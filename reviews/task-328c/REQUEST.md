# Task 328c -- RELIEF: the eight landforms and the shaping arithmetic

Task: 328c
Round: 1
Base: 17c8d0bf (main, with 328b #314 merged)
Code commit: 52b4667e7514c070ce8d23cd2cbfa3b2bf02f4cc

```
[harness] PASS: 34/34 checks @ 52b4667e7514c070ce8d23cd2cbfa3b2bf02f4cc (clean tree) scope=all
```

`[harness2]`: **N/A.** Nothing changed touches `TWO_PLAYER_PATHS` -- `src/shared/Grid/` is the map,
not the match, the drive, the tie or the teams, and `tools/studio_mcp.py`'s change is one
`SCOPE_SPECS` row. Director decision 2026-10-03.

**What changed.** Three new files and one row:
`src/shared/Grid/Relief.luau` (the eight landforms plus the pure arithmetic),
`tests/server/relief_golden.luau` (the BAKE_VERSION epoch golden),
`tests/server/grid_relief.spec.luau` (design 13.1), and `grid_relief.spec` added to
`SCOPE_SPECS["map"]` in `tools/studio_mcp.py`. **Nothing writes terrain, nothing reaches Karen's
place, and no existing file's behaviour changes.**

## Claims

1. **`Relief` requires nothing.** `src/shared/Grid/Relief.luau` has no `require`, no
   `game:GetService`, no `Instance`, no `Terrain`, no `Random`. It does not require `Grid`, and
   `src/shared/Grid/init.luau` does not require `Relief`. *Verify:* read the file head to `return
   Relief`; `grep -n "require\|GetService\|Instance\." src/shared/Grid/Relief.luau` is empty.
2. **The eight rows are SWARM_DESIGN section 2.2's recipes.** Compare `Relief.LANDFORMS` against
   `reviews/task-328/SWARM_DESIGN.md` section 2.2's eight **Sculpt** blocks, row by row.
   `grid_relief.spec`'s *"has one landform for each of the eight cells"* asserts the field ranges.
3. **B2 ships a 24-degree scarp with THREE ramps at u .20, .50 and .78** (design 15 item 4), and its
   `noTrees` band is the scarp +- 8 studs. *Verify:* `grid_relief.spec`'s *"ships B2 with a
   24-degree scarp and THREE ramps"*, and the gate's measured `SCARP`/`RAMP` rows in the report below.
4. **`Relief.columnsFor` is `Places.Ground.bandBounds`' arithmetic, generalised, not re-derived**
   (design 4 rule 2, 7.1 correction F-2). Same shape: `columns = ceil(width / VOXEL)` then anchor on
   the band's own midpoint. *Verify:* read both functions side by side;
   `grid_relief.spec`'s *"turns every nominal band into whole voxel columns, whatever the centre's
   parity"* runs design 7.1's five bands at a centre congruent to 0, 1, 2 and 3 (mod 4) and asserts
   the realised WIDTH does not move with the parity.
5. **`relief_golden.luau` binds the arithmetic to `BAKE_VERSION`.** 48 heights (6 named (u,v) a
   cell) over a stated synthetic base, plus `Golden.bakeVersion`. *Verify:* `grid_relief.spec`'s
   *"matches relief_golden.luau, and the version it was measured at"* asserts
   `Relief.BAKE_VERSION == Golden.bakeVersion` and all 48 to 1e-6, and notes the design's own
   failure sentence when one moves.
6. **`grid_relief.spec` is in the `map` scope.** `SCOPE_SPECS["map"]` in `tools/studio_mcp.py`;
   `python tools/studio_mcp.py selftest` passes (it fails if a spec belongs to no scope), as does
   `python tools/agents.py selftest`.
7. **Design 13.1's twelve cases are covered**, in this spec's own describe blocks: 1 golden,
   2 the eight landforms, 3 falloffs, 4 scarp/bench/ramps, 5 the road fade, 6 the limiter,
   7 outside the footprint, 8 tile alignment, 9 the voxel ceiling, 10 `columnsFor`, 11 `epochInput`,
   12 no terrain written. Three deviations are listed under **Deviations** and each says why.
8. **Nothing in this change writes terrain.** *Verify:* `grid_relief.spec`'s *"drives all eight
   landforms and changes not one voxel of the place"* drives 121 points a cell through `heightAt`
   and `materialAt` and asserts `Terrain:CountCells()` and a `ReadVoxels` of a whole 128-stud tile
   are identical before and after. This is a BEHAVIOURAL proof and it is the one that carries
   design 1.2 item **1** -- see **Deviations** 3 for why the source scan cannot be it.
9. **The road stays flat.** `roadFadeAt` is exactly 0 at every centreline and at 51 studs from it,
   and exactly 1 at 120 studs wherever no crossing road is nearer -- asserted over all eight roads
   at 11 points each, both sides (the spec counts the full-fade assertions and requires > 100).
10. **The limiter meets its ceiling.** A 63.4-degree synthetic cliff comes out at exactly 20.00 and
    32.00 degrees, and every cell's own column -- over a flat base and over a base built from that
    cell's measured `Grid.CELLS[*].relief` row -- is at or under its ceiling clear of the pins.
    A pinned band is returned byte-identical.

## Measured (the gate run at 52b4667e unless a row says otherwise)

Worst 16-stud window AFTER `limitPass`, clear of pinned samples, `u = 0.64` (off B2's ramps):

| cell | flat base, ceil 20 | flat base, ceil 32 | measured base, ceil 20 | measured base, ceil 32 |
|---|---|---|---|---|
| A1 | 7.73 | 7.73 | 20.00 | 24.67 |
| B1 | 13.54 | 13.54 | 17.37 | 17.37 |
| C1 | 14.04 | 14.04 | 16.33 | 16.33 |
| D1 | 5.02 | 5.02 | 7.53 | 7.53 |
| A2 | 1.99 | 1.99 | 5.88 | 5.88 |
| B2 | 20.00 | 30.82 | 20.00 | 32.00 |
| C2 | 0.16 | 0.16 | 5.86 | 5.86 |
| D2 | 17.11 | 17.11 | 20.00 | 32.00 |
| B2 at u .50 (through a ramp) | 20.00 | 30.82 | 20.00 | 32.00 |

B2's scarp and ramps, measured off `heightAt` (probe run, 2026-11-02; `heightAt` is unchanged since
-- the gate's golden case re-asserts all 48 of its samples to 1e-6 at the code commit):
`SCARP B2 drop=28.115 over=64 meanDeg=23.72 faceMaxDeg=33.24` --
`RAMPPURE B2 u=0.20/0.50/0.78 grade=15.000%` each.

Road fade, every road, probe run: `at51=0.000000` for all eight.

Each op's own peak against its recipe, probe run, flat base: A1 trough -14.000 / B1 dome +22.000,
trough -8.000 / C1 ridge +24.000, saddles cut it to +12.000 / D1 bowl -10.000 / A2 trough -13.000 at
v .60 (0 at v .20 to -26 at v 1) / C2 knolls +26.000 each / B2 scarp -14.000 at its centre.

## Deviations from the design, each with its reason

1. **`Op` gains `rzStuds`.** SWARM 2.2 gives D1 "rx 260 st, rz 200 st" and design 4's `Op` sketch has
   one `rStuds`. `rzStuds` is optional and nil means a circle.
2. **`limitPass` gains an `exempt` parameter and `Relief.isExempt`.** Design 3.0 says the scarp and
   ramps are exempt and design 4's signature has nowhere to say which samples those are.
   Design 4's API is otherwise present in full.
3. **Design 13.1 case 12's source scan cannot be a spec's instrument. MEASURED:** the spec reads
   `Script.Source` inside a pcall, proves the instrument on a script with known source, and the gate
   run prints `grid_relief source scan: Script.Source is UNREADABLE` -- `Source` needs
   PluginSecurity, which design 5.4 itself records. The scan arm therefore asserts its own verdict
   rather than passing silently, and §1.2 item 1 is carried by claim 8's behavioural proof. The
   scan arm is written and will run the day the instrument becomes readable.
   (A literal repo-wide scan would also fail today for a legitimate reason: `src/server/Lobby/Field`
   and `src/server/Places/Ground` write terrain for the LOBBY and the four line places, which §1.2
   item 1 names as untouched. They are the spec's allow-list.)
4. **Design 13.1 case 3's "0.001 of weight a stud at the support boundary"** is met by every falloff
   whose support is >= 100 studs and asserted there. A ramp's 16-stud side blend cannot reach it
   (0.0112 at its last non-zero stud), so what is asserted for the short blends is the thing the
   figure is FOR: under 0.25 studs of HEIGHT a stud, which is one voxel over four studs.
5. **Two numbers the measurement moved, both in the code with the reading beside them:**
   a bench's v-edges now blend INSIDE its band (blending 40 studs past `v1` put 5.5 studs of plateau
   on B2's scarp and read the 28-stud face as 33.5); and `limitPass` finishes with an exact
   forward-then-backward min-cone clamp, because 8 relaxation passes alone leave a 63.4-degree cliff
   at 22.92 against a ceiling of 20.
6. **Design 15 item 4's "~75 st" worst corridor-to-ramp distance is 96 st** (`TASKS.md` 328a-notes
   (d)). Not used here -- the three ramps ship as the design rules -- recorded because this task
   re-derived it.

## Not verified

- **No bake, no Studio terrain change, no change to Karen's place.** `Relief` is required by nothing
  live until 328d. There is no Forest Test proof and none was asked for.
- The **hillshade pictures** are rendered from `Relief.heightAt`'s own output at a 25-stud pitch
  (`<runs-dir>/328c-relief-<cell>.png`). The heights were produced by a spec driving the real module
  in a harness Play run, not by a standalone Luau interpreter: the repo pins none, and the MCP thread
  may not `require`. No terrain was read or written to make them.
- `materialAt` has one case (its three stated floor rules). It has no caller until 328d/328e.
- The budgets of design 12.2 stay UNMEASURED; nothing here cites one.
