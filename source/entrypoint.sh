#!/usr/bin/env bash
set -euo pipefail

JOB="${1:-}"
BIN_DIR="/app/bin"

usage() {
  cat <<'EOF'
Usage: entrypoint.sh <job>

Jobs:
  iran
  meta
  telegram
  spamhaus
  main
  all          # iran + meta + telegram + spamhaus (not main)
EOF
}

if [ -z "$JOB" ]; then
  usage
  exit 2
fi

case "$JOB" in
  iran) "$BIN_DIR/daily_iran_update.sh" ;;
  meta) "$BIN_DIR/daily_meta_update.sh" ;;
  telegram) "$BIN_DIR/daily_telegram_update.sh" ;;
  spamhaus) "$BIN_DIR/daily_spamhaus_update.sh" ;;
  main) "$BIN_DIR/daily_main_address_list_update.sh" ;;
  all)
    "$BIN_DIR/daily_iran_update.sh"
    "$BIN_DIR/daily_meta_update.sh"
    "$BIN_DIR/daily_telegram_update.sh"
    "$BIN_DIR/daily_spamhaus_update.sh"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "unknown job: $JOB" >&2
    usage
    exit 2
    ;;
esac
