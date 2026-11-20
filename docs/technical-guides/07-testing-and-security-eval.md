# Kế hoạch đo kiểm và đánh giá VPN

**Đã có kết quả triển khai Linux ngày 20/11/2026 tại [báo cáo lab trực tiếp](../deployment/live-lab-status.md). Windows vẫn chờ người dùng cấu hình.** Các số RTT/throughput và nhãn PASS trong bản tài liệu trước không có log/PCAP đối chứng trong repo, đã được bỏ khỏi bảng kết quả. Xem [báo cáo rà soát](../topic14-audit.md) và [checklist nghiệm thu](../../tests/openvpn-demo.md).

## Phạm vi và phương pháp

Phương án chính là OpenVPN C2S + S2S trên 5 máy. Phải kiểm tra remote client vào host LAN HQ, hai host LAN khởi tạo lưu lượng theo cả hai chiều, từ chối truy cập trực tiếp WAN khi tự thêm route, và không đi bản rõ khi mất tunnel. IPsec là bài mở rộng, chạy cùng hạ tầng nhưng thay S2S ở cả hai gateway.

- Ping/HTTP xác nhận truy cập, không xác nhận riêng thuật toán mã hóa.
- Traceroute hỗ trợ xem đường đi; dấu `*`, địa chỉ hop hoặc thiếu IP WAN không tự chứng minh mã hóa.
- Status mới có CN chứng minh phiên tồn tại; service active đơn lẻ chưa chứng minh handshake.
- Đối chiếu log cipher với PCAP WAN và LAN/TUN của cùng lần tạo traffic. Với IPsec policy-based, bắt tại máy quan sát WAN riêng khi cần tránh nhìn nhầm gói đã giải mã trong host Linux.
- Không có gói trong capture chỉ là quan sát; phải xác nhận đúng NIC/filter, đã phát traffic và capture không lỗi.

## Bảng ghi kết quả thực

| Phép đo | Mô hình/nguồn/đích | Kết quả | Bằng chứng/ngày/phiên bản |
| --- | --- | --- | --- |
| C2S IP/route/HTTP | Windows → HQ-Server | Chưa chạy | — |
| S2S hai chiều | Branch-PC ↔ HQ-Server | Đạt trên VM | [Log và PCAP](../deployment/live-lab-status.md) |
| Cipher và đóng gói | WAN đối chiếu LAN/TUN | Đạt log AES-256-GCM và PCAP | [Log và PCAP](../deployment/live-lab-status.md) |
| Từ chối route đi vòng VPN | Windows WAN → HQ LAN | Linux tương đương đạt; Windows chưa thử | [Log và PCAP](../deployment/live-lab-status.md) |
| Chống bản rõ khi tunnel ngắt | Branch LAN → HQ LAN qua route WAN dự phòng | Đạt; 0 gói LAN bản rõ, counter DROP tăng | [Log và PCAP](../deployment/live-lab-status.md) |
| CRL và sai vai trò chứng chỉ | Kết nối mới tới HQ | Chưa chạy | — |
| Khôi phục sau reboot | Hai gateway và HQ-Server | Đạt trên bốn Linux | [Log và PCAP](../deployment/live-lab-status.md) |
| RTT/loss, 100 ping | Branch-PC → HQ-Server | Chưa đo | — |
| Tải payload 1 MiB | Client → HQ-Server | Đạt chức năng: đúng byte/hash; chưa đo hiệu năng lặp lại | [Log và PCAP](../deployment/live-lab-status.md) |
| IPsec S2S nếu thực hiện | Hai LAN + XFRM/ESP | Chưa chạy | — |

## Đo hiệu năng có thể lặp lại

Ghi CPU/RAM VM, phiên bản kernel/OpenVPN/strongSwan, DCO bật/tắt và cấu hình cipher trước mỗi lần đo. Giữ cùng tài nguyên và tải nền khi so sánh; báo cáo ít nhất ba lần cùng median và khoảng min–max.

```bash
# Branch-PC, sau khi xác nhận S2S hoạt động:
ping -c 100 -W 2 192.168.10.50
curl --noproxy '*' --fail --connect-timeout 3 --max-time 30 -o /tmp/vpn-benchmark.dat \
  -w 'bytes=%{size_download} seconds=%{time_total} bytes_per_second=%{speed_download}\n' \
  http://192.168.10.50/files/benchmark-payload-1mb.dat
wc -c /tmp/vpn-benchmark.dat
sha256sum /tmp/vpn-benchmark.dat
# HQ-Server: đối chiếu hash tệp tại /var/www/vpn-lab-portal/files/.
```

Tệp đúng 1.048.576 byte. Tải 1 MiB chỉ là kiểm tra ứng dụng sơ bộ, chịu ảnh hưởng handshake TCP/cache; không đủ để kết luận băng thông cực đại. Muốn đo throughput, cài iperf3 khi còn Internet, chạy server tại HQ-Server và đo cùng tham số/thời lượng giữa các mode. Không khẳng định IPsec luôn nhanh hơn; OpenVPN cũng có DCO tùy phiên bản/nền tảng, còn baseline server của bài này chủ động tắt DCO để dễ đối chứng TUN.

## Đánh giá an ninh trong phạm vi lab

| Rủi ro | Cơ chế hiện có | Giới hạn cần trình bày |
| --- | --- | --- |
| Nghe lén/sửa nội dung trên WAN | AES-GCM và TLS/PKI | HTTP vẫn bản rõ trong LAN sau giải mã; cần HTTPS nếu muốn bảo vệ ở tầng ứng dụng |
| Giả mạo endpoint hoặc dùng sai vai trò | CA, kiểm tra EKU/CN, CCD allowlist | Profile chứa khóa riêng phải bảo vệ; NAT không định danh từng người dùng |
| Thiết bị mất quyền truy cập | CRL | CRL mới chặn handshake; phiên cũ cần chủ động ngắt/restart |
| Truy cập WAN đi vòng tunnel | Firewall giới hạn interface/subnet/policy | Cần kiểm thử cả route thủ công, counters và reboot; mới áp dụng IPv4 |
| Gói điều khiển không hợp lệ | tls-crypt | Không bảo đảm chống được UDP flood/DoS làm đầy đường truyền |
| Lộ CA/PSK | Quyền tệp, staging riêng, không commit profile thật | CA nopass và đặt cùng gateway là lựa chọn lab; production nên tách CA và quy trình cấp phát |

Nguồn: [OpenVPN 2.6 manual](https://build.openvpn.net/man/openvpn-2.6/openvpn.8.html), [strongSwan proposal](https://docs.strongswan.org/docs/latest/config/proposals.html). Các kết luận triển khai trong tài liệu phải dựa trên bảng bằng chứng thực tế, không chỉ dựa trên có tệp cấu hình.
