#!/usr/bin/env bash
# ==============================================================================
# Script: verify-portal.sh
# Mục đích: Kiểm tra tự động khả năng truy cập Cổng thông tin nội bộ HQ Server
#           (10.74.10.50) từ máy khách qua đường hầm bảo mật VPN.
# Sử dụng: ./verify-portal.sh [portal_url]
# Ví dụ:   ./verify-portal.sh http://10.74.10.50
# ==============================================================================

set -euo pipefail

TARGET_URL="${1:-http://10.74.10.50}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE} KIỂM TRA TRUY CẬP CỔNG THÔNG TIN NỘI BỘ (HQ INTRANET PORTAL)${NC}"
echo -e "${BLUE} Đích đến kiểm tra: ${TARGET_URL}${NC}"
echo -e "${BLUE}==============================================================================${NC}"

PASS_COUNT=0
FAIL_COUNT=0

record_pass() {
    echo -e "${GREEN}[PASS] $1${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
}

record_fail() {
    echo -e "${RED}[FAIL] $1${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

# 1. Kiểm tra mã trạng thái HTTP
echo -n "  [*] Kiểm tra kết nối HTTP GET ${TARGET_URL}... "
HTTP_CODE=$(curl --noproxy '*' --fail -s --max-time 10 -o /dev/null -w "%{http_code}" --connect-timeout 4 "${TARGET_URL}" || echo "000")

if [[ "${HTTP_CODE}" == "200" ]]; then
    echo -e "${GREEN}[HTTP 200 OK]${NC}"
    record_pass "Cổng thông tin nội bộ phản hồi thành công"
else
    echo -e "${RED}[HTTP ${HTTP_CODE}]${NC}"
    record_fail "Không thể kết nối tới ${TARGET_URL} (Mã lỗi: ${HTTP_CODE})"
fi

# 2. Kiểm tra API định danh mạng /api/identity
echo -n "  [*] Kiểm tra API định danh mạng (/api/identity)... "
API_RESP=$(curl --noproxy '*' --fail -s --max-time 10 --connect-timeout 3 "${TARGET_URL}/api/identity" || echo "")

if [[ -n "${API_RESP}" ]] && echo "${API_RESP}" | grep -q "ip"; then
    echo -e "${GREEN}[OK]${NC}"
    echo -e "      Phản hồi từ máy chủ: ${YELLOW}${API_RESP}${NC}"
    record_pass "API Network Identity Inspector hoạt động chính xác"
else
    record_fail "Không nhận được phản hồi từ /api/identity"
fi

# 3. Kiểm tra tải tệp tài liệu bảo mật
TEST_FILE_URL="${TARGET_URL}/files/corporate-security-policy-2026.txt"
echo -n "  [*] Kiểm tra tải tài liệu chính sách bảo mật (${TEST_FILE_URL})... "
FILE_CONTENT=$(curl --noproxy '*' --fail -s --max-time 10 --connect-timeout 4 "${TEST_FILE_URL}" | head -n 2 || echo "")

if echo "${FILE_CONTENT}" | grep -q "SECURITY POLICY"; then
    echo -e "${GREEN}[SUCCESS]${NC}"
    record_pass "Tải tệp tin mẫu qua HTTP thành công"
else
    echo -e "${RED}[FAIL] Không tải được tệp tin mẫu${NC}"
    record_fail "Tệp tin không tồn tại hoặc lỗi truyền dẫn"
fi

# 4. Đo lường thời gian phản hồi (Latency Benchmark)
echo -n "  [*] Đo lường thời gian phản hồi (HTTP Latency)... "
if TIME_TOTAL=$(curl --noproxy '*' --fail -s --max-time 10 --connect-timeout 4 -o /dev/null -w "%{time_total}" "${TARGET_URL}"); then
    echo -e "${GREEN}${TIME_TOTAL}s${NC}"
    record_pass "Thời gian phản hồi HTTP: ${TIME_TOTAL}s"
else
    record_fail "Không đo được thời gian phản hồi HTTP"
fi

echo -e "\n------------------------------------------------------------------------------"
echo -e " TỔNG KẾT: ${GREEN}${PASS_COUNT} PASSED${NC} | ${RED}${FAIL_COUNT} FAILED${NC}"
echo -e "------------------------------------------------------------------------------"

if [[ "${FAIL_COUNT}" -eq 0 ]]; then
    echo -e "${GREEN}[SUCCESS] Máy khách truy cập Portal qua HTTP thành công; đối chiếu VPN trên gateway.${NC}"
    exit 0
else
    echo -e "${RED}[ATTENTION] Chưa đạt yêu cầu. Vui lòng kiểm tra lại dịch vụ Nginx trên HQ Server và VPN tunnel.${NC}"
    exit 1
fi

