# TÀI LIỆU KỸ THUẬT: THIẾT KẾ KIẾN TRÚC MẠNG & TOPOLOGY LAB

> Mô hình hiện tại: VMware Workstation, 3 Armbian không GUI (HQ-GW, Branch-GW, HQ-Server), Armbian GUI Branch-PC và Windows Remote-PC. Chuẩn bị image/renderer/NIC theo [hướng dẫn Armbian VMware](09-armbian-vmware-guide.md) trước khi dùng các mẫu IP bên dưới.

> **Dự án:** Thiết lập mạng riêng ảo VPN Site-to-Site và Client-to-Site  
> **Tài liệu:** `docs/technical-guides/02-network-topology.md`  
> **Giai đoạn:** Giai đoạn 1 - Chuẩn bị máy ảo & Cấu hình mạng tĩnh  

---

## 1. Sơ đồ Tổng thể Kiến trúc Mạng (Master Topology)

Hệ thống Lab bao gồm 3 phân vùng mạng vật lý/ảo biệt lập, giao tiếp với nhau qua 2 thiết bị VPN Gateway:

```mermaid
flowchart LR
    subgraph HQ_SITE ["Trụ sở chính (HQ Site - 10.74.10.0/24)"]
        HQ_Server["HQ Internal Server\n(Web / Docs Portal)\nIP: 10.74.10.50\nGW: 10.74.10.1"]
        HQ_GW["HQ VPN Gateway\n(Armbian không GUI)\nLAN: 10.74.10.1\nWAN: 172.16.1.10"]
        HQ_Server <-->|"LAN vSwitch\n(HQ-LAN-Net)"| HQ_GW
    end

    subgraph WAN_ENV ["Simulated WAN / Internet (172.16.1.0/24)"]
        WAN_SW["Virtual WAN Network Switch\n(WAN-Net)"]
    end

    subgraph BRANCH_SITE ["Văn phòng chi nhánh (Branch Site - 10.74.20.0/24)"]
        BR_GW["Branch VPN Gateway\n(Armbian không GUI)\nWAN: 172.16.1.20\nLAN: 10.74.20.1"]
        BR_PC["Branch Client Host\n(Armbian có GUI)\nIP: 10.74.20.50\nGW: 10.74.20.1"]
        BR_GW <-->|"LAN vSwitch\n(Branch-LAN-Net)"| BR_PC
    end

    subgraph REMOTE_WORKER ["Nhân viên từ xa (Remote Client)"]
        RW_PC["Remote Worker Windows 10/11 x64\nWAN: 172.16.1.100\nAssigned VPN IP: 10.8.0.x"]
    end

    HQ_GW <-->|"eth0 (WAN)"| WAN_SW
    WAN_SW <-->|"eth0 (WAN)"| BR_GW
    WAN_SW <-->|"Wi-Fi / Ethernet"| RW_PC

    %% Đường hầm VPN
    RW_PC -.->|"Tunnel 1: OpenVPN Client-to-Site (10.8.0.0/24)\n[UDP 1194 - AES-256-GCM]"| HQ_GW
    BR_GW -.->|"Tunnel 2: OpenVPN Site-to-Site (10.9.0.0/24)\n[UDP 1195]"| HQ_GW
```

---

## 2. Bảng Quy Hoạch IP, Subnet và Gateway Chi Tiết

| Node / Máy ảo | Tên Interface | Địa chỉ IP & Subnet | Default Gateway | Chức năng chi tiết |
| :--- | :--- | :--- | :--- | :--- |
| **Mạng WAN Giả lập** | Virtual Switch | `172.16.1.0/24` | Không có | Đại diện cho môi trường Internet công cộng kết nối giữa các chi nhánh |
| **VM-HQ-GW** (HQ Gateway) | `eth0` (WAN)<br>`eth1` (LAN)<br>`tun0` (C2S)<br>`tun1` (S2S) | `172.16.1.10/24`<br>`10.74.10.1/24`<br>`10.8.0.1/24`<br>`10.9.0.1/24` | None<br>None<br>None<br>None | VPN Gateway tại Trụ sở: phục vụ Remote Worker truy cập và kết nối Site-to-Site sang Chi nhánh |
| **VM-HQ-Server** (HQ Internal) | `eth0` (LAN) | `10.74.10.50/24` | `10.74.10.1` | Máy chủ Web Portal và tài liệu nội bộ cần được bảo vệ |
| **VM-Branch-GW** (Branch Gateway) | `eth0` (WAN)<br>`eth1` (LAN)<br>`tun0` (S2S) | `172.16.1.20/24`<br>`10.74.20.1/24`<br>`10.9.0.2/24` | None<br>None<br>None | VPN Gateway tại Chi nhánh: làm đầu cuối VPN kết nối đường hầm Site-to-Site về HQ |
| **VM-Branch-PC** (Branch Client) | `eth0` (LAN) | `10.74.20.50/24` | `10.74.20.1` | Máy trạm làm việc của nhân viên chi nhánh, truy cập tài nguyên HQ qua VPN Gateway |
| **VM-Remote-PC** (Windows 10/11 x64) | Ethernet (WAN)<br>Adapter OpenVPN (C2S) | `172.16.1.100/24`<br>`10.8.0.x/24` (Cấp động) | Không có default gateway trên WAN giả lập; route HQ qua adapter OpenVPN | Nhân viên từ xa kết nối bằng OpenVPN GUI |

---

## 3. Cấu hình Card Mạng Ảo trên VMware

Để đảm bảo các phân vùng mạng hoạt động cô lập và đúng thiết kế:

### 3.1. Thiết lập 3 mạng ảo

Demo dùng 4 Armbian VM (3 CLI + 1 GUI Branch-PC) và Windows Remote-PC. VMware dùng ba LAN Segment. WAN-Net là WAN giả lập, không tự có Internet. Dùng NIC NAT tạm để tải gói rồi ngắt trước demo theo [README](../../README.md).

Tên eth0/eth1 trong các mẫu là placeholder. Đối chiếu MAC bằng `ip -br link`, sửa NIC trong Netplan và khai báo WAN_IF/LAN_IF ở `/etc/vpn-lab/interfaces.conf` trên mỗi gateway. Không cần sửa từng script. Chọn renderer đúng image, xử lý DHCP catch-all của Armbian theo hướng dẫn riêng; Branch-PC GUI dùng NetworkManager nếu image đang dùng backend đó.

- **`WAN-Net`:** Mạng nội bộ kết nối các card WAN (`172.16.1.0/24`).
- **`HQ-LAN-Net`:** Mạng nội bộ riêng của Trụ sở chính (`10.74.10.0/24`).
- **`Branch-LAN-Net`:** Mạng nội bộ riêng của Văn phòng Chi nhánh (`10.74.20.0/24`).

### 3.2. Ánh xạ Card mạng trên từng máy ảo

1. **`VM-HQ-GW`:**
   - NIC WAN: LAN Segment `WAN-Net`; NIC LAN: LAN Segment `HQ-LAN-Net`. Ghi tên card thực tế theo MAC.
2. **`VM-Branch-GW`:**
   - NIC WAN: LAN Segment `WAN-Net`; NIC LAN: LAN Segment `Branch-LAN-Net`.
3. **`VM-HQ-Server`:**
   - NIC LAN: LAN Segment `HQ-LAN-Net`.
4. **`VM-Branch-PC`:**
   - NIC LAN: LAN Segment `Branch-LAN-Net`; VM này chạy Armbian GUI.
5. **`VM-Remote-PC` (Windows 10/11 x64):**
   - NIC WAN: LAN Segment `WAN-Net`, đặt IPv4 `172.16.1.100/24` trong `ncpa.cpl`.
   - OpenVPN tạo/dùng adapter VPN theo driver đi kèm; không thêm adapter LAN HQ/Branch.

---

## 4. Cài đặt IP Tĩnh Bằng Netplan trên Armbian

Các mẫu nằm trong `configs/netplan/`. Đổi NIC và renderer theo image trước khi chép. Các lệnh bên dưới không tự gỡ YAML DHCP mặc định; thực hiện bước xử lý cấu hình trùng và duy trì NAT theo [guide Armbian](09-armbian-vmware-guide.md). Áp dụng bằng console VMware, ưu tiên `netplan generate` rồi `netplan try`.

### 4.1. Cấu hình trên VM-HQ-GW
Sao chép `configs/netplan/01-netcfg-hq-gw.yaml` vào `/etc/netplan/01-netcfg.yaml`:
```bash
sudo cp configs/netplan/01-netcfg-hq-gw.yaml /etc/netplan/01-netcfg.yaml
sudo chmod 600 /etc/netplan/01-netcfg.yaml
sudo netplan apply
```

### 4.2. Cấu hình trên VM-Branch-GW
Sao chép `configs/netplan/01-netcfg-branch-gw.yaml` vào `/etc/netplan/01-netcfg.yaml`:
```bash
sudo cp configs/netplan/01-netcfg-branch-gw.yaml /etc/netplan/01-netcfg.yaml
sudo chmod 600 /etc/netplan/01-netcfg.yaml
sudo netplan apply
```

### 4.3. Cấu hình trên VM-HQ-Server
Sao chép `configs/netplan/01-netcfg-hq-server.yaml` vào `/etc/netplan/01-netcfg.yaml`:
```bash
sudo cp configs/netplan/01-netcfg-hq-server.yaml /etc/netplan/01-netcfg.yaml
sudo chmod 600 /etc/netplan/01-netcfg.yaml
sudo netplan apply
```

### 4.4. Cấu hình trên VM-Branch-PC
Sao chép `configs/netplan/01-netcfg-branch-pc.yaml` vào `/etc/netplan/01-netcfg.yaml`:
```bash
sudo cp configs/netplan/01-netcfg-branch-pc.yaml /etc/netplan/01-netcfg.yaml
sudo chmod 600 /etc/netplan/01-netcfg.yaml
sudo netplan apply
```

---

### 4.5. Windows Remote-PC

Windows không dùng Netplan. Mở `ncpa.cpl` → card WAN-Net → IPv4: IP `172.16.1.100`, mask `255.255.255.0`, không đặt gateway/DNS trên WAN giả lập. Kiểm tra `ping -n 3 172.16.1.10`, rồi cài/import OpenVPN GUI theo [hướng dẫn Windows](08-windows-client-requirements.md). Adapter VPN nhận `10.8.0.x` và route HQ sau khi Connect.

## 5. Kích hoạt Chuyển tiếp Gói tin Kernel (IP Forwarding)

Trên cả 2 VPN Gateway (`VM-HQ-GW` và `VM-Branch-GW`), chuyển tiếp gói tin là điều kiện tiên quyết để định tuyến giữa các card mạng:

Chạy script tự động hóa:
```bash
sudo bash scripts/common/enable-ip-forward.sh
```

Hoặc thực hiện thủ công:
```bash
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-vpn-forward.conf
sudo sysctl -p /etc/sysctl.d/99-vpn-forward.conf
```

---

## 6. Thiết lập Tường lửa & Chống Phân mảnh Gói tin (MSS Clamping)

Chạy script thiết lập tường lửa trên từng Gateway:
```bash
# Trên VM-HQ-GW:
sudo bash scripts/common/setup-firewall-rules.sh hq-gw

# Trên VM-Branch-GW:
sudo bash scripts/common/setup-firewall-rules.sh branch-gw
```

---

## 7. Kiểm tra & Nghiệm thu Giai đoạn 1

Chạy script kiểm tra tự động trên bất kỳ node nào:
```bash
bash scripts/common/verify-phase1.sh
```

### Bảng tiêu chí đạt yêu cầu (Pass Criteria):
- [ ] `VM-HQ-GW` ping thông `172.16.1.20` (Branch GW) và `172.16.1.100` (Remote PC).
- [ ] `VM-HQ-GW` ping thông `10.74.10.50` (HQ Server).
- [ ] `VM-Branch-GW` ping thông `10.74.20.50` (Branch PC).
- [ ] `net.ipv4.ip_forward = 1` trên cả 2 Gateway.
- [ ] Dịch vụ `chrony` đang hoạt động và đồng bộ thời gian trên toàn bộ máy ảo.

