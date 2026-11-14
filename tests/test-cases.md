# MA TRẬN 11 CA KIỂM THỬ MẠNG & AN NINH VPN (TEST CASES MATRIX)

Tài liệu này định nghĩa chi tiết **11 ca kiểm thử chức năng, hiệu năng và an ninh mạng** cho hệ thống VPN (Client-to-Site OpenVPN, Site-to-Site OpenVPN và Site-to-Site strongSwan IPsec), bám sát mục tiêu đồ án An ninh mạng và quy chuẩn tại [TEST_AGENTS.md](file:///c:/University%20Coding%20Project/VPN-Site-to-Site-and-Client-to-Site-Implementation/.agents/test/test_agents.md).

---

## 1. BẢNG TỔNG QUAN MA TRẬN KIỂM THỬ (TEST EXECUTION MATRIX)

| Mã TC | Phân Loại | Tên Kịch Bản Kiểm Thử | Nguồn -> Đích | Giao Thức / Port | Tiêu Chí Đạt (Expected Result) |
| :---: | :---: | :--- | :--- | :--- | :--- |
| **TC-01** | Chức năng | Kết nối Remote Access Client-to-Site | Remote PC -> HQ GW | UDP 1194 / TLS 1.3 | Cấp IP `10.8.0.x`, OpenVPN GUI trạng thái Connected |
| **TC-02** | Định tuyến | Kiểm tra bảng định tuyến Remote Client | Remote PC (Windows) | Routing Table | Tồn tại route `192.168.10.0/24` qua Gateway `10.8.0.1` |
| **TC-03** | Chức năng | Ping máy chủ nội bộ HQ qua Client-to-Site | `10.8.0.2` -> `192.168.10.50` | ICMP Echo Request/Reply | RTT < 5ms, Packet Loss = 0% |
| **TC-04** | Ứng dụng | Truy cập Cổng thông tin nội bộ HQ (HTTP) | Remote PC -> `192.168.10.50:80` | HTTP GET / TCP 80 | HTTP 200 OK, Portal hiển thị IP nguồn VPN `10.8.0.2` |
| **TC-05** | Chức năng | Thiết lập đường hầm Site-to-Site OpenVPN | HQ GW <=> Branch GW | UDP 1195 / TLS 1.3 | Interface ảo `tun1` (HQ) & `tun0` (Branch) ở trạng thái UP |
| **TC-06** | Định tuyến | Thông suốt mạng nội bộ LAN-to-LAN hai chiều | `192.168.20.50` <=> `192.168.10.50` | ICMP Echo | Ping 2 chiều thành công, không cần NAT trung gian |
| **TC-07** | Định tuyến | Xác nhận chặng định tuyến (Traceroute) | Branch PC -> HQ Server | UDP/ICMP Traceroute | Đi qua Gateway tunnel `10.9.0.1`, không lộ IP WAN `172.16.1.x` |
| **TC-08** | An ninh | Phân tích gói tin WAN (OpenVPN Tunnel) | Card WAN `eth0` trên HQ GW | OpenVPN UDP 1194/1195 | 100% Payload mã hóa AES-256-GCM, không lộ bản rõ HTTP/ICMP |
| **TC-09** | An ninh | Phân tích gói tin WAN (IPsec ESP & IKEv2) | Card WAN `eth0` trên HQ GW | ESP (Proto 50), UDP 500 | Gói tin ESP có SPI/Sequence, Payload mã hóa, IKE đàm phán bảo mật |
| **TC-10** | An ninh | Kiểm thử Thu hồi chứng chỉ số (CRL) | Client1 (bị thu hồi) -> HQ GW | TLS Handshake | Server từ chối kết nối: `TLS_ERROR: CRL check failed` |
| **TC-11** | An ninh | Chống rò rỉ dữ liệu khi ngắt kết nối (Killswitch) | Ngắt dịch vụ OpenVPN S2S | LAN-to-LAN Traffic | Chặn toàn bộ traffic, không rò rỉ gói tin bản rõ ra WAN |

---

## 2. CHI TIẾT CÁC CA KIỂM THỬ (TEST CASE SPECIFICATIONS)

### TC-01: Kết Nối Remote Access Client-to-Site
- **Mục tiêu:** Xác minh máy khách ngoài Internet (`VM-Remote-PC`) kết nối thành công tới máy chủ OpenVPN Server tại Trụ sở chính (`VM-HQ-GW`) bằng chứng chỉ số X.509 và khóa `ta.key`.
- **Môi trường:** `VM-Remote-PC` (Windows 10/11) -> `VM-HQ-GW` (Ubuntu 22.04 LTS).
- **Điều kiện tiên quyết:** Dịch vụ `openvpn-server@server.service` trên `VM-HQ-GW` đang hoạt động (`active (running)`).
- **Các bước thực hiện:**
  1. Mở phần mềm **OpenVPN GUI** trên Windows.
  2. Import file cấu hình [client1.ovpn](file:///c:/University%20Coding%20Project/VPN-Site-to-Site-and-Client-to-Site-Implementation/openvpn/client-to-site/client/template.ovpn).
  3. Nhấp chuột phải vào biểu tượng OpenVPN ở Taskbar -> chọn **Connect**.
  4. Mở PowerShell/CMD trên Windows, thực thi lệnh:
     ```powershell
     ipconfig /all
     ```
- **Kết quả kỳ vọng:**
  - Biểu tượng OpenVPN GUI chuyển sang màu xanh lá cây.
  - Card mạng ảo `OpenVPN TAP-Windows6` hoặc `Wintun` nhận địa chỉ IP trong dải `10.8.0.x/24` (thông thường là `10.8.0.2`), Subnet Mask `255.255.255.0`, Gateway ảo `10.8.0.1`.
- **Ghi nhận bằng chứng:** Ảnh chụp màn hình OpenVPN GUI Connected (`screenshots/c2s-connection/c2s-01-connected.png`) và output `ipconfig` (`screenshots/c2s-connection/c2s-02-ip-assigned.png`).

---

### TC-02: Kiểm Tra Bảng Định Tuyến Máy Khách (Routing Push)
- **Mục tiêu:** Xác minh chỉ thị `push "route 192.168.10.0 255.255.255.0"` từ máy chủ được nạp thành công vào bảng định tuyến hệ điều hành Windows mà không làm đảo lộn Default Gateway của người dùng (Split-Tunneling).
- **Môi trường:** `VM-Remote-PC` (Windows).
- **Điều kiện tiên quyết:** Đã kết nối TC-01 thành công.
- **Các bước thực hiện:**
  1. Trên Windows `VM-Remote-PC`, mở PowerShell:
     ```powershell
     route print -4
     ```
  2. Tìm kiếm mục tương ứng với dải mạng `192.168.10.0`.
- **Kết quả kỳ vọng:**
  - Xuất hiện dòng định tuyến:
    - **Network Destination:** `192.168.10.0`
    - **Netmask:** `255.255.255.0`
    - **Gateway:** `10.8.0.1` (hoặc IP peer nội bộ `10.8.0.x`)
    - **Interface:** Địa chỉ IP của card OpenVPN TAP (`10.8.0.2`).
  - Default route (`0.0.0.0/0`) vẫn trỏ về card mạng vật lý gốc của máy khách (đảm bảo Internet gia đình không bị ảnh hưởng).
- **Ghi nhận bằng chứng:** Ảnh chụp bảng route Windows (`screenshots/routing-tables/c2s-03-route-print.png`).

---

### TC-03: Ping Máy Chủ Nội Bộ HQ Qua Client-to-Site Tunnel
- **Mục tiêu:** Kiểm tra khả năng đóng gói gói tin ICMP qua đường hầm ảo `tun0` và chuyển tiếp an toàn tới Máy chủ nội bộ (`VM-HQ-Server`).
- **Môi trường:** `VM-Remote-PC` (`10.8.0.2`) -> `VM-HQ-Server` (`192.168.10.50`).
- **Điều kiện tiên quyết:** TC-01 và TC-02 đạt; `net.ipv4.ip_forward = 1` trên `VM-HQ-GW`.
- **Các bước thực hiện:**
  1. Trên PowerShell `VM-Remote-PC`:
     ```powershell
     ping -n 5 10.8.0.1
     ping -n 5 192.168.10.50
     ```
- **Kết quả kỳ vọng:**
  - Cả 2 lệnh ping đều phản hồi: `Reply from 192.168.10.50: bytes=32 time<5ms TTL=63`.
  - Tỷ lệ mất gói: 0% (`0% loss`).
  - TTL = 63 (chứng minh gói tin đã giảm 1 hop qua Gateway chuyển tiếp).

---

### TC-04: Truy Cập Cổng Thông Tin Nội Bộ HQ (HTTP Web Portal)
- **Mục tiêu:** Kiểm tra giao tiếp ứng dụng tầng cao (HTTP TCP Port 80), tải trang web quản trị và kiểm tra chức năng đo đạc tốc độ bảo mật.
- **Môi trường:** `VM-Remote-PC` -> `VM-HQ-Server:80`.
- **Điều kiện tiên quyết:** Nginx đang chạy trên `VM-HQ-Server`, Portal đặt tại `/var/www/html/`.
- **Các bước thực hiện:**
  1. Trên Windows `VM-Remote-PC`, mở trình duyệt web (Edge/Chrome/Firefox), truy cập:
     `http://192.168.10.50`
  2. Quan sát khung hiển thị thông tin bảo mật và IP kết nối.
  3. Bấm nút **"Test Download Speed"** hoặc chạy thử tải file 1MB:
     ```powershell
     Invoke-WebRequest -Uri "http://192.168.10.50/files/benchmark-payload-1mb.dat" -OutFile "$env:TEMP\benchmark.dat"
     ```
- **Kết quả kỳ vọng:**
  - Giao diện **HQ Intranet Portal** hiển thị giao diện Cyber Security màu xanh neon và đen chuẩn mực.
  - Widget trạng thái nhận diện rõ IP nguồn là `10.8.0.2` (IP VPN an toàn).
  - Tải file 1MB thành công, mã trạng thái HTTP 200 OK.
- **Ghi nhận bằng chứng:** Ảnh chụp giao diện Portal nội bộ (`screenshots/c2s-connection/c2s-04-web-portal.png`).

---

### TC-05: Thiết Lập Đường Hầm Site-to-Site OpenVPN
- **Mục tiêu:** Kiểm tra khả năng kết nối tự động giữa 2 Gateway trụ sở (`VM-HQ-GW`) và chi nhánh (`VM-Branch-GW`) qua đường hầm định tuyến OpenVPN Routed Tunnel.
- **Môi trường:** `VM-HQ-GW` (`172.16.1.10`) <=> `VM-Branch-GW` (`172.16.1.20`).
- **Điều kiện tiên quyết:** Dịch vụ `openvpn-server@s2s-hq` trên HQ và `openvpn-client@s2s-branch` trên Branch đã cấu hình.
- **Các bước thực hiện:**
  1. Trên `VM-HQ-GW`:
     ```bash
     sudo systemctl status openvpn-server@s2s-hq.service
     ip addr show dev tun1
     cat /var/log/openvpn/s2s-status.log
     ```
  2. Trên `VM-Branch-GW`:
     ```bash
     sudo systemctl status openvpn-client@s2s-branch.service
     ip addr show dev tun0
     ```
- **Kết quả kỳ vọng:**
  - HQ Gateway: Interface `tun1` nhận IP `10.9.0.1/24`, trạng thái `UP`.
  - Branch Gateway: Interface `tun0` nhận IP `10.9.0.2/24`, trạng thái `UP`.
  - File log hiển thị kết nối `Initialization Sequence Completed`.
- **Ghi nhận bằng chứng:** Ảnh chụp trạng thái interface (`screenshots/s2s-tunnel/s2s-01-tunnel-status.png`).

---

### TC-06: Thông Suốt Mạng Nội Bộ LAN-to-LAN Hai Chiều (Site-to-Site)
- **Mục tiêu:** Xác minh máy trạm chi nhánh (`VM-Branch-PC`) và máy chủ trụ sở (`VM-HQ-Server`) liên lạc trực tiếp trong suốt hai chiều thông qua đường hầm Site-to-Site mà không bị NAT che giấu địa chỉ IP gốc.
- **Môi trường:** `VM-Branch-PC` (`192.168.20.50`) <=> `VM-HQ-Server` (`192.168.10.50`).
- **Điều kiện tiên quyết:** TC-05 hoạt động; quy tắc `iroute 192.168.20.0 255.255.255.0` trong CCD đã được nạp.
- **Các bước thực hiện:**
  1. Chiều xuôi (Branch -> HQ): Từ `VM-Branch-PC` ping tới `VM-HQ-Server`:
     ```bash
     ping -c 5 192.168.10.50
     curl -I http://192.168.10.50
     ```
  2. Chiều ngược (HQ -> Branch): Từ `VM-HQ-Server` ping tới `VM-Branch-PC`:
     ```bash
     ping -c 5 192.168.20.50
     ```
- **Kết quả kỳ vọng:**
  - 100% gói tin ICMP phản hồi thành công ở cả 2 chiều, packet loss = 0%.
  - Lệnh curl trả về HTTP/1.1 200 OK.
  - Trên Access log Nginx (`/var/log/nginx/access.log`), IP client truy cập được ghi nhận đúng là `192.168.20.50` (chứng minh định tuyến thuần Routed Tunnel, không bị SNAT/Masquerade).
- **Ghi nhận bằng chứng:** Ảnh chụp màn hình ping 2 chiều (`screenshots/s2s-tunnel/s2s-02-ping-lan-lan.png`).

---

### TC-07: Xác Nhận Chặng Định Tuyến Bằng Traceroute
- **Mục tiêu:** Chứng minh toàn bộ dữ liệu luân chuyển giữa 2 chi nhánh đi xuyên qua đường hầm VPN bảo mật, không xuất hiện bất kỳ IP WAN trung gian nào làm rò rỉ cấu trúc mạng.
- **Môi trường:** `VM-Branch-PC` (`192.168.20.50`) -> `VM-HQ-Server` (`192.168.10.50`).
- **Các bước thực hiện:**
  1. Trên `VM-Branch-PC`:
     ```bash
     traceroute -n 192.168.10.50
     ```
- **Kết quả kỳ vọng:**
  - Chặng 1: `192.168.20.1` (Branch Gateway LAN interface)
  - Chặng 2: `10.9.0.1` (HQ Gateway Tunnel interface)
  - Chặng 3: `192.168.10.50` (HQ Server đích)
  - **Tuyệt đối KHÔNG xuất hiện** IP mạng ngoài `172.16.1.10` hay `172.16.1.20`.
- **Ghi nhận bằng chứng:** Ảnh chụp terminal traceroute (`screenshots/s2s-tunnel/s2s-03-traceroute.png`).

---

### TC-08: Phân Tích Gói Tin WAN (OpenVPN Tunnel Security)
- **Mục tiêu:** Bắt gói tin trên giao diện mạng công cộng `eth0` trong lúc máy trạm truyền file nhạy cảm và HTTP để kiểm chứng tính toàn vẹn và bí mật của mã hóa AES-256-GCM.
- **Môi trường:** Card mạng `eth0` trên `VM-HQ-GW`.
- **Các bước thực hiện:**
  1. Trên `VM-HQ-GW`, chạy tcpdump bắt gói tin trên cổng WAN:
     ```bash
     sudo tcpdump -i eth0 -nn "udp port 1194 or udp port 1195" -c 50 -X
     ```
  2. Đồng thời trên `VM-Remote-PC` hoặc `VM-Branch-PC`, gửi request HTTP tải tài liệu:
     ```bash
     curl http://192.168.10.50/files/financial-report-q4-internal.txt
     ```
  3. Kiểm tra payload bắt được bằng tcpdump / Wireshark.
- **Kết quả kỳ vọng:**
  - 100% gói tin bắt được là OpenVPN UDP datagram.
  - Trường dữ liệu (Payload) là các byte ngẫu nhiên (Entropy cao).
  - Không xuất hiện bất kỳ chuỗi bản rõ nào như `GET /files/...`, `HTTP/1.1`, hoặc nội dung tài chính `Doanh thu Q4`.
- **Ghi nhận bằng chứng:** Ảnh chụp Wireshark phân tích mã hóa (`screenshots/wireshark-evidence/ws-01-wan-encrypted.png`).

---

### TC-09: Phân Tích Gói Tin WAN (IPsec ESP & IKEv2 Security)
- **Mục tiêu:** Bắt gói tin đường hầm strongSwan IPsec IKEv2, xác nhận cơ chế đóng gói giao thức Encapsulating Security Payload (ESP Protocol 50) và đàm phán IKE SA.
- **Môi trường:** Card mạng `eth0` trên `VM-HQ-GW` khi hệ thống đang ở chế độ IPsec.
- **Các bước thực hiện:**
  1. Chuyển hệ thống sang chế độ IPsec:
     ```bash
     sudo ./scripts/switch-vpn-mode.sh ipsec
     ```
  2. Bắt gói tin trên `eth0`:
     ```bash
     sudo tcpdump -i eth0 -nn "proto 50 or udp port 500 or udp port 4500" -c 50
     ```
  3. Từ `VM-Branch-PC`, thực hiện ping `192.168.10.50`.
- **Kết quả kỳ vọng:**
  - Xuất hiện các gói tin `ESP (spi=0x..., seq=...)`.
  - Không thể đọc được IP header nguồn/đích nội bộ `192.168.20.50` và `192.168.10.50` từ phía WAN vì IPsec Tunnel mode đã bọc một Outer IP Header mới (`172.16.1.20 -> 172.16.1.10`).
- **Ghi nhận bằng chứng:** Ảnh chụp Wireshark ESP Packet (`screenshots/wireshark-evidence/ws-02-ipsec-esp.png`).

---

### TC-10: Kiểm Thử An Ninh Thu Hồi Chứng Chỉ Số (CRL Revocation)
- **Mục tiêu:** Đảm bảo khi một nhân viên nghỉ việc hoặc thiết bị bị mất, chứng chỉ của họ bị đưa vào Danh sách thu hồi chứng chỉ (CRL) và hệ thống lập tức từ chối kết nối ngay trong bước bắt tay TLS.
- **Môi trường:** `VM-HQ-GW` và `VM-Remote-PC`.
- **Các bước thực hiện:**
  1. Trên `VM-HQ-GW`, thực hiện thu hồi chứng chỉ `client1`:
     ```bash
     cd /home/student/openvpn-ca
     ./easyrsa revoke client1
     ./easyrsa gen-crl
     sudo cp pki/crl.pem /etc/openvpn/server/crl.pem
     sudo chmod 644 /etc/openvpn/server/crl.pem
     ```
  2. Trên `VM-Remote-PC`, thực hiện ngắt kết nối và bấm **Connect** lại.
  3. Kiểm tra log OpenVPN GUI và log server `/var/log/openvpn/openvpn-status.log`.
- **Kết quả kỳ vọng:**
  - Client không thể kết nối lại.
  - Nhật ký OpenVPN GUI báo lỗi: `VERIFY ERROR: ... certificate revoked`.
  - Nhật ký máy chủ OpenVPN Server ghi: `TLS_ERROR: CRL check failed for client1`.
- **Ghi nhận bằng chứng:** Ảnh chụp log từ chối kết nối (`screenshots/c2s-connection/sec-01-crl-revoked.png`).

---

### TC-11: Chống Rò Rỉ Dữ Liệu Khi Đứt Đường Truyền (Failover & Anti-Leakage)
- **Mục tiêu:** Xác minh khi dịch vụ VPN bị dừng đột ngột, các gói tin dữ liệu nội bộ không bao giờ bị nhân Linux định tuyến bản rõ ra cổng WAN công cộng (Bảo vệ thông tin tuyệt đối - Blackhole Routing).
- **Môi trường:** `VM-Branch-GW` và `VM-HQ-GW`.
- **Các bước thực hiện:**
  1. Trên `VM-HQ-GW`, dừng đột ngột dịch vụ OpenVPN S2S:
     ```bash
     sudo systemctl stop openvpn-server@s2s-hq.service
     ```
  2. Bắt gói tin trên card WAN `eth0` của `VM-Branch-GW`:
     ```bash
     sudo tcpdump -i eth0 -nn "icmp or port 80" -c 10
     ```
  3. Trên `VM-Branch-PC`, liên tục gửi lệnh ping:
     ```bash
     ping -c 10 192.168.10.50
     ```
- **Kết quả kỳ vọng:**
  - Lệnh ping tại máy trạm báo lỗi `Destination Host Unreachable` hoặc `100% packet loss`.
  - Trên card mạng WAN `eth0`, lệnh tcpdump **không bắt được bất kỳ gói tin ICMP hay HTTP nào** hướng tới `192.168.10.50`. Dữ liệu được chặn và loại bỏ hoàn toàn tại Gateway.
- **Ghi nhận bằng chứng:** Nhật ký tcpdump xác nhận 0 packet leaked.
