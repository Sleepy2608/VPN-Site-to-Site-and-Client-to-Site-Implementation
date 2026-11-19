#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-hq-portal.sh
# Mục đích: Tự động cài đặt Nginx và triển khai Cổng thông tin nội bộ
#           HQ Secure Intranet Portal trên máy chủ VM-HQ-Server (192.168.10.50).
# Đối tượng thực thi: VM-HQ-Server (Trụ sở chính)
# Sử dụng: sudo ./deploy-hq-portal.sh
# ==============================================================================

set -euo pipefail

# Kiểm tra quyền root
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Vui lòng chạy script này với quyền root: sudo $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PORTAL_SRC="${REPO_ROOT}/services/intranet-portal"
WEB_ROOT="/var/www/html"

echo "=============================================================================="
echo " TRIỂN KHAI HQ SECURE INTRANET PORTAL (VM-HQ-SERVER: 192.168.10.50)"
echo "=============================================================================="

# 1. Cài đặt Nginx Web Server nếu chưa có
if ! command -v nginx &>/dev/null; then
    echo "[*] Đang cập nhật gói và cài đặt Nginx Web Server..."
    apt update -y
    DEBIAN_FRONTEND=noninteractive apt install -y nginx curl
fi

# 2. Xóa các tệp mặc định của Nginx và sao chép mã nguồn Cổng nội bộ
echo "[*] Đồng bộ mã nguồn Cổng thông tin nội bộ vào ${WEB_ROOT}..."
mkdir -p "${WEB_ROOT}"
rm -rf "${WEB_ROOT:?}"/*

if [[ -d "${PORTAL_SRC}" ]]; then
    cp -r "${PORTAL_SRC}"/* "${WEB_ROOT}/"
else
    echo "[ERROR] Không tìm thấy thư mục nguồn: ${PORTAL_SRC}" >&2
    exit 1
fi

# 3. Cấu hình Nginx Virtual Host tích hợp API Network Identity Inspector
NGINX_CONF="/etc/nginx/sites-available/hq-portal"

echo "[*] Thiết lập cấu hình Nginx Virtual Host tại ${NGINX_CONF}..."
cat << 'EOF' > "${NGINX_CONF}"
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name portal.corp.vpn.internal 192.168.10.50 192.168.10.1 10.8.0.1 172.16.1.10 localhost;
    root /var/www/html;
    index index.html;

    # Cung cấp endpoint API trả về địa chỉ IP nguồn của client
    location /api/identity {
        default_type application/json;
        return 200 '{"ip":"$remote_addr","server_time":"$time_iso8601","status":"secured"}';
    }

    # Phục vụ tệp tĩnh và tải tệp tài liệu kiểm thử
    location / {
        try_files $uri $uri/ =404;
    }

    # Bật nén Gzip tối ưu truyền tải qua đường hầm VPN
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;
}
EOF

# Kích hoạt site trong Nginx
ln -sf "${NGINX_CONF}" /etc/nginx/sites-enabled/default

# 4. Kiểm tra cú pháp và khởi động lại Nginx
echo "[*] Kiểm tra cú pháp cấu hình Nginx..."
nginx -t

echo "[*] Khởi động lại dịch vụ Nginx..."
systemctl enable nginx
systemctl restart nginx

# 5. Kiểm tra kết nối cục bộ
sleep 1
echo "[*] Kiểm tra phản hồi HTTP nội bộ..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ || echo "000")

if [[ "${HTTP_STATUS}" == "200" ]]; then
    echo "[SUCCESS] Cổng thông tin nội bộ HQ Intranet Portal đã sẵn sàng!"
    echo "  URL truy cập: http://192.168.10.50"
    echo "  Kiểm tra API: http://192.168.10.50/api/identity"
else
    echo "[FAILED] Nginx phản hồi mã lỗi HTTP: ${HTTP_STATUS}" >&2
    exit 1
fi

echo "=============================================================================="
echo " TRIỂN KHAI HOÀN TẤT!"
echo "=============================================================================="

