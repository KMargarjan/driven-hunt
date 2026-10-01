# Task 99 -- the new shotgun: exact metal, Karen's walnut, a real hinge, and the white glove

Task: 99
Round: 1
Base: main (`2026eee`)
Code commit: f2b96671ffb7ddb65444e35f60d8637829cf3b35

```
[harness2] PASS: 34/34 checks @ f2b96671ffb7ddb65444e35f60d8637829cf3b35 (clean tree)
[harness] PASS: 34/34 checks @ f2b96671ffb7ddb65444e35f60d8637829cf3b35 (clean tree)
```

Behind `NEW_GUN`, born OFF, **first person only**: the world gun every other player sees is
untouched and no number a shot depends on moved. Both guns are driven by parameter, so every spec
drives both while the flag sits off.

## Claims

1. **The metal is exact geometry, and the hinge is real.** `src/shared/Gun` is the pure piece list
   plus the gun's own arithmetic. Verify: `tests/server/gun.spec.luau` -- the barrels are Cylinders
   with equal cross-axes (a Roblox Cylinder is analytically round, which is the whole reason this is
   parts: the note, section 3), four bore discs sit inside their own tubes, the drawn `HingePin` is
   at exactly `Gun.hinge`, and nothing on the body rises above the rib. `tests/client/gun_client.spec.luau`
   measures the live model: the tube moves and the pin does not, the tube keeps its place on the
   barrel group, and its distance to the pin is unchanged -- which is what makes it a rotation about
   that axis rather than a slide.
2. **The shells go IN.** `Gun.chamber` puts each shell on its own tube's bore line instead of the
   gun's centre line, which is why they floated in the gap. Verify: `gun.spec` ("puts a chamber on
   each tube's own bore line") and `gun_client.spec` ("seats a fresh shell INSIDE the barrel"),
   which measures in the tube's own frame with no yield.
3. **The white glove was `AlphaMode.Overlay` over a map with no alpha channel**, measured in three
   steps and proved by isolation (the comment above `showItsOwnColour` has all four). The dispatch's
   "wrong id for the right hand" was wrong: both ids were present. The map now goes on `TextureID`,
   whose id lives in the manifest row because **a game script cannot read
   `SurfaceAppearance.ColorMap` at all** -- "lacking capability Plugin", which took the whole boot
   down and published nothing. Verify: `gun_client.spec` ("never left at Roblox's default grey") and
   `gun.spec`'s glove case; live, all three templates publish with their map on `TextureID`.
4. **Karen's walnut stock is in; the forend is not, and that was measured.** `A-barrels.glb` is one
   mesh, one material, one primitive and -- welded by position, the test that survives UV seams --
   ONE connected component spanning the whole model, so Meshy fused the forend into the barrels and
   there is no loose part to lift out. Verify: `gun.spec`'s two wood cases; `assets/uploads.json`
   row for asset 115346777423870 with Karen's verbatim OK; the exact-geometry forend is drawn in the
   same place at the same size, and `Camera.Viewmodel` swaps in a mesh the moment a row appears.
5. **The flag's OFF branch is the gun Karen has been playing.** Verify: `NEW_GUN` is `default =
   false` in `src/shared/Flags`, `Camera.Config` reads it once at its boundary, and every
   `camera_client.spec` case that drove the cloned gun still drives it unchanged -- 34/34 both ways.

Not verified: whether the new gun LOOKS right. It does not yet, and the report says what the three
captures show -- the action renders bright, the aimed picture is wrong (the action's top face
dominates and the barrels read small) and the right hand is off screen in all three poses. Those are
`poses.json`'s `newGun` set and `Gun.LOOK`, which is the content lane, and they are TASKS.md row 99a.
