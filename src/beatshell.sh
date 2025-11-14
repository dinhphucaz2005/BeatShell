#!/usr/bin/env bash
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
LOADING="loading"
BEAT_TUI="beattui"
BEAT_CMD="beatcmd"
BEAT_SERVER="beatserver"
PWD=$HOME/Music/BeatShell/metadata

export PATH="$SCRIPT_DIR/bin:$PATH"

start_beat_server() {
  if pgrep "$BEAT_SERVER" > /dev/null; then
    echo "$BEAT_SERVER is already running"
  else
    echo "Starting $BEAT_SERVER"
    "$BEAT_SERVER" &
  fi
}

start_beat_server

$LOADING

if [ -n "$1" ]; then
  "$BEAT_CMD" "--play" "$1"
fi

$BEAT_TUI