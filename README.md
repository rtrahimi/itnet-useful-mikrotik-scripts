# iTNet Useful MikroTik Scripts


## Repository layout

- `scripts/` — MikroTik-ready `.rsc` files and import helpers
- `raw-data/` — daily raw IPv4 prefix lists (`.txt` + `.sha256`) produced on the generator host

Raw files currently published:

- `raw-data/iran_ipv4.txt`
- `raw-data/meta_ipv4.txt`
- `raw-data/telegram_ipv4.txt`
- `raw-data/spamhaus_ipv4.txt`

Dedicated `daily-*-address-list` GitHub repositories are no longer updated; this repository is the single publish target.

![RouterOS](https://img.shields.io/badge/routeros-v7-blue)
![Scope](https://img.shields.io/badge/scope-production%20utility%20scripts-0b7285)

A curated collection of practical MikroTik scripts used in iTNet production environments.

## Address-list generator

Daily address-list generation runs on the generator host as an always-on Docker container.
This repository only stores published MikroTik scripts and raw-data outputs.


## Repository Goals

- Keep reusable RouterOS scripts in one place.
- Use safe, explicit defaults for production rollout.
- Provide quick import steps and predictable behavior.

## Included Scripts

### 2. `scripts/itnet_addresslist_import_iran.rsc`

For Iran (`Y-*-RTR*`) only. Installs script + daily scheduler and runs once.

- Creates `/system script` and `/system scheduler` named `iTNet-AddressList-Import-Iran`.
- Removes legacy `iTNet-AddressList-Import-All` and `iTNet-import address lists` if present.
- Fetches and imports:
  - `itnet-iran_no_vpn.rsc` → address-list `NO-VPN`
  - `itnet-whatsapp_vpn.rsc` → address-list `VPN`
  - `itnet-telegram_vpn.rsc` → address-list `VPN`
  - `itnet-spamhaus_auto_block.rsc` → address-list `Auto-Block`
- Scheduler: `interval=1d`, `start-time=01:00:00`, `start-date=jan/01/1970`

### 3. `scripts/itnet_addresslist_import_outside.rsc`

For outside-Iran (`X-*-RTR*`) only. Installs script + daily scheduler and runs once.

- Creates `/system script` and `/system scheduler` named `iTNet-AddressList-Import-Outside`.
- Removes Iran/legacy import script+scheduler names if present (`Import-Iran`, `Import-All`, legacy).
- Fetches and imports only:
  - `itnet-spamhaus_auto_block.rsc` → address-list `Auto-Block`
- Same scheduler timing as Iran: `interval=1d`, `start-time=01:00:00`

### 4. Address-list data files

- `scripts/itnet-iran_no_vpn.rsc`
- `scripts/itnet-whatsapp_vpn.rsc`
- `scripts/itnet-telegram_vpn.rsc`
- `scripts/itnet-spamhaus_auto_block.rsc`

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
```

### Install address-list import — Iran (`Y-*-RTR*`)

```routeros
/tool fetch check-certificate=no url="https://raw.githubusercontent.com/rtrahimi/itnet-useful-mikrotik-scripts/main/scripts/itnet_addresslist_import_iran.rsc" dst-path="itnet_addresslist_import_iran.rsc"
/import file-name="itnet_addresslist_import_iran.rsc"
/file remove [find where name="itnet_addresslist_import_iran.rsc"]
```

### Install address-list import — outside Iran (`X-*-RTR*`)

```routeros
/tool fetch check-certificate=no url="https://raw.githubusercontent.com/rtrahimi/itnet-useful-mikrotik-scripts/main/scripts/itnet_addresslist_import_outside.rsc" dst-path="itnet_addresslist_import_outside.rsc"
/import file-name="itnet_addresslist_import_outside.rsc"
/file remove [find where name="itnet_addresslist_import_outside.rsc"]
```

### Install DNS static OpenAI setup script

```routeros
```

### Install DNS static Discord setup script

```routeros
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
- Scripts are designed to be explicit and operationally predictable.

## Contribution Workflow
