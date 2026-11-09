# Task 327f — the map shows the whole grid, and a hunter picks his stand on it

Task: 327f
Round: 1
Base: b0d0a149
Code commit: 7aa55e5c71129245c7aa4d144864818e4001c0e7

Karen, 2026-11-09: *"I still can't select on map position and map is not updated I want to see all
map all sections"*.

```
[harness] PASS: 34/34 checks @ 7aa55e5c71129245c7aa4d144864818e4001c0e7 (clean tree) scope=all
```
`test2`: **N/A** — nothing in `TWO_PLAYER_PATHS` is touched. The change is `src/client/Hud/MapUi.luau`,
`src/client/Hud/init.luau` and `tests/client/map_ui.spec.luau`.

## PLAN (core protocol)
This task touches no `Boar/`, `Weapon/`, `Shotgun/`, `Ballistics/`, `Flight` or `Effects` path, so
step 0's "no `src/` edit before the plan is committed" does not bind it; the steps that do apply —
reproduce on her path, measure before and after, prove live in her place — were followed and are
claims 6–9.

## Claims (files and symbols, never line numbers)

1. **`MapUi.geometryFromGrid(grid, cellId, driven, base)`** draws the whole world off `Grid`: eight
   cells (`cellIds`, `worldBoundsOf`), every road (`roads`, `roadPolyline`), the dealt cell's stands
   at `Grid.standPosition`, `standKinds` from `towerStands` and `standSides` from `sideOf`, A1 marked
   empty from `PLANTED_CELLS`. Verify: `map_ui.spec` case 29 — every count is `Grid`'s own.
2. **The dispatch is the injected grid.** `MapUi.geometryFor(world, forestTest, map, layoutName, grid)`
   draws the world for a CELL and the layout's own map for everything else; the dealt cell's road and
   stands are `geometryFromForestTest`'s, value for value. Verify: case 30 (with/without the grid,
   and `"road"` unchanged — `map-ui.md` §21's "absent is pre-327 behaviour").
3. **The pads are measured, not transcribed.** `MapUi.standHitPx` takes the closest pair's LARGER
   AXIS gap (the pads are squares) less two pixels of air, so the 72 px pad that overlapped 70 ways
   on a cell (case 28's stated gap) is 26 px here with **0 overlapping pairs**. Verify: case 31,
   which also asserts the tower icon (bigger square, brass ring) against `Grid.towerStands`.
4. **323c: the stand list** is a `ScrollingFrame` of 15 rows, 42 real px a row at 400 × 800 (the
   panel's scale and the list's inverse scale multiply to exactly 1), it is **beside** the map and
   never over it, and every row calls the same `MapUi.tapStand`. Verify: case 32.
5. **The map follows the drive**: `cellStateFor` over all eight (active/driven/empty/free), and
   C1 → C2 redraws with the brass rim on the new cell. Verify: case 33. `driven` has no publisher
   yet (the cell vote is 327e) and is reachable by parameter.
6. **LIVE IN HER FOREST TEST, at this code commit** (`driven-hunt-rev` on :34873, her place, Play):
   `full=true cells=8 stands=15 listRows=15 title="section C1" footer="click a stand"`, rows reading
   `1 MAIN FREE … 7 MAIN TOWER … 15 EAST FREE`. Frame `327f-F1-after-full.png` (opened: all eight
   sections with their roads, A1 said empty, C1 ringed in brass with its 15 stands, the list beside
   the map, 0:14 LEFT in ASSIGNING).
7. **CLICK PROOF, same session, same commit**: one REAL left click (`click.ps1`) at the screen point
   of stand 4's own pad **on the map** → the footer went `"click a stand"` → `"stand 4 is yours"` and
   row 4 `4 MAIN YOURS`; the server then stood the player at `Grid.standPosition(C1, 4)`, **0.0
   studs** away (`327f-stand.luau`). Frames `327f-F2-after-full.png` (his stand marked, list row
   YOURS) and `327f-F3-after-full.png` (his eye height on that stand, drive running).
8. **The flag, in her place only**: `DHFlag_STAND_PICK` absent → `true`, and the before/after
   attribute dumps differ by **exactly that one line** (`327f-attrs-BEFORE.txt`, `327f-attrs-AFTER.txt`).
   Left ON by the Director's decision. `Flags.STAND_PICK.default` is untouched (`false`).
9. **A regression this task found and fixed, measured**: with the world's eight roads on the MINIMAP
   as well, `map_ui.spec`'s own tick case read the client at **11.2 Hz then 9.4 Hz** against its 20 Hz
   target, twice at 221c444c. The roads are the panel's only now (the minimap keeps the drive's own
   road, as before this task) and the same case reads **15.0 Hz** at the code commit.
10. **One writer each**: the map is still `Hud.MapUi`'s only, the pick still asks `StandPick` through
    `PickSystem.requestStand`, and `Grid` is INJECTED into `geometryFor` (the Hud requires it, the
    map does not).

## What I could not verify
- **327f-F4 (a phone frame) NOT OBTAINABLE this session**: the Device Simulator outlives the session
  and must be off before any gate run (it cost task 220 three runs), and this task needed four gate
  runs after it would have been switched on. The phone case is measured in case 32 instead: at
  400 × 800 the panel's own `UIScale` is **< 0.5** and the list's inverse scale cancels it to **1.000**,
  so a row is 42 real px against the 44 px thumb minimum.
- **No "before" frame of the old map**: her place had to be moved to this commit to be photographed
  at all. The before state is asserted instead by case 30 — the same call without the grid has no
  cells.
- The pick window is **15 s** (`Match.CONFIG.STAND_PICK_SECONDS` with the flag on); the live click
  landed 4.4 s into it. Not changed, as instructed.

ANSWERED: L-136 the flakes that fired are named with their runs (map_ui:1071 fired twice and was NOT
a flake — claim 9; weapon_shot:1490/:2077, weapon_client:1211/:1773, semiauto_client:93 and
deer_hitbox:682 fired on runs the FT was in Play beside the harness; the code commit's run is clean,
34/34).
ANSWERED: L-127 every item is MET or named NOT OBTAINABLE above.
ANSWERED: L-162 claims 6–8 were taken at the code commit, in her place.
ANSWERED: L-014 no code was ever checked out in `driven-hunt-karen`; her FT ends on :34873 from
`driven-hunt-karen` at main b0d0a149, in Edit.
ANSWERED: L-101 the attribute diff is claim 8.
ANSWERED: L-093 cases 29–33 all die if the drawing, the dispatch, the measured pad or the list is
removed; case 31's own numbers come from `Grid`.
