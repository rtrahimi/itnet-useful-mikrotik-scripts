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

### 7. `scripts/itnet_router_sftp_backup_setup.rsc`

Installs daily MikroTik configuration backups on RouterOS 6.49+ and 7.
Do not deploy this RouterOS workflow to non-MikroTik routers.

- Creates or updates script and scheduler `iTNet-Router-SFTP-Backup`.
- Stores connection settings in script `iTNet-Router-SFTP-Settings`.
- Runs daily at `08:00:00` router local time, with `interval=1d`.
- Runs once during installation unless `runImmediately` is set to `false`.
- Creates an unencrypted native `.backup` and a verbose `.rsc` export.
- Includes exportable secrets using `show-sensitive` on RouterOS 7; on
  RouterOS 6, the `hide-sensitive` flag is deliberately omitted.
- Adds a separate `.umb` database backup when User Manager is enabled.
- Sends files over SFTP, then deletes each local file only after its upload
  reports `status=finished`.
- Retries a failed transfer up to three attempts with 15-second pauses.
- At the start of the next run, deletes this job's staging files left by an
  unsuccessful run. Unrelated files are not selected for cleanup.
- Prevents overlapping worker runs and duplicate scheduler entries.
- Disables the exact legacy scheduler `Backup to ftp` when present.

Destination layout, relative to the shared SFTP account's home directory:

```text
<Router Identity>/itnet-sftp-<Router Identity>-YYYYMMDD-HHMMSS.backup
<Router Identity>/itnet-sftp-<Router Identity>-YYYYMMDD-HHMMSS.rsc
<Router Identity>/itnet-sftp-<Router Identity>-YYYYMMDD-HHMMSS.umb
```

The `.umb` file applies only to routers with an enabled User Manager package.
Identity must be unique and contain only ASCII letters, digits, spaces,
periods, underscores, or hyphens. Spaces are preserved in directory and file
names. A failed run's local files are discarded, not retried the next day.
Server-side retention is independent; this script never deletes remote copies.

### Install daily SFTP backups

1. Provision the shared SFTP user and a directory matching the exact Identity
   of each router. Create that directory again when adding or renaming a router;
   `fetch` does not create it. Ensure the account can upload and overwrite there.
2. Set `sftpHost`, `sftpPort`, `sftpUser`, and `sftpPassword` in the installer.
   The iTNet endpoint defaults to `172.16.241.2:2022`, account
   `itnet-router-backup`. Its home is
   `/srv/itnet-storage/backup/iTNet/Router-Backups`; leave `remoteBase` empty for
   this layout. The actual shared password is an operational value, not part of
   the public repository. Quote RouterOS string values correctly, escaping
   backslashes, double quotes, and dollar signs.
3. Verify the private route to Storage, writable local space, and synchronized
   NTP. iTNet MikroTik routers use `Asia/Tehran`, UTC+03:30 year-round, with
   automatic timezone detection disabled and no summer DST. The installer does
   not change the clock, timezone, firewall, or routing.
   The existing public endpoint of the same iTNet Storage service is
   `88.135.38.69:2022`; set `sftpHost` to that address for routers without a
   working private Storage path. Provisioning a new listener or NAT rule is not
   part of this installer.
4. Import the configured installer with the required script permissions:
   `ftp,read,write,policy,test,password,sensitive`.

RouterOS 6.49 SFTP clients can require the `hmac-sha1` SSH MAC. Verify server
compatibility: a server offering only SHA-2 MACs can reject the connection
before password authentication. The installer does not change server settings.

```routeros
/import file-name="itnet_router_sftp_backup_setup.rsc"
/system scheduler print detail where name="iTNet-Router-SFTP-Backup"
/system script run iTNet-Router-SFTP-Backup
```

Acceptance requires actual nonempty files in the correct Storage directory,
the expected Identity/date/time names, an export without `#error exporting`
markers, and no remaining local `itnet-sftp-*.backup`, `.rsc`, or `.umb` files
after a successful run. Check the scheduler's next run as well as its 08:00
start time. A clock that is not synchronized can run the job at the wrong civil
time even when the scheduler is configured correctly.

A native backup is a RouterOS configuration backup, not an image of arbitrary
files or attached disks. Text export cannot include system user login passwords,
installed certificates, or SSH keys. Native restore and separate application
backups remain necessary; User Manager is handled by the supplemental `.umb`,
while The Dude data requires its own workflow when used. Restore should be
tested on an appropriate spare device, preferably with the matching RouterOS
version, not on a live production router.

References: [MikroTik Fetch](https://help.mikrotik.com/docs/spaces/ROS/pages/8978514/Fetch),
[native backup](https://help.mikrotik.com/docs/spaces/ROS/pages/40992852/Backup),
[configuration export](https://help.mikrotik.com/docs/spaces/ROS/pages/328155/Configuration+Management),
[User Manager](https://help.mikrotik.com/docs/spaces/ROS/pages/2555940/User+Manager).

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
