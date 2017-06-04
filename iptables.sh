#!/bin/bash

# Install/Update and flush all current rules
yum install iptables -y
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


# Save and list settings:
service iptables save
service iptables restart
chkconfig --level 345 iptables on
iptables -vnL --line-numbers
