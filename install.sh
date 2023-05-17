#!/bin/bash

# Update system packages
sudo apt update
sudo apt upgrade -y

# Install dependencies
sudo apt install -y apache2 mariadb-server libapache2-mod-php openssl \
    php-imagick php-common php-curl php-gd php-imap \
    php-intl php-json php-ldap php-mbstring php-mysql \
    php-pgsql php-smbclient php-ssh2 php-sqlite3 php-xml php-zip \
    bzip2 curl gpg unzip wget

# Configure Apache
sudo systemctl enable apache2
sudo a2enmod rewrite
sudo systemctl restart apache2

# Configure MariaDB
sudo systemctl enable mariadb
sudo systemctl start mariadb

# Secure MariaDB installation
sudo mysql_secure_installation

# Create a database for Nextcloud
sudo mysql -u root -p <<EOF
CREATE DATABASE nextcloud;
CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

# Download and extract Nextcloud
sudo apt install unzip
sudo wget https://download.nextcloud.com/server/releases/latest.zip -O /tmp/latest.zip
sudo unzip /tmp/nextcloud.zip -d /var/www/html/
sudo chown -R www-data:www-data /var/www/html/nextcloud/

# Configure Nextcloud
sudo cp /var/www/html/nextcloud/config/config.sample.php /var/www/html/nextcloud/config/config.php
sudo sed -i "s|'passwordsalt' => '',|'passwordsalt' => '$(openssl rand -base64 30)',|" /var/www/html/nextcloud/config/config.php
sudo sed -i "s|'trusted_domains' => \[|'trusted_domains' => \['PLEASE_PUT_HERE_YOUR_DOMAIN_OR_IP',|" /var/www/html/nextcloud/config/config.php

# Set file permissions
sudo chmod 750 /var/www/html/nextcloud
sudo chmod -R 770 /var/www/html/nextcloud/data

# Configure Apache virtual host
sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/nextcloud.conf
sudo sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/nextcloud|' /etc/apache2/sites-available/nextcloud.conf
sudo a2ensite nextcloud.conf
sudo a2enmod headers
sudo a2enmod env
sudo a2enmod dir
sudo a2enmod mime
sudo systemctl restart apache2

# Open firewall ports
sudo ufw allow 80
sudo ufw allow 443

# Display Nextcloud installation information
echo "Nextcloud installation is complete."
echo "You can access your Nextcloud instance by visiting http://YOUR_DOMAIN_OR_IP/nextcloud"
echo "Follow the on-screen instructions to complete the setup."

# Cleanup
sudo rm /tmp/nextcloud.zip
