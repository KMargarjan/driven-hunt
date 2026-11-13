PASS

Rule 5, stated so this PASS is not read as rule 5 having been met: this task has no CORE item --
no animal behaviour and no shooting path is touched, the diff is forest data and its spec. What WAS
seen in Karen's own place (Forest Test 130094961655666): the C1 stand-4 eye-height view behind the
line, BEFORE and AFTER, opened and described in MEASUREMENTS section 4, including the residual lit
gap in `360b-FB-AFTER.png`. What was NOT seen by anyone: a drive with animals moving through the new
band -- which is the half of Karen's *"I don't want to have that feeling that animals comes from
nowhere"* that only a played drive can answer; stands 8-15; and seven of the eight cells, which are
plan censuses only. Both sides of every frame were taken with C1 injected by `346-plant.py` rather
than on a normal Play boot, which the Builder discloses.

## Notes (non-blocking)
- `Places.skirtBands` / the `stand` field — the comment "THE STAND SIDE'S NEAR BAND, which
  `plantCell` gives a second storey to" is false at HEAD: nothing in `plantCell` or anywhere else in
  `src/` reads `band.stand` (grep: the only reads are `grid.spec`), and claim 7 says the storey was
  removed. `grid.spec` case 16a's header repeats it -- "it carries a SECOND STOREY, which the other
  three do not" -- and the case asserts no storey at all. Drop both clauses.
- `Places.PART_BUDGET_CELL` — two contradictory "**RAISED AGAIN IN TASK 360**" paragraphs stand one
  above the other. The first ("the heaviest plan goes 4,225 to 4,483 models = 16,856 parts at 3.76,
  so 17,000 leaves 38 models") is a superseded draft sitting directly above `= 18200`, and it also
  calls C1's 4,483 the heaviest plan where the census says A1's 4,690. Delete the first paragraph.
- `Places.skirtBands` header — "measured at eye height behind C1 40.5 % of the back half's rays left
  900 studs of nothing (`<runs-dir>/360-FT-BEFORE.txt`)" contradicts this task's own headline, 78.6 %
  from `360b-eye-BEFORE.txt` (REQUEST claim 2, MEASUREMENTS sections 1 and 2). The shipped comment
  carries the superseded instrument's number and is the one a later task will cite.
- `grid.spec` case 16a, the `backWood` loop — it compares a planting's WORLD `item.x` / `item.z`
  against the band's GRID rect, raw. The same file forbids exactly this a few hundred lines down:
  "A BAND RECT IS IN GRID SPACE AND A PLANTING IS IN WORLD SPACE, which is what case 16a's
  `Grid.toGrid` is for: comparing them raw counted 193 of C1's cheap sites as strays on the first
  run" -- and the gap-rule block inside case 16a itself calls `Grid.toGrid(item.x, item.z)`. With
  `bend.ewStuds = 45` / `nsStuds = 60` the counting window slides up to 45 studs in z and 60 in x, so
  the sentence "it cannot be satisfied by the cell's wood or by another side's skirt" is overstated
  by roughly the 3 studs by which the slide overruns the road gap. Not blocking: 605 against a bound
  of 159 is far outside that margin and the case still reddens when the band is deleted. Fix is one
  line plus a re-derivation of 605/159. (Same shape as task 346a note (e), which was accepted as a
  note; this is the second occurrence, so it is worth closing.)
- `grid.spec` case 16a — `expect((standBand).spacing).to.equal(Plan.STAND_SIDE_SPACING_STUDS)` is
  near the identity that was task 346b's round-1 blocking finding: `skirtBands` assigns that constant
  into the band. It has teeth only against the `if cheap then SKIRT_CHEAP_SPACING_STUDS` branch. The
  case survives because `#bandList == 2`, `standSides == 1` and `backWood > 159` do the work.
- REQUEST claim 10 — "`grid.spec` asserts both literals" is not what the spec does: it asserts the
  derived `CELL_PLAN_CAP` 9175 and `CELL_PART_CAP` 4840. Any `PART_BUDGET_CELL` in 18,199..18,202
  produces 4,840, so the literals themselves are unpinned.
- `docs/design/grid-map.md` §8.2 — still describes the skirt as "`80` studs at the active cell's own
  spacing (full density), then to `skirtStuds` 230 at `deepSpacingStuds` 60", which is now wrong on
  one of the four sides. The request's "no design change" is not true of that sentence. The doc was
  already behind (52, not 60, and no 230-420 band since task 346), so this widens an existing drift
  rather than starting one -- queue a design round for the whole §8.2 paragraph.
- `docs/design/grid-roads.md` §8 — publishes 3.03 parts a model, 22,000 / 8,000 budgets and 7,260 /
  2,640 caps, while `grid.spec` case 14's own comment claims the pair is asserted "AT THE PAIR THE
  DESIGN PUBLISHES ... so a change to the ratio or to either budget reddens here before it ships
  undocumented". Four tasks (337c, 346, 346b, 360) have now moved the numbers without the doc. Same
  queue as above.
- THE ONE THING IN THIS CHANGE THAT COSTS THE GAME, and it is a Director call, not a defect:
  client frame p95 at the C1 stand goes 22.76 -> 25.34 ms median, **+11.3 % against a +10 % budget,
  NOT MET**, and `PART_BUDGET_CELL` 18,200 now stands ABOVE 328g's only measured frame ceiling
  (<= 16.7 ms with <= 17,000 parts inside 1,024 studs). Both are disclosed and measured rather than
  inferred, which is the same posture under which tasks 346 ("p95 ... is ABOVE the +2 ms budget ...
  a Director call") and 346b ("TWO BUDGET LINES ARE NOT MET") were passed, so it is a note here --
  but it is the line the merge gate should read first. The three AFTER readings (25.34 / 27.75 /
  21.30) straddle the three BEFORE ones, and the Builder says so.
- The PLAN's own target, escaped <= 10 %, is missed at 50.4 % and is reported as missed. MEASUREMENTS
  section 5 calls the remainder "geometric rather than a tuning failure" and then, in the next
  paragraph, gives the arithmetic for closing it (the whole 0-420 band at ~19 studs, ~+700 models a
  cell). Those two sentences disagree: it is a cost decision, not a ceiling. Say it once.

---
REVIEWER verdict on commit `92cf54429de7ee01e6492b1fa5e6c547e5e55c5a` (round 1) · 2026-11-13 19:18 UTC · session cost $2.44, 31 turns · written by tools/agents.py
