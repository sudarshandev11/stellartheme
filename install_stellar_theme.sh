#!/bin/bash

# ------------------- CONFIG -------------------
PANEL_DIR="/var/www/pterodactyl"
BACKUP_DIR="/var/backups/panel_backup_$(date +%F_%T)"
TEMP_DIR="/tmp/stellar_theme"
DB_NAME="pterodactyl"
DB_USER="root"
# ----------------------------------------------

echo "🔁 Backing up current panel..."
mkdir -p "$BACKUP_DIR"
cp -r "$PANEL_DIR" "$BACKUP_DIR/panel_files"
cp "$PANEL_DIR/.env" "$BACKUP_DIR/.env.backup"
mysqldump -u "$DB_USER" -p "$DB_NAME" > "$BACKUP_DIR/pterodactyl.sql"
echo "✅ Backup complete: $BACKUP_DIR"

echo "📥 Cloning Stellar Theme from GitHub..."
rm -rf "$TEMP_DIR"
git clone https://github.com/sudarshandev11/stellartheme.git "$TEMP_DIR"

echo "📁 Copying modified theme files..."
cp -r "$TEMP_DIR/pterodactyl/"* "$PANEL_DIR"

echo "🔧 Installing Node.js 16 and Yarn (if not already installed)..."
curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt-get install -y nodejs
npm install -g yarn

echo "📦 Installing panel frontend dependencies and building assets..."
cd "$PANEL_DIR"
yarn add react-feather
php artisan migrate --force
yarn install
yarn build:production
php artisan view:clear

echo "🔐 Fixing permissions..."
chown -R www-data:www-data "$PANEL_DIR"
chmod -R 755 "$PANEL_DIR"

echo "✅ Stellar Theme installation complete!"
echo "🛡️ Backup location: $BACKUP_DIR"
echo "🎨 Activate it from Admin Panel > Settings > Theme"
