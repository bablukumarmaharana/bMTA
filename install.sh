#!/bin/bash
#=====================================================================
# bMTA - Bulk Mail Transfer Agent
# One‑click installer for Ubuntu 22.04/24.04 or Debian 12
# Run as root: sudo bash install.sh
#=====================================================================
set -e

# --- Colour codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  bMTA Automated Installer               ${NC}"
echo -e "${GREEN}========================================${NC}"

# --- Check root ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root.${NC}" 
   exit 1
fi

# --- Detect OS ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo -e "${RED}Cannot detect OS. Exiting.${NC}"
    exit 1
fi

if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
    echo -e "${RED}Unsupported OS. This installer supports Ubuntu and Debian.${NC}"
    exit 1
fi

echo -e "${YELLOW}Detected $OS $VERSION${NC}"

# --- Environment variables with random password fallback ---
DB_HOST="${BMTA_DB_HOST:-localhost}"
DB_NAME="${BMTA_DB_NAME:-bmta}"
DB_USER="${BMTA_DB_USER:-bmta}"
DB_PASS="${BMTA_DB_PASS:-$(openssl rand -base64 16)}"
APP_URL="${BMTA_BASE_URL:-http://$(hostname -I | awk '{print $1}')/}"
SERVER_IP=$(hostname -I | awk '{print $1}')
PHP_VERSION=""

# Determine available PHP version
if command -v php8.3 &>/dev/null; then PHP_VERSION="8.3"
elif command -v php8.2 &>/dev/null; then PHP_VERSION="8.2"
elif command -v php8.1 &>/dev/null; then PHP_VERSION="8.1"
else PHP_VERSION="8.2"  # default attempt
fi

echo -e "${YELLOW}Using PHP $PHP_VERSION${NC}"

# --- 1. Update system and install core packages ---
echo -e "\n${GREEN}[1/8] Installing system packages...${NC}"
apt update -y
apt upgrade -y
apt install -y software-properties-common wget unzip acl dos2unix

# Pre-seed Postfix to avoid interactive prompts
SERVER_FQDN="$(hostname -f)"
debconf-set-selections <<< "postfix postfix/mailname string $SERVER_FQDN"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

# Add PHP repository if needed
if [[ "$OS" == "ubuntu" ]]; then
    add-apt-repository -y ppa:ondrej/php
    apt update -y
fi

# Install LAMP + required modules
apt install -y \
    apache2 \
    mariadb-server mariadb-client \
    php${PHP_VERSION} libapache2-mod-php${PHP_VERSION} \
    php${PHP_VERSION}-mysql php${PHP_VERSION}-imap php${PHP_VERSION}-cli \
    php${PHP_VERSION}-curl php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml \
    php${PHP_VERSION}-zip php${PHP_VERSION}-gd \
    postfix postfix-mysql dovecot-core dovecot-mysql dovecot-imapd dovecot-pop3d \
    opendkim opendkim-tools

# --- 2. Configure PHP ---
echo -e "\n${GREEN}[2/8] Configuring PHP...${NC}"
PHP_INI_DIR="/etc/php/${PHP_VERSION}"
for php_env in apache2 cli; do
    ini_file="${PHP_INI_DIR}/${php_env}/php.ini"
    if [ -f "$ini_file" ]; then
        sed -i 's/^upload_max_filesize.*/upload_max_filesize = 100M/' "$ini_file"
        sed -i 's/^post_max_size.*/post_max_size = 100M/' "$ini_file"
        sed -i 's/^memory_limit.*/memory_limit = 256M/' "$ini_file"
        sed -i 's/^max_execution_time.*/max_execution_time = 300/' "$ini_file"
        echo "    Updated $ini_file"
    fi
done

# --- 3. Configure MySQL/MariaDB ---
echo -e "\n${GREEN}[3/8] Setting up database...${NC}"
systemctl start mariadb
systemctl enable mariadb

mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"

# Import schema (make it idempotent first)
if [ -f /var/www/html/sql/schema.sql ]; then
    # Fix potential CRLF issues in schema file
    dos2unix /var/www/html/sql/schema.sql 2>/dev/null || true
    # Replace CREATE TABLE with IF NOT EXISTS for re-runs
    sed -i 's/CREATE TABLE `/CREATE TABLE IF NOT EXISTS `/g' /var/www/html/sql/schema.sql
    mysql ${DB_NAME} < /var/www/html/sql/schema.sql
else
    echo -e "${RED}Schema file not found at /var/www/html/sql/schema.sql. Did you clone the repository?${NC}"
    exit 1
fi

# --- 4. Create bMTA configuration ---
echo -e "\n${GREEN}[4/8] Generating application configuration...${NC}"
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

# --- 5. Set up mail infrastructure ---
echo -e "\n${GREEN}[5/8] Configuring Postfix...${NC}"

# Check if required files exist
for f in /var/www/html/postfix/main.cf.patch /var/www/html/postfix/mysql_virtual_domains.cf /var/www/html/postfix/mysql_virtual_mailbox_maps.cf /var/www/html/postfix/mysql_virtual_alias_maps.cf; do
    if [ ! -f "$f" ]; then
        echo -e "${RED}Missing Postfix configuration file: $f${NC}"
        echo "Make sure the full repository is cloned (including postfix/ directory)."
        exit 1
    fi
done

cp /etc/postfix/main.cf /etc/postfix/main.cf.bak

# Fix line endings and append custom configuration
dos2unix /var/www/html/postfix/main.cf.patch 2>/dev/null || true
cat /var/www/html/postfix/main.cf.patch >> /etc/postfix/main.cf

# Copy MySQL lookup files
cp /var/www/html/postfix/mysql_virtual_domains.cf /etc/postfix/
cp /var/www/html/postfix/mysql_virtual_mailbox_maps.cf /etc/postfix/
cp /var/www/html/postfix/mysql_virtual_alias_maps.cf /etc/postfix/

# Secure the MySQL password inside .cf files (handle special characters safely)
# Escape the password for safe use in sed - we use '|' as delimiter and escape any '|' in the password
DB_PASS_ESC=$(printf '%s\n' "$DB_PASS" | sed -e 's/[\|&]/\\&/g')
for f in /etc/postfix/mysql_virtual_domains.cf /etc/postfix/mysql_virtual_mailbox_maps.cf /etc/postfix/mysql_virtual_alias_maps.cf; do
    dos2unix "$f" 2>/dev/null || true
    sed -i "s|password = .*|password = ${DB_PASS_ESC}|" "$f"
done

postmap /etc/postfix/mysql_virtual_domains.cf
postmap /etc/postfix/mysql_virtual_mailbox_maps.cf
postmap /etc/postfix/mysql_virtual_alias_maps.cf

# Create vmail user if not exists
id -u vmail &>/dev/null || useradd -m -d /var/mail/vhosts -s /bin/false vmail
mkdir -p /var/mail/vhosts
chown -R vmail:vmail /var/mail/vhosts
chmod -R 770 /var/mail/vhosts

systemctl restart postfix

# --- 6. Configure Dovecot ---
echo -e "\n${GREEN}[6/8] Configuring Dovecot...${NC}"

# Check required files
for f in /var/www/html/dovecot/dovecot.conf.patch /var/www/html/dovecot/conf.d/10-auth.conf /var/www/html/dovecot/conf.d/auth-sql.conf.ext /var/www/html/dovecot/dovecot-sql.conf.ext; do
    if [ ! -f "$f" ]; then
        echo -e "${RED}Missing Dovecot configuration file: $f${NC}"
        echo "Make sure the full repository is cloned (including dovecot/ directory)."
        exit 1
    fi
done

cp /var/www/html/dovecot/dovecot.conf.patch /etc/dovecot/
cp /var/www/html/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/
cp /var/www/html/dovecot/conf.d/auth-sql.conf.ext /etc/dovecot/conf.d/
cp /var/www/html/dovecot/dovecot-sql.conf.ext /etc/dovecot/

# Fix line endings
dos2unix /etc/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/auth-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext 2>/dev/null || true

# Insert DB credentials into Dovecot SQL conf (safe sed using |)
sed -i "s|connect = .*|connect = host=127.0.0.1 dbname=${DB_NAME} user=${DB_USER} password=${DB_PASS_ESC}|" /etc/dovecot/dovecot-sql.conf.ext

# Fix permissions
chown -R vmail:dovecot /etc/dovecot
chmod -R o-rwx /etc/dovecot

systemctl restart dovecot

# --- 7. Configure Apache ---
echo -e "\n${GREEN}[7/8] Configuring Apache...${NC}"
a2enmod rewrite

# Allow .htaccess overrides in default site
cat > /etc/apache2/sites-available/000-default.conf <<'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/public

    <Directory /var/www/html/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Set proper ownership and permissions

chown -R www-data:www-data /var/www/html/
mkdir -p /var/www/html/public/uploads
chmod -R 755 /var/www/html/public/uploads
chown www-data:www-data /var/www/html/public/uploads
chmod 775 /var/www/html/public/uploads

systemctl restart apache2

# --- 8. Cron jobs ---
echo -e "\n${GREEN}[8/8] Installing cron jobs...${NC}"
mkdir -p /var/log/bmta
(crontab -l 2>/dev/null | grep -v "process_queue.php\|process_bounces.php"; 
 echo "* * * * * /usr/bin/php /var/www/html/cron/process_queue.php >> /var/log/bmta/queue.log 2>&1";
 echo "*/5 * * * * /usr/bin/php /var/www/html/cron/process_bounces.php >> /var/log/bmta/bounces.log 2>&1") | crontab -

# --- Summary ---
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  bMTA installation complete!            ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Please open ${YELLOW}${APP_URL}${NC} in your browser to create the admin account."
echo -e "Database credentials have been saved in /var/www/html/config/config.php"
echo -e "  ${YELLOW}Database: ${DB_NAME}${NC}"
echo -e "  ${YELLOW}Username:  ${DB_USER}${NC}"
echo -e "  ${YELLOW}Password:  ${DB_PASS}${NC}"
echo ""
echo -e "Postfix & Dovecot are configured to use the same database."
echo -e "DKIM keys will be generated automatically when you add a domain via the UI."
echo -e "Ensure your firewall allows ports 25, 80, 443, 993."
echo ""
echo -e "${RED}Important: Set your domain's DNS records (SPF, DKIM, DMARC, MX) as shown in the domain manager.${NC}"
