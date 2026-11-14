/**
 * JavaScript: app.js - Network Identity Inspector
 * Tự động phân tích và hiển thị trạng thái kết nối mạng của máy khách truy cập
 */

document.addEventListener('DOMContentLoaded', () => {
    initNetworkInspector();
});

async function initNetworkInspector() {
    let clientIp = '10.8.0.2'; // Mặc định hiển thị IP Client-to-Site cho môi trường Lab

    try {
        // Thử gọi endpoint API nhẹ do Nginx hoặc backend trả về
        const response = await fetch('/api/identity', { cache: 'no-store' });
        if (response.ok) {
            const data = await response.json();
            if (data.ip) {
                clientIp = data.ip;
            }
        }
    } catch {
        // Nếu chạy tĩnh thuần không có backend API, tự động nhận diện từ hostname/URL params nếu có
        const urlParams = new URLSearchParams(window.location.search);
        if (urlParams.has('ip')) {
            clientIp = urlParams.get('ip');
        }
    }

    renderIdentityStatus(clientIp);
}

function renderIdentityStatus(ip) {
    const card = document.getElementById('identityCard');
    const badge = document.getElementById('shieldBadge');
    const statusTitle = document.getElementById('identityStatus');
    const statusDesc = document.getElementById('identityDesc');
    const clientIpDisplay = document.getElementById('clientIpDisplay');
    const cryptoState = document.getElementById('cryptoState');
    const tunnelType = document.getElementById('tunnelType');

    clientIpDisplay.textContent = ip;

    // Phân loại dải địa chỉ IP truy cập
    if (ip.startsWith('10.8.0.')) {
        // Trường hợp 1: Truy cập qua OpenVPN Client-to-Site (Remote Worker)
        card.className = 'identity-banner-card secure';
        badge.className = 'shield-badge secure';
        statusTitle.innerHTML = '<span class="text-emerald">[SECURE]</span> Bạn đang kết nối an toàn qua OpenVPN Remote Access';
        statusDesc.textContent = `Địa chỉ IP Tunnel: ${ip} được cấp phát từ máy chủ HQ VPN Gateway. Toàn bộ lưu lượng truy cập được mã hóa đầu cuối.`;
        cryptoState.textContent = 'AES-256-GCM / SHA256 (TLS-Crypt)';
        cryptoState.className = 'metric-value mono text-emerald';
        tunnelType.textContent = 'OpenVPN Remote Access (C2S)';
        tunnelType.className = 'metric-value mono text-emerald';

    } else if (ip.startsWith('192.168.20.')) {
        // Trường hợp 2: Truy cập từ mạng LAN Chi nhánh qua Site-to-Site Tunnel
        card.className = 'identity-banner-card branch';
        badge.className = 'shield-badge';
        statusTitle.innerHTML = '<span class="text-cyan">[CONNECTED]</span> Bạn đang truy cập từ Văn phòng Chi nhánh (Branch Site)';
        statusDesc.textContent = `Địa chỉ IP LAN: ${ip} được định tuyến thông qua đường hầm Site-to-Site giữa Branch Gateway và HQ Gateway.`;
        cryptoState.textContent = 'AES-256-GCM / IPsec ESP Encapsulated';
        cryptoState.className = 'metric-value mono text-cyan';
        tunnelType.textContent = 'Site-to-Site Routed Tunnel (HQ <=> Branch)';
        tunnelType.className = 'metric-value mono text-cyan';

    } else if (ip.startsWith('192.168.10.')) {
        // Trường hợp 3: Truy cập nội bộ trực tiếp tại Trụ sở HQ
        card.className = 'identity-banner-card';
        badge.className = 'shield-badge';
        statusTitle.innerHTML = '<span class="text-cyan">[LOCAL]</span> Bạn đang kết nối trực tiếp trong mạng LAN Trụ sở chính HQ';
        statusDesc.textContent = `Địa chỉ IP nội bộ: ${ip} kết nối qua vSwitch nội bộ HQ-LAN-Net mà không cần thông qua đường hầm mã hóa bên ngoài.`;
        cryptoState.textContent = 'Bản rõ nội bộ (Physical Isolated LAN)';
        cryptoState.className = 'metric-value mono';
        tunnelType.textContent = 'Direct Internal Ethernet (No VPN)';
        tunnelType.className = 'metric-value mono';

    } else {
        // Trường hợp 4: IP từ dải mạng khác hoặc cảnh báo
        card.className = 'identity-banner-card';
        statusTitle.innerHTML = '<span class="text-amber">[WARNING]</span> Kết nối từ dải mạng không xác định';
        statusDesc.textContent = `Địa chỉ IP nguồn: ${ip}. Vui lòng kiểm tra lại cấu hình định tuyến và cổng VPN Gateway.`;
        cryptoState.textContent = 'Chưa xác thực';
        cryptoState.className = 'metric-value mono text-amber';
        tunnelType.textContent = 'External / Unknown Route';
        tunnelType.className = 'metric-value mono text-amber';
    }
}

