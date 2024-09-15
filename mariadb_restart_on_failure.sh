#!/bin/bash

# Define the MariaDB service file path
mariadb_service_file="/lib/systemd/system/mariadb.service"

# Function to add restart settings to MariaDB service file
configure_mariadb_service() {
    echo "Configuring MariaDB service for auto-restart on failure..."

    # Check if the necessary settings already exist in the file
    if grep -q "Restart=on-failure" "$mariadb_service_file"; then
        echo "Restart settings already exist. Skipping modification."
    else
        # Add the Restart settings after "RestartSec=5s" and before "UMask=007"
        sudo sed -i '/RestartSec=5s/a\\n# Restart on failure to avoid any issues\nRestart=on-failure\nRestartSec=5s' "$mariadb_service_file"
        echo "Restart settings added to the MariaDB service."
    fi
}

# Function to reload systemd daemon and restart MariaDB
reload_and_restart_mariadb() {
    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload

    echo "Restarting MariaDB service..."
    sudo systemctl restart mariadb

    # Verify if the settings were applied
    echo "Checking MariaDB restart settings:"
    systemctl show mariadb | grep Restart=
}

# Main function
main() {
    # Step 1: Configure MariaDB service for auto-restart on failure
    configure_mariadb_service

    # Step 2: Reload systemd daemon and restart MariaDB
    reload_and_restart_mariadb

    echo "MariaDB service configuration completed successfully."
}

# Execute the main function
main
