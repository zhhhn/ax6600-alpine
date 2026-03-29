// ClawUI API Client
const API = {
    baseUrl: '/cgi-bin/api',
    
    // Generic request
    async request(path, options = {}) {
        const url = `${this.baseUrl}${path}`;
        const response = await fetch(url, {
            headers: { 'Content-Type': 'application/json' },
            ...options
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        
        return response.json();
    },
    
    // GET
    async get(path) {
        return this.request(path);
    },
    
    // POST
    async post(path, data = {}) {
        return this.request(path, {
            method: 'POST',
            body: JSON.stringify(data)
        });
    },
    
    // DELETE
    async delete(path) {
        return this.request(path, { method: 'DELETE' });
    },
    
    // API endpoints
    status: {
        get: () => API.get('/api/status')
    },
    
    network: {
        get: () => API.get('/api/network'),
        update: (data) => API.post('/api/network', data)
    },
    
    wireless: {
        get: () => API.get('/api/wireless'),
        config: () => API.get('/api/wireless/config'),
        scan: () => API.get('/api/wireless/scan'),
        update: (data) => API.post('/api/wireless', data),
        toggle: (action) => API.request('/api/wireless', {
            method: 'PUT',
            body: JSON.stringify({ action })
        })
    },
    
    firewall: {
        get: () => API.get('/api/firewall'),
        forwards: () => API.get('/api/firewall/forwards'),
        addForward: (data) => API.post('/api/firewall/forwards', data),
        deleteForward: (id) => API.delete(`/api/firewall/forwards?id=${id}`),
        reload: () => API.post('/api/firewall/reload')
    },
    
    packages: {
        list: () => API.get('/api/packages'),
        available: () => API.get('/api/packages/available'),
        upgrades: () => API.get('/api/packages/upgrades'),
        get: (name) => API.get(`/api/packages/${name}`),
        install: (pkg) => API.post('/api/packages/install', { package: pkg }),
        remove: (pkg) => API.post('/api/packages/remove', { package: pkg }),
        update: () => API.post('/api/packages/update'),
        upgrade: () => API.post('/api/packages/upgrade')
    },
    
    system: {
        get: () => API.get('/api/system'),
        logs: (lines = 50) => API.get(`/api/system/logs?lines=${lines}`),
        services: () => API.get('/api/system/services'),
        setHostname: (hostname) => API.post('/api/system/hostname', { hostname }),
        setTimezone: (timezone) => API.post('/api/system/timezone', { timezone }),
        reboot: () => API.post('/api/system/reboot'),
        factoryReset: () => API.post('/api/system/factory-reset'),
        backup: () => API.post('/api/system/backup')
    }
};