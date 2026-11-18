# ĐỀ CƯƠNG SLIDE THUYẾT TRÌNH BÁO CÁO ĐỒ ÁN (PRESENTATION SLIDES OUTLINE)

> **Đề tài 14:** Thiết lập mạng ảo riêng (VPN) Site-to-Site và Client-to-Site: Sử dụng OpenVPN hoặc IPsec để bảo mật kết nối cho nhân viên làm việc từ xa.  
> **Tài liệu:** `docs/presentation/slides.md`  
> **Quy mô:** 18 Slide PowerPoint / Canva (Khuyến nghị thuyết trình trong 10 - 15 phút)  

---

## 📊 NỘI DUNG CHI TIẾT 18 SLIDE BÁO CÁO

---

### SLIDE 1: TRANG BÌA (TITLE SLIDE)
- **Tiêu đề lớn:** BÁO CÁO ĐỒ ÁN AN NINH MẠNG
- **Tên đề tài:** THIẾT LẬP MẠNG RIÊNG ẢO (VPN) SITE-TO-SITE VÀ CLIENT-TO-SITE
- **Phụ đề:** Sử dụng OpenVPN và IPsec strongSwan để bảo mật kết nối cho nhân viên làm việc từ xa
- **Nhóm sinh viên thực hiện:**
  1. Nguyễn Lê Huy Tâm
  2. Nguyễn Sun Sin
  3. Huỳnh Đình Chấn
- **Giảng viên hướng dẫn:** [Điền tên Giảng viên]
- **Thời gian:** Học kỳ I - Năm học 2026 - 2027

---

### SLIDE 2: ĐẶT VẤN ĐỀ & BỐI CẢNH DOANH NGHIỆP (PROBLEM STATEMENT)
- **Xu hướng:** Chuyển đổi mô hình làm việc linh hoạt (Hybrid / Remote Work) và nhu cầu liên kết an toàn giữa Trụ sở chính và các Chi nhánh.
- **Thách thức an ninh mạng:**
  - Nguy cơ nghe lén (Eavesdropping) và tấn công trung gian (Man-in-the-Middle) trên mạng công cộng Internet.
  - Lộ lọt tài liệu mật, thông tin tài chính nội bộ.
  - Tấn công phát lại (Replay Attack) và giả mạo máy trạm ngoài doanh nghiệp.
- **Mục tiêu đề tài:** Thiết kế và hiện thực hóa hạ tầng VPN kép (Client-to-Site & Site-to-Site) với cơ chế xác thực mạnh và mã hóa chuẩn quân sự.

---

### SLIDE 3: KIẾN TRÚC MÔ HÌNH MẠNG PHÒNG LAB (NETWORK TOPOLOGY)
- **Hình ảnh trọng tâm:** Chèn sơ đồ Mermaid kiến trúc mạng 3 dải mạng.
- **Các phân vùng mạng:**
  - **Trụ sở chính HQ (`192.168.10.0/24`):** HQ Gateway (`172.16.1.10`) + HQ Internal Server (`192.168.10.50`).
  - **Chi nhánh Branch (`192.168.20.0/24`):** Branch Gateway (`172.16.1.20`) + Branch PC (`192.168.20.50`).
  - **Mạng WAN công cộng (`172.16.1.0/24`):** Môi trường kết nối trung gian không tin cậy.
  - **Nhân viên từ xa Remote PC (`172.16.1.100`):** Máy trạm ngoài Internet được cấp IP ảo `10.8.0.2`.

---

### SLIDE 4: HẠ TẦNG KHÓA CÔNG KHAI PKI VÀ QUẢN LÝ CHỨNG CHỈ SỐ (PKI & EASY-RSA)
- **Hạ tầng CA Độc lập:** Xây dựng bằng Easy-RSA 3 trên HQ Gateway.
- **Các thành phần mật mã:**
  - **Chứng chỉ số X.509 v3 (2048-bit RSA):** Cấp phát riêng biệt cho Server và từng Client.
  - **Tham số Diffie-Hellman (MODP-2048):** Đảm bảo tính bí mật chuyển tiếp hoàn hảo (Perfect Forward Secrecy - PFS).
  - **Khóa đối xứng `ta.key` (tls-auth):** Chữ ký HMAC tầng tiền bắt tay giúp chống Port Scanning và tấn công DoS/Replay.
- **Quy trình đóng gói profile inline:** Tự động nhúng toàn bộ CA, Cert, Private Key và `ta.key` vào 1 tệp `.ovpn` duy nhất cho người dùng cuối.

---

### SLIDE 5: GIẢI PHÁP 1 — OPENVPN CLIENT-TO-SITE (REMOTE ACCESS)
- **Mục đích:** Cho phép nhân viên làm việc tại nhà hoặc quán cà phê truy cập tài nguyên công ty an toàn.
- **Công nghệ triển khai:**
  - Giao thức UDP Port 1194, card ảo `tun0`.
  - Bộ mã hóa đối xứng: `AES-256-GCM` (Mã hóa và xác thực dữ liệu AEAD).
- **Cơ chế Split-Tunneling thông minh:**
  - Chỉ điều hướng lưu lượng dải `192.168.10.0/24` qua VPN bằng lệnh `push "route"`.
  - Không làm ảnh hưởng tới Default Gateway và băng thông Internet cá nhân của nhân viên.
- **Ứng dụng phía Client:** Kết nối trực quan qua phần mềm OpenVPN GUI trên Windows.

---

### SLIDE 6: ỨNG DỤNG MÔ PHỎNG NỘI BỘ — HQ INTRANET SECURE PORTAL
- **Hình ảnh trọng tâm:** Ảnh chụp giao diện Cổng nội bộ `http://192.168.10.50`.
- **Đặc điểm giao diện:**
  - Thiết kế phong cách Cyber Security Enterprise màu xanh neon và đen.
  - **Widget Network Identity Inspector:** Tự động nhận diện và hiển thị IP nguồn của Client (phân loại rõ ràng: IP VPN an toàn vs IP ngoài bị cảnh báo).
  - **Kho tài liệu bảo mật & Benchmark:** Tích hợp file 1MB/10MB phục vụ đo đạc hiệu năng truyền tải qua đường hầm.

---

### SLIDE 7: GIẢI PHÁP 2 — OPENVPN SITE-TO-SITE ROUTED TUNNEL
- **Mục đích:** Kết nối mạng LAN Trụ sở chính và Chi nhánh thành một thể thống nhất thông qua đường hầm định tuyến.
- **Cấu hình kỹ thuật:**
  - Giao diện ảo `tun1` (HQ: `10.9.0.1`) kết nối với `tun0` (Branch: `10.9.0.2`) qua UDP Port 1195.
  - **Cơ chế Client Config Directory (CCD) & `iroute`:**
    - File cấu hình `ccd/branch-gw` chỉ định tuyến nội bộ `iroute 192.168.20.0 255.255.255.0`.
  - **Truyền thông 2 chiều trong suốt:** Máy trạm 2 bên ping và giao tiếp trực tiếp qua IP nội bộ mà không cần NAT Masquerade.

---

### SLIDE 8: GIẢI PHÁP 3 — MỞ RỘNG SITE-TO-SITE IPSEC STRONGSWAN (IKEv2)
- **Lý do mở rộng:** Nghiên cứu và so sánh giải pháp VPN tiêu chuẩn công nghiệp hoạt động ở Tầng Mạng (Layer 3).
- **Kiến trúc strongSwan IKEv2:**
  - **Giai đoạn 1 (IKE_SA):** Đàm phán bảo mật trên UDP 500, xác thực bằng Pre-Shared Key (PSK 32+ ký tự), Diffie-Hellman Group 14 (MODP-2048).
  - **Giai đoạn 2 (CHILD_SA / ESP):** Đóng gói dữ liệu mã hóa bằng giao thức ESP (Protocol 50) trực tiếp trong nhân Linux (**In-Kernel Linux XFRM**).
- **Kịch bản chuyển đổi linh hoạt:** Phát triển script `switch-vpn-mode.sh` giúp chuyển đổi dứt điểm giữa OpenVPN và IPsec, tránh xung đột định tuyến.

---

### SLIDE 9: SO SÁNH ĐỐI CHIẾU KIẾN TRÚC OPENVPN VS STRONGSWAN IPSEC
- **Bảng so sánh trực quan:**
  | Tiêu chí | OpenVPN Site-to-Site | strongSwan IPsec IKEv2 |
  |---|---|---|
  | **Tầng hoạt động** | Tầng ứng dụng (Userspace daemon qua `/dev/net/tun`) | Tầng mạng (Linux Kernel XFRM Framework) |
  | **Giao thức đóng gói** | UDP Datagram (Port 1195) | Giao thức ESP (IP Protocol 50) |
  | **Interface mạng** | Card mạng ảo `tun0`, `tun1` | Policy-based (Không tạo card ảo) |
  | **Độ trễ RTT (thực nghiệm)** | 2.15 ms | **1.18 ms** (Nhanh hơn 45%) |
  | **Khả năng xuyên tường lửa/NAT**| Xuất sắc (chạy trên 1 cổng tùy chọn) | Cần mở Protocol 50 hoặc NAT-T (UDP 4500) |
- **Kết luận kiến trúc:** IPsec tối ưu cho hạ tầng router và đường truyền cố định; OpenVPN linh hoạt và tiện lợi nhất cho Remote Access.

---

### SLIDE 10: MA TRẬN 11 CA KIỂM THỬ THỰC NGHIỆM (TEST EXECUTION MATRIX)
- **Bảng tổng hợp kết quả 11 ca kiểm thử:**
  - **Kiểm thử chức năng (TC-01, TC-03, TC-05):** Cấp phát IP, ping thông mạng, trạng thái interface UP.
  - **Kiểm thử định tuyến (TC-02, TC-06, TC-07):** Bảng route Windows, ping 2 chiều không NAT, traceroute không lộ IP WAN.
  - **Kiểm thử ứng dụng (TC-04):** HTTP 200 OK, Cổng Web nội bộ nhận diện đúng IP VPN.
  - **Kiểm thử an ninh & mật mã (TC-08, TC-09, TC-10, TC-11):** Bắt gói tin WAN, thu hồi chứng chỉ CRL, chống rò rỉ khi ngắt VPN.
- **Tỷ lệ hoàn thành:** **100% (11/11 Ca kiểm thử ĐẠT - PASS)**.

---

### SLIDE 11: PHÂN TÍCH GÓI TIN WIRESHARK — ĐỐI CHỨNG WAN VS LAN
- **Phân tích 3 trạng thái gói tin:**
  1. **Bản rõ (Cleartext HTTP trên card LAN `eth1`):** Lộ rõ địa chỉ IP, URL truy cập và nội dung tài liệu mật.
  2. **Đường hầm OpenVPN (trên card WAN `eth0`):** 100% bọc trong UDP 1194/1195. Dữ liệu là ciphertext hỗn loạn, kèm Packet ID chống Replay.
  3. **Đường hầm IPsec (trên card WAN `eth0`):** Gói tin ESP mang trường SPI và Sequence Number, Outer IP Header che giấu hoàn toàn dải IP nguồn/đích nội bộ.

---

### SLIDE 12: ĐÁNH GIÁ MÔ HÌNH ĐE DỌA AN NINH MẠNG (STRIDE THREAT MODEL)
- **Đánh giá 6 nguy cơ theo mô hình STRIDE:**
  - **Spoofing (Giả mạo):** Phòng chống bằng xác thực song phương chứng chỉ X.509 và IKEv2 PSK phức tạp.
  - **Tampering (Sửa đổi):** Phòng chống bằng mã hóa kèm thẻ xác thực AEAD Tag (AES-256-GCM).
  - **Repudiation (Chối bỏ):** Kiểm soát nhờ cơ chế quản lý chứng chỉ nối tiếp của CA (Serial tracking).
  - **Information Disclosure (Lộ thông tin):** Loại bỏ hoàn toàn nhờ mã hóa đường hầm 256-bit.
  - **Denial of Service (Từ chối dịch vụ):** Chặn đứng quét nmap và UDP flood bằng chữ ký HMAC `ta.key`.
  - **Elevation of Privilege (Leo thang đặc quyền):** Hạ quyền tiến trình OpenVPN sang `nobody`/`nogroup`.

---

### SLIDE 13: BẢO MẬT ÂM BẢN — THU HỒI CHỨNG CHỈ SỐ (CRL REVOCATION)
- **Tình huống thực tế:** Nhân viên nghỉ việc hoặc thiết bị máy trạm bị thất lạc.
- **Giải pháp triển khai:**
  - CA thu hồi chứng chỉ qua lệnh `./easyrsa revoke client1` và cập nhật tệp `crl.pem`.
  - OpenVPN Server nạp chỉ thị `crl-verify` tự động kiểm tra theo thời gian thực mà không cần khởi động lại dịch vụ.
- **Kết quả thực nghiệm:**
  - Client lập tức bị từ chối kết nối tại bước bắt tay TLS: `VERIFY ERROR: certificate revoked`.
  - Log server ghi nhận rõ danh tính và địa chỉ IP bị chặn.

---

### SLIDE 14: BỘ CÔNG CỤ TỰ ĐỘNG HÓA & TRẢI NGHIỆM NGƯỜI DÙNG (DEVOPS / AUTOMATION)
- **Tiện ích Windows `quick-setup.bat`:**
  - Menu 10 chức năng: Ping toàn mạng, mở Web Portal, kiểm tra routing table, chạy traceroute, SSH nhanh và đo tốc độ tải file.
- **Kịch bản Linux `scripts/deploy-all.sh`:**
  - Triển khai 1-click tự động hóa trọn gói cho từng node máy ảo (`hq-gw`, `branch-gw`, `hq-server`, `branch-pc`).
- **Kịch bản điều khiển:**
  - `switch-vpn-mode.sh`: Chuyển đổi an toàn giữa 2 công nghệ VPN.
  - `capture-traffic.sh`: Tự động hóa bắt gói tin tcpdump phục vụ Wireshark.

---

### SLIDE 15: KẾT LUẬN & ĐÓNG GÓP CỦA ĐỀ TÀI
- **Kết quả đạt được:**
  - Hiện thực hóa thành công mô hình mạng VPN doanh nghiệp hoàn chỉnh đáp ứng đầy đủ yêu cầu của đề tài 14.
  - Kết hợp linh hoạt cả OpenVPN (Client-to-Site và Site-to-Site) và strongSwan IPsec IKEv2.
  - Xây dựng hệ thống tự động hóa hoàn chỉnh từ cấp phát chứng chỉ, cấu hình mạng tới kiểm thử an ninh.
  - Thu thập bằng chứng Wireshark thực nghiệm đối chứng và kiểm thử an ninh chuyên sâu.
- **Khả năng ứng dụng:** Mô hình có thể áp dụng ngay cho các doanh nghiệp vừa và nhỏ (SMB) cần giải pháp kết nối từ xa bảo mật với chi phí tối ưu.

---

### SLIDE 16: HƯỚNG PHÁT TRIỂN MỞ RỘNG (FUTURE WORK)
1. **Xác thực Đa Yếu Tố (MFA/2FA):** Tích hợp mã OTP qua Google Authenticator hoặc kết nối hệ thống máy chủ xác thực tập trung RADIUS / LDAP.
2. **Hạ tầng Dự phòng Nóng (High Availability - HA):** Cấu hình cặp Gateway Active/Passive sử dụng Keepalived (VRRP) để tự động failover khi có sự cố.
3. **Quản lý chứng chỉ doanh nghiệp:** Tích hợp HashiCorp Vault hoặc Smallstep CA để tự động hóa vòng đời chứng chỉ số qua giao thức ACME/EST.

---

### SLIDE 17: PHẦN TRÌNH DIỄN THỰC NGHIỆM (LIVE DEMO)
*(Slide chuyển tiếp bước vào phần thực hành demo trực tiếp)*
- Demo 1: Kết nối Remote Worker và truy cập Cổng nội bộ HQ.
- Demo 2: Kiểm tra thông suốt Site-to-Site LAN-to-LAN.
- Demo 3: Chuyển đổi sang strongSwan IPsec và kiểm tra SA.
- Demo 4: Bắt gói tin Wireshark chứng minh mã hóa.
- Demo 5: Thu hồi chứng chỉ (CRL) từ chối truy cập thời gian thực.

---

### SLIDE 18: LỜI CẢM ƠN & HỎI ĐÁP (Q&A)
- **Lời cảm ơn:** Nhóm xin chân thành cảm ơn Quý Thầy/Cô trong Hội đồng đã lắng nghe bài báo cáo!
- **Mời Hội đồng đặt câu hỏi:** Nhóm rất mong nhận được những ý kiến đóng góp quý báu từ Quý Thầy/Cô.

