# Task 50 — make `test2` fast, and fix the ordering defect that made it visible

Task: 50
Round: 1
Base: `edc3136` (`main`; everything through Task 49 merged)
Code commit: `1d470161b2902148e092a1d31895f996ab85c612` — the `[harness]` line below names it, it is the
last commit that changed `src/`, `tests/` or `tools/`, and only this request changes after it
(CLAUDE.md git workflow step 4).

Harness, clean tree, one player:

    [harness] PASS: 28/28 checks @ 1d470161b2902148e092a1d31895f996ab85c612 (clean tree)

Harness, clean tree, two players — run by the DIRECTOR, not by me:

    <the [harness2] PASS line for 1d470161b2902148e092a1d31895f996ab85c612 goes here>

307 server specs (unchanged) and **78** client specs (75 before: three new ones, claim 8).

## What changed

Two things. `test2` went from about 7–10 minutes to **96 seconds**, by overlapping waits and cutting
no checks. And the speed-up exposed a real ordering defect in a client spec, which is fixed by fixing
the order — not the tolerance.

## Half one: the speed-up, and what it measured

The Director's old logs carry no timestamps, so I measured what I could reach, and then made both
modes print a **phase table** so nobody has to do it by hand again.

| measured, 2026-09-26, this PC | value |
|---|---|
| `execute_luau` against Edit | **0.067 s** (median of 5) |
| `get_studio_state` / `get_console_output` | 0.033 s |
| two `execute_luau` pipelined vs sequential | 0.084 s vs 0.150 s |
| one input batch against a **Play** client | **~0.2 s** (26 batches = 5 s) |
| `tests/client/input_scenarios.txt`'s own `wait` steps | **34.5 s** |
| 1-player `test` | **90–91 s** (4 s Edit checks · 65 s replay · 19 s reports · 2 s end) |

**Round trips are not what makes a run long — waiting is.** Every per-process wait in `test2` was a
loop of whole timeouts, so two clients that answered at the same moment cost twice one client:

| `test2` wait | before: one timeout **each** | after: one deadline for **all** | bound removed |
|---|---|---|---|
| classify the 3 processes | 3 × 60 s | 60 s | **120 s** |
| ask both clients their team | 2 × 45 s | 45 s | **45 s** |
| the token reaching each client | 2 × 20 s | 20 s | **20 s** |
| each client's input-ready handshake | 2 × 60 s | 60 s | **60 s** |
| the 26 input batches | 52 round trips | 26 (`send_input_many`) | ~5 s |

**The Director's three runs at `9165d63` are the result**, and their phase tables are the evidence:

| phase | run a | run b | run c |
|---|---|---|---|
| checks, token sync, gate shut | 1.5 s | 1.5 s | 1.5 s |
| waiting for the Start click and three processes | 77.7 s | 20.5 s | 20.7 s |
| classifying the three processes | 5.1 s | 4.8 s | 4.7 s |
| team query · token injection · ready handshake | **all three under 0.5 s, so the table omits them** |||
| replaying the input scenarios into both clients | 58.0 s | 58.3 s | 58.5 s |
| reading all three reports | 1.4 s | 6.8 s | 6.8 s |
| consoles, report checks, ending the session | 3.2 s | 3.2 s | 3.2 s |
| **total** | **147 s** | **96 s** | **96 s** |

Run a's 77.7 s was the Director's F7 arriving late, not the harness. **96 s is the run**, against a
target of under 300 s. The three waits this task set out to overlap now cost less than half a second
between them, and the remaining 58 s of replay is 34.5 s of scenario gaps (the specs assert against
them), ~19 s inside the `stage` query waiting for the drive to release a boar, and ~5 s of calls.

## Half two: the ordering defect the speed-up exposed

Runs b and c **failed 28/30**: `shoot_boar.spec:142`, the camera **82.30°** and **88.96°** off a
point it had just been asked to look at, and 0.00° on a later reading. Run a read 0.00° first. Not
flakiness — a real defect, and the speed-up is what made it reachable.

The spec invoked `LookAtRequest` and then waited exactly **two `RenderStepped` frames**. The owner
sets the angles at once, but `update()` runs `Mode.step` **first**, and `Mode.step` consumes whatever
`UserInputService` mouse movement arrived in that frame. Since this task the replay starts sooner, so
the first scenario's mouse moves now land *during* that `it`: a delta in the same frame takes the
camera somewhere else entirely. Before the speed-up the replay had not reached the client yet and two
frames happened to be enough.

## Claims

1. **`wait_for_each` bounds every subject exactly as `wait_for` did; only the waiting overlaps.**
   Same per-subject `timeout`, same predicate, same `RuntimeError`-is-"not yet", same last value on
   failure. Verify: `wait_for_each` beside `wait_for`; selftest cases 1–4.

2. **Four sequential loops became one deadline each, and nothing else about them moved:**
   `classify_studios` (3 processes, 60 s), the team query and the token-replication check in
   `run_test2`, and the ready handshake in `replay_input`. Same lines printed, same checks raised.
   Verify: those four call sites; and the phase tables above, where all three per-client waits fell
   below the table's 0.5 s print threshold.

3. **The transport can hold more than one request in flight; the old one could not.**
   `Studio._submit` / `Studio._await` key replies by id and **keep** them. The old `_rpc` loop threw
   away every message whose id did not match — safe only while exactly one request existed, and a
   latent bug the moment two did. `_rpc` is now `_await(_submit(...))`, so every caller is unchanged.
   Verify: those three methods; selftest cases 5 and 6, including an out-of-order reply.

4. **`send_input_many` is one round trip per batch and one call for one target.** Batch contents and
   the order batches leave in are untouched; only the *wait* for two clients' replies to the *same*
   batch overlaps, and nothing orders those against each other. Verify: `Studio.send_input_many`,
   its use in `replay_input`; selftest cases 7 and 8.

5. **The look-at fix is an ordering fix. The angle check is untouched at `dot > 0.999`** (~2.5°).
   The camera owner now says when a request has been **rendered**: `Camera.lookAt` marks the point
   pending, and `update()` clears it and counts `stats().lookAtLanded` once the CFrame it actually
   wrote points there. Measured against the **written** CFrame, so occlusion and a stray delta are
   both accounted for. Nothing about what the camera does changed: one pending point, two counters.
   Verify: `Camera.lookAt` and `update` in `src/client/Camera/init.luau`.

6. **`Config.LOOK_AT_LANDED_DOT = 0.99` (~8.1°) is deliberately LOOSER than the 0.999 the spec
   asserts**, so "the owner saw it land" and "the aim is good" stay two different statements and the
   spec's own measurement of `Workspace.CurrentCamera` is not a restatement of the owner's. Verify:
   the comment at `LOOK_AT_LANDED_DOT`, and the two separate `expect`s in the spec.

7. **The spec waits for a frame instead of counting frames.** It re-asks and re-measures the live
   camera until the reading is within 2.5°, bounded by `LOOK_AT_SECONDS = 15`, then also asserts the
   owner's `lookAtLanded` rose and that `foreignCameraWrites` did **not**. Re-asking is required
   because the request is one-shot by design — the owner never fights the player's mouse, so a
   disturbed request is simply gone. Verify: `tests/client/shoot_boar.spec.luau`, "turns the real
   camera onto a point".

8. **The two-player race cannot be a regression test, so the signal it rests on is tested with one
   player.** Three new tests in `camera_client.spec.luau`, "the look-at landed signal":
   `lookAtRequests` rises on the ask and `lookAtLanded` does **not**, read with no yield between the
   two lines so nothing can have rendered; it does rise once a frame goes by; landed never exceeds
   asked; a refused request counts as neither. Verify: that `describe`, and claim 9.

9. **Checked by mutation, three times.** (a) `wait_for_each` reverted to a serial loop fails the
   selftest's "the waits overlapped" (0.252 s against a 0.25 s bound). (b) `_await` reverted to the
   old drop-other-ids loop fails three selftest cases; the failure arrives as `queue.Empty`, which is
   caught and **named** rather than ending the selftest in a traceback (rule 6). (c) making
   `Camera.lookAt` count the **ask** instead of the rendered frame fails
   `camera_client.spec:256` ("0" vs "1") and `camera_client.spec:278` ("1" vs "2") in a real harness
   run — `[harness] FAIL: 26/28`. All three mutations were run and reverted; the tree is clean.

10. **The one-player `test` did not get slower, and it now streams.** Six timed runs of the same 28
    checks: **91 s** before the change, then 90 · 91 · 90 · 90 · 91 s after. With one target
    `wait_for_each` is `wait_for` look for look and `send_input_many` is one submit and one await.
    Separately, stdout is line buffered, so a run's lines appear live even when piped to a log — the
    Director was waiting on "the gate is shut again", which used to arrive in an 8 KiB block after
    the run had finished. Measured through a pipe: first line at 4.2 s, last at 95.6 s.
    Also closed here: row **49a(b)** (`/.agent-evidence/` and `/.assets/` are git-ignored, so a blind
    `git add -A` cannot re-commit the local paths Task 49 scrubbed) and row **49a(c)**
    (`privacy_scan.py`'s docstring now matches its code on which noreply domains are allowed).

## What I could not verify

- **I have not run `test2` and claim no `[harness2]` result at this commit.** The 96 s figure and the
  phase tables above are the Director's runs at `9165d63`, which is this branch **before** the
  look-at fix. The fix changes `src/client/` and `tests/client/`, so it needs a fresh two-player run;
  the speed work it sits on is unchanged by it.
- **The two-player look-at race is fixed by reasoning plus a one-player test of the signal, not by
  reproducing the race.** I cannot make a mouse delta land in a chosen frame from a spec. What is
  proved is that the spec no longer depends on a frame count, that it is bounded, and that the
  owner's counter counts frames and not asks.
- **`LOOK_AT_SECONDS = 15` is a judgement, not a measurement.** The replay's mouse bursts are a
  second or two apart, so a clean frame should come within one or two; 15 s is roughly ten times
  that. If it ever runs out, the spec fails with the last measured angle printed, which is what the
  Director's logs showed.
- **`REPORT_WINDOW_2P` stays 420 s on purpose.** The loop exits as soon as all three reports are in —
  1.4–6.8 s in the Director's runs — so the cap costs no wall clock and lowering it could only fail a
  slow run.
- **CI has not run yet** at the time of writing; lint, format, both selftests and the 1-player
  harness all pass locally.
