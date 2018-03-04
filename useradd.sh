#!/bin/bash

read -r -p "Set new username: " username
user=${username,,} # tolower
useradd $user
passwd $user


read -r -p "Add user to sudoers? [y/N] " response
res=${response,,} # tolower
if ! [[ $res =~ ^(yes|y)$ ]]; then
  #gpasswd -a $user wheel # si wheel no esta autorizado en sudoers esto no funciona
  echo >> /etc/sudoers
  echo "# User $user authorization:" >> /etc/sudoers
  echo "$user ALL=(ALL) ALL" >> /etc/sudoers
fi


# SSH: RSA key
mkdir -p /home/$user/.ssh
cat hernani.pub >> /home/$user/.ssh/authorized_keys
chown -R $user:$user /home/$user/.ssh

# -> to connect using private key without attach it each time:
# eval `ssh-agent -s` # to start ssh-agent (do it only one time)
# ssh-add xxx.pem     # to add the private key to the ssh-agent (do it once)
# ssh user@ip-or-host # connect ssh normally each time
# -> or forget the above three lines and use each time:
# ssh -i xxx.pem user@ip-or-host


# NANO, colorines:
for f in /usr/share/nano/*; do
	echo "include $f" >> /home/$user/.nanorc
done
chown $user:$user /home/$user/.nanorc
