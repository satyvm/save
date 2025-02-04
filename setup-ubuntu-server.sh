#!/bin/bash
set -euo pipefail
trap 'echo "Error at line $LINENO"; exit 1' ERR

die() {
    echo -e "\n[ERROR] $1"
    exit 1
}

check_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

if [[ $EUID -ne 0 ]]; then
    die "This script must be run as root. Use sudo."
fi

echo "Starting system initialization..."

echo "Updating and upgrading system..."
{
    apt update -y &&
    apt upgrade -y &&
    apt autoremove -y
} || die "Failed to update system packages"

echo "Setting timezone to IST..."
timedatectl set-timezone Asia/Kolkata || die "Failed to set timezone"
timedatectl set-ntp true || die "Failed to enable NTP"
timedatectl status || die "Time synchronization failed"

create_sudo_user() {
    read -p "Do you want to create a new user? (y/n): " create_user
    if [[ $create_user =~ ^[Yy]$ ]]; then
        read -p "Enter new username: " username
        
        if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
            echo "Warning: Username doesn't match recommended POSIX pattern"
            read -p "Force creation anyway? (y/n): " force_create
            [[ "$force_create" =~ ^[Yy]$ ]] || die "User creation aborted"
        fi
        
        echo "Creating user: $username"
        if ! adduser --force-badname --gecos "" "$username"; then
            die "Failed to create user $username"
        fi

        if ! usermod -aG sudo "$username"; then
            die "Failed to add $username to sudo group"
        fi

        echo "Setting password for $username:"
        passwd "$username" || die "Password setup failed"

        echo "Securing SSH configuration..."
        sshd_config="/etc/ssh/sshd_config"
        cp "$sshd_config" "${sshd_config}.bak"
        sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' "$sshd_config"
        systemctl restart sshd || die "Failed to restart SSH service"
    fi
}
create_sudo_user

configure_firewall() {
    echo "Configuring UFW firewall..."
    check_command ufw || apt install ufw -y
    ufw allow OpenSSH || die "Failed to allow OpenSSH"
    ufw --force enable || die "Firewall activation failed"
}
configure_firewall

install_packages() {
    local packages=(
        curl wget git vim htop iotop iftop tmux
        fail2ban clamav rkhunter unattended-upgrades
        apparmor apparmor-utils auditd aide
        debian-keyring debian-archive-keyring apt-transport-https
    )
    
    echo "Installing system packages..."
    apt install -y "${packages[@]}" || die "Package installation failed"
}
install_packages

configure_security() {
    echo "Initializing security services..."
    systemctl enable --now fail2ban || die "Fail2Ban setup failed"
    freshclam || die "ClamAV update failed"
    aideinit --force || die "AIDE initialization failed"
    
    # Schedule security scans
    echo "Configuring daily security scans..."
    tee /etc/cron.daily/security-scans <<'EOL'
#!/bin/bash
clamscan -r / --exclude-dir="^/sys" -l /var/log/clamav_scan.log
rkhunter --check --sk
EOL
    chmod +x /etc/cron.daily/security-scans
}
configure_security

install_monitoring() {
    echo "Installing monitoring tools..."
    curl -Ss https://my-netdata.io/kickstart.sh | bash -s -- --non-interactive ||
        die "Netdata installation failed"

    echo "Installing Caddy..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' |
        gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg ||
        die "Caddy GPG key import failed"
    
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' |
        tee /etc/apt/sources.list.d/caddy-stable.list ||
        die "Caddy repository setup failed"
    
    apt update && apt install -y caddy ||
        die "Caddy installation failed"
}
install_monitoring

system_check() {
    echo "Running post-installation verification..."
    [ -d "/home/$username" ] && [ "$(id -u "$username")" ] ||
        echo "Warning: User home directory verification failed"
    
    ufw status verbose | grep -qw active ||
        echo "Warning: Firewall not active"
    
    systemctl is-active --quiet fail2ban ||
        echo "Warning: Fail2Ban service not running"
}
system_check

echo -e "\nSystem hardening complete!"
echo "Security services status:"
echo "--------------------------------------------------"
systemctl status fail2ban --no-pager | head -n 5
echo -e "\nClamAV version: $(clamscan --version)"
echo "--------------------------------------------------"

if [ -n "${username:-}" ]; then
    echo -e "\nNext steps:"
    echo "1. SSH access: Use 'ssh ${username}@$(hostname -I | awk '{print $1}')'"
    echo "2. Caddy config: /etc/caddy/Caddyfile"
    echo "3. Review daily security scans in /var/log/"
else
    echo -e "\nNo new user created - existing accounts remain unchanged"
fi
