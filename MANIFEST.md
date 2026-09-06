# MANIFEST — where these files live on `terramaster`

| Repo path | Live location on the box |
|---|---|
| `compose/tm/docker-compose.yml` | `~/docker-compose.yml` (project `tm`: arr stack + Immich + Plex) |
| `compose/tm/docker-compose-monitoring.yml` | `~/docker-compose-monitoring.yml` (Prometheus/Grafana/Alertmanager/unpoller) |
| `compose/home-dash2/*` | `~/sigen-dashboard/home.dash2/` |
| `compose/trading-platform/*` | `~/trading-platform/deploy/` |
| `compose/<app>/docker-compose.yml` | `~/<app>/docker-compose.yml` |
| `env-examples/*.env.example` | the matching real `.env` on the box — **values intentionally stripped**; fill from your password manager |
| `etc/nginx/sites-available/*` | `/etc/nginx/sites-available/` (symlinked into `sites-enabled/`) |
| `etc/ssh/sshd_config.d/50-cloud-init.conf` | `/etc/ssh/sshd_config.d/` |
| `etc/exports` `etc/fstab` `etc/smartd.conf` | `/etc/` |
| `etc/samba/smb.conf.testparm` | rendered `testparm -s` output (source is `/etc/samba/smb.conf` + usershares) |
| `etc/systemd/*` | `/etc/systemd/system/` |
| `scripts/mam-check.sh` | `~/scripts/mam-check.sh` — **MAMID token stripped**, restore before use |
| `scripts/plex_*.sh` | `~/scripts/` |
| `crontab.tm.txt` | `crontab -l` for user `tm` |

## Not captured here (do separately)
- `~/config/*` (Radarr/Sonarr/Prowlarr/qBittorrent/Plex/Grafana) — contains API keys
  and a 31 GB Plex metadata tree. Needs a curated, redacted export.
- Real `.env` files and secrets — belong in a password manager / Docker secrets, never here.

## Restore sketch
1. Recreate `~/<app>/` dirs, drop the compose files back.
2. Recreate each `.env` from `env-examples/` + your password manager.
3. `sudo cp` the `etc/` files back to their locations; `nginx -t && systemctl reload nginx`;
   `systemctl daemon-reload`; re-enable timers.
4. `docker compose up -d` per stack.
