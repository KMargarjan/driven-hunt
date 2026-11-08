PASS (item 1 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the deliverable here is a PICTURE
— what C1 looks like from a stand — and **Karen has not looked at it**. What WAS seen in her place:
the plant itself, the live cover probe on `Workspace.GridForest.C1` (`species birch=2387`, open ALL
480/3888, non-exempt 80/3220) and two described captures in EDIT at explicit coordinates (F1
top-down at the dispatch's camera, F2 from C1 stand 8's eye 120 studs east). What was NOT seen: her
verdict on either frame, and **nothing was seen with a BOAR in the 40-140-stud band** — `maskGrid`
arms 9-11 read `if group == "young" and not stand.tower then return R.CONE`, and C1's understorey is
no longer `young`, so saplings now stand in the shot band of every non-tower C1 stand where none
could before. Whether a hunter can still pick a body out of that wood is unproven by anything in
this task. That is the shooting-adjacent half and it is why line 1 is not a bare PASS.

What I verified rather than took on trust: the keep/fell path (`Places.dressCell`'s
`if folder.Name == cellId or keep == nil or keep[folder.Name] ~= true`, `dressCells`' `keep` build,
`PLANT_SEAM` and `command_plant`'s `keep = ",".join(...cells)`); claim 5's arithmetic against
`Grid.CELLS` C1 (`minY` 89.14 + .30 × 61.12 = 107.476 > `lineMeanY` 106.03) and `scatter`'s bias
block; claim 1's producer-sensitivity (the mixes are `mix({"birch", 1})`, `frontage.groups` contains
`birch` so `frontageGroupFor` keeps it, and `frontageRows` — which WOULD inject `young`/`aspen`/
`fieldOak` into a one-row mix — has no caller in `src/`); claim 2's lattice (54 × 72 = 3,888 grid
points, `boundsOf` is grid space, `maskGrid` takes grid space, `Grid.toWorld` applied once, 50-stud
buckets with a 3×3 neighbourhood which is sufficient for a 25-stud reach, and `REASON`'s strings
match `EXEMPT`'s keys exactly while `clearing` is absent from it); claim 4's breakdown
(73+7+11+233+107+49 = 480 = open ALL; 400 = 10.3 % of 3,888; 73+7 = 80 of 3,220 = 2.48 %); claim 6's
stub (`Places` is not frozen, `plantCell` and `zoneAt` both call `Places.cellPlanFor` through the
module table so the stub is honoured, everything that can throw is inside the `pcall`, and
`forgetCells` clears `ZONE_RECTS`/`CELL_FACTS` on both sides); claim 9 (only `Grid.CELLS` row C1
names `mixedRolling`, no other cell's zones name the three new mixes or `birchWood` in `FERN_MIXES`,
and `plantCell`'s skirt loop `continue`s on `Places.isPlanted(near.id)` so nothing reads C1's
recipe); claim 10 (`local standard = 1861` is now a literal and `expect(ownTrees(Grid.PREVIEW_CELL))
.to.equal(2418)` reddens on a revert — the old `standard = ownTrees(PREVIEW_CELL)` was C1 compared
with itself). Delete-the-producer, by reading: revert `mixedRolling`'s v5 `zones` and claim 1's case
fails on its `wrong` list, claim 2's case fails because the spacing-0 clearing makes `maskGrid` arm 8
answer `clearing` over ~15 % of a cell whose bound is 3 %, claim 8's `expect(clear > 0).to.equal(id
~= "C1")` fails, and claim 10's 2,418 fails. Lint, format and build are green; the harness line names
`687dc1e8` "(clean tree)" and `paperwork-after-code-commit.txt` reads OK.

## Notes (non-blocking)
- **THE ONE-CELL `GridForest`, AND THE PART OF THE DISCLOSURE THAT IS WRONG** — the mechanism is
  exactly as disclosed and I confirmed it in code, so the fell is real and this task did it. I judge
  it NOT blocking: `dressCell`'s one-cell contract is pre-existing and documented by its own `keep`
  parameter ("nil is the one-cell contract this function was born with: every other cell goes"), the
  tool refuses to run without a fresh `--backup` .rbxl outside the repo (`check_backup`, refusal 5),
  no `src/` line is wrong, holding the merge would not restore one tree, and Karen's *"we only load
  one per game"* plus task 336 are the Director's decision about the re-plant. **But the sentence
  offered as the reason it is harmless is false, and the merge decision should not rest on it:**
  *"a boot dress plants the cell being played"*. `command_plant` stamps the folder with the LIVE
  terrain epoch as its last act, so `ForestTest.prebuildVerdict(live, planted)` now returns
  `STANDS, dress = false`, and `ForestTestBoot` hands `Places.build` `if prebuild.dress then nil
  else {}` — an EMPTY cell list. **No boot in her Forest Test will re-plant anything, ever, while
  that stamp matches.** Worse, and this is the part she can SEE from where she actually plays:
  `Places.isPlanted` reads the static `Grid.PLANTED_CELLS`, not the live folder, so C1 still draws
  NO skirt into B1, D1 and C2 — 328i withdrew it precisely because those neighbours had their own
  wood, and they no longer do. Looking across the road out of C1 she will see bare ground where
  328i's reasoning put wood. The recovery is one Edit-mode command naming every planted cell so the
  keep set is all of them (`plant --cells C1,B1,D1,A2,B2,C2,D2 --backup <fresh>.rbxl`), and it is
  the Director's to run or to defer to 336 — but defer it knowingly, not in the belief that a boot
  fixes it. Also worth one line in the tool: `report.destroyed` exists and `command_plant`'s row
  printer is the one caller that does not print it, which is the whole reason this went two rounds
  unseen.
- `src/shared/Places/init.luau` / `mixedRolling`'s v5 header — *"Three things change and nothing else
  does"* still counts three while the rows make four changes: the oak park zone `(0.60, 0.35, 1.00,
  0.70)` gained `under = BIRCH_UNDER`, which it did not carry. The request's "What changed" now says
  so; the source comment, which is what the next reader opens, does not. It is a sight line at a
  stand — the v3 paragraph above it reads *"`oakPark` -- SPACING AND STOREY BOTH UNCHANGED. It is the
  park a hunter can see across"* — so say the storey where the spacing is said, for Karen.
- `src/shared/Places/init.luau` / three comment blocks still read as current and are false of v5
  (round 2's note, queued not fixed): `mixedRolling`'s own first header, *"SEVEN ZONES AND FOUR
  DIFFERENT WOODS ... an oak park to the east ... and a clearing two thirds in"*, which sits ABOVE
  the *"EVERYTHING FROM HERE TO THE v5 BLOCK IS HISTORY"* marker and so is not covered by it; the
  density block above `UNDER`, *"C1 is the standard: **1,861 trees inside its own rectangle**"* and
  *"`under` (**30**-stud `larchYoung`) on every CANOPY zone, meaning a wood zone that is not
  `oakPark`, `clearing` or `scrub`"* — false of C1 in every clause now; and `src/shared/Grid/
  init.luau`'s C1 row, *"seven zones, four woods -- the preview cell"*.
- `reviews/task-335/REQUEST.md` claim 9 — *"`grid.spec`'s density case still reading C2/A2/B1/D1 at
  1,926/2,016/1,805/1,843"* cites the wrong file. Those four numbers are not in `grid.spec`, which
  pins only the ±10 % band and prints the counts in a `TestKit.note`; they are in
  `src/shared/Places/init.luau`'s own density block (*"Shipped own-wood: 1,926 / 2,016 / 1,805 /
  1,843 against C1's 1,861 -- 103 / 108 / 97 / 99 %"*). The substance of claim 9 holds on the three
  facts I checked above; only the pointer is wrong.
- `tests/server/grid_ground.spec.luau`, "a clearing refuses, **and the zone beside it does not**" —
  the change moved this case from C1 to B1, and the second half its name promises is still not
  asserted: `local empty, solid = nil, nil`, `solid` is filled from the first non-clearing zone and
  then never read. One `expect(Plan.maskGrid(id, centre of solid...)) ~= Plan.REASON.CLEARING` would
  make the name true. Pre-existing, but this is the case the change touched.
- `tests/server/grid.spec.luau`, the bent-count case — the `t1861` -> `t2418` fix left the sentence
  it contradicts standing two lines above: *"C1's OWN rectangle has not moved a tree -- ... and this
  plan is `t2418 f104 s0` (task 335)"*. It moved 557. And the new line, *"2,522 bent since task 335
  (328i's 1,965 plus the clearing, the park and a birch-only understorey)"*, adds to a number that
  still had a 464-site skirt in it.
- `tests/server/grid.spec.luau`, the understorey case — *"IT IS YOUNG GROWTH AND NOT A SECOND
  CANOPY"* with `expect(row.group == "young" or row.group == "birch")`. For C1 the second storey is
  now the SAME group as the canopy, so the only thing separating the two storeys there is
  `scaleFor`'s `shrub` band (0.35-0.45 against the wood band's 0.8-1.2). Assert the scale band, not
  the group. The case does still bite on the `under` loop: `expect(saplings > 381)` counts
  `band == "shrub"` and the two scrub zones alone hold 381.
- `src/shared/Places/init.luau` / `scatter`'s `reliefBias` block — after this change NO shipped
  recipe declares the key (`grid_ground.spec` asserts exactly that), so the bias ships with no caller
  and is exercised only by a synthetic plan. `grid.spec`'s dressCell pair
  (`expect(#Plan.plantCell(id, hillside)).to.equal(#woods[id])`) is therefore a tripwire and not a
  proof; claim 7 says so, which is the right handling, and it must not be re-offered as one. Queue a
  decision: keep the block for the next cell that wants it, or retire it under rule 7.
- `src/shared/Places/init.luau` / `PARTS_PER_MODEL`, `PART_BUDGET_CELL` — disclosed and unchanged
  since round 1: 9,318 live parts for 2,476 models is 3.76 a model against the frozen 3.03, so
  `grid.spec`'s `#woods[id] <= Plan.CELL_PART_CAP` (2,640 = 8,000/3.03) certifies a cell 1,318 parts
  past `PART_BUDGET_CELL`. Not blocking, and the design says why itself: `grid-roads.md` §8.2,
  *"the per-cell part ceiling is UNMEASURED ... no spec and no request may cite 8,000 as a
  measurement until that run happens"*, and its own open question 6, *"`PARTS_PER_MODEL` 3.03 is
  C1's mix only ... the bound must be re-read, not trusted"*. This is that caveat coming true. The
  one measurement taken favours the change (C1 stand 8 21.10 / 27.78 ms against untouched C2 stand
  8's 24.05 / 31.60). Re-derive the ratio per mix, or run 328g's client frame.
- `src/shared/Places/init.luau` / `Places.standTypeFor`, `Places.frontMixOf` — re-verified dormant
  this round, so correctly queued rather than fixed: the mix-name arm
  (`ahead.mix == "spruceThicket" or ahead.mix == "scrub"`) and the `spacingStuds <= 0` arm can no
  longer fire for C1, so C1's "S" and "C" stand letters are gone; `standTypeFor`'s only callers
  anywhere are in `grid_ground.spec` (whose C1 assertions read the tower and ride arms, which run
  first), and `frontMixOf`'s only caller is `borderPlan`, which has no caller at all.
- `src/shared/Places/init.luau` / the v5 header — *"They were 510 and 197 of the 1,121 lattice points
  with no trunk within 25 studs"* against claim 3's own BEFORE line `open 1188/3888`. One of the two
  is off; round 2's note, still queued.
- `reviews/task-335/RESULT.md` — the round-2 verdict was edited by the Builder to replace the literal
  that finding 1 quoted, which is disclosed in the file, in `ESCALATE.md` and in `TASKS.md`, and the
  finding's substance is intact. The escalation's own ask is the right fix and I would back it:
  `tools/agents.py` should run `privacy_scan` over the verdict before it writes it, so the Reviewer's
  output is never the thing that reddens CI and the subject of a verdict never has cause to edit it.

---
REVIEWER verdict on commit `c01f3fe02d119f0314bb17cf9461cd1043ab239b` (round 3) · 2026-11-08 19:56 UTC · session cost $4.53, 54 turns · written by tools/agents.py
