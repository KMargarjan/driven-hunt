# Task 287: the lobby pad starts a fresh hunt, not the one already running

Task: 287
Round: 1
Base: 5832342d (main)
Code commit: c26c375c9030cf86577a816239fa1d49e0bae050

```
[harness] PASS: 34/34 checks @ c26c375c9030cf86577a816239fa1d49e0bae050 (clean tree) scope=auto:economy,hud,lobby,match
```

**THE FULL RUN WAS ALSO MADE AND ALSO PASSED** at this same commit on a clean tree -- 34/34 checks,
whole suite, `scope=all`, 2407 server and 612 client assertions, 0 failed, 0 errors. Its line is
quoted verbatim in `ESCALATE.md` and in the Builder's report, and deliberately NOT pasted here:
`tools/agents.py` treats the presence of a FULL line as "this is merge evidence" and then requires
the `[harness2]` line, which needs Karen's click. So this round is evidenced by the scoped line, as
CLAUDE.md allows (a `scope=auto:...` line is accepted for a review round and then no `[harness2]`
line is asked for).

`[harness2]` is NOT pasted and the run was NOT made: it needs Karen's click (Test -> Clients and
Servers -> Players: 2 -> Start, twice), and she is not here. **The merge gate still wants the full
pair** -- `ESCALATE.md` carries the NEEDS KAREN entry with the exact clicks, and the dispatch left
that call to the Director.

## What changed

KAREN, 2026-10-24: *"when I respawn and then go to lobby then go back on pad to hunt I been
transferred to same hunt ... with less than min remaining ... I need to be same role and from
beginning"*. Measured by the Playtester (sweep17b item 13): the lit beater pad left him in
`DRIVE 10 - 2:31 - BEATER`, then 2:09. Task 261 already stopped the REJOIN; what was left was a man
alone in a lobby watching the clock of a drive nobody is in, and -- with other men still hunting --
a rectangle that said nothing at all.

Two branches, and they are decided by ONE question about the roster:

* **SOLO** (`Phase.mayRestart`: inside a drive, roster empty) -- the pad step starts a FRESH drive.
  One new pure event, `restart`, into the existing `enterAssigning`: drive number +1, the countdown's
  full clock and then the drive's, the bar lifts by itself (the number moved), the role comes back
  through the stored turn already on the event.
* **MULTI-PLAYER** (anybody else still in the drive) -- unchanged, and no longer silent: he is
  latched (`Lobby.PAD_LATE_ATTRIBUTE`) and his screen says `hunt still on - you go next`
  (`Objective.CONFIG.TEXT.LobbyLate`), while the existing `leftDrive` latch puts him in the next
  drive's party.

## Claims

1. **`Phase.mayRestart` is one pure question and it is asked only inside a drive.**
   `src/server/Match/Phase.luau`, `Phase.mayRestart` -- `insideDrive and participantCount == 0`.
   Verify: `tests/server/match_phase.spec.luau`, *"asks ONE question of the roster"* (Waiting false,
   Running-with-a-man false, roster emptied true, Scoring false).
2. **Solo: a NEW drive number, a full clock, the SAME role.** `Phase.step`'s `restart` branch calls
   `enterAssigning`. Verify: same spec, *"gives the solo man a NEW drive number, a full clock and the
   same role"* -- it asserts the KNOWN-BAD first (a `join` keeps the old number and a part-spent
   clock), then `driveNumber + 1`, `phaseEndsAt == now + INTERMISSION_SECONDS`, then `Running` with
   `phaseEndsAt == now + DRIVE_SECONDS`, `assignment[1]` unchanged, `barredFromRejoin` false.
3. **Multi-player: the running drive is not joined and nobody is enrolled.** Same spec, *"refuses the
   restart while another man is still in the drive"* -- a REAL second participant is in the live
   roster (`state.participants[2]`), and the event changes no drive number, no phase, no clock, no
   roster and emits no effect.
4. **Exactly one fresh drive per pad step, however many steps arrive.** Same spec, *"gives exactly
   ONE fresh drive however many times a pad is stepped on"*: his own step twice (same tick and the
   next), a second barred man's step in the same tick, then that man's ordinary `join`. One
   increment, one clock. The restart itself falsifies `mayRestart`, so this is a property of the
   predicate and not a guard.
5. **A step during `Assigning` restarts once too.** Same spec, *"restarts from `Assigning` too"*.
6. **The lobby asks the DRIVE and holds no second opinion.** `src/server/Lobby/init.luau`,
   `restartOk` -> the OPTIONAL `world.mayRestart`, wired in `src/server/ForestTestBoot.server.luau`
   to `Match.mayRestart` (= `barredFromRejoin and Phase.mayRestart`). A world that injects nothing
   restarts nothing. Verify: `Match.mayRestart` in `src/server/Match/init.luau`, and
   `tests/server/match_live.spec.luau` *"says no pad restarts a drive for a man it never let go of"*.
7. **Alone, the pad is a door again.** `Lobby.occupancy` measures him on the rectangle either way and
   stops dropping him when a restart is possible. Verify: `tests/server/lobby_live.spec.luau`,
   *"hands the man alone in a dead drive back to a pad, and enrols him (task 287)"* -- the pad goes
   `SIZING`, the party departs with no pick, `seen.enrolled` is `{55}`, the latch comes down.
8. **With others hunting, the pad still refuses him -- and says so.** Same spec,
   *"keeps a man a live drive let go of off the pads while others hunt (tasks 261, 287)"*. The second
   participant is REAL (`seen.inDrive[66]`, the set the fake's `mayRestart` answers from, which is
   `Phase.mayRestart`'s own rule and not a constant). It asserts the pad stays `EMPTY`, the door is
   refused, nobody is enrolled, `DHPadLate` is true for him and absent for her, it follows him off
   the rectangle and back on, and both men are in the next drive's party.
9. **One line on his screen, and it yields to anything that says more.**
   `src/client/Hud/Objective.luau` (`LobbyLate`, 27 ASCII characters, above the `left` row) and
   `src/client/Hud/init.luau` (reads `PAD_LATE_ATTRIBUTE`). Verify:
   `tests/client/hud_clarity.spec.luau`, *"says why the pad did nothing while the hunt is still on"*.
10. **Known-bad fails on main.** With `src/` at main and these specs in place:
    `[harness] FAIL: 30/34 checks @ 5832342d47fbc7b2eac7c06f64fdf911889768ac (DIRTY TREE (4 paths) -
    NOT valid evidence) scope=all` -- server 8 failed / 8 errors, client 1 failed
    (`hud_clarity.spec:360`, `LobbyLate` nil).

## What could not be verified

* **The two-player run.** Not made: it needs Karen's click. Claim 3 and claim 8 are the
  multi-player path, proven in the pure machine and against the lobby's fake doors with a real
  second participant -- not with a second client.
* **On Karen's own screen.** No Forest Test session was run: the dispatch says the Director checks it
  there after the review ("PROOF: no OS clicks. Yours: spec + harness").
* The wording of the notice is this Builder's pick, as the dispatch allows; Karen judges it later.
