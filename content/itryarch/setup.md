---
title: "Installation and Setup"
date: 2020-09-28T10:45:27+01:00
description: "This post describes the installation process of the base system and my overall desktop setup."
---

## Base system

For installing the base system I followed the [Arch Wiki's Installation Guide][arch_guide] for the most part.
It covers all essential aspects to get a functional system, while providing good context on *why* you need to do something.
Also, there are some points where you need to branch off and decide *how* *you* want to do a certain aspect.
These are the turns I took:

### Partitioning

I created a classical three partition layout with 300MB for EFI, 1.5GB for Swap and the remainder for the root partition.
Upon creating the filesystems, I ended up assigning labels like "boot", "swap", "arch" to the partitions. That allows them to be identified by label in `fstab` and, more importantly, by the bootloader.

I played around with [discoverable partitions][systemd_partitions] for a few hours.
Basically the discoverable partitions specification defines some well known GUIDs for partitions, which are defined to represent a specific partition (eg. root, swap, etc.).
This would allow the system to find the partitions only by their well known GUID and I wouldn't need the `root=` parameter on the kernel command line and I could even completely waive a `fstab`.
I liked the idea of autodiscovery, but I just could not get it to work, upon booting the kernel just wouldn't find it's root partition.
So after a few hours I ditched that and went with aforementioned labels instead.

### Booting

The first thing to come to my mind was obviously GRUB, but studying the [Wiki][wiki:bootprocess] this caught my eye:

> In the case of UEFI, the kernel itself can be directly launched by the UEFI using the EFI boot stub.

Good idea - why not work with what we already have and use the UEFI as boot manager.
The setup is described [here][wiki:EFISTUB].
I must say, however, fiddeling with `efibootmgr` and all the kernel parameters is not the nicest experience, but I don't typcially change my boot entries on a daily basis.
The previously mentioned labels came in handy here, as putting `root=LABEL=arch` is a *lot* less typing effort than putting `root=PARTUUID=...` and a 128bit UUID on the command line.

Here I tried the discoverable partitions to save me the hassle of putting them onto the command line, but, as I said, the kernel just wouldn't find the root partition.
I also tried systemd-boot for a moment, but that didn't boot as well (with the UUIDs). It did well with the labels, but so did EFISTUB on it's own, so I refrained from the extra component.

### Networking

I wanted something simple to manage the network interface(s), so I *didn't* install NetworkManager. Instead, I went with using `systemd-networkd` as well as `systemd-resolved`.
Since the system is based on systemd anyways, might as well go all the way? Well, especially the cli `networkctl` isn't as powerfull as NetworkManager, however I anticipated my networking configuration to be pretty stable so I wouldn't need a sophisticated tool to change it around all the time.
Further, as long as I'm in the virtual machine, I can always rely on the host's network ( ͡° ͜ʖ ͡°)

Aside from enabling both services, I currently have the following configuration file:

```
# /etc/systemd/network/00-ens33-dhcp.network
[Match]
Name=ens33

[Network]
DHCP=yes

[DHCP]
UseDomains=true
```
The `UseDomains=true` in the last section is important, since that makes `systemd-resolved` use whatever DNS suffix the DHCP server sent for the local network.

### Sound

So far, only installed `pulseaudio` - just worked. 🎉

## Window manager

As I already wrote in [VM Shenanigans][vm-shenanigans] I chose sway as my window manager.
The installation itself was pretty straight forward, basic configuration included setting the output positions (as I use two monitors), some keybindings and I was good to go.

You can find the full configuration in my [dotfiles][dotfiles], and I will dive deeper into how I set everything up (and made look nice) in a future post.

As for logging in and starting sway, there are a couple of different options.
Probably the most common would be using a display manager such as lightdm et al. to handle your login and start the window manager.
Another way I thought of is letting systemd start and manage the window manager, however this configuration is not supported by the devs and also generally seems to be the wrong way (see [sway#5160][sway:5160]).

As a quick way to get started (until I figure out that display manager thing), I just put the following into my `.zlogin` to startup sway when I login on tty1:

```
# Start sway on login on tty1
if [ "$(tty)" = "/dev/tty1" ]; then
	exec systemd-cat --identifier=sway sway
fi
```
Additionally I setup [autologin for agetty][wiki:autologin] so I'm automatically logged in on tty1 on boot, and when sway starts `swaylock` is executed immediately to lock the screen again.
This I a pretty hacky setup, I know, but it got me up and running pretty quickly.

### Systemd integration for Sway
Note the use of `systemd-cat` here to run sway: Some of the problems I had with sway (while still having the [VM caused troubles][vm-shenanigans]) I couldn't really debug since sway's output was pretty much gone when I exited the session, as it is just printed to `stdout`. By using `systemd-cat`, I can pipe the output of whatever command I tell it to run into the systemd journal, without actually running the programm as a sytemd service.
This is recommended as per the [sway wiki][sway:systemd-integration].

#### Autostarting apps

Initially I used the sway config file to `exec` some programs I want to automatically start with sway and have them running in the background, such as `waybar`, `swayidle` and `keepassxc`. However, I'll be moving this to systemd user services connected with a `sway-session.target`, as described in the [sway wiki][sway:systemd-integration], as I think it's the cleaner solution. I'll update this post, stay tuned!

**Update**: I successfully removed all the `exec`s from sway's config and run them as systemd user services, either with their own [service files][dots:user-services], or by linking their `.desktop` files into `$XDG_CONFIG_HOME/autostart`.
This setup runs smoothly now.
However one thing to keep in mind is that user services don't run inside your actual session (that's exactly why the sway devs think sway shouldn't be run as user service).
In my case that's no problem for the background services.
The only issue I ran into was `swayidle` not being able to discover what session it runs in, however that's already fixed upstream but just not released yet. Installing the AUR version helps for the moment :wink:

**Update Nr 2**: In the meantime, I refactored the [session startup][session-startup] quite a bit :laughing:


[arch_guide]: https://wiki.archlinux.org/index.php/Installation_guide
[systemd_partitions]: https://systemd.io/DISCOVERABLE_PARTITIONS/
[wiki:bootprocess]: https://wiki.archlinux.org/index.php/Arch_boot_process#Boot_loader
[wiki:EFISTUB]: https://wiki.archlinux.org/index.php/EFISTUB
[vm-shenanigans]: {{<ref "vm-shenanigans.md" >}}
[ricing]: TODO
[dotfiles]: https://github.com/PalatinCoder/dotfiles/tree/master/sway
[sway:5160]: https://github.com/swaywm/sway/issues/5160
[wiki:autologin]: https://wiki.archlinux.org/index.php/getty#Automatic_login_to_virtual_console
[sway:systemd-integration]: https://github.com/swaywm/sway/wiki/Systemd-integration
[dots:user-services]: https://github.com/PalatinCoder/dotfiles/tree/master/systemd/user
[session-startup]: {{< ref "itryarch/session-startup.md" >}}
