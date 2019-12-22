#!/bin/bash

# Setup wlan0 to connect to wifi
if [ $(sudo grep -c "network" /etc/wpa_supplicant/wpa_supplicant.conf) == 0 ]; then
    echo "This device should be connected to a wireless network, please provide the details bellow"
    read -p "SSID: " wifi_ssid
    read -sp "Passphrase: " wifi_passphrase
    wpa_passphrase $wifi_ssid $wifi_passphrase | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
    sudo sed -ri 's/^.+#psk=.+$//g' /etc/wpa_supplicant/wpa_supplicant.conf
    wpa_cli -i wlan0 reconfigure
else
    echo "Connection to house wifi has already been configured. Skipping..."
fi

# Update and upgrade
sudo apt-get update && sudo apt-get upgrade -y

# Check if wlan1 is available
if [ $(ifconfig | grep -c "wlan1") == 1 ]; then
    # Fix the wifi adapter driver
    if test ! -f /usr/bin/install-wifi; then
        echo "Fixing the wifi adapter driver"
        sudo apt purge -y firmware-realtek
        sudo wget http://downloads.fars-robotics.net/wifi-drivers/install-wifi -O /usr/bin/install-wifi
        sudo chmod +x /usr/bin/install-wifi
        sudo install-wifi
    else
        echo "The wifi adapter driver has already been fixed. Skipping..."
    fi
    # Setup wlan1 to serve a hotspot
    if [ $(sudo grep -c "iptables-restore" /etc/rc.local) == 0 ]; then
        echo "Configuring the wifi hotspot"
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
        echo "Wifi hotstpot has already been configured. Skipping..."
    fi
else
    echo "Wifi hotstpot can't be configured as no adapter was detected"
fi

# Setup camera
if [ $(sudo raspi-config nonint get_camera) != 0 ]; then
    echo "Enabling camera..."
    sudo raspi-config nonint do_camera 0
else
    echo "Camera has already been enabled. Skipping..."
fi

# Install tensorflow dependencies
sudo apt-get install -y python3-dev python3-pip libjpeg8-dev
sudo apt install -y libatlas-base-dev
sudo pip3 install -U virtualenv

# Create virtual env
PERISCOPE_DIR=/var/periscope
sudo mkdir -p $PERISCOPE_DIR
sudo chmod -R 744 $PERISCOPE_DIR
sudo chown -R pi:pi $PERISCOPE_DIR
cd $PERISCOPE_DIR
virtualenv --system-site-packages -p python3 $PERISCOPE_DIR/venv
source $PERISCOPE_DIR/venv/bin/activate
pip3 install --upgrade pip
# Install the tensorflow pip package
pip install --upgrade tensorflow
sudo pip3 install pillow lxml jupyter matplotlib cython
sudo apt-get install -y python-tk
# Install OpenCV
sudo apt-get install -y libjpeg-dev libtiff5-dev libjasper-dev libpng12-dev
sudo apt-get install -y libavcodec-dev libavformat-dev libswscale-dev libv4l-dev
sudo apt-get install -y libxvidcore-dev libx264-dev
sudo apt-get install -y qt4-dev-tools libatlas-base-dev
sudo pip3 install opencv-python==3.4.6.27
# Install Protobuf
sudo apt-get install protobuf-compiler
# Setup tensorflow dir
TENSORFLOW_DIR=/var/tensorflow
sudo mkdir -p $TENSORFLOW_DIR
sudo chmod -R 744 $TENSORFLOW_DIR
sudo chown -R pi:pi $TENSORFLOW_DIR
cd $TENSORFLOW_DIR
git clone --depth 1 https://github.com/tensorflow/models.git
export PYTHONPATH=$PYTHONPATH:$TENSORFLOW_DIR/models/research:$TENSORFLOW_DIR/models/research/slim
cd $TENSORFLOW_DIR/models/research
protoc $TENSORFLOW_DIR/object_detection/protos/*.proto --python_out=.
cd $TENSORFLOW_DIR/models/research/object_detection
wget http://download.tensorflow.org/models/object_detection/ssdlite_mobilenet_v2_coco_2018_05_09.tar.gz
tar -xzvf ssdlite_mobilenet_v2_coco_2018_05_09.tar.gz
wget https://raw.githubusercontent.com/EdjeElectronics/TensorFlow-Object-Detection-on-the-Raspberry-Pi/master/Object_detection_picamera.py
sudo apt-get install -y libilmbase-dev libopenexr-dev libgstreamer1.0-dev