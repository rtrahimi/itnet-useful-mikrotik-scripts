#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

OUTPUT_FILE="${1:-iran_ipv4.txt}"

python3 - "$OUTPUT_FILE" <<'PY'
import csv
import gzip
import io
import ipaddress
import json
import ssl
import sys
import urllib.request
from collections import defaultdict

output_file = sys.argv[1]

user_agent = "iTNet-IranIPv4-Fetch/2026-03-08"
ssl_context = ssl.create_default_context()

source_networks = defaultdict(set)
source_stats = defaultdict(int)
fetch_errors = []

delegated_asns = set()
ripestat_country_asns = set()
peeringdb_asns = set()


def fetch_bytes(url, timeout=60):
    request = urllib.request.Request(url, headers={"User-Agent": user_agent})
    with urllib.request.urlopen(request, context=ssl_context, timeout=timeout) as response:
        return response.read()


def fetch_json(url, timeout=60):
    data = fetch_bytes(url, timeout=timeout)
    return json.loads(data.decode("utf-8", errors="replace"))


def add_network(prefix_text, source_name):
    prefix = str(prefix_text).strip()
    if not prefix:
        return
    try:
        network = ipaddress.ip_network(prefix, strict=False)
    except ValueError:
        return
    if network.version != 4:
        return
    source_networks[source_name].add(network)


def add_range(start_ip_text, end_ip_text, source_name):
    try:
        start_ip = ipaddress.IPv4Address(str(start_ip_text).strip())
        end_ip = ipaddress.IPv4Address(str(end_ip_text).strip())
    except ipaddress.AddressValueError:
        return
    if int(end_ip) < int(start_ip):
        return
    for network in ipaddress.summarize_address_range(start_ip, end_ip):
        source_networks[source_name].add(network)


def add_delegated_asn(start_text, count_text):
    try:
        start = int(start_text)
        count = int(count_text)
    except ValueError:
        return
    if count <= 0:
        return
    end = start + count
    for asn in range(start, end):
        delegated_asns.add(asn)


def parse_asn(value):
    text = str(value).strip().upper()
    if text.startswith("AS"):
        text = text[2:]
    try:
        return int(text)
    except ValueError:
        return None


def parse_ripe_inetnum_stream(text_reader):
    inet_start = ""
    inet_end = ""
    has_ir_country = False

    def flush_object(start, end, has_ir):
        if start and end and has_ir:
            add_range(start, end, "whois_inetnum")

    for raw_line in text_reader:
        line = raw_line.rstrip("\r\n")

        if not line.strip():
            flush_object(inet_start, inet_end, has_ir_country)
            inet_start = ""
            inet_end = ""
            has_ir_country = False
            continue

        lower = line.lower()
        if lower.startswith("inetnum:"):
            value = line.split(":", 1)[1].strip()
            if "-" in value:
                left, right = value.split("-", 1)
                inet_start = left.strip()
                inet_end = right.strip()
        elif lower.startswith("country:"):
            country_parts = line.split(":", 1)[1].strip().split()
            if country_parts and country_parts[0].upper() == "IR":
                has_ir_country = True

    flush_object(inet_start, inet_end, has_ir_country)


delegated_urls = [
    "https://ftp.ripe.net/pub/stats/ripencc/delegated-ripencc-latest",
    "https://ftp.apnic.net/stats/apnic/delegated-apnic-latest",
    "https://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest",
    "https://ftp.afrinic.net/pub/stats/afrinic/delegated-afrinic-latest",
    "https://ftp.lacnic.net/pub/stats/lacnic/delegated-lacnic-latest",
]

for url in delegated_urls:
    try:
        text = fetch_bytes(url, timeout=90).decode("utf-8", errors="replace")
    except Exception as exc:
        fetch_errors.append(f"delegated source failed: {url} ({exc})")
        continue

    lines = text.splitlines()
    source_stats[f"delegated_lines::{url}"] = len(lines)

    for line in lines:
        if not line or line.startswith("#"):
            continue

        parts = line.split("|")
        if len(parts) < 7:
            continue

        country = parts[1].strip().upper()
        resource_type = parts[2].strip().lower()
        start = parts[3].strip()
        value = parts[4].strip()
        status = parts[6].strip().lower()

        if country != "IR":
            continue
        if status not in {"allocated", "assigned"}:
            continue

        if resource_type == "ipv4":
            try:
                count = int(value)
                if count <= 0:
                    continue
                start_ip = ipaddress.IPv4Address(start)
                end_ip = ipaddress.IPv4Address(int(start_ip) + count - 1)
            except Exception:
                continue
            add_range(str(start_ip), str(end_ip), "delegated")
        elif resource_type == "asn":
            add_delegated_asn(start, value)

source_stats["delegated_asn_count"] = len(delegated_asns)

ripe_inetnum_url = "https://ftp.ripe.net/ripe/dbase/split/ripe.db.inetnum.gz"
try:
    request = urllib.request.Request(ripe_inetnum_url, headers={"User-Agent": user_agent})
    with urllib.request.urlopen(request, context=ssl_context, timeout=120) as response:
        with gzip.GzipFile(fileobj=response) as gz_file:
            text_reader = io.TextIOWrapper(gz_file, encoding="utf-8", errors="replace")
            parse_ripe_inetnum_stream(text_reader)
except Exception as exc:
    fetch_errors.append(f"whois inetnum source failed: {ripe_inetnum_url} ({exc})")

geofeed_url = "https://opengeofeed.org/feed/public.csv"
try:
    geofeed_text = fetch_bytes(geofeed_url, timeout=90).decode("utf-8", errors="replace")
    geofeed_reader = csv.reader(io.StringIO(geofeed_text))
    for row in geofeed_reader:
        if not row:
            continue
        first = row[0].strip()
        if not first or first.startswith("#"):
            continue
        if len(row) < 2:
            continue
        country = row[1].strip().upper()
        if country != "IR":
            continue
        add_network(first, "geofeed")
except Exception as exc:
    fetch_errors.append(f"geofeed source failed: {geofeed_url} ({exc})")

ripestat_country_url = "https://stat.ripe.net/data/country-resource-list/data.json?resource=IR&v4_format=prefix"
try:
    ripestat_country_json = fetch_json(ripestat_country_url, timeout=60)
    resources = ripestat_country_json.get("data", {}).get("resources", {})

    for prefix in resources.get("ipv4", []):
        add_network(prefix, "ripestat_country")

    for asn_text in resources.get("asn", []):
        asn = parse_asn(asn_text)
        if asn is not None:
            ripestat_country_asns.add(asn)
except Exception as exc:
    fetch_errors.append(f"RIPEstat country-resource-list source failed: {ripestat_country_url} ({exc})")

source_stats["ripestat_country_asn_count"] = len(ripestat_country_asns)

peeringdb_org_url = "https://www.peeringdb.com/api/org?country=IR"
try:
    peeringdb_org_json = fetch_json(peeringdb_org_url, timeout=90)
    org_ids = []
    for org in peeringdb_org_json.get("data", []):
        if str(org.get("status", "")).lower() != "ok":
            continue
        org_id = org.get("id")
        if isinstance(org_id, int):
            org_ids.append(org_id)

    for org_id in sorted(set(org_ids)):
        net_url = f"https://www.peeringdb.com/api/net?org_id={org_id}"
        try:
            net_json = fetch_json(net_url, timeout=60)
        except Exception as exc:
            fetch_errors.append(f"PeeringDB net source failed: {net_url} ({exc})")
            continue

        for net in net_json.get("data", []):
            if str(net.get("status", "")).lower() != "ok":
                continue
            asn = net.get("asn")
            if isinstance(asn, int):
                peeringdb_asns.add(asn)

    for asn in sorted(peeringdb_asns):
        announced_url = f"https://stat.ripe.net/data/announced-prefixes/data.json?resource=AS{asn}"
        try:
            announced_json = fetch_json(announced_url, timeout=60)
        except Exception as exc:
            fetch_errors.append(f"RIPEstat announced-prefixes failed: {announced_url} ({exc})")
            continue

        prefixes = announced_json.get("data", {}).get("prefixes", [])
        for item in prefixes:
            if isinstance(item, dict):
                prefix = item.get("prefix")
                if prefix:
                    add_network(prefix, "peeringdb_ripestat")
            elif isinstance(item, str):
                add_network(item, "peeringdb_ripestat")
except Exception as exc:
    fetch_errors.append(f"PeeringDB source failed: {peeringdb_org_url} ({exc})")

source_stats["peeringdb_asn_count"] = len(peeringdb_asns)

add_network("10.0.0.0/8", "private")
add_network("172.16.0.0/12", "private")
add_network("192.168.0.0/16", "private")
add_network("169.254.0.0/16", "private")

all_networks = set()
for source_name, networks in source_networks.items():
    source_stats[f"prefixes::{source_name}"] = len(networks)
    all_networks.update(networks)

if not all_networks:
    raise SystemExit("No IPv4 prefixes were collected from any source")

collapsed_networks = list(ipaddress.collapse_addresses(all_networks))
collapsed_networks.sort(key=lambda n: (int(n.network_address), n.prefixlen))

with open(output_file, "w", encoding="utf-8") as out:
    for network in collapsed_networks:
        out.write(f"{network}\n")

print(f"Delegated IR ASNs: {len(delegated_asns)}")
print(f"RIPEstat country ASNs: {len(ripestat_country_asns)}")
print(f"PeeringDB IR ASNs: {len(peeringdb_asns)}")
for key in sorted(source_stats):
    if key.startswith("prefixes::"):
        print(f"{key}: {source_stats[key]}")
print(f"IPv4 prefixes (collapsed): {len(collapsed_networks)}")
print(f"Output file: {output_file}")

if fetch_errors:
    print("Source warnings:", file=sys.stderr)
    for item in fetch_errors:
        print(item, file=sys.stderr)
PY
