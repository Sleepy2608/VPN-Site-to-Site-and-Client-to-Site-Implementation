#!/usr/bin/env bash
# ==============================================================================
# Script: verify-s2s.sh
# Mục đích: Tự động kiểm tra nghiệm thu kết nối và định tuyến hai chiều
#           đường hầm OpenVPN Site-to-Site giữa HQ và Chi nhánh.
# Sử dụng: ./verify-s2s.sh [hq-gw|branch-gw|branch-pc|auto]
# ==============================================================================

set -euo pipefail

NODE_ROLE="${1:-auto}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE} KIỂM TRA NGHIỆM THU ĐƯỜNG HẦM OPENVPN SITE-TO-SITE (HQ <=> BRANCH)${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# Tự động nhận diện node nếu chọn auto
if [[ "${NODE_ROLE}" == "auto" ]]; then
    if ip addr show 2>/dev/null | grep -q "172.16.1.10"; then
        NODE_ROLE="hq-gw"
    elif ip addr show 2>/dev/null | grep -q "172.16.1.20"; then
        NODE_ROLE="branch-gw"
    elif ip addr show 2>/dev/null | grep -q "192.168.20.50"; then
        NODE_ROLE="branch-pc"
    else
        echo -e "${YELLOW}[WARN] Không nhận diện được IP. Mặc định kiểm tra từ góc độ Branch GW / Client-Linux...${NC}"
        NODE_ROLE="branch-gw"
    fi
fi

# Chuyển đổi alias tên 3-VM sang vai trò tương đương
if [[ "${NODE_ROLE}" == "server" || "${NODE_ROLE}" == "vm-server" ]]; then
    NODE_ROLE="hq-gw"
elif [[ "${NODE_ROLE}" == "client-linux" || "${NODE_ROLE}" == "vm-client-linux" ]]; then
    NODE_ROLE="branch-gw"
fi

echo -e "[*] Đang thực hiện kiểm tra từ node: ${YELLOW}${NODE_ROLE}${NC}\n"

PASS_COUNT=0
FAIL_COUNT=0

record_pass() {
    echo -e "${GREEN}[PASS] $1${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
}

record_fail() {
    echo -e "${RED}[FAIL] $1${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

record_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

test_ping() {
    local target_ip="$1"
    local desc="$2"

    echo -n "  [*] Ping ${desc} (${target_ip})... "
    if ping -c 2 -W 2 "${target_ip}" &>/dev/null; then
        echo -e "${GREEN}[REACHABLE]${NC}"
        record_pass "Ping ${desc} (${target_ip}) thành công"
    else
        echo -e "${RED}[UNREACHABLE]${NC}"
        record_fail "Không thể ping tới ${desc} (${target_ip})"
    fi
}

case "${NODE_ROLE}" in
    hq-gw)
        echo "=== [1] Kiểm tra trạng thái dịch vụ S2S Server ==="
        if systemctl is-active --quiet openvpn-server@server-s2s 2>/dev/null; then
            record_pass "Dịch vụ openvpn-server@server-s2s đang hoạt động"
        else
            record_fail "Dịch vụ openvpn-server@server-s2s chưa chạy"
        fi

        echo -e "\n=== [2] Kiểm tra interface ảo tun1 ==="
        if ip addr show dev tun1 2>/dev/null | grep -q "10.9.0.1"; then
            record_pass "Interface tun1 nhận đúng IP 10.9.0.1/24"
        else
            record_fail "Interface tun1 không tồn tại hoặc sai IP"
        fi

        echo -e "\n=== [3] Kiểm tra bảng định tuyến tới mạng Chi nhánh ==="
        if ip route show 2>/dev/null | grep -q "192.168.20.0"; then
            record_pass "Tuyến đường 192.168.20.0/24 qua tun1 đã nạp vào kernel"
        else
            record_fail "Thiếu tuyến đường 192.168.20.0/24 trong routing table"
        fi

        echo -e "\n=== [4] Kiểm tra thông suốt hai đầu đường hầm ==="
        test_ping "10.9.0.2" "Branch Gateway Tunnel Endpoint"
        test_ping "192.168.20.1" "Branch Gateway LAN Interface"
        test_ping "192.168.20.50" "Branch Client PC"
        ;;

    branch-gw)
        echo "=== [1] Kiểm tra trạng thái dịch vụ S2S Client ==="
        if systemctl is-active --quiet openvpn-client@client-s2s 2>/dev/null; then
            record_pass "Dịch vụ openvpn-client@client-s2s đang hoạt động"
        else
            record_fail "Dịch vụ openvpn-client@client-s2s chưa chạy"
        fi

        echo -e "\n=== [2] Kiểm tra interface ảo tun0 ==="
        if ip addr show dev tun0 2>/dev/null | grep -q "10.9.0.2"; then
            record_pass "Interface tun0 nhận đúng IP 10.9.0.2/24"
        else
            record_fail "Interface tun0 không tồn tại hoặc sai IP"
        fi

        echo -e "\n=== [3] Kiểm tra tuyến đường tới mạng Trụ sở HQ ==="
        if ip route show 2>/dev/null | grep -q "192.168.10.0"; then
            record_pass "Tuyến đường 192.168.10.0/24 via 10.9.0.1 đã được push"
        else
            record_fail "Thiếu tuyến đường 192.168.10.0/24 trong routing table"
        fi

        echo -e "\n=== [4] Kiểm tra thông suốt hai đầu đường hầm ==="
        test_ping "10.9.0.1" "HQ Gateway Tunnel Endpoint"
        test_ping "192.168.10.1" "HQ Gateway LAN Interface"
        test_ping "192.168.10.50" "HQ Web Server"
        ;;

    branch-pc)
        echo "=== [1] Kiểm tra kết nối LAN-to-LAN hai chiều ==="
        test_ping "192.168.10.50" "HQ Internal Web Server (192.168.10.50)"
        test_ping "192.168.10.1" "HQ Gateway LAN Interface (192.168.10.1)"

        echo -e "\n=== [2] Kiểm tra truy cập dịch vụ HTTP nội bộ ==="
        echo -n "  [*] Kiểm tra HTTP GET http://192.168.10.50... "
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 4 http://192.168.10.50 || echo "000")
        if [[ "${HTTP_CODE}" == "200" ]]; then
            echo -e "${GREEN}[HTTP 200 OK]${NC}"
            record_pass "Truy cập Web Portal nội bộ HQ từ Chi nhánh thành công"
        else
            echo -e "${RED}[HTTP ${HTTP_CODE}]${NC}"
            record_fail "Không tải được Cổng nội bộ HQ (Mã lỗi: ${HTTP_CODE})"
        fi

        echo -e "\n=== [3] Kiểm tra chặng định tuyến (Traceroute) ==="
        if command -v traceroute &>/dev/null; then
            echo "  [*] Chạy traceroute tới 192.168.10.50:"
            traceroute -n -w 2 -m 5 192.168.10.50 || true
            record_pass "Đã thực hiện traceroute kiểm tra luồng định tuyến"
        fi
        ;;
esac

echo -e "\n------------------------------------------------------------------------------"
echo -e " KẾT QUẢ NGHIỆM THU: ${GREEN}${PASS_COUNT} PASSED${NC} | ${RED}${FAIL_COUNT} FAILED${NC}"
echo -e "------------------------------------------------------------------------------"

if [[ "${FAIL_COUNT}" -eq 0 ]]; then
    echo -e "${GREEN}[SUCCESS] Đường hầm OpenVPN Site-to-Site đã kết nối và thông suốt hai chiều!${NC}"
    exit 0
else
    echo -e "${RED}[ATTENTION] Một số mục chưa đạt. Vui lòng kiểm tra lại cấu hình CCD (iroute) hoặc iptables FORWARD.${NC}"
    exit 1
fi
