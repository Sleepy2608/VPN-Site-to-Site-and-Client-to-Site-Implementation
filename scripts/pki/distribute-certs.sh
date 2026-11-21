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
BRANCH_USER="${BRANCH_USER:-${SUDO_USER:-${USER}}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/pki-paths.sh"

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

    if [[ ! "${BRANCH_USER}" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ || ! "${BRANCH_IP}" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
        echo '[ERROR] Invalid SSH user/host.' >&2; exit 1
    fi
    # Private staging dirs on BOTH hosts; never put predictable key names in /tmp.
    local tmp_dir remote_dir
    tmp_dir="$(mktemp -d)"
    trap "rm -rf -- '${tmp_dir}'" EXIT
    for file in ca.crt ta.key branch-gw.crt branch-gw.key; do
        case "${file}" in
            ca.crt) src="${CA_DIR}/pki/ca.crt" ;;
            ta.key) src="${CA_DIR}/ta.key" ;;
            branch-gw.crt) src="${CA_DIR}/pki/issued/branch-gw.crt" ;;
            branch-gw.key) src="${CA_DIR}/pki/private/branch-gw.key" ;;
        esac
        install -m 600 "${src}" "${tmp_dir}/${file}"
    done
    remote_dir="$(ssh "${BRANCH_USER}@${BRANCH_IP}" 'umask 077; mktemp -d /tmp/vpn-lab.XXXXXXXXXX')"
    if [[ ! "${remote_dir}" =~ ^/tmp/vpn-lab[.][a-zA-Z0-9]{10}$ ]]; then
        echo '[ERROR] Invalid remote staging path.' >&2; exit 1
    fi
    if ! scp -p "${tmp_dir}/"* "${BRANCH_USER}@${BRANCH_IP}:${remote_dir}/"; then
        ssh "${BRANCH_USER}@${BRANCH_IP}" "rm -rf -- '${remote_dir}'" || true
        exit 1
    fi
    ssh -t "${BRANCH_USER}@${BRANCH_IP}" "
        set -eu
        trap 'rm -rf -- ${remote_dir}' EXIT
        sudo install -d -m 755 /etc/openvpn/client
        sudo install -m 644 ${remote_dir}/ca.crt ${remote_dir}/branch-gw.crt /etc/openvpn/client/
        sudo install -m 600 ${remote_dir}/ta.key ${remote_dir}/branch-gw.key /etc/openvpn/client/
    "
    rm -rf -- "${tmp_dir}"
    trap - EXIT
    echo '[OK] Branch certificates installed without transferring the CA private key.'

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

