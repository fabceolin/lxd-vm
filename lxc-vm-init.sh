#!/bin/bash

# Initialize LXC container with basic setup

set -a

source optparse.bash

optparse.define short=n long=name desc="Name of the image" variable=NAME default="jammy"
optparse.define short=i long=image desc="Image to use" variable=IMAGE default="ubuntu:j"
optparse.define short=v long=vm desc="Set flag for VM mode" variable=VM_MODE value=true default=false

source $( optparse.build )

sudo iptables -I DOCKER-USER -i lxdbr0 -o $(ip route | awk '/default/{print $5}') -j ACCEPT
sudo iptables -I DOCKER-USER -o lxdbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

ARGS=""
if [ "$VM_MODE" = true ]; then
  ARGS="--vm"
fi

lxc profile create ${NAME}
cat <<EOF | lxc profile edit ${NAME}
config: {}
devices:
  config:
    source: cloud-init:config
    type: disk
  eth0:
    nictype: bridged
    parent: lxdbr0
    type: nic
  root:
    path: /
    pool: default
    size: 40GB
    type: disk
EOF

lxc init $IMAGE $NAME -p $NAME $ARGS
cat <<EOF | lxc config set $NAME user.user-data -
#cloud-config
ssh_pwauth: True
ssh_enabled: True
users:
  - name: user
    groups:
      - sudo
      - lxd
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: false
    ssh-authorized-keys:
      - "ssh-rsa YOUR_PUBLIC_KEY_HERE"
growpart:
    mode: auto
    devices: ['/']
    ignore_growroot_disabled: false
package_update: true
package_upgrade: true
packages:
  - build-essential
  - git
  - jq
  - moreutils
write_files:
  - path: /etc/default/generic-config
    content: |
      # Configuration settings
    owner: root
    permissions: '0644'
runcmd: 
  - |
    # Custom commands to run after container initialization
EOF

lxc start $NAME

