# Task 295 -- the results scene stays up 5 s longer

Task: 295
Round: 1
Base: 5fb54278 (main)
Code commit: 6cbe6542a021a9ec5775f08fafd409d11c9d855e

Karen, 2026-10-27, playing her build: *"before the next round add more 5s after hunt when all
animals there"*. That scene is the Scoring phase and its whole length is
`Match.CONFIG.SCORE_SECONDS`: 4 -> 9. No other phase was cut to pay for it.

```
[harness] PASS: 34/34 checks @ 6cbe6542a021a9ec5775f08fafd409d11c9d855e (clean tree) scope=auto:economy,lobby,match
```

The FULL run also passed at this same commit (34/34 checks, clean tree, scope=all) -- the line is
quoted in the Builder report. `test2` was NOT run: two Studios are connected and the dispatch
reserves that run for the Director (run-test2.sh). NEEDS DIRECTOR before the merge.

ANSWERED: L-107 -- the whole between-drive gap is measured and stated: 9 + 6 + 5 = **20 s** (15
after task 249), asserted in `match_live.spec` and reported to the Director for Karen.

## Claims

1. `Match.CONFIG.SCORE_SECONDS` is 9, was 4. `src/server/Match/init.luau`, the `SCORE_SECONDS`
   row; its comment carries Karen's 2026-10-27 sentence, the date, and the 2026-10-18 *"make 8s
   max"* it supersedes.
2. FAIL FIRST, at main's value: the new case `keeps the results scene up for the whole of the live
   SCORE_SECONDS (task 295)` in `tests/server/match_phase.spec.luau` drives `Phase.step` with
   `config({ SCORE_SECONDS = Match.CONFIG.SCORE_SECONDS })` and asserts end-of-drive + 8.9 s is
   still `Scoring`. With `SCORE_SECONDS = 4` the harness printed:
   `failed [server] match_phase.spec:320 Expected value "Scoring" (string), got "Assigning"
   (string) instead`. It passes at 9. Verify: set the row back to 4 and re-run that spec.
3. Only one writer of the scene's length: `Phase.luau`'s `state.phaseEndsAt = now + config.SCORE_SECONDS`
   is unchanged. `grep -rn "SCORE_SECONDS" src/` shows no second constant.
4. The Hud footer needs no change (dispatch item 4). `Hud.renderScore`'s footer writes
   `secondsLeft` (from the server's `phaseEndsAt`) and latches its bar denominator from the first
   `Scoring` frame -- the comment at `scoreCountdownFrom` says why there is no client copy.
5. The lobby relation, MEASURED before anything moved (dispatch item 2): `CFG.SECONDS >
   Match.CONFIG.SCORE_SECONDS` in `tests/server/lobby_next.spec.luau` is **not** load-bearing, so
   the card stays at 6 and that one assertion is dropped. Why: the card is up exactly while its
   countdown is armed, and `Next.step` step 3 arms it only when nobody is `held` -- the `free`
   edge that ENDS the scene (`src/server/Lobby/init.luau` `stepNextDrive`'s `isHeld` comment). The
   spec's own case `WAITING: the results scene is still up` is that proof: held party, no deadline.
   The two phases cannot overlap, so nothing on the player's path reads them against each other.
6. The card was NOT lengthened, so Valve's 5..15 clamp (`mp_bonusroundtime`) is untouched:
   `CFG.SECONDS == 6`, and the clamp assertions in the same case still run.
7. `ARM_TIMEOUT_SECONDS > SCORE_SECONDS` IS load-bearing and kept: 12 > 9. The rescue for a party
   nothing freed must land after the scene, never over Karen's score table.
8. The whole gap is one assertion: `match_live.spec`'s case, renamed to `is 20 seconds from the end
   of one drive to the start of the next (task 295)`, pins 9 + 6 + 5 = 20 and keeps `card > walk`.
   The `card > results` half is gone with claim 5. The `<= 8` bound is gone: her new sentence
   supersedes *"8s max"*, and the value is pinned at 9 instead.
9. Rule 7: `backups/2026-10-27_task295_score-seconds-4s.txt` archives the 4 with the lineage
   25 -> 8 -> 4 -> 9 and both of Karen's quotes.
10. Rule G: `python tools/studio_mcp.py selftest` and `python tools/agents.py selftest` both PASS;
    `selene src`, `selene --config tests/selene.toml tests`, `stylua --check src tests` and
    `rojo build` are clean. No new spec file, so no `SCOPE_SPECS` row is needed.

## Could not verify

- `test2` (two players): two Studios are connected. NEEDS DIRECTOR.
- Nothing was played: this is a phase length Karen named in seconds, and the Director checks the
  footer counting 9 down on her place after the merge (one drive, `ftplay.py server lobby-go.luau`).
