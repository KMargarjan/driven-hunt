# Design: drive-places — four real driven-hunt places, dressed from code

Task 193. Architect. Input: `reviews/task-193/BRIEF.md` (which overrides anything older in `docs/`,
`TASKS.md` or an earlier design) and `docs/research/2026-10-17-four-driven-hunt-places.md` (below:
"the note").

KAREN, 2026-10-15 ~17:30, verbatim:

> *"then we need make at least 4 hunting places / 1. has to be road like we did previuosly / 2. next
> one has to be forest ending then field and then again forest / 3. next one has to be just cut tree
> line and forest on both sides / 4. has to be again forest road and forests on side / it has to be
> like real life hunting situations in driven hunt / use same trees mix them make like in real life
> and what is acceptable for us / so you goal fix terrain make 4 hunting places where each time
> person will be in new place when is hunter then loop it again"*

and *"be sure you do it properly not fake it or broken"*.

This document designs **one system**: the **dressing** of a drive place — what stands around the
hunters' line and what the ground under the line is made of — plus the **rotation** that sends each
drive to the next place. It designs no new drive, no new phase, no new axis, no animal behaviour and
no terrain carving.

**It is written against code that already exists.** Commit `a23838b` ("Task 193: WORK IN PROGRESS,
paused by the Director for Karen's look (not reviewed, not gated)") already contains
`src/shared/Places/init.luau`, `src/server/Places/init.luau`, `tests/server/places.spec.luau`, the
fourth layout row in `src/shared/ForestTest/init.luau` and the rotation in
`src/server/ForestTest/init.luau`. Where that code already matches this design I say so and name the
symbol; where it does not, §10 lists the corrections with evidence. **Nothing in §10 is a new
feature: each item is a hole the next task would inherit.**

Deltas this task forces on `docs/design/drive-layouts.md`, `forest-drive.md` and `map-ui.md` are in
§15. The two catch-up deltas the brief §6 asks for (`lobby.md`, `drive.md`) are in §16 — as **exact
text for the Builder to paste**, because the Architect script writes only this one file.

---

## 1. What it must do, and what it must not do

### 1.1 Must do

| Must | Why |
|---|---|
| Make each of Karen's four places read, **from a hunter's eye at ground level**, as the kind of place her reference frame shows | Her words, and the whole of the task. A number cannot answer it (rule 5) |
| Dress places 2, 3 and 4 **from code in `src/`, at run time**, out of the templates this place already holds | BRIEF D6, D7. `PROJECT_CONTEXT.md`: *"Everything lived in the cloud place file: no diffs, no history, no rollback"* |
| Keep **place 1 (`road`) at today's numbers, to the stud**, and dress it with **nothing** | BRIEF D3. `tests/server/places.spec.luau` asserts `Plan.planFor("road") == nil` |
| Deal the places **in Karen's order, 1 → 2 → 3 → 4 → 1**, one per drive | BRIEF D2, Karen: *"each time person will be in new place when is hunter then loop it again"* |
| Put **every** planted tree on the ground through `src/shared/TreeGround` — the trunk/root junction at or below the **lowest** ground under the trunk's own footprint | BRIEF D4, lesson L-086, standing rule E. One copy of the arithmetic, and it already exists |
| Keep **no tree in a shooting lane and no stand inside a trunk**, as a rule the planner enforces and a spec asserts over **every** planting | the dispatch, and the note §1 item 3 |
| Be a **pure function of (layout, seed)**: same commit, same forest | so a frame Karen judges can be rebuilt and a defect bisected |
| Plant on **clean ground that was measured**, never by cutting the existing wood | BRIEF M7, M8, rule 7 |
| Set `CanQuery = false` on every cloned part that does not collide, and **leave trunks queryable and collidable** | BRIEF D9, lesson L-060. Task 149 lost 4 of 5 shots in leaves; you must not shoot through a trunk |
| Say out loud, once, what it planted and what it refused | rule 8. The counts are what *"not fake it or broken"* is checked against |
| Do **nothing at all** in the DEV place, loudly, once | BRIEF item 8. The harness runs in DEV |

### 1.2 Must not

1. **Must not add a field to the `Layout` record.** `src/shared/ForestTest/init.luau` stays what task
   157 made it — the one world-**geometry** seam. The dressing is a **second system that READS a
   layout** (`src/shared/Places`), and the seam between them is one direction only: `Places` requires
   `ForestTest`; `ForestTest` never requires `Places`. (Already true: `src/shared/Places/init.luau`
   requires `ReplicatedStorage.ForestTest` and nothing in `src/shared/ForestTest/init.luau` mentions
   `Places`.)
2. **Must not move, re-parent, scale, re-colour or destroy anything in `Workspace.OurForest`,
   `Workspace.Session` or `Workspace.LobbyAssets`.** Clone only (BRIEF D7, rule 7). The one thing this
   system may destroy is **its own** folder, `Workspace.DrivePlaces`.
3. **Must not carve terrain, and must not change terrain HEIGHT anywhere.** Painting a surface
   material is in scope (§7); `Terrain:FillBlock`, `WriteVoxels` and any height write are not. The
   measured relief is 29–37 studs along a 700-stud stand line (BRIEF M8), and a flat slab over that
   is the floating-geometry failure `Lobby.Field`'s header already records.
4. **Must not invent a y.** `Places.Planting` carries `x`, `z`, `scale`, `yaw` and **no `y`** — the
   ground is the one thing only the world can answer (`src/shared/Places/init.luau`, the `Planting`
   type comment). A second ground-fit implementation is forbidden by BRIEF D4.
5. **Must not write a second copy of the claw arithmetic, the footprint grid or the settle rule.**
   `src/shared/TreeGround` is taken whole.
6. **Must not touch** `src/server/Match/`, `src/client/Match/` or `src/shared/Drive/` — those are
   `TWO_PLAYER_PATHS` and this task is gated on the one-player run (BRIEF §7).
7. **Must not plant a second answer to "where is the ground".** `ForestTest.terrainYAt` and
   `ForestTest.groundAt` stay the only two readings, and the planter is **given** one (§6.2).
8. **Must not produce a silent wrong answer.** A template that is not in this place, ground the world
   cannot answer, a footprint across a step: each is **counted and printed**, never a tree left in the
   air and never a crash.
9. **Must not build the beater ground of task 194**, a crop field, an autumn canopy, a raised stand,
   or a drive on another axis (note §4, BRIEF §7).

---

## 2. The pattern adopted, and why

**A PURE PLAN, THEN A THIN PLANT** (BRIEF D8, the note §3). The planner answers *what stands where* —
position, species, scale, yaw — from a layout and a seed, with no Instance, no service and no
raycast. The planter is the only thing that touches `Workspace`: it clones, measures the terrain under
the trunk's own footprint, and hands the measurements to `TreeGround`. This is task 199's own split,
and `docs/research/2026-10-17-forest-trees-on-the-ground.md` names the reason: when the arithmetic and
the measuring were one lump, *"neither could be checked alone"*, and the lobby's ground-fit was wrong
for rounds at a time.

**A JITTERED GRID WITH BRIDSON'S GRID NEIGHBOUR TEST, not his active list** (source A, §17). One
candidate per cell, displaced inside its cell, **dropped when it is closer than `minGapStuds` to a
tree already placed in its own or an adjacent cell**. What that buys over Bridson's loop is what we
actually need: the plan is a pure function of `(layout, seed)`, the tree count is bounded before
anything runs, and cell (i, j) is the same tree every time so a spec can assert one. What it costs is
a slightly more regular scatter than true blue noise. **The neighbour test is the half that is
currently missing from the code — §10.3.**

**FOUR DEPTH BANDS PER EDGE, not one density** (source D, extended). Measured outward from the lane
edge: `herb` (ferns, no trees) → `shrub` (young growth) → `wood` (full forest) → `deep` (the same
forest at a coarser grid, out to where the drive actually happens). Source D gives the first three as
the real recipe for an edge that is not a wall — `Krautsaum` 5–10 m, `Strauchmantel` 5–10 m, then the
`Baummantel`. The fourth is this world's own arithmetic and §10.2 is why it has to exist.

**THE STRIP IS A SUBTRACTION, NOT A SHAPE.** Nothing is planted within `halfStripStuds + LANE_STUDS`
of the line's own z at that x. One rule keeps every shooting lane clear, rather than a hand-placed row
of trees that a later tweak could walk inward. (Already built: `Places.inLane` and the
`if not Places.inLane(...)` guard in `Places.layer`.)

**THE GROUND IS PAINTED, NEVER BUILT** (§7). The strip's surface is a terrain **material** write
inside the running session — `Terrain:ReplaceMaterial`, which changes material without touching
height — so a rolling ride stays a rolling ride. The precedent and the discipline are
`src/server/Lobby/Field.luau`: *"a spec hands in a fake with a recording `FillBlock`, so no spec in
the DEV place can write DEV's terrain, ever"*.

**ONE WRITER, AND IT IS A SEVENTH OWNER** (rule 3). `ServerScriptService.Places` writes
`Workspace.DrivePlaces` and the strip materials, and nothing else writes either. It requires no owner
and no owner requires it; the boot wires it.

What is borrowed from inside this repo, said plainly (rule 2): `TreeGround` whole; `Lobby.Build`'s
*shape* for planting from code (its code is not reused — it is documented as the one writer of every
part in `Workspace.Lobby`, and reaching into it is the owner collision rule 3 exists to stop);
`Lobby.Field`'s injected-terrain discipline; `ForestTest.Markers.build`'s destroy-and-rebuild;
`ForestTest`'s trailing-optional-layout parameter shape.

---

## 3. Ownership — one writer each, named

| System | Owner (the only writer) | Location on disk |
|---|---|---|
| **What a place is dressed with** (species, bands, spacings, seeds) | **nobody at run time**: frozen data | `src/shared/Places/init.luau` — `Places.PLANS`, `Places.SPECIES` |
| **Where every planted thing goes** (the plan) | **nobody at run time**: a pure function | `src/shared/Places/init.luau` — `Places.plant`, `Places.layer` |
| **`Workspace.DrivePlaces` and every instance in it** | **`ServerScriptService.Places`** | `src/server/Places/init.luau` — `Places.build`, `Places.plantOne` |
| **The strip's terrain MATERIAL** (and nothing else about terrain) | **`ServerScriptService.Places`** | `src/server/Places/Ground.luau` (NEW, §7) |
| **Where a tree meets the ground** (arithmetic only) | **nobody at run time**: pure | `src/shared/TreeGround/init.luau` — unchanged |
| **Which layout is live, and the rotation** | **`ServerScriptService.ForestTest`** — `chosen.*` | `src/server/ForestTest/init.luau` — `layoutForDrive`, `publishLayout` |
| **The layout table** (where the line is, how many stands) | **nobody at run time**: frozen data | `src/shared/ForestTest/init.luau` — `ForestTest.LAYOUTS`, `LAYOUT_ORDER` |
| **The stand/beater marker parts** | **`ServerScriptService.ForestTest.Markers`** — unchanged | `src/server/ForestTest/Markers.luau` |
| **Where the ground is** | **two readers, both `ServerScriptService.ForestTest`'s**: `terrainYAt` (Terrain only) and `Data.groundAt` (the cross-check) | `src/server/ForestTest/init.luau`, `src/shared/ForestTest/init.luau` |
| **The wiring** | **`src/server/ForestTestBoot.server.luau`** — boot line only; owns nothing, decides nothing | — |

Rows for `GAME_DESIGN.md`'s *System owners* table (rule 3):

```
| the four places' planted forest and strip surface | ServerScriptService.Places        | src/server/Places/   |
| what dresses a place (the plan, pure)             | ReplicatedStorage.Places (data)   | src/shared/Places/   |
```

**The client is told nothing new.** It already reads one string (`ForestTest.Live.Layout`) and draws
the map from it. The dressing publishes no attribute, no remote and no replica field: a tree is a
replicated Instance and that is the whole of what a client needs.

---

## 4. The four places

### 4.1 The layouts (task 179's record; this task adds the fourth row)

| | 1 `road` | 2 `edge` | 3 `ride` | 4 `track` |
|---|---|---|---|---|
| label | Road | Field edge | Cut line | Forest road |
| `centre` | (3030, 138, −2097) | (3480, 202, −3400) | (1500, 146, −4100) | (4800, 158, −4100) |
| `amplitudeStuds` | 30 | 0 | 0 | 0 |
| stands × spacing | 9 × 150 | 6 × 150 | 5 × 130 | 6 × 130 |
| stand span (x) | 2430…3630 | 3105…3855 | 1240…1760 | 4475…5125 |
| `halfSpanStuds` | 800 | 435 | 320 | 385 |
| `exitZOf` | −2377 | −3650 | −4350 | −4350 |
| beaters form up at z | −1517 | −2820 (inside the existing wood) | −3520 (inside the planted belt, §10.2) | −3520 (inside the planted belt, §10.2) |
| dressed by this task | **nothing** | its own edge only | both belts | both belts |

All four rows are already in `ForestTest.LAYOUTS` at these numbers, and `centre.Y` is the mean of each
layout's own **measured** stand terrain (BRIEF §4; the per-stand readings are in the table's own
comments). `centre.Y` is a fallback ground only — every production reader re-measures (§8).

**One correction to the brief, with the arithmetic.** BRIEF §4 and the note call the field at place 2
*504 studs = 141 m*. It is **500 studs = 140 m**: the wood's southern face was measured at z −2900
across the whole stand span (BRIEF M5) and the line is at z −3400. Still inside Karen's 80–150 m, and
it is the number `places.spec`'s *"leaves 141 m of open field"* case actually computes
(`(treeLine - layout.centre.Z) * 0.28`). **Rename that case to "140 m" and keep the 80–150 bound.**

### 4.2 The dressing, as data (BRIEF item 9)

One row per layout name in `Places.PLANS`; a layout with no row is dressed with nothing. Every number
below is a dial in a data table, not code.

| | 2 `edge` | 3 `ride` | 4 `track` |
|---|---|---|---|
| reference frame | karen-ref-6 | karen-ref-5 | karen-ref-1 |
| `halfStripStuds` | 30 | 32 | 9 |
| **tree-free width** (`2 × (halfStrip + 12)`) | 84 studs / 23.5 m | **88 studs / 24.6 m** | **42 studs / 11.8 m** |
| painted surface width | none (§7.3) | none — grass ride (ref-5) | **18 studs / 5 m**, `Ground` |
| `beltStuds` (south) | 190 | 230 | 230 |
| `northBeltStuds` | **0** | **640** (§10.2) | **640** (§10.2) |
| `bands` { herb, shrub, wood } from the lane edge | 36 / 72 / 190 | 30 / 80 / 230 | 14 / 50 / 230 |
| `spacingStuds` / `deepSpacingStuds` | 34 / — | 30 / 60 | 28 / 60 |
| `fernSpacing` | 26 | 24 | 22 |
| `minGapStuds` (§10.3) | 19 | 17 | 16 |
| `herb` mix | fern | fern | fern |
| `shrub` mix | fieldOak 5, aspen 4, birch 1 | young 8, birch 2 | young 9, birch 1 |
| `wood` / `deep` mix | fieldOak 5, aspen 3, birch 2 | conifer 9, birch 4, aspen 4, oak 3 | conifer 10, birch 6, aspen 2, oak 2 |
| `shrubScale` | 0.18–0.30 | 0.25–0.45 | 0.22–0.40 |
| `woodScale` | 0.85–1.15 | 0.8–1.2 | 0.8–1.2 |
| `seed` | 1932 | 1933 | 1934 |

The species groups (`Places.SPECIES`) are the names counted in `Workspace.OurForest` on 2026-10-17
(BRIEF M2): `conifer` (7 spruce), `young` (4 larch — the **smallest** trees this world has, 26–96
studs, which is why young growth is a larch and not a scaled spruce: a spruce at sapling scale has a
one-stud trunk), `birch` (8), `oak` / `fieldOak` (forest-form vs open-grown), `aspen` (4), `fern`
(5 — **our bracken**). `Model:ScaleTo` is the only size control (BRIEF M3).

**What each place is, in one sentence each:**

* **`edge`** — the hunters stand **in** their own hedge at z −3400 looking north over 140 m of open
  field at the existing wood's straight southern face; the beaters push **out of those trees** into
  the open. `northBeltStuds = 0` is the whole point, not an omission: plant one tree north of the line
  and the field stops being a field. (`places.spec` asserts zero plantings north of it.)
* **`ride`** — a straight cut line on the flattest clean plot in the world (x 1500, z −4100: **zero**
  non-terrain parts, 29 studs of relief along its own line, BRIEF M8), forest both sides, a band of
  young pines at the edge, taller mixed wood behind. The exit line (z −4350) is **24 studs inside the
  south belt**, so an animal that gets through disappears into cover rather than into open grass.
* **`track`** — a narrow dirt double track on the other zero-part plot (x 4800, z −4100), forest
  **close**: the first trunk is 21 studs (5.9 m) from the centre line, and the painted track is 5 m.
  Straight where place 1 curves, which is the whole difference a hunter reads between the two roads.

**Honest gaps, stated rather than faked** (note §4): we have **no crop model**, so place 2's field is
mown grass and not Karen's golden waist-high maize; our 61 models are in **summer leaf** and every
reference frame is late autumn; the wheel ruts are two material strips, not two trenches (terrain
resolution is 4 studs = 1.1 m). The belts' **floor** is this world's existing grass, not brown leaf
litter — §7.3 and open decision K2.

---

## 5. The rotation (BRIEF item 4)

**`Data.nextLayout`'s signature changes and the bag is gone.** This is the one task-179 decision Karen
herself reversed.

```luau
-- src/shared/ForestTest/init.luau. PURE: no roll, no bag, no state.
function ForestTest.nextLayout(previous: string?): string   -- was (previous, bag, roll) -> (string, bag)
```

Already built exactly so, and `ForestTest.LAYOUT_ORDER` is now **the cycle itself**:
`{ "road", "edge", "ride", "track" }`.

**What happens to the bag's documented sources.** `drive-layouts.md` §12.2 (TetrisWiki *Random
Generator*) and §12.3 (the DevForum map-rotation threads) stay in that document as **history, marked
superseded** — the bag's own stated reason, *"a layout she is never dealt is a layout she cannot
judge"*, is what a rotation does **better**: every place exactly once per cycle, in an order she can
predict. What a rotation loses is also written down in `nextLayout`'s header: it is predictable, which
is a cost for a shipped game and an advantage for a playtest world. If it ever ships to players the
fix is a bag **per cycle** (shuffle four, deal four, reshuffle) — the 7-bag again.

**The invariants a spec asserts** (`tests/server/forest_stand.spec.luau`, already written at lines
~213–244):

1. `nextLayout` walked `2 × #LAYOUT_ORDER` times visits `road, edge, ride, track, road, edge, …` —
   four drives in a row are the four places and the fifth is place 1 again;
2. `nextLayout(nil)` and `nextLayout("a name nobody knows")` both answer `LAYOUT_ORDER[1]`, so a
   drive is never layout-less;
3. **a forced drive does not advance the cycle.** `ForestTest.layoutForDrive` keys the step on
   `chosen.rotated`, not on `chosen.drive`, and the override branch never sets it
   (`src/server/ForestTest/init.luau`, `layoutForDrive`). So `DHForestLayout` set for three drives and
   then cleared resumes at exactly the next place;
4. the **first** drive of a session is `LAYOUT_ORDER[1]` and not the one after the default — which is
   what `chosen.rotated` exists for, and its own comment says so.

`ForestTest.stats()` reports `layout`, `layoutSource` (`"rotation"` / `"override"` / `"default"`) and
`layoutNext`. A forced drive reported as a rotated one is the failure that line prevents.

---

## 6. The interface (BRIEF item 3)

### 6.1 `ReplicatedStorage.Places` — the planner. PURE.

```luau
export type Planting = {
    model: string,  -- a template's name under one of TEMPLATE_SOURCES
    x: number, z: number,          -- world studs. NO y: the ground is the world's to answer
    scale: number,                 -- Model:ScaleTo; 1 is the template's own size
    yaw: number,                   -- radians about Y
    band: "herb" | "shrub" | "wood" | "deep",
    side: number,                  -- -1 south of the line, +1 north
}

Places.LANE_STUDS   = 12          -- == ForestTest.PICK.standRadiusStuds, EXACTLY (§10.4)
Places.JITTER       = 0.8         -- fraction of a cell
Places.FOLDER       = "DrivePlaces"   -- NEW here, so the shared side names it once (§10.1)
Places.SPECIES      : frozen      -- group -> { model name }
Places.PLANS        : frozen      -- layout name -> plan (§4.2)

Places.planFor(layoutName: string?): Plan?            -- nil for `road`, and that nil is asserted
Places.inLane(x, z, layout, plan): boolean            -- the ONE lane definition
Places.bandAt(distanceFromLaneEdge: number, plan): string?
Places.speciesFrom(rows, roll: number): string        -- roll in [0,1)
Places.plant(layout, plan): { Planting }              -- the whole list, in order
Places.layer(layout, plan, rng, minX, maxX, spacing, floor): { Planting }
Places.capacity(layout, plan): number                 -- the bound, known before anything runs
Places.plotOf(layout, plan): { minX, maxX }           -- NEW (§10.5): the SURVEYED x range
Places.surfaceRegions(layout, plan, loY, hiY): { { at: CFrame, size: Vector3 } }   -- NEW (§7)
```

**What the planner decides:** everything about *what stands where*. **What the planter is allowed to
decide: nothing.** It clones what the plan names, at the x and z the plan names, at the scale and yaw
the plan names. Its only freedom is the two refusals the world forces on it — no ground, and a
footprint across a step — and both are **counted**.

### 6.2 `ServerScriptService.Places` — the planter. The one writer of `Workspace.DrivePlaces`.

```luau
Places.FOLDER            = Plan.FOLDER      -- read from the shared side, not restated (§10.1)
Places.TEMPLATE_SOURCES  = { "OurForest", "LobbyAssets.Trees", "Session" }
Places.CLAW_FRACTION     : frozen           -- the five non-zero fractions measured by
                                            -- tools/forest_ground.py species (tools/forest_claws.json)
Places.INVISIBLE_AT      = 0.95

Places.boxOf(part: BasePart): TreeGround.Box
Places.clawFor(model: string): number
Places.trunkBox(model: Model): (TreeGround.Box?, TreeGround.Box?)   -- (trunk footprint, whole)
Places.groundsUnder(box, groundAt: (number, number) -> number?): { number }
Places.quieten(model: Model): number                               -- D9; returns how many it changed
Places.templates(world: Instance?): { Instance }
Places.plantOne(item, template, parent, groundAt): (Model?, string)
Places.build(groundAt: ((number, number) -> number?)?, world: Instance?, terrain: any?): Report
Places.stats(world: Instance?): { [string]: any }
```

`Report` is `{ places, planted, skipped, cliff, missing, painted, seconds, reason? }`.

**The order inside `plantOne` is load-bearing and is not cosmetic:** scale **first**, then yaw and a
provisional pivot **above** the rough ground, then measure the trunk footprint, then settle. `ScaleTo`
moves every part, so a tree measured before it was scaled is measured at the wrong size; and the claw
fraction is a fraction of **height** precisely so it survives that step. The provisional pivot is
deliberately high so that `TreeGround.decide` — which **only ever sinks** a tree — is always offered a
drop. (All of this is already written and commented in `src/server/Places/init.luau`.)

**`groundAt` and `world` and `terrain` are arguments, never `Workspace` reached for inside a spec's
reach.** That is `Lobby.Field`'s discipline and it is why `places.spec` can drive the whole planter
over a fake hillside in the DEV place.

**The reader the boot hands it is `ForestTest.terrainYAt` — Terrain only — and not
`ForestTest.groundAt`.** §10.1 is the reason, and it is a correction to the code as it stands.

### 6.3 `src/server/Places/Ground.luau` — the strip surface (NEW, §7)

```luau
Ground.RESOLUTION        = 4                     -- the engine's terrain voxel, and the only legal value
Ground.CHUNK_STUDS       = 200                   -- one ReplaceMaterial call per chunk
Ground.SOURCE_MATERIALS  = { Enum.Material.Grass, Enum.Material.LeafyGrass }
Ground.Y_PAD_STUDS       = 10

Ground.yBandOf(layout, plan, terrainYAt): (number?, number?)   -- measured along the strip, both ends
Ground.paint(terrain: any, layout, plan, terrainYAt): number   -- returns the call count; 0 for a plan
                                                               -- with no `surface` row
```

`Ground.paint` is the **only** terrain call in this system and it is `Terrain:ReplaceMaterial`, which
changes material and **never height**. `terrain` is injected, so no spec can paint DEV's terrain.

### 6.4 `src/server/ForestTestBoot.server.luau` — the wiring, in order

```luau
local Places = require(ServerScriptService:WaitForChild("Places"))   -- the seventh owner
…
-- THE FOUR PLACES, PLANTED ONCE, BEFORE THE BOARS AND BEFORE THE DRIVE.
local planted = Places.build(ForestTest.terrainYAt, Workspace, Workspace.Terrain)
print("[ForestTestBoot] places: …")        -- the counts line, §11.4
```

**Before the boars and before `Match.start`**, and the reason is in the boot's own comment: a boar
released into a place whose wood arrived afterwards would have pathfound over ground that then grew
trees. The navmesh rebuilds in the background (`tools/mapgen.py`'s own measurement: a wall across a
corridor still answered `PathStatus.Success` after one second and `NoPath` after five), and the first
wave is a minute away.

`Places` requires no owner and no owner requires it. The boot is the only file that names both.

### 6.5 What this system reads and writes, and who owns each

| Reads / writes | Owner | Through |
|---|---|---|
| **writes** `Workspace.DrivePlaces` (and destroys its own previous folder) | `ServerScriptService.Places` | `Places.build` |
| **writes** terrain **material** inside each strip | `ServerScriptService.Places` | `Ground.paint` → `Terrain:ReplaceMaterial` |
| **reads** the layout table and `standSpan`, `roadZ`, `PICK.standRadiusStuds` | `src/shared/ForestTest` (frozen data) | `Places` (shared), by require |
| **reads** the terrain height | `ServerScriptService.ForestTest` — `terrainYAt` | injected at the boot |
| **reads** `LAYOUT_ORDER` to know which places to dress | `src/shared/ForestTest` | `Places.build`'s loop |
| **reads** the planting rule | `src/shared/TreeGround` | `bounds`, `groundBand`, `samples`, `spread`, `decide` |
| **reads** templates | **Karen's Studio content** (`OurForest`, `Session`, `LobbyAssets.Trees`) | `Clone()` only, never a write (rule 7) |
| **is read by** the two ground readers' ignore list | `ServerScriptService.ForestTest` / `src/shared/ForestTest` | `ForestTest.GROUND_IGNORE` (§10.1) |
| **is read by** `roomToStand` / `nearestSolid` as **solid** | `ServerScriptService.ForestTest` | deliberately **not** excluded: a rest spot must be near a trunk and not inside one |

Nothing in `src/server/Match/`, `src/client/`, `src/shared/Drive/` changes.

---

## 7. The strip surface: painted, never built

Karen's goal sentence begins *"so you goal fix terrain"*, and three of the four reference frames are
about a **surface**: pale gravel, a grassy ride with two ruts, a dirt double track under brown leaves.
Trees alone do not answer it.

### 7.1 The decision

**`Terrain:ReplaceMaterial(region, 4, source, target)`, per chunk, per source material, inside the
running session.** It replaces the material of voxels in a region and leaves the shape alone, which is
the only API that can re-surface 29–37 studs of relief without flattening it. `FillBlock` is
**refused** here for exactly that reason, and the refusal is already paid for: `Lobby.Field`'s header
records what a flat slab costs, and task 191 measured a voxelised surface sitting 0.752 studs off its
nominal shelf.

### 7.2 The shape of a write

```
loY, hiY := Ground.yBandOf(layout, plan, terrainYAt)   -- terrainYAt sampled every 20 studs along the
                                                       -- strip centre, min and max, padded Y_PAD_STUDS
for each chunk of CHUNK_STUDS along x, inside Places.plotOf(layout, plan):
    region := Region3 over (chunk x) x (loY, hiY) x (lineZ ± surface.halfWidthStuds)
              -- ExpandToGrid(4) before the call, because an edge off the 4-stud grid keeps its old
              -- material: task 191 measured 623 Ground and 2 Grass for exactly that reason
    for each source in SOURCE_MATERIALS: terrain:ReplaceMaterial(region, 4, source, surface.material)
```

A curved layout gets a **chunked** approximation of its curve: one region per chunk, centred on
`roadZ` at the chunk's middle. `road` has no `surface` row, so no curve is ever painted — and if one
is wanted later, 200-stud chunks over amplitude 30 / wavelength 440 is a ±5-stud error on the band's
edge, which is inside the band's own half-width. Stated so the next reader does not have to derive it.

Only **Grass** and **LeafyGrass** are replaced, so a strip that crosses the Limestone, Asphalt or Mud
this world also holds (BRIEF M4) keeps it. **Nothing is painted back**: the rollback is that a Studio
Play session's terrain write is discarded when Play stops, which is the property `Lobby.Field` has
relied on in this same place since task 178. **I have not re-verified it myself (§18).**

### 7.3 What is painted, and what is not

| Place | Painted | Why |
|---|---|---|
| 1 `road` | **nothing** | BRIEF D3 freezes it. Its gravel is Karen's existing Studio road |
| 2 `edge` | **nothing** | the field is grass; a crop is not reachable (§4.2). Painting it `Ground` would make a ploughed field, which is a different place from ref-6 |
| 3 `ride` | **nothing** | ref-5 **is** a grassy ride. The dressing is the pines at its edge, not its surface |
| 4 `track` | **18 studs of `Enum.Material.Ground`** down the centre line | ref-1 is bare soil and leaf litter under the trees. This is the one surface the frames demand and the assets can give |

So the whole surface system is **one row in one plan** today. That is deliberate: it is the smallest
thing that answers a frame, the module exists so the next place is a row and not a code path, and the
cost is bounded (§11).

**The belts' floor stays this world's green grass**, and that is the biggest remaining gap between
Karen's frames and what ships — her forests are floored brown. Two ways to close it, neither taken
here: paint each belt's whole footprint (≈ 692,000 voxels per place against the strip's ≈ 58,000 —
measured in voxels, not timed, so it is a risk and not a cost), or change `Terrain.MaterialColors` for
Grass, which is **global** and would re-colour the lodge's lawn and the existing wood too. **Rejected
by default, Karen's to ask for** (K2).

---

## 8. How a stand stays on rolling ground (BRIEF item 5)

Measured: 29–37 studs of relief along a 700-stud stand line, 58–98 studs over a whole plot, and **no
flatter ground exists in this world** (BRIEF M8). So the answer cannot be "find flat ground"; it has
to be "never use one height for two points".

**Nothing new is needed, and that is the finding.** Every production reader of a layout point already
re-measures:

* **the stands** — `Markers.build` asks `Markers.groundFor(stand.X, stand.Z, …)` **per stand**
  (`src/server/ForestTest/Markers.luau`), and `groundFor` asks **both** readers and **refuses a
  disagreement over `GROUND_TOLERANCE_STUDS` (1)**. A refused stand is a counter and a console line,
  not a `missing` string;
* **the hunter on it** — `Body.placementFor` reads `post.Position` and `post.Size.Y`, so he stands on
  the post's own measured height;
* **the beater pad** — `ForestTest.beaterStartPosition` measures `terrainYAt` per side-step try and
  checks `roomToStand(point, BEATER.clearStuds = 6)`;
* **the rest spots and the release line** — `Data.groundAt` per spot, with
  `REST.canopySlackStuds = 6` against `terrainYAt`;
* **every planted tree** — `Places.groundsUnder` reads the ground at **25 samples over the trunk's own
  flare footprint** (`TreeGround.samples(…, 4)`), takes the **lowest**, and refuses the tree outright
  when the spread exceeds `TreeGround.CLIFF_STUDS` (4.0). Lesson L-024 is this rule: *"ground height
  must be sampled at each tree's actual footprint corners, not one point reused for the whole model"*.

**The dressing does not re-measure per stand, because it never asks about a stand.** It asks about its
own tree, 25 times, which is strictly more than `Markers.groundFor` does.

**What this system must NOT break is the stand refusal**, and §10.1 is how it nearly does.

---

## 9. No tree in a lane, no stand inside a trunk (BRIEF item 6)

**The rule, in one line:** nothing is planted where
`|z − roadZ(x, layout)| ≤ plan.halfStripStuds + Places.LANE_STUDS`, asked at the **jittered** point
and not at the cell centre — because the jitter is the only thing that could have walked a tree into
the lane. (`Places.layer`'s `if not Places.inLane(jx, z, layout, plan)` already does exactly this, and
re-asks `roadZ` at the jittered x so a curved layout gets a curved strip for free.)

**The numbers it produces:**

| | clear half-width from the line | = metres | nearest trunk to a stand's centre | stand circle (`PICK.standRadiusStuds`) |
|---|---|---|---|---|
| `edge` | 42 studs | 11.8 m | 42 studs | 12 studs |
| `ride` | 44 studs | 12.3 m | 44 studs | 12 studs |
| `track` | 21 studs | 5.9 m | 21 studs | 12 studs |

So "no stand inside a trunk" holds **by construction with 9 studs of margin in the worst place**, and
`LANE_STUDS` is exactly `ForestTest.PICK.standRadiusStuds` so the two can never drift apart silently
(§10.4 makes that an assertion).

**What the lane rule does NOT promise, stated so nobody claims it:** a **canopy** may overhang the
clear ground. On `track` the nearest planted trees are `shrub`-band larches at 21 studs, scaled
0.22–0.40 of a 14-stud crown — a reach of ≤ 2.8 studs, so the first overhang begins 18 studs from the
line; the `wood` band starts 71 studs out (reach ≤ 19 studs). A pellet is unaffected either way,
because `Places.quieten` makes every non-colliding part unqueryable (D9) and leaves the trunk
queryable. **The ray that is affected is the ground reader, and that is §10.1.**

---

## 10. Corrections to the code as it stands

Each item is a hole the next task inherits, a second answer to one question, or a claim the code does
not keep. Evidence is a file and a symbol.

### 10.1 The planter measures the ground with a reader that can see its own trees — and the stands' cross-check can see them too

**Evidence.** `Places.build` (`src/server/Places/init.luau`) defaults its reader to
`Forest.groundAt`, and `plantOne` parents each clone (`made.Parent = parent`) **before** the next tree
is measured. `ForestTest.groundAt` (`src/shared/ForestTest/init.luau`) excludes exactly three folders
by name — `{ "OurForest", "Foliage", "Boars" }` — and a planted trunk keeps `CanQuery = true` by
design (D9), so it is a legal ray hit. The same function is the **canopy** half of
`Markers.groundFor` (`Markers.setReaders(ForestTest.terrainYAt, Data.groundAt)`, the last lines of
`src/server/ForestTest/init.luau`), and a disagreement over 1 stud **refuses a stand**
(`Markers.GROUND_TOLERANCE_STUDS`). A refused stand is not cosmetic: all of them refused is
`complete = false`, which is `WAITING forest:stands (0 of 6)` for ever on that place.

**Why it matters.** Two failures from one cause. A tree planted on top of another tree's trunk is
Karen's *"look at the trees wtf"* again, and it would depend on **planting order**, so it would not be
reproducible from the seed — which breaks the one property §2 is built on. And a planted trunk or an
invisible-but-queryable part over a strip can make the drive refuse to start in a world the harness
never runs in.

**The fix, two lines and one injection:**

1. the boot hands the planter **`ForestTest.terrainYAt`** (Terrain only, `FilterType.Include` on
   `Workspace.Terrain`): the two plots hold **zero** non-terrain parts (BRIEF M8) and terrain answered
   **every** sample across this ground (M4), so terrain *is* the ground here, and the plan's output
   stops depending on its own order;
2. `ForestTest.groundAt`'s ignore list becomes **data in the shared module** and gains our folder:

```luau
-- src/shared/ForestTest/init.luau
ForestTest.GROUND_IGNORE = table.freeze({ "OurForest", "Foliage", "Boars", "DrivePlaces" })
```

   `groundAt` loops it, and `tests/server/places.spec.luau` asserts
   `table.find(Forest.GROUND_IGNORE, Plan.FOLDER) ~= nil` — so the name exists once (shared
   `Places.FOLDER`, §6.1), the server planter reads it from there, and the ignore list cannot drift
   from the folder it is about.

`roomToStand` and `nearestSolid` are **deliberately left alone**: a rest spot must be at least
`REST.clearStuds` (8) and at most `nearTrunkStuds` (22) from something solid, which is precisely the
question a planted trunk should answer *yes* to.

### 10.2 The north belt stops 306 studs short of the drive, so the beaters muster in open grass

**Evidence.** `Places.layer` plants the band `[lane, lane + depth]`, so with `northBeltStuds = 230`
and `lane = 44`, `ride`'s north belt runs z −4056…−3826. `ForestTest.beaterNorthStuds()` is
`LINE.spawnNorthStuds (180) + BEATER.behindLineStuds (400)` = **580**, i.e. z −3520. That is **306
studs north of the last tree.** `ForestTest.REST.farRoadStuds` is **425**, so the resting wood's own
band also runs 151 studs past the last trunk — and `restSpot` only accepts a spot whose nearest solid
thing is within `nearTrunkStuds` (22), so beyond the belt there is no legal rest spot at all.

Both the brief (§4's table, *"inside the planted north belt"*) and the code's own comment
(`Places.PLANS.ride`: *"The beaters form up at z −3520, 40 studs inside the north belt's far edge"*)
**state a property the numbers do not have.** That is the task-151 rule: the older sentence does not
get to stand.

**Why it matters.** A hunter on a straight ride looks 580 studs up it and watches seven bots walk out
of bare grass — which is the stage-set look Karen's *"not fake it or broken"* is aimed at — and the
animals have cover over only half the band they are stocked into.

**The fix:** the belts reach the drive, at a coarser grid.

* `bands` gains a third edge, `woodStuds` (the far edge of the **full-density** wood band, 230);
* `northBeltStuds` becomes **640** for `ride` and `track` — `beaterNorthStuds() 580 + 60` of margin,
  the same 60-stud run-out task 179 used for a half stand spacing;
* beyond `woodStuds`, the band is **`deep`**: the same `wood` mix at `deepSpacingStuds = 60` and
  **no fern layer**. Borrowed justification, not a cost excuse: the frames show 40–60 m of sight line
  between trunks in high forest (note's target table), i.e. 143–215 studs, so past the 230-stud
  full-density band a 60-stud grid **is** the horizon;
* `Places.capacity` counts the deep band, and `Places.plant` emits `band = "deep"` items.

Measured consequences (arithmetic, from §4.2 and the plot clamp of §10.5): **≈ 3,000 plantings in
total** against the WIP's ≈ 1,800, of which only ≈ 250 are deep-band trees; the whole north belt is
inside the boar field (`boundsOf(ride).maxZ = −3200` against the belt's far edge at −3460), so nothing
is planted where an animal cannot go.

**The consequence that must be MEASURED and not assumed:** bots walk a straight lane with
`Humanoid:MoveTo` and no pathfinding (`src/server/Bots/Lane.luau`'s header: *"`PathfindingService` is
rejected for this"*), so trunks are now in their lanes for 580 studs. This is **not new** — the `road`
layout's lanes already cross `OurForest`, whose ≈ 2,200 trees over its footprint average one tree per
≈ 34 studs, the same spacing as these belts, and task 162 measured that walk at 120 s — but it has
never been measured on a belt we planted. §11 makes "bots crossing the line per drive" a target with a
number, and §13 puts it in the live-only list.

### 10.3 The grid has no neighbour test, so two trees can share a stump

**Evidence.** `src/shared/Places/init.luau`'s header claims Bridson's grid neighbour test: *"A
candidate is dropped if it is closer than `minGapStuds` to a tree already placed in the same or an
adjacent cell"*. `Places.layer` inserts **every** candidate that is out of the lane; the file declares
no `minGapStuds` and compares no distance. The note §3 makes the same claim.

**Why it matters.** With `spacingStuds = 28` and `JITTER = 0.8`, two trees in adjacent cells can land
**≈ 5 studs apart** while a trunk flare is up to 13.6 studs across (`TreeGround.FLARE_FRACTION 0.08`
on an 85-stud aspen) and `LarchTree_Var02`'s trunk mesh alone is 15.6 studs across
(`src/shared/TreeGround/init.luau`, `flareFootprint`'s header). Two trunks in one stump is the
knife-held-backwards class of defect: measured correct, looks wrong. It is also the one claim in the
module that a reader would trust without checking.

**The fix:** `minGapStuds` per plan (§4.2: 0.55–0.57 of the cell), a `{ [cellKey] = {x, z} }` table
built as the layer runs, and a check against the **nine** cells around the candidate — Bridson's own
invariant (one sample per cell) makes nine enough, and it is O(1). The fern layer keeps its own,
smaller gap (`0.5 × fernSpacing`) so a fern may stand under a tree but not inside another fern.

**The spec case this needs** (§12): over **every** planting of **every** place, the minimum pairwise
distance within a group (trees with trees, ferns with ferns) is `≥ minGapStuds`, computed by the spec
with its own grid and not by calling the planner's helper.

### 10.4 Two spec bugs that would fail the harness, and one that cannot fail it

1. **`tests/server/places.spec.luau`, case *"keeps every tree clear of every stand circle"*, reads
   `Forest.PICK.radiusStuds`.** The field is **`ForestTest.PICK.standRadiusStuds`**
   (`src/shared/ForestTest/init.luau`). `radiusStuds` is `nil`, so the first comparison errors and
   the case fails. Fix the name, and **assert the identity the comment assumes**:
   `expect(Plan.LANE_STUDS).to.equal(Forest.PICK.standRadiusStuds)` — the two numbers are the same
   fact and must be checked, not described. (`Places.LANE_STUDS`'s own comment says *"rounded up"*; it
   is **equal**, and the comment is wrong.)
2. **The band counter will error on the new band.** The same spec's *"puts the young growth at the
   edge"* case builds `local counts = { herb = 0, shrub = 0, wood = 0 }` and does
   `counts[item.band] += 1`; a `deep` planting makes that `nil + 1`. Add the row.
3. **The lane case proves only that the planner called its own predicate.**
   `expect(Plan.inLane(item.x, item.z, layout, plan)).to.equal(false)` cannot catch a wrong
   `inLane`. `PROJECT_CONTEXT.md` names this shape (*"One predicate answered two unrelated
   questions"*). The case must **also** assert the arithmetic independently:
   `math.abs(item.z - Forest.roadZ(item.x, layout)) > plan.halfStripStuds + Plan.LANE_STUDS`, and
   report the worst gap it saw (it already computes it).

### 10.5 Planting runs past the ground that was surveyed

**Evidence.** `Places.plant` sets `minX = span.minX - plan.beltStuds` and
`maxX = span.maxX + plan.beltStuds`: for `track` that is x **4245…5355**. The plot that was measured
is 820 studs wide about x 4800 — **x 4390…5210** (BRIEF M8) — and the terrain sweep of M4 sampled only
x 1400…4600. So up to 145 studs at each end of two places are planted on ground nobody looked at.

**Why it matters.** It is not a crash: `plantOne` answers `"no-ground"` for a column with no terrain
and `"cliff"` for a footprint across a step, and both are counted. It is a **claim** problem: "every
tree is on the ground" would be asserted over ground that was never surveyed, and an unsurveyed strip
is also where an existing `Session` bush could be standing.

**The fix:** `Places.plotOf(layout, plan)` returns the **surveyed** x range (`plan.plotHalfWidthStuds
= 410`, centred on `layout.centre.X`), `plant` and `capacity` intersect with it, and the report keeps
`missing`/`skipped`/`cliff` as the backstop. For `edge`, whose plot is the field measured in M6
(x 3100…3860), the surveyed range is x 3080…3880.

---

## 11. Numeric targets

| What | Target | Measured, derived or chosen |
|---|---|---|
| Places Karen can stand in | **4** | her ask |
| Places dressed by this task | 3 (`road` keeps today's world) | BRIEF D3 |
| Rotation: four drives in a row | places 1, 2, 3, 4; the fifth is 1 | by construction (§5) |
| A forced drive advances the rotation | **never** | by construction (`chosen.rotated`) |
| Trunk junction above the lowest ground under its footprint, worst planted tree | **≤ 0.20 studs** | `TreeGround.TOLERANCE_STUDS`, the number task 196 held the lobby's 38 trees to |
| Trees in a shooting lane, any place | **0** | asserted over every planting |
| Trunks inside a stand circle (12 studs) | **0**, with ≥ 9 studs of margin in the worst place (`track`) | derived (§9) |
| Minimum distance between two planted trees | **≥ `minGapStuds`** (16–19) | §10.3 |
| Clear corridor, cut line | 88 studs = **24.6 m** | source C's 15–25 m band, at the top of it |
| Clear corridor, forest road | 42 studs = **11.8 m**; first trunk **5.9 m** from the line | source B's 3–4 m track, widened so a boar is shootable crossing it |
| Painted track width | 18 studs = **5 m**, `Enum.Material.Ground` | source B |
| Field, place 2: guns to the far tree line | **500 studs = 140 m** | measured (M5); Karen's 80–150 m |
| Belt depth at full density, either side of a strip | **≥ 230 studs = 64 m** | the frames' 40–60 m sight line |
| North belt reaches the beaters' muster | **640 studs ≥ `beaterNorthStuds()` 580** | §10.2 |
| Plantings, all places | **≈ 3,000**, hard bound **< 4,500** (`Places.capacity`) | derived; the spec asserts `#list ≤ capacity` |
| Parts created, all places | **< 25,000** | derived (≈ 7 descendants per model). **Must be printed, not assumed** |
| Build cost, all four places | **< 2.5 s**, once, at boot | derived from M9 (200 models in 0.09 s) |
| Terrain calls | **≤ 12** `ReplaceMaterial` calls total (one place, ~4 chunks × 2 source materials), **< 0.5 s** | derived; must be printed |
| Per-frame cost of the dressing | **0** — anchored parts, no script, no animation, no heartbeat | by construction |
| Bots that cross the line in a drive, places 3 and 4 | **≥ 90 %** | **not measured. §13** |
| Stands refused by `Markers.groundFor`, places 2–4 | **0 of 6 / 5 / 6** | **not measured. §13** |
| Drive length, every place | 120.0 s ± 0.1 of beater walk | holds by construction: no layout carries the number |

---

## 12. How it is tested

### 12.1 Server spec — `tests/server/places.spec.luau` (exists; this is the full list after this task)

It runs in **DEV**, where no template exists, which is why every case is either pure or driven through
a fake reader.

1. **four places, three dressed, `road` dressed with nothing** — `#LAYOUT_ORDER == 4`,
   `planFor("road") == nil`, three plans, each with a positive strip, spacing and ordered bands
   (exists);
2. **the strip widths the frames show** — cut line 15–25 m, forest road 4–8 m, and the forest road is
   the narrower of the two (exists);
3. **nothing north of the field edge** — `edge.northBeltStuds == 0` and zero plantings with
   `z > roadZ(x)` (exists);
4. **140 m of field** (exists; rename per §4.1);
5. **no tree in any lane, in any place** — asserted **independently** of `Places.inLane` (§10.4 item
   3) and also through it;
6. **every tree clear of every stand circle** — with `PICK.standRadiusStuds`, plus
   `LANE_STUDS == PICK.standRadiusStuds` (§10.4 item 1);
7. **the lane follows the curve** — on `road`, `inLane` at `roadZ(x)` is true and at `centre.Z` is
   false (exists);
8. **NEW: no two trees share a stump** — minimum pairwise distance ≥ `minGapStuds`, by the spec's own
   grid (§10.3);
9. **NEW: the belts reach the beaters** — for `ride` and `track`,
   `northBeltStuds ≥ beaterNorthStuds()`, and at least one planting within 60 studs of
   `beaterStart(centre.X, 0, layout).Z`; and the far edge is inside `boundsOf(layout).maxZ`;
10. **NEW: nothing is planted outside the surveyed plot** — every `item.x` inside
    `Places.plotOf(layout, plan)`;
11. **the same forest every time** — two `plant` calls, item for item (exists);
12. **under the declared capacity** — `#list ≤ capacity(layout, plan)`, total within bounds (exists;
    raise the band table per §10.4 item 2);
13. **young growth at the edge, big trees behind** — `shrubScale[2] ≤ woodScale[1]` for every plan,
    and all four bands non-empty on `track` (exists, extended);
14. **only species this world holds**, and every mix names a group that exists (exists);
15. **a mix is drawn in proportion to its weight**, clamped out of range (exists);
16. **the claw fractions are the five measured ones and zero elsewhere** (exists);
17. **the ground is read on a 5 × 5 grid over the footprint, corners included** (exists);
18. **a column the world cannot answer is dropped, never invented** (exists);
19. **a part's world box is its rotation projected onto the axes** (exists);
20. **the trunk's footprint and not the crown's** (exists);
21. **an invisible pad is ignored when measuring and cannot stop a bullet; the trunk still can**
    (exists — this is D9 and lesson L-060);
22. **NEW: a tree is never planted above the ground** — `plantOne` over a fake hillside, asserting
    the settled model's trunk junction is within `TreeGround.TOLERANCE_STUDS` of the lowest sample,
    and that a footprint across a 6-stud step answers `"cliff"` and leaves **no instance behind**;
23. **nothing at all when the templates are not in this place** — `templates(empty) == 0`,
    `report.reason == "no-templates"`, no folder (exists; this is the DEV path, BRIEF item 8);
24. **NEW: the surface is painted through an injected terrain and nowhere else** — a fake `terrain`
    with a recording `ReplaceMaterial`: the call count, the chunking, `resolution == 4`, every region
    inside the strip's own half-width and inside the plot, and **zero calls** for a plan with no
    `surface` row (`Lobby.Field`'s own fake-FillBlock idiom);
25. **NEW: the ignore list and the folder name are one fact** —
    `table.find(Forest.GROUND_IGNORE, Plan.FOLDER)` (§10.1).

**No new spec file**, deliberately: every case above lives in `places.spec.luau`, so no new
`SCOPE_SPECS` membership is needed and CI's selftest cannot go red for a missing row (standing rule
G).

### 12.2 Server spec — `tests/server/forest_stand.spec.luau` (exists, loops `LAYOUT_ORDER`)

Already covers the fourth layout by construction, and already asserts the rotation (the cycle, the
unknown name, the start) and `road` number-for-number. **Add nothing** except the two assertions that
bind this task's places to the drive's own geometry: for every layout,
`exitZOf(layout) < min roadZ(x)` (exists) and — NEW — for every **dressed** layout,
`REST.farRoadStuds ≤ plan.northBeltStuds - Places.LANE_STUDS`, so the resting wood can never be
stocked outside the trees again (§10.2).

### 12.3 Client spec

**None, and nothing on the client changes.** `tests/client/map_ui.spec.luau` already loops
`data.LAYOUT_ORDER`, so the fourth layout's map is covered the moment the row exists, and
`MapUi.geometryFromForestTest` reads the layout rather than a list of names. Said here so nobody adds
a client file (`forest-drive.md` §6.4's rule).

### 12.4 The console line, which is the honest channel

```
[ForestTestBoot] places: 3 dressed, 2994 planted, 11 skipped, 4 on a step, 0 template(s) missing,
                 1.42s, 8 terrain call(s)
```

Every number in §11 that is marked *must be printed* is printed by that line or by `Places.stats()`.
A report that says it planted a forest and cannot say how many trees is the measured-correct /
looks-wrong failure.

### 12.5 Screenshots (rule 5) — the point of the task

A number cannot answer *"it has to be like real life hunting situations"*. **Nine frames, each
inspected before it is claimed**, taken with `DHForestLayout` forced to the place:

1. **places 2, 3 and 4: the hunter's own eye at his stand, looking up the drive** — the three frames
   Karen's four references are judged against, side by side with her frame;
2. **place 3 and place 4: the view down the strip from the end stand**, which is where a tree in the
   lane would show;
3. **place 2: looking north from the stand** — hedge in the near frame, 140 m of field, the existing
   wood's face across it;
4. **place 4: the painted track at the hunter's feet**, because a 5 m material strip either reads as a
   track or does not;
5. **place 3 or 4: the beaters' muster, 580 studs up the strip**, taken during a drive — the frame
   §10.2 exists for;
6. **one tree's base, close up, on the steepest ground the report names**, which is the 196/199 defect
   this whole system is held to.

### 12.6 Harness input, and the gate

* **`tests/client/input_scenarios.txt`: nothing new.** It replays keys, buttons and moves and
  **cannot set a Studio attribute** (TASKS.md tasks 6–7), so the layout override is tested through the
  pure parser (`ForestTest.forcedLayout`) and the one `GetAttribute` line in the boot is **not covered
  by any spec**.
* **The gate is the one-player run only.** `git diff --name-only origin/main...HEAD` must contain no
  path in `TWO_PLAYER_PATHS`: this task touches `src/shared/Places/`, `src/server/Places/`,
  `src/shared/ForestTest/`, `src/server/ForestTest/`, `src/server/ForestTestBoot.server.luau`,
  `tests/server/places.spec.luau`, `tests/server/forest_stand.spec.luau` and `tools/studio_mcp.py` —
  **none** of which is on that list (BRIEF §7 is the Director's own statement of this, and a change
  to `src/server/Match/` would stop the task instead).
* `python tools/pose.py clear` and `python tools/flags.py clear` before the run, **and
  `DHForestLayout` cleared by hand** — the harness does not refuse that attribute
  (`drive-layouts.md` §11, D3).

### 12.7 Blast radius rows (BRIEF item 11)

Already present in `tools/studio_mcp.py` and to be kept:

```python
("src/shared/Places/", "places"),
("src/server/Places/", "places"),
"places": ("tests/server/places.spec.luau", "tests/server/forest_stand.spec.luau"),
# and places.spec is a member of the "match" scope as well
```

Lesson L-079 is why they exist (task 190's `HandAssets` silently resolved to the whole suite), and
`tools/studio_mcp.py selftest` fails if a spec belongs to no scope or a scope names a file that does
not exist. **`src/server/Places/Ground.luau` needs no new row** — it is inside
`src/server/Places/`.

---

## 13. What a spec can prove with no world, and what only a live place can answer (BRIEF item 7)

**Provable in the harness, in DEV, with no Studio content:**

* where every one of ≈ 3,000 plantings goes, for every place, to the stud;
* that not one is in a lane, inside a stand circle, within `minGapStuds` of another, or outside the
  surveyed plot;
* that the plan is identical from the same seed, and bounded by `capacity` before it runs;
* that every species name is one this world holds and every mix names a group that exists;
* the whole of `TreeGround`'s decision over a fake hillside: which trees move, by how much, which are
  refused as `cliff`, and that a refusal leaves no instance;
* the footprint grid, the trunk-vs-crown rule, the invisible-pad rule, the `CanQuery` rule;
* that the terrain write happens only through an injected handle, only inside the strip, and not at
  all for a plan with no surface;
* the rotation, the override parser, and that a forced drive does not advance the cycle;
* that the DEV place plants nothing and says why.

**Only a live Forest Test session can answer:**

* **whether it looks like Karen's frames.** Nobody has seen any of this (§18);
* the real counts: `planted` / `skipped` / `cliff` / `missing`, and the measured build seconds and
  part count;
* the worst real `clawGap` over ~3,000 real meshes — the spec proves the arithmetic, not these models;
* whether `Markers.groundFor` still accepts every stand on places 2–4 **after** planting (the §10.1
  failure, and the one that would sit in `Waiting` for ever);
* whether `beaterStartPosition` finds room to stand inside the belt, or falls through to its
  "behind the crossing anyway" branch;
* **what fraction of bots cross the line** in a planted lane (§10.2), and whether a boar's pathfinding
  copes with ~3,000 new trunks at `MAX_BOARS`;
* the frame rate and the replication cost of ~25,000 new parts;
* whether the `Ground` paint reads as a dirt track rather than a grey stripe, and how many voxels of
  the strip actually changed (task 191's 625-sample material grid is the method);
* that a Studio Play session's terrain write really is discarded on stop (§18).

---

## 14. The DEV path (BRIEF item 8)

**Nothing, loudly, once.** `src/server/ForestTestBoot.server.luau` returns early unless
`Map.EXPECTED_WORLD == "forest-test"`, so `Places.build` is never called in DEV by the boot. And if it
is called — it is, by `places.spec`, with a fake root — `Places.templates` answers an empty list and
`build` returns `{ reason = "no-templates", planted = 0 }` **and creates no folder**. That is case 23
of §12.1.

`Workspace.DrivePlaces` cannot dirty a harness run for the same reason `Workspace.ForestMarkers` and
`Workspace.DriveMarkers` cannot: the harness compares the **Edit-mode** DataModel against disk and
fails on a **script** outside a Rojo-owned path; `Workspace` is not Rojo-owned, these are Parts and
Models, and they are created during Play (`src/server/Match/Body.luau`'s header writes this down).
Stronger here: the code cannot execute in DEV at all.

---

## 15. Deltas to the designs this task changes (BRIEF item 10)

### 15.1 `docs/design/drive-layouts.md`

* **§1.2 item 3** (*"Must not ship a fourth layout"*) — **superseded by task 193.** Replace the item
  with: *"Must not CUT a layout out of the existing wood. Re-measured on 2026-10-17: along the best
  candidate line inside it, 18 of 36 samples have a trunk within 14 studs, and a sweep for any line
  clear at ±10 studs over 900 studs found none (BRIEF M7). The fourth and fifth places are therefore
  PLANTED on the two measured clean plots (BRIEF M8), which is `docs/design/drive-places.md`. The old
  item's reason — there is no clearing in this wood — is still true; what changed is the answer."*
* **§3.1 / §3.2 tables** — four columns, the numbers in §4.1 above, `exitZOf` −2377 / −3650 / −4350 /
  −4350. `edge` moved from z −3000 to −3400 and its `centre.Y` from 185 to 202 (re-measured, six
  readings in the table's own comment); `ride` moved from (3350, −2600) to (1500, −4100); `track` is
  new at (4800, −4100).
* **§5.4 (the bag)** — **replaced by the rotation.** `nextLayout(previous)` only; no bag, no roll, no
  `state.bag`. The boundary-swap paragraph goes; the Tetris and DevForum sources (§12.2, §12.3) stay as
  **superseded history** with one line saying Karen's sentence reversed it.
* **§5.2's pseudocode** — `name = if chosen.rotated then Data.nextLayout(chosen.name) else
  LAYOUT_ORDER[1]`, `source = "rotation"`, and the override still never touches the cycle.
* **§9.1 item 9** — the bag's cases become the rotation's (§5 here).
* **§10** — "Layouts shipped: 3" → **4**; add the dressing's own targets by reference to
  `drive-places.md` §11.
* **§11, D4** (*"the fourth layout is not shipped"*) — closed by this task, with the measurement that
  changed the answer.

### 15.2 `docs/design/forest-drive.md`

* **§4.1.5** — the list of what makes `complete` false gains a sentence: *"and a planted canopy over a
  stand would too, which is why `ForestTest.GROUND_IGNORE` includes `DrivePlaces`
  (`drive-places.md` §10.1)"*.
* **§6.3** — unchanged in rule (a tied player is roped to the nearest stand marker; the forest tags no
  trunks). Add: *"the planted wood is not tagged either, and `markers.trees` stays empty, so the post
  fallback is still the answer by construction."*
* No other change: the arc still reads `line.normal` only, and for the three straight layouts the
  one-plane approximation is **exact**.

### 15.3 `docs/design/map-ui.md`

* **§5.2's bounds table** — four rows, from `boundsOf` per layout. No signature changes:
  `geometryFromForestTest(data, layout)` already reads the layout for the centre, half-span,
  amplitude, stand count and `exitZOf`, and a straight layout samples to a straight polyline with no
  second code path.
* Add one sentence to §5.5: *"On places 3 and 4 the lodge (x 2740…2960) is far off the map's west or
  east edge, so a player at the lodge between drives is pinned to the border and the minimap hides —
  the existing rule doing what it says (`drive-layouts.md` §8, K5)."*

### 15.4 `GAME_DESIGN.md`

The two *System owners* rows in §3 above.

---

## 16. The two designs that are behind the code (BRIEF §6)

The Learning Agent is right: `docs/design/` is behind `src/`. The Architect script writes **only this
file**, so here is the text, ready to paste, each into the file and section it belongs in. **These are
descriptions of code that already shipped and passed review; nothing here is a new decision.**

### 16.1 `docs/design/lobby.md` — add §9.3 and amend §12.2 and §13

> ### 9.3 The gathering yard (task 191), and the trees that stand on real ground (tasks 196, 199)
>
> **Karen, 2026-10-15 ~17:20:** *"next is when hunt over everyone is in clean ground no grass
> firstable / second it could be next to cabin"*. After playing it, 2026-10-16: *"yes it works / I
> shoot and cna see them there"* (`PLAYTEST.md`).
>
> The end-of-drive gathering happens in the lodge's own clean yard **west of the lodge**, not out in
> the forest grass. The yard is **one row** in `Lobby.CONFIG.FIELD.PADS` named `Gather` (56 × 56,
> `Enum.Material.Ground`), found **by name** by `Lobby.gatherPad(cfg)`, and **four** things read that
> one row: `Field.fill` lays the blade-free block from it (it already loops the list, so this is a row
> and not a code path), `Lobby.gatherSpotFor` reads its centre, `Build.treeLine` keeps a tree off it,
> and `lobby.spec` bounds the drive's whole scene inside it. **Nothing recomputes the rectangle.**
>
> **The world gets first say and the drive's old rule is the fallback, not a replacement.**
> `Lobby.gatherSpot()` (server) is handed to the drive as `world.gatherSpot`;
> `Match.gatherSpotOf(reader, markers, cfg)` is pure in the reader and answers
> `(spot, facing, fromWorld)`; `Match.gatherSpotFor` — `SCENE.GATHER_BEHIND_STUDS` behind the middle
> stand — is **unchanged** and still answers when the world names nowhere. The pattern is ioquake3's
> `FindIntermissionPoint` (GPL-2.0, nothing copied): the authored point first, `if ( !ent )` the
> derived one. **The DEV place has no lobby at all** (`Lobby.ANCHORS` has no `map:v1` row), so the
> harness's own world takes the fallback and `Match.stats().sceneWorldSpots` is 0 there — which is why
> no feature flag was added.
>
> **The spot's height is measured, never predicted.** `Lobby.gatherSpotFor` asks the injected
> `groundAt` **once**, at the yard's own centre, and falls back to the anchor's Y only when the reader
> is absent, answers a non-number, or throws. `Field.fill`'s surface is voxelised and is **not** the
> nominal shelf: that is how four trucks got their tyres 0.752 studs underground (task 186). Live, the
> server printed `(2800, 150, −2940)` against a shelf of 149.2. The yard was also moved **two studs
> east onto the 4-stud voxel grid** after the first build came back 623 `Ground` and 2 `Grass`; it
> re-measured 625/625 `Ground`, spread 0.00.
>
> **The whole scene fits**: `Scene.cornerReachFor(SCENE.MAX_ANIMALS, Match.CONFIG)` is 23.5 studs, so
> the worst-case square is 47 studs inside a 56-stud yard, and the spec asks `Match.Scene` for that
> number rather than copying it.
>
> **Where a tree meets the ground is no longer the lobby's own arithmetic.** Task 196 found that a
> birch's root flare is a set of arched claws, so seating the claw **tips** leaves daylight under every
> arch; task 199 found the same defect in `Workspace.OurForest` (Karen: *"look at the trees wtf"*).
> The rule — the trunk/root **junction** at or below the **lowest** ground anywhere under the trunk's
> own footprint — now lives in **`src/shared/TreeGround`**, which `Lobby.Build` requires from
> `treePlan` and `settleOnGround`, and which **`tools/forest_ground.py` reads from this file** and
> injects into the Luau it sends to Karen's Forest Test (a different place, which Rojo does not serve).
> There is one copy of the arithmetic and the tool carries it rather than restating it.
> `TreeGround.flareFootprint` is deliberately **not** called by `Lobby.Build`, and that is a
> measurement and not a preference: `lobby.spec`'s *"buries each tree's root claws"* case failed with
> it, because the lobby's footprint is already the union of the parts that reach the ground and on its
> two templates those **are** the flare.
> `Lobby.Build` is still **the one writer of every part in `Workspace.Lobby`**, and
> `src/server/Places` (task 193) borrows its shape and not its code for that reason.

> **§12.2, `ServerScriptService.Lobby` — add:**
> `Lobby.gatherSpot(): (Vector3?, Vector3?)` — the yard's measured centre and `CONFIG.GATHER.FACING`,
> handed to the drive as `world.gatherSpot`.
> **§12.1, `ReplicatedStorage.Lobby` — add:** `Lobby.gatherPad(cfg)`,
> `Lobby.gatherSpotFor(anchor, cfg, groundAt?)`, `Lobby.CONFIG.GATHER`, and the `Gather` row in
> `CONFIG.FIELD.PADS`.
> **§13 — add the row:** *where the drive gathers → `src/shared/Lobby` states it, `ServerScriptService.Lobby`
> measures it, `ServerScriptService.Match` decides between it and its own fallback.*

### 16.2 `docs/design/drive.md` — amend §3.6 and add §10.5 (and the truck rig belongs in `truck-pads.md`)

> **§10.5 The pad rig: one predicate, two readers (task 197)**
>
> **Karen, 2026-10-15 ~17:40:** *"same with entering in game menu has to be nicer and cleaner / and we
> need clear message that game is loading once clicked 1/1 or other now is delay / also could be car
> started sound light on something like that indicating loading ect"*.
>
> **The delay is not a load and was measured on the player's own path:** press to drive is **5.30 s**,
> of which 5.0 is `Lobby.CONFIG.COUNTDOWN_SECONDS` — a designed wait in which a second player can
> still step on. So the fix is **feedback**, not speed.
>
> **One pure predicate with two readers.** `Lobby.padLoading(state)` is true for `filling`,
> `countdown` and `leaving`. The owner mirrors that pad's state word onto each member as the `Player`
> attribute **`DHPadMine`** (written only by `ServerScriptService.Lobby`, level-triggered with edge
> writes in `setPadMine`, cleared the moment `world.inDrive` is true and again in `Lobby.stop`, with
> **no inbound door**) and hands the same answer to `Build.setTruck`. The banner and the engine are one
> fact said twice.
>
> **The truck is RECONCILED on the owner's scan, not fired on the pick.**
> `Build.setTruck(index, Data.padLoading(pad.state))` is asked every scan in `stepPads`, beside the
> `Build.setPad` that was already there, and is edge-triggered inside — so a running truck costs one
> comparison a scan per bay, and **no truck is ever left idling** whichever of the four ways a party
> ends.
>
> **There is no progress bar while a party is filling, and that is deliberate.**
> `PadPanel.barFraction` answers `nil` for `filling`: NN/g's rule is that a progress indicator says
> *approximately how much time remains*, which `countdown` knows exactly and `filling` — up to 45 s
> waiting for people who may never come — cannot.
>
> **The view turns through the camera's owner, as a request.** A player arrives on a pad facing north
> and his truck is 18 studs south, so the engine start, the headlights and the smoke all happened
> behind him. `Camera.faceTowards(point)` is a request of exactly `Camera.lookAt`'s shape: it eases
> over `Config.FACE_TURN_SECONDS` inside the camera's own `update`, through the pure
> `Mode.towardAngles` / `Mode.angleGapDeg`, and **`Rig.apply` is still the only writer of
> `workspace.CurrentCamera`**. The Hud **asks**, once, on the edge where a pad starts asking
> (`facedPad` in `Hud.renderObjective`), and the point comes from `Lobby.truckPosition(index)` —
> the model the server built, not a repeat of `Pads.centreFor`'s arithmetic on the client. Measured
> live: the view's flat LookVector dotted with the direction to the truck goes **0.037 → 1.000**.
>
> **One message at a time, as a level rule.** `Objective.text` returns `""` while either of the pad's
> panels is up, read from `lobby.asking` / `lobby.loading` — asked **every frame from the state as it
> is**, with no enter/exit edge to miss, so the line comes back by itself.
>
> **Two measured corrections that are design, not polish:** an attachment's `WorldCFrame` written
> **before** it is parented lands in the local `CFrame` — the exhaust and the **engine sound** were
> 3,000 studs away, at (5783.8, 304.8, −5872.9) against a lobby at (2893, 150, −2941) — so both are
> parented first now; and a dark `Neon` lamp still glows at night, so the rig remembers each lamp's
> shipped material (`TruckRig.lamps[].was`) and swaps it to `ENGINE.OFF_MATERIAL` when dark. The tail
> `PointLight`s are gone (`ENGINE.TAIL_BRIGHTNESS = 0`, a dial and not a deletion); the lit `Neon`
> lens is what reads as a tail light.

> **§3.6 — add the row:** *the pad menu, the loading banner, the truck rig → `ServerScriptService.Lobby`
> (the state and `DHPadMine`), `Lobby.Build` (the rig), `Hud.PadPanel` + `Hud.Objective` (the screen).
> `Match` is unchanged by it.*
> The truck rig's own numbers (`ENGINE.*`, the lamp rules) belong in **`docs/design/truck-pads.md`**,
> not in `drive.md`; the same text serves.

---

## 17. External sources

### A. Robert Bridson, *Fast Poisson Disk Sampling in Arbitrary Dimensions* (SIGGRAPH 2007 sketch)

<https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf>
Reference implementation: SciPy `scipy.stats.qmc.PoissonDisk`
<https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.qmc.PoissonDisk.html>
**Licence:** the sketch is the author's own copy of an ACM publication, all rights reserved — read for
the method, nothing copied; SciPy is **BSD-3-Clause**. **Maintenance:** the paper is a fixed 2007
document; SciPy is actively maintained.

* **Well.** It is the canonical answer to *scatter things so none is closer than r to another, with no
  clumps and no grid lines* — which is a forest. The background grid with cell size `r/√n` makes the
  neighbour test O(1); k = 30 candidates per active point is the only tuning it needs.
* **Badly, for us.** The active-list loop is unbounded in wall-clock terms and its output is an
  **unordered set**: you cannot ask it for "the tree at cell (i, j)" and get the same answer twice
  without storing the whole result. We need a plan that is a pure function of `(layout, seed)`, a hard
  cap on the tree count known before anything runs, and a cell whose tree a spec can name.
* **Adopted:** the **principle and the grid neighbour test**, not the loop (§2, §10.3).

### B. LWF-Merkblatt Nr. 38 on `Rückegassen` (skid trails), via waldwissen.net and Wald-Prinz

<https://www.waldwissen.net/de/technik-und-planung/forsttechnik-und-holzernte/walderschliessung/merkblatt-feinerschliessung>
<https://www.wald-prinz.de/ruckegassen-anlegen-feinerschliessung-sichert-bodenschonende-holzernte/3436>
**Licence:** Bayerische Landesanstalt für Wald und Forstwirtschaft / private publisher, all rights
reserved — read for dimensions. **Maintenance:** waldwissen.net is a live, curated public forestry
portal; the Merkblatt is a current advisory sheet.

* **Well.** It gives the dimension karen-ref-1 is a photograph of: a skid trail is **3–4 m wide**,
  "at least four metres" recommended, **20–60 m between trails** — and it is why the track has no made
  surface in the frame: a skid trail is bare soil and leaf litter, not gravel. That is place 4's
  18-stud painted strip and its `Enum.Material.Ground`.
* **Badly.** It is about machinery. It says nothing about sight lines and nothing about what a stand on
  one needs, so the **tree-free** corridor (42 studs) is ours and not its.
* **Adopted:** the width, the surface, and the reason the forest is close.

### C. `Schneise` / `Schussschneise` — WILD UND HUND forum practice, and the term itself

<https://forum.wildundhund.de/threads/schussschneisen-wie-umsetzen.115534/>
<https://www.duden.de/rechtschreibung/Schneise> · <https://www.kulturpixel.de/waldschneisen/>
**Licence:** forum terms / dictionary, read for practice and definition. **Maintenance:** live sites;
the thread itself is an old (2019) discussion, quoted as what practitioners do, not as a maintained
document.

* **Well.** The definition is place 3's brief — *an artificially created straight strip, cleared of
  trees and shrubs, that divides a forest* — and the practitioners give the number: 30 m is too wide
  and spoils the stand, **10–15 m preferred**, because game crosses a narrow lane quickly and is gone.
  That is exactly the shot ref-5 shows.
* **Badly.** Forum practice, not a study; the thread disagrees with itself between 6 m and 15 m.
* **Adopted:** the band, not a point — and honestly: our tree-free corridor is **24.6 m**, at the top
  of the dispatch's 15–25 m and **above** the preferred 10–15. `halfStripStuds` is the dial and K1 is
  the question.

### D. The graded forest edge — Gehlken, *Der "ideale Waldrand"* (Uni Göttingen, 2014), and the DVL practice booklet

<https://www.uni-goettingen.de/de/document/download/9ef453bebe0d4d3d4b5fd07c1e814771.pdf/Gehlken%202014%20Waldrand.pdf>
<https://www.dvl.org/fileadmin/user_upload/Publikationen/Praxishefte_Biotoppflege/DVL-Publikation-Praxisheft_Hinweise_zur_Biotop-_und_Landschaftspflege-Waldrand.pdf>
**Licence:** academic and NGO publications, freely published, all rights reserved. **Maintenance:**
both are current, both are static documents (neither is revised).

* **Well.** It is the recipe for why a forest edge is not a wall: **`Krautsaum` 5–10 m**, then
  **`Strauchmantel` 5–10 m**, then the `Baummantel` of light-demanding trees, 10–30 m in all. That is
  ref-6 (a bramble wall beside the stand, under an oak) and ref-5 (young pines in front of taller
  forest), and it says a belt must be built in **depth bands** rather than at one density.
* **Badly.** It is written for biodiversity: its species lists are nothing like our 61 models, and it
  says nothing about sight lines or about how dense is too dense to shoot through.
* **Adopted:** the three bands, with a fourth of our own (§10.2) that the source does not have and
  does not contradict.

### E. Roblox Creator Docs — `Terrain:ReplaceMaterial`, `Model:ScaleTo`, `Humanoid:MoveTo`

<https://create.roblox.com/docs/reference/engine/classes/Terrain#ReplaceMaterial> ·
<https://create.roblox.com/docs/reference/engine/classes/Model#ScaleTo> ·
<https://create.roblox.com/docs/reference/engine/classes/Humanoid#MoveTo>
**Licence:** Roblox documentation, free to read, not open-licensed. **Maintenance:** maintained with
the engine.

* **Well.** `ReplaceMaterial(region, resolution, source, target)` is the only API that changes a
  material without touching height, which is the whole of §7; `ScaleTo` is why young growth is a
  scaled model and not a second species; `MoveTo`'s documented 8-second timeout is why a bot stuck on
  a trunk stalls rather than crashes.
* **Badly.** `ReplaceMaterial` states no voxel ceiling, while `WriteVoxels` has a measured one
  (24,576 per region, recorded in `MapGen.Ground`'s header), so the chunking in §7.2 is defensive and
  its cost has to be **measured** rather than read off a page. `ScaleTo` has no documented effect on a
  mesh's collision fidelity at small scales.
* **Adopted:** all three, with the chunk size and the measurement obligation written down.

### F. Borrowed from inside this repo (rule 2)

`src/shared/TreeGround` **whole** — the claw rule, the flare footprint, the 5 × 5 grid, the cliff
refusal, the sink. `src/server/Lobby/Build.luau` — the **shape** of planting from code (clone a
Studio template, measure under the footprint, settle), its code deliberately not reused.
`src/server/Lobby/Field.luau` — the injected-terrain discipline, verbatim: *"a spec hands in a fake
with a recording `FillBlock`, so no spec in the DEV place can write DEV's terrain, ever"*.
`src/server/ForestTest/Markers.luau` — destroy-and-rebuild as the way one writer owns one folder, and
`groundFor`'s two-reader refusal. `src/shared/ForestTest/init.luau` — the trailing-optional-layout
parameter shape, and `Drive.deepFreeze`/`table.freeze` for data with no run-time writer.
`src/server/Boar/init.luau`'s `newRuntime(world)` — the injected-world precedent for
`Places.build(groundAt, world, terrain)`.

---

## 18. What I could not verify (rule 8)

* **No Studio, no place, no network in an Architect run.** Every geometric number here is read out of
  `reviews/task-193/BRIEF.md` §3, `docs/research/2026-10-17-four-driven-hunt-places.md`, or the code,
  or is arithmetic over those. **I measured nothing myself.**
* **I have not seen one frame of any of this.** Not the planted wood, not the painted track, not one
  hunter's view. Karen's eye decides §19's K-list, and §12.5's nine frames are the first look.
* **The counts in §11 marked *derived*** — ≈ 3,000 plantings, < 25,000 parts, < 2.5 s — are arithmetic
  over BRIEF M9's *200 models in 0.09 s*. The part count is an estimate of ~7 descendants per model
  from M2's *4,819 models, 1,404 descendants per 200*; it must be printed, not assumed.
* **The `ReplaceMaterial` cost is not known.** No region limit is documented and I could not time a
  call. §7.2's chunking is defensive and §11 makes the call count and the seconds a printed number.
* **That a Studio Play session's terrain write is discarded on stop** rests on `Lobby.Field`'s
  precedent in this same place, not on a test I ran. If it ever persists, the strip paint becomes a
  change to Karen's place file, which is rule 7 territory — the Builder must confirm it before the
  first run and say so.
* **Whether a planted belt breaks the bots' walk or the boars' pathfinding.** §10.2 argues from
  `OurForest`'s own measured density and task 162's 120 s, which is an argument and not a measurement
  of **these** lanes.
* **The links in §17 are not fetched.** A–D are carried from the note; E is carried from
  `docs/design/lobby.md` §14.4 and `src/server/Bots/Lane.luau`, where earlier tasks cited them. The
  Builder must confirm each URL resolves before putting it in a code comment (rule 9).
* **`tools/forest_claws.json` was not re-read against `Places.CLAW_FRACTION`.** The claim that of 61
  models only five carry a non-zero fraction is the server module's own comment; `places.spec` asserts
  the five against the table, which is not the same as asserting the table against the file. Named in
  §19 as D3.

---

## 19. Open decisions

### For Karen (feel and look) — none of these blocks building

* **K1. Is the cut line too wide?** The tree-free corridor is **24.6 m**, at the top of the dispatch's
  15–25 m and above the 10–15 m practitioners prefer, because `LANE_STUDS` (12) is added to the strip
  on both sides. `halfStripStuds` 32 → 24 makes it 20 m, and 20 → 17.9 m. One number.
* **K2. The forest floor is green, not brown.** Every reference frame is brown leaf litter and dry
  bracken; our belts are planted over this world's grass with a fern accent every 22–26 studs. §7.3
  names the two ways to fix it and why neither is taken by default. **This is the largest gap between
  her frames and what ships.**
* **K3. Summer leaf, late-autumn frames.** All 61 models are in full green leaf. Nothing here
  recolours or strips them (note §4 item 2).
* **K4. No crop in the field.** Place 2's field is mown grass; ref-6 is standing maize. The fix is one
  cheap wheat/stubble mesh, which is an Asset task.
* **K5. Is 1 → 2 → 3 → 4 the right order**, and is a different place every drive right, or too much?
  `LAYOUT_ORDER` is one line.
* **K6. Do 5 and 6 stands over 520–650 studs feel like a line**, against the road's 9 over 1,200?
* **K7. The minimap appearing and disappearing** at the lodge between drives as the bounds move —
  existing behaviour, now with four sets of bounds.

### For the Director (scope) — each has a decided default

* **D1. The strip surface (§7): build it, in this task.** One module, one plan row, one painted place.
  **Droppable** if the time box runs out: drop `src/server/Places/Ground.luau`, the `surface` row and
  §12.1 case 24, and place 4 is a grass track until a follow-up. Nothing else in the design depends on
  it.
* **D2. The deep band's cost (§10.2): ship it.** It adds ≈ 250 models per place and is what makes the
  beaters muster in trees. The alternative — beaters forming up in open grass 162 m up a straight ride
  — is the thing Karen's *"not fake it or broken"* is aimed at.
* **D3. `Places.CLAW_FRACTION` is five numbers copied out of `tools/forest_claws.json`.** Default:
  **keep the five and log it.** A tool's JSON cannot be required in game and 56 copied zeroes are 56
  chances to drift; the check that would close it belongs in `tools/studio_mcp.py selftest` and is its
  own task.
* **D4. `DHForestLayout` is still not a `DHFlag_*` name**, so `test` and `test2` do not refuse to start
  while it is set and a forced place could be reported as a rotated one. Default: **the printed
  `source=` line and `ForestTest.stats()` are the mitigation** (`drive-layouts.md` §11 D3, unchanged).
* **D5. The axis is still the next task.** All four places push south along −Z. The twelve attachment
  points are listed in `drive-layouts.md` §13 and none is touched here.
* **D6. Task 194's beater ground** sits **north of z −3460** on places 3 and 4 (beyond the planted
  belt's far edge) and **inside the existing wood** on place 2. This task leaves that room and builds
  nothing in it (BRIEF D5).
