#!/usr/bin/env bash
# Verify both host sides separately; a gateway-only ping is insufficient.
set -euo pipefail
ROLE="${1:-auto}"
case "${ROLE}" in hq-gw|branch-gw|hq-server|branch-pc|auto) ;; *) echo "Invalid role: ${ROLE}" >&2; exit 1 ;; esac
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common/verification.sh"
if [[ "${ROLE}" == auto ]]; then
    addresses="$(ip -4 -o addr show)"
    if [[ "${addresses}" == *' 172.16.1.10/'* ]]; then ROLE=hq-gw
    elif [[ "${addresses}" == *' 172.16.1.20/'* ]]; then ROLE=branch-gw
    elif [[ "${addresses}" == *' 192.168.10.50/'* ]]; then ROLE=hq-server
    elif [[ "${addresses}" == *' 192.168.20.50/'* ]]; then ROLE=branch-pc
    else echo '[ERROR] Cannot identify node; specify role.' >&2; exit 1; fi
fi
echo "Node: ${ROLE}"
case "${ROLE}" in
    hq-gw)
        check 'HQ S2S service' systemctl is-active --quiet openvpn-server@server-s2s
        check 'HQ S2S address' interface_has tun1 '10[.]9[.]0[.]1'
        check 'Branch host route via tun1' route_uses 192.168.20.50 tun1
        check 'branch-gw connected, status age <=30s' connected_client /var/log/openvpn/openvpn-s2s-status.log branch-gw
        check 'Branch tunnel endpoint reachable' ping -c 2 -W 2 10.9.0.2
        check 'HQ LAN source reaches Branch host' ping -I 192.168.10.1 -c 2 -W 2 192.168.20.50
        ;;
    branch-gw)
        check 'Branch S2S service' systemctl is-active --quiet openvpn-client@client-s2s
        check 'Branch S2S address' interface_has tun0 '10[.]9[.]0[.]2'
        check 'HQ host route via tun0' route_uses 192.168.10.50 tun0
        check 'HQ tunnel endpoint reachable' ping -c 2 -W 2 10.9.0.1
        check 'Branch LAN source reaches HQ host' ping -I 192.168.20.1 -c 2 -W 2 192.168.10.50
        ;;
    branch-pc)
        check 'HQ host reachable from Branch host' ping -c 3 -W 2 192.168.10.50
        check 'HQ portal from Branch host' http_ok http://192.168.10.50/
        ;;
    hq-server)
        check 'Branch host reachable from HQ host (reverse initiation)' ping -c 3 -W 2 192.168.20.50
        ;;
esac
finish_checks
