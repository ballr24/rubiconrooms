#!/bin/bash

# Function to generate a random password
generate_password() {
    echo $(openssl rand -base64 12)
}

# 1. Installation
echo "Installing vsftpd..."
sudo apt-get update
sudo apt-get install vsftpd -y
echo "vsftpd installed successfully."

# 2. Backup Original Configuration
echo "Backing up the original configuration file..."
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.orig
echo "Backup completed."

# 3. Configuring vsftpd
echo "Configuring vsftpd..."
sudo sed -i 's/anonymous_enable=YES/anonymous_enable=NO/' /etc/vsftpd.conf
sudo sed -i 's/#local_enable=YES/local_enable=YES/' /etc/vsftpd.conf
sudo sed -i 's/#write_enable=YES/write_enable=YES/' /etc/vsftpd.conf

# Restart vsftpd to apply configuration
sudo systemctl restart vsftpd
echo "vsftpd configuration updated and service restarted."

# 4. Generate random username and password for the FTP user
ftp_user="ftpuser_$(openssl rand -hex 3)"
ftp_password=$(generate_password)

echo "Creating FTP user..."
sudo adduser --disabled-password --gecos "" $ftp_user
echo "$ftp_user:$ftp_password" | sudo chpasswd
echo "User $ftp_user created with a random password."

# 5. Set /var/www/html as the user's home directory
echo "Setting /var/www/html as the home directory for $ftp_user..."
sudo usermod -d /var/www/html $ftp_user
sudo chown -R $ftp_user:www-data /var/www/html
echo "Home directory set to /var/www/html for $ftp_user."

# 6. Add user to www-data group and set permissions
echo "Adding user to www-data group and setting permissions..."
sudo usermod -aG www-data $ftp_user
sudo chmod -R g+w /var/www/html/
echo "Permissions set for /var/www/html."

# 7. Firewall Configuration
echo "Configuring the firewall for FTP traffic..."
sudo ufw allow 20/tcp
sudo ufw allow 21/tcp
sudo ufw allow OpenSSH
sudo ufw enable
echo "Firewall configuration complete."

# 8. Display FTP details
ftp_server=$(hostname -I | awk '{print $1}')
echo "-------------------------------------"
echo "SFTP setup completed!"
echo "Server: $ftp_server"
echo "Username: $ftp_user"
echo "Password: $ftp_password"
echo "Port: 22 (SFTP)"
echo "-------------------------------------"
