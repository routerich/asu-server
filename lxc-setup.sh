#!/bin/bash

# Скрипт автоматического развертывания ASU сервера в LXC контейнере

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Конфигурация
CONTAINER_NAME="${CONTAINER_NAME:-asu-server}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-ubuntu:22.04}"
CPU_CORES="${CPU_CORES:-4}"
MEMORY_GB="${MEMORY_GB:-8}"
HTTP_PORT="${HTTP_PORT:-80}"
API_PORT="${API_PORT:-8000}"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Развертывание ASU сервера в LXC контейнере         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Проверка, что LXD установлен
if ! command -v lxc &> /dev/null; then
    echo -e "${RED}LXD не установлен. Установите его:${NC}"
    echo "sudo snap install lxd"
    echo "sudo lxd init"
    exit 1
fi

# Ввод параметров
echo "Конфигурация контейнера:"
echo "- Имя: $CONTAINER_NAME"
echo "- Образ: $CONTAINER_IMAGE"
echo "- CPU: $CPU_CORES ядер"
echo "- RAM: ${MEMORY_GB}GB"
echo "- HTTP порт: $HTTP_PORT"
echo "- API порт: $API_PORT"
echo ""

echo "Изменить параметры? (y/n): "
read -r modify

if [ "$modify" = "y" ] || [ "$modify" = "Y" ]; then
    echo "Введите имя контейнера [$CONTAINER_NAME]: "
    read -r input_name
    if [ -n "$input_name" ]; then
        CONTAINER_NAME="$input_name"
    fi
    
    echo "Введите количество CPU ядер [$CPU_CORES]: "
    read -r input_cpu
    if [ -n "$input_cpu" ]; then
        CPU_CORES="$input_cpu"
    fi
    
    echo "Введите объем RAM в GB [$MEMORY_GB]: "
    read -r input_memory
    if [ -n "$input_memory" ]; then
        MEMORY_GB="$input_memory"
    fi
    
    echo "Введите HTTP порт [$HTTP_PORT]: "
    read -r input_http
    if [ -n "$input_http" ]; then
        HTTP_PORT="$input_http"
    fi
fi

echo ""
echo "Итоговая конфигурация:"
echo "- Имя: $CONTAINER_NAME"
echo "- CPU: $CPU_CORES ядер"
echo "- RAM: ${MEMORY_GB}GB"
echo "- HTTP порт: $HTTP_PORT"
echo "- API порт: $API_PORT"
echo ""

echo "Продолжить создание контейнера? (y/n): "
read -r confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Отменено"
    exit 0
fi

echo ""
echo -e "${GREEN}=== Создание и настройка LXC контейнера ===${NC}"

# Проверка, не существует ли уже контейнер
if lxc info "$CONTAINER_NAME" &>/dev/null; then
    echo -e "${YELLOW}Контейнер $CONTAINER_NAME уже существует.${NC}"
    echo "Удалить и пересоздать? (y/n): "
    read -r recreate
    
    if [ "$recreate" = "y" ] || [ "$recreate" = "Y" ]; then
        echo "Удаление существующего контейнера..."
        lxc stop "$CONTAINER_NAME" || true
        lxc delete "$CONTAINER_NAME"
    else
        echo "Отменено"
        exit 0
    fi
fi

# Создание контейнера
echo -e "${YELLOW}[1/8] Создание контейнера $CONTAINER_NAME...${NC}"
lxc launch "$CONTAINER_IMAGE" "$CONTAINER_NAME"

# Настройка ресурсов
echo -e "${YELLOW}[2/8] Настройка ресурсов...${NC}"
lxc config set "$CONTAINER_NAME" limits.cpu "$CPU_CORES"
lxc config set "$CONTAINER_NAME" limits.memory "${MEMORY_GB}GB"

# Настройка привилегий для Podman
echo -e "${YELLOW}[3/8] Настройка привилегий для контейнеров...${NC}"
lxc config set "$CONTAINER_NAME" security.privileged true
lxc config set "$CONTAINER_NAME" security.nesting true

# Проброс портов
echo -e "${YELLOW}[4/8] Настройка проброса портов...${NC}"
lxc config device add "$CONTAINER_NAME" http proxy \
    listen="tcp:0.0.0.0:$HTTP_PORT" \
    connect="tcp:127.0.0.1:80"

lxc config device add "$CONTAINER_NAME" api proxy \
    listen="tcp:0.0.0.0:$API_PORT" \
    connect="tcp:127.0.0.1:8000"

# Перезапуск для применения настроек
echo -e "${YELLOW}[5/8] Перезапуск контейнера...${NC}"
lxc restart "$CONTAINER_NAME"

# Ожидание запуска контейнера
echo "Ожидание запуска контейнера..."
sleep 10

# Обновление системы в контейнере
echo -e "${YELLOW}[6/8] Обновление системы в контейнере...${NC}"
lxc exec "$CONTAINER_NAME" -- bash -c "
apt update && apt upgrade -y
apt install -y wget curl
"

# Загрузка и установка ASU
echo -e "${YELLOW}[7/8] Загрузка и установка ASU сервера...${NC}"
lxc exec "$CONTAINER_NAME" -- bash -c "
cd /root
wget https://raw.githubusercontent.com/routerich/asu-server/main/asu_complete_installer.sh
chmod +x asu_complete_installer.sh
"

# Запуск установки ASU
echo -e "${YELLOW}[8/8] Установка ASU сервера в контейнере...${NC}"
echo "Это может занять несколько минут..."

lxc exec "$CONTAINER_NAME" -- bash -c "
cd /root
./asu_complete_installer.sh install
"

# Проверка статуса
echo ""
echo -e "${GREEN}=== Проверка установки ===${NC}"
sleep 5

# Получение IP адреса контейнера
CONTAINER_IP=$(lxc list "$CONTAINER_NAME" -c 4 | awk '/RUNNING/{print $4}' | cut -d/ -f1)
HOST_IP=$(hostname -I | awk '{print $1}')

echo ""
if lxc exec "$CONTAINER_NAME" -- systemctl is-active --quiet asu-server; then
    echo -e "${GREEN}✓ ASU сервер успешно установлен и запущен!${NC}"
else
    echo -e "${YELLOW}⚠ ASU сервер установлен, но еще запускается...${NC}"
    echo "Проверьте статус через несколько минут"
fi

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    УСТАНОВКА ЗАВЕРШЕНА!                     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}Доступ к ASU серверу:${NC}"
echo ""
echo -e "🌐 Веб-интерфейс (хост):     ${GREEN}http://$HOST_IP:$HTTP_PORT/${NC}"
echo -e "🔧 API endpoint (хост):      ${GREEN}http://$HOST_IP:$API_PORT/api/${NC}"
echo -e "📖 API документация (хост):  ${GREEN}http://$HOST_IP:$API_PORT/api/docs${NC}"
echo ""
echo -e "📦 Веб-интерфейс (контейнер): ${GREEN}http://$CONTAINER_IP/${NC}"
echo -e "🔧 API endpoint (контейнер):  ${GREEN}http://$CONTAINER_IP:8000/api/${NC}"
echo ""

echo -e "${YELLOW}Управление контейнером:${NC}"
echo "- Вход в контейнер:    lxc exec $CONTAINER_NAME -- bash"
echo "- Статус контейнера:   lxc info $CONTAINER_NAME"
echo "- Остановка:           lxc stop $CONTAINER_NAME"
echo "- Запуск:              lxc start $CONTAINER_NAME"
echo "- Удаление:            lxc delete $CONTAINER_NAME --force"
echo ""

echo -e "${YELLOW}Управление ASU в контейнере:${NC}"
echo "- Статус ASU:          lxc exec $CONTAINER_NAME -- /opt/asu-server/status.sh"
echo "- Добавить IB:         lxc exec $CONTAINER_NAME -- /opt/asu-server/asu_complete_installer.sh add ..."
echo "- Логи ASU:            lxc exec $CONTAINER_NAME -- journalctl -u asu-server -f"
echo ""

echo -e "${BLUE}Настройка клиентов OpenWrt:${NC}"
echo "В LuCI укажите сервер: http://$HOST_IP:$API_PORT/api/"
echo "В CLI: owut --server http://$HOST_IP:$API_PORT/api/ upgrade"
echo ""

echo -e "${GREEN}Для добавления Image Builder:${NC}"
echo "lxc exec $CONTAINER_NAME -- bash"
echo "./asu_complete_installer.sh add 24.10.1 mediatek/filogic official"
echo ""

# Создание удобного скрипта управления
cat > "${CONTAINER_NAME}-manage.sh" << EOF
#!/bin/bash

# Скрипт управления ASU контейнером $CONTAINER_NAME

case "\$1" in
    start)
        lxc start "$CONTAINER_NAME"
        echo "Контейнер $CONTAINER_NAME запущен"
        ;;
    stop)
        lxc stop "$CONTAINER_NAME"
        echo "Контейнер $CONTAINER_NAME остановлен"
        ;;
    restart)
        lxc restart "$CONTAINER_NAME"
        echo "Контейнер $CONTAINER_NAME перезапущен"
        ;;
    status)
        lxc info "$CONTAINER_NAME"
        echo ""
        echo "Статус ASU сервера:"
        lxc exec "$CONTAINER_NAME" -- /opt/asu-server/status.sh
        ;;
    shell)
        lxc exec "$CONTAINER_NAME" -- bash
        ;;
    logs)
        lxc exec "$CONTAINER_NAME" -- journalctl -u asu-server -f
        ;;
    add-ib)
        echo "Добавление Image Builder..."
        lxc exec "$CONTAINER_NAME" -- /root/asu_complete_installer.sh
        ;;
    delete)
        echo "Удаление контейнера $CONTAINER_NAME..."
        echo "Вы уверены? (y/n): "
        read -r confirm
        if [ "\$confirm" = "y" ]; then
            lxc delete "$CONTAINER_NAME" --force
            echo "Контейнер удален"
            rm -f "\$0"
        fi
        ;;
    *)
        echo "Использование: \$0 {start|stop|restart|status|shell|logs|add-ib|delete}"
        echo ""
        echo "Команды:"
        echo "  start    - Запустить контейнер"
        echo "  stop     - Остановить контейнер"
        echo "  restart  - Перезапустить контейнер"
        echo "  status   - Показать статус контейнера и ASU"
        echo "  shell    - Войти в контейнер"
        echo "  logs     - Показать логи ASU сервера"
        echo "  add-ib   - Добавить Image Builder"
        echo "  delete   - Удалить контейнер"
        echo ""
        echo "Доступ к сервису:"
        echo "  Веб-интерфейс: http://$HOST_IP:$HTTP_PORT/"
        echo "  API: http://$HOST_IP:$API_PORT/api/"
        ;;
esac
EOF

chmod +x "${CONTAINER_NAME}-manage.sh"

echo -e "${GREEN}Создан скрипт управления: ${CONTAINER_NAME}-manage.sh${NC}"
echo "Используйте ./${CONTAINER_NAME}-manage.sh status для проверки"