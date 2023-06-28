#!/bin/bash

read -r -e -p "Set new hostname: " newname
new=${newname,,} # tolower

# Operative System:
os=$(grep ^ID= /etc/os-release | cut -d "=" -f 2)
os=${os,,} #tolower

centos_version=$(rpm -qa \*-release | grep -Ei "oracle|redhat|centos" | sed 's/[^6-8]*//g' | cut -c1)

if [[ "$centos_version" -ge 7 || $os =~ "ubuntu" ]]; then
	hostnamectl set-hostname $new
	exit # end of this script
fi


# Following lines are only for CentOS 6:

current=`hostname`

# 1) Network:
sed -i "s|$current|$new|g" /etc/sysconfig/network


# 2) /etc/hosts

# 2.1) Cambio del nombre completo:
sed -i "s|$current|$new|g" /etc/hosts

# 2.2) Puede haber una linea tipo: 11.22.33.44   algo.domain.com   algo
OIFS="$IFS"    # guardamos el valor del Internal Field Separator original
IFS="."        # fijamos el valor del separador en un punto
read -a hosts <<< "${current}"
sed -i "s|${hosts[0]}|$new|g" /etc/hosts  # cambiamos "algo" por el nuevo nombre
IFS="$OIFS"    # restauramos a su valor original


# 3) Hostname
hostname $new


# 4) Restart network:
/etc/init.d/network restart
