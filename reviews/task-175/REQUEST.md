# Task 175 - the horn 2.5x, the stand ring always visible, and the measurement that says the horn IS welded

Task: 175
Round: 1
Base: `a4d71e8` (main, #158 merged -- 172, 173 and 174)
Code commit: `2c90fe709f0797fb45c3f3fe353a86b8421cf7f2`

```
[harness] PASS: 33/33 checks @ 2c90fe709f0797fb45c3f3fe353a86b8421cf7f2 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 2c90fe709f0797fb45c3f3fe353a86b8421cf7f2 (clean tree) scope=all
```

`test2` is **N/A**: no path in `TWO_PLAYER_PATHS` is touched. The seven files are
`src/shared/Horn/init.luau`, `src/client/Hud/Objective.luau`, `src/server/ForestTest/init.luau`,
`src/server/ForestTestBoot.server.luau`, `tests/server/zz_horn.spec.luau`,
`tests/server/forest_stand.spec.luau` and `tests/client/hud_clarity.spec.luau`.

## What changed

Karen, 2026-10-13 ~19:05, after playing 172-174, verbatim: *"for shooter - get in your stand (we need
to show where is his stand this circle has to remain all a time / for beater horn has to be doubble
or tripple size now is to small / horn still hangign somewhere it has to be in hand now I can turn
around and horn stand in place somehwere behind"*.

Three items. **Two are built. The third is ESCALATED with a live measurement that says the dispatch's
premise is false**, and that escalation is the honest answer to it rather than a dodge: the horn is
welded, and what she is seeing is that the character does not face the look in first person --
`docs/design/camera.md` 6.4 / Director item A, a character/movement owner that does not exist.

## Claims

1. **The horn is 2.5x bigger, and it is the same horn for players and bots.**
   `Horn.MESH.SIZE_STUDS` 1.25 -> 3.125 studs. Verify: `src/shared/Horn/init.luau`, `Horn.MESH`.
   `ServerStorage.Assets` reads those numbers out of `Horn.MESH` (`HornData` in
   `src/serverstorage/Assets/init.luau`), so there is still one copy. MEASURED live in the Forest
   Test after the change, on the player beater and three bot beaters, all identical:
   `meshSize=(3.1250,1.0842,0.5992) grip=(0.000,0.000,0.250) handle-hand=0.407 anch=false/false
   rgrip=true`.

2. **The scale is still UNIFORM, and the spec proves it against the model's own natural box.**
   (3.125, 1.084244, 0.599201) deviates from 3.125 x the natural aspect by 4.1e-7 and 2.3e-7
   relative, against the existing case's 1e-4 tolerance. Verify: `zz_horn.spec`, *"is scaled
   UNIFORMLY, so the horn in the hand is the horn that was looked at"* -- unchanged, it just now
   passes with the new numbers.

3. **The raise-to-mouth was RE-FITTED BY ARITHMETIC, and the mouthpiece lands where it always did.**
   `CONFIG.GRIP_BLOW`'s Z 0.3 -> 1.2375, which is `0.3 + (3.125 - 1.25) / 2`. The engine welds with
   `Handle.CFrame * Grip == RightHand.CFrame * C0`, so a Handle point `p` lands at
   `C0 * R:Inverse() * (p - T.Position)` when `Grip = T * R`; the mouthpiece is `p = (0, 0, size.X/2)`
   and `p - T.Position` is `(0.42, 0.22, 0.325)` before AND after. Verify three ways:
   (a) the new spec case *"keeps the MOUTHPIECE at the mouth whatever the horn is scaled to"*
   (`zz_horn.spec`) asserts exactly that vector;
   (b) MEASURED against the live rig's own `RightGrip.C0` in the Forest Test -- the mouthpiece lands
   at `(0.3215, 0.2088, 0.3044)` in hand coordinates under the OLD numbers and under the NEW ones,
   `delta=0.000000`;
   (c) MEASURED on three bot beaters actually blowing: `grip=(-0.420,-0.220,1.237)
   mouthLocal=(0.321,0.209,0.304)` in every sample, `mouth-head` settling at 1.95-1.99 studs.

4. **`CONFIG.GRIP` deliberately did NOT scale, and the file says why.** 0.625 (the proportional
   answer) would put the bell 2.19 studs behind the fist, further than an R15 arm is long, so a
   third-person beater would wear it through his own ribs. At 0.25 the fist is near the middle of a
   long object. Verify: the `GRIP` block in `src/shared/Horn/init.luau`, and the existing spec case
   that asserts the grip point is inside the mesh's half-extents -- which still holds (0.25 against a
   1.5625 half-length) and is now also asserted from the other side by claim 3's new case.

5. **Nothing in the horn is anchored and every piece is welded to the Handle, in BOTH builds.**
   New spec case in `zz_horn.spec`: *"anchors nothing and welds every piece to the Handle, in BOTH
   builds (task 175)"* -- it walks the parts horn (nine cylinders) and the mesh horn, asserts
   `Anchored == false` on every BasePart, asserts every piece has a Weld whose `Part0` is the Handle,
   and asserts there was at least one piece so the case cannot pass vacuously.

6. **The stand ring now has ONE writer and it follows ONE answer.**
   `ForestTestBoot.showRing` is the only caller of `Markers.ring` and `Markers.clearRing` in the boot,
   and it reads `ForestTest.standIndexOf` -- new, pure, the pick's index whether locked or open.
   Verify: `src/server/ForestTestBoot.server.luau` (`shownRing`, `standIsClaimed`, `showRing`) and
   `src/server/ForestTest/init.luau` (`ForestTest.standIndexOf`). It also fixes two cases the
   hand-written version could not: an index that CHANGES at the lock (the abandoned stand's ring used
   to stay up for the rest of the drive) and two hunters wrapped onto one stand (one leaving used to
   take the other's circle).

7. **The ring is up for the whole drive, from the intermission's placement onward.** It used to be
   drawn at exactly one moment -- the instant the pick LOCKED, ten seconds into the drive -- so the
   whole of *get to your stand* had no circle. Verify: the `Assigning` branch of the second
   `Match.PhaseChanged` handler (it clears, then waits `PLACEMENT_SETTLE_SECONDS` and opens a pick at
   `nearestStand` of where `Body.place` actually left him), and `openPickFor` (which now draws
   immediately). MEASURED in a live Forest Test session, all three lines in one drive:
   `is walking to stand 5 this intermission (edge ring 12 studs, 20 segments)` /
   `has the pick window open on stand 5 (edge ring 12 studs, shown now)` /
   `took stand 5 (edge ring 12 studs, 20 segments)`.

8. **An OPEN pick still enforces nothing, which is what claim 7 rests on.** `standArea`, `boundary`
   and `hunterStandX` all test `lockedAt` and ignore an open pick on purpose, so the stated reason
   for the `Assigning` clear survives: nobody is held to a stand between drives and no wave is aimed
   at one. Verify: the new case in `forest_stand.spec`, *"names the stand an OPEN pick points at, and
   enforces nothing with it (task 175)"* -- it asserts no fire gate, no wall, no write to the part
   and no change in `hunterStandX`, then that the LOCK still wins and is decided by the position.

9. **ARRIVED now means INSIDE the circle.** `Objective.CONFIG.ARRIVED_IN_STUDS` 24 -> 12 and
   `ARRIVED_OUT_STUDS` 30 -> 16. A hunter 12-24 studs out used to be outside the rule that holds him
   (`withinStand`) and outside the gate on his gun (`Weapon.Rules.outsideStand`) with no chevron, no
   compass takeover and nothing on screen. Verify: `src/client/Hud/Objective.luau` `CONFIG`, and
   `hud_clarity.spec`'s arrival case, which now ties both numbers to
   `ForestTest.PICK.standRadiusStuds` itself rather than to a copy -- the Hud keeps literals because
   it must not require a playtest world's module, and the spec is where they are tied.

10. **The band sits ABOVE the radius, and that is a measurement and not a preference.**
    `ForestTest.boundaryPoint` parks a player who walks out at EXACTLY the radius, so `far == 12`
    must read ARRIVED from both directions or the chevron flickers at the soft wall. Asserted in the
    same case: `Objective.arrived(radius, false)` and `Objective.arrived(radius, true)` are both true,
    which also agrees with `withinStand`'s `<=`.

## What could not be verified, and what I got wrong

* **ITEM 1 IS NOT FIXED AND IS NOT THE HORN.** `ESCALATE.md`, top entry, carries the whole
  measurement. In short: on a real player beater in Play, `RightGrip` (RightHand->Handle) and
  `ModelWeld` (Handle->Model) are both present, nothing in the Tool is anchored, and the mesh held
  **0.407 studs from RightHand in all 100 samples** of a 0.2 s client sampler while the camera swept
  0 -> -90 degrees. What never moved is `rootYaw`. A second run caught the shotgun through a full
  360: `rootYaw` 180.0 in every sample while `camYaw` went all the way round, and the tool's
  camera-space Z went from -3.10 (in front) to +3.76 (behind). The character does not face the look,
  and in first person the body is invisible, so a carried object that is NOT redrawn as a viewmodel
  floats and then leaves the view. The gun is redrawn; the horn is exempted on purpose (task 152).
  `docs/design/camera.md` 6.4 and Director item A already record the fix as needing a
  character/movement owner that does not exist. **Task 172 was not wrong** -- its 0.407 is still
  there.
* **I did not photograph the horn AT THE MOUTH.** I sent a real mouse click into the Play client and
  captured, but the 0.9 s raise had passed or the click did not reach `Tool.Activated`; the frame
  shows the carry pose. The raise is evidenced numerically instead (claim 3b and 3c), and claim 3b is
  the stronger of the two because it compares the old and new numbers against the same live `C0`.
* **The screenshots are first-person-flag-off for the third-person ones.** Karen's game is first
  person, where the local body is hidden, so a third-person picture of a PLAYER beater needs
  `DHFlag_FIRST_PERSON=false`. I set it, took the pictures, and removed it again. The Forest Test's
  attributes are back to exactly what they were when I arrived: `DHFlag_COINS=true`,
  `DHFlag_DRIVE_BOTS=true`, `DHForestStartRole=hunter`, nothing else.
* **`DHFlag_HORN` WAS NOT SET IN THE FOREST TEST WHEN I ARRIVED**, and `HORN` defaults to false, so a
  beater in that place carries nothing at all. I set it to measure and removed it again. Karen cannot
  judge the bigger horn without it.
* **The parts-horn fallback did not scale.** It is a different object (a nine-cylinder brass coil, not
  the ivory mesh) and is only ever on screen for the second or two before `upgradeLook` swaps it, so
  its proportions are left alone and `zz_horn.spec` still asserts them. If a reviewer wants them to
  match, it is three constants and a round.
* **The objective LINE is phase-driven, not arrival-driven**, and that is unchanged by this task:
  during `Running` it says *stay on your stand, boars coming* even to a hunter 50 studs away, while
  the chevron correctly points him back. Worth a sentence from Karen; not fixed here.
* **`/beater` was typed through `TextChannels.RBXGeneral:SendAsync`**, not by a human at a keyboard.
  It goes through `Player.Chatted` and `ForestTest.parseRole` exactly as her typing does -- the
  console's own `[ForestTest] ... is now a beater` line is the evidence -- but it is a tool call and
  is named here as one.

## Screenshots (rule 5, inspected)

`.screenshots/` is git-ignored, so these are on the Builder's machine and this is what they show.

* `20261013T175820Z-t175-player-beater-horn-third-person.png` -- **Karen's one screenshot.** A player
  beater, third person, turned, orange vest and cap, with the big ivory horn clearly **in his right
  hand**, bell forward and clear of the body. It renders in the hand.
* `20261013T175509Z-t175-bot-beater-horn-25x.png` -- the same horn in the player's own first-person
  view: large, filling the bottom-right, and **with no hand under it**, which is the escalation's
  claim in a picture.
* `20261013T175742Z-t175-stand-ring-third-person.png` -- a hunter standing on his stand with the
  orange ring drawn on the ground around him, during `Running`.

## Smoke (standing rule A), Forest Test, 95 s

1. the Tool is in the CHARACTER: `15s HAND:Shotgun(size 4.400 anch=false)`,
   `60s HAND:Shotgun`, and after `/beater` at 65 s, `end HAND:Horn(size 3.125 anch=false)`;
2. **129 console lines, 0 suspicious** -- no "Stack Begin", no "attempt to", no "invalid argument",
   no error line;
3. the changed features ran: all three ring lines in one drive (above), and four
   `[ForestTest] horn blown at ...` lines with boars pushed.
