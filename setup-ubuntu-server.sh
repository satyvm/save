#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit
fi

echo "Updating and upgrading system..."
apt update && apt upgrade -y

echo "Setting timezone to IST..."
timedatectl set-timezone Asia/Kolkata
timedatectl set-ntp true
timedatectl

# User creation prompt
read -p "Do you want to create a new user? (y/n): " create_user
if [[ $create_user =~ ^[Yy]$ ]]; then
    read -p "Enter new username: " username
    adduser $username
    usermod -aG sudo $username
    echo "Disabling root SSH login..."
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    systemctl restart sshd
fi

echo "Configuring UFW firewall..."
apt install ufw -y
ufw allow OpenSSH
ufw enable

echo "Installing essential tools..."
apt install -y curl wget git vim htop iotop iftop tmux

# Final message based on user creation
echo -e "\nInitial setup complete!"
if [ -n "$username" ]; then
    echo "You can now log in with the new user: $username"
else
    echo "No new user was created - existing user accounts remain unchanged"
fi
