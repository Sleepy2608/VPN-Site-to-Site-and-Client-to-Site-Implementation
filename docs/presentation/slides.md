# ĐỀ CƯƠNG BỘ SLIDE THUYẾT TRÌNH BÁO CÁO ĐỒ ÁN (CHUẨN UTH)
## Đề tài: Thiết lập Mạng riêng ảo (VPN) Site-to-Site và Client-to-Site
**Quy chuẩn trình bày UTH (Trường ĐH Giao thông vận tải TP.HCM):**
- **Slide mẫu:** Sử dụng mẫu chính thức của UTH.
- **Quy định font chữ:** Tiêu đề Size 32, Nội dung Size 26.
- **Quy mô:** 30 slide nội dung (nằm trong dải quy định 25–40 slide, chưa bao gồm slide bìa).

---

### SLIDE 0: BÌA BÁO CÁO (CHƯA TÍNH VÀO 30 SLIDE NỘI DUNG)
- **Tiêu đề (Size 32):** BÁO CÁO ĐỒ ÁN MÔN HỌC AN NINH MẠNG
- **Nội dung (Size 26):**
  - **Đề tài:** Thiết lập mạng riêng ảo (VPN) Site-to-Site và Client-to-Site
  - **Giảng viên hướng dẫn:** [Tên Giảng Viên]
  - **Sinh viên thực hiện:** Nguyễn Lê Huy Tâm, Nguyễn Sun Sin, Huỳnh Đình Chấn
  - **Đơn vị:** Trường Đại học Giao thông vận tải TP.HCM (UTH) — Năm 2026

---

### PHẦN 1: TỔNG QUAN LÝ THUYẾT & RỦI RO AN NINH (SLIDE 1 – 7)

#### SLIDE 1: BỐI CẢNH VÀ ĐẶT VẤN ĐỀ
- **Tiêu đề (Size 32):** Bối cảnh và Nhu cầu Bảo mật Kết nối
- **Nội dung (Size 26):**
  - Xu hướng làm việc từ xa (Work from Anywhere) và liên kết đa chi nhánh.
  - Môi trường truyền dẫn Internet công cộng tiềm ẩn nguy cơ mất an toàn.
  - Nhu cầu thiết lập kênh truyền riêng tư, xác thực mạnh và chi phí tối ưu.

#### SLIDE 2: KHÁI NIỆM & NGUYÊN LÝ HOẠT ĐỘNG VPN
- **Tiêu đề (Size 32):** Khái niệm và Nguyên lý Mạng riêng ảo VPN
- **Nội dung (Size 26):**
  - Tạo lập đường hầm ảo (Tunnel) trên nền tảng hạ tầng mạng công cộng.
  - Ba trụ cột an ninh: Tính bí mật (Confidentiality), Toàn vẹn (Integrity), Xác thực (Authentication).
  - Kỹ thuật đóng gói (Encapsulation) và mã hóa dữ liệu đầu mối.

#### SLIDE 3: PHÂN LOẠI MÔ HÌNH TRIỂN KHAI VPN
- **Tiêu đề (Size 32):** Phân loại Mô hình VPN Doanh nghiệp
- **Nội dung (Size 26):**
  - **Client-to-Site (Remote Access):** Kết nối nhân viên di động vào mạng nội bộ trụ sở.
  - **Site-to-Site (Network-to-Network):** Kết nối cố định, trong suốt giữa hai mạng LAN.
  - Yêu cầu đồ án: Triển khai đồng thời cả hai mô hình trên cùng hệ thống.

#### SLIDE 4: TỔNG QUAN GIAO THỨC OPENVPN
- **Tiêu đề (Size 32):** Công nghệ OpenVPN và Cơ chế Hoạt động
- **Nội dung (Size 26):**
  - Ứng dụng không gian người dùng (User-space) dựa trên giao diện TUN/TAP.
  - Sử dụng thư viện OpenSSL: Mã hóa AES-256-GCM, bắt tay bảo mật qua TLS.
  - Cơ chế **TLS-Crypt**: Ký số và mã hóa gói tin điều khiển, chống quét cổng và DoS.

#### SLIDE 5: TỔNG QUAN GIAO THỨC IPSEC STRONGSWAN
- **Tiêu đề (Size 32):** Công nghệ IPsec và Bộ giao thức strongSwan
- **Nội dung (Size 26):**
  - Hoạt động tại tầng mạng (Network Layer - Tầng 3 mô hình OSI) trong Kernel Linux.
  - Bắt tay quản lý khóa IKEv2 (Internet Key Exchange v2).
  - Đóng gói mã hóa ESP (Encapsulating Security Payload - IP Protocol 50).

#### SLIDE 6: HẠ TẦNG KHÓA CÔNG KHAI PKI & X.509
- **Tiêu đề (Size 32):** Hạ tầng Khóa công khai PKI và Chứng chỉ số
- **Nội dung (Size 26):**
  - Xây dựng Tổ chức chứng thực số gốc (Root CA) bằng Easy-RSA 3.
  - Cặp khóa bất đối xứng RSA 2048-bit và trao đổi khóa Diffie-Hellman.
  - Chứng chỉ số X.509 v3 định danh thiết bị và người dùng độc lập.

#### SLIDE 7: CÁC NGUY CƠ & RỦI RO AN NINH LIÊN QUAN
- **Tiêu đề (Size 32):** Các Rủi ro An ninh trên Đường truyền Công cộng
- **Nội dung (Size 26):**
  - **Nghe lén (Eavesdropping / Packet Sniffing):** Thu thập bản rõ tài liệu, mật khẩu.
  - **Tấn công trung gian (Man-in-the-Middle):** Đánh chặn và chỉnh sửa gói tin.
  - **Sử dụng chứng chỉ bị đánh cắp:** Thiết bị nhân viên nghỉ việc cố tình kết nối trái phép.

---

### PHẦN 2: THIẾT KẾ MÔ HÌNH LAB TRÊN VMWARE (SLIDE 8 – 12)

#### SLIDE 8: SƠ ĐỒ KIẾN TRÚC TỔNG THỂ PHÒNG LAB
- **Tiêu đề (Size 32):** Kiến trúc Mạng Phòng Lab 5 Máy ảo
- **Nội dung (Size 26):**
  - 5 Máy ảo: VM-HQ-GW, VM-Branch-GW, VM-HQ-Server, VM-Branch-PC, VM-Remote-PC.
  - Nền tảng: VMware Workstation Pro, hệ điều hành Armbian Linux x86_64 và Windows.
  - Chèn sơ đồ khối đen trắng chuẩn Hình 2.1 giữa 3 phân vùng mạng.

#### SLIDE 9: PHÂN TÁCH MẠNG BẰNG LAN SEGMENT
- **Tiêu đề (Size 32):** Phân vùng Mạng cô lập bằng VMware LAN Segment
- **Nội dung (Size 26):**
  - **WAN-Net (172.16.1.0/24):** Mạng WAN giả lập môi trường công cộng Internet.
  - **HQ-LAN-Net (10.74.10.0/24):** Vùng mạng an toàn Trụ sở chính.
  - **Branch-LAN-Net (10.74.20.0/24):** Vùng mạng an toàn Chi nhánh.

#### SLIDE 10: QUY HOẠCH ĐỊA CHỈ IP HỆ THỐNG LAB
- **Tiêu đề (Size 32):** Bảng Quy hoạch Địa chỉ IP và Giao diện
- **Nội dung (Size 26):**
  - HQ-GW: WAN 172.16.1.10 | LAN 10.74.10.1 | Tunnel C2S 10.8.0.1 | S2S 10.9.0.1.
  - Branch-GW: WAN 172.16.1.20 | LAN 10.74.20.1 | Tunnel S2S 10.9.0.2.
  - HQ-Server: LAN 10.74.10.50 | Branch-PC: LAN 10.74.20.50 | Remote-PC: WAN 172.16.1.100.

#### SLIDE 11: CẤU HÌNH MẠNG TĨNH NETPLAN LINUX
- **Tiêu đề (Size 32):** Quản trị Mạng tĩnh bằng Netplan trên Gateway
- **Nội dung (Size 26):**
  - Cấu hình tệp YAML cố định IP, tắt DHCP để chống sai lệch gateway.
  - Không gán default gateway lên mạng WAN giả lập để tránh lặp tuyến.
  - Cơ chế ánh xạ card mạng thực tế (ens33, ens37) linh hoạt qua interfaces.conf.

#### SLIDE 12: ĐỊNH TUYẾN, TƯỜNG LỬA VÀ ĐỒNG BỘ THỜI GIAN
- **Tiêu đề (Size 32):** Hạ tầng Định tuyến và Tường lửa Nền tảng
- **Nội dung (Size 26):**
  - Kích hoạt `net.ipv4.ip_forward = 1` trên nhân hệ điều hành Linux.
  - Đồng bộ thời gian qua giao thức NTP (Chrony) đạt Stratum 3, bảo vệ hiệu lực chứng chỉ.
  - Thiết lập tường lửa iptables kiểm soát chặt luồng FORWARD giữa các vùng mạng.

---

### PHẦN 3: KỊCH BẢN DEMO THỰC NGHIỆM 4 BƯỚC (SLIDE 13 – 26)

#### SLIDE 13: BƯỚC 1 — THIẾT LẬP HẠ TẦNG CA & PKI
- **Tiêu đề (Size 32):** Bước 1: Khởi tạo CA và Cấp phát Chứng chỉ
- **Nội dung (Size 26):**
  - Khởi tạo Root CA độc lập, tạo khóa bí mật bảo vệ bằng thuật toán RSA-2048.
  - Sinh chứng chỉ máy chủ `server.crt` và chứng chỉ người dùng `client1.crt`, `branch-gw.crt`.
  - Sinh khóa xác thực đối xứng bổ sung `ta.key` (TLS-Crypt).

#### SLIDE 14: BƯỚC 1 — CẤU HÌNH DỊCH VỤ OPENVPN GATEWAY
- **Tiêu đề (Size 32):** Bước 1: Cấu hình OpenVPN C2S và S2S trên HQ-GW
- **Nội dung (Size 26):**
  - Dịch vụ C2S: Lắng nghe cổng UDP 1194, cấp IP dải 10.8.0.0/24, push route 10.74.10.0/24.
  - Dịch vụ S2S: Lắng nghe cổng UDP 1195, cấp mạng tunnel 10.9.0.0/24, nạp CCD định tuyến.
  - Thiết lập chế độ quản lý tập trung và cô lập tiến trình an toàn.

#### SLIDE 15: BƯỚC 1 — THIẾT LẬP CLIENT WINDOWS & LINUX
- **Tiêu đề (Size 32):** Bước 1: Thiết lập Máy trạm Client-to-Site và Branch
- **Nội dung (Size 26):**
  - Đóng gói hồ sơ `client1.ovpn` tích hợp chứng chỉ an toàn cho OpenVPN GUI Windows.
  - Kịch bản thiết lập nhanh `quick-setup.bat` và import cấu hình 1 chạm.
  - Branch-GW cấu hình kết nối tự động khi khởi động (systemd openvpn-client).

#### SLIDE 16: BƯỚC 2 — TẤN CÔNG NGHE LÉN TRÊN MẠNG WAN
- **Tiêu đề (Size 32):** Bước 2: Tấn công Nghe lén (Sniffing) khi Chưa có VPN
- **Nội dung (Size 26):**
  - Kẻ tấn công trên WAN (172.16.1.x) khởi chạy công cụ Wireshark / Tcpdump.
  - Nhân viên truy cập dữ liệu nội bộ qua giao thức truyền thống ngoài Internet.
  - Toàn bộ gói tin IP, cổng dịch vụ và luồng dữ liệu truyền qua WAN ở dạng bản rõ.

#### SLIDE 17: BƯỚC 2 — PHÂN TÍCH THIỆT HẠI KHI BỊ KHAI THÁC
- **Tiêu đề (Size 32):** Bước 2: Phân tích Thiệt hại Rò rỉ Dữ liệu Bản rõ
- **Nội dung (Size 26):**
  - Bắt trọn gói tin HTTP GET và nội dung trang web nội bộ trên card eth0.
  - Lộ lọt mã định danh, tài khoản quản trị và tệp tài liệu mật của doanh nghiệp.
  - Chứng minh sự mất an toàn nghiêm trọng nếu không có mã hóa đầu mối.

#### SLIDE 18: BƯỚC 2 — KIỂM THỬ TRUY CẬP TRÁI PHÉP BẰNG CHỨNG CHỈ HỦY
- **Tiêu đề (Size 32):** Bước 2: Kiểm thử Nguy cơ từ Chứng chỉ bị Lạm dụng
- **Nội dung (Size 26):**
  - Mô phỏng trường hợp nhân viên nghỉ việc hoặc thiết bị di động bị đánh cắp.
  - Client cố gắng sử dụng chứng chỉ cũ để thâm nhập hệ thống mạng nội bộ.
  - Nếu thiếu cơ chế danh sách thu hồi CRL, hệ thống sẽ bị xâm nhập trái phép.

#### SLIDE 19: BƯỚC 3 — KÍCH HOẠT PHÒNG THỦ OPENVPN CLIENT-TO-SITE
- **Tiêu đề (Size 32):** Bước 3: Triển khai Phòng thủ OpenVPN C2S
- **Nội dung (Size 26):**
  - Khởi tạo kết nối an toàn từ OpenVPN GUI trên Windows Remote-PC.
  - Bắt tay xác thực 2 chiều bằng cặp chứng chỉ X.509 và khóa TLS-Crypt.
  - Thiết lập kênh truyền mã hóa AES-256-GCM, cấp IP ảo 10.8.0.2.

#### SLIDE 20: BƯỚC 3 — CƠ CHẾ ĐỊNH TUYẾN SPLIT-TUNNELING
- **Tiêu đề (Size 32):** Bước 3: Cơ chế Phân luồng Định tuyến Split-Tunnel
- **Nội dung (Size 26):**
  - Chỉ chuyển tiếp lưu lượng nội bộ (10.74.10.0/24 & 10.74.20.0/24) qua đường hầm VPN.
  - Lưu lượng Internet thông thường đi trực tiếp qua gateway mạng gia đình.
  - Tối ưu hóa băng thông cho Gateway công ty và đảm bảo quyền riêng tư người dùng.

#### SLIDE 21: BƯỚC 3 — KÍCH HOẠT PHÒNG THỦ SITE-TO-SITE (IPSEC / OPENVPN)
- **Tiêu đề (Size 32):** Bước 3: Triển khai Phòng thủ Site-to-Site Liên Chi nhánh
- **Nội dung (Size 26):**
  - Kết nối tự động giữa VM-Branch-GW và VM-HQ-GW.
  - Hỗ trợ linh hoạt 2 chế độ: OpenVPN S2S (UDP 1195) hoặc strongSwan IPsec (IKEv2/ESP).
  - Định tuyến thông suốt hai chiều LAN-to-LAN, máy trạm nội bộ không cần cài phần mềm.

#### SLIDE 22: BƯỚC 3 — THIẾT LẬP CRL VÀ TƯỜNG LỬA CHỐNG RÒ RỈ
- **Tiêu đề (Size 32):** Bước 3: Giám sát Thu hồi CRL và Tường lửa Chống Rò rỉ
- **Nội dung (Size 26):**
  - Cấu hình `crl-verify crl.pem` trên server để kiểm soát danh sách thu hồi thời gian thực.
  - Tường lửa iptables: Cơ chế **Blackhole Anti-Leakage** chặn dữ liệu LAN rò rỉ ra WAN khi đứt VPN.
  - Cơ chế **TCP MSS Clamping** (`--clamp-mss-to-pmtu`) triệt tiêu lỗi phân mảnh gói tin.

#### SLIDE 23: BƯỚC 4 — ĐÁNH GIÁ KẾT QUẢ CLIENT-TO-SITE (TC-01, TC-02, TC-04)
- **Tiêu đề (Size 32):** Bước 4: Kiểm tra Hiệu quả Kết nối Client-to-Site
- **Nội dung (Size 26):**
  - Kết nối thành công, biểu tượng OpenVPN GUI chuyển xanh lá, cấp IP ảo 10.8.0.2.
  - Bảng định tuyến Windows ghi nhận route chính xác đến dải 10.74.10.0/24 qua gateway ảo.
  - Truy cập thành công Cổng thông tin nội bộ `http://10.74.10.50` (HTTP 200 OK).

#### SLIDE 24: BƯỚC 4 — ĐÁNH GIÁ KẾT QUẢ SITE-TO-SITE (TC-05, TC-06, TC-08)
- **Tiêu đề (Size 32):** Bước 4: Kiểm tra Hiệu quả Kết nối Site-to-Site
- **Nội dung (Size 26):**
  - Ping hai chiều thông suốt từ Branch-PC (10.74.20.50) đến HQ-Server (10.74.10.50).
  - Lệnh `traceroute` chứng minh gói tin đi qua các hop mạng riêng: 10.74.20.1 -> 10.9.0.1 -> Server.
  - Đo kiểm băng thông qua Iperf3 đạt mức tối ưu, ổn định không xảy ra hiện tượng nghẽn mạng.

#### SLIDE 25: BƯỚC 4 — ĐỐI CHỨNG BẮT GÓI WIRESHARK TRÊN WAN (TC-07)
- **Tiêu đề (Size 32):** Bước 4: Bằng chứng Bắt gói Đối chứng Mã hóa An toàn
- **Nội dung (Size 26):**
  - Bắt gói trên card WAN ens33 trong lúc tải tệp 1 MiB: **120 gói tin ESP/OpenVPN**, 0 gói bản rõ.
  - Toàn bộ Header gốc và Payload HTTP đều nằm sâu trong khối mã hóa chuẩn.
  - Kẻ tấn công nghe lén trên mạng WAN hoàn toàn bất lực trong việc giải mã dữ liệu.

#### SLIDE 26: BƯỚC 4 — KIỂM CHỨNG TOÀN VẸN VÀ THU HỒI CHỨNG CHỈ (TC-09, TC-10)
- **Tiêu đề (Size 32):** Bước 4: Kiểm chứng Tính Toàn vẹn và Thu hồi CRL
- **Nội dung (Size 26):**
  - Tải tệp 1 MiB đối chứng mã băm SHA-256 (`63f19950...`) trùng khớp 100%, bảo toàn dữ liệu.
  - Thực thi lệnh thu hồi `pki-revoke-client.sh client1`: Cập nhật CRL ngay lập tức.
  - Client bị từ chối bắt tay ngay tại cổng: Log ghi nhận `VERIFY ERROR: CRL has expired/revoked`.

---

### PHẦN 4: KẾT LUẬN & BÀI HỌC KINH NGHIỆM CHO DOANH NGHIỆP (SLIDE 27 – 30)

#### SLIDE 27: SO SÁNH CHUYÊN SÂU OPENVPN VÀ IPSEC STRONGSWAN
- **Tiêu đề (Size 32):** So sánh Chuyên sâu OpenVPN và IPsec strongSwan
- **Nội dung (Size 26):**
  - **OpenVPN:** Dễ cấu hình, vượt tường lửa xuất sắc (UDP/TCP), thích hợp Remote Access đa nền tảng.
  - **IPsec strongSwan:** Xử lý tại tầng Kernel Linux, độ trễ cực thấp, thông lượng vượt trội cho Site-to-Site.
  - Giải pháp tối ưu: Kết hợp linh hoạt cả hai công nghệ theo từng mục đích sử dụng.

#### SLIDE 28: ĐÁNH GIÁ TÍNH KHẢ THI VÀ CHI PHÍ ĐẦU TƯ
- **Tiêu đề (Size 32):** Đánh giá Tính Khả thi và Chi phí Doanh nghiệp
- **Nội dung (Size 26):**
  - Chi phí bản quyền: 0 VNĐ (Hoàn toàn dựa trên các công nghệ mã nguồn mở hàng đầu).
  - Tận dụng hạ tầng máy chủ hiện có, không đòi hỏi phần cứng Router/Firewall chuyên dụng đắt đỏ.
  - Dễ dàng triển khai nhân rộng cho hàng trăm chi nhánh và nhân viên làm việc từ xa.

#### SLIDE 29: BÀI HỌC KINH NGHIỆM VẬN HÀNH AN TOÀN MẠNG
- **Tiêu đề (Size 32):** Bài học Kinh nghiệm Vận hành An toàn Mạng
- **Nội dung (Size 26):**
  - Quản trị PKI là trọng tâm: Khóa bí mật của Root CA phải được lưu trữ ngoại tuyến (Offline CA).
  - Luôn áp dụng cơ chế tự động hóa kiểm tra CRL hoặc OCSP để ngăn ngừa lạm dụng danh tính.
  - Bắt buộc cấu hình TCP MSS Clamping và quy tắc tường lửa Blackhole để ngăn chặn rò rỉ dữ liệu.

#### SLIDE 30: HƯỚNG PHÁT TRIỂN & KẾT LUẬN
- **Tiêu đề (Size 32):** Hướng Phát triển Mở rộng và Lời Cảm ơn
- **Nội dung (Size 26):**
  - Tích hợp xác thực đa yếu tố (MFA / TOTP) và tiến tới kiến trúc Zero Trust Network Access (ZTNA).
  - Triển khai cụm Gateway chịu lỗi sẵn sàng cao (High Availability / Failover VRRP).
  - Nhóm xin chân thành cảm ơn Quý Thầy Cô đã theo dõi! Kính mời Thầy Cô đặt câu hỏi!
