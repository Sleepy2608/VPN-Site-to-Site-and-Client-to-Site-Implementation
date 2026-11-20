#!/usr/bin/env bash
# ==============================================================================
# capture-traffic.sh: Kịch bản tự động hóa bắt gói tin và phân tích mạng VPN
# Đồ án An ninh mạng: Thiết lập mạng riêng ảo VPN Site-to-Site & Client-to-Site
# Armbian Generic x86_64 trên VMware (HQ Gateway hoặc Branch Gateway)
# ==============================================================================

set -euo pipefail

# Định nghĩa bảng màu hiển thị ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Kiểm tra quyền root
if [[ "${EUID}" -ne 0 ]]; then
    echo -e "${RED}[ERROR] Kịch bản này yêu cầu quyền quản trị root để chạy tcpdump.${NC}"
    echo -e "Vui lòng chạy lại với lệnh: ${YELLOW}sudo $0 [tham số]${NC}"
    exit 1
fi

# Kiểm tra công cụ tcpdump
if ! command -v tcpdump &>/dev/null; then
    echo -e "${YELLOW}[INFO] Chưa tìm thấy tcpdump. Đang tiến hành cài đặt...${NC}"
    apt-get update -qq && apt-get install -y -qq tcpdump
fi

# Thiết lập thư mục lưu trữ file pcap
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common/lab-network.sh"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CAPTURE_DIR="${BASE_DIR}/tests/captures/samples"
mkdir -p "${CAPTURE_DIR}"

# Cấu hình mặc định
INTERFACE="${WAN_IF}"
PACKET_COUNT=100
DURATION=30
FILTER_MODE="all-vpn"
CUSTOM_FILTER=""
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"

# Hàm in hướng dẫn sử dụng
show_usage() {
    cat <<EOF
Sử dụng: sudo $0 [TÙY CHỌN]

Kịch bản bắt gói tin tự động phục vụ kiểm tra và chụp bằng chứng Wireshark.

TÙY CHỌN:
  -i, --interface <tên_card>   Card mạng cần bắt gói (Mặc định: ${WAN_IF}).
                               Gợi ý: ${WAN_IF} (WAN), ${LAN_IF} (LAN), tun0/tun1 (Tunnel).
  -c, --count <số_lượng>       Số lượng gói tin cần bắt (Mặc định: 100, nhập 0 để bắt liên tục).
  -m, --mode <chế_độ>          Chế độ lọc gói tin:
                                 openvpn-c2s : Lọc OpenVPN Client-to-Site (UDP 1194)
                                 openvpn-s2s : Lọc OpenVPN Site-to-Site (UDP 1195)
                                 ipsec       : Lọc strongSwan IPsec (ESP, IKE UDP 500, NAT-T 4500)
                                 all-vpn     : Lọc tất cả các loại lưu lượng VPN (Mặc định)
                                 lan-http    : Lọc lưu lượng HTTP/ICMP nội bộ trên card LAN
                                 leak-check  : Kiểm tra rò rỉ (bắt HTTP/ICMP bản rõ trên card WAN)
  -f, --filter <chuỗi_lọc>     Bộ lọc tcpdump/pcap tùy biến (ghi đè chế độ lọc -m).
  -o, --output <tên_file>      Tên file lưu trữ (.pcap). Nếu không chỉ định sẽ tự tạo tên theo thời gian.
  -d, --duration <giây>        Dừng sau thời gian này (mặc định 30, 0 = thủ công).
  -h, --help                   Hiển thị hướng dẫn này và thoát.

VÍ DỤ:
  sudo $0 -i ${WAN_IF} -m openvpn-c2s -c 50
  sudo $0 -i ${WAN_IF} -m ipsec -c 100
  sudo $0 -i ${LAN_IF} -m lan-http -c 50
  sudo $0 -i ${WAN_IF} -m leak-check -c 20
EOF
    exit 0
}

# Xử lý tham số dòng lệnh
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    if [[ "$1" != -h && "$1" != --help && $# -lt 2 ]]; then
        echo "[ERROR] Missing value for $1" >&2; exit 2
    fi
    case "$1" in
        -i|--interface)
            INTERFACE="$2"
            shift 2
            ;;
        -c|--count)
            PACKET_COUNT="$2"
            shift 2
            ;;
        -m|--mode)
            FILTER_MODE="$2"
            shift 2
            ;;
        -f|--filter)
            CUSTOM_FILTER="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -d|--duration)
            DURATION="$2"; shift 2 ;;
        -h|--help)
            show_usage
            ;;
        *)
            echo -e "${RED}[ERROR] Tùy chọn không hợp lệ: $1${NC}"
            exit 2
            ;;
    esac
done

if [[ ! "${PACKET_COUNT}" =~ ^[0-9]{1,8}$ || ! "${DURATION}" =~ ^[0-9]{1,8}$ ]]; then
    echo '[ERROR] count/duration must be nonnegative integers.' >&2; exit 2
fi
PACKET_COUNT=$((10#${PACKET_COUNT}))
DURATION=$((10#${DURATION}))
# Kiểm tra card mạng có tồn tại trên máy không
if ! ip link show "${INTERFACE}" &>/dev/null; then
    echo -e "${RED}[ERROR] Không tìm thấy card mạng '${INTERFACE}' trên hệ thống.${NC}"
    echo -e "Danh sách card mạng hiện có:"
    ip -br link show
    exit 1
fi

# Xác định biểu thức lọc tcpdump dựa vào chế độ
if [[ -n "${CUSTOM_FILTER}" ]]; then
    TCPDUMP_EXPR="${CUSTOM_FILTER}"
    MODE_DESC="Tùy biến: ${CUSTOM_FILTER}"
else
    case "${FILTER_MODE}" in
        openvpn-c2s)
            TCPDUMP_EXPR="udp port 1194"
            MODE_DESC="OpenVPN Client-to-Site (UDP 1194)"
            ;;
        openvpn-s2s)
            TCPDUMP_EXPR="udp port 1195"
            MODE_DESC="OpenVPN Site-to-Site (UDP 1195)"
            ;;
        ipsec)
            TCPDUMP_EXPR="proto 50 or udp port 500 or udp port 4500"
            MODE_DESC="strongSwan IPsec IKEv2 / ESP (Proto 50, UDP 500/4500)"
            ;;
        all-vpn)
            TCPDUMP_EXPR="proto 50 or udp port 500 or udp port 4500 or udp port 1194 or udp port 1195"
            MODE_DESC="Tất cả lưu lượng VPN (OpenVPN + IPsec ESP/IKE)"
            ;;
        lan-http)
            TCPDUMP_EXPR="tcp port 80 or icmp"
            MODE_DESC="Lưu lượng nội bộ LAN (HTTP Port 80 hoặc ICMP Echo)"
            ;;
        leak-check)
            TCPDUMP_EXPR="(tcp port 80 or icmp) and (net 192.168.10.0/24 or net 192.168.20.0/24)"
            MODE_DESC="Kiểm tra rò rỉ dữ liệu bản rõ mạng LAN ra cổng ngoài"
            ;;
        *)
            echo -e "${RED}[ERROR] Chế độ lọc '${FILTER_MODE}' không hợp lệ.${NC}"
            exit 2
            ;;
    esac
fi

# Thiết lập đường dẫn file output
if [[ -z "${OUTPUT_FILE}" ]]; then
    OUTPUT_FILE="${CAPTURE_DIR}/capture_${INTERFACE}_${FILTER_MODE}_${TIMESTAMP}.pcap"
else
    # Nếu người dùng truyền đường dẫn tương đối, đưa vào CAPTURE_DIR
    if [[ "${OUTPUT_FILE}" != /* ]]; then
        OUTPUT_FILE="${CAPTURE_DIR}/${OUTPUT_FILE}"
    fi
fi

# Đảm bảo đuôi mở rộng là .pcap
if [[ "${OUTPUT_FILE}" != *.pcap ]]; then
    OUTPUT_FILE="${OUTPUT_FILE}.pcap"
fi

echo -e "=============================================================================="
echo -e "${CYAN}     BẮT ĐẦU TIẾN TRÌNH THU THẬP GÓI TIN MẠNG (TCPDUMP CAPTURE)             ${NC}"
echo -e "=============================================================================="
echo -e " * Card mạng lắng nghe : ${YELLOW}${INTERFACE}${NC}"
echo -e " * Chế độ phân tích    : ${YELLOW}${MODE_DESC}${NC}"
echo -e " * Biểu thức tcpdump   : ${CYAN}${TCPDUMP_EXPR}${NC}"
if [[ "${PACKET_COUNT}" -eq 0 ]]; then
    echo -e " * Giới hạn số gói     : ${YELLOW}Không giới hạn (Nhấn Ctrl+C để dừng)${NC}"
else
    echo -e " * Giới hạn số gói     : ${YELLOW}${PACKET_COUNT} gói tin${NC}"
fi
echo -e " * Tệp tin kết quả     : ${GREEN}${OUTPUT_FILE}${NC}"
echo -e "=============================================================================="

# Chuẩn bị cờ thực thi cho tcpdump
TCPDUMP_ARGS=(-i "${INTERFACE}" -w "${OUTPUT_FILE}" -U)

if [[ "${PACKET_COUNT}" -gt 0 ]]; then
    TCPDUMP_ARGS+=(-c "${PACKET_COUNT}")
fi

# Xử lý tín hiệu ngắt (SIGINT/SIGTERM) để thoát an toàn
trap_exit() {
    echo -e "\n${YELLOW}[!] Đã nhận tín hiệu dừng. Đang hoàn tất ghi file pcap...${NC}"
}
trap trap_exit SIGINT SIGTERM

echo -e "${BLUE}[*] Đang lắng nghe gói tin trên ${INTERFACE}... Hãy thực hiện thao tác test (ping/curl/vpn)...${NC}"

# Thực thi tcpdump
set +e
if [[ "${DURATION}" -gt 0 ]]; then
    timeout --signal=INT "${DURATION}" tcpdump "${TCPDUMP_ARGS[@]}" "${TCPDUMP_EXPR}"
else
    tcpdump "${TCPDUMP_ARGS[@]}" "${TCPDUMP_EXPR}"
fi
TCPDUMP_STATUS=$?
set -euo pipefail

case "${TCPDUMP_STATUS}" in
    0|124|130) ;; # timeout sends SIGINT to finish the PCAP normally
    *) echo "[ERROR] tcpdump failed: ${TCPDUMP_STATUS}" >&2; exit "${TCPDUMP_STATUS}" ;;
esac
[[ -s "${OUTPUT_FILE}" ]] || { echo '[ERROR] No PCAP written.' >&2; exit 1; }
PACKET_TOTAL=$(tcpdump -nn -r "${OUTPUT_FILE}" 2>/dev/null | wc -l)
echo "[OBSERVED] ${PACKET_TOTAL} packets: ${OUTPUT_FILE}"
if [[ "${FILTER_MODE}" == leak-check && -z "${CUSTOM_FILTER}" ]]; then
    if [[ "${PACKET_TOTAL}" -gt 0 ]]; then
        echo '[FAIL] Found cleartext matching the lab LAN filter; inspect PCAP.' >&2; exit 1
    fi
    echo '[INFO] Zero matching packets. Validate the capture point and active test traffic before drawing a security conclusion.'
elif [[ "${PACKET_TOTAL}" -eq 0 ]]; then
    echo '[ERROR] No traffic observed; capture does not prove encryption.' >&2; exit 1
fi
