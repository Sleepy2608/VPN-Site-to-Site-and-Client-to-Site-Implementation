#!/usr/bin/env bash
# Dừng và tắt tự khởi động IPsec từ các lần triển khai lab cũ.
set -euo pipefail
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Chạy bằng sudo." >&2
    exit 1
fi

# Ubuntu ipsec.conf dùng starter; một số bản cài dùng tên strongswan.service.
if command -v ipsec >/dev/null 2>&1 && ipsec status >/dev/null 2>&1; then
    ipsec stop
fi
for unit in strongswan-starter.service strongswan.service; do
    if systemctl cat "${unit}" >/dev/null 2>&1; then
        systemctl disable --now "${unit}"
    fi
done
echo "[OK] Lab sử dụng OpenVPN cho C2S và S2S."
