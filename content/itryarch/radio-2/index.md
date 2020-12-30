---
title: "Radio (Part 2)"
date: 2020-12-30T10:20:56+01:00
---

In the previous post, I setup `mpd` to play my favourite radio station in the background. Now, let's build a stream selector for it!

<!--more-->

Sunshine live offers a multitude of different streams for different genres, aside from it's main feed.
Altough I listen to the main feed (yes, I avoid writing "mainstream" on purpose :laughing:) 99% of the time, occasionally I do switch to another stream.
For that, I wanted to build a little "stream selector", and [wofi][wofi] in dmenu mode came in just perfect for that.

The different stream URLs are provided by a JSON API, so the first step is to get that data consumable with `jq`.
The JSON data structure is actually one top-level object instead of an array, which would be correct... *sigh*.
Anyways: It contains an object for each stream, with the "array index" as key.
Luckily, `jq` is awesome enough to unroll that pseudo array so we can pipe the individual elements into the next filter to extract the properties we need.
(The `-r` option is used to get the output without quotes)
```sh
$ curl --silent https://sunshinelive-stream-service.loverad.io/v1/live | jq -r '.[] | "\(.stream) \(.url_high)"'
```
Now we have a list of all available streams and their URL.
In dmenu mode, wofi takes a list via `STDIN` and prints the selected entry to `STDOUT`, so we can do something like this
(assuming that `get-streams.sh` writes the stream URLs on it's `STDOUT`, like the command above):
```sh
$ get-streams.sh | wofi --dmenu --prompt="sunshine live stream selector"
```

With some added pango markup in the list to make the URL transparent, and some markup-related flags for wofi, now we get something like this:

{{< figure src="stream-selector-1.png" alt="Screenshot" caption="Here it is in action 📻 🎵">}}

## Next level

The JSON API additionally provides a tile for each stream, which are used on the station's own stream selector on their website.
Natually, I decided to take it to the next level and also include the tiles in my selector.

### Get the images

Wofi can take base64 encoded images from `STDIN`, so my first thought was to do some jq/awk/magic to `curl | base64` the image and embed it directly.
That would however be terribly inefficient since it would take time to download all of them every time, and the menu wouldn't show up until *all* downloads complete.
Obviously, the images need to be cached.

As a first step, I produced a list of all image URLs with `jq` and piped it into `wget -N`. (`-N` adds timestamps to the downloaded files, so wget can check if it'd download the same when invoked again)
Unfortunately, the server apparently didn't support the `If-None-Match` header, so inspite `wget` wanting to only check all images were still transferred every time the script was invoked.
Therefore, I moved the file checking to the shell and only invoke wget if the needed image is not present in the cache directory.
To accomplish that, I pipe the list of URLs into `xargs`, which spawns a shell to `test -f || wget`, invoking wget only if the test fails.
In the end, this construct looks like this:
```sh
echo $streams | jq '.[] | .stream_logo' | (cd $LOGO_CACHE && xargs -n1 -I_file -- sh -c 'test -f `basename "_file"` || wget -qN "_file"' )
```
I use a subshell to wrap the image downloading, so I don't have to juggle with the working directory of the current context.
While developing the rest of the script I also threw in an occasional `sed` into the pipeline to change the query parameters of the image URLs.
The server renders the images in the size given in the query parameters, so this way I could easily get them smaller :smile:


### Building the list

So now that we have the images in the cache, we need to build the list for wofi to show.
Again I use jq's string interpolation to build the syntax wofi needs:
```sh
echo $streams | jq -r '.[] | "img-noscale:\(.stream_logo):text:\(.stream)"'
```
Again I threw in some `sed` to change the image URLs, and to replace the http path with the filesystem path of the cached images.

### The agony of choice

All that's left now is to pipe the list into wofi.
Despite my previous attempts, this time I configured it to print the selected line number to `STDOUT` instead of the whole line.
This way, I don't need to parse the URL out of the line, and also it saves me the headache of hiding the URL in the actual menu :joy:

On the other hand, it means that I need to `jq` again to get the URL of the selected stream, but that's a rather easy exercise now.
But: I need to increase the selection by one, because apparently at radio stations, arrays start at 1 :man-facepalming:.
Also, the stream URLs don't include the URL scheme, so that needs to be prefixed, too.
```sh
echo $streams | jq -r "\"https:\(.\"$(( $choice + 1 ))\".url_high)\"")
```
This looks a bit messy because of all them interpolations, but essentially it takes the property `url_high` of the chosen "array" index (remember, it's a pseudo array) and prefixes it with `http:`.

Now we have a complete URL we can pass to `mpd`:
```sh
$ mpc clear && mpd add $url && mpc play
```
And off we go! :musical_note: :radio:

## Start it up

To round things up, I put a little `.desktop` file in `~/.local/share/applications` to be able to run the selector from my main application launcher:
```
[Desktop Entry]

Type=Application
Name=Radio Sunshine Live
GenericName=Internetradio
Comment=Stream Selector for MPD
Exec=/home/jan/bin/radio-sunshine-live.sh
```

Now after all the hassle with poorly implemented JSON APIs, it was truly rewarding to take this screenshot:

{{< figure src="stream-selector-final.png" alt="Screenshot" caption="📻 🎵 🎧 🔊" >}}

[wofi]: https://hg.sr.ht/~scoopta/wofi
