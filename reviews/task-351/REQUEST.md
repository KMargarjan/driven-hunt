# Task 351 — every drive a different pattern

Task: 351
Round: 3
Base: origin/main (2f9524ca, #368)
Code commit: adf2a276b9eb0d3112e17580293f527ab3c990a4

```
[harness] PASS: 34/34 checks @ adf2a276b9eb0d3112e17580293f527ab3c990a4 (clean tree) scope=all
```

`[harness2]` is **N/A**: nothing under `TWO_PLAYER_PATHS` changed (`src/shared/ForestTest/`,
`src/server/ForestTest/`, `src/shared/Flags/`, `tests/server/forest_line.spec.luau` — no `Match/`,
no `Drive/`, no `Role.luau`, no match spec).

**Round 3 is Director-authorised** (`ESCALATE.md`, *"Director 2026-11-12 14:02 UTC: round 3
authorised (option 1)"*; `MAX_ROUNDS` is 3, no override used). **One commit entered it**: `92d55fc1`,
which closes round 2's single finding. `adf2a276` adds nothing but round 2's verdict file, which is
why the harness line names it. **Nothing else in the branch changed since round 2.**

## What this round is about: round 2's finding, closed

Round 2's finding: `tests/server/forest_line.spec.luau`'s cases **"keeps the dial's own shape: nine
groups at quiet, no more than the script at normal"**, **"never deals a drive with no red deer in
it"** and **"still releases in the LAST act: the drive ends with the last runners"** all **passed**
with `ForestTest.generateDrive` stubbed to return the shipped script, and one line offered as claim
6's verification (`expect(Data.SILENT_KEEP_AT > Data.groupsWanted("busy", SCHEDULE))`) was `99 > 15`
— two constants, reading no generated row. The finding was right and is not disputed.

## Claims

1. **The three cases now FAIL when the generator is deleted — run, not argued.** A `differsFromScript`
   helper (`tests/server/forest_line.spec.luau`, above `generated`) is called **first** in each of
   the three. It is field-level, not identity: it compares each row's `species`, `composition`,
   `party`, `keepAt`, `northStuds` and `offsetX` against `SCHEDULE.drive`'s row of the same index and
   returns the count that differ, so a **clone** of the script fails it too.
   *Verify:* stub `ForestTest.generateDrive` to `return resolved.drive` (round 1's own deletion) and
   run the harness. Done, in DEV, uncommitted, then reverted; the tree was clean again before this
   request was written. `[harness] FAIL: 32/34 checks @ 0763ed36 (DIRTY TREE (1 paths) - NOT valid
   evidence) scope=all`, `[tests:server] FAIL: 2958 passed, 8 failed, 0 skipped, 8 errors`, and the
   three cases are three of those eight:

   ```
   TestService: ServerStorage.Tests.forest_line.spec:2525: Expected anything but value "table: 0x58e6d9ddbbd96e89" (table)
   ServerStorage.Tests.forest_line.spec:2352 function differsFromScript
   ServerStorage.Tests.forest_line.spec:2525          <- "keeps the dial's own shape"

   TestService: ServerStorage.Tests.forest_line.spec:2662: Expected anything but value "table: 0x58e6d9ddbbd96e89" (table)
   ServerStorage.Tests.forest_line.spec:2352 function differsFromScript
   ServerStorage.Tests.forest_line.spec:2662          <- "never deals a drive with no red deer in it"

   TestService: ServerStorage.Tests.forest_line.spec:2680: Expected anything but value "table: 0x58e6d9ddbbd96e89" (table)
   ServerStorage.Tests.forest_line.spec:2352 function differsFromScript
   ServerStorage.Tests.forest_line.spec:2680          <- "still releases in the LAST act"
   ```

   The other five failures of that run are cases that already bit at round 2 (`:2386` identity,
   `:2437` purity `distinct == 5`, `:2495` Karen's rules, `:2587` "sometimes", `:2649` the geometry
   tuple) — the stub is a deletion of the producer, so they fail too, which is what they are for.
   The line numbers are that run's Studio copies of the spec at this commit, and the case each one
   sits in was read back out of the file rather than assumed.
2. **Claim 6's `99 > 15` line is gone and the sentence it claimed is asserted of a GENERATED drive.**
   The case now clones `SCHEDULE`, puts the generated rows in it, walks them, and for every row
   carrying `Data.SILENT_KEEP_AT` asserts `Data.slotAt(slot, …)` is `nil` at `busy`, `normal` **and**
   `quiet` — the three dials, the widest included. A floor, `silentSeen >= 12` over the twelve drives,
   stops the walk being vacuous. *Verify:* the case's own body; `ForestTest.SILENT_KEEP_AT` is 99 and
   its **only writer is inside `generateDrive`** (`grep -n SILENT_KEEP_AT src/shared/ForestTest/init.luau`
   gives the declaration and `out.keepAt = ForestTest.SILENT_KEEP_AT`), and no shipped row carries it
   (`keepAt` literals in that file: 9 ×12, 13 ×8, 15 ×5, 0 ×1 — no 99). So under the stub the floor
   line cannot hold either; **that half is argued by reading, not by run**, because
   `differsFromScript` aborts the case before the walk is reached (V293b).
3. **Round 2's two taken notes are comments, not behaviour.** `ForestTest.generateDrive`'s `minDeer`
   comment now says out loud that the SNEAK act's lone stag counts as the drive's deer party; the
   act-III geometry comment now says act II is the **shallower** half of the script (its ordinary rows
   are at `northStuds` 150/170/210/265 against act III's 290), which was the wrong reason given for a
   right change. *Verify:* `git show 92d55fc1 -- src/shared/ForestTest/init.luau` — nine added lines,
   all comment.
4. **Nothing else moved.** `git diff 5350c8c7 adf2a276 --stat` is exactly
   `src/shared/ForestTest/init.luau` (+9 comment lines) and `tests/server/forest_line.spec.luau`
   (+50/−4), plus round 1's and round 2's paperwork. *Verify:* that diff.
5. **CI is green on the branch head** (`0763ed36`, run 43232545698, success), and
   `python tools/studio_mcp.py selftest` and `python tools/agents.py selftest` both PASS in this
   session (rule G).
6. **Only paperwork follows the code commit.** After `adf2a276`: `659d002f` (`ESCALATE.md`),
   `0763ed36` (the `TASKS.md` status row) and this request plus the authorisation line. *Verify:*
   `git diff --name-only adf2a276..HEAD` and `.agent-evidence/paperwork-after-code-commit.txt`.

## Unchanged from rounds 1 and 2 (not re-claimed; nothing in this round touches it)

Round 1's five findings are fixed and round 2 passed all of it at `5350c8c7`: OFF is the shipped
script by identity and byte-identical to `origin/main`; the generator is pure and gives five
consecutive drives five different patterns; Karen's rules hold over 40 spec drives and 160 probe
drives (animals 65..81, out of spec 0); each special appears in some drives and not others; the dial
keeps its meaning; `planDrive` is keyed on the drive number (proved live with `PLACEMENT_IN_PLACE`
ON); four live drives at `5350c8c7` are all different, first sighting 6 s, median gap 7 s, max gap
44–51 s against the OFF control's 50 s; `351r2-sighting.png` opened and described.

**MET:** every dispatch item except the two below. **NOT MET, unchanged and the Director's to rule
on:** (a) **stands 7 and 11 NOT MEASURED** — the real click lands on the row but the hunter is still
dealt stand 4 (`351s-track.txt`: `stand=4 at=0`), which is the stand-pick path of tasks 323/349, not
this change, and this dispatch says not to investigate it here; (b) **`released` within 15 %: drive 1
is +19 %** (145 against the OFF control's 122), while drive 3 is +0 %; the roster the generator
actually controls is 65–73 against the script's 73, i.e. −11 % to 0 %, inside the band. Also still
open as a **non-blocking note of round 2, for the backlog, not this round**: a drive that draws SNEAK
can satisfy `deerGroups >= 1` with the lone stag and no deer party.

## What I could not verify

- **No live run was taken this round, and none was asked for.** Every live figure above is round 2's,
  at `5350c8c7`, labelled as such; the only new evidence is the stubbed harness run in **DEV**, which
  is a test-bite proof and not a claim about Karen's place.
- **The stubbed run's own line is a DIRTY-TREE FAIL line** — that is what it is for; the clean-tree
  PASS evidence for this round is the `adf2a276` line at the top.

## ANSWERED (the dispatch's CHECKED flags)

- ANSWERED: **L-028** — the three cases' FAIL output is **pasted verbatim per case** in claim 1, from
  a run made in this session with `generateDrive` stubbed (no earlier proof run existed; the runs dir
  holds no such capture). The one half that is read rather than run is named on its own line in claim 2.
- ANSWERED: **L-038** — round 3 is Director-authorised and the authorisation line is appended under
  the task-351 entry of `ESCALATE.md`; `MAX_ROUNDS` stays 3 and `DIRECTOR_MAX_ROUNDS` was not set.
- ANSWERED: **ROUTE** — the code commit is `adf2a276`, the commit the harness line names (`92d55fc1`
  is the fix, `adf2a276` only adds round 2's verdict), and the review is run through
  `tools/review.ps1 351`. Round 2's note about drive 1's +19 % is carried into the NOT MET lines above
  rather than left to a harness PASS, and the SNEAK-stag note is flagged for the backlog.
