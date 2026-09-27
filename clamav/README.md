# ClamAV: two-tier on-access scanning

Realtime ClamAV for this machine (CachyOS, ClamAV 1.5, glibc 2.44): a blocking tier on the folders where files
arrive, a detect tier on the rest of `~`, a weekly full scan, desktop notifications, and a watchdog. The system
side is installed from here as root; the user side (scripts and user units) comes with the rest of the dotfiles.

## Layout

| Path | Purpose |
|---|---|
| `stage/etc/clamav/clamd.conf` | scanner daemon config: ClamAV's sample `clamd.conf` as Arch ships it, plus MaxThreads 40, StreamMaxLength 100M, LogRotate, ExcludePath /proc /sys /dev /run |
| `stage/etc/clamav/clamonacc-block.conf` | **Tier 1, blocking.** `OnAccessPrevention yes` on Downloads, Desktop, Documents, Pictures, Videos, Music, Public, Templates, `.cache/yay`. Opens are held until clamd answers; infected files are denied and quarantined. Files over 10M are left to tier 2. |
| `stage/etc/clamav/clamonacc-notify.conf` | **Tier 2, detect.** Notify-only on all of `~` minus churn dirs (Steam, browser/shader/thumbnail caches, `~/.gradle`, `.claude`, Trash, Minecraft saves). Scans on close-write, move-in and open; quarantines. Files up to 100M. |
| `stage/etc/systemd/system/clamav-clamonacc@.service` | template unit; instances `@block` and `@notify` |
| `stage/etc/sysctl.d/60-clamav-onaccess.conf` | inotify watch limit |
| `stage/usr/local/bin/clamav-watchdog` + `stage/etc/systemd/system/clamav-watchdog.{service,timer}` | restarts clamd and both tiers when clamd burns CPU with no scan job (see below) |
| `fts-shim/clamonacc-fts-shim.c` | LD_PRELOAD shim that makes clamonacc's directory discovery work on glibc >= 2.44 (see below). Built and installed to `/usr/local/lib` by `install-clamav.sh` and `apply.sh`. |
| `clamav-notify.service` | user unit: desktop notification for every detection and quarantine (`scripts/.local/bin/clamav-notify.sh`) |
| `clamav-weekly-scan.{service,timer}` | user units: full scan of `~` through clamd, Sunday 03:00 (`scripts/.local/bin/clamav-weekly-scan.sh`) |
| `install-clamav.sh` | root: install clamav, gcc and socat, drop in `stage/`, create `/var/lib/clamav/quarantine`, mask the stock clamonacc unit, freshclam, enable and start everything |
| `apply.sh` | root: re-apply everything in `stage/` and the shim, restart clamd and both tiers. Use after editing anything in `stage/`. |
| `cleanup.sh` | root: stop, remove the package and everything `install-clamav.sh` put in place. Keeps the signature DB unless `KEEP_DB=0`. |
| `test/` | `watchdog.sh` and `weekly-scan.sh`: decision tests with fake `clamd`, `socat`, `clamdscan` and `notify-send`; no root needed |

The panel's ClamAV card (`quickshell/.config/quickshell/panel/ClamAV.qml`, fed by `scripts/.local/bin/panel-clam`)
shows every unit with a switch, detections since boot, the last weekly scan and the signature date.

## Install from scratch

```bash
sudo ./clamav/cleanup.sh          # only when replacing an existing setup
sudo ./clamav/install-clamav.sh
./install.sh scripts              # user side: stows the scripts, links and enables the user units
```

`install.sh` links the ClamAV user units only when `clamdscan` is installed, so run `install-clamav.sh` first.

## The bug: clamonacc + glibc >= 2.44 = no subdirectories watched

Symptom: on-access catches files directly in an `OnAccessIncludePath` dir but nothing in subdirectories, and any
`OnAccessExcludePath` makes the log say `ClamInotif: can't exclude '...'`.

Cause: glibc 2.44 replaced its BSD-derived `fts(3)` with gnulib's. gnulib's `fts_children()` **defers `stat()` when
`fts_open()` was given no comparator** and returns every entry as `FTS_NSOK` (type hint only in `fts_statp->st_mode`).
clamonacc's DDD (`hash.c: onas_ht_add_hierarchy`) records a child only if `fts_info == FTS_D`, so every directory ends
up with an empty child list. The watch walk follows those lists → only the include roots get fanotify marks. The exclude
loop (`inotif.c: onas_ddd_th`) calls `onas_ht_rm_child(parent, name)` → name not in the (empty) list → `return NULL`
→ DDD thread dead. It reproduces against stock Arch glibc too; it is not a CachyOS build quirk.

Fix: `fts-shim/clamonacc-fts-shim.c`, preloaded into clamonacc only via `Environment=LD_PRELOAD=` in the template unit.
It wraps `fts_open()` and substitutes a no-op comparator when none is given, which makes gnulib stat eagerly and return
`FTS_D` again. It is root-owned in `/usr/local/lib` because it runs inside a root process: never make it user-writable.
Verified: nested EICAR in `~/Downloads/a/b/c/` → `cat` returns "Operation not permitted", then quarantined; nested
deeper elsewhere in `~` → quarantined within seconds; a file in an excluded dir → untouched.
If a future ClamAV release fixes this upstream, the shim becomes a harmless no-op.

## Changing the notify-tier excludes

Edit `stage/etc/clamav/clamonacc-notify.conf`, then `sudo ./clamav/apply.sh`.

**Every `OnAccessExcludePath` must be an anchored regex matching exactly one directory** (`^/home/sricharan/\.cache/foo$`).
The pattern is an unanchored ERE matched against *every* directory in the table (`inotif.c` ~L531). An unanchored path
matches all of its subdirectories too; each match triggers a hierarchy removal whose child recursion has a length bug
(`hash.c onas_ht_rm_hierarchy` passes the buffer size, not the string length) so children are never removed, and visiting
one after its parent is gone kills the DDD thread. An anchored pattern matches one entry, unlinks it from its parent, and
the watch walk never descends into it.

Exclude what is rewritten or reopened constantly and has no inbound path of its own. The tier scans on open, so a
directory of large archives that tools keep opening (`~/.gradle`: every Gradle daemon or IDE start reopens multi-MB
compiler jars) holds a core busy for minutes at a time. `clamd` showing one `FILDES` job after another in `zSTATS`,
each 30 s or longer, is the sign; `sudo ls -l /proc/$(pgrep -x clamd)/fd` names the file.

## The watchdog

Every 2 min, `clamav-watchdog` samples clamd's CPU for 5 s and asks it for `zSTATS`. A strike is clamd above 90 % of
a core while STATS lists no scan job (only `STATS` and `IDLE` threads, or no reply at all), or only single-file jobs
(`FILDES`, `INSTREAM`) older than 300 s, which clamd's own 120 s scan limit should have ended. Two strikes in a row
restart clamd and both tiers. Each strike is logged with the jobs STATS showed (`journalctl -u clamav-watchdog`).

The queue length is not a signal: `QUEUE` counts only jobs waiting for a free thread, so with 40 threads it reads 0
under full load, and a busy clamd (the weekly scan runs at 2000 % and more) would look like a stuck one.

## The weekly scan

`clamav-weekly-scan.sh` runs `clamdscan --fdpass --multiscan` over `~`, writes
`~/.local/state/clamav/weekly-YYYY-MM-DD.log` (a second run the same day replaces it) and sends one notification.
It reports and never quarantines; the on-access tiers do that.

clamdscan prints `Infected files: N` even when it gives up halfway, and its exit code is 2 both for that and for a
finished scan that skipped a few sockets or pipes. The verdict comes from the log instead: any `ERROR:` line other than
the per-file `Can't access file` means the scan did not finish, and the notification says so with the reason.
`panel-clam` applies the same rule, so the card shows "incomplete" rather than "clean".

## Log noise that is normal

`WARNING: Can't open file ... for safe quarantine action` / `Daemon failed to scan` on `*.tmp`, `*.journal`, sqlite
side files: with `--move` set, clamonacc opens the file itself before scanning (so it quarantines exactly the file that
was scanned) and passes that descriptor to clamd. Temp files renamed away in between log this and are skipped. Four
lines per file is one per fanotify event. Persistent offenders belong in the notify tier's exclude list.

## Day-to-day

```bash
systemctl status 'clamav*'                              # services
journalctl -f -o cat -u 'clamav-clamonacc@*'            # live on-access log
journalctl -u clamav-watchdog -o cat --since today      # watchdog strikes and restarts
sudo ls -la /var/lib/clamav/quarantine                  # quarantined files
sudo tail /var/log/clamav/clamonacc-block.log /var/log/clamav/clamonacc-notify.log
ls ~/.local/state/clamav/                               # weekly scan reports
systemctl --user list-timers clamav-weekly-scan.timer   # next weekly run
./clamav/test/watchdog.sh && ./clamav/test/weekly-scan.sh
```

Test the tiers: `printf 'X5O!P%%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > ~/Downloads/eicar.txt`
→ quarantined within a second, and a desktop notification appears.

## Known limits

- Blocking mode costs one clamd round-trip per `read()` (about 3-10 ms), which is why it covers only inbound dirs.
- Notify mode is detect-after-the-fact; a file can be opened once before it's quarantined.
- ClamAV is signature-based: known malware only.
- Excluded churn dirs are only covered by the weekly scan.
- If clamd is down, access is allowed (`OnAccessDenyOnError no`): availability over security.
