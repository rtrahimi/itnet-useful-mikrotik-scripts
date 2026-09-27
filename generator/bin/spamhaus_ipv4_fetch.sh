#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

OUTPUT_FILE="${1:-spamhaus_ipv4.txt}"
SOURCE_URL="https://www.spamhaus.org/drop/drop_v4.json"
USER_AGENT="iTNet-Spamhaus-Fetch/2026-09-26"

python3 - "$OUTPUT_FILE" "$SOURCE_URL" "$USER_AGENT" <<'PY'
import ipaddress
import json
import ssl
import sys
import urllib.request

output_file = sys.argv[1]
source_url = sys.argv[2]
user_agent = sys.argv[3]

ssl_context = ssl.create_default_context()
request = urllib.request.Request(source_url, headers={"User-Agent": user_agent})
with urllib.request.urlopen(request, context=ssl_context, timeout=120) as response:
    raw = response.read().decode("utf-8", errors="replace")

networks = []
for line in raw.splitlines():
    text = line.strip()
    if not text:
        continue
    try:
        item = json.loads(text)
    except json.JSONDecodeError:
        continue
    if not isinstance(item, dict):
        continue
    if item.get("type") == "metadata":
        continue
    cidr = str(item.get("cidr", "")).strip()
    if not cidr:
        continue
    try:
        network = ipaddress.ip_network(cidr, strict=False)
    except ValueError:
        continue
    if network.version != 4:
        continue
    networks.append(network)

if not networks:
    raise SystemExit("no IPv4 prefixes parsed from Spamhaus DROP feed")

collapsed = list(ipaddress.collapse_addresses(networks))
collapsed.sort(key=lambda n: (int(n.network_address), n.prefixlen))

with open(output_file, "w", encoding="utf-8") as out:
    for network in collapsed:
        out.write(f"{network}\n")

print(f"spamhaus_prefixes={len(collapsed)}")
PY
