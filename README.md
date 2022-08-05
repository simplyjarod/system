# CentOS 6, 7, 8 and Ubuntu system installation and configuration

Please, **download _all files_ before executing any script**. There are several dependencies between them.

## CentOS
```bash
yum install wget unzip -y
wget https://github.com/simplyjarod/system/archive/master.zip
unzip master.zip && cd system-master && rm -rf ../master.zip
chmod u+x *.sh -R
```

## Ubuntu
```bash
apt update -y && apt upgrade -y
apt install wget unzip -y
wget https://github.com/simplyjarod/system/archive/master.zip
unzip master.zip && cd system-master && rm -rf ../master.zip
chmod u+x *.sh -R
```