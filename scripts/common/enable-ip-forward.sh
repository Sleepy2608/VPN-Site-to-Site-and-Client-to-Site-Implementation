#!/usr/bin/env bash
# ==============================================================================
# Script: enable-ip-forward.sh
# Mục đích: Kích hoạt chuyển tiếp gói tin IPv4 tại tầng kernel cho VPN Gateway
# Đối tượng sử dụng: VM-HQ-GW và VM-Branch-GW
# ==============================================================================

set -euo pipefail

# Kiểm tra quyền thực thi root
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Vui lòng chạy script này với quyền root: sudo $0" >&2
    exit 1
fi

SYSCTL_CONF="/etc/sysctl.d/99-vpn-forward.conf"

echo "[INFO] Đang cấu hình chuyển tiếp IPv4 kernel..."

# Đảm bảo cấu hình mang tính khả diễn (idempotent)
cat << 'EOF' > "${SYSCTL_CONF}"
# Kích hoạt IP Forwarding cho chuyển tiếp gói tin VPN
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1
EOF

# Nạp lại cấu hình sysctl vào runtime
sysctl -p "${SYSCTL_CONF}" > /dev/null

# Kiểm tra xác nhận trạng thái runtime
CURRENT_STATUS=$(sysctl -n net.ipv4.ip_forward)

if [[ "${CURRENT_STATUS}" -eq 1 ]]; then
    echo "[SUCCESS] Đã kích hoạt IPv4 forwarding thành công! (net.ipv4.ip_forward = 1)"
else
    echo "[FAILED] Không thể kích hoạt IPv4 forwarding. Trạng thái hiện tại: ${CURRENT_STATUS}" >&2
    exit 1
fi

