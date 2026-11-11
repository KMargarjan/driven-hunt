# Task 349: more action from the hunter's stand

Task: 349
Round: 1
Base: 6fa59255 (origin/main, #365)
Code commit: 8939503e18d87d3045874b0170fea5c36f4fb654

Harness, clean tree, at the code commit:

```
[harness] PASS: 34/34 checks @ 8939503e18d87d3045874b0170fea5c36f4fb654 (clean tree) scope=all
```

`test2`: N/A. No file in this change is in `TWO_PLAYER_PATHS` (`src/server/ForestTest/`,
`src/shared/ForestTest/`, `src/shared/Flags/`, `tests/server/forest_stand.spec.luau`).

## What changed

The drive is aimed at the stand she LOCKED, in x and in z, instead of at a point clamped onto the
main line. Behind `DRIVE_AIMS_AT_PICKED_STAND`, born OFF, expires 2026-12-02.

## MEASURED, on her Forest Test, C1, hunter, 3 stands picked by real clicks on the map

One drive each, 299 s each, same cell, same instrument (`<runs-dir>/349-arm.luau`, a client-side
sampler at 1 Hz: an animal counts when it is within 120 studs of her stand AND the ray from her own
eye to it is unobstructed). BEFORE at 6fa59255, AFTER at the code commit; no row blends commits.

| stand | side | run | first sighting | median gap | max gap | peak live | released |
|---|---|---|---|---|---|---|---|
| 4 | main, central | BEFORE `B4b` | 15 s | 6 s | 24 s | 33 | 121 |
| 4 | main, central | AFTER `A4b` | 13 s | 4 s | 39 s | 33 | 121 |
| 7 | main, end | BEFORE `B7` | 9 s | 8 s | 26 s | 33 | 130 |
| 7 | main, end | AFTER `A7b` | 10 s | 6 s | 22 s | 32 | 130 |
| 11 | west flank, corner | BEFORE `B11` | **never** | -- | -- | 35 | 120 |
| 11 | west flank, corner | AFTER `A11b` | 15 s | 11 s | 57 s | 16 | 72 |

Targets: first <= 30 s MET at all three. Median gap <= 20 s MET at all three. Max gap <= 40 s MET at
stands 4 and 7, **NOT MET at stand 11 (57 s)**.

## Claims

1. **The defect is real and it is the corner stand.** `B11-track.txt` line 1 reads
   `neverNearAnyStand=0` and every `t=` row reads `near=0`: in a whole 299 s drive not one of 120
   released animals came within 120 studs of stand 11. Verify: `349-table.py B11`, and
   `grep -c "near=0" B11-track.txt` against the row count.
2. **The cause is in the code, not in the data.** `ForestTest.hunterStandX` clamps a flank x into
   `Data.standSpan` (the MAIN line's), and `releaseLine` builds every release, crossing and exit on
   `Data.roadZ` / `Data.exitZOf` -- the main road's z. Stand 11 is 975 studs north of it.
3. **The lever is the aim frame.** `ForestTest.aimFrame` (`src/shared/ForestTest/init.luau`) is the
   whole rule and it is pure: `dz = standZ - roadZAtStand`. `ForestTest.hunterAim`
   (`src/server/ForestTest/init.luau`) reads the two live facts and the flag; `releaseLine` adds
   `aim.dz` at the four places the main road's frame was used, and skips the beater-line clamp when
   `aim.dz ~= 0`.
4. **A main-line drive cannot move.** `AIM_FLAT_STUDS` = 1 snaps a sub-stud shift to exactly 0, so
   for stands 1-7 `aim.dz == 0` and `aim.x` is the same x the clamp answered -- the released points
   are identical to OFF. Verify: `forest_stand.spec.luau`'s new case asserts `on.dz` **equals 0**
   for every `main` stand and `> 100` for every flank stand.
5. **The case bites if the lever is deleted (L-093).** The flank half asserts a shift of more than
   100 studs; a rule that answered 0 -- which is what `releaseLine` did before this task, and what
   the flag OFF still does -- fails it. Verify: set `aimFrame`'s returned `dz` to 0 and re-run.
6. **The snap was itself measured, not assumed.** At `c88b92b7` (before `AIM_FLAT_STUDS`) the
   main-line stands' worst gap went 24 s -> 49 s (stand 4, `A4`) and 26 s -> 57 s (stand 7, `A7`),
   because a main stand's z is the road's to a thousandth of a stud but not to the bit, so
   `aim.dz == 0` read false and the beater-line clamp was silently dropped. After the snap: 39 s and
   22 s. Verify: `349-table.py A4 A7 A4b A7b`.
7. **The frame.** `<runs-dir>/A7b-sighting.png`, captured from stand 7's own eye
   (-3450.7, 118.1, -5093.5; stand 7 is at -3451, 106, -5094) at the instant the probe measured a
   hind 103 studs out with an unobstructed ray (`A7b-sighting.txt`). I opened it: the hunter's
   first-person view, shotgun barrel and glove bottom-left, the yellow verge across the foreground,
   mown grass and birch wood beyond; HUD `DRIVE 1 / 4:45 TIME / 0 ANIMALS / HUNTER / $13500`. A dark
   brown animal body sits at the centre of the frame -- `A7b-sighting-centre.png` is that centre at
   4x.
8. **The flag cap.** The table held 24 and the tripwire refused the 25th
   (`flags.spec:124 Expected 0, got 1`, measured at `8c88d7db`). `MAX_FLAGS` 24 -> 25 with the
   reason said out loud, which is the route tasks 238 and 345a took.
9. **The stand picks are real clicks.** `349-run.py` reads each row's `AbsolutePosition` out of the
   live `StandList`, converts it with the viewport origin measured off `349-cal2.png`, and clicks it
   with `click.ps1`. Each run's `-pick.txt` / log line shows the row reading `YOURS` afterwards and
   the end-of-run `-stand.txt` reads `char nearest stand <N> at 0 studs`.

## What I could not verify

- **Max gap at the corner stand: 57 s, target 40 s. NOT MET.** The hole is one stretch mid-drive
  (`349-gaps.py A11b:8`); act II's rows are released 145-270 studs out and walk in, and on a flank
  there is only one stand's worth of traffic instead of the main line's overlapping several.
- **Server step cost was not measured.** The dispatch asks for step avg both sides; I measured peak
  live (table above, unchanged at stands 4 and 7, 35 -> 16 at stand 11) and ran out of session for a
  second instrumented pair. At stands 1-7 the released points are identical to OFF (claim 4), so the
  step cost there cannot differ by construction.
- `neverNearAnyStand` rises at stands 7 and 11 (1 -> 9, 0 -> 8): with the band translated onto one
  stand, groups that used to pass several main-line stands now pass hers and no other. That is the
  aim working, but nobody has judged whether it reads as emptier elsewhere.
- Karen has not played it. The flag is OFF in her Forest Test.
