# Review request — Task 241: the shop's goods, rebuilt to the Designer's approved spec

Task: 241
Round: 1
Base: `9acb7db606746586f6378d491aed4fe4c3a2649f` (main, the merge of task 240)
Code commit: `d3b15f012afd7c55990242ad95d0413a9e9bd7db`

```
[harness] PASS: 34/34 checks @ d3b15f012afd7c55990242ad95d0413a9e9bd7db (clean tree) scope=all
```

`test2` is **N/A**: not one changed path is in `TWO_PLAYER_PATHS`. The change is
`src/client/Hud/ShopDisplay.luau`, `src/client/Hud/ShopPanel.luau`,
`tests/client/shop_panel.spec.luau`, `assets/uploads.json` and three docs — the HUD, which
behaves the same with one player as with two.

## What changed

Karen, 2026-10-22: *"Slug shells has to be more releastic and package smae with unlimited ammo /
All things like beater license Deer license has to be clear and nice"*, and *"now it's good"* to
the Designer's r2 target. The spec is `<runs-dir>/design/goods-spec.md`; the target is
`goods-mockups.png` beside it.

The one engine fact it turns on: **a `Decal` renders inside a `ViewportFrame` and a `SurfaceGui`
does not**. That is why every printed line in these drawings used to be a 3-px `Part`, and it
splits the four items: things you HOLD stay 3-D with real labels, things you are ISSUED become flat
images over the case.

Four PNGs of our own art were uploaded (Karen's OK is recorded verbatim against each row in
`assets/uploads.json`), all `Approved`. `buildLicence`, `licenceShell`, `deerFurniture`,
`beaterFurniture`, `horn`, `LEAF`/`leaf`/`onLeaf`, `BOOK_VIEW`, `buildSlugCarton`'s `CARTON_X` /
`CARTON_Z` / `LID_PRINT` / `LOOSE_SHELL` / `turned`, `buildBandolier` with `BELT_RX` / `BELT_RZ` /
`BUCKLE`, and the 21 palette hexes they were the only readers of, are archived under `backups/`
with a logged reason (rule 7).

## Claims

1. **Every id in the code is the IMAGE id and not the DECAL id.** An Open Cloud PNG upload creates
   a Decal (`AssetTypeId 13`) and returns the DECAL's id, which neither an `ImageLabel` nor a
   `Decal.Texture` can draw — the trap `src/shared/Report/init.luau` records from task 205. All
   four were resolved on the server with `InsertService:LoadAsset(decalId).Texture` in DEV on
   2026-10-22. **Verify:** `ShopDisplay`'s `ART` table carries the four `rbxassetid://` image ids
   and its header records both halves of each pair; `assets/uploads.json` carries the four DECAL
   ids; `shop_panel.spec`'s case *"points at the IMAGE behind each upload, not the decal"* asserts
   each id and asserts that none of the four decal ids appears in any of them.

2. **The slug carton is the Designer's section 3.1: 14 parts and 2 `Decal`s**, where the ten-round
   open tray was 66. One closed five-round carton, its lid band, and two loose rounds of six
   coaxial cylinders each. **Verify:** `buildSlugCarton` and `carton` / `shell` / `ROUND` in
   `ShopDisplay`; `shop_panel.spec` asserts `1 + 1 + 2 * 6`.

3. **`UNLIMITED AMMO` is the same carton stacked, which is Karen's own instruction taken
   literally** (*"package smae with unlimited ammo"*): a shipping slab, seven of the identical
   carton with their lid bands, and the same two rounds — **27 parts and 14 `Decal`s**, reusing the
   same two uploaded images and needing no new upload. **Verify:** `buildAmmoStack`;
   `shop_panel.spec` asserts `1 + 7 + 7 + 2 * 6`, and asserts the stack carries exactly **two
   distinct textures, each used seven times**.

4. **The print is on the wall the camera is on.** `Enum.NormalId.Front` is `-Z`; `SOLID_VIEW`
   stands the camera at yaw 34, so it looks from `+x / +z` and sees `+Z` = `Back`, with `+X` =
   `Right` as the end. `buildAmmoCrate` stencilled `-z` two tasks ago and nobody ever saw it — a
   fault no frame of the front can show, which is why it is a spec. **Verify:** `carton`'s `decals`
   keys; `shop_panel.spec` asserts `faces.Back == 1`, `faces.Right == 1`, `faces.Front == nil`,
   `faces.Left == nil`.

5. **A round is six coaxial cylinders aimed by rotating the part's X axis**, which is a `Cylinder`'s
   own axis — the mesh-frame mistake class of tasks 188–190. `shell` reads the step direction off
   the very `CFrame` `place` will build (`.RightVector`), so there is no second copy of the
   trigonometry. **Verify:** `shop_panel.spec` measures the DRAWN parts: the standing round's
   `RightVector.Y ≈ 1`, its crimp above and its primer below the hull, its `CrimpTop` BRIGHTER than
   the hull (which is the whole fix for *"slugs itself looks odd"* — a darker disc is how you draw
   the mouth of an open tube); the lying round's `RightVector.Y ≈ 0`, its rim nearer the camera
   direction than its crimp (yaw 186, not −16), and its centre one radius above the shelf.

6. **An item has a viewport MODEL or a flat IMAGE, never both and never neither.** The two licences
   leave the viewport because a document has to be READ, and at a 356 × 200 case a `Decal` pitched
   25° cannot carry body type (`goods-spec.md` section 4 states the all-3-D alternative and refuses
   it). **Verify:** `ShopDisplay.imageFor` beside `ShopDisplay.build`; `shop_panel.spec`'s *"has a
   picture for every row it sells"* asserts exactly one of the two for every row in `Shop.ORDER`,
   and the viewport case asserts selecting a licence leaves **zero** models behind the glass.

7. **Section 3.5 is ONE function, so the next screen to show a licence inherits all of it.**
   `ShopDisplay.dressLicenceImage` writes `Rotation = 0`, `ScaleType.Fit`, `ImageTransparency = 0`,
   `BackgroundTransparency = 1`, `ResampleMode.Default` and centred anchor/position; nothing in
   `ShopPanel` writes any of them. **Verify:** `buildCase`'s `Document` label;
   `shop_panel.spec` asserts all seven on the real control AND asserts the function corrects a
   hand-dressed label. **The "everywhere" is MEASURED, not assumed:** `src/client/Hud/LicenceCard.luau`
   (task 238's popup) is a title, a sentence and two buttons with no image in it, and the start
   card's licence row is a drawn glyph plus text plus `START_CARD_LICENCE_TAG` (`Hud.init`'s
   `quarry` loop) — also no image. So the shop case is the only place a licence image appears
   today, and that is said in `ShopDisplay`'s own header rather than left to be rediscovered.

8. **Never below 150 px wide.** `ShopDisplay.licenceFits` is pure; `ShopPanel.fitDocument` is its
   one application, called after every layout and every selection and never per frame. A width of
   0 or 1 is *"the engine has not drawn a frame yet"* and not *"too small"*. **Verify:**
   `shop_panel.spec` drives `licenceFits` at the boundary and at 0, and asserts the real case
   clears it at the size it is actually drawn.

9. **A licence inside a package still draws, so `THE FULL SEASON` has no hole.** `build` draws a
   single thin card carrying the same image when, and only when, the caller says `IN_PACKAGE` —
   the `"lite"` word that already meant *this is a thumbnail inside a package*, now with that as
   its one meaning. Its height is the art's own 1.79 : 1 and not section 4's rounded `1.00`,
   because a `Decal` stretches to its face. **Verify:** `buildLicenceCard` and the `DRAW` rows;
   `shop_panel.spec` asserts every covered row of every bundle builds under `"lite"`, and that a
   licence is 0 parts in the case and exactly 1 inside a package.

10. **`viewportId` is what the CASE is showing, not what model is in the viewport**, and since this
    task those are two questions. It is set for both kinds and still nil for an id this module does
    not draw, so `setOpen`'s *"is the case already showing the selected row"* stays one comparison
    and cannot go on rebuilding a picture that is already there. **Verify:** `ShopPanel.showPicture`;
    `shop_panel.spec` asserts `pictureId()` for a licence and `pictureModel() == nil` for the same
    selection.

## Measured, on the player's own path

In the **Forest Test** (the only place with a shop counter), read-only under the Director's standing
block: its `ServerStorage` attributes were read before and after and are **identical**
(`DHFlag_SHOP=true DHFlag_LOBBY=true DHShopTestGrant=true …`). The shop was opened with the real `E`
on the real shopkeeper's prompt and the rows were clicked with real mouse input.

| Item | Measured in Play |
|---|---|
| `SLUG SHELLS` | 14 parts, 2 `Decal`s, **both `AssetFetchStatus.Success`** |
| `UNLIMITED AMMO` | 27 parts, 14 `Decal`s, **all 14 `Success`** |
| `BEATER LICENCE` | 0 parts; document `IsLoaded = true`, `Success`, visible, 334 × 182, `Rotation = 0`, `Fit`, `ImageTransparency = 0.00` |
| `DEER LICENCE` | the same, with `imageFor` = `118076983085725` (the deer image, confirmed off the live label) |
| `THE FULL SEASON` | **17/17 `Decal`s loaded** — 14 stack + 2 carton + 1 licence card |
| `RIFLE, SCOPED` | 5 parts, document hidden, `Image = ""` |

Frames looked at (rule 5), each at the recorded viewport yaw, cropped to the case and zoomed 3×:
`241-slug-42-case3x.png` (yaw 30.7), `241-ammo-27-case3x.png` (yaw 34.3),
`241-beater-00-case3x.png`, `241-deer2-00-case3x.png`, `241-season-43-case3x.png` (yaw 37.8), plus
the full panel at `241-deer2-00.png` and `20261022T111318Z-241-ft-ammo-slug.png`. Compared with
`goods-mockups.png` tile for tile: the carton, its label, the standing round left of the box and the
lying round with its primer to the camera all match the target's close-up, and both licences read —
title, bearer, ground/season, serial, stamp, and the deer's `☑ STAG ☑ HIND ☑ CALF` and `07·114` tag.

**The five new spec cases were run against the PRE-CHANGE source first** and all five failed on the
right lines (`<runs-dir>/241-pre-change-spec-failures.txt`): the licence still built a viewport
model, `documentImage` and `imageFor` did not exist, and the carton was 66 parts.

## What I could not verify

1. **Karen has not seen it.** The frames are mine. Her sentence is the acceptance test
   (*"nothing in that run should look broken comapiring with weapons"*), and only she can say it.
2. **The frames are 947 × 785, not the Designer's 1280 × 720**, because that is the Studio window
   this machine has. The case itself is the real 356 × 200 and the document the real 334 × 182, so
   what is drawn is at the shipped size; only the surrounding window is smaller. The crops are 3×
   nearest-neighbour so the pixels that land are the ones you see.
3. **The viewport SPINS, so a frame catches an arbitrary yaw.** I captured a full revolution and
   kept the frames nearest the spec's yaw 34, reporting each frame's measured yaw rather than
   assuming it. There is no way to pin the angle without a second writer of the camera.
4. **`THE FULL SEASON`'s board is framed as a long diagonal that runs out of the case.** That is
   **pre-existing and unchanged** — `.screenshots/228-after-bundle-season.png` shows the same
   framing before this task — and the licence card inside it draws correctly. Not fixed here,
   because the bundle's staging is not this task.
5. **The phone layout was not photographed.** `ShopPanel.fitDocument` and `licenceFits` are
   asserted pure and at the boundary, and the inset is written as an inset rather than two fixed
   numbers, but no frame was taken at a width where the rule actually hides the image.
