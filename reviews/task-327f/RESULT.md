1. `reviews/task-327f/REQUEST.md` claim 6 / `src/shared/Grid/init.luau` `Grid.CELLS` C1 — the live row
   transcription names a row the code cannot produce for the cell the same claim names, so the one
   piece of rule-5 evidence that the list's WORDS are right in Karen's place is inconsistent with the
   repository. Evidence: claim 6 says `title="section C1"` and *"rows reading `1 MAIN FREE … 7 MAIN
   TOWER … 15 EAST FREE`"*. C1's entry is `towers = table.freeze({ 8, 10, 13 }), -- 8 west +120/0.00/
   0.01; 10 west +216/0.00/0.10; 13 east +234/0.00/0.03`, and `Grid.sideOf` answers `"main"` only for
   `standIndex <= c.mainStandCount` (7) — so for C1 **no row can read `MAIN TOWER` at all**: the tower
   rows are 8 WEST, 10 WEST, 13 EAST, and stand 7 is a free main ground stand. `MapUi.standRowText`
   says `TOWER` only on `word == "high"` or `kind == "tower"`; `geometryFromGrid` sets
   `kinds[index] = if towers[index] then "tower" else "ground"` from `grid.towerStands(cellId)`, and
   `standStateFor` returns `"high"` only from `view.seated`, which is `HighSeats.STANDS` — the same
   `{8, 10, 13}`. Required: replace the quoted rows with what was actually on the frame (`7 MAIN FREE`,
   and `8 WEST TOWER` for the tower example), or — if row 7 really did read TOWER in her place — say so
   and find the defect, because nothing in the shipped code can write that string for C1.

## Notes (non-blocking)
- `MapUi.fullMapRect` — its header promises *"the same three lines `layoutFor` performs, so a change to
  one shows up in the other's spec"*, and that is now false: `layoutFor` subtracts `reserve` from
  `roomX` and shifts by `-(column + reserve)/2`, `fullMapRect` does neither. For the 15 s the list is up
  it answers a rectangle the panel does not occupy, and it is what `hud_clarity.spec` and
  `touch_controls.spec` audit the band against. Fix: give it the same optional reserve, or amend the
  header to say it answers the no-list rectangle only.
- `buildStandList` / `CONFIG.STAND_LIST_ROW_PX` — the row's tappable height is
  `UDim2.new(1, -STAND_LIST_SCROLL_PX, 0, config.STAND_LIST_ROW_PX - 2)` = **42** real px, but
  `layoutFor`'s comment states *"a row is 44 REAL pixels at every viewport"* and `grid-map.md` §10.4
  specifies *"fifteen rows at 44 px"* against `mobile-controls.md` §B's 44 px minimum. The request
  discloses the 42. Fix: full `ROW_PX` with a `UIListLayout` gap, or `ROW_PX = 46`.
- `drawGeometry`, the roads comment — *"the 128 extra segments"*. `Grid.roads()` is 3 EW + 5 NS = 8 and
  `GRID_ROAD_SAMPLES = 9` is 8 segments each: 64 on the panel.
- `MapUi.cellStateFor` / `drawGeometry` — `"driven"` is drawn **identically to `"free"`**: `edge.Color`
  falls to `CELL_EDGE_COLOR`, `edge.Transparency` to `CELL_EDGE_TRANSPARENCY`, the label stays `cell.id`
  at `TEXT_COLOR`/`PINNED_TRANSPARENCY`. The design amendment this change cites says *"a driven cell is
  `PINNED_TRANSPARENCY`"*. Invisible today (no publisher), but when 327e publishes the driven set the
  map will not change. Queue the driven cell's own mark with 327e.
- `map_ui.spec` case 33 — `local before = MapUi.stats().rebuilds` is read **before** the C1
  `setGeometry`, which itself tears down and increments `stats.rebuilds`, so
  `expect(MapUi.stats().rebuilds > before).to.equal(true)` after the C2 call cannot fail. The claim is
  carried entirely by `brass("C2") == true` / `brass("C1") == false`. Re-read `before` just above the C2
  call.
- `sameGeometry` — the added `a.activeCell ~= b.activeCell or #(a.cells or {}) ~= ... or #(a.roads or {})
  ~= ...` line is unreachable in practice: `bounds` is the grid-footprint union and so is equal across
  cells, while `stands` already differ cell by cell and the existing element-wise loop catches it. No
  case dies if the line is removed; it is a cheap early-out, not a behaviour change.
- `map_ui.spec` case 32 — the *"beside the map, never over it"* block runs **after**
  `MapUi.setPickWindow(false, false)` and `MapUi.setOpen(false)`, so `listShown` is false, `reserve` is
  0 and the list is `Visible = false`. The branch is the same one the player gets (the reserve only
  raises `roomRight`), but the assertion is taken in a state the player never sees. Move it above the
  two closes.
- `map_ui.spec` case 32 — `expect(rowPx >= CONFIG.STAND_LIST_ROW_PX - 2).to.equal(true)` cannot fail
  once `panelScale.Scale * listScale.Scale` has been asserted `near(1)`: `rowPx` is
  `(ROW_PX - 2) * 1` by construction.
- `map_ui.spec` case 30 — the DEV arm is wrapped in `if dev ~= nil then`, and in the Forest Test
  `Map.EXPECTED_WORLD` is `"forest-test"` with `forestTest` nil, so `geometryFor` returns nil and that
  assertion never executes. State it as skipped or drive it with a `Map` stub.
- citations — `map-ui.md` §21 is *"The grid's roads are curves (task 328o)"*; the *"Absent is pre-327
  behaviour"* text the code and claim 2 cite is the planned map-ui amendment quoted inside
  `grid-map.md`. That same amendment names `geometryFromGrid(grid, cellId, cells)` and dispatch on
  `world == "grid:v1"`; shipped is `(grid, cellId, driven, base)` dispatching on
  `grid.cellOf(layoutName)` inside the `"forest-test"` branch, and the cell `Hit` child,
  `pushBearingDeg`, the vote arrow and `setCellStates` are absent (327e's, correctly).
- claim 3 — "26 px" implies a closest pair of ~28 px, while `CONFIG.STAND_HIT_MIN_PX`'s comment and
  `standHitPx`'s header both say the world view draws the main line *"~31 px apart"*.
- claim 9 — 15.0 Hz passes because the tick case allows `near(CONFIG.TICK_HZ, CONFIG.TICK_HZ * 0.4)`
  (12–28 Hz). The request gives 11.2/9.4 at 221c444c and 15.0 at the code commit but never the rate at
  base b0d0a149, so "fixed" means "back inside tolerance", not "no cost".
- `layoutFor` — *"On a phone there is no outside, and then it sits over a map"*: with `reserve` now
  shrinking the panel, a 400 × 800 phone takes the BESIDE branch (`roomRight` ≈ 152 ≥ 140). The `else`
  branch is reached only at viewports near 300 px. The comment describes the pre-reserve state.

Rule 5, stated so this review is not read as rule 5 having been met: this task has **no core item** —
it touches no `Boar/`, `Weapon/`, `Shotgun/`, `Ballistics/` or `Effects` path, so nothing here is animal
behaviour or shooting. What Karen will judge is a picture, and I cannot see it: frames F1–F3 are
described in words only, F4 (the phone) is named NOT OBTAINABLE, and the one live sentence I could
check against the repo — claim 6's row list — is the blocking finding above.

---
REVIEWER verdict on commit `a9ec752e3e19dafb124043376c1d48159398c4db` (round 1) · 2026-11-09 20:39 UTC · session cost $4.81, 46 turns · written by tools/agents.py
