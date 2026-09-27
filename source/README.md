# iTNet address-list generator (container)

Build and run daily Iran / Meta / Telegram / Spamhaus list updates, then publish
`raw-data/` + `scripts/*.rsc` into the parent useful-scripts repository.

## Host layout

- Project root: `/root/itnet-addresslist-generator`
- Source: `/root/itnet-addresslist-generator/source`
- Work/lock data: `/root/itnet-addresslist-generator/data`
- Publish repo bind-mount: `/opt/itnet-useful-mikrotik-scripts` → `/data/repo`
- Deploy key (read-only): `/root/.ssh/itnet_useful_mikrotik_scripts_deploy`

## Build

```bash
cd /root/itnet-addresslist-generator/source
docker compose build
```

## Manual run

```bash
cd /root/itnet-addresslist-generator/source
docker compose run --rm update spamhaus
docker compose run --rm update meta
docker compose run --rm update telegram
docker compose run --rm update iran
docker compose run --rm update main
```

## Scheduling

Host systemd timers call `docker compose run --rm update <job>`.
