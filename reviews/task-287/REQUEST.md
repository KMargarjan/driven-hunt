# Task 287: the lobby pad starts a fresh hunt, not the one already running

Task: 287
Round: 2
Base: 5832342d (main)
Code commit: 55a978fb85b10aac69c5f31b3e52e16dda1a7b66

```
[harness] PASS: 34/34 checks @ 55a978fb85b10aac69c5f31b3e52e16dda1a7b66 (clean tree) scope=all
```

Server 2408 passed / 0 failed / 0 errors; client 612 / 0 / 0. `[harness2]` is NOT pasted and the run
was NOT made: it needs Karen's click, and the Director holds that call (`ESCALATE.md`). The merge
gate still wants the pair.

## What changed since round 1

Round 1's three findings are closed, and **the regression round 1's own fix caused is found,
measured and fixed** (the Director: `weapon_shot.spec:476` failed on the branch and passed on main).

* **Finding 1 — the live door was proven by nothing.** It is driven now, live, in a NEW spec file
  `tests/server/zz_pad_restart.spec.luau`. Known-bad: with the restart block disabled
  (`if false and Phase.mayRestart(...)`), `[harness] FAIL: 32/34 ... (DIRTY TREE (1 paths)) scope=all`
  — `zz_pad_restart.spec:88`, which is `expect(Match.enrol(player)).to.equal(true)`.
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

1. **The live door, true side.** `tests/server/zz_pad_restart.spec.luau`: withdraw → `enrolRefused`
   false → `enrol` true → `restarts` +1 → drive number +1 → phase `Assigning` → a second `enrol`
   that restarts nothing. Measured in the PASS run:
   `task287 live restart: drive 2 -> 3, team Drivers -> Drivers, held Horn -> Horn, restarts 0 -> 1,
   economy true paid 1 -> 2`.
   Verify: the known-bad line above, which is the same case failing with the block disabled.
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

* **The two-player run.** Not made: Karen's click. The multi-player path is proven in the pure
  machine with a real second participant and against the lobby's fake doors — not with a second
  client.
* **On Karen's own screen.** No Forest Test session: the dispatch says the Director checks it there
  after the review.
* The notice wording is the Builder's pick, as the dispatch allows.
