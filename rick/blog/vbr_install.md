Fixed 1. Straight Ubuntu server install sets up docker so only root
   can use it.
  * Advice at https://docs.docker.com/engine/install/linux-postinstall/ is OK as far as it goes,
    but I found I had to reboot to get the docker permissions right; even once I found `snap restart docker`, it wasn't enough.

Fixed 1. Straight defaults for Ubuntu put all my disk space on `/boot` it looks like; will likely have to do
   some volume management to clean that up.

OK 1. Biggest deal: no players are discovered. OTOH, players see it, and I can swap over, so not a dealkiller

Fixed 1. LMS has a random hostname

Fixed 1. yar (ripper) is ripping to Music rather than Music/flac

OK 1. yar may be using classic abcde which will make MusicBrainz useless according to https://antzucaro.com/posts/2020/cddb-woes/ try a really common CD
   Not a problem. Found Green Day.

1. Music directory is owned wackily; playlists & state by unregistered user 819, mirror directories by root, but ripped dir by user.

1. Probably do want to run Picard on the collection to push a bunch of obscure Surf CDs back to MusicBrainz or somebody. Should
   search for Insect Surfers on all freedb/gnudb , musicbrainz, and gracenote and figure out what's the best bang for my minutes.

Done 1. Fork VBR for your changes, or at least build a branch of your stuff. Check Github for what others have done.

Not repeatable 1. Lots of buffering on KQED following morning, even when down to just Kitchen / Office / Living Room.  Scheduling problems?

1. Login time is slow.

Done 1. Toss cloudinit and microk8s

1. Interestingly, had volume control (though volumes were different) on new LMS

Plans:

Done 1. Reconfigure yar for our location & naming convention (on branch! Yay!)

Done 1. Set up so we have room for music. Seems wrong to be on /boot. 
   * Followed https://packetpushers.net/ubuntu-extend-your-default-lvm-space/ to expand / to the full size of the drive (though probably should keep some out for snapshots); OTOH, maybe use spare disk for that?
   * Early observation that boot was too big is wrong; only 2GB there.

Done 1. Remove overhead daemons (cloudinit, microk8s, whatever else looks dumb)
   * snap uninstalled cloud & microk8s

1. Move project management to Trello? Stymied by atlassian merger; cobbr2@yahoo.com account won't reattach. Fkem.

1. Fixing ownerships:
    Symptoms:
	* yar: Seems to be OK: it's ripping as `rec` (user 1000)
	* flacmirror: using root
		* Tried adding USER 1000:1000 to the docker-compose.yml file for that.
	* LMS install: using 819
		* Tried adding USER 1000:1000 to the docker-compose.yml file for that.
    setting USER in compose.yml did nothing useful 
	mirror directories still ended up root-owned
	no flac dir created
    manually created flac dir as `rec`
    chowned format subdirs of Music as rec:rec
    disabled squeezelite for now in .yml since nobody:nobody is another problem
    
1. flac_mirror doesn't have any enabled formats, even though there's a setting in compose.yml
OK 1. Ripper actually resumed even though I'd stopped rip after 2 songs and restarted docker-compose. Nice!
1. LMS starts really late in the compose; ripper had already ripped a couple tracks.
Done 1. hostname: worked for lms
Done 1. Still ripped to Music instead of Music/flac
Done 1. didn't eject disk after rip

===== docker-compose build && docker-compose up =====
1. Ripped to Music/flac with new format.  OTOH (for unknown CD):
```
-rw-r--r-- 1 root root 4879265 Jun 11 21:43 '1 - TRACKFILE}.flac'
```
1. flac_mirror still bitching. Disabled until rip & lms work.
1. ejected after rip.  LMS immediately scanned.
1. Apparently the _FILE macros use under_case formatting. Am I more interested in consistency or convenience? Might like under_case
1. Got the TRACKFILE}.flac problem again. Hmph. Easy syntax issue in conf file.
1. Set up your homer dirs for Linux; missing git stuff is annoying. Also: can't push to GH.
1. TZ and maybe time is off.
1. Fixed unkn/unkn
===== docker-compose build && docker-compose up =====
1. unkn/unkn needs fix
1. Still ripping as root. Interesting error is: ripper_1  | post_encode processing files in /out/flac/Unknown_Artist/Unknown_Album
ripper_1  | useradd: invalid user name '1000'
ripper_1  | groupadd: '1000' is not a valid group name
	not sure what's in abcde.conf and what's in dc.yml
===== docker-compose build && docker-compose up =====
1. unkn/unkn?
  => lots of bugs getting that to work, bad dev cycle gotta get into better habits about those.
1. uid/gid thing looks like bug in postencode, gave it strings and maybe it'll work
===== docker-compose build && docker-compose up =====
1. Installed cifs-utils so I could send what I've ripped to sounds to actually work on for yoyo.
1. also pkg updates keep asking me to reboot. Probably shood soon.
1. uid/gid for ripper: FIXED, kind of: album created right, tracks right, artist root
1. cd ids have spaces. Who knew?

19 Jun
------
Started adding in the flac_mirror.
1. mirror format must be capitalized
2. now building mp3/flac/...; should just be mp3/...
   Problem: "flac_dir" in mirror.py is "/flac/flac" in current mounting; don't know why.
   Also now can't create in /mp3 itself, because the mkdir ran again.
   => Mounting problem. Remapped.
3. Mirrors now. OTOH, *wow* it's going to be a lot of statting on the FS.  IIRC, vbox
   used rsync to help optimize that.
   Probably can remove python "-u" flag, but it really didn't seem to be logging until
   I put that in.
4. I suspect interrupting during ffmpeg will not remove file, but will check.
   => I hate it when I'm right.

26 Aug
------
Somewhere in there I got Avahi to come up; had to *not* mount the volume.

Now trying to get both Avahi & Samba to work; I've had Samba show the volumes once but on only the IP address...
and I've had Avahi show the server, but not been able to see or mount volumes.

Before starting the work tonight, did a docker top but didn't capture output.

Changed the SAMBA_SERVER name in hopes I was colliding w/ `sounds`.

Wanted clean start so I ran `docker-compose up --build samba`... not sure if process is up or not...
`docker top vbr_samba_1` shows running processes:

```
rec@newsounds:~$ docker top vbr_samba_1
UID                 PID                 PPID                C                   STIME               TTY                 TIME                CMD
root                3340859             3340838             0                   03:49               ?                   00:00:00            runsvdir -P /container/config/runit
root                3340925             3340859             0                   03:49               ?                   00:00:00            runsv samba
root                3340926             3340859             0                   03:49               ?                   00:00:00            runsv avahi
root                3340927             3340925             0                   03:49               ?                   00:00:01            smbd --foreground
86                  3340928             3340926             0                   03:49               ?                   00:00:00            avahi-daemon: running [newsounds.local]
86                  3340930             3340928             0                   03:49               ?                   00:00:00            avahi-daemon: chroot helper
root                3340937             3340927             0                   03:49               ?                   00:00:00            smbd --foreground
root                3340938             3340927             0                   03:49               ?                   00:00:00            smbd --foreground
root                3340939             3340927             0                   03:49               ?                   00:00:00            /usr/lib/samba/samba-bgqd --ready-signal-fd=45 --parent-watch-fd=12 --debuglevel=4 -F
```
I don't think that `bgqd` was there before.

but no change; Finder sees "newsounds", but can't connect. Nothing seems to log on connect.

## So try a separate docker-compose

Shouldn't be any interaction in a multi-service config, but suppose there could be...

don't get initial logging once I'm @ level 4, must need to do something different w/ DC to see those.

no change... well, I'm now getting a brief "Loading..." dialog in osx

Was forcing to a non-existent group, tried creating it in the containner to no avail...
removed force and restarted. Same result ("loading..." before Connection Failed)

Could it be wsdd? 

## Current situation:

```
rec@newsounds:~$ docker top samba_samba_1
UID                 PID                 PPID                C                   STIME               TTY                 TIME                CMD
root                3346286             3346266             0                   04:13               ?                   00:00:00            runsvdir -P /container/config/runit
root                3346344             3346286             0                   04:13               ?                   00:00:00            runsv samba
root                3346345             3346286             0                   04:13               ?                   00:00:00            runsv avahi
root                3346346             3346286             0                   04:13               ?                   00:00:00            runsv wsdd2
86                  3346347             3346345             0                   04:13               ?                   00:00:00            avahi-daemon: running [newsounds.local]
root                3346348             3346346             0                   04:13               ?                   00:00:00            /usr/sbin/wsdd2
root                3346349             3346344             0                   04:13               ?                   00:00:00            smbd --foreground
86                  3346352             3346347             0                   04:13               ?                   00:00:00            avahi-daemon: chroot helper
root                3346361             3346349             0                   04:13               ?                   00:00:00            smbd --foreground
root                3346362             3346349             0                   04:13               ?                   00:00:00            smbd --foreground
root                3346368             3346349             0                   04:13               ?                   00:00:00            /usr/lib/samba/samba-bgqd --ready-signal-fd=45 --parent-watch-fd=12 --debuglevel=2 -F
```

Comppletely flumoxed. SMB config at /etc/samba/smb.conf looks as intended, no force...

Restarting MAC on thought that somehow it's got state wrong... wacky, I know.

# Lost notes on NFS

# 5 Mar 2023

At some point back in September I got NFS up in a docker-compose way.  OTOH, I failed
to get to the point where I could tag music from my Mac.  Trying to get back to
the point where I can mount & write at all from the Mac.

To mount on Sounds, I used:

	sudo mount -t nfs4 -w newsounds:/ /mnt

Mounting on Mac:

	sudo mount -o vers=4 -t nfs 192.168.222.6:/ testNewSounds

Can create files, but they're empty. OTOH, can append to files. Weird. Presumed it
was permissions, but even w/ umask 000 can't write to the files I create:

```
Ricks-MacBook-Air:_TestDir rick$ umask 000
Ricks-MacBook-Air:_TestDir rick$ echo "something from Mac umask 000" >_umask_000_from_Mac
Ricks-MacBook-Air:_TestDir rick$ cat _umask_000_from_Mac 
Ricks-MacBook-Air:_TestDir rick$ ls -l _umask_000_from_Mac 
-rw-rw-rw-  1 rick  staff  0 Mar  5 18:02 _umask_000_from_Mac
```

Append is flakey, but works if the file is new'ed on the server and empty:

Full Scenario:

On newsounds:
```
rec@newsounds:~/Music/_TestDir$ > _append_another
rec@newsounds:~/Music/_TestDir$ chmod a+w _append_another
```

On macbook:
```
Ricks-MacBook-Air:_TestDir rick$ ls -l
total 40
-rw-rw-rw-  1 rick  staff   0 Sep 11 12:13 Bar
-rw-rw-rw-  1 1000  1000    0 Mar  5 18:08 _append_another
-rw-rw-rw-  1 1000  1000   20 Mar  5 17:58 _append_to_this
-rw-rw-rw-  1 rick  staff   8 Mar  5 18:01 _send_something_from_mac
-rw-rw-rw-  1 rick  staff   0 Mar  5 18:02 _umask_000_from_Mac
-rw-rw-rw-  1 rick  staff  25 Sep 11 12:17 _wackamole
-rw-r--r--  1 rick  staff   0 Mar  5 17:56 _written-from-rickMac-to-newSounds
-rw-rw-r--  1 1003  1004   11 Mar  5 17:42 _written_from_sounds_to_newsounds
-rw-rw-r--  1 1000  1000    8 Mar  5 17:40 _written_on_newsounds
Ricks-MacBook-Air:_TestDir rick$ echo "writting something from Mac" >>_append_another
Ricks-MacBook-Air:_TestDir rick$ ls -l _append_another
-rw-rw-rw-  1 1000  1000  28 Mar  5 18:09 _append_another
Ricks-MacBook-Air:_TestDir rick$ cat _append_another
writting something from Mac
Ricks-MacBook-Air:_TestDir rick$ echo "and  here's another line" >>_append_another
Ricks-MacBook-Air:_TestDir rick$ cat _append_another
writting something from Mac
Ricks-MacBook-Air:_TestDir rick$ 
```

From Finder, was able to create a test directory *and* copy a file from Desktop to it.

So let's see if I can retag a file, that's the goal anyway...

Using TagEditor

1. Had to reauthenticate with Apple ID
2. Chmod'ed the Unknown/Unknown (first) directory to 777 / 666
3. Opened in TagEditor
4. Entered a bunch of stuff for the first cd of what appears to be the 2-CD Tom Jones Surrounded By Time (I only listened to a bit of the first song on album 580b4e07) 
5. Hit Save.

First song name changed (matched convention I put in, but it doesn't match my normal conventions; need to remove '_' separator).

Five minutes later: first file's name is changed, but no others. Mac / TagEditor has been stuck in "Preparing for saving..." since I hit Save.

NFS docker container logs -- nothing new since booted

### Examining NFS

```
The SYNC environment variable is unset or null, defaulting to 'async' mode.
Writes will not be immediately written to disk.
```

Wonder if that's the append issue? /etc/exports shows:

> /nfsshare *(rw,fsid=0,async,no_subtree_check,no_auth_nlm,insecure,no_root_squash)

21.4% of CPU is going to nfsd

# 3/11/23

~10:30 AM
* Was able to attach and play for a few minutes
* Stopped

Diagnosis:
* Could not restart docker containers (permission denied in /var/lib/docker, all of which is owned by root)
* Could not `docker ps` (same reason)
* Rebooted the whole box

Other events:
* Power had been off to the machine earlier in the week (5 days earlier or so)
* Had just reconnected ethernet before attaching

After reboot (at least a minute)
	* Pings OK
	* ssh taking even longer than usual
	* power light is on.
	* did eventually (minutes?) finish ssh handshake
	* no change in bahavior


As root:
* Still can't docker ps (permission denied on process 2746)

Decided to reinstall docker, but didn't look to see how it was installed first.
* Installed from docker web site (via apt repository)
* `docker-compose` didn't start working, but `docker` and `docker compose` did.
* Discovered the previous installation was via "snap"
* Disabled and uninstalled snap version while waiting for VBR to download its layers and start
* Eventually started, including flac mirror, and played KQED
* Couldn't stop individual container (flac-mirror) via docker compose stop; stopped via docker stop <full name>
* It's `flac_mirror`, misspelled.

* Had a hard mount when restarting docker, locked up laptop. Hard mounts suck

# 12/28/23

* Note: several power off / on cycles since last worked with newsounds
* Got BamBoom player to hook up

Back to file systems:

* Still trying NFS...
* Used
```
        sudo mount -o vers=4 -t nfs 192.168.222.6:/ testNewSounds
```
From Mac:
* Can create files
* Can't put any data in them
* Can't append anything via `>>`.
    * Not even if the file was created empty & 0666 on NewSounds
* Successfully copied a file from Mac to a directory created from the Mac.  Slow (lots of initialization time).
* Opened a (zero-length) file created on the Mac in TextEdit, edited. Could not save.  Just "The document could not be autosaved"
    * When quitting out, also got "The document "..." is on a volume that does not support permannet version storage"

First hail-mary: update NFS image
* Tried to just umount the volume from Finder, but even though I got mys hells out of the directory, Finder reports that Terminal still has filesystem open.
* Also reported by umount. Killed Terminal
* Looked for new image. `itsthenetwork/...` has not been updated in 5 years, so:
    a. it must work for whoever uses it
    b. let's try somebody else's.
* Decided to try `erichough` which is clearly very closely related.  OTOH: 4 years old too.
    a. both are based on `sjiveson/...`
    b. a lot of this is redone in OpenEBS, but I didn't want to go all K8s today.
* Got an install, turned on rw, insecure, etc... (see ~rick/nfs), finally got it to mount...
    a. hung on `echo > _newFile`
    b. created the ifle, but wrote nothing.
    c. even though debug logging is enabled, nfs server logged nothing.

# 12/29/23: Not VBR today: Bamboom

Goal: Get Rotary encoder to do something useful

* Configured to use newsounds (192.168.222.6:9000) and enable telnet ("y")
* No sign that the rotary encoder is doing anything
* LMS does not see the device?  It logs, but doesn't show in browser?!
* LMS page render is very slow
* Bamboom logs a problem with socket close every five/ten seconds

Shut down useless NFS server

* still can't see the player, though server logs some discovery:
```
[23-12-28 04:21:19.8789] Plugins::SqueezeESP32::Player::init (108) SqueezeESP player connected: 8c:ce:4e:b6:b9:fc
[23-12-28 04:21:19.9049] Plugins::SqueezeESP32::Player::playerSettingsFrame (183) Setting player 128x32 for BamBoom
[23-12-28 04:21:56.3866] Plugins::SqueezeESP32::Player::playerSettingsFrame (183) Setting player 128x32 for BamBoom
[23-12-28 04:33:13.0529] Plugins::SqueezeESP32::Player::init (108) SqueezeESP player connected: 8c:ce:4e:b6:b9:fc
[23-12-28 04:33:13.8179] Plugins::SqueezeESP32::Player::playerSettingsFrame (183) Setting player 128x32 for BamBoom
[23-12-29 00:52:01.4932] main::init (377) Starting Logitech Media Server (v8.3.1, 1676361197, Fri 17 Feb 2023 06:37:09 AM CET) perl 5.028001 - x86_64-linux-gnu-thread-multi
```

* Restarted LMS using `docker restart <container>`
* see restart logged, nothing else...
* enabled a ton of debug flags on LMS. Applied, did not see restart requirement popup...
* saw some Jive 'GotGLFRequest" stuff logged, but w/mac 12:34:56:78:12:34 (harumph)
* restarted LMS... and bamboom... no change, nothing logged @LMS.  Conclusion: even though I can connect from sounds via curl on both 9090 & 9000, getting conn problem from bamboom...
* check connectivity from another player by swapping music source for workshop
    * no sound from workshop
    * nothing logged @ LMS
    * did show the workshop player @ LMS
    * very slow response time, though i finally got volume turned down after a few minutes via phone
* gave up on the server for a minute, thought I'd try to just see the buttons on the telnet session
* turned off player, performance of LMS became acceptable. Nothing extra logged @ LMS,though.
* turned on player, watched telnet (have to remember to reconnect!)
* Got Rotary Button 1 pressed when rotated left
* Checked LMS performance: swapping to KQED took a long time... checked KCSM & back, definitely slow.  Adding this player, mo matter that nothing is logged, slows the server way down
* Also: *no display* now that rotary is defined?!
    * after power cycle, display is up.  Hooked up vDC measurement, which is showing total oddity... took a long time to grow to -13.7?
* Probed all the J6 outputs.  AFAICT, I had them mapped backwards.
    * After rewiring, telnet now shows "Button Press" events like:
```
I (142637) buttons: Rotary push-button 1
I (233547) buttons: Rotary push-button 0
I (233897) buttons: Rotary push-button 1
```
    * OTOH: both left right, and knobpush all seem to generate the same strings.
* Played around with getting LMS logging on newsounds to tell me something new about what's going on, didn't get anything.
    * Discovered that once  aminute there's a "Jive" probe on the Discovery logging, whether anything's connected to that server or not.
    * Each of those samples look like:
```
[23-12-30 04:49:21.3464] Slim::Networking::Discovery::gotTLVRequest (217) sending response
[23-12-30 04:49:21.3502] Slim::Networking::Discovery::gotTLVRequest (217) sending response
[23-12-30 04:49:21.9994] Slim::Networking::Discovery::gotTLVRequest (217) sending response
[23-12-30 04:49:39.0570] Slim::Networking::Discovery::__ANON__ (125) Jive: 12:34:56:78:12:34
[23-12-30 04:49:39.0597] Slim::Networking::Discovery::gotTLVRequest (217) sending response
[23-12-30 04:49:39.0673] Slim::Networking::Discovery::__ANON__ (125) Jive: 12:34:56:78:12:34
[23-12-30 04:49:39.0707] Slim::Networking::Discovery::gotTLVRequest (217) sending response
[23-12-30 04:49:48.0057] Slim::Networking::Discovery::gotTLVRequest (217) sending response
[23-12-30 04:49:48.0092] Slim::Networking::Discovery::gotTLVRequest (217) sending response
[23-12-30 04:49:48.0131] Slim::Networking::Discovery::Server::gotTLVResponse (197) discovery response packet:
[23-12-30 04:49:48.0165] Slim::Networking::Discovery::Server::gotTLVResponse (197) discovery response packet:
```
* Removed server string from Bamboom & restarted; got a fine registration with Sounds
    * Rotary actions (in addition to above) get:
```
[00:04:19.889] cli_send_cmd:209 cannot send CLI 8c:ce:4e:b6:b9:fc button knob_push
```
    * Plays fine.
    * `telnet sounds 9090` gets a "Connection closed by foreign host", so I suspect sounds isn't set up for cli (good thing to turn off if not using, but the button intepreter on SqueezeESP32 wants to use it)

# 12/30/23

Not my brightest day, I guess... after reading a bunch of stuff, I
found the lmscommunity Docker image for LMS.  That didn't like the
files built by the other container (because I had things mounted
*in the container* in `/mnt/...`), so I ended up building a whole
new server. Of course, that means changing all the flags & plugins
again.

One win is that the new directory map used in the container doesn't
have the `/mnt` thing, so it's about as clean as it can get given that
LMS uses fullpaths everywhere.

# 12/31/23

Second win: the new server display data on bamboom!

Bamboom rotary debug is confusing.
1. No matter what I do with the switch, I get random Rotary push-button results.
2. I don't seem to get knob_button events
3. I can remove the GPIO 18 & 19 wires entirely and get the same results
4. Adding + power makes no change
5. GPIO 18/19 don't work at all (unless SW GPIO5 is connected, but once it is, they don't matter)
6. Kind of finding it hard to believe that I'm getting cross-talk to GPIOs that aren't connected.
7. Figure I either don't have the right rotary encoders, or I'm completely misunderstanding, so will ask questions

Moving on to trying a button (on 4 first, then 21, using config from README but replacing 5 w/ 21):

Goal:
```
buttons: [{"gpio":4,"type":"BUTTON_LOW","pull":true,"long_press":1000,"normal":{"pressed":"ACTRLS_VOLDOWN"},"longpress":{"pressed":"buttons_remap"}},
 {"gpio":5,"type":"BUTTON_LOW","pull":true,"shifter_gpio":4,"normal":{"pressed":"ACTRLS_VOLUP"}, "shifted":{"pressed":"ACTRLS_TOGGLE"}}]

buttons_remap: [{"gpio":4,"type":"BUTTON_LOW","pull":true,"long_press":1000,"normal":{"pressed":"BCTRLS_DOWN"},"longpress":{"pressed":"buttons"}},
 {"gpio":5,"type":"BUTTON_LOW","pull":true,"shifter_gpio":4,"normal":{"pressed":"BCTRLS_UP"}}]
```

Start: just a voldown button:
buttons: [{"gpio":4,"type":"BUTTON_LOW","pull":true}]
actrls_config: "buttons"

Concern: I think my switch is momentary contact, so long-press won't make sense at the least....

Configured, wired switch to ground & what should be 4, and got... nuthin'.

Enough for a day with football & fireworks.

Oh: and while it thinks it's bamboom, newsounds thinks it's SqueezeESP32

# 2024/01/06

## Rotary control hardware setup solved!

After reading Philippe's reply to my plaintive wtf? on the forum, I added some
Dupont connectors to the ends of the black octopus cable, then plugged the whole
set in at once so the mapping couldn't be confused. I also directly wired to the 
part of the breadboard the rotary was on, instead of bridging.  That immediately
worked, though the DT / CLK assignment was backwards so the knob worked backwards.

## Changed name from SqueezeESP32 on newsounds

Don't know if it took. Never have had to do that with other players, so I
think there's still something odd about the upgraded server. Player automatically
connects to `sounds` on startup (haven't tied it back to newsounds since that
didn't work last week).

## On to buttons

I also learned how those arduino momentary contact switches work: they are SPDT, but
the short-distance (not the bridgeable distance) is the switching direction.

ACTRLS_TOGGLE is the pause/play button; don't use ACTRLS_PAUSE. Still have
to decide what buttons we really want.

Haven't decided which of the rotary configurations I like yet.  I've
set up for "volume,longpress" at the moment, but it didn't look
like LEFT worked the way I expected it to (it probably did *work*,
it's just not intuitive, will keep rereading). I wonder; I think
my intuition comes from the Transporter, and that had a separate
BACK button (which might have been left), so perhaps I want the longpress
mode to be UP, RIGHT, SELECT, which might not be a choice I have.

Definitely don't understand what the ACTRL / BCTRL distinction is.

Added config file to github.


=========== SAMBA ============= 2024-03-22

After all the frustration with samba in a container, I decided to just
go ahead and install it straight on newsounds.  Annoying as hell.

I hope this also helps learn something about discovery / UDP / UPNP / whatever
the squeezebox protocol stuff...Net::UDAP is. I've come to suspect that my docker
install doesn't allow some form of multi/broadcast to reach my containers, even
though I'm using host containers.

Following very old instructions at https://ubuntu.com/tutorials/install-and-configure-samba#2-installing-samba

Saved terminal session at `/Users/rick/Documents/ubuntu_samba_install.txt`

Note: I had to type:
```
ufw allow samba
```
as part of those instructions.  I think that was probably the magic I always needed.  And there's probably one of those for the squeeze protocol... fuzzball.

UDAP searches come up with an LG protocol from the 2010s, so not the protocol we need.

--

Configuring Spotty:
* Didn't see the LMS from my phone or web (apparently need mac app at least)
* Disabled `ufw` completely
* Had to re-enter password (had to recreate it, too)
* Once I did, I got an admin screen I don't remember seeing before, so that's nice. 
    * Configured just office & kitchen first.
* Still can't see the devices.  https://github.com/michaelherger/Spotty-Plugin makes me think it's either port 4070 outbound or 5353/UDP, but I already disabled `ufw`....
* Kind of odd that the server scan results now identifies spotify albums & such.

2024-03-23
* Set up youtube plugin; since not in host, I went ahead and install ed
```
sudo apt-get install libio-socket-ssl-perl libnet-ssleay-perl
```
but I'll probably have to install them into the container, too?
Proactively checked by running apt-get update and apt-get install in the vbr-lms-1 container; if that helps, will need to build a proper image & push it (to dockerhub?) for recovery

No: already installed; this ain't the problem.

* OK, so restart the server and see if it  works...
* No.
* Added new secret to credential
* Tried resetting all the fieldds
* Don't see anything logged at console after startup log problems.
* Restart from app doesn't log to docker logs either, though, so maybe logging somehow goes to server.log?
* Disabled the plugin that would go to squeeze net for unknown functions, since that was shut off on 19 Mar
* Logs ain't going to server.log either, AFAICT; bringing thos eup in the app shows same last line....

* When I hit "Get Code", the app responds with "Changes have been saved."  I don't get prompted for authorization.
* Tried Firefox. Same result.
* Definitely see 403s in the log. Also see that it's still showing the first search I entered, rather than "recent" which should be the current search
* Still get errors about "api/sounds/v1" & "Sounds & Effects menu"

* Created new API application & credentials.  Got it to finally prompt with an access code, but my *app hasn't passed google review*, which means I probably picked wrong when I said "external" vs. "internal" application.

===== Server (sounds, newsounds) Checklist:

[x] Can directly connect to server from players 
[x] Automatic rip works and rescans 
[x] Can retag music 
[x] Spotify works 
[ ] Youtube works 
[ ] Samba share name makes sense (s/sambashare/music/g)
[ ] Backup & restore works and can handle OS upgrade (Now complicated by native Samba install)
[ ] Music library synced *to* newsounds
[ ] Music library syncs *from* newsounds to sounds as backup device
[ ] Can discover from random players
[ ] Retagging causes re-mp3 creation
[ ] MP3 sync works without affecting music players
[ ] Can swap between sounds & newsounds (will this require sounds LMS upgrade?)
[ ] Bandcamp downloads automatically make it into the library
[ ] Names of everything make sense
[ ] Passwords are secured (google password manager) but usable
[ ] Music Library view in SqueezeCommander shows just the flac dir
[ ] No duplicates in newsounds inventory based on compression type
[ ] Newsounds on near-tip LMS revision 
[ ] Sounds upgraded to sensible OS
[ ] Finance & project directories on sounds are secured
