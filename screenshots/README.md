# DANH MỤC ẢNH CHỤP MÀN HÌNH MINH CHỨNG (PROOF OF CONCEPT SCREENSHOTS)

Thư mục này quy hoạch **12 ảnh minh chứng** cho VMware lab: 3 Armbian không GUI, Armbian GUI Branch-PC và Windows Remote-PC. Thu thập các ảnh OpenVPN theo [checklist demo](../tests/openvpn-demo.md); ảnh IPsec/CRL là phần tham khảo hoặc mở rộng. Danh mục không đồng nghĩa đã có bằng chứng thực nghiệm.

---

## 1. BẢNG DANH MỤC 12 ẢNH CHỨNG MINH THỰC NGHIỆM

| STT | Tên Tệp Tin | Thư Mục Lưu Trữ | Nội Dung Cần Thể Hiện Trong Ảnh | Trạng Thái |
| :---: | :--- | :--- | :--- | :---: |
| 1 | `c2s-01-connected.png` | `screenshots/c2s-connection/` | OpenVPN GUI trên Windows báo Connected, log có `Initialization Sequence Completed`. | Chưa thu thập |
| 2 | `c2s-02-ip-assigned.png` | `screenshots/c2s-connection/` | `ipconfig` trên Windows cho thấy adapter OpenVPN có IP `10.8.0.x`. | Chưa thu thập |
| 3 | `c2s-03-route-print.png` | `screenshots/routing-tables/` | `route print -4` trên Windows có route HQ qua adapter OpenVPN. | Chưa thu thập |
| 4 | `c2s-04-web-portal.png` | `screenshots/c2s-connection/` | Trình duyệt Windows Remote-PC mở `http://192.168.10.50`; C2S NAT có thể hiển thị IP gateway. | Chưa thu thập |
| 5 | `s2s-01-tunnel-status.png`| `screenshots/s2s-tunnel/` | Lệnh `ip addr show dev tun1` trên HQ GW và `tun0` trên Branch GW ở trạng thái UP. | Đã quy hoạch |
| 6 | `s2s-02-ping-lan-lan.png` | `screenshots/s2s-tunnel/` | Terminal từ máy `VM-Branch-PC` (`192.168.20.50`) ping tới `VM-HQ-Server` (`192.168.10.50`) thành công 0% packet loss. | Đã quy hoạch |
| 7 | `s2s-03-traceroute.png` | `screenshots/s2s-tunnel/` | Lệnh `traceroute -n 192.168.10.50` chứng minh đường đi qua hop trung gian `10.9.0.1`, không lộ IP WAN `172.16.1.x`. | Đã quy hoạch |
| 8 | `ipsec-01-statusall.png` | `screenshots/s2s-tunnel/` | Lệnh `sudo ipsec statusall` hiển thị kết nối IKEv2 `ESTABLISHED` và Child SA `INSTALLED, TUNNEL`. | Đã quy hoạch |
| 9 | `ws-01-wan-encrypted.png` | `screenshots/wireshark-evidence/`| Wireshark bắt trên `eth0` chứng minh toàn bộ payload truyền tải file là OpenVPN UDP datagram bị mã hóa. | Đã quy hoạch |
| 10 | `ws-02-ipsec-esp.png` | `screenshots/wireshark-evidence/`| Wireshark hiển thị gói tin giao thức ESP (Protocol 50) với các trường SPI, Sequence Number và Payload mã hóa. | Đã quy hoạch |
| 11 | `ws-03-lan-decrypted.png`| `screenshots/wireshark-evidence/`| Wireshark bắt trên card LAN `eth1` hiển thị request HTTP `GET /` và ICMP bản rõ sau khi Gateway giải mã. | Đã quy hoạch |
| 12 | `sec-01-crl-revoked.png` | `screenshots/c2s-connection/` | Log OpenVPN GUI Windows và journal HQ ghi từ chối chứng chỉ `client1` bị thu hồi. Bài mở rộng, không bắt buộc trong demo ngắn. | Chưa thu thập |

---

## 2. QUY CHUẨN CHỤP ẢNH & ĐỊNH DẠNG (STANDARDS)

- **Định dạng file:** Khuyến nghị dùng định dạng `.png` để chữ hiển thị sắc nét nhất, không bị vỡ hạt như `.jpeg`.
- **Độ phân giải:** Tối thiểu 1280x720 (HD) hoặc chụp trực tiếp cửa sổ ứng dụng (Alt + PrintScreen hoặc Snipping Tool).
- **Nguyên tắc bảo mật:** Không để lộ mật khẩu thật, khóa bí mật riêng tư hoặc thông tin cá nhân không liên quan trong ảnh chụp màn hình.
