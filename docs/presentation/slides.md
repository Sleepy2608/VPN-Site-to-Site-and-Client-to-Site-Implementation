# Đề cương 8 slide — VPN bằng OpenVPN

Dùng 3 Armbian CLI + 1 Armbian GUI + 1 Windows trên VMware và [kịch bản demo 6–8 phút](demo-script.md). Chỉ đưa kết quả đã đo vào slide.

## Slide 1 — Đề tài và thành viên

Thiết lập VPN Site-to-Site và Client-to-Site bằng OpenVPN.

Nguyễn Lê Huy Tâm, Nguyễn Sun Sin, Huỳnh Đình Chấn.

## Slide 2 — Bài toán

- Nhân viên từ xa cần vào tài nguyên HQ.
- Chi nhánh cần liên lạc với LAN HQ qua đường truyền không tin cậy.
- Mục tiêu demo: kết nối đúng, truy cập ứng dụng, quan sát mã hóa trên WAN.

## Slide 3 — Mô hình lab

- 5 VM trên VMware: HQ-GW, Branch-GW, HQ-Server chạy Armbian không GUI; Branch-PC chạy Armbian GUI; Remote-PC chạy Windows.
- Armbian dùng image Generic UEFI x86_64 phù hợp VMware; đối chiếu backend Netplan và tên NIC theo MAC, không mặc định eth0/eth1.
- OpenVPN GUI hiện hành cần Windows 10 trở lên; baseline lab Windows 10 22H2 x64, khuyến nghị Windows 11 x64 còn được hỗ trợ. Xem [nguồn/yêu cầu](../technical-guides/08-windows-client-requirements.md).
- WAN 172.16.1.0/24, HQ LAN 192.168.10.0/24, Branch LAN 192.168.20.0/24.
- WAN là mạng giả lập. Tạo VM/mạng thủ công, triển khai dịch vụ bằng Bash theo node.

## Slide 4 — Cấu hình OpenVPN

- C2S: UDP 1194, tunnel 10.8.0.0/24, Windows client dùng OpenVPN GUI.
- S2S: UDP 1195, tunnel 10.9.0.0/24, Branch-GW kết nối HQ-GW.
- Easy-RSA cấp chứng chỉ X.509; tls-crypt bảo vệ kênh điều khiển.
- Route + CCD/iroute cho hai LAN; bật IPv4 forwarding và quy tắc firewall.

## Slide 5 — Demo Client-to-Site

- Remote-PC chọn Connect; quan sát `ipconfig`, `route print -4` và log OpenVPN GUI.
- Ping HQ-Server và truy cập http://192.168.10.50.
- C2S đang NAT nên Portal có thể thấy IP gateway 192.168.10.1.
- Cuối demo chọn Disconnect để ngắt C2S; S2S độc lập vẫn hoạt động.

## Slide 6 — Demo Site-to-Site

- Branch-PC Armbian GUI ping và mở Portal trong browser mà không cài VPN client trên PC.
- Kiểm tra tun1 tại HQ, status log và client branch-gw.
- Site-to-Site giữ IP LAN nguồn; ghi lại ping và HTTP 200 thực tế.

## Slide 7 — Bằng chứng mã hóa

- Cùng lần tải file: pcap WAN là UDP OpenVPN; pcap LAN có HTTP bản rõ.
- Đối chiếu cipher trong log OpenVPN; không suy ra mã hóa chỉ từ IP hay traceroute.
- Chèn ảnh/pcap đã thu thật, không dùng số liệu benchmark/PASS giả định.

## Slide 8 — Kết quả và hướng phát triển

- Ghi kết quả thực tế theo checklist OpenVPN.
- Phân biệt mã hóa trên WAN với HTTP bản rõ trong LAN.
- Hướng mở rộng: HTTPS cho Portal, MFA, dự phòng gateway; CRL và firewall đã có cấu hình, cần chèn bằng chứng kiểm thử thật.
- Hỏi đáp.
