# Forum / mherger note: Spotty playback — metadata OK, no audio (Lyrion in Docker)

Paste or adapt for [Lyrion forums](https://forums.lyrion.org/) (3rd-party / Spotty) or a direct message to **Michael Herger** if that’s the project norm.

---

## Environment

- **Lyrion Music Server:** community image `lmscommunity/lyrionmusicserver:stable` (9.x) in **Docker** on a Linux host (**newsounds**).
- **Spotty:** **4.60.7** (from `install.xml` in the container).
- **Helper binary:** e.g. `spotty v2.0.9` / **librespot 0.7.1** (from `spotty --help` / `-V` in the container).
- **Players:** **PiCorePlayer** / SqueezeAMP (e.g. **Office** MAC `b8:27:eb:2c:c1:7a`), plus other players; **local library playback works** (rules out a completely dead player path).
- **UI:** Default skin. **Spotify Connect phone → LMS** is out of scope (Spotty documents Connect limitations).

## Symptom

- Browsing **Spotty** / metadata / artwork works.
- Starting playback shows **Ogg Vorbis (Spotify)**-style metadata and a **transcoded** type in the UI (e.g. **Converted to FLAC** or **Converted to MP3**), and the skin can look like it is “playing,” but there is **no audible output** on Squeeze players.
- **SlimProto / HTTP stream:** buffer stays **empty** (e.g. `Buffering... 0 / 261120` for FLAC, or `0 / 122880` for MP3) and **0 bytes of silence** in `Source::_readNextChunk` in `server.log`.

## What we ruled out (on this system)

1. **Missing `lame` in LMS `Bin` path**  
   The image may not ship `/lms/Bin/x86_64-linux/lame` even though `/usr/bin/lame` exists. A **host bind** of a small wrapper at `/lms/Bin/x86_64-linux/lame` was used so **File Types → MP3 (lame)** can resolve `[lame]`.

2. **Broken shell pipeline tokenization for `spotty | …`**  
   Stock **Lyrion** `TranscodingHelper.pm` appends ` & |` when `$noPipe` is unset; for commands that **already contain** `|`, the tokenized line could end with garbage (e.g. `… & |`), breaking transcoding. **Local patch:** only append that suffix when the command **does not** already contain `|`.  
   **Also:** **`Song.pm`** must use **`Slim::Player::Pipeline` (IPC::Open2)** for **multi-stage** transcodes (`spotty | lame`, `spotify | flac`), not **`FileHandle->new`** alone — otherwise **`ENOENT` / “While creating conversion pipeline”** can occur when `$sock` is unset for **remote** streams.

3. **File Types ordering**  
   Spotty’s rules list **PCM before FLAC before MP3** in `custom-convert.conf`. With **FLAC disabled** but **PCM enabled**, LMS could match **PCM** before ever considering **MP3**. **Disabling the PCM row** was required so **`spt->mp3`** could win when testing MP3.

4. **Docker bridge vs `network_mode: host`**  
   For **identical** `EXTRA_ARGS=--advertiseaddr=<LAN IP>` and the same Spotty account/cache: **`network_mode: host`** vs **published ports** produced the **same** stuck buffering / silence. So this failure mode is **not** explained by “bridge NAT only” on this host.

## What the logs show when it “should” play

- **`Matched: spt->flc`** (or **`spt->mp3`**) and a **sensible `Tokenized command:`** (`spotty … | …/flac` or `… | …/lame`), **without** the old **`& |`** tail.
- **No** recurring **`Song::open (614)`** once **`Song.pm` + `lame` + `TranscodingHelper`** fixes are in place — the pipeline **object** is created.
- Problem remains **no bytes** moving into the player buffer → points **above** SlimProto as “no decoded audio from the transcoder chain,” not “wrong codec row only.”

## CLI sanity check (same container, same credentials dir)

For a **known `spotify://track:…` URI**, a shell pipeline such as **`spotty … | flac …`** can yield **some** FLAC bytes, while **`spotty … | lame …`** may yield only a **tiny** MP3 output over **tens of seconds** — far below normal music throughput. That matches **librespot / Spotify audio path** trouble more than “LMS HTTP server broken.”

Spotify / forum/GitHub threads (e.g. **Spotty-Plugin #199**, **librespot audio key / Family account** symptoms) describe **metadata OK, decryption/audio key errors, no real playback** — **`server.log` may not show librespot stderr** unless **`spotty -v`** output is captured separately.

## Ask / next steps we’d like from maintainers

- Whether **Spotty beta** (`spotty-test.xml`) is the preferred next step when **stable** shows this pattern **without** useful **`spotty` stderr** in **`server.log`**.
- Any **known** **librespot 0.7.x + Spotify** regressions vs **Family / multi-account** flows worth naming explicitly.
- Confirmation whether **disabling volume normalisation** at the **Spotty helper** level (if exposed) is still recommended when debugging **CPU / pipeline starvation** (UI may not expose it; LMS still injects **`--enable-volume-normalisation`** when that pref is on).

## Repro bundle to attach

- **`server.log`** snippets around **`Matched: spt->`**, **`Tokenized command:`**, **`Player::_buffering`**, **`Source::_readNextChunk`** for one failing track.
- **Spotty + Lyrion versions**, **Docker** baseline (**bridge** vs **host** result identical here).
- **`spotty -V`** / **`spotty --help`** header from the plugin **Bin** dir.

---

*Generated from troubleshooting session; paths like `/home/rec/VBR` on **newsounds** hold optional LMS patch bind-mounts — revert or rebase on image upgrade.*
