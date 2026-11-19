#!/usr/bin/env bash
# ==============================================================================
# Script: setup-firewall-rules.sh
# Mục đích: Thiết lập quy tắc tường lửa iptables ban đầu cho VPN Gateway
#           (MSS Clamping, Masquerade và chuyển tiếp gói tin)
# Cách dùng: sudo ./setup-firewall-rules.sh [hq-gw|branch-gw]
# ==============================================================================

set -euo pipefail

# Kiểm tra quyền thực thi root
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Vui lòng chạy script này với quyền root: sudo $0" >&2
    exit 1
fi

ROLE="${1:-hq-gw}"

# Hàm kiểm tra và thêm quy tắc iptables một cách an toàn (idempotent)
add_iptables_rule() {
    local table="$1"
    shift
    if ! iptables -t "${table}" -C "$@" 2>/dev/null; then
        iptables -t "${table}" -A "$@"
        echo "  [+] Đã thêm quy tắc (${table}): $*"
    else
        echo "  [.] Quy tắc đã tồn tại (${table}): $*"
    fi
}

echo "=============================================================================="
echo " Thiết lập tường lửa iptables cho node: ${ROLE}"
echo "=============================================================================="

# 1. Bật TCP MSS Clamping để chống phân mảnh gói tin khi đóng gói VPN
echo "[*] Cấu hình TCP MSS Clamping..."
add_iptables_rule mangle FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# 2. Cấu hình theo từng vai trò Gateway
if [[ "${ROLE}" == "hq-gw" || "${ROLE}" == "server" || "${ROLE}" == "vm-server" ]]; then
    echo "[*] Áp dụng quy tắc cho HQ Gateway / VM-Server (${ROLE})..."

    # Cho phép lưu lượng từ Client-to-Site (tun0) vào LAN (eth1) và ngược lại
    add_iptables_rule filter FORWARD -i tun0 -o eth1 -j ACCEPT
    add_iptables_rule filter FORWARD -i eth1 -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT

    # Cho phép lưu lượng giữa các client VPN (Client-to-Client qua tun0)
    add_iptables_rule filter FORWARD -i tun0 -o tun0 -j ACCEPT

    # Cho phép lưu lượng từ Site-to-Site (tun1) qua lại với LAN (eth1)
    add_iptables_rule filter FORWARD -i tun1 -o eth1 -j ACCEPT
    add_iptables_rule filter FORWARD -i eth1 -o tun1 -j ACCEPT

    # Cho phép lưu lượng giữa các interface LAN và WAN nếu cần
    add_iptables_rule filter FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

    # NAT Masquerade cho dải VPN Client-to-Site (10.8.0.0/24) ra mạng LAN HQ
    add_iptables_rule nat POSTROUTING -s 10.8.0.0/24 -o eth1 -j MASQUERADE

    # Mở cổng dịch vụ VPN trên card WAN (eth0)
    add_iptables_rule filter INPUT -i eth0 -p udp --dport 1194 -j ACCEPT
    add_iptables_rule filter INPUT -i eth0 -p udp --dport 1195 -j ACCEPT

    # Mở cổng Web Portal Nginx (HTTP 80 / HTTPS 443)
    add_iptables_rule filter INPUT -p tcp --dport 80 -j ACCEPT
    add_iptables_rule filter INPUT -p tcp --dport 443 -j ACCEPT

    # Mở cổng IPsec (IKEv2 & NAT-T & ESP)
    add_iptables_rule filter INPUT -i eth0 -p udp --dport 500 -j ACCEPT
    add_iptables_rule filter INPUT -i eth0 -p udp --dport 4500 -j ACCEPT
    add_iptables_rule filter INPUT -i eth0 -p esp -j ACCEPT

elif [[ "${ROLE}" == "branch-gw" || "${ROLE}" == "client-linux" || "${ROLE}" == "vm-client-linux" ]]; then
    echo "[*] Áp dụng quy tắc cho Branch Gateway / Client-Linux (${ROLE})..."

    # Cho phép chuyển tiếp giữa Site-to-Site tunnel (tun0) và LAN Branch (eth1)
    add_iptables_rule filter FORWARD -i tun0 -o eth1 -j ACCEPT
    add_iptables_rule filter FORWARD -i eth1 -o tun0 -j ACCEPT
    add_iptables_rule filter FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

    # Mở cổng dịch vụ IPsec (IKEv2 & NAT-T & ESP)
    add_iptables_rule filter INPUT -i eth0 -p udp --dport 500 -j ACCEPT
    add_iptables_rule filter INPUT -i eth0 -p udp --dport 4500 -j ACCEPT
    add_iptables_rule filter INPUT -i eth0 -p esp -j ACCEPT

else
    echo "[WARN] Không nhận diện được vai trò '${ROLE}'. Chỉ áp dụng MSS Clamping chung."
fi

# 3. Lưu quy tắc vĩnh viễn với netfilter-persistent
if command -v netfilter-persistent &> /dev/null; then
    echo "[*] Đang lưu quy tắc vào bộ nhớ vĩnh viễn (netfilter-persistent)..."
    netfilter-persistent save > /dev/null
    echo "[SUCCESS] Hoàn tất thiết lập tường lửa và đã lưu vĩnh viễn!"
else
    echo "[WARN] Chưa cài đặt netfilter-persistent. Hãy chạy: sudo apt install -y iptables-persistent netfilter-persistent"
fi

