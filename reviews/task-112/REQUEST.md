# Task 112 - shooting: the kick, the flash and the noise

Task: 112
Round: 3
Base: `content-hands-karen-1` (PR #102 was retargeted by the Director)
Code commit: `3e7a1d3334a4ac640b68348e2467212b4df439a2`

```
[harness]  PASS: 33/33 checks @ 3e7a1d3334a4ac640b68348e2467212b4df439a2 (clean tree)
[harness2] PASS: 35/35 checks @ 3e7a1d3334a4ac640b68348e2467212b4df439a2 (clean tree)
```

**THE TWO-PLAYER LINE WAS A FAIL TWICE AND IS FIXED IN THE TEST SETUP** (Director's decision on the
`ESCALATE.md` entry, now closed): the shooter is tied on purpose by the LAST scenario in
`input_scenarios.txt`, which exists FOR `zz_tie_to_a_tree.spec`, so pardoning ties would take the tie
from the one spec whose subject it is. The two failing cases in `weapon_client.spec` assumed an
equipped gun AFTER that scenario had run -- one waited on `Weapon.get().equipped` while saying one
line down that `Weapon.get()` is the wrong thing to ask, and now reads the equip off the LOG; the
other accepts an EMPTY readout when there is no gun in hand, which the case beside it already says in
its own note. No gameplay file is touched and `Match` is untouched.

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
1. **THE STAR WAS THE DEFAULT TEXTURE** (round 3). Karen: "flash is not perfect seems like animation
   kids smoke has to be real life simple", and "I am not about size I am about this shape like a
   star". A `ParticleEmitter` with no `Texture` draws Roblox's four-pointed SPARKLE, which is the
   shape she described. Both emitters carry one of the engine's own soft textures now --
   `rbxasset://textures/particles/fire_main.dds` for the flash,
   `rbxasset://textures/particles/smoke_main.dds` for the smoke. `rbxasset://` is shipped with
   Studio: nothing uploaded, no library asset, nothing fetched. The colours the Director previewed
   live and Karen OK'd ("smoke looks good now", the flash "yes") are DATA, because a colour is three
   numbers: the flash runs RGB(255,190,110) -> RGB(255,120,40) at `LightEmission` 1, the smoke is a
   flat RGB(190,190,185) at 0. Every other number in `newGun.fire` is the Director's content commit,
   untouched.
2. **ONE FLASH, NOT TWO** (round 1's finding 1, and it was right). `Effects.muzzleFrame` has asked the
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
5. **THE GUN HAS A VOICE**: Audioscape's "AS_shotgun_shot-01", `rbxassetid://99008924129683`, found
   by the Director at Karen's asking -- Roblox-provided library audio, NOT an upload, so nothing was
   published to Karen's account and no asset row is needed; the source is written beside the id.
   **Nobody here has heard it**: the Builder cannot play audio and the Director picked it from the
   store page. The two clicks are Studio's own `rbxasset://sounds/` files. `Weapon.Sound` still
   treats an empty id as "play nothing", which is what the old gun gets.
6. **THE READOUT CASE REALLY ASSERTS NOW** (round 2's finding): it returned before its only
   assertion whenever the player was tied, which is every `test2` run -- the last scenario ties him
   on purpose. `Hud.readoutFor` exports the formatter, so the case asks the SHAPE of a state it owns
   and then requires the live text to be empty exactly when there is no gun in hand.
   **Mutation-checked** in the one-player run (the case runs in both): with `readoutFor` returning
   `""`, `weapon_client.spec:950` FAILS. The flash case also asserts both textures are `rbxasset://`
   and neither is a sparkle -- **mutation-checked**: with the flash texture cleared,
   `gun_client.spec:560` FAILS.
7. **The rest measures on the drawn instances, and the sound by what came back** (finding 4:
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
- **Nobody has heard the shot sound.** The id is the Director's pick from a store page; the spec
  proves an id reached a `Sound` and nothing more. Karen is the first person who will know.
- **The kick was not compared against the target video frame by frame.** The numbers are a first
  pass, sized by eye against `TARGET-fire-smoke.jpg` and the old gun's, and every one is live.
- **No roll in the recoil.** The dispatch asked for a small roll with the kick; the spring in
  `Camera.Mode` has pitch and back-travel only, and adding an axis to it is a change to the one
  module that is shared with the gun Karen plays. Left out, said here rather than half-done.
- **Only one shot was photographed**, in carry, not in aim.
