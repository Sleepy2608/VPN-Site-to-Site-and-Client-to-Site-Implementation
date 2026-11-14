# THƯ MỤC LƯU TRỮ TỆP BẮT GÓI TIN MẪU (SAMPLE PACKET CAPTURES)

Thư mục này dùng để lưu trữ các tệp bắt gói tin định dạng `.pcap` / `.pcapng` phục vụ phân tích cấu trúc giao thức mật mã và đối chứng dữ liệu trên Wireshark theo kế hoạch tại [PLAN.md](file:///c:/University%20Coding%20Project/VPN-Site-to-Site-and-Client-to-Site-Implementation/.plan/PLAN.md) và [wireshark-analysis.md](file:///c:/University%20Coding%20Project/VPN-Site-to-Site-and-Client-to-Site-Implementation/tests/captures/wireshark-analysis.md).

---

## 1. DANH MỤC CÁC TỆP BẮT GÓI TIN TIÊU CHUẨN

| Tên Tệp Tin | Card Bắt | Giao Thức Chính | Mục Đích Minh Chứng |
| :--- | :---: | :---: | :--- |
| `openvpn-handshake.pcap` | `eth0` (WAN) | UDP 1194 / TLS 1.3 | Quá trình bắt tay 3 bước của OpenVPN, đàm phán TLS, trao đổi chứng chỉ số X.509 và khởi tạo kênh Data Channel. |
| `openvpn-data-transfer.pcap` | `eth0` (WAN) | OpenVPN P_DATA_V2 | Dữ liệu truyền tải file và HTTP giữa máy khách/chi nhánh đã bị mã hóa 100% bằng thuật toán AES-256-GCM. |
| `ipsec-esp-traffic.pcap` | `eth0` (WAN) | ESP (Proto 50) / IKE | Bắt tay IKE_SA_INIT, IKE_AUTH đàm phán Child SA và luồng dữ liệu đóng gói ESP Tunnel mang trường SPI và Sequence Number. |
| `lan-decrypted-traffic.pcap` | `eth1` (LAN) | HTTP / ICMP | Dữ liệu bản rõ đối chứng sau khi được HQ Gateway giải mã và chuyển tiếp tới máy chủ nội bộ `192.168.10.50`. |
| `anti-leakage-verification.pcap`| `eth0` (WAN) | IP / ICMP | Bằng chứng 0 gói tin (Empty capture) khi đường hầm bị ngắt, chứng minh tính năng chống rò rỉ (Killswitch). |

---

## 2. HƯỚNG DẪN THU THẬP TỆP PCAP BẰNG SCRIPT TỰ ĐỘNG

Trên máy ảo Gateway (`VM-HQ-GW`), bạn có thể sử dụng kịch bản [capture-traffic.sh](file:///c:/University%20Coding%20Project/VPN-Site-to-Site-and-Client-to-Site-Implementation/scripts/capture-traffic.sh) để tự động thu thập các tệp tin trên:

```bash
# 1. Bắt gói tin OpenVPN bắt tay & truyền dữ liệu:
sudo ./scripts/capture-traffic.sh -i eth0 -m openvpn-c2s -c 100 -o openvpn-handshake.pcap

# 2. Bắt gói tin strongSwan IPsec (IKEv2 & ESP):
sudo ./scripts/capture-traffic.sh -i eth0 -m ipsec -c 100 -o ipsec-esp-traffic.pcap

# 3. Bắt gói tin đối chứng trên card LAN:
sudo ./scripts/capture-traffic.sh -i eth1 -m lan-http -c 50 -o lan-decrypted-traffic.pcap

# 4. Kiểm thử chống rò rỉ dữ liệu khi tắt VPN:
sudo ./scripts/capture-traffic.sh -i eth0 -m leak-check -c 20 -o anti-leakage-verification.pcap
```

---

## 3. CÁCH XUẤT VÀ MỞ TỆP BẰNG WIRESHARK

1. **Sao chép tệp từ máy ảo về máy tính thật (Host):**
   - Sử dụng phần mềm WinSCP, FileZilla hoặc lệnh `scp`:
     ```powershell
     scp student@172.16.1.10:/c/University\ Coding\ Project/.../tests/captures/samples/*.pcap .
     ```
   - Hoặc copy thông qua thư mục chia sẻ (Shared Folder) của VirtualBox/VMware.
2. **Mở bằng Wireshark:**
   - Khởi động Wireshark -> Chọn menu **File** -> **Open...** -> Chọn tệp `.pcap`.
   - Áp dụng các bộ lọc hiển thị (Display Filters) đã được hướng dẫn chi tiết tại tài liệu [wireshark-analysis.md](file:///c:/University%20Coding%20Project/VPN-Site-to-Site-and-Client-to-Site-Implementation/tests/captures/wireshark-analysis.md).
