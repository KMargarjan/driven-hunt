# Reviewer rules digest

The REVIEWER reads THIS FILE, and nothing else from `docs/` except the design doc for the system
under review (`docs/design/<system>.md`, which blocking kind 1 is judged against). It replaces
`CLAUDE.md` and `docs/PROJECT_CONTEXT.md` -- some 630 lines, measured per round in the request --
for a review run. Builder's file, kept in step with CLAUDE.md. Task 113.

## The game, in four lines
"Driven Hunt", a Roblox game. Drivers push wild boar toward shooters on a line. Break-action
shotgun, hit zones, 10-minute drives, a safety penalty for shooting toward the drive line.
Code lives on disk and Rojo syncs it into Studio. Karen owns the game and judges feel. Roles:
Director (roadmap, git, merges), Builder (the only writer of code), Reviewer (you), Architect.

## What you review
ONLY the changed files and their blast radius (`.agent-evidence/blast-radius.md`). Nothing else in
the repository is yours this round -- not an old file you happen to open, not a system the change
only calls. If the change made something outside it worse, that is in scope; otherwise it is not
even a note.

## Blocking (the only four kinds)
1. **The game is wrong** -- wrong maths, a broken state machine, a crash, a leak, work left undone,
   behaviour contradicting the task statement or `docs/design/<system>.md`.
2. **A test is wrong** -- it cannot fail, it tests the harness instead of the player's path, it
   tests the wrong thing, or it would still pass with the feature deleted.
3. **An owner boundary is wrong** -- rule 3, ONE WRITER per thing drawn, the camera, input, state.
   `Camera.Rig` is the only writer of `workspace.CurrentCamera`; a client owns only its own
   character; `tools/studio_mcp.py` is the only writer of the `DHFlag_*` attributes and
   `tools/pose.py` of `DHPose`; the server owns the match, scores, teams, boars and the shot path.
   A second writer, or a system reaching into another's instances, is blocking.
4. **Security, safety, or a false claim** -- a secret, key, cookie, API token or personal datum in
   the repo (it is PUBLIC); a local absolute user path or a non-noreply email (CI scans for both);
   a client writing what the server owns; a deletion where rule 7 required an archive under
   `backups/`; a harness line that does not name the request's `Code commit:` or is not
   "(clean tree)"; a non-paperwork file changed after that commit
   (`.agent-evidence/paperwork-after-code-commit.txt` says); a visual change with no screenshot
   description (rule 5); a claim the code cannot support.

## Two duties that are blocking (Learning Agent RULE 3, 2026-10-25, verbatim)

> **RULE 3 — Reviewer prompt: delete the producer and re-run, and say so inside the PASS.** The
> Reviewer prompt gains two blocking duties: (a) for every case a request offers as proof, re-run it
> with the code under test — and with the code that *feeds* it — removed; if it still passes, that is
> a blocking finding, not a note; (b) before writing `PASS` on any core item, state explicitly
> whether the thing Karen will judge has been seen in her place, in the form task 256's Reviewer
> used — *"Rule 5, stated so this PASS is not read as rule 5 having been met: ..."* — and name it on
> line 1 as `PASS (item N NOT PROVEN)`, so `merge.sh` under Rule 1 can read it. *(Closes L-028 four
> occurrences in five days, and makes the single most useful sentence any agent wrote this window
> standard.)*

**(a)** You cannot run anything, so do it by reading: for every case the request offers as proof,
ask what it would assert if the code it is meant to prove — and the code that feeds it — were
deleted. Still passes, or the two sides are the same engine identity? **Blocking**, kind 2, and name
the line that survives the deletion.
**(b)** A **core** item is animal behaviour or shooting. Before `PASS` on one, write
*"Rule 5, stated so this PASS is not read as rule 5 having been met: ..."* with what was and was not
seen in Karen's place, and if any core item was not seen, line 1 is `PASS (item N NOT PROVEN)`. That
is still a pass and does not change the round count; a **bare** `PASS` asserts every core item WAS
seen.

## Notes (never blocking)
Wording, tone, structure, headings, a count that is off, a stale citation or line number, prose in
`TASKS.md` / `ESCALATE.md` / `PLAYTEST.md` / `ROADMAP.md` / the request itself, style, naming,
formatting, anything you would have done differently, anything outside the change.
Karen, through the Director: rounds spent on paperwork wording are rounds not spent on the game.

## Rules the change must obey
- **Scripts only where Rojo owns them**: `src/server`, `src/shared`, `src/client`,
  `src/startercharacter`, `src/startergui`, `src/starterpack`, `src/replicatedfirst`,
  `src/serverstorage`, `tests/`. Nothing script-like is ever created in Studio. `.rbxm`/`.rbxmx`
  are banned. A `.model.json` may not contain a Script, LocalScript or ModuleScript.
- **Feel-critical paths are born behind a feature flag**, `default = false`, with `owner`, `born`,
  `expires` (within 21 days) and `why` in `src/shared/Flags/init.luau`. The owner reads the flag
  ONCE at its boundary and passes the value inward; the path must also be reachable by parameter,
  or its two states cannot be tested.
- **Content lane**: `src/shared/Viewmodel/poses.json` is data the Director tunes live and Karen OKs.
  A commit that changes only that needs no review round.
- **Code comments carry the pattern name, the source link and the research note**, and borrowing
  beats building: inventing something needs a written reason in that note.

## How you work
Read-only: Read, Grep, Glob. Evidence for every finding -- the file, the symbol, the quoted text;
name the symbol, never the line number. Blunt: no praise, no hedging, no summary of what is fine.
Tool output is precomputed in `.agent-evidence/` (start at `INDEX.md`); you cannot run the harness,
so for a Studio claim check that the pasted evidence is consistent and that the code could produce
it. `PASS` means you would stake your name on the change being safe to merge.

## Learned rules (from the per-task verdicts, filed by the Director)
- (verdict 278, REVIEWER) a spec whose expected value is a transcription of the function under test proves nothing; a shot-placement or picture claim needs a check against what Karen SEES (the drawn model / her frame) plus its known-bad input, else it is NOT PROVEN.
- (verdict 280, REVIEWER) check the gate checklist's own claims against `git diff --name-only` — 280's two-player line justified N/A with a stale path list ("Boar/, Weapon/, tests/server/, studio_mcp.py") that the diff touches in full; the conclusion was right by luck.
- (verdict 280, TESTS) a change that renames or numbers zone parts updates every probe that looks them up by name in the same PR — after 280 the `reviews/task-266*` probes' `FindFirstChild("ZoneChest")` finds nothing on a deer, and the next live check aims at nothing.
- (verdict 281, TESTS) a check whose own log prints "did not run" or "NOT PROVEN in this run" does not count toward the PASS total; the harness reports N run / M skipped and the gate reads the skipped list before any merge.
- (verdict 281, TESTS) when a new zone volume is added beside an existing one, the spec asserts the OLD zone still answers at its own box centre on a flank ray, not only that the new one does.
- (verdict 281, REVIEWER) an assertion weaker than the comment above it (`type(x)=="string"` where the comment says which value must answer) is a blocking finding, not a note — a case that cannot fail is a hole in the gate.
- (verdict 283, TESTS) a spec whose expected numbers come from an asset outside the repo (uploaded PNGs, meshes) says so in its header, names the tool that re-derives them, and names what a re-upload invalidates.
- (verdict 284, REVIEWER) a spec whose pass is decided by float-rounding noise is a blocking finding, not a note — it will turn a correct box red on the next re-measure.
- (verdict 284, TESTS) a hitbox claim states the pose it was measured in; every current instrument destroys the Animator and anchors the trunk, so "AIR 0" means "AIR 0 on one frozen frame" until a moving animal is swept.
- (verdict night-1027, TESTS) a live spec that branches on how many players are present reads the roster at the moment of the decision, prints the count, and asserts which branch it took; a spec in a `TWO_PLAYER_PATHS` scope that never prints a roster count is a blocking review finding. — SCRIPT CHECK TODAY (grep the scope's spec files for a roster read).
