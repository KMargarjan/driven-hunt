#!/usr/bin/env bash
# Task 338: one cell drive, counting released animals, animals that left the cell, and escape
# entries on the wire (what the toast stacks) at 15 s, 60 s and drive end.
set -u
R=/c/Users/karen/Desktop/driven-hunt-runs; cd "$R" || exit 9
TAG=${1:-before}
m=$(python ftplay.py mode 2>/dev/null | tail -1)
[ "$m" = "Edit" ] || { echo "REFUSED: Studio is '$m'"; exit 2; }
python ftplay.py start >/dev/null 2>&1; t0=$(date +%s)
# install the watchers as soon as the server answers
for i in $(seq 1 30); do
  o=$(python ftplay.py server 338-watch.luau 2>/dev/null | tail -1)
  case "$o" in installed*|already*) break;; esac
  sleep 2
done
echo "watch at +$(( $(date +%s) - t0 ))s: $o"
w=$(python ftplay.py client 338-wire.luau 2>/dev/null | tail -1); echo "wire: $w"
# enroll
lob=nolobby; while [ $(( $(date +%s) - t0 )) -le 80 ]; do
  lob=$(python ftplay.py server lobby-go.luau 2>/dev/null | tail -1)
  case "$lob" in *gunBefore=false*) break;; esac
  sleep 2
done
echo "lobby-go at +$(( $(date +%s) - t0 ))s: $lob"
# the drive opens ~15 s after the pad takes him; mark that as d0
d0=$(date +%s)
for mark in 15 60 150 300; do
  while [ $(( $(date +%s) - d0 )) -lt "$mark" ]; do sleep 3; done
  echo "=== t+${mark}s (wall +$(( $(date +%s) - t0 ))s)"
  python ftplay.py server 338-read.luau 2>/dev/null | tail -1
  python ftplay.py client 338-wireread.luau 2>/dev/null | tail -1
done
python ftplay.py consolefull 2>/dev/null > "338-console-$TAG.txt"
echo "console -> 338-console-$TAG.txt"
