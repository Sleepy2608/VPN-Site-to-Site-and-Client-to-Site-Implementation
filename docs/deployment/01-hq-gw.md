# Máy 1 HQ-GW

HQ-GW là gateway trụ sở, chạy CA/Easy-RSA, OpenVPN C2S cho Windows và OpenVPN S2S cho Branch-GW. Thực hiện [chuẩn bị chung](00-preparation.md) trước. Các lệnh dưới chạy tại **console/terminal HQ-GW** bằng tài khoản thường có sudo.

## 1 Vai trò và card mạng

| Card trên HQ-GW đã đối chiếu | Nối VMware | Địa chỉ | Chức năng |
| --- | --- | --- | --- |
| ens33 | WAN-Net | 172.16.1.10/24 | Nhận UDP 1194 từ Windows và UDP 1195 từ Branch |
| ens37 | HQ-LAN-Net | 10.74.10.1/24 | Gateway của HQ-Server |
| ens38 | NAT | DHCP tạm, hiện nhận 192.168.27.141/24 | Cài gói trước nghiệm thu |
| tun0 | OpenVPN tự tạo | 10.8.0.1/24 | Đầu server C2S |
| tun1 | OpenVPN tự tạo | 10.9.0.1/24 | Đầu server S2S |

Máy đã cung cấp thông tin là Armbian 26.11.3 nền Ubuntu 26.04, dùng NetworkManager. WAN ens33 có MAC `00:0c:29:da:ef:ff`, LAN ens37 có MAC `00:0c:29:da:ef:09`, NAT ens38 có MAC `00:0c:29:da:ef:13`. Địa chỉ DHCP NAT có thể thay đổi. Nếu dựng VM khác, đối chiếu lại MAC thay vì mặc định cùng tên card.

Không tạo hoặc gán IP tun0/tun1 bằng Netplan.

## 2 Đặt tên máy và IP tĩnh

```bash
sudo hostnamectl set-hostname hq-gw
ip -br link
sudo cp -a /etc/netplan "/root/netplan-backup-hq-gw-$(date +%Y%m%d-%H%M%S)"
sudo nano /etc/netplan/20-vpn-lab.yaml
```

Trên máy này, giữ `/etc/netplan/00-default-use-network-manager.yaml` đang có: tệp chỉ khai báo renderer, không chứa DHCP catch-all. Tạo tệp mới dưới đây; nếu đã có `20-vpn-lab.yaml` từ lần thử trước, sửa lại nội dung cho đúng. Với VM khác có YAML DHCP dùng match mọi card, xử lý xung đột theo phần chuẩn bị chung trước.

```yaml
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    ens33:
      dhcp4: false
      dhcp6: false
      addresses: [172.16.1.10/24]
    ens37:
      dhcp4: false
      dhcp6: false
      addresses: [10.74.10.1/24]
    ens38:
      dhcp4: true
      dhcp6: false
      dhcp4-overrides:
        route-metric: 50
```

Lưu trong nano bằng Ctrl+O, Enter rồi Ctrl+X. Áp dụng tại console VMware; khi `netplan try` hỏi xác nhận, nhấn Enter nếu cấu hình đúng:

```bash
sudo chmod 600 /etc/netplan/20-vpn-lab.yaml
sudo netplan generate
sudo netplan try
ip -br address
ip route
```

Kỳ vọng ens33 có `172.16.1.10/24`, ens37 có `10.74.10.1/24`, ens38 vẫn nhận DHCP trong mạng NAT. Default route tạm phải có `dev ens38`; không đặt default gateway cho WAN-Net hoặc HQ LAN của gateway. Nếu IP chưa đúng hoặc generate/try báo lỗi, giữ console và kiểm tra `nmcli -f NAME,UUID,TYPE,DEVICE connection show` để xác định profile cũ còn quản lý card; không tắt profile NAT theo phỏng đoán.

## 3 Cài gói và khai báo NIC cho script

```bash
cd ~/vpn-lab
sudo bash scripts/common/install-prerequisites.sh gw
sudo install -d -m 755 /etc/vpn-lab
sudo tee /etc/vpn-lab/interfaces.conf >/dev/null <<'EOF'
WAN_IF=ens33
LAN_IF=ens37
EOF
sudo chmod 644 /etc/vpn-lab/interfaces.conf
sudo modprobe tun
test -c /dev/net/tun && echo 'TUN san sang'
openvpn --version
bash scripts/common/check-openvpn-version.sh
date -Is
chronyc tracking
```

`interfaces.conf` phải dùng cùng NIC WAN/LAN đã đặt IP. Chạy với `sudo bash` giúp các script dùng home của tài khoản gọi sudo để tìm CA/profile. Bắt đầu từ đây, không đổi sang `sudo -i` rồi dùng `~` như thể vẫn ở home tài khoản thường.

Khi Branch-GW và HQ-Server đã đặt IP, thử:

```bash
ping -c 3 -W 2 172.16.1.20
ping -c 3 -W 2 10.74.10.50
```

Chưa có VPN thì HQ-GW chưa cần liên lạc được Branch-PC. Hoàn tất mạng/gói trên các máy khác trước khi chuyển sang lượt triển khai dịch vụ trong [bảng thứ tự](README.md).

## 4 Triển khai CA và hai server OpenVPN

Trong lượt B, sau khi HQ-Server đã dựng web, chạy trên HQ-GW:

```bash
cd ~/vpn-lab
sudo bash scripts/deploy-all.sh hq-gw
```

Lệnh còn chạy apt nên NIC NAT phải đang Connected. Lần đầu sinh khóa/DH có thể mất vài phút. Các bước chính là bật forwarding, áp dụng firewall, tạo CA/chứng chỉ nếu chưa có, đóng gói `client1.ovpn`, rồi khởi động hai OpenVPN server. Không chạy lại `init-pki` thủ công lên CA đang dùng.

| Thành phần | Tệp hoặc địa chỉ |
| --- | --- |
| CA của tài khoản triển khai | ~/openvpn-ca |
| Profile Windows | ~/client1.ovpn |
| Cấu hình C2S đang chạy | /etc/openvpn/server/server-c2s.conf |
| Cấu hình S2S đang chạy | /etc/openvpn/server/server-s2s.conf |
| Quyền client C2S | /etc/openvpn/ccd-c2s/client1 |
| Định tuyến client Branch | /etc/openvpn/ccd/branch-gw |
| Trạng thái C2S | /var/log/openvpn/openvpn-c2s-status.log |
| Trạng thái S2S | /var/log/openvpn/openvpn-s2s-status.log |

C2S đẩy route HQ-LAN cho Windows và NAT nguồn VPN sang `10.74.10.1` khi đi vào HQ LAN. S2S dùng route kernel và CCD/iroute tới Branch LAN, giữ IP LAN nguồn. Server S2S chỉ nhận chứng chỉ `branch-gw`; C2S mặc định nhận `client1` qua CCD allowlist.

## 5 Kiểm tra server đã khởi động

```bash
sudo systemctl is-active openvpn-server@server-c2s openvpn-server@server-s2s
sysctl net.ipv4.ip_forward
ip -br address show tun0
ip -br address show tun1
sudo ss -lunp 'sport = :1194 or sport = :1195'
ls -l ~/client1.ovpn
sudo iptables -S VPN_LAB_FORWARD
sudo iptables -t nat -S POSTROUTING
```

Kỳ vọng hai service `active`, forwarding bằng `1`, tun0 là `10.8.0.1`, tun1 là `10.9.0.1`, UDP1194/1195 mở. Profile có quyền đọc hạn chế. Chưa chạy `verify-c2s.sh server` để đòi kết quả đạt lúc Windows chưa kết nối: script yêu cầu có client thật trong status mới.

## 6 Chuyển chứng chỉ sang Branch-GW

Branch-GW phải ping được ở WAN `.20`, có tài khoản SSH và sudo từ bước chuẩn bị. Trên HQ-GW, thay `student` bằng tài khoản thật ở Branch:

```bash
cd ~/vpn-lab
sudo env BRANCH_USER=student bash scripts/pki/distribute-certs.sh branch-gw 172.16.1.20
```

Đối chiếu host key đúng VM nếu được hỏi. Script có thể hỏi mật khẩu SSH và sudo trên Branch. Chỉ chuyển `ca.crt`, `ta.key`, `branch-gw.crt`, `branch-gw.key`; **không chuyển khóa riêng CA**. Sang [Máy 2](02-branch-gw.md) để kiểm tra bốn tệp và chạy deploy S2S.

Windows sẽ nhận tệp `~/client1.ovpn` theo [Máy 5](05-windows-remote.md). Không gửi profile Branch cho Windows, không gửi profile Windows cho Branch.

## 7 Kiểm tra khi hai client đã kết nối

Sau khi Branch đã kết nối và Windows đã Connect, chờ ít nhất một chu kỳ status khoảng 5 giây rồi chạy:

```bash
cd ~/vpn-lab
sudo bash scripts/verify-s2s.sh hq-gw
sudo bash scripts/verify-c2s.sh server
sudo cat /var/log/openvpn/openvpn-s2s-status.log
sudo cat /var/log/openvpn/openvpn-c2s-status.log
```

S2S status phải có CN `branch-gw`; C2S phải có `client1`. Gateway kiểm tra ping với nguồn LAN, nhưng vẫn cần kiểm tra từ HQ-Server và Branch-PC để chứng minh hai host LAN thực sự liên lạc.

## 8 Khoanh vùng lỗi trên HQ-GW

| Triệu chứng | Kiểm tra |
| --- | --- |
| Service không chạy | Xem journal đúng instance; cert/key, local 172.16.1.10, TUN, tun/port có bị demo cũ chiếm không |
| Báo thiếu CA/chứng chỉ | Xem đường dẫn CA được in ra, tài khoản chạy sudo, bản repo cập nhật; không tự tạo CA thứ hai để thử |
| Branch chưa nối | Kiểm tra WAN, UDP1195, bộ chứng chỉ branch-gw, giờ hai máy và CCD đúng CN |
| Windows chưa nối | Xem log GUI, profile client1, UDP1194, CA và CN server hq-c2s-server |
| Tunnel lên nhưng web lỗi | Kiểm tra route, forwarding, counters FORWARD, Nginx và gateway trả về của HQ-Server |

```bash
sudo journalctl -u openvpn-server@server-c2s -n 60 --no-pager
sudo journalctl -u openvpn-server@server-s2s -n 60 --no-pager
sudo iptables -nvL VPN_LAB_FORWARD
```

Sau khi cả hệ thống chạy, thực hiện [nghiệm thu và reboot](06-acceptance.md). Giữ CA hiện tại và snapshot đã biết hoạt động để phục hồi khi thử CRL sau này.
