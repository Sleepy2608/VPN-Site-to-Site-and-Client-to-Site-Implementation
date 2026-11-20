# Máy 2 Branch-GW

Branch-GW là gateway chi nhánh và OpenVPN client của đường S2S. Nó chuyển tiếp lưu lượng cho Branch-PC, không dùng profile C2S của Windows. Làm [chuẩn bị chung](00-preparation.md), sau đó thực hiện các bước dưới trên **Branch-GW**.

## 1 Vai trò và card mạng

| Card trên Branch-GW đã đối chiếu | Nối VMware | Địa chỉ | Chức năng |
| --- | --- | --- | --- |
| ens33 | WAN-Net | 172.16.1.20/24 | Đi tới HQ-GW 172.16.1.10 UDP1195 |
| ens37 | Branch-LAN-Net | 192.168.20.1/24 | Gateway cho Branch-PC |
| ens38 | NAT | DHCP tạm, hiện nhận 192.168.27.139/24 | Cài gói |
| tun0 | OpenVPN tự tạo | 10.9.0.2/24 | Đầu tunnel S2S của Branch |

`tun0` trên Branch là S2S; `tun0` trên HQ lại là C2S. Tên interface có ý nghĩa trong từng VM, không dùng chung giữa các máy.

Trên VM đã cung cấp: ens33 có MAC `00:0c:29:d7:fa:9e` là WAN, ens37 có MAC `00:0c:29:d7:fa:a8` là LAN còn lại, ens38 có MAC `00:0c:29:d7:fa:b2` là NAT. Máy dùng renderer `networkd`; YAML mặc định chứa `all-eth-interfaces` với match `e*` và DHCP. Địa chỉ NAT do DHCP cấp có thể thay đổi.

## 2 Đặt tên máy và IP tĩnh

```bash
sudo hostnamectl set-hostname branch-gw
ip -br link
sudo cp -a /etc/netplan "/root/netplan-backup-branch-gw-$(date +%Y%m%d-%H%M%S)"
sudo nano /etc/netplan/20-vpn-lab.yaml
```

Tạo cấu hình mới sau đây nhưng chưa áp dụng mạng cho đến khi đã vô hiệu YAML DHCP catch-all ở bước tiếp theo:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:
      dhcp4: false
      dhcp6: false
      addresses: [172.16.1.20/24]
    ens37:
      dhcp4: false
      dhcp6: false
      addresses: [192.168.20.1/24]
    ens38:
      dhcp4: true
      dhcp6: false
      optional: true
      dhcp4-overrides:
        route-metric: 50
```

Lưu Ctrl+O, Enter rồi thoát Ctrl+X. Với VM này, tệp DHCP cũ có thể match cả ba card, nên cần ngừng nạp nó. Chạy đoạn sau tại console; đoạn lệnh nhận diện tệp cũ theo khóa `all-eth-interfaces` đã quan sát, không đoán tên tệp:

```bash
for lab_cfg in /etc/netplan/*.yaml /etc/netplan/*.yml; do
    [ -f "$lab_cfg" ] || continue
    if sudo grep -q 'all-eth-interfaces:' "$lab_cfg"; then
        sudo mv -- "$lab_cfg" "${lab_cfg}.disabled"
    fi
done
sudo ls -l /etc/netplan
```

Giữ `20-vpn-lab.yaml` là cấu hình mới đang được nạp; tệp catch-all cũ đã chuyển sang đuôi `.disabled`. Không áp dụng phần vô hiệu catch-all này sang HQ-GW: máy HQ hiện chỉ có tệp renderer NetworkManager và không có khóa catch-all này. Áp dụng trên Branch:

```bash
sudo chmod 600 /etc/netplan/20-vpn-lab.yaml
sudo netplan generate
sudo netplan try
ip -br address
ip route
```

Khi `netplan try` hỏi xác nhận, nhấn Enter nếu không có lỗi và kết nối đúng. Kỳ vọng ens33 là `172.16.1.20/24`, ens37 là `192.168.20.1/24`, ens38 còn DHCP NAT và default route có `dev ens38`. Không đặt default gateway trên WAN-Net. Lúc này HQ-GW đã đặt WAN `.10`, nên có thể kiểm tra `ping -c 3 -W 2 172.16.1.10` trước khi cài VPN.

## 3 Cài gói và chuẩn bị SSH

```bash
cd ~/vpn-lab
sudo bash scripts/common/install-prerequisites.sh gw
sudo install -d -m 755 /etc/vpn-lab
sudo tee /etc/vpn-lab/interfaces.conf >/dev/null <<'EOF'
WAN_IF=ens33
LAN_IF=ens37
EOF
sudo chmod 644 /etc/vpn-lab/interfaces.conf
sudo systemctl enable --now ssh
sudo modprobe tun
test -c /dev/net/tun && echo 'TUN san sang'
bash scripts/common/check-openvpn-version.sh
date -Is
chronyc tracking
ping -c 3 -W 2 172.16.1.10
```

Đến đây tạm dừng phần deploy. Đợi HQ-Server dựng web, HQ-GW dựng CA/server và chuyển bộ chứng chỉ theo [hướng dẫn Máy 1](01-hq-gw.md). Không chạy `init-ca.sh` trên Branch để tự tạo một CA khác.

## 4 Kiểm tra chứng chỉ đã nhận

Sau khi lệnh phân phối trên HQ-GW hoàn tất, tại Branch:

```bash
sudo ls -l /etc/openvpn/client/ca.crt /etc/openvpn/client/ta.key /etc/openvpn/client/branch-gw.crt /etc/openvpn/client/branch-gw.key
sudo openssl x509 -in /etc/openvpn/client/branch-gw.crt -noout -subject -issuer -dates
```

Kỳ vọng đủ bốn tệp, cert có CN `branch-gw`, thời gian hiện tại nằm trong hạn sử dụng. Hai khóa `.key` có mode 600. Thư mục này không chứa `ca.key`. Nếu thiếu tệp, sửa bước chuyển cert; không chép khóa CA hay profile Windows vào để thay thế.

## 5 Triển khai S2S

Khi HQ server S2S đã hoạt động, chạy:

```bash
cd ~/vpn-lab
sudo bash scripts/deploy-all.sh branch-gw
sudo systemctl is-active openvpn-client@client-s2s
sudo journalctl -u openvpn-client@client-s2s -n 60 --no-pager
ip -br address show tun0
ip route get 192.168.10.50
sysctl net.ipv4.ip_forward
```

Lệnh triển khai còn cần Internet qua NAT. Cấu hình đang chạy là `/etc/openvpn/client/client-s2s.conf`: remote `172.16.1.10 1195`, xác thực server CN `hq-s2s-gw`, dùng cert `branch-gw` và nhận route HQ-LAN do HQ đẩy sang.

Kỳ vọng có log `Initialization Sequence Completed`, tun0 là `10.9.0.2`, forwarding `1`, route tới `192.168.10.50` chứa `dev tun0`. Service `active` mà chưa có handshake/địa chỉ/route thì chưa đạt.

## 6 Kiểm tra đường đi và forwarding

HQ-Server phải đang chạy, Branch-PC đã đặt IP theo lượt A:

```bash
cd ~/vpn-lab
ping -c 3 -W 2 10.9.0.1
ping -I 192.168.20.1 -c 3 -W 2 192.168.10.50
sudo bash scripts/verify-s2s.sh branch-gw
sudo iptables -nvL VPN_LAB_FORWARD
```

Ping có nguồn `192.168.20.1` kiểm tra đường trả về cho mạng Branch. Tiếp theo dùng **Branch-PC** mở Portal; kết quả từ gateway riêng lẻ chưa thay thế phép thử host LAN.

## 7 Khoanh vùng lỗi trên Branch-GW

| Triệu chứng | Kiểm tra |
| --- | --- |
| Không ping được 172.16.1.10 | NIC WAN hai gateway cùng WAN-Net, Connected, đúng MAC/IP/mask |
| TLS verify hoặc certificate revoked | Đồng hồ, issuer/CA, CN branch-gw, CRL trên HQ; đọc journal hai đầu |
| Có active nhưng không có 10.9.0.2 | Handshake chưa hoàn tất; UDP1195, cert/key, server CN, cấu hình demo cũ chiếm tun0 |
| Ping tunnel được nhưng HQ-Server không được | Route HQ qua tun0, forwarding, firewall HQ/Branch, IP/gateway và Nginx HQ-Server |
| Branch-PC không vào được nhưng gateway vào được | NIC LAN, IP/gateway của Branch-PC, rule FORWARD và route trả về HQ-Server |

```bash
ip route
sudo cat /etc/vpn-lab/interfaces.conf
sudo journalctl -u openvpn-client@client-s2s -n 80 --no-pager
sudo iptables -S VPN_LAB_FORWARD
```

Không thêm NAT S2S để che lỗi route. Phương án này giữ IP LAN nguồn để HQ nhận đúng `192.168.20.50` từ Branch-PC. Hoàn tất [Máy 4](04-branch-pc.md), rồi cùng cả hệ thống làm [nghiệm thu](06-acceptance.md).
