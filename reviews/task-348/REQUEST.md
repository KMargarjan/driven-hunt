# Task 348 — round 2: the stub runtime hands out the real handle's shape

Task: 348
Round: 1
  (the Director's dispatch calls this "round 2"; `tools/agents.py` counts the round from this
  task's committed `RESULT.md`, which is a round-1 PASS, so it requires `Round: 1` here and the
  request cannot say otherwise. Round 1's verdict is kept in git history at `a357e028`.)
Base: 0c1dd2ac
Code commit: 1bae84ba23a7e8be88ded3651c04e7a36167b942
  (the last commit to change `src/`/`tests/` is `b97b3751`; `1bae84ba` is three paperwork commits
  later and is the sha the harness line below names, which git workflow step 4 allows and calls
  stricter.)

Round 1 passed (`PASS`, item 6 NOT PROVEN) and **the bot fix is unchanged** — `Match.botFillDuringPick`,
its spec case 15 and the Forest Test before/after are exactly as reviewed, and nothing in `src/` moved
this round. The Director accepted the round-1 `ESCALATE.md` entry and sent this round to unblock `test2`.

Harness at the code commit, clean tree:

    [harness] PASS: 34/34 checks @ 1bae84ba23a7e8be88ded3651c04e7a36167b942 (clean tree) scope=auto:match

A FULL `scope=all` run also passed, at `b97b3751` — the same tree, three paperwork commits earlier —
and its line is in the Builder's report and in `ESCALATE.md` for the merge gate. The scoped line is
the one pasted here because this change cannot produce the `[harness2]` line that a `scope=all` line
makes the gate ask for (see "What is NOT obtained" below); that is the Task 113 review-round route.

## The one change this round

`tests/server/forest_placement.spec.luau`, `stubRuntime().boars()` — and nothing else, in any file.

    before:  table.insert(out, { id = id })
    after:   id, kind, and position AS A FUNCTION, read live from the stub's own `where` table

**It is a STUB defect, and the fix is at the stub.** The real handle is built in
`src/server/Boar/init.luau` (`Runtime:boars` returns `entry.handle`) and carries
`id`, `kind`, `part`, `soundPlays`, `state()` and `position()`. `ForestTest.spookNearBeaters` reads
`handle.id`, `handle.kind` and `handle.position()` **unguarded**; the stub supplied only `id`, so
`local at = handle.position()` was a call of a nil value.

**Production was NOT made tolerant of a handle with no `position`**, as the dispatch required: the
real `Runtime` always hands one out — `position = function() return Body.position(body) end` in the
`local handle = {` literal in `src/server/Boar/init.luau` — so a missing one is a stub bug, not a
contract the server has to defend against.

**`part` is deliberately left out.** `ForestTest` reads `handle.part` three times and **both call
sites nil-guard it** (`local part = handle and handle.part; if part ~= nil and part.Parent ~= nil`,
and `if handle and handle.part and handle.part.Parent`), and a stub has no instance to hand over.
`id`/`position`/`kind` are the three read unguarded, and those are the three now supplied.

**Why only `test2` ever found it:** the loop is gated on `#ForestTest.realBeaters() > 0` — real
beater players plus bot DRIVERS. With one player there is no beater and the loop is never entered,
which is why the one-player run was 34/34 with that spec green all along.

## Claims

1. **The defect is gone, twice.** `test2` @ `b97b3751`, two independent runs
   (`<runs-dir>/348r2-after.log`, `348r2-after2.log`): `grep -c "forest_placement\|spookNearBeaters"`
   answers **0** in both. *Verify:* the two logs.
2. **L-093, the delete-and-fail side, is a RUN and not a reading.** Round 1's `test2`
   @ `66de5029` (`<runs-dir>/348-test2.log`) is the same spec with the field **absent**:
   `ServerStorage.Tests.forest_placement.spec:1310` → `ServerScriptService.ForestTest:2743 function
   spookNearBeaters`, *attempt to call a nil value*, `[tests:server] FAIL: 2944 passed, 1 failed`.
   The only delta in that file between `66de5029` and `b97b3751` is this stub field, so reverting it
   is that run. **Two harness lines, two different commits**, both pasted below.
3. **The one-player gate is green** at the code commit (`34/34 ... scope=auto:match`) and a full
   `scope=all` run was also 34/34 at `b97b3751`, first run, with 2945/0 on the server.
4. **No `src/` file changed this round.** *Verify:* `git diff --name-only 66de5029..b97b3751` — one
   file, `tests/server/forest_placement.spec.luau`.
5. **The two selftests pass** (`tools/studio_mcp.py selftest`, `tools/agents.py selftest`), and the
   spec file is already in the `match` scope, so no `SCOPE_SPECS` row moved.

## What is NOT obtained, and why — read this before judging claim 1

* **There is no `[harness2] PASS` line, and there cannot be one this session.** `test2`'s first
  check is `One Studio instance before the test starts`, and Karen's Forest Test Studio is the
  second. It **FAILs in every run** — it is recorded, not fatal, and task 226's scoping directly
  below it resolves the editor BY PLACE, so the run itself is sound. Closing that Studio would
  discard the Director's 11:59 UTC `PLACEMENT_IN_PLACE=false`, which `tools/flags.py` wrote as an
  unsaved session attribute, and this round's dispatch says not to touch it. Written up at the hard
  stop in `ESCALATE.md` (12:15 UTC, corrected after the runs) with the three steps that unblock it.
* **The merge-base control at `0c1dd2ac` was attempted three times and never reached the specs.**
  Run from the `driven-hunt-rev` worktree, `Rojo synced the fresh token from disk` reads
  `'<missing>'` then `''` (`348r2-control.log`, `-control2.log`, `-control3.log`) because
  `tests/sync-token.txt` is git-ignored and absent from a fresh worktree; re-serving after creating
  it did not clear the empty read. Claim 2 answers the same question with a **tighter** delta — one
  field in one file — so I stopped rather than spend the rest of the session on it.
* **Other specs fired in the two `test2` runs, and none is `forest_placement`:**
  `deer_hitbox.spec:682` in both (it is on this dispatch's own KNOWN FLAKE list),
  `deer_hitbox.spec:340` and `gun_client.spec:393` once each, neither recurring. The two runs scored
  31/36 and 33/36. I make no claim about `:340` or `gun_client.spec:393` beyond "fired once, did not
  recur"; neither is on the dispatch's list and neither is touched by this diff.
* **Round 1's item 6 is still NOT PROVEN** and this round does not change it: the bot's absence
  beside the player was MEASURED in Karen's place (`within10=0/287`), never SEEN in a frame of the
  wood. Nobody has watched an empty neighbouring post.

**A HARNESS FAULT, REPORTED AS RULE 6 ASKS (it cost three runs).** Two scoped runs failed on
`camera_client.spec:1161` — the same line twice, at a commit whose only delta from the green
`scope=all` run is paperwork, so it was never the code. The cause was **two orphaned `Place1` test
clients left running by `test2`**: its own output says *"3 test Studio(s) still open: press Cleanup"*,
and my Cleanup click had missed after the DEV window moved. They stayed connected, and the client
specs read them. Closing the DEV place and killing both processes cleared it on the next run
(`348r2-scoped3.log`, 34/34). Worth a guard: `test` could refuse to start while a `Place1` Studio is
connected, exactly as it refuses a flag override.

The two harness lines, at the two different commits claim 2 rests on:

    [harness] PASS: 34/34 checks @ 1bae84ba23a7e8be88ded3651c04e7a36167b942 (clean tree) scope=auto:match
    [harness2] FAIL: 34/36 checks @ 66de5029955d6560ffaa62606b9be6f1198770b4 (clean tree)

ANSWERED: L-136 every spec that fired is named above with its run — `deer_hitbox.spec:682` twice (on
the dispatch's list), `deer_hitbox.spec:340` and `gun_client.spec:393` once each; I re-ran `test2`
once, so the count is two runs, and `forest_placement` is 0 in both.
ANSWERED: L-162 this round's pasted harness line names the code commit `1bae84ba`, and the full
`scope=all` run named `b97b3751`, which differs from it only in paperwork; the one
line that names `66de5029` is round 1's, cited only as the field-absent side of L-093 and labelled
with its commit on the line.
ANSWERED: L-093 the delete-and-fail is a RUN, not a reading — round 1's `test2` at `66de5029` is the
stub with the field absent and it fails at `forest_placement.spec:1310`; claim 2.
ANSWERED: L-034 the control line and the new-commit lines are kept apart above and never blended;
the control was not obtained and says so in its own bullet.
ANSWERED: L-173 I ran NO scoped harness this round, and the lesson does not apply: this defect fires
only in `test2`, which has no `--scope` form at all, so the fix-and-recheck loop had to be `test2`
itself. It cost two runs, not ten, because the fix was read off the real handle before it was written.
