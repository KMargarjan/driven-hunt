# Review request — Task 36: test-suite robustness

Task: 36
Round: 1
Base: `task-35-safety-score` @ `31dfc89` (**stacked**: Task 35 is not merged; the Director merges 35
first, then this)
Code commit: `f03e7cd373c805eed98f02221dacc425080611b6`
Branch: `task-36-test-robustness`

```
[harness]  PASS: 27/27 checks @ f03e7cd373c805eed98f02221dacc425080611b6 (clean tree)
[harness2] PASS: 30/30 checks @ f03e7cd373c805eed98f02221dacc425080611b6 (clean tree)
```

The two-player run now checks **all three** reports: server 263 passed, shooter 69 passed, driver 62
passed, 0 failed / 0 errors / 0 skipped in each. Before this task the driver's report was printed and
checked against nothing, and 23 of its 67 specs failed by construction.

No `src/` file changed. This task is tests and the harness only.

---

## Claims

1. **The flaky claim is now measured in the boar's own simulation, and it is not weaker.**
   `boar_body.spec`'s "it gets away" was "20 studs of gap inside 3 s of wall clock" and lost that race
   once under harness load. It now requires the same 20 studs of gap, opened inside **60 studs of the
   boar's own travel** — a boar that ran three times the distance it gained is not fleeing at any
   frame rate — with a 30-second backstop that can only fire if the body does not move at all, and a
   print of both numbers. *Verify:* `tests/server/boar_body.spec.luau`, "sprints away from a threat,
   and stays upright", and the `stepUntil` helper's header.

2. **The speed ramp is measured from first sensing, which is what the design says.**
   `docs/design/boar-ai.md` §11: "body reaches ≥ 0.5 × `SPRINT_SPEED` **within 1.0 s of first
   sensing**". The old test started its 1.0 s when the spec assigned a variable, so the scheduler's
   own latency was inside the design's budget. It now waits for the state to become `FLEE` — the
   decision, with no physics in it — and counts **frames** from there: 120, which is 1.0 s at 60 Hz
   plus as much again so a throttled tick cannot decide the verdict. Seconds are printed, not
   asserted. *Verify:* the same `it`.

3. **Same class, same fix, elsewhere.** `boar_hit.spec`'s "reacted in under 100 ms" is now "in fewer
   frames than `SENSE_INTERVAL` is long" (12 at 60 Hz) — the claim was always "not gated by the sense
   interval", and in milliseconds it was also a claim about the machine. Two backstops that were
   tight rather than wrong were widened (the plate landing, 3 → 6 s; the exit crossing, 8 → 30 s).
   *Verify:* `tests/server/boar_hit.spec.luau`, "turns and runs from a hit"; `boar_body.spec`'s
   "idles slowly…" and "despawns once when it reaches the exit edge…".

4. **A driver's client now asserts its own half of every rule, and skips nothing.** New
   `tests/client/Role.luau` resolves this client's team once, **at require time and before
   `InputReady` publishes the ready attribute**, so the replay can never start against a client that
   does not yet know what it is. The driver's branches assert: no `Tool` in the Backpack or the
   character at any point, no `DrivenHunt.Weapon.*` action bound, `Weapon.get()` still `nil`, the
   crosshair never visible, no viewmodel while the camera is aiming, the camera never entering
   `Aiming` from a replayed right mouse button, never staged on a boar, no marker from a shot he
   cannot fire, and the Hud badge reading `DRIVER`. *Verify:* `tests/client/Role.luau`;
   `weapon_client.spec` ("the driver's empty hands"), `camera_client.spec` ("cannot be aimed at all
   by a driver…" and the viewmodel `it`), `shoot_boar.spec` ("staged nobody on this client…"),
   `match_client.spec` (`Role.badge()`), `zz_tie_to_a_tree.spec` (already role-aware, Task 35).

5. **Both clients get the same input; only one gets the stage.** `replay_input` gained `mirror_ids`
   and sends every batch to each client in turn, so `input_driving.spec` — which is about the engine
   delivering real input, not about guns — is true on both. The `stage` stays on the shooter because
   it pivots a character, and two characters staged onto one boar is a scrum. *Verify:*
   `replay_input` in `tools/studio_mcp.py` and its docstring; the `[input] replayed every step…`
   line now reads "sent to 2 client(s)".

6. **The ready handshake waits for every client, and waits longer.** 20 s → 60 s, because a client
   now resolves its team before publishing ready, and a one-player `test` writes its token before
   Play — so the handshake really does wait for the drive to assign teams. A replay into a client
   that has not bound its listeners proves nothing there. *Verify:* `replay_input`'s `targets` loop.

7. **`test2` requires PASS from all three reports.** The driver's is evidence like any other, and a
   missing one is a failure. *Verify:* the report loop in `tools/studio_mcp.py` (`run_test2`), and
   the 30/30 line above — it was 26 checks before.

8. **A real defect found by running it (rule 6), and the explanation is the second one, not the
   first.** `hit_marker.spec` waited 30 s for the marker `weapon_hits.spec` sends. That is a
   **start-order race**: the server sends once, wherever its suite has got to, and a client hears it
   only if its listener already exists. The shooter is immune by accident — he also receives one for
   every shot he lands, all session — and a driver receives nothing else at all. Measured: one
   two-player run gave the driver **0 markers in 174 s**, the next gave him **2 within 14 s**, same
   code on both sides. So arrival is asserted for the shooter; the driver asserts the remote, the
   Hud's connection and the whole drawing path, and both sides record what they sent and saw as
   harness notes with timestamps. Queued as row 36a. *Verify:* `tests/client/hit_marker.spec.luau`
   header and the first `it`; `tests/server/weapon_hits.spec.luau`, "fires the one-way remote…".

9. **The exploit window is a conservation law now, not a frozen snapshot.** Its own comment already
   said it assumed nobody re-armed the player inside it — and with the replay going to two clients it
   takes twice as long, so the last scenario's reload landed in the window and spent two shells. That
   is the gun working, and it failed the test. It now asserts what an exploit would actually break
   and a legitimate reload cannot: reserves never grow, the ammo kind stays one that exists, the
   barrel count is unchanged, and **no barrel is loaded that a shell was not spent on**.
   *Verify:* `weapon_client.spec`, "ignores every request a client must not be able to make".

10. **Replay-driven budgets were raised where the doubled replay made them tight**, each with the
    reason at the constant: `shoot_boar` 120 → 210 s, `zz_tie_to_a_tree` 150 → 240 s, `input_driving`
    25 → 45 s, `weapon_client` 40 → 70 s. None of them is an assertion; they are how long a spec waits
    for input that is in flight.

---

## What could not be verified, and what is wrong

- **The start-order race in claim 8 is not fixed, only contained and recorded.** A longer window
  cannot catch an event that was already over. The fix is a send the client can ask for, or a server
  that keeps sending until every client has seen one; neither belongs in a robustness task, and row
  36a carries it. Every hit marker in the real game is a targeted `FireClient`, so it is worth
  settling before release.
- **`Role` is resolved from `Player.Team` and nothing else**, so a client asserts the driver's
  branch because the drive says he is a driver — not because the server refused him a gun. The two
  agree only while `Match.CONFIG.DRIVERS_MAY_SHOOT` is false; the comment in `Role.luau` names that
  premise, and `tests/server/match_teams.spec.luau` is what checks the server's side of it.
  An unknown team deliberately takes the shooter's branch, so a drive stuck in `Waiting` fails loudly
  rather than quietly passing a driver's assertions.
- **The two-player mode still needs one human click** (`Test → Clients and Servers → Players: 2 →
  Start`) and a Cleanup afterwards. Unchanged by this task; the Director's script sends both.
- **No screenshot.** Nothing drawn changed. Rule 5 N/A.
