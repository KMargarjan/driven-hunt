# Design: grid-map — one world, eight drive cells, one cell per round

Task 327 · Architect · 2026-11-01 · written to `reviews/task-327/BRIEF.md`, which **overrides anything
older** in `docs/`, `TASKS.md` or an earlier design (`docs/ARCHITECT_PROMPT.md`). D1–D11 are not
re-opened. What this document rules on is everything the brief left to the Architect: the grid's
geometry and its owner, whether a cell is a new system or a `Layout`, the round flow and its
arithmetic, the safety proof, the part and frame budgets, the map deltas, the tests and the task
split.

Karen, 2026-11-01 ~18:45 and ~19:20: the brief §1 carries her words verbatim and they are not
restated here.

Deltas this forces on `drive-places.md`, `drive-layouts.md`, `stand-pick.md`, `map-ui.md`,
`drive.md`, `high-seats.md`, `bots.md`, `shop.md` and `map-generator.md` are in §14, as **exact
text for the Builder to paste**, because the Architect script writes only this one file.

---

## 0. The six facts this design is built on, every one of them already in the repo

Read these first. Four of them change the obvious answer, and two of them are the reason this is
eight small tasks and not one big one.

**F1. A drive place is already DATA, and the generaliser already exists.** `ForestTest.LAYOUTS`
(`src/shared/ForestTest/init.luau`) is four frozen rows — `name`, `label`, `centre`,
`amplitudeStuds`, `standCount`, `standSpacing`, `halfSpanStuds` — and *everything* that places a
hunter, a beater, a marker, a tower, a rest spot, a wave or an exit plane is written against that
record: `roadZ`, `standX`, `standPosition`, `standSpan`, `exitZOf`, `beaterStart`, `boundsOf`,
`fieldFor`, `corridorOf`, `wavePoint`, `restPoint`, `Markers.build`, `Seats.ensure`,
`HighSeats.STANDS`, `Places.PLANS`. **A CELL IS A LAYOUT ROW. It is not a new system**, and §2 is
why that is the ruling and not a shortcut.

**F2. The wood is already planted from code, at run time, and it was already measured at this
scale.** `src/shared/Places/init.luau` is the pure planner (`Places.plant`, `Places.layer`,
`Places.capacity`, `Places.inLane`), `src/server/Places/init.luau` is the one writer of
`Workspace.DrivePlaces` (`Places.build`, `Places.plantOne`), and task 326 measured **3,253 planted
trees in Karen's place, 0 of them floating** (TASKS.md row 326). The grid reuses that planter whole.

**F3. The road surface is already paintable without touching terrain height.**
`src/server/Places/Ground.luau` — `Ground.paint` → `Terrain:ReplaceMaterial`, chunked at
`CHUNK_STUDS` 200, with the terrain **injected** so no spec can write DEV's ground
(`docs/design/drive-places.md` §7).

**F4. The safety rule is a PROXIMITY rule, not a cone, and that is what makes stands on three sides
of a cell safe.** `Match.CONFIG.SAFETY_LOCK_ENABLED = true` / `SAFETY_LOCK_STUDS` (6): the trigger
does not fire while the shot line passes within that of **any person, human or bot, hunter or
beater** (`src/server/Match/init.luau`, `Match.lineUnsafeFor`). `Match.Penalty.judge` ties a shooter
whose fired shot passed within `SAFETY_MISS_STUDS` (12) of a person inside
`SAFETY_RANGE_STUDS` (330). The cone (`Weapon.SafetyArc.isForbidden`, `SAFETY_ARC_HALF_DEG` 45,
about `line.normal`) is only the *into-the-drive* half. §7 is the proof that D10 needs **no change
to any of them**, and the cell's own width is the proof.

**F5. The stand pick is already built and already dark.** `src/server/Match/StandPick.luau`
(`judge` pure, `claim` yields nowhere), the `StandRequest` remote, `snapshot.picks` /
`snapshot.pickWindow` (`src/shared/Drive/init.luau`), `MapUi.setStandStates` / `tapStand` /
`setPickWindow` / the `Hit` pads, `HighSeats.dealLine`'s fifth parameter and its sweep A, all behind
`Flags.STAND_PICK` with `default = false` (TASKS.md rows 323a, 323b). D7 is a **rename and one new
refusal reason**, not a build.

**F6. `Flags.MAX_FLAGS` is 23 and there are 23 rows.** `src/shared/Flags/init.luau`. Any new flag
needs that number raised, and `tests/server/flags.spec.luau` fails the harness if it is not. §11.1.

---

## 1. What it must do, and what it must not do

### 1.1 Must do

| Must | Why |
|---|---|
| Be **ONE world** cut by straight forest roads into **8 drive cells**, 2 rows × 4 columns, replacing the four separate drive places | D1, Karen: *"we don't need several different maps terrains we have one devided in sections"* |
| Size a cell so the beaters **walk through it inside the drive clock**, from ONE number set in CONFIG | D2, Karen: *"based on time how much time ?"* |
| Make each cell read differently **from a hunter's eye at ground level and from a beater's**, from relief and from mixed tree sections | D3, Karen: *"each place is a bit different for the hunter to get real life experience"*. A number cannot answer it (rule 5) |
| Put stands — **ground spots and towers** — along the road edges of a cell, several per side, each a bit different | D4 |
| Run **one drive in one cell**, show that cell, its stands and **the beaters' direction** before the pick | D5 |
| Let every player **vote** on the results screen for the next cell, from the cells not yet driven this cycle | D6, Karen: *"maybe they can vote to choose what to take ?"* |
| Make the shop's one access card **STAND CHOICE**: holders pick first, everyone else is placed at **random** on what is left | D7, Karen: *"instead tower license there will be choose stand"*, *"who has license can select first then what remains is yours"* |
| Put **every** tree and **every** stand on the ground, through `src/shared/TreeGround`, at task 326's census | D3, lesson L-086, rule E |
| Stay inside a **stated** part, tree and frame budget, measured and printed | D8, Karen: *"to not be laggy or look odd"* |
| Be a **pure function of (cell, seed)**: same commit, same forest, whatever order it was built in | so a frame Karen judges can be rebuilt and a defect bisected. `drive-places.md` §2 |
| Work on **touch** | D11 |
| Do **nothing at all** in the DEV place, loudly, once | the harness runs in DEV |

### 1.2 Must not

Each line is a boundary, not a style note.

1. **Must not be a second world system.** `ForestTest` keeps every behaviour it has and gains eight
   `LAYOUTS` rows plus four **optional** record fields (§3.2). A parallel `src/server/Grid/` holding
   its own markers, seats, beater line, rest spots, waves and field would be ~4,500 lines of second
   answer to questions `ForestTest` already answers. The grid's **data and pure geometry** are a new
   module (`src/shared/Grid`); its **behaviour** is `ForestTest`'s, unchanged.
2. **Must not write terrain HEIGHT.** `drive-places.md` §1.2 item 3 stands: `Terrain:FillBlock`,
   `WriteVoxels` and any height write are refused here. The relief is **measured**, not generated
   (§4), and painting a surface material (`Ground.paint`) is the only terrain call in this system.
3. **Must not be a second planter.** `src/server/Places/` stays the one writer of a planted tree
   and of road material. `Workspace.GridPlaces` is a second FOLDER with the same writer, never a
   second writer.
4. **Must not add a phase, a clock or a timestamp.** `Phase.luau`'s cardinal rule — *"EVERY
   TRANSITION IS TIME-DRIVEN FROM `phaseEndsAt`, AND `phaseEndsAt` IS THE ONLY CLOCK"* — holds: the
   vote window **is** the `Scoring` phase and the pick window **is** `Assigning` (§5).
5. **Must not change any safety number.** `SAFETY_LOCK_STUDS`, `SAFETY_MISS_STUDS`,
   `SAFETY_RANGE_STUDS`, `SAFETY_ARC_HALF_DEG`, `Weapon.SafetyArc`, `Match.Penalty` and
   `Weapon.Rules` are read-only to this system. §7 proves D10 without touching one of them.
6. **Must not let a FLANK post answer a LINE question.** `Match.lineReferenceFor`,
   `Match.crossedLine`, `Match.beaterGoalFor`, `Match.gatherSpotFor` and `Fill.standsFree` must be
   given the **main line's** posts only. §6.4 is the hole and the fix; it is the one genuine defect
   this design creates and closes.
7. **Must not break the four old places while they are still the world.** Every function listed in
   F1 answers, for `LAYOUTS.road` / `edge` / `ride` / `track`, **value for value** what it answers
   today, and `forest_stand.spec` already asserts the road number for number.
8. **Must not make the world switch a feature flag.** §11.2: task 79's measurement applies verbatim.
9. **Must not plant or destroy 2,400 models in one frame.** §8.3.
10. **Must not delete.** The four places' rows, `Places.PLANS` and `Workspace.DrivePlaces` are
    archived under `backups/` with a note (rule 7) and kept as the rollback.
11. **Must not claim a frame nobody looked at.** `ESCALATE.md` 2026-11-01 records that
    `screen_capture` against the Forest Test returns one cached image for six cameras. Until that is
    fixed, rule 5 on this work is **Karen's eye** and nothing else. §13.4, open decision D-1.

---

## 2. The pattern adopted, and why

**A CELL IS A LAYOUT ROW, AND THE WORLD IS A UNIFORM GRID OF THEM.** One world, cut into
coordinate-named cells, one cell active at a time, content authored per cell from a recipe. That is
Unreal's World Partition shape (§12 source A) with the cell size taken from gameplay rather than
from streaming.

**EVERY CELL'S MAIN LINE IS EAST–WEST AND EVERY DRIVE PUSHES SOUTH.** This is the single decision
that makes the whole thing small, and it falls out of Karen's own layout. One horizontal road through
the middle and a border road around the whole gives three east–west roads. The north row's four
cells take the **middle** road as their hunter line (beaters muster on the north border road); the
south row's four take the **south border** road (beaters muster on the middle road). So:

* the drive axis is still +Z → −Z, so `roadZ`, `exitZOf`, `beaterStart`, `beaterNorthStuds`,
  `crossedLine`, `lineReferenceFor`, `wavePoint`, `restPoint`, `boundsOf` and `fieldFor` are
  **untouched arithmetic**;
* `ForestTest.DRIVE_BEARING_DEG` (0) and `PUSH_BEARING_DEG` (180) stay constants, so the compass and
  `MapUi.setPush` need no per-cell answer;
* no axis basis, no rotated layout record, no second code path anywhere.

The alternative — a layout that carries an axis, so a north–south road can be a hunter line — would
have made ~20 pure functions axis-aware and re-opened every spec that asserts them. **Rejected, and
the cost of rejecting it is named in §15 K-1:** the upwind road carries no stands, so "all around the
rectangle" is three sides, not four.

**A PURE PLAN, THEN A THIN PLANT, IN SLICES.** `drive-places.md` §2's split, with one addition:
`Places.plantCell` emits the plan and `src/server/Places/Slice.luau` spends it against a Heartbeat
budget, nearest-to-the-hunter-line first. The budget exists because the cell's wood is now rebuilt
**every drive** instead of once at boot, and 2,400 models in one frame is a hitch (§8.3). The slice
idea is `MapGen.steps`' own — *"~3,000 Models in one step is one step that can time out and tell you
nothing about where it was"* (`src/serverstorage/MapGen/init.luau`).

**A PER-CELL SEED FROM THE CELL'S COORDINATES, NOT FROM A COUNTER.** `Grid.seedFor(cellId, stream)`
hashes the world seed with the cell's row and column, so a cell's forest is the same whatever order
the cells were built in — the property `drive-places.md` §10.1 found broken when the planter's reader
could see its own trees. Minecraft's chunk seeding is the source and **its documented failure is the
reason the road lane stays a subtraction** (§12 source B).

**PLURALITY OVER THE UNDRIVEN, RANDOM ON A TIE.** SourceMod's `mapchooser` rule set, cut to what
fits in nine seconds (§12 source C).

**ONE WRITER EACH, AND ONLY ONE OF THEM IS NEW.** §3.

What is borrowed from inside this repo, said plainly (rule 2): `ForestTest`'s whole record, markers,
seats, beater line, rest spots, waves and field; `Places` and `TreeGround` whole, including
`Ground.paint`'s injected-terrain discipline; `HighSeats.dealLine` and its serial dictatorship;
`StandPick.luau`'s shape, file position and reasoning for `CellVote.luau`; `MapUi`'s `Stand%d` +
transparent `Hit` child for `Cell%s`; `Bots`' `stepMsAvg` / `stepMsMax` counters for the frame
budget; `Map.EXPECTED_WORLD`'s switch and its rollback recipe.

---

## 3. Ownership — one writer each, named (rule 3)

### 3.1 The table

| System | Owner (the only writer) | Location on disk |
|---|---|---|
| **The grid's geometry and the 8 cells** (origin, cell size, road widths, cell ids, stand slots per side, relief rows, recipe names, animal patterns, seeds) | **nobody at run time**: frozen data and pure functions | **`src/shared/Grid/init.luau`** (NEW) — `Grid.CONFIG`, `Grid.CELLS`, `Grid.ROADS` |
| **The eight layout rows the drive reads** | **nobody at run time**: frozen data, **derived from `Grid` at load** | `src/shared/ForestTest/init.luau` — `ForestTest.LAYOUTS`, `LAYOUT_ORDER` |
| **Which cell is live, and the cycle** | **`ServerScriptService.ForestTest`** — `chosen.*`, **unchanged owner** | `src/server/ForestTest/init.luau` — `layoutForDrive`, `publishLayout`, `promote` |
| **The ballot and the tally** | **`ServerScriptService.Match.CellVote`** (NEW) | **`src/server/Match/CellVote.luau`** |
| **The vote window, and whether it is open** | **`Match.Phase`** — it **is** `state.phase == "Scoring"` + `state.phaseEndsAt` | `src/server/Match/Phase.luau` — `Phase.voteWindow` (NEW, pure) |
| **The ballot on the wire, and the verdict** | **`Match.snapshot`** and `Match`'s `CellVote` handler | `src/server/Match/init.luau` |
| **`Workspace.GridPlaces` and every instance in it** | **`ServerScriptService.Places`** — **unchanged owner** | `src/server/Places/init.luau` — `Places.build`; `src/server/Places/Slice.luau` (NEW) |
| **The roads' terrain MATERIAL** (and nothing else about terrain) | **`ServerScriptService.Places`** — **unchanged owner** | `src/server/Places/Ground.luau` — `Ground.paintRoads` (NEW) |
| **The stand and beater marker parts** | **`ServerScriptService.ForestTest.Markers`** — **unchanged owner** | `src/server/ForestTest/Markers.luau` |
| **The towers** | **`ServerScriptService.ForestTest.Seats`** — **unchanged owner** | `src/server/ForestTest/Seats.luau` |
| **Which stand a hunter holds** | **`Match.StandPick`** — **unchanged owner** | `src/server/Match/StandPick.luau` |
| **Where a character stands** | **`Match.Body`** — **unchanged owner** | `src/server/Match/Body.luau` |
| **Every pixel of the map** | **`Hud.MapUi`** — **unchanged owner** | `src/client/Hud/MapUi.luau` |
| **Which cell/stand/vote view `MapUi` is given** | **`Hud`** — one evaluation, `renderObjective`'s own discipline | `src/client/Hud/init.luau` |
| **The drive wire on the client** | **`PlayerScripts.Match`** — **unchanged owner** | `src/client/Match/init.luau` |
| **The wiring** | **`src/server/ForestTestBoot.server.luau`** — boot lines only; owns nothing, decides nothing | — |

**One new shared data module and one new server module. Everything else keeps its owner.** That is
the whole point of §2's ruling, and it is what makes this eight small tasks.

### 3.2 `ForestTest.Layout` gains four OPTIONAL fields, and every old row is bit-identical

`drive-places.md` §1.2 item 1 forbade adding a field to the `Layout` record. **This brief overrides
it** (`docs/ARCHITECT_PROMPT.md`), and the reason the old rule existed is honoured instead: the
record stays the one world-**geometry** seam, and nothing about dressing, seats or picks enters it.

```luau
export type Layout = {
    name: string,            -- a cell's name IS its id: "A1".."D2". Nothing else keys on a cell
    label: string,
    centre: Vector3,         -- the MAIN line's middle. Y is a fallback ground only (unchanged)
    amplitudeStuds: number,  -- 0 for every cell: a cell's roads are straight in plan
    standCount: number,      -- EVERY stand of the cell: main + both flanks (15)
    standSpacing: number,    -- the MAIN line's spacing (150)
    halfSpanStuds: number,   -- the main line's ground run-out (unchanged meaning)

    -- NEW, ALL FOUR OPTIONAL. nil on `road`/`edge`/`ride`/`track`, so those four rows answer
    -- value for value what they answer today -- asserted, not claimed (§13.1 case 2).
    sides: Sides?,              -- the stand sides. nil means "one side, standCount stands" = today
    beaterNorthStuds: number?,  -- where the beaters muster. nil = LINE.spawnNorthStuds + BEATER.behindLineStuds (580)
    fieldNorthStuds: number?,   -- the boar field's north edge. nil = DRIVERS.startNorthStuds + 200 (900)
    cellOf: { row: number, column: number }?,  -- for Grid.seedFor and the map. nil = not a cell
}

export type Sides = {
    main: { count: number, spacingStuds: number },
    flanks: { count: number, spacingStuds: number, firstStuds: number, offsetStuds: number },
}
```

`ForestTest.beaterNorthStuds()` and `ForestTest.boundsOf()` gain the same trailing-optional-layout
parameter every other function in that file already has, and read the new fields with the stated
fallback. **Two one-line changes; no caller moves.**

### 3.3 What this system reads and writes, and who owns each

| Reads / writes | Owner | Through |
|---|---|---|
| **writes** `Workspace.GridPlaces` (and destroys its own previous cell) | `ServerScriptService.Places` | `Places.build`, `Slice.step` |
| **writes** terrain **material** inside every road | `ServerScriptService.Places` | `Ground.paintRoads` → `Terrain:ReplaceMaterial` |
| **writes** `Workspace.ForestMarkers` (the active cell's 15 posts, the beater pad) | `ServerScriptService.ForestTest.Markers` | `Markers.build` |
| **writes** `Workspace.HighSeats` (the active cell's towers) | `ServerScriptService.ForestTest.Seats` | `Seats.ensure` |
| **writes** the live cell name attribute | `ServerScriptService.ForestTest` | `publishLayout` → `ReplicatedStorage.ForestTest.Live.Layout` |
| **writes** the ballot | `Match.CellVote` | `claim`, `release`, `reset`, `close` |
| **reads** the grid geometry | `src/shared/Grid` (frozen data) | require |
| **reads** the terrain height | `ServerScriptService.ForestTest` — `terrainYAt` | injected at the boot |
| **reads** who may pick first | `src/shared/Shop` — `Shop.grantsStandChoice` (renamed, §10) | `Match.placementLine`'s `entitled` |
| **reads** the planting rule | `src/shared/TreeGround` | `bounds`, `groundBand`, `samples`, `spread`, `decide` |
| **reads** templates | **Karen's Studio content** (`OurForest`, `Session`, `LobbyAssets.Trees`) | `Clone()` only, never a write (rule 7) |
| **is read by** the ground readers' ignore list | `ServerScriptService.ForestTest` | `ForestTest.GROUND_IGNORE` gains `"GridPlaces"` |

Rows for `GAME_DESIGN.md`'s *System owners* table (rule 3):

```
| The grid world's geometry: 8 cells, their roads, stand slots, relief rows and recipes | **nobody at run time** (frozen data, pure) | `src/shared/Grid/init.luau` | [the grid map](docs/research/2026-11-01-the-grid-map.md) |
| The active cell's wood and the roads' surface | `ServerScriptService.Places` (`Workspace.GridPlaces`) | `src/server/Places/`, `src/server/Places/Slice.luau` | [the grid map](docs/research/2026-11-01-the-grid-map.md) |
| Which cell the party votes for next (the ballot and the tally) | `ServerScriptService.Match.CellVote` | `src/server/Match/CellVote.luau` | [the grid map](docs/research/2026-11-01-the-grid-map.md) |
```

---

## 4. The world, as data and as arithmetic

### 4.1 The stud conversion, and every number derived from it

**1 stud = 0.28 m** (`ForestTest.SPOOK.METRES_PER_STUD`, and the same number `Horn.CONFIG`,
`Report.CONFIG` and `Boar.CONFIG.SENSE` publish). **1 m = 3.5714 studs.**

| | metres | studs | derivation |
|---|---|---|---|
| cell width (east–west) | 299.6 | **1070** | Karen's 300 m, rounded to 10 studs |
| cell depth (north–south) | 400.4 | **1430** | Karen's 400 m, rounded to 10 studs |
| road clear width (no tree stands in it) | 11.8 | **42** | `2 × (halfStrip 9 + Places.LANE_STUDS 12)` — the `track` place's measured number, `drive-places.md` §4.2 |
| road painted width | 5.0 | **18** | `Places.PLANS.track.surface`, which is the one surface Karen's reference frames demand |
| road pitch (cell + road) | | **1112** | 1070 + 42 |
| **world footprint, x** | **1257** | **4490** | `4 × 1070 + 5 × 42` |
| **world footprint, z** | **836** | **2986** | `2 × 1430 + 3 × 42` |
| world area | | **13.41 M sq studs** | |
| one cell's area | | **1.530 M sq studs** | |

Karen's *"one big terrain ... 1.2 km x 0.8 km"* comes out at **1.26 km × 0.84 km**. The roads are
what makes it bigger than 1.2 × 0.8, and they are hers.

**A border road around the whole is NOT the Architect's option, it is forced.** D4 says the active
cell's bordering road sides are the hunter line; without a border road the eight outer cells have
only two or three roads. So: **3 east–west roads (2 border + 1 middle) and 5 north–south roads
(2 border + 3 interior)**, exactly Karen's *"straing road vertical and horizintal in the middle ...
then we can devide into 2 more vertical lines and then 8 rectangles"* with the frame she needs for it
to work.

### 4.2 Cell ids, and which road is which

Columns **A B C D** west to east; rows **1** (north) and **2** (south). Eight ids: `A1 B1 C1 D1 A2
B2 C2 D2`. The id is the layout's `name`, so `Places.CELL_PLANS`, `HighSeats.STANDS`,
`ForestTest.LAYOUTS` and the vote's wire all key on the same string and no second naming exists.

| | row 1 (north) | row 2 (south) |
|---|---|---|
| main line (the hunter line) | the **middle** east–west road | the **south border** road |
| beaters muster on | the **north border** road | the **middle** road |
| flanks | the two north–south roads that bound the cell | the same |
| push | **south** | **south** |

So the middle road is a hunter line for row 1 and a muster line for row 2, and over a cycle a hunter
stands on every east–west road and every north–south road in the world. **Every drive pushes south**
(§2).

### 4.3 The beater walk-time arithmetic — the number the cell size comes from (D2)

The beaters start at the cell's upwind road and walk to the main line, i.e. the cell's full depth.

```
required walk speed = cellDepthStuds / driveSeconds
```

`ForestTest.DRIVE.seconds` is **300** (Karen's place; `Match.CONFIG.DRIVE_SECONDS` is 600 and
`DRIVE_SECONDS` is on `Match.WORLD_OVERRIDABLE`). `Bots.CONFIG.WALK_SPEED` is **3.1** today.

| cell depth | walk speed needed | line arrives at | verdict |
|---|---|---|---|
| 580 (today's `beaterNorthStuds`) | 1.93 | 187 s at 3.1 | today's drive |
| **1430 (this design)** | **4.77** | **275 s at 5.2** | **chosen** |
| 930 | 3.00 | 300 s at 3.1 | the fallback if Karen wants today's walk |

**Ruling: `Grid.CONFIG.beaterWalkStudsPerSecond = 5.2`, and `Bots.CONFIG.WALK_SPEED` takes it.**
1430 / 5.2 = **275 s**, plus `BEATERS_THROUGH_GRACE_SECONDS` 15 = 290 s, inside the 300 s clock — so
Karen's second ending (*"when all beaters cross line of hunters"*, `END_ON_BEATERS_CROSS`) can
actually fire instead of always being beaten by the timer.

**This is not a reversal of task 251's measurement, it is the same measurement at a new depth.**
`WALK_SPEED` went 5 → 3.1 to stretch a 130 s drive over a 580-stud walk (`ForestTest.SCHEDULE`'s own
header). The cell is 2.5× deeper, so the same 300 s drive needs the speed back.

**Two consequences, both good, both asserted rather than hoped:**

1. **Every one of the fifteen release slots still plays.** `SCHEDULE.firstSlotSeconds` 10 +
   14 × `intervalSeconds` 13 = **192 s**, against an arrival at 275 s — **83 s of margin** where
   today there is 18. The spec asserts the relation, not the number:
   `firstSlotSeconds + (slots - 1) * intervalSeconds <= cellDepthStuds / beaterWalk`.
2. **`SCHEDULE.leadStuds`' clamp stops biting.** A group is released at
   `min(table depth, lineDepth − 130)`. At t = 192 s the line is at `1430 − 5.2 × 192` = **432**
   studs, so slot 15 is released 302 studs ahead of the line. Today the same slot is clamped to
   `minNorthStuds` 25 — *"they are then level with the line rather than ahead of it"*
   (`ForestTest.SCHEDULE`'s own comment). The deeper cell fixes what task 251c had to accept.

**The risk, named: bots now walk 1430 studs through standing wood with no pathfinding.**
`src/server/Bots/Lane.luau`'s header rejects `PathfindingService` by name. Task 162 measured a
580-stud walk through `OurForest` at 120 s with the lanes crossing ~2,200 trees. 1430 studs has never
been measured in this place. §9 makes *bots that cross the line in a drive* a target with a number
and §13.3 puts it in the live-only list.

### 4.4 Relief: measured, not generated — and why (D3)

**RULING: for `grid:v1` the relief is Karen's existing bought terrain, MEASURED per cell and recorded
as a data row. No terrain height is written anywhere.**

Four reasons, in order of weight:

1. **It is the only option that gets Karen something she can SEE in one task** (brief §3.7). A
   generated heightfield over 13.41 M sq studs is **2.9× the whole DEV map's area** — `MapGen` writes
   2048 × 2048 as 256 tiles of 128 studs at ~4 s a tile (`MapGen.steps`' own estimate), so the grid
   would be ~750 tiles and **~50 minutes of edit-time build**, driven step by step by
   `tools/mapgen.py`, in a place where that pipeline has never run. `MapGen.Config.INCLUDE.relief` is
   `false` even in DEV.
2. **The relief she has already differs per section, and it was measured.** `drive-places.md`
   BRIEF M8: **58–98 studs of relief over a whole plot** and **29–37 studs along a 700-stud stand
   line**, with the two chosen plots holding **zero** non-terrain parts. That is D3's *"hills,
   hollows, a slope, a dip — different per cell"*, and it is measured rather than invented.
3. Rule 7: her bought terrain is not touched.
4. Rule 2: borrow before building. A generated heightfield here would be inventing a second answer to
   "where is the ground" in a world that already has one.

**The escape hatch is the row's SHAPE, so switching the source later is not a redesign.** Each cell
carries what was measured, filled by 327a's survey:

```luau
-- src/shared/Grid/init.luau
relief = {
    character = "slope",   -- one word, for the map legend and the recipe: flat | slope | ridge | dip | rolling
    minY = 121.4, maxY = 168.9,   -- MEASURED, terrainYAt on a 20-stud lattice over the cell
    spreadStuds = 47.5,           -- maxY - minY
    lineSpreadStuds = 31.2,       -- along the main line's own 1070 studs: what a hunter's eye reads
},
```

A later task that generates the relief writes the same four fields from its own heightfield and
`grid.spec`'s assertions do not move. **Open decision D-5 if the Director wants it generated now.**

### 4.5 The tree recipes (D3)

`Places.PLANS` is keyed by layout name and `Places.planFor(name)` answers nil for a name with no
row — already true (`Places.planFor("road") == nil` is asserted). Eight new rows, one per cell, in
the **same record shape** the three dressed places already use (`halfStripStuds`, `beltStuds`,
`bands`, `spacingStuds`, `deepSpacingStuds`, `fernSpacing`, `minGapStuds`, the four mixes, the two
scale bands, `seed`), plus two fields a cell needs that a line does not:

```luau
-- src/shared/Places/init.luau -- Places.CELL_PLANS, beside Places.PLANS
zones = {           -- MIXED TREE SECTIONS, Karen: "different trees growing in different section, mixed"
    -- Each zone is a rectangle in CELL-RELATIVE fractions (0..1 across, 0..1 deep), so a zone row
    -- is independent of the cell's size and survives a CONFIG change to it.
    { at = { 0.00, 0.00, 0.45, 0.60 }, mix = "spruceThicket", spacingStuds = 24 },
    { at = { 0.45, 0.00, 1.00, 0.35 }, mix = "mixedWood",     spacingStuds = 30 },
    { at = { 0.20, 0.60, 0.70, 1.00 }, mix = "clearing",      spacingStuds = 0 },  -- 0 = no trees
    ...
},
skirtStuds = 230,   -- how far into a NEIGHBOUR cell the wood reaches from a shared road (§8.2)
```

Species come from `Places.SPECIES` unchanged — the names counted in `Workspace.OurForest` on
2026-10-17 (`conifer` 7 spruce, `young` 4 larch, `birch` 8, `oak`/`fieldOak`, `aspen` 4, `fern` 5).
**No new asset, no upload, no asset id.** The eight recipes differ in: which zones, which mixes,
clearing count and size, `spacingStuds` per zone, and the seed. Honest gaps carry over verbatim from
`drive-places.md` §4.2 — summer leaf, no crop model, a green floor rather than brown litter.

### 4.6 The grid's public interface — `ReplicatedStorage.Grid`, PURE

```luau
Grid.VERSION   = "grid:v1"             -- the string Map.EXPECTED_WORLD resolves to
Grid.CONFIG    : frozen                -- origin, cellWidthStuds, cellDepthStuds, roadClearStuds,
                                       -- roadPaintStuds, rows, columns, beaterWalkStudsPerSecond, seed
Grid.CELLS     : frozen                -- 8 rows: id, row, column, relief, recipe, animals
Grid.CELL_ORDER: frozen                -- { "A1","B1","C1","D1","A2","B2","C2","D2" } -- the fallback cycle

Grid.cellIds(): { string }                               -- a fresh copy (layoutNames' discipline)
Grid.cellOf(id: string?): Cell?                          -- nil for a name nobody knows
Grid.boundsOf(id: string): Bounds                        -- the cell's interior, minX/maxX/minZ/maxZ
Grid.roads(): { Road }                                   -- every road: axis, at, from, to
Grid.roadsOf(id: string): { main: Road, west: Road, east: Road, muster: Road }
Grid.layoutFor(id: string): ForestTest.Layout            -- the row ForestTest.LAYOUTS takes (§3.2)
Grid.sideOf(id: string, standIndex: number): "main" | "west" | "east"
Grid.standPosition(id: string, standIndex: number): Vector3   -- side-aware; main indices agree with
                                                              -- ForestTest.standPosition exactly
Grid.standWalk(id: string): { number }                   -- main centre-out, then flanks near-first
Grid.mainStandCount(id: string): number                  -- 7. What Fill.standsFree is given (§6.4)
Grid.towerStands(id: string): { number }                 -- HighSeats.STANDS[id], measured (327b)
Grid.seedFor(id: string, stream: number): number         -- hash(CONFIG.seed, row, column, stream)
Grid.footprint(): Bounds                                 -- the whole world, for the map's bounds
Grid.separationStuds(id: string): number                 -- the worst cross-side stand pair (§7)
```

`Grid` requires **nothing**. `ForestTest` requires `Grid` (for the eight rows); `Grid` never requires
`ForestTest`. One direction only, which is `drive-places.md` §1.2 item 1's own rule applied to the
new seam.

---

## 5. The round flow, and the phase arithmetic (brief §3.3)

### 5.1 One drive, end to end

```
Running  (300 s)   the drive in cell X
   |
Scoring  (9 s)     the results scene -- AND THE VOTE. The window IS this phase.
   |               Match: CellVote.reset(driveNumber); map auto-opens to the WORLD view
   |               ...taps, each judged, claimed, force-broadcast...
   |
[lobby NEXT 6 s]   the role choice, untouched
   |
Assigning (5 s, or 15 s with STAND_PICK)
   |               1. CellVote.close(); Match.nextCell() = the tally's answer
   |               2. ForestTest.layoutForDrive(driveNumber, override, nextCell) promotes the cell
   |                  -> Markers.build (15 posts), Seats.ensure (towers), applyField, retire
   |               3. Places: DESTROY the old cell's wood, then PLANT the new, in slices (§8.3)
   |               4. the STAND PICK window: licence holders first, then everyone (§10)
   |
Running            settleStands; the first animal at FIRST_RELEASE_SECONDS (20 s)
```

**Gap, drive to drive: 20 s today, 30 s with `STAND_PICK` on** — `SCORE_SECONDS` 9 +
`Lobby.CONFIG.PADS.NEXT.SECONDS` 6 + `INTERMISSION_SECONDS` 5, unchanged, and that total is Karen's
own budget (`Match.CONFIG`: *"9 + 6 + 5 = 20 s"*).

### 5.2 The vote window IS `Scoring`, unlengthened

```lua
-- src/server/Match/Phase.luau -- PURE, the shape Phase.pickWindow already has
function Phase.voteWindow(state: State?, config, candidateCount: number?): boolean
    return state ~= nil
        and state.phase == "Scoring"
        and (config.CELL_VOTE_SECONDS or 0) > 0
        and (candidateCount or 0) > 1      -- one candidate is not a vote; zero is a cycle reset
end
```

```lua
-- src/server/Match/init.luau, Match.CONFIG -- THE ONE BOUNDARY READ OF THE FLAG
-- Nine seconds and not a second more: it is SCORE_SECONDS, so the window cannot outlive its phase
-- and there is nothing to keep in step. If nine is too short, SCORE_SECONDS is Karen's row and
-- moving it moves both.
CELL_VOTE_SECONDS = if Flags.isOn("CELL_VOTE") then SCORE_SECONDS else 0,
```

**Why this and not the alternatives**, each rejected for a named reason:

| Alternative | Rejected because |
|---|---|
| a new `"Voting"` phase | a fifth `PhaseName` on the wire that every client, every `Objective.CONFIG.TEXT` row and `Phase.driveOpen`/`insideDrive`/`lineHeld` would have to learn. `Phase.luau`'s header has refused one three times (tasks 158, 159, 323) |
| a `task.delay` window | a second clock. `Phase.luau`: *"a hitch cannot skip a phase"*; a delay can |
| the vote in `Assigning` | the cell must be promoted, the markers measured and the wood planted **before** the stand pick, and `Match`'s `dispatch` already *"measures the markers on the `Assigning` edge (task 179)"*. A vote inside `Assigning` would decide the ground after the hunters were standing on it |
| lengthening `Scoring` for the vote | it is a feel change to a row Karen moved twice (25 → 8 → 9) and the vote does not need it. Hers to move |

### 5.3 The tally, resolved exactly where the cell is already chosen

`ForestTest.layoutForDrive(driveNumber, override)` is **idempotent per drive number** on
`chosen.drive`, and *"`chosen.cycle` and not `chosen.name` is what it steps from"* (its own comment,
after the round-1 finding of task 193). One argument is added and one branch:

```lua
-- src/server/ForestTest/init.luau
-- `voted` IS THE PARTY'S ANSWER, or nil. It takes the place of the rotation's step and NOTHING
-- else: the override still wins (the Director's DHForestLayout), a vote for a cell nobody knows is
-- a warn and a normal deal, and `chosen.cycle` still records what was actually driven -- so
-- clearing the override resumes the cycle, exactly as it does today.
function ForestTest.layoutForDrive(driveNumber: number?, override: any, voted: string?): string
```

```lua
-- src/server/ForestTest/init.luau -- the cycle, generalised from 4 names to 8 with a DRIVEN SET,
-- because a vote cannot be "the next in order".
function ForestTest.nextCell(previous: string?, driven: { [string]: boolean }?, voted: string?, roll: number?): string
```

**The rule, in four lines (D6, and §12 source C's rule set):**

1. candidates = `Grid.CELL_ORDER` minus the cells driven this cycle;
2. candidates empty → **the cycle resets**, every cell is a candidate again, and that reset is
   printed once;
3. `voted` is a candidate → it wins;
4. otherwise → the candidate at `roll`, a seeded pick (`Grid.seedFor(previous, VOTE_STREAM)`), so a
   tie, no votes and a flag-off build all land on a reproducible answer a spec can assert.

**`nextCell(prev, nil, nil, roll)` over eight drives visits all eight exactly once**, and that is the
assertion, not the order.

### 5.4 The ballot: `Match.CellVote`, the shape `StandPick` already has

```lua
-- src/server/Match/CellVote.luau -- a sibling of Phase.luau, StandPick.luau and Roster.luau:
-- THE RULE IS PURE, THE STATE IS ONE TABLE, AND THE OWNER MEASURES THE WORLD.
export type Ask = {
    userId: number,
    cell: string,
    open: boolean,              -- Phase.voteWindow, measured by the owner
    candidates: { [string]: boolean },  -- what the WORLD says is votable this cycle
    playing: boolean,           -- is he in this drive at all (Phase.participantIds)
    mine: string?,              -- what he voted for now
    lastAt: number?, asks: number, now: number, config: any,
}

CellVote.REASON = table.freeze({
    CLOSED = "closed", ROLE = "role", RANGE = "range",
    RATE = "rate", FLOOD = "flood", SAME = "same",
})
-- `Rules.ORDER`'s own rule: the outermost fact about the asker first.
CellVote.ORDER = table.freeze({ CLOSED, ROLE, RANGE, RATE, FLOOD, SAME })

function CellVote.judge(ask: Ask): (boolean, string?)     -- PURE. No service, no Player, no clock
CellVote.reset(driveNumber: number)
CellVote.claim(userId: number, cell: string, now: number): (boolean, string?)  -- YIELDS NOWHERE
CellVote.release(userId: number): string?
CellVote.close()
CellVote.voteOf(userId: number): string?
CellVote.tally(): { [string]: number }       -- frozen; the snapshot field
CellVote.winner(candidates: { string }, roll: number): string   -- PURE: plurality, random on a tie
CellVote.stats(): { asks, accepted, refused: { [string]: number }, malformed, resets }
```

| Reason | Refused when | The word his screen shows |
|---|---|---|
| `closed` | `not ask.open` | `voting is over` |
| `role` | `not ask.playing` | *(silent)* |
| `range` | not a string, or not a candidate | `not this round` |
| `rate` | `now - lastAt < CELL_VOTE_MIN_INTERVAL` (0.25) | *(silent)* |
| `flood` | `asks > CELL_VOTE_MAX_REQUESTS` (10) | *(silent)* |
| `same` | `cell == ask.mine` | *(silent, and it is not an error)* |

Every word is ≤ 25 ASCII characters, inside `Objective.CONFIG.TEXT`'s measured bound of 33
(`hud_clarity.spec`'s `TextFits` at 400 px). **Both beaters and hunters vote** — Karen said
*"they can vote"*, and a beater has as much stake in the next cell as a hunter.

**Why both directions on one remote**, and it is `StandRequest`'s own argument
(`stand-pick.md` §4.1): the **tally** is a property of the drive and rides `MatchState` beside
`picks`, `stands`, `tied` and `through`; the **verdict** is addressed to one player and is the reply
to one ask, which cannot ride `MatchEvent` (`FireAllClients`).

### 5.5 The wire

```json
// src/shared/Drive/Remotes.model.json
{ "className": "Folder", "children": [
    { "name": "MatchState",   "className": "RemoteEvent" },
    { "name": "MatchEvent",   "className": "RemoteEvent" },
    { "name": "StandRequest", "className": "RemoteEvent" },
    { "name": "CellVote",     "className": "RemoteEvent" }
] }
```

```lua
-- CLIENT -> SERVER. ONE STRING. Anything else is dropped and counted (stats.malformed), never
-- coerced: `tostring(t)` on a client's table is the server believing a client's type.
CellVote:FireServer(cellId: string)

-- SERVER -> THAT CLIENT, exactly once per ask it did not drop.
export type CellVerdict = { ok: boolean, cell: string, reason: string? }
CellVote:FireClient(player, verdict: CellVerdict)
```

```lua
-- src/shared/Drive/init.luau, MatchSnapshot -- two fields, the `picks` / `pickWindow` idiom
-- THE TALLY, not the ballot: cellId -> how many voted for it. Eight rows at most. Who voted for
-- what is nobody's business on screen, and a per-voter table would be a second representation of
-- a fact that fits in eight numbers.
votes: { [string]: number }?,
-- WHAT I VOTED FOR. One string, so the map can mark my own choice without reading the ballot.
myVote: string?,
-- IS THE VOTE OPEN RIGHT NOW. NOT derivable from `phase == "Scoring"` alone: the flag may be off
-- and the cycle may have one candidate left, and a map that opened itself and refused every tap is
-- the worst of the three states.
voteWindow: boolean?,
-- WHICH CELLS ARE STILL VOTABLE, and which cell this drive is in. ABSENT means "not a grid world",
-- which is what every pre-327 world publishes and what makes the client draw exactly what it drew
-- before this task.
cells: { id: string, driven: boolean, active: boolean }?,
```

`phaseEndsAt` already carries the deadline, in server time. **No new timestamp.**

**The broadcast rule** is `stand-pick.md` §4.4's, for its reason: an **accepted** vote calls
`broadcast(true)` — forced, past `STATE_MIN_INTERVAL` (0.25 s) — because a client that learns 1.2 s
late that a cell has four votes is a client voting on a stale tally. A **refused** one broadcasts
nothing and sends only the verdict. Ceiling: 16 players × one accepted change per 0.25 s over 9 s =
**576 worst case, and 16 to 32 in practice.**

---

## 6. The stands (D4)

### 6.1 Fifteen stands per cell, on three sides, and the numbers are derived

| | count | spacing | span | first | where |
|---|---|---|---|---|---|
| **main** (the downwind road) | **7** | **150** | 900 of 1070, 85 studs of run-out each end | — | on the main road, indices 1–7 west → east |
| **west flank** | **4** | **220** | 660 of 1430 | **340** studs north of the main road | on the west road, indices 8–11 near → far |
| **east flank** | **4** | **220** | 660 | **340** | on the east road, indices 12–15 near → far |
| **upwind road** | **0** | — | — | — | the beaters muster here (§2, open decision K-1) |

* **150 studs** on the main line is Karen's accepted spacing — *"150 studs is 42 m"*, a real driven-hunt
  figure (`ForestTest.LAYOUTS.road`'s own comment), and it is unchanged from the road she has played.
* **220 studs** on a flank is 61.6 m — wider, because a flank sees fewer crossings over a longer
  frontage.
* **340 studs** is not a taste value. It is **derived from the slug's range** and §7 is the derivation.
* **15 stands for up to 8 hunters** means `HighSeats.dealLine`'s pass 3 (every stand taken, wrap onto
  a shared stand) is unreachable, and Karen is choosing from fifteen, which is what *"several stands
  in on line"* asks for. Open decision K-4 if that is too many icons.

**Towers: `HighSeats.capFor(15)` = 5 per cell, at least one per side.** Which five is **measured, not
chosen**, by task 218's own rule and instrument: rank the cell's fifteen stands by `gain` (a fan of
seven rays north from a deck eye 12.5 studs up against a ground eye), take while the count is under
the cap, no two adjacent, `gain >= MIN_GAIN_STUDS` (60), `spread <= MAX_FOOT_SPREAD_STUDS` (4.0),
`relief <= JUMP_RELIEF_STUDS` (1.8). **Measured in a PLAY session, not in Edit** — task 218's own
finding: the Edit run read `DrivePlaces=ABSENT` and moved two gains by over 40 studs. That
measurement is task 327b.

### 6.2 The stand index is side-aware, and nothing else changes

```lua
-- src/shared/Grid/init.luau
-- THE INDEX ORDER IS LOAD-BEARING AND IS NOT COSMETIC: HighSeats.STANDS[cellId], StandPick's
-- claim, snapshot.picks, MapUi's Stand%d nodes and ForestTest.standArea all key on it, so it may
-- never be re-ordered without moving every one of them. Main first, because the main line is the
-- one every pre-327 reader assumes is "the stands".
--   1..7    the main line, west to east            (ForestTest.standX / standPosition, unchanged)
--   8..11   the west flank, nearest the main road first
--   12..15  the east flank, nearest first
function Grid.standPosition(id: string, standIndex: number): Vector3
```

`ForestTest.standPosition(index, layout)` delegates to `Grid.standPosition` when
`layout.sides ~= nil`, and is **unchanged** otherwise. For a main index the two agree **exactly**,
by construction and by assertion (§13.1 case 4).

Everything downstream works unchanged because it reads `standPosition`, not arithmetic:
`Markers.build`'s `1..standCount` loop, `Markers.ring`, `Seats.ensure`, `ForestTest.nearestStand`,
`withinStand`, `standArea`, `boundaryPoint`, `StandPick`, `dealLine`.

### 6.3 The walk

```lua
-- src/shared/Grid/init.luau
-- THE ORDER STANDS ARE OFFERED IN, and it is HighSeats.dealLine's `walk` parameter, so there is no
-- second walk to drift from. Main line centre-out first -- a hunter dealt a stand with nobody
-- playing should be in the middle of the line, which is ForestTest.standWalk's own rule -- then the
-- flanks, nearest the main road first and alternating sides so one flank is never filled before
-- the other is touched.
--   7 stands:  4 3 5 2 6 1 7
--   then:      8 12 9 13 10 14 11 15
function Grid.standWalk(id: string): { number }
```

### 6.4 The hole this creates, and the fix — a FLANK POST MUST NOT ANSWER A LINE QUESTION

**This is the one genuine defect the design introduces, and it is closed here rather than found
later.**

**Evidence.** `Match.lineReferenceFor(position, line, posts)` (`src/server/Match/init.luau`) picks
the post with the smallest **lateral** distance — `|delta − normal·(delta·normal)|`, with
`normal = +Z` — and returns it as *where the line is for this beater*. Its callers are
`Match.crossedLine` (the drive's second ending), `Match.beaterGoalFor` (where a bot beater walks to)
and, by the same shape, `Match.gatherSpotFor`, which takes `posts[ceil(#posts / 2)]` as the middle
stand. `Fill.standsFree(postCount, realHunters)` is given `#posts`.

With fifteen posts in the list, a beater walking south at `x = centre + 500` is **50 studs** laterally
from the main line's end post (`centre + 450`) and **56** from the east flank's first post
(`centre + 556`) — and at `x = centre + 510` the flank post **wins**. Its z is the main road
**+ 340 studs**, so `crossedLine` would call that beater *through* 340 studs early, `beaterGoalFor`
would walk him to a point 340 studs short of the road, `gatherSpotFor` would lay the dead animals out
on a flank, and `Fill` would hire **15 − n** bot hunters instead of **7 − n**.

**Why it matters.** `END_ON_BEATERS_CROSS` is one of the two ways a drive ends. A drive that ends
when the beaters are a third of the way down the cell is a drive that ends at ~90 s instead of 275.

**The fix: one new field, one subset, four call sites.**

```lua
-- src/server/ForestTest/Markers.luau -- Markers.Set
-- THE MAIN LINE'S POSTS, AND ONLY THEM. `posts` is every stand of the cell, in index order, and is
-- what the map, the pick and the placement want. THIS is what answers "where is the hunters' LINE",
-- which is a question about the drive's axis -- a flank post is 340 studs up the cell and would
-- answer it wrong by exactly that much (design 6.4). nil-safe: with no `sides` it IS `posts`.
linePosts: { BasePart },
```

`Match.crossedLine`, `Match.beaterGoalFor`, `Match.gatherSpotFor` and the `Fill.standsFree` call site
read `markerSet.linePosts`. A spec case drives a beater down the x where the flank post would have
won and asserts the reference is the main post (§13.1 case 7).

**One more, same class.** `ForestTest.hunterStandX()` is where the waves are aimed. A west-flank
hunter's x is `centre − 556`, **outside** the main line's ±450 span, so aiming there would push
animals out of the cell through the flank road. **Fix:** `hunterStandX` clamps to
`ForestTest.standSpan(layout)`. One `math.clamp`, and a case at both ends.

---

## 7. Safety on every stand of every cell (D10), and it needs no rule change

**The ruling: D10 holds with NO change to any safety number, and the cell's own width is the proof.**

The three rules, and what each says about a cell:

| Rule | What it measures | On a cell |
|---|---|---|
| `Weapon.Rules.beaterInLine` | the aim ray would hit a beater → the shot is **refused** | person-relative. Works on every stand of every side, unchanged |
| `Match.lineUnsafeFor` (`SAFETY_LOCK_STUDS` 6) | the shot line passes within 6 studs of **any** person, hunter or beater, human or bot → the trigger **does not fire** | person-relative. Unchanged |
| `Match.Penalty.judge` (`SAFETY_MISS_STUDS` 12, `SAFETY_RANGE_STUDS` 330) | a fired shot passed within 12 studs of a person, inside 330 studs → **tied to a tree** | person-relative and **range-bounded**. Unchanged |
| `Weapon.SafetyArc.isForbidden` (`SAFETY_ARC_HALF_DEG` 45, about `line.normal` = +Z) | shooting **into the drive** → published violation | the drive axis is +Z for every cell (§2), so this is **exactly today's rule** |

**The one thing a four-sided stand ring could add is a hunter shooting at a hunter across the cell,
and the cell is too wide for the shot to arrive.** `Shotgun.CONFIG.RANGE_STUDS.Slug` is **330 studs**
(`Match.CONFIG.SAFETY_RANGE_STUDS` is that number, for that reason: *"past it nothing arrives"*). So
the design's invariant is:

> **Every pair of stands on DIFFERENT sides of a cell is at least `Shotgun.CONFIG.RANGE_STUDS.Slug`
> apart.**

The arithmetic, with the numbers of §6.1 (`cx` = the cell's centre x, `rz` = the main road's z):

| pair | Δx | Δz | distance | verdict |
|---|---|---|---|---|
| main end stand (`cx+450`, `rz`) ↔ east flank 1 (`cx+556`, `rz+340`) | 106 | 340 | **356.1** | ✓ 26.1 studs of margin |
| west flank 1 ↔ east flank 1 | 1112 | 0 | **1112** | ✓ |
| east flank 4 (`rz+1000`) ↔ main line, any | ≥106 | ≥1000 | **≥ 1005** | ✓ |
| main ↔ main (adjacent) | 150 | 0 | 150 | **inside range — and this is today's game**, nine stands at 150 on the `road` layout, handled by the lock and the penalty |
| flank ↔ flank (same side, adjacent) | 0 | 220 | 220 | same |

**`flankFirstStuds` = 340 is derived from that inequality and not chosen:**

```
Δx = (cellWidth/2 + roadClear/2) − (mainCount−1)/2 × mainSpacing = 556 − 450 = 106
required Δz = sqrt(330² − 106²) = 312.5
flankFirstStuds = ceil(312.5) + 27.5 of margin = 340
```

Written in the code as that formula, not as the literal, so a change to the cell width, the main
count or the spacing moves it instead of silently breaking it. **The spec asserts the pairwise
inequality over all 8 cells and all 105 pairs**, so any CONFIG change that breaks it reddens a case
(§13.1 case 5).

**What this does NOT promise, stated so nobody claims it:** two hunters on the **same** side are
inside slug range of each other, exactly as nine hunters on the `road` layout are today. That is what
`SAFETY_LOCK` and `Penalty` are for, and this design changes neither. And a flank hunter who shoots
north-west, out of the cell and over the flank road into the neighbouring cell, is shooting at the
neighbouring cell's wood — nobody is standing there, because only the active cell has posts.

---

## 8. How the world is generated and placed (brief §3.2)

### 8.1 What is built, when, and by whom

| | when | by | lives in |
|---|---|---|---|
| the roads' terrain material | **once, at boot**, in slices | `Places` → `Ground.paintRoads` | Terrain (a Play session's write; discarded when Play stops) |
| the **active cell's** wood + the skirts into its neighbours | **every drive**, at the `Scoring → Assigning` edge, in slices | `Places` → `Slice.step` | `Workspace.GridPlaces` |
| the active cell's 15 posts and the beater pad | every drive, on the `Assigning` edge | `ForestTest.Markers` | `Workspace.ForestMarkers` |
| the active cell's towers | every drive, on the `Assigning` edge | `ForestTest.Seats` | `Workspace.HighSeats` |
| the relief | **never** | nobody. It is the place's terrain, measured (§4.4) | Terrain |

**Only one cell is dressed at a time, and that is arithmetic rather than a preference.** Full-density
wood over the whole 13.41 M sq studs at the `ride` recipe's 30-stud spacing is **~14,900 trees ≈
104,000 parts** — five times `Map.BUDGET.parts` (20,000) and thirty-two times what task 326 measured
standing in this place. There is no version of "dress the whole world" that fits.

### 8.2 The skirt — what the hunter sees across the road

A road's clear width is **42 studs**. A hunter on the main line looks 21 studs across it into the
**next cell**, which is not the active one. If only the active cell is dressed, he is looking at bare
grass. So:

**Every cell adjacent to the active cell is dressed with a SKIRT from the shared road inward**:
`80` studs at the active cell's own spacing (full density), then to `skirtStuds` 230 at
`deepSpacingStuds` 60. The second band's 60-stud grid is `drive-places.md` §10.2's measured horizon
— *"the frames show 40–60 m of sight line between trunks in high forest ... so past the 230-stud
full-density band a 60-stud grid IS the horizon"*.

### 8.3 The budget, and the slice that spends it

| What | Target | Derivation |
|---|---|---|
| trees in the active cell | **≈ 1,500** | 1.530 M sq studs / 900 (30-stud jittered grid), less 7 % for the lane subtraction, less `minGapStuds` drops |
| ferns (the `herb` band, hugging the roads) | **≈ 260** | ~150 k sq studs of herb band / `fernSpacing` 24² |
| skirt trees, worst case (4 neighbours) | **≈ 650** | 400 k / 900 full + 750 k / 3,600 coarse |
| **models per drive** | **≈ 2,400; hard bound < 3,600** | `Places.capacity`, asserted as `#list <= capacity` |
| **parts per drive** | **< 22,000** | ≈ 7 descendants per model (`drive-places.md` §11). **Printed, never assumed** |
| plant work | **1.08 s** total | 2,400 × 0.45 ms/model (M9: 200 models in 0.09 s) |
| **plant slice budget** | **≤ 4.5 ms per Heartbeat**, ≤ 10 models a step | 10 × 0.45 ms |
| **whole cell planted** | **< 4.0 s** (240 frames at 60 Hz) | 2,400 / 10 / 60 |
| **whole cell destroyed** | **< 4.0 s**, same budget, **FIRST** | so the peak part count is one cell's, never two |
| head-room | **40 s** against 8 s of work | `Assigning` 5 (or 15) + `FIRST_RELEASE_SECONDS` 20, plus `Scoring` 9 and NEXT 6 if needed |
| road paint | **≤ 300 `ReplaceMaterial` calls, < 4.0 s, once at boot** | 28,400 studs of road / `CHUNK_STUDS` 200 = 142 chunks × 2 source materials = 284, at ≤ 2 calls a Heartbeat |
| per-frame cost of the standing wood | **0** | anchored parts, no script, no animation, no heartbeat |

```lua
-- src/server/Places/Slice.luau -- THE BUDGETED LOOP, AND NOTHING ELSE. It decides nothing: the
-- plan says what goes where, `Places.plantOne` plants it, and this spends a frame budget.
--
-- Pattern: MapGen's own step split -- "~3,000 Models in one step is one step that can time out and
-- tell you nothing about where it was" (src/serverstorage/MapGen/init.luau).
--
-- NEAREST THE HUNTER LINE FIRST, and that is a LOOK decision with a reason: the hunter is put on
-- his stand at `enterAssigning` and the picture fills outward from his feet, so what he sees while
-- it grows is the near belt and not a bald cell. With STAND_PICK on he is looking at the map for
-- the whole 15 s anyway.
Slice.BUDGET_MS      = 4.5
Slice.MAX_PER_STEP   = 10

Slice.order(plan: { Places.Planting }, layout): { Places.Planting }   -- PURE: by |z - roadZ(x)|
Slice.begin(kind: "plant" | "destroy", items, context)
Slice.step(now: number): (number, boolean)    -- (items spent, done)
Slice.stats(): { planted, destroyed, steps, stepMsAvg, stepMsMax, pending, seconds }
```

`stepMsAvg` / `stepMsMax` are `src/server/Bots/init.luau`'s own two counters, borrowed by name
(rule 2) — because a budget nobody measures is a hope.

### 8.4 The ground rule is `drive-places.md`'s, whole

Every tree is settled by `src/shared/TreeGround` on the **lowest** terrain under its own trunk
footprint, read at 25 samples, refused outright above the step allowance, and the refusal is
**counted and printed** — not a tree left in the air and not a crash. **Task 326's census is the
acceptance test, verbatim:** `0` models above the ground and `0` spanning over 300 studs, out of
however many were planted. The planter is handed **`ForestTest.terrainYAt`** (Terrain only) and not
`groundAt`, which is `drive-places.md` §10.1's fix and the reason the plan cannot depend on its own
planting order. `ForestTest.GROUND_IGNORE` gains `"GridPlaces"`, and `grid.spec` asserts
`table.find(Forest.GROUND_IGNORE, Planter.GRID_FOLDER) ~= nil` so the name exists once.

---

## 9. The animals (D8)

### 9.1 Per-cell patterns, as data on top of the schedule that exists

`ForestTest.SCHEDULE` is taken **whole**: fifteen slots, `firstSlotSeconds` 10, `intervalSeconds` 13,
`DENSITIES = { quiet = 9, normal = 13, busy = 15 }`, `releaseDepth`'s `leadStuds` 130 /
`minNorthStuds` 25 clamp against the live beater line, the repeating window for a drive that outlives
its script, and the stag's slot 13. **A cell does not get its own schedule.** It gets a row that
*parameterises* the one that exists:

```luau
-- src/shared/Grid/init.luau -- Grid.CELLS[i].animals
animals = {
    -- HOW BUSY. Karen OK'd `normal` (13 of 15 slots). A cell may be quieter or busier, which is
    -- half of "each round feels different".
    density = "normal",
    -- WHERE THEY START, as a fraction of the cell's DEPTH, not as studs: so a CONFIG change to the
    -- cell size moves every row at once and none of them can be left behind.
    startDepth = { 0.85, 0.70, 0.55, 0.40 },
    -- WHERE THEY BREAK OUT, as a fraction of the main line's own span (-1 west .. +1 east). Karen:
    -- "we will make patter how they run where run how manny to have fun". `wavePoint` already
    -- takes a crossing x; this biases it.
    routeBias = "split",     -- centre | west | east | split | wide
    -- WHICH ZONES HOLD THE RESTING GROUPS, by the recipe's own zone index, so animals are stocked
    -- IN COVER and never in a clearing -- which is `ForestTest.restSpot`'s own rule
    -- (`nearTrunkStuds` 22) expressed where the cover is decided.
    restZones = { 1, 2, 4 },
}
```

`ForestTest.releaseLine`, `slotAt`, `stagRow`, `restSpot`, `stockWood`, `wavePoint` and
`computeRoute` are **unchanged**; they are handed the cell's numbers instead of the layout's.

### 9.2 The budget, and how it is measured

| What | Target | How |
|---|---|---|
| live animals at the busiest instant | **≤ 24** | counted every drive. Slot 12 releases nine today, so 24 is three overlapping groups |
| hard ceiling | **`ForestTest.MAX_BOARS` = 60**, unchanged | `ForestTest.release` already refuses past it |
| **boar runtime, server step** | **≤ 4.0 ms/frame average, ≤ 8.0 ms peak** | **NEW: `stepMsAvg` / `stepMsMax` on the boar runtime**, the two counters `src/server/Bots/init.luau` already has. Today the boar runtime has neither, and that is a hole this task closes rather than inherits |
| **bots, server step** | **≤ 4.0 ms/frame average** | `Bots.stats().stepMsAvg` / `stepMsMax`, exists |
| animal parts | **< 2,000** | ≤ 24 live × the boar model's descendants. Printed |
| bots that cross the line in a drive | **≥ 90 %** | **not measured. §13.3** — a 1,430-stud walk through planted wood with no pathfinding has never been measured in this place (§4.3) |
| drive length | **275 s of beater walk, ± 5 s**, ending inside a 300 s clock | by construction: `cellDepth / beaterWalk` |

**"No lag, nothing that looks odd" is not a number and cannot be one.** The numbers above bound the
cost; whether it *looks* odd is rule 5 and it is Karen's eye (§13.4, open decision D-1).

---

## 10. Stand choice: the licence picks first, the rest are thrown (D7)

### 10.1 The shop row — a rename and a grant, and the ID DOES NOT MOVE

```lua
-- src/shared/Shop/init.luau
[Shop.ITEM.HIGH_SEAT] = {                 -- the id stays "access.highseat" (see below)
    id = Shop.ITEM.HIGH_SEAT,
    label = "STAND CHOICE",               -- was "HIGH SEAT ACCESS"
    category = "access",
    blurb = "You choose your own stand on the map before the drive, ahead of everyone else.",
    price = 600, hunts = 5, sale = true,
    grants = { standChoice = true },       -- was { highSeat = true }
}
```

**`Shop.ITEM.HIGH_SEAT` is still `"access.highseat"` and that is not laziness.** The repo's own rule,
written for exactly this case when RED STAG CARD became DEER LICENCE: *"THE ID DOES NOT MOVE ...
those are KEYS, they are what a saved purchase is stored under, and renaming one would un-own the
card for everybody who already has it"* (`src/shared/Shop/init.luau`). A comment at the row says so.

`Shop.grantsHighSeat` is **renamed** `Shop.grantsStandChoice`, keeping its **nil → true** rule and
its stated reason (*"an un-wired world — and a DataStore outage — must deal exactly as it does
now"*). The old name is archived in `backups/` with a note (rule 7).

**Towers stop being gated, and that is Karen's sentence.** *"instead tower license there will be
choose stand"*: a tower is now just a stand you may pick. So `HighSeats.dealLine`'s `seated` /
`entitled` pair no longer refuses anyone a seated stand — `entitled` is all-true, which `dealLine`'s
own header says is *"today's deal, value for value"* with `entitled == nil`. `StandPick.judge`'s
`seat` reason becomes unreachable and is **kept, marked unreachable, with a case that drives it by
parameter** (the discipline `drive-places.md` §1.2 item 8 asks for), because a later task may gate
towers again. Open decision K-5.

### 10.2 Two sub-windows, one clock

Karen: *"who has license can select first then what remains is yours"*. So the pick window has two
halves, and **both are read off `phaseEndsAt`** — there is no second clock and no second phase.

```lua
-- src/server/Match/StandPick.luau -- ONE new pure predicate and ONE new reason word.
-- WHOSE TURN IS IT. `secondsLeft` is `state.phaseEndsAt - now`, the only clock there is.
-- With STAND_CHOICE_FIRST_SECONDS = 0 this is `true` always, which is task 323's game by identity
-- and is how both states are reachable by parameter while the dial sits at one of them.
function StandPick.mayAskNow(entitled: boolean?, secondsLeft: number, config): boolean
    if entitled ~= false then return true end
    return secondsLeft <= (config.STAND_PICK_SECONDS - config.STAND_CHOICE_FIRST_SECONDS)
end

StandPick.REASON.TURN = "turn"     -- his screen: `licence holders first`
```

```lua
-- src/server/Match/init.luau, Match.CONFIG
-- SIX OF THE FIFTEEN. Long enough for a holder to read the map and tap; short enough that a man
-- with no licence is not watching a countdown for most of the window. The Director's start value,
-- and one row.
STAND_CHOICE_FIRST_SECONDS = 6,
```

`StandPick.ORDER` becomes `{ CLOSED, ROLE, TURN, RANGE, RATE, FLOOD, SAME, SEAT, TAKEN }` — `TURN`
third, by `Rules.ORDER`'s own rule: the outermost fact about the asker first, before anything about
the stand he asked for.

### 10.3 What is left is thrown at random, not dealt centre-out

D7: *"when their window closes, everyone else is placed at RANDOM on what remains"*. Karen's
*"randomly trowen there"*.

```lua
-- src/shared/HighSeats/init.luau -- dealLine gains a SIXTH argument.
-- `roll` SEEDS THE ORDER THE LEFTOVER STANDS ARE OFFERED IN (task 327). nil is the centre-out walk,
-- value for value -- every caller written before this argument, the DEV place and every spec.
-- SEEDED AND NOT `math.random`: the deal must be reproducible from (driveNumber, cellId) or a spec
-- cannot assert it and a defect cannot be bisected (design 2).
function HighSeats.dealLine(walk, seated, entitled, count, picks, roll: number?): { number }
```

Sweep A (every valid pick, in line-index order, before anybody takes anything by fallback) is
**unchanged** — it is what makes a claim strictly stronger than the fallback, which is the whole of
D7's *"who has license can select first"*. Sweep B's pass 1 shuffles the **free** stands with
`Random.new(roll)` before offering them. `Match.placementLine` passes
`Grid.seedFor(cellId, DEAL_STREAM) + driveNumber`.

### 10.4 Mobile (D11), with the arithmetic

The full map is a fixed **1100 px canvas** with a `UIScale` (`map-ui.md` §7.2). Two views now:

| view | bounds | px per stud | gap on canvas | on a 400 × 800 phone (scale 0.32) | the 44 px thumb minimum (`mobile-controls.md` §B) |
|---|---|---|---|---|---|
| **world** (the vote) | 4490 × 2986 studs | 0.245 | a cell is **262 px** | **84 px** | ✓ **comfortably**, with no list |
| **cell** (the pick) | 1154 × 1514 studs | 0.727 | stands **109 px** apart | **35 px** | ✗ |

**So the cell vote works on touch with a tap on the cell itself — no list, no tabs.** That is the
opposite of task 323's problem and it is worth saying: the world view is zoomed *out*, so its targets
are big.

**The stand pick on touch still needs 323c's list**, and the arithmetic says why: 35 px is below 44
and a bigger pad cannot fix it, because the stands themselves are 35 px apart. So 323c ships as part
of this work, with **one change**: fifteen rows at 44 px is 660 px against the phone panel's 644 px
(`map-ui.md` §7.4), so the `StandList` is a **`ScrollingFrame`** — one property (`CanvasSize`), no
tabs, no new owner. Each row carries the index, the side word (`MAIN` / `WEST` / `EAST`), the state
word (`FREE` / a name / `TOWER`) and nothing else, and its `Activated` calls **the same**
`MapUi.tapStand(index)` the markers call. One tap rule, not two.

---

## 11. The flags, the switch and the rollback (D9)

### 11.1 Two new flags, and `MAX_FLAGS` must move

`Flags.MAX_FLAGS` is **23** and there are exactly 23 rows (F6), so the cap is doing its job and the
next row fails `tests/server/flags.spec.luau`, which fails the harness, which blocks the merge gate.

```lua
-- src/shared/Flags/init.luau
Flags.MAX_FLAGS = 25,           -- 23 -> 25: the two rows below. The Director may prefer to retire
                                -- two instead (open decision D-3)

GRID_PREVIEW = {
    default = false,
    owner = "ServerScriptService.Places (and ReplicatedStorage.Grid, data)",
    born = "2026-11-01 task 327a",
    expires = "2026-11-22",
    why = "The grid world's roads and cell corners, painted and staked beside the four places so "
        .. "Karen can walk them before the world switches. It tags nothing, claims no stand and "
        .. "starts no drive, so with it OFF the four places are the world, bit for bit.",
},
CELL_VOTE = {
    default = false,
    owner = "ServerScriptService.Match (and ServerScriptService.Match.CellVote)",
    born = "2026-11-01 task 327e",
    expires = "2026-11-22",
    why = "Every player votes on the results screen for the next drive cell. OFF deals the next "
        .. "undriven cell by a seeded roll, which is the flag-off path and is reachable by "
        .. "parameter from a pure spec.",
},
```

Both read **once, at the boundary, and passed inward as a number**:
`CELL_VOTE_SECONDS = if Flags.isOn("CELL_VOTE") then SCORE_SECONDS else 0`. That is the only
permitted shape (CLAUDE.md, *"Feature flags"*), and `0` makes both states reachable by parameter.

### 11.2 The WORLD switch is by commit, and the MAP SWITCH exception applies verbatim

**Ruling: yes. `Map.WORLD_BY_PLACE[130094961655666]` goes `"forest-test"` → `"grid:v1"` in a
commit, and the grid is NEVER a feature flag.**

Task 79's measurement is not merely analogous, it is the same failure: *"built behind a flag, the map
sat in Workspace with the flag off and the same commit went from 32/32 checks to 22/27 with eleven
specs failing — including `GetTagged("DrivenHunt.ShooterPost")` answering **16**, because both worlds
tag with the same strings, which would have put shooters on map posts 700 studs away"*
(`src/shared/Map/init.luau`, and CLAUDE.md's *"THE MAP SWITCH IS THE EXCEPTION"*). Here, both worlds
would state stands through the same `ForestTest.Markers`, name them `Stand%d` in the same folder, and
`Markers.read` would answer with both sets. **A switch that cannot be switched off is not a feature
flag, and the world lives in the place.**

**`GRID_PREVIEW` is not a counter-example and the difference is measurable, not rhetorical.** The
preview paints terrain material and parents a `Folder` of trees and corner stakes. It **tags
nothing**, builds no `Stand%d`, no `HighSeats` child and no beater pad, and `ForestTest.LAYOUTS` does
not yet hold a cell row — so `Markers.read`, `GetTagged`, `standCount`, `nearestStand` and
`dealLine` answer identically with it on and off. `grid.spec` asserts exactly that: with the preview
on, `#Markers.folder():GetChildren()` and `ForestTest.layoutNames()` are unchanged.

### 11.3 The rollback, step by step

1. a commit back to `Map.WORLD_BY_PLACE[...] = "forest-test"`;
2. **`Places.build` destroys BOTH folders at boot, always, whichever world is live** — one line, and
   it is task 79's lesson in the other direction: the grid's wood must not be left standing in a
   world that has never heard of it. `grid.spec` asserts the destroy happens for the folder that is
   **not** this world's;
3. the roads: a Play session's `ReplaceMaterial` write is discarded when Play stops, which is the
   property `Lobby.Field` has relied on in this place since task 178. **`Ground.paintRoads` runs in
   a Play session only, never in Edit**, and the terrain is injected so no spec can paint.
   **I have not re-verified the discard myself (§16);** `drive-places.md` §7.2 did not either;
4. the four places' rows, `Places.PLANS` and `Workspace.DrivePlaces` are **kept, not deleted** —
   `ForestTest.LAYOUT_ORDER` becomes the eight cell ids and the four old rows stay in `LAYOUTS`,
   reachable by `DHForestLayout`, with `backups/2026-11-0X_task327_four-places.md` recording the
   order they were dealt in (rule 7, open decision D-4).

---

## 12. External sources (rule 1)

I could not fetch any of these in this run — the Architect has Read, Grep and Glob and no network.
Every licence and maintenance status below is from knowledge, and §16 says so.

### A. Unreal Engine 5 — **World Partition**
<https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition-in-unreal-engine>
**Licence:** Epic documentation, under the Unreal EULA. **Nothing is taken but the shape** — no code,
no asset. **Maintenance:** actively maintained; shipped and iterated across UE 5.0–5.5.
**Does well:** it is the industry's answer to Karen's exact sentence — *"we don't need several
different maps terrains we have one devided in sections"*. One world, a **uniform grid of square
cells**, a **stable id derived from the cell's coordinates**, content authored per cell, and only the
cells near the viewer resident. It also validates the "cell is the unit of content" decision: Epic
moved from `World Composition`'s hand-placed sub-levels to a derived grid precisely because
hand-named regions drift from the geometry.
**Does badly:** it is a streaming and *authoring* system for a C++ engine. Roblox has its own
distance-based streaming with no per-cell control — `Map.STREAMING`'s own comment records that four
of its five properties *"are NOT reachable from Luau"* — so none of the mechanism transfers. Its
cells are sized for memory (hundreds of metres to kilometres); ours is sized by how far a beater
walks in five minutes, which is a gameplay quantity Epic's grid knows nothing about.
**Adopted:** the uniform grid, the coordinate-derived id (`A1`…`D2`), and one active cell.

### B. Minecraft's chunk and decoration seeding (Mojang; the community wiki)
<https://minecraft.wiki/w/Chunk> · <https://minecraft.wiki/w/Java_Edition_level_format>
**Licence:** wiki text CC BY-NC-SA 3.0. **No code taken.** **Maintenance:** actively maintained; the
wiki tracks each release.
**Does well:** the per-region RNG seeded from `(worldSeed, cellX, cellZ)` rather than from a counter.
That is what makes a cell's forest **the same whatever order the cells were built in** — the exact
property `drive-places.md` §2 is built on and §10.1 found broken (*"it would depend on planting
order, so it would not be reproducible from the seed"*).
**Does badly:** and this is the more valuable half. Minecraft's own decoration pass is documented to
produce **border seams and "cascading worldgen"**, because a feature placed in one chunk may reach
into a neighbour that has not been generated yet. A road edge is exactly that boundary, and in this
world a tree that reaches across one would stand in a shooting lane.
**Adopted:** `Grid.seedFor(cellId, stream)`; and the **explicit rejection** of neighbour-reaching
decoration — the road lane stays a **subtraction** applied at the jittered point
(`Places.inLane`, `Places.clearOfEveryLane`), never a per-cell rule that hopes its neighbour agrees.

### C. SourceMod — **`mapchooser`** (AlliedModders)
<https://github.com/alliedmodders/sourcemod> · <https://wiki.alliedmods.net/Mapchooser_(SourceMod)>
**Licence:** **GPL-3.0 with a linking exception.** Incompatible with this repository, so **the
pattern only; not one line of code**, and this paragraph is the rule 2 disclosure.
**Maintenance:** actively maintained (SourceMod 1.11 / 1.12 branches).
**Does well:** the end-of-round map vote, tested on public servers for fifteen years. Its rule set is
D6: a candidate list that **excludes recently played maps**, a **fixed-length** vote tied to the
round's own end, **plurality wins**, and a **random tiebreak** so a tie never stalls the rotation.
**Does badly:** it adds nominations, a **runoff** second round and an *extend the current map*
option, none of which fits in nine seconds; and its vote is a console/radio menu, not a map, so it
says nothing about how eight cells should be *shown*. Its exclusion window is a count of maps, which
for eight cells is the whole cycle — so ours is the degenerate case of the same rule.
**Adopted:** plurality over the not-yet-driven candidates; random on a tie or no votes; cycle resets
after all eight. **Not adopted:** nominations, the runoff, the extend option.

### D. Red Blob Games — **"Making maps with noise functions"** (Amit Patel), with `amitp/mapgen2`
<https://www.redblobgames.com/maps/terrain-from-noise/> · <https://github.com/amitp/mapgen2>
**Licence:** `mapgen2` is **Apache-2.0**; the articles' code snippets are published for reuse.
**Maintenance:** the articles are **actively maintained**; `mapgen2` itself is **dormant** (no
substantive work since ~2017).
**Does well:** the clearest statement of **per-region character, then a recipe**: a region gets a
one-word character from a few cheap inputs, and the character picks what grows there. That is
`Grid.CELLS[i].relief.character` → `Places.CELL_PLANS[recipe]` exactly, and `MapGen.Config`'s
`OCTAVES` / `LACUNARITY` / `GAIN` / `WARP` / `WARP_FREQUENCY` are already from this family.
**Does badly:** its regions are Voronoi polygons grown from a Poisson scatter — nothing like a road
grid, and its whole output is a 2-D picture seen from above. It says nothing about what a wood looks
like from a hunter's eye at ground level, which is the only thing Karen judges (rule 5).
**Adopted:** character-then-recipe per cell, and **nothing** of its region shape.

### E. WILD UND HUND, *"Drückjagdstände — Sicher ist sicher?"*, and the Deutscher Jagdverband's
*Drückjagd* guidance
<https://wildundhund.de/> · <https://www.jagdverband.de/>
**Licence:** editorial text; the facts are used, nothing is reproduced. **Maintenance:** both are
live publications. The first is **already cited in `src/shared/ForestTest/init.luau`**, on the `edge`
layout, so this is a repo borrow as much as an external one.
**Does well:** it is the only source that says where a stand **belongs**: *not* on a path or in a
narrow clearing between two thickets — panicked game runs down those light bridges — but where the
passages converge and the bullet catch is safe. It is what justifies §6.1's flank set-back and §2's
ruling that the upwind road carries no stand: you do not put a *Schütze* on the line the *Treiber*
step off from.
**Does badly:** it is written about real rifles with a real *Kugelfang* and separations of hundreds of
metres between neighbours. A game that honours all of it has no shots in it. Our translation is one
inequality — **330 studs between any two stands on different sides** — which is the slug's own range
and not a German safety margin.
**Adopted:** three sides of stands, never the beaters' side; the flank set-back; and *know what is
behind the animal* implemented as the **existing proximity lock** rather than as a new cone.

### F. Roblox — instance streaming
<https://create.roblox.com/docs/workspace/streaming>
**Licence:** Roblox documentation. **Maintenance:** actively maintained.
**Does well:** it is why one 4,490-stud world is viable on a Roblox client at all, and
`Map.STREAMING` records that `StreamingEnabled` has been **true in this project since before
Milestone 1** — measured 2026-09-26, Studio 0.740.19.
**Does badly:** `Map.STREAMING`'s own measurement is that four of its five properties cannot be read
from Luau (*"not a valid member of Workspace"*), so the behaviour **cannot be asserted by a spec** —
only looked at. §13.3.

---

## 13. How it is tested

### 13.1 Server spec — `tests/server/grid.spec.luau` (NEW)

It runs in **DEV**, where no template and no grid exist, so every case is either pure or driven
through a fake reader — `places.spec`'s own discipline.

1. **eight cells, two rows, four columns** — `#Grid.cellIds() == 8`, ids `A1`…`D2`, every id in
   `ForestTest.LAYOUTS`, every `LAYOUTS` cell row in `Grid.CELLS`;
2. **the four old places are untouched, value for value** — for `road`, `edge`, `ride`, `track`:
   `sides`, `beaterNorthStuds`, `fieldNorthStuds` and `cellOf` are all nil, and `boundsOf`,
   `fieldFor`, `beaterNorthStuds()`, `standPosition`, `standSpan`, `exitZOf` and `corridorOf` answer
   **exactly** what `forest_stand.spec` already asserts for them. **This is boundary 7 and it is the
   case that stops this task breaking the world Karen plays today;**
3. **the footprint is the arithmetic** — `4 * cellWidth + 5 * roadClear == 4490`,
   `2 * cellDepth + 3 * roadClear == 2986`, no two cells overlap, every cell is inside
   `Grid.footprint()`, and `footprint` holds every road;
4. **a main stand index agrees with `ForestTest.standPosition` exactly** — for every cell, indices
   1..7, both functions, to 1e-9; and `sideOf` answers `main` for 1..7, `west` for 8..11, `east` for
   12..15;
5. **NO STAND IS WITHIN SLUG RANGE OF A STAND ON ANOTHER SIDE** — over all 8 cells and all 105
   pairs, `distance >= Shotgun.CONFIG.RANGE_STUDS.Slug`, computed by the spec's own loop and not by
   calling `Grid.separationStuds`; and the worst pair is **reported**, so a CONFIG change that eats
   the 26-stud margin is read as a number rather than a pass. **This is §7, and it is the case that
   makes D10 a property of the data;**
6. **`flankFirstStuds` is the formula and not a literal** — recomputed in the case from
   `cellWidth`, `roadClear`, `mainCount`, `mainSpacing` and `RANGE_STUDS.Slug`;
7. **a flank post never answers a line question** — a fake `Set` with 15 posts, a beater driven down
   the x where the flank post wins laterally, asserting `Match.lineReferenceFor` returns the **main**
   post; and `crossedLine` answers false at that beater's position. **§6.4;**
8. **`hunterStandX` is clamped to the main span** — a west-flank and an east-flank stand, both
   clamped, both ends;
9. **the beaters walk the cell inside the clock** —
   `cellDepth / beaterWalk <= DRIVE.seconds - BEATERS_THROUGH_GRACE_SECONDS`, and
   `SCHEDULE.firstSlotSeconds + (slots - 1) * intervalSeconds <= cellDepth / beaterWalk`;
10. **the release clamp does not bite** — `releaseDepth` at the last slot's time is at least
    `SCHEDULE.leadStuds` and never `minNorthStuds`;
11. **the walk is centre-out then flanks** — `Grid.standWalk` is `{4,3,5,2,6,1,7,8,12,9,13,10,14,11,15}`
    exactly, and it is a permutation of `1..15`;
12. **every recipe names a species group that exists** and every zone rectangle is inside `[0,1]²`,
    non-empty, and no two zones of one cell overlap;
13. **the same forest every time** — two `Places.plantCell` calls for one cell, item for item; and
    two calls for the SAME cell in a different **build order** (B1 then A1, A1 then B1) give A1 the
    same list. **This is `Grid.seedFor`'s whole reason;**
14. **under the declared capacity** — `#list <= Places.capacity(cell, plan)`, total < 3,600, and the
    worst cell is reported;
15. **nothing is planted in any road's clear width** — asserted **independently** of
    `Places.inLane` (`drive-places.md` §10.4 item 3's lesson) and also through it, over every cell;
16. **the skirt reaches the neighbour and stops** — every skirt planting is inside
    `skirtStuds` of a shared road and inside the neighbour's own bounds;
17. **the slice spends a budget and finishes** — `Slice.begin` with 2,400 fake items and a fake
    clock: no step exceeds `BUDGET_MS`, no step plants more than `MAX_PER_STEP`, `done` arrives, the
    total equals the input, and **destroy runs before plant** (so the peak count is one cell's);
18. **the slice order is nearest-the-line first** — `Slice.order` is monotone in `|z - roadZ(x)|`;
19. **the roads are painted through an injected terrain and nowhere else** — a fake `terrain` with a
    recording `ReplaceMaterial`: the call count ≤ 300, `resolution == 4`, every region inside a road's
    own painted half-width, and **zero** calls when `paintEnabled` is false;
20. **the ignore list and the folder name are one fact** —
    `table.find(Forest.GROUND_IGNORE, Planter.GRID_FOLDER) ~= nil`;
21. **the other world's folder is destroyed** — `Places.build` in a `forest-test` world destroys
    `GridPlaces`, and in a `grid:v1` world destroys `DrivePlaces`. **§11.3 step 2;**
22. **the preview tags nothing** — with `GRID_PREVIEW` reachable **by parameter**,
    `ForestTest.layoutNames()`, `Markers.stats().posts` and the tagged counts are unchanged.

### 13.2 Server spec — `tests/server/match_cell_vote.spec.luau` (NEW)

1. **`judge`, one case per refusal reason**, each with no remote, no `Player` and no clock, and
   `CellVote.ORDER` asserted as the order they fire in;
2. **`winner`: plurality** — 3/2/1 picks the 3; **a tie is the roll** (two cells at 2, two different
   rolls, two different answers, both candidates); **no votes is the roll**;
3. **`claim` yields nowhere and first-in wins** — two claims with the same `now`, the second reads a
   table the first wrote;
4. **a vote for a driven cell is `range`**, and a vote for a cell nobody knows is `range`;
5. **`reset` drops every ballot on the drive edge**, so a vote in drive 4 cannot win drive 6;
6. **the cycle visits all eight exactly once, then resets** — `nextCell` walked 16 times with no
   votes visits each id twice and prints one reset;
7. **a vote beats the roll; the override beats the vote** — `layoutForDrive(n, "B2", "C1")` is `B2`,
   and **does not advance `chosen.cycle`** (task 193's own invariant, re-asserted here);
8. **`Phase.voteWindow`** as a table of booleans over (phase × flag × candidate count) — 16 rows,
   not three hand-transcribed lines (323b-notes (g));
9. **a leaver's vote is released** at `Match.forget`, and the tally drops by one;
10. **`STAND_CHOICE_FIRST_SECONDS`**: `StandPick.mayAskNow` as a table over
    (entitled × secondsLeft), including `0` (today's game by identity) and the exact boundary;
11. **the leftover deal is a seeded shuffle** — `dealLine(..., roll)` with two rolls gives two
    different orders, both collision-free, both covering the free stands exactly once; and
    `roll == nil` is **the centre-out walk, value for value**.

### 13.3 Client spec — `tests/client/map_ui.spec.luau` (extended)

1. **`geometryFromGrid`** — 8 cell rectangles, 8 road polylines, the active cell's 15 stands in
   index order, `standKinds` naming ground vs tower, and `bounds == Grid.footprint()` plus the margin;
2. **`scopeFor`** as a pure table over (phase × voteWindow × pickWindow × isHunter) — world view in
   `Scoring` with the vote open, cell view in `Assigning` with the pick open, no map otherwise;
3. **a cell pad is at least 44 px on a 400 × 800 phone** — the §10.4 arithmetic, computed in the
   case from the canvas size and the bounds, **not** transcribed;
4. **a stand pad is NOT** on the cell view, and the `StandList` is built instead, scrolls, has 15
   rows and routes every row's `Activated` to `MapUi.tapStand`;
5. **the five marker states and the arrow** — `standStateFor` unchanged (323b's cases), plus
   `cellStateFor` over (driven × active × mine × votes);
6. **the cursor and the trigger are released at every exit** — the six exits of
   `stand-pick.md` §9.2 plus two new ones (the vote window closing, the map scope changing), each
   asserting `Cursor.isFree() == false` **by tag** (323b-notes (j): only the tag can answer, because
   `ReportPanel` holds the cursor free under its own);
7. **zero added per-tick cost** — `setCellStates` and `setStandStates` both return at once on an
   unmoved version, and `applyVisibility`'s pick/vote body is edge-triggered on a change
   (323b-notes (c), fixed here rather than inherited).

### 13.4 Live, in Karen's place — what a spec cannot answer

Everything in this list is measured in a Play session in the Forest Test, at the code commit, and
**printed**, because every one of them is a thing a number in DEV cannot know:

| What | How | Target |
|---|---|---|
| **every tree on the ground** | task 326's census script, same probe | **0** above ground, **0** spanning > 300 studs, of ~2,400 |
| stands refused by `Markers.groundFor` | the console line it already prints | **0 of 15**, per cell, all eight |
| towers refused | `Seats.takeLine()`'s own line | **0 of 5**, per cell |
| parts in `GridPlaces` | `Places.stats()` | **< 22,000** |
| plant / destroy time and peak frame | `Slice.stats()` | **< 4.0 s** each, `stepMsMax` **≤ 4.5 ms** |
| road paint calls and time | `Ground.paintRoads`' return | **≤ 300**, **< 4.0 s** |
| bots that cross the line | the drive's own count | **≥ 90 %** over a 1,430-stud walk |
| beater line arrival | `ForestTest.lineNorthAt` sampled | **275 s ± 5** |
| live animals at the peak, and server step | the new boar `stepMsAvg`/`stepMsMax` | **≤ 24**, **≤ 4.0 ms** avg / **8.0** peak |
| the worst cross-side stand separation | `Grid.separationStuds` per cell | **≥ 330**, worst **356** |

**Harness input (Task 6).** `tests/client/input_scenarios.txt` gains a scenario that replays a real
`M`, a real `MouseButton1` on a cell pad and a real one on a stand pad, with a client spec asserting
what `ContextActionService` and `UserInputService` delivered — the route task 323b used for the
stand pads.

**Screenshots (rule 5) — AND THIS IS A HARNESS FAULT, NOT A GAP.** `ESCALATE.md`, 2026-11-01:
`screen_capture` against the Forest Test **returns the same cached image for six different
camera/look pairs and for a confirmed character move**. Both routes were tried and both report
success in Luau. So for every task in §17, **rule 5 is met by Karen's eye and by nothing else**
until that is fixed. It is reported as a bug (rule 6), it is open decision **D-1**, and no task in
this split may claim a frame it could not take (rule 8).

---

## 14. Deltas to the designs this touches — exact text for the Builder to paste

The Architect script writes only this file, so each delta below is to be pasted into the named
document as part of the task that makes it true.

**`docs/design/drive-places.md`** — a new §19, *Superseded by the grid map (task 327)*:
> **§1.2 item 1 is overridden by `reviews/task-327/BRIEF.md` and `docs/design/grid-map.md` §3.2:**
> `ForestTest.Layout` gains four **optional** fields (`sides`, `beaterNorthStuds`, `fieldNorthStuds`,
> `cellOf`), all nil on `road`, `edge`, `ride` and `track`, so every number in §4.1 and §9 of this
> document still holds for those four. **§1.2 item 2 is unchanged** — `Places` still moves nothing in
> `OurForest`, `Session` or `LobbyAssets`, which is the boundary task 326 was refused at
> (`ESCALATE.md`, 2026-11-01). **§1.2 item 3 is unchanged and reaffirmed:** the grid writes no
> terrain height either. **§3's owner table gains `Workspace.GridPlaces` to the same owner,
> `ServerScriptService.Places`,** and `Places.build` now destroys **both** folders whichever world is
> live (grid-map §11.3). **The four places are superseded at task 327d but not deleted** (rule 7):
> their rows stay in `ForestTest.LAYOUTS` and are reachable by `DHForestLayout`.

**`docs/design/drive-layouts.md`** — a new §13:
> **The rotation is now a CYCLE OVER EIGHT WITH A VOTE** (task 327, D6). `ForestTest.nextLayout` is
> superseded by `ForestTest.nextCell(previous, driven, voted, roll)`: candidates are the cells not yet
> driven this cycle, a vote that is a candidate wins, a tie or no votes takes a **seeded** roll, and
> the cycle resets after all eight. §5's fixed cycle and §12.2's 7-bag stay as history, **marked
> superseded** — and §12.2's own stated reason, *"a layout she is never dealt is a layout she cannot
> judge"*, is what the driven-set exclusion delivers. **A forced drive still does not advance the
> cycle** (`chosen.cycle`, §5 invariant 3), and that invariant is re-asserted by
> `match_cell_vote.spec` case 7.

**`docs/design/stand-pick.md`** — a new §16:
> **Amendments for the grid map (task 327).** (1) **A-327-1:** the map has two scopes — the **world**
> view for the vote in `Scoring` and the **cell** view for the pick in `Assigning`;
> `MapUi.scopeFor(phase, voteWindow, pickWindow, isHunter)` is the one pure answer and `Hud` resolves
> it once. (2) **A-327-2:** the pick window has two sub-windows, read off `phaseEndsAt` — licence
> holders for `STAND_CHOICE_FIRST_SECONDS` (6), then everyone. `StandPick.mayAskNow` is the predicate
> and `REASON.TURN` the word; `STAND_CHOICE_FIRST_SECONDS = 0` is §3's game by identity. (3) the
> leftover deal is a **seeded shuffle** (`dealLine`'s sixth argument), not the centre-out walk —
> Karen's *"randomly trowen there"*. (4) `REASON.SEAT` becomes **unreachable** because towers stop
> being gated (grid-map §10.1); it is kept, marked, and driven by parameter. (5) **§5.2's *"Only
> claimants are moved"* and §12's `standsSettled` row are stale against the shipped code** and are
> corrected here, closing 323b-notes (h) and (j): the number is how many the pick **moved**, which is
> ≥ the claimants. (6) **§14's delta table gains the `drive.md` amendment** it is missing: this system
> **does** take a client remote. (7) **§10.1 must name `Flags.MAX_FLAGS`**, which no row can be added
> without. (8) **323c ships with this work**, as a **`ScrollingFrame`** of 15 rows — §9.5's 44-px
> arithmetic is redone for the cell view in grid-map §10.4 and the conclusion is unchanged.

**`docs/design/map-ui.md`** — a new §21:
> **The grid world's geometry (task 327).** `MapGeometry` gains four **optional** fields — `roads`
> (every road as a polyline), `cells` (id, bounds, driven, active, pushBearingDeg), `standKinds`
> (ground or tower, by index) and `activeCell`. **Absent is pre-327 behaviour**, the
> `stands` / `coinsOn` / `roleOverruled` idiom, so the DEV map and the four places draw exactly what
> they drew. `MapUi.geometryFromGrid(grid, cellId, cells)` is a third source beside
> `geometryFromForestTest` and `geometryFromMap`, and `geometryFor` dispatches on
> `world == "grid:v1"`. **§5.4's rule holds: a world that has stated nothing gets NO MAP**, never a
> blank panel. The **arrow** is `setPush`'s existing `facingOffsetPx`, drawn at the active cell's
> centre — no new drawing primitive. The **cell nodes** are `Cell%s` frames with a transparent
> `Hit` `TextButton` child, which is A-323-3's shape exactly, so there is still **no new input
> owner and no `UserInputService` reader**. §11's budget is unchanged: cells and roads are built once
> per world by `drawGeometry` and their states are edge-triggered (`setCellStates(states, version)`).
> §12's no-new-colour rule holds: a driven cell is `PINNED_TRANSPARENCY`, the active cell carries the
> map's own `RIM_COLOR` stroke, and my own vote is the `COLORS.arrow` diamond — **one orange mark on
> the map, still**.

**`docs/design/drive.md`** — a new section:
> **The vote (task 327).** The `Scoring` phase is also the **cell vote** window, `Phase.voteWindow`,
> unlengthened at `SCORE_SECONDS` 9. `MatchSnapshot` gains `votes`, `myVote`, `voteWindow` and
> `cells`; `src/shared/Drive/Remotes` gains one `RemoteEvent`, `CellVote`, carrying one string in and
> one `CellVerdict` out. **No new phase, no new clock, no new timestamp.** And the amendment
> `stand-pick.md` already owed this document: §9.1's and line 117's *"this system takes no client
> remote"* has been false since task 323a (`StandRequest`) and is now false twice.

**`docs/design/high-seats.md`** — a new section:
> **On the grid (task 327).** `HighSeats.STANDS` gains eight rows, keyed by **cell id** — which is
> what §3's *"keys its table by layout NAME for exactly this reason"* was built for. `capFor(15)` is
> 5 per cell, at least one per side, and which five is **measured in a Play session** by §6.2's own
> rule and instrument (task 327b), never chosen. **The entitlement gate is removed:** towers stop
> being bought (grid-map §10.1), so `dealLine`'s `entitled` is all-true and §5.2's double check
> becomes the single check at the pick. `dealLine` gains a **sixth** argument, `roll`, seeding the
> leftover order. The lane rule that keeps a tree out of a seat's footprint
> (`Places.LANE_STUDS >= HighSeats.footprintRadiusStuds()`) is **unchanged and still asserted**.

**`docs/design/bots.md`** — a new section:
> **On the grid (task 327).** `Bots.CONFIG.WALK_SPEED` goes **3.1 → 5.2**, derived
> (`cellDepthStuds / DRIVE.seconds`, grid-map §4.3), and `bots_lane.spec` holds the relation rather
> than the number. **This is task 251's measurement at a new depth, not a reversal of it.**
> `Fill.standsFree` is given **`Grid.mainStandCount(cellId)` (7)**, not the cell's 15, so the bot
> roster does not grow and no rig ever stands on a flank. **A 1,430-stud lane walk through planted
> wood has never been measured in this place** — the design makes *bots that cross the line* a target
> with a number (≥ 90 %) and puts it in the live-only list.

**`docs/design/shop.md`** — a new section:
> **`access.highseat` becomes STAND CHOICE (task 327, D7).** Karen, 2026-11-01: *"Stand choise same
> license we have instead tower license there will be choose stand"*. Label, blurb and grant change;
> **the id does not move** — it is the key a saved purchase is stored under, and the rule is this
> file's own, written for RED STAG CARD → DEER LICENCE. `Shop.grantsHighSeat` →
> `Shop.grantsStandChoice`, keeping its **nil → true** rule and the outage cost it already names.
> Price (600) and hunts (5) do not move; `Shop.ORDER`'s position does not move.

**`docs/design/map-generator.md`** — a new section:
> **The grid world does not use the generator, and this is why (task 327).** `grid:v1`'s relief is
> **measured** from the Forest Test's bought terrain, not generated: 13.41 M sq studs is **2.9× this
> map's area**, which at §5.2's own per-tile estimate is ~750 tiles and ~50 minutes of edit-time
> build in a place this pipeline has never run in, and `Config.INCLUDE.relief` is `false` even in
> DEV. What **is** borrowed is the **step/slice shape** (`src/server/Places/Slice.luau`) and the
> **per-cell seed** idea. §17's switch recipe is followed exactly for `Map.WORLD_BY_PLACE` →
> `"grid:v1"`, and §12.2's one-id-table rule is untouched: the grid adds no asset id.

---

## 15. Open decisions

### Karen (feel and design)

**K-1. The upwind road carries no stands.** Her words are *"you can select all around rectangle where
to stand"*; this design gives **three sides of four**, because the beaters have to step off from
somewhere and a hunter standing on their line is a hunter in the drive. Over a cycle she does stand
on every road in the world. **Does she want a far-side stand anyway, knowing it will see very
little?** One row in `Sides` if so, and §7's inequality already clears it (the far road is 1,430
studs from the main line).

**K-2. The cell is 1070 × 1430 studs and the beaters now walk at 5.2 studs/s.** The drive is 2.5×
deeper than the one she has played. **Does a five-minute drive across that cell feel right, or should
the cell shrink to 930 studs deep so the walk stays at today's 3.1?** Both are one number
(`Grid.CONFIG.cellDepthStuds` and `beaterWalkStudsPerSecond`), and §4.3 has the table.

**K-3. The vote is nine seconds** — the whole of the results scene. **Long enough to read eight cells
and tap one?** If not, `SCORE_SECONDS` is her row and it moves both.

**K-4. Fifteen stands per cell.** Seven on the line, four on each flank. **Too many icons on the
map?** Five / three / three is 11 and is one row.

**K-5. Towers stop being bought.** Reading *"instead tower license there will be choose stand"* as
*the card now buys the pick, and a tower is just a stand you may pick*. **Is that what she meant, or
should a tower still need the card as well?** The gate is kept in the code, marked unreachable, so
turning it back on is one line.

**K-6. The roads are painted bare earth** (`Enum.Material.Ground`, 18 studs / 5 m), because she said
*"road"* and that is the one surface her reference frames demand. **Or left as grass rides**
(`Places.PLANS.ride` is exactly that and she accepted it)? One row, and it saves ~284 terrain calls.

### Director (scope)

**D-1. THE FRAME FAULT BLOCKS RULE 5 ON EVERY TASK IN THIS SPLIT.** `ESCALATE.md`, 2026-11-01:
`screen_capture` against the Forest Test returns one cached image for six cameras. Either that is
fixed before 327a, or every task here is accepted on Karen's eye alone and says so. **This design
cannot close it and will not pretend to.**

**D-2. The grid's ORIGIN is an output of 327a's survey, not of this document.** Her terrain is known
to reach at least x −620…5,355 and z −4,350…+3,503 (the four places' plots, the lobby, the range, and
a `Session` tree at (−620, 3503)), but no 4,490 × 2,986-stud block has been measured for coverage,
for parts or for relief. If the survey finds no clear block, **the cell size shrinks** — which is why
it is CONFIG. The Director decides between a smaller cell and a new place.

**D-3. `Flags.MAX_FLAGS` 23 → 25**, for `GRID_PREVIEW` and `CELL_VOTE`. The cap is at its limit
today. The Director may prefer to **retire two expired rows** instead (task 82b is queued for exactly
this).

**D-4. The four places are superseded at 327d.** This design keeps their rows, archives
`Places.PLANS` and `Workspace.DrivePlaces` under `backups/` with a note, and leaves them reachable by
`DHForestLayout` as the rollback (rule 7). **Confirm that, or say they go.**

**D-5. The relief is measured, not generated** (§4.4). If the Director wants it generated, that is a
`WriteVoxels` programme over 2.9× the DEV map's area that **nobody has costed in this place** — its
own task, ahead of 327c, and the `relief` row's shape does not change either way.

**D-6. The two-player gate.** 327d, 327e and 327g touch `src/server/Match/` and
`src/shared/Drive/`, which are in `TWO_PLAYER_PATHS`, so each needs a `[harness2]` line and one human
click. **327a, b, c, f and h touch neither** and need the one-player line only — and `src/shared/Grid`,
`src/shared/Places` and `src/server/Places/` must be added to `BLAST_RADIUS` / `SCOPE_SPECS` as the
`map` scope so `test --scope auto` can resolve them (`tools/studio_mcp.py selftest` fails otherwise).

---

## 16. Not verified (no Studio, no network in an Architect run)

1. **Every external link in §12 was not fetched.** The Architect has Read, Grep and Glob. Licences
   and maintenance statuses are from knowledge and must be checked when the research note is written
   (rule 1).
2. **No number in §4 was measured in Karen's place by me.** The cell size, the origin, the relief
   rows and the tower choices are all 327a/327b survey outputs. What I have used is the measurements
   already in the repo: `drive-places.md` BRIEF M4–M9, task 218's 25-stand survey, task 326's census,
   task 162's bot walk.
3. **The terrain-material discard on Play-stop is not re-verified**, by me or by
   `drive-places.md` §7.2, which says the same. §11.3 step 3 rests on it.
4. **The 0.45 ms/model planting rate is `drive-places.md`'s M9** (200 models in 0.09 s), not a
   measurement of this planter at this scale. Every budget in §8.3 derives from it, so §13.4 measures
   it again rather than assuming it.
5. **The boar runtime has no `stepMsAvg` / `stepMsMax` today.** §9.2 asks for them, so the 4 ms
   target has no instrument until 327h builds one.
6. **Roblox streaming's behaviour over a 4,490-stud world is unasserted and unassertable** — four of
   `Map.STREAMING`'s five properties cannot be read from Luau (§12 source F). Whether the far end of
   the world streams in acceptably is a thing to look at, not to test.
7. **The 1,430-stud bot lane walk is unmeasured in this place** (§4.3, §9.2).

---

## 17. The task split (brief §3.7)

Each is one task, small, testable, and committed with a research note where rule 1 asks for one.
**The research note comes first:** `docs/research/2026-11-01-the-grid-map.md`, indexed in
`docs/research/INDEX.md`, before any code (rule 1).

| # | Task | Days | Gate | Karen sees |
|---|---|---|---|---|
| **327a** | **THE GRID, SURVEYED AND WALKABLE.** `src/shared/Grid/init.luau` (CONFIG, the 8 cell rows, `boundsOf`, `roads`, `footprint`, `seedFor`, `standPosition`, `standWalk`, `separationStuds`); the **survey** — terrain coverage, non-terrain parts and relief on a 20-stud lattice over the candidate footprint, written into the eight `relief` rows as **measured** values; `Ground.paintRoads` and corner stakes, in slices, behind `GRID_PREVIEW` (OFF). `ForestTest.LAYOUTS` is **not** touched. `tests/server/grid.spec.luau` cases 1, 3, 5, 6, 9, 11, 19, 22 | **1.0** | one-player | **YES: she walks the eight cells' roads and stands at a corner.** The world's shape, on the ground, with nothing else changed |
| **327b** | **THE STANDS AND THE TOWERS.** `Layout`'s four optional fields; `Grid.layoutFor`; `ForestTest.standPosition` / `beaterNorthStuds` / `boundsOf` delegating; `Markers.Set.linePosts` and the four call sites (**§6.4**); `hunterStandX`'s clamp; the per-cell **tower measurement** in a Play session (gain / spread / relief, task 218's rule) → `HighSeats.STANDS`' eight rows. One cell's markers and towers built under the preview. Cases 2, 4, 7, 8, 10 | **1.0** | one-player | **YES: she stands on all 15 stands of one cell and climbs its towers** |
| **327c** | **THE CELL'S WOOD.** `Places.CELL_PLANS`' eight recipes with their zones; `Places.plantCell`; `src/server/Places/Slice.luau`; the destroy-then-plant order; nearest-the-line-first; `GROUND_IGNORE` gains `GridPlaces`; the census. Cases 12–18, 20 | **1.5** | one-player | **YES: she looks into a dressed cell from a stand and from a tower, and across a road into the skirt** |
| **327d** | **THE SWITCH.** `Map.WORLD_BY_PLACE` → `"grid:v1"`; `ForestTest.LAYOUTS` gains the eight rows and `LAYOUT_ORDER` becomes the eight ids; `ForestTestBoot` wires `Grid` through the seams that exist; `Places.build` destroys **both** folders; the four places archived (rule 7). `GRID_PREVIEW` retired. Case 21 | **1.0** | **one + `test2`** | **YES: a whole 300 s drive in one cell** |
| **327e** | **THE VOTE.** `src/server/Match/CellVote.luau`; `Phase.voteWindow`; the `CellVote` remote and the four snapshot fields; `ForestTest.nextCell` and `layoutForDrive`'s third argument; the client's `requestCellVote` / `cellVoteTable` / `myVote`; `CELL_VOTE` (OFF) and `MAX_FLAGS` 23 → 25. `match_cell_vote.spec` cases 1–9 | **1.0** | **one + `test2`** | not yet (no pixel) |
| **327f** | **THE MAP.** `geometryFromGrid`; `scopeFor`; the world view, the cell highlight, the drive arrow, the `Cell%s` + `Hit` pads, the vote tally and my-vote mark, ground vs tower stand icons; **323c as a `ScrollingFrame`**; the two new cursor/trigger exits. `map_ui.spec` cases 1–7 | **1.0** | one-player | **YES: she votes on the map and picks her stand on it, on desktop and on her phone** |
| **327g** | **STAND CHOICE.** the shop row's label / blurb / grant and `grantsStandChoice`; `StandPick.mayAskNow`, `REASON.TURN` and `ORDER`; `dealLine`'s sixth argument and sweep B's seeded shuffle; `STAND_CHOICE_FIRST_SECONDS` 6. `match_cell_vote.spec` cases 10, 11 | **0.5** | **one + `test2`** | **YES: she buys the card and picks before everyone else** |
| **327h** | **THE ANIMALS.** the eight `animals` rows (density, `startDepth` fractions, `routeBias`, `restZones`); `releaseLine` / `slotAt` / `restSpot` handed the cell's numbers; **`stepMsAvg` / `stepMsMax` on the boar runtime**; the live budget measured over a full drive in three cells | **1.0** | one-player | **YES: three different cells' drives, and she says whether they feel different** |

**Total ≈ 9.0 days.** Three tasks need the two-player run and one human click; five do not.
**327a gives her the empty world with its roads and its relief and nothing else**, which is the
brief's first requirement.
