# Máy 4 Branch-PC

Branch-PC là máy người dùng trong LAN chi nhánh, dùng trình duyệt truy cập HQ qua hai gateway. Máy này **không cần chạy VPN client, không import profile `.ovpn` và không làm NAT**. Hoàn tất [chuẩn bị chung](00-preparation.md), rồi thực hiện trên **Branch-PC**.

## 1 Vai trò và card mạng

| Card trên Branch-PC đã kiểm tra | Nối VMware | Địa chỉ | Gateway |
| --- | --- | --- | --- |
| ens33 | Branch-LAN-Net | 192.168.20.50/24 | 192.168.20.1 |
| ens37 | NAT | DHCP tạm | Do DHCP cấp, chỉ để tải gói |

Không nối Branch-PC trực tiếp với HQ-LAN-Net hoặc WAN-Net. Nếu máy này từng dùng làm Linux VPN client trong bài ba máy, dừng/tắt client cũ và kiểm tra không có tunnel/route VPN cũ làm sai đường đi.

VM hiện tại dùng Armbian nền Ubuntu 26.04 và renderer `networkd`; NIC LAN ens33 có MAC `00:0c:29:1e:6f:8b`, NAT ens37 có MAC `00:0c:29:1e:6f:95`. Cấu hình dưới đây khớp VM đã kiểm tra qua SSH.

## 2 Đặt tên máy và IP tĩnh

```bash
sudo hostnamectl set-hostname branch-pc
ip -br link
sudo nano /etc/netplan/20-vpn-lab.yaml
```

Sau khi xử lý YAML/profile DHCP cũ, lưu cấu hình cho VM hiện tại:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:
      dhcp4: false
      dhcp6: false
      addresses: [192.168.20.50/24]
      routes:
        - to: default
          via: 192.168.20.1
          metric: 200
        - to: 192.168.10.0/24
          via: 192.168.20.1
        - to: 10.9.0.0/24
          via: 192.168.20.1
    ens37:
      dhcp4: true
      dhcp6: false
      optional: true
      dhcp4-overrides:
        route-metric: 50
```

Nếu dựng một VM Desktop khác dùng NetworkManager, đổi renderer cho đúng backend của VM đó. Áp dụng ở console:

```bash
sudo chmod 600 /etc/netplan/20-vpn-lab.yaml
sudo netplan generate
sudo netplan try
ip -br address
ip route
ping -c 3 -W 2 192.168.20.1
```

Kỳ vọng LAN có `.50`, ping được Branch-GW. Route cụ thể HQ-LAN phải qua `192.168.20.1`, kể cả khi NIC NAT còn hoạt động.

## 3 Cài công cụ và kiểm tra trình duyệt

```bash
cd ~/vpn-lab
sudo bash scripts/common/install-prerequisites.sh pc
date -Is
chronyc tracking
```

VM không có Desktop có thể nghiệm thu S2S bằng ping/curl ở các phần dưới. Nếu đã cài Desktop và muốn mở browser, cài `xdg-utils open-vm-tools-desktop` rồi mở thử Firefox/Chromium khi còn Internet. Repo không tự cài GUI/browser; tránh đợi đến sau khi ngắt NAT mới hoàn tất trình duyệt cần tải thành phần bổ sung. Lệnh `xdg-open` chỉ dùng trong phiên Desktop, không bắt buộc khi kiểm tra qua SSH.

Đến đây đợi HQ-Server và hai gateway hoàn tất lượt B. Chưa có S2S thì việc HTTP tới HQ thất bại là bình thường.

## 4 Kiểm tra ứng dụng qua S2S

Sau khi Branch-GW đã handshake thành công, chạy:

```bash
cd ~/vpn-lab
sudo bash scripts/deploy-all.sh branch-pc
ip route get 192.168.10.50
ping -c 3 -W 2 192.168.10.50
bash scripts/verify-portal.sh
curl --noproxy '*' --fail --connect-timeout 3 --max-time 6 http://192.168.10.50/api/identity
xdg-open http://192.168.10.50
```

Lệnh `deploy-all.sh branch-pc` cài công cụ rồi kiểm tra, không cài OpenVPN client trên máy này. Kỳ vọng route có `via 192.168.20.1` và `src 192.168.20.50`; web/API trả HTTP 200; API/Nginx thấy IP `192.168.20.50`. Trình duyệt dùng URL HTTP, không tự đổi sang HTTPS của một site khác.

Nếu trình duyệt báo lỗi nhưng curl hoạt động, kiểm tra proxy, cache và chế độ ép HTTPS của browser. Thêm ngoại lệ proxy cho subnet lab nếu đang dùng proxy; lệnh curl có `--noproxy '*'` để đo trực tiếp.

## 5 Tải tệp và đối chiếu dung lượng

```bash
curl --noproxy '*' --fail --connect-timeout 3 --max-time 20 -o /tmp/vpn-benchmark.dat http://192.168.10.50/files/benchmark-payload-1mb.dat
wc -c /tmp/vpn-benchmark.dat
sha256sum /tmp/vpn-benchmark.dat
```

Tệp phải có **1.048.576 byte** và hash trùng với tệp trên HQ-Server. Đây cũng là lưu lượng dùng khi bắt gói đối chứng ở HQ-GW. Thời gian tải tệp nhỏ không thay thế phép đo thông lượng VPN đầy đủ.

## 6 Xác nhận S2S hai chiều

Tại Branch-PC:

```bash
cd ~/vpn-lab
bash scripts/verify-s2s.sh branch-pc
```

Sau đó sang **HQ-Server** chạy `bash scripts/verify-s2s.sh hq-server` để HQ chủ động ping lại Branch-PC. Cả hai chiều phải đạt. Không chỉ ping hai IP tunnel gateway rồi kết luận host LAN đã liên lạc.

## 7 Khoanh vùng lỗi trên Branch-PC

| Triệu chứng | Kiểm tra |
| --- | --- |
| Không ping được 192.168.20.1 | LAN Segment, Connected, MAC, địa chỉ/mask Branch-PC và Branch-GW |
| Route HQ đi NAT | Thiếu route 192.168.10.0/24 via 192.168.20.1, YAML/profile cũ chưa được áp dụng |
| Gateway vào HQ được nhưng PC không được | Forwarding và rule LAN ↔ tunnel ở Branch, route trả về ở HQ-Server |
| API thấy nguồn khác 192.168.20.50 | Kiểm tra route, proxy hoặc NAT S2S ngoài cấu hình; không coi IP hiển thị là bằng chứng mã hóa |
| HQ không chủ động ping lại được | Route trả về, firewall đầu cuối đã bật, NIC/địa chỉ Branch; không tắt toàn bộ firewall để thay kiểm tra |

Khi Windows cũng đã Connect, tiến hành [nghiệm thu sau khi ngắt NAT](06-acceptance.md).
