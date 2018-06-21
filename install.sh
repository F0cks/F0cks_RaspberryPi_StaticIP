#!/usr/bin/env bash

#################
### VARIABLES ###
#################
# Global
ASK_TO_REBOOT=0
MYDIR="$(dirname "$(realpath "$0")")"

# SSH
SSH_UPDATE=0
SSH_EXIT=0
SSH_PORT=22

###############
### SSH BEG ###
###############

ssh_change_port()
{
    local ssh_line
    # Enable port changing
    sed -i -- "s/#Port /Port /g" /etc/ssh/sshd_config
    # Catch line
    ssh_line=$(grep "Port " /etc/ssh/sshd_config)
    # Change port
    sed -i -- "s/$ssh_line/Port $SSH_PORT/g" /etc/ssh/sshd_config
    SSH_UPDATE=1
}

ssh_get_current_port()
{
    SSH_PORT=$(grep "Port " /etc/ssh/sshd_config | awk '{print $2}')
}

ssh_change_port_menu()
{
    local exitstatus
    ssh_get_current_port
    SSH_PORT=$(whiptail --title "New SSH port" --inputbox "\nWhat port do you want to use?" 10 60 $SSH_PORT 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        ssh_change_port
    fi
}

ssh_password_uncomment()
{
    # Make sure that all options are uncommented
    sed -i -- "s/#ChallengeResponseAuthentication /ChallengeResponseAuthentication /g" /etc/ssh/sshd_config
    sed -i -- "s/#PasswordAuthentication /PasswordAuthentication /g" /etc/ssh/sshd_config
    sed -i -- "s/#UsePAM /UsePAM /g" /etc/ssh/sshd_config
    sed -i -- "s/#PermitRootLogin /PermitRootLogin /g" /etc/ssh/sshd_config
    SSH_UPDATE=1
}


ssh_disable_password()
{
    # Update values
    sed -i -- "s/ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/g" /etc/ssh/sshd_config
    sed -i -- "s/PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
    sed -i -- "s/UsePAM yes/UsePAM no/g" /etc/ssh/sshd_config
    sed -i -- "s/PermitRootLogin yes/PermitRootLogin no/g" /etc/ssh/sshd_config
    sed -i -- "s/PermitRootLogin prohibit-password/PermitRootLogin no/g" /etc/ssh/sshd_config
    SSH_UPDATE=1
}

ssh_enable_password()
{
    # Update values
    sed -i -- "s/ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/g" /etc/ssh/sshd_config
    sed -i -- "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
    sed -i -- "s/UsePAM no/UsePAM yes/g" /etc/ssh/sshd_config
    sed -i -- "s/PermitRootLogin yes/PermitRootLogin prohibit-password/g" /etc/ssh/sshd_config
    sed -i -- "s/PermitRootLogin no/PermitRootLogin prohibit-password/g" /etc/ssh/sshd_config
    SSH_UPDATE=1
}

ssh_disable_password_menu()
{
    local SSHOPTION
    local SSHexitstatus
    SSHOPTION=$(whiptail --title "SSH password authentication" --cancel-button Cancel --ok-button Select --menu "\nDo you want to Enable or Disable SSH password authentication?" 15 60 4 \
    "1" "Enable" \
    "2" "Disable"  3>&1 1>&2 2>&3)
    SSHexitstatus=$?
    if [ $SSHexitstatus = 0 ]; then
        case "$SSHOPTION" in
            # Enable
            1)  ssh_password_uncomment
                ssh_enable_password
                ;;
            # Disable
            2)      if !(whiptail --title "Disable SSH password authentication" --yes-button "Cancel" --no-button "Continue"  --yesno "Doing this will make SSH authentication impossible if you have not already imported RSA key. Do you want to continue?" 10 60) then
                    ssh_password_uncomment
                    ssh_disable_password
                fi
                ;;
            # Exit this menu
            *)  echo "error SSH password authentication"
                exit 1
        esac
    fi
}

ssh_menu()
{
    local SSHOPTION
    local SSHexitstatus

    SSH_EXIT=0

    while [ $SSH_EXIT -eq 0 ]
    do
        SSHOPTION=$(whiptail --title "SSH operations" --cancel-button Finish --ok-button Select --menu "\nChoose what you want to do:" 15 60 4 \
        "1" "Change SSH port" \
        "2" "Enable/Disable SSH password authentication"  3>&1 1>&2 2>&3)
        SSHexitstatus=$?
        if [ $SSHexitstatus = 0 ]; then
            case "$SSHOPTION" in
                # Change SSH port
                1)  ssh_change_port_menu
                    ;;
                # Enable/Disable password connexion
                2)  ssh_disable_password_menu
                    ;;
                *)  echo "SSH Error"
                    exit 1
            esac
        else
            # Finish
            if [ $SSH_UPDATE = 1 ]; then
                if (whiptail --title "SSH restart" --yesno "Do you want to restart SSH now?" 10 60) then
                    systemctl reload ssh
                    SSH_UPDATE=0
                fi
            fi
            SSH_EXIT=1
        fi
    done
}
###############
### SSH END ###
###############

# Force sudo
if [ "$EUID" -ne 0 ]
then 
    echo "Script must be run as root. Try with 'sudo'"
    exit 1
fi

# Main menu
while :
do
    OPTION=$(whiptail --title "F0cks RaspberryPi ToolBox" --cancel-button Finish --ok-button Select --menu "\nChoose what you want to do:" 15 60 4 \
    "1" "SSH operations" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        case "$OPTION" in
            # SSH operations
            1)  ssh_menu
                ;;
            *)  echo "Error"
                exit 1
        esac
    else
        # Finish
        if [ $ASK_TO_REBOOT = 1 ]; then
            if (whiptail --title "Reboot" --yesno "Do you want to reboot now?" 10 60) then
                reboot
            fi
        fi
        if [ $SSH_UPDATE = 1 ]; then
                if (whiptail --title "SSH restart" --yesno "Do you want to restart SSH now? (last chance)" 10 60) then
                    systemctl reload ssh
                    SSH_UPDATE=0
                fi
            fi
        exit 0
    fi
done
exit 1