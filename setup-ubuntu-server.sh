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

read -p "Do you want to create a new user? (y/n): " create_user
if [[ $create_user =~ ^[Yy]$ ]]; then
    read -p "Enter new username: " username
    adduser $username
    usermod -aG sudo $username
    sudo passwd $username
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

echo "Configuring advanced security..."
apt install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban


apt install -y clamav rkhunter
freshclam
echo "Running initial security scans (backgrounded)..."
clamscan -r / --exclude-dir="^/sys" > /var/log/clamav_initial.log 2>&1 &
rkhunter --check --sk > /var/log/rkhunter_initial.log 2>&1 &

apt install -y unattended-upgrades
dpkg-reconfigure -p low -f noninteractive unattended-upgrades

apt install -y apparmor apparmor-utils
systemctl enable apparmor
systemctl start apparmor

apt install -y auditd
systemctl enable auditd
systemctl start auditd

apt install -y aide
aideinit --force

echo "Installing monitoring tools..."
bash <(curl -Ss https://my-netdata.io/kickstart.sh) --non-interactive

apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update
apt install -y caddy

apt install -y certbot python3-certbot-nginx

echo -e "\nInitial setup complete!"
echo "Critical security services installed:"
echo -e "- Fail2Ban intrusion prevention\n- ClamAV antivirus\n- RKHunter rootkit detection"
echo -e "- AppArmor MAC\n- Auditd logging\n- AIDE file integrity monitoring"

if [ -n "$username" ]; then
    echo -e "\nNext steps:"
    echo "1. Log in with new user: $username"
    echo "2. Configure Caddy: /etc/caddy/Caddyfile"
    echo "3. Review security scans:"
    echo "   - ClamAV: /var/log/clamav_initial.log"
    echo "   - RKHunter: /var/log/rkhunter_initial.log"
else
    echo -e "\nNo new user created - existing accounts remain unchanged"
fi
