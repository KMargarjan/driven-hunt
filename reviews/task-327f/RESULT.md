PASS (item 4 NOT PROVEN)

Round 1's finding is closed, checked against the repo and not against the request: claim 6 now reads
`1 MAIN FREE` … `7 MAIN FREE`, `8 WEST TOWER`, `9 WEST FREE`, `10 WEST TOWER`, `11 WEST FREE`, and
`Grid.sideOf` answers `"main"` for `standIndex <= c.mainStandCount` (7), `"west"` through 11, with
`Grid.CELLS` C1 `towers = table.freeze({ 8, 10, 13 })` — so every quoted row is a string
`MapUi.standRowText` can write for C1, and no quoted row is one it cannot. Harness line names the
`Code commit:` 7aa55e5c with "(clean tree)"; `paperwork-after-code-commit.txt` says OK (only
`reviews/task-327f/REQUEST.md` and `RESULT.md` followed it). No blocking finding in the code: the
blast radius holds, `Objective.targetFor` reads only `geometry.road` / `geometry.stands` (both
`base`'s, value for value by case 30) and never `bounds`, which is the one field the cell path
changes; `case 28` still asserts `child.Size.X.Offset == CONFIG.STAND_HIT_PX` for the four line
places, so `standHitPx`'s clamp leaves the pre-327 pads at 72 and the harness proves it.

Rule 5, stated so this PASS is not read as rule 5 having been met: this task has **no core item** —
it touches no `Boar/`, `Weapon/`, `Shotgun/`, `Ballistics/` or `Effects` path, so nothing here is
animal behaviour or shooting. What Karen judges is a picture, and I cannot see one: F1–F3 are
described in words only. Items 1–3, 5, 9, 10 are carried by the repo and the harness; items 6–8 are
consistent with the code (footer strings `PICK_PROMPT = "click a stand"` and
`PICK_HELD = "stand %d is yours"`, `label = string.format("section %s", cellId)`, 8 `CELL_ORDER`
cells, 15 = `mainStandCount + 2 * flankStandCount`). **Item 4 is named NOT PROVEN** for the one part
of it nothing in this change can support: claim 4 says *"every row calls the same `MapUi.tapStand`"*
and offers case 32, which never touches a row — it calls `MapUi.tapStand(13)` directly under the
comment *"A ROW ASKS THE SAME DOOR THE PAD DOES"*. Delete `row.Activated:Connect(function()
MapUi.tapStand(at) end)` from `buildStandList` and case 32 passes line for line, including its
`TestKit.note`. The spec cannot close it (this file's own 323b header: *"the GESTURE is
`GuiButton.Activated`, which the harness cannot synthesise"*), and the remedy that file names — *"the
real click is in the task's report, with a frame"* — was taken for the pads (claim 7) and not for a
row: F4 is NOT OBTAINABLE and claim 7's click was on stand 4's pad on the map. A list row has
therefore never been tapped by anybody, in a spec or in her place.

## Notes (non-blocking)
- `buildStandList` / the row tap — one real left click on a list ROW, in her place, closes item 4.
  It was obtainable this session on desktop and not on a phone: case 32 asserts `frame.AnchorPoint.X
  == 0` and `frame.Position.X.Offset >= canvas.Position.X.Offset + canvas.Size.X.Offset` at
  1920 × 1080, and F1 is described as *"the list beside the map"* at her own viewport.
- `grid-map.md` §13.3 / §17's 327f row — `scopeFor` exists in no file but the design doc (grepped:
  one match, `docs/design/grid-map.md`), and with it the two views §10.4 specifies ("**world** (the
  vote)" / "**cell** (the pick)"), the cell `Hit` pads, the vote tally and the my-vote mark. Deferring
  the vote half with 327e is right — nothing publishes it — but the consequence is shipped: the pick
  happens on the WORLD view, so `standHitPx` measures a 26 px pad where §10.4's cell view would give
  "stands **109 px** apart". At 400 × 800 that pad is ~8 real px, so on a phone the LIST is the only
  pick path — which is exactly what item 4 leaves unproven. Queue `scopeFor` with 327e.
- `buildStandList` / `CONFIG.STAND_LIST_ROW_PX` — still open from round 1. The tappable height is
  `UDim2.new(1, -STAND_LIST_SCROLL_PX, 0, config.STAND_LIST_ROW_PX - 2)` = **42** real px (the pitch
  is 44), against `grid-map.md` §10.4's *"fifteen rows at 44 px"* and `mobile-controls.md` §B's 44 px
  minimum. The request discloses the 42. Fix: `ROW_PX = 46` with the same 2 px of air, or a
  `UIListLayout` gap.
- `MapUi.fullMapRect` — still open. `layoutFor` now subtracts `reserve` from `roomX` and shifts by
  `-(column + reserve) / 2`; `fullMapRect` does neither, though its header promises *"the same three
  lines `layoutFor` performs"*. No `src/` caller (grepped: only `hud_clarity.spec` and
  `touch_controls.spec`), so nothing is drawn wrong today — but those two audits cannot see the panel
  the player gets for the 15 s of a pick, and they cannot see the `StandList`'s rectangle at all.
- `MapUi.cellStateFor` / `drawGeometry` — still open. `"driven"` reaches no property: `edge.Color`,
  `edge.Thickness`, `edge.Transparency`, the label text and its colour all fall to the `"free"` arm.
  Dead until 327e publishes a driven set, and then the map will not change. Queue the driven mark
  with 327e.
- `map_ui.spec` case 33 — still open. `local before = MapUi.stats().rebuilds` is read before the C1
  `setGeometry`, which itself increments `stats.rebuilds`, so `expect(MapUi.stats().rebuilds >
  before).to.equal(true)` cannot fail. The case's claim is carried by `brass("C2") == true` /
  `brass("C1") == false`, which do die if the redraw stops, so the case is not empty — the line is.
  Re-read `before` just above the C2 call.
- `map_ui.spec` case 32 — still open, two lines. The *"beside the map"* block runs after
  `MapUi.setPickWindow(false, false)` / `MapUi.setOpen(false)`, so `listShown` is false, `reserve` is
  0 and the list is `Visible = false` when its position is asserted; and `expect(rowPx >=
  CONFIG.STAND_LIST_ROW_PX - 2)` cannot fail once `panelScale.Scale * listScale.Scale` is asserted
  `near(1)` — `rowPx` is `(ROW_PX - 2) * 1` by construction. The product itself is a real assertion
  (delete `listScale.Scale = 1 / shown` and it reads `shown`).
- `map_ui.spec` case 30 — still open. The DEV arm is inside `if dev ~= nil then`, and in the Forest
  Test `Map.EXPECTED_WORLD` is `"forest-test"` with `forestTest` nil, so `geometryFor` returns nil
  and `expect((dev :: any).cells).to.equal(nil)` never runs. Say it is skipped, or drive it with a
  `Map` stub.
- `map_ui.spec` — there are now TWO `it("case 30: ...")` in one file (the 323b block's *"the window
  opens the map by itself"* and this task's *"a CELL drive draws the world"*), so claim 2's *"Verify:
  case 30"* names two cases. Renumber the new block.
- citations — `map-ui.md` §21 is *"The grid's roads are curves (task 328o, pasted by 328q)"*
  (verified). The *"absent is pre-327 behaviour"* text that `MapGeometry`'s comment, `geometryFor`'s
  comment and claim 2 all cite as §21 is the PLANNED amendment quoted inside `grid-map.md`, and it
  has not been pasted into `map-ui.md`. That amendment also names `geometryFromGrid(grid, cellId,
  cells)` and `pushBearingDeg`; shipped is `(grid, cellId, driven, base)`.
- `drawGeometry`, the roads comment — *"the 128 extra segments"*. `Grid.roads()` is `rows + 1` = 3 EW
  plus `columns + 1` = 5 NS = 8 roads, and `GRID_ROAD_SAMPLES = 9` is 8 segments each: **64**.
- claim 3 — "26 px" implies a closest pair of ~28 px, while `CONFIG.STAND_HIT_MIN_PX`'s comment and
  `standHitPx`'s header both say the world view draws the main line *"~31 px apart"*. One of the two
  numbers is stale; the case's own `TestKit.note` prints the measured one.
- claim 9 — 15.0 Hz passes because the tick case allows `near(CONFIG.TICK_HZ, CONFIG.TICK_HZ * 0.4)`.
  The request gives 11.2 / 9.4 at 221c444c and 15.0 at the code commit, never the rate at base
  b0d0a149, so "fixed" means "back inside tolerance", not "no cost".
- `layoutFor` — *"On a phone there is no outside, and then it sits over a map"* describes the
  pre-reserve state: with `reserve` shrinking the panel, a 400 × 800 phone takes the BESIDE branch
  and the `else` arm is reached only near 300 px. Also unsaid: the panel moves and rescales on the
  pick window's open edge (`applyPick` → `layoutFor`), so the pads she is about to click shift once
  when the window opens.

---
REVIEWER verdict on commit `1922b2aef043a16a2541738ed486b8fa530070ff` (round 2) · 2026-11-09 21:00 UTC · session cost $4.26, 46 turns · written by tools/agents.py
