# Task 78 — the Edit-mode flag queries read the current module, not a cached one

Task: 78
Round: 1
Base: `main` (`3273f3e`)
Code commit: `4f28c0b931db27c8affc9288c7c7a3eace04efb1`

```
[harness] PASS: 32/32 checks @ 4f28c0b931db27c8affc9288c7c7a3eace04efb1 (clean tree)
```

**32, not 30**: two checks are new. `tools/studio_mcp.py` is the harness itself, so `test2` is part
of the gate; the Director runs it at this branch's head and that line goes here. `[tests:server] PASS:
419 passed`, client 88 — unchanged, because nothing in `src/` or `tests/` moved.

**What changed.** `tools/studio_mcp.py` (`FRESH_FLAGS`; `QUERY_FLAG_TABLE` and `QUERY_SET_FLAG` use
it; `QUERY_REQUIRE_CACHE`; `declared_flags()`; two run-time checks; three selftest checks; the
docstring), `docs/research/2026-09-27-require-cache.md` and its INDEX row, `TASKS.md` rows 78/78a.

## Claims

1. **The bug is real and was reproduced, not taken on trust.** Before the fix, in the live Edit
   session: `flags.py set ORANGE_OUTFITS on` → `REFUSED: no such flag ORANGE_OUTFITS`, and `flags`
   listed only `BOAR_SOUNDERS` and `TIE_UNTIL_DRIVE_END` while the file declared three.
2. **The cause is `require`'s per-instance cache, and Roblox says so.** *"ModuleScripts run once and
   only once per Luau environment and return the exact same value for subsequent calls to
   `require()`"*, and return values are *"independent with regards to Scripts and LocalScripts, and
   other environments like the Command Bar"* — the Edit-mode MCP context is one of those. Rojo
   rewrites the **Source of the same ModuleScript**, so the cache never refreshes.
3. **Both rendered doc pages gave a fetcher nothing** (asked twice, 2026-09-27). The quotes above
   come from the generated YAML those pages are built from, in `Roblox/creator-docs`, and the code
   comment and the note both say so. This repo set that rule for the Blender manual and
   `en.help.roblox.com`; it is followed here rather than a plausible sentence being invented.
4. **So the behaviour was MEASURED, from scratch, in memory.** `QUERY_REQUIRE_CACHE` makes a
   ModuleScript declaring `A`, rewrites its Source to declare `A` and `B` as Rojo does, and asks
   both: the **same instance** answers `A`, a **clone** answers `A,B`. The harness prints it every
   run — this run said `same instance said 'A' after its Source declared 'A,B'  <-- STALE`.
5. **The fix was already in this repo (rule 2).** `tools/mapgen.py`'s `CALL` has used
   `require(source:Clone())` since 2026-09-26 with the same measurement beside it. The flag queries
   never got it, and the comment on `QUERY_FLAG_TABLE` asserted the opposite — that the cache was
   *"CORRECT rather than a hazard"*. That comment is replaced by what was measured.
6. **One `FRESH_FLAGS` snippet, shared by both queries**: a parentless clone, required, destroyed.
   It keeps the property that matters — these queries are still **constants** with a JSON-encoded
   name and a boolean literal interpolated, so they send no arbitrary Luau — and it puts no script
   in any Rojo-owned container, so the harness's own "no script outside Rojo-managed paths" check
   cannot trip over it.
7. **Three alternatives rejected, each with the reason written down** (note, "The pattern adopted"):
   parsing `Source` (measured to be possible — it is readable, 18,253 bytes — but a second, weaker
   implementation of what the module already says), `loadstring` (arbitrary Luau), and parenting the
   clone (measured to work, and it is exactly what that check exists to catch).
8. **Two harness checks, about different things.** The fixture proves the MECHANISM and bites in
   every session; the flag-table check proves the CALL SITES use it, by comparing Studio's answer
   with the names `declared_flags()` parses out of `src/shared/Flags/init.luau` — a different route
   from the one Studio takes. The fixture asserts only that a clone is fresh and **reports** whether
   the same instance went stale, so a future Roblox fix could never block this repo.
9. **Two mutations applied, run and restored.** The cached require put back → *"The Edit-mode flag
   table lists every flag the repo declares"* FAILS with `repo [...ORANGE_OUTFITS...], Studio
   [BOAR_SOUNDERS, TIE_UNTIL_DRIVE_END]` — the original bug, caught by the check. The fixture
   stopped cloning → `fresh` reads `A` and the mechanism check FAILS. Three offline selftest checks
   cover the parser, which is the half CI can run without Studio.
10. **Done for real, in the same Studio session that had refused it minutes earlier**, from the
    committed code and with the tree clean afterwards: `set ORANGE_OUTFITS on` →
    `override set: ORANGE_OUTFITS=true`; `flags` lists all three with `override on` / `effective
    on`; `clear` → `cleared: DHFlag_ORANGE_OUTFITS`.

## What I could not verify

- **`test2` is the Director's run.** This file is the harness, so the gate wants it; nothing here is
  two-player-specific, and `run_test2` keeps its own shorter Edit-mode check list (32, unchanged).
- **The two-player outfit screenshot is unblocked but still not taken** (77a(c), now 78a(a)). Step 1
  of those steps works now; the rest still needs a human click, and `test`/`test2` refuse to start
  while an override is set.
- **The flag-table check only bites in a session whose cache is already stale.** On a freshly opened
  Studio the cached and the fresh module agree and it passes either way — which is why there are
  two checks, and it is said in the code (78a(f)).
- **The cloned `Flags` still requires a session-cached `Shotgun`** for `deepFreeze`. Harmless
  because that is a pure function on frozen data — but that is reasoning, not a measurement, which
  is the kind of claim this task exists to distrust (78a(d)).
- **Nobody has asked what else in a long session is holding a stale module** (78a(c)). `mapgen.py
  stale` answers it for one module; reopening the place is still the only thing that clears them all.
