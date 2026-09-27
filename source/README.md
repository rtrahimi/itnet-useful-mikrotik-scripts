# iTNet address-list generator (container)

## Host layout

```text
/root/itnet-addresslist-generator/
  source/     # Dockerfile, compose, scripts, systemd unit templates
  data/
    repo/     # local clone of itnet-useful-mikrotik-scripts (publish target)
    work/     # job workdirs
    lock/     # flock files
  secrets/
    git_deploy_key   # GitHub deploy key (repo write)
```

Only host requirements outside this tree:
- Docker Engine
- systemd timers that call `docker compose run` (optional scheduler)

## Build / run

```bash
cd /root/itnet-addresslist-generator/source
docker compose build
docker compose run --rm update spamhaus
```
