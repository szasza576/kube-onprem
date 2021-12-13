#!/bin/bash

#Join to cluster
#Copy the join command from the master node or run this on master: kubeadm token create --print-join-command
sudo kubeadm join kubemaster:6443 --token yi3kpf.retdeyzmwuj6u9bp --discovery-token-ca-cert-hash sha256:c235e234d3e056dd46264ceb1c62c9c879b9c5311cf73a7406e15cf4962142aa


