#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-s2s-hq.sh
# Mục đích: Tự động cấu hình và khởi chạy dịch vụ OpenVPN Site-to-Site Server
#           trên HQ Gateway (VM-HQ-GW: port UDP 1195, dev tun1).
# Đối tượng thực thi: VM-HQ-GW (Trụ sở chính)
# Sử dụng: sudo ./deploy-s2s-hq.sh
# ==============================================================================

set -euo pipefail

# Kiểm tra quyền root
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Vui lòng chạy script này với quyền root: sudo $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SERVER_S2S_SRC="${REPO_ROOT}/openvpn/site-to-site/gateway-hq/s2s-hq.conf"
SERVER_S2S_DEST="/etc/openvpn/server/server-s2s.conf"
CCD_SRC="${REPO_ROOT}/openvpn/site-to-site/gateway-hq/ccd"
CCD_DEST="/etc/openvpn/ccd"
CA_DIR="${CA_DIR:-/home/${SUDO_USER:-$USER}/openvpn-ca}"

echo "=============================================================================="
echo " TRIỂN KHAI OPENVPN SITE-TO-SITE SERVER (HQ GATEWAY - VM-HQ-GW)"
echo "=============================================================================="

# 1. Đảm bảo các thư mục cấu hình và log tồn tại
mkdir -p /etc/openvpn/server "${CCD_DEST}" /var/log/openvpn

# 2. Kiểm tra và đồng bộ chứng chỉ S2S nếu chưa có
echo "[*] Kiểm tra các tệp chứng chỉ số S2S trong /etc/openvpn/server/..."
if [[ ! -f "/etc/openvpn/server/hq-s2s-gw.crt" ]]; then
    if [[ -f "${CA_DIR}/pki/issued/hq-s2s-gw.crt" ]]; then
        cp "${CA_DIR}/pki/issued/hq-s2s-gw.crt" /etc/openvpn/server/
        cp "${CA_DIR}/pki/private/hq-s2s-gw.key" /etc/openvpn/server/
    else
        echo "[ERROR] Không tìm thấy chứng chỉ hq-s2s-gw.crt tại /etc/openvpn/server/ hoặc ${CA_DIR}" >&2
        echo "Vui lòng chạy 'bash scripts/pki/init-ca.sh' trước." >&2
        exit 1
    fi
fi

chmod 600 /etc/openvpn/server/*.key /etc/openvpn/server/ta.key 2>/dev/null || true
chmod 644 /etc/openvpn/server/*.crt /etc/openvpn/server/*.pem 2>/dev/null || true

# 3. Nạp cấu hình CCD (Client Config Directory) - Rất quan trọng cho S2S
echo "[*] Thiết lập Client Config Directory (CCD) tại ${CCD_DEST}..."
cp -r "${CCD_SRC}"/* "${CCD_DEST}/"
chmod 644 "${CCD_DEST}"/*
echo "[+] Đã cấu hình chỉ thị iroute cho branch-gw: $(cat "${CCD_DEST}/branch-gw")"

# 4. Sao chép tệp cấu hình server-s2s.conf
echo "[*] Nạp tệp cấu hình ${SERVER_S2S_DEST}..."
cp "${SERVER_S2S_SRC}" "${SERVER_S2S_DEST}"

# 5. Cấu hình tường lửa iptables cho đường hầm S2S (tun1)
echo "[*] Thiết lập quy tắc tường lửa cho interface tun1..."

add_rule() {
    local table="$1"
    shift
    if ! iptables -t "${table}" -C "$@" 2>/dev/null; then
        iptables -t "${table}" -A "$@"
    fi
}

# Cho phép lưu lượng hai chiều giữa tun1 (S2S) và eth1 (LAN HQ)
add_rule filter FORWARD -i tun1 -o eth1 -j ACCEPT
add_rule filter FORWARD -i eth1 -o tun1 -j ACCEPT

# Mở cổng UDP 1195 trên card WAN eth0
add_rule filter INPUT -i eth0 -p udp --dport 1195 -j ACCEPT

# Lưu vĩnh viễn cấu hình tường lửa
if command -v netfilter-persistent &>/dev/null; then
    netfilter-persistent save >/dev/null
fi
echo "[+] Quy tắc tường lửa cho S2S đã được kích hoạt và lưu vĩnh viễn."

# 6. Khởi động dịch vụ OpenVPN S2S Server qua systemd
echo "[*] Khởi động dịch vụ openvpn-server@server-s2s..."
systemctl daemon-reload
systemctl enable openvpn-server@server-s2s
systemctl restart openvpn-server@server-s2s

# 7. Kiểm tra trạng thái hoạt động
sleep 2
if systemctl is-active --quiet openvpn-server@server-s2s; then
    echo "[SUCCESS] Dịch vụ OpenVPN S2S Server đang hoạt động!"
    echo "  Interface tun1 IP: $(ip -4 addr show tun1 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo 'Đang khởi tạo...')"
else
    echo "[FAILED] Dịch vụ S2S Server không khởi động được. Xem log qua: journalctl -u openvpn-server@server-s2s -n 30" >&2
    exit 1
fi

echo "=============================================================================="
echo " TRIỂN KHAI S2S PHÍA HQ HOÀN TẤT!"
echo " Log kết nối: /var/log/openvpn/openvpn-s2s-status.log"
echo "=============================================================================="
