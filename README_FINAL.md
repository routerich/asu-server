# 🏗️ Complete ASU Server Deployment

**Полное развертывание локального ASU сервера OpenWrt одним скриптом**

Автоматическая установка и настройка:
- 🔧 ASU (Attended Sysupgrade Server)
- 🌐 firmware-selector-openwrt веб-интерфейс  
- 📱 Поддержка Attended Sysupgrade для устройств
- 🎯 Интеграция вашего кастомного Image Builder

## 🚀 Мгновенный запуск

```bash
# Скачайте и запустите единый скрипт
sudo bash deploy_complete_asu.sh
```

**Вот и всё!** 🎉 Один скрипт развернет полную инфраструктуру ASU.

## 📋 Что включено

### 🏗️ Полная автоматизация:
- ✅ Установка всех зависимостей (Podman, Redis, Nginx)
- ✅ Настройка ASU сервера с вашим Image Builder
- ✅ Настройка веб-интерфейса firmware-selector
- ✅ Конфигурация Attended Sysupgrade API
- ✅ Создание systemd сервисов
- ✅ Настройка Nginx reverse proxy
- ✅ Конфигурация firewall

### 🎯 Для MediaTek Filogic устройств:
- **Поддерживаемые чипы**: MT7981, MT7986, MT7622
- **Устройства**: Xiaomi AX3000T/AX6000, TP-Link AX53/AX73, ASUS RT-AX53U, GL.iNet MT3000/MT6000

### 🔧 Готовые интерфейсы:
- **Веб**: `http://your-server/` - выбор устройства и пакетов
- **API**: `http://your-server/api/` - для owut/auc интеграции
- **Docs**: `http://your-server/api/docs` - документация API

## 🎮 Как использовать

### 1️⃣ Подготовка
Убедитесь что у вас есть:
- Ubuntu 20.04+ сервер
- Ваш Image Builder для MediaTek Filogic 24.10.1
- 4GB+ RAM, 20GB+ диск

### 2️⃣ Развертывание
```bash
sudo bash deploy_complete_asu.sh
```

Скрипт спросит:
- Путь к вашему Image Builder
- Название сервера (опционально)
- Домен для HTTPS (опционально)

### 3️⃣ Использование на устройствах

#### LuCI (веб-интерфейс роутера):
```bash
opkg install luci-app-attendedsysupgrade
```
Затем: System → Attended Sysupgrade → Server: `http://your-server/api/`

#### CLI:
```bash
owut --server http://your-server/api/ upgrade
```

## 🏭 Архитектура решения

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   OpenWrt       │    │   Nginx         │    │   ASU Server    │
│   Device        │◄───┤   Reverse       │◄───┤   + Workers     │
│                 │    │   Proxy         │    │                 │
│ owut/auc/LuCI   │    │                 │    │ Custom ImageBuilder │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                       ┌─────────────────┐    ┌─────────────────┐
                       │ firmware-       │    │   Redis         │
                       │ selector        │    │   Cache         │
                       │ Web UI          │    │                 │
                       └─────────────────┘    └─────────────────┘
```

## 📁 Структура проекта

```
/opt/asu-server/
├── asu/                           # ASU сервер
├── firmware-selector-openwrt-org/ # Веб-интерфейс
├── imagebuilders/                 # Ваши Image Builder
│   └── 24.10.1/
│       └── mediatek/
│           └── filogic/          # Ваш кастомный IB
├── public/store/                  # Собранные прошивки
├── status.sh                      # Скрипт проверки
└── CLIENT_SETUP.md               # Инструкции для устройств
```

## 🛠️ Управление сервером

### Проверка статуса:
```bash
/opt/asu-server/status.sh
```

### Логи:
```bash
journalctl -u asu-server -f      # Логи ASU
systemctl status nginx redis    # Статус сервисов
```

### Управление:
```bash
systemctl restart asu-server    # Перезапуск ASU
systemctl reload nginx          # Перезагрузка конфигурации
```

## 🔧 Кастомизация

### Добавление дополнительных Image Builder:
```bash
# Создайте imagebuilder_manager.sh из репозитория
./imagebuilder_manager.sh add 23.05 mediatek/filogic /path/to/imagebuilder.tar.xz
```

### Настройка пакетов по умолчанию:
Отредактируйте `/opt/asu-server/firmware-selector-openwrt-org/www/config.js`

### SSL сертификаты Let's Encrypt:
```bash
apt install certbot python3-certbot-nginx
certbot --nginx -d your-domain.com
```

## 🔒 Безопасность

Скрипт автоматически настраивает:
- ✅ UFW firewall (только HTTP/HTTPS/SSH)
- ✅ Отдельный пользователь для ASU
- ✅ Контейнеризация сборок
- ✅ Изоляция процессов

### Дополнительная защита:
```bash
# Ограничить доступ по IP
ufw allow from 192.168.1.0/24 to any port 80

# Включить rate limiting в nginx
# (добавьте в конфигурацию nginx)
```

## 📊 Мониторинг

### Простой мониторинг:
```bash
watch -n 5 '/opt/asu-server/status.sh'
```

### Prometheus/Grafana (опционально):
ASU поддерживает экспорт метрик для Prometheus

## ❓ FAQ

**Q: Можно ли добавить несколько Image Builder?**
A: Да, используйте `imagebuilder_manager.sh` после установки

**Q: Поддерживаются ли другие архитектуры?**  
A: Скрипт настроен для MediaTek Filogic, но легко адаптируется

**Q: Как обновить ASU до новой версии?**
A: `cd /opt/asu-server/asu && git pull && podman-compose build`

**Q: Что делать если сборка зависает?**
A: Увеличьте таймауты в `/opt/asu-server/asu/.env`

## 🚨 Устранение проблем

### ASU не запускается:
```bash
journalctl -u asu-server -n 50    # Посмотреть логи
systemctl restart asu-server      # Перезапустить
```

### Nginx 502 ошибка:
```bash
systemctl status asu-server       # Проверить ASU
curl http://localhost:8000/api/   # Прямой доступ к ASU
```

### Podman проблемы:
```bash
podman system prune -a            # Очистить кеш
systemctl --user restart podman   # Перезапуск для пользователя
```

## 🎯 Поддерживаемые устройства

### MediaTek Filogic (MT7981, MT7986, MT7622):
- **Xiaomi**: AX3000T, AX6000, Redmi AX6000, AX1800
- **TP-Link**: Archer AX53, AX73, AXE75, Deco X50
- **ASUS**: RT-AX53U, RT-AX59U, TUF-AX3000 V2
- **GL.iNet**: MT3000 (Beryl AX), MT6000 (Flint 2), AXT1800
- **Cudy**: WR3000, X6000, AX1800
- **Ubiquiti**: UniFi 6 Plus, Dream Router

## 📚 Дополнительные материалы

- [QUICK_START.md](QUICK_START.md) - Быстрый старт
- [MEDIATEK_DEVICES.md](MEDIATEK_DEVICES.md) - Подробно о MediaTek устройствах
- [UPDATE_24_10_1.md](UPDATE_24_10_1.md) - Особенности версии 24.10.1

---

## 🌟 Результат

После выполнения скрипта у вас будет **полноценный локальный сервер** для:

✅ **Сборки прошивок** с вашими пакетами  
✅ **Обновления устройств** через Attended Sysupgrade  
✅ **Веб-интерфейса** для выбора устройств  
✅ **API** для автоматизации  

**Одна команда → полная инфраструктура ASU! 🚀**