#!/usr/bin/env bash
# Dedicated IPv4 lab gateways. Shared by deploy and VPN mode switching.
set -euo pipefail
ROLE="${1:-hq-gw}"
VPN_MODE="${2:-openvpn}"
case "${ROLE}:${VPN_MODE}" in
    hq-gw:openvpn|branch-gw:openvpn|hq-gw:ipsec|branch-gw:ipsec) ;;
    *) echo "Usage: sudo bash $0 {hq-gw|branch-gw} [openvpn|ipsec]" >&2; exit 1 ;;
esac
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Chạy bằng sudo." >&2; exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lab-network.sh"
check_gateway_interfaces
if [[ "${ROLE}" == hq-gw ]]; then
    LOCAL_NET=10.74.10.0/24; REMOTE_NET=10.74.20.0/24
    LOCAL_WAN=172.16.1.10; PEER_WAN=172.16.1.20; S2S_IF=tun1
else
    LOCAL_NET=10.74.20.0/24; REMOTE_NET=10.74.10.0/24
    LOCAL_WAN=172.16.1.20; PEER_WAN=172.16.1.10; S2S_IF=tun0
fi
ensure_rule() {
    local table="$1"; shift
    iptables -w -t "${table}" -C "$@" 2>/dev/null || iptables -w -t "${table}" -A "$@"
}
# Temporary forwarding guard stays in place if a command fails mid-rebuild.
iptables -w -I FORWARD 1 -m comment --comment vpn-lab-rebuild -j DROP
# Rebuild only our chains; keep host rules. Hooks precede old broad ACCEPT rules.
for chain in VPN_LAB_FORWARD VPN_LAB_WAN_IN VPN_LAB_WAN_OUT; do
    iptables -w -N "${chain}" 2>/dev/null || true
    iptables -w -F "${chain}"
done
if [[ "${ROLE}" == hq-gw ]]; then
    iptables -w -A VPN_LAB_FORWARD -i tun0 -o "${LAN_IF}" -s 10.8.0.0/24 -d "${LOCAL_NET}" -j ACCEPT
    iptables -w -A VPN_LAB_FORWARD -i "${LAN_IF}" -o tun0 -s "${LOCAL_NET}" -d 10.8.0.0/24 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    ensure_rule nat POSTROUTING -s 10.8.0.0/24 -o "${LAN_IF}" -j MASQUERADE
fi
if [[ "${VPN_MODE}" == openvpn ]]; then
    # Permit LAN sources and tunnel endpoint sources used by gateway diagnostics.
    for source_net in "${REMOTE_NET}" 10.9.0.0/24; do
        iptables -w -A VPN_LAB_FORWARD -i "${S2S_IF}" -o "${LAN_IF}" -s "${source_net}" -d "${LOCAL_NET}" -j ACCEPT
        iptables -w -A VPN_LAB_FORWARD -i "${LAN_IF}" -o "${S2S_IF}" -s "${LOCAL_NET}" -d "${source_net}" -j ACCEPT
    done
else
    iptables -w -A VPN_LAB_FORWARD -i "${WAN_IF}" -o "${LAN_IF}" -s "${REMOTE_NET}" -d "${LOCAL_NET}" -m policy --dir in --pol ipsec --mode tunnel --tunnel-src "${PEER_WAN}" --tunnel-dst "${LOCAL_WAN}" -j ACCEPT
    iptables -w -A VPN_LAB_FORWARD -i "${LAN_IF}" -o "${WAN_IF}" -s "${LOCAL_NET}" -d "${REMOTE_NET}" -m policy --dir out --pol ipsec --mode tunnel --tunnel-src "${LOCAL_WAN}" --tunnel-dst "${PEER_WAN}" -j ACCEPT
    # Decrypted packets to a gateway's own LAN address use INPUT.
    iptables -w -A VPN_LAB_WAN_IN -s "${REMOTE_NET}" -d "${LOCAL_NET}" -m policy --dir in --pol ipsec --mode tunnel --tunnel-src "${PEER_WAN}" --tunnel-dst "${LOCAL_WAN}" -j ACCEPT
    iptables -w -A VPN_LAB_WAN_OUT -s "${LOCAL_NET}" -d "${REMOTE_NET}" -m policy --dir out --pol ipsec --mode tunnel --tunnel-src "${LOCAL_WAN}" --tunnel-dst "${PEER_WAN}" -j RETURN
    # Put IPsec NAT exemption before any legacy generic WAN masquerade.
    while iptables -w -t nat -C POSTROUTING -s "${LOCAL_NET}" -d "${REMOTE_NET}" -m policy --dir out --pol ipsec -j ACCEPT 2>/dev/null; do
        iptables -w -t nat -D POSTROUTING -s "${LOCAL_NET}" -d "${REMOTE_NET}" -m policy --dir out --pol ipsec -j ACCEPT
    done
    iptables -w -t nat -I POSTROUTING 1 -s "${LOCAL_NET}" -d "${REMOTE_NET}" -m policy --dir out --pol ipsec -j ACCEPT
fi
iptables -w -A VPN_LAB_FORWARD -j DROP
# Reject direct WAN routes to LAN/tunnel addresses, even for old tracked flows.
for net in 10.74.10.0/24 10.74.20.0/24 10.8.0.0/24 10.9.0.0/24; do
    iptables -w -A VPN_LAB_WAN_IN -s "${net}" -j DROP
    iptables -w -A VPN_LAB_WAN_IN -d "${net}" -j DROP
    iptables -w -A VPN_LAB_WAN_OUT -d "${net}" -j DROP
done
iptables -w -A VPN_LAB_WAN_OUT -j RETURN
iptables -w -A VPN_LAB_WAN_IN -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -w -A VPN_LAB_WAN_IN -s 172.16.1.0/24 -d "${LOCAL_WAN}" -p tcp --dport 22 -j ACCEPT
iptables -w -A VPN_LAB_WAN_IN -s 172.16.1.0/24 -d "${LOCAL_WAN}" -p icmp -j ACCEPT
if [[ "${ROLE}" == hq-gw ]]; then
    iptables -w -A VPN_LAB_WAN_IN -d "${LOCAL_WAN}" -p udp --dport 1194 -j ACCEPT
    if [[ "${VPN_MODE}" == openvpn ]]; then
        iptables -w -A VPN_LAB_WAN_IN -s "${PEER_WAN}" -d "${LOCAL_WAN}" -p udp --dport 1195 -j ACCEPT
    fi
fi
if [[ "${VPN_MODE}" == ipsec ]]; then
    iptables -w -A VPN_LAB_WAN_IN -s "${PEER_WAN}" -d "${LOCAL_WAN}" -p udp -m multiport --dports 500,4500 -j ACCEPT
    iptables -w -A VPN_LAB_WAN_IN -s "${PEER_WAN}" -d "${LOCAL_WAN}" -p esp -j ACCEPT
fi
iptables -w -A VPN_LAB_WAN_IN -j DROP
# Only physical WAN packets enter the WAN guards.
iptables -w -I VPN_LAB_WAN_IN 1 ! -i "${WAN_IF}" -j RETURN
iptables -w -I VPN_LAB_WAN_OUT 1 ! -o "${WAN_IF}" -j RETURN
for spec in "FORWARD VPN_LAB_FORWARD" "INPUT VPN_LAB_WAN_IN" "OUTPUT VPN_LAB_WAN_OUT"; do
    read -r parent child <<< "${spec}"
    while iptables -w -C "${parent}" -j "${child}" 2>/dev/null; do
        iptables -w -D "${parent}" -j "${child}"
    done
    iptables -w -I "${parent}" 1 -j "${child}"
done
while iptables -w -C FORWARD -m comment --comment vpn-lab-rebuild -j DROP 2>/dev/null; do
    iptables -w -D FORWARD -m comment --comment vpn-lab-rebuild -j DROP
done
ensure_rule mangle FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null
fi
echo "[OK] IPv4 firewall: ${ROLE}, ${VPN_MODE}; WAN SSH management: 172.16.1.0/24."
