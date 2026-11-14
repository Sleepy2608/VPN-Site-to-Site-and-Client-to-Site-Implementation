#!/usr/bin/env bash
# ==============================================================================
# Script: install-prerequisites.sh
# Mục đích: Tự động cài đặt toàn bộ gói phần mềm cần thiết cho từng máy ảo Lab
# Sử dụng: sudo ./install-prerequisites.sh [gw|server|pc]
# ==============================================================================

set -euo pipefail

# Kiểm tra quyền root
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Vui lòng chạy script này với quyền root: sudo $0" >&2
    exit 1
fi

ROLE="${1:-gw}"

echo "=============================================================================="
echo " Cài đặt gói phần mềm cho vai trò: ${ROLE}"
echo "=============================================================================="

# Cập nhật danh mục gói
echo "[*] Đang cập nhật danh mục gói hệ thống..."
apt update -y

case "${ROLE}" in
    gw|gateway)
        echo "[*] Cài đặt gói cho VPN Gateway (OpenVPN, strongSwan, iptables, tools)..."
        DEBIAN_FRONTEND=noninteractive apt install -y \
            openvpn \
            easy-rsa \
            strongswan \
            strongswan-pki \
            libstrongswan-extra-plugins \
            iptables \
            iptables-persistent \
            netfilter-persistent \
            net-tools \
            tcpdump \
            traceroute \
            curl \
            chrony
        ;;
    server)
        echo "[*] Cài đặt gói cho Internal Server (Nginx, curl, chrony)..."
        DEBIAN_FRONTEND=noninteractive apt install -y \
            nginx \
            curl \
            net-tools \
            traceroute \
            chrony
        ;;
    pc|client)
        echo "[*] Cài đặt gói cho Client Host (net-tools, curl, traceroute)..."
        DEBIAN_FRONTEND=noninteractive apt install -y \
            net-tools \
            traceroute \
            curl \
            chrony
        ;;
    *)
        echo "[ERROR] Vai trò không hợp lệ: '${ROLE}'. Chọn: gw | server | pc" >&2
        exit 1
        ;;
esac

# Đồng bộ thời gian hệ thống qua chrony (quan trọng cho chứng chỉ số X.509)
if systemctl list-unit-files | grep -q "chrony.service"; then
    echo "[*] Kích hoạt và đồng bộ thời gian hệ thống bằng chrony..."
    systemctl enable chrony --now
    systemctl restart chrony
    chronyc tracking || true
fi

echo "[SUCCESS] Hoàn tất cài đặt gói phần mềm cho ${ROLE}!"

