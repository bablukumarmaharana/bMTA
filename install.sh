#!/bin/bash
set -e

# Usage: DB user/pass from environment, or generated
DB_HOST="${BMTA_DB_HOST:-localhost}"
DB_NAME="${BMTA_DB_NAME:-bmta}"
DB_USER="${BMTA_DB_USER:-bmta}"
DB_PASS="${BMTA_DB_PASS:-$(openssl rand -base64 12)}"

apt update
apt install -y apache2 mysql-server php8.1 libapache2-mod-php \
  php8.1-mysql php8.1-imap php8.1-cli php8.1-curl php8.1-mbstring \
  postfix dovecot-core dovecot-mysql dovecot-imapd dovecot-pop3d \
  opendkim opendkim-tools

# Create database and user
mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}'; GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"
mysql ${DB_NAME} < /var/www/html/sql/schema.sql

# Generate config
mkdir -p /var/www/html/config
cat > /var/www/html/config/config.php <<EOF
<?php
return [
    'db' => [
        'host' => '${DB_HOST}',
        'dbname' => '${DB_NAME}',
        'user' => '${DB_USER}',
        'pass' => '${DB_PASS}',
        'charset' => 'utf8mb4',
    ],
    'app' => [
        'base_url' => 'http://${_SERVER_IP_OR_DOMAIN}/',
        'tracking_pixel' => 'track/open/',
        'click_rewrite' => 'track/click/',
        'dkim_key_size' => 2048,
        'upload_dir' => '/var/www/html/public/uploads',
    ],
];
EOF

# Deploy application (assuming files are already in place via git clone / copy)
# ... set permissions, etc.
# Postfix, Dovecot setup as before
# Cron jobs (do not forget)

echo "bMTA installed. Visit http://$(hostname -I | awk '{print $1}')/ and create your admin account."
echo "Database password: ${DB_PASS} (saved in config/config.php)"