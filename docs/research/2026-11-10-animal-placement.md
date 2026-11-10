# Animals are already standing in the wood: placement before the drive (task 345)

Rule 1 note for `docs/design/animal-placement.md`. Written for **T1**, the pure rules
(`src/shared/ForestTest/Placement.luau`), before any code in that file.

Karen, 2026-11-10 ~10:30 UTC: *"animals has to be in palces not just apear magically"* and *"we need
to have them not magically apearing it has to be there then it spooked or it walkks towards"*.

---

## 1. What the system must do

| Must | The number that says it |
|---|---|
| Every animal a player can see existed before that player could see it | spawns in view of a player, per drive = **0** |
| No animal is created within reach of a player, ever | `PLACEMENT.neverStuds` = **145** studs, 3-D, no fallback |
| A drive's population is fixed at its boundary and never re-stocked | **9 / 13 / 15** groups and **53 / 73 / 83** animals (quiet / normal / busy), and not one more |
| A placed-but-dormant animal costs nothing measurable | **0 instances, 0 parts, 0 ms** of `Runtime:step` for a RECORD |
| The bodies that do exist stay inside the measured budget | ≤ **24** bodies, of which ≤ **12** bedded; boar step ≤ **7.0 ms** mean, ≤ **20 ms** peak; server heartbeat p95 ≤ **32 ms** |
| Two ways to the line, both from a place the animal already stood | **spooked** (the line's notice band reaches the bed) and **walks toward** (`walkersPerDrive` = **2**) |
| The beds are far enough apart that one approach does not flush two groups | ≥ **71** studs between beds, 3-D (`SPOOK.BEATER_STUDS`) |
| A group that cannot be bedded legally is skipped, counted and printed | skipped for `inview` per drive = **0** at a stand; `nobed` and `budget` skips tolerated and counted |

Every one of those numbers is derived in `docs/design/animal-placement.md` §5.2 and §6.2 and is
asserted as a **relation** in `tests/server/forest_placement.spec.luau`, never as a literal.

---

## 2. The pattern adopted, and why

**A record is the truth; a body is a view of it.** Every animal of a drive is a row in a roster from
the drive's first frame. A row acquires a body only when the drive needs one, and only at a place and
a moment no player can perceive. This is Luanti's static/active object split (§3.1) with Left 4
Dead's *never spawn inside the visible set* as the promotion gate (§3.3).

**Why not the obvious alternatives.**

* **Spawn earlier and further away** (what the code does today, with `SCHEDULE.minNorthStuds` = 25
  studs as the floor) is the defect: 25 studs is inside the lane a hunter is looking down. Moving the
  floor north makes the pop rarer, not impossible, because distance alone cannot tell "behind a rise"
  from "straight down the ride".
* **A cheap body tier** (an anchored dummy that is upgraded later) was rejected on this repo's own
  measurement: `Runtime:step` does the snapshot, the gait, the history ring, the wound and the
  whiskers for *every* entry whatever it is doing, so a body is 0.19–0.22 ms whether it is lying up
  or running (task 342's two-point fit). A tier that still ticks is not a cheap tier; the only cheap
  tier is **no body at all**.
* **A fade at the boundary** — OpenMW's answer (§3.2) — is still a pop for an animal Karen is
  supposed to be able to *watch standing*. Her sentence is stronger than "don't let me see it
  arrive".

**Borrowed before built (rule 2).** The record/body split, the visible-set gate and the per-tier
count cap are all borrowed (§3). What is **not** borrowed, and is said so: the *selector*. Every
source promotes by **distance from the player**; ours promotes by **the drive's own clock** — a
record is due when the line is `leadSeconds` = 20 s from reaching its bed — because the drive already
owns that fact and a distance rule laid over it would be a second disagreeing owner (rule 3). The
same reasoning, in the same words, is `docs/research/2026-11-08-one-cell-at-a-time.md`'s.

---

## 3. External sources

### 3.1 Luanti (formerly Minetest) — static vs active objects

`doc/lua_api.md` (`staticdata`, `on_activate`, `on_deactivate`), `src/serverenvironment.cpp`
(`activateObjects`, `deactivateFarObjects`).
<https://github.com/luanti-org/luanti> · <https://api.luanti.org/>
**Licence:** LGPL-2.1-or-later (engine), media CC BY-SA. **Maintenance:** active (renamed from
Minetest in 2024, regular releases).

* **Well:** the pattern in production for twelve years. An object outside the active block range is
  not an object at all — it is a string of static data on the block, promoted by `on_activate` and
  demoted by `on_deactivate`. Server cost scales with *active* objects, not with existing ones,
  which is exactly this design's budget split.
* **Badly:** promotion is block-and-distance with **no sight term at all**, so entities appear at
  block boundaries — the very defect Karen reported. And a static object's time does not pass.
* **Adopted:** the two-tier split, and "cost scales with active". **Not adopted:** distance-only
  promotion; advancing a dormant animal.
* **FETCH, HONESTLY:** `api.luanti.org/objects/` and `api.luanti.org/entities/` are **404**, and
  `docs.luanti.org/for-creators/entities/` is **404**. The canonical `doc/lua_api.md` on
  `raw.githubusercontent.com` **does** fetch but the fetcher **truncates it before the entity
  lifecycle section**, so of this source only one sentence was read first-hand — *"Entities are
  active"* when their mapblocks are active, in "Map terminology and coordinates". The
  `staticdata` / `on_activate` detail is quoted from the design and from prior knowledge, **not
  re-read**, and nothing in our code depends on its exact wording.

### 3.2 OpenMW — a processing range, not an existence range

`apps/openmw/mwmechanics/actors.cpp`; the `actors processing range` setting.
<https://gitlab.com/OpenMW/openmw> · <https://openmw.readthedocs.io/>
**Licence:** GPL-3.0. **Maintenance:** active (0.49 series).

* **Well:** it separates *exists* from *is simulated* and keeps state for actors outside the range,
  so the world is not reset when you come back. **Fetched and quoted:** `actors processing range`
  defaults to **7168 game units** and *"specifies the actor state update distance from the player in
  game units. Actor state update includes AI, animations, and physics processing."*
* **Badly, and this is the useful half:** the docs also say *"Actors close to this distance softly
  fade in and out instead of appearing or disappearing abruptly"* — a **fade is a confession that a
  hard distance boundary pops**, which is this task's whole complaint, and it is the third option
  this design rejects by name (§2). Single-player, so there is no replication question and no
  "who can see this" at all.
* **Also fetched, and it is the walkers' precedent:** *"actors running Travel AI packages remain
  always active regardless of this distance setting"* — an actor with somewhere to be is exempt from
  the range rule, which is exactly `walkersPerDrive`.
* **Adopted:** a dormant animal keeps its identity and its plan (a RECORD holds the row, the kinds
  and the march order, so a group bedded late is still *that* group); and the travel exemption.
  **Not adopted:** the fade.

### 3.3 Left 4 Dead's population system (Michael Booth, Valve)

"Replayable Cooperative Game Design: *Left 4 Dead*", GDC 2009, plus the Valve Developer Community's
nav/population pages. <https://developer.valvesoftware.com/wiki/> ·
<https://www.valvesoftware.com/en/publications>
**Licence:** paper © Valve (readable, not reusable); VDC wiki CC BY-NC-SA 2.5. **Maintenance:** the
talk is **static (2009)**; the wiki is still edited.

* **Well:** the canonical statement of the rule this task is about. Confirmed in search, in these
  words: *"the Infected are spawned out of sight from the Survivors, and are de-spawned after the
  Survivors move out of range"*, over a navigation mesh with an **"Active Area Set" that follows the
  group, creating and destroying population as it moves**, and a **population cap** rather than a
  spawn rate. Both halves are this design's §6 and §5.
* **Badly:** it rests on a **baked** area-to-area visibility set, which this repo does not have and
  will not build — so our gate is one live ray per player, a weaker test, and it is admitted as such
  in the design's §16. And its rule exists so the player never *watches* the horde arrive; Karen's
  rule is stronger — she must be able to watch the animal **standing** afterwards, which is why a
  bed must also be *reachable by the line* and not merely hidden.
* **Adopted:** never place inside the visible set; cap the population, not the rate. **Not
  adopted:** precomputed visibility.
* **FETCH, HONESTLY:** `developer.valvesoftware.com` answers **403** to the fetcher (as it has for
  earlier notes in this repo), and the Valve publications page was not readable either. The
  quotations above are from a **search result summarising the talk**, not from Valve's own page, and
  the AiGameDev transcript that carries the detail is a **third-party** PDF
  (`cs.drexel.edu/~so367/teaching/2012/CS680/papers/11 Secrets about LEFT 4 DEAD's AI Director…`).
  Treated as editorial, exactly as `docs/research/2026-11-01-the-grid-map.md` treats its 403s.

### 3.4 Unreal Engine — `MassEntity` LOD and the Significance Manager

<https://dev.epicgames.com/documentation/en-us/unreal-engine/mass-entity-in-unreal-engine> ·
<https://dev.epicgames.com/documentation/en-us/unreal-engine/significance-manager-in-unreal-engine>
**Licence:** Unreal Engine EULA (source on GitHub under that licence; **not** open source).
**Maintenance:** active (UE 5.x).

* **THE DESIGN'S CLAIM FOR THIS SOURCE DOES NOT SURVIVE THE FETCH, and that matters for rule 2.**
  `docs/design/animal-placement.md` §10.4 says this source gives *"formal LOD tiers with a maximum
  count per tier"*. The Significance Manager page says the opposite in its own words: it
  *"provides a centralized framework that supports the ability to write flexible, project-specific
  code for evaluating and prioritizing Objects relative to one another"*, *"does not actually
  improve performance"*, and how significance is computed is *"custom-defined by the Objects
  themselves in game code"*. A per-type budget is named only as *"one possible use case"* —
  *"grouping similar Actors together and enacting a per-Actor-type budget"* — i.e. **the developer's
  code, not the engine's feature**.
* **So what is actually borrowed is the SHAPE and a precedent for it, not a mechanism:** a
  big-engine framework whose documented use case is a per-type budget is evidence that
  `LIVE_CAP` 24 / `bedCap` 12 / records is a normal way to spend a frame — and the cap itself is
  **ours**, written as such here rather than claimed as a borrow.
* **Badly:** an ECS framework with no Roblox analogue; its lowest tier still ticks a
  representation, so "costs nothing" is not on offer; importing its vocabulary into Luau would be an
  invented foundation (rule 2, and `docs/PROJECT_CONTEXT.md`'s *"invented foundations"*).
* **Adopted:** a per-tier count cap, as our own number with this precedent. **Not adopted:**
  anything structural.

### 3.5 Roblox Creator Documentation — instance streaming

<https://create.roblox.com/docs/workspace/streaming> ·
<https://create.roblox.com/docs/reference/engine/classes/Model#ModelStreamingMode>
**Licence:** CC BY 4.0. **Maintenance:** active.

* **Well, and fetched:** the authority for what a client is sent and when. *"During gameplay, a
  client may remove regions of BaseParts from the player's Workspace based on the behavior set by
  `Workspace.StreamOutBehavior`"* — **stream-out is the client's decision**, which is why no
  streaming radius may be in our rule. And the documented way to make a model arrive whole:
  *"If a Model is set to Atomic, all of its initial descendants are streamed in together when a
  descendant BasePart is eligible to be streamed in"*, and *"An atomic model is only streamed out
  when all of its descendant parts are eligible for streaming out, at which point the entire model
  streams out together."* Already relied on by `Places.plantOne`.
* **TWO NUMBERS CORRECTED.** The page's **defaults** are `StreamingMinRadius` **64** (*"Use the
  default of 64 to maximize how much the engine can scale the game down for low-end devices"*) and
  `StreamingTargetRadius` **1024** (*"Use the default of 1024 to strike a good balance…"*). The
  design's **384 / 512** are **Karen's Forest Test's measured values**
  (`docs/design/cell-loading.md` §3, 2026-11-08), not defaults — and
  `docs/research/2026-11-01-the-grid-map.md` already recorded the 1024 default. Nothing in this
  task depends on either pair.
* **Badly:** four of the five streaming properties **cannot be read from Luau** in this engine
  version — `tools/studio_mcp.py`'s `UNREADABLE` list, with three `NEEDS KAREN` entries in
  `ESCALATE.md` about setting one by hand. So no spec can assert the place's radii.
* **Adopted:** `Atomic` on the animal model (T3); streaming as **margin** for the client spec only.
  **Not adopted:** any streaming radius as part of the never-in-view rule.

---

## 4. The numeric targets T1 is judged on

T1 ships no behaviour: nothing in the live path reads `Placement.luau` and the
`PLACEMENT_IN_PLACE` flag is born OFF, so flag-off is byte-for-byte today's drive. Its targets are
therefore the **plan's own arithmetic**, every one of them a case in
`tests/server/forest_placement.spec.luau`:

| Target | Value | Where it comes from |
|---|---|---|
| groups planned, quiet / normal / busy | **9 / 13 / 15** | `SCHEDULE.DENSITIES` through `Data.slotAt`'s `keepAt` rule |
| animals planned (nominal) | **53 / 73 / 83** | the kept rows' own compositions, through `Boar.compositionSize` / `Boar.deerComposition` |
| deepest bed | `bandFar` = `beaterNorth − noticeAhead − SWEEP.MIN_AHEAD_STUDS` = **450** at 580 | design §4.2 |
| shallowest bed | `bandNear` = `max(neverStuds, REST.nearRoadStuds)` rounded up = **150** | design §6.2 |
| bed spacing | **37.5 / 25.0 / 21.4** studs | `(far − near) / (g − 1)` |
| the line finds a group every | **6.65 / 4.43 / 3.80 s** | `(far − near) / WALK_SPEED / (g − 1)` at the LIVE `Bots.CONFIG.WALK_SPEED` = `Grid.CONFIG.beaterWalkStudsPerSecond` **5.64** (task 327d2, 2026-11-09). The design's 12.1 / 8.1 / 6.9 is the same arithmetic at **3.1**, which that task superseded the day before the design was written -- so the design's *"releases finish at ~97 s"* is really **53 s**. MEASURED by the spec: *"placement normal: the line finds a group every 4.43 s"*. Against the 13 s Karen accepted this is the number that needs a decision, and it is in `ESCALATE.md` 2026-11-10 ~13:50 |
| `neverStuds` | **145** = `SPOOK.NOTICE_STUDS` 125 + `bedSpreadStuds` 40 / 2 | design §6.2 |
| min distance between two beds | ≥ **71** = `SPOOK.BEATER_STUDS` | design §4.2 |
| walkers per drive | **2**, the two shallowest beds | design §4.5, Karen's K-2 |
| ordering that must hold | `bedSpread` 40 < `bedGap` 71 < `never` 145 < `bandNear` 150 | design §13.1 case 4 |

**Measured for this note, which is why the gap rule needed building rather than asserting.** The
design's §4.2 says the 71-stud bed gap *"is carried by the lateral offsets, and `Placement.plan`
asserts it"*. It is not: at `normal` the beds are 25 studs apart in depth and slots 4 and 6 sit at
`offsetX` +45 and +95, which is **55.9 studs** apart in 3-D; at `busy` slots 5 and 8 at −75 and −95
are **67.3** apart. Both are inside 71. So `plan` **places** the bed rather than asserting about it:
it keeps the row's own depth and sweeps the lateral offset outward from the row's written `offsetX`,
in 1-stud steps inside `crossCapStuds` 95, to the first x that clears every bed already laid — and a
row for which no such x exists is **skipped with reason `nobed`, counted and printed** (design
must-not 3: never retried into a player's view). The assertion then holds by construction, which is
what the design wanted; only the mechanism is one line bigger. Reported to the Director rather than
silently diverging.

---

## 5. What this note did not verify

1. **No drive was run.** Every ms and heartbeat figure in §1 is quoted from task 342's measurements
   through `docs/design/animal-placement.md` §5.1; T1 adds no measurement of the running game,
   because T1 adds nothing to the running game.
2. **The Luanti entity lifecycle** was not read first-hand (§3.1): three of its URLs are 404 and the
   canonical file truncates before the section.
3. **Valve's own page** is 403 to every tool here; §3.3's quotations are second-hand (§3.3).
4. **Whether a bed at dz 450 is actually occluded from a stand** depends on each cell's planted
   wood. That is T3's measurement (`inView == 0`, `rays > 0`), not an arithmetic claim.
5. **`Boar.deerComposition`'s `CHANCE_PER_RELEASE`** can grow a deer party, so 53 / 73 / 83 are
   nominal — the spec asserts the nominal figures, which is what `plan` computes.
