#!/bin/bash

read -r -p "Set new username: " username
user=${username,,} # tolower
useradd $user
passwd $user


read -r -p "Add user to sudoers? [y/N] " response
res=${response,,} # tolower
if [[ $res =~ ^(yes|y)$ ]]; then
	#gpasswd -a $user wheel # si wheel no esta autorizado en sudoers esto no funciona
	echo >> /etc/sudoers
	echo "# User $user authorization:" >> /etc/sudoers
	echo "$user ALL=(ALL) ALL" >> /etc/sudoers
fi


# SSH: RSA key
mkdir -p /home/$user/.ssh
for f in *.pub; do (cat $f; echo '') >> /home/$user/.ssh/authorized_keys; done
chown -R $user:$user /home/$user/.ssh
chmod 600 /home/$user/.ssh
chmod 600 /home/$user/.ssh/authorized_keys
