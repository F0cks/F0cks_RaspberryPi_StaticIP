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

# static IP
STATIC_IP_ABORT=0
IPv4dev=0
IPv4addr=0
IPv4gw=0
IPv4dns=0

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
                # Enable/Disable password authentication
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

#####################
### STATIC IP BEG ###
#####################

function variables_reset()
{
    IPv4dev=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++)if($i~/dev/)print $(i+1)}')
    IPv4addr=$(ip route get 8.8.8.8| awk '{print $7}')
    IPv4gw=$(ip route get 8.8.8.8 | awk '{print $3}')
    IPv4dns=$IPv4gw
    #IPv4dns=$(awk '{ if (NR!=1) print $2 }' /etc/resolv.conf | tr '\n' ' ' |sed 's/.$//')  
}

function dhcpcd_backup()
{
    # Check backup
    if [ ! -f /etc/dhcpcd.conf.f0cks.bak ]; then
        # Create backup
        cp /etc/dhcpcd.conf /etc/dhcpcd.conf.f0cks.bak
    else
        # Use clear backup
        rm /etc/dhcpcd.conf
        cp /etc/dhcpcd.conf.f0cks.bak /etc/dhcpcd.conf
    fi
}

function dhcpcd_update()
{
    # Append static ip configuration to dhcpcd.conf
    echo -e "\r\n# static IP configuration" >> /etc/dhcpcd.conf
    echo "interface $IPv4dev" >> /etc/dhcpcd.conf
    echo "static ip_address=$IPv4addr" >> /etc/dhcpcd.conf
    echo "static routers=$IPv4gw" >> /etc/dhcpcd.conf
    echo "static domain_name_servers=$IPv4dns" >> /etc/dhcpcd.conf
}

function IPv4dev_update()
{
    # Turn the available interfaces into an array so it can be used with a whiptail dialog
    local interfacesArray=()
    # Number of available interfaces
    local interfaceCount
    # Whiptail variable storage
    local chooseInterfaceCmd
    # Temporary Whiptail options storage
    local chooseInterfaceOptions
    # Loop sentinel variable
    local firstLoop=1

    local availableInterfaces=$(ip -o link  | grep "state UP" | awk '{print $2}' | cut -d':' -f1 | cut -d'@' -f1) 

    # read $firstLoop
    while read -r line; do
        mode="OFF"
        if [[ $firstLoop -eq 1 ]]; then
            firstLoop=0
            mode="ON"
        fi
        interfacesArray+=("${line}" "" "${mode}")
    done <<< "${availableInterfaces}"

    # Find out how many interfaces are available to choose from
    interfaceCount=$(echo "${availableInterfaces}" | wc -l)
    chooseInterfaceCmd=(whiptail --separate-output --radiolist "Available interfaces (press space to select):" 15 60 ${interfaceCount})
    chooseInterfaceOptions=$("${chooseInterfaceCmd[@]}" "${interfacesArray[@]}" 2>&1 >/dev/tty)
    if [[ $? = 0 ]]; then
        for desiredInterface in ${chooseInterfaceOptions}; do
            IPv4dev=${desiredInterface}
        done
    else
        STATIC_IP_ABORT=1
    fi
}

function IPv4addr_update()
{
    local IPv4addrUpdate
    local exitstatus

    IPv4addrUpdate=$(whiptail --title "Local IP" --inputbox "What IP do you want to use?" 10 60 $IPv4addr 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        IPv4addr=$IPv4addrUpdate
    else
        STATIC_IP_ABORT=1
    fi
}

function IPv4gw_update()
{
    local IPv4gwUpdate
    local exitstatus

    IPv4gwUpdate=$(whiptail --title "Router IP" --inputbox "Do you want to update router IP?" 10 60 $IPv4gw 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        IPv4gw=$IPv4gwUpdate
    else
        STATIC_IP_ABORT=1
    fi
}

function IPv4dns_update()
{
    local IPv4dnsUpdate
    local exitstatus

    IPv4dnsUpdate=$(whiptail --title "DNS IP(s)" --inputbox "Update DNS? (use space as separator)" 10 70 "$IPv4dns" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        IPv4dns=$IPv4dnsUpdate
    else
        STATIC_IP_ABORT=1
    fi
}

staticIp_menu()
{
    STATIC_IP_ABORT=0
    variables_reset
    # Ask to use default settings
    if !(whiptail --title "Default settings" --yesno "Current settings:\n\n\
        Interface : $IPv4dev\n\
        Current IP: $IPv4addr\n\
        Router IP : $IPv4gw\n\
        DNS IP(s) : $IPv4dns\n\n\
    Do you want to use these settings?\n\
    'yes' will set $IPv4addr as static\n\
    'no'  will allow you to edit these settings" 16 60) then
        if [ $STATIC_IP_ABORT = 0 ]; then
            IPv4dev_update
        fi
        if [ $STATIC_IP_ABORT = 0 ]; then
            IPv4addr_update
        fi
        if [ $STATIC_IP_ABORT = 0 ]; then
            IPv4gw_update
        fi
        if [ $STATIC_IP_ABORT = 0 ]; then
            IPv4dns_update
        fi        
    fi
    if [ $STATIC_IP_ABORT = 0 ]; then
        dhcpcd_backup
        dhcpcd_update
        ASK_TO_REBOOT=1
    fi 
}

#####################
### STATIC IP END ###
#####################

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
    "1" "SSH operations"\
    "2" "Set static IP" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        case "$OPTION" in
            # SSH operations
            1)  ssh_menu
                ;;
            # Static IP
            2)  staticIp_menu
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