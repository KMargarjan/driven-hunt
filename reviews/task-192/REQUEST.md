# Task 192 -- nobody dies on respawn or at a new round, and the terrain is whole

Task: 192
Round: 2
Base: 5cc4472 (main, after #173)
Code commit: 6c32b75524cb72ef0c27e69908badfc5997b85d1

Harness, clean tree, FULL suite (this branch touches `src/server/Match/`, which maps to the `match`
scope, and `src/server/ForestTestBoot.server.luau`, which maps to nothing and therefore to `all`):

    [harness] PASS: 33/33 checks @ 012f0e5aabf5fb4fb02437b521fdc98f7da0ac8e (clean tree) scope=all
    [harness] PASS: 33/33 checks @ 6c32b75524cb72ef0c27e69908badfc5997b85d1 (clean tree) scope=all
    [harness2] PASS: 35/35 checks @ 6c32b75524cb72ef0c27e69908badfc5997b85d1 (clean tree)

Round 1's two findings are both fixed and both were right. Round 1's eight notes: five fixed, three
answered in place.

## Finding 1 -- the net asked the wrong question, and it was worse than the review could show

"Where is the ground under this body" was answered by a ray from 300-600 studs UP, so the first
solid thing OVERHEAD became the ground. I reproduced both of the Reviewer's cases in the live place
before changing anything, with that world's OWN reader:

| where | asked from the sky | asked from root + 6 | the lie |
|---|---|---|---|
| under the log cabin, (2840, -2910) | **160.8** (`Lobby.Lodge.House.Log Cabin.Part`) | 150.0 (Terrain) | 10.8 studs; a man standing there measured **7.6 studs "under the ground"** |
| under a canopy, (3450, -2900) | **221.3** (`Workspace.Session.Mesh Tree.OuterLeaves`) | 180.1 (Terrain) | **41.2 studs**, which is a beater's whole 580-stud walk |

One correction to the finding's citation, not to the finding: the live lodge has **no `RoofSouth` /
`RoofNorth`** -- task 180 replaced `Build.roof` with a free model -- so the part that stops the ray
is the cabin's own geometry. The shop counter itself happens to sit under the door gap and reads
Terrain; six studs away, inside the cabin, it does not. The fault is exactly as described.

**The rule now: a downward ray can only hit what is BELOW its origin.**

* `ForestTest.groundAt` takes a `fromY`. `nil` is the old 600, kept for every caller that asks about
  a COLUMN rather than about a body (`Markers.groundFor`, `Bots`, `Lobby.tryBuild`, the boar world).
* `Body.groundUnder(x, z, fromY)` asks from `fromY + NEAR_PROBE_STUDS` (6) first. **Stage B, the far
  cast, runs only when the near one found nothing** -- which is exactly "there is nothing below this
  point": buried, or over a hole.
* **Stage B has to exist, and that is measured, not assumed.** At (3555, -3000) with the surface at
  191.6: from 197.6 down -> HIT 191.6; from 188.6 (three studs INSIDE) -> **MISS**; from 171.6
  (twenty studs inside) -> **MISS**. A body buried in the hill cannot find its own surface by
  looking down.
* `Body.floorStep` **no longer asks for a depth at all.** Three questions, every one about the
  body's own place: BURIED (`Body.insideTerrain`), OFF THE WORLD (below
  `FallenPartsDestroyHeight + 100`), or FALLING THROUGH NOTHING (`FloorMaterial == Air` AND moving
  down faster than `FALLING_SPEED_STUDS` AND a ray from the root finds no floor within
  `FALL_PROBE_STUDS`). A character the engine says is standing is never touched by 2 or 3 and is
  remembered as the last good place instead.
* `Body.insideTerrain` is `Terrain:ReadVoxels`, measured here: four studs above the surface reads
  `Air` 0.00, three studs inside `Grass` 0.91, twenty studs inside `Grass` 1.00, two hundred up
  `Air` 0.00. Nothing overhead can change that answer.

## Claims

1. **Nothing above a point can be its ground any more.** `Body.groundUnder` asks the near stage
   first and the far cast only on a miss; `Body.underGroundBy` and `Body.onGround` pass the point's
   own Y into it.
   *Verify:* `askGround` / `Body.groundUnder` in `src/server/Match/Body.luau`;
   `tests/server/match_place.spec.luau`, describe "indoors and under a canopy" -- the reader
   `roofedBuilding` answers the ROOF from the sky and the FLOOR from near a body, which is the live
   geometry as arithmetic.

2. **The net fires on three body-local facts and no depth.** Buried, off the world, or falling with
   no floor beneath -- each asked of the body's own position or of the engine.
   *Verify:* `Body.floorStep` and `fallingFreely`; `match_place.spec`, describe "Body.floorStep"
   (nine cases, including "leaves a man STANDING UNDER A ROOF alone, however low the sky says the
   ground is" and "leaves a beater UNDER A CANOPY alone").

3. **Proved live, under the two things the Reviewer named.** 46 s standing under the cabin roof at
   (2840, 153.1, -2910) and 39 s under the canopy at (3450, 183.3, -2900): not moved once, no
   `[place] RESCUED` line, and the sampler's own from-above column recorded the lie all the way
   through (160.7 `Part` and 221.3 `OuterLeaves` against terrain at 150.0 and 180.1).
   *Verify:* `<runs-dir>/t192b-after.log`, the `-->` marker lines and the samples after each.

4. **Finding 2: the guard asks both questions now.** `Match.isHeld` reads `heldStill` (written only
   by `applyHold`) and a tie writes `tied`, so the comment claimed a fix the code did not make. The
   guard is `Match.isHeld(...) or Match.isTied(...)`, and the comment says why they are two.
   *Verify:* the `local frozen = ...` line in `src/server/ForestTestBoot.server.luau`.

5. **Note 1: a rescue of nobody is not counted.** The net compares the target with where the body
   already is and does nothing below `RESCUE_MOVED_STUDS`.
   *Verify:* `Body.floorStep`; the case "counts nothing when there is nowhere to put him".

6. **Note 2: the hollow `forget` case is gone**, with a comment saying why rather than a silent
   deletion -- `lastGood` cannot be populated from a spec, so the case could not fail.
   *Verify:* the comment where it stood, in describe "Body.floorStep".

7. **Note 3: the wall asks the lift only when the clamp DISPLACED the body.** A hunter leaning on
   his circle is moved a fraction of a stud a frame and now costs no raycast at all; the mid-drive
   respawn the lift exists for arrives 900 studs away and still does.
   *Verify:* `LIFT_WHEN_MOVED_STUDS` and the guard in `ForestTest.boundary`.

8. **Note 4: the counter moved above `boundary`'s header**, so the header documents the function
   again. **Note 8: dressing happens before the snap**, so a missed ray cannot delay the appearance
   window. **The counter that measured a depth was renamed** to `Body.worstRescueStuds` -- the net
   no longer measures one, so the old name would have been a lie.
   *Verify:* `src/server/ForestTest/init.luau` around `LIFT_WHEN_MOVED_STUDS`; `Body.place`'s
   `pivot`; `Body.worstRescueStuds`.

9. **Notes 5, 6 and 7 are answered rather than changed.** 5 and 6 were miscounts in round 1's
   request (five `PivotTo` sites, seven cases) and this request counts them correctly -- there are
   now **five** `PivotTo` call sites in `Body` and **nine** cases in describe "Body.floorStep". 7:
   the fallback ray is the DEV place's reader and never runs beside the forest's, and its header
   now says so.
   *Verify:* `grep -n ":PivotTo(" src/server/Match/Body.luau` prints five lines -- `settle`,
   `place`, `standCharacter`, `floorStep`, `tieCharacter`; `askGround`'s header.

10. **The three-cycle proof was repeated whole.** Lobby -> truck pad -> drive -> drive end ->
    gathering -> next round, three times, on the `edge`, `road` and `ride` layouts (hunter, beater,
    hunter), with a mid-drive respawn. **2208 samples, 2201 living: foot height above the terrain
    +0.10 to +5.30 -- NOT ONE living sample under the ground -- 0 unrequested deaths (the single
    death was requested by the probe 0.1 s earlier), 0 rescues, 0 console errors.** The three
    `[place]` lines per cycle: `gather ... dY -2.2 / +0.5 / +0.5` and `spawn ... (2850, 153.7,
    -2934) ground=150.2 askedY=149.2 dY=+4.5` three times, which is the death that is gone.
    *Verify:* `<runs-dir>/t192b-after.log`, `t192b-after-console.txt`.

## What I could not verify

* **`test2`.** `src/server/Match/` is in `TWO_PLAYER_PATHS`, so the MERGE needs a two-player line
  and that needs a human F7. The review does not: the pasted line is `scope=all`.
* **The "last good position" write.** It happens only when `Humanoid.FloorMaterial` says the engine
  has the body standing, and that property cannot be set from Luau, so the specs drive the other
  branch and assert that nothing was remembered. Round 1's live run printed the write working
  (`put back at (3555, 195.1, -3000)`, which was his stand); this run never needed a rescue at all,
  which is the better outcome and leaves that line unexercised in the live log.
* **`Body.insideTerrain` against real terrain.** The specs drive `buriedTest` as a seam because
  `ReadVoxels` needs terrain; the engine half is the measurement table above
  (`Air` 0.00 / `Grass` 0.91 / `Grass` 1.00), taken in the place Karen plays.
* **"Terrain is broken" is still not a terrain defect**, as far as I could measure: 564 ray samples
  over the lobby, the drive area and the road corridor with **0 misses (no holes)**, the stands'
  two ground readings agreeing to 0.00, and four screenshots from a player's height. Unchanged from
  round 1.
