#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_ROOT="${WORK_ROOT:-/data/work}"
WORK_DIR="$WORK_ROOT/iran"
OUTPUT_NAME="iran_ipv4.txt"
HASH_NAME="iran_ipv4.txt.sha256"
RSC_NAME="itnet-iran_no_vpn.rsc"
RSC_LIST="NO-VPN"
RSC_COMMENT="iTNet-NoVPN"

for cmd in git whois sha256sum curl awk python3 flock; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd command is not installed" >&2; exit 1; }
done

mkdir -p "$WORK_DIR"
"$BIN_DIR/iran_ipv4_fetch.sh" "$WORK_DIR/$OUTPUT_NAME"
(cd "$WORK_DIR" && sha256sum "$OUTPUT_NAME" > "$HASH_NAME")

{
  echo "/ip firewall address-list remove [find where list=\"$RSC_LIST\" comment=\"$RSC_COMMENT\"]"
  awk -v list="$RSC_LIST" -v comment="$RSC_COMMENT" 'NF {print "/ip firewall address-list add list=" list " address=" $1 " comment=" comment}' "$WORK_DIR/$OUTPUT_NAME"
} > "$WORK_DIR/$RSC_NAME"

"$BIN_DIR/itnet_git_publish.sh" \
  "daily update: iran raw+rsc $(date -u +%F) $(date -u +%H:%M:%S)" \
  "$WORK_DIR/$OUTPUT_NAME:raw-data/$OUTPUT_NAME" \
  "$WORK_DIR/$HASH_NAME:raw-data/$HASH_NAME" \
  "$WORK_DIR/$RSC_NAME:scripts/$RSC_NAME"
