#!/usr/bin/env bash
# Revoke on the existing CA. --disconnect restarts affected server and its sessions.
set -euo pipefail
NAME="${1:-}"
ACTION="${2:-}"
if [[ ! "${NAME}" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$ || ( -n "${ACTION}" && "${ACTION}" != --disconnect ) ]]; then
    echo "Usage: sudo bash $0 CLIENT_CN [--disconnect]" >&2; exit 1
fi
if [[ "${EUID}" -ne 0 ]]; then echo '[ERROR] Run with sudo.' >&2; exit 1; fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/pki-paths.sh"
cd "${CA_DIR}"
[[ -s "pki/issued/${NAME}.crt" ]] || { echo '[ERROR] Unknown certificate.' >&2; exit 1; }
if ! openssl x509 -in "pki/issued/${NAME}.crt" -noout -purpose | grep -q '^SSL client : Yes'; then
    echo '[ERROR] This script only revokes client certificates.' >&2; exit 1
fi
./easyrsa --batch revoke "${NAME}"
./easyrsa gen-crl
openssl crl -in pki/crl.pem -noout -nextupdate
# Atomic publish prevents readers seeing a partially copied CRL.
install -m 644 pki/crl.pem /etc/openvpn/server/crl.pem.new
mv -f /etc/openvpn/server/crl.pem.new /etc/openvpn/server/crl.pem
if [[ "${ACTION}" == --disconnect ]]; then
    if [[ "${NAME}" == branch-gw ]]; then unit=openvpn-server@server-s2s
    else unit=openvpn-server@server-c2s; fi
    systemctl restart "${unit}"
fi
echo '[OK] CRL updated. New handshakes are rejected; existing sessions require disconnect/restart.'
