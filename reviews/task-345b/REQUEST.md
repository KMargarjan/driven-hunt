# Task 345b (T2): the roster becomes the drive's population, behind `PLACEMENT_IN_PLACE`

Task: 345b
Round: 3
Base: main (`5ca28de9`, #361)
Code commit: `7e87d8e05fe7d8b4ab575bcd351c15243cc826af`

`[harness] PASS: 34/34 checks @ 7e87d8e05fe7d8b4ab575bcd351c15243cc826af (clean tree) scope=all`

`test2` **N/A**: no `TWO_PLAYER_PATHS` path is touched (`src/shared/ForestTest/`,
`src/server/ForestTest/`, `src/server/ForestTestBoot.server.luau`, `tests/server/`), and
`docs/design/animal-placement.md` section 17 says so for all six of T1..T6.

Round 3 is authorised by the Director (`ESCALATE.md`, 2026-11-11 ~01:45, commit `87df8ab8`), run
once with `DIRECTOR_MAX_ROUNDS=3` and never committed.

**What changed.** T2 of the design's section 17: with the flag ON every group of a drive is a RECORD
from the drive's first frame and gets a BODY in cover, `leadSeconds` 20 before the beater line
reaches its bed; with the flag OFF the drive is today's. `REST.groups` / `stockWood` / `stepRest` are
archived in `backups/2026-11-10_task-345b_rest-groups.md` and deleted at the flag flip (D-2).

**Round 3 did exactly four things.** (1) `bedCap` stays 18 and its comment now cites the Director's
decision instead of arguing it; (2) a row that goes `gone` clears `row.ids`, so `releaseLine`'s
bridge -- which keys its two arms on `#row.ids` -- can never print *"the line finds it"* for a group
whose bodies have gone, with a new case that asserts the state word; (3) `state.latched` is declared
in the `state` table; (4) claims 8 and 9 below say what the Director asked them to say. The stub
runtime gained a `standing` list, because `stepPlacement`'s reconcile reads the RUNTIME and with an
always-empty `boars()` the round-2 bridge case could no longer reach its own branch.

**Deviations from the design, all decided by the Director:** the even bed ladder (retired by the
tempo decision), `bedCap` 12 -> 18 (**ACCEPTED as a change to D-1**, 2026-11-11 ~01:45), the bridge
holding a budget-refused slot (**ACCEPTED**), and K-1's muster of 700 (K-1 was measured on the ROAD
place's 580; every drive Karen plays musters at a CELL's own 1,430). `docs/design/` is unchanged.

## Claims

1. **A bed is where the line will be at the moment the script says that group moves.**
   `Placement.bedNorth(far, atSeconds, lineSpeed, near)`, one line of arithmetic off
   `Data.slotSeconds`. Verify: *"lie where the line will be at the moment the script says the group
   moves"* -- slot 1 is `firstSlotSeconds` of walk short of `bandFar`, consecutive slots are
   `CONFIG.bedSpacingStuds` apart for all fifteen rows, `near` is the floor and the second return
   says when it bit.
2. **The tempo is the Director's decision, derived and asserted.** `CONFIG.bedSpacingStuds` 73.32 =
   `SCHEDULE.intervalSeconds` 13 x `Grid.CONFIG.beaterWalkStudsPerSecond` 5.64, arithmetic in its
   comment. Verify: *"keeps the tempo Karen accepted, at the live line speed and not the design's
   3.1"*. Its DEPTH half is what carries the claim (both owners' own constants); its time half is an
   algebraic identity, which round 2 noted and this says out loud.
3. **The roster IS the population behind the flag, and nothing at all with it off.**
   `ForestTest.planDrive` is the one writer of `state.roster`, idempotent per drive number, pure
   inside, called from `ForestTestBoot`'s `markers` closure. Verify: *"plans a roster when the switch
   is on and nothing at all when it is off"*.
4. **The bridge has a case that drives `ForestTest.releaseLine`, and it fails when the bridge is
   deleted.** *"releases a slot the WOOD refused and releases nothing for one the roster owns"*: a
   stub runtime with two ids ON THEIR FEET, `planDrive(953, true)`, slot 1 bedded, then
   `Forest.step(Data.slotSeconds(1, …), true)` must print `THE ROSTER'S` and `the line finds it` with
   **zero** spawns recorded. **L-093, RUN at round 2's code commit:** deleting the whole bridge block
   from `releaseLine` fails `forest_placement.spec:661` (*"Expected true, got false"*).
5. **ROUND 3's FIX -- a row whose bodies have gone keeps no ids, and the line never says the line
   finds it.** `stepPlacement`'s reconcile does `row.state = "gone"; row.ids = {}`. Verify:
   *"never says the line finds a group whose bodies have gone"* -- the same stub with its `standing`
   list EMPTY, so the two bodies are gone by the time the slot fires; the case asserts
   `first.state == "gone"`, `#first.ids == 0`, that the line contains `HELD BY THE ROSTER` and `gone`
   and that it does **not** contain `the line finds it`. **L-093, RUN at this code commit:** deleting
   `row.ids = {}` fails `forest_placement.spec:718` -- *"Expected value 0 (number), got 2"* --
   on a full harness run (`FAIL: 32/34 … (DIRTY TREE (1 paths))`).
6. **`bedCap` 18 cites the decision, and `state.latched` is declared.** `Placement.CONFIG.bedCap`'s
   comment quotes `ESCALATE.md` 2026-11-11 ~01:45 (*"ACCEPTED, as a change to D-1 … supersedes the
   '<= 12' rows"*); `state.latched = {} :: { [string]: boolean }` sits in the `state` table beside
   `lines` and `stuck`.
7. **With the flag OFF the drive is today's drive, measured against `main` in Karen's own Forest
   Test.** `345b-OFF2-C1-console.txt` (this branch, flag off, run at `69ab538f`) against
   `345b-MAIN-C1-console.txt` (`driven-hunt-karen` at `5ca28de9`), same cell C1: slots 1..15
   identical line for line -- `1 STRAIGHT 1of1, 2 STRAIGHT 5of5, 3 STRAIGHT 6of6, 4 STRAIGHT 7of7,
   [5 silent], 6 LATERAL 6of6, 7 STRAIGHT 9of9, 8 STRAIGHT 1of1, 9 STRAIGHT 8of8, [10 silent],
   11 SPLIT 6of6, 12 BREAK-BACK 7of7, 13 BREAK-BACK 6of6, 14 STRAIGHT 5of5, 15 HOLD 6of6` -- **0
   `[placement]` lines and `DHForestPlacement` nil on all 160 samples**, peak live 34, peak parts 608.
   Nothing committed since `69ab538f` changes a flag-OFF code path: `bedCap`, `row.ids = {}` and
   `releaseLine`'s roster branch are all inside `if inPlace`/`if inRoster ~= nil`.
8. **THE LIVE ON DRIVE AT THIS CODE COMMIT, C1** (`345b-R3-ON-C1`, one drive, one window), console
   line **verbatim**:
   `[placement] drive 1: placed 13 / bedded 0 / awake 0 / gone 9 / skipped 4 (73 animals placed, 0 bedded bodies, 9 searches, skips budget 4)`
   and `[boarstep] drive 1: 14022 step(s) avg 4.10 ms worst 85.27 ms | 17 alive now, 289`.
   13 groups / 73 animals is the design's own `normal` figure. **Peak live 24 against
   `Data.LIVE_CAP` 24; peak parts 438.** **`the line finds it` was printed ONCE in the whole drive,
   for `THE ROSTER'S: 7 animal(s) bedded`; the count of such lines for a row with no live body --
   `THE ROSTER'S: 0 animal` -- is `0`, which is round 3's required number.** The fix is visible on the
   same drive: `HELD BY THE ROSTER: NO BODY YET (gone)` x2 and `(record, skipped: budget)` x1.
9. **The budget holds; the heartbeat does not, on either side.** C1, one drive each:
   **OFF peak live 34 / peak parts 608; ON peak live 24 / peak parts 438.** `[boarstep]`:
   **OFF avg 4.30 ms worst 80.79 ms; ON avg 4.10 ms worst 85.27 ms.** Server heartbeat p95 is
   **breached on both sides -- OFF 32.38 ms, ON 32.84 ms, against the 32 ms target -- and this change
   did not cause it**; T5 restates and measures it (the Director, 2026-11-11 ~01:45).
10. **The bedded-body cost, which design 16.3 item 3 left unmeasured.** 30 s windows, cell C1, step
    ms from `Boars.StepCount`/`StepMsAvg` deltas (one instrument, `<runs-dir>/345b-window.py`):
    **RUNNING -- `345b-MAIN-C1-track.txt` t=213..243, 19.1 standing, 0 bedded: avg 4.330 ms
    (0.227 ms/animal); BEDDED -- `345b-ON4-C1-track.txt` t=0..30, 17.0 standing and all 17 bedded:
    avg 4.636 ms (0.273 ms/animal).** A bedded body costs the same as a running one -- design 4.1's
    assumption confirmed. Two RUNS, named and not blended (V284).

## What I could not verify

- **NOBODY HAS SEEN A BEDDED ANIMAL ON SCREEN, and both routes to a frame are closed from the
  server. This is unproven, not a nicety.** `ESCALATE.md` 2026-11-11 ~02:05 is the route-fix task,
  with the measurement: route 1 (`244-hold-cam.luau`, the camera) loses to the client camera's single
  owner; route 2 (`345b-standnext.luau`, the character, new this round) reports *"standing at
  -3807,111.8,-4358 … gap=22.2 studs"* on the SERVER while `345b-clientsee.luau` reads the client's
  own root at `-4493.1, 132.2, -4091.6` -- **760 studs away, with 16 Boars replicated and 0 within
  120 studs of the lens**, because the client owns its character. All four frames
  (`345b-F3-bedded.png`, `345b-F3b.png`, `345b-F3-r3.png`, `345b-F3-r3b.png`) were **opened**: the
  first two are the hunter on his stand with `0 ANIMALS` and nothing in the lane (design 12.2
  **frame 1**, which is Karen's complaint answered from her eye); the last two are deep grass, pines,
  a hill and one orange-vested bot beater, with no animal near the aim point. L-150: the route failed
  twice, so it is escalated rather than retried a third time.
- **Four groups of thirteen are still skipped at C1, all `budget: bedded`.** T3's predicate and T4's
  `orderGroup` close it.
- **Two bedded groups were measured at dz 138..189 in C1 while the shallowest PLANNED bed of that
  drive is dz 217** -- unexplained, queued as `TASKS.md` 345b-notes (b).
- No named flake fired at this code commit; the only spec failures this task saw were its own.

ANSWERED: L-136 0 FAIL lines at the code commit (`<runs-dir>/345b-harness-r3b.txt`); no named flake
fired, so none to re-run or control.
ANSWERED: L-127 every before/after pair quotes BOTH readings on one line (claims 9 and 10), and the
dispatch's WHY sentence is reported as NOT PROVEN ON SCREEN rather than asserted.
ANSWERED: L-162 the live ON drive, both round-3 frames and the client-ownership reading were all
taken at this code commit `7e87d8e0`; the flag-OFF comparison names its own commit on its own line.
ANSWERED: L-014 no code was checked out in `driven-hunt-karen`; the proof ran from `driven-hunt-rev`
on :34873 and her FT ends on :34873 from `driven-hunt-karen`, in Edit.
ANSWERED: L-101 `<runs-dir>/345b-r3-attrs-before.txt` against `345b-r3-attrs-final.txt` -- `diff`
EMPTY. The proof flag was removed by name; `flags.py --place forest clear` was never run.
ANSWERED: L-093 three delete-and-fail proofs RUN, two of them at this code commit (claims 4 and 5).
