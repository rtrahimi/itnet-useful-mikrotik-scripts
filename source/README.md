# iTNet address-list generator (always-on container)

## Host layout

```text
/root/itnet-addresslist-generator/
  source/     # Dockerfile, compose, scripts
  data/
    repo/     # local clone of itnet-useful-mikrotik-scripts
    work/     # job workdirs + logs/
    lock/
  secrets/
    git_deploy_key
```

Host requirements outside this tree:
- Docker Engine (with restart on boot)

No systemd timers are used. Scheduling is inside the container via cron (UTC).

## Schedule (UTC)

- 03:00 — iran, meta, telegram, spamhaus
- 03:30 — main

## Start / stop

```bash
cd /root/itnet-addresslist-generator/source
docker compose up -d --build
docker compose ps
docker compose logs -f
docker compose down
```

## Manual one-shot job

```bash
docker compose run --rm update spamhaus
```
