# Task 184 -- the rifle's bolt takes a second longer after each shot

Task: 184
Round: 1
Base: 84a37ca (main)
Code commit: 826b0d3ac212e0a70f76dd7130babdb9cb1a3dde

Harness, FULL, twice, clean tree, at the code commit:

```
[harness] PASS: 33/33 checks @ 826b0d3ac212e0a70f76dd7130babdb9cb1a3dde (clean tree) scope=all
[harness2] N/A
```

`.agent-logs/task184-r1-test1.log` and `.agent-logs/task184-r1-test2.log`.

**`test2` is N/A.** The code `git diff --name-only 84a37ca..HEAD` touches is
`src/shared/Rifle/init.luau`, `src/shared/Viewmodel/poses.json`,
`src/server/Weapon/StateMachine.luau`, `src/server/Weapon/init.luau`,
`tests/server/rifle.spec.luau` and `tests/server/camera_mode.spec.luau`. **No path in
`TWO_PLAYER_PATHS` is touched** (Director, 2026-10-03): no `src/server/Match/`, no `MatchBoot`, no
`src/client/Match/`, no `src/shared/Drive/`, no `tests/client/Role.luau`, no `match_*.spec`, no
`zz_drive_boundary.spec`, no `match_client.spec`, no `outfit_client.spec`, no
`zz_tie_to_a_tree.spec`.

## What changed, and why

Karen, 2026-10-14 ~20:10: *"I think it reloads to fast has to be 1 s slower"* -- and, asked which of
the rifle's two sequences she meant: *"Bolt after each shot"*. So the bolt worked after every shot
grows by a second and the magazine change does not.

Two things had to move together, and the second is the interesting half. The SERVER's window is
`Rifle.CONFIG.CYCLE`. The DRAWN bolt is a separate pair of numbers in `poses.json`
(`weapons.rifle.cycle.openSeconds` / `closeSeconds`), tuned to fit inside the OLD windows, and the
only thing tying them together was an inequality (`rifle.spec`: the stroke is shorter than the step)
which the old pair satisfied all the way up. Scaling one and not the other would have snapped the
bolt back in 0.18 s and left it standing still for 0.50 s, then home in 0.14 s and still for 0.80 s,
twice per shot -- an idle gap, not a slower bolt.

And making the two lists disagree broke an invariant `StateMachine.waitFor` relied on, which is the
one defect in this task that was not a number.

## Claims

1. **The bolt is a second longer.** `Rifle.CONFIG.CYCLE_TOTAL` is `1.62`, `CYCLE` is `Break 0.68` +
   `Close 0.94`, and the two steps are the old `0.26` / `0.36` scaled by the same `1.62/0.62` so the
   split does not move. Verify: `src/shared/Rifle/init.luau`, `CONFIG.CYCLE` and `CYCLE_TOTAL` --
   Karen's sentence is the comment above them and the old rationale is kept in its own line.
   `tests/server/rifle.spec.luau`, "carries the rifle's own action, which is a BOLT", asserts the
   sum against the list AND pins 1.62.

2. **`RELOAD` is untouched**, per the dispatch (*"DO NOT change them without Karen"*): still
   `Magazine 1.35` + `Break 0.26` + `Close 0.36`, `RELOAD_TOTAL = 1.97`. Verify the same file. The
   same spec case asserts `RELOAD[2].wait < CYCLE[1].wait` and `RELOAD[3].wait < CYCLE[2].wait`, so
   that they now differ is asserted rather than incidental. **What I say about it, which the dispatch
   asked for:** the last two steps of the magazine change ARE a bolt cycle (Karen, task 142: *"then
   the right hand cycles the bolt to chamber"*), so matching the new pace -- `0.68` / `0.94`,
   `RELOAD_TOTAL` `2.97` -- is the consistent reading. Her call; queued as `TASKS.md` 184a.

3. **`StateMachine.waitFor` takes the sequence being run, and that is a defect fix, not a
   refactor.** It searched `{ row.CYCLE, row.RELOAD }` first-match. `Break` and `Close` are in BOTH
   of the rifle's lists; while they carried the same waits in each the order decided nothing (the old
   comment said exactly that), and the moment they differ it decides everything -- the magazine
   change would have been charged the bolt's 0.68 s window, `runCycle` would have waited its own
   0.26 s, asked for `Close`, been refused `"busy"`, and finished the reload down its
   error-recovery path instead of its own. Verify: `src/server/Weapon/StateMachine.luau` `waitIn` /
   `waitFor` and the new `steps` parameter on `StateMachine.apply`; `src/server/Weapon/init.luau`
   `runCycle` passes `sequence` at both `apply` call sites.

4. **That parameter is additive and nil is the old behaviour exactly.** `apply`'s `steps` is
   optional; with nothing passed the search order is `CYCLE` then `RELOAD`, as before. The shotgun
   has one sequence, so both answers are the same number and it cannot tell the difference. Verify:
   `tests/server/rifle.spec.luau`, "charges each sequence its OWN window, now that the two
   disagree" -- it drives the reducer with `row.RELOAD`, with `row.CYCLE`, with nothing, and with
   the shotgun.

5. **A step that waits 0 s is not walked past.** `waitIn` answers `nil`, not `0`, for "this list has
   no step of that kind", so `waitFor` tells an absent kind from a zero wait. Verify `waitIn`'s two
   `return nil`s and `waitFor`'s `wait == nil` tests in `src/server/Weapon/StateMachine.luau`.

6. **The drawn bolt follows the new window.** `poses.json` `weapons.rifle.cycle.openSeconds`
   `0.18 -> 0.62` and `closeSeconds` `0.14 -> 0.88`, which fills each new step with about the same
   0.06 s of travel-complete dwell the old pair had inside the old steps. Verify
   `src/shared/Viewmodel/poses.json`, and `tests/server/rifle.spec.luau` "draws faster than the
   server's own steps" -- unchanged, derived from `row.CYCLE`, still passing.

7. **The idle gap is MEASURED, through the real client reducer.** A new case drives `Mode.step` at
   1/60 with the rifle's own view overlaid on the first-person config the way `Camera.Config` builds
   the shotgun's, counts the frames the bolt takes to reach full travel and to come home, and
   asserts the time it spends standing still is under 0.1 s. It prints what it measured:
   `rifle bolt: drawn 0.63 s back + 0.88 s forward in a 1.62 s cycle, 0.10 s idle`, in both logs.
   Verify `tests/server/camera_mode.spec.luau`, "draws the rifle's bolt across the WHOLE of the
   server's new window", and `rifleFirstPerson` at the top of that file.

8. **The fire-rate gate follows the config and is not typed twice.** The next shot is gated by
   `state.busyUntil`, which `apply` sets from the step's own wait, and `runCycle` sleeps `step.wait`;
   neither carries a number of its own. Verify: `grep -rn "CYCLE_TOTAL" src/` is the config, the
   `Weapons` type and the `Weapons` row, and the only literal outside the config is the pin in
   `rifle.spec` (claim 1).

9. **What I got wrong on the way, because it is in the history and it matters.** The first cut of
   claim 3 wrote `ipairs({ steps, row.CYCLE, row.RELOAD })`. `ipairs` stops at a nil element, so
   with `steps` nil it iterated NOTHING and every busy window became 0 -- the gun was never busy
   after any step. Three timing cases in `rifle.spec` failed, including the one added in claim 4 to
   assert that nil is the old behaviour. Commit `c4a2cfc` is the fix and the comment above `waitIn`
   records it.

10. **No research note, and no new system.** This is a dial Karen named, on a system that already
    has its note (`docs/research/2026-10-10-rifle-bolt-magazine-sound.md`) and its design
    (`docs/design/rifle.md`). The design's section 13 table still records the pre-task-142 proposal
    (0.90 s, `Break`/`Load`/`Close`), so it was already behind the code before this task;
    `docs/design/` is the Architect's and I did not touch it.

## What I could NOT verify

- **The feel.** Nobody here has worked the bolt. Karen judges whether 1.62 s is the second she
  asked for, and whether the stroke now reads as a bolt rather than a pause.
- **A live trigger pull in Play.** The dispatch asked for the stroke measured on the player's path in
  Play. The harness's Play session is the only thing that can drive real input into a client
  (`tests/client/input_scenarios.txt`), and there is no rifle scenario in it -- adding one plus a
  client timing spec is a bigger change than this task, and it would touch the shared scenario file.
  What claim 7 measures instead is the real client reducer at a real frame rate on the real data,
  which is how `camera_mode.spec` has tested the camera since task 90; the server half of the chain
  (when `open` goes true and false) is asserted by `rifle.spec`'s timing cases.
- **A screenshot (rule 5).** The change is a DURATION. A still frame shows the pose, and the pose did
  not move. The measurement in claim 7 is the evidence instead.
