# VNC Server

If you want to test your setup without connecting a monitor to your Pi you can install and start a VNC server.

<!-- TOC -->

- [VNC Server](#vnc-server)
    - [Install x11vnc](#install-x11vnc)
    - [Create password file for x11vnc](#create-password-file-for-x11vnc)
    - [Create x11-vnc systemd drop-in override](#create-x11-vnc-systemd-drop-in-override)
    - [Start x11vnc](#start-x11vnc)

<!-- /TOC -->


## Install x11vnc

Connect to your Pi using SSH. Become root using `su -` and provide the root password (default=`root`), then execute the following commands to install x11 vnc:

```
$# pacman -Sy
$# pacman -S x11vnc --noconfirm
```

## Create password file for x11vnc

Now create the file containing the VNC password (`/etc/x11vnc.passwd`) by executing the following command:

```
$# x11vnc -storepasswd alarm /etc/x11vnc.passwd # password 'alarm'
```

## Create x11-vnc systemd drop-in override

Now create a so called **drop-in** folder to be able to create a **drop-in-file** to override the default settings of `x11vnc

```
$# mkdir -p /etc/systemd/system/x11vnc.service.d/
```

Then create the **drop-in-file** `/etc/systemd/system/x11vnc.service.d/override.conf`using your favorite editor:

```
# /etc/systemd/system/x11vnc.service.d/override.conf
[Service]
# Set password by running `sudo x11vnc -storepasswd [PASSWORD] /etc/x11vnc.passwd`
ExecStart=
ExecStart=/usr/bin/x11vnc -auth guess -forever -loop -noxdamage -repeat -rfbauth /etc/x11vnc.passwd -rfbport 5900 -shared
```

Now reload the systemd configuration files with

```
$# systemctl daemon-reload
```

## Start x11vnc

You can now start the x11vnc service by executing:

```
$# systemctl start x11vnc
```

To enable autostart for x11vnc additionally do a

```
$# systemctl enable x11vnc
```

You should now be able to connect to the Pi using VNCViewer and point it to your Pis **IP** address at **port 5900**.
