#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_ROOT="${WORK_ROOT:-/data/work}"
WORK_DIR="$WORK_ROOT/meta"
OUTPUT_NAME="meta_ipv4.txt"
HASH_NAME="meta_ipv4.txt.sha256"
RSC_NAME="itnet-whatsapp_vpn.rsc"
RSC_LIST="VPN"
RSC_COMMENT="iTNet-Whatsapp-IPv4"

for cmd in git whois sha256sum curl awk python3 flock; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd command is not installed" >&2; exit 1; }
done

normalize_ipv4_file() {
  python3 - "$1" "$2" <<'PY'
import ipaddress, sys
items=[]
with open(sys.argv[1], encoding="utf-8") as h:
    for line in h:
        t=line.strip()
        if not t: continue
        try: n=ipaddress.ip_network(t, strict=False)
        except ValueError: continue
        if n.version==4: items.append(n)
collapsed=sorted(ipaddress.collapse_addresses(items), key=lambda n:(int(n.network_address), n.prefixlen))
with open(sys.argv[2],"w",encoding="utf-8") as out:
    for n in collapsed: out.write(f"{n}\n")
PY
}

mkdir -p "$WORK_DIR"
raw_file="$WORK_DIR/${OUTPUT_NAME}.raw"
"$BIN_DIR/meta_ipv4_fetch.sh" "$raw_file"
normalize_ipv4_file "$raw_file" "$WORK_DIR/$OUTPUT_NAME"
rm -f "$raw_file"
(cd "$WORK_DIR" && sha256sum "$OUTPUT_NAME" > "$HASH_NAME")
rm -rf "$WORK_DIR/mikrotik"
rm -f "$WORK_DIR/meta_ipv4_all.txt"

{
  echo "/ip firewall address-list remove [find where list=\"$RSC_LIST\" comment~\"^iTNet-Whatsapp\"]"
  awk -v list="$RSC_LIST" -v comment="$RSC_COMMENT" 'NF {print "/ip firewall address-list add list=" list " address=" $1 " comment=" comment}' "$WORK_DIR/$OUTPUT_NAME"
} > "$WORK_DIR/$RSC_NAME"

"$BIN_DIR/itnet_git_publish.sh" \
  "daily update: meta/whatsapp raw+rsc $(date -u +%F) $(date -u +%H:%M:%S)" \
  "$WORK_DIR/$OUTPUT_NAME:raw-data/$OUTPUT_NAME" \
  "$WORK_DIR/$HASH_NAME:raw-data/$HASH_NAME" \
  "$WORK_DIR/$RSC_NAME:scripts/$RSC_NAME"
