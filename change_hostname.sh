#!/bin/bash

current=`hostname`

read -r -p "Set new hostname: " newname
new=${newname,,} # tolower

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
