# ASU Server - OpenWrt Attended Sysupgrade Server

Автоматизированный установщик и менеджер для ASU (Attended Sysupgrade) сервера OpenWrt с поддержкой кастомных Image Builder.

## 🚀 Возможности

- ✅ **Полная автоматическая установка** ASU сервера на Ubuntu/Debian
- ✅ **Управление Image Builder** - добавление, удаление, включение/выключение
- ✅ **Веб-интерфейс** для выбора и сборки прошивок
- ✅ **API для Attended Sysupgrade** - автоматическое обновление роутеров
- ✅ **Поддержка контейнеров** LXC/Docker
- ✅ **Интерактивное меню** и командная строка
- ✅ **Проверка системных требований**
- ✅ **Мониторинг и статистика**

## 📋 Системные требования

### Минимальные
- Ubuntu 20.04+ или Debian 11+
- 2+ CPU ядра
- 4+ GB RAM  
- 20+ GB свободного места
- Интернет соединение

### Рекомендуемые
- 4+ CPU ядра
- 8+ GB RAM
- 100+ GB SSD
- Стабильное интернет соединение

## 🛠 Быстрая установка

### Вариант 1: Прямая установка на хост

```bash
# Скачать и запустить установщик
wget https://raw.githubusercontent.com/routerich/asu-server/main/asu_complete_installer.sh
chmod +x asu_complete_installer.sh

# Проверить систему
sudo ./asu_complete_installer.sh check

# Установить сервер
sudo ./asu_complete_installer.sh install
```

### Вариант 2: Установка в LXC контейнер

```bash
# На хосте создать контейнер
lxc launch ubuntu:22.04 asu-server
lxc config set asu-server limits.cpu 4
lxc config set asu-server limits.memory 8GB
lxc config set asu-server security.privileged true
lxc config set asu-server security.nesting true

# Проброс портов
lxc config device add asu-server http proxy listen=tcp:0.0.0.0:80 connect=tcp:127.0.0.1:80
lxc config device add asu-server api proxy listen=tcp:0.0.0.0:8000 connect=tcp:127.0.0.1:8000

lxc restart asu-server

# Установка в контейнере
lxc exec asu-server -- bash -c "
apt update && apt install -y wget
wget https://raw.githubusercontent.com/routerich/asu-server/main/asu_complete_installer.sh
chmod +x asu_complete_installer.sh
./asu_complete_installer.sh install
"
```

## 📖 Использование

### Интерактивный режим
```bash
./asu_complete_installer.sh
```

### Командный режим
```bash
# Проверка системы
./asu_complete_installer.sh check

# Установка сервера  
./asu_complete_installer.sh install

# Управление Image Builder
./asu_complete_installer.sh list                                    # Список установленных
./asu_complete_installer.sh add 24.10.1 mediatek/filogic official   # Добавить официальный
./asu_complete_installer.sh add custom ath79/generic /path/to/ib.tar.xz  # Добавить кастомный
./asu_complete_installer.sh remove 24.10.1 mediatek/filogic         # Удалить
./asu_complete_installer.sh enable 24.10.1 mediatek/filogic         # Включить
./asu_complete_installer.sh disable 24.10.1 mediatek/filogic        # Выключить

# Статус сервера
./asu_complete_installer.sh status
```

## 🌐 Доступ к сервису

После установки сервис будет доступен по адресам:

- **Веб-интерфейс**: http://YOUR_SERVER_IP/
- **API endpoint**: http://YOUR_SERVER_IP/api/
- **API документация**: http://YOUR_SERVER_IP/api/docs

## 📱 Настройка клиентов OpenWrt

### LuCI (веб-интерфейс роутера)

1. Установите пакет:
```bash
opkg update
opkg install luci-app-attendedsysupgrade
```

2. В веб-интерфейсе роутера:
   - System → Attended Sysupgrade
   - Server URL: `http://YOUR_SERVER_IP/api/`
   - Нажмите "Request Firmware"

### CLI с owut
```bash
owut --server http://YOUR_SERVER_IP/api/ upgrade
```

### CLI с auc (старые версии)
```bash
opkg install auc
auc -s http://YOUR_SERVER_IP/api/
```

## 🔧 Управление сервисом

```bash
# Статус сервисов
systemctl status asu-server nginx redis

# Перезапуск
systemctl restart asu-server

# Логи
journalctl -u asu-server -f

# Скрипт статуса (если установлен через installer)
/opt/asu-server/status.sh
```

## 📁 Структура проекта

```
/opt/asu-server/
├── asu/                              # ASU сервер
├── firmware-selector-openwrt-org/    # Веб-интерфейс
├── imagebuilders/                    # Image Builder файлы
│   └── 24.10.1/
│       └── mediatek/filogic/
├── public/store/                     # Собранные образы
├── imagebuilders.json               # Конфигурация Image Builder
├── status.sh                        # Скрипт статуса
└── CLIENT_SETUP.md                  # Инструкции для клиентов
```

## 🚀 Поддерживаемые архитектуры

### MediaTek (рекомендуется)
- **mediatek/filogic** - MT7981, MT7986, MT7622
  - Xiaomi: AX3000T, AX6000, Redmi AX6000
  - TP-Link: Archer AX53, AX73, AXE75
  - ASUS: RT-AX53U, RT-AX59U
  - GL.iNet: MT3000, MT6000

### Другие популярные
- **x86/64** - PC, серверы, виртуальные машины
- **ath79/generic** - TP-Link, Ubiquiti
- **ramips/mt7621** - Xiaomi, Redmi, TP-Link
- **ipq40xx/generic** - Qualcomm IPQ40xx
- **bcm27xx/bcm2711** - Raspberry Pi 4

## 🛠 Разработка

### Структура скрипта
Основной скрипт `asu_complete_installer.sh` включает:

- Проверку системных требований
- Установку зависимостей
- Настройку ASU сервера
- Управление Image Builder
- Настройку веб-сервера
- Создание systemd сервисов
- Интерактивное меню

### Добавление новых функций
1. Форкните репозиторий
2. Создайте ветку для новой функции
3. Внесите изменения
4. Создайте Pull Request

## 📋 Changelog

### v1.0.0
- Первый релиз объединенного установщика
- Поддержка Ubuntu/Debian
- Интерактивное и командное управление
- Автоматическая настройка всех компонентов
- Поддержка LXC контейнеров

## 🤝 Поддержка

- **Issues**: https://github.com/routerich/asu-server/issues
- **Discussions**: https://github.com/routerich/asu-server/discussions
- **Wiki**: https://github.com/routerich/asu-server/wiki

## 📄 Лицензия

MIT License - см. [LICENSE](LICENSE) файл.

## 🙏 Благодарности

- [OpenWrt ASU](https://github.com/openwrt/asu) - основной ASU сервер
- [Firmware Selector](https://github.com/openwrt/firmware-selector-openwrt-org) - веб-интерфейс
- Сообщество OpenWrt за отличную документацию

---

⭐ **Если проект полезен, поставьте звездочку!**