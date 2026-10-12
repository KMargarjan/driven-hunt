# HUD clarity: one objective line, one waypoint, one button rail

2026-10-12 · Task 165 · Builder

## What Karen asked for

Verbatim, 2026-10-12 ~10:40:

> "we need to have better map or direction that people has to walk we need to improve design that it
> will be clear to understand what happening / could be buttons on the side for M - map ect"

Three sentences, three requirements:

1. **Direction** — *"better map or direction that people has to walk"*. She cannot tell where to go.
2. **Legibility of the state** — *"clear to understand what happening"*. She cannot tell what the
   game wants from her right now.
3. **Side buttons** — *"could be buttons on the side for M - map ect"*. A thumb has no M key, and
   mobile is in v1 (`docs/PROJECT_CONTEXT.md` build order 4).

## What is on screen today, and why it does not answer her

| Element | Where | What it answers |
|---|---|---|
| Drive bar (1.7a) | top centre, y 8..34 | which drive, which phase, the clock, boars left, my team |
| Tied banner | y 44..74 | I fired toward the drive |
| Compass strip (125, 153) | y 76..102 | which way the drive comes from / which way I push |
| Minimap (155) | top right | the road, the stands, everyone moving |
| Full map on M (155) | centred | the same picture, bigger |
| Start card (158) | upper middle, `Assigning` only | my role, what I may shoot, ten seconds |
| Results table (159) | centred, `Scoring` only | who won |
| Ammo readout | bottom right | barrels and shells |
| Feed (124) | bottom left | what just happened |

Every one of those is a **fact**. Not one of them is an **instruction**. The drive bar says
`DRIVE 1   04:51   BOARS 6   SHOOTER`; it never says *stay on your stand*. The compass says the
drive is north; it never says *that is 400 m away and this is where you walk*. The start card is the
only element that ever gives an instruction (`GET TO YOUR STAND`) and it is up for ten seconds in
one phase and then gone.

So the gap is not information. It is **one line of instruction, continuously, and one place on the
ground to walk to**.

## What the system must do

- **One objective line, always visible**, that reads as a sentence and changes with role × phase.
  Six states: hunter and beater across `Assigning`, `Running`, `Scoring`, plus `Waiting`.
- **One waypoint**, drawn over the world, for the one place this player must be: a hunter's stand,
  a beater's point on the road straight down her push. With a **distance in metres**, and **pinned
  to the screen edge** rather than hidden when it is behind the player.
- The **compass, the minimap and the full map must agree with it** — one evaluation of "where must I
  go", several drawers, which is the rule task 153 round 2 already paid for (*"a marker that moved
  without its label told a beater the drive was south"*).
- A **button rail on the right edge**, labels plus key hints, every button wired to a function that
  already exists. No dead buttons.
- **Readable at 400 x 800** (a phone), and clear of the two corners Roblox reserves for its own
  touch controls.
- **One owner per drawn thing** (rule 3). Everything drawn is `PlayerScripts.Hud`'s; nothing here
  changes that.

### Numeric targets

| Target | Value | Why |
|---|---|---|
| Objective line text size | 24 px | the headline; the drive bar is 20 and the compass 13, so it reads first |
| Objective line band | y 8..40 | the top line of the screen: the first thing read |
| Waypoint distance unit | metres, `Report.metres` | the one conversion in the repo (0.28 m/stud) |
| Waypoint pinned inset | 56 px | clear of the rail on the right and the objective line on top |
| Rail button | 48 x 48 px, 8 px gap | over the ~44 px touch target Roblox's own tutorial sets as a max height |
| Rail top | under the minimap, right edge | the right edge is already the map's column; one category, one place |
| Phone layout | 400 x 800 | task 155's own check size |
| Waypoint update | once a frame | it tracks the VIEW, which is the compass's rule; the map's 20 Hz is for POSITIONS |

## Sources

### A. Roblox Creator Docs — *Wireframe your layouts* and *Implement designs in Studio*

<https://create.roblox.com/docs/tutorials/user-interface-design/wireframe-your-layouts>
<https://create.roblox.com/docs/tutorials/curriculums/user-interface-design/implement-designs-in-studio>

Licence **CC BY 4.0** (stated by the `Roblox/creator-docs` repository); maintained by Roblox, the
curriculum is current.

Fetched, and three sentences decide the layout here:

> "Interacting with UI that are far from the bottom corners of some mobile and tablet devices is
> either uncomfortable or impossible. Place interactive elements in easy-to-reach zones near the
> natural resting position for thumbs."

> "a virtual thumbstick displays in the bottom-left corner of the screen, and a jump button displays
> in the bottom-right corner of the screen"

> "If you group UI elements from different categories together throughout the screen, players won't
> know where to look for what they need. To assist players in navigating your game, group UI
> elements from the same category together."

**Well:** first-party, specific, and the last sentence is an argument rather than a preference — it
is the reason the map button stops being a lone circle under the minimap and becomes the first
button of one rail. The companion page gives the touch size as a number
(`UISizeConstraint.MaxSize = inf, 44`), which this repo's existing `BUTTON_PX = 48` already clears.

**Badly:** it says nothing about where a right-edge rail should start vertically, nothing about
objective text, and the thumb-zone advice is about reachability rather than avoidance — it states no
keep-out rectangle in pixels. The bottom corners are named, and that is all that is used from it.

### B. PersonifiedPizza, *Location Marker System* — Roblox DevForum community resource

<https://devforum.roblox.com/t/location-marker-system/1586885>

**Uncopylocked model, no explicit licence**; last author response **December 2021**, so
**unmaintained**. Read for the pattern, not vendored — the decision
`docs/research/2026-09-27-first-person-viewmodel.md` made about the four viewmodel kits ("no licence
is not free to copy").

What it does: one `ScreenGui`, markers tracked from attachments in the workspace, a 2-D direction
taken from the camera, indicators **clamped to the screen edge with trigonometry** when the target
is outside the view, and transparency that fades with distance.

**Well:** it is the canonical Roblox shape for this, and it confirms the two decisions that matter —
a **single ScreenGui** rather than per-target `BillboardGui`s, and **edge clamping rather than
hiding**. The clamping rule is the one the compass strip and the map markers in this repo already
follow for their own reason (*"so 'it is behind me and to the left' still has an answer"*), so
adopting it costs no new concept.

**Badly:** it is built on workspace-attachment discovery, which is exactly the route `MapUi`
measured and **rejected** in task 155 — the DEV posts are `Transparency = 1`, `CanQuery = false`
parts in a place with streaming on and a 1,024-stud radius, so a client may simply not have them.
Its distance handling is a *fade*, not a *number*, which answers "far" and not "how far". And it
reads `workspace.CurrentCamera` directly, which this repo cannot do: `Camera.Rig` is the one writer
of that property and counts foreign writes (`src/client/Camera/init.luau`, `Camera.viewCFrame`).
Pattern yes, code no.

### C. theHunter: Call of the Wild — the genre's own waypoint, read through its players

<https://steamcommunity.com/app/518790/discussions/2/133257636770005666/>
<https://steamcommunity.com/app/518790/discussions/0/4839770694279329770/>

Avalanche Studios, commercial, live. Not borrowable code — borrowable **complaints**, which is the
useful half, and the same source `docs/research/2026-10-05-drive-report.md` used for the harvest
screen.

The three that change this design:

- the waypoint marker is *"massive and orange"* and players ask to shrink it — so the marker here is
  a small chevron and a short word, not a billboard;
- *"only showing the closest waypoint on the HUD to avoid visual overload"* — so there is **exactly
  one** waypoint on screen at a time, never a set;
- the waypoint *"shows distance information"* on the HUD and players still ask for it on the compass
  as well, because opening the map to navigate breaks the hunt — which is Karen's sentence, and the
  reason the same target is drawn on the strip, the minimap and the full map rather than only on M.

**Well:** the closest living product to this game, and its players have already found the failure
modes.

**Badly:** single-player, so nothing in it is about roles, and its waypoints are player-placed while
ours is assigned by the drive. Nothing about mobile.

### D. Negative result, recorded

`https://create.roblox.com/docs/projects/cross-platform` was fetched for the thumb-zone and
minimum-touch-size numbers (a search extract attributed them to it) and **does not contain them** —
it states only that controls must not be *"blocked or obscured by device cutouts or Roblox UI
elements"*. The sentences in source A come from the UI-design curriculum pages, which were fetched
and do contain them. Written down because this repo has twice spent a round on a citation that did
not say what it was cited for.

## The pattern adopted, and why

**One evaluation of the objective, several drawers, and a screen-space projection the Hud computes
itself.**

1. **The objective is a pure function of (phase, team, secondsLeft).** `Objective.text` returns one
   ASCII line; `Objective.targetFor` returns the world point and its word. Both pure and exported,
   so a spec asserts all six role × phase states with no drive, no world and no wire — the shape
   `Hud.startCardLines`, `Hud.driveBearing` and `Hud.crosshairVisible` already have, and for the
   same reason: a drive is 300-600 s long and no harness run reaches `Scoring`.

2. **The target comes from the geometry the map already has** (`MapGeometry`: the road polyline and
   the stands), not from a new wire field and not from `CollectionService`. A hunter's target is the
   nearest stand; a beater's is the road point at her own x. Source B's discovery route is rejected
   for the measured reason task 155 recorded. One geometry, one target — and a world that has
   stated no geometry gets **no waypoint at all** rather than a guess, which is
   `MapUi.geometryFor`'s own rule and `docs/PROJECT_CONTEXT.md`'s *"a visibility audit certified a
   blank screen twice"*.

3. **The screen marker is projected by hand from `Camera.viewCFrame()` and the camera's FOV**, not
   by `Camera:WorldToViewportPoint`. Roblox's FOV is vertical, so `px = f * x / -z` with
   `f = (viewportY / 2) / tan(fov / 2)` is exact — the same relation `Hud.reticleDegToPx` already
   uses for the scope, and the same trustworthy view source task 125 round 3 settled on
   (`Rig.appliedCFrame`, never `workspace.CurrentCamera.CFrame`). It is **pure**, so the projection
   is a spec and not a screenshot.

4. **Off screen or behind: pinned to the edge, dimmer.** Source B's clamping, in the words
   `Compass.CONFIG.PINNED_TRANSPARENCY` and `MapUi.CONFIG.PINNED_TRANSPARENCY` already use. Pinned
   and real are not the same picture.

5. **One rail, one category.** Source A's grouping sentence applied literally: the map button stops
   being a lone circle under the minimap and becomes the first of a column on the right edge, each
   button bound to a function that already exists. Nothing in the rail is new behaviour — it is a
   second door onto `MapUi.toggle`, `ReportPanel.toggle` and the weapon's own reload and ammo
   requests. A button with no function behind it is not built.

**What is NOT adopted, and why**

- **`BillboardGui` per target.** The obvious Roblox answer, and source B rejects it too: it needs an
  `Adornee` part, so the Hud would have to create an Instance in `Workspace` — a second writer of
  the world, for a mark that is pure UI. One ScreenGui, built once, so a visibility audit has one
  place to look (the Hud's own header).
- **A new remote or a new snapshot field.** The objective is a *reading* of the phase the snapshot
  already carries, and the target is a reading of geometry the client already has. A second wire
  would be a second answer to a question already answered on the client.
- **Rewriting the drive bar's vocabulary.** The bar says SHOOTER / DRIVER and Karen says hunter /
  beater; the objective line uses her words, through `Hud.roleWord`, which already exists for the
  start card. Which vocabulary the WHOLE Hud speaks is her decision and is still open
  (`TASKS.md` row 158a). Renaming half the screen to settle it quietly is what that row exists to
  prevent.
