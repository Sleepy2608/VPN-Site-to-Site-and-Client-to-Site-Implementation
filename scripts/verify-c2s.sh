#!/usr/bin/env bash
# ==============================================================================
# Script: verify-c2s.sh
# Mục đích: Kiểm tra nghiệm thu tự động kết nối OpenVPN Client-to-Site (Remote Access)
# Sử dụng: ./verify-c2s.sh [server|client|auto]
# ==============================================================================

set -euo pipefail

MODE="${1:-auto}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE} KIỂM TRA NGHIỆM THU OPENVPN CLIENT-TO-SITE (REMOTE ACCESS)${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# Tự động nhận diện vai trò
if [[ "${MODE}" == "auto" ]]; then
    if systemctl list-units --full -all 2>/dev/null | grep -q "openvpn-server@server-c2s"; then
        MODE="server"
    else
        MODE="client"
    fi
fi

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

if [[ "${MODE}" == "server" ]]; then
    echo -e "[*] Đang kiểm tra phía OpenVPN Server (VM-HQ-GW)...\n"

    # 1. Trạng thái dịch vụ systemd
    echo -n "  [*] Kiểm tra dịch vụ systemd openvpn-server@server-c2s... "
    if systemctl is-active --quiet openvpn-server@server-c2s 2>/dev/null; then
        echo -e "${GREEN}[ACTIVE]${NC}"
        record_pass "Dịch vụ OpenVPN C2S đang hoạt động"
    else
        echo -e "${RED}[INACTIVE]${NC}"
        record_fail "Dịch vụ OpenVPN C2S chưa được khởi động"
    fi

    # 2. Cổng mạng UDP 1194
    echo -n "  [*] Kiểm tra cổng lắng nghe UDP 1194... "
    if ss -uln 2>/dev/null | grep -q ":1194"; then
        echo -e "${GREEN}[LISTENING]${NC}"
        record_pass "Cổng UDP 1194 đang lắng nghe kết nối"
    else
        echo -e "${RED}[CLOSED]${NC}"
        record_fail "Cổng UDP 1194 không hoạt động"
    fi

    # 3. Interface ảo tun0
    echo -n "  [*] Kiểm tra card mạng ảo tun0 và địa chỉ IP... "
    if ip addr show dev tun0 2>/dev/null | grep -q "10.8.0.1"; then
        echo -e "${GREEN}[UP: 10.8.0.1]${NC}"
        record_pass "Interface tun0 đã nhận IP 10.8.0.1"
    else
        echo -e "${RED}[DOWN/MISSING]${NC}"
        record_fail "Interface tun0 không tồn tại hoặc sai IP"
    fi

    # 4. Quy tắc NAT Masquerade
    echo -n "  [*] Kiểm tra quy tắc iptables NAT Masquerade... "
    if iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o eth1 -j MASQUERADE 2>/dev/null; then
        echo -e "${GREEN}[CONFIGURED]${NC}"
        record_pass "NAT Masquerade cho dải 10.8.0.0/24 ra eth1 đã kích hoạt"
    else
        echo -e "${YELLOW}[MISSING]${NC}"
        record_warn "Chưa thấy quy tắc NAT Masquerade cho 10.8.0.0/24"
    fi

    # 5. Danh sách client đang kết nối
    echo -e "\n=== DANH SÁCH MÁY KHÁCH ĐANG KẾT NỐI (STATUS LOG) ==="
    STATUS_LOG="/var/log/openvpn/openvpn-c2s-status.log"
    if [[ -f "${STATUS_LOG}" ]]; then
        CLIENT_LIST=$(grep -A 10 "Common Name,Real Address" "${STATUS_LOG}" | grep -v "ROUTING TABLE" | grep -v "Common Name,Real Address" || true)
        if [[ -n "${CLIENT_LIST}" ]]; then
            echo -e "${GREEN}${CLIENT_LIST}${NC}"
            record_pass "Có máy khách kết nối thành công"
        else
            echo "  (Hiện tại chưa có client nào kết nối tới)"
        fi
    else
        echo "  (Chưa có tệp status log)"
    fi

else
    echo -e "[*] Đang kiểm tra phía Client (Remote Worker)...\n"

    # 1. Ping Gateway Tunnel IP
    echo -n "  [*] Ping OpenVPN Gateway Tunnel IP (10.8.0.1)... "
    if ping -c 2 -W 2 "10.8.0.1" &>/dev/null; then
        echo -e "${GREEN}[REACHABLE]${NC}"
        record_pass "Kết nối tới Gateway qua Tunnel 10.8.0.1 thành công"
    else
        echo -e "${RED}[UNREACHABLE]${NC}"
        record_fail "Không thể kết nối tới Gateway Tunnel 10.8.0.1"
    fi

    # 2. Ping máy chủ nội bộ HQ
    echo -n "  [*] Ping HQ Internal Server (192.168.10.50)... "
    if ping -c 2 -W 2 "192.168.10.50" &>/dev/null; then
        echo -e "${GREEN}[REACHABLE]${NC}"
        record_pass "Truy cập máy chủ nội bộ 192.168.10.50 thành công"
    else
        echo -e "${YELLOW}[TIMEOUT/WAITING]${NC}"
        record_warn "Chưa ping được 192.168.10.50 (HQ Server có thể chưa bật hoặc firewall chặn ICMP)"
    fi
fi

echo -e "\n------------------------------------------------------------------------------"
echo -e " KẾT QUẢ NGHIỆM THU: ${GREEN}${PASS_COUNT} PASSED${NC} | ${RED}${FAIL_COUNT} FAILED${NC}"
echo -e "------------------------------------------------------------------------------"

if [[ "${FAIL_COUNT}" -eq 0 ]]; then
    echo -e "${GREEN}[SUCCESS] Dịch vụ OpenVPN Client-to-Site đã sẵn sàng và hoạt động chính xác!${NC}"
    exit 0
else
    echo -e "${RED}[ATTENTION] Một số mục chưa đạt. Vui lòng kiểm tra lại log dịch vụ hoặc chứng chỉ.${NC}"
    exit 1
fi

