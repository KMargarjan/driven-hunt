# Task 328d -- BAKE C1: the bake, its tool, and the two hard stops that kept it out of her place

Task: 328d
Round: 1
Base: main (`6b520717`)
Code commit: `f64106dd89cd1809f5aaee69595e233e978ecfaa`

```
[harness] PASS: 34/34 checks @ f64106dd89cd1809f5aaee69595e233e978ecfaa (clean tree) scope=all
```

`test2` N/A: no path in `TWO_PLAYER_PATHS` is touched.

## What changed

`src/serverstorage/TerrainBake/init.luau` (new), `tools/terrainbake.py` (new) with its selftest as
a CI step, two `BLAST_RADIUS` rows, thirteen cases in `tests/server/grid_relief.spec.luau`, a
`.gitignore` line, the `TASKS.md` row, and `ESCALATE.md`.

**THE BAKE DID NOT RUN AND NO `WriteVoxels` TOUCHED KAREN'S PLACE.** Three measured facts say why
(claim 1). Everything that could be measured read-only was, and everything that could not is named
`NOT OBTAINABLE` in claim 10.

## PLAN (core protocol step 0), as it actually resolved

- **(a) REAL LIFE / the design:** a forest road is level across and graded along -- 8 % E-W, 10 %
  N-S, crossfall under 0.5 st over 44, a 2-st ditch in two whole voxel columns at nominal d 22-30
  (`docs/design/grid-terrain.md` 7.1, 15 item 2).
- **(b) MEASURED NOW,** `<runs-dir>/328d-base.luau` in her place in Edit: C1's base spans 61.73 st
  (min 89.16, max 150.89, mean 113.20, 3,888 rays); the four road centrelines fall 21.99 / 52.25 /
  63.61 / 28.99 st with worst 20-st steps of **9.2 / 18.4 / 26.5 / 13.7 %** -- every one over its
  clamp; and `Grid.standPosition`'s fixed Y 106.98 is up to **24.33 st** off the ground, **stand 10
  buried 24.33 st** today.
- **(c) TARGET:** the grades above, and the ditch at 2 st +-1.0 or the 4-st fallback (15 item 2).
- **(d) LEVER:** `TerrainBake.bakeTile` -> `Terrain:WriteVoxels`, `src/serverstorage/TerrainBake/init.luau`.
- **(e) HOW MEASURED AFTER:** the same probe, the same three cameras.

**(b) CONTRADICTS THE DISPATCH AND THE RUN STOPPED THERE** (step 0's own rule), at 13:56 UTC, before
any workaround was designed (V280). `ESCALATE.md` carries it.

## Claims

1. **Three hard stops, each with a control.** `ESCALATE.md`, 2026-11-02 ~13:56 UTC.
   Verify: (i) `Desktop\driven-hunt-backups\` is empty, so the Director's own gate is unmet;
   (ii) Team Create reads **ON** -- `FindService("NetworkClient")` answers `NetworkClient` and
   `Players:GetPlayers()` holds 1 (the owner, uid = `game.CreatorId`) where **DEV answers `nil` and
   0**, same Studio, same probe (`<runs-dir>/328d-tc.luau`); (iii) in her Edit session **297 of 297**
   script instances read `Source` length **0** and `require` fails on every one, where DEV reads
   27,750 and requires fine (`328d-src.luau`, `328d-req2.luau`) -- which takes out BOTH halves of
   design 3's ruling, the clone load and `check_synced`. **It is Edit-only:** the same place's PLAY
   server requires `Grid` fine and reads `#Grid.Source` = 27,750 (`328d-playprobe.luau`).
2. **The tool REQUIRES and injects nothing** (design 3). `tools/terrainbake.py`, `CALL_TEMPLATE`.
   Verify: the template holds `require(ServerStorage:WaitForChild("TerrainBake"))` and no module
   source; selftest case *"the sent Luau REQUIRES and injects nothing"*. Every MCP helper is
   imported from `studio_mcp`, none copied (the `from studio_mcp import` block).
3. **Seven refusals, each cased against the state it is about.** `check_place`, `check_synced`,
   `check_clean_tree`, `check_backup`, `check_overrides` in `tools/terrainbake.py`.
   Verify: `python tools/terrainbake.py selftest` -> `[bake] selftest: PASS`, 36 cases, now a CI
   step in `.github/workflows/ci.yml`. The Forest Test is resolved **by place id** through
   `studio_for_place` (L-055) and `check_place` is re-run **inside** the tile loop before every
   mutating call (`tile_pass`), not once per run. `--backup census` is refused with its reason.
   Refusal 7 **leaves `GRID_PREVIEW` and `RANGE_SOLO` alone** and tells the operator `set <NAME>
   off`, never `clear` (lesson K) -- both directions cased.
4. **`plan` ASSERTS the tile count** (Director decision 6, overriding design 6.4's "no scope"), and
   the number is derived **three independent ways**: `python tools/terrainbake.py plan --cells C1`
   -> *"ASSERTED: 208 tiles, re-derived from Grid.CONFIG on disk"* (Python, off the Luau files);
   `Relief.tiles` itself in Studio (`<runs-dir>/328d-arith.luau` -> `208` / `1333`); and spec case
   **328d-3** -> note `bake tiles: C1 208, the whole world 1333`. All three agree, and
   `TerrainBake.regionFor` is design 5.2's rule, not a typed number.
5. **Two `BLAST_RADIUS` rows, both `map`** (Director decision 6): `src/serverstorage/TerrainBake/`
   and `tools/terrainbake.py`, in `tools/studio_mcp.py`. Verify: `python tools/studio_mcp.py
   selftest` passes, and this branch resolves to `scope=all` (`tools/studio_mcp.py` is in
   `FAIL_SAFE_PATHS`), which is what the gate line says.
6. **The 328c note about the cell-edge fade is DECIDED in code, not carried.**
   `TerrainBake.blendAt` / `unionOf`, called by `bakeTile`: the per-cell delta is taken from
   `Relief.heightAt` and re-weighted by ONE blend from the baked union. Case **328d-5**, whose note
   reads `blend on the C1/C2 road: union of both 1.000, C1 alone 0.969` -- the two-cell case is what
   shows the difference, and the case says so.
7. **The 328c note about the limiter's axis is DECIDED in code.** `TerrainBake.limitGrid` runs
   `Relief.limitPass` along z and then along x. Case **328d-6** is FAIL FIRST: its note reads
   `limiter: ceiling 5.82 st per 16; z-only leaves 16.00 in x, both axes leave 5.82`. Delete the
   x pass and the case fails at 16.00.
8. **The voxel ceiling is arrived at, not retyped, and the Y band splits.** `TerrainBake.bandsFor`
   and `MAX_VOXELS`; case **328d-4** asserts one call for an 88-st band, more than one for a 300-st
   band, that no call exceeds the ceiling, and that the bands **abut** so no slice is left unwritten.
   The selftest derives *"the ceiling allows 96 studs of Y band per call"* from 1,024 columns.
9. **`snapshot` refuses rather than guesses**, and the bake refuses what one tile cannot hold.
   `TerrainBake.snapshot` returns `(nil, why)` on Water, on an overhang (more than one solid run in
   a column) and on an empty column; `TerrainBake.bakeTileAt` refuses a cell whose landform holds a
   `bench`, because `Relief.applyOps` reads the base across the whole cell. Case **328d-8**, note
   `bake: benched cells A1,B2,D2; tile-local B1,C1,D1,A2,C2` -- **C1 is tile-local**, so the task's
   own cell is bakeable by this route. `TerrainBake.archive` re-parents and never destroys (B3).
10. **What is NOT proven, said plainly.** NOT OBTAINABLE without a bake, and none of it is claimed:
    the per-tile cost in seconds (design's 8 s target stays UNMEASURED), the achieved ditch depth
    against +-1.0 st, the road crown and cross-fall, the landform census against `Relief.heightAt`,
    pad and stand heights after, and the post-bake tree census. The three "before" frames were taken
    and looked at (`<runs-dir>/328d-before-A|B|C.png`, eye height 5 st over the measured ground,
    cameras in `328d-cam.luau` for reuse): **A** from stand 4 shows a flat, featureless plain with
    **no ridge**; **B** standing on EW2's centreline shows **no road at all** -- no carriageway,
    ruts, ditch or verge, and the ground falling away west; **C** at stand 10 shows the camera on a
    high shoulder in deep grass, which is the 24.33-st burial in a picture. The BEFORE tree census
    was read in her Play server (`328d-census-before.luau`): `Workspace.Session` trees=769
    floating=195 sunk=464 broken=250 worstHigh=65.23; `OurForest` trees=4819 floating=836 sunk=1673
    broken=1277 -- **reported SUSPECT as a certified figure** (rule E): `GridCensus.survey` was
    handed a stubbed `clawOf` returning 0 and does not filter its tree set by cell, and
    `Workspace.GridForest` does not exist yet (328i). It is a baseline reading, not a census.

## Could not be verified

- **Everything the bake would produce.** See claim 10. The blocked proof is an `ESCALATE.md` entry
  written at the stop, not worked around (V280).
- **The port switch to `:34874` and the switch back was NOT performed**, because without a bake there
  was nothing to sync. `driven-hunt-karen` was never checked out and its HEAD never moved (L-014).
  Her place stayed on `localhost:34873`, visible in the Rojo panel in all three frames.
- **Whether Team Create CAUSES the Edit-side source fault.** Both are true of her place and neither
  is true of DEV; the causal link is an inference and is labelled as one in `ESCALATE.md`.
- **`StreamingMinRadius` could not even be READ**, let alone set: it, `StreamingTargetRadius` and
  `StreamingIntegrityMode` all answer *"not a valid member of Workspace"* from this context, which
  `studio_mcp.map_streaming_radius` already records for one of them. It is a NEEDS KAREN click.

## The gate, honestly

Five harness runs, all clean-tree, all `scope=all`. Two were green, three failed on **one** spec
each, in files this branch does not touch: `deer_hitbox.spec:528` once, `weapon_shot.spec:1890`
once, `weapon_shot.spec:1490` once. The dispatch names `weapon_shot.spec:1490` as not ours.
**The run that matters is not an argument about flakiness:** run 2 was `PASS: 34/34 @ 190a4930`
(clean tree, scope=all), and `git diff --name-only 190a4930 f64106dd` is exactly `ESCALATE.md` and
`tools/terrainbake.py` -- neither of which any spec loads. Logs: `<runs-dir>/328d-gate1..5.txt`.
