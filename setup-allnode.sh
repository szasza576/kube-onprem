#!/bin/bash

K8sVersion="1.21.8-00"

#General update
sudo apt-get update
sudo apt-get upgrade -y

#Install base tools
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    gnupg2 \
    lsb-release \
    mc \
    curl \
    software-properties-common \
    net-tools

#Install kubelet, kubeadm, kubectl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt -y install vim git curl wget kubelet=$K8sVersion kubeadm=$K8sVersion kubectl=$K8sVersion
sudo apt-mark hold kubelet kubeadm kubectl

echo 'source <(kubectl completion bash)' >> /home/*/.bashrc

#Disable Swap
sudo sed -i '/swap/ s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a

#Configure hosts file and routes
echo "192.168.0.128 kubemaster" | sudo tee -a /etc/hosts
echo "192.168.0.129 kubenode" | sudo tee -a /etc/hosts

sudo ip route add 10.0.0.0/8 via 192.168.0.130


#Enable kernel modules and setup sysctl
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system


#Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl daemon-reload 
sudo systemctl restart docker
sudo systemctl enable docker

sudo usermod -aG docker $(ls /home/)
