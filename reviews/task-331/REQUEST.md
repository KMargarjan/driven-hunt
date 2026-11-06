# Task 331 -- a wounded range animal must never keep the lane; the next pass is a fresh animal

Task: 331
Round: 2
Base: b59e065b (main)
Code commit: 9cc0fb633f5e779d961c25933873995d3c42f0f6

```
[harness] PASS: 34/34 checks @ 9cc0fb633f5e779d961c25933873995d3c42f0f6 (clean tree) scope=all
```
`test2`: N/A -- no path in `TWO_PLAYER_PATHS` is touched (`src/server/Range/`, `src/server/Boar/`,
`tests/server/`). No known flake fired; both suites were green (2847 server / 676 client, 0 failed).

**Round 1's blocking finding is fixed, and three of its notes with it.** The fake's animals now
carry a `wound` (0 at spawn, as `Boar.Wound` does); the case writes **55** on the animal whose order
it refuses and asserts the replacement reads **0** while the refused one read 55 -- an assertion
about the ANIMAL, not about the fake's table shape. From the notes: `UNSTEERED_PASS_SECONDS`'
comment no longer rests on `Runtime:flying` (the Reviewer is right -- `SENSE` is off at the range,
nothing wires `hearShot`, `_latchFlight` is unreachable there, so `flying` is never true and 3.0
was never a bound on that branch); a new case covers the reset on an ACCEPTED lead; and the boar
case pins the rump slug's 55 to `Boar.CONFIG.WOUND.DAMAGE.rear.Slug` and asserts it is under
`LETHAL` and not a carcass. **The live proof stands at this commit**: `git diff 98263b84 9cc0fb63
-- src/` is comment-only (no non-comment line changed), so the 3.89 / 3.86 / 3.98 s readings below
are readings of this code. The three notes left for `TASKS.md` are the design-doc delta
(`docs/design/shooting-range.md` section 6 -- not mine, dispatch), the untested flying branch, and
the merge note about an unsteered animal being despawned where it stands.

## PLAN (core quality protocol)

(a) **REAL LIFE.** A shot animal that can no longer run does not keep the stand, and at a range a
target that has stopped being a target is taken off the lane. Karen, 2026-11-06: *"once I hit animal
and it's going to left or right and it ends on next has to be healthy animal new one not the same"*;
her standing rule, 2026-10-31: *"it runs or walks no matter killed or no it comes to end new animal
comes old gone"*. The number: a rump slug is **55** of the 100-point lethal scale, which is
`crippling` at or past `MORTAL` 50, and `Wound.flightStuds` then gives it 81 studs -- **about 18 s**
of crawling at `CRIPPLE_SPEED` 4.5 (`src/server/Boar/init.luau`, the `rear` row's own comment).

(b) **MEASURED NOW, in Karen's Forest Test, at main (b59e065b).** `<runs-dir>/331-mid-BEFORE.txt`,
station 2, walk, rump slugs through `Shotgun.Remotes.FireRequest`, each hit taken in the MIDDLE
THIRD of the span: three wounded animals **held the lane 20.78 / 20.83 / 20.76 s** after the hit
(the ~18 s crawl plus `CARCASS_SECONDS`), against a healthy pass of 23-24 s and a pass-to-pass gap
of 0.00 s. `<runs-dir>/331-ft-cripple.txt` is the first reading of the same thing (18.3 s and
18.2 s from the hit to the next animal, with the hits at `BOARD ... zones=[rear]`).
**The dispatch's premise is refuted in one part and confirmed in the other**:
`<runs-dir>/331-ft-walk-body.txt`, 10 passes in her place at main, is **10 DISTINCT instance ids**
-- no pass ever reuses pass N's animal, and `<runs-dir>/331-dev-rear.txt` (DEV ONLY) says the same
over 16 more. What Karen sees is the animal she hit **holding her lane** instead of leaving it.

(c) **TARGET.** An animal the range can no longer steer loses the lane within **4.0 s** of its last
accepted order; the animal that follows is a different instance at **wound 0**; the gap stays at
today's median. Why 4.0 (**corrected in round 2**, Reviewer note 3): the only refusal that reaches
this range is `CRIPPLED`, and it is permanent, so any positive bound ends the hold -- `Runtime:flying`
is never true here (`RangeBoot` sets `SENSE.ENABLED = false`, `world.threats` is empty and nothing
wires `hearShot`, so `_latchFlight` is unreachable) and 3.0 was never a bound on that branch. 4.0 is
the shortest value comfortably past the one TRANSIENT the animal system has after a hit,
`WOUND.BOLT_SECONDS` = 3.0, so that if the flying skip ever does become reachable here a bolting
animal keeps its pass; and it is 19% of the 20.8 s the lane was held at main.

(d) **LEVER.** `boars.leadTo`'s own return value, already read in `Range.order`, and `boars.flying`,
already read in `Range.scan`:

```
$ grep -n "leadTo\|flying" src/server/Range/init.luau   (at main)
1259:	if boars.leadTo(trial.targetId :: string, point, speed) then
1260:		state.stats.leadTos += 1
1384:		if boars.flying ~= nil and boars.flying(trial.targetId) then
```

and the refusal itself: `Brain:leadTo` in `src/server/Boar/Brain.luau` returns `false` for
`state == "CRIPPLED"` (and `GONE`/`DOWN`) -- the state a rump hit at or past MORTAL produces.

(e) **MEASURED AFTER**: the same probe, the same place, at the code commit.

## Iteration (measure -> change -> re-measure, all in HER place, same instrument)

| # | change | measured: hold from the hit to the animal leaving the lane | distance to target |
|---|---|---|---|
| 1 | none (main b59e065b) | 20.78 / 20.83 / 20.76 s; next animal 20-21 s later | the defect |
| 2 | first reading, `331-ft-cripple.txt` at main, hit anywhere in the span | 18.3 / 18.2 s to the next animal | the same defect, found |
| 3 | `UNSTEERED_PASS_SECONDS = 4.0` at the code commit | **3.89 / 3.86 / 3.98 s**, next instance always different, `Wound` 0 at spawn | met |
| 4 | the same code, two more runs taken for the frames | **3.93 / 3.78 / 3.85 s** | met, repeatable |

## Claims

1. **The cause is `Brain:leadTo` refusing a CRIPPLED animal, not the range's spawn bookkeeping.**
   Verify: `Brain:leadTo` returns false for `state == "CRIPPLED"`; `WOUND.CLASS.rear` is
   `crippling`; `Brain:_reactToHit` sets CRIPPLED at or past mortal. The animal then circles inside
   the span, so `passOver` (it never leaves) and `stalled` (it DID enter) can never fire --
   `331-mid-BEFORE.txt`.
2. **Instance reuse is refuted.** `331-ft-walk-body.txt`: `DISTINCT ids over 10 passes = 10`,
   `GAPS n=9 min=0.00 median=0.00`. The dispatch's wording ("the next pass was the SAME animal") is
   not what the game does; the wounded animal KEEPING the lane is.
3. **An unsteered animal now loses the lane in 4.0 s.** Verify: `tests/server/range.spec.luau`,
   "ends the pass of an animal it can no longer steer, and the next one is fresh" -- it refuses the
   order through the fake's `refuseLeadIds`, asserts the animal is STILL his at 3 s, gone past the
   bound, `lastClear == "range pass unsteered"`, and the next id different. It bites: at main
   neither `UNSTEERED_PASS_SECONDS` nor `unsteeredClears` exists and the animal is never cleared.
4. **A pass that is still being steered is never cut.** Same file, "never takes an animal that is
   still accepting its orders": 8 s, several whole passes, `unsteered == 0` and
   `unsteeredClears == 0`. Without it a plain 4 s timer would pass claim 3. And, from round 1's
   note 5, "forgets the refusals an accepted order has answered": 3 s refused, ONE accepted order,
   3 s refused again -- 6 s of refusal in 6.3 s and the animal is still his. Delete
   `trial.unsteeredFor = 0` from `order` and that case fails.
5. **The next animal is fresh, and that is readable live.** `Body` publishes `Wound` on the trunk,
   0 at birth (`Body.create`) and the damage after a hit (`Runtime:takeHit` -> `Body.setWound`).
   Verify: `tests/server/boar_model.spec.luau`, "publishes the wound on the animal, 0 at birth and
   the damage after a hit"; and live, `331-mid-AFTER.txt` reads `wound=55` on the animal that was
   hit and `woundAtSpawn=0` on every animal that replaced one.
6. **Measured in her place at the code commit**: 3.89 / 3.86 / 3.98 s hold against main's
   20.78 / 20.83 / 20.76 s, same probe (`<runs-dir>/331-mid.luau`), same station, same pace, hits in
   the same middle third. The gap after an unsteered clear read **0.06 s** (`331-mid-AFTER.txt`, the
   one row whose next animal the probe did not swallow -- see "what I could not verify").
7. **321a(g) is closed.** `clearId` now drops a carcass id when `clearOne` answers false (which can
   only mean the runtime does not have that id), so `mineIdsFor` cannot publish a dead id for the
   rest of the session. Verify: `range.spec`, "drops a carcass id its runtime says it does not have".
8. **Nothing else about a pass changed.** `passOver`, `stalled`, the kill branch, `CARCASS_SECONDS`
   and task 324's carcass collision group are untouched; the harness is 34/34 with 2844 server
   assertions, including every task 319 / 321 / 324 case.

## Frames (opened and described)

- `<runs-dir>/331-F0-b3.png` (**main**, shooter's eye at station 2, camera 9 studs up and 14 back so
  the post does not block the lane): the hit card bottom-left reads **HIT - SLUG** with the red dot
  on the boar silhouette's **rump**, and on the lane there are **TWO** animals --
  `331-F0-b3-zoom.png` at 4x shows one standing broadside (left) and one **lying on its side**
  (right). The probe's nearest lane reading, 4 s earlier, had `Boar10 x=2850 z=-3211` after a rump
  hit, having moved 5 studs in 8.5 s where a walk covers 38. The lying animal is from a moment that
  reading does not cover, so it is named as what the picture shows and not as an identified id.
- `<runs-dir>/331-F1-d.png` (**the fix**, same place, eye on the mat): one boar on the lane,
  broadside, in front of the berm -- the probe's bracketing reading is
  `Boar45 x=2811 z=-3219 wound=55`, the wounded animal inside the 4 s it is allowed, drifted 4 studs
  off the lane line (Karen's *"going to left or right"*).
- `<runs-dir>/331-F1-s5.png` (**the fix**): the same lane with **one** animal on it, walking
  broadside, and nothing else; the readings either side of that capture are `Boar14 x=2852 wound=0`
  and `Boar14 x=2814 wound=0` -- the fresh animal crossing after the wounded one was taken.

## What I could not verify

- **One frame holding both states at once is NOT OBTAINABLE under the fix**, and that is the fix:
  the wounded animal is destroyed and the next released on the SAME 10 Hz tick (gap 0.06 s), while a
  StudioMCP capture round trip measured 4-8 s. The pair above is the before and the after instead.
  `331-F1-s2.png` was captured across that transition and shows an empty lane.
- **The gap after an unsteered clear is one reading, not three.** `331-mid.luau` records a new id
  before it closes the wounded row, so when the replacement arrives on the same tick the probe
  attributes the row to the animal AFTER it (GAP 23-24 s in two of three rows). The 0.06 s row is
  the one where that did not happen, and `331-ft-walk-body.txt`'s `median 0.00` over nine passes is
  the independent reading.
- **Real keystrokes**: every shot went through `Shotgun.Remotes.FireRequest` and every station pick
  through `Range.remotes().RangeRequest` from a client probe, not a real mouse. No control in this
  task changed.
- **Karen has not seen it.** The fix is proven in her place by probe and frame; she has not played it.
