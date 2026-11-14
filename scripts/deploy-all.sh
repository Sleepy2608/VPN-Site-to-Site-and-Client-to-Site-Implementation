#!/usr/bin/env bash
# ==============================================================================
# deploy-all.sh: Kịch bản triển khai tự động toàn diện cho hệ thống VPN Lab
# Đồ án An ninh mạng: Thiết lập mạng riêng ảo VPN Site-to-Site & Client-to-Site
# Phù hợp chạy trên Ubuntu 22.04 LTS (HQ-GW, Branch-GW, HQ-Server, Branch-PC)
# ==============================================================================

set -euo pipefail

# Định nghĩa màu hiển thị ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Kiểm tra quyền root
if [[ "${EUID}" -ne 0 ]]; then
    echo -e "${RED}[ERROR] Kịch bản này yêu cầu quyền quản trị root.${NC}"
    echo -e "Vui lòng chạy lại với lệnh: ${YELLOW}sudo $0 [hq-gw | branch-gw | hq-server | branch-pc]${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

show_menu() {
    cat <<EOF
==============================================================================
   HỆ THỐNG TRIỂN KHAI TỰ ĐỘNG TOÀN DIỆN CHO VPN LAB (ONE-CLICK DEPLOY)
==============================================================================
 Vui lòng chọn loại máy ảo bạn đang thao tác:
   [1] HQ-GW     : Cổng VPN Trụ sở chính (PKI CA + C2S + S2S OpenVPN + IPsec)
   [2] Branch-GW : Cổng VPN Chi nhánh (S2S OpenVPN + IPsec Client)
   [3] HQ-Server : Máy chủ nội bộ HQ (Nginx Web Portal + Benchmark files)
   [4] Branch-PC : Máy trạm nội bộ Chi nhánh (Test kết nối LAN-to-LAN)
   [0] Thoát
==============================================================================
EOF
}

deploy_hq_gw() {
    echo -e "\n${CYAN}${BOLD}>>> BẮT ĐẦU TRIỂN KHAI HQ GATEWAY (VM-HQ-GW)...${NC}"
    
    echo -e "\n${BLUE}[1/7] Kích hoạt IP Forwarding nhân Linux...${NC}"
    bash "${SCRIPT_DIR}/common/enable-ip-forward.sh"
    
    echo -e "\n${BLUE}[2/7] Thiết lập tường lửa iptables & MSS Clamping cho HQ Gateway...${NC}"
    bash "${SCRIPT_DIR}/common/setup-firewall-rules.sh" hq-gw
    
    echo -e "\n${BLUE}[3/7] Khởi tạo PKI CA nội bộ và sinh chứng chỉ số...${NC}"
    bash "${SCRIPT_DIR}/pki/init-ca.sh"
    
    echo -e "\n${BLUE}[4/7] Đóng gói profile client OpenVPN nhúng chứng chỉ inline...${NC}"
    bash "${SCRIPT_DIR}/pki/build-client-ovpn.sh" client1
    
    echo -e "\n${BLUE}[5/7] Triển khai dịch vụ OpenVPN Client-to-Site Server...${NC}"
    bash "${SCRIPT_DIR}/deploy-c2s-server.sh"
    
    echo -e "\n${BLUE}[6/7] Triển khai dịch vụ OpenVPN Site-to-Site Server (tun1, CCD)...${NC}"
    bash "${SCRIPT_DIR}/deploy-s2s-hq.sh"
    
    echo -e "\n${BLUE}[7/7] Cài đặt cấu hình strongSwan IPsec IKEv2 (Sẵn sàng dự phòng)...${NC}"
    bash "${SCRIPT_DIR}/deploy-ipsec-hq.sh"
    
    echo -e "\n${GREEN}${BOLD}=============================================================================="
    echo -e " HOÀN TẤT TRIỂN KHAI HQ GATEWAY THÀNH CÔNG!"
    echo -e " Profile client OpenVPN cho Windows được lưu tại: /home/student/openvpn-ca/client1.ovpn"
    echo -e " Hãy chạy lệnh kiểm tra nghiệm thu: bash ${SCRIPT_DIR}/verify-c2s.sh"
    echo -e "==============================================================================${NC}"
}

deploy_branch_gw() {
    echo -e "\n${CYAN}${BOLD}>>> BẮT ĐẦU TRIỂN KHAI BRANCH GATEWAY (VM-Branch-GW)...${NC}"
    
    echo -e "\n${BLUE}[1/5] Kích hoạt IP Forwarding nhân Linux...${NC}"
    bash "${SCRIPT_DIR}/common/enable-ip-forward.sh"
    
    echo -e "\n${BLUE}[2/5] Thiết lập tường lửa iptables cho Branch Gateway...${NC}"
    bash "${SCRIPT_DIR}/common/setup-firewall-rules.sh" branch-gw
    
    echo -e "\n${BLUE}[3/5] Triển khai dịch vụ OpenVPN Site-to-Site Client...${NC}"
    bash "${SCRIPT_DIR}/deploy-s2s-branch.sh"
    
    echo -e "\n${BLUE}[4/5] Cài đặt cấu hình strongSwan IPsec IKEv2 cho Branch Gateway...${NC}"
    bash "${SCRIPT_DIR}/deploy-ipsec-branch.sh"
    
    echo -e "\n${BLUE}[5/5] Đồng bộ chế độ VPN sang OpenVPN S2S...${NC}"
    bash "${SCRIPT_DIR}/switch-vpn-mode.sh" openvpn
    
    echo -e "\n${GREEN}${BOLD}=============================================================================="
    echo -e " HOÀN TẤT TRIỂN KHAI BRANCH GATEWAY THÀNH CÔNG!"
    echo -e " Hãy chạy lệnh kiểm tra nghiệm thu: bash ${SCRIPT_DIR}/verify-s2s.sh"
    echo -e "==============================================================================${NC}"
}

deploy_hq_server() {
    echo -e "\n${CYAN}${BOLD}>>> BẮT ĐẦU TRIỂN KHAI HQ INTERNAL SERVER (VM-HQ-Server)...${NC}"
    
    echo -e "\n${BLUE}[1/2] Cài đặt Nginx và cấu hình Cổng nội bộ Intranet Portal...${NC}"
    bash "${SCRIPT_DIR}/deploy-hq-portal.sh"
    
    echo -e "\n${BLUE}[2/2] Kiểm tra nghiệm thu dịch vụ Web nội bộ...${NC}"
    bash "${SCRIPT_DIR}/verify-portal.sh"
    
    echo -e "\n${GREEN}${BOLD}=============================================================================="
    echo -e " HOÀN TẤT TRIỂN KHAI HQ INTERNAL SERVER THÀNH CÔNG!"
    echo -e " Cổng thông tin nội bộ đang lắng nghe tại: http://192.168.10.50:80"
    echo -e "==============================================================================${NC}"
}

deploy_branch_pc() {
    echo -e "\n${CYAN}${BOLD}>>> KIỂM TRA MÁY TRẠM CHI NHÁNH (VM-Branch-PC)...${NC}"
    
    echo -e "\n[*] Kiểm tra kết nối tới Gateway Chi nhánh (192.168.20.1)..."
    ping -c 3 192.168.20.1 || true
    
    echo -e "\n[*] Kiểm tra kết nối tới Máy chủ nội bộ HQ (192.168.10.50)..."
    ping -c 3 192.168.10.50 || true
    
    echo -e "\n[*] Thử nghiệm request HTTP tới Portal nội bộ HQ..."
    curl -I --connect-timeout 3 http://192.168.10.50 || true
    
    echo -e "\n${GREEN}${BOLD}=============================================================================="
    echo -e " KIỂM TRA MÁY TRẠM HOÀN TẤT!"
    echo -e "==============================================================================${NC}"
}

# Xử lý tham số truyền vào
TARGET="${1:-}"

if [[ -z "${TARGET}" ]]; then
    show_menu
    read -r -p "Nhập lựa chọn của bạn [0-4]: " CHOICE
    case "${CHOICE}" in
        1) deploy_hq_gw ;;
        2) deploy_branch_gw ;;
        3) deploy_hq_server ;;
        4) deploy_branch_pc ;;
        0) exit 0 ;;
        *) echo -e "${RED}[ERROR] Lựa chọn không hợp lệ!${NC}"; exit 1 ;;
    esac
else
    case "${TARGET}" in
        hq-gw|hq)
            deploy_hq_gw
            ;;
        branch-gw|branch)
            deploy_branch_gw
            ;;
        hq-server|server)
            deploy_hq_server
            ;;
        branch-pc|pc)
            deploy_branch_pc
            ;;
        *)
            echo -e "${RED}[ERROR] Tham số '${TARGET}' không hợp lệ.${NC}"
            echo -e "Sử dụng: sudo $0 [hq-gw | branch-gw | hq-server | branch-pc]"
            exit 1
            ;;
    esac
fi

