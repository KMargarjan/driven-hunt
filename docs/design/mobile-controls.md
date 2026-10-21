# Mobile controls: the touch INPUT for a drive and the lobby (Task 220)

Architect, task 220. Written to `reviews/task-220/BRIEF.md` (the Builder carrying the Director,
2026-10-21) and `docs/research/2026-10-20-mobile-controls.md`. The brief overrides anything older;
where this design departs from it, the departure is named in section 1 and nowhere else.

Karen's v1 plan, 2026-10-11, confirmed *"continue"* 2026-10-19: *"world: ... MOBILE controls"*.

This run is **read-only** and could not re-fetch a single page. Every quotation in section 12 is the
research note's, and the note records which pages were retrieved and what it threw out — the shape
`docs/design/hud-clarity.md` section 11 already uses.

---

## 1. The three measured facts, and the one place this design departs from the brief

### 1.1 The facts are inputs, not assumptions

The brief's §0 carries M1, M2 and M3 as measurements from a live session. This design rests on them
and on nothing else that is unmeasured about the engine:

* **M1** — `tool:Activate()` from a LocalScript fires the **server's** `Tool.Activated`
  (`SERVER activated=2`, the Tool in the Backpack). This is the whole of BLOW:
  `src/server/Weapon/Horn.luau`, `Horn.grant`, connects `tool.Activated` → `Horn.blow(player)` and
  its own comment already says *"a blast needs NO RemoteEvent"*.
* **M2** — `Humanoid:EquipTool(tool)` from a LocalScript moves the Tool on the server
  (`parentAfterEquip=<character>`, `toolInCharacter=true`). This is the whole of SWAP.
* **M3** — `ProximityPrompt.ClickablePrompt` defaults to **true**, and `Build.shopPrompt`
  (`src/server/Lobby/Build.luau`) never sets it. The lobby interact needs **nothing built**.

Consequence, stated once: **zero new remotes, zero new flags, zero new ScreenGuis.**

### 1.2 One named deviation: D-220-1, the brief's chip recommendation does not fit

The brief's §2.1 recommends the ammo/horn chip's *"bottom becomes the cluster's top − 8"*, keeping
it at `right 16`. **That rectangle is occupied.** At 800 × 400 the chip would land at
y 170..216 at x ≈ 584..784, and `MapUi.minimapRect(800, 400)` is **x 692..788, y 140..236**
(`MapUi.diameterFor(800, 400)` = 96 — `MINIMAP_VIEWPORT_FRACTION` 0.22 × 400 = 88, clamped up to
`MINIMAP_MIN_PX`). The chip would be drawn on the minimap.

So the chip moves **up and left**: its bottom-right corner becomes the **cluster's** top-right
corner, 8 px above it (section 5.3). `Hud` is still the one writer of the chip (section 4), and it
asks `Touch` for two numbers instead of one. Everything else in the brief's §1 and §2 is adopted as
written.

---

## 2. What the system must do, and what it must not do

### 2.1 Must do

1. Give a touch player a tappable target for every action a mouse-and-keyboard player has in a
   drive: **FIRE**, **AIM**, **SWAP** (next carried Tool) and **BLOW** (the beater's horn). RELOAD
   and the ammo switch are already `Hud.Rail` buttons and do not move or gain a twin.
2. Reach the server through the **paths that already exist**: `FireRequest` for a shot
   (`Weapon.Input`), `Tool.Activated` for a blast (M1), `Humanoid:EquipTool` for a swap (M2).
   **Exactly one path per action, and the key is the second caller of the same function.**
3. Draw a button **only when there is something behind it** (`Rail.buttonVisible`'s rule): no dead
   buttons.
4. Clear the engine's two control zones and every rectangle this HUD draws, **at 800 × 400 first and
   at 400 × 800 second**, proved arithmetically by pure exported functions.
5. Stop the button rail from being drawn off the bottom of a landscape phone
   (`Rail.topFor(96, 140)` + `Rail.heightFor(4)` = **510 on a 400 px screen** today — RELOAD and
   AMMO are unreachable, which is an input defect and in scope, research note §5).
6. **Verify** the lobby interact (M3). Not rebuild it.

### 2.2 Must not do

* **Must not write the engine's touch controls.** `GuiService.TouchControlsEnabled` is not read or
  written by anything in this system. The thumbstick is movement and the camera drag is the look;
  this repo owns no character controller (note §4, source D).
* **Must not use the engine's auto-generated `ContextActionService` buttons** (note source C): their
  rectangles cannot wear `Style`, so the no-overlap claim cannot be asserted against them, and
  `GetButton` answers nothing on a desktop, so there would be no route to live evidence at all.
* **Must not add a remote, a snapshot field, a flag, a second `ScreenGui`, or an Instance outside
  `PlayerGui.HunterHud`** (the Hud's own D2/D3, `docs/design/hud-clarity.md` 2.2).
* **Must not decide a rule.** The cooldown is `Horn.blow`'s and the shot is the server's. The cluster
  holds no rule the mouse door does not already run.
* **Must not consult `Weapons.ORDER` or ownership** to decide which guns a player has (brief §1.8).
  SWAP cycles the Tools he is **actually carrying**, which is already `Weapons.loadout`'s answer
  delivered as Instances.
* **Must not hold a finger down.** One tap is one shot (brief §1.7); AIM is a **toggle** on touch.
* **Must not move a button when the loadout changes.** The cluster's slots are fixed (section 5.4).

---

## 3. Owners and files (rule 3)

One writer each, named. `PlayerScripts.Hud` remains the only writer of everything drawn, and the new
module is a sibling INSIDE it — the shape `Compass`, `MapUi`, `ReportPanel` and `Rail` already have.

| Thing | The one writer | File |
|---|---|---|
| The `ScreenGui` and **the creation, position and size of the cluster's frame** | `Hud` (`Hud.build`) | `src/client/Hud/init.luau` |
| **Everything inside the cluster frame: the four buttons, their text, `Visible`, position and `Activated`** | **`Hud.Touch`** (new) | **`src/client/Hud/Touch.luau`** (new) |
| **The cluster frame's own `Size` and `Visible`** | `Hud.Touch` (`Touch.applyVisibility`) | as above |
| The ammo / horn chip — including **where it sits** | `Hud` (`Hud.renderCorner`) | `src/client/Hud/init.luau` |
| The rail's buttons **and, new, the rail frame's `Position`** | `Hud.Rail` (`Rail.applyLayout`, `Rail.applyVisibility`) | `src/client/Hud/Rail.luau` |
| `FireRequest` / `ActionRequest`, the aim flag, **and the local player's hands** | `PlayerScripts.Weapon.Input` | `src/client/Weapon/Input.luau` |
| The minimap, the full map and **the rail column it reserves** | `Hud.MapUi` | `src/client/Hud/MapUi.luau` |
| The horn Tool, the blast and its cooldown | `ServerScriptService.Weapon.Horn` | `src/server/Weapon/Horn.luau` |
| The shopkeeper's prompt | `ServerScriptService.Lobby.Build` (`shopPrompt`) | unchanged |

### 3.1 Who owns equipping a Tool on the client (brief §3.1) — `Weapon.Input`, and no new module

**Ruling: `Weapon.Input` gains `Input.swap()` and `Input.blowHorn()`. No `Carry` module is created.**

* `Input` **already reads the carried-Tool tree**: `equippedWeapon()`, `isLive()`, `pruneWatched()`
  and `watchTool` walk the player's Backpack and character. A second module would be a second reader
  of one tree, which is the fault rule 3 exists for.
* The brief's decision 6 is titled *"ONE INPUT OWNER"*. Input is one system; splitting
  "what the thumb asks for" across two modules by whether the request travels as a remote or as a
  Tool call would be an owner boundary drawn on an implementation detail.
* `src/client/Weapon/` already resolves to the `weapon` scope in `BLAST_RADIUS`
  (`tools/studio_mcp.py`), so nothing in the gate changes.

**The boundary with the server, written down because there now are two callers of `EquipTool`:**
`src/server/Weapon/Hardware.luau`'s `Hardware.equip` owns the **grant-time** equip and retries it
for up to 2 s (`for _ = 1, 20 ... task.wait(0.1)`, stopping when `tool.Parent == character`).
`Input.swap()` owns **every player-initiated equip after that**. They collide in exactly one window:
a SWAP inside 2 s of a grant or a placement respawn is undone within 100 ms by that loop. That is a
named hole (section 14.1), not a design choice, and it is the server's to fix.

---

## 4. The dependency directions

All one-way. The Hud is still the only thing that knows more than one of them.

```
        Hud.render / Hud.renderObjective / Hud.renderCorner     <- the one evaluation
            |          |            |              |
   setWeapon|          |setCarried  |setSuppressed |reserved()/rect()
   setAiming|          |setHorn     |setCovered    v
            v          v            v         (pure, read)
                   Hud.Touch  ----------------->  Weapon.Input.fire / setAim / toggleAim
                                  calls           Weapon.Input.swap / blowHorn

   Hud reads:  Weapon.get()                     (is a gun in hand -- ONE read, told to Rail AND Touch)
               CameraSystem.getMode()           (is the view AIMING -- the drawn truth, not the request)
               Weapon.Input.carriedSummary()    (how many Tools, is one a horn)
               MapUi.isOpen(), ReportPanel.isOpen(), ShopPanel.hidesRail(viewX),
               Hud.isScorePanelVisible()        (the cluster's "covered" set)
               Workspace.CurrentCamera.ViewportSize  (read, never written)

   Hud tells:  Rail.applyLayout(viewport, diameter, minimapTop, floorY)
               MapUi.setRailColumn(px)
```

`Touch` requires **only** `Style`. It never requires `script.Parent` (a cycle —
`MapUi.setPush`'s header records why) and it never reads `Weapon`, `MapUi` or `Camera`: it is told,
and it takes its collaborators at `start`, the `Rail.start` / `MapUi.start` shape.

---

## 5. The geometry — numbers, not adjectives

### 5.1 The two keep-outs are OURS, and they are unverified

Source A states the two zones and gives no rectangle for either (note §6). So they are OUR
constants, built from two numbers each so a remeasurement moves two numbers and nothing else:

```lua
Touch.CONFIG.JUMP       = { BUTTON_PX = 120, INSET_PX = 20 }   -- keep-out 140 x 140, bottom-right
Touch.CONFIG.THUMBSTICK = { RING_PX   = 160, INSET_PX = 20 }   -- keep-out 180 x 180, bottom-left
Touch.CONFIG.JUMP_CLEAR_PX = 20                                -- source A's own sample: 20 px
```

Reasoning for each number: the engine's jump button is visibly larger than this repo's 48 px rail
button and is inset from both edges; 120 + 20 is our estimate of button + inset. The dynamic
thumbstick's ring is larger again, hence 160 + 20. **Both are a guess with a comment on it until a
person runs the Studio Device Emulator** and reads `PlayerGui.TouchGui`'s children —
`tools/studio_mcp.py` has **no emulator command** (checked: its only input verbs are `keyboard`,
`mouse` and `wait`, `STEP_ACTIONS`), so the harness cannot produce it. Section 13.5 says how it is
measured and who clicks.

**The whole layout is a pure function of these two rectangles.** If the measurement is bigger, the
cluster moves and the chip follows it; no other number in this design changes.

### 5.2 Placement: one rule, two answers

```
Touch.placement(viewport, leftStackRightPx) -> "left-of-jump" | "above-jump"
  freeWidth = (viewport.X - JUMP.W) - math.max(THUMBSTICK.W, leftStackRightPx)
  return if freeWidth >= clusterWidth + JUMP_CLEAR_PX then "left-of-jump" else "above-jump"
```

`leftStackRightPx` is `Hud.leftStackRight(viewport)` — the right edge of the bottom-left stack the
Hud owns: `max(FEED_LEFT_OFFSET + Hud.FEED.WIDTH, CARD.MARGIN_LEFT + CARD.WIDTH)` = `max(16 + 440,
16 + 188)` = **456**. It is handed in as a parameter because `Touch` may not require `Hud`.
(`Hud.FEED.WIDTH = 440` is a new name for the literal in `Hud.build`'s `feed.Size`; nothing moves.)

* **`left-of-jump`** — the cluster's right edge is `viewport.X - (JUMP.W + 20)`, its bottom is
  `viewport.Y - Style.MARGIN`. This is source A's *"relative positioning ... near frequently-used
  controls like the default jump button"*.
* **`above-jump`** — the cluster's right edge is `viewport.X - Style.MARGIN`, its bottom is
  `viewport.Y - (JUMP.H + 20)`. The phone-portrait answer: between a 180 px thumbstick and a 140 px
  jump a 400 px screen has **80 px** of bottom band, and an 88 px FIRE does not fit in it.

### 5.3 Every rectangle, at 800 × 400 (first) and 400 × 800 (second)

`Style.isPhone(800)` is **false** (`PHONE_BELOW_PX` = 700), so a landscape phone renders at the
**desktop** step — the fact the research note measured on paper, and the reason the rail does not fit
today.

| Rect | 800 × 400 (landscape) | 400 × 800 (portrait) |
|---|---|---|
| THUMBSTICK keep-out | x 0..180, y 220..400 | x 0..180, y 620..800 |
| JUMP keep-out | x 660..800, y 260..400 | x 260..400, y 660..800 |
| Placement | `left-of-jump` (free width 204 ≥ 168 + 20) | `above-jump` (free width −56) |
| **Cluster box** (168 × 160) | **x 472..640, y 224..384** | **x 216..384, y 480..640** |
| FIRE 88 | x 552..640, y 296..384 | x 296..384, y 552..640 |
| AIM 64 | x 576..640, y 224..288 | x 320..384, y 480..544 |
| BLOW 72 | x 472..544, y 312..384 | x 216..288, y 568..640 |
| SWAP 56 | x 488..544, y 248..304 | x 232..288, y 504..560 |
| **Ammo / horn chip** (ceiling 200 × 46 / 42) | **x 440..640, y 170..216** | **x 184..384, y 430..472** |
| Rail (folded, 2 × 2) | x 684..788, y 244..348 | x 284..388, y 244..348 |
| Minimap | x 692..788, y 140..236 | x 292..388, y 140..236 |
| Compass strip | x 190..610, y 108..138 | x 12..388, y 108..138 |
| Status slate (ceiling) | x 166..634, y 40..74 | x 12..388, y 40..74 |
| Objective line | y 8..38 | y 8..38 |
| Toast feed | x 16..456, y 282..384 | x 16..456, y 697..784 |
| Hit card | x 16..204, y 130..256 | x 16..204, y 545..689 |
| Full map panel | x 171..505, y 140..352 | x 12..264, y 140..300 |

Every one of those is produced by a pure exported function of the viewport — `Touch.rect`,
`Touch.buttonRect`, `Hud.cornerRect`, `Rail.layoutFor`, `MapUi.minimapRect`, `MapUi.fullMapRect`,
`Hud.statusRect`, `Objective.lineRect`, `Compass.widthFor` — because `AbsolutePosition` can only
answer for whatever size the Studio window happens to be (969 × 784 in the task-220 probe pass, and
in task 155's).

**The asserted intersection set is EMPTY** over
{objective, status, compass, minimap, rail, chip, cluster, each of the four buttons, THUMBSTICK,
JUMP} at **400 × 800, 800 × 400, 800 × 600, 969 × 784 and 1920 × 1080**. Tightest clearances:
landscape cluster-to-feed **16 px**, portrait cluster-to-hit-card **12 px**, portrait
cluster-to-rail **132 px** after the fold (**20 px** without it — which is why the fold is not
optional, section 5.6).

**Three members are excluded, each with its reason** (the idiom §4.3 already uses for the tied
banner):

1. **The full map, the report panel, the shop panel and the pad dialog** — the cluster is not drawn
   while any of them is up (`Touch.setCovered`, section 6.3). This is `MapUi.minimapVisible`'s own
   argument, not a dropped check; the predicate is asserted instead.
2. **The results board and the start card** — centred cards that already exceed a 400 px screen
   (`Hud.BOARD.WIDTH` 520, `Drive.CONFIG.START_CARD_WIDTH` 440; `hud-clarity.md` 12.2 names this as
   pre-existing). The board is in the cluster's `covered` set; the start card is not (a beater's
   BLOW is legal while it is up) and it is drawn above the cluster's ZIndex.
3. **The toast feed and the hit card at 400 × 800 against the THUMBSTICK keep-out** — they are
   inside it today, before this task adds anything (note §6). Reported with numbers (section 14.3),
   not fixed here.

### 5.4 The cluster's shape: fixed slots, and nothing ever moves

168 × 160, two columns, right column nearest the thumb:

```
   +--------+  +----------+      left column 72 wide, right column 88
   |  SWAP  |  |   AIM    |      SWAP 56 right-aligned in the left column
   |   56   |  |    64    |      AIM  64 right-aligned in the right column
   +--------+  |          |
   +--------+  +----------+      gaps: 8 everywhere
   |  BLOW  |  |          |
   |   72   |  |   FIRE   |      FIRE and BLOW share the bottom edge
   |        |  |    88    |
   +--------+  +----------+
```

**The slots are fixed and a hidden button leaves its slot empty.** This is the one place this design
refuses `Rail.applyVisibility`'s *"PACKED, NOT PARKED"*: a rail button is a menu item and a trigger
is muscle memory. `docs/PROJECT_CONTEXT.md` names *"a marker wandering the screen"* among the bugs
that killed the previous project, and a FIRE button that slides 72 px left the moment a second gun is
picked up is that bug with a finger on it. The cluster's rect is therefore **independent of how many
buttons are visible**, which is also what lets the chip's position be stable (section 5.5).

Every target's shorter side: FIRE 88, BLOW 72, AIM 64, SWAP 56 — all ≥ **44** (source B). Every gap
≥ **8** (`Rail.CONFIG.GAP`). Every button ≥ **20** from the JUMP keep-out, and the nearest is FIRE at
exactly 20 (source A's own sample distance).

### 5.5 The chip moves, and `Hud` is still the one writer (brief §2.1)

```lua
Touch.shown(touchEnabled): boolean          -- touchEnabled or CONFIG.SHOW_ON_DESKTOP
Touch.reserved(viewport, shown): (number, number)   -- extra (right, bottom) inset for the corner
    -- not shown -> (0, 0): the chip sits exactly where it sits today
    -- left-of-jump -> (JUMP.W + 20 - Style.MARGIN, clusterHeight + 8)  = (144, 168)
    -- above-jump   -> (0,                          JUMP.H + 20 + clusterHeight + 8 - Style.MARGIN) = (312)
```

`Hud.renderCorner` — already *"THE ONE WRITER OF THE BOTTOM-RIGHT CORNER"*, already called once a
frame — writes
`chip.Position = UDim2.new(1, -(Style.MARGIN + rightPx), 1, -(Style.MARGIN + bottomPx))`,
edge-triggered on the viewport so it costs one comparison a frame. It is written there and **not** in
`Hud.applyViewportLayout`, because that function is keyed on `viewX` alone
(`if viewX == lastViewportX then return`) and the reserve depends on `viewport.Y`.

**The chip's ceiling is declared, because the chip is `AutomaticSize.X`.**
`Hud.CORNER = { MAX_WIDTH_PX = 200 }`, and `Hud.cornerRect(viewport, rightPx, bottomPx)` returns the
box the chip may never grow past — `Hud.statusRect`'s own rule (*"IT IS THE MAXIMUM AND NOT THE DRAWN
WIDTH"*), so an overlap test against it is conservative. 200 is the widest row this chip can build
(slate padding 24 + shell glyph 16 + 7 + three pips 48 + 7 + a two-digit `STAT` value + 7 + a spaced
`MICRO` load word ≈ 171, and the horn's `THROUGH`/`WAIT` row is shorter), and the live spec asserts
`Hud.ammoChip().AbsoluteSize.X <= Hud.CORNER.MAX_WIDTH_PX` so the ceiling is a measurement and not a
guess (section 13.2).

### 5.6 The rail is clamped by FOLDING (brief §2.5)

Today: `Rail.topFor(96, 140)` = 244, `Rail.heightFor(4)` = 216, bottom **510 on a 400 px screen**.
Shrinking the gap cannot save it — at 800 × 400 the free right-edge column under the minimap is
y 236..384, **148 px**, and four 48 px buttons are 192 px with **no** gaps at all. So it folds.

```lua
Rail.CONFIG.MAX_COLUMNS = 2
Rail.widthFor(columns)  = columns * BUTTON_PX + (columns - 1) * GAP          -- 48 | 104
Rail.columnPx(columns)  = Rail.widthFor(columns) + MARGIN + 8                -- 68 | 124
Rail.heightFor(count, columns?) = rows * BUTTON_PX + (rows - 1) * GAP        -- rows = ceil(count/columns)
Rail.topFor(diameter, minimapTop)                                            -- unchanged: 140 + d + 8
Rail.floorFor(viewport, blockers): number
    -- viewport.Y - Style.MARGIN, lowered to (blocker.y - 8) for every blocker that overlaps the
    -- WORST-CASE column x-range (viewport.X - columnPx(MAX_COLUMNS)). The worst case is used so the
    -- answer cannot depend on the fold the answer decides.
Rail.columnsFor(viewport, diameter, minimapTop, floorY): number
    -- the fewest columns for which topFor + heightFor(#Rail.BUTTONS, columns) <= floorY, else MAX_COLUMNS.
    -- #Rail.BUTTONS and not the visible count, so the reserved column never moves with the loadout.
Rail.layoutFor(viewport, diameter, minimapTop, visibleCount, floorY): (x, y, w, h, columns)
Rail.rect(viewport, diameter, minimapTop, count, floorY?)  -- the first four; floorY nil = today's answer
Rail.slotFor(index, columns): (number, number)   -- 0-based among VISIBLE buttons; top-to-bottom,
                                                 -- then the next column to the LEFT
```

* `Rail.rect` stays **pure** (brief §2.5) and keeps its current signature with one optional argument,
  so `hud_clarity.spec`'s existing cases are unchanged.
* **No desktop viewport folds.** 1920 × 1080: floor 1010 (lowered by the chip), one column
  298..514 — pixel-identical to today. 969 × 784 (the Play window): floor 714, one column 298..514 —
  identical. 800 × 600: floor 584, one column 280..496 — fits. Only 800 × 400 and 400 × 800 fold.
* **The rail becomes the one writer of its own frame's `Position`.** `Rail.applyLayout(viewport,
  diameter, minimapTop, floorY)` writes it; `MapUi.applyLayout`'s three lines that write
  `rail.Position`, its `railFrame` local and the `rail` field of `MapUi.start` are **removed** and
  archived under `backups/` with a note (rule 7). This is forced rather than tidy: the clamp cannot
  live in two places, and `MapUi` currently re-computes `MINIMAP_TOP + diameter + 8` by hand beside
  `Rail.topFor`. It removes a second writer rather than adding one.
* **`MapUi` is told the column width instead of hard-coding it.** `MapUi.setRailColumn(px)` (a
  setter, the `setPush` shape, edge-triggered) and `MapUi.fullMapRect(viewport, railColumnPx?)`,
  defaulting to `CONFIG.RAIL_COLUMN_PX` = 68. The Hud passes
  `Rail.columnPx(Rail.columnsFor(...))`, so a folded rail reserves 124 and an unfolded one reserves
  68 — which is why the full map clears the folded rail at 400 × 800 (panel x 12..264, rail
  x 284..388). `hud_clarity.spec`'s existing identity
  `RAIL_COLUMN_PX == BUTTON_PX + MARGIN + 8` becomes `RAIL_COLUMN_PX == Rail.columnPx(1)`.

---

## 6. `Hud.Touch` — the public interface

`--!strict`. Pure functions first; they take everything and read nothing.

```lua
export type Button = {
    id: string,        -- "FIRE" | "AIM" | "SWAP" | "BLOW"
    label: string,     -- what is drawn, ASCII, <= 5 characters
    px: number,        -- its own square size
    slot: string,      -- "bottom-right" | "top-right" | "bottom-left" | "top-left"
    needs: string,     -- "weapon" | "two" | "horn"   -- the condition that draws it
}

Touch.CONFIG = {
    FIRE_PX = 88, AIM_PX = 64, SWAP_PX = 56, BLOW_PX = 72,
    GAP = 8, MARGIN = Style.MARGIN,              -- 16
    JUMP = { BUTTON_PX = 120, INSET_PX = 20 },
    THUMBSTICK = { RING_PX = 160, INSET_PX = 20 },
    JUMP_CLEAR_PX = 20,
    Z_INDEX = 10,
    SHOW_ON_DESKTOP = false,                     -- section 7
    LABEL_STEP = "LABEL",
    -- the look is the rail's ghost slate, read from Style; FIRE's rim is BLAZE (section 6.4)
}
Touch.BUTTONS: { Button }                        -- fixed slots, drawing order

-- ---- pure -----------------------------------------------------------------
Touch.shown(touchEnabled: boolean, showOnDesktop: boolean?): boolean
Touch.visible(touchEnabled: boolean, suppressed: boolean, covered: boolean,
              showOnDesktop: boolean?): boolean
Touch.buttonVisible(button: Button, hasWeapon: boolean, carried: number, hasHorn: boolean): boolean
Touch.clusterSize(): (number, number)                             -- 168, 160
Touch.placement(viewport: Vector2, leftStackRightPx: number): string
Touch.rect(viewport: Vector2, leftStackRightPx: number?): (number, number, number, number)
Touch.buttonRect(id: string, viewport: Vector2, leftStackRightPx: number?)
                                                 : (number, number, number, number)
Touch.jumpKeepOut(viewport: Vector2): (number, number, number, number)
Touch.thumbstickKeepOut(viewport: Vector2): (number, number, number, number)
Touch.reserved(viewport: Vector2, shown: boolean, leftStackRightPx: number?): (number, number)

-- ---- state: this module is the one writer of what is inside its frame ----
Touch.start(frame: Frame, collaborators: { Input: any?, touchEnabled: boolean? }): ()
Touch.applyLayout(viewport: Vector2, leftStackRightPx: number): ()   -- writes its own Size + slots
Touch.applyVisibility(): ()
Touch.press(id: string): boolean          -- THE NAMED HANDLER each button's Activated calls
Touch.setWeapon(hasWeapon: boolean): ()
Touch.setCarried(count: number): ()
Touch.setHorn(hasHorn: boolean): ()
Touch.setAiming(on: boolean): ()          -- paints AIM's "on" state; the CAMERA's answer, not the flag
Touch.setSuppressed(on: boolean): ()
Touch.setCovered(on: boolean): ()

-- ---- read-only, for a spec ----
Touch.buttonIds(): { string }             -- what is actually on screen now, in slot order
Touch.button(id: string): TextButton?
Touch.actionFor(id: string): (() -> any)? -- the function the button calls, for the identity claim
Touch.isAimOn(): boolean
Touch.isSuppressed(): boolean
Touch.isCovered(): boolean
Touch.stats(): { presses: number, refused: number, byId: { [string]: number } }
```

### 6.1 The four buttons

| id | label | px | slot | calls | drawn when |
|---|---|---|---|---|---|
| FIRE | `FIRE` | 88 | bottom-right | `Weapon.Input.fire()` | a gun is in hand |
| AIM | `AIM` | 64 | top-right | `Weapon.Input.toggleAim()` | a gun is in hand |
| SWAP | `SWAP` | 56 | top-left | `Weapon.Input.swap()` | `carried >= 2` |
| BLOW | `BLOW` | 72 | bottom-left | `Weapon.Input.blowHorn()` | a horn is carried |

`hasWeapon` is the boolean the Hud **already** computes for the rail
(`Rail.setWeapon(state ~= nil and state.equipped == true)`), handed to both — one reader of the
weapon state in the Hud, and `Touch` learns nothing about weapons. `carried` and `hasHorn` come from
`Input.carriedSummary()` (section 8.3).

**No interact button** (M3), **no RELOAD or AMMO twin** (they are the rail's), **no jump button** (the
engine's), **no movement** (the engine's thumbstick).

### 6.2 `Touch.press(id)` is the seam, and it gates on legality

```lua
function Touch.press(id: string): boolean
    if suppressed or covered then stats.refused += 1; return false end
    local action = actions[id]
    if action == nil then return false end
    stats.presses += 1; stats.byId[id] = (stats.byId[id] or 0) + 1
    local ok, result = pcall(action)
    if not ok then warn(...) ; return false end
    return result ~= false
end
```

`Rail.press`'s header gives the reason the function is public: *"a named function rather than an
inline closure, so a client spec can drive exactly the code path the wire drives"*. A spec cannot
fire `GuiButton.Activated` and the harness cannot synthesise a tap, so this is the only seam — and
what it proves is the **ACTION**, not the touch (section 13.4).

**It differs from `Rail.press` in one way, deliberately:** it refuses while suppressed or covered.
`Rail.press` does not, and must not — MAP and REPORT are toggles and a spec drives them while
hidden. FIRE is a shot. The full map does **not** request an `Input` hold (the shop, the report and
the pad dialog do, with the tags `shop`, `report`, `padsize`), so without this check a tap through an
open map would fire the gun. Queued, one line, out of scope here: *"the full map requests
`Input.requestHold("map")`, so the key door and the button door agree"*.

### 6.3 Visibility: three rules, three questions

`Touch.visible(touchEnabled, suppressed, covered)` = `shown(touchEnabled) and not suppressed and not
covered` — `Rail.applyVisibility`'s exact arrangement, and for its reason: *"a sight picture and an
open shop can be true independently, and whichever ends first must not turn the rail back on while
the other still holds it down"*.

| flag | written by | from |
|---|---|---|
| `suppressed` | `Hud.renderScope`, beside the three `setSuppressed` calls it already makes | `scoped` |
| `covered` | `Hud.renderObjective`, beside `Rail.setCovered` | `MapUi.isOpen() or ReportPanel.isOpen() or ShopPanel.hidesRail(viewX) or Hud.isScorePanelVisible()` |

The score panel is in the cluster's `covered` set and not in the rail's: there is nothing to shoot in
`Scoring`, and REPORT still has to be reachable. Both setters are edge-triggered, so a per-frame
caller costs one comparison and never a write — and `Touch.applyVisibility` stays the one place
`Visible` is written, which is the fault task 196 round 1 found in the rail
(`railFrame.Visible` written from the Hud *"turned four buttons back on INSIDE the eyepiece"*).

### 6.4 The look: borrowed whole, and expected back

Every colour, face, size, radius and duration is `Style`'s (task 201, the Designer's system). The
buttons are built by one private helper that is `Rail.start`'s button recipe with the size passed in:
`Style.LOOK.SLATE` at `Style.SLATE_QUIET_T`, `Style.corner(node, Style.RADIUS.ROW)`,
`Style.stroke(node, Style.LOOK.LINE, Style.EDGE_T.GHOST)`, `AutoButtonColor = false`, `Text = ""`
with a child `TextLabel` at `Style.sizeFor("LABEL", viewportX)` in `Style.FONT.SANS_SEMI` and
`Style.LOOK.FIELD_MUTED`, and the same three states on `MouseEnter` / `MouseLeave` /
`MouseButton1Down` / `MouseButton1Up` — including the rail's measured touch rule: *"on touch there
is no `MouseLeave` after `MouseButton1Up`, so painting the hover state there would leave a thumbed
button lit for the rest of the session"*.

Two departures, each one line:

1. **FIRE's rim is `Style.LOOK.BLAZE` at `EDGE_T.GHOST`.** §1.1: *"Blaze = act / go here"*. A
   trigger is the act, and it is the one button a thumb must find without reading.
2. **AIM wears the hover paint while the camera is aiming** (`Touch.setAiming`) — opaque slate,
   brass rim, `PAPER` label. A toggle with no visible state is the previous project's *"marker
   wandering the screen"* in another costume.

**The LOOK of the cluster is expected back as a second, cheap task** (brief §4). This design fixes
the geometry and the owners; the picture is Karen's.

---

## 7. `SHOW_ON_DESKTOP` — the ruling (brief §2.4)

**`Touch.CONFIG.SHOW_ON_DESKTOP` ships `false`.** The rail's three reasons do not survive the move
to the bottom-right:

1. Karen **asked for** the rail (*"could be buttons on the side for M - map ect"*) and never asked
   for a trigger button. A FIRE square over the world on the one machine she plays on is clutter she
   did not request, and rule 5 makes every change to her picture her decision.
2. **It would move her ammo chip.** `Touch.reserved` is keyed on `shown`, so a desktop cluster drags
   the chip 144 px left and 168 px up on a screen whose owner cannot use the buttons. With
   `SHOW_ON_DESKTOP = false`, `reserved` is `(0, 0)` and **nothing on a desktop HUD moves at all** —
   including the rail, which does not fold at any desktop viewport (section 5.6).
3. The rail's third reason — *"a `TextButton` is clickable with a real mouse, which is the only route
   to any live evidence at all"* — is **answered differently here**: `Touch.press` gates on
   `suppressed` / `covered` and **not** on `touchEnabled`, so every live claim in section 13.2 runs
   on a desktop with the cluster hidden. What a mouse click would have added over `Touch.press` is
   the `Activated` wiring itself, and that needs a finger on a phone either way.

Both states are reachable **by parameter**: `Touch.shown(touchEnabled, showOnDesktop?)` and
`Touch.visible(..., showOnDesktop?)` take the fourth argument, so one spec drives both worlds while
the constant sits at one of them — this repo's rule for every branched path. It is one boolean for
Karen to turn on.

---

## 8. `Weapon.Input` — four public functions, and the key becomes the second caller

### 8.1 FIRE and AIM (brief §1.6)

```lua
-- THE IMPLEMENTATION. The hold is checked HERE, where task 165 moved it, so a tap through an open
-- panel is refused once for both doors. Returns whether the request actually went.
function Input.fire(): boolean
    if Input.isHeld() then return false end
    local camera = Workspace.CurrentCamera
    if camera == nil then return false end
    local cframe = camera.CFrame
    remotes().FireRequest:FireServer({ origin = cframe.Position, direction = cframe.LookVector.Unit })
    return true
end

function Input.setAim(on: boolean): boolean      -- the mouse's Begin/End, with the value
    if Input.isHeld() then return false end
    if on ~= aiming then aiming = on; signal:Fire(aiming) end
    return true
end

function Input.toggleAim(): boolean              -- the thumb's one tap
    return Input.setAim(not aiming)
end
```

and the two existing handlers become two lines each:
`onFire` → `if state == Begin then Input.fire() end; return Pass`;
`onAim` → `if state == Begin or state == End then Input.setAim(state == Begin) end; return Pass`.

Every handler still returns `Pass`, for the two reasons `Input`'s header already gives. `Input`
remains the only firer of `FireRequest` / `ActionRequest` and the only keeper of the aim flag, and
`Input.AimChanged` is unchanged — so `CameraBoot`'s `setAimSource` sees a toggle and a hold as the
same fact and the ADS path needs no edit.

**AIM is a toggle on touch and a hold on the mouse** (brief §1.5): on a phone the right thumb IS the
camera, so a held AIM pins the only finger that aims. One flag, two callers, different arguments.

### 8.2 SWAP and BLOW

```lua
-- PURE, so a spec drives the order with no Tools at all.
function Input.nextToolName(names: { string }, current: string?): string?
    -- `names` SORTED ASCENDING; the one after `current`, wrapping; the first when `current` is nil
    -- or not in the list; nil when fewer than two names.

function Input.carriedSummary(): { count: number, hasHorn: boolean, equipped: string? }
    -- ONE walk of the Backpack and the character per call: every Tool, by name, sorted.

function Input.swap(): boolean
    -- refuses while Input.isHeld(); false when count < 2 or there is no Humanoid.
    -- humanoid:UnequipTools() then humanoid:EquipTool(next)   -- M2's exact measured state
function Input.blowHorn(): boolean
    -- false when no Tool named Horn.TOOL_NAME is carried.
    -- not in the character -> UnequipTools() + EquipTool(horn)  (M2), then horn:Activate()  (M1)
```

* **The order is alphabetical by `Tool.Name`** — today `Horn`, `Lever`, `Rifle`, `SemiAuto`,
  `Shotgun`. It depends on nothing but the Tools in the player's hands: it does **not** consult
  `Weapons.ORDER`, `Weapons.ROWS` or any ownership set (brief §1.8), so SWAP cannot become a second
  answer to *"which guns are his"*. It is stable across a respawn and across the Backpack ↔ character
  move that equipping performs — which the engine's own child order is not. Karen may want the
  shotgun first; that is one pure function to change (section 16, K-3).
* **`UnequipTools()` before `EquipTool`** puts the swap into exactly the state M2 measured (the Tool
  in the Backpack, nothing in the hand, a LocalScript calling `EquipTool`). *"EquipTool while another
  Tool is held"* was **not** measured, so the design does not depend on it, and the live spec case in
  13.2 proves the outcome in the gate either way.
* **BLOW equips first and then activates**, which is precisely the two steps a desktop beater
  performs (hotbar, then click): both halves are measured, and neither is a capability the mouse door
  lacks. M1 additionally shows `Activate()` reaching the server with the Tool in the Backpack, so the
  blast is not lost if the equip has not settled in the same frame.
* **The cooldown is not re-implemented.** `Horn.blow` holds `lastBlast` and `Horn.readyAt`, the chip
  draws the readiness bar from `Horn.BLOW_ATTRIBUTE`, and a tap during the 1.5 s is refused by the
  server exactly as a click is. A client-side gate would be a second answer to *"is this horn
  ready"*.
* `src/shared/Horn/` is required for `Horn.TOOL_NAME` / `Horn.isToolName` — `src/client/Hud/init.luau`
  already requires the same module, there is no cycle, and `src/shared/Horn/` already resolves to the
  `weapon` scope.

### 8.3 What the Hud reads, once

In `render(Weapon, CameraSystem)`, where `Rail.setWeapon` already is — one read, four tells:

```lua
local hasGun = state ~= nil and state.equipped == true
Rail.setWeapon(hasGun)
Touch.setWeapon(hasGun)
Touch.setAiming(CameraSystem ~= nil and CameraSystem.getMode() == "Aiming")
local carried = Weapon.Input.carriedSummary()
Touch.setCarried(carried.count)
Touch.setHorn(carried.hasHorn)
```

**`setAiming` takes the CAMERA's mode and not `Input.isAiming()`**, which is this file's own rule
three lines up: *"The Hud asks the CAMERA, which is the state, not the weapon's aim flag, which is
the request"*. A lit AIM button with an unshouldered gun would be a number that measured right and
looked wrong.

**Two answers to "is there a horn", and they are two questions.** `Hud.renderCorner` asks *is a horn
IN THE HAND* (`character:FindFirstChild(Horn.TOOL_NAME)`) because that is the chip's rule, unchanged.
`Touch` asks *does he CARRY one*, because that is the button's rule — the button equips it. Neither
derives from the other, and both read the same tree. Written down here because *"one predicate
answered two unrelated questions"* is in `PROJECT_CONTEXT.md`.

---

## 9. What changes in the existing owners

### 9.1 `src/client/Hud/init.luau`

1. `build()` creates one new empty `Frame` — `TouchCluster`, `AnchorPoint (1, 1)`,
   `ZIndex = Touch.CONFIG.Z_INDEX`, `Visible = false` — and writes nothing inside it afterwards.
   `Hud.touchCluster()` returns it, the `Hud.rail()` / `Hud.compass()` shape, so a spec never walks
   `PlayerGui` by name.
2. `Hud.FEED = { WIDTH = 440 }` names the literal in `feed.Size`; `Hud.leftStackRight(viewport)` is
   new and pure (section 5.2).
3. `Hud.CORNER = { MAX_WIDTH_PX = 200 }` and `Hud.cornerRect(viewport, rightPx, bottomPx)` are new
   and pure (section 5.5).
4. `Hud.start` calls `Touch.start(cluster, { Input = Weapon.Input, touchEnabled =
   UserInputService.TouchEnabled })` next to the existing `Rail.start`, and then
   `Touch.setWeapon(...)` once, as `Rail`'s boot already does.
5. `Hud.renderCorner` writes the chip's `Position` from `Touch.reserved`, edge-triggered on the
   viewport (section 5.5).
6. `Hud.renderObjective` — already *"THE ONE EVALUATION"* — gains four lines beside
   `Rail.setCovered`: `Touch.setCovered(...)`, `Touch.applyLayout(viewport, Hud.leftStackRight(...))`,
   `Rail.applyLayout(viewport, MapUi.diameterFor(...), MapUi.CONFIG.MINIMAP_TOP, floorY)` and
   `MapUi.setRailColumn(Rail.columnPx(columns))`, where `floorY = Rail.floorFor(viewport, { chipRect,
   clusterRect })`. All four are edge-triggered inside their owners.
7. `Hud.renderScope` gains `Touch.setSuppressed(scoped)` beside the three `setSuppressed` calls it
   already makes.
8. `render` gains the four tells in section 8.3.

### 9.2 `src/client/Hud/Rail.luau`

The fold, the floor, `columnPx`, `slotFor`, `layoutFor` and `Rail.applyLayout` (section 5.6).
`Rail.CONFIG`, `Rail.BUTTONS`, `Rail.press`, `Rail.visible`, `Rail.buttonVisible`, `setWeapon`,
`setSuppressed` and `setCovered` are **unchanged**.

### 9.3 `src/client/Hud/MapUi.luau`

`setRailColumn`, the parameterised `fullMapRect`, and the removal of the three lines that write
`rail.Position` plus the `railFrame` local and `start`'s `rail` field (archived, rule 7).

### 9.4 `src/client/Weapon/Input.luau`

Section 8. `onFire` / `onAim` become callers; `fire`, `setAim`, `toggleAim`, `swap`, `blowHorn`,
`nextToolName` and `carriedSummary` are added. Nothing about the bindings, the watch set, the hold
or `AimChanged` changes.

### 9.5 The lobby interact — verified, not built (M3)

`tests/server/lobby.spec.luau`'s existing prompt case gains **one line**:
`expect(p.ClickablePrompt).to.equal(true)`. No source file changes. The case already asserts the key,
the distance, the hold, the line of sight and `Enabled`; this is the property a thumb needs, and it
is asserted on the prompt the real `Build` makes in the real place rather than on a remembered
default.

**What is wrong and is not fixed here:** the prompt's `ObjectText` is **`"Press E"`**
(`Lobby.CONFIG.LODGE.KEEPER.PROMPT`, asserted in that same spec). On a phone there is no E. The
prompt is tappable, so the lobby WORKS; it just says the wrong word. It is data, one line, and it is
Karen's wording (section 16, K-4) — and `src/shared/Lobby/` is not in this task's scope.

---

## 10. ZIndex

| Node | ZIndex | Why |
|---|---|---|
| Ammo / horn chip | 6 (`Hud.STATUS.Z_INDEX`) | unchanged |
| **The cluster and its buttons** | **10** / 11 for the labels | Above every field surface (the compass, the maps, the feed, ≤ 9) and **below the scope's mask (11-13) and every modal panel (15)** — so if `setCovered` ever failed, a panel would still be on top and the rail's buttons would still win. Below the rail's 16, which is deliberate: on a phone the rail is the only way to CLOSE a panel and must never lose to a trigger. |
| Rail | 16 | unchanged |

---

## 11. Numeric targets

| What | Target | Source |
|---|---|---|
| Every touch target, shorter side | ≥ **44 px**; FIRE 88, BLOW 72, AIM 64, SWAP 56 | source B |
| Gap between two targets | ≥ **8 px** | `Rail.CONFIG.GAP` |
| Cluster's distance from the JUMP keep-out | ≥ **20 px** (FIRE is at exactly 20) | source A's own sample |
| JUMP keep-out | **140 × 140**, bottom-right (120 + 20) | ours, unverified |
| THUMBSTICK keep-out | **180 × 180**, bottom-left (160 + 20) | ours, unverified |
| Cluster box | **168 × 160**, independent of how many buttons show | section 5.4 |
| Viewports the layout must hold at | **800 × 400** and **400 × 800**; asserted also at 800 × 600, 969 × 784, 1920 × 1080 | brief §1.10 |
| Intersections in the asserted set | **0**, at all five viewports | brief §3.2 |
| Tightest clearance | 12 px (portrait cluster ↔ hit card) | section 5.3 |
| Ammo / horn chip ceiling | **200 px** wide, asserted live against `AbsoluteSize.X` | section 5.5 |
| Paths from a touch FIRE to the server | exactly **1**, and it is `FireRequest` | brief §1.6 |
| New remotes / new flags / new ScreenGuis | **0 / 0 / 0** | brief §1.11 |
| Taps per shot | **1** (no hold-to-repeat, any gun) | brief §1.7 |
| Rail buttons off-screen at 800 × 400 | **0** (today: 2) | note §5 |
| Desktop HUD rectangles that move | **0** at 969 × 784 and 1920 × 1080 | section 7 |
| Per-frame cost of the new work | **< 0.05 ms**: two `GetChildren` and ≤ 6 name compares (`carriedSummary`), five edge-triggered comparisons, and two viewport comparisons. No new `RenderStepped` connection. | camera design 8.2's budget discipline |

---

## 12. External sources

Fetched by the Builder for `docs/research/2026-10-20-mobile-controls.md` on 2026-10-20. **This
Architect run is read-only and could not re-fetch them**; the quotations are that note's.

### A. Roblox Creator Docs — *Position and size UI objects*

<https://create.roblox.com/docs/ui/position-and-size> · **CC BY 4.0** (stated by the
`Roblox/creator-docs` repository) · **maintained**, current.

> "On mobile devices, the default controls occupy a portion of the bottom-left and bottom-right
> corners of the screen." — "Most mobile players use two thumbs — one on the virtual thumbstick and
> one on the jump button." — "A button placed 40% below the screen's top edge is reachable on a phone
> but almost unreachable on a tablet." — "A reliable approach on both phones and tablets is
> **relative** positioning of custom buttons near frequently-used controls like the default jump
> button, placing them within easy reach."

**Well:** the only source that states the two zones as a LAYOUT CONSTRAINT and gives reach a number;
its own sample places a custom button 20 px left of the jump button. It is the whole argument for a
SIBLING cluster rather than more rail — the rail is the top-right, and 40 % below the top edge is
where a thumb cannot go.
**Badly:** no pixel size for either zone, so the keep-outs in section 5.1 are OURS and have to be
measured.
**Adopted:** placement relative to the jump button, 20 px of clearance, two groups with two reach
budgets and two owners.

### B. WCAG 2.2, SC 2.5.5 *Target Size (Enhanced)*, Level AAA

<https://www.w3.org/TR/WCAG22/#target-size-enhanced> · **W3C Document Licence** · W3C
Recommendation 2023, errata 2024, **current**.

> "The target size is at least 44 by 44 [CSS pixels]"

**Well:** a number instead of a feel, and it is the same document `Style` already cites for its
contrast floor — so reach and look are measured against one standard.
**Badly:** a CSS pixel is not a Roblox offset pixel on a high-DPI phone.
**Adopted:** 44 as a floor in `Rail`'s own units (task 165 already cleared it at 48); every target
here clears it by 12 px or more.

### C. Roblox Engine API Reference — `ContextActionService`

<https://create.roblox.com/docs/reference/engine/classes/ContextActionService> · **CC BY 4.0** ·
**maintained**.

> "For touch devices, a button is created on-screen automatically via the 3rd parameter"

**Well:** the borrow-first candidate, and already half-wired — `Input.bind` calls `BindAction` for all
four weapon actions and passes `false`. Flipping one argument would produce touch buttons today.
**Badly, and it is REFUSED (brief §1.2):** (1) the engine's `ContextActionGui` circles cannot wear
`Style`, and a rectangle the engine owns and does not publish cannot be in the no-overlap assertion —
which is the only honest evidence this design has; (2) `GetButton` returns *"nothing"* on a non-touch
device, so there would be no desktop route to any live evidence, the exact trap task 165 named for the
map's old touch-only button that *"never once appeared in her sessions"*.
**Adopted:** nothing. The `false` stays `false`.

### D. Roblox Creator Docs — *Disable default UI*

<https://create.roblox.com/docs/players/disable-ui> · **CC BY 4.0** · **maintained**.

> "Devices with touch capabilities include a virtual thumbstick and a jump button by default. If
> desired, you can hide these elements by setting `GuiService.TouchControlsEnabled` to `false` in a
> client-side script." — the Backpack bar "Does not appear if there are no Tools in the backpack"

**Well:** names exactly what the engine gives a touch player, and confirms the stock hotbar is a real
if poor weapon switch today.
**Badly:** the obvious move it offers — hide them and write our own — is refused: this repo owns no
character controller and movement is not this task.
**Adopted:** the two zones are a CONSTRAINT, not a choice. `TouchControlsEnabled` is never written.

### E. Ours — `Hud.Rail` (task 165) and the Designer's design system §4.2 / §4.3

`src/client/Hud/Rail.luau`, `src/client/Hud/Style.luau`, `docs/design/hud-clarity.md` §6.

**Well:** the pattern this system copies rather than invents — one module owning one frame, every
button *"a second door onto a function that already exists"*, `GuiButton.Activated` as the one event
(*"a click AND a tap, which is why the rail needs no touch branch at all"*), a named `press(id)` seam
because *"a spec cannot fire `GuiButton.Activated`"*, PURE exported rectangle functions because
*"the existing overlap case measures `AbsolutePosition` at whatever size the Studio window happens to
be"*, told-not-read state (`setWeapon`), and two independent suppression flags.
**Badly:** §4.2 and §4.3 are drawn for **400 × 800 only**. Neither says one word about landscape, and
section 5.6 plus section 14 are what that costs.
**Adopted:** all of it, including the look. The only things new in this system are the four buttons,
the placement rule and the fold.

### F. Verification route for the keep-outs, named but NOT relied on

Roblox's own touch control scripts (the `PlayerModule` that ships in `StarterPlayer`, mirrored
historically at <https://github.com/Roblox/Core-Scripts>) contain the jump button's and the
thumbstick's real sizes. **No number in this design comes from it**, and this run could not fetch it:
the Builder must confirm its licence and maintenance status before quoting a single value from it,
and even then the keep-outs are confirmed against a **live** `TouchGui` (section 13.5), not against
source code that may not be the version the client runs.

---

## 13. How it is tested

### 13.1 Client spec, pure — `tests/client/touch_controls.spec.luau` (new)

No drive, no world, no camera, no second player — the shape `hud_clarity.spec` already has.

1. `Touch.visible` and `Touch.shown` — all eight combinations of (touchEnabled, suppressed, covered)
   **and both `showOnDesktop` values by parameter**, so the shipped `false` is not what the test
   rests on.
2. `Touch.buttonVisible` — the four buttons × hasWeapon × carried {0, 1, 2, 3} × hasHorn. FIRE and
   AIM need a gun; SWAP needs two; BLOW needs a horn; **no row draws a button whose action would
   return false**.
3. `Touch.placement` — `left-of-jump` at 800 × 400 and `above-jump` at 400 × 800, driven with the
   real `Hud.leftStackRight`, plus the boundary: one pixel either side of
   `clusterWidth + JUMP_CLEAR_PX`.
4. `Touch.rect` and `Touch.buttonRect` — the exact rectangles of section 5.3 at both viewports; every
   button's shorter side ≥ 44; every pair of buttons ≥ 8 apart; every button ≥ 20 from
   `Touch.jumpKeepOut` and disjoint from `Touch.thumbstickKeepOut`.
5. **The intersection set is empty** at 400 × 800, 800 × 400, 800 × 600, 969 × 784 and 1920 × 1080
   over the set in section 5.3, with the three exclusions written into the test as comments. *This
   is the most valuable case in the file*, for `map_ui.spec`'s own reason: task 125 round 2 shipped a
   strip over the clock and the frames did not show it.
6. `Rail.columnsFor` / `layoutFor` / `heightFor` / `slotFor` / `floorFor` — folds at 800 × 400 and
   400 × 800; **does not fold** at 969 × 784 or 1920 × 1080 and `Rail.rect` there equals today's
   answer (the no-regression claim); `Rail.columnPx(1) == MapUi.CONFIG.RAIL_COLUMN_PX`; no rail
   button is below `viewport.Y - Style.MARGIN` at any of the five viewports.
7. `Touch.reserved` → `(0, 0)` when not shown, and the two exact pairs when shown;
   `Hud.cornerRect` with and without the reserve; `MapUi.fullMapRect(viewport, 124)` is disjoint from
   the folded rail at both phone viewports.
8. `Input.nextToolName` — sorted order, wrap at the end, `nil` current → the first, a name not in the
   list → the first, one name → nil, empty → nil, and a `Horn` among four guns.

### 13.2 Client spec, live

9. The cluster frame exists, is a direct child of the one `ScreenGui`
   (`Hud.touchCluster().Parent == Hud.gui()`), carries four `TextButton` children with the right
   names and sizes, and `frame.Visible == Touch.visible(UserInputService.TouchEnabled,
   Touch.isSuppressed(), Touch.isCovered())`. Then `setSuppressed` / `setCovered` are driven through
   all four states and the frame follows, restoring both — `hud_clarity.spec`'s own idiom for the
   rail.
10. **One path, proved by identity:** `Touch.actionFor("FIRE") == Weapon.Input.fire`,
    `Touch.actionFor("AIM") == Weapon.Input.toggleAim`, `Touch.actionFor("SWAP") ==
    Weapon.Input.swap`, `Touch.actionFor("BLOW") == Weapon.Input.blowHorn`. The button calls the
    function, not a copy of it — so there is nothing for the touch door to drift from.
11. `Input.fire()` returns **false** while `Input.isHeld()` (driven with a spec-owned tag) and
    **true** otherwise; `Touch.press("FIRE")` returns false while covered or suppressed and
    increments `stats().refused`. The real-input half is already covered: the `weapon-fire-reload-ammo`
    scenario in `tests/client/input_scenarios.txt` drives a real MouseButton1 through `onFire`, which
    is now a caller of `Input.fire`.
12. `Touch.press("AIM")` flips `Weapon.Input.isAiming()` and flips it back; `Touch.setAiming` paints
    and unpaints; the restore leaves the flag where it was found.
13. `Touch.press("SWAP")` with two carried Tools (the `RIFLE` flag is on, so a hunter carries
    `Shotgun` + `Rifle`): on the next `Heartbeat` the equipped Tool's name is
    `Input.nextToolName(...)`'s answer — **this is the case that proves `UnequipTools` + `EquipTool`
    does what section 8.2 says**, because Roblox's signals are deferred (measured, task 47). With
    one Tool it returns false and nothing is equipped or unequipped.
14. `Touch.press("BLOW")` with a **spec-made** `Tool` named `Horn.TOOL_NAME` in the Backpack, whose
    `Activated` the spec counts: the count becomes 1, and the Tool is destroyed in the same case.
    This proves the `Activate()` door on this client without a server horn. With no horn carried it
    returns false.
15. `Touch.press("NOT_A_BUTTON")` returns false and counts nothing.
16. The chip's ceiling: with a gun in hand, `Hud.ammoChip().AbsoluteSize.X <=
    Hud.CORNER.MAX_WIDTH_PX`, and `Hud.ammoChip().AbsolutePosition` equals `Hud.cornerRect`'s x/y for
    the live viewport and the live `Touch.reserved` — the chip is where the arithmetic says.
17. The existing `hud_clarity.spec` rail cases are unchanged and still pass: the fold is inert at the
    Play window's 969 × 784.

### 13.3 Server spec

One line in `tests/server/lobby.spec.luau` (section 9.5). Nothing else in `tests/server/` changes:
nothing in this task is the server's.

### 13.4 What a spec cannot reach, said plainly (rules 6 and 8)

* **A tap. There is no synthesised touch.** `tools/studio_mcp.py`'s scenario file speaks `keyboard`,
  `mouse` and `wait` (`STEP_ACTIONS`) and nothing else, and a `moveTo` carries **static** pixels while
  the cluster is anchored to a Play viewport whose size is not fixed (969 × 784 in one run). A click
  at `x = 600, y = 340` is a test that passes on one machine. This is the rail's own limitation
  (`hud-clarity.md` 10.4), already queued as **165a** — *a scenario step that names a GuiObject and
  resolves its centre at replay time* — and this task does not widen it.
* **The Device Emulator.** No command exists; a person clicks it (section 13.5).
* **`ClickablePrompt`'s effect.** The spec asserts the property; that a thumb on the circle fires
  `Triggered` is the engine's, and `ProximityPrompt.Triggered` cannot be raised from a script
  (`shop_panel.spec`'s own header says so). M3 plus the property is the whole of the claim.
* **A beater's BLOW end-to-end.** `Match.CONFIG.ODD_PLAYER_TEAM = "Shooters"`, so the one-player gate
  is a hunter: no horn is granted and `Horn.blow` is never reached from this door in the gate. Case
  14 proves the client half with a fake Tool; the server half is `zz_horn.spec`'s, unchanged. **The
  joined-up path is NOT verified by this task's gate** and must be reported as such.
* **Whether the picture is right.** Karen's eye.

### 13.5 The gate, the keep-out measurement and the screenshot

* **`test2` is N/A.** The changed paths are `src/client/Hud/`, `src/client/Weapon/Input.luau`,
  `tests/client/`, `tests/server/lobby.spec.luau` and `tools/studio_mcp.py` — **none** is in
  `TWO_PLAYER_PATHS`, and `src/shared/Drive/` is deliberately not touched. The one-player
  `[harness] PASS ... scope=all` line is the whole gate (Director, 2026-10-03).
* **`tools/studio_mcp.py` must be edited in the same commit:** the new spec goes into
  `SCOPE_SPECS["hud"]` **and** `SCOPE_SPECS["weapon"]` (the dual membership `shoot_boar` and
  `zz_horn` already use — the geometry is the Hud's and the input is the weapon's), or `selftest`
  fails with *"a spec file belongs to no scope"*, which is a failed harness run and not a note.
  Because that file changes, `--scope auto` resolves to `all`.
* **The keep-out probe.** One case in the new spec: when `UserInputService.TouchEnabled` is true it
  reads `PlayerGui.TouchGui`'s control frames and asserts each is inside the matching keep-out;
  when it is false it asserts `TouchEnabled == false` and **says in its own name** that the touch
  branch did not run. A case that silently skips is a false-PASS path; this one states which world it
  ran in, and the request must report that the touch branch was NOT RUN on a desktop.
* **Screenshots (rule 5) — this task cannot produce them alone, and that is an `ESCALATE.md`
  `NEEDS KAREN` entry.** The exact clicks: Studio → **Test** tab → **Device** → pick a phone
  (landscape **and** portrait), with Play running. Then the Builder runs
  `python tools/studio_mcp.py capture t220-touch-landscape` / `-portrait` and **looks at them**: the
  four buttons clear of both corners, the chip above the cluster, and all four rail buttons on
  screen. Whether the emulator sets `TouchEnabled` is **unverified**; if it does not, the one boolean
  `Touch.CONFIG.SHOW_ON_DESKTOP` is what makes the cluster visible for the frame, and the design says
  so rather than leaving a screenshot nobody can take.

---

## 14. Holes this design does not close, named with numbers

1. **The server's 2 s equip retry can undo a SWAP.** `Hardware.equip` re-equips the granted Tool for
   up to 2 s, at 100 ms intervals, until `tool.Parent == character`. A SWAP inside that window is
   reverted. The fix is in `src/server/Weapon/Hardware.luau` — stop the loop when **any** Tool of
   this system is in the character, not only the granted one — and it is the server's task. Queue.
2. **The prompt says `"Press E"` on a device with no E** (section 9.5). Data, one line, Karen's word.
3. **The bottom-left stack is inside the THUMBSTICK keep-out, today.** The toast feed is
   `left 16, bottom 16` and the hit card sits above it; at 400 × 800 the feed's frame is **440 px
   wide on a 400 px screen** (`Hud.build`'s `feed.Size`). Both predate this task (note §6, and
   `hud-clarity.md` 12.2 for the panels). Not fixed; the cluster is proved clear of both instead
   (12 px in portrait).
4. **A real landscape layout for the top band and the right column is OUT of scope and is the
   Designer's** (brief §2.6). The numbers, so it is queued and not half-done: at 800 × 400 the top
   band owns y 8..138 and the minimap y 140..236, which leaves **148 px** of right-edge column — room
   for two 48 px buttons in one column, which is why four of them fold into a 104 × 104 block. The
   centred panels are still wider than the screen (`Report.CONFIG.PANEL_WIDTH` 760,
   `Hud.BOARD.WIDTH` 520, `START_CARD_WIDTH` 440, the feed 440). A phone layout for those is its own
   task.
5. **The full map does not request an `Input` hold**, so a desktop click fires the gun with the map
   open. The cluster refuses (section 6.2); the mouse door is unchanged. One line, queued.
6. **`Style.isPhone` is keyed on width alone**, so a landscape phone draws desktop-sized type
   (note §5). Deliberately untouched: it is one break point for the whole game
   (`Style.PHONE_BELOW_PX`), and changing it repaints every surface. The Designer's task.

---

## 15. Measure before you build (two items, both cheap)

Neither blocks the design; both are measured with the probe driver task 220 already has
(`220run.py`, pinned by place id).

1. **`Humanoid:EquipTool` while another Tool is held.** Section 8.2 avoids depending on it by calling
   `UnequipTools()` first — which puts the swap into M2's measured state — and live case 13 proves
   the outcome in the gate either way. If both prove false, the fix is one line and the spec names it.
2. **The live `TouchGui` rectangles** (section 13.5). Until then the two keep-outs are OURS, and a
   remeasurement moves two constants.

---

## 16. Open decisions

**None of these blocks building.** Each has a first value, built as written, and is one line or one
pure function to change.

**Karen (feel):**

1. **The four sizes** — FIRE 88, BLOW 72, AIM 64, SWAP 56 — and the **shape** (two columns, FIRE
   bottom-right under the thumb). Hers; the floor is 44.
2. **The four words** — `FIRE`, `AIM`, `SWAP`, `BLOW`. ASCII, ≤ 5 characters to fit a 56 px button.
3. **The SWAP order** is alphabetical by Tool name (`Horn`, `Lever`, `Rifle`, `SemiAuto`, `Shotgun`).
   If she wants the shotgun first, that is `Input.nextToolName`'s comparator — one pure function.
4. **`"Press E"`** on the shopkeeper's prompt (section 14.2).
5. **`Touch.CONFIG.SHOW_ON_DESKTOP`**, shipped **false** (section 7). One boolean if she wants to see
   it on her PC — and note that turning it on moves her ammo chip 144 px left and 168 px up.
6. **AIM as a toggle on touch** (brief §1.5, already decided). It is re-listed because it is the one
   place the two doors behave differently, and only she can say whether a toggle feels right with a
   thumb.

**The Director (scope):**

7. **The look of the cluster**, expected back as a second cheap task (brief §4). This design borrows
   the rail's ghost slate whole and departs from it twice, by one line each (section 6.4).
8. **The six queued items** in sections 14.1, 14.2, 14.4, 14.5 and 165a — in particular whether the
   Designer's landscape/phone layout comes before or after v1.
9. **No feature flag** (brief §1.11), and this design agrees: the path is reachable only on a device
   Karen does not play on, `SHOW_ON_DESKTOP = false` already makes it invisible on hers, and
   `docs/design/feature-flags.md`'s 21-day expiry would be ceremony with no playtest behind it. If
   the Director wants one anyway, the row is `TOUCH_CLUSTER`, read once in `Touch.CONFIG` and passed
   inward — the only permitted shape.

---

## 17. Build order

One task, nothing extra. In this order, because each step leaves the tree working and testable.

1. **`Weapon.Input`**: `fire`, `setAim`, `toggleAim`, `nextToolName`, `carriedSummary`, `swap`,
   `blowHorn`, and the two handlers reduced to callers. Pure case 8 and live cases 11-15.
2. **`Rail`**: `widthFor`, `columnPx`, `heightFor(count, columns)`, `slotFor`, `floorFor`,
   `columnsFor`, `layoutFor`, `applyLayout`; `MapUi.setRailColumn` and the parameterised
   `fullMapRect`; the three removed lines archived under `backups/`. Pure case 6, and
   `hud_clarity.spec` still green (case 17).
3. **`Hud.Touch`**: the pure half only — `CONFIG`, `BUTTONS`, `shown`, `visible`, `buttonVisible`,
   `clusterSize`, `placement`, `rect`, `buttonRect`, the two keep-outs, `reserved`. Pure cases 1-5
   and 7. Nothing is drawn yet.
4. **`Hud`**: `Hud.FEED.WIDTH`, `Hud.leftStackRight`, `Hud.CORNER.MAX_WIDTH_PX`, `Hud.cornerRect`,
   the new `TouchCluster` frame and `Hud.touchCluster()`. Pure case 5 now runs against the real
   constants.
5. **`Hud.Touch`'s drawing half** plus the tells in `Hud.start`, `render`, `renderScope`,
   `renderObjective` and `renderCorner`. Live cases 9, 10 and 16.
6. **The lobby line** (section 9.5) and the keep-out probe case.
7. `SCOPE_SPECS["hud"]` and `["weapon"]` gain the new spec; `GAME_DESIGN.md`'s owners table gains
   `Hud.Touch` with its one-writer sentence and `Weapon.Input`'s four new functions;
   `docs/research/INDEX.md` already has the note.
8. The harness (`test`; `test2` N/A with the reason), then the `NEEDS KAREN` emulator click and the
   two screenshots, **inspected**.
