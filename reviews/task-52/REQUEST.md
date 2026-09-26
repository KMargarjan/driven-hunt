# Task 52 — feature flags: merge dark, switch on for a playtest, flip the default in git

Task: 52
Round: 1
Base: `edc3136` (`main`; everything through Task 49 merged. Task 50 is **not** merged, so this
branch has the pre-Task-50 harness)
Code commit: `d0fc1bfe660600fd0ff66aa2f6704581a3eab3b5` — the `[harness]` line below names it, it is
the last commit that changed `src/`, `tests/` or `tools/`, and only this request changes after it.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ d0fc1bfe660600fd0ff66aa2f6704581a3eab3b5 (clean tree)

Harness, clean tree, two players — run by the DIRECTOR, not by me:

    <the [harness2] PASS line goes here. Both lines must name the SAME commit for tools/agents.py,
     so once test2 has run at the branch head I re-run `test` there and repoint both.>

327 server specs (307 before: **20 new**) and 81 client specs (75 before: **6 new**). 30 harness
checks (28 before: **2 new**, the flag-override guards).

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

## What I could not verify

- **No `[harness2]` yet.** This touches `src/`, `tests/client/` and `tools/studio_mcp.py`, so the
  two-player run is part of the gate and it is the Director's to make. With it comes the last
  unmeasured half of §15 item 2 (Edit attribute → a **two-client** server) and the cross-process
  claim that all three processes resolve the same digest.
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
