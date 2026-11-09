#!/usr/bin/env bash
# Task 338: the END of a drive in Karen's place -- the state she photographed. Waits for the HUD
# countdown to reach ~0:12 and takes the hunter's-eye frame with the toast and the clock together.
set -u
R=<runs-dir>; cd "$R" || exit 9
m=$(python ftplay.py mode 2>/dev/null | tail -1)
[ "$m" = "Edit" ] || { echo "REFUSED: Studio is '$m'"; exit 2; }
python ftplay.py start >/dev/null 2>&1; t0=$(date +%s)
for i in $(seq 1 30); do
  w=$(python ftplay.py client 338-wire.luau 2>/dev/null | tail -1)
  case "$w" in installed*|already*) break;; esac
  sleep 2
done
echo "wire at +$(( $(date +%s) - t0 ))s: $w"
lob=none; while [ $(( $(date +%s) - t0 )) -le 90 ]; do
  lob=$(python ftplay.py server lobby-go.luau 2>/dev/null | tail -1)
  case "$lob" in *gunBefore=false*) break;; esac
  sleep 2
done
echo "lobby-go at +$(( $(date +%s) - t0 ))s: $lob"
for i in $(seq 1 60); do
  c=$(python ftplay.py client 338-clock.luau 2>/dev/null | tail -1)
  echo "+$(( $(date +%s) - t0 ))s $c" | cut -c1-200
  case "$c" in *'"0:1'*|*'"0:0'*) break;; esac
  sleep 8
done
cam=$(python ftplay.py client 338-cam.luau 2>/dev/null | tail -1)
echo "cam $cam"
python ftplay.py capture "$(cygpath -w "$R/338-F2-driveend.png")" $cam 2>/dev/null | tail -1
python ftplay.py client 338-clock.luau 2>/dev/null | tail -1 | cut -c1-200
