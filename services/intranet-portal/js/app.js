/** Hiển thị IP nguồn Nginx quan sát được; không suy đoán cipher/SA từ IP. */
document.addEventListener('DOMContentLoaded', initNetworkInspector);

async function initNetworkInspector() {
    let clientIp = null;
    try {
        const response = await fetch('/api/identity', { cache: 'no-store' });
        if (response.ok) {
            const data = await response.json();
            if (typeof data.ip === 'string' && data.ip.length > 0) clientIp = data.ip;
        }
    } catch {
        // API không có dữ liệu: giữ trạng thái chưa xác định.
    }
    renderIdentityStatus(clientIp);
}

function renderIdentityStatus(ip) {
    const card = document.getElementById('identityCard');
    const badge = document.getElementById('shieldBadge');
    const title = document.getElementById('identityStatus');
    const description = document.getElementById('identityDesc');
    const cryptoState = document.getElementById('cryptoState');
    const tunnelType = document.getElementById('tunnelType');
    document.getElementById('clientIpDisplay').textContent = ip || 'Chưa xác định';
    card.className = 'identity-banner-card';
    badge.className = 'shield-badge';
    cryptoState.className = 'metric-value mono';
    tunnelType.className = 'metric-value mono';
    cryptoState.textContent = 'Đối chiếu log OpenVPN và capture WAN';

    if (!ip) {
        title.textContent = '[UNKNOWN] Chưa đọc được IP nguồn';
        description.textContent = 'API định danh chưa phản hồi hợp lệ. Kiểm tra Nginx và kết nối tới máy chủ.';
        tunnelType.textContent = 'Chưa xác định';
    } else if (ip === '192.168.10.1') {
        title.textContent = '[GATEWAY] Yêu cầu đến từ HQ Gateway';
        description.textContent = 'C2S trong lab dùng NAT nên Nginx có thể thấy IP gateway này. Xem IP tunnel bằng ipconfig trên Windows Remote-PC và phiên client trong status log.';
        tunnelType.textContent = 'HQ Gateway / C2S qua NAT';
    } else if (ip.startsWith('10.8.0.')) {
        title.textContent = '[C2S] IP nguồn thuộc dải OpenVPN Client-to-Site';
        description.textContent = `Nginx quan sát IP ${ip}. Đối chiếu phiên kết nối và cipher trên gateway.`;
        tunnelType.textContent = 'Nguồn thuộc dải C2S';
    } else if (ip.startsWith('192.168.20.')) {
        card.className = 'identity-banner-card branch';
        title.textContent = '[BRANCH] IP nguồn thuộc LAN chi nhánh';
        description.textContent = `Nginx quan sát IP ${ip}. Mô hình lab dùng OpenVPN S2S; kiểm tra tunnel tại hai gateway.`;
        tunnelType.textContent = 'LAN Branch / mô hình OpenVPN S2S';
    } else if (ip.startsWith('192.168.10.')) {
        title.textContent = '[HQ] IP nguồn thuộc LAN trụ sở';
        description.textContent = `Nginx quan sát IP ${ip}. HTTP trong LAN sau gateway là bản rõ.`;
        tunnelType.textContent = 'LAN HQ';
    } else {
        title.textContent = '[OTHER] IP nguồn ngoài các dải demo';
        description.textContent = `Nginx quan sát IP ${ip}. Kiểm tra route để xác định đường đi.`;
        tunnelType.textContent = 'Nguồn khác';
    }
}
