# Task 299: a pad restart ends the old drive through Scoring -- paid once

Task: 299
Round: 1
Base: a28bafbb (task-287-pad-fresh-hunt head; this branch is stacked on it)
Code commit: df70c86b4b84041e488b2cc9c04c3e96dd9b8d6a

Karen (2026-10-24): *"when I respawn and then go to lobby then go back on pad to hunt I been
transferred to same hunt ... I need to be same role and from beginning"*. 287 gave her the fresh
drive; its round-3 review found the pay-out it added was repeatable. This is that fix.

## What changed

A restart out of `Running` now enters `Scoring` (`Phase.step`, the `restart` branch), so the old
drive ends the way every drive ends: the owner's one `Scoring` edge pays it and runs the per-drive
work, and the loop's own `Scoring` exit deals the fresh drive with the new number and a full clock.
287 round 2's separate `world.economy.payDrive(...)` call in `Match.enrol` is deleted. A restart out
of `Assigning` has nothing to score: it pays nothing and is dealt a fresh drive directly, as before.

## Gate lines

```
[harness] PASS: 34/34 checks @ df70c86b4b84041e488b2cc9c04c3e96dd9b8d6a (clean tree) scope=all
[harness2] PASS: 36/36 checks @ df70c86b4b84041e488b2cc9c04c3e96dd9b8d6a (clean tree)
[harness2] PASS: 36/36 checks @ df70c86b4b84041e488b2cc9c04c3e96dd9b8d6a (clean tree)
```
(the one-player run was made twice, both PASS; `test2` three times -- 299a PASS, 299b FAIL, 299c PASS.)

**THE ONE FAILURE, WITH ITS CONTROL.** `test2` run 299b: `[harness2] FAIL: 34/36 @ df70c86b`,
`failed [driver] map_ui.spec:1057 Expected value to be near 20.000000 (within 8.000000) but got
11.577399`. That assertion measures the map UI's TICK RATE on the second client over 0.6 s. Control
run of the same scope at the merge base: `[harness2] PASS: 36/36 checks @
a28bafbb2e7a6b9ddea7ea35b964235229333819 (clean tree)` -- and the same commit df70c86b passed it
twice (299a, 299c). I am not calling it "the known flake": it is a client frame-rate measurement
with no Match, Phase or Economy call in it, and three of the four runs across two commits passed it.

## Claims

1. **A restart out of `Running` enters `Scoring`.** `src/server/Match/Phase.luau`, the `restart`
   branch of `Phase.step`: `enterScoring` when `next_.phase == "Running"`, `enterAssigning`
   otherwise. `tests/server/match_phase.spec.luau`, *"gives the solo man a NEW drive number"*:
   phase `Scoring`, drive number UNCHANGED, `scene` and `clearBoars` emitted, then the next tick at
   `SCORE_SECONDS` deals drive+1 with the full countdown and the same role.
2. **The 287 round-2 pay-out call is gone.** `grep -n payDrive src/server/Match/init.luau` gives one
   call site, the `Scoring` edge; the justification comment above the old call was rewritten with it
   (Learning Agent L-030).
3. **N pad steps, ONE pay-out.** `match_phase.spec`, *"gives exactly ONE fresh drive however many
   times a pad is stepped on"*: four further `restart` events over two ticks emit nothing and move
   nothing, because he is in the roster and `Scoring` is no drive to restart. The edge the pay-out
   hangs off can be crossed once per drive (L-031: one path, not a second guard).
4. **LIVE, ON THE REAL ECONOMY.** `tests/server/zz_pad_restart.spec.luau` now counts coins and
   `drivesPaid` before and after FIVE pad steps. The one-player run's own note:
   `task287/299 SOLO branch: drive 2 -> 3, phase Assigning -> Assigning, team Drivers -> Drivers,
   held Horn -> Horn, restarts 0 -> 1, economy true paid 1 -> 1 (5 pad steps), coins 10 -> 10,
   lastPaidDrive 1, duplicates 0`.
5. **A restart from `Assigning` pays nothing and still gives a fresh drive.** Claim 4's note is that
   arm, measured: drive 2 -> 3, `drivesPaid` 1 -> 1, coins 10 -> 10. The old head paid here.
   `match_phase.spec`, *"restarts from `Assigning` too"*, asserts no `scene` effect -- no edge, no
   pay-out.
6. **FAIL FIRST AT THE OLD HEAD** (L-028). The new specs against 287's `src/`
   (`git checkout a28bafbb -- src/server/Match/*`): `[harness] FAIL: 32/34 checks @ df70c86b
   (DIRTY TREE (2 paths) - NOT valid evidence) scope=all`, server `2406 passed, 3 failed, 3 errors`.
   Clean tree, both files restored: `34/34`.
7. **The multi-player door is untouched.** Both `test2` PASS runs took it:
   `task287 MULTI-PLAYER branch (still in the drive: Player2): refused=true enrolled=false drive 2
   (unchanged), phase Assigning, restarts 0 (unchanged), rejoinsRefused 0 -> 1, paid 1 (unchanged)`.
8. `selene src`, `selene --config tests/selene.toml tests`, `stylua --check src tests`,
   `rojo build`, `python tools/studio_mcp.py selftest`, `python tools/agents.py selftest`: all clean.

## What I could not verify

**The `Running` arm was not entered LIVE in this run.** `zz_pad_restart.spec` takes whichever phase
the drive is in when it reaches the file, and in all four runs that was `Assigning` -- so the live
proof above is the `Assigning` arm (which is where the faucet was measurable, and it is shut). The
`Running` arm is proven in `match_phase.spec` only, where it is entered for real (Running, withdraw,
restart, phase `Scoring`). No playtest in Karen's place: no Studio session is free before the
deadline.

## Answered learning flags

- **ANSWERED: L-093** both arms get a case that really ENTERS them: the pure spec drives
  Running->restart->Scoring and Assigning->restart->Assigning as separate cases with phase
  assertions, and the live spec branches on the measured phase rather than assuming one.
- **ANSWERED: L-033** `test2` was run twice at the code commit (299a, 299c, both PASS), plus a third
  run (299b) and a control at the merge base; exactly one Studio open throughout, Players spinner
  photographed first (`driven-hunt-runs/299-spinner-zoom.png`: mode Server, count 2).
- **ANSWERED: L-028** the new specs FAIL at 287's head (claim 6) and pass here.
- **ANSWERED: L-029** "exactly one pay-out per drive" is asserted under five repeated pad steps live
  (claim 4) and under overlapping steps by two men in one tick in the pure spec (claim 3).
- **ANSWERED: L-030** both `payDrive` sites were grepped before and after; one remains (the Scoring
  edge) and the comment block above the deleted call was rewritten, not left behind.
- **ANSWERED: L-031** the fix routes every pay-out through the one `Scoring` edge instead of adding
  a second guard beside `Economy.payDrive`'s drive-number one.
