#!/usr/bin/env bash
# Five-node model only; server mode requires a connected remote employee.
set -euo pipefail
MODE="${1:-auto}"
case "${MODE}" in server|client|auto) ;; *) echo "Invalid role: ${MODE}" >&2; exit 1 ;; esac
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common/verification.sh"
if [[ "${MODE}" == auto ]]; then
    if [[ -f /etc/openvpn/server/server-c2s.conf ]]; then MODE=server; else MODE=client; fi
fi
if [[ "${MODE}" == server ]]; then
    source "${SCRIPT_DIR}/common/lab-network.sh"
    check 'C2S service active' systemctl is-active --quiet openvpn-server@server-c2s
    check 'tun0 has 10.8.0.1' interface_has tun0 '10[.]8[.]0[.]1'
    check 'IPv4 forwarding enabled' test "$(sysctl -n net.ipv4.ip_forward)" = 1
    check 'VPN firewall hook installed' iptables -C FORWARD -j VPN_LAB_FORWARD
    check 'C2S NAT toward HQ LAN installed' iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o "${LAN_IF}" -j MASQUERADE
    check 'client1 present in fresh status log (connect Windows first, wait 5s)' connected_client /var/log/openvpn/openvpn-c2s-status.log client1
else
    route="$(ip -4 route get 10.74.10.50)" || route=''
    echo "${route}"
    # Linux C2S diagnostic only. Windows uses verify-c2s-windows.ps1.
    device="$(awk '{for(i=1;i<NF;i++) if($i=="dev") print $(i+1)}' <<< "${route}")"
    if [[ "${device}" == tun* ]]; then record_pass 'HQ route uses TUN'; else record_fail 'HQ route must use TUN'; fi
    check 'Tunnel gateway reachable' ping -c 2 -W 2 10.8.0.1
    check 'HQ server reachable' ping -c 2 -W 2 10.74.10.50
    check 'HQ portal HTTP 200' http_ok http://10.74.10.50/
fi
finish_checks
