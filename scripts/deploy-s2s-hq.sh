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
source "${SCRIPT_DIR}/common/pki-paths.sh"
source "${SCRIPT_DIR}/common/lab-network.sh"
check_gateway_interfaces

echo "=============================================================================="
echo " TRIỂN KHAI OPENVPN SITE-TO-SITE SERVER (HQ GATEWAY - VM-HQ-GW)"
echo "=============================================================================="

bash "${SCRIPT_DIR}/common/check-openvpn-version.sh"

# 1. Đảm bảo các thư mục cấu hình và log tồn tại
mkdir -p /etc/openvpn/server "${CCD_DEST}" /var/log/openvpn

# Standalone S2S deploy also needs CA, DH, TLS key and current CRL.
for file in ca.crt dh.pem crl.pem hq-s2s-gw.crt hq-s2s-gw.key ta.key; do
    case "${file}" in
        hq-s2s-gw.crt) src="${CA_DIR}/pki/issued/${file}" ;;
        hq-s2s-gw.key) src="${CA_DIR}/pki/private/${file}" ;;
        ta.key) src="${CA_DIR}/${file}" ;;
        *) src="${CA_DIR}/pki/${file}" ;;
    esac
    mode=644
    [[ "${file}" != *.key ]] || mode=600
    if [[ -f "${src}" ]]; then
        install -m "${mode}" "${src}" "/etc/openvpn/server/${file}"
    elif [[ ! -s "/etc/openvpn/server/${file}" ]]; then
        echo "[ERROR] Missing ${file}; run scripts/pki/init-ca.sh first." >&2
        exit 1
    fi
done

# 3. Nạp cấu hình CCD (Client Config Directory) - Rất quan trọng cho S2S
echo "[*] Thiết lập Client Config Directory (CCD) tại ${CCD_DEST}..."
install -m 644 "${CCD_SRC}/branch-gw" "${CCD_DEST}/branch-gw"
# Remove the obsolete alias that used to authorize another CN.
rm -f "${CCD_DEST}/branch-gateway"
chmod 644 "${CCD_DEST}"/*
echo "[+] Đã cấu hình chỉ thị iroute cho branch-gw: $(cat "${CCD_DEST}/branch-gw")"

# 4. Sao chép tệp cấu hình server-s2s.conf
echo "[*] Nạp tệp cấu hình ${SERVER_S2S_DEST}..."
cp "${SERVER_S2S_SRC}" "${SERVER_S2S_DEST}"
bash "${SCRIPT_DIR}/common/check-openvpn-version.sh" "${SERVER_S2S_DEST}"

# Apply the shared policy before starting the tunnel.
bash "${SCRIPT_DIR}/common/setup-firewall-rules.sh" hq-gw openvpn

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
