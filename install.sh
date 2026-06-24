#!/bin/bash
#=====================================================================
# bMTA – Universal Installer (latest PHP + latest MariaDB, Dovecot, etc.)
# Run as root: sudo bash install.sh
#=====================================================================
set +e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ERRORS=()
add_error() { ERRORS+=("$1"); }

if [ "$EUID" -ne 0 ]; then echo -e "${RED}Please run as root.${NC}"; exit 1; fi

# ---------- environment ----------
DB_HOST="${BMTA_DB_HOST:-localhost}"
DB_NAME="${BMTA_DB_NAME:-bmta}"
DB_USER="${BMTA_DB_USER:-bmta}"
DB_PASS="${BMTA_DB_PASS:-$(openssl rand -base64 16)}"

# ---------- portable IP detection ----------
get_ip() {
    if command -v hostname &>/dev/null && hostname -I &>/dev/null 2>&1; then
        hostname -I | awk '{print $1}'
    else
        ip addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -1
    fi
}
SERVER_IP=$(get_ip)
[ -z "$SERVER_IP" ] && SERVER_IP="127.0.0.1"
APP_URL="${BMTA_BASE_URL:-http://$SERVER_IP/}"

# ---------- OS detection ----------
if [ -f /etc/os-release ]; then . /etc/os-release
else echo -e "${RED}Cannot detect OS.${NC}"; exit 1; fi
OS_ID="$ID"
OS_VERSION="${VERSION_ID:-}"
OS_PRETTY="$PRETTY_NAME"

# ---------- package manager & settings ----------
detect_distro() {
    if command -v apt &>/dev/null; then
        PKG_UPDATE="apt update -y && apt upgrade -y"
        PKG_INSTALL="DEBIAN_FRONTEND=noninteractive apt install -y"
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
        MYSQL_CMD="mysql"
    elif command -v dnf &>/dev/null; then
        PKG_UPDATE="dnf update -y"
        PKG_INSTALL="dnf install -y"
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
        MYSQL_CMD="mysql"
    elif command -v yum &>/dev/null; then
        PKG_UPDATE="yum update -y"
        PKG_INSTALL="yum install -y"
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
        MYSQL_CMD="mysql"
    elif command -v zypper &>/dev/null; then
        PKG_UPDATE="zypper --non-interactive refresh && zypper --non-interactive update"
        PKG_INSTALL="zypper --non-interactive install"
        PHP_PREFIX="php8"
        APACHE_SERVICE="apache2"
        MYSQL_SERVICE="mariadb"
        POSTFIX_SERVICE="postfix"
        DOVECOT_SERVICE="dovecot"
        APACHE_USER="wwwrun"
        APACHE_GROUP="www"
        APACHE_CONF_DIR="/etc/apache2/vhosts.d"
        APACHE_SITES_DIR="/etc/apache2/vhosts.d"
        PHP_INI_BASE="/etc/php"
        MYSQL_CMD="mariadb"
    elif command -v pacman &>/dev/null; then
        PKG_UPDATE="pacman -Syu --noconfirm"
        PKG_INSTALL="pacman -S --noconfirm"
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
        MYSQL_CMD="mariadb"
    elif command -v apk &>/dev/null; then
        PKG_UPDATE="apk update && apk upgrade"
        PKG_INSTALL="apk add"
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
        MYSQL_CMD="mariadb"
    elif command -v emerge &>/dev/null; then
        PKG_UPDATE="emaint sync && emerge --sync"
        PKG_INSTALL="emerge"
        PHP_PREFIX="dev-lang/php"
        APACHE_SERVICE="apache2"
        MYSQL_SERVICE="mariadb"
        POSTFIX_SERVICE="postfix"
        DOVECOT_SERVICE="dovecot"
        APACHE_USER="apache"
        APACHE_GROUP="apache"
        APACHE_CONF_DIR="/etc/apache2/vhosts.d"
        APACHE_SITES_DIR="/etc/apache2/vhosts.d"
        PHP_INI_BASE="/etc/php"
        MYSQL_CMD="mariadb"
    else
        echo -e "${RED}Unsupported package manager.${NC}"; exit 1
    fi
}
detect_distro

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  bMTA Universal Installer               ${NC}"
echo -e "${GREEN}  Detected: $OS_PRETTY                    ${NC}"
echo -e "${GREEN}========================================${NC}"

# ---------- 0. Pre‑flight check & repair ----------
echo -e "\n${GREEN}[0/9] Pre‑flight check...${NC}"
if ! ping -c 2 8.8.8.8 &>/dev/null; then
    echo -e "${RED}No internet access.${NC}"; exit 1
fi

echo "    Testing package manager..."
case "$OS_ID" in
    alpine) $PKG_INSTALL dos2unix &>/dev/null || {
            echo "    Fixing Alpine repositories..."
            echo "http://dl-cdn.alpinelinux.org/alpine/v$(cat /etc/alpine-release | cut -d. -f1,2)/main" > /etc/apk/repositories
            echo "http://dl-cdn.alpinelinux.org/alpine/v$(cat /etc/alpine-release | cut -d. -f1,2)/community" >> /etc/apk/repositories
            apk update && apk add dos2unix || { echo -e "${RED}Alpine repair failed.${NC}"; exit 1; }
        }
        ;;
    gentoo) emerge sys-apps/dos2unix 2>/dev/null || add_error "Gentoo dos2unix install skipped" ;;
    *) eval "$PKG_INSTALL dos2unix" &>/dev/null || {
            echo -e "${YELLOW}Package manager failed – auto‑repair...${NC}"
            case "$OS_ID" in
                kali) cat > /etc/apt/sources.list <<'KALIEOF'
deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware
deb-src http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware
KALIEOF
                    apt update -y && DEBIAN_FRONTEND=noninteractive apt install -y dos2unix || { echo -e "${RED}Kali repair failed.${NC}"; exit 1; }
                    ;;
                ubuntu|debian) apt update --fix-missing -y && DEBIAN_FRONTEND=noninteractive apt install -y dos2unix || { echo -e "${RED}apt repair failed.${NC}"; exit 1; }
                    ;;
                centos|rhel|rocky|almalinux) dnf install -y epel-release dos2unix 2>/dev/null || yum install -y epel-release dos2unix || { echo -e "${RED}RHEL repair failed.${NC}"; exit 1; }
                    ;;
                opensuse*|sles*) zypper --non-interactive install dos2unix || { echo -e "${RED}SUSE repair failed.${NC}"; exit 1; }
                    ;;
                *) echo -e "${RED}Could not auto‑repair. Please fix package manager manually.${NC}"; exit 1 ;;
            esac
        }
        ;;
esac

# ---------- 1. Install system packages ----------
echo -e "\n${GREEN}[1/9] Installing system packages...${NC}"
eval "$PKG_UPDATE" || add_error "System update failed"

# ---------- ADDITIONAL REPOS FOR LATEST VERSIONS ----------
if command -v apt &>/dev/null; then
    # --- MariaDB official repo (latest version) ---
    if [ ! -f /etc/apt/sources.list.d/mariadb.list ]; then
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-10.11" 2>/dev/null || add_error "MariaDB repo setup failed"
    fi
    # --- Dovecot community repo (latest) ---
    if [ ! -f /etc/apt/sources.list.d/dovecot.list ]; then
        echo "deb [arch=amd64] https://repo.dovecot.org/ce-2.3-latest/$(lsb_release -sc)/$(lsb_release -sc) main" > /etc/apt/sources.list.d/dovecot.list
        apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 26FF2A43 2>/dev/null || true
    fi
    apt update -y || add_error "apt update after adding repos failed"
elif command -v dnf &>/dev/null || command -v yum &>/dev/null; then
    # RHEL already uses EPEL + Remi, which have latest MariaDB, Dovecot, etc.
    :
fi

# PHP repos
if command -v apt &>/dev/null; then
    if [[ "$OS_ID" == "ubuntu" ]]; then
        add-apt-repository -y ppa:ondrej/php || add_error "Failed to add PHP PPA"
        apt update -y || add_error "apt update after PPA failed"
    fi
fi

# RHEL: EPEL + Remi + CRB
if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
    $PKG_INSTALL https://rpms.remirepo.net/enterprise/remi-release-${OS_VERSION}.rpm 2>/dev/null || true
    $PKG_INSTALL epel-release 2>/dev/null || true
    if command -v dnf &>/dev/null; then
        dnf config-manager --set-enabled crb 2>/dev/null || true
        dnf install -y libmemcached libmemcached-devel 2>/dev/null || true
    fi
fi

# ---------- DYNAMIC PHP VERSION DETECTION ----------
detect_latest_php() {
    if command -v apt &>/dev/null; then
        apt-cache search --names-only '^php[0-9]+\.[0-9]+$' 2>/dev/null | \
            sed -n 's/^php\([0-9.]*\) .*/\1/p' | sort -Vr | head -1
    elif command -v dnf &>/dev/null; then
        dnf module list php 2>/dev/null | grep -E '^php[0-9]' | awk '{print $1}' | sort -Vr | head -1 | cut -d'c' -f1
    elif command -v yum &>/dev/null; then
        yum module list php 2>/dev/null | grep -E '^php[0-9]' | awk '{print $1}' | sort -Vr | head -1 | cut -d'c' -f1
    elif command -v zypper &>/dev/null; then
        zypper search php 2>/dev/null | grep -oP '^php\d+' | sort -Vr | head -1 | sed 's/php//'
    elif command -v pacman &>/dev/null; then
        echo "latest"
    elif command -v apk &>/dev/null; then
        apk search php 2>/dev/null | grep -oP '^php\d+' | sort -Vr | head -1 | sed 's/php//'
    elif command -v emerge &>/dev/null; then
        equery list -po dev-lang/php 2>/dev/null | grep -oP '\d+\.\d+' | sort -Vr | head -1
    else
        echo ""
    fi
}

php_ver=$(detect_latest_php)
if [ -z "$php_ver" ]; then
    $PKG_INSTALL ${PHP_PREFIX} 2>/dev/null && php_ver="latest"
fi

if [ "$php_ver" = "latest" ]; then
    php_suffix=""
else
    php_suffix="$php_ver"
fi

echo -e "${YELLOW}Detected PHP version: $php_suffix${NC}"

if command -v dnf &>/dev/null && [ -n "$php_suffix" ] && [ "$php_suffix" != "latest" ]; then
    dnf module enable php:remi-${php_suffix} -y 2>/dev/null || add_error "Failed to enable PHP ${php_suffix} module"
fi

if [ -n "$php_suffix" ] && [ "$php_suffix" != "latest" ]; then
    $PKG_INSTALL ${PHP_PREFIX}${php_suffix} || add_error "Failed to install PHP"
else
    $PKG_INSTALL ${PHP_PREFIX} || add_error "Failed to install PHP"
fi

# ---------- Install core packages per distribution ----------
install_core() {
    case "$OS_ID" in
        ubuntu|debian|kali|devuan|pureos|turnkeylinux)
            $PKG_INSTALL apache2 mariadb-server mariadb-client \
                php${php_suffix} libapache2-mod-php${php_suffix} \
                php${php_suffix}-mysql php${php_suffix}-imap php${php_suffix}-cli \
                php${php_suffix}-curl php${php_suffix}-mbstring php${php_suffix}-xml \
                php${php_suffix}-zip php${php_suffix}-gd \
                postfix postfix-mysql dovecot-core dovecot-mysql dovecot-imapd dovecot-pop3d \
                opendkim opendkim-tools
            ;;
        centos|rhel|rocky|almalinux|fedora|amzn|oracle)
            $PKG_INSTALL httpd mariadb-server mariadb \
                php php-mysqlnd php-imap php-cli php-curl php-mbstring php-xml php-zip php-gd \
                postfix postfix-mysql dovecot dovecot-mysql dovecot-pigeonhole \
                opendkim opendkim-tools
            ;;
        opensuse*|sles*)
            $PKG_INSTALL apache2 mariadb mariadb-client \
                ${PHP_PREFIX}-imap ${PHP_PREFIX}-mbstring ${PHP_PREFIX}-curl \
                ${PHP_PREFIX}-xml ${PHP_PREFIX}-zip ${PHP_PREFIX}-gd \
                postfix postfix-mysql dovecot dovecot-backend-mysql \
                opendkim
            ;;
        arch|manjaro)
            $PKG_INSTALL apache mariadb \
                php php-apache php-mysql php-imap php-curl php-mbstring php-xml php-zip php-gd \
                postfix postfix-mysql dovecot opendkim
            ;;
        alpine)
            $PKG_INSTALL apache2 mariadb mariadb-client \
                php php-mysqlnd php-imap php-curl php-mbstring php-xml php-zip php-gd \
                postfix postfix-mysql dovecot opendkim
            ;;
        gentoo)
            $PKG_INSTALL www-servers/apache dev-db/mariadb \
                dev-lang/php dev-php/php-mysql dev-php/php-imap dev-php/php-curl dev-php/php-mbstring dev-php/php-xml dev-php/php-zip dev-php/php-gd \
                mail-mta/postfix mail-mta/dovecot mail-filter/opendkim
            ;;
        *) add_error "Unknown distribution for package installation." ;;
    esac
}
install_core || add_error "Failed to install one or more packages"

# Postfix preseeding (Debian/Ubuntu)
if command -v debconf-set-selections &>/dev/null; then
    SERVER_FQDN="$(hostname -f)"
    debconf-set-selections <<< "postfix postfix/mailname string $SERVER_FQDN"
    debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
fi

# ---------- 2. Configure PHP ----------
echo -e "\n${GREEN}[2/9] Configuring PHP...${NC}"
php_ini_version="$php_suffix"
if [ -z "$php_ini_version" ] || [ "$php_ini_version" = "latest" ]; then
    php_ini_version=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.2")
fi

if [[ "$PHP_INI_BASE" == "/etc/php.d" ]]; then
    ini="/etc/php.ini"
    sed -i 's/^upload_max_filesize.*/upload_max_filesize = 100M/' "$ini" 2>/dev/null || add_error "upload_max_filesize"
    sed -i 's/^post_max_size.*/post_max_size = 100M/' "$ini" 2>/dev/null || add_error "post_max_size"
    sed -i 's/^memory_limit.*/memory_limit = 256M/' "$ini" 2>/dev/null || add_error "memory_limit"
    sed -i 's/^max_execution_time.*/max_execution_time = 300/' "$ini" 2>/dev/null || add_error "max_execution_time"
else
    for env in apache2 cli; do
        ini="/etc/php/${php_ini_version}/${env}/php.ini"
        [ -f "$ini" ] && {
            sed -i 's/^upload_max_filesize.*/upload_max_filesize = 100M/' "$ini" || add_error "upload_max_filesize $ini"
            sed -i 's/^post_max_size.*/post_max_size = 100M/' "$ini" || add_error "post_max_size $ini"
            sed -i 's/^memory_limit.*/memory_limit = 256M/' "$ini" || add_error "memory_limit $ini"
            sed -i 's/^max_execution_time.*/max_execution_time = 300/' "$ini" || add_error "max_execution_time $ini"
            echo "    Updated $ini"
        }
    done
fi

# ---------- 3. Database ----------
echo -e "\n${GREEN}[3/9] Setting up database...${NC}"
if [[ "$OS_ID" == "alpine" ]]; then
    mkdir -p /run/mysqld
    rc-service mariadb setup 2>/dev/null || true
    rc-service mariadb start 2>/dev/null || add_error "MariaDB start failed on Alpine"
else
    systemctl start ${MYSQL_SERVICE} 2>/dev/null || service ${MYSQL_SERVICE} start 2>/dev/null || add_error "Failed to start ${MYSQL_SERVICE}"
fi
systemctl enable ${MYSQL_SERVICE} 2>/dev/null || true

DB_PASS_SQL=$(printf '%s\n' "$DB_PASS" | sed "s/'/''/g")
$MYSQL_CMD -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || add_error "Database creation failed"
$MYSQL_CMD -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS_SQL}';" || add_error "User creation failed"
$MYSQL_CMD -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;" || add_error "GRANT failed"
$MYSQL_CMD -e "ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS_SQL}';" || add_error "ALTER USER failed"

if [ -f /var/www/html/sql/schema.sql ]; then
    dos2unix /var/www/html/sql/schema.sql 2>/dev/null || true
    sed -i 's/CREATE TABLE `/CREATE TABLE IF NOT EXISTS `/g' /var/www/html/sql/schema.sql
    $MYSQL_CMD ${DB_NAME} < /var/www/html/sql/schema.sql || add_error "Schema import failed"
else
    add_error "schema.sql not found"
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
mkdir -p /etc/postfix
for f in /var/www/html/postfix/main.cf.patch /var/www/html/postfix/mysql_virtual_domains.cf /var/www/html/postfix/mysql_virtual_mailbox_maps.cf /var/www/html/postfix/mysql_virtual_alias_maps.cf; do
    [ ! -f "$f" ] && add_error "Missing Postfix file: $f"
done
[ -f /etc/postfix/main.cf ] && cp /etc/postfix/main.cf /etc/postfix/main.cf.bak
dos2unix /var/www/html/postfix/main.cf.patch 2>/dev/null || true
cat /var/www/html/postfix/main.cf.patch >> /etc/postfix/main.cf
cp /var/www/html/postfix/mysql_virtual_*.cf /etc/postfix/
DB_PASS_ESC=$(printf '%s\n' "$DB_PASS" | sed -e 's/[\|&]/\\&/g')
for f in /etc/postfix/mysql_virtual_*.cf; do
    sed -i "s|password = .*|password = ${DB_PASS_ESC}|" "$f"
    postmap "$f" || add_error "postmap $f failed"
done

if ! getent passwd vmail &>/dev/null; then
    case "$OS_ID" in
        alpine) adduser -D -h /var/mail/vhosts -s /sbin/nologin vmail ;;
        *) useradd -m -d /var/mail/vhosts -s /bin/false vmail ;;
    esac
fi
mkdir -p /var/mail/vhosts
chown -R vmail:vmail /var/mail/vhosts 2>/dev/null || add_error "vmail ownership failed"
chmod -R 770 /var/mail/vhosts
systemctl restart ${POSTFIX_SERVICE} 2>/dev/null || service ${POSTFIX_SERVICE} restart 2>/dev/null || add_error "Postfix restart failed"

# ---------- 6. Dovecot ----------
echo -e "\n${GREEN}[6/9] Configuring Dovecot...${NC}"
mkdir -p /etc/dovecot/conf.d
for f in /var/www/html/dovecot/dovecot.conf.patch /var/www/html/dovecot/conf.d/10-auth.conf /var/www/html/dovecot/conf.d/auth-sql.conf.ext /var/www/html/dovecot/dovecot-sql.conf.ext; do
    [ ! -f "$f" ] && add_error "Missing Dovecot file: $f"
done

if [ -d /etc/dovecot/conf.d ]; then
    cp /var/www/html/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/ 2>/dev/null || add_error "10-auth.conf copy failed"
    cp /var/www/html/dovecot/conf.d/auth-sql.conf.ext /etc/dovecot/conf.d/ 2>/dev/null || add_error "auth-sql.conf.ext copy failed"
else
    cp /var/www/html/dovecot/conf.d/10-auth.conf /etc/dovecot/ 2>/dev/null || add_error "10-auth.conf copy failed"
    cp /var/www/html/dovecot/conf.d/auth-sql.conf.ext /etc/dovecot/ 2>/dev/null || add_error "auth-sql.conf.ext copy failed"
fi
cp /var/www/html/dovecot/dovecot.conf.patch /etc/dovecot/ 2>/dev/null || add_error "dovecot.conf.patch copy failed"
cp /var/www/html/dovecot/dovecot-sql.conf.ext /etc/dovecot/ 2>/dev/null || add_error "dovecot-sql.conf.ext copy failed"
dos2unix /etc/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/auth-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext 2>/dev/null || true
dos2unix /etc/dovecot/10-auth.conf /etc/dovecot/auth-sql.conf.ext 2>/dev/null || true
sed -i "s|connect = .*|connect = host=127.0.0.1 dbname=${DB_NAME} user=${DB_USER} password=${DB_PASS_ESC}|" /etc/dovecot/dovecot-sql.conf.ext
chown -R vmail:dovecot /etc/dovecot 2>/dev/null || true
chmod -R o-rwx /etc/dovecot 2>/dev/null || true
systemctl restart ${DOVECOT_SERVICE} 2>/dev/null || service ${DOVECOT_SERVICE} restart 2>/dev/null || add_error "Dovecot restart failed"

# ---------- 7. Apache / httpd ----------
echo -e "\n${GREEN}[7/9] Configuring Apache...${NC}"
if command -v a2enmod &>/dev/null; then a2enmod rewrite || add_error "mod_rewrite failed"; fi
mkdir -p ${APACHE_CONF_DIR}
if [[ "$APACHE_SERVICE" == "apache2" ]]; then
    cat > ${APACHE_CONF_DIR}/000-bmta.conf <<'VHOST'
<VirtualHost *:80>
    DocumentRoot /var/www/html/public
    <Directory /var/www/html/public>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog /var/log/apache2/bmta_error.log
    CustomLog /var/log/apache2/bmta_access.log combined
</VirtualHost>
VHOST
    [ -d "$APACHE_SITES_DIR" ] && ln -sf ${APACHE_CONF_DIR}/000-bmta.conf ${APACHE_SITES_DIR}/ 2>/dev/null || add_error "Apache symlink failed"
else
    cat > ${APACHE_CONF_DIR}/bmta.conf <<'VHOST'
<VirtualHost *:80>
    DocumentRoot /var/www/html/public
    <Directory /var/www/html/public>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog logs/bmta_error_log
    CustomLog logs/bmta_access_log combined
</VirtualHost>
VHOST
fi
chown -R ${APACHE_USER}:${APACHE_GROUP} /var/www/html/ 2>/dev/null || add_error "Apache ownership failed"
mkdir -p /var/www/html/public/uploads
chmod 775 /var/www/html/public/uploads
chcon -R -t httpd_sys_rw_content_t /var/www/html/public/uploads 2>/dev/null || true
systemctl restart ${APACHE_SERVICE} 2>/dev/null || service ${APACHE_SERVICE} restart 2>/dev/null || add_error "Apache restart failed"

# ---------- 8. Firewall ----------
echo -e "\n${GREEN}[8/9] Configuring firewall...${NC}"
FW_PORTS=(22 21 25 80 443 587 993 3306 8080)
if command -v firewall-cmd &>/dev/null; then
    systemctl enable --now firewalld 2>/dev/null || true
    for p in "${FW_PORTS[@]}"; do firewall-cmd --permanent --add-port=${p}/tcp 2>/dev/null || true; done
    firewall-cmd --reload 2>/dev/null || true
    echo "    firewalld ports added."
elif command -v ufw &>/dev/null; then
    ufw --force enable 2>/dev/null || true
    for p in "${FW_PORTS[@]}"; do ufw allow ${p}/tcp 2>/dev/null; done
    echo "    ufw ports added."
elif command -v iptables &>/dev/null; then
    for p in "${FW_PORTS[@]}"; do iptables -I INPUT -p tcp --dport $p -j ACCEPT 2>/dev/null; done
    echo "    iptables rules added (non‑persistent)."
else
    if command -v apt &>/dev/null; then
        DEBIAN_FRONTEND=noninteractive apt install -y ufw && ufw --force enable && for p in "${FW_PORTS[@]}"; do ufw allow ${p}/tcp; done
    elif command -v dnf &>/dev/null; then
        dnf install -y firewalld && systemctl enable --now firewalld && for p in "${FW_PORTS[@]}"; do firewall-cmd --permanent --add-port=${p}/tcp; done && firewall-cmd --reload
    elif command -v yum &>/dev/null; then
        yum install -y firewalld && systemctl enable --now firewalld && for p in "${FW_PORTS[@]}"; do firewall-cmd --permanent --add-port=${p}/tcp; done && firewall-cmd --reload
    else
        add_error "No firewall installed; please open ports: ${FW_PORTS[*]}"
    fi
fi

# ---------- 9. Cron ----------
echo -e "\n${GREEN}[9/9] Installing cron jobs...${NC}"
mkdir -p /var/log/bmta
(crontab -l 2>/dev/null | grep -v "process_queue\|process_bounces"; 
 echo "* * * * * /usr/bin/php /var/www/html/cron/process_queue.php >> /var/log/bmta/queue.log 2>&1";
 echo "*/5 * * * * /usr/bin/php /var/www/html/cron/process_bounces.php >> /var/log/bmta/bounces.log 2>&1") | crontab - || add_error "Cron install failed"

# ---------- Final report ----------
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  bMTA installation completed!            ${NC}"
echo -e "${GREEN}========================================${NC}"
if [ ${#ERRORS[@]} -eq 0 ]; then
    echo -e "${GREEN}No errors detected.${NC}"
else
    echo -e "${RED}The following errors occurred:${NC}"
    for err in "${ERRORS[@]}"; do echo -e "  - ${RED}$err${NC}"; done
    echo -e "\nSome parts may not work. Please fix the issues above."
fi
echo ""
echo -e "Open ${YELLOW}${APP_URL}${NC} to create the admin account."
echo -e "Database: ${DB_NAME} | User: ${DB_USER} | Pass: ${DB_PASS}"
echo -e "Ports opened: ${FW_PORTS[*]}"
echo -e "${RED}Set DNS records as shown in the domain manager.${NC}"
