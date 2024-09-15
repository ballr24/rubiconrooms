#!/bin/bash

# Prompt for the domain name (without www or https)
read -p "Enter the domain name (without www or https): " DOMAIN_NAME

# Hardcoded path to the configuration file in the "wordpress" directory
VHOST_CONFIG_PATH="/usr/local/lsws/conf/vhosts/wordpress/vhconf.conf"
LOG_FILE="/var/log/vhconf_replace.log"

# Logging function
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Start log
log_message "Starting the process to replace vhconf.conf for domain: $DOMAIN_NAME."

# Backup the original virtual host config
if cp "$VHOST_CONFIG_PATH" "$VHOST_CONFIG_PATH.bak"; then
  log_message "Backup of $VHOST_CONFIG_PATH created successfully."
else
  log_message "Failed to create a backup of $VHOST_CONFIG_PATH."
  exit 1
fi

# Replace the content of vhconf.conf with the new configuration, using the domain name for SSL paths
cat > "$VHOST_CONFIG_PATH" <<EOL
docRoot                   /var/www/html/

index  {
  useServer               0
  indexFiles              index.php index.html
}

context /phpmyadmin/ {
  location                /var/www/phpmyadmin
  allowBrowse             1
  indexFiles              index.php

  accessControl  {
    allow                 *
  }

  rewrite  {
    enable                0
    inherit               0
  }
  addDefaultCharset       off
}

context / {
  location                \$DOC_ROOT/
  allowBrowse             1
  note                    <<<END_note
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy "upgrade-insecure-requests;connect-src *"
Referrer-Policy strict-origin-when-cross-origin
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection 1;mode=block
Permissions-Policy: geolocation=(self "")
  END_note

  rewrite  {

  }
  addDefaultCharset       off

  phpIniOverride  {

  }
}

rewrite  {
  enable                  1
  autoLoadHtaccess        1
}

vhssl  {
  keyFile                 /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem
  certFile                /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem
  certChain               1
}
EOL

# Log success
log_message "The configuration file for $DOMAIN_NAME has been replaced."

# Graceful restart of OpenLiteSpeed
if /usr/local/lsws/bin/lswsctrl restart; then
  log_message "OpenLiteSpeed restarted successfully."
else
  log_message "Failed to restart OpenLiteSpeed."
  exit 1
fi

# Display log file location
echo "All logs have been saved to $LOG_FILE"
