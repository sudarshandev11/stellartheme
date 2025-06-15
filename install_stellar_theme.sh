#!/bin/bash

set -e

PANEL_DIR="/var/www/pterodactyl"
BACKUP_DIR="/var/backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H:%M:%S")
THEME_REPO="https://github.com/sudarshandev11/stellartheme"
TMP_DIR="/tmp/stellar_theme"

echo "🔁 Backing up current panel..."
mkdir -p "$BACKUP_DIR"
read -sp "Enter password: " MYSQL_PWD
mysqldump -u root -p"$MYSQL_PWD" --all-databases > "$BACKUP_DIR/panel_backup_${TIMESTAMP}.sql" 2>/dev/null || echo "⚠️ Warning: Database backup failed (check if DB name is correct)."
tar -czf "$BACKUP_DIR/panel_backup_${TIMESTAMP}.tar.gz" "$PANEL_DIR"
echo -e "\n✅ Backup complete: $BACKUP_DIR/panel_backup_${TIMESTAMP}"

echo "📥 Cloning Stellar Theme from GitHub..."
rm -rf "$TMP_DIR"
git clone "$THEME_REPO" "$TMP_DIR"

echo "📁 Copying modified theme files..."
cp -r "$TMP_DIR/"* "$PANEL_DIR"

echo "🔧 Installing Node.js 20 and Yarn (if not already installed)..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs yarn

cd "$PANEL_DIR"

echo "📦 Installing panel frontend dependencies and building assets..."
yarn install
yarn build

echo "🧹 Clearing compiled views..."
php artisan view:clear

echo "🔐 Fixing permissions..."
chown -R www-data:www-data "$PANEL_DIR"

echo "✅ Stellar Theme installation complete!"
echo "🛡️ Backup location: $BACKUP_DIR/panel_backup_${TIMESTAMP}"
echo "🎨 Activate it from Admin Panel > Settings > Theme"
