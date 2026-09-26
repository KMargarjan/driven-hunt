# Task 74 — M2.7a: the id → Instance seam, and Karen's shotgun is the gun

Task: 74
Round: 1
Base: `main` (`f3f6a49`)
Code commit: `1c4ae70e14cac934a4237ccb47342aeeb224bcbd`

```
[harness]  PASS: 30/30 checks @ 1c4ae70e14cac934a4237ccb47342aeeb224bcbd (clean tree)
[harness2] PASS: 32/32 checks @ 1c4ae70e14cac934a4237ccb47342aeeb224bcbd (clean tree)
```

Both lines are the Director's runs at this branch's head, and **`test2` matters for this change** —
it touches `src/`, so a second client is real evidence rather than a formality. The head is the
paperwork commit, so it is at or after every commit that touched `src/` or `tests/` (the last was
`41ca09a`) and the only things between them are `TASKS.md` rows 74/74a and this file. My own
clean-tree `[harness] PASS: 30/30 @ 41ca09a` covers the same code.

**What changed.** New `src/serverstorage/Assets/init.luau` (the manifest) and `Loader.luau` (the
seam), new `tests/server/assets_seam.spec.luau`; `Weapon.Hardware`, `WeaponBoot`,
`Camera.Viewmodel`, `weapon_look.spec` and `camera_client.spec` changed. 398 server specs (390
before: eight new), 84 client.

## Claims

1. **The seam is the design's, not a new one.** `docs/design/asset-pipeline.md` §§4–5 specify the
   manifest's interface (`VERSION`, `ROWS`, `KEYS`, `byKey`, `describe`, `keysFor`) and the Loader's
   (`setInsert`, `setCacheParent`, `preload`, `template`, `stats`, `clear`, a `LoadReport` with a
   named reason). Both are built to that, so the owner rows Task 73 put in `GAME_DESIGN.md` now
   describe things that exist.

2. **The yield boundary is real and it is why there are two functions.** `preload` yields and
   `WeaponBoot` calls it once at server start; `template` never yields, so `Hardware.build` — reached
   from a grant path whose own header records what a yield there cost this project — cannot block.
   Verify: `Loader.template` calls nothing that yields, and `WeaponBoot` is the only `preload` caller.

3. **Measured before written.** In Studio, `LoadAsset(117134580332969)` returns
   `Model > Model > one MeshPart + SurfaceAppearance`, natural **199.999 × 31.314 × 11.311** studs,
   `MeshId rbxassetid://72415641939074`, `TextureID` set. Every number in the manifest row comes from
   that measurement or from `assets/uploads.json`.

4. **The size is uniform, and the spec proves it rather than restating it.** The mesh is scaled so
   its **length** is `HANDLE_SIZE.Z`; every axis uses the same factor. A non-uniform fit to the
   0.4 × 0.5 envelope would squash the gun 28 % flatter (8.8:1 against the real 6.4:1) and measure
   perfectly — design §6.1's squashed boar. Verify: `assets_seam.spec`, `it("keeps the gun's LENGTH
   and does not squash it")`, which asserts the three axes share one factor and that the result is
   *not* the envelope.

5. **The gun pointed backwards and only the screenshot said so.** `tools/asset_prep.py` measured the
   muzzle at the source model's minimum X; the arithmetic from that gives −90° about Y; the FBX
   import flips that axis. Photographed both ways from the same camera
   (`.screenshots/…task74-yaw-plus90.png` and `…-minus90.png`): **+90** puts the muzzle at the
   Handle's −Z, which is what `GRIP` and `MUZZLE_OFFSET` mean. This is `docs/PROJECT_CONTEXT.md`'s
   knife held backwards, caught on the first look instead of the third round, exactly as design §6.3
   says it must be.

6. **Nothing about the Handle changed, so nothing downstream did.** Still `HANDLE_SIZE`, still
   `Tool.Grip`, still the `Muzzle` attachment the server reads for every shot, still the **only part
   of the gun a ray can hit**. The mesh is welded scenery: `CanQuery = false`, `CanCollide = false`,
   `Massless = true`. Verify: `assets_seam.spec`, `it("wears the mesh when there is one, and nothing
   about the Handle changes")`.

7. **Both paths are driven by injection, and the failures are exhaustive.** `Loader.setInsert`
   replaces the one call that touches the world. The spec drives the mesh being loaded and used, and
   **`insert-failed`, `contains-script`, `no-meshpart`, `multi-meshpart`, `aspect` and `no-row`** each
   ending with `Loader.template` returning nil and `Hardware.build` drawing Task 71's parts gun — so
   the player is never gunless.

8. **The viewmodel would have lost the texture, and the design said so first.** The uploaded gun
   carries its PBR maps on a `SurfaceAppearance` child; `Viewmodel`'s clone destroyed every
   non-`Attachment` child, so the **first-person** gun would have been untextured while the
   third-person one was fine — visible only in ADS, only to the player holding it, asserted by
   nothing. It now lets `SurfaceAppearance`, `Texture` and `Decal` through. Design §6.6 predicted this
   sweep and named the fix as the camera owner's, which is that file.

9. **Two older specs failed the moment the mesh loaded, which is the system working.** They asserted
   Task 71's ten parts on a Tool that now wears the mesh. They **ask** for the parts gun now
   (provider set to nil, then put back) rather than testing whatever happened to load; the client
   check takes either gun and asserts what is true of both — the envelope is the only invisible part
   and everything else shows, which a blank viewmodel still fails. `assets_seam.spec` borrows the live
   provider and restores it, so no spec can leave the running server wearing the grey box.

10. **`MapGen.Assets` is still the empty table it was.** This adds no second id table:
    `assets_seam.spec` asserts `#MapGen.Assets.ROWS == 0`. Moving `MapGen.Props` onto the Loader
    (design §6.8) is queued as 74a(a) — it changes what the map generator does and needs
    `mapgen verify`.

## Not verified

- **No ADS screenshot was caught.** The viewmodel path is asserted on screen by `camera_client.spec`,
  but nobody has *looked* at the mesh in first person (74a(c)).
- **The barrels read light silver in Roblox's daylight**, not the near-black of Task 72's Blender
  renders: the SurfaceAppearance's metalness reflects a bright sky. The albedo is what Karen asked
  for; the in-engine result is not, and the dial is the prep recipe's (74a(b)).
- **From directly behind, the gun is nearly edge-on** — 0.25 studs wide, pointing away — so the
  third-person camera shows a thin sliver plus a long shadow (74a(d)).
- **`LoadAsset` was exercised for real only in this Studio, on this account.** A server where it
  fails takes the fallback, which is asserted — but the real failure has not been seen.
- **`test2` was run by the Director, not by me** — the `[harness2]` line above is his, at this head.
  Two players each held the gun and the whole client suite ran on both sides.
