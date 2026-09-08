#!/usr/bin/env bash
# Toggle a region screen recording. Same key starts and stops.
set -uo pipefail

OUT="$HOME/Videos/Recordings"
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/wf-recorder.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
	kill -INT "$(cat "$PIDFILE")"
	rm -f "$PIDFILE"
	notify-send "Recording stopped" "Saved to $OUT"
	exit 0
fi

mkdir -p "$OUT"
region="$(slurp)" || exit 0
file="$OUT/$(date +%Y-%m-%d_%H-%M-%S).mp4"

wf-recorder -g "$region" -f "$file" &
echo $! >"$PIDFILE"
notify-send "Recording started" "$file"
