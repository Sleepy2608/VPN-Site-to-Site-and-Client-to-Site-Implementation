# Hướng dẫn thiết lập phòng lab VPN

Mô hình hiện tại là **5 máy: HQ-Gateway, Branch-Gateway, HQ-Server, Branch-PC và Windows Remote-PC**. Hai gateway nối hai LAN bằng OpenVPN Site-to-Site; Windows kết nối Client-to-Site vào HQ.

## Triển khai mô hình 5 máy

Thực hiện theo [bộ hướng dẫn triển khai từng máy](../deployment/README.md):

1. [Chuẩn bị VMware và tạo mạng từng bước](../deployment/00-preparation.md).
2. [HQ-Gateway](../deployment/01-hq-gw.md).
3. [Branch-Gateway](../deployment/02-branch-gw.md).
4. [HQ-Server](../deployment/03-hq-server.md).
5. [Branch-PC](../deployment/04-branch-pc.md).
6. [Windows Remote-PC](../deployment/05-windows-remote.md).
7. [Nghiệm thu, ngắt NAT và kiểm tra sau reboot](../deployment/06-acceptance.md).

[Báo cáo triển khai trực tiếp](../deployment/live-lab-status.md) ghi IP/NIC thực tế, log và PCAP. C2S đã được kiểm tra bằng client Linux tạm; Windows do người dùng tự cấu hình, chưa có bằng chứng nghiệm thu Windows độc lập trong repo.

## Thuyết trình và bài thực hành bổ sung

- [Runbook 5 máy](detailed-lab-runbook.md), [kịch bản demo](demo-script.md) và [slides](slides.md).
- [Bài thực hành C2S 3 máy](three-vm-openvpn-demo.md) dùng cấu hình riêng trong hướng dẫn. Hai client kết nối cùng một server chỉ minh họa Client-to-Site; dùng mô hình 5 máy để nghiệm thu LAN-to-LAN qua hai gateway.

Các mẫu Netplan `01-netcfg-server.yaml`, `01-netcfg-client-linux.yaml` và CCD trong `openvpn/client-to-site/server/ccd-c2s/` được giữ từ phương án 3 máy trước đây. Bộ triển khai 5 máy không tự dùng những mẫu này; áp dụng đúng YAML/NIC và CCD theo hướng dẫn từng máy. Không dùng lệnh `deploy-all.sh server` hoặc `client-linux` của tài liệu cũ; các vai trò hiện tại là `hq-gw`, `branch-gw`, `hq-server`, `branch-pc`.
