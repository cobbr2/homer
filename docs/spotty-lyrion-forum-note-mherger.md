# Spotty / Lyrion — playback silent (metadata OK), Docker bridge vs host — forum note

**Audience:** Michael Herger / Lyrion forums — Spotty + Docker troubleshooting.

## Environment

- **Server:** `newsounds`, Docker Compose stack under **`~/VBR`** (`docker-compose.yml`).
- **Image:** `lmscommunity/lyrionmusicserver:stable` (Lyrion 9.x).
- **Spotty:** **4.60.7** (`install.xml` in plugin cache).
- **Helper:** `spotty-x86_64` reports **v2.0.9**, **librespot 0.7.1** (`spotty --help` / `-V`).
- **Players tested:** PiCorePlayer **Office** MAC `b8:27:eb:2c:c1:7a` (out of sync group for isolation). Local library FLAC playback works.

## Symptom

- Spotify via Spotty: **metadata and UI look normal** (“Ogg Vorbis (Spotify) (Converted to FLAC)” or MP3 when selected).
- **No audible audio.** LMS shows **playing / buffering** in the UI.
- **`server.log`:** **`Slim::Player::Player::_buffering`** stays **`Buffering... 0 / …`** (e.g. **`0 / 261120`** for FLAC), and **`Slim::Player::Source::_readNextChunk`** logs **`Sending 0 bytes of silence`** — **no decoded audio bytes** reaching the player buffer.

## Transcoding / LMS path (not the old Spotty UI row order bug)

- **`getConvertCommand2`:** **`Matched: spt->flc`** (or **`spt->mp3`** when MP3 row wins).
- **Tokenized command** is the stock **`spotty … | flac …`** or **`spotty … | lame …`** pipeline (Spotty cache path **`/config/cache/spotty/<account-hash>/`**).
- After local fixes (see below), **`Song::open`** does **not** fail with **`While creating conversion pipeline`** for these pipelines.

### Root causes we ruled out (Docker / LMS packaging)

1. **`lame` not under LMS `Bin` path** — image has **`/usr/bin/lame`** but LMS resolves **`[lame]`** to **`/lms/Bin/x86_64-linux/lame`**. **Fix:** bind-mount a small wrapper script at **`/lms/Bin/x86_64-linux/lame`** that **`exec /usr/bin/lame "$@"`** (documented in **`~/VBR/patches/lms/`**).

2. **`TranscodingHelper.pm`** appending **` & |`** to **every** tokenized command when **`$noPipe`** is unset — breaks **already-piped** commands (`spotty | …`) into garbage like **`… & |`**. **Fix:** only append when the command **does not** already contain **`|`** (`tokenizeConvertCommand2` guard).

3. **`Song.pm`** using **`FileHandle->new`** for **multi-stage** shell pipelines when **`$sock`** is unset (**streamMode R**) — **`ENOENT`** / broken pipeline. **Fix:** set **`$usepipe`** when **`$transcoder->{'command'} =~ /\|/`** on Linux so **`Slim::Player::Pipeline`** (**IPC::Open2**) runs **`spotty | flac|lame`**.

Patches live under **`~/VBR/patches/lms/`** with bind mounts in Compose; **`PROVENANCE.txt`** describes rebasing on upgrade.

## Docker networking A/B

- **Bridge + published ports** (`9000`, `9090`, `3483`, `1900`) + **`EXTRA_ARGS=--advertiseaddr=192.168.222.6`** — **same** silent buffering.
- **`network_mode: host`** for **`lms` only** (removed **`ports:`** per Docker rules) + **same `EXTRA_ARGS`** — **same** silent buffering.

**Conclusion for report:** failure is **not** explained by bridge NAT / published ports alone in this setup; host mode **did not** restore audio.

## Spotty auth / UI

- User had to **Apply** Spotty settings; missing **Apply** looked “signed in” but did not persist.
- **`/config/cache/spotty/<hash>/credentials.json`** present after real sign-in.
- **No** custom Spotify Client ID in UI.

## CLI sanity check (same container user as LMS)

For the same **`spotify://track/…`** URI and cache dir:

- **`spotty | lame`:** only **~417 bytes** MP3 in **45s** (essentially no real stream).
- **`spotty | flac`:** **~8k bytes** FLAC in **35s** — still **far** below normal music bitrate; aligns with **librespot not delivering sustained decoded audio**, not “FLAC row wrong.”

**`server.log`** did **not** show **`audio key` / `librespot` / `decryption`** strings (those often go to **spotty stderr**, not LMS log).

## Ask / next steps (for mherger)

1. Does this match known **librespot / Spotify account / family / audio key** issues (cf. GitHub **Spotty-Plugin #199**, librespot issues)?
2. Recommended **Spotty beta** vs stable retest procedure when metadata works but **pipeline outputs a trickle**.
3. Whether **`spotty -v`** stderr captured during **`--single-track`** should be attached.

---

*Generated from troubleshooting session; Docker Compose reverted to bridge mode after host-network A/B unless noted otherwise in repo.*
