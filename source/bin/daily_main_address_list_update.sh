#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_REPO_URL="${SCRIPTS_REPO_URL:-git@github.com:rtrahimi/itnet-useful-mikrotik-scripts.git}"
SCRIPTS_REPO_DIR="${SCRIPTS_REPO_DIR:-/data/repo}"
SCRIPTS_BRANCH="${SCRIPTS_BRANCH:-main}"
IRAN_FILE="${IRAN_FILE:-$SCRIPTS_REPO_DIR/raw-data/iran_ipv4.txt}"
WHATSAPP_FILE="${WHATSAPP_FILE:-$SCRIPTS_REPO_DIR/raw-data/meta_ipv4.txt}"
TELEGRAM_FILE="${TELEGRAM_FILE:-$SCRIPTS_REPO_DIR/raw-data/telegram_ipv4.txt}"
TARGET_REL="scripts/itnet_main_address_list.rsc"
COMMIT_NAME="${COMMIT_NAME:-Morteza Rahimi}"
COMMIT_EMAIL="${COMMIT_EMAIL:-rtrahimi@gmail.com}"
LOCK_FILE="${LOCK_FILE:-/data/lock/itnet-useful-mikrotik-scripts.lock}"
GIT_DEPLOY_KEY="${GIT_DEPLOY_KEY:-/run/secrets/git_deploy_key}"

for cmd in git flock mktemp python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd command is not installed" >&2
    exit 1
  fi
done

for file in "$IRAN_FILE" "$WHATSAPP_FILE" "$TELEGRAM_FILE"; do
  if [[ ! -s "$file" ]]; then
    echo "required source file is missing or empty: $file" >&2
    exit 1
  fi
done

mkdir -p /var/lock

temp_file="$(mktemp)"
trap 'rm -f "$temp_file"' EXIT

python3 - "$IRAN_FILE" "$WHATSAPP_FILE" "$TELEGRAM_FILE" "$temp_file" <<'PY'
import ipaddress
import sys

iran_path = sys.argv[1]
whatsapp_path = sys.argv[2]
telegram_path = sys.argv[3]
output_path = sys.argv[4]


def load_ipv4_networks(path):
    networks = []
    with open(path, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            text = raw_line.strip()
            if not text:
                continue
            try:
                network = ipaddress.ip_network(text, strict=False)
            except ValueError:
                continue
            if network.version != 4:
                continue
            networks.append(network)
    return list(ipaddress.collapse_addresses(networks))


def subtract_networks(base_networks, block_networks):
    result = []
    for base in base_networks:
        remaining = [base]
        for blocker in block_networks:
            if not remaining:
                break
            next_remaining = []
            for candidate in remaining:
                if not candidate.overlaps(blocker):
                    next_remaining.append(candidate)
                    continue
                if blocker == candidate or blocker.supernet_of(candidate):
                    continue
                if candidate.supernet_of(blocker):
                    next_remaining.extend(candidate.address_exclude(blocker))
                    continue
                next_remaining.append(candidate)
            remaining = next_remaining
        result.extend(remaining)
    return list(ipaddress.collapse_addresses(result))


iran_networks = load_ipv4_networks(iran_path)
whatsapp_networks = load_ipv4_networks(whatsapp_path)
telegram_networks = load_ipv4_networks(telegram_path)
telegram_unique_networks = subtract_networks(telegram_networks, whatsapp_networks)

with open(output_path, "w", encoding="utf-8") as out:
    out.write(':log info "iTNet-Main-address-list-start"\n')
    out.write('/ip firewall address-list remove [find where list="NO-VPN" comment="iTNet-NoVPN"]\n')
    out.write('/ip firewall address-list remove [find where list="VPN" comment~"^iTNet-Whatsapp"]\n')
    out.write('/ip firewall address-list remove [find where list="VPN" comment~"^iTNet-Telegram"]\n')

    for network in iran_networks:
        out.write(f'/ip firewall address-list add list=NO-VPN address={network} comment=iTNet-NoVPN\n')

    for network in whatsapp_networks:
        out.write(f'/ip firewall address-list add list=VPN address={network} comment=iTNet-Whatsapp-IPv4\n')

    for network in telegram_unique_networks:
        out.write(f'/ip firewall address-list add list=VPN address={network} comment=iTNet-Telegram-IPv4\n')

    out.write(':log info "iTNet-Main-address-list-done"\n')

print(f"iran_prefixes={len(iran_networks)}")
print(f"whatsapp_prefixes_collapsed={len(whatsapp_networks)}")
print(f"telegram_prefixes_collapsed={len(telegram_networks)}")
print(f"telegram_prefixes_unique={len(telegram_unique_networks)}")
PY

if [ ! -f "$GIT_DEPLOY_KEY" ]; then
  echo "deploy key missing: $GIT_DEPLOY_KEY" >&2
  exit 1
fi
install -m 600 "$GIT_DEPLOY_KEY" /tmp/git_deploy_key
export GIT_SSH_COMMAND="ssh -i /tmp/git_deploy_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

mkdir -p "$(dirname "$LOCK_FILE")"
exec 200>"$LOCK_FILE"
flock -x 200

if [ ! -d "$SCRIPTS_REPO_DIR/.git" ]; then
  git clone "$SCRIPTS_REPO_URL" "$SCRIPTS_REPO_DIR"
fi

git -C "$SCRIPTS_REPO_DIR" config user.name "$COMMIT_NAME"
git -C "$SCRIPTS_REPO_DIR" config user.email "$COMMIT_EMAIL"
git -C "$SCRIPTS_REPO_DIR" config core.sshCommand "$GIT_SSH_COMMAND"

if git -C "$SCRIPTS_REPO_DIR" show-ref --verify --quiet "refs/heads/$SCRIPTS_BRANCH"; then
  git -C "$SCRIPTS_REPO_DIR" checkout "$SCRIPTS_BRANCH"
else
  if git -C "$SCRIPTS_REPO_DIR" ls-remote --exit-code --heads origin "$SCRIPTS_BRANCH" >/dev/null 2>&1; then
    git -C "$SCRIPTS_REPO_DIR" fetch origin "$SCRIPTS_BRANCH"
    git -C "$SCRIPTS_REPO_DIR" checkout -b "$SCRIPTS_BRANCH" "origin/$SCRIPTS_BRANCH"
  else
    git -C "$SCRIPTS_REPO_DIR" checkout -b "$SCRIPTS_BRANCH"
  fi
fi

if git -C "$SCRIPTS_REPO_DIR" ls-remote --exit-code --heads origin "$SCRIPTS_BRANCH" >/dev/null 2>&1; then
  git -C "$SCRIPTS_REPO_DIR" fetch origin "$SCRIPTS_BRANCH"
  git -C "$SCRIPTS_REPO_DIR" rebase "origin/$SCRIPTS_BRANCH"
fi

mkdir -p "$SCRIPTS_REPO_DIR/$(dirname "$TARGET_REL")"
cp "$temp_file" "$SCRIPTS_REPO_DIR/$TARGET_REL"

git -C "$SCRIPTS_REPO_DIR" add "$TARGET_REL"

if ! git -C "$SCRIPTS_REPO_DIR" diff --cached --quiet; then
  GIT_AUTHOR_NAME="$COMMIT_NAME" GIT_AUTHOR_EMAIL="$COMMIT_EMAIL" \
  GIT_COMMITTER_NAME="$COMMIT_NAME" GIT_COMMITTER_EMAIL="$COMMIT_EMAIL" \
  git -C "$SCRIPTS_REPO_DIR" commit -m "daily update: itnet_main_address_list.rsc $(date -u +%F) $(date -u +%H:%M:%S)"
  git -C "$SCRIPTS_REPO_DIR" push origin "$SCRIPTS_BRANCH"
fi

echo "main address-list script generated: $SCRIPTS_REPO_DIR/$TARGET_REL"
