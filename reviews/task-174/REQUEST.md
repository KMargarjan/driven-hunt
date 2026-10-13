# Task 174 -- THE SIGNALS ARE THE RULES: the start horn opens the drive, the end horn closes it

Task: 174
Round: 1
Base: `e7b4904` (`main`, #157 merged -- tasks 172 and 173)
Code commit: `bfca4fb7689bb449dc3dbb06e785e36153b80c8c`

```
[harness] PASS: 33/33 checks @ bfca4fb7689bb449dc3dbb06e785e36153b80c8c (clean tree) scope=all
[harness] PASS: 33/33 checks @ bfca4fb7689bb449dc3dbb06e785e36153b80c8c (clean tree) scope=all
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

## What changed

`src/server/Match/Phase.luau` (`Phase.driveOpen`), `src/server/Match/init.luau` (`Match.driveOpen`,
`mayBlowHorn`, `botsMayGo`), `src/server/Weapon/Rules.luau` (rule 4), `src/server/Weapon/init.luau`
(`setDriveOpenProvider`), both composition roots (`MatchBoot.server.luau`,
`ForestTestBoot.server.luau`), `src/server/Bots/init.luau` (one data number), and four specs
(`match_phase`, `weapon_rules`, `zz_horn`, `bots_live`). No client file: the refusal reason and its
one-line notice already travel on the wire (task 171).

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

* `[harness] PASS: 33/33 ... @ bfca4fb (clean tree) scope=all` -- **twice** (logs in the scratchpad).
  An earlier run FAILED 31/33 at `c9a6a3c` on exactly one case, this task's own
  (`END_ON_BEATERS_CROSS` is off by default, so the line's ending did not fire); fixed in `9cd2b10`.
* `SMOKE PASS` in the Forest Test, 90 s: gun in hand at 15 s and at 90 s, `stacks=0 errorLines=0`,
  5 waves, worst 1 boar sound at once, 22 boars.
* No research note and no Architect run: no new system and no new owner. This is a fourth rule in
  task 171's own gate (`docs/research/2026-10-13-the-rules.md`) and one new predicate in the machine
  that already owns the drive's phase.
