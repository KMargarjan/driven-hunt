# Task 355 -- the server's worst frame during a drive: find who spends it, cut the biggest one

Task: 355
Round: 1
Base: `main` `bc988cd2`
Code commit: `de597a5fa0b2dbc9f029456419492d6d5fc1dc0d`

`[harness] PASS: 34/34 checks @ de597a5fa0b2dbc9f029456419492d6d5fc1dc0d (clean tree) scope=all`

`test2`: **N/A** -- no `TWO_PLAYER_PATHS` path is touched. The change is `src/server/Boar/`,
`src/server/ForestTest/`, `src/server/ForestTestBoot.server.luau`, `src/shared/Flags/`,
`tools/studio_mcp.py` (a `SCOPE_SPECS` row) and one new server spec; none of them is in that list.

## What changed

**Measurement first, then one fix.** Three instrument commits (`83837a30`, `f96d38a8`, `402aec2e`)
answer "who spends the worst frame" -- nine named sections of the boar step, seven of
`ForestTest.step`, six owners of `ForestTestBoot`'s Heartbeat, each with its own max AND total,
published where a probe can read them. `reviews/task-355/MEASUREMENTS.md` is the table, written
before any fix code. **One fix** (`c47a41b0`, corrected in `2291121d`): a frame budget on
`Body.attachVisual`, behind `BOAR_ATTACH_BUDGET` born OFF. `487e3b83` moves `LICENCE_POPUP`'s expiry,
which the UTC date roll tripped.

## Claims

1. **The instrument is behaviour-neutral.** Nothing in the game reads `StepWorst`, `StepOwners`,
   `SpawnCost`, `DHBootStep`, `DHBootWorst`, `DHBootOwners` or `ForestTest.stepSections`; no ordering
   changes and no call is added or removed. *Verify:* `grep -rn "StepOwners\|DHBootOwners\|stepSections" src/ tests/`
   -- the writers in `Boar.Runtime:_stepCost` and `ForestTestBoot`, and no reader. The attribute
   writes sit inside the existing `steps % STEP_PUBLISH_EVERY == 0` block and a new
   `bootSteps % 120 == 0 and RunService:IsStudio()` block.
2. **`ForestTest.step`'s bill needs no wrapper and changes none of its six early returns.** The table
   is zeroed at the top of `step` and read by the composition root AFTER the call returns.
   *Verify:* `ForestTest.stepSections` in `src/server/ForestTest/init.luau`, and `local inner =
   ForestTest.stepSections()` in `ForestTestBoot.server.luau` -- it is read after `ForestTest.step`
   has returned, inside the same Heartbeat body.
3. **The top three spikes, measured in Karen's Forest Test (C1, her flags, one 340 s drive at
   `402aec2e`):** `ForestTest.releaseLine` **569.3 ms** in one frame; `Lobby.step` **378.4 ms** once
   at the join; `Body.attachVisual` **92.1 ms** of a **104.2 ms** boar step. *Verify:*
   `reviews/task-355/MEASUREMENTS.md`, and `<runs-dir>/BEFORE-track.txt` (`BOOTOWNERS` and `OWNERS`
   lines, which carry each owner's own max/total).
4. **The one fixed is spike 3, and the request says why it is not spike 1.** The dispatch's headline
   number -- *"a server step peak of 73-94 ms"* -- is `workspace.Boars.StepMsMax`, which is the boar
   step and nothing else; spike 3 is 88 % of it, and its target (<= 40 ms) is the one a fix is
   measurable against. Spike 1 is named as the next owner with its measurement; spike 2 is at the
   join, before any drive. *Verify:* MEASUREMENTS.md, "Which one this task fixes".
5. **The fix is a borrowed pattern with three named sources.** React Scheduler's `shouldYieldToHost`
   frame budget (MIT, active), with Game Programming Patterns' level-triggered Update Method
   supplying the continuation and no queue at all; Godot's threaded background loading is named and
   refused with a reason. *Verify:*
   `docs/research/2026-11-12-frame-budget-for-attaching-models.md` and its `INDEX.md` row.
6. **The flag is born OFF and is read once at its owner's boundary.**
   `Boar.CONFIG.MODEL.ATTACH_BUDGET_MS = if Flags.isOn("BOAR_ATTACH_BUDGET") then 8 else 0`, and
   **0 means no budget**, so the OFF world is today's byte for byte. Both states are reachable BY
   PARAMETER: the spec hands the value in through `world.config.MODEL`. *Verify:* the
   `BOAR_ATTACH_BUDGET` row in `src/shared/Flags/init.luau`, the `ATTACH_BUDGET_MS` line in
   `Boar.CONFIG.MODEL`, and `buildWorld` in `tests/server/boar_attach_budget.spec.luau`.
7. **FAIL FIRST, with the producer deleted (L-093).** Replace `if budget <= 0 or prof.attach <
   budget then` with `if true then` and run the harness: `failed [server] boar_attach_budget.spec:199
   Expected value "1" (number), got "4"` and `:215 Expected "1,2,3,4", got "4,4,4,4"`
   (`<runs-dir>/355-delete-fail.txt`, `[harness] FAIL: 32/34 @ de597a5f (DIRTY TREE (1 paths))`).
   The tree was restored immediately; `git status` is clean at the code commit.
8. **It defers, it never drops.** `boar_attach_budget.spec` asserts the sequence `1,2,3,4` over four
   steps and then that all four are dressed and `count`/`liveCount` are still 4 -- so a budget that
   SKIPPED the work fails here, not just one that did it all at once. *Verify:* the two cases under
   "with a budget, the step dresses what it can afford and DEFERS the rest".
9. **BEFORE | AFTER in her place, both arms at the code commit, same probe, same cell.**
   step peak **104.2 (no flag) / 75.8 (OFF) -> 26.1 (ON)** ms, target <= 40 **MET**; `attach` worst
   **92.1 / 70.4 -> 17.2** ms; animals left with no model **0**; peak live 60/59/56 and peak parts
   1020/1003/950. Heartbeat p95 **33.1 / 33.7 -> 34.0** ms, target <= 32 **NOT MET** and stated as
   not this owner's (both loops together are 5.1 ms of a ~33 ms frame). *Verify:* MEASUREMENTS.md,
   `<runs-dir>/OFF-ARM-track.txt` and `ON-ARM-track.txt` (and `AFTER-ON-track.txt`, a second ON drive:
   24.8 ms peak, p95 30.8 ms).
10. **349's own instrument at stand 4 is not worse**, and her attribute diff is EMPTY. first sighting
    1 s (OFF) -> 0 s (ON), median gap 2 s both, max gap 2 s both, groups that never came near 1 -> 0.
    *Verify:* `python 349-table.py S4-OFF S4-ON` in `<runs-dir>`, and
    `diff 355-attrs-before.txt 355-attrs-after.txt` (empty).

## What could not be verified

- **Karen has not seen any of it.** The fix is behind a flag born OFF, so her build is unchanged;
  whether a coat arriving a few frames later is visible at all is a playtest question and hers.
- **Heartbeat p95 (<= 32 ms) is NOT met and is not moved by this task.** 30.8-34.0 ms across four
  drives, with and without the budget. The honest reading is that it is not spike-bound: the two
  instrumented loops are 5.1 ms of a ~33 ms frame, and the other 85 % (physics and replication for
  ~1,000 parts on 56-60 animals) is outside anything this instrument can see.
- **`MAX_FLAGS` 28 -> 29.** The dispatch asks for a flag born OFF and the table was full; the only
  other routes are retiring a lit row (the Director's call, TASKS.md 82b) or shipping lit, which
  `docs/design/feature-flags.md` section 11 forbids. Said out loud in the file, not paid for quietly.
- **`LICENCE_POPUP`'s expiry moved** (`487e3b83`). Not this task's row; the rot tripwire fired at
  00:00 UTC and the documented fix is one line with a reason. The reason given is that Karen plays
  with it ON as a Forest Test override, so the flip is hers and the row is still live.
