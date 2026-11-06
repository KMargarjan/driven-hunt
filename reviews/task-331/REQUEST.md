# Task 331 -- a wounded range animal must never keep the lane; the next pass is a fresh animal

Task: 331
Round: 1
Base: b59e065b (main)
Code commit: (filled in below once the harness has run)

## PLAN (core quality protocol)

(a) **REAL LIFE.** A shot animal that can no longer run does not keep the stand, and at a range a
target that has stopped being a target is taken off the lane. Karen, 2026-11-06 ~10:30 UTC:
*"once I hit animal and it's going to left or right and it ends on next has to be healthy animal
new one not the same"*; her standing rule, 2026-10-31: *"it runs or walks no matter killed or no it
comes to end new animal comes old gone"*. The number: a rump slug is **55** of the 100-point lethal
scale, which is `crippling` at or past `MORTAL` 50, and `Wound.flightStuds` then gives it 81 studs
-- **about 18 s** of crawling at `CRIPPLE_SPEED` 4.5 before the wound finishes it
(`src/server/Boar/init.luau`, the `rear` row's own comment).

(b) **MEASURED NOW, in Karen's Forest Test, at main.**
- `<runs-dir>/331-ft-cripple.txt` (station 2, walk, rump slugs through
  `Shotgun.Remotes.FireRequest`): two rump hits landed (`BOARD ... zones=[rear=1]`, then `rear=2`).
  After each, the animal **stopped crossing and circled inside the span** -- x 2844.9..2855.0 and
  z -3205.5..-3215.4 for `Boar16`, x 2777.3..2787.9 for `Boar17` -- and **no new animal was
  released for 18.3 s and 18.2 s** (hit 11.92 -> next animal 30.06; hit 32.55 -> next 50.74).
  A healthy pass over the same span takes 23.0-24.0 s and the next animal follows in 0.00 s.
- `<runs-dir>/331-ft-walk-body.txt` (same place, 10 passes, 3 hits landed): **10 passes, 10
  DISTINCT instance ids**, gap median 0.00 s. So "the next pass was the SAME animal" is **refuted
  as instance reuse**: no pass ever reuses pass N's animal. What Karen sees is the animal she hit
  **holding her lane** instead of leaving it, which her sentence says in her own words.
- `<runs-dir>/331-dev-rear.txt`, `331-dev-walk*.txt` (DEV ONLY, 16 passes, 2 hits): same -- every
  pass a distinct instance, gap <= 0.06 s.

(c) **TARGET.** An animal the range can no longer steer loses the lane within **4.0 s** of its last
accepted order; the animal that follows is a **different instance at full health (wound 0)**; the
pass-to-pass gap stays at today's median (0.00 s measured; the dispatch's "about 1 s").
Why 4.0 and not another number: `WOUND.BOLT_SECONDS = 3.0` is the longest stretch in which a
HEALTHY pass legitimately refuses the range's steering -- the bolt after a hit, during which
`Runtime:flying` is true and `scan` skips `order` on purpose. 4.0 s clears that by 1.0 s (33%) and
is 22% of the measured 18.3 s hole, so a grazed animal still finishes its pass ("it runs or walks
... it comes to end") and a crippled one goes.

(d) **LEVER.** `boars.leadTo`'s own return value, already read in `Range.order`, and `boars.flying`,
already read in `Range.scan` -- no new seam, no new reader of the Brain.
```
$ grep -n "leadTo\|flying" src/server/Range/init.luau
1259:	if boars.leadTo(trial.targetId :: string, point, speed) then
1260:		state.stats.leadTos += 1
1384:		if boars.flying ~= nil and boars.flying(trial.targetId) then
1385:			state.stats.skippedFlying += 1
```
and the refusal itself: `src/server/Boar/Brain.luau`'s `Brain:leadTo` returns `false` for
`state == "CRIPPLED"` (and `GONE`/`DOWN`), which is exactly the state a rump hit produces.

(e) **MEASURED AFTER** with the same two probes, in the same place, at the code commit.
