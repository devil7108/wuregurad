#/bin/bash
#更新内核
update_kernel(){
 
    yum -y install epel-release curl wget git
    sed -i "0,/enabled=0/s//enabled=1/" /etc/yum.repos.d/epel.repo
    yum remove -y kernel-devel
    rpm -Uvh http://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm
    rpm --import http://elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm
    yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
    yum -y --enablerepo=elrepo-kernel install kernel-ml
    sed -i "s/GRUB_DEFAULT=saved/GRUB_DEFAULT=0/" /etc/default/grub
    grub2-mkconfig -o /boot/grub2/grub.cfg
    yum -y --enablerepo=elrepo-kernel install kernel-ml-devel
    read -p "须要重启VPS，再次执行脚本选择安装wireguard，是否如今重启 ? [Y/n] :" yn
	[ -z "${yn}" ] && yn="y"
	if [[ $yn == [Yy] ]]; then
		echo -e "VPS 重启中..."
		reboot
	fi
}
 
#生成随机端口
rand(){
    min=$1
    max=$(($2-$min+1))
    num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')
    echo $(($num%$max+$min))  
}
 
wireguard_update(){
    yum update -y wireguard-dkms wireguard-tools
    echo "更新完成"
}

wireguard_remove(){
    wg-quick down wg0
    yum remove -y wireguard-dkms wireguard-tools
    rm -rf /etc/wireguard/
    echo "卸载完成"
}

config_client(){
cat > /etc/wireguard/client.conf <<-EOF
[Interface]
PrivateKey = $c1
Address = 10.0.0.2/24 
DNS = 8.8.8.8
MTU = 1420
 
[Peer]
PublicKey = $s2
Endpoint = $serverip:$port
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF

}

#centos7-8wireguard

wireguard_install(){

curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-8/jdoss-wireguard-epel-8.repo

yum install -y dkms gcc-c++ gcc-gfortran glibc-headers glibc-devel libquadmath-devel libtool systemtap systemtap-devel  qrencode wget git bash-completion

yum install wireguard-dkms wireguard-tools kmod-wireguard
 
mkdir /etc/wireguard

cd /etc/wireguard

wg genkey | tee sprivatekey | wg pubkey > spublickey

wg genkey | tee cprivatekey | wg pubkey > cpublickey

s1=$(cat sprivatekey)

s2=$(cat spublickey)

c1=$(cat cprivatekey)

c2=$(cat cpublickey)

serverip=$(curl ipv4.icanhazip.com)

port=$(rand 10000 60000)

eth=$(ls /sys/class/net | awk '/^e/{print}')

chmod 777 -R /etc/wireguard

systemctl enable firewalld.service

systemctl restart firewalld.service 

firewall-cmd --set-default-zone=public
firewall-cmd --add-interface=$ETH
firewall-cmd --zone=public --add-interface=wg0
firewall-cmd --add-masquerade  --zone=public --permanent
firewall-cmd --add-port=1701/udp --permanent
firewall-cmd --add-port=4500/udp --permanent
firewall-cmd --permanent --direct --passthrough ipv4 -t nat -I POSTROUTING -o eth0 -j MASQUERADE -s 10.7.7.7/24
firewall-cmd --permanent --add-port=0-65535/udp --zone=public
firewall-cmd --reload

echo "1" > /proc/sys/net/ipv4/ip_forward

echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

sysctl -p

cat > /etc/wireguard/wg0.conf <<-EOF

[Interface]
PrivateKey = $s1
Address = 10.0.0.1/24 
PostUp = firewall-cmd --zone=public --add-port 1701/udp && firewall-cmd --zone=public --add-masquerade
PostDown = firewall-cmd --zone=public --add-port 4500/udp && firewall-cmd --zone=public --add-masquerade
ListenPort = $port
DNS = 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $c2
AllowedIPs = 10.0.0.2/32
PersistentKeepalive = 25
EOF

config_client

wg-quick up wg0

wg-quick down wg0

systemctl enable wg-quick@wg0

systemctl restart wg-quick@wg0

systemctl status wg-quick@wg0

modprobe wireguard

content=$(cat /etc/wireguard/client.conf)

echo "电脑端请下载client.conf，手机端可直接使用软件扫码"

echo "${content}" | qrencode -o - -t UTF8

}

add_user(){

echo -e "\033[37;41m给新用户起个名字，不能和已有用户重复\033[0m"

read -p "请输入用户名：" newname

cd /etc/wireguard/

cp client.conf $newname.conf

wg genkey | tee temprikey | wg pubkey > tempubkey

ipnum=$(grep Allowed /etc/wireguard/wg0.conf | tail -1 | awk -F '[ ./]' '{print $6}')

newnum=$((10#${ipnum}+1))

sed -i 's%^PrivateKey.*$%'"PrivateKey = $(cat temprikey)"'%' $newname.conf

sed -i 's%^Address.*$%'"Address = 10.0.0.$newnum\/24"'%' $newname.conf

cat >> /etc/wireguard/wg0.conf <<-EOF

[Peer]
PublicKey = $(cat tempubkey)
AllowedIPs = 10.0.0.$newnum/24
PersistentKeepalive = 25
EOF

wg set wg0 peer $(cat tempubkey) allowed-ips 10.0.0.$newnum/32

echo -e "\033[37;41m添加完成，文件：/etc/wireguard/$newname.conf\033[0m"

rm -f temprikey tempubkey

}

#开始菜单
start_menu(){
    clear
    echo "========================="
    echo " 介绍：CentOS8"
    echo " 网站：www.fson.net"
    echo "========================="
    echo "1. 升级系统内核"
    echo "2. 安装wireguard"
    echo "3. 升级wireguard"
    echo "4. 卸载wireguard"
    echo "5. 显示客户端二维码"
    echo "6. 增长用户"
    echo "0. 退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
    	1)
	update_kernel
	;;
	2)
	wireguard_install
	;;
	3)
	wireguard_update
	;;
	4)
	wireguard_remove
	;;
	5)
	content=$(cat /etc/wireguard/client.conf)
    	echo "${content}" | qrencode -o - -t UTF8
	;;
	6)
	add_user
	;;
	0)
	exit 1
	;;
	*)
	clear
	echo "请输入正确数字"
	sleep 5s
	start_menu
	;;
    esac
}
 
start_menu
把上面的代码复制到脚步文件如install


=========================
 介绍：适用于CentOS8
 做者：Linuas + Fans 
 网站：www.fson.net
=========================
1. 升级系统内核
2. 安装wireguard
3. 升级wireguard
4. 卸载wireguard
5. 显示客户端二维码
6. 增长用户
0. 退出
