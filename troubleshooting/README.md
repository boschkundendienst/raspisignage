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
