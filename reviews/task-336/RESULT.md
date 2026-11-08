PASS (items 2, 9 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the eight frames of claim 9 were
opened and described in Karen's own Forest Test, and the species, density, budget and swap numbers
are machine-measured there — but **nobody has played a drive in any of the six new cells**, Karen has
given no verdict on any frame, and claim 2 is NOT MET by the Builder's own measurement (B2 8.04 %,
D2 3.27 % open against the 3 % bound). The wood a hunter stands in and shoots through has been seen
from above and not from a stand.

Checked and clean: the harness line `[harness] PASS: 34/34 checks @ 257db07... (clean tree) scope=all`
names the request's `Code commit:`; `.agent-evidence/paperwork-after-code-commit.txt` says only
`TASKS.md` and `REQUEST.md` followed it; selene 0/0, stylua clean, rojo build exit 0. The `test2` N/A
is correct against the diff — `TWO_PLAYER_PATHS` in `tools/agents.py` holds none of
`src/shared/Places/`, `src/shared/Grid/`, `tests/server/grid.spec.luau`,
`tests/server/grid_ground.spec.luau` (verdict 280's lesson, re-checked path by path). No secret, no
absolute user path, no non-noreply email, no new script outside Rojo-owned paths, no second writer.
Delete-the-producer, by reading: claim 1's case `"gives each planted cell its own species, and C1
nothing but birch"` reads `woods[id] = Plan.plantCell(id)` — the real planner — and asserts
`allowed[group]` per tree, so reverting any recipe reddens it (old B1's `birchStand`/`spruceThicket`/
`birchOpen`/`scrub` draw birch, aspen, conifer, young and fieldOak); claim 6's density case pins
`ownTrees("C1") == 2418` and a ±10 % band whose floor is 2,176, which 328i's shipped own-wood counts
(2,016 / 1,926 / 1,805 / 1,843) all fail. Both are producer-sensitive. Arithmetic cross-check of the
live claims: 2,482 − 529 = 1,953 (B2) and 2,624 − 444 = 2,180 (D2) tie claim 4 to claim 1; 14,342 +
2,476 = 16,818 ties claim 3's two boot lines; GridWood + Workspace = 55,254 at both forced cells.

## Notes (non-blocking)
- `tests/server/grid.spec.luau` / `"is a second storey of young growth..."` — the one assertion the
  diff ADDS to it, `expect(zone.band == "wood" or zone.band == "shrub")`, cannot fail: every zone's
  band is one of the two and the eight-recipes case already asserts exactly that. And the replacement
  `expect(own[row.group])` is not producer-sensitive — `own` is the union of the cell's own zone
  mixes, so pre-336 B1 gives `own = {birch, aspen, conifer, young, fieldOak}` and `larchYoung`'s
  `{young, birch}` sit inside it. The comment's headline fact ("the storey is planted at the `shrub`
  band ... while the canopy takes `woodScale` 0.8-1.2") is asserted only for C1, further down the
  same case (`item.band == "shrub"` ⇒ `scale <= plan.shrubScale[2]`). Fix: run that scale pair over
  `Grid.PLANTED_CELLS` instead of `woods.C1` alone, and drop the band line.
- `src/shared/Places/init.luau` — five recipe headers now describe woods that are gone, and the diff
  left every one of them as context: A2 *"a larch plantation. The SMALLEST trees this world has"*
  (it is aspen), B1 *"white trunks, and one wide clearing off centre"* (spruce, no clearing), B2
  *"FOUR ZONES ... and one clearing band straight across the middle"* (planted at 30), C2 *"dark
  conifer either side of a lighter middle"*, D2 *"an open birch stand with a wide oak park through
  the middle (1191 trees)"*. Same class as 335's queued note (e).
- `src/shared/Places/init.luau` / THE DENSITY RULE block — *"FOUR RECIPES TAKE IT -- `spruceRolling`
  (C2), `larchRolling` (A2), `birchSlope` (B1) ... `aspenSlope` (B2) and `birchRolling` (D2) are
  untouched"*. Four of those five names no longer exist in the file and all five cells are now
  planted. The block is three lines above the `UNDER`/`CANOPY` replacement the diff did edit.
- `src/server/Places/init.luau` / `Places.build`'s preview block — *"dresses `Grid.PLANTED_CELLS` --
  the five whose ground is baked"* and *"the boot's deferred dress of the other four"*. Seven and
  six now, and two of the seven are not baked. Blast-radius file, not touched by the diff.
- `src/shared/Grid/init.luau` / `Grid.PLANTED_CELLS` — the surviving sentence above the new paragraph
  still reads *"That leaves five."*
- `tests/server/grid.spec.luau` / the skirt case — the superseded sentence is still sitting directly
  above its own inversion: *"C2's B2 and D2 are not planted; A1 is in no list at all."* immediately
  precedes `expect(Plan.hasOwnWood("B2")).to.equal(true)`. The local is also still called `c2Skirt`
  while it now counts B1's, and the note it prints says `B1`.
- `src/shared/Places/init.luau` / `Places.CELL_MIXES`, `Places.FERN_MIXES` — `birchStand`,
  `birchOpen`, `oakWood`, `oakPark`, `larchYoung`, `aspenWood` and `scrub` now have no caller in any
  recipe, and four of them are still `true` in `FERN_MIXES`. Consequence worth queueing:
  `Places.standTypeFor`'s `"S"` arm keys on `ahead.mix == "spruceThicket" or ahead.mix == "scrub"`
  and its `"C"` arm on `spacingStuds <= 0`, so both now fire for A1 only — every cell but A1 and C1
  is down to T/R/O, i.e. exactly three distinct letters against `grid_ground.spec`'s
  `assert(weakest >= 3)`. Dormant today (no `src/` caller, 335's note (d) re-verified), but the next
  recipe edit reddens that assert.
- B2's species assignment vs `Places.mask` arm 11 — `group == "young" and not stand.tower` returns
  `R.CONE` over the whole 40-140 stud cone of every ground stand, and B2 is `young` end to end
  (`larchAll` / `larchUnder` → `young`). So a bake cannot close B2's 221 managed-band points:
  TASKS.md's *"(a) B2 and D2 need a BAKE before they can be wall to wall"* and the request's *"the
  cause is the ground, not the planting"* overstate, and the request's own second reason contradicts
  them. B2 was bare before this task, so nothing got worse — but the 221 points are this change's
  own choice, not the landform, and 335's queued note (b) is now a cell-wide fact.
- `REQUEST.md` claim 2 — the bound's denominator moved between 335 and 336: 335 measured *"points
  that are not road, ditch, verge, ride, corridor, stand, tower or cone"*, 336 measures *"points
  where ANY of that cell's own species may stand"*, which additionally exempts D1's `field` and B2's
  managed band. Both sets are quoted (0.59/0.79/0.26/0.84/0.21 against 2.45/1.31/25.29/1.07/0.93),
  so it is disclosed — but the two 3 % figures are not the same 3 %, and the sentence should say so.
- `REQUEST.md` claim 3 — the GridWood totals reconcile exactly both times (55,254 parts), but the
  `Workspace parts 31,806 → 31,614 → 29,695` row does not: C1 out / B1 in is −321 and the row shows
  −192; B1 out / D2 in is −1,931 and the row shows −1,919. Live-server drift is the likely cause;
  say what else was in the count.
- `REQUEST.md` claim 10 — *"the understorey's species ... re-aimed at **A1**"*. It was not: that case
  still loops over all eight cells; what changed is the assertion. Claim 1's *"A1's front mix"* is
  also the wrong function — the skirt's `pick` returns `cellMixNamed(zoneAt(near.id, x, z).mix)`,
  i.e. whichever A1 zone the site lands in, not `Places.frontMixOf`.
- `src/shared/Places/init.luau` — the six new frontage comments each carry one ~155-character line
  inside an otherwise 100-column wrapped block (e.g. *"60-stud band stays; what it allows is conifer,
  because a cell whose roadside drew birch and larch would not be the spruce cell Karen asked
  for. The CROWN"*). stylua does not reflow comments, so this needs a hand wrap.
- `src/shared/Places/init.luau` — `CELL_PART_CAP` headroom is 3 models at the top of claim 5's range
  (2,637 of 2,640), and `PARTS_PER_MODEL` 3.03 is still C1's pre-335 mix, so B1's live 8,997 parts
  make it the **second** cell certified as inside a `PART_BUDGET_CELL` of 8,000 that it is past
  (C1 is 9,318). 335's note (c) and task 337c already own the re-derivation; this change doubles the
  cells it applies to.
- `src/shared/Places/init.luau` — `spruceUnder` is drawn as B1's own canopy in two zones (bands
  `wood` and `shrub`) and `spruceBirchUnder` as C2's in two more. The `*Under` / `*All` pair is only
  a `FERN_MIXES` flag, as the header says, but a mix named for a storey standing as a wood will read
  as a mistake to the next editor; name the pair for the fern floor instead.
- `src/shared/Places/init.luau` — `UNDER` and `CANOPY` were deleted with no `backups/` entry. The
  values survive verbatim in the six new constants and in the surviving DENSITY RULE text, so rule 7
  looks satisfied in place; flagging it so the Director can confirm that is the call it wants.
- `tests/server/grid_ground.spec.luau` / `"a clearing refuses, and the zone beside it does not"` —
  pre-existing, and now re-aimed without being fixed: `solid` is computed and never asserted, so the
  second half of the case's own name is not tested.
- `TASKS.md` — the 336 row says the backup click *"IS one a Builder can make"*; the 337b row two rows
  above still blocks on *"a fresh `File > Download a Copy` backup, which is **a click only Karen can
  make**"*. One of the two is wrong and 337b may be unblocked.

---
REVIEWER verdict on commit `7658901d5d6134481ac44dd17bf4e40b226bb703` (round 1) · 2026-11-08 23:07 UTC · session cost $4.72, 42 turns · written by tools/agents.py
