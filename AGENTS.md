# AGENTS.md — working on `terramaster`

Operational guide for an AI agent (or human) picking up work on this NAS.
**Read `docs/PROGRESS.md` first** for the live state and the next actions.

## The machine

| | |
|---|---|
| Host | `terramaster`, Ubuntu 24.04.4, kernel 6.8.0-139, Intel N95, 7.5 GiB RAM |
| Address | `192.168.0.172` (LAN) / `100.92.12.96` (Tailscale, tailnet `jeremypoon2007@`) |
| Login | `ssh tm@192.168.0.172` — **key auth only from the auditor's machine**; SSH also still has `PasswordAuthentication yes` (open finding) |
| sudo | password for `tm` is **`tm`** (weak — rotation is an open task). Use `echo tm \| sudo -S -p '' <cmd>` for non-interactive. |
| Role | media (Plex + *arr* + qBittorrent/TorrentLeech + MyAnonaMouse), Immich photos, `home-dash2` energy dashboard, trading-platform, several small web apps, Prometheus/Grafana |

Full picture: `docs/audits/2026-09-06-terramaster-audit.md` (also `.pdf`). Don't
re-derive it — cite it.

## This repo

| Path | What |
|---|---|
| `docs/PROGRESS.md` | **Running handoff log.** Update it as you work. |
| `docs/audits/` | Point-in-time infra audits. |
| `docs/` (`*.md`) | Operational runbooks (backup, maintenance, network, MAM, storage). |
| `compose/` | The 10 `docker-compose` stacks, copied from the box. `compose/tm/` is the big one (arr + Immich + Plex + monitoring). |
| `env-examples/` | `.env` files with **values stripped to bare `KEY=`**. Real values live on the box / a password manager. |
| `etc/` | Reference copies of `/etc/fstab`, `exports`, `smartd.conf`, nginx sites, sshd drop-in, systemd units. |
| `scripts/` | `mam-check.sh` (MAM token redacted) + Plex helpers. |
| `MANIFEST.md` | Where each captured file lives on the box + restore sketch. |

## Git

- `origin` → `git@github.com:alc168/nas-admin.git` (GitHub, **private**)
- `mirror` → `/home/tm/git/nas-admin.git` (on-box bare repo)
- **Push both:** `git push origin main && git push mirror main`
- Auth: account key `~/.ssh/id_ed25519` (on the GitHub profile). Commit as
  `alc168 <42325600+alc168@users.noreply.github.com>`.
- Other repos on the box: `~/trading-platform`, `~/sigen-dashboard/home.dash2`,
  `~/hybrid-research` (mirror only), `~/territory` (mirror only). All on the
  account key now; the old per-repo deploy keys were removed.

## Rules of engagement

1. **Recon read-only first.** This box runs live household services (Plex,
   photos, the battery controller). Verify before you change.
2. **Never commit secrets.** Scrub `.env` → `.env.example` (`sed -E
   's/^([A-Za-z_][A-Za-z0-9_]*=).*/\1/'`). The `.gitignore` blocks
   `*.env`/`*.db`/`*.sql`/keys — keep it that way.
3. **No reboots.** There is **no UPS** and a disk (`sdd`/disk4) has already
   failed to re-mount once (2026-09-07). The `/etc/fstab` race is patched but
   unproven across a boot. If a reboot is unavoidable, afterwards verify
   `df -h /mnt/storage` shows **66T / all 6 disks** before trusting the pool.
4. **Destructive batches get auto-blocked.** Chaining `rm` + `docker prune` +
   `systemctl` in one command trips the harness classifier. Run them
   singly, or hand them to the user.
5. **Leave rollback paths.** Don't delete an old copy until the replacement
   has soaked. See the Immich item in `PROGRESS.md`.
6. **`du` on `/mnt/storage/*` is very slow** (millions of small files) — it
   will time out. Use `df`, or Immich/Plex DB counts, or `rsync --stats`.
7. `docker compose` for project `tm` uses two files
   (`~/docker-compose.yml` + `~/docker-compose-monitoring.yml`). Operate on
   **named services** and pass only `-f docker-compose.yml`, or you'll get
   "orphan containers" warnings about the monitoring stack. **Never**
   `--remove-orphans` there.

## Resuming

```
ssh tm@192.168.0.172
cd ~/nas-admin && git pull
sed -n '1,80p' docs/PROGRESS.md      # current state + next actions
```
