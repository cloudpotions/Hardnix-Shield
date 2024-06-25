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

# [Previous functions remain unchanged]

# Function to check password complexity
check_password_complexity() {
    local password="$1"
    if [[ ${#password} -ge 16 && "$password" =~ [A-Z] && "$password" =~ [a-z] && "$password" =~ [0-9] && "$password" =~ [^[:alnum:]] ]]; then
        return 0
    else
        return 1
    fi
}

# Main script function
main_script() {
    # Check if script is run as root or with sudo
    if [ "$EUID" -ne 0 ] && [ -z "$SUDO_USER" ]; then
        echo "Please run as root or with sudo. The Force is not strong with this one."
        exit 1
    fi

    # User prompt
    start_script=$(get_input "Did you copy some text and are you ready to start the script, young Padawan? (yes/no): " "no")
    if [[ $start_script != "yes" ]]; then
        echo "Exited script - The Sith Lords are grateful for your unsecured system."
        exit 1
    fi

    # [Update and upgrade system section remains unchanged]

    # Prompt for non-root user creation
    create_user=$(get_input "Would you like to create a non-root user with sudo privileges, young Jedi? (yes/no): " "no")
    if [[ $create_user == "yes" ]]; then
        while true; do
            read -r -p "Enter the new username (must start with a letter, and can contain letters, numbers, underscores, and hyphens): " new_username
            if ! validate_username "$new_username"; then
                echo "Invalid username format. The Force is not strong with this one. Try again."
                continue
            fi
            if id "$new_username" &>/dev/null; then
                echo "User already exists. Choose a different username, you must."
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
                echo "Passwords do not match. Concentrate and try again, you must."
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
            echo "Failed to create user. A disturbance in the Force, I sense."
            exit 1
        fi
        if ! echo "$new_username:$password" | run_with_sudo chpasswd; then
            echo "Failed to set password. The dark side clouds everything."
            exit 1
        fi
        if ! run_with_sudo usermod -aG sudo "$new_username"; then
            echo "Failed to add user to sudo group. Impossible to see, the future is."
            exit 1
        fi
        echo "User $new_username created with sudo privileges. A new Jedi Knight, we have."
    fi

    # [Other security configurations remain unchanged]

    # Security level selection
    echo "Choose your security level, you must:"
    echo "1. Padawan (Strong security: create a non-root user with sudo privileges, disable root SSH login)"
    echo "2. Jedi Knight (Padawan + Enhanced security: Google Authenticator)"
    echo "3. Jedi Master (Ultimate security: Padawan + Google Authenticator + SSH keypair)"
    security_level=$(get_numeric_input "Enter your choice (1/2/3): " "1")

    case $security_level in
        1)
            echo "Configuring Padawan level security... May the Force be with you."
            run_with_sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
            ;;
        2|3)
            echo "Configuring advanced security... The Force is strong with this one."
            run_with_sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
            install_package "libpam-google-authenticator"
            
            echo "Setting up Google Authenticator... Your lightsaber, this is."
            google-authenticator --time-based --disallow-reuse --force --rate-limit=3 --rate-time=30 --window-size=3

            if [[ -n "$new_username" ]]; then
                run_with_sudo cp ~/.google_authenticator /home/$new_username/.google_authenticator
                run_with_sudo chown $new_username:$new_username /home/$new_username/.google_authenticator
                echo "Google Authenticator configured for $new_username. Guard it well, young Jedi."
            fi

            run_with_sudo sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
            echo "auth required pam_google_authenticator.so secret=\${HOME}/.google_authenticator" | run_with_sudo tee -a /etc/pam.d/sshd

            if [ "$security_level" == "3" ]; then
                echo "Generating SSH key pair... A Jedi's weapon this is. This weapon is your life."
                ssh-keygen -t rsa -b 4096
            fi
            ;;
        *)
            echo "Invalid choice. Defaulting to Padawan level. Much to learn, you still have."
            run_with_sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
            ;;
    esac

    # Prompt for SSH port change
    change_ssh_port=$(get_input "Change the SSH port, would you like to? (yes/no): " "no")
    if [[ $change_ssh_port == "yes" ]]; then
        while true; do
            read -r -p "Enter a new SSH port (49152-65535), you must: " new_ssh_port
            if [[ "$new_ssh_port" =~ ^[0-9]+$ ]] && [ "$new_ssh_port" -ge 49152 ] && [ "$new_ssh_port" -le 65535 ]; then
                # Update SSH config
                run_with_sudo sed -i "s/^#*Port .*/Port $new_ssh_port/" /etc/ssh/sshd_config
                
                # Update firewall rules
                run_with_sudo ufw allow "${new_ssh_port}/tcp"
                run_with_sudo ufw deny 22/tcp
                
                echo "Changed, the SSH port has been. To port $new_ssh_port, it now listens."
                break
            else
                echo "Invalid, this port number is. Between 49152 and 65535, a number you must enter."
            fi
        done
    else
        echo "Unchanged, the SSH port remains. At 22, it stays."
    fi

    echo "Complete, the security configuration is. Review the changes and copy important information, you should."
    echo "If changed the SSH port was, use the new port number for future connections, you must."
    echo "Press Enter to finish the script, you should. Disconnected you may be, if SSH settings were changed."
    read -r

    # Restart SSH service
    run_with_sudo systemctl restart sshd

    echo "Completed, the script execution has. More secure, your system now is."
    echo "Current user: $(whoami)"
    if [[ $change_ssh_port == "yes" ]]; then
        echo "Remember, you must: Your new SSH port is $new_ssh_port"
    fi
    echo "May the Force be with you, always."
}

# Run the main script
main_script
