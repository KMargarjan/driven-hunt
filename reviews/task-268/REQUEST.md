# Task 268 -- a staged running deer, and the two core proofs it unblocks

Task: 268
Round: 1
Base: `fb81366f` (`main`, after #247)
Code commit: `77908afc6cb703a4ec8b2d3d3859da89b3bc78f5`

```
[harness] PASS: 34/34 checks @ 77908afc6cb703a4ec8b2d3d3859da89b3bc78f5 (clean tree) scope=all
```

`test2` is **N/A**: none of the four changed files is in `TWO_PLAYER_PATHS`
(`src/shared/ForestTest/`, `src/server/ForestTest/`, `src/server/ForestTestBoot.server.luau`,
`tests/server/forest_line.spec.luau`).

## PLAN

Written before any `src/` edit, as the core quality protocol's step 0 requires. Three dispatch
items: **1** the enabler (`DHTestRelease`), **2** CORE shooting, **3** CORE the dead deer on the road.

### Item 1 -- the enabler. It is a TOOL, so (a)/(c) are about what it must put in front of the gun

* **(a) REAL LIFE.** A driven hunt puts the animal across the gun's front at a flight run: a red
  deer's gallop is 10-13 m/s. This world's own figure is `PACE.RUN_SPEED = 24` studs/s with the
  deer's species multiplier on top (`src/server/Boar/init.luau:1141`, `:4276`), which task 264
  measured live at **28.3 studs/s** (= 7.9 m/s at `Report.CONFIG.METRES_PER_STUD` 0.28).
* **(b) MEASURED NOW.** The drive supplies deer in **2 of 15 slots**
  (`Data.SCHEDULE.drive`, slots 2 and 8), released 200-360 studs out, and task 266b's reading is
  the consequence: *with `HIT_CLAIM` on, a still animal was hit in the chest 3/3; NO running animal
  was ever hit with an accepted claim -- no runner inside 150 studs at the trigger.* The Forest
  Test's live attributes, read this session with `<runs-dir>/attrs-id.luau`:
  `placeId=130094961655666 DHFlag_BOAR_BEHAVIOUR=true DHFlag_BOAR_MODEL=true DHFlag_COINS=true
  DHFlag_DEER_ROAD_LEAP=true DHFlag_DRIVE_BOTS=true DHFlag_HORN=true DHFlag_LICENCE_POPUP=true
  DHFlag_LOBBY=true DHFlag_SHOP=true DHForestStartRole=hunter DHShopTestGrant=true` -- eleven, and
  `HIT_CLAIM` is not among them, so it is at its `default` for item 2's "before".
* **(c) TARGET.** One named group (`stag` / `hinds`), on demand, at a chosen depth (default 250
  studs = 70 m, inside the dispatch's 60-90 m), crossing the road **in front of the stand**
  (`crossOffset = 0`) at `pace = "run"`. It must come through the SAME path a slot does, so what is
  proved on it is true of the drive.
* **(d) LEVER.** `ForestTest.releaseLine` is the real release path and it builds everything from
  ONE row of `Data.SCHEDULE.drive`:
  ```
  src/server/ForestTest/init.luau:2953:	local row = ForestTest.waveAt(slot)
  src/server/ForestTest/init.luau:3047:			composition = Boar.deerComposition(0, 0, boar, row.party)
  ```
  So the lever is **the row**, and the enabler writes one instead of reading one. No new mover, no
  second spawner: `Boar.deerComposition`, `Boar.sounderKinds`, `runtime:spawn`,
  `runtime:formSounder` and `state.lines` are all the ones a slot uses.
* **(e) HOW IT IS MEASURED AFTER.** The same console line every slot prints (`releaseLine`'s
  `"line %d: SLOT ..."`), plus `<runs-dir>/268-stage.luau` reading the released group's kind,
  position, depth and speed.

### Item 2 -- CORE, shooting: the lead, with the true-hit claim

* **(a) REAL LIFE.** A bullet takes time to arrive, so a crossing animal must be led. At the
  scoped rifle's own numbers the flight to 200 studs is ~0.08 s, and a deer at 28.3 studs/s travels
  **~2.3 studs** in that time -- about 0.4 of a body length (a deer body measured 5.9 studs in task
  264), i.e. a chest-width error if it is not taken out.
* **(b) MEASURED NOW.** Task 266b, `HIT_CLAIM` on: still animal, chest, 3/3. Running animal with an
  accepted claim: **0, ever.** No runner was inside 150 studs at any trigger.
* **(c) TARGET.** Three shots LED by `v x flight` at a staged running deer: the zone the server
  names is `chest` on all three, `DHClaimStats` accepted claims **+3**, and a frame of the mark on
  a moving animal. Then three shots aimed AT the chest with no lead: they land **behind** the chest
  by `v x t` within the measurement's own error. Those numbers and not others because they are the
  dispatch's, and because `v x t` is the only prediction the lead model makes.
* **(d) LEVER.** The lead itself is already written and exported:
  ```
  src/shared/Ballistics/init.luau:119:function Ballistics.timeToRange(shot: Shot, studs: number): number
  src/shared/Ballistics/init.luau:377:function Ballistics.leadStuds(shot: Shot, studs: number, targetStudsPerSecond: number): number
  ```
  So nothing in `src/` is changed for this item: the lever is the instrument's aim point, and the
  claim path under test is task 266's. **L-021 is noted and is why the yardstick is the ZONE and
  the ALONG/ACROSS split, not an absolute impact point**: `askLineUnsafe` and `safetySignal` are
  known to cast from origins ~0.73 studs apart (queued as 259b), and a no-lead measurement read as
  an absolute offset would charge that constant to the lead model. The instrument reports the miss
  resolved along the sight line and across it, as task 265's does.
* **(e) HOW IT IS MEASURED AFTER.** `<runs-dir>/aimshot.py` (task 265's instrument, 5/5 selftest)
  extended with a per-frame TRACKING hold, which is the one thing it lacks: its hold is a static
  point, and at 28.3 studs/s the animal is ~20 studs away from it by the time the click lands.
  L-023 is noted: the shot is a **real focused click** through `click.ps1`, so the origin is the
  player's own muzzle and `Validator.checkShot`'s 6-stud origin cap is never approached.

### Item 3 -- CORE, animal: the dead deer lying still ON the road

* **(a) REAL LIFE.** A deer shot through the chest drops within a body length or two and then does
  not move at all; it does not slide, and it does not float.
* **(b) MEASURED NOW.** Task 264: **one** kill, off the road, at 1.0 studs/s -- `SLIDE 0.83 studs
  = 0.14 bodyLen`, `HANG 0.357 studs`, `anchored=true`. **On the road, running: nobody has ever
  seen one.** Five attempts (261, 264, 265, 266, 267) and no reading.
* **(c) TARGET.** 8 staged running deer killed, **at least 4 ON the road**: slide **0 over 1 body
  length** and hang **0 over 0.5 studs**, per carcass. Those are task 261's own targets, which is
  why they and not others: this item exists to prove the code that was written to them.
* **(d) LEVER.** Both halves already exist and neither is changed here:
  ```
  src/server/Boar/Body.luau:2617:function Body.shouldAnchorCarcass(linear: Vector3, stillFor: number, collapsedFor: number, config): boolean
  src/server/Boar/Body.luau:2750:function Body.stepCarcass(handle, dt: number, config, groundAt: ((number, number, number?) -> number?)?)
  src/server/Boar/Body.luau:2861:		handle.part.Anchored = true
  ```
* **(e) HOW IT IS MEASURED AFTER.** `<runs-dir>/268-carcass.luau`, which is task 232's carcass
  probe (ground raycast, lowest bone, box up-vector) plus the slide: the position is sampled at the
  moment `Carcass` becomes true and again once `Anchored` is true, and "on the road" is decided by
  `Data.roadZ` at the carcass's own x.

### Time, and L-012

The Learning Agent's L-012 is right about this dispatch: items 2 and 3 are both CORE and the first
has eaten the box four times. **So item 3 is measured FIRST**, immediately after the enabler is
gated -- its five failed attempts outrank the dispatch's numbering -- and item 2's shots are taken
from the same staged releases, because a led kill is also a kill whose carcass can be measured.

## WHAT CHANGED

**`src/`, four files, one feature: `DHTestRelease`.** A Studio-only instrument that releases ONE
named group on demand, through the drive's own release path.

* `src/shared/ForestTest/init.luau` -- `ForestTest.STAGED_ATTRIBUTE`, `ForestTest.STAGED` (the
  defaults and the bounds) and `ForestTest.stagedRow(isStudio, raw, staged)`: **pure**, the one
  place a spec string becomes a `SCHEDULE.drive`-shaped row.
* `src/server/ForestTest/init.luau` -- `releaseLine` takes a second parameter, the staged row;
  `ForestTest.setStagedReader` and `ForestTest.stagedLine(now)`; `ForestTest.step` asks for one
  every tick, before the metronome and independent of it.
* `src/server/ForestTestBoot.server.luau` -- the one reader: `RunService:IsStudio()`, a
  `ServerStorage` attribute, one-shot (read and cleared in the same call).
* `tests/server/forest_line.spec.luau` -- seven cases under `the staged release`, both branches.

**Nothing else in `src/` changed.** Items 2 and 3 are measurements, and their levers
(`Ballistics.leadStuds` / `timeToRange`, `Body.shouldAnchorCarcass` / `stepCarcass`) are untouched.

## WHAT THE LIVE PROOF MEASURED, including what it did NOT reach

All of it in Karen's Forest Test (placeId 130094961655666), rifle in hand, real focused clicks.
Logs: `<runs-dir>/268-t3.log`, `268-t3b.log`. Attributes read before (`<runs-dir>/attrs-id.luau`)
and read again after: **identical, eleven, `DHTestOwns` added for the session and removed.**

### Item 1 -- MET, first try

```
[ForestTest] STAGED hinds@250 -- line 5: SLOT 0 act 0 STRAIGHT -- 2 of 2 animal(s) [hind+calf]
in 1 of 1 file(s) at a run, from dz 250 of 250, line at dz 549, offset -140, crossing +60 studs
from the stand -- STAGED by DHTestRelease (task 268)
```
`SLOT 0`, `from dz 250 of 250` (the depth asked for, unclamped), `at a run`, the hind party by
name, and the drive's own slot line format. 14 staged releases over the session.

### Item 3 -- the targets are MET on every carcass, and the count is NOT

**THE FIRST READING OF A DEER DEAD ON THE ROAD IN KAREN'S PLACE, after five failed attempts:**

| # | animal | SLIDE | = bodyLen (target 1.00) | HANG (target 0.500) | where |
|---|---|---|---|---|---|
| 1 | Boar253 hind | 0.007 | **0.001** | **0.386** | off the road |
| 2 | Boar326 male | 1.061 | **0.193** | **0.002** | off the road (dz 23.3, just outside the verge) |
| 3 | **Boar356 hind** | 0.223 | **0.037** | **0.020** | **ON THE ROAD (dz 8.4 of half width 20)** |
| 4 | Boar383 hind | 0.009 | **0.001** | **0.341** | off the road (dz 186) |

Worst slide 0.193 body lengths against a target of 1.00; worst hang 0.386 studs against 0.500.
`anchored=true` on all four; settling took 0.24 to 1.24 s.

**WHAT IS NOT MET, said plainly: 4 kills and not 8, and ONE on the road and not four.** And the
one on the road had **stopped** at the verge at the instant of the trigger (`v 0.00` in the shot
row) -- it was selected by the tracker while running at 12+ studs/s and shot standing. A deer
killed while actually running was Boar383 at `v 32.05` and it died 186 studs north of the road.
**So "a deer killed running ON the road lies still" is still not a thing anybody has seen.**

### Item 2 -- NOT MET, and it was not run under its own condition

`HIT_CLAIM` was never switched on: the session's time went on the enabler and on three measured
instrument faults (below), and turning the flag on for shots that were not going to be chest hits
would have produced a number with nothing behind it. Of the seven real shots:

* a RUNNING deer was hit for the first time -- `Boar383(body) @ ... | v 32.05 lead 1.837 flight
  0.0573` at 141.7 studs. **Task 266b's "no running animal was ever hit" is no longer true.**
* **no shot named `chest`.** The zones the server named were `body` (twice) and `ZoneRear(rear)`.
* the one shot with a still, settled hold on a still animal came back `OFF-SIGHT 0.016 studs`; the
  shot taken while the hold was SWEEPING a 32 studs/s animal came back `OFF-SIGHT 3.828 studs`.
  That difference is the instrument's, not the gun's -- the sight line is reconstructed from the
  aim point as the listener reads it, and a moving hold has moved between the trigger and the read
  -- and it is reported rather than charged to the ballistics (L-021's warning, one step further
  along than it was written for).

### Three instrument faults this session MEASURED and fixed, because they cost the rest of it

1. **the gun.** The first run fired a SHOTGUN (range 100) at 136 studs: nothing landed. The rifle
   has to be put in the hand with a real `2`, and re-asserted every shot -- four minutes later it
   was a Shotgun again with no key pressed, because a new drive re-gives the loadout.
2. **the view.** A shot fired 1.5 s after the hold was re-pointed came back with the camera
   **122 degrees** off the held point and three impacts 55 studs BEHIND the shooter. The
   instrument now reads the real angle and waits for it to be under 0.6 deg.
3. **the target behind a tree.** Three shots came back `Session.Tree<N>.CollidePart ... local
   43.294,1.113,1.131 | OFF-SIGHT 0.143 studs at 43.4 studs` -- a bullet 43 studs up a 97-stud
   trunk, 0.14 studs off a line held perfectly on a deer 180 studs beyond it. The visibility ray
   had been excluding a folder called `Foliage`; the trees are `Workspace.Session.Tree<N>`.

And one that cost two whole runs and is worth keeping: **`require(ServerScriptService.ForestTest)`
over StudioMCP returns a sandboxed copy with EMPTY STATE** (that module's own comment says so,
task 122). `stats().started` read `false` and `hunterStandX()` read its default `3030` for
33 minutes while the drive was releasing slot 16 with eleven animals out. A readiness gate built
on either number can never open. Instance facts only.

## CLAIMS

1. **`Data.stagedRow` is pure and answers nil on a live server.** `forest_line.spec`, "answers nil
   on a live server for every spec it would otherwise read": four well-formed specs, `isStudio`
   true gives a row and false gives nil, with no Studio session and no attribute.
2. **It refuses everything it cannot read and never guesses.** Same spec, "refuses anything it
   cannot read": 17 malformed specs including a NaN depth, both ends of the depth band off by one,
   `boar0`, `boar1.5`, an unknown pace and an unknown party -- all nil; and both edges of the band
   (40, 600) accepted.
3. **The row it writes is read by exactly the readers a SCHEDULE row is.** Same spec, "is a row the
   drive's own readers accept": `Data.slotRoute`, `Data.clampedToLine`, `Data.routeFloor`,
   `Data.releaseDepth`, `Data.wavePoint` and `Data.roadZ`, which are `releaseLine`'s own calls in
   its own order.
4. **The party names it passes on are exactly the ones the animal owner knows, both directions.**
   Same spec, "passes on only party names Boar.deerComposition can turn into counts": every name in
   `STAGED.PARTIES` becomes a composition with animals in it, and every row of
   `SPECIES.reddeer.RELEASE.COMPOSITIONS` is a name the parser accepts.
5. **A staged release goes through the real path and touches none of the drive's counters.** Read
   `releaseLine`: `slot = 0` when staged, `state.driveWave` is advanced only by the metronome in
   `ForestTest.step`, `state.owedRow` is never set for a staged row, and `state.deerDone` is
   guarded by `staged == nil`. Everything after the row -- the depth clamp, the composition, the
   routes, the spawn, the file, the sounder, the console line -- is byte-for-byte what a slot gets.
6. **Three independent Studio gates.** `ForestTestBoot`'s reader tests `RunService:IsStudio()`; the
   attribute is on `ServerStorage`, which never replicates; and `Data.stagedRow` is handed
   `RunService:IsStudio()` again at the point of use in `ForestTest.stagedLine`. Claim 1 proves the
   third one alone is sufficient.
7. **The live release line above is what the enabler produced**, and it is in the Forest Test's own
   console, in `releaseLine`'s own format.
8. **Item 3's four carcasses meet both of task 261's targets and one of them is ON THE ROAD**, with
   the table above. The probe is `<runs-dir>/proof268.py`'s `WATCH`: event-driven on
   `GetAttributeChangedSignal("Carcass")` and `GetPropertyChangedSignal("Anchored")`, so the death
   position is the position at the instant of death and not a poll up to 2.8 studs late.
9. **Item 3 is NOT met on its count and item 2 is NOT met at all**, as written out above. Neither is
   dressed up: four kills not eight, one on the road not four, that one stationary at the trigger,
   no `chest` zone on a running animal, and `HIT_CLAIM` never switched on.
10. **The Forest Test is exactly as it was found.** The eleven attributes read at the start are the
    eleven read at the end (`<runs-dir>/268-restore.luau` output in the ledger); `DHTestOwns` was
    added for the session and removed by name; `flags.py --place forest clear` was never run
    (Builder rule K).

## WHAT COULD NOT BE VERIFIED

* **No frame shows a deer lying on the road.** `<runs-dir>/268-t3-t3.9.2.png` was opened and is
  described in the ledger: the shooter's eye, the scoped .416 held low over the stand's yellow
  circle, the hit card reading `Alhamdulilah824 HIND  body  7 m  RIFLE` and `an animal got away x6`,
  HUD `DRIVE 5 / 2:22 / 0 ANIMALS / HUNTER`. It corroborates the kill and **it does not show the
  carcass**: the capture happens after the read, by which time the held point is the dead animal on
  the ground and the viewmodel fills the lower half of the frame. `NOT OBTAINABLE this session`.
* The two-player run: N/A. None of the four changed files is in `TWO_PLAYER_PATHS`.
* Whether a staged group would be refused by `MAX_GROUPS_ALIVE` was not reached: the cap is bypassed
  for a staged row by design, and the live line never printed the refusal branch.
