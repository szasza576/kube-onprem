#!/bin/bash

PSK="testkey123"
HomeIP="188.6.114.113"
AzureIP="20.107.68.29"

#General update
sudo apt-get update
sudo apt-get upgrade -y

#Install base tools
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    mc \
    curl \
    net-tools \
    strongswan

#Reconfigure sysctl
sudo tee /etc/sysctl.d/router.conf << EOF
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
EOF

sudo sysctl --system


#Configure strongswan
echo "$HomeIP $AzureIP : PSK "'"'$PSK'"' | sudo tee -a /etc/ipsec.secrets
sudo cp /etc/ipsec.conf /etc/ipsec.conf.back

sudo curl https://raw.githubusercontent.com/szasza576/kube-onprem/main/vpn-router/ipsec.conf -o /etc/ipsec.conf
sudo sed -i "s+<HomeIP>+$HomeIP+g" /etc/ipsec.conf
sudo sed -i "s+<AzureVPNGW>+$AzureIP+g" /etc/ipsec.conf

sudo curl https://raw.githubusercontent.com/szasza576/kube-onprem/main/vpn-router/ipsec-notify.sh -o /usr/local/sbin/ipsec-notify.sh
sudo chown strongswan:users /usr/local/sbin/ipsec-notify.sh
sudo chmod 755 /usr/local/sbin/ipsec-notify.sh

sudo apparmor_parser -R /etc/apparmor.d/usr.lib.ipsec.charon
sudo apparmor_parser -R /etc/apparmor.d/usr.lib.ipsec.stroke
sudo ln -s /etc/apparmor.d/usr.lib.ipsec.charon /etc/apparmor.d/disable/
sudo ln -s /etc/apparmor.d/usr.lib.ipsec.stroke /etc/apparmor.d/disable/

sudo sed -i "s+# install_routes = yes+install_routes = no+g" /etc/strongswan.d/charon.conf

sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/8 -d 192.168.0.128/25 -j MASQUERADE

sudo ipsec restart
sudo systemctl enable strongswan-starter
sudo ipsec up azure



















sudo tee /etc/ipsec.conf << EOF
config setup
conn azure
    leftupdown=/usr/local/sbin/ipsec-notify.sh # Script to create a VTI and configure the necessary routing when doing "ipsec up azure" (and remove changes when doing "ipsec down azure"
    authby=secret
    type=tunnel
    left=$HomeIP # My Public IP address
    leftsubnet=192.168.0.128/25 # My IP address space / protected network(s)
    right=$AzureIP #Azure Dynamic Gateway
    rightsubnet=10.0.0.0/8 #Azure Vnet prefixes, coma separated list
    auto=route
    keyexchange=ikev2 # Mandatory for Dynamic / Route-based gateway
EOF