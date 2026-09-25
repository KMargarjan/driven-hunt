# Task 6 — the harness drives real player input

Task: 6
Round: 1
Base: `a7e4745`
Code commit: `043fc7b8b27bfa80c3bb2c4d1e97229471bf1893`

```
[harness] PASS: 26/26 checks @ 043fc7b8b27bfa80c3bb2c4d1e97229471bf1893 (clean tree)
```

## Task

Director, 2026-09-25 (verbatim in `TASKS.md`): the smallest version of harness-driven input, exactly
as `docs/design/shotgun.md` §13.3 asks for — a key down and up, a mouse button down and up, and two
inputs in sequence with an observable gap — plus making captures saveable, which closes row 7.
Blocking before the shotgun build.

## What changed

| File | What |
|---|---|
| `tests/client/input_scenarios.txt` | **new.** The scenario, JSON in a `.txt` |
| `tests/client/input_driving.spec.luau` | **new.** Binds CAS + UIS, records, asserts |
| `tools/studio_mcp.py` | `replay_input`, `scenario_batches`, `load_scenarios`, `Studio.send_input`, `Studio.capture`, the `capture` command, and the docstring |
| `.gitignore`, `CLAUDE.md`, `docs/research/2026-09-24-toolchain.md`, `TASKS.md` | `.screenshots/`, the two Run/test bullets, the research addendum, rows 6 and 7 plus the dispatch |

## Claims

1. **It ran, and the input arrived.** The harness line above is a clean-tree PASS on the code commit,
   with 26 checks (24 before, plus `[input] the client bound its listeners and published this run's
   token` and `[input] replayed every step of 1 scenario(s) (6 steps sent)`), and 11 client assertions
   where there were 4. **Verify:** the two new `check(...)` calls in `replay_input`.

2. **The input came through the path a player's input takes.** `input_driving.spec.luau` binds
   `ContextActionService:BindAction` over `Enum.KeyCode.F`, `Enum.KeyCode.R` and
   `Enum.UserInputType.MouseButton1`, and connects `UserInputService.InputBegan/InputEnded/
   InputChanged`. Every assertion is over `log`, which only those engine callbacks write — `record` is
   called from nowhere else, and no test calls a handler. **Verify:** grep `record(` in that file.

3. **The three things §13.3 asks for are each asserted.** `saw the key press and release as separate
   events` (one `Begin`, one `End` for `F`); `saw the mouse button through ContextActionService, and
   the move through UserInputService` (two CAS `MouseButton1` events, at least one UIS
   `MouseMovement`); `carried the scenario's gap` — the gap around the scenario's `wait` step is
   ≥ 0.6 × the requested 700 ms **and** strictly larger than every unwaited gap in the same run.

4. **The order is asserted, not just the arrival.** `matchInOrder` walks the recorded log once,
   consuming expectations in sequence, so the events must occur in the scenario's order; the last
   assertion then compares each matched entry field by field against `expectedFrom(steps)`.

5. **The scenario is one file, read by both sides.** The harness reads
   `tests/client/input_scenarios.txt` from disk (`load_scenarios`); the spec reads the same file as
   `ReplicatedStorage.ClientTests.input_scenarios` and derives its expectations from it
   (`expectedFrom`). Nothing is duplicated between them: change the steps and both sides follow.

6. **A `.txt` holding JSON, on purpose.** Rojo maps a `.txt` to a `StringValue`, which the harness
   already compares byte-for-byte (docstring, "What `test` checks", step 4), so the client provably
   reads the file on disk. The alternative — a `.json` or a probe `LocalScript` — needs a new
   `default.project.json` mapping, which the running `rojo serve` does not reload: a restart, and
   Karen's Connect click. Recorded as a Builder's note under the dispatch in `TASKS.md`.

7. **The replay cannot race the bindings.** The spec binds at require time (module body, before TestEZ
   runs) and then publishes `TestKit.openToken()` on `LocalPlayer` under the scenario's
   `readyAttribute`; `replay_input` waits up to 20 s for that attribute to equal **this run's** token
   before sending anything, so a stale attribute cannot be mistaken for a fresh one. **This was found
   by running it:** the first run sent all six steps into a client that recorded nothing, because
   `QUERY_READY` was built with `luau_json`, which asks for an attribute whose name includes the JSON
   quote characters. The fix is a plain Luau literal plus an identifier check on the name.

8. **Gated exactly like the specs.** The replay happens only inside `test`, only between that run's
   `set_play(True)` and `set_play(False)`, and only after a token handshake; the spec only listens
   because the gated runner required it. Karen's playtests neither replay nor record.

9. **Captures can be saved (row 7).** `Studio._call` joins text blocks and drops the image, which is
   why no capture could be saved. `Studio.capture` reads the image block and writes it;
   `python tools/studio_mcp.py capture <name> [camera x,y,z] [look-at x,y,z]` saves to
   `.screenshots/<UTC stamp>-<name>.png`, now git-ignored. Run three times on 2026-09-25: twice in
   **Edit** (correctly empty grey — since Task 22 `Workspace` holds only `Camera` and `Terrain`, and
   the arena is built at run time) and once during **Play**, where I looked at the file and saw the
   400×400 arena plate as a full square. It is a separate command, not part of `test`.

10. **The docstring is still the single source of truth.** It gained the scenario format, the replay
    sequence, what a scenario **cannot** express, step 7a, the capture command and the safety note;
    `CLAUDE.md` points at it in two bullets rather than restating it. The research addendum in
    `docs/research/2026-09-24-toolchain.md` holds the sources, the pattern and the measurements.

## What I could not verify

- **Whether a scenario step reaches a client that is not focused, or in a different Studio layout.**
  Every run here had Studio open on this machine with the place in the foreground.
- **Holds measured in frames, touch, gamepad, `textInput`, and `instance_path`-targeted input.** The
  format cannot express them and the harness does not send them; listed in the docstring.
- **An unexplained one-off:** the very first run of this session (before the handshake fix, on a dirty
  tree) reported `[server] 38 passed, 1 failed, 1 errors` in the boar specs. The three runs after it,
  including the clean-tree PASS above, were 39/39 with no server failure, and nothing in this change
  touches `src/`. I could not recover which assertion it was, so I am reporting it rather than
  explaining it (rule 8).
