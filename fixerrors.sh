#!/bin/bash

echo "Now we will Fix the errors"

#The OPcache interned strings buffer is nearly full. To assure that repeating strings can be effectively cached, it is recommended to apply opcache.interned_strings_buffer to your PHP configuration with a value higher than 8.
# Specify the Nextcloud installation directory
nextcloud_dir="/var/www/html/nextcloud"

# Add the opcache.interned_strings_buffer directive to .htaccess
echo "php_value opcache.interned_strings_buffer 64" >> "${nextcloud_dir}/.htaccess"

#------------------------------------------------------------------------------------------------------------

#The PHP module "imagick" is not enabled although the theming app is. For favicon generation to work correctly, you need to install and enable this module.
# Specify the path to the .htaccess file
HTACCESS_FILE="/var/www/html/nextcloud/.htaccess"

# Add imagick directives to .htaccess
cat << EOF >> "$HTACCESS_FILE"

<IfModule mod_rewrite.c>
    RewriteEngine on
    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]

    <IfModule mod_env.c>
        SetEnv MAGICK_HOME "/usr/"
        SetEnv MagickConfigPath "/etc/ImageMagick-6/"
    </IfModule>
</IfModule>
EOF

# Change ownership and permissions of the .htaccess file
chown www-data:www-data "$HTACCESS_FILE"
chmod 644 "$HTACCESS_FILE"

#------------------------------------------------------------------------------------------------------------

#Module php-imagick in this instance has no SVG support. For better compatibility it is recommended to install it.

sudo apt-get install libmagickcore-6.q16-6-extra libmagickwand-6.q16-6 librsvg2-bin php-imagick -y



# Define the path to Nextcloud's .htaccess file
htaccess_file="/var/www/html/nextcloud/.htaccess"

# Add the directives to the .htaccess file
cat << EOF >> "$htaccess_file"
<IfModule mod_rewrite.c>
    RewriteEngine On
    SetEnv MAGICKCORE_ALLOW_OPENCL 0
    SetEnv MAGICKCODERMODULE_PATH "/usr/lib/x86_64-linux-gnu/ImageMagick-6.9.10/modules-Q16/coders"
</IfModule>
EOF

echo "Directives added to $htaccess_file"

#------------------------------------------------------------------------------------------------------------

# PHP modules "gmp" and/or "bcmath" are not enabled on your server. These modules are required if you use WebAuthn passwordless authentication.

sudo apt-get install php-gmp php-bcmath -y 

htaccess_path="/var/www/html/nextcloud/.htaccess"

if [ -f "$htaccess_path" ]; then
  if grep -q "php_flag gmp.enable 1" "$htaccess_path"; then
    echo "gmp.enable already enabled in $htaccess_path"
  else
    echo "php_flag gmp.enable 1" >> "$htaccess_path"
    echo "Added gmp.enable to $htaccess_path"
  fi

  if grep -q "php_flag bcmath.enable 1" "$htaccess_path"; then
    echo "bcmath.enable already enabled in $htaccess_path"
  else
    echo "php_flag bcmath.enable 1" >> "$htaccess_path"
    echo "Added bcmath.enable to $htaccess_path"
  fi
else
  echo "$htaccess_path does not exist"
fi

#------------------------------------------------------------------------------------------------------------



#No memory cache has been configured. To enhance performance, please configure a memcache, if available
#!/bin/bash

# Step 1: Install APCu and Redis
sudo apt install php-apcu redis-server php-redis -y
sudo service apache2 restart

# Step 2: Edit the Redis configuration file
sudo sed -i 's/^port 6379$/port 0/' /etc/redis/redis.conf
sudo sed -i '/^# unixsocket .*$/s/^# //' /etc/redis/redis.conf
sudo sed -i 's/^unixsocketperm 700$/unixsocketperm 770/' /etc/redis/redis.conf

# Step 3: Add the Redis user to the www-data group
sudo usermod -a -G redis www-data

# Step 4: Restart Apache
sudo service apache2 restart

# Step 5: Start Redis server
sudo service redis-server start


nextcloud_path="/var/www/html/nextcloud"
config_file="$nextcloud_path/config/config.php"

# Check if the config.php file exists
if [[ ! -f "$config_file" ]]; then
  echo "config.php file not found. Please provide the correct path to your Nextcloud installation."
  exit 1
fi

# Step 6: Add the caching configuration to the Nextcloud config file

# Check if the lines already exist in the config.php file
if grep -Fxq "<?php" "$config_file" && grep -Fxq "\$CONFIG = array (" "$config_file"; then
  # Add the new line to the config.php file
sudo sed -i "/'memcache.local' =>/a \ \ 'distributed' => '\\\\OC\\\\Memcache\\\\Redis'," /var/www/html/nextcloud/config/config.php
sudo sed -i "/'distributed' =>/a \ \ 'memcache.locking' => '\\\\OC\\\\Memcache\\\\Redis'," /var/www/html/nextcloud/config/config.php
sudo sed -i "/'memcache.locking' =>/a \ \ 'filelocking.enabled' => 'true'," /var/www/html/nextcloud/config/config.php
sudo sed -i "/'filelocking.enabled' =>/a \ \ 'redis' => \\\n \\\t array \\\n \\\t (\n \\\t 'host' => '\\\\/var\\\\/run\\\\/redis\\\\/redis-server.sock',\n \\\t 'port' => 0,\n \\\t 'timeout' => 0.0,\n \\\t )," /var/www/html/nextcloud/config/config.php
else
  echo "Could not find the specified lines '<?php' and '\$CONFIG = array (' in the config.php file."
  exit 1
fi


# Step 7: Enable Redis to start on boot
sudo systemctl enable redis-server

# Step 8: Enable .htaccess
sudo sed -i 's/^<Directory \/var\/www\/>/&\n\tAllowOverride All/' /etc/apache2/apache2.conf
sudo service apache2 restart

# Step 9: Change memory limit size
# Define the memory limit value to add
MEMORY_LIMIT="8192M"

# Set the path to the Nextcloud installation directory
NEXTCLOUD_DIR="/var/www/html/nextcloud"

# Set the path to the .htaccess file
HTACCESS_FILE="${NEXTCLOUD_DIR}/.htaccess"

# Check if the .htaccess file exists
if [ ! -f "${HTACCESS_FILE}" ]; then
    echo "The .htaccess file does not exist in the Nextcloud installation directory. Aborting."
    exit 1
fi

# Check if the memory limit value is already set in the .htaccess file
if grep -q "^php_value memory_limit" "${HTACCESS_FILE}"; then
    echo "The memory limit value is already set in the .htaccess file. Aborting."
    exit 1
fi

# Add the memory limit value to the .htaccess file
echo "php_value memory_limit ${MEMORY_LIMIT}" >> "${HTACCESS_FILE}"

# Check if the memory limit value was successfully added to the .htaccess file
if grep -q "^php_value memory_limit ${MEMORY_LIMIT}$" "${HTACCESS_FILE}"; then
    echo "The memory limit value was successfully added to the .htaccess file."
else
    echo "Failed to add the memory limit value to the .htaccess file. Aborting."
    exit 1
fi

# Restart Apache to apply the changes
systemctl restart apache2


# Step 10: Install recommended PHP modules
sudo apt install php-curl php-gd php-imagick php-intl php-mbstring php-xml php-zip -y
sudo service apache2 restart



#------------------------------------------------------------------------------------------------------------


#Your installation has no default phone region set. This is required to validate phone numbers in the profile settings without a country code. To allow numbers without a country code, please add "default_phone_region" with the respective ISO 3166-1 code ↗️ of the region to your config file.

# Specify the path to your Nextcloud installation and config.php file
nextcloud_path="/var/www/html/nextcloud"
config_file="$nextcloud_path/config/config.php"

# Check if the config.php file exists
if [[ ! -f "$config_file" ]]; then
  echo "config.php file not found. Please provide the correct path to your Nextcloud installation."
  exit 1
fi

# Check if the lines already exist in the config.php file
if grep -Fxq "<?php" "$config_file" && grep -Fxq "\$CONFIG = array (" "$config_file"; then
  # Add the new line to the config.php file
  sed -i "/\$CONFIG = array (/a \\\t'default_phone_region' => 'PH'," "$config_file"
  echo "Line 'default_phone_region' => 'PH' added successfully to config.php."
else
  echo "Could not find the specified lines '<?php' and '\$CONFIG = array (' in the config.php file."
  exit 1
fi

#------------------------------------------------------------------------------------------------------------


#The reverse proxy header configuration is incorrect, or you are accessing Nextcloud from a trusted proxy. If not, this is a security issue and can allow an attacker to spoof their IP address as visible to the Nextcloud. Further information can be found in the documentation ↗️.

nextcloud_path="/var/www/html/nextcloud"
config_file="$nextcloud_path/config/config.php"

#Specify your Trusted proxy Here
trusted_proxy="stflst-nextcloud.sfm.edu.ph" 

# Check if the config.php file exists
if [[ ! -f "$config_file" ]]; then
  echo "config.php file not found. Please provide the correct path to your Nextcloud installation."
  exit 1
fi

# Check if the lines already exist in the config.php file
if grep -Fxq "<?php" "$config_file" && grep -Fxq "\$CONFIG = array (" "$config_file"; then
  # Add the new lines to the config.php file
  sed -i "/\$CONFIG = array (/a \\\t'trusted_proxies' => array (\\n\\t\\t0 => '$trusted_proxy',\\n\\t)," "$config_file"
  echo "Lines 'trusted_proxies' added successfully to config.php."
else
  echo "Could not find the specified lines '<?php' and '\$CONFIG = array (' in the config.php file."
  exit 1
fi



#------------------------------------------------------------------------------------------------------------



#The "Strict-Transport-Security" HTTP header is not set to at least "15552000" seconds. For enhanced security, it is recommended to enable HSTS as described in the security tips ↗️.

#!/bin/bash

config_file="/etc/apache2/sites-available/nextcloud.conf"
header_line="Header always set Strict-Transport-Security \"max-age=15552000; includeSubDomains; preload\""

# Check if the config file exists
if [ -f "$config_file" ]; then
  # Check if the header already exists in the config file
  if grep -q "$header_line" "$config_file"; then
    echo "Header already exists in $config_file. No changes needed."
  else
    # Add the header to the config file
    sudo sed -i "1s/^/$header_line\n\n/" "$config_file"
    echo "Header added to $config_file."
  fi
else
  echo "$config_file not found. Please make sure the file exists."
fi



