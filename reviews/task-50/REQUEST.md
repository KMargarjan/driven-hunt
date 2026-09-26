# Task 50 — make `test2` fast: overlap every per-process wait

Task: 50
Round: 1
Base: `edc3136` (`main`; everything through Task 49 merged)
Code commit: `d204f103d88127d7999f127ba401b146106a1d76` — the `[harness]` line below names it, it is the
last commit that changed `src/`, `tests/` or `tools/`, and only this request changes after it
(CLAUDE.md git workflow step 4).

Harness, clean tree, one player:

    [harness] PASS: 28/28 checks @ d204f103d88127d7999f127ba401b146106a1d76 (clean tree)

Harness, clean tree, two players — run by the DIRECTOR, not by me (this change touches
`tools/studio_mcp.py`, so `agents.py` requires it):

    <the [harness2] PASS line for d204f103d88127d7999f127ba401b146106a1d76 goes here;
     the Director runs test2 twice and reports both totals>

307 server specs and 75 client specs, unchanged: no `src/` and no `tests/` file is touched.

## What changed

Nothing about what is checked. Every check, bound, predicate and report is the same; what changed is
that `test2` no longer waits for its three processes **one after another**.

## Measurement first (rule: measure, then cut)

The Director's `test2` logs carry no timestamps, so I timed what I could reach: three 1-player runs
piped through a line stamper, plus a direct measurement of StudioMCP call cost against the Edit place.
Both modes now print a **phase table** at the end and the replay prints its own split, so no future
session has to do this again.

| measured, 2026-09-26, this PC | value |
|---|---|
| `execute_luau` against Edit | **0.067 s** median of 5 |
| `get_studio_state` / `get_console_output` | 0.033 s |
| two `execute_luau` pipelined vs sequential | 0.084 s vs 0.150 s (**44 % less**) |
| one input batch against a **Play** client | **~0.2 s** (26 batches took 5 s) |
| `tests/client/input_scenarios.txt`'s own `wait` steps | **34.5 s** |
| 1-player `test`, total | **91 s** (4.1 s Edit checks · 64.9 s replay · 19.5 s reports · 2.1 s end) |
| inside that replay: scenario gaps / calls / `stage` waiting for a boar | 34 s / 5 s / ~22 s |

**So round trips are not what makes a run long — waiting is**, and StudioMCP is fast enough that
pipelining is worth having but is not the prize. The prize is that every per-process wait in `test2`
was a loop of whole timeouts.

## The before/after table

| `test2` wait | before: one timeout **each** | after: one deadline for **all** | upper bound removed |
|---|---|---|---|
| classify the 3 processes (`classify_studios`) | 3 × 60 s | 60 s | **120 s** |
| ask both clients their team | 2 × 45 s | 45 s | **45 s** |
| the gate token reaching each client | 2 × 20 s | 20 s | **20 s** |
| each client's input-ready handshake (`replay_input`) | 2 × 60 s | 60 s | **60 s** |
| the 26 input batches | 52 round trips | 26 (`send_input_many`) | ~5 s |
| new-studio poll / report poll interval | 2 s / 2 s | 1 s / 1 s | ≤ 4 s |

In the ordinary case the saving is not the bound but **the second process's real wait**, every time:
three processes that all become answerable at t=40 s used to cost 120 s and now cost 40 s. The phase
table in the Director's runs is what turns that into a number, which is why it is part of this task.

**What is NOT cut, deliberately:** the 34.5 s of scenario gaps (the specs assert against them), the
~22 s the `stage` query spends waiting for the drive to release a boar (that is the game's timing,
not the harness's), and `REPORT_WINDOW_2P = 420` (the loop exits as soon as all three reports are in
— measured 0–4 s in every one of the Director's logs — so the cap costs no wall clock and lowering
it could only fail a slow run).

## Claims

1. **`wait_for_each` bounds every subject exactly as `wait_for` did; only the waiting overlaps.**
   Same `timeout` per subject, same predicate, same `RuntimeError`-is-"not yet" rule, same
   last-value-on-failure. A subject that never answers still fails. Verify: `wait_for_each` beside
   `wait_for` in `tools/studio_mcp.py`, and selftest cases 1–4.

2. **Four sequential loops became one deadline each**, and nothing else about them moved:
   `classify_studios` (3 processes, 60 s), the team query and the token-replication check in
   `run_test2`, and the ready handshake in `replay_input`. Each still prints the same line and raises
   the same check. Verify: those four call sites, each commented with the Task 50 reason.

3. **The transport can hold more than one request in flight, and the old one could not.**
   `Studio._submit` / `Studio._await` key replies by id and **keep** them. The old `_rpc` loop read
   messages and **threw away** any whose id did not match — safe only while exactly one request
   existed, and a latent bug the moment two did. `_rpc` is now `_await(_submit(...))`, so every
   existing caller is unchanged. Verify: `Studio._submit`, `Studio._await`, `Studio._rpc`; selftest
   cases 5 and 6, including an out-of-order reply.

4. **`send_input_many` sends one batch per target in one round trip, and is one call for one
   target.** Batch contents, order within a batch, and the order the batches leave in are untouched;
   only the *wait* for two clients' replies to the *same* batch overlaps, and nothing orders those
   against each other. A refusal is reported against its own target. Verify: `Studio.send_input_many`
   and its use in `replay_input`; selftest cases 7 and 8.

5. **The one-player `test` did not get slower.** Four timed runs of the same 28 checks, 307 server
   and 75 client specs: **91 s** before the change (`edc3136`), then **90 s** (`8028435`), **91 s**
   (`bcbe439`) and **90 s** (`d204f10`) after it. With one target `wait_for_each` is `wait_for` look for look (selftest
   case 4) and `send_input_many` is one submit and one await. Verify: the phase tables in the run
   output, and selftest cases 4 and 8.

6. **`python tools/studio_mcp.py selftest` proves the multi-subject behaviour with no Studio**, in
   under a second, and CI runs it. This exists because a 1-player run only ever exercises the
   one-subject case, so the code that makes `test2` fast would otherwise be verified by nothing I can
   run. Verify: `selftest()`, and the new CI step "Harness selftest (no Studio)".

7. **The selftest bites — checked by mutation, not by assertion.** Reverting `wait_for_each` to a
   serial loop fails "the waits overlapped" (0.252 s against a 0.25 s bound). Reverting `_await` to
   the old drop-other-ids loop fails three cases. In that second case the failure arrives as
   `queue.Empty`, which is caught and **named** rather than left to end the selftest in a traceback —
   a harness fault is a reported failure, never a stack (rule 6). Both mutations were run and
   reverted; the evidence is in this request, not in the tree.

8. **The harness docstring is still the single source of truth.** It gains: the round-robin
   classification and the round-robin per-client waits, the phase table as step 7, a
   "How long a run takes, and what it is waiting for" section carrying every number in the table
   above, and `selftest` in the usage block with why it is exempt from "needs Studio". The table is
   printed from `verdict()`, so it comes out on every path -- a refusal and a half-finished run
   included, which is when it is worth most.

9. **Row 49a(b): `.gitignore` now covers `/.agent-evidence/` and `/.assets/`.** `.agent-evidence/`
   is written by `tools/agents.py` and reliably contains a local absolute path (`rojo-build.txt`
   records the `rojo build --output` line verbatim), so one blind `git add -A` would have re-committed
   exactly what Task 49 removed. `/.assets/` is the asset pipeline's run record
   (`docs/design/asset-pipeline.md` §7.2). Verify: `git check-ignore -v .agent-evidence/x .assets/y`.

10. **Row 49a(c): `privacy_scan.py`'s docstring now says what the code does.** It claimed
    `<something>@users.noreply.github.com`; `ALLOWED_EMAIL_SUFFIX` allows **any** domain ending
    `.noreply.github.com` (which is the enterprise form too), plus `ALLOWED_EMAILS`. The code is
    unchanged — it was the documentation that was wrong. Verify: the docstring beside
    `ALLOWED_EMAIL_SUFFIX` / `ALLOWED_EMAILS` / `_email_allowed`.

## What I could not verify

- **I have not run `test2` and I claim no `[harness2]` result.** It needs a click I cannot make and
  it exceeds my tool limit, which is the whole reason for this task. The Director runs it twice; the
  before/after *total* for `test2` is theirs to report and is not claimed here. What I claim is the
  mechanism, the bounds removed, and that the phase table will show where the remaining seconds go.
- **The multi-subject paths are proved by selftest, not by a real two-player run.** `wait_for_each`
  with three real processes, `classify_studios` round-robin against three loading Studios, and
  `send_input_many` against two real Play clients have not run on this machine. If StudioMCP turns
  out to serialise two in-flight input calls, the replay is no slower than before — one call per
  target either way — but the ~5 s saving would not materialise.
- **The `stage` query's ~22 s is a 1-player measurement.** In `test2` the drive has been running
  since classification began, so the boar is probably already there and the wait is probably near
  zero. I did not measure it with two players.
- **The phase table's own cost is not free but is negligible**: one `time.time()` per phase, nine
  phases.
- **CI has not run yet** at the time of writing; the new selftest step passes locally (exit 0).
