# PROGRESS / handoff log — `terramaster`

Newest entry first. Update this file as you work, then
`git commit -am '…' && git push origin main && git push mirror main`.

---

## Current state (as of 2026-09-16)

- **Logging stack is live** (2026-09-16): Loki + Grafana Alloy in the `tm` compose
  project, CrowdSec as a host package. ~420 MB total. See "DONE 2026-09-16" below.
  **Outstanding:** the Dream Wall is not yet sending syslog - that is a UI step for
  the user (Settings -> Control Plane -> Integrations -> Activity Logging ->
  192.168.0.172:514).

## Earlier state (as of 2026-09-15)

- **theownitguy-website**: **decommissioned 2026-09-15.** The public site
  (`ownitguy.com.au`) is now hosted elsewhere, not on this box. Containers,
  built image, compose folder and the `ownitguy-nas` Cloudflare tunnel are gone.
  `lac-evidence-lens` (floris), also published via that tunnel, is being retired. See IN PROGRESS.

- **Immich** (as of 2026-09-08): migrated onto `/mnt/NVMe2` (DB + model-cache + 368 GB library).
  Healthy, verified. **Old copies still on disk pending soak** — see IN PROGRESS.
- **mergerfs pool**: whole — 66 TB, all 6 disks. `/etc/fstab` race patched
  2026-09-08 (not yet tested across a reboot).
- **nas-admin repo**: created this session; holds the audit, runbooks, all
  compose files, env templates, `/etc` reference copies, scripts.
- **Everything else**: as described in `docs/audits/2026-09-06-terramaster-audit.md`.
  The security A-list from that audit is still almost entirely open.

---

## IN PROGRESS / pending verification

### lac-evidence-lens (floris) — being removed, final deletes pending (2026-09-15)
User chose to retire it. Cloudflare Access app removed by user; the `floris`
DNS record (CNAME to the deleted tunnel, returns error 1033) should also be deleted.
**Done:** `docker compose --profile tools down`; removed network
`theownitguy-website_ownitguy-tunnel`. Rollback archives (no `.env`) in `~/archives/`:
`lac-evidence-lens-source-2026-09-15.tgz`, `lac-evidence-lens-data-volume-2026-09-15.tgz`.
**Still to run (agent harness blocked these deletes):**
```
docker image rm lac-evidence-lens-lac-evidence-lens lac-evidence-lens-ingest
docker volume rm lac-evidence-lens_lac-data lac-evidence-lens_lac-claude-config
rm -rf ~/lac-evidence-lens
```
Then revoke the secrets its `.env` held: `CLAUDE_CODE_OAUTH_TOKEN` and `GEMINI_API_KEY`.

### Immich migration cleanup (blocked on soak)
Migration done 2026-09-08 ~14:52 (~18 min downtime). Verified: 32018 assets,
pgvector intact, thumbnail API 200, 0 failed jobs, DB `data_directory` on NVMe2.

**Old data retained as the rollback path — DO NOT DELETE until soak passes:**
| Path | Size | Filesystem |
|---|---|---|
| `/mnt/storage/jez-photos` | ~369 GB | mergerfs pool |
| `/jez-cache/immich` | 5.4 GB | OS SSD `/` |

**Soak check (after 24–48 h of normal use + one nightly job cycle):**
```
curl -s http://192.168.0.172:2283/api/server/ping
docker exec immich_postgres psql -U postgres -d immich -tAc "select count(*) from asset"
curl -s -H "x-api-key: <IMMICH_API_KEY from ~/.env>" http://192.168.0.172:2283/api/jobs \
  | python3 -m json.tool | grep -E '"failed"'      # all 0
ls -la /mnt/NVMe2/immich/upload/backups/            # a fresh nightly dump present
```
**If good, reclaim the space (run singly — batched rm/prune gets auto-blocked):**
```
echo tm | sudo -S rm -rf /jez-cache/immich
echo tm | sudo -S rm -rf /mnt/storage/jez-photos
```
**Rollback (if Immich is unhappy):**
```
cd ~ && cp docker-compose.yml.bak.premigrate.20260908-145232 docker-compose.yml
docker compose -f docker-compose.yml up -d immich-server immich-machine-learning immich-power-tools redis database
```
(old paths: `/mnt/storage/jez-photos`, `/jez-cache/immich/{postgres,model-cache}`)

---

## DONE 2026-09-16 - log collection + CrowdSec

Goal: a searchable record of what happened, kept off the machines that generate it,
on a 7.5 GiB box. Wazuh was rejected (needs 8 GB alone) - see the memory note below.

**Loki** (`grafana/loki:latest`, service `loki` in `docker-compose-monitoring.yml`)
- Config `~/config/loki/loki-config.yaml`; data on **`/mnt/NVMe2/loki`** (539 GB free),
  deliberately not the OS SSD.
- TSDB schema v13, filesystem store, **90-day retention** via the compactor.
- Host port bound to **127.0.0.1:3100** only; Grafana reaches it over `tm_monitoring`.

**Alloy** (`grafana/alloy:latest`, service `alloy`, runs as root)
- Config `~/config/alloy/config.alloy`. Three sources:
  1. **syslog** - container listens on 1514, host publishes **514/udp + 514/tcp**
     (RFC3164, for the Dream Wall). Verified with a hand-sent test message.
  2. **docker** - every container via the socket, labelled `container`,
     `compose_project`, `stream`.
  3. **journal** - `/var/log/journal`: sshd, sudo, systemd, kernel. rsyslog is NOT
     installed on this box, so there is no `/var/log/auth.log`; journald is the only
     host log source.
- Gotcha: `loki.source.journal` labels streams with the component id unless a relabel
  rule sets `job` - hence the explicit rule in the config.
- First start replays historical container logs; Loki rejects anything older than
  `reject_old_samples_max_age` (168h) with HTTP 400. One-time and harmless.

**Grafana**
- Loki datasource added by **provisioning file**
  `~/config/grafana-provisioning/datasources/loki.yaml` (mounted read-only), not the
  API: the admin password in `~/.env` no longer matches the running instance, so API
  auth returns 401. Audit finding A1 may therefore be partly addressed; the real
  password is not known to this repo.

**unpoller**
- `UP_LOKI_URL=http://loki:3100` added so UniFi events/alarms/anomalies/IDS hits reach
  Loki. **BUT** unpoller cannot authenticate to the controller:
  `https://192.168.0.250/api/auth/login` returns 500 "authentication failed" for user
  `prometheus`, and only 2 `unpoller_` metrics are exposed. This predates today's
  change (it was serving a "last good snapshot"). **Open task:** fix or recreate that
  local UniFi account. Until then UniFi data arrives only via syslog.

**CrowdSec** (host package, NOT a container - the image has no `journalctl`, and with
no auth.log on this box a container cannot read host logs)
- Official packagecloud repo (Ubuntu universe only carries 1.4.6); installed **1.8.1**.
- LAPI moved to **127.0.0.1:8090** - port 8080 is qbittorrent-nox.
- Acquisition `/etc/crowdsec/acquis.d/journald.yaml`: `ssh.service` + syslog facility 10.
- Whitelist `/etc/crowdsec/parsers/s02-enrich/lan-whitelist.yaml`: LAN, Docker,
  Tailscale, loopback - so it can never ban you off your own network.
- **Detect-only: no bouncer installed.** Nothing is blocked yet. Deliberate: there is
  no host firewall, and a bad rule could lock out SSH.
- Verified: the ssh.service source reads and parses; the whitelist fires on LAN IPs.

**Memory after all of this** (the constraint behind every choice):
`loki` ~125 MB + `alloy` ~121 MB + `crowdsec` ~172 MB = **~420 MB**, against ~4.1 GB
available. Wazuh alone wanted 8 GB. The F6-424 has 2 SO-DIMM slots (64 GB max) if that
ever needs revisiting.

**Next:**
- User: point the Dream Wall's Activity Logging at `192.168.0.172:514`, and enable the
  free-tier Intrusion Prevention.
- Grafana alert rules: failed SSH, new SSH key, unexpected container start, IPS hit,
  sudden drop in log volume.
- Decide on a CrowdSec bouncer once a host firewall exists.
- Back up `/mnt/NVMe2/loki` off-box, so the logs outlive the machine they describe.

---

## DONE 2026-09-15 — theownitguy-website decommissioned

Site moved off-box (`ownitguy.com.au` verified serving different content;
the NAS nginx had logged 0 requests).
- User: `docker compose down --rmi local` in `~/theownitguy-website`; deleted
  Cloudflare tunnel **ownitguy-nas** (`8a01d73e-…`), which invalidates its token.
- Archived the source without `.env` → `~/theownitguy-website-archive-2026-09-15.tgz`
  (24 files), then `rm -rf ~/theownitguy-website`.
- Removed the tunnel token that had leaked into `~/.bash_history`.
- Removed `compose/theownitguy-website/` and `env-examples/theownitguy-website.env.example`
  from this repo.
- `docker builder prune -f` (reclaimed 22.65 GB of build cache).
- The other tunnel, `local-expert-system-cloudflared` (`10f5fef7-…`, created
  2026-09-11, after the audit), is unaffected. It **still passes its token on the
  command line** (visible in `docker inspect`) and runs cloudflared 2026.7.3.

---

## DONE this session (2026-09-06 → 2026-09-08)

### Audit
- Full infra audit → `docs/audits/2026-09-06-terramaster-audit.{md,pdf}`
  (storage, Docker, arr stack, TorrentLeech/MAM, Plex, Immich, dash.home2,
  other stacks, secrets inventory §11, security findings §12, legacy §13,
  GitHub §14, recommendations §15). Root-verified addendum: SMART table (all
  6 disks clean), firewall (none — `iptables -P INPUT ACCEPT`), SSH
  (`PasswordAuthentication yes`), no UPS + 35 unclean NVMe shutdowns.

### Git / GitHub migration
- Added account SSH key `~/.ssh/id_ed25519` to GitHub profile (`alc168`).
- Created **`nas-admin`** repo → `github.com/alc168/nas-admin` (private) +
  on-box mirror `~/git/nas-admin.git`. Populated with compose/, env-examples/,
  etc/, scripts/, MANIFEST.md, the audit, and the folded-in `~/docs` runbooks.
- `home.dash2`: removed a read-only `core.sshCommand` deploy-key override that
  blocked pushes; reattached detached HEAD to `main`.
- `trading-platform`: moved off the `github-trading-platform` deploy-key alias
  onto the account key.
- `hybrid-research`: GitHub remote was gone (repo deleted) → pointed at a new
  on-box mirror `~/git/hybrid-research.git`.
- Trimmed `~/.ssh/config` to one `Host github.com` block; deleted the 3 unused
  deploy keys.

### fstab / boot reliability (2026-09-08)
- Root cause of the 2026-09-07 10-hour degraded pool: `mnt-storage.mount` had
  **no dependency** on the individual `/mnt/diskN` mounts (the `/mnt/disk*`
  glob is opaque to systemd), so it assembled from whatever was mounted at
  that instant (5 of 6).
- Fix applied to `/etc/fstab` (backups: `/etc/fstab.bak.20260907-*`):
  - 6 disk lines: `+x-systemd.device-timeout=90,x-systemd.mount-timeout=120`
  - mergerfs line: `+nofail` `+x-systemd.requires-mounts-for=/mnt/disk1..6`
  - Net: pool now hard-requires all 6 branches; a missing disk => pool doesn't
    mount at all (loud) instead of silently partial; box still boots.
- **Untested across a reboot.** Synced to `etc/fstab` here (commit `1d272a3`).

### Immich migration — see IN PROGRESS above.

---

## OPEN / NEXT (priority order — from audit §14)

### Security (only the user can do most of these)
- **A1** Grafana admin password is `admin` on `0.0.0.0:3001` — change it.
- **A3** `sudo passwd tm` (currently `tm`); then override the cloud-init
  `PasswordAuthentication yes` with `/etc/ssh/sshd_config.d/99-hardening.conf`
  (`PasswordAuthentication no`, `PermitRootLogin no`, `AllowUsers tm`).
- **A2** No host firewall. Install `ufw`, default-deny inbound, allow LAN only
  to the handful of ports actually used; rest via Tailscale.
- **A4 / A9** Rotate the cleartext secrets in audit §11 (start with reused
  personal passwords `SIGEN_CLOUD_PASSWORD`, `MEROSS_PASSWORD`,
  `TERRAMASTER_PASSWORD`). ~~Regenerate the theownitguy tunnel token~~, done
  2026-09-15 (tunnel deleted). The `local-expert-system` tunnel token is still exposed in `docker inspect`.
- **A5** arr apps have no auth from LAN (`DisabledForLocalAddresses`).

### Robustness
- **B10** Buy a UPS + `nut`. Power was lost unattended 2026-09-07 03:55.
  **Nothing should reboot this box until there's one.**
- **B11** `/etc/smartd.conf` has no self-test schedule; alerts go to unread
  local root mail. Add `-s (S/../.././02|L/../../6/03)` + a real `-m` target.
- **B12** `disk2` (sdb) is 45,600 h / 5.2 yr, SMART-clean but oldest; no
  parity. Cold spare or pre-emptive swap. `disk1` (sda) is SMR.
- **B9** SnapRAID parity for the 47 TB pool (currently zero redundancy).
- **B5/B6** Offsite backup for the 268 GB Immich originals + small DBs.
- **B7** arr `LogLevel` is `debug` (~2.5 GB of logs) → `info`.

### Cleanup (safe, mechanical — several were handed to the user, may be undone)
- Disable `glancesweb.service` (fails on missing `defusedxml`, retries each boot).
- `rm /mnt/immich_db_backup.sql` (4.4 GB stray dump; nightly gz backups exist).
- `docker compose -p v2 down` + `-p life360-nas-poller down`, then
  `docker image prune -a` / `builder prune` (~40–50 GB).
- Sweep `.DS_Store` / `._*` from `/mnt/storage`; set `fruit:veto_appledouble`.
- `~/config/*` (arr `config.xml` API keys, `prowlarr.db` TL creds, 31 GB Plex
  metadata) still **not** in `nas-admin` — needs a curated redacted export.
- `life360-nas-poller` working tree has 32 uncommitted files; project retired.

### Bigger, needs a plan
- **D3** Reconcile the 7.6 TB `/mnt/storage/torrents` (hardlinks vs copies).
- **D2** Give Plex its own config root (currently `./config` = all of `~/config`).

---

## Landmines / gotchas

- **No UPS.** Unclean power loss on 2026-09-07 (~03:55, no logged cause —
  user to physically check power/PSU/outlet).
- **No parity** on the 66 TB mergerfs pool. A dead disk = its files gone.
- sudo password = `tm`; SSH password auth on; no fail2ban; ~25 ports on
  `0.0.0.0` with no firewall.
- Harness auto-blocks destructive command batches — run `rm`/`prune`/
  `systemctl` singly or hand to the user.
- `du /mnt/storage/*` times out — don't rely on it.
- `home.dash2` had a repo-local `core.sshCommand` override; watch for the same
  pattern (`git config --local --get core.sshCommand`) in other repos.
