#!/usr/bin/env bash
# OpenVPN 2.5+ supports the lab cipher settings. Disable DCO only where supported.
# Optional argument: installed config path to keep lab TUN captures predictable.
set -euo pipefail
version="$(openvpn --version | sed -n '1s/^OpenVPN \([^ ]*\).*/\1/p')"
if [[ -z "${version}" ]] || ! dpkg --compare-versions "${version}" ge 2.5; then
    echo "[ERROR] Lab requires OpenVPN >=2.5; installed: ${version:-unknown}." >&2
    exit 1
fi
if [[ -n "${1:-}" ]] && dpkg --compare-versions "${version}" ge 2.6; then
    grep -qx 'disable-dco' "$1" || echo 'disable-dco' >> "$1"
fi
