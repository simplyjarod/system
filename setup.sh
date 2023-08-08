#!/bin/bash

echo -e "\e[91mWARNING #######################################################"
echo -e "This script will perform the following actions:\e[0m"
echo " |_ SELinux: Disable SELinux for Ubuntu and CentOS 7 or greater"
echo " |_ Firewall: Elimina toda regla existente y configura iptables"
echo " |_ User: (opcional) Crea un nuevo usuario"
echo " |_ SSH:"
echo "    |_ Copia las claves de pub_keys/*.pub a .ssh/authorized_keys"
echo "    |_ Bloquea ssh con contraseña. Solo acceso con clave privada"
echo " |_ IPv6: Deshabilita IPv6"
echo " |_ yum-cron: Actualizaciones automáticas (solo en CentOS 6 y 7)"
echo 

# ARE YOU ROOT (or sudo)?
if [[ $EUID -ne 0 ]]; then
	echo -e "\e[91mERROR: This script must be run as root\e[0m"
	exit 1
fi

# WARNING:
echo -e "\e[91mIMPORTANTE: Sólo se podrá acceder por ssh con el usuario root o el nuevo usuario creado a continuación y haciendo uso de una de las claves privadas existentes en pub_keys. No se podrá acceder como root ni usando contraseña con ningún usuario. El equipo será reiniciado a la finalización de este script.\e[0m"

# CONTINUE OR NOT?
read -r -p "Continue? [y/N] " response
res=${response,,} # tolower
if ! [[ $res =~ ^(yes|y)$ ]]; then
	echo "Proceso abortado"
	exit 1
fi

# Operative System:
os=$(grep ^ID= /etc/os-release | cut -d "=" -f 2)
os=${os,,} #tolower


# Install EPEL and some basics:
if [[ $os =~ "centos" ]]; then # $os contains "centos"

	centos_version=$(rpm -qa \*-release | grep -Ei "oracle|redhat|centos" | sed 's/[^6-8]*//g' | cut -c1)

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

elif [[ $os =~ "ubuntu" ]]; then # $os contains "ubuntu"

	apt update -y && apt upgrade -y
	apt install wget net-tools nmap nano mlocate -y
	apt autoremove -y

else
	echo -e "\e[91mOS not detected. Nothing was done\e[0m"
	exit 1
fi


updatedb # updates locate database


# We need to execute some bash scripts with execution permissions:
chmod u+x *.sh


# Disable SELinux for Ubuntu and CentOS 7 or greater:
if [[ "$centos_version" -ge 7 ]]; then
	# In ubuntu, SELinux could be not installed/enabled, so this will show a warning (no problem)
	sed -i "s|SELINUX=enforcing|SELINUX=disabled|g" /etc/selinux/config
	sed -i "s|SELINUX=permissive|SELINUX=disabled|g" /etc/selinux/config
	setenforce 0
fi


# FIREWALL: iptables
./iptables.sh


# NEW USER:
read -r -p "Create new user? [y/N] " response
res=${response,,} # tolower
if [[ $res =~ ^(yes|y)$ ]]; then
	./useradd.sh
else
	mkdir -p /root/.ssh
	for f in pub_keys/*.pub; do (cat $f; echo '') >> /root/.ssh/authorized_keys; done
	chmod 700 /root/.ssh
	chmod 600 /root/.ssh/authorized_keys
fi


# ssh: motd and sshd config
if [[ $os =~ "centos" ]]; then # $os contains "centos"
	\cp rc.local /etc/rc.d/rc.local
	chmod +x /etc/rc.d/rc.local
	rm -f /etc/motd /etc/issu*
fi


# SSH security:
# Will change any line that starts by (commented or not), with space after it or not...
sed -i -e '/^\(#\|\)\s*PermitRootLogin/s/^.*$/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i -e '/^\(#\|\)\s*PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i -e '/^\(#\|\)\s*X11Forwarding/s/^.*$/X11Forwarding no/' /etc/ssh/sshd_config
sed -i -e '/^\(#\|\)\s*MaxAuthTries/s/^.*$/MaxAuthTries 5/' /etc/ssh/sshd_config
sed -i -e '/^\(#\|\)\s*AllowTcpForwarding/s/^.*$/AllowTcpForwarding no/' /etc/ssh/sshd_config
sed -i -e '/^\(#\|\)\s*AllowAgentForwarding/s/^.*$/AllowAgentForwarding no/' /etc/ssh/sshd_config
sed -i -e '/^\(#\|\)\s*AuthorizedKeysFile/s/^.*$/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config
sed -i -e '/AuthorizedKeysFile/aPubkeyAcceptedKeyTypes +ssh-rsa # Visual Studio Code Hack' /etc/ssh/sshd_config


service sshd restart


# CHANGE HOSTNAME:
read -r -p "Current hostname is $(hostname). Would you like to change it? [y/N] " response
res=${response,,} # tolower
if [[ $res =~ ^(yes|y)$ ]]; then
	./change_hostname.sh
fi


# DISABLE IPv6 NETWORKING:
if ifconfig | grep inet6; then
	echo "IPv6 is enabled. Disabling..."
	echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
	sysctl -p # restart sysctl
fi


# AUTO-UPDATES: yum-cron
if [[ "$centos_version" -eq 6 ]]; then
	yum install yum-cron -y
	sed -i "s|CHECK_ONLY=yes|CHECK_ONLY=no|g" /etc/sysconfig/yum-cron
	service yum-cron restart
	service crond start
	chkconfig yum-cron on
elif [[ "$centos_version" -eq 7 ]]; then
	yum install yum-cron -y
	sed -i "s|apply_updates = no|apply_updates = yes|g" /etc/yum/yum-cron.conf
	systemctl restart yum-cron
	systemctl start crond
	systemctl enable yum-cron
fi


# CAMBIO ZONA HORARIA y sincronizacion de hora:
if [[ "$centos_version" -ge 7 || $os =~ "ubuntu" ]]; then
	timedatectl set-timezone Europe/Madrid
fi


# NANO, colorines:
for f in /usr/share/nano/*.nanorc; do
	echo "include $f" >> /root/.nanorc
done


# Add bash aliases config in .bashrc  (only if it does not exist yet)
cp .bash_aliases ~/
grep .bash_aliases ~/.bashrc || cat >> ~/.bashrc <<EOF

# User specific aliases and functions
if [ -f ~/.bash_aliases ]; then
	. ~/.bash_aliases
fi
EOF

# REBOOT:
echo "ssh access will only be permitted by using an authorised RSA key."
echo "Rebooting now. Have a nice day ;)"
reboot
