#!/usr/bin/env bash
# ==============================================================================
# Script: verify-phase1.sh
# Mục đích: Tự động kiểm tra nghiệm thu kết nối mạng & cấu hình Giai đoạn 1
# Cách dùng: ./verify-phase1.sh [hq-gw|branch-gw|hq-server|branch-pc]
# ==============================================================================

set -euo pipefail

# Màu hiển thị
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TARGET_NODE="${1:-auto}"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE} KIỂM TRA NGHIỆM THU MẠNG GIAI ĐOẠN 1 (LAB NETWORK VERIFICATION)${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# Tự động nhận diện node nếu không chỉ định
if [[ "${TARGET_NODE}" == "auto" ]]; then
    if ip addr show 2>/dev/null | grep -q "172.16.1.10"; then
        TARGET_NODE="hq-gw"
    elif ip addr show 2>/dev/null | grep -q "172.16.1.20"; then
        TARGET_NODE="branch-gw"
    elif ip addr show 2>/dev/null | grep -q "192.168.10.50"; then
        TARGET_NODE="hq-server"
    elif ip addr show 2>/dev/null | grep -q "192.168.20.50"; then
        TARGET_NODE="branch-pc"
    else
        echo -e "${YELLOW}[WARN] Không tự nhận diện được địa chỉ IP. Vui lòng truyền tham số:${NC}"
        echo "  ./verify-phase1.sh [hq-gw | branch-gw | hq-server | branch-pc]"
        exit 1
    fi
fi

echo -e "[*] Node hiện tại được xác định là: ${YELLOW}${TARGET_NODE}${NC}\n"

PASS_COUNT=0
FAIL_COUNT=0

test_ping() {
    local target_ip="$1"
    local desc="$2"

    echo -n "  [*] Kiểm tra Ping tới ${desc} (${target_ip})... "
    if ping -c 2 -W 2 "${target_ip}" &>/dev/null; then
        echo -e "${GREEN}[PASS]${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL] (Không nhận được phản hồi)${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

check_sysctl_forward() {
    echo -n "  [*] Kiểm tra Kernel IP Forwarding (net.ipv4.ip_forward)... "
    local status
    status=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "0")
    if [[ "${status}" -eq 1 ]]; then
        echo -e "${GREEN}[PASS] (Đã kích hoạt = 1)${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL] (Chưa kích hoạt = ${status})${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

check_chrony() {
    echo -n "  [*] Kiểm tra dịch vụ đồng bộ thời gian (chrony)... "
    if systemctl is-active --quiet chrony 2>/dev/null; then
        echo -e "${GREEN}[PASS] (Active)${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${YELLOW}[WARN] (Chưa bật chrony - cần kiểm tra đồng hồ máy ảo)${NC}"
    fi
}

case "${TARGET_NODE}" in
    hq-gw)
        echo "=== [1] Kiểm tra cấu hình Kernel & Dịch vụ ==="
        check_sysctl_forward
        check_chrony

        echo -e "\n=== [2] Kiểm tra kết nối WAN ==="
        test_ping "172.16.1.20" "Branch Gateway WAN"
        test_ping "172.16.1.100" "Remote PC WAN (nếu đang bật)"

        echo -e "\n=== [3] Kiểm tra kết nối LAN Trụ sở ==="
        test_ping "192.168.10.50" "HQ Web Server LAN"
        ;;

    branch-gw)
        echo "=== [1] Kiểm tra cấu hình Kernel & Dịch vụ ==="
        check_sysctl_forward
        check_chrony

        echo -e "\n=== [2] Kiểm tra kết nối WAN ==="
        test_ping "172.16.1.10" "HQ Gateway WAN"
        test_ping "172.16.1.100" "Remote PC WAN (nếu đang bật)"

        echo -e "\n=== [3] Kiểm tra kết nối LAN Chi nhánh ==="
        test_ping "192.168.20.50" "Branch PC LAN"
        ;;

    hq-server)
        echo "=== [1] Kiểm tra dịch vụ ==="
        check_chrony

        echo -e "\n=== [2] Kiểm tra kết nối Default Gateway ==="
        test_ping "192.168.10.1" "HQ Gateway LAN Interface"
        ;;

    branch-pc)
        echo "=== [1] Kiểm tra kết nối Default Gateway ==="
        test_ping "192.168.20.1" "Branch Gateway LAN Interface"
        ;;
esac

echo -e "\n------------------------------------------------------------------------------"
echo -e " KẾT QUẢ KIỂM TRA: ${GREEN}${PASS_COUNT} PASSED${NC} | ${RED}${FAIL_COUNT} FAILED${NC}"
echo -e "------------------------------------------------------------------------------"

if [[ "${FAIL_COUNT}" -eq 0 ]]; then
    echo -e "${GREEN}[SUCCESS] Node ${TARGET_NODE} đã đáp ứng 100% tiêu chí nghiệm thu Giai đoạn 1!${NC}"
    exit 0
else
    echo -e "${RED}[ATTENTION] Một số mục chưa đạt. Vui lòng kiểm tra lại cấu hình Netplan/Adapter ảo.${NC}"
    exit 1
fi

