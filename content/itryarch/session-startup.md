---
title: "Session Startup"
date: 2021-12-09T14:37:42+01:00
---

At first I used a simple shell script to startup my sway session after login, since sway was the only window manager I used. However, over time, I installed some other ones so the startup process needs to get more confortable. Oh and there's one more annoyance to fix.

<!--more-->

# Status quo

So currently, I use the defaults of `login(8)` and `agetty(8)` to log me in and a simple script to startup sway if I'm on `tty1` which basically looks like this:
```sh
# Start sway on login on tty1
if [ "$(tty)" = "/dev/tty1" ]; then
	# various wayland enables
	export MOZ_ENABLE_WAYLAND=1
	export QT_QPA_PLATFORM=wayland
	exec systemd-cat --identifier=sway sway
fi
```
In order to choose between  multiple window managers I replaced the `if` with a `switch case`, so it would start different wms on different ttys, but that's not really elegant, is it?
Also, the default `login(8)` isn't really esthetically pleasing.

# Display Manager

Naturally, I need to use a display manager to improve this situation.
And to avoid pulling in half of Gnome, KDE or some other desktop environment, I decided to use [greetd] (for being lightweight and flexible) in combination with [tuigreet] (for the lulz - aswell as not having to spin up a whole compositor).
Thanks to the AUR, I could just install the packages and enable the systemd service for `greetd`.
Unfortunately, at the time I'm writing this, tuigreet suffers from a [bug][tuigreet#44] which basically sends one of it's threads into a spin loop.
That in turn makes my fans go brrrrr - so for the moment I pinned it to the previous version until the [patch][tuigreet#46] gets merged.

Configuration of `greetd` ant `tuigreet` is pretty much per their respective instructions.
But, as the sessions are not started from the shell anymore, I need another place to set all the required environment variables (which I previously did in `.zlogin`).
For that, I quick and dirty hacked a small script with a lot of `exports` and a `switch case` to run whatever of the predefined sessions it's told with an argument:
```sh
#!/bin/sh
# file: /usr/local/bin/wayland-session-startup.sh

# Firefox
export MOZ_ENABLE_WAYLAND=1
# GTK
export CLUTTER_BACKEND=wayland
# QT
export QT_QPA_PLATFORM=wayland-egl
export QT_WAYLAND_FORCE_DPI=physical
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
# SDL
export SDL_VIDEODRIVER=wayland
# Java
export _JAVA_AWT_WM_NONREPARENTING=1

# XKB Keyboard Layout (in case it's needed)
export XKB_DEFAULT_LAYOUT="de(nodeadkeys)"

case "$1" in
    "sway")
        exec systemd-cat --identifier=sway sway
        ;;
    "river")
        export WLR_NO_HARDWARE_CURSORS=1
        exec systemd-cat --identifier=river river
        ;;
    "newm")
        export XDG_SESSION_TYPE=wayland
        export XDG_SESSION_DESKTOP=wlroots
        export XDG_CURRENT_DESKTOP=wlroots
        export XDG_CURRENT_SESSION=wlroots
        exec systemd-cat --identifier=newm python -u -c "from newm import run; run()"
        ;;
esac
```

So far, so good. But there is something else:

# Multihead (again)

The problem with using the console to login is that it's not *really* aware of multi-monitor setups and how to handle them, at least not automatically.
But since my laptop lives under my desk while docked, having the greeter show up there is impractical.
When I first setup Arch on my physical machine, I already [discovered][realdeal#multihead] the `fbcon=map` kernel parameter.
But I can't really set this permanently in my kernel commandline, since it depends if my laptop is docked or not wheter I want the VT1 on framebuffer 0 or 1 (where `fb1` wouldn't even be there while undocked).

To remap this during runtime, there is a little utility from the Debian maintainers called `con2fbmap`, which is [packaged for Arch][aur#con2fbmap] as well.
With this, I can just type `con2fbmap 1 1` to map the console number 1 to framebuffer number 1. That's not the ultimate solution however, since I would need to login first to type a command.
Instead, I'd rather have the command executed automatically when there is a second framebuffer, i.e. the laptop is docked.

As it turns out, `udev` can indeed trigger systemd units when devices are added or removed.
So first, let's define a simple systemd service to remap consoles 1 and 2 (in case I need a console to recover a broken desktop or something)
```service
[Unit]
Description=Remap virtual terminals 1 and 2 to framebuffer 1

[Service]
Type=oneshot
ExecStart=/usr/bin/con2fbmap 1 1
ExecStart=/usr/bin/con2fbmap 2 1
```

Now, with the help of [this awesome article][linux#systemd+udev], let's setup a udev rule to trigger it.
```
ACTION=="add", SUBSYSTEM=="graphics", KERNEL=="fb1", TAG+="systemd", ENV{SYSTEMD_WANTS}="con2fb-remap.service"
```
What this does is basically, whenn a second framebuffer gets added to the system, it tells systemd that this device wants the `con2fb-remap.service` to be activated, so systemd goes ahead and fires the commands I defined previously.

By the way I changed some kernel parameters according to the [wiki][wiki#silent] to achieve a silent boot, now directly into my greeter and also on my main display. Awesome! :tada:

**Small update**: After using this for a couple of days, I noticed that some kind of "hot plug" support would be nice, so I added `ExecStop` directives to reset the mapping to fb0 and `StopWhenUnneeded=yes` to the `[Unit]` section.
This should, in theory, execute the stop commands when the framebuffer device is unplugged (since the udev rule established a dependency from the device to the service, the service is no longer needed when the devices isn't there anymore).
But only in theory, since the hotplug of the framebuffer device doesn't work at all (manually stopping the service does, however).
I'll just leave it for the moment but might revisit another time.

## Bigger update: Environment and Systemd integration

To have a better integration between the session and the systemd user session, I did some changes after the initial setup.
As I described in a [previous post][changing-env], I was looking for a single place to configure environment variables and have them available in the desktop session as well as all terminals.
Having the window manager started from a shell session, the shell rc was that place, and during startup of the window manager a quick call to `systemctl --user import-environment` made the variables available to the user services.
Using a display manager however, that became scattered and also I wanted to keep the startup script nice and small.
So to achieve that single point of configuration again, I moved all the variables from the startup script and the shell rc into different \*.conf files in systemd's `environment.d`.
Then, to have them available, the block in the startup script changed to this simple call:
```sh
# Import environment variables from systemd user manager
export $(/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator)
```
With the same call in the beginning of `.zshrc`, in case I run a shell without having started the desktop environment yet.

Now with the environment set, the startup of the window manager(s) also needs some work.
Fristly, to have autorun apps find the window manager the `WAYLAND_DISPLAY` variable needs to be available (which is set by the window manager), so it needs to be imported in to the systemd environment by calling `systemctl --user import-environment WAYLAND_DISPLAY` towards the end of the wm's initialization.

Secondly, to have all the background services like `swaybg`, `waybar` etc. started, I created a `systemd.target` for the session which pulls in all required services, like this (e.g. for my [river][github/river-wm] session):
```systemd
[Unit]
Description=river wm session
Documentation=man:systemd.special(7)
BindsTo=graphical-session.target
BindsTo=river.scope
After=river.scope
After=graphical-session-pre.target
Wants=graphical-session-pre.target
Wants=xdg-desktop-autostart.target
Wants=kanshi@river.service
Wants=waybar@river.service
Wants=swaybg.service
Wants=swayidle@river.service
```
There are a few things to discuss here:
On the one hand, notice how some of the services are *instanciated services* (e.g. `kanshi@river.service`).
This allows me to have the same service start with different config files for different wm sessions (e.g. `kanshi@sway.service`).
On the other hand, notice the `BindsTo=river.scope` directive.
I changed the invocation in the startup script to use `systemd-run(1)` to create a transient systemd unit.
This way, the user service manager can track the window manager and the target can be stopped when I exit the wm. This allows for a clean stop of the session.
The whole invocation in the startup script now looks like this:
```sh
exec systemd-cat --identifier="$1" systemd-run --user --scope --unit="$1" "$1"
```

Finally, I have to startup the `*-session.target` when the window manager starts to have systemd fire up all the services.
This is done for example by a simple `systemctl --user start river-session.target` in the init script.
In a perfect ~world~window manager, I would have an exit hook to call `systemctl --user stop river-session.target` to have a perfectly ordered shutdown, but the dependency between the `target` and the `scope` is sufficient.

[greetd]: https://git.sr.ht/~kennylevinsen/greetd
[tuigreet]: https://github.com/apognu/tuigreet
[tuigreet#44]: https://github.com/apognu/tuigreet/issues/44
[tuigreet#46]: https://github.com/apognu/tuigreet/pull/46
[realdeal#multihead]: {{< ref "itryarch/the-real-deal.md#multihead-virtual-console" >}}
[aur#con2fbmap]: https://aur.archlinux.org/packages/con2fbmap/
[linux#systemd+udev]: https://www.linux.com/training-tutorials/systemd-services-reacting-change/
[wiki#silent]: https://wiki.archlinux.org/title/Silent_boot
[changing-env]: {{< ref "itryarch/dotfiles.md#update" >}}
[github/river-wm]: https://github.com/riverwm/river
