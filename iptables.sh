#!/bin/bash

# Operative System:
os=$(grep ^ID= /etc/os-release | cut -d "=" -f 2)
os=${os,,} #tolower

# Install/Update and flush all current rules
if [[ $os =~ "centos" ]]; then # $os contains "centos"
	
	centos_version=$(rpm -qa \*-release | grep -Ei "oracle|redhat|centos" | sed 's/[^6-8]*//g' | cut -c1)
	
	if [ "$centos_version" -eq 6 ]; then
		yum install iptables -y
	else
		# Desactivamos firewalld (que viene por defecto en CentOS 7+)
		systemctl stop firewalld
		systemctl mask firewalld
		yum install iptables iptables-services -y
	fi
elif [[ $os =~ "ubuntu" ]]; then # $os contains "ubuntu"

	# ufw is inactive by default, we don't do anything with it
	apt install iptables-persistent netfilter-persistent -y
fi

iptables -F

# Set default policies for INPUT, FORWARD and OUTPUT chains
iptables -P INPUT DROP    # OJO! que nos podemos quedar sin conexión ssh
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Acceso desde localhost
iptables -A INPUT -i lo -j ACCEPT

# Acceso para ssh y http
iptables -I INPUT -p tcp --dport 22 -j ACCEPT
#iptables -I INPUT -p tcp --dport 80 -j ACCEPT

# SEGURIDAD PARA SSH:
# 3 logins incorrectos desde la misma IP en una ventana de tiempo de 5 mins
# bloqueará dicha IP hasta que pase la ventana de tiempo desde el primer login
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 300 --hitcount 3 -j DROP

# Acceso para icmp desde área local:
iptables -A INPUT -s 192.168.0.0/16 -p icmp -j ACCEPT
iptables -A INPUT -s 10.0.0.0/8 -p icmp -j ACCEPT

# Accept packets belonging to established and related connections:
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT


# Save settings, restart service and enable on boot:
if [[ $os =~ "ubuntu" ]]; then
	netfilter-persistent save # saves in /etc/iptables/rules.v4
	systemctl restart netfilter-persistent
	systemctl enable  netfilter-persistent

elif [ "$centos_version" -eq 6 ]; then
	iptables-save
	service iptables restart
	chkconfig --level 345 iptables on
else
	iptables-save
	systemctl restart iptables
	systemctl enable  iptables.service
fi

iptables -vnL --line-numbers
