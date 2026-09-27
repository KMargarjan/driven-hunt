# Task 94 — clean barrels, built rather than smoothed

Task: 94
Round: 1
Base: `main` (`b29d925`)
Code commit: `a60c8a99062cf7229822a33099f2e5188ff2412e`

```
[harness2] PASS: 32/32 checks @ a60c8a99062cf7229822a33099f2e5188ff2412e (clean tree)
[harness]  PASS: 32/32 checks @ a60c8a99062cf7229822a33099f2e5188ff2412e (clean tree)
```

Karen, after her third test (2026-09-27): *"gun is not smooth and nice … nozzle is terrible (ending
where we aim) … barrels don't feel smooth"*. The Director approved the renders in her place tonight.

## Claims

1. **THE BARRELS ARE BUILT, NOT SMOOTHED.** `asset_prep`'s new `rebuildBarrels` cuts the model where
   the region plan already says the action starts, keeps Karen's stock, action and wooden forend
   (1,282 faces), drops the generated barrels (8,213) and builds two round tubes side by side, 64
   segments each, a rib along the top, a thin-walled muzzle with two real openings and a bead:
   **11,770 triangles** against 19,325. Proportions are a Parallelo's, as fractions of the model's
   own length -- barrels 0.62 of the gun, 23 mm across, a 1.7 mm wall, a 3.4 mm bead.
2. **THE THREE FLAWS THE DIRECTOR FOUND ARE FIXED AT THEIR CAUSES.** The pale shards were faces that
   STRADDLE the cut (a face now goes if ANY vertex is forward of it), plus 344 stray fragments, plus
   one filled breech face. The lengthwise stripes were the FBX's own custom split normals, which
   `shade_smooth` does not touch -- cleared before shading. The barrels' 0.45 metalness was the
   action's: the step that owns those texels now writes 0.10 / 0.50 itself, between the shine pass
   and the check that samples the surface back.
3. **THREE MORE DEFECTS WERE FOUND IN THE GAME AND NOT IN A RENDER, AND EACH COST AN UPLOAD.** Roblox
   reads smoothing GROUPS, not per-edge flags, so the export went back to `mesh_smooth_type="FACE"`
   (task 92 had the reason backwards); tubes built exactly tangent to each other and to the rib
   shimmered where coincident surfaces fight for the depth buffer, so `clearanceT` puts 0.4 mm
   between them; and a borrowed patch of atlas a few dozen pixels wide **blends into its neighbours
   by the third mip level**, which speckled both barrels -- the built faces now sit on a small island
   in the middle of the largest empty square of atlas, painted flat.
4. **THE MANIFEST WALKS FORWARD AND KEEPS EVERY ROW.** v4, v5 and v6 are each kept with their own id
   and the reason they were replaced; v7 (**107443663683446, Approved**) is live. `assets_seam.spec`
   asserts the chain by rule -- exactly one live row, every other pointing at a later version that
   exists -- and names each superseded id. `sightOffsetStuds` is now **computed from the geometry**
   (the prep reports the bead at 0.0021 of the length from the muzzle, 0.491 of the height above the
   centre → `(0, 0.336, -2.19)`), not measured off a screenshot.
5. **THE GAME, IN DAYLIGHT, WITH `FIRST_PERSON` ON** (`.screenshots/…t94d-ads.png`, `…t94d-carry.png`;
   the flag was cleared afterwards). Aimed: two smooth dark tubes taper away to the muzzle with the
   brass bead on the rib at the tip, no speckle, no stripes, no shards -- against `…t94b-ads.png`,
   the same view two uploads earlier, where a bright scalloped shimmer ran down both barrels.
   Carried: a slim blued barrel pair with a soft highlight, the walnut forend and the silver action
   behind it.

## Not verified

- Karen has not seen any of it; the Director approved the renders in her place tonight.
- The barrel REGION still reports metalness 0.45 through the mesh: that median includes the old
  fragments of action geometry the region plan calls "barrel". The built tubes' own texels are 0.10,
  read back out of the shipped PNG.
- Nothing in the harness loads asset 107443663683446; the screenshots are the only evidence that what
  is in the place is what was uploaded.
