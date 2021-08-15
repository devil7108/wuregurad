#!/bin/bash                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    #!/bin/bash
#    Setup Simple  VPN server for CentOS 7 on LINUX- Unix system
#    Copyright (C) 2015-2022  and contributors
#
#    BONJOURS VERSIONER THANK YOU D-C OR PC FOR PP.



printhelp() {

echo "
Usage: ./pptp.sh [OPTION]
If you are using custom password , Make sure its more than 8 characters. Otherwise it will generate random password for you. 
If you trying set password only. It will generate Default user with Random password. 
example: ./pptp.sh -u myusr -p mypass
Use without parameter [ ./pptp.sh ] to use default username and Random password
  -u,    --username               Enter the Username
  -p,    --password                Enter the Password
"
}

while [ "$1" != "" ]; do
  case "$1" in
    -u    | --username )             NAME=$2; shift 2 ;;
    -p    | --password )              PASS=$2; shift 2 ;;
    -h    | --help )            echo "$(printhelp)"; exit; shift; break ;;
  esac
done

# Check if user is root
[ $(id -u) != "0" ] && { echo -e "\033[31mError: You must be root to run this script\033[0m"; exit 1; } 

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
clear

            yum  -y update
            yum  -y install firewalld net-tools curl ppp pptpd git wget dkms 
echo -e "You can now connect to your VPN via your external IP \033[32m${VPN_IP}\033[0m"
echo -e "Username: \033[32m${NAME}\033[0m"
echo -e "Password: \033[32m${PASS}\033[0m"
echo -e "You can now connect to your VPN via your external IP \033[32m${VPN_IP}\033[0m"
echo -e "Username: \033[32m${NAME}\033[0m"
echo -e "Password: \033[32m${PASS}\033[0m"
clear


cat >> /etc/ppp/chap-secrets <<END
$NAME pptpd $PASS *
END

cat >> /etc/pptpd.conf <<END
option /etc/ppp/options.pptpd
#logwtmp
localip 192.168.1.1
remoteip 192.168.1.10-100
END

cat > /etc/ppp/options.pptpd <<END
name pptpd
refuse-pap
refuse-chap
refuse-mschap
require-authentication
require-mschap-v2
require-mppe-128
ms-dns 8.8.8.8
ms-dns 1.1.1.1
proxyarp
pppotfile
lock
nobsdcomp
mtu 1400
nodefaultroute
debug
auth
noccp
novj
novjccomp
END

ETH=`route | grep default | awk '{print $NF}'`
firewall-cmd --set-default-zone=public
firewall-cmd --add-interface=$ETH
firewall-cmd --add-port=1723/tcp --permanent
firewall-cmd --add-masquerade --permanent
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -i $ETH -p gre -j ACCEPT
firewall-cmd --permanent --direct --passthrough ipv4 -t nat -I POSTROUTING -o eth0 -j MASQUER
firewall-cmd --permanent --add-port=0-65535/tcp --zone=public
firewall-cmd --reload




echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p


systemctl restart firewalld.service
systemctl enable firewalld.service
systemctl restart pptpd.service
systemctl enable pptpd.service
systemctl startus pptpd.service

chmod +777 /etc/ppp/ip-up.local
cat >> /etc/ppp/ip-up.local <<END
/sbin/ifconfig $1 mtu 1400
END



