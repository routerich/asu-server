# 🚀 Быстрый запуск ASU сервера

Полное развертывание ASU сервера с вашим кастомным Image Builder одной командой.

## ⚡ Мгновенный запуск

```bash
sudo bash deploy_complete_asu.sh
```

Скрипт запросит:
1. **Путь к вашему Image Builder** - MediaTek Filogic 24.10.1
2. **Название сервера** (опционально)  
3. **Домен для HTTPS** (опционально)

## 📦 Что устанавливается

### Компоненты:
- ✅ **ASU сервер** - сборка прошивок по запросу
- ✅ **firmware-selector** - веб-интерфейс выбора устройств
- ✅ **Attended Sysupgrade API** - обновление через LuCI/CLI
- ✅ **Nginx** - веб-сервер с reverse proxy
- ✅ **Redis** - кеширование сборок
- ✅ **Podman** - контейнеризация сборок

### Автоматическая настройка:
- ✅ Ваш кастомный Image Builder (MediaTek Filogic 24.10.1)
- ✅ Systemd сервисы для автозапуска
- ✅ Firewall (HTTP/HTTPS доступ)
- ✅ SSL сертификаты (самоподписанные или Let's Encrypt)

## 🎯 Результат

После установки у вас будет:

### 🌐 Веб-сайт: `http://YOUR_SERVER_IP/`
- Выбор устройства MediaTek Filogic
- Выбор пакетов для установки
- Запрос сборки прошивки
- Скачивание готовых образов

### 🔧 API: `http://YOUR_SERVER_IP/api/`
- REST API для Attended Sysupgrade
- Автоматизация сборок
- Интеграция с owut/auc

### 📱 Поддержка устройств MediaTek Filogic:
- Xiaomi AX3000T, AX6000, Redmi AX6000
- TP-Link Archer AX53, AX73, AXE75  
- ASUS RT-AX53U, RT-AX59U
- GL.iNet MT3000, MT6000
- Cudy WR3000, X6000

## 🔌 Подключение устройств OpenWrt

### Через LuCI:
1. System → Attended Sysupgrade
2. Server: `http://YOUR_SERVER_IP/api/`
3. Request Firmware

### Через CLI:
```bash
owut --server http://YOUR_SERVER_IP/api/ upgrade
```

## ⚙️ Управление

### Проверка статуса:
```bash
/opt/asu-server/status.sh
```

### Просмотр логов:
```bash
journalctl -u asu-server -f
```

### Перезапуск сервиса:
```bash
systemctl restart asu-server
```

## 🛠️ Требования

- **ОС**: Ubuntu 20.04+ / Debian 11+
- **RAM**: 4GB+ (рекомендуется 8GB)
- **Диск**: 20GB+ свободного места
- **CPU**: 2+ ядра
- **Сеть**: Интернет для скачивания зависимостей

## 🔒 Безопасность

Скрипт автоматически:
- ✅ Настраивает UFW firewall
- ✅ Создает отдельного пользователя для ASU
- ✅ Настраивает HTTPS (при указании домена)
- ✅ Добавляет заголовки безопасности в Nginx

## 📋 Пример запуска

```bash
$ sudo bash deploy_complete_asu.sh

╔══════════════════════════════════════════════════════════════╗
║              Развертывание ASU сервера OpenWrt               ║
║        ASU + firmware-selector + Attended Sysupgrade        ║
╚══════════════════════════════════════════════════════════════╝

=== Конфигурация развертывания ===

Введите путь к вашему Image Builder (MediaTek Filogic 24.10.1):
Например: /path/to/openwrt-imagebuilder-24.10.1-mediatek-filogic.Linux-x86_64.tar.xz
Или URL для скачивания:
> /home/user/my-custom-imagebuilder.tar.xz

Введите название вашего сервера (по умолчанию: Local ASU Server):
> My Custom OpenWrt Builder

Введите домен для HTTPS (опционально, для HTTP оставьте пустым):
> asu.mydomain.com

Конфигурация:
- Image Builder: /home/user/my-custom-imagebuilder.tar.xz
- Название сервера: My Custom OpenWrt Builder  
- Домен: asu.mydomain.com

Продолжить установку? (y/n): y

[Процесс установки...]

╔══════════════════════════════════════════════════════════════╗
║                     УСТАНОВКА ЗАВЕРШЕНА!                    ║
╚══════════════════════════════════════════════════════════════╝

🌐 Веб-интерфейс: https://asu.mydomain.com/
🔧 API endpoint: https://asu.mydomain.com/api/
📖 API документация: https://asu.mydomain.com/api/docs
```

## 🆘 Поддержка

При возникновении проблем:

1. **Проверьте логи**: `journalctl -u asu-server -f`
2. **Статус сервисов**: `/opt/asu-server/status.sh`
3. **Перезапустите**: `systemctl restart asu-server nginx redis`

---

**Готово!** Теперь ваши устройства MediaTek смогут обновляться через ваш локальный ASU сервер.