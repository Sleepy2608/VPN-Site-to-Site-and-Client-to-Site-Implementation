# Rà soát mức đáp ứng Chủ đề 14 — 20/11/2026

> Cập nhật sau đánh giá ban đầu: bốn Linux đã được triển khai trực tiếp trên VMware. Xem [trạng thái lab và bằng chứng thực tế](deployment/live-lab-status.md). Các trạng thái chưa chạy bên dưới mô tả thời điểm rà soát trước triển khai; Windows vẫn do người dùng tự cấu hình.

## Kết luận và phạm vi

Tên đề tài yêu cầu **hai loại VPN: Site-to-Site và Client-to-Site**. Người dùng chưa cung cấp rubric chi tiết của giảng viên; các tiêu chí dưới đây là mức kỹ thuật tối thiểu được suy ra từ tên đề tài và mục tiêu đã ghi trong repo, không phải một bảng chấm điểm chính thức.

**Trước bổ sung: chưa đủ nếu chỉ dùng bài demo 3 máy đang được README ưu tiên.** Linux Server + Linux Client + Windows Client đều ở WAN-Net, hai client truy cập web trên IP tunnel server. Bài này chứng minh remote access đa hệ điều hành; chưa có hai LAN và hai gateway chuyển tiếp cho các host LAN.

**Sau bổ sung: repo có phương án triển khai 5 máy để đáp ứng đủ về thiết kế/cấu hình/quy trình. Chưa nghiệm thu hoạt động thực tế.** Máy hiện tại chạy Windows/Git Bash, chưa có Linux VPN/VM đang được kết nối để kiểm chứng; các test offline không xác nhận handshake, XFRM, driver Windows hay cấu hình VMware.

## So sánh các mô hình đang có

| Tiêu chí | 3 máy C2S | 5 máy OpenVPN C2S + S2S | 5 máy OpenVPN C2S + IPsec S2S |
| --- | --- | --- | --- |
| Vai trò | Server, Linux client, Windows client | Hai gateway, hai host LAN, Windows remote | Giữ cùng năm vai trò |
| Tài nguyên | Web gắn IP tunnel `10.8.0.1` | HQ-Server riêng `192.168.10.50` | HQ-Server riêng `192.168.10.50` |
| LAN riêng ở hai site | Chưa có | HQ `192.168.10.0/24`, Branch `192.168.20.0/24` | Cùng hai LAN |
| Client-to-Site | Có hai client | Remote-PC → HQ bằng OpenVPN | Giữ OpenVPN C2S |
| Site-to-Site | Chưa có | Branch-GW ↔ HQ-GW, UDP 1195 | IKEv2/ESP, policy-based XFRM |
| VPN agent trên host LAN | Linux VM là VPN client | HQ-Server/Branch-PC không cần VPN agent | HQ-Server/Branch-PC không cần VPN agent |
| Mức đáp ứng tên đề tài | Một phần | **Đủ phạm vi thiết kế; chọn làm phương án chính** | Đủ phạm vi thiết kế, mở rộng tùy chọn |
| Tài nguyên cần bổ sung từ 3 máy | — | Thêm hai VM; chuyển Linux client thành Branch-GW và thêm hai host LAN | Cùng yêu cầu hạ tầng, thêm cấu hình IPsec |

Không cần triển khai hai công nghệ để có hai loại VPN. OpenVPN thực hiện được cả C2S và S2S. IPsec là lựa chọn so sánh bổ sung nếu rubric yêu cầu hoặc nhóm muốn trình bày thêm.

## Ma trận yêu cầu và bằng chứng nghiệm thu

| Yêu cầu | Hiện thực trong repo sau rà soát | Bằng chứng phải thu trên VM | Trạng thái |
| --- | --- | --- | --- |
| Hai LAN khác subnet, định tuyến qua hai gateway | Netplan 4 node, WAN-Net/HQ-LAN-Net/Branch-LAN-Net | NIC/MAC, `ip -br a`, route; không còn NAT phụ khi demo | Chưa chạy VM |
| Site-to-Site trong suốt với host | OpenVPN tun1 HQ/tun0 Branch, route + CCD/iroute, IP Branch `.2` cố định | Ping HQ-Server → Branch-PC và chiều ngược; HTTP từ Branch; PC không chạy VPN client | Có cấu hình; chưa chạy VM |
| Client-to-Site vào tài nguyên HQ | OpenVPN C2S, profile Windows, split route HQ | IP `10.8.0.x`, route qua VPN, HTTP 200, CN `client1` trong status mới | Có cấu hình; chưa chạy VM |
| Xác thực hai đầu và phân vai | CA/Easy-RSA, client/server EKU, pin CN server, CCD exclusive C2S, S2S chỉ CN branch-gw | Handshake hợp lệ; profile sai vai trò/CA/khóa bị từ chối | Có cấu hình; chưa chạy VM |
| Mã hóa/toàn vẹn WAN | TLS >=1.2, `data-ciphers AES-256-GCM`, `tls-crypt`, tắt compression | Log cipher thương lượng + cùng lần tải file ở PCAP WAN và LAN/TUN | Có cấu hình; chưa chạy VM |
| Chỉ truy cập LAN qua VPN | Chain quản lý riêng trước rule cũ; DROP chuyển tiếp ngoài luồng cho phép | Remote tắt VPN, tự thêm route tới HQ LAN vẫn không vào được; counter DROP tăng | Đã kiểm tra logic offline; chưa chạy VM |
| Ngắt S2S không đi bản rõ ra WAN | FORWARD allow theo tunnel/policy; OUTPUT guard tới subnet nội bộ | Ngắt client S2S, tạo route dự phòng WAN có chủ đích, phát traffic, PCAP/counter đối chứng | Đã kiểm tra logic offline; chưa chạy VM |
| Thu hồi chứng chỉ | `revoke-client.sh`, CRL publish nguyên tử, tùy chọn ngắt phiên | Sau revoke thử kết nối mới và kiểm tra lỗi chứng chỉ bị thu hồi | Chưa chạy VM |
| Vận hành sau reboot | systemd enable, sysctl và iptables-persistent; mode S2S chọn nhất quán | Reboot hai gateway + server, C2S/S2S hoạt động lại | Chưa chạy VM |
| Hiệu năng và báo cáo trung thực | Payload đúng 1 MiB; HTTP có timeout; bảng đo để trống | Phiên bản, tài nguyên VM, RTT/loss, thời gian tải, dung lượng/hash thực | Chưa đo |

C2S NAT là lựa chọn triển khai hợp lệ cho remote access một chiều khởi tạo từ client. Portal sẽ thấy `192.168.10.1`; không suy ra danh tính nhân viên từ địa chỉ này. S2S giữ IP hai LAN, không NAT.

## Các lỗi đã sửa trong lần rà soát này

| Mức | Trước sửa | Bổ sung/sửa |
| --- | --- | --- |
| Cao | README ưu tiên mô hình 3 máy như bài demo hiện tại, dễ bỏ phần S2S | Đặt 5 máy là phương án chính; 3 máy ghi rõ chỉ C2S; đồng bộ mục lục demo |
| Cao | Firewall chỉ thêm ACCEPT; client trên WAN có thể tự thêm route vào LAN | Dùng `VPN_LAB_FORWARD`, `VPN_LAB_WAN_IN`, `VPN_LAB_WAN_OUT`; hook trước rule cũ; giới hạn interface/subnet và DROP phần còn lại |
| Cao | Mỗi script deploy tự thêm rule khác nhau | C2S/S2S và IPsec cùng gọi một chính sách firewall; chặn cả lưu lượng gateway tự sinh đi bản rõ tới LAN qua WAN |
| Cao | Chứng chỉ cùng CA có thể dùng sai endpoint | C2S chỉ các CN có CCD riêng (mặc định `client1`), S2S pin `branch-gw` và CCD; client pin đúng CN server; server kiểm tra chứng chỉ loại client |
| Cao | `cipher` chưa xác định rõ tập cipher thương lượng trên OpenVPN mới | Dùng `data-ciphers AES-256-GCM`, TLS tối thiểu, không compression; kiểm tra OpenVPN >=2.5; từ 2.6 tắt DCO cho phép đối chứng TUN ổn định |
| Cao | IPsec dùng PSK công khai trong repo, proposal ESP GCM kèm integrity riêng | Bắt buộc PSK riêng; sửa IKE thành `aes256gcm16-prfsha256-modp2048!`, ESP `aes256gcm16-modp2048!`; policy IPsec ràng buộc hướng và endpoint |
| Vừa | Deploy S2S HQ độc lập chưa chuẩn bị đầy đủ CA/DH/TLS key/CRL | Kiểm tra/copy từng tệp bắt buộc; cài CCD đúng CN, gỡ alias cũ tại đích |
| Vừa | Phân phối khóa qua tên cố định `/tmp/branch-gw.key` trước khi siết quyền | Thư mục staging ngẫu nhiên quyền riêng ở hai máy, khóa mode 600 từ đầu, kiểm tra user/host/path, dọn staging |
| Vừa | Verify C2S có thể thành công khi không có client; verify S2S nhìn tên subnet dù route sai interface | Status phải mới và có đúng CN; kiểm tra route thực qua tun; dùng nguồn LAN khi ping từ gateway; thêm vai trò HQ-Server kiểm tra chiều ngược |
| Vừa | Verify IPsec nhận vai trò sai hoặc chỉ cần chuỗi TUNNEL | Từ chối vai trò không hợp lệ, yêu cầu INSTALLED, TUNNEL và có XFRM policy; vẫn cần đo LAN-to-LAN riêng |
| Vừa | Capture bỏ qua lỗi tcpdump; tệp có header nhưng không có packet có thể bị coi là bằng chứng | Thêm giới hạn thời gian, kiểm tra mã lỗi và số packet; 0 packet không tự chứng minh an toàn |
| Vừa | Portal bind mọi NIC, tải font Internet trong lab cô lập | Bind HQ LAN và loopback, dùng font dự phòng offline, API không cache; giữ web root riêng |
| Vừa | Profile sinh ở ngoài thư mục client có thể không được gitignore | Bỏ qua `.ovpn` được sinh ở toàn repo, vẫn giữ template/example |
| Vừa | Có nhãn PASS, RTT/throughput cụ thể và kết luận an toàn tuyệt đối chưa có artifact đối chứng | Đổi thành bảng chờ đo, checklist thực nghiệm và giới hạn kết luận; bỏ liên kết file tuyệt đối cũ |

Những thay đổi đã có sẵn trong workspace trước lượt này (đường dẫn CA theo tài khoản sudo, NIC dùng chung, deploy-all chọn OpenVPN hai đầu, Windows client/runbook) được giữ lại và tiếp tục sử dụng; không coi chúng là thay đổi mới của lần này.

## Phạm vi mã đã rà soát

- Toàn bộ script Bash deploy/common/PKI/verify/capture/chuyển mode; tiện ích BAT Windows và script kiểm tra PowerShell bổ sung.
- OpenVPN server/client/CCD/vars, strongSwan hai đầu/secrets template, bốn mẫu Netplan.
- Portal HTML/CSS/JavaScript và ba tệp tải; tài liệu topology/PKI/C2S/S2S/IPsec, runbook/demo/slides, test/capture và README.
- Kiểm tra hồi quy offline chạy qua Bash thật với lệnh hệ thống giả lập: không thay đổi firewall, service hoặc chứng chỉ của máy người dùng.

## Cách chuyển từ bài 3 máy sang bài đủ chủ đề

1. Giữ Linux Server làm **HQ-GW**, có WAN `172.16.1.10` và thêm NIC HQ-LAN `192.168.10.1`.
2. Chuyển Linux Client thành **Branch-GW**, giữ WAN `172.16.1.20`, thêm NIC Branch-LAN `192.168.20.1`; dùng chứng chỉ `branch-gw`, không dùng profile C2S cũ.
3. Giữ Windows làm **Remote-PC**, WAN `172.16.1.100`; import `client1.ovpn` của phương án 5 máy.
4. Thêm **HQ-Server** `192.168.10.50`, gateway `192.168.10.1`, và **Branch-PC** `192.168.20.50`, gateway `192.168.20.1`.
5. Tạo ba LAN Segment, nối NIC theo [README](../README.md). Tạm có NAT để tải gói, ngắt trước nghiệm thu.
6. Dừng/tắt autostart `openvpn-server@demo` trên Linux Server và `openvpn-client@demo-linux` trên Linux Client nếu đã dùng bài 3 máy; không để chúng chiếm tun0/UDP1194. Không xóa PKI của bài cũ.
7. Triển khai theo runbook 5 máy. Portal mới chạy trên HQ-Server, không dùng `10.8.0.1` làm tài nguyên nghiệm thu. Sau khi lab mới chạy đạt, dừng Nginx demo cũ trên HQ-GW nếu còn chạy.
8. Thu bằng chứng theo [checklist](../tests/openvpn-demo.md) trước khi ghi kết luận đạt đề tài.

## Kiểm chứng và giới hạn

Chạy `python -m unittest discover -s tests -p test_repository.py -v` để kiểm tra cú pháp toàn bộ Bash, đầu vào sai, status cũ/rỗng/sai CN, route sai interface, và các luồng firewall được sinh khi chạy lại trên cả hai vai trò/hai mode. Bộ kiểm thử có giả lập command và đánh giá rule; không thay thế kernel Linux/XFRM/conntrack, OpenVPN thật hoặc Wireshark.

Kết quả kiểm tra tại workspace ngày 20/11/2026:

| Kiểm tra mã/tài liệu | Kết quả |
| --- | --- |
| Bộ hồi quy Python/Git Bash | **9/9 test đạt**, gồm các ca con cho HQ/Branch và OpenVPN/IPsec |
| Cú pháp Bash | **28/28 script hợp lệ** qua bash -n |
| Cú pháp PowerShell mới | Parser không báo lỗi |
| JavaScript Portal | node --check không báo lỗi |
| Liên kết Markdown nội bộ | Không có liên kết đích bị thiếu |
| Dung lượng benchmark | Đúng 1.048.576 byte |
| git diff --check | Không có lỗi whitespace; Git có cảnh báo chuyển LF/CRLF cho một số tệp text |

Các phép thử mới còn bao gồm capture rỗng/lỗi, PSK mẫu/sai định dạng, tên profile chứa path traversal và tương thích tùy chọn DCO giữa OpenVPN 2.5/2.6. Chưa chạy ShellCheck, OpenVPN/strongSwan parser thực, Nginx trên Linux hoặc VM end-to-end.

Chưa có bằng chứng VM để xác nhận đạt end-to-end. Cần hoàn tất cả phép thử dương, âm và reboot trong checklist. Phạm vi lab là IPv4 và WAN giả lập không NAT trung gian; IPv6, MFA, HA, HTTPS end-to-end và triển khai Internet thật chưa phải kết quả của bài này. Không suy ra “chống mọi DoS”, “an toàn tuyệt đối” hoặc “IPsec luôn nhanh hơn” từ cấu hình hiện có.

## Nguồn kỹ thuật đối chiếu

- [OpenVPN: mở rộng VPN tới subnet hai đầu](https://openvpn.net/community-docs/expanding-the-scope-of-the-vpn-to-include-additional-machines-on-either-the-client-or-server-subnet/): subnet riêng, forwarding, route và iroute.
- [OpenVPN 2.6 manual](https://build.openvpn.net/man/openvpn-2.6/openvpn.8.html): data-ciphers, remote-cert-tls, verify-x509-name, CCD, CRL, status và DCO.
- [strongSwan: Algorithm Proposals](https://docs.strongswan.org/docs/latest/config/proposals.html): AEAD GCM, PRF cho IKE và proposal ESP không có integrity riêng.
- [iptables extensions: policy](https://man7.org/linux/man-pages/man8/iptables-extensions.8.html): khớp policy IPsec theo in/out, tunnel và endpoint.
