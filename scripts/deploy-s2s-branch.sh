#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-s2s-branch.sh
# Mục đích: Tự động cấu hình và khởi chạy dịch vụ OpenVPN Site-to-Site Client
#           trên Branch Gateway (VM-Branch-GW: kết nối tới HQ GW UDP 1195).
# Đối tượng thực thi: VM-Branch-GW (Văn phòng Chi nhánh)
# Sử dụng: sudo ./deploy-s2s-branch.sh
# ==============================================================================

set -euo pipefail

# Kiểm tra quyền root
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Vui lòng chạy script này với quyền root: sudo $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common/lab-network.sh"
check_gateway_interfaces
CLIENT_S2S_SRC="${REPO_ROOT}/openvpn/site-to-site/gateway-branch/s2s-branch.conf"
CLIENT_S2S_DEST="/etc/openvpn/client/client-s2s.conf"

echo "=============================================================================="
echo " TRIỂN KHAI OPENVPN SITE-TO-SITE CLIENT (BRANCH GATEWAY - VM-BRANCH-GW)"
echo "=============================================================================="

# 1. Cài đặt các gói nếu chưa có
if ! command -v openvpn &>/dev/null; then
    echo "[*] Đang cài đặt openvpn và iptables-persistent..."
    apt update -y
    DEBIAN_FRONTEND=noninteractive apt install -y openvpn iptables-persistent netfilter-persistent
fi

bash "${SCRIPT_DIR}/common/check-openvpn-version.sh"

mkdir -p /etc/openvpn/client /var/log/openvpn

# 2. Kiểm tra các tệp chứng chỉ bắt buộc tại /etc/openvpn/client/
REQUIRED_CERTS=(
    "ca.crt"
    "branch-gw.crt"
    "branch-gw.key"
    "ta.key"
)

echo "[*] Kiểm tra các tệp chứng chỉ trong /etc/openvpn/client/..."
MISSING_CERT=0
for f in "${REQUIRED_CERTS[@]}"; do
    if [[ ! -f "/etc/openvpn/client/${f}" ]]; then
        echo "[ERROR] Thiếu chứng chỉ bắt buộc: /etc/openvpn/client/${f}" >&2
        MISSING_CERT=1
    fi
done

if [[ "${MISSING_CERT}" -eq 1 ]]; then
    echo "[FATAL] Hãy sao chép chứng chỉ từ HQ Gateway sang bằng lệnh:" >&2
    echo "  (Trên HQ GW): sudo bash scripts/pki/distribute-certs.sh branch-gw 172.16.1.20" >&2
    exit 1
fi

chmod 600 /etc/openvpn/client/*.key /etc/openvpn/client/ta.key 2>/dev/null || true
chmod 644 /etc/openvpn/client/*.crt 2>/dev/null || true
echo "[+] Các chứng chỉ X.509 đã sẵn sàng và được bảo vệ."

# 3. Nạp tệp cấu hình client-s2s.conf
echo "[*] Nạp tệp cấu hình ${CLIENT_S2S_DEST}..."
cp "${CLIENT_S2S_SRC}" "${CLIENT_S2S_DEST}"
bash "${SCRIPT_DIR}/common/check-openvpn-version.sh" "${CLIENT_S2S_DEST}"

# 4. Kích hoạt IP Forwarding tại tầng nhân kernel
echo "[*] Kiểm tra chuyển tiếp IPv4 kernel..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null
if [[ ! -f /etc/sysctl.d/99-vpn-forward.conf ]]; then
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-vpn-forward.conf
fi

# Apply the shared policy before starting the tunnel.
bash "${SCRIPT_DIR}/common/setup-firewall-rules.sh" branch-gw openvpn

# 6. Khởi động dịch vụ OpenVPN S2S Client
echo "[*] Khởi động dịch vụ openvpn-client@client-s2s..."
systemctl daemon-reload
systemctl enable openvpn-client@client-s2s
systemctl restart openvpn-client@client-s2s

# 7. Kiểm tra trạng thái đường hầm
sleep 3
if systemctl is-active --quiet openvpn-client@client-s2s; then
    echo "[SUCCESS] Dịch vụ OpenVPN S2S Client đang hoạt động!"
    echo "  Interface tun0 IP: $(ip -4 addr show tun0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo 'Đang thiết lập...')"
    echo "  Tuyến đường tới mạng HQ LAN:"
    ip route show | grep "10.74.10" || echo "  (Đang chờ nhận push route...)"
else
    echo "[FAILED] Dịch vụ không khởi động được. Xem chi tiết qua: journalctl -u openvpn-client@client-s2s -n 30" >&2
    exit 1
fi

echo "=============================================================================="
echo " Đã khởi động client; chạy verify-s2s.sh branch-gw để xác nhận handshake/route."
echo "=============================================================================="
