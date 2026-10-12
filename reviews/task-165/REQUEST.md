# Task 165 — review request

Task: 165
Round: 1
Base: `9d73341` (main, #148 merged)
Code commit: `0a14dd5285774a7cd67d0bab955cd1db6bed782b`
Branch: `task-165-clear-hud`

```
[harness] PASS: 33/33 checks @ 0a14dd5285774a7cd67d0bab955cd1db6bed782b (clean tree) scope=all
[harness] PASS: 33/33 checks @ 0a14dd5285774a7cd67d0bab955cd1db6bed782b (clean tree) scope=all
```

Two full runs, `.agent-logs/task165-test1.log` and `task165-test2.log`.
**`[harness2]` IS OUTSTANDING AND IT IS A HUMAN CLICK.** `src/shared/Drive/init.luau` is in
`TWO_PLAYER_PATHS` and two of its layout offsets move (claim 2), so the merge needs
`python tools/studio_mcp.py test2`. `test --scope auto` cannot stand in for it here: this change
edits `tools/studio_mcp.py` (claim 9, required or `selftest` fails), which `BLAST_RADIUS` resolves to
`all` — **measured**, `scope_for(changed_paths())` answers `['all']` — so a scoped run would print
`scope=all` and be full evidence rather than a review-round line.

## What changed

Karen, 2026-10-12 ~10:40: *"we need to have better map or direction that people has to walk we need
to improve design that it will be clear to understand what happening / could be buttons on the side
for M - map ect"*.

The finding behind the answer is in `docs/research/2026-10-12-hud-clarity.md`: **everything this Hud
drew was a FACT and nothing was an INSTRUCTION.** Built to `docs/design/hud-clarity.md` (Architect
`PASS`), with one named deviation and one correction to the design, both below.

Twelve files. Two new modules (`src/client/Hud/Objective.luau`, `src/client/Hud/Rail.luau`), one new
spec (`tests/client/hud_clarity.spec.luau`), four existing owners edited
(`src/client/Hud/init.luau`, `MapUi.luau`, `Compass.luau`, `src/client/Weapon/Input.luau`), two
constants in `src/shared/Drive/init.luau`, `tools/studio_mcp.py`, `tests/client/map_ui.spec.luau`,
`GAME_DESIGN.md`, and one archive note under `backups/`.

## Claims

1. **One objective line, by role x phase, and it is pure.** `Objective.text(phase, team)` returns one
   ASCII sentence; `Objective.CONFIG.TEXT` is the only place the words live. *Verify:*
   `tests/client/hud_clarity.spec.luau`, `describe "the sentence"` — all six role x phase rows, both
   `Waiting` rows, `""` for no team in every phase, every byte under 128, and the live case in
   `describe "what is actually drawn, live"` asserting the LABEL equals the pure function in whatever
   phase the run is in. Run note: `objective live: phase=Running team=Shooters visible=true
   text="stay on your stand, boars coming"`.

2. **The top band moved down one band and nothing overlaps anything.** `Objective.CONFIG.TOP` 8,
   `Drive.CONFIG.BAR_TOP_OFFSET` 8 -> 44, `TIED_TOP_OFFSET` 44 -> 74, `Compass.CONFIG.TOP` 76 -> 108,
   `MapUi.CONFIG.MINIMAP_TOP` and `FULL_TOP` 108 -> 140, rail under the minimap. *Verify:*
   `hud_clarity.spec`, `describe "the rectangles do not overlap"` — six bands, pairwise, at
   **400x800, 800x600 and 1920x1080**, computed from the same constants the renderers read.
   `Objective.lineRect`, `Rail.rect`, `MapUi.minimapRect` and `MapUi.fullMapRect` are pure and
   exported for exactly that: no tool here can resize a Studio viewport, which is why
   `map_ui.spec`'s `AbsolutePosition` case cannot answer for a phone. That case stays and now
   measures the RAIL (a 216 px column) where it used to measure one 48 px button.

3. **One world waypoint, projected by hand, pinned rather than hidden.** `Objective.project` takes
   the view `CFrame`, the vertical fov and the viewport; `Objective.markVisible` is a second
   predicate beside the line's. *Verify:* `hud_clarity.spec`, `describe "the projection"` — dead
   ahead is dead centre; **four properties** pin the formula (the tangent law, distance invariance,
   the magnification law, the viewport law), each of which a linear mapping fails; off the edge
   clamps per axis and reports `onScreen == false`; behind pins to the correct side at mid height.
   And `describe "what is actually drawn, live"` renders the real node twice and reads back its
   position and its `BackgroundTransparency` (0 in front, `PINNED_TRANSPARENCY` when pinned).

4. **The compass, the minimap and the full map show the SAME target, from ONE evaluation.**
   `Hud.renderObjective` resolves it once a frame and is the only caller of `Compass.setBearing`,
   `MapUi.setPush` and `MapUi.setTarget` after boot; `Hud.markerFor` is the pure rule (the target's
   bearing when there is one, the world's when there is not). *Verify:* `hud_clarity.spec`,
   `describe "the compass, the map and the chevron agree"` — compared against `Compass.headingDeg` of
   the same vector rather than against a copy of the expression. **This REMOVES a two-writer
   arrangement**: `Hud.start`'s `whenReady(ReplicatedStorage, "ForestTest", ...)` closure used to call
   `Compass.setBearing` and `MapUi.setPush` itself and now writes two locals.

5. **Arrival, with hysteresis, is what stops a man standing on his own stand being given a wobbling
   arrow.** In at 12 studs, out at 18 (`ForestTest.PICK.leashStuds` is 6). Arrived means no chevron
   AND no compass takeover, so the strip goes back to the drive. *Verify:* `hud_clarity.spec`,
   "latches ARRIVED with a dead band" — both directions. Visible in screenshot 1: the hunter is on
   his stand, so there is no chevron and the strip still says DRIVE.

6. **The rail: four buttons, every one a second door onto a function that already exists, and no
   dead buttons.** `Rail.BUTTONS`, `Rail.press(id)`, `Rail.buttonVisible(button, hasWeapon)`.
   `Input.reload` and `Input.selectAmmo` are new public twins in `src/client/Weapon/Input.luau` with
   the input hold moved INSIDE them, so a button and a key run one implementation and neither can
   fire through an open report panel. `Input` is still the only firer of `ActionRequest`. *Verify:*
   `hud_clarity.spec`, `describe "the button rail"` — `Rail.press("MAP")` flips `MapUi.isOpen()` and
   `MapUi.stats().toggles`, `Rail.press("REPORT")` flips `ReportPanel.isOpen()`, an unknown id
   returns false, and no weapon hides exactly RELOAD and AMMO. Run note:
   `rail: MAP,REPORT,RELOAD,AMMO (touch=false)`.

7. **The map's own touch button is gone, and the thing that replaced it is asserted.** It was
   `touchEnabled and BUTTON_ENABLED`, so it had never once appeared in a session of Karen's — which
   is why she asked for a button that was already written. `MapUi.CONFIG.BUTTON_ENABLED`,
   `MapUi.buttonVisible`, `MapUi.start`'s `button` field, its `layoutFor` lines and `Hud.mapButton`
   are removed; the block is archived with its reason in
   `backups/2026-10-12_mapui-touch-button.txt` (rule 7). *Verify:* `map_ui.spec`, "has NO button of
   its own any more, and the rail's one opens this map" — `Hud.mapButton` is nil, `Rail.press("MAP")`
   opens this module's map, and `stats().keyToggles` is NOT incremented by it.

8. **The full map is clearer and still fits a phone.** A six-row legend (`MapUi.legendRows`,
   `MapUi.legendVisible`) inside the panel, one orange-red target mark that is YOUR place, and the
   panel shifted left by half `MapUi.CONFIG.RAIL_COLUMN_PX` so it never runs under the rail — which
   **cannot hide**, because on a phone it is the only way to close the map. *Verify:*
   `hud_clarity.spec`, "keeps the full map clear of the rail" at three viewports, plus
   `RAIL_COLUMN_PX == Rail.CONFIG.BUTTON_PX + Rail.CONFIG.MARGIN + 8` asserted rather than assumed,
   and "hides the legend where no font inside the panel could be read" (below a panel scale of 0.67).
   **Stated, not hidden:** at 400 px the panel's scale is about a third and the legend is OFF; what a
   phone loses is the colour key for other players' teams.

9. **The harness knows the new spec.** `SCOPE_SPECS["hud"]` gains
   `tests/client/hud_clarity.spec.luau`, without which `python tools/studio_mcp.py selftest` fails
   with "a spec file belongs to no scope". *Verify:* `selftest` passes; this is also the edit that
   makes `--scope auto` resolve to `all` (see the top of this page).

10. **Nothing in this task decides anything.** No remote, no snapshot field, no `CollectionService`
    query, no `BillboardGui`, no Instance outside `PlayerGui.HunterHud`, no write to the camera, the
    weapon, the match or the world. The objective is a reading of `MatchSnapshot.phase` +
    `Player.Team` + `Match.secondsLeft()`; the target is a reading of the `MapGeometry` `MapUi`
    already builds. *Verify:* `git diff 9d73341..0a14dd5 --stat` — `src/server/` and `src/shared/`
    are untouched but for the two layout constants in `Drive.CONFIG`.

## What I could not verify, and two corrections

- **THE TAP ON A RAIL BUTTON IS NOT PROVED AND CANNOT BE TODAY** (rule 6, rule 8). A spec cannot fire
  `GuiButton.Activated`, the harness cannot synthesise a touch, and a `moveTo` step in
  `tests/client/input_scenarios.txt` carries STATIC pixel coordinates while the rail is anchored to
  the right edge of a Play window whose size is not fixed. `Rail.press` is the seam the spec drives
  and what it proves is the ACTION, not the touch. The fix is a scenario step that names a GuiObject
  and resolves its centre at replay time — harness work, queued as 165a.
- **CORRECTION TO THE DESIGN, MEASURED.** Design 10.1 case 5 asks for `Objective.project` to be
  checked against `Hud.reticleDegToPx` as *"an INDEPENDENT expression of the same relation"*. **It is
  not the same relation.** The scope's conversion is the LINEAR screen mapping `viewportY * deg /
  fov`; a perspective camera puts an angle at `f * tan(deg)`. Measured in the run:
  `1 deg is 13.46 px exact against 15.43 px by Hud.reticleDegToPx (ratio 1.146, predicted 1.146) at
  fov 70, viewportY 1080`, and 1.146 is exactly `2 * tan(fov/2) / fov_in_radians`. So the scope's
  duplex is drawn about 15 % further from the centre than the world behind it. **Nothing in this task
  depends on it and nothing here changes it** — the scope was tuned and photographed against its own
  conversion (task 141) and `src/client/Camera` is out of scope. The spec asserts the RATIO and notes
  the number; the projection itself is proved by the four properties in claim 3. Queued as 165a.
- **`Scoring` is not reached by any client run** (a drive is 600 s), so its two sentences are proved
  purely. `Running` IS reached, and the live case asserts there.
- **The hunter's stand is the NEAREST stand**, so it becomes his neighbour's once he walks past half
  the 150-stud spacing. Asserted as a case so it is a decision and not a surprise; the real fix is
  the drive publishing the assigned stand index, which is a new snapshot field and is refused by the
  design. Queued as 165a.
- **In the DEV world a hunter is sent to the LINE, not to a STAND**, because
  `MapUi.geometryFromMap` publishes `stands = {}` deliberately and `Match.CONFIG.ODD_PLAYER_TEAM` is
  `"Shooters"`. The word changes with it, so the screen never claims to know more than the world
  said. Task 155a (`Map.LINE`) is the full answer.
- **Deviation from the brief's D12**, named by the design (section 1.2) and followed here: the new
  strings live in `Objective.CONFIG` and `Rail.CONFIG` rather than `Drive.CONFIG`, because the repo's
  real rule is one word table per drawer and `src/shared/Drive/` is in `TWO_PLAYER_PATHS` — a
  sentence kept there could not be retuned without a human click, and these are sentences Karen is
  going to move.
- **A beater in the Forest Test shows RELOAD and AMMO**, because `Weapon.get().equipped` is true for
  her — the same read the ammo readout has always used, and screenshot 2 shows that readout. Whether
  a beater should carry a gun at all is a game question, not a rail one; the rail follows the one
  reader rather than inventing a second.

## Screenshots, inspected (rule 5)

Both taken in **Driven Hunt Forest Test**, in a live drive, one per role.

- `.screenshots/20261012T124250Z-t165-hunter.png` — the objective line *"stay on your stand, boars
  coming"* on the top line, the drive bar under it in SHOOTER orange, the compass with its DRIVE
  marker, the minimap with the road and the stands, and the rail: MAP/M, REPORT/TAB, RELOAD/R,
  AMMO/X. **No chevron, because he is standing on his stand** — claim 5, in a picture.
- `.screenshots/20261012T124426Z-t165-beater.png` — *"walk to the road, push the boars"*, the bar in
  DRIVER blue, the compass marker reading ROAD, **the orange-red chevron in the world with
  `ROAD  106 m` under it**, the minimap's target mark pinned at the rim (378 studs, past the 300-stud
  range), the rail, and the feed. Nothing overlaps anything in either frame.
