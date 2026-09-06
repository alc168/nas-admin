---
title: "TerraMaster NAS — Infrastructure Audit & Improvement Plan"
subtitle: "Host: terramaster (192.168.0.172) · Ubuntu 24.04.4 LTS"
author: "Prepared for jp3@poons.com"
date: "2026-09-06"
---

# 1. Executive summary

`terramaster` is a single Intel N95 mini-NAS (4 cores, 7.5 GiB RAM) running Ubuntu
24.04 that has grown organically into a **41-container, 10-Docker-Compose-project**
home server. It does four unrelated jobs at once:

1. **Media automation & streaming** — Plex + the "*arr*" stack (Radarr, Sonarr,
   Prowlarr, qBittorrent) pulling from **TorrentLeech** and **MyAnonaMouse**.
2. **Photo library** — Immich (31,975 assets / ~268 GB originals, single user).
3. **Home-energy automation** — the "**dash.home2**" Sigenergy battery/solar
   controller (project `home-dash2`) plus a Life360 family-location feed.
4. **A cluster of personal web apps & experiments** — an algorithmic-trading
   data platform, a study site, a psychology-revision app, a public marketing
   site behind a Cloudflare tunnel, a research agent (LiteLLM + SearXNG +
   GPT-Researcher), a Prometheus/Grafana monitoring stack, and several
   abandoned prototypes.

**It works, but it is fragile and over-exposed.** The headline problems:

| Area | Problem | Severity |
|---|---|---|
| Security | Grafana admin password is `admin`, exposed on `0.0.0.0:3001` | **High** |
| Security | ~25 service ports bound to `0.0.0.0` with **no host firewall** (ufw not installed) | **High** |
| Security | Plaintext personal passwords & API keys in `~/.env`, `~/sigen-dashboard/.env`, `prowlarr.db`, `theownitguy-website/.env` | **High** |
| Security | SSH on `0.0.0.0:22` — `PasswordAuthentication yes` (**verified** via `sshd -T`), `PermitRootLogin without-password`, **fail2ban inactive**, and the sudo/login password for `tm` is literally **`tm`** | **High** |
| Security | NFS exports `/mnt/storage` **read-write, no auth**, to the whole `192.168.0.0/24` | **Medium** |
| Robustness | **No UPS**; NVMe SMART shows **35 unclean shutdowns** across the two SSDs — ext4 + Postgres + SQLite are being power-cut roughly monthly | **Medium–High** |
| Robustness | **No SMART self-test schedule**; `smartd` only mails `root` locally (i.e. nowhere) — on a **no-parity** pool this is the blind spot | **Medium** |
| Robustness | ~**22 GB** real Docker footprint, **~38 GB** nominal-reclaimable images + **15 GB** build cache | **Medium** |
| Robustness | `home.dash2` git repo is in **detached HEAD**; most infra config is **not in git at all** | **Medium** |
| Robustness | Pending **reboot** for kernel `6.8.0-139` (running `-138`). *(Auto-updates via `unattended-upgrades` **are** working — earlier draft said otherwise.)* | **Low–Med** |
| Filesystem | Immich DB (4.7 GB) + model cache live on the **OS SSD**; the 932 GB "photos" NVMe (`/mnt/NVMe2`) is **99 % empty** | **Medium** |
| Filesystem | `/mnt/storage/torrents` = **7.6 TB** (16 % of the pool) — seeding backlog / copies not hardlinks | **Medium** |
| Legacy | 6 dead containers, 3 stale compose projects (`v2`, `life360-nas-poller`, staging), a failed `glancesweb.service`, 9 `.bundle` files, a 4.4 GB stray SQL dump | **Low–Med** |

Nothing here is on fire. The recommendations in [§14](#14-recommendations-one-by-one)
are ordered so the security items can be done in an evening and the cleanup over a
weekend.

---

# 2. Hardware & operating system

| Property | Value | Evidence |
|---|---|---|
| Model | TerraMaster (F4-style), `bond0` networking | `mount`, `ss` show `Interface=bond0` |
| CPU | Intel **N95** @ up to 3.4 GHz, 4 cores / 4 threads | `lscpu` |
| RAM | **7.5 GiB** total; at audit **3.7 GiB used, 4.2 GiB cache, 279 MiB free**; **swap 2.5 GiB / 4 GiB used** | `free -h` |
| GPU | Intel iGPU (`/dev/dri`) — used by Plex & Immich for QuickSync transcode | `docker-compose.yml` `devices:` |
| OS | Ubuntu **24.04.4 LTS** (noble), kernel **6.8.0-138-generic** | `/etc/os-release`, `uname -a` |
| Uptime | 3 days 5 h at audit; load average ~1.0 (i.e. one core pinned continuously) | `uptime` |
| Boot | UEFI, `curtin`/cloud-init install | `/etc/fstab` comments |
| Pending | **`/var/run/reboot-required` present**; `reboot-required.pkgs` = `linux-image-6.8.0-139-generic` (running `-138`) | `cat /var/run/reboot-required.pkgs` |
| Auto-updates | `unattended-upgrades` **is enabled and running** — `/etc/apt/apt.conf.d/20auto-upgrades` sets both `Update-Package-Lists "1"` and `Unattended-Upgrade "1"`; `apt-daily-upgrade.timer` fired 2026-09-05 06:04 and patched openssh, gnupg, `linux-*` 138→139, libgcrypt, etc. | `/var/log/apt/history.log` |

**Observation:** swap is 62 % used with 4 GiB cache in RAM — the box is under
steady memory pressure. `immich` (386 MB RSS), two Immich Postgres instances,
Radarr/Sonarr/Prowlarr (.NET, ~500 MB combined), Grafana, Prometheus, the
7-container trading platform, and `home-dash2` all resident. Load average pinned
at ~1.0 is `trading-collector` (10 % CPU continuously) plus Immich ML.
**Reassuring:** `journalctl -k -b` over 3+ days shows **no OOM kills, no I/O
errors, no ext4 errors, no ATA resets** — swap is absorbing the pressure without
anything being killed. Only boot-time noise: cosmetic ACPI-BIOS symbol errors
(N95 firmware quirk), a `blkmapd` NFS pipe warning, and the 2nd NIC (`enp2s0`)
link-down (unplugged).

## 2.1 Disk & power health (SMART, verified with sudo)

**Every drive passes SMART with _zero_ reallocated sectors, zero pending
sectors, zero offline-uncorrectable, zero UDMA-CRC errors.** The pool is
genuinely healthy today. The caveats are age, drive type, and the lack of
monitoring/parity/UPS.

| Dev | Mount | Model | Type | Power-on hours | Realloc / Pending / CRC | Temp | Note |
|---|---|---|---|---|---|---|---|
| sda | disk1 | WD60EFAX-68JH4N0 | **SMR** (WD Red SMR), 5400 rpm | 4,991 | 0 / 0 / 0 | 24 °C | **SMR is poor for the torrent-move workload** |
| sdb | disk2 | WD60EFRX-68MYMN1 | CMR (WD Red), 5700 rpm | **45,608 (~5.2 yr)** | 0 / 0 / 0 | 31 °C | **Oldest by far — statistically first to fail**; holds ~4.2 TB, no parity |
| sdc | disk3 | WD60EFRX-68MYMN1 | CMR, 5700 rpm | 14,334 | 0 / 0 / 0 | 33 °C | healthy |
| sdd | disk4 | WUH721818ALE6L4 | CMR (Ultrastar DC HC550), 7200 rpm | 31,514 | 0 / 0 / 0 | 36 °C | healthy |
| sde | disk5 | WUH721818ALE6L4 | CMR, 7200 rpm | 31,379 | 0 / 0 / 0 | 37 °C (max-ever 49 °C) | slightly warm |
| sdf | disk6 | WUH721818ALE6L4 | CMR, 7200 rpm | 21,835 | 0 / 0 / 0 | 37 °C | healthy |
| nvme0 | /mnt/NVMe2 | WD SN550 1TB | TLC | 4,611 | wear **6 %**, 35 TB written, **21 unsafe shutdowns**, 0 media errors | — | the under-used "photos" NVMe |
| nvme1 | / (OS) | WD SN550 1TB | TLC | 4,911 | wear **1 %**, 23 TB written, **14 unsafe shutdowns**, 0 media errors | — | OS + Immich DB + Plex metadata |

**Three robustness gaps fall out of this:**

1. **No UPS.** `lsusb` shows no UPS; no `nut`/`apcupsd` installed. The NVMe
   counters record **35 combined unsafe shutdowns** — the machine is losing
   power uncleanly on the order of once a month. ext4, mergerfs, Postgres
   (Immich + trading), and a dozen SQLite databases are all exposed to that.
2. **No SMART self-test schedule.** `/etc/smartd.conf` is only
   `DEVICESCAN -d removable -n standby -m root -M exec …` — no
   `-s (S/../.././02|L/../../6/03)` short/long test schedule, and alerts go to
   local `root` mail (unread). On a **no-parity** pool, undetected drive
   degradation is the worst case.
3. **The 5.2-year-old `disk2` (sdb).** Still clean, but this is the one to
   pre-emptively replace or at least watch closely — and the SMR `disk1`
   (sda) is the one whose write performance will degrade under load.

---

# 3. Storage architecture

## 3.1 Physical disks

```
lsblk (abridged):
sda  5.5T WD60EFAX   ext4  /mnt/disk1
sdb  5.5T WD60EFRX   ext4  /mnt/disk2
sdc  5.5T WD60EFRX   ext4  /mnt/disk3
sdd  16.4T WUH721818 ext4  /mnt/disk4
sde  16.4T WUH721818 ext4  /mnt/disk5
sdf  16.4T WUH721818 ext4  /mnt/disk6
nvme0n1  931.5G WD SN550  xfs   /mnt/NVMe2      (fstab: "The Second NVMe2 for Photos")
nvme1n1  931.5G WD SN550  ext4  /              + /boot/efi     (OS)
```

## 3.2 mergerfs pool

`/etc/fstab`:

```
/mnt/disk* /mnt/storage mergerfs defaults,allow_other,cache.files=off,use_ino,\
  category.create=mfs,minfreespace=100G,fsname=mergerfsPool,nonempty 0 0
```

- **6 data disks (66 TB raw) pooled as `/mnt/storage`** via mergerfs (FUSE union).
- `category.create=mfs` = new files go to the disk with **most free space**.
- **There is no parity / RAID.** mergerfs is JBOD-with-a-union-view: lose one
  disk, lose exactly the files on that disk. `mergerfs.balance` and
  `mergerfs-tools` (cloned from `trapexit/mergerfs-tools`) are present for
  rebalancing.
- Pool usage: **47 TB used / 66 TB (75 %)**, 16 TB free.

`df -h` at audit:

| Mount | Size | Used | Use % |
|---|---|---|---|
| `/` (OS SSD) | 915 G | 99 G | 12 % |
| `/mnt/storage` (pool) | 66 T | 47 T | 75 % |
| `/mnt/disk1` | 5.5 T | 4.0 T | 77 % |
| `/mnt/disk2` | 5.5 T | 4.2 T | 78 % |
| `/mnt/disk3` | 5.5 T | 4.0 T | 77 % |
| `/mnt/disk4` | 17 T | 12 T | 78 % |
| `/mnt/disk5` | 17 T | 12 T | 78 % |
| `/mnt/disk6` | 17 T | 11 T | 67 % |
| `/mnt/NVMe2` | 932 G | **58 G** *(2.8 G real; xfs overhead)* | **7 %** |

## 3.3 What lives where (logical map)

| Path | Contents | Size | Notes |
|---|---|---|---|
| `/mnt/storage/plex-movies` | Radarr library root, Plex "Movies" | **26 TB** | 1,137 folders / 1,127 Plex items |
| `/mnt/storage/plex-tv` | Sonarr library root, Plex "TV Shows" | **12 TB** | 632 show folders / 5,763 episodes |
| `/mnt/storage/plex-mobile` | Plex "Mobile-Movies" (re-encoded small copies) | **922 GB** | 930 folders |
| `/mnt/storage/torrents` | qBittorrent completed-download area for radarr/sonarr | **7.6 TB** | 688 entries — see [§5.4](#54-the-76-tb-torrents-problem) |
| `/mnt/storage/jez-photos` | Immich upload root (`/usr/src/app/upload`) | ~**300–350 GB** | 268 GB originals per Immich DB + thumbs/encoded |
| `/mnt/storage/F1` | qBittorrent "F1" category + Plex "F1" library | (in pool) | also mis-mapped to `/mnt/NVMe2` in Plex |
| `/mnt/storage/EPL`, `/mnt/storage/data` | sports / misc download landing | small | |
| `/mnt/storage/homes` | Samba `[homes]` per-user dirs | small | root-owned |
| `/mnt/storage/research-agent`, `/mnt/storage/plex-mobile` | app data on the pool | | |
| `/jez-cache/immich/postgres` | **Immich Postgres data dir** | **4.7 GB on disk** (2.2 GB logical) | **on the OS SSD `/`, not NVMe2** |
| `/jez-cache/immich/model-cache` | Immich ML models | 786 MB | on the OS SSD |
| `/var/lib/docker` | images / overlay / volumes | **22 GB** | ~half reclaimable ([§13](#13-legacy--orphaned-inventory)) |
| `/mnt/NVMe2/trading-platform/` | trading Postgres + parquet | 2.8 GB | one of only two real users of the "photos" NVMe |
| `/mnt/NVMe2/family-home-backups/` | nightly snapshot of `/mnt/storage/homes`, via `family-home-backup.timer` (02:15) → `/usr/local/sbin/backup-family-homes` | ~0 | source `/mnt/storage/homes` is itself only **48 KB** — feature set up 2026-08-31, barely used |
| `/home/tm/config/Library` | **Plex metadata / thumbnails / DB** | **31 GB** | on the OS SSD (fine, but large) |
| `/home/tm/config/{radarr,kometa,qbt-tl,sonarr}` | app configs + **debug logs** | 2.3 G / 1.2 G / 1.2 G / 422 M | log level is `debug` everywhere — inflated |
| `/mnt/immich_db_backup.sql` | **stray 4.4 GB manual dump, 2026-07-04** | 4.4 GB | legacy — delete |

**Two filesystem problems jump out:**

1. **The 932 GB NVMe (`/mnt/NVMe2`) that fstab labels "for Photos" is 99 % empty.**
   Immich's database and ML cache sit on the OS SSD instead, and the photo
   originals sit on spinning mergerfs disks. Immich thumbnail generation and
   timeline scrubbing are exactly the random-IO workload an NVMe is for.
2. **`/mnt` is a junk drawer**: `immich_db_backup.sql` (4.4 GB), `temp/`,
   `scratch/`, `nvme1n1p2-scratch/`, `usb_data/`, `remote_usb/`, `das1/`,
   `das2/` (empty DAS mountpoints), and `.DS_Store` files committed all over
   `/mnt/storage`.

---

# 4. Docker landscape

`docker info`: **47 containers (41 running), 49 images, overlay2, root `/var/lib/docker`.**
`docker system df`:

```
Images         49   ACTIVE 42   SIZE 39.11GB   RECLAIMABLE 38.32GB (97%)
Containers     47   ACTIVE 41   SIZE 268.3MB
Local Volumes   8   ACTIVE  6   SIZE 326.1MB
Build Cache   832               SIZE 17.26GB   RECLAIMABLE 14.92GB
```

## 4.1 Compose projects (`docker compose ls -a`)

| Project | Config file | State | Purpose |
|---|---|---|---|
| **tm** | `~/docker-compose.yml` + `~/docker-compose-monitoring.yml` | 19 running, 1 exited | Media stack + Immich + Plex + monitoring |
| **trading-platform** | `~/trading-platform/deploy/docker-compose.terramaster.yml` | 8 running | ASX/crypto data platform |
| **home-dash2** | `~/sigen-dashboard/home.dash2/docker-compose.yml` | 5 running | **dash.home2** energy dashboard |
| **research-agent** | `~/research-agent/docker-compose.yml` | 3 running | LiteLLM + SearXNG + GPT-Researcher |
| **territory** | `~/territory/docker-compose.yml` | 2 running | news-signal watcher web app |
| **theownitguy-website** | `~/theownitguy-website/docker-compose.yml` | 2 running | public marketing site + Cloudflare tunnel |
| **timeline-nas-webapp** | `~/timeline-nas-webapp/docker-compose.yml` | 1 running | Google-Takeout family timeline |
| **vce-psychology** | `~/vce-psychology/docker-compose.yml` | 1 running | VCE Psychology revision app (`ap.study`) |
| **v2** | `~/sigen-dashboard/v2/docker-compose.yml` | **exited (3)** | **superseded predecessor of home-dash2** |
| **life360-nas-poller** | `~/life360-nas-poller/docker-compose.yml` | **exited (2)** | **standalone Life360 app, replaced by home-dash2's built-in poller** |

## 4.2 Docker networks

18 networks. Live/normal: `tm_default`, `tm_immich-network`, `tm_monitoring`,
`home-dash2_default`, `research-network`, `territory_default`,
`trading-platform_trading_internal`, `dashboard_shared` (shared trading↔dash),
`theownitguy-website_*`, `timeline-nas-webapp_default`, `vce-psychology_default`.

**Orphaned:** `homedash2_default`, `home-dash2_default` *(duplicate naming —
`home.dash2` vs `homedash2`)*, `life360-nas-poller_default`, `v2_default`.

## 4.3 Container privilege posture

- **No container is `--privileged`.** ✅
- **No container mounts `/var/run/docker.sock`.** ✅
- **6 containers use `network_mode: host`:** `plex2`, `qbt-tl`, `sonarr`,
  `radarr`, `prowlarr`, `autobrr`. Host networking is normal for Plex (DLNA/GDM
  discovery) but means Radarr:7878, Sonarr:8989, Prowlarr:9696 and the
  qBittorrent WebUI:8080 are **directly on the LAN with no Docker port
  mapping to restrict them**.
- The **trading-platform** stack is the model citizen: `read_only: true`,
  `cap_drop: [ALL]`, `no-new-privileges`, `tmpfs` for `/tmp`, Docker
  *secrets* for the DB password, `mem_limit`/`cpus` on every service,
  all ports bound to `127.0.0.1`. Nothing else on the box is this disciplined.

---

# 5. Media automation stack (the "*arr*" stack)

## 5.1 Components

All defined in `~/docker-compose.yml` (project `tm`), images from
`lscr.io/linuxserver/*`, `PUID=1000 PGID=1000`, `TZ=Australia/Melbourne`,
`/mnt` bind-mounted whole into each:

| Container | Image | Port | Config dir | Role |
|---|---|---|---|---|
| `prowlarr` | linuxserver/prowlarr | 9696 (host) | `~/config/prowlarr` | Indexer manager — the single source of "where to search" |
| `radarr` | linuxserver/radarr | 7878 (host) | `~/config/radarr` | Movie automation |
| `sonarr` | linuxserver/sonarr | 8989 (host) | `~/config/sonarr` | TV automation |
| `qbt-tl` | linuxserver/qbittorrent | 8080 (host) | `~/config/qbt-tl` | The one torrent client |
| `autobrr` | ghcr.io/autobrr/autobrr | 7474 (host) | `~/config/autobrr` | IRC announce → instant grabs — **installed but empty** |
| `seerr` | ghcr.io/seerr-team/seerr | 5055 | `~/config/overseerr` | Request front-end (Overseerr fork) |
| `kometa` | kometateam/kometa | — | `~/config/kometa` | Plex collection/artwork manager, runs 03:00 daily |

## 5.2 How a download actually happens

```
                 ┌─────────────┐   search    ┌──────────────┐
   Plex user ───▶│    seerr     │────────────▶│ Radarr /     │
   "I want X"    │  :5055       │  (approve)  │ Sonarr       │
                 └─────────────┘             └──────┬───────┘
                                                    │ query indexers
                                                    ▼
                                             ┌──────────────┐   Cardigann   ┌───────────────┐
                                             │  Prowlarr    │──────────────▶│ TorrentLeech  │
                                             │  :9696       │◀──────────────│ (only indexer)│
                                             └──────┬───────┘   results     └───────────────┘
                                                    │ push .torrent (best release)
                                                    ▼
                                             ┌──────────────┐
                                             │  qbt-tl      │  category = radarr / tv-sonarr
                                             │  :8080       │  save → /mnt/storage/torrents
                                             └──────┬───────┘
                                                    │ on complete: Radarr/Sonarr import
                                                    ▼
                              /mnt/storage/plex-movies/…   or   /mnt/storage/plex-tv/…
                                                    │
                                                    ▼
                                          Plex scans, Kometa decorates
```

### Evidence

**Prowlarr** (`prowlarr.db`):

- **Indexers (1):** `TorrentLeech` — `Implementation: Cardigann`,
  `definitionFile: torrentleech`, credentials embedded (see [§11](#11-exposed-secrets-inventory)).
- **Applications (2):** Radarr (`http://localhost:7878`) and Sonarr
  (`http://localhost:8989`), both `SyncLevel: 2` ("Full Sync" — Prowlarr
  owns the indexer list in Radarr/Sonarr).
- **Download client (1):** qBittorrent `localhost:8080`, category `prowlarr`.

**Radarr** (`radarr.db`):

```
RootFolders:     /mnt/storage/plex-movies/
DownloadClients: qBittorrent  localhost:8080  user=qbittorrent pass=qbittorrent
                 movieCategory = "radarr"
Config:  autounmonitorpreviouslydownloadedmovies=True
         deleteemptyfolders=True   minimumfreespacewhenimporting=1000 (MB)
```

**Sonarr** (`sonarr.db`):

```
RootFolders:     /mnt/storage/plex-tv/
DownloadClients: qBittorrent  localhost:8080  user=qbittorrent pass=qbittorrent
                 tvCategory = "tv-sonarr"
Config:  enablecompleteddownloadhandling=True  deleteemptyfolders=True
```

**qBittorrent** categories (`~/config/qbt-tl/qBittorrent/categories.json`):

| Category | Save path |
|---|---|
| `radarr` | `/mnt/storage/torrents` |
| `tv-sonarr` | `/mnt/storage/torrents` |
| `prowlarr` | *(empty — uses default)* |
| `new movies` | `/mnt/storage/data/movies` |
| `new tv` / `tv` | `/mnt/storage/data/tv` |
| `F1` | `/mnt/storage/F1` |
| `Books` | `/mnt/disk5/data/books` |
| `remoteT5` | `/mnt/remote_usb/T5` |

qBittorrent session config (`qBittorrent.conf`):

```
Session\DefaultSavePath=/mnt/storage/data
Session\TempPathEnabled=false
Session\Port=40012          Session\Interface=bond0  InterfaceAddress=192.168.0.172
Session\DHTEnabled=false  PeXEnabled=false  LSDEnabled=false   ← private-tracker safe
Preferences\WebUI\Address=*   WebUI\Username=qbittorrent
Preferences\Downloads\SavePath=/mnt/disk2/temp/       ← STALE, contradicts DefaultSavePath
```

## 5.3 Notable configuration facts

- **Authentication on Radarr/Sonarr/Prowlarr = "Forms" but
  `AuthenticationRequired = DisabledForLocalAddresses`** — i.e. **no login at
  all from the LAN**. Anyone on `192.168.0.0/24` has full admin.
- API keys are in cleartext in each `config.xml` (see [§11](#11-exposed-secrets-inventory)).
- `LogLevel = debug` on all three — this is why `~/config/radarr` is 2.3 GB.
- **`autobrr` is running but 100 % unconfigured**: `autobrr.db` has 0 users,
  0 indexers, 0 filters, 0 IRC networks, 0 actions. It is dead weight and an
  open `:7474` port. Either wire it to TorrentLeech's IRC announce channel
  (its actual purpose — near-instant grabs) or remove it.
- Only **one** qBittorrent instance despite the compose header comment
  ("`qbt-sports is for downloading F1, AFL, EPL from Sports Cult`"). The
  `qbt-sports` container referenced in comments does not exist; F1 is handled
  by categories in `qbt-tl`.

## 5.4 The 7.6 TB `/mnt/storage/torrents` problem

`/mnt/storage/torrents` holds **7.6 TB across 688 entries** — 16 % of the whole
pool. Radarr and Sonarr import from there into `plex-movies` / `plex-tv`. Both
source and destination are under the same mergerfs mount, so **hardlink imports
are possible only when Radarr/Sonarr's "Use Hardlinks instead of Copy" is on
*and* mergerfs keeps both paths on the same underlying disk**. Given the size,
a large fraction of this is either:

- duplicated (copied, not hardlinked) into the library — pure waste, or
- seeding torrents deliberately retained for TorrentLeech ratio, or
- orphaned downloads Radarr/Sonarr failed to import and never cleaned.

This needs a manual reconciliation pass (see Recommendation 15).

---

# 6. TorrentLeech & MyAnonaMouse

## 6.1 TorrentLeech (movies / TV)

- **Reached only through Prowlarr's Cardigann `torrentleech` definition.**
  Account `alchemist168`, password + alt-2FA token stored in `prowlarr.db`
  `Indexers.Settings.extraFieldData` (see [§11](#11-exposed-secrets-inventory)).
- Prowlarr full-syncs the TL indexer into Radarr and Sonarr. Neither *arr*
  talks to TL directly — they ask Prowlarr, Prowlarr scrapes TL, returns
  results, the *arr* picks a release by its quality profile and hands the
  `.torrent` to qBittorrent.
- **qBittorrent is configured private-tracker-safe**: DHT / PeX / LSD all
  disabled, bound to `bond0` / `192.168.0.172`, port 40012, UPnP off,
  `PortForwardingEnabled=false`.
- **No VPN and no bind-fail "kill switch".** `Proxy\Profiles\*=true` is set but
  **no proxy host is configured**, so that setting is inert — torrent traffic
  egresses on the home WAN IP. For private trackers this is the normal and
  expected setup; noted only so it is a conscious choice.
- `autobrr` was clearly intended to add TL's IRC announce channel for instant
  grabbing but was never set up.

## 6.2 MyAnonaMouse (books) — the `mam-check.sh` cron

Separate from the *arr* stack:

- `crontab -l` (user `tm`): `0 3,9,15,21 * * * /bin/bash /home/tm/scripts/mam-check.sh`
- `~/scripts/mam-check.sh` logs into MyAnonaMouse with a hard-coded
  `MAMID` session token, keeps a session cookie in `~/.mam_script/MAM.cookies`,
  and **auto-spends bonus points**: buys VIP, keeps upload credit topped up
  (100 GB / 50 GB tranches) while staying above a 10,000-point buffer.
- Books land via the qBittorrent `Books` category →
  `/mnt/disk5/data/books`.
- The `MAMID` token in the script is a **long-lived credential in plaintext**
  in a world-readable-by-`tm` script (see [§11](#11-exposed-secrets-inventory)).

---

# 7. Plex

## 7.1 Setup

`~/docker-compose.yml` service `plex` → container **`plex2`**,
`lscr.io/linuxserver/plex:latest`, `network_mode: host`,
`devices: /dev/dri:/dev/dri` (QuickSync).

**Config path:** the compose file mounts `./config:/config`, and `./` is
`/home/tm`, so **Plex's `/config` is the entire `~/config` directory**. Plex's
own data therefore lives at:

```
/home/tm/config/Library/Application Support/Plex Media Server/     (31 GB)
```

This is messy — Plex shares a config root with Radarr, Sonarr, Prowlarr,
Kometa, etc. It works because each app uses its own subfolder, but a
`chown -R` or a backup script pointed at `~/config` now sweeps up 31 GB of
Plex thumbnails.

`Preferences.xml` highlights:

```
FriendlyName="TM"
PlexOnlineUsername="Jeremy_Poon"   PlexOnlineMail="jeremy@poons.com"
PlexOnlineToken="***"              (present in cleartext in the file)
TranscoderQuality="2"  TranscoderThrottleBuffer="6000"
HardwareDevicePath="8086:46d2…@0000:00:02.0"   ← HW transcode enabled
ScannerLowPriority="1"  GenerateBIFBehavior="scheduled"
DlnaEnabled="0"
```

Transcode temp dir: compose mounts `/mnt/temp:/temp` (host `/mnt/temp`, 24 KB —
effectively unused / transcodes to default location).

Two extra Plex-related scripts in `~/scripts/`: `plex_limit.sh` /
`plex_resume.sh` (bandwidth throttling helpers, 188 / 77 bytes).

## 7.2 Libraries (from `com.plexapp.plugins.library.db`)

| # | Library | Type | Path(s) | Items |
|---|---|---|---|---|
| 1 | **Movies** | movie | `/mnt/storage/plex-movies` | **1,127** |
| 2 | **TV Shows** | show | `/mnt/storage/plex-tv` | 5,763 (episodes+seasons) |
| 3 | **Mobile-Movies** | movie | `/mnt/storage/plex-mobile` | 924 |
| 6 | **F1** | movie | `/mnt/storage/F1` **and** `/mnt/NVMe2` | 20 |

- **Where movies are stored:** `/mnt/storage/plex-movies` — the mergerfs pool,
  physically spread across disk1–disk6 (every disk has a `plex-movies/`
  subtree). ~**26 TB**, 1,137 on-disk folders.
- The **F1 library is mis-configured**: it points at both `/mnt/storage/F1`
  and the bare `/mnt/NVMe2` root. That second path is almost certainly a
  leftover mistake (NVMe2 is supposed to be photos) and should be removed
  from the library.
- The Plex DB file is **206 MB** and was last written seconds before the
  audit query — healthy and active.

---

# 8. Immich (photo library)

## 8.1 Topology

`~/docker-compose.yml` (project `tm`), 5 containers on `tm_immich-network`,
`env_file: .env`:

| Container | Image | Purpose | Storage |
|---|---|---|---|
| `immich_server` | `ghcr.io/immich-app/immich-server:v3` | API + web, port **2283** | upload → `/mnt/storage/jez-photos`; internal `/data` on a Docker volume |
| `immich_machine_learning` | `…/immich-machine-learning:v3` | face/CLIP/OCR models | `/jez-cache/immich/model-cache` (786 MB, **OS SSD**) |
| `immich_postgres` | `ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0` | DB (pgvecto.rs) | `/jez-cache/immich/postgres` (**OS SSD**), `DB_STORAGE_TYPE='HDD'` |
| `immich_redis` | `redis:6.2-alpine` | queue | ephemeral |
| `immich_power_tools` | `ghcr.io/varun-raj/immich-power-tools` | bulk-edit UI, port **8001** | talks straight to the DB |

## 8.2 Library facts (from the live database)

```
assets total ......... 31,975      (29,246 IMAGE + 2,729 VIDEO)
external libraries ... 0           (all assets are uploaded/internal)
users ................ 1           jeremy@poons.com  "Jeremy Poon"
originals size ....... 268 GB      (sum of asset_exif.fileSizeInByte)
DB size .............. 2,233 MB
capture date range ... 1900-01-01 → 2026-09-02   ← some assets have broken EXIF dates
```

`/mnt/storage/jez-photos/` subfolders: `library/`, `upload/`, `thumbs/`,
`encoded-video/`, `profile/`, `takeout/` (Google Photos import staging),
`backups/`.

## 8.3 Backups — this part is done right

`/mnt/storage/jez-photos/backups/` contains Immich's **native nightly DB dump**:

```
immich-db-backup-20260822T020000-v3.0.1-pg14.19.sql.gz   ~253 MB
… one per night …
immich-db-backup-20260906T020000-v3.0.1-pg14.19.sql.gz
```

14 retained, ~250 MB each, generated 02:00, written 12:01. This is Immich's
built-in `BACKUP_DATABASE` feature and it is working. The dumps are the DB
only — the 268 GB of originals are protected only by the mergerfs disk they
happen to sit on (no parity, no offsite).

The stray **`/mnt/immich_db_backup.sql` (4.4 GB, uncompressed, 2026-07-04)** is
a one-off manual dump from before the nightly job existed. Delete it.

## 8.4 Notes

- The `:v3` image tag is unusual (Immich normally tags `release` / `vX.Y.Z`);
  the backup filenames say `v3.0.1`, so this is a real Immich 3.x line.
- `DB_PASSWORD=immich`, `JWT_SECRET=jez_power_tools_2026_security` — trivially
  guessable, and Postgres:5432 is only inside `tm_immich-network` (not
  published), so exposure is limited, but Power-Tools:8001 **is** on
  `0.0.0.0`.

---

# 9. "dash.home2" — the home-energy dashboard

## 9.1 What "dash.home2" is

There is no `.home2` hostname anywhere. "**dash.home2**" is your shorthand for
the **`home-dash2` compose project**, whose code lives in
`~/sigen-dashboard/home.dash2/` (a git repo, `origin =
git@github.com:alc168/home.dash2.git`). The "2" is an internal generation
marker — it is the **second full rewrite** of the Sigenergy dashboard
(`_legacy_v1_unused/` → `v2/` → `home.dash2/`).

It is reached in a browser at **`https://home/`, `https://home.energy/`, or
`https://home.dash/`** — nginx (`/etc/nginx/sites-enabled/sigen-dashboard`)
terminates TLS with the self-signed `home.energy` cert and reverse-proxies to
`127.0.0.1:3000`.

## 9.2 What it does (from its README)

Every 5 minutes it:

1. Reads the **Sigenergy SigenStor** inverter over Modbus/TCP (SOC, solar,
   load, grid flow, charge limits).
2. Pulls wholesale prices from **Amber Electric** for the next 48 half-hours.
3. Predicts whether the battery will be full before the next price peak.
4. If not, and power is cheap now, **charges the battery from the grid**.
5. Renders one web page and sends **WhatsApp alerts** (via a Baileys
   sidecar) when something looks wrong.

It also reads a **Govee** sauna temp sensor, a **Meross** smart plug (surplus-
solar diversion to a Bluetti battery), **UniFi** client counts, and BOM
weather; and it exposes a **family-location view** fed by the Life360 poller.

## 9.3 Runtime (`~/sigen-dashboard/home.dash2/docker-compose.yml`)

| Service | Command | Ports | Notes |
|---|---|---|---|
| `sigen-web` | `python -m sigen_dashboard.web` | `0.0.0.0:3000→3000` | the dashboard UI + control API |
| `sigen-scheduler` | `python -m sigen_dashboard.scheduler` | — | the 5-minute decision loop |
| `sigen-baileys` | Node/Baileys | `0.0.0.0:3002→3001` | WhatsApp gateway |
| `life360-poller` | `Dockerfile.life360-poller` | — | polls Life360's unofficial API, writes `life360.db` |
| `life360-api` | `Dockerfile.life360-api` | `expose 4000` (internal only) | sanitised read API for `sigen-web` |

- Persisted state → `~/sigen-dashboard/data/` (bind mount, **root-owned**):
  `history_v2.db` (30 MB, actively growing — the energy time-series),
  `baileys_auth/` (WhatsApp login), `sauna_config.json`, `topup_config.json`,
  `known_people.json`, `solar_history*.jsonl`.
- `ps` showed `python -m sigen_dashboard.web` (PID 3345) and `.scheduler`
  (PID 3162) as **root** — that is the container processes seen from the host
  PID namespace, **not** a second native copy. There is no systemd unit for
  this app.
- Config comes from `~/sigen-dashboard/.env` (shared with the retired `v2`
  project) and `~/sigen-dashboard/life360.env`. Both contain **cleartext
  personal passwords** (see [§11](#11-exposed-secrets-inventory)).

## 9.4 Orphaned code around dash.home2

`~/sigen-dashboard/` is the single messiest directory on the box. What is
actually in use is **only `home.dash2/`** and the shared `data/`, `.env`,
`life360.env`. Everything else is dead:

| Path | What it is | Status |
|---|---|---|
| `_legacy_v1_unused/` | the original Flask `app.py` (63 KB) + a **195 MB `history.db`** + `secrets.yaml` | dead — keep the DB if it has history you want, else delete |
| `v2/` | previous rewrite, **compose project `v2` still registered, containers `sigen-web`/`sigen-scheduler`/`sigen-baileys` exited 12 days ago** | dead — `docker compose -p v2 down`, delete dir |
| `migration-test/` | a copy of the codebase used for a migration dry-run | dead |
| `data-staging/`, `home.dash2/docker-compose.staging.yml` | staging variant | unused |
| `backups/` (`codex-*`, `pre-git-cutover-*`) | snapshot dirs from before git | superseded by git |
| Root-level `*.md` / `*.pdf` (Architecture, Tutorials, Security Report, …) | ~15 docs, many duplicated in `docs/` and again as `._*` AppleDouble files | consolidate |
| `sigen-cron.log`, `sigen-logger.log` in `~/` | logs from a **retired native-cron** version of the scheduler | delete |
| `glancesweb.service` (systemd, **enabled, failed, crash-looped, gave up 2026-09-03**) | old Glances web UI on `0.0.0.0` as root | disable + delete unit |
| `data/glances_key*` | leftover Glances auth keys | delete |

Docker images still on disk for these: `v2-sigen-*`, `home-dash2-staging-*`,
`homedash2-sigen-scheduler`, `sigen-map-test-*` — ~3.5 GB.

---

# 10. Other application stacks

| Stack | Ports | What it is | Storage | Health |
|---|---|---|---|---|
| **trading-platform** | `127.0.0.1:8092` api, `:8093` ui, `:9108–9110` metrics | 7-service ASX/crypto data & signal platform (collector, api, ui, maintenance, sentiment, macro, equity) + `postgres:17` | `/mnt/NVMe2/trading-platform/{postgres,parquet}` | healthy; **best-hardened stack on the box** (read-only, cap-drop, secrets, limits) |
| **research-agent** | `:4000` litellm, `:8088` searxng, `:8000` gpt-researcher | Zero-cost research pipeline: LiteLLM gateway → free Gemini/Groq/Cerebras keys, SearXNG metasearch, GPT-Researcher orchestrator. Proxied at `https://research.agent` | `~/research-agent/*` | running; **API keys in `~/research-agent/.env`** |
| **territory** | `:8801` backend, `:8802` frontend | News-signal watcher (Google News / GDELT / press releases), SQLite | `~/territory/backend/data` | running; git remote is a **local bare repo only** |
| **vce-psychology** | `:8137` (→ `https://ap.study`) | VCE Psychology revision web app, SQLite + flashcard scheduler, optional AI | Docker volume `vce-psychology_vce-data`; config `/opt/vce/config` or `~/vce-config` | healthy |
| **theownitguy-website** | none local — **Cloudflare tunnel** | Public marketing site (`theownitguy`), served to the internet by `cloudflared` on the `ownitguy-tunnel` network | image build | running; **only publicly-reachable service** |
| **timeline-nas-webapp** | `:4002` | Family timeline from Google Takeout | `~/timeline-nas-webapp/data` | running |
| **bitmappery** | `:5173` | Self-hosted image editor (built from github `igorski/bitmappery`, 3.15 GB image) | Docker volume | running; `bitmappery-init-1` exited(0) — normal |
| **Monitoring** (`~/docker-compose-monitoring.yml`) | `:9090` prometheus, `:3001` grafana, `:9093` alertmanager, `:9130` unpoller, node-exporter | Prometheus (365-day retention) + Grafana + Alertmanager + UniFi Poller | `~/data/{prometheus,alertmanager}`, `~/config/grafana` | running; **Grafana admin password = `admin`** |

---

# 11. Exposed secrets inventory

> These were found in cleartext during the audit. Treat every one as
> compromised-if-the-host-is and rotate. Values below are **masked** — the
> point is *where they live*, so you can fix them.

| Secret | Location | Value (masked) | Risk |
|---|---|---|---|
| Grafana admin password | `~/docker-compose-monitoring.yml` → `~/.env` `GF_SECURITY_ADMIN_PASSWORD` | `admin` | **Critical** — full Grafana on `0.0.0.0:3001` |
| Sigen cloud password | `~/sigen-dashboard/.env` `SIGEN_CLOUD_PASSWORD` | `P15q…n0!` | High — appears to be a reused personal password |
| Meross account password | `~/sigen-dashboard/.env` `MEROSS_PASSWORD` | `Athe…e5!` | High — reused personal password |
| TerraMaster admin password | `~/sigen-dashboard/.env` `TERRAMASTER_PASSWORD` | `tm` | High — NAS admin is `tm`/`tm` |
| TorrentLeech password + 2FA token | `~/config/prowlarr/prowlarr.db` (Indexers.Settings) | `7ac0…8!` / `af5e…dd` | Med — tracker account takeover |
| MyAnonaMouse session token (`MAMID`) | `~/scripts/mam-check.sh` (hard-coded) | `DfJz…oD` (270 chars) | Med — long-lived, auto-spends points |
| Life360 bearer token | `~/sigen-dashboard/life360.env` `LIFE360_ACCESS_TOKEN` | `Bearer NjU4…Vm` | Med — family location data |
| Amber Electric API key | `~/sigen-dashboard/.env` `AMBER_API_KEY` | `psk_9e24…c2` | Low–Med |
| Govee API key | `~/sigen-dashboard/.env` `GOVEE_API_KEY` | `ef97…d9a9` | Low |
| UniFi API key + `prometheus` account pw | `~/sigen-dashboard/.env`, `~/.env` `UP_UNIFI_DEFAULT_PASS` | `Jeov…gK` / `mr8S…lc` | Med — network controller |
| Immich API key / JWT secret / DB pw | `~/.env` | `Zrr…4g` / `jez_power_tools_2026_security` / `immich` | Med |
| Plex claim token | `~/.env` `PLEX_CLAIM` | `claim-53G4…` | Low (claim tokens expire in 4 min) |
| Plex online token | `…/Plex Media Server/Preferences.xml` | present | Med — Plex account access |
| Cloudflare Tunnel token | `~/theownitguy-website/.env` **and** visible in `docker inspect cloudflared` args | `eyJ…Jm` | Med — anyone who can read it can run your tunnel |
| Gemini / Groq / Cerebras keys | `~/research-agent/.env` | `AQ.Ab8…` / `gsk_zg…` / `csk-tx…` | Low–Med |
| autobrr session secret | `~/config/autobrr/config.toml` | `b73e…a4` | Low (service is unconfigured) |
| *arr* API keys | `~/config/{radarr,sonarr,prowlarr}/config.xml` | `e280…01` / `db71…94` / `fe2e…33` | Low (LAN only) |

---

# 12. Security review

| # | Finding | Detail / evidence | Severity |
|---|---|---|---|
| S1 | **No host firewall (verified)** | `iptables -S`: `-P INPUT ACCEPT`; the only INPUT rules are Tailscale's `ts-input` chain. `nft list ruleset` confirms — no LAN filtering at all. `ufw` not installed. Every `0.0.0.0` port is reachable from the whole `/24`. | High |
| S2 | **Grafana `admin`/`admin` on `0.0.0.0:3001`** | `~/.env`; `GF_USERS_ALLOW_SIGN_UP=false` is the only mitigation | High |
| S3 | **Cleartext personal passwords** in `.env` files | [§11](#11-exposed-secrets-inventory); several look reused across accounts | High |
| S4 | **SSH weak, verified.** `sshd -T`: `passwordauthentication yes` (set in `/etc/ssh/sshd_config.d/50-cloud-init.conf`), `permitrootlogin without-password` (root **can** log in with a key), `maxauthtries 6`. `fail2ban` **inactive**. Port 22 on `0.0.0.0`. Login+sudo password for `tm` is **`tm`** (2 chars). 4 keys in `~/.ssh/authorized_keys`. | **High** |
| S5 | **NFS `/mnt/storage` exported RW, no auth, to `192.168.0.0/24`** | `/etc/exports`: `rw,sync,all_squash,anonuid=1000,anongid=1000,insecure,fsid=0` | Medium |
| S6 | **Samba shares `/mnt` (whole tree) RW**; `[homes]` browsable; guest mapping on | `testparm`: `[mnt_tmshare] path=/mnt read only=No`; `usershare allow guests=Yes`; `map to guest=Bad User` | Medium |
| S7 | **arr apps have no auth from LAN** | `AuthenticationRequired=DisabledForLocalAddresses` on Radarr/Sonarr/Prowlarr | Medium |
| S8 | **~25 service ports on `0.0.0.0`** | incl. Immich 2283, Immich Power-Tools 8001, seerr 5055, qbt 8080, radarr 7878, sonarr 8989, prowlarr 9696, searxng 8088, litellm 4000, gpt-researcher 8000, home-dash2 3000, baileys 3002, prometheus 9090, alertmanager 9093 | Medium |
| S9 | **Cloudflare tunnel token in `.env` and process args** | `docker inspect cloudflared` exposes the full token to any local user | Medium |
| S10 | **`glancesweb.service` ran Glances web UI as root on `0.0.0.0`** | now failed (`ModuleNotFoundError: No module named 'defusedxml'` — broken pip install), but still `enabled` — retries on every boot | Low (currently) |
| S11 | **Pending reboot** for `linux-image-6.8.0-139` (running `-138`) | `reboot-required.pkgs`. *(Auto-updates are working — not a finding.)* | Low–Med |
| S12 | **`tm` / `tm` everywhere** | Same 2-char string is the SSH login password, the sudo password, and `TERRAMASTER_PASSWORD` in `.env` (NAS web UI). | High |
| S13 | **Single user, no MFA anywhere**; `tm` is in `sudo` + `docker` + `lxd` | `id`: `sudo,docker,lxd,render` — docker group = root-equivalent | Info |
| S14 | **Immich has no offsite/backup for originals** | 268 GB on one mergerfs disk, no parity | Medium (data-loss, not intrusion) |
| S15 | **No UPS; 35 unclean NVMe shutdowns** | `lsusb` / no `nut`; `nvme smart-log` unsafe-shutdown counters 21 + 14 | Medium–High (data integrity) |
| S16 | **No SMART self-test schedule; alerts go to local `root` mail** | `/etc/smartd.conf` has no `-s` schedule; `-m root` only | Medium (on a no-parity pool) |

**Good, for balance:** no privileged containers; no `docker.sock` mounts;
`iptables` `FORWARD` policy is `DROP` (Docker-managed) and the Tailscale ACL
chain correctly drops tailnet source addresses arriving on non-`tailscale0`
interfaces; Tailscale has **no funnel/serve** (nothing exposed to the internet
via Tailscale); only `theownitguy-website` is public (via Cloudflare, isolated
on its own bridge network); qBittorrent is private-tracker-safe (DHT/PeX/LSD
off); `unattended-upgrades` is on; `fstrim.timer` and `e2scrub_all.timer` run
weekly; the trading-platform stack is genuinely well-hardened; Immich DB is
backed up nightly with 14-day retention; **all 6 pool drives are SMART-clean
with zero reallocated/pending sectors**.

---

# 13. Legacy / orphaned inventory

| Item | Evidence | Action |
|---|---|---|
| Exited containers: `sigen-web`, `sigen-scheduler`, `sigen-baileys` (project `v2`) | `Exited (137) 12 days ago` | `docker compose -p v2 down` |
| Exited containers: `life360-webapp`, `life360-poller` (project `life360-nas-poller`) | `Exited (0) 11 days ago` — replaced by home-dash2's poller | `docker compose -p life360-nas-poller down` |
| **38.3 GB reclaimable images** (97 % of image store) | `docker system df` | `docker image prune -a` |
| **14.9 GB reclaimable build cache** | `docker buildx du` | `docker builder prune` |
| Unused images: `v2-sigen-*`, `home-dash2-staging-*`, `homedash2-sigen-scheduler`, `sigen-map-test-*`, `home-dash2-life360-*`, `life360-nas-poller-*` | `docker images` vs `docker ps -a` | prune |
| Orphan networks: `homedash2_default`, `v2_default`, `life360-nas-poller_default` | `docker network ls` | `docker network prune` |
| `glancesweb.service` — enabled, failed, crash-looped | `systemctl status glancesweb` | `sudo systemctl disable --now glancesweb && sudo rm /etc/systemd/system/glancesweb.service` |
| `/mnt/immich_db_backup.sql` — 4.4 GB, 2026-07-04 | `ls -la /mnt` | delete (nightly gz backups exist) |
| `~/sigen-dashboard/_legacy_v1_unused/history.db` — 195 MB | `ls -la` | keep only if it has history you still want |
| `~/sigen-dashboard/{v2,migration-test,data-staging,backups}` | dirs | archive to a tarball, remove |
| `~/trading-platform-*.bundle` × 9 (~1.5 MB total) | `ls ~/*.bundle` | delete — the GitHub remote is the backup now |
| `~/*.py` / `~/*.sh` loose scripts (`check*.py`, `console*.js`, `topup.py`, `modbus.py`, `deploy_unpoller*.sh`, `extract_devices*.sh`, `get_devices.sh`, `unifi_api_client.py`, …) | `ls ~` | move to `~/scratch/` or a `misc-scripts` repo |
| `~/config/{plex,ntopng}` empty; `~/config/overseerr` vs container name `seerr` | `du -sh ~/config/*` | tidy naming |
| `.DS_Store` and `._*` AppleDouble files throughout `/mnt/storage`, `~/sigen-dashboard` | `find` | `find … -name '._*' -o -name .DS_Store -delete`; set `fruit:veto_appledouble` |
| `~/sigen-dashboard/{sigen-cron.log,sigen-logger.log}` | `ls ~` | delete |
| `/mnt/{das1,das2,scratch,usb_data,remote_usb,nvme1n1p2-scratch,temp}` | mostly empty mountpoints/junk | consolidate to one `/mnt/scratch` |
| `autobrr` container — 0 config | `autobrr.db` all-zero | configure or `docker compose` remove |
| Plex "F1" library extra path `/mnt/NVMe2` | `section_locations` | remove that path in Plex |
| `qBittorrent.conf` `Preferences\Downloads\SavePath=/mnt/disk2/temp/` | contradicts `Session\DefaultSavePath` | reconcile to one path |

---

# 14. GitHub review — what is (and isn't) replicated

No `gh` CLI, no `~/.gitconfig`. GitHub account: **`alc168`**
(`github.com/alc168`). Auth is via SSH keys, including a dedicated host alias
`github-trading-platform` (a per-repo deploy key).

## 14.1 Repos on the box

| Local path | Remote | Branch | Working tree | On GitHub? |
|---|---|---|---|---|
| `~/sigen-dashboard/home.dash2` | `git@github.com:alc168/home.dash2.git` | **detached HEAD @ `cbfe0ef`** | clean | **Yes** — `origin/main` present; HEAD not ahead of it |
| `~/trading-platform` | `git@github-trading-platform:alc168/trading-platform.git` | `main` | clean, up to date | **Yes** — has CI (`.github/`), PR #1 merged |
| `~/hybrid-research` | `github.com/alc168/hybrid-research.git` | `main` | clean | **Yes** |
| `~/life360-nas-poller` | `github.com/alc168/life360-nas-poller` | `main` | **32 modified files, uncommitted** | Yes, but local has drifted; project is retired |
| `~/territory` | `/home/tm/git/territory.git` (**local bare repo only**) | `main` | clean | **No** — not on GitHub. Has `RECOMMENDATIONS.md` from a 2026-09-06 review |
| `~/mergerfs-tools` | `github.com/trapexit/mergerfs-tools.git` | `master` | clean | third-party clone |

## 14.2 What is **NOT** in version control at all

Everything that actually defines this server:

- `~/docker-compose.yml` (the whole media + Immich + Plex stack)
- `~/docker-compose-monitoring.yml`
- `~/config/*` (Radarr/Sonarr/Prowlarr/qBittorrent/Plex/Grafana/Prometheus/…)
- `~/research-agent/`, `~/theownitguy-website/`, `~/timeline-nas-webapp/`,
  `~/vce-psychology/`
- `~/sigen-dashboard/` top level (only the `home.dash2/` subdir is a repo)
- `/etc/nginx/sites-*`, `/etc/exports`, `/etc/samba/smb.conf`, `/etc/fstab`,
  the systemd units, `crontab`, `~/scripts/`

If the OS SSD dies you can rebuild the *data* (mostly) but you would be
reconstructing the *configuration* from memory. See Recommendation 1.

## 14.3 Documentation that exists

`~/sigen-dashboard/` is heavily documented (README 30 KB, AGENTS.md,
ARCHITECTURE.md, a 56 KB Architecture-Reference-Proposal, tutorials, a
Home-Network-Security-Report .md+.pdf, plus `docs/` duplicates and `._*`
AppleDouble copies). `home.dash2/README.md` is a genuine self-contained
tutorial. `trading-platform` has `docs/` and CI. Nothing else has a README.

---

# 15. Recommendations — one by one

Ordered: **A = security (do first, ~1 evening)**, **B = robustness / backup**,
**C = cleanup**, **D = filesystem re-sort**. Each is independent unless noted.

## A. Security

**A1 — Change the Grafana admin password now.**
`~/.env`: set `GF_SECURITY_ADMIN_PASSWORD` to a real secret, then
`cd ~ && docker compose -f docker-compose-monitoring.yml up -d grafana`.
Log in, delete the old default. *(2 min, removes the single worst finding.)*

**A2 — Put a host firewall in front of everything.**
```bash
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 192.168.0.0/24 to any port 22,80,443,445,2049,32400,2283,5055,3000,3001 proto tcp
sudo ufw allow in on tailscale0
sudo ufw enable
```
Then decide, service by service, which of the ~25 open ports actually need to
be on the LAN vs. only reachable over Tailscale. Anything that is "just for
me" (Prometheus 9090, Alertmanager 9093, litellm 4000, gpt-researcher 8000,
power-tools 8001, baileys 3002, qbt 8080, radarr/sonarr/prowlarr) should be
Tailscale-only.

**A3 — Harden SSH and change the `tm` password.** First:
`sudo passwd tm` → a real passphrase (it is currently `tm`, and that is also
your sudo password). Then, because `/etc/ssh/sshd_config.d/50-cloud-init.conf`
sets `PasswordAuthentication yes`, override it in
`/etc/ssh/sshd_config.d/99-hardening.conf` (later file wins):
```
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers tm
```
`sudo systemctl restart ssh` (verify with `sudo sshd -T | grep -E
'passwordauthentication|permitrootlogin'`). You already authenticate with a
key. Then either install `fail2ban` (`sudo apt install fail2ban`, default jail
is fine) or, better, stop exposing 22 to the LAN at all and reach the box over
Tailscale SSH.

**A4 — Rotate the secrets in [§11](#11-exposed-secrets-inventory)**, starting
with the ones that are reused personal passwords (`SIGEN_CLOUD_PASSWORD`,
`MEROSS_PASSWORD`) and `TERRAMASTER_PASSWORD=tm`. Give the NAS admin account a
real password. Move secrets out of `.env` files into either Docker secrets
(as the trading-platform stack already does) or at minimum `chmod 600` +
`.gitignore` verified for every `.env`.

**A5 — Turn on auth for the *arr* apps.** Set
`AuthenticationRequired=Enabled` (not `DisabledForLocalAddresses`) in each
`config.xml`, or front them with a single authenticating reverse proxy. Same
for qBittorrent WebUI (it already has a password; make sure `WebUI\Address`
is not `*` once behind the proxy).

**A6 — Lock down NFS and Samba.** NFS: export read-only, and to specific host
IPs, not the whole `/24` — e.g.
`/mnt/storage 192.168.0.50(ro,sync,no_subtree_check,root_squash)`. Samba:
scope `[mnt_tmshare]` to a specific subtree (e.g. `/mnt/storage`) instead of
all of `/mnt`, set `usershare allow guests = No`, and confirm `map to guest`
is intentional.

**A7 — Reboot the box** into `linux-image-6.8.0-139` (pick a low-use window;
`sudo reboot`). `unattended-upgrades` is already enabled, so this is the only
outstanding update action. Consider adding
`Unattended-Upgrade::Automatic-Reboot "true";` with a 04:00 window in
`/etc/apt/apt.conf.d/50unattended-upgrades` so kernel patches don't sit
unbooted for weeks.

**A8 — Disable the dead Glances unit** so it does not resurrect on reboot:
`sudo systemctl disable --now glancesweb.service && sudo rm /etc/systemd/system/glancesweb.service`.

**A9 — Cloudflare tunnel:** confirm the Zero-Trust dashboard only routes the
one hostname to `theownitguy` and that no path maps back to other NAS ports.
Regenerate the tunnel token (it has been on disk in cleartext and in
`docker inspect`).

## B. Robustness & backup

**B1 — Put the server config in git.** Create `alc168/nas-config` (private).
Track: `~/docker-compose*.yml`, every app dir's `docker-compose.yml` +
`*.example` env (never the real `.env`), `~/scripts/`, and copies of
`/etc/nginx/sites-available/*`, `/etc/exports`, `/etc/samba/smb.conf`,
`/etc/fstab`, `crontab -l`, the systemd unit files. A `Makefile` or
`bootstrap.sh` that recreates the layout. This is the single highest-value
robustness change.

**B2 — Fix the `home.dash2` detached HEAD:**
```bash
cd ~/sigen-dashboard/home.dash2
git checkout main && git pull --ff-only
```
and confirm `cbfe0ef` is already on `origin/main` (it appears to be). Add a
pre-deploy check that refuses to build from a detached HEAD.

**B3 — Commit or discard the 32 dirty files in `~/life360-nas-poller`**, then
—since the project is retired—archive the repo on GitHub and
`docker compose -p life360-nas-poller down --rmi local`.

**B4 — Push `territory` to GitHub** (it only exists as a local bare repo at
`~/git/territory.git` — one disk failure from gone).

**B5 — Protect the Immich originals.** 268 GB is small enough for an
inexpensive offsite: `rclone` to a cloud bucket (Backblaze B2 / Storj) on a
weekly cron, or an external USB drive rotated monthly. The nightly DB dump is
worthless without the photos.

**B6 — Add a restic/borg job for the irreplaceable small stuff:**
`~/sigen-dashboard/data/history_v2.db`, `~/config/*` (minus Plex's 31 GB
`Library/`), the trading Postgres, `territory.db`, `vce-data`. Target
`/mnt/storage/backups/` **and** offsite.

**B7 — Right-size logging.** Set `LogLevel` back to `info` on Radarr, Sonarr,
Prowlarr (reclaims most of the 2.3 GB / 422 MB / 42 MB). Add
`logging: {driver: json-file, options: {max-size: 10m, max-file: 3}}` to every
service in `~/docker-compose.yml` (the trading and home-dash2 stacks already
do this).

**B8 — Add swap headroom or RAM.** 7.5 GiB with this many resident services
means constant swapping. Either bump the box to 16 GiB (an N95 typically
takes a single SO-DIMM up to 16 GiB) or shut down the stacks you rarely use
(see C1).

**B9 — Consider parity for the media pool.** mergerfs + **SnapRAID** gives you
one- or two-disk parity for the 47 TB of media without converting to a real
RAID. Even one parity disk turns "lost a disk = lost those movies" into "lost
a disk = rebuild". A weekly `snapraid sync` + monthly `snapraid scrub` timer
also gives you bit-rot detection the pool currently has none of.

**B10 — Buy a small UPS and wire up NUT.** The NVMe SMART logs show **35
unclean shutdowns**. A ~600–900 VA UPS + `sudo apt install nut`, configured
for a clean shutdown at ~50 % battery, protects the two Postgres instances,
the dozen SQLite DBs, and the ext4 filesystems from the power cuts that are
already happening. This is the highest-value robustness spend on the box.

**B11 — Schedule SMART self-tests and real alerting.** Append to
`/etc/smartd.conf` (then `sudo systemctl restart smartmontools`):
```
/dev/sda -a -o on -S on -s (S/../.././02|L/../../6/03) -W 4,45,55 -m <you@email> -M exec /usr/share/smartmontools/smartd-runner
# …one line per /dev/sd[a-f] and /dev/nvme[01]…
```
(short test nightly 02:00, long test Saturday 03:00, temperature warnings).
Point `-m` at an address that reaches you, or a script that pings the
Alertmanager you already run. Add a Prometheus `smartctl_exporter` /
`node_exporter --collector.smartmon` panel so drive health shows up in
Grafana next to everything else.

**B12 — Pre-empt `disk2` (sdb, 45,600 h / 5.2 yr).** It is SMART-clean but
statistically the first to go, and the pool has no parity. Either buy a cold
spare now, or plan a `mergerfs` drain of that disk
(`mergerfs.balance` / manual `rsync` off, then swap) at the next
maintenance window. While you are in there, note `disk1` (sda) is an **SMR**
drive — fine for cold media, bad as a torrent-write target; steer new
`category.create` writes away from it or replace it.

## C. Cleanup (safe, reversible)

**C1 — Decide which stacks are keepers.** Running today but arguably idle:
`research-agent` (3 containers, 4.7 GB gpt-researcher image), `territory`,
`timeline-nas-webapp`, `bitmappery` (3.15 GB image), `theownitguy-website`.
Each one you stop frees RAM and a port. `docker compose -p <name> stop` is
instant and reversible.

**C2 — Prune Docker.** After C1:
```bash
docker compose -p v2 down
docker compose -p life360-nas-poller down
docker container prune
docker image prune -a          # ~38 GB
docker builder prune           # ~15 GB
docker network prune
```
Expect ~50 GB back on `/`.

**C3 — Delete the stray dumps & bundles.**
`rm /mnt/immich_db_backup.sql` (4.4 GB), `rm ~/trading-platform-*.bundle`,
`rm ~/sigen-dashboard/{sigen-cron.log,sigen-logger.log}`.

**C4 — Collapse `~/sigen-dashboard`.** Keep `home.dash2/`, `data/`, `.env`,
`life360.env`, and *one* copy of the docs (in the `home.dash2` repo). Tar the
rest (`_legacy_v1_unused`, `v2`, `migration-test`, `data-staging`, `backups`,
loose root `*.md`/`*.pdf`) to `~/archive/sigen-dashboard-legacy-2026-09.tar.zst`
and delete the originals. Extract `_legacy_v1_unused/history.db` first if you
want the old history.

**C5 — Sweep AppleDouble litter.**
```bash
find /mnt/storage ~/sigen-dashboard -name '._*' -o -name '.DS_Store' -delete
```
and set `fruit:veto_appledouble = yes` in `smb.conf` to stop it recurring.

**C6 — Tidy loose `~` scripts** into `~/scripts/` (or a `misc-scripts` repo)
and out of `$HOME`: `check*.py`, `console*.js`, `costs.py`, `investigate.py`,
`modbus.py`, `row.py`, `sim_test.py`, `topup.py`, `deploy_unpoller*.sh`,
`extract_devices*.sh`, `get_devices.sh`, `enhanced_unifi_client.py`,
`simple_unifi_client.py`, `unifi_api_client.py`, `add_monitoring.py`,
`create_compose.sh`, `device_summary.sh`, `fix_unpoller_endpoint.sh`,
`unpoller_dreamwall.sh`.

**C7 — Remove `docker-compose*.yml.bak*` / `.backup`** from `~` once B1 is
done (git is the history now).

**C8 — Either configure `autobrr` or remove it.** If you want instant TL
grabs: add the TorrentLeech IRC network + announce channel, a filter, and a
qBittorrent action. Otherwise delete the service from `~/docker-compose.yml`.

**C9 — Fix the Plex "F1" library** — remove the `/mnt/NVMe2` path
(Settings → Libraries → F1 → Edit → remove folder).

## D. Filesystem re-sort

**D1 — Move Immich onto the NVMe it was bought for.** `/mnt/NVMe2` (932 GB,
2 % used) is literally labelled "for Photos" in `/etc/fstab`. Plan:
1. `docker compose stop immich-server immich-machine-learning immich-microservices database redis`
2. `rsync -aH /jez-cache/immich/ /mnt/NVMe2/immich/` (DB data + model cache)
3. Move the 268 GB of originals:
   `rsync -aH --info=progress2 /mnt/storage/jez-photos/ /mnt/NVMe2/immich/upload/`
   *(268 GB + thumbs/encoded fits comfortably in 932 GB)*
4. Repoint the bind mounts in `~/docker-compose.yml`
   (`/mnt/NVMe2/immich/upload:/usr/src/app/upload`,
   `/mnt/NVMe2/immich/postgres:/var/lib/postgresql/data`,
   `/mnt/NVMe2/immich/model-cache:/cache`) and set `DB_STORAGE_TYPE='SSD'`.
5. `docker compose up -d`, verify, then remove the old dirs.
Result: photo scrubbing/thumbnails/ML get NVMe random-IO, the OS SSD gets
~3 GB back, and the mergerfs pool gets ~300 GB back.

**D2 — Give Plex its own config root.** Change the compose mount from
`./config:/config` to `./config/plex:/config` (or a dedicated
`~/plex-config`), migrate
`~/config/Library/` → the new location, so a backup or `chown` of `~/config`
no longer drags 31 GB of Plex thumbnails and Plex is not sharing a directory
with six other apps.

**D3 — Reconcile the torrents area (the 7.6 TB).** In Radarr and Sonarr
enable **Settings → Media Management → "Use Hard Links instead of Copy"**.
Then audit `/mnt/storage/torrents`:
```bash
# entries with only one hardlink = not linked into the library = candidates
find /mnt/storage/torrents -type f -links 1 -size +100M -printf '%k KB\t%p\n' | sort -rn | head -50
```
Cross-check against qBittorrent's active-seeding list. Anything not seeding
for ratio and already in the library can go. Set a qBittorrent
**share-limit** (ratio or seed-time) with "remove torrent and files" so this
does not rebuild.

**D4 — One scratch dir.** Replace `/mnt/{temp,scratch,usb_data,remote_usb,nvme1n1p2-scratch}`
and `/mnt/das1`, `/mnt/das2` with a single `/mnt/scratch` (and delete the
commented DAS lines from `/etc/fstab` if the D4-320 enclosure is gone).

**D5 — Normalise the download taxonomy.** qBittorrent has `new movies`,
`new tv`, `tv`, `radarr`, `tv-sonarr` categories pointing at four different
paths (`/mnt/storage/data/movies`, `/mnt/storage/data/tv`,
`/mnt/storage/torrents`). Pick one convention: `radarr` →
`/mnt/storage/torrents/movies`, `tv-sonarr` → `/mnt/storage/torrents/tv`,
delete the rest, and update `Session\DefaultSavePath` and the stale
`Preferences\Downloads\SavePath` to match.

**D6 — Move `~/config` app data that is really *state* off the OS SSD** only
if `/` gets tight — at 12 % it is fine for now. The bigger win is D1.

---

# Appendix A — full container list (running)

```
IMMICH:      immich_server(2283) immich_machine_learning immich_postgres
             immich_redis immich_power_tools(8001)
MEDIA:       plex2(host) qbt-tl(host:8080) sonarr(host:8989) radarr(host:7878)
             prowlarr(host:9696) autobrr(host:7474) seerr(5055) kometa
MONITORING:  prometheus(9090) grafana(3001) alertmanager(9093)
             unpoller(9130) node_exporter
HOME-DASH2:  home-dash2-sigen-web-1(3000) home-dash2-sigen-scheduler-1
             home-dash2-sigen-baileys-1(3002) home-dash2-life360-api-1
             home-dash2-life360-poller-1
TRADING:     trading-platform-{postgres,api(8092),ui(8093),collector(9108),
             sentiment(9109),macro(9110),equity,maintenance}-1
WEB APPS:    territory-{frontend(8802),backend(8801)}-1  vce-psychology(8137)
             theownitguy-website  cloudflared  timeline-webapp(4002)
             bitmappery(5173)
RESEARCH:    gpt-researcher(8000) searxng(8088) litellm(4000)
```

# Appendix B — evidence files

Raw command output captured during the audit is in the working directory
alongside this report (`01-disk-mounts` … `15-photos`). Key sources:
`docker ps -a`, `docker compose ls -a`, `docker inspect`, `docker system df`,
`/etc/fstab`, `/etc/exports`, `testparm -s`, `ss -tulpn`, `crontab -l`,
`~/docker-compose.yml`, `~/docker-compose-monitoring.yml`,
`~/sigen-dashboard/home.dash2/docker-compose.yml`, `prowlarr.db` / `radarr.db`
/ `sonarr.db` / `autobrr.db` queries, `com.plexapp.plugins.library.db`
queries, Immich Postgres queries, `git remote -v` across all repos.
