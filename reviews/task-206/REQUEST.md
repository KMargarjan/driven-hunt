# Task 206 — the beater's horn: the arm, and an icon you can read

Task: 206
Round: 1
Base: 21056c2 (main, the Director's branch point)
Code commit: 487e2f4e1e00e42c56ac818798e39806769ccc21

Karen, 2026-10-18 ~14:20, verbatim: *"also horn is broken arm is wrong / and what is this icon ?"*.
Her frames: `<runs-dir>/karen-2026-10-18/shot-5.png` (first person), `shot-6.png` (the HORN chip),
`shot-9.png` (a bot beater seen by a hunter).

```
[harness] PASS: 33/33 checks @ 487e2f4e1e00e42c56ac818798e39806769ccc21 (clean tree) scope=all
```

`test2` is **N/A**: nothing this branch touches is in `TWO_PLAYER_PATHS` (checked against
`agents.py`'s own table for this diff, answer `[]`). The change is the horn's data, the beater's arm
on the server, the bot rig and the HUD — none of them the match, the drive, the tie or the teams.

SMOKE PASS (rule A), Forest Test, 90 s: `gun in hand @15s=1 @90s=1 | stacks=0 errorLines=0 |
waves=10`, player on the ground at 15 s, at the end and after a respawn.

**TWO OF HER THREE ARE FIXED HERE. THE THIRD IS IN `ESCALATE.md` AND IS NOT IN THIS DIFF** — the
first-person hand needs a size decision that is Karen's, and the pose data is untouched
(a diff of `src/shared/Viewmodel/poses.json` against `origin/main` is empty). Claim 10 is that.

## What changed

* `src/shared/Horn/init.luau` — `CARRY_POSE` (the data, with its measurements), `armSequence` (one
  builder; `blowSequence` and the new `carrySequence` call it), `carryAnimationId`, and `registered`
  so the two registrations share one cache shape.
* `src/server/Weapon/Horn.luau` — `trackFor` (one loader for both clips), `Horn.carryArm`, and the
  `Tool.Equipped`/`Unequipped` pair that plays it for a player.
* `src/server/Bots/Rig.luau` + `src/server/Bots/init.luau` — the same clip on a rig: a `carry` slot,
  `Rig.holdHorn`, and `carryPosed` beside `toolPosed`.
* `src/client/Hud/Style.luau` — the `horn` glyph redrawn as five shapes.
* `src/client/Hud/init.luau` — the HORN chip's hand-built icon replaced by `Style.glyph`.
* `tests/server/zz_horn.spec.luau`, `tests/client/hud_style.spec.luau` — the new cases.
* `tests/server/bots_live.spec.luau` — a bot loads five clips now, not four.

## Claims, and how to verify each

1. **THE DEFECT WAS REPRODUCED ON HER PATH BEFORE ANYTHING CHANGED (rule H).** In the Forest Test as
   a beater and as a hunter, 2026-10-18, with `DHForestStartRole` set for the run and restored to her
   `hunter` afterwards (read back: it is `hunter`). `.screenshots/t206-before-fp.png` is her shot-5
   (the horn across the screen with a dark patch of glove on it) and `t206-before-tp2.png` is her
   shot-9 at eye height from 7 studs (the arm straight out, the horn level and away from the body).
   Verify: the two files, and the measurements quoted in claims 2 and 3.

2. **THE THIRD-PERSON CAUSE WAS MEASURED, NOT GUESSED.** On all three bot beaters at once and
   identically: the arm ran **0.99 along the body's own forward** and 0.12 down, the right hand sat
   **1.95 studs in front of the chest** and the Handle **2.30**; the clip doing it was
   `rbxassetid://507768375` (`ToolNoneAnim`) at `Idle`. Verify: the numbers are quoted in
   `Horn.CARRY_POSE`'s header in `src/shared/Horn/init.luau` and in the commit message; the clip is
   `Rig.TOOL_CLIP`, whose own header records task 164 adding it.

3. **AND THE FIX MOVED IT, MEASURED THE SAME WAY, ON BOTS AND ON A PLAYER.** After: the arm runs
   **0.98 down and -0.09 forward**, and the Handle sits **0.07 studs** from the chest instead of
   2.30. On a player's own body, through a whole blast: carry `fwd=0.00 down=0.99`, blast
   `fwd=0.93 down=-0.28` with the `Action` track on top, then back to `fwd=-0.01 down=0.99`. Verify:
   `.screenshots/t206-after-tp.png` and `t206-after-tp2.png` (the same 7-stud eye-height frame, the
   second turned so the horn's side faces the lens) against `t206-before-tp2.png`.

4. **`Tool.Grip` IS NOT WHAT WAS WRONG, AND THAT IS WHY IT IS NOT TOUCHED.** `Grip` is the point of
   the Handle the HAND holds; the hand was out in front, so moving `Grip` would have pulled the horn
   off a fist that was still out in front. Verify: `Horn.CONFIG.GRIP` is unchanged in the diff, and
   the probe lines in claim 3 show `grip=0, 0, 0.25` before and after.

5. **THE CARRY IS ONE CLIP FOR A PLAYER AND A BOT, AND ITS PRIORITY IS THE MECHANISM.** `Rig.CARRY`,
   `Rig.carrySequence` and `Rig.carryAnimationId` are aliases of `src/shared/Horn`'s, exactly as the
   blast's three have been since task 168; the clip plays at `Movement`, above `ToolNoneAnim`'s
   `Idle` and the gait's `Core`, below the blast's `Action`. Verify: `zz_horn.spec`'s *"carries the
   horn at the side, under the blast and over the tool pose (task 206)"*, and the live track list in
   claim 3 (a `@Movement` track at weight 1.00 beside `507768375@Idle` and the gait, and an
   `@Action` one only during a blast).

6. **`Enum.AnimationPriority` IS NOT NUMBERED IN ITS OWN BLENDING ORDER, AND THE HARNESS CAUGHT THE
   ASSERTION THAT ASSUMED IT WAS.** Round 1's `test` failed `zz_horn.spec:664`:
   `carry.Priority.Value > Core.Value` is FALSE, because `Idle` is 0, `Movement` 1, `Action` 2 and
   `Core` — which blends lowest — is 1000. The case names each priority instead. Verify: commit
   `487e2f4`'s message and the case's own header.

7. **`UDim2.fromOffset` TRUNCATES, SO THE GLYPH'S TAPER HAD TO BE MEASURED IN WHOLE PIXELS.** The
   first try's 2.4 / 3.2 / 4.2 px sections came out **2 / 2 / 3 at `px = 14`** — the phone's size,
   where the taper simply was not drawn; `hud_style.spec` drives 14, 16 and 18 for that reason and
   failed on it. 2.6 / 3.6 / 4.8 is the triple that gives three distinct increasing integers at all
   three. Verify: the spec case *"draws the horn as a tapering, curving tube with a bell"*, and
   `Style.glyph`'s `horn` branch.

8. **THE HORN GLYPH READS AS A HORN, AND IT WAS LOOKED AT (rule 5).**
   `.screenshots/t206-chip-before-after.png` is the live chip at Karen's own 955 x 785, before over
   after: a brass lozenge and a dot, against a dark mouthpiece, a tapering tube that curves up, and a
   bright flared bell. `.screenshots/t206-glyph-before-after.png` is the same shape drawn at 14, 16
   and 18 px. Verify: both files.

9. **THERE IS ONE HORN ICON IN THE GAME NOW, NOT TWO.** The chip built its own 18 x 7 bar with a
   9 x 9 bell in `Hud/init.luau` while `Style.GLYPHS` carried a different hand-built horn; the chip
   asks `Style.glyph` now. Verify: a grep for `hornShape` or `hornBell` under `src/` finds nothing,
   and `hud_style.spec`'s *"builds the HORN chip's icon out of Style.glyph (task 206)"*, which also
   asserts the old `Body` frame is gone.

10. **WHAT THIS DOES NOT FIX, SAID PLAINLY (rule 8).** Her shot-5 — the first-person hand — is NOT
    fixed. Measured: the glove covers **119 px** at **3.13-4.07 studs** where the shotgun's covers
    **638 px** at **0.32-0.91**, and the fist's hole axis is **90.0 degrees** off the tube it is
    supposed to be holding. Re-posing cannot fix it (a 3.125-stud horn fits a 70-degree view only
    broadside at 2.52 studs or more; four solved poses were tried, two photographed, all worse), so
    the cause is the horn's SIZE, which is Karen's own instruction to change. `ESCALATE.md` carries
    the arithmetic and two costed options. **The pose data is untouched** — verify: a diff of
    `src/shared/Viewmodel/poses.json` against `origin/main` is empty.

## What could not be verified

* **Whether Karen likes either picture.** The arm is measurably at the side and the glyph is
  measurably a tapering horn with a bell, and both were looked at; whether a 3.125-stud horn hanging
  to 0.33 studs above the sole is the carry she wants is her eye, and it is the same size question
  `ESCALATE.md` asks.
* **A second player.** `test2` was not run (N/A by `TWO_PLAYER_PATHS`), so what a beater's arm looks
  like to a real second human was not seen — only what a bot beater's looks like to the local player,
  which is the same server-played clip on the same kind of body.
* **Phone.** The glyph's 14 px size is proved by spec and by a drawn sheet, not by a phone.
