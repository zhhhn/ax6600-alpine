// ClawUI Main Application

// Navigation
document.querySelectorAll('.nav-item').forEach(item => {
    item.addEventListener('click', (e) => {
        e.preventDefault();
        const page = item.dataset.page;
        showPage(page);
    });
});

function showPage(page) {
    // Update nav
    document.querySelectorAll('.nav-item').forEach(i => i.classList.remove('active'));
    document.querySelector(`[data-page="${page}"]`).classList.add('active');
    
    // Update pages
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    document.getElementById(`page-${page}`).classList.add('active');
    
    // Load data
    loadPageData(page);
}

// Load page data
async function loadPageData(page) {
    switch (page) {
        case 'status':
            await loadStatus();
            break;
        case 'network':
            await loadNetwork();
            break;
        case 'wireless':
            await loadWireless();
            break;
        case 'firewall':
            await loadFirewall();
            break;
        case 'packages':
            await loadPackages();
            break;
        case 'system':
            await loadSystem();
            break;
    }
}

// Status page
async function loadStatus() {
    try {
        const data = await API.status.get();
        
        document.getElementById('info-hostname').textContent = data.hostname;
        document.getElementById('info-uptime').textContent = formatUptime(data.uptime);
        document.getElementById('info-kernel').textContent = data.kernel;
        document.getElementById('info-alpine').textContent = data.alpine;
        
        document.getElementById('info-cpu').textContent = `${data.cpu}%`;
        document.getElementById('cpu-bar').style.width = `${data.cpu}%`;
        
        const memPercent = Math.round((data.memory.used / data.memory.total) * 100);
        document.getElementById('info-memory').textContent = 
            `${data.memory.used}MB / ${data.memory.total}MB`;
        document.getElementById('memory-bar').style.width = `${memPercent}%`;
        
        document.getElementById('info-download').textContent = formatBytes(data.network.rx);
        document.getElementById('info-upload').textContent = formatBytes(data.network.tx);
        document.getElementById('info-clients').textContent = data.clients;
        
        document.getElementById('hostname').textContent = data.hostname;
    } catch (e) {
        console.error('Failed to load status:', e);
    }
}

// Network page
async function loadNetwork() {
    try {
        const data = await API.network.get();
        
        document.getElementById('lan-ip').value = data.lan.ip;
        document.getElementById('wan-ip').value = data.wan.ip || '未连接';
        document.getElementById('wan-proto').value = data.wan.proto;
        
        // Show/hide PPPoE fields
        document.getElementById('pppoe-fields').style.display = 
            data.wan.proto === 'pppoe' ? 'block' : 'none';
        
        // Interfaces list
        const tbody = document.getElementById('interfaces-list');
        tbody.innerHTML = data.interfaces.map(i => `
            <tr>
                <td>${i.name}</td>
                <td>${i.type}</td>
                <td><span class="badge ${i.status}">${i.status}</span></td>
            </tr>
        `).join('');
    } catch (e) {
        console.error('Failed to load network:', e);
    }
}

// Wireless page
async function loadWireless() {
    try {
        const [status, config] = await Promise.all([
            API.wireless.get(),
            API.wireless.config()
        ]);
        
        // 2.4GHz
        document.getElementById('ssid-2g').value = config['2g'].ssid || '';
        document.getElementById('channel-2g').value = config['2g'].channel || 'auto';
        
        // 5GHz
        document.getElementById('ssid-5g').value = config['5g'].ssid || '';
        document.getElementById('channel-5g').value = config['5g'].channel || 'auto';
        
        // Status table
        const tbody = document.getElementById('wifi-status');
        tbody.innerHTML = `
            <tr>
                <td>2.4GHz</td>
                <td>${status['2g'].status}</td>
                <td>${status['2g'].clients}</td>
            </tr>
            <tr>
                <td>5GHz</td>
                <td>${status['5g'].status}</td>
                <td>${status['5g'].clients}</td>
            </tr>
        `;
    } catch (e) {
        console.error('Failed to load wireless:', e);
    }
}

// Firewall page
async function loadFirewall() {
    try {
        const [status, forwards] = await Promise.all([
            API.firewall.get(),
            API.firewall.forwards()
        ]);
        
        document.getElementById('firewall-status').textContent = 
            status.enabled ? '已启用' : '已禁用';
        document.getElementById('firewall-rules').textContent = status.rules_count;
        
        const tbody = document.getElementById('port-forwards');
        tbody.innerHTML = forwards.map((f, i) => `
            <tr>
                <td>${f.proto}</td>
                <td>${f.ext_port}</td>
                <td>${f.int_ip}</td>
                <td>${f.int_port}</td>
                <td>
                    <button class="btn-danger" onclick="deleteForward(${i})">删除</button>
                </td>
            </tr>
        `).join('') || '<tr><td colspan="5">无规则</td></tr>';
    } catch (e) {
        console.error('Failed to load firewall:', e);
    }
}

// Packages page
async function loadPackages() {
    try {
        const packages = await API.packages.list();
        
        const tbody = document.getElementById('packages-list');
        tbody.innerHTML = packages.map(p => `
            <tr>
                <td>${p.name}</td>
                <td>${p.version}</td>
                <td>${p.description || '-'}</td>
                <td>
                    <button class="btn-secondary" onclick="removePackage('${p.name}')">卸载</button>
                </td>
            </tr>
        `).join('');
    } catch (e) {
        console.error('Failed to load packages:', e);
    }
}

// System page
async function loadSystem() {
    try {
        const [info, services] = await Promise.all([
            API.system.get(),
            API.system.services()
        ]);
        
        document.getElementById('system-hostname').value = info.hostname;
        document.getElementById('system-timezone').value = info.timezone;
        
        const tbody = document.getElementById('services-list');
        tbody.innerHTML = services.map(s => `
            <tr>
                <td>${s.name}</td>
                <td><span class="badge ${s.status}">${s.status}</span></td>
                <td>
                    <button class="btn-secondary" onclick="toggleService('${s.name}')">
                        ${s.status === 'started' ? '停止' : '启动'}
                    </button>
                </td>
            </tr>
        `).join('');
    } catch (e) {
        console.error('Failed to load system:', e);
    }
}

// Actions
async function toggleWifi(band) {
    // Implementation
    alert(`Toggle ${band} WiFi`);
}

async function showAddPortForward() {
    showModal(`
        <h3>添加端口转发</h3>
        <form id="form-port-forward">
            <div class="form-group">
                <label>协议</label>
                <select id="pf-proto">
                    <option value="tcp">TCP</option>
                    <option value="udp">UDP</option>
                </select>
            </div>
            <div class="form-group">
                <label>外部端口</label>
                <input type="number" id="pf-ext-port">
            </div>
            <div class="form-group">
                <label>内部 IP</label>
                <input type="text" id="pf-int-ip" placeholder="192.168.1.100">
            </div>
            <div class="form-group">
                <label>内部端口</label>
                <input type="number" id="pf-int-port">
            </div>
            <button type="submit" class="btn-primary">添加</button>
        </form>
    `);
}

async function deleteForward(id) {
    if (confirm('确定删除此规则？')) {
        await API.firewall.deleteForward(id);
        loadFirewall();
    }
}

async function reloadFirewall() {
    await API.firewall.reload();
    alert('防火墙已重新加载');
}

async function updateRepos() {
    await API.packages.update();
    alert('软件包列表已更新');
}

async function upgradeAll() {
    if (confirm('确定升级所有软件包？')) {
        await API.packages.upgrade();
        alert('升级完成');
        loadPackages();
    }
}

async function removePackage(name) {
    if (confirm(`确定卸载 ${name}？`)) {
        await API.packages.remove(name);
        loadPackages();
    }
}

async function backupConfig() {
    const result = await API.system.backup();
    alert(`配置已备份到: ${result.file}`);
}

async function reboot() {
    if (confirm('确定重启系统？')) {
        await API.system.reboot();
        alert('系统正在重启...');
    }
}

async function factoryReset() {
    if (confirm('⚠️ 确定恢复出厂设置？此操作不可逆！')) {
        await API.system.factoryReset();
        alert('正在恢复出厂设置...');
    }
}

// Utilities
function formatUptime(seconds) {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    
    if (days > 0) return `${days}天 ${hours}小时`;
    if (hours > 0) return `${hours}小时 ${mins}分钟`;
    return `${mins}分钟`;
}

function formatBytes(bytes) {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    if (bytes < 1024 * 1024 * 1024) return (bytes / 1024 / 1024).toFixed(1) + ' MB';
    return (bytes / 1024 / 1024 / 1024).toFixed(2) + ' GB';
}

function showModal(content) {
    document.getElementById('modal-body').innerHTML = content;
    document.getElementById('modal').classList.add('show');
}

function closeModal() {
    document.getElementById('modal').classList.remove('show');
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    showPage('status');
    
    // Update time
    setInterval(() => {
        document.getElementById('footer-time').textContent = new Date().toLocaleString('zh-CN');
    }, 1000);
});

// Form handlers
document.getElementById('form-lan')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = { lan_ip: document.getElementById('lan-ip').value };
    await API.network.update(data);
    alert('LAN 设置已保存');
});

document.getElementById('wan-proto')?.addEventListener('change', (e) => {
    document.getElementById('pppoe-fields').style.display = 
        e.target.value === 'pppoe' ? 'block' : 'none';
});