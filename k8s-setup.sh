#!/bin/bash

case $1 in
  "master01")
    ;;
  *)
    exit 255
    ;;
esac


wget https://github.com/kubespray/kubespray/archive/master.tar.gz
tar -zxvf master.tar.gz 

sudo chown -R cloudinit:cloudinit ~/kubespray-master/
sudo apt install -y python3-pip
sudo pip install -r ~/kubespray-master/requirements.txt 
sudo apt install -y sshpass
