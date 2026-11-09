# Task 337b -- the world trim: `tools/terrainbake.py trim`

Task: 337b
Round: 3
Base: 77217b77 (`main`)
Code commit: 7462b00d4cd17588898e39e048acd02fc7aae59c

`[harness] PASS: 34/34 checks @ 7462b00d4cd17588898e39e048acd02fc7aae59c (clean tree) scope=all`

`test2`: **N/A** -- no `TWO_PLAYER_PATHS` path. The code files are `tools/terrainbake.py`,
`src/serverstorage/TerrainBake/init.luau` and `tests/server/grid_relief.spec.luau`; the first two map
to scope `map` in `BLAST_RADIUS`, none is in `TWO_PLAYER_PATHS`.

Round 3 is **authorised by the Director** (`ESCALATE.md` top entry, 2026-11-09 ~05:15 UTC, commit
`03e93950`), for this code commit only. `MAX_ROUNDS` is 3, so no `DIRECTOR_MAX_ROUNDS` is set.
**This round changed nothing in `src/`, `tests/` or `tools/`** -- the tree at the code commit is the
tree round 2 reviewed plus round 2's one fix. **The terrain run is NOT authorised tonight**: no
backup has been taken and `trim` has never been run.

## What changed since round 2

One commit, `7462b00d`: round 2's blocking finding, plus three of its notes that were a falsehood or
a loop in a tool that writes terrain. Everything else in both verdicts stays queued (CLAUDE.md
step 5), in `TASKS.md` row 337b.

## Claims -- each marked against the instrument that reads it, not against round 2's wording

1. **MET (read out of the commit, not out of ESCALATE.md).** Round 2's finding is fixed *in
   `7462b00d`*: `git show 7462b00d:tools/terrainbake.py` has `command_trim`'s third statement as
   `region = None`, then `region = trim_live_region(studio, studio_id, injected)`, and `region` is
   what `trim_region_problem` and the `K1 ASSERTED` print read. Both `log_run` exits in
   `command_trim` now pass the parameter `live` untouched, so `log_run`'s
   `"liveOverrides": list(live or [])` records the override list and not the region's four key names.
   *Verify:* `git show 7462b00d:tools/terrainbake.py`, `command_trim` and `log_run`. **Nothing RUNS
   this fix** -- `selftest` stubs `log_run` to a lambda returning `"<log>"`, so no case can observe
   what `live` carried. The claim is proved by reading, and I say so.
2. **MET by reading, NOT by a case.** `main`'s refusal now tests
   `args.block_studs is not None and (args.block_studs < facts["voxel"] or args.block_studs %
   facts["voxel"] != 0)`, so `--block-studs -4`, `0` and `7` all refuse before `trim_blocks`' bare
   `assert` and before the `trim plan` return. `grep -n "block_studs" tools/terrainbake.py` shows no
   `selftest` case for it; the round-1 note's traceback and the round-2 note's `x += block` walk-away
   are both closed in code only.
3. **PART MET, and the residual is mine to report, not the Reviewer's to find.** The closing print
   is fixed -- *"There is no cursor: the next run starts at block 1 again, so finish with a bigger
   --blocks"*, and `grep -n "are LEFT" tools/terrainbake.py` is empty. But `command_trim`'s own
   **docstring still opens *"Resumable: an Air write over Air is a no-op, so a run that stops half
   way is continued by running it again"***, which is the sentence the note objected to, in the
   place a reader meets first. *Verify:* the docstring of `command_trim` at this commit. Repeating a
   run is harmless and is not progress; the docstring was not corrected, and I did not correct it
   this round because the dispatch forbids touching `tools/`.
4. **MET (read out of the commit).** `git show 7462b00d:src/serverstorage/TerrainBake/init.luau`
   has the rule-7 comment (*"B3: REPARENT ONLY, never Destroy"*) immediately above
   `function TerrainBake.archive`; the commit's only Luau change is the removal of that blank line.
5. **MET, run in this session at this tree (rule G).** `python tools/studio_mcp.py selftest`,
   `python tools/agents.py selftest` and `python tools/terrainbake.py selftest` all PASS now
   (`[bake] selftest: PASS`). The trim cases carrying the two round-1 findings are in that output by
   name: *"K1 is TerrainBake.regionFor's own region, COMPUTED -- a bend of +40 moves all four sides"*
   `x[-7190,-1720] z[-7090,-3124]`; *"K1 is checked against TerrainBake.regionFor IN STUDIO"*;
   *"refusal 11 ... REFUSES a K1 that is not regionFor's region"*; *"refusal 10 ... refuses a
   hand-written list, an empty one, and a line place"*; *"the removal set is the EXACT complement"*
   (7 rectangles); *"every block is on the 4-stud voxel lattice"* (74 blocks); *"the irreversible
   half is proved by a Studio spec and not by a grep"*. `selene src`,
   `selene --config tests/selene.toml tests` and `stylua --check src tests` are 0 warnings / exit 0.
6. **MET for existence, NOT re-run by me.** The two Studio cases are in the spec *at this commit*:
   `git show 7462b00d:tests/server/grid_relief.spec.luau` has `337b-1 trimHits reads the lattice it
   is given, and trimBlock fills that block with Air` and `337b-2 trimBlock REFUSES a block it would
   have to expand, and writes nothing`. Their producer-sensitivity was checked by round 2's own
   verdict (its *"Producer-deletion check"* paragraph) against the identical spec text; **I did not
   re-run that deletion check this round** and do not claim it as my own reading.
7. **MET.** Only paperwork followed the code commit: `git diff --name-only 7462b00d..HEAD` is
   `ESCALATE.md` and `TASKS.md`, and the `TASKS.md` diff is `1 insertion(+), 1 deletion(-)` -- row
   337b alone.
8. **MET for the branch head, NOT for the code commit's own sha.** `Build and lint completed
   success` on `03e93950` (the pushed head, read from the GitHub check-runs API). The API returns
   **no check run for `7462b00d`** -- CI ran on the push, which carried the later paperwork commits.
   The head's tree equals the code commit's tree in `src/`, `tests/` and `tools/` (claim 7), so what
   CI linted is this code; the sha on the green check is not the code commit's. There is **no PR
   open** for this branch yet (`gh pr list --head task-337b-world-trim` is empty).
9. **NOT RE-MEASURED THIS ROUND, and cited rather than re-asserted (L-182).** The harness PASS line
   above was produced by the previous session, not by me: its record is the committed `TASKS.md`
   row 337b and `ESCALATE.md` section 3 at commit `c66d22d8`. No harness run was made in this round
   -- the dispatch says none is needed because the code commit is unchanged -- and there is no
   harness log file in the repo to re-read it from.
10. **NOT RE-MEASURED, and the run that printed them was at a DIFFERENT commit.** The trim-plan
    figures -- 7 rectangles, **233 blocks, 88.7 % of the world box removed, 11.3 % kept**, census
    `841/1681` nodes with 738 outside the keep boxes, K1 `x[-7190,-1720] z[-7090,-3124]`, K2
    `x[2200,3900] z[-3500,-1250]`, world `x[-7500,7500] z[-7500,7500] y[-512,616]` -- come from the
    read-only `trim plan` run in Karen's Forest Test at code commit **`98dbdaa9`** (round 2's
    `REQUEST.md` claim 11, transcribed into `TASKS.md` row 337b). `trim plan` writes nothing, so
    there is no `.terrainbake/` file to re-read: that transcription is its only record. `7462b00d`'s
    change to that path is the variable rename alone (`git show 7462b00d -- tools/terrainbake.py`,
    `command_trim_plan`), so the arithmetic is unchanged -- but **the numbers were not re-measured at
    the commit under review**, and I do not present them as if they were.

## What I could not verify

- **No terrain has been trimmed, no backup has been taken, `trim` has never been run.** Dispatch
  items 2-4 (backup, run, before/after census, frames, `smoke.sh`) are gated on this PASS and on a
  separate Director dispatch. Nothing in Karen's place was opened, read or written in this round.
- **The per-block cost is still unmeasured**, so `trim plan` prints no minutes: measuring one block
  is itself a terrain write.
- **The live `FillRegion` size is still unproved.** The biggest fill any case runs is the spec's
  128 x 256 x 128; a live block is ~18.5 M voxels, and `call` raises rather than refuses if the
  engine rejects it. Queued round-2 note; the failure mode at block 1 is a traceback.
- **Terrain beyond the census lattice (+-10,000 studs)** is not in the removal set, and the Y ceiling
  is inferred from the same lattice as the declared -512 floor.
- Round 2's other notes are all queued unchanged in `TASKS.md` row 337b, not fixed.

ANSWERED: L-174 the round count is read off the committed `reviews/task-337b/RESULT.md` trailer,
which names round 2 at `7b21d2b9`; this request is `Round: 3`, authorised by the Director in
`ESCALATE.md` at `03e93950`, and 3 is inside `MAX_ROUNDS`, so no `DIRECTOR_MAX_ROUNDS` is set or
committed. A finding here goes to `ESCALATE.md` and the task stops.
ANSWERED: L-127 every claim above carries MET / PART MET / NOT RE-MEASURED against the instrument
that reads it, and three of the ten are explicitly not measurements of mine (6, 9, 10). Claim 3
reports a residual against the fix instead of restating round 2's wording as settled.
ANSWERED: L-014 nothing was checked out in `driven-hunt-karen`, no Studio was opened, and no place
was read or written in this round.
ANSWERED: L-171 claim 1 reads the fix back out of `git show 7462b00d:tools/terrainbake.py`; neither
`ESCALATE.md` nor round 2's `RESULT.md` is taken as evidence that it landed, and claims 2 and 4 do
the same for the three notes.
ANSWERED: L-182 claims 9 and 10 name where each number was printed and at which commit, and mark
both as not re-measured here; the 233 / 88.7 % pair is cited to the `98dbdaa9` `trim plan` run as
transcribed in `TASKS.md` row 337b, not re-asserted from this dispatch's own text.
