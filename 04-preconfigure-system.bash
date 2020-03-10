#!/bin/bash
########################################################################
# 04-preconfigure-system.bash
# This script uses the settings specified in the configuration file
# '00-a_client.conf' and does all we can without booting the system
# to prepare it for first boot.
# It sets
#  - keyboard layout
#  - hostname
#  - region and city (e.g. Europe/Berlin)
#  - NTP servers
#  - collation
#  - locale.gen
#  - IPv6 disable/enable
#  - WiFi disable/enable
#  - URL Firefox should open when system is fully installed
########################################################################

########################################################################
# check if we have root permissions
########################################################################
if (( EUID != 0 )); then
 echo -e "\e[91m[ERR]\e[0m Please run as root or with sudo!"
 exit 1
else
 echo -e "\e[92m[OK]\e[0m root privileges available."
fi

########################################################################
# location of 00-a_client.conf to source it
########################################################################
configfile='./00-a_client.conf'
if [ ! -f "$configfile" ]; then echo "configuration file $configfile is missing. Aborting."; exit 1; fi

########################################################################
# additional checks for missing files
########################################################################
if [ ! -f "./00-zrootafterboot.bash" ]; then echo "missing ./00-zrootafterboot.bash. Aborting."; exit 1; fi
if [ ! -f "./00-zsrv_rootafterboot.bash" ]; then echo "missing ./00-zsrv_rootafterboot.bash. Aborting."; exit 1; fi
if [ ! -f "./00-a_client.conf" ]; then echo "missing ./00-a_client.conf. Aborting."; exit 1; fi
if [ ! -f "./00-d_eth0.conf" ]; then echo "missing ./00-d_eth0.conf. Aborting."; exit 1; fi
if [ ! -f "./00-b_wpa_supplicant-wlan0.conf" ]; then echo "missing ./00-b_wpa_supplicant-wlan0.conf. Aborting."; exit 1; fi
if [ ! -f "./00-c_wlan0.conf" ]; then echo "missing ./00-c_wlan0.conf. Aborting."; exit 1; fi


########################################################################
# source our variables from client.conf
########################################################################
unset mydrive
unset mydrivesuff
unset mykbdlayout
unset myhostname
unset myregion
unset mycity
unset myntps
unset mylang
unset mycoll
unset mycs
unset mydisv6
unset myenawifi
unset myopenurl

source "$configfile"
if [ -z ${mydrive+x} ]; then echo "var mydrive is not set. Aborting"; exit 1; fi
if [ -z ${mydrivesuff+x} ]; then echo "var mydrive is not set. Aborting"; exit 1; fi
if [ -z ${mykbdlayout+x} ]; then echo "var mykbdlayout is not set. Aborting"; exit 1; fi
if [ -z ${myhostname+x} ]; then echo "var myhostname is not set. Aborting"; exit 1; fi
if [ -z ${myregion+x} ]; then echo "var myregion is not set. Aborting"; exit 1; fi
if [ -z ${mycity+x} ]; then echo "var mycity is not set. Aborting"; exit 1; fi
if [ -z ${myntps+x} ]; then echo "var myntps is not set. Aborting"; exit 1; fi
if [ -z ${mylang+x} ]; then echo "var mylang is not set. Aborting"; exit 1; fi
if [ -z ${mycoll+x} ]; then echo "var mycoll is not set. Aborting"; exit 1; fi
if [ -z ${mycs+x} ]; then echo "var mycs is not set. Aborting"; exit 1; fi
if [ -z ${mydisv6+x} ]; then echo "var mydisv6 is not set. Aborting"; exit 1; fi
if [ -z ${myenawifi+x} ]; then echo "var myenawifi is not set. Aborting"; exit 1; fi
if [ -z ${myopenurl+x} ]; then echo "var myopenurl is not set. Aborting"; exit 1; fi

########################################################################
# if directories for mountpoints to not exist, create them
########################################################################
[ -d "./boot" ] || mkdir "./boot"
[ -d "./root" ] || mkdir "./root"


########################################################################
# unmount just in case they are mounted somehow
########################################################################
echo -n "try to unmount ${mydrive} (just in case)..."
umount "${mydrive}${mydrivesuff}1" > /dev/null 2>&1
umount "${mydrive}${mydrivesuff}2" > /dev/null 2>&1
echo -e "\t\t\tdone"


########################################################################
# create a trap to unmount if script gets interrupted
# on signals 1,2,3 or 6
########################################################################
trap cleanup 1 2 3 6
cleanup()
{
  echo "          Caught Signal ... unmounting drives."
  umount "${mydrive}${mydrivesuff}1"
  umount "${mydrive}${mydrivesuff}2"
  echo "          Done unmounting ... quitting."
  exit 1
}

########################################################################
# mount part 1 of sdcard to ./boot
########################################################################
if mount "${mydrive}${mydrivesuff}1" boot
then
 echo -e "\e[92msuccessfully mounted ${mydrive}${mydrivesuff}1 to ./boot\e[0m"
else
 echo -e "\e[91mSomething went wrong with the mount of ${mydrive}${mydrivesuff}1 to ./boot. Aborting!\e[0m"
 exit 1
fi
########################################################################
# mount part 2 of sdcard to ./root
########################################################################
if mount "${mydrive}${mydrivesuff}2" root
then
 echo -e "\e[92msuccessfully mounted ${mydrive}${mydrivesuff}2 to ./root\e[0m"
else
 echo -e "\e[91mSomething went wrong with the mount of ${mydrive}${mydrivesuff}2 to ./root. Aborting!\e[0m"
 exit 1
fi

########################################################################
########################################################################
##                  preconfigure unbooted system                      ##
########################################################################
########################################################################

########################################################################
# create vconsole.conf and set keyboard layout
########################################################################
echo -n "Setting KEYMAP to $mykbdlayout in /etc/vconsole.conf..."
echo "KEYMAP=$mykbdlayout" > ./root/etc/vconsole.conf
echo -e "\t\t\t\tdone"

########################################################################
# set hostname in /etc/hosts
########################################################################
# write to /etc/hosts
echo -n "Writing hostname to /etc/hosts..."
if ! grep -q "$myhostname" ./root/etc/hosts
then
 {
  echo -e "127.0.0.1\tlocalhost"
  echo -e "::1\t\tlocalhost"
  echo -e "127.0.1.1\t$myhostname"
 } >> ./root/etc/hosts
fi
echo -e "\t\t\t\t\t\t\tdone"
echo -n "Writing hostname to /etc/hostname..."
echo "$myhostname" > "./root/etc/hostname"
echo -e "\t\t\t\t\t\t\tdone"

########################################################################
# link localtime to timezone from $myregion and $mycity
########################################################################
echo -n "Setting timezone to ${myregion}/${mycity} via softlink..."
ln -sf "/usr/share/zoneinfo/${myregion}/${mycity}" -T ./root/etc/localtime
echo -e "\t\t\t\t\tdone"

########################################################################
# create/replace /etc/systemd/network/eth0.network
########################################################################
eth0net='./00-d_eth0.conf'
echo -n "Writing /etc/systemd/network/eth0.conf based on $eth0net to card..."
if [ -f "$eth0net" ]
then
 cat "$eth0net" > "./root/etc/systemd/network/eth0.network"
fi
echo -e "\t\tdone"

########################################################################
# create/replace /etc/systemd/network/wlan0.network if myenawifi = 'y'
########################################################################
# only if myenawifi is y
if [ "$myenawifi" == "y" ]
then 
 #/etc/systemd/network/wlan0.network
 wlan0net='./00-c_wlan0.conf'
 echo -n "Writing /etc/systemd/network/wlan0.network based on $wlan0net to card..."
 if [ -f "$wlan0net" ]
 then
  cat "$wlan0net" > "./root/etc/systemd/network/wlan0.network"
 fi
 echo -e "\tdone"
 ########################################################################
 #/etc/wpa_supplicant/wpa_supplicant-wlan0.conf
 ########################################################################
 wlan0wpa='./00-b_wpa_supplicant-wlan0.conf'
 echo -n "Writing /etc/wpa_supplicant/wpa_supplicant-wlan0.conf..."
 if [ -f "$wlan0wpa" ]
 then
  cat "$wlan0wpa" > "./root/etc/wpa_supplicant/wpa_supplicant-wlan0.conf"
 fi
 echo -e "\t\t\t\tdone"
 ## activate WPA Supplicant Daemon by link
 echo -n "Activating WPA Supplicant Daemon by setting a link..."
 ln -sf /usr/lib/systemd/system/wpa_supplicant@.service "./root/etc/systemd/system/multi-user.target.wants/wpa_supplicant@wlan0.service"
 echo -e "\t\t\t\t\tdone"
else # myenawifi is not y 
 echo -n "mydiswifi NOT set to 'y' disabling wpa_supplicant daemon"
 rm -f "./root/etc/systemd/system/multi-user.target.wants/wpa_supplicant@wlan0.service"  > /dev/null 2>&1
 echo -e "\t\tdone"
 echo -n "removing wpa_supplicant-wlan0.conf"
 rm -f "./root/etc/wpa_supplicant/wpa_supplicant-wlan0.conf"  > /dev/null 2>&1
 echo -e "\t\t\t\t\tdone"
 echo -n "removing wlan0.network"
 rm -f "./root/etc/systemd/network/wlan0.network"  > /dev/null 2>&1
 echo -e "\t\t\t\t\t\t\tdone"
fi

########################################################################
# set NTP servers
########################################################################
echo -n "Setting NTP servers in /etc/systemd/timesyncd.conf..."
sed -i "s/^#NTP=/NTP=${myntps}/g" ./root/etc/systemd/timesyncd.conf
# set Fallback NTP to arch defaults
sed -i 's/^#FallbackNTP/FallbackNTP/g' ./root/etc/systemd/timesyncd.conf
echo -e "\t\t\t\t\tdone"

########################################################################
# create/replace locale.gen and locale.conf
########################################################################
echo -n "Setting locale.gen and locale.conf..."
sed -i "s/#${mycs}/${mycs}/g" ./root/etc/locale.gen
# locales will be generated later running on the client during package installation
# Create the locale.conf(5) file, and set the LANG variables accordingly
echo "LANG=$mylang" > ./root/etc/locale.conf
echo "LC_COLLATE=$mycoll" >> ./root/etc/locale.conf
#echo "LANGUAGE=$mylang" >> ./root/etc/locale.conf
#echo "LC_MONETARY=$mylang" >> ./root/etc/locale.conf
#echo "LC_PAPER=$mylang" >> ./root/etc/locale.conf
#echo "LC_MEASUREMENT=$mylang" >> ./root/etc/locale.conf
#echo "LC_NAME=$mylang" >> ./root/etc/locale.conf
#echo "LC_ADDRESS=$mylang" >> ./root/etc/locale.conf
#echo "LC_TELEPHONE=$mylang" >> ./root/etc/locale.conf
#echo "LC_IDENTIFICATION=$mylang" >> ./root/etc/locale.conf
echo "LC_ALL=" >> ./root/etc/locale.conf
echo -e "\t\t\t\t\t\t\tdone"

########################################################################
# disable ipv6 at kernel level if mydisv6 = 'y'
########################################################################
# add ipv6.disable=1 to kernel parameter in /boot/cmdline.txt
if [ "$mydisv6" == "y" ]
echo -n "Disabling IPv6 at kernel boot line..."
then
 if ! grep -q 'ipv6.disable=1' "./boot/cmdline.txt"
 then
  sed -i 's/^\(root=.*\)$/\1 ipv6.disable=1/g' "./boot/cmdline.txt"
 fi
echo -e "\t\t\t\t\t\t\tdone"
fi

########################################################################
# fix DNS resolution (quick fix for a DNS resolving problem I ran into)
########################################################################
# this is a hack to make DNS working again by editing nsswitch.conf
echo -n "Fixing DNS in Name Service Switch configuration file nsswitch.conf..."
sed -i 's/^hosts:.*/hosts: files mymachines myhostname dns [!UNAVAIL=return]/g' "./root/etc/nsswitch.conf"
echo -e "\t\t\tdone"

########################################################################
## copy installation script for additional components
## to roots home directory as rootafterboot.bash and make it executable
########################################################################
echo -n "Copying rootafterboot.bash to /root. Execute it after booting the Pi..."
cp -f "./00-zrootafterboot.bash" "./root/root/rootafterboot.bash"
chmod +x "./root/root/rootafterboot.bash"
echo -e "\t\t\tdone"

if [ -f ./00-zsrv_rootafterboot.bash ]
then
 echo -n "Copying srv_rootafterboot.bash to /root. (to create WP CMS)"
 cp -f "./00-zsrv_rootafterboot.bash" "./root/root/srv_rootafterboot.bash"
 chmod +x "./root/root/srv_rootafterboot.bash"
 echo -e "\t\t\t\tdone"
fi

########################################################################
## replace myopenurl as url in rootafterboot.bash
########################################################################
echo -n "Setting kiosk mode url in ./root/root/rootafterboot.bash..."
sed -i "s@^url=.*@url='${myopenurl}'@g" './root/root/rootafterboot.bash'
echo -e "\t\t\t\tdone"


### TESTING ###
if [ -f ./00-zarmreflector.bash ]; then cp ./00-zarmreflector.bash './root/root/armreflector.bash';chmod +x './root/root/armreflector.bash';fi


########################################################################
# unmount partitions
########################################################################
# sync
echo -n "Syncing drives. This could take a while..."
sync
echo -e "\t\t\t\t\t\tdone"
sleep 3
########################################################################
# unmount ./boot
########################################################################
if umount "${mydrive}${mydrivesuff}1"
then
 echo -e "\e[92msuccessfully unmouted ${mydrive}${mydrivesuff}1 from ./boot\e[0m"
else
 echo -e "\e[91mcould not unmount ${mydrive}${mydrivesuff}1 from ./boot - manual intervention needed!\e[0m"
 exit 1
fi
sleep 3
########################################################################
# unmount ./root
########################################################################
if umount "${mydrive}${mydrivesuff}2"
then
 echo -e "\e[92msuccessfully unmouted ${mydrive}${mydrivesuff}2 from ./root\e[0m"
else
 echo -e "\e[91mcould not unmount ${mydrive}${mydrivesuff}2 from ./root - manual intervention needed!\e[0m"
 exit 1
fi

########################################################################
# Show final message
########################################################################
echo '########################################################################'
echo "You can now insert the SD Card into your Pi and boot,"
echo "then login via SSH or local attached keyboard as"
echo " U: alarm"
echo " P: alarm"
echo "As the user 'alarm' type 'su -' to become root."
echo "The root password is 'root'"
echo '########################################################################'
echo "ON THE PI:"
echo " execute '/root/rootafterboot.bash'     once to make it a DS Player"
echo " execute '/root/srv_rootafterboot.bash' once to make it a DS CMS"
echo '########################################################################'
echo "Hint to find your Pi:"
echo " sudo nmap xxx.xxx.xxx.0/24 -p 22 | grep -B 5 'Raspberry'"
echo '########################################################################'

########################################################################
#  END END END END END END END END END END END END END END END END END #
########################################################################
# if [ -f ./00-zarmreflector.bash ]; then cp ./00-zarmreflector.bash './root/root/armreflector.bash';chmod +x './root/root/armreflector.bash';fi
