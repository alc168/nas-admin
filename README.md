# nas-admin

Operational documentation and (over time) configuration for **terramaster**
(`192.168.0.172`) — the household NAS running Plex + the *arr* stack, Immich,
the `home-dash2` energy dashboard, the trading platform and assorted web apps.

## Layout

| Path | Contents |
|---|---|
| `docs/` | Operational runbooks (backup/restore, maintenance, network, MAM automation, storage, …) |
| `docs/audits/` | Point-in-time infrastructure audits. Start with `2026-09-06-terramaster-audit.md`. |

## Intended scope (see the 2026-09-06 audit, recommendation B1)

This repo should grow to hold, in version control, the things that currently
only exist on the box:

- `~/docker-compose.yml`, `~/docker-compose-monitoring.yml`
- each app dir's `docker-compose.yml` + `*.env.example` (**never real `.env`**)
- `~/scripts/`
- copies of `/etc/nginx/sites-available/*`, `/etc/exports`, `/etc/samba/smb.conf`,
  `/etc/fstab`, `/etc/smartd.conf`, the systemd unit files, `crontab -l`

## Rules

- **No secrets.** Real `.env`, tokens, keys, cookies and `*.db` files are
  git-ignored. Commit `*.example` templates only.
- Private repo only — the audit describes the full security posture of the host.
