# One world, eight drive cells: the grid map

**Task 327 / 327a. Written 2026-11-01, before any code (rule 1).**
Design: `docs/design/grid-map.md`. Brief: `reviews/task-327/BRIEF.md`.
Sources below were **fetched on 2026-11-01** from this machine; section 12 of the design listed them
from the Architect's knowledge with no network, so every licence, date and maintenance line here is a
reading, and **three of the design's statements turned out wrong** (section 4 of this note).

## 1. What the system must do

Karen, 2026-11-01 ~18:45 UTC: *"imagine one big terrain where is different trees growing in
different section, mixed then there are in the middle on straing road vertical and horizintal in the
middle so there we have rectangle with 4 smaller rectangles. Then we can devide into 2 more vertical
lines and then 8 rectangles. So each line is road forest road where hunter can stand ... we don't
need several different maps terrains we have one devided in sections"*.

So:

1. **One** world, not four places, cut by straight forest roads into **8 rectangular drive cells**
   (2 rows x 4 columns), with a road on **every** side of every cell.
2. Every road is standable: the hunter line is a road, and several stands sit on it.
3. Each cell must **feel different** from a hunter's eye and a beater's: its own relief, its own
   mixed tree sections.
4. One cell per round; the next cell is chosen (voted), and after eight the cycle resets.
5. Nothing may get slower or odder than the four places Karen plays today.

327a is the first slice: the grid **as data and as surveyed ground**, plus roads painted and cell
corners staked behind a flag, so she can walk the shape before anything else is built on it.

## 2. External sources

### A. Unreal Engine 5 - World Partition (Epic Games)
<https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition-in-unreal-engine>
**Licence:** Epic documentation under the Unreal EULA; **nothing is copied** - no code, no asset,
only the shape of the idea. **Maintenance:** actively maintained; the page fetched today documents
**UE 5.8**, so it has tracked eight engine releases.

**Does well.** It is the industry's answer to Karen's own sentence: *"storing your world in a single
persistent level separated into grid cells"*, with a configurable runtime grid (its example cell is
256 m x 256 m), content authored anywhere and **assigned to a cell automatically**, and only the
cells near the viewer resident. That validates the two decisions this task rests on: one world, and
the cell as the unit of content.

**Does badly.** It is a streaming and *authoring* system for a C++ engine with per-cell control
Roblox does not expose (source F). Its cells are sized for memory; ours is sized by how far a beater
walks in five minutes, which Epic's grid knows nothing about. And the page does **not** say the grid
is uniform or that ids are derived from coordinates - the design claimed both; the first is implicit
in "grid cells", the second is **not in the document**. Ours is uniform and its ids are derived, by
our own choice, and this note is where that is admitted.

**Adopted:** one world; a uniform grid; one active cell at a time; the coordinate-derived id
(`A1`..`D2`).

### B. Minecraft chunks and per-chunk seeding (minecraft.wiki)
<https://minecraft.wiki/w/Chunk>
**Licence:** wiki text **CC BY-NC-SA 3.0** (confirmed on the page). **No code taken.**
**Maintenance:** actively maintained - the page tracks **Java Edition 1.21.11 (snapshot 25w44a)**.

**Does well.** It states the property our forest needs: chunks *"generate with the help of the map
seed, which means that each chunk generates largely the same if you would use the same seed again"*.
A region keyed on `(seed, x, z)` is the same whatever order the regions were built in - exactly what
`drive-places.md` section 10.1 found broken when a planting depended on its own order.

**Does badly, and this is the more useful half.** The page's own caveat is that the result is only
*largely* the same: *"if an entity that can load chunks ... loads from a certain direction the chunk
may generate with slight variations"*, and *"events in a chunk may affect blocks in outside chunks"*
(water, lava, fire, grass spreading across the boundary). A road edge is that boundary, and in this
world a tree that reaches across one stands in a shooting lane.

**Adopted:** `Grid.seedFor(cellId, stream)` = a hash of `(CONFIG.seed, row, column, stream)`, and the
**explicit rejection** of any neighbour-reaching rule: the road lane is a *subtraction applied at the
point* (`Places.inLane`), never a per-cell rule that hopes its neighbour agrees.

### C. SourceMod `mapchooser` (AlliedModders)
<https://github.com/alliedmodders/sourcemod/blob/master/plugins/mapchooser.sp> ·
<https://sm.alliedmods.net/new-api/mapchooser>
**Licence:** **GPL-3.0 with a linking exception** (read off the file header today) - **incompatible
with this repository, so the pattern only and not one line of code.** This paragraph is the rule 2
disclosure. **Maintenance:** actively maintained on `master`.
(The wiki page the design cited, `wiki.alliedmods.net/Mapchooser_(SourceMod)`, is **404** today; the
plugin source and the API reference are the live documents.)

**Does well.** Fifteen years of public-server testing of an end-of-round vote: a candidate list that
**excludes the last N maps played** (`sm_mapvote_exclude`, default **5**; the extended fork adds
`mce_exclude_time`, default 5 h), a fixed-length vote tied to the round's end, and the highest count
wins.

**Does badly - and the design got its tiebreak wrong.** There is **no random tiebreak** in the
standard flow: the winner is *the first item of the results array*, so a tie is resolved by list
order. What it has instead is a **runoff** - `sm_mapvote_runoffpercent`, default **50 %**: if the
leader is under that share, the top two are voted again - plus an **extend the current map** option.
Neither fits a 9-second results screen.

**Adopted:** plurality over the not-yet-driven candidates; **a seeded random on a tie or no votes,
which is ours and not SourceMod's**; the cycle resets after all eight. **Not adopted:** the runoff,
the extend option, nominations, and list-order tiebreaking (it would make cell `A1` win every tie for
ever).

### D. Red Blob Games - "Making maps with noise functions" (Amit Patel)
<https://www.redblobgames.com/maps/terrain-from-noise/> - <https://github.com/amitp/mapgen2>
**Licence:** the article states *"Feel free to copy, port, and use it for your own projects"* - no
formal licence named; `mapgen2` is **Apache-2.0**. **Maintenance:** the article is **actively
maintained** - *"written Jul 2015, then updated in 2016, 2017, 2018, 2019, 2020, and 2022"*, last
modified **29 Sep 2026**. `mapgen2` itself is dormant (nothing substantive since ~2017).

**Does well.** The clearest statement of **character first, then a recipe**: a region gets its kind
from a couple of cheap inputs (elevation and moisture, through a lookup table), and the kind decides
what grows there. That is `Grid.CELLS[i].relief.character` -> the cell's tree recipe, and
`MapGen.Config`'s `OCTAVES` / `LACUNARITY` / `GAIN` / `WARP` are already from this family.

**Does badly.** Its regions are Voronoi polygons grown from a Poisson scatter - nothing like a road
grid - and its whole output is a picture seen from above. It says nothing about what a wood looks
like from a hunter's eye at ground level, which is the only view Karen judges (rule 5).

**Adopted:** character-then-recipe per cell. **Not adopted:** its region shape, and (for `grid:v1`)
its heightfield - the relief here is **measured off Karen's bought terrain**, not generated
(section 3).

### E. Deutscher Jagdverband, *"Sicherheit vor Jagderfolg"*
<https://www.jagdverband.de/sicherheit-vor-jagderfolg> (page dated **14 October 2016**)
**Licence:** editorial text; the **facts** are used and nothing is reproduced beyond the two short
quotations below. **Maintenance:** live publication of Germany's hunting association.
(The design cited WILD UND HUND's *"Drueckjagdstaende - Sicher ist sicher?"*, which answers **403**
to a fetch today; it is already cited in `src/shared/ForestTest/init.luau` on the `edge` layout, so
it stays a repo borrow. The DJV page is the one actually read.)

**Does well.** It is the only source with a number for the thing section 7 of the design is about:
**the shooting angle to a neighbouring shooter must be greater than 30 degrees**; shooting *"in the
direction of persons, automobiles and settlements is strictly forbidden"*; a bullet catch is **only
natural ground**, and the DJV therefore recommends shooting from **elevated** stands - which is why
the grid's stands come in ground and tower kinds, and why towers are not decoration. The 2.50 m
minimum stand height the related guidance gives is **8.9 studs**, against the 12.5-stud deck eye
`HighSeats` already measures from: our towers are, by that figure, high enough.

**Does badly.** It is written about rifles with hundreds of metres between neighbours; a game that
honours all of it has no shots in it. And **our 330-stud separation is not its rule** - the 30-degree
angle is an *angular* constraint between neighbours on the same line, which this project does not
implement; `SafetyArc`'s 45-degree cone is about shooting *into the drive*, a different question.
That gap is named here rather than papered over, and it belongs to a later task.

**Adopted:** stands on three sides and never on the beaters' side; the flank set-back; ground and
tower stands; *know what is behind the animal* implemented as the existing proximity lock.
**Not adopted (yet):** the 30-degree neighbour angle.

### F. Roblox - instance streaming
<https://create.roblox.com/docs/workspace/streaming>
**Licence:** Roblox documentation. **Maintenance:** actively maintained.

**Does well.** It is why a 4,490-stud world is viable on a Roblox client at all: content loads and
unloads with distance, and `Map.STREAMING` records `StreamingEnabled` has been true in this project
since before Milestone 1.

**Does badly, and it set a number this task has to respect.** `StreamingTargetRadius` **defaults to
1024 studs**, and the properties that would raise it *"must be set in Studio on the Workspace
object"* - `Map.STREAMING`'s own measurement is that four of the five are not even readable from
Luau. **A cell is 1430 studs deep, so a hunter on the main line is past the default radius before the
far end of his own cell.** That cannot be asserted by a spec; it is a thing to look at, and it is
written into the honest-gaps list below.

## 3. The pattern adopted, and why

**A uniform grid, cells keyed by coordinate, content per cell, one cell live, relief MEASURED off the
ground Karen already bought.**

Borrowed, not invented (rule 2): the grid and the one live cell from A, the per-cell seed from B, the
vote from C, character-then-recipe from D, three-sided stands from E, and the reason one 4.5 k-stud
world works at all from F.

The one place where this design **declines** a source is the relief. D's heightfield is the obvious
answer and it is refused for a measured reason: `MapGen` writes 128-stud tiles at ~4 s each, and
13.41 M sq studs is ~750 tiles, i.e. **~50 minutes of Edit-time build** driven step by step by a tool
that has never been run in this place - against a survey that takes **one probe** and gives Karen the
ground on the same day. Rule 7 also applies: her bought terrain is not touched. The escape hatch is
the **row's shape** - four measured fields per cell - so a later task that generates the relief writes
the same four fields and no assertion moves.

## 4. Where the design was wrong, now that the sources have been read

1. **SourceMod has no random tiebreak** (source C). It has a runoff and list-order resolution. Our
   seeded roll is our own invention and is now disclosed as one.
2. **World Partition's docs do not say the ids are coordinate-derived** (source A). Ours are, by our
   choice.
3. **The two cited URLs for sources C and E are dead to a fetch** (404 and 403). Live substitutes are
   cited above and the dead ones named.
4. Not an error but a number the design never had: **`StreamingTargetRadius` 1024 < a cell's 1430**
   (source F).

## 5. The numeric targets

### Measured on Karen's own terrain, 2026-11-01 (the survey)

Probes: `327-survey3.luau` .. `327-survey6.luau` in the runs dir, run through `ftplay.py edit`
against the Forest Test place (130094961655666) in Edit. A 100-stud lattice over x,z in
[-7200, 7200] (145 x 145 = 21,025 terrain rays), every `BasePart` in `Workspace` bucketed into it,
then every 4490 x 2986 window ranked.

| | value |
|---|---|
| windows with **zero** non-terrain parts, 100 % terrain coverage **and** a 300-stud margin of terrain all round | **12** |
| chosen origin (the window whose **worst** cell still has the most relief) | **x = -6700, z = -6600** |
| footprint | x [-6700, -2210], z [-6600, -3614] |
| terrain coverage, 20-stud lattice (225 x 150 = **33,750** rays) | **100.000 %** (33,750 / 33,750) |
| non-terrain parts inside the footprint (exact, by position) | **0** |
| whole footprint y range | **50.1 .. 291.2**, spread **241.1** studs |
| per-cell relief spread | **61.7 .. 173.0** studs |
| per-cell main-line spread (what a hunter's eye reads over 1070 studs) | **14.1 .. 70.2** studs |
| characters measured | 3 x `slope`, 5 x `rolling` |
| distance to the four existing drive places (x 3030..4900) | **> 5,100 studs**: no overlap |

For comparison, `drive-places.md` BRIEF M8 measured **58-98** studs over a whole plot and **29-37**
along a 700-stud stand line, with zero non-terrain parts. The grid's ground is of the same kind and
somewhat steeper; D2, at 173 studs, is the steepest cell and the one to look at first.

### Derived, and asserted by `tests/server/grid.spec.luau`

| | value | from |
|---|---|---|
| cell | **1070 x 1430** studs (299.6 x 400.4 m at 0.28 m/stud) | Karen's 300 x 400 m |
| footprint | **4490 x 2986** | 4 x 1070 + 5 x 42 ; 2 x 1430 + 3 x 42 |
| road clear width | **42** | 2 x (halfStrip 9 + `LANE_STUDS` 12) |
| road painted width | **18** | `Places.SURFACES.track.halfWidthStuds` 9 |
| beater walk | **5.2** studs/s -> **275 s** over 1430 | inside `DRIVE.seconds` 300 - grace 15 |
| stands per cell | **7** main at 150 + **4 + 4** flank at 220, flank set-back **340** | section 6.1 |
| cross-side stand separation | **>= 330** studs (`RANGE_STUDS.Slug`); worst pair **356.1** | section 7 |
| road paint calls | **<= 300** `ReplaceMaterial`; **270** at a 1000-stud chunk | section 8.3 |

## 6. Honest gaps

1. **`StreamingTargetRadius` 1024 < cellDepth 1430** (source F). A hunter cannot see his own cell's
   far end at the default radius, and the property is not readable from Luau. Not assertable - it is
   a frame to look at, and a reason a later task may want the radius raised by hand in Studio.
2. **The 30-degree neighbour angle (source E) is not implemented.** Two hunters on the same side of a
   cell are inside slug range of each other, exactly as nine hunters on the `road` layout are today;
   the lock and the penalty are what stand in for it.
3. **1430 studs of bot walk through standing wood has never been measured in this place** - task 162
   measured 580 studs at 120 s with no pathfinding. Section 9 of the design makes it a target.
4. **A Play session's terrain write is discarded when Play stops** is still *carried, not verified* -
   `Places.Ground`'s own header says so, and this note does not change that.
5. The relief is Karen's bought ground, so *"different per cell"* is a measurement and not a dial: if
   she wants a particular cell flatter, the lever is the footprint origin (11 other blocks were
   found) or a later generated heightfield, not a number in `CONFIG`.
