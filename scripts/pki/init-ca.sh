#!/usr/bin/env bash
# ==============================================================================
# Script: init-ca.sh
# Mục đích: Tự động khởi tạo Certificate Authority (CA) với Easy-RSA 3,
#           sinh tham số Diffie-Hellman, khóa TLS-Crypt và cấp phát chứng chỉ
#           cho toàn bộ thực thể trong mô hình VPN Lab.
# Đối tượng thực hiện: VM-HQ-GW (hoặc máy chủ PKI chuyên dụng)
# ==============================================================================

set -euo pipefail

CA_DIR="${1:-${HOME}/openvpn-ca}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "=============================================================================="
echo " KHỞI TẠO HẠ TẦNG KHÓA CÔNG KHAI PKI (EASY-RSA 3)"
echo " Thư mục làm việc: ${CA_DIR}"
echo "=============================================================================="

# 1. Kiểm tra công cụ cần thiết
if ! command -v easyrsa &>/dev/null && [[ ! -f "/usr/share/easy-rsa/easyrsa" ]]; then
    echo "[*] Đang cài đặt gói easy-rsa và openvpn..."
    sudo apt update -y
    sudo apt install -y easy-rsa openvpn
fi

# 2. Tạo thư mục làm việc CA nếu chưa có
if [[ ! -d "${CA_DIR}" ]]; then
    echo "[*] Thiết lập thư mục CA từ mẫu hệ thống..."
    make-cadir "${CA_DIR}"
fi

cd "${CA_DIR}"

# 3. Nạp cấu hình biến môi trường vars
VARS_SRC="${REPO_ROOT}/openvpn/pki/vars.example"
if [[ -f "${VARS_SRC}" ]]; then
    echo "[*] Sao chép cấu hình vars từ repository..."
    cp "${VARS_SRC}" "${CA_DIR}/vars"
else
    echo "[*] Tạo tệp vars cấu hình mặc định..."
    cat << 'EOF' > "${CA_DIR}/vars"
set_var EASYRSA_REQ_COUNTRY    "VN"
set_var EASYRSA_REQ_PROVINCE   "Danang"
set_var EASYRSA_REQ_CITY       "Danang"
set_var EASYRSA_REQ_ORG        "CyberSec-VPN-Lab"
set_var EASYRSA_REQ_EMAIL      "admin@corp.vpn.internal"
set_var EASYRSA_REQ_OU         "Security-Operations"
set_var EASYRSA_ALGO           rsa
set_var EASYRSA_KEY_SIZE       2048
set_var EASYRSA_CA_EXPIRE      3650
set_var EASYRSA_CERT_EXPIRE    825
set_var EASYRSA_CRL_DAYS       180
set_var EASYRSA_BATCH          "1"
EOF
fi

# 4. Khởi tạo PKI sạch
if [[ ! -d "${CA_DIR}/pki" ]]; then
    echo "[*] Khởi tạo cấu trúc PKI mới..."
    ./easyrsa init-pki
else
    echo "[.] Cấu trúc PKI đã tồn tại, tiếp tục các bước kế tiếp."
fi

# 5. Xây dựng Root CA (nopass cho môi trường thực nghiệm lab)
if [[ ! -f "${CA_DIR}/pki/ca.crt" ]]; then
    echo "[*] Xây dựng Root Certificate Authority..."
    ./easyrsa --batch build-ca nopass
    echo "[+] Đã tạo Root CA thành công: pki/ca.crt"
else
    echo "[.] Root CA đã tồn tại: pki/ca.crt"
fi

# 6. Sinh tham số trao đổi khóa Diffie-Hellman (dh.pem)
if [[ ! -f "${CA_DIR}/pki/dh.pem" ]]; then
    echo "[*] Đang sinh tham số Diffie-Hellman 2048-bit (dh.pem)..."
    ./easyrsa gen-dh
    echo "[+] Đã tạo dh.pem thành công."
else
    echo "[.] Tham số Diffie-Hellman đã sẵn sàng."
fi

# 7. Sinh khóa bảo vệ kênh điều khiển TLS-Crypt (ta.key)
if [[ ! -f "${CA_DIR}/ta.key" ]]; then
    echo "[*] Đang sinh khóa bảo vệ TLS-Crypt (ta.key)..."
    openvpn --genkey secret "${CA_DIR}/ta.key"
    echo "[+] Đã tạo ta.key thành công."
else
    echo "[.] Khóa ta.key đã sẵn sàng."
fi

# 8. Khởi tạo danh sách thu hồi chứng chỉ (CRL)
if [[ ! -f "${CA_DIR}/pki/crl.pem" ]]; then
    echo "[*] Khởi tạo danh sách thu hồi chứng chỉ (crl.pem)..."
    ./easyrsa gen-crl
    echo "[+] Đã tạo crl.pem thành công."
fi

# 9. Hàm tiện ích sinh và ký chứng chỉ tự động
issue_cert() {
    local cert_name="$1"
    local cert_type="$2" # server hoặc client

    if [[ ! -f "${CA_DIR}/pki/issued/${cert_name}.crt" ]]; then
        echo "[*] Đang tạo yêu cầu và ký chứng chỉ [${cert_type}]: ${cert_name}..."
        ./easyrsa --batch gen-req "${cert_name}" nopass
        ./easyrsa --batch sign-req "${cert_type}" "${cert_name}"
        echo "  [+] Đã phát hành: pki/issued/${cert_name}.crt"
    else
        echo "  [.] Chứng chỉ ${cert_name}.crt đã tồn tại."
    fi
}

echo -e "\n=== CẤP PHÁT CHỨNG CHỈ CHO CÁC THỰC THỂ ==="
# Cấp chứng chỉ cho Server C2S (Remote Access)
issue_cert "hq-c2s-server" "server"

# Cấp chứng chỉ cho HQ Gateway (Site-to-Site)
issue_cert "hq-s2s-gw" "server"

# Cấp chứng chỉ cho máy trạm từ xa (Remote Client Windows / client1)
issue_cert "client1" "client"
issue_cert "client-windows" "client"

# Cấp chứng chỉ cho máy khách Linux (Remote Client Linux)
issue_cert "client-linux" "client"

# Cấp chứng chỉ cho Branch Gateway (Site-to-Site Endpoint)
issue_cert "branch-gw" "client"

# 10. Phân quyền bảo mật nghiêm ngặt
echo -e "\n[*] Phân quyền bảo mật hệ thống tệp tin PKI..."
chmod 700 "${CA_DIR}/pki/private"
chmod 600 "${CA_DIR}/pki/private/"*.key "${CA_DIR}/ta.key"
chmod 644 "${CA_DIR}/pki/ca.crt" "${CA_DIR}/pki/dh.pem" "${CA_DIR}/pki/crl.pem"
chmod 644 "${CA_DIR}/pki/issued/"*.crt

echo "=============================================================================="
echo " [SUCCESS] HẠ TẦNG PKI ĐÃ ĐƯỢC THIẾT LẬP HOÀN TẤT!"
echo " Danh mục chứng chỉ sẵn sàng tại: ${CA_DIR}/pki/issued/"
ls -la "${CA_DIR}/pki/issued/"
echo "=============================================================================="

