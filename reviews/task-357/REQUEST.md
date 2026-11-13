# Task 357 -- the 1.4 s server frame at the lobby join

Task: 357
Round: 2
Base: `690265d8` (origin/main)
Code commit: `4f3a0da2b90aa4febe66b8f75ab2bff96b927802`

```
[harness] PASS: 34/34 checks @ 4f3a0da2b90aa4febe66b8f75ab2bff96b927802 (clean tree) scope=all
```

**The known flake, captured before re-running** (`<runs-dir>/357-flake.txt`). The run before that
one failed `ServerStorage.Tests.weapon_shot.spec:1890` -- named in the dispatch's own flake list,
and no weapon file is in this diff:

```
[harness] FAIL: 30/34 checks @ 4f3a0da2b90aa4febe66b8f75ab2bff96b927802 (clean tree) scope=all
[tests:server] FAIL: 2979 passed, 1 failed, 0 skipped, 1 errors, 83 spec files @ weapon_shot.spec:1890
[harness] PASS: 34/34 checks @ 6106812d04dafaf81f96dc1acbea0218a8712e30 (clean tree) scope=all
```

Two different commits, and the same commit twice: the PASS and the FAIL are the same tree, so the
assertion is flaky there and was green at `6106812d` and `fdc04963` on this branch.

`test2`: **N/A.** Nothing in `TWO_PLAYER_PATHS` is touched -- the code in this diff is
`src/server/Lobby/init.luau`, `src/server/ForestTestBoot.server.luau` and
`tests/server/lobby_live.spec.luau`.

## What changed since round 1

**No behaviour, in either round.** Round 2 is the four findings, all four right and all four about
the instrument's own honesty rather than about the finding. `reviews/task-357/MEASUREMENTS.md`
section 7 lists them; `ESCALATE.md`, `docs/research/INDEX.md` and the research note carry the same
corrections.

## Claims

1. **Finding 1 is fixed by striking, not by arguing.** `stats.buildMs` and `profMs.build` read the
   same `began` two lines apart, so the console's `[lobby] built in 83 ms` is one reading printed
   twice. *Verify:* "independent", "different clock", "different span" and "cross-check" are gone
   from MEASUREMENTS section 1, `ESCALATE.md`, `docs/research/INDEX.md` and
   `docs/research/2026-11-13-the-join-frame.md` ("What was rejected"); each now says the
   milliseconds have ONE source, and names what a second mechanism does corroborate -- `frames=0`,
   from `bootSteps`, an integer with no clock in it. The boot's outer bracket is written down as a
   consistency check bounding call overhead at < 0.1 ms, not as an instrument.
2. **Finding 2 is fixed in code, and the fix is visible in the live line.** `lastTookStep` is
   written beside `lastTookMs` only when a handler returns; `luaOn(rank)` prints `?` unless
   `lastTookStep == bootSteps - 1`. *Verify:* `grep -n "lastTookStep\|luaOn" src/server/ForestTestBoot.server.luau`;
   the `R2` reading reads `top3 1666.5@15(lua ?) 890.9@17(lua 0.1) 149.5@932(lua 0.9)` -- rank 1 is
   the frame whose predecessor entered `world.place` on step 1 and had not returned.
3. **Finding 3 is fixed in code, and the fix changed what the line says.** The previous frame's four
   lobby numbers are snapshotted at the top of the handler, before anything can reassign them.
   *Verify:* `prevStepMs, prevStepFrames = lobbyStepMs, lobbyStepFrames` immediately after
   `bootSteps += 1`, and the `hbWorst` format reading `prevStepMs` and not `lobbyStepMs`. The `R2`
   line prints `prev frame's lobby step=0.0/0f`, which is now true because step 14's scan was
   throttled out -- the hazard the finding named, printed honestly instead of accidentally.
4. **Finding 4 is fixed on both halves.** *Verify:* MEASUREMENTS section 1 pastes `DHLobbyBill` as
   one unbroken line with nothing cut, and `report max=%.1f frames=%d` is in the publish format
   (`lobbyReportMaxFrames`), so the `reportLobby` row's `0` has a source.
5. **The finding itself is unchanged and re-measured at round 2's code.** `scan worst=410.8
   frames=14 | ground=0.0/0f/1c build=82.6/0f/1c@step1 place=328.0/14f/1c@step1 rest=0.2`.
   *Verify:* `<runs-dir>/R2-bill.txt`, read at `84b213c3`, which differs from the code commit only
   by `reviews/task-357/RESULT.md`. Five joins now, tabulated in section 1 (13/17/11/14/14 frames).
6. **`Lobby.step` yields, which is why the bucket was wall time.** `stepPlayer` -> `world.place` ->
   `Match.Body.place` -> `player:LoadCharacter()`. *Verify:* the call site and the comment three
   lines above it in `src/server/Lobby/init.luau` (there since task 182); `Body.place` in
   `src/server/Match/Body.luau`; the Roblox page cited in the research note.
7. **The real long frames are the engine's.** Ranks 2 and 3 of a 5,520-frame session are 890.9 ms
   with 0.1 ms of Lua before it and 149.5 ms with 0.9 ms; rank 1 is unknowable and says so.
   *Verify:* the `top3` field in claim 2's line, MEASUREMENTS section 2, and the five-run spread
   written out there.
8. **The instrument is not blind (L-141).** A SPIN of 800 ms at the `place` seam read back
   `1034.4 ms / 7 frames` **and a new 811.4 ms Heartbeat**; a WAIT of 800 ms read back
   `1125.2 ms / 37 frames` **and no new Heartbeat**. *Verify:*
   `backups/2026-11-13_task-357_lobby-place-control.md`, MEASUREMENTS section 5,
   `<runs-dir>/357-CTRLBURN.log` and `357-CTRLWAIT.log`. The control is archived, not shipped:
   `grep -n "DHLobbyBurn\|DHLobbyWait\|burnSpins" src/server/ForestTestBoot.server.luau` answers one
   line, the comment pointing at the backup.
9. **FAIL FIRST, run.** With the depth guard deleted and nothing else changed: `2979 passed, 1
   failed` at `lobby_live.spec:415`. *Verify:* `<runs-dir>/357-failfirst.txt`; MEASUREMENTS
   section 4 also records the attempt before it, where a case of mine failed for a fault of its own.
   Round 2 took the note on the re-entrancy case's toothless `@step0`: its counter starts at **41**,
   so `@step41` can only pass if `atFrame` really carries the frame the bite began on.
10. **Nothing was written to Karen's place, and her build is back.** *Verify:*
    `<runs-dir>/357-attrs-before.txt` vs `357-attrs-after.txt` -- 24 identical rows, the only
    differing line the harness's own "N Studios connected" banner; `357-connect-karen.png` shows
    :34873 connected from `driven-hunt-karen` `690265d8`, Edit.

## What I could NOT verify

- **Whether Karen ever SEES the 1,666.5 ms frame.** It lands in the first fraction of a second of
  the server's life, while her client is also loading. No instrument here can say what she sees, and
  the MicroProfiler -- the tool that would attribute that frame engine-side -- has no scripting API.
  `ESCALATE.md` item 1 asks her.
- **What the engine spends steps 15 and 17 on.** Rank 1's Lua cost is `?` by construction, and ranks
  2 and 3 bound this repository's share at 0.1-0.9 ms without saying whose the rest is.
- **The instrument's own cost.** `DHBootStep avg` read 1.03-1.54 ms across five runs against
  1.19-1.22 ms in task 356's runs of the same place; the run-to-run spread is larger than anything
  this could add (MEASUREMENTS section 6).
- **`smoke.sh` gun-in-hand BEFORE | AFTER.** N/A by reason: no behaviour changed, so there is no
  AFTER.

## Answered learning flags

ANSWERED: L-136 -- `weapon_shot.spec:1890` fired once and is named above with the capture taken
BEFORE the re-run, the re-run at the same commit, and a second commit's PASS beside it. It is in the
dispatch's flake list and no weapon file is in this diff. No claim here rests on it.
ANSWERED: L-127 -- every table is BEFORE-only and says so, with the five runs, their commits and
their files named per row; the control's table is three arms of one instrument.
ANSWERED: L-162 -- the live proof was re-run at round 2's code (`R2` at `84b213c3`, which differs
from the code commit only by `reviews/task-357/RESULT.md`); the four earlier readings are tabulated
beside it, not instead of it.
ANSWERED: L-014 -- no code was ever checked out in `driven-hunt-karen`; the proof route was
`driven-hunt-rev` on :34873, and the FT ends on :34873 from `driven-hunt-karen` `690265d8`, Edit.
ANSWERED: L-101 -- attribute diff EMPTY, 24 rows; the control was set at runtime inside Play and
never in Edit, and `flags.py --place forest clear` was never run.
ANSWERED: L-093 -- the producer (the depth guard) was deleted and the suite run: one failure, at the
case written for it. The frame counter's producer is covered by case 1 (`place=.../7f/1c@step100`)
and the `atFrame` producer by case 2's non-zero counter (`@step41`). The third case is labelled in
writing as a nil-guard that proves only that nil does not error.
ANSWERED: L-028 -- the new cases were shown failing on code without the producer, output pasted in
claim 9 and MEASUREMENTS section 4, including the case that failed for a fault of its own and was
fixed rather than loosened.
