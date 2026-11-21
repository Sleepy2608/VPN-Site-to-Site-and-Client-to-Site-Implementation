# Checklist nghiệm thu Chủ đề 14 — OpenVPN C2S và S2S

Phương án chính: 4 Armbian Linux (BR-PC hiện dùng CLI) + Windows Remote-PC, ba LAN Segment VMware. Xem [README](../README.md), [runbook](../docs/presentation/detailed-lab-runbook.md) và [kết quả theo từng dải LAN](../docs/deployment/live-lab-status.md). Bảng dùng dải mới `10.74.10.0/24` và `10.74.20.0/24`. Kết quả trên dải cũ được ghi rõ để đối chiếu log và PCAP.

## Chuẩn bị và kiểm thử dương

| Mã | Thao tác | Kỳ vọng | Kết quả/bằng chứng |
| --- | --- | --- | --- |
| OVPN-01 | Windows GUI Connect, xem ipconfig/route và View Log | IP 10.8.0.x, route HQ qua VPN, handshake hoàn tất | HQ-GW thấy `client1` kết nối và gửi route mới. Chưa kiểm tra `ipconfig` hoặc bảng route trên Windows |
| OVPN-02 | Windows ping HQ-Server, HTTP và tải file 1 MiB | Ping có phản hồi, HTTP 200, đúng dung lượng/hash | Chưa chạy |
| OVPN-03 | Status C2S/S2S trên HQ sau khi kết nối và chờ 5s | client1 và branch-gw ở đúng server; status mới, log cipher AES-256-GCM | Sau đổi dải, HQ-GW thấy cả hai phiên và log C2S ghi AES-256-GCM |
| OVPN-04 | Branch-PC ping/mở Portal; HQ-Server chủ động ping Branch-PC | Hai chiều LAN-to-LAN; host LAN không chạy VPN client; Nginx thấy nguồn Branch 10.74.20.50 | Đạt trên dải mới, gồm ping hai chiều, HTTP 200, IP nguồn và SHA-256 |
| OVPN-05 | Cùng lần tải file capture WAN và LAN/TUN | WAN có UDP1194/1195; LAN/TUN có HTTP tương ứng; có gói thật và log cipher | Có capture đối chứng trên dải cũ |
| OVPN-06 | Reboot hai gateway và HQ-Server; Windows Connect lại | Đúng mode OpenVPN tự chạy; forwarding/firewall/Portal phục hồi, kiểm tra lại OVPN-01..05 | Có kết quả đầy đủ bốn Linux trên dải cũ. Lần đổi dải có reboot ba VM dùng networkd |
| OVPN-07 | Disconnect Windows, thử HTTP mới rồi Connect lại | Khi ngắt không vào HQ; kết nối lại hoạt động; S2S vẫn hoạt động | Chưa chạy |

```bash
# HQ-GW, kết nối Windows và Branch trước, chờ một chu kỳ status 5s:
sudo bash scripts/verify-c2s.sh server
sudo bash scripts/verify-s2s.sh hq-gw
# Branch-GW:
sudo bash scripts/verify-s2s.sh branch-gw
# Branch-PC:
bash scripts/verify-s2s.sh branch-pc
bash scripts/verify-portal.sh
# HQ-Server (khởi tạo chiều ngược):
bash scripts/verify-s2s.sh hq-server
```

Trên Windows PowerShell, tại checkout:

```powershell
powershell -NoProfile -File scripts/verify-c2s-windows.ps1 -ExpectedState Connected
# Disconnect trong GUI, rồi:
powershell -NoProfile -File scripts/verify-c2s-windows.ps1 -ExpectedState Disconnected
```

Nếu chính sách thực thi chặn PS1, dùng ipconfig, route print và curl.exe thủ công theo runbook. Lưu log/ảnh thực tế; không chạy Bash/systemctl trên Windows.

## Kiểm thử âm bắt buộc để đánh giá bảo vệ tài nguyên

| Mã | Thao tác | Kỳ vọng | Kết quả/bằng chứng |
| --- | --- | --- | --- |
| SEC-01 | Windows tắt VPN và tự thêm route tới HQ LAN qua WAN HQ-GW | HTTP vẫn thất bại; counter DROP tăng ở HQ-GW | Đạt trên dải cũ bằng client Linux WAN tạm |
| SEC-02 | Dừng Branch S2S, thêm route WAN dự phòng rồi phát ping/HTTP từ Branch-PC | Không kết nối và không có gói LAN bản rõ đi ra WAN; counter DROP tăng | Đạt trên dải cũ, DROP tăng 5 gói và 0 gói LAN bản rõ đi WAN |
| SEC-03 | Thu hồi client thử nghiệm trên CA đang dùng; thử handshake mới | Server ghi certificate revoked; không truy cập được HQ | Chưa chạy |
| SEC-04 | Thử profile C2S vào cổng S2S, hoặc profile sai CA/tls-crypt | Không thiết lập phiên S2S; không xuất hiện client sai vai trò trong status | Chưa chạy |
| SEC-05 | Ngắt một loại VPN trong khi loại còn lại đang dùng | C2S/S2S hoạt động độc lập, không vô tình dùng đường còn lại để báo đạt | Chưa chạy |

### SEC-01: thử route trực tiếp khi Windows không có VPN

Trước hết xác nhận OVPN-02 chạy đạt, rồi Disconnect và ngắt NIC NAT tạm. Trong **PowerShell Administrator** trên Windows, chỉ thêm route tạm chưa có sẵn:

```powershell
$wanIndex = (Get-NetIPAddress -AddressFamily IPv4 -IPAddress 172.16.1.100).InterfaceIndex
route ADD 10.74.10.0 MASK 255.255.255.0 172.16.1.10 IF $wanIndex
curl.exe --noproxy '*' --connect-timeout 2 --max-time 4 http://10.74.10.50/
# Kỳ vọng lỗi kết nối/timeout. Dọn đúng route vừa thêm sau phép thử:
route DELETE 10.74.10.0 MASK 255.255.255.0 172.16.1.10 IF $wanIndex
```

Trên HQ-GW xem `sudo iptables -nvL VPN_LAB_FORWARD`; counter DROP phải tăng trong thời gian phát request. Ping WAN được nhưng HTTP HQ thất bại mới cho thấy có đường WAN mà bị policy chặn; thiếu route sẵn có không phải bằng chứng firewall.

### SEC-02: ép đường WAN dự phòng khi S2S ngắt

Xác nhận S2S đang đạt trước. Trên Branch-GW:

```bash
sudo systemctl stop openvpn-client@client-s2s
source scripts/common/lab-network.sh
ip route show 10.74.10.0/24
# Chỉ thêm nếu route này đã được gỡ sau khi dừng client:
sudo ip route add 10.74.10.0/24 via 172.16.1.10 dev "$WAN_IF"
# Terminal 1, có giới hạn thời gian; ghi lại bộ đếm khi capture kết thúc:
sudo timeout --signal=INT 20 tcpdump -ni "$WAN_IF" -Q out -w /tmp/s2s-off-wan.pcap 'net 10.74.10.0/24 or net 10.74.20.0/24'
```

Trong 20 giây bắt gói, tại Branch-PC chạy `ping -c 5 -W 1 10.74.10.50` và `curl --noproxy '*' --connect-timeout 2 --max-time 4 http://10.74.10.50/`. Cả hai phải thất bại. Dùng terminal thứ hai trên Branch-GW kiểm tra counter DROP trước/sau tại `sudo iptables -nvL VPN_LAB_FORWARD`; đọc PCAP bằng `sudo tcpdump -nn -r /tmp/s2s-off-wan.pcap`. Capture phải hợp lệ, đúng NIC và có traffic thử đã phát; không chỉ dựa vào 0 packet.

Dọn đúng route thử rồi phục hồi tunnel:

```bash
sudo ip route del 10.74.10.0/24 via 172.16.1.10 dev "$WAN_IF"
sudo systemctl start openvpn-client@client-s2s
sudo bash scripts/verify-s2s.sh branch-gw
```

### SEC-03/04: CRL và chứng chỉ sai vai trò

Thực hiện sau các phép thử dương, trong snapshot lab riêng. Dùng `sudo bash scripts/pki/revoke-client.sh client1 --disconnect` trên HQ-GW để chặn handshake mới và restart server C2S/ngắt các phiên C2S đang chạy. Kiểm tra Windows kết nối lại thất bại và journal có lỗi thu hồi. Không tạo lại CA để khôi phục; khôi phục snapshot lab đã lưu hoặc cấp CN mới, tạo CCD allowlist tương ứng và profile mới theo quy trình quản trị PKI. Không thu hồi client đang cần trình diễn trước khi có phương án phục hồi.

Để thử sai vai trò, chép profile `client1.ovpn` sang một tên thử nghiệm trên Windows, đổi remote port sang 1195 và pin tên server thành `hq-s2s-gw` để yêu cầu đi tới đúng dịch vụ S2S. Khi `client1` còn hợp lệ, kết nối vẫn phải bị server S2S từ chối vì chỉ nhận CN `branch-gw`. Nếu không đổi pin tên, phía client có thể từ chối sớm do sai server CN; kết quả đó chưa chứng minh allowlist S2S. Khôi phục profile gốc sau phép thử.

## Bằng chứng cần lưu

Ghi ngày chạy, host/guest OS, VMware, CPU/RAM VM, phiên bản OpenVPN, NIC/renderer/IP/route, CN, trạng thái DCO, log handshake/cipher, kết quả lệnh, counter firewall, ảnh và PCAP. Không đưa khóa riêng/profile thật vào Git. Mỗi phép đo chỉ chứng minh phạm vi nó quan sát; Portal hiển thị IP Nginx thấy, không tự xác nhận mã hóa. Đo hiệu năng theo [hướng dẫn đánh giá](../docs/technical-guides/07-testing-and-security-eval.md), không chép số liệu cũ thành kết quả mới.
