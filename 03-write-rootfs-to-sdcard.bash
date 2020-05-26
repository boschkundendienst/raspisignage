#!/bin/bash
########################################################################
# 03-write-rootfs-to-sdcard.bash
# This script takes 'ArchLinuxARM-rpi-latest.tar.gz' and extracts
# it to /root (partition 2) on our SD card.
# After that everything from /root/boot is moved to /boot (partition 1)
# to get a bootable SD card for the Pi with archlinux|ARM on it. 
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
# check prerequisites
########################################################################
command -v bsdtar >/dev/null 2>&1 || { echo >&2 "bsdtar is not installed. Aborting."; exit 1; }

########################################################################
# location of 00-a_client.conf to source it
########################################################################
configfile='./00-a_client.conf'
if [ ! -f "$configfile" ]; then echo "configuration file $configfile is missing. Aborting."; exit 1; fi

########################################################################
# source our variables from client.conf
########################################################################
unset mydrive
unset mydrivesuff
unset myoutputfile
source "$configfile"
if [ -z ${mydrive+x} ]; then echo "var mydrive is not set. Aborting"; exit 1; fi
if [ -z ${mydrivesuff+x} ]; then echo "var mydrive is not set. Aborting"; exit 1; fi
if [ -z ${myoutputfile+x} ]; then echo "var myoutputfile is not set. Aborting"; exit 1; fi

########################################################################
# create folders for mounts in current folder
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
  echo "          Caught Signal ... unmounting drives...please wait!...."
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
# disable write cache for sdcard
# does not help anything but at least it avoids caching
########################################################################
#hdparm -W 0 ${mydrive} # disabling write cache on sdcard if you like

########################################################################
# extract the downloaded file to ./root
########################################################################
# Info:
# All attributes contained in the official archlinux|ARM .tar.gz are only
# supported by the latest version of bsdtar which is currently not
# avaialbe on Ubuntu 18.04 so I pointed the errors to /dev/null for better
# user experience. Finally the result works but may not contain all
# information as if you had `pacstrap` archlinux yourself.
echo -n "Extracting $myoutputfile to ./root. Please wait..."
bsdtar -xpf "$myoutputfile" -C root 2>/dev/null
echo -e "\tdone"

########################################################################
# mv root/boot/* to boot
# because mv cannot overwrite non-empty directories we delete subfolders
# in ./root first to make sure we can re-run this script without errors
########################################################################
find boot/* -type d -exec sudo rm -rf -- '{}' > /dev/null 2>&1 \;
echo -n "Moving ./root/boot/* to ./boot/ ..."
mv -f ./root/boot/* boot
echo -e "\t\t\t\t\tdone"

########################################################################
# sync filesystems
########################################################################
sync &
pid=$!
trap "kill $pid 2> /dev/null" EXIT
echo -n "Syncing drives. This could take a while.."
while kill -0 $pid 2> /dev/null
do
 sleep 5
 echo -n "."
done
echo -e "\t\t\tdone"
trap - EXIT # disable the trap on a normal exit
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
# show some output
########################################################################
echo "Arch Linux is now on ${mydrive}"
echo -e "Ready to continue with next script\n"

########################################################################
#  END END END END END END END END END END END END END END END END END #
########################################################################
