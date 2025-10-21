#! /bin/bash
#
#         WiFinder
#	"Wifi Tool init script"
#	  v4.1 - 16/10/2025
# Authors Aaron, Harry - Team 404
#
#   First run this to configure
#    any new hardware easily.
#

REQUIREMENTS_FILE="/etc/Main_Project_Repo/requirements.txt"
VENV_DIR="/etc/.venv"
LOGFILE="/etc/Main_Project_Repo/setupLogs/$(date +'%Y-%m-%d_%H:%M:%S').log"
webserverport="5001"

								#Set target file
#Should be changed for a static absolute path instead
#absolutetarget="/etc/rc.local"
#echo "Target is set to $absolutetarget"
#targetfile="rc.local"
targetdir="etc"

###################################################################################
                                #Functions

#Function to log both to file and stdout (yet to be fully implemented in here)
log() {
    sudo echo -e "$@" | tee -a "$LOGFILE"
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
								#Banner and instructions
echo "###################################"
echo "########## WiFinder Init ##########"
echo "###################################"
echo ""
echo "This file must be run as root. Python3 v3.8 required."

echo "directory set: (Default /[etc])"
echo $targetdir
echo "Run setup? (y/n/c)"
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
                                #Screen setup (will reboot)
#clones screen setup to any current directory and then runs it. We only run this once so thats fine.
echo "Install screen drivers and rotate? (Only needs to be run once, then skip) (y/n/c)"
if yes; then
    sudo rm -rf /etc/LCD-show
    echo "Cloning..."
    sudo git -C /etc clone https://github.com/goodtft/LCD-show.git
    sudo chmod -R 755 /etc/LCD-show
    cd /etc/LCD-show/
    echo "This will install and reboot, you will then have to run this script again to continue setup (or 10s)."
    read -s -n 1 -t 10
    sudo ./LCD5-show 270
else
    echo -e "skipping...\n"
fi


								#Autostart and Desktop disable
#This will make a .desktop autorun to run our script each bot and will disable the desktop rendering so that the user cannot do anything but wait for our app to run and cannot escape once it does
echo "###################################"
echo "######## Autostart Setup ##########"
echo "###################################"
echo ""
sleep 1

echo "Configure autostart? (y/n/c) (default yes)"
if yes; then
    echo "Enter the base user: (default: pi) (Needs to have autologin enabled [is by default])"    
    read currentuser
    echo "Making /home/$currentuser/.config/autostart folder..."
    sudo mkdir /home/$currentuser/.config/autostart
    echo "Making .desktop file..."
    touch /home/$currentuser/.config/autostart/WiFinder.desktop
    echo "" > /home/$currentuser/.config/autostart/WiFinder.desktop
    echo "populating .desktop file..."
    echo "[Desktop Entry]" >> /home/$currentuser/.config/autostart/WiFinder.desktop
    echo "Type=Application" >> /home/$currentuser/.config/autostart/WiFinder.desktop
    echo "Name=WiFinder" >> /home/$currentuser/.config/autostart/WiFinder.desktop
    echo "Exec=sh -c 'sudo /etc/Main_Project_Repo/init.sh'" >> /home/$currentuser/.config/autostart/WiFinder.desktop
    echo -e "Done! Now Populated with:\n"
    cat /home/$currentuser/.config/autostart/WiFinder.desktop
    

    echo "Disable desktop environment? (y/n/c) (Will disable debugging) (default yes)"
    if yes; then
        echo "Disabling desktop environment"
        echo "" > /etc/xdg/lxsession/LXDE-pi/autostart
    else
        echo -e "keeping desktop enabled..."
    fi
else
    echo -e "skipping...\n"
fi

echo ""
echo "###################################"
echo "####### boot speed increase #######"
echo "###################################"
echo ""
sleep 1
                                #Stop unneeded task for quicker boot time
echo "Need to disable slow and un-needed services? (first time only) (experimental) (y/n/c)"
if yes; then
    echo "fixing rpc.statd"
    cp /lib/systemd/system/rpc-statd.service /etc/systemd/system/rpc-statd.service
    sed -i '/\[Unit\]/a Requires=rpcbind.service\nAfter=rpcbind.service' /etc/systemd/system/rpc-statd.service
    systemctl daemon-reload
    systemctl restart rpc-statd.service
    echo "fixed."
    
    echo "stopping rpi-eeprom-update"
    sudo systemctl mask rpi-eeprom-update

    echo "stopping bluetooth"
    sudo sh -c 'echo "dtoverlay=disable-bt" >> /boot/config.txt'
    echo "killing bluetooth services"
    sudo systemctl disable hciuart.service
    sudo systemctl disable bluealsa.service
    sudo systemctl disable bluetooth.service
    echo "stopping and disabling rc.local services"
    sudo systemctl stop rc-local.service
    sudo systemctl disable rc-local.service
    echo -e "all done \n\n"
else
    echo -e "skipping...\n\n"
fi

                                #Custom boot screen
echo "###################################"
echo "###### Replace boot screen #######"
echo "###################################"
echo ""
sleep 1

echo "Replace the boot and splash screen images with way cooler ones? (heck yea) (y/n/c)"
if yes; then
    echo "Not yet :("
    sleep 5
else
    echo -e "skipping...\n\n"
fi


###################################################################################
                                #Main repo installer
								#Set up easy github install and file execute
echo "###################################"
echo "###### Github EZ Installer ########"
echo "###################################"
sleep 1

#get the repo we want to add to the rc.local file
echo -e "\nDo you need to clone the repo? (Default yes) (y/n/c)"
if yes; then
    echo "proceeding..."

    echo "Use default project repo? (https://github.com/UTS-Team-404/Main_Project_Repo.git) (y/n/c)"
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

    echo "Use default start file? (init.sh) (y/n/c)"
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
    echo "Clone the repo into /etc?"
    if yes; then
        sudo git -C /etc clone $githuburl
        echo "Making all executable at /etc/$repo/*"
        sudo chmod +x /$targetdir/$repo/*
    else
        echo "Clone the repo manually."
        exit
    fi
else
    echo -e "Skipping repo clone...\n\n"
fi


###################################################################################
                                #Dependancies
                                # - by Harry

								#Check Install dependencies

#clear or make logfile
sudo echo "" > "$LOGFILE"

echo ""
echo "###################################"
echo "######## Main Dependancies ########"
echo "###################################"
echo ""

echo "system update"
sudo apt update -y
echo -e "Done system update\n\n"

APT_PACKAGES=(
    python3-gi
    python3-gi-cairo
    gir1.2-gtk-3.0
    libgirepository1.0-dev
    libcairo2-dev
    pkg-config
    python3-dev
    python3-full
    libgtk-3-dev
    build-essential
    libwebkit2gtk-4.1-dev
    gir1.2-webkit2-4.1
    libopenblas-dev
    mariadb-server
    aircrack-ng
    gpsd
    gpsd-clients
    python3-gps
    python3-scapy
    python3.11-venv
)

echo "Installing required system packages..."
apt install -y "${APT_PACKAGES[@]}" 2>&1 # | tee -a "$LOGFILE" #Causing issues, temperarily removed
if [ $? -eq 0 ]; then
    log "System packages installed successfully."
else
    log "some packages failed to install."
fi

                                #PythonSetup - should be done after repois cloned, in the repo dir
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
    sudo python3 -m venv "$VENV_DIR" --system-site-packages
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
sudo pip3 --python $VENV_DIR/bin/python3 install --upgrade pip 2>&1 | tee -a "$LOGFILE"

# --- Install requirements ---
if [ -f "$REQUIREMENTS_FILE" ]; then
    log "[*] Installing Python dependencies from $REQUIREMENTS_FILE ..."
    sudo pip3 --python $VENV_DIR/bin/python3 install -r "$REQUIREMENTS_FILE" 2>&1 | tee -a "$LOGFILE"
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
                                #Wireless Setup
								#Wireless Warning
echo "###################################"
echo "######### Wireless Setup ##########"
echo "###################################"
echo "Should now have $startfile run on system boot. Now setting up wifi config."
echo "The onboard wireless interface will be configured to a hotspot, a second external adapter will be configured as a monitor mode adapter to capture traffic on"
echo "Configure hotspot for onbaord wifi interface (wlan0)? (Yes if this is the first time being run) (y/n/c)"
if yes; then
    echo "proceeding..."
								    #Set up Hotspot config
    echo "###################################"
    echo "########## Setup Hotspot ##########"
    echo "###################################"

    #Making hotspot connection on the wlan0 interface called "WiFinder-Reports-Module" and set it to start on boot.
    sudo nmcli con add type wifi ifname wlan0 con-name hotspot ssid "WiFinder-Reports-Module" autoconnect yes connection.autoconnect-priority 100   

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
    echo "Hotspot should be setup, see below:"
    sudo nmcli | cat
    echo -e "\nPress any key to continue (or 10s)"
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
    sudo nft add rule nat prerouting iif wlan0 tcp dport 80 redirect to $webserverport
    sudo nft add rule nat prerouting iif wlan0 udp dport 53 redirect to 53
    sudo touch /etc/NetworkManager/dnsmasq-shared.d/yfinder-webserver-redirect.conf 
    sudo sh -c 'echo "address=/#/10.42.0.1" > /etc/NetworkManager/dnsmasq-shared.d/WiFinder-webserver-redirect.conf'

    sudo sh -c 'nft list ruleset > /etc/nftables.conf'
    echo ""
    cat /etc/nftables.conf
    echo -e '\nCheck that the above is correct'
    echo "Press any key to continue (or 10s)"
    read -s -n 1 -t 10
else
    echo -e "Skipping...\n\n"
fi



								#Set up Wifi Adapter to perminent monitor mode
echo "###################################"
echo "## Setup Wifi Adapter Mon Config ##"
echo "###################################"

echo -e "\nCompleting this set will block your access to the internet once your device reboots unless you have a second wireless adapter (Third wireless interface). We reccomend completing this part and then imediatly running the init script (eventually this will be automated). Do you want to proceed? (y/n/c)"
if yes; then
    echo "proceeding..."
else
    echo "Rerun this file when you want to configure the wireless device to monitor mode (required for operation). Exiting..."
    exit
fi


iw dev
echo "check above"
echo "enter device MAC address to set in perminent monitor mode"
read devmac
echo [keyfile] >> /etc/NetworkManager/NetworkManager.conf
echo unmanaged-devices=mac:$devmac >> /etc/NetworkManager/NetworkManager.conf
echo -e "unmanaged-devices=mac:$devmac added to /etc/NetworkManager/NetworkManager.conf:\n"
cat /etc/NetworkManager/NetworkManager.conf

echo -e '\nCheck that the above is correct'
echo "Press any key to continue (or 10s)"
read -s -n 1 -t 10


echo "Doneski :)"

