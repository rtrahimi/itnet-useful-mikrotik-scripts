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
  - start date equivalent to `01.01.1997` (`jan/01/1997` in RouterOS syntax, shown as `1997-01-01`)

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

- Add each new script under `scripts/`.
- Keep file names in `snake_case`.
- Update `README.md` when adding or changing scripts.
