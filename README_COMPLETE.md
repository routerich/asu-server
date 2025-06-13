# Локальный ASU сервер с гибким управлением Image Builder

Полнофункциональный сервер для сборки прошивок OpenWrt с поддержкой различных версий и архитектур.

## Возможности

✅ **Гибкое управление версиями и архитектурами**
- Добавляйте любые версии OpenWrt (официальные и кастомные)
- Поддержка всех архитектур
- Включение/выключение отдельных Image Builder
- Импорт официальных релизов одной командой

✅ **Удобные интерфейсы**
- Веб-интерфейс для управления Image Builder
- Командная строка с интерактивным меню
- REST API для автоматизации

✅ **Интеграция с OpenWrt устройствами**
- Attended Sysupgrade через LuCI
- Обновление через owut/auc
- Сохранение настроек при обновлении

## Установка на Ubuntu

```bash
sudo bash install_ubuntu.sh
```

Скрипт автоматически установит и настроит все компоненты.

## Управление Image Builder

### 1. Через веб-интерфейс

Откройте в браузере: `http://YOUR_SERVER_IP/manage.html`

![Управление Image Builder](manage-screenshot.png)

### 2. Через командную строку

**Интерактивный режим:**
```bash
/opt/asu-server/imagebuilder_manager.sh
```

**Быстрые команды:**
```bash
# Показать установленные
./imagebuilder_manager.sh list

# Добавить официальный релиз
./imagebuilder_manager.sh add 24.10 x86/64 official

# Добавить из файла
./imagebuilder_manager.sh add custom ath79/generic /path/to/imagebuilder.tar.xz

# Добавить по URL
./imagebuilder_manager.sh add 23.05 ramips/mt7621 https://example.com/ib.tar.xz

# Выключить/включить
./imagebuilder_manager.sh disable 22.03 x86/64
./imagebuilder_manager.sh enable 22.03 x86/64

# Удалить
./imagebuilder_manager.sh remove 21.02 x86/generic

# Импорт официальных релизов (интерактивно выбрать версии и архитектуры)
./imagebuilder_manager.sh import-official
```

### 3. Через API

```bash
# Получить список Image Builder
curl http://localhost/api/imagebuilders

# Обновить конфигурацию
curl -X POST http://localhost/api/imagebuilders/refresh
```

## Примеры использования

### Сценарий 1: Добавить последние стабильные версии для популярных роутеров

```bash
cd /opt/asu-server

# Быстрое добавление версии 24.10.1 для MediaTek Filogic
./add_24_10_1.sh

# Или добавить вручную только MediaTek Filogic
./imagebuilder_manager.sh add 24.10.1 mediatek/filogic official

# Для других архитектур используйте старые версии:
./imagebuilder_manager.sh add 24.10 ath79/generic official       # TP-Link, Netgear
./imagebuilder_manager.sh add 24.10 ramips/mt7621 official       # Xiaomi, D-Link  
./imagebuilder_manager.sh add 24.10 ipq40xx/generic official     # AVM Fritz!Box
```

### Сценарий 2: Настроить кастомную версию

```bash
# Скачиваем свой Image Builder
wget https://myserver.com/custom-imagebuilder.tar.xz

# Добавляем с кастомным именем
./imagebuilder_manager.sh add mycustom ramips/mt7621 ./custom-imagebuilder.tar.xz "My Custom Build"
```

### Сценарий 3: Отключить старые версии

```bash
# Отключаем старые версии, но оставляем файлы
./imagebuilder_manager.sh disable 21.02 x86/64
./imagebuilder_manager.sh disable 22.03 x86/64
```

## Структура хранения

```
/opt/asu-server/
├── imagebuilders/
│   ├── 24.10/
│   │   ├── x86/
│   │   │   └── 64/
│   │   ├── ath79/
│   │   │   └── generic/
│   │   └── ramips/
│   │       └── mt7621/
│   ├── 23.05/
│   │   └── ...
│   └── custom/
│       └── ...
├── imagebuilders.json          # Конфигурация всех Image Builder
├── imagebuilder_manager.sh     # Скрипт управления
└── ...
```

## Настройка клиентов OpenWrt

### Вариант 1: LuCI (веб-интерфейс)

На роутере:
```bash
opkg update
opkg install luci-app-attendedsysupgrade
```

Затем в веб-интерфейсе:
1. System → Attended Sysupgrade
2. Server URL: `http://YOUR_SERVER_IP/api/`
3. Request Firmware

### Вариант 2: CLI (командная строка)

Новые версии (24.10+):
```bash
owut --server http://YOUR_SERVER_IP/api/ upgrade
```

Старые версии:
```bash
opkg install auc
auc -s http://YOUR_SERVER_IP/api/
```

## Решение проблем

### Image Builder не появляется в firmware-selector

1. Проверьте, что он включен:
```bash
./imagebuilder_manager.sh list
```

2. Обновите конфигурацию:
```bash
./imagebuilder_manager.sh update
systemctl restart asu-server
```

### Ошибка при добавлении Image Builder

Проверьте:
- Достаточно ли места на диске (нужно ~2GB на каждый)
- Правильный ли формат архива (.tar.xz)
- Доступен ли URL для скачивания

### Сборка прошивки зависает

Увеличьте таймауты в `/opt/asu-server/asu/.env`:
```
BUILD_TIMEOUT=1200
```

## Автоматизация

### Скрипт для добавления всех версий для конкретного устройства

```bash
#!/bin/bash
# add_for_device.sh

DEVICE_TARGET="ath79/generic"
VERSIONS=("24.10" "23.05" "22.03")

for ver in "${VERSIONS[@]}"; do
    /opt/asu-server/imagebuilder_manager.sh add "$ver" "$DEVICE_TARGET" official
done
```

### Резервное копирование конфигурации

```bash
# Экспорт
./imagebuilder_manager.sh export backup-$(date +%Y%m%d).json

# Импорт
./imagebuilder_manager.sh import backup-20240113.json
```

## Безопасность

1. **Ограничьте доступ через firewall:**
```bash
ufw allow from 192.168.1.0/24 to any port 80
```

2. **Используйте HTTPS с Let's Encrypt:**
```bash
apt install certbot python3-certbot-nginx
certbot --nginx -d asu.yourdomain.com
```

3. **Добавьте аутентификацию в nginx:**
```nginx
location /api/ {
    auth_basic "ASU API";
    auth_basic_user_file /etc/nginx/.htpasswd;
    proxy_pass http://127.0.0.1:8000/;
}
```

## Мониторинг

Проверка статуса:
```bash
/opt/asu-server/status.sh
```

Просмотр логов:
```bash
# Все логи
journalctl -u asu-server -f

# Только ошибки
journalctl -u asu-server -p err

# Логи конкретного worker
cd /opt/asu-server/asu && podman-compose logs worker
```

## Обновление

Для обновления ASU до последней версии:
```bash
cd /opt/asu-server/asu
git pull
podman-compose build
systemctl restart asu-server
```

---

**Поддержка:** Создайте issue в репозитории при возникновении проблем.