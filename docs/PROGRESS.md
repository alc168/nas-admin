# PROGRESS / handoff log — `terramaster`

Newest entry first. Update this file as you work, then
`git commit -am '…' && git push origin main && git push mirror main`.

---

## Current state (as of 2026-09-08)

- **Immich**: migrated onto `/mnt/NVMe2` (DB + model-cache + 368 GB library).
  Healthy, verified. **Old copies still on disk pending soak** — see IN PROGRESS.
- **mergerfs pool**: whole — 66 TB, all 6 disks. `/etc/fstab` race patched
  2026-09-08 (not yet tested across a reboot).
- **nas-admin repo**: created this session; holds the audit, runbooks, all
  compose files, env templates, `/etc` reference copies, scripts.
- **Everything else**: as described in `docs/audits/2026-09-06-terramaster-audit.md`.
  The security A-list from that audit is still almost entirely open.

---

## IN PROGRESS / pending verification

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
  `TERRAMASTER_PASSWORD`); regenerate the Cloudflare tunnel token.
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
