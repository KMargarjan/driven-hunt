# Task 367 -- main's harness green every run: the flaky specs, measured first

Task: 367
Round: 1
Base: 014f70ba35a6a1ce2c16365a8a3a682b561e706a (origin/main)
Code commit: 7f32cd842d8226c7b043ce7a4d77b4ee0a49347b

Nothing in `src/` changed. Every fix is in `tests/` plus the harness's own report.

```
[harness] PASS: 34/34 checks @ 7f32cd842d8226c7b043ce7a4d77b4ee0a49347b (clean tree) scope=all
[harness] PASS: 34/34 checks @ 7f32cd842d8226c7b043ce7a4d77b4ee0a49347b (clean tree) scope=all
[harness] PASS: 34/34 checks @ 7f32cd842d8226c7b043ce7a4d77b4ee0a49347b (clean tree) scope=all
[harness] PASS: 34/34 checks @ 7f32cd842d8226c7b043ce7a4d77b4ee0a49347b (clean tree) scope=all
[harness] PASS: 34/34 checks @ 7f32cd842d8226c7b043ce7a4d77b4ee0a49347b (clean tree) scope=all
```

`test2` N/A: no `TWO_PLAYER_PATHS` file is touched. The files changed are `tests/TestKit.luau`,
`tools/studio_mcp.py`, `tests/client/input_scenarios.txt` and nine `*.spec.luau` -- none of
`src/server/Match/`, `src/client/Match/`, `src/shared/Drive/`, `tests/client/Role.luau`,
`match_*.spec`, `zz_drive_boundary.spec`, `match_client.spec`, `outfit_client.spec` or
`zz_tie_to_a_tree.spec`.

## BEFORE | AFTER (L-127)

5 full runs at `014f70ba` (origin/main), clean tree, each FAIL captured before the next run
(`<runs-dir>/367/before-1..5.txt`); 5 full runs at the code commit (`<runs-dir>/367/gate-1..5.txt`).

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
   a fault. The loop returns the instant it answers, so a healthy run pays nothing.

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

4. **The frame budget is measured in the camera's own windows, and 0.3 ms is not widened.**
   `camera_client.spec`, "keeps the update inside its frame budget": three fresh windows of 60 camera
   updates, the BEST faces 0.3. Verify the note in every AFTER run: `0.095..0.127 ms`, and the
   measurement that caused the change -- `aft-4.txt`'s *"update 0.336 ms average, 0.909 ms worst, over
   366 frames"* against ten runs at 0.126. A window that cannot be taken at all still FAILS.

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
| `Rules.unlicensed` -> always false | `weapon_client.spec:2039`, and `semiauto_client.spec:262` -- which is also the proof of claim 8: the INNER line, not the wrapper's |

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
* **The 12-name cap**: the fail-first run had 41 server failures and named 12. That is the design,
  not a defect, but a run with more than 12 failures still loses names to the console.
* No screenshot: nothing visual changed (rule 5 N/A).
