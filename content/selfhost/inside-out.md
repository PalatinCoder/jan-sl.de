---
title: "Turning the World Inside Out"
date: 2021-09-20T10:49:23+02:00
---

As I wrote before, using bhyve as hypervisor has proven to be not the most battle-tested solution.
To make my life a little bit easier, I decided to use Proxmox VE as my hypervisor and virtualize my TrueNAS box, instead of using TrueNAS as virtualization host.

<!--more-->

# Why TrueNAS in the first place?

The decision to install TrueNAS on bare metal was based on recommendations you read all over the internet to *not* virtualize TrueNAS.
This is recommended because when using ZFS, it should have bare metal access to the drives and controller to make use of it's error correction.
Some say that there's even the risk of data corruption or data loss when a virtualization layer is in between ZFS and the drives, if no special precaution is taken.
Naturally, that scared me a little when I was getting started, so I followed the recommendation, knowing that I can have VMs in TrueNAS as well.

However, TrueNAS is built as a storage appliance and the virtualization features are just bonus.
You can feel that everytime you try to manage a VM through the web interface.
Also, [cloning VMs and using cloud-init](truenas-cloud-init) was more of a hassle to setup than a help.
Although I learned a lot setting it up, in hindsight it would've been easier using a purpose-built virtualization system as a base instead of a storage appliance.

# Can it be done?

As already mentioned, TrueNAS can be virtualized but special caution must be taken regarding the drives.
The optimal case would be to have a seperate SATA controller on the motherboard which can be completely passed through to the TrueNAS VM.
And guess what, my Supermicro A2SDI-4C-HLN4F has exactly that!
There are a total of 8 SATA ports, 4 of which are internally on the motherboard and share their controller with the M.2 slot.
The remaining four are the hot swap bays, which are connected to their own controller. Awesome :tada:!
That means that I can use my 250GB SSD as a boot drive and storage for Proxmox, while passing through the hot swappable HDDs to TrueNAS.

# Proxmox Setup

As for the installation of Proxmox itself, I just downloaded the latest ISO and let the installer do its thing. (Having pulled the HDDs out, just in case :smile:)

To use PCIe passthrough though it is necessary to enable the IOMMU.
As opposed to many guides on the internet, using PVE 7.0, I only had to append `intel_iommu=on` to the kernel commandline by editing `/etc/default/grub`.
Then, when defining a VM, a PCI host device can be added.

Of course, I need to find out which one of the PCI devices is the right SATA controller, but that's not to difficult:
```sh
$ lspci
(...)
00:13.0 SATA controller: Intel Corporation Atom Processor C3000 Series SATA Controller 0 (rev 11)
00:14.0 SATA controller: Intel Corporation Atom Processor C3000 Series SATA Controller 1 (rev 11)
```
Here's the two of them, so which one is the hot swap bay?
```sh
$ ls -l /sys/block/sd*
lrwxrwxrwx 1 root root 0 Dec 13 16:49 /sys/block/sdc -> ../devices/pci0000:00/0000:00:14.0/ata5/host4/target4:0:0/4:0:0:0/block/sdc
```
Now, knowing that `sdc` is the boot drive, I can see that the pci device `00:14.0` is the SATA controller corresponding to the onboard ports, so the other one must be the hot swap bays.

# TrueNAS Installation

Once Proxmox VE was setup, I straight forward installed TrueNAS with the latest ISO.
Having attached the SATA controller via PCIe passthrough, my hard disks showed up in TrueNAS as soon as I plugged them in and I could import the Pool without any problems.
Honestly, it was that easy! :smile:  Awesome! :tada:

However, with the storage system being virtualized, there is the danger of a chicken-and-egg situation.
Of course, the bulk storage in TrueNAS shall be used to store VM disks and backups and all that stuff, so the NFS exports are setup in Proxmox as storage.
That means, obviously, that the TrueNAS VM must be booted before Proxmox can access the storage where backups and possibly other VM disks are.
Luckily, Proxmox is not to fussy about NFS mounts only becoming available after it has already booted.
And furthermore, one can define a startup order for the VMs and containers, where everything that has *no* explicit order set is started after everything *with* an order.
So by just setting the TrueNAS VMs order to, say, 2 and giving it a startup delay of 5 minutes, I can be reasonably confident that TrueNAS has booted before everything else comes up.
(Sidenote: This has meanwhile proven to work, as I accidentally tripped the RCD while doing some electrical work :see_no_evil:)
However, this only works in the startup/shutdown the whole server scenario.
There is also the scenario where TrueNAS itself updates, so only this VM restarts.
I'll have to see how to handle that case when I setup other VMs and services that also use some of the NFS shares.
But now, having setup Proxmox as hypverisor, I have a solid base for my completely over-engineered homelab that's to come :laughing::tada:

[truenas-cloud-init]: {{<ref "selfhost/truenas-cloud-init.md" >}}
[pve-pci-passthrough]: https://pve.proxmox.com/wiki/Pci_passthrough
