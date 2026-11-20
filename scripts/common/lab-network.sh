#!/usr/bin/env bash
# Source để dùng tên NIC thực tế trên Armbian/VMware. Không áp dụng IP/Netplan.
# File tùy chọn: /etc/vpn-lab/interfaces.conf, mỗi dòng WAN_IF=... hoặc LAN_IF=...
VPN_LAB_INTERFACES_FILE="${VPN_LAB_INTERFACES_FILE:-/etc/vpn-lab/interfaces.conf}"
_lab_wan="eth0"
_lab_lan="eth1"
if [[ -f "${VPN_LAB_INTERFACES_FILE}" ]]; then
    while IFS='=' read -r _lab_key _lab_value || [[ -n "${_lab_key}" ]]; do
        case "${_lab_key}" in
            ''|\#*) continue ;;
            WAN_IF) _lab_wan="${_lab_value}" ;;
            LAN_IF) _lab_lan="${_lab_value}" ;;
            *) echo "[ERROR] Khóa NIC không hợp lệ trong ${VPN_LAB_INTERFACES_FILE}: ${_lab_key}" >&2; return 1 ;;
        esac
    done < "${VPN_LAB_INTERFACES_FILE}"
fi
export WAN_IF="${WAN_IF:-${_lab_wan}}"
export LAN_IF="${LAN_IF:-${_lab_lan}}"
for _lab_iface in "${WAN_IF}" "${LAN_IF}"; do
    if [[ ! "${_lab_iface}" =~ ^[a-zA-Z0-9_.:-]{1,15}$ ]]; then
        echo "[ERROR] Tên interface không hợp lệ: ${_lab_iface}" >&2
        return 1
    fi
done
if [[ "${WAN_IF}" == "${LAN_IF}" ]]; then
    echo "[ERROR] WAN_IF và LAN_IF của gateway phải khác nhau." >&2
    return 1
fi

check_gateway_interfaces() {
    local iface
    for iface in "${WAN_IF}" "${LAN_IF}"; do
        if ! ip link show dev "${iface}" >/dev/null 2>&1; then
            echo "[ERROR] Không tìm thấy card ${iface}; kiểm tra ip -br link và ${VPN_LAB_INTERFACES_FILE}." >&2
            return 1
        fi
    done
}
unset _lab_wan _lab_lan _lab_key _lab_value _lab_iface
