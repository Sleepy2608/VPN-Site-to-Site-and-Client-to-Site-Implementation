# Windows tối thiểu và chuẩn bị Remote-PC

Đối chiếu nguồn chính thức ngày **19/11/2026**. Mô hình VMware gồm **3 Armbian không GUI + 1 Armbian GUI Branch-PC + 1 Windows Remote-PC**. Chỉ Remote-PC dùng Windows; hướng dẫn [Armbian/VMware](09-armbian-vmware-guide.md) dành cho 4 VM còn lại.

## 1. Cần Windows mấy?

| Mức yêu cầu | Kết luận |
| --- | --- |
| Hệ điều hành tối thiểu cho OpenVPN GUI hiện hành | **Windows 10 trở lên** theo OpenVPN Community; không dùng Windows 7/8/8.1 cho quy trình này |
| Cấu hình Windows 10 chọn cho lab | **Windows 10 22H2 64-bit**, cập nhật đầy đủ; đây là baseline thực tế của lab, không phải khẳng định OpenVPN chỉ chạy từ 22H2 |
| Khuyến nghị cho cài đặt mới | **Windows 11 64-bit ở phiên bản còn được Microsoft hỗ trợ**, phù hợp phần cứng/VM |
| Home hay Pro? | Bài lab chỉ dùng VPN client, trình duyệt và công cụ kiểm tra; không cần tính năng Windows Server/Hyper-V trên Remote-PC, Home hoặc Pro đều phù hợp |
| Wireshark trên cùng Remote-PC | Dùng bản 64-bit tương thích đúng Windows/build; Wireshark hiện đại không còn hỗ trợ Windows 32-bit |

OpenVPN Community cung cấp installer với OpenVPN GUI và hỗ trợ Windows từ 10 trở lên. Không cần cài Access Server/CloudConnexa để dùng profile trong repo. [OpenVPN Community](https://openvpn.net/community/), [OpenVPN GUI](https://github.com/OpenVPN/openvpn-gui).

Windows 10 Home/Pro đã kết thúc hỗ trợ thông thường ngày **14/10/2025**. Việc OpenVPN còn chạy được khác với việc hệ điều hành còn được cập nhật bảo mật; ESU/LTSC có điều kiện/vòng đời riêng. Vì vậy ưu tiên Windows 11 cho VM mới. [Microsoft Lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro).

Wireshark đã ngừng hỗ trợ Windows 32-bit sau nhánh 3.6 và các nhánh mới có yêu cầu Windows/build riêng. Chọn x64 cho lab và đối chiếu trang tải/yêu cầu của bản cài, không cài bản cũ chỉ để dùng Windows 7/8. [Wireshark System Requirements](https://www.wireshark.org/docs/wsug_html_chunked/ChIntroPlatforms.html).

## 2. Chuẩn bị VM Windows

- Chạy `winver` để xem phiên bản/build; vào Settings → System → About để kiểm tra 64-bit.
- Gợi ý tài nguyên cho Remote-PC lab: 2 vCPU, 4 GB RAM và ổ đĩa 64 GB. Đây là phân bổ đề xuất của lab; Windows 11 vẫn cần đáp ứng [yêu cầu phần cứng chính thức của Microsoft](https://www.microsoft.com/en-us/windows/windows-11-specifications), bao gồm CPU tương thích, UEFI/Secure Boot capable và TPM 2.0.
- Gắn một adapter vào **WAN-Net**: VirtualBox Internal Network hoặc VMware LAN Segment. Đây là VM Windows thứ năm, không phải máy host.
- Có thể dùng adapter NAT tạm để tải bộ cài/cập nhật; tắt NAT trước demo. Không nối Remote-PC vào HQ-LAN-Net hoặc Branch-LAN-Net.
- Trong `ncpa.cpl`, chọn adapter WAN-Net → IPv4: IP `172.16.1.100`, subnet mask `255.255.255.0`, để trống default gateway và DNS cho card WAN giả lập.
- Nếu muốn HQ ping được Windows, mở đúng rule ICMPv4 Echo Request trên adapter/profile lab; không cần tắt toàn bộ Windows Firewall. Ping từ Windows ra HQ dùng lệnh bình thường.

## 3. Cài và kết nối OpenVPN GUI

1. Tải bản **OpenVPN Community Windows x64** ổn định từ [trang chính thức](https://openvpn.net/community/), cài với quyền quản trị và các service/driver đi kèm.
2. Repo dùng OpenVPN GUI trong bộ Community để import profile `client1.ovpn`. Không dùng tính năng VPN tích hợp Windows để import file này.
3. Cài driver mặc định của bộ cài. OpenVPN **2.7 đã bỏ Wintun**, dùng win-dco mặc định và TAP-Windows6 cho trường hợp fallback; không theo hướng dẫn cũ yêu cầu Wintun. [Release notes 2.7](https://community.openvpn.net/ReleaseHistory#OpenVPN2.7.0--Released11February2026).
4. Trên HQ-GW, profile mặc định nằm ở `~/client1.ovpn` của người chạy sudo. Chuyển sang Windows bằng Shared Folder, WinSCP hoặc SCP nếu OpenSSH Client đã cài. File có khóa riêng inline; chỉ sao chép profile, không sao chép private key của CA.
5. Mở OpenVPN GUI ở system tray → **Import file...** → chọn `client1.ovpn`. Cũng có thể đặt file trong `%USERPROFILE%\OpenVPN\config\`.
6. Chọn profile `client1` → **Connect**. Chờ trạng thái Connected và log `Initialization Sequence Completed`. Dùng service đi kèm bộ cài; nếu thao tác route/adapter bị từ chối, kiểm tra service/quyền quản trị.
7. Kiểm tra bằng PowerShell hoặc CMD:

```powershell
ipconfig
route print -4
ping -n 3 10.8.0.1
ping -n 3 192.168.10.50
Test-NetConnection 192.168.10.50 -Port 80
Invoke-WebRequest -UseBasicParsing -Method Head -Uri http://192.168.10.50 -TimeoutSec 5
Start-Process http://192.168.10.50
```

IP tunnel phải thuộc `10.8.0.0/24`, route HQ đi qua adapter OpenVPN. Tên adapter phụ thuộc driver/phiên bản, không bắt buộc mang tên TAP hay Wintun. C2S hiện dùng NAT nên Portal có thể thấy `192.168.10.1`; IP client thật xem bằng `ipconfig`.

Ngắt bằng OpenVPN GUI → `client1` → **Disconnect**. Kiểm tra route HQ đã được gỡ; trong mô hình cô lập, truy cập HQ sẽ thất bại sau khi ngắt.

## 4. Công cụ hỗ trợ demo

- `quick-setup.bat` chạy trên Windows để ping, xem route, mở Portal/OpenVPN GUI và tải tệp mẫu. Không chạy script Bash trên Windows Remote-PC.
- Capture bằng tcpdump trên Armbian HQ-GW. Chép pcap về Windows qua Shared Folder/WinSCP rồi mở bằng Wireshark; chỉ đọc pcap không đòi hỏi bắt gói trực tiếp trên Windows.
- Các chức năng SSH/SCP cần OpenSSH Client hoặc phần mềm tương đương. Nếu không có, dùng Shared Folder/WinSCP; các bước VPN, ping, route và trình duyệt vẫn thực hiện độc lập.

Xem [README](../../README.md), [kịch bản demo Windows](../presentation/demo-script.md) và [checklist](../../tests/openvpn-demo.md). Yêu cầu phiên bản được đối chiếu tài liệu nhà cung cấp, chưa phải kết quả cài/chạy VPN thực tế trong VM của nhóm.
