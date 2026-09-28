# Task 93 — S3: Karen's two gloved hands on the gun, first person

Task: 93
Round: 1
Base: main (0e94fc2)
Code commit: f83ac79ab940df7d2685eb3c0f99747c56b020c3

```
[harness2] PASS: 32/32 checks @ f83ac79ab940df7d2685eb3c0f99747c56b020c3 (clean tree)
[harness] PASS: 32/32 checks @ f83ac79ab940df7d2685eb3c0f99747c56b020c3 (clean tree)
```

## What changed

Karen's two gloved hands, prepped, uploaded and drawn on the first-person gun. `FIRST_PERSON` stays
`default = false`. A defect in the prep tool's smoothing step was found and fixed on the way.

## Claims

1. **The smoothing step was a no-op and now is not.** `shade` in `tools/asset_prep_blender.py`
   cleared nothing before asking Blender to mark edges sharp by angle, and `shade_smooth_by_angle`
   ADDS to the flag. Measured on Karen's right hand: 1,476 of 3,120 edges arrive flagged, and 35, 70
   and 179 degrees all produced 1,478. Verify: the new `sharpOnImport` and `sharpByAngle` fields, and
   `edges_over_angle`, which counts the same thing off the geometry. Mutation-checked — with the
   clear removed the run FAILS: *"the smoothing step did not take: 1476 edge(s) are flagged sharp but
   277 of 3120 meet at more than 70 degrees"*. The gun preset was re-run after the fix and still
   passes (4,429 on import → 2,092, wanted 2,086).
2. **Two uploads, two manifest rows, one scope.** `Assets.KEYS.handRight`/`handLeft`,
   `scope = "viewmodel"`, and `Assets.keysFor` answers per scope. Verify:
   `tests/server/assets_seam.spec.luau`, "keeps the hands out of the server's preload" — the
   viewmodel scope is exactly the two hands, neither is in `"runtime"`, and the existing
   `#keys == 2` case is the other half. Ids and sha256 match `assets/uploads.json`.
3. **The server loads them and the client draws them.** `src/server/ViewmodelAssetsBoot.server.luau`
   preloads the viewmodel scope and publishes clones into a run-time `ReplicatedStorage` folder;
   `Camera.Viewmodel.hands` clones them under the camera. `ReplicatedStorage.HandAssets` holds the
   three names so neither side carries a literal the other could disagree with. `LoadAsset` is
   server-only and `Assets.Loader` is still the only caller.
4. **The right hand is the body's and the left is the barrels'.** The left hand is parented to
   `Barrels` and re-placed by `Viewmodel.hinge` from the barrels' own transform, like the bead;
   the right hand hangs on the Handle. Verify: `tests/client/camera_client.spec.luau`, "the hands" —
   with the gun open the left hand's place on the BODY moves 0.247 studs and its place on the
   BARRELS moves 0.0000, while the right hand's place on the body moves 0.0000.
5. **Both fallbacks, and the flag-off branch.** No template → no hands, the gun still draws, and it
   is counted (`stats().handsMissing`, 8 → 9 in the run's own note). Flag off → the hands are taken
   OFF rather than left on, which is the lesson task 96 round 2 taught about the barrels. Verify:
   the same client case; the pose maths itself is `tests/server/camera_mode.spec.luau`, "where the
   hands sit on the gun" (three cases: the grip is behind the breech and the forend in front, both
   sets of fingers point at the muzzle, the left palm is up, and the three degrees are degrees).

## Deviation, recorded

`docs/design/camera.md` S3 has `Hardware` write `GripHold`/`ForeHold` attachments and `Viewmodel`
clone the player's own avatar arms. Neither happens: the hands are Karen's uploaded meshes (the
Director's dispatch), and their pose lives in `Camera.Config` beside the drawn bead, the shells and
the fill light — all cosmetic, client-side and first-person only — while `Sight` is on the gun
because the shot geometry depends on it. Written out in `TASKS.md` row 93 and in `Config`.

## What I could not verify

* **Whether the hands look right to Karen.** Screenshots inspected, flag on, daylight: in the CARRY
  the left hand is at the bottom-left under the barrels and mostly out of frame, and the right hand
  is not in frame at all — the accepted carry pose puts the stock and grip outside the picture. In
  ADS the left hand is under the barrels and largely hidden behind them, and the right hand is
  behind the camera (the cheek weld). Both hands are plainly visible only while the gun is BROKEN
  OPEN, where the left cradles under the barrels and the right is on the grip.
* **The hand size (1.28 studs long).** Derived from real proportions at this game's scale, not
  measured against Karen's own picture; it is one constant in `Assets`.
* **Fingers through wood or metal.** Nothing obvious at screenshot resolution; a close-up in the
  break pose is the only view that would settle it.
