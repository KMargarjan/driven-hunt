# Task 192 -- nobody dies on respawn or at a new round, and the terrain is whole

Task: 192
Round: 1
Base: 5cc4472 (main, after #173)
Code commit: ba7a8a097db41095930ac0bed26a4cb7e718b9c8

Harness, clean tree, FULL suite (the branch touches `src/server/Match/`, which maps to the `match`
scope, and `src/server/ForestTestBoot.server.luau`, which maps to nothing and therefore to `all`):

    [harness] PASS: 33/33 checks @ b0e2c6cb119a2a155276de198e9cc97316218274 (clean tree) scope=all
    [harness] PASS: 33/33 checks @ ba7a8a097db41095930ac0bed26a4cb7e718b9c8 (clean tree) scope=all
    [harness2] PASS: 35/35 checks @ ba7a8a097db41095930ac0bed26a4cb7e718b9c8 (clean tree)

DIRECTOR NOTE: the last two lines are the Director's at the head `ba7a8a0` (only paperwork after `b0e2c6c`).

`[harness2]` is NOT pasted and the review does not need it: the line above is `scope=all`, not
`scope=auto:...`. **The MERGE does need it** -- `src/server/Match/` is in `TWO_PLAYER_PATHS` -- and
only the Director can press F7, so the report ends `NEEDS TEST2 192 <sha>`.

## What changed

Karen, 2026-10-14: *"when drive ends I am underground ... when next round is started respawn in
under terrain and I dead all a time"*; 2026-10-15: *"when I respawn I die or when new round I die"*.

Reproduced first, in the live Forest Test, with her own switches and a 0.5 s server sampler on the
player's root, before a line was changed. Four defects, one mistake: **a Y that was not measured at
the point it is used for.** One rule now, at one owner, plus a net under it.

Note: `docs/research/2026-10-15-one-placement-rule.md`.

## Claims

1. **`Body.onGround` is the one placement rule.** It replaces a target's Y with the ground measured
   at that target's own x,z plus a clearance, leaves X, Z and the rotation alone, retries a missed
   ray `GROUND_RETRIES` times, hands the caller's frame back unchanged when the ground cannot be
   read, and returns the measured ground so the owner can print it.
   *Verify:* `src/server/Match/Body.luau`, the section headed "task 192: ONE PLACEMENT RULE";
   `tests/server/match_place.spec.luau`, describe "Body.onGround".

2. **Every path a PLAYER is put down by goes through it, and they are the only such paths.**
   `Body.place` (the drive's placement AND the lobby's return, which is injected as
   `place = function(player, cframe) Body.place(player, cframe, Match.CONFIG) end` in
   `ForestTestBoot`) and `Body.standCharacter` (the results scene). `Body.tieCharacter` takes the
   one-sided lift instead, for the reason claim 7 states.
   *Verify:* grep `PivotTo` in `src/server/Match/Body.luau` -- four call sites, three of them the
   above and the fourth `Body.settle`, which is handed the SNAPPED frame.

3. **A caller's Y is now advisory, and no caller's arithmetic was changed to compensate.**
   `Body.placementFor` still returns post-top + `STAND_HEIGHT_STUDS`, `Scene.ringLayout` still
   returns its flat ring and `Lobby.spawnCFrame` still returns its porch slot -- `Lobby` is not
   touched by this branch at all.
   *Verify:* `git diff 5cc4472..b0e2c6c --stat` lists no file under `src/server/Lobby/` or
   `src/shared/Lobby/`; the headers of `Body.placementFor` and `Body.place` say so in words.

4. **There is ONE definition of "where is the ground" per world.** `Match.start` sets
   `Body.setGroundReader(world.groundAt)` and `Match.stop` clears it, the way it already does for
   `world.placement` and `world.config`; `ForestTestBoot` passes `Data.groundAt`, the same function
   it already hands `Markers.setReaders`, `Bots.start` and `Lobby.start`. A world that injects
   nothing gets `Body`'s own ray, which excludes characters -- the DEV place, where the arena's
   posts are solid parts, so the ray hits the post top and the snap is a no-op.
   *Verify:* `Match.start`/`Match.stop` in `src/server/Match/init.luau`; `groundAt = Data.groundAt`
   in the `Match.start` table in `src/server/ForestTestBoot.server.luau`; `Body.groundUnder`.

5. **The second writer of a character's position is gone while the drive holds him.**
   `ForestTest.boundary` is skipped when `Match.isHeld(player.UserId)` -- the same function the
   lobby is already handed for the same reason one screen up. It covers the gathering, the beaters'
   hold at the start line, and a hunter tied to a tree.
   *Verify:* the `if root and Match.isParticipant(...) and not Match.isHeld(...)` guard in
   `src/server/ForestTestBoot.server.luau`, and the comment above it with the measurement.

6. **The soft wall is HORIZONTAL and cannot bury anybody, and cannot pin a jumper either.**
   `ForestTest.boundary` takes a `lift` seam, given `Body.liftOntoGround`, which is ONE-SIDED: it
   moves a point more than `Body.maxBelowGround()` studs INSIDE the ground and never touches one on
   it or above it. `ForestTest.boundaryLifts()` counts it; `nil` is the old behaviour, so a spec
   with no Workspace drives it unchanged.
   *Verify:* `ForestTest.boundary` in `src/server/ForestTest/init.luau`;
   `tests/server/match_place.spec.luau`, describe "Body.liftOntoGround" (three cases: lifted,
   never-lowered, unmeasurable).

7. **The tie is deliberately NOT snapped, and that is a measurement rather than an omission.**
   `Body.tiePointFor` reads the TREE's own bottom face, which is already an answer to "where is the
   ground"; a ray would tie an offender to the ground far below a tree that stands on a rock, and
   `match_safety.spec`'s own fixture (a trunk 700 studs up) fails on exactly that -- it did, in the
   first gate run, which is how this was found rather than argued. The tie takes the one-sided lift
   only.
   *Verify:* `Body.tieCharacter`; commit `ab2ea94`; `match_safety.spec` passes at the code commit.

8. **The net is `Body.floorStep`, on the drive's existing 4 Hz step, and it is for the LIVING.**
   A character more than `MAX_BELOW_GROUND_STUDS` (5) under the measured ground, or below
   `FallenPartsDestroyHeight + 100`, is put back -- at the last place the ENGINE said it was
   standing (`Humanoid.FloorMaterial`), else on the ground over its own x,z -- with one console
   line. A dead ragdoll is skipped: measured, one slid ten studs downhill and clipped 47.8 studs
   into the terrain, and the net put a corpse back half a second before `LoadCharacter` destroyed
   it. It walks every player on the server, not the drive's roster, because the placement that
   killed Karen every round was the lobby's and a man at the lodge is in no roster.
   *Verify:* `Body.floorStep`; the `stats.rescuedFromUnderGround += Body.floorStep(playersService())`
   line in `Match:step`; `tests/server/match_place.spec.luau`, describe "Body.floorStep" (six cases).

9. **The scene's animals and torches sit on their own ground too, and without a reader the scene is
   exactly the one before this task.** `Scene.build` takes an optional `groundAt`;
   `Match.applyScene` passes `Body.groundUnder`. `match_scene.spec` -- which asserts the flat layout
   against `spot.Y` throughout -- is unchanged and green.
   *Verify:* `onGround` in `src/server/Match/Scene.luau` and its two call sites; the last case of
   describe "the results scene's ring" in `match_place.spec` asserts both halves.

10. **It was proved on the player's path, three times.** Three full cycles (lobby -> truck pad ->
    drive -> drive end -> gathering -> next round) on the `edge`, `ride` and `edge` layouts, plus a
    manual respawn during a drive, at the gathering and in the lobby. 1718 samples: **0 unrequested
    deaths** (the 3 deaths were each requested by the probe 0.0-0.1 s earlier and are logged as
    such), **0 `Freefall` samples** (before: the whole 25-second scene), foot height above the
    terrain between -2.6 (a corpse lying down, `hp=0`) and +1.3. The three `[place]` lines that
    carry the fix: `gather ... ground=168.8 askedY=174.5 dY=-2.2`,
    `spawn ... (2850, 153.7, -2934) ground=150.2 askedY=149.2 dY=+4.5` (the death, gone),
    `spawn ... ground=191.6 askedY=195.6 dY=-0.5`.
    *Verify:* `<runs-dir>/t192-after.log` and `t192-after-console.txt` (the before-run is
    `t192-before.log`); the task row in `TASKS.md`; `<runs-dir>/t192-after-gathering.png` and
    `t192-after-lobby.png`.

## What I could not verify

* **`test2`.** `src/server/Match/` is in `TWO_PLAYER_PATHS`, so the MERGE needs a two-player line and
  that needs a human F7. The review does not: the pasted line is `scope=all`.
* **The "last good position" branch of the net, in a spec.** `Humanoid.FloorMaterial` is written by
  the engine and cannot be set from Luau, so the spec's fakes exercise the other branch (back onto
  the ground over the body's own x,z). The remembered branch is proved by one live console line:
  `[place] RESCUED Alhamdulilah824: root (3549, 143.7, -2990) was 47.8 studs under the ground, put
  back at (3555, 195.1, -3000)` -- (3555, -3000) is his stand, which is where he had been standing.
  The spec says this in its header.
* **The guard in `ForestTestBoot`** (claim 5) is one line in a composition root, which has no spec.
  It is proved by the live log: the player stays at the slot the scene chose for the whole scoring
  phase, where before he was dragged 138 studs and buried.
* **"Terrain is broken" (dispatch item 3) is NOT a terrain defect, as far as I could measure.**
  564 ray samples over the lobby field, the whole drive area and the road corridor came back with
  **0 misses (no holes)**; the steepest 50-stud neighbour step is 18 studs and the steepest
  100-stud one 43; the live markers report `6/6 stands (0 refused), max ground delta 0.00`. Four
  screenshots from a player's height (`t192-edge-stand3`, `t192-road-stand5`, `t192-ride-stand3`,
  `t192-edge-wide`) show continuous ground. I believe Karen was describing being INSIDE the terrain.
  If a hole exists somewhere I did not sample, it is a different task.
* **Nothing about the map generator or any Studio-saved terrain was touched**, so no place was saved
  and there is nothing for Karen to re-open.
