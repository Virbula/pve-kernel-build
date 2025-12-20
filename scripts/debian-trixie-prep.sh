#!/bin/bash

# Must be run as root
[[ $EUID -eq 0 ]] || { echo "Must be root" >&2; exit 1; }


# Very simply script to install necessary base tools for building Proxmox PVE 
# kernel based on docker

# Some basic tools

apt-get update -y

apt install -y git make curl


# Install docker

#remove any default left over docker stuff, usually none
apt remove -y docker docker-engine docker.io containerd runc

# Install some base stuff for docker install
apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release


# gpg keyring for docker repo and create docker repo
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/debian/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg


echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian bookworm stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null


# install docker engine from docker.com

apt update -y
apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin


# enable, this is probably already done by the install
echo "Enabling docker service...."
systemctl enable docker
systemctl start docker

echo "All done............"
