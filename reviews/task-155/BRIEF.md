# Task 155 — design brief for the ARCHITECT: the map (full map on M, round minimap)

Written by the Builder, carrying the Director (2026-10-11). This brief is the input to
`tools/architect.sh design map-ui --task 155` and **overrides anything older** in `docs/`,
`TASKS.md` and any existing design where they disagree (`docs/ARCHITECT_PROMPT.md`).

Read first: **`docs/research/2026-10-11-map-ui.md`** — this task's note. It names the three
candidate patterns, their licences and maintenance status, the one engine fact that forces the
choice, and the numeric targets. **The pattern is already chosen and is not open** (§1.2 below).

The design is a **new system document**, `docs/design/map-ui.md`. It is also a **delta** to
`docs/design/drive-report.md` §8 and to the Hud's own ownership statement, wherever the new element
shares screen space or an input key with them.

## 1. The decisions already taken — do not re-open them

1. **KAREN, 2026-10-11 ~14:10, verbatim:** *"I am missing map, we need a map when click M where will
   be hunter position where they stand and what direction to move also can see other players on map
   moving / and small map in left or right corner circle like is on another games hwere showing
   where to move ect"*. That is the whole requirement and the design serves it literally: a key, the
   stands, the direction to move, other players moving, and a small round corner map.
2. **The pattern is a 2D map PROJECTED from the world's own geometry data. No `ViewportFrame`, no
   map image.** The forcing fact is in the note: a `ViewportFrame` cannot render Terrain, and the
   ground is Terrain in **both** worlds. The design must not re-open this; it may record it.
3. **North up, both sizes. The map does not rotate.** Rule 3: a rotating map needs a view heading,
   and `Hud.Compass` already owns that question through `Camera.viewHeadingDeg` — three rounds of
   task 125 were spent getting that one source right. The player's own marker carries a **facing
   wedge** instead, so "which way am I pointing" is answered without turning the picture.
4. **The minimap is TOP-RIGHT and is always on**; the full map is a toggle on **M**, closing on M
   (Escape belongs to the Roblox menu and cannot be bound — `ReportPanel`'s `bind()` says so).
5. **It must be openable without a keyboard** (mobile is in v1): a small on-screen button.
6. **Marker colours are by team**, the local player's own marker distinct. Styling never blocks
   (Karen's standing rule) — the Director picks the first colours and Karen judges them.
7. **An out-of-range marker is PINNED to the border, not hidden.** This repo's own rule already:
   `Compass.offsetPx` returns `(x, onStrip)` and pins at `PINNED_TRANSPARENCY`.
8. **The Forest Test world comes first** — it is where Karen plays. The DEV Match world is served
   by the same projection if it is cheap and safe to do so, and **must not require any change under
   `TWO_PLAYER_PATHS`** (`tools/agents.py`); if it would, the design says so and DEV is a later task.
9. **No boars on the map, no fog of war, no map image under the overlay** in this task. The note
   records each as deliberately out, with its reason.

## 2. What the design must contain

1. **THE OWNER, named, and the reason it is not a second writer (rule 3).** Everything drawn in this
   game is `PlayerScripts.Hud`'s: its own header says it is *"THE OWNER OF ANYTHING DRAWN"* and *"the
   only writer of PlayerGui.HunterHud and everything in it"*. Decide and write down whether the map
   is:
   - a new module **under** that owner (`Hud/Map.luau` or similar, filling a frame `Hud.build`
     creates — the shape `Hud/Compass.luau` and `Hud/ReportPanel.luau` both already have), or
   - a new owner with its own ScreenGui.

   State which, and if it is the first, say explicitly that the Hud remains the one writer and the
   map module the one writer of everything **inside** its frames. Name who owns, individually: the
   projection, the static geometry (road, stands, push arrow), the player markers, the open/closed
   state, the **M** key binding, and the mobile button.

2. **THE PROJECTION, as a pure function with a stated signature and convention.** World (x, z) in,
   map (u, v) in pixels out, plus whether the point is inside the view. It must:
   - use this game's existing bearing convention — **north is +Z, bearings run clockwise through
     east (+X)**, as `Compass.headingDeg` fixes it with `atan2(x, z)` and says why the other order is
     "a compass that is always wrong by one cardinal";
   - put **north up**, so +Z is **−v** (up the screen) and +X is +u;
   - serve both sizes from the same function (the full map and the minimap differ only in centre,
     scale and clip shape);
   - be **pure and exported**, so a spec asserts it with hand-written studs and no world. This is
     the non-negotiable testability requirement: `docs/PROJECT_CONTEXT.md`'s *"measured correct and
     looked wrong"* is survivable only if the arithmetic is provable and the **look** is the only
     thing left for Karen's eye.

3. **WHERE THE GEOMETRY COMES FROM, per world, and the seam between them.** The map must read the
   world's own statement and never re-derive it:
   - Forest Test: `ForestTest.roadZ(x)` (*"the one definition; every other reader calls this"*),
     `ForestTest.standPosition(index)` / `STAND_COUNT`, `DRIVE_BEARING_DEG` /
     `PUSH_BEARING_DEG` / `PUSH_LABEL`, `CENTRE`, `HALF_SPAN`, and — if the design wants bounds —
     `EXIT_Z` and `BEATER`/`LINE`.
   - DEV Match world: `Map.ROAD`, `Map.FIELD.bounds`, `Map.TAGS.shooterPost` and
     `Match.Markers.read`.
   - Define **one shape** ("what a world tells the map") so the map has one reader and two
     providers, rather than two code paths. Say what a world that states nothing gets — and it must
     be *visibly* no map, never a blank panel (the audit that *"certified a blank screen twice"*).
   - The client already reaches `ForestTest` through `Hud.whenReady(ReplicatedStorage, "ForestTest",
     …)`. Say whether the map uses that same door and whether it must survive the module arriving
     late (task 134's bug).

4. **THE PUSH DIRECTION, and which direction each role is shown.** `Hud.driveBearing(data, team)` is
   already the pure rule that answers this for the compass: a hunter gets `DRIVE_BEARING_DEG`
   (where the drive comes from), a beater on `PUSH_TEAM` gets `PUSH_BEARING_DEG` and `PUSH_LABEL`.
   The map must **reuse that one rule**, not a second copy of it. Say whether the map asks the Hud
   or the rule is moved somewhere both read.

5. **SCREEN SPACE, EXACTLY, AND THE COLLISIONS PROVED CLEAR.** Task 125 round 2 shipped a compass
   strip over the drive bar and it *"was not seen because the frames were taken in the Forest Test,
   where there is no bar at all"*. So the design must list the pixel rectangle each existing element
   owns and the one the map takes, and show they do not overlap:
   - drive bar y 8..34 (`Drive.CONFIG.BAR_TOP_OFFSET` 8, 26 tall, 520 wide, top centre)
   - tied banner y 44..68
   - compass strip y 76..102 (`Compass.CONFIG.TOP` 76, 360 wide, top centre)
   - the ammo readout, the feed, the crosshair, the scope mask and the report panel
   Include the **`ZIndex`** the map and the mobile button take, against the stack task 141 set:
   feed/bar 1, compass 6, scope mask 11-13, report/score `Report.CONFIG.PANEL_Z_INDEX` 15.
   State explicitly what happens at **~400 px phone width** — the minimap must still clear the
   readout there, not only at 1080p.

6. **WHAT HIDES WHAT.** Say whether the minimap is hidden while the sight picture is in (the compass
   is, *"because a mask cannot cover what is drawn inside its own circle"*), whether the full map
   hides the minimap, and what the full map does to the crosshair, the cursor and aiming. If opening
   the full map must take the mouse, name the one owner of the cursor (`Camera.Cursor`) and say the
   map asks it rather than writing it.

7. **THE INPUT, and the collision check.** **M** must not already be bound. Name every existing
   binding it is checked against: `Weapon.Input` (`FIRE`, `RELOAD` R, `SELECT_AMMO` X, `AIM`) and
   `ReportPanel` (`Report.CONFIG.TOGGLE_KEY` Tab, Backspace, Return, arrows). Say which service
   binds M and at what priority, and whether it passes or sinks the input.

8. **THE MOBILE BUTTON**: where, how big (a thumb is ~44 px), what it does, and — since it is drawn
   — that it belongs to the same one owner. Say whether it is shown always or only on a touch
   device, and name the property that decides (`UserInputService.TouchEnabled`).

9. **THE REDRAW BUDGET.** Static geometry built once; markers at a stated rate (the note's target is
   ≤ 20 Hz, against `Compass`'s per-frame `RenderStepped`, and the reason the two differ is that a
   compass tracks the **view** while a map tracks **positions**). Say which signal drives it and why
   it is not `RenderStepped`. Name the per-tick work and show there is no clone, no raycast and no
   `GetPartBoundsInRadius` in it.

10. **HOW A PLAYER'S POSITION IS READ**, and what happens for a player with no character yet, a
    streamed-out character, or a dead one. `ForestTest.realBeaters` is the precedent shape
    (`player.Character`, `PrimaryPart`, skip when nil).

11. **FLAG OR NO FLAG, decided and justified.** `docs/design/feature-flags.md`: a *feel-critical*
    path is born OFF. A map is an addition that covers no existing pixel and changes no existing
    rule — say whether that makes it feel-critical, and if a flag is wanted, give the row
    (`owner`, `born`, `expires` within 21 days, one-line `why`) and name the single boundary read.
    Note that an `expires` date in the past fails `tests/server/flags.spec.luau`.

12. **WHAT IS TESTABLE AND WHERE.** Which assertions are server specs, which are client specs
    (`tests/client/`, run in the player's client — `compass.spec.luau` is the model), and which are
    only Karen's eye. The task's gate is the **one-player** `test`; say plainly if any part of this
    design would drag a `TWO_PLAYER_PATHS` file in, because that changes the gate.

13. **THE DEVIATIONS, NAMED.** If this design contradicts anything in `docs/design/camera.md`,
    `drive-report.md`, `drive.md` or `beater-kit.md`, say so in its own section rather than leaving
    the older sentence standing (task 151 round 1's rule, and `reviews/task-154/RESULT.md`'s last
    note).

## 3. Numeric starting values (the Director's, and changeable by Karen)

From the note's target table. The design may adjust them with a reason; it must not leave them
unstated.

| Thing | Start value |
|---|---|
| Minimap diameter | 150 px, top-right |
| Minimap range | 300 studs radius (84 m at 0.28 m/stud; two `STAND_SPACING`s) |
| Full map coverage | the drive area: Forest Test `CENTRE.X ± HALF_SPAN` by beater start to past `EXIT_Z` |
| Marker redraw | ≤ 20 Hz |
| Player markers | ≤ 16 (`PROJECT_CONTEXT.md`: 10-16 players) |
| Mobile button | ≥ 44 px square |
| Scale bar | on the full map, in metres (`0.28` m/stud, the number `Horn.CONFIG`, `Report.CONFIG`, `Boar.CONFIG.SENSE` and `ForestTest.SPOOK` all publish) |

## 4. Out of scope for this design

- Boars or any animal on either map.
- Fog of war, discovered/undiscovered area, ping or waypoint placing.
- A rendered map image under the overlay (the note records the projection as the seam for it).
- Any change to the camera, the weapon, the drive or the boar.
- `TWO_PLAYER_PATHS` files. If the design needs one, it says so and that part becomes a later task.
