#!/bin/bash
# Prepare SD card with cloud-init for automation

set -e

BOOT_MOUNT="/media/$USER/boot"
HOSTNAME=$1
IP=$2

if [ -z "$HOSTNAME" ] || [ -z "$IP" ]; then
    echo "Usage: $0 <hostname> <ip>"
    echo "Example: $0 pi-master 192.168.0.120"
    exit 1
fi

# Enable SSH
touch "$BOOT_MOUNT/ssh"

# Create user-data for cloud-init
cat > "$BOOT_MOUNT/user-data" << EOF
#cloud-config
hostname: $HOSTNAME

users:
  - name: hezekiah
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - $(cat ~/.ssh/keys/hobby/pi_k3s_cluster.pub)

packages:
  - python3

runcmd:
  - 'echo "$IP $(hostname)" >> /etc/hosts'
  - 'sed -i "$ s/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/" /boot/cmdline.txt'
EOF

# Create network-config
cat > "$BOOT_MOUNT/network-config" << EOF
version: 2
ethernets:
  eth0:
    dhcp4: true
    dhcp6: false
EOF

echo "✅ SD card prepared for $HOSTNAME"