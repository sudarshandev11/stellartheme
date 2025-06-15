#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error_exit() { echo -e "${RED}[ERROR]${NC} $1" 1>&2; exit 1; }

# Timestamp for backups
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/var/backups"
WEB_DIR="/var/www/pterodactyl"
DB_NAME="panel"
MYSQL_USER="root"
# (Adjust MYSQL_USER / credentials as needed.)

info "Creating backups (web files and database)..."
mkdir -p "$BACKUP_DIR"

# Backup web directory
if [ -d "$WEB_DIR" ]; then
    info "Archiving $WEB_DIR..."
    tar czf "$BACKUP_DIR/panel_www_$TIMESTAMP.tar.gz" -C "$(dirname "$WEB_DIR")" "$(basename "$WEB_DIR")" \
        || error_exit "Failed to create web root backup"
    success "Web root backed up: $BACKUP_DIR/panel_www_$TIMESTAMP.tar.gz"
else
    warn "$WEB_DIR not found; skipping web root backup"
fi

# Backup MySQL database
info "Backing up MySQL database '$DB_NAME'..."
if command -v mysqldump >/dev/null 2>&1; then
    mysqldump -u "$MYSQL_USER" -p "$DB_NAME" > "$BACKUP_DIR/${DB_NAME}_backup_$TIMESTAMP.sql" \
        || error_exit "Database backup failed"
    success "Database '$DB_NAME' backed up: $BACKUP_DIR/${DB_NAME}_backup_$TIMESTAMP.sql"
else
    error_exit "mysqldump not found; install MySQL client tools first"
fi

# Ensure git is installed for cloning
if ! command -v git >/dev/null 2>&1; then
    info "Installing git..."
    apt-get update -qq
    apt-get install -y git curl unzip || error_exit "Failed to install git/curl"
fi

# Clone the Stellar theme repository
TEMP_DIR="/tmp/stellar_theme"
if [ -d "$TEMP_DIR" ]; then
    warn "$TEMP_DIR already exists, removing..."
    rm -rf "$TEMP_DIR"
fi
info "Cloning Stellar theme repository..."
git clone https://github.com/sudarshandev11/stellartheme "$TEMP_DIR" \
    || error_exit "Failed to clone repository"
success "Repository cloned to $TEMP_DIR"

# Copy theme files to panel directory
info "Copying theme files into $WEB_DIR..."
if [ -d "$WEB_DIR" ]; then
    cp -a "$TEMP_DIR/." "$WEB_DIR" || error_exit "Failed to copy theme files"
    success "Theme files copied to $WEB_DIR"
else
    error_exit "$WEB_DIR not found; ensure Pterodactyl is installed"
fi

# Ensure Node.js v20 is installed
if command -v node >/dev/null 2>&1; then
    NODE_VER=$(node -v)
    info "Detected Node.js version $NODE_VER"
else
    info "Node.js not found, installing Node.js 20.x..."
    curl -fsSL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh \
        || error_exit "Failed to download Node.js setup script"
    bash nodesource_setup.sh || error_exit "NodeSource setup script failed"
    apt-get install -y nodejs || error_exit "Failed to install Node.js"
    success "Node.js installed"
fi

# Ensure Yarn is installed
if command -v yarn >/dev/null 2>&1; then
    YARN_VER=$(yarn -v)
    info "Detected Yarn version $YARN_VER"
else
    info "Yarn not found, installing Yarn via npm..."
    npm install -g yarn || error_exit "Failed to install Yarn"
    success "Yarn installed"
fi

# Install frontend dependencies (including react-feather)
info "Installing NPM dependencies..."
cd "$WEB_DIR"
if [ -f package.json ]; then
    yarn add react-feather --ignore-scripts || warn "react-feather installation encountered an issue"
    yarn install --frozen-lockfile || error_exit "yarn install failed"
    success "NPM dependencies installed"
else
    warn "package.json not found, skipping npm install"
fi

# Run database migrations
info "Running database migrations..."
php artisan migrate --force || error_exit "artisan migrate failed"
success "Database migrated"

# Build frontend assets
info "Building assets with yarn..."
export NODE_OPTIONS=--openssl-legacy-provider
yarn build || error_exit "Asset build failed"
success "Assets built"

# Clear view cache
info "Clearing view cache..."
php artisan view:clear || warn "artisan view:clear failed"
success "View cache cleared"

# Fix permissions
info "Fixing ownership and permissions..."
chown -R www-data:www-data "$WEB_DIR" || error_exit "Failed to set ownership"
find "$WEB_DIR" -type d -exec chmod 755 {} \\; || error_exit "Failed to set directory permissions"
find "$WEB_DIR" -type f -exec chmod 644 {} \\; || error_exit "Failed to set file permissions"
success "Ownership and permissions set"

echo
success "Stellar theme installation complete!"
echo "Backup files are located in $BACKUP_DIR"
