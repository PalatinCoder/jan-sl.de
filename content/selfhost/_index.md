---
title: "Self Hosting"
---

Just how much services can an Atom C3558 hold? Let's find out!
{ .subtitle }

{{< figure src="lack-rack.jpg" class="is-pulled-right" alt="Lack Rack" >}}

The core of my homelab is an Intel Atom C3558 on a Supermicro A2SDi-4C-HLN4F with 32GB of finest registered ECC RAM.
It lives inside an Inter-Tech 2U-2404S which is a 2U 19" format case that I put in a Lack Rack under my desk, accompanied by my Fritz!Box 7530, a TL-SG1016DE and a patch panel.

On the server, I run some useful services for me, but I'm also hosting some public facing services on some VPSes.
The posts in this section will be mostly about how I setup my infrastructure in my (home)lab to run these services.

I'm running ~~FreeNAS~~ TrueNAS on the bare metal and some Linux VMs on top of that.
I tought it'd be wise to give TrueNAS direct access to the disks, however over time this decision showed some drawbacks:
Running `bhyve` of all hypervisors turned out to be not the most common and thus documented and battle-tested option :sweat_smile:
But there are no problems, only challenges :muscle:

Or so I thought.
Over time, I had enough challenges and decided to [turn it inside out]({{< ref "selfhost/inside-out.md" >}}) :laughing:
{ .is-clearfix }

