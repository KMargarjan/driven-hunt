PASS (item 1, 2 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: both items are core (animal
behaviour). Item 1 (*"animals go on the side after jum"*) and item 2 (*"stuck for few seconds
hitting tree"*) were MEASURED in Karen's place after the change -- `344-AFTER-C1.txt` /
`344-AFTER-A2.txt`, with `344-verify.luau` reading the shipped numbers off the running build -- but
NEITHER was SEEN in her place after the fix. The request says so itself: *"344-F1 AFTER and 344-F2
NOT OBTAINED"*, with three measured reasons (`screen_capture` ignores its camera arguments in a Play
session; a server `PivotTo` on a hunter is undone by the stand keeper; at 48 studs no stag landed in
front of the stand in 240 s). The only opened frame is the BEFORE one (a stag broadside on the road
verge, 52.3 deg facing-vs-travel). So what Karen will judge by playing -- a landing stag drawn on its
line, and an animal that steps round a trunk instead of pushing into it -- rests on probe counters,
not on a frame anyone looked at. Line 1 carries that, and nothing in this verdict should be read as
the after picture having been seen.

Verified against the repo, not the request:
- the harness line names the request's `Code commit:` 04243c64, is "(clean tree)", and
  `paperwork-after-code-commit.txt` says only `reviews/task-344/REQUEST.md` followed it. selene 0/0,
  stylua clean, rojo build exit 0.
- claim 2's arithmetic holds in the code: `LEAP.SECONDS` is 0.75 (`init.luau`, `MODEL.LEAP`),
  `Body.leapAir("stag")` = 2*sqrt(2*6.0*196.2)/196.2 = 0.4946 from `APEX_STUDS = { stag = 6.0 }` and
  `GRAVITY = 196.2`, so the refreshed window covers (0.75-0.495)+0.8 = 1.055 s of ground. The
  refresh sits at `intent.leaping = self._leapFor > 0` and the `math.min` after the gait block, so
  the cap sees the refreshed value on the same tick and binds `TURN_RATE` *and*
  `RUN_TURN_DEG * LINE.TURN_SCALE`.
- the new keys reach the animal that bounds: `Boar.speciesConfig` does not replace `MOVE`,
  `scaledByWary` does not touch it, and `leapByKind` / `edgeByKind` clone it as a delta --
  `deer.spec`'s own `world.MOVE.WEDGE_SECONDS = 9.75` -> `stag.WEDGE_SECONDS == 9.75` case pins that
  wire. `LAND_TURN_DEG = 90` and `LAND_SECONDS = 0.8` therefore arrive on a live stag.
- delete the producer, item 1 (`deer.spec` "LANDS RUNNING STRAIGHT ON"): remove the `math.min` and
  both runs slew at `CONFIG.TURN_RATE` (4 rad/s -> 3.8197 deg/frame * 60 = 229.18, which is exactly
  the note's 229.1865), so `expect(capped <= LAND_TURN_DEG + 0.5)` fails. Remove the
  `if intent.leaping then self._landFor = ...` refresh, or `LAND_TURN_DEG` from `MOVE`, and the same
  assertion fails. Shorten `LAND_SECONDS` below the measured 0.7 s and it fails. The two sides are
  not one identity: `free` comes from `run(nil)`, where `(config.MOVE ~= nil and
  config.MOVE.LAND_SECONDS) or 0` evaluates to 0 and the window never opens. `free > LAND_TURN_DEG`
  pins the cap below the uncapped rate, so raising `LAND_TURN_DEG` cannot buy a green.
- delete the producer, item 2 (`boar_move.spec` "SIDESTEPS AGAIN INSIDE 1.5 s"): with
  `WEDGE_SECONDS` back at 0.75 the straddling window carries ~24 studs/s of SETTLE travel and cannot
  fire, so the earliest first fire is >= 0.75 s and `expect(turns[1] <= 0.6)` fails. With the
  `_wedgeFrom` re-base removed, the post-hold window divides 1.0 s of 0.4-studs/s slide by its own
  0.4 s = 1.0 studs/s >= `WEDGE_SPEED`, so `expect(turns[2] <= 1.6)` fails. Neither assertion
  survives either half.
- 0.5 deg/s of slack on a measured 90.0068 is not float-decided (verdict 284): the slew bounds one
  frame at exactly `rad(90)/60`, the overshoot is 0.0068 of the 0.5 allowed, and the other side of
  the comparison is 229.

## Notes (non-blocking)
- `src/server/Boar/Brain.luau`, the `_updateWedge` call site — "...AND THE FAST ONE (task 150), which
  answers in 0.75 s where `_updateStuck` takes up to four" is stale: the window is 0.4 s since this
  change, in a file this change edits. One number.
- `src/server/Bots/init.luau` (`Boar.CONFIG.MOVE.WEDGE_SECONDS` 0.75) and
  `docs/research/2026-10-19-bots-unstuck.md` (the `STUCK_FAST_SECONDS` 0.8 and
  `RECOVER_HOLD_SECONDS` 2.2 derivations both quote the boar's 0.75) now cite a number the repo no
  longer holds. Citations, so notes -- but the bots' 0.8-s detector was derived AS "a little longer
  than the boar's window" and the boar's is now half of it; worth a line wherever that row is next
  touched.
- `reviews/task-344/REQUEST.md` claim 5 overstates one half: "deleting the `_wedgeFrom` re-base means
  no second turn ever fires" is not what the code does. The window after the inflated one reads
  0.4 studs/s and fires at ~1.9 s; the case dies on `turns[2] <= 1.6`, not on `#turns >= 2`. The
  conclusion (the case dies) is right.
- `tests/server/deer.spec.luau`, the new case — it runs with `PACE.ENABLED` at its shipped `false`,
  so the rate the cap binds is `CONFIG.TURN_RATE` (229 deg/s) and not the
  `RUN_TURN_DEG * LINE.TURN_SCALE` 352 deg/s the whole premise is about. That is deliberate (it is
  what refuted cycle 3's placement inside the PACE block, and commit 8e1b37f7 removed the PACE lines
  for exactly that reason), but it leaves the live configuration -- PACE on, `ordered` true, 352
  deg/s -- covered only by the live probe. Queue a second half of the case with PACE on and a
  waypoint list, asserting the capped rate there too.
- `reviews/task-344/REQUEST.md` claim 3 and the same sentence in `Brain:step`'s comment -- "the DEV
  world has no road, so `_landFor` is 0 there for ever" -- state a reason the code does not support:
  the spook-bound branch sets `self._leapFor = boundLeap.SECONDS` with no road anywhere in it. What
  actually keeps the DEV window shut is `MODEL.LEAP.ENABLED = Flags.isOn("DEER_ROAD_LEAP")` (default
  false) and `MOVE.BOUND_ON_SPOOK` behind `STAG_BOUND_ON_SPOOK` (default false). The conclusion --
  nothing changes in a world that never publishes a bound -- holds; the reason written beside it is
  the wrong one, and it is in a code comment, so it will be read as true.
- `src/server/Boar/init.luau` — `MOVE.LAND_SECONDS` (0.8, the landing hold) and
  `MODEL.LEAP.LAND_SECONDS` (0.708, the clip frame the hooves touch down on) are now one name for two
  unrelated numbers, both read inside `src/server/Boar/`, and `deer.spec` asserts on both under that
  short name within 400 lines of each other. `LAND_HOLD_SECONDS` would cost one rename and remove the
  trap.
- The residual worst case, and the one thing I would look at before anything else: 41.7 deg (C1) and
  86.1 (A2) against the 30-deg target, cause named in the request -- the 90-degree wedge/stuck
  rotation applied to `_desired` AFTER the slew and deliberately uncapped. This change made that
  rotation MORE frequent: `WEDGE_SECONDS` 0.75 -> 0.4 plus the `_wedgeFrom` re-base lets a pinned
  animal fire one every ~1.0 s (0.4 window + 0.6 hold), where before the hold's travel inflated the
  next window and suppressed the retry -- which is the fix, but it is also three times as many
  instant 90-degree setpoint jumps for the drawn body to lag behind, i.e. item 1's symptom on a path
  item 1's probe does not sample (it measures only after a bound). The per-drive stuck counts fell
  (8 -> 2, 16 -> 2) and the landing angles fell, so there is no measurement saying it got worse --
  but the next round's measurement should be facing-vs-travel across the WHOLE drive, not only after
  a bound, and the lever is suppressing or ramping that rotation while `_landFor > 0`.
- `tests/server/boar_move.spec.luau`, the new case — the >= 45-deg-per-frame detector cannot tell a
  wedge sidestep from `_updateStuck`'s own 90-degree turn, which is live here (`moveConfig(true)`
  enables PACE, `ordered` is false, `STUCK_TIME` is 2 s) and is the likeliest source of the note's
  third entry at ~2.03 s. The two assertions only read `turns[1]` and `turns[2]`, which are the
  wedge's, so the case is sound; one sentence in the comment would stop a future reader counting all
  four entries as sidesteps.

---
REVIEWER verdict on commit `0d434e919ecc78bcfd429b77b6977f8ec9ecb6c0` (round 1) · 2026-11-10 12:49 UTC · session cost $3.57, 37 turns · written by tools/agents.py
