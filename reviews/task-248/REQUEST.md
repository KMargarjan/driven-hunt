# Task 248 -- Karen's noon test: respawn, ammo prompts, the semi-auto reload sound, no shooting at people

Task: 248
Round: 2
Base: `1b87143c` (main, PR #227 merged)
Code commit: `885274e3b71f7a274d311c50f44adeb7436e07dd`

```
[harness]  PASS: 34/34 checks @ 885274e3b71f7a274d311c50f44adeb7436e07dd (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 885274e3b71f7a274d311c50f44adeb7436e07dd (clean tree)
```

KAREN, 2026-10-23: *"we have a bug / when I respawn I am in lobby with weapons but I can't go to next
hunt / so when I respown hunt should over then I can enter to next games / and when magazine is empty
we need to show reload R letter higlight / also if no rounds at all tell no ammo / ... / I still can
shoot towards hunters and beaters / when reloading semiauto we need sound"*.

## Round 1's two findings

**1. `Rail.setNeeded`'s "off" direction was not edge-triggered. FIXED AT ITS CAUSE, and the Reviewer
was exactly right.** It stored `on or nil`, so a repeated `false` could never match its own guard
(`nil == false` is false) -- and `Hud.renderCorner` calls it every frame on both of its paths. Every
client was creating one Tween per frame on the RELOAD button and repainting it out of its own hover
and pressed states, for the whole session. The boolean is stored as a boolean and the guard compares
booleans; the comment that claimed it was edge-triggered is now true. Verify:
`Rail.setNeeded` in `src/client/Hud/Rail.luau`.

**2. No frame of the HUD surfaces. PARTLY FIXED: two of the three are now in one frame, and the
third is still missing and is named below.** `<runs-dir>/248-notsafe-and-railR.png` (also
`.screenshots/20261023T135424Z-248dev-notsafe.png`), DEV, a real refusal on the player's own screen
at eye height, LOOKED AT:
* **the centre line is drawn** -- `NOT SAFE` over `SOMEBODY IS IN YOUR LINE`, on a field slate under
  the reticle, clear of the aim point;
* **the rail's RELOAD button is LIT** in the accent orange while MAP, REPORT and AMMO are the ghost
  slate beside it -- the gun in that frame is empty with 12 in the pocket, which is exactly the state
  the highlight is for;
* and the ammo chip is bottom-right with its pips and `12 SLUG`.
The **`NO AMMO` chip is still not photographed** -- see *What I could NOT verify*.

The three non-blocking notes about comments that said the opposite of the code are fixed in the same
commit (the lock's 12 -> 6, `BESIDE_STUDS` 5 -> 10 and what it now proves, and `Hud.flashFor` ->
`Hud.calloutFor` in two citations). The other three notes are queued in `TASKS.md` under 248a.

## What changed

**1. A respawn ends your hunt.** `Phase`'s new `withdraw` event is `dismiss` for one man: his roster
row and his assignment go, his team is handed back, his gun is re-asked for, nothing holds him, there
is no feed line and his board row stands. The trigger is a RECONCILIATION (`respawnSweep`, once a
tick beside `Body.floorStep`) over one fact -- *the character he is in is not the character the drive
gave him* -- so it is true however he got there. `Body.place` now reports the character it produced
and counts its placements in flight (`Body.isPlacing`), which is the one fact that tells the drive's
own `LoadCharacter` apart from the player's. Only in a world with a lobby; the DEV arena is untouched.

**2. The ammo prompts.** `Shotgun.ammoNeed` is one definition of OK / RELOAD / EMPTY read by both
sides: the server publishes `NO AMMO` from it on a trigger pull that found nothing anywhere, and the
Hud lights the rail's R, prints the chip and draws a centre line from it. The centre line carries
exactly two refusals -- `NOT SAFE` and `NO AMMO` (plus `BUY AT THE LODGE` where a lodge sells them).

**3. The semi-auto's reload is heard.** It was never silent -- it was inaudible, MEASURED at
**Volume 0.35** in Karen's own client against this gun's shot at 1.6 and ambience at 3.00. A voice
may now state its own `gain`; nil is 1 and every other voice in the game is bit for bit what it was.

**4. The safety lock.** `Rules.unsafeLine` is the sixth rule of the shape Karen has asked for since
task 171 -- the trigger does nothing and nothing is taken away. The geometry is `Match.Penalty.judge`,
the game's one definition of *"the shot passed close to a person"*, asked again at the lock's own
radius over EVERY person in the world (`Match.peoplePositions`): human or bot, hunter or beater.

## Claims

1. **A respawn mid-drive takes that player out of the drive, disarms him and frees him for the next
   one -- MEASURED ON KAREN'S PATH, BEFORE AND AFTER.** Forest Test, 2026-10-23, one Play session per
   build, the Reset button driven as `Player:LoadCharacter()` (`<runs-dir>/248-reset.luau`) and the
   state read as INSTANCE facts (`248-state.luau`):
   * BEFORE (`src/server/` checked out at `1b87143c`):
     `team=Shooters held=[Shotgun] respawnAt=nil` -- her bug, both halves.
   * AFTER (this branch): `team=nil held=[] respawnAt=LodgeSpawn char=2853,153,-2933` (the lodge).
   Verify: `Match.withdraw` / `respawnSweep` / `Match.withdrawOnRespawn` in `src/server/Match/init.luau`,
   the `withdraw` branch in `Phase.step`, and `match_phase.spec` ("a respawn takes one player out of
   the drive").
2. **The drive's own placement is not a respawn, and that is what makes the rule safe.**
   `Body.place` bumps `placing[userId]` before `LoadCharacter` and clears it in `finish` (which the
   `PLACE_TIMEOUT` also calls), and tells the owner the character it produced before anything that
   can yield. Without the `placing` clause every placed player would be withdrawn at the moment he
   was placed. Verify: `Match.withdrawOnRespawn`'s case *"says no while one of its OWN placements is
   in flight"*, and the live runs above (several drives started normally and nobody was withdrawn).
3. **The trigger does not fire while the shot line passes within `SAFETY_LOCK_STUDS` of any person,
   and the SERVER is what refuses it.** Proved twice on the wire, with a control either side, by a
   raw `FireRequest:FireServer` -- not the trigger (`<runs-dir>/248-wire.luau`):
   ```
   DEV, slug (range 330):
   1-SKY                       refused=nil         notice=-        live=1   (fired: 2 -> 1)
   2-AT(bot-hunter-1 160 studs) refused=unsafe-line notice=NOT SAFE live=1   (refused: no shell)
   3-PAST(40 studs off)        refused=nil         notice=-        live=0   (fired: 1 -> 0)

   Forest Test, buckshot (range 100):
   2-AT(bot-beater-1 4 studs)  refused=unsafe-line notice=NOT SAFE live=1
   ```
   A bot HUNTER and a bot BEATER, which is Karen's own pair of words. The two-player gate shows it
   inside the drive's specs as well (`refusals seen [... beater-in-line, unsafe-line, unsafe-line
   ...]`, `<runs-dir>/test2-t248a.log`). Verify: `Rules.unsafeLine`, `Rules.ORDER`,
   `Match.lineIsUnsafe`, `Weapon.setSafetyLineProvider`, `match_safety.spec`'s lock block.
4. **A bot counts as a person, and that is what Karen could never see working before.**
   `Penalty.DriverPos.userId` is optional (nil is never equal to the shooter's id, so the
   self-exclusion needs no branch) and `Bots.people` answers for every bot with a body, hunters
   included -- `Bots.beaters` answers only for the ones that WALK, so a rule built on it would have
   left every bot hunter unprotected, which is half of what she reported. BEFORE, same path:
   `atBot(bot-hunter-1 148 studs) refused=nil` -- it fired, and no `unsafe-line` reason existed
   anywhere in the tree. **The RANGE is part of the rule and the Reviewer's note was right to ask for
   it plainly:** a man beyond the ammo's reach is a shot the rule is RIGHT to allow, so the same
   buckshot shot at 148 studs still fires today (range 100). Verify: `match_safety.spec` *"counts a
   BOT, which has no userId at all"* and *"ignores a person behind the muzzle and one past where the
   shot stopped"*, and `Match.peoplePositions`.
5. **The lock's radius is INSIDE the tie's, and that is the decision of this task.** 6 studs against
   12. At an equal radius the tie could never fire again -- the lock's people list is a superset of
   the tie's -- and a rule that silently retires another rule has retired it without saying so.
   The number was settled by the two-player run and not by taste: at 8 the tie proof's own shot
   (`miss 9.3 of 12`) came back `unsafe-line` twice in two identical runs, because the lock measures
   from the MUZZLE down the server's aim ray and the spec measures from the EYE. Verify:
   `Match.CONFIG.SAFETY_LOCK_STUDS`'s own note, `match_safety.spec` *"ships a lock radius INSIDE the
   penalty's"*, and `zz_tie_to_a_tree.spec`'s `BESIDE_STUDS` (5 -> 10, with the reason).
6. **The rail's R is lit while the gun will not fire until he presses it, and goes out when the
   reload starts -- SEEN IN THE FRAME above.** `Hud.ammoChipFor` returns `need` and `reloadHint` off
   `Shotgun.ammoNeed`; `Rail.setNeeded` is a need STATED by the Hud and performed by the rail (the
   `setWeapon` / `setCovered` shape), edge-triggered IN BOTH DIRECTIONS since round 1's finding 1.
   Verify: `hud_style.spec` *"highlights the rail's R..."* and *"lights the rail's RELOAD button..."*.
7. **`NO AMMO` is said in three places and spelled once.** The chip's word, the readout's notice and
   the centre line all come from `Shotgun.NOTICE_NO_AMMO`, published by the server on the
   `barrel-empty` branch when `Shotgun.ammoNeed` says EMPTY -- forced past the publish limiter, with
   `refused` set, so the trigger also makes one dry click where before it was the quietest event in
   the game. Verify: `weapon_state.spec`'s `ammoNeed` block, `hud_style.spec` *"says NO AMMO on the
   chip..."* and *"draws the centre line for exactly two refusals"*.
8. **The semi-auto's reload is audible, and the number comes from a measurement.** `play` multiplies
   by the voice's own `gain`; the row asks for 2.6 at the port (0.91) and 3.0 on the bolt (1.05),
   against this gun's shot at 1.6. Verify: `semiauto_client.spec` *"puts one shell through the port
   LOUD ENOUGH TO HEAR"*, which reads the Volume off the `Sound` the engine was actually handed in
   the real client, and `semiauto.spec`'s voice case (the lever's `load` has no gain, so nothing else
   in the game moves).
9. **Only paperwork follows the code commit.** `git diff --name-only 885274e3..HEAD`.
10. **Both gate runs are green at this commit**, pasted above, and both selftests
    (`tools/agents.py selftest`, `tools/studio_mcp.py selftest`) pass. Said plainly: the FIRST
    one-player run at this commit came back 32/34 with no failing spec case at all (both suites
    `PASS`, 2102 and 564), taken seconds after a Play session had been stopped and a flag override
    cleared; the run pasted above is the next one, unchanged tree, 34/34.

## What I could NOT verify

* **No frame of the `NO AMMO` chip.** The pocket would not empty in either place: nine cycles of
  "fire both barrels, press R" left the reserve at 12 every time and the barrels empty
  (`<runs-dir>/248-drain2.luau`, `reserve trail 12>12>12>12>12>12>12>12>12 | live=0`), which is
  either the per-drive refill (`Weapon.refillForDrive`) topping it back up or the reload itself not
  running from a probe. Either way I could not reach the state, so the chip's word is proved by
  `hud_style.spec` and by `Shotgun.ammoNeed`'s own cases and NOT by a photograph. Queued as 248a.
  **It is also worth the Director's eye**: a gun that answers `need=reload` and a pocket that never
  goes down may be a real defect of its own and is not one this task touched.
* **Nobody here has heard any sound**, as `SemiAuto.CONFIG`'s voice block already says. The gains are
  reasoned off the measured 0.35 against 1.6; Karen's ears decide and each is one line.
* **The 2.60 s semi-auto reload itself is untouched** and still open: task 242 recorded it as the
  slowest in the game (2.60 against the side-by-side's 1.59), queued as 242a, NEEDS KAREN. This task
  changes what a shell sounds like, not how long it takes.
* **`Match.withdraw` is not driven live in the harness.** The DEV world enrols automatically, and a
  spec that withdrew the one real player would break the client suite standing in him (the rule
  `match_safety.spec`'s header already states about revoking a gun mid-session). The live proof is
  the Forest Test run in claim 1.
