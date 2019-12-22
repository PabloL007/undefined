#!/bin/bash

sudo update-rc.d -f servicename remove
sudo rm -rf /etc/init.d/hastcope
sudo rm -rf /var/hastcope/