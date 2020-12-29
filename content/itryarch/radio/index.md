---
title: "Radio"
date: 2020-12-29T19:20:56+01:00
---

Of course I need to listen to my favorite radio station while working, so I need something to play it in the background.

<!--more-->

## Summon the daemon

Instead of a media player floating around my desktop all the time, I wanted a solution which just plays music in the background.
For that, I chose the [Music Player Daemon][mpd] with it's classical client/server architecture.
While the daemon is running in the background playing music, I don't need a client to be active all the time, and I can control it from the command line with `mpc`.
Obious bonus point: There's a lot of different clients out there, and some of them have [ridiculous names](https://git.janouch.name/p/nncmpp/) :laughing:
So that nicely fullfills my requirements. Yeah!

To get it running, all I had to do was:
```sh
$ pacman -S mpd mpc
$ systemctl --user enable --now mpd
$ mpc add $STREAM_URL && mpc play
```
And: :notes: :radio: :tada:!

While the initial setup was pretty easy, I had to do quite some tweaking to get it working *nicely*.
Sound was playing well with the default config, however it didn't integrate with PulseAudio at all (which means it's streams weren't visible in `pavucontrol` et. al.)
Having no config, mpd defaults to autodetecting one soundcard, and apparently it connected itself directly via ALSA.
So I needed to put this little section into `~/.config/mpd/mpd.conf`:
```
audio_output {
    type        "pulse"
    name        "Pulse Audio"
}
```

The next thing that caught my attention was the socket, which is used for communication between mpd and it's clients.
By default, mpd listens on port 6600 on **all interfaces**.
That certainly makes sense if you want to use it over the network, however this is not something I typically want to do on a desktop.

There are two ways to change this, and they correlate with how mpd should be started.
Apart from changing the `bind_address` in the config file, there is also the option of using a socket managed by systemd, which brings the additional advantage of *socket activation*.
That means systemd will listen on the socket and only start mpd itself when someone actually tries to connect to the socket.
I really like this idea of on demand activation, so I went with it.
Consequently, I had to edit the unit file of the socket, to change where it binds, with `systemctl --user edit --full mpd.socket`, to look like this:
```
[Socket]
ListenStream=%t/mpd/socket
Backlog=5
KeepAlive=true
PassCredentials=true

[Install]
WantedBy=sockets.target
```
(I needed to do a full edit, as with a drop-in the Listen directive would be appended instead of replaced.)

Now with the daemon set, the clients need to know, too.
By default, `mpc` tries to connect to `localhost:6600`, unless otherwise told with the `--host` flag or the `MPD_HOST` environment variable.
So to set this, I added this line to `~/.pam_environment`:
```
MPD_HOST        DEFAULT="${XDG_RUNTIME_DIR}/mpd/socket"
```

And there we go :tada:

## Waybar module

To have some kind of visual feedback about the music playback, I enabled the mpd module for [waybar][waybar].
However, this interfered with the socket activation, as waybar would immediately try to connect to the mpd socket.
That, in turn, would trigger systemd to start mpd, so it would basically always be active and not only when I actually want it.
Unfortunately, there is no option for the mpd module to be enabled only when mpd is active, but a custom module can do that!

I quickly created a custom module using `mpc current` to display the current stream, and `systemd is-active` to determine if the module should be active.
This is the relevant snippet from `~/.config/waybar/config`:
```json
    "custom/radio": {
        "format": " {}",
        "exec": "mpc current",
        "exec-if": "systemctl --user --quiet is-active mpd",
        "on-click": "radio-sunshine-live.sh",
        "on-click-right": "systemctl --user --quiet stop mpd",
        "interval": 10
    }
```

This approach still has some annoyances, so I might have to reiterate on that.
But it's a good start.

{{< figure src="waybar-module.png" alt="Screenshot" caption="Here's how it looks">}}

Oh and in case you saw the script in the `on-click` action: Stay tuned!

[waybar]: https://github.com/Alexays/Waybar
[mpd]: https://www.musicpd.org/
