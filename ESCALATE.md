# Escalations

For the Director and Karen. The Builder (or any agent) writes here and stops when:
- the same item has failed 3 review rounds
- it believes the Reviewer or Architect is factually wrong
- a design, feel or scope decision is needed
- **a human action is needed** (Rojo **Connect**, the Studio MCP toggle, Studio not in Edit mode,
  anything only Karen can click). Head that entry **`NEEDS KAREN`** and list the exact clicks.

Newest first. The Director or Karen answers under each entry, and the entry is closed with a date.

---
## 2026-09-25 · CLOSED 2026-09-25 · NEEDS KAREN · Task 34: the 2-player harness mode needs one click to be exercised

**Raised by:** Builder, Task 34 (branch `task-34-harness-2p`). **Nothing is blocked**: the mode is
built, the one-player harness is green with it, and the 2-player spec runs in both modes. What is
missing is the only thing no tool here can do.

**Why it needs you.** StudioMCP's `start_stop_play` takes `is_start` and `studio_id` and **nothing
else** -- there is no player count anywhere in its tool schema -- so the harness cannot start a
Clients-and-Servers test. Everything after the click is the mode's own work.

**The clicks, and the one command, in this order:**

1. In a terminal in the repo folder, start the mode FIRST:

   ```
   python tools/studio_mcp.py test2
   ```

   It writes the gate token, prints these clicks, and then waits up to 180 s for the test windows.

2. In Studio, on **Driven Hunt DEV**: **Test** tab -> **Clients and Servers** -> **Players: 2** ->
   **Start**, within the **180 s** the mode waits. It no longer races a token: the disk token is
   cleared before the click and a fresh one is written into the running server afterwards, which is
   why there is no 120-second rule here any more.
3. Leave the three windows alone. The mode reads them: it finds which is the server and which are
   the clients, asks each client which team it is on, replays the input scenarios into the
   **shooter's** client, and collects all three reports.
4. When it says so, press **Cleanup** in the Test tab.
5. Paste the final `[harness2] ...` line under this entry, and the `[match_teams]` line from the
   server output just above it (it prints each player's name and team).

**CLOSED 2026-09-25.** The Director can now start and end the session himself
(`driven-hunt-runs/studio-key.ps1 F7` / `EndSession`), so this needs nobody's hands. Nine runs were
made; the last is the confirmation at `166bd33`:

```
[harness2] PASS: 28/28 checks @ 166bd334e576a84f324c5ca093e56af22ccb286b (clean tree)
[match_teams] 2 player(s): Player1=Shooters, Player2=Drivers | drivers=1 shooters=1 phase=Running
```

Server 234 passed / 0 failed, the shooter's client 58 / 0, the driver's report printed as an
observation. The runs also found the game bug Task 34 fixed: with two players the Shooter carried no
gun at all, for a whole drive.

**What the answer decides.** If it passes, ROADMAP 1.6 is closed and a two-player check is one
command away from then on. If a report is empty, the token window was missed -- just run it again.
If the studios are found but the classification is wrong, that is a real finding and the mode prints
what it saw.

---
## 2026-09-25 · CLOSED 2026-09-25 · Task 30: is a 2-player harness run possible at all?

**ANSWERED — yes, it is possible.** Karen ran Test -> Clients and Servers with 2 players and
`python tools/studio_mcp.py studios` listed **FOUR** studios: the DEV edit Studio
("Driven Hunt DEV (placeId: 136410205938347)") plus three unnamed ones - the local server and
the two clients. So the extra Studio processes DO register with StudioMCP and every tool takes a
`studio_id`, which is the route a 2-player harness would use. The Director has queued
**"harness runs specs with 2 players"** as its own task (`TASKS.md` row 33); it is not part of
Task 32. Reported by the Director, 2026-09-25.

**Raised by:** Builder, Task 30 (branch `task-30-harness-multiplayer`). **Nothing is blocked**: the
task is complete without this, and the answer only decides whether ROADMAP 1.6's automation is worth
a future task or should be closed.

**What is already known** (measured, `docs/research/2026-09-24-toolchain.md`, Task 30 addendum):
StudioMCP's `start_stop_play` takes no player count, and `execute_luau`'s `datamodel_type` is an enum
of `Edit` / `Client` / `Server` with no index — so one Studio cannot host a second addressable
client. **But every tool takes a `studio_id`**, and `list_roblox_studios` says "several instances are
commonly open at once". A local multi-client test starts extra Studio *processes*. If they register
with StudioMCP, a 2-player harness is possible; if they do not, 1.6's automation is closed for good.

**The exact clicks, once:**

1. In Studio, on **Driven Hunt DEV**, open the **Test** tab.
2. In the **Clients and Servers** group, set **Players** to **2**, leave the rest alone, and press
   **Start**. Two extra client windows open.
3. While they are running, in a terminal in the repository folder (`<repo>`), run exactly:

   ```
   python tools/studio_mcp.py studios
   ```

4. Paste the output under this entry. One line of JSON is the whole answer: if it lists **three or
   more** studios, a 2-player harness is feasible and deserves a task; if it lists **one**, it is not
   possible with this tool and `ROADMAP.md` 1.6 should say so.
5. Press **Cleanup** in the Test tab to close the extra windows.

**Note:** the harness's own tests do not run during that check, and nothing needs to be committed.
The MCP server must be on (Studio → Assistant settings), which it already is.

---
## 2026-09-25 · CLOSED 2026-09-25 · Task 22 cannot be reviewed: the round counter has no task boundary

**Raised by:** Builder, at loop step 5 of Task 22 (branch `task-22-playtest-ready`, code commit
`d265cab396b2a23b61c620fe9e6594f23b925211`, harness `PASS: 24/24 ... (clean tree)` on it).

**What happened.** `powershell -ExecutionPolicy Bypass -File tools/review.ps1` refused, verbatim:

```
[agents] REFUSED: `Round: 1` in REVIEW_REQUEST.md, but the committed REVIEW_RESULT.md is round 5
(FINDINGS), so this run must be `Round: 6`. The round is counted from the verdict file, not from the
request, so it cannot be raised or skipped here.
```

`Round: 6` would then hit the next check, `round 6 > 3: stop rule`.

**Why it is stuck.** `tools/agents.py` `cmd_review` computes
`expected = 1 if prev_rnd is None or prev_verdict == "PASS" else prev_rnd + 1`. The count restarts
only after a **PASS**. Tasks 17 and 18 ended on `FINDINGS` at round 5 and were merged anyway by
Director decision (the escalation above), so the verdict file on `main` says round 5 FINDINGS. Every
task branched from `main` from now on inherits that: round 1 is refused as too low and round 6 as too
high. This is not specific to Task 22 — **no task can be reviewed until it is resolved.**

CLAUDE.md counts rounds **per task** ("The loop, for every task ... increment `Round:`"); the script
counts them globally. That gap is the bug (rule 6: a harness fault is a bug and gets reported).

**What I did not do.** I did not touch `tools/agents.py`, and I did not set `DIRECTOR_MAX_ROUNDS`.
The Builder does not edit the gate that constrains it, and CLAUDE.md allows that variable only when
this file records the Director's authorisation for that task and that round. So Task 22 is built,
harness-green and pushed, and **unreviewed**.

**What the Director can choose.**
1. **One-off:** authorise here, for Task 22 round 6 only, and I re-run with
   `DIRECTOR_MAX_ROUNDS=6` and `Round: 6` in `REVIEW_REQUEST.md`. Unblocks this task; every later
   task hits the same wall one round higher.
2. **Fix the counter** (a Builder task of its own, reviewed like any other): restart the count at 1
   when the commit named in the committed `REVIEW_RESULT.md` trailer is an **ancestor of this
   request's `Base:`** — that is, when the verdict belongs to work already merged into the base this
   task branches from. It cannot be gamed by the Builder: resetting would require getting the
   failing commit merged first, and only the Director merges.
3. **Accept Task 22 unreviewed** on the harness evidence and the diff (one config constant plus
   comments and docs), and let the fix land with the next task.

My recommendation is 2, with 1 to unblock Task 22 in the same breath.

**Director's answer, 2026-09-25 (transcribed verbatim by the Builder from the dispatch):**

> DIRECTOR DECISION on the ESCALATE.md entry (review gate refuses round 1 after Tasks 17+18 merged on
> FINDINGS):
> - For Task 22 only: DIRECTOR_MAX_ROUNDS=6 and `Round: 6` are authorised (one review round). Record
>   this under the entry.
> - The real fix (per-task review files, round count per task) is Task 21, next. Do not change
>   tools/agents.py in Task 22.
> - Accepted: ServerStorage has a $path, so the Archive folder will go at the next Connect;
>   backups/2026-09-25_workspace-defaults.md is the rule-7 record. Good catch.
>
> Run the one review round now (policy: only real defects block; notes do not). If only notes: record
> PASS-with-notes as the Director's call in ESCALATE.md, close the entry, push. If a real defect: fix,
> harness, and with DIRECTOR_MAX_ROUNDS=7 one more round, then stop regardless.

**So:** this is the authorisation `tools/agents.py` requires, for **Task 22, round 6** (which is Task
22's first round). `DIRECTOR_MAX_ROUNDS` is set in the environment for that run only and is never
committed. `tools/agents.py` is untouched; the counter fix is Task 21. Entry **closed**; the outcome
of the round is recorded below.

**Outcome of the authorised round (round 6 = Task 22's round 1), 2026-09-25.** `REVIEW_RESULT.md`
line 1 is not `PASS`: the Reviewer returned **4 findings**, and **none of them is blocking under the
Director's policy for this round** (only a finding that makes the game, a test, an owner boundary or
security wrong blocks). All four are about documents:

| # | What | Disposition |
|---|---|---|
| 1 | `docs/research/2026-09-24-boar-ai.md` §4 still says, in the present tense, that the plate is coplanar with the default `Baseplate`; and claim 9 named 2 of the 3 stale mentions in `docs/design/boar-ai.md` | **Accurate. Not fixed here** — the research note is not on the merge gate's list of files that may change after the code commit (git workflow step 4), so fixing it now would put the harness PASS and this review out of date. Queued below |
| 2 | `TASKS.md` row 17 still poses "delete the Baseplate?" as Karen's open call and says two SpawnLocations exist | **Accurate, and not the Builder's row.** The Reviewer's own alternative applies: the Builder may write only its current task's status row, so row 17 is the Director's to close or strike through |
| 3 | `backups/2026-09-25_workspace-defaults.md` claims "every property ... recreated from it alone", but records the `Texture` and `Decal` children as counts only | **Accurate. Not fixed here** (same gate reason). The missing data is preserved verbatim below so it cannot be lost at Karen's next Connect, when Rojo removes `ServerStorage.Archive` |
| 4 | The request had no screenshot description a reviewer could read, for a change whose whole purpose is visual (rule 5) | **Fixed**: `REVIEW_REQUEST.md` now carries a `## Screenshots, inspected` section with all five views. `REVIEW_REQUEST.md` is on the gate's list, so this changes nothing about the evidence |

**The data finding 3 asks for, read from the place on 2026-09-25 before it can be lost** (both
children are still in `ServerStorage.Archive`; Rojo removes that folder at the next Connect):

- `Baseplate.Texture` — `Texture` `rbxassetid://6372755229`, `Face` `Top`, `StudsPerTileU` 8,
  `StudsPerTileV` 8, `OffsetStudsU` 0, `OffsetStudsV` 0, `Transparency` 0.8, `Color3` `0, 0, 0`,
  `ZIndex` 1.
- `SpawnLocation.Decal` — `Texture` `rbxasset://textures/SpawnLocation.png`, `Face` `Top`,
  `Transparency` 0, `Color3` `1, 1, 1`, `ZIndex` 1.

**Queued for the next task** (Task 21, or wherever the Director puts them): findings 1 and 3 — correct
the research note's §4 sentence, name all three stale mentions in the Architect design for its next
regeneration, and fold the two child-property lines above into
`backups/2026-09-25_workspace-defaults.md`, retitling that section to what it is. Finding 2 is the
Director's row 17.

There is **no round 7**: the Director authorised one more round only if a real defect appeared, and
none did.



---
## 2026-09-25 · CLOSED 2026-09-25 · Tasks 17+18: round 5 was the last authorised round, and it found 4 things

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

**Director decision 2026-09-25:** merged on the record. The Director read the only unreviewed code change after round 5 (`Boar.defaultWorld`: records "success: no waypoints" in the path-problem counter and returns nil, as before); it changes diagnostics, not behaviour. The harness PASS at `b6cf3de` stands.

## 2026-09-25 · CLOSED 2026-09-25 · FOR THE DIRECTOR · play-time `screen_capture` works; `TASKS.md` row 7 is wrong

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

**Director decision 2026-09-25:** agreed. TASKS.md row 7 is updated: play-time capture works; the remaining work is making `tools/studio_mcp.py` keep image blocks so the harness can save captures.

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
## 2026-09-24 · CLOSED 2026-09-24 · Task 20 round 2 returned 5 findings; the Director's limit was two rounds

**Director decision (2026-09-24 ~23:50):** option 1, accepted on the record. The five unreviewed fixes are wording and source labelling; none changes a conclusion or a number. The Architect reads the note fresh when it designs the map generator. Merged by the Director with main (paperwork conflicts resolved by keeping both sides).

**Raised by:** Builder, at loop step 5 of Task 20 (branch `task-20-map-research`, code commit
`6cd9a84`). Documents only.

**Result.** Two review rounds, 11 findings, all fixed. Round 2's five are fixed in the commit that
carries this entry, and **they are unreviewed**: the dispatch said "max 2 rounds", and unlike
`MAX_ROUNDS` that is a Director instruction rather than something the script enforces, so I have
stopped rather than run a third.

| Round | Commit | Findings | What they were |
|---|---|---|---|
| 1 | `fba85c8` | 6 | the seed/determinism story did not work (`math.noise` has no seed, so seeding a `Random` answered nothing); the maths library was a source in everything but name; three broken section references; a false "one-to-one" claim; `ESCALATE.md` in the change but in no claim; the Director's dispatch paraphrased rather than transcribed |
| 2 | `41e9069` | 5 | **a new broken section reference inside my fix for the broken section references**; the source count corrected in one place and not two others; the "two table rows" summary corrected in one copy and not the other; the decisive finding resting on two unnamed sources (the MCP tool list, the community threads); the mesh limits presented as first-party when §9 itself calls them community/vendor figures |

**What this says about the work.** Round 1's finding 1 was the valuable one — it caught a real muddle
that would have been copied into a design, not a citation slip. But the pattern across Tasks 19 and
20 is now unmistakable: **I fix the instance I am shown rather than the class.** Round 2 found that
two of my round-1 fixes were themselves wrong in exactly the way the originals were. The one thing
that worked was mechanical: for round 2 I audited *every* section reference in the file against the
actual headings programmatically — 13 headings, zero unresolved — instead of hand-fixing the three I
was handed. That check should have existed in round 1.

**State.** Code commit `6cd9a84`, clean tree. The note has 13 sources, every section reference
resolves, the Director's dispatch is transcribed verbatim in `TASKS.md`, and the `NEEDS KAREN` entry
for `rojo serve` is on this branch. Lint, format and `rojo build` pass — unchanged by this task,
which touches no code. **No harness run** (nothing executes; Rojo is down), **no screenshot**
(nothing visual), **no Architect design** (the dispatch was research only).

**Options for the Director.**
1. **Accept on the record.** The five unreviewed fixes are: one section reference, one source count
   in two places, one summary sentence, two sources promoted from prose to numbered entries, and one
   "these figures are community, not first-party" label. None changes a conclusion or a number; the
   note's findings and targets are the same before and after.
2. **One authorised round 3.** ~$1.60. It would confirm the fixes, and on this task's record it
   would probably find something — rounds 1 and 2 both did.
3. **Regenerate nothing.** There is no design to regenerate here; the Architect was not run, by
   dispatch.

**Builder's recommendation: option 1, with one caveat.** The note is input to a future
`tools/architect.sh design map-generator`, not something built from directly, and the Architect will
read it with fresh eyes. The caveat is that I would not describe this note as *verified* — see the
long "Could not verify" list in `REVIEW_REQUEST.md`, of which the largest items are that
`math.noise`'s stability is undocumented and unmeasured, that `CollectionService` tag persistence is
unconfirmed, and that every number in the targets table is arithmetic rather than measurement.

**Needs:** a Director decision. Nothing here needs Karen beyond the Connect clicks already requested
in the `NEEDS KAREN` entry below.
## 2026-09-24 · CLOSED 2026-09-24 · Task 19 round 2: a Reviewer finding I believe is factually
wrong, and a contradiction I may not fix myself

**Raised by:** Builder, at loop step 5 of Task 19 (branch `task-19-shotgun-design`, code commit
`0f5627f`). Two separate things, both from review round 2 — the Director's limit for this task.

### 1. Round 2's finding 1 is factually wrong, and the evidence is reproducible

The finding says my addendum's `docs/PROJECT_CONTEXT.md` line numbers "are all wrong", and that of the
design's four citations only `:592` is "genuinely wrong".

Checked three independent ways at commit `009c20e`, on a clean tree — `awk` over the working tree,
`grep -n` over the working tree, and `grep -n` over `git show HEAD:docs/PROJECT_CONTEXT.md`. All three
agree:

| Quote | Actually at | Round 2 says | Design cites | Verdict on the design |
|---|---|---|---|---|
| "Two systems wrote the creature's position" | **34** | 36 | `:36` | wrong |
| "Three scripts set the mouse cursor" | **32** | 34 | `:33-34` | wrong |
| "one predicate answered two unrelated questions" | **32-33** | 34-35 | `:34-35` | wrong |
| "a visibility audit ignored parent visibility …" | **30-31** | 32-33 | `:30-31` | **correct** |

Round 2's numbers are uniformly **two lines later** than the file reads, which inverts its conclusion:
`:592` is the **only correct** design citation, not the only wrong one. My addendum's numbers
(`:34`, `:32`, `:32-34`, `:29-31`) were correct or contained the quote; they are now exact.

I cannot explain the offset. The Reviewer reads a `git worktree` of the same commit, which should be
byte-identical, and `docs/PROJECT_CONTEXT.md` is 48 lines of ASCII with no BOM and has not been
touched by this branch. **If the Reviewer's worktree really does differ from the commit, that is a
harness fault and far more important than this task** (rule 6). Someone with Studio down but git
working should run `git show 009c20e:docs/PROJECT_CONTEXT.md | grep -n` and compare.

Round 1's finding 10 was wrong the same way on two of its four replacements, and **I copied it into
the addendum instead of checking it** — which is how a wrong correction got two rounds of life. That
is my error, and it is the reason `CLAUDE.md` has the "you believe a finding is factually wrong" stop
rule at all.

### 2. The note and the design contradict each other on the slug cone, and I may not fix it

`docs/design/shotgun.md` §9: "Slug cone | 0.16° **half-angle**". The note: "**0.16° full cone**
(0.08° half-angle)", with the arithmetic. The buckshot row beside it in §9 is a **full** angle, and
§11.1 specs the pattern as "within the configured **half-angle** of the aim". So a `ShotgunConfig`
built from §9 as written produces a cone at 2× or 0.5×. Round 2's finding 4 is right that this ships
two documents disagreeing on a load-bearing number.

Rule 3 gives `docs/design/` and `ARCH_RESULT.md` to the Architect and the Builder never edits them, so
I have recorded all three design defects in `TASKS.md` row 19 and in the note's addendum rather than
touching the files. Round 2 asked for either a regeneration or this entry; this is the entry.

**Options for the Director.**
1. **Re-run `tools/architect.ps1 design shotgun`** on the corrected note. ~$2 and a few minutes. It
   would fix all three defects at once and re-derive its own citations — but it returns an
   **unreviewed** design, and this task has no rounds left to check it.
2. **Accept the documents as they are**, with the three defects recorded in `TASKS.md` row 19, and
   regenerate the design when the boar branches are merged — which it needs anyway, because
   `ARCH_RESULT.md` item 3 says the Architect could not see them and therefore cannot guarantee one
   writer for the damage entry point.
3. Waive the two-round limit for one more review round.

**Builder's recommendation: option 2.** The design has to be regenerated once the boar work is
visible regardless, and doing it twice costs two sessions to fix three citation-level defects that
are already written down where the next Builder will read them. Nothing is blocked in the meantime:
Task 1.4's code is blocked on Director decisions 13.1–13.3 anyway.

**Needs:** a Director decision on 2, and someone to sanity-check 1 — if the Reviewer's worktree
differs from the commit, that is a harness bug.

### DIRECTOR's answer · 2026-09-24

**1. The Builder is right about the line numbers.** The Director checked
`git show 009c20e:docs/PROJECT_CONTEXT.md`: the quotes are at **34, 32, 32-33 and 30-31**, exactly as
the Builder reported. **Round 2's finding 1 was wrong by two lines**, and not fixing it was correct.
Why the Reviewer's numbers were off — an evidence copy that differs from the commit, or a miscount —
is logged as a **before release** item in `TASKS.md`. The working rule already covers the practical
risk: `REVIEW_REQUEST.md` cites **files and symbols, not line numbers** (`CLAUDE.md` loop step 4).

**2. Task 19 is accepted on the record**, as documents only. **The shotgun design will be
REGENERATED by the Architect once Tasks 17 and 18 are merged**, and that regeneration fixes the
half-angle / full-cone unit defect and names the damage entry point owner. **Until then the design is
not built from.** So the Builder's recommendation (option 2) is taken, and the three design defects
recorded in `TASKS.md` row 19 are the handover list for that regeneration.

**3. The Architect's three blocking decisions are answered:**
- **(a) Task 6 lands BEFORE the shotgun build. No waiver.** The smallest version is the one the
  design proposes: one scenario, one key, one client spec.
- **(b) Accepted:** the shotgun first ships on the **default camera, with no ADS and no viewmodel**.
  Third-person-to-first-person aim comes as **its own camera task with its own design, right after**,
  because Karen wants it in v1. So the design's §3.3 cut stands, and it is a sequencing decision, not
  a scope cut.
- **(c) The damage entry point owner is decided in the regenerated design** (see 2).

**4. Karen's five feel questions keep their defaults** until her playtest.

**Closed** 2026-09-24 by the Director.

**Still open, and not part of this entry:** the `NEEDS KAREN · rojo serve is down` entry below.
Karen has not connected yet, so Tasks 17, 18 and 19 still have no harness run.

---

## 2026-09-24 · CLOSED 2026-09-25 · NEEDS KAREN · `rojo serve` is down; no task can be harness-tested

**Raised by:** Builder, during Task 20 (branch `task-20-map-research`).

`rojo serve` crashed on 2026-09-24 during Task 17 and has not run since: no `rojo.exe`, nothing
listening on port 34872. It is the known Rojo 7.7.0 watched-file panic, and on that occasion **a
large branch switch alone was enough** — `git switch main && git pull` across 59 commits, no test, no
**Raised by:** Builder, during Task 19 (branch `task-19-shotgun-design`).

`rojo serve` crashed on 2026-09-24 during Task 17 and has not run since: no `rojo.exe`, nothing
listening on port 34872. It is the known Rojo 7.7.0 watched-file panic, and on that occasion **a large
branch switch alone was enough** — `git switch main && git pull` across 59 commits, no test, no
deletion. Studio itself is still open on the DEV place in **Edit** mode and its MCP server still
answers; only Rojo is down.

Per the overnight rules I have not restarted it, and restarting alone would not be enough: the Rojo
plugin's **Connect** button cannot be clicked by any tool.

**Why this entry is repeated on this branch.** The same entry exists on `task-17-test-area`,
`task-18-boar-ai` and `task-19-shotgun-design`, but none of those is merged, so anything cut from
`main` — including this branch — has no record of why no task can produce a harness line. Task 19's
review round 1 caught me citing it from a branch where it did not exist. **The claim and the record
have to live in the same place**, so it is written here too. When the branches merge, these copies
collapse into one.

### Exact clicks for Karen, in order

1. Open a terminal (PowerShell or Git Bash) in the repository folder
   (`<repo>`).
**This entry exists on this branch because it was missing here.** Tasks 17 and 18 carry the same
entry, but they are on unmerged branches, so on `main` and on anything cut from it there was no record
of why no task has a harness line — which review round 1 of this task caught (finding 1). The harness
claim and the record must live in the same place.

### Exact clicks for Karen, in order

1. Open a terminal (PowerShell or Git Bash) in the repository folder (`<repo>`).
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

**Closed by the Director 2026-09-25:** same outage as the Task 17 entry; Karen pressed Connect in the morning.

## 2026-09-24 · CLOSED 2026-09-24 · Task 11 round 4 (authorised) returned 5 findings
3. In Roblox Studio, with **Driven Hunt DEV** open in **Edit** mode: the **Plugins** tab → **Rojo**
   → **Connect**.
4. Rojo may show a confirmation dialog listing instances it will remove. It should name nothing
   outside the Rojo-owned containers. **Do not accept anything that names `Workspace.Baseplate` or
   `Workspace.SpawnLocation`** — those are yours and must stay (rule 7).
5. Nothing else.

**What is waiting on those clicks.** Task 17 (test arena) and Task 18 (boar AI) have never been
executed at all — no harness run, no screenshot. Tasks 19 and 20 are documents only and need nothing
from Studio, but they cannot cite a harness line either, which is why both say N/A and point here.
executed at all — no harness run, no screenshot. Task 19 is documents only and needs nothing from
Studio, but it cannot cite a harness line either, which is why it says N/A and points here.

**Needs:** Karen's clicks. Nothing here needs the Director.

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
