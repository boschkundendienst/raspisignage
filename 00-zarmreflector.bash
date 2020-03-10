#!/bin/bash
# This script is in a very early stage but does the job for now.
# Feel free to come up with a better solution.
# The purpose of this script is to measure the responsiveness
# of archlinux|ARM mirrors in a given mirrorlist and print
# out a speed sorted list of them to stdout.
if [ "$1" == "--help" ]
then
        echo -e "\nUsage: armreflector <source mirrorlist>"
        echo "Prints a speed optimized mirrorlist of <source mirrorlist>"
        echo "to stdout. Can be used to optimizie your pacman mirrors."
        echo -e "**!! Early Beta !!**\n"
        exit 1
fi

mirrorlist=$1
if [ ! -f "$mirrorlist" ]; then echo "please specify a valid mirrorlist file as parameter 1. Aborting";exit 1;fi
if [ "$mirrorlist" == "/etc/pacman.d/mirrorlist" ]; then echo "You should not specify the 'live-list' as input, use a copy instead. Aborting";exit 1;fi
LANG=C
# create an array containing all urls from mirrorlist
declare -a lines # declare the indexed array for Servers
# put all lines that contained 'Server = ' in mirrorlist into the array 'lines'
for line in $(cat "$mirrorlist" | grep -o ".*Server = .*" | sed 's@.*Server = \(http.*\)@\1@g')
do
 lines+=("$line")
done
#echo "lines has ${#lines[@]} elements"

# print new mirrorlist sorted by speed
echo '##################################################'
echo '### quick and dirty speed optimized mirrorlist ###'
echo '##################################################'
# measure the time_total for any url and put it into the speed array
for (( a=0; a<${#lines[@]}; a++ ))
do
  #url=$(echo "${lines[a]}" | sed 's@\(http.*\)$arch.*@\1@g' | sed 's@\(http.*\)$(arch|repo).*@\1@g') # for all arch
  url=$(echo "${lines[a]}" | sed 's@\(http.*\)$arch.*@\1@g') # for archlinuxarm
  #url=$(echo ${lines[a]} | sed 's@\(http.*\)$rep.*@\1@g') # for arch
  #echo "$url"
  speedline=$(curl -L -s -o /dev/null -w '%{http_code} %{time_total}' --url "$url" --connect-timeout 5 --max-time 2)
  http_code=$(echo "$speedline" | awk '{print $1}')
  speed=$(echo "$speedline" | awk '{print $2}')
  if [ "$http_code" == "200" ] # kann abgeändert werden
  then
   echo "$speed ${lines[a]}"
  fi
done | sort -n -k 1 | awk '{print "#speed "$1"\nServer = "$2}'
