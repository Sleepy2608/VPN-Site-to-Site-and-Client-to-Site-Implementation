#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-c2s-server.sh
# Mục đích: Tự động hóa cài đặt, cấu hình và khởi chạy dịch vụ OpenVPN Server
#           Client-to-Site (Remote Access) trên VM-HQ-GW.
# Đối tượng thực thi: VM-HQ-GW (Trụ sở chính)
# Sử dụng: sudo ./deploy-c2s-server.sh
# ==============================================================================

set -euo pipefail

# Kiểm tra quyền root
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Vui lòng chạy script này với quyền root: sudo $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SERVER_CONF_SRC="${REPO_ROOT}/openvpn/client-to-site/server/server.conf"
SERVER_CONF_DEST="/etc/openvpn/server/server-c2s.conf"
source "${SCRIPT_DIR}/common/pki-paths.sh"
source "${SCRIPT_DIR}/common/lab-network.sh"
check_gateway_interfaces

echo "=============================================================================="
echo " TRIỂN KHAI OPENVPN CLIENT-TO-SITE SERVER (VM-HQ-GW)"
echo "=============================================================================="

# 1. Đảm bảo các gói phần mềm cần thiết đã được cài đặt
if ! command -v openvpn &>/dev/null; then
    echo "[*] Đang cài đặt openvpn và iptables-persistent..."
    apt update -y
    DEBIAN_FRONTEND=noninteractive apt install -y openvpn iptables-persistent netfilter-persistent
fi

bash "${SCRIPT_DIR}/common/check-openvpn-version.sh"

# 2. Tạo thư mục cấu hình và thư mục lưu trữ log
mkdir -p /etc/openvpn/server /var/log/openvpn /etc/openvpn/ccd-c2s
# An explicit CCD entry authorizes the remote employee, separate from Branch.
install -m 644 /dev/null /etc/openvpn/ccd-c2s/client1

# 3. Đồng bộ chứng chỉ số và khóa mật mã nếu chưa có trong /etc/openvpn/server/
REQUIRED_FILES=(
    "ca.crt"
    "hq-c2s-server.crt"
    "hq-c2s-server.key"
    "dh.pem"
    "ta.key"
    "crl.pem"
)

echo "[*] Kiểm tra các tệp chứng chỉ số và khóa mật mã trong /etc/openvpn/server/..."
MISSING_CERT=0
for f in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "/etc/openvpn/server/${f}" ]]; then
        # Thử tìm trong thư mục CA_DIR
        if [[ "${f}" == "hq-c2s-server.crt" ]] && [[ -f "${CA_DIR}/pki/issued/${f}" ]]; then
            cp "${CA_DIR}/pki/issued/${f}" /etc/openvpn/server/
        elif [[ "${f}" == "hq-c2s-server.key" ]] && [[ -f "${CA_DIR}/pki/private/${f}" ]]; then
            cp "${CA_DIR}/pki/private/${f}" /etc/openvpn/server/
        elif [[ -f "${CA_DIR}/pki/${f}" ]]; then
            cp "${CA_DIR}/pki/${f}" /etc/openvpn/server/
        elif [[ -f "${CA_DIR}/${f}" ]]; then
            cp "${CA_DIR}/${f}" /etc/openvpn/server/
        else
            echo "[ERROR] Thiếu tệp bắt buộc: /etc/openvpn/server/${f}" >&2
            MISSING_CERT=1
        fi
    fi
done

if [[ "${MISSING_CERT}" -eq 1 ]]; then
    echo "[FATAL] Vui lòng chạy 'bash scripts/pki/init-ca.sh' trước để khởi tạo chứng chỉ!" >&2
    exit 1
fi

# Phân quyền nghiêm ngặt cho tệp khóa
chmod 600 /etc/openvpn/server/*.key /etc/openvpn/server/ta.key 2>/dev/null || true
chmod 644 /etc/openvpn/server/*.crt /etc/openvpn/server/*.pem 2>/dev/null || true
echo "[+] Các chứng chỉ và khóa mật mã đã được bảo vệ an toàn."

# 4. Sao chép tệp cấu hình server-c2s.conf
echo "[*] Nạp tệp cấu hình ${SERVER_CONF_DEST}..."
cp "${SERVER_CONF_SRC}" "${SERVER_CONF_DEST}"
bash "${SCRIPT_DIR}/common/check-openvpn-version.sh" "${SERVER_CONF_DEST}"

# 5. Kích hoạt IP Forwarding tại tầng nhân kernel
echo "[*] Kiểm tra trạng thái chuyển tiếp IPv4..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null
if [[ ! -f /etc/sysctl.d/99-vpn-forward.conf ]]; then
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-vpn-forward.conf
fi

# Apply the shared policy before starting the tunnel.
bash "${SCRIPT_DIR}/common/setup-firewall-rules.sh" hq-gw openvpn

# 7. Khởi động và kích hoạt dịch vụ systemd
echo "[*] Khởi động dịch vụ openvpn-server@server-c2s..."
systemctl daemon-reload
systemctl enable openvpn-server@server-c2s
systemctl restart openvpn-server@server-c2s

# 8. Kiểm tra trạng thái hoạt động
sleep 2
if systemctl is-active --quiet openvpn-server@server-c2s; then
    echo "[SUCCESS] Dịch vụ OpenVPN C2S Server đang hoạt động (active running)!"
    echo "  Interface tun0 IP: $(ip -4 addr show tun0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo 'Đang khởi tạo...')"
else
    echo "[FAILED] Dịch vụ OpenVPN C2S Server không khởi động được. Xem chi tiết qua: journalctl -u openvpn-server@server-c2s -n 30" >&2
    exit 1
fi

echo "=============================================================================="
echo " TRIỂN KHAI HOÀN TẤT!"
echo " File log trạng thái kết nối client: /var/log/openvpn/openvpn-c2s-status.log"
echo "=============================================================================="

