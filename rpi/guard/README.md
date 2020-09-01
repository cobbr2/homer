No need to mount anything, rpi mounts usb drives automatically.

To avoid the cameras logging in, set RequireValidShell to *off* in proftpd.conf,
and use /usr/sbin/nologin for their shells
