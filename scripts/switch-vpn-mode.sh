#!/usr/bin/env bash
# Run on BOTH gateways. Persist selected mode across reboot; keep C2S running.
set -euo pipefail
MODE="${1:-status}"
ROLE="${2:-auto}"
case "${MODE}" in openvpn|ipsec|status) ;; *) echo 'Invalid mode' >&2; exit 1 ;; esac
case "${ROLE}" in hq-gw|branch-gw|auto) ;; *) echo 'Invalid role' >&2; exit 1 ;; esac
if [[ "${EUID}" -ne 0 ]]; then echo '[ERROR] Run with sudo.' >&2; exit 1; fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${ROLE}" == auto ]]; then
    addresses="$(ip -4 -o addr show)"
    if [[ "${addresses}" == *' 172.16.1.10/'* ]]; then ROLE=hq-gw
    elif [[ "${addresses}" == *' 172.16.1.20/'* ]]; then ROLE=branch-gw
    else echo '[ERROR] Cannot identify gateway.' >&2; exit 1; fi
fi
if [[ "${ROLE}" == hq-gw ]]; then
    OPENVPN_UNIT=openvpn-server@server-s2s
    OPENVPN_CONF=/etc/openvpn/server/server-s2s.conf
else
    OPENVPN_UNIT=openvpn-client@client-s2s
    OPENVPN_CONF=/etc/openvpn/client/client-s2s.conf
fi
IPSEC_UNIT=''
for unit in strongswan-starter.service strongswan.service; do
    if systemctl cat "${unit}" >/dev/null 2>&1; then IPSEC_UNIT="${unit}"; break; fi
done
case "${MODE}" in
    openvpn)
        [[ -s "${OPENVPN_CONF}" ]] || { echo '[ERROR] Deploy OpenVPN first.' >&2; exit 1; }
        bash "${SCRIPT_DIR}/common/prepare-openvpn.sh"
        bash "${SCRIPT_DIR}/common/setup-firewall-rules.sh" "${ROLE}" openvpn
        systemctl enable "${OPENVPN_UNIT}"
        systemctl restart "${OPENVPN_UNIT}"
        systemctl is-active --quiet "${OPENVPN_UNIT}"
        ;;
    ipsec)
        [[ -n "${IPSEC_UNIT}" && -s /etc/ipsec.conf && -s /etc/ipsec.secrets ]] || { echo '[ERROR] Deploy IPsec and its private PSK first.' >&2; exit 1; }
        bash "${SCRIPT_DIR}/common/check-ipsec-secrets.sh" /etc/ipsec.secrets
        if systemctl cat "${OPENVPN_UNIT}" >/dev/null 2>&1; then
            systemctl disable --now "${OPENVPN_UNIT}"
        fi
        bash "${SCRIPT_DIR}/common/setup-firewall-rules.sh" "${ROLE}" ipsec
        systemctl enable "${IPSEC_UNIT}"
        systemctl restart "${IPSEC_UNIT}"
        systemctl is-active --quiet "${IPSEC_UNIT}"
        ;;
    status)
        systemctl is-active "${OPENVPN_UNIT}" || true
        if [[ -n "${IPSEC_UNIT}" ]]; then systemctl is-active "${IPSEC_UNIT}" || true; fi
        if command -v ipsec >/dev/null 2>&1; then ipsec status || true; fi
        exit 0
        ;;
esac
echo "[OK] ${ROLE}: ${MODE} service started. Run the same mode on the peer and verify real traffic."
