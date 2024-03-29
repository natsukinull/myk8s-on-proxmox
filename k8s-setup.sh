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
master01 ansible_host=192.168.100.220  
master02 ansible_host=192.168.100.221  
master03 ansible_host=192.168.100.222  
# ## configure a bastion host if your nodes are not directly reachable
# [bastion]
# bastion ansible_host=x.x.x.x ansible_user=some_user

[all:vars]
ansible_ssh_port=22
ansible_ssh_user=cloudinit
ansible_ssh_pass=zaq12wsx

[kube-master]
master01
master02
master03

[etcd]
master01
master02
master03

[kube-node]
master03

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

wget https://github.com/natsukinull/myk8s-on-proxmox/archive/refs/heads/main.zip
unzip /home/cloudinit/main.zip
ansible-playbook -i /home/cloudinit/myk8s-on-proxmox-main/ansible/hosts/inventory.ini /home/cloudinit/myk8s-on-proxmox-main/ansible/playbook_preset_kubespray.yaml


ansible-playbook -i /home/cloudinit/kubespray-release-2.24/inventory/mycluster/inventory.ini /home/cloudinit/kubespray-release-2.24/cluster.yml -vvv -b
