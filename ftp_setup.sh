#!/bin/bash

# Enable debug mode and log all output to a file
log_file="/tmp/ftp_setup.log"
exec > >(tee -a "$log_file") 2>&1
set -e
trap 'echo "Error occurred at line $LINENO. Retrying..."; retry_script' ERR

# Retry mechanism
retry_count=0
max_retries=3

retry_script() {
    if (( retry_count < max_retries )); then
        ((retry_count++))
        echo "Retrying... Attempt #$retry_count"
        main_setup
    else
        echo "Max retries reached. Exiting."
        exit 1
    fi
}

# Function to generate a random password
generate_password() {
    echo $(openssl rand -base64 12)
}

# Function to confirm input
confirm_input() {
    local prompt="$1"
    local value="$2"
    read -p "$prompt ($value)? [y/n]: " confirm
    case "$confirm" in
        [Yy]* ) return 0 ;;  # Confirmed
        [Nn]* ) return 1 ;;  # Not confirmed
        * ) echo "Please answer y or n."; confirm_input "$prompt" "$value" ;;
    esac
}

# Install mailutils without any prompts
install_mailutils() {
    if ! dpkg -s mailutils >/dev/null 2>&1; then
        echo "Installing mailutils..."
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mailutils
        echo "mailutils installed successfully."
    else
        echo "mailutils is already installed. Skipping."
    fi
}

# Main setup process
main_setup() {
    # 1. Prompt for email address and confirm
    while true; do
        read -p "Enter your email address to send the server details: " email_address
        if confirm_input "Is the email address correct" "$email_address"; then
            break
        fi
    done

    # 2. Prompt for domain name (without https or www) and confirm
    while true; do
        read -p "Enter the domain name (without https or www): " domain_name
        if confirm_input "Is the domain name correct" "$domain_name"; then
            break
        fi
    done

    # 3. Install mailutils without prompts
    install_mailutils

    # 4. Installation of vsftpd
    echo "Installing vsftpd..."
    sudo apt-get update
    sudo apt-get install -y vsftpd || echo "vsftpd is already installed."
    echo "vsftpd installed successfully."

    # 5. Backup Original Configuration if not already backed up
    if [ ! -f /etc/vsftpd.conf.orig ]; then
        echo "Backing up the original configuration file..."
        sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.orig
        echo "Backup completed."
    else
        echo "Backup already exists. Skipping."
    fi

    # 6. Configuring vsftpd
    echo "Configuring vsftpd..."
    sudo sed -i 's/anonymous_enable=YES/anonymous_enable=NO/' /etc/vsftpd.conf
    sudo sed -i 's/#local_enable=YES/local_enable=YES/' /etc/vsftpd.conf
    sudo sed -i 's/#write_enable=YES/write_enable=YES/' /etc/vsftpd.conf
    sudo systemctl restart vsftpd
    echo "vsftpd configuration updated and service restarted."

    # 7. Generate random username and password for the FTP user
    ftp_user="ftpuser_$(openssl rand -hex 3)"
    ftp_password=$(generate_password)

    # Create user only if it doesn't already exist
    if ! id -u "$ftp_user" >/dev/null 2>&1; then
        echo "Creating FTP user..."
        sudo adduser --disabled-password --gecos "" $ftp_user
        echo "$ftp_user:$ftp_password" | sudo chpasswd
        echo "User $ftp_user created."
    else
        echo "User $ftp_user already exists. Skipping user creation."
    fi

    # 8. Set /var/www/html as the user's home directory if not already set
    if [[ $(getent passwd "$ftp_user" | cut -d: -f6) != "/var/www/html" ]]; then
        echo "Setting /var/www/html as the home directory for $ftp_user..."
        sudo usermod -d /var/www/html $ftp_user
        sudo chown -R $ftp_user:www-data /var/www/html
        echo "Home directory set to /var/www/html for $ftp_user."
    else
        echo "Home directory is already set. Skipping."
    fi

    # 9. Add user to www-data group and set permissions if not already set
    if ! groups "$ftp_user" | grep -q www-data; then
        echo "Adding user to www-data group and setting permissions..."
        sudo usermod -aG www-data $ftp_user
        sudo chmod -R g+w /var/www/html/
        echo "Permissions set for /var/www/html."
    else
        echo "User already in www-data group. Skipping."
    fi

    # 10. Firewall Configuration if not already done
    if ! sudo ufw status | grep -q '20/tcp'; then
        echo "Configuring the firewall for FTP traffic..."
        sudo ufw allow 20/tcp
        sudo ufw allow 21/tcp
        sudo ufw allow OpenSSH
        yes | sudo ufw enable   # Automatically answer yes to the prompt
        echo "Firewall configuration complete."
    else
        echo "Firewall rules already set. Skipping."
    fi

    # 11. Check if the rubiconrooms directory exists and is non-empty
    if [ -d "rubiconrooms" ]; then
        if [ "$(ls -A rubiconrooms)" ]; then
            echo "Directory 'rubiconrooms' already exists and is not empty. Skipping cloning."
        else
            echo "Directory 'rubiconrooms' exists but is empty. Proceeding with cloning."
            git clone https://github.com/ballr24/rubiconrooms.git
        fi
    else
        echo "Directory 'rubiconrooms' does not exist. Proceeding with cloning."
        git clone https://github.com/ballr24/rubiconrooms.git
    fi

    # 12. Capture server details without logging sensitive info
    ftp_server=$(hostname -I | awk '{print $1}')
    ftp_port="22"
    subject="SFTP Server Details for $domain_name"
    message=$(cat <<- EOM
Hello,

Your SFTP server for $domain_name has been set up successfully.

Here are your login details:

Server: $ftp_server
Username: $ftp_user
Password: $ftp_password
Port: $ftp_port

Attached below is the debug log for the entire setup process.

Best regards,
Your server setup script
EOM
    )

    # 13. Send email with server details and log
    {
        echo "$message"
        echo -e "\n\nDebug log:"
        cat "$log_file"
    } | mail -s "$subject" $email_address

    # 14. Display server details in the terminal, mask sensitive info in the log
    echo "-------------------------------------"
    echo "SFTP setup completed!"
    echo "Server: $ftp_server"
    echo "Username: [REDACTED IN LOG]"
    echo "Password: [REDACTED IN LOG]"
    echo "Port: $ftp_port (SFTP)"
    echo "Details and log sent to $email_address"
    echo "-------------------------------------"
}

# Run the main setup
main_setup
