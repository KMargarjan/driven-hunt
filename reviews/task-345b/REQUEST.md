# Task 345b (T2): the roster becomes the drive's population, behind `PLACEMENT_IN_PLACE`

Task: 345b
Round: 2
Base: main (`5ca28de9`, #361)
Code commit: `3e8c3bd4dfc33e86cacec5a18bd6d86912784582`

`[harness] PASS: 34/34 checks @ 3e8c3bd4dfc33e86cacec5a18bd6d86912784582 (clean tree) scope=all`

`test2` **N/A**: no `TWO_PLAYER_PATHS` path is touched (`src/shared/ForestTest/`,
`src/server/ForestTest/`, `src/server/ForestTestBoot.server.luau`, `tests/server/`), and
`docs/design/animal-placement.md` section 17 says so for all six of T1..T6.

**What changed.** T2 of the design's section 17. With the flag ON every group of a drive is a RECORD
from the drive's first frame and gets a BODY in cover, `leadSeconds` 20 before the beater line
reaches its bed; with the flag OFF the drive is today's. `REST.groups` / `stockWood` / `stepRest` are
archived in `backups/2026-11-10_task-345b_rest-groups.md` and deleted at the flag flip (D-2).

**Round 1's three findings were all right. What round 2 did:** (1) `Placement.alreadyInTheWood` is
**dropped** -- it decided nothing -- and the bridge now has a case that drives `ForestTest.step`
itself onto slot 1 with a stub boar runtime; (2) the flag is a **parameter** of `step` and
`releaseLine` as well as of `planDrive` and `stepPlacement`, and the stub runtime makes its two
states answer differently; (3) a slot with no body no longer prints *"the line finds it"* and no
longer sets `deerDone`, and the held-budget deviation is `ESCALATE.md` 2026-11-11 ~01:20
(deviation 4) with its arithmetic. The three non-blocking notes are queued as `TASKS.md` 345b-notes.

**Four deviations from the design, all in `ESCALATE.md` with arithmetic**: the even bed ladder
(retired by the Director's tempo decision), `bedCap` 12, K-1's muster of 700 (measured on the ROAD
place's 580; every drive Karen plays musters at a CELL's own 1,430), and the bridge.
`docs/design/` is unchanged -- the Builder does not write designs.

## Claims

1. **A bed is where the line will be at the moment the script says that group moves.**
   `Placement.bedNorth(far, atSeconds, lineSpeed, near)`, one line of arithmetic off
   `Data.slotSeconds`. Verify: `forest_placement.spec`, *"lie where the line will be at the moment
   the script says the group moves"* -- slot 1 is `firstSlotSeconds` of walk short of `bandFar`,
   consecutive slots are `CONFIG.bedSpacingStuds` apart for all fifteen rows, `near` is the floor and
   the second return says when it bit.
2. **The tempo is the Director's decision, derived and asserted.** `CONFIG.bedSpacingStuds` 73.32 =
   `SCHEDULE.intervalSeconds` 13 x `Grid.CONFIG.beaterWalkStudsPerSecond` 5.64, arithmetic in its
   comment. Verify: *"keeps the tempo Karen accepted, at the live line speed and not the design's
   3.1"* -- the published value against both owners' own numbers, AND a planned `busy` drive
   delivering 13.00 s between consecutive groups.
3. **The roster IS the population behind the flag, and nothing at all with it off.**
   `ForestTest.planDrive` is the one writer of `state.roster`, idempotent per drive number, pure
   inside, called from `ForestTestBoot`'s `markers` closure. Verify: *"plans a roster when the switch
   is on and nothing at all when it is off"* -- it drives the real owner and compares its rows slot
   for slot and bed for bed with a fresh `Placement.plan`.
4. **ROUND 1 FINDING 1 -- the bridge now has a case that drives `ForestTest.releaseLine`, and the
   case FAILS when the bridge is deleted.** *"releases a slot the WOOD refused and releases nothing
   for one the roster owns"*: a stub boar runtime, `planDrive(953, true)`, slot 1's row set bedded
   with two ids, then `Forest.step(Data.slotSeconds(1, …), true)` -- the line must contain
   `THE ROSTER'S` and `the line finds it`, and the stub must have recorded **zero** spawns.
   **L-093, RUN at this code commit:** deleting the whole bridge block from `releaseLine` (the
   `local onNow = …` line through its `return string.format(…)`) makes `forest_placement.spec:661`
   fail -- *"Expected value true (boolean), got false"* -- on a full harness run
   (`FAIL: 30/34 ... (DIRTY TREE (1 paths))`). `Placement.alreadyInTheWood` is gone.
5. **ROUND 1 FINDING 2 -- the flag's two states now answer differently, and the guard's deletion
   fails the case.** `step(now, inPlace)` and `releaseLine(now, staged, inPlace)` take the flag as a
   parameter and default to the value `ForestTest.start` read once at this owner's boundary, which is
   `docs/design/feature-flags.md`'s own requirement. Verify: *"makes a body when the switch is on and
   nothing at all when it is off"* -- with a stub runtime installed, OFF answers nil and spends 0
   searches, ON answers a `bed g954-s…` line and spends more than 0.
   **L-093, RUN at this code commit:** deleting `inPlace ~= true` from `stepPlacement`'s guard makes
   the OFF line answer
   `bed g954-s1: slot 1 SKIPPED for this drive (nobed) at planned dz 1244 -- placed 8 / …`
   instead of nil (`FAIL: 32/34 ... (DIRTY TREE (1 paths))`).
6. **ROUND 1 FINDING 3 -- a slot with no body says so, and spends no deer.** `releaseLine`'s roster
   branch prints `HELD BY THE ROSTER: NO BODY YET (<state>[, skipped: <reason>]) at dz <n> --
   nothing is released for this slot` when `#ids == 0`, and `state.deerDone` is set only when
   `bodies > 0`. Whether the bridge should release such a row at all is `ESCALATE.md` 2026-11-11
   ~01:20 (deviation 4), with the table below as its evidence. `TASKS.md`'s 345b row now says what
   the code does.
7. **With the flag OFF the drive is today's drive, measured against `main` in Karen's own Forest
   Test.** `345b-OFF2-C1-console.txt` (this branch, flag off, run at code commit `69ab538f`; only
   `tests/`, the spec's own stub and `releaseLine`'s console text changed after it) against
   `345b-MAIN-C1-console.txt` (`driven-hunt-karen` at `5ca28de9`), same cell C1: slots 1..15
   identical line for line -- `1 STRAIGHT 1of1, 2 STRAIGHT 5of5, 3 STRAIGHT 6of6, 4 STRAIGHT 7of7,
   [5 silent], 6 LATERAL 6of6, 7 STRAIGHT 9of9, 8 STRAIGHT 1of1, 9 STRAIGHT 8of8, [10 silent],
   11 SPLIT 6of6, 12 BREAK-BACK 7of7, 13 BREAK-BACK 6of6, 14 STRAIGHT 5of5, 15 HOLD 6of6` -- **0
   `[placement]` lines and `DHForestPlacement` nil on all 160 samples**, peak live 34 against 33,
   peak parts 608 against 591.
8. **With the flag ON the roster is placed, in two cells.** C1 `normal`
   (`345b-ON4-C1-console.txt`): `placed 13 / bedded 0 / awake 0 / gone 9 / skipped 4 (73 animals
   placed, 9 searches, skips budget 4)`. A2 `busy` (`345b-ON4-A2-console.txt`): `placed 15 / bedded 0
   / awake 0 / gone 13 / skipped 2 (83 animals placed, 15 searches, skips nobed 2)`. 13/73 and 15/83
   are the design's own `normal` and `busy` figures.
9. **The budget holds and the drive got CHEAPER.** C1, one drive each, same probe:
   **OFF peak live 34 / peak parts 608; ON peak live 24 / peak parts 438** -- exactly
   `Data.LIVE_CAP` 24, where the OFF drive is 10 over it. `[boarstep]` drive report:
   **OFF avg 4.30 ms worst 80.79 ms; ON avg 4.08 ms worst 77.47 ms** (A2 ON 2.41 / 79.92). Server
   heartbeat p95: **OFF 32.38 ms; ON 33.18 ms**, same session and cell.
10. **The bedded-body cost, which design 16.3 item 3 left unmeasured.** 30 s windows, cell C1, step
    ms from `Boars.StepCount`/`StepMsAvg` deltas (one instrument, `<runs-dir>/345b-window.py`):
    **RUNNING -- `345b-MAIN-C1-track.txt` t=213..243, 19.1 standing, 0 bedded: avg 4.330 ms
    (0.227 ms/animal), in-window peak 72.00 ms; BEDDED -- `345b-ON4-C1-track.txt` t=0..30, 17.0
    standing and all 17 bedded: avg 4.636 ms (0.273 ms/animal), in-window peak 42.53 ms.**
    **A bedded body costs the same as a running one** -- design 4.1's assumption confirmed, no
    cheap-body tier, and the record tier is what the budget is actually bought with. Two RUNS, not
    two windows of one run, named and not blended (V284): no window of either ON drive held 12-20
    standing with zero bedded bodies for 30 s.

## What I could not verify

- **Design 12.2 frame 3 (a bedded group in cover, close, before the beaters arrive) is NOT
  OBTAINABLE on this route, and the reason is measured.** `<runs-dir>/244-hold-cam.luau`'s mechanism
  (`CameraType = Scriptable`, held for 12 s) is overridden every frame by the client camera's single
  owner, so both attempts returned the hunter's own view: `345b-F3-bedded.png` and `345b-F3b.png`.
  **I opened both.** They show the hunter on his stand inside the yellow stand circle, shotgun across
  the bottom left, the HUD reading `DRIVE 1 / 4:25 TIME / 0 ANIMALS / HUNTER / $13500` and then
  `3:53 TIME / 0 ANIMALS`, a birch wood and open grass in front of him and **not one animal anywhere
  in frame** -- while the probe at that instant read `placed=13 bedded=4 animals=73 bodies=17`. That
  is design 12.2 **frame 1**, not frame 3. Queued as `TASKS.md` 345b-notes (c).
- **Four groups of thirteen are still skipped at C1, all `budget: bedded`** (A2 skipped two, both
  `nobed`). The bed cap is the binding arm. T3's predicate and T4's `orderGroup` close it.
- **Two bedded groups were measured lying at dz 138..189 in C1 while the shallowest PLANNED bed of
  that drive is dz 217.** Unexplained; queued as 345b-notes (b) with the Reviewer's own narrowing.
- The harness's input replay failed once at `69ab538f` (`tie-the-driver`, *"Target is not reachable
  ... No OnInvoke handler responded"*); every later run of this branch, this commit's included, is
  34/34 with 2,930 server and 684 client specs passing.

ANSWERED: L-136 no named flake fired at the code commit -- 0 FAIL lines in
`<runs-dir>/345b-harness-r2b.txt`; the only spec failures this task saw were its own.
ANSWERED: L-127 every before/after pair quotes BOTH readings on one line (claims 9 and 10).
ANSWERED: L-162 the ON proofs and both frames were taken at `69ab538f`; only `tests/` and
`releaseLine`'s console text changed after it, and the flag-OFF path is byte-identical in behaviour
(claim 7 names the run and its commit).
ANSWERED: L-014 no code was checked out in `driven-hunt-karen`; the proofs ran from
`driven-hunt-rev` on :34873, and her FT ends on :34873 from `driven-hunt-karen`, in Edit.
ANSWERED: L-101 `<runs-dir>/345b-attrs-before.txt` against `345b-attrs-final.txt` -- `diff` EMPTY.
The proof flag was removed by name; `flags.py --place forest clear` was never run.
ANSWERED: L-093 two delete-and-fail proofs RUN at this code commit, claims 4 and 5.
