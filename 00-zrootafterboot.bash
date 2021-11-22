#!/bin/bash
########################################################################
# Run this script after first boot on the new system as root!          #
# You only need to run it once!                                        #
# It will                                                              #
#  - setup autologin for user 'alarm'                                  #
#  - setup a working X system with lightdm, fluxbox, etc.              #
#  - autostarts a browser with given URL in fullscreen kiosk mode      #
#                                                                      #
# AN INTERNET CONNECTION IS REQUIRED !                                 #
########################################################################

########################################################################
# update or set values /boot/config.txt
########################################################################
echo -n "Setting parameters in /boot/config.txt..."
# grep the initramfs line and store it
initline=$(grep "^initramfs.*$" /boot/config.txt)
# write values to config.txt
cat >"/boot/config.txt" <<EOL
# See /boot/overlays/README for all available options
# The settings below should work for a Pi 4 where the
# HDMI cable is connected to the HDMI port that is
# most away from the USB-C power
# It might be necessary to update config.txt
# to your needs especially for your specific monitor
#disable_overscan=1
#dtparam=audio=on
#hdmi_drive=2
#hdmi_group=2
#hdmi_mode=82
#hdmi_force_hotplug=1

# Set disable_overscan to 1 to disable the default values of overscan that is set by the firmware.
# The default value of overscan for the left, right, top, and bottom edges is 48 for HD CEA modes,
# 32 for SD CEA modes, and 0 for DMT modes. The default value for disable_overscan is 0
disable_overscan=1

#dtparam=audio=on

#Normal HDMI mode (sound will be sent if supported and enabled)
hdmi_drive=2

# 2 DMT timing
# 1 TV timing
# 0 auto-detect from EDID
hdmi_group=2

# The gpu_mem_1024 command sets the GPU memory in megabytes for Raspberry Pi devices with 1024MB
# or more of memory. (It is ignored if memory size is smaller than 1024MB). This overrides
# gpu_mem. The maximum value is 944, and the default is not set.
gpu_mem_1024=64

# needed on Pi4 to make Chrome work again
# decide yourself
##dtoverlay=vc4-kms-v3d

# needed on some Pi3s to make lightdm work again
# decide yourself
##dtoverlay=vc4-fkms-v3d

EOL
echo -e -n "\n$initline\n" >> /boot/config.txt
echo "done"

########################################################################
# check internet connection (archlinuxarm.org)                         #
########################################################################
while ! timeout 5 curl -s https://archlinuxarm.org/ &> /dev/null
do
    printf "%s\n" "no internet connection, please check! - Long press Ctrl+C to exit!"
    sleep 1
done
printf "\n%s\n"  "Internet is accessible."

########################################################################
# initialize pacman keyring and populate Arch ARM package signing keys
########################################################################
pacman-key --init
pacman-key --populate archlinuxarm

########################################################################
# function to prepare and fix pacman-mirrorlist for Germany            #
# It should also work if you replace 'Germany' with your country       #
########################################################################
function fix_mirrorlist {
 cp -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
 echo "Backup of previous mirrorlist is at /etc/pacman.d/mirrorlist.bak"
 # use armreflector.bash to create a fast mirrorlist
 echo -n "Generating a more speedy mirrorlist..."
 ./armreflector.bash /etc/pacman.d/mirrorlist.bak > /etc/pacman.d/mirrorlist
 echo "done"
 pacman -Sy --noconfirm # only update package database
}
cp -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.original # just for sure
fix_mirrorlist

########################################################################
# Download latest pacman-mirrorlist and overwrite old
########################################################################
pacman -S pacman-mirrorlist --noconfirm
if [ -f /etc/pacman.d/mirrorlist.pacnew ]
 then
 mv -f /etc/pacman.d/mirrorlist.pacnew /etc/pacman.d/mirrorlist
 fix_mirrorlist
fi

########################################################################
# fully update the system
########################################################################
pacman -Syu --noconfirm

########################################################################
# Install packages we need
# - fluxbox
# - xorg-server
# - xf86-video-fbdev
# - xorg-xmodmap
# - xorg-xinit
# - xorg-xset
# - accountsservice
# - lightdm
# - lightdm-gtk-greeter
# - unclutter
# - firefox
# - chromium
# - youtube-dl
# - ttf-liberation
# - feh
########################################################################
# get list of already installed packages and store them in $installed
# --force can be used as "$1" to ignore the variable completely
########################################################################
installed=$(pacman -Q | cut -d ' ' -f 1 | tr '\n' '|')
if [ "$1" == "--force" ];then installed='';fi # override when --force
# list of packages to install
# if you can afford arround 600 MiB more disk space, you can install all
# the noto-fonts packages from the list below
#
# noto-fonts-cjk   (294 MB)
# noto-fonts-emoji (  9 MB)
# noto-fonts-extra (321 MB)
#
packages="fluxbox,xorg-server,xf86-video-fbdev,xorg-xmodmap,xorg-xinit,xorg-xset,accountsservice,lightdm,lightdm-gtk-greeter,unclutter,firefox,chromium,ttf-liberation,feh,alsa-tools,alsa-utils,alsa-firmware,youtube-dl,rtmpdump,python-pycryptodome,omxplayer-git,vim,cronie" # noto-fonts,noto-fonts-cjk,noto-fonts-emoji,noto-fonts-extra"
# install packages from list
for i in $(echo $packages | sed "s/,/ /g")
do
 if ! echo "$installed"|grep -q "$i" # only if not yet installed
 then
  LANG=C pacman -Si "$i" | grep -E "Name|Depends"; echo "----"
  pacman -S "$i" --noconfirm
 fi
done

########################################################################
# add user alarm to group video and audio
########################################################################
gpasswd -a alarm video
gpasswd -a alarm audio

########################################################################
# create /etc/crontab and fill with some commented stuff
# and enable cronie. User can uncomment lines to have some funny vids
########################################################################
cat >>"/etc/crontab" <<'EOL'
#Min Hour Day Month DayOfWeek user Command
## Rundschau 100 Sekunden
#0 * * * * root /usr/bin/omxplayer --vol -900 "$(/usr/bin/youtube-dl -g 'https://www.br.de/br-fernsehen/sendungen/rundschau/rundschau-news100.html')" >/dev/null 2>&1
## Heute Xpress aktuelle Sendung
#5 * * * * root /usr/bin/omxplayer --vol -900 "$(/usr/bin/youtube-dl -g 'https://www.zdf.de/nachrichten/heute-sendungen/videos/heute-xpress-aktuelle-sendung-100.html')" > /dev/null 2>&1
## Tagesschau 100 Sekunden
#10 * * * * root /usr/bin/omxplayer --vol -900 "$(/usr/bin/youtube-dl -g 'https://www.tagesschau.de/100sekunden/')" > /dev/null 2>&1
## Morgennachrichten heute SAT1
#15 * * * * root /usr/bin/omxplayer --vol -900 "$(/usr/bin/youtube-dl -g "$(/usr/bin/date +'https://www.sat1.de/news/video/morgennachrichten-\%d-\%m-\%Y-clip')")" > /dev/null 2>&1
## Earth
#20 * * * * root /usr/bin/omxplayer --vol -90000 "$(/usr/bin/youtube-dl -f mp4 -g 'https://www.youtube.com/watch?v=HiN6Ag5-DrU')" > /dev/null 2>&1
## OTV Wetterschau von heute
#25 * * * * root /usr/bin/omxplayer --vol -900 $(/usr/bin/youtube-dl -g "$(/usr/bin/date +'https://www.otv.de/mediathek/kategorie/sendungen/otv-wetterschau/video/das-wetter-vom-\%d-\%m-\%Y/')") > /dev/null 2>&1
############ RUN 2
## Rundschau 100 Sekunden
#30 * * * * root /usr/bin/omxplayer --vol -900 "$(/usr/bin/youtube-dl -g 'https://www.br.de/br-fernsehen/sendungen/rundschau/rundschau-news100.html')" >/dev/null 2>&1
## Heute Xpress aktuelle Sendung
#35 * * * * root /usr/bin/omxplayer --vol -900 "$(/usr/bin/youtube-dl -g 'https://www.zdf.de/nachrichten/heute-sendungen/videos/heute-xpress-aktuelle-sendung-100.html')" > /dev/null 2>&1
## Tagesschau 100 Sekunden
#40 * * * * root /usr/bin/omxplayer --vol -900 "$(/usr/bin/youtube-dl -g 'https://www.tagesschau.de/100sekunden/')" > /dev/null 2>&1
## Morgennachrichten heute SAT1
#45 * * * * root /usr/bin/omxplayer --vol -900 "$(/usr/bin/youtube-dl -g "$(/usr/bin/date +'https://www.sat1.de/news/video/morgennachrichten-\%d-\%m-\%Y-clip')")" > /dev/null 2>&1
## Earth
#50 * * * * root /usr/bin/omxplayer --vol -90000 "$(/usr/bin/youtube-dl -f mp4 -g 'https://www.youtube.com/watch?v=HiN6Ag5-DrU')" > /dev/null 2>&1
## -1080'TV Wetterschau von heute
#55 * * * * root /usr/bin/omxplayer --vol -900 $(/usr/bin/youtube-dl -g "$(/usr/bin/date +'https://www.otv.de/mediathek/kategorie/sendungen/otv-wetterschau/video/das-wetter-vom-\%d-\%m-\%Y/')") > /dev/null 2>&1
EOL
systemctl start cronie
systemctl enable cronie
########################################################################
# create system group autologin and add user alarm to group
########################################################################
groupadd -f -r autologin
gpasswd -a alarm autologin

########################################################################
# create .xinitrc for user alarm
########################################################################
cat >"/home/alarm/.xinitrc" <<EOL
#!/bin/sh
userresources=\$HOME/.Xresources
usermodmap=\$HOME/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap
# merge in defaults and keymaps
if [ -f \$sysresources ]; then
    xrdb -merge \$sysresources
fi
if [ -f \$sysmodmap ]; then
    xmodmap \$sysmodmap
fi
if [ -f "\$userresources" ]; then
    xrdb -merge "$userresources"
fi
if [ -f "\$usermodmap" ]; then
    xmodmap "\$usermodmap"
fi
# start some nice programs
if [ -d /etc/X11/xinit/xinitrc.d ] ; then
 for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
  [ -x "\$f" ] && . "\$f"
 done
 unset f
fi
twm &
xclock -geometry 50x50-1+1 &
xterm -geometry 80x50+494+51 &
xterm -geometry 80x20+494-0 &
exec startfluxbox
EOL
chown alarm:alarm /home/alarm/.xinitrc

########################################################################
# create /etc/lightdm
########################################################################
[[ -d /etc/lightdm ]] || mkdir -p /etc/lightdm/
########################################################################
# configure lightdm.conf for autologin of user alarm and more
########################################################################
cat >"/etc/lightdm/lightdm.conf" <<EOL
[LightDM]
start-default-seat=true
greeter-user=lightdm
minimum-display-number=0
minimum-vt=7 # Setting this to a value < 7 implies security issues, see FS#46799
user-authority-in-system-dir=false
run-directory=/run/lightdm
dbus-service=true
[Seat:*]
autologin-user=alarm
autologin-user-timeout=0
xserver-display-number=7
greeter-session=lightdm-gtk-greeter
user-session=fluxbox
session-wrapper=/etc/lightdm/Xsession
[XDMCPServer]
[VNCServer]
EOL

########################################################################
# create .fluxbox folder in home of user alarm and fix permissions
########################################################################
[[ -d /home/alarm/.fluxbox ]] || mkdir -p /home/alarm/.fluxbox/
chown alarm:alarm /home/alarm/.fluxbox
########################################################################
# create fluxbox startup script to autostart browser for our URL
########################################################################
cat >"/home/alarm/.fluxbox/startup" <<EOL
xmodmap "/home/alarm/.Xmodmap"
########################################################################
# disable screensaver and blanking of monitor
########################################################################
xset s off
xset s noblank
xset -dpms

########################################################################
# set url for Browsers
########################################################################
url='https://chemnitzer.linux-tage.de/'
########################################################################

########################################################################
# applications to run with fluxbox add & at the end
########################################################################
########################################################################
# hide mouse cursor on inactivity with unclutter
unclutter &
########################################################################

########################################################################
# PREPARE FOR FIREFOX
########################################################################
# remove links/folders in alarms home dir for firefox
rm -r -f /home/alarm/.mozilla
rm -r -f /home/alarm/.cache/mozilla
# remove mozilla ramdisk folder if exists
rm -r -f /dev/shm/mozilla
# (re)create mozilla folder in ramdisk /dev/shm
mkdir -p /dev/shm/mozilla
# point firefox folders to /dev/shm/mozilla
ln -sfrn /dev/shm/mozilla /home/alarm/.mozilla
ln -sfrn /dev/shm/mozilla /home/alarm/.cache/mozilla

########################################################################
# PREPARE FOR CHROMIUM
########################################################################
# kill all chromium instances
killall chromium
# remove chromium singleton files and folder  if any
rm -r -f /tmp/.org.chromium.Chromium*
# remove links/folders in alarms home dir for chromium
rm -r -f /home/alarm/.config/chromium
rm -r -f /home/alarm/.cache/chromium
# remove chromium ramdisk folder if exists
rm -r -f /dev/shm/chromium
# (re)create chromium folder in ramdisk /dev/shm
mkdir -p /dev/shm/chromium
# point chromium folders to /dev/shm/chromium
ln -sfrn /dev/shm/chromium /home/alarm/.config/chromium
ln -sfrn /dev/shm/chromium /home/alarm/.cache/chromium

########################################################################
# START BROWSER
########################################################################
# Firefox in kiosk mode with url (make sure there is an '&' at the end
# Firefox needs ~150MB more RAM
#/usr/lib/firefox/firefox --kiosk \$url &

# Chromium in kiosk mode with url (make sure there is an '&' at the end
# --no-xshm makes Chromium work again!
# see https://archlinuxarm.org/forum/viewtopic.php?f=15&t=15001&p=65896&hilit=chromium#p65717
/usr/bin/chromium --ignore-certificate-errors --disable-features=TranslateUI --disable-features=Translate --disable-breakpad --start-fullscreen --incognito --no-first-run --disable-session-crashed-bubble --temp-profile --disable-infobars --noerrdialogs --noerrors --kiosk --no-xshm --no-shm \$url &

# START OMXPLAYER with youtube URL
#youtubeurl='https://www.youtube.com/watch?v=sajBySPeYH0' # Raspberry Pi 4: your new $35 computer
#/usr/bin/omxplayer -o hdmi "\$(youtube-dl -f mp4 -g \$youtubeurl | tail -n 1)" &

########################################################################
# finally start all of the above with fluxbox
########################################################################
exec fluxbox
EOL
chown alarm:alarm /home/alarm/.fluxbox/startup

########################################################################
# enable and start lightdm
########################################################################
systemctl enable lightdm
systemctl start lightdm

########################################################################
# point /home/alarm/.mozilla/firefox and /home/alarm/.cache/mozilla
# to ramdisk (/dev/shm)
#
# your Pi should have a minimum of 1GB RAM if you do that!
# could possibly work with 512MB
########################################################################
# /home/alarm/.mozilla/firefox
mkdir -p /home/alarm/.mozilla
chown alarm:alarm /home/alarm/.mozilla/
ln -sf /dev/shm /home/alarm/.mozilla/firefox
chown alarm:alarm /home/alarm/.mozilla/firefox
# /home/alarm/.cache/mozilla
mkdir -p /home/alarm/.cache
chown alarm:alarm /home/alarm/.cache
ln -sf /dev/shm /home/alarm/.cache/mozilla

########################################################################
# show pacnew files if any
########################################################################
echo "If any .pacnew files are listed here you have to manually take care!"
find / -xdev -iname "*.pacnew" -exec echo '{}' \;

########################################################################
# reboot info
########################################################################
echo -e "\n\nEven your system may work properly at this point"
echo -e "you should now reboot the Pi with the command 'reboot'\n\n"

########################################################################
#  END END END END END END END END END END END END END END END END END #
########################################################################
