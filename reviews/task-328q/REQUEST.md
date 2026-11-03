# Task 328q — THE BEND, PURE AND INERT AT ZERO

Task: 328q
Round: 3
Base: `main` `1ef61b67` (328o #323 and 328p #324 both merged)
Code commit: `a7267a8d`

`[harness] PASS: 34/34 checks @ a7267a8dfe273e59cfeb48b1549bf9ae1cdd5d41 (clean tree) scope=all`
control at the merge-base: `[harness] PASS: 34/34 checks @ 1ef61b67fd70366a3f2de32d6f335cb1010e089a (clean tree) scope=all`

`test2`: **N/A.** No `TWO_PLAYER_PATHS` path is touched (`src/shared/ForestTest/init.luau`'s `roadZ`
is changed and is not in that list; `src/shared/Drive/` and both `Match/` trees are untouched).
Director decision 2026-10-03.

**NO CODE CHANGED THIS ROUND.** `a7267a8d` is a paperwork commit on top of the fix `87844e02`, and
`git diff a7267a8d..HEAD` is `ESCALATE.md` plus the 328q status row of `TASKS.md` (2 changed lines).
Round 3 is authorised in `ESCALATE.md` (2026-11-03 ~18:35 UTC) to read that fix.

## What this task is

Karen, 2026-11-03: *"road could be also not just straight make line in real life"*. The bend's
arithmetic ships; **`Grid.CONFIG.bend` is `{0, 0, 1}` and nothing in any world moves.** 328r switches
it to 45 / 60 by commit. Everything new carries the bend as a **trailing optional**, so both states
are reachable by parameter and every new case asserts the bent world while the config sits at 0.

## Claims, each with how to verify it

1. **Round 2's finding is fixed, and `Places` no longer mixes the two spaces anywhere.**
   `Places.standTypeFor` reads `Grid.standGridOf(cellId, standIndex)` and compares `spot.X` /
   `spot.Y` (plus `Places.standFacing`, a grid unit vector) against `zoneRect`, `zoneAt` and
   `rideSegments` — all grid facts. Verify: `grep -n "standPosition\|standGridOf"
   src/shared/Places/init.luau` — no `standPosition` call survives in `Places`; and
   `sed -n '/function Places.standTypeFor/,/^end/p'` shows `spot.X` / `spot.Y` only, no `spot.Z`.
   Inert at 0: `standPosition` IS `standGridOf` through `toWorld`, which is the identity at
   amplitude 0 (claim 2).
2. **Inert, proved against PUBLISHED pre-328q coordinates, not a recomputation.** `grid.spec` → "the
   bend" → *"IS today's world at amplitude zero, value for value"*: both maps are the identity
   **exactly**; all 120 stands of all 8 cells equal the pre-328q formula written out in the case to
   magnitude 0; three of C1's points are quoted from `Grid.CELLS`' own untouched 327b `towers`
   header — C1 8 = B1 12 = (−4455, −4767), C1 13 = D1 9 = (−3343, −4547), C1 15 = D1 11 =
   (−3343, −4107). Harness note: `inert at bend 0: all 120 stands of 8 cells exact …, 1823 plantings
   in C1, both maps the identity; held at zero: max |bendZ| 45.00, max |bendX| 60.00`.
3. **`Grid` owns the centreline and nothing else holds one.** `grep -rn "math.sin" src/
   --include=*.luau`: outside `Grid` the sines are `ForestTest.roadZ`'s line-place arm,
   `Places.corridorXAt`'s jitter, `src/shared/Range/`'s four and `MapGen`'s noise — **not one is a
   road centreline**; `Relief.luau` has none. `Grid` still requires only `Shotgun`.
4. **Exactly TWO expected values moved in the whole suite, and both are the epoch.**
   `Relief.epochInput` hashes ten keys (defect F-2) and `tools/terrainbake.py`'s fixture was
   **re-captured**. `git diff 1ef61b67..a7267a8d -- tests/` — every other change is an added
   assertion, a note's format, or the same value through the seam. `EXPECTED_TILES` is unchanged, and
   that is correct: `region_for` grows by `max(bendEw, bendNs)` = 0.
5. **The re-capture is a reading off the Luau (D-C).** `grid_relief.spec`'s epoch case runs
   `Relief.epochInput` on `terrainbake.py`'s own fixture input and prints the 346-character string;
   it is byte-for-byte `CANONICAL_FIXTURE_OUTPUT`. `python tools/terrainbake.py selftest` passes.
6. **`flankFirstStuds` is a WORLD-coordinate fixed point, 340 at 0 and 366 at 45/60** (defect F-1).
   `grid.spec` → "the flank set-back" recomputes it from `cellWidth`, `roadClear`, `mainCount`,
   `mainSpacing`, `RANGE_STUDS.Slug` and the two bend slopes, asserts convergence in ≤ 3 steps, and
   pins both. It is the identity at 0, which is what makes the task inert.
7. **The 330-stud cross-side invariant is measured in world coordinates at both amplitudes and the
   realised number pinned.** Harness note: `worst cross-side pair 356.14 studs (A1 1-8), range 330,
   margin 26.14; at bend 45/60 363.79 (A1 7-12), margin 33.79`. At the un-re-derived 340 the realised
   worst is 338.41, which still clears 330 — so a bare `>= 330` would have passed either way.
8. **The junction zeros are asserted with the half-pitch extremum** (TASKS.md item (vii)), because
   `A·sin(πk)` is 0 for any A. Harness note: `15 junctions, bend 0 to 1e-12 at every one; at 45/60
   the half-pitch offsets are 45.000 / 60.000; m=1.5 breaks 2 of 5`. The case's title now says what
   is measured at which amplitude (round-2 note).
9. **The exact-translate property replaces the row that restated `cellDepthStuds`** (item (iii)).
   Harness note: `200 stations at each of 2 amplitudes: worst translate error 4.55e-13, worst cell
   depth error 4.55e-13, walk 275.0 s` — the double count in that note is fixed (round-2 note).
10. **The round-trip bound carries a factor of 2** (round-2 note: 2.6 % of margin would redden a
    correct map on one `math.sin` ulp), and `luau_facts`' three bend rows are `int()`-wrapped like
    the twelve above them. Harness note: `16200 lattice points: worst round-trip 0.00e+00 /
    1.17e-07 / 1.24e-04 studs at 0, 45-60, 90-120; worst |J-1| 0.0651`.

## Design figures corrected in `grid-roads.md` (measurement, not the design, decided each)

5.4's 333.1 / 3.1 and 357.4 are **linear bounds** (332.44 / 2.44 and 357.45), not realised pairs; the
shear's bound off `dx` is **43.54** (true max change 42.59), not 39.9; 5.4's 586 / 806 are **grid**
depths (world z 578.83 / 813.49); 11.1 case 2's 1e-6 is unreachable at 90/120 (1.24e-4), so the case
asserts the derived bound; 5.1's *"three of five junctions"* is **two**; 5.3's published minima are
15 m / 25 m with our road wider than both classes (≤ 31× / ≤ 41×, not 26–52×); 5.5's 0.16 studs holds
for the **painted** 20-stud strip only (40-stud formation 0.33, 68-stud 0.56); and §10's metadata
carries all five of 328o's source corrections.

## What could not be verified

* **The curve is not measured on baked ground.** `Places`' seam functions, `Places.mask` and
  `TerrainBake.roadAt` take no amplitude, so at 0 their two-space identity **is** the identity:
  `grid_ground.spec`'s *"ONE rule in two spaces"* and `grid_relief.spec`'s *"the SAME cross-section
  along a bend"* are the **inert gate**, not curve tests, and say so in their own comments. The curve
  is tested by parameter wherever the bend is one; on the real world it is **328r's** measurement.
* **Rule 5 / core items 5 and 6** (the flank set-back, the 330-stud invariant) are **NOT PROVEN in
  Karen's place** and need not be at this commit: nothing in any world changes. 328r's commit is the
  first time either can be judged on screen. No frame is owed and none is claimed.
* **`EXPECTED_TILES` for 328r, computed and deliberately NOT committed** (`selftest` compares it with
  `region_for` at the live facts, which are 0): A1 238, B1 238, C1 **255**, D1 238, A2 238, B2 238,
  C2 **255**, D2 238, ALL **1408**.
* Queued in `TASKS.md`, not fixed here (Reviewer notes (a)–(e)): the trailing-optional treatment for
  `roadDistanceGrid` / `maskGrid` / `TerrainBake.roadAt`, that function's axis-aligned road pick,
  `survey` / `roadDistance`'s grid range with a world reader, and `toWorld`'s cost per ask.

## Known intermittents that fired, with the count

`deer_hitbox.spec:659` (*calf: the skull … answered nil, wanted head*) failed **three consecutive
clean-tree runs at this same code commit `a7267a8d`**, then the merge-base control `1ef61b67` passed
34/34, then `a7267a8d` itself passed 34/34 — the two harness lines above are those two commits. It is
therefore **Studio-session state, not a commit property**: the spec requires `Assets`, `Loader`,
`Pierce`, `Boar`, `TestKit`, `Weapon` — not one file this branch touches — and builds its own plate.
Earlier on the branch `:659` fired once at `14c9dcee` and `:682` once at `6d8e8ba2`, each passing on
a re-run at the same commit. No `weapon_shot.spec:1490` and no client intermittent fired.
