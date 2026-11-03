# REQUEST -- Task 328o: curved grid roads, the research note and the docs round

Task: 328o
Round: 1
Base: `97b2cfbc` (main)
Code commit: `6e54e4fc`

**Docs only.** No file under `src/`, `tests/` or `tools/` is touched, so the harness is N/A
(CLAUDE.md loop step 3's docs-only exemption) and `test2` is N/A. Nothing in the world changed, so
there is no frame and no click proof. Diff: `docs/research/2026-11-03-curved-grid-roads.md` (new),
`docs/research/INDEX.md` (one row), `TASKS.md` (nine rows).

The branch already carried `reviews/task-328o/BRIEF.md`, the Architect's `docs/design/grid-roads.md`
and its `ARCH_RESULT.md` = PASS, plus the Director's decisions at the top of `ESCALATE.md`. **This
round adds the rule-1 note, and that note is the first actual check on the design**: its
`ARCH_RESULT.md` is a bare PASS with no re-derived number and no fetched-URL status, and the design's
own section 16 item 1 says no source was fetched.

## Claims

1. **The note exists and meets rule 1.** `docs/research/2026-11-03-curved-grid-roads.md` has what the
   system must do (section 1), five named and linked external sources with licence and maintenance
   status (section 2), what each does well and badly (section 2), the pattern adopted and why, with the
   rejected alternatives and their reasons (section 3), and the numeric targets (sections 4-5). It is
   indexed in `docs/research/INDEX.md`, newest first. *Verify:* read those sections; `grep` the INDEX
   for `2026-11-03-curved-grid-roads`.
2. **All five sources were actually fetched, and all five carry a correction** -- this is the dispatch's
   item 1 and L-069's failure mode. Section 2 names each fetch, its status, and the delta against the
   design's section 10: OpenDRIVE is **v1.9.0, spec dated 2026-05-08** under an ASAM grant (*"a basic,
   non-exclusive and unlimited license to use the standard ASAM OpenDRIVE"*), not "CC
   attribution/no-derivatives" at "1.8 ... 2024", and `poly3` is deprecated; **FAO 13/5 is ALL RIGHTS
   RESERVED and dated 1998**, not "non-commercial reproduction with attribution" and not 1989; Red Blob
   Games is code MIT-or-Apache-2.0 with the prose the author's, last modified 22 Jun 2026 (the design's
   wording is accurate); Roblox's docs are **CC BY 4.0** as claimed, but the 4-stud voxel is on
   `create.roblox.com/docs/parts/terrain` and **no Roblox page fetched states the lattice is
   world-axis-aligned**. *Verify:* each URL is in section 2 and section 7 with the status beside it.
3. **Source B's "15-30 m" is WRONG, which the dispatch asked to be checked first.** Keller & Sherar
   Table 4.1 gives **Curve Radius 15 m min.** for a Rural Access Road (Road Width 3.5-4.5 m, our class
   -- `grid-terrain.md` 7.1's carriageway is 20 studs = 5.6 m, its painted surface 18 studs = 5.0 m)
   and **25 m min.** for a Collector Road, plus the practice *"Locate roads with a minimum curve radius
   of 15 meters."* **There is no 30 anywhere in the document.** *Verify:* the quoted Table 4.1 in
   section 2 B; the design's section 5.3 row says "15-30 m".
4. **What that changes is ONLY the ratio row, and it changes in our favour** (the dispatch asked this
   question explicitly). The design's *"26 to 52x looser"* is 780/30 to 780/15, so its lower end rests
   on a figure not in the source, and the N-S column's *"same"* is wrong independently because the N-S
   minimum radius is 1,024 m, not 780 m. **Corrected: E-W 52x the 15 m floor (31x the collector floor),
   N-S 68x (41x).** The conclusion -- curvature does not bind, so the amplitude is sized by the sight
   line -- is strengthened. Nothing downstream reads the ratio: section 5.2's amplitudes come from the
   equal-swing rule and the sight figures from `Places.ROAD_TRUNK_FLOOR_STUDS`. *Verify:* section 4
   finding 1; `grep` the design for the ratio and check no other section consumes it.
5. **Every number in the design's sections 5 and 8 was re-derived from `Grid.CONFIG`, not copied**
   (dispatch item 2, CHECKED L-167). Section 4 is a row per number with its inputs: the junction
   pitches 1112 / 1472 from `cellWidthStuds + roadClearStuds` and `cellDepthStuds + roadClearStuds`;
   the first junctions -6679 / -6579 from `originX`/`originZ + roadClearStuds/2`; the swing slopes
   0.12713 / 0.12805; the minimum radii 2784.2 st = 779.6 m and 3659.0 st = 1024.5 m at 1 stud = 0.28 m;
   the sight figures 435.1 / 498.8 and their 2.90 / 2.27 stand gaps; `flankFirstStuds`' `dx0` = 106 from
   `(cellWidthStuds/2 + roadClearStuds/2) - ((mainStandCount-1)/2) * mainSpacingStuds`; the fixed point
   340 -> 365 -> 366; the Jacobian 0.0163 and the five `toWorld` steps to 6.9e-8; 151.21, +0.82 %,
   0.16 st, 0.208 st, 31.46 / 31.24 st. *Verify:* the inputs are the frozen `Grid.CONFIG` in
   `src/shared/Grid/init.luau`; re-run any row.
6. **Two numbers do not reproduce, and they are reported as findings against the design, not silently
   fixed.** (a) Section 5.4's intermediate *"333.1 studs, 3.1 of margin"* is **332.44 and 2.44** -- the
   design's own parenthesised arithmetic `sqrt(62.5^2 + (340-13.5)^2)` evaluates to 332.44, and at full
   precision to 332.444. **The defect the design found is real and worse than it wrote**, and the fix
   (`flankFirstStuds` = **366**, realised worst pair **357.45**, margin **27.45**, stand depths 586 and
   806, span 1026, 404 short of the muster road) reproduces to the decimal. (b) The swing angles are
   **7.245 / 7.297 deg**, not 7.244 / 7.295; the slopes they come from are exact and their 0.052 deg
   difference holds. Neither is blocking; both are corrected in the design's section 14 delta by 328q,
   which 328q's `TASKS.md` row names. *Verify:* section 4 findings 1 and 2.
7. **All of the design's section 8 reproduces exactly:** 5104/1687 = 3.0255 -> **3.03**;
   floor(22000/3.03) = **7260**; floor(8000/3.03) = **2640**; room 2640 - 1687 = **953** models, 20.1 %
   as a spacing cut against the old bound's 2.6 %; C1's 1875 + 516 + 1025 = **3416** against today's
   `grid.spec` case 14 (`capacity < 3600` and `total < 3600`), so **184** of slack; 2640 * 3.03 = 7999
   parts and 8 cells = 64,000; and the refuted ratio's own contradiction, 3600 * 7 = 25,200 against the
   same section's 22,000 ceiling. *Verify:* section 4's capacity paragraph; `tests/server/grid.spec.luau`
   for the two `3600` assertions.
8. **`TASKS.md` carries the 328o status row and the Director's queue in the Director's own words.** The
   order line *"**D-B** RATIFIED: 328g moves after 328h. Order: **328p -> 328q -> 328r -> 328s -> 328h
   -> 328i -> 328g**."* is transcribed verbatim from `ESCALATE.md`'s 328o entry and marked as the
   Director's in each row, as are D-A, D-C, D-D, D-E and all four of K-A..K-D (in 328r's row, the task
   where Karen sees it). Each row's scope is `docs/design/grid-roads.md` section 13's own text.
   *Verify:* rows `328o`, `328p`, `328q`, `328r`, `328s`, `328h`, `328i`, `328g` against the top of
   `ESCALATE.md` and the design's section 13.
9. **F-6 is queued under "before release", not fixed** (the Director's D-E, transcribed). Row
   `328o-F6`, in the before-release part of the table beside `133a`: the six `Places.CORRIDOR.atStuds`
   corridors and `ForestTest.beaterLaneOffset`'s lanes are two different sets of x values, pre-existing,
   neither created nor worsened by the bend. *Verify:* the row, and `grep` `Places.CORRIDOR` /
   `ForestTest.beaterLaneOffset`.
10. **Rule G ran even though this is docs-only:** `python tools/privacy_scan.py selftest` (26 shapes
    caught, 23 allowed forms clean) and `scan` (**0 findings in 1336 tracked text files**, with the note
    staged -- it cites a re-host URL and no local path), `python tools/agents.py selftest` (**all ok**)
    and `python tools/studio_mcp.py selftest` (**PASS**). *Verify:* re-run all four.

## What could not be verified

- **Nothing was measured in Karen's place**, and nothing could be: task 328o is docs-only, no harness
  run, no Studio, no frame, no voxel, no bake. Every repo number is read from the file named beside it;
  every derived number is arithmetic over those. The note's section 6 lists this and six more
  unverified items.
- **Source B's official Forest Service URL is HTTP 403 to this fetcher.** The document was read from a
  complete re-host, named in section 2 B with the evidence that it is the same document (the same title
  page, the same "LOW-VOLUME ROADS BMPS: i..." footers, the same Table 4.1), extracted with
  `pdftotext -layout`. So the design's *"still distributed by the Forest Service's T&D programme"* is
  **not confirmed**; the content is.
- **The 435 / 499-stud sight figures remain a tangent-line approximation** (`0.5*k*d^2` against the
  34-stud corridor), not a ray cast through planted wood. 328r's frame is the measurement.
- **The per-cell 8,000-part ceiling and the world-axis alignment of the voxel lattice are both
  unmeasured/undocumented** as section 6 items 4 and 5 say; 328g owns the first.
