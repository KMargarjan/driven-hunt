# Task 312 — Karen's OK flips `AIM_REWIND` and `ZONES_FOLLOW_GAIT` on by default

Task: 312
Round: 2
Base: a7d264b0 (main, after PR #294)
Code commit: acb34e7a

`[harness] PASS: 34/34 checks @ acb34e7a7ddc417818cb575fc56b96cf1f545e97 (clean tree) scope=all`

## What changed

Two lines in `src/shared/Flags/init.luau`: `default = false` -> `default = true` on the `AIM_REWIND`
and `ZONES_FOLLOW_GAIT` rows, each with a one-line comment quoting Karen's OK (commit `3feb648f`),
plus round 1's finding in the same file (`f33c2612`): both `expires` dates moved out of the 21-day
dark window, and the two stale comment blocks the round noted. Nothing else in `src/`, `tests/` or
`tools/` is this task's own change. The branch then merged
`origin/main` (`9f046fcb`) to pick up task 314's `Viewmodel` handle-cache fix, which is what made the
gate runnable; that merge brings `src/client/Camera/Viewmodel.luau` and
`tests/client/camera_client.spec.luau` in unchanged from `main` (PR #294, already reviewed and
merged there).

## Claims

1. **This task's own change is one file, `src/shared/Flags/init.luau`.**
   `git diff a7d264b0..acb34e7a -- src tests` names that file and nothing else: nothing the merge
   brought in from `main` is modified here. Two behavioural lines (`default = false` -> `true` on
   both rows, commit `3feb648f`), and in `f33c2612` round 1's finding: both `expires` dates and
   three comment blocks.
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
4a. **ROUND 1 FINDING 1 IS FIXED, as the design's own step says.**
   `docs/design/feature-flags.md` section 11 step 6a: an accepted flag's flip moves `expires` out to
   the retirement task's date. Both rows now read `expires = "2026-12-31"` -- the nine lit rows'
   precedent -- in place of the 21-day dark-path `2026-11-18`, each with the accepted-flag reason
   those rows carry instead of the "21 days, the ceiling" comment. So `Flags.problems` cannot emit
   `EXPIRED` for them and `flags.spec`'s rot tripwire cannot fire on 2026-11-19. The round's two
   non-blocking comment notes are in the same commit: the cap commentary no longer says
   `ZONES_FOLLOW_GAIT` "ships DARK", and the LIT/DARK census now reads 14/7 and names
   `AIM_REWIND`, `ZONES_FOLLOW_GAIT` and the `HIT_CLAIM` row it had always omitted. Verify by
   counting `default = true` rows: 14, and 21 rows in all, `Flags.MAX_FLAGS` untouched.
5. **No spec asserts either flag's default, so no spec needed updating.**
   `grep -rn "AIM_REWIND\|ZONES_FOLLOW_GAIT" tests/` returns nothing; `tests/server/flags.spec.luau`
   builds synthetic rows and otherwise keys off `TIE_UNTIL_DRIVE_END`, already `true`.
6. **The suite is green at the code commit, and one intermittent red is disclosed with its control
   pair rather than excused by a word.** Three full runs, all `scope=all`, clean tree:
   - `[harness] PASS: 34/34 checks @ acb34e7a7ddc417818cb575fc56b96cf1f545e97 (clean tree) scope=all` — the code commit
   - `[harness] FAIL: 32/34 checks @ acb34e7a7ddc417818cb575fc56b96cf1f545e97 (clean tree) scope=all` — the SAME commit, one run earlier, on `failed [server] deer_hitbox.spec:682 calf: legs box 1 is unreachable by a flank ray`
   - `[harness] PASS: 34/34 checks @ a7d264b0387f80ef46a3b0aeb62587b59f7a97bf (clean tree) scope=all` — CONTROL at `main`, this change absent
   The first run of this branch, `[harness] PASS: 34/34 checks @ 6e1b0e11374c81d0fbf14a2e1b6d34dc44383c5d (clean tree) scope=all`,
   already had both flags lit and the identical `src/` for this spec: `acb34e7a` differs from
   `6e1b0e11` only in `expires` strings and comments, which no deer geometry reads. So the failure
   is NOT this change: it is intermittent in `deer_hitbox.spec` itself (it casts real rays at a LIVE
   animal whose pose drifts, so a small `legs` box on the calf can be behind another part at the
   instant of the cast). Not called "the flake" and not dismissed — queued in `TASKS.md` as a note
   for the Director. The red that blocked round 1 yesterday, `rifle_client.spec:747`, was
   root-caused and fixed by task 314 (PR #294, on `main`); `ESCALATE.md`'s 312 entry carries that
   resolution line.
7. **`test2` is N/A, answered by the tool.** Round 1's own `tools/review.sh` line read
   `harness line(s) found for the code commit (1 code file(s) changed, 0 needing two players)`:
   `agents.needs_two_player` returns `[]` for `src/shared/Flags/init.luau`, the one code file in the
   diff, and `TWO_PLAYER_PATHS` contains no `src/shared/Flags/` entry.
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
