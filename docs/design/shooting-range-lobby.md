# The range moves straight out of the shop door: one row, one corridor, one remover

Task 315. Design to `reviews/task-315/BRIEF.md`, which overrides anything older in `docs/`,
`TASKS.md` and the earlier designs. **This is a DELTA to `docs/design/shooting-range.md` (task 298)
and to `docs/design/shooting-range-lobby.md` as task 313 left it** — both stay in force for
everything this document does not replace. What changes is **two numbers on one row** and **who keeps
the ground between the lodge and the range clear**. No tuned number of the range changes.

Nothing below is measured by me. Every spatial claim is arithmetic off shipped symbols, cited by file
and symbol; the brief's own live measurements are marked **(brief)**; everything that needs an eye is
in §16 and §17.

---

## 0. The delta map

| Where | What this document does |
|---|---|
| `Range.ANCHORS["forest-test"]` `x`/`z` (`src/shared/Range/init.luau`) | **replaced**: (2600, −3030) → **(2790, −3090)**, with the comment rewritten (§2) |
| `shelfFrom`, `keepOut`, `plate`, `downrange`, `berm`, `fill`, and every row of `Range.LAYOUT` | **unchanged, deliberately** (§2.3, §3). The whole move is a translation of the range frame |
| the lodge, the yard, the road, the pads, the trucks, the spawn, the gathering | **unchanged** (§5.5) |
| which trees stand in the lobby | **one new rectangle, one new predicate, four call sites, one owner** (§5) |
| `Workspace.Session.Tree8` (place content, inside the new footprint) | **removed at run time by the lobby's existing sweep**, given the range's footprint as data (§5.4) |
| `Lobby.CONFIG.AVENUE.SLOTS` | **not edited.** The avenue is dropped by the corridor rule, counted, and its table stays in git (§5.3) |
| `shooting-range-lobby.md` §13 T1–T18 (task 313) | **unchanged and translation-invariant** (§9.1). This document adds W1–W9 (§14) |
| `tests/server/range.spec.luau`'s typed anchor pair, `tests/server/lobby.spec.luau`'s *"keeps the pole and every avenue trunk away from the range"* | **replaced** (§15.1). The second one FAILS at the new anchor by arithmetic and is a must-fix of this task, not a surprise |

---

## 1. What this system must do, and what it must not do

Karen, 2026-10-30 ~13:00 UTC, with a frame **(brief §1)**: *"those trees can be removed and shooting
range can be moved there that I can directly from shop walk to shooting range same distance but
straight / still shooting range changes is not there? / add and improve"*.

### Must do

1. **One range, moved.** Its origin goes on the straight line out of the shop door; the walk stays
   within ±15 % of today's 172.8 studs (147..199). §2 puts all six stations in 174.3..184.0.
2. **The walk is straight and DEAD LEVEL** — no step anywhere between the door and a mat (§3).
3. **The birch row and the pine in front of the shop go**, by a RULE and not a list, at run time,
   never by a Studio click and never by an edit to the place (§5).
4. **Everything proven on the range stays exactly as it is relative to its own origin**: the hill, the
   107/125/179 lanes, the T6 envelope, solo on the whole range, the treestands, the climb, the
   isolation. A pure translation (§2.3).
5. **The berm still faces away from the lodge, the shop and every walk path**, and no shot from any
   station can end anywhere a player stands — re-swept against the NEW surroundings (§9).
6. **A man on the new range is still home** — `Join.insideHome` true along the whole straight walk
   and at every station (§10).
7. **The old site is left clean**, and that is stated as a fact to be verified, not assumed (§11).

### Must NOT do

- **No second remover of trees.** `Lobby.Build.clearWorkingGround` is, in its own words, *"The ONE
  place this repository removes an instance it did not make"*. The range must not remove a tree, a
  bush or a model it did not create. It hands over a RECTANGLE and nothing else (§5.4, §6).
- **No second definition of the corridor.** One predicate answers *"is this foot on ground the range's
  sightline needs"*, and the three planting loops and the sweep all read **that one function** (§5.2).
- **No require edge between `Lobby` and `Range`.** Neither owner learns the other exists; the
  composition root composes them, exactly as it already composes `homeAreas`
  (`src/server/ForestTestBoot.server.luau`, `rangeHomeAreas`; `src/server/Lobby/Join.luau`: *"THE
  AREAS ARE DATA, HANDED IN BY THE COMPOSITION ROOT"*).
- **No change to `Range.LAYOUT`.** Not one row, not one built edge. The move is `x` and `z` on the
  anchor row (§2.3).
- **No flag.** The world lives in the place; this switches by COMMIT, like the map (§12).
- **No new asset, no new part, no `.rbxm`, no Studio-made instance, no terrain edit saved into the
  place.** Every write in this design is a run-time write (§12).
- **No edit to the shooting path, the span arithmetic, the paces, the masks, the solo view, the claim
  path or `Shotgun.CONFIG.CLAIM.*`.**
- **No re-plant of the avenue and no batter on the new cut faces in this task** (§5.3, §4.3): both are
  LOOK decisions with Karen's eye and a frame, and both are queued (§17).

---

## 2. The anchor

### 2.1 The row

```lua
["forest-test"] = {
    x = 2790,        -- was 2600
    z = -3090,       -- was -3030
    plate = false, downrange = -1, drawn = true, berm = "terrain", fill = true,
    shelfFrom = { x = 2850, z = -2950 },   -- UNCHANGED: the lobby's own anchor
    keepOut  = { x = 2740, z = -3060 },    -- UNCHANGED: the lobby field's west and south edges
}
```

`Range.matPosition` lays mat *n* at `anchor.X + (n − 1) * SPOT_SPACING_STUDS`, so the six mats are
**2790 / 2814 / 2838 / 2862 / 2886 / 2910** at z −3090, and the row's centre is
`anchor.X + spotSpan/2` = **2850**.

### 2.2 Why 2790 and −3090 are not free numbers

**x = 2790 is forced by the door.** The lodge stands at `anchor + LODGE.OFFSET` with
`LODGE.OFFSET.X = 0` (`src/shared/Lobby/init.luau`, `CONFIG.LODGE`), so the lodge's centre line, its
door and `Build.lodge`'s `DoorThreshold` are all at **x 2850** — measured live at
(2850.0, 152.3, −2916.1), 9.6 wide, facing south **(brief §2)**. Centring the station row on the
door needs `anchor.X = 2850 − spotSpan/2 = 2790`, and that is the Builder's proposal, accepted.

Three reasons it is accepted rather than, say, centred on the road at x 2870 (`ROAD.CENTRE_X` = 20 →
2870, lane 2860..2880 **(brief §2)**):

1. Karen's words are *"directly from shop"*. The door is the thing she named, and the lodge's own
   symmetry axis is the same number — the range reads as centred on the house.
2. **The hill rises to the EAST (brief §2)**, so every stud of eastward shift buys cut depth: at
   x 2966 the place's ground is 183.8 against 146.0 at x 2734. A road-centred row would push the
   terrace's east edge to 2988 and the cut past 40 studs for no gain in the walk (the nearest mat
   would be 174.08 instead of 174.31 — 0.23 studs).
3. The walk's difference is cosmetic: at x 2850 she walks 10 studs west of the road lane, on the
   lobby's own flat field, for the first 138 studs.

**z = −3090 is forced by the voxel plane the two terraces have to meet on.** `Range.cutRects` takes
the terrace's uprange edge as `min(anchor.Z + CUT.uprangeStuds, footprint.maxZ)` snapped INWARD by
`Range.toGrid(…, false)`. With `CUT.uprangeStuds` 34, `Range.standReach` 21 and
`PROMPT.MaxActivationDistance` 12 that is `min(−3056, −3057) = −3057`, floored to the 4-stud grid =
**−3060** — which is exactly the lobby field's own south edge (`FIELD.SPAN_STUDS` 220 centred on
−2950). The two terraces therefore meet **flush on one voxel plane, with zero overlap and zero gap**.
That holds only for `anchor.Z ∈ [−3093, −3089)`; at −3088 the range would start writing ground inside
the lobby field's rectangle (the thing `keepOut` exists to prevent), and at −3094 a 4-stud strip of
un-terraced hill would stand across the walk. −3090 is in the middle of that window.

### 2.3 The move is a translation, and that is checkable rather than claimed

Every spatial function in `src/shared/Range/init.luau` takes `anchor` and derives: `matPosition`,
`laneCentre`, `windowSpanFor`, `sightSpanFor`, `laneEndsFor`, `corridorSpan`, `bankPosition`,
`bermPosition`, `bermSpanFor`, `bermCrestFaceZ`, `backstopSpanFor`, `bermColumns`, `turfRect`,
`lineRect`, `footprintFor`, `cutRects`, `fieldFor`, `standPosition`, `hutPostPositions`,
`climbTargetFor`. **The only world coordinates in the module are in `Range.ANCHORS`**, and of that
row's six spatial fields exactly two are the range's own position (`x`, `z`); the other two,
`shelfFrom` and `keepOut`, are facts about the LODGE and must NOT move with the range — which is why
they are untouched. `range.spec` already pins both against `Lobby`'s own config
(`shelfFrom == Lobby.ANCHORS["forest-test"]`, `keepOut == lobby anchor ± SPAN/2`), and both
assertions stay true after the move with no edit.

So decision (c) of the brief is satisfied **by construction**: T6 and the whole task-313 span
arithmetic are invariant under translation, and the only thing left to re-answer is (d) — what is now
AROUND the range (§9).

### 2.4 The walk, worked through

From the door (2850, −2916.1) to each mat (z −3090, dz = 173.9):

| station | mat x | distance | bearing | off the door's own facing (180) |
|---|---|---|---|---|
| 1 | 2790 | **183.97** | 199.03 | 19.03° |
| 2 | 2814 | **177.59** | 191.70 | 11.70° |
| 3 | 2838 | **174.31** | 183.95 | **3.95°** |
| 4 | 2862 | **174.31** | 176.05 | **3.95°** |
| 5 | 2886 | **177.59** | 168.30 | 11.70° |
| 6 | 2910 | **183.97** | 160.97 | 19.03° |

**Today, for comparison:** mat 6 is 172.84 studs at bearing 228.76 (48.8° off the door's facing) and
mat 1 is 274.72 at 245.5 **(brief §2 measured the same two numbers live)**.

So the move does two things, not one:

- the nearest mat goes 172.8 → **174.3 studs, +0.87 %**, inside (a)'s 147..199 band;
- **the spread across the six stations collapses from 101.9 studs to 9.66**, and the worst bearing
  from 65.5° off the door to 19.0°. Every station is now "straight out of the shop", not just one.

---

## 3. The shelf and the level walk (the brief's open decision 1)

**Decision: `shelfFrom` stays the lobby's own anchor. The walk is dead level for all 174 studs and the
cut is paid for.** The alternative (taking the shelf from the new site, ~163) is refused.

Four reasons, in order of weight:

1. **It is what Karen asked for.** *"directly from shop walk to shooting range"*. Taking the level
   from the new site puts a **13-stud climb at z −3060, in the middle of her walk** — and nothing in
   this repository builds a ramp.
2. **The flush voxel plane of §2.2 only exists if the two terraces share a shelf.** Otherwise the
   plane at z −3060 is a 13-stud cliff across the corridor, 174 studs from the door.
3. **It is the shipped arrangement and Karen called the result perfect.** `Range.Build.shelfAt`'s own
   comment records the measurement that put it there: the range anchor reads 134.87 and the lobby
   anchor 149.25, *"a 16-stud step across her walk, which is why the level is taken from the lodge"*.
4. **The deeper cut costs nothing in code.** `LAYOUT.FILL` is `{ DEPTH_STUDS = 48, CLEAR_STUDS = 96,
   GRID_STUDS = 4 }`. The air box runs from the grid boundary at or below the shelf up by
   `CLEAR_STUDS` (`Range.Build.cutBoxes`): 148 → **244**, against a worst natural 183.8 — **60 studs
   of headroom**. The grass box runs 48 studs below the shelf: 100 → 148, against a worst natural
   146.0 — **46 studs of margin**. Not one number moves.

**The cut, against the two datums, because the brief and the code use different ones.** The fill is
laid to the SHELF; the surface the renderer draws sits ~2 studs proud of it (measured: the lobby
anchor reads 149.25 natural, snaps to a shelf of 148, and the built surface reads flat **150.0** —
**brief §2**, and the same offset the existing row's comment records).

| | against the shelf 148 | against the rendered 150 **(brief's numbers)** |
|---|---|---|
| deepest cut, at the south-east corner (2966, −3281) | **35.8** | 33.8 |
| deepest fill, at the south-west corner (2734, −3281) | **2.0** | 4.0 |
| today's site, for comparison | ~21 | 21 |

**Boot order cannot change the shelf, and that is already proved.** `Range.Build.shelfAt` floors the
reading to the 4-stud grid when `fill = true`, and `Lobby.Field.shelfFor` is the same arithmetic for
the same stated reason (*"FLOORING IS THE FIXED POINT"*). `RangeBoot` and `ForestTestBoot` are two
Scripts in no defined order, so `groundAt(2850, −2950)` may read 149.25 (natural) or 150.0 (filled) —
and `floor(149.25/4)*4 = floor(150.0/4)*4 = 148`. The two boots cannot disagree about the shelf.
*(Log only, pre-existing: the fixed point holds while the rendered surface stays under 152. There are
2 studs of margin and no instrument watching it. §14 W3 makes it a number.)*

---

## 4. The ground at the new site

### 4.1 The two terraces, as rectangles

All of these are computed by shipped functions at `anchor = (2790, 148, −3090)`, `downrange = −1`:

```
bermSpanFor        = [2734, 2966]        (anchor.X + 60 ± 116)
corridorSpan       = [2752, 2948]        (anchor.X − 38 .. + 158)
bermCrestFaceZ     = −3282               (anchor.Z − 192)
footprintFor       = x 2722 .. 2978, z −3302 .. −3057
cutRects           = ONE rect: x 2732 .. 2968, z −3292 .. −3060
lineRect           = x 2780 .. 2920, z −3100 .. −3076
fieldFor.bounds    = x 2692 .. 3008, z −3329 .. −3030,  exitZ −3669
lobby FIELD        = x 2740 .. 2960, z −3060 .. −2840
```

| Fact | Value | Why it matters |
|---|---|---|
| range terrace ∩ lobby field | **zero area** (they share the line z = −3060) | the range writes no ground the lobby owns; `keepOut`'s purpose is met |
| range footprint ∩ lobby field | **x 2740..2960, z −3060..−3057** (3 studs) | the two HOME areas overlap, so the walk has no gap (§10) |
| lobby road's own built end | z −3054 **(brief §2)** | 6 studs north of the terrace; the road is not crossed |
| lobby road pad (`FIELD.PADS` "Road") | z −3054 | ditto |
| terrace north edge vs the deck's feet | −3060 vs −3069 (`standReach` 21) | the treestand and the ladder foot stand ON the terrace |
| the 10 × 20 asphalt scrap at (2850..2860, −3070..−3090) **(brief §2)** | inside the terrace | overwritten by the terrace's own `SURFACE.LANE` fill; nothing to do, and the frame confirms no grey patch (§15.4) |
| the real asphalt road (x 2600..2665, z −3240..−3260) **(brief §2)** | 67 studs west of the terrace | not touched, unlike at the old site where it bounded the berm |

### 4.2 The `keepOut` seam goes inert, and that is a hole if nobody says so

With the terrace's north edge AT `keepOut.z`, `Range.cutRects` takes its `splitZ >= highZ` branch and
returns **one** rectangle — the same answer a row with no `keepOut` gets. So the two-rectangle arm
that task 306 step B8 built and `range.spec` covers **stops being exercised by the live row**.

- The row keeps `keepOut`. It costs nothing, it is still the correct statement of where the lobby's
  ground begins, and an anchor that later moves north needs it.
- **`range.spec` must drive the split arm BY PARAMETER** (a synthetic anchor north of −3060), or a
  later anchor move inherits an untested seam. Named here so it is a requirement and not a
  regression (§15.1 case 6).

### 4.3 The new cut faces, and how they are finished

The air box removes everything above the shelf inside x 2732..2968, z −3292..−3060. Because the
lobby field is already flat at the same shelf to the north, **the only new faces are three**:

| Face | Depth | Who can see it |
|---|---|---|
| **east**, x 2968, deepest at its south end | up to 35.8 | from the firing line, 58 studs east of station 6's mat, behind the east bank (`bankSpanFor(1)` = [2954, 2966], outer face ON the terrace edge). Perpendicular to every lane |
| **south**, z −3292 | up to 35.8 | nobody: it is 2 studs behind the berm's own back face (−3290) |
| **west**, x 2732 | mostly fill (2.0) | from the firing line, 58 studs west of station 1 |
| north, z −3060 | **none** | it is the lobby field's own edge, already flat |

**Decision: the faces are left as the fill makes them, exactly as at today's site, and the two frames
that can refute it are required** (§15.4 items 4 and 3). Reasons: today's site cuts 21 studs with the
same arithmetic and Karen called the result perfect; the deep corner is behind a 21-stud heap; and a
batter is a new `CUT` row, new terrain volume and a rebuild of her place — a LOOK task with its own
number, queued (§17 D4). **What is NOT claimed:** that a 36-stud earth wall standing 2 studs beyond
the east bank reads acceptably. Nobody has looked (§16 item 3).

**One thing the move gives for free, and one risk with it.** The place's own hill rises to 183.8
behind the berm **(brief §2)** — 15 studs ABOVE the berm's 169 crest. As a backstop that is margin on
top of margin (§9.2). As a picture, the heap now dies into a taller natural hillside instead of into
flat ground, and its tapered shoulders (`shoulderDropStuds` 5 over `shoulderStuds` 16) end 5 studs
lower still. That could read as "an earth formed mountain" with a real hill behind it, which is what
Karen asked for — or as a lump in front of a cliff. One frame decides (§15.4 item 3).

### 4.4 The cost of the fill does not move

`bermWidthFor` is 232 at either anchor and the terrace is 236 × 232 against today's 232 × 226, so the
filled volume changes by ~4 % and the chunking (`FILL.CHUNK_STUDS` 64, `Field.chunks`' shape) is
identical. W6 (§14) holds the build's own counters to ±10 %.

---

## 5. The trees: one rectangle, one predicate, one owner

### 5.1 What is actually in the way, measured

**(brief §2, measured live at main d4b10eda.)** Over x 2700..3000, z −3320..−2960 there are **18
lobby trees and exactly ONE place-content tree**. Ten lobby trunks plus that one pine stand between
the lodge's south front and the new range, which reproduces Karen's own count — *"a row of ~10
birches plus one tall pine"* — and that reproduction is the evidence that this is the row she pointed
at. The pine is `Workspace.Session.Tree8` at (2844, −3188), **104.7 studs tall, inside the new
footprint, 6 studs off the door's own line**, and 9 studs uprange of the 107-stud lane: it is in the
firing fan of every station.

### 5.2 The corridor, as a rule

**Decision: the corridor is the STATION ROW's own span, grown by half a hut roof, projected from the
range's uprange edge to the lodge's south face.**

```
X:  [ anchor.X − HUT.roofSize.X/2 , anchor.X + spotSpan + HUT.roofSize.X/2 ]
      = [2783.5, 2916.5]                         width 133
Z:  [ footprintFor(...).maxZ , lodge south face ]
      = [−3057, −2917]                           depth 140
```

- **Why the station row and not the lane corridor or the berm.** The question the rule answers is
  *"can she see the whole range and walk straight at it"*. `Range.corridorSpan` (196 studs) is where
  the ANIMALS run, and `bermSpanFor` (232) is the heap — clearing either would strip the entire south
  arc of the forest edge for no gain in the view. The station row grown by half a hut roof is the
  **smallest rule under which every built part of every station is unobstructed**: the hut is the
  widest and tallest thing at a station (`HUT.roofSize` 13 × 0.6 × 15 at `roofRise` 9), so a trunk
  outside its span cannot hide one. (`SURFACE.LINE_SIDE_STUDS` 8 gives almost the same span, 2782 ..
  2918; the hut is chosen because the hut is what a tree can hide.)
- **Why a rectangle and not the sightline FAN from the door.** The fan is narrower — at the
  northernmost avenue slot its half-width is 12.2 studs — but its edges would depend on the door's
  measured position, i.e. on a lodge detail, and its margins at the avenue are **3 studs** against a
  birch crown of about 10. A rule decided by 3 studs against a crown nobody measured is a rule that
  photographs wrong. The rectangle is also the WALK, which Karen asked for by name.
- **Why the lodge's south face (−2917) and not the porch's (−2925).** The door is in that face and
  the door is what she looks out of. The corridor therefore also contains the porch strip and the
  spawn pad (`SPAWN.OFFSET` → (2850, −2934)) — which holds no trees and never will, because
  `treeLine`'s fourth exclusion and `onWorkingGround`'s front rectangle already keep it clear.
  **Margin to watch: the flagpole's foot is at (2906, −2915) (`FLAGPOLE.OFFSET` (56, 0, 35)) — inside
  the corridor's X span and 2 studs NORTH of its north edge.** It survives by 2 studs and by the fact
  that the rule removes only trees. `lobby.spec` asserts it (§15.1 case 9) so a later change to
  `LODGE.SIZE.Z` or to that offset cannot quietly swallow the pole.

### 5.3 What the rule removes, derived, and the one discrepancy with the brief

| Planter | Removed | Derivation |
|---|---|---|
| `Lobby.Build.treeLine` (the 30-tree ring) | **5, possibly up to 7** | the ring is radius 100 ± `JITTER_STUDS` 9 over `FROM_RADIANS` 0.6 .. `TO_RADIANS` 5.68 with `angle_i = 0.6 + 5.08·(i−0.5)/30`. z ≤ −2917 and \|x − 2850\| ≤ 66.5 select indices 12..19; 14, 15 and 16 are already not planted (the road exclusion), so **5 stand** — and that is exactly the five the brief measured (Tree12, Tree13, Tree17, Tree18, Tree19). Indices 11 and 20 enter or miss depending on their own jittered radius, so the live count is 5..7 |
| `Lobby.Build.avenue` (task 311's birch avenue) | **6 — all of them** | every slot is at `anchor.X + ROAD.CENTRE_X ± OFF_ROAD_STUDS` = x **2846** or **2894**, both inside [2783.5, 2916.5], at anchor-relative z −98..+2 = world **−3048..−2948**, all inside [−3057, −2917]. Seven slots are plantable (one is `gap = true`), six stand today |
| `Lobby.Build.lodgeTrees` (the grove) | **0** | the table's own rule is *"Nothing is planted south of z = −20"* in the lodge's frame; its southernmost trunk is world z −2906, north of −2917 |
| `Lobby.Build.clearWorkingGround` (the world's foliage) | **1** | `Workspace.Session.Tree8`, by the footprint (§5.4) |

**Total 12: eleven of our own and one of the world's.** Karen's count was ten plus a pine.

**The discrepancy, named rather than smoothed over.** The brief's own table lists **five** Avenue
trunks in the corridor and says *"five of the six standing birches"*; the arithmetic above says **six
of six**, because all eight slots lie inside the rectangle and `AVENUE.SHIFT_STUDS` walks a fouled
slot NORTH, which is further INTO the corridor, never out of it. The sixth standing birch (the west
row's z −3048) is absent from the brief's table. **The build reports the live count and that settles
it** (§14 W5); either number satisfies Karen's request, and the design must not pretend to know which.

**Decision on the avenue: it is dropped by the rule, the slot table is NOT edited, and it is not
re-sited in this task.**

- Karen asked for the avenue on 2026-10-28 and for these trees gone on 2026-10-30. **The later word
  is the current one**, and the reversal is named here rather than hidden — the brief's own discipline.
- **The two cannot both exist on this road.** The avenue lines the approach road (centre x 2870); the
  corridor is x 2783.5..2916.5 over the same z range; and north of the corridor the road is already
  inside the yard gravel (south edge −2994, which is why `AVENUE`'s own comment stops the rows at
  −2998). There is no stretch of this road left for an avenue.
- **Dropping by RULE rather than by deleting rows** keeps rule 7 (`NEVER DELETE`), keeps the reversal
  one commit away, and makes *"why is there no avenue"* a number in `Lobby.stats()` plus this
  paragraph instead of a mystery. `Naturvårdsverket`'s allé definition (≥5 trees) is also why the
  avenue is not simply thinned to four and still called one (§13 source 5).
- A re-plant flanking the new corridor (x ≤ 2783.5 or ≥ 2916.5) is possible and is **Karen's call with
  a frame** (§17 K1, D4).

**The forest edge gains a second designed gap.** The ring already leaves a gap due NORTH, and its own
comment says why (*"what the gap protects is the view straight out of the back of the lodge into the
forest that is really there"*). It now also has one due SOUTH, protecting the view out of the FRONT
to the range. Same rule, same shape, Karen's two words.

### 5.4 Who removes the pine (the brief's open decision 4)

**Decision: `Lobby.Build.clearWorkingGround`, given the range's own footprint as data. The range
removes nothing.**

- The lobby's sweep is already *"The ONE place this repository removes an instance it did not make"*,
  and it is already bounded three ways: only the folders `CLEARING.FOLDERS` names
  (`Session`/`OurForest`/`Foliage`), only their DIRECT children, and only feet on the rule's own
  rectangles. A second remover inside `Range.Build` would be a second writer of one fact — *"which of
  the world's trees are standing"* — which is the failure `docs/PROJECT_CONTEXT.md` records
  (*"Two systems wrote the creature's position"*).
- The rectangle is the RANGE's (`Range.footprintFor`, the same box `Join` is already handed), so no
  owner reaches into the other and nothing is re-derived.
- `Tree8` is a direct child of `Workspace.Session` **(brief §2)** ✔, and the sweep locates a Model by
  `GetBoundingBox().Position` — a bbox centre, not a foot. The pine's trunk is ≥ 110 studs from every
  footprint edge, so a leaning bbox cannot move it out. Both bounds are stated because both are real:
  a nested model or a trunk near an edge would be missed.
- **The accepted dependency, named:** if the lobby does not build (no anchor row, a missing seam,
  `Lobby.start` returning false), the pine stays standing in the lane and the range builds anyway.
  That is made VISIBLE rather than silent: the removal is counted in `Lobby.stats()`, the boot prints
  it, and `RangeBoot` prints a one-line **read-only census** of foreign BaseParts inside the footprint
  (§7.4). A print is not a second writer.
- Rule 7: the removals are appended to a `backups/` note the way task 249's are
  (`backups/2026-10-23_task249_lobby-clearing.txt`) — names and coordinates of the pine and of the
  eleven trunks that stop being planted.

### 5.5 Nothing else in the lobby moves

Checked against `Lobby.CONFIG`: `FIELD.PADS` (Yard, Road, Gather), `SPAWN`, `TRUCK`/`PADS`,
`GATHER`, `LODGE`, `TREELINE`'s own four exclusions, `FLAGPOLE` and `Build.yardRect` are all north of
z −2994 or inside it, and the footprint's northernmost edge is −3057. **Not one lobby rectangle is
touched by the footprint or the terrace**, and the corridor removes only trees. `Places`
(`Workspace.DrivePlaces`) plants along each drive layout's road, which lies inside the drive's field
(x 2230..3830, z −2477..−1197, per `Range.fieldFor`'s own comment) — 580 studs north of the terrace.

---

## 6. Owners — one writer each, named

| System | THE one writer | On disk | Changed? |
|---|---|---|---|
| **The range's position** (the anchor row) | **nobody at run time.** Frozen data (`Range.deepFreeze`), edited by the Builder in git | `src/shared/Range/init.luau`, `Range.ANCHORS` | **two numbers** |
| The range's geometry — every Instance under `Workspace.Range` | `ServerScriptService.Range.Build` | `src/server/Range/Build.luau` | unchanged |
| The range's own GROUND (terrace, heap, lane surface) | `ServerScriptService.Range.Build`, through `RangeData.cutRects` and `Build.cutBoxes`, **only inside `footprintFor`** | `src/server/Range/Build.luau` | unchanged |
| The lobby's own GROUND (the 220 × 220 shelf) | `ServerScriptService.Lobby`, through `Lobby.Field` | `src/server/Lobby/Field.luau` | unchanged |
| **WHICH TREES STAND IN THE LOBBY** — the one planter (`treeLine`, `lodgeTrees`, `avenue`) and the one remover of the world's foliage (`clearWorkingGround`) | **`ServerScriptService.Lobby.Build`** | `src/server/Lobby/Build.luau` | **unchanged owner.** It gains one predicate and two optional arguments |
| **The corridor's two X edges and its range-side edge** | **`ReplicatedStorage.Range`** (pure, derived from the anchor and `LAYOUT`) | `src/shared/Range/init.luau`, `Range.sightlineFrom` | **new, pure, no writer** |
| **The corridor's lodge-side edge** | **`ServerScriptService.Lobby.Build`** (the lodge's own south face) | `src/server/Lobby/Build.luau`, `Build.sightlineRect` | **new** |
| **Composing the two, and handing the footprint over** | **`ServerScriptService.ForestTestBoot`** — the same `do` block that already composes `rangeHomeAreas` | `src/server/ForestTestBoot.server.luau` | **two more fields** |
| Where a man belongs | `ServerScriptService.Lobby.Join` (areas handed in as data) | `src/server/Lobby/Join.luau` | unchanged, not one line |
| The range's STATE, the span, the masks, the solo view, the loan | `ServerScriptService.Range` / `StarterPlayerScripts.Range.*` | `src/server/Range/`, `src/client/Range/` | **unchanged, not one line** |

Mirror the three new/changed rows into `GAME_DESIGN.md` "System owners" in the same commit as the
first code.

---

## 7. Interfaces, with types

### 7.1 `ReplicatedStorage.Range` — one new pure function

```lua
-- THE RANGE'S HALF OF THE SIGHTLINE: the two X edges a tree may not stand between if every built
-- station is to be visible, and the edge of the range nearest the firing line's uprange side.
-- PURE, derived from the anchor and LAYOUT, so it follows the row with no code change. The caller
-- closes the fourth edge with ITS OWN fact; this module knows of no lodge.
function Range.sightlineFrom(
    anchor: Vector3, layout, downrange: number?
): { minX: number, maxX: number, fromZ: number }
--   minX = anchor.X - HUT.roofSize.X/2
--   maxX = anchor.X + spotSpan(layout) + HUT.roofSize.X/2
--   fromZ = the uprange edge of footprintFor(anchor, layout, downrange)
--           (its maxZ when downrange == -1, its minZ when +1)
```

`Range.LAYOUT` gains **no row**. `Range.footprintFor`, `cutRects`, `fieldFor`, `sightSpanFor`,
`laneEndsFor` and every other function are **untouched**.

### 7.2 `ServerScriptService.Lobby.Build` — one new predicate, four call sites

```lua
-- THE RECTANGLE, CLOSED. nil when no lane was handed in, which is every world without a range and
-- every spec that passes nothing -- and then nothing below changes one answer.
function Build.sightlineRect(lane: any?, anchor: Vector3, cfg): { minX, maxX, minZ, maxZ }?
--   X from the lane; Z between lane.fromZ and the lodge's south face
--   (anchor.Z + cfg.LODGE.OFFSET.Z - cfg.LODGE.SIZE.Z/2)

-- IS THIS FOOT ON GROUND THE RANGE NEEDS? PURE -- two numbers in, a boolean out, no Instance and no
-- world -- `Build.onWorkingGround`'s shape exactly, so `lobby.spec` asks it about the measured
-- trunks, about the pine and about the flagpole with nothing built.
function Build.keptClear(
    x: number, z: number, anchor: Vector3, cfg,
    keepClear: { Join.Area }?, lane: any?
): boolean
--   true when (x, z) is in sightlineRect(lane, ...) or in any rectangle of keepClear
```

Read by **exactly four call sites**, and by nothing else:

| Call site | Change | Counter |
|---|---|---|
| `treeLine`'s loop | one `continue`, after the four shipped exclusions | `stats.sightlineDropped += 1` |
| `Build.avenuePlan` | a slot whose FINAL position is kept clear is marked dropped (so a `SHIFT_STUDS` walk is tested where it ends up, not where its row says) | `stats.sightlineDropped` |
| `lodgeTrees`' loop | one `continue` — zero today, and that is the point: a future table cannot re-plant into the corridor | `stats.sightlineDropped` |
| `clearWorkingGround` | `or Build.keptClear(...)` inside the one existing `if` | `stats.sightlineCleared += 1` |

`Build.onWorkingGround` and its four rectangles are **not touched**: that predicate answers a
different question (*"is this the lobby's working ground"*) and changing it would drop ring trees
nobody asked about. Two boundaries with two reasons stay two functions; the NEW one has exactly one
definition, which is the rule that matters (`Join`'s own words: *"a boundary asked twice is two
boundaries"*).

### 7.3 The seams — `Lobby.start` and `Build.build`

```lua
Lobby.start({
    ...,
    homeAreas = { Join.Area }?,        -- shipped, unchanged
    keepClear = { Join.Area }?,        -- NEW, optional: complete rectangles the lobby keeps free of
                                       -- trees. The range's footprint. nil = today's game, bit for bit
    sightline = { minX: number, maxX: number, fromZ: number }?,  -- NEW, optional: the range's three
                                       -- edges. The lobby closes the fourth
})
```
Both are passed straight into `Build.build`'s existing `seams` table (`rig`, `dress`, `assets`,
`groundAt`, `terrainAt` — the same shape), and both are **plain tables of numbers**: no Instance, no
function, no module. A world that injects nothing is unchanged in every answer, which is what keeps
the DEV place and every spec out of this.

### 7.4 `ForestTestBoot` — the composition, beside the one it already does

```lua
local rangeHomeAreas, rangeKeepClear, rangeSightline = nil, nil, nil
do
    local row = RangeData.anchorFor(Map.EXPECTED_WORLD)
    if row ~= nil and RangeOwner.ENABLED then         -- the SAME guard, not a second Flags.isOn
        local at = Vector3.new(row.x, 0, row.z)
        local dir = RangeData.downrangeOf(row)
        local box = RangeData.footprintFor(at, RangeData.LAYOUT, dir)
        rangeHomeAreas = { box }                      -- shipped
        rangeKeepClear = { box }                      -- the pine's rectangle
        rangeSightline = RangeData.sightlineFrom(at, RangeData.LAYOUT, dir)
    end
end
```

**One read-only census line, in the range's own root** (`RangeBoot`, after `Range.start`):
`[RangeBoot] footprint census: n foreign BaseParts, nearest <name> at (x, z)`. It writes nothing and
removes nothing — it turns *"the lane is clear"* into a number instead of a belief, which is the one
thing §5.4's dependency needs. `Lobby.stats()` gains `sightlineDropped` and `sightlineCleared`.

### 7.5 Remotes, client, flags

**None.** `RangeRequest` and `RangeBoard` are untouched; no client module changes; no flag row is
added or read (§12).

---

## 8. What it reads and writes, and who owns each

| Fact | Direction | Owner | How |
|---|---|---|---|
| where the range is | read, as frozen data | `ReplicatedStorage.Range` (no run-time writer) | `Range.ANCHORS["forest-test"]` |
| the shelf to build on | read, once, at build | `ReplicatedStorage.ForestTest` (`groundAt`, the world's ONE ground reader) | `Range.shelfFor` → `Build.shelfAt(row.shelfFrom)` |
| the range's own ground | **write**, terrain, inside `footprintFor` only | `ServerScriptService.Range.Build` | `Terrain:FillBlock` / `FillBall` / `ReplaceMaterial` |
| the lobby's ground | **write**, terrain, inside `FIELD` only | `ServerScriptService.Lobby` (`Field`) | ditto |
| which trees stand, and which of the world's foliage goes | **write** (create / `Destroy`) | `ServerScriptService.Lobby.Build` | `treeLine`, `lodgeTrees`, `avenue`, `clearWorkingGround` |
| the corridor and the footprint rectangles | read, pure | `ReplicatedStorage.Range` | `sightlineFrom`, `footprintFor` |
| the lodge's south face | read, pure | `ServerScriptService.Lobby.Build` | `cfg.LODGE.OFFSET`, `cfg.LODGE.SIZE` |
| where a man belongs | read | `ServerScriptService.Lobby.Join` | `homeAreas` ← the root |
| the span, the masks, the solo view, the shot's ignore list, the loan, the board | untouched | `ServerScriptService.Range`, `StarterPlayerScripts.Range.*`, `ServerScriptService.Weapon` | — |
| money, points, penalties, the roster, a drive row | not read, not written | `Economy`, `Match`, `HitLog` | — |
| the saved place file | **never written** | Karen, in Studio | every write above is a run-time write (§12) |

---

## 9. Safety, re-swept against the new surroundings (the brief's decision (d))

### 9.1 The envelope is translation-invariant, and that is the whole of T6

Every term of task 313's §3 is anchor-derived: `backstopSpanFor` = `bermSpanFor` ± `shoulderStuds`,
`backstopSlope` = `reach / |bermCrestFaceZ|`, `bayHalfSlope` = a pure `LAYOUT` ratio, and the apron
bound = `corridorSpan ± APRON_STUDS`. **T6's 36 combinations therefore hold at the new anchor with no
new arithmetic**, worst off-axis angle still 39.81°, and every worst ray still crosses
`bermCrestFaceZ` (now z −3282) inside `backstopSpanFor` (now x 2750..2950). `range.spec` already
drives all 36 from `anchor` as a parameter, so the existing cases cover the new row the moment it
changes.

### 9.2 What is now around the range

| What a player occupies | Where | Relative to the firing line (z −3090) |
|---|---|---|
| the lobby field (the whole 220 × 220) | z −3060 .. −2840 | **≥ 30 studs UPRANGE** |
| the yard, the four bays, the four pads, the turning ground | z ≥ −2994 | ≥ 96 uprange |
| the spawn pad | (2850, −2934) | 156 uprange |
| the lodge, the shop counter, the keeper | z ≥ −2917 / (2857, −2899) | ≥ 173 uprange |
| the gathering yard | (2788, −2940) ± 40 | ≥ 110 uprange |
| the drive's own field | z −2477 .. −1197 | ≥ 613 uprange |

**Nothing a player stands on is downrange of any station, at any distance, in any lane.** The whole
surface danger area of this range lies between z −3090 and the crest face at −3282, inside x
2750..2950, on ground the terrace cut flat and the heap closes — and the place's own hill rises to
183.8 behind it, 15 studs above the crest, as unclaimed margin. This is the US Army TC 25-8 / NRA
pattern (§13 sources 1 and 2): the danger area is bounded downrange and occupied ground is kept out
of it, rather than the angle being chased with more earth.

### 9.3 The one new exposure, named and not built against

The firing line is now **174 studs due south of the shop door, with the lodge directly behind every
shooter**. A man on a mat who turns round is pointing at the door. Three facts bound it:

- there is no player damage anywhere in this game's shooting path: `Weapon.HitReported` →
  `runtime:takeHit` matches the part against **its own animals** (`RangeBoot`'s listener), so a shot
  at the lodge reports nothing and hurts nobody;
- the safety-arc penalty is the drive's (`Match.Penalty`, `Rules.unsafeLine`) and no drive is open in
  the lobby, so nothing fires and nothing is tied to a tree — unchanged by this move;
- it existed before, at a worse angle and a longer range (the lodge was 40–65° off the old back
  azimuth at 170–280 studs); the move makes it exactly 180° and 174 studs.

**Decision: nothing is built for it.** A facing gate on firing is a feel change, it is Karen's, and
it has a cheap shape if she wants it (`Range.mayShoot` already gates on `spotAt`). §17 K6.

---

## 10. Where a man belongs (Learning Agent L-154, the brief's §5)

The gap that put a player back at the lodge in tasks 298/302 is closed here **by arithmetic, before
any build**:

```
lobby field        x 2740 .. 2960,  z −3060 .. −2840     Join.homeAreas' first rectangle
range footprint    x 2722 .. 2978,  z −3302 .. −3057     RangeData.footprintFor, handed in by the root
walkway corridor   x 2826 .. 2874,  z −3203.5 .. −2926   Join.walkwayTo(lobby anchor, footprint centre),
                                                          FIELD.WALKWAY_HALF_STUDS 24
```

- **The field and the footprint OVERLAP by 3 studs in z (−3060 .. −3057).** There is therefore no gap
  anywhere along the straight walk at x 2850, with or without the corridor — the corridor is belt to
  that brace. (The brief's §5 feared an 11-stud hole; it was computing with the range's PARTS bbox
  (z −3071) rather than with `footprintFor`, whose margin is `PROMPT.MaxActivationDistance` 12 and
  whose uprange reach is `standReach` 21.)
- Every mat (x 2790..2910, z −3090) and every deck (z −3076) is inside the footprint, with 112 studs
  of X margin at the ends.
- `FIELD.PADS`, the spawn, the gather rectangle and the truck bays are all north of −2994 and are not
  touched.
- **It is still VERIFIED live, not assumed** (§14 W7, §15.3): a sampled walk, and
  `Lobby.stats().returns` staying at 0 while a man stands on each of the six mats and each of the six
  decks.

---

## 11. The old site (the brief's decision (e))

Clean **by construction**, and each clause is a fact with a source:

| Claim | Why | Verify |
|---|---|---|
| no orphan mat, post, bench, hut, deck, ladder, bank or prompt | every part the range makes is parented under `Workspace.Range` by `Range.Build.build`, which builds the whole folder at the row's anchor | EDIT: `Workspace:FindFirstChild("Range") == nil` in the saved place |
| no orphan fence | `FENCE` is refuted and nothing on those two lines is built (`LAYOUT.FENCE`'s own comment; `range.spec` asserts it) | — |
| no orphan terrace | the terrace is a run-time `FillBlock`; the place's EDIT terrain at the old site still reads 134.9 / 148.3 / 155.1 **(brief §2)**, i.e. the natural hill. The 150 terrace is not in the place | EDIT probe at the old anchor after the move |
| no orphan animal | `Workspace.RangeTargets` is created by the range's own runtime and lives at its field | — |

**The one way this goes wrong, named because it is a false-PASS path.** If a `Workspace.Range` folder
was ever SAVED into the place, `Build.build` returns **"already built"**, the range never appears at
the new anchor, and the only symptom is one warn line
(`[RangeBoot] the range refused to start: already built`, from `Range.stats().refusedBy`).
**Pre-flight check, in EDIT, before the move is merged: `Workspace.Range` and `Workspace.RangeTargets`
must both be absent from the saved place.** §17 D3.

---

## 12. Reversibility: by commit, not by flag

**Decision: no feature flag.** CLAUDE.md's own exception applies verbatim — *"A flag lives in code and
the WORLD LIVES IN THE PLACE"* — and this is the same class of change as the map switch
(`Map.EXPECTED_WORLD`, `docs/design/map-generator.md` §17). A flag would need two anchor rows and
would double every derived rectangle (terrace, footprint, home area, corridor), and a flag-off boot
after a flag-on session would leave two terraces cut and six trees already gone.

**What makes a commit enough here, and it is stronger than the map's case: every write in this design
is a run-time write.**

- the range's parts: built into `Workspace` at boot, not Rojo-owned, not saved;
- the terrace and the heap: `FillBlock`/`FillBall` in a Play session, discarded with it;
- the trees: `treeLine`/`avenue` plant them each boot, so a revert re-plants them;
- the pine: `CLEARING`'s own comment — *"deleting this table puts the bush back on the next server"*.

So the rollback is **one revert of the row plus `Build.keptClear`'s two arguments**, and the next
server is the old game. The one standing instruction that makes it true: **nobody saves the place from
a Play session.** §17 D1.

---

## 13. External sources (rules 1 and 2)

1. **US Army TC 25-8, *Training Ranges*, appendix B (surface danger zones)** —
   <https://armypubs.army.mil/> · **US Government work, public domain**, current series; already cited
   in `Range.LAYOUT.BERM`'s own comment for the 6 m berm.
   *Well:* the danger area is defined entirely DOWNRANGE of the firing line, and no occupied structure
   or route may lie inside it; a range limits the firing angle to its backstop rather than chasing the
   angle with earth. *Badly:* live-fire absolutes (ricochet fans, 5° lateral dispersion) are about a
   real bullet and do not transfer to this engine.
   **Taken:** §9's decision rule — occupied ground is proved UPRANGE by rectangle arithmetic, and the
   envelope stays the derived one (T6), unchanged by the move.
2. **NRA Range Source Book, ch. 2 (site selection) and ch. 3 (impact berms)** —
   <https://www.nrahq.org/pdf/RangeSourceBook.pdf> · © NRA, reference only, the standing edition.
   *Well:* site selection treats the APPROACH and the firing line's own clear line of sight to the
   targets as part of the range, not as landscaping, and it uses natural terrain behind the berm as
   additional stop. *Badly:* assumes real earthmoving; nothing about voxels or a 4-stud grid.
   **Taken:** the corridor is a RULE belonging to the range's geometry (§5.2), and the place's own hill
   behind the berm is kept as margin and never leaned on (§4.3, §9.2).
3. **BSRC 50 m Running Boar / Time Limit Range** — <https://bsrc.co.uk/time-limit-range/> ·
   <https://bsrc.co.uk/wp-content/uploads/2023/01/50m-Running-Boar-Normal-Runs.pdf> — club pages,
   © BSRC, reference only, live (2023 PDF).
   *Well:* the firing hut of BAYS, the walk-up approach behind the line, and the paces (10 m in 5.0 s
   and 2.5 s). *Badly:* second-hand for the ISSF rulebook; a sport range, nothing about a backstop.
   **Taken:** nothing new. It is named because this design CHANGES none of it — the bays, the row, the
   paces and the window are translated untouched, which is decision (c).
4. **Roblox Creator Documentation** — `Terrain:FillBlock`, `Terrain:ReplaceMaterial`,
   `Region3:ExpandToGrid`, `Model:GetBoundingBox`, `Instance:Destroy`.
   <https://create.roblox.com/docs/reference/engine/classes/Terrain#FillBlock> ·
   <https://github.com/Roblox/creator-docs> — the docs repository is **CC BY 4.0** and continuously
   maintained.
   *Well:* the 4-stud voxel grid anchored at the world origin, and that a box face landing inside a
   voxel writes it only partly — the whole reason the terrace's edges are snapped outward and the
   reason the two terraces can meet flush (§2.2, §4.1). *Badly:* silent on where the rendered
   isosurface sits over a filled voxel, which is why the shelf-to-surface 2-stud offset is a
   MEASUREMENT and not a derivation (§3).
   **Taken:** snap outward, floor the shelf (the fixed point), treat the drawn surface as measured.
5. **Naturvårdsverket, *allé* / biotope protection guidance** — <https://www.naturvardsverket.se/> ·
   Swedish public-authority guidance, current; already the source for `Lobby.CONFIG.AVENUE` through
   `docs/research/2026-10-29-lobby-flagpole-and-birch-avenue.md`.
   *Well:* an allé is ≥5 deciduous trees in one or two rows along a road, with no spacing requirement.
   *Badly:* says nothing at all about removing one.
   **Taken:** the avenue is not thinned to four and still called an avenue; it is dropped whole by the
   rule, with its table kept, so a re-plant is a decision rather than a repair (§5.3).
6. **This repository, which outranks all of the above for the mechanism.**
   `src/server/Lobby/Build.luau` — `clearWorkingGround` (*"The ONE place this repository removes an
   instance it did not make"*, bounded by folder, by direct child and by rectangle) and
   `onWorkingGround` (a pure two-number predicate a spec drives with nothing built): **`keptClear` is
   that function with a different set of rectangles, and its header says so** (rule 9).
   `src/server/Lobby/Join.luau` — `homeAreas` / `walkwayTo` (*"THE AREAS ARE DATA, HANDED IN BY THE
   COMPOSITION ROOT"*): **the seam of §7.3 and §7.4 is that arrangement, a second time.**
   `src/server/Lobby/Field.luau` — `shelfFor` (floor-to-grid as a fixed point).
   `src/shared/Range/init.luau` — `cutRects`' `keepOut` seam and `footprintFor`'s outward rounding
   (*"a fractional edge does not survive a Vector3's float32"*).

---

## 14. Numeric targets

| # | Target | Instrument |
|---|---|---|
| **W1** | **The walk: door → nearest mat 174.31 studs, inside 147..199 (±15 % of today's 172.8), and within 4.0° of the door's own facing.** All six stations 174.31..183.97, spread ≤ 10 studs, worst bearing ≤ 19.1° off (§2.4) | `range.spec`, read off `matPosition` and the lodge's own config; once live from the `DoorThreshold` part |
| **W2** | **The walk is LEVEL: no step over 1.0 stud anywhere between the door and any mat**, and the ground along x 2850 from z −2916 to −3090 stays within 0.5 studs of one value | the Director's ground-profile probe at 1-stud steps (today: flat 150.0 to −3056, then **up to 160.3 and 164.6** — brief §2), plus §15.4 frame 2 |
| **W3** | **The two terraces meet flush:** `cutRects(...)[1].maxZ` == the lobby field's south edge == −3060; terrace ∩ field area **0**; both shelves resolve to the SAME number from either boot order | `range.spec` (reading `Lobby.CONFIG`, the shipped `keepOut` case's shape); live, `floor(groundAt(2850,−2950)/4)*4` before and after the lobby builds |
| **W4** | **The cut and the fill stay inside the shipped envelope:** worst cut **35.8** ≤ `FILL.CLEAR_STUDS` 96 (60 studs spare), worst fill **2.0** ≤ `FILL.DEPTH_STUDS` 48 (46 spare). No `LAYOUT` number changes | arithmetic in `range.spec`; live terrain probe over the brief's own 9 × 11 grid |
| **W5** | **The trees: 12 removed — 5..7 ring, 6 avenue, 0 grove, 1 world pine — and ZERO trees left standing inside the corridor or the footprint** | `Lobby.stats().sightlineDropped` / `.sightlineCleared`; a live census over the corridor and the footprint; `[RangeBoot] footprint census: 0 foreign BaseParts` |
| **W6** | **The build costs no more than today:** terrain fills/replaces within ±10 % and `Range.Build`'s own elapsed time within +20 % of the old site's; `Lobby.stats().parts` ≤ `MAX_PARTS` 1500 still, and lower by eleven trees | the `[RangeBoot]` and `[lobby]` boot lines |
| **W7** | **Home is continuous:** `Join.insideHome` true at every 1-stud sample of the straight walk from the door to each of the six mats, at all six mats, at all six decks and at both ladder feet; field ∩ footprint = 3 studs of z | `lobby.spec` (pure, the footprint handed in as data); live, `Lobby.stats().returns` == 0 while standing on each |
| **W8** | **Safety: every lobby rectangle is ≥ 30 studs UPRANGE of the firing line**, and T6's 36 combinations still land inside `backstopSpanFor` at the new anchor (worst margin 0.0 where the backstop bound binds, by construction) | `range.spec` + `lobby.spec`; one live ray sweep (§15.3) |
| **W9** | **The old site is empty:** 0 parts under any `Workspace.Range` near (2600, −3030), EDIT terrain there unchanged at 134.9 / 148.3 / 155.1, and **no `Workspace.Range` in the saved place** (§11) | EDIT probe, before and after |

T1–T18 of `shooting-range-lobby.md` (task 313) are **unchanged and re-asserted at the new anchor by
the same spec cases**, because every one of them is anchor-parameterised (§9.1).

---

## 15. How it is tested

### 15.1 Server specs

**`tests/server/range.spec.luau`**

1. **The row, by its DERIVED properties and not only by two typed numbers.** The shipped case asserts
   `x == 2600` and `z == -3030` and must be replaced — but it is replaced with facts, not with two new
   literals: the station row's centre equals the lodge's centre line
   (`matPosition(anchor,1).X + spotSpan/2 == Lobby.ANCHORS["forest-test"].x + LODGE.OFFSET.X`), the
   door-to-nearest-mat distance is inside 147..199, and the bearing is within 10° of 180. The row's
   other fields (`plate`, `downrange`, `drawn`, `berm`, `fill`, no `y`) keep their shipped assertions.
2. **`shelfFrom` and `keepOut` did NOT move**: the two shipped cases pass unedited, which is the
   machine-checkable half of "this is a translation".
3. **The flush plane (W3)**: `cutRects(...)` returns ONE rectangle whose `maxZ` equals
   `Lobby.CONFIG.FIELD`'s south edge, read from `Lobby`'s own config, and the terrace ∩ field area is 0.
4. **The terrace still contains everything built on it**: the shipped *"every part of the range stands
   inside the ground the cut wrote"* case, unedited, at the new anchor.
5. **W4's cut/fill envelope**, as arithmetic against `FILL.CLEAR_STUDS` and `DEPTH_STUDS`, driven with
   the brief's measured ground grid as a fake `groundAt`.
6. **The `keepOut` SPLIT arm, by parameter** (§4.2): a synthetic anchor north of −3060 must still
   return two rectangles with the seam at `keepOut.z`. Without this case the arm goes dark.
7. **`sightlineFrom`**: both signs of `downrange`; `fromZ` equals the footprint's uprange edge; the X
   span contains every `hutPostPositions`, `hutRoofPosition`, `matPosition`, `benchPosition` and
   `standPosition` for all six stations, and a deliberately narrowed `HUT.roofSize.X` must make the
   containment case FAIL (the bound is load-bearing, not decorative).
8. **T6 and T18 at the new anchor** — the shipped 36-combination sweep, unedited.

**`tests/server/lobby.spec.luau`**

9. ***"keeps the pole and every avenue trunk away from the range"* is REPLACED.** It asserts every
   avenue slot is >150 studs from the range anchor; at the new anchor the slot at (2846, −3048) is
   **70.0 studs away** and the case **fails by arithmetic**. Its replacement is the rule itself: the
   flagpole's foot is **outside** `sightlineRect` and outside the footprint (true by 2 studs — §5.2,
   and that margin is the point of the assertion), and **no avenue trunk is planted at all**, read
   off `Build.avenuePlan`.
10. **`Build.keptClear` bites exactly where it must, as a pure predicate with nothing built**: true for
    each of the eleven measured trunks **(brief §2's table)** and for the pine at (2844, −3188); false
    for the flagpole foot, the four pads, the spawn, the gather rectangle, each `LODGE_TREES` trunk in
    the lodge's own frame, and a trunk 50 studs out in the wood. `keepClear = nil` and `lane = nil`
    answer **false** for every one of them — the no-range world, bit for bit.
11. **The live build plants nothing in either rectangle**, and reports the count — the `gather`
    exclusion's own shape: *"counts what the live build plants and asserts that none of it is inside
    this rectangle — which is the half that must never change — and reports the count, which is the
    half Karen judges"*. Expect 5..7 ring drops and 6 avenue drops.
12. **The sweep removes a fixture the spec puts in the footprint and in the corridor**, into a
    `Session` folder the spec builds itself, and returns the count; a fixture 1 stud outside each
    rectangle survives.
13. **W7's walk**: `Join.insideHome` at 1-stud samples along the door-to-mat segments, with the
    footprint handed in as data exactly as the root hands it.
14. **W8**: every lobby rectangle (field, yard, road, gather, pads, spawn, truck bays, lodge box,
    flagpole) is north of the firing line by ≥ 30 studs, computed from both configs.

### 15.2 Client specs

**None, and that is a claim.** No client module, remote, panel or picture changes: the client learns
the range's position only through the Instances the server builds and through `RangeBoard`'s existing
payload, and `MapUi.geometryFor` draws the DRIVE's geometry, never the range's. `range_panel.spec`,
`range_mask.spec` and `range_solo.spec` are untouched.

### 15.3 The harness, and what it cannot see

**The one-player run cannot see this change at all, and that must be said plainly.** The harness runs
in the DEV place, where `Lobby.ANCHORS` has no row (no lobby, no trees, no sweep) and the range row is
`{ x = 1200, z = 0, plate = true }` — its own anchored plate, no terrain, no terrace. So:

- what the harness PROVES: every pure rule above, the DEV range still building, and that nothing else
  in `src/` broke (scope resolves to **`all`**, because `src/server/Lobby/` maps to no `BLAST_RADIUS`
  entry and *"an unmapped code path can only ever mean the whole suite"*);
- what it CANNOT prove: the walk, the level, the terrace, the trees, the pine, the frames. **Those are
  the Director's live step in Karen's place** (§15.4, §18 M2), measured with the probe instrument the
  brief's own numbers came from.

| Harness limit | Evidence | What is done instead |
|---|---|---|
| no lobby and no terrain in DEV | `Lobby.ANCHORS`' one row; `Range.ANCHORS["map:v1"].plate` | every forest-test number is a PURE spec case; the world is the Director's live run |
| the stage places the character on `Workspace.Range`'s first `BasePart` (mat 1), not at the shop door | `tools/studio_mcp.py` docstring; `Build` parents mat 1 first | the 174-stud walk is a ground profile plus a frame, not a replayed `W` |
| the replay cannot aim input at an instance, and a spec cannot fire a real `ProximityPrompt` | TASKS.md tasks 6–7; `ShopPanel.setPrompt`'s own comment | unchanged: no prompt behaviour is in this task |
| a spec cannot assert what the SCREEN shows | rule 5; `docs/PROJECT_CONTEXT.md` (*"certified a blank screen twice"*) | every claim about the view is paired with a frame somebody looked at (§15.4) |

**`test2` is N/A**, and that is CLAUDE.md's explicit list rather than an opinion: `src/shared/Range/`,
`src/server/Lobby/`, `src/server/ForestTestBoot.server.luau`, `tests/server/range.spec.luau` and
`tests/server/lobby.spec.luau` are none of them in `TWO_PLAYER_PATHS`. The one-player line is required,
always, and the PR to `main` needs the FULL `scope=all` run.

### 15.4 Screenshots (rule 5) — required, looked at before any claim

1. **Karen's own frame, reproduced.** From the yard gravel at (2850, −2960) on her heading ~196°
   **(brief §1)**: the birches gone, the pine gone, the range in the frame. This is the before/after of
   the picture she sent, and it is the one frame that answers her request.
2. **The walk.** From (2850, −3000) looking south at eye height: level ground, no step at z −3060, the
   six numbered huts ahead.
3. **The heap against the hill.** From station 3's bench down the 179 lane: the berm's crest against
   the place's natural hill 15 studs above it (§4.3).
4. **The east cut face.** From station 6's mat looking east: the terrace's east edge, the east bank in
   front of it, and how deep the wall reads.
5. **From the spawn pad**, looking south: all six huts visible, no trunk between (W5's picture).
6. **The old site**, from the lobby: natural hill, nothing standing, no mat, no post.

---

## 16. UNVERIFIED UNTIL BUILT

An Architect PASS proves this document is coherent. It does not prove it fits the engine or the eye.

1. **That the saved place holds no `Workspace.Range`.** If it does, the range never moves and the only
   symptom is one warn line (§11). One EDIT read settles it, and it is a pre-flight (§17 D3).
2. **That 35.8 studs of cut at the south-east corner leaves a surface worth looking at**, and that the
   `FillBlock` air box really clears the hill there rather than leaving task 311's mound in a partial
   voxel. The arithmetic says the box covers 148..244 whole; nobody has probed it.
3. **That the east cut face does not read as a quarry wall** from station 6 (§4.3). This is the single
   biggest LOOK risk of the move.
4. **That the heap against a taller natural hill reads as "an earth formed mountain"** and not as a
   lump in front of a cliff (§4.3).
5. **The live tree count: 5..7 ring, and 6 avenue against the brief's measured 5** (§5.3). The
   arithmetic and the brief's table disagree by one trunk and the census decides.
6. **That `floor(groundAt(2850,−2950)/4)*4` answers 148 in a live session after the lobby has built.**
   Measured 149.25 natural and 150.0 built, so it does — with 2 studs of margin and no instrument
   watching it (§3).
7. **That six drawn animals on the new terrace behave as they did on the old one.** The ground is the
   same shelf and the same material; nothing has run there.
8. **That the 6-stud band of bladed grass between the lobby's road pad (−3054) and the terrace (−3060)
   does not read as a seam** across the walk (§4.1).

### Carried forward from task 313, open and NOT closed by this move (the brief's §6)

9. **TASKS.md 313a(o):** the boar does not hold RUN pace across the wide span — the board read 9.13 s
   against the 4.18 s setpoint. **Pre-existing, not caused by the move**, and the report must say so
   when the click proof asks for a RUN crossing.
10. **TASKS.md 313a(a):** nobody has looked at an invisible player (solo) in Karen's place. The move
    does not re-close it, and if the translation changes who counts as "on the range" that is still
    open, not settled by this geometry.

---

## 17. Open decisions

### For Karen (feel) — each has a stated default; none blocks building

- **K1. The birch avenue is gone.** Default: **gone, and not re-planted in this task.** Its slot table
  stays in git, so a re-plant flanking the new corridor (x ≤ 2783.5 or ≥ 2916.5) is one commit when she
  wants it. The alternative she might prefer — the avenue back and the range somewhere else — is
  refused by her own later word and by §5.3's geometry.
- **K2. The walk runs 10 studs west of the road lane rather than down it.** Default: **as designed**
  (door-centred, §2.2). Centring on the road costs cut depth and 0.23 studs of walk.
- **K3. The forest edge now has a gap due SOUTH as well as due north.** Default: **yes** — it is the
  same rule and the same reason the north gap exists.
- **K4. The heap now stands against a natural hill 15 studs taller than its crest.** Default:
  **keep it** — free backstop, and plausibly the picture she asked for. One frame (§15.4 item 3).
- **K5. The new cut faces are left as the fill makes them** (§4.3). Default: **leave them**; a battered
  skirt is one new `CUT` row and a LOOK task if the frame reads badly.
- **K6. A man on a mat can turn round and fire at the shop door, 174 studs away.** Default:
  **nothing is built**: no player damage exists on this path and no drive is open in the lobby (§9.3).
  If she dislikes the picture, a facing gate is a feel change and hers to ask for.

### For the Director (scope) — none blocks building

- **D1. No flag; the move switches by COMMIT** (§12), with the standing instruction that nobody saves
  the place from a Play session. Default: **by commit.**
- **D2. The row move and the clearing are ONE task** (§18 M1). They are one change — moving the range
  into a row of birches and a 104-stud pine and merging that as an intermediate state would put a tree
  in the lane in Karen's place for a round. Default: **one task.**
- **D3. The EDIT pre-flight of §11 and §16 item 1** — `Workspace.Range` and `Workspace.RangeTargets`
  absent from the saved place — **before** the move is merged. Default: **do it, it is two reads.**
- **D4. Queued, not done:** the avenue's re-plant (K1) and the cut-face batter (K5), both LOOK tasks
  with a frame.
- **D5. 313a(o) and 313a(a) stay open** and are not re-closed by this move (§16 items 9–10); the task
  report says so rather than letting a RUN-pace discrepancy be read as a defect of the move.

---

## 18. The build steps

| # | What | What closes it |
|---|---|---|
| **M1** | **The move and the clearing, one task.** `Range.ANCHORS["forest-test"]` x/z and its comment rewritten with §2–§4's numbers; `Range.sightlineFrom`; `Build.sightlineRect` + `Build.keptClear` and its four call sites; `Lobby.start`'s two optional seams through to `Build.build`; `ForestTestBoot`'s composition; `RangeBoot`'s census print; `Lobby.stats()`' two counters; the `backups/` note (rule 7); **and the stale comments fixed in the same commit** — `Lobby.CONFIG.FLAGPOLE`'s *"291 studs from the range's nearest edge (`Range.ANCHORS["forest-test"]` is (2650, −3216)…)"*, which is already wrong by two anchors and becomes **142 studs** to `footprintFor`'s own edge, and `lobby.spec`'s matching comment | §15.1's fourteen cases; one-player harness, `scope=all`; `test2` N/A with the `TWO_PLAYER_PATHS` reason. **No screenshot: nothing in the DEV place changes visually** |
| **M2** | **Her place, live (the Director).** The EDIT pre-flight (D3); the boot lines; the ground profile along the walk (W2); the terrain grid over the terrace (W4); the tree census (W5); `insideHome` on every mat and deck (W7); one real T6 ray sweep (W8); the old-site probe (W9); **the six frames of §15.4, looked at**; `PLAYTEST.md` | W1–W9 measured, the frames inspected, Karen's word |
| **M3** | **Only what M2's frames ask for**: the cut-face batter, the avenue's re-plant, or nothing. Each its own task with its own number | Karen's OK |

M2 needs M1. M3 needs M2 and Karen. Nothing here needs two players, a new asset, a flag or a Studio
click except the Rojo **Connect** and the Play session M2 already costs.
