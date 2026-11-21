#!/usr/bin/env bash
# Optional IPsec extension; configure an actual shared secret on both gateways.
set -euo pipefail
ROLE="${1:-}"
case "${ROLE}" in hq-gw) SIDE=hq ;; branch-gw) SIDE=branch ;; *) exit 1 ;; esac
if [[ "${EUID}" -ne 0 ]]; then echo '[ERROR] Run with sudo.' >&2; exit 1; fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/lab-network.sh"
check_gateway_interfaces
PSK_FILE="${PSK_FILE:-/etc/vpn-lab/ipsec.secrets}"
bash "${SCRIPT_DIR}/check-ipsec-secrets.sh" "${PSK_FILE}"
# Ubuntu's strongswan metapackage can install charon-systemd/swanctl, which
# does not read the ipsec.conf and ipsec.secrets used by this lab.
if ! systemctl cat strongswan-starter.service >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y strongswan-starter strongswan-charon libstrongswan-extra-plugins iptables-persistent netfilter-persistent
fi
install -m 644 "${REPO_ROOT}/ipsec/strongswan/gateway-${SIDE}/ipsec.conf" /etc/ipsec.conf
# Avoid copying a file onto itself if PSK_FILE already points to /etc/ipsec.secrets.
if [[ ! "${PSK_FILE}" -ef /etc/ipsec.secrets ]]; then
    install -m 600 "${PSK_FILE}" /etc/ipsec.secrets
else
    chmod 600 /etc/ipsec.secrets
fi
bash "${SCRIPT_DIR}/enable-ip-forward.sh"
bash "${SCRIPT_DIR}/../switch-vpn-mode.sh" ipsec "${ROLE}"
echo '[OK] IPsec service configured. Deploy both ends, then run verify-ipsec.sh and LAN-to-LAN tests.'
