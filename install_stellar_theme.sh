#!/bin/bash

# ------------------- CONFIG -------------------
PANEL_DIR="/var/www/pterodactyl"
BACKUP_DIR="/var/backups/panel_backup_$(date +%F_%T)"
TEMP_DIR="/tmp/stellar_theme"
DB_NAME="pterodactyl"
DB_USER="root"
# ----------------------------------------------

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔁 Backing up current panel and database...${NC}"
mkdir -p "$BACKUP_DIR"
cp -r "$PANEL_DIR" "$BACKUP_DIR/panel_files"
cp "$PANEL_DIR/.env" "$BACKUP_DIR/.env.backup"
mysqldump -u "$DB_USER" -p "$DB_NAME" > "$BACKUP_DIR/pterodactyl.sql"
echo -e "${GREEN}✅ Backup complete: $BACKUP_DIR${NC}"

echo -e "${YELLOW}📥 Cloning Stellar Theme from GitHub...${NC}"
rm -rf "$TEMP_DIR"
git clone https://github.com/sudarshandev11/stellartheme.git "$TEMP_DIR" || { echo -e "${RED}❌ Failed to clone theme repo.${NC}"; exit 1; }

echo -e "${YELLOW}📁 Copying theme files to panel...${NC}"
cp -r "$TEMP_DIR/pterodactyl/"* "$PANEL_DIR"

echo -e "${YELLOW}🔧 Ensuring Node.js 16 and Yarn are installed...${NC}"

if ! node -v | grep -q "v16"; then
    curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo -e "${GREEN}✔ Node.js 16 is already installed.${NC}"
fi

if ! command -v yarn &> /dev/null; then
    npm install -g yarn
else
    echo -e "${GREEN}✔ Yarn is already installed.${NC}"
fi

echo -e "${YELLOW}📦 Installing frontend dependencies and building panel assets...${NC}"
cd "$PANEL_DIR"
yarn add react-feather
php artisan migrate --force
yarn install
yarn build:production
php artisan view:clear

echo -e "${YELLOW}🔐 Fixing permissions...${NC}"
chown -R www-data:www-data "$PANEL_DIR"
chmod -R 755 "$PANEL_DIR"

echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✅ Stellar Theme installation complete!${NC}"
echo -e "${YELLOW}🛡️ Backup saved at: ${BACKUP_DIR}${NC}"
echo -e "${YELLOW}🎨 Activate the theme from: Admin Panel > Settings > Theme${NC}"
