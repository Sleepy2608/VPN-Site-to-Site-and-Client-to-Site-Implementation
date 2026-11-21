# Lab VMware: 3 Armbian không GUI, 1 Armbian có GUI và 1 Windows

Để triển khai theo từng VM, bắt đầu tại [bộ hướng dẫn 5 máy](../deployment/README.md), gồm chuẩn bị chung, cấu hình đầy đủ mỗi máy và thứ tự nghiệm thu.

Xem [kịch bản triển khai và demo chi tiết](../presentation/detailed-lab-runbook.md) để có cấu hình Netplan đầy đủ cho từng máy, kể cả NIC NAT tạm và route trong giai đoạn cài gói, cùng thứ tự chạy lệnh và lời dẫn trình diễn.

## 1. Phân vai và chọn image

| VM | Hệ điều hành | Chức năng | NIC lab |
| --- | --- | --- | --- |
| HQ-GW | Armbian Minimal/CLI, không GUI | OpenVPN C2S + S2S, Easy-RSA CA | WAN + HQ LAN |
| Branch-GW | Armbian Minimal/CLI, không GUI | OpenVPN S2S client, định tuyến | WAN + Branch LAN |
| HQ-Server | Armbian Minimal/CLI, không GUI | Nginx, Portal và tệp demo | HQ LAN |
| Branch-PC | Armbian Desktop, có GUI | Ping, trình duyệt truy cập Portal qua S2S | Branch LAN |
| Remote-PC | Windows 10/11 x64 | OpenVPN GUI truy cập HQ qua C2S | WAN |

Hướng dẫn giả định VMware Workstation trên máy Intel/AMD x86_64. Dùng **Armbian Generic UEFI x86/x86_64**, firmware VM chọn UEFI. Không dùng image dành cho Orange Pi/Raspberry Pi/ARM board để boot trên VM x86. Armbian có [Generic UEFI x86](https://armbian.com/boards/uefi-x86) và extension [vmware-vm](https://docs.armbian.com/build-framework/extensions/list/#vmware-vm) tạo OVF/VMDK kèm open-vm-tools; không mặc định mọi file tải về đều là ISO hoặc VM VMware sẵn dùng.

Chọn image Debian/Ubuntu-based còn được Armbian hỗ trợ, có systemd và OpenVPN 2.5 trở lên; ghi chính xác image/base/version đã dùng. Nên dùng cùng base/release cho cả 4 VM, chọn Minimal/CLI cho 3 server và Desktop cho Branch-PC. Repo không tự cài hệ điều hành và chưa được chạy thử trên image cụ thể của người dùng.

Gợi ý phân bổ lab: gateway 1–2 vCPU/1–2 GB RAM, HQ-Server 1 vCPU/1 GB, Branch-PC GUI 2 vCPU/2–4 GB; Windows theo [hướng dẫn riêng](08-windows-client-requirements.md). Điều chỉnh theo desktop/image và tài nguyên host. Nếu clone, tạo MAC/hostname riêng và kiểm tra machine-id/SSH host keys, không giữ định danh máy trùng nhau.

## 2. Ba LAN Segment trên VMware

Tạo `WAN-Net`, `HQ-LAN-Net`, `Branch-LAN-Net` và gán NIC theo bảng. Đây là LAN Segment cô lập; VMware NAT thông thường không thay thế ba phân vùng này.

| Node | IP lab | Default gateway lab |
| --- | --- | --- |
| HQ-GW | WAN `172.16.1.10/24`, LAN `10.74.10.1/24` | Không có trên WAN giả lập |
| Branch-GW | WAN `172.16.1.20/24`, LAN `10.74.20.1/24` | Không có trên WAN giả lập |
| HQ-Server | `10.74.10.50/24` | `10.74.10.1` |
| Branch-PC GUI | `10.74.20.50/24` | `10.74.20.1` |
| Windows Remote-PC | `172.16.1.100/24` | Không có trên WAN giả lập |

Thêm NIC NAT **tạm thời trên từng VM cần tải gói**. Giữ tới khi deploy xong, sau đó ngắt kết nối NIC NAT trước demo. Giữ nguyên MAC/vị trí NIC lab sau khi khai báo tên card. Không nối Windows vào LAN HQ/Branch; không nối Branch-PC trực tiếp vào HQ LAN.

## 3. Kiểm tra Armbian và tên card

Trên từng Armbian, dùng console VMware:

```bash
uname -m
cat /etc/armbian-release
cat /etc/os-release
ip -br link
ip -br addr
systemctl is-active NetworkManager
systemctl is-active systemd-networkd
networkctl list
command -v nmcli && nmcli device status
ls /etc/netplan
```

Image Generic x86_64 phải báo `x86_64`. Đối chiếu MAC từng NIC với VMware để xác định WAN/LAN/NAT; các tên `ens33`, `ens37` bên dưới chỉ là ví dụ, không gán theo tên đoán.

Armbian từ 24.05 dùng Netplan cho các loại image. **Minimal** mặc định dùng `networkd`, còn **standard CLI và Desktop** có thể dùng `NetworkManager`. Hai dịch vụ có thể cùng hoạt động; đối chiếu renderer trong YAML và trạng thái quản lý của từng NIC qua networkctl/nmcli, không chỉ dựa vào is-active hoặc có/không GUI. Xem [tài liệu networking Armbian](https://docs.armbian.com/user-guide/networking/).

## 4. IP tĩnh và backend mạng

Chép repo vào cả 4 Armbian. Cài prerequisite đúng role khi NAT còn có Internet theo [README](../../README.md), rồi chuẩn bị Netplan theo từng node:

Nếu image chưa có tích hợp VMware, có thể cài `sudo apt install open-vm-tools`; riêng Branch-PC đã có desktop có thể cài thêm `open-vm-tools-desktop` từ kho của image khi còn Internet. Không cần thêm desktop vào ba node CLI.

- Chọn mẫu cùng vai trò trong `configs/netplan/`.
- Đổi khóa `eth0`/`eth1` sang **tên NIC thực tế**. Trên host chỉ có LAN, đổi `eth0` thành NIC LAN.
- Minimal dùng `renderer: networkd`; Desktop/CLI đang được NetworkManager quản lý dùng `renderer: NetworkManager`. Mẫu Branch-PC được đặt NetworkManager cho VM GUI.
- Kiểm tra tất cả Netplan và connection NetworkManager hiện có. Armbian có thể có `/etc/netplan/10-dhcp-all-interfaces.yaml` dùng match `e*`, chồng lên NIC lab. Sao lưu và chuyển tệp mặc định xung đột ra ngoài thư mục YAML được nạp trước khi áp dụng IP tĩnh; không áp dụng đè qua SSH đang dùng card đó.
- Nếu vẫn cần NAT để deploy, **khai báo NIC NAT riêng với DHCP trong YAML đang giữ lại**. Khi bỏ DHCP catch-all, NAT sẽ không tự có IP nếu không được khai báo riêng.

Ví dụ thêm dưới `network.ethernets` (thay `ens39` bằng NIC NAT thực tế):

```yaml
    ens39:
      dhcp4: true
      dhcp6: false
```

Sau khi chỉnh mẫu và xử lý cấu hình trùng, chạy trên console từng VM:

```bash
# Ví dụ HQ-GW; chọn mẫu khác tương ứng trên mỗi node:
sudo cp configs/netplan/01-netcfg-hq-gw.yaml /etc/netplan/20-vpn-lab.yaml
sudo chmod 600 /etc/netplan/20-vpn-lab.yaml
sudo netplan generate
sudo netplan try
ip -br addr
ip route
```

Kiểm tra kết nối WAN/LAN đúng địa chỉ, Internet qua NAT còn dùng được cho bước deploy. Trên Windows dùng `ncpa.cpl`, không dùng Netplan.

## 5. Khai báo NIC cho các script gateway

Thực hiện **trên cả HQ-GW và Branch-GW**, dùng tên NIC của từng máy. File này chỉ cấu hình script, không đặt IP hoặc tự đổi tên card:

```bash
sudo install -d -m 755 /etc/vpn-lab
sudo tee /etc/vpn-lab/interfaces.conf >/dev/null <<'EOF'
WAN_IF=ens33
LAN_IF=ens37
EOF
sudo chmod 644 /etc/vpn-lab/interfaces.conf
```

Không copy nguyên ví dụ nếu MAC/NIC thực tế khác. File chỉ nhận hai khóa WAN_IF/LAN_IF, giá trị là tên card không có dấu nháy/space. Script hỗ trợ biến môi trường WAN_IF/LAN_IF để override; nếu không có file/override thì dùng eth0/eth1 để tương thích mẫu cũ.

Firewall OpenVPN, NAT C2S, script deploy C2S/S2S, verify NAT và capture WAN đọc file chung này. Chúng không tự sửa các luật cũ gắn với tên NIC khác; khi đổi NIC của lab đã triển khai, kiểm tra và xử lý riêng luật iptables cũ rồi triển khai lại. Chọn tên NIC đúng ngay từ đầu là quy trình demo chính.

## 6. Triển khai và demo

Thực hiện các bước `deploy-all.sh hq-gw`, phân phối cert sang Branch, `deploy-all.sh branch-gw`, `hq-server`, `branch-pc` theo [README](../../README.md). Armbian dùng apt/systemd; không cần GUI trên hai gateway hoặc HQ-Server. Script không tự thêm/xóa desktop.

Trước deploy gateway, kiểm tra TUN (`ls -l /dev/net/tun`; nếu thiếu thì kiểm tra kernel/module tun) và các unit `openvpn-server@.service`, `openvpn-client@.service` sau khi cài OpenVPN. Nếu image không có các thành phần này, xử lý image/kernel/package trước khi kết luận tương thích.

Branch-PC GUI có thể cài browser/open-vm-tools-desktop từ kho của đúng image khi còn Internet; mở Portal bằng browser hoặc `xdg-open http://10.74.10.50`. Phần GUI chỉ phục vụ trình diễn, không phải VPN client S2S.

Ngắt NAT tạm, kiểm tra lại route rồi dùng [kịch bản 6–8 phút](../presentation/demo-script.md): Windows C2S, Branch-PC GUI S2S, capture WAN/LAN trên HQ-GW. Ghi [checklist](../../tests/openvpn-demo.md) và image/base/version thật trước khi đánh dấu PASS.
