# Task 364 -- DRIVE_VARIETY ships ON (Karen's OK)

Task: 364
Round: 2
Base: 840d01ed (origin/main)
Code commit: cc35e3949433d5a94ebd54347987b34dc31570c6

Karen, 2026-11-13 ~11:55 UTC, after playing her Forest Test with `DRIVE_VARIETY` on by attribute:
*"variation also good"*. CLAUDE.md's feature-flags section: her OK flips the default in a later small
commit with the one-player gate.

`git diff 840d01ed..HEAD -- src tests tools`: `src/shared/Flags/init.luau`,
`src/server/ForestTest/init.luau`, `tests/server/flags.spec.luau`, `deer.spec.luau`,
`forest_line.spec.luau`, `forest_placement.spec.luau`, `forest_stand.spec.luau`. No
`TWO_PLAYER_PATHS` file, so `test2` is N/A -- `src/server/ForestTest/` is not in that list; the
match, the drive, the tie and the teams are, and none of them is touched.

## Harness

```
[harness] PASS: 34/34 checks @ cc35e3949433d5a94ebd54347987b34dc31570c6 (clean tree) scope=all
```

`f494440a` is the last commit to touch `src/`, `tests/` or `tools/`; `cc35e394` is this request and
nothing else, so the line covers the code and only paperwork follows it (git workflow step 4).
An earlier clean 34/34 at `53bd250c` covers the same code minus the one census comment line
(`PASS: 34/34 checks @ 53bd250ca0f40990eb3952501a75ae9fdc9a3cba (clean tree) scope=all`, 00:53 UTC).

## Claims

1. **The flip is the row and nothing else.** `Flags.DEFAULTS.DRIVE_VARIETY`: `default = true`,
   `expires` 2026-12-03 -> 2026-12-31 (accepted, not a 21-day dark path any more, the shape
   `ZONES_FOLLOW_GAIT` already uses), Karen's words in the comment and at the head of `why`.
   Verify: `git diff 840d01ed..HEAD -- src/shared/Flags/init.luau`.
2. **The flag is NOT retired and the OFF branch is untouched.** No row removed, nothing archived,
   the generator and `Data.variedSchedule` unchanged. Verify: `git diff 840d01ed..HEAD -- src`
   touches two files, neither of them `src/shared/ForestTest/`.
3. **MEASURED, live from the DEV Studio, `python tools/flags.py`.**
   BEFORE `DRIVE_VARIETY off none off 2026-12-03 ServerScriptService.ForestTest`;
   AFTER `DRIVE_VARIETY on none on 2026-12-31 ServerScriptService.ForestTest`. Override `none` both
   times. Verify: run it.
4. **ROUND 1's CLAIM 4 IS WITHDRAWN. The Reviewer's finding 2 was right.** What I had measured was a
   grep for the flag's NAME in `tests/` (no hit), and a grep cannot see `ForestTest.start`'s
   callers. Two spec files DO reach the gated path through the flag: `forest_placement.spec` (26
   `Forest.start` sites) and `forest_stand.spec` (6), and `start` is the one reader. What is true is
   narrower: **no spec asserts the flag's default value by name**, and the generator's two arms are
   driven by parameter in `forest_line.spec` (`Data.variedSchedule(SCHEDULE, 1, weigh, false/true)`).
   `TASKS.md`'s status row now says that instead.
5. **Finding 1 is fixed at the owner's boundary, in the shape `inPlace` already has.**
   `ForestTest.start(runtime, now, varietyIn, seedIn)` and
   `ForestTest.waveAt(index, inPlace, varietyIn)` take the value by parameter; production passes
   nothing and reads `Flags.isOn("DRIVE_VARIETY")` at that one boundary, exactly as before.
   The spec sites now say which drive they mean: 32 `start(..., 0, false, 1)`, the 8 no-argument
   `Forest.cellSchedule()` calls become `cellSchedule(false)`, and `forest_line`'s
   "is what BOTH release paths read" becomes `waveAt(slot, nil, false)`. So no spec rides
   `state.sessionSeed`'s unseeded draw, and `planDrive`'s roster and the release path cannot be two
   different draws. No case was deleted; no `it` node was added or removed.
   Verify: `grep -rn "waveAt(\|cellSchedule(\|driveVariety()" tests` -- every hit passes a boolean;
   `grep -n varietyIn src/server/ForestTest/init.luau`.
6. **What keeps the flip flipped is a spec, and it bites.** `flags.spec`'s existing `isOn` case
   ("answers the resolved value for a declared one") also asserts
   `DEFAULTS.DRIVE_VARIETY.default`, `Flags.defaults().DRIVE_VARIETY`,
   `Flags.resolve(Flags.defaults(), nil).DRIVE_VARIETY` and Karen's words in `why`.
   **FAIL FIRST** for the first of those four, measured with `default = false` restored (dirty tree
   at 840d01ed, 23:11 UTC) -- at that moment the assertions sat in a NEW `it` node, which is why the
   pasted line names `flags.spec:115` while the shipped case is in `isOn`:
   `failed [server] flags.spec:115 Expected value "true" (boolean), got "false" (boolean) instead`.
   The bite is unchanged by the move, and round 1's own note 3 agrees: "the new `flags.spec`
   assertions do bite -- reverting `default` to false fails all three".
7. **They went into an EXISTING case on purpose, and that was measured.** As a new `it` node the
   server suite failed **7 runs of 7** (`licence_popup.spec:367`, `weapon_shot.spec:1890`,
   `deer_hitbox.spec:340`/`:682` -- none of them this change's code); the same code without that
   node passed **4 of 4**, including two clean-tree controls at `840d01ed`
   (`[harness] PASS: 34/34 @ 840d01ed`, 23:35 and 23:40 UTC). That is task 80's lesson: inserting a
   spec node shifts which moment of the live Play session every later spec samples.
8. **ONE CHANGE IS NOT THIS TASK'S FLAG, in its own commit:** `DEER_ROAD_LEAP`'s `expires` was
   `2026-11-13`, so at 00:00 UTC today the rot tripwire began failing `flags.spec` and with it the
   whole harness **for every task, main included** -- measured on main at 00:22 UTC:
   `[harness] FAIL: 32/34 checks @ 840d01edbbbc537c3755ea327899466973def7c1 (clean tree) scope=all`
   with `flags.spec:124 Expected value "0" (number), got "1" (number)`. CLAUDE.md prescribes this
   fix; the date is `2026-12-05` with the reason (dark until TASKS.md 245c, the Director's
   2026-10-24 decision) in the row, in `why`, in `deer.spec` (which pins it) and in `ESCALATE.md`.
   The flag's VALUE is untouched: `DEER_ROAD_LEAP off none off`.
9. **`STAG_BOUND_ON_SPOOK` fires the same tripwire at 00:00 UTC on 2026-11-15** (`expires`
   `2026-11-14`). Not touched -- not expired yet, and not this task's flag. `ESCALATE.md` says so.
10. **The round-1 note that is one line is done:** the file header's LIT/DARK census counts
    `DRIVE_VARIETY` among the lit. Verify: the census comment in `src/shared/Flags/init.luau`.

## What I could not verify

- **The dispatch's pattern-line proof is NOT OBTAINABLE in DEV, and I did not work around it.**
  `ForestTestBoot` returns at its fourth line in any place that is not the Forest Test and is the
  only caller of `ForestTest.patternLine()`; the StudioMCP thread cannot `require` a ModuleScript
  (the harness docstring's own measurement), so no probe can call it; and the dispatch forbids
  touching her Forest Test, which `ftplay.py mode` confirmed is in **Edit** (nothing else was called
  against it). What IS measured is claim 3 plus the one line between it and the drive --
  `state.driveVariety = ... Flags.isOn("DRIVE_VARIETY")` -- with the generator below it unchanged by
  this task. `ESCALATE.md`, 2026-11-14 00:40 UTC.
- **The suite is flaky tonight around this change and not because of it.** Named, with two commits:
  `licence_popup.spec:367` (TASKS.md row 362b), `weapon_shot.spec:1890` and
  `deer_hitbox.spec:340`/`:682` (rows 281a(b), 281a(c)), and the StudioMCP input transport fault
  (`tie-the-driver: ... Target is not reachable (DMN_ID_PLAYCLIENT)`, row 362b) which drags
  `weapon_client` with it. `deer_hitbox.spec:682` fired on **main** at `840d01ed` too (00:22 UTC).
  The code commit's own run is a clean 34/34.

## The runs

| what | commit | tree | line |
|---|---|---|---|
| gate, round 2 | `cc35e394` | clean | `PASS: 34/34 ... scope=all` (01:05 UTC) |
| gate, round 2 | `53bd250c` | clean | `PASS: 34/34 ... scope=all` (00:53 UTC) |
| gate, round 1 | `6a12123b` | clean | `PASS: 34/34 ... scope=all` (00:27 UTC) |
| control | `840d01ed` | clean | `PASS: 34/34` twice (23:35, 23:40 UTC, before the date rolled) |
| control | `840d01ed` | clean | `FAIL: 32/34` (00:22 UTC, after midnight: the expired flag) |
| FAIL FIRST | `840d01ed` plus the case, `default=false` | dirty | `flags.spec:115 Expected "true", got "false"` |
