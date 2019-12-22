#!/bin/bash

HASTCOPE_DIR=/var/hastcope
RED='\e[1;31m'
GREEN='\e[1;32m'
NC='\e[0m' # No Color

# Setup wlan0 to connect to wifi if there's no connection
wget -q --spider http://google.com
if [[ $? != 0 ]]; then
    read -p "The camera isn't currently connected to the internet, would you like to configure wifi now? [y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo "These are the available networks:"
        sudo iwlist wlan0 scan | grep -e ESSID -e Quality
        read -p "Which one would you like to connect to? " wifi_ssid
        if [ $(sudo grep -c "$wifi_ssid" /etc/wpa_supplicant/wpa_supplicant.conf) != 0 ]; then
            echo "Warning: A network with that name has already been configured"
        fi
        read -sp "What's the password for it? (it will not be echoed) " wifi_passphrase
        wpa_passphrase $wifi_ssid $wifi_passphrase | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
        sudo sed -ri 's/^.+#psk=.+$//g' /etc/wpa_supplicant/wpa_supplicant.conf
        wpa_cli -i wlan0 reconfigure
        echo "Done!"
    fi
else
    echo -e "${GREEN}The camera is connected to the internet, skipping wifi setup${NC}"
fi

# Check if wlan1 is available
if [ $(ifconfig | grep -c "wlan1") == 1 ]; then
    # Fix the wifi adapter driver
    if test ! -f /usr/bin/install-wifi; then
        echo -e "${GREEN}Fixing the wifi adapter driver${NC}"
        sudo apt purge -y firmware-realtek
        sudo wget http://downloads.fars-robotics.net/wifi-drivers/install-wifi -O /usr/bin/install-wifi
        sudo chmod +x /usr/bin/install-wifi
        sudo install-wifi
    else
        echo -e "${GREEN}The wifi adapter driver has already been fixed. Skipping...${NC}"
    fi
    # Setup wlan1 to serve a hotspot
    if [ $(sudo grep -c "iptables-restore" /etc/rc.local) == 0 ]; then
        echo -e "${GREEN}Configuring the wifi hotspot${NC}"
        sudo apt-get install -y hostapd dnsmasq
        # Assign a static IP address for wlan1
sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOT
interface wlan1
static ip_address=192.168.3.254/24
nohook wpa_supplicant   # don't call the wpa_supplicant hook
denyinterfaces wlan1    # don't send DHCP requests
EOT
        # Configure DHCP
        sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
sudo tee -a /etc/dnsmasq.conf > /dev/null <<EOT
interface=wlan1
dhcp-range=192.168.3.1,192.168.3.20,255.255.255.0,24h
EOT
        # Configure the access point
        read -p "Hotspot name: " hs_ssid
        read -sp "Hotspot passphrase: " hs_passphrase
sudo tee -a /etc/hostapd/hostapd.conf > /dev/null <<EOT
interface=wlan1
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
ssid=$hs_ssid
wpa_passphrase=$hs_passphrase
EOT
        echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' | sudo tee -a /etc/default/hostapd > /dev/null
        sudo systemctl unmask hostapd.service
        sudo systemctl enable hostapd.service
        # Enable traffic forwarding
        sudo sed -i -E 's/^#(net\.ipv4\.ip_forward=1)$/\1/' /etc/sysctl.conf
        # Create forwarding rules
        sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
        sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        sudo iptables -A FORWARD -i wlan1 -o wlan0 -j ACCEPT
        sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
        sudo sed -ri 's/^(exit 0)$/iptables-restore < \/etc\/iptables.ipv4.nat\n\1/' /etc/rc.local
    else
        echo -e "${GREEN}Wifi hotstpot has already been configured. Skipping...${NC}"
        echo "(if you'd like to change the name or password you can do so editing /etc/hostapd/hostapd.conf and restarting the hostapd service)"
    fi
else
    echo "Error: The secondary wifi interface isn't present, this could mean that its taking its time to boot up"
    echo "or that one of the cables has come loose while in transit. Give it a minute and check for a green light"
    echo "shinning through the shell above the button, if you don't see it and you try running the script again"
    echo "and get the same error (and turning off and on again) then ask for help"
fi

# Clean up things that shouldn't be there anymore
echo -e "${GREEN}Cleaning up unnecessary files...${NC}"
sudo rm -rf /var/tensorflow /var/periscope
sudo apt-get --purge remove -y libilmbase-dev libopenexr-dev libgstreamer1.0-dev protobuf-compiler qt4-dev-tools python-tk

# Install OpenCV Dependencies
echo -e "${GREEN}Installing OpenCV dependencies...${NC}"
sudo apt-get install -y build-essential git cmake pkg-config
sudo apt-get install -y libjpeg-dev libtiff5-dev libjasper-dev libpng12-dev
sudo apt-get install -y libavcodec-dev libavformat-dev libswscale-dev libv4l-dev
sudo apt-get install -y libxvidcore-dev libx264-dev
sudo apt-get install -y libgtk2.0-dev
sudo apt-get install -y libatlas-base-dev gfortran
sudo apt-get install -y python2.7-dev python3-dev python3-pip
# Create hastcope dir
if [ ! -d "$HASTCOPE_DIR" ]; then
    echo -e "${GREEN}Creating Hastcope dir...${NC}"
    sudo git clone https://github.com/PabloL007/undefined.git "$HASTCOPE_DIR"
else
    echo -e "${GREEN}Hastcope dir already created, skipping...${NC}"
fi
sudo chmod -R 744 "$HASTCOPE_DIR"
sudo chown -R pi:pi "$HASTCOPE_DIR"
# Create hastcope virtual env
cd "$HASTCOPE_DIR" || exit
if [ ! -d "$HASTCOPE_DIR/venv" ]; then
    echo -e "${GREEN}Creating Hastcope virtual env...${NC}"
    virtualenv --system-site-packages -p python3 "$HASTCOPE_DIR/venv"
else
    echo -e "${GREEN}Hastcope virtual env already created, skipping...${NC}"
fi
source $HASTCOPE_DIR/venv/bin/activate
# Install hastcope requirements
if  [ $(python -c 'import sys; print ("1" if hasattr(sys, "real_prefix") else "0")') == 0 ]; then
    echo -e "${RED}Error: The script is not running in the hastcope python virtual environment, exiting...${NC}"
    exit
fi
pip install -r "$HASTCOPE_DIR/requirements.txt"

# Start hastcope on boot
if [ ! -f "/etc/init.d/hastcope" ]; then
  echo -e "${GREEN}Adding hastcope to init.d${NC}"
  sudo cp hastcope /etc/init.d/hastcope
  sudo chmod 744 /etc/init.d/hastcope
  sudo update-rc.d hastcope defaults
else
  echo -e "${GREEN}Hastcope has already been added to init.d, skipping...${NC}"
fi

# wget -O opencv.zip https://github.com/opencv/opencv/archive/3.4.8.zip
# unzip opencv.zip
# wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/3.4.8.zip
# unzip opencv_contrib.zip

# sudo pip3 install -U virtualenv virtualenvwrapper
# sudo rm -rf ~/.cache/pip

# sudo tee -a ~/.profile > /dev/null <<EOT
# # virtualenv and virtualenvwrapper
# export WORKON_HOME=$HOME/.virtualenvs
# source /usr/local/bin/virtualenvwrapper.sh
# EOT
# source ~/.profile
