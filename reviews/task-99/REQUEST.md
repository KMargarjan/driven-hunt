# Task 99 -- the new shotgun: exact metal, Karen's walnut, a real hinge, and the white glove

Task: 99
Round: 2
Base: main (`2026eee`)
Code commit: b49ae77a58d877866ac2675fcf0d3cc4102ce20d

```
[harness2] PASS: 34/34 checks @ b49ae77a58d877866ac2675fcf0d3cc4102ce20d (clean tree)
[harness] PASS: 32/32 checks @ b49ae77a58d877866ac2675fcf0d3cc4102ce20d (clean tree)
```

**TASK 101 IS MERGED INTO THIS BRANCH AND IS OUT OF THIS REVIEW'S SCOPE.** It rewrote the harness so
nothing it sends needs `require` or `Invoke`, and it was reviewed on its own (PR #90, PASS). It is
why the one-player count is 32 rather than 34, and why both runs are green at all: the two-player
run could not stage a shot before it. Everything below is task 99's own diff.

Behind `NEW_GUN`, born OFF, **first person only**: the world gun every other player sees is
untouched and no number a shot depends on moved. Both guns are driven by parameter, so every spec
drives both while the flag sits off.

**The break-open capture** (`.screenshots/20261001T222212Z-pose-reload.png`, `NEW_GUN` on): the two
slim dark barrels hang down and away to the upper left on the pin, with **two small dark round
chamber mouths** at the breech end where round 1 had a solid blued plate, Karen's golden walnut
stock at the lower right and a dark glove on the forend. The action renders bright white-grey and
the olive sleeve crosses the right of the frame; no shell is visible in a mouth at this framing.

## Claims

1. **The breech shows two open bores (round 1, finding 1).** The `BreechFace` plate that buried both
   discs -- and that the fed shells slid through -- is gone; a Cylinder's rear end is already the
   flat face, and the breech disc now sits DEEPER than `Gun.chamber` seats a shell, so an empty
   chamber reads dark and a fed one shows the shell in front of the dark. Verify: `gun.spec`, "lets
   you SEE both openings" -- nothing in the BARREL GROUP may stand in front of a bore, which is the
   right scope because the break-open is what separates the barrels from the standing breech.
2. **The old case could not have caught it, and the new one can.** A disc sealed inside an opaque
   plate still satisfies "inside its tube". The new case found a second defect on its first run --
   its own box arithmetic treated a Z-lying cylinder's `size.X` as a width, so it reported the left
   muzzle bore as hidden by the right barrel. The test was wrong, the gun was not (`1232022`).
3. **The muzzle flash is on the bore line, for both guns (round 1, finding 2).** `Gun.muzzle` is
   back on the Handle's axis (`= MUZZLE_OFFSET` exactly) and `Gun.barrelOffset` is the one definition
   of this gun's bore line -- sign from `Shotgun`, magnitude this gun's own 0.076.
   `Viewmodel.muzzle` picks the offset from an attribute the BUILDER wrote on the model, so no caller
   can hand it the wrong gun. Verify: `gun.spec` (pure: the flash lands exactly on the tube's axis)
   and `gun_client.spec` (live: inside the drawn tube, and the OLD gun's flash exactly where it has
   always been). MUTATION CHECKED: putting the attachment back on the bore line failed four
   assertions across both files, then restored.
4. **The metal is exact geometry and the hinge is real.** Verify: `gun.spec` -- the barrels are
   Cylinders with equal cross-axes, four bore discs sit inside their own tubes, the drawn `HingePin`
   is at exactly `Gun.hinge`, nothing on the body rises above the rib, 22 parts exactly;
   `gun_client.spec` -- the tube moves, the pin does not, the tube keeps its place on the barrel
   group and its distance to the pin is unchanged.
5. **The white glove was `AlphaMode.Overlay` over a map with no alpha channel**, measured in three
   steps and proved by isolation (the comment above `showItsOwnColour` has all four). The dispatch's
   "wrong id for the right hand" was wrong: both ids were present. The map now goes on `TextureID`,
   whose id lives in the manifest row because a game script cannot read `SurfaceAppearance.ColorMap`
   at all. Verify: `gun_client.spec` ("never left at Roblox's default grey") and `gun.spec`'s glove
   case.
6. **Karen's walnut stock is in; the forend is not, and that was measured.** `A-barrels.glb` is one
   mesh, one material, one primitive and -- welded by position, the test that survives UV seams --
   ONE connected component spanning the whole model, so Meshy fused the forend into the barrels.
   Verify: `gun.spec`'s two wood cases, and the `assets/uploads.json` row for asset 115346777423870
   with Karen's verbatim OK.

Not verified: whether the new gun LOOKS right. It does not yet -- the capture above says how -- and
those are `poses.json`'s `newGun` set and `Gun.LOOK`, which is the content lane. The Reviewer's
round-1 notes are queued as `TASKS.md` row 99a(f), unfixed.
