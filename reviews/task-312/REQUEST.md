# Task 312 — Karen's OK flips `AIM_REWIND` and `ZONES_FOLLOW_GAIT` on by default

Task: 312
Round: 1
Base: cc058bf4 (main)
Code commit: 3feb648f

**THIS REQUEST CANNOT BE REVIEWED YET AND THE BUILDER KNOWS IT.** The harness-before-review gate
wants a `PASS` line for the code commit. There is none, and the reason is not this change: `main`
itself is red. See `ESCALATE.md`, 2026-10-30, and claim 4 below. It is written so the Director can
run the round unchanged the moment `main` is green.

## What changed

Two lines in `src/shared/Flags/init.luau`: `default = false` -> `default = true` on the `AIM_REWIND`
and `ZONES_FOLLOW_GAIT` rows, each with a one-line comment quoting Karen's OK. Nothing else in
`src/`, `tests/` or `tools/`.

## Claims

1. **Exactly two behavioural lines changed, in one file.** `git diff cc058bf4..3feb648f` touches only
   `src/shared/Flags/init.luau`; the only non-comment lines are the two `default` values.
2. **The rows are NOT retired, and no losing branch was deleted.** The dispatch forbids it here and
   rule 7 governs it later. `AIM_REWIND` and `ZONES_FOLLOW_GAIT` still exist in `Flags.DEFAULTS` with
   their `owner`, `born`, `expires` and `why`; `Flags.MAX_FLAGS` is still 21 and no row was removed.
3. **`AIM_REWIND`'s own row made the flip conditional on two things, and both hold at this commit.**
   The row says: dark until `SetNetworkOwner(nil)` has landed on the animal and `305lag.py` reads
   one-signed at both distances. (a) `src/server/Boar/Body.luau` calls `trunk:SetNetworkOwner(nil)`
   in `attachVisual` after the weld loop that reverts ownership to AUTO, and `Body.create` calls
   `part:SetNetworkOwner(nil)` as well — both `grep SetNetworkOwner src/`. (b) `ESCALATE.md`'s table
   records `+0.180 s, client in the PAST, residual 0.011 studs` from `<runs-dir>/305lag.py`, against
   a moving client-owned control of the opposite sign. Verify by reading both.
4. **The defaults are live ON with no override, read from the DEV place, not assumed.**
   `python tools/flags.py --place dev` prints `AIM_REWIND  on  none  on  2026-11-18` and
   `ZONES_FOLLOW_GAIT  on  none  on  2026-11-18` (columns: default, override, effective), and every
   other row reads `none` in the override column.
5. **No spec asserts either flag's default, so no spec needed updating.**
   `grep -rn "AIM_REWIND\|ZONES_FOLLOW_GAIT" tests/` returns nothing. `tests/server/flags.spec.luau`
   builds its own synthetic rows and otherwise keys off `TIE_UNTIL_DRIVE_END`, which was already
   `true`. This answers the dispatch's "if any spec asserts the old default, say which": none does.
6. **The suite is no worse at this commit than at the merge-base — measured, not asserted.**
   - branch: `[harness] FAIL: 32/34 checks @ 3feb648fa67d359e2303710deba2c432375af714 (clean tree) scope=all`
   - CONTROL at the merge-base: `[harness] FAIL: 32/34 checks @ cc058bf49f6072553df07d7e33b282ca1ec72336 (clean tree) scope=all`
   Same count, and the same single failure in both: `rifle_client.spec:747 Expected value "rifle"
   (string), got "shotgun" (string) instead` — the viewmodel never drew the rifle inside the spec's
   own 60-frame wait. 3 runs out of 3. It is NOT the flake the dispatch names
   (`weapon_shot.spec.luau:1490`), and nothing the two flipped flags reach writes the drawn weapon
   (`AIM_REWIND` is read in `src/server/Weapon/init.luau`, `ZONES_FOLLOW_GAIT` in
   `src/server/Boar/init.luau`; both are server-side).
7. **`test2` is N/A, answered by the tool and not by eye.** `agents.needs_two_player` returns `[]`
   for `src/shared/Flags/init.luau`; `TWO_PLAYER_PATHS` contains no `src/shared/Flags/` entry.
8. **CORE-NA.** No input path, weapon geometry, ballistic or animal-behaviour code changed. The
   behaviour now shipped by default is the behaviour Karen played and accepted on 2026-10-30 with
   both flags lit by `ServerStorage` attribute, recorded in `PLAYTEST.md` with that disclosure.

## What could not be verified

- **A `PASS` harness line for the code commit.** It does not exist at this commit or at `main`;
  claim 6 is the evidence, and `ESCALATE.md` is the entry.
- **That `rifle_client.spec:747` is a flake rather than a real regression on `main`.** It failed 3/3
  including at the merge-base, so "flake" is NOT claimed. Whose defect it is, and whether `main`
  should be fixed before this merges, is the Director's call.
- **Anything in Karen's Forest Test.** The dispatch forbids touching it; it was not opened, stopped,
  read or written, and `tools/flags.py` was never run against it.
