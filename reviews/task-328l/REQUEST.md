# Task 328l -- TREES WITH NO LEAVES IN THE GROUND

Task: 328l
Round: 1
Base: `main` 579af893 (+ the Director's decision 84fbfd71)
Code commit: `f26bcf051f4a86dfc8747f67edf4832614e3bba0`

```
[harness] PASS: 34/34 checks @ f26bcf051f4a86dfc8747f67edf4832614e3bba0 (clean tree) scope=all
```

`test2` N/A: nothing in `TWO_PLAYER_PATHS` is touched (the forest, the contact rule, the census and
one tool).

## What changed, and the one thing that made it change

The dispatch's premise -- *"a table wrong in 27 of 35 rows"* -- is **confirmed and its cause is not
a re-scale**. `Workspace.OurForest` is the WOOD, not a folder of 35 models: each species name has
**16 to 125 standing instances** whose own `GetScale()` spans **x1.65 to x1.84**
(`328l-spread.json`). `FindFirstChild(name)` answered an arbitrary one, so the row described a
different tree from session to session and `item.scale`, which is relative to the template, planted
a different size each time. Re-measuring alone would have been wrong again at the next boot, and the
audit arm the dispatch asks for would then have quarantined ~27 of 35 names and emptied the forest.
So the re-measure ships with a deterministic chooser.

## Claims

1. **`tools/forest_ground.py dims` exists and generates the table** (design 9.2). `cmd_dims`,
   `DIMS`, `dims_block`, `write_dims`; it reads `SPECIES`, `FOLIAGE_WORDS`, `TEMPLATE_SOURCES` and
   `INVISIBLE_AT` out of the modules that own them (`species_names`, `plan_strings`,
   `planter_sources`, `planter_number`) rather than restating them. Verify: run
   `python tools/forest_ground.py dims` against the Forest Test in Edit;
   `driven-hunt-runs/328l-dims-BEFORE.txt` and `-AFTER.txt` are the before and after runs.
2. **All 35 rows are the median-scale instance and read `live / row` 1.000** (worst 1.001, the
   4-decimal rounding; the audit's band is 2 %). Before: 27 off, ratios 0.589 to 1.371. Verify:
   `328l-dims-AFTER.txt`'s `med/row` column and its `[dims] ... 1 off their row (worst ratio 1.001)`.
3. **The template is chosen, not found.** `Places.nearestScale` (pure) and `Places.pickTemplate`
   (server, used by `Places.build`'s `template()`). Verify: `grid_ground.spec` section 2c, cases 1
   and 2 -- the first child is asserted NOT to be the answer, and a tie goes to the smaller scale so
   child order cannot decide.
4. **The audit refuses a template off its row, by name.** `Places.rescaledReason` ->
   `Places.auditTemplate`, reason `template-rescaled`. It is the TEMPLATE's arm only: a planted
   clone's scale is the template's times `item.scale` by design, so `Places.auditReason` -- which
   the census runs over clones as `broken` -- must never carry it, and case 2c-3 asserts both. With
   the arm deleted the same model answers `extents`, not this word.
5. **`Places.CROWN_SCALE_SLACK` is retired**, archived with its arithmetic in
   `backups/2026-11-03-crown-scale-slack.md` (rule 7), and `crownOverRoad` is **still 0** live --
   the Director's own proof condition. 328f-notes (a) (the wrong 18.76) and (b) (GAME_DESIGN's
   *"cannot disagree by construction"*) are corrected where they describe this rule.
6. **The seat leaves room for the crown.** `TreeGround.sinkFor(height, foliageDrop)` with
   `FOLIAGE_SINK_STUDS` / `FOLIAGE_MARGIN_STUDS`, passed through `TreeGround.decide` from
   `Places.foliageDrop(made, trunk.minY)` -- this clone's own crown against this clone's own trunk
   box, never a per-species number (L-024). The drop is **signed**: two of the six offending names
   have their crown ABOVE the trunk's foot and were counted because the **sink alone is 0.6 against
   the census's 0.5**. `nil` (no foliage-named part) keeps the old seat exactly, which is what leaves
   the ferns alone. Verify: `tree_ground.spec`'s `sinkFor` and `decide carries the drop` cases --
   the second one fails if the argument is dropped from the call.
7. **LIVE, in Karen's Forest Test, at the code commit, same instrument both ways** (injection, no
   port switch, nothing checked out in `driven-hunt-karen`): C1 `foliageInGround` **158 -> 62**, and
   `floating=0 sunk=0 tilted=0 broken=0 noGround=0 onCliff=0 inRoad=0 crownOverRoad=0` throughout,
   15 posts + 3 towers. Trees **1,364 -> 1,433**: the retired slack shrinks the crown set-back, so
   the plan offers 1,452 -> 1,551 sites. `refused` **6.1 % -> 7.6 %** (118 cliff of 1,551), inside
   the 8 % gate but up, and it is the same cause -- more offered sites in the roadside band, where
   the cross-section steps. Verify: `328l-census-BEFORE-replanted.txt` and `328l-census-AFTER.txt`.
8. **The 62 that remain are three field oak templates and the cause is their mesh.**
   `Field_OakTree_Var04/05/07_LOD_0` (22/23/17), whose canopy box foot sits 1.16-1.27 studs below
   the trunk box's foot at the planted scale -- more than the 0.45 the seat can pay. The other three
   names are **gone**: `LarchTree_Var01` (18), `LarchTree_Var02` (51), `Field_OakTree_Var06_LOD_0`
   (26). Measured against the ground under each offending leaf's OWN footprint (L-024), 29 of the 62
   are really under it, by 0.05 to 0.82 studs mean. NOT quarantined, deliberately: it is 3 of the 4
   field oaks and would leave the field edge one variant. One `Places.QUARANTINE` row reverses that.
9. **Her place is unchanged.** No terrain written, nothing saved, published or committed there; the
   attribute dump before and after is byte-identical, all 15 flags
   (`328l-attrs-BEFORE.txt` / `328l-attrs-AFTER.txt`).
10. **Frames, three pairs, hunter eye height (5.6 st), same cameras both runs**, looked at and
    described in the report: `328l-{BEFORE,AFTER}-{W1,W2,W3}.png`. W1 is the worst tree's patch, W2
    a stand view off the C1 road, W3 the roadside. **W3 shows the look change this task makes**: the
    tree line stands 10-20 studs closer to the road now that the slack is gone, with no crown over
    the carriageway.

## What I could not verify

- **The 1.000 ratios hold only while the wood holds still.** If a model is added to or removed from
  `OurForest` the median can move by one instance; the audit then quarantines that name rather than
  planting the wrong size, which is the fail-safe direction, but no run proves that case.
- **W1's before and after are not the same tree.** The plan changed, so a different model stands on
  that patch; the pair shows the same patch, not the same trunk.
- `foliageInGround` is counted against the ground under the TRUNK's footprint. Whether that is the
  right reference for a 40-stud canopy is the **Architect's** (design 9.4); claim 8 reports both.

ANSWERED: L-136 the only failing spec in any run of this task was `deer_hitbox.spec:659`, the
disclosed intermittent, on the DIRTY diagnostic run; the clean run at the code commit is 34/34 with
nothing failing, so no "known flake" claim is being made against a FAIL line.
ANSWERED: L-127 every claim above is MET / NOT MET / NOT PROVEN per item in the report's handover
block; claim 8 is the NOT MET one and says so in its own words.
ANSWERED: L-162 every live number comes from a run of the code commit's own modules, injected into
her place at `f26bcf05` (the probe prints the sha and the four digests).
ANSWERED: L-014 nothing was checked out, built or run in `driven-hunt-karen`; the branch's modules
reached her place by injection only.
ANSWERED: L-167 every design number used here was re-derived: 0.5, 0.6, 0.2, 2 %, 15 % all read from
the modules that own them in the specs, and the x1.84 spread, the drops and the ratios are this
task's own measurements.
ANSWERED: L-076 three eye-height pairs at 5.6 studs, at the worst tree, a stand view and the
roadside, taken BEFORE any "0" is claimed and described by name in the report.
ANSWERED: L-101 her attributes dumped before and after and diffed: byte-identical, 15 flags.
ANSWERED: L-093 each new case bites when its producer is deleted: 2c-1 (first child), 2c-2
(pickTemplate), 2c-3 (the audit arm answers `extents` without it), `decide carries the drop` (both
lines read -2.6).
ANSWERED: L-024 the drop is measured per clone off that model's own parts, and the remainder in
claim 8 is measured against the ground under each offending leaf's own 5x5 footprint.
ANSWERED: L-143 the whole counter set is quoted for both runs in claim 7, including `refused`
rising 6.1 % -> 7.6 % and `trees` rising, with the cause.
ANSWERED: L-171 the two text fixes were read back out of the commit (`git show HEAD:...`) after the
StyLua pass: the archived note carries **23.2**, and `GAME_DESIGN.md` no longer contains the phrase.
