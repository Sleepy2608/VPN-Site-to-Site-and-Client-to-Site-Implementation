# Kết quả triển khai trực tiếp trên VMware

## Triển khai IPsec ngày 21/11/2026

**Mode đang chạy** là IPsec Site-to-Site với strongSwan 6.0.4 trên HQ-GW và Branch-GW. OpenVPN Client-to-Site chạy trên HQ-GW UDP 1194. Branch-GW chủ động thiết lập IKEv2, HQ-GW nhận kết nối. PSK riêng được lưu trên hai gateway với quyền `600`.

| Phép thử qua SSH | Kết quả |
| --- | --- |
| Hai gateway | Mỗi đầu có một IKE SA `ESTABLISHED` và CHILD SA `INSTALLED, TUNNEL`, dùng ESP `AES_GCM_16_256`. Chính sách XFRM khớp hai LAN `10.74.10.0/24` và `10.74.20.0/24`. |
| HQ-Server ↔ Branch-PC | Ping khởi tạo từ mỗi LAN đều nhận 3/3 phản hồi. Branch-PC nhận HTTP 200 và API thấy nguồn `10.74.20.50`. |
| Tải file qua IPsec | Đúng 1.048.576 byte và SHA-256 trùng file gốc. Trong lần tải đối chứng, bộ đếm XFRM trên HQ-GW tăng 757 gói chiều ra và 147 gói chiều vào. |
| Wireshark | Capture WAN hướng ra HQ-GW ghi 120 gói ESP và 0 gói mang địa chỉ LAN bản rõ theo bộ lọc. Capture LAN ghi 120 gói TCP/80, có HTTP GET của file. Cả hai capture dừng ở 120 gói. [WAN](../../tests/captures/samples/ipsec-s2s-wan-2026-11-21.pcap) · [LAN](../../tests/captures/samples/ipsec-s2s-lan-2026-11-21.pcap) |
| Mất IPsec tại Branch | Khi dừng strongSwan và thử route WAN dự phòng, ping và HTTP đều thất bại, counter DROP tăng 5 gói và capture WAN hướng ra ghi 0 gói liên LAN bản rõ. Sau khi dọn route thử và khởi động lại dịch vụ, CHILD SA và HTTP phục hồi. |
| Đổi mode S2S | IPsec → OpenVPN → IPsec. Ping hai chiều và HTTP đạt sau mỗi lần đổi. Tiến trình C2S giữ cùng PID và phiên `client1` vẫn xuất hiện trong status. |
| C2S trên HQ-GW | `verify-c2s.sh server` đạt 6/6, có `client1` từ `172.16.1.100`. HTTP và GUI phía Windows do người dùng tự nghiệm thu. |

Hai gateway bật `strongswan-starter` tự khởi động và đã lưu firewall qua `netfilter-persistent`. Bản sao firewall trước khi chuyển mode ở `/root/vpn-lab-backup/ipsec-20261121/` trên mỗi gateway. Lần này có kiểm tra khởi động lại dịch vụ IPsec ở Branch. Kiểm tra reboot toàn bộ VM với mode IPsec và thử sai PSK vẫn chờ chạy.

Xem [hướng dẫn IPsec](../technical-guides/06-ipsec-strongswan-guide.md) để chọn mode tại hai gateway và [script cấu hình lại Windows](../../scripts/setup-c2s-windows.ps1) để cài profile C2S.

## Đổi subnet LAN ngày 20/11/2026

| Máy | IP LAN mới | IP SSH quản trị qua VMnet8 |
| --- | --- | --- |
| HQ-GW | `10.74.10.1/24` | `client@192.168.27.141` |
| HQ-Server | `10.74.10.50/24` | `root@192.168.27.138` |
| Branch-GW | `10.74.20.1/24` | `branchgateway@192.168.27.139` |
| Branch-PC | `10.74.20.50/24` | `branchpc@192.168.27.140` |

- Qua SSH, kiểm tra IP LAN và route mới trên bốn Linux, cùng các chain firewall mới trên hai gateway. S2S dùng `tun1` tại HQ và `tun0` tại Branch. Hai host LAN ping được nhau theo cả hai chiều.
- Branch-PC nhận HTTP 200 từ `http://10.74.10.50`. API `/api/identity` trả IP nguồn `10.74.20.50`. SHA-256 của file tải trùng file gốc trên HQ-Server.
- Phía HQ-GW ghi nhận `client1` kết nối từ WAN `172.16.1.100`, được cấp `10.8.0.2`, được gửi route `10.74.10.0/24` và thương lượng `AES-256-GCM`. Chưa kiểm tra HTTP từ trong VM Windows ở lần chuyển địa chỉ này.
- `netplan apply` làm gián đoạn SSH trên ba VM dùng `systemd-networkd`. Khởi động mềm ba VM bằng VMware đã khôi phục các NIC và lease NAT. Bản sao trước thay đổi nằm ở `/root/vpn-lab-backup/lan-10-74-20261120-v2` trên từng Linux.

## Lần triển khai ban đầu trên dải LAN cũ

Địa chỉ bên dưới cùng log và PCAP đi kèm phản ánh lần chạy trước khi chuyển subnet. Xem [quy trình chuyển địa chỉ](README.md#2-chuyển-địa-chỉ-cho-lab-đã-dựng) để áp dụng cho bản lab còn dùng dải cũ.

**Bốn Linux đã được cấu hình và kiểm tra thực tế qua SSH.** OpenVPN Site-to-Site và Portal HQ đang hoạt động; server Client-to-Site đã được thử bằng client Linux tạm. Windows Remote-PC do người dùng tự cấu hình, chưa được đánh dấu đạt nghiệm thu Windows.

Ngày ghi nhận theo Asia/Bangkok. Thời gian trong log Linux và PCAP có thể hiển thị UTC.

## 1 Máy và địa chỉ đã xác minh

Đã đối chiếu cấu hình VMX/LAN Segment, MAC và MAC đọc qua SSH trước khi thay đổi guest. Các địa chỉ NAT trong bảng là lease DHCP hiện tại, có thể thay đổi ở lần cấp phát sau.

| VM trong VMware | Hostname Linux | User SSH | NAT quản trị | WAN lab | LAN lab | Repo trên VM |
| --- | --- | --- | --- | --- | --- | --- |
| HQ-Gateway | hq-gw | client | 192.168.27.141 | 172.16.1.10 | 192.168.10.1 | /home/client/vpn-lab |
| BR-Gateway | branch-gw | branchgateway | 192.168.27.139 | 172.16.1.20 | 192.168.20.1 | /home/branchgateway/vpn-lab |
| HQ-Server | hq-server | root | 192.168.27.138 | — | 192.168.10.50 | /root/vpn-lab |
| BR-PC | branch-pc | branchpc | 192.168.27.140 | — | 192.168.20.50 | /home/branchpc/vpn-lab |

Các gateway dùng ens33 WAN, ens37 LAN, ens38 NAT. Hai host LAN dùng ens33 LAN và ens37 NAT. HQ-GW dùng NetworkManager; ba Linux còn lại dùng networkd. Tất cả có nền Ubuntu 26.04; OpenVPN trên gateway là 2.7.0, Easy-RSA tại HQ là 3.2.5.

BR-PC hiện là VM CLI, kiểm tra ứng dụng bằng curl; chưa cài thêm Desktop/browser. Không cài VPN client trên hai host LAN để thực hiện S2S.

## 2 Dịch vụ và tệp đang sử dụng

| Máy | Dịch vụ | Kết quả sau reboot |
| --- | --- | --- |
| HQ-GW | openvpn-server@server-c2s | Active, nghe 172.16.1.10 UDP1194, tun0 10.8.0.1 |
| HQ-GW | openvpn-server@server-s2s | Active, nghe 172.16.1.10 UDP1195, tun1 10.9.0.1 |
| Branch-GW | openvpn-client@client-s2s | Active, handshake thành công, tun0 10.9.0.2, route HQ qua tunnel |
| HQ-Server | nginx | Active; HTTP 200 tại 192.168.10.50, API định danh hoạt động |
| Hai gateway | netfilter-persistent và sysctl | Chain firewall được phục hồi; IPv4 forwarding bằng 1 |

CA nằm tại `/home/client/openvpn-ca` trên HQ-GW. Chỉ bộ chứng chỉ Branch được chuyển sang Branch-GW; không chuyển private key CA. CRL có nextUpdate ngày 19/05/2027 UTC tại thời điểm kiểm tra; cần làm mới trước hạn.

Profile Windows đã tạo tại `/home/client/client1.ovpn` trên HQ-GW. Bản lấy về Windows host nằm ở **`C:\Users\ngnsusinn\Downloads\VPN-Lab\client1.ovpn`**. Profile chứa khóa riêng, nằm ngoài repo.

## 3 Các kiểm tra thực tế đã đạt

| Phép thử | Kết quả và phạm vi | Bằng chứng |
| --- | --- | --- |
| S2S tại HQ-GW và Branch-GW | Đúng IP tunnel, route qua đúng TUN, CN branch-gw trong status mới | [HQ](../../tests/results/2026-11-20-live/hq-gw-final-verification.json), [Branch](../../tests/results/2026-11-20-live/branch-gw-final-verification.json) |
| Hai chiều host LAN | HQ-Server chủ động ping Branch-PC và Branch-PC chủ động ping HQ-Server thành công | [HQ-Server](../../tests/results/2026-11-20-live/hq-server-final-verification.json), [Branch-PC](../../tests/results/2026-11-20-live/branch-pc-final-verification.json) |
| Portal qua S2S | HTTP 200; Nginx quan sát nguồn 192.168.20.50 | [Branch-PC](../../tests/results/2026-11-20-live/branch-pc-final-verification.json) |
| C2S với client Linux tạm | Một namespace riêng trên Branch-GW có WAN 172.16.1.101 dùng profile client1, được cấp 10.8.0.2 và truy cập Portal; không phải kết quả Windows GUI | [Client thử](../../tests/results/2026-11-20-live/c2s-client-functional-summary.json), [log cipher và status](../../tests/results/2026-11-20-live/hq-gw-capture-and-crypto.json) |
| Cipher và capture đối chứng | Log hai loại VPN ghi AES-256-GCM; WAN có 1.186 gói UDP1194 và 1.162 gói UDP1195; LAN có 1.138 gói TCP80 trong lần tải đối chứng | [WAN PCAP](../../tests/results/2026-11-20-live/pcap/vpn-wan.pcap), [LAN PCAP](../../tests/results/2026-11-20-live/pcap/hq-lan.pcap) |
| Đi vòng C2S bằng route WAN | Ngắt client tạm, tự thêm route HQ-LAN qua 172.16.1.10; HTTP bị chặn, counter DROP HQ tăng | [Kết quả](../../tests/results/2026-11-20-live/branch-gw-c2s-disconnect-bypass.json) |
| Mất S2S có route dự phòng WAN | Dừng client S2S, thêm route HQ-LAN qua WAN: ping/HTTP từ Branch-PC đều thất bại; DROP Branch tăng 5 gói; capture WAN hướng ra có 0 gói LAN bản rõ | [Client](../../tests/results/2026-11-20-live/branch-pc-s2s-off-negative.json), [Gateway](../../tests/results/2026-11-20-live/branch-gw-s2s-off-capture-and-restore.json), [PCAP](../../tests/results/2026-11-20-live/pcap/s2s-off-wan.pcap) |
| Cô lập NAT trên bốn Linux | Đồng thời tạm ngắt IPv4 NAT trong guest, kiểm tra không còn IPv4/route NAT; ping hai chiều và HTTP S2S vẫn thành công, sau đó tự phục hồi NAT | [HQ-GW](../../tests/results/2026-11-20-live/hq-gw-nat-isolation.json), [HQ-Server](../../tests/results/2026-11-20-live/hq-server-nat-isolation.json), [Branch-GW](../../tests/results/2026-11-20-live/branch-gw-nat-isolation.json), [Branch-PC](../../tests/results/2026-11-20-live/branch-pc-nat-isolation.json) |
| Reboot cả bốn Linux | Boot ID thay đổi trên từng máy; IP, dịch vụ, firewall, forwarding và S2S/HTTP tự phục hồi, không phải khởi động dịch vụ thủ công | Tệp before-reboot, after-reboot-state và final-verification trong [thư mục kết quả](../../tests/results/2026-11-20-live) |
| Đồng bộ thời gian | Chrony sau reboot có nguồn NTP và stratum 3 trên cả bốn máy | Các tệp final-verification ở trên |

Payload tải qua cả S2S và client C2S thử có đúng 1.048.576 byte, cùng SHA256 với tệp gốc:

```text
63f19950a67b8a4728337f1da3ab83f5ee6b821852f13fcdb86eb60873ffa4a4
```

Client/namespace C2S tạm và bản sao profile trên Branch đã được dọn; server C2S đang chờ người dùng kết nối Windows. Các kiểm tra payload/cipher là lần đo chức năng, không được diễn giải thành thông lượng cực đại hoặc chứng nhận an toàn tuyệt đối.

## 4 Những lỗi đã xử lý khi triển khai

- Sửa `renderrer: networkkd` trên Branch-GW thành `renderer: networkd`, vô hiệu YAML DHCP catch-all và giữ ens38 DHCP NAT.
- Đặt IP/route cho HQ-Server và Branch-PC, gồm route trả về hai site khi NAT tạm còn bật.
- Phát hiện `vars.example` khi chép từ Windows có CRLF làm Easy-RSA 3.2.5 lỗi dry-run. Sửa `init-ca.sh` chuẩn hóa CRLF khi nạp vars, thêm quy tắc LF và kiểm thử hồi quy. CA được tạo thành công sau sửa; không xóa hay khởi tạo lại CA đã hoạt động.
- Bộ test offline hiện có **10/10 test đạt**, gồm ca sao chép vars từ Windows.

## 5 Trạng thái bàn giao và phần Windows còn lại

NAT quản trị của bốn Linux hiện đã được bật lại để tiếp tục SSH từ host. Phép thử cô lập ở trên ngắt NAT trong guest, không thay đổi cấu hình NIC VMware vĩnh viễn. Trước buổi demo có thể ngắt NIC NAT trong VMware theo [nghiệm thu](06-acceptance.md); khi đó host không SSH trực tiếp qua các IP NAT được nữa.

Người dùng tự thực hiện trên Windows Remote-PC:

1. Đặt NIC WAN-Net thành 172.16.1.100/24, gateway/DNS của card lab để trống.
2. Cài OpenVPN Community/GUI và chuyển `client1.ovpn` vào VM. Có thể dùng WinSCP từ Windows VM tới 172.16.1.10, user client, lấy `/home/client/client1.ovpn`.
3. Import profile, Connect, kiểm tra IP 10.8.0.x và route HQ-LAN.
4. Mở `http://192.168.10.50`, kiểm tra tải file và Disconnect/Connect lại theo [hướng dẫn Windows](05-windows-remote.md).

Chưa nghiệm thu driver/GUI/route trên Windows, phép thu hồi chứng chỉ thật, chứng chỉ sai vai trò, IPsec hoặc IPv6. Không đánh dấu các mục này PASS từ kết quả Linux thay thế. Các bản sao cấu hình được lưu trong `/root/vpn-lab-backup/` trên từng Linux; backup đầy đủ sau triển khai chứa khóa riêng chỉ giữ tại VM với quyền root.
