---
title: "The Real Deal"
date: 2021-03-07T19:55:47+01:00
---

Enough playing around, let's install on real hardware! :muscle:
<!--more-->

Installing on real hardware, I had to face several problems:

1. Thunderbolt
1. Fake RAID
1. Small EFI Partition
1. Bootloader
1. Boot partition mounting

Let's get started :laughing:

## Thunderbolt

I have a Thunderbolt 3 dock for my laptop, which not only has USB, Ethernet and power connections, but also an integrated graphics card from Nvidia.
This is pretty awesome since I can have my laptop connect to all my peripherals with one connection *and* even have a decent graphics performance while docked.
Even better, the [wiki][wiki-tb] says:
> Thunderbolt 3 works out of the box with recent Linux kernel versions

So obivously, I was pretty disappointed when I booted into the Arch install medium for the first time and all my peripherals stayed black.
As it turns out (and I read, again, in the wiki), Thunderbolt has some security modes to, among others, prevent DMA attacks.
The security mode is set at firmware level, and mine is set to "user" - so I (or the operating system) have to authorize every device every time it is connected, the firmware doesn't automatically accept any device.
Unfortunately, the very limited firmware Acer put into my device doesn't allow me to change this...

Since the firmware is incapable, I need a userspace tool to make my devices work (obviously I need at least a working keyboard while booted from the installation medium :sweat_smile:).
To get this, I had to create a custom [Arch installation medium][wiki-archiso], which fortunately is pretty easy.
To install `bolt` as an additional package, only one line in the `packages.x86_64` config file was neccessary.

So with bolt now in the installation medium, I could authorize devices using `boltctl authorize <uuid>`, and my keyboard lit up (the monitors not quite yet, but I'll get to that).
However, I don't know about you, but I find typing UUIDs on a command line more than annoying.
In a permanent installation, the authorization of a device can be stored in a database by boltctl, but in a live system this isn't possible.
To make this a little more confortable, I added the following `udev` rule to the installation medium, as suggested in the [wiki][wiki-tb]:
```
ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"
```

For my permanent setup, I only added `bolt` to the list of packages being installed in my [ansible playbook][reproduction-2].

### Multihead virtual console

Now with Thunderbolt working, I'd like to have the console on the external monitors as well.
These are connected to the GPU in the Thunderbolt dock, so they are not available at boot time and I needed a way to activate them later on.
I found an interesting kernel parameter: `fbcon=map:01`, which defines the mapping between the framebuffer consoles and which actual framebuffer the are connected to.
Using `map:01`, I get the first console (i.e. `tty1`) on fb0, the second one on fb1, the third one again on fb0 and so on, so boot messages are visible on the internal display of the notebook, and once booted and the external displays are active I can change to `tty2` on the external monitor.
Nice :smile:

## Windows (and a small EFI partition)

With Windows being installed on the machine, it does already have a UEFI partition with a size of 100MB.
Having a quick look around showed that there was more than 50% in use, and while I could fit a kernel in there, squeezing in the initrds would get a little tight.
Resizing the partition is not an option, since the Windows root partition follows directly and I didn't want to get into the hassle of moving partitions around.
The most common solution to this is to use an extended bootloader partition and to use a bootloader which can load the kernel from it.
I, however, wanted to use EFISTUB for booting (keep on reading to hear why I still needed to change this tought :laughing:).
I came up with a different solution:
Scaning through the directories, I found the Windows boot environment *twice*.
I suppose this is Acer's Disk2Disk recovery, which I don't want to use anyway (and whose partition I already deleted), so I just deleted these files as well.
Et Voilà, a roomy EFI partition!

Now to have Windows and Arch dualbooting nicely together, Windows has to follow some rules.
First, Fastboot needs to be disabled to prevent Windows from messing up the EFI partition.
Second, Windows set's the hardware clock of the system in *local time* (:man-facepalming:), while every sensible other system expects it in UTC.
This can be fixed with a little registry value, and all of this is described (you guessed it) in the [wiki][wiki-dualboot].

## Fake RAID

On my system, I'm "blessed" with two SSDs in RAID 0, but it's Intel Rapid Storage Technology, so a software RAID which the operating system still has to manage.
But it's not too big of a problem, `mdadm` automatically recognizes the array without any problem, and someone else has [already done it][wiki-fakeraid].
The only thing to consider for me was including the `mdadm_udev` hook for `mkinitcpio`, so the kernel has `mdadm` in it's initial ramdisk to build the array and find the root partition.
To accomplish this, I added two `lineinfile` tasks to the playbook as well as a handler to regenerate the initrd when `/etc/mkinitcpio.conf` has been changed.

## Bootloader and partition discovery

For booting, I wanted to rely on the firmware and use [EFISTUB][wiki-efistub] again, so I created an entry in the firmware bootloader using `efibootmgr`.
However, it was not able to permanently create the entry and it wouldn't show up in the firmware boot menu.
After some fiddling around, I ended up using the UEFI shell and `bcfg` to create the entry.

Having setup the bootloader and run the playbook for the workstation, I happily booted into my new system.
But only several boots later I realized that I hadn't created an `fstab`. What?
Seems I accidentally got systemd's autodiscovery of partitions working!

Well, nearly.
Finding the root partition is easy for the system, as it is given on the kernel command line.
The home partition, however, is indeed automatically discovered and mounted by systemd.
What's missing is the UEFI partition at `/boot`.
According to `systemd-gpt-auto-generator(8)`, it *should* discover it as well by it's partition type.

##### Excursus: My first time really breaking Arch

Well you usually don't need the EFI partition in daily life.
But as it turns out, running a kernel upgrade and generating a new initrd without the actual EFI partition mounted at `/boot` doesn't work too well.
It will indeed put the kernel and the initrd into `/boot`, but obviously not on the actual partition :face_palm:.
Updating the kernel and libs and all that, without *actually* updating the kernel which is being booted, got me to a working system - at least that's what it looked like.
I got the login prompt - but somehow seemingly random things didn't work.
I got suspicous when systemd reported that loading kernel modules failed....
The fix was easy though, I booted the installation medium, chrooted into my install, downgraded the kernel from the pacman cache and then updated it again. This triggered the hook to regenerate the initrd, this time with `/boot` actually mounted, and the system was fine again. And because it was so much fun, I did it again (accidentally) :see_no_evil:.

Okay, so how to solve the problem of `/boot` not being mounted?

Reading the manpage helped here. For autodiscovery of the boot and root partitions, systemd needs a little help from the bootloader.
An EFI variable needs to be set indicating from which partition the kernel was booted, so systemd knows on which disk to search for partitions.
This variable is not set when booting with EFISTUB.
So I have two options: hardwiring the boot partition in the `fstab`, or using `systemd-boot` as a bootloader.
In the end, I decided to use `systemd-boot` as it gives me the autodiscovery as well as some nice gimmicks:
The `reboot` option of systemctl has a parameter to "preselect" which boot menu entry to boot next, so I can reboot into Windows from the command line.
Or I can even press the "w" key during boot and `systemd-boot` will boot Windows, without having to display a boot menu slowing down every boot.
Installing the bootloader, `efibootmgr` again wasn't able to put the entry properly into the NVRAM, so again the UEFI Shell and `bcfg` helped here.

Okay so with that done, one last thing is missing that tricked me:
Automounting the root partition.
It took some reading for me to find out that I may need yet another hook in the initrd, now the systemd one.
In hindsight, this makes perfect sense. I mean, how should systemd discover the root partition if it has to be loaded from that very partition first?
The huge problem in understanding that I had here was that *systemd*, not the *kernel*, discovers the partition, and that there are some more preconditions to be met other than assigning the correct partition UUIDs.
Nevertheless I gave up on that after hours and hours of experimenting with different hooks and kernel parameters and such, as systemd still couldn't mount root.
I also couldn't get into a recovery shell to see what's going on.
I assume the problem is with the fakeraid not being initialized when systemd wants to mount root, maybe some kind of ordering issue. But for the moment I don't bother anymore.

But yet again it holds true that you do learn *a lot* about a linux system when using Arch.
Because you *have* to do so much on your own, you are pretty much forced to learn and understand the inner workings of your system.
For me, who is eager for knowledge by nature, that's just perfect! :blush:



[wiki-tb]: https://wiki.archlinux.org/index.php/Thunderbolt
[wiki-archiso]: https://wiki.archlinux.org/index.php/Archiso
[reproduction-2]: {{<ref "itryarch/reproduction-2.md" >}}
[wiki-dualboot]: https://wiki.archlinux.org/index.php/Dual_boot_with_Windows
[wiki-fakeraid]: https://wiki.archlinux.org/index.php/Install_Arch_Linux_with_Fake_RAID
[wiki-efistub]: https://wiki.archlinux.org/index.php/EFISTUB
