#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-ipsec-branch.sh
# Mục đích: Tự động cài đặt, cấu hình và khởi chạy strongSwan IPsec IKEv2
#           phía Branch Gateway (VM-Branch-GW: 172.16.1.20).
# Đối tượng thực thi: VM-Branch-GW (Văn phòng Chi nhánh)
# Sử dụng: sudo ./deploy-ipsec-branch.sh
# ==============================================================================

set -euo pipefail

# Kiểm tra quyền root
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Vui lòng chạy script này với quyền root: sudo $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
IPSEC_CONF_SRC="${REPO_ROOT}/ipsec/strongswan/gateway-branch/ipsec.conf"
IPSEC_SECRETS_SRC="${REPO_ROOT}/ipsec/strongswan/gateway-branch/ipsec.secrets.example"

echo "=============================================================================="
echo " TRIỂN KHAI STRONGSWAN IPSEC IKEV2 (BRANCH GATEWAY - VM-BRANCH-GW)"
echo "=============================================================================="

# 1. Cài đặt các gói strongSwan nếu chưa có
if ! command -v ipsec &>/dev/null; then
    echo "[*] Đang cài đặt gói strongswan và các plugin mật mã..."
    apt update -y
    DEBIAN_FRONTEND=noninteractive apt install -y \
        strongswan \
        strongswan-pki \
        libstrongswan-extra-plugins \
        iptables-persistent \
        netfilter-persistent
fi

# 2. Tạm dừng OpenVPN S2S Client để tránh xung đột định tuyến
if systemctl is-active --quiet openvpn-client@client-s2s 2>/dev/null; then
    echo "[!] Phát hiện OpenVPN S2S Client đang chạy."
    echo "[*] Đang tạm dừng OpenVPN S2S để chuyển sang IPsec IKEv2..."
    systemctl stop openvpn-client@client-s2s
fi

# 3. Nạp cấu hình /etc/ipsec.conf
echo "[*] Nạp tệp cấu hình /etc/ipsec.conf..."
cp "${IPSEC_CONF_SRC}" /etc/ipsec.conf
chmod 644 /etc/ipsec.conf

# 4. Nạp cấu hình khóa chia sẻ trước /etc/ipsec.secrets
echo "[*] Cấu hình khóa bí mật Pre-Shared Key tại /etc/ipsec.secrets..."
if [[ ! -f /etc/ipsec.secrets ]] || ! grep -q "DuAnAnNinhMang2026" /etc/ipsec.secrets 2>/dev/null; then
    cp "${IPSEC_SECRETS_SRC}" /etc/ipsec.secrets
fi
chmod 600 /etc/ipsec.secrets
echo "[+] Phân quyền an toàn: chmod 600 /etc/ipsec.secrets"

# 5. Kích hoạt IP Forwarding
sysctl -w net.ipv4.ip_forward=1 >/dev/null

# 6. Mở cổng tường lửa cho IKEv2 và ESP
echo "[*] Thiết lập quy tắc tường lửa iptables cho IPsec..."

add_rule() {
    local table="$1"
    shift
    if ! iptables -t "${table}" -C "$@" 2>/dev/null; then
        iptables -t "${table}" -A "$@"
    fi
}

add_rule filter INPUT -i eth0 -p udp --dport 500 -j ACCEPT
add_rule filter INPUT -i eth0 -p udp --dport 4500 -j ACCEPT
add_rule filter INPUT -i eth0 -p esp -j ACCEPT
add_rule filter FORWARD -s 192.168.20.0/24 -d 192.168.10.0/24 -j ACCEPT
add_rule filter FORWARD -s 192.168.10.0/24 -d 192.168.20.0/24 -j ACCEPT

if command -v netfilter-persistent &>/dev/null; then
    netfilter-persistent save >/dev/null
fi
echo "[+] Quy tắc tường lửa cho IPsec đã được lưu vĩnh viễn."

# 7. Khởi động lại dịch vụ strongSwan
echo "[*] Khởi động dịch vụ strongSwan..."
systemctl enable strongswan --now 2>/dev/null || true
ipsec restart || systemctl restart strongswan

# 8. Chủ động khởi tạo kết nối (IKE Initiation)
sleep 2
echo "[*] Đang bắt tay thiết lập đường hầm tới HQ Gateway (172.16.1.10)..."
ipsec up branch-to-hq || true

# 9. Kiểm tra trạng thái SA
sleep 2
echo -e "\n=== TRẠNG THÁI SECURITY ASSOCIATION (IKE SA) ==="
ipsec status || true

echo "=============================================================================="
echo " TRIỂN KHAI IPSEC PHÍA CHI NHÁNH HOÀN TẤT!"
echo " Lệnh kiểm tra chi tiết: sudo ipsec statusall"
echo "=============================================================================="
