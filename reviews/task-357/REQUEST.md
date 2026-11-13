# Task 357 -- the 1.4 s server frame at the lobby join

Task: 357
Round: 1
Base: `690265d8` (origin/main)
Code commit: `6106812d04dafaf81f96dc1acbea0218a8712e30`

```
[harness] PASS: 34/34 checks @ 6106812d04dafaf81f96dc1acbea0218a8712e30 (clean tree) scope=all
```

`test2`: **N/A.** Nothing in `TWO_PLAYER_PATHS` is touched -- the diff is `src/server/Lobby/init.luau`,
`src/server/ForestTestBoot.server.luau`, `tests/server/lobby_live.spec.luau`, a research note, the
index, an archived control and this folder.

## What changed

**No behaviour.** An instrument, its two spec cases, a research note, and the measurements that say
the stall the dispatch sent me after is not one. The dispatch: *"If the 1.2-1.4 s is NOT in one
frame, write that in MEASUREMENTS and ESCALATE.md and stop: no fix for a stall that does not
exist."* It is not, so no fix was written. `reviews/task-357/MEASUREMENTS.md`, `ESCALATE.md`.

## Claims

1. **`Lobby.step` yields, so the boot bill's `lobby` bucket was wall time.** `Lobby.step` ->
   `stepPlayer` -> `world.place` -> `ForestTestBoot`'s seam -> `Match.Body.place` ->
   `player:LoadCharacter()`. *Verify:* `grep -n "world.place" src/server/Lobby/init.luau` and the
   comment three lines above it (*"`Body.place` yields on `LoadCharacter`"*, there since task 182);
   `Body.place` in `src/server/Match/Body.luau`; the Roblox page is cited in the research note.
2. **Measured in her place, it is 14 frames, not one.** `ServerStorage.DHLobbyBill` at the code
   commit: `scan worst=386.5 frames=14 | ground=0.0/0f/1c build=69.1/0f/1c@step1
   place=317.1/14f/1c@step1 rest=0.2`. *Verify:* MEASUREMENTS section 1 and
   `<runs-dir>/357-CODEC.log`; four joins at four commits are tabulated there (13/17/11/14 frames).
3. **The lobby's whole ONE-FRAME cost at a join is 69.1 ms, and it is cross-checked.** The `build`
   bite reads 69.1 ms in **0** frames; the console's independent `[lobby] built in 69 ms` comes from
   `stats.buildMs`, a different clock bracketing a different span. *Verify:* the two numbers on the
   same run in `<runs-dir>/357-CODEC.log`; `profMs.build` and `stats.buildMs` in `Lobby.tryBuild`.
4. **The bill adds up, so nothing is hiding in an unbitten gap.** 0.0 + 69.1 + 317.1 + 0.2 = 386.5,
   and `rest` is computed as the remainder rather than measured, so it cannot disagree. *Verify:*
   the `string.format` in `Lobby.step`; the arithmetic on the line in claim 2.
5. **The real long frames are the engine's.** Top three of 5,760: 1,545.7 ms @step15, 827.8 @step17,
   104.0 @step2 -- with `ForestTestBoot`'s whole handler costing 0.0-0.1 ms on the frame before each,
   and every frame from step 18 on under 104.0 ms. *Verify:* `hbTopMs`/`hbTopPrev`/`lastTookMs` in
   `ForestTestBoot`, the `top3` field of the line in claim 2, MEASUREMENTS section 2. `dt` looks
   backward, which the code comment says and which is why `lastTookMs` is the previous handler's.
6. **The instrument is not blind (L-141, a NULL result needs a control).** At the `place` seam, a
   SPIN of 800 ms read back `place=1034.4 ms / 7 frames` **and a new 811.4 ms Heartbeat**; a WAIT of
   800 ms read back `1125.2 ms / 37 frames` **and no new Heartbeat**; both off, `361.1 / 11`.
   *Verify:* `backups/2026-11-13_task-357_lobby-place-control.md` (the code, the runner, the table),
   MEASUREMENTS section 5, `<runs-dir>/357-CTRLBURN.log` and `357-CTRLWAIT.log`.
7. **The control is archived, not shipped.** *Verify:*
   `grep -n "DHLobbyBurn\|DHLobbyWait\|burnSpins" src/server/ForestTestBoot.server.luau` answers one
   line, and it is the comment pointing at the backup.
8. **The bill survives the scan re-entering itself, and that bug was found in HER place, not
   reasoned about.** `BEFORE`/`BEF2` reported `build=0.0/0f/0c` while the console said 75/82 ms --
   the inner scan's reset wiped the suspended outer call's bites (439.1 - 356.7 = 82.5 against
   `built in 82 ms`). *Verify:* `scanDepth` in `Lobby.step` (the `pcall` + re-raise shape task 356
   round 3 gave `releaseInFlight`), MEASUREMENTS section 4, the four-run table in section 1.
9. **FAIL FIRST, run, not argued.** With the depth guard deleted and nothing else changed:
   `[tests:server] FAIL: 2979 passed, 1 failed, 0 skipped, 1 errors, 83 spec files` at
   `ServerStorage.Tests.lobby_live.spec:415`. *Verify:* `<runs-dir>/357-failfirst.txt`; the case is
   *"keeps the outer scan's bites when the yield lets a second scan in"*, which drives the re-entry
   by hand rather than by timing.
10. **Nothing was written to Karen's place, and her build is back.** The control's attributes were
    set at RUNTIME inside Play, never in Edit. *Verify:* `<runs-dir>/357-attrs-before.txt` vs
    `357-attrs-after.txt` -- 24 identical rows, the only differing line being the harness's own
    "N Studios connected" banner; `357-connect-karen.png` shows :34873 connected from
    `driven-hunt-karen` `690265d8`, Edit.

## What I could NOT verify

- **Whether Karen ever SEES the 1,545.7 ms frame.** It lands in the first fraction of a second of
  the server's life, while her client is also loading. No instrument here can say what she sees, and
  the MicroProfiler -- the tool that would attribute that frame engine-side -- has no scripting API.
  `ESCALATE.md` item 1 asks her.
- **The instrument's own cost.** `DHBootStep avg` read 1.03-1.54 ms across four runs against
  1.19-1.22 ms in task 356's runs of the same place; the run-to-run spread is larger than anything
  this could add, so no claim is made that it was measured (MEASUREMENTS section 6).
- **`smoke.sh` gun-in-hand BEFORE | AFTER.** N/A by reason: no behaviour changed, so there is no
  AFTER. The dispatch's bite table has a BEFORE column only for the same reason.

## Answered learning flags

ANSWERED: L-136 -- no spec failed on the gate run (34/34, 2980 server assertions). The two that fired
on the FIRST fail-first attempt, `weapon_shot.spec:1490` and `:1890`, are both named in the
dispatch's own flake list; they did not fire on the second fail-first run or on either gate run, and
no claim here rests on them.
ANSWERED: L-127 -- every table in MEASUREMENTS is BEFORE-only and says so, with the four runs, their
commits and their files named per row; the control's table is three arms of one instrument.
ANSWERED: L-162 -- the live proof was re-run at the code commit's parent content (`CODEC` at
`fdc04963`, whose only difference from `6106812d` is `docs/`, `TASKS.md`, `ESCALATE.md` and
`reviews/`); the readings at the three earlier instrument commits are tabulated beside it, not
instead of it.
ANSWERED: L-014 -- no code was ever checked out in `driven-hunt-karen`; the proof route was
`driven-hunt-rev` on :34873, and the FT ends on :34873 from `driven-hunt-karen` `690265d8`, Edit.
ANSWERED: L-101 -- attribute diff EMPTY, 24 rows, before/after dumps in `<runs-dir>`; the control was
set at runtime inside Play and never in Edit, and `flags.py --place forest clear` was never run.
ANSWERED: L-093 -- the producer (the depth guard) was deleted and the suite run: one failure, at the
case written for it. The frame counter's producer is covered too: the first bill case asserts
`place=.../7f/1c@step100` against a spec-controlled counter.
ANSWERED: L-028 -- the new cases were shown failing on code without the producer, output pasted in
claim 9 and in MEASUREMENTS section 4, including the one case that failed for a fault of its own
(the bill keeps the WORST scan and a fixed 2 ms spin never outranked a 68 ms build) and was fixed.
