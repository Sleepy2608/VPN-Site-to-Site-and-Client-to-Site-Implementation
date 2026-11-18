# KỊCH BẢN DEMO TRỰC TIẾP TRÊN PHÒNG HỘI ĐỒNG BẢO VỆ ĐỒ ÁN (LIVE DEMO SCRIPT)

> **Đề tài 14:** Thiết lập mạng ảo riêng (VPN) Site-to-Site và Client-to-Site: Sử dụng OpenVPN hoặc IPsec để bảo mật kết nối cho nhân viên làm việc từ xa.  
> **Tài liệu:** `docs/presentation/demo-script.md`  
> **Thời lượng khuyến nghị:** 10 - 15 phút  

---

## TỔNG QUAN TIẾN TRÌNH TRÌNH DIỄN (5 MÀN LIỀN MẠCH)

```mermaid
flowchart LR
    D1["Màn 1: Chuẩn bị & Bật Lab\n(5 VMs sẵn sàng)"] --> D2["Màn 2: Demo Client-to-Site\n(Remote Worker truy cập Portal)"]
    D2 --> D3["Màn 3: Demo Site-to-Site\n(Ping LAN-LAN & Traceroute)"]
    D3 --> D4["Màn 4: So Sánh & Chuyển Đổi IPsec\n(switch-vpn-mode & statusall)"]
    D4 --> D5["Màn 5: Đỉnh Cao An Ninh\n(Wireshark & Thu Hồi CRL)"]
```

---

### Màn 1: Khởi Động Môi Trường & Giới Thiệu Lab (1 phút)
1. **Chuẩn bị trước khi lên bục thuyết trình:**
   - Khởi động sẵn 5 máy ảo trong VirtualBox/VMware: `VM-HQ-GW`, `VM-Branch-GW`, `VM-HQ-Server`, `VM-Branch-PC`, `VM-Remote-PC`.
   - Mở sẵn cửa sổ terminal của 2 Gateway và cửa sổ Windows của Remote PC.
2. **Lời dẫn thuyết minh mẫu:**
   > *"Kính thưa Thầy/Cô Hội đồng, hệ thống phòng Lab của nhóm đã sẵn sàng với 5 máy ảo mô phỏng hoàn chỉnh mạng doanh nghiệp: Trụ sở chính HQ (192.168.10.0/24), Chi nhánh Branch (192.168.20.0/24) và Nhân viên từ xa kết nối qua mạng công cộng WAN (172.16.1.0/24)."*

---

### Màn 2: Demo Client-to-Site OpenVPN — Nhân Viên Từ Xa Kết Nối An Toàn (3 phút)
1. **Thao tác 1 - Kết nối VPN:**
   - Trên máy Windows `VM-Remote-PC` (IP WAN `172.16.1.100`), mở phần mềm **OpenVPN GUI**.
   - Nhấp chuột phải chọn profile `client1` -> bấm **Connect**.
   - Biểu tượng OpenVPN chuyển sang màu **xanh lá cây** báo hiệu kết nối thành công.
2. **Thao tác 2 - Xác nhận IP và Routing Split-Tunneling:**
   - Mở tiện ích `quick-setup.bat` (hoặc CMD):
     ```cmd
     ipconfig
     route print -4 | findstr 192.168.10.
     ```
   - **Chỉ rõ trên màn chiếu:**
     - Card ảo `OpenVPN TAP-Windows6` nhận địa chỉ IP an toàn `10.8.0.2`.
     - Chỉ thị route `192.168.10.0/24` trỏ qua Gateway `10.8.0.1`.
     - Default Gateway (`0.0.0.0/0`) vẫn trỏ về card mạng vật lý gốc (Split-Tunneling giúp người dùng vẫn lướt Internet bình thường không bị chậm).
3. **Thao tác 3 - Truy cập Cổng thông tin nội bộ HQ (Intranet Portal):**
   - Mở trình duyệt web truy cập: `http://192.168.10.50`
   - **Điểm nhấn thuyết minh:** Trang Web hiển thị giao diện Cyber Security với widget nhận diện IP nguồn:
     `SECURE CLIENT DETECTED: 10.8.0.2 (Remote Worker VPN Tunnel)`.
   - Bấm nút **"Test Download Speed"** để tải file mẫu 1MB qua đường hầm mã hóa AES-256-GCM.

---

### Màn 3: Demo Site-to-Site OpenVPN Routed Tunnel (3 phút)
1. **Thao tác 1 - Kiểm tra trạng thái đường hầm giữa 2 Gateway:**
   - Trên `VM-HQ-GW`, chạy script kiểm tra tự động:
     ```bash
     bash scripts/verify-s2s.sh
     ```
   - Chỉ rõ interface ảo `tun1` (IP `10.9.0.1`) trên HQ và `tun0` (IP `10.9.0.2`) trên Branch ở trạng thái `UP`.
2. **Thao tác 2 - Ping thông suốt hai chiều giữa 2 dải mạng LAN:**
   - Từ máy trạm chi nhánh `VM-Branch-PC` (`192.168.20.50`):
     ```bash
     ping -c 4 192.168.10.50
     ```
   - Kết quả: **0% packet loss, RTT < 2ms**.
3. **Thao tác 3 - Traceroute chứng minh đường đi qua đường hầm bảo mật:**
   - Thực thi lệnh:
     ```bash
     traceroute -n 192.168.10.50
     ```
   - **Điểm nhấn thuyết minh:**
     - Chặng 1: `192.168.20.1` (Branch GW LAN).
     - Chặng 2: `10.9.0.1` (Tunnel HQ GW).
     - Chặng 3: `192.168.10.50` (HQ Server đích).
     - **Tuyệt đối không xuất hiện bất kỳ IP WAN 172.16.1.x nào**, chứng minh dữ liệu được định tuyến hoàn toàn bên trong đường hầm mã hóa.

---

### Màn 4: Demo Mở Rộng IPsec strongSwan & Chuyển Đổi Chế Độ An Toàn (3 phút)
1. **Thao tác 1 - Chuyển đổi linh hoạt sang chế độ IPsec:**
   - Trên cả 2 Gateway, chạy script chuyển đổi:
     ```bash
     sudo bash scripts/switch-vpn-mode.sh ipsec
     ```
   - Script tự động dừng OpenVPN S2S, bật strongSwan và cấu hình lại iptables để tránh xung đột định tuyến.
2. **Thao tác 2 - Kiểm tra trạng thái Security Association (SA):**
   - Chạy lệnh:
     ```bash
     sudo ipsec statusall
     ```
   - **Chỉ rõ trên màn chiếu:**
     - Kết nối `hq-to-branch` đạt trạng thái `ESTABLISHED` (IKEv2 đàm phán thành công qua Diffie-Hellman Group 14 MODP-2048).
     - Child SA đạt `INSTALLED, TUNNEL` với thuật toán `AES_GCM_16_256`.
3. **Thao tác 3 - Kiểm tra lại kết nối LAN-to-LAN:**
   - Từ `VM-Branch-PC` tiếp tục ping `192.168.10.50` -> Thông suốt hoàn toàn với độ trễ RTT thấp hơn ~45% so với OpenVPN nhờ xử lý trực tiếp trong nhân Linux (In-Kernel XFRM).

---

### Màn 5: Đỉnh Cao An Ninh — Bắt Gói Tin Wireshark & Thu Hồi Chứng Chỉ CRL (4 phút)
1. **Thao tác 1 - Bắt gói tin đối chứng trên Wireshark (Mã hóa vs Bản rõ):**
   - Bật script bắt gói trên card WAN `eth0` của HQ Gateway:
     ```bash
     sudo bash scripts/capture-traffic.sh -i eth0 -m all-vpn -c 30
     ```
   - Gửi request HTTP từ Remote PC tải tài liệu tài chính nội bộ.
   - **Chỉ rõ trên Wireshark:** Trên cổng WAN `eth0`, 100% gói tin là `OpenVPN UDP` hoặc `ESP (Protocol 50)`. Payload là chuỗi ngẫu nhiên không thể đọc được.
   - Khi chuyển bộ lọc sang card LAN `eth1`, thấy rõ gói tin HTTP `GET /files/...` bản rõ sau khi Gateway giải mã.
2. **Thao tác 2 - Kiểm thử Thu hồi chứng chỉ số (CRL Revocation):**
   - Giả lập tình huống: Nhân viên `client1` bị mất máy hoặc thôi việc cần thu hồi quyền truy cập.
   - Trên CA Server (`VM-HQ-GW`):
     ```bash
     cd ~/openvpn-ca
     ./easyrsa revoke client1
     ./easyrsa gen-crl
     sudo cp pki/crl.pem /etc/openvpn/server/crl.pem
     ```
   - Trên `VM-Remote-PC`, ngắt kết nối và bấm **Connect** lại.
   - **Kết quả trực tiếp trên máy chiếu:** Kết nối bị từ chối ngay lập tức!
   - Log OpenVPN GUI hiển thị: `VERIFY ERROR: ... certificate revoked`.
   - Log server OpenVPN báo lỗi: `TLS_ERROR: CRL check failed for client1`.
   - **Lời kết thuyết minh:** *"Hệ thống đã thu hồi quyền truy cập trong thời gian thực mà không cần khởi động lại máy chủ và không ảnh hưởng tới bất kỳ nhân viên nào khác."*

