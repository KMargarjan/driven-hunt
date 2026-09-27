# Task 90 — S1's hand, and S2: the bead you aim with

Task: 90
Round: 1
Base: `main` (`364e5fd`)
Code commit: `a51e82f46d8ee65d479a69d7702e970d17356c5e`

```
[harness2] PASS: 32/32 checks @ a51e82f46d8ee65d479a69d7702e970d17356c5e (clean tree)
[harness]  PASS: 32/32 checks @ a51e82f46d8ee65d479a69d7702e970d17356c5e (clean tree)
```

My own `gate.sh` at this head, `FIRST_PERSON` **OFF**, no override (`flags.py` printed
`override none` before the run, and again after the screenshots were taken and the override cleared).

**Two gates failed before this one, and neither failure was the game.** `[harness2] 28/32 @ d919450`:
one case expected `BasePart.Size` to *equal* `0.055` and got `0.054999999701976776` — float32, so the
claim is now a tolerance. `[harness] 30/32 @ 3611c71`, twice: my own two spec faults, both about
frames — a fallback case that passed the **live** manifest row and expected the fallback (true only
while no row carried a measurement, and this task measured one an hour earlier), and a bound that
compared the bead's `Z` against `sizeStuds.Z/2` when `sizeStuds` is the **mesh's** box *before*
`rotationDeg` puts its length on `Z`. Both are fixed in their own commits with the reason in the
message. Nothing was re-run until each was diagnosed.

**What changed.** `src/server/Weapon/Shape.luau` (`beadOffset`, `sight`), `Hardware.luau`
(`SIGHT_NAME`, `setSight`, the row's measurement, the once-per-server warning),
`src/serverstorage/Assets/init.luau` (`sightOffsetStuds`, and the gun row's measured value),
`src/client/Camera/Config.luau` (the mirrored carry, `EYE_RELIEF_STUDS`,
`BEAD_CENTRE_TOLERANCE_DEG`, the bead marker), `Mode.luau` (`aimOffset`), `Viewmodel.luau`
(`sight`, `stats`, the drawn bead), `tests/server/camera_mode.spec.luau`,
`tests/server/assets_seam.spec.luau`, `tests/client/camera_client.spec.luau`, `PLAYTEST.md`,
`GAME_DESIGN.md` (two owner rows), `TASKS.md` rows 90/90a.

## Claims

1. **KAREN'S S1 PLAYTEST IS RECORDED VERBATIM** in `PLAYTEST.md`, with the six questions and what she
   answered — including the two she did not answer separately. First person and the missing crosshair
   are **accepted** (*"feel good"*, *"nice, love it"*, *"first step is nice"*); the carry hand, the
   aimed distance and the bead are what this task changes; hands are hers to have in S3.

2. **THE CARRY IS RIGHT-HANDED NOW.** `VIEWMODEL_CARRY_POS_STUDS.X` is `+0.95` and the yaw and roll
   are mirrored (`+14 / -8`), so the stock sits at the right shoulder and the barrels cross toward the
   centre-left — *"right hand grip and left hand pipes"*. The spec asserts the position's sign **and
   that the muzzle points IN** (`carry.LookVector.X < 0`, still forward): the sign alone would pass
   with the gun aimed off the right edge of the screen.

3. **ADS IS GEOMETRY.** `Mode.aimOffset(sightLocal, config) = CFrame.new(0, 0, -EYE_RELIEF_STUDS) *
   sightLocal:Inverse()`, so composing it with the gun's own `Sight` puts that attachment exactly
   `EYE_RELIEF_STUDS` in front of the eye, looking where the camera looks — asserted to 1e-4 on the
   position and 1e-6 on the direction, with **zero** tolerance beyond floating point. A second case
   moves the sight and requires the pose to move with it, so a function that ignored its argument
   cannot pass.

4. **ONE EXPRESSION DECIDES WHERE THE BEAD IS.** `Shape.beadOffset` places the `Bead` piece **and**
   answers `Shape.sight`; the spec asserts the piece and the sight agree to **1e-6**. Two expressions
   would let the bead a player sees and the point the camera aims drift apart — both measured, both
   green, and the picture a lie.

5. **THE GUN CARRIES ITS OWN SIGHT, AND THE MESH'S IS MEASURED.** `Weapon.Hardware` writes a `Sight`
   attachment beside `Muzzle` in `build`, overwrites it from the manifest row in `addMesh`, and leaves
   **exactly one** after `upgrade` (asserted). With no measurement it falls back to the parts gun's
   bead and warns **once per server**, not once per grant.

6. **THE BEAD IS DRAWN, BECAUSE THE MESH'S OWN IS PAINTED.** `Camera.Viewmodel` adds one `SightBead`
   (Neon, `CanQuery = false`, 0.055 studs) **at the `Sight` attachment** when the cloned gun has no
   `Bead` part — so the mark the player follows the animal with *is* the point the geometry aims, one
   Instance rather than two numbers that agree today. A gun that brought its own bead gets nothing
   added (asserted both ways), and the marker's colour is asserted equal to `Shotgun.CONFIG.LOOK.bead`
   so the camera's written-out copy cannot drift.

7. **THE NUMBER THE DIRECTOR ASKED FOR: 0.00–0.01 px.** The client spec poses the viewmodel with a
   first-person config on the **real camera in the real viewport**, with no yield between the pose and
   the measurement, and projects both the `Sight` and the `Bead`: each must be within
   `BEAD_CENTRE_TOLERANCE_DEG = 0.37` of the screen centre **and of the shot's own line** — the point
   143 studs down `camera.CFrame.LookVector`, which is the ray `Weapon` fires (`shotgun.md` §5.5). At
   the code commit: `task90 bead: worst 0.00 px from the shot line and the screen centre, tolerance
   3.76 px (0.37 deg, viewport 1082x712, fov 70)` — and 0.01 px at 958×784. The tolerance is derived
   from the live viewport, never a fixed pixel count, because a small Play window would make a fixed
   count a *looser* angular claim.

8. **THE MESH'S BEAD HEIGHT WAS FOUND BY LOOKING, WHICH IS THE ONLY WAY IT CAN BE FOUND.** The first
   ADS capture put the drawn bead at the parts gun's height (Y = 0.255) and it was **invisible** —
   buried in the muzzle's own metal; the brightest pixel within 60 px of the screen centre was
   (185, 197, 219), the mesh's lit rim, not a Neon ball. The template's box is 0.689 studs tall about
   the Handle's centre, so nothing it has reaches above +0.345: `sightOffsetStuds = (0, 0.375, -2.15)`
   clears the highest point it could have by 0.03. The next capture's **centre pixel is (255, 254,
   252)**. Recorded in the row with the date and the method.

9. **THE NEAR PLANE STILL HOLDS AT THE CLOSER VIEW.** `EYE_RELIEF_STUDS` goes 5.6 → **5.0** — Karen's
   *"view has to be closer when aiming, like looking through pipes"*, about 12 % more gun across the
   frame. The corner assertion is run against the **real** aimed pose now, and the run reports
   `task90: aimed, nearest gun corner -0.650 studs (eye relief 5.00, margin 0.25)`. The floor is ~4.6.

10. **SIX MUTATIONS, IN TWO RUNS, EACH FAILING ITS OWN NAMED CASE, ALL RESTORED.** At `4af61e2`
    (`[harness] FAIL: 28/32, DIRTY`): `aimOffset` ignoring the sight → `camera_mode.spec:428` **and**
    the client bead measurement; the viewmodel drawing no marker → the client marker case; the carry
    back on the left → `camera_mode.spec:320`; `Shape.sight` offset from `beadOffset` →
    `assets_seam.spec:574`. At `a51e82f` (`FAIL: 30/32, DIRTY`): no `Sight` created in `build` →
    `assets_seam.spec:536` and `:636`; an absurd `sightOffsetStuds` of Y = 0.9 → the manifest bound at
    `:689`.

## The screenshots, described as they are

Taken with the override on and cleared afterwards; a one-player Play session, because in the
two-player one the MCP could not reach Player1's window and Player2 was the driver (no gun).

- **Carry (`20260927T113716Z-task90-carry-1p.png`).** First person. The gun enters from the
  **lower-right**: the wooden stock in the bottom-right corner, the action across the middle, the
  barrels running up toward the centre-left, with a small bright bead at the muzzle tip. Roughly half
  the gun is in frame. No reticle anywhere. The scene is **dark** — the shooter's post is under the
  canopy, as in Task 89.
- **ADS (`20260927T114417Z-task90-ads-closer.png`).** Looking down the gun from behind: receiver,
  forend, the two barrels running away, and **a bright white bead at the muzzle, at the centre of the
  screen**. Measured on the image itself: the bead's bright centroid is at (477.9, 392.0) against a
  centre of (479, 392) — **1.1 px left, 0.0 px up or down** (the bright pixels span ~41 px including
  the Neon bloom; the solid core is ~9 px). No crosshair. **Honest about the angle:** you look at the
  barrels slightly **from above** rather than flat along the rib, because the sight sits 0.375 studs
  above the bore on this mesh and the eye is on that line. That is the geometry, not a choice, and
  the flatness is what a lower bead — or Karen's word — would change.
- **The first ADS attempt (`20260927T113738Z-task90-ads-1p.png`) is kept and described in claim 8**:
  the same picture with **no visible bead**, which is why the measurement exists.
