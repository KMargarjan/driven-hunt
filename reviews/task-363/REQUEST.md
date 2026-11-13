# Task 363 -- when the game starts she is in the lobby, not on the road

Task: 363
Round: 1
Base: e883fa5a (origin/main)
Code commit: 9abf33a80e1aaa8520bb8790a54c10eec508a2db

```
[harness] PASS: 34/34 checks @ 9abf33a80e1aaa8520bb8790a54c10eec508a2db (clean tree) scope=all
```

`test2` is **N/A**: of the six non-paperwork files in `git diff --name-only e883fa5a..HEAD` --
`src/server/ForestTestBoot.server.luau`, `src/server/Lobby/init.luau`, `src/server/Lobby/Join.luau`,
`src/shared/Lobby/init.luau`, `tests/server/lobby.spec.luau`, `tests/server/lobby_live.spec.luau` --
none is in `TWO_PLAYER_PATHS`.

## What changed, and why

Karen, 2026-11-13: *"also when game starts I need to be in lobby not in road"*.

**MEASURED FIRST in her own place, attributes untouched.** The engine's `CharacterAutoLoads` loads
her first character at `Workspace.ForestRoadSpawn` -- (3000, 141, -2109), 838 studs from the lodge --
before the lobby has measured its ground, and `Join.needsReturn` respawns her at the lodge at
`DistributedGameTime` 5.5. `team=nil` at every sample, so neither the Director's
`DHForestStartRole=hunter` fixture nor the drive is the cause.

`Lobby` -- already the owner of `Player.RespawnLocation` and of where a man who is not in a hunt
stands -- becomes the one writer of `Players.CharacterAutoLoads`. `ForestTestBoot` arms the hold at
its last non-yielding line, the lobby loads the first body at the lodge through `world.place`, and
the auto-load is handed back on the first scan where the lobby is built and nobody is bodiless.

**THIS IS A RE-REVIEW OF AN UPDATED TREE, NOT A SECOND ROUND.** The first review of this task
passed (`PASS (item 2 NOT PROVEN)`, verdict committed at `9abf33a8`, reviewing `5027776e`); nothing
in it was a finding. Since then I changed one number and added one case, so the verdict has to name
the tree that will be merged -- `tools/agents.py` counts the round from the committed verdict and
says this run is `Round: 1`. What is new since that verdict: The ceiling that releases a hold nobody else released was `BUILD_TIMEOUT_SECONDS`' 10 s,
and its undo is a body at the engine's own spawn -- the road. 10 s sits INSIDE the range of boots
measured in that place: 5.6/6.0/6.1 s here, but 12.2-14.5 s over 11 Plays per `<runs-dir>/smoke.sh`.
A slow boot would have fired my own belt and put her back where the task started. It is 25 s now,
with that arithmetic written down, and `holdFirstSpawn` takes the seconds so a spec can drive it.

## Claims

1. **The cause is the engine's first spawn, not the fixture.** BEFORE, three Plays (A/B/C) on the
   merged-main build: the earliest sample reads `pos=3000,141,-2109 road=3 lodge=838 team=nil`, and
   the body that reaches the lodge is a SECOND character (`CharacterAdded dgt=5.45`, run C). Verify:
   `<runs-dir>/363-samples-B.txt`, `363-samples-C.txt`.
2. **AFTER: the first and only position is the lodge.** Four Plays (D/E/F at `369e641a`, **H at this
   code commit**): `pos=2850,153.4,-2934 road=838 lodge=4` at every sample, no road sample at all.
   Run H printed `build: FIRST_SPAWN_HOLD_SECONDS=25`; the BEFORE build answers `nil`. Verify:
   `<runs-dir>/363-samples-H.txt`, `-D`, `-E`, `-F`.
3. **This owner gave her the body, and not the old return path**: the console reads
   `[lobby] Alhamdulilah824 had no body: loading it at the lodge (first bodies 1)` in every AFTER
   run and **zero** times in the BEFORE runs, while `[place] spawn ... at (2850, 153.7, -2934)` is
   byte-identical in both (`363-console-D.txt` vs `363-console-B.txt`).
4. **The fix bites (L-093).** With `needsBody` deleted from `stepPlayer`'s door and nothing else
   changed: `failed [server] lobby_live.spec:526 Expected value "1" (number), got "0" (number)
   instead` (`<runs-dir>/363-failfirst.txt`, dirty tree at `369e641a`).
5. **The hold is a window, not a policy.** `Join.releasesHold(built, bodiless)`; the live case
   asserts `CharacterAutoLoads` goes false, STAYS false while he has no body, and is true again on
   the scan after it arrives. With the hold off nothing moves at all -- `Join.needsBody` is false
   unless this owner is holding, and the case "is the engine's own business when nothing is held"
   places nobody.
6. **Four releases, and each one has a case that dies with it**: the built scan, the degraded build
   path (`gets one anyway when the lobby cannot build itself`), `Lobby.stop`, and **the ceiling**,
   which round 2 drives at 50 ms through the new `seconds` argument (`gives up by itself when
   nothing ever releases it`) -- nothing scans, stops or builds in that case.
7. **The ceiling cannot re-create the bug.** `lobby.spec` asserts
   `FIRST_SPAWN_HOLD_SECONDS >= 2 * 12.2` and that it is NOT `BUILD_TIMEOUT_SECONDS` (two clocks:
   one starts at the lobby's first scan, the other at the boot's first line).
8. **Respawns still work after the hold is handed back.** `smoke.sh` at this commit:
   `gun in hand @+17s=1 @80s=1 | stacks=0 errorLines=0 | waves=10`, and
   `respawn+10s=[respawn-ground Alhamdulilah824:ok hp=100 y=153.4]` -- SMOKE PASS
   (`<runs-dir>/363-smoke2.txt`).
9. **The frame (rule 5), at this code commit.** `<runs-dir>/363-after-eye-H.png`, from her own eye
   at (2850.0, 154.9, -2934.0) looking +Z, +10 s into Play H: she stands on the lodge porch -- log
   wall, woodpile, bench, stone plinth -- with the lobby HUD reading *"step on a truck pad to
   hunt"*, `DRIVE 0 / WAITING / 0 ANIMALS / $13500`, compass N, and a `TRUCK 13 m` waypoint.
10. **What her screen shows in the held window, measured both ways.** The Studio viewport, sampled
    at ~25 Hz across the Play start (543 frames, `<runs-dir>/363-s3-BEFORE-*.png`): on the merged
    build the FIRST frame in which any world is drawn is already the lodge porch
    (`363-s3-BEFORE-539-24645ms.png`), and on this build it is the lodge too
    (`363-s2-AFTER2-34.png`). The held seconds look exactly like the seconds that are already there:
    the loading view, with the HUD over it.

## What I could not verify

- **I could not reproduce "I am on the road" ON SCREEN**, in either build: the client's loading view
  outlasts the server's 5.5 s road window on this machine, so no road frame is ever drawn here
  (claim 10). What is reproduced is her character STANDING on the road for those seconds, three
  times before and never after. If her report comes from a slower boot -- `smoke.sh`'s 12.2-14.5 s
  -- the road would be drawn, and that is the case the 25-second ceiling is now sized for.
- **The first ~5 s of an AFTER run cannot be probed:** the FT server answers `execute_luau` only
  from `DistributedGameTime` ~5. That she never had a road body is argued from claim 3, not from a
  sample at +1 s.
- **Two players:** not run, no `TWO_PLAYER_PATHS` path changed.
- **Flakes, all on the Director's list, none in the PASS run at the code commit:**
  `weapon_client.spec:1769` (run at `b1089d22`), `deer_hitbox.spec:659` (the dirty FAIL-FIRST run),
  `weapon_shot.spec:1890`, `weapon_shot.spec:2077` and `weapon_client.spec:1773` (one run at this
  commit, `363-harness-5.txt`; the next run at the SAME commit, `363-harness-6.txt`, is the pasted
  `PASS: 34/34`). One harness fault, not a spec: `363-harness-4.txt` ended
  `FAIL [input] ... Target is not reachable (UserMouseInputTool.SendUserInput, DMN_ID_PLAYCLIENT)`
  with both suites passing -- StudioMCP could not reach the Play client. It is reported, not worked
  around (rule 6).
