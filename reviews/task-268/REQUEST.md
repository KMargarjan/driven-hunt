# Task 268 -- a staged running deer, and the two core proofs it unblocks

Task: 268
Round: 1
Base: `fb81366f` (`main`, after #247)
Code commit: (filled in below, with the harness line)

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

(filled in after the build)

## CLAIMS

(filled in after the build)
