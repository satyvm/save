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

read -p "Enter new username: " username
adduser $username
usermod -aG sudo $username

echo "Disabling root SSH login..."
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd

echo "Configuring UFW firewall..."
apt install ufw -y
ufw allow OpenSSH
ufw enable

echo "Installing essential tools..."
apt install -y curl wget git vim htop iotop iftop tmux

echo "Initial setup complete!"
echo "Log in with the new user: $username"
