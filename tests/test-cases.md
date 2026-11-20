# Ma trận kiểm thử VPN Site-to-Site và Client-to-Site

Thực hiện theo [checklist có lệnh và kỳ vọng](openvpn-demo.md). Kết quả Linux ngày 20/11/2026 có [bằng chứng triển khai trực tiếp](../docs/deployment/live-lab-status.md); các phép thử Windows vẫn chờ người dùng thực hiện. [Bộ kiểm thử offline](test_repository.py) kiểm tra mã, không thay thế lab.

| Mã | Phép thử | Nguồn → đích | Kỳ vọng | Trạng thái |
| --- | --- | --- | --- | --- |
| TC-01 | Handshake C2S | Windows → HQ-GW UDP1194 | Đúng CA/CN/EKU, log hoàn tất, IP 10.8.0.x | Chưa chạy |
| TC-02 | Split route C2S | Windows | Route HQ qua VPN, không bắt buộc full tunnel hoặc Internet | Chưa chạy |
| TC-03 | Tài nguyên HQ qua C2S | Windows → HQ-Server | Ping/HTTP/tải file; Portal có thể thấy IP NAT 192.168.10.1 | Chưa chạy |
| TC-04 | C2S ngắt và route giả lập | Windows WAN → HQ LAN | Không vào HQ dù tự thêm route; Connect lại truy cập được | Linux tương đương đạt; Windows chưa thử |
| TC-05 | Handshake S2S | Branch-GW ↔ HQ-GW UDP1195 | Đúng CN branch-gw, tun0 Branch .2/tun1 HQ .1; status mới | Đạt trên VM |
| TC-06 | Hai chiều LAN-to-LAN | Branch-PC ↔ HQ-Server | Cả hai host tự khởi tạo ping; HTTP từ Branch; giữ IP LAN nguồn | Đạt trên VM |
| TC-07 | Định tuyến và đường đi | Hai gateway và hai host LAN | Route đúng TUN ở gateway, host đi qua gateway LAN; traceroute là thông tin hỗ trợ | Route đã kiểm tra đạt; traceroute không bắt buộc |
| TC-08 | Đối chứng mã hóa | WAN so với LAN/TUN | Log AES-256-GCM và gói tin tương ứng của cùng request | Đạt log/capture đối chứng |
| TC-09 | IPsec S2S tùy chọn | Hai LAN + gateway | IKE/CHILD SA, selectors/counter XFRM, HTTP/ping hai chiều | Chưa chạy |
| TC-10 | Thu hồi và sai vai trò cert | Client → HQ | CRL chặn handshake mới, client C2S không vào S2S | Chưa chạy |
| TC-11 | Mất tunnel và reboot | S2S tắt/có WAN fallback, sau đó reboot | Không bản rõ đi WAN; phục hồi đúng mode/firewall/forwarding và truy cập | Đạt trên bốn Linux |

Hiệu năng ghi riêng theo [kế hoạch đo](../docs/technical-guides/07-testing-and-security-eval.md), gồm RTT/loss và thời gian tải đúng payload 1 MiB/hash. Không mặc định mọi hypervisor cho RTT dưới một ngưỡng cố định hoặc IPsec nhanh hơn một tỷ lệ định trước.
