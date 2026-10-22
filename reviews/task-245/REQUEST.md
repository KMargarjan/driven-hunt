# Task 245 - the deer's hit and death clips, a fast bolt at a sound, and a leap across the road

Task: 245
Round: 1
Base: 747b8666 (main)
Code commit: e69457740871b12293eb3c17ff0022883ec2a5df

```
[harness] PASS: 34/34 checks @ e69457740871b12293eb3c17ff0022883ec2a5df (clean tree) scope=all
```

`[harness2]`: **N/A.** Nothing this task changed is in `TWO_PLAYER_PATHS` -- the only code files are
`tools/boar_prep.py` and `tools/boar_prep_blender.py`, and the rest is paperwork. The one-player run
is the whole gate (CLAUDE.md, "Run / test").

## What this task found, in one line

**Karen asked three things and two of them were already true.** Items 1 and 2 needed no code: the
hit and death clips play, and a deer already bolts at a shot and at a horn. Item 3's export is done
and the leap itself is stopped at a `NEEDS DIRECTOR` publish, which is where the dispatch said to
stop it.

## What changed in code

Two files, both tools, neither reachable from the game:

* `tools/boar_prep.py` -- `DEER_CLIPS` asks for a twelfth clip, `Jump_Run_IP`; `selftest` gains four
  cases and its count goes 11 -> 12.
* `tools/boar_prep_blender.py` -- three new per-clip measurements: `hoofRiseMetres`,
  `rootRiseMetres` and `hoofFloorMetresPerFrame`.

Everything else is paperwork: `ESCALATE.md` (item 3(b)), `docs/research/2026-10-23-deer-road-leap.md`
plus its INDEX row, and the task's status row in `TASKS.md`.

## Claims

1. **A killed deer plays a death clip and stays down, on Karen's own path.** Measured live in the
   Forest Test on a stag the drive released through `ForestTest.releaseLine` -> `Runtime:spawn`, shot
   by the real `Shotgun.Remotes.FireRequest` with nine buckshot pellets in the chest at 53.3 studs:
   `carcass=true` at t = 0.19 s with `deathLeft` at weight 1.00, the only track by t = 0.30, and held
   at **speed 0** on the last frame (t = 1.15 of 1.21 s). The animation id was read off the live
   track: **90698126097935**, which is `Assets.ROWS`' `deer.anim.death.left`
   (`displayName` `Arm_Deer|Death_L`). Verify: the numbers are in the research note section 2 and in
   the `TASKS.md` row; the id can be checked against `Assets.ROWS`.
2. **A deer hit and not killed plays a flinch clip.** `hitFront` (**114345439062479**, length 0.83 s
   read off the live track) reaches weight 1.00 **40 ms** after the hit, is the only track from
   t = 0.13 to t = 0.27 s, and is then cross-faded into the gait -- which is `Body.flinchWindow`
   shortening the flinch on an animal that is accelerating away, exactly as task 116 built it.
   `hitBack` (**89636256373552**) was seen on a hit from the other side. **Honest limit, stated in
   the note and below:** this one was measured through `Runtime:takeHit` -- the function `BoarBoot`
   calls when the weapon reports a hit -- and not through a pellet. Verify: research note section 2.
3. **A deer that hears a shot bolts, and it always did.** Two drive stags went **4.7 -> 28.4** and
   **11.0 -> 28.6** studs/s inside half a second of the bang, cross-fading `trot` -> `run`
   (113134617381510). 28.3 is `Boar.CONFIG.PACE.RUN_SPEED` 24 x the deer's `runScale` 1.18
   (`Boar.CONFIG.KINDS.stag.wary`). Verify: read `Boar.scaledByWary` and the three deer rows.
4. **A deer that hears a horn bolts harder.** A stag standing `IDLE` at a measured peak of **0.00**
   studs/s, 40 studs from a blast at `Horn.spookStuds` = 357: `runtime:hearHorn(at, radius, true)` --
   `ForestTestBoot`'s own line -- pushed both deer, the stag reached a peak of **44.92** studs/s in
   state `FLEE` and moved from 40 to **89** studs from the blast in three seconds. 44.84 is
   `SPRINT_SPEED` 38 x 1.18.
5. **Why no code was needed for claims 3 and 4, and this is the reviewable part.**
   `Boar.speciesConfig` replaces `BODY_SIZE`, `ZONES` and the `MODEL` overlay and **nothing else**,
   so `SENSE` is the world's table for every species; `Runtime:hearShot` and `Runtime:hearHorn` both
   walk `self._boars`, which is every live animal of every kind. Verify by reading those three
   functions: there is no species test in any of them.
6. **`Jump_Run_IP` is the clip, and the dispatch's alternative name is wrong.** Measured by reading
   the `AnimStack` names straight out of the three `*_anim_IP.fbx`: the stag and the Doe ship **77**
   clips each and the Calf **80**, and the Calf's three extras are exactly `Run_Jump_F_IP`,
   `Run_Jump_L_IP` and `Run_Jump_R_IP`. So `Run_Jump_F_IP` would refuse on a stag run.
   `tools/boar_prep.py selftest` asserts both names, in both directions, and that the boar does not
   have the clip. Verify: `python tools/boar_prep.py selftest` (12 groups, PASS).
7. **The clip does not lift the animal: it lifts its BODY and reaches its LEGS DOWN.** Measured on
   the stag: `root_bone` rise **0.0000 m**, chest (`Spine_01`) +0.267, rump (`Spine_base`) +0.865,
   and a hind hoof **0.465 m = 1.66 studs BELOW** the plane it rests on. Played as it arrives, a
   leaping stag puts its back legs through the road. That is why `tools/boar_prep_blender.py` now
   measures `hoofFloorMetresPerFrame`: the lift that keeps a leaping deer out of the road is the
   clip's own arc inverted, not a curve this project invented. Verify: the new `vertical_rise` and
   `hoof_floor_per_frame`, and research note section 3.
8. **All three exports are written, outside the repo**, by the existing prep path:
   `prep-{stag,hind,calf}-jump/clips/Jump_Run_IP.fbx`, each with its own measured ground speed
   (stag 4.354, hind 10.202, calf 6.747 studs/s) beside its own `Run_F_IP` for comparison. The run
   also re-proved every original input byte-for-byte (18 files hashed). Verify: the three
   `recipe.json` / `measurements.json` in those folders.
9. **Item 3(b) is `ESCALATE.md`, and it asks for ONE publish and not three**, because all three deer
   kinds share `Arm_Deer` exactly as the other eleven clips do (`Assets/init.luau`: *"the eleven
   publishes below are 1x and not 3x"*). The entry carries the file path, the track name, the sha256
   and `Loop = false`.
10. **Rule 1 is satisfied before the leap's code, not after:**
    `docs/research/2026-10-23-deer-road-leap.md` has the six sources with licence and maintenance
    status, what each is good and bad for, the pattern adopted (borrowed from this repo's own
    `deathLiftStuds`, task 232) and the two rejected alternatives with their reasons, and the
    numeric targets. INDEX row added.

## What I could not verify

* **No frame was produced for item 1, and that is a harness fault (rule 6).** `capture` during Play
  came back as a photograph of the sky from three different camera positions, each verified first:
  the client's own `WorldToViewportPoint` answered `onScreen=true` with the animal at screen centre
  (485, 411) and the camera 18 studs away pointing at it. Three captures taken from three verified
  positions have three different sha256s -- so they are fresh frames and not a stale buffer -- and
  none of them contains the animal. The evidence for claims 1 and 2 is therefore the live
  animation-track reads (id, weight, speed, `TimePosition`, `Length`), not a picture.
* **Claim 2 went through `Runtime:takeHit` and not through a pellet.** Three things have to line up
  at once on the drive path and they did not inside this session: the drive has to release a deer
  (they come on waves 2-4 and then not again for the rest of a ~300 s drive), that deer has to cross
  within a shotgun's reach of the stand the drive LOCKED (measured on two waves: **317** and **351**
  studs), and the first shot has to be non-lethal before the animal bolts, because the flinch is
  deliberately cut short on a running animal. The DEATH half (claim 1) did land through a real
  pellet.
* **Two refusals cost this task several rounds and are worth knowing**, because both show up only as
  `impacts=NONE` and an animal that does not react: a shot at a red deer is refused
  `no-licence` / **NO LICENCE** until the 750-coin `licence.reddeer` card is bought, and any shot
  taken away from the player's own stand is refused `off-stand` / **NOT IN YOUR STAND**.
* **One harness run in three FAILED** at this same commit, with the client side reporting 544 passed,
  1 failed, 1 error, and I did not capture which spec -- the failure lines were truncated by my own
  `tail` and the console had been cleared by the time I looked. The two runs after it both passed
  34/34 at the same commit (the line at the top is the third). I am reporting it as a possible flake
  rather than claiming it was one.
* **Item 3(c) is not built.** It cannot be: there is no animation asset id yet.
