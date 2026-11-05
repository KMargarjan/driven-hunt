PASS (item 8 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: Karen has seen NONE of this.
The only thing she will judge -- a wood standing behind the C1 line at the first frame -- exists
solely as the Builder's own frame `328g2-F1.png`, described in claim 8 and not visible to me; the
request says so itself ("**Karen has not seen this.** The frames are mine."). What WAS seen in her
place (place `130094961655666`), by the Builder and not by Karen: the plant log, the `STANDS` boot
line, the Play-server row hashes, the close/reopen read-back and `smoke.sh`. Item 8 is NOT PROVEN
for that reason; items 1-7, 9 and 10 are instrument readings, not feel judgements.

Checks that passed, since the whole deliverable is outside the repo:
- No code changed. `blast-radius.md`: "No function, class or constant definition changed: the diff
  is data, docs or paperwork only." Diff is `ESCALATE.md`, `TASKS.md`, `reviews/task-3282/REQUEST.md`.
- The missing harness line is legitimate, not a false claim. `harness_gate` in `tools/agents.py`:
  with `ranges = [base...head, code_full~1..head]` both empty of `CODE_PATHS`, it prints
  "docs-only change: no harness line required" and returns. `b3efcf84`'s parent IS the base
  `8f91a477`, so the anti-bypass range does not cross the #335 merge -- the request's reason for
  not naming `main` is correct. `paperwork-after-code-commit.txt`: "Not paperwork: none / OK".
- Every quoted engine line is one the code can emit, format for format:
  `"[ForestTestBoot] prebuilt forest: %s, folder=%s, %d model(s) in %d cell folder(s), live=%s
  planted=%s, dress=%s"` (`ForestTestBoot.server.luau`) and `"[bake] plant OK: %d cell(s) @ %s
  %s=%s %d models / %d parts in Workspace.%s (clean tree)"` (`command_plant`).
- Claim 10's three code assertions are true. `ForestTest.prebuildVerdict` returns
  `{ branch = REFUSED, dress = false }` for `planted ~= live` and `STANDS, dress = false` for
  `planted == live`; the boot passes `if prebuild.dress then nil else {}` and `Places.build` does
  `local list = cells or Grid.PLANTED_CELLS` -- `{}` is truthy in Lua, so `first = {}` and
  `dressCells` loops zero times; and the only `:Destroy()` on a wood folder is
  `priorGrid = root:FindFirstChild(Places.GRID_FOLDER) ... priorGrid:Destroy()`. Grep for
  `FOREST_FOLDER` under `src/` returns only `FindFirstChild` and `Places.stats` reads. "Nothing
  under `src/` destroys `Places.FOREST_FOLDER`" is correct, and so is the stale-wood consequence.
- Delete the producer, claim 3 (determinism): the case survives, because `dressCell`'s own header
  says "The cell being dressed is ALWAYS destroyed first, in the set or not -- that is what
  re-planting it means", and `command_plant` passes `keep` = all five cells. Plant #2 therefore
  destroys and re-plants each cell against live raycasts rather than re-reading plant #1's
  instances -- the two readings are not the same engine identity. See note (f) for the one
  conjunct that does survive deletion.
- Delete the producer, claim 6: the Edit read is `command_plant`'s `forest_rows` on the Edit
  DataModel, the Play read is `328g-rows.py` on the Play server's clone -- two DataModels, and
  with defect F-1 live the Play side would answer `{ folder = false }`. The case discriminates.
- Arithmetic: 1942+2241+2314+2168+2174 = 10839, matching the plant line, the boot's
  `10839 model(s)` and claim 7's `up=1.1 s` sample. Claim 4's "+1, 0, +3, +1, +5" against part 1's
  1941/2241/2311/2167/2169 is right, and the five hashes equal part 1's boot dress #2 exactly as
  recorded in `TASKS.md`'s 328g row. 28,944,173 B = 27.60 MiB. 20.55/1.90 = 10.8x.
  `PlantEpoch=58575af518ae6156` is the `TerrainEpoch` 328y's row says it wrote.
- `TASK_PATTERN = r"[0-9]{1,4}[a-z]?"` confirmed; `328g2` cannot match it; `328a`..`328z` are all
  26 present as `TASKS.md` keys. `cmd_review` checks the `Task:` line against the folder only, so
  `Task: 3282` in `reviews/task-3282/` passes, and no stale `reviews/task-328g2/` is left behind.
- No secret, no absolute user path, no non-noreply address in the diff; `<backups-dir>` and
  `<runs-dir>` are used throughout. `selene` 0/0, `rojo build` exit 0.

## Notes (non-blocking)
- `tools/agents.py` `resolve_task` / the new `3282` id -- the request's reason for the number is
  backwards. It says `3282` is "far from the queue's head (329), so it cannot collide with the
  Director's next dispatch", but the ordering is `task_order(task) = (int(leading digits), str)`,
  and `reviews/task-3282/` is now the ONLY four-digit task folder in the repo (`ls-files` grep for
  `^reviews/task-[0-9]{4}` returns one line), so it is the MAXIMUM key -- above `329a`. The
  shallow-clone fallback `newest = max(found, key=task_order)` would therefore answer `3282` for
  every future no-argument `review` run until a task above 3282 exists. The primary path is commit
  recency, so a normal clone is unaffected, and the request's own recommendation 1 (rename to 330)
  removes it. Worth doing for this reason, not only for tidiness.
- `ESCALATE.md`, the 328g2 entry -- "a no-argument run does not fall through to this folder, it
  falls through to the newest CONFORMANT one, which is `task-328g`" is wrong twice.
  `resolve_task(None)`'s primary path is the most recently COMMITTED `reviews/task-*/REQUEST.md`
  by `git log`, and the fallback is `max(..., key=task_order)`; `reviews/task-329a/REQUEST.md` is
  committed, so neither path answers `328g`. The conclusion -- do not run it with no argument --
  holds either way. Fix the sentence the Director will decide from.
- `TASKS.md` -- the row is keyed `328g2` while the request is `Task: 3282` in
  `reviews/task-3282/`. Nothing refuses it, but the merge paperwork now carries two ids for one
  task. Pick one when the Director renames the folder.
- `reviews/task-3282/REQUEST.md` claim 8 -- the stated derivation does not give the stated number:
  "taken at server `up` about **3.8 s** (`328g2-earlyframe.py` prints the pin at `up=1.2 s` and
  the shot 3.0 s after it)" is 1.2 + 3.0 = 4.2 s. Immaterial to the conclusion -- claim 7 already
  reads all five cells complete at `up=1.1 s` -- but either the arithmetic or the prose is wrong.
- `<runs-dir>/replant-forest.sh` -- the dispatch's fifth deliverable is the only one with no
  artefact under version control, so I cannot read it and neither can a Director after the runs
  directory is cleaned. A one-command runbook the Director is meant to re-run belongs beside
  `tools/review.sh` and `tools/architect.sh`. That makes it a `tools/` change and costs the full
  harness, so queue it rather than move this round.
- (f) `tools/terrainbake.py` `command_plant` -- the conjunct of claim 3 that survives the
  producer's deletion: `row["rowHash"] = measured.get("rowHash", "none")` and
  `row["standing"] = measured.get("models", 0)`, so with the planting code removed both runs read
  `0` models and `none`, and "all five cells identical in models, parts AND row hash" is still
  true. The bite is carried entirely by the quoted values (`1942/09b41eb8` and the other four),
  which a deleted producer cannot produce. State the counts, never the bare equality, when this
  claim is repeated.
- `src/server/ForestTest/init.luau` `prebuildVerdict` vs claim 4's drift -- the arbiter compares
  epochs and nothing else, so a re-plant after a Studio restart stamps the SAME
  `PlantEpoch=58575af518ae6156` over wood that differs by up to 5 models a cell, and the boot
  still prints `STANDS`. That is within the epoch's stated contract ("was this wood planted on
  THIS ground") and breaks nothing, but it means `STANDS` does not certify the particular forest
  Karen approved -- relevant to the Director when the runbook is run.
- Carried from part 1 and unchanged here, so outside this round: the census's `sunk`
  101/154/123/194/200, `foliageInGround` 45/33/41/40/176 and worstSink 4.35-4.41 all come from a
  survey handing in `clawOf = 0`, which the request caveats; and `command_plant` writes
  `PlantEpoch` with an inline `SetAttribute` where `grid-terrain.md` section 2's owner row says
  the epoch attributes go "through `TerrainBake.stamp`". Both are already queued as 328g notes.
- `reviews/task-3282/REQUEST.md` claim 9 -- it proves persistence into the next Team Create EDIT
  session, which is what Play-in-Studio reads, and that is all it claims. Part 1 bounded this
  explicitly ("it is not a claim about a PUBLISHED build"); this request drops the bound and does
  not list the published case under "What I could not verify". Design section 735 says `GridForest`
  is "saved with the place", and no Save or Publish was clicked (claim 1). Re-state the bound.

---
REVIEWER verdict on commit `1aac6996588005631bf72d55c16865b09e0fe31d` (round 1) · 2026-11-05 20:37 UTC · session cost $2.40, 33 turns · written by tools/agents.py
