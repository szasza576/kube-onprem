#!/bin/bash

PodCIDR="172.16.0.0/16"
ServiceCDR="172.17.0.0/16"
IngressRange="192.168.0.140-192.168.0.149"

#Configure master node
sudo systemctl enable kubelet
sudo kubeadm config images pull

sudo kubeadm init \
  --pod-network-cidr=$PodCIDR \
  --service-cidr=$ServiceCDR \
  --control-plane-endpoint=kubemaster

mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl taint nodes kubemaster node-role.kubernetes.io/master-

#Configre Calico as network plugin
kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml

curl https://docs.projectcalico.org/manifests/custom-resources.yaml -s -o /tmp/custom-resources.yaml
sed -i "s+192.168.0.0/16+$PodCIDR+g" /tmp/custom-resources.yaml
kubectl create -f /tmp/custom-resources.yaml
rm /tmp/custom-resources.yaml


#Configure MetalLB
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - $IngressRange
EOF


# Install Helm
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -

echo "deb https://baltocdn.com/helm/stable/debian/ all main" | \
sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

sudo apt update
sudo apt install -y helm


# Setup NFS share if needed
sudo apt install -y nfs-kernel-server
sudo mkdir -p /mnt/k8s-pv-data
sudo chown -R nobody:nogroup /mnt/k8s-pv-data/
sudo chmod 777 /mnt/k8s-pv-data/

sudo tee -a /etc/exports<<EOF
/mnt/k8s-pv-data  192.168.0.128/25(rw,sync,no_subtree_check)
EOF

sudo exportfs -a
sudo systemctl restart nfs-kernel-server

# Install NFS-provisioner
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    -n kube-system \
    --set nfs.server=192.168.0.128 \
    --set nfs.path=/mnt/k8s-pv-data \
    --set storageClass.name=default \
    --set storageClass.defaultClass=true

## Install NVIDIA device plugin
sudo apt install -y nvidia-driver-510 nvidia-cuda-toolkit

kubectl create -f https://github.com/kubernetes/kubernetes/raw/master/cluster/addons/device-plugins/nvidia-gpu/daemonset.yaml
kubectl label nodes kubemaster cloud.google.com/gke-accelerator=gpu