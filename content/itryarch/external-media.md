---
title: "External Media"
date: 2020-10-24T20:09:45+02:00
---

While trying out [photography workflows][1] I discovered that I need to configure how external storage (or devices) such as SD cards are automatically mounted when plugging them in.
You can, of course, don't automount them and `sudo mount` and `sudo unmount` them all the time, but I want a little more convenience.

## udisks

[Udisks][2] is a utility that let's users other than root handle (un)mounting file systems.
Also it auto creates the needed mountpoints:

```
$ udisksctl mount -b /dev/mmcblk0p1
Mounted /dev/mmcblk0p1 at /run/media/jan/EOS_DIGITAL
```

That's already better, but still not automatic

## udiskie

There are several mount helpers listed in the Arch wiki, for me the easiest was to install [Udiskie][3].
For the first try, you can just run `udiskie` in the foreground.
Upon inserting the SD card you see it automatically mounting the device (by using udisks2 under the hood).
So that's pretty nice, but I don't want to run `udiskie` in the foreground all the time.

To run `udiskie` in the background, I wrote a simple systemd user service:
```
[Unit]
Description=Udiskie auto mount utility

[Service]
ExecStart=/usr/bin/udiskie

[Install]
WantedBy=default.target
```

Now just enable it with `systemctl --user enable --now udiskie` and have your external media mounted automatically!

Runnig udiskie as a systemd unit has the advantage of having all it's output available via `journalctl -u udiskie`.
Also autostarting it with sway would mean that another window manager would also have to do that, should I switch to anotherone, so letting systemd handle such a system task felt right.

So why a user service instead of a system-wide service? Well, I guess there's no big difference on a single user system.
However I try to do as much as possible configuration in my `$XDG_CONFIG_HOME` so I can keep it nicely under version control, and leave `/etc` as default as possible.

[1]: {{<ref "photography-workflow.md" >}}
[2]: https://wiki.archlinux.org/index.php/Udisks
[3]: https://github.com/coldfix/udiskie

