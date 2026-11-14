# Task 367 -- main's harness green every run: the flaky specs, measured first

Task: 367
Round: 2
Base: 014f70ba35a6a1ce2c16365a8a3a682b561e706a (origin/main)
Code commit: bc543778491beefaf4581adfdb2285d5887e10ab

Nothing in `src/` changed. Every fix is in `tests/` plus the harness's own report.

```
[harness] PASS: 34/34 checks @ bc543778491beefaf4581adfdb2285d5887e10ab (clean tree) scope=all
[harness] PASS: 34/34 checks @ bc543778491beefaf4581adfdb2285d5887e10ab (clean tree) scope=all
[harness] PASS: 34/34 checks @ bc543778491beefaf4581adfdb2285d5887e10ab (clean tree) scope=all
[harness] PASS: 34/34 checks @ bc543778491beefaf4581adfdb2285d5887e10ab (clean tree) scope=all
[harness] PASS: 34/34 checks @ bc543778491beefaf4581adfdb2285d5887e10ab (clean tree) scope=all
```

`test2` N/A: no `TWO_PLAYER_PATHS` file is touched. The files changed are `tests/TestKit.luau`,
`tools/studio_mcp.py`, `tests/client/input_scenarios.txt` and nine `*.spec.luau` -- none of
`src/server/Match/`, `src/client/Match/`, `src/shared/Drive/`, `tests/client/Role.luau`,
`match_*.spec`, `zz_drive_boundary.spec`, `match_client.spec`, `outfit_client.spec` or
`zz_tie_to_a_tree.spec`.

## BEFORE | AFTER (L-127)

5 full runs at `014f70ba` (origin/main), clean tree, each FAIL captured before the next run
(`<runs-dir>/367/before-1..5.txt`); 5 full runs at the round-2 code commit
(`<runs-dir>/367/r2-1..5.txt`). Round 1's own five, at `7f32cd84`, were 5 of 5 as well
(`<runs-dir>/367/gate-1..5.txt`).

| case | B1 | B2 | B3 | B4 | B5 | A1 | A2 | A3 | A4 | A5 |
|---|---|---|---|---|---|---|---|---|---|---|
| `[input] tie-the-driver` unreachable | FAIL | FAIL | ok | ok | ok | ok | ok | ok | ok | ok |
| `licence_popup.spec` nil vs `"no-range"` | FAIL | FAIL | ok | ok | ok | ok | ok | ok | ok | ok |
| `deer_hitbox.spec` nil / unreachable box | ok | FAIL | ok | ok | ok | ok | ok | ok | ok | ok |
| `camera_client.spec` avg > 0.3 ms | ok | ok | ok | FAIL | ok | ok | ok | ok | ok | ok |
| `camera_client.spec` replayed hold | ok | ok | ok | FAIL | ok | ok | ok | ok | ok | ok |
| `weapon_client.spec` end state / swap | ok | ok | ok | FAIL | ok | ok | ok | ok | ok | ok |
| **run** | **FAIL 31/34** | **FAIL 31/34** | **PASS** | **FAIL 32/34** | **PASS** | **PASS** | **PASS** | **PASS** | **PASS** | **PASS** |

**BEFORE 2 of 5 PASS, AFTER 5 of 5 PASS.** Six more faults surfaced in the 12 intermediate runs
(`measure-*`, `after-*`, `aft-*`, `final5-*`) and are in the claims below: `weapon_shot.spec:483`,
the three live-claim counters, `semiauto_client.spec:93`, `weapon_shot.spec:2123`.

## Claims

1. **The input transport fault was the BUDGET, and it is measured.** `tools/studio_mcp.py`,
   `INPUT_RETRY` 20 -> 90, and the retry loop prints the recovery either way. Verify: the retry loop
   in `replay_input`; then `grep "tie-the-driver" <runs-dir>/367/*.txt`. The first call is dropped in
   most runs, and **25 recoveries are now timed: 15 s to 35 s, median 21 s** -- 20 of them past the
   old 20 s budget, which is why it failed 2 of 5 BEFORE runs with *"stayed unreachable for 20 s"*
   and nothing since. The client suite runs while the replay plays, so by the last scenario it can be
   deep inside a synchronous stretch and StudioMCP's handler cannot be scheduled: a busy client, not
   a fault. The loop returns the instant it answers, so a healthy run pays nothing. **90 is a
   ceiling, not a measurement** -- the worst reading is 35 s -- and the cost of it is stated in the
   comment: a client that really is dead now holds a dropped batch for 90 s rather than 20, which is
   longer than the replay's own waiters (`RUN_TIMEOUT` 70, `waitUntil(60)`), so such a run fails on
   those instead and takes a minute longer to say so.

2. **`licence_popup.spec`'s live arm has a loaded barrel before it asks.** `licence_popup.spec`, the
   live-handler case: `ammoAhead` + the owner's own `"Reload"` waited for on the CONDITION, then
   `expect(ahead).to.be.ok()`. Verify: the note *"the live arm runs on shotgun, barrel 1 held **None**
   before and Slug now"* in `measure-1.txt` -- `None` is the empty-barrel VALUE, so the Aim branch
   answered `"no-range"` before it ever reached the licence. **The GAME defect this uncovered is
   `ESCALATE.md` 2026-11-14 05:05 and TASKS.md 367(a); no `src/` change here.**

3. **The hitbox fixtures cast in their own empty space.** `ownSpace()` in `deer_hitbox.spec`,
   `boar_hitbox.spec`, `boar_zones.spec` (both casters) and `boar_model.spec` ignores every sibling
   of the fixture's holder. Verify: `aft-2.txt`'s *"calf: legs box 1 is unreachable by a flank ray"*
   against the same kind's sweep answering an identical 32 of 63 in **all 17 runs**; a tree stops a
   flank ray and three foreign `ZonesOnly` trunks exhaust `Pierce.MAX_PASS_THROUGH`. Nothing of the
   animal under test is excluded -- trunk, volumes and coat are all under that holder.

4. **The frame budget is measured in the camera's own 120-frame windows. The NUMBER is not widened;
   the STATISTIC is, and that is the substantive change.** `camera_client.spec`, "keeps the update
   inside its frame budget": three fresh windows of **120 rendered frames each** -- the sample
   `docs/design/camera.md` 8.2 already names -- and the BEST faces 0.3 ms. What changed is the
   statistic: from that section's session `avgUpdateMs` to the least of three windows. Verify the
   note in every round-2 run: `0.096..0.114 ms over 120 frames` three times each. `windowAverage`
   returns nil unless it got all 120 (round 1 finding 1), the note then prints
   `SHORT: only N of 120`, and `expect(best).to.be.ok()` therefore fails exactly when its comment
   says: not one full window in three tries of 12 s each, which is a client below 10 fps. The
   measurement that caused the change is `aft-4.txt`'s *"update 0.336 ms average, 0.909 ms worst,
   over 366 frames"* against ten runs at 0.126 -- and `stats.frames` is every RENDERED frame
   (`stats.frames += 1` in both arms of `Camera.update`, bound at `Enum.RenderPriority.Camera`, no
   earlier return), so 366 by this case means the case runs ~6 s into the client suite.
   `docs/design/camera.md` 8.2 and 9.2 item 17 still say `avgUpdateMs`: queued as TASKS.md 367(f),
   because `docs/design/` is the Architect's.

5. **The replayed holds are counted from before the replay existed.** `camera_client.spec`:
   `preReplay` is captured on the line above `InputReady.ready("camera_client")`, which is the one
   instant provably before any replay, and both holds are asserted as `>= baseline + 2`. Verify that
   the case no longer re-reads the counters mid-case (the old `afterFirst` is gone), so deleting
   either scenario still fails it whenever the case runs.

6. **The replay's R -> X gap is the MEASURED reload, not the nominal one.**
   `tests/client/input_scenarios.txt`, 3000 -> 5000 ms, with the reading written into
   `weapon_client.spec`'s case. Verify that comment: the window's own timeline shows the reload
   taking **3.8 s** against `Shotgun.CONFIG.RELOAD_TOTAL = 2.0`, with 2.7 s inside one `Load` step, so
   `X` landed while `open=true` and `SelectAmmo` was refused `not-ready`.

7. **A live claim case waits for an empty sky.** `waitForEmptySky()` before all four
   `setClaimPolicy(true)` cases in `weapon_shot.spec`, and the same precondition in the sight-line
   case (`skyWasClear`). Verify `final5-5.txt`'s note *"self-block claim: rifle/Slug, 1 report(s),
   accepted 3 -> 3, refusedClaimBy [claim-blocked=1 claim-moved=1]"* -- two refusals counted for one
   claim, which is TASKS.md 285's *"ran in 2 of 5 runs and FAILED both times"* explained.

8. **Every failure the report carries is named** (step 4, TASKS.md 362b). `TestKit.compactFailure`
   keeps the innermost spec FRAME instead of the first 400 characters, and names 12 not 5;
   `TestKit.tracedCall` (21 client wrappers) captures `debug.traceback` so `error(why, 0)` no longer
   reports the wrapper's line; `describe_failure` reads both shapes. Verify: the four selftest cases
   in `studio_mcp.py selftest` (CI), and `failfirst.txt`'s `semiauto_client.spec:262` -- the real case
   line, where TASKS.md 281a(k) records `:93`.

9. **A case that could not run is COUNTED** (step 3, TASKS.md 285). `TestKit.notProven` plus the
   marker the ten existing fallback lines already use; the harness prints
   `---- [server] N claim(s) NOT PROVEN in this run`. Verify that line in every AFTER run (1 or 2),
   and `weapon_shot.spec`'s sight-line case now using `TestKit.notProven`.

10. **An aim the ACTION limiter dropped is asked again.** `aimOnce` in `weapon_shot.spec` and
    `licence_popup.spec`, 8 sites. Verify `final5-2.txt`'s `weapon_shot.spec:2123 Expected nil, got
    "rate-limited"`; the Aim branch moves nothing and a dropped ask increments `rateDropped`, never
    `aimQuestions`, so the `#lists`/`#asked`/`aimQuestions` counts beside the sites are untouched.

## FAIL FIRST (L-028): one run with three guarded behaviours broken

`<runs-dir>/367/failfirst.txt`, at the code commit with three temporary breaks, all reverted
(`git status` clean at `7f32cd84`). 41 server failures, 3 client:

| break | what failed, so the fix did not blind it |
|---|---|
| `Pierce.MAX_PASS_THROUGH` 4 -> 0 | `boar_hitbox.spec:368/:495/:537` on all four kinds, `boar_model.spec:416`, `boar_zones.spec:432` -- the isolated fixtures still catch a broken pass-through (`deer_hitbox` and `licence_popup` are among the 41 but past the 12-name cap) |
| camera window budget 0.3 -> 0.05 | `camera_client.spec:430`, with the windows reading 0.095/0.101/0.101 -- the three-window instrument is live, not vacuous |
| `Rules.unlicensed` -> always false | `weapon_client.spec:2039` (the licence card). `semiauto_client.spec:262` also failed in that run and the break cannot have caused it -- it is `expect(rose > 0.01)` on the lifter tray, a coincident failure -- but it IS the proof of claim 8: the INNER line, where the wrapper would have said `:93` |

## Round 2: the blocking finding, and the notes

**Finding 1 is closed** (claim 4): the window is 120 frames or `windowAverage` returns nil and says
how short it was; each try's frame count is in the note; the "not every frame" sentence is corrected
to what the source does; and the design edit is queued as 367(f).

The non-blocking notes, acted on rather than queued, because four of them were live flakes in waiting:

| note | what was done |
|---|---|
| `licence_popup`'s new Reload had no retry, and `onActionRequest` drops at the ACTION limiter first thing | the Reload goes through the same retry shape as `aimOnce` (`"rate-limited"` and `"not-ready"`) |
| `waitForEmptySky`'s answer discarded at four sites | a sky that did not clear is a `TestKit.notProven` naming the pellet count, so a green line measured with somebody else's shot in it is readable |
| `deer_hitbox`'s mesh-excluded control built once | rebuilt per cast, like `ownSpace` and for its reason |
| the SERVER wrappers still lose the line | `TestKit.tracedCall` now covers all 11 (`assets_seam` 4, `forest_placement` 3, `weapon_equip` 2, `weapon_look` 1, `zz_horn` 1); 32 wrappers in total |
| `test2` printed no unproven count | it does now |
| "ten cases across five files" | eleven lines in two files (`weapon_shot` 10, `range` 1) |
| `NOT_PROVEN` said to be "above" `note` | corrected: it is declared below |
| the 2 s grace "for a snapshot already in flight" | corrected: `ownLogEntries` is frozen at the shut so a later snapshot can never enter the window; the grace is a clock margin and the gain is failing in 2 s instead of 70 |
| `INPUT_RETRY`'s comment reads as though 90 were measured | corrected below, claim 1 |
| claim 9 did not name which claims went unproven | named below |
| the FAIL FIRST row for `semiauto_client.spec:262` | corrected: it is a coincident failure that happened to demonstrate claim 8, not an effect of the `Rules.unlicensed` break |
| `semiauto_client`'s 35-vs-36 cause (281a(k)) is not fixed | said so under "What I could not verify" |

**Which claims go unproven in a green run** (claim 9): the same two, every round-2 run --
`weapon_shot accepted claim` and `weapon_shot self-block claim`, both *"nobody is holding a gun that
can fire"*. One run in five has only one (the accepted-claim case found an armed player). That is
TASKS.md 285's own case, now counted on the gate's page instead of passing silently.

## What I could not verify

* **`deer_hitbox`'s "unreachable box" is fixed for the live-world cause only.** The second cause is
  NOT named: `aft-4.txt` printed `Boar1 -> Red_Deer_Doe_NoAlpha -> nothing (2 pass-through(s) of 4
  allowed)` -- the fixture's OWN trunk and coat, so neither contamination nor exhaustion. It has not
  recurred in the 6 runs since, and the failure now also prints the design offset, the built part's
  own local offset and the trunk's size. Queued as 367(b).
* **`weapon_client.spec`'s exploit window** failed once (`final5-2.txt`, `:1853` Live -> Spent) and
  the cause IS named and NOT fixed: the SERVER suite's live-fire cases spend this player's barrels,
  and `lastWeaponInput` only sees the CLIENT's own input, so the window looks quiet while a server
  spec fires. A cross-side quiet protocol (the server marking a replicated player attribute while it
  fires) is the fix; queued as 367(c).
* **`weapon_client.spec:1291`** (reserve Slug 13 vs 11, once in 17) is not explained. 367(d).
* **`semiauto_client`'s 35-vs-36 (TASKS.md 281a(k))** is NOT fixed and its cause is NOT named. It
  did not fire in any of the 22 runs of this task. What changed is only that the report now names the
  real line instead of the wrapper's `:93` (claim 8), so the next occurrence can be read. The fixed
  `task.wait(0.3)` in that file's `withSemiAutoDrawn` is the obvious suspect -- a fixed delay where
  the condition is "the live viewmodel has redrawn from the fake source" -- but suspecting is not
  measuring, so it is left. 367(g).
* **The 12-name cap**: the fail-first run had 41 server failures and named 12. That is the design,
  not a defect, but a run with more than 12 failures still loses names to the console.
* No screenshot: nothing visual changed (rule 5 N/A).
