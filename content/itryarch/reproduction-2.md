---
title: "Configuration Management, Part 2"
date: 2021-03-06T20:27:45+01:00
---

In the [previous post][part-1] I said:
> With Ansible, my overall goal is to boot the archiso, partition the disk, `pacstrap` it with Ansible, run the playbook and end up with a fully provisioned workstation.

Spoiler: I did actually achieve this! But not without some trouble :wink:
<!--more-->
I did most of the work already in [part 1][part-1] by generating a list of installed packages and identifying configuration files which need to be edited.
Copying/Editing files and installing packages are pretty unspectacular for ansible, so this should be pretty easy.
Well, generally, it is. But the devil is in the details.

I'm probably not going to publish my playbook on Github since it's specifically tailored for my machine (and I'm planning on hosting more of my code myself in my homelab, btw).
Instead, this post might get a little longer since I'll be putting a lot of examples in it.

## First, some spaghetti

Having no experience with ansible at all, I started by putting one task after the other in a playbook, loosely resembling the installation guide.
While developing the playbook, I repeatedly ran it with the `--check` and `--diff` options against my running machine to see if it would set it up correctly.
However, the large playbook quickly became unhandy, having a lot of tasks and blocks and even filecontents all over the place, so I made use of ansible's roles to modularize it.

In the my working directory, I created a role called `workstation`, consisting of smaller task files. All of them are pulled in by the `main.yml`:
```yaml
# roles/workstation/tasks/main.yml

- import_tasks: base.yml
  tags: setup

- import_tasks: net.yml
  tags: net

- import_tasks: packages.yml
  tags: packages

- import_tasks: vmware.yml
  tags: vmware
  when: ansible_facts['virtualization_role'] == "guest" and ansible_facts['virtualization_type'] == "VMware"

- import_tasks: user.yml
  tags: user

- import_tasks: dotfiles.yml
  tags: user,jan,dots
```
As you can see, I tag all of the import blogs so I can specifically chose a set of tasks to run (or to *not* run). The tasks themselves are also tagged, but we'll see that now when we look at them individually.
Also, the vmware block has a condition so VMware specific thing like `open-vm-tools` and the `hgfs` (shared folders) are only installed in a VM and not on bare metal.
There'll be a "bare metal" block containing firmware, microcode etc. once I get into the bare metal installation.

### The Base

The base tasks contain the initial steps of the installation guide.
Here I use the `copy`,`template` modules to set the hostname.
The single line in `/etc/hostname` is set by the copy module which doesn't only copy files but can have the content inline as well.
The hosts file however has a little more content so I used a template for that to keep the tasks file tidy.
In both cases I use the variable `inventory_hostname` to put the hostname I defined in the ansible inventory.
As I run the playbook with a local connection, and the host doesn't have a hostname yet, ansible obviously can't discover the hostname and would put `localhost` instead.

I'm not 100% happy with this solution, but it's the best I could come up with yet. (For the most part, I feel like I need a safety net to prevent me from accidentally applying the wrong configuration on a host, since connection=local connects to whereever it is running.

```yaml
# roles/workstation/tasks/base.yml
- name: base - hostname file
  tags: hostname
  copy: content="{{ inventory_hostname }}\n" dest=/etc/hostname

- name: base - hosts file
  tags: hostname
  template: src=etc-hosts.j2 dest=/etc/hosts
```

```
# roles/workstation/templates/etc-hosts.j2
127.0.0.1	localhost
::1		localhost
127.0.1.1	{{ inventory_hostname }}.localdomain {{ inventory_hostname }}
```

Still in the `base.yml`, I use the copy module some more to generate the locale config and set the timezone.
The latter needs a symlink, which is handled by the file module. Furthermore, the command module is used to execute the command which syncs the clock:
```yaml
- name: base - set timezone
  tags: locale
  file: src=/usr/share/zoneinfo/Europe/Berlin dest=/etc/localtime state=link

- name: base - create time adjustment
  command: hwclock --systohc
```

### The Networking

Now that I have the basic configuration set, I can setup the networking services of systemd.
That's also the first appearance of the systemd module to enable the services, after the network file is copied.
(The network file just has a generic match so that all interfaces have DHCP active by default. By naming it `99-*` I could place interface-specific configuration before it)
```yaml
# roles/workstation/tasks/net.yml
- name: net - systemd.network for dhcp
  copy: src=dhcp-all.network dest=/etc/systemd/network/99-dhcp-all.network

- name: net - enable systemd network services
  systemd: name={{ item }} enabled=true
  loop:
    - systemd-networkd
    - systemd-resolved
```
I use an ansible loop here to enable both services with one task.

### The Packages

Now for the fun part, let's install some packages! Ansible has a generic `package` module, but also an arch-specific `pacman` module.
```yaml
# roles/workstation/tasks/packages.yml
- name: packages - full system upgrade
  pacman: update_cache=yes upgrade=yes
```
Well, that was easy. Installing more packages isn't more complicated either:
```yaml
# roles/workstation/tasks/packages.yml
- name: packages - install
  pacman:
    state: latest
    name:
      - insert
      - packages
      - here
```
That's were my package list with all the explicitly installed packages form the previous post comes in.
Note that I don't use a loop here but pass an array of names.
This is for performance reasons. By giving an array, pacman is actually only called once and processes the list, whereas in a loop ansible would invoke pacman for each package seperately, taking A LOT longer.

So that went smooth until now, but we need some AUR packages as well.
Luckily, some awesome dude created the awesome [aur module][kewlfft-aur] for ansible, which supports installing AUR packages with a variety of AUR helpers.
The module can be installed from the AUR :face_palm:
And, none of the AUR helpers is in the official repos (at least not that I know of), so I need to install an AUR helper from the AUR to install packages from the AUR?
What sounds like a double chicken and egg problem actually resolves pretty easily.

The AUR module is listed as a dependency for the workstation role and put in `requirements.yml` in the root directory. Prior to running the playbook, I just have to run `ansible-galaxy install -r requirements.py` to install it.
Then, the module can fall back to a plain `makepkg` if it doesn't find any helper, so I can install `yay` in one task and then use it to install the other packages in another task:
```yaml
# roles/workstation/tasks/packages.yml
- name: packages - ensure AUR helper is present
  become: true
  become_user: sentinel
  tags: aur
  aur: name=yay use=makepkg state=present

- name: packages - ensure latest AUR packages
  become: true
  become_user: sentinel
  tags: aur
  aur:
    aur_only: yes
    state: latest
    name:
      - list
      - of
      - packages
```
But who is this `sentinel`, you might ask? Hang on, first let's connect:

### The Dots

At this point, we have a working system and the system level configuration is complete.
What's left now is the user environment.
The `user` task file uses the user module to create my user and add it to the necessary groups, as well as the `lineinfile` module to enable sudo for the `wheel` group.
```yaml
# roles/workstation/tasks/user.yml
- name: user - jan
  tags: user,personal
  user: state=present name=jan uid=1000 group=wheel groups=video shell=/usr/bin/zsh

- name: user - allow sudo for group wheel
  tags: user,personal
  lineinfile:
    path: /etc/sudoers
    state: present
    line: "%wheel ALL=(ALL) ALL"
    regexp: "%wheel ALL=\\(ALL\\) ALL$"
    validate: /usr/sbin/visudo -cf %s
```
Now I obviously need my dotfiles, so I use the git module to clone them in. Also, remember the part about the [changing environment in my dotfiles][dotfiles]?
With ansible, I make sure that `.zshenv` is in place so all my environment variables are set.
```yaml
# roles/workstation/tasks/dotfiles.yml
- name: user - jan - clone dotfiles
  tags: user,personal,dots
  become: true
  become_user: jan
  git:
    clone: yes
    dest: /home/jan/.config
    repo: https://github.com/PalatinCoder/dotfiles.git

- name: user - jan - zshenv
  tags: user,personal,dots
  become: true
  become_user: jan
  copy: content="export ZDOTDIR=/home/jan/.config/zsh\n" dest=/home/jan/.zshenv
```

### The Sentinel

The concept in my head for managing not only my workstation but also my servers with ansible provides a dedicated user with a dedicated ssh key which ansible uses to connect.
This user cannot be used to login to a machine. But it will be allowed to sudo without password, so the execution of a playbook can run without interaction.
I chose to name him `sentinel`, because, well it makes sense and I have some more The Matrix references in my homelab :wink:

I have setup a seperate role, called `manage`, which sets up the base requirements so a machine can be ansible managed.
For the moment, it only consists of creating the sentinel and allowing passwordless sudo:
```yaml
# roles/managed/tasks/main.yml
- name: ansible user
  tags: user
  user: state=present name=sentinel group=wheel comment="Ansible User" system=yes password='*' password_lock=yes uid=999

- name: passwordless sudo
  tags: user
  lineinfile:
    path: /etc/sudoers.d/ansible-sentinel-allow-all
    state: present
    line: "sentinel ALL=(ALL) NOPASSWD: ALL"
    validate: /usr/sbin/visudo -cf %s
    create: yes
```
When using a local connection however, ansible runs as the user which invokes it.
Setting up a new machine is usually done as root, so all the aforementioned actions (installing packages, editing config files, enabling services, etc) can be performed without problems.
When it comes to AUR packages however, `makepkg` as well as the AUR helpers refuse to run as root, to avoid damaging the system (I struggled with that during my test runs).
Conveniently, ansible can switch to another userid with the `become: yes` and `become_user: sentinel` options I have set in packages.yml.
Usually, this mechanism is used to elevate privileges when using an unprivileged account (which my concepts implements for servers by having the sentinel), but of course it also works the other way around :laughing:


Oh, by the way, if you missed the VMware tasks file: Nothing to see there, it just installs `open-vm-tools` and `xf86-video-vmware` with the pacman module and enables the services for `vmtoolsd` and `hgfs` with the systemd module - we already saw how that works :wink:
But now:

## Testrun(s)

Now this is where it get's interesting :joy:
Obviously I ran into a couple of problems during my test runs, one being the privilege problem I just discussed (and resolved).
Other than that, the test VM became unresponsive reproducibly when compiling one of the AUR packages. I could easily resolve this by giving it a *second* vCPU :joy:

Once that was resolved, the playbook went through pretty smoothly, however my shell prompt was all over the place once I logged into the newly provisioned machine.
I use [Powerlevel10k][p10k] as my shell prompt, which features different segments.
I wrote a segment myself to display the currently selected docker context, so I can see where my docker commands go to.
To display it, the custom segment reads `~/.docker/config.json` with `jq`.
On the new system however, that file wasn't there yet, as I hadn't used docker yet (obviously), so the `jq` command failed breaking the whole prompt. D'ouh!
Honestly, I did for real put a task in the playbook to create a dummy config file so it could be read by the prompt function.
But before even running it I realized how stupid that is and how much easier a `[ -f ~/.docker/config.json ] || return` in the prompt function would be. :joy:

In the end, my whole arch installation roughly looks like this, with the playbook files sitting on an nfs share:

* Partition the disk
* mount the partitions
* pacstrap the root partition including ansible
* chroot into the new root and run the playbook
* set my password
* setup the bootloader
* Profit!

```sh
$ fdisk (...)                                                   # partitioning
$ mount /dev/sdX /mnt                                           # mount the root
$ mount /dev/sdX /mnt/boot                                      #  and boot partitions
$ mount -t nfs server:/ansible-playbook /mnt/bootstrap          # mount nfs share for the playbook
$ pacstrap /mnt base base-devel linux linux-firmware ansible    # bootstrap root
$ arch-chroot /mnt                                              # chroot into new root
$ ansible-playbook /bootstrap/playbook.yml                      # run the playboo
$ passwd                                                        # set my passwd
$ exit                                                          # exit chroot
$ efibootmgr (...)                                              # setup bootloader using efistub
```

## What's left?

Discipline. The thing with ansible is, it automates things, but it doesn't prevent you from doing things aside the automation, which is known as configuration drift.
There are a couple of ideas to prevent this, like running the playbook regularly.
But you would still have to make sure that, for example, not only the wanted packages are installed but also *no* other package is present. The same is true for config files.
To *really* accomplish this, immutable systems like Fedora CoreOS exist.
I've tried this particular one, but for fiddling around in the homelab it felt unconfortable and unflexible having to reprovision the whole server for *every* config change I wanted to make.
For that, my approach is to be disciplined and do config changes only via the playbooks. I'm thinking of enforcing this by restricting the sudo capability of my personal user to maybe `systemctl` and `pacman`, or even completely revoke it. But I'm not sure how this will go yet :laughing:

But anyway - Next up: Dual boot!


# Updates:

Since writing this post I did further develop my playbook, so here are some useful updates:

### The Base

In the base setup, I changed the commands to generate the locales and to sync the clock so they don't run every time, but only if needed. This is how it looks now:
```yaml
- name: base set up | locale.gen de_DE
  tags: locale
  lineinfile:
    path: /etc/locale.gen
    line: "de_DE.UTF-8 UTF-8"
    regexp: "de_DE\\.UTF-8"
  # UPDATE: Notify a handler to generate the locales only if the locale.gen file was changed
  notify:
    - Generate locales
#(...)
- name: base set up | create time adjustment
  command:
    cmd: hwclock --systohc
    # UPDATE: The creates parameter tells ansible what the command does, so it's not executed when the file already exists
    creates: /etc/adjtime
```
```yaml
# roles/workstation/handlers/main.yml
# Handler to regenerate locales
- name: Generate locales
  command: locale-gen
```


[part-1]: {{<ref "itryarch/reproduction.md" >}}
[dotfiles]: {{<ref "itryarch/dotfiles.md#update" >}}
[kewlfft-aur]: https://github.com/kewlfft/ansible-aur
[p10k]: https://github.com/romkatv/powerlevel10k
