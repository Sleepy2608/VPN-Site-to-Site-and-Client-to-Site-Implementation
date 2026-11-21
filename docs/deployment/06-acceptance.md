# Nghiệm thu hệ thống năm máy

Thực hiện sau khi [năm hướng dẫn triển khai](README.md) đã hoàn tất. Phải kiểm tra từ Windows và hai host LAN để phân biệt C2S với S2S; trạng thái gateway riêng lẻ chưa đủ.

## 1 Ngắt NIC NAT tạm

Trong VMware, bỏ chọn **Connected** và **Connect at power on** trên NIC NAT tạm của cả năm VM. Giữ NIC nối ba LAN Segment và không xóa/đổi thứ tự NIC để tránh thay đổi tên card. Các lệnh kiểm tra bên dưới không cần Internet; không chạy lại `deploy-all.sh` khi NAT đã ngắt vì script vẫn gọi apt.

Trên bốn Linux xem `ip -br address` và `ip route`. Kiểm tra route tới site bên kia ở host LAN vẫn dùng gateway lab; trên Windows, card WAN giữ `172.16.1.100` và profile vẫn kết nối được tới `.10`.

## 2 Kiểm tra các thành phần đúng máy

| Máy | Lệnh kiểm tra | Kỳ vọng |
| --- | --- | --- |
| HQ-GW | systemctl is-active openvpn-server@server-c2s openvpn-server@server-s2s | Hai service active |
| HQ-GW | ip -br address show tun0; ip -br address show tun1 | 10.8.0.1 và 10.9.0.1 |
| Branch-GW | systemctl is-active openvpn-client@client-s2s | Active và log handshake hoàn tất |
| Branch-GW | ip route get 10.74.10.50 | dev tun0 |
| HQ-Server | systemctl is-active nginx | Active; HTTP cục bộ 200 |
| Branch-PC | ip route get 10.74.10.50 | via 10.74.20.1, src 10.74.20.50 |
| Windows | ipconfig, route print -4 sau Connect | IP 10.8.0.x và route HQ qua VPN |

## 3 Kiểm tra luồng thực tế

Mở Windows GUI Connect, đợi handshake; Branch S2S cũng phải đang kết nối. Chờ ít nhất khoảng 5 giây trước khi đọc status.

**HQ-GW:**

```bash
cd ~/vpn-lab
sudo bash scripts/verify-c2s.sh server
sudo bash scripts/verify-s2s.sh hq-gw
```

**Branch-GW:**

```bash
cd ~/vpn-lab
sudo bash scripts/verify-s2s.sh branch-gw
```

**Branch-PC:**

```bash
cd ~/vpn-lab
bash scripts/verify-s2s.sh branch-pc
bash scripts/verify-portal.sh
```

**HQ-Server:**

```bash
cd ~/vpn-lab
bash scripts/verify-s2s.sh hq-server
```

**Windows Remote-PC trong PowerShell:**

```powershell
ping -n 3 10.74.10.50
curl.exe --noproxy '*' --fail --connect-timeout 3 --max-time 6 http://10.74.10.50/api/identity
Start-Process 'http://10.74.10.50'
```

Cần có hai chiều khởi tạo giữa host LAN, HTTP từ Branch-PC và Windows. Sau đó ngắt Windows: HTTP mới từ Windows phải lỗi, trong khi Branch-PC vẫn dùng Portal được. Kết nối lại Windows trước khi làm phần capture C2S.

## 4 Bắt gói đối chứng

Ví dụ bắt lưu lượng **S2S** trên HQ-GW. Mở hai terminal tại `~/vpn-lab`, chạy trong mỗi terminal một lệnh tương ứng.

Terminal WAN:

```bash
cd ~/vpn-lab
source scripts/common/lab-network.sh
sudo bash scripts/capture-traffic.sh -i "$WAN_IF" -m openvpn-s2s -c 0 -d 20 -o five-vm-s2s-wan.pcap
```

Terminal LAN:

```bash
cd ~/vpn-lab
source scripts/common/lab-network.sh
sudo bash scripts/capture-traffic.sh -i "$LAN_IF" -m lan-http -c 0 -d 20 -o five-vm-s2s-lan.pcap
```

Đợi cả hai báo listening, rồi trong 20 giây đó, chạy tại **Branch-PC**:

```bash
curl --noproxy '*' --fail --connect-timeout 3 --max-time 10 -o /tmp/vpn-benchmark.dat http://10.74.10.50/files/benchmark-payload-1mb.dat
```

Đọc tại HQ-GW:

```bash
sudo tcpdump -nn -r tests/captures/samples/five-vm-s2s-wan.pcap -c 10
sudo tcpdump -nn -A -r tests/captures/samples/five-vm-s2s-lan.pcap -c 20
sudo journalctl -u openvpn-server@server-s2s -n 80 --no-pager
```

WAN phải có UDP1195 giữa hai IP WAN; LAN thấy traffic/HTTP tương ứng và nguồn Branch. Đối chiếu cipher được thương lượng trong log hai đầu. HTTP trong LAN sau giải mã vẫn bản rõ; không kết luận có mã hóa ứng dụng end-to-end.

Đối với C2S, đổi mode WAN thành `openvpn-c2s`, dùng tên PCAP khác rồi tải payload từ Windows khi đang Connect. Nếu lọc `http` trong Wireshark không tự giải mã, xem `tcp.port == 80` hoặc Decode As. 0 packet có thể do sai điểm bắt/filter hoặc chưa phát traffic, không tự chứng minh an toàn.

## 5 Kiểm thử từ chối truy cập và mất tunnel

Làm các bước có chuẩn bị/khôi phục tại [checklist kiểm thử âm](../../tests/openvpn-demo.md), gồm:

1. Windows Disconnect rồi tự thêm route HQ LAN qua `172.16.1.10`: HTTP vẫn phải bị chặn, counter DROP tăng.
2. Dừng S2S trên Branch, thêm route WAN dự phòng có chủ đích, phát ping/HTTP từ Branch-PC: không vào HQ và không có lưu lượng LAN bản rõ đi WAN; dọn route thử rồi bật lại client.
3. Dùng snapshot riêng để thử CRL và cert sai vai trò. Thu hồi `client1` sẽ ảnh hưởng demo Windows; thực hiện sau bài chính và có phương án phục hồi.

Không chỉ dựa vào việc client thiếu route để kết luận firewall bảo vệ LAN. Theo dõi counter trên gateway đúng đường đi khi phát traffic thử.

## 6 Kiểm tra sau reboot

Lưu snapshot trước, sau đó reboot từng Linux từ console để còn khoanh vùng lỗi. Windows tạm Disconnect trong lúc các gateway khởi động lại.

```bash
# Chạy trên đúng Linux cần khởi động lại:
sudo reboot
```

Sau reboot HQ-GW/Branch-GW, kiểm tra service đúng instance, tun/route, `sysctl net.ipv4.ip_forward` và rules firewall. Trên HQ-Server kiểm tra Nginx và IP LAN. Windows chủ động Connect lại, rồi chạy lại phần kiểm tra luồng thực tế ở trên. Linux host LAN vẫn không cần chạy VPN client.

Nếu dịch vụ chỉ hoạt động sau restart thủ công, xử lý nguyên nhân boot/network rồi thử reboot lại; chưa đánh dấu bài reboot đạt. Không tạo lại CA để chữa lỗi reconnect.

## 7 Hồ sơ kết quả

| Nhóm bằng chứng | Nội dung cần lưu |
| --- | --- |
| Hạ tầng | Tên/phiên bản image, VMware, CPU/RAM VM, MAC/NIC và ba LAN Segment |
| Mạng | IP/route từng máy khi NAT đã ngắt |
| VPN | CN đúng hai vai trò, log handshake/cipher, status mới |
| Ứng dụng | HTTP từ Windows/Branch, ping hai chiều host LAN, dung lượng/hash file |
| An ninh | Counter DROP, kết quả route trực tiếp/tunnel ngắt, PCAP có traffic đối chứng |
| Vận hành | Các kiểm tra lặp lại sau reboot |

Ghi kết quả và đường dẫn bằng chứng vào [checklist nghiệm thu](../../tests/openvpn-demo.md). Chỉ đánh dấu mục đã thử thực tế, không đưa profile/khóa riêng vào Git hoặc ảnh. Sau nghiệm thu, dùng [kịch bản demo](../presentation/demo-script.md) để trình bày ngắn gọn cả C2S và S2S.
