# Task 74 — M2.7a: the id → Instance seam, and Karen's shotgun is the gun

Task: 74
Round: 2
Base: `main` (`f3f6a49`)
Code commit: `8d2b809ef18b081497d6704a93e5d79cee6a70d1`

```
[harness] PASS: 30/30 checks @ 8d2b809ef18b081497d6704a93e5d79cee6a70d1 (clean tree)
```

`test2` matters for this change — it touches `src/` and `tests/client/` — and the Director runs it at
this branch's head; this request is updated with the `[harness2]` line for the same commit before the
review. Only paperwork (this file and `TASKS.md` rows 74/74a) follows the code commit.

**Round 1's three findings were all real and all fixed.** Two were the same mistake at two layers: a
spec that borrowed shared state and did not put it back. One of them has a consequence I have to own —
`withLoader` destroyed the live template, so **round 1's in-game screenshots were of the fallback
parts gun, not the mesh**. The pictures are retaken and described below.

**What changed.** New `src/serverstorage/Assets/init.luau` (the manifest) and `Loader.luau` (the
seam), new `tests/server/assets_seam.spec.luau`; `Weapon.Hardware`, `WeaponBoot`, `Camera.Viewmodel`,
`weapon_look.spec` and `camera_client.spec` changed. **400 server specs** (390 before: ten new),
**85 client** (one new).

## Claims

1. **The seam is the design's, not a new one.** `docs/design/asset-pipeline.md` §§4–5 specify the
   manifest's interface (`VERSION`, `ROWS`, `KEYS`, `byKey`, `describe`, `keysFor`) and the Loader's
   (`setInsert`, `setCacheParent`, `preload`, `template`, `stats`, `clear`, a `LoadReport` with a
   named reason). Both are built to that, so the owner rows Task 73 put in `GAME_DESIGN.md` now
   describe things that exist. Two documented deviations are listed in `TASKS.md` 74a(g) for the
   Architect; three unbuilt §5 members are 74a(h).

2. **Boot cannot wait on the network, and it is now true two ways over (finding 1).**
   `WeaponBoot` calls `Weapon.start()` **before** anything touches the network, so a stalled
   `LoadAsset` gives the parts gun rather than no weapon system — round 1 claimed that in a comment
   and it was only true if `preload` returned. And `preload` is now bounded as design §5.2 requires:
   `LOAD_TIMEOUT_S = 10` per key, `PRELOAD_BUDGET_S = 20` for the whole call, reason **`timeout`**.
   `LoadAsset` cannot be cancelled, so the load runs in its own thread and the caller stops *waiting*
   at the deadline; a late arrival is **adopted** if the key is still empty, so a slow load is late
   rather than lost. Verify: `assets_seam.spec`, `it("gives up on a load that never returns, and says
   timeout")` — an injected insert that loops forever — and the run note
   `loader timeout: gave up after 10.0 s (bound 10 s)`.

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
   knife held backwards, caught on the first look instead of the third round, as design §6.3 says it
   must be.

6. **Nothing about the Handle changed, so nothing downstream did.** Still `HANDLE_SIZE`, still
   `Tool.Grip`, still the `Muzzle` attachment the server reads for every shot, still the **only part
   of the gun a ray can hit**. The mesh is welded scenery: `CanQuery = false`, `CanCollide = false`,
   `Massless = true`. Verify: `assets_seam.spec`, `it("wears the mesh when there is one, and nothing
   about the Handle changes")`.

7. **Both paths are driven by injection, and every failure ends in a gun.** `Loader.setInsert`
   replaces the one call that touches the world, and the spec drives the mesh being used plus
   **`insert-failed`, `contains-script`, `no-meshpart`, `multi-meshpart`, `aspect`, `no-row` and
   `timeout`**, each ending with `Loader.template` nil and `Hardware.build` drawing Task 71's parts
   gun. Two cheap notes are in: `Hardware.addMesh` no longer falls through with a silent `return
   true` for a template class it cannot scale — it destroys the clone, warns once and returns false,
   so an unhandled class is the parts gun rather than an invisible gun; and `Loader.aspectOf` sorts
   all three axes, because the old version dropped every axis *equal* to the longest and failed a cube
   for arithmetic reasons.

8. **The viewmodel keeps the gun's appearance, and that is now asserted (finding 2).**
   `camera_client.spec`, `it("keeps the appearance of the gun it clones, and still strips everything
   else")` injects a `MeshPart` handle carrying a `SurfaceAppearance`, a `Texture`, a `Decal` and an
   `Attachment` plus a `Weld`, a `Sound` and a `Folder`, and asserts the first four survive the clone
   and the last three do not — on a welded piece as well as on the root. It waits past the
   source-refresh interval first: the viewmodel asks its source four times a second, not every frame,
   so a single update rebuilds from the *previous* handle, which is how the first version of this test
   read the live gun and wrongly reported no `SurfaceAppearance`. It borrows the live source through
   the new `Viewmodel.getSource` and puts it back, because `setSource(nil)` does not restore what
   `CameraBoot` set — it ends it. Design §6.6 predicted this sweep and named the fix as the camera
   owner's, which is that file.

9. **The spec no longer eats the live cache, and it proves the server still has a gun (finding 3).**
   `withLoader` called `Loader.clear()` **before** `setCacheParent`, so every case destroyed the real
   template `WeaponBoot` had preloaded and nothing put it back: the server wore the grey box for the
   rest of the session, and round 1's in-game captures were of the fallback gun. The throwaway
   container is nominated **first** now, so `clear()` can only reach what the spec made, and a final
   case — `describe("the live server after this file has run")` — builds a real Tool, asserts it is
   wearing the mesh **or** the parts gun (never neither) and says which in a note: the run reads
   **`the live server is wearing Karen's mesh`**. Two older specs that assumed Task 71's ten parts now
   **ask** for the parts gun (provider set to nil, then restored) rather than testing whatever
   happened to load.

10. **`MapGen.Assets` is still the empty table it was.** This adds no second id table:
    `assets_seam.spec` asserts `#MapGen.Assets.ROWS == 0`. Moving `MapGen.Props` onto the Loader
    (design §6.8) is queued as 74a(a) — it changes what the map generator does and needs
    `mapgen verify`.

## The ADS screenshot, taken in Play and looked at (rule 5)

`.screenshots/20260926T231103Z-task74-ads2-44.png`, first person, aiming: the gun seen from behind
the stock — **walnut with its grain clearly textured** filling the lower frame, the silver/blue action
with its top lever and hinge, the pale standing breech above it, and the barrels foreshortening away
to a small pale shape at the top, because the camera is looking straight down them. **No untextured
or purple surface anywhere**, which is the evidence finding 2 asked for. Honest caveats: the action
and the stock's edges carry a **blue cast** — the SurfaceAppearance's metalness reflecting the sky —
and the gun is centred pointing away, so it reads as a sight picture rather than a flank view. That
framing is the same geometry as Task 71's ADS, already queued as 71a(b). Nothing clips into the camera.

## Not verified

- **The barrels read light silver in Roblox's daylight**, not the near-black of Task 72's Blender
  renders, and in ADS the metal takes a blue cast from the sky. The albedo is what Karen asked for;
  the in-engine result is not, and the dial is the prep recipe's (74a(b)).
- **From directly behind, the third-person gun is nearly edge-on** — a thin sliver plus a long
  shadow, because the barrels point away from the camera (74a(d)).
- **`LoadAsset` was exercised for real only in this Studio, on this account.** A server where it
  fails takes the fallback, which is asserted — but the real failure has not been seen.
- **The `timeout` bound is measured at 10.0 s in the harness, but no real `LoadAsset` has ever
  hung.** The case that proves the bound is an injected loader that never returns; the deliberate
  gap is that it asserts nothing about the shared cache, because `WeaponBoot`'s own preload can land
  inside that 10 s wait — asserting on it would be asserting a race.
- **`test2` is the Director's run**, pasted above this review.
