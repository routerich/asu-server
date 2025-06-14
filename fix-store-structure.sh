#!/bin/bash

# Скрипт для создания структуры store и файлов .overview.json

STORE_DIR="/opt/asu-server/public/store"

echo "Создание структуры store..."

# Создание директорий
mkdir -p "$STORE_DIR/releases/24.10.1"
mkdir -p "$STORE_DIR/releases/24.10"
mkdir -p "$STORE_DIR/releases/23.05"
mkdir -p "$STORE_DIR/releases/22.03"
mkdir -p "$STORE_DIR/releases/SNAPSHOT"

# Создание .overview.json файлов
cat > "$STORE_DIR/releases/24.10.1/.overview.json" << 'EOF'
{
  "version": "24.10.1",
  "branch": "24.10",
  "release_date": "2024-10-01",
  "targets": {},
  "profiles": {}
}
EOF

cat > "$STORE_DIR/releases/24.10/.overview.json" << 'EOF'
{
  "version": "24.10",
  "branch": "24.10",
  "release_date": "2024-10-01",
  "targets": {},
  "profiles": {}
}
EOF

cat > "$STORE_DIR/releases/23.05/.overview.json" << 'EOF'
{
  "version": "23.05",
  "branch": "23.05",
  "release_date": "2023-05-01",
  "targets": {},
  "profiles": {}
}
EOF

cat > "$STORE_DIR/releases/22.03/.overview.json" << 'EOF'
{
  "version": "22.03",
  "branch": "22.03",
  "release_date": "2022-03-01",
  "targets": {},
  "profiles": {}
}
EOF

cat > "$STORE_DIR/releases/SNAPSHOT/.overview.json" << 'EOF'
{
  "version": "SNAPSHOT",
  "branch": "master",
  "release_date": "ongoing",
  "targets": {},
  "profiles": {}
}
EOF

# Создание корневого overview.json
cat > "$STORE_DIR/.overview.json" << 'EOF'
{
  "versions": ["SNAPSHOT", "24.10.1", "24.10", "23.05", "22.03"],
  "default_version": "24.10.1"
}
EOF

# Установка прав
chmod -R 755 "$STORE_DIR"
chown -R www-data:www-data "$STORE_DIR" 2>/dev/null || true

echo "Структура store создана успешно!"
echo ""
echo "Проверка созданных файлов:"
find "$STORE_DIR" -name ".overview.json" -type f | while read file; do
    echo "- $file"
done