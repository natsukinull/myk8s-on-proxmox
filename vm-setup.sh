TARGET_BRANCH=$1
TEMPLATE_VMID=4999
# CLOUDINIT_IMAGE_TARGET_VOLUME=CephPool01
CLOUDINIT_IMAGE_TARGET_VOLUME=local-lvm
# TEMPLATE_BOOT_IMAGE_TARGET_VOLUME=CephPool01
TEMPLATE_BOOT_IMAGE_TARGET_VOLUME=local-lvm
# BOOT_IMAGE_TARGET_VOLUME=CephPool01
BOOT_IMAGE_TARGET_VOLUME=local-lvm
SNIPPET_TARGET_VOLUME=local
SNIPPET_TARGET_PATH=/mnt/pve/${SNIPPET_TARGET_VOLUME}/snippets
REPOSITORY_RAW_SOURCE_URL="https://raw.githubusercontent.com/natsukinull/myk8s-on-proxmox/${TARGET_BRANCH}"

# download the image(ubuntu 22.04 LTS)
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

qm create $TEMPLATE_VMID --cores 2 --memory 4096 --net0 virtio,bridge=vmbr1 --name template-cp

# import the downloaded disk to $TEMPLATE_BOOT_IMAGE_TARGET_VOLUME storage
qm importdisk $TEMPLATE_VMID jammy-server-cloudimg-amd64.img $TEMPLATE_BOOT_IMAGE_TARGET_VOLUME

# finally attach the new disk to the VM as scsi drive
qm set $TEMPLATE_VMID --scsihw virtio-scsi-pci --scsi0 $TEMPLATE_BOOT_IMAGE_TARGET_VOLUME:vm-$TEMPLATE_VMID-disk-0

# add Cloud-Init CD-ROM drive
qm set $TEMPLATE_VMID --ide2 $CLOUDINIT_IMAGE_TARGET_VOLUME:cloudinit

# set the bootdisk parameter to scsi0
qm set $TEMPLATE_VMID --boot c --bootdisk scsi0

# set serial console & agent enabled
qm set $TEMPLATE_VMID --serial0 socket --vga serial0 --agent enabled=1

# migrate to template
qm template $TEMPLATE_VMID

# cleanup
rm jammy-server-cloudimg-amd64.img

VM_LIST=(
    # ---
    # vmid:       proxmox上でVMを識別するID
    # vmname:     proxmox上でVMを識別する名称およびホスト名
    # cpu:        VMに割り当てるコア数(vCPU)
    # mem:        VMに割り当てるメモリ(MB)
    # vmsrvip:    VMのService Segment側NICに割り振る固定IP
    # targetip:   VMの配置先となるProxmoxホストのIP
    # targethost: VMの配置先となるProxmoxホストのホスト名
    # ---
    #vmid #vmname      #cpu #mem  #vmsrvip    #targetip    #targethost
    "5000 master01  2    2048  192.168.240.220  192.168.200.207 pve"
    "5001 master02  2    2048  192.168.240.221  192.168.200.207 pve"
    "5002 master03  2    2048  192.168.240.222  192.168.200.207 pve"
    # "5003 worker01  2    2048  192.168.240.223  192.168.200.207 pve"
    # "5004 worker02  2    2048  192.168.240.224  192.168.200.207 pve"
    # "5005 worker03  2    2048  192.168.240.225  192.168.200.207 pve"
    # "5006 storage01 2    2048  192.168.240.226  192.168.200.207 pve"
    # "5007 storage02 2    2048  192.168.240.227  192.168.200.207 pve"
    # "5008 storage03 2    2048  192.168.240.228  192.168.200.207 pve"
    # "5009 access01  2    2048  192.168.240.229  192.168.200.207 pve"
)

for array in "${VM_LIST[@]}"
do
    echo "${array}" | while read -r vmid vmname cpu mem vmsrvip targetip targethost
    do
        # ここで何らかの処理を行う。例えば変数を出力する。
        echo "VM ID: ${vmid}, Name: ${vmname}, CPU: ${cpu}, Memory: ${mem}MB, Service IP: ${vmsrvip}, Target IP: ${targetip}, Host: ${targethost}"

                # clone from template
        # in clone phase, can't create vm-disk to local volume
        qm clone "${TEMPLATE_VMID}" "${vmid}" --name "${vmname}" --full true --target "${targethost}"
        
        # set compute resources
        ssh -n "${targetip}" qm set "${vmid}" --cores "${cpu}" --memory "${mem}"

        # move vm-disk to local
        ssh -n "${targetip}" qm move-disk "${vmid}" scsi0 "${BOOT_IMAGE_TARGET_VOLUME}" --delete true

        # resize disk (Resize after cloning, because it takes time to clone a large disk)
        ssh -n "${targetip}" qm resize "${vmid}" scsi0 30G

# ----- #
cat > "$SNIPPET_TARGET_PATH"/"$vmname"-user.yaml << EOF
#cloud-config
hostname: ${vmname}
timezone: Asia/Tokyo
manage_etc_hosts: true
chpasswd:
  expire: False
users:
  - default
  - name: cloudinit
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    # mkpasswd --method=SHA-512 --rounds=4096
    # password is zaq12wsx
    passwd: \$6\$rounds=4096\$Xlyxul70asLm\$9tKm.0po4ZE7vgqc.grptZzUU9906z/.vjwcqz/WYVtTwc5i2DWfjVpXb8HBtoVfvSY61rvrs/iwHxREKl3f20
ssh_pwauth: true
ssh_authorized_keys: []
package_upgrade: true
runcmd:
  # set ssh_authorized_keys
  - su - cloudinit -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
  - su - cloudinit -c "curl -sS https://github.com/natsukinull.keys >> ~/.ssh/authorized_keys"
  - su - cloudinit -c "chmod 600 ~/.ssh/authorized_keys"
  # run install scripts
  - su - cloudinit -c "curl -s ${REPOSITORY_RAW_SOURCE_URL}/k8s-setup.sh > ~/k8s-setup.sh"
  - su - cloudinit -c "sudo bash ~/k8s-setup.sh ${vmname}"
  # change default shell to bash
  - chsh -s $(which bash) cloudinit
EOF
# ----- #
        # END irregular indent because heredoc

        # create snippet for cloud-init(network-config)
        # START irregular indent because heredoc
# ----- #
cat > "$SNIPPET_TARGET_PATH"/"$vmname"-network.yaml << EOF
version: 1
config:
  - type: physical
    name: ens18
    subnets:
    - type: static
      address: '${vmsrvip}'
      netmask: '255.255.255.0'
      gateway: '192.168.240.1'
  - type: nameserver
    address:
    - '8.8.8.8'
    search:
    - 'local'
EOF
# ----- #
        # END irregular indent because heredoc

        # set snippet to vm
        ssh -n "${targetip}" qm set "${vmid}" --cicustom "user=${SNIPPET_TARGET_VOLUME}:snippets/${vmname}-user.yaml,network=${SNIPPET_TARGET_VOLUME}:snippets/${vmname}-network.yaml"

    done
done

for array in "${VM_LIST[@]}"
do
    echo "${array}" | while read -r vmid vmname cpu mem vmsrvip targetip targethost
    do
        # start vm
        ssh -n "${targetip}" qm start "${vmid}"
        
    done
done
