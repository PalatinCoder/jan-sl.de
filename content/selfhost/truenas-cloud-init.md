---
title: "Provisioning VMs with cloud-init on TrueNAS"
date: 2021-04-11T08:47:21+02:00
---

The core to a home lab is some sort of virtualization, i.e. a hypervisor on which you can deploy virtual machines.
Ideally, deploying the VMs should be simple and fast, and that's what [cloud-init](https://cloud-init.io) was built for.
In my case, running FreeBSD-based TrueNAS, `bhyve` is the hypervisor - which doesn't make life easier, but it works!

<!--more-->

The way cloud providers are able to provision VMs in seconds is to have preconfigured, stripped down images of the operating system.
For a new VM the image is used as the hard disk, so instead of installing the operating system they're actually booting an already setup system.
But provisioning a system means more that partitioning and installing the base packages.
At the very least there's network configuration to do, as well as setting a hostname and configure ssh for remote access.
This is where `cloud-init` comes into play.
It runs in several stages during boot, reading metadata from a multitude of sources.
Usualy using some sort of API of the cloud service, for home use it can also read it's metadata from an iso, which has to consist of a file called `user-data` `meta-data`, and the label `CIDATA`.

With a simple `user-data` like the following, such an iso can be created easily:

```yaml
#cloud-config
users:
  - name: arch
    ssh_authorized_keys:
      - ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzd...
hostname: lab-test-01
```

```
$ touch meta-data
$ touch user-data
$ genisoimage -o cidata.iso -V cidata -r -J user-data meta-data
```

Now to actually fire up an instance of something I need a cloud-init enabled image.
Luckily, the [arch-boxes](https://gitlab.archlinux.org/archlinux/arch-boxes) project provides exactly that for Arch&nbsp;Linux!&nbsp;:tada:
Unfortunately, it comes as a `qcow` image for use with `qemu`, but `bhyve` has absolutely no idea what that is, so I need to convert it to a raw image:
```
$ qemu-img convert -O raw Arch-Linux_x86-64-cloudimg-XXXX.qcow2 Arch-Linux_x86-64-cloudimg.raw
```
Being on TrueNAS, instead of using a raw image I can make use of zfs volumes, which is what TrueNAS preferably uses to store VM disks.
As the raw image is, well, a raw image, "converting" it to a zvol is actually as easy as
```
# zfs create -V 2G tank/vms/archlinux-cloudimg
# cat Arch-Linux_x86-64-cloudimg.raw > /dev/zvol/tank/vms/archlinux-cloudimg
```
So a VM using this volume as disk and the user-data iso as additional cdrom drive should boot.
Of course the boot order must be minded, trying to boot from the iso won't really work :laughing:

### Well...
#### Nope.

My first try booting the image failed horribly.
I quickly put together a VM through the TrueNAS GUI, which uses UEFI boot by default.
The UEFI loader, however, failed to find anything to load and dropped me into the UEFI shell.
On close examination of the drive mapping in the UEFI shell and the image itself, I noticed that there is no EFI partition.
It's hardly surprising that that doesn't work :laughing:

Changing the boot mode for the VM to UEFI-CSM unfortunately cost me around a whole day of troubleshooting the wrong problem :see_no_evil:.
Bhyve offers a VNC device attached to a VM, but only if booting in UEFI mode.
With UEFI-CSM I have to fall back to the serial console, and that's where I saw.... nothing.
Long story short: I tinkered around with different boot modes for the whole day because I thought the image wouldn't boot, when it was actually just *not* outputting anything to the serial console. :angry:

In the process I made an important discovery:
Trying to control the VM form the shell instead of the GUI, none of the usual FreeBSD and bhyve management utilities seemed to know my VMs.
In the output of `ps`, the bhyve processes command line only has the VMs name, so it must know the definition from somewhere I tought.
Looking around the filesystem I found it: They are using `libvirt` and thus `virsh` :tada:!

This discovery led me to the right track then, as I was able to do `virsh start --console <vm>`.
That means that the boot is delayed until the console is connected, and thus I was able to see early output of the bootloader and even interact with the UEFI.
Testing with different images (archiso, Arch cloudimage, Ubuntu) some of them had the bootloader output to serial console, and from there I could change the kernel command line to use the serial console as well.

From there I finally knew what I had to do.
I spun up an instance of the cloud image with the following `user-data`:
```yaml
#cloud-config
timezone: Europe/Berlin

# Change grub config to use serial console
write_files:
  - content: |
      GRUB_DEFAULT=0
      GRUB_TIMEOUT=1
      GRUB_DISTRIBUTOR="Arch"
      GRUB_CMDLINE_LINUX_DEFAULT="rootflags=compress-force=zstd console=ttyS0,9600"
      GRUB_CMDLINE_LINUX="net.ifnames=0"
      GRUB_PRELOAD_MODULES="part_gpt part_msdos"
      GRUB_SERIAL_COMMAND="serial --unit=0 --speed=9600"
      GRUB_TERMINAL_INPUT=serial
      GRUB_TERMINAL_OUTPUT=serial
    path: /etc/default/grub
runcmd:
  - [ grub-mkconfig, -o, '/boot/grub/grub.cfg' ]
  - [ cloud-init, 'clean', '--logs' ]
# poweroff when done
power_state:
  mode: poweroff
```
Et voilà, output!
The `user-data` changes the grub config to use the serial console and shuts down as soon as the initial provisioning is done.
Additionally, it removes cloud-init's logs before it's finished so it looks like cloud-init never even ran on the machine.

## Clone the gold

This now allows me to use this user-data to create a golden copy, based on which I can then clone further VMs and provision them with their own user-data.
After setting up the volume like described earlier and creating a VM with the cidata.iso attached, I just boot it and wait for it to poweroff again.
As soon as the VM has powered off, the goldencopy is complete and ready for cloning!

To clone it, I can just use TrueNAS GUI's included cloning feature, making sure to give the machine the correct cidata.iso.
As they will have the grub config already setup correctly, I can watch them boot with the integrated serial console to check SSH keys and the IP they were assigned.
Using this procedure, it takes me less than five minutes from creating a user-data to a fully provisioned VM!
That's pretty awesome, however I'm already thinking of using ansible to automate creating the user-data files and the cidata.iso, as well as maybe even clone the VM to get even faster :laughing:
