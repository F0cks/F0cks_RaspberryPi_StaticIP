#!/usr/bin/env bash

# Variables
ASK_TO_REBOOT=0
MYDIR="$(dirname "$(realpath "$0")")"

# Sources

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
    "1" "SSH operations" \
    "2" "Set static IP"  3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        case "$OPTION" in
            # SSH operations
            1)  
                ;;
            # Set static IP
            2)  echo "Set Static IP"
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
        exit 0
    fi
done
exit 1