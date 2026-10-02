# Task 112 - shooting: the kick, the flash and the noise

Task: 112
Round: 1
Base: `task-111-reload-hand` (`0030a56`)
Code commit: `4ee53b62983b150f544a477e388047cbc181200f`

```
[harness] PASS: 33/33 checks @ 4ee53b62983b150f544a477e388047cbc181200f (clean tree)
[harness2] PASS: 35/35 checks @ 4ee53b62983b150f544a477e388047cbc181200f (clean tree)
```

`test2` is required: `src/client/Camera/Config.luau`, `init.luau`, `CameraBoot.client.luau` and
`src/client/Weapon/` are all outside `WEAPON_VIEWMODEL_PATHS`.

## Claims

1. **The kick is the gun's now, not the player's.** `newGun.fire` is model B's own block -- 6.0
   degrees of muzzle rise and 0.20 studs back against the old gun's 4.0 and 0.14, with its own caps,
   frequency and damping -- and `Viewmodel.view` reads `set.fire`, so the OLD gun's recoil is the
   same spring at the same numbers it has had since task 92. Nothing in `Camera.Mode` changed: the
   spring was already there and already played on every shot in carry and aim, and both hands follow
   because they are posed in the gun's frame. `viewmodel_poses.spec` now says which block each gun
   reads and that the two differ.
2. **The flash and the smoke come out of the pipe that fired, on the DRAWN gun.** `Weapon.Effects`
   draws the WORLD flash for every player's shot; the first-person gun is two studs from the eye and
   nowhere near it, so `Camera.Viewmodel.flash` draws this one -- a `PointLight` and two
   `ParticleEmitter`s (a one-burst bloom and a grey puff that rises and thins) parented to the
   viewmodel at `Viewmodel.muzzle(barrel)`. New gun only, and said twice: the flag, and that the old
   gun's `fire` block carries no `flash` at all.
3. **Every number is data**: `newGun.fire.flash` (size, light range and brightness, seconds, how far
   forward) and `.smoke` (size, seconds, rise, transparency, spread, rate, burst) are `pose.py set`
   paths, so the look is tuned live like every other number in `poses.json`.
4. **The noise has one owner.** `Weapon.Sound` is the only writer of the gun's sounds for the local
   player, played on the shot (from `Weapon.Fired`) and on the break and the close (from the one
   closure that already sees that state flip). Volumes are in `newGun.fire.volume`.
5. **THE SHOT SOUND'S ID IS EMPTY, DELIBERATELY.** The dispatch says library sounds only; choosing a
   12-gauge from the library means picking an id I cannot hear, and a wrong one ships as the gun's
   voice. `Weapon.Sound` treats `""` as "play nothing" without a warning, so the path is live and
   waiting for one line in `Camera.Config.SOUND_SHOT_ID`. The two clicks are Studio's own
   `rbxasset://sounds/` files, which ship with the engine and need no library at all.
6. **One client case measures the three on the drawn instances**: the new gun's kick is bigger than
   the old gun's, a flash exists for each barrel with a light and two emitters within 0.25 studs of
   THAT barrel's muzzle and closer to it than to the other one, the flag-OFF config draws none, and
   the three sounds are each asked for once.

## What I could not verify

- **The shot is silent until Karen picks an id.** Everything else about the sound is wired and
  counted; nobody has heard it.
- **The kick was not compared against the target video frame by frame.** The numbers are a first
  pass, sized by eye against `TARGET-fire-smoke.jpg` and the old gun's, and every one is live.
- **No roll in the recoil.** The dispatch asked for a small roll with the kick; the spring in
  `Camera.Mode` has pitch and back-travel only, and adding an axis to it is a change to the one
  module that is shared with the gun Karen plays. Left out, said here rather than half-done.
- **Only one shot was photographed**, in carry, not in aim.
