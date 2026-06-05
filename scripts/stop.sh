#!/bin/sh

set -eu

usage() {
  cat <<'EOF'
Usage: sh scripts/stop.sh [--help]

Stop the local File Browser process started by scripts/start.sh.

Environment variables:
  FB_PID_FILE   PID file path. Default: .local-dev/filebrowser.pid
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    printf 'Unknown argument: %s\n\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd "$SCRIPT_DIR/.." && pwd)
LOCAL_DIR=${FB_LOCAL_DIR:-"$PROJECT_ROOT/.local-dev"}
PID_FILE=${FB_PID_FILE:-"$LOCAL_DIR/filebrowser.pid"}

is_running() {
  pid=$1
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

if [ ! -f "$PID_FILE" ]; then
  printf 'File Browser is not running: PID file not found.\n'
  exit 0
fi

pid=$(cat "$PID_FILE")
if ! is_running "$pid"; then
  rm -f "$PID_FILE"
  printf 'File Browser is not running: removed stale PID file.\n'
  exit 0
fi

printf 'Stopping File Browser. PID: %s\n' "$pid"
kill "$pid"

count=0
while is_running "$pid"; do
  count=$((count + 1))
  if [ "$count" -ge 20 ]; then
    printf 'File Browser did not stop after 20 seconds. PID: %s\n' "$pid" >&2
    exit 1
  fi
  sleep 1
done

rm -f "$PID_FILE"
printf 'File Browser stopped.\n'
