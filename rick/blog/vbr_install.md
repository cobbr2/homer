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

3/12/23
