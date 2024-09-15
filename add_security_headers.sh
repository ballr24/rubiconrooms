#!/bin/bash

# Variables
VHOST_CONFIG_PATH="/usr/local/lsws/conf/vhosts/wordpress/vhconf.conf"  # Correct vhost path for WordPress
FIREWALL_CMD=$(command -v firewall-cmd || echo "")

# Backup the original virtual host config
cp "$VHOST_CONFIG_PATH" "$VHOST_CONFIG_PATH.bak"

# Insert security headers in the desired format if they are not already present
if ! grep -q "extraHeaders" "$VHOST_CONFIG_PATH"; then
  sed -i '/context \//a \  extraHeaders            <<<END_extraHeaders\nStrict-Transport-Security: max-age=31536000; includeSubDomains\nContent-Security-Policy \"upgrade-insecure-requests;connect-src *\"\nReferrer-Policy strict-origin-when-cross-origin\nX-Frame-Options: SAMEORIGIN\nX-Content-Type-Options: nosniff\nX-XSS-Protection 1;mode=block\nPermissions-Policy: geolocation=(self \"\")\n  END_extraHeaders' "$VHOST_CONFIG_PATH"
else
  echo "Security headers already exist in the configuration."
fi

# Graceful restart of OpenLiteSpeed
/usr/local/lsws/bin/lswsctrl restart

# Add port 7080 to the firewall if firewall-cmd exists
if [[ -n "$FIREWALL_CMD" ]]; then
  $FIREWALL_CMD --add-port=7080/tcp --permanent
  $FIREWALL_CMD --reload
  echo "Port 7080 added to the firewall."
else
  echo "firewall-cmd not found, skipping firewall configuration."
fi

echo "OpenLiteSpeed security headers and firewall configuration updated."
