# Task 354 -- the painted map in the game, behind `MAP_PAINTED` (born OFF)

Task: 354
Round: 1
Base: 8cc53d35 (origin/main)
Code commit: 159c66257ad6b21e5eb08519fcf0dce010cc3291

```
[harness] PASS: 34/34 checks @ 159c66257ad6b21e5eb08519fcf0dce010cc3291 (clean tree) scope=all
```

`test2` is **N/A**: nothing here touches `TWO_PLAYER_PATHS` (the map UI, a flag row, a render script
and one client spec repair), and the dispatch says `test2` N/A.

## What changed

`tools/map_paint.py` renders the M map's ground as **nine PNGs** -- one per drive cell plus one for
the 420-stud outer wood -- into `assets/ready/map/`, and writes `src/shared/Map/PaintedMap.luau`
(each tile's world rect) and `src/shared/Map/PaintedLandmarks.json` (the proof table). `MapUi` draws
them as `ImageLabel`s under the icons, behind `MAP_PAINTED`, born OFF.

**THE UPLOAD IS BLOCKED AND NOTHING WAS PUBLISHED.** All nine Decal uploads answer
`401 Invalid API Key`; a bare read with the same key answers the same, so the credential is refused,
not the asset type. `ESCALATE.md` (2026-11-12 ~20:14 UTC) is the NEEDS KAREN entry, written at the
hard stop before any workaround. Every `assetId` is therefore **0**, which `PaintedMap` and `MapUi`
already treat as "not uploaded, draw nothing". `assets/uploads.json` is **unchanged**.

## Claims

1. **0 px, measured over 83 landmarks, against a different instrument.** `map_ui.spec`'s "puts every
   landmark at the SAME pixel the render script painted it at" takes each world point's pixel from
   `ReplicatedStorage.Map.PaintedLandmarks` -- written by `tools/map_paint.py` -- maps it through
   `MapUi.paintedRectPx`, and compares with `MapUi.rawOffsetPx` of the same point.
   *Verify:* the harness note `map_ui 354 alignment: 83 landmarks (15 stands, 32 corners, 36 road),
   worst 0.000000 px at roadEW3_5`. The 15 C1 stands and the 8 cells' corners the dispatch names are
   counted in the case itself (`Grid.standCount`, `4 * #Grid.cellIds()`), not written down.

2. **The picture is of THIS forest.** The render script mirrors `Grid`'s arithmetic in Python, so the
   case "paints the world the GAME says is there" compares its 47 stand and corner points against
   `Grid.standPosition` and `Grid.boundsOf`.
   *Verify:* note `map_ui 354 geometry mirror: 47 points against Grid, worst 0.000e+00 studs`.

3. **Flag OFF is today's `MAP_LOOK` map; ON replaces the tint and keeps the icons.**
   *Verify:* note `map_ui 354 draw: 9 images and 0 bands with the tiles, 0 and 384 without`, plus the
   case's own assertions that stands are still drawn and no band sits below `CONFIG.Z_INDEX`.

4. **Inside task 347's budget.** *Verify:* note `map_ui 354 budget (DEV): open p50 0.16 ms, max 0.68
   ms (<= 50), 322 instances in the map frame (<= 1500)` -- the same five-timed-opens instrument
   347's cost case uses. **DEV ONLY.**

5. **One owner, one read of the flag.** `MapUi.PAINTED.ENABLED` is the only `Flags.isOn("MAP_PAINTED")`
   in the repo; `Hud` requires `PaintedMap` only while it is on, so an OFF build never loads it.
   *Verify:* `grep -rn "MAP_PAINTED" src/` -- the flag row, `MapUi.PAINTED.ENABLED`, and `Hud`'s
   comment. Nothing but `MapUi` creates an instance in the map frames.

6. **Both states reachable by parameter with the row at false.** Every case drives the layer through
   `geometryFor`'s own `paintedMap` argument. *Verify:* `Flags.DEFAULTS.MAP_PAINTED.default == false`
   and the four cases pass.

7. **A tile with no picture is dropped, not drawn blank.** `PAINTED.NO_ASSET` is the only rule, and
   it is applied in the producer so the drawer can ask one question. *Verify:* case 1 asserts
   `paintedFromGrid` answers nil for an `assetId` 0 table and one tile once an id is set.

8. **The eight tiles tile the footprint exactly** -- shared rounded boundaries, no gap, no overlap --
   and each tile's world rect is read BACK out of its whole-pixel crop box, which is what makes 0 px
   exact rather than nearly exact. *Verify:* `python tools/map_paint.py selftest` (29 checks, incl.
   the round-trip at four resolutions) and `python tools/map_paint.py check`.

9. **The render script reads the repo and refuses to guess.** `Grid.CONFIG`, `Grid.CELLS`,
   `Places.CELL_PLANS`' `zone(...)` rows and `Shotgun`'s slug range are parsed from `src/`; a missing
   constant raises `Refused`. *Verify:* selftest cases "a renamed constant is REFUSED, not defaulted"
   and "a Grid with the wrong cell count is REFUSED". The render is deterministic: two runs produced
   byte-identical PNGs (`sha256sum` diff empty).

10. **`report_panel.spec:540` was RED ON MAIN and is repaired here.** A control run with
    `origin/main`'s `src/` and `tests/` checked into the tree failed the same line:
    `[harness] FAIL: 32/34 checks @ ababb3cf8712 (DIRTY TREE (4 paths) - NOT valid evidence) scope=all`
    with `failed [client] report_panel.spec:540 Expected value "2" (number), got "1" (number)`.
    It read `#after == before + 1`, which counts two different lists across the render `onKilled`
    triggers -- that render expires lines older than `Drive.CONFIG.FEED_SECONDS` (8 s) and caps the
    rest at `Style.FEED_LINES` (3). Now asserted as the rule it was written for: the kill's line is
    the LAST line and is in the feed exactly ONCE.
    *Verify:* `git show origin/main:tests/client/report_panel.spec.luau` vs this branch's, and the two
    harness lines above (the control at `ababb3cf8712`, the gate at `159c6625`).

## What could NOT be verified, and why

* **THE UPLOAD, AND THEREFORE THE FLAG-ON FRAME.** `NOT OBTAINABLE`, measured reason in `ESCALATE.md`:
  nine `401 Invalid API Key` refusals and the same on a bare read. With every `assetId` at 0 there is
  nothing to draw, so a flag-ON frame would show today's map and would be a frame named for a state
  it does not show. No such frame is offered. `assets/uploads.json` has **no new row**.
* **ANY LIVE PROOF IN KAREN'S FOREST TEST.** Her FT syncs from `driven-hunt-karen`, which carries
  merged `main` and not this branch, and the dispatch forbids checking code out there. So no frame in
  her place can exercise this change before the Director merges. Nothing was started, no attribute
  was touched, and `MAP_PAINTED` is **left OFF** -- the dispatch leaves it on only if every item is
  MET, and the upload is not.
* **THE CLICK PROOF on the painted map.** It needs the painted map on screen in her place, which
  needs the upload. `NOT OBTAINABLE` for the same reason. Task 352b's finding stands untouched: the
  stand pick works by a real click when the window is not re-activated (`click.ps1`, in `<runs-dir>`),
  and nothing in this change touches the pick path.
* **The budget numbers are DEV ONLY**, as task 347's are.
* **Whether Karen likes it.** Nobody has seen the painted map in the game, and nobody can until the
  key is replaced.

## The pictures, opened and described

* `assets/ready/map/c1.png` (774 x 1024) -- C1's cell: a yellow-green wood (mean RGB 88,96,32) with
  amber autumn crowns through it, a pale open scrub patch at the top-left and another top-right, the
  sandy east flank road curving down the right-hand edge, and the main road along the bottom with
  darker wood beyond it.
* `assets/ready/map/wood.png` (1024 x 739) -- the whole world: two rows of four wood blocks separated
  by the pale, visibly bent road grid, and the outer wood skirt running past the blocks on every side
  before it fades into olive open ground. This is the "outer wood drawn" the dispatch asks for.
* Checked numerically rather than by eye: each of the eight cell tiles correlates **0.993-0.998** with
  the same rectangle cropped out of `wood.png`, mean colour equal to +-1 per channel -- so the crops
  really are where the manifest says they are.
