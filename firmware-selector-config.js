// Динамическая конфигурация firmware-selector
// Автоматически обновляется при изменении Image Builder

async function loadDynamicConfig() {
    try {
        // Загрузка конфигурации с сервера
        const response = await fetch('/api/config');
        const serverConfig = await response.json();
        
        // Объединение с базовой конфигурацией
        return {
            asu_url: window.location.origin + '/api',
            image_url: window.location.origin + '/store',
            versions: serverConfig.versions || ['SNAPSHOT', '24.10', '23.05'],
            default_version: serverConfig.default_version || '24.10',
            asu_enabled: true,
            show_custom_images: true,
            allow_custom_packages: true,
            show_advanced_options: true,
            
            // Дополнительные настройки
            version_names: serverConfig.version_names || {},
            target_names: serverConfig.target_names || {},
            
            // Кастомные фиды пакетов
            custom_feeds: serverConfig.custom_feeds || [],
            
            // Рекомендуемые пакеты по категориям
            package_recommendations: {
                'basic': ['luci', 'luci-ssl', 'nano', 'htop'],
                'vpn': ['openvpn-openssl', 'wireguard-tools', 'luci-app-wireguard'],
                'nas': ['samba4-server', 'luci-app-samba4', 'block-mount', 'e2fsprogs'],
                'routing': ['bird2', 'bird2-uci', 'luci-app-bird'],
                'monitoring': ['prometheus-node-exporter-lua', 'collectd', 'luci-app-statistics'],
                'development': ['git', 'make', 'gcc', 'python3'],
                'security': ['fail2ban', 'luci-app-firewall', 'tcpdump']
            }
        };
    } catch (error) {
        console.warn('Не удалось загрузить динамическую конфигурацию, используем статическую');
        
        // Статическая конфигурация как fallback
        return {
            asu_url: window.location.origin + '/api',
            image_url: window.location.origin + '/store',
            versions: ['SNAPSHOT', '24.10.1', '24.10', '23.05', '22.03', '21.02', 'custom'],
            default_version: '24.10.1',
            asu_enabled: true,
            show_custom_images: true,
            allow_custom_packages: true,
            show_advanced_options: true
        };
    }
}

// Экспорт конфигурации
var config = null;

// Загрузка конфигурации при старте
(async function() {
    config = await loadDynamicConfig();
    
    // Инициализация firmware-selector с новой конфигурацией
    if (window.initializeFirmwareSelector) {
        window.initializeFirmwareSelector(config);
    }
})();