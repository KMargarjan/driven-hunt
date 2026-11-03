# BRIEF -- Task 328o: curved forest roads on the grid (Architect design run)

Written by the Director, 2026-11-03. Input to `tools/architect.sh design grid-roads --task 328o`.
This brief overrides anything older in docs/, TASKS.md or an earlier design (docs/ARCHITECT_PROMPT.md).

## Karen's words (2026-11-03 ~11:20 UTC, C1 playtest 2, verbatim)
"more trees, and road could be also not just straight make line in real life"

## Decisions already taken
1. **The grid roads bend in plan**, like real forest roads. No road in the world stays a ruler line.
   The 2x4 cell topology stays: 3 east-west roads, 5 north-south roads, 8 cells, the same cell ids,
   the same drive direction (+Z to -Z), the same main line, muster and flanks per cell (grid-map.md 4.2).
2. **Junctions still meet.** Each road is fixed at its junctions and bends between them, so cells stay
   closed and a hunter on a corner still stands at a crossing.
3. **Borrow what exists first** (rule 2). The old `road` place already curves: `ForestTest.LAYOUTS.road`
   `amplitudeStuds = 30` over `SHAPE.wavelengthDivisor`, and it has a surface row (`Ground.luau`). The
   design states whether that sine is enough, or names the real-world reason it is not. Plausible real
   forest-road plan geometry (minimum curve radius, how often they bend) gets a source.
4. **C1 is re-baked, from the base snapshot** (328k; `TerrainBake` reads `terrain-base-<sha>.bin`, never
   live ground). Karen accepted C1's ground, paint and forest otherwise ("rest is good" / "rest is ok"),
   so the landform, paint rules and forest v2 rules are kept, and only what the road line moves changes.
5. **328h (bake the other 7 cells) waits for this design**, so no straight-road cell is baked and redone.
6. **No new assets, no uploads.**

## What the design must contain
- The road centreline as a pure function, with one owner (`src/shared/Grid` per grid-map.md 3.1), and
  every consumer that today assumes a constant `roadZ`/`standX` along a road listed with how it changes:
  the stand slots and their facing, the tower spots, Grid.standPosition, the road cross-section
  (ditch/verge, grid-terrain 7.1), the frontage and crown rules (7.2), Places.mask, the bake's road
  profiles (`profilesFor`), the pads, the rides, the safety arc / shooting cones (7.4), the beater muster
  line, `exitZOf`/goal-past-line, the map UI's bounds and road drawing, and the animal drive field.
- The numbers: amplitude and wavelength (or radius) per road class, the worst case where a bend meets a
  junction, and the clear-width rule on the inside of a bend.
- The census and spec changes: what proves "no crown over road" and "stands on the road edge" once the
  road bends, plus grid.spec case 14's capacity bound. It assumes 7 parts per model; the measured figure
  is 3.03. Revise that bound so "more trees" in C1 is not blocked (C1 has 184 spare before case 14 goes red).
- The task split (build steps, each small and testable), and the order against 328h, 328i and 328g.
- A fresh Forest Test backup (File > Download a Copy) before any re-bake.
