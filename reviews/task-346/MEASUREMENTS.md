# Task 346 — the forest behind the roads, measured in Karen's Forest Test

Place **Driven Hunt Forest Test** (130094961655666). Each side is ONE Play session, driven by
`<runs-dir>/346-run.sh`, and **both replant the cell first** — a Play boot adopts the prebuilt
`Workspace.GridForest` saved in the place, so neither side would otherwise show what
`Places.plantCell` plans today. The planter is injected by `tools/terrainbake.py`'s own
`plant_prelude()` and `PLANT_SEAM` (`<runs-dir>/346-plant.py`), never a second copy of it. Nothing
is written to the place: a Play session's `Workspace` is discarded at stop.

- **BEFORE** = `driven-hunt-rev` at `29fd976c` (merged `main`, this branch's base).
- **AFTER** = `driven-hunt` at `c4ab2f99` (the code commit).
- The same named stations on both sides (L-181), the same probe file, the same run script.

## 1. The instrument, and its own control (L-141)

`346-fan.luau`, a Play **server** probe (terrain is whole on the server; the client streams). From
each station it casts 13 horizontal rays at eye height (local ground + 5) over a 120 degree fan.
Each ray is launched where it leaves the cell's rectangle grown by one road width — that is *past
the far road* — and run 400 studs. OPEN = it reached 400 studs without crossing a trunk or canopy;
a fern is stepped over. Two columns: **trunk** (the dispatch's words, wood only) and **eye**
(terrain counted as cover as well, because a hill stops a sight line exactly as a wood does).

**THE CONTROL REFUTES THE 10 % TARGET.** The probe measures itself in the same run, at a spot
everyone agrees is dense and one everyone agrees is bare:

| control | trunk | eye |
|---|---|---|
| `ctrl:dense:C1` — standing inside C1's OWN wood, the one Karen accepted in task 328s | **61.5 %** | 7.7 % |
| `ctrl:open` — the footprint corner furthest from the standing cell, bare ground | **100 %** | 100 % |

A 400-stud horizontal ray at eye height reads **61.5 % open from inside the densest wood in the
game**. The dispatch's target — *no stand, corner or road end above 10 % open* — is therefore
**unreachable by any planting**, because it is far below what the accepted wood itself scores. The
arithmetic agrees: solving the measured interception for an effective blocking width gives about
0.84 studs a stem, and 10 % open over 400 studs needs an optical depth of 2.3 — a stem every ~12
studs over the whole 400, about 3,000 extra models **per side**, against a per-cell ceiling of
3,776 models in total. **REFUTED. A refuted premise is a finished item, not a failure** (core
protocol, step 0).

## 2. Open fraction, before and after — the same 27 stations a cell

`<runs-dir>/346-{before,after}-fan-{C1,A2}.json`, printed by `346-diff.py`.

| | trunk before to after | eye before to after |
|---|---|---|
| C1, all 27 | 91.2 to **91.7 %** | 33.6 to **33.3 %** |
| C1, 15 stands | 84.1 to 85.6 % | 26.2 to 26.2 % |
| C1, 4 corners | 100 to 100 % | 38.5 to 38.5 % |
| C1, 8 road ends | 100 to 99.0 % | 45.2 to 44.2 % |
| A2, all 27 | 93.7 to **92.6 %** | 40.7 to **39.0 %** |

**The metric does not move, and section 1 is why**: at 52-stud spacing a band 190 studs deeper
cannot shift a number that does not separate a dense wood from bare ground. The before run was
taken **twice on the same build** and reproduced to the digit (91.2 / 33.6 and 93.7 / 40.7), so the
flatness is the instrument's and not noise.

## 3. What DID change — the frames, each opened and described (rule 5, rule F)

Eye height, Karen's place, the same camera on both sides (`346-cam.luau`; the ground height is read
on the SERVER, because a client raycast 1,500 studs from the character returns nil).

- **346-F3** — the north road end, camera (-4452, 143, -3614), looking north out of the grid.
  **BEFORE: an empty green hillside, edge to edge, not one tree.** AFTER: a stand of tall conifers
  across the whole horizon beyond the rise. This is Karen's sentence, answered.
- **346-F2** — C1's NE corner at the road junction, camera (-3343, 110, -3635), looking NE at 45
  degrees. BEFORE: birch in the near ground and, through the trunks, a bright open green gap with
  empty haze behind it. AFTER: the same birches, and that gap is closed by a dark band of conifers.
- **346-F1** — C1 stand 4, camera (-3905, 118, -5062), looking north across the cell past the far
  road. **No visible difference**, and that is expected rather than a miss: the far road is 1,430
  studs away and the new band is 230–420 studs beyond it, past the fog. Both frames show C1's own
  birch wood; the after frame also has a herd of red deer crossing, which is the drive clock and
  not this change.

Pairs: `346-F1-pair.png`, `346-F2-pair.png`, `346-F3-pair.png` (before on top).

## 4. The plan and the per-cell census (L-165, L-182)

From `<runs-dir>/346-verify.py` and each run's own `PLANT(...)` line:

| | BEFORE | AFTER |
|---|---|---|
| C1 planned / planted / parts | 3,188 / 3,140 / **11,644** | 3,558 / 3,507 / **12,927** |
| A2 planned / planted / parts | 3,159 / 3,053 / 9,063 | 3,605 / 3,363 / 9,993 |
| heaviest cell of the eight (D2) | 3,256 models | **3,650** models = 13,724 parts at 3.76 |
| `PART_BUDGET_CELL` / `CELL_PART_CAP` | 12,800 / 3,404 | **14,200 / 3,776** |
| `PART_BUDGET_DRIVE` / `CELL_PLAN_CAP` | 27,000 / 7,180 | **29,000 / 7,712** |
| corner quadrants holding wood | **0, on all 8 cells** | every corner an outer edge touches, 26–63 stems each |
| skirt sites past the old 230-stud depth | **0** | 411–515 a cell |
| `Workspace` parts, whole place | **22,878** (census) | 24,161 — derived as before + the measured cell delta; the after census was not re-read in its own pass |

`PARTS_PER_MODEL` is unchanged at 3.76. C1's live wood re-measured **3.707** (11,645 parts for
3,141 models, `346-split.luau`), which 3.76 still bounds. The new cell budget is **2,800 parts
under** the only MEASURED ceiling there is — 328g's client frame, at most 16.7 ms with at most
17,000 parts inside 1,024 studs (`grid-terrain.md` 12.2).

**Only the named cell is touched (L-182).** Every `PLANT` line reports
`destroyed = <that cell's own old models>`, and the six stored cells are identical across every
swap in both runs (`storedParts` 56,281 before the C1 replant and 56,280 after it, the one model
being C1's own `cliff` drop). No cell outside the keep set lost a planting.

## 5. The Director's budget — one line each

| | BEFORE | AFTER | budget | verdict |
|---|---|---|---|---|
| client frame p95, C1 stand 8 | 20.22 ms | **25.73 ms** | +2 ms | **NOT PROVEN — above it**, see below |
| client frame p95, A2 stand 8 | 24.31 ms | 22.05 ms | +2 ms | met |
| client memory, C1 stand 8 | 4,487.9 MB | 4,630.9 MB | +300 MB | **met** (+143.0 MB) |
| cell swap C1 to A2 | 532 ms over 45 bites, `unbudgetedSteps=0` | 536 ms over 44 bites, `unbudgetedSteps=0` | worst server frame under 100 ms | **NOT PROVEN**: this probe reports bites and wall ms, not the worst frame. No bite ran over `Slice.BUDGET_MS`, which is the bound the swap is written against |
| boot — the lobby takes the player | +6 s | +11 s | drive start under 5 s | **NOT MEASURED**: this reading is the boot, not a drive start |

**The p95 line, honestly.** The same build at the same station varies run to run: the before run
was taken **twice**, reading 21.27 then 20.22 ms at C1 stand 8 and 21.54 then 24.31 ms at A2 stand
8 — a spread of 1.05 and 2.77 ms with nothing changed. One sample a side cannot settle a 2 ms
budget: C1's +5.51 ms is larger than its own spread, while A2's −2.26 ms has the opposite sign.
**This is a Director decision, not a Builder claim** — either the budget is breached at C1 and the
deepest band needs a coarser spacing, or the C1 sample is session drift. Recorded as NOT PROVEN.

## 6. Attribute diff (L-101)

`346-before-attrs.txt` vs `346-after-attrs.txt`: all **16 `DHFlag_*` rows plus `DHForestStartRole`,
`DHShopTestGrant` and `DHTestOwns` are byte-identical**. The only two lines that differ are the Play
session's own clocks — `DHBoarHistory`'s `newest=` timestamp and `TestStageAge`'s seconds-since-boot
— which no code in this task writes. `flags.py clear` was never run (lesson K).
