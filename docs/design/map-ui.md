# The map: a full map on M and a round minimap (`map-ui`)

Task 155 · Architect · 2026-10-11 · designed to `reviews/task-155/BRIEF.md` and
`docs/research/2026-10-11-map-ui.md`.

The pattern is **not re-opened**: a 2D map projected from the world's own geometry data, no
`ViewportFrame`, no map image, north up (brief §1.2, §1.3; note "The pattern adopted"). This
document decides the owner, the interface, the pixels, the input, the budget and the tests.

---

## 1. What it must do

Karen, 2026-10-11 ~14:10, verbatim: *"I am missing map, we need a map when click M where will be
hunter position where they stand and what direction to move also can see other players on map
moving / and small map in left or right corner circle like is on another games hwere showing where
to move ect"*.

Six requirements, and every one of them is a row in this design:

| # | Her words | This design |
|---|---|---|
| 1 | "when click M" | `DrivenHunt.Map.Toggle` on **M**, §7 |
| 2 | "where will be hunter position where they stand" | `ForestTest.standPosition(i)` × `STAND_COUNT`, §3 |
| 3 | "what direction to move" | the push arrow + its word, from `Hud.driveBearing`, §4 |
| 4 | "can see other players on map moving" | ≤ 16 live markers at 20 Hz, team-coloured, §9, §10 |
| 5 | "small map in left or right corner circle" | the 150 px round minimap, top **right**, §5 |
| 6 | mobile (`PROJECT_CONTEXT.md` build order 4) | an on-screen button on a touch device, §8 |

## 2. What it must NOT do

Each line is a boundary, not a style note.

1. **Never render the world.** No `ViewportFrame`, ever, while the ground is Terrain. The note's
   forcing fact: *"You can't put Terrain instances under ViewportFrame"*
   ([devforum #219346](https://devforum.roblox.com/t/add-terrain-support-rendering-from-outside-its-parental-structure-for-viewportframe/219346),
   still open). `ForestTest.groundAt` raycasts real terrain; `MapGen.Ground` paints terrain
   materials. A top-down viewport of either world is a transparent void with trees floating in it —
   `PROJECT_CONTEXT.md`'s *"a visibility audit ignored parent visibility and certified a blank
   screen twice"* in a new costume.
2. **No boars, no animal of any kind.** Brief §4, note "What is deliberately NOT built".
3. **It writes no other system's state.** Not the camera, not the cursor, not the trigger, not the
   weapon, not `Player.Team`, not a boar, not the server. It fires **no remote** and owns none:
   everything it draws is data the client already has.
4. **It re-derives nothing.** Not the road (`ForestTest.roadZ` is *"the one definition; every other
   reader calls this"*), not a stand position, not the drive or push bearing
   (`Hud.driveBearing`), not metres per stud (`Report.metres`).
5. **It never reads `workspace.CurrentCamera.CFrame` for a heading.** `Camera.Rig` counts foreign
   writes to that property and has warned about one since task 123; `Camera.viewHeadingDeg()` is
   the one source. Three rounds of task 125 were spent settling that.
6. **It does not rotate.** North is up at both sizes. A rotating map needs a second view-heading
   source, and that question already has an owner (§4).
7. **It writes no other Hud element's `Visible`.** Not the crosshair (`Hud.crosshairVisible` is a
   pure predicate about the gun and first person — adding "is the map open" to it is literally the
   previous project's *"one predicate answered two unrelated questions"*), not the compass, not the
   drive bar, not the report panel.
8. **It touches no file under `TWO_PLAYER_PATHS`** (`tools/agents.py`). §12 proves this file by
   file.
9. **No fog of war, no ping, no waypoint, no map image under the overlay, no "which stand is
   taken".** Out of scope (brief §4). The last one is named because a reader could mistake it for
   a gap: which stand a hunter *locked* is server state in `src/server/ForestTest/`, reaching it
   needs a new remote, and Karen asked where hunters **stand**, which is all nine spots.

---

## 3. The owner

### 3.1 The decision

**A new module under the existing owner.** `PlayerScripts.Hud` stays *"THE OWNER OF ANYTHING
DRAWN"* and *"the only writer of PlayerGui.HunterHud and everything in it"* (`src/client/Hud/init.luau`
header). Nothing here changes that.

| Disk | Studio | Role |
|---|---|---|
| `src/client/Hud/MapUi.luau` | `StarterPlayerScripts.Hud.MapUi` | the one writer of everything **inside** the map's frames |
| `src/client/Hud/init.luau` | `StarterPlayerScripts.Hud` | creates the frames in `Hud.build`, starts `MapUi`, hands it its collaborators |

This is the shape `Hud/Compass.luau` and `Hud/ReportPanel.luau` both already have, and both say why
in their own headers: *"IT IS NOT ITS OWN SCREEN. `Hud.build` creates the `Compass` frame with the
rest of the HUD … one ScreenGui, built once, so a visibility audit has one place to look."* A second
`ScreenGui` would give a visibility audit two places to look, which is the thing that failed twice
in the previous project.

**The file is `MapUi.luau` and not `Map.luau`.** `src/client/Hud/init.luau` already holds
`local Map = require(ReplicatedStorage:WaitForChild("Map"))` — the world contract. A sibling called
`Map` would shadow it at the one call site that needs both. `ReplicatedStorage.Map` is the **world**;
`Hud.MapUi` is the **picture of it**, and the names say so.

### 3.2 One writer each, named individually (brief §1, rule 3)

| Thing | The one writer | Where |
|---|---|---|
| the two frames' existence, size, position, `ZIndex` | `Hud.build` | `src/client/Hud/init.luau` |
| everything **inside** both frames (geometry, markers, arrow, labels, scale bar) | `Hud.MapUi` | `MapUi.luau` |
| the two frames' `Visible` | `Hud.MapUi` (`MapUi.applyVisibility`) | `MapUi.luau` |
| the projection (studs → pixels) | `Hud.MapUi` (`MapUi.project`, pure) | `MapUi.luau` |
| the static geometry (road, stands) | `Hud.MapUi`, built once per world | `MapUi.luau` |
| the player markers | `Hud.MapUi` | `MapUi.luau` |
| the open/closed state (`open: boolean`) | `Hud.MapUi` | `MapUi.luau` |
| the suppression state (`suppressed: boolean`) | `Hud.MapUi`, set through `MapUi.setSuppressed` | `MapUi.luau` |
| the **M** binding (`DrivenHunt.Map.Toggle`) | `Hud.MapUi` (`ContextActionService`) | `MapUi.luau` |
| the mobile button's `Visible` and its action | `Hud.MapUi` | `MapUi.luau` |
| **the geometry source** — the world's own numbers | **nobody at run time.** `ReplicatedStorage.ForestTest` and `ReplicatedStorage.Map` are frozen data the map READS | `src/shared/` |
| the push bearing and its word | `Hud.driveBearing`, already (task 153), resolved once and handed to both drawers | `src/client/Hud/init.luau` |
| the view heading for the facing wedge | `PlayerScripts.Camera` (`Camera.viewHeadingDeg`) | `src/client/Camera/init.luau` |

### 3.3 The one place this design refuses the Compass's precedent, and why

`Hud.renderScope` hides the compass strip while the sight picture is in, and its own comment admits
the cost: *"`compassFrame.Visible` therefore has TWO writers and that is deliberate (rule 3): both
are in this file."* It works, but it is a second writer kept honest by a comment.

**The map does not copy it.** `Hud.renderScope` instead **states a need**:

```lua
MapUi.setSuppressed(scoped)   -- and MapUi performs the single write, at once
```

That is this repo's own `Camera.Cursor.requestFree(tag)` pattern — *"a caller states a NEED … this
module resolves every outstanding need and performs the single write"* — and `Input.requestHold`
borrowed it verbatim for the same reason. The map module stays the single writer of its own frames'
`Visible`. `setSuppressed` applies the write immediately rather than waiting for the next 20 Hz tick,
so the blackout and the map arrive on the same frame (the lesson of task 141: *"a sight picture that
waits for the blend was computed exactly once, at the only moment it is false"*).

Recorded in §13 as a deliberate difference from `Compass`, not an oversight.

---

## 4. The projection and the conventions

### 4.1 The view

```lua
export type ClipShape = "rect" | "disc"

export type MapView = {
    centreX: number,       -- world studs at the middle of the frame
    centreZ: number,
    pxPerStud: number,     -- ONE scale for both axes. A map with two scales lies about distance.
    halfWidthPx: number,   -- the frame's half-extent; for "disc", halfWidthPx == halfHeightPx == r
    halfHeightPx: number,
    shape: ClipShape,
}
```

### 4.2 The one function

```lua
-- WORLD (x, z) -> PIXELS from the frame's own centre, and whether the point is really in view.
-- A point that is NOT in view comes back PINNED to the border, exactly as Compass.offsetPx does,
-- "so 'it is behind me and to the left' still has an answer".
function MapUi.project(worldX: number, worldZ: number, view: MapView): (number, number, boolean)
    local u = (worldX - view.centreX) * view.pxPerStud
    local v = -(worldZ - view.centreZ) * view.pxPerStud     -- NORTH IS UP: +Z is -v
    if view.shape == "disc" then
        local r = view.halfWidthPx
        local d = math.sqrt(u * u + v * v)
        if d > r then
            return u / d * r, v / d * r, false              -- pinned to the rim
        end
        return u, v, true
    end
    local cu = math.clamp(u, -view.halfWidthPx, view.halfWidthPx)
    local cv = math.clamp(v, -view.halfHeightPx, view.halfHeightPx)
    return cu, cv, (cu == u and cv == v)
end
```

**Pure and exported.** This is the non-negotiable requirement of brief §2: a spec asserts it with
hand-written studs, no world, no camera, no player. `PROJECT_CONTEXT.md`'s *"measured correct and
looked wrong"* is survivable only when the arithmetic is **provable** and the **look** is the only
thing left for Karen's eye.

### 4.3 The bearing convention, which is this game's and not a new one

North is **+Z**; bearings run **clockwise through east (+X)**. `Compass.headingDeg` fixes it with
`atan2(x, z)` and says why the other order is *"a compass that is always wrong by one cardinal,
which is worse than no compass"*. `Camera.headingOfLookDeg` uses the same expression and was settled
against a **photograph** of four neon posts (`.screenshots/t129-turn-A.png`), not against another
CFrame.

North up therefore means exactly: **+Z is −v** (up the screen) and **+X is +u** (right). One minus
sign, in one place, in the function above.

The inverse — a bearing to a screen offset, for the facing wedge and the push arrow — is the second
and last piece of trigonometry, and it is also one function:

```lua
-- A BEARING TO AN OFFSET IN PIXELS, the inverse of `project`'s convention and the only place it is
-- written. GuiObject.Rotation is clockwise from "up", so `rotation = bearingDeg` needs no sign flip:
-- a bar drawn pointing up, rotated clockwise by 90, points east.
function MapUi.facingOffsetPx(bearingDeg: number, radiusPx: number): (number, number)
    local rad = math.rad(bearingDeg)
    return math.sin(rad) * radiusPx, -math.cos(rad) * radiusPx
end
```

A spec asserts all four cardinals against `Compass.headingDeg` of the same vector, so the two
conventions are **compared** and not copied — the lesson of task 129, where a case that copied the
expression under test into itself *"agreed with the wrong one"* for three rounds.

### 4.4 Both sizes, one function

| | centre | `pxPerStud` | `shape` |
|---|---|---|---|
| **minimap** | the local player's own (x, z) | `(diameter / 2) / MINIMAP_RANGE_STUDS` | `"disc"` |
| **full map** | the geometry's bounds centre | `min(w / spanX, h / spanZ)` | `"rect"` |

They differ in **centre, scale and clip shape** and in nothing else. Both are built by pure
constructors so a spec can make one with no screen:

```lua
function MapUi.minimapView(centre: Vector3, diameterPx: number, rangeStuds: number): MapView
function MapUi.fullView(bounds: Bounds, widthPx: number, heightPx: number): MapView
```

### 4.5 The minimap's geometry moves in ONE write

The minimap is player-centred, so its road and stands must move. They are **not** re-projected per
tick. They are drawn once, in map space, as children of an inner frame, and the tick writes that
frame's position:

```lua
local u, v = MapUi.project(me.X, me.Z, viewCentredOnGeometry)   -- same function, same view
inner.Position = UDim2.new(0.5, -u, 0.5, -v)                    -- ONE write moves all of it
```

This is the "move the map under the player" mechanism of the image-based option (note option B),
borrowed without its image. It is also the whole reason the minimap's per-tick cost is flat in the
amount of geometry (§9).

---

## 5. Where the geometry comes from, per world, and the seam between them

### 5.1 One shape — "what a world tells the map"

```lua
export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }

export type MapGeometry = {
    world: string,           -- Map.EXPECTED_WORLD, carried for the record and for a spec
    bounds: Bounds,          -- what the full map covers
    road: { Vector2 },       -- the hunters' line as a polyline of (x, z), in x order
    stands: { Vector2 },     -- one point per stand/post, in index order. MAY BE EMPTY.
}
```

**One reader, two providers.** There is no second code path: `MapUi` draws a `MapGeometry` and does
not know which world made it.

```lua
function MapUi.geometryFromForestTest(data: any): MapGeometry   -- pure
function MapUi.geometryFromMap(map: any): MapGeometry           -- pure
function MapUi.geometryFor(world: string, forestTest: any?, map: any?): MapGeometry?
```

### 5.2 The Forest Test (first, because it is where Karen plays — brief §1.8)

Every number is read from `ReplicatedStorage.ForestTest` and none is re-typed:

| Field | Source symbol |
|---|---|
| `road` | 33 samples of **`ForestTest.roadZ(x)`** at 50-stud steps across `CENTRE.X ± HALF_SPAN` |
| `stands` | **`ForestTest.standPosition(i)`** for `i = 1..ForestTest.STAND_COUNT` (9) |
| `bounds.minX` / `.maxX` | `CENTRE.X ∓ (HALF_SPAN + MARGIN)` = `CENTRE.X ∓ 860` |
| `bounds.maxZ` | `CENTRE.Z + max(DRIVERS.startNorthStuds, LINE.spawnNorthStuds + BEATER.behindLineStuds) + MARGIN` = `CENTRE.Z + 760` |
| `bounds.minZ` | **`ForestTest.EXIT_Z`** `− MARGIN` = `CENTRE.Z − 340` |

`MARGIN = 60`. `maxZ` takes the **larger** of the two drive-side starts — `DRIVERS.startNorthStuds`
is 700 and a beater's own start is `180 + 60 = 240` — because a driver walking in from 700 studs is
one of the "other players moving" Karen asked to see, and a map that cuts him off has lost him. The
road's ±30 of amplitude is inside the margin; `EXIT_Z` already subtracts it.

33 road samples over 1,600 studs is a 50-stud chord on a 440-stud-wavelength, 30-amplitude sine:
the worst chord error is under 2 studs, which at the full map's 0.64 px/stud is **one pixel**. A
finer sample buys nothing visible and costs frames.

### 5.3 The DEV Match world — the road and the bounds, and **no stands**, deliberately

| Field | Source symbol |
|---|---|
| `road` | `{ (Map.ROAD.from, Map.ROAD.z), (Map.ROAD.to, Map.ROAD.z) }` — straight, two points |
| `bounds` | `Map.FIELD.bounds`, widened to hold the road: `minX = min(bounds.minX, ROAD.from) − MARGIN`, `maxX = max(bounds.maxX, ROAD.to) + MARGIN` |
| `stands` | **`{}`** |

**Why the DEV stands are empty, and this is a finding, not a shrug.** `Map.TAGS.shooterPost` is
read by `Markers.read` in **`src/server/Match/Markers.luau`** — which is **in
`TWO_PLAYER_PATHS`** (`src/server/Match/`), is server-only, and brief §1.8 and §4 forbid dragging
one in. The generator's own statement of the post line lives in `MapGen.Config`'s
`WORLD.postCount` / `postSpacing` / `lineZ`, read by `Layout.markers`
(`src/serverstorage/MapGen/Layout.luau`) — and **ServerStorage does not replicate**, so a client
cannot read it at all. The shared `Map` module publishes `EXPECTED_COUNTS.shooterPost = 8` and the
road, and **not the post spacing**.

The two ways to close it, and both are the next task:

1. `CollectionService:GetTagged(Map.TAGS.shooterPost)` on the client. **Refused here**: the posts
   are `Transparency = 1`, `CanQuery = false` parts in a place where `Map.STREAMING.enabled = true`
   with a 1,024-stud target radius, so the far end of a 1,120-stud line may simply not exist on this
   client — a map that silently drops half its stands by distance. Whether runtime
   `AddTag` even replicates is a second unverified dependency (§15).
2. **The recommended fix, as task 155a:** add a pure `Map.LINE = { postCount, postSpacing, z }` to
   `src/shared/Map/init.luau` (**not** a `TWO_PLAYER_PATHS` file), have `MapUi.geometryFromMap`
   read it, and have **`tests/server/map_contract.spec.luau`** assert it against
   `GetTagged(Map.TAGS.shooterPost)` positions — so the second description cannot drift from the
   first, which is the only real cost of option C in the note.

Until then the DEV map draws the road, the bounds and the players. That is **not** a blank panel: it
is a map of a world that has stated a road and no stands, which is the truth about that world's
shared data today.

### 5.4 A world that states nothing gets **no map at all**

`MapUi.geometryFor` returns `nil` when the world is neither of the two. Then, explicitly:

* both frames stay `Visible = false`;
* **M is not bound** (an M that opens an empty panel is worse than an M that does nothing);
* the mobile button is not shown;
* one `warn` names the world;
* `MapUi.geometry()` answers `nil`, so a spec asserts the state instead of guessing.

*Visibly no map, never a blank panel* (brief §3) — the audit that *"certified a blank screen twice"*
is what that sentence is made of.

### 5.5 The door, and the late arrival (task 134's bug)

The Hud already reaches the Forest Test's data through
`Hud.whenReady(ReplicatedStorage, "ForestTest", …)`, whose own comment records the bug: *"no
`ForestTest` yet means no bearing, and a compass with no DRIVE marker on it is the thing Karen asked
for … quietly not there."*

**The map uses that same door, and it must survive the late arrival.** `MapUi.start` is called with
`geometry` possibly `nil`; `MapUi.setGeometry(geometry)` is the one setter, and the first non-nil
call is what **builds** the static geometry, binds M, and shows the minimap. Idempotent: a second
call builds nothing twice. Same shape as `ReportPanel.setMatch` and `Compass.setBearing`, for the
same stated reason.

In the DEV world no wait is needed: `Hud/init.luau` already requires `ReplicatedStorage.Map`
synchronously at the top of the file.

---

## 6. The push direction, and which direction each role is shown

`Hud.driveBearing(data, team)` is **already** the one rule (task 153), and it is pure:

* a hunter (or any other team, or no team) gets `data.DRIVE_BEARING_DEG` and a `nil` label, which
  means *the compass's own word*, `DRIVE`;
* a player on `data.PUSH_TEAM` gets `data.PUSH_BEARING_DEG` and `data.PUSH_LABEL` (`"ROAD"`);
* a world that states neither gets `nil`, and then **there is no arrow and no word** —
  `Compass.setBearing(nil)`'s rule: *"a marker pointing at zero would be a lie in the shape of a
  fact"*.

**The map does not ask the Hud, and the rule does not move.** The Hud already resolves it **once**,
in the `whenReady` closure that re-runs on `player:GetPropertyChangedSignal("Team")` (because
`/beater` switches the team mid-session), and hands the answer to `Compass.setBearing`. The same
closure hands the same two values to a second drawer:

```lua
local function apply()
    local team = player.Team
    bearing, bearingLabel = Hud.driveBearing(data, if team then team.Name else nil)
    Compass.setBearing(bearing, bearingLabel)
    MapUi.setPush(bearing, bearingLabel)        -- the SAME answer, not a second call to the rule
end
```

One rule, one evaluation, two drawers. A second `Hud.driveBearing` call from inside `MapUi` would be
two readers of one fact that could be given different teams — which is how task 153 round 2's
blocking finding (*"a marker that moved without its label told a beater the drive was south"*) comes
back. `MapUi.luau` is a sibling of `init.luau` and requiring the parent would also be a cycle.

**Where the arrow is drawn:** from the **local player's own marker**, on **both** sizes — a 40 px
bar in `Compass.CONFIG.DRIVE_COLOR` rotated to the bearing with the word at its tip, placed by
`MapUi.facingOffsetPx`. Karen's "showing where to move" is her sentence about the *corner* map, so
the always-on one carries it too.

**The two marks on the player's marker are deliberately different, and they mirror the compass.**

| Mark | Says | Colour | Source |
|---|---|---|---|
| facing wedge, 9 px | "you are **looking** this way" | `Drive.CONFIG.SCORE_HIGHLIGHT_COLOR` (cream) | `Camera.viewHeadingDeg()` |
| push arrow, 40 px, with a word | "**go** this way" | `Compass.CONFIG.DRIVE_COLOR` (red-orange) | `Hud.driveBearing` |

That is exactly the compass's own colour language — a cream centre hairline (`CENTRE_COLOR`) and a
red-orange marker with a word — on an element Karen has already accepted.

---

## 7. Screen space, exactly, and the collisions proved clear

Task 125 round 2 shipped a compass strip over the drive bar and *"it was not seen because the frames
were taken in the Forest Test, where there is no bar at all"*. So the rectangles are written down
and then **asserted by a spec** (§12 case 18), not promised in prose.

### 7.1 What every existing element owns (`HunterHud` has `IgnoreGuiInset = true`, so y = 0 is the true top)

| Element | Rectangle | Symbol |
|---|---|---|
| drive bar | y **8..34**, x cx±260 | `Drive.CONFIG.BAR_TOP_OFFSET` 8, `Size = (520, 26)` |
| tied banner | y **44..74**, x cx±310 | `Drive.CONFIG.TIED_TOP_OFFSET` 44, `Size = (620, 30)` |
| compass strip | y **76..102**, x cx±180 | `Compass.CONFIG.TOP` 76, `WIDTH` 360, `HEIGHT` 26 |
| ammo readout | y H−40..H−16, x W−256..W−16 | `label.Position = (1,−16),(1,−16)`, `Size = (240, 24)` |
| event feed | y H−116..H−16, x 16..436 | `FEED_LEFT/BOTTOM_OFFSET` 16, `FEED_LINES` 5 × 20 |
| crosshair / hit marker | screen centre | `Shotgun.CONFIG.CROSSHAIR_*` |
| scope mask | screen centre, up to the screen's diagonal | `Hud.layoutScope` |
| score panel | centred, 480 × (60 + rows·h + 30) | `Drive.CONFIG.SCORE_PANEL_WIDTH` |
| report panel | centred, 760 × 640 | `Report.CONFIG.PANEL_WIDTH/HEIGHT` |

**One correction to the brief:** the tied banner's rectangle is **44..74**, not 44..68. The brief
read `TIED_TEXT_SIZE` (24); the frame is `UDim2.fromOffset(620, 30)` in `Hud.build`. So the HUD's
top band ends at **102**, and that is the number the map clears.

### 7.2 What the map takes

| Element | Rectangle | Rule |
|---|---|---|
| **minimap** | anchor (1,0), `Position = (1, −12, 0, 108)`, `Size = (D, D)` → x W−12−D..W−12, y **108..108+D** | top-right, **below the whole top band** |
| **mobile button** | anchor (1,0), `Position = (1, −12, 0, 116+D)`, `Size = (48, 48)` | directly under the minimap |
| **full map** | anchor (0.5,0), `Position = (0.5, 0, 0, 108)`, `Size = (w, h)`; `w = min(1100, W−48)`, `h = min(700, H−156)` | **top-anchored at 108**, horizontally centred |

**`MINIMAP_TOP = 108` is the one layout decision that is not literally "the corner".** It is 6 px
below the compass's 102. The reason is arithmetic, not taste: the drive bar is a **520 px** centred
frame and the compass is **360 px** centred, so on a ~400 px phone those two span the **whole
width** of the screen. A minimap at y = 8 would sit on top of the clock in every world that has a
drive — which is task 125 round 2's defect, repeated. 108 is still unambiguously the top-right
corner and nothing in the Hud draws between 102 and the bottom-right readout.

The full map is top-anchored at the same 108 and bounded 48 px off the bottom, so it clears the
compass above it and the ammo readout below it at **every** viewport. The clock, the banner and the
compass stay visible with the map open, which is right: those are the things you want while reading
a map.

### 7.3 `ZIndex`, against the stack task 141 set

The live stack is feed/bar **1**, compass **6..10** (`Compass.CONFIG.Z_INDEX` + 4), scope mask
**11..13**, report panel and score board **15** (`Report.CONFIG.PANEL_Z_INDEX`).

| Map element | `ZIndex` |
|---|---|
| minimap frame, full map frame, mobile button | **6** |
| road and stands (inner geometry) | 7 |
| push arrow and its word, other players' markers | 8 |
| the local player's marker, its wedge, the rim, the scale bar, the "N" | 9 |

**The whole map lives in 6..9**: under the scope's mask (11), under the report and the score board
(15), over the feed and the bar (1). It shares numbers with the compass's 6..10 band and that
decides nothing, because §7.1 and §7.2 show the two never share a pixel — and a spec asserts it.

### 7.4 ~400 px phone width, stated explicitly (brief §5)

The note promises 150 px is readable *"at a phone's ~400 px width without eating a quarter of it"*.
**150/400 = 37.5%, which is not under a quarter** — the note's own sentence does not hold at the
width it names. So the diameter is a clamped function of the viewport, recomputed only when the
viewport changes (the same recompute-on-change rule as `Hud.layoutScope`):

```lua
D = math.clamp(math.min(MINIMAP_DIAMETER_PX, 0.22 * math.min(viewportX, viewportY)),
               MINIMAP_MIN_PX, MINIMAP_DIAMETER_PX)
```

| Viewport | D | share of width | minimap rect | clears |
|---|---|---|---|---|
| 1920 × 1080 | **150** | 7.8 % | x 1758..1908, y 108..258 | everything |
| 400 × 800 | **96** | 24 % | x 292..388, y 108..204 | bar (8..34), banner (44..74), compass (76..102), readout (760..784), feed (684..784) |
| 800 × 400 | **96** | 12 % | x 692..788, y 108..204 | the same |

The mobile button at 48 px lands at y 220..268 on the phone — clear of everything, and over the
thumb's own 44 px minimum.

The full map on the phone: `w = min(1100, 352) = 352`, `h = min(700, 644) = 644`, so x 24..376,
y 108..752 — above the readout at 760 and below the compass at 102.

**A viewport too small for a map at all:** if `H − 156 < 240` the full map is not shown and M warns
once. Stated so the behaviour is a decision rather than a squashed rectangle.

---

## 8. What hides what

| Question | Answer | Why |
|---|---|---|
| minimap while the sight picture is in | **hidden** | §8.1 |
| full map while the sight picture is in | **hidden**, same mechanism | a scope is not a map |
| minimap while the full map is open | **hidden** | the same picture twice, and the full map replaces it |
| either map while the report panel is open | **hidden** | §8.2 |
| the crosshair, when the map opens | **untouched** | §8.3 |
| the mouse cursor, when the map opens | **untouched** | §8.4 |
| aiming and the trigger, when the map opens | **untouched** | §8.4 |

### 8.1 The sight picture

The compass is *hidden* rather than covered *"because a mask cannot cover what is drawn inside its
own circle"*. The minimap is at the **corner**, so at 1080p (eyepiece ≈ 1080 px wide, centred) it is
already outside the circle and the mask's stroke would cover it correctly by `ZIndex` alone. But at
400 × 800 the eyepiece spans y 200..600 and the minimap's bottom edge is at 204: **four pixels
inside**. A minimap with its corner blacked out is worse than no minimap, and "is it outside the
circle" is not provable at every viewport. So it is hidden, explicitly, through
`MapUi.setSuppressed(scoped)` from `Hud.renderScope` — the one place in the repo that already
answers "is the eye at the glass" (`Hud.scopeVisible`). **No new predicate is created.**

### 8.2 The report panel

Two full-screen panels at once is two panels nobody can read, and `Hud.scorePanelVisible` already
takes `reportOpen` for exactly that reason. The map reads the same published predicate,
`ReportPanel.isOpen()`, handed in as a collaborator — **read, never written**. The report panel's
own `Tab` stays entirely its business.

```lua
-- PURE and exported, so a spec asserts all eight combinations with no scope, no report and no world
-- (the `Hud.crosshairVisible` precedent).
function MapUi.fullMapVisible(open: boolean, suppressed: boolean, reportOpen: boolean): boolean
    return open and not suppressed and not reportOpen
end
function MapUi.minimapVisible(open: boolean, suppressed: boolean, reportOpen: boolean, hasGeometry: boolean): boolean
    return hasGeometry and MapUi.CONFIG.MINIMAP_ENABLED and not open and not suppressed and not reportOpen
end
```

### 8.3 The crosshair

**Nothing.** `Hud.crosshairVisible(state, aiming, firstPerson)` is a pure predicate about the gun
and the view, and `FIRST_PERSON` has been the default since task 98, so there is no crosshair to
hide in the game Karen plays. Adding "is the map open" to that predicate would be the previous
project's named killer — *"one predicate answered two unrelated questions, so mounting hid both the
crosshair and the weapon"* — rebuilt on purpose.

### 8.4 The cursor, the trigger and the aim

**The full map takes none of them, and that is a decision with a reason.** There is nothing to click
on it: no waypoint, no ping, no row (brief §4). `ReportPanel` frees the mouse because the player
clicks rows, and then it must hold the trigger or *"clicking a row in the report would also fire the
gun"*. The map has no rows, so freeing the mouse would buy nothing and would cost the camera its
lock while the player is standing in a drive.

So the map **does not call** `Cursor.requestFree`, `Cursor.release`, `Input.requestHold` or
`Input.releaseHold`. If a later task makes the map clickable, it asks `PlayerScripts.Camera.Cursor`
— the **one writer** of `MouseBehavior`, `MouseIconEnabled`, `MouseDeltaSensitivity` and
`Mouse.Icon` — with the tag `"map"`, exactly as `ReportPanel` does with `"report"`. It never writes
the mouse.

One consequence named rather than hidden: with the map open a click still fires the gun. That is
correct for a half-transparent overlay the player chose to put up, and `onFire` fires down the
**camera** ray (`camera.CFrame.LookVector`), not at the mouse, so the shot goes where the view
points whatever is drawn over it.

---

## 9. The input

### 9.1 M is free, checked against every binder in the repo

There are exactly **two** callers of `ContextActionService:BindAction` in `src/`:

| Binder | Actions | Keys |
|---|---|---|
| `src/client/Weapon/Input.luau` | `DrivenHunt.Weapon.Fire` / `.Reload` / `.SelectAmmo` / `.Aim` | MouseButton1, ButtonR2, **R**, ButtonX, **X**, DPadLeft, MouseButton2, ButtonL2 |
| `src/client/Hud/ReportPanel.luau` | `DrivenHunt.Report.Toggle` / `.Back` / `.Open` / `.Up` / `.Down` / `.PageLeft` / `.PageRight` | **Tab** (`Report.CONFIG.TOGGLE_KEY`), Backspace, Return, Up, Down, Left, Right |

Test fixtures bind **T** (`zz_tie_to_a_tree.spec`), **Q** (`weapon_client.spec`) and **F**/**R**
(`input_driving.spec`). **M appears nowhere**, in `src/` or in `tests/`.

### 9.2 The binding

```lua
local TOGGLE = "DrivenHunt.Map.Toggle"      -- the reserved prefix: a grep for "DrivenHunt.Map."
                                            -- finds every binding this module owns
ContextActionService:BindAction(TOGGLE, on(MapUi.toggle), false, Enum.KeyCode.M)
```

* **Service:** `ContextActionService`, bound by `MapUi` and by nothing else.
* **Priority:** `createTouchButton = false` and **no priority argument** — the same three-argument
  shape every other binding in this repo uses. No system competes for M, so a priority would be a
  number with nothing to order.
* **It PASSES, never sinks.** `Enum.ContextActionResult.Pass`, like every handler in the repo, for
  the reason `Weapon.Input`'s header gives: *"Sink on MouseButton1 or R would swallow the Task 6
  input probe, which is the harness's evidence that input arrives at all."*
* **M closes it too** (brief §1.4): one toggle, one key. **`Escape` is not bound** — it belongs to
  the Roblox menu and cannot be taken (`ReportPanel`'s `bind()` says so).
* **No `SetCoreGuiEnabled` call.** The Hud is the one caller of it and it has exactly one call,
  for Tab. M is not a CoreGui key, so the map adds none.
* `MapUi.boundActions(): { string }` returns the sorted list, so a spec reads it instead of
  hard-coding a name — the `ReportPanel.boundActions` precedent.

---

## 10. The mobile button

| | |
|---|---|
| **What** | a `TextButton` named `MapButton`, created by `Hud.build`, filled and driven by `MapUi` |
| **Where** | directly under the minimap: anchor (1,0), `Position = (1, −12, 0, 116 + D)` |
| **Size** | **48 × 48 px** — over the ~44 px thumb target, square, with `UICorner` 0.5 and the minimap's own rim colour |
| **Label** | `"MAP"`, `Enum.Font.Code`, the black `UIStroke` every label in this Hud wears |
| **What it does** | `MapUi.toggle()` on `Activated` — the **same** entry point M uses, so there is one toggle and not two |
| **Shown when** | `UserInputService.TouchEnabled` is true |
| **Owner** | `Hud.MapUi`. It is drawn, so it belongs to the one owner of anything drawn |

```lua
-- PURE, because a Studio Play on a PC has TouchEnabled false and a spec cannot change that.
function MapUi.buttonVisible(touchEnabled: boolean): boolean
    return touchEnabled and MapUi.CONFIG.BUTTON_ENABLED
end
```

The spec asserts both values of the predicate **and** that the live button's `Visible` equals
`UserInputService.TouchEnabled`, so the wiring is checked without needing a phone.

**One hazard, named and bounded.** `Weapon.Input` binds `MouseButton1` / `ButtonR2` and **no touch
input**, so on a phone a tap on this button cannot reach the trigger at all. On a device with both a
touchscreen and a mouse (`TouchEnabled` and `KeyboardEnabled` both true) a mouse click on it is a
`MouseButton1` and **would** also fire. The cost is one shell, fired down the middle of the screen,
on a device that also has M. It is not designed around, because the alternatives are worse: relying
on a `TextButton` to swallow the click is *"a guess about engine behaviour"* in `Weapon.Input`'s own
words, and `GuiButton.Modal` would free the mouse and fight `Camera.Cursor`, the one writer of it.
Queued as **155b**: if Karen ever meets it, the fix is a tagged `Input.requestHold("map-button")`
around the press.

---

## 11. The redraw budget

### 11.1 The signal, and why it is not `RenderStepped`

**`RunService.Heartbeat` with an accumulator at `1 / TICK_HZ`** — the exact shape `Hud.useMatch`
already uses for the drive clock (`sinceTick += dt; if sinceTick < 0.25 then return end`).

The compass uses `RenderStepped` and its own comment says why: *"a compass that updates on an event
is a compass that lags the turn that caused it"* — it tracks the **view**, which changes every frame
a mouse moves. **A map tracks positions**, which change at the replication and physics rate, not the
draw rate. The measurement: a Roblox Humanoid walks 16 studs/s, so 0.8 studs per 20 Hz tick; at the
minimap's 150 px / 300 studs that is **0.2 px**, and at the full map's 0.64 px/stud it is 0.5 px.
Under one pixel either way. Redrawing 20 times a second instead of 60 costs nothing anyone can see
and saves two thirds of the work on the device that has least of it.

The facing wedge also reads the **view**, at 20 Hz, so it lags a turn by up to 50 ms. Accepted and
stated: the wedge answers "which way am I pointing", not "aim with this".

### 11.2 Exactly what one tick does

`Players:GetPlayers()` is called **once per tick**, never inside a loop — the hoisting task 153's
review asked for (*"`Players:GetPlayers()` is walked once per live line per Heartbeat rather than
once per Heartbeat"*).

1. one `Workspace.CurrentCamera.ViewportSize` read, compared with the last one; the layout is
   recomputed **only on a change** (`Hud.layoutScope`'s rule);
2. one `Camera.viewHeadingDeg()` call;
3. **exactly one drawer is live** — the minimap when closed, the full map when open — so the work
   below happens once, not twice;
4. the minimap only: one `inner.Position` write, which moves all the geometry (§4.5);
5. per player, ≤ 16: `player.Character`, `.PrimaryPart`, `.Position`, one `MapUi.project`
   (two subtractions, two multiplications, one compare), one `Frame.Position` write, one `Visible`
   write, one `BackgroundTransparency` write (0, or `PINNED_TRANSPARENCY` when pinned);
6. the local marker only: one wedge `Rotation` write, one wedge `Position` write, and the push
   arrow's two writes.

**Ceiling: ~120 property touches per tick, 20 times a second.** And the three things the brief asks
to be shown absent:

* **no clone** — every frame is created once (`Instance.new` appears only in the build path; the 16
  markers are pre-built and hidden when unused, the shape `Hud.build`'s feed lines and score rows
  already have);
* **no raycast** — nothing is measured against the world; every number came off a frozen table or a
  replicated `Position`;
* **no `GetPartBoundsInRadius`**, and no `GetTagged`, and no `FindFirstChild` in the tick (every
  node is held in a local from the build).

### 11.3 Static geometry, built once

33 road segments + 9 stands + the rim + the "N" + the scale bar and its label + the push arrow and
its word + 16 markers (+1 wedge) ≈ **64 frames per drawer**, built once per world, at
`MapUi.setGeometry`'s first non-nil call. The road is drawn as rotated `Frame`s — the same
no-asset technique `Compass`'s chevron (`Rotation = 45`) and `ReportPanel`'s thirteen-part
silhouette already use, *"no art, no mesh and no `ViewportFrame`"*.

---

## 12. How a player's position is read

`ForestTest.realBeaters` (in **`src/server/ForestTest/init.luau`** — the server half, not the shared
data) is the precedent shape, and the map copies its three steps on the client:

```lua
-- WHO IS DRAWN, as a pure function over a list this module did not fetch, so every absent case is
-- assertable with ONE player (the `ForestTest.realBeaters` shape, client-side).
export type MarkerSource = { userId: number, team: string?, position: Vector3? }

function MapUi.pointsFor(sources: { MarkerSource }, view: MapView, localUserId: number)
    : { { userId: number, u: number, v: number, pinned: boolean, mine: boolean, team: string? } }
```

The live reader that feeds it:

```lua
for _, player in ipairs(Players:GetPlayers()) do
    local character = player.Character
    local root = character and character.PrimaryPart
    table.insert(sources, {
        userId = player.UserId,
        team = if player.Team then player.Team.Name else nil,
        position = if root then (root :: BasePart).Position else nil,   -- nil, never a guess
    })
end
```

| Case | What is drawn |
|---|---|
| no character yet (joining, respawning) | `Character` is nil → `position` nil → **no marker**, the frame is hidden |
| a streamed-out character | `PrimaryPart` is nil → **no marker**. The map never invents a last-known position: a stale dot is a lie about where somebody is |
| dead (`Humanoid.Health == 0`, character still there) | **drawn**, where the body is. It is where the player is |
| out of the view's range | **pinned to the border** at `PINNED_TRANSPARENCY` (0.45), never hidden — brief §1.7, `Compass.offsetPx`'s rule, and Etheroit's *"pinned … will stick on the border instead of disappearing"* |
| no team | drawn in `Drive.CONFIG.TEXT_COLOR` |
| more than 16 players | the first 16 in `GetPlayers()` order are drawn and `MapUi.stats().overflow` counts the rest. A silent drop is a lie; 10–16 is the design's own roster (`PROJECT_CONTEXT.md`) |

**Colours are the repo's own, not new ones** (brief §1.6, and styling never blocks):

| Marker | Colour | Already used for |
|---|---|---|
| the local player | `Drive.CONFIG.SCORE_HIGHLIGHT_COLOR` | your own row on the score board |
| a Drivers/beater | `Drive.CONFIG.DRIVER_COLOR` | the drive bar's DRIVER badge |
| a Shooters/hunter | `Drive.CONFIG.SHOOTER_COLOR` | the drive bar's SHOOTER badge |
| no team | `Drive.CONFIG.TEXT_COLOR` | every HUD label |

`player.Team` is **the one representation of the team** on the client — the same door
`Match.myTeam` reads and the same one `Hud.start` reads for the compass's bearing. `Match.Body` is
its only writer, on the server.

---

## 13. The public interface

`src/client/Hud/MapUi.luau`, returning `MapUi`. Nothing here fires a remote; there are none.

```lua
-- ------------------------------------------------- the arithmetic, PURE and exported
MapUi.project(worldX: number, worldZ: number, view: MapView): (number, number, boolean)
MapUi.facingOffsetPx(bearingDeg: number, radiusPx: number): (number, number)
MapUi.minimapView(centre: Vector3, diameterPx: number, rangeStuds: number): MapView
MapUi.fullView(bounds: Bounds, widthPx: number, heightPx: number): MapView
MapUi.diameterFor(viewportX: number, viewportY: number): number
MapUi.scaleBarStuds(pxPerStud: number, panelWidthPx: number): (number, number)   -- (studs, metres)
MapUi.pointsFor(sources, view, localUserId): { MarkerPoint }
MapUi.fullMapVisible(open, suppressed, reportOpen): boolean
MapUi.minimapVisible(open, suppressed, reportOpen, hasGeometry): boolean
MapUi.buttonVisible(touchEnabled: boolean): boolean

-- ------------------------------------------------- the world's statement, PURE
MapUi.geometryFromForestTest(data: any): MapGeometry
MapUi.geometryFromMap(map: any): MapGeometry
MapUi.geometryFor(world: string, forestTest: any?, map: any?): MapGeometry?

-- ------------------------------------------------- state: five values, one writer (this module)
--   open, suppressed, geometry, pushBearingDeg, pushLabel
MapUi.start(frames: { miniMap: Frame, fullMap: Frame, button: TextButton? }, collaborators: {
    Camera: any?,          -- for viewHeadingDeg only. May be nil: then there is no facing wedge.
    Report: any?,          -- ReportPanel, for isOpen(). May be nil.
    geometry: MapGeometry?,-- may arrive later through setGeometry
    userId: number,
})
MapUi.setGeometry(geometry: MapGeometry?)      -- the late-arrival door; builds once
MapUi.setPush(bearingDeg: number?, label: string?)
MapUi.setSuppressed(on: boolean)               -- a tagged NEED from Hud.renderScope; this module writes
MapUi.toggle()
MapUi.setOpen(next_: boolean)
MapUi.render()                                 -- PUBLIC: a spec cannot wait 50 ms reliably
MapUi.applyVisibility()

-- ------------------------------------------------- what a spec reads instead of guessing
MapUi.isOpen(): boolean
MapUi.geometry(): MapGeometry?
MapUi.pushBearingDeg(): number?
MapUi.pushLabel(): string?
MapUi.markerPoints(): { MarkerPoint }          -- what is ACTUALLY on screen, read off the frames
MapUi.boundActions(): { string }
MapUi.stats(): { ticks: number, toggles: number, pinned: number, overflow: number,
                 builtAt: number?, elapsed: number }
MapUi.CONFIG                                   -- §14
```

And on the Hud, the accessors a spec uses rather than reaching through `PlayerGui` by name — the
`Hud.compass()` / `Hud.reportPanel()` shape:

```lua
Hud.MapUi = MapUi
Hud.minimap(): Frame?
Hud.fullMap(): Frame?
Hud.mapButton(): TextButton?
```

**`render` and the predicates are public for the reason `Hud.renderScore` and `ReportPanel.render`
are**, stated in their own headers: a spec cannot turn a camera, cannot walk a second player across
a wood and cannot wait on a tick, so the only honest way to prove the picture moves is to hand it
the inputs.

### What it reads, and who owns each

| Direction | What | The other side's owner | Shape |
|---|---|---|---|
| `MapUi` ← | `ForestTest.roadZ`, `.standPosition`, `.STAND_COUNT`, `.CENTRE`, `.HALF_SPAN`, `.EXIT_Z`, `.DRIVERS`, `.LINE`, `.BEATER` | `ReplicatedStorage.ForestTest` — **frozen data, no run-time writer** | read |
| `MapUi` ← | `Map.EXPECTED_WORLD`, `Map.ROAD`, `Map.FIELD.bounds` | `ReplicatedStorage.Map` — frozen, deep-frozen, no writer | read |
| `MapUi` ← | the push bearing and its word | `Hud.driveBearing`, resolved once in `Hud.start` | handed in |
| `MapUi` ← | `Camera.viewHeadingDeg()` | `PlayerScripts.Camera` | read, may be nil |
| `MapUi` ← | `ReportPanel.isOpen()` | `PlayerScripts.Hud.ReportPanel` | read |
| `MapUi` ← | `Players:GetPlayers()`, `player.Character.PrimaryPart.Position`, `player.Team` | the engine; `Match.Body` writes `Team` on the server | read |
| `MapUi` ← | `Drive.CONFIG` colours, `Compass.CONFIG.DRIVE_COLOR`, `Report.metres(studs)` | frozen shared tables | read |
| `MapUi` ← | `MapUi.setSuppressed(scoped)` | `Hud.renderScope` states the need | **tagged request**; `MapUi` performs the write |
| `MapUi` → | its own two frames and their children | itself | the only writer |
| `MapUi` → | **nothing else.** No camera, no cursor, no trigger, no team, no boar, no remote | | |

The dependency direction stays one-way everywhere it already is: the camera has no reference to the
Hud, the weapon has no reference to the Hud, and `ReportPanel` has no reference to `MapUi`.

**`Report.metres(studs)` is called for the scale bar**, not the constant. `0.28` is published in
**four** places already (`Report.CONFIG.METRES_PER_STUD`, `Horn.CONFIG`, `Boar.CONFIG.SENSE`,
`ForestTest.SPOOK.METRES_PER_STUD`); the map adds a **fifth reader and no fifth copy**. The four
copies are a log-only observation for the next audit, not this task's to fix.

---

## 14. Numeric targets

`MapUi.CONFIG`, one block so a retune is one diff — the `Compass.CONFIG` shape.

| Name | Value | Why |
|---|---|---|
| `MINIMAP_DIAMETER_PX` | **150** | the Director's start value, at 1080p: 7.8 % of the width |
| `MINIMAP_MIN_PX` | **96** | 24 % of a 400 px phone — under the quarter the note promises (§7.4) |
| `MINIMAP_VIEWPORT_FRACTION` | **0.22** | of `min(viewportX, viewportY)`; 1080p resolves to the full 150 |
| `MINIMAP_TOP` | **108** | 6 px under the compass's 102; the HUD's top band is 8..102 |
| `MINIMAP_MARGIN` | **12** | from the right edge |
| `MINIMAP_RANGE_STUDS` | **300** | 84 m at 0.28 m/stud: two `STAND_SPACING`s, so a beater sees the road and ≥ 2 stands before she reaches them |
| `FULL_MAX_WIDTH_PX` / `FULL_MAX_HEIGHT_PX` | **1100 / 700** | 1080p leaves 108 above and 272 below; the aspect matches the Forest Test's 1720 × 1100 span to 0.5 % |
| `FULL_TOP` | **108** | the same top line as the minimap |
| `FULL_BOTTOM_INSET` | **48** | clears the ammo readout's own 40 |
| `FULL_MIN_HEIGHT_PX` | **240** | below this the full map is not shown and M warns once |
| `GEOMETRY_MARGIN_STUDS` | **60** | the road's ±30 amplitude plus a body's room |
| `ROAD_SAMPLES` | **33** | 50-stud steps over 1,600; worst chord error < 2 studs = **1 px** at 0.64 px/stud |
| `TICK_HZ` | **20** | 0.8 studs of walking per tick = **0.2 px** on the minimap (§11.1) |
| `MAX_MARKERS` | **16** | `PROJECT_CONTEXT.md`: 10–16 players |
| `MARKER_PX` / `OWN_MARKER_PX` | **8 / 10** | a dot you can tell from a stand at 150 px |
| `STAND_PX` | **6** | a square, so a stand is not a player |
| `WEDGE_PX` | **3 × 9** | the facing wedge, offset 8 px along the view bearing |
| `ARROW_PX` | **3 × 40** | the push arrow, in `Compass.CONFIG.DRIVE_COLOR`, with the word at its tip |
| `PINNED_TRANSPARENCY` | **0.45** | `Compass.CONFIG`'s own number, so pinned looks the same everywhere |
| `BUTTON_PX` | **48** | over the ~44 px thumb |
| `PANEL_TRANSPARENCY` | **0.25** | the score panel's, which Karen has accepted |
| `SCALE_BAR_CHOICES_M` | **{25, 50, 100, 200, 500}** | the largest that fits 40 % of the panel width |
| **frame budget** | **≤ 1 ms/tick**, ~120 property touches | §11.2 |
| **static frames** | **≤ 70 per drawer**, built once | §11.3 |

Two switches that are **not** flags, matching `Shotgun.CONFIG.CROSSHAIR_ENABLED` and
`Drive.CONFIG.SCOREBOARD_ENABLED`, which this repo already turns features off with in one line:
`MINIMAP_ENABLED = true`, `BUTTON_ENABLED = true`.

---

## 15. Flag or no flag

**No flag.** Decided, and here is the justification brief §11 asks for.

`docs/design/feature-flags.md` and CLAUDE.md say a **feel-critical** path is born OFF. The two HUD
additions this repo has already shipped are the precedent and they are two for two: **`Compass`
(task 125)** and **`ReportPanel` (task 124)** are both drawn, both pure feel, and **neither has a
row in `Flags.DEFAULTS`**. A map is the same class of thing: it covers no existing pixel, changes no
existing rule, takes a key nothing else binds, and reads data that is already replicated.

Three further reasons, each a cost:

1. **OFF is indistinguishable from "not built".** The flag's job is to let a feel-critical path
   *merge* while Karen judges it. Nothing here needs that cover: if she hates the map, the rollback
   is `MINIMAP_ENABLED = false` (one line, §14) or a revert of one new file.
2. **`Flags.MAX_FLAGS` is 12 and nine rows are declared.** Spending a tenth of a scarce, audited
   budget on a thing with no OFF-state question is the wrong trade.
3. **The `expires` rot tripwire is a real cost for no benefit.** A row born today needs a date
   within 21 days (`feature-flags.md` §12); an `expires` in the past fails
   `tests/server/flags.spec.luau`, which fails the harness, which **blocks whatever gate runs that
   day** — as task 149b and `FIRST_PERSON` both record. Three rows in this table have already had to
   have their dates moved for exactly that.

**There is therefore no boundary flag read**, and nothing in `MapUi` calls `Flags.isOn`.

---

## 16. How it is tested

### 16.1 The gate: the ONE-PLAYER `test`, and the file-by-file proof

Files this design touches:

| File | In `TWO_PLAYER_PATHS`? | In `CODE_PATHS`? | `BLAST_RADIUS` scope |
|---|---|---|---|
| `src/client/Hud/MapUi.luau` (new) | **no** | yes | `hud` |
| `src/client/Hud/init.luau` | **no** | yes | `hud` |
| `tests/client/map_ui.spec.luau` (new) | **no** | yes | `hud`, once added to `SCOPE_SPECS` |
| `tests/client/input_scenarios.txt` | **no** | yes | → `all` (unmapped under `tests/`) |
| `tools/studio_mcp.py` (one `SCOPE_SPECS` row) | **no** (the Director's 2026-10-03 decision puts the harness with the tools) | yes | → `all` (`FAIL_SAFE_PATHS`) |
| `GAME_DESIGN.md`, `docs/design/map-ui.md`, `docs/research/INDEX.md`, `TASKS.md` | no | no | docs |

The explicit `TWO_PLAYER_PATHS` list is `src/server/Match/`,
`src/server/MatchBoot.server.luau`, `src/client/Match/`, `src/client/MatchBoot.client.luau`,
`src/shared/Drive/`, `tests/client/Role.luau`, `tests/server/match_*.spec.luau`,
`zz_drive_boundary.spec.luau`, `tests/client/match_client.spec.luau`, `outfit_client.spec.luau`,
`zz_tie_to_a_tree.spec.luau`. **Not one of them is touched**, and §5.3 is where that cost was paid:
the DEV stands are deferred precisely so `src/server/Match/Markers.luau` stays out of this task.

So: `test` is the gate, and **`test2` is N/A** with the reason — hud-only change, no
`TWO_PLAYER_PATHS` file.

**The one thing one player cannot prove, said out loud.** Karen's requirement 4 is *"can see other
players on map moving"*, and the only evidence that a **second real player's** marker appears is a
second client. The marker code is pinned by `MapUi.pointsFor` over a synthetic roster (every absent
case, the pin, the overflow, the colours), so the arithmetic and the drawing are provable with one
player — but "her daughter shows up as a blue dot" is a **playtest** item for Karen, and the
Director may choose to run `test2` once by hand to see two markers. It is not a gate item, because
`tools/agents.py`'s list is what decides the gate and this change is not in it.

**`tools/studio_mcp.py selftest` fails if a spec file belongs to no scope**, so the new spec must be
added to `SCOPE_SPECS["hud"]` in the same commit — otherwise `--scope auto` would quietly consider
it covered by nothing.

### 16.2 Server specs

**None, and that is the right answer.** Every assertion here is about a client module's pure
arithmetic and about pixels in `PlayerGui`, and `compass.spec.luau` is the model: it is a client
spec, it runs in the player's client, and it asserts the convention and the movement. No existing
server spec is touched (`forest_stand.spec.luau` is in the `boar` scope and this task has no
business in it).

### 16.3 The client spec — `tests/client/map_ui.spec.luau`

Model: `tests/client/compass.spec.luau`. TestEZ `describe`/`it`/`expect`.

**The arithmetic (no world, no camera, no player)**

1. **north is up, east is right.** `project(cx, cz + 100)` → `v < 0`, `u == 0`; `project(cx + 100, cz)`
   → `u > 0`, `v == 0`; both to the exact pixel from `pxPerStud`.
2. **the convention is the compass's, compared and not copied.** For each of four offsets, assert
   `facingOffsetPx(Compass.headingDeg(offset), r)` points the same way as `project` puts the offset.
   This is task 129's lesson made into a case.
3. **one scale on both axes.** For a diagonal pair, the projected pixel distance equals
   `studDistance × pxPerStud` to 1e-6. A map with two scales would pass every axis-aligned case and
   lie about every diagonal.
4. **the disc pin.** A point 400 studs out on a 300-stud minimap: `inside == false` and
   `u² + v² == r²` to 1e-6.
5. **the rect pin.** A point outside the full map's bounds is clamped to the border and
   `inside == false`; a point inside is returned unchanged with `true`.
6. **the diameter rule.** `diameterFor(1920, 1080) == 150`; `diameterFor(400, 800) == 96`;
   `96 / 400 < 0.25` — the note's own promise, asserted.
7. **the scale bar** picks the largest choice that fits 40 % of the panel, at 1080p and at 400 px.

**The world's statement (pure, against the real modules)**

8. **the road IS `ForestTest.roadZ`.** Every sampled point of `geometryFromForestTest(ForestTest).road`
   equals `ForestTest.roadZ(x)` exactly. There is no second curve.
9. **the stands ARE `ForestTest.standPosition`.** `#stands == ForestTest.STAND_COUNT`, and each
   equals `standPosition(i)`'s (x, z) exactly.
10. **the road's centre lands at the centre**, and **stand 1 and stand 9 land either side of it**,
    in x order, `8 × STAND_SPACING × pxPerStud` apart.
11. **the bounds hold everything the world states**: `EXIT_Z`, the driver start, both ends of the
    stand line, all strictly inside.
12. **the DEV world** gets `Map.ROAD`'s two points, `Map.FIELD.bounds` widened to hold them, and
    **`#stands == 0`** — the deferral of §5.3 asserted, so the next task finds a case to change
    rather than a comment to read.
13. **a world that states nothing**: `geometryFor("something-else", nil, nil) == nil`, and with nil
    geometry `MapUi.geometry()` is nil, both frames are `Visible == false`, and
    `boundActions()` is empty. *Visibly no map, not a blank panel.*

**The picture on screen**

14. **it exists inside the one Hud ScreenGui.** `Hud.minimap()` and `Hud.fullMap()` are descendants
    of `player.PlayerGui`; the minimap is `Visible == true` with `ClipsDescendants == true`; the
    full map is `Visible == false`. (The `report_panel.spec` "it exists, hidden" case is the model.)
15. **THE RECTANGLES DO NOT OVERLAP.** Read `AbsolutePosition` and `AbsoluteSize` off the live
    minimap, the mobile button, the drive bar, the tied banner, the compass strip and the ammo
    readout, and assert the map's rectangles intersect none of the others. **This is the most
    valuable case in the list**: task 125 round 2 shipped a strip over the clock and the frames did
    not show it because they were taken in a world with no clock. A rectangle intersection does not
    care which world it is run in.
16. **the toggle.** `MapUi.toggle()` → full map visible, minimap hidden; again → the reverse.
    `fullMapVisible` and `minimapVisible` asserted for **all** combinations of their arguments.
17. **the suppression.** `MapUi.setSuppressed(true)` hides both at once and `setSuppressed(false)`
    puts back exactly what was there (open stays open, closed stays closed).
18. **nothing else moved.** `Hud.isCrosshairVisible()`, `Hud.compass().Visible` and
    `Hud.isDriveBarVisible()` are read before and after an open/close cycle and are unchanged.
19. **the markers.** `pointsFor` over a synthetic roster: a nil position draws nothing; a far one
    comes back pinned; 20 sources draw 16 and `stats().overflow == 4`; the local one is `mine` and
    carries the highlight colour. Then the live `markerPoints()` contains the local player exactly
    once.
20. **the push direction is the Hud's rule and not a copy.** After `Hud.start`,
    `MapUi.pushBearingDeg()` and `MapUi.pushLabel()` equal
    `Hud.driveBearing(ForestTest, player.Team and player.Team.Name)`, for a hunter **and** for
    `ForestTest.PUSH_TEAM`; and with `setPush(nil, nil)` there is no arrow and no word.
21. **the button's predicate.** `buttonVisible(true)` true, `buttonVisible(false)` false, and the
    live button's `Visible == UserInputService.TouchEnabled`.
22. **the tick is not per frame.** `stats()` carries `ticks` and `elapsed`; assert the measured rate
    is within 25 % of `CONFIG.TICK_HZ`, and that `ticks` is far below the frames elapsed over the
    same window. A spec that only checked "it redraws" would pass a `RenderStepped` map.
23. **the map is left as this world had it** — the last `describe`, the shape `compass.spec` ends
    with: restore `open = false` and the player's own push bearing, so a harness run never leaves
    Karen's screen with a map open.

### 16.4 Harness input — the player's path, not the harness's (rule 6)

A new scenario in `tests/client/input_scenarios.txt`:

```json
{
    "name": "map-toggle",
    "spec": "ClientTests.map_ui.spec",
    "steps": [
        { "device": "keyboard", "action": "keyPress", "key": "M" },
        { "device": "wait", "ms": 700 },
        { "device": "keyboard", "action": "keyPress", "key": "M" },
        { "device": "wait", "ms": 400 }
    ]
}
```

The spec then asserts `MapUi.stats().toggles >= 2` and that the frame ended **closed** — so **M
really reaches us from a real key**, and not just that `MapUi.toggle()` works when called. Belt and
braces: `ContextActionService:GetAllBoundActionInfo()["DrivenHunt.Map.Toggle"] ~= nil`, the
`report_panel.spec` precedent, plus an assertion that `Enum.KeyCode.M` appears in no other binder's
key list.

**What the harness cannot express** (TASKS.md Task 6): **touch**, gamepad, `textInput`,
frame-counted holds, and input aimed at an instance. So **the mobile button cannot be driven by the
harness at all** — hence the pure predicate in case 21, plus a screenshot in Studio's device
emulator, plus Karen's phone. Said here so nobody later reports a touch result they could not
produce.

### 16.5 Screenshots (rule 5) — four, taken and **inspected**

`python tools/studio_mcp.py capture <name>`, in the **Forest Test**, because that is where Karen
plays and where a world with no drive bar hid task 125's defect:

1. standing at a stand: the minimap top-right, the road curving through it, two stands, the cream
   wedge and the red-orange DRIVE arrow. **Check:** the circle is round (§17), nothing is clipped,
   nothing sits on the compass.
2. M pressed: the full map, all nine stands, the whole road, the scale bar reading in metres, the
   "N" at the top, the minimap gone.
3. as a **beater** (`DHForestStartRole`): the arrow reversed and the word reading **ROAD**, not
   DRIVE — the exact defect task 153 round 2 blocked on.
4. in Studio's device emulator at a phone profile: the 96 px minimap, the 48 px MAP button, and
   clear air between the map and the clock, the compass and the readout.

### 16.6 What only Karen's eye can answer

The diameter, the 300-stud range, the colours, whether north-up reads right, whether top-right is
the corner she meant ("left or right"), whether the full map should dim the world behind it, and
whether an always-on minimap is wanted at all. The arithmetic is all provable; the **look** is hers.
That is the whole point of §4.2 being pure.

---

## 17. Not verified (no Studio in an Architect run)

1. **`ClipsDescendants` with `UICorner` 0.5 giving a true round clip.** If the engine clips to the
   square, the minimap is a rounded square. That is a **look** issue, not a correctness one; the
   fallbacks are living with it (Karen's call) or an uploaded circular mask (an upload, her OK and
   a moderation wait, which is why it is not the first choice). **Screenshot 1 is the check.**
2. **`UserInputService.TouchEnabled` in Studio's device emulator.** If it stays false there, the
   mobile button cannot be seen in Studio and judging it is a **NEEDS KAREN** item on her own phone.
   The predicate in §10 is unaffected either way.
3. **Whether a `GuiButton` tap can reach `ContextActionService`'s FIRE on a touchscreen PC** (§10).
   Bounded to one wasted shell and queued as 155b.
4. **Whether runtime `CollectionService:AddTag` replicates to clients**, and what streaming does to
   a 1,120-stud post line on a client. Both are reasons §5.3 does **not** take the tag route; neither
   is a dependency of anything this task builds.
5. **M against Roblox's own CoreGui bindings.** Tab and Escape are the two this repo has met and
   both are documented in `ReportPanel`. If M turns out to be taken, it is **one value** —
   `MapUi.CONFIG.TOGGLE_KEY` — and changing it is Karen's call, not a redesign. (Written the way
   `drive-report.md` §8.3 wrote the same risk for Tab.)

---

## 18. Deviations, named (brief §13)

1. **`docs/design/drive-report.md` §8.3 is stale about the stack.** It says the report panel is
   *"ZIndex **10** (over the feed at 1, the score panel at 5)"*. The live code is
   `Report.CONFIG.PANEL_Z_INDEX = 15`, and since task 141 the **score panel shares it**
   (`panel.ZIndex = Report.CONFIG.PANEL_Z_INDEX` in `Hud.build`). §7.3 of this document is the
   current stack; the older sentence is superseded and should not be read as the contract.
2. **The brief's tied-banner rectangle is 44..68; it is 44..74** (§7.1). The frame is 30 px tall,
   not 24.
3. **The note's "150 px … without eating a quarter of [a 400 px screen]" does not hold** —
   150/400 = 37.5 %. §7.4 keeps 150 at 1080p and makes the diameter a clamped function of the
   viewport so the promise is true at the width the note names.
4. **`Compass`'s two-writer arrangement for its frame's `Visible` is deliberately not copied**
   (§3.3). The map uses this repo's own tagged-request pattern instead, so `MapUi` is the single
   writer of its own frames.
5. **The minimap is at y 108, not at the very top of the corner** (§7.2), and the reason is the
   520 px drive bar at phone width.
6. **`docs/design/camera.md`, `drive.md` and `beater-kit.md` are contradicted nowhere.** The map
   never writes the camera (camera design §6.2's rule holds: the Hud reads and never writes), never
   touches the drive's bar or feed (drive design §9.3), and takes the beater's push direction from
   `ForestTest.PUSH_*` through `Hud.driveBearing` exactly as task 153 left it.
7. **`GAME_DESIGN.md`'s *System owners* row for "UI / anything drawn" must gain the map and
   `Hud.MapUi`** — rule 3 requires the table to mirror this design. The Builder updates it in the
   same commit.

---

## 19. External sources

Carried from `docs/research/2026-10-11-map-ui.md`, with licence and maintenance status, what each
does well and badly, and what is taken.

| Source | Licence | Maintenance | Does well | Does badly | Taken |
|---|---|---|---|---|---|
| [Roblox: Viewport frames](https://create.roblox.com/docs/ui/viewport-frames), source at [Roblox/creator-docs](https://github.com/Roblox/creator-docs) | **CC BY 4.0** prose, **MIT** code samples | **active** (2,173 commits on main, open PRs) | names this exact use case first — *"A minimap of your game directly in the corner of a user's screen"* — and is the official, maintained answer | describes the one option that **cannot draw our ground** | **nothing.** The one licence here that permits copying describes the option we are not using |
| [Add terrain support for ViewportFrame](https://devforum.roblox.com/t/add-terrain-support-rendering-from-outside-its-parental-structure-for-viewportframe/219346), and [Rendering terrain in a viewportframe](https://devforum.roblox.com/t/rendering-terrain-in-a-viewportframe/1931034) | feature request, no grant | **still open**, six years | states the forcing fact plainly: *"You can't put Terrain instances under ViewportFrame"* | it is a request, not a fix | **the decision.** This is why §2.1 exists |
| [Creating An Efficient\* Viewport Minimap](https://devforum.roblox.com/t/creating-an-efficient-viewport-minimap/1179030) | devforum post, **no grant** — readable, not copyable | **2021, inactive**; a post, not a module | the only end-to-end build of option A, measured on 17,315 parts; honest about its own asterisk | per-frame cloning and Region3 do not scale; the author says image-based *"substantially outperform"* it | **nothing copied.** Its asterisk is cited as evidence against option A |
| [ShouxTech/roblox-minimap](https://github.com/ShouxTech/roblox-minimap) | **NONE declared** (all rights reserved) | **unmaintained**, last push 2021-04-21, 10 commits | the shape: markers over a map, team-coloured, player-centred | no licence, so not one line is usable; unmaintained | **the pattern only** — team-coloured markers over a projected map (§12). No code |
| [Minimap Render & Gui](https://devforum.roblox.com/t/minimap-render-gui/1995940) (Etheroit, RainyLofi; [dv8-studio/renderer](https://github.com/dv8-studio/renderer)) | **not stated** — readable, not copyable | **2022, inactive** | the blip rule worth stealing: markers coloured by team, and an out-of-range one *"pinned (will stick on the border instead of disappearing when they're out of bounds)"* | needs pre-rendered chunks, which means an upload per world per change | **the border-pinning rule** (§4.2, §12), which this repo **already ships** as `Compass.offsetPx` |
| [RoRender V4](https://devforum.roblox.com/t/rorender-v4-minimap-generator/3525559) | render plugin open source; **web editor paid** | **active**, a ground-up V4 | the best-looking result there is: a raytraced picture of the real place | an image goes stale silently, and both our worlds are under construction this month; a subscription | **nothing now.** Named as the seam for a later task: an `ImageLabel` can go **under** this overlay without changing the projection |
| [`ViewportFrame` Upgrades](https://devforum.roblox.com/t/viewportframe-upgrades/3953219) · [Are ViewportFrames more/less efficient than images?](https://devforum.roblox.com/t/are-viewportframes-moreless-efficient-than-images/254323) | devforum, no grant | active thread / 2019 | the 1024 × 1024 render-target cap and the double-render cost, which is the mobile argument | anecdotal | **the mobile reason** in §2.1 |
| [Pete Hodgson, *Feature Toggles*](https://martinfowler.com/articles/feature-toggles.html) | article, no grant | active reference; this repo already cites it in `src/shared/Flags/init.luau` | the lifecycle that `feature-flags.md` is built on | nothing relevant | **the reasoning in §15** for why this path is **not** flagged |

### What is borrowed, and from where (rule 2)

Nothing in this design is invented:

* the **bearing convention** is `Compass.headingDeg`'s, with a second axis and one minus sign;
* the **border pin** is `Compass.offsetPx`'s, generalised from a strip to a rectangle and a disc —
  and it is also Etheroit's rule and ShouxTech's shape;
* the **tagged request** for suppression is `Camera.Cursor.requestFree`'s, which
  `Input.requestHold` already borrowed once;
* the **module-under-the-Hud** shape, the frame built by `Hud.build`, the pure exported predicates
  and the `stats()` counters are `Compass`'s and `ReportPanel`'s;
* the **late-arrival setter** is `ReportPanel.setMatch`'s and `Compass.setBearing`'s, for task 134's
  bug;
* the **accumulated Heartbeat tick** is `Hud.useMatch`'s drive clock;
* the **recompute-only-on-change layout** is `Hud.layoutScope`'s;
* **lines and shapes out of `Frame`s with `Rotation` and `UICorner`** is `Compass`'s chevron and
  `ReportPanel`'s thirteen-part silhouette — *"no art, no mesh and no `ViewportFrame`"*;
* the **colours** are `Drive.CONFIG`'s and `Compass.CONFIG`'s, already on Karen's screen;
* the **"move the map under the player"** inner-frame offset is the image-based option's own
  mechanism (note option B), borrowed without its image.

What is genuinely new is **one multiplication per axis** — arithmetic this repo already contains for
one axis.

---

## 20. Open decisions

### For Karen (feel) — **none of these blocks building.** Every one has the Director's start value in §14.

1. **Diameter and range.** 150 px / 300 studs. Too small to read, or too big a bite out of the
   screen? Is 84 m of look-ahead enough for a beater?
2. **Top-right or top-left.** She said *"left or right corner"*; the Director chose **right**
   (the left is the event feed's side at the bottom, and the right is where the ammo readout already
   trained her eye). One constant.
3. **Colours.** Team colours are the drive bar's and the own-marker is the score board's highlight —
   all three already on her screen. Styling never blocks.
4. **Should the full map dim the world behind it?** Start value: **no dim**, panel transparency 0.25
   (the score panel she already accepted). A dim is one property.
5. **Should the minimap be always on?** Start value: **yes** (`MINIMAP_ENABLED = true`). Off is one
   line.
6. **Does north-up read right, or does she want the picture to turn?** Start value: **north up** at
   both sizes, and §2.6 is why turning it is not a one-line change. If she wants it, it is a task
   with the heading question answered once, by `Camera.viewHeadingDeg` and nothing else.
7. **The mobile button on her phone** — a NEEDS KAREN click if the device emulator does not report
   `TouchEnabled` (§17.2).
8. **Does her daughter's marker actually appear?** The one requirement one client cannot prove
   (§16.1). A playtest, with two clients.

### For the Director (scope) — **none of these blocks building.** Each has a decided default.

1. **The DEV world's stands.** Default: **not in this task**, `stands = {}`, and the DEV map draws
   the road, the bounds and the players (§5.3). Queued as **155a** with the mechanism named:
   `Map.LINE` in `src/shared/Map/init.luau` plus an assertion in
   `tests/server/map_contract.spec.luau`. The reason it is deferred is `TWO_PLAYER_PATHS`, which the
   brief itself forbids this task to touch.
2. **A map image under the overlay.** Default: **later**. The projection is the seam and nothing in
   this design has to change to add one.
3. **155b:** the touchscreen-PC fire-through on the map button (§10), bounded to one shell.
4. **A log-only observation for the next audit:** `0.28` m/stud is published in four shared tables
   (`Report.CONFIG.METRES_PER_STUD`, `Horn.CONFIG`, `Boar.CONFIG.SENSE`, `ForestTest.SPOOK`). The
   map adds a fifth **reader** (`Report.metres`) and no fifth copy, so it is not this task's to fix
   — but four statements of one constant is four places a retune can be forgotten.
5. **Whether `test2` is run once by hand** to photograph two markers (§16.1). Not a gate item.
