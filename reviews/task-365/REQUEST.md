# Task 365 - four flag expiry dates moved so the harness stays green

Task: 365
Round: 1
Base: c8c6e178 (origin/main)
Code commit: 0b2069d3642a84d511ff6cd186837a91f279e044

Karen is away until ~2026-11-15. Four rows in `src/shared/Flags/init.luau` expire before she can
decide them, and an expired row fails the rot tripwire in `tests/server/flags.spec.luau`, which fails
the harness for **every** branch. All four dates move to `2026-12-01`. No value, default, owner,
born or why changes; nothing a player sees changes.

## MEASURED: before | after

Read from the file AND from the live DEV flags read (`python tools/flags.py`, place 136410205938347).

| row | expires before | expires after | default before \| after | override | effective |
|---|---|---|---|---|---|
| STAG_BOUND_ON_SPOOK | 2026-11-14 | 2026-12-01 | off \| off | none | off |
| HIT_CLAIM | 2026-11-15 | 2026-12-01 | off \| off | none | off |
| RANGE | 2026-11-17 | 2026-12-01 | off \| off | none | off |
| RANGE_SOLO | 2026-11-20 | 2026-12-01 | off \| off | none | off |

`2026-12-01` is 17 days from the move, inside the 21-day ceiling in
`docs/design/feature-flags.md` section 12.

## Claims

1. **Exactly four `expires` values changed, and nothing else in those four rows.**
   `git diff c8c6e178..0b2069d3 -- src/shared/Flags/init.luau`: four `-expires`/`+expires` pairs,
   `+"2026-12-01"` each, plus two comment lines per row. No `default`, `owner`, `born` or `why` line
   appears in the diff.
2. **No other flag row moved.** Same diff: the other 26 rows are absent from it.
3. **Each moved row carries the reason.** Each of the four has the line `MOVED to 2026-12-01 by the
   Director 2026-11-14: Karen is away; the keep/retire decision is hers on return (task 365).`
   `grep -n "MOVED to 2026-12-01" src/shared/Flags/init.luau` returns four hits.
4. **The live game agrees with the file.** `python tools/flags.py` prints `2026-12-01` for all four,
   with `default off`, `override none`, `effective off` — the table above, right-hand columns.
5. **The dispatch missed one coupling, and it is fixed.** `tests/server/deer.spec.luau` pins
   `STAG_BOUND_ON_SPOOK.expires` **by value**, so moving the row alone failed that spec: measured
   `[harness] FAIL: 29/34 checks @ 2d7995b9e9d63a0dede35ea33921733d983715fa (clean tree) scope=all`,
   `Expected "2026-11-14", got "2026-12-01"`. The pin now reads `2026-12-01`, with the same reason,
   exactly as task 364 did for the sibling `DEER_ROAD_LEAP` pin in the same file (line ~1636).
   Verify: `grep -n 'row.expires' tests/server/deer.spec.luau`.
6. **That was the only pin of any of the four dates.** `grep -rn '2026-11-14\|2026-11-15\|2026-11-17\|2026-11-20' tests/`
   returns only the (now updated) `deer.spec` case plus task 364's own comment text; and
   `grep -rn 'row.expires\|\.expires)' tests/` shows the other three pins belong to other flags
   (`2026-12-03`, `2026-12-31`, `2026-12-05`, `> 2026-10-18`), none of them touched.
7. **The spec case still asserts the feature DARK.** In the same `deer.spec` case: `row.default` is
   still asserted `false`, `CONFIG.KINDS.stag.spook.bound` still `== Flags.isOn(...)` and `== false`,
   and every behaviour case still drives the bound on **by parameter** (`configWith(true)`).
   Nothing about what the stag does changed.
8. **Full gate green at the code commit, on a clean tree.**
   `[harness] PASS: 34/34 checks @ 0b2069d3642a84d511ff6cd186837a91f279e044 (clean tree) scope=all`
   (exit 0; server 2998 passed / 0 failed, client 719 passed / 0 failed).
9. **`test2` is N/A.** The change touches `src/shared/Flags/` and `tests/server/deer.spec.luau`;
   neither is in `TWO_PLAYER_PATHS` in `tools/agents.py` (match, drive, tie, teams). Nothing about a
   second player is in question: no flag's effective value moves at all.
10. **Lint, format and both selftests pass.** `selene src`, `selene --config tests/selene.toml tests`
    and `stylua --check src tests` all clean; `python tools/studio_mcp.py selftest` and
    `python tools/agents.py selftest` both PASS.

## What I could not verify, stated plainly

- **Two earlier runs of this same code were not reproducible, and I cannot name every assertion that
  failed in them.** Three full runs happened:
  `[harness] FAIL: 29/34 checks @ 2d7995b9e9d63a0dede35ea33921733d983715fa (clean tree) scope=all` —
  server 2 failed/2 errors (one of them the real `deer.spec` pin above), client 2 failed/2 errors at
  `weapon_client.spec:1175` (`expect(finished).to.equal(true)`) and `weapon_client.spec:1300`
  (`expect(sawSwapInProgress).to.equal(true)`), both input-replay assertions;
  then at the fixed commit `FAIL: 31/34 @ 0b2069d3...` — server 1 failed/1 error, client fully clean;
  then at the **same commit** `PASS: 34/34 @ 0b2069d3...` — server and client fully clean.
  So the same commit produced both a failure and a pass. The server assertion that failed in the
  middle run is **not named here because I did not capture it**: the harness keeps no report file and
  I read those two runs through `tail`. I am not claiming it is harmless — only that it is not
  reproducible at this commit and that it is not any `expires` assertion (run 3 ran all 2998 server
  cases green at the same tree).
- **No Forest Test proof, by instruction.** Karen's place was not opened, no override was read or
  written there, and nothing was Saved, Published or committed to Drafts.
- **No screenshot (rule 5):** nothing drawn changes. The four rows stay `off` and `effective off`.

## ANSWERED (the dispatch's CHECKED flags)

- **ANSWERED: L-127** BEFORE | AFTER is given per line for all four rows, from two instruments (the
  file diff and the live `tools/flags.py` read), in the MEASURED table above.
- **ANSWERED: L-162** Every proof is at the code commit `0b2069d3`: the PASS line names it, and the
  harness itself checked `HEAD unchanged during the run (0b2069d3642a -> 0b2069d3642a)`.
- **ANSWERED: L-136** The non-reproducible failures that fired before the green run are named above
  with their commits, their counts and (for the two client ones) their spec and line — including the
  one I could not name, said as such rather than passed over.
