#!/bin/bash

echo -e "\e[91m############################################################"
echo -e "WARNING: Este script realiza las siguientes configuraciones:\e[0m"
echo " |_ Firewall:"
echo "    |_ iptables -> eliminará toda regla y establecerá nueva configuración"
echo " |_ Usuario:"
echo "    |_ creación de nuevo usuario con permisos de root"
echo " |_ SSH:"
echo "    |_ copiado de la clave .pub en authorized_keys"
echo "    |_ configuración de sshd"
echo "       |_ no se permitirá ssh con contraseña (sólo con clave hernani.pem)"
echo " |_ IPv6: se inhabilitará IPv6"
echo " |_yum-cron: instalación y configuración para actualizaciones automáticas"
echo ""

# ARE YOU ROOT (or sudo)?
if [[ $EUID -ne 0 ]]; then
	echo -e "\e[91mERROR: This script must be run as root\e[0m"
	exit 1
fi

centos_version=$(rpm -qa \*-release | grep -Ei "oracle|redhat|centos" | sed 's/[^6-8]*//g' | cut -c1)

# WARNING:
echo -e "\e[91mIMPORTANTE: Sólo se podrá acceder por ssh con el nuevo usuario creado a continuación y haciendo uso de la clave hernani.pem, no se podrá acceder como root ni usando contraseña con ningún usuario. El equipo será reiniciado a la finalización de este script.\e[0m"

# CONTINUE OR NOT?
read -r -p "Continue? [y/N] " response
res=${response,,} # tolower
if ! [[ $res =~ ^(yes|y)$ ]]; then
	echo "Proceso abortado"
	exit 1
fi


# Install EPEL and some basics:
yum install wget -y

if [ "$centos_version" -eq 6 ]; then
	wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
elif [ "$centos_version" -eq 7 ]; then
	wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
else
	wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
fi
yum install ./epel-release-latest-*.noarch.rpm -y
rm ./epel-release-latest-*.noarch.rpm -f

yum install net-tools nmap nano mlocate -y
updatedb # updates locate database


# We need to execute some bash scripts with execution permissions:
chmod u+x *.sh


# FIREWALL: iptables
./iptables.sh


# NEW USER:
./useradd.sh


# ssh: motd and sshd config
\cp rc.local /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local
rm -f /etc/motd /etc/issu*

sed -i "s|#PermitRootLogin yes|PermitRootLogin without-password|g" /etc/ssh/sshd_config
sed -i "s|PermitRootLogin yes|PermitRootLogin without-password|g" /etc/ssh/sshd_config
sed -i "s|PasswordAuthentication yes|PasswordAuthentication no|g" /etc/ssh/sshd_config
service sshd restart


# CHANGE HOSTNAME:
./change_hostname.sh


# DISABLE IPv6 NETWORKING:
if ifconfig | grep inet6; then
	echo "IPv6 is enabled. Disabling..."
	echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
	sysctl -p # restart sysctl
fi


# AUTO-UPDATES: yum-cron
if [ "$centos_version" -eq 6 ]; then
	yum install yum-cron -y
	sed -i "s|CHECK_ONLY=yes|CHECK_ONLY=no|g" /etc/sysconfig/yum-cron
	service yum-cron restart
	service crond start
	chkconfig yum-cron on
elif [ "$centos_version" -eq 7 ]; then
	yum install yum-cron -y
	sed -i "s|apply_updates = no|apply_updates = yes|g" /etc/yum/yum-cron.conf
	systemctl restart yum-cron
	systemctl start crond
	systemctl enable yum-cron
fi


# CAMBIO ZONA HORARIA y sincronizacion de hora:
if [ "$centos_version" -eq 7 ]; then
	timedatectl set-timezone Europe/Madrid
elif [ "$centos_version" -eq 8 ]; then
	timedatectl set-timezone Europe/Madrid
fi


# NANO, colorines:
for f in /usr/share/nano/*.nanorc; do
	echo "include $f" >> /root/.nanorc
done


# ALIAS:
alias cp='cp -i'
alias grep='grep --color=auto'
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias mv='mv -i'
alias rm='rm -i'


# REBOOT:
echo "Solo podra acceder por ssh con el usuario recien creado usando la clave hernani.pem"
echo "Rebooting now. Have a nice day ;)"
reboot
