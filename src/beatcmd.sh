#!/usr/bin/env bash

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

BEAT_SEARCH="$SCRIPT_DIR/beatsearch"

case "$1" in
  --search)
    if [ -z "$2" ]; then
      echo "Usage: beatcmd --search <search>"
      exit 1
    fi
    "$BEAT_SEARCH" --search "$2"
    ;;

  --play)
    if [ -z "$2" ]; then
      echo "Usage: beatcmd --play <youtube_metadata.json>"
      exit 1
    fi
    curl -X POST http://127.0.0.1:8080/play \
         -H "Content-Type: application/json" \
         -d "$(cat "$2")"
    ;;

  *)
    echo "Usage:"
    echo "  beatcmd --search <search>"
    echo "  beatcmd --play <youtube_metadata.json>"
    exit 1
    ;;
esac
