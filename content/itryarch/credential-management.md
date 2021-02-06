---
title: "Credential Management"
date: 2020-11-07T21:14:08+01:00
---

This post will be mostly about a password manager, specifically about  [KeePassXC][keepassxc], which is just awesome.
But I'll be using it as a little bit more than that, which is why this post *isn't* titled "password manager" or even "KeePassXC".
<!--more-->

## KeePassXC installation
Simply install the package `keepassxc` from the Arch repos.
I also had to install `qt5-wayland` to and to `export QT_QPA_PLATFORM=wayland` to get Qt to work with wayland as a backend.

### Browser integration

On Windows I'm used to relying on the AutoType feature of KeePass for basically everything, but AutoType isn't available for KeePassXC under Wayland yet (see [#2281][keepassxc-2281]).
Most of the times one needs to enter a password is in the browser anyways (except for maybe SSH keys, but more on that later), so I thought I'd follow the recommendation of using the browser extension and see how far it can get me.

The basic installation, following the documentation, gave me already a functional setup without further configuration. Awesome 🎉

The only thing I had to change was
```
for_window [title="KeePassXC(.*)Browser"] floating enable
```
in the sway config to make the selection popup floating.

### Autorun

For the browser integration to work KeePassXC needs to be running in the background.
For now, I put these lines in my sway config to autostart KeePassXC with sway and put it on it's own workspace:
```
set $wskpxc KPXC
assign [title="^(.*)KeePassXC$"] $wskpxc
bindsym $mod+p workspace $wskpxc
exec keepassxc
```
However I might explore things like "minimize to tray" once sway actually has a tray as well as starting it with a proper systemd unit instead of just exec'ing it.

## SSH Key agent

KeePassXC can also feed your ssh keys to an ssh agent. To make use of that, I configured a systemd user service for the ssh agent itself, as described in the [Arch wiki][wiki-sshagent], and setup KeePassXC also as described in their [user guide][keepassxc-ug-ssh].
After that, you can add your keys saved in KeePassXC to the ssh agent, or you can choose (on a per-key basis) to automatically add them when unlocking the database and also removing them from the agent when the database gets locked. Again: Awesome!

Note: When using ECDSA keys, you may need to convert them to a new format so that KeePassXC can read them (see [#2450][keepassxc-ecdsa-key-bug]):
```
ssh-keygen -c -o -f ecdsa.key
```

## TOTP

KeePassXC can also generate TOTPs which are commonly used with 2FA logins.
Initially I was excited about that and planned to move my TOTP generation from Google Authenticator on my phone to KeePassXC and thus multiplatform.
On second thought though, I realized that having the TOTP secrets in the same database as the passwords would kind of defeat the idea of them being a second factor.
So I tossed that idea and kept Google Authenticator on my phone.

Speaking of phones: I do need a way to sync my KeePass database between my computer and my phone.
At the moment I use OneDrive for it's integration into Windows. My Arch system being a VM, I just mounted the Windows folder into it and thus have it synced.
But obviously I need to figure something out once I go dual boot, so stay tuned!

[keepassxc]: https://keepassxc.org/
[keepassxc-2281]: https://github.com/keepassxreboot/keepassxc/issues/2281
[keepassxc-ug-ssh]: https://keepassxc.org/docs/KeePassXC_UserGuide.html#_ssh_agent
[keepassxc-ecdsa-key-bug]: https://github.com/keepassxreboot/keepassxc/issues/2450
[wiki-sshagent]: https://wiki.archlinux.org/index.php/SSH_keys#ssh-agent
