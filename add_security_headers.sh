#!/bin/bash

# Variables
VHOST_CONFIG_PATH="/usr/local/lsws/conf/vhosts/wordpress/vhconf.conf"  # Correct vhost path for WordPress
LOG_FILE="/var/log/add_security_headers.log"

# Logging function
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Start log
log_message "Starting the process to add security headers and configure firewall."

# Backup the original virtual host config
if cp "$VHOST_CONFIG_PATH" "$VHOST_CONFIG_PATH.bak"; then
  log_message "Backup of $VHOST_CONFIG_PATH created successfully."
else
  log_message "Failed to create a backup of $VHOST_CONFIG_PATH."
  exit 1
fi

# Check if the `/` context exists and add it if not
if ! grep -q "context / {" "$VHOST_CONFIG_PATH"; then
  echo -e "\ncontext / {\n  location \$DOC_ROOT/\n  allowBrowse 1\n}\n" >> "$VHOST_CONFIG_PATH"
  log_message "The `/` context did not exist, so it was created."
fi

# Insert security headers using the `note` block in the `/` context
if ! grep -q "note                    <<<END_note" "$VHOST_CONFIG_PATH"; then
  # Find the context for `/` and add the `note` block with security headers
  sed -i '/context \/ {/a \  note                    <<<END_note\nStrict-Transport-Security: max-age=31536000; includeSubDomains\nContent-Security-Policy \"upgrade-insecure-requests;connect-src *\"\nReferrer-Policy strict-origin-when-cross-origin\nX-Frame-Options: SAMEORIGIN\nX-Content-Type-Options: nosniff\nX-XSS-Protection 1;mode=block\nPermissions-Policy: geolocation=(self \"\")\n  END_note' "$VHOST_CONFIG_PATH"
  
  if [ $? -eq 0 ]; then
    log_message "Security headers added successfully using the `note` block to the / context in $VHOST_CONFIG_PATH."
  else
    log_message "Failed to add security headers using the `note` block to $VHOST_CONFIG_PATH."
    exit 1
  fi
else
  log_message "Security headers (note block) already exist in $VHOST_CONFIG_PATH. No changes made."
fi

# Graceful restart of OpenLiteSpeed
if /usr/local/lsws/bin/lswsctrl restart; then
  log_message "OpenLiteSpeed restarted successfully."
else
  log_message "Failed to restart OpenLiteSpeed."
  exit 1
fi

# Use ufw to open port 7080
if command -v ufw >/dev/null 2>&1; then
  if ufw allow 7080/tcp; then
    log_message "Port 7080 opened using ufw."
  else
    log_message "Failed to open port 7080 using ufw."
    exit 1
  fi
else
  log_message "ufw not found, skipping firewall configuration."
fi

log_message "OpenLiteSpeed security headers and firewall configuration completed successfully."

# Display log file location
echo "All logs have been saved to $LOG_FILE"
