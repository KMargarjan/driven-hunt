# Task 349 round 3: close the three round-2 findings

Task: 349
Round: 3
Base: 6fa59255 (origin/main, #365)
Code commit: 956d6e5b0a42565943a431579de25f3084750a2b

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

## MEASURED, her Forest Test, C1, hunter, stands picked by REAL clicks (one re-pick mid-drive)

```
[harness] PASS: 34/34 checks @ 956d6e5b0a42565943a431579de25f3084750a2b (clean tree) scope=all
```
`test2`: N/A -- no changed file is in `TWO_PLAYER_PATHS`.

One 299 s drive each, same instrument. **Every row below the first two is at the code commit.**
`inView` = samples with an animal inside 120 studs on a clear ray from her own eye.

| run | commit | stand | flag | first | median | max | inView | released | peakLive | stepAvg | escaped |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `M4` | 6fa59255 | 4 | (none) | 11 s | 6 s | 35 s | 213/288 | 121 | 33 | 3.528 | 112 |
| `M11` | 6fa59255 | 11 | (none) | **never** | -- | -- | **0/289** | 129 | 34 | 3.618 | 97 |
| `B4f` | 956d6e5b | 4 | OFF | 11 s | 5 s | 31 s | 222/287 | 121 | 33 | 3.628 | 112 |
| `B11f` | 956d6e5b | 11 | OFF | **never** | -- | -- | **0/289** | 120 | 35 | 3.579 | 91 |
| `B7f` | 956d6e5b | 7 | OFF | 10 s | 6 s | 16 s | 219/288 | 130 | 32 | 3.510 | 84 |
| `A4f` | 956d6e5b | 4 | ON | 14 s | 3 s | 40 s | 216/288 | 121 | 33 | 3.577 | 112 |
| `A7f` | 956d6e5b | 7 | ON | 10 s | 5 s | 25 s | 207/288 | 121 | 33 | 3.523 | 86 |
| `A11f` | 956d6e5b | 11 | ON | 15 s | 4 s | **46 s** | **184/288** | 115 | 26 | 2.888 | 96 |
| `X11d` | 956d6e5b | 11 | ON + `PLACEMENT_IN_PLACE` | 193 s | 3 s | 4 s | 92/289 | 77 | 19 | 3.838 | 59 |
| `P11` | 956d6e5b | 11 | OFF + `PLACEMENT_IN_PLACE` | **never** | -- | -- | **0/289** | 91 | 24 | 4.694 | 60 |

## Claims

1. **OFF IS TODAY'S DRIVE, measured on both stands.** `B4f` against `M4`: 222/288 against 213/288,
   median 5 s against 6 s, released 121 against 121. `B11f` against `M11`: **never, 0 of 289, both**.
   Decision 1 and 2.
2. **A pick changed mid-drive still aims the next release with the flag OFF.**
   `forest_stand.spec` locks stand 2, reads the aim, re-picks stand 6 and reads it again:
   `aimStandX` answers `standX(2)` then `standX(6)`, `settleAim` returns `latched = false` both
   times, and the field's box equals `Data.fieldFor(layout)` field for field.
3. **The corner stand still has its drive.** `A11f` 184 of 288 samples against `B11f`'s 0 of 289,
   first sighting 15 s, median gap 4 s.
4. **`aimAcross` is 0 unless the aim is real, and `promote` passes `0, 0`.** Claim 2's case asserts
   the whole box. The across-union is now the band's own extent (`AIM_BAND_HALF_STUDS` 155), not a
   half-span.
5. **The three producers were deleted and run (L-093), one per fix.** No-latch guard ->
   `failed [server] forest_stand.spec:152` (`expect(latched).to.equal(false)`). `aimAcross`'s guard
   -> `failed [server] forest_stand.spec:293` (`expect(ForestTest.aimAcross(second)).to.equal(0)`,
   raised as `attempt to perform arithmetic (sub) on nil`). `restPoint`'s shift ->
   `failed [server] forest_stand.spec:324`. All three reverted, tree clean.
6. **`signalPoint` is aimed in x and z** (decision 4).
7. **The frame.** `<runs-dir>/A11f-sighting.png`, from stand 11's own eye (-4504.4, 133.8, -4087.3)
   50 s into the run, when the probe measured a hind 101 studs out on a clear ray. I opened it:
   hunter's first-person view, shotgun barrel and glove bottom-left, deep grass, the yellow verge,
   two tracks running north, conifers either side, open sky; HUD `DRIVE 1 / 4:39 TIME / 0 ANIMALS /
   HUNTER / $13500`. **`A11f-left.png` is its left edge at 7x: one red hind, head down, at the
   treeline.** That is the animal the probe named.

## What I could not verify, and one correction

- **MAX GAP AT THE CORNER IS 46 s AGAINST A 40 s TARGET. NOT MET.** `A11f`. Stands 4 and 7 are
  inside it (40 s and 25 s).
- **`peak live` 26 at the corner against the main line's 33 is -21%, outside the dispatch's 10%** --
  in the direction of less load (`stepAvg` 2.888 against 3.577, cost down 19%). `released` 115
  against 121 is -5% and inside it.
- **BEDS ARE 0 WITH `PLACEMENT_IN_PLACE` ON, AND THAT IS NOT THE AIM'S DOING.** Decision 3 asked for
  beds > 0. `X11d` (both flags) places 13 rows, beds 0, 85 `nobed`. **The control `P11`
  (placement ON, aim OFF) is also beds 0, 83 `nobed`** -- so this cell's placement path lays no bed
  with or without the aim, and the premise of that target is refuted rather than met. What the aim
  does with placement on is still the task's own number: stand 11 goes from `never` to 92 of 289.
  The frame fixes are in and proven by claim 5's third deletion; the bed failure itself is the
  placement system's (345e/f), which this task is told is not mine.
- **A CORRECTION TO ROUND 2.** Round 2's request said "no gap over 20 s" for `A11d` and `A4`. That
  came from `349-table.py`/`349-gaps.py`, which split the names field off `minD=` while the row had
  gained `step=` and `fate=` -- so every sample read as occupied. `<runs-dir>/349-count.py` parses
  by field name and is the instrument for every number above. Round 2's `inView`, `released`,
  `peakLive`, `stepAvg` and `escaped` are unaffected; its gap figures were wrong and are withdrawn.
- The roster SPLIT branch is still proven as the pure rule only: two real Players on different
  frames cannot be reached by a one-player harness and `src/server/ForestTest/` is not in
  `TWO_PLAYER_PATHS`. Adding it is the Director's call.
- Karen has not played it. The flag is OFF in her Forest Test, and `PLACEMENT_IN_PLACE` is back to
  `false` (attribute diff against this session's own 22:33 read is empty).
