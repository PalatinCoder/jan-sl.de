---
title: "Screenshots"
date: 2020-10-18T22:12:58+02:00
description: "When you're ricing, you need to take screenshots. Here's how I replicated an awesome windows tool's features."
---

When you're ricing, you need to take screenshots to show off your rice, obviously, and it's pretty handy in many other situations, too.
On Windows, I use [ShareX][1], mainly for its awesome postprocessing features and the simple region selection.
It has many other features and you can define pretty complex workflows with it, but screenshotting and annotating are my main use cases which I need to replicate in my Arch setup.

## The holy trinity

*The* tool to take screenshots on Wayland seems to be [grim], which can be used together with [slurp] to select a region of the screen.
For annotating, someone on reddit recommended [swappy].

So these are the tools, now stitch them together!

Spoiler: This is the monstrosity I ended up binding to the Print key:

```
swaymsg -t get_tree | jq -r '.. | select(.pid? and .visible?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"' | slurp -o | grim -g - - | swappy -f - -o $(xdg-user-dir PICTURES)/Screenshots/$(date +%Y-%m-%d-%H%M%S).png
```

Let's break that down.

The last one in the chain obviously is the postprocessing with `swappy`.
In general, it reads an input image, lets you edit it, and then saves it to some output.
As it's the last one in the chain in this case, it reads its input from `STDIN`, which is indicated by the `-f -` flag.
The output is then saved as a png file in the screenshots folder using `xdg-user-dir`, as indicated by the `-o` flag.

As an input to `swappy` we need a png, so the actual captured image of the screen. Providing that to `STDOUT` is `grim`'s task.
But what should `grim` capture? Luckily it does accept coordinates and the size of the region from `STDIN`, when told to do so with `-g -`.

Good. So all we have to do now is select the region.

At first, I came up with a rather circumstantial solution.
I had googled and found different command chains for capturing the active output (i.e. workspace), the active window, a selected region, etc.
So what I came up with is using the Print key to set `sway` into a custom mode `screenshot`. In this mode, I would then have individual keys mapped to the various functions.
There would be `s` for *screen*, which uses `grim -o` to capture a complete wayland output and some `$(swaymsg ...)` to determine what the current output is.
The same would go for `w` as in *window*, but using `grim -g` to select a region output by some more `$(swaymsg | jq)` magic.
Last but not least, I would have `r` as in region, which would start `slurp` to select a region and pipe the coordinates into `grim -g`.

This sounds pretty neat, doesn't it? Well, let's make it easier.

It took me a few reads of the `slurp` README and man page to discover that you can not only interactively select a region, but also select a predefined one.
Adding `-o` to the `slurp` command adds all currently active wayland outputs to the it's list of regions, so that would allow me to select an entire screen.
All that's left now is selecting a window, which is accomplished by feeding a list of coordinates to `slurp` via `STDIN`. The list is produced by retrieving sway's tree with `swaymsg` and some `jq` magic to extract the coordinates and size of the visible windows. (TBH I copied that from the readmes).

So there you have it. Flexible screenshots with annotations one keypress away. Nice. 🎉

[1]: https://getsharex.com
[grim]: https://github.com/emersion/grim
[slurp]: https://github.com/emersion/slurp
[swappy]: https://github.com/jtheoof/swappy
