# Ma trận kiểm thử VPN Site-to-Site và Client-to-Site

Thực hiện theo [checklist có lệnh và kỳ vọng](openvpn-demo.md). Xem [bằng chứng triển khai theo từng dải LAN](../docs/deployment/live-lab-status.md) và [bộ kiểm thử offline](test_repository.py).

| Mã | Phép thử | Nguồn → đích | Kỳ vọng | Trạng thái |
| --- | --- | --- | --- | --- |
| TC-01 | Handshake C2S | Windows → HQ-GW UDP1194 | Đúng CA/CN/EKU, log hoàn tất, IP 10.8.0.x | HQ-GW ghi nhận `client1` từ `172.16.1.100` |
| TC-02 | Split route C2S | Windows | Route HQ qua VPN, không bắt buộc full tunnel hoặc Internet | HQ-GW đã gửi route mới, chưa kiểm tra bảng route trên Windows |
| TC-03 | Tài nguyên HQ qua C2S | Windows → HQ-Server | Ping/HTTP/tải file; Portal có thể thấy IP NAT 10.74.10.1 | Chưa chạy |
| TC-04 | C2S ngắt và route giả lập | Windows WAN → HQ LAN | Không vào HQ dù tự thêm route; Connect lại truy cập được | Linux tương đương đạt trên dải cũ |
| TC-05 | Handshake S2S | Branch-GW ↔ HQ-GW UDP1195 | Đúng CN branch-gw, tun0 Branch .2/tun1 HQ .1; status mới | Đạt trên VM |
| TC-06 | Hai chiều LAN-to-LAN | Branch-PC ↔ HQ-Server | Cả hai host tự khởi tạo ping; HTTP từ Branch; giữ IP LAN nguồn | Đạt trên VM |
| TC-07 | Định tuyến và đường đi | Hai gateway và hai host LAN | Route đúng TUN ở gateway, host đi qua gateway LAN; traceroute là thông tin hỗ trợ | Route đã kiểm tra đạt; traceroute không bắt buộc |
| TC-08 | Đối chứng mã hóa | WAN so với LAN/TUN | Log AES-256-GCM và gói tin tương ứng của cùng request | Có log và capture đối chứng trên dải cũ |
| TC-09 | IPsec S2S tùy chọn | Hai LAN + gateway | IKE/CHILD SA, selectors/counter XFRM, HTTP/ping hai chiều | Đạt trên bốn Linux ngày 21/11/2026 |
| TC-10 | Thu hồi và sai vai trò cert | Client → HQ | CRL chặn handshake mới, client C2S không vào S2S | Chưa chạy |
| TC-11 | Mất tunnel và reboot | S2S tắt/có WAN fallback, sau đó reboot | Không bản rõ đi WAN; phục hồi đúng mode/firewall/forwarding và truy cập | Có kết quả đầy đủ bốn Linux trên dải cũ |

Hiệu năng ghi riêng theo [kế hoạch đo](../docs/technical-guides/07-testing-and-security-eval.md), gồm RTT/loss và thời gian tải đúng payload 1 MiB/hash. Không mặc định mọi hypervisor cho RTT dưới một ngưỡng cố định hoặc IPsec nhanh hơn một tỷ lệ định trước.
