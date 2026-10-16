# Task 191 — the gathering happens on clean ground, next to the cabin

Task: 191
Round: 1
Base: 458b99a (main, #176 merged — task 195)
Code commit: `2e50710f9aa7f2fb564469281067aa156dbcef82`

Harness, clean tree, at the code commit (run by the Director):

```
[harness] PASS: 33/33 checks @ 2e50710f9aa7f2fb564469281067aa156dbcef82 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 2e50710f9aa7f2fb564469281067aa156dbcef82 (clean tree) scope=auto:lobby,match
[harness2] PASS: 35/35 checks @ 2e50710f9aa7f2fb564469281067aa156dbcef82 (clean tree)
```

`[harness2]` is **required and present**: `src/server/Match/init.luau` and
`tests/server/zz_drive_boundary.spec.luau` are both in `TWO_PLAYER_PATHS`.

Karen, 2026-10-15 ~17:20, verbatim: *"next is when hunt over everyone is in clean ground no grass
firstable / second it could be next to cabin"*. And after playing it, 2026-10-16 ~12:45: *"yes it
works / I shoot and cna see them there"* (`PLAYTEST.md`).

The end-of-drive gathering (tasks 159 / 168 / 173) happened at the **drive's** own spot out in the
forest, where tall grass hid the animals and the players. It happens in the lobby's clean, flat,
blade-free yard **west of the lodge** now. Research note:
`docs/research/2026-10-16-gathering-at-the-cabin.md`.

## Claims

1. **The world gets first say, and the drive's old rule is the fallback — not a replacement.**
   `Match.gatherSpotOf(reader, markers, cfg)` is new, PURE in the reader, and returns
   `(spot, facing, fromWorld)`. `Match.gatherSpot()` is the one line that hands it
   `world.gatherSpot`, and `applyScene` calls that instead of `Match.gatherSpotFor`.
   `Match.gatherSpotFor` is **unchanged** and is still what answers when the world names nowhere.
   The pattern is ioquake3's `FindIntermissionPoint` (GPL-2.0), fetched and quoted verbatim in the
   note section 3.1: the authored point first, `if ( !ent )` the derived one.
   *Verify:* `Match.gatherSpotOf`, `Match.gatherSpot` and `applyScene` in
   `src/server/Match/init.luau`; the five fallback cases in `match_scene.spec.luau`'s
   *"who decides where the drive gathers"* describe — no reader, a reader that answers nothing, one
   that answers a spot and no facing, one that answers a non-`Vector3`, and one that **throws**.
   `git diff 458b99a..2e50710 -- src/server/Match/init.luau` shows `gatherSpotFor`'s body untouched.

2. **A world that injects nothing is the game bit for bit, and that is reachable by parameter.**
   `ForestTestBoot` passes `gatherSpot = if lobbyOn then Lobby.gatherSpot else nil` — the same
   `if lobbyOn` guard `enrol` already uses — and the **DEV place has no lobby at all**
   (`Lobby.ANCHORS` has no `map:v1` row). So the harness's own world takes the fallback, which is
   why no flag row was added (`Flags` is at `MAX_FLAGS = 13`, and a flag over an absent function
   could not satisfy *"reachable by parameter as well as by flag"*).
   *Verify:* the `Match.start({...})` call in `src/server/ForestTestBoot.server.luau`;
   `Lobby.ANCHORS` in `src/shared/Lobby/init.luau`; and the new assertions in
   `tests/server/zz_drive_boundary.spec.luau` *"built the results scene"*, which now calls the live
   owner's `Match.gatherSpot()` and requires `fromWorld == false` and
   `Match.stats().sceneWorldSpots == 0` **on the real production `Match` in the DEV place**.

3. **The yard's rectangle is written once.** It is one row in `Lobby.CONFIG.FIELD.PADS` named
   `Gather` (56 × 56, `Enum.Material.Ground`), found **by name** by `Lobby.gatherPad(cfg)`. Four
   things read that one row — `Field.fill` lays the blade-free block from it (it already loops the
   list, so this is a row and not a code path), `Lobby.gatherSpotFor` reads its centre,
   `Build.treeLine` keeps a tree off it, and `lobby.spec` bounds the drive scene inside it. Nothing
   recomputes the rectangle.
   *Verify:* `CONFIG.FIELD.PADS` and `CONFIG.GATHER` in `src/shared/Lobby/init.luau`;
   `Lobby.gatherPad` and `Lobby.gatherSpotFor` in the same file; `Field.fill` in
   `src/server/Lobby/Field.luau` (unchanged); `treeLine` in `src/server/Lobby/Build.luau`. Grep for
   `Vector3.new(-50` — it appears once.

4. **The spot's height is measured, never predicted.** `Lobby.gatherSpotFor` asks the injected
   `groundAt` at the yard's **own centre** (once), and falls back to `anchor.Y` only when the reader
   is absent, answers a non-number, or throws. That is task 186's fault stated as a rule:
   `Field.fill`'s surface is voxelised and is **not** the nominal shelf, which is how four trucks
   got their tyres 0.752 studs underground. Live, the server printed `(2800, 150, -2940)` against a
   shelf of 149.2.
   *Verify:* `Lobby.gatherSpotFor` in `src/shared/Lobby/init.luau`; `Lobby.gatherSpot` in
   `src/server/Lobby/init.luau` (it passes `world.groundAt`, the same reader `tryBuild` used for the
   shelf); `lobby.spec` *"measures the spot's height and never predicts it"*, which asserts the
   reader is asked **once** and about the yard's centre, not the anchor; and
   *"falls back to the shelf for a reader that answers nothing, throws, or is not there"*.

5. **The whole scene fits in the yard, measured against `Match`'s own numbers.**
   `Scene.cornerReachFor(MAX_ANIMALS, Match.CONFIG)` is 23.5 studs — the four torches on both axes,
   which already contains the ring (`ringRadiusFor`), which already contains the rows — so the
   worst-case square is 47 studs inside a 56-stud yard. The spec asks `Match.Scene` for that number
   rather than copying it, and also asserts `ringRadiusFor <= cornerReachFor`, which is what makes
   one bound enough.
   *Verify:* `lobby.spec` *"holds the WHOLE scene at its worst case, measured against Match's own
   numbers"* — it requires `Match` and reads `Match.CONFIG.SCENE.MAX_ANIMALS`.

6. **Nothing of the lobby's own layout is touched, and what clears the lodge is the scene, not the
   dirt.** The gathering square's east edge is 5.5 studs from the chimney's west face and 8.5 from
   the wall; the pad's own east edge stops 4 studs short of the lodge footprint; the road, the
   fences, the porch, the spawn, the four truck bays and the four pads are all east of the pad.
   *Verify:* `lobby.spec` *"clears the lodge, the porch, the spawn, the road, the fences, the trucks
   and the four pads"* — the pad clearances are compared against `CONFIG.LODGE`, `CONFIG.ROAD`,
   `CONFIG.FENCE`, `CONFIG.SPAWN` and `Pads.centreFor` (the one place the pad arithmetic lives),
   never against literals.

7. **The yard takes no tree out of the line, and a tree cannot stand on it.** `Build.treeLine` gains
   a third exclusion, the same shape as the road and yard ones it sits beside, reading
   `Data.gatherPad(cfg)`. It removes **nothing today**, and that is measured rather than asserted:
   the western arc's nearest trunk was read out of the live place at x −86 against a yard edge of
   −78, and 27 trees were built — the same 27 the road and yard rules already left.
   *Verify:* `treeLine` in `src/server/Lobby/Build.luau`; `lobby.spec` *"takes no tree out of the
   line, and lets none stand on it"*, which walks **every angle at every radius in the jitter band**
   one stud at a time (a convex box can be crossed with both endpoints outside, so the two extremes
   alone would not be a proof); and *"keeps a spruce off the yard even if the arc is moved onto it"*,
   which builds a lobby with a tree line aimed at the yard so the `continue` is actually reached.

8. **The pad audit now covers every pad, which is the latent fault this task would otherwise have
   walked into.** `lobby.spec`'s *"writes nothing outside the field's own rectangle"* was written as
   `CFG.FIELD.PADS[1]` and `CFG.FIELD.PADS[2]`, so a third pad — this one — would never have been
   bounded by the one audit that bounds them. It iterates the list and asserts the count.
   *Verify:* that `it` in `tests/server/lobby.spec.luau`; `git diff` shows the two indexed calls
   replaced by a loop plus `expect(#blocks).to.equal(2 + #CFG.FIELD.PADS)`.

9. **The console says where it gathered, and a counter tells the two rules apart.** The `[match]`
   line now carries the spot and names *"the world's own spot"* or *"the drive's spot behind the
   stands"*, and `stats.sceneWorldSpots` counts the former. A line saying twelve animals were laid
   out in two rows cannot tell the cabin from the grass; this one can.
   *Verify:* `applyScene`'s `print` and the `sceneWorldSpots` row in `stats` in
   `src/server/Match/init.luau`; `zz_drive_boundary.spec.luau` asserts it is 0 in DEV (claim 2).
   Live, in Karen's place: `[match] gathered 0 animal(s) in 0 row(s) at the world's own spot (2800,
   150, -2940): 0 real model(s), 0 box(es)`.

10. **Measured live, in Karen's Forest Test, three drives run to their end** — and the third
    measurement **changed the design rather than confirming it**. The first built yard came back
    **623 `Ground` and 2 `Grass`** over the worst-case square: `Terrain:FillBlock` writes 4-stud
    voxels and an edge off the grid keeps its blades (x 2770 is 692.5 voxels). The yard moved two
    studs east onto the grid and re-measured **625 / 625 `Ground`, spread 0.00 at y 150.00, 0
    obstacles, 0 misses**. Also: 4 torches, 7 bots in the ring, the player's feet **0.35 studs above
    the ground** (Karen's earlier *"underground"* stays closed), 61.6 studs from the lodge floor,
    **0 "Stack Begin", 0 error lines, 9 waves**, and the gun in the **character** at 56 s and 96 s.
    *Verify:* the numbers and how each was taken are in
    `docs/research/2026-10-16-gathering-at-the-cabin.md` section 5; the voxel reason is written into
    the `Gather` row's own comment in `src/shared/Lobby/init.luau`. Screenshots (git-ignored, copied
    to the runs dir): `191-gathering-aimed-1.png`, `191-gathering-lodge-2.png`.

## What I could not verify

* **No boar was shot in any of my three smoke drives**, so the row was empty in every picture I
  took. My *"no grass over an animal"* claim therefore rests on the 625-sample material grid over
  the whole worst-case square (claim 10) and on claim 5's arithmetic, **not** on a carcass I
  photographed. **Karen closed exactly this half by playing it**: *"I shoot and cna see them there"*
  (`PLAYTEST.md`, 2026-10-16).
* **The bots' ring slots are not ground-snapped the way a player's are.** `Bots.gather` →
  `Rig.place` pivots to the ring CFrame; only `Body.stand` runs `Body.onGround`. It does not matter
  at this yard because the yard is dead flat (spread 0.00) and the spot's own Y is the measured
  surface, but it is untested on sloped ground and it is **unchanged by this task**.
* **The camera keeps its own yaw at the gathering**, so the scene can open facing away from the
  animals. `Match.Body.stand` turns the character and never the camera — `docs/design/camera.md` 6.4,
  the missing character/movement owner that `ESCALATE.md` 2026-10-13 already records. **Pre-existing
  and out of this task's scope**; queued for the Director, and noted in `PLAYTEST.md`.
* **`docs/design/lobby.md` and `docs/design/drive.md` do not yet describe `world.gatherSpot` or the
  `Gather` pad.** Designs are the **Architect's** lane; the Builder does not write them. Queued.
* **I could not read script `.Source` in the Forest Test Studio** — every script answers `""` there
  over `execute_luau` while DEV answers the exact disk byte counts — so "the branch reached that
  place" was proved **behaviourally** (the server's own `[match]` line and the measured scene), not
  textually.
