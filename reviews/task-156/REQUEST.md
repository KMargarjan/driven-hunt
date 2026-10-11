# Task 156 — review request: kill the flakes in the one-player gate

Task: 156
Round: 1
Base: `5a097fc` (main, after #138)
Code commit: `a82235a5d3087cbd67289dad0cfa49b1b19b727b`

```
[harness] PASS: 33/33 checks @ a82235a5d3087cbd67289dad0cfa49b1b19b727b (clean tree) scope=all
[harness2] N/A — nothing in TWO_PLAYER_PATHS is touched (see claim 10)
```

The full `test` was run **six times** on this commit, all PASS 33/33 clean, scope=all
(`<runs-dir>/flake-fixed-1.log` … `flake-fixed-6.log`):

```
[harness] PASS: 33/33 checks @ a82235a5d3087cbd67289dad0cfa49b1b19b727b (clean tree) scope=all
[harness] PASS: 33/33 checks @ a82235a5d3087cbd67289dad0cfa49b1b19b727b (clean tree) scope=all
[harness] PASS: 33/33 checks @ a82235a5d3087cbd67289dad0cfa49b1b19b727b (clean tree) scope=all
[harness] PASS: 33/33 checks @ a82235a5d3087cbd67289dad0cfa49b1b19b727b (clean tree) scope=all
[harness] PASS: 33/33 checks @ a82235a5d3087cbd67289dad0cfa49b1b19b727b (clean tree) scope=all
[harness] PASS: 33/33 checks @ a82235a5d3087cbd67289dad0cfa49b1b19b727b (clean tree) scope=all
```

## What changed

Two files. `tools/studio_mcp.py` — the harness's own startup race, which is the thing that
actually failed in the six baseline runs — and `tests/client/camera_client.spec.luau`, where
the aim-blend waits now spend a budget the camera actually promises and report what they
measured.

**Six FULL one-player runs at `5a097fc` before any change** (`<runs-dir>/flake-1.log` …
`flake-6.log`): **five PASS 33/33, one FAIL — and the one that failed was the HARNESS**:

```
[harness] FAIL: harness error @ 5a097fc…: RuntimeError: get_studio_state: This call is
missing the required `studio_id` argument.
```

**`camera_client.spec:602`, the task 155 flake, did not reproduce in any of the twelve runs,
and no cause for it was guessed at** (claims 8 and 9).

## Claims

**1. Six runs at `5a097fc` with nothing changed: five PASS 33/33, one FAIL, and the failure
was the harness, not a spec.**
Verify: the final line of `<runs-dir>/flake-1.log` … `flake-6.log`. Runs 2–6 read
`[harness] PASS: 33/33 checks @ 5a097fc… (clean tree) scope=all`; run 1 reads the harness
error above. No `failed [` line appears in any of the six.

**2. The cause is measured, not inferred: the run died because the resolver pinned nothing.**
Verify: `flake-1.log` is three lines long and carries **no** `[harness] N Studio(s) connected`
line — which `_choose_default_studio` prints on every path that pins — so it returned without
pinning, and its only early return above the identification loop was `if len(studios) <= 1`.
It died **2 s in**, so it was not the twelve-attempt "none answered" path, which exits after
~24 s with a different message. Every log that got past startup with both places open carries
that line (`flake-2.log` line 1, `test-t155.log` line 1). And the count really does move:
`python tools/studio_mcp.py state` at 16:33 on 2026-10-11 answered `Edit` with no such line
(one Studio listed); `flake-2.log`, one minute later, printed `2 Studios connected`.

**3. The same error has ended five runs on this machine, so it is the recurring one.**
Verify: `grep -l "missing the required" <runs-dir>/*.log` → `flake-1.log`,
`test1-task-80b.log`, `test1-task-80c.log`, `test1-task36-final2.log`, `test2-task50e.log`,
`test2-task52a.log`.

**4. The fix: the editor is pinned from any listing that identifies the harness place,
including a one-entry one.**
Verify: `Studio._choose_default_studio` in `tools/studio_mcp.py`. The `len(studios) <= 1`
early return is gone from above the identification loop (`if not studios: return` is what is
left there), so the `game.PlaceId` query now runs for a one-entry listing too. Visible in
every command's first line: `1 Studio connected` or `2 Studios connected`.

**5. …and it is falsifiable, with no Studio: `selftest` case 9c.**
Verify: `python tools/studio_mcp.py selftest` → `selftest PASS`. Case 9c's `ListingStudio`
scripts a queue of listings, a place id per studio, and a switch that refuses unscoped calls
the way a second connected Studio makes StudioMCP refuse them. Its entries are **nameless** on
purpose — StudioMCP returns them that way for seconds after a Play session ends — so what
identifies the editor is `game.PlaceId` and not the label. **Against the pre-fix code the case
reports 5 of its 7 assertions wrong**, with the run's own message:
`<refused: get_studio_state: This call is missing the required studio_id argument…>`.
(Measured by splicing the case alone into an unpatched copy, outside the repo.)

**6. A lone Studio that is NOT the harness place still pins nothing, and still costs no retry
loop.**
Verify: the `if len(studios) <= 1: return` that now sits **after** the identification loop,
with the reason written beside it, and case 9c's assertions `a lone Studio that is NOT the
harness place pins nothing` and `...and costs no retry loop` (under 1 s). Behaviour for that
case is unchanged: the report's `comes from the DEV place` check is still what says so, and
with one Studio connected StudioMCP accepts an unscoped call anyway.

**7. `Studio._call` closes the class, not the one call.**
Verify: `_call`'s recovery condition is now
`(chosen and "not connected" in text.lower()) or (not chosen and missing_id)`. A second place
can attach at any moment, including between the listing a run resolved its default from and
the next call, so the refusal was never only an init-time race. Case 9c's `late` studio drives
exactly that: one entry at resolve time (not this place → nothing pinned), two by the time
`get_studio_state` goes out → the refusal re-resolves, pins the editor, and the call returns
`ok`. The harness docstring — the single source of truth for the test system — carries both
halves.

**8. `camera_client.spec:602` did not reproduce, and nothing was invented for it.**
Verify: no `failed [client] camera_client.spec` line in any of the twelve logs
(`flake-1..6`, `flake-fixed-1..6`). The task 155 occurrence is `<runs-dir>/test-t155.log`
(`failed [client] camera_client.spec:602`, 31/33) and the pass at the same commit is
`test-t155b.log`. **The two causes I considered are NOT supported by the measurement** — see
claim 10's numbers: in six runs the longest single frame was 0.020 s, where the old wall budget
would have needed a stall of ~0.50 s to run out, and `modes seen` never once included `Loading`
or `Dead`, so no respawn crossed the window. The cause of the task 155 occurrence is **still
unmeasured**; what is new is that the next occurrence prints it.

**9. What WAS fixed in that spec is provable without the failure.**
Verify: `blendBudget` and `waitRendered` in `tests/client/camera_client.spec.luau`.
(a) The old budget was `Config.AIM_BLEND_SECONDS + 0.5` = 0.70 s for **both** directions; the
move the live camera makes is `Mode.blendSeconds(config, aiming)`, which with `FIRST_PERSON` on
is `AIM_RAISE_SECONDS` / `AIM_LOWER_SECONDS` — 0.25 / 0.20, from
`src/shared/Viewmodel/poses.json` — and `tests/server/camera_mode.spec.luau` already pins that
pairing. So the spec budgeted from a field this camera does not read for this move. It now asks
that function with `Camera.poseConfig()`, the very config `Camera.update` hands it every frame;
the logged budgets are 0.750 and 0.700, which is that number plus the margin.
(b) The budget is spent in RENDERED time. `Mode.step` advances the blend by `dt / seconds`
("frame-rate-independent blending", the `Mode.luau` header), so a wall clock asserts one more
thing — that this machine kept rendering — which the camera does not promise. Frames in
`Loading`/`Dead` do not count, because `Mode.nextMode` holds the camera there for as long as a
respawn takes and the blend clock is not running. `math.max(20, seconds * 20)` is still a
wall-clock cap, so a client that stops rendering FAILS rather than hangs.
(c) Only waits for a move **this spec asked for** were converted (six of them). The three waits
for the session to reach a state — `waitUntil(5, …)` in "sits a boom behind the pivot" and in
"puts the real camera at the eye", `waitUntil(10, …)` in the occlusion case — are waiting on
the harness's **replay** releasing the aim button, which is wall-clock driven, and they are
untouched.

**10. The instrument, and what it measured over six runs.**
Verify: the two `TestKit.note` lines in every one of `flake-fixed-1..6.log`
(`grep "camera_client: the" flake-fixed-*.log`). Across the six:
*the raise* 0.251–0.260 s rendered of 0.750 budgeted, 0.234–0.248 s on the clock over 15–16
frames, longest frame 0.017–0.019 s, modes seen `Third,Aiming`, ended
`mode=Aiming blend=1.000 fov=50.00`; *the lower* 0.201–0.217 s rendered of 0.700 budgeted,
0.200–0.216 s on the clock over 12–13 frames, longest frame 0.018–0.020 s, modes seen
`Aiming,Third`, ended `mode=Third blend=0.000 fov=70.00`. **`test2` is N/A**: the changed paths
are `tools/studio_mcp.py` and `tests/client/camera_client.spec.luau`, and neither is in
`TWO_PLAYER_PATHS` in `tools/agents.py` — the harness is explicitly "with the tools" (Director,
2026-10-03) and `camera_client.spec` is not in the list (`match_client.spec`,
`outfit_client.spec`, `zz_tie_to_a_tree.spec` and `Role.luau` are).
`python tools/agents.py selftest` → `all ok`.

## What I could not verify

- **The cause of `camera_client.spec:602`.** It did not reproduce in twelve runs. Both of my
  candidate causes are contradicted by the numbers in claim 10, so I fixed neither; the spec is
  instrumented instead.
- **Two of case 9c's seven assertions cannot fail against the old code** — the two about the
  unchanged "lone Studio that is not this place" behaviour. That is deliberate (they pin what
  must NOT change), but it is why the falsifiability figure is 5 of 7 and not 7 of 7.
- **A harness fault found while recovering, reported rather than fixed (rule 6).** After the
  previous session was killed mid-Play, `python tools/studio_mcp.py state` answered `Edit` while
  DEV was really in **Play**: the next two runs died at an Edit query with
  `execute_luau: Edit datamodel is not available in Play mode` instead of the readable
  `REFUSED (Studio not in Edit mode)` that guard exists to give, and
  `python tools/studio_mcp.py stop` then printed `Game Stopped`. So `Studio.mode()` — which
  parses StudioMCP's `Current Studio Mode:` label — can report `Edit` for a place that is in
  Play after an interrupted session. **Not touched in this task**: it needs its own measurement,
  and it was caused by a killed session rather than by the gate. It is a candidate for task 153's
  unexplained "4/5 pre-Play stop" — I have no evidence for that and do not claim it. Queued in
  TASKS.md as **156a**.
- Nothing visual: this is not a visual task, so no screenshot (rule 5 N/A).
