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

```
#/boot/config.txt with http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-armv7-latest.tar.gz
#the dtoverlay parameter speeds up the browser/gpu
disable_overscan=1
hdmi_drive=2
hdmi_group=2
gpu_mem_1024=64
dtoverlay=vc4-kms-v3d
initramfs initramfs-linux.img followkernel
```
