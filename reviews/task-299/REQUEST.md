# Task 299: a pad restart gives a fresh drive, and an abandoned drive pays nobody

Task: 299
Round: 2
Base: a28bafbb (task-287-pad-fresh-hunt head; this branch is stacked on it)
Code commit: 7af2954222e66272c9afe99cd827fd9d373091df

Karen (2026-10-24): *"when I respawn and then go to lobby then go back on pad to hunt I been
transferred to same hunt ... I need to be same role and from beginning"*.

## What changed, against round 1's three findings

1. **The restart goes straight to `Assigning` again, and must never cross `Scoring`**
   (`Phase.step`, the `restart` branch). In the place that HAS pads, `Lobby.onPhase("Scoring")` sets
   `dismissPending` and the next `Lobby.step` dismisses the whole roster, so round 1's results-scene
   detour landed in `Waiting`.
2. **`Match.withdraw` marks his board row `left`** (`board = Score.leave(board, userId)`), which
   `Coins.forDrive` skips — so the drive he abandons pays him no coins and counts him no hunt. The
   faucet is shut at the row, not at a second guard.
3. **The owner's per-drive block is keyed on the drive NUMBER** (`state.driveNumber ~= driveBefore`)
   instead of the `Assigning` phase edge, so the restart arm — which crosses no phase edge — rebuilds
   the board, re-measures the markers and counts the drive like any other.

## Gate lines

```
[harness] PASS: 34/34 checks @ 7af2954222e66272c9afe99cd827fd9d373091df (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 7af2954222e66272c9afe99cd827fd9d373091df (clean tree)
[harness2] PASS: 36/36 checks @ 7af2954222e66272c9afe99cd827fd9d373091df (clean tree)
```
No failure in any of the three runs. One Studio throughout; the Players spinner was photographed
first and read (`driven-hunt-runs/299r2-spinner-zoom.png`: mode **Server**, count **2**).

## Claims

1. **THE LOBBY IS REALLY WIRED, and that is the new case.** `tests/server/lobby_live.spec.luau`,
   *"a pad restart in a world that HAS a lobby (task 299)"*: the real `Phase` machine, every
   transition fed to the real `Lobby.onPhase` exactly as `ForestTestBoot` does, the lobby's
   `dismissAll` seam dispatching the real `dismiss` event, `Lobby.step` called on every step.
   A solo man in a **`Running`** drive withdraws, steps on the pad, and gets `Assigning`,
   `driveNumber + 1`, `phaseEndsAt == at + INTERMISSION_SECONDS`, his own team back, and
   **`dismissals == 0`** after five more scans — then the drive runs for its full length.
2. **The same case proves the lobby is wired and not merely quiet:** the ordinary end of that fresh
   drive reaches `Scoring` and `dismissals` becomes 1.
3. **FAIL FIRST AT `1de1468c`** (round 1's head), new specs on round-1 `src/`:
   `[harness] FAIL: 32/34 checks @ 1de1468cc0bd42b065e54765da6e15b53e714e74 (DIRTY TREE (3 paths) -
   NOT valid evidence) scope=all`, server `2406 passed, 4 failed, 4 errors`:
   `lobby_live.spec:1953 Expected value "Assigning" (string), got "Scoring"` (finding 1),
   `match_phase.spec:2996` and `:3055` (`drive 2` expected, got `1`),
   `zz_pad_restart.spec:129 Expected value "true", got "false"` (the `left` row, finding 2).
4. **LIVE, ON THE REAL ECONOMY AND THE REAL MATCH.** `tests/server/zz_pad_restart.spec.luau` reads
   HIS coins and HIS completed hunts, not just the global counter, across FIVE pad steps. The
   one-player run's own note at the code commit:
   `task287 SOLO branch (nobody else in the drive): drive 2 -> 3, phase Assigning -> Assigning,
   team Drivers -> Drivers, held Horn -> Horn, restarts 0 -> 1, economy true paid 1 -> 1,
   his coins 10 -> 10, his hunts 1 -> 1, drives 2 -> 3 (5 pad steps)`.
5. **Finding 2, live:** the same spec asserts his snapshot row carries `left == true` the moment he
   withdraws, and a FRESH row (`left == false`) once the restart has dealt the new drive.
6. **Finding 3, live:** `Match.stats().drives` moves by exactly one across the restart
   (`drives 2 -> 3` in claim 4's note) although the phase never left `Assigning`, and it does not
   move again over the four further pad steps.
7. **The pure machine is back to one arm** (`match_phase.spec`, restored to its pre-299 cases): a
   restart deals drive+1 with the countdown's full clock and the same role, from `Running` and from
   `Assigning`, once however many pads are stepped on.
8. **One pay-out site remains** (`grep payDrive src/server/Match/init.luau` → the `Scoring` edge
   only) and two `Score.leave` sites (`Match.withdraw`, `Match.forget`).
9. `selene src`, `selene --config tests/selene.toml tests`, `stylua --check src tests`,
   `rojo build`, `python tools/studio_mcp.py selftest`, `python tools/agents.py selftest`: clean.

## What I could not verify

**No frame and no Forest Test session.** This is a phase/economy change with nothing drawn; the proof
is the lobby-wired case and the live counters above. **A drive nobody finished is now never paid at
all** — that is deliberate (nobody is left in it to pay, by `mayRestart`), and it is a behaviour
change against 287's *"his result for this drive stands"*, which the Director's round-2 dispatch
overrides.

## Answered learning flags

- **ANSWERED: L-093** the `Running`-restart arm is ENTERED for real in the new lobby-wired case
  (`expect(state.phase).to.equal("Running")` before the pad step); the `Assigning` arm is entered
  live in `zz_pad_restart.spec`. Both arms, both files, neither asserted only as a count.
- **ANSWERED: L-033** `test2` twice at the code commit, both PASS, one Studio open, spinner read.
- **ANSWERED: L-028** fail-first at `1de1468c` with the four failing lines quoted (claim 3).
- **ANSWERED: L-029** "no extra pay-out" is asserted over five repeated pad steps on the man's OWN
  balance and hunts, plus the global `drivesPaid` and `duplicatePayouts == 0`.
- **ANSWERED: L-030** every `payDrive` and `Score.leave` call site re-grepped after the change
  (claim 8); the comment above the deleted round-1 call went with it in round 1.
- **ANSWERED: L-031** no second guard was added: the pay-out still has exactly one call site, and
  what changed is which ROWS it is given.
- **ANSWERED: ROUTE** the lobby case lives in `tests/server/lobby_live.spec.luau`, the file the
  Reviewer named.
