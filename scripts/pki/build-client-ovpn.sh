#!/usr/bin/env bash
# ==============================================================================
# Script: build-client-ovpn.sh
# Mục đích: Tự động trích xuất chứng chỉ và đóng gói thành tệp cấu hình
#           OpenVPN độc lập (.ovpn) nhúng chứng chỉ inline cho người dùng từ xa.
# Sử dụng: ./build-client-ovpn.sh [client_name] [output_path]
# Ví dụ:   ./build-client-ovpn.sh client1 ~/client1.ovpn
# ==============================================================================

set -euo pipefail

CLIENT_NAME="${1:-client1}"
OUTPUT_FILE="${2:-${HOME}/${CLIENT_NAME}.ovpn}"
CA_DIR="${CA_DIR:-${HOME}/openvpn-ca}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEMPLATE_FILE="${REPO_ROOT}/openvpn/client-to-site/client/template.ovpn"

echo "=============================================================================="
echo " ĐÓNG GÓI HỒ SƠ KẾT NỐI OPENVPN CLIENT (.OVPN)"
echo " Tên máy khách: ${CLIENT_NAME}"
echo " Tệp xuất ra:   ${OUTPUT_FILE}"
echo "=============================================================================="

# 1. Kiểm tra sự tồn tại của các tệp chứng chỉ và khóa
CA_CRT="${CA_DIR}/pki/ca.crt"
CLIENT_CRT="${CA_DIR}/pki/issued/${CLIENT_NAME}.crt"
CLIENT_KEY="${CA_DIR}/pki/private/${CLIENT_NAME}.key"
TLS_KEY="${CA_DIR}/ta.key"

for f in "${CA_CRT}" "${CLIENT_CRT}" "${CLIENT_KEY}" "${TLS_KEY}"; do
    if [[ ! -f "${f}" ]]; then
        echo "[ERROR] Không tìm thấy tệp bắt buộc: ${f}" >&2
        echo "Vui lòng chạy script 'scripts/pki/init-ca.sh' trước khi tạo profile." >&2
        exit 1
    fi
done

# 2. Tạo nội dung tệp profile
TMP_OUTPUT="$(mktemp)"

# Nạp template cấu hình cơ sở
if [[ -f "${TEMPLATE_FILE}" ]]; then
    cat "${TEMPLATE_FILE}" > "${TMP_OUTPUT}"
else
    cat << 'EOF' > "${TMP_OUTPUT}"
client
dev tun
proto udp
remote 172.16.1.10 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
verb 3
EOF
fi

# 3. Nhúng các khối chứng chỉ inline
echo -e "\n<ca>" >> "${TMP_OUTPUT}"
cat "${CA_CRT}" >> "${TMP_OUTPUT}"
echo -e "</ca>" >> "${TMP_OUTPUT}"

echo -e "\n<cert>" >> "${TMP_OUTPUT}"
# Chỉ lấy khối chứng chỉ X.509 thực tế, bỏ qua phần text metadata
sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' "${CLIENT_CRT}" >> "${TMP_OUTPUT}"
echo -e "</cert>" >> "${TMP_OUTPUT}"

echo -e "\n<key>" >> "${TMP_OUTPUT}"
cat "${CLIENT_KEY}" >> "${TMP_OUTPUT}"
echo -e "</key>" >> "${TMP_OUTPUT}"

echo -e "\n<tls-crypt>" >> "${TMP_OUTPUT}"
cat "${TLS_KEY}" >> "${TMP_OUTPUT}"
echo -e "</tls-crypt>" >> "${TMP_OUTPUT}"

# 4. Di chuyển vào đích đến và phân quyền an toàn
mv "${TMP_OUTPUT}" "${OUTPUT_FILE}"
chmod 600 "${OUTPUT_FILE}"

echo "[SUCCESS] Đã tạo thành công tệp cấu hình OpenVPN tự chứa:"
echo "          --> ${OUTPUT_FILE}"
echo "          (Quyền truy cập đã được thiết lập nghiêm ngặt: chmod 600)"
echo ""
echo "Hướng dẫn tiếp theo:"
echo "1. Chuyển tệp '${OUTPUT_FILE}' sang máy người dùng từ xa (VM-Remote-PC)."
echo "2. Mở ứng dụng OpenVPN GUI trên Windows -> Chọn 'Import file...'."
echo "3. Nhấn 'Connect' để kích hoạt đường hầm bảo mật."
