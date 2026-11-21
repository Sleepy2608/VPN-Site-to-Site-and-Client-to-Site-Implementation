# THƯ MỤC LƯU TRỮ TỆP BẮT GÓI TIN MẪU (SAMPLE PACKET CAPTURES)

Thư mục này dùng để lưu trữ các tệp bắt gói tin định dạng `.pcap` / `.pcapng` phục vụ phân tích cấu trúc giao thức mật mã và đối chứng dữ liệu trên Wireshark theo [checklist nghiệm thu](../../openvpn-demo.md) và [wireshark-analysis.md](../wireshark-analysis.md).

---

PCAP thực nghiệm IPsec ngày 21/11/2026 được bắt cùng lúc trên HQ-GW khi Branch-PC tải file mẫu. WAN hướng ra có ESP, LAN thấy HTTP GET. [WAN](ipsec-s2s-wan-2026-11-21.pcap) · [LAN](ipsec-s2s-lan-2026-11-21.pcap)

Các tên trong bảng dưới đây là mẫu đặt tên khi thu capture mới. Thay eth0/eth1 bằng NIC thật. Dùng `sudo bash scripts/capture-traffic.sh` nếu tệp chưa có quyền execute.

## 1. DANH MỤC CÁC TỆP BẮT GÓI TIN TIÊU CHUẨN

| Tên Tệp Tin | Card Bắt | Giao Thức Chính | Mục Đích Minh Chứng |
| :--- | :---: | :---: | :--- |
| `openvpn-handshake.pcap` | `eth0` (WAN) | UDP 1194 / kênh điều khiển | Quan sát gói điều khiển; tls-crypt che nội dung TLS/chứng chỉ, đối chiếu log thay vì kỳ vọng đọc được toàn bộ handshake từ PCAP. |
| `openvpn-data-transfer.pcap` | `eth0` (WAN) | OpenVPN P_DATA_V2 | Đối chứng gói OpenVPN với cùng lần tải file ở LAN và cipher AES-256-GCM trong log. |
| `ipsec-esp-traffic.pcap` | `eth0` (WAN) | ESP (Proto 50) / IKE | Bắt tay IKE_SA_INIT, IKE_AUTH đàm phán Child SA và luồng dữ liệu đóng gói ESP Tunnel mang trường SPI và Sequence Number. |
| `lan-decrypted-traffic.pcap` | `eth1` (LAN) | HTTP / ICMP | Dữ liệu bản rõ đối chứng sau khi được HQ Gateway giải mã và chuyển tiếp tới máy chủ nội bộ `10.74.10.50`. |
| `anti-leakage-verification.pcap`| `eth0` (WAN) | IP / ICMP | Quan sát khi tunnel ngắt; 0 packet chỉ có ý nghĩa khi capture hợp lệ, có traffic thử và counter DROP đối chứng. |

---

## 2. HƯỚNG DẪN THU THẬP TỆP PCAP BẰNG SCRIPT TỰ ĐỘNG

Trên máy ảo Gateway (`VM-HQ-GW`), bạn có thể sử dụng kịch bản [capture-traffic.sh](../../../scripts/capture-traffic.sh) để tự động thu thập các tệp tin trên:

```bash
# 1. Bắt gói tin OpenVPN bắt tay & truyền dữ liệu:
sudo bash scripts/capture-traffic.sh -i eth0 -m openvpn-c2s -c 100 -o openvpn-handshake.pcap

# 2. Bắt gói tin strongSwan IPsec (IKEv2 & ESP):
sudo bash scripts/capture-traffic.sh -i eth0 -m ipsec -c 100 -o ipsec-esp-traffic.pcap

# 3. Bắt gói tin đối chứng trên card LAN:
sudo bash scripts/capture-traffic.sh -i eth1 -m lan-http -c 50 -o lan-decrypted-traffic.pcap

# 4. Kiểm thử chống rò rỉ dữ liệu khi tắt VPN:
sudo bash scripts/capture-traffic.sh -i eth0 -m leak-check -c 0 -d 20 -o anti-leakage-verification.pcap
```

---

## 3. CÁCH XUẤT VÀ MỞ TỆP BẰNG WIRESHARK

1. **Sao chép tệp từ máy ảo về máy tính thật (Host):**
   - Trên Windows Remote-PC dùng Shared Folder hoặc WinSCP để lấy pcap trong thư mục `tests/captures/samples/` của repo trên HQ-GW. Nếu dùng SCP cần cài OpenSSH Client và chỉ định đúng tài khoản/đường dẫn nguồn.
   - Hoặc copy thông qua thư mục chia sẻ (Shared Folder) của VirtualBox/VMware.
2. **Mở bằng Wireshark:**
   - Khởi động Wireshark -> Chọn menu **File** -> **Open...** -> Chọn tệp `.pcap`.
   - Áp dụng các bộ lọc hiển thị (Display Filters) đã được hướng dẫn chi tiết tại tài liệu [wireshark-analysis.md](../wireshark-analysis.md).
