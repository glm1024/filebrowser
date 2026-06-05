#!/bin/sh

set -eu

usage() {
  cat <<'EOF'
Usage: sh scripts/start.sh [--help]

Start File Browser locally without Docker.

Environment variables:
  FB_ADDRESS    Listen address. Default: 127.0.0.1
  FB_PORT       Listen port. Default: 8080
  FB_ROOT       File root directory. Default: .local-dev/files
  FB_DATABASE   BoltDB path. Default: .local-dev/filebrowser.db
  FB_BIN        File Browser binary. Default: ./filebrowser
  FB_PID_FILE   PID file path. Default: .local-dev/filebrowser.pid
  FB_LOG_FILE   Log file path. Default: .local-dev/filebrowser.log
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
FILES_DIR=${FB_ROOT:-"$LOCAL_DIR/files"}
DB_PATH=${FB_DATABASE:-"$LOCAL_DIR/filebrowser.db"}
PID_FILE=${FB_PID_FILE:-"$LOCAL_DIR/filebrowser.pid"}
LOG_FILE=${FB_LOG_FILE:-"$LOCAL_DIR/filebrowser.log"}
ADDRESS=${FB_ADDRESS:-127.0.0.1}
PORT=${FB_PORT:-8080}
DEFAULT_BIN="$PROJECT_ROOT/filebrowser"
BIN=${FB_BIN:-"$DEFAULT_BIN"}

is_running() {
  pid=$1
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

start_background() {
  if command -v python3 >/dev/null 2>&1; then
    FB_START_BIN="$BIN" \
    FB_START_ADDRESS="$ADDRESS" \
    FB_START_PORT="$PORT" \
    FB_START_ROOT="$FILES_DIR" \
    FB_START_DATABASE="$DB_PATH" \
    FB_START_LOG="$LOG_FILE" \
    FB_START_CWD="$PROJECT_ROOT" \
    python3 - <<'PY'
import os
import subprocess

command = [
    os.environ["FB_START_BIN"],
    "--address", os.environ["FB_START_ADDRESS"],
    "--port", os.environ["FB_START_PORT"],
    "--root", os.environ["FB_START_ROOT"],
    "--database", os.environ["FB_START_DATABASE"],
]

log = open(os.environ["FB_START_LOG"], "wb", buffering=0)
process = subprocess.Popen(
    command,
    cwd=os.environ["FB_START_CWD"],
    stdin=subprocess.DEVNULL,
    stdout=log,
    stderr=subprocess.STDOUT,
    start_new_session=True,
    close_fds=True,
)
print(process.pid)
PY
  else
    nohup "$BIN" \
      --address "$ADDRESS" \
      --port "$PORT" \
      --root "$FILES_DIR" \
      --database "$DB_PATH" \
      > "$LOG_FILE" 2>&1 &
    printf '%s\n' "$!"
  fi
}

wait_for_health() {
  health_host=$ADDRESS
  case "$health_host" in
    ""|0.0.0.0)
      health_host=127.0.0.1
      ;;
  esac

  count=0
  while [ "$count" -lt 20 ]; do
    if ! is_running "$pid"; then
      return 1
    fi
    if command -v curl >/dev/null 2>&1; then
      if curl -fsS "http://$health_host:$PORT/health" >/dev/null 2>&1; then
        return 0
      fi
    else
      sleep 2
      is_running "$pid"
      return $?
    fi
    count=$((count + 1))
    sleep 1
  done

  return 1
}

build_default_binary() {
  printf 'File Browser binary not found, building locally...\n'
  if command -v task >/dev/null 2>&1; then
    (cd "$PROJECT_ROOT" && task build)
  elif command -v go >/dev/null 2>&1; then
    if [ ! -f "$PROJECT_ROOT/frontend/dist/public/index.html" ]; then
      printf 'Frontend assets are missing and task is not available.\n' >&2
      printf 'Run: cd frontend && pnpm install --frozen-lockfile && pnpm run build\n' >&2
      exit 1
    fi
    (cd "$PROJECT_ROOT" && go build -o "$DEFAULT_BIN" .)
  else
    printf 'Neither task nor go is available. Install the local toolchain first.\n' >&2
    exit 1
  fi
}

mkdir -p "$LOCAL_DIR" "$FILES_DIR"

if [ -f "$PID_FILE" ]; then
  old_pid=$(cat "$PID_FILE")
  if is_running "$old_pid"; then
    printf 'File Browser is already running. PID: %s\n' "$old_pid"
    printf 'URL: http://%s:%s\n' "$ADDRESS" "$PORT"
    exit 0
  fi
  rm -f "$PID_FILE"
fi

if [ ! -x "$BIN" ]; then
  if [ "$BIN" = "$DEFAULT_BIN" ]; then
    build_default_binary
  else
    printf 'Configured binary is not executable: %s\n' "$BIN" >&2
    exit 1
  fi
fi

if command -v lsof >/dev/null 2>&1; then
  if lsof -n -P -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    printf 'Port %s is already in use. Set FB_PORT to another port.\n' "$PORT" >&2
    exit 1
  fi
fi

printf 'Starting File Browser...\n'
pid=$(start_background)
printf '%s\n' "$pid" > "$PID_FILE"

if ! wait_for_health; then
  rm -f "$PID_FILE"
  printf 'File Browser failed to start. Recent logs:\n' >&2
  tail -n 40 "$LOG_FILE" >&2 || true
  exit 1
fi

printf 'File Browser started. PID: %s\n' "$pid"
printf 'URL: http://%s:%s\n' "$ADDRESS" "$PORT"
printf 'Root: %s\n' "$FILES_DIR"
printf 'Database: %s\n' "$DB_PATH"
printf 'Log: %s\n' "$LOG_FILE"
printf '\nRecent logs:\n'
tail -n 20 "$LOG_FILE" || true
