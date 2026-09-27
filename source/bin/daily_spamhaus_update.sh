#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_ROOT="${WORK_ROOT:-/data/work}"
WORK_DIR="$WORK_ROOT/spamhaus"
OUTPUT_NAME="spamhaus_ipv4.txt"
HASH_NAME="spamhaus_ipv4.txt.sha256"
RSC_NAME="itnet-spamhaus_auto_block.rsc"
RSC_LIST="Auto-Block"
RSC_COMMENT="iTNet-spanhaus.org-BlackList"

for cmd in git sha256sum curl awk python3 flock; do
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
"$BIN_DIR/spamhaus_ipv4_fetch.sh" "$raw_file"
normalize_ipv4_file "$raw_file" "$WORK_DIR/$OUTPUT_NAME"
rm -f "$raw_file"
(cd "$WORK_DIR" && sha256sum "$OUTPUT_NAME" > "$HASH_NAME")


{
  echo "/ip firewall address-list remove [find where list=\"$RSC_LIST\" comment=\"$RSC_COMMENT\"]"
  awk -v list="$RSC_LIST" -v comment="$RSC_COMMENT" 'NF {print "/ip firewall address-list add list=" list " address=" $1 " comment=" comment}' "$WORK_DIR/$OUTPUT_NAME"
} > "$WORK_DIR/$RSC_NAME"

"$BIN_DIR/itnet_git_publish.sh" \
  "daily update: spamhaus raw+rsc $(date -u +%F) $(date -u +%H:%M:%S)" \
  "$WORK_DIR/$OUTPUT_NAME:raw-data/$OUTPUT_NAME" \
  "$WORK_DIR/$HASH_NAME:raw-data/$HASH_NAME" \
  "$WORK_DIR/$RSC_NAME:scripts/$RSC_NAME"
