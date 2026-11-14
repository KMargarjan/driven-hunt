# Task 364 -- DRIVE_VARIETY ships ON (Karen's OK)

Task: 364
Round: 1
Base: 840d01ed (origin/main)
Code commit: 6a12123be767c2135397c650834a8c9834986d09

Karen, 2026-11-13 ~11:55 UTC, after playing her Forest Test with `DRIVE_VARIETY` on by attribute:
*"variation also good"*. CLAUDE.md's feature-flags section: her OK flips the default in a later small
commit with the one-player gate.

`git diff 840d01ed..HEAD -- src tests tools` is three files: `src/shared/Flags/init.luau`,
`tests/server/flags.spec.luau`, `tests/server/deer.spec.luau`. No `TWO_PLAYER_PATHS` file, so
`test2` is N/A.

## Harness

```
[harness] PASS: 34/34 checks @ 6a12123be767c2135397c650834a8c9834986d09 (clean tree) scope=all
```

## Claims

1. **The flip is the row and nothing else.** `Flags.DEFAULTS.DRIVE_VARIETY`: `default = true`,
   `expires` 2026-12-03 -> 2026-12-31 (accepted, not a 21-day dark path any more, the shape
   `ZONES_FOLLOW_GAIT` already uses), and Karen's words at the head of `why` and in the comment.
   Verify: read the row; `git diff 840d01ed..HEAD -- src/shared/Flags/init.luau`.
2. **The flag is NOT retired and the OFF branch is untouched.** No row removed, nothing archived,
   `ForestTest.cellSchedule(varietyIn)` and `Data.variedSchedule(.., false)` unchanged.
   Verify: `git diff 840d01ed..HEAD -- src` names one file; `forest_line.spec`'s
   "is the shipped table BY IDENTITY with the switch off" still drives both arms by parameter.
3. **MEASURED, live from the DEV Studio, `python tools/flags.py`.**
   BEFORE `DRIVE_VARIETY off none off 2026-12-03 ServerScriptService.ForestTest`;
   AFTER `DRIVE_VARIETY on none on 2026-12-31 ServerScriptService.ForestTest`. Override `none` both
   times. Verify: run it.
4. **No spec asserted DRIVE_VARIETY's default, and none reaches the gated path BY THE FLAG.**
   Measured, not assumed: no `isOn("DRIVE_VARIETY")` anywhere in `tests/`; the only reader in `src/`
   is `ForestTest.start`; `forest_line.spec` drives both arms through the parameter
   (`Data.variedSchedule(SCHEDULE, 1, weigh, false/true)`), and `Data.groupsWanted` fixes the slot
   count from the density dial, so the generated drive has the same number of rows as the script and
   no spec's count moves with the flag. So item 2 of the dispatch needed no edit and no case was
   deleted. Verify: `grep -rn 'DRIVE_VARIETY' tests/` and `grep -rn 'DRIVE_VARIETY' src/`.
5. **What keeps it flipped is a spec, and it bites.** `flags.spec`'s `isOn` case
   ("answers the resolved value for a declared one") now also asserts `DEFAULTS.DRIVE_VARIETY.default`,
   `Flags.defaults().DRIVE_VARIETY`, `Flags.resolve(Flags.defaults(), nil).DRIVE_VARIETY` and
   Karen's words in `why`. **FAIL FIRST**, that case, with `default = false` restored and the case
   present (dirty tree at 840d01ed, 23:11 UTC):
   `failed [server] flags.spec:115 Expected value "true" (boolean), got "false" (boolean) instead`.
6. **The assertions went into an EXISTING case on purpose, and that was measured.** As a NEW `it`
   node the server suite failed **7 runs out of 7** -- `licence_popup.spec:367`,
   `weapon_shot.spec:1890`, `deer_hitbox.spec:340`/`:682`, none of them this change's code -- while
   the same code without that node passed **4 of 4**, including two clean-tree controls at
   `840d01ed` (`[harness] PASS: 34/34 @ 840d01ed`, 23:35 and 23:40 UTC). That is task 80's lesson
   (TASKS.md row 80): inserting a spec node shifts which moment of the live Play session every later
   spec samples. The node count is now unchanged. Verify: the comment in the case says so; the run
   files are listed under "The runs" below.
7. **ONE CHANGE HERE IS NOT THIS TASK'S FLAG, and it is in its own commit:** `DEER_ROAD_LEAP`'s
   `expires` was `2026-11-13`, so at 00:00 UTC today the rot tripwire began failing `flags.spec` and
   with it the whole harness -- **for every task, main included**. Measured on main:
   `[harness] FAIL: 32/34 checks @ 840d01edbbbc537c3755ea327899466973def7c1 (clean tree) scope=all`
   with `flags.spec:124 Expected value "0" (number), got "1" (number)`, 00:22 UTC. CLAUDE.md
   prescribes exactly this fix -- retire it, flip it, or move the date with a reason -- so the date
   is `2026-12-05` with the reason (dark until TASKS.md 245c, the Director's 2026-10-24 decision) in
   the row, in `why`, in `deer.spec`, and in `ESCALATE.md`. Commits `eb3cb43e` and `6a12123b`.
   The flag's VALUE is untouched: `DEER_ROAD_LEAP off none off` after, as before.
8. **`STAG_BOUND_ON_SPOOK` fires the same tripwire at 00:00 UTC on 2026-11-15** (`expires`
   `2026-11-14`). Not touched -- not expired yet, and not this task's flag. `ESCALATE.md` says so.

## What I could not verify

- **The dispatch's pattern-line proof is NOT OBTAINABLE in DEV, and I did not work around it.**
  `ForestTestBoot` returns at its fourth line in any place that is not the Forest Test, and it is
  the only caller of `ForestTest.patternLine()`; the StudioMCP thread cannot `require` a
  ModuleScript (the harness docstring's own measurement), so no probe can call it either; and the
  dispatch forbids touching her Forest Test, which `ftplay.py mode` confirmed is in **Edit**
  (nothing else was called against it). What IS measured is claim 3 plus the one line between it and
  the drive -- `state.driveVariety = Flags.isOn("DRIVE_VARIETY")` -- with the generator below it
  byte-identical to the build Karen played ON. `ESCALATE.md`, 2026-11-14 00:40 UTC.
- **The suite is flaky tonight around this change and not because of it.** Named, with two commits:
  `licence_popup.spec:367` (TASKS.md row 362b, an unlisted flake), `weapon_shot.spec:1890` and
  `deer_hitbox.spec:340`/`:682` (TASKS.md rows 281a(b), 281a(c)), and the StudioMCP input transport
  fault (`tie-the-driver: ... Target is not reachable (DMN_ID_PLAYCLIENT)`, row 362b) which drags
  `weapon_client` with it. `deer_hitbox.spec:682` fired on **main** at `840d01ed` as well
  (00:22 UTC run above). The code commit's own run is a clean 34/34.

## The runs

| what | commit | tree | line |
|---|---|---|---|
| gate | `6a12123b` | clean | `PASS: 34/34 ... scope=all` (00:27 UTC) |
| control | `840d01ed` | clean | `PASS: 34/34` x2 (23:35, 23:40 UTC, before the date rolled) |
| control | `840d01ed` | clean | `FAIL: 32/34` (00:22 UTC, after midnight: the expired flag) |
| FAIL FIRST | `840d01ed` + the case, `default=false` | dirty | `flags.spec:115 Expected "true", got "false"` |
