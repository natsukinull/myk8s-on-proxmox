#!/bin/bash

case $1 in
  "master01")
    sudo apt install -y qemu-guest-agent
    ;;
  *)
    sudo apt install -y qemu-guest-agent
    sudo reboot 
    exit 255
    ;;
esac


sudo apt install -y unzip
wget https://github.com/kubernetes-sigs/kubespray/archive/refs/heads/release-2.24.zip
unzip /home/cloudinit/release-2.24.zip

sudo chown -R cloudinit:cloudinit /home/cloudinit/kubespray-release-2.24/
sudo apt install -y python3-pip
sudo pip install -r /home/cloudinit/kubespray-release-2.24/requirements.txt 
sudo apt install -y sshpass
ansible-galaxy collection install ansible.posix

cp -rfp /home/cloudinit/kubespray-release-2.24/inventory/sample /home/cloudinit/kubespray-release-2.24/inventory/mycluster
cp -p /home/cloudinit/kubespray-release-2.24/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml /home/cloudinit/kubespray-release-2.24/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml.bk
sed 's/^kube_version: v.*/kube_version: v1.27.0/' /home/cloudinit/kubespray-release-2.24/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml | sudo tee /home/cloudinit/kubespray-release-2.24/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml

cat <<EOF | tee /home/cloudinit/kubespray-release-2.24/inventory/mycluster/inventory.ini 
[all]
master01 ansible_host=192.168.240.220  
master02 ansible_host=192.168.240.221  
master03 ansible_host=192.168.240.222
worker01 ansible_host=192.168.240.223
worker02 ansible_host=192.168.240.224
worker03 ansible_host=192.168.240.225
storage01 ansible_host=192.168.240.226
storage02 ansible_host=192.168.240.227
storage03 ansible_host=192.168.240.228
access01 ansible_host=192.168.240.229

[all:vars]
ansible_ssh_port=22
ansible_ssh_user=cloudinit
ansible_ssh_pass=zaq12wsx

[kube-master]
master01
master02
master03

[etcd]
storage01
storage02
storage03

[kube-node]
worker01
worker02
worker03

[calico-rr]

[k8s-cluster:children]
kube-master
kube-node
calico-rr
EOF


cat <<EOF | tee /home/cloudinit/.ansible.cfg
[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
EOF

cat <<EOF | tee /root/.ansible.cfg
[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
EOF

wget https://github.com/natsukinull/myk8s-on-proxmox/archive/refs/heads/stg.zip
unzip /home/cloudinit/stg.zip
ansible-playbook -i /home/cloudinit/myk8s-on-proxmox-stg/ansible/hosts/inventory.ini /home/cloudinit/myk8s-on-proxmox-stg/ansible/playbook_preset_kubespray.yaml

cd /home/cloudinit/kubespray-release-2.24
ansible-playbook -i ./inventory/mycluster/inventory.ini ./cluster.yml -vvv -b

sudo chown -R cloudinit:cloudinit /home/cloudinit/.ssh/

mkdir /home/cloudinit/.kube
sudo chown -R cloudinit:cloudinit /home/cloudinit/.kube
sudo cp -p /etc/kubernetes/admin.conf /home/cloudinit/.kube/config
sudo chown cloudinit:cloudinit /home/cloudinit/.kube/config
sudo cp -p /etc/kubernetes/admin.conf /root/.kube/config

ssh cloudinit@192.168.240.221 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 mkdir ~/.kube
ssh cloudinit@192.168.240.221 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 sudo cp -p /etc/kubernetes/admin.conf $HOME/.kube/config
ssh cloudinit@192.168.240.221 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 sudo chown cloudinit:cloudinit /home/cloudinit/.kube/config
ssh cloudinit@192.168.240.221 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 sudo cp -p /etc/kubernetes/admin.conf /root/.kube/config

ssh cloudinit@192.168.240.222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 mkdir ~/.kube
ssh cloudinit@192.168.240.222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 sudo cp -p /etc/kubernetes/admin.conf $HOME/.kube/config
ssh cloudinit@192.168.240.222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 sudo chown cloudinit:cloudinit /home/cloudinit/.kube/config
ssh cloudinit@192.168.240.222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 sudo cp -p /etc/kubernetes/admin.conf /root/.kube/config

sudo reboot