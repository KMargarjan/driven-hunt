# Task 346b — the deeper forest, made cheap and made full, measured in Karen's Forest Test

Place **Driven Hunt Forest Test** (130094961655666). Every side replants the cell first (a Play boot
adopts the prebuilt `Workspace.GridForest`), through `tools/terrainbake.py`'s own `plant_prelude()`
and `PLANT_SEAM` (`<runs-dir>/346-plant.py`) — never a second copy of the planter. Nothing is
written to the place. Driver: `<runs-dir>/346b-run.sh`, built on 346's probes.

- **BEFORE 346** = `driven-hunt-rev` at `29fd976c`. `git diff 1bd9583b 29fd976c -- src tests tools`
  is **empty**, so this IS the build the dispatch names.
- **#360** = a throwaway worktree at `a36899b6`.
- **AFTER** = `driven-hunt` at `b397aa41`, the code commit. `git diff 1d2bc385 b397aa41 -- src` is
  empty, so readings taken at `1d2bc385` are readings of this `src/`; the whole set was re-taken at
  `b397aa41` anyway (section 6, L-162).

## 1. Four instrument faults, found and fixed before anything was claimed (rule 6)

1. **`346-cam.luau` parks the camera only after a 15 s ground-raycast retry loop**, and
   `346-run.sh` shoots at 16 s. A frame whose own output says `ground false` therefore photographs
   the **previous** camera. Measured here: `346b-after-F1.png` and `346b-after-F2.png` came out
   pixel-identical, and F2/F3 swapped twice more. `<runs-dir>/346b-cam.luau` parks first when the
   server has given the height, and each frame is now taken alone.
   **THIS REACHES TASK 346'S OWN FRAMES**: `346-after-F3.png`, labelled "the north road end", is the
   view this instrument produces for the **NE corner** (`346b-afterW-F2.png`). The Director's frame
   check of `346-F3-pair.png` was reading the corner, not the road end.
2. **The game swaps the standing cell on its own drive clock.** A probe run minutes after a replant
   reported cell **C2** and read the new band as absent. Every measurement is now bracketed by
   `346b-cell.luau` and **discarded and retaken if the cell moved** — it was, once (`after` A2).
3. **`Match.phase()` cannot be read from an MCP probe**: the probe gets a fresh `Match` whose phase
   is always `Waiting`. The drive's state is read off `HunterHud` instead (`346b-waitclear.luau`).
4. **Between drives the results card and the stand-pick map cover the whole screen.** Two proof
   frames came out as those panels; frames are now gated on a clear screen.

## 2. The instrument for "how full is the horizon", and its own control (L-141)

`<runs-dir>/346b-ray.luau`, a Play **server** probe. **Two raycast sweeps were tried first and both
read a frame that plainly shows conifers as 100 % open** — the far band stands on hills, so a
horizontal eye-height ray flies under it and a pitched one flies between the crowns. A ray that
misses a tree cannot tell a thin wood from no wood. So it **counts the planted models in each
column's angular wedge**: 37 columns across the frame's own 90 degrees, out to 1,400 studs. OPEN =
that column of the picture holds **no tree at all**.

The control is in every run: **F1, standing inside C1's own wood** (the one Karen accepted in task
328s), reads **0 % open with 1,969–2,008 trees** on all three sides. So a low count at F3 or F2 is a
real hole, not the instrument's floor.

## 3. The dispatch's budget lines — one each, three samples a side, median of three

| line | BEFORE 346 | #360 | AFTER | budget | verdict |
|---|---|---|---|---|---|
| client frame p95, C1 stand 8 | **23.35** (26.58/23.35/19.86) | **23.93** (26.11/23.93/19.73) | **20.31** (20.31/21.48/19.98) | ≤ before+2 = 25.35 | **MET**, −3.04 ms |
| client frame p95, A2 stand 8 | **20.12** (20.82/20.12/19.98) | **21.48** (21.57/19.92/21.48) | **21.83** (22.87/20.25/21.83) | ≤ 22.12 | **MET**, +1.71 ms |
| client memory, C1 stand 8 | 4,241.2 MB | 4,258.4 MB | 4,323.5 MB | ≤ +300 MB | **MET**, +82.3 MB |
| client memory, A2 stand 8 | 4,255.6 MB | 4,244.9 MB | 4,345.4 MB | ≤ +300 MB | **MET**, +89.8 MB |
| cell swap C1→A2, worst SERVER frame | **655.3 ms** | **746.3 ms** | **783.4 ms** | < 100 ms | **NOT MET — and not met before 346 either** |
| drive start: truck pad → gun in hand | **14.11 s** | **13.98 s** | **14.07 s** | < 5 s | **NOT MET — unchanged by this task** |

**The swap line is now measured, not inferred.** 346 recorded it NOT PROVEN because its probe
reported bites and wall ms. `346b-swapframe.luau` opens a `Heartbeat` connection around
`Cells.reconcile` and reports the worst frame the swap was inside. The 100 ms ceiling is breached on
**every** side, worst 783 ms here; `unbudgeted=0` on all three, so no single bite exceeds
`Slice.BUDGET_MS` — the swap spends 45–57 bites inside 4–7 server frames. **This is a standing
defect, not this task's.** Mine adds 37 ms over #360 and 128 ms over the pre-346 build.

**The drive-start line is now measured, not inferred.** 346 reported the BOOT. `346b-padwait.luau`
owns the pad step itself and then polls, so the clock starts where the player commits. All three
sides read ~14 s and `Match.isParticipant` never turns true inside an 18 s window with one player:
**the wait is the one-player lobby's, not the forest's**, and this task moves it by 0.09 s.

**The p95 instrument's own spread is 6.7 ms** inside one build and one session (before-346 C1:
26.58 / 23.35 / 19.86). Three samples a side is what the dispatch asked for and what is reported; a
2 ms budget is inside that spread, so the −3.04 ms is read as "no worse", not as a precise gain.

## 4. Models and parts a cell

| | BEFORE 346 | #360 | AFTER |
|---|---|---|---|
| C1 planned / planted / parts | 3,188 / 3,140 / 11,644 | 3,558 / 3,507 / 12,927 | **4,020 / 3,969 / 14,628** |
| A2 planned / planted / parts | 3,159 / 3,053 / 9,063 | 3,605 / 3,363 / 9,993 | **4,213 / 3,782 / 11,250** |
| cheap models (no shadow, no collision, no raycast) | 0 | 0 | **C1 825, A2 731** |
| `PART_BUDGET_CELL` / `CELL_PART_CAP` | 14,200 / 3,776 | 14,200 / 3,776 | **16,000 / 4,255** |
| `PART_BUDGET_DRIVE` / `CELL_PLAN_CAP` | 29,000 / 7,712 | 29,000 / 7,712 | **32,000 / 8,510** |

## 5. The open fraction along the F1/F2/F3 camera rays — the dispatch's MEASURED NOW

| view | BEFORE 346 | #360 | AFTER |
|---|---|---|---|
| **F3** north road end | **81.0 % open** (30/37 columns empty), 8 trees | **21.6 %** (8/37), 58 trees | **0 %** (0/37), **118 trees**, 105 cheap |
| **F2** C1's NE corner | **100 % open** (37/37), 0 trees | **40.5 %** (15/37), 35 trees | **29.7 %** (11/37), **80 trees**, 80 cheap |
| **F1** C1 stand 4 (control) | 0 %, 1,969 | 0 %, 1,994 | 0 %, 2,008 |

**F3 — the road end — has no empty column left.** Reproducible and not luck: the plan is a pure
function of its seed, and 34 studs read 0/37 in four separate sessions while 36, 38, 42 and 46 all
left 3–4 empty (section 7).

**F2's 11 dead columns are structural, not thin.** Their world bearings are 1–25 degrees
(`346b-ray.luau`'s `emptyBearings`), and `346b-sides.luau` reads the geometry: C1's box is
x −4434..−3364 z −5086..−3656, the footprint x −6700..−2210 z −6600..−3614, and **only C1's north
side is an outer edge** — east is D1. The wedge is the strip **0–230 studs north of the footprint,
east of x −2905** (C1's ground + `SKIRT_WIDEN_STUDS`). Nothing plants it because the widening is
confined to the DEEPEST band on purpose — task 346's own recorded reason is that at 230+ studs it is
clear of every road's frontage. Filling it means widening a near band across another cell's
frontage. **That is a design decision and not a Builder call: it is for the Director.**

## 6. Every live reading re-taken at the code commit (L-162)

At `b397aa41`, Karen's Forest Test, C1 replanted and the cell checked standing:
`models=3969 parts=14628 cheapModels=825`, F3 `0 % open, 118 trees`, F2 `29.7 %, 80`, F1
`0 %, 2008` — identical to the `1d2bc385` readings, as `git diff -- src` predicts.

## 7. Six iteration cycles on the cheap band's grid (core protocol step 2)

| cycle | `SKIRT_CHEAP_SPACING_STUDS` | C1 planted / parts | F3 empty columns | F2 empty columns | distance to target |
|---|---|---|---|---|---|
| 1 | 52 (= `deepSpacingStuds`, #360) | 3,507 / 12,927 | 8 of 37 | 15 of 37 | start |
| 2 | **34** | 3,969 / 14,628 | **0 of 37** | 11 of 37 | F3 met |
| 3 | 42 | 3,694 / 13,628 | 4 of 37 | 12 of 37 | F3 missed |
| 4 | 46 | 3,596 / 13,263 | 4 of 37 | 12 of 37 | F3 missed |
| 5 | 38 | 3,821 / 14,079 | 3 of 37 | 13 of 37 | F3 missed |
| 6 | 36 | 3,881 / 14,335 | 3 of 37 | 10 of 37 | F3 missed |

34 is the loosest grid that closes the road end. F2 does not respond to spacing at all (10–15 empty
whatever the value), which is section 5's structural reading arriving a second way.

## 8. The delete-and-fail proof (L-093), RUN

`local cheap = band.near >= Places.SKIRT_CHEAP_FROM_STUDS` replaced by `local cheap = false` in the
worktree — which kills both halves at once, the flag and the spacing — then replanted in the same
Play server:

| | with the band cheap | producer deleted |
|---|---|---|
| C1 models / parts / cheapModels | 3,969 / 14,628 / **825** | 3,507 / 12,927 / **0** |
| F3 open | **0 %**, 118 trees | **21.6 %**, 58 trees |
| F2 open | 29.7 %, 80 trees | 40.5 %, 35 trees |

Every number falls back **exactly** to the measured #360 column of sections 4 and 5. The SPECS were
run against the deletion too: `grid.spec:2687` (`expect(band.cheap).to.equal(true)`) goes red, as do
the three plan counts. `grid_ground.spec`'s cheap-clone case stays green there and is the OTHER
producer's case — it reddens if the `item.cheap` block in `Places.plantOne` is deleted; **that
half's bite is argued by reading, not run** (V293b). The file was restored and `git status` is
clean.

## 9. Attribute diff (L-101)

`346b-before2-attrs.txt` vs `346b-after2-attrs-end.txt`: all **16 `DHFlag_*` rows** plus
`DHForestStartRole`, `DHShopTestGrant` and `DHTestOwns` are byte-identical. The only two lines that
differ are the harness's own stage clock (`TestStage` boot → no-token, `TestStageTrail`), which no
code in this task writes. `flags.py clear` was never run (lesson K).

## 10. The frames, each opened and described (rule 5, rule F)

All at eye height in Karen's place, the same camera as 346's, taken **one at a time** with a clear
screen and C1 freshly planted and checked standing.

- **`346b-afterW-F3.png`** — the north road end, camera (-4452.3, 143.0, -3613.7), bearing 90.
  Grass and leaf litter in the foreground, a dark conifer mass at the very left edge close to the
  camera, and across the middle distance a **scatter of conifers over a green slope, right out to
  the right edge**. Against `346b-at360d-F3.png` (same camera, #360): the same broadleaf row, with
  several tall dark conifers now filling the gaps in the left-centre. Fuller, but a **scatter and
  not a wall**.
- **`346b-afterW-F2.png`** — C1's NE corner, camera (-3343.0, 110.0, -3635.0), bearing 45. Gravel
  road junction underfoot, a green hill, and a **continuous belt of conifers across the horizon from
  about a quarter of the way in to the right edge**, two to three ranks deep, with a solid dark mass
  on the right. Against `346b-at360d-F2.png` (#360): there the belt is a **broken row of single
  spires with clear sky between them**, starting further right. **The left quarter of the frame is
  bare green hill in both** — that is section 5's wedge, and it is the one thing this frame still
  does not answer.
- **`346b-afterY-F1.png`** — C1 stand 4, camera (-3904.8, 112.4, -5062.0), bearing 90. C1's own
  birch wood, trunks and dappled shadow, a deer crossing. Against `346b-at360d-F1.png`: **no visible
  change**, and that is expected rather than a miss — the far road is 1,430 studs away and the cheap
  band is 230–420 studs beyond it, past the fog. The probe agrees: 1,994 → 2,008 trees in frame,
  0 % open on both sides (L-148, flagged in the dispatch).
