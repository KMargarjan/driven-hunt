# BRIEF for the Architect — Task 165, design `hud-clarity`

Written by the Builder, carrying the Director's dispatch of 2026-10-12. This overrides anything
older in `docs/`, `TASKS.md` or an earlier design (`docs/ARCHITECT_PROMPT.md`).

Read first: `docs/research/2026-10-12-hud-clarity.md` (this task's note, with the three sources, the
pattern adopted and the numeric targets).

## Karen's words, verbatim, 2026-10-12 ~10:40

> "we need to have better map or direction that people has to walk we need to improve design that it
> will be clear to understand what happening / could be buttons on the side for M - map ect"

She wants mobile in v1.

## What the design must contain

Four drawn things, and the owner boundary for each:

1. **ONE OBJECTIVE LINE**, always visible, by role × phase:
   - hunter: `Assigning` → "get to your stand", `Running` → "stay on your stand, boars are
     coming", `Scoring` → "drive over";
   - beater: `Assigning` → "wait for the horn", `Running` → "walk toward the road, push the
     boars", `Scoring` → "drive over";
   - `Waiting`, and no team: say so or draw nothing — the design decides which, and says which.
2. **A WORLD WAYPOINT** for the one place this player must go — a hunter's stand, a beater's point
   on the road straight down her push — showing the **distance**, with the **compass, the minimap
   and the full map agreeing with it**.
3. **A SIDE BUTTON RAIL** on the right edge, mobile-first, label plus key hint, every button bound
   to a real action. No dead buttons.
4. **THE FULL MAP (M) MADE CLEARER**: a legend, and *your* stand / *your* lane distinct from the
   others.

## Decisions already taken — do not re-open

These are the Director's dispatch and the Builder's research note. The design builds on them.

- **D1. One owner stays one owner.** `PlayerScripts.Hud` remains the only writer of everything
  drawn (`src/client/Hud/init.luau` header, `GAME_DESIGN.md` "UI / anything drawn"). The new work is
  **sibling modules inside it**, the shape `Compass` (125), `ReportPanel` (124) and `MapUi` (155)
  already have: `Hud.build` creates the frame, the module is the one writer of everything inside it.
  No second `ScreenGui`.
- **D2. No `BillboardGui` and no Instance in `Workspace`.** The waypoint is drawn in the Hud's own
  ScreenGui and **projected** from `Camera.viewCFrame()` (`Rig.appliedCFrame`, never
  `workspace.CurrentCamera.CFrame` — task 125 round 3) plus the camera's vertical FOV and
  `ViewportSize`: `f = (viewportY / 2) / tan(fov / 2)`, `px = f * x / -z`, the relation
  `Hud.reticleDegToPx` already uses. The projection is **pure and exported**, so it is a spec.
- **D3. No new remote and no new snapshot field.** The objective is a reading of
  `MatchSnapshot.phase` + `Player.Team` + `Match.secondsLeft()`, all already on the client. The
  target is read off the `MapGeometry` `MapUi` already builds (`geometry.road` polyline,
  `geometry.stands`). `CollectionService` is **refused** for the measured reason task 155 recorded
  (the DEV posts are invisible, unqueryable, streamed parts).
- **D4. The target is ONE evaluation with several drawers.** `Hud.start` resolves it and hands it
  to each drawer, exactly as it already does for `Compass.setBearing` / `MapUi.setPush` ("ONE RULE,
  ONE EVALUATION, TWO DRAWERS", task 153 round 2). Two readers of one fact that could be handed
  different teams is the bug that round found.
- **D5. A world that has stated no geometry gets NO waypoint**, not a guess and not a blank frame
  (`MapUi.geometryFor`'s rule; `docs/PROJECT_CONTEXT.md` "certified a blank screen twice"). Today
  that means the DEV world has a road but `#stands == 0`, so a DEV hunter gets no stand waypoint
  until task 155a publishes `Map.LINE`. **Say this out loud in the design**; do not invent a
  client-side post discovery to paper over it.
- **D6. Pinned, not hidden.** A target behind the player or off the edge is clamped to the edge and
  drawn **dimmer** (`Compass.CONFIG.PINNED_TRANSPARENCY`, `MapUi.CONFIG.PINNED_TRANSPARENCY`).
- **D7. Exactly one waypoint on screen.** theHunter's players: *"only showing the closest waypoint
  on the HUD to avoid visual overload"*.
- **D8. The rail owns the map button.** `MapUi`'s standalone touch button under the minimap becomes
  the rail's first button, because Roblox's own curriculum says to group one category in one place.
  The rail calls `MapUi.toggle()` — it does not reimplement it. `MapUi` keeps its `M` binding.
  The design says what happens to `MapUi.CONFIG.BUTTON_ENABLED`, `MapUi.buttonVisible` and
  `MapUi.start`'s `button` parameter, and `tests/client/map_ui.spec.luau` follows.
- **D9. Only real actions in the rail.** Candidates, and all are existing client functions or one
  line away from being one: `MAP` → `MapUi.toggle()`; `REPORT` (Tab) → `ReportPanel.toggle()`;
  `RELOAD` (R) and `AMMO` (X) → `src/client/Weapon/Input.luau`'s `onReload` / `onSelectAmmo`, which
  are **local today** and would get a public twin so the rail can call the same implementation the
  key calls (the Hud already reads `Weapon.Input` — it is handed to `ReportPanel` — and that
  direction is one-way). A weapon button must be **hidden when there is no weapon in hand**, or it
  is a dead button. The HORN is a Tool and is **not** in the rail unless the design finds a door
  onto it that is not a second implementation of what a blast is (`Weapon.Horn.blowTool` is the
  server's).
- **D10. The vertical band.** The objective line is the headline, so it takes the top line and the
  rest of the top band moves down by one band. Proposed, and the design may move a number with a
  reason: objective `y 8..40` (24 px text, centred) · drive bar `44..70` · tied banner `74..104` ·
  compass `108..134` · minimap top `140` · full map top `140` · the rail under the minimap on the
  right edge. Nothing may overlap anything at **400 x 800**, which is what task 155's
  `map_ui.spec` already asserts by rectangle intersection and what this task extends.
- **D11. Colours are the ones already published.** `Drive.CONFIG.DRIVER_COLOR` (blue) and
  `SHOOTER_COLOR` (orange) mirror the `Team.TeamColor`s `Match.Body` sets ("Bright blue" /
  "Bright orange"), and the direction mark is the orange-red the compass's DRIVE marker and the
  map's push arrow already share. **A conflict is named rather than settled here:** the dispatch
  says "orange = beater/road", and in this repo orange is the SHOOTERS' team colour and
  RGB(255, 112, 0) hunter orange is worn by **both** roles (`Match.Body` OUTFIT_COLOR). Re-assigning
  team colours would repaint the scoreboard, the bar and the map, so it is **Karen's decision** and
  is out of this task — like the hunter/beater vocabulary question still open as `TASKS.md` 158a.
- **D12. Every word the Hud draws is written down in one file.** New strings go in `Drive.CONFIG`
  beside `START_CARD_HUNTER_TIMER` and `TIED_TEXT`. **ASCII only** (the repo's rule for everything
  drawn): a hyphen, never an em dash.

## What the design must settle

1. **The module split.** One new module or two? The Builder's proposal: `src/client/Hud/Objective.luau`
   — the one writer of the objective line **and** the screen waypoint, plus the two pure functions
   (`text`, `targetFor`) and the pure projection — and `src/client/Hud/Rail.luau`, the one writer of
   the button rail. Rule on it; a different split needs a reason.
2. **Who reads what.** Confirm the dependency directions are one-way and name them:
   `Objective` ← (snapshot, team, secondsLeft, geometry, view) handed in by `Hud.start`;
   `MapUi.setTarget(...)` written **by the Hud**, never by `Objective`, so there is no cycle with
   `MapUi.geometry()`.
3. **Where "my stand" comes from** when a hunter has walked off it. Proposal: the **nearest** stand
   in `geometry.stands`, which is his because the drive put him on one and they are 150 studs apart
   (`ForestTest.STAND_SPACING`), so the answer only changes if he walks 75 studs. State the rule and
   its failure case rather than hiding it.
4. **The beater's road point.** Proposal: interpolate z on the `geometry.road` polyline at the
   player's own x. Say what happens past the ends of the polyline.
5. **The tick.** The waypoint tracks the VIEW, so once a frame (`RenderStepped`, the compass's
   rule). The map's target marker tracks POSITIONS, so it may ride `MapUi`'s existing 20 Hz. Confirm
   or correct.
6. **Visibility rules.** Which of these hide the objective line and the waypoint: the report panel
   open, the full map open, the sight picture in (the scope mask — see `Hud.renderScope` and
   `compassHiddenByScope`), the results table up, the start card up. The start card already says
   "GET TO YOUR STAND" for ten seconds; decide whether the objective line duplicates it or whether
   one of them stands down, and say which is the one writer of that decision.
7. **The full map's legend**: what is in it, and where, at 400 x 800 as well as 1080p.
8. **What a spec can assert** for each of the four things, given that no harness run reaches
   `Running` or `Scoring`.

## Out of scope — do not design it here

- Re-assigning team colours, or the hunter/beater vocabulary of the drive bar and the scoreboard
  (Karen's, `TASKS.md` 158a).
- `Map.LINE` / DEV stands (task 155a).
- A horn button, unless D9's condition is met.
- Any change to the camera, the weapon's behaviour, the match, the drive or the wire.
- Feel numbers Karen must judge (sizes, exact wording). The design states a first value and says it
  is hers to move.
