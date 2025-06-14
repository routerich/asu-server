#!/bin/bash

# ===============================================================================
# Единый скрипт установки и управления ASU сервером OpenWrt
# Объединяет все функции: установка, настройка, управление Image Builder
# ===============================================================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Конфигурация
INSTALL_DIR="${INSTALL_DIR:-/opt/asu-server}"
CONFIG_FILE="$INSTALL_DIR/imagebuilders.json"
SERVER_NAME="${SERVER_NAME:-Local ASU Server}"
DOMAIN="${DOMAIN:-}"

# ===============================================================================
# ФУНКЦИИ ПРОВЕРКИ СИСТЕМЫ
# ===============================================================================

check_requirement() {
    local name="$1"
    local current="$2"
    local required="$3"
    local status="$4"
    
    printf "%-25s" "$name:"
    
    if [ "$status" = "ok" ]; then
        echo -e "${GREEN}✓ $current${NC} (требуется: $required)"
    elif [ "$status" = "warning" ]; then
        echo -e "${YELLOW}⚠ $current${NC} (рекомендуется: $required)"
    else
        echo -e "${RED}✗ $current${NC} (требуется: $required)"
    fi
}

check_system_requirements() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        Проверка системных требований           ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""

    # Операционная система
    echo -e "${YELLOW}=== Операционная система ===${NC}"
    OS=$(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")
    ARCH=$(uname -m)

    if [[ "$OS" =~ Ubuntu.*2[024]\. ]] || [[ "$OS" =~ Debian.*1[12] ]]; then
        check_requirement "ОС" "$OS" "Ubuntu 20.04+/Debian 11+" "ok"
    else
        check_requirement "ОС" "$OS" "Ubuntu 20.04+/Debian 11+" "error"
    fi

    if [ "$ARCH" = "x86_64" ]; then
        check_requirement "Архитектура" "$ARCH" "x86_64" "ok"
    else
        check_requirement "Архитектура" "$ARCH" "x86_64" "error"
    fi

    # Процессор и память
    echo ""
    echo -e "${YELLOW}=== Ресурсы системы ===${NC}"
    CPU_CORES=$(nproc)
    RAM_GB=$(free -g | awk '/^Mem:/ {print $2}')
    DISK_AVAIL_GB=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')

    if [ "$CPU_CORES" -ge 4 ]; then
        check_requirement "Ядра CPU" "$CPU_CORES ядер" "4+ ядер" "ok"
    elif [ "$CPU_CORES" -ge 2 ]; then
        check_requirement "Ядра CPU" "$CPU_CORES ядра" "4+ ядер" "warning"
    else
        check_requirement "Ядра CPU" "$CPU_CORES ядро" "2+ ядер" "error"
    fi

    if [ "$RAM_GB" -ge 8 ]; then
        check_requirement "RAM" "${RAM_GB}GB" "8+ GB" "ok"
    elif [ "$RAM_GB" -ge 4 ]; then
        check_requirement "RAM" "${RAM_GB}GB" "8+ GB" "warning"
    else
        check_requirement "RAM" "${RAM_GB}GB" "4+ GB" "error"
    fi

    if [ "$DISK_AVAIL_GB" -ge 100 ]; then
        check_requirement "Свободное место" "${DISK_AVAIL_GB}GB" "100+ GB" "ok"
    elif [ "$DISK_AVAIL_GB" -ge 20 ]; then
        check_requirement "Свободное место" "${DISK_AVAIL_GB}GB" "100+ GB" "warning"
    else
        check_requirement "Свободное место" "${DISK_AVAIL_GB}GB" "20+ GB" "error"
    fi

    # Сеть
    echo ""
    echo -e "${YELLOW}=== Сетевое подключение ===${NC}"
    if ping -c 1 google.com >/dev/null 2>&1; then
        check_requirement "Интернет" "Доступен" "Требуется" "ok"
    else
        check_requirement "Интернет" "Недоступен" "Требуется" "error"
    fi

    # Итоговая оценка
    echo ""
    if [ "$CPU_CORES" -ge 4 ] && [ "$RAM_GB" -ge 8 ] && [ "$DISK_AVAIL_GB" -ge 100 ]; then
        echo -e "${GREEN}🎉 Отличная конфигурация!${NC} Система полностью готова для продакшена"
        return 0
    elif [ "$CPU_CORES" -ge 2 ] && [ "$RAM_GB" -ge 4 ] && [ "$DISK_AVAIL_GB" -ge 20 ]; then
        echo -e "${YELLOW}⚠ Базовая конфигурация${NC} - подходит для тестирования"
        return 1
    else
        echo -e "${RED}❌ Недостаточная конфигурация${NC} - система может работать нестабильно"
        return 2
    fi
}

# ===============================================================================
# ФУНКЦИИ УПРАВЛЕНИЯ IMAGE BUILDER
# ===============================================================================

init_imagebuilder_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo '{"imagebuilders": []}' > "$CONFIG_FILE"
    fi
}

list_imagebuilders() {
    echo -e "${BLUE}=== Установленные Image Builder ===${NC}"
    echo ""
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Нет установленных Image Builder"
        return
    fi
    
    jq -r '.imagebuilders[] | "\(.version)|\(.target)|\(.path)|\(.added)|\(.enabled)"' "$CONFIG_FILE" | \
    while IFS='|' read -r version target path added enabled; do
        # Удаляем пробелы
        version=$(echo "$version" | xargs)
        target=$(echo "$target" | xargs)
        path=$(echo "$path" | xargs)
        added=$(echo "$added" | xargs)
        enabled=$(echo "$enabled" | xargs)
        
        status=$([ "$enabled" = "true" ] && echo -e "${GREEN}включен${NC}" || echo -e "${RED}выключен${NC}")
        echo -e "Версия: ${YELLOW}$version${NC}, Target: ${YELLOW}$target${NC}, Статус: $status"
        echo "  Путь: $path"
        echo "  Добавлен: $added"
        echo ""
    done
}

add_imagebuilder() {
    local version=$1
    local target=$2
    local source=$3
    local custom_name=$4
    
    if [ -z "$version" ] || [ -z "$target" ] || [ -z "$source" ]; then
        echo -e "${RED}Использование: add_imagebuilder <версия> <target> <источник> [название]${NC}"
        echo "Источник может быть:"
        echo "  - Путь к файлу .tar.xz"
        echo "  - URL для скачивания"
        echo "  - 'official' для скачивания с downloads.openwrt.org"
        return 1
    fi
    
    # Проверка, не добавлен ли уже
    if jq -e ".imagebuilders[] | select(.version == \"$version\" and .target == \"$target\")" "$CONFIG_FILE" > /dev/null 2>&1; then
        echo -e "${YELLOW}Image Builder для $version/$target уже существует${NC}"
        echo -n "Заменить? (y/n): "
        read -r response
        if [ "$response" != "y" ]; then
            return 1
        fi
        remove_imagebuilder "$version" "$target" "quiet"
    fi
    
    local ib_dir="$INSTALL_DIR/imagebuilders/$version/$target"
    mkdir -p "$ib_dir"
    
    echo -e "${YELLOW}Добавление Image Builder $version/$target...${NC}"
    
    # Обработка источника
    if [ "$source" = "official" ]; then
        local arch=$(echo "$target" | tr '/' '-')
        local url="https://downloads.openwrt.org/releases/$version/targets/$target/openwrt-imagebuilder-$version-$arch.Linux-x86_64.tar.xz"
        
        echo "Скачивание с $url..."
        if ! wget -O "/tmp/imagebuilder-$version-$arch.tar.xz" "$url"; then
            echo -e "${RED}Ошибка скачивания${NC}"
            return 1
        fi
        source="/tmp/imagebuilder-$version-$arch.tar.xz"
    elif [[ "$source" =~ ^https?:// ]]; then
        echo "Скачивание с $source..."
        if ! wget -O "/tmp/imagebuilder-temp.tar.xz" "$source"; then
            echo -e "${RED}Ошибка скачивания${NC}"
            return 1
        fi
        source="/tmp/imagebuilder-temp.tar.xz"
    fi
    
    # Распаковка
    echo "Распаковка Image Builder..."
    if ! tar -xf "$source" -C "$ib_dir" --strip-components=1; then
        echo -e "${RED}Ошибка распаковки${NC}"
        rm -rf "$ib_dir"
        return 1
    fi
    
    # Добавление в конфигурацию
    local name="${custom_name:-OpenWrt $version}"
    local entry=$(jq -n \
        --arg ver "$version" \
        --arg tgt "$target" \
        --arg pth "$ib_dir" \
        --arg name "$name" \
        --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{version: $ver, target: $tgt, path: $pth, name: $name, added: $date, enabled: true}')
    
    jq ".imagebuilders += [$entry]" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    
    echo -e "${GREEN}Image Builder успешно добавлен!${NC}"
    update_asu_config
}

remove_imagebuilder() {
    local version=$1
    local target=$2
    local quiet=$3
    
    if [ -z "$version" ] || [ -z "$target" ]; then
        echo -e "${RED}Использование: remove_imagebuilder <версия> <target>${NC}"
        return 1
    fi
    
    if [ "$quiet" != "quiet" ]; then
        echo -n "Удалить Image Builder $version/$target? (y/n): "
        read -r response
        if [ "$response" != "y" ]; then
            return 1
        fi
    fi
    
    # Удаление из конфигурации
    jq "del(.imagebuilders[] | select(.version == \"$version\" and .target == \"$target\"))" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && \
    mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    
    # Удаление файлов
    rm -rf "$INSTALL_DIR/imagebuilders/$version/$target"
    
    [ "$quiet" != "quiet" ] && echo -e "${GREEN}Image Builder удален${NC}"
    update_asu_config
}

toggle_imagebuilder() {
    local version=$1
    local target=$2
    local action=$3
    
    if [ -z "$version" ] || [ -z "$target" ] || [ -z "$action" ]; then
        echo -e "${RED}Использование: toggle_imagebuilder <версия> <target> <enable|disable>${NC}"
        return 1
    fi
    
    local enabled=$([ "$action" = "enable" ] && echo "true" || echo "false")
    
    jq "(.imagebuilders[] | select(.version == \"$version\" and .target == \"$target\")).enabled = $enabled" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && \
    mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    
    echo -e "${GREEN}Image Builder $version/$target $([ "$action" = "enable" ] && echo "включен" || echo "выключен")${NC}"
    update_asu_config
}

update_asu_config() {
    echo -e "${YELLOW}Обновление конфигурации ASU...${NC}"
    
    # Создание динамической конфигурации для ASU
    cat > "$INSTALL_DIR/asu/custom_config.py" << 'EOF'
import json
from pathlib import Path
from asu.config import Settings as BaseSettings

# Загрузка кастомных Image Builder
config_file = Path("/opt/asu-server/imagebuilders.json")
custom_branches = {}

if config_file.exists():
    with open(config_file) as f:
        data = json.load(f)
        imagebuilders = data.get("imagebuilders", [])
        
        for ib in imagebuilders:
            if not ib.get("enabled", True):
                continue
                
            version = ib["version"]
            target = ib["target"]
            
            if version not in custom_branches:
                custom_branches[version] = {
                    "enabled": True,
                    "snapshot": version == "SNAPSHOT",
                    "targets": {}
                }
            
            custom_branches[version]["targets"][target] = {
                "imagebuilder_path": ib["path"],
                "enabled": True
            }

class LocalSettings(BaseSettings):
    @property
    def branches(self):
        base_branches = super().branches.copy()
        base_branches.update(custom_branches)
        return base_branches
    
    upstream_url: str = ""
    allow_defaults: bool = True
    max_custom_rootfs_size_mb: int = 2048
    max_defaults_length: int = 40960

settings = LocalSettings()
EOF

    # Обновление профилей устройств
    echo "Обновление профилей устройств..."
    update_device_profiles

    # Перезапуск ASU если запущен
    if systemctl is-active --quiet asu-server 2>/dev/null; then
        echo "Перезапуск ASU сервера..."
        systemctl restart asu-server
    fi
}

update_device_profiles() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return
    fi
    
    jq -r '.imagebuilders[] | select(.enabled == true) | "\(.version) \(.target) \(.path)"' "$CONFIG_FILE" | \
    while read -r version target path; do
        if [ -d "$path" ]; then
            echo "Сканирование профилей для $version/$target..."
            
            # Поиск файла .targetinfo
            targetinfo_file="$path/.targetinfo"
            if [ -f "$targetinfo_file" ]; then
                # Извлечение профилей из .targetinfo
                profiles=$(awk '/^Target-Profile:/ {print $2}' "$targetinfo_file" | sort -u)
                echo "Найдено профилей: $(echo "$profiles" | wc -l)"
            else
                echo "Файл .targetinfo не найден в $path"
            fi
            
            # Поиск в build_dir/target-*
            build_dir=$(find "$path" -name "build_dir" -type d | head -1)
            if [ -n "$build_dir" ]; then
                target_dir=$(find "$build_dir" -name "target-*" -type d | head -1)
                if [ -n "$target_dir" ]; then
                    linux_dir=$(find "$target_dir" -name "linux-*" -type d | head -1)
                    if [ -n "$linux_dir" ]; then
                        echo "Найдена директория сборки: $linux_dir"
                    fi
                fi
            fi
        fi
    done
}

populate_overview_files() {
    echo -e "${YELLOW}Заполнение файлов .overview.json данными из Image Builder...${NC}"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Нет настроенных Image Builder"
        return
    fi
    
    local store_dir="$INSTALL_DIR/public/store"
    
    jq -r '.imagebuilders[] | select(.enabled == true) | "\(.version) \(.target) \(.path)"' "$CONFIG_FILE" | \
    while read -r version target path; do
        echo "Обработка $version/$target..."
        
        if [ -d "$path" ]; then
            local overview_file="$store_dir/releases/$version/.overview.json"
            local targetinfo_file="$path/.targetinfo"
            
            if [ -f "$targetinfo_file" ]; then
                # Извлечение профилей из .targetinfo в правильном формате
                echo "  Создание .overview.json и profiles.json в формате OpenWrt..."
                
                # Создание временного файла для .overview.json профилей (массив)
                local temp_overview="/tmp/overview_profiles_$version.json"
                echo '[' > "$temp_overview"
                
                # Создание временного файла для target/profiles.json (объект)
                local temp_profiles="/tmp/target_profiles_$version.json"
                echo '{' > "$temp_profiles"
                
                # Парсинг .targetinfo для создания обоих форматов
                awk '
                BEGIN { RS=""; FS="\n"; first_overview=1; first_profiles=1 }
                /^Target-Profile:/ {
                    profile_id = ""
                    profile_name = ""
                    device_title = ""
                    device_packages = ""
                    
                    for (i=1; i<=NF; i++) {
                        if ($i ~ /^Target-Profile:/) {
                            gsub(/^Target-Profile: /, "", $i)
                            profile_id = $i
                        }
                        if ($i ~ /^Target-Profile-Name:/) {
                            gsub(/^Target-Profile-Name: /, "", $i)
                            profile_name = $i
                        }
                        if ($i ~ /^Target-Profile-Description:/) {
                            gsub(/^Target-Profile-Description: /, "", $i)
                            device_title = $i
                        }
                        if ($i ~ /^Target-Profile-Packages:/) {
                            gsub(/^Target-Profile-Packages: /, "", $i)
                            device_packages = $i
                        }
                    }
                    
                    # Если нет описания, используем имя профиля
                    if (device_title == "") {
                        device_title = profile_name
                    }
                    
                    # Разделение на vendor и model
                    vendor = "Generic"
                    model = device_title
                    if (match(device_title, /^([^[:space:]]+)[[:space:]]+(.+)/, arr)) {
                        vendor = arr[1]
                        model = arr[2]
                    }
                    
                    # Запись в формат .overview.json (массив объектов)
                    if (!first_overview) printf "," >> "/tmp/overview_profiles_'$version'.json"
                    first_overview=0
                    printf "    {\n" >> "/tmp/overview_profiles_'$version'.json"
                    printf "      \"id\": \"%s\",\n", profile_id >> "/tmp/overview_profiles_'$version'.json"
                    printf "      \"target\": \"%s\",\n", "'$target'" >> "/tmp/overview_profiles_'$version'.json"
                    printf "      \"titles\": [\n" >> "/tmp/overview_profiles_'$version'.json"
                    printf "        {\n" >> "/tmp/overview_profiles_'$version'.json"
                    printf "          \"vendor\": \"%s\",\n", vendor >> "/tmp/overview_profiles_'$version'.json"
                    printf "          \"model\": \"%s\"\n", model >> "/tmp/overview_profiles_'$version'.json"
                    printf "        }\n" >> "/tmp/overview_profiles_'$version'.json"
                    printf "      ]\n" >> "/tmp/overview_profiles_'$version'.json"
                    printf "    }" >> "/tmp/overview_profiles_'$version'.json"
                    
                    # Запись в формат target/profiles.json (объект с ключами-профилями)
                    if (!first_profiles) printf "," >> "/tmp/target_profiles_'$version'.json"
                    first_profiles=0
                    printf "  \"%s\": {\n", profile_id >> "/tmp/target_profiles_'$version'.json"
                    printf "    \"device_packages\": [" >> "/tmp/target_profiles_'$version'.json"
                    if (device_packages != "") {
                        split(device_packages, packages, " ")
                        for (j in packages) {
                            if (j > 1) printf "," >> "/tmp/target_profiles_'$version'.json"
                            printf "\"%s\"", packages[j] >> "/tmp/target_profiles_'$version'.json"
                        }
                    }
                    printf "],\n" >> "/tmp/target_profiles_'$version'.json"
                    printf "    \"image_prefix\": \"openwrt-%s-%s-%s\",\n", "'$version'", "'$(echo $target | tr / -)'" , profile_id >> "/tmp/target_profiles_'$version'.json"
                    printf "    \"images\": [],\n" >> "/tmp/target_profiles_'$version'.json"
                    printf "    \"supported_devices\": [\"%s\"],\n", profile_id >> "/tmp/target_profiles_'$version'.json"
                    printf "    \"titles\": [\n" >> "/tmp/target_profiles_'$version'.json"
                    printf "      {\n" >> "/tmp/target_profiles_'$version'.json"
                    printf "        \"vendor\": \"%s\",\n", vendor >> "/tmp/target_profiles_'$version'.json"
                    printf "        \"model\": \"%s\"\n", model >> "/tmp/target_profiles_'$version'.json"
                    printf "      }\n" >> "/tmp/target_profiles_'$version'.json"
                    printf "    ]\n" >> "/tmp/target_profiles_'$version'.json"
                    printf "  }" >> "/tmp/target_profiles_'$version'.json"
                }
                END { 
                    print "" >> "/tmp/overview_profiles_'$version'.json"
                    print "" >> "/tmp/target_profiles_'$version'.json"
                }
                ' "$targetinfo_file"
                
                echo ']' >> "$temp_overview"
                echo '}' >> "$temp_profiles"
                
                # Создание .overview.json для релиза
                cat > "$overview_file" << EOF
{
  "release": "$version",
  "profiles": $(cat "$temp_overview")
}
EOF
                
                # Создание структуры для target
                local target_dir="$store_dir/releases/$version/targets/$target"
                mkdir -p "$target_dir"
                
                # Создание profiles.json для target в правильном формате объекта
                cat > "$target_dir/profiles.json" << EOF
{
  "arch_packages": "$(echo "$target" | cut -d'/' -f1)",
  "default_packages": [],
  "metadata_version": 1,
  "profiles": $(cat "$temp_profiles")
}
EOF
                
                # Создание .targetinfo для target
                cp "$targetinfo_file" "$target_dir/.targetinfo" 2>/dev/null || touch "$target_dir/.targetinfo"
                
                # Подсчет и проверка профилей
                local profile_count=$(grep -c '"id":' "$overview_file" 2>/dev/null || echo "0")
                echo "  Добавлено профилей: $profile_count"
                echo "  Создан: $target_dir/profiles.json"
                
                # Проверка наличия routerich_ax3000-v1
                if grep -q "routerich_ax3000-v1" "$overview_file"; then
                    echo -e "  ${GREEN}✓ routerich_ax3000-v1 найден и добавлен!${NC}"
                fi
                
                # Очистка временных файлов
                rm -f "$temp_overview" "$temp_profiles"
            else
                echo "  Файл .targetinfo не найден, создаем пустую структуру"
                cat > "$overview_file" << EOF
{
  "release": "$version",
  "profiles": []
}
EOF
                
                # Создание пустой структуры для target
                local target_dir="$store_dir/releases/$version/targets/$target"
                mkdir -p "$target_dir"
                
                # Создание пустого profiles.json в правильном формате
                cat > "$target_dir/profiles.json" << EOF
{
  "arch_packages": "$(echo "$target" | cut -d'/' -f1)",
  "default_packages": [],
  "metadata_version": 1,
  "profiles": {}
}
EOF
                touch "$target_dir/.targetinfo"
                
                echo "  Создан: $target_dir/profiles.json (пустой)"
            fi
        fi
    done
    
    # Установка прав
    chmod -R 755 "$store_dir"
    chown -R www-data:www-data "$store_dir" 2>/dev/null || true
    
    echo "Заполнение .overview.json завершено"
    
    # Создание дополнительных файлов для совместимости
    create_additional_store_files "$store_dir"
}

create_additional_store_files() {
    local store_dir="$1"
    echo "Создание дополнительных файлов для store..."
    
    # Создание index.json для корня store
    cat > "$store_dir/index.json" << 'EOF'
{
  "versions": ["SNAPSHOT", "24.10.1", "24.10", "23.05", "22.03"],
  "default_version": "24.10.1"
}
EOF

    # Создание versions.json
    cat > "$store_dir/versions.json" << 'EOF'
[
  {
    "name": "SNAPSHOT",
    "enabled": true,
    "snapshot": true
  },
  {
    "name": "24.10.1",
    "enabled": true,
    "snapshot": false
  },
  {
    "name": "24.10",
    "enabled": true,
    "snapshot": false
  },
  {
    "name": "23.05",
    "enabled": true,
    "snapshot": false
  },
  {
    "name": "22.03",
    "enabled": true,
    "snapshot": false
  }
]
EOF

    echo "Дополнительные файлы созданы"
}

show_device_profiles() {
    echo -e "${BLUE}=== Профили устройств ===${NC}"
    echo ""
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Нет настроенных Image Builder"
        return
    fi
    
    jq -r '.imagebuilders[] | select(.enabled == true) | "\(.version) \(.target) \(.path)"' "$CONFIG_FILE" | \
    while read -r version target path; do
        echo -e "${YELLOW}=== $version/$target ===${NC}"
        
        if [ -d "$path" ]; then
            # Поиск файла .targetinfo
            targetinfo_file="$path/.targetinfo"
            if [ -f "$targetinfo_file" ]; then
                echo "Доступные профили устройств:"
                awk '/^Target-Profile:/ {print "  - " $2}' "$targetinfo_file" | head -20
                
                total_profiles=$(awk '/^Target-Profile:/ {print $2}' "$targetinfo_file" | wc -l)
                echo "  Всего профилей: $total_profiles"
                
                # Поиск конкретного профиля routerich_ax3000-v1
                if grep -q "routerich_ax3000-v1" "$targetinfo_file"; then
                    echo -e "  ${GREEN}✓ routerich_ax3000-v1 найден!${NC}"
                else
                    echo -e "  ${RED}✗ routerich_ax3000-v1 не найден${NC}"
                fi
            else
                echo "  Файл .targetinfo не найден"
                
                # Попытка найти профили в других местах
                if [ -f "$path/tmp/.targetinfo" ]; then
                    echo "  Найден tmp/.targetinfo, проверяем..."
                    awk '/^Target-Profile:/ {print "  - " $2}' "$path/tmp/.targetinfo" | head -10
                fi
            fi
        else
            echo "  Директория не найдена: $path"
        fi
        echo ""
    done
}

# ===============================================================================
# ФУНКЦИИ УСТАНОВКИ
# ===============================================================================

install_dependencies() {
    echo -e "${YELLOW}Установка зависимостей...${NC}"
    apt update && apt upgrade -y
    apt install -y \
        curl \
        git \
        python3 \
        python3-pip \
        python3-poetry \
        podman \
        podman-compose \
        redis-server \
        nginx \
        jq \
        tar \
        xz-utils \
        wget \
        ufw \
        htop \
        nano \
        lsof \
        net-tools
}

setup_podman() {
    echo -e "${YELLOW}Настройка Podman...${NC}" >&2
    local user="${SUDO_USER:-root}"
    if [ "$user" = "root" ]; then
        user="asu"
        if ! id "$user" &>/dev/null; then
            useradd -m -s /bin/bash "$user"
            echo "Создан пользователь: $user" >&2
        fi
    fi
    
    # Попытка включить linger для пользователя
    if command -v loginctl >/dev/null 2>&1; then
        loginctl enable-linger "$user" 2>/dev/null || {
            echo "Предупреждение: не удалось включить linger для $user" >&2
            echo "Это нормально в контейнерной среде" >&2
        }
    fi
    
    echo "$user"
}

create_directory_structure() {
    echo -e "${YELLOW}Создание структуры директорий...${NC}"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Клонирование репозиториев
    if [ ! -d "asu" ]; then
        git clone https://github.com/openwrt/asu.git
    fi
    
    if [ ! -d "firmware-selector-openwrt-org" ]; then
        git clone https://github.com/openwrt/firmware-selector-openwrt-org.git
    fi
    
    # Создание структуры
    mkdir -p public/store imagebuilders custom_feeds redis-data
    
    # Настройка прав
    local user="${1:-root}"
    chown -R "$user:$user" "$INSTALL_DIR"
    chmod -R 755 public
}

configure_asu() {
    echo -e "${YELLOW}Настройка ASU сервера...${NC}"
    local user="$1"
    
    cat > "$INSTALL_DIR/asu/.env" << EOF
PUBLIC_PATH=$INSTALL_DIR/public
CONTAINER_SOCKET_PATH=/run/user/$(id -u "$user")/podman/podman.sock
ALLOW_DEFAULTS=1
SERVER_STATS=1
REDIS_URL=redis://redis:6379/0
ASU_TITLE="$SERVER_NAME"
EOF

    # Создание базовой конфигурации
    cat > "$INSTALL_DIR/asu/custom_config.py" << 'EOF'
from asu.config import Settings as BaseSettings

class LocalSettings(BaseSettings):
    upstream_url: str = ""
    allow_defaults: bool = True
    max_custom_rootfs_size_mb: int = 2048
    max_defaults_length: int = 40960

settings = LocalSettings()
EOF
}

configure_firmware_selector() {
    echo -e "${YELLOW}Настройка firmware-selector...${NC}"
    
    cat > "$INSTALL_DIR/firmware-selector-openwrt-org/www/config.js" << EOF
var config = {
  asu_url: window.location.origin + '/api',
  image_url: window.location.origin + '/store',
  versions: ['SNAPSHOT', '24.10.1', '24.10', '23.05'],
  default_version: '24.10.1',
  asu_enabled: true,
  show_custom_images: true,
  allow_custom_packages: true,
  show_advanced_options: true,
  server_name: '$SERVER_NAME'
};
EOF
}

configure_nginx() {
    echo -e "${YELLOW}Настройка веб-сервера...${NC}"
    
    cat > /etc/nginx/sites-available/asu << EOF
server {
    listen 80;
    server_name _;

    # Firmware Selector
    location / {
        root $INSTALL_DIR/firmware-selector-openwrt-org/www;
        index index.html;
        try_files \$uri \$uri/ =404;
    }

    # ASU API
    location /api/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_read_timeout 1200s;
        proxy_connect_timeout 600s;
        proxy_send_timeout 600s;
        client_max_body_size 50M;
    }

    # Store
    location /store/ {
        alias $INSTALL_DIR/public/store/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
        
        # Правильные MIME типы для JSON
        location ~* \.json$ {
            add_header Content-Type application/json;
            add_header Cache-Control "no-cache, no-store, must-revalidate";
        }
        
        # Разрешить доступ к скрытым файлам (.overview.json, .targetinfo)
        location ~ /\. {
            allow all;
        }
    }
}
EOF

    # Активация конфигурации
    ln -sf /etc/nginx/sites-available/asu /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t && systemctl restart nginx
}

create_systemd_service() {
    echo -e "${YELLOW}Создание systemd сервиса...${NC}"
    local user="$1"
    
    cat > /etc/systemd/system/asu-server.service << EOF
[Unit]
Description=OpenWrt ASU Server
After=network.target nginx.service
Wants=nginx.service

[Service]
Type=simple
User=$user
Group=$user
WorkingDirectory=$INSTALL_DIR/asu
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
Environment="XDG_RUNTIME_DIR=/run/user/$(id -u "$user")"
ExecStartPre=/bin/bash -c 'systemctl stop redis-server 2>/dev/null || systemctl stop redis 2>/dev/null || true'
ExecStartPre=/bin/bash -c 'pkill -f redis-server 2>/dev/null || true'
ExecStartPre=/bin/bash -c 'systemctl --user start podman.socket 2>/dev/null || true'
ExecStart=/usr/bin/podman-compose up
ExecStop=/usr/bin/podman-compose down
Restart=on-failure
RestartSec=15
TimeoutStartSec=300
KillMode=mixed
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF
}

build_and_start_services() {
    echo -e "${YELLOW}Сборка и запуск сервисов...${NC}"
    local user="$1"
    
    # Настройка среды для пользователя
    export XDG_RUNTIME_DIR="/run/user/$(id -u "$user")"
    mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
    chown "$user:$user" "$XDG_RUNTIME_DIR" 2>/dev/null || true
    chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
    
    # Запуск Podman socket (с проверкой доступности)
    if command -v systemctl >/dev/null 2>&1; then
        su - "$user" -c "export XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR'; systemctl --user enable podman.socket 2>/dev/null || echo 'Предупреждение: не удалось включить podman.socket'"
        su - "$user" -c "export XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR'; systemctl --user start podman.socket 2>/dev/null || echo 'Предупреждение: не удалось запустить podman.socket'"
    else
        echo "Systemd недоступен, пропускаем настройку podman socket"
    fi
    
    # Остановка системного Redis, если он запущен
    echo "Проверка системного Redis..."
    if systemctl is-active --quiet redis-server 2>/dev/null || systemctl is-active --quiet redis 2>/dev/null; then
        echo "Остановка системного Redis для освобождения порта 6379..."
        systemctl stop redis-server 2>/dev/null || systemctl stop redis 2>/dev/null || true
        systemctl disable redis-server 2>/dev/null || systemctl disable redis 2>/dev/null || true
    fi
    
    # Проверка, что порт 6379 свободен
    echo "Проверка доступности порта 6379..."
    if ss -tuln 2>/dev/null | grep -q ':6379' || (command -v lsof >/dev/null && lsof -i :6379 >/dev/null 2>&1); then
        echo -e "${YELLOW}Предупреждение: Порт 6379 занят. Попытка освободить...${NC}"
        # Убиваем все процессы redis
        pkill -f redis-server 2>/dev/null || true
        pkill -f redis 2>/dev/null || true
        # Ждем освобождения порта
        for i in {1..10}; do
            if ! ss -tuln 2>/dev/null | grep -q ':6379'; then
                echo "Порт 6379 освобожден"
                break
            fi
            echo "Ожидание освобождения порта... ($i/10)"
            sleep 1
        done
    else
        echo "Порт 6379 свободен"
    fi
    
    # Остановка и очистка старых контейнеров
    echo "Очистка старых контейнеров..."
    cd "$INSTALL_DIR/asu"
    su - "$user" -c "cd $INSTALL_DIR/asu && podman-compose down --remove-orphans" 2>/dev/null || true
    su - "$user" -c "podman system prune -f" 2>/dev/null || true
    
    # Сборка контейнеров
    echo "Сборка контейнеров..."
    su - "$user" -c "cd $INSTALL_DIR/asu && podman-compose build"
    
    # Запуск сервисов
    systemctl enable nginx
    
    systemctl daemon-reload
    systemctl enable asu-server
    echo "Запуск ASU сервера..."
    systemctl start asu-server
}

create_store_structure() {
    echo -e "${YELLOW}Создание структуры store...${NC}"
    local store_dir="$INSTALL_DIR/public/store"
    
    # Создание директорий для релизов
    mkdir -p "$store_dir/releases/24.10.1"
    mkdir -p "$store_dir/releases/24.10"
    mkdir -p "$store_dir/releases/23.05"
    mkdir -p "$store_dir/releases/22.03"
    mkdir -p "$store_dir/releases/SNAPSHOT"
    
    # Создание .overview.json файлов
    cat > "$store_dir/releases/24.10.1/.overview.json" << 'EOF'
{
  "release": "24.10.1",
  "profiles": []
}
EOF

    cat > "$store_dir/releases/24.10/.overview.json" << 'EOF'
{
  "release": "24.10",
  "profiles": []
}
EOF

    cat > "$store_dir/releases/23.05/.overview.json" << 'EOF'
{
  "release": "23.05",
  "profiles": []
}
EOF

    cat > "$store_dir/releases/22.03/.overview.json" << 'EOF'
{
  "release": "22.03",
  "profiles": []
}
EOF

    cat > "$store_dir/releases/SNAPSHOT/.overview.json" << 'EOF'
{
  "release": "SNAPSHOT",
  "profiles": []
}
EOF

    # Создание корневого overview.json
    cat > "$store_dir/.overview.json" << 'EOF'
{
  "versions": ["SNAPSHOT", "24.10.1", "24.10", "23.05", "22.03"],
  "default_version": "24.10.1"
}
EOF
    
    # Установка правильных прав
    chmod -R 755 "$store_dir"
    chown -R www-data:www-data "$store_dir" 2>/dev/null || true
    
    echo "Структура store создана"
    echo "Файлы .overview.json:"
    find "$store_dir" -name ".overview.json" -type f | while read file; do
        echo "  - $file"
    done
}

create_management_tools() {
    echo -e "${YELLOW}Создание утилит управления...${NC}"
    
    # Скрипт статуса
    cat > "$INSTALL_DIR/status.sh" << 'EOF'
#!/bin/bash

echo "=== Статус ASU сервера ==="
echo ""

# Проверка сервисов
echo "Nginx:" $(systemctl is-active nginx)
echo "Redis:" $(systemctl is-active redis)
echo "ASU:" $(systemctl is-active asu-server)

echo ""
echo "Проверка доступности:"

if curl -s http://localhost/ > /dev/null; then
    echo "✓ Firmware Selector доступен"
else
    echo "✗ Firmware Selector недоступен"
fi

if curl -s http://localhost:8000/api/overview > /dev/null; then
    echo "✓ ASU API доступен"
else
    echo "✗ ASU API недоступен"
fi

echo ""
echo "Image Builder:"
if [ -f "/opt/asu-server/imagebuilders.json" ]; then
    jq -r '.imagebuilders[] | "- \(.version)/\(.target): \(if .enabled then "включен" else "выключен" end)"' /opt/asu-server/imagebuilders.json
else
    echo "Нет установленных Image Builder"
fi

echo ""
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "Доступ к сервису:"
echo "- Веб-интерфейс: http://$SERVER_IP/"
echo "- API: http://$SERVER_IP/api/"
echo "- Документация API: http://$SERVER_IP/api/docs"
EOF

    chmod +x "$INSTALL_DIR/status.sh"
    
    # Скрипт для обновления store
    cat > "$INSTALL_DIR/update-store.sh" << 'EOF'
#!/bin/bash

STORE_DIR="/opt/asu-server/public/store"

echo "Обновление структуры store..."

# Создание директорий для релизов
for version in "24.10.1" "24.10" "23.05" "SNAPSHOT"; do
    mkdir -p "$STORE_DIR/releases/$version"
    
    # Создание .overview.json если его нет
    if [ ! -f "$STORE_DIR/releases/$version/.overview.json" ]; then
        echo "Создание .overview.json для $version"
        cat > "$STORE_DIR/releases/$version/.overview.json" << JSON
{
  "version": "$version",
  "branch": "${version%.*}",
  "release_date": "$(date -u +%Y-%m-%d)",
  "targets": {},
  "profiles": {}
}
JSON
    fi
done

# Установка прав
chmod -R 755 "$STORE_DIR"

echo "Структура store обновлена"
EOF
    
    chmod +x "$INSTALL_DIR/update-store.sh"
    
    # Скрипт для отладки конфигурации
    cat > "$INSTALL_DIR/debug-config.sh" << 'EOF'
#!/bin/bash

echo "=== Содержимое imagebuilders.json ==="
if [ -f "/opt/asu-server/imagebuilders.json" ]; then
    cat /opt/asu-server/imagebuilders.json | jq .
else
    echo "Файл не найден"
fi

echo ""
echo "=== Проверка custom_config.py ==="
if [ -f "/opt/asu-server/asu/custom_config.py" ]; then
    echo "Файл существует"
    grep -n "enabled" /opt/asu-server/asu/custom_config.py || echo "Нет упоминаний enabled"
else
    echo "Файл не найден"
fi
EOF
    
    chmod +x "$INSTALL_DIR/debug-config.sh"
    
    # Инструкция для клиентов
    cat > "$INSTALL_DIR/CLIENT_SETUP.md" << EOF
# Настройка клиентов OpenWrt для Attended Sysupgrade

## Вариант 1: LuCI (веб-интерфейс)

1. Установите пакет:
\`\`\`
opkg update
opkg install luci-app-attendedsysupgrade
\`\`\`

2. В веб-интерфейсе роутера:
   - Перейдите в System → Attended Sysupgrade
   - Server URL: \`http://$(hostname -I | awk '{print $1}')/api/\`
   - Нажмите "Request Firmware"

## Вариант 2: CLI с owut

\`\`\`bash
owut --server http://$(hostname -I | awk '{print $1}')/api/ upgrade
\`\`\`

## Вариант 3: CLI с auc (старые версии)

\`\`\`bash
opkg install auc
auc -s http://$(hostname -I | awk '{print $1}')/api/
\`\`\`
EOF
}

# ===============================================================================
# ГЛАВНОЕ МЕНЮ
# ===============================================================================

show_main_menu() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              ASU Server Manager               ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "1) Проверить системные требования"
    echo "2) Установить ASU сервер"
    echo "3) Управление Image Builder"
    echo "4) Показать статус сервера"
    echo "5) Быстрое добавление OpenWrt 24.10.1"
    echo "6) Настройка Attended Sysupgrade"
    echo "7) Создать клиентскую документацию"
    echo "8) Управление сервисами"
    echo "9) Создать/обновить структуру store"
    echo "a) Заполнить overview.json профилями устройств"
    echo "0) Выход"
    echo ""
    echo -n "Выберите действие: "
}

show_imagebuilder_menu() {
    echo -e "${BLUE}=== Управление Image Builder ===${NC}"
    echo "1) Показать установленные"
    echo "2) Добавить Image Builder"
    echo "3) Удалить Image Builder"
    echo "4) Включить Image Builder"
    echo "5) Выключить Image Builder"
    echo "6) Импорт официальных релизов"
    echo "7) Обновить конфигурацию ASU"
    echo "8) Показать профили устройств"
    echo "9) Заполнить .overview.json из Image Builder"
    echo "0) Назад"
    echo ""
    echo -n "Выберите действие: "
}

show_services_menu() {
    echo -e "${BLUE}=== Управление сервисами ===${NC}"
    echo "1) Перезапустить ASU сервер"
    echo "2) Перезапустить все сервисы"
    echo "3) Остановить сервисы"
    echo "4) Запустить сервисы"
    echo "5) Показать логи ASU"
    echo "6) Показать логи Nginx"
    echo "7) Очистить Redis и перезапустить"
    echo "8) Полная очистка контейнеров"
    echo "0) Назад"
    echo ""
    echo -n "Выберите действие: "
}

import_official_releases() {
    echo -e "${BLUE}=== Импорт официальных релизов OpenWrt ===${NC}"
    
    local versions=("24.10.1" "24.10" "23.05" "22.03" "SNAPSHOT")
    local targets=("x86/64" "x86/generic" "ath79/generic" "ramips/mt7621" "mediatek/filogic" "ipq40xx/generic")
    
    echo "Доступные версии: ${versions[*]}"
    echo "Популярные targets: ${targets[*]}"
    echo ""
    echo "Выберите версии (через пробел, или 'all' для всех):"
    read -r selected_versions
    
    echo "Выберите targets (через пробел, или 'all' для всех):"
    read -r selected_targets
    
    if [ "$selected_versions" = "all" ]; then
        selected_versions="${versions[*]}"
    fi
    
    if [ "$selected_targets" = "all" ]; then
        selected_targets="${targets[*]}"
    fi
    
    for version in $selected_versions; do
        for target in $selected_targets; do
            echo ""
            echo "Добавление $version/$target..."
            add_imagebuilder "$version" "$target" "official" "OpenWrt $version"
        done
    done
}

add_mediatek_24_10_1() {
    echo -e "${GREEN}=== Добавление OpenWrt 24.10.1 MediaTek Filogic ===${NC}"
    echo ""
    echo "Будет добавлена архитектура: mediatek/filogic"
    echo "Поддерживаемые устройства: Xiaomi AX3000T/AX6000, TP-Link AX53/AX73, ASUS RT-AX53U и др."
    echo ""
    echo "Продолжить? (y/n): "
    read -r response
    
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        add_imagebuilder "24.10.1" "mediatek/filogic" "official" "OpenWrt 24.10.1 MediaTek Filogic"
        echo -e "${GREEN}✓ OpenWrt 24.10.1 MediaTek Filogic добавлен!${NC}"
    fi
}

configure_attended_sysupgrade() {
    echo -e "${BLUE}=== Настройка Attended Sysupgrade ===${NC}"
    
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo "Конфигурация для клиентов OpenWrt сохранена в $INSTALL_DIR/CLIENT_SETUP.md"
    echo ""
    echo "Быстрая настройка:"
    echo ""
    echo "1. На устройстве OpenWrt установите пакет:"
    echo "   opkg update && opkg install luci-app-attendedsysupgrade"
    echo ""
    echo "2. В веб-интерфейсе роутера:"
    echo "   System → Attended Sysupgrade"
    echo "   Server URL: http://$SERVER_IP/api/"
    echo ""
    echo "3. Или используйте CLI:"
    echo "   owut --server http://$SERVER_IP/api/ upgrade"
    echo ""
}

install_full_system() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              Установка ASU сервера             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Проверка root прав
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Запустите скрипт от root или через sudo${NC}"
        return 1
    fi
    
    echo "Введите название вашего сервера (по умолчанию: Local ASU Server):"
    read -r input_name
    if [ -n "$input_name" ]; then
        SERVER_NAME="$input_name"
    fi
    
    echo ""
    echo "Начать установку с настройками:"
    echo "- Название: $SERVER_NAME"
    echo "- Директория: $INSTALL_DIR"
    echo ""
    echo "Продолжить? (y/n): "
    read -r confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Установка отменена"
        return 1
    fi
    
    echo ""
    echo -e "${GREEN}=== Начало установки ===${NC}"
    
    # Этапы установки
    install_dependencies
    local user=$(setup_podman)
    create_directory_structure "$user"
    configure_asu "$user"
    configure_firmware_selector
    configure_nginx
    create_systemd_service "$user"
    build_and_start_services "$user"
    create_store_structure
    create_management_tools
    init_imagebuilder_config
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║             УСТАНОВКА ЗАВЕРШЕНА!              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo -e "🌐 Веб-интерфейс: ${GREEN}http://$SERVER_IP/${NC}"
    echo -e "🔧 API endpoint: ${GREEN}http://$SERVER_IP/api/${NC}"
    echo -e "📖 API документация: ${GREEN}http://$SERVER_IP/api/docs${NC}"
    echo ""
    echo "Для добавления Image Builder используйте пункт меню 3"
}

# ===============================================================================
# ОСНОВНАЯ ЛОГИКА
# ===============================================================================

# Инициализация
init_imagebuilder_config

# Обработка аргументов командной строки
case "$1" in
    check)
        check_system_requirements
        ;;
    install)
        install_full_system
        ;;
    list)
        list_imagebuilders
        ;;
    add)
        shift
        add_imagebuilder "$@"
        ;;
    remove)
        shift
        remove_imagebuilder "$@"
        ;;
    enable)
        shift
        toggle_imagebuilder "$1" "$2" "enable"
        ;;
    disable)
        shift
        toggle_imagebuilder "$1" "$2" "disable"
        ;;
    status)
        if [ -f "$INSTALL_DIR/status.sh" ]; then
            bash "$INSTALL_DIR/status.sh"
        else
            echo "ASU сервер не установлен. Используйте: $0 install"
        fi
        ;;
    update)
        update_asu_config
        ;;
    *)
        # Интерактивный режим
        while true; do
            clear
            show_main_menu
            read -r choice
            
            case $choice in
                1) 
                    clear
                    check_system_requirements
                    echo ""
                    echo "Нажмите Enter для продолжения..."
                    read -r
                    ;;
                2) 
                    clear
                    install_full_system
                    echo ""
                    echo "Нажмите Enter для продолжения..."
                    read -r
                    ;;
                3)
                    while true; do
                        clear
                        show_imagebuilder_menu
                        read -r ib_choice
                        
                        case $ib_choice in
                            1) 
                                clear
                                list_imagebuilders
                                ;;
                            2) 
                                echo "Введите версию (например, 24.10.1):"
                                read -r version
                                echo "Введите target (например, mediatek/filogic):"
                                read -r target
                                echo "Введите источник (путь/URL/official):"
                                read -r source
                                echo "Введите название (опционально):"
                                read -r name
                                add_imagebuilder "$version" "$target" "$source" "$name"
                                ;;
                            3)
                                echo "Введите версию:"
                                read -r version
                                echo "Введите target:"
                                read -r target
                                remove_imagebuilder "$version" "$target"
                                ;;
                            4)
                                echo "Введите версию:"
                                read -r version
                                echo "Введите target:"
                                read -r target
                                toggle_imagebuilder "$version" "$target" "enable"
                                ;;
                            5)
                                echo "Введите версию:"
                                read -r version
                                echo "Введите target:"
                                read -r target
                                toggle_imagebuilder "$version" "$target" "disable"
                                ;;
                            6) 
                                import_official_releases
                                ;;
                            7) 
                                update_asu_config
                                ;;
                            8)
                                clear
                                show_device_profiles
                                ;;
                            9)
                                clear
                                populate_overview_files
                                ;;
                            0) 
                                break
                                ;;
                            *) 
                                echo -e "${RED}Неверный выбор${NC}"
                                ;;
                        esac
                        
                        if [ $ib_choice != 0 ]; then
                            echo ""
                            echo "Нажмите Enter для продолжения..."
                            read -r
                        fi
                    done
                    ;;
                4) 
                    clear
                    if [ -f "$INSTALL_DIR/status.sh" ]; then
                        bash "$INSTALL_DIR/status.sh"
                    else
                        echo "ASU сервер не установлен. Используйте пункт 2 для установки."
                    fi
                    echo ""
                    echo "Нажмите Enter для продолжения..."
                    read -r
                    ;;
                5) 
                    clear
                    add_mediatek_24_10_1
                    echo ""
                    echo "Нажмите Enter для продолжения..."
                    read -r
                    ;;
                6) 
                    clear
                    configure_attended_sysupgrade
                    echo ""
                    echo "Нажмите Enter для продолжения..."
                    read -r
                    ;;
                7) 
                    clear
                    echo "Документация для клиентов создана в: $INSTALL_DIR/CLIENT_SETUP.md"
                    if [ -f "$INSTALL_DIR/CLIENT_SETUP.md" ]; then
                        cat "$INSTALL_DIR/CLIENT_SETUP.md"
                    fi
                    echo ""
                    echo "Нажмите Enter для продолжения..."
                    read -r
                    ;;
                8)
                    while true; do
                        clear
                        show_services_menu
                        read -r svc_choice
                        
                        case $svc_choice in
                            1) 
                                # Остановка системного Redis перед перезапуском
                                systemctl stop redis-server 2>/dev/null || systemctl stop redis 2>/dev/null || true
                                systemctl restart asu-server 
                                ;;
                            2) 
                                systemctl stop redis-server 2>/dev/null || systemctl stop redis 2>/dev/null || true
                                systemctl restart asu-server nginx
                                ;;
                            3) systemctl stop asu-server ;;
                            4) 
                                # Остановка системного Redis перед запуском
                                systemctl stop redis-server 2>/dev/null || systemctl stop redis 2>/dev/null || true
                                systemctl start asu-server 
                                ;;
                            5) journalctl -u asu-server -f ;;
                            6) journalctl -u nginx -f ;;
                            7) 
                                echo "Очистка Redis и перезапуск..."
                                systemctl stop asu-server
                                systemctl stop redis-server 2>/dev/null || systemctl stop redis 2>/dev/null || true
                                pkill -f redis-server 2>/dev/null || true
                                pkill -f redis 2>/dev/null || true
                                sleep 2
                                systemctl start asu-server
                                ;;
                            8)
                                echo "Полная очистка контейнеров..."
                                systemctl stop asu-server
                                local user="${SUDO_USER:-asu}"
                                cd "$INSTALL_DIR/asu"
                                su - "$user" -c "cd $INSTALL_DIR/asu && podman-compose down --remove-orphans" 2>/dev/null || true
                                su - "$user" -c "podman system prune -af" 2>/dev/null || true
                                systemctl stop redis-server 2>/dev/null || systemctl stop redis 2>/dev/null || true
                                pkill -f redis 2>/dev/null || true
                                sleep 2
                                systemctl start asu-server
                                ;;
                            0) break ;;
                            *) echo -e "${RED}Неверный выбор${NC}" ;;
                        esac
                        
                        if [ $svc_choice != 0 ] && [ $svc_choice != 5 ] && [ $svc_choice != 6 ]; then
                            echo ""
                            echo "Нажмите Enter для продолжения..."
                            read -r
                        fi
                    done
                    ;;
                9)
                    clear
                    create_store_structure
                    echo ""
                    echo "Перезапуск nginx для применения изменений..."
                    nginx -t && systemctl reload nginx
                    echo ""
                    echo "Нажмите Enter для продолжения..."
                    read -r
                    ;;
                a|A)
                    clear
                    populate_overview_files
                    echo ""
                    echo "Нажмите Enter для продолжения..."
                    read -r
                    ;;
                0) 
                    echo "До свидания!"
                    exit 0
                    ;;
                *) 
                    echo -e "${RED}Неверный выбор${NC}"
                    sleep 1
                    ;;
            esac
        done
        ;;
esac