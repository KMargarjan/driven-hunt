# Task 363 -- when the game starts she is in the lobby, not on the road

Task: 363
Round: 1
Base: e883fa5a (origin/main)
Code commit: 369e641a581ac5ee191464ba2021afe16f479065

```
[harness] PASS: 34/34 checks @ 369e641a581ac5ee191464ba2021afe16f479065 (clean tree) scope=all
```

`test2` is **N/A**: nothing changed is in `TWO_PLAYER_PATHS`. The four files are
`src/server/Lobby/init.luau`, `src/server/Lobby/Join.luau`, `src/shared/Lobby/init.luau` and
`src/server/ForestTestBoot.server.luau` -- none of them in that list.

## What changed, and why

Karen, 2026-11-13: *"also when game starts I need to be in lobby not in road"*.

**MEASURED FIRST, in her own place, with her own attributes untouched** (three Plays before, three
after; `<runs-dir>/363-samples-*.txt`). The engine's `CharacterAutoLoads` loads her first character
at `Workspace.ForestRoadSpawn` -- (3000, 141, -2109), 838 studs from the lodge -- seconds before the
lobby has measured its own ground, and `Join.needsReturn` then respawns her at the lodge at
`DistributedGameTime` 5.5. Nothing was broken: she simply stood on the road for those five seconds,
and that is what she sees. `team=nil` at every sample, so the Director's `DHForestStartRole=hunter`
fixture is **not** the cause, and neither is the drive.

So `Lobby` -- which already owns `Player.RespawnLocation` and where a man who is not in a hunt
stands (`docs/design/lobby.md` 8.1/8.2) -- becomes the one writer of `Players.CharacterAutoLoads`.
`ForestTestBoot` arms the hold at its last non-yielding line, the lobby loads the first body at the
lodge through `world.place` (the same door the return uses), and the auto-load is handed straight
back once the lobby is built and nobody is bodiless. It is a WINDOW, not a policy: every later
respawn is the engine's exactly as before.

## Claims

1. **The cause is the engine's spawn, not the fixture.** BEFORE, three Plays (A/B/C): the earliest
   sample a probe can take reads `pos=3000,141,-2109 road=3 lodge=838 team=nil`, and the character
   that reaches the lodge is a SECOND one (`CharacterAdded dgt=5.45`, run C). Verify:
   `<runs-dir>/363-samples-B.txt`, `363-samples-C.txt`.
2. **AFTER, three Plays (D/E/F) in her place on this commit: the first and only position is the
   lodge** -- `pos=2850,153.4,-2934 road=838 lodge=4` at +0/+2/+10/+20 s, no road sample at all.
   Verify: `<runs-dir>/363-samples-D.txt`, `-E`, `-F`; each run printed
   `build: FIRST_SPAWN_HOLD_SECONDS=10` (the BEFORE build answers `nil`).
3. **It is this owner that gave her the body**, not a return: the console says
   `[lobby] Alhamdulilah824 had no body: loading it at the lodge (first bodies 1)` in all three
   AFTER runs and **zero** times in the BEFORE runs (`363-console-D.txt` vs `363-console-B.txt`),
   while `[place] spawn ... at (2850, 153.7, -2934)` is identical in both.
4. **The fix bites (L-093).** With `needsBody` deleted from `stepPlayer`'s door and nothing else
   changed, the suite fails at the case this task added:
   `failed [server] lobby_live.spec:526 Expected value "1" (number), got "0" (number) instead`
   (`<runs-dir>/363-failfirst.txt`, dirty tree at the same commit). Verify by re-reading that file,
   or by deleting the `needsBody or` from `src/server/Lobby/init.luau`.
5. **The hold is a window and not a policy.** `Join.releasesHold(built, bodiless)` hands the
   auto-load back on the first scan where the lobby is built and nobody is waiting; the live case
   asserts `CharacterAutoLoads` goes false, stays false while he has no body, and is true again on
   the scan after it arrives (`lobby_live.spec`, "the first character" -> "is loaded at the lodge").
6. **With the hold off, nothing in the game moves.** `Join.needsBody` is false unless this owner is
   holding, so the DEV place, a world with no lobby and every spec written before this one are
   untouched: `lobby_live.spec` "is the engine's own business when nothing is held" places nobody.
7. **The lobby can still never lock the game out.** Three releases: the degraded build path (case
   "gets one anyway when the lobby cannot build itself" -- the auto-load comes back AND whoever has
   no body is loaded at the engine's own spawn), `Lobby.stop` (case "hands the auto-load back on
   teardown"), and a `FIRST_SPAWN_HOLD_SECONDS` ceiling equal to `BUILD_TIMEOUT_SECONDS`.
8. **Respawns still work after the hold is handed back.** `smoke.sh` on this build:
   `lobby=[lobby gunBefore=false] (+17s) gun in hand @+17s=1 @80s=1 | stacks=0 errorLines=0 |
   waves=10`, and `respawn+10s=[respawn-ground Alhamdulilah824:ok hp=100 y=153.4]` -- SMOKE PASS
   (`<runs-dir>/363-smoke.txt`).
9. **The frame (rule 5).** `<runs-dir>/363-after-eye-E.png`, from her own eye at
   (2850.0, 154.9, -2934.0) looking +Z, +10 s into Play E: she is standing on the lodge porch -- log
   wall, woodpile, bench, stone plinth -- with the lobby HUD reading *"step on a truck pad to hunt"*,
   `DRIVE 0 / WAITING / 0 ANIMALS`, and a `TRUCK 13 m` waypoint. No road, no stand, no gun.

## What I could not verify

- **The first five seconds of the AFTER runs are not directly observable.** The FT server answers
  `execute_luau` only from `DistributedGameTime` ~5, so the earliest sample in D/E/F already shows
  the lodge body. That she never had a road body is argued from claim 3 (the lobby found her with
  no character at all, which can only happen with the hold on) and from the absence of a second
  `CharacterAdded`, not from a sample taken at +1 s.
- **The `FIRST_SPAWN_HOLD_SECONDS` ceiling itself is not exercised by a spec** -- it would cost a
  10-second wait in the suite. What is asserted is the number (`lobby.spec`) and the release path it
  calls (the degraded and teardown cases).
- **Two players.** Not run: no `TWO_PLAYER_PATHS` path changed. A second player joining AFTER the
  lobby is built auto-loads as before and is returned by the existing level rule.
- Known flakes that fired during this task and not in the PASS run at the code commit:
  `weapon_client.spec:1769` (run 1 at `b1089d22`) and `deer_hitbox.spec:659` (the dirty FAIL-FIRST
  run). Both are on the Director's known-flake list; the clean run at `369e641a` has neither.
