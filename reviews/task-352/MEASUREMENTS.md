# Task 352 -- the measurements

Instrument: `<runs-dir>/352-measure.luau`, run through `<runs-dir>/ftplay.py server` in a **DEV Play
session**. It is PURE: it reads `Places.plantCell(id)` and `Places.borderPlan()` and touches no
Instance, so DEV (which holds no tree template at all -- measured below) answers it exactly as the
Forest Test would.

**Why a Play session and not Edit.** StudioMCP's Edit `execute_luau` keeps its own `require` cache:
after Rojo had synced the new `Places`, an Edit probe still returned the OLD module (`Source` read
162,465 chars and contained the new zone, while `require` answered `spacingStuds = 26`). Every run
below therefore starts Play fresh, and the probe prints a **canary** -- `spruceSlopeSpacing`,
`aspenRolling.zones[1].band`, `#PLANTED_CELLS` -- so which module ran is a reading, not a hope.

BEFORE = `origin/main` `42a25d46` (the `src/` changes stashed, same instrument, same session kind).
AFTER = the code commit `7a283b2f`.

---

## 1. The view from the stand

36 rays per stand, every 10 degrees, eye height 5 studs, 150 studs of reach. A direction HITS when
some planting's crown disc (`TEMPLATE_DIMS.crownHalfWidthStuds` x the planting's own scale) crosses
the ray, and only trees at least eye height count -- ground cover is excluded.

**It is measured against that cell's OWN plan and nothing else**, because `Places.Cells` stands one
cell and stores every other in `ServerStorage`: a hunter in C1 cannot see A1's wood whatever is
planted there. A world-wide union would quote wood that is not drawn.

**Excluded as "the road directions":** a direction where half or more of its 150 studs lies in
ground the planter is forbidden to plant -- a road's clear width (`Places.clearOfEveryRoad`), a
shooting lane (`Places.clearOfEveryLane`), **or a cut ride** (`Places.rideSegments`, half of
`RIDE_CLEAR_STUDS`). The rides matter: C1 stand 14's own L ride is 300 studs long and stand 5's V
ride 700, and asking the planter to fill those would be asking it to plant the hunter's sight line.

See `352-table.txt` for the full table. Summary:

| | before | after |
|---|---|---|
| stands measured | 26 | 26 |
| below the 90 % target | 2 | 2 |
| the two | B1-11 86.7 %, A1-4 80.0 %* | A2-14 86.7 %, A1-11 86.7 % |

*A1's BEFORE rows are A1's PLAN. Nothing was planted in A1 at all, so a hunter standing there saw
**no tree whatsoever** -- the honest before-number for all three A1 rows is 0 %.

Moved up: A1-4 (plan 80.0 -> 96.7, from nothing planted), A1-8 (-> 100.0), B1-11 86.7 -> 90.3,
A2-8 93.3 -> 100.0. Moved down: A2-14 90.0 -> 86.7, A2-4 96.7 -> 93.3, B1-4 100.0 -> 96.7,
A1-11 (plan 93.3 -> 86.7). C1 and D1 are untouched in both directions, which is the expected result:
nothing in their recipes moved.

## 2. Trees planted per cell

| cell | has a wood | total plantings | own wood | skirt | ring (outside the footprint) |
|---|---|---|---|---|---|
| A1 | false -> **true** | 3042 -> **4225** | 1343 -> **2301** | 1699 -> 1924 | 970 -> **1031** |
| B1 | true | 3906 -> 3964 | 2299 | 1607 -> 1665 | 395 -> 389 |
| C1 | true | 4020 | 2433 | 1587 | 476 |
| D1 | true | 4157 | 2361 | 1796 | 822 |
| A2 | true | 4213 -> 4172 | 2356 -> 2414 | 1857 -> 1758 | 827 -> 823 |
| B2 | true | 4123 -> 4118 | 2418 | 1705 -> 1700 | 483 |
| C2 | true | 4082 | 2474 | 1608 | 395 |
| D2 | true | 4195 | 2490 | 1705 | 1020 |

Over the cells that HAVE a wood: **28,696 -> 32,933** plantings, of which **4,418 -> 5,439** stand
outside the grid's own footprint (the ring). A1's `own wood` 2,301 is 95 % of C1's pinned 2,418,
inside `grid.spec`'s +-10 % band.

**The cap. `Places.CELL_PART_CAP` is 4,255 and A1 now sits at 4,225 -- 30 of headroom.** That is
measured and it passes, and it is the tightest cell in the world. Anything later that adds to A1's
plan breaches `grid.spec` case 14 before it reaches a frame.

## 3. The outer ring, and what Karen's ring mark actually is

The ring is **already planted and always was**: `Places.skirtBands` with no neighbour runs each
boundary cell's wood from the far kerb of the border road out to `SKIRT_DEEPEST_STUDS` 420, cheap
(no shadow, no collision, no raycast) past 150, and that is the 4,418 ring trees in the BEFORE
column above. **What is bare is the PICTURE, not the ground**: `MapUi.groundFromGrid` and
`<runs-dir>/350/paint.py` both draw one patch per CELL ZONE and nothing else, so no skirt has ever
been on the map Karen marked.

Two things did change the ring: A1's quadrant of it went 0 -> **1,031** trees (A1 was unplanted, so
its skirt was never built), and `<runs-dir>/352/paint.py` now draws the outer skirt, so the picture
ends in woods.

**Not done, and why:** making the ring DENSER is out of budget. A2 stood 42 models under
`CELL_PART_CAP` before this task and D1/D2 stand 60/98 under it now. Raising `PART_BUDGET_CELL`
crosses the only MEASURED ceiling there is -- 328g's client frame, <= 16.7 ms with <= 17,000 parts
inside 1,024 studs -- and a new frame reading can only be taken in Karen's Forest Test, which the
Director's 14:30 addendum puts off limits for this task.

## 4. The iteration (core protocol step 2): A2-14, three cycles

A2-14 is a flank stand that sits 35 studs INSIDE the 80-stud full-pitch skirt band across its road,
and then looks through the deep band's 52-stud lattice. The lever is `skirtFullStuds`.

| cycle | change | A2 plantings (cap 4255) | A2-14 share | distance to 90 % |
|---|---|---|---|---|
| 1 | A1 + A2's two zones (`skirtFullStuds` 80, shipped) | 4194 | 86.7 % | -3.3 |
| 2 | `skirtFullStuds` 80 -> 110 | **4373 -- OVER THE CAP by 118** | 90.0 % | 0.0 |
| 3 | `skirtFullStuds` 80 -> 90 | 4249 (fits) | **76.7 % -- WORSE** | -13.3 |

Cycle 3 is the finding. The share is **not monotone in this knob**: a band's width is the width of
its own seeded jittered grid, so changing it re-rolls every site in the band, and 90 landed worse
than both 80 and 110. Tuning one stand with it is fitting noise, so 80 -- the shipped value -- is
kept and A2-14 is reported NOT MET rather than fixed by a lucky number. A2-4 and A2-14 moving in
opposite directions between BEFORE and AFTER is the same effect.

## 5. What could not be measured, and the reading that says so

`<runs-dir>/352-devworld.txt`, in a DEV Play server:

```
Workspace.OurForest: ABSENT      Workspace.Session: ABSENT
ServerStorage.Sources: ABSENT    Workspace.GridForest: ABSENT
Workspace.GridPlaces: ABSENT     Places.templates found 0 template folder(s)
Places.stats(GridPlaces): folder=false total=0
```

So DEV draws **zero** trees and no frame of this wood can be taken in it. The only place that holds
the templates is Karen's Forest Test, and the Director's 14:30 addendum forbids touching it. The
scripts that would take the frames exist and were not run for that reason:
`<runs-dir>/ftplay.py capture`, `<runs-dir>/346-cam.luau`, `<runs-dir>/ft-open.sh`.

NOT OBTAINABLE this session, each for that one reason: the stand-11 and outer-edge frames; the
client frame p95 and memory at the lobby spawn and at a C1 stand; the cell-load hitch; 349's action
numbers from stands 4 and 11; the real-click stand pick.

**The cell-load hitch has no clean baseline to be "not worse" than.** 337c measured the cell swap at
C1 661 ms and B2 573 ms against `cell-loading.md` T7's 500 ms target and marked it NOT MET. That is
the starting point, not a clean one. This change adds one more cell to the set that can be swapped
and does not change the slice, the order or the budget.
