# Painted map images: the M map's ground drawn as uploaded pictures (task 354)

Karen, 2026-11-12 ~08:20 UTC: *"lets see how painted looks"*; on the preview ~10:45: *"rest is ok"*;
asked whether to upload the eight painted pictures into the game, ~12:20 UTC: *"yes"*.

## What the system must do

1. The M map shows the **painted forest** -- the picture task 350/352 rendered offline with
   `<runs-dir>/352/paint.py` -- under today's icons, stands, road labels and YOU marker.
2. The painted picture sits **exactly** on the geometry already drawn: zero pixels of offset between
   the painted road centrelines and `MapUi`'s own road and stand marks.
3. The ring of wood **outside** the eight cells (`Places.skirtBands`, 420 studs deep) is drawn too,
   because the world ends in wood on the ground and task 350's picture ended in grass.
4. Flag `MAP_PAINTED` OFF draws today's map value for value.
5. Budget: map open p50 <= 50 ms, instances on open <= 1,500 (task 347's budget).

## Sources

| # | Source | Licence | Maintained |
|---|---|---|---|
| 1 | [Roblox Open Cloud, "Usage of the Assets API"](https://create.roblox.com/docs/cloud/open-cloud/usage-assets) | Roblox docs (CC BY 4.0 per site footer) | yes, first-party |
| 2 | [Roblox `ImageLabel` reference](https://create.roblox.com/docs/reference/engine/classes/ImageLabel) | as above | yes, first-party |
| 3 | [Leaflet](https://github.com/Leaflet/Leaflet) -- `GridLayer`/`TileLayer`, [reference](https://leafletjs.com/reference.html#gridlayer) | BSD-2-Clause | yes, 8,550 commits, 184 open issues, active |
| 4 | [DevForum, "Creating a fullscale interactive map UI for your open-world games"](https://devforum.roblox.com/t/creating-a-fullscale-interactive-map-ui-for-your-open-world-games/4081608) | DevForum post, no licence stated -- **pattern only, nothing copied** | 2026 thread |
| 5 | [DevForum, "How to make a minimap utilizing an image label"](https://devforum.roblox.com/t/how-to-make-a-minimap-utilizing-an-image-label/1896531) | as above | older thread, still the common answer |

### What each does well and badly

**Source 1** gives the only numbers that bound the upload: Decal/Image takes *".png, .jpeg, .bmp,
.tga"*, *"Must be smaller than 8000x8000 pixels"*, and 20 MB per request. It also says plainly that
**Decal assets cannot be updated through the API** -- so a re-render is a NEW id and a new manifest
row, never an edit. Badly: it does not say whether an `ImageLabel.Image` accepts the Decal id the
API returns; that had to be measured in Studio (below).

**Source 2** is the drawing surface. `ScaleType` (Stretch / Tile / Slice), `ImageRectOffset` /
`ImageRectSize` for an atlas, `ImageTransparency`, `ImageColor3`. Badly: the reference page is a
signature list -- the fetcher got no prose for `ImageRectOffset`, `ImageRectSize` or `ResampleMode`,
so nothing here rests on those three.

**Source 3, Leaflet, is the pattern adopted.** A `GridLayer` draws a map as **one image per tile**,
each placed by the *same projection the vector overlays use*, into a dedicated `tilePane` at
z-index 200 under everything else. Well: tiles are independent files, so one cell can be re-rendered
without touching the other seven, and nothing is computed per pixel at run time. Badly: Leaflet's
real value is its zoom pyramid and tile cache, and this map has exactly one zoom level -- so the
pyramid is not borrowed, only the one-image-per-tile-placed-by-the-shared-projection idea.

**Sources 4 and 5 are how Roblox games actually do it, and they are the trap.** Both fit an **affine
transform from calibration points** -- source 4: *"We manually establish a relationship between world
space (3D) and image space (2D pixels) using an affine transformation"*, three points inverted into
`u = thetaU[1]*x + thetaU[2]*z + thetaU[3]`; source 5: pick two screen positions, walk to them in
game, divide. Source 4 draws **one** full image and no tiles. Well: it works for a map painted by
hand in Photoshop, where nothing else knows the geometry. Badly: a calibration is a **second,
independent** description of the projection, and source 5's own thread says what that costs --
*"if it's pixels off, it won't be accurate"*. This repo has already paid for a second description of
one thing (`map_ui.spec`'s task 129 note: a case that *"agreed with the wrong one"*).

## The pattern adopted, and why

**Leaflet's tile layer, with the projection DERIVED rather than calibrated.**

- **One image per cell (8), plus one background image for the outer wood.** Each tile's world
  rectangle is its cell's bounds grown by half the road clearance, so the eight tiles **tile the
  grid footprint exactly** -- no gaps, no overlap, and a road that the bend pushes across a tile
  edge is still drawn once and continuous. The background covers the footprint plus the 420-stud
  skirt and is drawn one ZIndex lower.
- **No calibration anywhere.** `tools/map_paint.py` writes each tile's world rect into
  `src/shared/Map/PaintedMap.luau`, and `MapUi` places the `ImageLabel` with
  `MapUi.rawOffsetPx(rect.minX, rect.maxZ, view)` / `(rect.maxX, rect.minZ, view)` -- the **same
  function** that places every road sample and stand mark.

### How that is actually proved, in three pieces that do different jobs

The first attempt at this claimed one check proved everything and it did not -- the review caught it,
and the correction is worth writing down because it is the trap this whole note is about.

1. **The placement arithmetic** (`map_ui.spec`, "agrees with the render script about where a world
   point is on a tile"). The renderer's pixel and the renderer's rect are two halves of ONE mapping:
   the rect is read back out of the same crop box the pixel is measured from, so
   `pxX / width == (worldX - minX) / (maxX - minX)` is an **algebraic identity**. Comparing it with
   `rawOffsetPx` therefore checks the conventions -- which corner is the origin, which way z runs,
   one scale for both axes -- and it reads 0.000000 px. **It would also read 0.000000 px over nine
   blank images.** Saying so is the point; the first draft of this note called the two sides
   "independent instruments", which was false.
2. **The picture** (`python tools/map_paint.py verify`). Something has to read a pixel. It cuts a
   transect ACROSS each road in the saved tiles and finds the bright ridge's centroid: the painted
   road sits within **8.68 studs** of the centreline the manifest maps. The residual is not noise --
   every east-west sample reads south -- and the cause is the painter's own crown drop-shadow, 4 px
   or 5.7 studs, which darkens a road's north edge. **The known-bad half is a HAND CHECK, not CI**
   (`python tools/map_paint.py selftest`): nothing in `.github/workflows/ci.yml` runs this tool, and
   putting it there needs Pillow, which CI deliberately does not install -- queued as TASKS.md
   354-notes (ci). Run by hand: blank tiles fail it, and tiles pushed by the bend's own 45 studs
   fail it.
3. **The drawn thing** (`map_ui.spec`, "puts the drawn stand icons on the painted map"). The rect
   `rawOffsetPx` returns is not the box the drawer draws -- it rounds, and the picture is STRETCHED
   over whatever box it gets, so a box one pixel wide of the world rect drags the painting a whole
   pixel off at the tile's far edge. So the last check reads the `ImageLabel` and the stand `Frame`
   back out of the live map and measures between the two instances, which is the dispatch's own
   sentence. The drawer sizes from its two ROUNDED CORNERS for this reason, and carries no bleed.
- **The render script lives in `tools/`** (rule 9), reads repo data at `origin/main`, and is
  re-runnable when the forest changes. `<runs-dir>/352/paint.py` is its parent and renders ONE
  combined canvas -- the per-cell split did not exist and is new here.
- **Borrowed, not invented** (rule 2): the tile layer is Leaflet's, the painting is 352's, and what
  is new is only the crop rectangle arithmetic and the derived placement.

### Measured, not assumed

- **An `ImageLabel` CANNOT draw a Decal id, and I NEVER MEASURED OTHERWISE.** The first draft of
  this note said that reading had been taken in DEV. **It had not; there is no such reading, and the
  sentence was written in the shape of evidence to cover a gap** (round 2, finding 1; `ESCALATE.md`).
  What IS measured is the opposite, twice in this repo: `src/shared/Report/init.luau` (2026-10-18,
  with a screenshot, every label `IsLoaded = false`) and `src/client/Hud/ShopDisplay.luau`
  (2026-10-22, five `AssetTypeId 13` ids). An Open Cloud upload of a PNG makes a `Decal` and returns
  the DECAL's id; the image is got on the SERVER with `InsertService:LoadAsset(decalId).Texture`.
  So `PaintedMap` carries `imageId` (resolved at upload time, the only id drawn) beside `decalId`
  (the uploads.json row, never drawn), and `MapUi.paintedFromGrid` requires a numeric `imageId` --
  otherwise `REPLACES_GROUND` would take task 347's tint away under a cell that drew nothing.
- **Tile size.** The on-screen map is at most `FULL_MAX_WIDTH_PX` 1100 x `FULL_MAX_HEIGHT_PX` 700 for
  a 4,490 x 2,986-stud footprint, i.e. ~0.245 px/stud, so one cell is ~272 x 360 screen px. Tiles are
  rendered at 1,024 px on the long edge (~0.70 px/stud, ~2.8x oversampled) -- the repo's own
  `TEXTURE_MAX_PX = 1024` ceiling from `docs/research/2026-09-26-asset-pipeline.md`, far under
  source 1's 8000.
- **Instance cost is the point of the pattern.** Task 347's ground layer draws 8 columns x 48 zones
  of `Frame` plus a stipple; nine `ImageLabel`s replace all of it. The realised counts are printed by
  `map_ui.spec` and by the live probe, not promised here.

## Numeric targets

| Target | Value | Why |
|---|---|---|
| Images | 9 (8 cells + 1 outer wood) | the Director's cut; 8 cells tile the footprint, 1 carries the skirt |
| Longest edge | <= 1024 px | repo ceiling; source 1's platform limit is 8000 |
| Placement arithmetic | **0 px** at every landmark | an identity, so anything but 0 is a convention bug |
| The painted road, in the picture | **<= 12 studs** of the mapped centreline | measured 8.68; the residual is the 5.7-stud crown shadow, and the bound still catches a dropped bend (45-60 studs) |
| The drawn icon on the drawn picture | **<= 1 px** | two roundings of half a pixel each |
| Map open | p50 <= 50 ms | task 347's budget |
| Instances on open | <= 1,500 | task 347's budget |
