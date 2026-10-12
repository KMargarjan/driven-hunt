# HUD clarity: the objective line, the waypoint and the button rail

Architect, task 165. Written to `reviews/task-165/BRIEF.md` (the Director's dispatch of 2026-10-12,
carried by the Builder) and `docs/research/2026-10-12-hud-clarity.md`. The brief overrides anything
older; where this design departs from it, the departure is named in section 1.2 and nowhere else.

Karen, 2026-10-12 ~10:40, verbatim:

> "we need to have better map or direction that people has to walk we need to improve design that it
> will be clear to understand what happening / could be buttons on the side for M - map ect"

---

## 1. Two corrections to the brief, and one deviation

These come first because the test plan and one string table rest on them.

### 1.1 Corrections (facts, with evidence)

**C1. A one-player harness run DOES reach `Running`.** The brief's question 8 asks what a spec can
assert "given that no harness run reaches `Running` or `Scoring`". That is true of `Scoring` and
false of `Running`:

- `Match.CONFIG.MIN_PLAYERS = 1` (`src/server/Match/init.luau`), so a solo player starts a drive.
- `Assigning` lasts `Phase.intermissionSeconds(config)` = `Match.CONFIG.INTERMISSION_SECONDS` = 15 s
  (`src/server/Match/Phase.luau`, `enterAssigning`).
- `Running` is reached next and lasts `DRIVE_SECONDS` = 600 s, so `Scoring` is NOT reached by the
  clock.
- `tests/client/zz_tie_to_a_tree.spec.luau` asserts `Match.isTied()` becomes true, and
  `src/server/Match/init.luau` states *"ties only exist in `Running`"* (and `Penalty`'s header says
  the owner answers *"is the phase Running"*). That spec is in the gate, so the gate reaches
  `Running`.
- The SERVER suite also drives the phase through `Scoring` deliberately:
  `tests/server/zz_drive_boundary.spec.luau` calls
  `Match.advanceForTests(Match.CONFIG.DRIVE_SECONDS + 1)` and then
  `Match.advanceForTests(Match.CONFIG.SCORE_SECONDS + 1)`.

What follows for this design: a client spec still cannot *choose* its phase (the two runners are not
ordered against each other), so the six role x phase strings are asserted **purely**. But a client
spec CAN assert, in whatever phase it finds, that **what is drawn equals what the rule says** —
`drawn == Objective.text(Match.phase(), Match.myTeam())` — which is a live check that holds in every
phase and catches a renderer that stopped following the rule. Section 10 uses it. The claim in
`GAME_DESIGN.md`'s UI row and in `src/client/Hud/init.luau`'s header ("a drive is 600 seconds, so no
harness run reaches the `Scoring` phase") stays correct as written: it is about `Scoring`.

**C2. The tied banner is 30 px tall, not 24.** `Compass.CONFIG.TOP`'s comment says the banner
*"sits at `TIED_TOP_OFFSET` = 44 and is 24 tall, so it owns 44..68"*; `Hud.build` creates it with
`tied.Size = UDim2.fromOffset(620, 30)`. The band in section 3 uses 30. Nothing today is wrong
because of it (76 clears 74 either way), but the new band has 4 px of gap and a stale 24 would eat it.

### 1.2 One named deviation from the brief: D12

**D12 says every new string goes in `Drive.CONFIG`. This design puts the objective's and the rail's
words in `Objective.CONFIG` and `Rail.CONFIG` instead.** Reasons:

1. The repo's actual rule is one word table per drawer, not one per repo:
   `Compass.CONFIG.DRIVE_LABEL`, `MapUi.CONFIG` (`"MAP"`, the `"%d m"` scale label, the `"N"`),
   `Report.CONFIG` and `Drive.CONFIG` are four such tables already. `Drive.CONFIG` is the DRIVE's
   words.
2. `src/shared/Drive/` is in **`TWO_PLAYER_PATHS`** (`tools/agents.py`), so a word in `Drive.CONFIG`
   cannot be retuned without `python tools/studio_mcp.py test2` and a human click. Karen is going to
   move these six sentences; `src/client/Hud/` resolves to the `hud` scope and needs the one-player
   line only.
3. It changes nothing about this task's own gate, which needs `test2` anyway (section 10.5), because
   the band offsets in section 3 ARE `Drive.CONFIG`'s.

The Director can reverse this with one line; it is not a blocking question, and the rest of the
design is identical either way.

---

## 2. What the system must do, and what it must not do

### 2.1 Must do

1. **One objective line**, one ASCII sentence, always on the top line, telling this player what the
   game wants of them right now, by role x phase. Six states plus `Waiting` plus "no team".
2. **One world waypoint** — exactly one, never a set — for the one place this player must be, drawn
   in the Hud's own ScreenGui, projected from the view, carrying a **distance in metres**, and
   **pinned dimmer** to the screen edge rather than hidden when it is off screen or behind.
3. **Agreement**: the compass marker, the minimap and the full map show the SAME target, from ONE
   evaluation.
4. **A button rail** on the right edge, mobile-first, every button a second door onto a function that
   already exists. No dead buttons; a weapon button disappears when there is no weapon in hand.
5. **A legend on the full map**, and *your* place distinct from everyone else's.
6. Readable at **400 x 800** and clear of the two corners Roblox reserves for the thumbstick and the
   jump button.

### 2.2 Must not do

- **Must not decide anything.** It reads the phase, the team, the clock and the world's geometry and
  draws. It fires no remote, writes no camera, moves no character, and decides no rule.
- **Must not create an Instance outside `PlayerGui.HunterHud`.** No `BillboardGui`, no `Adornee`, no
  part in `Workspace` (D2).
- **Must not add a remote or a snapshot field** (D3). The objective is a reading of
  `MatchSnapshot.phase` + `Player.Team` + `Match.secondsLeft()`; the target is a reading of the
  `MapGeometry` `MapUi` already builds.
- **Must not query `CollectionService` for posts** (D3, and the measured reason
  `MapUi.geometryFromMap` records: the DEV posts are `Transparency = 1`, `CanQuery = false` parts in
  a place with `Map.STREAMING.enabled = true` and a 1,024-stud target radius).
- **Must not derive the view heading itself.** `Camera.viewHeadingDeg` and `Camera.viewCFrame` are
  the one source (`src/client/Camera/init.luau`; task 125 round 3's two measured wrong answers are in
  `Compass.headingFrom`'s header).
- **Must not invent a stand for a world that has not stated one** (D5), and must not re-assign team
  colours or change the hunter/beater vocabulary of the bar and the board (D11, `TASKS.md` 158a).
- **Must not guess a position.** No last-known location, no stale dot — `MapUi.pointsFor`'s rule.

---

## 3. The vertical band, and the rectangles

D10's numbers are adopted unchanged. Everything in the top band moves down by one band so the
objective line takes the top line.

| Element | Today | New | Height | Constant that moves |
|---|---|---|---|---|
| **Objective line** | — | **8..40** | 32 | `Objective.CONFIG.TOP = 8`, `HEIGHT = 32` (new) |
| Drive bar | 8..34 | **44..70** | 26 | `Drive.CONFIG.BAR_TOP_OFFSET` 8 -> 44 |
| Tied banner | 44..74 | **74..104** | 30 | `Drive.CONFIG.TIED_TOP_OFFSET` 44 -> 74 |
| Compass strip | 76..102 | **108..134** | 26 | `Compass.CONFIG.TOP` 76 -> 108 |
| Minimap top | 108 | **140** | diameter | `MapUi.CONFIG.MINIMAP_TOP` 108 -> 140 |
| Full map top | 108 | **140** | laid out | `MapUi.CONFIG.FULL_TOP` 108 -> 140 |
| **Button rail** | — | **140 + diameter + 8**, right edge | 216 | `Rail.CONFIG` (new) |
| Ammo readout | bottom right, H-40..H-16 | unchanged | 24 | — |
| Event feed | bottom left | unchanged | 100 | — |

Four one-line constant edits in three files, plus two new CONFIG blocks. Every gap is 4 px or more.

**The rail's column, and the hole it closes.** At 1080p the rail runs y 298..514 at x W-60..W-12
(margin `MapUi.CONFIG.MINIMAP_MARGIN` = 12, button 48). At 400 x 800 the minimap's rendered diameter
is `MapUi.diameterFor(400, 800)` = 96, so the rail runs y 244..460 at x 340..388. **The full map
panel is centred and would run under it**: at 400 px the panel's own room is
`viewportX - 2 * FULL_SIDE_INSET` = 352 px, spanning x 24..376, which crosses the rail. The minimap
never had this problem because `MapUi.minimapVisible` hides it while the map is open; the rail cannot
hide, because on a phone it is the only way to CLOSE the map.

So `layoutFor` reserves the rail's column:

```
RAIL_COLUMN_PX = Rail.CONFIG.BUTTON_PX + MapUi.CONFIG.MINIMAP_MARGIN + 8   -- 68
roomX  = viewport.X - MapUi.CONFIG.FULL_SIDE_INSET - RAIL_COLUMN_PX
full.Position = UDim2.new(0.5, -RAIL_COLUMN_PX / 2, 0, MapUi.CONFIG.FULL_TOP)
```

One number, written in the one function that already writes both `UIScale`s
(`MapUi.luau`, `layoutFor`). Section 10.2 asserts the two rectangles are disjoint arithmetically at
several viewports.

**Every rectangle is produced by a pure exported function of the viewport.** `Rail.rect(viewport)`,
`MapUi.fullMapRect(viewport)`, `MapUi.minimapRect(viewport)`, `Objective.lineRect(viewport)`. The
existing `map_ui.spec` overlap case measures `AbsolutePosition` at whatever size the Studio window
happens to be; that case stays and is worth keeping, but it cannot answer for 400 x 800, because a
scale-anchored `Position` resolves against the real screen and `MapUi.applyLayout(Vector2)` only pins
MapUi's own layout maths. The arithmetic can answer for any viewport, so it is what the phone claim
rests on.

**ZIndex.** All new nodes are direct children of the one `ScreenGui`, so absolute numbers order them
under either `ZIndexBehavior` (`Hud.build`'s `panelLabel` comment states the same).

| Node | ZIndex | Why |
|---|---|---|
| Waypoint chevron + its label | **5** | over the feed and the bar (1), UNDER the compass and the map (6-9): a mark that crosses the screen must pass BEHIND the furniture, not scribble on it |
| Objective line | **6** | the compass's band; it is top-band furniture |
| Rail | **16** = `Report.CONFIG.PANEL_Z_INDEX + 1` | **the only node in this Hud that is over the centred panels, and it is deliberate**: on a touch device the REPORT button is the only way to close the report panel. Everything else about the panels is unchanged |

---

## 4. Owners and files

One writer each, named (rule 3). `PlayerScripts.Hud` remains the only writer of everything drawn
(D1): the new modules are siblings INSIDE it, the shape `Compass` (125), `ReportPanel` (124) and
`MapUi` (155) already have. **No second `ScreenGui`.**

| Thing drawn | The one writer | File |
|---|---|---|
| The `ScreenGui` and every frame in it (creation, size, position, `ZIndex`) | `PlayerScripts.Hud` (`Hud.build`) | `src/client/Hud/init.luau` |
| **The objective line's text and `Visible`; the waypoint chevron, its label and its `Visible`** | **`Hud.Objective`** | **`src/client/Hud/Objective.luau`** (new) |
| **The rail's buttons: text, `Visible`, `Activated`** | **`Hud.Rail`** | **`src/client/Hud/Rail.luau`** (new) |
| Everything inside the minimap and the full map, including their `Visible` and **the new target marker and the legend** | `Hud.MapUi` | `src/client/Hud/MapUi.luau` |
| Everything inside the compass strip | `Hud.Compass` | `src/client/Hud/Compass.luau` |
| **The one evaluation of "where must I go", and the one call to each drawer** | `Hud` (`Hud.renderObjective`) | `src/client/Hud/init.luau` |
| `DrivenHunt.Weapon.*` actions, `FireRequest`/`ActionRequest` | `PlayerScripts.Weapon.Input` | `src/client/Weapon/Input.luau` |

### 4.1 Ruling on the module split (brief question 1)

**The Builder's proposal is adopted: two modules.**

- `Objective.luau` owns **both** the line and the waypoint. They are not two things: they are one
  answer ("what must I do, and where") rendered twice. Splitting them would create two readers of one
  target, which is exactly the failure D4 exists to prevent (task 153 round 2: *"a marker that moved
  without its label told a beater the drive was south"*).
- `Rail.luau` owns the buttons. It is a different question (what can my thumb reach) with different
  inputs (touch, whether a weapon is in hand) and no shared state with the objective.
- The **projection** lives in `Objective` because `Objective` is its only caller. It is the client's
  one world-to-screen projection; if a second caller ever appears it moves up to `init.luau` beside
  `Hud.reticleDegToPx`, which is the one angle-to-pixel conversion for the same reason.
- Neither new module may `require` `script.Parent` — `MapUi.setPush`'s header records why
  (`MapUi.luau` is a sibling of `init.luau`, so requiring it would be a cycle). They take their
  collaborators at `start`, the `MapUi.start` / `ReportPanel.start` shape.

### 4.2 Ruling on the dependency directions (brief question 2)

All one-way, and the Hud is the only thing that knows more than one of them.

```
          Hud.start / Hud.renderObjective          <- the one evaluation
                 |          |           |
      setLine/   |          | setTarget |  setBearing
      setTarget  v          v           v
            Objective     MapUi      Compass        <- three drawers, none calls another

  Hud reads:  Match (phase, team, secondsLeft)   -- one-way, Match has no Hud reference
              MapUi.geometry()                   -- a getter; MapUi never calls back
              Camera.viewCFrame / viewHeadingDeg / getMode / getBlend / scope
              Weapon.get() (is a gun in hand), Weapon.Input (the rail's two actions)
              ReportPanel.isOpen()
              Workspace.CurrentCamera.FieldOfView / .ViewportSize   (read, never written)
```

`MapUi.setTarget` is written **by the Hud**, never by `Objective` — so there is no cycle with
`MapUi.geometry()`, which the Hud is the one caller of.

**Why `Camera.viewCFrame()` for the orientation but `CurrentCamera.FieldOfView` for the angle.**
`Rig.apply` counts FOREIGN WRITES to `CurrentCamera.CFrame` and has warned about one since task 123,
so the engine's CFrame is not reliably the view and `Camera.viewCFrame()` (`Rig.appliedCFrame`) is
(task 125 round 3). There is no `Rig.appliedFov()` accessor, and adding one is a camera change, which
the brief puts out of scope. The field of view is read off the property — which is exactly what
`Hud.renderScope` already does for the mask (`local liveFov = camera.FieldOfView`, with its own
comment saying why the frame's own fov and not the weapon's target) and what `Hud.layoutScope` uses.
It is a READ of a property whose one writer is `Rig.apply`. Stated here so nobody "fixes" the
asymmetry by reading the CFrame off the same object.

---

## 5. `Hud.Objective` — the public interface

`--!strict`. Pure functions first; they take everything and read nothing.

```lua
export type Target = {
    point: Vector3,       -- where, in world studs
    word: string,         -- "STAND" | "LINE" | "ROAD"  -- what it is, in one ASCII word
    kind: string,         -- "stand" | "line" | "road"  -- for a spec and for the colour
}

-- ---- pure ----------------------------------------------------------------

-- The one sentence. ASCII. Empty string means draw nothing.
Objective.text(phase: string?, team: string?): string

-- The one place this player must be, or nil. Pure over geometry it did not fetch.
Objective.targetFor(
    team: string?, phase: string?, geometry: MapUi.MapGeometry?, me: Vector3?
): Target?

-- How far, in studs, from the player (not from the camera). nil target -> nil.
Objective.distanceStuds(target: Target?, me: Vector3?): number?

-- Has the player arrived? Hysteresis, so a hunter shuffling on his stand does not flicker.
Objective.arrived(distanceStuds: number?, wasArrived: boolean): boolean

-- World point -> pixels from the screen centre, and whether it is really on screen.
Objective.project(
    point: Vector3, view: CFrame, fovDeg: number, viewport: Vector2
): (number, number, boolean)

-- Is the line drawn? Is the chevron drawn? Two predicates, two questions.
Objective.lineVisible(phase: string?, team: string?, reportOpen: boolean,
                      mapOpen: boolean, scoped: boolean, startCardUp: boolean): boolean
Objective.markVisible(target: Target?, reportOpen: boolean, mapOpen: boolean,
                      scoped: boolean, hasView: boolean): boolean

-- ---- state: this module is the one writer of what is inside its two nodes ----

Objective.start(nodes: { line: TextLabel, mark: Frame, markLabel: TextLabel }): ()
Objective.render(state: {                    -- called once a frame by the Hud
    text: string, target: Target?, distanceStuds: number?,
    view: CFrame?, fovDeg: number, viewport: Vector2,
    lineVisible: boolean, markVisible: boolean,
}): ()
Objective.setSuppressed(on: boolean): ()     -- the sight picture is in; the `MapUi.setSuppressed` shape

-- ---- read-only, for a spec ----
Objective.lineText(): string
Objective.markOffsetPx(): (number, number)?  -- nil when the chevron is not drawn
Objective.isMarkPinned(): boolean
Objective.lineRect(viewport: Vector2): (number, number, number, number)
Objective.textSizeFor(viewportX: number): number
Objective.stats(): { renders: number, pinned: number, noView: number }
```

### 5.1 The six states (brief requirement 1; `Objective.CONFIG.TEXT`)

ASCII, hyphen never an em dash. First values; the wording is Karen's to move (section 13).

| team | phase | text |
|---|---|---|
| Shooters (hunter) | `Assigning` | `get to your stand` |
| Shooters | `Running` | `stay on your stand, boars coming` |
| Shooters | `Scoring` | `drive over` |
| Drivers (beater) | `Assigning` | `wait for the horn` |
| Drivers | `Running` | `walk to the road, push the boars` |
| Drivers | `Scoring` | `drive over` |
| either | `Waiting` | `waiting for the drive to start` |
| **no team**, any phase | — | **`""` — nothing is drawn** |

**The `Waiting` ruling (the brief left it open):** with a team, it SAYS so, in one short sentence
with no reason attached — the drive bar already carries the reason
(`"WAITING " .. table.concat(snapshot.waitingFor, ",")`, `renderDrive`), and two renderings of one
reason is the duplication this task exists to remove. **With no team, nothing is drawn**: a player
with no team has no objective, and a sentence would be an instruction nobody gave. The empty string
is the signal, and `Hud.roleWord` already answers `""` for the same case.

The text never carries the distance. The distance belongs to the chevron, which is where the eye
already is when it is asking "how far".

**Length is a numeric target, measured by the engine, not by a font-width guess.** Longest string is
32 characters. `Objective.textSizeFor(viewportX)` returns `24` at `viewportX >= 700` and `18` below
(one break point). The spec sets each string into the real label at a 400 px wide frame and asserts
`TextLabel.TextFits` (section 10.1) — the engine measures it, so no assumption about `Enum.Font.Code`
is being trusted.

### 5.2 The target (brief questions 3 and 4)

```
targetFor(team, phase, geometry, me):
  if phase ~= "Assigning" and phase ~= "Running" then return nil end   -- no walking in Waiting/Scoring
  if geometry == nil or me == nil then return nil end                  -- D5: no geometry, no waypoint
  if team == "Shooters" then
      if #geometry.stands > 0 then
          return { point = nearest(geometry.stands, me), word = "STAND", kind = "stand" }
      end
      return { point = onRoadAtX(geometry.road, me.X), word = "LINE", kind = "line" }
  elseif team == "Drivers" then
      return { point = onRoadAtX(geometry.road, me.X), word = "ROAD", kind = "road" }
  end
  return nil                                                          -- no team, no objective
```

**"My stand" is the NEAREST stand, and the failure case is stated rather than hidden** (brief
question 3). The drive puts a hunter on a stand (`Match.Body.place` / `Body.placementFor`, and in the
Forest Test `ForestTest.PICK`), and `ForestTest.STAND_SPACING` is 150 studs, so the nearest stand is
his until he walks 75 studs along the line — at which point the waypoint silently becomes his
neighbour's. There is no way to do better without the drive publishing the assigned stand index,
which is a new snapshot field and is refused by D3. **Queue it**: "the snapshot carries the hunter's
stand index; the waypoint reads it instead of guessing" (`TASKS.md`, before release).

**The hunter with no stands falls back to the road, and that is not a guess.** `Map.ROAD`'s own
comment says *"The road's centreline IS the drive line -- there is no second concept"*, and
`MapUi.CONFIG.ROAD_COLOR`'s says *"THE ROAD is the hunters' line"*. In the DEV world
`MapUi.geometryFromMap` returns `stands = {}` deliberately, so without this clause a DEV hunter would
get nothing — and `Match.CONFIG.ODD_PLAYER_TEAM = "Shooters"` means **a solo player in DEV IS a
hunter**, which is how Karen plays. Without the fallback this entire feature would be inert in the
world she tests in. The fallback states something the world HAS stated (the line) and declines to
state what it has not (which post), which is exactly `MapUi.geometryFor`'s rule, and the word changes
from `STAND` to `LINE` so the screen never claims more than the world said. See section 12.1.

**The road point (brief question 4): interpolate z at the player's own x.** Straight down her push,
so she walks forward into the line instead of diagonally to the mathematically nearest point — on a
sine of amplitude 30 over 1,600 studs (`ForestTest.ROAD`) the two differ by under a stud anyway, and
"walk straight ahead" is the instruction. **Past the ends of the polyline, x is clamped to the
polyline's x range**, so the target becomes the end of the road: a beater who has walked off the end
of the world is sent back to the line rather than to a point that does not exist. The DEV road is two
points (`Map.ROAD.from = -900`, `to = 900`, `z = -700`) and the same interpolation handles it with no
branch — `MapUi.geometryFromMap`'s own *"A STRAIGHT ROAD IS TWO POINTS"*.

**Arrival, with hysteresis.** `ARRIVED_IN_STUDS = 12`, `ARRIVED_OUT_STUDS = 18`.
`ForestTest.PICK.leashStuds` is 6, so a hunter may legally move 6 studs on his stand; 12 is twice
that and 18 gives a 6-stud dead band, so standing on the stand cannot flicker the chevron on and off.
**Arrived means: no chevron, no compass takeover, and the line reads the arrived sentence** — which
is already what the table says ("stay on your stand" IS the arrived wording). This is what stops a
hunter standing on his own stand from being given a wobbling 3-metre arrow, and it is what lets the
compass go back to saying where the drive comes FROM, which is what he actually wants there.

### 5.3 The projection (D2)

Roblox's `FieldOfView` is the VERTICAL angle — the fact `Hud.reticleDegToPx` already rests on — so:

```
local p = view:PointToObjectSpace(point)         -- x right, y up, -z forward
local f = (viewport.Y / 2) / math.tan(math.rad(fovDeg) / 2)
if p.Z < -1e-3 then                              -- in front
    sx, sy = f * p.X / -p.Z, -f * p.Y / -p.Z     -- screen y grows downward
else                                             -- behind: a direction, not a point
    sx, sy = (if p.X >= 0 then 1 else -1) * math.huge, 0
end
```

then clamp per axis to the insets and report `onScreen` only if nothing was clamped —
`MapUi.project`'s rect rule, cited rather than re-invented, *"because on a rectangle that is what
pinning means"*.

**Behind the player is handled as a direction, not a trig clamp.** Source B clamps with trigonometry;
this is the simplified version and the simplification is named: a point behind the camera has no
honest vertical position on screen, so it pins to the left or right edge at mid height, which answers
"it is behind you, to your left" and claims nothing else. `p.Z >= 0` with `p.X == 0` exactly (dead
behind) pins right; arbitrary, deterministic, and asserted so it cannot drift.

**Insets.** Left/top/bottom 56 px (D10's number). **Right 68 px**, because the rail's column is 68
wide (section 3) and a chevron pinned at 56 would sit under the RELOAD button.

**No view, no chevron.** `Camera.viewCFrame()` is nil before the camera system's first applied frame;
the line still draws and the chevron does not. `Compass.headingFrom` keeps its last heading in that
case because a strip that lags by three frames is not a strip that lies — a MARK is different: a
chevron drawn from a stale camera is in the wrong place on the screen, which is a lie in the shape of
a fact. Counted as `stats().noView`.

### 5.4 Visibility (brief question 6)

Two predicates, two questions. The rule the previous project died of is *"one predicate answered two
unrelated questions"*.

| Condition | Line | Chevron |
|---|---|---|
| Report panel open (`ReportPanel.isOpen()`) | hidden | hidden |
| Full map open (`MapUi.isOpen()`) | hidden | hidden — the map shows the target better |
| Sight picture in (`Hud.scopeVisible`) | hidden | hidden |
| Start card up (`Hud.startCardVisible`) | **hidden** | **shown** |
| Results table up (`Scoring`) | shown | no target in `Scoring`, so nothing |
| No team | hidden (empty text) | nothing |

**The start-card ruling (the brief asked who stands down).** In `Assigning` the card's timer line
already reads `GET TO YOUR STAND  7` (`Drive.CONFIG.START_CARD_HUNTER_TIMER`,
`Hud.startCardTimerFor`). Two renderings of one instruction, 140 px apart, for fifteen seconds. **The
objective line stands down while the card is up; the WAYPOINT does not.** The card says *what*, the
waypoint says *where*, and the moment the card says "get to your stand" is exactly the moment the
player most needs the arrow. When the card goes at GO, the line takes over with no gap.

**The one writer of that decision** is `Hud.startCardVisible(snapshot, reportOpen)`, which already
exists and is already the card's own predicate. The Hud calls it ONCE per pass and hands the boolean
to `Hud.renderStartCard` and to `Objective.lineVisible`, so the two can never disagree about whether
a card is up. That is `renderDrive`'s existing shape — *"three things that could disagree about which
phase it is, drawn from one read"*.

**Suppression uses the request pattern, not a second writer.** `Hud.renderScope` already computes
`scoped` once a frame and states a need to the map (`MapUi.setSuppressed(scoped)`) — this repo's own
`Camera.Cursor.requestFree` shape, borrowed by `Input.requestHold`. `Objective.setSuppressed(scoped)`
and `Rail.setSuppressed(scoped)` go on the same line. **The compass's two-writer arrangement
(`compassHiddenByScope`) is NOT copied**; `MapUi.applyVisibility`'s header already says why.

---

## 6. `Hud.Rail` — the public interface

```lua
export type Button = {
    id: string,        -- "MAP" | "REPORT" | "RELOAD" | "AMMO"
    label: string,     -- what is drawn, ASCII, <= 6 characters
    key: string,       -- the key hint drawn under it: "M", "TAB", "R", "X"
    needsWeapon: boolean,
}

Rail.CONFIG = { BUTTON_PX = 48, GAP = 8, MARGIN = 12, Z_INDEX = 16,
                SHOW_ON_DESKTOP = true, LABEL_SIZE = 11, KEY_SIZE = 9 }
Rail.BUTTONS: { Button }                                  -- the order they are drawn in

-- pure
Rail.visible(touchEnabled: boolean): boolean
Rail.buttonVisible(button: Button, hasWeapon: boolean): boolean
Rail.topFor(minimapDiameterPx: number): number            -- MINIMAP_TOP + diameter + GAP
Rail.rect(viewport: Vector2): (number, number, number, number)

-- state: this module is the one writer of what is inside the rail frame
Rail.start(frame: Frame, collaborators: { Map: any, Report: any, Input: any }): ()
Rail.press(id: string): boolean        -- THE NAMED HANDLER each button's Activated calls
Rail.setWeapon(hasWeapon: boolean): () -- told by the Hud on Weapon.Changed; never read from here
Rail.setSuppressed(on: boolean): ()
Rail.buttonIds(): { string }           -- what is actually on screen now, for a spec
Rail.stats(): { presses: number, byId: { [string]: number } }
```

### 6.1 The buttons (D9: only real actions)

| id | label | key | calls | hidden when |
|---|---|---|---|---|
| MAP | `MAP` | M | `MapUi.toggle()` | never (it is the only way to close the map on a phone) |
| REPORT | `REPORT` | TAB | `ReportPanel.toggle()` | never (same reason) |
| RELOAD | `RELOAD` | R | `Weapon.Input.reload()` | no weapon in hand |
| AMMO | `AMMO` | X | `Weapon.Input.selectAmmo()` | no weapon in hand |

**No horn button.** D9's condition is not met: `Weapon.Horn.blowTool` is the SERVER's, there is no
client-side function to call, and a button would need a new remote — refused by D3. Queue it:
"a beater's horn button needs a client request path; design it with the remote, not around it".

**`Rail.press(id)` is a named public function and that is the point.** It is the
`Hud.onHitMarker` precedent, stated in that function's own header: *"a named function rather than an
inline closure, so a client spec can drive exactly the code path the wire drives"*. Each button is
`button.Activated:Connect(function() Rail.press(id) end)` and nothing else. A spec cannot fire
`Activated` and the harness cannot synthesise a tap (section 10.4), so `Rail.press` is the seam that
makes the rail testable at all.

**`hasWeapon` is told, not read.** `Weapon.get().equipped` is the Hud's existing read
(`Hud.render`: `readout.Text = if state and state.equipped then ...`). The Hud hands the boolean to
`Rail.setWeapon` on `Weapon.Changed`, so there is one reader of the weapon state in the Hud and the
rail learns nothing about weapons. A button whose action cannot run is not drawn — D9's "no dead
buttons", enforced by a pure predicate rather than by a comment.

### 6.2 Desktop or touch only

`Rail.visible(touchEnabled)` returns `touchEnabled or Rail.CONFIG.SHOW_ON_DESKTOP`, and
`SHOW_ON_DESKTOP` ships **true**. Three reasons: Karen asked for the buttons and plays on a PC, so a
touch-only rail is a feature she can never see; the key hints make it a legend for the keyboard as
well as a thumb target; and a `TextButton` is clickable with a real mouse, which is the only route to
any live evidence at all. It is one boolean for Karen to turn off (section 13).

`MapUi.buttonVisible` had the opposite rule (`touchEnabled and BUTTON_ENABLED`) and is removed with
the rest of that button — section 7.2.

---

## 7. What changes in the existing owners

Each change names the one writer it leaves behind.

### 7.1 `src/client/Hud/init.luau`

1. `build()` creates four new nodes, empty, and writes nothing inside them after that: the
   `ObjectiveLine` `TextLabel`, the `Waypoint` `Frame` with its `WaypointLabel`, the `Rail` `Frame`,
   and the `MapLegend` `Frame`. `Hud.objectiveLine()`, `Hud.waypoint()`, `Hud.rail()` and
   `Hud.mapLegend()` return them, the `Hud.compass()` / `Hud.minimap()` shape, so a spec never walks
   `PlayerGui` by name.
2. `Hud.start` calls `Objective.start(...)` and `Rail.start(...)` after `MapUi.start`, and hands
   `MapUi`, `ReportPanel` and `Weapon.Input` to the rail. The legend frame is handed to `MapUi.start`
   with the other two, because the legend is the map's.
3. **One new `RenderStepped` connection, outside every `if`**, calling `Hud.renderObjective`. It is
   its own connection and not the compass's, for the reason task 141 already wrote down: *"a scope
   that only worked in a world with a compass strip is a bug waiting for the next place"*.
4. **`Hud.renderObjective(CameraSystem)` is the ONE evaluation** (D4), and it is the only caller of
   `Compass.setBearing` and `MapUi.setPush` after boot:

```lua
function Hud.renderObjective(CameraSystem)
    local snapshot = matchSystem and matchSystem.get()
    local phase    = snapshot and snapshot.phase
    local team     = matchSystem and matchSystem.myTeam() or localTeamName()
    local me       = Hud.localPosition()                       -- character PrimaryPart, or nil
    local target   = Objective.targetFor(team, phase, MapUi.geometry(), me)
    local far      = Objective.distanceStuds(target, me)
    arrivedState   = Objective.arrived(far, arrivedState)
    if arrivedState then target = nil end                      -- arrived: no waypoint, no takeover
    -- ONE target, THREE drawers:
    Objective.render({ text = Objective.text(phase, team), target = target, ... })
    MapUi.setTarget(target and target.point, target and target.word)
    local deg, word = Hud.markerFor(target, me, worldBearing, worldBearingLabel)
    if compassFrame then Compass.setBearing(deg, word) end
    MapUi.setPush(deg, word)
end
```

5. **`Hud.markerFor(target, me, worldBearingDeg, worldLabel)` is new, pure and exported**: the
   target's own bearing and word when there is a live target, otherwise the world's
   (`Hud.driveBearing`'s answer, unchanged). It is what makes the compass, the minimap and the full
   map AGREE with the waypoint — the brief's requirement 2 — while keeping **exactly one marker on
   the strip** (D7). A hunter standing on his stand has no target, so the compass goes back to
   pointing at the drive, which is what he is watching.
6. **The team closure stops writing the drawers.** Today
   `Hud.start`'s `whenReady(ReplicatedStorage, "ForestTest", ...)` closure calls `Compass.setBearing`
   and `MapUi.setPush` directly; it now writes only the two locals `bearing` / `bearingLabel` that
   already exist, and the per-frame pass is the one writer of both drawers. This REMOVES a
   two-writer arrangement rather than adding one. `Compass.start(frame, bearing, bearingLabel)` at
   boot is unchanged.
7. `Hud.renderScope` gains two lines beside the existing `MapUi.setSuppressed(scoped)`:
   `Objective.setSuppressed(scoped)` and `Rail.setSuppressed(scoped)`.
8. `renderDrive` hands its already-computed `Hud.startCardVisible(...)` boolean to the objective's
   visibility (section 5.4), so the card and the line read one answer.
9. `Hud.localPosition(): Vector3?` is new and trivial: the local character's `PrimaryPart.Position`
   or nil. `MapUi`'s private `roster()` reads the same engine state for its own markers; two readers
   of the engine, no writer of anything, and neither derives state from the other.

### 7.2 `src/client/Hud/MapUi.luau`

1. **The standalone map button goes** (D8). `Hud.build`'s `MapButton` node, the `button` field of
   `MapUi.start`, `MapUi.CONFIG.BUTTON_ENABLED`, `MapUi.buttonVisible`, `Hud.mapButton()` and the
   button's two lines in `layoutFor` are **removed**, and the removed block is archived under
   `backups/` with a note (rule 7). The rail's MAP button is the rail's, and it calls `MapUi.toggle()`
   — it does not reimplement it. `MapUi` keeps its `M` binding, `TOGGLE`, `stats().keyToggles` and
   everything else about the toggle. The alternative — leaving `buttonVisible` behind with no caller
   — is dead code pretending to be an owner, which is worse. `tests/client/map_ui.spec.luau` drops
   the two cases that read `Hud.mapButton()` (the visibility case and the button half of the overlap
   case); the rail's own cases replace them.
2. **`MapUi.setTarget(point: Vector2?, word: string?)`** is new: a setter, the `setPush` shape, that
   stores and draws nothing itself. `buildDrawer` gains one node per drawer — a target mark in
   `MapUi.COLORS.arrow`, projected through the drawer's own view and **pinned like any marker**
   (`PINNED_TRANSPARENCY`), with the word beside it. One per drawer, and exactly one drawer is live
   per tick (`renderDrawer` is called only for a visible gate), so there is one target on screen.
3. **The legend** (section 8) is filled here, into the frame `Hud.build` creates:
   `MapUi.legendRows()` (pure, the six rows) and `MapUi.legendVisible(scale)` (pure).
4. `MINIMAP_TOP` and `FULL_TOP` 108 -> 140; `layoutFor` reserves the rail's column (section 3);
   `MapUi.fullMapRect` and `MapUi.minimapRect` are new pure exports.

### 7.3 `src/client/Hud/Compass.luau`

`CONFIG.TOP` 76 -> 108, and the comment that explains the band is rewritten to the new one (and to
the banner's real 30 px, correction C2). Nothing else: `setBearing` already takes a label, already
treats `nil` as "not stated", and is already called by exactly one place in the Hud.

### 7.4 `src/client/Weapon/Input.luau`

Two public twins, and the guard moves INTO them so there is one site for the rule:

```lua
function Input.reload(): boolean
    if Input.isHeld() then return false end
    remotes().ActionRequest:FireServer("Reload")
    return true
end
function Input.selectAmmo(): boolean
    if Input.isHeld() then return false end
    ... the existing body of onSelectAmmo ...
    return true
end
```

and `onReload` / `onSelectAmmo` become `if state == Begin then Input.reload() end; return Pass`. The
key and the button then run the same implementation, including the hold — so a player cannot reload
by tapping a button through an open report panel, which is exactly what `Input.requestHold`'s header
says the hold is for. `Input` remains the only firer of `ActionRequest`; the Hud reads
`Weapon.Input` and is never called by it, as it already does for `ReportPanel`.

This puts `src/client/Weapon/` in the change, which resolves to the `weapon` scope in
`BLAST_RADIUS` — see section 10.5.

### 7.5 `src/shared/Drive/init.luau`

`BAR_TOP_OFFSET` 8 -> 44 and `TIED_TOP_OFFSET` 44 -> 74. **Nothing else** — the new strings are in
the drawers' own CONFIG blocks (section 1.2). These two numbers are what put this task in
`TWO_PLAYER_PATHS`.

---

## 8. The full map, made clearer (brief requirement 4, question 7)

### 8.1 Your place against everyone else's

- **Your own marker** is already distinct: `MapUi.COLORS.own` = `Drive.CONFIG.SCORE_HIGHLIGHT_COLOR`,
  the cream your own row on the board wears, plus the facing wedge. Unchanged.
- **Your stand / your lane** is the new **target mark** (section 7.2) in the orange-red
  `MapUi.COLORS.arrow`, with its word (`STAND` / `LINE` / `ROAD`) beside it. The other stands keep
  `MapUi.COLORS.stand` and their index labels. So on the full map there is one orange-red mark, and
  it is yours.
- The push arrow now points at the same place (section 7.1 item 5).

### 8.2 The legend, and what it costs on a phone

Six rows, inside the panel's footer band, to the right of the existing scale bar, in the panel's
fixed pixel space so it scales with the panel:

| swatch | word |
|---|---|
| line, `ROAD_COLOR` | `ROAD` |
| square, `COLORS.stand` | `STAND` |
| square, `COLORS.arrow` | `GO HERE` |
| dot, `COLORS.own` | `YOU` |
| dot, `COLORS.Shooters` | `HUNTER` |
| dot, `COLORS.Drivers` | `BEATER` |

**At 1080p it is readable and at 400 x 800 it is not, and that is a decision rather than an
accident.** The panel is laid out at a fixed pixel size and fitted with one `UIScale` (the mechanism
`MapUi`'s header defends, and the reason a resize cannot leave a stale road behind). At a 400 px
width that scale is roughly a third, and no font inside the panel survives it. A counter-`UIScale`
would make the legend overflow the panel; a screen-space legend collides with the event feed, which
is 420 px wide on a 400 px screen already (`Hud.build`: `feed.Size = UDim2.fromOffset(420, ...)`).

So: **`MapUi.legendVisible(scale)` is false below `LEGEND_MIN_TEXT_PX / LEGEND_TEXT_PX`** (8/12, so a
scale under 0.67), and when it is false **the map labels itself instead**: the own marker gets a
`YOU` tag drawn beside it and the target mark keeps its word, both of which exist at every size. What
is lost on a phone is the colour key for OTHER players' teams. Stated, not hidden; the real fix is a
phone layout for the feed, the readout and the centred panels, which is a task of its own
(section 12.2).

---

## 9. Numeric targets

| Target | Value | Why |
|---|---|---|
| Objective text size | 24 px at viewport >= 700 px wide, 18 below | the headline: the bar is 20, the compass 13. The break point is the one place a size is chosen |
| Objective band | y 8..40, 32 tall, centred, full width less 16 px margins | the top line is the first thing read |
| Longest objective string | **32 characters**, and every string must satisfy `TextFits` at a 400 px frame | measured by the engine, not by a font-width assumption |
| Waypoint chevron | 14 x 14 rotated square (the `Compass` chevron's technique: no asset) | a small mark, not a billboard — theHunter's players ask for theirs to be smaller |
| Waypoint label | 11 px, `WORD  240 m` | the distance is where the eye already is |
| Distance unit | metres, via `Report.metres` (`METRES_PER_STUD = 0.28`) | the one conversion in the repo; the map adds a reader, never a copy |
| Pinned inset | 56 px left/top/bottom, **68 px right** | 68 = the rail's column, so a pinned chevron never lands under a button |
| Pinned transparency | 0.45 (`Compass.CONFIG.PINNED_TRANSPARENCY`) | pinned and real are not the same picture |
| Waypoints on screen | **exactly 1**, ever | D7; theHunter: *"only showing the closest waypoint on the HUD to avoid visual overload"* |
| Arrival | in at 12 studs, out at 18 | `ForestTest.PICK.leashStuds` is 6; twice it, with a 6-stud dead band so it cannot flicker |
| Rail button | 48 x 48, gap 8, margin 12 | over the 44 px `UISizeConstraint.MaxSize` the Roblox curriculum sets; `MapUi.CONFIG.BUTTON_PX` was already 48 |
| Rail block | 4 buttons = 216 px tall; top = 140 + minimap diameter + 8 | 298..514 at 1080p, 244..460 at 400 x 800 — clear of the readout at both |
| Waypoint tick | once a frame, `RenderStepped` | it tracks the VIEW. The compass's rule, and task 141's: *"a thing that tracks the VIEW cannot be told by an event about the MODE"* |
| Map target tick | the map's existing 20 Hz | it tracks POSITIONS. `MapUi.CONFIG.TICK_HZ`'s own argument, unchanged — `setTarget` is a setter and schedules nothing |
| Per-frame cost | **under 0.1 ms** | one `PointToObjectSpace`, one `tan`, <= 33 polyline samples or 9 stands, four property writes. The camera's whole budget is 0.3 ms (camera design 8.2) |
| Phone size | 400 x 800, asserted arithmetically at 400x800, 800x600 and 1920x1080 | task 155's own check size |
| Legend | 6 rows; hidden below a panel scale of 0.67 | 8 px is the floor for `Enum.Font.Code` to be read |

---

## 10. How it is tested

### 10.1 Client spec, pure (`tests/client/hud_clarity.spec.luau`, new)

Pure cases need no drive, no world, no camera and no second player — the shape
`Hud.startCardLines`, `Hud.driveBearing`, `Hud.crosshairVisible` and `MapUi.project` already have.

1. `Objective.text` — all eight rows of section 5.1, plus `nil` phase and `nil` team, plus: **no team
   returns `""` in every phase** (the case that proves the design's own ruling).
2. **Every string fits**: write each into the real `Hud.objectiveLine()` label with
   `TextSize = Objective.textSizeFor(400)` and the frame width a 400 px viewport gives, and assert
   `TextFits`; restore. (Save-and-restore is `map_ui.spec`'s own overlap-case idiom.)
3. `Objective.targetFor` — hunter with stands -> the nearest, and **the neighbour's when the player
   is 80 studs along** (the failure case, asserted so it is a decision and not a surprise); hunter
   with `#stands == 0` -> the road point, word `LINE`; beater -> the road point at her own x; x past
   the end -> the polyline's endpoint; `Waiting` and `Scoring` -> nil; nil geometry -> nil; nil team
   -> nil.
4. `Objective.arrived` — crosses in at 12, does NOT come back out until 18 (both directions, which is
   what proves the hysteresis exists).
5. `Objective.project` — dead ahead -> (0,0) and `onScreen`; a point at a known angle off axis ->
   compared against `Hud.reticleDegToPx(angle, fov, viewportY)`, which is an INDEPENDENT expression
   of the same relation. (`map_ui.spec` asserts its bearings against `Compass.headingDeg` for exactly
   this reason: task 129 *"copied the expression under test into itself and agreed with the wrong
   one"*.) Off the edge -> clamped per axis, `onScreen == false`. Behind -> pinned to the correct
   side at mid height.
6. `Objective.lineVisible` / `markVisible` — every combination of the five inputs, including the one
   row that differs: **start card up -> line hidden, chevron shown**.
7. `Hud.markerFor` — target present -> the target's bearing and word; no target -> the world's
   bearing and word unchanged; neither -> nil, nil.
8. `Rail.visible`, `Rail.buttonVisible` — no weapon hides RELOAD and AMMO and hides nothing else.
9. **Rectangles**: `Objective.lineRect`, `Rail.rect`, `MapUi.minimapRect`, `MapUi.fullMapRect` and
   the four existing bands are pairwise disjoint at 400x800, 800x600 and 1920x1080. **This is the
   most valuable case in the file**, and it is the one `map_ui.spec` already explains: task 125
   round 2 shipped a strip over the clock and the frames did not show it, because they were taken in
   a world with no clock.

### 10.2 Client spec, live

10. **What is drawn equals what the rule says**, in whatever phase the run is in:
    `Hud.objectiveLine().Text == Objective.text(Match.phase(), Match.myTeam())` and
    `Hud.objectiveLine().Visible == Objective.lineVisible(...)` with the live predicates. Valid in
    every phase (correction C1), so it needs no phase to be arranged.
11. The rail exists, `Rail.buttonIds()` is the expected list for the live weapon state, and each
    button's rectangle is disjoint from the minimap's and the readout's by `AbsolutePosition` at the
    live viewport (the existing overlap case's technique, extended as the brief asks).
12. `Rail.press("MAP")` flips `MapUi.isOpen()` and increments `MapUi.stats().toggles`;
    `Rail.press("REPORT")` flips `ReportPanel.isOpen()`; `Rail.press("RELOAD")` returns false while
    `Weapon.Input.isHeld()` and true otherwise. This proves the second door leads to the same room.
13. `MapUi.setTarget` then one tick: exactly one target mark is visible across both drawers, and it
    is pinned (dimmer) when the point is outside the view.

### 10.3 Server spec

None is needed and none is added: nothing in this task is the server's. `tests/server/` is untouched.

### 10.4 Harness input, and what cannot be verified

- The **key** paths are already driven by the real harness: `M` in the `map-toggle` scenario, `R` and
  `X` in `weapon-fire-reload-ammo` (`tests/client/input_scenarios.txt`). Those still pass through
  `Input.reload` / `Input.selectAmmo` after 7.4, so the refactor is covered by existing real input.
- **The tap or click on a rail button is NOT proved by any spec, and it cannot be today.** A spec
  cannot fire `GuiButton.Activated`; the harness cannot synthesise a touch; and a `moveTo` step in
  the scenario file carries STATIC pixel coordinates, while the rail is anchored to the right edge of
  a Studio Play viewport whose size is not fixed (task 155 measured 969 x 784 in one run). Saying
  "add a click at x=940" would be a scenario that passes on one machine. **This is reported as a
  harness limitation, not papered over** (rule 6, rule 8). The fix is a scenario step that names a
  GuiObject and resolves its centre at replay time; it is harness work (`tools/studio_mcp.py`), out
  of this task's scope, and goes in `TASKS.md` as 165a.
- `Rail.press` is therefore the seam the spec drives, and the design says plainly that what it proves
  is the ACTION, not the touch.

### 10.5 The gate, screenshots, and the harness tables

- **`test2` IS required for this task.** `src/shared/Drive/init.luau` is in `TWO_PLAYER_PATHS`
  (`tools/agents.py`) and two of its offsets move (7.5), so the PR to `main` needs
  `[harness2] PASS ... @ <code commit>` as well as `[harness] PASS ... scope=all`. A review round may
  use `python tools/studio_mcp.py test --scope auto`, which resolves to `hud,weapon,match` and then
  asks for no `[harness2]` line at all.
- **`tools/studio_mcp.py` must be edited in the same commit**: the new spec file goes into
  `SCOPE_SPECS["hud"]`, or `selftest` fails with "a spec file belongs to no scope" — and that failure
  is a failed harness run, not a note.
- **Screenshots (rule 5), inspected by the Builder, not merely saved.** At minimum: (1) the objective
  line and the waypoint chevron in a live `Assigning`, showing the line is NOT drawn while the start
  card is up and the chevron IS; (2) the same a few seconds later in `Running`, line up, card gone;
  (3) the rail, with RELOAD and AMMO present with a gun and absent without one; (4) the full map open
  at 1080p with the legend and the orange-red target mark. The phone layout is proved
  **arithmetically** (10.1 case 9), not photographically, because the Studio Play window size is not
  something a tool here can set — stated so nobody claims a phone screenshot that is really a 969 px
  window.

---

## 11. External sources

Fetched by the Builder for `docs/research/2026-10-12-hud-clarity.md` on 2026-10-12. **This Architect
run is read-only and could not re-fetch them**; the quotations below are that note's, and the note
records which pages were actually retrieved and which claim it threw out.

### A. Roblox Creator Docs — *Wireframe your layouts* / *Implement designs in Studio*

<https://create.roblox.com/docs/tutorials/user-interface-design/wireframe-your-layouts>
<https://create.roblox.com/docs/tutorials/curriculums/user-interface-design/implement-designs-in-studio>

**Licence CC BY 4.0** (stated by the `Roblox/creator-docs` repository). **Maintained** by Roblox;
current curriculum.

> "If you group UI elements from different categories together throughout the screen, players won't
> know where to look for what they need... group UI elements from the same category together."

> "a virtual thumbstick displays in the bottom-left corner of the screen, and a jump button displays
> in the bottom-right corner"

**Well:** first-party, and the grouping sentence is an ARGUMENT rather than a preference — it is the
whole reason the map button stops being a lone circle and becomes the first button of one rail. The
companion page gives the touch target as a number (`UISizeConstraint.MaxSize = inf, 44`), which this
repo's existing 48 already clears.
**Badly:** it says nothing about where a right-edge rail starts vertically, nothing about objective
text, and it states no keep-out rectangle in pixels — only that the two bottom corners are the
engine's. That is all this design takes from it, and it is why the rail is a right-EDGE column rather
than a bottom-corner cluster.
**Adopted:** one category, one place (the rail); 48 px buttons; the two bottom corners stay empty.

### B. PersonifiedPizza, *Location Marker System* — Roblox DevForum community resource

<https://devforum.roblox.com/t/location-marker-system/1586885>

Uncopylocked model, **no explicit licence**; last author response **December 2021**, so
**unmaintained**. **Read for the pattern, not vendored** — the rule
`docs/research/2026-09-27-first-person-viewmodel.md` set for the four viewmodel kits ("no licence is
not free to copy").

**Well:** it is the canonical Roblox shape for this and it confirms the two decisions that matter —
**one `ScreenGui`** rather than a `BillboardGui` per target, and **edge clamping rather than hiding**,
which is the rule `Compass.offsetPx` and `MapUi.project` already follow in this repo.
**Badly:** it is built on workspace-attachment discovery, which `MapUi` measured and rejected (the
DEV posts are invisible, unqueryable, streamed parts); its distance handling is a FADE, which answers
"far" and not "how far"; and it reads `workspace.CurrentCamera` directly, which this repo cannot do
(`Camera.Rig` counts foreign writes to that property). **Pattern yes, code no.**
**Adopted:** one ScreenGui; clamp, do not hide; dim when pinned. **Refused:** its discovery route,
its fade, its camera source.

### C. theHunter: Call of the Wild — the genre's own waypoint, through its players

<https://steamcommunity.com/app/518790/discussions/2/133257636770005666/>
<https://steamcommunity.com/app/518790/discussions/0/4839770694279329770/>

Avalanche Studios, commercial, **live**. Not borrowable code — borrowable **complaints**, the same
source `docs/research/2026-10-05-drive-report.md` used for the harvest screen.

**Well:** the closest living product to this game, and its players have already found the failure
modes: the marker is *"massive and orange"* and they ask to shrink it; *"only showing the closest
waypoint on the HUD to avoid visual overload"*; the waypoint *"shows distance information"* and they
still want it on the compass, because opening the map to navigate breaks the hunt — which is Karen's
sentence.
**Badly:** single-player, so nothing in it is about roles; its waypoints are player-placed and ours
is assigned by the drive; nothing about mobile.
**Adopted:** a small chevron and a short word, never a billboard; **exactly one** waypoint (D7); the
distance as a NUMBER; the same target on the strip, the minimap and the map, not only on M.

### D. Roblox Engine API Reference — `Camera`, `TextLabel`, `GuiObject`, `ContextActionService`

<https://create.roblox.com/docs/reference/engine/classes/Camera>
<https://create.roblox.com/docs/reference/engine/classes/TextLabel>

Same corpus and licence as A (**CC BY 4.0**, `Roblox/creator-docs`), **maintained**.

**Well:** it is the definition of the two properties this design depends on —
`Camera.FieldOfView` is the VERTICAL angle (which is what makes `f = (viewportY/2)/tan(fov/2)` exact,
the relation `Hud.reticleDegToPx` already rests on) and `TextLabel.TextFits`, which lets a spec ask
the ENGINE whether a sentence fits instead of guessing a glyph width.
**Badly:** `Camera:WorldToViewportPoint` is the obvious answer it offers and this design **refuses
it**, because it answers for `workspace.CurrentCamera` — the object `Camera.Rig` has counted a
foreign write on since task 123 — rather than for the view this system applied. The API reference has
no opinion about which camera is the truth; this repo does.
**Adopted:** the hand projection from `Camera.viewCFrame()`; `TextFits` as the measurement.

### E. Negative result, carried forward from the note

`https://create.roblox.com/docs/projects/cross-platform` was fetched for thumb-zone and
minimum-touch-size numbers that a search extract attributed to it, and **does not contain them**. The
numbers in source A do. Recorded because this repo has twice spent a round on a citation that did not
say what it was cited for.

---

## 12. Holes this design does not close, named

### 12.1 The DEV world has no stands, and a solo player there is a hunter

`MapUi.geometryFromMap` returns `stands = {}` deliberately (its own header gives the measured reason),
and `Match.CONFIG.ODD_PLAYER_TEAM = "Shooters"`, so **the world Karen plays solo in cannot say which
post is hers.** This design does not invent one (D5). It gives her the LINE instead — which that
world HAS stated (`Map.ROAD`, *"the road's centreline IS the drive line"*) — with the word `LINE`
rather than `STAND`, so the screen never claims to know more than the world said. The full answer is
task **155a** (`Map.LINE`, a pure shared statement of the post line asserted against the tags by
`map_contract.spec`); when it lands, `geometryFromMap` fills `stands` and this design's hunter branch
takes the first path with no other change. The Director decides the order (section 13).

### 12.2 The centred panels are wider than a phone

`Report.CONFIG.PANEL_WIDTH` is 760, `Drive.CONFIG.SCORE_PANEL_WIDTH` 480, `START_CARD_WIDTH` 440 and
the feed frame 420 — all wider than a 400 px screen, none of them scaled. That is an existing defect,
it predates this task, and this design does not fix it. What it does is make sure the new work does
not depend on it: the rail sits at ZIndex 16 **over** those panels, so its buttons are reachable on a
phone whatever the panels do, and the legend degrades to on-map labels rather than relying on panel
room that is not there. Queue: "the Hud's fixed-width panels need a phone layout (`UIScale` or a
width clamp)".

### 12.3 What a spec cannot reach

- The tap on a rail button (10.4).
- The `Scoring` strings on a live client: the server suite drives the phase through `Scoring`
  (`zz_drive_boundary.spec`) but the two runners are not ordered, so a client spec cannot be sure to
  be there. The pure cases cover the strings; the live case covers whatever phase the run is in.
- Whether the picture is RIGHT. That is Karen's eye and a screenshot (rule 5), and it is deliberately
  the only thing left to it: *"things measured correct and looked wrong"*.

---

## 13. Open decisions

None of these blocks building. Each has a first value, built as written, and is one line to change.

**Karen (feel):**

1. **The six sentences.** First values in section 5.1. Hers to rewrite; the only constraint the code
   imposes is 32 characters (and the spec will say so if a rewrite breaks it).
2. **Text sizes**: 24 px, 18 px below 700 px wide, and the chevron at 14 px. Hers.
3. **`Rail.CONFIG.SHOW_ON_DESKTOP`**, shipped `true`. If the rail is clutter on a PC it is one
   boolean to `false`, and the rail stays for touch.
4. **The arrival distance** (12 studs in, 18 out): does the arrow go away too early or too late?
5. **D11's colour conflict, named and NOT settled here.** The dispatch says "orange = beater/road";
   in this repo orange is the SHOOTERS' team colour (`Drive.CONFIG.SHOWER_COLOR` / `SHOOTER_COLOR`,
   mirroring the `Bright orange` `Team.TeamColor` `Match.Body` sets) and hunter orange is worn by
   BOTH roles (`Match.Body` OUTFIT_COLOR). Re-assigning team colours would repaint the scoreboard,
   the bar and the map, so it is out of this task. The target mark uses the orange-RED
   `MapUi.COLORS.arrow` / `Compass.CONFIG.DRIVE_COLOR`, which is already distinct from both team
   colours — so nothing here depends on the answer.
6. **hunter/beater vs SHOOTER/DRIVER** across the whole Hud — still `TASKS.md` 158a, still hers, and
   still not settled quietly in a renderer. The objective line uses her words through the same door
   the start card does.

**The Director (scope):**

7. **Task 155a (`Map.LINE`) before or after this?** After is fine: a DEV hunter gets the `LINE`
   waypoint meanwhile (12.1). Before would make the DEV waypoint say `STAND` from the first frame.
8. **The horn button** (D9's condition is not met): a client request path for a blast is a remote,
   which D3 refuses for this task. Its own task, or not at all.
9. **The deviation from D12** (section 1.2): strings in the drawers' own CONFIG rather than
   `Drive.CONFIG`. One line to reverse.
10. **The harness extension** for clicking a named GuiObject (10.4), queued as 165a.

---

## 14. Build order

One task, nothing extra. In this order, because each step leaves the tree working:

1. `Objective.luau`: the pure half only (`text`, `targetFor`, `distanceStuds`, `arrived`, `project`,
   the two predicates, `CONFIG`) — and the pure spec cases 1-8. Nothing is drawn yet.
2. The band move: the four constants, `Hud.build`'s new empty nodes, and rectangle case 9.
3. `Objective`'s drawing half, `Hud.renderObjective`, `Hud.markerFor`, the team closure change, the
   two `setSuppressed` lines. Live cases 10 and 13.
4. `Rail.luau`, `Input.reload` / `Input.selectAmmo`, and live cases 11-12.
5. `MapUi.setTarget`, the legend, the rail column in `layoutFor`, the button removal (+ the
   `backups/` note), and the `map_ui.spec` edits.
6. `SCOPE_SPECS["hud"]` gains the new spec; `GAME_DESIGN.md`'s UI row gains `Objective` and `Rail`
   with their one-writer sentences; `docs/research/INDEX.md` already has the note.
7. The harness (`test`, and `test2` because of 7.5), the four screenshots, inspected.
