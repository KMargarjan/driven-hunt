PASS (item 6, 8 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing here is animal behaviour
or shooting, so there is no core item in the usual sense -- but the thing Karen judges by playing
(which wood is in `Workspace` when she hunts) was NOT seen in her place through the code under
review. Claim 6's live run proves the MODULE on her real 2,476-model wood by injection at
`6fab3196`; the two call sites that drive it -- `ForestTestBoot`'s boot-path
`Cells.reconcile(Cells.wantedCell(ForestTest.layoutName()), workspace, ServerStorage)` and the same
call inside the `markers` closure -- are proven by READING ONLY, which the request now says plainly,
and item 8's forced-CELL-beats-`GRID_PREVIEW` line was never driven in her place at all. Her server
syncs merged `main` (L-014), so this commit's `ForestTestBoot` has never run anywhere. T5/T6 have a
before and no after, and the stored-cell frame is not obtainable (measured reason given). What WAS
seen: F1/F2/F3 described, and the Edit census showing no `GridWood` and a byte-for-byte unchanged
place.

Round 1's blocking finding is fixed and the fix is real, not asserted. `grid.spec`'s
*"refuses at Edit time and creates no store"* now calls `Cells.reconcile("C1", world, store, nil, nil)`
-- the five-nil-argument shape both live call sites resolve to -- and asserts `reason == nil`,
`moved == 1`, `stood == "C1"`, one standing, one stored, with `Cells.editTime() == false` asserted
beside it so the default is pinned to a known value under the harness. `grid.spec:3216` is
`expect(defaulted.reason).to.equal(nil)`, exactly the line the quoted fail-first run reddens
(`Expected value "nil" (nil), got "edit-time" (string)`), on a dirty tree that was then restored.
Delete-the-producer, by reading, per case the request offers:
- claim 2: restore `keep == nil` in `dressCell`'s destroy loop and `expect(standing["D2"]).to.equal(1)`,
  `expect(grid:FindFirstChild("D2")).to.equal(stale)` and `expect(staleTree.Parent).to.equal(stale)`
  all redden. Survives nothing.
- claim 3: a `Destroy` in the store branch makes `Cells.stored(store)[1]` nil and
  `expect(stored.models).to.equal(5)` errors; an edge-triggered early return reddens the third
  call's `moved == 0` / `Cells.line(again) == nil` pair.
- claim 4: `isStanding` off `Grid.PLANTED_CELLS` makes `isStanding("C2", world)` read true against
  the asserted false.
- claim 5: covered above.
- claim 7: restore `report.gridPending = rest` and `expect(report.gridPending).to.equal(nil)`
  reddens; restore the dress of the rest and the named `C2`/`B1` assertions redden.
Claim 1 verified in the file: `Cells.luau` holds one `Instance.new` (`ensure`, a Folder) and no
`Destroy`; `src/server/Places/init.luau` names `Cells` only in comments, so `terrainbake.py`'s
`PLANT_MODULES` require rewrites are untouched (it rewrites an explicit list, it does not walk the
directory, so the new sibling is not injected). `test2` N/A is correct: none of the six touched
src/tests/tools paths is in `TWO_PLAYER_PATHS`. Harness line names `e052992b` "(clean tree)" and
`paperwork-after-code-commit.txt` says OK (only `REQUEST.md` followed it). selene/stylua/rojo clean.
No local path and no personal datum in the changed files.

## Notes (non-blocking)
- `src/server/ForestTestBoot.server.luau`, the new `Cells` require comment -- still reads "The one
  writer of a cell folder's `Parent`", the exact wording claim 1 says was corrected because
  `dressCell`'s `ensureFolder` also parents a cell folder. It was corrected in `Cells.luau`'s header
  and `GAME_DESIGN.md`'s two rows but not here, and `cell-loading.md` §9's section heading carries it
  too. Fix: the same "only thing that MOVES a cell folder between its home and the store".
- `reviews/task-337/REQUEST.md`, `ANSWERED: L-162` -- *"the one run made at the code commit
  `6fab3196`: ... and the harness line names the same sha"* is false; the harness line names
  `e052992b`. The substance holds and I checked it: `log.txt` shows `e052992b` changed
  `src/server/Places/Cells.luau` by 2 insertions / 1 deletion, and the file's header is exactly the
  two corrected sentences, so the injected text's BEHAVIOUR is the reviewed code. Claim 6's
  parenthetical *"`Cells.luau`'s own text at this code commit"* should name `6fab3196`.
- `tests/server/grid.spec.luau`, *"stands one cell, stores the rest, and writes nothing when nothing
  changed"* -- design §11.2 names three deletion-sensitivities and the case implements two. The third
  (*"a third assertion counts the world's children between the two writes through an injected `clock`
  tick and reads 2"*) is absent, and it is not writable as specified: `reconcile` calls `tick` only at
  entry and before `return`, so an injected clock cannot observe between the store and the stand
  write. Store-before-stand IS implemented and nothing asserts it. Fix: drop the sentence from the
  design, or give `reconcile` an observable seam and assert the peak.
- `Cells.line` / `cell-loading.md` §5.4 -- the code emits `<head> | ANOMALY: ...`; the design's
  example line is a bare `[Places.Cells] ANOMALY: C1 stands in both ...`. One of the two.
- `Cells.line` on the `missing` branch -- it returns non-nil whenever `reason ~= nil`, and the
  `markers` closure is read once a second while `Waiting`, so a wanted cell with no wood prints the
  MISSING line ~1 Hz for the whole wait, not the "ONE line printed" of §5.3. Matches §5.4's own rule
  as written, so the code is not wrong against the design; only reachable with a forced cell that has
  no wood, which `TASKS.md` row 336 already warns against. Worth a `printed once per want` latch when
  336 lands.
- `tests/server/grid.spec.luau`, *"plants exactly one cell on the boot path, and no more"* --
  `expect(#Planter.cellWoodFolders(gridFolder) <= 1).to.equal(true)` is a bound, not a count; the two
  named `C2`/`B1` assertions above it are what can fail. Harmless, but it reads as a third proof and
  is not one.
- Round-1 notes (a)-(f) are queued verbatim in `TASKS.md` row 337 and all six still stand as written;
  I re-checked (f) specifically -- `Cells.HOMES[1] == Planter.FOREST_FOLDER` is the same engine
  identity through two names, and the request correctly does NOT offer that case as proof of
  anything, so it stays a tripwire and a note. (b) `report.ms` left at 0 on both early returns is
  confirmed in the source.
- `src/server/Places/init.luau`, `Places.dressPending` -- now has no caller under `src/` (the boot's
  `task.spawn` is archived and `PLANT_SEAM` drives `dressCells`), so its only driver is `grid.spec`.
  Round-1 note (e) already queues naming a driver or archiving it under rule 7.
- `cell-loading.md` §5.3 vs §15 step 2 -- the `missing` row says "nothing written" while step 2
  requires every other cell stored. The code follows §15, says so in `Cells.plan`'s comment and in
  the spec case, and target T1 needs it. Already queued for the Architect; recording that I agree
  with the arm chosen.

---
REVIEWER verdict on commit `0fa48aa82c6156ef622127628a345b36624b81a8` (round 2) · 2026-11-08 21:50 UTC · session cost $3.77, 43 turns · written by tools/agents.py
