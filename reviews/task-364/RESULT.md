PASS (item 3 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the varied drive itself HAS been
seen in Karen's place -- she played her Forest Test with `DHFlag_DRIVE_VARIETY` on and said
*"variation also good"* (2026-11-13), and `src/server/ForestTest/init.luau`'s generator is unchanged
by this task. What has NOT been seen anywhere is a drive dealt with the flag resolving from the
SHIPPED DEFAULT: the dispatch's item 3 pattern line was not produced, and the reason in `ESCALATE.md`
2026-11-14 00:40 is true in the repo -- `ForestTestBoot.server.luau` has `if Map.EXPECTED_WORLD ~=
"forest-test" then return end` above every line of its body, and its `local pattern =
ForestTest.patternLine()` is the ONLY call to that function in `src/`. So item 3 is proven only as
far as `tools/flags.py`'s before/after read of the resolved default, not as a live varied drive on a
default-ON server.

Round 1's two blocking findings are fixed, checked by reading, not by the Builder's word:
- finding 1: `ForestTest.start(runtime, now, varietyIn, seedIn)` and
  `ForestTest.waveAt(index, inPlace, varietyIn)` take the value, `cellSchedule(varietyIn, ...)` reads
  it with `local on = if type(varietyIn) == "boolean" then varietyIn else ForestTest.driveVariety()`,
  and production still passes nothing: `ForestTestBoot`'s `ForestTest.start(runtime, os.clock())` and
  the two internal `ForestTest.waveAt(slot, onNow)` sites are two-argument, so
  `state.driveVariety = ... else Flags.isOn("DRIVE_VARIETY")` is still the one boundary read. Every
  call site in `tests/` now pins the arm -- 26 `Forest.start(..., 0, false, 1)` in
  `forest_placement.spec`, 6 `ForestTest.start(..., 0, false, 1)` in `forest_stand.spec`, 8
  `cellSchedule(false)`, and `waveAt(slot, nil, false)` in `forest_line.spec`'s identity case -- so
  `state.driveVariety` is false for the whole live session and `cellSchedule` returns `base` by
  identity on both the `planDrive` (`cellSchedule(nil, key)`) and the release (`cellSchedule()`)
  side. The two draws round 1 named can no longer differ. No `it` node added or removed, no case
  deleted (diff is argument-only in all four spec files).
- finding 2: claim 4 is withdrawn in `REQUEST.md` and in `TASKS.md`'s status row, and the narrower
  statement it replaces it with is true -- grep for `DRIVE_VARIETY` finds no spec naming the flag
  outside `flags.spec`'s new assertions.
Delete the producer: revert `Flags.DEFAULTS.DRIVE_VARIETY.default` to `false` and three of
`flags.spec`'s four new lines fail (`DEFAULTS...default`, `Flags.defaults()`, `Flags.resolve(...)`);
none compares a value with itself -- each is a derived read against the literal `true`, and
`Flags.defaults()`/`Flags.resolve` are separate pure functions over the row, not the row. The fourth
(`string.find(why, "variation also good")`) dies with the `why` text. `forest_line.spec`'s touched
case keeps an independent hard number, `expect(silent).to.equal(2)`, which survives nothing.

## Notes (non-blocking)
- `ForestTest.cellSchedule` ON arm — the arm that now SHIPS is the one no spec drives: every site in
  `tests/` passes `false`, and the generator is covered only one layer down
  (`Data.variedSchedule(SCHEDULE, 1, weigh, true)` and `Data.generateDrive(Data.driveSeed(...))` in
  `forest_line.spec`). The server glue — `driveVariety()`, `ForestTest.driveSeed(driveNumber)`,
  `weighParty` — has no ON-state case. Queue one `cellSchedule(true)` / `waveAt(slot, nil, true)`
  case, as `inPlace` already has both arms (`waveAt(slot, true)` and `waveAt(slot, false)`).
- `src/server/ForestTest/init.luau`, `seedIn` — no case asserts it does anything: every spec site
  passes `false` for the variety, which makes `state.sessionSeed` dead for the rest of that call.
  Queue it with the ON-arm case above, where a pinned seed is the point of it.
- `tests/server/deer.spec.luau` — round 1's note is still open: the case title "is BORN OFF, with an
  owner, a birthday and an expiry inside 21 days" is false against `born = "2026-10-23 task 245b"`
  and `expect(row.expires).to.equal("2026-12-05")` (43 days). The assertion is exact and bites;
  rename the case.
- `src/shared/Flags/init.luau` header census — `LIT (15)` is now right (15 rows at `default = true`,
  counted). `DARK (8)` is still wrong and was wrong before this change: 15 rows are at
  `default = false`, and the census names 8 — CARCASS_POSE, BOAR_ATTACH_BUDGET,
  DRIVE_AIMS_AT_PICKED_STAND, STAND_PICK, PLACEMENT_IN_PLACE, MAP_LOOK and MAP_PAINTED are missing.
  Not made worse here.
- `src/shared/Flags/init.luau`, `Flags.MAX_FLAGS = 30` — 30 rows are declared and the tripwire is
  `#names > Flags.MAX_FLAGS`, so the table sits exactly on its cap. The next flag needs the cap line
  moved in the same commit.
- `src/shared/Flags/init.luau`, `STAG_BOUND_ON_SPOOK` — `expires = "2026-11-14"` and the tripwire is
  `row.expires < today`, so at 00:00 UTC on 2026-11-15 `flags.spec`'s rot case goes red and the whole
  harness with it, for every task including main. Correctly not touched here; queue it before
  midnight.
- `src/shared/Flags/init.luau`, `DEER_ROAD_LEAP` — the date move is outside the dispatch ("NOT YOURS:
  any other flag"), but it un-breaks rather than breaks: `Flags.problems` fails only on
  `row.expires < today`, the VALUE is untouched (`default = false`, and `deer.spec`'s
  "reads the flag at ONE boundary" still asserts `CONFIG.MODEL.LEAP.ENABLED == false`), it is its own
  commit `eb3cb43e` plus `6a12123b` for the spec pin, and `ESCALATE.md` 2026-11-14 00:15 hands the
  call to the Director. Flagged, not disputed.
- `reviews/task-364/REQUEST.md` claim 6 — the pasted FAIL FIRST `flags.spec:115` still does not point
  at the shipped case: line 115 of the committed file is `end).to.throw()` in the deep-freeze case.
  The request now explains this (a new `it` node at the time of the measurement) and claim 8's `:124`
  against `ESCALATE.md`'s `:136` reconciles exactly against flags.spec's +12 lines, with the
  committed `expect(#problems).to.equal(0)` at 136. Consistent, but as pasted the FAIL FIRST line
  does not name the case that ships.
- `ESCALATE.md` 2026-11-14 00:40 and `REQUEST.md` — "`ForestTestBoot.server.luau` returns at its
  fourth line" is loose; the guard is `if Map.EXPECTED_WORLD ~= "forest-test" then return end` after
  the service and module requires. The substance is right.
- `docs/design/feature-flags.md` §12 "Default flip diff ≤ 3 lines in one file" — the substantive flip
  is exactly 3 (`default`, `expires`, `why`'s head); the extra diff lines in that row are the
  comments CLAUDE.md requires. Not counted against it.
- Checked and clean: the harness line `PASS: 34/34 checks @
  cc35e3949433d5a94ebd54347987b34dc31570c6 (clean tree) scope=all` names the request's `Code commit:`
  and `scope=all` is full evidence; `f494440a` (the last `src/` commit, the census line) precedes it,
  so the line covers all the code; `paperwork-after-code-commit.txt` says only `REQUEST.md` followed
  it. `test2` N/A is right — none of `src/server/ForestTest/init.luau`,
  `src/shared/Flags/init.luau`, `tests/server/{deer,flags,forest_line,forest_placement,forest_stand}
  .spec.luau` starts with a `TWO_PLAYER_PATHS` entry in `tools/agents.py`. selene (src and tests),
  stylua and rojo build all exit 0. No row removed and nothing deleted, so rule 7 asks for no
  archive. `DRIVE_VARIETY` is read in exactly one place in `src/`
  (`ForestTest.start`), and `variedSchedule`/`cellSchedule` have no caller outside
  `src/server/ForestTest/init.luau` — the flip reaches no other world. No secret, key, local absolute
  path or non-noreply email in the diff. §11 step 6a does sanction `expires` moving out on
  acceptance, and `Flags.problems` enforces no 21-day ceiling, so neither moved date trips it.

---
REVIEWER verdict on commit `088f15ae7679856e3e8a6637ca49d3f4c90a3858` (round 2) · 2026-11-14 01:16 UTC · session cost $3.11, 40 turns · written by tools/agents.py
