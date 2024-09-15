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
sudo systemctl restart vsftpd
echo "vsftpd configuration updated and service restarted."

# 4. Generate random username and password for the FTP user
ftp_user="ftpuser_$(openssl rand -hex 3)"
ftp_password=$(generate_password)

echo "Creating FTP user..."
sudo adduser --disabled-password --gecos "" $ftp_user
echo "$ftp_user:$ftp_password" | sudo chpasswd
echo "User $ftp_user created with a random password."

# 5. Add user to the www-data group and set permissions
echo "Adding user to www-data group and setting permissions..."
sudo usermod -aG www-data $ftp_user
sudo chmod -R g+w /var/www/html/
echo "Permissions set for /var/www/html."

# 6. Firewall Configuration
echo "Configuring the firewall for FTP traffic..."
sudo ufw allow 20/tcp
sudo ufw allow 21/tcp
sudo ufw allow OpenSSH
sudo ufw enable
echo "Firewall configuration complete."

# 7. Display FTP details
ftp_server=$(hostname -I | awk '{print $1}')
echo "-------------------------------------"
echo "SFTP setup completed!"
echo "Server: $ftp_server"
echo "Username: $ftp_user"
echo "Password: $ftp_password"
echo "Port: 22 (SFTP)"
echo "-------------------------------------"

