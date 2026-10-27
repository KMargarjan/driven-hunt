# Task 287: the lobby pad starts a fresh hunt, not the one already running

Task: 287
Round: 2
Base: 5832342d (main)
Code commit: 9d343ffaafd54fc836f33f9d02dfc42bf6ec9e51

```
[harness] PASS: 34/34 checks @ 9d343ffaafd54fc836f33f9d02dfc42bf6ec9e51 (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 9d343ffaafd54fc836f33f9d02dfc42bf6ec9e51 (clean tree)
```

Both at the same commit, clean tree. One-player: server 2408/0/0, client 612/0/0. Two-player:
server 2408/0/0, shooter 612/0/0, driver 606/0/0 (`<runs-dir>/test2-287b1.log`). **The SECOND
`test2` run the dispatch asked for did not happen:** `run-test2.sh` twice reported
`FAIL A 2-player local test appeared within 180 s (0 new studio(s) beside the editor)` -- the Start
click did not land (Studio was in Edit with one instance; I opened and closed nothing). That is an
instrument failure, recorded in `ESCALATE.md`, not a result.

## What changed since round 1

Round 1's three findings are closed, and **the regression round 1's own fix caused is found,
measured and fixed** (the Director: `weapon_shot.spec:476` failed on the branch and passed on main).

* **Finding 1 — the live door was proven by nothing.** Both live doors are driven now, in a NEW
  spec file `tests/server/zz_pad_restart.spec.luau`, and **the branch is the LIVE ROSTER'S, measured
  after the withdrawal** -- so the one-player harness exercises the SOLO door and `test2` exercises
  the MULTI-PLAYER door. Known-bad, solo: with the restart block disabled
  (`if false and Phase.mayRestart(...)`), `[harness] FAIL: 32/34 ... (DIRTY TREE (1 paths)) scope=all`
  — `zz_pad_restart.spec`, `expect(Match.enrol(player)).to.equal(true)`.
* **The two-player refutation of the first cut, and it CONFIRMED the game.** The Director measured
  `[harness2] FAIL: 34/36 @ 187c23cf`, `zz_pad_restart.spec:91`, *"Expected false, got true"*: with
  two players the OTHER man is still a participant, so `Match.enrolRefused` is TRUE -- which is this
  task's own multi-player rule. The spec was wrong, not the game, and that is the pre-fix failure of
  the multi-player branch (L-028). At `247b493b` the branch then ran and asserted, and only its
  lobby reading failed (`scans` 1, not 0: `Lobby.stats()` outlives `lobby_live.spec`'s start/stop),
  which is why the reading is now the PLACE's data row.
* **Finding 2 — the aborted drive was wiped unpaid.** `Economy.payDrive` now runs on the restart
  path, before the dispatch, while the board and the drive number are still drive N's.
* **Finding 3 — the lobby held a second opinion.** `Match.mayRestart` became `Match.enrolRefused`
  (the question the door itself answers) and `Lobby.occupancy` asks only that; `leftDrive` is no
  longer part of the pad decision.
* **The `:476` regression, MEASURED in three runs, not read off the code.** The instrument was a
  `TestKit.note` of what the case handed on:
  - `bb7c8deb`: `task287 handover: team=Shooters mayCarry=true char=none pack=Shotgun phase=Assigning`
    — the restart reloads the character (`enterAssigning` → `placePlayers` → `LoadCharacter`), the
    re-grant lands in the Backpack, `Weapon.Hardware.equip` retries for 2 s, and `weapon_shot`'s
    sight-line case needs a HELD gun: with none, the server has no muzzle and the pellet's cast
    starts at the eye, which is exactly `:476`.
  - `618aa228`: the tool waited for and back in the hand (`char=Shotgun`) — `:476` still FAILED.
  - `df3e726e`: team, phase and the same gun name restored (`heldBefore=Shotgun heldAfter=Shotgun
    phase=Running (was Running)`) — `:476` still FAILED **and** `zz_drive_boundary.spec` broke on its
    own `expect(Match.testSeconds()).to.equal(0)`, because `advanceForTests` is shared state no
    restoration can give back.
  So the conclusion is measured and not patched: **a drive boundary cannot be driven from the middle
  of the suite.** `zz_drive_boundary.spec`'s header already says so for its own case (*"Doing that
  while a client suite is still running would break it ... So this spec runs LAST"*), and the fix is
  that rule applied here — the case moved to a `zz_` file that runs after every weapon and client
  spec and waits for `ClientsFinished` exactly as that file does. `match_live.spec` keeps only the
  read-only reader case.

## Claims

1. **The SOLO door, live** (one-player run): withdraw → `enrolRefused` false → `enrol` true →
   `restarts` +1 → drive +1 → phase `Assigning` → a second `enrol` that restarts nothing. Measured:
   `task287 SOLO branch (nobody else in the drive): drive 2 -> 3, phase Assigning -> Assigning,
   team Drivers -> Drivers, held Horn -> Horn, restarts 0 -> 1, economy true paid 1 -> 2`.
1b. **The MULTI-PLAYER door, live** (`test2`, with a REAL second participant in the roster):
   `enrolRefused` TRUE, `enrol` false, NOT a participant, and the running drive untouched -- drive
   number, phase, `restarts` and `drivesPaid` all unchanged, `rejoinsRefused` +1. Measured
   (`<runs-dir>/test2-287b1.log`): `task287 MULTI-PLAYER branch (still in the drive: Player2):
   refused=true enrolled=false drive 2 (unchanged), phase Assigning, restarts 0 (unchanged),
   rejoinsRefused 0 -> 1, paid 1 (unchanged); ... this place has a lobby = false (world map:v1)`.
   The `DHPadLate` notice and the next-party enrolment are the LOBBY's and this place has no lobby
   row -- asserted as a reading in the case, and owned by `lobby_live.spec` (claims 8 and 9).
2. **It cannot disturb what runs after it:** the `zz_` prefix puts it last of all spec files, and it
   waits for `ClientsFinished` before touching the drive. Verify: the PASS run's 34/34 with
   `weapon_shot` and `zz_drive_boundary` green, against the three FAIL runs quoted above.
3. **`Phase.mayRestart` is one pure question asked only inside a drive** —
   `insideDrive and participantCount == 0`. Verify: `match_phase.spec`, *"asks ONE question of the
   roster"*.
4. **Solo: a NEW drive number, a full clock, the SAME role.** `Phase.step`'s `restart` branch →
   `enterAssigning`. Verify: `match_phase.spec`, *"gives the solo man a NEW drive number..."* — it
   asserts the KNOWN-BAD first (a `join` keeps the old number and a part-spent clock).
5. **Multi-player: the running drive is not joined and nobody is enrolled**, with a REAL second
   participant in the live roster. Verify: `match_phase.spec`, *"refuses the restart while another
   man is still in the drive"*.
6. **Exactly one fresh drive per pad step** — his own step twice, a second barred man's step in the
   same tick, then that man's ordinary `join`. Verify: `match_phase.spec`, *"gives exactly ONE fresh
   drive however many times a pad is stepped on"*, and *"restarts from `Assigning` too"*.
7. **The aborted drive is paid, and it is MEASURED live.** `Match.enrol`'s restart block calls
   `world.economy.payDrive` before the dispatch. `zz_pad_restart.spec` reads it across the restart
   with `zz_drive_boundary.spec`'s own flag-conditional shape: in the PASS run
   `economy true paid 1 -> 2`, `duplicatePayouts` 0, `lastPaidDrive` = the ABANDONED drive. Known-bad:
   with the call disabled, `[harness] FAIL: 32/34 ... (DIRTY TREE (1 paths)) scope=all` --
   `zz_pad_restart.spec:112`, *"Expected 2, got 1"*.
8. **The lobby asks the drive and nothing else.** `Lobby.occupancy` → `padRefused` →
   `world.enrolRefused`, wired in `ForestTestBoot`. Verify: `tests/server/lobby_live.spec.luau`,
   *"hands the man alone in a dead drive back to a pad"* — and, inside it, the second withdrawn man
   whose pad is an ordinary pad the moment the drive's door would take him (finding 3).
9. **With others hunting the pad still refuses him, and says so.** `lobby_live.spec`, *"keeps a man a
   live drive let go of off the pads while others hunt"*: pad `EMPTY`, door refused, nobody enrolled,
   `DHPadLate` true for him and absent for her, followed off the rectangle and back on, both men in
   the next party.
10. **One line on his screen, yielding to anything that says more.** `Objective.CONFIG.TEXT.LobbyLate`
    (27 ASCII chars, in BOTH of `hud_clarity.spec`'s sentence lists now). Verify:
    `hud_clarity.spec`, *"says why the pad did nothing while the hunt is still on"*.

## What could not be verified

* **The SECOND two-player run.** Not made: the Start click did not land, twice
  (`FAIL A 2-player local test appeared within 180 s`). The first one PASSED 36/36 at this commit.
* **On Karen's own screen.** No Forest Test session: the dispatch says the Director checks it there
  after the review.
* The notice wording is the Builder's pick, as the dispatch allows.
