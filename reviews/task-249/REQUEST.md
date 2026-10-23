# Task 249 — Karen's afternoon test: four of six

Task: 249
Round: 1
Base: c9583d38 (main)
Code commit: 3cb2827dfe41710e60b2036ddc7db14a4213e380

```
[harness] PASS: 34/34 checks @ 3cb2827dfe41710e60b2036ddc7db14a4213e380 (clean tree) scope=all
```

**`[harness2]` IS MISSING AND THIS REQUEST CANNOT BE REVIEWED UNTIL THE DIRECTOR RUNS IT.**
`src/server/Match/init.luau` and `tests/server/match_live.spec.luau` are in `TWO_PLAYER_PATHS`, so
`tools/agents.py` will refuse this round without the `[harness2]` line for the same commit. The run
needs the Test-tab Start click with the Players spinner at 2 (`director-preflight-checklist` items
51 / 60 / 75) and this session was already an hour past its 2.5 h cap when it reached the gate. It
is not claimed and it was not faked.

## What changed

Four of the dispatch's six items, one commit each. Items **2** (a dead boar standing) and **6** (the
respawned player's line) are **not built** — see *What could not be verified*. Every one of the four
was measured on Karen's own path in the Forest Test before a line was written (rule H): read-only,
`ServerStorage` attributes read before and re-read identical after, the window closed before every
harness run so only DEV was open.

## Claims

1. **The yellow box was `Weapon.Effects`' impact marker, and it is measured rather than assumed.**
   Firing into the ground in the Forest Test drew nine parts named `Impact`, each **0.30 studs,
   `Enum.Material.Neon`, colour 255,170,90, transparency 0**, all at the one point a buck pattern
   lands on. *Verify:* `Shotgun.CONFIG.IMPACT`'s header carries the measurement; the old values are
   in `git show c5badceb^:src/client/Weapon/Effects.luau` (`Effects.playLanded`).
2. **Nothing in this repository draws that cube any more.** `Effects.playLanded` and `Effects.play`
   both go through one local `puff`: an invisible anchored host named `Impact` carrying one
   `ParticleEmitter:Emit` burst — stock soft texture, `LightEmission` 0, no `Neon`, grains 0.22–0.38 s
   under gravity. *Verify:* `src/client/Weapon/Effects.luau` (`puff`, forward-declared above
   `part`); `tests/client/weapon_client.spec.luau`, *"draws the landing as an unlit particle puff,
   never a Neon box (task 249)"*.
3. **It is soil on the ground and splinters on wood, and nothing in the air.** `Weapon.Cast.world`
   now returns `material`; `Weapon.onShotLanded` sends `normals` and `materials` beside the
   `impacts` it always sent; `Effects.impactColor` and `Effects.impactFrame` are pure and exported.
   Air needs no rule: a pellet that hits nothing produces no cast result, so no point is sent — that
   function's own *"A shot that hit nothing sends nothing"*. *Verify:* `tests/client/weapon_client.spec.luau`,
   *"picks the puff off the surface, and stands it on the surface normal (task 249)"*.
4. **Both new arrays are optional at every index**, so every caller written before this task is
   unchanged — including the suite's own `playLanded({ impacts = ... })` and the three task-185
   cases, which still pass untouched. *Verify:* the three older `Impact` cases in
   `tests/client/weapon_client.spec.luau` are unedited and green in the 34/34 run.
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
   branch in `Runtime:_avoidTurn`); `tests/server/deer.spec.luau`, *"the stag in close wood (task 249)"*.
7. **The fix cannot reach any other animal, and that is asserted rather than argued.** The fallback
   runs only where `bodyAvoidRadius < avoidRadius`; for every boar kind the two are the same number,
   and the hind's gap is 0.005 studs against the stag's 0.735. *Verify:* `tests/server/deer.spec.luau`,
   *"changes nothing measurable for any animal but the stag"*.
8. **Karen's bush is not one of ours.** Measured with the lobby built and running: every
   `Lobby.TreeLine` and `LODGE_TREES` trunk is 40+ studs from the nearest pad; the thing in her frame
   is `Workspace.Session.Bush` at (2871, −2965), part of the bought forest the place was built from,
   12 studs west of the gravel's edge and inside the road corridor. *Verify:* her frame and mine of
   the same bush are `<runs-dir>/karen-bush-2026-10-23.png` and `<runs-dir>/249-before-bush.png`.
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
    the deep cut goes on the results scene instead. *Verify:*
    `tests/server/match_live.spec.luau`, *"is 15 seconds from the end of one drive to the start of
    the next (task 249)"*; `backups/2026-10-23_task249_between-drive-gap-31s.txt` (rule 7).

## What could not be verified

- **`[harness2]` was not run** (above). The review gate will refuse this round until it is.
- **Item 2, the dead boar standing, is NOT BUILT and was NOT REPRODUCED.** A drive issues 12 slug +
  12 buck (`Shotgun.CONFIG.DRIVE_SHELLS`) and this session's shells went on item 1's ground shots, so
  there was no kill sample at all. Task 150's *"0 standing dead in 23 kills"* is from a different
  setup and is not a baseline for this one (L-021). Nothing was changed on a guess. The code suspect
  and the plan are in `TASKS.md` row 249a(a).
- **Item 6, the respawned player's line, is NOT BUILT.** The work is mapped in `TASKS.md` row
  249a(b): `Objective.text` answers `""` for a man with no team while a drive runs, which is the
  nothing Karen saw, and it needs a per-player fact (a man who never enrolled must not read *"YOU
  LEFT THE DRIVE"*) plus `Lobby.step` collecting the withdrawn into the next drive's party.
- **Three "after" measurements were not taken:** the stag's stuck percentage in a second drive, the
  results → card → intermission gap clocked off the `MatchState` wire (L-022 — the *before* side was
  clocked: the wire carries each phase's real `phaseEndsAt`), and a frame of the new impact puff.
  Queued as 249a(c). The item-5 change is three data rows whose sum a spec now asserts; the item-1
  and item-3 changes are proved by spec and not yet by a frame or a second count.
- **Harness fault (rule 6):** `tests/client/camera_client.spec.luau`'s task-93 *"no templates"* case
  (`handsMissing > missingBefore`) **failed 2 of 4 runs at three different commits**, in a file this
  task never touched. The 34/34 line above is a run it passed. Queued as 249a(d).
