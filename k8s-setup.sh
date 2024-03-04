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
cd /home/cloudinit
wget https://github.com/kubernetes-sigs/kubespray/archive/v2.12.3.tar.gz
tar xvf v2.12.3.tar.gz 

sudo chown -R cloudinit:cloudinit /home/cloudinit/kubespray-2.12.3/
sudo apt install -y python3-pip
sudo pip install -r /home/cloudinit/kubespray-2.12.3/requirements.txt 
sudo apt install -y sshpass
ansible-galaxy collection install ansible.posix

cp -rfp /home/cloudinit/kubespray-2.12.3/inventory/sample /home/cloudinit/kubespray-2.12.3/inventory/mycluster
cp -p /home/cloudinit/kubespray-2.12.3/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml /home/cloudinit/kubespray-2.12.3/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml.bk
# sed 's/^kube_version: v.*/kube_version: v1.27.0/' /home/cloudinit/kubespray-2.12.3/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml | sudo tee /home/cloudinit/kubespray-2.12.3/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml

cat <<EOF | tee /home/cloudinit/kubespray-2.12.3/inventory/mycluster/inventory.ini 
[all]
api1     ansible_host=192.168.240.240
api2     ansible_host=192.168.240.241
gpu1     ansible_host=192.168.240.242
# gpu2     ansible_host=192.168.240.243
# storage1 ansible_host=192.168.240.244
# storage2 ansible_host=192.168.240.245
# storage3 ansible_host=192.168.240.246
# access1  ansible_host=192.168.240.247

[all:vars]
ansible_ssh_port=22
ansible_ssh_user=cloudinit
ansible_ssh_pass=zaq12wsx

[kube-master]
api1
api2
gpu1

[etcd]
api1
api2
gpu1

[kube-node]
api1
api2
gpu1

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

wget https://github.com/natsukinull/myk8s-on-proxmox/archive/refs/heads/develop.zip
unzip /home/cloudinit/develop.zip
ansible-playbook -i /home/cloudinit/myk8s-on-proxmox-develop/ansible/hosts/inventory.ini /home/cloudinit/myk8s-on-proxmox-develop/ansible/playbook_preset_kubespray.yaml

# cd /home/cloudinit/kubespray-2.12.3
# ansible-playbook -i ./inventory/mycluster/inventory.ini ./cluster.yml -vvv -b

# sudo chown -R cloudinit:cloudinit /home/cloudinit/.ssh/

# mkdir /home/cloudinit/.kube
# sudo chown -R cloudinit:cloudinit /home/cloudinit/.kube
# sudo cp -p /etc/kubernetes/admin.conf /home/cloudinit/.kube/config
# sudo chown cloudinit:cloudinit /home/cloudinit/.kube/config
# sudo cp -p /etc/kubernetes/admin.conf /root/.kube/config

# ssh cloudinit@192.168.240.241 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 mkdir ~/.kube
# ssh cloudinit@192.168.240.241 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 sudo cp -p /etc/kubernetes/admin.conf $HOME/.kube/config
# ssh cloudinit@192.168.240.241 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 sudo chown cloudinit:cloudinit /home/cloudinit/.kube/config
# ssh cloudinit@192.168.240.241 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 sudo cp -p /etc/kubernetes/admin.conf /root/.kube/config

# sudo reboot