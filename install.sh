#!/bin/bash
set -e

echo "=== bMTA Installer ==="
echo "Make sure you are running on Ubuntu 22.04/24.04 as root."

DB_HOST="${BMTA_DB_HOST:-localhost}"
DB_NAME="${BMTA_DB_NAME:-bmta}"
DB_USER="${BMTA_DB_USER:-bmta}"
DB_PASS="${BMTA_DB_PASS:-$(openssl rand -base64 12)}"
APP_URL="${BMTA_BASE_URL:-http://$(hostname -I | awk '{print $1}')/}"

# Update system and install packages
apt update
apt install -y apache2 mysql-server php8.1 libapache2-mod-php \
  php8.1-mysql php8.1-imap php8.1-cli php8.1-curl php8.1-mbstring \
  php8.1-xml postfix dovecot-core dovecot-mysql dovecot-imapd dovecot-pop3d \
  opendkim opendkim-tools acl

# Configure MySQL
mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}'; GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"

# Populate database schema
mysql ${DB_NAME} < /var/www/html/sql/schema.sql

# Write configuration file
mkdir -p /var/www/html/config
cat > /var/www/html/config/config.php <<EOF
<?php
return [
    'db' => [
        'host'   => '${DB_HOST}',
        'dbname' => '${DB_NAME}',
        'user'   => '${DB_USER}',
        'pass'   => '${DB_PASS}',
        'charset'=> 'utf8mb4',
    ],
    'app' => [
        'base_url'       => '${APP_URL}',
        'tracking_pixel' => 'track/open/',
        'click_rewrite'  => 'track/click/',
        'dkim_key_size'  => 2048,
        'upload_dir'     => '/var/www/html/public/uploads',
    ],
];
EOF

# Set permissions
chown -R www-data:www-data /var/www/html/
chmod -R 755 /var/www/html/public/uploads

# Configure Postfix (append our settings)
cp /etc/postfix/main.cf /etc/postfix/main.cf.bak
cat /var/www/html/postfix/main.cf.patch >> /etc/postfix/main.cf
cp /var/www/html/postfix/mysql_*.cf /etc/postfix/
postmap /etc/postfix/mysql_virtual_domains.cf
postmap /etc/postfix/mysql_virtual_mailbox_maps.cf
postmap /etc/postfix/mysql_virtual_alias_maps.cf
systemctl restart postfix

# Configure Dovecot
cp /var/www/html/dovecot/dovecot.conf.patch /etc/dovecot/
cp /var/www/html/dovecot/conf.d/* /etc/dovecot/conf.d/
cp /var/www/html/dovecot/dovecot-sql.conf.ext /etc/dovecot/
mkdir -p /var/mail/vhosts
chown -R vmail:vmail /var/mail/vhosts
systemctl restart dovecot

# Set up Cron jobs
(crontab -l 2>/dev/null; echo "* * * * * /usr/bin/php /var/www/html/cron/process_queue.php >> /var/log/bmta_queue.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/bin/php /var/www/html/cron/process_bounces.php >> /var/log/bmta_bounces.log 2>&1") | crontab -

echo "===================================="
echo "bMTA installation complete!"
echo "Open ${APP_URL} and create your admin account."
echo "Database password: ${DB_PASS} (stored in config/config.php)"
