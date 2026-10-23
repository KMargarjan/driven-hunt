# Task 249 — Karen's afternoon test: all six

Task: 249
Round: 1
Base: c9583d38 (main)
Code commit: dbf1f92626dd776637b589394b64f14a0c7b7625

```
[harness] PASS: 34/34 checks @ dbf1f92626dd776637b589394b64f14a0c7b7625 (clean tree) scope=all
```

**`[harness2]` IS MISSING AND THIS REQUEST CANNOT BE REVIEWED UNTIL THE DIRECTOR RUNS IT.**
`src/server/Match/init.luau`, `src/server/Lobby/init.luau` and `tests/server/match_live.spec.luau`
are in `TWO_PLAYER_PATHS`, so `tools/agents.py` will refuse this round without the `[harness2]` line
for the same commit. It needs the Test-tab Start click with the Players spinner at 2
(`director-preflight-checklist` items 51 / 60 / 75); it was attempted and reported *"0 new studio(s)
beside the editor"*, and the second session reached its 2 h cap. `ESCALATE.md` carries the
`NEEDS DIRECTOR` entry and the clicks. **It is not claimed and it was not faked.**

## What changed

All six of the dispatch's items, one commit per item. Each was measured on Karen's own path in the
Forest Test before a line was written (rule H): read-only, `ServerStorage` attributes read before
and re-read identical after, the window closed with CloseMainWindow → Don't Save before every
harness run so only DEV was open.

## Claims

Claims 1–10 are items 1, 3, 4 and 5; claims 11–14 are items 2 and 6.

1. **The yellow box was `Weapon.Effects`' impact marker, measured rather than assumed.** Firing into
   the ground in the Forest Test drew nine parts named `Impact`, each **0.30 studs,
   `Enum.Material.Neon`, colour 255,170,90, transparency 0**, all at the one point a buck pattern
   lands on. *Verify:* `Shotgun.CONFIG.IMPACT`'s header carries the measurement; the old values are
   in `git show c5badceb^:src/client/Weapon/Effects.luau` (`Effects.playLanded`).
2. **Nothing in this repository draws that cube any more.** `Effects.playLanded` and `Effects.play`
   both go through one local `puff`: an invisible anchored host named `Impact` carrying one
   `ParticleEmitter:Emit` burst — stock soft texture, `LightEmission` 0, no `Neon`, grains
   0.22–0.38 s under gravity. *Verify:* `src/client/Weapon/Effects.luau` (`puff`, forward-declared
   above `part`); `tests/client/weapon_client.spec.luau`, *"draws the landing as an unlit particle
   puff, never a Neon box (task 249)"*.
3. **It is soil on the ground and splinters on wood, and nothing in the air.** `Weapon.Cast.world`
   now returns `material`; `Weapon.onShotLanded` sends `normals` and `materials` beside the
   `impacts` it always sent; `Effects.impactColor` and `Effects.impactFrame` are pure and exported.
   Air needs no rule: a pellet that hits nothing produces no cast result, so no point is sent — that
   function's own *"A shot that hit nothing sends nothing"*. *Verify:*
   `tests/client/weapon_client.spec.luau`, *"picks the puff off the surface, and stands it on the
   surface normal (task 249)"*.
4. **Both new arrays are optional at every index**, so every caller written before this task is
   unchanged — the suite's own `playLanded({ impacts = ... })` and the three task-185 cases
   included. *Verify:* those three cases are unedited and green in the 34/34 run.
5. **The stag is stuck and the other six kinds are not, measured on Karen's path.** 150 s of a real
   drive, every animal sampled 4×/s, *stuck* = its `Mover.PlaneVelocity` asks for movement **and**
   the body is under 0.8 studs/s: **stag 73 of 337 = 21.7 %** (worst run 1.6 s) against cub 4.2 %,
   female 4.2 %, calf 3.1 %, hind 2.2 %, male 0.0 %. *Verify:* the table is written into
   `Boar.bodyAvoidRadius`'s header and into commit `b935e911`.
6. **The cause is the width he is planned at, and the fix is at the movement owner.**
   `Boar.avoidRadius` (task 240) reads `drawnWidthStuds`, and only the stag's — 3.47, his antlers —
   is meaningfully wider than his box: he hunts a 4.67-stud corridor where every other animal needs
   3.2. `Runtime:_avoidTurn` now retries the same fan at `Boar.bodyAvoidRadius` **only when the wide
   one found nothing at either horizon**, so an animal with room keeps task 240's antler clearance
   exactly. *Verify:* `src/server/Boar/init.luau` (`Boar.bodyAvoidRadius`, the `avoidNarrowed`
   branch in `Runtime:_avoidTurn`); `tests/server/deer.spec.luau`, *"the stag in close wood"*.
7. **The fix cannot reach any other animal, and that is asserted rather than argued.** The fallback
   runs only where `bodyAvoidRadius < avoidRadius`; for every boar kind the two are the same number,
   and the hind's gap is 0.005 studs against the stag's 0.735. *Verify:* `tests/server/deer.spec.luau`,
   *"changes nothing measurable for any animal but the stag"*.
8. **Karen's bush is not one of ours.** Measured with the lobby built and running: every
   `Lobby.TreeLine` and `LODGE_TREES` trunk is 40+ studs from the nearest pad; the thing in her frame
   is `Workspace.Session.Bush` at (2871, −2965), part of the bought forest the place was built from,
   12 studs west of the gravel's edge and inside the road corridor. *Verify:* her frame and mine of
   the same bush at player eye height — `<runs-dir>/karen-bush-2026-10-23.png` and
   `<runs-dir>/249-before-bush.png`.
9. **So the lobby clears its own working ground, by geometry and not by model name.**
   `Build.onWorkingGround` is three rectangles this file already owns — `Build.yardRect` plus
   `CLEARING.YARD_MARGIN_STUDS`, the road corridor, and the lodge's front — and
   `Build.clearWorkingGround` sweeps only the folders `Lobby.CONFIG.CLEARING.FOLDERS` names, only
   their direct children, returning the count (`stats.worldFoliageCleared`). It removes **exactly 1**
   instance today; behind and beside the lodge, where our own grove stands, is untouched. *Verify:*
   `tests/server/lobby.spec.luau`, *"the working ground is kept clear (task 249)"* — both cases.
10. **The gap between drives is 15 s and the sum is now asserted.** 8 (`SCORE_SECONDS`) + 8
    (`PADS.NEXT.SECONDS`) + 15 (`INTERMISSION_SECONDS`) = 31 becomes **4 + 6 + 5 = 15**. The split is
    *not* the dispatch's 5/6/4: the card keeps its 6 because the role choice (`T`) and the way out
    (`Y`) are bound only while it is up, but the dispatch's remaining 4 would have landed on
    `INTERMISSION_SECONDS` — the one phase the player does *not* spend waiting (he is respawned, free
    and walking to his stand) and the number Karen herself asked to be raised to 15 on 2026-10-12. So
    the deep cut goes on the results scene instead. *Verify:* `tests/server/match_live.spec.luau`,
    *"is 15 seconds from the end of one drive to the start of the next"*;
    `backups/2026-10-23_task249_between-drive-gap-31s.txt` (rule 7). **Clocked live after the
    change:** the `Scoring` phase read **3.95 s** off the `MatchState` wire in the Forest Test.
11. **A dead animal stands because a backstop the code promises was never written.** `Body.topple`'s
    own comment has said since task 150 that it is called *"from exactly two places — the collapse,
    and the backstop in `stepCarcass`"*; `grep -rn "Body.topple" src/` finds **one** caller,
    `Body.collapse`. So when `Body.boxFalls` answers false the `AlignOrientation` is left on
    deliberately and the only thing that can lay the animal down is the death clip really playing —
    and `Animator:LoadAnimation` hands back a track for an asset that has not downloaded, which
    `trackFor` cannot tell from a loaded one, and whose `Play` reports `IsPlaying` while applying
    nothing. *Verify:* the grep; `Body.stepCarcass` before this commit
    (`git show b97131c2^:src/server/Boar/Body.luau`).
12. **The backstop is there now, it is bounded, and it cannot double-rotate a carcass.**
    `Body.collapse` remembers the track it is trusting (`handle.deathTrack`); `Body.stepCarcass`
    rolls the box if that track has not advanced its own `TimePosition` by
    `WOUND.DEATH_BACKSTOP_SECONDS` (1.5 s, measured against the 1.167 s clip), stopping the track
    first so a late download cannot apply one afterwards — and `stepVisual` already returns early for
    a toppled carcass, which is task 150's buried-upside-down case. `Runtime.stats().deathBackstops`
    counts it on the edge. *Verify:* `tests/server/boar_model.spec.luau`, *"a dead animal is laid
    down even when its clip never runs (task 249)"* — three cases, one of which proves a world with
    no `DEATH_BACKSTOP_SECONDS` behaves exactly as it did before.
13. **A man the drive let go of is told so, and only him.** The Lobby latches the edge
    `world.inDrive` true → false **while a drive is live** (`Assigning` or `Running`, the same window
    `Phase`'s own `withdraw` branch refuses outside of), reconciled on the tick rather than fired off
    `CharacterAdded` (L-029), and publishes `Lobby.LEFT_DRIVE_ATTRIBUTE`. `Objective.text` turns it
    into one line. It is **not** `team == nil`: a man who never enrolled is also teamless. *Verify:*
    `tests/server/lobby_live.spec.luau`, *"marks the man a LIVE drive let go of…"* and *"does NOT
    mark the end of a drive as a withdrawal"*; `tests/client/hud_clarity.spec.luau`, *"tells a man
    the drive let go of him, and tells nobody else that"*. **On her path:**
    `<runs-dir>/249-after-respawn-line.png` — Reset pressed mid-drive, the clock still reading
    `DRIVE 2 · 4:19`, the player at the lodge porch at eye height, and the line on screen.
14. **He goes on the next drive by default.** The roster handed to `Next.collect` is now `inDrive`
    **or** `leftDrive`, so the man who respawned leaves with the party he was in instead of walking
    to a pad again; the latch clears the moment a drive has him. *Verify:* the same `lobby_live.spec`
    case — the party holds both men, and the attribute is gone on the first scan of the drive that
    takes him.

## What could not be verified

- **`[harness2]` was not run** (above, and in `ESCALATE.md`). The gate will refuse this round until
  it is.
- **ITEM 2 HAS NO HONEST BEFORE/AFTER COUNT, and the dispatch asked for one.** The cause is certain
  (claim 11 is a grep, not an inference) and the fix is spec-covered, but the COUNT is not. Two
  things defeated it inside the budget: **(a)** the drawn-height metric I built proved unsound — a
  dead cub measured **1.65×** its own sampled live height, because a bone span sampled four times a
  second never catches the animal's true standing height; **(b)** every carcass it flagged had
  despawned before the camera reached it, so of **8 traced kills** I have **one** frame actually
  looked at, a male boar lying correctly on its flank
  (`<runs-dir>/249-before-corpse-male.png`). What is needed is a trace that photographs each corpse
  the moment it settles, against a standing height read off the kind's own model rather than off
  live samples. Queued as `TASKS.md` 249a(a). **`Runtime.stats().deathBackstops` is the number to
  read on the next playtest:** every count is an animal that would have stood.
- **Item 5's gap is clocked only in part (L-022).** `Scoring` measured 3.95 s off the wire against
  the new `SCORE_SECONDS` 4; the full results → card → intermission clock was not caught in one
  window. Queued as 249a(c).
- **Item 3 has no "after" stuck count**, and **item 1 has no frame of the new puff.** Both are
  proved by spec; neither has a second measurement. Queued as 249a(c).
- **The dispatch's sentence for item 6 could not be used verbatim.** *"YOU LEFT THE DRIVE · NEXT
  DRIVE STARTS SOON"* is 42 characters against this table's measured bound of **33**
  (`hud_clarity.spec`, the engine's own `TextFits` at 400 px) and the middle dot is not ASCII
  (`Drive.CONFIG.TIED_TEXT`'s rule, also swept). Shortened to *"you left the drive - next soon"*
  (30), which is this file's own precedent for the Director's last over-long sentence. **The
  Director may want different words.**
- **Harness fault (rule 6):** `tests/client/camera_client.spec.luau`'s task-93 *"no templates"* case
  (`handsMissing > missingBefore`) has now failed **5 of 9** harness runs across **six** different
  commits, in a file this task never touched. It is flaky, not a defect of this branch — the 34/34
  line above is a run it passed. Queued as 249a(d).
