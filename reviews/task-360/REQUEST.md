# Task 360 -- dense forest behind the main-road stands

Task: 360
Round: 1
Base: 9bf829f7
Code commit: 3f93f07c2f8ed5a40de8bb32204a5545ad4a347a

`[harness] PASS: 34/34 checks @ 3f93f07c2f8ed5a40de8bb32204a5545ad4a347a (clean tree) scope=all`

`test2` N/A: nothing in `TWO_PLAYER_PATHS` is touched -- the diff is `src/shared/Places/init.luau`
and `tests/server/grid.spec.luau`, which are forest data and its spec.

## What changed

The **stand side** -- the one road of a cell that carries its seven main-line stands, and the one a
hunter turns round INTO -- was planted as two bands, 0-80 studs at `spacingStuds` 24 and 80-230 at
`deepSpacingStuds` 52, against the cell's own wood in front at 16-26. It is now **one full-density
band, 0-230 at `STAND_SIDE_SPACING_STUDS` 16**, which is C1's own densest canopy zone. The deepest
band (230-420, cheap, 34) and the other three sides are untouched. Two typo-guard ceilings rise with
it. One owner, `Places.skirtBands`; no new owner, no flag, no asset, no design change.

**The measurements, the sweep, the frames and the budget miss are in
`reviews/task-360/MEASUREMENTS.md`**, which this request does not restate.

## PLAN (step 0, committed at 8839ae05 before any `src/` edit)

(a) REAL LIFE: a managed 40-80 year stand carries 2-3 m between stems; C1's own wood is built to it
(`minGapStuds` 11 ~ 3.1 m, canopy 16-26). (b) MEASURED NOW: **78.6 %** of the back half's rays at
eye height left 900 studs of nothing. (c) TARGET: escaped <= 10 %. (d) LEVER: `Places.skirtBands`,
the pasted grep in the PLAN commit. (e) AFTER: the same probe. **(c) is NOT MET -- 50.4 %** --
and MEASUREMENTS section 5 gives the geometric reason and the arithmetic of closing it.

## Claims

1. **The dispatch's own target was already met BEFORE the change, and the instrument it names is
   the wrong one.** Task 352's plan instrument reads the back half at **91.7-100 %** at every one
   of stands 1-7 at `origin/main`. Verify: `360-BEFORE-inj.txt`, the `[360] back` rows.
   MEASUREMENTS section 1 says why (it blocks on a crown at any height; `TEMPLATE_DIMS` has no
   crown base), and names the eye-height raycast's own limit (foliage is `CanQuery = false`).
2. **What Karen photographed, as a number: 78.6 % of back-half rays at eye height escape 900 studs
   of nothing; 12.7 % meet wood within 150.** Verify: `360-ft-eye.luau` run over her Forest Test
   with C1 replanted from `origin/main` -- `360b-eye-BEFORE.txt`.
3. **After: 50.4 % escape, 29.0 % wooded within 150** -- escapes down 28.2 points, wood within 150
   x2.3. Same probe, same seven stands, same session. Verify: `360b-eye-AFTER.txt`.
4. **The frames show it and one of them shows the residue.** `360b-FA-BEFORE.png` vs
   `360b-FA-AFTER.png`, opened and described in MEASUREMENTS section 4; `360b-FB-AFTER.png` still
   has a lit gap on the right.
5. **The frame-p95 budget is NOT met: +11.3 % against a 10 % ceiling** (median of three readings a
   side, same camera, same session). Memory +1.0 %, MET. Not re-run until green (task 79).
   Verify: MEASUREMENTS section 3, `360b-frame-*.txt`.
6. **Both numbers were swept on the REAL instrument, never extrapolated** -- eight pairs, each one
   replanted in her Forest Test and re-measured (`360-sweep.sh`, MEASUREMENTS section 6). The
   plan's eye PROXY ranked the pairs the opposite way round and was discarded. It is not a dial:
   16/22 is denser than 16/30 and reads worse.
7. **A second storey was built for this band and then removed, on the measurement.** At canopy 16
   the shared `minGapStuds` 11 leaves it 34 stems in the whole band (`360-count.txt`) and every
   storey spacing from 22 to 60 reads 48.8-50.0 % escaped. The code, its stream and its capacity
   term are gone rather than shipped as an unmeasurable claim.
8. **A spec that reddens if the band behind the line is not planted** (L-093): `grid.spec` case 16a
   counts the stems inside the stand band's OWN rect -- **605** at 16, against **159** for the
   24/52 pair over the same rect, and the bound IS that old count. Verify: the new case in
   `tests/server/grid.spec.luau`, and `360-count.txt` / `360-oldband.luau` for both numbers.
9. **No cell's own wood moves by one stem, and every cell's skirt does.** All eight cells' plans,
   one instrument both sides, in MEASUREMENTS section 7 -- the `own` column is identical
   throughout. The stand sightlines in FRONT are unchanged as a number, not as a claim.
10. **The two ceilings raised are typo guards, each with its arithmetic in the file**:
    `PART_BUDGET_CELL` 16,000 -> 18,200 (heaviest plan 4,690 models = 17,634 parts, 150 models of
    headroom -- the tightest cell is A1, disclosed per L-165) and `PART_BUDGET_DRIVE` 32,000 ->
    34,500 (heaviest bound, D1's `cellCapacity`, 9,005 sites). `grid.spec` asserts both literals.

## Could not be verified

* **Karen's compass label.** The dispatch describes her frame as looking S/SW behind the stand; the
  frames here read **N** on the same HUD. The direction is right whatever the label: the half these
  rays are cast into is the half that measures 78.6 % empty, and the cell's own 2,433 trees are in
  the other one. Her exact bearing is hers to confirm.
* **The other seven cells are measured as PLANS only.** Only C1 was replanted and photographed; the
  rest are the census in section 7. A cell whose ground is re-baked later re-plans from the same
  code.
* **Stands 8-15.** The eye-height instrument was run over stands 1-7, which is what the dispatch's
  back-half target names. The all-round reading for 1-15 exists on the PLAN instrument only
  (`360-BEFORE-inj.txt`), and section 1 says that instrument does not answer this question.
