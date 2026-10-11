# Task 155 — review request: the map (full map on M, round minimap)

Task: 155
Round: 2
Base: `14eb7e9` (main, after #137)
Code commit: `0f5f9fe46fc6866e83cf03967ad4f80c915d8149`

```
[harness] PASS: 33/33 checks @ 0f5f9fe46fc6866e83cf03967ad4f80c915d8149 (clean tree) scope=all
[harness2] N/A — nothing in TWO_PLAYER_PATHS is touched (see claim 9)
```

The full `test` was run TWICE on this commit, both PASS 33/33 clean
(`.agent-logs/task155-test1.log`, `task155-test2.log`).

## Round 2 — both blocking findings fixed, and three of the notes

**Finding 1 — the minimap was resized TWICE, and the Reviewer is right.** A `UIScale` scales the
GuiObject it is parented to, not only its descendants, and **the same run already measured it**: the
full map was built 984 x 700, `UIScale` 0.897, `AbsoluteSize` 883 x 628. So `layout` writing both
`mini.Size` and the scale multiplied them, and a 96 px minimap at a 400 px viewport rendered at
**61 px**, with the picture inside it — built in the fixed 150 px space, half-extent 75 — drawn at
radius 48 inside a frame of radius 30 under `ClipsDescendants`: **a marker pinned to the rim was
clipped out of existence**, which is the one thing the pin exists to prevent. Nothing in the run
could see it, because at this PC's 969 x 784 the diameter is 150 and the scale is exactly 1.
*Fixed:* the `Size` write is gone and the `UIScale` is the one writer, so
`AbsoluteSize = MINIMAP_DIAMETER_PX * Scale = diameter` exactly; the button is placed from that same
rendered diameter. *Pinned:* `MapUi.applyLayout(viewport)` is public, and `map_ui.spec` →
*"RENDERS at that diameter, at a phone's viewport as well as at this one"* asserts the live
`AbsoluteSize` at 400 x 800 and at 1920 x 1080. **Its note from this run:**
`map: minimap renders 96 px at 400x800 (want 96) and 150 px at 1920x1080 (want 150)`.

That case took a second go and the reason is worth having: `applyLayout` originally just laid out,
and the 20 Hz tick re-read the real `ViewportSize` and undid it **within 50 ms, between the call and
the read** — the case saw 150 where it had asked for 96. `applyLayout(v)` now **pins** the viewport
until `applyLayout(nil)` gives the screen back, which is the same explicit-seam shape as the flag
and pose overrides; `MapUi.pinnedViewport()` lets the case assert it gave it back.

**Finding 2 — the toggle count proved nothing about the key, and the Reviewer is right.**
`stats.toggles` counts every change including the spec's own `setOpen` calls, so `toggles >= 2`
passed with the M binding deleted — and that case was the whole of "a real M arrives" (rule 6).
*Fixed:* `stats.keyToggles` is incremented **only** inside the bound action's `Begin`, which nothing
a caller can reach, and the case asserts it **equals** the scenario's two presses.

**Three notes that were real defects rather than wording, fixed in the same round:**
- `geometryFor` fell through to the DEV geometry for **any** unrecognised world, so the next place
  id added to `Map.WORLD_BY_PLACE` would have drawn the DEV road over a place that never heard of
  it — wrong rather than absent, the opposite of design section 5.4. It compares `EXPECTED_WORLD`
  now, and the spec asserts `geometryFor("some-new-place", nil, Map) == nil`.
- `markerPoints` read a team back as `""` where `pointsFor` answers `nil` (an attribute cannot hold
  nil). One shape for one answer.
- `stats.pinned` was cumulative while `stats.overflow` beside it was per tick. Per tick now.

**The remaining notes are queued as 155c** in `TASKS.md`, including the two the Architect owns (the
design's owner table gives the frames' sizing to `Hud.build` while `MapUi.layoutFor`/`setGeometry`
write it, and section 5.2's bounds are stale by the road's amplitude — the live span is 1,720 x
1,130, which the spec's own note prints). **REQUEST claim 7's wording was overstated and the
Reviewer is right about that too:** the intersection case measures the minimap and the button, not
the full map's panel; claim 7 below now says so.

## What changed

Karen, 2026-10-11: *"I am missing map, we need a map when click M where will be hunter position
where they stand and what direction to move also can see other players on map moving / and small map
in left or right corner circle like is on another games hwere showing where to move ect"*.

A new system, to `docs/design/map-ui.md` (Architect PASS, `ARCH_RESULT.md`), from
`docs/research/2026-10-11-map-ui.md` and `reviews/task-155/BRIEF.md`.

- **`src/client/Hud/MapUi.luau`** (new) — the one writer of everything inside the two map frames.
  The projection is pure; the drawing is a pool of `Frame`s built once per world.
- **`src/client/Hud/init.luau`** — builds `MiniMap`, `FullMap` and `MapButton`; starts `MapUi`;
  hands it the push bearing; states the scope's suppression need. The `ForestTest` bearing closure
  moved out of `if compassFrame then`.
- **`src/server/ForestTest/init.luau`** — task 154a item (a): `restSpot`'s keep-away.
- **`tests/client/map_ui.spec.luau`** (new), **`tests/client/input_scenarios.txt`** (a real M),
  **`tests/server/sync.spec.luau`** (a latent fault, claim 10), **`tools/studio_mcp.py`**
  (`SCOPE_SPECS["hud"]`), **`GAME_DESIGN.md`** (the owners row).

## Claims, and how to verify each

1. **The map is PROJECTED, never rendered, and the reason is an engine fact.** A `ViewportFrame`
   cannot render Terrain and the ground is Terrain in both worlds, so the option the Roblox docs
   recommend first for this use case would draw a void. *Verify:* `docs/research/2026-10-11-map-ui.md`
   weighs three patterns with licence and maintenance status; `MapUi`'s header carries the fact and
   the link. No `ViewportFrame` and no image asset appear anywhere in the diff.

2. **One owner, and `Hud` is still it.** `Hud.build` CREATES the three nodes and writes their
   `ZIndex`, `ClipsDescendants`, colours and their starting size and position; `MapUi` writes
   everything inside them, their `Visible`, and — from `layoutFor` and `setGeometry` — their live
   size and position thereafter. **Round 1's wording said the sizing stays with `Hud.build` and the
   Reviewer is right that it does not;** the code says so for the full map
   (*"Its size is written by `MapUi` … the offset here is only what it starts at"*) and the design's
   owner table does not, which is queued for the Architect as 155c.
   *Verify:* `Hud.build` — `miniMap`/`fullMap`/`mapButton`; the only writers of `.Visible` on those
   frames are `MapUi.applyVisibility`. `grep -n "MiniMap\|FullMap" src/client/Hud/init.luau`.

3. **The compass's two-writer arrangement is deliberately NOT copied.** `Hud.renderScope` states a
   need — `MapUi.setSuppressed(scoped)` — and `MapUi` performs the single write, which is
   `Camera.Cursor.requestFree`'s pattern. *Verify:* `Hud.renderScope`, the block after the compass's
   `compassHiddenByScope` flag; `MapUi.setSuppressed` and `MapUi.applyVisibility`. Spec: *"hides both
   at once while a sight picture is in, and puts back what was there"*.

4. **The projection is pure, north up, one scale, and agrees with the compass.** `MapUi.project` has
   one minus sign; `MapUi.facingOffsetPx` is its inverse and the only other trigonometry.
   *Verify:* `map_ui.spec` → *"puts north UP and east RIGHT"*, *"uses ONE scale on both axes"*, and
   *"agrees with the COMPASS's bearing convention at all four cardinals"* — that case takes each
   bearing from `Compass.headingDeg` rather than re-writing the expression (task 129's lesson).

5. **The geometry is the world's own numbers, not a second copy.** *Verify:* `map_ui.spec` →
   *"draws the Forest Test's road from `ForestTest.roadZ` and nothing else"* (every sampled point
   equals `roadZ(x)`), *"draws the stands from `ForestTest.standPosition`, all nine, in order"*,
   *"holds everything that world states inside its bounds"*.

6. **The push direction is `Hud.driveBearing`, evaluated ONCE and handed to both drawers.** `MapUi`
   never calls that rule. *Verify:* `grep -n "driveBearing" src/client/Hud/` — one call site, in the
   team closure that also feeds `Compass.setBearing`. Spec: *"shows the push direction the HUD's own
   rule gives, with its word"*, which asserts a beater's `ROAD` differs from a hunter's `DRIVE`.
   **Measured live, as a beater:** `team=Drivers`, `arrow rot=180`, `word='ROAD'`.

7. **The minimap and the button overlap nothing already on screen.** (Round 1's wording said
   "nothing the map draws", which overstated it: the full map's PANEL is intersected with nothing,
   in any world — queued as 155c.) *Verify:*
   `map_ui.spec` → *"keeps the map clear of the drive bar, the tied banner, the compass and the
   readout"* makes each element visible and intersects their `AbsolutePosition`/`AbsoluteSize`
   rectangles — so it cannot hide the way task 125 round 2's defect hid. **Measured live** (viewport
   969 x 784): `MiniMap abs=(807,50) 150x150`, `Compass abs=(304,18) 360x26`,
   `Readout abs=(713,686) 240x24`. `MINIMAP_TOP = 108` and `diameterFor` are why it holds at
   ~400 px too.

8. **The DEV world gets the road, the bounds and the players and NO stands, deliberately.** The post
   line is stated only in `src/server/Match/Markers.luau` (`TWO_PLAYER_PATHS`) and in ServerStorage,
   which does not replicate. *Verify:* `MapUi.geometryFromMap`'s header; `map_ui.spec` →
   *"gives the DEV world a straight road, widened bounds and NO stands"* asserts `#stands == 0`, so
   task 155a changes a case rather than finding a comment.

9. **`test2` is N/A.** *Verify:* the changed paths are `src/client/Hud/`, `src/server/ForestTest/`,
   `tests/client/map_ui.spec.luau`, `tests/client/input_scenarios.txt`, `tests/server/sync.spec.luau`,
   `tools/studio_mcp.py` and docs. None is in `TWO_PLAYER_PATHS` (`tools/agents.py`). `git diff
   --name-only 14eb7e9..ae1fdf7`.

10. **Two defects were found by this task's own evidence, and both are fixed and pinned.**
    *Verify:*
    - **Parent visibility.** The full map's drawer draws into a canvas inside the panel; the canvas
      is always `Visible` and the PANEL opens and closes, so the closed map drew a second copy of
      every marker. `Drawer.gate` is the fix; the spec case *"draws THIS player exactly once"*
      caught it (`mine <= 1` was false) and now pins it. This is `PROJECT_CONTEXT.md`'s *"a
      visibility audit ignored parent visibility"*.
    - **The arrow ran the wrong way, and only the SCREENSHOT caught it** (rule 5). Every number was
      right — bearing 180, word `ROAD`, rotation 180 — and the bar pointed north, because
      `GuiObject.Rotation` pivots about the element's **centre**, not its `AnchorPoint`. The bar is
      centred half its length along the bearing now, which depends on no pivot at all, and
      `map_ui.spec` → *"runs the push arrow FROM the player TOWARD the way to go"* is the number
      that would have.

11. **A latent fault in `tests/server/sync.spec.luau`, reported rather than worked around**
    (rule 6). It asserted `awaitToken(0) == token.Value`; `openToken` answers *"may a runner START
    now"*, which `TestKit`'s own header calls *"deliberately time-limited (TOKEN_MAX_AGE)"* with
    *"a long suite outlives it"* — 120 s, against a server tail already near that line. Adding one
    client spec and one input scenario tipped it, and the case failed on a run where 898 server
    assertions passed and the token was present. *Verify:* the two questions are asked separately
    now — `TestKit.activeToken()` for *"the token this run opened with"* and `awaitToken(0)` for
    what it promises at any age. Its bound took a second go, recorded in `ae1fdf7`: `awaitToken` is
    a `repeat ... until`, so timeout 0 with a closed gate costs one `task.wait(0.5)`.

12. **Task 154a item (a).** `ForestTest.restSpot` measured its keep-away from where a beater
    *spawned*; at re-stock she is 240 studs from there, and the last `REST.groups` row lands ~56
    studs from where she actually is — inside `SPOOK.BEATER_STUDS` (89). *Verify:* `restSpot` now
    reads `ForestTest.realBeaters()` once and takes `nearestBeater(at, beaters)`, with
    `Data.beaterStart` as the explicit fallback for the first stock, when nobody has a body.
    `tests/server/forest_stand.spec.luau` still passes untouched.

## What I could not verify

- **"Can see other players on map moving" needs a SECOND client.** `MapUi.pointsFor` is pinned over
  a synthetic roster (nil position, the pin, the overflow, the colours) and the live case proves
  *this* player is drawn exactly once — but a second real marker is a **playtest** item. It is not a
  gate item: `TWO_PLAYER_PATHS` decides the gate and this change is not in it.
- **The mobile button cannot be driven by the harness at all** — touch is one of the things
  `tests/client/input_scenarios.txt` cannot express (TASKS.md Task 6). The predicate is pinned both
  ways and the live button's `Visible` is asserted to equal `UserInputService.TouchEnabled`
  (measured `false` on this PC, so the button is correctly hidden). **Whether it works under a
  thumb is Karen's phone.**
- **Everything about the LOOK** — the 150 px diameter, the 300-stud range, the colours, whether
  north-up reads right, whether top-right is the corner she meant, whether the panel should dim the
  world behind it. Karen's standing rule for this task; `docs/design/map-ui.md` section 20 lists
  them with the Director's start values.
- **`MapUi.CONFIG.FULL_MIN_HEIGHT_PX`'s warning path** was not reached: this viewport is 784 px tall.
- **The full map's panel at a phone viewport was not photographed**, only computed. The minimap's
  rendered diameter IS now asserted at 400 x 800 (finding 1), but design section 16.5's fourth
  screenshot — the device emulator at a phone profile — is still not taken, and it is the frame that
  would have shown finding 1 by eye. Said plainly rather than implied.

## Evidence

- Gate, twice on the code commit: `PASS: 33/33 ... @ 0f5f9fe4 ... scope=all` (and twice again on
  round 1's `ae1fdf78`).
- Smoke in the Forest Test on this commit (`driven-hunt-runs/smoke.sh 85`):
  `gun in hand @15s=1 @85s=1 | stacks=0 errorLines=0 | boars=27` → **SMOKE PASS**.
- **Two screenshots, inspected** (rule 5), both in the Forest Test as a beater,
  `.screenshots/task155-minimap.png` and `task155-fullmap.png`. The minimap is a true circle (the
  `UICorner` 0.5 clip works — design section 17 item 1 resolved), top-right and clear of the compass,
  with the road, nine stands, the cream own-marker and the red arrow running down to the road with
  `ROAD` at its tip. The full map shows the title, `N`, the whole sine road with all nine numbered
  stands, the own-marker north of it and a `100 m` scale bar.
- M was pressed as a **real key** through StudioMCP: `before M: mini=true full=false` →
  `after M: mini=false full=true` → `after M again: mini=true full=false`.
- Spec notes from the run: `map: minimap renders 96 px at 400x800 (want 96) and 150 px at
  1920x1080 (want 150)`, `map: full view 1720 x 1130 studs at 0.531 px/stud; 9 stands span 637 px`
  and `map: 10 ticks in 0.62 s (16.2 Hz, target 20) against 37 frames`.
