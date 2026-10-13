# Task 174 -- THE SIGNALS ARE THE RULES: the start horn opens the drive, the end horn closes it

Task: 174
Round: 1
Base: `e7b4904` (`main`, #157 merged -- tasks 172 and 173)
Code commit: `2ad0cc587bbe179aa71ee4eb85d097ad580e270b`

```
[harness] PASS: 33/33 checks @ 2ad0cc587bbe179aa71ee4eb85d097ad580e270b (clean tree) scope=all
[harness] PASS: 33/33 checks @ 2ad0cc587bbe179aa71ee4eb85d097ad580e270b (clean tree) scope=all
[harness2] <<< THE DIRECTOR'S TWO-PLAYER LINE GOES HERE, for the same commit >>>
```

**`[harness2]` IS NOT RUN AND CANNOT BE BY THIS BUILDER.** `src/server/Match/` and
`tests/server/match_phase.spec.luau` are in `TWO_PLAYER_PATHS`, so `tools/review.ps1 174` refuses to
start without the line, and `test2` needs one human click. `--scope auto` cannot get round it, and
that was CHECKED rather than assumed: `scope_for` on this branch's eleven changed paths answers
`['all']` (`src/server/Bots/` and `src/server/ForestTestBoot.server.luau` are unmapped in
`BLAST_RADIUS`), which is tagged `scope=all` -- full evidence, and therefore still asks for
`[harness2]`. See `ESCALATE.md`, **NEEDS TEST2 174**.

KAREN, 2026-10-13 ~09:35, verbatim: *"also we can't walk or make a horn sound before horn anounce
hunting started for beater / for hunter once hunt over (drive) horn anounce then I can; shoot anymore
/ so implemt thease"*. And ~13:40, choosing between three answers to task 172's measurement: *"Bots
blow less often"*.

## What the Director's two FAILING gates were, and what fixed them (both measured off his own logs)

His `test` and `test2` at `b355b37` failed where my two runs of the same commit passed, and both
were THIS TASK'S hazards -- one in the game's new gate meeting a spec that assumed a drive, one a
bug in my own new spec case. No assertion was weakened and no `src/` file changed.

* **`test` [client] `weapon_client.spec:874` (12 vs 14) and `:925` (2 vs 0): THE CUE LANDED AT
  `+4.1 s`.** His log says `cue at +4.1s`; mine said `cue at +49.3s` for the same commit -- how fast
  a Play client comes up is not this suite's to decide. The DEV drive reaches `Running` ~15 s after
  the player joins and GO 2.18 s later, so the early run replayed both clicks inside `Assigning`,
  which this task's gate refuses. Hence 0 shots, and a pocket of 14 instead of 12: the two slugs went
  back in having never been spent. **The game did what Karen asked for; the spec assumed a drive.**
  **FIXED IN ONE PLACE -- `tests/client/InputReady.luau`**, the single writer of the ready attribute
  the harness replays behind. It now holds that attribute until this client's own snapshot says the
  drive is open, so EVERY replayed click of EVERY spec lands inside one, deterministically. A client
  cannot state the drive for itself (the gate is the SERVER's), which is why this is one place and not
  five specs.
* **`test2` [server] `zz_horn.spec:1616`: A SHARED COOLDOWN TABLE AND A STAMP IN THE FUTURE.**
  `Weapon.Horn` keeps ONE module-level `lastBlast` for the server. My new case blew `bot-beater-2` at
  a hand-picked `t0 = 7000`, and the bot cooldown case further down blows that same key at
  `os.clock()`: in a Studio open for hours `os.clock()` is past 7001.5 and the blast is allowed, in a
  fresh one it is a few hundred, so the REAL cooldown refused it. **Unique key (`bot-beater-174`) and
  an `os.clock()` base**, so the pollution is impossible and a leaked stamp would be harmless anyway.

## ...AND HIS `test2` AT `454d58a`: `zz_tie_to_a_tree.spec:673`, the SERVER's own stand rule

His notes carry the whole thing: *"me 0.0 from the centre"* (the CLIENT) against *"refusals seen
[off-stand x5]"* (the SERVER), and *"probe attempts: #1 answered=off-stand"* -- ONE attempt, taken
while the server had not yet seen him parked. GO is also when `placePlayers` respawns everybody onto
their posts, so the park and the respawn were in flight together.

* **THE PROBE NOW RETRIES WHILE THE SERVER SAYS `off-stand`**, inside the unchanged `PROBE_WINDOW`.
  `off-stand` is not an answer to this case's question -- it is the server saying it has not got him
  there yet. **The wait is on the server's OWN VERDICT**, which is what you asked for and the only
  read that cannot drift from the rule: `Rules.outsideStand` is computed from the SERVER's view of
  his root, and that view is published to no client (the snapshot carries the stand CIRCLE and no
  positions), so asking the gate is asking the gate. A probe aimed at his body can only ever be
  REFUSED, and a refused attempt commits no state and costs no shell -- which is why asking again is
  free. **`:673` is untouched**; it is now asserted of a shot taken from where the server could see
  him, and if the server never agrees inside the window the case FAILS with every attempt in the
  note. The case waits for `probeDone` (the loop's own last line) instead of for the first answer.
* **THE ARC SHOT INHERITS THAT WAIT.** The aim only moves beside the driver on `probeDone`, so the
  click that ties him is taken after the server agreed as well -- one wait, before both shots.
* **THE MISSING NUMBER IS NOW PRINTED:** how many `off-stand` refusals the server's own rule took,
  when it agreed (seconds after the cue), the client's own distance and the stand radius.
* **ONE THING I TRIED AND MEASURED AS WRONG, AND IT IS WHY `477d4d5` IS NOT THE CODE COMMIT.** Making
  `InputReady` also wait a second for the respawned character to settle moved the cue from `+19.4 s`
  to `+20.4 s`; the client suite RUNS WHILE THE REPLAY PLAYS, so that second slid the `aim-hold`
  scenario's right-mouse into `camera_client`'s hand-pose case, whose viewmodel clone the live camera
  re-drew under it -- `camera_client.spec:1488` failed on a `< 1e-3` stud comparison in **both** runs
  at `477d4d5` having passed in both at `9c722c5`. Reverted to waiting on the drive alone; the
  character reading is KEPT and printed (`character=settled` in every note since), which is also the
  evidence that the wait was never what fixed anything.

## What changed

`src/server/Match/Phase.luau` (`Phase.driveOpen`), `src/server/Match/init.luau` (`Match.driveOpen`,
`mayBlowHorn`, `botsMayGo`), `src/server/Weapon/Rules.luau` (rule 4), `src/server/Weapon/init.luau`
(`setDriveOpenProvider`), both composition roots (`MatchBoot.server.luau`,
`ForestTestBoot.server.luau`), `src/server/Bots/init.luau` (one data number), and four specs
(`match_phase`, `weapon_rules`, `zz_horn`, `bots_live`), plus `tests/client/InputReady.luau`,
`tests/client/weapon_client.spec.luau` and `tests/client/zz_tie_to_a_tree.spec.luau` for the two
rounds above. **No client `src/` file at all:** the
refusal reason and its one-line notice already travel on the wire (task 171).

## Claims

1. **ONE SOURCE FOR "IS THE DRIVE OPEN", AND IT IS A PURE PREDICATE.** `Phase.driveOpen(state)` is
   `Running`, past the start fanfare (`Phase.lineHeld`), before the end. Three rules read it and none
   owns a clock. **Verify:** `tests/server/match_phase.spec.luau`, case *"opens the drive at GO and
   shuts it at the end, by the clock and by the line (task 174)"* -- it walks the real machine from
   `Assigning` through the fanfare, GO, both endings and into the next countdown.
2. **`Match.botsMayGo` DELEGATES TO IT** rather than restating its two conditions, so the line that
   walks and the horn that sounds cannot drift. **Verify:** `Match.botsMayGo` in
   `src/server/Match/init.luau` is one `return`; `bots_live.spec`'s *"is held through the START
   FANFARE too"* is unchanged and still passes, and the same case now holds the line over **80 s of
   handed-in clock** (past the new 60 s window) with 0 walking and 0 blasts.
3. **A BEATER BLOWS NOTHING BEFORE GO -- PLAYER AND BOT, THROUGH ONE DOOR.** `Match.mayBlowHorn(key)`
   is now `Match.driveOpen() and not Match.beaterThrough(key)`, and `Weapon.Horn.blowTool` is the
   single door a player's click, `Bots.blowFor` and a spec all come through. **Verify:**
   `zz_horn.spec`, *"refuses a blast before GO, for a player and for a bot, and takes nothing
   (task 174)"*.
4. **NOTHING IS TAKEN BY A REFUSED BLAST**: the horn stays in his hand, the Grip is not at his mouth,
   no cooldown is started and no `Blown` is published -- so no animal moves, and the click he makes
   the instant the fanfare ends is not also serving a penalty for the one he made during it.
   **Verify:** the same case (`refusedThrough` +2, `#heard == 0`, `tool.Grip == CONFIG.GRIP`, then
   both blasts succeed at the SAME instant once the drive opens).
5. **TASK 168'S RULE IS KEPT AND IS A DIFFERENT QUESTION**: the drive's window is about the DRIVE,
   `beaterThrough` is about the MAN. **Verify:** `zz_horn.spec`, *"asks the DRIVE whether a horn may
   sound at all, and it is two facts (task 174)"*, read off the live drive -- its note from the run:
   `zz_horn: the live drive is shut, so mayBlowHorn(152015)=false (task 174)`.
6. **A HUNTER CANNOT SHOOT ONCE THE DRIVE IS OVER.** `Weapon.Rules.REASON.DRIVE_OVER` /
   `"drive-over"`, notice `"THE DRIVE IS OVER"`, refused **from the drive's end** -- the signal's
   START, because the signal announces a drive that is already over -- through the results scene
   until the next drive's GO, and for BOTH endings (the clock, and the last beater crossing the
   line), because both land in `Scoring`. **Verify:** `weapon_rules.spec`, *"refuses every shot while
   the drive is shut, and says nothing when nothing said (task 174)"*, and claim 1's case for the two
   endings.
7. **IT IS FIRST IN `Rules.ORDER`**: a fact about the drive outranks every fact about the shooter,
   because it is the one thing he cannot fix by moving or by aiming elsewhere. **Verify:**
   `weapon_rules.spec`, *"asks the four rules in one declared order, and names the winner"* -- all
   four true at once answers `drive-over`, and with the drive OPEN the old three answer exactly as
   they did before.
8. **THE REAL HANDLER REFUSES AND SPENDS NOTHING**, measured on a real player's loaded gun in the DEV
   place. **Verify:** `weapon_rules.spec`'s live case and its note from both runs:
   `weapon_rules: Alhamdulilah824 refused=beater-in-line driveShut=drive-over fired=nil; shots +0/+1,
   refused +1/+2; barrels Live/Live -> Live/Live -> Spent/Live`. That live case now states its own
   drive (the fifth seam, restored to `Match.driveOpen` in its own last lines): without it the
   control shot would answer `drive-over` whenever the harness's session happened to be in its
   countdown -- which is what the live drive IS during the server suite (claim 5's note).
9. **UNWIRED IS STILL "NO RESTRICTION", ON EVERY GATE.** `Rules.driveClosed` refuses only on an
   explicit `false`; the provider is `pcall`-ed and a throw says nothing rather than silencing every
   gun in the wood. A server with no drive -- every `tests/server/weapon_*.spec.luau`, a bare DEV
   place -- fires exactly as it did. **Verify:** `Rules.driveClosed(nil) == false` and
   `Rules.refuse({}) == nil` in `weapon_rules.spec`; `askDriveOpen` in `src/server/Weapon/init.luau`.
10. **BOTS BLOW LESS OFTEN: `HORN.EVERY_SECONDS` 18-35 s -> 45-60 s** (data, Karen's choice; the
    reason and the arithmetic are in the `Bots.CONFIG` comment). **Verify:** `bots_live.spec` pins
    `min >= 45` beside the existing `min > COOLDOWN`; and the live Forest Test smoke of **90 s**
    logged **6** bot blasts (`[ForestTest] horn blown at ...`), where four beaters at 18-35 s would
    have been ~13.

11. **NO REPLAYED CLICK DEPENDS ON THE AMBIENT PHASE ANY MORE, and it is measured in the note.**
    `InputReady` waits (up to 45 s), prints the drive it waited for, and gives up loudly rather than
    hanging the attribute -- replaying into a shut drive would then fail the firing specs with that
    line beside them, which is the honest failure of the two. **Verify:** `InputReady.driveOpen` /
    `waitForOpenDrive` / `drivePrint` in `tests/client/InputReady.luau`, and `weapon_client`'s note
    from the two runs below -- `cue at +19.4s with the drive phase=Running hold=0.0 open=true` and
    `cue at +19.3s with the drive phase=Running hold=0.0 open=true`, where the same spec cued at
    `+4.1 s` and `+49.3 s` before it. It reads `Match.phase` and `Match.holdSecondsLeft`, the two
    fields the Hud already reads, and it decides exactly one thing: WHEN THE TEST FIRES. It allows
    nothing and refuses nothing.

12. **THE PROBE'S WAIT IS THE SERVER'S OWN ANSWER, BOUNDED, AND MEASURED.** **Verify:** the retry
    and its comment in `tests/client/zz_tie_to_a_tree.spec.luau` (the `answered == "off-stand"`
    branch), the `probeDone` wait in the same case, and its two new notes. **It is a two-player
    claim** -- with one player the probe is not fired at all (`driver() == nil`), which both of this
    round's runs say in the log -- so the `[harness2]` line is what proves it.

## What this Builder could NOT verify

* **The two-player run.** See the top of this file and `ESCALATE.md`.
* **The readout line on screen.** `"THE DRIVE IS OVER"` is carried by task 171's own notice path
  (server-computed `Rules.noticeFor`, printed by `Hud` beside the glyphs) and no client file changed,
  so what is new is the STRING, not the mechanism. Seeing it live needs a drive to actually end
  (300 s in the Forest Test, 600 s in DEV) and then a trigger pull, which did not fit the time box.
* **A player beater's WALK hold before GO** is task 168's (`Body.hold` / `heldStill`) and is
  untouched here; this task did not re-measure it live. The dispatch asked for the horn, and the hold
  is proved for the BOTS in claim 2.

## Gate

* `[harness] PASS: 33/33 ... @ 2ad0cc5 (clean tree) scope=all` -- **twice**, both with **DEV alone,
  one Studio connected** (cue `+19.3 s` / `+19.4 s`, `open=true character=settled`) (the Director's own condition, the Forest Test closed), logs kept. Server
  1241 passed / 0 failed, client 302 / 0.
* The failures this round fixed are above. Two earlier FAILs are on the record and both were this
  task's: 31/33 at `c9a6a3c` (`END_ON_BEATERS_CROSS` is off by default, so the line's ending did not
  fire -- fixed in `9cd2b10`), and the Director's pair at `b355b37`.
* `SMOKE PASS` in the Forest Test, 90 s: gun in hand at 15 s and at 90 s, `stacks=0 errorLines=0`,
  5 waves, worst 1 boar sound at once, 22 boars.
* No research note and no Architect run: no new system and no new owner. This is a fourth rule in
  task 171's own gate (`docs/research/2026-10-13-the-rules.md`) and one new predicate in the machine
  that already owns the drive's phase.
