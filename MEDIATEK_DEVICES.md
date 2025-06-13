# Поддержка устройств MediaTek Filogic в OpenWrt 24.10.1

Версия OpenWrt 24.10.1 включает улучшенную поддержку новых устройств на чипах MediaTek Filogic.

## Поддерживаемые чипы

- **MT7981** - Wi-Fi 6 dual-band
- **MT7986** - Wi-Fi 6E tri-band  
- **MT7622** - Wi-Fi 5/6 dual-band
- **MT7621** - Более старые устройства (используйте архитектуру ramips/mt7621)

## Популярные устройства MediaTek Filogic

### Xiaomi
- **Xiaomi AX3000T** (MT7981)
- **Xiaomi AX6000** (MT7986)
- **Redmi AX6000** (MT7986)
- **Xiaomi AX1800** (MT7622)

### TP-Link
- **Archer AX53** (MT7622)
- **Archer AX73** (MT7622)
- **Archer AXE75** (MT7986)
- **Deco X50** (MT7981)

### ASUS
- **RT-AX53U** (MT7622)
- **RT-AX59U** (MT7986)
- **TUF-AX3000 V2** (MT7981)

### GL.iNet
- **GL-MT3000 (Beryl AX)** (MT7981)
- **GL-MT6000 (Flint 2)** (MT7986)
- **GL-AXT1800 (Slate AX)** (MT7622)

### Cudy
- **WR3000** (MT7981)
- **X6000** (MT7986)
- **AX1800** (MT7622)

### Ubiquiti
- **UniFi 6 Plus** (MT7622)
- **Dream Router** (MT7622)

## Установка Image Builder для MediaTek Filogic

```bash
cd /opt/asu-server

# Быстрая установка
./add_24_10_1.sh

# Или вручную
./imagebuilder_manager.sh add 24.10.1 mediatek/filogic official
```

## Сборка прошивки для устройства

### Через веб-интерфейс:

1. Откройте http://YOUR_SERVER_IP/
2. Выберите версию "24.10.1"
3. В поиске устройств введите модель (например, "Xiaomi AX3000T")
4. Выберите нужные пакеты
5. Нажмите "Request Build"

### Через API:

```bash
curl -X POST http://YOUR_SERVER_IP/api/build \
  -H "Content-Type: application/json" \
  -d '{
    "version": "24.10.1",
    "target": "mediatek/filogic", 
    "profile": "xiaomi_redmi-ax6000",
    "packages": ["luci", "luci-ssl", "luci-app-wireguard", "wireguard-tools"]
  }'
```

## Обновление через Attended Sysupgrade

На устройстве MediaTek с уже установленным OpenWrt:

### Через LuCI:
1. System → Attended Sysupgrade
2. Server: `http://YOUR_SERVER_IP/api/`
3. Request Firmware

### Через CLI:
```bash
owut --server http://YOUR_SERVER_IP/api/ upgrade
```

## Особенности MediaTek Filogic

### Wi-Fi 6/6E поддержка
- Поддержка 160MHz каналов
- OFDMA и MU-MIMO
- Improved beamforming

### Аппаратное ускорение
- Hardware NAT offloading
- Crypto acceleration
- Flow offloading для высокой производительности

### Современные интерфейсы
- USB 3.0 на многих устройствах
- Gigabit Ethernet
- 2.5GbE на топовых моделях

## Рекомендуемые пакеты для MediaTek устройств

### Базовые:
```
luci luci-ssl nano htop
```

### Wi-Fi оптимизация:
```
hostapd-utils iw wireless-tools
```

### Производительность:
```
irqbalance
```

### VPN:
```
wireguard-tools luci-app-wireguard
openvpn-openssl luci-app-openvpn
```

### Мониторинг:
```
luci-app-statistics collectd-mod-cpu collectd-mod-memory
```

## Известные особенности

1. **WiFi регионы**: Убедитесь что выбрали правильный WiFi регион в настройках
2. **160MHz каналы**: Не все регионы поддерживают широкие каналы
3. **Hardware offloading**: Включите в Network → Interfaces → WAN → Advanced → Use builtin switch

## Поиск профиля устройства

Если не знаете точное название профиля:

```bash
# Через API
curl http://YOUR_SERVER_IP/api/overview/24.10.1 | jq '.targets."mediatek/filogic"'

# Поиск по бренду
curl http://YOUR_SERVER_IP/api/overview/24.10.1 | jq '.profiles[] | select(.id | contains("xiaomi"))'
```

## Backup и восстановление

Перед обновлением на MediaTek устройствах:

```bash
# Создать backup
sysupgrade -b /tmp/backup.tar.gz

# При проблемах восстановить через TFTP recovery mode
```

---

**Важно**: Всегда читайте changelog для вашего конкретного устройства перед обновлением!