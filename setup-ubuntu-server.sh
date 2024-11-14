#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit
fi

# Update and upgrade the system
echo "Updating and upgrading system..."
apt update && apt upgrade -y

# Set up a new user
read -p "Enter new username: " username
adduser $username
usermod -aG sudo $username

# Disable root SSH login
echo "Disabling root SSH login..."
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd

# Set up UFW firewall
echo "Configuring UFW firewall..."
apt install ufw -y
ufw allow OpenSSH
ufw enable

# Install essential tools
echo "Installing essential tools..."
apt install -y curl wget git vim htop iotop iftop tmux

echo "Initial setup complete!"
echo "Log in with the new user: $username"
