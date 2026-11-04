PASS (item 10 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the DENSITY has been seen in
Karen's place -- six eye-height frames in Play at the FT (130094961655666), one held point
~(-3916, 110, -5063) on C1's main road, three before/after pairs with distinct shas, each described
(F1 "closed treeline both sides", F2 "visibly more stems and a lined verge", F3 "a layered screen of
spruce"). What has NOT been seen is claim 10, the ANIMAL item: the crossing of a bent road segment is
COUNTED by `<runs-dir>/328s-sampler.luau` (27 crossings in 120 s, one cub -5025 -> -5102 across a
road centre at -5062.65, 0 stuck > 3 s, 2 of 80 no-progress >= 6 s) and no frame shows an animal on
that road. 328r's item 9 was NOT PROVEN for exactly this; a number from a sampler is not the thing
Karen judges when she plays, so item 10 stays NOT PROVEN rather than being closed by arithmetic.

Verified against the repo, not taken from the request:
- Harness: `[harness] PASS: 34/34 @ 871f7655a0c44989ee47e6b983f70655d1f84444 (clean tree) scope=all`
  names the request's `Code commit:`; `log.txt` shows `871f7655` is the last commit touching
  `src/`/`tests/`/`tools/`; `paperwork-after-code-commit.txt` says OK (only ESCALATE.md, TASKS.md,
  REQUEST.md after it). selene 0/0, stylua exit 0, rojo build exit 0.
- `[harness2]` N/A is correct and not justified by a stale path list (verdict 280's rule):
  `changed-files.txt` is `src/shared/Places/init.luau` + `tests/server/grid.spec.luau`, and neither
  prefix is in `agents.py` `TWO_PLAYER_PATHS`.
- DELETE THE PRODUCER, case by case. `grid.spec` case 5's `expect(#drawn).to.equal(2458)`, case
  "the bend"'s `expect(#drawn).to.equal(2448)` / `.equal(2458)`, and the new case's
  `expect(#rows >= 2300)` all read `Plan.plantCell("C1")`; revert the four `mixedRolling` rows
  (16/22/21, under 30, 24/52, gap 11) and every one of them reddens at 1789/1803. The new case's
  `expect(tally.planted).to.equal(#rows)` is NOT the same identity twice: delete
  `Places.resetTally()` from `plantCell` and it fails, because case 14's own `woods` loop has already
  run `plantCell` eight times. `tally` nil (feature deleted) errors the case.
- The refactor of `scatter` is behaviour-identical: `blocked = hasRows and tooClose(...)` preserves
  the original conjunction's short-circuit, so `tooClose` -- which RESERVES the site -- is still
  called exactly once per in-rect unmasked site, and the crown arm is the same `~= nil` test under a
  local. Bucket arithmetic is exhaustive and disjoint by reading: outside | mask | noRows | gap |
  (noRows on empty names | crown | planted).
- `mixedRolling` is C1's recipe alone (`src/shared/Grid/init.luau`, C1's `recipe = "mixedRolling"`),
  and its `spacingStuds`/`deepSpacingStuds` reach only `Places.skirtBands` and `cellCapacity`'s skirt
  term (no `bands` field, so `Places.layer`'s line-place path never reads them). `oakPark`, the
  clearing and the two scrub zones are untouched in the diff. So "the other seven cells unchanged"
  holds: a neighbour's skirt into C1 reads C1's zone MIX and BAND, neither of which moved.
- Arithmetic: 22000/3.03 -> 7260, 8000/3.03 -> 2640; 2640-2448 = 192; 7260-5097 = 2163;
  2448/1789 = +36.8 %; 38/2448 = 1.55 %; 7279/2410 = 3.02. The base tally closes exactly:
  1789+418+481+360+243+121 = 3412, and the mask split 152+140+75+53+36+15+10 = 481.
- Claim 7's mechanism is exactly what the repo shows: `GridCensus.report` takes
  `clawOf: (string) -> number`, `src/shared/Places` (= grid.spec's `Plan`, ReplicatedStorage.Places)
  has no `clawOf`, and the claw lives in `src/server/Places` as `CLAW_FRACTION` / `clawFor`. Var11
  0.0425 and Var13 0.0239 are the shipped rows, and 83.0x0.0425 = 3.53, 87.2x0.0239 = 2.08.
- Claim 8 is verbatim: `GridCensus/init.luau`'s `inLane` block ends *"never 0 for a grid cell"*.
- Claim 10's bend figure is consistent with the shipped amplitude: `Grid.CONFIG.bend.ewStuds = 45`
  bounds the quoted 44.35, and the cub's z pair straddles the quoted road centre.

## Notes (non-blocking)
- `src/shared/Places/init.luau`, `mixedRolling`'s v4 note — *"Raising the offer to 5,438 (one notch
  past these rows) bought only 204 more trees and cost 380 more gap refusals"*. Those two deltas are
  cycle 1 -> cycle 2 (2,355 -> 2,559, 775 -> 947... 1,155), not "one notch past these rows": against
  the SHIPPED rows cycle 2 bought 111 more trees and 208 more gap refusals. The conclusion (the gap
  rule binds, these rows sit at its knee) survives either baseline; the sentence names the wrong one.
  The request's own ITERATION table frames it correctly.
- `src/shared/Places/init.luau`, `mixedRolling`'s v3 header — the bullet *"`spruceThicket`,
  `mixedWood`, `birchStand` -- CLOSER (24/32/30 -> 21/28/27)"* and *"these rows put its capacity at
  3,416"* are now the v1/v3 derivation, and only the capacity half is corrected below. A reader who
  stops at the bullets gets 21/28/27 as today's rows. One "(superseded by v4)" on the bullet fixes it.
- `tests/server/grid.spec.luau`, the new case — `expect(sum).to.equal(tally.offered)` cannot fail
  against today's `scatter`: every arm is counted by construction, so the line is a forward guard for
  an uncounted arm and nothing else. Its own comment says that, which is why this is a note and not a
  finding; the case's teeth are the `>= 2300` floor.
- `tests/server/grid.spec.luau`, the understorey case — the shear comment still reads *"a 12-stud
  grid gap can read 10.47 in the world"*. `minGapStuds` is now 11, so the example is 11 x 0.8724 =
  9.60. The assertion itself reads `plan.minGapStuds * shrink` and is right; only the number in the
  prose is stale. Same case: `expect(saplings > 381)` is now a very loose floor with `under` at 30.
- `src/shared/Places/init.luau`, `Places.plantCell`'s header — still *"PURE -- no Instance, no
  terrain, no `Workspace`, and no `y`"* and *"A PURE FUNCTION OF THE CELL ID AND NOTHING ELSE"*. It
  now writes module state (`Places.resetTally()`). The RETURN is still pure of its arguments; one
  clause naming the tally as the single side effect keeps the header true.
- `src/shared/Places/init.luau`, `tallyBump("noRows")` — two different losses share one bucket: `pick`
  answering no rows (before `tooClose`), and `Places.namesOf(group)` answering an empty list AFTER
  `tooClose` has reserved the site. The second is a quarantined-template loss that also costs a
  reserved slot in the neighbour grid; a `quarantined` counter would say which is which, and the
  printed split would stop blaming the mix table for a quarantine.
- `reviews/task-328s/REQUEST.md` claim 7 and the `TASKS.md` 328s row — *"the two largest
  `Places.CLAW_FRACTION` rows"* is wrong against the table: `SilverBirch_Var07_LOD_0 = 0.0562` is the
  largest and `Var13 = 0.0239` is the second smallest of the five. The arithmetic and the conclusion
  (`sunk` is 0 with the real `clawFor`) are unaffected; the descriptor is. Worth a sentence for the
  Director, because "why only Var11 and Var13 and not Var07" is the one question the diagnosis leaves.
- `reviews/task-328s/REQUEST.md` claim 6 — `foliageInGround` 77 sits outside the "0 on every counter
  that can be 0" list with no reason given, unlike `inLane`, which gets claim 8. It is task 328l's by
  the Director's 2026-11-03 ESCALATE decision ("takes `foliageInGround` ... toward 0"); say so, or the
  73 -> 77 rise reads as unexplained. (Per tree it fell, 4.17 % -> 3.20 %.)
- No dress/plant TIME is reported for the denser cell. `TASKS.md` reports 92 ms for the PLAN, which is
  328r note (e) answered, but design 8.3's *"whole cell planted < 4.0 s"* is about the DRESS, and that
  is the number 37 % more models moves. `Places.dressCell` is frame-budgeted so nothing breaks; the
  boot already prints `planted.gridSeconds`, so quoting it costs one paste next round.
- `docs/design/grid-roads.md` 8.3's table still reads *"C1 drawn 1,687 / room 953 / 20 %"*. 328p note
  (a) is pasted into the `mixedRolling` header (817, not 953) but the design table it names as the
  thing needing correction is untouched, and is now doubly stale (2,448 / 192). Outside this task's
  stated scope -- queue it with the other unpasted section 14 deltas in the 328r row's item (i).

---
REVIEWER verdict on commit `139a5850c45b135f72d92dea44f7e6ac726afc17` (round 1) · 2026-11-04 07:03 UTC · session cost $3.39, 39 turns · written by tools/agents.py
