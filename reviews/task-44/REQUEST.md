# Task 44 — Milestone 2.2: the whole 2048-stud map

Task: 44
Round: 1
Base: `5a060ed` (task-43-map-slice; stacked on 41, 38, 36 and 35, none merged)
Code commit: `6bdd43b6724a21e43af0063468bb660574a851b9`

Harness, clean tree, one player:

    [harness] PASS: 27/27 checks @ 6bdd43b6724a21e43af0063468bb660574a851b9 (clean tree)

301 server specs (300 before this task's last commit, 274 before the map work), 70 client.

Harness, two players: **not run by me.** The Director's standing rule since Task 43 is that the
Builder never runs `test2`; this task ends on `NEEDS TEST2 6bdd43b`, and the `[harness2]` line goes in
before the review is run.

Generator, clean tree, same seed twice, and walkable — from one
`python tools/mapgen.py verify --seed 7 --backup census` (268 step lines and two run-log lines sit
between the digests; the reachability block is printed by the same command, just before the last line):

    [mapgen] build 1: digest=dbf6aef43044b14612770da0ff13917a6306aab68f49658c776e2698f6097fce parts=1238
    [mapgen] build 2: digest=dbf6aef43044b14612770da0ff13917a6306aab68f49658c776e2698f6097fce parts=1238
      BoarSpawn1: Enum.PathStatus.Success (355 waypoints)
      BoarSpawn2: Enum.PathStatus.Success (352 waypoints)
      BoarSpawn3: Enum.PathStatus.Success (339 waypoints)
      BoarSpawn4: Enum.PathStatus.Success (340 waypoints)
      DriverStart: Enum.PathStatus.Success (370 waypoints)
    [mapgen] reachability OK
    [mapgen] OK: same seed twice, same digest @ 81a0af4a51c9f6693573e99d0ba53ebec937c2b1 seed=7 digest=dbf6aef43044b14612770da0ff13917a6306aab68f49658c776e2698f6097fce (clean tree)

`81a0af4` is the commit the map was built from. `6bdd43b` is three commits later and changed no
generator code (`git diff --name-only 81a0af4..6bdd43b`): the research note, the owner row and the task
rows (`e488d72`); one spec fix (`9497f51`, claim 8); and the navmesh retry in the same spec (`6bdd43b`,
claim 11).

## What changed

Milestone 2.1's 512-stud slice becomes the whole 2,048-stud map: **268 steps, 1,238 parts, 6.3 M
voxels, about five minutes**. The design's section 12 corridor (x ± 340, z ± 800, the shooter line at
z = −700 and the drivers at +700), a **hedgerow network** of five lines cutting the map into ~512-stud
fields, two dirt tracks, and one bog outside the corridor. Props are still proxies.

It is still **not the world**: `Map.EXPECTED_WORLD` stays `"arena"`, and the map is cleared out of
Workspace before a harness run.

## Claims

1. **Every hedgerow line that crosses the drive corridor is gated, and the gate is inside the
   corridor.** `Scatter.hedgeGates` divides the line's corridor span into `gatesPerLine` slices and
   places one gate inside each, never closer to a slice edge than its own half-width;
   `Layout.hedgeSegments` drops every segment whose EDGE would reach into a gate;
   `Layout.widestGap` measures the clear span that resulted. The spec asserts the measured gap is at
   least `gateStuds` wide **for twenty seeds on every crossing line**, that no segment lies inside a
   gate, and that the same line with no gates has no gap at all.

2. **The generated map is pathfound, and the check bites** — TASKS.md row 43a(k).
   `MapGen.reachability()` walks every `BoarSpawn` and the `DriverStart` to the drive line with
   `Boar.CONFIG.AGENT`, and `mapgen.py verify` fails the run if any route does not arrive. Proved
   sharp by measurement, not by argument: with one wall dropped across the corridor's gates all five
   routes returned `NoPath` and the command failed; with the wall removed all five returned `Success`
   at the same waypoint counts. Run it yourself with `python tools/mapgen.py reach`.

3. **Two engine facts were measured before the check was trusted** (research note, "Measurements,
   Milestone 2.2"). `PathfindingService:ComputeAsync` works in an Edit session through `execute_luau`;
   and **Studio's navmesh lags the map** — the same wall answered `Success` one second after it
   appeared and `NoPath` after five — so `MapGen.reachability` waits `REACH_SETTLE_SECONDS = 6` before
   asking. A check that races the navmesh answers about the map as it was.

4. **The map is reproducible at full size.** Two complete builds of seed 7, each preceded by a clear,
   produced the same 64-hex digest over 1,238 instances **and 4,096 terrain samples**.

5. **The bog is one feature, not two.** `Layout.bogDepth` decides both the dip in the heightfield and
   the Mud material, per voxel, in the terrain pass — so there is no bog step, because a step that
   could only repaint what is already right is worse than no step. The track pass refuses to paint
   over the bog, so the two features cannot fight.

6. **The tie trees are placed, not chosen.** At 2,048 studs the wood begins beyond the corridor, so
   the nearest scattered trunk is ~150 studs from the line and the design's "within 120 studs"
   (§4.3) could not hold. `Layout.tieTreePoints` puts twelve trees 45 studs **behind** the line across
   the post span; `Props.tieTrees` places them in their own folder and `Markers.tagTieTrees` tags
   exactly those. The spec asserts all twelve are within 120 studs and none is in front of the line.

7. **One predicate decides where a tree may not stand**, and the spec shares it.
   `Props.rejectTree` = corridor, track, bog, or within `SCATTER_CLEARANCE` of a hedgerow line — which
   closes row 43a(o), the trees that could stand inside a hedge on the slice's flank. The spec checks
   each of those four conditions separately against the placed points, so a predicate that silently
   stopped rejecting one of them would fail.

8. **The map's rectangle and the contract's rectangle are kept apart on purpose.** `Map.FIELD` is the
   rectangle of the world `EXPECTED_WORLD` names — the arena, which must equal `Boar.CONFIG.field` and
   which another test asserts. `Config.FIELD` is the generated map's, used by `verifyContract` and by
   the spec, and asserted against the design's section 12 numbers so it cannot drift. At M2.5 the two
   become one. (The harness caught me getting this wrong: the planned-marker test compared the map's
   spawns with the arena's bounds and failed. That is commit `9497f51`.)

9. **Task 43's queue, folded in where the items were real and small.** 43a(n): the duplicated
   `STAND_HEIGHT_STUDS` is gone. 43a(m): `Settings.current` and `MapGen.markerDigest` now have a reader
   in `mapgen.py contract`, and `Markers.tagged`, which had none and which `Markers.counts` answers
   better, is gone. 43a(p): the `mapgen.py` docstring names both evidence lines. 43a(o) and (b) are
   claims 7 and 10.

10. **Seven screenshots, taken by `mapgen.py shots` at the map's own scale and looked at**
    (`.screenshots/map-*.png`, rule 5). The design's six cameras, with `map-stand` pointed at the tie
    trees (the only stand M2.2 builds) and a seventh, `map-gate`, on a hedgerow gate — the fix this
    task exists for, and a picture is the only way to see it is really there.

11. **The harness flake is diagnosed and fixed** — TASKS.md row 43a(j). `25/27` is exactly the two
    `[server] status` checks, i.e. ONE server spec failing, and the only server spec that can fail on
    an unchanged tree is the arena pathfinding check this file gained in Task 43 — the flake arrived
    with it. Same cause as claim 3: the navmesh is rebuilt in the background and `ArenaBoot` builds the
    arena moments before the spec runs. It retries for 10 s now, and a world with no route still fails.

## What I could not verify

* **Measurement B (do tags survive a save and a reopen) is still open** from Task 43. The Director and
  Karen own that click. Nothing in this task changes it.
* **Nobody has walked this map.** Reachability says a pathfinding agent can cross it; whether the
  fields are the right size, whether the gates are where a driver would want them, and whether the bog
  is a feature or an annoyance are Karen's, on foot.
* **The reachability check paths to the drive line's centre only.** A map where a boar could reach the
  centre but not one end of the line would still pass. Queued as 44a(e) for M2.5.
* **The design's hedge LENGTH row is exceeded**: section 12 asks for ≤ 6,000 studs of hedge and the
  network is 10,240. The PART budget is met (400 of ≤ 500) by using 24-stud segments instead of 12.
  Queued as 44a(a) for the Architect rather than quietly ignored.
* **Row 43a(j)'s diagnosis is an inference, not a measurement.** I never caught the failing run's own
  output: five runs at `73b1d25` all passed. The reasoning is in claim 11, and if a `FAIL: 25/27`
  appears again it was wrong.
