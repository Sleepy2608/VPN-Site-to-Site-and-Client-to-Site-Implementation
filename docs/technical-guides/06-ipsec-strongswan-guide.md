# Phần mở rộng: Site-to-Site IPsec IKEv2 bằng strongSwan

IPsec là mode Site-to-Site thứ hai của lab 5 máy. OpenVPN Client-to-Site tiếp tục chạy độc lập trên HQ-GW. Mode IPsec đã được kiểm thử trên bốn Linux qua SSH. Xem [bằng chứng triển khai trực tiếp](../deployment/live-lab-status.md#triển-khai-ipsec-ngày-21112026).

## Cấu hình và khác biệt

Hai LAN vẫn là HQ `10.74.10.0/24` và Branch `10.74.20.0/24`; hai WAN `172.16.1.10` và `.20`. IPsec dùng chính sách Linux XFRM, không cấp dải tunnel `10.9.0.0/24` và không cần tun0/tun1 cho S2S.

Cấu hình nguồn ở `ipsec/strongswan/gateway-hq/` và `gateway-branch/`. Dùng IKEv2, PSK, tunnel mode:

```text
ike=aes256gcm16-prfsha256-modp2048!
esp=aes256gcm16-modp2048!
```

AES-GCM là AEAD nên ESP không thêm `sha256` làm integrity riêng. IKE vẫn cần PRF cho dẫn xuất khóa. Tham khảo [strongSwan Algorithm Proposals](https://docs.strongswan.org/docs/latest/config/proposals.html).

Branch-GW chủ động kết nối và kết nối lại. HQ-GW nạp cấu hình để nhận IKEv2. Chỉ một đầu khởi tạo để tránh hai phiên S2S cùng được thương lượng lúc khởi động.

## Chuẩn bị PSK riêng cho lab

Tạo một khóa ngẫu nhiên bằng `openssl rand -hex 32` trên máy quản trị. Dùng **cùng giá trị** trên hai gateway, chuyển qua kênh tin cậy; không commit vào repo hay đưa vào ảnh/log báo cáo.

Trên mỗi gateway, tạo `/etc/vpn-lab/ipsec.secrets` bằng quyền root, quyền tệp 600, theo cấu trúc:

```text
172.16.1.10 172.16.1.20 : PSK "REPLACE_WITH_RANDOM_SHARED_SECRET"
```

```bash
sudo mkdir -p /etc/vpn-lab
sudoedit /etc/vpn-lab/ipsec.secrets
sudo chmod 600 /etc/vpn-lab/ipsec.secrets
```

Chỉ chạy sau khi đã thay placeholder bằng đúng 64 chữ số hex được tạo ở trên; script từ chối định dạng khác. Không dùng khóa công khai của bản repo cũ hoặc chép nguyên tệp `.example`. Script mặc định đọc đường dẫn trên; có thể truyền `PSK_FILE` bằng `sudo env PSK_FILE=/duong/dan/tep-rieng ...`.

## Triển khai và chuyển mode trên cả hai gateway

Giữ NIC NAT tạm cho bước apt; tắt trước nghiệm thu. Khai báo NIC thật tại `/etc/vpn-lab/interfaces.conf` như mô hình OpenVPN.

```bash
# Trên HQ-GW:
sudo bash scripts/deploy-ipsec-hq.sh
# Trên Branch-GW:
sudo bash scripts/deploy-ipsec-branch.sh
```

Bộ deploy cài rõ `strongswan-starter` và `strongswan-charon` để đọc `/etc/ipsec.conf` và `/etc/ipsec.secrets`. Trên Ubuntu 26.04, gói meta `strongswan` có thể chọn `charon-systemd` với `swanctl`, dùng bộ cấu hình khác. Kiểm tra SA sau khi dịch vụ lên ở cả hai đầu.

Nếu cả hai công nghệ đã được cài và cấu hình:

```bash
# Chạy cùng mode trên HQ-GW trước, rồi đến Branch-GW:
sudo bash scripts/switch-vpn-mode.sh ipsec
sudo bash scripts/switch-vpn-mode.sh status
# Khi quay về bài chính, chạy trên CẢ HAI gateway:
sudo bash scripts/switch-vpn-mode.sh openvpn
```

Script tắt autostart mode cũ, bật mode đã chọn và cập nhật firewall. Không dùng đồng thời hai đường S2S tới cùng subnet. C2S trên HQ vẫn giữ nguyên.

## Firewall và nghiệm thu

Firewall chung mở IKE UDP 500/4500 và ESP từ peer WAN đã cấu hình. Lưu lượng liên LAN chỉ được forward khi khớp `-m policy --pol ipsec`, đúng hướng in/out và endpoint tunnel; có miễn NAT trước rule NAT cũ. Khi mất SA/policy, không được đi bản rõ ra WAN. Không chỉ ACCEPT theo cặp subnet.

```bash
# Tại từng gateway (chỉ định đúng vai trò):
sudo bash scripts/verify-ipsec.sh hq-gw
sudo ipsec statusall
sudo ip -s xfrm state list nokeys
# Tại Branch-GW:
sudo bash scripts/verify-ipsec.sh branch-gw
# Branch-PC:
ping -c 3 -W 2 10.74.10.50
curl --noproxy '*' --fail --max-time 6 http://10.74.10.50/
# HQ-Server, chiều khởi tạo ngược:
ping -c 3 -W 2 10.74.20.50
```

Phải có IKE SA `ESTABLISHED`, CHILD SA `INSTALLED, TUNNEL`, selector hai LAN và counter tăng khi tạo traffic. Kiểm tra sai PSK, ngắt cả hai đầu IPsec và route dự phòng, reboot rồi đo lại. Linux có thể quan sát gói sau giải mã tại host thực hiện IPsec; dùng máy quan sát riêng trên WAN nếu cần chứng minh không có bản rõ trên đường truyền. Ghi kết quả thực, không dùng mẫu log làm bằng chứng.

Để trình diễn Wireshark, mở hai capture thật của cùng lần tải file. Lọc `esp` ở WAN và `http.request.method == "GET"` ở LAN. [PCAP WAN](../../tests/captures/samples/ipsec-s2s-wan-2026-11-21.pcap) · [PCAP LAN](../../tests/captures/samples/ipsec-s2s-lan-2026-11-21.pcap)
