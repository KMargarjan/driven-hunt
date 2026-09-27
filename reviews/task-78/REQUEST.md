# Task 78 — the Edit-mode flag queries read the current module, not a cached one

Task: 78
Round: 2
Base: `main` (`3273f3e`)
Code commit: `314337b877d25055896cc2c5ef087bed508adedd`

```
[harness] PASS: 32/32 checks @ 314337b877d25055896cc2c5ef087bed508adedd (clean tree)
```

`tools/studio_mcp.py` is the harness itself, so `test2` is part of the gate; the Director runs it at
this branch's head and that line goes here. `[tests:server] PASS: 419 passed`, client 88 — unchanged,
because nothing in `src/` or `tests/` moved.

**Round 1's finding was right, and it was the sharpest kind: the fix had the same shape as the bug.**
`FRESH_FLAGS` answered a bare `"REFUSED: ..."` string. The `set` path checked that prefix; the two
`json.loads` call sites did not — and my diff had removed the only producer of `{error=...}`, so both
of their handlers became dead code. The **reachable** case, Studio open in Edit before Rojo has been
connected, which is exactly what that message names, ended in a `JSONDecodeError` traceback where it
used to print `[flags] could not read ...`. Right about the thing it was aimed at, wrong about the
thing beside it — which is what Task 78 is about in the first place.

**What changed this round.** `tools/studio_mcp.py`: `FRESH_FLAGS` and `QUERY_SET_FLAG` answer JSON;
`json_answer()`; `run_flags`' two call sites and `run_test`'s two checks go through it; the offline
cases; the docstring's ordered check list (the two new checks, renumbered);
`flags_in_text()` split out of `declared_flags()`. Plus
`docs/research/2026-09-27-require-cache.md` (a round-2 section, and licence/maintenance on the
sources) and `TASKS.md` rows 78/78a.

## Claims

1. **One answer shape for every query that reads `Flags`.** A JSON object; failure is
   `{ error = ... }`. `QUERY_SET_FLAG` answers `{ set = "NAME=true" }` on success rather than a bare
   string, so there is no second shape left to get wrong.
2. **One parser, and it cannot raise on what Studio said.** `json_answer()` turns a bare string,
   truncated JSON, `null`, a Luau error text or a JSON array into a `problem` the caller prints. The
   shape rule makes the common case right; the parser makes *every* case right, including whatever a
   future query answers.
3. **Every caller goes through it.** `run_flags` show (exit 1) and set (exit 2), `run_test`'s flag
   table check, and `run_test`'s require-cache check. `grep "json.loads(studio.query"` leaves one
   hit, `QUERY_ALL_SCRIPTS`, which is not a Flags query — left alone deliberately and queued as
   78a(h) with the reason.
4. **The offline cases drive the real `run_flags`, not a stand-in.** A scripted Studio answers five
   bad shapes — round 1's bare refusal, an empty answer, a Luau error text, a JSON array, and the
   `{error}` object itself — and each is asserted to print `[flags] could not read
   ReplicatedStorage.Flags:` and to exit **1** for `show` and **2** for `set`. A raised exception is
   reported as exit `-1` with the exception text, so "it did not crash" is not what passes.
5. **And the good answers still work**, so claim 4 is not a guard that refuses everything:
   `{"rows": [], "stray": []}` prints the empty table and exits 0, `{"set": "SOME_FLAG=true"}` prints
   `override set: SOME_FLAG=true` and exits 0.
6. **A source-shape check too.** `FRESH_FLAGS`, `QUERY_SET_FLAG` and `QUERY_FLAG_TABLE` together must
   contain no `return "` and `FRESH_FLAGS` must contain `JSONEncode({ error` — the same idiom as the
   existing "every argument builder asks `_scoped`" check. The parser makes callers safe; this keeps
   the queries honest.
7. **Two mutations, applied, run and restored.** Round 1's call site restored (`json.loads(
   studio.query(...))` in the show path) → four cases report `raised JSONDecodeError: Expecting
   value` and `raised AttributeError: 'list' object has no attribute 'get'` — the defect verbatim.
   Round 1's bare-string refusal restored → the shape check fails, naming the offending line.
8. **The live path re-proved against the new shape**, from the committed code with the tree clean:
   `set ORANGE_OUTFITS on` → `override set: ORANGE_OUTFITS=true`; the listing shows `override on`;
   `clear` → `cleared: DHFlag_ORANGE_OUTFITS`.
9. **Three non-blocking notes fixed in this round rather than queued.** The docstring's ordered check
   list gains the two new checks and is renumbered — CLAUDE.md makes that docstring the source of
   truth for every check, so its omission was a documentation defect, not a preference. The parser
   selftest is driven by a **synthetic** `DEFAULTS` table instead of hardcoding `ORANGE_OUTFITS`,
   which would have failed CI the day that flag is legitimately retired and did not test what its
   label claimed. The research note's sources carry licence and maintenance status, and the shortfall
   against rule 1's "3+ external sources" is stated plainly rather than padded.
10. **Round 1's ten claims are unchanged and still hold** — the clone, the measurement, the borrowed
    `mapgen.py` pattern, the two harness checks, the audit. This round changed only how a failure is
    reported.

## What I could not verify

- **`test2` is the Director's run.** Nothing here is two-player-specific.
- **The two-player outfit screenshot was taken by the DIRECTOR, not by me** — round 1's claim 11,
  and `TASKS.md` 78a(a) now says so and no longer reads "still not taken" (Reviewer note). I have not
  seen those screenshots, so both places attribute them rather than describing them as my own look.
- **The flag-table check only bites in a session whose cache is already stale** (78a(f)). The
  in-memory fixture is the half that bites always.
- **`unmanaged_scripts` still parses `QUERY_ALL_SCRIPTS` directly** (78a(h)). Same shape of risk, not
  the same defect: it is not a Flags query and always JSON-encodes, and routing it through
  `json_answer` means deciding what a malformed answer does to the script scan — a behaviour change
  to a check this task did not touch.
- **The offline cases drive `run_flags`, not `run_test`'s check** (78a(i)). Both read through
  `json_answer` and the selftest asserts what that helper hands the check; driving the check itself
  would mean faking a whole run.
- **`docs/design/feature-flags.md` still asserts what this task disproved** (Reviewer note, now
  78a(g)). It is the Architect's file; queued for reconciliation like 74a(g) and 75a(i).
