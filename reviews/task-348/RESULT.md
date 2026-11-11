PASS (item 6 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing was seen in Karen's
place this round — the one change is a test stub and produces no frame. Round 1's item 6 is carried
forward unchanged and is still the only unseen thing: the bot's ABSENCE beside her after the fix was
MEASURED in her place (`within10=0/287`, `minDist=150.7`) and never SEEN in a frame of the wood; the
two frames offered in round 1 are of the map panel, which draws no bot markers. No animal-behaviour
or shooting item is in this task.

What I verified in the repo (not blocking, recorded so the PASS is readable):
- The fix belongs at the stub, not in production. `src/server/Boar/init.luau` has exactly ONE
  `local handle = {` literal (the one `Runtime:boars` hands out as `entry.handle`) and it always
  carries `id`, `kind`, `part`, `state()` and `position = function() return Body.position(body) end`.
  So `ForestTest.spookNearBeaters`'s unguarded `handle.position()`, `handle.id` and
  `Boar.isDeerKind(handle.kind, ...)` cannot meet a nil in production, and the request's refusal to
  make `spookNearBeaters` tolerant is right.
- `part` left out is right: both readers nil-guard it — `local part = handle and handle.part; if
  part ~= nil and part.Parent ~= nil` in `ForestTest`, and `if handle and handle.part and
  handle.part.Parent` in the wave counter.
- The gate claim holds: `ForestTest.realBeaters` is beater PLAYERS plus `botThreats()` rows with
  `threat.kind == "driver"`, and `spookNearBeaters` returns nil on `#beaters == 0` — so a one-player
  run never enters the loop, which is why the spec was green at 34/34 all along.
- The delete-and-fail side is a real run with the exact delta, not a reading. `.agent-evidence/log.txt`
  shows every commit between `66de5029` (round 1's code commit, where `test2` failed) and `b97b3751`
  is paperwork except `b97b3751` itself, which touches one file,
  `tests/server/forest_placement.spec.luau`, 13 insertions. And the traceback line matches the body:
  the diff adds 12 lines above it, so the old `forest_placement.spec:1310` is today's
  `local held = Forest.step(Data.slotSeconds(1, Forest.cellSchedule()), true)` — inside the one case
  ("releases nothing for a scheduled slot the switch owns") that does
  `table.insert(standing, "Boar1")` directly, which is the only case whose stub boars reach
  `handle.position()`. One failure, one error, as the pasted line says.
- With the fields present the case still asserts what it asserted: the stub's `spook`, `notice` and
  `sounderOf` all answer false/nil, `kind = "female"` is not a deer kind, so `spookNearBeaters`
  returns nil and `held` is unchanged — the case passes with 0, 1 or 2 players, which is what the two
  post-fix `test2` runs report. `urgeAcrossRoad`/`checkAtTheEdge` (which would call the stub's
  missing `leads`/`urge`) are in `step`'s NON-LINE branch and `Data.LINE.enabled` is true, so the fix
  opens no new nil call.
- Claim 5's scope half is true: `tools/studio_mcp.py`'s `"match"` tuple lists both
  `tests/server/forest_placement.spec.luau` and `tests/server/match_stand_pick.spec.luau`, so
  `scope=auto:match` played the changed file.
- Harness line names the `Code commit:` (`1bae84ba23a7e8be88ded3651c04e7a36167b942`), is
  "(clean tree)", and `paperwork-after-code-commit.txt` says OK (only `reviews/task-348/REQUEST.md`
  followed it). selene (src and tests), stylua and the rojo build are clean. No secret, key, absolute
  user path or non-noreply address in the diff.

## Notes (non-blocking)
- `ESCALATE.md`, the 2026-11-11 ~12:15 entry — it contradicts itself and the Director reads the top
  of the file first. Its opening says *"It is fatal, not cosmetic. Measured both ways today: with two
  Studios the run stops at 9/11"*, and nine lines later *"The check is NOT fatal -- it records a FAIL
  and the run continues"*. The later paragraph is the one the evidence supports (two runs with the
  Forest Test open reached 31/36 and 33/36; the 9/11 control attempt is separately explained by the
  missing `tests/sync-token.txt` in the `driven-hunt-rev` worktree). Cut or strike the opening
  paragraph so the entry says one thing.
- The merge gate still has no `[harness2] PASS` for `src/server/Match/` (`TWO_PLAYER_PATHS`). The two
  post-fix `test2` runs scored 31/36 and 33/36 — `forest_placement` is gone, and the named remainder
  (`deer_hitbox.spec:682` on the dispatch's flake list, `deer_hitbox.spec:340`, `gun_client.spec:393`,
  the one-Studio check) is nothing this diff touches. Stated so the Director weighs it rather than
  reading this PASS as the gate being satisfied.
- `tests/server/forest_placement.spec.luau`, `stubRuntime().boars()` — `kind = (where[id] or {}).kind
  or "female"` and `position` falling back to `Vector3.new(0, 0, 0)` silently stand in for a MISSING
  `where` row, and one case relies on exactly that: it pushes `"Boar1"`/`"Boar2"` into `standing` with
  no row, so those two animals are a sow at the world origin. Harmless today because that case asserts
  only the returned line, but a future case that asserts a position or a deer kind would read a
  default instead of failing. Either seed `where` in that case or make the stub `assert` the row
  exists.
- Round 1's note (a) is unchanged and still queued as `TASKS.md` `348-notes`: `match_stand_pick.spec`
  case 15 proves the PURE rule, not the WIRING — revert `syncBots` to `bots.fillCounts(...)` and leave
  `Match.botFillDuringPick` in the file and every line of case 15 still passes. This round did not set
  out to fix it and did not.

---
REVIEWER verdict on commit `1b1b4e3a7c2b1e98fed6912667f1f818ff2fd94f` (round 1) · 2026-11-11 13:05 UTC · session cost $1.92, 25 turns · written by tools/agents.py
