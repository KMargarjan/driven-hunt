# Task 328t -- the one-player gate was red at `main`: the ENGINE was killing the runner

Task: 328t
Round: 1
Base: 14581cc7 (`main`)
Code commit: 1fd399b3c7a18bd58f7c9fc1d5ae6cc3d122a8f6

```
[harness] PASS: 34/34 checks @ 1fd399b3c7a18bd58f7c9fc1d5ae6cc3d122a8f6 (clean tree) scope=all
```
and again, the same commit, consecutively:
```
[harness] PASS: 34/34 checks @ 1fd399b3c7a18bd58f7c9fc1d5ae6cc3d122a8f6 (clean tree) scope=all
```
`test2` is N/A: nothing here touches `TWO_PLAYER_PATHS` (`tests/TestKit.luau`,
`tests/TestRunner.server.luau`, `tests/server/weapon_equip.spec.luau`, `tools/studio_mcp.py`).

## What changed

1. `tests/TestRunner.server.luau` -- publishes `ServerStorage.TestStage` / `TestStageTrail` /
   `TestStageAge` as the run goes, traps the engine's own errors off `LogService.MessageOut` with the
   asset noise filtered out (`TestStageErrors`), and `xpcall`s `TestKit.run`.
2. `tests/TestKit.luau` -- `TestKit.stage`, `TestKit.onStage`, and `TestKit.atEveryNode`: one frame
   yielded at a test boundary once `YIELD_AFTER` (2 s) of non-yielding execution has gone by, plus
   the stage that names the test.
3. `tools/studio_mcp.py` -- reads the stage attributes in the Play datamodel when a report does not
   arrive and names them in the failing check; and the input replay now applies the harness's own
   "still loading is not a fault" policy (`INPUT_RETRY`).
4. `tests/server/weapon_equip.spec.luau` -- the late-mesh case waits for the template and sets its
   own premise (a player holding nothing). No assertion removed.
5. **Not in the repo:** three test leftovers removed from the DEV **Edit** place --
   `Workspace.StagRoar` (Part), `Workspace.BoarEscapeSpec` (Folder), `ServerStorage.OneSpecOut`
   (this task's probe).

## Claims

1. **The cause is the engine, not the repo.** `git diff --name-only d989ebc0 14581cc7` is
   `TASKS.md` + two `reviews/task-328r/` files, so the code that passed 34/34 on 2026-11-03 and the
   code that failed all night are identical. Verify: run that diff.
2. **The server thread was KILLED, with `Script timeout: exhausted allowed execution time`.**
   Measured by the error trap added here (run 10, `<runs-dir>/328t-run10.log`). Not catchable, so
   no window ever helped -- 300, 900 and 2400 s all failed identically (328s's own measurements).
   Verify: that log line, beside the `ESCALATE.md` entry for 328s.
3. **Studio did not update.** One Studio installed, `0.745.0.7451137`, written 2026-10-27 17:02 --
   before 328r's PASS. Verify: `RobloxStudioBeta.exe`'s FileVersion/LastWriteTime.
4. **Where it stopped, before the fix: `testez-starting` (run 6), then `grid_relief.spec`'s
   `328e-6` (runs 5-10), at a varying statement inside it.** After the fix: `report-set`, and the
   report arrives after 76 s. Verify: the `last stage:` detail in runs 6/7/10 against run 20.
5. **It is not a slow suite and not memory.** Bare TestEZ over the same folder in the same Play
   session finishes in 338.7 s; every statement of `328e-6` measures 0.55 s in Edit; the server's
   memory is flat at ~3.06 GB / ~935 MB Luau heap from 25 s to 406 s. Verify:
   `<runs-dir>/328t-time-328e6.luau` and run 9's memory trail.
6. **`YIELD_AFTER` is a yield-when-needed, not a yield-per-test.** `os.clock() - lastYield > 2`
   inside the node seam, so a suite that yields on its own pays nothing. Verify: `TestKit.atEveryNode`.
7. **The 38 bare-TestEZ failures are an artefact of running the suite OUTSIDE the gate**, not 38
   defects: 36 of them are `match_live`, `zz_drive_boundary`, `zz_pad_restart`, `match_teams`,
   `match_stand_pick`, `bots_live`, `assets_seam`, `grid_relief:1218`, `sync` -- the specs that
   assert on the LIVE server's own state, which a StudioMCP probe cannot see (its `require` cache is
   its own; `sync.spec` also checks a harness token the probe never wrote). The remaining two,
   `forest_stand:526` and `weapon_equip:673`, were real and are both fixed here. Verify: the list in
   the report, and that both now pass.
8. **`forest_stand.spec:526` was a leftover in the place, not a defect.** `Workspace.StagRoar`, the
   Part `ForestTest.start` builds at runtime, was sitting in the DEV **Edit** Workspace and cloned
   into every Play session, so the spec counted two emitters. Removing it took the suite from
   2 failures to 1 with no code change. Verify: runs 12/13 side by side.
9. **`weapon_equip.spec` was asserting against the rule it is built on.** Measured in-run:
   `upgraded=1 wearsMesh(tool)=true heldId=rifle`. `Weapon.upgradeLook` re-equips the gun that was
   HELD, or the PRIMARY when none is (task 140), so with a rifle in the hand it correctly left the
   upgraded shotgun in the Backpack. The case now unequips first and waits for
   `Weapon.heldId` to go nil, because that registry field is written a frame later. Verify: the
   note in `<runs-dir>/328t-run16.log` and the spec's comment.
10. **The input replay's failure was the harness's, and pre-existing.** `Target is not reachable`
    against a Play client is in `LOADING_ERRORS` and is retried for every other call against a test
    process; this loop did not retry it. It failed 7 of 9 runs tonight AND in run 2 of this task --
    before the yield existed -- and in `test1-t99r2b.log` and `test1-task-113-r2.log`. Verify:
    `grep -l "FAIL \[input\] replayed" <runs-dir>/*.log`.

## Could not verify

* **`ServerScriptService.Boar.Brain:838: attempt to index nil with 'minX'`** fires repeatedly on the
  live DEV server. It is caught by this task's new error trap, it is not mine, and it fails nothing;
  queued in `TASKS.md`.
* `deer_hitbox.spec:659` (run 14) and `:682` (run 16) each fired once in 21 runs and passed in the
  two PASS runs. Named in the dispatch as KNOWN INTERMITTENT; row opened in `TASKS.md` (L-149).
* Whether the engine's budget is exactly 10 s: not measured. `YIELD_AFTER = 2` is chosen to sit well
  inside it, not derived from it.
