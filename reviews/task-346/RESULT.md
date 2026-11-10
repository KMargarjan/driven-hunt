PASS

Rule 5, stated so this PASS is not read as rule 5 having been met: no item of task 346 is **core** in
duty (b)'s sense -- no animal behaviour, no shooting, no shot path. What Karen will judge is the view
behind the roads, and it has been seen only in the Builder's three described before/after pairs
(`346-F{1,2,3}-pair.png`), which I cannot open. Their cameras do check out against the grid's own
arithmetic, to the stud: F3 at z -3614 = `originZ -6600 + 2*1430 + 3*42` = `Grid.footprint().maxZ`
exactly, with x -4452 three studs off the NS3 road centre (-6700 + 2*1112 + 21 = -4455), i.e. standing
on a road looking out of the grid -- "the north road end"; F2 at (-3343, -3635) is the NS4 centre
(-6700 + 3*1112 + 21) by the border road's centre (maxZ - 21), i.e. C1's NE junction. The geometry also
supports *"BEFORE: an empty green hillside"*: at the base every band rect's cross span was the cell's
own (or the neighbour's) inset ground and `scatter`'s `inRect` refuses a jittered site that leaves its
rect, so no site could stand in a corner quadrant. **Karen has not seen it.**

Round 1's finding 1 is fixed, and the fix has teeth, verified by reading the deletion:
`deepest = band.near >= plan.skirtStuds` is true of band 3 only (band 2's `near` is
`plan.skirtFullStuds` 80 against `skirtStuds` 230), so deleting the third band from `skirtBands`
empties `deepRects` and `expect(#deepRects).to.equal(4)` and `expect(inDeepest > 0)` both redden --
matching the run in MEASUREMENTS 5a (4 -> 0, C1 371 -> 0, A2 451 -> 0). `SKIRT_WIDEN_STUDS` -> 0
confines every band to the cell's own inset cross span, so no site is past `box` + half on BOTH axes
and `error("corner quadrant %s holds no tree")` fires. `SKIRT_DEEPEST_STUDS` -> 250 reddens the new
floor. The vacuous `beyondSkirt` assertion is gone; it is now the note line's figure only, and says so.

## Notes (non-blocking)
- **The one hard number against this change is the frame time, and it is not settled.** p95 at the C1
  stand 20.22 -> 25.73 ms against a +2 ms budget, with the same-build spread measured at 1.05/2.77 ms
  and A2 moving -2.26. The request records it as NOT PROVEN and a Director call, which is the honest
  reading, so it is not a blocking finding here -- but merging is the Director accepting an unresolved
  +5.51 ms at the one station Karen stands at. A second C1 sample a side costs one run and would settle
  it; the lever named in `grid-terrain.md` 12.2 terms is `plan.deepSpacingStuds` on the new band.
- `src/shared/Places/init.luau` / `Places.skirtZoneAt` -- the new clamp on the FIRST branch is dead
  today and the stated reason for it is wrong. `widen` is `if other == nil then SKIRT_WIDEN_STUDS else
  0`, so a widened band only ever asks `skirtZoneAt(cellId, nil, ...)`, which takes the SECOND branch
  -- and that branch clamped before this change too (`local g = Places.cellGround(cellId)` at the
  base). On an interior side the rect is clipped to `theirs.minX/maxX` and spans `theirs.minZ/maxZ`,
  so the clamp there is a no-op for every site `scatter` can offer. The edit is harmless; REQUEST's
  *"unclamped, the widened ground reads nil and plants nothing"* and the function's own new comment are
  about a branch the widening never reaches.
- `tests/server/grid.spec.luau` / case 16a -- `expect(Plan.SKIRT_WIDEN_STUDS).to.equal(
  Grid.CONFIG.roadClearStuds + Plan.SKIRT_DEEPEST_STUDS)` is the definition retyped
  (`Places.SKIRT_WIDEN_STUDS = Grid.CONFIG.roadClearStuds + Places.SKIRT_DEEPEST_STUDS`), i.e. the same
  expression compared with itself. It can fail only if someone replaces the derivation with a literal,
  which is a worthwhile freeze -- but it is not evidence about any geometry, and the comment above it
  ("THE TWO NUMBERS ARE ONE FACT WITH THE ROAD") reads as if it were.
- `tests/server/grid.spec.luau` / case 16a -- `inDeepest > 0` is a floor of ONE site against a measured
  348-451 a cell, and a site one stud past `skirtStuds` satisfies it; the planted depth is pinned only
  by the constant floor plus the band rect's construction. `deepest` (the max `out`) is computed and
  printed and never asserted. `expect(deepest >= Plan.SKIRT_DEEPEST_STUDS - plan.deepSpacingStuds -
  Grid.maxBendStuds())` would pin from below what the live run already shows (worst 479 outside the
  footprint) and would catch a band that exists, is planted at its kerb, and is refused by the mask
  further out.
- `tests/server/grid.spec.luau` / case 16a -- `quads`, `out` and `deepest` still compare a WORLD
  `item.x`/`item.z` with the GRID rects `box` and `fp`; only `inDeepest` was converted with
  `Grid.toGrid`. For `outside <= Relief.BLEND_STUDS + 230 + Grid.maxBendStuds()` that is the right
  comparison (`terrainbake.py`'s `region_for` grows the grid footprint by that pad and uses it as a
  world region, the bend term being exactly the mapping slop), and the quadrant keys carry up to
  `maxBendStuds` 60 of slop against a 462-stud widening, so nothing is wrong -- but two of the three
  figures in the note line are mixed-space and one sentence of comment, or one `toGrid` call, would
  stop the next reader re-finding round 1's trap.
- The measured worst site outside the footprint is **479** in MEASUREMENTS 4 and claim 4, **470** in
  `SKIRT_DEEPEST_STUDS`' own header and in TASKS.md 346a(d) ("20 studs to spare"). One of the two is
  wrong; the derived bound 490 holds either way, and the margin is 11 studs if 479 is the number.
- Nothing in `src/` couples `SKIRT_DEEPEST_STUDS` to the keep box. Case 16a's derived
  `BLEND_STUDS + 230 + maxBendStuds` is now the only guard between a deeper band (or a larger bend) and
  trees planted where task 340's trim left no terrain; `tools/terrainbake.py`'s `BORDER_WOOD_STUDS = 230`
  is a stale NAME for the same quantity. Queued as 346a(d), correctly.
- `TASKS.md` row 346 still names code commit **`c4ab2f99`** and that commit's harness line, which
  `dd0bc967` superseded by changing `src/` and `tests/`. REQUEST's `7f35ed1d` line is the current one and
  `paperwork-after-code-commit.txt` says OK for it; the merge gate reads the TASKS.md row, so that row
  should be moved to `7f35ed1d` before merge.
- `docs/design/grid-terrain.md` 8.4 (*"230 st deep"*) and 5.2 (*"footprint() expanded by
  Relief.BLEND_STUDS 200 plus the border wood's 230"*) are wrong by 190 studs: the wood now spends the
  blend's share of the same pad. Round 1's note, correctly queued as 346a(d) rather than edited.
- `tests/server/grid.spec.luau` / case 16 -- the reach bound is now `half + CELL_EDGE_STUDS +
  SKIRT_WIDEN_STUDS + plan.deepSpacingStuds` = 538 against a true worst near 493, and it adds a LATERAL
  reach to a bound compared against a depth on the other axis. Still bites, loosely; round 1's note,
  unchanged.
- Case 16a calls `Plan.plantCell(id)` for all eight cells a second time (the file already builds
  `woods[id]` the same way at the top), doubling the heaviest work in this spec for no new information.
- Checked and sound, for the record of what any follow-up must not break: `widen` is applied only on
  band 3 and only where `other == nil`, whose whole extent is 230+ studs beyond `Grid.footprint()`,
  where `clearOfEveryRoadGrid`/`roadDistanceGrid` find no road (both read `from`/`to`, which
  `Grid.roads` sets to the footprint) and no cell's ground reaches -- so claim 3 holds and case 16's new
  `inLane` guard is honest rather than a weakening; `grid_ground.spec`'s ride floor (`worstRide >=
  RIDE_TRUNK_FLOOR_STUDS`, asked of C1 for every planting of every cell) and its frontage case are real
  teeth and are green; the lobby and the line places are 2,100+ and 400+ studs clear of the deepened
  band, so `clearOfEveryLane` is not newly breached; the budgets are arithmetic (D2 3,650 x 3.76 =
  13,724 under 14,200 -> 126 models; D1 7,561 x 3.76 = 28,429 under 29,000 -> 151 sites; `CELL_PLAN_CAP`
  7,712 and `CELL_PART_CAP` 3,776 are `math.floor` of the two budgets and match the spec's frozen pair),
  and no second typed copy of 12,800/27,000 exists in `src/`; selene, stylua and `rojo build` are clean;
  `[harness2]` N/A is right (no `TWO_PLAYER_PATHS` path); no secret, local path or non-noreply email in
  the diff.

---
REVIEWER verdict on commit `58ec91521d8778e8db6dfae6aaf48155c9d51ab0` (round 2) · 2026-11-10 19:33 UTC · session cost $3.23, 36 turns · written by tools/agents.py
