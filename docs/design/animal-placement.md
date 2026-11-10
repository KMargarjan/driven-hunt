# Design: animal-placement — the animals are already standing in the wood, and the line finds them

Task 345. Architect. Input: `reviews/task-345/BRIEF.md`, which overrides anything older in `docs/`,
`TASKS.md` and every earlier design. Karen, 2026-11-10: *"animals has to be in palces not just apear
magically"* and *"animal patter is ok but as I mentioned we need to have them not magically apearing
it has to be there then it spooked or it walkks towards"*.

This document designs **one system**: which animals exist in a drive of the Forest Test world, where
they are standing before anybody can see them, and what turns a standing animal into a moving one.
It designs no new animal, no new AI state, no new client file and no new place.

Deltas to `docs/design/grid-map.md` §9.2, `docs/design/forest-drive.md` §3/§7.2 and
`docs/design/cell-loading.md` are in §14, as exact text.

---

## 1. What it must do, and what it must not do

### 1.1 Must do

| Must | Why |
|---|---|
| **Every animal a player can see was in the world before that player could see it** | BRIEF decision 1. Today `ForestTest.releaseLine` calls `runtime:spawn` on each scheduled group at `Data.releaseDepth(...)`, whose floor is `SCHEDULE.minNorthStuds` **25 studs** north of the road, and whose shallowest table row is slot 4 at `northStuds = 85`. 25 studs is inside the lane a hunter is looking down. That is the magic |
| **The per-cell patterns survive whole** — `Grid.CELLS[i].animals` (`density`, `startDepth`, `routeBias`, `restZones`), `ForestTest.SCHEDULE`'s fifteen rows, `Data.slotAt`'s dial, `ROUTE_BIAS`, `Data.wavePoint` | BRIEF decision 2. Karen: *"animal patter is ok"*. The schedule still decides WHEN a group moves and WHERE it breaks out; it stops deciding when the group comes into existence |
| **Two ways to the line, both from a place the animal already stood**: (a) **spooked** — lying up in cover, the line reaches it, it breaks; (b) **walks toward** — it stands up on its own slot's clock and walks at the road ahead of the line | BRIEF decision 3, Karen's own two words |
| **A placed animal that has not been woken costs close to nothing** | BRIEF decision 4. §5 says exactly what "nothing" is: a Luau row, **zero instances, zero parts, zero milliseconds of `Runtime:step`** |
| **One owner of "which animals exist in this drive and in what state", named** | BRIEF decision 6, rule 3. §3 |
| **The client must not see an animal pop in** | BRIEF decision 7. §7 |
| **A testable predicate for "never in view"**, with a counter that reads 0 or says why not | BRIEF: the measurement plan. §6, §12 |
| Only the stag leaps (task 339); the out-of-play despawn (task 342) stays | BRIEF decision 5. Both untouched: §9.4 |

### 1.2 Must not

1. **Must not create an animal within `PLACEMENT.neverStuds` of any player's character**, at any
   distance, for any reason. No fallback, no "place it anyway and let the sweep catch it" — task 168
   took that path and Karen saw the result twice (`REST`'s own header).
2. **Must not create an animal a player has a clear line of sight to.** The sight test is a
   **refusal**, and the bed search is the fallback, exactly as `restSpot`'s ring search is today.
3. **Must not re-stock inside a drive.** Task 172's rule survives word for word: *"a wood is beaten
   once; when it is empty it stays empty for this drive"*. A group that could not be bedded is
   **skipped for that drive, counted and printed** — never retried into a player's view.
4. **Must not place or wake anything behind the beater front.** `Data.sweepCatches` and
   `Data.lineFrontAt` are unchanged and are still the one answer to "behind the line".
5. **Must not be a second writer** of a body (`Boar.Runtime`), of a character (`Match.Body`), of the
   wood (`ServerScriptService.Places`), of which cell is live (`ForestTest.promote`), or of the
   drive's phase (`ServerScriptService.Match`).
6. **Must not yield inside the `markers` closure.** `ForestTestBoot`'s `world.markers` runs from
   inside `Match`'s `dispatch`, whose contract is *"it MUST NOT YIELD"* (`Match.measureMarkers`).
   The plan is pure and goes there; the raycasts and the spawns go in Heartbeat bites (§4.4).
7. **Must not anchor a bedded animal.** `REST.canopySlackStuds` is 6, so a measured bed can be six
   studs off the real surface; an anchored animal there is a boar floating in the air, which is the
   previous project's purple-legs failure in a new shape (`docs/PROJECT_CONTEXT.md`).
8. **Must not keep two animal populations.** `state.rest` (beater mode, `REST.groups`) and
   `state.lines` (hunter mode, `releaseLine`) become **views of one roster** (§3.2). Two populations
   with two spawn paths is *"two correct pieces of code disagreeing"*.
9. **Must not read a streaming property from Luau.** `StreamingMinRadius`, `StreamingTargetRadius`,
   `StreamingIntegrityMode`, `StreamOutBehavior` and `ModelStreamingBehavior` all answer *"not a
   valid member of Workspace"* (`tools/studio_mcp.py`, `UNREADABLE`). No streaming radius is in the
   predicate (§6.2).
10. **Must not tag anything `DrivenHunt.*` in the forest** (`forest-drive.md` §1.2 item 3).
11. **Must not produce a silent wrong answer**: no bed at the origin, no group reported placed that
    has no body, no counter that is 0 because nothing wrote it (§12.3).

---

## 2. The pattern adopted

**A record is the truth; a body is a view of it.** Every animal of a drive exists from the drive's
first frame as a **row in a roster**. A row acquires a **body** only when the drive needs one, and
only at a moment and a place no player can perceive. A body is destroyed back to nothing when the
animal is out of play (task 342, unchanged).

That is Luanti's *static vs active object* split (§10.1), with Left 4 Dead's *never spawn inside the
survivors' visible set* as the promotion gate (§10.3) and Unreal's *per-tier maximum count* as the
budget shape (§10.4). Sources, licences and what each gets wrong: §10.

**Borrowed from inside this repo, and said so (rule 2):**

| Borrowed | From | For |
|---|---|---|
| plan in the closure, spend the work in Heartbeat **bites** | `Cells.begin` + the drain loop, task 343 (`src/server/Places/Cells.luau`) | the stocking must not stall a frame; the swap already solved this |
| the ring search for a spot in cover | `ForestTest.restSpot` (`searchRings` 4 × `searchStepStuds` 16) | finding a bed, unchanged machinery, one new refusal |
| the pure-rule / measured-world split | `ForestTest.restSpotOk` vs `restSpot`, `Data.stockStep` vs `stepRest` | §4.1's module boundary |
| `ModelStreamingMode = Atomic` on a model that must arrive whole | `Places.plantOne` (`src/server/Places/init.luau`) | §7.2 |
| the world-provides / owner-decides injection | `forest-drive.md` §2, `Boar.newRuntime(world)`, `Weapon.setDriveLineProvider` | the readers `Placement` is handed |
| the Studio-only probe attribute | `Runtime:step`'s `DHBoarHistory` | §12.3's counters |

**No new foundation is invented.** There is no pooling layer, no ECS, no second scheduler and no new
scene graph. The roster is a Luau array; the body is the `Boar.Runtime` entry that already exists.

---

## 3. Ownership — one writer each, named

### 3.1 The table

| System | Owner (the only writer) | Location |
|---|---|---|
| **Which animals exist in this drive and in what state** — the roster, every bed, every state transition, every counter | **`ServerScriptService.ForestTest`** — unchanged owner, extended statement. `state.roster` is its new state and nothing else writes it | `src/server/ForestTest/init.luau` |
| The **pure rules** of placement: the roster plan, the bed depths, the wake rule, the budget door, the distance half of the never-in-view predicate | **`ReplicatedStorage.ForestTest.Placement`** — NEW, pure, no Instance, no raycast, no clock. It owns no state | `src/shared/ForestTest/Placement.luau` |
| An animal's **body and brain** | `ServerScriptService.Boar` (`Runtime`, `Body`, `Brain`) — unchanged, and still the only thing that creates, moves or destroys an animal Instance | `src/server/Boar/` |
| Where a **character** stands | `ServerScriptService.Match.Body` — unchanged. This system only READS `player.Character` | `src/server/Match/Body.luau` |
| Which **cell** is live, and when | `ServerScriptService.ForestTest` (`promote`, `layoutForDrive`) — unchanged | `src/server/ForestTest/init.luau` |
| Which cell's **wood** is in `Workspace` | `ServerScriptService.Places.Cells` — unchanged | `src/server/Places/Cells.luau` |
| The **cell's pattern** (`density`, `startDepth`, `routeBias`, `restZones`) | `ReplicatedStorage.Grid` — frozen data, unchanged | `src/shared/Grid/init.luau` |
| The **drive's phase and boundary** | `ServerScriptService.Match` — unchanged | `src/server/Match/init.luau` |
| The wiring | `src/server/ForestTestBoot.server.luau` — boot line only; owns nothing, decides nothing | — |

**Why the owner does not move.** `forest-drive.md` §3 already names
`ServerScriptService.ForestTest` as the owner of *"the forest's animals: when a wave exists, when the
wood is stocked"*. This task **widens that sentence and moves no boundary**, which is the cheapest
possible answer to rule 3. A new `ServerScriptService.ForestTest.Animals` module was considered and
rejected: it would have to own the roster, the spook rule, `stepLines` and the spawn path — about
1,050 lines moved out of the file that writes `state` — and for the whole of that move there would be
two modules that could plausibly write an animal's state. `ForestTest.Line`, `ForestTest.Markers` and
`ForestTest.Seats` are already submodules of this owner; `Placement` is the fourth, and it is the
*pure* one, so it cannot write anything by construction.

### 3.2 The two populations become one, and that is the point

Today:

* `ForestTest.stockWood` spawns `Data.REST.groups` — **36 animals in ten groups** — on the first
  heartbeat of `beaterMode()`, into `state.rest`.
* `ForestTest.releaseLine` spawns a scheduled group per slot into `state.lines`.
* `ForestTest.step` picks one or the other on `ForestTest.beaterMode()`.

So a hunter's drive and a beater's drive have **different animals, placed by different code, at
different times, under different rules** — and the thing Karen asked for already exists in one of
them and not the other. `ESCALATE.md` 2026-11-10 ~04:30 measured the cost of the split: *"36 > 24
with no drive in it at all"*, live jumping 9 → 60 in one ten-second sample at the second drive's
opening.

After this design there is **one roster**, built from the schedule and the cell's row, used by both
roles. `state.rest` and `state.lines` are **views over it** (`state.lines` keeps the file/trail
bookkeeping of a group that is under orders; a row's `lineId` points at it). `Data.REST.groups` is
**archived** under rule 7 with a note: the band, the lane offsets and the ten depths it encodes are
reproduced by `Placement.plan` from the fifteen rows, and keeping the table would be a second answer
to "where does a group lie up".

---

## 4. The design

### 4.1 Four states, and only two of them cost anything

```
          plan (drive boundary)        materialise                wake                 out of play
  (nothing) ───────────────────▶ RECORD ──────────▶ BEDDED ──────────────▶ AWAKE ──────────────▶ GONE
                                   │  0 instances      │  a body, calm,       │  under orders       │
                                   │  0 parts          │  no route            │  (a route, or a     │
                                   │  0 ms             │                      │   flight)           │
                                   └── skipped, counted ──────────────────────────────────────────▶ GONE
```

| State | What it is | Cost |
|---|---|---|
| `RECORD` | a row in `state.roster`. Nothing exists in the world | **0 instances, 0 parts, 0 ms of the boar step.** `Runtime:step` iterates `self._boars`, and a record is not in it |
| `BEDDED` | a real `Boar.Runtime` group, standing in cover, no route, `CALM.ENABLED`'s graze/stand/lie repertoire | a full Runtime entry: **0.19–0.22 ms/step/animal** (§5) |
| `AWAKE` | the same bodies, under orders: a `state.lines` file walking a route, or a flight from `Runtime:spook` | the same 0.19–0.22 ms, plus its path requests |
| `GONE` | shot, crossed, or despawned by `Brain:_outcome` (task 342) | 0 |

**The honest headline, because the BRIEF asks for it in parts and ms:** a *dormant* animal is a
RECORD and costs **nothing measurable**; a *bedded* animal is a BODY and costs **the same as a
running one**. There is no cheap-body tier and this design does not invent one — `Runtime:step`'s
per-animal loop does the snapshot, `Body.followGait`, the history ring, `Wound.advance` and the
`PACE` whiskers for every entry whatever it is doing. So the budget is spent on BODIES, and the
design's job is to keep the number of bodies small while the number of *placed* animals is large.
That is exactly what the record tier buys: **73 placed, ≤ 24 with a body.**

### 4.2 The roster: who is in the drive, and where each group lies up

Built once per drive, at the drive boundary, by `Placement.plan`. Pure.

* **WHO** — the fifteen rows of `Data.SCHEDULE.drive`, filtered by the live cell's `density` through
  `Data.slotAt` (unchanged). `Boar.compositionSize` / `Boar.deerComposition` still answer the size,
  and this file still never writes the word "stag".
* **WHERE IT BREAKS OUT** — the row's `crossOffset` through `routeBias` / `ROUTE_BIAS`, and the
  route word (`STRAIGHT`, `LATERAL`, `BREAK-BACK`, `SPLIT`, `HOLD`, the stag's `sneak`). Unchanged.
* **WHERE IT LIES UP** — new, and the whole of this design's geometry:

```
bandFar  = beaterNorth − noticeAheadStuds − SWEEP.MIN_AHEAD_STUDS     = 580 − 100 − 30 = 450
bandNear = max(PLACEMENT.neverStuds, REST.nearRoadStuds)              = max(145, 40)   = 150  -> 150
bedNorth(n) = bandFar − (n − 1) × (bandFar − bandNear) / (g − 1)      -- DEEPEST SLOT FIRST
```

with `g` = the dial's group count (`DENSITIES`: quiet 9 / normal 13 / busy 15), `n` the slot's
ordinal among the groups the dial kept, `beaterNorth` = `ForestTest.beaterNorthStuds()` (580) and
`noticeAheadStuds` = `Data.noticeAheadStuds(SPOOK, layout)` (100).

**Why deepest first, and it is not a preference.** The line musters at dz 580 and walks SOUTH at
`Bots.CONFIG.WALK_SPEED` 3.1 studs/s. Whatever the schedule says, the first animals the line can
possibly reach are the **deepest** ones. The current acts run the other way (act I at dz 85–150, act
III at dz 145–360) because the current code *spawns* a group wherever the row says and clamps late
rows forward to `lineNorth − leadStuds` — which is why act III's rows were measured being released
*behind* the men meant to be pushing them (task 251c). With the animals already in place there is
nothing to clamp: **`Data.releaseDepth`, `SCHEDULE.leadStuds` and `minNorthStuds` lose their only
caller** and are archived with the behaviour they bounded (rule 7). The row's `northStuds` becomes
documentation of the drive's *intent*, and `Placement.bedNorth` is the depth.

**What the slot number now means.** A slot is an **ordinal in the wood from the back**, and its
`atSeconds` is the time the line is expected to reach it. The two agree by arithmetic rather than by
hope:

```
lineReaches(d) = (bandFar − d) / WALK_SPEED        -- seconds from the drive opening
```

| density | g | bed spacing | first bed reached | last bed reached | interval |
|---|---|---|---|---|---|
| quiet | 9 | 37.5 studs | 0 s (dz 450) | 96.8 s (dz 150) | **12.1 s** |
| normal | 13 | 25.0 studs | 0 s | 96.8 s | **8.1 s** |
| busy | 15 | 21.4 studs | 0 s | 96.8 s | **6.9 s** |

So the dial stops being "how many of fifteen slots fire" and becomes **how often the line finds
something**, which is a better dial and is free. `SCHEDULE.intervalSeconds` 13 stops being the
metronome and becomes the *walker* spacing (§4.5).

**Two numbers that follow from this and are Karen's and the Director's, not mine (§15, D-1 / K-1):**
the releases finish at ~97 s of a 300-second drive, and `normal` is now busier per second than the
drive Karen accepted. Both move with one data row — `BEATER.behindLineStuds` 400 → 520 puts the
muster at 700, which `BEATER`'s own measurement says the wood holds (*"700 WOULD ALSO FIT THE
WOOD"*; the trees run out at 775–850 studs), giving a band of [150, 570], releases spread over
10–145 s and a 232-second flat walk against `DRIVE_SECONDS` 300.

* **Lateral and lane** — the row's `offsetX` biased by `routeBias`, capped at `crossCapStuds` 95,
  and `laneOffset` dealt by `ForestTest.beaterLaneOffset` exactly as `REST.groups` does today, so a
  bed belongs to a lane and can be judged by what that lane will see of it.
* **The cover** — `restZones` of the live cell, through `Places.zoneIndexAt`, and the four-pass
  order `(zone AND seen) > zone > seen > any` that task 327h round 3 settled. Unchanged.
* **No two beds inside `PLACEMENT.bedGapStuds`** (= `SPOOK.BEATER_STUDS`, 71) in 3-D, because the
  fright latches and two groups inside the flush reach both bolt on one approach — `REST.groups`'
  own measured rule (min pair 101.3 studs over 45 pairs). With 25-stud depth spacing at `normal`
  this is carried by the lateral offsets, and `Placement.plan` **asserts it** rather than hoping.

### 4.3 Materialise: a record gets a body

Level-triggered, once per Heartbeat, at most one group per step:

```
A record is DUE when   lineReaches(bedNorth) − now ≤ PLACEMENT.leadSeconds        (default 20)
                 or    it is one of this drive's walkers and its slot time is within leadSeconds.

It is MATERIALISED when, in this order:
  1. the budget has room:   Placement.roomFor(bodies, size, LIVE_CAP) and bedded + size ≤ bedCap
  2. the bed is found:      ForestTest.restSpot-style ring search in the group's zones
  3. the bed is HIDDEN:     ForestTest.bedHidden(spot) is true for EVERY player        (§6)
  4. the bed is in front:   not Data.sweepCatches(frontZ − spot.Z, sweepDepth, SPOOK)  (unchanged)
Otherwise it is SKIPPED for this drive, counted in stats().skipped[reason], and printed once.
```

`leadSeconds` 20 is derived: the line covers 62 studs in 20 s, which is well inside the 100-stud
notice band, so a group always has a body before anything can notice it, and no body exists more
than 20 s before it is needed. It is the one number that trades bedded-at-once against "bedded in
time", and `bedCap` (§5) is what it is traded against.

**A skipped group is a hole in the wood, and it is REPORTED, not hidden.** `stats().skipped` and one
console line per skip, with the reason (`budget`, `nobed`, `inview`, `behindline`). §12 makes
`skipped` a measured target, not a hope: *skipped-for-`inview` per drive = 0 at a stand*.

### 4.4 Where the work happens, and why it is in bites

| When | What | Where |
|---|---|---|
| the `Assigning` edge, inside `world.markers` | `ForestTest.layoutForDrive` (unchanged) → `ForestTest.planDrive(now)`. **Pure: no raycast, no Instance, no yield** | `ForestTestBoot`'s `markers` closure, one line after the layout deal |
| the `Assigning` edge, `promote` | the previous drive's bodies go (`retire` + `runtime:clear("layoutChanged")`, unchanged) and `state.roster` is replaced | `ForestTest.promote` |
| every Heartbeat, from the drive boundary on | `ForestTest.stepPlacement(now)` — **at most one** group materialised, **at most one** ring search, **at most `#Players`** rays | `ForestTest.step`, before `spookNearBeaters` |
| every Heartbeat | `spookNearBeaters` (unchanged) then `stepLines` (unchanged) | `ForestTest.step` |

The bite loop is `Cells.begin`'s shape, for `Cells.begin`'s measured reason: the whole-folder write
it replaced *"cost 738 ms of frame in Karen's place"* (task 343). A ten-group ring search with two
raycasts and an overlap query per candidate, over five rings of eight, is the same order of work.

**`ForestTest.beaterMode()` stops choosing a population.** `ForestTest.step`'s
`if ForestTest.beaterMode() then return ForestTest.stepRest(...)` branch goes, and both roles run
the one path. `beaterMode` keeps its other readers; `Data.stockStep`, `state.restStocked` and
`state.restTriedAt` are archived with the branch (rule 7).

### 4.5 Wake: a bedded animal starts moving

```luau
Placement.wakeReason(row, elapsed, frontNorth, spook) -> ("beaters" | "slot")?
```

| Trigger | Rule | Who implements it |
|---|---|---|
| **spooked** (the default; every group has it) | the line's notice band reaches the bed, then `SPOOK.ALERT_SECONDS` 2 of standing and looking, then the flush — `Data.encounterStage`, `Runtime:notice`, `Runtime:spook`. **Not one line changes** | `ForestTest.spookNearBeaters`, unchanged |
| **walks toward** (`PLACEMENT.walkersPerDrive`, default **2**) | the two SHALLOWEST beds of the roster stand up on the slot clock — `firstSlotSeconds` 10 and `+intervalSeconds` 13 — and are handed their route with nobody pushing them. They are what the hunter sees in the first 30 seconds, before the line has reached anything | `ForestTest.orderGroup` |
| **a shot nearby** | `Runtime:hearShot` → `Brain:spook`. Already true for a bedded animal, because a bedded animal is a real body in the world | `Boar.Runtime`, unchanged |
| **the horn** | `Runtime:hearHorn` at `Horn.SPOOK_STUDS` / `Horn.SIGNAL.SPOOK_STUDS`. Same | `Boar.Runtime`, unchanged |

**Two walkers and not thirteen, and the reason is geometric.** A group that stands up and walks south
with no beater behind it is, to `Brain:_outcome`, a group *"the drive let go of"* — 80+ studs north
for 60 s is task 342's `settled` despawn. More than a couple of them is a wood walking out of itself.
Two is the opening of a drive; the rest is the line's work. The number is Karen's (§15, K-2).

### 4.6 `releaseLine` keeps its route half and loses its spawn half

This is the one substantial change to existing code, and the split is clean because the function
already computes **the routes before a single animal exists** (its own comment: *"THE ROUTES COME
FIRST, BEFORE A SINGLE ANIMAL EXISTS"*, after `ComputeAsync` was measured failing from inside a pile
of freshly-spawned colliders).

| Half of `releaseLine` | After |
|---|---|
| the slot, the row, the owed deer row, the deer cap, the composition, the kinds, the march order | **moves into `Placement.plan`** — decided once per drive, at the boundary, where a held-over party and the deer cap are one decision instead of fifteen |
| the depth clamp (`Data.releaseDepth`, `routeFloor`, `clampedToLine`) | **retired**, archived (rule 7). The bed is the depth |
| `computeRouteVia`, the pins, `Line.split`, `formSounder`, the trail seed, the pace and speed | **kept, as `ForestTest.orderGroup(row, now)`**, operating on bodies that already exist |
| `runtime:spawn` per member along the approach | **gone.** The bodies were made at materialise time, in cover |
| the `SLOT` console line | **kept**, with the bed's depth and the front's depth in place of `startNorth`/`lineNorth` |
| `Data.repeatRoomFor` and the repeat window (`repeatFrom` 6 .. `repeatTo` 12) | **retired**, archived (rule 7). §5.3 |
| `stagedLine` / `Data.stagedRow` (the Director's instrument) | **kept, and it keeps a spawn path**, Studio-only (`RunService:IsStudio()`). An instrument that must put a stag out NOW cannot wait for a bed. It is named here so nobody reads it as a hole |

**The one real technical risk, named with its measurement.** Today a file is spawned *along* its
approach so station *k* exists on the first step, and the trail is seeded with the points the
followers are already standing on. That fix is why the line forms at all: with an empty trail the
measured nose-to-nose median gap was **9.6 studs against a `spacingStuds` of 3** (task 127). A woken
group is standing in a loose bed, not in a file. `orderGroup` must therefore seed the trail from the
**leader's own position backwards along the first leg of the route**, and the followers walk up to
their stations over the first few seconds. **Target: a formed file within 5 s of the break, median
nose-to-nose gap ≤ 2 × `LINE.spacingStuds` (17 studs).** Measured, not assumed — §12.

### 4.7 The bed is tighter than the old ring

`PLACEMENT.bedSpreadStuds = 40`, against `REST.spreadStuds` 90. Ninety studs is the ring
`spawnSounder` spreads a *released* sounder over so nine animals do not spawn inside each other;
forty studs (11 m) is a group **lying up**, and it is what makes `bedGapStuds` 71 meaningful — two
beds 71 studs apart whose groups are each 90 studs wide are one group. Nine animals on a 40-stud ring
are 14 studs apart, well clear of `Boar.bodyAvoidRadius`.

---

## 5. The budget, restated (the Architect's answer to `ESCALATE.md` 2026-11-10 ~04:30)

### 5.1 The measurement that forces the restatement

Task 342 fitted the step cost from two points per cell, same instrument, same place:

```
C1 normal: (26.3 live, 6.45 ms) and (13.6 live, 4.03 ms)  ->  0.191 ms/animal + 1.44 ms fixed
D1 quiet : (19.3 live, 5.44 ms) and (13.4 live, 4.13 ms)  ->  0.222 ms/animal + 1.16 ms fixed
```

`grid-map.md` §9.2 asks for **≤ 24 live AND ≤ 4.0 ms average**. The fit says 24 live is 6.0–6.5 ms,
and 4.0 ms is ~13 live. The two numbers do not meet, and the escalation asked the Architect to move
one.

**Decision: the ms ceiling moves; the live count does not.** The reason is option 3 of the 327h
escalation, which is correct: **4.0 ms was never measured for this runtime.** It is
`src/server/Bots/init.luau`'s number, borrowed, for a system that steps characters with no brain, no
wound, no sounder and no whiskers. The number that has actually been measured in the place Karen
plays is the **server heartbeat**: 36.35 ms p95 before task 342, 32.05 ms after. The server is
running at ~31 Hz for reasons that are mostly not the animals, and the animal step is 13 % of that
frame. So the ceiling is set as a share of a measured frame, not as an aspiration:

### 5.2 The numbers

| What | Target | Derivation |
|---|---|---|
| **animals with a BODY at any instant** | **≤ 24** (`Data.LIVE_CAP`, unchanged) | `grid-map.md` §9.2's own number. It is not raised: the thing that broke it was the repeat window (§5.3), not the cap |
| of which **BEDDED** (a body, not under orders) | **≤ 12** (`PLACEMENT.bedCap`) | at `leadSeconds` 20 and `normal`'s 8.1 s interval, 2–3 groups are bedded-and-not-yet-woken; 12 animals is four groups of three and leaves half the cap for the ones crossing |
| **hard ceiling** | **`Data.MAX_BOARS` = 60**, unchanged | `Runtime:spawn` asserts past it, so every door is checked before the spawn |
| **boar runtime step, average over one drive** | **≤ 7.0 ms** (was 4.0) | `0.222 × 24 + 1.44 = 6.77`. 7.0 ms is **22 % of the 32.05 ms heartbeat measured at task 342's code commit** |
| **boar runtime step, peak within one drive** | **≤ 20 ms** (was 8.0) | the per-drive reset task 342 built. The 74–92 ms figures in `ESCALATE.md` are session high-water marks set by a spawn frame, which is not the number to act on |
| **server heartbeat p95** | **≤ 32 ms** — no worse than `342-cc-C1b` | the same instrument both sides. This is the number that decides whether the game lags, and the one Karen can feel |
| **dormant RECORDS** | **≤ 120 rows**, costing **0 instances, 0 parts, 0 ms of the boar step** | 15 slots × ≤ 9 animals = 135 animals in ≤ 15 group rows. `Runtime:step` never sees them |
| **animal parts** | **< 2,000** | 24 bodies × ~24 descendants = 576. Measured 1,025 at 44 live |
| **groups PLACED per drive** | **9 / 13 / 15** (quiet / normal / busy) | the dial, unchanged |
| **animals PLACED per drive** (nominal) | **53 / 73 / 83** | the fifteen rows' own sizes at each `keepAt`: quiet = slots 1,2,3,4,6,7,9,11,14 (1+5+6+7+6+9+8+6+5); normal adds 8,12,13,15 (+1+7+6+6); busy adds 5,10 (+8+2). `Boar.deerComposition`'s `CHANCE_PER_RELEASE` can add to a deer party, so these are nominal |
| **spawns in view of a player, per drive** | **0** | §6, §12. The new number this task exists for |
| **groups skipped for `inview`, per drive** | **0** at a stand | a skip is a hole in the wood; `nobed` and `budget` skips are tolerated and counted |
| **min distance between two beds** | **≥ 71 studs** (`SPOOK.BEATER_STUDS`) | asserted in `Placement.plan` |

### 5.3 Where the overrun actually came from, and why this design removes it

`ESCALATE.md` 2026-11-10 ~00:35 named it: *"past the end of the script,
`SCHEDULE.repeatFrom..repeatTo` releases a group every 13 s for the rest of the clock, and nothing
despawns a group that is still walking. So live animals climb to the `MAX_BOARS` ceiling in EVERY
cell at EVERY density — the **quiet** cell D1 reached **55**."*

**A fixed roster has nothing to repeat.** The drive holds 53/73/83 animals and not one more, and
`Data.LIVE_CAP` is enforced at the materialise door instead of at a release door. The repeat window,
`Data.repeatRoomFor` and the `slot > #rows` branch of `Data.slotAt` are archived (rule 7) with this
paragraph as the reason. The second half of the overrun — `REST.groups`' 36 animals stocked in one
heartbeat — goes with `REST.groups` (§3.2).

---

## 6. "Never in view", as a predicate a spec can fail

### 6.1 The rule

```luau
-- src/shared/ForestTest/Placement.luau -- PURE. The DISTANCE half.
-- `eyes` is one point per player who HAS a character; a player with none is not an observer.
function Placement.clearOfEyes(spot: Vector3, eyes: { Vector3 }, neverStuds: number): (boolean, number)
    -- false and the offending distance when ANY eye is inside `neverStuds`. 3-D, not flat: a hunter
    -- on a high seat deck is 12.5 studs up and that distance is real.
end
```

```luau
-- src/server/ForestTest/init.luau -- the MEASURED half. One ray per player, and only for a spot
-- the distance test has already passed.
function ForestTest.bedHidden(spot: Vector3): (boolean, string?)
    -- for each player with a character:
    --   1. Placement.clearOfEyes failed            -> false, "within 145 studs of <name>"
    --   2. a ray from the character's head to the spot + sightTargetStuds is CLEAR
    --      (RespectCanCollide = true, Boars excluded, terrain INCLUDED, a character is not a screen)
    --                                              -> false, "in sight of <name>"
    -- otherwise                                    -> true
end
```

The ray is `ForestTest.restSeenFromLane`'s machinery with the origin changed from the beater's lane
to each player's head, and the sense inverted. Its rules are already measured and written down there:
`RespectCanCollide = true` because *"this forest is mostly ferns and leaf cards that a man sees
straight through"*; the terrain is **not** excluded because *"a rise between the lane and the group
hides the group, and a ray that flew through it would answer 'seen' over a hill"*; and
`Data.characterOf(hit.Instance) ~= nil` means a body is not a screen.

### 6.2 The numbers, and where they come from

| Number | Value | Derivation |
|---|---|---|
| `PLACEMENT.neverStuds` | **145** | `SPOOK.NOTICE_STUDS` 125 + `bedSpreadStuds` 40 / 2. Inside the notice reach an animal would already be reacting to her, and half the bed spread is how far the nearest member of the group can be from the point that was tested. `forest_placement.spec` asserts the RELATION, never the literal |
| `PLACEMENT.bandNearStuds` | **150** | `max(neverStuds, REST.nearRoadStuds)`, rounded up. **This is the consequence that must be said out loud:** with `crossCapStuds` 95 capping a bed's lateral offset, a bed shallower than 145 studs is inside `neverStuds` of a hunter on the nearest stand by arithmetic (`sqrt(145² − 95²)` = 110 < 145 at any depth under 110). **So the near 150 studs of the cell hold no bedded animal.** That ground is *crossed*, not inhabited |
| rays per step | **≤ `#Players`** (≤ 16) | one materialise attempt per Heartbeat, one ray per player, and only after the distance test |

### 6.3 Why no streaming radius is in the predicate

`cell-loading.md` §3 measured Karen's Forest Test on 2026-11-08: `StreamingEnabled` true, **min 384 /
target 512**. Beyond 512 studs the client is not sent an instance at all, so a body created there
*cannot* pop in — it streams in later exactly as a tree does.

**That fact is used as MARGIN and never as the rule.** Putting 512 in the predicate would make the
guarantee depend on a place property that **no tool and no spec can read** (`tools/studio_mcp.py`,
`UNREADABLE`: all five streaming properties answer *"not a valid member of Workspace"*), and whose
error direction is unsafe: a datum larger than the real radius would skip the sight test for a client
that *can* be sent the body. So the predicate is distance plus occlusion at every range, and the
streaming radii are quoted in exactly one place — §7.3, where they make the **client spec** valid.

---

## 7. The client, and "it must NOT pop in" (BRIEF decision 7)

### 7.1 No client file changes

There is no client code in this system and none is added. `Workspace.Boars` is replicated by the
engine; `Hud` draws no animal; `Match`'s snapshot carries counts, not bodies. Said here so nobody
adds a client module.

### 7.2 What a client sees, case by case

| Case | What the client is sent | What the player sees |
|---|---|---|
| a RECORD | **nothing.** There is no instance | nothing |
| a bed materialised **> 512 studs** from this client's character | nothing at that moment. The model arrives when the region streams in | the animal is simply there when the wood around it is there. No event |
| a bed materialised **≤ 512 studs** and out of sight | the model arrives immediately, behind trees or a rise | nothing, until she walks or looks round a trunk — and then an animal **standing** in cover, which is Karen's *"it has to be there"* |
| a bed materialised **≤ 512 studs** and in sight | **forbidden.** `bedHidden` refuses; the group is skipped and counted | — |
| a bed inside **145 studs** | **forbidden** at any sight answer | — |
| the local character is **respawned** at the drive boundary (`placePlayers` → `LoadCharacter`) | everything within `StreamingMinRadius` 384 of the new position arrives at once | a wood that already has animals in it. This is the *good* case and it is the one the drive boundary gives for free |

**One property is set that is not set today:** every animal model gets
`ModelStreamingMode = Enum.ModelStreamingMode.Atomic` at spawn, so it arrives **whole** rather than
limb by limb. Borrowed from `Places.plantOne`, which sets it on a tree for the same reason.
`Persistent` is explicitly **refused**: a persistent animal is sent to every client regardless of
distance, which would defeat the whole design.

### 7.3 Why the client spec is sound

`StreamingMinRadius` is **384** and `PLACEMENT.neverStuds` is **145**. Everything inside 384 studs of
a character is always loaded, so an instance **cannot arrive by streaming** inside 384 studs of a
settled character. Therefore: **any arrival inside 145 studs is a creation, and it is a failure.**
That is a 239-stud margin between the rule and the only mechanism that could produce a false
positive, and it is what makes `tests/client/animal_placement.spec.luau` (§13.2) a real test rather
than a restatement of the server's own opinion.

The one exception is honest and handled: when the local character is respawned or teleported, a whole
384-stud sphere arrives at distances from 0 upward. The spec therefore ignores arrivals within
`SETTLE_SECONDS` (3) of a `CharacterAdded` or of a single-frame position jump over 100 studs, and
**says how many it ignored**, so a drive in which it ignored everything cannot read as a pass.

---

## 8. The public interface

### 8.1 `ReplicatedStorage.ForestTest.Placement` — new, pure

```luau
-- src/shared/ForestTest/Placement.luau
-- PURE: no Instance, no raycast, no os.clock, no RunService. Requires NOTHING (the caller hands in
-- every table), which is what keeps it out of `tools/terrainbake.py`'s require rewrites and makes
-- every rule drivable from a spec with hand-written numbers.

export type RowState = "record" | "bedded" | "awake" | "gone"
export type WakeReason = "beaters" | "slot" | "shot" | "horn"
export type SkipReason = "budget" | "nobed" | "inview" | "behindline"

export type RosterRow = {
    id: string,                 -- "g<drive>-s<slot>", stable for the drive, printed in every line
    slot: number,               -- the schedule row's slot (0 = a staged release)
    act: number,
    row: any,                   -- the frozen schedule row: species, party/composition, route, pace…
    size: number,               -- nominal members (Boar.compositionSize / deerComposition)
    kinds: { string },          -- decided once, at plan time, in march order
    bedNorth: number,           -- dz north of the road: WHERE IT STANDS
    bedOffsetX: number,         -- studs from the stand the drive aims at, after routeBias
    laneOffset: number,         -- which beater lane this bed belongs to
    zones: { number }?,         -- the cell's restZones, or nil for "any legal spot"
    walker: boolean,            -- true for this drive's walkersPerDrive shallowest groups
    wakeAtSeconds: number,      -- a walker's slot clock; math.huge for a group the line must find
    state: RowState,            -- written ONLY by src/server/ForestTest/init.luau
    at: Vector3?,               -- the bed actually found
    ids: { string },            -- the live Boar ids, once it has bodies
    lineId: string?,            -- its row in state.lines, once it is awake
    skipped: SkipReason?,
}

Placement.CONFIG = {               -- every number of §5.2 and §6.2, in one frozen table
    neverStuds = 145, bandNearStuds = 150, bedSpreadStuds = 40, bedGapStuds = 71,
    bedCap = 12, leadSeconds = 20, walkersPerDrive = 2, bitesPerStep = 1,
    settleSeconds = 3,
}

-- THE ROSTER. `schedule` is ForestTest.cellSchedule()'s table, `animals` is Grid.animalsOf(cell).
function Placement.plan(
    driveNumber: number, schedule: any, animals: any?, rest: any, spook: any, layout: any,
    beaterNorth: number, walkSpeed: number, boarConfig: any, rng: Random
): ({ RosterRow }, { string })      -- the roster, and the lines that explain it

function Placement.bandFar(beaterNorth: number, spook: any, layout: any): number
function Placement.bedNorth(ordinal: number, groups: number, near: number, far: number): number
function Placement.lineReaches(bedNorth: number, far: number, walkSpeed: number): number
function Placement.dueNow(row: RosterRow, elapsed: number, lead: number): boolean
function Placement.roomFor(bodies: number, bedded: number, size: number, cap: number, bedCap: number): (boolean, string?)
function Placement.clearOfEyes(spot: Vector3, eyes: { Vector3 }, neverStuds: number): (boolean, number)
function Placement.wakeReason(row: RosterRow, elapsed: number, frontNorth: number?, spook: any): WakeReason?
function Placement.gapOk(rows: { RosterRow }, at: Vector3, gapStuds: number): boolean
function Placement.line(rows: { RosterRow }): string     -- "placed 13 / bedded 3 / awake 9 / gone 1 / skipped 0"
```

### 8.2 `ServerScriptService.ForestTest` — the owner's new and changed functions

```luau
-- NEW. The one writer of state.roster.
function ForestTest.planDrive(driveNumber: number, now: number): string?   -- pure inside; no yield
function ForestTest.stepPlacement(now: number): string?                    -- one bite per Heartbeat
function ForestTest.materialise(row, now: number): (boolean, string?)      -- record -> bedded
function ForestTest.orderGroup(row, now: number): string?                  -- bedded -> awake
function ForestTest.bedHidden(spot: Vector3): (boolean, string?)           -- §6.1
function ForestTest.bedSpot(row): Vector3?                                 -- restSpot, + bedHidden + gapOk
function ForestTest.roster(): { Placement.RosterRow }                      -- READ-ONLY view
function ForestTest.placementStats(): {
    placed: number, bedded: number, awake: number, gone: number,
    skipped: { [string]: number }, inView: number, rays: number, searches: number,
}

-- CHANGED
function ForestTest.newDrive(now: number?)        -- also replaces state.roster via planDrive
function ForestTest.step(now: number)             -- one path for both roles; stepPlacement added
function ForestTest.releaseLine(now, staged)      -- STAGED ONLY, Studio-only; the slot path is gone
function ForestTest.stats()                       -- gains the placement counters

-- RETIRED, archived with a note (rule 7)
ForestTest.stockWood, ForestTest.stepRest, Data.stockStep, Data.REST.groups,
Data.REST.stockRetrySeconds, Data.releaseDepth, Data.routeFloor, Data.clampedToLine,
Data.repeatRoomFor, Data.SCHEDULE.leadStuds / minNorthStuds / repeatFrom / repeatTo,
Data.LINE.twoLineChance (already dead data, round 1 of task 251 noted it)
```

### 8.3 No remote, no event, no flag-visible wire

No `RemoteEvent` is added. Nothing about placement is replicated: a client that knew which groups
exist and where they lie up would know the drive, which is the same reason `drive.md` §3.4 keeps the
safety numbers off the wire. The only published value is the layout name, which
`ForestTest.publishLayout` already owns.

---

## 9. What it reads and writes across owners

### 9.1 Reads

| Reads | From | Owner |
|---|---|---|
| `density`, `startDepth`, `routeBias`, `restZones` | `Grid.animalsOf(cellName)` | `ReplicatedStorage.Grid` (frozen data) |
| `cellDepthStuds` 1430 | `Grid.CONFIG` | same |
| which recipe zone a point is in | `Places.zoneIndexAt(cell, x, z)` | `ReplicatedStorage.Places` (pure) |
| the fifteen rows, the dial, `ROUTE_BIAS`, `REST`, `SPOOK`, `LINE` | `Data.*` | `ReplicatedStorage.ForestTest` |
| the beaters' bodies and the front | `ForestTest.realBeaters`, `Data.lineFrontAt`, `Bots.view()` | `ServerScriptService.Bots` (the lane walk) |
| `WALK_SPEED` 3.1 | `Bots.CONFIG` | `ServerScriptService.Bots` |
| the drive number and the phase edge | `Match.driveNumber()`, `Match.PhaseChanged` | `ServerScriptService.Match` |
| **where a character is** (for the predicate) | `Players:GetPlayers()`, `player.Character` | `ServerScriptService.Match.Body` writes it; this system only reads |
| composition size, party, kinds, march rank, "is this a deer" | `Boar.compositionSize`, `Boar.deerComposition`, `Boar.sounderKinds`, `Boar.MARCH_RANK`, `Boar.isDeerKind` | `ServerScriptService.Boar` |
| live counts and capacity | `Runtime:liveCount`, `Runtime:count`, `Runtime:capacity` | `ServerScriptService.Boar` |
| the ground, the canopy, the trunks, the sightline | `ForestTest.terrainYAt`, `Data.groundAt`, `ForestTest.nearestSolid`, `Workspace:Raycast` | the world |

### 9.2 Writes

| Writes | Owner of the thing written |
|---|---|
| `state.roster` and every row's `state`, `at`, `ids`, `lineId`, `skipped` | **this system, and nothing else** |
| `state.lines` rows for a group under orders | this system (unchanged) |
| bodies, through `Runtime:spawn` / `spawnSounder` / `formSounder` / `leadTo` / `spook` / `notice` / `urge` | **`Boar.Runtime` remains the only writer of a body.** This system asks |
| `ModelStreamingMode = Atomic` on a spawned animal model | `Boar.Body.create` sets it — the body's owner, not this system |
| console lines, `placementStats()` | this system |
| `ServerStorage:SetAttribute("DHForestPlacement", …)`, **Studio only** | this system. The shape is `Runtime:step`'s `DHBoarHistory`. It is not `DHFlag_*`, which `tools/studio_mcp.py` owns |

### 9.3 Writes nothing

`Player.Team`, any character, the camera, the Hud, the wood, the terrain, any `DrivenHunt.*` tag, any
`Match.CONFIG` value, any flag row's default.

### 9.4 Untouched by name, because the BRIEF asks

* **Only the stag leaps** (task 339): `Boar.leapByKind` and the `leaps` rows are read, never written.
* **Out-of-play despawn** (task 342): `Brain:_outcome`'s `pastRoadStuds` 150 / `pastRoadSeconds` 1.5
  and the `settled` rule are unchanged. A bedded group is **never ordered**, which is exactly the case
  task 342's spec already pins — *"one the drive never ordered — Karen's stocked wood — never does"*
  (claim 5). That case becomes the rule rather than the exception, so the spec that proves it matters
  more, not less.
* **The deer cap** `MAX_GROUPS_ALIVE` 1 (task 223) and the held-over party (task 251) move from
  `releaseLine` into `Placement.plan`, where they are decided **once per drive** instead of fifteen
  times. The owed-row retry into a silence is retired with the silences: a roster has no silences,
  and a deer party that the cap refuses at plan time is simply not in the drive — printed.

---

## 10. External sources (rule 1)

### 10.1 Luanti (formerly Minetest) — static vs active objects

`doc/lua_api.md` ("Objects", `staticdata`, `on_activate`, `on_deactivate`) and
`src/serverenvironment.cpp` (`activateObjects`, `deactivateFarObjects`).
<https://github.com/luanti-org/luanti> · docs <https://api.luanti.org/>
**Licence:** LGPL-2.1-or-later (engine); media CC BY-SA. **Maintenance:** active (renamed from
Minetest in 2024, regular releases).

* **Well:** this *is* the pattern, in production, for twelve years. An entity outside
  `active_object_send_range_blocks` is not an entity at all — it is a string of static data on the
  block, promoted by `on_activate` when a player comes near and demoted by `on_deactivate` when
  nobody is. The record is authoritative; the entity is a view. Server cost scales with *active*
  objects, not with existing ones, which is precisely §5's split.
* **Badly:** promotion is purely block-and-distance, with no sight term at all, so entities visibly
  appear at block boundaries — the exact defect Karen is complaining about. And a static object's
  time does not pass: nothing happens to it while it is dormant. Both are why this design adds the
  never-in-view gate (§6) and keeps the drive's own clock outside the record (§4.5).
* **Adopted:** the two-tier record/body split and the "cost scales with active" budget. **Not
  adopted:** distance-only promotion.

### 10.2 OpenMW — a processing range, not an existence range

`apps/openmw/mwmechanics/actors.cpp` (the inactive-actor path, `mActorLists` and the processing-range
split) and `aitravel.cpp`'s fast-forward for actors in unloaded cells.
<https://gitlab.com/OpenMW/openmw> · <https://openmw.readthedocs.io/>
**Licence:** GPL-3.0. **Maintenance:** active (0.49 series).

* **Well:** it separates *exists* from *is simulated*, and keeps state for actors outside the
  processing range so the world is not reset when you come back. Readable source, not a conference
  talk — you can check what it actually does, which `PROJECT_CONTEXT.md` rates above a claim.
* **Badly:** single-player, so there is no replication question and no "who can see this" at all.
  Its coarse advance for inactive actors is per-AI-package, not a budget, so it gives no ceiling.
* **Adopted:** "a dormant animal keeps its identity and its plan" — a `RECORD` holds the row, the
  kinds and the march order, so a group that is bedded late is still *that* group. **Not adopted:**
  advancing dormant animals at all; a record does nothing until it has a body.

### 10.3 Michael Booth, "The AI Systems of *Left 4 Dead*" (Valve), AIIDE/GDC 2009

<https://www.valvesoftware.com/en/publications> · the population and `nav` visibility rules on
<https://developer.valvesoftware.com/wiki/>
**Licence:** paper © Valve (readable, not reusable); Valve Developer Community wiki CC BY-NC-SA 2.5.
**Maintenance:** the paper is **static (2009)**; the wiki is still edited.

* **Well:** the canonical statement of the rule this task is about — the population system places
  the horde only in active areas that are **outside the survivors' visible set**, using the nav
  mesh's precomputed area-to-area visibility, and it holds a **population cap** rather than a spawn
  rate. Both halves are this design's §6 and §5.
* **Badly:** it depends on a baked inter-area visibility set, which this repo does not have and will
  not build — so the gate here is one live ray per player, which is a weaker test and is admitted as
  such (§16). And its rule exists so the player never *watches* the horde arrive; Karen's rule is the
  stronger one — she must be able to watch the animal **standing** afterwards.
* **Adopted:** never place inside the visible set; cap the population, not the rate. **Not adopted:**
  precomputed visibility.

### 10.4 Unreal Engine — `MassEntity` LOD and the Significance Manager

<https://dev.epicgames.com/documentation/en-us/unreal-engine/mass-entity-in-unreal-engine> ·
<https://dev.epicgames.com/documentation/en-us/unreal-engine/significance-manager-in-unreal-engine>
**Licence:** Unreal Engine EULA (source on GitHub under that licence; **not** open source).
**Maintenance:** active (UE 5.x).

* **Well:** formal LOD tiers with a **maximum count per tier** and a tick rate per tier, chosen from
  distance *and* on-screen significance rather than distance alone. That is the shape of
  `LIVE_CAP` 24 / `bedCap` 12 / records, and it is why this design caps the middle tier separately
  instead of trusting one number.
* **Badly:** an ECS framework with no Roblox analogue; its lowest tier still ticks a representation,
  so "costs nothing" is not on offer; and importing its vocabulary would be an invented foundation
  in a Luau codebase — rule 2's warning, and `PROJECT_CONTEXT.md`'s *"invented foundations"*.
* **Adopted:** a per-tier count cap. **Not adopted:** anything structural.

### 10.5 Roblox Creator Documentation — instance streaming

<https://create.roblox.com/docs/workspace/streaming> ·
<https://create.roblox.com/docs/reference/engine/classes/Model#ModelStreamingMode> ·
source <https://github.com/Roblox/creator-docs>
**Licence:** CC BY 4.0 (docs). **Maintenance:** active.

* **Well:** the authority for what a client is sent and when, which is the entire basis of §7.3's
  margin, and the documented way to make a model arrive whole (`ModelStreamingMode = Atomic`).
  Already relied on in this repo by `Places.plantOne` and `docs/research/2026-09-24-map-generator.md`.
* **Badly:** **four of the five properties cannot be read from Luau** in this engine version — a
  measured fact, not a guess (`tools/studio_mcp.py`'s `UNREADABLE`; `ESCALATE.md` has three separate
  `NEEDS KAREN` entries about setting `StreamingMinRadius` by hand). So no spec can assert the
  place's radii, which is why §6.3 keeps them out of the predicate.
* **Adopted:** `Atomic` on the animal model; streaming as *margin* for the client spec. **Not
  adopted:** any streaming radius as a rule.

---

## 11. Feature flag

`PLACEMENT_IN_PLACE`, a row in `src/shared/Flags/init.luau`: `default = false`, `owner` = the
Director, `born` = the merge date, `expires` **within 21 days**, `why` = *"Karen 2026-11-10: animals
must be in place, not appear"*.

* **Read once, at the owner's boundary**, and passed inward — the only permitted shape
  (`docs/design/feature-flags.md`): `ForestTest.start` resolves it into `state.placementInPlace`, and
  `planDrive` / `stepPlacement` / `releaseLine` take it as a **parameter**, so both states are
  reachable from a spec while the flag sits at one of them.
* **Flag OFF is byte-for-byte today's drive:** `planDrive` returns an empty roster,
  `stepPlacement` returns nil on its first line, `releaseLine` keeps its slot path, `stepRest` keeps
  its branch. Nothing is deleted until Karen's OK flips the default — and then the losing branch is
  archived under `backups/` with a note (rule 7) and the row is removed.
* **This is not the map switch's case.** The map switch is by commit because *"a flag lives in code
  and the WORLD LIVES IN THE PLACE"*. Animals are run-time bodies in `Workspace.Boars`, created and
  destroyed every drive and persisted nowhere, so a flag can genuinely switch them off.

---

## 12. The measurement plan (BRIEF: the measurement plan)

### 12.1 Per drive, from the console and the probe attribute

| Reading | Target | Where it comes from |
|---|---|---|
| **spawns in view of a player** | **0** | `placementStats().inView`, and the client spec's own count (§13.2). Two independent instruments, deliberately |
| groups skipped `inview` | **0** at a stand | `placementStats().skipped.inview` |
| groups skipped `budget` / `nobed` | counted, no target yet | same |
| **placed** (roster rows) | 9 / 13 / 15 by density | `Placement.line`, printed every 2 s beside `waveReport` |
| **bedded** at the busiest instant | ≤ 12 animals | the ten-second sample series, as task 342 took it |
| **live bodies** peak within drive 1 | ≤ 24 | `Runtime` folder's `LiveMax`, per drive (task 342) |
| **boar step average / peak** per drive | ≤ 7.0 ms / ≤ 20 ms | the drive report's `drive N: … avg X ms worst Y` |
| **server heartbeat p95** | ≤ 32 ms | `<runs-dir>/342-drive.sh`, the same instrument both sides |
| animal parts peak | < 2,000 | `Runtime:partCount()` |
| **file formed after a break** | median nose-to-nose ≤ 17 studs within 5 s | the stuck/gap probe `state.lines` already feeds |
| crossings W / C / E | still all three thirds, centre dominant | as task 342 reported them |
| releases span | stated, not targeted: ~0–97 s at `behindLineStuds` 400 | `lineReaches`, and the SLOT lines' timestamps |

Each row is **one run and one window, named** (V284). No row blends two.

### 12.2 What Karen sees at a stand (rule 5, and the thing no number can answer)

Three frames, same fixed camera, one drive, in her Forest Test:

1. **t ≈ 8 s** — the wood in front of the stand. **Expected: nothing appears.** The first walker is
   still 40 studs away and bedded.
2. **t ≈ 25 s** — the first walker crossing the lane, having **walked** in. Expected: an animal that
   entered frame from the far wood, not one that was not there a frame earlier.
3. **t ≈ 70 s** — an animal **standing** at the tree line, head up, before it breaks (the
   `ALERT_SECONDS` 2 stand), with the beater line behind it.

And the one Karen must judge herself (§15, K-1): *did anything appear?* A frame cannot prove a
negative; her eye over a whole drive is the only instrument for that, which is rule 5 and
`PROJECT_CONTEXT.md`'s *"look at the screen; a number is not a verification"*.

### 12.3 No counter may be zero because nothing wrote it

`placementStats().rays` and `.searches` are published beside `.inView`. A drive that reports
`inView = 0` with `rays = 0` has not tested anything, and `forest_placement.spec` asserts that a
materialise attempt with a player in front of the bed **increments both** `rays` and
`skipped.inview`. That is the guard against *"a visibility audit ignored parent visibility and
certified a blank screen twice"*.

---

## 13. How it is tested

### 13.1 Server spec — `tests/server/forest_placement.spec.luau` (new; scope `match`)

Pure, no world, no raycast, driven entirely through `Placement`'s parameters:

1. **The roster is the dial.** `plan` at `quiet` / `normal` / `busy` returns 9 / 13 / 15 rows and
   53 / 73 / 83 nominal animals, and the row set is exactly `Data.slotAt`'s. Change `DENSITIES` and
   the counts follow.
2. **Deepest first, evenly, inside the band.** `bedNorth(1) == bandFar`, `bedNorth(g) == bandNear`,
   monotone decreasing, and every bed in `[bandNearStuds, bandFar]`.
3. **The band is DERIVED, not written.** `bandFar == beaterNorth − noticeAheadStuds −
   SWEEP.MIN_AHEAD_STUDS`, and `bandNearStuds >= neverStuds`. Move `behindLineStuds` and both move.
4. **`neverStuds` is derived and ordered.** `neverStuds == SPOOK.NOTICE_STUDS + bedSpreadStuds / 2`,
   and `bedSpreadStuds < bedGapStuds < neverStuds < bandNearStuds`.
5. **No two beds inside `bedGapStuds`**, 3-D, over every pair at every density — `REST.groups`'
   45-pair assertion, re-aimed at the generated roster.
6. **`clearOfEyes` fails and says how far.** An eye at 144 studs refuses and returns 144; at 146
   allows. A high-seat eye 12.5 studs up is measured in 3-D, so a bed 144 studs away flat and 12.5
   up is still inside.
7. **`roomFor` is the door, read at the instant** (L-029): it refuses at `bodies + size > 24` and at
   `bedded + size > 12` independently, and it is never latched.
8. **`wakeReason`**: a walker wakes on its clock and never earlier; a non-walker returns nil until
   the front is within `noticeAheadStuds` of its bed, and nil for ever if the front is nil.
9. **A skip is a skip**, not a retry: `dueNow` answers false for a row already `skipped`, so a
   refused group cannot come back inside the drive (must-not 3).
10. **The deer cap is spent once per drive** at plan time: two `reddeer` rows at
    `MAX_GROUPS_ALIVE` 1 yield one deer group in the roster and one printed refusal, and the stag is
    still the last deer.

Plus the two negative cases that must FAIL if the fix is deleted (lesson L-093): delete the
`bandNearStuds >= neverStuds` clamp and case 3 fails; replace `clearOfEyes` with `return true` and
cases 6 and 9 fail.

### 13.2 Client spec — `tests/client/animal_placement.spec.luau` (new)

It exists because the claim is about **what the player is sent**, and only a client can measure that.

* `WaitForChild("Boars")`, then `ChildAdded` for the whole run. For each arrival record the 3-D
  distance to `LocalPlayer.Character.PrimaryPart` **at that instant**, and whether a ray from the
  camera to it was clear.
* **Assert: zero arrivals inside `Placement.CONFIG.neverStuds`.**
* Ignore arrivals within `settleSeconds` 3 of `CharacterAdded` or of a single-frame position jump
  over 100 studs, **and report how many were ignored** — a run that ignored everything must not read
  as a pass.
* Assert the margin that makes the spec valid is still there, as a statement rather than a property
  read (§6.3): `neverStuds` 145 < the place's documented `StreamingMinRadius` 384
  (`docs/design/cell-loading.md` §3). If Karen changes that place setting, this is the assertion that
  has to be re-justified, and it says so.

`src/server/ForestTest/` and `src/shared/ForestTest/` are **not** in `TWO_PLAYER_PATHS`
(`tools/agents.py`), so the gate is the **one-player** line for every task in §17 — scope `match`
(`tools/studio_mcp.py`'s `BLAST_RADIUS`), which plays `forest_stand.spec`, `forest_line.spec`,
`forest_markers.spec` and the match specs. A client spec in `tests/client/` does not change that: the
two-player list is explicit and this file is not in it.

### 13.3 Harness input and screenshots — what it can and cannot do

* **Can:** `python tools/studio_mcp.py capture <name> [camera x,y,z] [look-at x,y,z]` during Play,
  which is how §12.2's three frames are taken (task 7, closed).
* **Can:** drive real keys and mouse through `tests/client/input_scenarios.txt` (task 6), so a
  hunter can be made to turn and look up the lane at a chosen instant.
* **Cannot:** express a frame-counted hold, aim input at an instance, or run anything after the
  client report (task 6's own "cannot express" list). So *"she turned round at the exact frame the
  group was placed"* is **not** a harness test; it is the client spec's distance measurement plus
  Karen's eye.
* **Cannot:** read any streaming property, in Edit or in Play (`UNREADABLE`). So §7.3's margin is a
  documented measurement, re-confirmed by a human, never an assertion.

### 13.4 What the specs cannot prove, said now

1. **That no player ever saw an animal appear.** A ray is a point sample from the character's head;
   the camera is the client's and can be anywhere within the character's own reach. The specs bound
   the failure (≥ 145 studs, occluded, counted on both sides); only a played drive closes it.
2. **That a bedded animal looks right standing there.** Rule 5, Karen's eye.
3. **The cost of a bedded body.** The 0.19–0.22 ms/animal fit was taken over populations that were
   mostly moving. A bedded animal pays the same step loop, but whether its *physics* cost differs
   from a running one is **unmeasured**, and §17's T2 measures it before anything is tuned on it.

---

## 14. Deltas to the designs this touches — exact text for the Builder to paste

**`docs/design/grid-map.md` §9.2**, replace the table's first three rows and add four:

```
| live animals WITH A BODY at the busiest instant | **<= 24** (`ForestTest.LIVE_CAP`) | counted per drive off `LiveMax` |
| of which BEDDED (a body, not under orders) | **<= 12** (`Placement.CONFIG.bedCap`) | the ten-second sample series |
| DORMANT records (no instance) | **<= 120 rows, 0 parts, 0 ms** | `placementStats().placed`; `Runtime:step` never sees them |
| boar runtime, server step, average over one drive | **<= 7.0 ms** | 0.222 ms/animal x 24 + 1.44 fixed = 6.77 (task 342's measured fit). **4.0 ms is retired here**: it is `Bots`' number, borrowed, and ESCALATE.md 2026-11-10 ~04:30 measured it as ~13 live for this runtime |
| boar runtime, server step, peak within one drive | **<= 20 ms** | the per-drive reset task 342 built; the 74-92 ms figures are session high-water marks set by spawn frames |
| server heartbeat p95 | **<= 32 ms**, no worse than `342-cc-C1b` | the number Karen can feel; the animal step is 22 % of it |
| spawns in view of a player, per drive | **0** | `placementStats().inView` AND `tests/client/animal_placement.spec.luau`, two independent instruments |
```

**`docs/design/grid-map.md` §9.1**, append:

```
SINCE TASK 345 THE SCHEDULE DOES NOT SPAWN. A slot's row says WHEN its group moves and WHERE it
breaks out; where the group STANDS before that is `Placement.bedNorth`, deepest slot first across
the band the beater line walks. `releaseDepth`, `leadStuds` and `minNorthStuds` are archived with
the spawn they clamped. See docs/design/animal-placement.md.
```

**`docs/design/forest-drive.md` §3**, amend the animals row:

```
| The forest's animals: WHICH ANIMALS EXIST IN THIS DRIVE AND IN WHAT STATE (the roster, every bed,
every transition), when the wood is stocked, the leash, the stand pick | **`ServerScriptService.ForestTest`**
-- unchanged owner, widened statement (task 345). `state.roster` is its state and nothing else writes
it; `ReplicatedStorage.ForestTest.Placement` holds the pure rules and owns no state |
`src/server/ForestTest/init.luau`, `src/shared/ForestTest/Placement.luau` |
```

**`docs/design/forest-drive.md` §7.2**, append:

```
SINCE TASK 345 THE DRIVE'S PHASE DOES RESET THE WOOD, and that is a change to this section. The
`Assigning` edge replaces `state.roster` (`planDrive`), because a roster is about one drive and one
cell -- `promote` already clears every body and swaps the field there. What is NOT reset is the
session's counters, exactly as before.
```

**`GAME_DESIGN.md`** *System owners*: amend the ForestTest animals row with §3.1's two lines, and add
`src/shared/ForestTest/Placement.luau` to its files column.

**`docs/design/cell-loading.md` §3**: no change. Its measurement (`min 384 / target 512`) is cited
by §6.3 and §7.3 of this design and is the one place that number lives.

---

## 15. Open decisions

### Karen (feel)

* **K-1 — the drive's tempo and length.** At `BEATER.behindLineStuds` 400 the releases now span
  ~0–97 s of a 300-second drive, and `normal` finds a group every **8.1 s** against the 13 s she
  accepted. Two levers, each one data row: `behindLineStuds` 400 → 520 (muster at 700, which the
  wood is measured to hold) spreads releases over 10–145 s at 11.2 s intervals; `Data.DRIVE.seconds`
  300 → ~220 makes the drive the walk. **Recommendation: 700, then play it.** Not a blocker: the
  Builder builds at 580 and measures, and either number is a later three-line commit.
* **K-2 — how many groups walk toward her** before the line reaches anything.
  `PLACEMENT.walkersPerDrive` default **2**. More fills the opening and risks a wood walking out of
  itself (task 342's `settled` despawn); fewer means a quiet first 30 seconds.
* **K-3 — the near 150 studs of the cell hold no bedded animal** (§6.2). She will not find one
  standing just inside the tree line in front of her stand; everything she sees close has arrived.
  This is forced by her own decision 1 and is stated so she can say if it is the wrong trade.
* **K-4 — a group lies up tighter than before** (`bedSpreadStuds` 40 against `REST.spreadStuds` 90).
  Does a sounder in cover look right at that spread?

### Director (scope)

* **D-1 — the budget restatement in §5.2 is taken here**, as the 342 escalation asked. If the
  Director wants 4.0 ms kept, the only remaining lever is ~13 live animals, and that is a different
  game. Confirm or overrule.
* **D-2 — the retirements.** `REST.groups`, `stockWood`, `stepRest`, the repeat window,
  `releaseDepth` and the clamp family are all archived under rule 7 in §8.2. Six archives in one
  system; confirm the scope.
* **D-3 — `ForestTest.drive`, `driveIndexAt`, `deerWaveOf`, `deerWanted` and `wavesPerDrive`** were
  already *"retained as pure window arithmetic"* with no production caller (`forest-drive.md` §7.2).
  After this task `deerWaveOf` / `deerWanted` lose their last reader too. Archive them in T5 or keep
  waiting for a claimant.
* **D-4 — re-confirming `StreamingMinRadius` 384 / `StreamingTargetRadius` 512** is a Karen click
  (`NEEDS KAREN`, three existing `ESCALATE.md` entries). It is **not** load-bearing for the rule
  (§6.3), only for the client spec's margin (§7.3), so it does not block. It should be re-read the
  next time she is in the Properties pane.

---

## 16. Not verified (no Studio, no network in an Architect run)

1. **Every number in §5.1 and §5.2 is quoted from `ESCALATE.md` and `reviews/task-342/REQUEST.md`.**
   I ran no drive and measured nothing. The restatement is arithmetic over somebody else's readings.
2. **`StreamingMinRadius` 384 / `StreamingTargetRadius` 512** are `cell-loading.md` §3's reading of
   2026-11-08. They cannot be read from Luau and I could not re-read them.
3. **The cost of a bedded body** is assumed equal to a running one (§4.1). Unmeasured; T2 measures it.
4. **Whether a bed at dz 450 is actually occluded from a stand** depends on the planted wood of each
   cell. I read `Places.CELL_PLANS`' zone structure, not a rendered frame. If a cell has a clear lane
   to its back, the skips will be `inview` and §12's target will fail loudly — which is the design
   working, not the design wrong.
5. **The exact ordering of `ForestTestBoot`'s `PhaseChanged` listeners against `Match`'s
   `placePlayers` effect.** §4.4 deliberately does not depend on it: the predicate is the guarantee
   and the ordering is only an optimisation.
6. **`Boar.deerComposition`'s `CHANCE_PER_RELEASE`** can grow a deer party, so the 53 / 73 / 83
   figures are nominal. I did not read the chance table.
7. **The file-formation risk in §4.6** is reasoned from task 127's recorded measurement, not
   re-measured. It is the thing most likely to come back as a finding.

---

## 17. The task split (BRIEF: Builder tasks of at most 1 day each)

Every task touches `src/server/ForestTest/`, `src/shared/ForestTest/` or `src/server/Boar/`, none of
which is in `TWO_PLAYER_PATHS`. **The gate for every one is the one-player
`python tools/studio_mcp.py test` line** (`scope=auto:match` is accepted for a review round;
the PR to `main` needs the full `scope=all` run). `test2` is **N/A** for all six, with that as the
reason.

| # | Task | Deliverable | Gate, beyond the one-player line |
|---|---|---|---|
| **T1** | **The pure rules.** `src/shared/ForestTest/Placement.luau` + `tests/server/forest_placement.spec.luau` + the research note `docs/research/<date>-animal-placement.md` and its INDEX row (rule 1, §10's five sources). Nothing in the live path reads it. The `PLACEMENT_IN_PLACE` flag row is born OFF here (§11) | the ten cases of §13.1, including the two that must fail if the fix is deleted | — |
| **T2** | **The roster becomes the population.** `planDrive` in the `markers` closure; `stepPlacement` in Heartbeat bites; `materialise` through `restSpot` + `gapOk`; `REST.groups` / `stockWood` / `stepRest` archived; `beaterMode`'s branch removed. `releaseLine` still spawns for a row with no body (the bridge, so the drive works end to end at every commit) | **the bedded-body cost measured** (§16.3): step ms at N bedded vs N running, same cell. Plus a live drive printing `placed/bedded/awake/skipped`, and screenshot §12.2 frame 3 | — |
| **T3** | **The predicate and the counters.** `bedHidden` (the ray), `clearOfEyes` wired in, `placementStats().inView/rays/searches`, the `DHForestPlacement` probe attribute, `ModelStreamingMode = Atomic` in `Boar.Body.create`, and `tests/client/animal_placement.spec.luau` | **`inView == 0` and `rays > 0`** over a live drive in two cells; the client spec's ignored-count reported | the client spec |
| **T4** | **`releaseLine` stops spawning; `orderGroup` orders.** The route half kept, the spawn half gone, the trail seeded from where the group actually stands. The staged instrument keeps its Studio-only spawn | **the file-formation measurement** (§12.1): median nose-to-nose ≤ 17 studs within 5 s of a break, over ≥ 10 breaks. A screenshot of a woken file | — |
| **T5** | **Retire the repeat window and restate the budget.** `repeatFrom`/`repeatTo`/`repeatRoomFor`/`slotAt`'s repeat branch and the clamp family archived; `grid-map.md` §9.2's new rows asserted; D-3's dead functions archived or claimed | **before/after in three cells** (C1 normal, D1 quiet, A2 busy): peak live, step avg, step peak, heartbeat p95, parts — one run and one window per row | — |
| **T6** | **The walkers and the opening.** `walkersPerDrive` 2, the slot-clock wake, the opening's console line. Then **flip `PLACEMENT_IN_PLACE` on for a playtest** (`python tools/flags.py set PLACEMENT_IN_PLACE on`) and write `PLAYTEST.md` | **§12.2's three frames, inspected**, and Karen's answer to K-1, K-2, K-3, K-4 | Karen's playtest; the default flip is a later three-line commit |

Six tasks. T1 is docs-plus-pure and takes one round. T2 and T5 are the two that carry a measurement
and are the two most likely to need a second round. **Nothing in T1–T4 changes what Karen sees
while the flag is off**, which is what lets all six merge before she has played any of them.
