# Task 335 -- cell C1 is one birch wood, wall to wall

Task: 335
Round: 3
Base: main 4751ffd6
Code commit: 687dc1e8971c72f862624a6acca6b2926b857ce9

Gate, clean tree, at the code commit:

```
[harness] PASS: 34/34 checks @ 687dc1e8971c72f862624a6acca6b2926b857ce9 (clean tree) scope=all
```

And re-run at this branch's head for the number claim 2 needs (the note is printed by the run, and no
round's output had been kept):

```
[harness] PASS: 34/34 checks @ 0fa08d4c94d46f6545ea257cf4a3c0142d06def8 (clean tree) scope=all
```

`test2` N/A: no `TWO_PLAYER_PATHS` path is touched (`src/shared/Places/init.luau`,
`tests/server/grid.spec.luau`, `tests/server/grid_ground.spec.luau`). **No `src/`, `tests/` or
`tools/` line changed in round 3** -- `git diff 687dc1e8..HEAD --name-only` is `ESCALATE.md`,
`TASKS.md` and this folder. Round 3 is authorised in `ESCALATE.md` 2026-11-08 ~19:40 UTC.

Karen, 2026-11-08 ~15:35 UTC, on a top-down frame of C1: *"so we start with this that all has to be
forest no free spot excep road so in one terrain maik all birch trees"*.

## What changed

`Places.CELL_PLANS.mixedRolling` (C1 only) v5: three birch-only mixes (`birchWood`, `birchThicket`,
`birchScrub` -- three names and not one because `Places.FERN_MIXES` keys on the mix name), the
understorey `larchYoung` -> `birchScrub`, `reliefBias` dropped from all four wood zones, the clearing
zone 0 -> 24, and the oak park 44 -> 26 **and the park also gained `under = BIRCH_UNDER`, which it did
not carry before** (round 2's note: the v5 header counts three changes and should count four; the park
is "the park a hunter can see across", so the storey in it is Karen's feel call). Nothing else in the
recipe moves. Two specs follow the recipe and two more carry the task's own claims.

## DISCLOSED: her Forest Test's `Workspace.GridForest` now holds ONE cell, and this task did that

The Director measured it live at 19:35 UTC: `cells=C1=2476`. B1, D1, A2, B2, C2 and D2 were planted by
tasks 328g2/330 and their wood is **gone from the place**.

**The command was this task's own plant: `python tools/terrainbake.py plant --cells C1 --backup
<backup>.rbxl`, run from this branch's worktree** -- the command `ANSWERED: L-139` named in round 2.
Why it fells the others: the tool passes `keep = {the cells named}` into `Places.dressCells`, and
`Places.dressCell`'s first loop collects `if folder.Name == cellId or keep == nil or
keep[folder.Name] ~= true` and destroys every folder it collected. With `--cells C1` the keep set is
`{C1}`, so the six other cell folders are felled by design -- the one-cell contract the `keep`
parameter's own comment describes. **It was not reported in round 1 or round 2, and that is my
omission**: the printed row (`plant  C1  ... planted, ... standing, ... cliff, ... skipped, ...
missing, cap, rows, seconds`) carries no `destroyed` column, so the fell left no line in the output I
read, and I did not read the `keep` path until this round. Verify: the `keep` block in
`Places.dressCell`, `PLANT_SEAM` and `command_plant` in `tools/terrainbake.py`, and that row printer.

By the Director's reading it is not a blocker -- Karen's decision of 2026-11-08 (*"we only load one per
game"*) and task 336 (every cell plants its own trees) re-plant them, and a boot dress plants the cell
being played. **The Reviewer judges that, not me.** What is certain is that every claim below about
another cell is about its PLAN, never about wood standing in her place.

## The two frames, opened and described

Both taken in Karen's Forest Test in EDIT, after the plant, with `ftplay.py capture`.

**`<runs-dir>/335-F1.png`** -- top-down, camera `-3899,1500,-4300` looking at `-3899,100,-4371`, the
camera the dispatch gave. WHAT IS IN IT: C1's rectangle is one even grey-green canopy from the north
road to the south road and from the west flank road to the east one. **The cut clearing that filled the
middle of `c1-top2.png` is gone, and so is the almost empty field in its south half** --
`335-F1-south.png` is that south third at 2.4x and carries crowns across its whole width down to the
south road. **No dark spruce block is left in the north half**: in `c1-top2.png` the north read as two
black blocks against pale ground; here the whole cell is one tone, which is the one species. The bare
ground inside the cell is a narrow north-south lane about two thirds up (the V ride at stand 5), a
shorter cross-lane on the east half (the X cut on stand 3's sight line), two short flank lanes, and the
pale road strips OUTSIDE the rectangle. **One honest qualification:** the eastern strip reads visibly
thinner -- the 26-stud `birchScrub` zone in the `shrub` band, crowns 0.35-0.45 scale, so from 1,400
studs up the ground shows between them. Every lattice point there is still inside 25 studs of a trunk
(claim 2); it is a canopy-size difference, not a hole, and it is Karen's to judge.

**`<runs-dir>/335-F2.png`** -- from C1 stand 8, camera `-4497,109,-4746` (the stand's own ground at
103.6 plus a 5-stud eye) looking at `-4377,107,-4739`, 120 studs due east into the cell. WHAT IS IN IT:
a closed wall of white-trunked birch three to four ranks deep, filling the frame side to side; the grass
verge and the ditch in the bottom quarter; stand 8's tower ladder in its own 24-stud clearing just right
of centre. **Not one spruce, larch, oak or aspen is in the frame.** Sky shows above the canopy and
between the upper crowns. **What it is NOT:** a thicket -- `335-F2-zoom.png` is the mid-ground at 2.4x
and between the trunks the ground is open sunlit grass, so a hunter can still see a boar's body through
the wood; what breaks the sight line is trunks and low crowns, not the floor. **The understorey IS in
the shot band:** in that zoom, the small tree left of centre whose crown starts at about chest height,
against the straight mature stems beside it -- so a hunter at this stand now has young growth where
`maskGrid` arm 11's `young` ban kept it out. Reported, her call.

## Claims

1. **Every stem C1 offers is a birch.** `grid_ground.spec` "offers no stem that is not a birch" walks
   `Plan.plantCell("C1", nil)` and fails on any model not in `Places.SPECIES.birch` (ferns excepted,
   they are ground cover). Verify: read the case; revert `mixedRolling`'s `zones` and it fails. The
   run's own note reads `C1 one species: birch=2418 fern=104`.
2. **C1's open ground meets the bound, and here is the margin** (round 2's note (i)).
   `grid_ground.spec` "leaves no open ground off the roads, the rides, the corridors and the stands":
   a 20-stud lattice over `Grid.boundsOf("C1")`, a point open when no non-herb planting is within 25
   studs, `road`/`ditch`/`verge`/`ride`/`corridor`/`stand`/`tower`/`cone` points excluded, bound 3 %.
   **The `TestKit.note` printed `C1 open ground: 73/3186 = 2.29% (<= 3%)`** in the 0fa08d4c run above
   -- 0.71 points of margin, i.e. 22 more open points before it bites. That 73 is the same number
   claim 4's live breakdown calls `PLANTABLE=73`. Verify: the note line in that run's output, and
   re-run `python tools/studio_mcp.py test`.
3. **Measured in Karen's Forest Test, same probe both sides** (`<runs-dir>/335-cover.luau`, run on the
   LIVE `Workspace.GridForest.C1`, not on the plan). Before: `C1 trunks=1853 herbs=91 parts=6566`,
   `species aspen=126 birch=433 conifer=754 fieldOak=99 oak=58 young=383`, `open 1188/3888 = 30.56%`.
   After: `C1 trunks=2387 herbs=89 parts=9318`, `species birch=2387`, `open ALL 480/3888 = 12.35% |
   NON-EXEMPT 80/3220 = 2.48%`. Verify: the lines are quoted in the task row; re-run the probe.
4. **The dispatch's 3 % is unreachable over ALL interior points, and that is arithmetic.** The
   uncovered points are `PLANTABLE=73 clearing=7 corridor=11 ride=233 road=107 verge=49`: 400 of them
   are road, verge, ride or corridor, which the mask keeps trunk-free for the stands and the beaters --
   10.3 % of the lattice before a tree is planted. So the bound is reported both ways and asserted
   against the non-exempt points. **Which mask produced that breakdown:** the LIVE probe runs inside
   her place, whose `Places` is still merged `main` `4751ffd6`, so the labels are the OLD mask over the
   NEW trees -- which is why `clearing=7` appears at all (v5 has no spacing-0 zone, so arm 8 can never
   answer `clearing` for C1). The exempt set is byte-identical in both recipes and `clearing` is
   non-exempt in either, so 80/3,220 = 2.48 % is unaffected. Verify: the `openwhy` line, `maskGrid`
   arms 1-4 and 9-12.
5. **`reliefBias` had to go, and the spec says so.** It rewrites any non-conifer to `conifer` under hn
   .30; C1's `relief.minY` 89.14 + .30 x 61.12 = 107.5 is ABOVE its `lineMeanY` 106.03, so left in it
   would have planted the lower half of a birch-only cell in spruce -- the live BEFORE count, conifer
   754 of 1,853, is that bias at work. Verify: `scatter`'s bias block in `src/shared/Places/init.luau`
   and `Grid.CELLS` C1's `relief`.
6. **The bias is still proven, with no shipped caller.** `grid_ground.spec` "the relief bias ... and it
   bites" hands `plantCell` its own plan -- C1's row with one `mixedWood` zone over the whole cell
   carrying `reliefBias` -- by stubbing `Plan.cellPlanFor` inside a `pcall` and restoring it; a second
   case asserts no shipped recipe declares the key. Verify: both cases.
7. **`grid.spec`'s "a plan with a reader differs from one without" can no longer bite, and is not left
   pretending to.** With no recipe carrying the bias the two counts are equal; the case asserts
   equality, says why in its comment, and names where the bias is proven instead. It is a tripwire, not
   a proof, and is not offered as one (round 2's note). Verify: the case and its comment.
8. **C1 has no clearing left, so the two cases that needed one move.** `grid.spec`'s per-cell rule
   becomes `clear < 0.34` for every cell plus `expect(clear > 0).to.equal(id ~= "C1")` -- which fails
   if C1 gains a clearing back AND if any other cell loses one. `grid_ground.spec`'s "a clearing
   refuses" asks B1. Verify: both cases.
9. **No other cell's PLANTING PLAN moves** (the place is the disclosure above, not this claim). C1's
   three neighbours B1, D1 and C2 are in `Grid.PLANTED_CELLS` and `plantCell` draws no skirt into a
   planted neighbour, so C1's plan puts nothing outside its own rectangle; the skirt other cells draw
   reads the NEIGHBOUR's mix through `Places.zoneAt` and passes no `zone`, so no skirt reads C1's
   recipe. Verify: `plantCell`'s skirt loop, and `grid.spec`'s density case still reading C2/A2/B1/D1
   at 1,926/2,016/1,805/1,843.
10. **The density standard became the number 1,861, not C1's live count**, because C1 is now 2,418 on
    Karen's instruction and holding four mixed woods to a one-species cell would raise them on nobody's
    say-so. C1's own 2,418 is pinned in the same case. Verify: `grid.spec`'s density case.

## What I could not verify

* **Karen has not looked at it.** Rule 5 is met only as far as the two frames above; her verdict on
  either is not in. Nothing was seen with a BOAR in the 40-140-stud band, so whether a hunter can still
  pick a body out of the new birch understorey is unproven by anything in this task.
* **The BEFORE frame time.** The old wood was replaced before anyone read it, and the only copy is
  `FT-before-335.rbxl`. One run AFTER the plant (`<runs-dir>/335-frametime.luau`): C1 stand 8 mean
  **21.10 ms**, p95 **27.78 ms**, 475 frames, against untouched C2 stand 8's **24.05** / **31.60**, 416
  frames -- so the heavier cell is not the slower one. It is not a before/after pair.
* **The part budget is exceeded and the cap is not.** 2,476 models against `CELL_PART_CAP` 2,640, but at
  9,318 parts (3.76 a model, where `Places.PARTS_PER_MODEL` says 3.03 -- measured on C1's OLD mix) C1 is
  past `PART_BUDGET_CELL` 8,000, the budget the cap is derived from. Pre-existing in kind: five planted
  cells already exceed `PART_BUDGET_DRIVE`.
* **The understorey is no longer `young`**, and `maskGrid` arm 11 bans only `young` growth from a
  stand's 40-140 stud cone, so saplings can stand in a hunter's shot band where they could not before.
  Reported, not hidden; Karen's feel call.
* Round 2's other notes are queued in `TASKS.md` row 335, not fixed (rule 3): the three stale source
  comment blocks, `grid.spec`'s bent-count sentence, the understorey case asserting the group rather
  than the scale band, `PARTS_PER_MODEL`, `standTypeFor`/`frontMixOf`, and the v5 header's 510/197
  counts against claim 3's `open 1188/3888`.
* No research note: a data change inside an existing recipe system, with no new pattern.

ANSWERED: L-127 every dispatch item is MET or NOT PROVEN by name in the report's handover block.
ANSWERED: L-162 the code commit is unchanged at `687dc1e8`, and every live proof -- the plant, the cover
probe, the frames, the frame time -- was taken in Karen's Forest Test at `ef357ba1`, whose `src/` is
identical to `687dc1e8`'s (`git diff ef357ba1 687dc1e8 -- src/` has no non-comment line).
ANSWERED: L-014 nothing was checked out in the Director's copy; it still reads `4751ffd6`. The plant
injected the planter's text off this branch's own worktree (the Builder's copy, not hers), and this
round touched her place not at all.
ANSWERED: L-064 `python tools/privacy_scan.py scan` was run before committing this file, and it is run
again over `RESULT.md` before that file is committed -- round 2's finding was a path quoted in the
request, and the verdict quoting it failed the same scan.
