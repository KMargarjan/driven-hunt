# Task 312 — Karen's OK flips `AIM_REWIND` and `ZONES_FOLLOW_GAIT` on by default

Task: 312
Round: 1
Base: a7d264b0 (main, after PR #294)
Code commit: 6e1b0e11

`[harness] PASS: 34/34 checks @ 6e1b0e11374c81d0fbf14a2e1b6d34dc44383c5d (clean tree) scope=all`

## What changed

Two lines in `src/shared/Flags/init.luau`: `default = false` -> `default = true` on the `AIM_REWIND`
and `ZONES_FOLLOW_GAIT` rows, each with a one-line comment quoting Karen's OK (commit `3feb648f`).
Nothing else in `src/`, `tests/` or `tools/` is this task's own change. The branch then merged
`origin/main` (`9f046fcb`) to pick up task 314's `Viewmodel` handle-cache fix, which is what made the
gate runnable; that merge brings `src/client/Camera/Viewmodel.luau` and
`tests/client/camera_client.spec.luau` in unchanged from `main` (PR #294, already reviewed and
merged there).

## Claims

1. **This task's own change is exactly two behavioural lines in one file.**
   `git diff cc058bf4..3feb648f` touches only `src/shared/Flags/init.luau`, and its only non-comment
   lines are the two `default` values. `git diff a7d264b0..6e1b0e11 -- src tests` shows the same one
   file: nothing the merge brought in is modified on this branch.
2. **The rows are NOT retired and no losing branch was deleted** (the dispatch forbids it here; rule
   7 governs it later). Both rows still exist in `Flags.DEFAULTS` with `owner`, `born`, `expires`,
   `why`; `Flags.MAX_FLAGS` is unchanged and no row was removed.
3. **`AIM_REWIND`'s row made the flip conditional on two things, and both hold.** (a)
   `grep -rn SetNetworkOwner src/` shows `trunk:SetNetworkOwner(nil)` in `Body.attachVisual` after
   the weld loop that reverts ownership to AUTO, and `part:SetNetworkOwner(nil)` in `Body.create`.
   (b) `ESCALATE.md` records `+0.180 s, client in the PAST, residual 0.011 studs` from
   `<runs-dir>/305lag.py`, one-signed against a client-owned control of the opposite sign.
4. **The defaults are live ON with no override, READ from the DEV place.** `python tools/flags.py`
   prints `AIM_REWIND on none on 2026-11-18` and `ZONES_FOLLOW_GAIT on none on 2026-11-18` (default,
   override, effective), and every other row reads `none` in the override column — so the gate above
   ran against the shipped defaults, not against an attribute.
5. **No spec asserts either flag's default, so no spec needed updating.**
   `grep -rn "AIM_REWIND\|ZONES_FOLLOW_GAIT" tests/` returns nothing; `tests/server/flags.spec.luau`
   builds synthetic rows and otherwise keys off `TIE_UNTIL_DRIVE_END`, already `true`.
6. **The suite is green at the code commit, and the red that blocked round 1 yesterday is gone.**
   The harness line above is 34/34 on a clean tree, scope=all, naming `6e1b0e11`. No failure is
   excused in this round: no FAIL line is pasted and no flake is claimed (L-136). The earlier red —
   `rifle_client.spec:747` — was root-caused and fixed by task 314 (PR #294, on `main`), and the
   `ESCALATE.md` entry for 312 now carries that resolution line.
7. **`test2` is N/A, answered by the tool.** `agents.needs_two_player` returns `[]` for all three
   files in this branch's diff against `main` (`src/shared/Flags/init.luau`,
   `src/client/Camera/Viewmodel.luau`, `tests/client/camera_client.spec.luau`); `TWO_PLAYER_PATHS`
   contains none of them. `tools/review.sh`'s own line in the log says the same.
8. **CORE-NA, and no look claim is made.** No input path, weapon geometry, ballistic or
   animal-behaviour code changed. The behaviour now shipped by default is the behaviour Karen played
   and accepted on 2026-10-30 ("yes", ~09:30 UTC), recorded in `PLAYTEST.md` with the disclosure
   that both flags were lit by attribute at the time. The green gate is NOT offered as a picture of
   anything on screen (L-138): the only on-screen evidence for this behaviour is Karen's own play.

## What could not be verified

- **Anything on screen in this round.** No frame was taken and none is claimed; the aim/zone
  behaviour's visual proof is Karen's accepted playtest, not this gate (L-138, L-127: no verdict
  here is written from intent, and the only quoted readings are the `flags.py` lines in claim 4 and
  the harness line above).
- **Anything in Karen's Forest Test.** The dispatch forbids touching it: it was not opened, stopped,
  read or written, and `tools/flags.py` was never run against it.

ANSWERED: L-136 — no FAIL line and no flake claim in this round; the run is 34/34 at the code commit.
ANSWERED: L-127 — every number here is quoted from an instrument (the harness line, `flags.py`'s own
rows); the behaviour verdict is Karen's play, not the Builder's reading of intent.
