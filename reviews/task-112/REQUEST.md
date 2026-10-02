# Task 112 - shooting: the kick, the flash and the noise

Task: 112
Round: 2
Base: `content-hands-karen-1` (PR #102 was retargeted by the Director)
Code commit: `ca572f7abab976547f27b391d0b8c7eac06d841b`

```
[harness]  PASS: 33/33 checks @ ca572f7abab976547f27b391d0b8c7eac06d841b (clean tree)
[harness2] FAIL: 33/35 checks @ ca572f7abab976547f27b391d0b8c7eac06d841b (clean tree)
```

**THE TWO-PLAYER LINE IS A FAIL AND IT IS NOT THIS TASK'S** -- both failures are in
`tests/client/weapon_client.spec.luau`, which this task does not touch, and the run's own notes say
the shooter was TIED during the drive so his gun was in the backpack by the time the specs ran. It
reproduced on a second run, so it is not a flake any more; `ESCALATE.md` (2026-10-02) has the
evidence and asks the Director to decide. The review cannot run until it is.

`test2` is required: `src/client/Camera/Config.luau`, `init.luau`, `CameraBoot.client.luau` and
`src/client/Weapon/` are all outside `WEAPON_VIEWMODEL_PATHS`.

## Claims (round 2 fixed all four blocking findings)

1. **The kick is the gun's now, not the player's.** `newGun.fire` is model B's own block -- 6.0
   degrees of muzzle rise and 0.20 studs back against the old gun's 4.0 and 0.14, with its own caps,
   frequency and damping -- and `Viewmodel.view` reads `set.fire`, so the OLD gun's recoil is the
   same spring at the same numbers it has had since task 92. Nothing in `Camera.Mode` changed: the
   spring was already there and already played on every shot in carry and aim, and both hands follow
   because they are posed in the gun's frame. `viewmodel_poses.spec` now says which block each gun
   reads and that the two differ.
2. **ONE FLASH NOW, NOT TWO** (finding 1, and it was right). `Effects.muzzleFrame` has asked the
   viewmodel for the SHOOTER'S OWN muzzle since task 92, so the old neon box and grey ball were
   already at the drawn gun -- round 1's comments said twice that they were "in the world, nowhere
   near it", which was false, and Karen saw the result: "remove those smokes (white from previous)".
   `Effects.setViewmodelFlash` is the seam: the viewmodel answers whether it drew its own, and that
   pair is skipped for that shot. Everybody else's shot and the flag-OFF build are drawn there
   exactly as before, and the false comments are replaced with what is true.
3. **Simpler and shorter, as Karen asked** ("should be simple", "recoil is perfect", "smoke short a
   bit"): the recoil numbers are untouched, and the smoke is half what it was -- 0.75 studs for
   0.7 s against 1.5 and 1.4. Every number is data: `newGun.fire.flash` (size, light range and brightness, seconds, how far
   forward) and `.smoke` (size, seconds, rise, transparency, spread, rate, burst) are `pose.py set`
   paths, so the look is tuned live like every other number in `poses.json`.
4. **The two clicks are behind the flag now** (finding 3): round 1 shipped them ON, unflagged, on
   the gun Karen plays, at a volume no data could reach -- only `newGun.fire` has a `volume` block.
   `Weapon.Sound.play` refuses unless `config.NEW_GUN`, which fixes both at once. The edge that
   decides open from close is `Camera.breakSound`, pure and beside `Camera.breakFrom` (finding 4),
   so a spec drives shut -> open -> shut.
5. **THE SHOT SOUND'S ID IS EMPTY, DELIBERATELY.** The dispatch says library sounds only; choosing a
   12-gauge from the library means picking an id I cannot hear, and a wrong one ships as the gun's
   voice. `Weapon.Sound` treats `""` as "play nothing" without a warning, so the path is live and
   waiting for one line in `Camera.Config.SOUND_SHOT_ID`. The two clicks are Studio's own
   `rbxasset://sounds/` files, which ship with the engine and need no library at all.
6. **The case measures it on the drawn instances, and the sound by what came back** (finding 4:
   counting its own calls proved nothing). A flash for each barrel within 0.25 studs of THAT
   barrel's muzzle and closer to it than to the other; `Effects.play` driven with a payload that says
   the shot is mine leaves **zero** old `Flash`/`Smoke` parts and exactly one `MuzzleFlash`, and with
   the seam cleared it draws the old pair again -- so the skip is an answer, not a deletion.
   `Sound.shot` is `false` while the id is empty, the two clicks are `true`, and both are `false` for
   the old gun. **Mutation-checked**: with the `drawnOnScreen` guard forced off,
   `gun_client.spec:545` FAILS on 2 parts where it wants 0.

## What I could not verify

- **THE SHIPPED FRAMES** (finding 2 -- round 1 described none).
  `.screenshots/20261002T201836Z-task112r2-kick.png`: a small white star of light at the muzzle, far
  up the left edge where the barrels point in carry, the gun kicked up-left, the glove lit warm,
  readout `x[*]`. No neon box and no grey ball anywhere in frame.
  `...-smoke.png` (+0.33 s): the flash is gone, the gun is back down -- and **no smoke is visible at
  all**. At 0.75 studs for 0.7 s the puff is brief and the muzzle is off the left edge in carry; it
  may simply be out of frame. That is the one thing a frame has not shown.
- **The shot is silent until Karen picks an id.** Everything else about the sound is wired and
  counted; nobody has heard it.
- **The kick was not compared against the target video frame by frame.** The numbers are a first
  pass, sized by eye against `TARGET-fire-smoke.jpg` and the old gun's, and every one is live.
- **No roll in the recoil.** The dispatch asked for a small roll with the kick; the spring in
  `Camera.Mode` has pitch and back-travel only, and adding an axis to it is a change to the one
  module that is shared with the gun Karen plays. Left out, said here rather than half-done.
- **Only one shot was photographed**, in carry, not in aim.
