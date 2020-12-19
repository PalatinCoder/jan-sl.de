---
title: "VM Shenanigans"
date: 2020-09-27T21:46:06+02:00
---

Obviously I wanted to setup a VM to try out Arch and see if I can come up with a suitable setup.
A drama in three acts.
<!--more-->

## Hyper V
Running Windows on my machine, going with Hyper V was the obvious choice, but Microsoft officially doesn't support Hyper V VMs in the Home version of Windows.
However, it is [possible][hyperv].
So I enabled the Hyper V role on my machine, created a new VM with pretty much the default settings, and installed Arch following the [installation guide] from the wiki.
The basic install went pretty well, although I struggled a bit with UEFI booting (more on that [here][boot]).

As I said in the [pilot], I had my eyes laid on the *material shell*, which is a GNOME extension. So I installed GNOME, following the Arch wiki. This is were things started to, well, take a turn...

First of all, being a complete desktop environment, GNOME comes with *a lot* of packages.
Additionally, the performance was very poor, with a lagging mouse cursor and animations with a felt speed of .5 fps.
This, however, is a known limitation of Hyper V's standard way of attaching to a VM and it is [recommended][hyperv-enhanced] to use a so called "enhanced session".
When connecting to an enhanced session, the Hyper V client basically doesn't connect to the VM's "graphic output" but uses a RDP connection instead.
I guess Microsoft's devs were ~~to lazy~~ out of budget to implement a decent way of having a graphical session, so they just reused the RDP client - nice move.
The problem with this, however, is that Wayland and RDP don't really go together. VNC is well supported, but that in turn can't be used with Hyper V. Yikes.

Somewhere along this lines I had the idea of trying a plain window manager and see if this would give me usable performance in a non-enhanced session.
I wanted to go with Wayland, so I chose Sway, being the most feature complete and mature tiling wm for Wayland at the moment.
This was a total failure as well, as Sway didn't start at all in the Hyper V VM. (Something about it not being able to open a drm device - I don't even remember anymore 😅)
However, I decided to stick with it. And after three days of fighting Hyper V, it was also clear that I need a different solution for virtualization.

## VirtualBox
Create a VM, give it the Arch ISO, do the basic setup - I pretty much had that in my finger's muscle memory at this point.
But, surprisingly, preparing the root partition with `pacstrap` was the end of the road in VirtualBox.
Pacman kept complaining about corrupted package databases.
Trying another mirror usually is the first aid in this case, but the like ten mirrors I tried all had corrupted databases.
WTF? Are all Arch mirrors broken? Of course they were not.
Pacman couldn't work with the databases as it had no luck verifying their signatures.
This was due to crypto stuff not working under VirtualBox.
These problems turned out to be known when running VirtualBox under Windows which has Hyper V enabled - which I have, not only for the first act of this drama but also for Docker Desktop and WSL and all that stuff.
"No luck at all", I tought, while uninstalling VirtualBox and setting up VMware.

## VMWare Workstation
Creating a VM in VMware Workstation, it told me, that running 64bit guests wasn't possible at all. WTF again?
As it turns out, VMware had the same difficulties as VirtualBox when Hyper V is enabled in Windows, so instead of having broken VMs it refuses to create them in the first place (how thoughtful).
Luckily, I happened to be on a somewhat older revision and updating Workstation fixed that issue.

From here, it finally was a pretty straight forward experience.
Install Arch (from muscle memory), install `openvm-tools` again following the [wiki][wiki-vmware], and here we go.
Almost. There was this little inconvenience of Sway only getting a black screen when starting Sway.
Another round of googling told me that all I had to do was start Sway with `WLR_NO_HARDWARE_CURSOR=1` being set.

Finally, I was greeted with Sway's default background image. Now let the fun begin.

### Shared Folders
Sharing Folders from the host to the guest is the easy way to get files into my Arch VM from my Windows host.
Also setting them up was almost to easy - there is not much more to say other than to follow the [wiki][wiki-vmware].
Basically it boils down to

1. Define the shared folder in the VM settings
2. Mount it with `vmhgfs-fuse`. I created a systemd service for that, as suggested in the wiki.

### Still to come
Something, maybe? - I will update this post as I go along.

[hyperv]: https://www.deskmodder.de/blog/2018/08/23/windows-10-home-hyper-v-aktivieren/
[hyperv-enhanced]: https://wiki.archlinux.org/index.php/Hyper-V#Enhanced_session_mode
[installation guide]: https://wiki.archlinux.org/index.php/installation_guide
[boot]: {{<ref "setup.md#booting" >}}
[pilot]: {{<ref "pilot.md" >}}
[wiki-vmware]: https://wiki.archlinux.org/index.php/VMware/Install_Arch_Linux_as_a_guest
