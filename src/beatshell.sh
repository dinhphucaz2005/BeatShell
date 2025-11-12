#!/usr/bin/env bash
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
BEAT_TUI="beattui"
BEAT_SERVER="beatserver"

export PATH="$SCRIPT_DIR/bin:$PATH"

start_beat_server() {
  if pgrep -x "beat_server" > /dev/null; then
    echo "beat_server is already running."
  else
    echo "Starting beat_server..."
    "$SCRIPT_DIR/bin/$BEAT_SERVER" &
    sleep 2
    echo "beat_server started."
  fi
}

start_beat_server

$BEAT_TUI