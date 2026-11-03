# Task 328q — THE BEND, PURE AND INERT AT ZERO

Task: 328q
Round: 1
Base: `main` `1ef61b67` (328o #323 and 328p #324 both merged)
Code commit: `60bc112f`

`[harness] PASS: 34/34 checks @ 60bc112f92b90cedaced353616801647d5de8189 (clean tree) scope=all`

`test2`: **N/A.** No path in `TWO_PLAYER_PATHS` is touched. `src/shared/ForestTest/init.luau` is
changed (`roadZ`) and is **not** in that list; `src/shared/Drive/` and both `Match/` trees are
untouched. Director decision 2026-10-03.

## What changed

Karen, 2026-11-03: *"road could be also not just straight make line in real life"*. The bend's
arithmetic ships; **`Grid.CONFIG.bend` is `{0, 0, 1}` and nothing in any world moves.** 328r switches
it to 45 / 60 by commit. Everything new carries the bend as a **trailing optional**, so both states
are reachable by parameter and every new spec case asserts the bent world while the config sits at 0.

## Claims, each with how to verify it

1. **`Grid` owns the centreline and nothing else holds one.** `Grid.CONFIG.bend`, `bendPitch`,
   `bendOrigin`, `bendZ`, `bendX`, `bendSlopeZ`, `bendSlopeX`, `maxBendStuds`, `toGrid` (the closed
   form, and the definition), `toWorld` (its five-step inverse), `roadCentreAt`, `roadTangentDeg`,
   `roadPolyline`, `bendFacts`, `worldBoundsOf`, `worldFootprint`, `standGridOf`. `Grid` still
   requires only `Shotgun`. Verify: `grep -n "math.sin" src/ --include=*.luau -r` — the only sines
   outside `Grid` are `ForestTest.roadZ`'s own line-place arm, `Places.corridorXAt`'s jitter and
   `Relief`'s landform ops, none of them a road centreline.
2. **Inert, proved against PUBLISHED pre-328q coordinates and not against a recomputation.**
   `grid.spec` → "the bend" → *"IS today's world at amplitude zero, value for value"*: both maps are
   the identity **exactly** over the footprint; all 120 stands of all 8 cells equal the pre-328q
   formula written out in the case to magnitude 0; and three of C1's stand points are quoted from
   `Grid.CELLS`' own `towers` header (task 327b's shared-flank finding) — C1 8 = B1 12 =
   (−4455, −4767), C1 13 = D1 9 = (−3343, −4547), C1 15 = D1 11 = (−3343, −4107). Harness note:
   `inert at bend 0: all 120 stands of 8 cells exact (C1 8 = -4455,-4767; 13 = -3343,-4547;
   15 = -3343,-4107), 1823 plantings in C1, both maps the identity; held at zero: max |bendZ| 45.00,
   max |bendX| 60.00`.
3. **Exactly TWO expected values moved in the whole suite, and both are the epoch.**
   `Relief.epochInput` hashes ten keys, not seven (defect F-2), so its string changed; and
   `tools/terrainbake.py`'s `CANONICAL_FIXTURE_INPUT`/`_OUTPUT` were **re-captured** with the three
   bend rows in them. Nothing geometric moved: `git diff 1ef61b67..60bc112f -- tests/` shows every
   other change is an **added** assertion, a note's format, or the same value reached through the
   seam (`roadGap` from the curve instead of `road.at`, `spot` from `standGridOf` instead of
   `standPosition`, `amplitudeStuds == 0` → `== c.bend.ewStuds`). `EXPECTED_TILES` is **unchanged**,
   and that is correct: `region_for` grows by `max(bendEw, bendNs)` = 0.
4. **The re-capture is a reading off the Luau, not a retyping (D-C).** `grid_relief.spec`'s epoch
   case now runs `Relief.epochInput` on `terrainbake.py`'s own fixture input and prints it. Harness
   note: `grid_relief: epochInput fixture = {"bakeVersion":1,"config":{"bendEwStuds":0,
   "bendHarmonic":1,"bendNsStuds":0,"cellDepthStuds":1430,...` — 346 characters, **byte-for-byte**
   `CANONICAL_FIXTURE_OUTPUT`. `python tools/terrainbake.py selftest` passes with the twin.
5. **`flankFirstStuds` is a WORLD-coordinate fixed point, 340 at 0 and 366 at 45/60** (defect F-1).
   `grid.spec` → "the flank set-back" recomputes it in the case from `cellWidth`, `roadClear`,
   `mainCount`, `mainSpacing`, `RANGE_STUDS.Slug` **and the two bend slopes**, asserts convergence in
   ≤ 3 steps, and pins both answers. It is the identity at amplitude 0, which is what makes the task
   inert.
6. **The 330-stud cross-side invariant is measured in WORLD coordinates at both amplitudes, and the
   realised number is pinned.** `grid.spec` case 5. Harness note: `worst cross-side pair 356.14
   studs (A1 1-8), range 330, margin 26.14; at bend 45/60 363.79 (A1 7-12), margin 33.79`.
   **The pinned 363.79 is what gives the case teeth:** at the un-re-derived set-back of 340 the
   realised worst is 338.41, which still clears 330, so a bare `>= 330` would have passed either way.
7. **The junction zeros are asserted together with the half-pitch extremum** (TASKS.md item (vii)):
   `A·sin(πk)` is 0 for any A, so the zeros alone cannot fail at the born amplitude. Harness note:
   `15 junctions, bend 0 to 1e-12 at every one; at 45/60 the half-pitch offsets are 45.000 / 60.000;
   m=1.5 breaks 2 of 5`.
8. **The exact-translate property replaces the row that restated `cellDepthStuds`** (item (iii)).
   Harness note: `400 stations x 2 amplitudes: worst translate error 4.55e-13, worst cell depth error
   4.55e-13, walk 275.0 s`. Also `15 junction pins, every station an exact zero of the other family`.
9. **`Relief.luau` is not touched and `BAKE_VERSION` stays 1.** The bake hands it GRID coordinates
   and a base reader composed with `Grid.toWorld` (`TerrainBake.shapeTile`'s `baseAtGrid`). Verify:
   `git diff 1ef61b67..60bc112f -- src/shared/Grid/Relief.luau` is `epochInput` and nothing else.
   Harness note: `1056 world points within 51 st of a centreline, at bend 0 and 45/60, all inside the
   grid zero band`; and `50 stations x 2 amplitudes: whole columns everywhere, stair pitch 31.46 studs`.
10. **Every design figure in sections 5.1–5.6 is re-derived and reproduces, and the five that do not
    are corrected in the design.** Harness note: `at 45/60: swing 7.245 / 7.297 deg, plan radius
    2784 / 3659 studs, view 435 / 499, voxel stair 31.5 / 31.2 studs`; `16200 lattice points: worst
    round-trip 0.00e+00 / 1.17e-07 / 1.24e-04 studs at 0, 45-60, 90-120; worst |J-1| 0.0651`;
    `worst facing tilt 7.294 deg at 45/60; cone half 30 deg leaves 22.706 up-drive`. The corrections
    are below.

## What the design said and what measurement says (every one corrected in `grid-roads.md`)

| Design | Measured | Where it is fixed |
|---|---|---|
| 5.4 / F-1 / §0: the shear takes **39.9** studs off `dx`, leaving **3.1** of margin; realised pair **333.1**, and **357.4** after the fix | the linear bound is `0.1280540 × 340 = `**43.54** (the true max change of `bendX` over a 340-stud window is **42.59**); the bound at 340 is **332.44 / 2.44** and at 366 **357.45 / 27.45**; the **realised** worst pair is **338.41** and **363.79** | §0 row, §5.4, §12 F-1, and the §14 delta |
| 5.4: `standPosition("C1", 9).Z − main.at` goes 560 → **586** | 586 / 806 are the **GRID** depths (`standGridOf`); the world z reads **578.83 / 813.49** at 45/60 | §5.4; `grid_ground.spec` asserts the grid form by parameter and leaves the world transcription to 328r |
| 11.1 case 2: round-trip to **1e-6** at twice the bend | 1.17e-7 at 45/60 (1e-6 holds) but **1.24e-4** at 90/120 — `q` quadruples and 5 steps cannot reach 1e-6 | the case asserts the **derived** bound `(ewStuds+nsStuds)·q^steps`, and 1e-6 where it is true |
| 5.3: published minimum **15–30 m**, ours **26 to 52×** looser | source B's Table 4.1: **15 m** Rural Access, **25 m** Collector, no range; our road is wider than both classes, so **≤ 31× / ≤ 41×** against the 25 m floor | §5.3 (both rows), §10 B |
| 5.1 / note: at m = 1.5 **three** of five junctions stop being zeros | **two** (k = 1 and k = 3) | §5.1, asserted in the spec |
| §10 metadata (328o item 1) | FAO 13/5 is **ALL RIGHTS RESERVED, 1998**; source B carries **no copyright notice** and its own URL is **403**, and it has **no "avoid long tangents" rule**; OpenDRIVE is **1.9.0 (2026-05-08) under an ASAM grant**, `poly3` deprecated; the 4-stud voxel is on **`docs/parts/terrain`** and no Roblox page states the lattice is world-axis-aligned | §10 A, B, C, E |
| 5.5: *"0.16 studs narrower perpendicular"* | true for the **painted** 20-stud strip only: the 40-stud level formation narrows **0.33 st** and the 68-stud trunk-free formation **0.56 st**, and every road rule now says which width it means | §5.5, pasted into `grid-terrain.md` §19 |

## Named in the design's §13 list and needing NO edit — said rather than hidden

* **`TerrainBake.blendAt`** — it measures how far a world point is outside the box `unionOf` hands it,
  and `unionOf` now returns `Grid.worldBoundsOf`. No coordinate of its own.
* **`TerrainBake.limitGrid`** — it takes a height grid, a pitch and a ceiling. No coordinates at all,
  and §7.3 keeps the limiter a world-lattice pass.
* **`Places.cellFacts`' cache key** stays `cellId`: with `standGridOf` and grid rides, everything in
  it is a grid fact.

## What could not be verified

* **The curve itself is not measured on baked ground.** `Places`' four seam functions, `Places.mask`
  and `TerrainBake.roadAt` read `Grid.CONFIG.bend` and take no amplitude, so at the shipped 0 their
  two-space identity **is** the identity: `grid_ground.spec`'s *"ONE rule in two spaces"* and
  `grid_relief.spec`'s *"the SAME cross-section along a bend"* are the **inert gate**, not curve
  tests, and both cases say so in their own comments. The curve is tested by parameter wherever the
  bend is a parameter (all of `Grid`, 16,200 lattice points, 400 stations, 1,056 fade points, 50
  band stations, 120 stands × 2 amplitudes); on the real world it is **328r's** measurement.
* **`EXPECTED_TILES` for 328r, computed here and NOT committed** (it must not be: `selftest` compares
  it against `region_for` at the live facts, which are 0): at 45 / 60 it becomes **A1 238, B1 238,
  C1 255, D1 238, A2 238, B2 238, C2 255, D2 238, ALL 1408** — C1 goes 208 → 255. Named so 328r
  does not discover it in a review round.
* **No frame, and none is owed:** nothing in any world changes. No Studio Play, no Forest Test.
* **The DEV harness cannot evidence Forest Test work** and nothing here claims it does.

## Known intermittents that fired, with the count

`deer_hitbox.spec` fired twice on this branch and **passed on the re-run, at the same commit**:
`:659` at `14c9dcee` (*calf: the skull … answered nil, wanted head*) and `:682` at `6d8e8ba2`
(*calf: legs box 1 is unreachable by a flank ray*). Both are named KNOWN INTERMITTENT in the
dispatch. Three clean-tree runs on this branch came back `34/34`: `6d8e8ba2`, `05b5791f` and the
code commit `60bc112f`. No `weapon_shot.spec:1490` and no client intermittent fired.
