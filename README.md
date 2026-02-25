# iTNet Useful MikroTik Scripts

A curated collection of practical MikroTik scripts used in iTNet production environments.

## Repository Goals

- Keep reusable RouterOS scripts in one clean place.
- Provide safe defaults for operational use.
- Include clear usage steps and expected behavior.

## Included Scripts

### 1. `scripts/itnet_vpn_mangle_setup.rsc`

Creates (or fixes) the `VPN` routing table and adds two `mangle` rules for routing-mark logic.

What it does:

- Ensures routing table `VPN` exists.
- Ensures `VPN` routing table has `fib` enabled.
- Adds a disabled rule for traffic matching destination address-list `VPN`.
- Adds a disabled rule for traffic matching destination address-list `!NO-VPN`.
- Keeps rules disabled by default (`disabled=yes`) for safe rollout.

Rule comments used:

- `iTNet-Mangle-VPNList-to-VPNRoute`
- `iTNet-Mangle-NotNoVPN-to-VPNRoute`

## Quick Start

### 1. Fetch script from GitHub

```routeros
/tool fetch check-certificate=no url="https://raw.githubusercontent.com/rtrahimi/itnet-useful-mikrotik-scripts/main/scripts/itnet_vpn_mangle_setup.rsc" dst-path="itnet_vpn_mangle_setup.rsc"
```

### 2. Import script

```routeros
/import file-name="itnet_vpn_mangle_setup.rsc"
```

### 3. Optional cleanup

```routeros
/file remove [find where name="itnet_vpn_mangle_setup.rsc"]
```

## Notes

- Tested on RouterOS v7.
- Rule order in `mangle` is important.
- Current rules are intentionally created with `passthrough=no`.
- Scripts are designed to be explicit and deterministic for production use.

## Contribution Workflow

- Add each new script under `scripts/`.
- Keep file names in `snake_case`.
- Update `README.md` when adding or changing scripts.
