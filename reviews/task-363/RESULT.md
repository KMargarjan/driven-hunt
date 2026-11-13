PASS (item 2 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: what HAS been seen in her place
is the +10 s frame of Play H (claim 9, described, a PNG I cannot open), the +0/+2/+10/+20 s position
samples, and claim 10's 543-frame viewport sweep across the Play start on both builds. What has NOT
been seen is the window this change creates — from the arm at `ForestTestBoot`'s last non-yielding
line to `Lobby.step`'s first built scan she has **no character at all**, and the request's own "What
I could not verify" says the FT server answers `execute_luau` only from `DistributedGameTime` ~5, so
claim 2's "first and only position" is an inference from claim 3's console line, not a sample. Nor
was the thing Karen reported ever reproduced on screen in either build: claim 10 says the loading
view outlasts the 5.5 s road window on that machine, so the AFTER frames show a held window that was
already covered by the loading view, and the SLOW boot her report most likely came from
(`smoke.sh` 12.2-14.5 s) — the case the 25 s ceiling is sized for — was not played at all. Item 2 is
NOT PROVEN. Karen's 2026-11-15 play is the first look at it.

Checked and true at this tree. `[harness] PASS: 34/34 @ 9abf33a80e1aaa8520bb8790a54c10eec508a2db
(clean tree) scope=all` names the request's `Code commit:`, and `paperwork-after-code-commit.txt`
says only `reviews/task-363/REQUEST.md` followed it. `test2` N/A is right: of the six non-paperwork
files in the diff (`ForestTestBoot.server.luau`, `Lobby/init.luau`, `Lobby/Join.luau`,
`shared/Lobby/init.luau`, `lobby.spec.luau`, `lobby_live.spec.luau`) none is in `TWO_PLAYER_PATHS`
(`src/server/Match/`, `MatchBoot*`, `src/client/Match/`, `src/shared/Drive/`, `tests/client/Role.luau`,
`match_*.spec`, `zz_drive_boundary.spec`, `match_client.spec`, `outfit_client.spec`,
`zz_tie_to_a_tree.spec`). selene 0/0, stylua clean, `rojo build` exit 0.
`players.CharacterAutoLoads` is written in exactly two places, both in `src/server/Lobby/init.luau`
(`releaseHold`, `holdFirstSpawn`), and `holdFirstSpawn` has exactly one production caller
(`ForestTestBoot`, twice), which returns early anywhere but `forest-test` — so the DEV place and the
harness are untouched. `Lobby`, `Body`, `Match` and `Players` are all required above the arm at
line 119, so the arm cannot crash the root.

Producer deletion, case by case (duty (a)):
- claim 4 / `lobby_live.spec:526` `expect(#seen.placed).to.equal(1)` — `occupant(77, nil, bin)` has
  `Character = nil`, so `rootOf` returns nil, `inHome` is nil, and `Join.needsReturn(false,false,nil)`
  returns `nil == false` = false. The placement can be produced by `needsBody` and by nothing else;
  deleting `needsBody or` leaves 0, which is the pasted `Expected "1", got "0"`.
- `Join.needsBody` has four clauses and `lobby.spec` has a line that dies with each: drop the
  `spawnsHeld` guard and line `needsBody(false,false,false,false)` goes true; drop
  `if inDrive or inHunt` and the three `true` arguments go true; drop `hasCharacter == false` and the
  first line goes false. `Join.releasesHold`: drop `built and` → `(false,0)` fails; drop
  `bodiless <= 0` → `(true,1)` fails.
- claim 6's four releases each die with their producer: delete the `spawnsHeld and
  Join.releasesHold(...)` block in `Lobby.step` and case 1's post-`Lobby.step(1002)`
  `CharacterAutoLoads == true` fails; delete `releaseHold()` from the degraded branch and "gets one
  anyway" fails; from `Lobby.stop` and "hands the auto-load back on teardown" fails; delete the
  `task.delay(... , releaseHold)` and "gives up by itself" spins its 2 s loop and fails on
  `spawnsHeld() == false`. The `load` loop inside `releaseHold` is asserted both ways — `#loaded == 1`
  in cases 3 and 4, `#loaded == 0` in case 1.
- "is the engine's own business when nothing is held" does pass with the whole feature deleted, and
  that is what it is for: it is the `spawnsHeld` guard's own case, and it goes red (placed 1, not 0)
  the moment that guard is removed. Not a vacuous case.
- the ceiling constant case errors rather than fails if `FIRST_SPAWN_HOLD_SECONDS` is removed
  (`nil >= 24.4`), and its bar (24.4) is STRONGER than the requirement its own comment states
  (longer than the slowest measured boot, 14.5), so it is not an assertion weaker than its comment.

Nothing else at boot breaks from the player having no character for those seconds: every
`Players:GetPlayers()` loop in `src/server` that reaches a character guards it (`if root then`,
`if character then`, `character and character.PrimaryPart`), `onPlayer` only connects `CharacterAdded`,
and `Body.place(player, nil, cfg)` reaches `Body.onGround(nil, ...)` which returns `nil, nil` → the
`finish(true)` "nowhere to put them: they spawned, and that is not a failure" path, so the ceiling's
undo really is a body at the engine's own spawn and writes no position.

## Notes (non-blocking)
- `src/shared/Lobby/init.luau` / `FIRST_SPAWN_HOLD_SECONDS` — THE ONE WITH TEETH THIS ROUND. The
  written derivation does not produce the number: *"the ceiling is the worst of those (14.5) plus the
  same again: 25"* is 29, not 25, and `lobby.spec` asserts `>= 2 * 12.2` = 24.4, which doubles the
  FAST end of the 12.2-14.5 range instead of the worst. The number is still safe — 25 s is 10.5 s
  clear of the slowest boot anybody has measured — so this is not a behaviour defect; but the comment
  and the spec state two different rules and neither is the one the number came from. Either write
  the rule the number satisfies ("the worst measured boot plus ~70 %") or move to 29 and make the
  spec `>= 2 * 14.5`.
- `src/server/ForestTestBoot.server.luau` / the `not lobbyOn` hand-back — the comment still reads
  *"the ceiling would otherwise keep her bodiless for the rest of its ten seconds"*. Stale since
  10 → 25; say twenty-five.
- `src/server/Lobby/init.luau` / `holdFirstSpawn` — the failure mode got 15 s worse this round and
  nothing says so. A root that dies ABOVE `Lobby.start` (an error in the places, the forest, the
  boars) now leaves her with no character for 25 s instead of 10 before the belt gives her one at the
  engine's spawn. It is the right trade — a 10 s ceiling could fire on a healthy slow boot, which IS
  the bug — but the Director should know the shape of the regression, because a world broken above
  `Lobby.start` used to show her a body on the road in one second.
- `src/server/Lobby/init.luau` / the degraded branch — ORDERING. `world.enrol(player)` runs for every
  occupant and THEN `releaseHold()` loads everybody whose `Character == nil`, and that loop is the one
  release path that does not ask whether the drive has him: both `Join.needsBody` and `Join.releasesHold`
  exclude `inDrive`, `releaseHold`'s loop does not. A man the degraded enrolment has just handed to
  `Match.Body.place` has no character until `LoadCharacter` lands, so this owner can fire a second
  `LoadCharacter` into a placement already in flight. The fake world's `enrol` only records the call,
  so no case can see it. Either call `releaseHold()` before the enrol loop, or gate the loop on
  `world.inDrive(player.UserId) ~= true`.
- `tests/server/lobby_live.spec.luau` / "gives up by itself when nothing ever releases it" — it arms
  the hold without a preceding `fresh`, so `started` is false and `afterEach`'s `Lobby.stop()` returns
  at its first line and cannot release it. If the ceiling ever fails to fire, `spawnsHeld` leaks true
  into every later case in the file and bodiless occupants start getting placed — one red case becomes
  a cascade. Same shape as "can be handed back by the caller"; there are now two of them. Arm after a
  `fresh`, or release in the case's own tail.
- `src/server/Lobby/Join.luau` / `needsBody` — still open from round 1: the header says "`held` IS THE
  HOLD AND NOT `Match.isHeld`", but no parameter is called `held`; the second parameter is `inHunt`
  and `stepPlayer` passes `world.isHeld(userId)` into it, i.e. `Match.isHeld` exactly. The hold is the
  fourth parameter, `spawnsHeld`. Name the parameters in that sentence.
- `src/server/Lobby/init.luau` / `Lobby.step` — still open from round 1: `bodiless` counts a player the
  drive has or holds, while `needsBody` refuses him, so one bodiless participant would keep the hold
  until the 25 s ceiling rather than one scan. Unreachable at boot today (enrolment needs a body, and
  the degraded path releases), but the two predicates disagree about who counts;
  `player.Character == nil and not inDrive` in the tally would make them agree.
- `src/server/Lobby/init.luau` / `holdFirstSpawn` — still open from round 1: the `hold == false` arm's
  `if holdPlayers == nil then holdPlayers = players end` is dead (`releaseHold` returns at once on
  `not spawnsHeld`) and leaves a dangling reference to the service table for the session. Delete the
  three lines.
- `tests/server/lobby_live.spec.luau` / "the first character" — still open from round 1: "THE COUNTERS
  ... ARE NOT CLEARED BETWEEN CASES (`stats.scans` climbs across this whole file)" is not what the code
  does — `Lobby.start` zeroes every numeric field in `stats`, and every case but the last two calls
  `fresh`. The deltas are right; the reason written beside them is not.
- `tests/server/lobby_live.spec.luau` — every arm schedules an unkeyed `task.delay(25, releaseHold)`
  that outlives its case (was 10 s, now 25). Today no stale timer can meet a live hold because the
  cases finish in milliseconds, but nothing stops one, and the window is now 2.5x longer.
- `reviews/task-363/REQUEST.md` — claim 7's *"The ceiling cannot re-create the bug"* is stronger than
  what is asserted: a boot slower than 25 s still ends with a body at the engine's own spawn, which is
  the road. The spec asserts the constant is beyond any boot anybody has MEASURED, which is the honest
  sentence. Likewise claim 2's *"the first and only position is the lodge"* is an inference from
  claim 3, not a sample — as the request's own "What I could not verify" says.
- `reviews/task-363/REQUEST.md` / `TASKS.md` row 363 — the dispatch's `Attribute diff EMPTY (L-101)`
  and "end with her FT on :34873 from `driven-hunt-karen`, Edit" are claimed nowhere in this round's
  request (round 1's was the same). Nothing in the diff writes an attribute, so this is the Director's
  gate to ask for rather than a code risk.
- `docs/design/lobby.md` — §8.2 and the owner table in §13 still list only `Player.RespawnLocation`;
  `Players.CharacterAutoLoads` is now owned by the same module and is not in either, and §8.2's "the
  engine's choice between two enabled neutral spawns is ... undefined for the first character" is now
  true only when the hold loses the race to the join. §14 has no row for `CharacterAutoLoads` either,
  though the code carries the docs link inline. The doc is outside this task's statement; queue it with
  the next lobby task.

---
REVIEWER verdict on commit `1c024b7d026957910318ca4f0d64b6bc1ce744dd` (round 1) · 2026-11-13 17:40 UTC · session cost $3.35, 37 turns · written by tools/agents.py
