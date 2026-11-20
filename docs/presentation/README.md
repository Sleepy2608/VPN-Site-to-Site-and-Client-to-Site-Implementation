# Tài liệu demo OpenVPN

**Phương án nghiệm thu đủ Chủ đề 14: mô hình 5 máy trên VMware, chạy OpenVPN C2S và S2S.** Xem [báo cáo rà soát](../topic14-audit.md). Mô hình 3 máy chỉ là bài thực hành C2S; web demo chạy tại `http://10.8.0.1` trong tunnel.

- **[Bộ hướng dẫn triển khai 5 máy](../deployment/README.md)**: phần chuẩn bị chung và hướng dẫn riêng cho HQ-GW, Branch-GW, HQ-Server, Branch-PC, Windows Remote-PC, kèm nghiệm thu toàn hệ thống.

Các tài liệu dưới đây dành cho **mô hình 5 máy chính** (OpenVPN C2S/S2S) hoặc yêu cầu nền tảng; không dùng lẫn lệnh/IP với mô hình 3 máy:

- [Kịch bản triển khai và demo chi tiết](detailed-lab-runbook.md): phần mềm từng máy, cấu hình IP/NAT tạm, thứ tự triển khai, kiểm tra và lời dẫn 8–10 phút.
- [Kịch bản demo rút gọn](demo-script.md): Remote-PC → HQ, Branch-PC → HQ, bắt gói WAN/LAN trong 6–8 phút.
- [Đề cương 8 slide](slides.md): mô hình, công nghệ, cấu hình và bằng chứng.
- [Triển khai](../../README.md): một quy trình chạy Bash theo từng node.
- [Checklist nghiệm thu](../../tests/openvpn-demo.md): ghi kết quả thật trước khi bảo vệ.
- [Windows tối thiểu và chuẩn bị client](../technical-guides/08-windows-client-requirements.md): Windows 10 trở lên, baseline lab Windows 10 22H2 x64, khuyến nghị Windows 11 x64 còn được hỗ trợ.
- [Chuẩn bị Armbian Generic x86_64 trên VMware](../technical-guides/09-armbian-vmware-guide.md): chọn image, LAN Segment, renderer mạng và NIC.
- [Bài thực hành C2S 3 máy](three-vm-openvpn-demo.md): dùng riêng khi học remote access, không thay bài S2S.

Chuẩn bị VM và dịch vụ trước giờ trình diễn. Phần so sánh IPsec/strongSwan cũ không thuộc demo chính.
