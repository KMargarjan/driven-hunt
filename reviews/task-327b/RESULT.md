PASS (item 7, 9 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: Karen has NOT walked the cell —
the request says so itself (*"Rule 5 is MINE, not Karen's. She has not walked the cell"*), there is
still no aerial of the ring of 15, and the one frame is described, not shown to me. What the live
session does establish, and what the repo's own arithmetic confirms, is the DEAL: `Grid.boundsOf("C1")`
is x [-4434, -3364] so `centre.X` is -3899 and `roadsOf("C1").main.at` is EW2 = -5107, which is
exactly the hunter's `HumanoidRootPart` (-3899.0, 111.7, -5107.0) and the `Stand4` marker; the three
bots at -4049 / -3749 / -4199 are `centre.X` -150 / +150 / -300, i.e. stands 3, 5, 2, which is
`Grid.standWalk` = {4,3,5,2,6,1,7,8,12,...} entry for entry (middle = `ceil(7/2)` = 4). The harness
lines name the request's `Code commit:` `2b2a55d1` with "(clean tree)",
`paperwork-after-code-commit.txt` says OK (only `TASKS.md` and `REQUEST.md` followed it), and
`[harness2]` is present for `src/server/Match/init.luau`. Item 9's refusal path
(`#linePosts == 0`) was seen neither live nor by any spec — see the first note.

Delete-the-producer, done by reading on the one case the request offers for claims 1-4
(`grid.spec` / "the stand walk" / "deals the first hunter of a cell the MAIN stand hunterStandX aims
at"): with `ForestTest.standWalk`'s `sides` arm removed (and the `standIndexFor` arm that feeds it,
or the two recurse), the cell's walk is the derived centre-out over 15 — `math.floor(15/2)+1` = 8 —
so `walk[index] == value` against `Grid.standWalk(id)` fails at entry 1, `Grid.sideOf(id, deal[1])`
answers `"west"` not `"main"`, and `expect(stand).to.equal(ForestTest.standIndexFor(1))` fails; with
`defaultPickIndex`'s `sides` arm removed it answers `math.min(5, 15)` = 5 and
`expect(ForestTest.hunterStandX()).to.be.near(Forest.standX(stand, layout), 1e-6)` fails by one
`mainSpacingStuds`, 150 studs. No line of the case survives the deletion, and the two sides of the
`hunterStandX` comparison are two computations (`standX(defaultPickIndex())` clamped by `onLine`
versus `standX(deal[1])`), not one identity. The round-1 cases likewise flip: "the line question" /
second case builds a real `Markers.Set` for a cell and drives `gatherSpotFor` and `throughSpotFor`,
and `wrongMiddle` = `posts[ceil(15/2)]` = stand 8 at `roads.main.at + flankFirstStuds()` is asserted
as its own number.

## Notes (non-blocking)
- `src/server/ForestTest/Markers.luau` / `Markers.build` — claim 9's two halves are driven by NO
  case: `line-posts` appears nowhere in `tests/`, and `grid.spec`'s cell cases build a complete set
  (15 posts, 7 line). Worse, the `complete` term is very nearly dead: `#linePosts == 0` requires all
  seven main stands refused, and stand 4's x IS `layout.centre.X`, which is where
  `Markers.lineGroundFor` reads the line — so the same refusal normally makes `line == nil` and
  `complete` false already. The one reachable path is `lineGroundFor`'s seat exception (it takes the
  terrain reading inside a seat footprint). Say that at the term, and a ground reader that answers
  nil on `roads.main.at` only would pin the `missing` string.
- `src/shared/Flags/init.luau` / `GRID_PREVIEW` — `owner` is still *"ServerScriptService.Places (and
  ReplicatedStorage.Grid, data)"*, but with this branch the flag decides the LIVE drive layout in
  `ForestTestBoot` (`if gridPreviewOn then Grid.PREVIEW_CELL else ServerStorage:GetAttribute(...)`).
  The read is single and at one boundary (`local gridPreviewOn = Places.gridPreviewEnabled()`, passed
  inward), so the flag rule is met; the row names no owner for what the flag now does.
- `src/server/ForestTest/init.luau` / `forcedLayout` — it accepts a cell id with the preview OFF
  (`local id = string.upper(word); return if Grid.cellOf(id) ~= nil then id else nil`), so a Director
  typing `c1` into `DHForestLayout` promotes a cell on unpainted ground: no roads, no corner stakes,
  and the 3.1 beater walk the flag's own `why` now warns about. Needed as the spec's parameter seam,
  but undeclared — one sentence at `forcedLayout`, or gate it on the preview.
- `tests/server/grid.spec.luau` / the new case — claim 3's second entitlement shape adds no path:
  C1's seats are `{8, 13, 15}` and `walk[1]` is 4, so `allowSeat` never gates the answer and
  `dealLine(walk, seated, { false }, 1, nil)` returns 4 through the same PASS 1 line as the nil case.
  An unentitled case that bites needs a cell whose walk's head carries a seat.
- `src/server/ForestTest/Markers.luau` — the new comment names `ForestTest.linePostsOf`; the function
  is `linePostsOf`, a local in `src/server/Match/init.luau`.
- `src/server/ForestTest/init.luau` / `standIndexFor` — the header above it still reads as the whole
  function (*"CENTRE-OUT -- 5, 4, 6, 3, 7, 2, 8, 1, 9 ... a solo hunter gets stand 5, which is
  `Data.PICK.defaultIndex`, which is the x `ForestTest.hunterStandX()` aims every wave at"*). That is
  the road's branch only now; the cell arm is documented inside the body.
- `src/shared/Grid/init.luau` / `Grid.standWalk` — it ignores its `_id` and builds a fresh 15-entry
  table per call, and `standIndexFor` now calls it once per index through `ForestTest.standWalk()`.
  Harmless at four bots; memoise it beside `LAYOUT_BY_ID` if the deal ever runs per frame.
- `src/client/Hud/MapUi.luau` — unchanged by this round and confirmed graceful, not a crash:
  `geometryFor` does `local layout = forestTest.layoutNamed(layoutName); if layout == nil then return
  nil end`, so with the preview on Karen walks C1 with NO map rather than a wrong one. Queued as
  327f, as the Director's decision C says.

---
REVIEWER verdict on commit `aa7a2f2cf2d819527a9df97a36aa315f536f0899` (round 3) · 2026-11-01 23:54 UTC · session cost $4.00, 41 turns · written by tools/agents.py
