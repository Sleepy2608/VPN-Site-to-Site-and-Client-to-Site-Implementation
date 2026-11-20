# Rà soát repository ngày 18/11/2026

> Báo cáo lịch sử ngày 18/11. Nhiều lỗi bên dưới đã được sửa trong các thay đổi hiện tại. Xem [rà soát Chủ đề 14 ngày 20/11](topic14-audit.md) để biết trạng thái mới và giới hạn kiểm chứng.

Phạm vi: README, tài liệu kỹ thuật, kịch bản demo, ma trận kiểm thử, toàn bộ script Bash, cấu hình Netplan/OpenVPN/strongSwan, tiện ích Windows và Portal. Đây là báo cáo rà soát; chưa sửa các tệp triển khai và chưa chạy lab VPN thực tế.

## 1. Ba mạng trong README có mâu thuẫn không?

Ba subnet không chồng lấn và đúng với bảng IP/cấu hình hiện tại:

| Mạng | Subnet | Thiết bị nối vào |
| --- | --- | --- |
| WAN-Net | 172.16.1.0/24 | WAN HQ-GW (.10), WAN Branch-GW (.20), Remote PC (.100) |
| HQ-LAN-Net | 192.168.10.0/24 | LAN HQ-GW (.1), HQ-Server (.50) |
| Branch-LAN-Net | 192.168.20.0/24 | LAN Branch-GW (.1), Branch-PC (.50) |

Tên WAN-Net mô tả vai trò WAN giả lập. Một mạng VirtualBox loại Internal Network vẫn có thể đóng vai trò WAN của lab; tên WAN không bắt buộc phải có Internet thật. Tên mạng ảo cũng không tự gán subnet: địa chỉ IP phải được cấu hình trong từng máy.

Mâu thuẫn nằm ở điều kiện triển khai:

- Nếu Remote PC là **VM Windows thứ năm**, có thể dùng Internal Network cho cả ba mạng. Host không trực tiếp tham gia WAN-Net. VMware Workstation dùng LAN Segment cho mô hình tương đương.
- Nếu Remote PC là **Windows host**, WAN-Net phải cho host tham gia, ví dụ Host-only Network. Chỉ đổi loại mạng WAN; giữ hai LAN riêng biệt. Đặt IP adapter host là 172.16.1.100/24 và tránh trùng IP DHCP.
- Cả hai phương án trên đều không tự cung cấp Internet. Phải cài gói/chuyển repo trước khi cô lập, hoặc thêm adapter NAT quản trị tạm thời cho từng VM cần tải gói. Gỡ/tắt adapter đó trước kiểm thử cô lập, kiểm tra lại route và DNS. Chỉ thêm NAT cho gateway chưa đủ để các máy LAN tải gói nếu chưa cấu hình đường ra/NAT chuyển tiếp.
- Dải 10.8.0.0/24 và 10.9.0.0/24 là mạng tunnel OpenVPN, không cần tạo thêm virtual switch. IPsec hiện là policy-based giữa hai LAN, không sử dụng dải tunnel 10.9.0.0/24. Sơ đồ README đang gộp hai công nghệ dưới cùng nhãn dải tunnel, cần tách rõ.

Nguồn đối chiếu: [Oracle VirtualBox Networking](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/networkingdetails.html).

## 2. Những lỗi cần ưu tiên sửa

P1: ảnh hưởng trực tiếp đến triển khai hoặc ranh giới truy cập. P2: làm sai kết quả nghiệm thu, vận hành hoặc tài liệu.

### 01 — P1: Tường lửa chưa thực thi yêu cầu “chỉ truy cập LAN qua VPN”

Vị trí: [setup-firewall-rules.sh](../scripts/common/setup-firewall-rules.sh#L40), [deploy-ipsec-hq.sh](../scripts/deploy-ipsec-hq.sh#L80), [deploy-ipsec-branch.sh](../scripts/deploy-ipsec-branch.sh#L75).

Script chủ yếu thêm ACCEPT, không thiết lập chính sách chặn truy cập từ WAN vào LAN. Với máy có FORWARD mặc định ACCEPT, một máy trên WAN có thể thêm route đến HQ LAN qua 172.16.1.10 và đi vào LAN mà không cần VPN. Hai script IPsec còn ACCEPT theo cặp subnet mà không ràng buộc chính sách IPsec.

Hệ quả: các phát biểu “không có route nên an toàn”, “Killswitch”, “VPN tắt thì hoàn toàn không truy cập được” chưa được đảm bảo bởi cấu hình. Việc thiếu route ở một client không phải quy tắc kiểm soát truy cập.

Hướng sửa: áp dụng quy tắc có thứ tự cho lưu lượng TUN và policy IPsec, chặn WAN → LAN chưa được giải mã/xác thực, chặn lưu lượng liên site đi ra WAN dạng bản rõ. Kiểm thử cả trường hợp client tự thêm route và gateway có default route. Giữ đường quản trị SSH theo chủ đích để tránh tự khóa truy cập.

### 02 — P1: Đường dẫn CA không thống nhất khi chạy bằng sudo

Vị trí: [init-ca.sh:12](../scripts/pki/init-ca.sh#L12), [build-client-ovpn.sh:13](../scripts/pki/build-client-ovpn.sh#L13), [distribute-certs.sh:16](../scripts/pki/distribute-certs.sh#L16), [deploy-c2s-server.sh:22](../scripts/deploy-c2s-server.sh#L22).

README và deploy-all gọi init-ca bằng sudo/root. Trên cấu hình sudo thông thường, CA được tạo ở /root/openvpn-ca; script deploy lại tìm ở /home/$SUDO_USER/openvpn-ca. Vì thế bước triển khai server báo thiếu chứng chỉ ngay sau khi vừa sinh CA.

Chiều ngược lại cũng lỗi: tài liệu PKI gọi init-ca không sudo, nhưng distribute-certs có sudo và mặc định tìm CA dưới HOME của root. Ngoài ra init-ca nhận đường dẫn qua đối số, không dùng biến CA_DIR như những script còn lại.

Hướng sửa: thống nhất cách xác định CA_DIR và truyền rõ cho mọi script; không suy luận đường dẫn khác nhau giữa các bước.

### 03 — P1: Deploy-all để hai gateway ở hai chế độ khác nhau

Vị trí: [deploy-all.sh:66](../scripts/deploy-all.sh#L66), [deploy-all.sh:91](../scripts/deploy-all.sh#L91).

HQ kết thúc bằng deploy-ipsec-hq, script này dừng OpenVPN S2S và khởi động IPsec. Branch triển khai IPsec rồi gọi switch-vpn-mode openvpn. Kết quả là HQ chạy IPsec trong khi Branch chạy OpenVPN; đường hầm S2S không hoạt động theo quy trình được giới thiệu.

Hướng sửa: chọn một chế độ mặc định cho cả hai gateway. Việc chuyển chế độ phải thực hiện trên cả hai máy. C2S trên HQ có thể tiếp tục chạy độc lập.

### 04 — P1: Quy trình thiếu bước cần thiết để triển khai được lab

Vị trí: [README:128](../README.md#L128), [README:192](../README.md#L192), [deploy-all.sh:45](../scripts/deploy-all.sh#L45), [deploy-s2s-branch.sh:42](../scripts/deploy-s2s-branch.sh#L42).

- Nhánh triển khai tự động không gọi install-prerequisites, không áp dụng Netplan và không phân phối chứng chỉ sang Branch. Nó không phải cài đặt trọn gói trên VM sạch như mô tả.
- Quy trình thủ công gọi deploy-s2s-branch nhưng thiếu bước chạy distribute-certs trên HQ trước đó. Cần ghi rõ tài khoản SSH bằng BRANCH_USER; script mặc định vpnadmin trong khi tiện ích Windows dùng student.
- Manual Deployment bỏ qua bước cấu hình Branch-PC dù mô hình cần node này: áp dụng 01-netcfg-branch-pc.yaml, cài công cụ, kiểm tra gateway 192.168.20.1.
- Topology chỉ có mạng nội bộ, gateway không có default route ra Internet, nhưng script vẫn yêu cầu apt update/install. DNS 1.1.1.1/8.8.8.8 không tự tạo được đường ra.
- Cần hướng dẫn chuẩn bị repo trên từng Ubuntu node và cài/bật SSH nếu sử dụng SCP/SSH.

Hướng sửa: thêm phần điều kiện tiên quyết dùng chung cho cả hai phương pháp; mô tả deploy-all là điều phối dịch vụ trên mạng đã chuẩn bị hoặc bổ sung đầy đủ các bước còn thiếu.

### 05 — P2: Đường dẫn client1.ovpn trong README sai

Vị trí: [README:227](../README.md#L227), [deploy-all.sh:70](../scripts/deploy-all.sh#L70), [build-client-ovpn.sh:13](../scripts/pki/build-client-ovpn.sh#L13).

README ghi /home/student/openvpn-ca/client1.ovpn. Script mặc định ghi ${HOME}/client1.ovpn; khi chạy sudo thường là /root/client1.ovpn. Đây là lỗi riêng với đường dẫn CA.

Hướng sửa: truyền output_path rõ ràng và in đúng đường dẫn thực tế; bỏ giả định tài khoản luôn tên student.

### 06 — P2: NAT C2S mâu thuẫn với tính năng nhận diện IP của Portal

Vị trí: [deploy-c2s-server.sh:105](../scripts/deploy-c2s-server.sh#L105), [app.js:67](../services/intranet-portal/js/app.js#L67), [test-cases.md:96](../tests/test-cases.md#L96).

Gateway MASQUERADE 10.8.0.0/24 ra eth1. Nginx vì vậy nhìn thấy 192.168.10.1, không phải 10.8.0.2. Portal sẽ phân loại client VPN là truy cập LAN HQ, trái với TC-04 và demo.

Hướng sửa: nếu cần quan sát IP VPN gốc, dùng routing thuần và bảo đảm route trả về 10.8.0.0/24 qua HQ-GW. HQ-Server hiện có default gateway 192.168.10.1 nên đã có cơ sở cho đường trả về. Nếu giữ NAT thì phải sửa kỳ vọng và giao diện; không gắn IP gateway với kết luận client đang ở LAN trực tiếp.

### 07 — P2: Portal hiển thị trạng thái an toàn không có bằng chứng

Vị trí: [app.js:11](../services/intranet-portal/js/app.js#L11), [app.js:24](../services/intranet-portal/js/app.js#L24), [app.js:62](../services/intranet-portal/js/app.js#L62), [index.html:129](../services/intranet-portal/index.html#L129).

Khi API lỗi hoặc không trả IP, giao diện giữ IP mẫu 10.8.0.2 và báo SECURE. Khi fetch lỗi, tham số ?ip= cũng có thể quyết định trạng thái hiển thị. Với client Branch, giao diện luôn ghi IPsec dù đường hầm có thể đang dùng OpenVPN. Các badge ONLINE/ROUTED trong HTML cũng là giá trị cố định.

Đã tái hiện bằng mô phỏng JavaScript: API lỗi → SECURE/10.8.0.2; API trả IP NAT 192.168.10.1 → LOCAL; IP Branch → IPsec bất kể chế độ gateway.

Hướng sửa: hiển thị Unknown khi không có dữ liệu API; chỉ diễn giải IP nguồn quan sát được. Muốn báo cipher/chế độ/SA thực tế phải có telemetry đáng tin cậy. VPN kết thúc tại gateway; HTTP từ gateway tới HQ-Server vẫn là bản rõ nên không nên gọi đây là mã hóa đầu cuối tới máy chủ Web.

### 08 — P2: Script nghiệm thu có thể báo thành công khi không kiểm tra gì

Vị trí: [verify-s2s.sh:65](../scripts/verify-s2s.sh#L65), [verify-ipsec.sh:88](../scripts/verify-ipsec.sh#L88), [verify-phase1.sh:82](../scripts/common/verify-phase1.sh#L82).

Đã chạy cả ba script với invalid-role: tất cả exit 0, báo 0 PASSED / 0 FAILED rồi kết luận thành công. Các case thiếu nhánh từ chối vai trò không hợp lệ và phần tổng kết chỉ xét FAIL_COUNT bằng 0.

[verify-ipsec.sh:68](../scripts/verify-ipsec.sh#L68) còn dùng INSTALLED|TUNNEL, nên chỉ cần có chữ TUNNEL trong mô tả kết nối là có thể tính CHILD_SA đạt. Thiếu policy XFRM chỉ bị coi là cảnh báo. [verify-c2s.sh:95](../scripts/verify-c2s.sh#L95) đọc phần sau header của status log và có thể tính dòng thống kê là client đang kết nối.

Hướng sửa: xác thực tham số, yêu cầu có phép kiểm tra thực sự, phân biệt health check dịch vụ với xác minh tunnel đã kết nối; kiểm tra bản ghi CLIENT_LIST và CHILD_SA INSTALLED cụ thể. Lệnh ipsec/iptables/xfrm trên gateway cần quyền root; README đang hướng dẫn một số lệnh này không sudo.

### 09 — P2: Bắt gói tin chưa đủ để đưa ra kết luận chống rò rỉ

Vị trí: [capture-traffic.sh:202](../scripts/capture-traffic.sh#L202), [capture-traffic.sh:225](../scripts/capture-traffic.sh#L225), [README:272](../README.md#L272), [test-cases.md:240](../tests/test-cases.md#L240).

TCPDUMP_STATUS được gán nhưng không dùng. Khi tcpdump thất bại và không tạo file, nhánh leak-check vẫn có thể in “KẾT LUẬN AN NINH ĐẠT”. Một pcap có header nhưng 0 packet vẫn có dung lượng khác 0, nên chỉ kiểm tra -s không phân biệt được số gói.

Lệnh leak-check -c 20 hoặc tcpdump -c 10 có thể chờ vô hạn chính trong trường hợp không rò rỉ. Script cũng chưa xem việc bắt được gói rò rỉ là một lỗi nghiệm thu riêng.

Hướng sửa: dùng cửa sổ thời gian hữu hạn, xác nhận capture chạy thành công, tạo lưu lượng kiểm thử có chủ đích, đếm gói phù hợp và trả trạng thái lỗi nếu phát hiện bản rõ. Với IPsec, nên đối chứng thêm trên adapter/máy WAN độc lập vì điểm bắt gói Linux tại gateway có thể quan sát lưu lượng ở các giai đoạn xử lý khác nhau.

### 10 — P2: Chuyển chế độ chưa bền qua reboot và có thể báo thành công giả

Vị trí: [switch-vpn-mode.sh:33](../scripts/switch-vpn-mode.sh#L33), [switch-vpn-mode.sh:60](../scripts/switch-vpn-mode.sh#L60), [switch-vpn-mode.sh:73](../scripts/switch-vpn-mode.sh#L73).

Script chỉ stop/start dịch vụ; các script deploy vẫn enable cả OpenVPN S2S và IPsec. Sau reboot có thể chạy lại cả hai và xung đột định tuyến. Khi Branch ipsec up thất bại, lỗi bị bỏ qua bằng || true rồi script vẫn báo SUCCESS.

Hướng sửa: quản lý trạng thái enable/disable cho dịch vụ S2S theo mode; giữ C2S riêng; không bỏ qua lỗi thiết lập SA khi tuyên bố tunnel đã thành công. Cần kiểm tra unit strongSwan thực tế: cách cài ipsec.conf/starter trên Ubuntu thường dùng strongswan-starter, trong khi nhiều lệnh đang hardcode strongswan và che lỗi.

### 11 — P2: Triển khai lại IPsec có thể ghi đè PSK đã tùy chỉnh

Vị trí: [deploy-ipsec-hq.sh:53](../scripts/deploy-ipsec-hq.sh#L53), [deploy-ipsec-branch.sh:53](../scripts/deploy-ipsec-branch.sh#L53).

Script ghi đè /etc/ipsec.secrets nếu không tìm thấy chuỗi của PSK mẫu. Khi người dùng đã thay khóa mẫu bằng khóa riêng, lần chạy tiếp theo sẽ khôi phục khóa công khai trong repo và ghi đè toàn bộ tệp secrets.

Hướng sửa: chỉ khởi tạo khi chưa có tệp, bảo toàn cấu hình đã tùy chỉnh và yêu cầu PSK riêng cho hai đầu. Không mô tả PSK công khai trong example là bí mật mạnh của hệ thống đang triển khai.

### 12 — P2: Báo cáo PASS và benchmark chưa có bằng chứng trong repo

Vị trí: [07-testing-and-security-eval.md:33](technical-guides/07-testing-and-security-eval.md#L33), [slides.md:115](presentation/slides.md#L115).

Tài liệu ghi 11/11 PASS, RTT cụ thể, IPsec nhanh hơn 45% và thông lượng 850–960 Mbps. Repo hiện có 0 pcap, 0 ảnh minh chứng và không có log benchmark để đối chứng; screenshots README mới ghi “Đã quy hoạch”. Điều này không chứng minh tác giả chưa từng đo, nhưng chưa đủ để người đọc xác minh các kết luận.

Hướng sửa: nếu là dữ liệu minh họa/kỳ vọng thì gắn nhãn rõ; nếu là kết quả thật thì bổ sung cấu hình máy, phiên bản phần mềm, lệnh đo, log gốc và bằng chứng. Các phát biểu “tuyệt đối an toàn”, “không có bất kỳ lỗ hổng” cần thay bằng kết luận giới hạn theo phạm vi kiểm thử.

## 3. Các lỗi tài liệu và tiện ích khác

### 13 — P2: Tên dịch vụ, log và profile trong test không khớp script

Vị trí: [test-cases.md:30](../tests/test-cases.md#L30), [test-cases.md:107](../tests/test-cases.md#L107), [test-cases.md:221](../tests/test-cases.md#L221).

- Dịch vụ thực tế là openvpn-server@server-c2s, openvpn-server@server-s2s và openvpn-client@client-s2s. Một số test dùng @server, @s2s-hq hoặc @s2s-branch; lệnh status/stop sẽ trỏ sai instance.
- Log trạng thái thực tế là openvpn-c2s-status.log và openvpn-s2s-status.log; status log không thay cho journal ghi lỗi bắt tay. Test đang dùng cả tên s2s-status.log/openvpn-status.log không được cấu hình.
- TC-01 liên kết template chưa nhúng khóa nhưng gọi là client1.ovpn để import. Phải dùng profile do build-client-ovpn sinh ra.
- Địa chỉ C2S 10.8.0.2 là ví dụ cấp động, không được bảo đảm cho mọi client/lần chạy. Branch được mô tả cố định 10.9.0.2 nhưng CCD chưa có ifconfig-push; nên gán tĩnh nếu bài nghiệm thu yêu cầu chính xác địa chỉ này.
- Tài liệu nói đã cấu hình mssfix 1400 nhưng không có chỉ thị đó trong các tệp OpenVPN. Nhiều tài liệu gọi ta.key là tls-auth trong khi cấu hình thực tế là tls-crypt.
- Sơ đồ OpenVPN ghi cổng nguồn Branch là 1195 dù cấu hình nobind dùng cổng nguồn động. Traceroute/TTL cụ thể cũng nên là ví dụ, không dùng riêng chúng để kết luận thuật toán mã hóa hoặc tính an toàn của WAN.
- Thu hồi CRL chặn bắt tay tiếp theo; cập nhật CRL không đồng nghĩa chủ động ngắt ngay mọi phiên đang tồn tại. Các mô tả thu hồi “tức thì” cần phân biệt điều này.

Nguồn đối chiếu: [OpenVPN 2.5 Manual](https://openvpn.net/community-docs/community-articles/openvpn-2-5-manual/).

### 14 — P2: Link nội bộ phụ thuộc máy tác giả hoặc trỏ đến tệp không có

Phát hiện 29 liên kết file:///c:/University%20Coding%20Project/... trong Markdown. Chúng không dùng được như liên kết repo trên GitHub và không khớp vị trí checkout hiện tại.

README liệt kê .agents/ và .plan/ như thành phần repository; các thư mục này không tồn tại trong checkout và đang bị .gitignore bỏ qua. Một số tài liệu còn liên kết PLAN.md/TEST_AGENTS.md trong các thư mục đó.

Hướng sửa: đổi sang liên kết tương đối theo vị trí tài liệu; bỏ liên kết đến tài nguyên riêng chưa được đưa vào repo hoặc đưa nội dung cần thiết sang docs/. Câu lệnh SCP trong tests/captures/samples/README.md cũng cần dùng đường dẫn thật trên Ubuntu thay cho đường dẫn Windows dạng /c/University... có dấu ... làm placeholder.

### 15 — P2: Netplan giả định tên card nhưng chưa có bước chuẩn hóa

Vị trí: [02-network-topology.md:79](technical-guides/02-network-topology.md#L79), [01-netcfg-hq-gw.yaml:8](../configs/netplan/01-netcfg-hq-gw.yaml#L8).

Tất cả cấu hình/firewall dùng eth0 và eth1. Số thứ tự adapter của hypervisor không bảo đảm Ubuntu đặt đúng những tên này; hệ thống có thể dùng enp0s3, enp0s8, ens33… Nếu không chuẩn hóa, IP và firewall sẽ không áp dụng đúng NIC.

Hướng sửa: bắt buộc kiểm tra ip -br link và đối chiếu MAC; chuẩn hóa tên bằng match MAC/set-name trong Netplan hoặc đồng bộ tên interface thực tế trong tất cả cấu hình liên quan. Kiểm tra cả YAML được installer/cloud-init tạo sẵn để tránh giữ DHCP/default route ngoài ý muốn; dùng console khi đổi mạng.

### 16 — P2: Tải file benchmark bằng batch dùng đường dẫn PowerShell sai

Vị trí: [quick-setup.bat:152](../quick-setup.bat#L152).

-OutFile '$env:TEMP\benchmark.dat' nằm trong chuỗi nháy đơn PowerShell, nên biến môi trường không được nội suy. Lệnh có thể thất bại dù VPN và HTTP đang hoạt động; phần catch lại quy nguyên nhân về kết nối VPN.

Hướng sửa: dựng đường dẫn bằng Join-Path $env:TEMP 'benchmark.dat', dùng đường dẫn đó để lưu và lấy kích thước file thực tế khi tính tốc độ. Ping thành công cũng chỉ chứng minh khả năng kết nối; tiện ích không nên tự kết luận VPN an toàn chỉ từ kết quả ping.

### 17 — P2: Chức năng và số liệu hiển thị không khớp tài nguyên Portal

Vị trí: [index.html:184](../services/intranet-portal/index.html#L184), [demo-script.md:49](presentation/demo-script.md#L49), [slides.md:73](presentation/slides.md#L73).

Demo/test hướng dẫn bấm “Test Download Speed”, nhưng HTML/JS chỉ có các link tải file, không có nút hay hàm đo tốc độ tương ứng. Slides nói có file 1MB/10MB nhưng repo chỉ có payload 1,048,576 byte (1 MiB).

Dung lượng hai tệp text hiển thị 12.4 KB/34.8 KB, thực tế là 2,418/1,612 byte. Đây là số liệu cố định sai, không phải lỗi truyền tải.

Hướng sửa: triển khai phép đo thực tế hoặc sửa kịch bản thành tải file và đo bằng công cụ đã có; đồng bộ kích thước/đơn vị và danh mục tài nguyên.

## 4. Kiểm tra đã thực hiện và giới hạn

- Kiểm tra cú pháp cả 20 script bằng Git Bash bash -n: đạt.
- Kiểm tra cú pháp app.js bằng node --check: đạt.
- Chạy ba script verify với vai trò không hợp lệ: tái hiện exit 0 và kết luận thành công khi 0 phép kiểm tra.
- Mô phỏng API lỗi, client bị NAT và client Branch trong Node: tái hiện các trạng thái hiển thị sai đã nêu.
- Đối chiếu đường dẫn, tên dịch vụ, IP/subnet, route, firewall, khóa mẫu, tài nguyên web và liên kết Markdown.
- Chưa chạy apt, netplan apply, systemctl, iptables, OpenVPN, strongSwan hay test LAN-to-LAN trên Ubuntu. Vì vậy không khẳng định khả năng kết nối hoặc benchmark thực tế.
- Không đánh dấu chuỗi proposal strongSwan hiện tại là lỗi gây thất bại chỉ dựa trên cách viết; nên chuẩn hóa AEAD thành IKE aes256gcm16-prfsha256-modp2048! và ESP aes256gcm16-modp2048!, rồi kiểm tra bằng bản strongSwan dùng trong lab. [Tài liệu strongSwan](https://docs.strongswan.org/docs/5.9/config/IKEv2CipherSuites.html).

Thứ tự xử lý đề xuất: quyết định Remote PC là host hay VM → hoàn thiện mạng/đường cài gói → thống nhất CA và phân phối cert → đồng bộ mode hai gateway → thực thi firewall → chỉnh Portal → sửa nghiệm thu/tài liệu → chạy lab và bổ sung bằng chứng thực tế.
