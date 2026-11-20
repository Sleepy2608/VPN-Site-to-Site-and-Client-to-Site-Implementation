#!/usr/bin/env bash
# Optional IPsec lab: require this connection's SA and exact LAN selectors.
set -euo pipefail
ROLE="${1:-auto}"
case "${ROLE}" in hq-gw|branch-gw|hq-server|branch-pc|auto) ;; *) echo 'Invalid role' >&2; exit 1 ;; esac
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common/verification.sh"
if [[ "${ROLE}" == auto ]]; then
    addresses="$(ip -4 -o addr show)"
    if [[ "${addresses}" == *' 172.16.1.10/'* ]]; then ROLE=hq-gw
    elif [[ "${addresses}" == *' 172.16.1.20/'* ]]; then ROLE=branch-gw
    elif [[ "${addresses}" == *' 192.168.10.50/'* ]]; then ROLE=hq-server
    elif [[ "${addresses}" == *' 192.168.20.50/'* ]]; then ROLE=branch-pc
    else echo '[ERROR] Cannot identify node.' >&2; exit 1; fi
fi
policy_matches() {
    ip xfrm policy | awk -v src="$1" -v dst="$2" -v dir="$3" -v peer_src="$4" -v peer_dst="$5" '
        $1 == "src" {selected=($2==src && $4==dst); direction=0; endpoints=0}
        selected && $1 == "dir" {direction=($2==dir)}
        selected && $1 == "tmpl" {endpoints=($3==peer_src && $5==peer_dst)}
        selected && direction && endpoints && /proto esp/ && /mode tunnel/ {found=1}
        END {exit !found}
    '
}
if [[ "${ROLE}" == hq-gw || "${ROLE}" == branch-gw ]]; then
    if [[ "${ROLE}" == hq-gw ]]; then
        connection=hq-to-branch; local_net=192.168.10.0/24; remote_net=192.168.20.0/24
        local_wan=172.16.1.10; remote_wan=172.16.1.20; local_lan=192.168.10.1; remote_host=192.168.20.50
    else
        connection=branch-to-hq; local_net=192.168.20.0/24; remote_net=192.168.10.0/24
        local_wan=172.16.1.20; remote_wan=172.16.1.10; local_lan=192.168.20.1; remote_host=192.168.10.50
    fi
    status="$(ipsec status)" || status=''
    check 'Expected IKE SA established' grep -Eq "^[[:space:]]*${connection}\[[0-9]+\]:.*ESTABLISHED" <<< "${status}"
    check 'Expected CHILD SA installed in tunnel mode' grep -Eq "^[[:space:]]*${connection}\{[0-9]+\}:.*INSTALLED, TUNNEL" <<< "${status}"
    check 'Outbound XFRM selectors and endpoints' policy_matches "${local_net}" "${remote_net}" out "${local_wan}" "${remote_wan}"
    check 'Inbound XFRM selectors and endpoints' policy_matches "${remote_net}" "${local_net}" in "${remote_wan}" "${local_wan}"
    check 'Forwarded XFRM selectors and endpoints' policy_matches "${remote_net}" "${local_net}" fwd "${remote_wan}" "${local_wan}"
    check 'LAN source reaches peer LAN host' ping -I "${local_lan}" -c 3 -W 2 "${remote_host}"
elif [[ "${ROLE}" == branch-pc ]]; then
    check 'HQ host reachable' ping -c 3 -W 2 192.168.10.50
    check 'HQ HTTP 200' http_ok http://192.168.10.50/
else
    check 'Branch host reachable from HQ host' ping -c 3 -W 2 192.168.20.50
fi
finish_checks
