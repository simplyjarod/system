#!/bin/bash

read -r -e -p "Set new username: " username
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
chown $user:$user /home/$user
chmod 700 /home/$user/.ssh
chmod 600 /home/$user/.ssh/authorized_keys


# Change Shell to Bash:
chsh -s /bin/bash $user


# Add bash aliases config in .bashrc  (only if it does not exist yet):
cp .bash_aliases /home/$user/
grep .bash_aliases /home/$user/.bashrc || cat >> /home/$user/.bashrc <<EOF

# User specific aliases and functions
if [ -f /home/$user/.bash_aliases ]; then
	. /home/$user/.bash_aliases
fi
EOF


# NANO, colorines:
for f in /usr/share/nano/*.nanorc; do
	echo "include $f" >> /home/$user/.nanorc
done