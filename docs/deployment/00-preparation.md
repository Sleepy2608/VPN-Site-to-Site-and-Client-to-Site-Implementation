# Chuẩn bị chung cho năm máy

Thực hiện phần này trước khi làm hướng dẫn riêng của mỗi máy. Mô hình dùng IPv4 trong ba mạng VMware cô lập, kèm NIC NAT tạm để tải gói. Các ví dụ cấu hình mạng chỉ áp dụng cho VM dành riêng cho lab.

## 1 Chuẩn bị máy ảo

| Máy | vCPU gợi ý | RAM gợi ý | Đĩa gợi ý | NIC khi chuẩn bị |
| --- | --- | --- | --- | --- |
| HQ-GW | 2 | 2 GB | 20 GB | WAN-Net, HQ-LAN-Net, NAT tạm |
| Branch-GW | 2 | 2 GB | 20 GB | WAN-Net, Branch-LAN-Net, NAT tạm |
| HQ-Server | 1–2 | 1–2 GB | 20 GB | HQ-LAN-Net, NAT tạm |
| Branch-PC | 2 | 3–4 GB | 24 GB | Branch-LAN-Net, NAT tạm |
| Remote-PC | Theo yêu cầu bản Windows đã chọn | Theo yêu cầu bản Windows đã chọn | Theo yêu cầu bản Windows đã chọn | WAN-Net, NAT tạm |

Các mức Linux là gợi ý phân bổ cho lab. Với Armbian trên máy host Intel/AMD, dùng image Generic UEFI x86_64 đúng loại đĩa/ISO, firmware VM UEFI; xem [chuẩn bị Armbian](../technical-guides/09-armbian-vmware-guide.md). Chọn Minimal cho ba máy server và Desktop cho Branch-PC. Có thể giữ Linux Ubuntu/Debian đã cài nếu có apt, systemd, Netplan và OpenVPN từ 2.5; kiểm tra backend mạng trước khi dùng mẫu.

Ưu tiên Windows 11 x64 còn được hỗ trợ; nếu sử dụng Windows khác, đối chiếu [yêu cầu Windows](../technical-guides/08-windows-client-requirements.md). Không cần cài GUI trên các gateway và HQ-Server.

## 2 Tạo mạng trên VMware

Phần này thao tác trên **Windows host đang mở VMware Workstation Pro**. Hoàn thành cách nối mạng của cả năm VM trước khi sang phần cài gói và đặt IP trong guest. Vị trí hoặc tên nút có thể khác nhẹ giữa các phiên bản Workstation.

### 2.1 Hiểu ba mạng cần tạo

Ta tạo ba switch ảo bằng **LAN Segment**. Tên `WAN-Net` chỉ có nghĩa là WAN giả lập giữa ba VM, không phải đường Internet. NIC loại NAT là card bổ sung riêng để tải gói.

| LAN Segment | Subnet sẽ đặt trong hệ điều hành | NIC nối vào |
| --- | --- | --- |
| WAN-Net | 172.16.1.0/24 | WAN HQ-GW, WAN Branch-GW, WAN Windows |
| HQ-LAN-Net | 10.74.10.0/24 | LAN HQ-GW, HQ-Server |
| Branch-LAN-Net | 10.74.20.0/24 | LAN Branch-GW, Branch-PC |

Trong cách LAN Segment, **không nhập subnet/IP ở VMware**; ta sẽ đặt IP tĩnh bằng Netplan hoặc IPv4 Properties ở các hướng dẫn từng máy. Cũng không tạo LAN Segment cho `10.8.0.0/24` hoặc `10.9.0.0/24`: OpenVPN tự tạo mạng tunnel.

### 2.2 Tắt máy ảo trước khi thêm card

1. Trong từng VM đang chạy, shutdown hệ điều hành bình thường.
2. Kiểm tra trạng thái VM trong VMware là **Powered off**, không phải Suspended.
3. Nếu có VM chưa cài hệ điều hành, có thể để VM ở trạng thái tắt sẵn.
4. Mở cửa sổ chính VMware, nhìn danh sách **Library** bên trái và xác định đúng năm VM: HQ-GW, Branch-GW, HQ-Server, Branch-PC, Remote-PC.

Không cần tắt Windows host. Việc tắt năm VM giúp chỉnh phần cứng/card mạng rõ ràng; các NIC vẫn có thể giữ nguyên sau khi cấu hình xong.

### 2.3 Tạo ba LAN Segment một lần

Thực hiện từ VM **HQ-GW**:

1. Chọn HQ-GW trong Library.
2. Mở **Edit virtual machine settings**, hoặc menu **VM → Settings**.
3. Trong tab **Hardware**, chọn **Network Adapter** ở danh sách bên trái.
4. Ở vùng **Network connection**, chọn **LAN segment** rồi bấm **LAN Segments...**. Một số bản hiển thị nút này ngay trong trang Network Adapter.
5. Trong hộp thoại quản lý segment, bấm **Add**, nhập `WAN-Net`, xác nhận tên bằng **OK** hoặc Enter theo hộp thoại đang hiển thị.
6. Lặp lại Add để tạo `HQ-LAN-Net` và `Branch-LAN-Net`.
7. Kiểm tra danh sách có đủ ba tên, sau đó bấm **OK** để trở lại VM Settings.
8. Tại Network Adapter của HQ-GW, chọn **LAN segment: WAN-Net** trong danh sách.
9. Chọn **Connect at power on**, rồi bấm **OK** để lưu.

Các segment vừa tạo được chọn lại trong danh sách trên những VM còn lại của cùng môi trường Workstation; không tạo thêm một bộ tên khác cho mỗi VM. Quy trình tạo/gán segment được mô tả trong [hướng dẫn VMware Workstation, mục Configuring LAN Segments](https://sw5-prod-media-files.s3.eu-central-1.amazonaws.com/media/pdf/25/0e/0e/workstation-pro-15-user-guide.pdf).

Nếu ô **Connected** bị mờ khi VM đang tắt, cứ bật **Connect at power on** và lưu. Sau khi bật VM, kiểm tra card đã Connected trong Settings hoặc menu **VM → Removable Devices → Network Adapter**. Không cần bật máy chỉ để tạo segment.

### 2.4 Cấu hình đủ ba card cho HQ-GW

HQ-GW cần **hai card lab và một NAT tạm**. Card đầu đã được gán WAN-Net ở bước trên.

1. Mở lại **HQ-GW → Settings → Hardware**.
2. Chọn **Network Adapter** đầu tiên; kiểm tra nó đang dùng **LAN segment: WAN-Net**.
3. Bấm **Add...** bên dưới danh sách phần cứng.
4. Chọn **Network Adapter**, hoàn tất wizard bằng Next/Finish theo phiên bản. Nếu wizard hỏi loại mạng trước khi cho Finish, có thể giữ NAT tạm rồi chỉnh lại ngay ở bước sau.
5. Khi card mới xuất hiện, chọn **Network Adapter 2** trong danh sách Hardware.
6. Chọn **LAN segment: HQ-LAN-Net**, bật **Connect at power on**.
7. Bấm **Add... → Network Adapter** một lần nữa để thêm card thứ ba.
8. Chọn **Network Adapter 3**, đặt **NAT: Used to share the host's IP address**, bật **Connect at power on**.
9. Chọn lần lượt từng card kiểm tra lần cuối rồi bấm **OK**.

| Card trong VMware HQ-GW | Chọn trong Network connection | Vai trò | IP sẽ đặt sau |
| --- | --- | --- | --- |
| Network Adapter | LAN segment → WAN-Net | WAN HQ | 172.16.1.10/24 |
| Network Adapter 2 | LAN segment → HQ-LAN-Net | LAN HQ | 10.74.10.1/24 |
| Network Adapter 3 | NAT | Internet tạm | DHCP |

Nếu VM đã có đủ card từ trước, chọn lại đúng loại kết nối cho từng card thay vì thêm card trùng. Trên VM đã có cấu hình IP, đối chiếu MAC trước khi đổi vai trò card.

### 2.5 Cấu hình ba card cho Branch-GW

1. Chọn **Branch-GW → Edit virtual machine settings**.
2. Chọn card đầu **Network Adapter**, đặt **LAN segment: WAN-Net**.
3. Dùng **Add... → Network Adapter** thêm card thứ hai; sau khi thêm, chọn card đó và đặt **LAN segment: Branch-LAN-Net**.
4. Thêm card thứ ba, chọn **NAT**.
5. Bật **Connect at power on** cho cả ba card, kiểm tra bảng dưới rồi bấm **OK**.

| Card trong VMware Branch-GW | Kết nối | IP sẽ đặt sau |
| --- | --- | --- |
| Network Adapter | LAN segment → WAN-Net | 172.16.1.20/24 |
| Network Adapter 2 | LAN segment → Branch-LAN-Net | 10.74.20.1/24 |
| Network Adapter 3 | NAT | DHCP |

Hai card WAN của HQ-GW và Branch-GW cùng vào `WAN-Net`. Hai card LAN đi vào **hai segment khác nhau**, vì đây là hai site riêng.

### 2.6 Cấu hình hai card cho HQ-Server

1. Chọn **HQ-Server → Edit virtual machine settings**.
2. Đặt **Network Adapter** đầu tiên thành **LAN segment: HQ-LAN-Net**.
3. Thêm một Network Adapter thứ hai bằng **Add... → Network Adapter**, đặt **NAT**.
4. Bật **Connect at power on** cho cả hai card rồi lưu **OK**.

| Card trong VMware HQ-Server | Kết nối | IP sẽ đặt sau |
| --- | --- | --- |
| Network Adapter | LAN segment → HQ-LAN-Net | 10.74.10.50/24 |
| Network Adapter 2 | NAT | DHCP |

HQ-Server chỉ cùng LAN với card LAN của HQ-GW; không nối trực tiếp card nào của máy này vào WAN-Net hoặc Branch-LAN-Net.

### 2.7 Cấu hình hai card cho Branch-PC

1. Chọn **Branch-PC → Edit virtual machine settings**.
2. Đặt **Network Adapter** đầu tiên thành **LAN segment: Branch-LAN-Net**.
3. Thêm card thứ hai, chọn **NAT**.
4. Bật **Connect at power on** cho cả hai card rồi lưu **OK**.

| Card trong VMware Branch-PC | Kết nối | IP sẽ đặt sau |
| --- | --- | --- |
| Network Adapter | LAN segment → Branch-LAN-Net | 10.74.20.50/24 |
| Network Adapter 2 | NAT | DHCP |

Branch-PC không có card trực tiếp ở HQ-LAN-Net. Sau khi dựng S2S, nó phải gửi traffic tới HQ qua Branch-GW.

### 2.8 Cấu hình hai card cho Windows Remote-PC

1. Chọn VM **Remote-PC → Edit virtual machine settings**.
2. Đặt **Network Adapter** đầu tiên thành **LAN segment: WAN-Net**.
3. Thêm card thứ hai, chọn **NAT** để tải OpenVPN/WinSCP nếu cần.
4. Bật **Connect at power on** cho cả hai card rồi lưu **OK**.

| Card trong VMware Remote-PC | Kết nối | IP sẽ đặt sau |
| --- | --- | --- |
| Network Adapter | LAN segment → WAN-Net | 172.16.1.100/24 |
| Network Adapter 2 | NAT | DHCP |

Không nối Windows Remote-PC với HQ-LAN-Net hoặc Branch-LAN-Net. IP VPN `10.8.0.x` chỉ xuất hiện khi OpenVPN Connect, không phải card LAN Segment cần thêm trong VMware.

### 2.9 Kiểm tra NAT tạm và tránh trùng subnet

Thông thường card **NAT** dùng mạng VMnet8 có sẵn. Không cần tạo NAT riêng cho từng VM và không cần cấu hình port forwarding cho bài lab này. Cách thêm card và lựa chọn NAT được hướng dẫn trong [tài liệu Virtual Network Editor của Broadcom](https://knowledge.broadcom.com/external/article/339371/using-the-virtual-network-editor-in-vmwa.html).

Trước khi bật năm VM, trên Windows host:

1. Chọn **Edit → Virtual Network Editor**.
2. Nếu cần chỉnh cấu hình, bấm **Change Settings** để mở quyền quản trị.
3. Chọn mạng đang có **Type: NAT**, thường là **VMnet8**.
4. Đọc Subnet IP và Subnet mask. Subnet NAT không được chồng lấn với các mạng `172.16.1.0/24`, `10.74.10.0/24`, `10.74.20.0/24`, `10.8.0.0/24`, `10.9.0.0/24`.
5. Nếu không trùng, giữ cấu hình NAT/DHCP hiện có và đóng cửa sổ. Trong cách LAN Segment, không tạo thêm WAN-Net/HQ-LAN-Net/Branch-LAN-Net tại Virtual Network Editor.

Kiểm tra các subnet lab với cả Wi-Fi/Ethernet và bảng route do VPN khác cài trên các máy tham gia. Nếu có mạng chồng lấn, chọn subnet lab trống và cập nhật đồng bộ địa chỉ LAN, route, OpenVPN, firewall và Portal. VMnet8 có thể phục vụ nhiều VM cùng lúc.

Ở giai đoạn cài gói, giữ cả năm NIC NAT Connected. Khi nghiệm thu, ngắt **chỉ các NIC NAT** theo [phần nghiệm thu](06-acceptance.md); các NIC LAN Segment vẫn giữ Connected.

### 2.10 Bật VM và đối chiếu MAC trước khi đặt IP

Bật từng VM. Trên Linux, mở terminal chạy:

```bash
ip -br link
ip -br address
```

Trên Windows Remote-PC, mở PowerShell:

```powershell
Get-NetAdapter | Format-Table Name, MacAddress, Status
ipconfig
```

Mở **VM Settings → chọn từng Network Adapter → Advanced...** và đọc MAC; đối chiếu với kết quả trong guest. Card WAN/LAN có thể chưa có IPv4 do LAN Segment không có DHCP, đây là trạng thái bình thường trước bước IP tĩnh. Card NAT dự kiến có địa chỉ DHCP thuộc subnet NAT khi hệ điều hành đã bật DHCP cho card đó.

Ghi bảng đối chiếu sau cho **từng VM** trước khi sửa Netplan:

| Máy | Card VMware | Nối vào | MAC | Tên card trong guest |
| --- | --- | --- | --- | --- |
| HQ-GW | Network Adapter | WAN-Net | Ghi MAC thực | Ghi tên thực |
| HQ-GW | Network Adapter 2 | HQ-LAN-Net | Ghi MAC thực | Ghi tên thực |
| HQ-GW | Network Adapter 3 | NAT | Ghi MAC thực | Ghi tên thực |
| Branch-GW | Network Adapter | WAN-Net | Ghi MAC thực | Ghi tên thực |
| Branch-GW | Network Adapter 2 | Branch-LAN-Net | Ghi MAC thực | Ghi tên thực |
| Branch-GW | Network Adapter 3 | NAT | Ghi MAC thực | Ghi tên thực |
| HQ-Server | Network Adapter | HQ-LAN-Net | Ghi MAC thực | Ghi tên thực |
| HQ-Server | Network Adapter 2 | NAT | Ghi MAC thực | Ghi tên thực |
| Branch-PC | Network Adapter | Branch-LAN-Net | Ghi MAC thực | Ghi tên thực |
| Branch-PC | Network Adapter 2 | NAT | Ghi MAC thực | Ghi tên thực |
| Remote-PC | Network Adapter | WAN-Net | Ghi MAC thực | Ghi tên thực |
| Remote-PC | Network Adapter 2 | NAT | Ghi MAC thực | Ghi tên thực |

Tên `Network Adapter 2` trong VMware không có nghĩa chắc chắn là `ens37` trong Linux hoặc `Ethernet 2` trong Windows. Luôn dùng MAC để xác định. Với VM clone, các NIC phải có MAC riêng, không trùng NIC ở VM khác.

### 2.11 Nếu giao diện không có LAN Segment

Chỉ dùng nhánh này nếu không thể chọn LAN Segment. Nếu đã làm các bước LAN Segment ở trên, bỏ qua phần Custom/VMnet để tránh trộn hai cách nối mạng.

1. Mở **Edit → Virtual Network Editor → Change Settings** trên host.
2. Bấm **Add Network...**, chọn ba VMnet chưa dùng. Ví dụ nếu còn trống: VMnet2, VMnet3, VMnet4. Không thay đổi VMnet đang dùng cho mạng khác.
3. Với mỗi VMnet lab, chọn kiểu **Host-only**, bỏ **Connect a host virtual adapter to this network**, bỏ **Use local DHCP service to distribute IP address to VMs**. Ba VMnet lab không bật NAT hoặc Bridged.
4. Đặt subnet/mask theo bảng sau, bấm Apply/OK.

| Tên vai trò trong hướng dẫn | VMnet ví dụ | Subnet IP | Mask |
| --- | --- | --- | --- |
| WAN-Net | VMnet2 | 172.16.1.0 | 255.255.255.0 |
| HQ-LAN-Net | VMnet3 | 10.74.10.0 | 255.255.255.0 |
| Branch-LAN-Net | VMnet4 | 10.74.20.0 | 255.255.255.0 |

5. Trong Settings từng VM, chọn **Custom: Specific virtual network** trên các card lab. Dùng VMnet2 ở mọi vị trí ghi WAN-Net, VMnet3 ở HQ-LAN-Net, VMnet4 ở Branch-LAN-Net.
6. NIC NAT tạm vẫn chọn NAT riêng như trước. IP tĩnh bên trong guest giữ nguyên theo hướng dẫn từng máy.

Ở nhánh này, bảng subnet chỉ định mạng lab, không đặt IP của gateway VM. HQ-GW vẫn phải có `10.74.10.1`, Branch-GW vẫn có `10.74.20.1` trong guest. Nếu phiên bản đang dùng không có Virtual Network Editor, cần dùng bản Workstation có tính năng này để thực hiện nhánh Custom.

### 2.12 Checklist hoàn thành phần VMware

- [ ] Có đúng năm VM; hai gateway mỗi máy ba NIC, ba máy còn lại mỗi máy hai NIC khi chuẩn bị, tổng cộng 12 NIC.
- [ ] WAN-Net có đúng ba NIC: WAN HQ-GW, WAN Branch-GW, WAN Windows.
- [ ] HQ-LAN-Net có đúng hai NIC: LAN HQ-GW và HQ-Server.
- [ ] Branch-LAN-Net có đúng hai NIC: LAN Branch-GW và Branch-PC.
- [ ] Mỗi VM có một NAT tạm; subnet NAT không trùng các subnet lab/tunnel.
- [ ] Không có card lab vô tình chọn Bridged hoặc VMnet của một LAN khác.
- [ ] Đã đối chiếu MAC và tên card trong guest; ghi đúng WAN/LAN/NAT.
- [ ] Chưa tạo thêm card/switch cho tunnel 10.8.0.0/24 hoặc 10.9.0.0/24.

Đến đây mới hoàn thành **cách nối mạng ảo**. Sang phần 3 để cài công cụ, sau đó dùng YAML/IP của [từng máy](README.md) để đặt địa chỉ trong hệ điều hành. Chỉ kiểm tra ping LAN/WAN sau khi các máy liên quan đã có IP tĩnh; chưa có VPN thì chưa yêu cầu hai host LAN khác site ping nhau.

| Vấn đề gặp ở bước VMware | Cách xử lý |
| --- | --- |
| Add hoặc Network Adapter bị khóa | Shutdown VM hoàn toàn, không để Suspended; mở lại Settings |
| Connected bị mờ khi VM tắt | Bật Connect at power on, sau khi boot kiểm tra trạng thái kết nối |
| VM chỉ có một card | Thêm card theo vai trò; không dùng một card để thay cả WAN và LAN gateway |
| Card LAN chưa có IPv4 | Bình thường trước cấu hình IP tĩnh vì LAN Segment không có DHCP |
| Card NAT không có IP | Kiểm tra NAT Connected, DHCP trong guest và VMware DHCP/NAT service; khi sửa YAML cũ phải khai báo lại NAT riêng |
| Không thấy tên segment vừa tạo ở VM khác | Kiểm tra cùng host/môi trường Workstation và danh sách LAN Segments; chọn đúng segment đã tạo, tránh tên gần giống |

## 3 Cài công cụ chung trên bốn Linux

Đăng nhập tài khoản thường có sudo, mở **console VMware**. Trong lúc NIC NAT còn có Internet, chạy trên từng Linux:

```bash
whoami
uname -m
cat /etc/os-release
sudo apt update
sudo apt install -y nano openssh-server openssh-client curl open-vm-tools
sudo systemctl enable --now ssh
ip -br address
timedatectl
```

Mỗi VM phải có hostname và MAC riêng. Nếu clone, chọn MAC mới, xử lý định danh máy/SSH theo quy trình clone của hệ điều hành; không coi hai VM clone là cùng một máy chỉ vì IP đã đổi. Các hướng dẫn từng máy sẽ đặt hostname.

## 4 Chép đúng bản repo vào mỗi Linux

Chép bản workspace hiện tại, gồm các thay đổi chưa push, vào **`/home/<tai-khoan>/vpn-lab`**. Không chỉ clone bản GitHub cũ rồi cho rằng đã có các sửa đổi trong cuộc trao đổi này.

Cách làm bằng WinSCP từ Windows host:

1. Trong Linux VM, đọc IP được DHCP cấp trên NIC NAT bằng `ip -br address`.
2. Mở WinSCP, chọn SFTP, host là **IP NAT của chính VM đó**, port 22, user là tài khoản Linux.
3. Kiểm tra fingerprint SSH. Có thể đọc fingerprint tại console VM bằng `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` để đối chiếu.
4. Tạo thư mục `vpn-lab` trong home và chép nội dung repo vào đó. Không cần chép `.git` hay bất kỳ PKI/profile thật nào từ lab khác.
5. Lặp lại với ba Linux còn lại.

Trên từng Linux xác nhận không bị lồng hai lần tên thư mục:

```bash
cd ~/vpn-lab
ls scripts configs openvpn services
test -f scripts/deploy-all.sh && echo 'Repo dung vi tri'
test -f scripts/common/lab-network.sh && echo 'Da co ban cap nhat NIC'
test -f scripts/common/check-openvpn-version.sh && echo 'Da co kiem tra phien ban'
```

Trong cấu hình LAN Segment, Windows host không trực tiếp nằm trên WAN-Net. Dùng IP NAT để chép repo từ host ở giai đoạn chuẩn bị; chỉ dùng `172.16.1.x` giữa các VM đã nối WAN-Net. Windows Remote-PC VM là máy riêng với host chạy VMware.

## 5 Xác định tên card và backend mạng

Trên mỗi Linux:

```bash
ip -br link
ip -br address
sudo ls -l /etc/netplan
sudo cat /etc/netplan/*.yaml
systemctl is-active systemd-networkd
systemctl is-active NetworkManager
```

Đối chiếu MAC từ `ip -br link` với **VM Settings → Network Adapter → Advanced**. Ghi lại tên NIC thực vào bảng riêng. Ví dụ xuyên suốt bộ hướng dẫn:

| Loại máy | ens33 | ens37 | ens39 |
| --- | --- | --- | --- |
| Hai gateway | WAN lab | LAN của site | NAT tạm |
| Hai host LAN | LAN của site | NAT tạm | — |

Armbian Minimal dùng `networkd`; image CLI/Desktop không phải Minimal dùng NetworkManager theo mặc định của Armbian. Mẫu YAML phải khớp backend đang quản lý NIC thực tế. [Nguồn Armbian](https://docs.armbian.com/user-guide/networking/)

## 6 Xử lý cấu hình DHCP cũ trước khi đặt IP

Chỉ thực hiện qua console trên VM lab. Lưu các tệp Netplan cũ để có thể khôi phục; sau đó sửa bản gốc xung đột bằng editor và đổi đuôi sang `.yaml.disabled`. Ví dụ `10-dhcp-all-interfaces.yaml` có thể match mọi `e*`, cần ngừng nạp khi chuyển sang mẫu IP tĩnh. Tệp cuối cùng `/etc/netplan/20-vpn-lab.yaml` trong hướng dẫn từng máy đã gồm cả NIC NAT DHCP.

```bash
LAB_NETPLAN_BACKUP="/root/vpn-lab-backup/netplan-$(date +%Y%m%d-%H%M%S)"
sudo install -d -m 700 "$LAB_NETPLAN_BACKUP"
sudo cp -a /etc/netplan/. "$LAB_NETPLAN_BACKUP/"
sudo ls -l /etc/netplan
```

Dùng `sudo mv /etc/netplan/<ten-tep-cu>.yaml /etc/netplan/<ten-tep-cu>.yaml.disabled` cho **đúng tệp đã xác định xung đột**; thay tên trong dấu `<...>` trước khi chạy. Giữ một cấu hình lab rõ ràng cho từng NIC. Không chạy `netplan apply` giữa lúc đã vô hiệu tệp cũ nhưng chưa tạo YAML mới.

Nếu NetworkManager còn profile DHCP cũ ngoài Netplan, xem `nmcli connection show` và `nmcli device status`; tắt autoconnect đúng profile cũ theo UUID, không down nhầm profile NAT đang tải gói. Không chỉ dựa vào việc có GUI để chọn renderer. Xem [giải thích và cách kiểm tra NIC](../technical-guides/09-armbian-vmware-guide.md).

## 7 Áp dụng mẫu trong hướng dẫn từng máy

Trên mỗi Linux, mở tệp bằng `sudo nano /etc/netplan/20-vpn-lab.yaml`, dán YAML của đúng máy và thay tên NIC. Lưu bằng Ctrl+O, Enter, thoát Ctrl+X rồi chạy:

```bash
sudo chmod 600 /etc/netplan/20-vpn-lab.yaml
sudo netplan generate
sudo netplan try
ip -br address
ip route
```

Trong `netplan try`, nhấn Enter xác nhận khi kết nối đúng. Nếu backend không hỗ trợ `try`, đọc lỗi và chỉ dùng `sudo netplan apply` tại console sau khi đã kiểm tra YAML; khôi phục từ bản sao lưu nếu mất mạng. Không đổi địa chỉ mạng qua phiên SSH duy nhất đang phụ thuộc NIC đó.

NAT có route metric 50 để apt sử dụng Internet. Default route qua gateway LAN ở hai host có metric 200; route cụ thể tới site bên kia luôn đi qua gateway lab. Hai gateway và Windows không đặt default gateway trên NIC WAN-Net.

## 8 Nếu chuyển từ bài ba máy

Giữ Linux Server làm HQ-GW, chuyển Linux Client thành Branch-GW; thêm HQ-Server và Branch-PC, giữ Windows làm Remote-PC. Thêm NIC LAN cho hai gateway và nối lại theo bảng ở trên. Dùng cấu hình năm máy, không tái sử dụng profile `client-linux`/`client-windows` của bài cũ.

Trước khi deploy trên VM tái sử dụng, kiểm tra:

```bash
systemctl list-units --all 'openvpn*'
sudo ss -lunp
ip -br address
```

Trên HQ-GW, nếu bài cũ có `openvpn-server@demo`, dừng/tắt autostart đúng unit đó. Trên Branch-GW, làm tương tự với `openvpn-client@demo-linux`. Dừng/tắt Nginx demo cũ trên HQ-GW nếu VM này trước đó chạy web của bài ba máy; Portal mới đặt trên HQ-Server. Không xóa hay khởi tạo lại PKI cũ chỉ để đổi mô hình.

Sau phần này, mở [hướng dẫn từng máy và lịch triển khai](README.md). Không ngắt NIC NAT cho tới khi chạy xong các lệnh deploy ở cả bốn Linux và tải xong phần mềm Windows.
