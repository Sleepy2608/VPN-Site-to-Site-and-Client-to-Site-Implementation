# Kịch bản triển khai và demo: 4 Armbian + 1 Windows trên VMware

> Phương án chính để nghiệm thu đủ Chủ đề 14: 5 máy, cả C2S và S2S. [Bài 3 máy](three-vm-openvpn-demo.md) chỉ dùng để thực hành C2S; xem [kết quả rà soát](../topic14-audit.md).

Nếu chia công việc theo từng VM, dùng **[bộ hướng dẫn triển khai riêng cho 5 máy](../deployment/README.md)**. Bộ đó tách rõ lượt cấu hình mạng trên tất cả máy và lượt triển khai dịch vụ theo phụ thuộc; tài liệu bên dưới bổ sung kịch bản demo và lời dẫn.

Tài liệu này đi từ VM mới đến buổi trình diễn. Mô hình dùng **OpenVPN cho cả Client-to-Site (C2S) và Site-to-Site (S2S)**. Chuẩn bị và cài đặt hoàn tất trước buổi demo; phần trình diễn khoảng **8–10 phút**, không bao gồm thời gian cài hệ điều hành, tải gói và tạo khóa.

Các lệnh Bash chạy trên đúng máy Armbian được ghi ở mỗi bước. Lệnh PowerShell chỉ chạy trên Windows Remote-PC. Ví dụ dùng tài khoản có quyền sudo tên `student`, repo ở `~/vpn-lab`; thay bằng tài khoản/thư mục thực tế của bạn.

## 1. Mỗi máy làm gì, cài gì, chạy gì?

| Máy | Hệ điều hành | Vai trò | Phần mềm cần có | Dịch vụ khi demo |
| --- | --- | --- | --- | --- |
| **HQ-GW** | Armbian Minimal/CLI, không GUI | Đầu nhận VPN nhân viên và VPN chi nhánh; định tuyến vào HQ | OpenVPN, Easy-RSA, iptables, iptables-persistent, netfilter-persistent, tcpdump, SSH, chrony, công cụ mạng | `openvpn-server@server-c2s`, `openvpn-server@server-s2s`; forwarding IPv4 |
| **Branch-GW** | Armbian Minimal/CLI, không GUI | Chủ động kết nối S2S tới HQ; chuyển tiếp lưu lượng Branch-PC | OpenVPN, Easy-RSA theo bộ gói gateway của repo, iptables, iptables-persistent, netfilter-persistent, tcpdump, SSH, chrony, công cụ mạng | `openvpn-client@client-s2s`; forwarding IPv4 |
| **HQ-Server** | Armbian Minimal/CLI, không GUI | Máy web nội bộ để hai phía truy cập | Nginx, curl, chrony, công cụ mạng | `nginx`, Portal tại `http://10.74.10.50` |
| **Branch-PC** | Armbian Desktop **Xfce**, có GUI | Máy người dùng chi nhánh, mở web qua hai gateway | Trình duyệt Firefox/Chromium, curl, traceroute, công cụ mạng; desktop có sẵn trong image | Desktop, terminal, browser; lưu lượng VPN do Branch-GW xử lý |
| **Remote-PC** | Windows x64 | Máy nhân viên ở WAN giả lập, tự bật/tắt C2S | OpenVPN Community kèm **OpenVPN GUI và driver**, trình duyệt; Wireshark tùy chọn | OpenVPN GUI với profile `client1.ovpn` |

SSH chỉ phục vụ quản trị/chuyển file. CA và khóa ký CA đặt trên HQ-GW; Branch chỉ nhận chứng chỉ/khóa của `branch-gw`. Windows nhận profile của `client1`. Không chép cả thư mục CA sang các máy khác.

### Image và tài nguyên VM

- Với VMware trên host Intel/AMD, lấy image **Armbian Generic UEFI x86_64** ở [trang UEFI x86 chính thức](https://armbian.com/boards/uefi-x86). Không lấy image dành riêng cho board ARM.
- Ba máy CLI: chọn mục **Minimal / IOT → Minimal (CLI) → UEFI ISO**. Branch-PC: **Desktop → Xfce → UEFI ISO**. Có thể dùng cùng một ISO CLI để cài ba VM riêng. Chọn cùng nền Ubuntu để dễ quản lý gói.
- Bản trong ảnh lựa chọn trước đó là Ubuntu 26.04: CLI dùng kernel `current`, Xfce ISO dùng `edge`. Tên phiên bản/kernel trên trang có thể thay đổi; giữ lại tên hai file ISO đã tải để các lần dựng lại dùng cùng bộ image.
- Nếu file tải về có đuôi `.iso.xz`, giải nén để lấy `.iso`. Đặt firmware VM là **UEFI**, gắn ISO vào CD/DVD rồi cài vào đĩa ảo của chính VM. Nếu image khởi động vào môi trường live, dùng trình cài có sẵn hoặc `armbian-install` với tùy chọn cài vào UEFI disk theo [hướng dẫn Armbian](https://docs.armbian.com/getting-started/install-to-internal-storage/). Sau cài đặt, tháo ISO và khởi động lại để xác nhận VM chạy từ đĩa ảo.
- Cấp phát gợi ý cho lab: mỗi CLI 2 vCPU, 1–2 GB RAM, 16–20 GB đĩa; Branch-PC 2 vCPU, 3 GB RAM, 24 GB đĩa; Windows 2 vCPU, 4 GB RAM và đĩa phù hợp phiên bản Windows. Đây là mức gợi ý vận hành lab, không thay thế yêu cầu cài đặt của hệ điều hành.
- Windows: ưu tiên **Windows 11 x64 còn được hỗ trợ**. Baseline tương thích lab là Windows 10 22H2 x64; xem [ghi chú vòng đời và OpenVPN](../technical-guides/08-windows-client-requirements.md).

Nếu clone VM, chọn tạo MAC mới, đặt hostname khác nhau và kiểm tra không trùng IP. Snapshot sau từng mốc lớn giúp phục hồi nhanh.

## 2. Nối mạng VMware trước khi cấu hình VPN

Tạo ba **LAN Segment** trong VMware, rồi gắn NIC theo bảng. LAN Segment chỉ tạo liên kết Ethernet; IP sẽ đặt trong hệ điều hành.

| Máy | NIC lab thứ nhất | NIC lab thứ hai | NIC NAT tạm |
| --- | --- | --- | --- |
| HQ-GW | WAN-Net: `172.16.1.10/24` | HQ-LAN-Net: `10.74.10.1/24` | Có, để tải gói |
| Branch-GW | WAN-Net: `172.16.1.20/24` | Branch-LAN-Net: `10.74.20.1/24` | Có, để tải gói |
| HQ-Server | HQ-LAN-Net: `10.74.10.50/24` | — | Có, để tải gói |
| Branch-PC | Branch-LAN-Net: `10.74.20.50/24` | — | Có, để tải gói/browser |
| Remote-PC | WAN-Net: `172.16.1.100/24` | — | Có nếu cần tải OpenVPN |

Hai subnet tunnel do OpenVPN tạo, **không tạo LAN Segment cho chúng**:

- C2S: `10.8.0.0/24`, HQ-GW là `10.8.0.1`; Windows nhận địa chỉ động `10.8.0.x`.
- S2S: `10.9.0.0/24`, HQ-GW là `10.9.0.1`, Branch-GW là `10.9.0.2`.

WAN-Net không phải Internet thật. NIC WAN của hai gateway và Windows không đặt default gateway/DNS. Giữ **NIC NAT tạm đến khi toàn bộ lệnh deploy hoàn tất**, vì `deploy-all.sh` vẫn gọi apt dù bạn đã cài gói trước đó. Khi nghiệm thu/demo, bỏ chọn **Connected** của NIC NAT trên cả năm VM; không xóa NIC để tránh thay đổi tên card.

## 3. Chuẩn bị chung trên bốn Armbian

### 3.1. Tài khoản, công cụ và repo

Đăng nhập bằng tài khoản thường có sudo. Trong lúc NAT còn hoạt động, trên **cả bốn Armbian** chạy:

```bash
whoami
sudo apt update
sudo apt install -y openssh-server openssh-client git nano open-vm-tools
sudo systemctl enable --now ssh
timedatectl
ip -br address
```

Đặt hostname tương ứng trên từng máy, ví dụ trên HQ-GW:

```bash
sudo hostnamectl set-hostname hq-gw
```

Các máy còn lại lần lượt là `branch-gw`, `hq-server`, `branch-pc`. Mở terminal mới để prompt cập nhật.

Chép **bản repo đang chỉnh sửa trong workspace hiện tại** từ máy host sang `~/vpn-lab` trên từng Armbian, bằng WinSCP qua SSH/NAT hoặc VMware Shared Folders. Các thay đổi chưa được commit/push sẽ không có trong bản clone từ GitHub. Xác nhận trên mỗi máy:

```bash
cd ~/vpn-lab
test -f scripts/deploy-all.sh && echo 'Da co repo lab'
```

Chỉ trên **Branch-PC GUI**, bổ sung tích hợp desktop nếu cần:

```bash
sudo apt install -y open-vm-tools-desktop xdg-utils
```

Mở thử trình duyệt có sẵn trong image. Nếu chưa có Firefox/Chromium, cài qua kho phần mềm của image khi còn Internet; chạy thử trước khi ngắt NAT. Repo không tự cài desktop hoặc browser.

### 3.2. Cài bộ gói theo vai trò

Từ `~/vpn-lab`, chạy đúng một lệnh theo từng máy:

```bash
# HQ-GW:
sudo bash scripts/common/install-prerequisites.sh gw

# Branch-GW:
sudo bash scripts/common/install-prerequisites.sh gw

# HQ-Server:
sudo bash scripts/common/install-prerequisites.sh server

# Branch-PC:
sudo bash scripts/common/install-prerequisites.sh pc
```

Danh sách do script cài:

| Nhóm | Gói |
| --- | --- |
| Tất cả vai trò | `iproute2 iputils-ping ca-certificates` |
| `gw` | `openvpn easy-rsa openssh-server openssh-client iptables iptables-persistent netfilter-persistent net-tools tcpdump traceroute curl chrony` |
| `server` | `nginx curl net-tools traceroute chrony` |
| `pc` | `net-tools traceroute curl chrony` |

Script đặt chế độ cài gói không tương tác và bước deploy sẽ thiết lập/lưu rules iptables của lab. Kiểm tra thời gian trên cả bốn máy; đợi đồng bộ qua NAT trước khi tạo và dùng chứng chỉ:

```bash
date -Is
chronyc tracking
```

Trên **hai gateway**, kiểm tra thiết bị TUN sau khi cài OpenVPN:

```bash
sudo modprobe tun
test -c /dev/net/tun && echo 'TUN san sang'
systemctl list-unit-files 'openvpn-server@*' 'openvpn-client@*'
```

Nếu không có `/dev/net/tun` hoặc template service, xử lý kernel/gói OpenVPN trước khi triển khai.

## 4. Đặt IP tĩnh cho từng máy

### 4.1. Nhận diện NIC và xử lý cấu hình mặc định

Trên mỗi Armbian chạy:

```bash
ip -br link
ip -br address
sudo ls -l /etc/netplan
sudo cat /etc/netplan/*.yaml
systemctl is-active systemd-networkd NetworkManager
```

Đối chiếu **MAC** từng NIC với VMware Settings → Network Adapter → Advanced. Ghi lại WAN/LAN/NAT. Ví dụ bên dưới giả định:

- Hai gateway: `ens33` = WAN, `ens37` = LAN, `ens39` = NAT.
- HQ-Server và Branch-PC: `ens33` = LAN, `ens37` = NAT.

**Thay mọi tên NIC trong ví dụ theo MAC thật.** NIC có số nhỏ hơn không đảm bảo là WAN.

Theo [tài liệu mạng Armbian](https://docs.armbian.com/user-guide/networking/), Minimal thường dùng `networkd`, image khác thường dùng NetworkManager. Kiểm tra renderer trong YAML và công cụ `networkctl`/`nmcli`; việc một service đang chạy chưa đủ kết luận NIC đang do service đó quản lý. Các ví dụ dưới dùng `networkd` cho ba Minimal và `NetworkManager` cho Desktop.

Thực hiện đổi mạng qua **console VMware**. Với VM mới dành riêng cho lab, sao lưu rồi chuyển YAML cũ ra khỏi thư mục Netplan để cấu hình DHCP mặc định (đặc biệt `10-dhcp-all-interfaces.yaml`) không chồng lên IP tĩnh:

```bash
LAB_BACKUP_DIR="/root/vpn-lab-backup/netplan-$(date +%Y%m%d-%H%M%S)"
sudo install -d -m 700 "$LAB_BACKUP_DIR"
for lab_file in /etc/netplan/*.yaml /etc/netplan/*.yml; do
    [ -f "$lab_file" ] || continue
    sudo mv -- "$lab_file" "$LAB_BACKUP_DIR/"
done
sudo nano /etc/netplan/20-vpn-lab.yaml
```

Dán **một** cấu hình đúng vai trò ở phần dưới. Các ví dụ có cả NIC NAT DHCP để tiếp tục cài gói. Không thực hiện thay toàn bộ YAML này trên máy đang phục vụ mạng khác.

Nếu NetworkManager còn profile cũ ngoài Netplan tự bật DHCP trên NIC lab, kiểm tra `nmcli connection show` và `nmcli device status`; tắt autoconnect đúng profile cũ bằng `sudo nmcli connection modify uuid <UUID-cu> connection.autoconnect no`. Chỉ down profile cũ sau khi đã xác định đúng NIC và có console; giữ profile NAT cho đến khi cấu hình mới hoạt động.

### 4.2. HQ-GW — `/etc/netplan/20-vpn-lab.yaml`

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:
      dhcp4: false
      dhcp6: false
      addresses: [172.16.1.10/24]
    ens37:
      dhcp4: false
      dhcp6: false
      addresses: [10.74.10.1/24]
    ens39:
      dhcp4: true
      dhcp6: false
      dhcp4-overrides:
        route-metric: 50
```

### 4.3. Branch-GW — `/etc/netplan/20-vpn-lab.yaml`

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
      addresses: [10.74.20.1/24]
    ens39:
      dhcp4: true
      dhcp6: false
      dhcp4-overrides:
        route-metric: 50
```

### 4.4. HQ-Server — `/etc/netplan/20-vpn-lab.yaml`

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:
      dhcp4: false
      dhcp6: false
      addresses: [10.74.10.50/24]
      routes:
        - to: default
          via: 10.74.10.1
          metric: 200
        - to: 10.74.20.0/24
          via: 10.74.10.1
        - to: 10.9.0.0/24
          via: 10.74.10.1
    ens37:
      dhcp4: true
      dhcp6: false
      dhcp4-overrides:
        route-metric: 50
```

### 4.5. Branch-PC — `/etc/netplan/20-vpn-lab.yaml`

```yaml
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    ens33:
      dhcp4: false
      dhcp6: false
      addresses: [10.74.20.50/24]
      routes:
        - to: default
          via: 10.74.20.1
          metric: 200
        - to: 10.74.10.0/24
          via: 10.74.20.1
        - to: 10.9.0.0/24
          via: 10.74.20.1
    ens37:
      dhcp4: true
      dhcp6: false
      dhcp4-overrides:
        route-metric: 50
```

NAT có default route metric 50 để tải Internet trong giai đoạn chuẩn bị. Route cụ thể tới LAN bên kia và tunnel S2S trên hai máy đầu cuối luôn đi qua gateway lab, kể cả khi NAT còn bật. Khi ngắt NAT, default route metric 200 qua gateway lab vẫn còn; mô hình này không cấu hình Internet breakout qua VPN.

### 4.6. Áp dụng và khai báo NIC cho script

Trên **từng Armbian**, sau khi lưu YAML:

```bash
sudo chmod 600 /etc/netplan/20-vpn-lab.yaml
sudo netplan generate
sudo netplan try
# Khi mạng đúng, nhấn Enter trong thời hạn xác nhận.
ip -br address
ip route
```

Nếu `netplan try` không hỗ trợ trên image/backend đang dùng, xem lỗi rồi áp dụng bằng `sudo netplan apply` tại console VMware và kiểm tra ngay; dùng bản sao lưu nếu cấu hình sai.

Trên **cả HQ-GW và Branch-GW**, lưu tên NIC thật để script firewall/NAT/capture dùng chung:

```bash
sudo install -d -m 755 /etc/vpn-lab
sudo tee /etc/vpn-lab/interfaces.conf >/dev/null <<'EOF'
WAN_IF=ens33
LAN_IF=ens37
EOF
sudo chmod 644 /etc/vpn-lab/interfaces.conf
```

Hai dòng này chỉ khai báo NIC cho script, không thay thế Netplan. Trên HQ-GW thử `ping -c 3 172.16.1.20`; trên HQ-Server thử `ping -c 3 10.74.10.1`; trên Branch-PC thử `ping -c 3 10.74.20.1`. Chưa có VPN thì chưa yêu cầu ping được LAN bên kia.

### 4.7. Windows Remote-PC

1. Mở `ncpa.cpl`, xác định adapter WAN-Net bằng MAC trong VMware; có thể đổi tên adapter thành `WAN-Lab` để dễ nhận diện.
2. IPv4 thủ công: IP `172.16.1.100`, subnet mask `255.255.255.0`, **để trống gateway và DNS trên NIC lab**. NIC NAT tạm tiếp tục DHCP đến lúc tải xong phần mềm.
3. Cài OpenVPN Community x64 kèm GUI/driver theo [hướng dẫn Windows](../technical-guides/08-windows-client-requirements.md). Không cần chạy Bash/script gateway trên Windows.
4. Trong PowerShell chạy `ping -n 3 172.16.1.10`. Nếu muốn checklist ping từ gateway tới Windows cũng chạy được, thêm rule ICMP phạm vi lab bằng PowerShell **Run as administrator**:

```powershell
New-NetFirewallRule -DisplayName 'VPN Lab ICMP from gateways' -Direction Inbound -Protocol ICMPv4 -IcmpType 8 -LocalAddress 172.16.1.100 -RemoteAddress 172.16.1.10,172.16.1.20 -Action Allow -Profile Any
```

Rule này phục vụ kiểm tra ping, không phải điều kiện bắt buộc để OpenVPN client kết nối ra ngoài.

## 5. Triển khai theo thứ tự từng máy

Giữ NAT tạm trong toàn bộ phần này. Mỗi terminal Bash bắt đầu bằng `cd ~/vpn-lab`. Không chạy lệnh của nhiều vai trò trên cùng một VM.

### Bước 1 — HQ-Server: dựng web nội bộ

Trên **HQ-Server**:

```bash
cd ~/vpn-lab
sudo bash scripts/deploy-all.sh hq-server
sudo systemctl is-active nginx
sudo bash scripts/verify-portal.sh
curl --noproxy '*' --max-time 5 http://10.74.10.50/api/identity
```

Script chép Portal của repo vào `/var/www/vpn-lab-portal`, cấu hình Nginx chỉ nghe HQ LAN và loopback, rồi khởi động dịch vụ. Dùng VM lab riêng và kiểm tra các virtual host cũ không còn nghe wildcard trên NIC NAT. Kỳ vọng Nginx `active`, HTTP thành công, API trả JSON. Đây mới là kiểm tra web tại HQ; chưa chứng minh VPN hoạt động.

### Bước 2 — HQ-GW: dựng CA và hai OpenVPN server

Trên **HQ-GW**:

```bash
cd ~/vpn-lab
sudo bash scripts/deploy-all.sh hq-gw
sudo systemctl is-active openvpn-server@server-c2s openvpn-server@server-s2s
sysctl net.ipv4.ip_forward
sudo ss -lunp 'sport = :1194 or sport = :1195'
ip -br address show tun0
ip -br address show tun1
ls -l ~/client1.ovpn
```

Lần đầu tạo DH/khóa có thể mất vài phút; làm trước giờ trình diễn. Script thực hiện:

- Cài gói, dừng/tắt tự khởi động IPsec/strongSwan của lab cũ nếu có.
- Bật IPv4 forwarding và cài rules chuyển tiếp/NAT của repo.
- Tạo PKI mặc định ở `~/openvpn-ca` của tài khoản gọi sudo, sinh chứng chỉ server và hai client.
- Xuất `~/client1.ovpn`, chạy C2S trên UDP **1194**, S2S trên UDP **1195**.

Các file hoạt động: `/etc/openvpn/server/server-c2s.conf`, `/etc/openvpn/server/server-s2s.conf`, `/etc/openvpn/ccd/branch-gw`. Kỳ vọng forwarding là `1`, hai service `active`, HQ có `tun0=10.8.0.1` và `tun1=10.9.0.1`. Trạng thái `active` lúc này chưa chứng minh có client kết nối.

### Bước 3 — HQ-GW: chuyển chứng chỉ sang Branch-GW

Branch-GW phải có SSH hoạt động từ bước chuẩn bị. Trên **HQ-GW**, thay `student` nếu Branch dùng tài khoản khác:

```bash
cd ~/vpn-lab
sudo env BRANCH_USER=student bash scripts/pki/distribute-certs.sh branch-gw 172.16.1.20
```

Lần đầu xác nhận SSH host key sau khi đối chiếu đúng VM; nhập mật khẩu SSH/sudo nếu được hỏi. Script chuyển `ca.crt`, `ta.key`, `branch-gw.crt`, `branch-gw.key` vào `/etc/openvpn/client` trên Branch. Không gửi khóa CA riêng.

### Bước 4 — Branch-GW: kết nối Site-to-Site

Trên **Branch-GW**:

```bash
cd ~/vpn-lab
sudo bash scripts/deploy-all.sh branch-gw
sudo systemctl is-active openvpn-client@client-s2s
sudo journalctl -u openvpn-client@client-s2s -n 40 --no-pager
ip -br address show tun0
ip route get 10.74.10.50
sudo bash scripts/verify-s2s.sh branch-gw
```

Kỳ vọng log có `Initialization Sequence Completed`, tunnel Branch là `10.9.0.2`, route tới HQ-LAN đi qua tunnel, ping/HTTP nội bộ hoạt động. File client đang chạy là `/etc/openvpn/client/client-s2s.conf`.

Trên **HQ-GW** kiểm tra chiều ngược:

```bash
cd ~/vpn-lab
sudo bash scripts/verify-s2s.sh hq-gw
sudo journalctl -u openvpn-server@server-s2s -n 40 --no-pager
```

HQ phải thấy `branch-gw` xác thực thành công; CCD gán IP tunnel `10.9.0.2` và `iroute` cho `10.74.20.0/24`.

### Bước 5 — Branch-PC GUI: kiểm tra từ máy người dùng

Trên **Branch-PC**:

```bash
cd ~/vpn-lab
sudo bash scripts/deploy-all.sh branch-pc
ip route get 10.74.10.50
ping -c 3 10.74.10.50
curl --noproxy '*' --max-time 5 http://10.74.10.50/api/identity
xdg-open http://10.74.10.50
```

Kỳ vọng route của Branch-PC dùng `via 10.74.20.1`, browser hiển thị Portal. Nginx dự kiến quan sát nguồn `10.74.20.50` vì S2S hiện tại giữ nguyên IP LAN. Branch-PC dùng gateway để đi VPN, không cần import `.ovpn`.

Trên **HQ-Server**, xác nhận thông hai chiều:

```bash
ip route get 10.74.20.50
ping -c 3 10.74.20.50
```

### Bước 6 — Windows: nhận profile và kết nối Client-to-Site

Chép **chỉ** `~/client1.ovpn` từ HQ-GW sang Windows bằng WinSCP, SCP nếu có OpenSSH Client, hoặc Shared Folders. Profile chứa khóa riêng client, không đăng công khai.

Trên **Windows Remote-PC**:

1. Mở OpenVPN GUI, dùng **Import file** để nhập `client1.ovpn`.
2. Ở system tray, chọn profile `client1` → **Connect**; chờ Connected và log `Initialization Sequence Completed`.
3. Mở PowerShell và kiểm tra:

```powershell
ipconfig
route print -4
ping -n 3 10.8.0.1
ping -n 3 10.74.10.50
Test-NetConnection 10.74.10.50 -Port 80
Invoke-WebRequest -UseBasicParsing -Method Head -Uri http://10.74.10.50 -TimeoutSec 5
Start-Process http://10.74.10.50
```

Kỳ vọng Windows có IP tunnel `10.8.0.x` và route `10.74.10.0/24`; không yêu cầu địa chỉ phải là `10.8.0.2`. Web trả HTTP 200. C2S hiện dùng NAT tại HQ-GW nên Portal dự kiến thấy nguồn **`10.74.10.1`**, không phải IP tunnel Windows. Profile hiện chỉ đẩy route vào HQ-LAN, không dùng truy cập Branch-LAN làm tiêu chí C2S.

Trên **HQ-GW**:

```bash
cd ~/vpn-lab
sudo bash scripts/verify-c2s.sh server
sudo journalctl -u openvpn-server@server-c2s -n 40 --no-pager
```

## 6. Nghiệm thu sau khi ngắt NAT

1. Trong VMware, bỏ chọn **Connected** của NIC NAT tạm trên cả năm VM. Giữ nguyên NIC nối LAN Segment và không đổi MAC.
2. Trên bốn Armbian xem `ip -br address` và `ip route`; route tới hai LAN phải vẫn đúng. Trên Windows xem `route print -4`, bảo đảm không có card khác nối trực tiếp HQ-LAN/Branch-LAN.
3. Khi Windows đang Connect, chạy lại HTTP từ Windows và Branch-PC. HQ-Server ping lại Branch-PC. Trên hai gateway chạy lại `verify-s2s.sh` đúng vai trò.
4. Có thể chạy `sudo bash scripts/common/verify-phase1.sh <vai-tro>` trên mỗi Armbian với một trong `hq-gw`, `branch-gw`, `hq-server`, `branch-pc`. Nếu riêng ping tới Windows thất bại, kiểm tra rule ICMP Windows trước khi kết luận VPN lỗi.
5. Windows **Disconnect**, thử HTTP bằng lệnh dưới. Dự kiến timeout/lỗi trong mô hình cô lập. Nếu vẫn thành công, kiểm tra adapter, proxy và route, không chuyển sang phần trình diễn với kết quả sai.

```powershell
Invoke-WebRequest -UseBasicParsing -Method Head -Uri http://10.74.10.50 -TimeoutSec 3
```

Ghi kết quả thực vào [checklist nghiệm thu](../../tests/openvpn-demo.md); chưa chạy VM thì không ghi PASS. Lưu snapshot sau khi hệ thống đã được kiểm tra. Firewall mới dùng chain FORWARD kết thúc bằng DROP và chặn WAN vào địa chỉ LAN/tunnel; cần chạy thêm phép thử route tự thêm và ngắt S2S trong checklist để xác minh trên VM.

## 7. Kịch bản trình diễn 8–10 phút

### Chuẩn bị màn hình trước khi bắt đầu

- Bật cả năm VM; tắt NIC NAT tạm.
- HQ-GW: hai terminal cho trạng thái và bắt gói; `cd ~/vpn-lab` rồi `sudo -v` trên từng terminal.
- Branch-PC: terminal và browser. HQ-Server/Branch-GW để sẵn console khi cần giải thích hoặc xử lý lỗi.
- Windows: PowerShell, OpenVPN GUI, browser; ban đầu **Disconnect**.
- Kiểm tra sẵn ba service VPN và Nginx. Không tạo lại CA, cài apt hoặc reboot VM trong phần trình diễn chính.

### Cảnh 1 — Giới thiệu mô hình (45 giây)

**Nói:** “Mô hình gồm hai mạng LAN độc lập và một WAN giả lập. Ba Armbian không GUI làm hai gateway và một web server. Armbian có GUI là máy chi nhánh, Windows là nhân viên từ xa. Hai kiểu kết nối đều dùng OpenVPN.”

Chỉ vào ba LAN Segment, IP gateway và server. Nêu UDP 1194 cho Windows → HQ, UDP 1195 cho Branch-GW → HQ. Không cần mở mọi file cấu hình.

### Cảnh 2 — Windows chưa kết nối VPN (30 giây)

Trên **Windows**, xác nhận OpenVPN GUI đang Disconnect, rồi chạy:

```powershell
ping -n 2 172.16.1.10
Invoke-WebRequest -UseBasicParsing -Method Head -Uri http://10.74.10.50 -TimeoutSec 3
```

**Kỳ vọng:** ping tới WAN của HQ được, HTTP tới LAN HQ lỗi/timeout. **Nói:** “Máy đã liên lạc được địa chỉ WAN của gateway nhưng chưa có đường VPN vào web nội bộ.” Dùng lệnh HTTP mới để tránh nhầm với trang browser đã cache.

### Cảnh 3 — Bật C2S và mở web (2 phút)

Trên **Windows**, chọn `client1` → Connect, chờ log thành công. Chạy:

```powershell
ipconfig
route print -4
Test-NetConnection 10.74.10.50 -Port 80
Start-Process http://10.74.10.50
```

Chỉ IP `10.8.0.x`, route HQ-LAN và Portal đang hoạt động. Trên **HQ-GW** hiển thị client từ xa trong log/status:

```bash
sudo journalctl -u openvpn-server@server-c2s -n 25 --no-pager
sudo cat /var/log/openvpn/openvpn-c2s-status.log
```

Status file có thể cập nhật trễ; nếu chưa thấy client, chờ chu kỳ cập nhật và đối chiếu log cùng HTTP thực tế. **Nói:** “OpenVPN xác thực bằng chứng chỉ, tạo tunnel và thêm route tới HQ. Với cấu hình NAT của lab, web server thấy địa chỉ LAN của HQ-GW.”

### Cảnh 4 — S2S từ máy chi nhánh (2 phút)

Chuyển sang **Branch-PC GUI**:

```bash
ip route get 10.74.10.50
ping -c 3 10.74.10.50
curl --noproxy '*' --max-time 5 http://10.74.10.50/api/identity
xdg-open http://10.74.10.50
```

Chỉ next hop `10.74.20.1` và địa chỉ nguồn quan sát `10.74.20.50` trong API/Portal. Trên **HQ-Server**, ping `10.74.20.50` để thể hiện chiều ngược. Nếu cần, mở log Branch-GW có tunnel `10.9.0.2`.

**Nói:** “Máy chi nhánh gửi gói cho Branch-GW. Hai gateway vận chuyển lưu lượng LAN qua tunnel S2S; máy người dùng chỉ dùng gateway bình thường.”

### Cảnh 5 — Bắt gói WAN và LAN (2–3 phút)

Trên **HQ-GW**, mở hai terminal tại `~/vpn-lab`. Terminal thứ nhất:

```bash
source scripts/common/lab-network.sh
sudo bash scripts/capture-traffic.sh -i "$WAN_IF" -m openvpn-s2s -c 20 -o demo-openvpn-wan.pcap
```

Terminal thứ hai:

```bash
source scripts/common/lab-network.sh
sudo bash scripts/capture-traffic.sh -i "$LAN_IF" -m lan-http -c 20 -o demo-http-lan.pcap
```

Đợi cả hai báo `listening`, rồi trên **Branch-PC** phát sinh lưu lượng:

```bash
curl --noproxy '*' --connect-timeout 3 --max-time 20 -o /dev/null http://10.74.10.50/files/benchmark-payload-1mb.dat
```

Nếu chưa đủ 20 gói, tải lại hoặc nhấn Ctrl+C sau khi đã thu được lưu lượng. PCAP lưu ở `tests/captures/samples/` trong repo HQ-GW. Đọc ngay trên HQ:

```bash
sudo tcpdump -nn -r tests/captures/samples/demo-openvpn-wan.pcap
sudo tcpdump -nn -A -r tests/captures/samples/demo-http-lan.pcap -c 10
```

Cần thấy gói thật trong cả hai file, không chỉ thông báo tạo file. Có thể chép PCAP sang Windows để xem bằng Wireshark, dùng filter `udp.port == 1195` cho WAN và `http` hoặc `tcp.port == 80` cho LAN. Chuẩn bị sẵn cách chuyển file trước khi ngắt NAT, chẳng hạn Shared Folders; sau Connect C2S cũng có thể SCP tới IP HQ-GW nếu SSH và driver client đã hoạt động.

**Nói:** “Trên WAN, chúng ta quan sát UDP giữa hai gateway; payload gốc được OpenVPN bảo vệ. Sau giải mã tại HQ-GW, HTTP đi vào LAN tới web server nên đọc được trên NIC LAN. Địa chỉ và cổng ngoài tunnel vẫn nhìn thấy được.” Đối chiếu cipher đã thương lượng trong log OpenVPN; chỉ nhìn thấy UDP hoặc không thấy chuỗi HTTP trong một mẫu bắt gói chưa đủ tự chứng minh thuật toán mã hóa.

### Cảnh 6 — Ngắt C2S và kết thúc (45 giây)

Trên **Windows**, Disconnect rồi chạy lại HTTP với timeout 3 giây; dự kiến lỗi. Trên **Branch-PC**, chạy lại `curl` API; dự kiến vẫn thành công vì S2S là kết nối riêng.

**Nói:** “Nhân viên từ xa truy cập qua C2S, còn chi nhánh truy cập qua S2S giữa hai gateway. Hai đường kết nối hoạt động độc lập; demo kiểm tra bằng route, log, truy cập web và bắt gói.”

## 8. Bằng chứng cần lưu và xử lý lỗi tại chỗ

Lưu ảnh hoặc đầu ra thực tế: topology VMware; IP/route Windows trước và sau Connect; log C2S/S2S thành công; Portal từ hai máy người dùng; ping hai chiều S2S; PCAP WAN/LAN. Ghi thời điểm kiểm tra, phiên bản image/OpenVPN và kết quả vào checklist. Không dùng số RTT/tốc độ ước lượng làm kết quả đo.

| Triệu chứng | Kiểm tra trên máy nào | Cách khoanh vùng |
| --- | --- | --- |
| apt không tải được | Armbian đang cài | NAT còn Connected, DHCP/default route metric 50, DNS; chưa ngắt NAT khi còn deploy |
| Hai gateway không ping WAN | HQ-GW và Branch-GW | Cùng WAN-Net, MAC đúng NIC, IP/mask, Connected; chưa sửa VPN khi WAN chưa thông |
| IP tĩnh bị trộn DHCP | Armbian gặp lỗi | YAML catch-all cũ và profile NetworkManager cũ; không chồng hai cấu hình lên NIC lab |
| Windows không kết nối C2S | Windows và HQ-GW | Log GUI, giờ hệ thống, profile `client1`, remote `172.16.1.10:1194`, UDP listener/firewall, chứng chỉ |
| Branch-GW không tạo tunnel | Branch-GW và HQ-GW | `journalctl`, giờ hệ thống, bốn file cert/key đã chuyển, remote UDP 1195; không sao chép profile C2S cho S2S |
| Tunnel lên nhưng web lỗi | Máy truy cập, hai gateway, HQ-Server | `ip route get`, forwarding, rules iptables, route trả về của HQ-Server, `systemctl status nginx`, `curl` cục bộ |
| Chỉ gateway ping được, PC không được | HQ-Server và Branch-PC | Gateway mặc định và route cụ thể hai LAN; tên NIC; firewall trên đầu cuối |
| GUI browser lỗi nhưng curl được | Branch-PC hoặc Windows | URL dùng IP, proxy/browser cache; tắt proxy cho subnet lab; không suy ra VPN lỗi ngay |
| Capture trống hoặc chờ mãi | HQ-GW | NIC trong `interfaces.conf`, đúng mode/port, đã đợi `listening`, tạo lưu lượng từ Branch-PC; đọc lại PCAP |
| Service báo active nhưng chưa truy cập được | Gateway tương ứng | Xem handshake, tunnel, route và lưu lượng thực; `active` không đồng nghĩa client đã nối |

Lệnh xem lỗi thường dùng trên đúng máy:

```bash
ip -br address
ip route
sysctl net.ipv4.ip_forward
sudo iptables -S
sudo iptables -t nat -S
sudo journalctl -u openvpn-server@server-c2s -n 60 --no-pager
sudo journalctl -u openvpn-server@server-s2s -n 60 --no-pager
sudo journalctl -u openvpn-client@client-s2s -n 60 --no-pager
```

Chỉ chạy dòng journal của service có trên máy đang kiểm tra. Nếu phải sửa khi demo, ưu tiên xác định lỗi theo lớp WAN → tunnel → route/forwarding → HTTP, rồi chạy lại đúng kiểm tra đã thất bại. Không tạo lại CA hoặc thu hồi `client1` giữa bài demo chính.
