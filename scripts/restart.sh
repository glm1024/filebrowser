#!/bin/sh

set -eu

usage() {
  cat <<'EOF'
Usage: sh scripts/restart.sh [--help]

Restart File Browser locally without Docker.
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

sh "$SCRIPT_DIR/stop.sh"
sh "$SCRIPT_DIR/start.sh"
