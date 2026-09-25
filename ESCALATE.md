# Escalations

For the Director and Karen. The Builder (or any agent) writes here and stops when:
- the same item has failed 3 review rounds
- it believes the Reviewer or Architect is factually wrong
- a design, feel or scope decision is needed
- **a human action is needed** (Rojo **Connect**, the Studio MCP toggle, Studio not in Edit mode,
  anything only Karen can click). Head that entry **`NEEDS KAREN`** and list the exact clicks.

Newest first. The Director or Karen answers under each entry, and the entry is closed with a date.

---
## 2026-09-25 · OPEN · Tasks 17+18: round 5 was the last authorised round, and it found 4 things

**Raised by:** Builder, at loop step 5 of the combined Tasks 17+18 (branch `task-18-boar-ai`, code
commit `b6cf3dec736347f65c42ad3d05129d302389349a`).

**Result.** `DIRECTOR_MAX_ROUNDS=5` authorised two rounds with real evidence. Both were used.
Round 4 returned **9** findings, round 5 returned **4**; all 13 are fixed, and **round 5's four are
unreviewed** because there is no round 6.

| Round | Commit | Findings | The one that mattered |
|---|---|---|---|
| 4 | `4432292` | 9 | **The "real arena" pathfinding test was testing the default Baseplate.** It never waited for `Workspace.TestArena`, so it ran before `ArenaBoot` had built anything — and its own output said so: 54 waypoints for a 210-stud route is a straight line with no detour, which I read past |
| 5 | `36b7c19` | 4 | **A whole failure class the diagnostic could not see.** `ComputeAsync` returning `Success` with no waypoint past where the boar already stands is counted as a failure by the Runtime, produces exactly the silent straight-line fallback the diagnostic exists to catch, and was recorded nowhere |

**What is unreviewed.** Round 5's four fixes:
1. `pathProblems` now counts `"success: no waypoints"` (about 10 lines in
   `Boar.defaultWorld().requestPath`), which is what makes the `world >= runtime` invariant rest on
   containment rather than coincidence.
2. A comment at the determinism test explaining why its `1e-9` is deliberately tighter than
   `EPSILON`.
3. `TASKS.md` row 18 and this file's Task-18 closure now name the reviewed code commit instead of
   `fbe1d60`, the first green run.
4. `REVIEW_REQUEST.md` rewritten fresh with one continuous claim numbering.

**Everything is green on the reviewed commit:**
`[harness] PASS: 24/24 checks @ b6cf3dec736347f65c42ad3d05129d302389349a (clean tree)` — 39 server
and 4 client assertions across five spec files. Lint, format and `rojo build` clean. Rule 5 met:
play-time screenshots captured and inspected.

**What these two rounds bought, plainly.** Rounds 1–3 reviewed this code with nothing ever executed
and passed over all of it: a test measuring the wrong world, a diagnostic with two blind spots, two
tests contradicting a feature they sat beside, and a tolerance tighter than float32. **Running it
once found three of those in ninety seconds.** The order the Director chose — harness first, then
review — is the reason this branch is worth merging.

**Options for the Director.**
1. **Accept on the record and merge.** The four unreviewed fixes are small, all of them make a
   diagnostic or a comment more honest rather than changing behaviour, and the full harness is green
   on the commit that contains them.
2. **One more authorised round** (`DIRECTOR_MAX_ROUNDS=6`), ~$2.80. On this branch's record it would
   probably find something — rounds 4 and 5 both did, and round 5 found a hole in a round-4 fix.
3. **Merge and queue the residue.** What is genuinely untested is listed in
   `REVIEW_REQUEST.md` "Could not verify" and in the research note's addendum §4: `Path.Blocked` has
   never fired, no real player has ever been a threat, `maxBoars` is never reached.

**Builder's recommendation: option 1, then option 3's residue as a queued task.** The remaining risk
is not in the code that was reviewed twice with evidence; it is in the paths nothing has exercised,
and a sixth reading will not reach those. A playtest with Karen and a second player will.

**Two things need Karen, both recorded in `TASKS.md` rows 17 and 18 and neither mine to change:**
the arena floor rendering as a triangle because it is coplanar with `Workspace.Baseplate`, and the
two `SpawnLocation`s during Play.

**Needs:** a Director decision. Karen's two calls are separate and not blocking this merge.

---

## 2026-09-25 · OPEN · FOR THE DIRECTOR · play-time `screen_capture` works; `TASKS.md` row 7 is wrong

**Raised by:** Builder, during the Tasks 17+18 harness run (branch `task-18-boar-ai`). This is not a
blocker — it **unblocks** something, and the queue is the Director's to edit, not mine (`CLAUDE.md`
Roles), so it comes here rather than into row 7.

**`TASKS.md` row 7 says:** "**BLOCKING before any visual client code (UI, HUD, cursor art):**
play-time screenshots | todo | StudioMCP's `screen_capture` is edit-time only, so rule 5 cannot be
met for play-time visuals by tools."

**That is wrong, and it has been wrong since Task 5.** `screen_capture` **does** work during Play. I
captured three play-time screenshots of the arena and the boar through MCP on 2026-09-25, inspected
them, and they are the rule-5 evidence for both tasks.

**The cause of the mistake was mine, in `tools/studio_mcp.py`.** `Studio._call` builds its return
value as

```python
text = "\n".join(c.get("text", "") for c in result.get("content", []))
```

— it joins **only the `text` content blocks**. `screen_capture` returns an **image** block
(`mimeType: image/jpeg`, base64), and no text at all, so `_call` returns an empty string. My first
attempt read that empty string as "capture is unavailable during Play". Calling `tools/call` directly
and keeping the image blocks returns the JPEG.

**What follows, for the Director to decide:**
1. **Row 7 is not blocking any more**, at least not for this reason. Whether it closes or becomes
   "wire capture into the harness" is a queue decision.
2. **A harness change would make this routine**, and it is small: one `capture` command that calls
   `screen_capture` and writes the image to a file. But `ROADMAP.md` speed rule 1 freezes tooling
   after Task 11, so I have not written it. Today's captures were taken by a throwaway script in the
   scratchpad, which means **rule 5 currently costs a hand-written script each time**.
3. **The `_call` text-only join is a latent trap for any future image-returning tool** (`store_image`,
   `generate_texture`, `generate_mesh` are all in the MCP tool list). Worth a one-line comment in
   `studio_mcp.py` at minimum, which is also a tooling change.

**Needs:** a Director decision on row 7 and on whether the harness gets a `capture` command. Nothing
here needs Karen.

---

## 2026-09-24 · CLOSED 2026-09-25 · Task 18 reached round 3; the script refuses a fourth

**Raised by:** Builder, at loop step 5 of Task 18 (branch `task-18-boar-ai`, stacked on
`task-17-test-area`). Overnight, no-Studio mode.

**Result.** Three review rounds, 16 findings, all fixed. Round 3's four are fixed in the commit that
carries this entry. `tools/review.sh` refuses `Round: 4` (`MAX_ROUNDS = 3`) and the round count is
taken from the committed verdict, so I cannot get a `PASS` on the fixed commit.

| Round | Commit | Findings | Of which real defects in code or specs |
|---|---|---|---|
| 1 | `ad35852` | 6 | 3: `Path.Blocked` documented but not implemented (and a `Path` rebuilt per request); the anti-stuck turn was dead code; `boar_body.spec` would have failed on its first run because it measured the spawn drop as walking speed |
| 2 | `732c74a` | 6 | 4: the anti-stuck fix still did nothing (the slew undid it); the new stuck test was vacuous; the landing guard was vacuous; **and a real gameplay bug — an idle boar could despawn itself as "escaped" with no driver anywhere, because `spawnPoint` was 130 studs from the exit line while `HOME_RADIUS` is 120** |
| 3 | `e821aa4` | 4 | 2: the control case for the stuck test was vacuous (the control boar ran over the exit line and went `GONE` on tick 64, so the window measured nothing); the reaction assertion was 0.5 s where the design specifies 0.25 s, which would have hidden a doubling of `SENSE_INTERVAL` |

**What this says about the work, honestly.** The anti-stuck behaviour took three attempts and its
tests took three. Two of my three "fixes" for it did not work, and I asserted in writing that each
one did. The same claim about who constructs a `Brain` was wrong in all three rounds. None of this
would have been caught by lint, and **none of it can be caught by running anything, because nothing
in this task has ever executed** — `rojo serve` is down until Karen presses Connect. The Reviewer is
currently the only thing standing between this code and the game.

**What is now unreviewed.** Round 3's four fixes: the control-case rewrite (the boar now circles at
radius 30 instead of running off the map, and the test asserts it is still alive), the 0.25 s
reaction bound, the research-note addendum §3 rewritten to record all four departures from the
design rather than two, and claim 1 in `REVIEW_REQUEST.md`.

**State.** Code commit `4fa3db2bfc92c6521e13d44799e8e48ead9b888a`, clean tree. `selene src`, `selene --config tests/selene.toml tests`,
`stylua --check src tests` and `rojo build -o build/place.rbxl` all pass — the commands CI runs.
**No harness run, no screenshot, nothing executed.** Branch pushed; no PR opened (the Director does
that).

**Options for the Director.**
1. **One authorised round 4** (`DIRECTOR_MAX_ROUNDS=4`), as for Task 11. Round 3's findings were two
   vacuous tests and two documentation bounds — not the "documentation-only" case your standing rule
   names, since a vacuous test is a defect. Cost ~$2.50.
2. **Merge on the record**, accepting that the last four fixes are unreviewed. I would not recommend
   this here: unlike Task 11, the unreviewed changes are *test* changes, and the pattern of this task
   is that my test fixes have been wrong more often than my code.
3. **Hold Task 18 until Karen connects Studio (~09:00), then run the harness first and review after.**
   Everything blocking is the same blocker: nothing has run. A harness run would settle more than a
   fourth reading would — in particular the `LinearVelocity` plane setup, the `Path.Blocked` index
   arithmetic and whether either spec even loads.

**Builder's recommendation: option 3, then option 1 if the harness turns up nothing.** The cheapest
real information available is a single harness run at 09:00, and it costs nothing but Karen's click.
A fourth reading of code that has never executed has clearly diminishing returns — rounds 2 and 3
each found that my *previous* fix was wrong, which is exactly what running it would have told me in
seconds.

**Needs:** a Director decision. Karen's Connect click is already requested in the Task 17 entry
below; nothing further is needed from her for this.

### DIRECTOR's answer · 2026-09-25

**Option 3, then option 1: harness first, then review with real evidence.** Karen connected on the
morning of 2026-09-25, so the cheapest information became available and was taken first.
`DIRECTOR_MAX_ROUNDS=5` is authorised **for this run only** — up to two more rounds on the combined
Task 17 + Task 18 change, which is now one unit on `task-18-boar-ai`.

**The Director was right that a harness run would settle more than a fourth reading.** It did. The
first real run gave **35 passed, 3 failed, 3 errors**, and all three failures were things no amount
of re-reading had found:

| Failure | What it actually was |
|---|---|
| `boar_body` "used real pathfinding" — `pathFailures` 31, expected 0 | **The spec asserted the wrong thing.** `Enum.PathStatus.NoPath` on the spec's own plate floating at y = 500. An Edit-mode probe settled it: the same agent parameters at y = 0 return `Success` with 54 waypoints from `CONFIG.spawnPoint` to the exit line. Pathfinding works where the game plays |
| `boar_brain` "never accelerates faster than ACCEL" | **A tolerance tighter than float32 can be.** Measured overshoot 1.9e-6 against a 1e-6 tolerance |
| `boar_brain` "never turns faster than TURN_RATE" | **Two of my own tests contradicted each other.** Both held the boar at a fixed position for 300 steps; standing still for 2 × `STUCK_TIME` is by definition stuck, so the anti-stuck branch turned it 90° in one tick — the very behaviour the neighbouring test asserts |

**Closed** 2026-09-25 by the Director.

---

## 2026-09-24 · CLOSED 2026-09-25 · NEEDS KAREN · `rojo serve` crashed; Task 17 cannot be tested

**Raised by:** Builder, at loop step 3 of Task 17 (branch `task-17-test-area`, code commit
`48169db`). Overnight run, Karen asleep.

**What happened.** The Task 17 code is written and committed. The harness then failed at check 3:

```
  FAIL Rojo synced the fresh token from disk  (Studio has '')
[harness] `rojo serve` is NOT running (crashed?). Known Rojo 7.7.0 bug ...
[harness] FAIL: 3/4 checks @ 48169db32effaa1d4b8f0995dbf7df106f0d8f46 (clean tree)
```

Confirmed independently: `tasklist` shows no `rojo.exe`, nothing is listening on port 34872, and
`curl http://localhost:34872/api/rojo` returns nothing. Studio is still open on the DEV place in
**Edit** mode and the MCP server still answers, so only Rojo is down.

**Why.** Almost certainly the known Rojo 7.7.0 crash already in `CLAUDE.md` ("Known Rojo 7.7.0
crash": it panics when a watched file or folder disappears before it processes the event,
[#1309](https://github.com/rojo-rbx/rojo/issues/1309),
[#1321](https://github.com/rojo-rbx/rojo/issues/1321)). Rojo was alive at the start of this run — two
`rojo.exe` processes, and a read-only MCP probe worked. It died across
`git switch main && git pull` (59 commits) and `git switch -c task-17-test-area`, which deleted and
rewrote many watched files at once. **New data point for that note: a large branch switch is enough to
crash it**, not only a test deleting a folder. `CLAUDE.md` currently says to stop `rojo serve` before
switching branches; this run shows why, and the Task 17 dispatch forbade stopping it. Worth folding
into `CLAUDE.md` on the next task.

**Why I stopped rather than fixing it.** Two overnight rules, both explicit: never stop or restart
`rojo serve`, and if Rojo is down write a NEEDS KAREN entry and stop. Restarting it would not be
enough anyway — the Rojo plugin's **Connect** button cannot be clicked by any tool, so Karen has to
press it before the harness can run again.

### Exact clicks for Karen, in order

1. Open a terminal (PowerShell or Git Bash) in `C:\Users\karen\Desktop\driven-hunt`.
2. Run, and leave the window open:

   ```
   rojo serve default.project.json
   ```

   It should print that it is serving on `localhost:34872`. If `rojo` is not found, run
   `rokit install` first.
3. In Roblox Studio, with **Driven Hunt DEV** open in **Edit** mode: the **Plugins** tab → **Rojo** →
   **Connect**.
4. Rojo may show a confirmation dialog listing instances it will remove. It is expected to list
   nothing outside the Rojo-owned containers. **Do not accept anything that names
   `Workspace.Baseplate` or `Workspace.SpawnLocation`** — those are yours and must stay (rule 7).
5. Nothing else. The Builder takes it from there on the next run.

**State of the work.** Branch `task-17-test-area`, code commit `48169db`, pushed. Clean tree.
`selene src`, `selene --config tests/selene.toml tests`, `stylua --check src tests` and
`rojo build -o build/place.rbxl` all pass locally (the same commands CI runs). **Not run:** the
harness, the Reviewer, and the screenshot — all three need Rojo connected. Nothing in this task has
been executed in Studio, so nothing about it is verified beyond lint and build.

**Also found, read-only, before Rojo died** (useful whoever picks this up):
- `Workspace` already holds a default **Baseplate** (`Part`, 2048×16×2048 at y = -8, so its top face
  is at **y = 0**) and a default **SpawnLocation** (12×1×12 at (0, 0.5, 0)). Both anchored, both Studio
  content, both left alone (rule 7, and the dispatch says to report them).
- That means two things the Director should look at once the arena can actually be seen:
  1. **The arena's ground surface is also at y = 0, so it is coplanar with the Baseplate's top over
     the whole 400×400 footprint.** That usually z-fights. I have not seen it — no screenshot was
     possible — so I am not claiming it does or does not.
  2. **Two SpawnLocations** will exist during Play: the default one at the origin and the arena's
     `ArenaSpawn` near the south edge. Roblox picks between them, so spawning will be inconsistent.
- `screen_capture` **is** available over MCP (`capture_id` + `studio_id`, optional `camera_position` /
  `look_at_position`), so rule 5 is satisfiable in Edit mode. The arena is built at server start, so
  it only exists during Play; whether `screen_capture` returns the Play viewport is untested.

**Needs:** Karen's clicks above. Then the Builder reruns the harness, the review loop, and the
screenshot.

### RESOLVED · 2026-09-25

Karen connected on the morning of 2026-09-25: the Director started
`rojo serve default.project.json` and Karen pressed **Connect**. Two `rojo.exe` processes are up,
Studio is on the DEV place in **Edit** mode and answering over MCP, and the harness has run green on
this branch. The first green run was
`[harness] PASS: 24/24 checks @ fbe1d6049da35f75675d532ee77d0c4f6992a235 (clean tree)`;
review rounds 4 and 5 then changed code three more times, and the line that covers the
reviewed commit is
`[harness] PASS: 24/24 checks @ fe21a0df30dc60e4d873157b1bd4821173b36b80 (clean tree)`,
43 tests across five spec files.

**Tasks 17 and 18 have now been executed**, and rule 5 is met for both: three play-time screenshots
were captured through MCP and inspected (see `TASKS.md` rows 17 and 18 for what they showed).
Task 19's and Task 20's documents still cite no harness line, correctly — they contain no code.

**Closed** 2026-09-25.

---


## 2026-09-24 · CLOSED 2026-09-24 · Task 11 round 4 (authorised) returned 5 findings

**Raised by:** Builder, at loop step 5 of Task 11 (branch `task-9-agent-workflow`, PR #4). The
Director's answer to the previous entry says: if round 4 fails, fix it, write an entry and stop. Do
not ask for round 5. That is what this is.

**Result.** Round 4 ran with `DIRECTOR_MAX_ROUNDS=4` (the notice is in the run log and in
`.agent-logs/`), reviewed `d624930`, and returned **5 findings**. All five are fixed in the commit
that carries this entry. **None of them is unreviewed policy or design; four are stale text.**

| # | Finding | Fix |
|---|---|---|
| 1 | Claim 19's "live proof" still described round 3's outcome ("`MAX_ROUNDS` refuses it ... escalated rather than reviewed a fourth time") while this *was* the fourth review | Rewritten: `expected` is 4, checked against `cap = max_rounds()`, and the run was accepted because `DIRECTOR_MAX_ROUNDS=4` raised the cap |
| 2 | Claim 16 still said `TASKS.md` row 16 is "blocked on Karen's map decision"; `8d0d06b` had unblocked it and claim 30 said so | Claim 16 corrected to "unblocked and not next" |
| 3 | **A real bug in `8d0d06b`.** `cmd_review` checked `cap = max_rounds()` but told the agent "round 4 of max `MAX_ROUNDS`" — so this session was told "round 4 of max 3". The `DIRECTOR_MAX_ROUNDS` notice goes only to stdout, which the agent never sees | `go()` now builds the task text from `cap`, and says "(default 3, raised by the Director)" when they differ (`tools/agents.py:317-324`) |
| 4 | `ESCALATE.md:28` still pointed at `tools/agents.py:28-31` and `CLAUDE.md:87-88`; `8d0d06b` moved both, and updated the identical references in `REVIEW_REQUEST.md` but not here | Updated to `tools/agents.py:31-34` and `CLAUDE.md:90-91` |
| 5 | Claim 29 said `ARCH_RESULT.md` is "untouched on this branch"; the evidence shows Task 9's `2958ab5` created it with the Builder-written `NONE` placeholder | Reworded to what is checkable: no audit ran for Task 11, and the file has not changed since `2958ab5` |

**What is now unreviewed.** The fixes above, and only them. Four are text in `REVIEW_REQUEST.md` and
`ESCALATE.md`. One is five lines of `tools/agents.py` (finding 3), added as claim 31a in
`REVIEW_REQUEST.md` and marked there as unreviewed.

**My own record, honestly.** Four of the five findings are the same class of mistake I made in
round 3: I edited some copies of a cross-reference or a claim and missed others. Rounds 3 and 4 have
now both been spent almost entirely on that. The mechanical cause is that `REVIEW_REQUEST.md`
accumulates claims across rounds, each carrying line numbers that every later commit invalidates.

**Options for the Director.**
1. **Merge on the record.** Rounds 1–4 found 15 items; all 15 are fixed. The only unreviewed code is
   finding 3's five lines, which make the Reviewer's own prompt honest and cannot affect the game.
   This breaks rule 10, so it needs a written Director decision.
2. **One more authorised round** (`DIRECTOR_MAX_ROUNDS=5`). Your answer to the last entry says not to
   ask for this, so I am not asking; I list it only because it is the option that ends with a real
   `PASS`. Cost: about $1.50–$2.00.
3. **Drop the accumulated claims.** Rewrite `REVIEW_REQUEST.md` for the final commit only — no
   round-by-round history, no line numbers that a later commit can invalidate — and review that.
   This removes the cause of rounds 3 and 4 but is still a review round.

**Builder's recommendation: option 1.** The residual risk is five lines that only change what the
Reviewer is told about its own round cap. Option 3 is the right shape for future tasks: if you want
it as a standing rule, `REVIEW_REQUEST.md` should describe the final state and cite symbols, not line
numbers. That is a `CLAUDE.md` change and tooling is frozen, so it is yours to decide, not mine.

**Also for the record:** `tools/architect.sh audit` was **not** run for Task 11, per your decision.
Nothing on this branch has been seen by the Architect.

**State.** Code commit `3da8fb8`, clean-tree harness PASS:
`[harness] PASS: 24/24 checks @ 3da8fb89100d8d7357e58ea73df1317051ff9d20 (clean tree)`.
Lint, format and `rojo build` clean. `task-9-agent-workflow` is pushed so PR #4 shows this state.
**`task-9` was NOT merged into `task-10-lint-test-globals`**: your dispatch gated that on a round-4
`PASS`, and there is none. PR #5 therefore still sits on the round-3 state of its base. Say the word
and it is one merge commit.

**Needs:** a Director decision. Nothing here needs Karen.

### DIRECTOR's answer · 2026-09-24

**Option 1: merged on the record.** The Director read the only unreviewed code — the five-line `cap`
fix in `cmd_review`'s `go()` (`tools/agents.py`) — and confirms it is correct. **PR #4 merged as
`a0ccadc`.** PR #5 merged as `7399585`, after the Director merged `main` into `task-10` (`8868e69`);
the only conflicts there were `REVIEW_REQUEST.md` and `REVIEW_RESULT.md`, and Task 10's versions were
kept. No harness run was made on `8868e69`: Task 17's first harness run on `main` covers it.

**Option 3 accepted as a working rule, with no tooling change:** `REVIEW_REQUEST.md` is written
**fresh per task**, not accumulated across rounds, and its claims cite **files and symbols, not line
numbers**. That sentence is now in `CLAUDE.md` loop step 4 (added by Task 17).

Task 11 is **done**.

**Closed** 2026-09-24 by the Director.

---

## 2026-09-24 · CLOSED 2026-09-24 · Task 11 reached round 3; the script refuses a fourth

**Raised by:** Builder, at loop step 5 of Task 11 (branch `task-9-agent-workflow`, PR #4).

**Situation.** Three review rounds ran. Nothing failed three times; each round found different
things, and every finding was fixed.

| Round | Commit reviewed | Verdict | What it found |
|---|---|---|---|
| 1 | `0362ee0` | 6 findings | the merge gate was unsatisfiable; the 3-round rule was self-reported; Task 11's extra scope had no record in the repo; the agent prompt was read from the working tree; the KAREN row never said she does not merge; the Layout table was stale |
| 2 | `20334d5` | 2 findings | both on round 1's fix to the round count: it was called tamper-proof but restoring the `NONE` placeholder would reset it; and `parse_trailer` took the **first** trailer-shaped line, so a Reviewer quoting an older trailer would set the round (a real bug I introduced) |
| 3 | `c36b22e` | 2 findings | both stale sentences in `REVIEW_REQUEST.md` claim 19, which I failed to update when I updated claims 24–25: it still said "the committed `REVIEW_RESULT.md` is round 1" and "which only this script writes". **No finding against the code.** |

All ten findings are fixed and committed. The round-3 two are fixed in the commit that carries this
entry; claim 19 now matches `tools/agents.py:31-34` and `CLAUDE.md:90-91`.

**Why I stopped.** `tools/review.sh` refuses `Round: 4` (`MAX_ROUNDS = 3`, `tools/agents.py:52`), and
the round is now counted from the committed `REVIEW_RESULT.md` trailer, so I cannot reset it — that is
the hardening round 2 asked for, and going around it is exactly what `CLAUDE.md` "What is enforced and
what is policy" forbids. So there is no way for me to obtain a `PASS` on the fixed commit. Per the
stop rule I wrote `ESCALATE.md` and stopped: **no Architect audit was run** (loop step 6 needs a PASS),
and nothing was merged.

**What is and is not verified.**
- Verified: the harness passes 24/24 on a clean tree at every code commit
  (`6378a07`, `9fe442c`, `b32ac5f`, and the final `be9d045`:
  `[harness] PASS: 24/24 checks @ be9d0453ac84a48b5f8c759901e95d239c0c34b6 (clean tree)`); lint,
  format and `rojo build` are clean; the round-count logic was exercised by hand across six states
  (see `REVIEW_REQUEST.md` claim 25).
- `be9d045` is after round 3's review. It adds `ESCALATE.md` to the merge gate's paperwork list in
  `CLAUDE.md` git-workflow step 4, which had omitted it — so this PR would have failed the gate it
  introduces. One line, unreviewed, and listed here because it is.
- Not verified: **there is no Reviewer `PASS` for this branch.** The last verdict is round 3 with two
  findings, and the fix for them is unreviewed.

**Options for the Director.**
1. **Authorise one more round** for this task, and record it. That means either raising `MAX_ROUNDS`
   for this run or accepting a reset, both of which are Director decisions, not mine. Cost: one more
   paid Reviewer session (rounds 1–3 cost $1.63, $2.16, $1.91).
2. **Accept the branch without a round-4 PASS**, on the record above: round 3 found nothing against
   the code, and its two findings were documentation errors in `REVIEW_REQUEST.md` that are now fixed.
   This breaks rule 10, so it has to be a written Director decision.
3. **Split Task 11** as round-1 finding 3 suggested: the Task 9 review in one PR, the merge-policy
   and `NEEDS KAREN` edits in another. A smaller change would review faster, but it re-runs all three
   rounds on two branches.

**Builder's recommendation: option 1.** The change is small and the outstanding delta is two sentences
in a review request. A fourth round confirms them and gives the branch a real `PASS`, which options 2
and 3 do not (2 skips it; 3 pays for six rounds).

**Also needed:** a standing decision on `MAX_ROUNDS`. Round 3 spent a whole paid session on stale text
in the Builder's own document. If the rule is meant to stop *repeated failure on the same item*, the
script should count that, not total rounds — but changing it is a workflow change and belongs in a
task of its own, not here.

**Needs:** a Director decision. Nothing here needs Karen.

### DIRECTOR's answer · 2026-09-24

**Option 1: one more review round (round 4) is authorised, for Task 11 only.**

- **Mechanism, kept minimal.** `tools/agents.py` reads an optional environment variable
  `DIRECTOR_MAX_ROUNDS` (integer, default `MAX_ROUNDS` = 3). It may be set **only** when this file
  records a Director authorisation for that task and that round. Round 4 of Task 11 is that
  authorisation. The change itself goes into the round-4 review.
- **Standing decision.** `MAX_ROUNDS` stays 3. The Director may authorise **one** extra round when the
  last round's findings were documentation-only; otherwise escalate as now. The round counting is
  **not** to be reworked — tooling is frozen (`ROADMAP.md` speed rule 1). This closes the Builder's
  "Also needed" question at the end of the entry: no, the script keeps counting total rounds.
- **No Architect audit for Task 11.** New speed rule (`ROADMAP.md` on `main`, PR #7): audits run every
  ~5 tasks, not per task. Loop step 6 is skipped for this task by Director decision, and `TASKS.md`
  row 11 records that.
- **Accepted:** the merge gate naming the reviewed **code commit** and allowing only loop paperwork
  after it. Good call.
- If round 4 fails: fix it, write an `ESCALATE.md` entry and stop. Do **not** ask for round 5.

**Closed** 2026-09-24 by the Director.

---

## 2026-09-24 · CLOSED 2026-09-24 · Audit-002 must-fix items are outside Task 10's scope

**Raised by:** Builder, at loop step 6 of Task 10 (branch `task-10-lint-test-globals`, head
`24fd22a` + the audit commit).

**Situation.** Task 10 (audit-001 L5) passed review in 2 rounds (`REVIEW_RESULT.md`: PASS on round 2).
The one-per-task Architect audit (`docs/architecture/audit-002.md`) returned 5 must-fix items
(`ARCH_RESULT.md`). I checked the evidence for each and believe all 5 are **valid**, but **none is in
Task 10's change**:

| # | Must-fix (audit-002) | Where it belongs | Decision needed? |
|---|---|---|---|
| 1 | Typed property values (Vector3, CFrame, Color3…) fail as "cannot compare", so no positioned geometry can come from disk | harness (`tools/studio_mcp.py`), before the first grey-box geometry | **Yes, partly design.** Either support typed values in the harness, or decide that geometry lives elsewhere (Workspace built in Studio; templates as `.model.json` with typed values). The Architect owns the structure; this probably needs `tools/architect.sh design geometry-on-disk` first |
| 2 | The unmanaged scan checks only scripts, so a Studio-made non-script instance in a Rojo-owned container passes, then vanishes at the next Connect | harness | No: Builder work |
| 3 | `tools/agents.py` (the four-agent gate) has no research note (rules 1, 2, 9) | Task 9 | No: Builder work |
| 4 | The Architect audits blind: earlier audits are not on this branch (audit-001 is only on PR #2) and are not in its evidence | Task 9 (`tools/agents.py` evidence), and PR #2's merge order | No: Builder work, plus merge order |
| 5 | `ARCH_RESULT.md`/`REVIEW_RESULT.md` got a Builder-written `NONE` placeholder, although only the scripts may write them; nothing ties a verdict to the merged commit; a dirty-tree audit writes an unqualified verdict | Task 9 | No: Builder work |

**The conflict.** CLAUDE.md's loop says "must-fix → fix, back to 4". Rule 4 says "one task per round, nothing
extra", and PROJECT_CONTEXT.md warns that big multi-item rounds hid failures. Folding 5 unrelated fixes
into Task 10 would make it a multi-item round about the harness and the workflow, not about L5. Choosing
between those two rules is a scope decision, so it is the Director's.

**Builder's proposal.**
- Close Task 10 as done (its own change passed review).
- Queue audit-002 must-fix items as five separate small tasks, 11–15 in `TASKS.md`, each through the full
  loop, **all before any game code**. Suggested order: 5, 4, 3 (they fix the workflow itself), then
  2, then 1 (after an Architect design for geometry on disk).
- Merge order suggestion: PR #2 (audit-001) early, so every later branch has `docs/architecture/`.

**Needs:** a Director decision (and Karen, if item 1's geometry question touches how she wants to
build the map).

### DIRECTOR's answer · 2026-09-24

Accepted as proposed, with one task added in front. Task 10 is **closed as done**: its own change
passed review. The five must-fix items become their own tasks, each through the full loop, all before
any game code, in this order (see `TASKS.md`):

| # | Task |
|---|---|
| 11 | Review Task 9 itself through the loop, and fix the findings |
| 12 | audit-002 #5: only the scripts write the verdict files; each verdict is tied to a commit; a dirty-tree audit verdict is marked as such |
| 13 | audit-002 #4: the Architect sees earlier audits |
| 14 | audit-002 #3: research note for `tools/agents.py` |
| 15 | audit-002 #2: detect Studio-made **non-script** instances in Rojo-owned containers |
| 16 | audit-002 #1: typed property values. **BLOCKED** on Karen's map decision (build the map in Studio, or everything on disk). Architect design first |

**Standing decision for every future audit.** A must-fix item **outside** the current task's change is
queued as its own task in `TASKS.md` and listed in the Builder's report. It is not an escalation, and it
is not fixed in the current task. Must-fix items **inside** the change are fixed as the loop says.

**Closed** 2026-09-24 by the Director. No open escalations remain.

#### Task 11's dispatch, verbatim (transcribed by the Builder, 2026-09-24)

The Director dispatched Task 11 in the same message, outside the repo. Its scope is more than
"review Task 9", so it is recorded here rather than inferred from a Builder-written `TASKS.md` row
(review round 1, finding 3):

> TASK 11: Task 9 (the four-agent workflow, PR #4) never went through the loop itself. Do that now.
> 1. Work on branch task-9-agent-workflow (PR #4). First merge origin/main into it (a merge, not a
>    rebase; no force pushes) so it is current with main.
> 2. Also in this task, update CLAUDE.md to the new policy: the Director (agent) retargets and merges
>    PRs after Reviewer PASS on the PR head, green CI and a clean-tree harness PASS naming that
>    commit; Karen no longer merges; the Builder still never merges. Update the KAREN and DIRECTOR
>    rows and the git-workflow section to match. Also add the stop case "a human action is needed
>    (Rojo Connect, Studio MCP toggle, anything only Karen can click)": write it in ESCALATE.md headed
>    "NEEDS KAREN" with the exact clicks, then stop.
> 3. Run the loop on the whole Task 9 change (git diff origin/main...HEAD) plus the edits above:
>    REVIEW_REQUEST.md, tools/review.sh, fix, repeat until PASS. Then one Architect audit; handle its
>    items per the standing decision above.
> 4. Push task-9-agent-workflow. Then merge task-9-agent-workflow into task-10-lint-test-globals
>    (merge, no rebase) and push, so PR #5 stays current. Put the ESCALATE.md answer and TASKS.md rows
>    on whichever branch lands first (task-9), not only on task-10.
> 5. If Studio is not in Edit mode, Rojo is not connected, or the MCP server is off, and you cannot
>    fix it yourself: NEEDS KAREN entry, stop.

**Builder's note on item 2.** "Reviewer PASS on the PR head" as written cannot hold: loop steps 5 and
6 commit `REVIEW_RESULT.md`, `ARCH_RESULT.md` and the audit document *after* the reviewed commit, so
the head always moves past it (review round 1, finding 1). The gate in `CLAUDE.md` git-workflow step 4
therefore names the **code commit** and bounds what may follow it (paperwork only). Same intent,
satisfiable. Flagged to the Director in the Task 11 report.
