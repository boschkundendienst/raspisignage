## no display


### Pi 3B+ with ArchLinuxARM-rpi-armv7-latest.tar.gz

```
#/boot/config.txt with http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-armv7-latest.tar.gz
hdmi_force_hotplug=1
disable_overscan=1
dtparam=audio=on
initramfs initramfs-linux.img followkernel
```

### Pi 4 with ArchLinuxARM-rpi-armv7-latest.tar.gz

The dtoverlay parameter speeds up the browser/gpu but take care since **omxplayer** will not work with vc4-kms-v3d but **works with vc4-fkms-v3d.**

**Make sure to plug the HDMI cable to *HDMI1*. This is the one furthest away from the power connection!**

```
# /boot/config.txt with http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-armv7-latest.tar.gz
# See /boot/overlays/README for all available options
disable_overscan=1
#dtoverlay=vc4-kms-v3d
dtoverlay=vc4-fkms-v3d
initramfs initramfs-linux.img followkernel

# Uncomment to enable bluetooth
#dtparam=krnbt=on

[pi4]
# Run as fast as firmware / board allows
arm_boost=1
```

## Wordpress

### Wordpress page not showing or chopped up

A non-working or chopped up wordpress site usually occurs if the IP address of the Pi (configured as server) had an IP change. To fix it, just rerun `srv_rootafterboot.bash` again on the Pi. This will update the IP address in the necessary configuration files. As a side effect, the passwords for the database and the `dsadmin` account will be re-generated, so watch for the output of the script to have the new passwords available.

### I forgot the password for dsadmin

If you forgot the password for the user `dsadmin`, just rerun the script `srv_rootafterboot.bash` on the Pi. It will regenerate all passwords! Make sure you watch the output of the script to get the new passwords.
