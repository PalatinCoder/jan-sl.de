---
title: "Reproduction (or: Configuration Management)"
date: 2020-12-27T13:33:59+01:00
---

After more than three months, I've gotten used to Arch and I quite like it, so I want to expand my usage of it.
For that, I need to find out exactly how the setup came to be what it is, in order to replicate it.
Or even better, a way to track and document all the steps needed.
There are many different ways to accomplish this, mine will be: Ansible!

<!--more-->
I chose Ansible for it being simple yet powerful, but most importantly for me, for being lightweight (as in *agentless*).
I have a lot of things planned with Ansible covering my homelab and public services, well basically I want to manage *everything* with it :sweat_smile:.

For the beginning, I chose my workstation to be the first system I manage with ansible.
As I transition with my Arch workstation from a VM to bare metal, I'm looking for an easy way to basically replicate the VM, and manage the workstation's configuration in the future.
With Ansible, my overall goal is to boot the archiso, partition the disk, `pacstrap` it with Ansible, run the playbook and end up with a fully provisioned workstation.
So in this post I'll find out what makes my current setup my current setup. 

## What have I done?

Regarding the system setup, I need to find out basically two things:

* Which packages are installed
* Which system-level config files have been changed (typically in `/etc`)

All other aspects of my setup are user-related and thus are covered in my [dotfiles][dots].

### Generating package lists

Luckily we have pacman, which makes this job *very* easy.

First, let's get a list of packages from the official repositories, by **Q**uerying **e**xplicitly installed packages (**q**uietly).
The `-n` modifier limits the query to native, i.e. "official", packages.
```sh
$ pacman -Qqen > packages-explicit.txt
```
Then, we change the `-n` modifier to `-m`, which lists "foreign", i.e. AUR or local packages:
```sh
$ pacman -Qqem > packages-aur.txt
```

With this, I got a handful of AUR packages and 72 official packages, but that can be cleaned up a little bit.

First, let's try adding the `-t` modifier to the pacman query.
```sh
$ pacman -Qqent > packages-explicit.txt
```
This time, I only get packages that are explicitly installed *and* are not a dependency of another explicitly installed package.
For example, I have explicitly installed `firefox` as well as `firefox-i18n-de`, where the former would be pulled in as a dependency for the latter.

For me, that made a difference of around 30 packages, a lot of them being members of the group `base-devel`, which I installed during initial setup.
When installing a group, all of it's members are marked as being explicitly installed in pacman's database, so there is no obvious way to see if package came in with a group.
You can query all installed packages, which also belong to a group, with `pacman -Qg`.
From here, you can see candidates of groups that could be installed on the system.
To check if a group is in fact fully installed, the repos can be queried: with `pacman -Sg <group>`.

These queries showed me that `base-devel` is the only group I have fully installed.
Consequently, I can add `base-devel` to the list of explicitly installed packages.
But before, I need to clean the members of the group out, which is as easy as:
```sh
$ comm -23 packages-explicit.txt packages-base-devel.txt > packages-explicit-cleaned.txt
```

Now, I still have 16 more explicit packages than independent ones.
I manually compared them using `vimdiff` and checked all of them. As it turned out, all but 2 exceptions were optional dependencies for other packages and thus got filtered out by the `-t` modifier.
However, I still need to explicitly install them, as optional dependencies don't get pulled in automatically (obviously).

Okay, that's the first part done - I have my list of packages.

### Finding config files

The first idea to find all the config files I changed was a bit naive: Find all files edited by my user id:
```sh
$ find /etc -type f -user jan
```
That however doesn't work too well, since one does most of the changes in `/etc` via `sudo`, and thus as `root`.

So I need a different strategy.
Luckily, pacman can help us out here.
Querying for installed packages with `pacman -Qii` will give us detailed information about every package, including it's files and their state.
To get a nice list out of that, we can do some `awk` filtering:
```sh
$ pacman -Qii | awk '/^MODIFIED/ {print $2}' > modified.txt
```
But there are not only modified files, there could as well be files that I created - how do we find these?
First, let's compile a list of all files in `/etc`:
```sh
$ find /etc -type f | sort -d > all.txt
```
Second, we slightly modify the awk filter so we get all files owned by a package:
```sh
$ pacman -Qii | awk '/^(UN)?MODIFIED/ {print $2}' | sort -d > package-owned.txt
```
All that's left now is to compare the two lists to see which config files are not owned by any package:
```sh
$ comm -23 all.txt package-owned.txt > diff.txt
$ wc -l *.txt
  441 all.txt
  291 diff.txt
  156 package-owned.txt
```
Well, that strategy could only rule out 156 packages, so it seems I'm gonna be scrolling through a list of around 300 files and see if I recognize some of them :man-shrugging:.
As it turns out, around 150 of them were the root CAs and another 50 were font conf, so 200 more files I could rule out quickly.

In the end, I came up with the following manageable list of files which I need to consider (annotated with why they are changed):
```
/etc/hostname                                           # base setup
/etc/hosts
/etc/fstab                                              # partitioning
/etc/locale.conf                                        # system localization
/etc/locale.gen
/etc/vconsole.conf
/etc/group                                              # users, groups, etc
/etc/passwd
/etc/sudoers
/etc/shells                                             # installing zsh
/etc/systemd/network/10-ens33-dhcp.network              # ethernet config for systemd-networkd
/etc/systemd/system/getty@tty1.service.d/override.conf  # autologin on tty1
/etc/systemd/system/mnt-hgfs.service                    # VMware shared folders
```

Alright, that's the second task done.

The next step now is to bring all this information into an ansible playbook and see if my current setup can be replicated automatically. But that's the job for another blog post!

[dots]: {{<ref "itryarch/dotfiles.md" >}}
