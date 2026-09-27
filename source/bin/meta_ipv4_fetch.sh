#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE="${1:-meta_ipv4_all.txt}"
ROOT_AS_SET="${2:-AS-FACEBOOK}"
WHOIS_HOST="whois.radb.net"

if ! command -v whois >/dev/null 2>&1; then
  echo "whois command is not installed." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

asns_file="$tmp_dir/asns.txt"
routes_raw_file="$tmp_dir/routes_raw.txt"
: > "$asns_file"
: > "$routes_raw_file"

declare -A seen_sets=()
declare -A seen_asns=()
queue=("${ROOT_AS_SET^^}")

while ((${#queue[@]})); do
  current_set="${queue[0]}"
  queue=("${queue[@]:1}")

  if [[ -n "${seen_sets[$current_set]:-}" ]]; then
    continue
  fi
  seen_sets["$current_set"]=1

  expansion="$(whois -h "$WHOIS_HOST" -- "!i${current_set}" 2>/dev/null || true)"
  if [[ -z "$expansion" ]]; then
    continue
  fi

  while IFS= read -r token; do
    token="${token//$'\r'/}"
    token="${token//,/}"
    token="${token^^}"

    if [[ "$token" =~ ^AS[0-9]+$ ]]; then
      if [[ -z "${seen_asns[$token]:-}" ]]; then
        seen_asns["$token"]=1
        printf '%s\n' "$token" >> "$asns_file"
      fi
    elif [[ "$token" =~ ^AS-[A-Z0-9._-]+$ ]]; then
      if [[ -z "${seen_sets[$token]:-}" ]]; then
        queue+=("$token")
      fi
    fi
  done < <(printf '%s\n' "$expansion" | tr '[:space:]' '\n')
done

if [[ ! -s "$asns_file" ]]; then
  echo "No ASNs were discovered from ${ROOT_AS_SET}." >&2
  exit 1
fi

sort -u "$asns_file" -o "$asns_file"

while IFS= read -r asn; do
  whois -h "$WHOIS_HOST" -- "-i origin $asn" 2>/dev/null \
    | awk '/^route:[[:space:]]/ { print $2 }' \
    >> "$routes_raw_file"
done < "$asns_file"

sort -u "$routes_raw_file" \
  | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+$/' \
  > "$OUTPUT_FILE"

echo "AS-SET: $ROOT_AS_SET"
echo "Discovered ASNs: $(wc -l < "$asns_file")"
echo "IPv4 prefixes: $(wc -l < "$OUTPUT_FILE")"
echo "Output file: $OUTPUT_FILE"
