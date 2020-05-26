#!/bin/bash
########################################################################
# 01-download.bash
# This script downloads the archlinux|ARM installation .tar.gz file
# from the official homepage based on the variable 'mydlurl'
# 'mydlurl' is set in the configuration file '00-a_client.conf'
########################################################################

########################################################################
# check prerequisites
########################################################################
# wget, curl or axel? axel is fastest!
#if command -v axel >/dev/null 2>&1
#then
# dlcmd='axel'
# elif command -v wget >/dev/null 2>&1
 if command -v wget >/dev/null 2>&1
 then
  dlcmd='wget'
 elif command -v curl >/dev/null 2>&1
 then
  dlcmd='curl'
else
 #echo "Neither 'wget' nor 'curl' nor 'axel' is installed as download utility. Aborting."
 echo "Neither 'wget' nor 'curl' is installed as download utility. Aborting."
 exit 1
fi

########################################################################
# location of 00-a_client.conf to source it
########################################################################
configfile='./00-a_client.conf'
if [ ! -f "$configfile" ]; then echo "configuration file $configfile is missing. Aborting."; exit 1; fi

########################################################################
# source our variables from client.conf
########################################################################
unset mydlurl
unset myoutputfile
source "$configfile"
if [ -z ${mydlurl+x} ]; then echo "var mydlurl is not set. Aborting"; exit 1; fi
if [ -z ${myoutputfile+x} ]; then echo "var myoutputfile is not set. Aborting"; exit 1; fi

########################################################################
# Download root filesystem from archlinux|arm page
########################################################################
# decide between axel, curl or wget as download tool
echo -n "Downloading to $myoutputfile from $mydlurl using "
#if [ "${dlcmd}" = 'axel' ]
#then
# echo "axel..."
# ${dlcmd} -o "$myoutputfile" "${mydlurl}"
#fi

if [ "${dlcmd}" = 'curl' ]
then
 echo "curl..."
 ${dlcmd} -L -o "$myoutputfile" "${mydlurl}"
fi

if [ ${dlcmd} = 'wget' ]
then
 echo "wget..."
 ${dlcmd} -O "$myoutputfile" -q --show-progres "${mydlurl}"
fi
echo "...done"

if file --mime-type "$myoutputfile" | grep -q 'application/gzip'
then
 echo -e "\e[92m[OK]\e[0m $myoutputfile has been downloaded."
else
 echo -e "\e[91m[ERR]\e[0m $myoutputfile is missing or wrong mime type. Abort here!"
fi

########################################################################
#  END END END END END END END END END END END END END END END END END #
########################################################################
