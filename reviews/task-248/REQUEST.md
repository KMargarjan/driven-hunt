# Task 248 -- Karen's noon test: respawn, ammo prompts, the semi-auto reload sound, no shooting at people

Task: 248
Round: 1
Base: `1b87143c` (main, PR #227 merged)
Code commit: `57acb1daf024eb3c8e4bc3fc3c69b90c0148f57e`

```
[harness]  PASS: 34/34 checks @ 57acb1daf024eb3c8e4bc3fc3c69b90c0148f57e (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 57acb1daf024eb3c8e4bc3fc3c69b90c0148f57e (clean tree)
```

KAREN, 2026-10-23: *"we have a bug / when I respawn I am in lobby with weapons but I can't go to next
hunt / so when I respown hunt should over then I can enter to next games / and when magazine is empty
we need to show reload R letter higlight / also if no rounds at all tell no ammo / ... / I still can
shoot towards hunters and beaters / when reloading semiauto we need sound"*.

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
Hud lights the rail's R, prints the chip and draws a centre line from it. A new centre line under the
reticle carries exactly two refusals -- `NOT SAFE` and `NO AMMO` (plus `BUY AT THE LODGE` where a
lodge sells them).

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
   * AFTER (this commit):
     `team=nil held=[] respawnAt=LodgeSpawn char=2853,153,-2933` (the lodge).
   Verify: `Match.withdraw` / `respawnSweep` / `Match.withdrawOnRespawn` in `src/server/Match/init.luau`,
   the `withdraw` branch in `Phase.step`, and the cases in `match_phase.spec` ("a respawn takes one
   player out of the drive").
2. **The drive's own placement is not a respawn, and that is what makes the rule safe.**
   `Body.place` bumps `placing[userId]` before `LoadCharacter` and clears it in `finish` (which the
   `PLACE_TIMEOUT` also calls), and tells the owner the character it produced before anything that
   can yield. Without the `placing` clause every placed player would be withdrawn at the moment he
   was placed. Verify: `Match.withdrawOnRespawn`'s case *"says no while one of its OWN placements is
   in flight"*, and the live runs above (three drives started normally and nobody was withdrawn).
3. **The trigger does not fire while the shot line passes within `SAFETY_LOCK_STUDS` of any person,
   and the SERVER is what refuses it.** Proved on the wire, with a control either side, in the Forest
   Test (`248-wire.luau`, a raw `FireRequest:FireServer` -- not the trigger):
   ```
   ammo=Buck range=100 live0=2
   1-SKY                      refused=nil         notice=-         live=1   (fired: 2 -> 1)
   2-AT(bot-beater-1 4 studs) refused=unsafe-line notice=NOT SAFE  live=1   (refused: no shell)
   3-PAST(40 studs off)       refused=nil         notice=-         live=0   (fired: 1 -> 0)
   ```
   The two-player gate shows it firing inside the drive's own specs as well (`refusals seen [...
   beater-in-line, unsafe-line, unsafe-line ...]`, `<runs-dir>/test2-t248a.log`). Verify:
   `Rules.unsafeLine`, `Rules.ORDER`, `Match.lineIsUnsafe`, `Weapon.setSafetyLineProvider`,
   `match_safety.spec`'s lock block.
4. **A bot counts as a person, and that is what Karen could never see working before.**
   `Penalty.DriverPos.userId` is optional (nil is never equal to the shooter's id, so the
   self-exclusion needs no branch) and `Bots.people` answers for every bot with a body, hunters
   included -- `Bots.beaters` answers only for the ones that WALK, so a rule built on it would have
   left every bot hunter unprotected, which is half of what she reported. BEFORE, same path:
   `atBot(bot-hunter-1 148 studs) refused=nil` -- it fired, and no `unsafe-line` reason existed
   anywhere in the tree. Verify: `match_safety.spec` *"counts a BOT, which has no userId at all"*,
   and `Match.peoplePositions`.
5. **The lock's radius is INSIDE the tie's, and that is the decision of this task.** 6 studs against
   12. At an equal radius the tie could never fire again -- the lock's people list is a superset of
   the tie's -- and a rule that silently retires another rule has retired it without saying so.
   The number was settled by the two-player run and not by taste: at 8 the tie proof's own shot
   (`miss 9.3 of 12`) came back `unsafe-line` twice in two identical runs, because the lock measures
   from the MUZZLE down the server's aim ray and the spec measures from the EYE. Verify:
   `Match.CONFIG.SAFETY_LOCK_STUDS`'s own note, `match_safety.spec` *"ships a lock radius INSIDE the
   penalty's"*, and `zz_tie_to_a_tree.spec`'s `BESIDE_STUDS` (5 -> 10, with the reason).
6. **The rail's R is lit while the gun will not fire until he presses it, and goes out when the
   reload starts.** `Hud.ammoChipFor` returns `need` and `reloadHint` off `Shotgun.ammoNeed`;
   `Rail.setNeeded` is a need STATED by the Hud and performed by the rail (the `setWeapon` /
   `setCovered` shape), edge-triggered, with the design system's accent and a gentle pulse. Verify:
   `hud_style.spec` *"highlights the rail's R..."* and *"lights the rail's RELOAD button..."*.
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
9. **Only paperwork follows the code commit.** `git diff --name-only 57acb1da..HEAD`.
10. **Both gate runs are green at this commit**, pasted above, and both selftests
    (`tools/agents.py selftest`, `tools/studio_mcp.py selftest`) pass.

## What I could NOT verify

* **No frame of the three HUD surfaces.** The CLICK PROOF asks for `NOT SAFE` and `NO AMMO` seen in
  frames. I have the wire proof of the refusal (claim 3) and the pure rules under test, but no
  photograph of the centre line, the lit R or the NO AMMO chip: every attempt landed in a Forest Test
  session where the drive had cycled, the gun had been revoked at the end of a drive, or the player
  had been made a BEATER (the one frame I cropped shows a HORN chip, so no ammo chip was drawn at
  all). It is queued rather than claimed.
* **The `NOT SAFE` frame specifically** needs a bot inside the ammo's range at the moment of the pull
  (buckshot reaches 100 studs; the bot HUNTERS stand 152 out), which is a narrow window while the
  beater line walks past.
* **Nobody here has heard any sound**, as `SemiAuto.CONFIG`'s voice block already says. The gains are
  reasoned off the measured 0.35 against 1.6; Karen's ears decide and each is one line.
* **The 2.60 s semi-auto reload itself is untouched** and still open: task 242 recorded it as the
  slowest in the game (2.60 against the side-by-side's 1.59), queued as 242a, NEEDS KAREN. This task
  changes what a shell sounds like, not how long it takes.
* **`Match.withdraw` is not driven live in the harness.** The DEV world enrols automatically, and a
  spec that withdrew the one real player would break the client suite standing in him (the rule
  `match_safety.spec`'s header already states about revoking a gun mid-session). The live proof is
  the Forest Test run in claim 1.
