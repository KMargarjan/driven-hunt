# Task 52 — feature flags: merge dark, switch on for a playtest, flip the default in git

Task: 52
Round: 1
Base: `4ee25d2` (`main`, with Task 50 merged as PR #47). This branch started from `edc3136` and
`origin/main` is **merged into it** at `a519cfe` — a merge, no rebase, no force push.
Code commit: `75720a77a2ae9e30554c8d000ee28c694dc13539` — both harness lines below name it. It is a
PAPERWORK commit: the last commit that changed `src/`, `tests/` or `tools/` is the merge `a519cfe`,
and `git diff --name-only a519cfe..75720a7` is `TASKS.md` and this file. Naming the later commit is
what CLAUDE.md git workflow step 4 allows and prefers, and it only narrows what the evidence covers.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ 75720a77a2ae9e30554c8d000ee28c694dc13539 (clean tree)

Harness, clean tree, two players — run by the DIRECTOR, not by me:

    [harness2] PASS: 32/32 checks @ 75720a77a2ae9e30554c8d000ee28c694dc13539 (clean tree)

Two players: server 327, shooter 84, driver 78. **One intermittent failure is disclosed below**
(`boar_body.spec`, a spec this task does not touch) — see "What I could not verify".

**Round 1's two-player run found a real defect of mine and it is fixed here.** At `ab4380c` every
spec PASSED on all three sides (server 327, shooter 81, driver 75) and the harness then died:
`[harness2] FAIL: RuntimeError: execute_luau: This call is missing the required studio_id argument`.
Claim 11.

327 server specs (307 before Task 52: **20 new**) and **84** client specs (6 new here, 3 from
Task 50's look-at work, which this branch now carries). 30 harness checks (28 before: **2 new**, the
flag-override guards). Task 50's phase table and replay split are in the run output, unchanged.

## The measurements, first, before a line of code (design §15)

Both of the design's unverified assumptions were **CONFIRMED**, so the named fallback (a
`StringValue` child of `State` carrying the digest) was not needed and **is not in the tree**.

| # | Assumption | Result, 2026-09-26, DEV place |
|---|---|---|
| 1 | server-written attributes on a `ReplicatedStorage` instance reach **clients** | **yes** — the client read `Digest=probe-digest-1 SOMETHING_OFF=false TIE_UNTIL_DRIVE_END=true` |
| 1b | …and a later **change** reaches them too | **yes** — after the server rewrote them: `Digest=probe-digest-2 SOMETHING_OFF=true` |
| 2 | an attribute set on `ServerStorage` in **Edit** reaches a **Play** server | **yes** — `isServer=true isStudio=true bool=true str=edit-side` |

Probed with a `Folder` the server created during Play and destroyed afterwards; nothing was written
to disk and the Edit attribute was cleared either way. **§15 item 3 was not probed** (nothing writes
`State` in Edit, and the two new guards cover what the question was about). The **two-client** half of
measurement 2 is the Director's `test2`, and until it is green that half is inference.

## Claims

1. **The resolver is pure and refuses rather than guesses.** `Flags.resolve` returns a **new frozen**
   table and never mutates either argument; it **never coerces** (`"true"`, `1`, `0`, `{}` are all
   rejected, not read as booleans); an override for an undeclared name is rejected and **does not
   create the key**; the rejected list is sorted, so two runs report the same thing. `Flags.digest`
   is sorted and stable. Verify: `Flags.resolve`/`digest`; `tests/server/flags.spec.luau`,
   `describe("resolve")` and `describe("digest")`.

2. **`isOn` raises on a name that is not declared.** A typo that read as `false` would be a dark path
   that silently never runs and a spec that passes for the wrong reason. Verify: `Flags.isOn`; the
   spec's `describe("isOn")`.

3. **The declarations are DEEP-frozen and the rot tripwire is real.** Assigning a row raises, and so
   does assigning a field **inside** a row — the Task 23a(b) defect, where `table.freeze` was shallow.
   `Flags.problems(Flags.DEFAULTS, today)` is empty today; an `expires` in the past fails that spec,
   which fails the harness, which blocks the merge gate. **And `problems()` is itself falsifiable:** a
   second case feeds it an expired row, a lower-case name, a non-boolean default, a missing field and
   `MAX_FLAGS + 1` rows, and asserts each is caught — otherwise the tripwire would prove only that it
   can return an empty list. Verify: `Flags.problems`; `describe("the declarations")`.

4. **The override's production branch is provable from inside Studio.** `RunService:IsStudio()` is an
   **injected parameter**, so `readOverrides(host, false)` is asserted to be `{}` *with an attribute
   present* — the branch a published place takes, which no harness run can otherwise reach because
   `IsStudio()` is always true here. The spec sets that attribute on a `Configuration` it creates and
   destroys, **never on `ServerStorage`**: nothing may leave an override on the service the harness
   guards. Verify: `Flags.readOverrides`; `describe("readOverrides")`.

5. **The harness refuses to run while an override is set, and it was proved to bite.** Two checks,
   in both modes: "No flag override is set" before the token is written and before Play (in `test2`,
   **before Karen's click**, so a refusal never wastes the one human step), and "No flag override
   appeared during the run" in `verdict()` beside "HEAD unchanged". **Measured with
   `DHFlag_TIE_UNTIL_DRIVE_END=false` set:** the run stopped before Play with
   `[harness] FAIL: 3/5 checks @ … `, **exit 1**, after printing `python tools/flags.py clear`.
   It **refuses, it does not reset** — silently clearing the Director's overrides mid-session would
   destroy a playtest setup and hide that the run was almost made against the wrong build. Verify:
   `check_no_flag_override`, its two call sites, and the two `verdict()` bodies.

6. **`Digest` is written last, and a client never reads half a set.** `Flags.publish` writes every
   flag, then `Source`, then `Digest`; a client waits on `GetAttributeChangedSignal("Digest")` with a
   10 s deadline (the signal wakes it, the deadline bounds it) and, on a digest mismatch, **warns and
   falls back to the defaults** rather than disagreeing silently. The server spec asserts the mirror
   carries exactly `#flags + 2` attributes and that its digest matches; the client spec asserts
   `source() == "published"`. Verify: `Flags.publish`, `resolveOnClient`; spec case "published a
   mirror…" and `tests/client/flags_client.spec.luau`.

7. **One migration and no more (design §10).** `Match.CONFIG.TIE_UNTIL_DRIVE_END` is now
   `Flags.isOn("TIE_UNTIL_DRIVE_END")` — **one line**, value unchanged at `true`, so the behaviour
   diff is nil while the plumbing gets a real consumer with three live suites. `Penalty.expired` is
   untouched and still takes `config`, which is what lets the spec assert **both** states of the
   behaviour (`TIE_UNTIL_DRIVE_END = false` → expired, `= true` → not) while the live flag sits at
   one of them. Verify: `Match.CONFIG`; `describe("the worked example")`.

8. **The mirror has exactly one writer, and a client is not it.** `Flags.setForTests`,
   `Flags.override` and `Flags.set` are all `nil`; `publish` called twice does not change the digest;
   `publish` raises on a client and on a source that is not declared; the client spec asserts the
   `Source` the server wrote is still there after the whole client suite has run. Verify:
   `Flags.publish`; spec cases "has no writer…", "refuses to publish a source…", and the client
   spec's `describe("what a client may not do")`.

9. **`tools/flags.py` is the Director's switch and `studio_mcp.py` is still the one owner.** Every
   line of logic, the Edit-mode gate and the MCP transport are in `run_flags`; `tools/flags.py` is a
   thin wrapper, the shape `tools/review.sh` already has over `tools/agents.py`. `set`/`clear` are
   **Edit-only** because the server resolves once at boot, so a write into a running session would
   never be read. The name is validated against `Flags.NAME_PATTERN` in Python **and** checked
   against `Flags.DEFAULTS` in Luau, and is sent as a JSON string literal with a Luau boolean
   literal — no arbitrary Luau, the same shape as `QUERY_SET_CLIENTS_DONE`. Driven by hand:
   `set … off` → `TIE_UNTIL_DRIVE_END=false`; the table then showed `override off, effective off`;
   `set NOPE on` → `REFUSED: no such flag NOPE`, exit 2; `set … maybe` → usage, exit 2; `clear` →
   `cleared: DHFlag_TIE_UNTIL_DRIVE_END`. Verify: `run_flags`, `tools/flags.py`, `QUERY_SET_FLAG`.

10. **The paperwork is complete and the docstring is still the source of truth.** `GAME_DESIGN.md`
    gains the three owner rows §2 asks for; `CLAUDE.md` gains a "Feature flags" section and the
    `flags.py` entry in its Layout table; the harness docstring gains the `flags` command, the two
    checks, and an amended **Safety** paragraph that admits the one new write; `TASKS.md` row 2's
    strip list gains "every `DHFlag_*` attribute on `ServerStorage`" (Director decision 5); and
    `docs/research/2026-09-26-feature-flags.md` plus its `INDEX.md` row carry the measurements, the
    §12 numbers and **five places where the built thing differs from the design**, with reasons.

11. **Every StudioMCP call is scoped once a local test has added processes — the class, not the
    one call.** StudioMCP refuses any tool call that names no `studio_id` as soon as more than one
    Studio is connected, and the three a local test adds **do not go away when the session ends**:
    `end_session` stops their Play, but only Karen's Cleanup closes them (the failing run printed
    "3 test Studio(s) still open"). So "run it after the session has ended" is not an escape — there
    is no later moment with one Studio — and my flag-override re-read in `run_test2`'s `verdict()`,
    which runs last of all, was refused. **All 47 call sites audited; one was wrong.** The fix is
    structural: `Studio.default_studio_id`, applied by `_call` and by `capture` (which builds its own
    arguments) through one `_scoped()` helper; `run_test2` sets it to the editor's id **before the
    click**, while there is still exactly one Studio, and prints it so the log says scoping happened;
    an explicit `studio_id` always wins; `list_roblox_studios` is never scoped, because "which
    Studios exist" is not a question about one of them. `flag_overrides` also takes an explicit id,
    and `verdict()`'s read passes it **and** goes through `process_call`, so a Studio that went away
    mid-teardown is a reported failure and never a traceback over the verdict line (rule 6).
    `run_flags` scopes itself through `studio_for_role(studio, "edit")` — `flags clear` is most
    wanted exactly while a session is still open, and every unnamed call in it would have been
    refused the same way. Verify: `Studio._scoped`, `_call`, `capture`, `Studio.default_studio_id`'s
    comment, the `run_test2` line that sets it, `flag_overrides`, `run_flags`.

12. **Task 50 is merged in, and both harnesses survive.** Four conflicts in
    `tools/studio_mcp.py`, and in every one **both sides are kept**: the docstring gains both new
    sections; `Studio.__init__` gains main's `self.replies` (the id-keyed reply map that lets more
    than one request be in flight) **and** `self.default_studio_id`; `run_flags` and `selftest` both
    exist; the command tuple gains both `flags` and `selftest`. `TASKS.md` keeps rows 50 and 52.
    Nothing under `src/` or `tests/` was deleted by the merge. Verify: `git log --merges -1`,
    `python tools/studio_mcp.py selftest`, `python tools/flags.py`, and the run output above, which
    carries Task 50's phase table *and* the two flag checks.

13. **The `studio_id` class was re-audited after the merge, and Task 50 had added a third
    argument-builder.** `Studio.send_input_many` built its own arguments and named only explicit
    ids — nothing broken today, because `replay_input` always names its targets, but an unnamed call
    there would be refused the moment a local test exists, which is exactly when that method is
    used. It asks `_scoped` now, like `_call` and `capture`; **all three builders are scoped and
    nothing else builds arguments.** The merge also gave the fix a home it did not have on the old
    base: **nine new `selftest` cases** (unnamed stays unnamed with no default; a default scopes
    `execute_luau`, `get_studio_state`, `get_console_output` and `start_stop_play`; an explicit id
    wins; `list_roblox_studios` is never scoped; `capture` agrees both ways) plus one that **counts
    argument builders against `_scoped` calls**, so the class cannot quietly reopen. Checked by
    mutation: un-scoping `send_input_many` fails `every argument builder asks _scoped: 4 vs 5`.
    Verify: `Studio._scoped` and its three call sites; `selftest`'s block 9b.

## An intermittent failure, disclosed

The first `test` run at this commit **FAILED 28/30**: `boar_body.spec:264`,
`expect(gained).to.equal(true)` — the boar had not gained its 20 studs inside the travel budget.
The immediate re-run of the same commit on the same clean tree **passed 30/30**, and so did the run
at `a519cfe` before the paperwork and the Director's `[harness2]` 32/32. Four runs of this tree,
three green.

`boar_body.spec` is not touched by this task, the assertion is a wall-clock physics one under harness
load (the spec's own neighbours carry comments about exactly that — "under harness load it is not
obviously enough"), and nothing in the flags system runs during it. **I am not claiming it is
harmless**: an intermittent server spec is a real problem for a merge gate that trusts one run, and
it is queued as Task 52a. I did not keep the run's `[boar_body] gained … studs` line, so I cannot say
how close it came — that is my mistake, and the next occurrence should be captured with the console
output intact.

## What I could not verify

- **No `[harness2]` for this commit yet.** The run at `ab4380c` proved the flags system itself —
  every spec passed on all three sides, which is the cross-process digest claim and the two-client
  half of §15 item 2 — but it died in the teardown, so there is no PASS line. The scoping fix
  changes only `tools/studio_mcp.py`, so a fresh run is needed and it is the Director's to make.
- **The scoping fix is proved against a fake transport, not against four Studios.** It is nine
  `selftest` cases now, and CI runs them, but the multi-Studio refusal itself needs four Studios and
  is the `test2` run.
- **`boar_body.spec:264` failed once and passed three times on this tree** (above). The green line
  is real, but one run is thinner evidence than it looks for that spec.
- **`flags live` was not run.** It needs a running Play session, which is the Director's `test2` or a
  playtest. `set`, `clear`, the table and both refusals were driven by hand; `live` was not.
- **"A published place ignores `DHFlag_*`" is proved only through the injected parameter.** No
  harness run can make `RunService:IsStudio()` false. That is exactly why the test is a parameter,
  but it is an argument, not a measurement.
- **While a flag is OFF, CI and the harness run the on-disk defaults only.** A dark path's wired,
  live behaviour is proved by the Director's override plus Karen's playtest and by pure specs before
  that — never by the harness. Said plainly because it is the honest limit of this system.
- **Resolution cost is reported, not asserted at the first resolution.** The spec measures the
  memoised repeat cost and `Flags` itself warns if the *first*, real resolution exceeds 1 ms; no run
  has yet printed that warning, but absence of a warning is weaker evidence than a number.
