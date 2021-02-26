#!/bin/bash
########################################################################
# 02-partitioning.bash
#
# This script creates 2 partitions on the SD card specified by
# the variables 'mydrive' and 'mydrivesuff' (00-a_client.conf).
#
# part1        100MB               vfat (e.g. /dev/mmcblk0p1)
# part2        rest of SD card     ext4 (e.g. /dev/mmcblk0p2)
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
command -v sfdisk >/dev/null 2>&1 || { echo >&2 "sfdisk from util-linux is not installed. Aborting."; exit 1; }
command -v mkfs.vfat >/dev/null 2>&1 || { echo >&2 "mkfs.vfat from dosfstools is not installed. Aborting."; exit 1; }
command -v mkfs.ext4 >/dev/null 2>&1 || { echo >&2 "mkfs.ext4 from e2fsprogs is not installed. Aborting."; exit 1; }

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
source "$configfile"
if [ -z ${mydrive+x} ]; then echo "var mydrive is not set. Aborting"; exit 1; fi
if [ -z ${mydrivesuff+x} ]; then echo "var mydrivesuff is not set. Aborting"; exit 1; fi

########################################################################
# check for device nodes (maybe needs some optimizing)
########################################################################
if  ! fdisk -l | grep -v "loop" | grep -q "${mydrive}"
then
 echo "Could not find device ${mydrive}."
 echo "Is the SD card inserted correctly and did you specify"
 echo "the correct value for 'mydrive' and 'mydrivesuff' in '00-a_client.conf'?"
 exit 1
fi

########################################################################
# unmount just in case they are mounted somehow
########################################################################
echo -n "try to unmount ${mydrive} (just in case)..."
umount "${mydrive}${mydrivesuff}1" > /dev/null 2>&1
umount "${mydrive}${mydrivesuff}2" > /dev/null 2>&1
echo -e "\t\t\tdone"

########################################################################
# create partitions
########################################################################
echo "Erasing first 1024 bytes of ${mydrive} for a clean start!"
dd if=/dev/zero of=${mydrive} bs=1M count=1
echo "Creating part 1 100MB vfat on ${mydrive}${mydrivesuff}1 and"
echo -n "         part 2  rest ext4 on ${mydrive}${mydrivesuff}2..."
sfdisk "$mydrive" >/dev/null 2>&1 <<EOL
start=        2048, size=      204800, type=c
start=      206848, type=83
EOL
echo -e "\t\t\tdone"

########################################################################
# create filesystems
########################################################################
label1='TOOB'
label2='HCRA'
echo -n "Creating vfat filesystem on ${mydrive}${mydrivesuff}1..."
mkfs.vfat -n "$label1" "${mydrive}${mydrivesuff}1" >/dev/null 2>&1   # vfat on /dev/sdX1 with label 'TOOB'
echo -e "\t\t\tdone"
echo -n "Creating ext4 filesystem on ${mydrive}${mydrivesuff}2..."
mkfs.ext4 -L "$label2" -F "${mydrive}${mydrivesuff}2"  >/dev/null 2>&1 # ext4 on /dev/sdX2 with label 'HCRA'
echo -e "\t\t\tdone"
if blkid "${mydrive}${mydrivesuff}1" | grep -q "$label1";
then
 echo -e "\e[92m[OK]\e[0m Partition 1 on ${mydrive}${mydrivesuff}1 (vfat) with label ${label1} present."
fi
if blkid "${mydrive}${mydrivesuff}2" | grep -q "$label2";
then
 echo -e "\e[92m[OK]\e[0m Partition 2 on ${mydrive}${mydrivesuff}2 (ext4) with label ${label2} present."
fi

########################################################################
#  END END END END END END END END END END END END END END END END END #
########################################################################
