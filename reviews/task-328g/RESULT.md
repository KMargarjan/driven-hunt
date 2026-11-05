PASS (items 6, 7 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: Karen has seen none of this. Item 6
(the trees standing at the first frame) and item 7 (the three described frames from the C1 stand at
−3905/109/−5062 looking −Z into C2) were seen by the Builder only, and by item 10's own statement
`Workspace.GridForest` is NOT in her place now -- it was planted, measured and archived out in the same
session, so there is nothing in her Forest Test for her to judge until PART 2 plants it. Item 8's own
rows are reported honestly as not met: client frame 43.12 / 44.30 ms against 16.7 ms (NOT MET, and the
1.2 ms is inside the instrument's spread either way), server heartbeat NOT PROVEN (two ABSENT sessions
4.7 ms apart), `StreamingMinRadius` NOT OBTAINABLE. What IS proven without her is the arbiter (three
branches by parameter in `grid.spec`, and three live `ForestTestBoot` lines at the code commit).

Duty (a), delete the producer, case by case:
- claim 2, `grid.spec` "stands on a match, dresses on an absence, and REFUSES a mismatch" and "reads an
  unstamped GridForest as REFUSED and not as absent" -- both die with `ForestTest.prebuildVerdict` /
  `plantedEpochOf` removed (a nil call), and they are not two names for one value: `prebuildVerdict(live,
  live)`, `(live, nil)`, `(live, "0000000000000000")`, `(nil, nil)` and `(nil, "58575…")` are five
  distinct inputs giving three distinct branches.
- claim 3, "an empty cell list dresses nothing and defers nothing" -- the `cells` parameter and its empty
  branch are task 328i's, not this change's, so the `#down.gridWoods == 0` / `#down.gridPending == 0`
  lines survive 328g's deletion; the lines that do NOT survive it are `prebuilt.Name =
  Planter.FOREST_FOLDER` (assigning nil to `Name` errors) and `Planter.stats(world,
  Planter.FOREST_FOLDER)`. The case is failable, and it is also the real guard on defect F-1: delete the
  constant or make `build` destroy the folder and `expect(world:FindFirstChild(Planter.FOREST_FOLDER))
  .to.be.ok()` / `expect(standing.Parent).to.equal(cell)` go red.
- claim 1's cited case SURVIVES the deletion -- see note 1. It is not blocking only because the invariant
  it names is carried behaviourally by the case above.
- claim 4's two sides are not one engine identity: `GridForest` read in Edit against `GridPlaces` read in
  a Play server, and the control proves the instrument discriminates (boot dress #2 differs from #1 in
  all five cells).
Harness line names the request's `Code commit:` `8c43aeac…`, is "(clean tree)", `scope=all`, and
`paperwork-after-code-commit.txt` reads OK (only `reviews/task-328g/REQUEST.md` followed it).

## Notes (non-blocking)
- `tools/terrainbake.py` selftest, "no line under src/ both names the prebuild's folder and destroys
  something" -- claim 1's cited proof, and it is line-local: `bare = line.split("--", 1)[0]` needs the
  folder name AND `Destroy` on ONE line, while the only destroy shape in the file it guards spans two
  (`local priorGrid = root:FindFirstChild(Places.GRID_FOLDER)` … `priorGrid:Destroy()` in `Places.build`).
  Swap `GRID_FOLDER` for `FOREST_FOLDER` there and F-1 is back with this case still green. It also passes
  vacuously with 328g removed, since `destroyers` is then empty for want of any namer. Fix: bind locals
  assigned from the name within a file, or at minimum assert the name IS referenced under `src/` at least
  once so the guard cannot be vacuous.
- `check_plant_echo` -- `same = (abs(mine - value) < 1e-9) if isinstance(value, float) else …` with
  `mine = got.get(key)`: a key the echo did not return makes this `abs(None - value)`, a TypeError
  traceback instead of refusal 4's message. Guard `mine is None` first. Same class: `plant_prelude`'s
  order check uses `plant_sent.index(...)`, which raises ValueError rather than reporting a failed check
  if a module is missing from the prelude.
- selftest, "the row-hash seam reads whatever folder it is given" -- the first conjunct,
  `FOREST_ROWS_SEAM % ("GridPlaces", "C1", "PlantEpoch")`, is a non-empty string and therefore always
  true. It asserts nothing; the conjuncts after it do the work. Drop it.
- `command_plant` -- writes `PlantEpoch` with an inline `f:SetAttribute(...)`, where `grid-terrain.md`
  section 2's owner row says the epoch attributes are written "through `TerrainBake.stamp`"
  (`stamp` hardcodes `"TerrainEpoch"`, so it cannot do this one). The owner is unchanged and nothing under
  `src/` writes it, so this is a wording-vs-mechanism gap: give `stamp` the attribute name, or correct the
  row. Also, unlike `bake`, `plant` calls no `log_run`, so a 10,000-clone write leaves no run-log entry.
- `command_plant`'s stamp-last ordering -- correct ("a folder stamped before its last cell is planted is a
  folder the boot would certify half full"), but a run that dies mid-way leaves an UNSTAMPED `GridForest`
  behind, and item 10 measured that an Edit write in her Team Create place persists with no save click. The
  next boot then prints REFUSED and dresses nothing (design 10.3), i.e. a partial wood and no fallback.
  Worth a named recovery in the refusal text, or a `plant` that removes a half-planted folder on entry.
- design `grid-terrain.md` 10.2 still says `breathe = nil`, which this change refutes by measurement and
  the seam now passes `task.wait`; 12.2's "+25-40 MB" row is measured at +3.73 MiB. Both are the
  Architect's to correct -- the code comment states the measurement, so nothing is hidden.
- `docs/design/drive-places.md` names `Places.stats(world: Instance?)`; it now takes a second
  `folderName` parameter. Stale citation only -- `src/server/ForestTestBoot.server.luau` and
  `tests/server/grid.spec.luau` are the only callers in the repo.
- REQUEST claim 8's place-file row is labelled **MET** on two numbers (28,944,488 B -> 32,853,698 B against
  150 MB), but 12.2's row also carries "Studio save <= 90 s", which was never measured -- Studio was closed
  with `WM_CLOSE` and no save prompt appeared. The measurements given are plain; the row label overstates.
- REQUEST claim 9's last sentence cites "the row hash in claim 5"; the row hash is claim 4.
- REQUEST's `test2` N/A names "the four files under `src/`" and lists three src files plus
  `tools/terrainbake.py`, omitting `tests/server/grid.spec.luau` and `tests/server/grid_ground.spec.luau`.
  Checked against `TWO_PLAYER_PATHS` in `tools/agents.py`: neither spec is in that list and no `src/Match`,
  `src/client/Range` or `src/shared/Drive` path is touched, so the N/A conclusion holds.
- `grid.spec`'s stand-down note hardcodes `2` for "%d dress(es)" rather than counting the calls, and the
  usage block in `tools/terrainbake.py` now lists `archive` twice.
- claim 3's substance -- that the boot hands `{}` when `dress` is false -- has no spec, because
  `ForestTestBoot` is a boot script. It rests on claim 5's live lines, and those do discriminate: an
  inverted ternary would print the same `dress=false` but would have left a cell folder in `GridPlaces`,
  and the request records none in either STANDS or REFUSED.

---
REVIEWER verdict on commit `9a3367c33c3c3f3061e6a843dd39995380e10072` (round 1) · 2026-11-05 19:36 UTC · session cost $4.93, 42 turns · written by tools/agents.py
