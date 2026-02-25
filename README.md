# iTNet Useful MikroTik Scripts

![RouterOS](https://img.shields.io/badge/routeros-v7-blue)
![Scope](https://img.shields.io/badge/scope-production%20utility%20scripts-0b7285)

A curated collection of practical MikroTik scripts used in iTNet production environments.

## Repository Goals

- Keep reusable RouterOS scripts in one place.
- Use safe, explicit defaults for production rollout.
- Provide quick import steps and predictable behavior.

## Included Scripts

### 1. `scripts/itnet_vpn_mangle_setup.rsc`

Creates or fixes the `VPN` routing table and adds two disabled `mangle` rules.

- Ensures routing table `VPN` exists.
- Ensures routing table `VPN` has `fib` enabled.
- Adds `mark-routing` rule for destination list `VPN`.
- Adds `mark-routing` rule for destination list `!NO-VPN`.
- Creates rules as `disabled=yes` for safe activation.

Rule comments:

- `iTNet-Mangle-VPNList-to-VPNRoute`
- `iTNet-Mangle-NotNoVPN-to-VPNRoute`

### 2. `scripts/itnet_addresslist_sync.rsc`

Installs daily address-list sync automation directly inside a scheduler task.

- Creates `/system scheduler` named `iTNet-AddressList-Sync`.
- Stores the full sync logic inline in scheduler `on-event`.
- Does not depend on a separate `/system script run ...` call.
- Removes legacy `/system script` with the same name if it exists.
- Syncs these remote lists daily:
  - `whatsapp_vpn.rsc`
  - `telegram_vpn.rsc`
  - `iran_no_vpn.rsc`
- Scheduler settings:
  - `interval=1d`
  - `start-time=05:00:00`
  - `start date 1997-01-01`

### 3. `scripts/itnet_dns_static_openai_setup.rsc`

Applies strict first-party OpenAI DNS static FWD records.

- Designed for fresh routers with no previous DNS static setup.
- Removes legacy OpenAI-managed records by comment.
- Rebuilds managed records idempotently with first-party-only scope.
- Uses address-list `VPN` for resolved IP tagging.
- Enables `match-subdomain=yes` on all managed FWD records.
- Uses comment:
  - `iTNet-oa-fp-sub2al` for managed domain records.

### 4. `scripts/itnet_dns_static_discord_setup.rsc`

Applies strict first-party Discord DNS static FWD records.

- Removes legacy Discord-managed records by comment.
- Rebuilds managed records idempotently with first-party-only scope.
- Uses address-list `VPN` for resolved IP tagging.
- Enables `match-subdomain=yes` on all managed FWD records.
- Uses comment:
  - `iTNet-dc-fp-sub2al` for managed domain records.

### 5. `scripts/openai_discord_dns_collector.py`

Linux DNS forwarder/collector for discovering OpenAI and Discord related domains and IPv4 addresses from live DNS traffic.

- Listens on UDP/TCP DNS (`53` by default).
- Forwards queries to an upstream resolver (`8.8.8.8` by default).
- Classifies observed domains (OpenAI/Discord suffix matching).
- Extracts global IPv4 answers and stores unique values.
- Writes detailed DNS events log for audit/troubleshooting.

Default outputs:

- `output-file=/root/openai_discord_ipv4.txt`
- `events-file=/root/openai_discord_dns_events.log`

## Quick Start

### Install VPN mangle setup script

```routeros
/tool fetch check-certificate=no url="https://raw.githubusercontent.com/rtrahimi/itnet-useful-mikrotik-scripts/main/scripts/itnet_vpn_mangle_setup.rsc" dst-path="itnet_vpn_mangle_setup.rsc"
/import file-name="itnet_vpn_mangle_setup.rsc"
/file remove [find where name="itnet_vpn_mangle_setup.rsc"]
```

### Install address-list sync scheduler script

```routeros
/tool fetch check-certificate=no url="https://raw.githubusercontent.com/rtrahimi/itnet-useful-mikrotik-scripts/main/scripts/itnet_addresslist_sync.rsc" dst-path="itnet_addresslist_sync.rsc"
/import file-name="itnet_addresslist_sync.rsc"
/file remove [find where name="itnet_addresslist_sync.rsc"]
```

### Install DNS static OpenAI setup script

```routeros
/tool fetch check-certificate=no url="https://raw.githubusercontent.com/rtrahimi/itnet-useful-mikrotik-scripts/main/scripts/itnet_dns_static_openai_setup.rsc" dst-path="itnet_dns_static_openai_setup.rsc"
/import file-name="itnet_dns_static_openai_setup.rsc"
/file remove [find where name="itnet_dns_static_openai_setup.rsc"]
```

### Install DNS static Discord setup script

```routeros
/tool fetch check-certificate=no url="https://raw.githubusercontent.com/rtrahimi/itnet-useful-mikrotik-scripts/main/scripts/itnet_dns_static_discord_setup.rsc" dst-path="itnet_dns_static_discord_setup.rsc"
/import file-name="itnet_dns_static_discord_setup.rsc"
/file remove [find where name="itnet_dns_static_discord_setup.rsc"]
```

### Run OpenAI/Discord DNS collector on Linux

```bash
python3 scripts/openai_discord_dns_collector.py \
  --listen-host 0.0.0.0 \
  --listen-port 53 \
  --upstream-host 8.8.8.8 \
  --upstream-port 53 \
  --output-file /root/openai_discord_ipv4.txt \
  --events-file /root/openai_discord_dns_events.log
```

### Verify scheduler

```routeros
/system scheduler print detail where name="iTNet-AddressList-Sync"
```

Expected key values:

- `start-time=05:00:00`
- `interval=1d`
- `start-date=1997-01-01`
- `on-event` contains the sync script body (inline)

## Notes

- Tested on RouterOS v7.
- Rule order in `mangle` is important.
- `itnet_vpn_mangle_setup.rsc` intentionally uses `passthrough=no` for deterministic match-stop behavior.
- Scripts are designed to be explicit and operationally predictable.

## Contribution Workflow
