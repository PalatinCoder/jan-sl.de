---
title: "The Dots"
date: 2021-02-07T11:12:48+01:00
---

As opposed to the system-level configuration, which I describe in [configuration management], the dotfiles are all my user-level configuration.
To reproduce my setup on a newly configured machine, I have to transfer all my configuration (i.e. dotfiles) to it, so I need a clean way to manage them.
<!--more-->
Most software is kind enough to respect the [XDG Base Directory specification][wiki-xdgbasedir] and thus puts it's configuration in `$XDG_CONFIG_HOME`, which defaults to `$HOME/.config`.
I manage my `.config` directory as a git repository. While not being the ideal solution for dotfile management, it was sufficient enough for me to start.

However, not every software respects the specification but "pollutes" the home directory instead.
Awesome as the Arch wiki is, it has a [list][wiki-xdgbasedir-list] of applications and how well they support XDG Base Directory, as well as workarounds if it's only partially supported.

In my case, these candidates are Vim and zsh. There are some more files and directories like `.gitconfig`, `~/.docker` and  `~/.ssh`, however I'm fine with these as they contain environment specific configuration like my ssh host aliases, and I don't need them under version control and certainly don't want them in my public dotfiles repo.

### Vim

For a moment I thought about using Neovim for it's built-in XDG Base Directory support, but the Arch wiki lists this awesome [blog][vim-xdg] which offers a complete solution to make vim respect it as well.
It basically boils down to setting all of vim's paths (runtimepath, packpath, viewdir, backupdir, undodir, etc) to their respective locations in your XDG dirs.
In addition to that, I had to adjust the directory in vim-plug's initialization, like so:
```vim
call plug#begin($XDG_DATA_HOME.'/vim/plugged')
```
To make vim pick up the file in the new location I set `$VIMINIT` to something like `source ~/.config/vim/vimrc` via `pam_env`, so it's always set.

### Zsh

Basically the same is true for zsh. I moved the dotfiles to `$XDG_CONFIG_HOME/zsh` and set `$ZDOTDIR` accordingly, also via `pam_env`.
Additionally, I moved the history file to `$XDG_DATA_HOME` by setting `$HISTFILE`.
At this point, all dotfiles were nicely stowed in their directory, however the `.zcompdump` file was bugging me. On startup, zsh compiles it's completions for better performance and dumps them as a script into this file.
That seems not like a file to put under version control, does it? More like it belongs into a place like `$XDG_CACHE_HOME`, I think.
And it happens that I'm not the only one who thinks this, as there's already a [PR][ohmyzsh#9090] open for `oh-my-zsh` (in my particular case the creation of the file was due to the oh-my-zsh framework, others might do it differently).

During my research, I also stumbled across this little snippet, which keeps wget from putting its hsts file in my home directory.
```sh
alias wget="wget --hsts-file=${XDG_CACHE_HOME:-$HOME/.cache}/wget-hsts"
```
And also basically the same for less:
```sh
LESSHISTFILE=${XDG_CACHE_HOME:-$HOME/.cache}/lesshist
```

So with all that, I (nearly) have a nice, uncluttered home directory, and even more important, I can transfer my config directory to a new machine and instantly get my setup. Awesome :tada:

### (Won't?) Fix

Unfortunately there are also apps which have their config file and user data location hardcoded and no workaround is available.
In my case, at the time of writing this, these are `.mozilla` and `.ansible`.
While the former has a 17 year old [bugreport][ff-bugreport] and even a recent [work-in-progress][ff-wip], the latter only has [stubborn][ansible-1] [developers][ansible-2].
Altough I can life with that, I find it a real shame that a project as awesome as ansible blocks adopting a commonly accepted standard with such flimsy arguments.

## Update: The environment is changing {#update}

Just recently I discovered that *linux-pam* has [deprecated reading the user environment][pam-env] (that is the `~/.pam_environment` file), so I (or basically everyone) need another way to set aforementioned environment variables.
Currently people are discussing multiple strategies, but "the best" solution hasn't emerged yet.
I'm a fan of using systemd's `environment.d`, but that only is applied to systemd user services. There is, however, [systemd#7641][systemd#7641] which discusses making them visible for login sessions.

For the time being, I stuck to using the `.zshenv` file to set `$ZDOTDIR` so `.zshrc` get's picked up, and then set everything else from there.

### Update to the update {#update2}

While refactoring my [session startup][session-startup], I needed a different solution to this, since, using a display manager, the window manager was no longer started through the shell.
Due to that, I moved everything from `.zshrc` into `environment.d` and use the [systemd-environment-d-generator(8)](https://www.freedesktop.org/software/systemd/man/systemd-environment-d-generator.html) to import them into the shell and the window manager session.


[configuration management]: {{<ref "itryarch/reproduction.md" >}}
[wiki-xdgbasedir]: https://wiki.archlinux.org/index.php/XDG_Base_Directory
[wiki-xdgbasedir-list]: https://wiki.archlinux.org/index.php/XDG_Base_Directory#Support
[vim-xdg]: https://blog.joren.ga/tools/vim-xdg
[ohmyzsh#9090]: https://github.com/ohmyzsh/ohmyzsh/issues/9090
[ff-bugreport]: https://bugzil.la/259356
[ff-wip]: https://phabricator.services.mozilla.com/D6995
[ansible-1]: https://github.com/ansible/ansible/issues/52354
[ansible-2]: https://github.com/ansible/ansible/issues/68587
[pam-env]: https://github.com/linux-pam/linux-pam/commit/ecd526743a27157c5210b0ce9867c43a2fa27784
[systemd#7641]: https://github.com/systemd/systemd/issues/7641
[session-startup]: {{< ref "itryarch/session-startup.md" >}}
