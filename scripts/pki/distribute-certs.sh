#!/usr/bin/env bash
# ==============================================================================
# Script: distribute-certs.sh
# Mục đích: Phân phối chứng chỉ và khóa mật mã sau khi sinh từ PKI
#           vào đúng thư mục OpenVPN Server trên HQ Gateway và đẩy sang Branch Gateway.
# Sử dụng: sudo ./distribute-certs.sh [local-server|branch-gw] [branch_ip]
# Ví dụ:   sudo ./distribute-certs.sh local-server
#          sudo ./distribute-certs.sh branch-gw 172.16.1.20
# ==============================================================================

set -euo pipefail

TARGET="${1:-all}"
BRANCH_IP="${2:-172.16.1.20}"
BRANCH_USER="${BRANCH_USER:-vpnadmin}"
CA_DIR="${CA_DIR:-${HOME}/openvpn-ca}"

# Kiểm tra thư mục PKI
if [[ ! -d "${CA_DIR}/pki" ]]; then
    echo "[ERROR] Không tìm thấy thư mục PKI tại: ${CA_DIR}" >&2
    echo "Hãy chạy scripts/pki/init-ca.sh trước." >&2
    exit 1
fi

copy_to_local_server() {
    echo "[*] Đang sao chép chứng chỉ vào /etc/openvpn/server/ trên HQ Gateway..."
    sudo mkdir -p /etc/openvpn/server /var/log/openvpn

    sudo cp "${CA_DIR}/pki/ca.crt" /etc/openvpn/server/
    sudo cp "${CA_DIR}/pki/dh.pem" /etc/openvpn/server/
    sudo cp "${CA_DIR}/ta.key" /etc/openvpn/server/
    sudo cp "${CA_DIR}/pki/crl.pem" /etc/openvpn/server/

    # Chứng chỉ C2S Server
    if [[ -f "${CA_DIR}/pki/issued/hq-c2s-server.crt" ]]; then
        sudo cp "${CA_DIR}/pki/issued/hq-c2s-server.crt" /etc/openvpn/server/
        sudo cp "${CA_DIR}/pki/private/hq-c2s-server.key" /etc/openvpn/server/
    fi

    # Chứng chỉ S2S Gateway
    if [[ -f "${CA_DIR}/pki/issued/hq-s2s-gw.crt" ]]; then
        sudo cp "${CA_DIR}/pki/issued/hq-s2s-gw.crt" /etc/openvpn/server/
        sudo cp "${CA_DIR}/pki/private/hq-s2s-gw.key" /etc/openvpn/server/
    fi

    sudo chmod 600 /etc/openvpn/server/*.key /etc/openvpn/server/ta.key
    sudo chmod 644 /etc/openvpn/server/*.crt /etc/openvpn/server/*.pem

    echo "[+] Đã nạp đầy đủ chứng chỉ cho HQ OpenVPN Server."
}

copy_to_branch_gw() {
    echo "[*] Đang chuyển chứng chỉ sang Branch Gateway (${BRANCH_USER}@${BRANCH_IP})..."

    # Tạo tệp tạm để chuyển
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    cp "${CA_DIR}/pki/ca.crt" "${tmp_dir}/"
    cp "${CA_DIR}/ta.key" "${tmp_dir}/"
    cp "${CA_DIR}/pki/issued/branch-gw.crt" "${tmp_dir}/"
    cp "${CA_DIR}/pki/private/branch-gw.key" "${tmp_dir}/"

    echo "  -> Đang gửi qua scp tới ${BRANCH_USER}@${BRANCH_IP}:/tmp/..."
    scp "${tmp_dir}/"* "${BRANCH_USER}@${BRANCH_IP}:/tmp/"

    echo "  -> Cài đặt vào /etc/openvpn/client/ trên Branch Gateway qua SSH..."
    ssh -t "${BRANCH_USER}@${BRANCH_IP}" "
        sudo mkdir -p /etc/openvpn/client
        sudo mv /tmp/ca.crt /tmp/ta.key /tmp/branch-gw.crt /tmp/branch-gw.key /etc/openvpn/client/
        sudo chmod 600 /etc/openvpn/client/*.key /etc/openvpn/client/ta.key
        sudo chmod 644 /etc/openvpn/client/*.crt
        echo '[Branch-GW] Chứng chỉ đã sẵn sàng tại /etc/openvpn/client/'
    "

    rm -rf "${tmp_dir}"
    echo "[+] Đã hoàn tất phân phối chứng chỉ sang Branch Gateway!"
}

case "${TARGET}" in
    local-server|hq)
        copy_to_local_server
        ;;
    branch-gw|branch)
        copy_to_branch_gw
        ;;
    all)
        copy_to_local_server
        echo ""
        echo "[*] Nếu muốn chuyển tự động sang Branch GW ngay bây giờ, hãy chạy:"
        echo "    sudo ./distribute-certs.sh branch-gw ${BRANCH_IP}"
        ;;
    *)
        echo "[ERROR] Lựa chọn không hợp lệ: ${TARGET}. Chọn: local-server | branch-gw | all" >&2
        exit 1
        ;;
esac
