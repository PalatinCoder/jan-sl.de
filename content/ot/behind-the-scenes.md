---
title: "Behind the Scenes"
date: 2020-10-19T21:23:38+02:00
---

Just as sudden as I felt the need of trying out Arch, I somehow felt the need to start a blog about my adventure.
I've thought about redoing my personal homepage for some time anyways (which I do like every few years), so why don't combine these two thougts.

<!--more-->

For the blog I wanted to use a static site generator, as I just didn't feel the need to use a fully fledged CMS.
There are approximately a quadrazillion SSGs out there in the universe, but the first one which came to my mind was [Hugo][1] so I just went with it.
Also it claims to be the absolute fastest one out there, so that sounds neat.

I'll update this post as I develop my workflow. For the full code, check out the [GitHub Repo][2].

## Running Hugo

While developing and writing the posts, I keep Hugo's embedded server running in the background. However, I don't just put it in the background by `hugo server &`.
To have the logs available but don't randomly splatter all over my terminal, I run it thorugh `systemd-cat` to have the output available in the journal.

Why don't redirect the output to `/dev/null`? Because I wouldn't see the output anymore.

Why not redirect it to a file? Well, I would have that file floating around somewhere in my filesystem.
Actually, there's nothing wrong with that, but why don't exploit systemd if we have it?

```
systemd-cat -t hugo hugo server -D &
```

And to check out the logs:
```
journalctl -et hugo
```

## Building the theme

The previous version of my homepage was written using Pug.js and Sass, to minimize typing effort.
However, I wrote it completely from scratch, using no frameworks whatsoever.
That was a good approach because I could tailor the css and markup to perfectly fit my idea, but it also felt like I was writing a lot of boilerplate code.

So obviously I was pretty hyped that hugo does support compiling Sass into CSS out of the box (that is, if you have the extended build, which my Arch package does).
But I didn't want to just copy all of the old code over. So this time around, I chose [Bulma](https://bulma.io) as a CSS framework as it is lightweight, easy to use and unopinionated about the markup (which is good *and* bad at the same time).

With the help of Bulma, I could flesh out the structure of my page very quickly, with own CSS only required for the special components like the parallax headers and the revealing footer. But also for these components most of the work is accomplished by Bluma and I just need to throw some CSS classes in my markup. Neat :thumbs_up:

The problems started to form when the scaffolding of the site was finished and now the content needed to be styled. As I said, Bulma is unopinionated about the markup, so everything is done with CSS classes.
A `<h1>` for example doesn't look any different than a `<span>`, until some classes are assigned. This is no problem when writing HTML directly, but as I'm writing the posts in markdown I mostly end up with simple HTML, without any classes assigned.
(To be fair: I couldn't find any decent framework which works on semantic HTML, they all rely on classes)
Here, I would've liked Bulma to provide some proper extension points or make it's modules available as mixins, so I could for example make every paragraph behave as it would have the class `column` assigned.

The probably best solution to this is hugo shortcodes. I created a handful of them to wrap some markdown content in the appropriate HTML elements with the Bulma classes assigned to them.

Another solution are hugo's render hooks.
I created one for links to add `target="_blank"` and `rel="noopener"` to links if their target is external (which is best practice, so I think it's no coincidence that exactly this is an example in the hugo documentation).
Also I created a hook for headings to assign bluma's `title` class.
That is, until I found out about bulma's `content` element.
It adds sensible styling to the semantic HTML elements beneath it, so that's exactly what I needed to wrap my markdown content in! Awesome! :tada:

## The Brick Wall

You may have noticed the so-called [masonry layout][css-tricks:masonry] in the [showcase][showcase] section of the homepage.
I actually struggled pretty long until I got it right, as there are so many ways to do it in CSS and none of them is perfect (and I *really* didn't want to use the JS library).
What helped me in the end was [this](https://tobiasahlin.com/blog/masonry-with-css/) blog post showing how to make a masonry with flexbox _and_ have the items ordered horizontally, which is the big problem usually.
I wanted to have the items appear in the order they are coded on mobile screens, where there is only one column. But on bigger screens with two columns, they would have to be ordered differently, so the `order` attribute combined with `nth-child` was the ideal solution to my problem.

To implement it I used bulma's multiline columns and added some flexbox modifier classes to have the `flex-direction` set to `column` insted of `row` and have decent spacing between the items.
From there, I only had to add the `nth-child` magic and the height for the element (which I carefully trialed and errored to get pixel perfect :see_no_evil:):

```sass
.masonry
  +tablet
    height: 2700px
  +desktop
    height: 2350px
  div
    &:nth-child(odd)
      order: 1
    &:nth-child(even)
      order: 2
```

[1]: https://gohugo.io
[2]: https://github.com/PalatinCoder/jan-sl.de
[css-tricks:masonry]: https://css-tricks.com/piecing-together-approaches-for-a-css-masonry-layout/
[showcase]: {{< ref "/_index.md#showcase" >}}
