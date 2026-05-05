Spotty / Lyrion: metadata and “playing” UI, but no audio (Docker A/B: bridge vs host)

Audience: Michael Herger / Lyrion forums — stable Spotty only (not beta), for an apples-to-apples comparison.

Environment (2026-05)

  Server: Lyrion Music Server from Docker image lmscommunity/lyrionmusicserver:stable (Perl LMS 9.x).
  Host: Linux host “newsounds”, docker compose.
  Spotty plugin: 4.60.7 (install.xml in plugin cache).
  Helper binary: spotty-x86_64 reports spotty v2.0.9 — librespot 0.7.1 (build 2025-11-07).
  Players: PiCorePlayer / squeezelite (e.g. Office, MAC b8:27:eb:2c:c1:7a). Local library FLAC plays fine on the same players, so this is not a generic “dead player” path.
  EXTRA_ARGS: --advertiseaddr=<LAN IP> so SlimProto advertises on the correct interface.

Follow-up — production stance (still valid after the outage was traced to account class): Spotty PCM is intentionally disabled in LMS File Types (server.prefs disabledformats includes spt-pcm-*-*); we keep the FLAC row as the usual Spotty transcoding target. Re-enable PCM only if you deliberately want to test or run that branch.

Symptom

  Spotify browsing and metadata work.
  The UI shows something like “Ogg Vorbis (Spotify) (Converted to FLAC)” (or MP3 when that rule is selected); playback appears to start in the skin.
  There is no audible output. The SlimProto buffer stays empty: server.log shows e.g. “Buffering... 0 / 261120” (FLAC path) or “0 / 122880” (MP3 path), and Source::_readNextChunk reports “0 bytes of silence”.

Transcoding / LMS path (from server.log)

  Matched: spt->flc (when FLAC is enabled for Spotty) or spt->mp3 — stock-style pipelines, e.g.
    spotty-x86_64 … -c <cache>/<account> … --single-track <spotify URI> … | flac -cs …
    or … | lame -r …
  Song::open shows a coherent tokenized command. We do not see “While creating conversion pipeline” / ENOENT once the usual Docker-side issues are fixed (lame available at the path LMS expects, Song.pm using Pipeline for pipe commands, TranscodingHelper not appending a broken “ & |” after already-piped commands).

  So on the LMS side, the rule matches and the pipeline is created; the failure is no meaningful audio bytes reaching the player buffer.

Spotify / librespot sanity (same machine, same container)

  HTTPS to spclient.wg.spotify.com / apresolve.spotify.com returns 2xx — basic egress is OK.
  Manual CLI (same spotty arguments plus “| lame” or “| flac”) for a failing URI produces output far below normal music bitrate over tens of seconds (e.g. ~417 bytes MP3 in 45 s, ~8 kB FLAC in 35 s on one sample) — a starved trickle, not a healthy stream. That points more at upstream librespot / Spotify behaviour (cf. GitHub Spotty-Plugin #199, librespot “audio key” discussions) than at “wrong File Types row.”

Docker networking A/B

  Default: bridge with published ports 9000, 9090, 3483, 1900 (and UDP where mapped).
  Trial: network_mode: host for the LMS container only, --advertiseaddr unchanged, no published ports.

  Result: identical symptom — same Matched: spt->… lines, same buffer 0 / …, still no audio. Host networking did not fix this failure mode for us; bridge vs host showed the same stuck buffering, so NAT port mapping alone is an unlikely explanation.

Auth / UI caveats

  Spotty Advanced can show dirty / need Apply even when only viewing; Apply after sign-in or preferences may not persist otherwise.
  After deleting and re-adding an account, confirm Apply and that something like /config/cache/spotty/<account>/credentials.json exists before trusting playback tests.

Separate note on “beta”: the old additional-repository URL https://www.herger.net/slim-plugins/spotty-test.xml now returns 404; only http://www.herger.net/slim-plugins/repo.xml (Spotty 4.60.7 via downloads.nixda.ch) responded in our checks.

Questions / ask

  Does this pattern match a known librespot / account-class / “audio key” issue on 4.60.x with librespot 0.7.x?
  Is there a current pre-release or test build location (the old spotty-test.xml feed is gone), or should we attach server.log excerpts (getConvertCommand2 / Tokenized command / _buffering) and spotty -V / plugin version lines?

We can attach log excerpts on request; a prepared excerpt file documents Matched / Tokenized / Buffering / silence lines for one failing Spotify track.

Prepared for paste into forums.lyrion.org. Hostnames and paths can be generalized further if needed.
