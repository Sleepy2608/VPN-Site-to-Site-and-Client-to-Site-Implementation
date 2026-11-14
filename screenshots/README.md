# DANH MỤC ẢNH CHỤP MÀN HÌNH MINH CHỨNG (PROOF OF CONCEPT SCREENSHOTS)

Thư mục này quản lý toàn bộ **12 ảnh chụp màn hình minh chứng thực nghiệm** của đồ án theo đúng quy chuẩn phân loại và tiêu chuẩn nghiệm thu tại [PLAN.md (Mục 7)](file:///c:/University%20Coding%20Project/VPN-Site-to-Site-and-Client-to-Site-Implementation/.plan/PLAN.md).

---

## 1. BẢNG DANH MỤC 12 ẢNH CHỨNG MINH THỰC NGHIỆM

| STT | Tên Tệp Tin | Thư Mục Lưu Trữ | Nội Dung Cần Thể Hiện Trong Ảnh | Trạng Thái |
| :---: | :--- | :--- | :--- | :---: |
| 1 | `c2s-01-connected.png` | `screenshots/c2s-connection/` | Cửa sổ OpenVPN GUI trên Windows chuyển màu xanh lá cây báo "Connected", hiển thị IP ảo `10.8.0.2`. | Đã quy hoạch |
| 2 | `c2s-02-ip-assigned.png` | `screenshots/c2s-connection/` | Kết quả lệnh `ipconfig /all` trên Windows hiển thị card mạng ảo `OpenVPN TAP-Windows6` nhận IP `10.8.0.2`. | Đã quy hoạch |
| 3 | `c2s-03-route-print.png` | `screenshots/routing-tables/` | Kết quả lệnh `route print -4` trên Windows thấy route `192.168.10.0/24` trỏ qua Gateway ảo `10.8.0.1`. | Đã quy hoạch |
| 4 | `c2s-04-web-portal.png` | `screenshots/c2s-connection/` | Trình duyệt mở `http://192.168.10.50`, Portal nội bộ nhận diện Client kết nối an toàn từ IP VPN. | Đã quy hoạch |
| 5 | `s2s-01-tunnel-status.png`| `screenshots/s2s-tunnel/` | Lệnh `ip addr show dev tun1` trên HQ GW và `tun0` trên Branch GW ở trạng thái UP. | Đã quy hoạch |
| 6 | `s2s-02-ping-lan-lan.png` | `screenshots/s2s-tunnel/` | Terminal từ máy `VM-Branch-PC` (`192.168.20.50`) ping tới `VM-HQ-Server` (`192.168.10.50`) thành công 0% packet loss. | Đã quy hoạch |
| 7 | `s2s-03-traceroute.png` | `screenshots/s2s-tunnel/` | Lệnh `traceroute -n 192.168.10.50` chứng minh đường đi qua hop trung gian `10.9.0.1`, không lộ IP WAN `172.16.1.x`. | Đã quy hoạch |
| 8 | `ipsec-01-statusall.png` | `screenshots/s2s-tunnel/` | Lệnh `sudo ipsec statusall` hiển thị kết nối IKEv2 `ESTABLISHED` và Child SA `INSTALLED, TUNNEL`. | Đã quy hoạch |
| 9 | `ws-01-wan-encrypted.png` | `screenshots/wireshark-evidence/`| Wireshark bắt trên `eth0` chứng minh toàn bộ payload truyền tải file là OpenVPN UDP datagram bị mã hóa. | Đã quy hoạch |
| 10 | `ws-02-ipsec-esp.png` | `screenshots/wireshark-evidence/`| Wireshark hiển thị gói tin giao thức ESP (Protocol 50) với các trường SPI, Sequence Number và Payload mã hóa. | Đã quy hoạch |
| 11 | `ws-03-lan-decrypted.png`| `screenshots/wireshark-evidence/`| Wireshark bắt trên card LAN `eth1` hiển thị request HTTP `GET /` và ICMP bản rõ sau khi Gateway giải mã. | Đã quy hoạch |
| 12 | `sec-01-crl-revoked.png` | `screenshots/c2s-connection/` | Log OpenVPN GUI và Server báo lỗi từ chối kết nối khi sử dụng chứng chỉ `client1` đã bị thu hồi (Revoked). | Đã quy hoạch |

---

## 2. QUY CHUẨN CHỤP ẢNH & ĐỊNH DẠNG (STANDARDS)

- **Định dạng file:** Khuyến nghị dùng định dạng `.png` để chữ hiển thị sắc nét nhất, không bị vỡ hạt như `.jpeg`.
- **Độ phân giải:** Tối thiểu 1280x720 (HD) hoặc chụp trực tiếp cửa sổ ứng dụng (Alt + PrintScreen hoặc Snipping Tool).
- **Nguyên tắc bảo mật:** Không để lộ mật khẩu thật, khóa bí mật riêng tư hoặc thông tin cá nhân không liên quan trong ảnh chụp màn hình.
