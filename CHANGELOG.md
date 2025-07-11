# Changelog

## [1.0.0] - 2025-01-13

### Добавлено
- 🚀 Единый установщик `asu_complete_installer.sh` объединяющий все функции
- ✅ Автоматическая проверка системных требований
- ✅ Полная установка ASU сервера на Ubuntu/Debian
- ✅ Интерактивное меню и командный интерфейс
- ✅ Управление Image Builder (добавление, удаление, включение/выключение)
- ✅ Поддержка официальных и кастомных Image Builder
- ✅ Автоматическая настройка nginx, redis, systemd
- ✅ Скрипты мониторинга и статуса
- ✅ Документация для настройки клиентов OpenWrt
- ✅ Поддержка LXC контейнеров
- ✅ Быстрое добавление популярных архитектур

### Объединенные скрипты
Следующие скрипты были объединены в `asu_complete_installer.sh`:
- `install_ubuntu.sh` - полная установка
- `deploy_complete_asu.sh` - развертывание с кастомными IB
- `imagebuilder_manager.sh` - управление Image Builder
- `setup_local_server.sh` - настройка локального сервера
- `setup_attended_sysupgrade.sh` - настройка Attended Sysupgrade
- `check_requirements.sh` - проверка системы
- `add_24_10_1.sh` - быстрое добавление 24.10.1

### Технические улучшения
- Единый конфигурационный файл для Image Builder
- Динамическая генерация конфигурации ASU
- Автоматическое обновление конфигурации при изменениях
- Цветной вывод для лучшего UX
- Подробное логирование операций
- Проверка совместимости и зависимостей

### Поддерживаемые архитектуры
- MediaTek Filogic (MT7981, MT7986, MT7622)
- x86/64 для серверов и PC
- ath79/generic для TP-Link, Ubiquiti
- ramips/mt7621 для Xiaomi, Redmi
- ipq40xx/generic для Qualcomm IPQ40xx
- bcm27xx/bcm2711 для Raspberry Pi 4

### Документация
- Полный README с инструкциями установки
- Примеры использования в LXC
- Настройка клиентов OpenWrt
- Changelog и лицензия MIT