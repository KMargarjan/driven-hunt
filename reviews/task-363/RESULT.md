PASS (item 2 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: what was seen in her place is the
frame at **+10 s** of Play E (claim 9, a described screenshot I cannot open) and the +0/+2/+10/+20 s
probe samples, all of which the request itself says are taken from `DistributedGameTime` ~5 onward.
What was NOT seen is the window the task is about -- the first ~5 seconds after she presses Play,
which this change turns from "a body on the road" into "no character at all" until `Lobby.step`'s
first built scan loads one at the lodge. No frame, no sample and no description exists for that
state; claim 2's "+0 s" label is the probe's clock, not the Play's, and the request's own "What I
could not verify" says so. Item 2 is therefore NOT PROVEN. Karen's 2026-11-15 play is the first look
at it.

Checked and true: the harness line `PASS: 34/34 @ 369e641a (clean tree) scope=all` names the
request's `Code commit:`, and `paperwork-after-code-commit.txt` says only `TASKS.md` and
`REQUEST.md` followed it. `test2` N/A is right -- none of the six non-paperwork files is in
`TWO_PLAYER_PATHS`. `Players.CharacterAutoLoads` has exactly one writer in the repo
(`src/server/Lobby/init.luau`); `Lobby` still requires no `Match` (the loader is injected). Claim 4
bites as stated: `occupant(77, nil, bin)` has no position, `Join.needsReturn(false,false,nil)`
returns `inField == false` = false, so `lobby_live.spec:526` `expect(#seen.placed).to.equal(1)` can
only be produced by `needsBody` -- deleting `needsBody or` from `stepPlayer` leaves it at 0, which
is the pasted failure. The release cases each die with their producer: delete `releaseHold()` from
the degraded branch and "gets one anyway" fails; from `Lobby.stop` and "hands the auto-load back on
teardown" fails; delete the `if not spawnsHeld then return end` guard and the last case's
`spawnHoldReleases` delta becomes 1. Claim 3's console line is printed only under `needsBody`, so it
cannot be produced by the old return path. The production loop hands `Lobby.step` an unfiltered
`Players:GetPlayers()` (`ForestTestBoot`, heartbeat), so a bodiless player really is an occupant;
`onPlayer` already guards `player.Character ~= nil`; `Body.place(player, nil, cfg)` reaches
`Body.onGround(nil, ...)` which returns nil and `finish(true)` -- "they spawned, and that is not a
failure" -- so the ceiling's undo is the engine's own spawn as claimed; and a boot that dies before
`Lobby.start` still ends with a body through `task.delay`.

## Notes (non-blocking)
- `src/server/Lobby/init.luau` / `holdFirstSpawn` — THE ONE TO WATCH ON 11-15: between the arm at
  `ForestTestBoot`'s last non-yielding line and the first built scan she has no character, and
  nothing in this task measured what that looks like. If she reports a frozen or empty view at the
  start, this is the owner and `FIRST_SPAWN_HOLD_SECONDS` is the dial. Worth one +2 s frame next
  time the FT channel is open.
- `src/server/Lobby/Join.luau` / `needsBody` — the header says "`held` IS THE HOLD AND NOT
  `Match.isHeld`", but no parameter is called `held`: the second parameter is `inHunt`, and
  `stepPlayer` passes `held = world.isHeld(userId)`, i.e. `Match.isHeld` exactly. The hold is the
  fourth parameter, `spawnsHeld`. Name the parameters in that sentence.
- `src/server/Lobby/init.luau` / `Lobby.step` — `bodiless` counts a player the drive has or holds,
  while `needsBody` refuses him, so one bodiless participant would keep the hold until the 10 s
  ceiling rather than one scan. Unreachable at boot today (`Match` is started with no enrolment when
  the lobby is on), but the two predicates disagree about who counts; `player.Character == nil and
  not inDrive` in the tally would make them agree.
- `src/server/Lobby/init.luau` / `holdFirstSpawn` — the `hold == false` arm does
  `if holdPlayers == nil then holdPlayers = players end` and then `releaseHold()`, which returns at
  once on `not spawnsHeld`. With nothing held the assignment changes no behaviour and leaves a
  dangling reference to the service table for the rest of the session. Delete those three lines.
- `src/server/Lobby/init.luau` / `holdFirstSpawn` — the ceiling reads
  `Data.CONFIG.FIRST_SPAWN_HOLD_SECONDS` where every other number in this module reads `cfg`
  (`world.config or Data.CONFIG`). That is the whole reason "it would cost a 10-second wait in the
  suite" is true: with `cfg` a spec could inject 0.05 and assert the ceiling's release and its
  `load`, which is the one release path with no case at all.
- `tests/server/lobby_live.spec.luau` / "the first character" — "THE COUNTERS ... ARE NOT CLEARED
  BETWEEN CASES (`stats.scans` climbs across this whole file)" is not what the code does:
  `Lobby.start` zeroes every numeric field in `stats`, and every case but the last calls `fresh`.
  The deltas are right (the last case has no `fresh`, so there the counter does carry); the reason
  written beside them is wrong.
- `tests/server/lobby_live.spec.luau` / "can be handed back by the caller" — it arms the hold with
  the owner stopped, so `afterEach`'s `Lobby.stop()` cannot release it. If its first `expect` ever
  fails, `spawnsHeld` stays true for every later case in the file and bodiless occupants start
  getting placed, turning one red case into a cascade. Arm it after a `fresh`. Relatedly, every arm
  schedules an unkeyed `task.delay(10, releaseHold)` that outlives its case; today all five cases
  finish in milliseconds, so no stale timer can meet a live hold, but nothing stops one.
- `reviews/task-363/REQUEST.md` — the `test2` N/A names "four files" and lists only the `src/` ones;
  the diff changes six non-paperwork files (both specs too). The conclusion holds -- neither spec is
  in `TWO_PLAYER_PATHS` -- but the list should be the diff's, which is verdict 280's lesson.
- `reviews/task-363/REQUEST.md` / `TASKS.md` row 363 — the dispatch's `Attribute diff EMPTY (L-101)`
  and "end with her FT on :34873 from `driven-hunt-karen`, Edit" are claimed nowhere. Nothing in the
  diff writes an attribute, so this is the Director's gate to ask for rather than a code risk.
- `docs/design/lobby.md` — §8.2 and the owner table in §13 still list only
  `Player.RespawnLocation`; `Players.CharacterAutoLoads` is now owned by the same module and is not
  there, and §8.2's "the engine's choice between two enabled neutral spawns is ... undefined for the
  first character" is now true only when the hold loses the race to the join. The code carries the
  citation and the doc is outside this task's statement, so queue it with the next lobby task.

---
REVIEWER verdict on commit `5027776ec94837a59cea3d42c51ae8bce220f4c2` (round 1) · 2026-11-13 16:51 UTC · session cost $3.52, 34 turns · written by tools/agents.py
