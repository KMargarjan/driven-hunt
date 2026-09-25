# Task 34 — running the specs with two players

Task: 34
Round: 3
Base: `2545891`
Code commit: `166bd334e576a84f324c5ca093e56af22ccb286b`

```
[harness] PASS: 27/27 checks @ 166bd334e576a84f324c5ca093e56af22ccb286b (clean tree)
[harness2] PASS: 28/28 checks @ 166bd334e576a84f324c5ca093e56af22ccb286b (clean tree)
```

One player: 234 server and 58 client `it` blocks (`main` had 226 and 58). Two players (the Director
ran it, 2026-09-25): server 234 passed / 0 failed, the **shooter's** client 58 / 0, the driver's
client printed as an observation. This request is written fresh for the whole change since `main`;
rounds 1 and 2 reviewed an earlier shape of it.

## Task

ROADMAP 1.6: run the specs with two players. What that took, in the end, was a second harness mode
**and** a game fix, because the first real two-player session found a drive in which the Shooter
carried no gun at all.

## Claims

1. **`test` is untouched and stays the default.** `test2` is a separate command and a separate
   function (`run_test2`); `run_test` gained no branch, flag or mode argument. No spec knows which
   mode it is in — same `TestKit` gate, same two runners, same reports.

2. **StudioMCP cannot start the test, and that is measured.** `start_stop_play` takes `is_start` and
   `studio_id` and nothing else, so `test2` prints the clicks and waits up to 180 s for three **new**
   studios; if nobody starts one it says so and claims nothing. The docstring also records that the
   Director can now post F7 to the Studio window (`driven-hunt-runs/press-f7.ps1`); the harness does
   not call it.

3. **A test process is classified by asking it, not by what it advertises.** Probed live: all three
   processes report `Available DataModels: Client, Server`, so reading that line made every one of
   them a server (run 2: "a SECOND server DataModel" twice, "0 client(s)"). `probe_role` runs
   `QUERY_ROLE` inside each and decides on `RunService:IsServer()`; the focused-DataModel line only
   picks which to try first. The real per-process shape is in the docstring.

4. **Nothing that talks to a test process can crash the run.** `still_loading`/`process_call` treat
   "Place is not open", "Target is not reachable" and "… is not available" as *not yet* and retry to
   that step's deadline, raising anything else. Run 3 died on the first of those, outside a retry.

5. **The gate is opened by the harness, after the processes exist.** Whether the copied place carries
   the token is a coin toss (run 4: empty, run 5: carried), and a carried token is worse — the
   suites then start 20-40 s before the replay can begin, and run 5 lost 14 shooter specs to that. So
   the disk token is written, checked (the proof Rojo is live), then **cleared before the click**; a
   fresh one is set on the SERVER through `execute_luau` and replicates to both clients.
   `TestKit.awaitToken` keeps both runners listening for it — the same gate, Studio and 120 s, read
   later rather than once at startup, and nil at once outside Studio, so a playtest still runs no
   tests.

6. **The three reports are polled together**, against one deadline (`REPORT_WINDOW_2P`), each
   announced with how long it took. Read one after another, run 5 gave up on both clients that had
   in fact reported. The **driver's** report is an observation in full: never checked, and its
   absence is a note — its suite has no gun and no replay, so it waits out every input budget.

7. **THE GAME FIX: a Shooter with no gun.** Two-player drives, twice: the HUD said SHOOTER,
   `mayCarryWeapon` said armed, and no Tool existed anywhere in the place. Every grant in this system
   is edge-triggered — the drive's phase transitions and the player's `CharacterAdded` — so when the
   answer changes *between* two edges nothing asks again. `Weapon.start` now sweeps every 2 s:
   `armingAction(mayArm, holdsTool)`, the same decision `refreshArming` makes, with `armingSweeps`
   and `armingRepairs` counted. `holdsTool` asks whether the player holds a Tool (`Parent ~= nil`)
   rather than whether one is recorded, and `watchTool` clears the record when a Tool is destroyed
   with the Backpack or character it was in. `Hardware.give` waits for a Backpack and **returns
   whether the tool landed**; `grant` records nothing when it did not (`grantsMissed`).

8. **The assertion that catches it lives with the drive:** `match_live.spec` — "gave the shooters a
   gun they are actually holding, not one on a list" — true at any player count, and the one the
   two-player runs failed. `weapon_rearm.spec` covers the mechanism without touching the live gun:
   the whole truth table of `armingAction`, that the sweep is running, and that it leaves a correctly
   armed player untouched.

9. **Three specs were assuming one player, and two of them were plainly wrong.**
   `weapon_client.spec`'s scenario end state read the newest snapshot ever published rather than the
   one the scenario ended on (Task 30's window-claim pattern); its exploit window's assumption —
   nothing re-arms this player mid-window — is now written down rather than guarded by a dead epoch
   check (a `WeaponSnapshot` carries no epoch, and `weapon_state.spec` asserts that).
   `shoot_boar.spec` waited 45 s for the stage counted from where TestEZ reaches it, while in `test2`
   the replay cannot begin until three processes are classified; 120 s now. `input_driving.spec`
   compared a deliberate gap against the **largest** unwaited one, and a background client window
   renders at ~15 fps (measured: 30 RenderStepped vs 120 Heartbeat in 2 s) — median now.
   `match_teams.spec` and `match_live.spec` are player-count aware.

10. **A truncated console can no longer hide a failure.** Every two-player console came back
    truncated with the evidence in it. `TestKit.note` and the first five failure messages ride in the
    **report**; both modes print `note [side] …` and `failed [side] <spec>:<line> <message>`. That is
    how the cause was finally found, and how the 2-player run now reports `sweeps N -> M`.

## What I could not verify

- **Why the drive's own edges missed, exactly.** The sweep makes the outcome right and the two-player
  run is green, but I never caught the losing sequence in the act: `execute_luau` requires a **fresh**
  module, so `tools[player]`, `stats` and the live phase cannot be read from outside a running server,
  and the console that held the prints was truncated. The notes channel exists because of that.
- **`armingRepairs` has been 0 in every run since.** So the sweep's repair path has not been observed
  doing anything — the fix is proven by the outcome (a green two-player run), not by the counter.
- **The driver's client suite fails by design** (no gun, HUD says DRIVER). It is printed, never
  checked, and its assertions are not role-aware yet — queued as row 34a.
- **The two-player run is the Director's, not mine**: I ran the one-player harness above and read the
  `[harness2]` line from his log.
- **Nothing about a real second player's experience** — a driver pushing a boar toward a shooter — is
  covered. That is still the drive design's §12.8 `NEEDS KAREN`.
