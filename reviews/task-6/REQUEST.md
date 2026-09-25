# Task 6 — the harness drives real player input

Task: 6
Round: 1
Base: `a7e4745`
Code commit: `1b0e8fa1ccc1381cb9e02f3858c52109cdbedab9`

```
[harness] PASS: 26/26 checks @ 1b0e8fa1ccc1381cb9e02f3858c52109cdbedab9 (clean tree)
```

**This is the SECOND review of Task 6**, and the last: the dispatch allows two rounds. It says
`Round: 1` because `tools/agents.py` restarts the count after a `PASS` (`expected = 1 if prev_rnd is
None or prev_verdict == "PASS"`), and the first review passed with nine notes. I fixed the notes
rather than queueing them, which moved `tests/` and `tools/` after the reviewed commit, so the merge
gate needs this commit reviewed. The counter's blind spot — a re-review after a `PASS` cannot be
numbered 2 — is recorded for the Director in `TASKS.md` under Task 21a.

## Task

Director, 2026-09-25 (verbatim in `TASKS.md`): the smallest version of harness-driven input — a key
down and up, a mouse button down and up, and two inputs in sequence with an observable gap — plus
saveable captures, closing row 7. Blocking before the shotgun build.

## What changed

| File | What |
|---|---|
| `tests/client/input_scenarios.txt` | **new.** The scenario: JSON in a `.txt` |
| `tests/client/input_driving.spec.luau` | **new.** Binds CAS + UIS, records what the engine delivers, asserts |
| `tools/studio_mcp.py` | `load_scenarios`, `check_step`, `scenario_batches`, `replay_input`, `Studio.send_input`, `Studio.capture`, the `capture` command, the docstring |
| `.gitignore`, `CLAUDE.md`, `docs/research/2026-09-24-toolchain.md`, `docs/research/INDEX.md`, `TASKS.md` | `.screenshots/`, two Run/test bullets, the research addendum and its INDEX row, rows 6 and 7 plus the dispatch |

## Claims

1. **It ran.** The harness line above is a clean-tree PASS on the code commit: 26 checks (24 before,
   plus `[input] the client bound its listeners…` and `[input] replayed every step…`), 39 server and
   11 client assertions where the client had 4.

2. **The input arrives through the path a player's input takes.** The spec binds
   `ContextActionService:BindAction` over `F`, `R`, `MouseButton1` and `MouseButton2`, and connects
   `UserInputService.InputBegan/InputEnded/InputChanged`. Every assertion reads `log`, which only
   those engine callbacks write — `record(` appears nowhere else, and nothing calls a handler.

3. **The three things the design asks for are each asserted:** the key's press and release as separate
   events; the mouse button through CAS and the move through UIS; and the scenario's 700 ms gap, which
   must be ≥ 0.6 × asked **and** strictly larger than every unwaited gap in the same run. Order is
   asserted too, field by field, by `matchInOrder` against `expectedFrom`.

4. **One scenario file, read by both sides.** `load_scenarios` reads
   `tests/client/input_scenarios.txt` from disk; the spec reads the same bytes as
   `ReplicatedStorage.ClientTests.input_scenarios` and derives its expectations with `expectedFrom`.
   It is a `.txt` holding JSON because Rojo makes a `.txt` a `StringValue` the harness already compares
   byte-for-byte — so the client provably reads the file on disk — and because any other shape needs a
   `default.project.json` mapping, which the running `rojo serve` does not reload (a restart, and
   Karen's Connect click).

5. **A step neither side understands cannot pass silently.** `check_step` refuses an unknown device or
   action, a missing `key` or `button`, a non-numeric `moveTo`, or a `wait` outside StudioMCP's
   0..10000 ms — at load time, before Play. `expectedFrom` returns errors for the same cases and the
   first `it` asserts there are none. I checked the five refusals directly against the committed
   module.

6. **The replay cannot race the bindings.** The spec binds in its module body (required before TestEZ
   runs) and publishes `TestKit.openToken()` on `LocalPlayer`; `replay_input` waits up to 20 s for that
   attribute to equal **this run's** token before sending. The first run of this task sent everything
   into a client that recorded nothing, because the attribute-name query was built with `luau_json` and
   asked for a name containing quote characters; the handshake check is what named it in one line.

7. **The mouse position is per call, not per session.** Moving the scenario's `wait` between the move
   and the click split them into two `user_mouse_input` calls and StudioMCP refused the second
   ("Either x and y, instance_path, or a prior action that establishes mouse position is required").
   `scenario_batches` now carries the last position into every later mouse action. Found by running it,
   not by reading.

8. **Gated exactly like the specs.** The replay happens only inside `test`, only between that run's
   `set_play(True)` and `set_play(False)`, and only after the token handshake; the spec listens only
   because the gated runner required it. Karen's playtests neither replay nor record. A failing or
   hung StudioMCP call fails the `[input]` check — `except Exception`, because `_rpc` raises
   `queue.Empty` — rather than aborting the run.

9. **Captures can be saved (row 7).** `Studio._call` joins text blocks and dropped the image.
   `Studio.capture` reads the image block; `python tools/studio_mcp.py capture <name> [camera x,y,z]
   [look-at x,y,z]` writes `.screenshots/<UTC stamp>-<name>.png`, git-ignored. Run three times on
   2026-09-25: twice in **Edit** (correctly empty grey — `Workspace` holds only `Camera` and `Terrain`
   since Task 22, and the arena is built at run time) and once during **Play**, where I opened the file
   and saw the 400×400 plate as a full square.

10. **The docstring stays the single source of truth**, with the scenario format, the replay sequence,
    the validation rule, what a scenario **cannot** express, step 7a, the capture command and the
    safety note. `CLAUDE.md` points at it; the research addendum holds the sources, the pattern and the
    measurements, and `INDEX.md`'s toolchain row names it.

## What I could not verify

- **Input into an unfocused or differently sized Studio window.** Every run had this Studio in the
  foreground on this machine.
- **Touch, gamepad, `textInput`, frame-counted holds, `instance_path` targeting.** Not expressible and
  not sent; `mouseButtonClick` and `"button": "right"` are validated and mapped on both sides but no
  committed scenario sends them.
- **A stray human mouse move** satisfies a `MouseMovement` expectation as well as the replayed one.
  The two CAS button events still pin the run to the replay, and the scenario now puts its `wait`
  after the move so an early stray move can only lengthen the waited gap. Written at `matchInOrder`.
- **An unexplained one-off:** the first run of this session (before the handshake fix, dirty tree)
  reported `[server] 38 passed, 1 failed, 1 errors` in the boar specs. Every run since — five,
  including three clean-tree PASSes — was 39/39, and nothing here touches `src/`. Reported rather than
  explained (rule 8).
