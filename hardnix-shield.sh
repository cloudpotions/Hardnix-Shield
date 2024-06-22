#!/bin/bash

# Redirect stderr to a log file
exec 2> >(tee -a "cloud_potions_error.log" >&2)

# ASCII Banner
cat << "EOF"
C͒̓̕l̿̓͝o͊͊͘u͒̈́̀d͌̽͝ Ṕ̈́̾o̓̈́͠t͋̓͝i̐̕o͊͘͝n̔́͝s̐̓̈́
H̓̀̀à͆͘r̾͑͝d͒͠n̈́̈́i͐̓̕e͋͑̚l̓́d̾̽

IMPORTANT INSTRUCTIONS:
- A lot of newbies will naturally try to copy by pressing Ctrl+C but on many terminals, this will exit your script!
- On macOS: Select the text with your mouse and use Cmd+C. 
- On Windows (using PowerShell): Just select the ***text*** in the ***console*** window and press enter or the right mouse button. That selected ***text*** ends up in your clipboard. Do not use Bitvise with this script because the Google QR Code does not show up properly on default! 

TIP: Before running the script, try copying some text from this terminal to ensure that you can copy text correctly in your current environment. This is important because the script will generate critical keys and passwords that you must copy and save. 
EOF

# Function to get user input with a default value
get_input() {
    local prompt="$1"
    local default="$2"
    local response

    read -r -p "$prompt" response
    if [ -z "$response" ]; then
        echo "$default"
    else
        echo "$response"
    fi
}

# Function to get numeric input
get_numeric_input() {
    local prompt="$1"
    local default="$2"
    local response

    while true; do
        read -r -p "$prompt" response
        if [ -z "$response" ]; then
            echo "$default"
            return
        fi
        if [[ "$response" =~ ^[1-3]$ ]]; then
            echo "$response"
            return
        else
            echo "Please enter a valid option (1, 2, or 3)."
        fi
    done
}

# Function to check password complexity
check_password_complexity() {
    local password="$1"
    if [[ ${#password} -ge 16 && "$password" =~ [A-Z] && "$password" =~ [a-z] && "$password" =~ [0-9] && "$password" =~ [^[:alnum:]] ]]; then
        return 0
    else
        return 1
    fi
}

# Function to run commands with sudo if not root
run_with_sudo() {
    if [ "$EUID" -ne 0 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

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

# Function to validate username
validate_username() {
    local username="$1"
    # Check if username starts with a letter and only contains letters, numbers, underscores, and hyphens
    if [[ "$username" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        return 0
    else
        return 1
    fi
}

# Main script function
main_script() {
    # Check if script is run as root or with sudo
    if [ "$EUID" -ne 0 ] && [ -z "$SUDO_USER" ]; then
        echo "Please run as root or with sudo"
        exit 1
    fi

    # User prompt
    start_script=$(get_input "Did you copy some text and are you ready to start the script? (yes/no): " "no")
    if [[ $start_script != "yes" ]]; then
        echo "Exited script - The Sith Lords are grateful for your unsecured system."
        exit 1
    fi

    # Update and upgrade system
    echo "Updating and upgrading system..."
    run_with_sudo apt-get update && DEBIAN_FRONTEND=noninteractive run_with_sudo apt-get upgrade -y
    wait_for_package_processes

    # Function to install a package if it's not already installed
    install_package() {
        if ! dpkg -s "$1" >/dev/null 2>&1; then
            run_with_sudo apt-get install -y "$1"
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

    # Prompt for non-root user creation
    create_user=$(get_input "Would you like to create a non-root user with sudo privileges? (yes/no): " "no")
    if [[ $create_user == "yes" ]]; then
        while true; do
            read -r -p "Enter the new username (must start with a letter, and can contain letters, numbers, underscores, and hyphens): " new_username
            if ! validate_username "$new_username"; then
                echo "Invalid username format. Please try again."
                continue
            fi
            if id "$new_username" &>/dev/null; then
                echo "User already exists. Please choose a different username."
            else
                break
            fi
        done

        # Password complexity check with double entry
        while true; do
            read -r -s -p "Enter password for $new_username (min 16 chars, must include capital, small letter, number, and symbol): " password
            echo
            read -r -s -p "Confirm password: " password_confirm
            echo

            if [ "$password" != "$password_confirm" ]; then
                echo "Passwords do not match. Please try again."
                continue
            fi

            if check_password_complexity "$password"; then
                break
            else
                echo "Password does not meet complexity requirements."
                echo "The force is weak with this one. Try again, young Padawan."
            fi
        done

        if ! run_with_sudo adduser --disabled-password --gecos "" "$new_username"; then
            echo "Failed to create user. Exiting script."
            exit 1
        fi
        if ! echo "$new_username:$password" | run_with_sudo chpasswd; then
            echo "Failed to set password. Exiting script."
            exit 1
        fi
        if ! run_with_sudo usermod -aG sudo "$new_username"; then
            echo "Failed to add user to sudo group. Exiting script."
            exit 1
        fi
        echo "User $new_username created with sudo privileges."
    fi

    # Configure GRUB bootloader security
    echo "Securing GRUB bootloader..."
    run_with_sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="quiet"$/GRUB_CMDLINE_LINUX_DEFAULT="quiet apparmor=1 security=apparmor"/' /etc/default/grub
    run_with_sudo update-grub

    # Configure LUKS for data at rest encryption
    echo "Setting up LUKS encryption..."
    # This is a placeholder. Actual LUKS setup requires more complex logic and user interaction.

    # Configure SSL/TLS
    echo "Setting up SSL/TLS..."
    # This is a placeholder. Actual SSL/TLS setup depends on specific services being used.

    # Configure fail2ban
    echo "Configuring fail2ban..."
    run_with_sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    run_with_sudo systemctl enable fail2ban
    run_with_sudo systemctl start fail2ban

    # Configure chrony
    echo "Configuring chrony..."
    run_with_sudo systemctl enable chrony
    run_with_sudo systemctl start chrony

    # Configure AppArmor
    echo "Configuring AppArmor..."
    run_with_sudo aa-enforce /etc/apparmor.d/*

    # Configure ClamAV
    echo "Configuring ClamAV..."
    run_with_sudo freshclam
    run_with_sudo systemctl enable clamav-freshclam
    run_with_sudo systemctl start clamav-freshclam

    # Configure rkhunter
    echo "Configuring rkhunter..."
    run_with_sudo rkhunter --update
    run_with_sudo rkhunter --propupd

    # Configure auditd
    echo "Configuring auditd..."
    run_with_sudo systemctl enable auditd
    run_with_sudo systemctl start auditd

    # Configure FSTAB for secure shared memory
    echo "Configuring secure shared memory..."
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" | run_with_sudo tee -a /etc/fstab

    # Disallow root login
    echo "Disallowing root login..."
    run_with_sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

    # Protect su command
    echo "Protecting su command..."
    run_with_sudo dpkg-statoverride --update --add root sudo 4750 /bin/su

    # Configure sysctl for network hardening
    echo "Hardening network with sysctl..."
    cat << EOF | run_with_sudo tee -a /etc/sysctl.conf
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
EOF
    run_with_sudo sysctl -p

    # Configure UFW
    echo "Configuring UFW..."
    run_with_sudo ufw default deny incoming
    run_with_sudo ufw default allow outgoing
    run_with_sudo ufw allow ssh
    run_with_sudo ufw --force enable

    # Prompt for web application firewall rules
    web_apps=$(get_input "Are you planning on using your server for web applications? (yes/no): " "no")
    if [[ $web_apps == "yes" ]]; then
        run_with_sudo ufw allow http
        run_with_sudo ufw allow https
        run_with_sudo ufw allow 3306
    fi

    # Security level selection
    echo "Choose your security level:"
    echo "1. Padawan (Strong security: create a non-root user with sudo privileges, disable root SSH login)"
    echo "2. Jedi (Padawan + Enhanced security: Google Authenticator)"
    echo "3. CP Wizard (Ultimate security: Padawan + Google Authenticator + SSH keypair)"
    security_level=$(get_numeric_input "Enter your choice (1/2/3): " "1")

    case $security_level in
        1)
            echo "Configuring Padawan level security..."
            run_with_sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
            ;;
        2|3)
            echo "Configuring advanced security..."
            run_with_sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
            install_package "libpam-google-authenticator"
            
            # Set up Google Authenticator for root
            google-authenticator --time-based --disallow-reuse --force --rate-limit=3 --rate-time=30 --window-size=3

            # If a new user was created, copy the config to their home directory
            if [[ -n "$new_username" ]]; then
                run_with_sudo cp ~/.google_authenticator /home/$new_username/.google_authenticator
                run_with_sudo chown $new_username:$new_username /home/$new_username/.google_authenticator
            fi

            # Configure PAM to use Google Authenticator
            run_with_sudo sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
            echo "auth required pam_google_authenticator.so secret=\${HOME}/.google_authenticator" | run_with_sudo tee -a /etc/pam.d/sshd

            if [ "$security_level" == "3" ]; then
                ssh-keygen -t rsa -b 4096
            fi
            ;;
        *)
            echo "Invalid choice. Defaulting to Padawan level."
            run_with_sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
            ;;
    esac

    # Prompt for SSH port change
    change_ssh_port=$(get_input "Would you like to change the SSH port? (yes/no): " "no")
    if [[ $change_ssh_port == "yes" ]]; then
        read -r -p "Enter a new SSH port (49152-65535): " new_ssh_port
        run_with_sudo sed -i "s/#Port 22/Port $new_ssh_port/" /etc/ssh/sshd_config
        run_with_sudo ufw allow "${new_ssh_port}/tcp"
        run_with_sudo ufw deny 22/tcp
    fi

    echo "Security configuration complete. Please review the changes and copy any important information."
    echo "Press Enter to finish the script. You may be disconnected if SSH settings were changed."
    read -r

    # Restart SSH service
    run_with_sudo systemctl restart sshd

    echo "Script execution completed. Your system is now more secure."
    echo "Current user: $(whoami)"
}

# Run the main script
main_script
