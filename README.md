# Instructions
1. Turn on by pressing the button once (it can be turned off by pressing it twice)
2. Connect to the "hastcope" wifi hotspot
3. Ssh to 192.168.3.254
4. Run the following commands:
```shell
HASTCOPE_DIR=/var/hastcope
sudo git clone https://github.com/PabloL007/undefined.git "$HASTCOPE_DIR"
sudo chmod +x $HASTCOPE_DIR/reconfigure.sh
$HASTCOPE_DIR/reconfigure.sh
```