# Task 328c -- RELIEF: the eight landforms and the shaping arithmetic

Task: 328c
Round: 2
Base: 17c8d0bf (main, with 328b #314 merged)
Code commit: 291f68cbe60d920adbacaf89ca3060fec2802916

```
[harness] PASS: 34/34 checks @ 291f68cbe60d920adbacaf89ca3060fec2802916 (clean tree) scope=all
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
   2 the eight landforms, 3 falloffs, 4 the scarp, the ramps AND the bench, 5 the road fade,
   6 the limiter, 7 outside the footprint, 8 tile alignment, 9 the voxel ceiling, 10 `columnsFor`,
   11 `epochInput`, 12 no terrain written. **Seven deviations** are listed under **Deviations** and
   each says why; case 9's SPLIT half is declared 328d's, not claimed.
8. **Nothing in this change writes terrain.** *Verify:* `grid_relief.spec`'s *"drives all eight
   landforms and changes not one voxel of the place"* drives 121 points a cell through `heightAt`
   and `materialAt` and asserts `Terrain:CountCells()` and a `ReadVoxels` of a whole 128-stud tile
   are identical before and after. This is a BEHAVIOURAL proof and it is the one that carries
   design 1.2 item **1** -- see **Deviations** 3 for why the source scan cannot be it.
9. **The road stays flat.** `roadFadeAt` is exactly 0 at every centreline and at 51 studs from it,
   and exactly 1 at 120 studs wherever no crossing road is nearer -- asserted over all eight roads
   at 11 points each, both sides (the spec counts the full-fade assertions and requires > 100).
10. **Every bench is a plane at its own weight times its own grade** (round 2, finding 2).
    *Verify:* `grid_relief.spec`'s *"makes every bench a PLANE at its own weight times its own
    grade"*, on a column at u .64 that is clear of A1's gully and all three of B2's ramps. The gate
    run prints all three: `A1 ... 0.0160 st/st against 0.0160`, `B2 ... 0.0180 against 0.0180`,
    `D2 ... 0.0280 against 0.0280` -- each the recipe's `weight * gradePercent / 100` exactly, with
    one gradient to 1e-9 across the span.
11. **The voxel-ceiling case reads shipped producers only** (round 2, finding 1). *Verify:*
    `grid_relief.spec`'s *"emits tiles the MEASURED voxel ceiling can carry"* takes its tiles from
    `Relief.tiles` and its 32 columns, 24 layers and 24,576 ceiling from `MapGen.Config`
    (`TILE_STUDS`, `VOXEL`, `BAND_Y`), whose header carries the 2026-09-26 measurement. Delete
    `Relief.tiles` and the case fails.
12. **The limiter meets its ceiling.** A 63.4-degree synthetic cliff comes out at exactly 20.00 and
    32.00 degrees, and every cell's own column -- over a flat base and over a base built from that
    cell's measured `Grid.CELLS[*].relief` row -- is at or under its ceiling clear of the pins.
    A pinned band is returned byte-identical.

## Measured (the gate run at 291f68cb unless a row says otherwise)

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

Every bench's realised plane, gate run: `A1 v 0.55-0.74 rises 3.008 studs over 188, 0.0160 st/st
against 0.0160` -- `B2 v 0.00-0.22 rises 3.096 over 172, 0.0180 against 0.0180` -- `D2 v 0.50-0.74
rises 7.280 over 260, 0.0280 against 0.0280`.

Limiter, gate run: `63.4 deg cliff -> 20.00 after 8 passes ... ceiling 20` and `-> 32.00 ...
ceiling 32`. Tiles, gate run: `the bake's region is 1333 tiles of 128 studs`.

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
   (A literal repo-wide scan would also fail today for a legitimate reason: `src/server/Lobby/Field`,
   `src/server/Places/Ground` and `src/server/Range/Build` write terrain for the LOBBY, the four line
   places and the range, none of which §1.2 item 1 touches. They are the spec's allow-list, and the
   match is on the CALL shape `:FillBlock(` so a comment mentioning one is not an offender.)
4. **Design 13.1 case 3's "0.001 of weight a stud at the support boundary"** is met by every falloff
   whose support is >= 100 studs and asserted there. A ramp's 16-stud side blend cannot reach it
   (0.0112 at its last non-zero stud), so what is asserted for the short blends is the thing the
   figure is FOR: under 0.25 studs of HEIGHT a stud, which is one voxel over four studs.
5. **Two numbers the measurement moved, both in the code with the reading beside them:**
   a bench's v-edges now blend INSIDE its band (blending 40 studs past `v1` put 5.5 studs of plateau
   on B2's scarp and read the 28-stud face as 33.5); and `limitPass` finishes with an exact
   forward-then-backward min-cone clamp, because 8 relaxation passes alone leave a 63.4-degree cliff
   at 22.92 against a ceiling of 20.
6. **`deltaAt` and `Landform` differ from design 4's sketch.** `deltaAt` takes `baseAt` and `h0`
   as well, because a bench's plane is anchored on the ground it meets and that needs the reader;
   and `Landform` gains a `floor` row, which `materialAt` needs and the sketch has none for.
7. **Design 13.1 case 9's SPLIT rule is 328d's, not asserted here.** The Y-band pad is
   `TerrainBake.BAND_PAD`, which does not exist yet; this task asserts only the ceiling and the
   stride, from shipped numbers. Round 1 finding 1 was exactly this and it is now declared.
8. **Design 15 item 4's "~75 st" worst corridor-to-ramp distance is 96 st** (`TASKS.md` 328a-notes
   (d)). Not used here -- the three ramps ship as the design rules -- recorded because this task
   re-derived it.

## Round 2 -- what the two findings changed

- **Finding 1** (the voxel case asserted literals it defined itself): rewritten to read
  `Relief.tiles` and `MapGen.Config`; the split half is declared, not claimed (Deviation 7).
- **Finding 2** (the bench's recipe asserted nowhere): a new case, claim 10 above.
- Five of the notes touched SHIPPED files and are fixed with them rather than queued, because each
  was a factual error in the tree: **B1 and A2 carried an invented mud depth** and SWARM 2.2 states
  none for either (A1's and D1's stay, each with its recipe line quoted beside it, and the four
  cells SWARM gives no floor now say so); the source scan matches the **call shape** and carries
  `Range.Build`; the scan's note now says plainly that it **proved nothing** on a run where `Source`
  is unreadable; the golden's header no longer names an instrument the repo does not hold; and the
  `epochInput` case now builds a **differently ordered** config, which is what `table.sort` is for.
  The limiter case's name and comment now say the finishing clamp is what lands it on the ceiling.
- The remaining notes are queued in `TASKS.md` under 328c-notes, not fixed here: the separable blur
  (328d pays for it), `columnsFor`'s inward shift on an off-centre band (328e paints it), the axes
  `limitPass` runs on (328d), and B2's bench weight 0.9.

## A harness fault worth reporting (rule 6)

The gate at this commit took **four runs**. Run 1 failed `deer_hitbox.spec:682`, run 2
`deer_hitbox.spec:659` -- both on the dispatch's KNOWN-INTERMITTENT list, and both passed on the
runs either side. Run 3 failed at the harness level, not in a spec:
`[input] replayed every step of 6 scenario(s) (shoot-the-boar: RuntimeError: user_mouse_input:
Network action UserMouseInputTool.SendUserInput sent to DMN_ID_PLAYCLIENT failed - Target is not
reachable ...)`, with every spec passing in that same run. Run 4 is the PASS pasted at the top.
The first gate of this task, at 52b4667e, passed 34/34 first time. Nothing in this change touches
the deer, the boar or the input replay.

## Not verified

- **No bake, no Studio terrain change, no change to Karen's place.** `Relief` is required by nothing
  live until 328d. There is no Forest Test proof and none was asked for.
- The **hillshade pictures** are rendered from `Relief.heightAt`'s own output at a 25-stud pitch
  (`<runs-dir>/328c-relief-<cell>.png`). The heights were produced by a spec driving the real module
  in a harness Play run, not by a standalone Luau interpreter: the repo pins none, and the MCP thread
  may not `require`. No terrain was read or written to make them.
- `materialAt` has one case (its three stated floor rules). It has no caller until 328d/328e.
- The budgets of design 12.2 stay UNMEASURED; nothing here cites one.
