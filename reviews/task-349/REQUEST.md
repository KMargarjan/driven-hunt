# Task 349 round 3: close the three round-2 findings

Task: 349
Round: 3
Base: 6fa59255 (origin/main, #365)
Code commit: PENDING

## PLAN (core protocol step 0, committed before any `src/` edit)

**(a) REAL LIFE.** On a driven hunt the guns stand on one line and the beaters push the wood toward
THAT line. Round 2 proved the aim on her path; what is left is that turning it OFF must give back
exactly the drive that was there before, and that the beds must be generated in the frame they are
judged in.

**(b) MEASURED NOW** (round 2, `reviews/task-349/RESULT.md`, three blocking findings; her Forest
Test attributes read at 22:33 UTC tonight, `<runs-dir>/349r3-attrs-start.txt`:
`DHFlag_PLACEMENT_IN_PLACE=false`, `DHFlag_DRIVE_AIMS_AT_PICKED_STAND=false`):
1. `settleAim` latches on `why == "off"`, so with the flag OFF `releaseLine`/`orderGroup`/
   `roarPoint` read a latched `aim.x` where they used to read `ForestTest.hunterStandX()` live.
2. `aimAcross` is non-zero with no aim (`aimNow` substitutes `hunterStandX()` for a nil `x`), so the
   field's box is widened on the OFF path too.
3. `restSpot`'s gate is measured with `driveZ` while `restPoint` still generates candidates on the
   main road, so with the aim ON no bed passes its band.

**(c) TARGET.** OFF is today's drive, measured: with the flag OFF at the code commit, stand 4 and
stand 11 must give the same table as main `6fa59255`, and the field box must equal
`Data.fieldFor(layout)` exactly. With BOTH flags ON from stand 11: beds placed > 0 and `released`
within 10% of the main-line drive. 10% is the Director's figure and the right one: it says the
flank drive is the same drive translated.

**(d) LEVER.** One predicate -- is this aim REAL -- read by every consumer.
```
src/server/ForestTest/init.luau:1017:	return { x = aim.x or ForestTest.hunterStandX(), dz = aim.dz, why = aim.why }
src/server/ForestTest/init.luau:1031:	return aim.x - chosen.layout.centre.X
src/server/ForestTest/init.luau:1062:	if aim.why == "nobody locked" then
src/shared/ForestTest/init.luau  / restPoint: ForestTest.roadZ(x, resolved) + north   (the generator)
src/server/ForestTest/init.luau:1900 / restSpot: local dz = at.Z - ForestTest.driveZ(at.X)  (the gate)
src/server/ForestTest/init.luau:2748 / signalPoint: ForestTest.hunterStandX() + Data.roadZ
```
`rosterAim` already answers `x = nil` for every non-aim; the fix is to stop throwing that away.

**(e) HOW IT WILL BE MEASURED AFTER.** The same instrument as round 2 -- `<runs-dir>/349-arm.luau`
at 1 Hz in her Forest Test, `349-table.py`, `349-gaps.py` -- plus a bed count read off the drive's
own placement line, and the three delete-the-producer runs (L-093), one per fix.
