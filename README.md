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

### 2. `scripts/itnet_addresslist_import_all_scheduler_setup.rsc`

Installs daily address-list import automation.

- Creates `/system script` named `iTNet-AddressList-Import-All`.
- Creates `/system scheduler` with the same name that runs that script daily.
- Removes legacy scheduler `iTNet-import address lists` if present.
- Runs the import once immediately during setup.
- Fetches and imports these lists from this repository:
  - `iran_no_vpn.rsc` → address-list `NO-VPN`
  - `whatsapp_vpn.rsc` → address-list `VPN`
  - `telegram_vpn.rsc` → address-list `VPN`
- Scheduler settings:
  - `interval=1d`
  - `start-time=01:00:00`
  - `start-date=jan/01/1970`

### 3. `scripts/itnet_addresslist_import_all.rsc`

One-shot manual import of the same three address-list files (no scheduler install).

### 4. Address-list data files

- `scripts/iran_no_vpn.rsc`
- `scripts/whatsapp_vpn.rsc`
- `scripts/telegram_vpn.rsc`

### 5. `scripts/itnet_dns_static_openai_setup.rsc`

Applies strict first-party OpenAI DNS static FWD records.

- Designed for fresh routers with no previous DNS static setup.
- Removes legacy OpenAI-managed records by comment.
- Rebuilds managed records idempotently with first-party-only scope.
- Uses address-list `VPN` for resolved IP tagging.
- Enables `match-subdomain=yes` on all managed FWD records.
- Uses comment:
  - `iTNet-oa-fp-sub2al` for managed domain records.

### 6. `scripts/itnet_dns_static_discord_setup.rsc`

Applies strict first-party Discord DNS static FWD records.

- Removes legacy Discord-managed records by comment.
- Rebuilds managed records idempotently with first-party-only scope.
- Uses address-list `VPN` for resolved IP tagging.
- Enables `match-subdomain=yes` on all managed FWD records.
- Uses comment:
  - `iTNet-dc-fp-sub2al` for managed domain records.

## Quick Start

### Install VPN mangle setup script

```routeros
/tool fetch check-certificate=no url="https://raw.githubusercontent.com/rtrahimi/itnet-useful-mikrotik-scripts/main/scripts/itnet_vpn_mangle_setup.rsc" dst-path="itnet_vpn_mangle_setup.rsc"
/import file-name="itnet_vpn_mangle_setup.rsc"
/file remove [find where name="itnet_vpn_mangle_setup.rsc"]
```

### Install address-list daily import (recommended)

```routeros
/tool fetch check-certificate=no url="https://raw.githubusercontent.com/rtrahimi/itnet-useful-mikrotik-scripts/main/scripts/itnet_addresslist_import_all_scheduler_setup.rsc" dst-path="itnet_addresslist_import_all_scheduler_setup.rsc"
/import file-name="itnet_addresslist_import_all_scheduler_setup.rsc"
/file remove [find where name="itnet_addresslist_import_all_scheduler_setup.rsc"]
```

### One-shot address-list import (no scheduler)

```routeros
/tool fetch check-certificate=no url="https://raw.githubusercontent.com/rtrahimi/itnet-useful-mikrotik-scripts/main/scripts/itnet_addresslist_import_all.rsc" dst-path="itnet_addresslist_import_all.rsc"
/import file-name="itnet_addresslist_import_all.rsc"
/file remove [find where name="itnet_addresslist_import_all.rsc"]
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

### Verify scheduler and script

```routeros
/system script print detail where name="iTNet-AddressList-Import-All"
/system scheduler print detail where name="iTNet-AddressList-Import-All"
```

Expected key values:

- `start-time=01:00:00`
- `interval=1d`
- `start-date=jan/01/1970`
- scheduler `on-event=iTNet-AddressList-Import-All`

## Notes

- Tested on RouterOS v7.
- Rule order in `mangle` is important.
- `itnet_vpn_mangle_setup.rsc` intentionally uses `passthrough=no` for deterministic match-stop behavior.
- Scripts are designed to be explicit and operationally predictable.
- Legacy `itnet_addresslist_sync.rsc` and combined `itnet_main_address_list.rsc` were removed; use the scheduler setup and the three split list files instead.

## Contribution Workflow
