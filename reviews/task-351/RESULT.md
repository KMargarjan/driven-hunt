PASS (item 1 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: this IS a core item (animal
behaviour — which animals come, in what groups, in what order). **No live run was taken at this
commit and none was asked for.** The harness line `[harness] PASS: 34/34 checks @ adf2a276…
(clean tree) scope=all` names the request's `Code commit:` and `.agent-evidence/paperwork-after-code-commit.txt`
says OK (`ESCALATE.md`, `TASKS.md`, `reviews/task-351/REQUEST.md` only), so the gate evidence is
sound. What was SEEN this round: nothing in Karen's place. What has NOT been seen in her place: the
generated drive at this commit; stands 7 and 11 (the request says so — the real click lands on the
row and the hunter is still dealt stand 4); `351r2-sighting.png` and every `<runs-dir>` figure, which
sit outside the worktree and I cannot open. Round 3's only new evidence is a DEV harness run with the
producer stubbed, which the request labels as a test-bite proof and not a claim about her place.

Round 2's single finding is closed, and closed by a case that actually bites. Verified by reading,
not taken on the request's word:

- `tests/server/forest_line.spec.luau` / `differsFromScript` — `local base = source or SCHEDULE.drive;
  expect(rows).never.to.equal(base)` then a field-level count over `species`, `composition`, `party`,
  `keepAt`, `northStuds`, `offsetX`. Under the round-1 stub (`return resolved.drive`) the identity
  line fails; under a clone-returning stub `differed` is 0 and the caller's `> 0` fails. Both
  deletions are covered, which is what the claim says.
- The three call sites are the FIRST assertion in each case: `:2525` ("keeps the dial's own shape"),
  `:2662` ("never deals a drive with no red deer in it"), `:2680` ("still releases in the LAST act").
  All three read as `expect(differsFromScript(rows) > 0).to.equal(true)` inside the per-drive loop.
- **The pasted FAIL output is consistent with the repo, line for line.** `differsFromScript`'s
  `never.to.equal` is at file line 2352 and the three callers at 2525 / 2662 / 2680 — exactly the
  four numbers the request quotes from the stubbed run, and the same table address appears in all
  three failures, which is what one shared `SCHEDULE.drive` looks like.
- Claim 2's replacement bites too: `ForestTest.SILENT_KEEP_AT = 99` has exactly one writer,
  `out.keepAt = ForestTest.SILENT_KEEP_AT` inside `generateDrive`; `DENSITIES = { quiet = 9,
  normal = 13, busy = 15 }`, and `slotAt` answers nil when `(row.keepAt or 1) > want`, so the
  three-dial assertion is a real one. No row of `SCHEDULE.drive` carries 99 (nine at 9, four at 13,
  two at 15), so with the generator stubbed `silentSeen` would be 0 and the floor line would fail on
  its own. `driveTally` walks `slot = 1, #rows` through `slotAt`, so the companion
  `groups == groupsWanted("quiet")` reads the generated rows and is not vacuous — a carrying row does
  answer in the same cloned schedule.
- Claim 3 ("comments, not behaviour") holds against round 2's own verbatim quotes: `minDeer` is still
  `if deerDrawn > 0 then 0 else math.min(1, #deerGroup)` and the act-III pool is still
  `if act == 3 and #ordinary[2] > 0 then …`. The hunk grew 576 → 583 lines, which is 9 added and 2
  replaced — consistent with "nine added lines, all comment".
- Claim 4's arithmetic checks out (spec hunk 371 → 417 lines = +46 net = +50/−4). selene 0/0/0,
  stylua clean, `rojo build` exit 0.

## Notes (non-blocking)

- `forest_line.spec` / "keeps the dial's own shape" — `expect(silentSeen >= 12).to.equal(true)` is a
  TOTAL over twelve drives, but the comment above it says *"EVERY DRIVE HAS AT LEAST ONE
  (`silenceWant` is drawn from 1), so the loop above is never vacuous"*. A drive with no silent row
  is paid for by another with two and the case stays green. The non-vacuity it was written for is
  still delivered (≥ 12 silent rows walked), so this is a note and not a hole: a per-drive counter
  asserted inside the loop says what the comment says.
- `forest_line.spec` / `differsFromScript(rows, source)` — `source` is never passed by any of the
  three callers. Dead parameter; drop it or use it.
- `forest_line.spec` / `differsFromScript` — a row counts as differing if only `keepAt` moved, so a
  generator that returned the script's geometry and parties with nothing but re-ranked `keepAt` would
  still clear `> 0`. The teeth for *"a different pattern"* are in the purity case (`distinct == 5`)
  and the geometry case (`differed > 0` on the tuple), not here. Fine as a stub-killer; say so in the
  helper's comment rather than letting it read as the pattern assertion.
- `reviews/task-351/REQUEST.md` claim 2 — the keepAt census *"9 ×12, 13 ×8, 15 ×5, 0 ×1"* does not
  match the file: `keepAt = ` appears as 9 ×10, 13 ×5, 15 ×3, 0 ×1, of which `SCHEDULE.drive`'s own
  rows are nine 9s, four 13s and two 15s. The conclusion the count was offered for — no shipped row
  carries 99 — holds.
- `ForestTest.variedSchedule` / `VARIED` — round 2's note is still not taken: the memo is keyed
  `[schedule][seed]` and never pruned, so a cloned schedule plus fifteen frozen rows accumulates per
  drive for the life of the server context (~12/hour at `DRIVE.seconds` 300). Still bounded and still
  harmless; a one-entry-per-schedule cache closes it. Queue it rather than reopen it here.
- `ForestTest.generateDrive` / `minDeer` — round 2's note was taken as a COMMENT only, which the
  request states plainly: a drive that draws SNEAK can satisfy `deerGroups >= 1` with the lone stag
  (`party = "stag"`, weight 1) and no deer party. The comment now says so and offers the one-word
  tightening. Backlog item, the Director's call, as the request asks.
- `ForestTest.generateDrive`, the specials' `keepAt` — unchanged from round 2: every drawn special
  gets `out.keepAt = 13`, so a generated drive at `quiet` fires no special act where the shipped
  script fires the SPLIT. Karen's cells are `normal`; documented in the comment, not asserted.
- `ForestTest.generateDrive` — at `busy` a generated drive carries 11–14 groups against the script's
  15 (the silences are silent at every density). Said out loud in the function's header; no case pins
  it. Queue a `busy` case if the Director ever moves her dial.
- `ESCALATE.md` / `TASKS.md` — the two NOT MET items (stands 7 and 11 not measured; drive 1's
  `released` +19 % against the dispatch's 15 %) are carried honestly in both files and in the
  request. Prose, and the Director's to rule on, not a review finding.

---
REVIEWER verdict on commit `16cdc01f43e7b0ecf1d41caf5c576315b9d3f2fc` (round 3) · 2026-11-12 14:19 UTC · session cost $1.90, 25 turns · written by tools/agents.py
