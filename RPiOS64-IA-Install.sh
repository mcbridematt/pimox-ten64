# !/bin/bash
#######################################################################
# Name:     RPiOS64-IA-Install.sh           Version:      0.1.2       #
# Created:  07.09.2021                      Modified: 22.02.2022      #
# Author:   TuxfeatMac J.T.                                           #
# Purpose:  interactive, automatic, Pimox7 installation RPi4B, RPi3B+ #
#########################################################################################################################################
# Tested with image from:														                                                                                                 #
# https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2021-11-08/2021-10-30-raspios-bullseye-arm64-lite.zip	 #
#########################################################################################################################################

#### SET SOME COLOURS ###################################################################################################################
NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
GREY=$(tput setaf 8)

#### SCRIPT IS MENT TO BE TO RUN AS ROOT! NOT AS PI WITH SUDO ###########################################################################
if [ $USER != root ]
 then
  printf "${RED}PLEASE RUN THIS SCRIPT AS ROOT! DONT USE SUDO! $NORMAL \n"
  exit
fi
printf " $YELLOW
====================================================================
!    PLEASE DONT USE SUDO, USE SU TO LOGIN TO THE ROOT USER        !
! PLEASE STOP THIS SCRIPT NOW WITH CONTROL+C IF YOU ARE USING SUDO !
!               CONTINUING SETUP IN 3 SECONDS...                   !
====================================================================
$NORMAL\n" && sleep 3

HOSTNAME=$(hostname)

#### IP AND NETMASK ! ###################################################################################################################
read -p "Enter new static IP and NETMASK e.g. 192.168.0.100/24 : " RPI_IP
while [[ ! "$RPI_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}+\/[0-9]+$ ]]
 do
  printf " --->$RED $RPI_IP $NORMAL<--- Is NOT an valid IPv4 ADDRESS with NETMASK, try again...\n"
  read -p "IPADDRESS & NETMASK ! E.G.: 192.168.0.100/24 : " RPI_IP
done
RPI_IP_ONLY=$(echo "$RPI_IP" | cut -d '/' -f 1)

#### GATEWAY ############################################################################################################################
GATEWAY="$(echo $RPI_IP | cut -d '.' -f 1,2,3).1"
read -p"Is $GATEWAY the correct gateway ?  y / n : " CORRECT
if [ "$CORRECT" != "y" ]
 then
  read -p "Enter the gateway  e.g. 192.168.0.1 : " GATEWAY
  while [[ ! "$GATEWAY" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$  ]]
   do
    printf " --->$RED $GATEWAY $NORMAL<--- Is NOT an valid IPv4 GATEWAY, try again...\n"
    read -p "THE GATEWAY IP ! E.G. 192.168.0.1 : " GATEWAY
  done
fi

#### AGREE TO CHANGES ###################################################################################################################
printf "
$YELLOW#########################################################################################
=========================================================================================$NORMAL
THE NEW HOSTNAME WILL BE:$GREEN $HOSTNAME $NORMAL
=========================================================================================
THE PIMOX REPO WILL BE ADDED IN : $YELLOW /etc/apt/sources.list.d/pimox.list $NORMAL CONFIGURATION :
$GRAY# Pimox 7 Development Repo$NORMAL
deb https://raw.githubusercontent.com/pimox/pimox7/master/ dev/
=========================================================================================
THE NETWORK CONFIGURATION IN : $YELLOW /etc/network/interfaces $NORMAL WILL BE $RED CHANGED $NORMAL !!! TO :
auto lo
iface lo inet loopback
iface eth0 inet manual
auto vmbr0
iface vmbr0 inet static
        address $GREEN $RPI_IP $NORMAL
        gateway $GREEN $GATEWAY $NORMAL
        bridge-ports eth0
        bridge-stp off
        bridge-fd 0
=========================================================================================
THE HOSTNAMES IN : $YELLOW /etc/hosts $NORMAL WILL BE $RED OVERWRITTEN $NORMAL !!! WITH :
127.0.0.1\tlocalhost
$RPI_IP_ONLY\t$HOSTNAME
=========================================================================================
THESE STATEMENTS WILL BE $RED ADDED $NORMAL TO THE $YELLOW /etc/default/grub $NORMAL IF NONE EXISTENT :
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1
$YELLOW=========================================================================================
TEN64 SPECIFIC:

The Traverse 5.15 kernel package will be installed (to align with mainline Proxmox)
cloud-init will be removed
contrib repo will be enabled for bullseye-backports
Google public DNS will be used as the DNS resolver, you can
change it in /etc/network/interfaces later
#########################################################################################\n $NORMAL
"

#### PROMPT FOR CONFORMATION ############################################################################################################
read -p "YOU ARE OKAY WITH THESE CHANGES ? YOUR DECLARATIONS ARE CORRECT ? CONTINUE ? y / n : " CONFIRM
if [ "$CONFIRM" != "y" ]; then exit; fi

echo 'deb [trusted=yes] https://archive.traverse.com.au/pub/traverse/debian-experimental/ lts-5-15 main' > /etc/apt/sources.list.d/traverse.list

(grep -q -E "deb .*bullseye-backports.*contrib" /etc/apt/sources.list) || {
  sed -i 's/\(deb .*bullseye-backports\)/\1 contrib/g' /etc/apt/sources.list
}

apt-get update && \
  apt-get -y install linux-image-traverse bridge-utils gnupg && \
  apt-get remove -y cloud-init &&
  apt-get -y upgrade

INSTALLED_KERNEL_VERSION=$(dpkg-query --showformat='${Version}' --show linux-image-traverse)
apt-get -y install "linux-headers-${INSTALLED_KERNEL_VERSION::-2}"
#### SET A ROOT PWD FOR WEB GUI LOGIN ###################################################################################################
printf "
=========================================================================================
                          $RED ! SETUP NEW ROOT PASSWORD ! $NORMAL
=========================================================================================\n
" && passwd
if [ $? != 0 ]; then exit; fi

#### BASE UPDATE, DEPENDENCIES INSTALLATION #############################################################################################
printf "
=========================================================================================
 Begin installation, Normal duration on a default RPi4 ~ 30 minutes, be patient...
=========================================================================================\n
"

#### ADD SOURCE PIMOX7 + KEY & UPDATE & INSTALL RPI-KERNEL-HEADERS #######################################################################
printf "# PiMox7 Development Repo
deb https://raw.githubusercontent.com/pimox/pimox7/master/ dev/ \n" > /etc/apt/sources.list.d/pimox.list
curl https://raw.githubusercontent.com/pimox/pimox7/master/KEY.gpg |  apt-key add -
apt update && apt upgrade -y

#### CLEAN UP ###############################################################################################################
apt autoremove -y

#### FIX CONTAINER STATS NOT SHOWING UP IN WEB GUI #######################################################################################
source /etc/default/grub

if [ "$(echo ${GRUB_CMDLINE_LINUX_DEFAULT} | grep cgroup)" != "" ]
 then
  printf "Seems to be already fixed!"
 else
  NEW_LINUX_CMDLINE="${GRUB_CMDLINE_LINUX_DEFAULT} cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1"
  sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"${NEW_LINUX_CMDLINE}\"/g" /etc/default/grub
fi
update-grub

#### NETWORK RECONFIG MOVED HERE (TEN64) - AVOID DISRUPTION DURING PACKAGE DOWNLOAD

#### INSTALL PIMOX7 AND REBOOT ###########################################################################################################

#### Ten64 edit: Download all packages now, as network stack may be inoperable after some proxmox packages install

apt-get -y install --download-only proxmox-ve

#### Install pve-manager separately, and without recommended packages, to avoid packaging issue later.
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends -o Dpkg::Options::="--force-confdef" pve-manager

#### Continue with remaining packages
DEBIAN_FRONTEND=noninteractive apt install -y -o Dpkg::Options::="--force-confdef" proxmox-ve

#### RECONFIGURE NETWORK #### /etc/hosts REMOVE IPv6 #### /etc/network/interfaces.new CONFIGURE NETWORK TO CHANGE ON REBOOT ##############
printf "
=========================================================================================
$GREEN ! FIXING NETWORK CONFIGURATION.... ERRORS ARE NOMALAY FINE AND RESOLVED AFTER REBOOT ! $NORMAL
=========================================================================================
\n"
printf "127.0.0.1\tlocalhost
$RPI_IP_ONLY\t$HOSTNAME\n" > /etc/hosts
printf "auto lo
iface lo inet loopback

iface eth0 inet manual

auto vmbr0
iface vmbr0 inet static
        address $RPI_IP
        gateway $GATEWAY
        bridge-ports eth0
        bridge-stp off
        bridge-fd 0
        dns-nameserver 8.8.8.8\n" > /etc/network/interfaces.new

rm "/etc/network/interfaces.d/50-cloud-init"

#### CONFIGURE PIMOX7 BANNER #############################################################################################################
cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.auto.backup
SEARCH="return Ext.String.format('"
#### PLACE HOLDER BANNER BEGIN --> #### LINE 1 ####                                                     #### LINEBREAK #### -- #### LINE 2 #####
REPLACE="return Ext.String.format(' This is a unofficial development build of PVE7 - PIMOX7 - https://github.com/pimox/pimox7  Build to run a PVE7 on the RPi4. ! ! ! NO GUARANTEE NOT OFFICIALLY SUPPORTED ! ! ! ');"
sed -i "s|$SEARCH.*|$REPLACE|" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

### FINAL MESSAGE ########################################################################################################################
printf "
=========================================================================================
                   $GREEN     ! INSTALATION COMPLETED ! WAIT ! REBOOT ! $NORMAL
=========================================================================================

    after reboot the PVE web interface will be reachable here :
      --->  $GREEN https://$RPI_IP_ONLY:8006/ $NORMAL <---
      
         run ---> $YELLOW apt upgrade -y $NORMAL <---
           in a root shell to complete the installation.
           
\n" && sleep 10 && reboot

#### EOF ####
