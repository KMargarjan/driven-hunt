# Task 134 - the Hud must not lose the match

Task: 134
Round: 1
Base: main (`dbab8b2`)
Code commit: `af5209306a1ae3b72865df21747408f65be9efa8`

```
[harness] PASS: 33/33 checks @ af5209306a1ae3b72865df21747408f65be9efa8 (clean tree) scope=all
```

`test2` is N/A: this change touches no path in `TWO_PLAYER_PATHS`. The files are
`src/client/Hud/init.luau`, `src/client/Hud/ReportPanel.luau`, a new `tests/client/` spec and one
line of `tools/studio_mcp.py`'s scope table -- `src/client/Match/` and `MatchBoot` are untouched, and
the harness itself is deliberately outside that list (Director, 2026-10-03).

## What changed

Task 133's queued row 133c. `Hud.start` read `PlayerScripts.Match` with `FindFirstChild` **on the
line after it WAITED for `PlayerScripts.Camera`** -- under a comment that describes this exact race
and exists because of it (task 123 round 7: the crosshair that would not go away). `PlayerScripts` is
replicated and its children arrive in no defined order, so a boot that lost the race left
`MatchSystem` nil **for the session** and none of the drive's three connections was ever made.

## Claims

1. **"Not there yet" is not "not there at all", and it is now one function.**
   `Hud.whenReady(container, name, use)` calls `use` **at once** when the child is already there --
   the common case, costing exactly the `FindFirstChild` it replaced -- and otherwise from a spawned
   bounded wait, so `Hud.start` is never blocked by a system the Hud is designed to work without.
   Verify: `Hud.whenReady` in `src/client/Hud/init.luau`.
2. **A system that never arrives is a WARNING, not a silence.** `whenReady` warns on its timeout, and
   the two lookups beside it that already waited -- `Camera` and `Report` -- now warn when their own
   5 s bound expires. They are otherwise untouched: `CameraSystem` is read synchronously a few lines
   below, so moving it to `whenReady` would mean moving what reads it, which is a bigger change than
   this bug needs.
3. **The drive's wiring is one idempotent call.** `Hud.useMatch` holds the `Changed` connection, the
   `Feed` connection, the quarter-second Heartbeat clock and the first `renderDrive` -- all of which
   used to be inline in `start`, which is precisely why they could only ever happen at start. A
   second call connects nothing twice, so the early path and the late path cannot both land.
4. **A late match still reaches the report panel.** The panel reads the points column off the match
   (`docs/design/drive-report.md` section 8.1) and is built further down `start`. In the common case
   `matchSystem` is already set when the panel is built and it is handed over as before; otherwise
   `ReportPanel.setMatch` -- one setter, the Hud its only caller -- gives it to the panel afterwards,
   instead of leaving the report scoreless for the session.
5. **THE SWEEP THE TASK ASKED FOR FOUND A SECOND ONE IN THE SAME OWNER, and it is fixed here.** The
   compass's DRIVE bearing read `ReplicatedStorage.ForestTest` with `FindFirstChild` too, so a lost
   race meant a compass with no marker on it -- the thing Karen asked for in task 125 (*"we need to
   indicate from what side drive is comming"*), quietly not there. Same `whenReady`;
   `Compass.setBearing` is already public, so a late answer reaches it.
6. **The rest of the sweep is clean, and is written down so it is not re-done.**
   `Camera/Poses.luau`'s `ReplicatedStorage:FindFirstChild("Viewmodel")` is re-read **every frame**
   inside `Poses.config`, so a late arrival is picked up -- not a race. `ReportPanel`'s
   `row:FindFirstChild("Text"/"Silhouette")` and `Weapon/Effects.luau`'s
   `Workspace:FindFirstChild("WeaponEffects")` look up children those files created themselves.
   **One real one is left for a later task because it is not the Hud's owner:**
   `src/client/Camera/Rig.luau` resolves `PlayerScripts` and `PlayerModule` with `FindFirstChild`, so
   a `PlayerModule` that has not replicated reads as "nothing to disable" and the stock camera is
   left running against ours. TASKS row 134a, with the number that makes it worth looking at.
7. **The spec drives the race itself.** `tests/client/hud_boot.spec.luau`, "connects to a system that
   arrives AFTER it looked": a container of the spec's own, the lookup, then the child a quarter of a
   second later, then the assertion that the callback still ran with it. A spec cannot make the real
   `PlayerScripts.Match` arrive late, and it cannot fabricate a module either -- `Source` is not
   writable outside a plugin -- which is why `whenReady` takes the container and the name rather than
   a module.
8. **MEASURED LOAD-BEARING.** With the spawned-wait arm of `whenReady` deleted -- the old
   `FindFirstChild`-only behaviour -- the suite reports **`154 passed, 1 failed, 1 errors`** against
   `155 passed, 0 failed, 0 errors`, and the failure is that case
   (`hud_boot.spec:93`, "Expected true, got false": the callback never ran). Restored with
   `git checkout`; the tree is clean at the code commit.
9. **The live claim is asserted too**, and it is the one that would have caught the bug where it
   happened: `Hud.driveConnected()` is true in this session. It had to be added because every other
   Hud case passes happily with no match at all -- "no drive" and "no drive SYSTEM" draw the same
   nothing. The same shape as the source assertion `camera_client.spec` gained in task 133.
10. **The spec leaves nothing behind.** Its containers are **never parented** -- `ReplicatedStorage`
    is Rojo-owned, and `WaitForChild`/`FindFirstChild` do not care whether the container is in the
    DataModel -- and each case destroys its own inside a `pcall`, so a failing assertion cannot leave
    this spec's rubbish in the session either.

## What could not be verified

- **The race itself was not reproduced on the real `PlayerScripts.Match`.** It is a replication race,
  so it cannot be made to happen on demand; task 133 measured its sibling in `CameraBoot` at 4
  failures in 10 fresh Plays, and this is the same shape in the same kind of lookup. What is proved
  here is the RULE (`whenReady`, both arms) and the live state (`driveConnected`).
- **The timeout arm of `whenReady` is not asserted.** `LATE_MODULE_SECONDS` is 10, so a case for it
  would add ten seconds to every client run to prove a `warn`.
- **Standing rule A was run in the Forest Test**, 85 s: the Tool in the CHARACTER at 15 s and at the
  end (`tool=true backpack=false` both times), **0 fault lines in 24**, and four wave lines released.
  The feature that must be seen there is the compass: `compass=true driveMark=true(true)` -- the
  DRIVE marker built and visible, which is claim 5 working. The **drive bar** is correctly invisible
  in that world (`drive=false`): the Forest Test has no Match drive, `ForestTestBoot` owns the place.
  The drive-bar half is evidenced by the gate's own run in DEV, where `hud_boot` notes "the Hud is
  connected to the drive".
