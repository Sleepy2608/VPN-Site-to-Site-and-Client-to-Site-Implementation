# Máy 5 Windows Remote-PC

Windows Remote-PC là VM nhân viên từ xa, nối WAN-Net và dùng **OpenVPN GUI** kết nối Client-to-Site tới HQ-GW. Đây là VM riêng với Windows host đang chạy VMware. Làm [chuẩn bị chung](00-preparation.md); các bước bên dưới thực hiện **trong Windows Remote-PC VM**.

## 1 Card mạng và địa chỉ

| Card | Nối VMware | Địa chỉ | Gateway và DNS |
| --- | --- | --- | --- |
| WAN lab | WAN-Net | 172.16.1.100/24 | Để trống |
| NAT tạm | NAT | DHCP | DHCP cấp, ngắt trước nghiệm thu |
| Adapter VPN | OpenVPN/driver tự tạo | 10.8.0.x khi Connect | Route do VPN cấp |

Không nối Windows với HQ-LAN-Net hoặc Branch-LAN-Net. Không đặt IP tĩnh cho adapter VPN bằng tay.

## 2 Đặt IP cho card WAN

1. Trong VMware, ghi MAC của NIC đang nối WAN-Net.
2. Trong Windows nhấn Win+R, nhập `ncpa.cpl`, Enter.
3. Đối chiếu MAC với kết quả PowerShell để xác định đúng card. Có thể đổi tên card thành `WAN-Lab` để dễ nhận biết.
4. Nhấn phải card WAN → Properties → Internet Protocol Version 4 → Properties.
5. Chọn Use the following IP address, nhập IP `172.16.1.100`, subnet mask `255.255.255.0`, để trống default gateway; không nhập DNS cho card lab.
6. Card NAT tạm giữ DHCP trong giai đoạn tải phần mềm.

Trong PowerShell:

```powershell
Get-NetAdapter | Format-Table Name, InterfaceDescription, MacAddress, Status
ipconfig
ping -n 3 172.16.1.10
```

Phải ping được WAN HQ-GW trước khi xử lý VPN. Windows không bắt buộc nhận được ping từ gateway để kết nối VPN ra ngoài; không tắt toàn bộ Windows Firewall chỉ để thử ICMP.

## 3 Cài OpenVPN Community

Tải bản **OpenVPN Community cho Windows x64** từ [trang chính thức](https://openvpn.net/community/), cài bằng tài khoản có quyền quản trị, giữ OpenVPN GUI, service và driver đi kèm. Bộ cài Community cung cấp GUI/service và hỗ trợ Windows từ Windows 10 trở lên; dùng bản OS phù hợp theo [yêu cầu Windows của lab](../technical-guides/08-windows-client-requirements.md).

Mở OpenVPN GUI từ Start Menu, tìm biểu tượng ở system tray, có thể phải mở nhóm biểu tượng ẩn. Không dùng Add a VPN connection tích hợp của Windows để import tệp `.ovpn` này. Trước mắt giữ trạng thái chưa kết nối.

## 4 Nhận đúng profile từ HQ-GW

Đợi HQ-GW chạy xong `deploy-all.sh hq-gw`. Tệp cần nhận là **`client1.ovpn` trong home tài khoản triển khai HQ-GW**; không phải template hay `client.ovpn.example` trong repo.

Cách dùng WinSCP trong Windows VM:

1. Chọn SFTP, host `172.16.1.10`, port 22, user là tài khoản Linux trên HQ-GW.
2. Kiểm tra fingerprint SSH đúng HQ-GW.
3. Mở `/home/<tai-khoan>/client1.ovpn`, tải về Downloads của Windows.
4. Chỉ tải profile client; không tải thư mục CA hay khóa CA.

Nếu Windows đã có OpenSSH Client, có thể dùng PowerShell thay WinSCP. Ví dụ dưới dành cho tài khoản Linux có home `/home/<ten-user>`:

```powershell
$hqUser = Read-Host 'Nhap tai khoan Linux tren HQ-GW'
scp "${hqUser}@172.16.1.10:/home/${hqUser}/client1.ovpn" "$env:USERPROFILE\Downloads\client1.ovpn"
Get-Item "$env:USERPROFILE\Downloads\client1.ovpn"
```

Nếu HQ được triển khai bằng root trực tiếp hoặc `CA_DIR`/đường dẫn khác, dùng đúng vị trí được script in ra và chuyển qua kênh quản trị thích hợp. Profile chứa khóa riêng inline, không đăng lên Git/chat/ảnh chụp.

## 5 Import và kết nối

1. Nhấn phải biểu tượng OpenVPN GUI → **Import file...** → chọn `Downloads\client1.ovpn`.
2. Chọn profile `client1` → **Connect**.
3. Mở View Log, đợi `Initialization Sequence Completed` và trạng thái Connected.

Profile phải trỏ `remote 172.16.1.10 1194` và xác thực server CN `hq-c2s-server`. Không đổi port sang 1195, không dùng cert `branch-gw`. Mỗi profile client chỉ dùng cho một máy thử tại một thời điểm.

## 6 Kiểm tra C2S khi đã Connect

Trong PowerShell:

```powershell
ipconfig
route print -4
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '10.8.0.*' }
Get-NetRoute -AddressFamily IPv4 -DestinationPrefix 192.168.10.0/24
ping -n 3 10.8.0.1
ping -n 3 192.168.10.50
Test-NetConnection 192.168.10.50 -Port 80
curl.exe --noproxy '*' --fail --connect-timeout 3 --max-time 6 http://192.168.10.50/api/identity
Start-Process 'http://192.168.10.50'
```

Kỳ vọng có IP VPN **10.8.0.x**, route HQ-LAN qua adapter VPN, TCP80/HTTP thành công. Không bắt buộc IP phải là `.2` hoặc adapter phải có tên TAP/Wintun. Profile là split tunnel vào HQ LAN, không cấp Internet qua VPN.

Portal có thể thấy **`192.168.10.1`** do NAT C2S tại HQ-GW; điều này phù hợp cấu hình. IP client thật xem ở `ipconfig`/Get-NetIPAddress và status/log OpenVPN. Portal không tự chứng minh danh tính nhân viên hay cipher.

Trên **HQ-GW**, sau khi Windows đã Connect và chờ khoảng 5 giây, người quản trị chạy:

```bash
cd ~/vpn-lab
sudo bash scripts/verify-c2s.sh server
sudo cat /var/log/openvpn/openvpn-c2s-status.log
```

Status phải có CN `client1`. Dòng journal/service active mà chưa có phiên và lưu lượng thật chưa đủ nghiệm thu.

## 7 Tải payload và thử ngắt VPN

Tải file trong PowerShell:

```powershell
$payloadPath = Join-Path $env:TEMP 'vpn-benchmark.dat'
curl.exe --noproxy '*' --fail --connect-timeout 3 --max-time 20 -o "$payloadPath" http://192.168.10.50/files/benchmark-payload-1mb.dat
if ($LASTEXITCODE -eq 0) {
    Get-Item -LiteralPath $payloadPath | Select-Object Name, Length
    Get-FileHash -LiteralPath $payloadPath -Algorithm SHA256
}
```

Đúng 1.048.576 byte và hash trùng HQ-Server. Sau khi hoàn tất deploy trên mọi máy, ngắt NIC NAT tạm, thử lại HTTP khi đang Connect. Chọn `client1 → Disconnect`, dùng request mới:

```powershell
curl.exe --noproxy '*' --connect-timeout 2 --max-time 4 http://192.168.10.50/
route print -4
```

Kỳ vọng HTTP lỗi/timeout, route HQ do VPN cấp được gỡ. Branch-PC vẫn truy cập được Portal qua S2S. Connect lại để xác nhận khôi phục.

Nếu muốn dùng tiện ích kiểm tra tự động, chép riêng `scripts/verify-c2s-windows.ps1` từ repo vào Downloads rồi chạy lúc đúng trạng thái:

```powershell
powershell -NoProfile -File "$env:USERPROFILE\Downloads\verify-c2s-windows.ps1" -ExpectedState Connected
# Sau khi Disconnect trong GUI:
powershell -NoProfile -File "$env:USERPROFILE\Downloads\verify-c2s-windows.ps1" -ExpectedState Disconnected
```

Nếu execution policy chặn tệp, dùng các lệnh thủ công phía trên; không cần đổi chính sách toàn máy để hoàn thành demo.

## 8 Khoanh vùng lỗi trên Windows

| Triệu chứng | Kiểm tra |
| --- | --- |
| Không ping được WAN HQ | NIC WAN-Net, MAC, Connected, IP/mask và IP HQ-GW |
| GUI chưa có profile | Import tệp sinh thật client1.ovpn; kiểm tra biểu tượng system tray |
| TLS/certificate lỗi | Đồng hồ Windows/HQ, đúng CA, cert chưa bị revoke, pin server đúng CN |
| Lỗi tạo adapter hoặc route | Service/driver của bộ cài, quyền GUI và View Log; không tự đặt IP adapter VPN |
| Connected nhưng không vào web | Route HQ qua VPN, proxy, HQ-Server/Nginx và NAT/forwarding HQ-GW |
| Tắt VPN vẫn vào web | Dùng curl mới không proxy, kiểm tra tunnel khác còn chạy, NIC nối nhầm LAN hoặc route ngoài lab |

Tiếp tục [nghiệm thu toàn hệ thống](06-acceptance.md), đặc biệt phép thử tự thêm route trực tiếp từ WAN khi VPN tắt.
