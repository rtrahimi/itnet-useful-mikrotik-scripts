#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE="${1:-telegram_ipv4.txt}"
SOURCE_URL="https://core.telegram.org/resources/cidr.txt"

python3 - "$OUTPUT_FILE" <<'PY'
import ipaddress
import sys
import urllib.request

output_file = sys.argv[1]
source_url = "https://core.telegram.org/resources/cidr.txt"

with urllib.request.urlopen(source_url, timeout=30) as response:
    raw = response.read().decode("utf-8", errors="ignore").splitlines()

networks = []
for line in raw:
    entry = line.strip()
    if not entry:
        continue
    try:
        net = ipaddress.ip_network(entry, strict=True)
    except ValueError:
        continue
    if net.version == 4:
        networks.append(net)

if not networks:
    print("No Telegram IPv4 prefixes were extracted.", file=sys.stderr)
    sys.exit(1)

collapsed = list(ipaddress.collapse_addresses(sorted(set(networks), key=lambda n: (int(n.network_address), n.prefixlen))))

with open(output_file, "w", encoding="ascii") as out:
    for net in collapsed:
        out.write(f"{net}\n")

print(f"IPv4 prefixes: {len(collapsed)}")
print(f"Output file: {output_file}")
PY
