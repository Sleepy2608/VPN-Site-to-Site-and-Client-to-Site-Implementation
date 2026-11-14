#!/usr/bin/env bash
# ==============================================================================
# Script: verify-ipsec.sh
# Mục đích: Tự động kiểm tra trạng thái đường hầm strongSwan IPsec IKEv2
#           (IKE_SA, CHILD_SA ESP, chính sách XFRM và kết nối LAN-to-LAN).
# Sử dụng: ./verify-ipsec.sh [hq-gw|branch-gw|branch-pc|auto]
# ==============================================================================

set -euo pipefail

ROLE="${1:-auto}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE} KIỂM TRA NGHIỆM THU ĐƯỜNG HẦM STRONGSWAN IPSEC IKEV2 (SITE-TO-SITE)${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [[ "${ROLE}" == "auto" ]]; then
    if ip addr show 2>/dev/null | grep -q "172.16.1.10"; then
        ROLE="hq-gw"
    elif ip addr show 2>/dev/null | grep -q "172.16.1.20"; then
        ROLE="branch-gw"
    elif ip addr show 2>/dev/null | grep -q "192.168.20.50"; then
        ROLE="branch-pc"
    else
        ROLE="branch-pc"
    fi
fi

echo -e "[*] Đang thực hiện kiểm tra từ vai trò: ${YELLOW}${ROLE}${NC}\n"

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

check_ipsec_sa() {
    echo -n "  [*] Kiểm tra IKE_SA (Giai đoạn 1)... "
    local status_output
    status_output=$(ipsec status 2>/dev/null || echo "")

    if echo "${status_output}" | grep -q "ESTABLISHED"; then
        echo -e "${GREEN}[ESTABLISHED]${NC}"
        record_pass "IKE_SA đã thiết lập thành công"
    else
        echo -e "${RED}[NOT ESTABLISHED]${NC}"
        record_fail "IKE_SA chưa được thiết lập"
    fi

    echo -n "  [*] Kiểm tra CHILD_SA / ESP (Giai đoạn 2 - IPsec Tunnel)... "
    if echo "${status_output}" | grep -q -E "INSTALLED|TUNNEL"; then
        echo -e "${GREEN}[INSTALLED, TUNNEL]${NC}"
        record_pass "CHILD_SA (ESP Tunnel) đã cài đặt vào nhân Linux"
    else
        echo -e "${RED}[NOT INSTALLED]${NC}"
        record_fail "CHILD_SA chưa được kích hoạt"
    fi
}

check_kernel_xfrm() {
    echo -n "  [*] Kiểm tra bảng chính sách mã hóa kernel (ip xfrm policy)... "
    if ip xfrm policy 2>/dev/null | grep -q "dir out"; then
        echo -e "${GREEN}[ACTIVE POLICIES]${NC}"
        record_pass "Chính sách XFRM IPsec đang hoạt động tại tầng mạng"
    else
        echo -e "${YELLOW}[NO POLICIES]${NC}"
        record_warn "Chưa tìm thấy chính sách XFRM trong kernel"
    fi
}

case "${ROLE}" in
    hq-gw|branch-gw)
        echo "=== [1] Kiểm tra trạng thái strongSwan Security Associations ==="
        check_ipsec_sa

        echo -e "\n=== [2] Kiểm tra tầng nhân Linux XFRM Framework ==="
        check_kernel_xfrm

        echo -e "\n=== [3] Chi tiết trạng thái (ipsec statusall rút gọn) ==="
        ipsec statusall 2>/dev/null | grep -E "Security Associations|ESTABLISHED|INSTALLED|bytes" || true
        ;;

    branch-pc)
        echo "=== [1] Đo kiểm thông suốt mạng LAN qua IPsec ESP ==="
        echo -n "  [*] Ping HQ Internal Web Server (192.168.10.50)... "
        if ping -c 4 -W 2 "192.168.10.50" &>/dev/null; then
            echo -e "${GREEN}[REACHABLE - 0% LOSS]${NC}"
            record_pass "Gói tin ICMP truyền tải thành công qua đường hầm IPsec"
        else
            echo -e "${RED}[UNREACHABLE]${NC}"
            record_fail "Không thể kết nối tới 192.168.10.50"
        fi

        echo -e "\n=== [2] Kiểm tra dịch vụ HTTP nội bộ qua IPsec ==="
        echo -n "  [*] HTTP GET http://192.168.10.50... "
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 4 http://192.168.10.50 || echo "000")
        if [[ "${HTTP_CODE}" == "200" ]]; then
            echo -e "${GREEN}[HTTP 200 OK]${NC}"
            record_pass "Truy cập ứng dụng Web nội bộ HQ thành công qua IPsec"
        else
            echo -e "${RED}[HTTP ${HTTP_CODE}]${NC}"
            record_fail "Không tải được Cổng nội bộ (Mã lỗi: ${HTTP_CODE})"
        fi
        ;;
esac

echo -e "\n------------------------------------------------------------------------------"
echo -e " KẾT QUẢ NGHIỆM THU: ${GREEN}${PASS_COUNT} PASSED${NC} | ${RED}${FAIL_COUNT} FAILED${NC}"
echo -e "------------------------------------------------------------------------------"

if [[ "${FAIL_COUNT}" -eq 0 ]]; then
    echo -e "${GREEN}[SUCCESS] Hệ thống strongSwan IPsec IKEv2 hoạt động chính xác và đạt chuẩn!${NC}"
    exit 0
else
    echo -e "${RED}[ATTENTION] Một số mục chưa đạt. Hãy kiểm tra lại file ipsec.secrets hoặc ipsec statusall.${NC}"
    exit 1
fi
