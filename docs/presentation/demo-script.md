# Demo OpenVPN với Windows Remote-PC trong 6–8 phút

> Kịch bản 5 máy để trình bày đủ Client-to-Site và Site-to-Site của Chủ đề 14. [Bài 3 máy](three-vm-openvpn-demo.md) chỉ trình bày C2S; xem [đối chiếu yêu cầu](../topic14-audit.md).

Nếu bắt đầu từ VM mới, làm theo [kịch bản chi tiết theo từng máy](detailed-lab-runbook.md) trước. Tài liệu dưới là bản trình diễn rút gọn sau khi triển khai và nghiệm thu xong.

Lab VMware đã triển khai đang dùng IPsec cho S2S. Trước khi chạy kịch bản OpenVPN S2S dưới đây, chuyển cả HQ-GW và Branch-GW sang mode `openvpn` theo [hướng dẫn chuyển mode](../technical-guides/06-ipsec-strongswan-guide.md#triển-khai-và-chuyển-mode-trên-cả-hai-gateway).

Demo trên **VMware** dùng **3 Armbian không GUI + 1 Armbian GUI (Branch-PC) + 1 Windows Remote-PC**, chỉ dùng **OpenVPN cho C2S và S2S**. Hoàn tất [triển khai](../../README.md) và [chuẩn bị Armbian/VMware](../technical-guides/09-armbian-vmware-guide.md) trước buổi trình diễn. Windows dùng OpenVPN GUI; xem [yêu cầu Windows](../technical-guides/08-windows-client-requirements.md).

## Chuẩn bị trước giờ demo

- Bật HQ-GW, Branch-GW, HQ-Server chạy Armbian không GUI; Branch-PC chạy Armbian GUI; Remote-PC chạy Windows.
- Tắt adapter NAT tạm; Remote-PC chỉ nối vào WAN-Net của lab.
- HQ chạy `openvpn-server@server-c2s` và `openvpn-server@server-s2s`; Branch chạy `openvpn-client@client-s2s`.
- Remote-PC đã cài OpenVPN Community x64 và import `client1.ovpn` vào OpenVPN GUI; profile đang Disconnect.
- Mở console/SSH của HQ-GW, terminal và browser trên Armbian GUI Branch-PC; PowerShell, OpenVPN GUI và browser/Wireshark trên Windows.
- Bash chạy trên đúng Armbian node từ thư mục repo; PowerShell chạy trên Windows. Chạy `sudo -v` trên các terminal Armbian cần sudo trước demo; kiểm tra file NIC `/etc/vpn-lab/interfaces.conf` trên hai gateway.
- Trên HQ-GW kiểm tra trước:

```bash
sudo systemctl is-active openvpn-server@server-c2s openvpn-server@server-s2s
sudo bash scripts/verify-s2s.sh hq-gw
```

Trên Windows Remote-PC trước khi bắt đầu: chọn `client1` → **Disconnect**, rồi kiểm tra:

```powershell
ping -n 2 172.16.1.10
Invoke-WebRequest -UseBasicParsing -Method Head -Uri http://10.74.10.50 -TimeoutSec 3
```

Ping WAN phải được; lệnh HTTP tới HQ dự kiến báo timeout/lỗi khi C2S tắt trong mô hình cô lập. Nếu HTTP đã thành công thì kiểm tra lại adapter, route và proxy trước demo. Kết quả này không thay thế kiểm thử chính sách firewall.

## Phần 1 — Nhân viên từ xa truy cập HQ (2 phút)

Lời dẫn: “Máy Windows của nhân viên đang ở WAN giả lập. Khi bật OpenVPN, client được cấp địa chỉ tunnel và route vào mạng HQ.”

Trên **Windows Remote-PC**, nhấp OpenVPN GUI ở system tray → `client1` → **Connect**. Chờ Connected và log `Initialization Sequence Completed`; mở **View Log** để xem cipher/kết nối.

Trong **PowerShell Windows**:

```powershell
ipconfig
route print -4
ping -n 3 10.74.10.50
Test-NetConnection 10.74.10.50 -Port 80
Invoke-WebRequest -UseBasicParsing -Method Head -Uri http://10.74.10.50 -TimeoutSec 5
Start-Process http://10.74.10.50
```

Chỉ ra IP tunnel `10.8.0.x`, route HQ `10.74.10.0/24` qua adapter OpenVPN, ping có phản hồi và HTTP 200. Tải một tài liệu trong trình duyệt. Tên adapter tùy driver, không bắt buộc TAP/Wintun; dùng driver đi kèm bộ cài hiện hành.

C2S đang NAT ra LAN HQ: Portal có thể thấy `10.74.10.1`. IP VPN thực tế xem bằng `ipconfig` trên Windows; IP trên Portal không xác nhận cipher hoặc trạng thái VPN. Có thể dùng `quick-setup.bat` làm menu hỗ trợ.

## Phần 2 — Chi nhánh truy cập HQ (2 phút)

Lời dẫn: “Máy Branch-PC không cài VPN client. Hai gateway OpenVPN định tuyến giữa hai LAN.”

Trên Branch-PC:

```bash
ping -c 3 -W 2 10.74.10.50
curl --noproxy '*' --connect-timeout 3 --max-time 10 -I http://10.74.10.50
traceroute -n -w 1 -m 5 10.74.10.50
xdg-open http://10.74.10.50
```

Browser trên **Armbian GUI Branch-PC** mở cùng Portal để chứng minh truy cập ứng dụng qua S2S; máy này không cài VPN client. Nếu chưa có browser mặc định, chuẩn bị browser của đúng image từ trước hoặc mở URL thủ công trong browser đã cài.

Trên HQ-GW:

```bash
ip -br addr show tun1
sudo cat /var/log/openvpn/openvpn-s2s-status.log
```

Chỉ ra tunnel HQ `10.9.0.1`, Branch `10.9.0.2`, client `branch-gw` và HTTP 200. Ghi số liệu ping thực tế; không đặt sẵn RTT. Traceroute minh họa đường đi, không thay thế phép kiểm tra mã hóa.

## Phần 3 — Quan sát dữ liệu trên WAN và LAN (2–3 phút)

Mở hai terminal **trên HQ-GW**, chạy hai capture ở hai interface khác nhau:

```bash
# Terminal 1 — WAN: helper đọc tên NIC đã khai báo cho VMware:
source scripts/common/lab-network.sh
sudo bash scripts/capture-traffic.sh -i "$WAN_IF" -m openvpn-s2s -c 20 -o demo-openvpn-wan.pcap

# Terminal 2 — LAN:
source scripts/common/lab-network.sh
sudo bash scripts/capture-traffic.sh -i "$LAN_IF" -m lan-http -c 20 -o demo-http-lan.pcap
```

Sau khi tcpdump báo đang lắng nghe, từ Branch-PC tạo lưu lượng:

```bash
curl --noproxy '*' --connect-timeout 3 --max-time 20 -o /dev/null http://10.74.10.50/files/benchmark-payload-1mb.dat
```

Nếu chưa đủ 20 gói thì tải lại file hoặc nhấn Ctrl+C để kết thúc capture. Chép pcap từ `tests/captures/samples/` trên HQ-GW về Windows qua Shared Folder/WinSCP; Wireshark cần cài trước khi tắt NAT. Chỉ mở pcap thì không cần bắt gói trực tiếp trên Windows.

Trên Windows mở Wireshark → **File → Open** → chọn `demo-openvpn-wan.pcap`, sau đó mở riêng `demo-http-lan.pcap` để đối chứng.

- Mở pcap WAN, lọc `udp.port == 1195`: đối chiếu datagram OpenVPN, không thấy HTTP bản rõ của lần tải.
- Mở pcap LAN, lọc `http`: thấy request/response HTTP sau khi gateway giải mã.
- Kiểm tra cipher thực tế trong journal OpenVPN; HTTP trên LAN sau gateway vẫn là bản rõ.

```bash
sudo journalctl -u openvpn-server@server-s2s -n 50 --no-pager
```

Lời kết: “Cùng dùng OpenVPN, C2S bảo vệ kết nối nhân viên từ xa; S2S nối hai LAN qua gateway. Dữ liệu ứng dụng được mã hóa trên đoạn WAN giữa các đầu VPN.”

## Ngắt và chuẩn bị lần demo tiếp theo (30 giây)

Trên Windows chọn OpenVPN GUI → `client1` → **Disconnect**. Trong PowerShell:

```powershell
route print -4
Invoke-WebRequest -UseBasicParsing -Method Head -Uri http://10.74.10.50 -TimeoutSec 3
```

Route HQ do OpenVPN đẩy vào phải bị gỡ; trong mô hình cô lập chuẩn, HTTP không truy cập được HQ khi C2S tắt. OpenVPN S2S giữa hai gateway vẫn chạy độc lập. Dùng **Connect** lại để demo lần nữa.

## Bằng chứng và phần mở rộng

Ghi kết quả/đường dẫn ảnh và pcap vào [checklist](../../tests/openvpn-demo.md). Chỉ đánh dấu đạt sau khi chạy thực tế.

Thu hồi chứng chỉ CRL là bài mở rộng nếu còn thời gian, thực hiện sau cùng theo [hướng dẫn PKI](../technical-guides/03-pki-ca-setup.md). Demo chính không cần thu hồi chứng chỉ, chuyển chế độ VPN hay so sánh benchmark.
