#! /bin/bash
#
#	Wifi Tool init script
#	v2.0 - 14/10/2025
#	Author Aaron - Team 404

#Yes or No Function
yes() {
  while true; do
    read -p "(y/n/c)" yn
    case "$yn" in
      [Yy]*) return 0;;
      [Nn]*) return 1;;
      [Cc]*) exit;;
      *) echo "Please answer (y)es, (n)o, or (c)ancel";;
    esac
  done
}



								#Set Touchscreen and Rotation
#This is for the screen specified in our hardware outline. Other screens can be used, please change as required. screenrotateset is a temperary status file and not required.
if [ ! -f /home/LCD-show/ ]; then
    echo "LCD-show not found, cloning... Then installing and restarting"
    git clone https://github.com/goodtft/LCD-show.git
    sudo chmod +x /home/LCD-show/*
    sudo /home/LCD-show/LCD5-show
    exit
    else
    if [ ! -f /home/LCD-show/screenrotateset ]; then
        echo "LCD-show installed but rotation isnt set, installing and restarting"
        touch /home/LCD-show/screenrotateset
        sudo /home/LCD-show/rotate.sh 270
        exit
    else
        echo "LCD-show found, installed and rotation set, continue..."
    fi
fi


								#Check rc.local
#/etc/rc.local is now depricated and can either be enabled in systemd, or can instead be run as a service which should be what this is upgraded to in the future.

if [ ! -f /ect/rc.local ]; then
    echo "rc.local file not found. Check if rc-local.service is enabled:"
    sudo systemctl is-enabled rc-local.service
    sudo systemctl status rc-local.service
    echo "Does rc.local need to be enabled/reset?"    
    if yes(); then
        sudo touch /etc/rc.local
        sudo sh -c 'echo "#!/bin/bash" > /etc/rc.local'
        sudo sh -c 'echo "sleep 1" >> /etc/rc.local'
        sudo chmod +x /etc/rc.local
        sudo systemctl enable rc-local.service
    else
        echo "try checking the file exists or checking its enabled/executable"
        exit
    fi  
fi


								#Set target file
#Might not support paths beyond root directory currently (Need better pattern matching)
absolutetarget="/etc/rc.local"
targetfile=$(echo $absolutetarget | awk 'BEGIN { FS = "/" } ; { print $NF }')
targetdir=$(echo $absolutetarget | awk 'BEGIN {FS = "/"} ; {$NF--;print}')
echo $absolutetarget
echo $targetfile
echo $targetdir

	
								#Banner and instructions
echo "###################################"
echo "#Team 404 Wifi Analitics tool Init#"
echo "###################################"
echo ""
echo "This file must be run as root and must be only run once.
If you need to rerun for whatever reason, first run the init-wiper.sh script first and then rerun this."
echo ""


								#Set up Hotspot config
echo "###################################"
echo "########## Setup Hotspot ##########"
echo "###################################"
echo "This may need fixing/modification - (Untested)"

#Making hotspot connection on the wlan0 interface called "YFinder-Reports-Module" and set it to start on boot.
sudo nmcli con add type wifi ifname wlan0 con-name hotspot ssid "YFinder-Reports-Module" autoconnect yes connection.autoconnect-priority 100   

#Set hotspot to use 2.4Ghz and to enable shared IP addressing
sudo nmcli con modify hotspot 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared

#Set encryption type and password - Default to "Maxwell1"
sudo nmcli con modify hotspot wifi-sec.key-mgmt wpa-psk
sudo nmcli con modify hotspot wifi-sec.psk "Maxwell1"

#Silly loop to wait 10s for the hotspot to start properly
sudo nmcli con up hotspot
echo -n "Starting Hotspot [Y]"
for i in $(seq 1 10);
do
    echo -n ")"
    sleep 0.5
    echo -n " "
    sleep 0.5
done
echo "Ding!"

#Check if hotspot is lookin good
echo "Check if the Hotspot is available below:"
nmcli connection
echo "Press any key to continue (or 10s)"
read -s -n 1 -t 10



								#Set up NFTables redirects
echo "###################################"
echo "## Setup Hotspot NFTables Config ##"
echo "###################################"
sudo systemctl enable nftables
sudo systemctl start nftables
sudo nft add table nat
sudo nft add chain nat prerouting '{ type nat hook prerouting priority -100 ; }'
sudo nft add rule nat prerouting iif wlan0 tcp dport 80 redirect to 5001
sudo nft add rule nat prerouting iif wlan0 udp dport 53 redirect to 53
sudo touch /etc/NetworkManager/dnsmasq-shared.d/yfinder-webserver-redirect.conf 
sudo sh -c 'echo "address=/#/10.42.0.1" > /etc/NetworkManager/dnsmasq-shared.d/yfinder-webserver-redirect.conf'

sudo sh -c 'nft list ruleset > /etc/nftables.conf'
echo ""
cat /etc/nftables.conf
echo -e '\nCheck that the above is correct'
echo "Press any key to continue (or 10s)"
read -s -n 1 -t 10



								#Set up easy github install and file execute
echo "###################################"
echo "###### Github EZ Installer ########"
echo "###################################"

#get which repo we want to add to the rc.local file
echo -e '\nEnter github branch url' 
echo '(e.g. https://github.com/UTS-Team-404/Init-Script-Prototype.git):'
read githuburl

#grab the repo file name for later
repo=$(echo $githuburl | awk 'BEGIN { FS = "/" } ; { print $NF }' | cut -d "." -f1)
echo Repo name found: $repo

#Read file to be executed incase its different
echo -e '\nWhat is the file to run on startup?'
read startfile

#Decide where to clone the repo. Currently must be done manually outside of /
echo "Clone the reop into $targetdir?"
if yes(); then
        git -c $targetdir clone $githuburl
        echo "Making all executable at /$targetdir/$repo/*"
        sudo chmod +x /$targetdir/$repo/*
    else
        echo "Clone the repo and add to rc.local manually eg. /path/to/repo/executable.file"
        exit
    fi

#This will make an identifier for where our added lines go incase we need to delete them manually (or with the wiper eventually).
echo ""
echo "###################################" >> $absolutetarget
echo "#Team 404 Wifi Analitics tool Init#" >> $absolutetarget
echo "###################################" >> $absolutetarget

#This will add a line that updates from the github branch each time the device turns on. We have decided not to implement this as currently we are not having the device connect to the internet, making it pointless. But could be added in the future?

#echo -e '\n--> writing git -c $targetdir clone $githuburl to $absolutetarget'
#echo "git -c $targetdir clone $githuburl" >> $absolutetarget

#This will add a line that runs the file on startup
echo "--> writing $targetdir$repo/$startfile to $absolutetarget"
startfiledir=$(echo "/$targetdir/$repo/$startfile")
echo ${startfiledir// /} >> $absolutetarget

echo "Should not have $startfile run on system boot as well as device hotspot"
