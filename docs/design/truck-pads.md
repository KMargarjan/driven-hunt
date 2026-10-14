# Truck pads: four coloured rectangles, four parties, one hunt

Task 182. Design for `reviews/task-182/BRIEF.md`, which is this document's input and overrides
anything older (`docs/ARCHITECT_PROMPT.md`). Research note:
`docs/research/2026-10-14-truck-pads.md`.

**Scope.** The four pads behind task 180's four trucks, their state machine, the size dialog and the
one inbound door it needs. It replaces task 177's single orange circle. It does **not** build a
teleport, a car ride, or a party that outlives the rectangle it is standing on.

**Evidence basis.** Every claim about existing code below names a file and a symbol. No link in
section 13 was opened in this session (the Architect has Read, Grep and Glob only) — the same
disclosure `docs/design/lobby.md` section 14 makes. Nothing was run: the evidence in
`.agent-evidence/` is for `c0f24f9`.

---

## 1. What the system must do

1. **A coloured rectangle behind each of the four trucks** `Lobby.Build.trucks` already parks
   (`src/server/Lobby/Build.luau`, `trucks`), one per truck, four distinct colours, a glowing rim,
   with the truck's number and the party's fill readable from the porch.
2. **The first player onto an empty pad is asked how many**, in a dialog with four big buttons:
   `1 / 1`, `2 / 2`, `4 / 4`, `8 / 8`. Only he may answer, and that is measured server-side.
3. **Others join by standing on it.** Membership is *who is standing on this rectangle right now*,
   re-measured on the lobby's existing 10 Hz scan (`src/server/Lobby/init.luau`, `Lobby.step`).
4. **A pick nobody makes defaults to `1` after `PICK_TIMEOUT_SECONDS`** — so the whole path works
   with no client at all (BRIEF 1h, section 15.4).
5. **The party leaves** when the pad fills or after `FILL_TIMEOUT_SECONDS`, then
   `COUNTDOWN_SECONDS`, through task 177's existing door: `world.enrol`, one call per member
   (`docs/design/lobby.md` 4.2).
6. **The screen says so**: the lobby's objective row becomes *"step on a truck pad to hunt"*, and
   the chevron, the compass marker and the full map point at the **nearest** pad.
7. **It costs nothing per frame.** No new clock, no write per scan: the billboard and the pad's two
   attributes change on an edge, the discipline `setRespawn` and `Build.faceKeeper` already follow
   (`src/server/Lobby/init.luau`, `setRespawn`; `src/server/Lobby/Build.luau`, `Build.faceKeeper`).

### What it must not do

* **Must not become a second writer of the roster.** `Match.enrol` / `Match.dismissAll` stay the
  drive's only two doors (`docs/design/lobby.md` 4.2, 4.5). `Lobby` gains no `setTeam`, no `dress`,
  no `Weapon` and no `Horn`, and still requires neither `Match` nor `Match.Body`.
* **Must not write a character's position.** It follows that **pad size is a target and never a
  cap**: this owner cannot keep a ninth man off a pad without pushing him, and pushing him would
  make it a second writer of where a character stands (`docs/design/lobby.md` 4.5, row 2). Section
  6.4 states what the rule does instead.
* **Must not let a client decide who hunts or how many.** Every fact is measured server-side; the
  payload carries two numbers and both are validated against the data table (section 8.2).
* **Must not promise a reserved server.** `TeleportService` cannot be tested in Studio, which is
  this repository's whole evidence chain. The seam is named and left unbuilt (section 9).
* **Must not add a second clock, a second countdown length, or a second answer to "when do I
  leave".** `COUNTDOWN_SECONDS = 5` is reused unchanged, and `DHLobbyLeaveAt` stays the one deadline
  the screen counts down.
* **Must not put a Script, LocalScript or ModuleScript into `Workspace`** (CLAUDE.md; the harness
  fails on one). A `BillboardGui` is not script-like — the reasoning `Build`'s own header already
  records for `SurfaceGui`.
* **Must not require the DEV place to have a lobby.** `Lobby.ANCHORS` has one row (`forest-test`);
  `Lobby.anchorFor("map:v1")` is nil, so the harness's world builds nothing and every spec builds
  into a folder of its own.
* **Must not design the car ride.** Karen's doc has one (*"you sit in car and drive to position"*).
  It is a later task, and the only thing this design owes it is the `leaving` state (section 6.3).

---

## 2. What this supersedes in `docs/design/lobby.md`, with the replacement wording

BRIEF 5. Sections 6, 10.3 and 14.3 are replaced; everything else in that document stands.

### 2.1 Replacement for `lobby.md` section 6 — "The join rule, as pure arithmetic"

> ## 6. The join rule, as pure arithmetic (task 182: four pads, not one circle)
>
> Pattern: **Valve's `trigger_multiple` read as arithmetic** — presence, not collision (§14.2) —
> widened from a circle to a **rectangle**, which is Karen's own word (*"rectangle where people
> stand"*). The circle and its five-second walk-in are gone; they are archived with their reason in
> `backups/2026-10-14_task-182_the-marked-circle.txt` (rule 7).
>
> ```luau
> -- src/server/Lobby/Join.luau -- PURE. No Instance, no service, no clock.
> -- FLAT and `<=`, exactly as the circle was: a man on the pad's edge is on the pad.
> function Join.withinRect(position: Vector3, centre: Vector3, size: Vector3): boolean
> function Join.insideField(position: Vector3, anchor: Vector3, cfg): boolean   -- unchanged
> function Join.needsReturn(inDrive: boolean, held: boolean, inField: boolean?): boolean  -- unchanged
> ```
>
> **Standing on a pad no longer enrols you by itself.** It puts you in a PARTY, and the party leaves
> — `empty -> sizing -> filling -> countdown -> leaving`, a pure state machine in
> `src/server/Lobby/Pads.luau`. The whole rule is `docs/design/truck-pads.md` section 6, and the
> countdown belongs to the PAD and not to a player. `Join.within` and `Join.decide` are archived
> with the circle.

### 2.2 Replacement for `lobby.md` section 10.3 — "Where the truck's position comes from"

> ### 10.3 Where the pads are — one definition, and pad 1 keeps the name
>
> The **server builds** the parts; the **client reads them**; nobody computes a position twice.
>
> ```luau
> -- src/shared/Lobby/init.luau
> Lobby.FOLDER_NAME = "Lobby"
> Lobby.SPOT_NAME = "TruckSpot"        -- = CONFIG.PADS.PART_NAMES[1]: PAD 1's own part
> Lobby.SPAWN_NAME = "LodgeSpawn"
>
> function Lobby.spotPart(): BasePart?        -- pad 1. Unchanged signature, unchanged readers
> function Lobby.spotPosition(): Vector3?     -- "the first place you can start a hunt"
> function Lobby.padPart(index: number): BasePart?      -- task 182
> function Lobby.padPositions(): { Vector3 }            -- task 182, in pad order
> ```
>
> **Pad 1's part is named `TruckSpot`** (BRIEF 1i). It is the same invisible-to-the-rule marker the
> circle had — now the pad's own visible slab — so `Lobby.spotPart`, `Lobby.spotPosition`,
> `Objective.targetFor`'s `kind = "truck"` and the Director's `smoke.sh` keep working with no edit.
> All four readers are memoised and drop the cache when the part leaves the DataModel
> (`IsDescendantOf(game)`), which is `MapUi.pointsFor`'s rule: *a stale dot is a lie about where
> somebody is*.

### 2.3 Replacement for `lobby.md` section 14.3 — the `ProximityPrompt` rejection

> ### 14.3 Roblox Creator Docs — `ProximityPrompt` — **REJECTED FOR THE PAD, ADOPTED FOR THE SHOP**
> <https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt>
> *Licence:* CC BY 4.0. *Maintenance:* first-party, current.
> **Well:** first-party, draws its own UI, `HoldDuration` IS a countdown, `Triggered` reaches the
> server. Task 181 adopted it for the shopkeeper, where pressing a key at a man is exactly what
> Karen asked for (*"a person bot who you need to click E to get access to shop"*).
> **Badly, for the pad:** it is a BUTTON, and Karen asked to *walk onto a rectangle*. A pad's
> membership has to be re-measured every tick (a man who steps off leaves the party), which is a
> presence question and not a trigger; and a second `E` binding in the lobby would be a second owner
> of one key — the failure CLAUDE.md rule 3 exists for.
> **So: the prompt opens the shop, and arithmetic decides the pads.** Recorded so it is not
> re-litigated in either direction.

---

## 3. The owner, and its location on disk

`Lobby` stays the owner and gains no new one (BRIEF 1e).

| Disk | Studio | Role | New in 182 |
|---|---|---|---|
| `src/shared/Lobby/init.luau` | `ReplicatedStorage.Lobby` | frozen DATA with no run-time writer: `CONFIG.PADS`, the attribute names, the pure readers | `CONFIG.PADS`, `PAD_STATE_ATTRIBUTE`, `PAD_FIRST_ATTRIBUTE`, `padPart`, `padPositions`, `padAsking`, `remotes()` |
| `src/shared/Lobby/Remotes.model.json` | `ReplicatedStorage.Lobby.Remotes` | the one inbound `RemoteEvent` | **new file** |
| `src/server/Lobby/init.luau` | `ServerScriptService.Lobby` | **the owner**: the pad state, the door, the rate bucket, the departure | `onPadRequest`, `depart`, the pads table |
| `src/server/Lobby/Pads.luau` | `…Lobby.Pads` | **pure**: pad geometry and the state machine. No Instance, no clock, no service | **new file** |
| `src/server/Lobby/Join.luau` | `…Lobby.Join` | **pure**: the rectangle predicate, the field predicate, the return rule | `withinRect`; `within` / `decide` archived |
| `src/server/Lobby/Build.luau` | `…Lobby.Build` | the one **writer** of every part, GUI and attribute in `Workspace.Lobby` | `Build.pads`, `Build.setPad`, `Build.padPart`, `Build.padLabel`; `spot` archived |
| `src/client/Hud/PadPanel.luau` | `…Hud.PadPanel` | the one writer of everything inside the `PadPanel` frame, **including its `Visible`** | **new file** |

**No new boot script and no new wiring order.** `ForestTestBoot` already calls `Lobby.start`,
`Lobby.step` and `Lobby.onPhase` (`src/server/ForestTestBoot.server.luau`); this task adds exactly
one field to the `Lobby.start` table (`remotes = Lobby.Data.remotes()`) and nothing else.

### 3.1 Row for `GAME_DESIGN.md`'s *System owners* table

Amend the lobby row's parenthesis — it currently reads *"the marked circle"*:

> …the log lodge, the four trucks, **the four truck pads and the party standing on each of them
> (`empty -> sizing -> filling -> countdown -> leaving`, derived at 10 Hz and never stored)**, the
> lodge spawn — `Workspace.Lobby` — and WHO HAS ASKED TO HUNT. Since task 182 it is also the one
> listener of `ReplicatedStorage.Lobby.Remotes.PadRequest` (the party-size pick: server-measured,
> rate-limited, forgery-counted) and the one decider of the two `DHPad*` attributes, which
> `Lobby.Build` writes because `Build` is the one writer of every instance in `Workspace.Lobby`. It
> still writes no team, no character position, no clothes, no tool and no roster entry.

---

## 4. The geometry, measured

Every clearance below is arithmetic over values already in `Lobby.CONFIG`
(`src/shared/Lobby/init.luau`) and literals already in `src/server/Lobby/Build.luau`. Offsets are
relative to the anchor, +x east and +z north.

```luau
-- src/server/Lobby/Pads.luau -- PURE, and it is the ONE place this arithmetic is written.
-- `Build.pads` and `Lobby.step` both call it, so "where is pad 3" has one answer. Task 177 had the
-- same expression (`anchor + cfg.SPOT.OFFSET`) in TWO files -- `Build.spot` and `Lobby.tryBuild` --
-- and this closes that.
function Pads.centreFor(anchor: Vector3, index: number, cfg): Vector3
    return anchor
        + Vector3.new(
            cfg.TRUCK.OFFSET.X + (index - 1) * cfg.TRUCK.BAY_GAP_STUDS,
            cfg.ROAD.THICK_STUDS + cfg.PADS.LIFT_STUDS - cfg.PADS.SIZE.Y / 2,
            cfg.TRUCK.OFFSET.Z + cfg.TRUCK.PAD_BEHIND_STUDS + cfg.PADS.SIZE.Z / 2
        )
end
```

**x = the bay's own x.** `TRUCK.OFFSET.X` 26, `BAY_GAP_STUDS` 17 → 26, 43, 60, 77. One definition of
where bay *n* is, shared with `Build.trucks`.

**z: `PAD_BEHIND_STUDS` is read as "from the bay centre to the pad's NEAR edge", and that is a
re-reading of task 180's words with a measurement behind it.** Task 180 wrote *"12 studs behind the
tailgate"*, but there are **two** tailgates: the parts truck's `BedTail` is built at `at.Z + 8` with
0.4 of depth (`Build.luau`, `truck`) → face at +8.2, and the free model is 18.5 studs long yawed a
quarter turn (`TRUCK.MODEL`) → half-length 9.25. A pad defined off "the tailgate" would therefore
move when a model is swapped. From the bay centre it does not: pad *n* spans **z +30 … +42**, which
clears the parts tailgate by 3.8 studs and the model's by 2.75.

**y: the slab is SUNK, and that is the whole of the task-177 round-1 finding applied in advance.**
The ring was lifted 0.08 off the *shelf* and so sat 0.42 studs **inside** the opaque road slab —
*"the lobby had a sign reading 'STAND HERE TO HUNT' with nothing to stand in"* (`Build.luau`,
`spot`). A pad's footprint straddles three surfaces: the parts `Yard` slab (`Build.road`, x +3…+94,
z −4…+40), the `Lane` and its east `Verge`, and bare blade-free terrain north of z +40
(`FIELD.PADS[1]`). So the pad's **top** is `shelfY + ROAD.THICK_STUDS + LIFT_STUDS` = +0.58 (above
every slab) and its **bottom**, at `SIZE.Y = 0.7`, is `shelfY − 0.12` (below the terrain top) — so
there is no floating edge anywhere and no slab the pad can hide inside. One number, both failures
closed.

### 4.1 Why the pad is 9 x 12 and not 14 x 10

The brief's first value was *~14 x 10*. **14 does not fit, and 10 x 14 does not either; the
measurements are these:**

| Neighbour | Where it is | Bound it sets |
|---|---|---|
| the parts lodge's east wall | `logWall(… "WallE" … origin.X + halfX)` with `LOG_DIAMETER` 2 → outer face x **+21** | pad 1's west face ≥ 21 → **half-width ≤ 5** |
| the parts porch deck | `Deck`, x −20…+20, z +24…+32 (`PORCH_DEPTH` 8) | cleared by the same bound |
| the parts porch roof | `size.X + 3` → x ≤ **+21.5**, 11 studs above the ground | pad 1's west face at 21.5 is exactly its drip line; nothing intersects at ground level |
| the free-model lodge | 23.1 studs wide at `LODGE.OFFSET` → x ≤ **+11.6** | not binding: pad 1 clears it by 9.9 studs |
| both tailgates | +8.2 (parts) and +9.25 (model) | pad's near edge ≥ 12 → **clear by ≥ 2.75** |
| `Build.treeLine`'s yard exclusion | a tree is skipped when `|z − TRUCK.OFFSET.Z| < 26` and `|x − yardMidX| < yardHalfX + 4` → z < +44, x < +98 | pad's far edge ≤ **+42** and pad 4's east face +81.5 → **no tree can stand on a pad** |
| `FIELD.SPAN_STUDS` 220 | half-span 110 | max |x| 81.5, max |z| 42 ✓ |

So: **`SIZE = Vector3.new(9, 0.7, 12)`** — 9 wide, 12 deep, a rectangle pointing back from the
tailgate, which is where a man loading into the back would stand. 108 square studs holds eight
bodies at two across and four deep; `BAY_GAP_STUDS` 17 leaves **8 studs between pads**, so four
parties read as four places rather than one stripe. Karen retunes `SIZE` in one row, and
`lobby.spec` holds every clearance above as arithmetic (section 15.1 case 1), so a retune that
breaks one fails the harness instead of looking wrong in a screenshot.

---

## 5. The data: `Lobby.CONFIG.PADS`

BRIEF 1k — every number and every word is data, deep-frozen by the `Shotgun.deepFreeze` call already
at the bottom of `src/shared/Lobby/init.luau`. Nothing numeric in `Build`, `Join`, `Pads` or the
panel.

```luau
PADS = {
    -- ---------------- the rectangle (section 4.1: every number here is a clearance, not a taste)
    SIZE = Vector3.new(9, 0.7, 12),
    LIFT_STUDS = 0.08,              -- `SPOT.RING.LIFT_STUDS`'s number, kept: z-fighting
    RIM_STUDS = 0.5,                -- the glowing border's width, `RING.THICKNESS_STUDS`'s number
    RIM_HEIGHT_STUDS = 0.12,        -- `RING.HEIGHT_STUDS`'s number
    TRANSPARENCY = 0.45,            -- `RING.TRANSPARENCY`'s number: the deck is a stain, not a wall
    -- FOUR HUES, AND THE RING'S HUNTING ORANGE STAYS IN THE PALETTE so the lobby's colours do not
    -- change (the Director). A colour-blind player still tells them apart by POSITION: they are in a
    -- row and each billboard says its truck's number.
    COLOURS = {
        Color3.fromRGB(86, 170, 88),    -- 1 green
        Color3.fromRGB(72, 124, 208),   -- 2 blue
        Color3.fromRGB(235, 150, 60),   -- 3 orange  (`SPOT.RING.COLOR`)
        Color3.fromRGB(150, 96, 200),   -- 4 violet
    },
    -- PAD 1'S PART IS CALLED `TruckSpot` (BRIEF 1i), and that is a DATA row rather than a branch in
    -- `Build`: `Lobby.spotPart`, `Lobby.spotPosition`, the Hud's chevron and the Director's
    -- `smoke.sh` all find it by that name, and none of them has to change.
    PART_NAMES = { "TruckSpot", "TruckPad2", "TruckPad3", "TruckPad4" },
    -- ---------------- the party
    -- 8 IS THE DRIVE'S WHOLE ROSTER (`Match.CONFIG.BOTS.TARGET`: 4 hunters + 4 beaters), and 1 is
    -- today's game exactly -- one man and seven bots. ORDER MATTERS: row 1 is the default a pick
    -- nobody makes falls back to (section 6.4).
    SIZES = {
        { size = 1, label = "1 / 1  alone" },
        { size = 2, label = "2 / 2" },
        { size = 4, label = "4 / 4" },
        { size = 8, label = "8 / 8  full hunt" },
    },
    -- ---------------- the clocks (all three read by `Pads.step`, which holds no clock of its own)
    PICK_TIMEOUT_SECONDS = 8,       -- BRIEF 1h, and it is load-bearing for the evidence (15.4)
    FILL_TIMEOUT_SECONDS = 45,      -- the longest a solo player waits for friends who are not coming
    -- COUNTDOWN_SECONDS IS NOT HERE. `CONFIG.COUNTDOWN_SECONDS` (5) is reused, because a second
    -- countdown length would be a second answer to "how long until I go".
    -- ---------------- the door
    REQUEST_MIN_INTERVAL = 0.25,    -- `Shop.CONFIG.REQUEST_MIN_INTERVAL`: 4/s/player, a forgery guard
    -- ---------------- the words over the pad
    BILLBOARD = {
        TRUCK = "TRUCK %d",         -- the truck number is what tells four identical pads apart
        COUNT = "%d / %d",          -- Karen's own format: *"can be 1/1 or 4/4"*
        COUNT_UNSET = "%d / -",     -- nobody has picked yet: "-" is not "0"
        OFFSET_STUDS = 6,
        SIZE_PX = Vector2.new(180, 64),
        TRUCK_PX = 22,
        COUNT_PX = 30,
        MAX_DISTANCE_STUDS = 160,   -- readable from the porch (46 studs), gone across the field
    },
    -- ---------------- the dialog
    PANEL = {
        TITLE = "HOW MANY PLAYERS?", -- Karen's word: *"select how many players"*
        WIDTH = 300,
        HEADER_PX = 44,
        ROW_PX = 48,
        GAP = 8,
        BUTTON_PX = 48,             -- `Rail.CONFIG.BUTTON_PX`, over Roblox's own 44 px minimum
        Z_INDEX = 15,               -- `Report.CONFIG.PANEL_Z_INDEX`'s band; `Rail` is 16 and stays
    },                              --   pressable over it, the `Shop.CONFIG.PANEL` arrangement
}
```

`CONFIG.SPOT` (the circle's offset, radius, ring and sign) is removed with the circle and archived
with its reason in `backups/2026-10-14_task-182_the-marked-circle.txt` (rule 7), together with
`Build.spot`, `Join.within` and `Join.decide`.

---

## 6. The state machine

BRIEF 3 item 1. Pure, in `src/server/Lobby/Pads.luau`, for exactly the reason `Join`'s own header
gives: *"that is what lets `tests/server/lobby.spec.luau` drive the entry, the cancel, the re-entry
and the exact boundary second with hand-written numbers and no character at all."*

```luau
export type Occupant = { userId: number, since: number }
export type Pad = {
    index: number,
    state: string,          -- one of the five below
    size: number?,          -- the pick, or nil in `empty` / `sizing`
    firstUserId: number?,   -- who picks. MEASURED, never sent
    deadline: number?,      -- when THIS state's clock runs out, in the owner's own `now`
    members: { number },    -- sorted userIds standing on it at the last scan
}

Pads.EMPTY, Pads.SIZING, Pads.FILLING, Pads.COUNTDOWN, Pads.LEAVING =
    "empty", "sizing", "filling", "countdown", "leaving"

-- ONE TRANSITION PER CALL, for the reason `Join.decide` returned one verdict: the caller does a
-- different thing for each, and a function that applied two of them would hide one. The cost is at
-- most 1/SCAN_HZ (0.1 s) of slack per edge, which section 14 counts into the smoke window.
function Pads.step(pad: Pad, members: { Occupant }, now: number, cfg): (Pad, string)
function Pads.withSize(pad: Pad, size: number, now: number, cfg): (Pad, boolean)
function Pads.sizeAllowed(size: any, cfg): boolean
function Pads.defaultSize(cfg): number                 -- = SIZES[1].size = 1
function Pads.labelFor(pad: Pad, cfg): (string, string) -- the billboard's two lines
function Pads.indexAt(position: Vector3?, anchor: Vector3, cfg): number?
function Pads.empty(index: number): Pad
```

The six verdicts: `Pads.NONE`, `Pads.ASK` (a pick is wanted — from a named player), `Pads.SET`,
`Pads.ARMED` (the countdown started), `Pads.DEPART` (send the party), `Pads.CANCELLED`.

### 6.1 The states

| State | What it means | What is on the billboard |
|---|---|---|
| `empty` | nobody is standing on it. No size, no first player, no deadline | `TRUCK n` / `0 / -` |
| `sizing` | somebody is on it and the first man has not answered. `deadline = now + PICK_TIMEOUT_SECONDS` | `TRUCK n` / `k / -` |
| `filling` | a size is chosen; the pad is waiting for bodies. `deadline = now + FILL_TIMEOUT_SECONDS` | `TRUCK n` / `k / size` |
| `countdown` | it is going. `deadline = now + CONFIG.COUNTDOWN_SECONDS` (5, unchanged) | `TRUCK n` / `k / size` |
| `leaving` | one scan long: the owner hands the party over and the next scan re-derives | `TRUCK n` / `k / size` |

### 6.2 The transitions, with what happens at each boundary

| From | Trigger | To | At the boundary |
|---|---|---|---|
| `empty` | the first occupant appears | `sizing` | `firstUserId` = that occupant, `deadline = now + PICK_TIMEOUT`; verdict `ASK` → the owner writes `DHPadState`/`DHPadFirst`, and **that player's own client opens the dialog** (section 8.1) |
| `sizing` | a legal pick from the first player (`Lobby.onPadRequest`) | `filling` | `size = k`, `deadline = now + FILL_TIMEOUT`; verdict `SET`. The dialog closes because the attribute changed, not because the client decided |
| `sizing` | `now >= deadline` (nobody answered) | `filling` | `size = Pads.defaultSize(cfg)` = **1**; verdict `SET`. BRIEF 1h |
| `sizing` | the first player steps off, ≥ 1 other remains | `sizing` | **re-elected**: `firstUserId` = the earliest-`since` remaining member, `deadline = now + PICK_TIMEOUT` — a **fresh** clock, which is `Join.decide`'s own rule (*"RE-ENTRY DOES NOT INHERIT THE OLD DEADLINE"*). Verdict `ASK` |
| `sizing` | the pad empties | `empty` | everything dropped; verdict `CANCELLED` |
| `filling` | a join or a leave | `filling` | `members` changes, the billboard changes, nothing else. No verdict beyond `NONE` |
| `filling` | `#members >= size` | `countdown` | `deadline = now + COUNTDOWN_SECONDS`; verdict `ARMED` → the owner writes `DHLobbyLeaveAt` on **every member** |
| `filling` | `now >= deadline` (fill timeout) | `countdown` | identical to the row above |
| `filling` | the pad empties | `empty` | **the size is dropped**: a pad nobody is standing on has no party. Verdict `CANCELLED` |
| `countdown` | a join | `countdown` | he is in the party and gets `DHLobbyLeaveAt`. **The deadline does not move** — a late arrival must not be able to push back a clock somebody else is watching |
| `countdown` | a leave, ≥ 1 remains | `countdown` | his `DHLobbyLeaveAt` is cleared. The deadline does not move |
| `countdown` | the **last** man steps off | `empty` | cancelled, every `DHLobbyLeaveAt` cleared, **nobody is enrolled**; verdict `CANCELLED` |
| `countdown` | `now >= deadline` | `leaving` | verdict `DEPART` → the owner calls `Lobby.depart` **once**, with the members standing there at that instant |
| `leaving` | the next scan | `empty` (or `sizing`) | **derived, not decided**: anyone the drive took is `inDrive` and is no longer an occupant (`stepPlayer` returns early for him), so the pad empties by itself. Anyone `depart` failed on is still standing there, so the pad re-enters `sizing` and he is asked again — a failed hand-over retries instead of stranding him |

### 6.3 The three boundaries the brief asked to be explicit about

* **The first player steps off in `sizing`:** the pad does not cancel while anybody is on it. It
  re-elects the earliest remaining occupant and restarts the pick clock. A pad that cancelled would
  throw away three men because the fourth walked away.
* **The first player steps off in `filling`:** nothing happens to him and nothing happens to the
  pad. The size is already chosen, and "who picked" has no meaning after the pick.
* **The last man steps off in `countdown`:** the pad cancels and nobody is enrolled. Karen's own
  rule from task 177 — *stepping out cancels it* — read at the level of the pad, which is where the
  countdown now lives.
* **`leaving` is the car ride's seam.** Today it lasts one scan. A later task that drives the party
  to the position holds the pad in `leaving` for the length of the ride; nothing else in the machine
  changes.

### 6.4 Size is a target, not a cap — and that follows from the owner boundary

`#members >= size` triggers the countdown; `size` never refuses anybody. The reason is not taste:
keeping a ninth man off a 9 x 12 slab would mean moving him, and `Lobby` **must not write a
character's position** (`docs/design/lobby.md` 4.5: *"the only move it asks for is
`world.place(player, cframe)`"*). The game is unharmed — the drive has eight slots and bots fill
every slot no player takes (`Match.CONFIG.BOTS.TARGET`, task 161), so an over-full pad simply sends
more men and fewer bots. The alternative (refusing the extra men) would also have to tell them why,
in a place where the honest answer is *"stand on the next pad"*, and the next pad is 17 studs away.

### 6.5 Four pads are four doors into one hunt, in words

BRIEF 1b. There is **one drive on this server**. A pad's party of 8 **is** the whole hunt; a party of
1 is one man and seven bots, which is today's game. What a pad buys a player is **leaving with his
friends instead of alone**. So:

* **a pad is not blocked while a drive runs.** `Match.enrol` dispatches `{ kind = "join" }` in any
  phase and `Phase.step`'s `join` branch assigns and places a mid-drive arrival
  (`docs/design/lobby.md` 4.2, 6) — which is what task 177's circle already does for one player. The
  Director's default is kept: **the mid-drive join stays**. "HUNT IN PROGRESS, pads inert" was
  considered and refused, because it would make four pads dead for up to ten minutes to protect a
  behaviour the drive already supports and `match_phase.spec` already tests.
* **the party is derived, never stored** (BRIEF 1c). `Pad.members` is recomputed from positions every
  scan and is never a list anybody appends to. A party object with its own lifetime would be a
  second answer to "who is in party 2", which is this project's named failure mode
  (`docs/PROJECT_CONTEXT.md`).

---

## 7. The owner table: one writer each

BRIEF 3 item 2.

| Thing | The one writer | Who decides |
|---|---|---|
| every part of the four pads (deck, rim, billboard) | `Lobby.Build` (`Build.pads`), called once from `Build.build` | — |
| the billboard's two lines | `Lobby.Build` (`Build.setPad`) | `Lobby.step`, from `Pads.labelFor` |
| the pad attributes `DHPadState`, `DHPadFirst` | `Lobby.Build` (`Build.setPad`) — because `Build` is *"the one writer of every part in `Workspace.Lobby`"* and an attribute is written **on** one of its parts | `Lobby.step` / `Lobby.onPadRequest` |
| the pad's state, size, first player and deadline | `ServerScriptService.Lobby` (the `pads` table) | `Lobby.Pads` (pure) |
| the `DHLobbyLeaveAt` attribute on a `Player` | `ServerScriptService.Lobby` — **unchanged from task 177** | `Lobby.step` |
| `Player.RespawnLocation` | `ServerScriptService.Lobby` — unchanged | unchanged |
| the enrolment / the roster | `ServerScriptService.Match` | `Lobby` **asks**, through `world.enrol`. It writes no roster entry |
| the dialog's `Visible` and everything inside the `PadPanel` frame | `Hud.PadPanel` | the server, through `DHPadState` + `DHPadFirst` |
| the `PadPanel` frame itself | `Hud.build` (one ScreenGui, built once — the `ShopPanel` arrangement) | — |
| the objective line and the chevron | `Hud.Objective` | `Hud.renderObjective`, the one evaluation |
| the per-player rate bucket | `ServerScriptService.Lobby` (`lastPadRequestAt`), emptied by `Lobby.forget` and `Lobby.stop` | — |

The one new judgement call, written down: **the two `DHPad*` attributes are written by `Build` and
decided by `Lobby`.** That is `Build.faceKeeper`'s arrangement exactly (*"`Build.faceKeeper` is the
one writer of his CFrame, and WHO he faces is `Lobby.step`'s to decide"*), and it is why
`Build.setPad` returns whether it wrote anything — so `stats.padWrites` counts **edges**, and a
counter that climbs with `stats.scans` is a bug the spec catches (the `keeperTurns` precedent).

---

## 8. The wire

BRIEF 3 item 3.

### 8.1 Outbound: two attributes, no new remote

Task 177 deliberately used *one attribute per player and no remote at all*
(`src/shared/Lobby/init.luau`, `LEAVE_AT_ATTRIBUTE`: *"ATTRIBUTES AS A ONE-WAY, READ-ONLY MIRROR IS
THIS REPO'S OWN PATTERN"* — `ReplicatedStorage.Flags.State`, `ServerStorage.DHFlag_*`,
`DHForestStartRole`, `LocalPlayer.TestReport`). **A pad's state is public, not per-player**, so it
goes on the pad's own part, which is the `Flags.State` shape and the exact fallback
`docs/design/lobby.md` section 18 item 5 already names for a direction it could not prove.

```luau
-- src/shared/Lobby/init.luau
Lobby.PAD_STATE_ATTRIBUTE = "DHPadState"   -- string: "empty"|"sizing"|"filling"|"countdown"|"leaving"
Lobby.PAD_FIRST_ATTRIBUTE = "DHPadFirst"   -- number?: the userId who may pick, or nil
```

**Exactly two, and both are read.** `DHPadSize` and `DHPadCount` were considered and refused: the
fill is already on the billboard the server draws, so an attribute carrying it would be *"an
argument nobody reads is an argument nobody checked"* (`Shop.checkRequest`'s own words). The
countdown the player needs is the one he already gets: `DHLobbyLeaveAt`, written per member on the
`filling -> countdown` edge, converted through `Workspace:GetServerTimeNow()` at the boundary — the
one conversion `stepPlayer` already makes.

```luau
-- src/shared/Lobby/init.luau -- PURE over the DataModel, memoised like `spotPart`
function Lobby.padStateOf(index: number): (string?, number?)   -- state, firstUserId
-- WHICH PAD IS ASKING THIS PLAYER TO PICK, or nil. The dialog's whole visibility rule, and it is a
-- SERVER-MEASURED fact mirrored in an attribute -- the client holds no opinion about who is first.
function Lobby.padAsking(userId: number): number?
```

### 8.2 Inbound: one `RemoteEvent`, `Shop.onRequest`'s shape

Task 177's lobby has **no inbound door at all**, and a dialog is a message from a client, so this is
the one genuinely new mechanism in the task (BRIEF 1f). Every property below is already true of
`src/server/Shop/init.luau`.

```json
// src/shared/Lobby/Remotes.model.json  ->  ReplicatedStorage.Lobby.Remotes
{ "className": "Folder", "children": [ { "name": "PadRequest", "className": "RemoteEvent" } ] }
```

```luau
-- src/shared/Lobby/init.luau
Lobby.REMOTES_NAME = "Remotes"
Lobby.PAD_REQUEST_REMOTE = "PadRequest"
function Lobby.remotes(): { PadRequest: RemoteEvent }   -- memoised, `Shop.remotes`' shape

-- src/server/Lobby/init.luau
-- THE ONE INBOUND HANDLER, PUBLIC for `Weapon.onFireRequest`'s and `Shop.onRequest`'s stated
-- reason: it is the seam a forged request arrives through, and it must be reachable BY PARAMETER as
-- well as by remote, because `OnServerEvent` can only be raised by a client (task 80).
--
-- IT RETURNS ITS OWN DECISION -- `{ ok = true, size = k }`, `{ ok = false, refused = "<reason>" }`,
-- or nil for a request that was not answered at all -- so a spec gets a per-call answer instead of
-- inferring one from a counter (task 80 round 2's correction).
function Lobby.onPadRequest(player: any, request: any, now: number?): any
```

The payload is `{ pad: number, size: number }` and **nothing else**. In order:

1. not started → `nil`.
2. `stats.padRequests += 1`.
3. **shape**: `request` a table, `pad` an integer in `1..cfg.TRUCK.COUNT`, `size` a member of
   `PADS.SIZES` (`Pads.sizeAllowed`). Otherwise `stats.badRequests += 1`, **nothing is sent back**
   (the client that forged it is not told what shape would have worked), return
   `{ ok = false, refused = "bad-request" }`.
4. **rate**: `Lobby.padRateLimited(userId, now or os.clock())` against
   `PADS.REQUEST_MIN_INTERVAL` → `stats.rateLimited += 1`, return `nil`. A forgery guard, not a game
   rule: a person cannot press a button four times a second.
5. **where he actually is**: `Pads.indexAt(rootOf(player), anchor, cfg)`, read off the character the
   **server** can see. If it is not `request.pad` → `refusedBy["not-on-pad"]`.
6. **who he is**: `pads[n].firstUserId == userId` → else `refusedBy["not-first"]`. BRIEF 1f: only the
   first player on the pad may pick, measured server-side; a pick from anyone else is refused, not
   applied.
7. **when**: `pads[n].state == Pads.SIZING` → else `refusedBy["too-late"]`.
8. apply `Pads.withSize`, write the attributes and the billboard through `Build.setPad`,
   `stats.picks += 1`, return `{ ok = true, size = k }`.

**A forged payload and a legal-but-refused pick are counted apart** — `badRequests` versus
`refusedBy` — which is `Weapon.stats`' own split and its stated reason: *"counting it as a bad
request would hide a mis-wired provider inside the forgery counter"*.

**There is no reply remote.** Every refusal above is a state the client could already see (he is not
on the pad, he is not the first man, the pad has moved on), and the pad's two attributes are the
answer to an accepted pick. One wire in, none out. Stated rather than discovered: a refused pick
therefore shows the player nothing — the dialog simply stays until the server's own state changes
it, and if he was never entitled to it, it was never open.

---

## 9. The published-game seam: `ReserveServerAsync` + `TeleportToPrivateServer`

BRIEF 3 item 4, BRIEF 1a.

```luau
-- src/server/Lobby/init.luau
export type Departure = {
    padIndex: number,
    size: number?,
    members: { any },   -- the Players standing on the pad when the countdown ran out
}

-- THE ONE PLACE A PARTY LEAVES THE LOBBY. Two implementations, one seam, and the owner calls it
-- once per `DEPART` verdict. Returns how many actually went.
function Lobby.depart(departure: Departure): number

-- IMPLEMENTATION 1, TODAY, AND THE ONLY ONE BUILT: this server's own drive, through task 177's
-- existing door, one call per member.
function Lobby.enrolHere(departure: Departure): number   -- loops `world.enrol`

-- IMPLEMENTATION 2, NOT BUILT, and this is the whole of it in words:
--   local code = TeleportService:ReserveServerAsync(game.PlaceId)
--   TeleportService:TeleportToPrivateServer(game.PlaceId, code, departure.members)
-- so four pads would be four simultaneous hunts on four servers.
```

`world.depart: ((Departure) -> number)?` — when nil, `Lobby.enrolHere` is used.
`ForestTestBoot` injects nothing, so the built path is the enrol path, and the teleport task injects
its own function at the same composition root. **Both branches are reachable by parameter**, which is
the stronger form of CLAUDE.md's flag requirement and what `lobby_live.spec` drives (case 14).

**The one sentence:** `TeleportService` has no documented Studio behaviour and in practice none —
there is no live server to reserve and no session to move a player into — so **this repository
cannot test a teleport at all**, and by rule 6 and rule 8 it must not be built in a task that cannot
show it working. `TeleportPartyAsync` and the older `ReserveServer` are both marked **Deprecated**,
which is why the names above are the current pair.

### 9.1 The flag row, written out — and why this task does not add it

The brief asks for the seam to sit behind a flag born OFF. **The row belongs in the task that builds
implementation 2, and here is why, with the evidence:**

* `src/shared/Flags/init.luau` declares **thirteen** rows and `Flags.MAX_FLAGS = 13`.
  `Flags.problems` fails above the cap (`#names > Flags.MAX_FLAGS`), `tests/server/flags.spec.luau`
  fails on `problems`, and that fails the harness. A fourteenth row therefore needs
  `MAX_FLAGS = 14`, and that file's own comment says the bump *"is the Director's call"*.
* CLAUDE.md's feature-flag section requires that *"a flagged path must be reachable by parameter as
  well as by flag, or its two states cannot be tested while the flag sits at one of them"*. A flag
  over a function that **does not exist** has no second state to reach, in Studio or anywhere else.
  A flag whose own rule it cannot satisfy is worse than no flag: it certifies a switch nobody can
  flip.

So today the switch is `world.depart` — injected, defaulted, and driven by a spec in both
directions. When the teleport is built, this is the row, ready to paste:

```luau
PAD_TELEPORT = {
    default = false,
    owner = "ServerScriptService.Lobby",
    born = "<date> task <n>",
    expires = "<+21 days>",
    why = "A truck pad's party leaves for ITS OWN reserved server (TeleportService:"
        .. "ReserveServerAsync + TeleportToPrivateServer), so four pads are four hunts. OFF is task "
        .. "182's game: the party is enrolled in this server's one drive. IT CANNOT BE TESTED IN "
        .. "STUDIO -- there is no server to reserve -- so it needs a published place and Karen's eyes.",
} :: FlagRow,
```

and it arrives with `Flags.MAX_FLAGS = 14` or with one of the three lit rows queued for retirement in
`TASKS.md` 82b retired first. Section 18 puts that choice to the Director; **nothing in this task
waits on it.**

---

## 10. The screen

`Hud.Objective` stays *"THE ONE WRITER of the objective LINE and of the WAYPOINT chevron"*
(`src/client/Hud/Objective.luau`). The pads are rows in its pure table and one more optional field.

### 10.1 Two rows change, nothing else in the table

```luau
-- Objective.CONFIG.TEXT
-- TASK 182: FOUR PADS, NOT ONE CIRCLE. 27 characters, which `hud_clarity.spec` measures with the
-- engine's own `TextFits` at 400 x 800 -- the research note's longer sentence ("step on a truck pad
-- to start a hunt", 35) is over the 32 this table's own comment bounds.
Lobby = "step on a truck pad to hunt",
LobbyLeaving = "leaving for the hunt in %d",   -- UNCHANGED, and so is the attribute behind it
```

`WORD_TRUCK = "TRUCK"` is unchanged: the chevron says which *thing* to walk to, and the billboard on
the pad says which *truck* it is.

### 10.2 The chevron points at the nearest pad

BRIEF 1j. `Objective.LobbyNow` gains one optional field, and `targetFor` reuses the nearest-of-a-set
rule it already has rather than inventing a second one.

```luau
export type LobbyNow = {
    spot: Vector3?,        -- pad 1. STILL THE GATE: nil = "this world has no lobby"
    secondsLeft: number?,  -- unchanged
    pads: { Vector3 }?,    -- task 182, in pad order. nil or empty = answer exactly as before
}
```

In `Objective.targetFor`, inside the existing teamless-and-`Waiting` branch:

* `pads` with at least one entry → the **nearest** one, through `Objective.nearestStand(flat, me)`
  (its arithmetic is "the nearest of a set of flat points"; its comment gains the sentence that the
  stands are one such set and the pads are another). The point keeps the pad's own y, as the truck
  spot's always has.
* `pads` nil or empty, **or `me` nil** → `lobby.spot`, which is task 177's answer bit for bit. Absent
  is not "nowhere" — `MapUi.pointsFor`'s rule.

**Three drawers, one target, no new plumbing.** `MapUi.setTarget`, `Hud.markerFor` and the chevron
are all written from the one `target` resolved in `Hud.renderObjective`, so the minimap, the compass
word and the chevron cannot disagree about which pad — the failure task 153 round 2 paid for
(*"a marker that moved without its label told a beater the drive was south"*). **`MapUi` changes
nothing at all**, and the minimap still hides in the lobby for the reason it already does (outside
the stated bounds, `docs/design/lobby.md` 10.5).

**One honest consequence, stated rather than discovered.** `Objective.CONFIG.ARRIVED_IN_STUDS` is 12
and is deliberately tied to the hunter's stand radius; the pad's half-extents are 4.5 and 6. So the
chevron now goes out while the player is up to ~7 studs **short** of the pad, where the circle's
radius of 8 used to mean he was already inside it. Nothing goes blank: the objective LINE persists
until he is actually on a pad (its gate is `lobby.spot ~= nil` and no team, not arrival), and at 7
studs the pad and its lit billboard fill his screen. The fix, if Karen minds, is a per-target
arrival band (`Target.arriveIn`), which is one optional argument to `Objective.arrived` and is
**queued, not built** (section 18, Director item 3).

### 10.3 The dialog: `ShopPanel`'s shape

BRIEF 1g. `src/client/Hud/PadPanel.luau`, drawing into a frame `Hud.build` creates with the rest of
the screen — *one ScreenGui, built once, so a visibility audit has one place to look*.

* **It owns its own `Visible`**, the `MapUi`/`ShopPanel` arrangement, and the rule is one line:
  `Visible == (ask ~= nil)`, where `ask` is **told** to it by the Hud (`Rail.setWeapon`'s rule:
  *"`hasWeapon` is TOLD to this module by the Hud, never read here"*), from
  `Lobby.padAsking(LocalPlayer.UserId)`. So the dialog's visibility is a **server-measured fact**,
  and this panel learns nothing about worlds, rectangles or who is first.
* **Edge-triggered**: `PadPanel.setAsk(index?)` returns early when the value has not changed, which
  is `Lobby`'s own discipline for an attribute that used to be written fifty times per walk-in.
* **It draws what arrived and decides nothing.** The four rows are `CONFIG.PADS.SIZES`, read from the
  shared table both sides read.
* **`GuiButton.Activated`** — one event for a click **and** a tap, which is why this panel needs no
  touch branch at all (`Hud.Rail`'s own citation) — and `BUTTON_PX` 48, over Roblox's own 44 px
  minimum.
* **The mouse and the trigger**, through the two doors that already exist and reason-keyed with the
  tag `"padsize"`: `Cursor.requestFree` / `Input.requestHold` on open, `release` / `releaseHold` on
  close (`ShopPanel.setOpen`'s shape, tag `"shop"`).
* **No close button, and that is deliberate.** `ShopPanel` needs one because walking away is the only
  other way out and `Escape` belongs to the Roblox menu. Here there are five exits: four buttons,
  and stepping off the pad. **`1 / 1  alone` is the "leave me alone" button**, and it is also what
  the timeout does, so the dialog can never be a dead end or a gate you must pass to play.

```luau
function PadPanel.start(frame: Frame, collaborators: any)
function PadPanel.setAsk(index: number?)          -- TOLD, edge-triggered. The one visibility rule
function PadPanel.press(size: number): boolean    -- PUBLIC and named: a spec cannot fire `Activated`
function PadPanel.isOpen(): boolean
function PadPanel.padIndex(): number?
function PadPanel.rowText(): { string }           -- what is on screen, `ShopPanel.rowText`'s seam
function PadPanel.stats()
```

`PadPanel.press` is public for `Rail.press`'s and `ShopPanel.press`'s stated reason: a spec cannot
fire `GuiButton.Activated` and the harness cannot synthesise a tap, so this is the seam that makes
the buttons testable at all — and what it proves is the **action**, not the touch. **That limit is
reported, not papered over** (section 15.3).

### 10.4 The Hud's two new lines

Both inside `Hud.renderObjective`, which is already *"THE ONE EVALUATION of 'what must I do, and
where', and the one call to each drawer"*:

```luau
local lobby = if lobbyData then {
    spot = lobbyData.spotPosition(),
    secondsLeft = lobbyData.secondsLeft(
        Players.LocalPlayer:GetAttribute(lobbyData.LEAVE_AT_ATTRIBUTE), Workspace:GetServerTimeNow()),
    pads = lobbyData.padPositions(),          -- task 182
} else nil
PadPanel.setAsk(if lobbyData then lobbyData.padAsking(Players.LocalPlayer.UserId) else nil)
```

Cost per frame: four memoised part lookups and four `.Position` reads for `padPositions`, and four
cached attribute reads for `padAsking`. Both are the same order as `ShopPanel.setNear`'s one
subtraction, which this function already does.

---

## 11. The public interface, in full

### 11.1 `ReplicatedStorage.Lobby` (shared data, no run-time writer)

```luau
Lobby.CONFIG                                   -- + CONFIG.PADS (section 5); SPOT removed
Lobby.FOLDER_NAME / SPOT_NAME / SPAWN_NAME / TEMPLATES_NAME / COUNTER_NAME / KEEPER_NAME / PROMPT_NAME
Lobby.LEAVE_AT_ATTRIBUTE: string               -- unchanged
Lobby.PAD_STATE_ATTRIBUTE: string              -- new
Lobby.PAD_FIRST_ATTRIBUTE: string              -- new
Lobby.REMOTES_NAME / PAD_REQUEST_REMOTE: string -- new
function Lobby.remotes(): { PadRequest: RemoteEvent }        -- new, memoised
function Lobby.anchorFor(world: string?)                     -- unchanged
function Lobby.spotPart(): BasePart?                         -- unchanged: PAD 1
function Lobby.spotPosition(): Vector3?                      -- unchanged
function Lobby.padPart(index: number): BasePart?             -- new, memoised
function Lobby.padPositions(): { Vector3 }                   -- new
function Lobby.padStateOf(index: number): (string?, number?) -- new
function Lobby.padAsking(userId: number): number?            -- new
function Lobby.counterPart / counterPosition / shopPrompt    -- unchanged
function Lobby.secondsLeft(leaveAt: number?, serverNow: number): number?   -- unchanged
```

### 11.2 `ServerScriptService.Lobby` (the owner)

```luau
function Lobby.start(world): boolean       -- + one optional field: `remotes`, `depart`
function Lobby.stop()                      -- + clears every DHPad* attribute and the rate bucket
function Lobby.step(now: number, players: { any }?)   -- unchanged signature
function Lobby.onPhase(phase: string?)                -- unchanged
function Lobby.onPadRequest(player, request, now: number?): any   -- new: the one inbound handler
function Lobby.padRateLimited(userId: number, now: number): boolean -- new, public like `Shop.rateLimited`
function Lobby.depart(departure: Departure): number   -- new: the seam (section 9)
function Lobby.padOf(index: number): Pad?             -- new: a reader, for the specs and a console probe
function Lobby.forget(userId: number)                 -- + the rate bucket
function Lobby.stats()
Lobby.Join, Lobby.Pads, Lobby.Field, Lobby.Build, Lobby.Data   -- + Pads
```

`world`, the two new optional fields (everything else unchanged):

| Field | Type | Bound by `ForestTestBoot` to | Why injected |
|---|---|---|---|
| `remotes` | `{ PadRequest: RemoteEvent }?` | `Lobby.Data.remotes()` | so a spec drives `onPadRequest` by parameter with no remote at all, and a `Connect` that answers nil cannot take the boot down (`Shop.start`'s measured round-1 fault) |
| `depart` | `((Departure) -> number)?` | **nothing** | section 9: the teleport's seam, defaulting to `Lobby.enrolHere` |

`Lobby.stats()` gains: `padRequests`, `picks`, `pickTimeouts`, `badRequests`, `rateLimited`,
`refusedBy` (a table, cloned by `stats()` as `Shop.stats` does), `parties`, `departures`,
`padWrites`, `padCancels`. `cancels` keeps its name and now counts **pad** cancels.

### 11.3 `Lobby.Build` — the delta

```luau
function Build.pads(container: Instance, anchor: Vector3, cfg): { BasePart }    -- new
function Build.padPart(index: number): BasePart?                                -- new, dropped on rebuild
function Build.setPad(index, state: string, firstUserId: number?, count: number, size: number?): boolean
function Build.padLabel(index: number): (string, string)   -- what is drawn, for a spec
-- `Build.spot` is archived with the circle. `Build.build`'s return is UNCHANGED
-- `(folder, marker, spawn, parts)`, with `marker` now PAD 1's part.
```

### 11.4 `Hud` — the delta

`Hud.build` creates one more frame (`PadPanel`), `Hud.PadPanel` is re-exported beside `Hud.Shop`,
`Hud.renderObjective` gains the two lines in 10.4, and `Objective.LobbyNow` gains `pads`.
`Objective.targetFor`'s signature does not change.

### 11.5 `Match` — the delta

**None.** No file under `src/server/Match/` changes, and a grep for `Lobby` under `src/server/Match/`
must still answer nothing. That is also what keeps this task off the two-player gate (section 15.5).

---

## 12. What it reads from and writes to other systems

| Thing | Owner | This system's relationship |
|---|---|---|
| every part and GUI in `Workspace.Lobby` | **`Lobby.Build`** | writes (the only writer) |
| the `DHPadState` / `DHPadFirst` attributes | **`Lobby.Build`**, decided by `Lobby` | writes |
| the `DHLobbyLeaveAt` attribute on a `Player` | **`Lobby`** | writes (unchanged, task 177) |
| `Player.RespawnLocation` | **`Lobby`** | writes (unchanged) |
| the roster | `Match` | **calls** `world.enrol` / `world.dismissAll`; **reads** `isParticipant`, `isHeld`. Writes nothing |
| where a character stands | `Match.Body` | **asks**, through the injected `place` |
| a team, clothes, a tool | `Match.Body`, `Weapon`, `Weapon.Horn` | **never touches** |
| the terrain inside `CONFIG.FIELD` | `Lobby.Field` | unchanged |
| where the ground is | `ForestTest` (`Data.groundAt`) | reads, injected |
| the objective line, the chevron, the compass word, the map mark | `Hud.Objective` / `Hud.Compass` / `Hud.MapUi` | **provides data** (pad positions, through `ReplicatedStorage.Lobby`). Writes nothing drawn |
| the `PadPanel` frame's contents and `Visible` | `Hud.PadPanel` | the server provides two attributes; the panel draws |
| `Cursor` / `Input` holds | `Camera.Cursor` / `Weapon.Input` | **requests**, reason-keyed `"padsize"` |
| the shop, the shopkeeper, his prompt | `Shop`, `Lobby.Build.shopkeeper` | **untouched** |

---

## 13. External sources

Named, linked, with licence and maintenance status. **None of these links was opened in this
session** — the Architect has Read, Grep and Glob only; each is either an API this repo already calls
or one the research note read on 2026-10-14, and each is proved by the harness run rather than by the
link.

### 13.1 Valve Developer Community — `trigger_multiple` — **ADOPTED (as arithmetic, widened to a rectangle)**
<https://developer.valvesoftware.com/wiki/Trigger_multiple>
*Licence:* CC BY-SA (the VDC wiki's own licence). *Maintenance:* community wiki, actively edited; the
entity ships in every Source game.
**Well:** a volume whose whole value is knowing who is **inside** it — presence, not contact.
Half-Life's level flow is built on it, and "standing somewhere IS the request" is exactly Karen's
*"rectangle where people stand"*.
**Badly:** it is a brush entity in a compiled map; there is no such thing in Roblox, and the naive
translation — `BasePart.Touched`
(<https://create.roblox.com/docs/reference/engine/classes/BasePart#Touched>, CC BY 4.0, current) — is
a physics event that fires on CONTACT, so a man standing still generates nothing after the first
touch and `TouchEnded` cannot answer *"has he left"*, which is the one question a pad that cancels on
stepping off must ask every tick.
**Adopted**, and it is already this repo's idiom: `Join.within` for the circle,
`ForestTest.withinStand` for a stand. What changes here is the **shape and not the mechanism** —
two `math.abs` comparisons instead of one squared distance (`Join.withinRect`).

### 13.2 "Free ADVANCED lobby model for multiplayer games" (DevForum) — **PATTERN ADOPTED WHOLE, NO CODE TAKEN**
<https://devforum.roblox.com/t/free-advanced-lobby-model-for-multiplayer-games/2272494>
*Licence:* **none stated** (a free community resource). *Maintenance:* posted 2023-04-04, bug fixes
through 2024-06, with a commenter asking whether the distributed model ever received them.
**Well, and this is the find:** its lobby is a pad with a configurable **maximum**, a live
**occupancy**, a **countdown owned by the pad** (started when the first player steps on) and a
`BillboardGui` over it drawing both. That is Karen's picture minus the dialog — the shape she asked
for is the shape the community converged on.
**Badly:** no size choice at all (the developer sets the maximum, not the first player), its own
documentation is vague about what the count displays, and the unstated licence means **no code may
be copied**.
**Adopted:** the four properties above — max, live occupancy, a pad-owned countdown, a billboard
saying both (sections 6.1, 6.2). **Changed:** the max is the first player's pick, and the countdown
is this repo's existing `COUNTDOWN_SECONDS` rather than a new number.

### 13.3 `PartyModule` (DevForum) — **REJECTED, vocabulary and posture borrowed**
<https://devforum.roblox.com/t/open-source-party-module/4265635>
*Licence:* explicitly *"free to use … in any project (personal or commercial). Credit is appreciated
but not required."* *Maintenance:* posted 2026-01-17, author active on the thread 2026-09-26, no
module update since.
**Well:** exactly our vocabulary — `CreateParty`, `AddPlayer`, `RemovePlayer`,
`ChangePartyLeader`, `GetPartyFromPlayer` — and server-side only, which is the right side.
**Badly:** *"does not replicate to clients automatically"*, *"does not auto-delete empty parties"*,
no GUI, no example place — and **no concept of a PLACE in the world**, which is the entire thing
Karen asked for.
**Rejected**, because our party is *who is standing on this rectangle right now*: a derived fact,
re-measured at 10 Hz, that cannot drift out of step with the world. A party object with its own
lifetime would be a second answer to "who is in party 2". **Borrowed:** the vocabulary (a pad has a
party, a party has a size and a first player) and the "server-side only, no client authority"
posture.

### 13.4 `Party Service v2.1` (DevForum) — **REJECTED**
<https://devforum.roblox.com/t/party-service-v21-create-a-party-system-more-easily/1816870>
*Licence:* **unstated** (says "open-source", names a GitHub repo, quotes no licence file).
*Maintenance:* v2.1, 2022-10-17 — **dead for four years**; it also phones home over `HttpService`
for update warnings.
**Well:** invite codes, a configurable maximum, cross-place data, and a documented Studio story
(`SetPartyServerEmulator`).
**Badly:** the unstated licence alone disqualifies it from a public repo; its max-50 ceiling is a
`TeleportService` constraint we are not paying; `SetAsync` per party is a DataStore write a lobby
should not carry; and `HttpService` traffic out of a lobby is not something this game does anywhere.

### 13.5 Roblox Creator Docs — `TeleportService` — **DESIGNED, NOT BUILT**
<https://create.roblox.com/docs/reference/engine/classes/TeleportService>
*Licence:* CC BY 4.0. *Maintenance:* first-party, current.
**Well:** `ReserveServerAsync` + `TeleportToPrivateServer` is the real pattern, and it is what makes
four pads four hunts.
**Badly:** `TeleportPartyAsync` and `ReserveServer` are marked **Deprecated**, so a design naming
them would be wrong on the day it was written; and the docs state no Studio behaviour, which in
practice means none. **A teleport is a thing this project cannot test at all.**
**So:** the seam is named and left unbuilt (section 9).

### 13.6 Roblox Creator Docs — `BillboardGui` — **ADOPTED**
<https://create.roblox.com/docs/reference/engine/classes/BillboardGui>
*Licence:* CC BY 4.0. *Maintenance:* first-party, current.
**Well:** it always faces the camera, needs no asset and no upload, `MaxDistance` makes "readable
from the porch, gone across the field" one property, and it is **not script-like**, so the harness's
"no script outside Rojo-managed paths" check is unaffected — the reasoning `Build`'s own header
already records for `SurfaceGui`.
**Badly:** it needs an **adornee in the world**, which is precisely why `Hud.Objective` refuses one
for the chevron (*"a billboard needs an `Adornee`, so the Hud would have to create a part in the
world — a second writer of the world, for a mark that is pure UI"*). That objection does not apply
here and the contrast is the point: the pad **is** a part the server already owns, so the billboard
hangs on its own owner's instance and the Hud is not involved at all.
**Adopted** for the `n / size` and `TRUCK n` over each pad.

### 13.7 This repository — `Shop.onRequest` and `Hud.ShopPanel` — **BORROWED WHOLE**
`src/server/Shop/init.luau` (`Shop.onRequest`, `Shop.rateLimited`, `Shop.atCounter`, `stats`) ·
`src/client/Hud/ShopPanel.luau` (`setNear`, `setOpen`, `press`, `rowText`, `LOOK`)
*Licence:* this project's own. *Maintenance:* live, tasks 178 and 181.
**Well:** it is the only inbound door in this repository that has been reviewed as one: public
handler, server-measured facts, a per-player rate bucket, forgeries counted apart from refusals, and
a panel that owns its `Visible`, draws what arrived and decides nothing.
**Badly:** `Shop` replies on a second remote (`ShopState`) because a balance is **per player**; a
pad's state is **public**, so this design drops the reply and mirrors the state on the pad's own part
instead (section 8.1). That is the one place the borrowing stops.

### 13.8 This repository — `Build.faceKeeper` and `ForestTest.Markers.RING` — **BORROWED WHOLE**
`src/server/Lobby/Build.luau` (`Build.faceKeeper`, `Build.keeperPosition`) ·
`src/server/ForestTest/Markers.luau` (`Markers.RING`)
**Well:** `faceKeeper` is the exact arrangement this task needs twice over — *the owner decides, the
builder writes, and the write is counted so an edge-triggered claim is checkable*. `RING` is where
the pad's rim numbers (0.5 thick, 0.12 high, 0.08 of lift, transparency 0.45, hunting orange) are
already justified and **already accepted on screen by Karen**.
**Badly:** `Markers.ring` reads the ground per segment, which a pad on a flat shelf does not need.
**Adopted:** the pad's rim is the ring's own numbers, so the lobby's palette does not change.

---

## 14. Numeric targets

| What | Target | How it is checked |
|---|---|---|
| pads | **4**, one per truck bay | `lobby.spec`: `Pads.centreFor` for 1…`TRUCK.COUNT`; `Build` makes four named parts |
| pad rectangle | **9 x 12 studs**, 0.7 thick | `lobby.spec` reads `CONFIG.PADS.SIZE` |
| pad centre | bay x; `TRUCK.OFFSET.Z + 12 + 6` = z +36 | `lobby.spec`: `Pads.centreFor` against the config expression, not a literal |
| clearance: parts lodge east wall | **≥ 0.5 studs** | `lobby.spec`: pad 1 west face ≥ `LODGE.OFFSET.X + LODGE.SIZE.X/2 + LOG_DIAMETER/2` |
| clearance: both tailgates | **≥ 2.75 studs** | `lobby.spec`: `PAD_BEHIND_STUDS >= TRUCK.SIZE.Z/2 + 3` |
| every pad inside `FIELD` | all four corners | `lobby.spec`, the rule `Field`'s regions are already held to |
| trees on a pad | **0** | `lobby.spec`: build with a fake `Trees` template and assert no clone's position is inside any pad |
| pad top above every slab | `shelfY + ROAD.THICK_STUDS + 0.08`, bottom **below** the shelf | `lobby.spec`, arithmetic over `SIZE.Y` and `LIFT_STUDS` |
| gap between pads | **8 studs** | `lobby.spec`: the four rectangles are disjoint |
| presence scan | **10 Hz**, unchanged, **no new clock** | `lobby_live.spec` counts `stats.scans` over a known span |
| instance writes per scan, nothing moving | **0** | `lobby_live.spec`: `stats.padWrites` does not climb with `stats.scans` |
| attribute + billboard writes per walk-on | **≤ 2** (`sizing`, then `filling`) | `lobby_live.spec` reads `stats.padWrites` |
| pick timeout | **8 s** | `lobby.spec` / `lobby_live.spec` at 7.9 / 8.0 |
| fill timeout | **45 s** | `lobby.spec` case table |
| countdown | **5 s**, `CONFIG.COUNTDOWN_SECONDS`, unchanged | `lobby.spec`: the pads read that field and declare none of their own |
| pad → drive, with no pick and no client | **≤ 15 s** (8 + 5 + ≤ 2 scans of slack) | `lobby.spec` asserts `PICK_TIMEOUT + COUNTDOWN + 2/SCAN_HZ < 20`; `lobby_live.spec` drives it |
| door rate limit | **4 requests/s/player** | `lobby_live.spec`: two calls inside `REQUEST_MIN_INTERVAL` → one refusal |
| enrolments per departing party | **exactly one per member, once** | `lobby_live.spec` counts the fake `enrol` |
| pad part budget | **20 parts** (4 x (1 deck + 4 rim)), against the circle's 23 removed → **net −3** | `Build.build` returns the count; `lobby.spec` asserts `<= MAX_PARTS` (1200), unchanged |
| dialog | fits **400 x 800**; every button **≥ 48 px** | `pad_panel.spec`, with the engine's own `TextFits` — the `hud_clarity.spec` idiom |
| objective row | **≤ 32 characters** | `hud_clarity.spec`, `TextFits` at 400 x 800 |
| DEV harness | **the same `m` checks, every one with the same answer** | section 15.5 — the claim to verify by running the gate, not to assert here |
| flag rows | **13**, `MAX_FLAGS` 13, **unchanged** | `flags.spec` (`Flags.problems` is empty) |

---

## 15. How it is tested

### 15.1 Server specs — pure, no world, no character (`tests/server/lobby.spec.luau`, scope `lobby`)

The existing cases 2 and 3 (`Join.within`, `Join.decide`) are replaced; everything else in the file
stands.

1. **`Pads.centreFor`**, and with it every clearance in section 4.1 — each asserted against the
   config expression and never a literal: x per bay; z = `TRUCK.OFFSET.Z + PAD_BEHIND_STUDS +
   SIZE.Z/2`; pad 1's west face clear of the parts lodge's east wall and its porch deck; the near
   edge clear of `TRUCK.SIZE.Z/2 + 3`; all four corners of all four pads inside `FIELD`; the four
   rectangles disjoint; the top above `ROAD.THICK_STUDS` and the bottom below the shelf.
2. **`Join.withinRect`**: inside; outside in x only; outside in z only; **exactly on** each of the
   four edges (`<=`, the comparison `within` made); 50 studs above the centre is still inside (flat).
3. **`Pads.indexAt`**: each centre → its own index; a point in the 8-stud gap → nil; a point 200
   studs away → nil; **nil position → nil** (a man with no character is standing nowhere).
4. **`Pads.step`, as a table of cases — every row of section 6.2**, each asserting the new state, the
   new deadline and the verdict. Including, by name: re-election starts a **fresh** pick clock; a
   join during `countdown` does **not** move the deadline; the last man off in `countdown` cancels
   and yields no `DEPART`; `filling` with the pad emptied drops the size; one transition per call.
5. **`Pads.withSize`**: accepted in `sizing`; refused in `empty`, `filling`, `countdown`, `leaving`;
   the refusal returns the pad unchanged.
6. **`Pads.sizeAllowed`**: every row of `SIZES` true; `3`, `0`, `-1`, `9`, `1.5`, `"8"`, `nil`,
   `0/0` false.
7. **`Pads.labelFor`**: `0 / -` and `TRUCK 1` in `empty`; `1 / -` in `sizing`; `3 / 4` in `filling`;
   and `Pads.defaultSize(cfg) == 1` with
   `PICK_TIMEOUT_SECONDS + COUNTDOWN_SECONDS + 2 / SCAN_HZ < 20` — the arithmetic
   section 15.4 rests on, asserted rather than believed.
8. **`Build.build` into a spec-owned Folder**: four pad parts named `PADS.PART_NAMES`, pad 1 named
   `Lobby.SPOT_NAME`; each `Anchored`, `CanQuery = false`, `CanTouch = false`,
   `CanCollide = false`; four distinct colours; each carrying one `BillboardGui` with two
   `TextLabel`s; **no `Spot` folder, no ring segment and no `STAND HERE TO HUNT` sign anywhere**;
   **no `Script`, `LocalScript` or `ModuleScript` anywhere in the tree**; part count
   `<= CONFIG.MAX_PARTS`; with a fake `Trees` template, **no tree inside any pad**; the spec destroys
   its folder.
9. **`Build.setPad` / `Build.padLabel`**: the two lines and the two attributes land on the pad's own
   part; a second call with the same values returns false and writes nothing (the edge claim).

### 15.2 Server specs — the owner against fakes (`tests/server/lobby_live.spec.luau`, scope `lobby`)

Fake occupants are `{ UserId, Character }` with a real root part in a spec-owned model, and the
`enrol` / `depart` / `inDrive` / `isHeld` / `place` seams are recording fakes. Cases 10-16 of the
existing file stand; these are added:

10. one occupant walks onto pad 2 → `DHPadState` is `sizing`, `DHPadFirst` is his userId, the
    billboard reads `1 / -`, and **`enrol` was not called**.
11. the door: `onPadRequest(first, { pad = 2, size = 4 })` → `{ ok = true, size = 4 }`, state
    `filling`, billboard `1 / 4`; a second call inside `REQUEST_MIN_INTERVAL` → nil and
    `stats.rateLimited == 1`.
12. **forged payloads** — `nil`, `"x"`, `{}`, `{ pad = 9, size = 4 }`, `{ pad = 2, size = 3 }`,
    `{ pad = 2, size = "4" }`, `{ pad = 2.5, size = 4 }` — each refused `bad-request`,
    `stats.badRequests == 7`, `refusedBy` **empty**, the pad unchanged.
13. a pick from a **non-first** occupant → refused `not-first`, counted in `refusedBy` and **not** in
    `badRequests`, size still nil; and a pick naming a pad he is **not standing on** → refused
    `not-on-pad`, measured from the character and not from the payload.
14. **the pick timeout and the seam**: nobody picks; `now += PICK_TIMEOUT` → size 1 and
    `stats.pickTimeouts == 1`; `now += COUNTDOWN` → with `depart` injected it is called **once** with
    that one member; with `depart` **not** injected, `enrol` is called once for that member. Both
    branches, which is what section 9 claims.
15. **the party reaching the drive**: four occupants on pad 3 with size 4 → `countdown` on the scan
    it fills, `DHLobbyLeaveAt` set on **all four**, then **four** `enrol` calls, one per member, and
    **no fifth call on the next scan** (the idempotence `Match.enrol` also guards).
16. the first player steps off in `sizing` with two others on → `DHPadFirst` becomes the earliest
    remaining and the deadline is refreshed; then all off → `empty` and **every `DHPad*` attribute
    nil**.
17. the last man steps off in `countdown` → `empty`, every `DHLobbyLeaveAt` cleared, **`enrol` not
    called**.
18. **a pad fills while the drive is `Running`** (fake `inDrive` true for others): the party is still
    enrolled — BRIEF 1b's mid-drive join, asserted rather than assumed.
19. **the edge claim**: 50 scans with nobody moving → `stats.padWrites` unchanged, `stats.scans` 50.
20. `Lobby.stop()` → no `DHPad*` attribute survives, the rate bucket and the pads table are empty;
    `Lobby.forget(userId)` clears his bucket entry.
21. `Lobby.start` with `remotes` whose `Connect` answers nil → still true, nothing thrown (the
    measured `Shop.start` round-1 fault, not repeated here).

### 15.3 Client specs (one player)

**`tests/client/pad_panel.spec.luau`** (new file, scopes `hud` **and** `lobby`):

22. `setAsk(2)` → the frame is `Visible`, the title is `PANEL.TITLE`, and `rowText()` is the four
    `SIZES` labels in order; `setAsk(nil)` → not `Visible`; `setAsk(2)` twice → one open in `stats`
    (edge-triggered).
23. `press(4)` → exactly one `FireServer` on the fake remote, with `{ pad = 2, size = 4 }` and no
    other field; `press(3)` (not in `SIZES`) → false and **nothing fired**; `press` with no ask →
    false.
24. the panel fits **400 x 800** and every button is **≥ `BUTTON_PX`** tall, by the engine's own
    `TextFits` and `AbsoluteSize`.
25. `Cursor.requestFree("padsize")` / `Input.requestHold("padsize")` on open and the matching
    releases on close, against fakes that record the reason tag.

**`tests/client/hud_clarity.spec.luau`** (+ cases, scope `hud`): `Objective.text(nil-team,
"Waiting", nil, nil)` is still `""` — **the DEV answer, unchanged**; with `{ spot = v }` it is the
new line, and it **fits at 400 x 800**; `targetFor` with four `pads` and `me` nearest pad 3 returns
pad 3's point with `word = "TRUCK"`, `kind = "truck"`; with `pads = nil` it returns `spot` (task
177's answer, bit for bit); with `me = nil` it returns `spot`; nil in every other phase and for a
player with a team.

**No change** to `tests/client/Role.luau`, `match_client.spec`, `outfit_client.spec`,
`shop_panel.spec`, `map_ui.spec`.

### 15.4 Harness input, and the one path that runs unattended

* **No input scenario.** The pad rule is positional and `tests/client/input_scenarios.txt` cannot
  express "walk 9 studs" — keys, mouse buttons, mouse moves and gaps only
  (`tools/studio_mcp.py`'s docstring). The rule is proved by the pure spec with hand-written
  positions and by the live spec with fake occupants, which is the player's path through the same
  arithmetic. **The dialog's touch is not proved**: a spec cannot fire `GuiButton.Activated` and the
  harness cannot synthesise a tap, so `PadPanel.press` proves the **action** and the limit is
  reported (`Rail.press`'s stated limit).
* **The Director's `smoke.sh` needs no change from this repo, and the pick timeout is why.** It
  pivots player 1 onto `TruckSpot` — which is **pad 1** (BRIEF 1i) — and requires the drive to have
  taken him. A snippet that `require`s the server's `Lobby` over StudioMCP gets a **sandboxed copy
  with empty state** (measured, task 122), so it can neither call `onPadRequest` nor press a button.
  With the default pick: `PICK_TIMEOUT 8 + COUNTDOWN 5 = 13 s`, plus at most two scans of slack
  (0.2 s), so **the whole path completes unattended in ≤ 13.2 s**.
  **But the window must be at least 15 s, and `ESCALATE.md`'s own proposal says 8.** The 2026-10-13
  task-177 entry asks the Director to change his check to *"put him in the circle — wait 8 s — and
  THEN require the gun in hand"*. Eight seconds is less than thirteen. If that version was
  implemented, `smoke.sh` will report `FAIL: gun not in hand` **and the pads will be working as
  designed**. The fix is one number in the Director's own file (section 18, Director item 1); step 1
  of that check (`Workspace.Lobby` exists and holds a part named `TruckSpot`) stays true.

### 15.5 Screenshots (rule 5) — two are owed, and the Builder must be honest about which it took

The brief owes Karen two pictures: **the four trucks with their pads** (from the porch, so the four
colours and the four billboards are all in frame) and **the size dialog**.

The lobby is built at **run time** in the **Forest Test** place (`Lobby.ANCHORS` has one row), so
both need that place open in Studio **in Play**.
`python tools/studio_mcp.py capture <name> [camera] [look-at]` has **no place-id check** (unlike
`test`, which refuses anything but DEV), so it photographs whichever Studio is connected. If the
Forest Test session is not the one that is open, **the pads cannot be screenshotted by the Builder**,
and the request must say so under "what could not be verified" with a `## Needs Karen` asking her to
look. **Do not report a screenshot that was not taken and inspected.** Three things to look at in
the first frame, because each is a defect this design predicted and bounded: the pad's west edge
against the lodge (section 4.1), the pad's surface against the road slab and the bare terrain north
of it (section 4), and whether a tree stands near pad 4 (if one does, `TREELINE.RADIUS_STUDS` 100 →
106 is the one-row fix and stays inside the field's half-span of 110).

### 15.6 The gate, and the DEV place

* **DEV sees no pad.** `ForestTestBoot` returns early when `Map.EXPECTED_WORLD ~= "forest-test"`,
  `Lobby.anchorFor("map:v1")` is nil, the `LOBBY` flag is `false`, and `Workspace` is not Rojo-owned
  so no run-time part can reach the Edit-mode comparison. **`ReplicatedStorage.Lobby.Remotes` is
  new in the synced tree** and the harness compares it like any `.model.json` — one `RemoteEvent`,
  no properties, no attributes, nothing script-like inside (CLAUDE.md's file-types table).
* **`tools/studio_mcp.py` gains one row in the same commit**, or `selftest` fails in CI (*"`selftest`
  fails if a spec file belongs to no scope"*):

  ```python
  # SCOPE_SPECS: the new client spec, in BOTH tuples -- the dual membership `zz_horn`, `boar_hit`
  # and `shoot_boar` already use. `src/client/Hud/` resolves to `hud` and `src/shared/Lobby/` to
  # `lobby`, and either side can break this panel.
  "hud":   ( ... , "tests/client/pad_panel.spec.luau"),
  "lobby": ( ... , "tests/client/pad_panel.spec.luau"),
  ```

  `BLAST_RADIUS` needs **nothing**: `src/server/Lobby/`, `src/shared/Lobby/` and `src/client/Hud/`
  are all already mapped.
* **THE TWO-PLAYER RUN IS NOT IN THIS TASK'S GATE, and that is checkable rather than hopeful.**
  `TWO_PLAYER_PATHS` in `tools/agents.py` is `src/server/Match/`,
  `src/server/MatchBoot.server.luau`, `src/client/Match/`, `src/client/MatchBoot.client.luau`,
  `src/shared/Drive/`, `tests/client/Role.luau` and their specs. **This design touches none of
  them** (section 11.5: no file under `src/server/Match/` changes), so the **one-player line is all
  that is required, for a review round and for the PR to `main`** — Director decision 2026-10-03.
  A review round may run on `scope=auto:lobby,hud`, and the merge needs the full `test`.

---

## 16. Build order for the Builder

One task, but the order matters because each step is provable before the next — and step 5 is a
stopping point that is a complete, playable game.

1. `src/shared/Lobby/init.luau`: `CONFIG.PADS`, the two attribute names, the remote names, and the
   four readers (`padPart`, `padPositions`, `padStateOf`, `padAsking`, `remotes`). `SPOT` out, with
   the `backups/` note (rule 7).
2. `src/server/Lobby/Pads.luau` and `Join.withinRect` (pure), plus `lobby.spec` cases 1-7. **Nothing
   on screen yet and the whole rule is proved.**
3. `src/shared/Lobby/Remotes.model.json`.
4. `src/server/Lobby/Build.luau`: `Build.pads`, `setPad`, `padPart`, `padLabel`; `Build.spot` out.
   `lobby.spec` cases 8-9. **Look at it** (15.5) before going further.
5. `src/server/Lobby/init.luau`: the pads table, the scan, `depart`/`enrolHere`, `DHLobbyLeaveAt` on
   the countdown edge. `lobby_live.spec` 10, 14-20. **At this point the game works end to end with
   the default size of 1, which is task 177's behaviour plus four pads.**
6. The door: `onPadRequest`, the rate bucket, `ForestTestBoot`'s one new `remotes` field.
   `lobby_live.spec` 11-13, 21.
7. `src/client/Hud/PadPanel.luau`, the frame in `Hud.build`, the two lines in `Hud.renderObjective`,
   and `pad_panel.spec` 22-25.
8. The screen's words: `Objective.CONFIG.TEXT.Lobby`, `LobbyNow.pads`, `targetFor`'s nearest-pad
   clause, `hud_clarity.spec`'s cases.
9. `tools/studio_mcp.py`'s one scope row, `GAME_DESIGN.md`'s owner row (3.1), the `lobby.md`
   replacements (section 2 — **the Architect's edit, not the Builder's**: queue it in `TASKS.md` or
   ask for it in the next Architect call), `docs/research/INDEX.md`.

---

## 17. What I could not verify

1. **That a server-written attribute on a `Workspace` part reaches the client.** This design rests on
   it (8.1). The repo already relies on attribute replication for `ReplicatedStorage.Flags.State`,
   and this is the exact fallback `docs/design/lobby.md` section 18 item 5 names for the direction it
   could not prove — but **only a live session proves the read**. `lobby_live.spec` asserts the
   write. If it does not replicate, the pads, the parties and the departures all still work and the
   **dialog never opens**, which is the default-size path (15.4) and not a broken lobby.
2. **Whether `Workspace.StreamingEnabled` is on in the Forest Test place.** If it is, a client far
   from the yard may not have the pad parts, so `padPositions()` is short and `padAsking` answers nil
   — the chevron is simply absent and the dialog does not open, which is the correct answer either
   way (*never a guess and never a blank frame*). No decision here rests on it.
3. **The free models' exact bounding boxes.** Section 4.1 uses the numbers written in
   `Lobby.CONFIG.TRUCK.MODEL` and `LODGE.MODEL`'s comments (task 180 measured them); I did not
   re-measure them, and I cannot — they are Studio content in another place. The clearances are also
   asserted against the **parts** build, which the spec can reach, and the parts build is the tighter
   of the two.
4. **How 9 x 12 reads under eight bodies.** It is 108 square studs for eight characters. The
   arithmetic says it holds them; whether it looks crowded is a picture, so it is Karen's.
5. **Whether `smoke.sh`'s current wait is 8 s or 20 s.** It is the Director's file and is not in this
   repository; both numbers appear in repo documents (`ESCALATE.md` 2026-10-13 proposes 8, the
   research note section 7 assumes the old 20). Section 15.4 states the requirement — **≥ 15 s** —
   rather than assuming which is live.
6. **No harness run, no lint and no build was performed for this document.** The Architect is
   read-only; `.agent-evidence/` is for `c0f24f9`.

---

## 18. Open decisions

**None of them blocks building.** The design is complete and buildable as written.

### For Karen (feel and design)

1. **The look of the four pads**: the four colours, `TRANSPARENCY` 0.45, the rim, and whether the
   billboard sits high enough at `OFFSET_STUDS` 6. Every row is one line.
2. **The words**: *"step on a truck pad to hunt"*, *"HOW MANY PLAYERS?"*, *"1 / 1  alone"*,
   *"8 / 8  full hunt"*, and `TRUCK %d` / `%d / %d`.
3. **9 x 12 studs** (section 4.1 says what bounds each number) and the four party **sizes**
   (1, 2, 4, 8).
4. **8 s to pick and 45 s to fill.** Eight is long enough to read four buttons; forty-five is the
   longest a solo player should wait for friends who are not coming.
5. **`NEEDS KAREN`, probably**: the Forest Test Studio in Play so the two screenshots can be taken
   (15.5).

### For the Director (scope)

1. **`smoke.sh`'s wait must be ≥ 15 s** (15.4). It is his file and the change is one number. With
   8 s it will report `FAIL: gun not in hand` while the pads work exactly as designed.
2. **The teleport's flag row** (9.1). It is not added in this task, because the table is at
   `MAX_FLAGS = 13` with thirteen rows declared and because a flag over code that does not exist
   cannot satisfy CLAUDE.md's "reachable by parameter as well as by flag". When the teleport is
   built it needs either `MAX_FLAGS = 14` or one of `TASKS.md` 82b's three retirements first.
   **Confirm that is the order you want**; nothing today changes either way.
3. **The chevron's arrival band** (10.2). `ARRIVED_IN_STUDS` 12 is tied to the hunter's stand radius,
   so on a 9 x 12 pad the chevron goes out ~7 studs short of the pad's edge. The fix is a per-target
   band (`Target.arriveIn`, one optional argument to `Objective.arrived`); it is **queued, not
   built**, because it touches a shared pure function for a case the objective line already covers.
4. **If the 3.5 hours run out, the split is clean at step 5** (section 16): **182** = the four pads,
   the state machine, the default size and the party reaching the drive (no remote, no panel, no
   client change beyond the nearest-pad chevron); **182b** = the size dialog and its door. Step 5 is
   a complete, playable, screenshot-able game. **The design is buildable as one task either way** —
   this is a scope call, not an engineering one.
5. **`docs/design/lobby.md`'s three replacement sections** (section 2) are the Architect's edit, not
   the Builder's (CLAUDE.md roles). Queue it, or ask for it in this run's next Architect call.
