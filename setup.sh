#! /bin/bash
#
#         WiFinder
#	"Wifi Tool init script"
#	  v3.2 - 16/10/2025
# Authors Aaron, Harry - Team 404
#
#   First run this to configure
#    any new hardware easily.
#

REQUIREMENTS_FILE="requirements.txt"
VENV_DIR=".venv"
LOGFILE="./initLogs/$(date +'%Y-%m-%d_%H:%M:%S').log"

								#Set target file
#Might not support paths beyond root directory currently (Need better pattern matching)
absolutetarget="/etc/rc.local"
echo "Target is set to $absolutetarget"
targetfile=$(echo $absolutetarget | awk 'BEGIN { FS = "/" } ; { print $NF }')
targetdir=$(echo $absolutetarget | awk 'BEGIN {FS = "/"} ; {$NF--;print}')

###################################################################################
                                #Functions
#clear or make logfile
: > "$LOGFILE"

#Function to log both to file and stdout (yet to be fully implemented in here)
log() {
    echo -e "$@" | tee -a "$LOGFILE"
}

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

###################################################################################
                                #Start
log "\n===== Initialization started at $(date) =====\n"
								#Banner and instructions
echo "###################################"
echo "########## WiFinder Init ##########"
echo "###################################"
echo ""
echo "This file must be run as root and should really only be run once.
If you need to rerun for whatever reason, first run the init-wiper.sh script first and then rerun this. Also should probably update before running this. Python3 v3.8 required."

echo "Variables set: (default [/etc/rc.local] [etc] [rc.local] )"
echo $absolutetarget
echo $targetfile
echo $targetdir
echo "Run? (y/n/c)"
if yes; then
    echo "running..."
else
    echo "exiting..."
    exit
fi

#Check for root
if [ "$EUID" -ne 0 ]; then
    echo "This script needs to be run with sudo or as root."
    exit 1
fi
echo "as root..."

###################################################################################
                                #FIRST SETUP
#clones screen setup to any current directory and then runs it. We only run this once so thats fine.
echo "Install screen drivers and rotate? (y/n/c)"
if yes; then
    echo "Cloning..."
    sudo git clone https://github.com/goodtft/LCD-show.git
    chmod -R 755 LCD-show
    cd LCD-show/
    sudo ./LCD5-show 270
else
    echo -e "skipping...\n"
fi


								#Check rc.local
#/etc/rc.local is now depricated and can either be enabled in systemd, or can instead be run as a service which should be what this is upgraded to in the future.
echo "###################################"
echo "##### rc.local service check ######"
echo "###################################"

echo "Are you using rc.local as autostart service? (y/n/c) (default yes)"
if yes; then
    if [ ! -e /ect/rc.local ]; then
        echo "rc.local file not found. Check if rc-local.service is enabled:"
        sudo systemctl is-enabled rc-local.service
        sudo systemctl status rc-local.service
        sudo echo "Adding rc.local..."
        sudo touch /etc/rc.local
        sudo sh -c 'echo "#!/bin/bash" > /etc/rc.local'
        sudo sh -c 'echo "sleep 1" >> /etc/rc.local'
        sudo chmod +x /etc/rc.local
        sudo echo "enabling rc.local.service..."
        sudo systemctl enable rc-local.service
    fi
else
    echo "Skipping rc.local check. ensure that you have changed the absolute target in this script to the desired output file."
    echo "Press any key to confirm it has been changed and continue. Or cancel and try again."
    read -s -n 1
fi




###################################################################################
                                #Dependancies  - by Harry

								#Check Install dependencies
echo ""
echo "###################################"
echo "######## Main Dependancies ########"
echo "###################################"
echo ""

echo "system update"
sudo apt update
echo -e "Done system update\n\n"

APT_PACKAGES=(
    python3-gi
    python3-gi-cairo
    gir1.2-gtk-3.0
    libgirepository1.0-dev
    libcairo2-dev
    pkg-config
    python3-dev
    libgtk-3-dev
    build-essential
    libwebkit2gtk-4.1-dev
    gir1.2-webkit2-4.1
    libopenblas-dev
    mysql-server
    aircrack-ng
    gpsd
    gpsd-clients
    python3-gps
    python3-scapy
)

echo "\nInstalling required system packages..."
apt install -y "${APT_PACKAGES[@]}" 2>&1 | tee -a "$LOGFILE"
if [ $? -eq 0 ]; then
    log "System packages installed successfully."
else
    log "some packages failed to install."
fi

                                #PythonSetup
echo ""
echo "###################################"
echo "######## Python Venv setup ########"
echo "###################################"
echo ""
echo -e "This will check for python version and then setup the virtual environment\n"

# ---Check for Python 3 ---
if command -v python3 &>/dev/null; then
    PY_VERSION=$(python3 -V 2>&1)
    log "[+] Python found: $PY_VERSION"
else
    log "[!] Python3 is not installed. Please install it and re-run this script."
    exit 1
fi

# --- Check Python version compatibility ---
REQUIRED_VERSION="3.8"
if python3 -c "import sys; exit(0 if sys.version_info >= (3,8) else 1)"; then
    log "[+] Python version >= $REQUIRED_VERSION OK"
else
    log "[!] Python version too old. Please upgrade to $REQUIRED_VERSION+"
    exit 1
fi

# --- Check for venv module ---
if ! python3 -m venv --help &>/dev/null; then
    log "[!] The 'venv' module is not available in your Python installation."
    exit 1
fi

# --- Create virtual environment if missing ---
if [ ! -d "$VENV_DIR" ]; then
    log "[*] Creating Python virtual environment in $VENV_DIR ..."
    python3 -m venv "$VENV_DIR"
    if [ $? -ne 0 ]; then
        log "[X] Failed to create virtual environment."
        exit 1
    fi
else
    log "[+] Virtual environment already exists ($VENV_DIR)"
fi

# --- Activate the venv ---
log "[*] Activating virtual environment..."
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

# --- Upgrade pip ---
log "[*] Upgrading pip inside venv..."
pip install --upgrade pip 2>&1 | tee -a "$LOGFILE"

# --- Install requirements ---
if [ -f "$REQUIREMENTS_FILE" ]; then
    log "[*] Installing Python dependencies from $REQUIREMENTS_FILE ..."
    pip install -r "$REQUIREMENTS_FILE" 2>&1 | tee -a "$LOGFILE"
else
    log "[!] No requirements.txt found — skipping dependency check."
fi

###################################################################################
                                #GPS
                                #GPS Setup
echo ""
echo "###################################"
echo "######## GPS reader Setup #########"
echo "###################################"
echo ""

#GPS SETUP HERE
sudo systemctl stop gpsd
sudo systemctl stop gpsd.socket
echo "gpsd set udp://10.42.0.1:65535"

#now shouldnt be needed
#gpsd -N udp://10.42.0.1:65535

echo "update /etc/default/gpsd to make perminent"

# use sed to change the config. add -i to actually write to the file
sudo  sed -i 's/DEVICES=""/DEVICES="10.42.0.1:65535"/' /etc/default/gpsd

sudo systemctl start gpsd
sudo systemctl start gpsd.socket
echo -e "gpsd & gpsd.socket started\n"

###################################################################################
                                #Main repo installer
								#Set up easy github install and file execute
echo "###################################"
echo "###### Github EZ Installer ########"
echo "###################################"

#get the repo we want to add to the rc.local file
echo "Use default project repo? (y/n/c)"
if yes; then
    echo "using https://github.com/UTS-Team-404/Main_Project_Repo.git"
    githuburl="https://github.com/UTS-Team-404/Main_Project_Repo.git"
else
    echo -e '\nEnter github branch url' 
    echo '(e.g. https://github.com/UTS-Team-404/Main_Project_Repo.git):'
    read githuburl
fi


#grab the repo file name for later
repo=$(echo $githuburl | awk 'BEGIN { FS = "/" } ; { print $NF }' | cut -d "." -f1)
echo Repo name found: $repo

echo "Use default start file? (y/n/c)"
if yes; then
    echo "using init.sh"
    startfile="init.sh"
else
    echo -e '\nWhat is the file to run on startup?'
    echo "(e.g. init.sh)"
    read startfile
fi

#Read file to be executed incase its different

#Decide where to clone the repo. Currently must be done manually outside of /
echo "Clone the reop into /$targetdir?"
if yes; then
    sudo git -C /$targetdir clone $githuburl
    echo "Making all executable at /$targetdir/$repo/*"
    sudo chmod +x /$targetdir/$repo/*
else
    echo "Clone the repo and add to rc.local manually eg. /path/to/repo/executable.file"
    exit
fi

###################################################################################
                                #Setup rc.local
								#(Wipe and) Set up rc.local
echo "###################################"
echo "#### Setup rc.local populated #####"
echo "###################################"

#Temp solution to stop rerunning causing issues is to just wipte the rc.local file each time. Since its depreciated, there shouldnt be anything important in there anyway.
echo "Wiping and repopulating rc.local..."
sudo sh -c 'echo "#!/bin/bash" > /etc/rc.local'
sudo sh -c 'echo "sleep 1" >> /etc/rc.local'

#easy getaround for systemctl timing issues. Could be done instead with a timer service but this is far easier
echo "sudo systemctl restart nftables.service" >> /etc/rc.local

#This will make an identifier for where our added lines go incase we need to delete or edit them.
echo ""
echo "###################################" >> $absolutetarget
echo "#Team 404 WiFinder autostart webUI#" >> $absolutetarget
echo "###################################" >> $absolutetarget

#This will add a line that updates from the github branch each time the device turns on. We have decided not to implement this as currently we are not having the device connect to the internet, making it pointless. But could be added in the future?
#echo -e '\n--> writing git -c $targetdir clone $githuburl to $absolutetarget'
#echo "git -c $targetdir clone $githuburl" >> $absolutetarget

#This will add a line that runs the file on startup
sudo echo "--> writing /$targetdir$repo/$startfile to $absolutetarget"
startfiledir=$(echo "/$targetdir/$repo/$startfile")
sudo echo ${startfiledir// /} >> $absolutetarget
        sudo sh -c 'echo "sleep 1" >> /etc/rc.local'





###################################################################################
                                #Wireless Setup
								#Wireless Warning
echo "###################################"
echo "######### Wireless Setup ##########"
echo "###################################"
echo "Should now have $startfile run on system boot. Now setting up wifi config."
echo "you will lose internet access after this if you do not have a third wifi adapter"


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



								#Set up hotspot NFTables redirects
echo "###################################"
echo "## Setup Hotspot NFTables Config ##"
echo "###################################"
sudo systemctl enable nftables
sudo systemctl start nftables
sudo systemctl enable nftables.service
sudo systemctl start nftables.service
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




								#Set up Wifi Adapter to perminent monitor mode
echo "###################################"
echo "## Setup Wifi Adapter Mon Config ##"
echo "###################################"

iw dev
echo "check above"
echo "enter device MAC for monitor mode"
read devmac
echo [keyfile] >> /etc/NetworkManager/NetworkManager.conf
echo unmanaged-devices=mac:$devmac >> /etc/NetworkManager/NetworkManager.conf
echo -e "unmanaged-devices=mac:$devmac added to /etc/NetworkManager/NetworkManager.conf:\n"
cat /etc/NetworkManager/NetworkManager.conf

echo -e '\nCheck that the above is correct'
echo "Press any key to continue (or 10s)"
read -s -n 1 -t 10


echo "Doneski :)"

