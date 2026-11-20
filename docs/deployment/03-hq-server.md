# Máy 3 HQ-Server

HQ-Server cung cấp web nội bộ tại **`http://192.168.10.50`** để cả Windows remote và Branch-PC truy cập. Máy này có một NIC HQ LAN và một NIC NAT tạm, không chạy OpenVPN và không làm CA. Làm [chuẩn bị chung](00-preparation.md), rồi chạy các bước sau trên **HQ-Server**.

## 1 Vai trò và card mạng

| Card ví dụ | Nối VMware | Địa chỉ | Gateway |
| --- | --- | --- | --- |
| ens33 | HQ-LAN-Net | 192.168.10.50/24 | 192.168.10.1 |
| ens37 | NAT | DHCP tạm | Do DHCP cấp, chỉ để tải gói |

Không nối HQ-Server vào WAN-Net. Tài nguyên HQ được truy cập qua HQ-GW; không mở đường trực tiếp từ Windows WAN tới NIC server.

## 2 Đặt tên máy và IP tĩnh

```bash
sudo hostnamectl set-hostname hq-server
ip -br link
sudo nano /etc/netplan/20-vpn-lab.yaml
```

Thay tên NIC theo MAC thật, xử lý YAML cũ như phần chung rồi lưu:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:
      dhcp4: false
      dhcp6: false
      addresses: [192.168.10.50/24]
      routes:
        - to: default
          via: 192.168.10.1
          metric: 200
        - to: 192.168.20.0/24
          via: 192.168.10.1
        - to: 10.9.0.0/24
          via: 192.168.10.1
    ens37:
      dhcp4: true
      dhcp6: false
      optional: true
      dhcp4-overrides:
        route-metric: 50
```

Route cụ thể tới Branch và tunnel S2S bảo đảm lưu lượng trả lời đi qua HQ-GW ngay cả khi NAT còn bật. Route NAT ưu tiên hơn cho Internet nhờ metric 50. Nếu dùng image quản lý bằng NetworkManager, đổi renderer tương ứng.

```bash
sudo chmod 600 /etc/netplan/20-vpn-lab.yaml
sudo netplan generate
sudo netplan try
ip -br address
ip route
ping -c 3 -W 2 192.168.10.1
```

Kỳ vọng ping được LAN HQ-GW; chưa có S2S thì chưa cần ping Branch. Cài bộ gói khi NAT đang hoạt động:

```bash
cd ~/vpn-lab
sudo bash scripts/common/install-prerequisites.sh server
date -Is
chronyc tracking
```

## 3 Triển khai web nội bộ

Trong lượt B, đây là dịch vụ dựng đầu tiên để hai gateway có tài nguyên kiểm tra:

```bash
cd ~/vpn-lab
sudo bash scripts/deploy-all.sh hq-server
sudo nginx -t
sudo systemctl is-active nginx
sudo ss -ltnp 'sport = :80'
```

Script chép Portal vào `/var/www/vpn-lab-portal`, cấu hình `/etc/nginx/sites-available/hq-portal` và kích hoạt qua `/etc/nginx/sites-enabled/default`. Listener của Portal là `192.168.10.50:80` và `127.0.0.1:80`. Nếu VM từng chạy web khác, kiểm tra `sudo nginx -T` để phát hiện site còn bind wildcard hoặc xung đột cổng, rồi xử lý đúng site cũ.

## 4 Kiểm tra ngay trên server

```bash
cd ~/vpn-lab
bash scripts/verify-portal.sh
curl --noproxy '*' --fail --connect-timeout 3 --max-time 6 -I http://192.168.10.50/
curl --noproxy '*' --fail --connect-timeout 3 --max-time 6 http://192.168.10.50/api/identity
wc -c /var/www/vpn-lab-portal/files/benchmark-payload-1mb.dat
sha256sum /var/www/vpn-lab-portal/files/benchmark-payload-1mb.dat
```

Kỳ vọng HTTP 200, API JSON có trường `ip`, payload đúng **1.048.576 byte**. Lưu hash để so với tệp tải trên Branch-PC và Windows. API được gọi từ chính HQ-Server chưa chứng minh đường VPN; các phép thử từ hai client thực hiện sau.

Đến đây có thể tiếp tục triển khai [HQ-GW](01-hq-gw.md), rồi [Branch-GW](02-branch-gw.md).

## 5 Kiểm tra chiều HQ sang Branch sau khi S2S lên

Khi hai gateway đã có tunnel và Branch-PC đã đặt IP:

```bash
cd ~/vpn-lab
ip route get 192.168.20.50
ping -c 3 -W 2 192.168.20.50
bash scripts/verify-s2s.sh hq-server
```

Route ở HQ-Server phải có `via 192.168.10.1`, nguồn `192.168.10.50`. Host HQ chủ động ping Branch thành công bổ sung cho phép thử Branch chủ động truy cập HQ; chỉ có Echo Reply của một chiều chưa chứng minh hai bên đều khởi tạo được kết nối.

Khi Branch-PC mở Portal, có thể xem nguồn tại Nginx:

```bash
sudo tail -n 20 /var/log/nginx/access.log
```

S2S dự kiến giữ nguồn `192.168.20.50`. Khi Windows C2S mở Portal, Nginx dự kiến thấy `192.168.10.1` vì NAT tại HQ-GW. Không sửa NAT S2S để làm hai trường hợp giống nhau; IP tunnel Windows kiểm tra tại Windows và status C2S trên HQ-GW.

## 6 Khoanh vùng lỗi trên HQ-Server

| Triệu chứng | Kiểm tra |
| --- | --- |
| Nginx cannot assign requested address | NIC HQ LAN đã có 192.168.10.50 chưa; sau khi IP đúng, restart nginx |
| Nginx address already in use | sudo ss -ltnp và nginx -T, site/process cũ chiếm cổng |
| HTTP local được nhưng Branch không vào được | Route trả về Branch, forwarding/firewall hai gateway, firewall host nếu đã bật |
| Branch vào được nhưng Windows không vào được | C2S/NAT tại HQ-GW, profile và route Windows; không cài OpenVPN trên server để chữa lỗi |
| Sau reboot web chưa lên | Kiểm tra địa chỉ LAN, nginx enabled, journal và trạng thái mạng; thử restart sau khi IP có sẵn để xác định lỗi thứ tự khởi động |

```bash
sudo systemctl is-enabled nginx
sudo journalctl -u nginx -n 60 --no-pager
ip -br address
ip route
```

Khi năm máy đã hoạt động, ngắt NAT tạm và làm [nghiệm thu](06-acceptance.md). Không cần HQ-Server truy cập Internet trong buổi demo.
