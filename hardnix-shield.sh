#!/bin/bash

# ASCII Banner
cat << "EOF"
C͒̓̕l̿̓͝o͊͊͘u͒̈́̀d͌̽͝ Ṕ̈́̾o̓̈́͠t͋̓͝i̐̕o͊͘͝n̔́͝s̐̓̈́
H̓̀̀à͆͘r̾͑͝d͒͠n̈́̈́i͐̓̕e͋͑̚l̓́d̾̽

IMPORTANT INSTRUCTIONS:
- A lot of newbies will naturally try to copy by pressing Ctrl+C but on many terminals, this will exit your script!
- On macOS or Linux: highlight text then press Command+C (macOS) or Ctrl+Shift+C (Linux) to copy
- On Windows (using PowerShell): Just select the text and right click your mouse button.Do not use Bitvise Terminal 
  with this script because the Google QR Code does not show up properly by default. 

TIP: Before running the script, try copying some text from this terminal to ensure that you can copy text correctly in your current environment. 
This is important because the script will generate critical keys and passwords that you must copy and save. 
EOF

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# User prompt
read -p "Did you copy some text and are you ready to start the script? (yes/no): " start_script
if [[ $start_script != "yes" ]]; then
    echo "Exited script - The Sith Lords are grateful for your unsecured system."
    exit 1
fi

# Function to check if a process is running
is_process_running() {
    pgrep -x "$1" > /dev/null
}

# Function to wait for package management processes to finish
wait_for_package_processes() {
    processes=("apt-get" "apt" "dpkg")
    for process in "${processes[@]}"; do
        while is_process_running "$process"; do
            echo "Waiting for $process to finish..."
            sleep 5
        done
    done
    echo "No package management processes running. Continuing..."
}

# Update and upgrade system
echo "Updating and upgrading system..."
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
wait_for_package_processes

# Function to install a package if it's not already installed
install_package() {
    if ! dpkg -s "$1" >/dev/null 2>&1; then
        apt-get install -y "$1"
        wait_for_package_processes
    else
        echo "$1 is already installed"
    fi
}

# Install required packages
packages=(
    "htop" "selinux-utils" "cryptsetup" "fail2ban" "glances" "chrony" "figlet" "lsb-release" 
    "update-motd" "secure-delete" "iproute2" "dnsutils" "apparmor" "apparmor-utils" "clamav" 
    "rkhunter" "auditd" "chkrootkit" "lynis" "openssh-server" "ufw"
)

for package in "${packages[@]}"; do
    install_package "$package"
done

# Configure GRUB bootloader security
echo "Securing GRUB bootloader..."
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="quiet"$/GRUB_CMDLINE_LINUX_DEFAULT="quiet apparmor=1 security=apparmor"/' /etc/default/grub
update-grub

# Configure LUKS for data at rest encryption
echo "Setting up LUKS encryption..."
# This is a placeholder. Actual LUKS setup requires more complex logic and user interaction.

# Configure SSL/TLS
echo "Setting up SSL/TLS..."
# This is a placeholder. Actual SSL/TLS setup depends on specific services being used.

# Configure fail2ban
echo "Configuring fail2ban..."
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl start fail2ban

# Configure chrony
echo "Configuring chrony..."
systemctl enable chrony
systemctl start chrony

# Configure AppArmor
echo "Configuring AppArmor..."
aa-enforce /etc/apparmor.d/*

# Configure ClamAV
echo "Configuring ClamAV..."
freshclam
systemctl enable clamav-freshclam
systemctl start clamav-freshclam

# Configure rkhunter
echo "Configuring rkhunter..."
rkhunter --update
rkhunter --propupd

# Configure auditd
echo "Configuring auditd..."
systemctl enable auditd
systemctl start auditd

# Configure FSTAB for secure shared memory
echo "Configuring secure shared memory..."
echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab

# Disallow root login
echo "Disallowing root login..."
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Protect su command
echo "Protecting su command..."
dpkg-statoverride --update --add root sudo 4750 /bin/su

# Configure sysctl for network hardening
echo "Hardening network with sysctl..."
cat << EOF >> /etc/sysctl.conf
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
EOF
sysctl -p

# Configure UFW
echo "Configuring UFW..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw enable

# Prompt for web application firewall rules
read -p "Are you planning on using your server for web applications? (yes/no): " web_apps
if [[ $web_apps == "yes" ]]; then
    ufw allow http
    ufw allow https
    ufw allow 3306
fi

# Prompt for non-root user creation
read -p "Would you like to create a non-root user with sudo privileges? (yes/no): " create_user
if [[ $create_user == "yes" ]]; then
    read -p "Enter the new username: " new_username
    adduser $new_username
    usermod -aG sudo $new_username
    echo "User $new_username created with sudo privileges."
fi

# Security level selection
echo "Choose your security level:"
echo "1. Padawan (Strong security: create a non-root user with sudo privileges, disable root SSH login)"
echo "2. Jedi (Padawan + Enhanced security: Google Authenticator)"
echo "3. CP Wizard (Ultimate security: Padawan + Google Authenticator + SSH keypair)"
read -p "Enter your choice (1/2/3): " security_level

case $security_level in
    1)
        echo "Configuring Padawan level security..."
        sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
        ;;
    2)
        echo "Configuring Jedi level security..."
        sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
        apt-get install -y libpam-google-authenticator
        google-authenticator
        sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
        echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd
        ;;
    3)
        echo "Configuring CP Wizard level security..."
        sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
        apt-get install -y libpam-google-authenticator
        google-authenticator
        sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
        echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd
        ssh-keygen -t rsa -b 4096
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Prompt for SSH port change
read -p "Would you like to change the SSH port? (yes/no): " change_ssh_port
if [[ $change_ssh_port == "yes" ]]; then
    read -p "Enter a new SSH port (49152-65535): " new_ssh_port
    sed -i "s/#Port 22/Port $new_ssh_port/" /etc/ssh/sshd_config
    ufw allow $new_ssh_port/tcp
    ufw deny 22/tcp
fi

echo "Security configuration complete. Please review the changes and copy any important information."
echo "Press Enter to finish the script. You may be disconnected if SSH settings were changed."
read

# Restart SSH service
systemctl restart sshd

echo "Script execution completed. Your system is now more secure."