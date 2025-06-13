# Обновление до OpenWrt 24.10.1 для MediaTek Filogic

OpenWrt 24.10.1 - это последний стабильный релиз с исправлениями безопасности и багфиксами.  
**Данная сборка поддерживает только архитектуру mediatek/filogic.**

## Быстрое добавление версии 24.10.1

### Вариант 1: Автоматическое добавление mediatek/filogic

```bash
cd /opt/asu-server
./add_24_10_1.sh
```

Этот скрипт автоматически добавит версию 24.10.1 для архитектуры:
- **mediatek/filogic** - поддерживает устройства на чипах MediaTek MT7981, MT7986, MT7622 и других Filogic

### Поддерживаемые устройства MediaTek Filogic:
- Xiaomi AX3000T, AX6000, Redmi AX6000
- TP-Link Archer AX53, AX73, AXE75
- ASUS RT-AX53U, RT-AX59U
- GL.iNet MT3000, MT6000
- Cudy WR3000, X6000
- И другие устройства на чипах MediaTek Filogic

### Вариант 2: Ручное добавление

```bash
cd /opt/asu-server

# Добавить только MediaTek Filogic для версии 24.10.1
./imagebuilder_manager.sh add 24.10.1 mediatek/filogic official
```

### Вариант 3: Через веб-интерфейс

1. Откройте http://YOUR_SERVER_IP/manage.html
2. Нажмите "Быстрое добавление"
3. Выберите версию "24.10.1 (Latest)"
4. Выберите архитектуру "MediaTek Filogic (24.10.1)"
5. Нажмите "Добавить выбранные"

## Что нового в 24.10.1

- Исправления безопасности
- Обновленные драйверы для WiFi
- Улучшенная поддержка новых устройств
- Исправления ошибок в ядре Linux

## Проверка установки

После добавления версии 24.10.1:

```bash
# Проверить список установленных Image Builder
./imagebuilder_manager.sh list

# Обновить конфигурацию ASU
./imagebuilder_manager.sh update

# Проверить статус сервера
./status.sh
```

## Использование на устройствах

После добавления версии 24.10.1 на сервер, устройства смогут обновляться до неё:

### Через LuCI:
1. System → Attended Sysupgrade
2. Выберите версию 24.10.1
3. Request Firmware

### Через CLI:
```bash
owut --server http://YOUR_SERVER_IP/api/ upgrade
```

## Переключение на 24.10.1 как версию по умолчанию

Чтобы сделать 24.10.1 версией по умолчанию в firmware-selector:

```bash
# Отредактируйте конфигурацию
nano /opt/asu-server/firmware-selector-openwrt-org/www/config.js

# Измените default_version на '24.10.1'
default_version: '24.10.1'

# Перезапустите nginx
systemctl reload nginx
```

## Устранение проблем

Если возникают проблемы:

1. **Проверьте доступность официальных образов:**
```bash
curl -I https://downloads.openwrt.org/releases/24.10.1/targets/x86/64/
```

2. **Проверьте логи ASU:**
```bash
journalctl -u asu-server -f
```

3. **Очистите кеш:**
```bash
cd /opt/asu-server/asu
podman-compose restart redis
```

4. **Пересоберите контейнеры:**
```bash
cd /opt/asu-server/asu
podman-compose build --no-cache
systemctl restart asu-server
```