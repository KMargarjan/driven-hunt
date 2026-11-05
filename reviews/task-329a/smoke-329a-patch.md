# Task 329a -- the smoke.sh patch, for reading in the PR

The patch that APPLIES is `<runs-dir>/smoke-329a.patch`. This copy exists so the diff can be
read in the pull request; its one absolute path is replaced by the `<runs-dir>` placeholder that
`tools/privacy_scan.py` requires of a tracked file, so it is NOT apply-clean.

Amended after the round-1 PASS -- see EVIDENCE.md section 7 for what changed and why.

```diff
--- smoke.sh	2026-10-16 23:49:13.363019200 +0200
+++ smoke-329a-test.sh	2026-11-05 18:49:34.748997900 +0100
@@ -7,29 +7,95 @@
 R=<runs-dir>; S=${1:-80}; cd "$R" || exit 9
 m=$(python ftplay.py mode 2>/dev/null | tail -1)
 [ "$m" = "Edit" ] || { echo "SMOKE REFUSED: Studio is '$m' (Karen may be playing)"; exit 2; }
-python ftplay.py start >/dev/null 2>&1; sleep 15
+python ftplay.py start >/dev/null 2>&1; t0=$(date +%s)
+FT=130094961655666
 # LOBBY (task 177, 2026-10-13): a player by the lodge has NO gun by design. If the lobby exists, check
 # no gun there, step him into the truck spot, and require the gun only after the drive takes him.
-lob=$(python ftplay.py server lobby-go.luau 2>/dev/null | tail -1)
-lobbyfail=0
-case "$lob" in lobby*) echo "$lob" | grep -q "gunBefore=false" || lobbyfail=1; sleep 20;; esac
-g1=$(python ftplay.py client wq.luau 2>/dev/null | grep -c "equipped tool")
+#
+# TASK 329a: POLLED, NOT SLEPT, AND THE EXIT CONDITION IS `gunBefore=false`. Measured in Karen's
+# place over 11 Plays: the `Lobby` folder appears 12.2-14.5 s into the SERVER's own boot, and the
+# lobby finishes TAKING the player (disarming him, standing him at the lodge) 0.5-1.2 s after that.
+# Two blind sleeps used to straddle those numbers:
+#   * `sleep 15` + process cost put this call at ~24 s of the server's boot -- ~11 s of margin. When
+#     a slower boot ate it, lobby-go answered "nolobby", which `case lobby*` matched NOWHERE, so the
+#     player was never stepped onto a pad and the run reported "gun not in hand" from the lodge
+#     porch at y=153: a true sentence about a player nobody had taken.
+#   * stepping him on while the folder exists but the lobby has NOT taken him (`gunBefore=true`)
+#     gets him respawned back to the lodge, OFF the pad, so the pad never takes him either
+#     (measured 2026-11-05: step-on at +12 s, no gun 51 s later, y=153.4 throughout).
+# So the wait ends on the fact the next line asserts, and nothing else. TASK 177'S CHECK IS NOW
+# SATISFIED BY ANY ONE SAMPLE IN THE WINDOW rather than by the single sample it used to take, and
+# that is deliberate: before the lobby has taken him the gun it is about to remove is not "a gun in
+# the lobby". Do not re-tighten this `case` to the first answer.
+#
+# ONLY THE FOREST TEST IS POLLED. Another `SMOKE_PLACE` has no lobby by design, so it keeps the old
+# single call, the old `sleep 20` and the old timing, bit for bit -- a poll there would spend
+# `SMOKE_GUN_WAIT` waiting for a step-on that never happened.
+lob=nolobby; lobwait=0; nolobby=0; lobbyfail=0; gunpoll=0
+if [ "${SMOKE_PLACE:-$FT}" = "$FT" ]; then
+	gunpoll=1
+	while [ "$lobwait" -le "${SMOKE_LOBBY_WAIT:-70}" ]; do
+		lob=$(python ftplay.py server lobby-go.luau 2>/dev/null | tail -1)
+		lobwait=$(( $(date +%s) - t0 ))
+		case "$lob" in *gunBefore=false*) break;; esac
+		sleep 2
+	done
+	case "$lob" in
+		*gunBefore=false*) ;;
+		lobby*) lobbyfail=1;;
+		*) nolobby=1;;
+	esac
+else
+	sleep 15
+	lob=$(python ftplay.py server lobby-go.luau 2>/dev/null | tail -1)
+	lobwait=$(( $(date +%s) - t0 ))
+	case "$lob" in lobby*) echo "$lob" | grep -q "gunBefore=false" || lobbyfail=1; sleep 20;; esac
+fi
+echo "lobby-go at +${lobwait}s: [$lob]"
+# ...AND THE SAME FOR THE GUN. The pad needs 8 s to pick, 5 s to leave and a scan: measured
+# 13.9-18.0 s from the step-on to the Tool being in the CHARACTER (the config's own comment predicts
+# 13.2 s; the remainder is this script's 2 s poll granularity plus the depart teleport and the
+# equip). The old `sleep 20` left 2-3 s.
+gunwait=0; g1=0
+if [ "$gunpoll" -eq 1 ] && [ "$nolobby" -eq 0 ] && [ "$lobbyfail" -eq 0 ]; then
+	t1=$(date +%s)
+	while [ "$gunwait" -le "${SMOKE_GUN_WAIT:-50}" ]; do
+		g1=$(python ftplay.py client wq.luau 2>/dev/null | grep -c "equipped tool")
+		gunwait=$(( $(date +%s) - t1 ))
+		[ "$g1" -ge 1 ] && break
+		sleep 2
+	done
+	echo "gun in hand at +${gunwait}s after the step-on: g1=$g1"
+else
+	g1=$(python ftplay.py client wq.luau 2>/dev/null | grep -c "equipped tool")
+fi
 gr1=$(python ftplay.py server ground.luau 2>/dev/null | tail -1)
 python ftplay.py consolefull > smoke-console-boot.txt 2>/dev/null
-sleep $((S-15))
+# The waits above are measured now, not fixed, so the END check is held at S seconds after Play
+# rather than at a constant distance from a sleep that no longer exists.
+rest=$(( S - ($(date +%s) - t0) )); [ "$rest" -gt 0 ] && sleep "$rest"
 g2=$(python ftplay.py client wq.luau 2>/dev/null | grep -c "equipped tool")
 gr2=$(python ftplay.py server ground.luau 2>/dev/null | tail -1)
 snd=$(python ftplay.py server snd.luau 2>/dev/null | tail -1)
 gr3=$(python ftplay.py server respawn-ground.luau 2>/dev/null | tail -1)
 python ftplay.py consolefull > smoke-console.txt 2>/dev/null; cat smoke-console-boot.txt >> smoke-console.txt
+# L-043, recurring since 2026-10-27: both console files are fixed names, so back-to-back runs
+# destroy each other's stacks. Keep a stamped copy of each before the next Play can start.
+st=$(date +%m%d-%H%M%S); cp smoke-console.txt "smoke-console-$st.txt" 2>/dev/null
+cp smoke-console-boot.txt "smoke-console-boot-$st.txt" 2>/dev/null
+echo "console kept as smoke-console-$st.txt"
 python ftplay.py stop >/dev/null 2>&1
 stacks=$(grep -c "Stack Begin\|Script .* line [0-9]" smoke-console.txt)
 errs=$(grep -i "error\|invalid argument\|attempt to" smoke-console.txt | grep -vc "^\[camera\]")
 waves=$(grep -cE "\[ForestTest\] (wave|line) [0-9]+:" smoke-console.txt)
-echo "lobby=[$lob] gun in hand @15s=$g1 @${S}s=$g2 | stacks=$stacks errorLines=$errs | waves=$waves | $snd"
+echo "lobby=[$lob] (+${lobwait}s) gun in hand @+${gunwait}s=$g1 @${S}s=$g2 | stacks=$stacks errorLines=$errs | waves=$waves | $snd"
 fail=0
-[ "$lobbyfail" -eq 0 ] || { echo "FAIL: a gun in the lobby"; fail=1; }
-echo "position @15s=[$gr1] @end=[$gr2] respawn+10s=[$gr3]"
+[ "$lobbyfail" -eq 0 ] || { echo "FAIL: a gun in the lobby after ${lobwait}s"; fail=1; }
+# TASK 329a: NO LOBBY IS NOW A FAILURE AND NOT A SKIP. It means the boot was still running -- or the
+# probe never answered at all -- so nothing below this line was ever given a chance, and it is the
+# state that used to report itself as "gun not in hand". The raw answer is in the `lobby-go at` line.
+[ "$nolobby" -eq 0 ] || { echo "FAIL: no lobby after ${lobwait}s -- the boot had not finished, or lobby-go did not answer, so the player was never stepped onto a truck pad (task 329a)"; fail=1; }
+echo "position @after-gun=[$gr1] @end=[$gr2] respawn+10s=[$gr3]"
 case "$gr1 $gr2 $gr3" in *BURIED*|*FLOATING*|*nochar*|*" hp=0 "*) echo "FAIL: a player is not standing on the ground (Karen 10-14: under the terrain, dying each round)"; fail=1;; esac
 case "$gr1|$gr2|$gr3" in *ground*\|*ground*\|*respawn-ground*) ;; *) echo "FAIL: ground probe returned nothing"; fail=1;; esac
 [ "$g1" -ge 1 ] && [ "$g2" -ge 1 ] || { echo "FAIL: gun not in hand"; fail=1; }
```
