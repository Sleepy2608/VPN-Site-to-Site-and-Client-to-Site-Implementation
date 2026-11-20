# Kiểm thử an ninh VPN

Các phép thử Linux về route đi vòng, ngắt S2S có WAN fallback, cô lập NAT và reboot đã có [kết quả thực tế](../docs/deployment/live-lab-status.md). Các mục Windows, CRL/sai vai trò chứng chỉ chưa được nghiệm thu. Mô hình chính là OpenVPN C2S + S2S 5 máy; IPsec là mở rộng. Quy trình thao tác và cách phục hồi được ghi tập trung tại [checklist nghiệm thu](openvpn-demo.md), tránh dùng các tên service hoặc rule thủ công cũ.

| Mã | Kiểm thử | Điều kiện và tiêu chí |
| --- | --- | --- |
| SEC-01 | WAN tự thêm route đi vòng VPN | Windows Disconnect, thêm route HQ qua WAN gateway; HTTP không truy cập được; counter firewall tăng |
| SEC-02 | Tunnel S2S mất, có route WAN dự phòng | Phát ping/HTTP từ host Branch; không có bản rõ ra WAN, counter DROP tăng; phục hồi route/service và thử lại |
| SEC-03 | Thu hồi chứng chỉ | CRL của đúng CA đang dùng được publish; handshake mới bị từ chối; phiên cũ phải ngắt riêng/restart |
| SEC-04 | Sai vai trò/CA/tls-crypt | Chứng chỉ C2S không được vào server S2S; sai trust/key không thiết lập phiên; đối chiếu log hai đầu |
| SEC-05 | Hai loại VPN độc lập | Tắt C2S vẫn dùng S2S; tắt S2S C2S vẫn vào HQ; không thông sang Branch qua C2S |
| SEC-06 | Bề mặt dịch vụ WAN | Gateway chỉ mở dịch vụ chủ đích; **SSH quản trị và ICMP trên IP WAN được cho phép trong WAN lab**, không khẳng định mọi TCP đều ẩn |
| SEC-07 | Cipher và traffic đối chứng | Log cipher thương lượng và PCAP WAN/LAN/TUN cùng lần tải file; không suy ra thuật toán từ entropy hoặc 0 packet |
| SEC-08 | Reboot và CRL hết hạn | Sau reboot policy còn hiệu lực; kiểm tra nextUpdate của CRL; gia hạn CRL trước khi hết hạn |

## Lưu ý khi đánh giá

`tls-crypt` bảo vệ và xác thực kênh điều khiển OpenVPN; dữ liệu sử dụng AEAD GCM. Không kết luận chống được mọi replay/DoS chỉ từ thử gói sai khóa. Không tắt toàn bộ Windows Firewall để làm ping thành công. Không dùng traceroute hay IP Portal như bằng chứng mật mã.

Với IPsec mở rộng, thử PSK sai trên snapshot riêng, restart đúng unit strongSwan của distro rồi kiểm tra không có CHILD SA. Khi thử mất SA, dừng IPsec cả hai đầu để tránh tự tái thiết lập; vẫn phát traffic và kiểm tra counter/PCAP. Dùng máy quan sát WAN riêng nếu cần phân biệt gói thật trên dây với gói sau giải mã trong host Linux. Không hiển thị PSK thật trong log/ảnh.

Không có bộ thử nào ở đây đủ để khẳng định tuân thủ NIST/BSI hoặc an toàn tuyệt đối. Báo cáo phải nêu phạm vi IPv4/WAN giả lập, quyền truy cập quản trị, CA nopass trong lab và HTTP bản rõ sau gateway.
