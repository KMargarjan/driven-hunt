# Task 337 -- review request

Task: 337
Round: 2
Base: `c0fa710b` (main)
Code commit: `e052992bb274c8e75f5c88fd9e8c46b8a1b95e07`

```
[harness] PASS: 34/34 checks @ e052992bb274c8e75f5c88fd9e8c46b8a1b95e07 (clean tree) scope=all
```

`test2`: **N/A.** No file here is in `TWO_PLAYER_PATHS` (`tools/agents.py`): the swap is called from
`ForestTestBoot`'s own `markers` closure, not from `src/server/Match/`.

**What changed.** Karen, 2026-11-08: *"we only load one per game thats it"*. Rule 1 and loop step 2
first: note `docs/research/2026-11-08-one-cell-at-a-time.md` + INDEX, BRIEF `reviews/task-337/BRIEF.md`,
then `tools/architect.sh design cell-loading --task 337` -> `docs/design/cell-loading.md`,
`ARCH_RESULT.md` line 1 = `PASS`. **The design split the dispatch in three (its section 14, rule 4);
this PR is part A.** Part B, the world trim, is blocked twice and is written up in `ESCALATE.md`
(a `NEEDS KAREN` backup click, and the rotation still dealing the four line places whose ground is in
the removal set). Part C is `TASKS.md` 337c.

---

## Claims

1. **`Places.Cells` is the only thing that MOVES a cell folder between its home and the store, and
   it creates and destroys nothing.** (Round 1 note: "the one writer of a cell folder's `Parent`"
   overstated it -- `dressCell`'s `ensureFolder` parents the folder it creates. Same owner, different
   verb. Corrected here, in `GAME_DESIGN.md`'s two rows and in `Cells.luau`'s header.) New `src/server/Places/Cells.luau`. Verify: `grep -n "Destroy\|Instance.new" ` over it
   -- the only `Instance.new` is `ensure`, which makes a `Folder` when a home or the store is
   missing, and there is no `Destroy` at all. `Cells` requires `Places`; `Places/init.luau` does not
   require `Cells` (design 2, so `tools/terrainbake.py`'s require rewrites are untouched).

2. **`Places.dressCell` fells no cell but the one it is dressing** -- task 335's live defect. The
   `keep` parameter is gone, `dressCells`/`dressPending` lose `keepIds`, and `PLANT_SEAM` loses its
   keep line. Verify: `grep -n "keep" src/server/Places/init.luau` finds only prose; the loop over
   `Places.cellWoodFolders` now reads `if folder.Name == cellId then`. **Dies if restored:**
   `grid.spec` *"stands every cell of the list up, and fells no cell it was not asked to dress"*
   asserts the untouched D2 folder is the **same Instance**, holds 1 model, and that
   `staleTree.Parent == stale`.

3. **The reconcile is level-triggered and moves rather than destroys.** `grid.spec` *"stands one
   cell, stores the rest, and writes nothing when nothing changed"*: the stored cell keeps its 5
   models, its first model `:IsDescendantOf(store)`, the swap moves both ways with both counts
   intact, and a repeat `want` gives `moved == 0` with `Cells.line(report) == nil`.

4. **The two names answer differently where the facts differ (L-093).** `Places.isPlanted` ->
   `Places.hasOwnWood` (static, pure, reads `Grid.PLANTED_CELLS`); the live fact is
   `Cells.isStanding`, which reads the world. `grid.spec` *"tells a wood that EXISTS from a wood
   that is STANDING"* asserts `hasOwnWood("C2") == true` **and** `isStanding("C2", world) == false`.
   **Dies if** `isStanding` is re-implemented off the table: the pair reads `true, true`.

5. **It refuses at Edit time, and that is not caution.** `default.project.json` maps all of
   `ServerStorage` to `src/serverstorage` with Rojo's default `$ignoreUnknownInstances: false`, so a
   store made in Edit would be deleted at the next Connect with 9,318 parts of Karen's wood. Both
   arms are reachable by parameter (`isEdit`). `grid.spec` *"refuses at Edit time and creates no
   store"* asserts `reason == "edit-time"`, `moved == 0` and that the store folder was **not**
   created, **and -- round 1, finding 1 -- the same case now takes the DEFAULT**, which is the only
   arm the game ever runs: both live call sites pass three arguments, so `isEdit` is nil and
   `Cells.editTime()` decides. `Cells.reconcile("C1", world, store, nil, nil)` must reconcile
   (`reason == nil`, `moved == 1`, `stood == "C1"`, one standing, one stored).
   **FAIL FIRST, RUN and not argued:** with that one line inverted to `if isEdit == nil then true`,
   `python tools/studio_mcp.py test` read
   `FAIL: 32/34 checks @ e052992b (DIRTY TREE (1 paths) - NOT valid evidence)` and
   `failed [server] grid.spec:3216 Expected value "nil" (nil), got "edit-time" (string) instead`
   -- 2,860 passed, 1 failed. The file was then restored with `git checkout --` and the tree is
   clean at the code commit. Before this case existed the same inversion left every case green. **Measured in her place:** after the live run below and a Play stop, her Edit place reads
   **48,726 instances / 21,148 parts**, `GridForest` 20,518/9,318, `ServerStorage` 105 descendants
   and **no `GridWood`** -- byte-for-byte what it read before the session.

6. **LIVE, in Karen's Forest Test, on 2,476 real models / 9,318 real parts**
   (`<runs-dir>/337-live.luau`: `Cells.luau`'s own text at this code commit, injected the way
   `tools/terrainbake.py` injects the planter -- a second DRIVER of the one writer, never a second
   writer; nothing persists, a Play session's `ServerStorage` goes with the session):

   ```
   BEFORE C1 rowHash=1d9a3d58 models=2476 parts=9318
   1 NO-OP  : want=C1 stood=C1 models=2476 moved=0 stored=0 ms=0.54 line=nil
   2 STORE  : want=C2 reason=missing moved=1 ms=240.47 | [Places.Cells] want=C2: MISSING -- no wood
              standing and none stored (plant it: tools/terrainbake.py plant --cells C2)
   2 WORLD  : GridForest holds 0 cell folder(s), GridPlaces holds 0; store holds 1
   2 LIVE   : Cells.isStanding(C1)=false
   2 STORED C1 rowHash=1d9a3d58 models=2476 parts=9318 home=GridForest
   3 STAND  : want=C1 stood=C1 models=2476 moved=1 ms=138.52
   T9 ROUND TRIP: rowHash 1d9a3d58 -> 1d9a3d58 -> 1d9a3d58  IDENTICAL=true ; parts 9318 -> 9318
   T7 SWAP  : store half 240.47 ms, stand half 138.52 ms, both halves 378.99 ms
   ```

   **T1** (a non-active cell contributes 0 parts: both homes empty at the extreme), **T2/T9**
   (model count and row hash identical across the round trip -- moved, not destroyed; `rowsOf` is
   `tools/terrainbake.py`'s own `FOREST_ROWS_SEAM` expression, lifted verbatim, so both sides are the
   same instrument), **T7** (379 ms against the design's 500 ms ceiling), **T8** (no-op 0.54 ms,
   0 writes, no line).

7. **The boot's deferred dress and `report.gridPending` are retired, archived, not deleted**
   (rule 7): `backups/2026-11-08_task-337_dressCell-keep-set.md` carries all six removed pieces
   verbatim. It was already inert in her place (`prebuild.dress == false` gives `build` an empty cell
   list). `grid.spec` *"plants exactly one cell on the boot path, and no more"* asserts
   `report.gridPending == nil` and that C2/B1 were never dressed.

8. **A forced CELL now beats `GRID_PREVIEW`** (design 9.4), or the swap could never be driven in the
   only place it can be measured: `ForestTestBoot`'s `markers` closure reads
   `ForestTest.forcedLayout(...)` and takes it when `Grid.cellOf(forced) ~= nil`. A forced LINE PLACE
   is still ignored under the preview, for the reason already written there.

9. **Rule G.** `python tools/studio_mcp.py selftest` PASS, `python tools/agents.py selftest` all ok,
   `python tools/terrainbake.py selftest` PASS (its plant-seam case now asserts the seam carries **no**
   keep and has exactly one `%s`), `python tools/privacy_scan.py scan` PASS 0 findings in 1,386 files.
   `selene src`, `selene --config tests/selene.toml tests`, `stylua --check src tests`, `rojo build`
   all clean. No new spec FILE, so no `SCOPE_SPECS` row is needed; `src/server/Places/` already maps
   to scope `places`.

10. **Frames, opened and described** (`<runs-dir>/`, Edit, this commit):
    - `337-F1-footprint.png` (camera -1900, **7000**, -4030, straight down, `Atmosphere.Density`
      temporarily 0): the 8-cell road grid, left of centre, with **exactly one cell dark with trees**
      (C1) and the other seven bare; everything north and east of it is open terrain running past the
      frame edge, with a lake -- the land nobody hunts on. Terrain ends at the left (sky).
    - `337-F2-lobby.png` (camera 3100, **400**, -2600, looking at the grid centre): `OurForest`'s
      conifers in the foreground by the lodge, then empty rolling ground to the horizon. The grid is
      ~6,000 studs away and not in frame -- which is the point of the trim.
    - `337-F3-c1stand-edit.png` (camera -4497, **109**, -4746, the C1 stand-8 station, her own
      `Atmosphere`): C1's birch wood across the road, exactly as task 335 left it. **This task changes
      nothing a player sees today**, and that frame is the claim.

---

## What I could not verify

- **The BOOT and DRIVE-BOUNDARY wiring is NOT PROVEN LIVE.** Her Forest Test syncs from
  `driven-hunt-karen` on merged `main` (rojo :34873), and L-014 forbids checking a branch out there,
  so her server never ran this commit's `ForestTestBoot`. Claim 6 proves the MODULE on her real wood
  by injection; **the two call sites are proven by READING ONLY** (round 1, finding 1 -- this
  sentence used to say `grid.spec` proved them, and it does not: it names neither `ForestTestBoot`
  nor the call shape). What the new default-arm case proves is that the DEFAULTING those call sites
  rely on resolves to "reconcile" under a running server. Pointing her place
  at this branch needs a Rojo re-Connect, which is a click.
- **T5 (boot / join-to-gun) and T6 (frame time) have a BEFORE and no AFTER in her place**, for the
  same reason. Before, at `c0fa710b`: `smoke.sh` PASS -- lobby took the player at +4 s, gun in hand
  +16 s after the step-on, 0 stacks, 0 error lines, 12 waves; frame time at C1 stand 8 mean
  **21.91 ms**, p95 **28.56 ms** (C2 stand 8: 21.04 / 26.02). The no-regression evidence for this
  commit is the DEV harness, which includes 118 s of Play replaying the input scenarios.
- **A frame of the cell with its wood STORED is NOT OBTAINABLE.** Measured reason: instance
  streaming follows the *character*, not the camera, so a Play capture at an unoccupied stand returns
  haze (`337-F3-standing.png`, first attempt -- opened, it shows sky and distant hills); and the Edit
  place cannot show it because `Cells.reconcile` correctly refuses at Edit time. The stored state is
  evidenced by claim 6's numbers instead.
- **A contradiction inside the design, reported in the round that wrote the fix.** Section 5.3's
  table says the `missing` branch writes **nothing**; section 15 step 2 requires that forcing C2
  stores C1 and leaves `Workspace` holding no cell folder. I implemented **15**, because T1 demands
  it, and said so in `Cells.plan`'s comment and in the spec case. One of the two lines needs
  correcting.
- **`Places.PARTS_PER_MODEL` is 3.03 and the live wood measures 3.76** (9,318 parts / 2,476 models).
  Not touched here: it is `TASKS.md` 337c's, with the skirt.

## Round 2: what changed since round 1

One blocking finding, and it was right. Fixed in `e052992b`: every `reconcile` case passed an
explicit `isEdit`, so the line resolving the default had no case over it -- inverting it would have
stopped the game reconciling at all while the suite stayed green at 34/34. Claim 5 now carries the
default-arm case AND the fail-first run that shows it reddens. The request's false sentence
(*"proven by `grid.spec` and by reading"*) is corrected to **reading only**, and the overstated
ownership wording is corrected in claim 1, `GAME_DESIGN.md` and `Cells.luau`.

**Nothing else was touched.** The eight non-blocking notes are queued verbatim in `TASKS.md` row 337
as (a)-(f) plus the Architect's 5.3-vs-15 contradiction (CLAUDE.md step 5: notes are queued, not
fixed in another round), and the Reviewer's reachable consequence -- *a forced `DHForestLayout`
naming any cell but C1 runs a drive on bare ground until 336 plants the others* -- is written into
`TASKS.md` row 336.

---

ANSWERED: **L-093** the producer-delete is stated per case in claims 2, 3, 4 and 5 -- what a reader
must restore to redden each. The flag's own subject is claim 4: `isPlanted` read the static table
while meaning two questions; it is now `hasOwnWood` (static) and `Cells.isStanding` (live, reads the
world), and `isStanding` was read back **live after a swap** (claim 6, `isStanding(C1)=false` while
`hasOwnWood("C1")` is true), not only by the Workspace/ServerStorage move.
ANSWERED: **L-136** no spec failed in either PASS run; no flake fired, so none is named and no
control run is owed. Two FAILs happened this session and **neither was a flake**: `grid.spec:2698`
counted folders where the case means "C2 and B1 were never dressed" (mine, fixed in `6fab3196`), and
`grid.spec:3216` is the deliberate fail-first above, run on a dirty tree and restored.
ANSWERED: **L-127** per item: MET -- claims 1-9 (specs + the live run + the selftests). NOT PROVEN --
the boot and drive-boundary wiring live in her place, T5 and T6 after, and the stored-cell frame,
each with its measured reason above. The world trim (dispatch item 2) is **NOT DONE**, blocked, in
`ESCALATE.md`.
ANSWERED: **L-162** every live number above is from the one run made at the code commit
`6fab3196`: `337-live.luau` carries that commit's `Cells.luau` text, and the harness line names the
same sha. The before-numbers are labelled as `c0fa710b`.
ANSWERED: **L-014** `driven-hunt-karen` was never checked out, written to or touched; it is still on
`c0fa710b`. Her Forest Test ends on rojo **:34873** from that directory, unchanged. No Save, no
Publish, no Drafts Commit.
ANSWERED: **L-101** one property of her place was changed and restored for the aerial frames --
`Lighting.Atmosphere.Density` 0.230 -> 0.000 -> 0.230 -- and it was **read back** afterwards
(`337-fog.luau`: `FogEnd=100000.0 FogStart=0.0 atmosphere=true density=0.230`). Her flag overrides
were never cleared or set (lesson K). The Edit census in claim 5 is the whole-place diff.
