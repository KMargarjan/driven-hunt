# Task 345b (T2): the roster becomes the drive's population, behind `PLACEMENT_IN_PLACE`

Task: 345b
Round: 1
Base: main (`5ca28de9`, #361)
Code commit: `69ab538f21e24c3d011c790d4b3e92ff7669f50c`

`[harness] PASS: 34/34 checks @ 69ab538f21e24c3d011c790d4b3e92ff7669f50c (clean tree) scope=all`

`test2` **N/A**: no `TWO_PLAYER_PATHS` path is touched (`src/shared/ForestTest/`,
`src/server/ForestTest/`, `src/server/ForestTestBoot.server.luau`, `tests/server/`), and
`docs/design/animal-placement.md` section 17 says so for all six of T1..T6.

**What changed.** T2 of the design's section 17. With the flag ON every group of a drive is a RECORD
from the drive's first frame and gets a BODY in cover, `leadSeconds` 20 before the beater line
reaches its bed; with the flag OFF the drive is today's. `Placement` gains `bedNorth`'s new rule,
`searchBand`, `alreadyInTheWood` and `bridgeMustRelease`; `ForestTest` gains `planDrive`,
`stepPlacement`, `materialise`, `bedSpot`, `rosterSlot`, `roster`, `placementStats`,
`placementReport` and the Studio-only `DHForestPlacement` attribute. `REST.groups` / `stockWood` /
`stepRest` are archived in `backups/2026-11-10_task-345b_rest-groups.md` and deleted at the flag
flip (Director decision D-2).

**Three design numbers are deviated from, all in `ESCALATE.md` (2026-11-10 ~23:30) with the
arithmetic.** The even bed ladder of design 4.2 (the Director's tempo decision retires it), `bedCap`
12 (refuted by the script's own compositions and two live drives), and K-1's muster of 700 (K-1 was
measured against the ROAD place's 580; every drive Karen plays musters at a CELL's own 1,430, so
`BEATER.behindLineStuds` is left at 400). `docs/design/` is unchanged -- the Builder does not write
designs.

## Claims

1. **A bed is where the line will be at the moment the script says that group moves.**
   `Placement.bedNorth(far, atSeconds, lineSpeed, near)` -- one line of arithmetic off
   `Data.slotSeconds`. Verify: `forest_placement.spec`, *"lie where the line will be at the moment
   the script says the group moves"*; slot 1 is `firstSlotSeconds` of walk short of `bandFar`,
   consecutive slots are `CONFIG.bedSpacingStuds` apart for all fifteen rows, `near` is the floor and
   the second return says when it bit.
2. **The tempo is the Director's decision, derived and asserted.**
   `CONFIG.bedSpacingStuds` 73.32 = `SCHEDULE.intervalSeconds` 13 x
   `Grid.CONFIG.beaterWalkStudsPerSecond` 5.64, with the arithmetic in its comment. Verify:
   *"keeps the tempo Karen accepted, at the live line speed and not the design's 3.1"* -- it asserts
   the published value against both owners' own numbers AND that a planned `busy` drive delivers
   13.00 s between consecutive groups. Note printed: `placement tempo: 73.32 studs per slot = 13 s x
   5.64 studs/s; busy delivers 13.00 s between groups`.
3. **The owner's roster IS the population behind the flag, and nothing at all with it off.**
   `ForestTest.planDrive` is the one writer of `state.roster`, idempotent per drive number, pure
   inside, called from `ForestTestBoot`'s `markers` closure. Verify: *"plans a roster when the switch
   is on and nothing at all when it is off"* -- it drives the real owner, compares its rows slot for
   slot and bed for bed with a fresh `Placement.plan`, and asserts every row is `record` with no ids.
   **L-093: delete `planDrive`'s `inPlace ~= true` guard and the OFF half fails; delete the
   `rosterDrive` key and the idempotence line fails; delete the `state.roster = rows` assignment and
   the ON half fails.**
4. **The bridge fills only the hole the WOOD refused.** `Placement.bridgeMustRelease(row)` is
   `row.skipped == "nobed"` and nothing else; `releaseLine` holds every other slot the roster owns.
   Verify: *"holds a slot whose group is already in the wood, and only that slot"*. **L-093: delete
   the `== "nobed"` test and `releaseLine` releases every group the live cap had just refused a bed
   to -- measured at 31 bodies against a `LIVE_CAP` of 24 (`345b-ON3-C1-track.txt`).**
5. **With the flag OFF the drive is today's drive, measured against `main` in Karen's own Forest
   Test.** `345b-OFF2-C1-console.txt` (branch, flag off, at the code commit) against
   `345b-MAIN-C1-console.txt` (`driven-hunt-karen` at `5ca28de9`), same cell C1, same route: slots
   1..15 identical line for line -- `1 STRAIGHT 1of1, 2 STRAIGHT 5of5, 3 STRAIGHT 6of6, 4 STRAIGHT
   7of7, [5 silent], 6 LATERAL 6of6, 7 STRAIGHT 9of9, 8 STRAIGHT 1of1, 9 STRAIGHT 8of8, [10 silent],
   11 SPLIT 6of6, 12 BREAK-BACK 7of7, 13 BREAK-BACK 6of6, 14 STRAIGHT 5of5, 15 HOLD 6of6` -- **0
   `[placement]` lines, `DHForestPlacement` nil on all 160 samples**, peak live 34 against 33, peak
   parts 608 against 591.
6. **With the flag ON the roster is placed, in two cells.** C1 `normal`
   (`345b-ON4-C1-console.txt`): `placed 13 / bedded 0 / awake 0 / gone 9 / skipped 4 (73 animals
   placed, 9 searches, skips budget 4)`. A2 `busy` (`345b-ON4-A2-console.txt`): `placed 15 / bedded 0
   / awake 0 / gone 13 / skipped 2 (83 animals placed, 15 searches, skips nobed 2)`. 13/73 and 15/83
   are the design's own `normal` and `busy` figures.
7. **The budget holds and the drive got CHEAPER, not dearer.** C1, one drive each, whole-drive peaks
   off the same probe: **OFF peak live 34 / peak parts 608; ON peak live 24 / peak parts 438** --
   exactly `Data.LIVE_CAP` 24, where the OFF drive is 10 over it. Boar step, the `[boarstep]` drive
   report: **OFF avg 4.30 ms worst 80.79 ms; ON avg 4.08 ms worst 77.47 ms** (A2 ON: 2.41 / 79.92).
   Server heartbeat p95: **OFF 32.38 ms; ON 33.18 ms** (same session, same cell; `main`'s own run,
   first after a fresh Studio, read 24.00 ms).
8. **The bedded-body cost, which design 16.3 item 3 left unmeasured.** 30 s windows, cell C1, step ms
   from `Boars.StepCount`/`StepMsAvg` deltas (one instrument, `345b-window.py`):
   **RUNNING -- `345b-MAIN-C1-track.txt` t=213..243, 19.1 standing, 0 bedded: avg 4.330 ms
   (0.227 ms/animal), in-window peak 72.00 ms; BEDDED -- `345b-ON4-C1-track.txt` t=0..30, 17.0
   standing and all 17 bedded: avg 4.636 ms (0.273 ms/animal), in-window peak 42.53 ms.**
   **A bedded body costs the same as a running one** -- design 4.1's assumption is confirmed, there
   is no cheap-body tier, and the record tier is what the budget is actually bought with.
   Two RUNS and not two windows of one run, named and not blended (V284): no window of either ON
   drive held 12-20 standing with zero bedded bodies for 30 s.
9. **The flag is read once, at the owner's boundary, and passed inward.** `ForestTest.start` does
   `state.placementInPlace = Flags.isOn("PLACEMENT_IN_PLACE")`; `planDrive(driveNumber, inPlace)` and
   `stepPlacement(now, inPlace)` take it as a parameter, so both states are reachable from a spec
   while the flag sits at one of them. Verify: *"steps nothing while the switch is off"*, and
   `ForestTestBoot` reads `ForestTest.placementInPlace()` rather than `Flags` a second time.
10. **No owner boundary moved.** `Boar.Runtime` is still the only thing that creates a body
    (`materialise` asks `spawn` / `spawnSounder`); `restSpot` is still the one bed searcher and is
    unchanged but for an optional band override; `spookNearBeaters`, `stepLines`, `Data.sweepCatches`
    and `Data.lineFrontAt` are untouched; nothing new is tagged, replicated or published except one
    Studio-only attribute.

## What I could not verify

- **Design 12.2 frame 3 (a bedded group in cover, close, before the beaters arrive) is NOT
  OBTAINABLE on this route, and the reason is measured.** `<runs-dir>/244-hold-cam.luau`'s own
  mechanism (`CameraType = Scriptable`, held for 12 s) is overridden every frame by the client
  camera's single owner, so both attempts returned the hunter's own view instead:
  `345b-F3-bedded.png` and `345b-F3b.png`. **I opened both.** They show the hunter on his stand
  inside the yellow stand circle, shotgun across the bottom left, the HUD reading `DRIVE 1 / 4:25
  TIME / 0 ANIMALS / HUNTER / $13500` and then `3:53 TIME / 0 ANIMALS`, a birch wood and open grass
  in front of him and **not one animal anywhere in frame** -- while the probe at that instant read
  `placed=13 bedded=4 animals=73 bodies=17`. That is design 12.2 **frame 1**, not frame 3: 17
  animals were standing in the wood and nothing appeared in front of him. Frame 3 needs a free
  camera in Play, which is T3's `bedHidden` work or a Director camera instrument.
- **Four groups of thirteen are still skipped at C1, all `budget: bedded`** (A2 skipped two, both
  `nobed`). The bed cap is the binding arm, not the live cap. T3's predicate and T4's `orderGroup`
  are what close it; the numbers are in `ESCALATE.md`.
- **Two bedded groups were measured lying at dz 138..189 in C1 while the shallowest PLANNED bed of
  that drive is dz 217** (`345b-beds.luau`, t=22 of a drive, flag ON). I could not find the cause in
  the time this session had. It is inside the design's own `bandNearStuds` 150 only by the group's
  40-stud spread, so nothing was placed inside `neverStuds` of the stand -- but it is unexplained and
  it is written here rather than left for someone to find.
- The harness's own input replay failed once at this commit (`tie-the-driver`, *"Target is not
  reachable ... No OnInvoke handler responded"*, 33/34); the re-run at the same commit is the 34/34
  line above, with 2,930 server and 684 client specs passing in both.

ANSWERED: L-136 the only spec failures this task saw were its own and are fixed; no named flake
fired at the code commit (0 FAIL lines in `345b-harness-final2.txt`).
ANSWERED: L-127 every before/after pair is on one line with BOTH readings quoted (claims 7 and 8).
ANSWERED: L-162 every live proof that carries a claim was taken at the code commit `69ab538f`
(`345b-OFF2-C1`, `345b-ON4-C1`, `345b-ON4-A2`, both frames); the earlier ON runs are quoted only as
the measurements that drove the three fixes, each named by its own file.
ANSWERED: L-014 no code was ever checked out in `driven-hunt-karen`; the proof ran from
`driven-hunt-rev` on :34873 and her FT ends on :34873 from `driven-hunt-karen`, in Edit.
ANSWERED: L-101 the FT's `ServerStorage` attributes before and after are
`<runs-dir>/345b-attrs-before.txt` and `345b-attrs-final.txt`; `diff` is EMPTY. The proof flag was
removed by name, never `flags.py --place forest clear`.
ANSWERED: L-093 three delete-the-producer cases, named in claims 3 and 4.
