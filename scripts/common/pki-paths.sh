#!/usr/bin/env bash
# Dùng chung đường dẫn PKI cho lệnh thường và lệnh chạy qua sudo.
# Source tệp này sau khi bật set -euo pipefail; không chạy độc lập.
LAB_USER_HOME="${HOME}"
if [[ -n "${SUDO_USER:-}" ]]; then
    LAB_USER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
    if [[ -z "${LAB_USER_HOME}" ]]; then
        echo "[ERROR] Không tìm được home của ${SUDO_USER}." >&2
        return 1
    fi
fi
export CA_DIR="${CA_DIR:-${LAB_USER_HOME}/openvpn-ca}"
