# Task 90 — S1's hand, and S2: the sight picture Karen sent

Task: 90
Round: 1
Base: `main` (`364e5fd`)
Code commit: `f22f74a41947b19bf093103d63f31ec3ffd92686`

```
[harness2] PASS: 32/32 checks @ f22f74a41947b19bf093103d63f31ec3ffd92686 (clean tree)
[harness]  PASS: 32/32 checks @ f22f74a41947b19bf093103d63f31ec3ffd92686 (clean tree)
```

My own `gate.sh` at this head, `FIRST_PERSON` **OFF**, no override (`flags.py` printed `override none`
before the run and again after the screenshots).

**Four gate failures happened on the way here and none of them was the game.** `[harness2] 28/32 @
d919450`: a case expected `BasePart.Size` to *equal* `0.055` and got `0.054999999701976776` — float32,
so the claim is a tolerance now. `30/32 @ 3611c71` (both runs): two spec faults of mine, both about
frames — a fallback case that passed the **live** manifest row and expected the fallback (true only
while no row carried a measurement, and I measured one an hour earlier), and a bound that compared the
bead's `Z` against `sizeStuds.Z/2` when `sizeStuds` is the **mesh's** box *before* `rotationDeg` puts
its length on `Z`. `[harness] 29/32 @ f22f74a` **with `[harness2] 32/32 at the same commit**: the
input replay could not reach the client — `VirtualInput::SendMousePosition: position (400.0, 358.0)
hits CoreGUI` and `CoreGUI has keyboard focus` — so `shoot-the-boar` never replayed and
`shoot_boar.spec` failed. That is **my own doing and not the build**: I had just driven that same
Studio process by hand for the screenshots (synthetic right-mouse and W/S/D), and `test2`, which uses
separate client processes, passed at that very commit. The next run of both was green with nothing
changed. Each failure was diagnosed before anything was re-run.

**What changed.** `src/server/Weapon/Shape.luau` (`beadOffset`, `sight`), `Hardware.luau`
(`SIGHT_NAME`, `setSight`, the row's measurement, the once-per-server warning),
`src/serverstorage/Assets/init.luau` (`sightOffsetStuds`, and the gun row's measured value),
`src/client/Camera/Config.luau` (the mirrored carry and its distance, `EYE_RELIEF_STUDS`,
`BEAD_CENTRE_TOLERANCE_DEG`, the red bead), `Mode.luau` (`aimOffset`), `Viewmodel.luau` (`sight`,
`stats`, the drawn bead), the three spec files, `PLAYTEST.md`, `GAME_DESIGN.md` (two owner rows),
`TASKS.md` rows 90/90a.

## Claims

1. **KAREN'S S1 PLAYTEST IS RECORDED VERBATIM** in `PLAYTEST.md` with the six questions. First person
   and the missing crosshair are **accepted**; the carry hand, the aimed distance and the bead are
   what this task changes; hands are S3.

2. **THE CARRY IS RIGHT-HANDED, AND CLOSER.** `VIEWMODEL_CARRY_POS_STUDS` is `(0.85, -1.3, -2.1)` with
   the yaw and roll mirrored (`+14 / -8`): the stock sits at the right shoulder and the barrels cross
   toward the centre-left — *"right hand grip and left hand pipes"* — and the gun is about a quarter
   bigger on screen than the first build round's `-2.6`, which read small and far. The spec asserts the
   position's sign **and that the muzzle points IN** (`carry.LookVector.X < 0`, still forward).

3. **ADS IS GEOMETRY.** `Mode.aimOffset(sightLocal, config) = CFrame.new(0, 0, -EYE_RELIEF_STUDS) *
   sightLocal:Inverse()`, so composing it with the gun's own `Sight` puts that attachment exactly
   `EYE_RELIEF_STUDS` in front of the eye, looking where the camera looks — asserted to 1e-4 on the
   position and 1e-6 on the direction. A second case moves the sight and requires the pose to move with
   it, so a function that ignored its argument cannot pass.

4. **THE EYE RELIEF IS MEASURED OFF KAREN'S OWN PICTURE, not chosen.** `ads-target-karen.jpg`: the
   barrel is about **4.4×** wider where it leaves the bottom of the frame than at the muzzle. Apparent
   width goes as 1/distance, so the muzzle is 4.4× as far as the point where the bore line drops half
   the vertical field below the sight line — with the bead 0.375 studs above this mesh's bore and a 50°
   field, `0.375/tan(25°) = 0.80`, so `4.4 × 0.80 = 3.5`. `EYE_RELIEF_STUDS` is **3.5** (the design's
   first pick was 5.6; the first build round used 5.0 and put the eye a whole gun behind the breech).

5. **ONE EXPRESSION DECIDES WHERE THE BEAD IS.** `Shape.beadOffset` places the `Bead` piece **and**
   answers `Shape.sight`; the spec asserts they agree to **1e-6**.

6. **THE GUN CARRIES ITS OWN SIGHT, AND THE MESH'S IS MEASURED.** `Weapon.Hardware` writes a `Sight`
   attachment beside `Muzzle` in `build`, overwrites it from the manifest row in `addMesh`, and leaves
   **exactly one** after `upgrade`. With no measurement it falls back to the parts gun's bead and warns
   **once per server**. The mesh's value was found by looking: at the parts gun's height the drawn bead
   was **invisible**, buried in the muzzle's metal (the brightest pixel within 60 px of the screen
   centre was (185, 197, 219) — the mesh's lit rim, not a Neon ball); the template's box is 0.689 studs
   tall about the Handle's centre, so `(0, 0.375, -2.15)` clears the highest point it could have by
   0.03, and the next capture's centre pixel was (255, 254, 252).

7. **THE BEAD IS RED, AND A LITTLE LARGER.** `BEAD_MARKER_COLOR = (255, 45, 35)`, `BEAD_MARKER_STUDS =
   0.07` (≈1.15° at 3.5 studs, ≈18 px in a 784-px viewport). It is deliberately **not**
   `Shotgun.CONFIG.LOOK.bead` any more: that off-white is the parts gun's own piece, which other players
   see, while this is the aiming mark the camera draws for one player — so the client spec asserts it is
   **really red** (R > 200, G and B < 90) rather than asserting a copy still matches.

8. **THE NUMBER: 0.00–0.02 px in the spec, 0.9 px on the screenshot.** The client spec poses the
   viewmodel with a first-person config on the **real camera in the real viewport**, with no yield
   between the pose and the measurement, and requires both the `Sight` and the `Bead` to be within
   `BEAD_CENTRE_TOLERANCE_DEG = 0.37` of the screen centre **and of the shot's own line** (143 studs
   down `camera.CFrame.LookVector`, the ray `Weapon` fires). At the code commit: `task90 bead: worst
   0.00 px ... tolerance 3.76 px (0.37 deg, viewport 1082x712, fov 70)`, and 0.02 px at 958×784. On the
   ADS screenshots themselves, the red pixels' centroid is **0.9 px** from the centre in both.

9. **THE NEAR-PLANE CLAIM IS SPLIT IN TWO, AND THAT IS A DEVIATION FROM THE DESIGN** (§9.1 item 8:
   *every* corner of the gun's box, both poses). Karen's picture is a **cheek weld** — the stock is
   under the cheek, behind the eye — so the design's rule forbids the framing she asked for. The spec
   asserts instead: (i) the pieces a player aims **through** (`BarrelLeft`, `BarrelRight`, `Rib`,
   `Bead`, taken from `Shape.pieces`, and the case asserts it really found four) clear
   `NEAR_PLANE_MARGIN_STUDS` in **both** poses — `nearest aimed-with corner -0.812 studs (aimed
   BarrelLeft), margin 0.25, eye relief 3.50`; and (ii) when aiming the `Stock`'s rearmost corner is
   **behind** the camera — `the stock's rearmost corner is 0.807 studs behind the eye` — while in the
   carry pose every barrel corner is still in front. Nothing was loosened: the claim was split, and the
   second half is Karen's picture written as an assertion. Recorded in `TASKS.md` row 90a(a2) for the
   Architect.

10. **NINE MUTATIONS, IN THREE RUNS, EACH FAILING ITS OWN NAMED CASE, ALL RESTORED.** At `4af61e2`:
    `aimOffset` ignoring the sight → `camera_mode.spec:428` **and** the client bead measurement; no
    drawn marker → the client marker case; the carry back on the left → `camera_mode.spec:320`;
    `Shape.sight` offset from `beadOffset` → `assets_seam.spec:574`. At `a51e82f`: no `Sight` in
    `build` → `assets_seam.spec:536` and `:636`; `sightOffsetStuds` of Y = 0.9 → the manifest bound at
    `:689`. At `f22f74a`: the carry pulled to Z = −0.5 → the aims-with corner case
    (`camera_mode.spec:387`); `EYE_RELIEF_STUDS = 6.0` → the cheek-weld case (`:420`); the bead back to
    off-white → the "is red" case (`camera_client.spec:823`).

## The screenshots, described as they are, beside Karen's picture

One-player Play session with the override on, then cleared. I walked the player out of the canopy
onto open ground with synthetic key holds, so the last two are in **daylight** as asked.

- **Carry, daylight (`20260927T120639Z-task90b-carry-light.png`).** Blue sky, lit open ground, the
  treeline to the left, a shooter post in the distance. The gun enters from the **lower-right** — a
  near-black silhouette (blued barrels against bright ground) running up-left, with the **red bead**
  clearly at the muzzle. Honest: in daylight the gun reads as a dark shape with a red dot on it.
- **ADS, daylight (`20260927T120659Z-task90b-ads-light.png`).** The gun fills the lower centre: the
  receiver at the bottom, the two barrels running away and converging, the muzzle just below centre and
  the **red bead at the screen centre** against the sky. **No stock plank** — it is behind the eye.
- **Against `ads-target-karen.jpg`:** the shape now matches hers — eye just behind the breech, barrels
  filling the lower centre, a small red bead dead centre at the far end, no stock. **Two differences,
  stated plainly.** (a) Ours is a dark silhouette where hers is a light-grey tube: her gun is a
  single-barrel pump in bright side light, ours is Karen's own blued side-by-side backlit by the sky.
  (b) Ours is seen slightly more **from above** — you can see the tops of the barrels and the receiver.
  That is geometry, not a choice: the eye sits on the bead's line, and this mesh's bead has to be 0.375
  studs above the bore to be visible at all (claim 6), which looks down on the barrels by
  `atan(0.375/3.5) = 6.1°`. Hers sits lower on a flatter rib. Lowering ours is one number in the
  manifest row and it buries the bead again — Karen's call.
- **The earlier captures are kept**: `...113738Z-task90-ads-1p.png` (no visible bead, why claim 6
  exists) and `...114417Z-task90-ads-closer.png` (the 5.0 framing: the stock as a plank across the
  lower half, which is what this round replaced).
