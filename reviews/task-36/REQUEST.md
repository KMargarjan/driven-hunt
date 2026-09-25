# Review request — Task 36: test-suite robustness

Task: 36
Round: 2
Base: `task-35-safety-score` @ `31dfc89` (**stacked**: Task 35 is not merged; the Director merges 35
first, then this)
Code commit: `f69e3ef44de080556d089d42ba9c5cca0c0835ae`
Branch: `task-36-test-robustness`

```
[harness]  PASS: 27/27 checks @ f69e3ef44de080556d089d42ba9c5cca0c0835ae (clean tree)
[harness2] PASS: 30/30 checks @ f69e3ef44de080556d089d42ba9c5cca0c0835ae (clean tree)
```

The two-player run checks **all three** reports: server 263 passed, shooter 69, driver 62, with 0
failed / 0 errors / 0 skipped in each. Before this task the driver's report was printed and checked
against nothing, and 23 of its 67 specs failed by construction.

No `src/` file changed. This task is tests and the harness only.

---

## Round 1's blocking finding, and what it cost to fix properly

**Finding 1 was right, and it was the important kind of right.** My first answer to a flaky exploit
window was to relax its assertions into a conservation law (reserves never grow, no barrel loads
unpaid). `Validator.checkRequest` is the whitelist that makes the reducer's primitives unreachable
from a client — so without it a forged `"Break"` runs the whole `Break → Load → Load → Close` cycle,
and one second later the reserves and the barrels are back where they started. **Every one of the
replacement assertions would have held. The exploit would have passed.**

The strict per-barrel, per-reserve, `open` and `loaded` comparisons are back. What was actually flaky
was the **window**, so that is what changed: it is opened only on a gun no weapon input has touched
for `QUIET` seconds and no action is still running, and it is **discarded and retried** (3 attempts)
if any weapon input arrives while it is open — a real exploit reproduces on every attempt, a replayed
keypress does not — and a window that never comes quiet **fails** rather than passing silently.

Two things that took a run each to find, both now written at the code:
- `not state.open` is never satisfied at all: the replay's last scenario leaves the gun broken open
  and nothing presses anything afterwards.
- `state.busyFor == 0` is not "no action is running". It is a number the **server** computed when it
  published, and the replica does not tick it down — a session's last snapshot said `0.25` for ever.
  Elapsed time since that snapshot arrived is the real test, and the spec already records it.

---

## Claims

1. **The exploit path detects the server acting on a reducer primitive again**, and the window is what
   became robust. *Verify:* `tests/client/weapon_client.spec.luau`, "ignores every request a client
   must not be able to make" — the retry loop, `stillBusy()`, and the seven equality assertions.

2. **The flaky physics claim is measured in the boar's own simulation, and is not weaker.**
   `boar_body.spec`'s "it gets away" was "20 studs of gap inside 3 s of wall clock" and lost that race
   once under harness load. It requires the same 20 studs, opened inside **60 studs of the boar's own
   travel** — a boar that ran three times the distance it gained is not fleeing at any frame rate —
   with a frame-counted bound that can only run out if the body stops. *Verify:*
   `tests/server/boar_body.spec.luau`, "sprints away from a threat, and stays upright", and
   `stepUntil`'s header.

3. **The speed ramp is measured from first sensing, which is what the design says.**
   `docs/design/boar-ai.md` §11 is "≥ 0.5 × `SPRINT_SPEED` **within 1.0 s of first sensing**"; the old
   test started its second when the spec assigned a variable, putting the scheduler's latency inside
   the design's budget. It now waits for the state to become `FLEE` — a decision, no physics — and
   counts 120 frames from there: 1.0 s at 60 Hz, and as much again so one throttled tick cannot decide
   the verdict. Seconds are printed, not asserted.

4. **Same class, same fix, elsewhere.** `boar_hit.spec`'s "reacted in under 100 ms" is now "in fewer
   frames than `SENSE_INTERVAL` is long" — the claim was always "not gated by the sense interval", and
   in milliseconds it was also a claim about the machine. Two tight backstops were widened (the plate
   landing 3 → 6 s, the exit crossing 8 → 30 s). *Verify:* `boar_hit.spec`, "turns and runs from a
   hit"; `boar_body.spec`'s "idles slowly…" and "despawns once when it reaches the exit edge…".

5. **A driver's client asserts its own half of every rule, and skips nothing.** New
   `tests/client/Role.luau` resolves this client's team once, **at require time and before
   `InputReady` publishes the ready attribute**, so the replay can never start against a client that
   does not yet know what it is. The driver's branches assert: no `Tool` in the Backpack or character
   at any point, no `DrivenHunt.Weapon.*` action bound, `Weapon.get()` still `nil`, the crosshair
   never visible, no viewmodel while the camera is aiming, the camera never entering `Aiming` from a
   replayed right mouse button, never staged on a boar, no marker from a shot he cannot fire, and the
   badge reading `DRIVER`. *Verify:* `Role.luau`; `weapon_client.spec` ("the driver's empty hands"),
   `camera_client.spec`, `shoot_boar.spec`, `match_client.spec` (`Role.badge()`).

6. **Both clients get the same input; only one gets the stage.** `replay_input` gained `mirror_ids`,
   so `input_driving.spec` — about the engine delivering real input, not about guns — is true on both.
   The `stage` stays on the shooter because it pivots a character. The ready handshake now waits for
   **every** client, and for 60 s rather than 20, because a client resolves its team before publishing
   ready. *Verify:* `replay_input` in `tools/studio_mcp.py` and its docstring.

7. **`test2` requires PASS from all three reports** — 28 checks became 30 (`[driver] status PASS` and
   `[driver] > 0 passed…`). *Verify:* the report loop in `run_test2`.

8. **A real defect found by running it (rule 6): a start-order race, and the second explanation is the
   right one.** `hit_marker.spec` waited 30 s for the marker `weapon_hits.spec` sends. The server sends
   once, wherever its suite has got to, and a client hears it only if its listener already exists. The
   shooter is immune by accident — he also receives one for every shot he lands — and a driver receives
   nothing else at all. Measured: one two-player run gave the driver **0 markers in 174 s**, the next
   gave him **2 within 14 s**, same code on both sides. Arrival is asserted for the shooter; the driver
   asserts the remote, the Hud's connection and the whole drawing path, and both sides record what they
   sent and saw as notes with timestamps. Queued as row 36a. **My first write-up of this said the wire
   to the second client was broken; the next run falsified that, and the commit that corrected it says
   so.** *Verify:* `hit_marker.spec`'s header and first `it`; `weapon_hits.spec`.

9. **The tie spec no longer touches a driver's camera.** Its cue key now reaches both clients, so
   `onCue` ignores a client that is not the shooter — `camera_client.spec` is asserting about that
   camera at the same moment. *Verify:* `zz_tie_to_a_tree.spec`, `onCue`.

10. **Replay-driven budgets raised where the doubled replay made them tight**, each with the reason at
    the constant: `shoot_boar` 120 → 210 s, `zz_tie_to_a_tree` 150 → 240 s, `input_driving` 25 → 45 s,
    `weapon_client` 40 → 70 s. None is an assertion; they are how long a spec waits for input in flight.

---

## Round 1's non-blocking notes, all addressed

Claim 7's "26 checks" was wrong (28 → 30, corrected above); the docstring's three stale sentences and
`REPORT_WINDOW_2P`'s comment; `zz_tie`'s two falsified comments (plus claim 9, which was a real
consequence, not only a comment); the two role halves are named so a report says which ran, and the
shooter's half now asserts something; `hit_marker`'s header carries the caveat, not only the `it`;
`replay_input`'s step counter no longer counts one step twice; and `TASKS.md` row 35's "271 server
`it` blocks" is corrected to the measured 263.

## What could not be verified, and what is wrong

- **The start-order race in claim 8 is contained and recorded, not fixed.** A longer window cannot
  catch an event that was already over. The fix is a send the client can ask for, or a server that
  keeps sending until every client has seen one; row 36a carries it, and it is worth settling before
  release because every hit marker in the real game is a targeted `FireClient`.
- **`Role` is resolved from `Player.Team` and nothing else**, so a client takes the driver's branch
  because the drive says he is a driver, not because the server refused him a gun. The two agree only
  while `Match.CONFIG.DRIVERS_MAY_SHOOT` is false; `Role.luau` names that premise, and
  `tests/server/match_teams.spec.luau` checks the server's side. An unknown team deliberately takes
  the shooter's branch, so a drive stuck in `Waiting` fails loudly rather than quietly passing a
  driver's assertions.
- **The code commit is a paperwork-only commit.** `f69e3ef` adds `reviews/task-36/RESULT.md` on top of
  `9160fd4`, which is the last commit that changed a test or the harness; the two trees are identical
  under `src/`, `tests/` and `tools/`. Both harness lines name `f69e3ef`, which is the tree that ran.
- **The two-player mode still needs one human click** (`Test → Clients and Servers → Players: 2 →
  Start`) and a Cleanup afterwards. Unchanged by this task.
- **No screenshot.** Nothing drawn changed. Rule 5 N/A.
