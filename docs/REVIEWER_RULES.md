# Reviewer rules digest

The REVIEWER reads THIS FILE and nothing else from `docs/`: it replaces `CLAUDE.md` (557 lines) and
`docs/PROJECT_CONTEXT.md` (48) for a review run. Builder's file, kept in step with CLAUDE.md. Task 113.

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
