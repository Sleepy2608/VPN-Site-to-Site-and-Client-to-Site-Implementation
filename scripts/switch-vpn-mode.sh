#!/usr/bin/env bash
# ==============================================================================
# Script: switch-vpn-mode.sh
# Mục đích: Chuyển đổi nhanh và an toàn giữa hai mô hình Site-to-Site VPN
#           (OpenVPN Routed Tunnel vs strongSwan IPsec IKEv2) trên Gateway
#           để tránh xung đột định tuyến khi thực hành Lab.
# Sử dụng: sudo ./switch-vpn-mode.sh [openvpn|ipsec|status]
# ==============================================================================

set -euo pipefail

# Kiểm tra quyền root
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Vui lòng chạy script này với quyền root: sudo $0" >&2
    exit 1
fi

MODE="${1:-status}"

# Tự nhận diện vai trò Gateway
IS_HQ=0
if ip addr show 2>/dev/null | grep -q "172.16.1.10"; then
    IS_HQ=1
fi

case "${MODE}" in
    openvpn)
        echo "=============================================================================="
        echo " CHUYỂN SANG CHẾ ĐỘ: OPENVPN SITE-TO-SITE ROUTED TUNNEL"
        echo "=============================================================================="

        # 1. Dừng strongSwan IPsec
        echo "[*] Dừng dịch vụ strongSwan IPsec..."
        ipsec stop 2>/dev/null || true
        systemctl stop strongswan 2>/dev/null || true

        # 2. Khởi động OpenVPN S2S tương ứng
        if [[ "${IS_HQ}" -eq 1 ]]; then
            echo "[*] Khởi động OpenVPN S2S Server trên HQ Gateway..."
            systemctl start openvpn-server@server-s2s
            sleep 2
            systemctl is-active openvpn-server@server-s2s
        else
            echo "[*] Khởi động OpenVPN S2S Client trên Branch Gateway..."
            systemctl start openvpn-client@client-s2s
            sleep 2
            systemctl is-active openvpn-client@client-s2s
        fi
        echo "[SUCCESS] Đã kích hoạt chế độ OpenVPN Site-to-Site thành công!"
        ;;

    ipsec)
        echo "=============================================================================="
        echo " CHUYỂN SANG CHẾ ĐỘ: STRONGSWAN IPSEC IKEV2 TUNNEL"
        echo "=============================================================================="

        # 1. Dừng OpenVPN S2S tương ứng
        if [[ "${IS_HQ}" -eq 1 ]]; then
            echo "[*] Dừng dịch vụ OpenVPN S2S Server..."
            systemctl stop openvpn-server@server-s2s 2>/dev/null || true
        else
            echo "[*] Dừng dịch vụ OpenVPN S2S Client..."
            systemctl stop openvpn-client@client-s2s 2>/dev/null || true
        fi

        # 2. Khởi động strongSwan IPsec
        echo "[*] Khởi động dịch vụ strongSwan..."
        systemctl start strongswan 2>/dev/null || ipsec start
        sleep 2

        if [[ "${IS_HQ}" -eq 0 ]]; then
            echo "[*] Branch Gateway đang bắt tay IKEv2..."
            ipsec up branch-to-hq || true
        fi

        echo "[SUCCESS] Đã kích hoạt chế độ strongSwan IPsec IKEv2 thành công!"
        ipsec status || true
        ;;

    status)
        echo "=============================================================================="
        echo " TRẠNG THÁI HIỆN TẠI CỦA CÁC DỊCH VỤ VPN SITE-TO-SITE"
        echo "=============================================================================="
        echo -n "  - OpenVPN S2S Service: "
        if [[ "${IS_HQ}" -eq 1 ]]; then
            if systemctl is-active --quiet openvpn-server@server-s2s 2>/dev/null; then
                echo "RUNNING (ACTIVE)"
            else
                echo "STOPPED"
            fi
        else
            if systemctl is-active --quiet openvpn-client@client-s2s 2>/dev/null; then
                echo "RUNNING (ACTIVE)"
            else
                echo "STOPPED"
            fi
        fi

        echo -n "  - strongSwan IPsec Service: "
        if ipsec status 2>/dev/null | grep -q "Security Associations"; then
            echo "RUNNING (ACTIVE)"
            ipsec status | head -n 3
        else
            echo "STOPPED"
        fi
        echo ""
        echo "Cách chuyển đổi: sudo $0 [openvpn | ipsec]"
        ;;

    *)
        echo "[ERROR] Lựa chọn không hợp lệ: '${MODE}'. Sử dụng: openvpn | ipsec | status" >&2
        exit 1
        ;;
esac
