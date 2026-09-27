#!/usr/bin/env bash
set -euo pipefail

JOB="${1:-daemon}"
BIN_DIR="/app/bin"

usage() {
  cat <<'EOF'
Usage: entrypoint.sh <command>

Commands:
  daemon       always-on mode (cron scheduler, default)
  iran
  meta
  telegram
  spamhaus
  main
  all          iran + meta + telegram + spamhaus (not main)
EOF
}

run_job() {
  local name="$1"
  mkdir -p /data/work/logs
  echo "[$(date -u +%F\ %T)] start $name" | tee -a "/data/work/logs/${name}.log"
  case "$name" in
    iran) "$BIN_DIR/daily_iran_update.sh" ;;
    meta) "$BIN_DIR/daily_meta_update.sh" ;;
    telegram) "$BIN_DIR/daily_telegram_update.sh" ;;
    spamhaus) "$BIN_DIR/daily_spamhaus_update.sh" ;;
    main) "$BIN_DIR/daily_main_address_list_update.sh" ;;
    *) echo "unknown job: $name" >&2; return 2 ;;
  esac
  echo "[$(date -u +%F\ %T)] done $name" | tee -a "/data/work/logs/${name}.log"
}

case "$JOB" in
  daemon)
    mkdir -p /data/work/logs
    # Persist container env for cron jobs (cron does not inherit Docker ENV).
    env | grep -E '^(SCRIPTS_|WORK_|LOCK_|GIT_|COMMIT_|TZ|LANG|PATH)=' > /etc/container.env
    chmod 644 /etc/container.env
    echo "[$(date -u +%F\ %T)] addresslist generator daemon started (cron UTC)"
    exec cron -f
    ;;
  iran|meta|telegram|spamhaus|main)
    run_job "$JOB"
    ;;
  all)
    run_job iran
    run_job meta
    run_job telegram
    run_job spamhaus
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "unknown command: $JOB" >&2
    usage
    exit 2
    ;;
esac
