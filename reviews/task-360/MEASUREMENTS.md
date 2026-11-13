# Task 360 -- measurements

Place **Driven Hunt Forest Test** (130094961655666). **Every side replants C1 first** through
`346-plant.py` (`tools/terrainbake.py`'s own `plant_prelude()` and `PLANT_SEAM`) from the worktree
named by `PLANT_REPO`, because a Play boot adopts the prebuilt `Workspace.GridForest` -- which still
stands at task 346b's BEFORE (3,141 models) and would show neither side's plan. Both sides are
therefore the same instrument (L-181). Nothing is written to the place: a Play session's Workspace
is discarded at stop. Script: `<runs-dir>/360-both.sh`, one Play session, BEFORE then AFTER.

## 1. The two instruments disagree, and that is the first finding

| instrument | what it reads | back half, stands 1-7, BEFORE |
|---|---|---|
| task 352's plan instrument (`360-measure.luau`) | a crown's half-width at ANY height | **91.7-100 %** hit within 150 studs |
| eye-height raycast on the drawn models (`360-ft-eye.luau`) | what a 5-stud eye meets | **12.7 %** wooded within 150; **78.6 %** of rays escape 900 studs |

**The dispatch's `>= 90 %` target was already met before any change**, at every one of stands 1-7
and at every C1 stand 1-15 all round (`360-BEFORE-inj.txt`). The plan instrument blocks on
`crownHalfWidthStuds` regardless of height and `TEMPLATE_DIMS` carries no crown base, so it counts a
crown a hunter sees UNDER -- which is exactly Karen's frame (high crowns, bare trunks, hills
through). The eye-height raycast is this task's instrument.

**It is a LOWER BOUND, and the limit is named here rather than left for the reader:** foliage is
`CanQuery = false` and non-colliding (`src/server/Places/init.luau`, task 328b's own measurement),
so a ray reads trunks and colliding branches while a player reads leaves. The frames in section 4
are what settle anything the ray cannot.

## 2. BEFORE | AFTER, one Play session, `3f93f07c`

252 rays: stands 1-7, eye 5 studs above the measured ground, the 180 degrees away from the cell.

| | BEFORE | AFTER | change |
|---|---|---|---|
| wooded within 150 studs | 32/252 **12.7 %** | 73/252 **29.0 %** | **+16.3 pts, x2.3** |
| blocked within 900 studs | 54/252 **21.4 %** | 125/252 **49.6 %** | +28.2 pts |
| **escaped 900 studs of nothing** | 198/252 **78.6 %** | 127/252 **50.4 %** | **-28.2 pts** |
| C1 planted models / parts | 3,968 / 14,627 | 4,431 / 16,344 | +11.7 % parts |

## 3. The cost, and the one budget NOT met

Three readings a side, same camera (C1 stand 4, eye height, Karen's angle), same session.

| | BEFORE | AFTER | budget | verdict |
|---|---|---|---|---|
| client frame p95 (ms) | 19.68 / 22.76 / 22.82 (median **22.76**) | 25.34 / 27.75 / 21.30 (median **25.34**) | <= before + 10 % = 25.04 | **NOT MET, +11.3 %** |
| client memory (MB) | 5677.5 / 5676.6 / 5687.4 (mean **5680.5**) | 5743.5 / 5738.4 / 5728.5 (mean **5736.8**) | <= +10 % | **MET, +1.0 %** |
| C1 parts | 14,627 | 16,344 | reported | +11.7 % |

**The frame miss is reported as a miss.** The three readings overlap -- AFTER's best (21.30) beats
BEFORE's median -- so the spread is wide and a median-to-median comparison is the strictest reading
available; it is the one quoted. **It is NOT re-run until green** (task 79's rule).

Part ceilings, both typo guards, both raised with the arithmetic in the file: `PART_BUDGET_CELL`
16,000 -> 18,200 (heaviest plan 4,225 -> 4,690 models = 17,634 parts, 150 models of headroom) and
`PART_BUDGET_DRIVE` 32,000 -> 34,500 (heaviest BOUND, D1's `cellCapacity`, 8,243 -> 9,005 sites).
**Disclosed per L-165: the tightest cell is now A1 at 4,690 against a 4,840 cap.**

## 4. The frames (rule 5, opened and described)

Camera held at C1 stand 4, eye height 112.4, through `RunService:BindToRenderStep` ABOVE the game's
own camera owner -- without that the capture photographs the player's view, which cost two runs.

* `360b-FA-BEFORE.png` / `360b-FA-AFTER.png` -- away from the cell, Karen's angle. **BEFORE:** thin
  widely spaced trunks, a broad mown lawn running through the middle of the frame into the distance,
  and bright sky between every trunk; the wood thins to nothing on the right. **AFTER:** a
  continuous dark wall of trunks across the whole width, crowns overlapping and closing the top of
  the frame, and the sky between the trunks almost entirely gone; the open ground is a shallow strip
  at the tree line instead of a lawn running away.
* `360b-FB-BEFORE.png` / `360b-FB-AFTER.png` -- straight back. **AFTER:** dense dark wood with a
  closed canopy overhead. **A lit gap remains on the right**, where the eye still reaches open
  ground -- the honest residue of the 50.4 % that still escapes.
* `360b-FC-*.png` -- the opposite half, into the cell, unchanged either side (the control).

## 5. What is NOT met, and the arithmetic

The dispatch asks for **no bare hills or horizon visible through the wood at eye height**. At
**50.4 %** escaped that is **NOT MET**, and the ceiling is geometric rather than a tuning failure:
the terrain trim keeps only ~490 studs of ground past the footprint (`grid-terrain.md` 10.2's K1),
`SKIRT_DEEPEST_STUDS` is 420, so **420 studs is all the wood there can ever be behind the line**.
A ray that survives 420 studs sees the hills, and nothing in this owner can plant them out.

Closing it would need the whole 0-420 band at roughly 19 studs on the sweep's own curve, which is
about 1,240 sites against today's 382 -- roughly **+700 models a cell**, past the only MEASURED
ceiling there is (328g's <= 16.7 ms with <= 17,000 parts inside 1,024 studs) and on top of a frame
p95 that already misses its budget here. **That is a decision for the Director, not a dial.**

## 6. The sweep, on the real instrument (`360-sweep.sh`)

The plan's eye PROXY ranked 30/16 above 22/36; the raycast ranked them the other way round, so the
proxy was discarded and every pair below was **replanted in Karen's Forest Test and re-measured**.

| canopy / storey | planted | parts | escaped |
|---|---|---|---|
| BEFORE (24 then 52, no storey) | 3,968 | 14,627 | 78.6 % |
| 22 / 36 | 4,269 | 15,764 | 59.1 % |
| 22 / 24 | 4,348 | 16,056 | 57.9 % |
| **16 / 30 (shipped, storey then removed)** | 4,468 | 16,477 | **48.8 %** |
| 16 / 22 | 4,493 | 16,573 | 49.2 % |
| 16 / 36 | 4,457 | 16,443 | 50.0 % |
| 16 / 60 (storey all but absent) | 4,440 | 16,378 | 49.6 % |
| 14 / 30 | 4,544 | 16,793 | 47.2 % |
| 12 / 30 | 4,614 | 17,001 | 44.0 % |

**The canopy carries it and the storey does not** -- at canopy 16 every storey spacing from 22 to 60
reads 48.8-50.0 %. A second storey WAS built for the stand side and was then **removed**: at 16 the
shared `minGapStuds` 11 leaves it **34 stems** in the whole band (`360-count.txt`), because the
canopy already fills the gap rule. 16 is C1's own densest canopy zone, which is the dispatch's "as
dense as the wood in front"; past it the curve flattens while the parts do not.
The lesson's warning held: it is **not a dial** -- 16/22 is denser than 16/30 and reads worse.

## 7. Every cell moves, and none is claimed untouched (L-182)

Every cell has a main line, so every cell's stand side is replanted. The census is the WHOLE
eight-cell plan, taken through one instrument at `origin/main` and at the code commit
(`360-BEFORE-inj.txt`, `360-AFTER-plan.txt`), not a count of the cells this task names.

| cell | BEFORE own / skirt / total | AFTER own / skirt / total | total |
|---|---|---|---|
| A1 | 2301 / 1924 / **4225** | 2301 / 2389 / **4690** | +465 |
| B1 | 2299 / 1665 / **3964** | 2299 / 2105 / **4404** | +440 |
| C1 | 2433 / 1587 / **4020** | 2433 / 2050 / **4483** | +463 |
| D1 | 2361 / 1796 / **4157** | 2361 / 2257 / **4618** | +461 |
| A2 | 2414 / 1758 / **4172** | 2414 / 2260 / **4674** | +502 |
| B2 | 2418 / 1700 / **4118** | 2418 / 2255 / **4673** | +555 |
| C2 | 2474 / 1608 / **4082** | 2474 / 2071 / **4545** | +463 |
| D2 | 2490 / 1705 / **4195** | 2490 / 2201 / **4691** | +496 |

**No cell's OWN wood moves by a single stem** -- every `own` column is identical, which is what the
change being confined to `skirtBands` means, and it is the dispatch's "keep the stand sightlines in
FRONT unchanged" as a number rather than a claim.
