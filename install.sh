#!/bin/bash
#=====================================================================
# bMTA – Fully Automated Universal Installer (error‑collecting, firewall autoconfig)
# Run as root: sudo bash install.sh
#=====================================================================
set +e    # Continue even if individual commands fail

# ---------- colour helpers ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# ---------- error collection ----------
ERRORS=()
add_error() { ERRORS+=("$1"); }

# ---------- root check ----------
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root.${NC}"
    exit 1
fi

# ---------- environment (overridable) ----------
DB_HOST="${BMTA_DB_HOST:-localhost}"
DB_NAME="${BMTA_DB_NAME:-bmta}"
DB_USER="${BMTA_DB_USER:-bmta}"
DB_PASS="${BMTA_DB_PASS:-$(openssl rand -base64 16)}"
APP_URL="${BMTA_BASE_URL:-http://$(hostname -I | awk '{print $1}')/}"
SERVER_IP=$(hostname -I | awk '{print $1}')

# ---------- OS detection ----------
if [ -f /etc/os-release ]; then . /etc/os-release
else
    echo -e "${RED}Cannot detect OS.${NC}"
    exit 1
fi
OS_ID="$ID"
OS_VERSION="${VERSION_ID:-}"
OS_PRETTY="$PRETTY_NAME"

# ---------- Detect package manager and settings ----------
detect_distro() {
    if command -v apt &>/dev/null; then
        PKG_UPDATE="apt update -y && apt upgrade -y"
        PKG_INSTALL="DEBIAN_FRONTEND=noninteractive apt install -y"
        PKG_EXTRA="software-properties-common dos2unix wget acl expect"
        PHP_PREFIX="php"
        APACHE_SERVICE="apache2"
        MYSQL_SERVICE="mariadb"
        POSTFIX_SERVICE="postfix"
        DOVECOT_SERVICE="dovecot"
        APACHE_USER="www-data"
        APACHE_GROUP="www-data"
        APACHE_CONF_DIR="/etc/apache2/sites-available"
        APACHE_SITES_DIR="/etc/apache2/sites-enabled"
        PHP_INI_BASE="/etc/php"
    elif command -v dnf &>/dev/null; then
        PKG_UPDATE="dnf update -y"
        PKG_INSTALL="dnf install -y"
        PKG_EXTRA="epel-release dos2unix wget acl expect"
        PHP_PREFIX="php"
        APACHE_SERVICE="httpd"
        MYSQL_SERVICE="mariadb"
        POSTFIX_SERVICE="postfix"
        DOVECOT_SERVICE="dovecot"
        APACHE_USER="apache"
        APACHE_GROUP="apache"
        APACHE_CONF_DIR="/etc/httpd/conf.d"
        APACHE_SITES_DIR="/etc/httpd/conf.d"
        PHP_INI_BASE="/etc/php.d"
    elif command -v yum &>/dev/null; then
        PKG_UPDATE="yum update -y"
        PKG_INSTALL="yum install -y"
        PKG_EXTRA="epel-release dos2unix wget acl expect"
        PHP_PREFIX="php"
        APACHE_SERVICE="httpd"
        MYSQL_SERVICE="mariadb"
        POSTFIX_SERVICE="postfix"
        DOVECOT_SERVICE="dovecot"
        APACHE_USER="apache"
        APACHE_GROUP="apache"
        APACHE_CONF_DIR="/etc/httpd/conf.d"
        APACHE_SITES_DIR="/etc/httpd/conf.d"
        PHP_INI_BASE="/etc/php.d"
    elif command -v zypper &>/dev/null; then
        PKG_UPDATE="zypper --non-interactive refresh && zypper --non-interactive update"
        PKG_INSTALL="zypper --non-interactive install"
        PKG_EXTRA="dos2unix wget acl expect"
        PHP_PREFIX="php"
        APACHE_SERVICE="apache2"
        MYSQL_SERVICE="mariadb"
        POSTFIX_SERVICE="postfix"
        DOVECOT_SERVICE="dovecot"
        APACHE_USER="wwwrun"
        APACHE_GROUP="www"
        APACHE_CONF_DIR="/etc/apache2/vhosts.d"
        APACHE_SITES_DIR="/etc/apache2/vhosts.d"
        PHP_INI_BASE="/etc/php"
    elif command -v pacman &>/dev/null; then
        PKG_UPDATE="pacman -Syu --noconfirm"
        PKG_INSTALL="pacman -S --noconfirm"
        PKG_EXTRA="dos2unix wget acl expect"
        PHP_PREFIX="php"
        APACHE_SERVICE="httpd"
        MYSQL_SERVICE="mariadb"
        POSTFIX_SERVICE="postfix"
        DOVECOT_SERVICE="dovecot"
        APACHE_USER="http"
        APACHE_GROUP="http"
        APACHE_CONF_DIR="/etc/httpd/conf/extra"
        APACHE_SITES_DIR="/etc/httpd/conf/sites"
        PHP_INI_BASE="/etc/php"
    elif command -v apk &>/dev/null; then
        PKG_UPDATE="apk update && apk upgrade"
        PKG_INSTALL="apk add"
        PKG_EXTRA="dos2unix wget acl expect"
        PHP_PREFIX="php"
        APACHE_SERVICE="apache2"
        MYSQL_SERVICE="mariadb"
        POSTFIX_SERVICE="postfix"
        DOVECOT_SERVICE="dovecot"
        APACHE_USER="apache"
        APACHE_GROUP="apache"
        APACHE_CONF_DIR="/etc/apache2/conf.d"
        APACHE_SITES_DIR="/etc/apache2/conf.d"
        PHP_INI_BASE="/etc/php"
    else
        echo -e "${RED}Unsupported package manager.${NC}"
        exit 1
    fi
}
detect_distro

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  bMTA Universal Installer               ${NC}"
echo -e "${GREEN}  Detected: $OS_PRETTY                    ${NC}"
echo -e "${GREEN}========================================${NC}"

# ---------- 1. Install system packages ----------
echo -e "\n${GREEN}[1/9] Installing system packages...${NC}"
eval "$PKG_UPDATE" || add_error "System update failed"
$PKG_INSTALL $PKG_EXTRA || add_error "Failed to install essential tools"

# Add PHP repository for Debian/Ubuntu
if command -v apt &>/dev/null; then
    if [[ "$OS_ID" == "ubuntu" ]]; then
        add-apt-repository -y ppa:ondrej/php || add_error "Failed to add PHP PPA"
        apt update -y || add_error "apt update after PPA failed"
    fi
fi

# Enable EPEL, Remi, CRB for RHEL-based
if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
    $PKG_INSTALL https://rpms.remirepo.net/enterprise/remi-release-${OS_VERSION}.rpm || add_error "Failed to install Remi repo"
    if command -v dnf &>/dev/null; then
        dnf module reset php -y || add_error "PHP module reset failed"
        dnf module enable php:remi-8.2 -y || add_error "Failed to enable PHP 8.2 module"
        # CRB for opendkim dependencies
        dnf config-manager --set-enabled crb || add_error "Failed to enable CRB repository (needed for libmemcached)"
        dnf install -y libmemcached libmemcached-devel || add_error "Failed to install libmemcached (opendkim dependency)"
    fi
fi

# Determine PHP version
php_ver=""
for v in 8.3 8.2 8.1 8.0; do
    if $PKG_INSTALL ${PHP_PREFIX}${v} 2>/dev/null; then php_ver="$v"; break; fi
done
if [ -z "$php_ver" ]; then
    $PKG_INSTALL ${PHP_PREFIX} || php_ver=""
fi

# Install the core stack
if command -v apt &>/dev/null; then
    $PKG_INSTALL apache2 mariadb-server mariadb-client \
        php${php_ver} libapache2-mod-php${php_ver} \
        php${php_ver}-mysql php${php_ver}-imap php${php_ver}-cli \
        php${php_ver}-curl php${php_ver}-mbstring php${php_ver}-xml \
        php${php_ver}-zip php${php_ver}-gd \
        postfix postfix-mysql dovecot-core dovecot-mysql dovecot-imapd dovecot-pop3d \
        opendkim opendkim-tools || add_error "Failed to install one or more packages"
elif command -v dnf &>/dev/null || command -v yum &>/dev/null; then
    $PKG_INSTALL httpd mariadb-server mariadb \
        php php-mysqlnd php-imap php-cli php-curl php-mbstring php-xml php-zip php-gd \
        postfix postfix-mysql dovecot dovecot-mysql dovecot-pigeonhole \
        opendkim opendkim-tools || add_error "Failed to install one or more packages"
elif command -v zypper &>/dev/null; then
    $PKG_INSTALL apache2 mariadb mariadb-client \
        php${php_ver} php${php_ver}-mysql php${php_ver}-imap php${php_ver}-cli \
        php${php_ver}-curl php${php_ver}-mbstring php${php_ver}-xml php${php_ver}-zip php${php_ver}-gd \
        postfix postfix-mysql dovecot23 dovecot23-backend-mysql \
        opendkim || add_error "Failed to install one or more packages"
elif command -v pacman &>/dev/null; then
    $PKG_INSTALL apache mariadb \
        php php-apache php-mysql php-imap php-curl php-mbstring php-xml php-zip php-gd \
        postfix postfix-mysql dovecot opendkim || add_error "Failed to install one or more packages"
elif command -v apk &>/dev/null; then
    $PKG_INSTALL apache2 mariadb mariadb-client \
        php php-mysqlnd php-imap php-curl php-mbstring php-xml php-zip php-gd \
        postfix postfix-mysql dovecot opendkim || add_error "Failed to install one or more packages"
fi

# Postfix preseeding (Debian/Ubuntu)
if command -v debconf-set-selections &>/dev/null; then
    SERVER_FQDN="$(hostname -f)"
    debconf-set-selections <<< "postfix postfix/mailname string $SERVER_FQDN"
    debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
fi

# ---------- 2. Configure PHP ----------
echo -e "\n${GREEN}[2/9] Configuring PHP...${NC}"
if [ -z "$php_ver" ]; then
    php_ver=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null) || php_ver="8.2"
fi

if [[ "$PHP_INI_BASE" == "/etc/php.d" ]]; then
    ini_file="/etc/php.ini"
    sed -i 's/^upload_max_filesize.*/upload_max_filesize = 100M/' "$ini_file" 2>/dev/null || add_error "Failed to set upload_max_filesize"
    sed -i 's/^post_max_size.*/post_max_size = 100M/' "$ini_file" 2>/dev/null || add_error "Failed to set post_max_size"
    sed -i 's/^memory_limit.*/memory_limit = 256M/' "$ini_file" 2>/dev/null || add_error "Failed to set memory_limit"
    sed -i 's/^max_execution_time.*/max_execution_time = 300/' "$ini_file" 2>/dev/null || add_error "Failed to set max_execution_time"
else
    for env in apache2 cli; do
        ini="/etc/php/${php_ver}/${env}/php.ini"
        [ -f "$ini" ] && {
            sed -i 's/^upload_max_filesize.*/upload_max_filesize = 100M/' "$ini" || add_error "Failed to set upload_max_filesize in $ini"
            sed -i 's/^post_max_size.*/post_max_size = 100M/' "$ini" || add_error "Failed to set post_max_size in $ini"
            sed -i 's/^memory_limit.*/memory_limit = 256M/' "$ini" || add_error "Failed to set memory_limit in $ini"
            sed -i 's/^max_execution_time.*/max_execution_time = 300/' "$ini" || add_error "Failed to set max_execution_time in $ini"
            echo "    Updated $ini"
        }
    done
fi

# ---------- 3. Database ----------
echo -e "\n${GREEN}[3/9] Setting up database...${NC}"
systemctl start ${MYSQL_SERVICE} 2>/dev/null || service ${MYSQL_SERVICE} start 2>/dev/null || add_error "Failed to start ${MYSQL_SERVICE}"
systemctl enable ${MYSQL_SERVICE} 2>/dev/null || true

DB_PASS_SQL=$(printf '%s\n' "$DB_PASS" | sed "s/'/''/g")
mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || add_error "Database creation failed"
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS_SQL}';" || add_error "User creation failed"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;" || add_error "GRANT failed"
mysql -e "ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS_SQL}';" || add_error "ALTER USER failed"

if [ -f /var/www/html/sql/schema.sql ]; then
    dos2unix /var/www/html/sql/schema.sql 2>/dev/null || true
    sed -i 's/CREATE TABLE `/CREATE TABLE IF NOT EXISTS `/g' /var/www/html/sql/schema.sql
    mysql ${DB_NAME} < /var/www/html/sql/schema.sql || add_error "Schema import failed"
else
    add_error "Schema file not found at /var/www/html/sql/schema.sql"
fi

# ---------- 4. App config ----------
echo -e "\n${GREEN}[4/9] Generating application configuration...${NC}"
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

# ---------- 5. Postfix ----------
echo -e "\n${GREEN}[5/9] Configuring Postfix...${NC}"
for f in /var/www/html/postfix/main.cf.patch /var/www/html/postfix/mysql_virtual_domains.cf /var/www/html/postfix/mysql_virtual_mailbox_maps.cf /var/www/html/postfix/mysql_virtual_alias_maps.cf; do
    [ ! -f "$f" ] && add_error "Missing Postfix file: $f"
done
cp /etc/postfix/main.cf /etc/postfix/main.cf.bak 2>/dev/null || true
dos2unix /var/www/html/postfix/main.cf.patch 2>/dev/null || true
cat /var/www/html/postfix/main.cf.patch >> /etc/postfix/main.cf || add_error "Failed to append Postfix config"
cp /var/www/html/postfix/mysql_virtual_*.cf /etc/postfix/ || add_error "Failed to copy Postfix mysql files"
DB_PASS_ESC=$(printf '%s\n' "$DB_PASS" | sed -e 's/[\|&]/\\&/g')
for f in /etc/postfix/mysql_virtual_*.cf; do
    sed -i "s|password = .*|password = ${DB_PASS_ESC}|" "$f" || add_error "Failed to set password in $f"
    postmap "$f" || add_error "postmap failed for $f"
done
id -u vmail &>/dev/null || useradd -m -d /var/mail/vhosts -s /bin/false vmail || add_error "Failed to create vmail user"
mkdir -p /var/mail/vhosts
chown -R vmail:vmail /var/mail/vhosts || add_error "Failed to set ownership on /var/mail/vhosts"
chmod -R 770 /var/mail/vhosts
systemctl restart ${POSTFIX_SERVICE} 2>/dev/null || service ${POSTFIX_SERVICE} restart 2>/dev/null || add_error "Failed to restart Postfix"

# ---------- 6. Dovecot ----------
echo -e "\n${GREEN}[6/9] Configuring Dovecot...${NC}"
for f in /var/www/html/dovecot/dovecot.conf.patch /var/www/html/dovecot/conf.d/10-auth.conf /var/www/html/dovecot/conf.d/auth-sql.conf.ext /var/www/html/dovecot/dovecot-sql.conf.ext; do
    [ ! -f "$f" ] && add_error "Missing Dovecot file: $f"
done
cp /var/www/html/dovecot/dovecot.conf.patch /etc/dovecot/ || true
cp /var/www/html/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/ || add_error "Failed to copy Dovecot 10-auth.conf"
cp /var/www/html/dovecot/conf.d/auth-sql.conf.ext /etc/dovecot/conf.d/ || add_error "Failed to copy Dovecot auth-sql.conf.ext"
cp /var/www/html/dovecot/dovecot-sql.conf.ext /etc/dovecot/ || add_error "Failed to copy Dovecot dovecot-sql.conf.ext"
dos2unix /etc/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/auth-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext 2>/dev/null || true
sed -i "s|connect = .*|connect = host=127.0.0.1 dbname=${DB_NAME} user=${DB_USER} password=${DB_PASS_ESC}|" /etc/dovecot/dovecot-sql.conf.ext || add_error "Failed to set Dovecot DB credentials"
chown -R vmail:dovecot /etc/dovecot 2>/dev/null || true
chmod -R o-rwx /etc/dovecot
systemctl restart ${DOVECOT_SERVICE} 2>/dev/null || service ${DOVECOT_SERVICE} restart 2>/dev/null || add_error "Failed to restart Dovecot"

# ---------- 7. Apache / httpd ----------
echo -e "\n${GREEN}[7/9] Configuring Apache/httpd...${NC}"
# Enable rewrite
if command -v a2enmod &>/dev/null; then a2enmod rewrite || add_error "Failed to enable mod_rewrite"; fi

if [[ "$APACHE_SERVICE" == "apache2" ]]; then
    cat > ${APACHE_CONF_DIR}/000-bmta.conf <<EOF || add_error "Failed to create Apache vhost"
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/public
    <Directory /var/www/html/public>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
    [ -d "$APACHE_SITES_DIR" ] && ln -sf ${APACHE_CONF_DIR}/000-bmta.conf ${APACHE_SITES_DIR}/ 2>/dev/null || add_error "Failed to symlink Apache site"
else
    cat > ${APACHE_CONF_DIR}/bmta.conf <<EOF || add_error "Failed to create Apache vhost"
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/public
    <Directory /var/www/html/public>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog "logs/bmta_error_log"
    CustomLog "logs/bmta_access_log" combined
</VirtualHost>
EOF
fi

chown -R ${APACHE_USER}:${APACHE_GROUP} /var/www/html/ || add_error "Failed to set ownership"
mkdir -p /var/www/html/public/uploads
chmod 775 /var/www/html/public/uploads
chcon -R -t httpd_sys_rw_content_t /var/www/html/public/uploads 2>/dev/null || true  # SELinux

systemctl restart ${APACHE_SERVICE} 2>/dev/null || service ${APACHE_SERVICE} restart 2>/dev/null || add_error "Failed to restart Apache"

# ---------- 8. Firewall (automatic port opening) ----------
echo -e "\n${GREEN}[8/9] Configuring firewall...${NC}"
configure_firewall() {
    # Firewalld (RHEL/CentOS/Fedora)
    if command -v firewall-cmd &>/dev/null; then
        systemctl enable --now firewalld 2>/dev/null || true
        firewall-cmd --permanent --add-port=80/tcp --add-port=25/tcp --add-port=443/tcp --add-port=587/tcp --add-port=993/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        echo "    firewalld ports added."
        return 0
    fi

    # ufw (Ubuntu/Debian)
    if command -v ufw &>/dev/null; then
        ufw --force enable 2>/dev/null || true
        ufw allow 80/tcp 2>/dev/null
        ufw allow 25/tcp 2>/dev/null
        ufw allow 443/tcp 2>/dev/null
        ufw allow 587/tcp 2>/dev/null
        ufw allow 993/tcp 2>/dev/null
        echo "    ufw ports added."
        return 0
    fi

    # iptables (legacy, temporary)
    if command -v iptables &>/dev/null; then
        iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null
        iptables -I INPUT -p tcp --dport 25 -j ACCEPT 2>/dev/null
        iptables -I INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null
        iptables -I INPUT -p tcp --dport 587 -j ACCEPT 2>/dev/null
        iptables -I INPUT -p tcp --dport 993 -j ACCEPT 2>/dev/null
        echo "    iptables rules added (non‑persistent)."
        return 0
    fi

    # No firewall present – install one based on package manager
    if command -v apt &>/dev/null; then
        DEBIAN_FRONTEND=noninteractive apt install -y ufw 2>/dev/null
        ufw --force enable 2>/dev/null
        ufw allow 80/tcp; ufw allow 25/tcp; ufw allow 443/tcp; ufw allow 587/tcp; ufw allow 993/tcp
        echo "    ufw installed and ports added."
    elif command -v dnf &>/dev/null; then
        dnf install -y firewalld 2>/dev/null
        systemctl enable --now firewalld 2>/dev/null
        firewall-cmd --permanent --add-port=80/tcp --add-port=25/tcp --add-port=443/tcp --add-port=587/tcp --add-port=993/tcp 2>/dev/null
        firewall-cmd --reload 2>/dev/null
        echo "    firewalld installed and ports added."
    elif command -v yum &>/dev/null; then
        yum install -y firewalld 2>/dev/null
        systemctl enable --now firewalld 2>/dev/null
        firewall-cmd --permanent --add-port=80/tcp --add-port=25/tcp --add-port=443/tcp --add-port=587/tcp --add-port=993/tcp 2>/dev/null
        firewall-cmd --reload 2>/dev/null
        echo "    firewalld installed and ports added."
    else
        add_error "Could not configure firewall. Please open ports 80,25,443,587,993 manually."
    fi
}
configure_firewall

# ---------- 9. Cron ----------
echo -e "\n${GREEN}[9/9] Installing cron jobs...${NC}"
mkdir -p /var/log/bmta
(crontab -l 2>/dev/null | grep -v "process_queue\|process_bounces"; 
 echo "* * * * * /usr/bin/php /var/www/html/cron/process_queue.php >> /var/log/bmta/queue.log 2>&1";
 echo "*/5 * * * * /usr/bin/php /var/www/html/cron/process_bounces.php >> /var/log/bmta/bounces.log 2>&1") | crontab - || add_error "Failed to install cron jobs"

# ---------- Final Report ----------
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  bMTA installation completed!            ${NC}"
echo -e "${GREEN}========================================${NC}"

if [ ${#ERRORS[@]} -eq 0 ]; then
    echo -e "${GREEN}No errors detected.${NC}"
else
    echo -e "${RED}The following errors occurred:${NC}"
    for err in "${ERRORS[@]}"; do
        echo -e "  - ${RED}$err${NC}"
    done
    echo -e "\nSome parts may not be fully functional. Please check the messages above."
fi

echo ""
echo -e "Open ${YELLOW}${APP_URL}${NC} to create the admin account."
echo -e "Database: ${DB_NAME} | User: ${DB_USER} | Pass: ${DB_PASS}"
echo -e "Firewall ports 25,80,443,587,993 have been automatically opened."
echo -e "${RED}Set DNS records as shown in the domain manager.${NC}"
