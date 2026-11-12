PASS (item 4 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the core item on this branch is
where animals are released, bedded and judged -- claim 4's three stand-11 flag-ON drives (`N1`/`N2`/
`N3`) and the aimed drive itself. Karen has not seen any of it: the request says so ("Karen has not
played any of it. The flag is OFF in her Forest Test"), `DHFlag_DRIVE_AIMS_AT_PICKED_STAND=false` in
her place, and the only frames are round 3's `A11f-sighting.png` / `A11f-left.png`, described in
prose and not seen by me. What exists in her place is a PROBE's counted output, not her screen. The
flag must stay OFF until the Director accepts the 46 s max gap (`N2`) against his own 40 s target and
the -21% `peak live`.

Harness/claim consistency checked: `[harness] PASS: 34/34 checks @ 7950974d... (clean tree)
scope=all` names the request's `Code commit:`; `paperwork-after-code-commit.txt` says only `TASKS.md`
and `reviews/task-349b/REQUEST.md` changed after it. selene/stylua/rojo all exit 0. Claim 3's three
citations are the right lines (`:365` `expect((why).band > 0)`, `:289` `expect(latchedFirst)`, `:383`
`expect((after).ground > 0)`) and each one does die with its producer: deleting `refusals.band += 1`
leaves `band` at 0; restoring `if aim.why == "nobody locked"` makes the first `settleAim(false)`
after `newDrive` latch (`why` is "off", so it falls through to `state.aimSettled = true`); dropping
`dz or 0` from `restSpot`'s `Data.restPoint` call puts every candidate at `150 - 975 +- 64`, which
the 120..180 band refuses on the band arm, so `ground` stays 0.

## Notes (non-blocking)
- `src/server/ForestTest/restSpot` + `tests/server/forest_stand.spec.luau` ("counts why a bed was
  refused") — THE STRONGEST NOTE: only two of the six increments are pinned. Delete
  `refusals.swept += 1`, `refusals.lane += 1`, `refusals.zone += 1` and `refusals.unseen += 1` and
  no case changes its verdict -- case (1) asserts `lane`/`zone` are *0* and case (2) asserts only
  `ground > 0`. The request's claim 1 ("The counters count") is shown for `band` and `ground`; its
  own quoted note reads `swept=0 ... lane=0 zone=0 unseen=0`. One band with `laneSideStuds = 0`
  would bite the lane arm; otherwise say in the case's header which arms are unasserted.
- `tests/server/forest_stand.spec.luau` / same case — the production call site is still unpinned one
  hop up: the case drives `ForestTest.restSpot(standX, spec, aimed, shift)` directly, so removing
  `aim.dz` (or `ForestTest.aimStandX(aim)`) from `bedSpot`'s `restSpot(...)` call leaves every line
  green. The dispatch allowed `bedSpot` OR `restSpot`, so this is within scope as written, but
  `bedSpot` is the function production calls.
- `tests/server/forest_stand.spec.luau` / same case — `expect((after :: any).ground > 0)` is
  unconditional, while five lines below it the case branches on `spot ~= nil` for a place that HAS
  C1 ground. In such a place ring 0 (depth exactly 150, inside 120..180) can be accepted and
  `ground` stays 0, so the case turns red where the feature works. `expect(((after).ground > 0) or
  spot ~= nil)`, or assert `band == 0` as the frame reading, would hold in both places.
- `tests/server/forest_stand.spec.luau` / "keeps the deepest release of every stand inside its own
  cell" — two of its three assertions are true by construction of the thing they measure:
  `box.minX = math.min(bounds.minX, centre.X + across - 155)` with `across = at.X - centre.X`, so
  `at.X >= box.minX and at.X <= box.maxX` holds for ANY non-negative `AIM_BAND_HALF_STUDS` (it does
  still fail if the whole x union is deleted); and `box.minZ <= Data.boundsOf(layout).minZ` cannot
  fail at all, since `math.min(a, a + shift) <= a` for either sign of `shift`. The case cannot tell
  155 from 0.
- `src/server/ForestTest/stepPlacement` — it resolves `local aim = aimIn or ForestTest.aim()` and
  then forwards the RAW `aimIn` to `orderGroup(row, now, aimIn)` and `materialise(due, now, aimIn)`.
  Production always hands one in (`step`), so no behaviour today; a caller that omits it (every
  `forest_placement.spec` call) gets `ForestTest.aim()` for the reopen/wake comparison and a
  `settleAim()` latch inside `orderGroup`. Forward `aim`.
- `src/server/ForestTest/newDrive` — clears `state.aimSettled` but not `state.aim`, so
  `signalHeard` -> `signalPoint`, `roarPoint` and `stockWood` read the PREVIOUS drive's frame until
  the next `step` tick settles it. Round 3's note, unfixed; inert while the flag is OFF.
- `src/server/ForestTest/stepPlacement` — the reopen branch still builds
  `atX = ForestTest.hunterStandX() + (row.bedOffsetX or 0)` and the bed line still prints
  `at.X - ForestTest.hunterStandX()` while the bed was generated at `aimStandX(aim) + bedOffsetX`.
  Round 3's note, unfixed; harmless only because `frontNorth` is forced nil whenever `aim.dz ~= 0`.
- `src/shared/Flags/init.luau` / `DRIVE_AIMS_AT_PICKED_STAND.why` — still says "the aim is settled
  at the first release and latched"; `ForestTest.step` calls `settleAim()` every tick, before
  anything is released. Rounds 2 and 3 both noted it.
- `src/server/Boar/init.luau` / `Runtime:setField` header — "it calls `clear()` before `setField`, so
  a drive never holds animals of two fields at once" is still false for `settleAim` -> `applyField`,
  which swaps the field mid-drive with no clear. The swap itself is SAFE (`Brain.new(config,
  self._field, ...)` takes the table by value, so pre-lock main-road animals keep their own exit
  plane), which is exactly why the sentence should name the exception. Boar's owner, not this task's.
- `src/server/ForestTest/ForestTest.aim` — annotated `{ x: number, dz: number, why: string }`, while
  the value carries `real` and `x` is nil on every OFF path.
- `TASKS.md` — the 349 row still reads **ESCALATED ... Builder recommends ONE authorised round for
  findings 1-3 only**, which is the round that is finished and under review here. Paperwork only.

---
REVIEWER verdict on commit `bbae145fa129e9adc6f11eee768e8af66f572e68` (round 1) · 2026-11-12 02:30 UTC · session cost $3.91, 31 turns · written by tools/agents.py
