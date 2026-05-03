# Lyrion Music Server (LMS) – Docker persistence and image plan

## Versions

- **Current (newsounds):** LMS **8.1.1** via `justifiably/logitechmediaserver`.
- **After migration:** Lyrion Music Server **9.x** via `lmscommunity/lyrionmusicserver` (e.g. `:stable` = 9.1.1). When we move to Lyrion we’ll be on 9; the plan below includes testing for what’s going to change in that upgrade.

---

## Findings from newsounds (VBR stack)

Inspected the live host via SSH. Current setup:

- **Image in use:** `justifiably/logitechmediaserver` (old/custom; not the community image).
- **Compose file:** `~/VBR/docker-compose.yml` uses **`/home/${USER}/Music`** and **`/home/${USER}/Music/state`** for LMS.
- **LMS container paths:** This image uses **`/mnt/music`**, **`/mnt/playlists`**, **`/mnt/state`** (not `/config`). State on the host is correctly at `/home/rec/Music/state` with `prefs/`, `cache/` (library.db, cache.db, etc.), and `prefs/plugin/` (plugin configs).
- **Root cause of “losing state”:** Compose expands **`${USER}` at runtime**. If `docker compose up` is run as **root** (e.g. after reboot via systemd, cron, or `sudo`), then `USER=root` and the stack mounts **`/home/root/Music`** and **`/home/root/Music/state`**. That state directory is **empty** (or missing), so LMS starts with default/empty state (two favorites, old/empty DB). When you run compose again as **rec**, it mounts `/home/rec/Music` and you see the correct state again—until the next time something runs compose as root.
- **Confirmed:** With `USER=root`, `docker compose config` shows `source: /home/root/Music/state` and `source: /home/root/Music/flac`, etc. So any “compose as root” scenario explains the symptom.

**Immediate fix (no image change):** Use **explicit paths** so the same directories are used regardless of who runs compose. For example, replace `/home/${USER}/Music` with `/home/rec/Music` in the compose file, or use a `.env` with `LMS_USER=rec` and `Music=/home/rec/Music` and reference `$Music` in the compose (compose expands `.env`). Then ensure any script or service that runs `docker compose up` does not override `USER` (or use the same explicit paths / `.env`).

**Plugin config:** On this image, plugin data lives under the same state mount: `.../state/prefs/plugin/` and `.../state/cache/DownloadedPlugins`, `InstalledPlugins`. So fixing the state mount (so it’s always `/home/rec/Music/state`) also preserves plugin configuration.

---

## Current image (Docker Hub) – recommended

- **Use:** `lmscommunity/lyrionmusicserver`
- **Do not use:** `lmscommunity/logitechmediaserver` — archived; “Legacy - don't use. Use lyrionmusicserver instead.”
- **Tags:** `latest` (v9.1.0), `stable` (v9.1.1), `dev` (v9.2.0). Prefer `stable` or a pinned tag for production.

Source: [Docker Hub – lmscommunity/lyrionmusicserver](https://hub.docker.com/r/lmscommunity/lyrionmusicserver), [GitHub – LMS-Community/slimserver-platforms Docker README](https://github.com/LMS-Community/slimserver-platforms/blob/master/Docker/README.md).

---

## Why “some” state is lost (favorites, old DB, possibly plugins)

All of the following live under **one** directory in the container: **`/config`**.

| What gets lost              | Where it lives in the container | Notes |
|----------------------------|----------------------------------|-------|
| Favorites                  | `/config` (prefs)               | Part of server prefs. |
| Music library DB / cache   | `/config` (e.g. cache, DB files) | Scan results, metadata. |
| Plugin installs & config   | `/config/cache/Plugins`          | Installed plugins and their settings. |

If `/config` is not a **single persistent** host path or named volume (or is wrong/empty), each `docker-compose up` can start with a fresh or old `/config`, so you see:

- Favorites back to a default (e.g. two entries).
- Music DB “back in time” (old or empty cache).
- Plugin configuration missing or reset.

So: **fix persistence for `/config` and you fix favorites, DB, and plugin config together.**

---

## Recommended volume layout (from Hub + GitHub)

- **`/config`** → **rw** → **One persistent host path or named volume.**  
  Must be the same every time you run compose. This preserves prefs, cache (music DB), and `cache/Plugins` (plugins + plugin config).
- **`/music`** → **ro** → Your music library path (host path or volume).  
  If this path differs between runs, LMS can “see” a different library and the DB can look “old” or wrong.
- **`/playlist`** → **rw** → Persistent path for playlists (host path or named volume).

Optional but recommended:

- **`/etc/localtime`** and **`/etc/timezone`** (ro) so server time is correct (or use `TZ=...` if you can’t bind those).
- **Ports:** 9000 (HTTP), 9090 (CLI) — map 1:1 (e.g. `9000:9000`, `9090:9090`). Other ports require `HTTP_PORT` (and CLI port set in LMS UI).
- **PUID/PGID** if you need consistent file ownership on the host (e.g. `1000:1000`).
- **hostname** so the server name is stable (e.g. `newsounds`).
- **restart: always** (or equivalent) so the container comes back after reboot.

---

## Example docker-compose (minimal, persistent)

```yaml
services:
  lms:
    image: lmscommunity/lyrionmusicserver:stable
    container_name: lms
    hostname: newsounds   # or your preferred name
    volumes:
      - /path/on/host/lyrion-config:/config:rw
      - /path/on/host/music:/music:ro
      - /path/on/host/playlists:/playlist:rw
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
    ports:
      - 9000:9000/tcp
      - 9090:9090/tcp
      - 3483:3483/tcp
      - 3483:3483/udp
    environment:
      - PUID=1000
      - PGID=1000
      # - TZ=America/Los_Angeles   # if you can't bind /etc/timezone
      # - EXTRA_ARGS=--advertiseaddr=192.168.222.6   # if players need server IP
    restart: always
```

Replace `/path/on/host/lyrion-config`, `/path/on/host/music`, and `/path/on/host/playlists` with real paths that **do not change** between `docker-compose up` runs. Using a **named volume** for `config` is OK as long as the same stack always uses that volume (e.g. `lyrion_config:/config:rw`).

---

## Checklist to fix and to avoid losing plugin config

1. **Switch image** to `lmscommunity/lyrionmusicserver` (e.g. `:stable`) and stop using `logitechmediaserver`.
2. **Mount `/config`** to one persistent host directory or named volume; ensure no other service or compose project overwrites it.
3. **Mount `/music`** to the same music library path you expect LMS to scan (and that you use consistently).
4. **Mount `/playlist`** to a persistent path if you use playlists.
5. **After first correct run:** Confirm on the host that `.../lyrion-config/cache` and `.../lyrion-config/cache/Plugins` exist and are updated after you change settings and install plugins.
6. **Backup:** Periodically back up the host path (or volume) used for `/config` so you never lose favorites, DB, or plugin config even if something else goes wrong.

---

## Optional: manual plugins

From the image docs: to install plugins manually, put them in **`[config folder]/cache/Plugins`** on the host (that’s `/config/cache/Plugins` in the container), then restart LMS. Plugin configuration is stored under the same `/config` tree, so a single persistent `/config` mount keeps plugin config as well.

---

## Fix for VBR on newsounds (immediate)

To stop state loss without changing the image yet:

1. **Use a fixed path in compose** so it does not depend on `$USER`. In `~/VBR/docker-compose.yml`, either:
   - Replace every `/home/${USER}/` with `/home/rec/`, or
   - Add a `.env` in `~/VBR` with e.g. `MUSIC_ROOT=/home/rec` and in the compose use `${MUSIC_ROOT}` (and set `MUSIC_ROOT=/home/rec` in that file so it’s never empty).

2. **Ensure compose is always run with that same config.** If a systemd unit or script runs `docker compose up`, run it as user `rec` (e.g. `User=rec` in the unit) or run it from a directory where `.env` or the compose file has the explicit path.

3. **Optional:** Add a comment in the compose file: “Do not run as root; paths are for rec’s Music dir.”

After that, a full `docker-compose down` then `docker-compose up -d` (as rec or with the explicit path in place) will keep using `/home/rec/Music` and `/home/rec/Music/state`, so favorites, DB, and plugin config will persist.

---

## Testing the basic fix (state not “going back in time”)

We need to confirm that after a compose restart (or running compose as a different user) the same state is used and nothing reverts.

**1. Capture baseline on newsounds (before down/up)**

- **Favorites:** In the LMS UI, note how many favorites and their names (e.g. “KQED”, “KCSM”, any others). Or from the host: `wc -l` and first lines of `/home/rec/Music/state/prefs/favorites.opml`.
- **Library:** In LMS UI note approximate track count, or on host: e.g. `sqlite3 /home/rec/Music/state/cache/library.db "SELECT COUNT(*) FROM tracks;"` (if that table exists) or just “library size” from the UI.
- **Plugins:** In LMS → Settings → Plugins, note which are enabled or list a couple; or on host: `ls /home/rec/Music/state/prefs/plugin/*.prefs` and optionally one plugin’s settings.

**2. Apply the fix**

- Deploy the compose change that uses a fixed path (e.g. `MUSIC_ROOT=/home/rec` in `.env` or `${MUSIC_ROOT:-/home/rec}` in the compose so the same state dir is always mounted).

**3. Restart and verify**

- On newsounds: `cd ~/VBR` (or the deploy path), `docker compose down`, then `docker compose up -d`. Wait for LMS to be healthy.
- **Favorites:** Same count and same entries as baseline (no drop to “just two”).
- **Library:** Same approximate track count / same library, no “back in time” (e.g. no drop to an older scan).
- **Plugins:** Same plugins enabled and same config (e.g. same plugin prefs files present and modified time after restart).

**4. Optional: simulate “wrong user”**

- Run once with `USER=root` but with `MUSIC_ROOT=/home/rec` set in `.env` (so compose still mounts `/home/rec/Music` and `/home/rec/Music/state`). Do a down/up and confirm state still persists. That confirms the fix works even if someone runs compose as root.

If any of these checks fail, the state directory in use is still wrong or the fix wasn’t applied where compose is actually run.

---

## Testing the 8 → 9 (Lyrion) upgrade

When we switch from current LMS 8.1.1 to Lyrion 9.x:

- **Paths:** Lyrion image uses `/config`, `/music`, `/playlist` (not `/mnt/state`, `/mnt/music`, `/mnt/playlists`). We need to point `/config` at the same content we now have in `/home/rec/Music/state` (or migrate that dir into a new Lyrion config dir and point `/config` there). Plan and test that migration once we’re ready.
- **Prefs/DB format:** 9.x may have different prefs or DB schema. Before switching images, back up `/home/rec/Music/state` entirely. After switching, verify favorites, library, and plugin list/settings; if something is missing or broken, we have a rollback and can check Lyrion 9 release notes for breaking changes.
- **Plugins:** Some 8.x plugins may be incompatible or renamed in 9. After upgrade, re-check installed plugins and their settings; re-enable or reconfigure as needed.
- **Players:** Confirm SqueezeESP32 / other players still connect and that discovery (e.g. port 3483, hostname) still works with the new image.

Include the “state not going back in time” test above after the 8→9 switch, using the new `/config` mount, to ensure restarts still preserve state.

---

## What’s next on the main Lyrion plan (order of work)

1. **VBR is already on `MUSIC_ROOT` and merged** — state paths no longer depend on `USER` for compose. Full-stack restarts should keep the same host state tree.
2. **Pre-migration backup** — copy or snapshot `/home/rec/Music/state` (entire tree: `prefs/`, `cache/`, plugin dirs) before any image swap.
3. **Compose migration for Lyrion** — switch `lms` service to `lmscommunity/lyrionmusicserver` (e.g. `:stable`), map **`/config`** to your persistent state (either reuse migrated content from current `.../Music/state` or a dedicated host dir), and map **`/music`** / **`/playlist`** per [Hub docs](https://hub.docker.com/r/lmscommunity/lyrionmusicserver). Add `TZ` or time bind mounts as needed; keep ports **1:1** (9000/9090) or set `HTTP_PORT` per docs.
4. **First boot on 9.x** — verify favorites, library scan, plugins; expect possible plugin compatibility tweaks and **Spotty re-auth** after upgrade.
5. **Post-upgrade regression** — run the same persistence checks as in pre-migration (favorites, `audio=1` count, plugin prefs). Optional: follow **`docs/lms-restart-checks.md`** in the **VBR** repo for a concrete checklist.
6. **After Lyrion is stable** — Spotty end-to-end; then the **mirror orphan / marker-file** work for non-FLAC and retagged albums.

---

## What’s next on the main Lyrion plan (order of work)

1. **VBR is already on `MUSIC_ROOT` and merged** — state paths no longer depend on `USER` for compose. Full-stack restarts should keep the same host state tree.
2. **Pre-migration backup** — copy or snapshot `/home/rec/Music/state` (entire tree: `prefs/`, `cache/`, plugin dirs) before any image swap.
3. **Compose migration for Lyrion** — switch `lms` service to `lmscommunity/lyrionmusicserver` (e.g. `:stable`), map **`/config`** to your persistent state (either reuse migrated content from current `.../Music/state` or a dedicated host dir), and map **`/music`** / **`/playlist`** per [Hub docs](https://hub.docker.com/r/lmscommunity/lyrionmusicserver). Add `TZ` or time bind mounts as needed; keep ports **1:1** (9000/9090) or set `HTTP_PORT` per docs.
4. **First boot on 9.x** — verify favorites, library scan, plugins; expect possible plugin compatibility tweaks and **Spotty re-auth** after upgrade.
5. **Post-upgrade regression** — run the same persistence checks as in pre-migration (favorites, `audio=1` count, plugin prefs). Optional: follow **`docs/lms-restart-checks.md`** in the **VBR** repo for a concrete checklist.
6. **After Lyrion is stable** — Spotty end-to-end; then the **mirror orphan / marker-file** work for non-FLAC and retagged albums.

---

## Summary

- **Image:** `lmscommunity/lyrionmusicserver` (Lyrion Music Server; no longer use `logitechmediaserver`).
- **Favorites, music DB, and plugin config** all live under **`/config`** (lyrionmusicserver) or under **`/mnt/state`** (justifiably image); in both cases one persistent mount must be used every time.
- **On newsounds:** State loss is caused by `${USER}` in the compose file. When compose runs as root, it mounts `/home/root/Music` (empty state). Fix: use explicit `/home/rec/` paths (or a `.env` with a fixed path) so the same state directory is always used.
- Use the same persistent paths (or named volumes) for config/state, music, and playlists on every `docker-compose up -d`, and back up the config/state directory regularly.
