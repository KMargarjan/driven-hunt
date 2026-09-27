# Task 85 — a bare test world

Task: 85
Round: 1
Base: `main` (`155c021`)
Code commit: `a55997c191dc56d50d481cc51290d13dc3699fe2`

```
[harness2] PASS: 32/32 checks @ a55997c191dc56d50d481cc51290d13dc3699fe2 (clean tree)
[harness]  PASS: 32/32 checks @ a55997c191dc56d50d481cc51290d13dc3699fe2 (clean tree)
```

Karen, 2026-09-27: *"remove all trees and unnecessary terrains, so we will focus now on shotgun
shooting etc and boars, so rest is just extra time and noise to load."*

**What changed.** `src/serverstorage/MapGen/Config.luau` (`Config.INCLUDE`), `Height.luau` (one early
return), `Layout.luau` (a guard per layer), `MapGen/init.luau` (the tree/brush/track steps),
`src/shared/Map/init.luau` (the digest), `tests/server/map_contract.spec.luau`, `GAME_DESIGN.md`,
`TASKS.md` rows 85/85a. **Nothing was deleted** — every generator is still here and still measured.

**One gate failed on the way, diagnosed before anything was re-run.** `28/32` and `30/32 @ 94a3807`:
eighteen cases in `map_contract.spec`, all of them measuring a **generator** (the height field's
noise, the corridor's slope ceiling, the species mix, the hedge and wood part budgets) whose layer the
bare world had just switched off — so they measured nothing. They ask `withScenery()` now.

## Claims

1. **IT IS A SWITCH PER LAYER, NOT A DELETION.** `Config.INCLUDE` has one row per layer; eleven are
   `false` and `stakes`/`tieTrees` are `true`. Flip a row and run `mapgen.py build --seed 1` and that
   layer is back. `TASKS.md` row 85a(a) lists the rows.
2. **THE BARE WORLD IS ASSERTED AT ITS EFFECT**, not by reading the table back: `map_contract.spec`
   "builds the bare world" asks the live config for the height at three points (all `GROUND_Y`),
   `bogDepth` (0), `treeBlocks`, `hedgeLines`, `highSeats` (all empty), `onTrack` (false) and
   `furniture` (16 stakes, and `highSeatLeg`/`barrierBoom`/`log`/`fencePost`/`gate`/`reed` absent).
3. **AND EVERY ONE OF THOSE BOUNDS IS PROVEN NOT TO BE A BOUND ON NOTHING**: the same case asks
   `withScenery()` — the live config with every row `true` — and the tree blocks, hedge lines, high
   seats, bog depth and track all come back.
4. **FLAT GROUND IS AN EARLY RETURN, NOT `RELIEF = 0`.** `Height.at` returns `config.GROUND_Y` when
   `INCLUDE.relief` is off, because `corridorFalloff` and `benchBand` **divide** by `RELIEF`.
5. **THE EIGHTEEN GENERATOR CASES NOW ASK WITH THE LAYER ON**, which is what keeps the switch a
   one-line change: `withScenery()` in `map_contract.spec` clones `MapGen.CONFIG` and sets every
   `INCLUDE` row true. The cases that measure the BUILT world still use `config()`.
6. **THE COUNTS DID NOT MOVE AND THE DIGEST DID.** `Map.EXPECTED_COUNTS` is untouched (shooterPost 8,
   driveLine 1, driverStart 1, boarSpawn 4, tree 12); `Map.DIGEST` is
   `15183f41211b3ba32453bf012277a323182fa95e07824a0479c68a8e884d8534`, which is what
   `python tools/mapgen.py digest` reads back out of the saved place (70 parts, 4096 samples).
7. **THE DRIVE STILL WORKS.** `mapgen.py verify` → reachability OK from all four BoarSpawns and the
   DriverStart to five points on the line, and the same seed twice gives the same digest.
   `mapgen.py contract` → `contract OK`. The gate's own `zz_drive_boundary` ran a live drive on this
   world: `phase=Running releases=1 boars=3 alive=3`.
8. **THE TIE TREES ARE REAL TREES, AND THAT IS WHY THEY ARE KEPT.** `Match.Body.anchorFor` ties a
   punished player to a `DrivenHunt.Tree`, so `INCLUDE.tieTrees` stays true and twelve are built — no
   new marker kind, and the penalty needed no change.
9. **MEASURED, BEFORE AND AFTER.** `DrivenHuntMap` **9,156 → 86 descendants**; 70 parts; terrain
   **3,381,368 → 3,145,728** cells; steps **274 → 262**; the run's own step time **3,561 → 1,993 ms**;
   a whole build is **22 s** wall clock.
10. **THE SCREENSHOTS, AS THEY ARE.** `map-stand-close.png`: the pale gravel road across flat tan
    ground, the near stand's orange-capped stake beside it and the next stakes receding, the tie trees
    in a line to the left. `map-road.png`: clear sky, flat ground to the horizon, the tie-tree line and
    the stakes — **the gravel is hard to pick out along its own length** with nothing to frame it
    (`TASKS.md` 85a(d)). `map-wide.png` is a hazy overhead view of the plain with a faint row of
    markers, very low contrast.

## Not verified

- **Nobody has played the bare world.** Pathfinding says the boars can cross; whether the drive
  *reads* on open ground, and whether a road with no wood beside it is still obviously the shooter
  line, is Karen's call.
- The "one row brings it back" claim is proven for the generators by `withScenery()` and by reading,
  **not** by an eleven-layer rebuild.
