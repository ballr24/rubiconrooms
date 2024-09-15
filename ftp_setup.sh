#!/bin/bash

# Enable debug mode and log all output to a file
log_file="/tmp/ftp_setup.log"
exec > >(tee -a "$log_file") 2>&1
set -e
trap 'echo "Error occurred at line $LINENO"; exit 1' ERR

# Function to generate a random password
generate_password() {
    echo $(openssl rand -base64 12)
}

# 1. Prompt for email address
read -p "Enter your email address to send the server details: " email_address

# 2. Install mailutils if not already installed
echo "Installing mailutils..."
sudo apt-get install -y mailutils
echo "mailutils installed successfully."

# 3. Installation of vsftpd
echo "Installing vsftpd..."
sudo apt-get update
sudo apt-get install vsftpd -y
echo "vsftpd installed successfully."

# 4. Backup Original Configuration
echo "Backing up the original configuration file..."
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.orig
echo "Backup completed."

# 5. Configuring vsftpd
echo "Configuring vsftpd..."
sudo sed -i 's/anonymous_enable=YES/anonymous_enable=NO/' /etc/vsftpd.conf
sudo sed -i 's/#local_enable=YES/local_enable=YES/' /etc/vsftpd.conf
sudo sed -i 's/#write_enable=YES/write_enable=YES/' /etc/vsftpd.conf
sudo systemctl restart vsftpd
echo "vsftpd configuration updated and service restarted."

# 6. Generate random username and password for the FTP user
ftp_user="ftpuser_$(openssl rand -hex 3)"
ftp_password=$(generate_password)

echo "Creating FTP user..."
sudo adduser --disabled-password --gecos "" $ftp_user
echo "$ftp_user:$ftp_password" | sudo chpasswd
echo "User $ftp_user created with a random password."

# 7. Set /var/www/html as the user's home directory
echo "Setting /var/www/html as the home directory for $ftp_user..."
sudo usermod -d /var/www/html $ftp_user
sudo chown -R $ftp_user:www-data /var/www/html
echo "Home directory set to /var/www/html for $ftp_user."

# 8. Add user to www-data group and set permissions
echo "Adding user to www-data group and setting permissions..."
sudo usermod -aG www-data $ftp_user
sudo chmod -R g+w /var/www/html/
echo "Permissions set for /var/www/html."

# 9. Firewall Configuration
echo "Configuring the firewall for FTP traffic..."
sudo ufw allow 20/tcp
sudo ufw allow 21/tcp
sudo ufw allow OpenSSH
sudo ufw enable
echo "Firewall configuration complete."

# 10. Capture server details
ftp_server=$(hostname -I | awk '{print $1}')
ftp_port="22"
subject="SFTP Server Details"
message=$(cat <<- EOM
Hello,

Your SFTP server has been set up successfully.

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

# 11. Send email with server details and log
{
    echo "$message"
    echo -e "\n\nDebug log:"
    cat "$log_file"
} | mail -s "$subject" $email_address

# 12. Display server details in the terminal
echo "-------------------------------------"
echo "SFTP setup completed!"
echo "Server: $ftp_server"
echo "Username: $ftp_user"
echo "Password: $ftp_password"
echo "Port: $ftp_port (SFTP)"
echo "Details and log sent to $email_address"
echo "-------------------------------------"
