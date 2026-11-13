# Task 359 -- the nine painted map tiles into the game (the ids)

Task: 359
Round: 1
Base: fbf3bf9b (origin/main)
Code commit: e4b50d48c288339ac0e1478aaef5b2d6edeef77a

Harness, clean tree, at the code commit:

```
[harness] PASS: 34/34 checks @ e4b50d48c288339ac0e1478aaef5b2d6edeef77a (clean tree) scope=all
```

`[harness2]` is N/A: nothing here touches the match, the drive, the tie or the teams
(`TWO_PLAYER_PATHS`). The change is one data file, one generated manifest and one tool selftest.

## What changed

1. `assets/uploads.json` -- the nine Decal rows the Director's upload wrote, applied verbatim from
   `<runs-dir>/359-uploads.json`. Nothing was re-uploaded here.
2. `assets/ready/map/asset-ids.json` (new) -- the nine `{decal, image}` pairs.
3. `src/shared/Map/PaintedMap.luau` -- rewritten by `map_paint.py render --ids`: 18 id lines, no
   logic change, the nine PNGs byte-identical before and after.
4. `tools/map_paint.py` -- one selftest assertion: the shipped manifest is compared against the
   **committed** ids file instead of a hardcoded `{}`.

## Claims

1. **The nine rows are the Director's own upload output, unaltered.** `git show e4b50d48~1 --
   assets/uploads.json` is the saved `<runs-dir>/359-uploads-rows.diff` (180 added lines, none
   removed). Every row says `"assetType": "Decal"`, `"moderationState": "Approved"`.
2. **Each row's bytes are the committed picture's bytes.** `sha256sum assets/ready/map/*.png`
   equals the `sha256` of the row with the same `file` -- nine for nine.
3. **No secret.** `python tools/privacy_scan.py selftest` then `scan`: 26 shapes caught, 23 allowed
   forms clean; `PASS: 0 findings in 1505 tracked text files`.
4. **9 of 9 decal ids resolved on the server, by the route ESCALATE names.**
   `<runs-dir>/359-assetid.py` ran `InsertService:LoadAsset(id)` in DEV (`game.PlaceId` confirmed):
   `MarketplaceService:GetProductInfo` says `type=13` (Decal) with the right name for all nine, and
   each one hands back one texture:
   A1 135667574051998->107857152970642 · A2 87409889528750->109920061059050 ·
   B1 79562321806238->88105522318562 · B2 75767827417628->110432674511729 ·
   C1 122343736914152->136803921093660 · C2 86559492704868->129920561232978 ·
   D1 111943313939065->88084526779597 · D2 136380820684632->107528269441496 ·
   WOOD 117507970509664->80741860013708. Nine distinct image ids, none equal to its decal id.
   `assets/ready/map/asset-ids.json` carries exactly those pairs, and `PaintedMap.luau` carries them
   in `decalId`/`imageId`.
5. **The drawer's own filter returns the IMAGE ids.** In DEV Play a client probe
   (`<runs-dir>/359-probe-painted.luau`) called `MapUi.paintedFromGrid(PaintedMap)` on the REAL
   module: 9 rows, background (`WOOD`) first, each `image=` the resolved id above, `NO_ASSET=0`.
6. **All nine ids really load as pictures.** `<runs-dir>/359-probe-tiles.luau` put each
   `tile.imageId` in front of an `ImageLabel` on a red ground and preloaded them: `loaded 9 of 9`,
   `IsLoaded=true` for every one. Frame
   `.screenshots/20261113T114511Z-359-dev-nine-image-ids.png`, opened: eight tall forest tiles --
   dark green crowns, a pale road band down one edge, orange autumn patches -- and the wide WOOD
   tile showing the eight-cell patchwork. No label is blank red. **This is a probe's own ScreenGui,
   not the map** (DEV ONLY), and is named as that and nothing else.
7. **The M key is unchanged and opens the map, pressed for real.** DEV Play, `313-clientkey.ps1`
   (real click into the viewport, then `keybd_event` with the scan code) sent one `M` at pid 11924:
   before, `FullMap(vis=false) MapScrim(vis=false) MiniMap(vis=true)`; after,
   `FullMap(vis=true) MapScrim(vis=true) MiniMap(vis=false)`. Frame
   `.screenshots/20261113T114632Z-359-dev-map-OPEN-after-M.png`, opened: the full map panel is up
   over the DEV world, headed `MAP / map:v1`, with the DEV road, the `YOU` dot on it, the N
   compass, the 200 m scale and the ROAD/STAND/GO HERE/YOU/HUNTER/BEATER legend.
8. **DEV CANNOT SHOW THE PAINTED TILES, and the frame is not named as if it could.**
   `MapUi.geometryFor` builds the painted layer only inside `if world == "forest-test"` (and only
   for a grid cell layout); `Map.WORLD_BY_PLACE` makes DEV `map:v1`. So with `MAP_PAINTED` ON in
   DEV (`flags.py set MAP_PAINTED on`, cleared afterwards -- DEV only, Karen's Forest Test never
   addressed; her Studio was in **Edit** throughout) the M map is byte-for-byte the map of
   claim 7: no tile, no blank tile, nothing changed. **The painted forest aligned with the stands
   is NOT PROVEN on screen.** It needs the forest-test world, and Karen is awake.
9. **`imageId` 0 still keeps the ground, and the guard still bites.**
   `tests/client/map_ui.spec.luau` -- "draws the IMAGE id, and a tile with only a Decal id paints
   nothing and keeps its ground" -- passes in the run above (715 client assertions, 0 failed). It
   builds its own tiles from `uploaded()`, so the real ids do not weaken it: arm 1 (`imageId` nil)
   still drops the tile and keeps its ground band, arm 2 draws `rbxassetid://<IMAGE>`. Its guard is
   `MapUi.paintedFromGrid`'s `type(imageId) == "number" and imageId ~= PAINTED.NO_ASSET`.
10. **The manifest is still the generator's output, and the check that says so still fails on a
    hand edit.** `python tools/map_paint.py selftest` -> `PASS: 40 checks, 0 failed`. Against the
    old hardcoded `{}` it read FAIL on this correct file (task 354 round 3 predicted exactly that);
    with the fix, changing one digit of `imageId` in `PaintedMap.luau` puts it straight back to
    `FAIL: 40 checks, 1 failed`, measured both ways.

## What I could not verify

- **The painted map drawn in the game** (claim 8): not reachable in DEV by any path, and the Forest
  Test is Karen's while she is awake. `MAP_PAINTED` ships OFF, so nothing is lit by this merge.
- **The 0 px alignment of tiles with stands and icons** is task 354's arithmetic over the same
  rects; no id changed a rect here (`git diff` touches `decalId`/`imageId` lines only).
- Pass 1 of the proof sent one left click to screen point 960,620, which is **outside** the DEV
  window (it sits at x 1273..2567) -- so that click, and the `M` after it, went to whatever window
  lay under that point, most likely the Forest Test Studio, which `studios` shows was in **Edit**
  (not Play) the whole session. Pass 2 read the window rect and clicked inside it. Nothing in that
  place was opened, played or flagged by me.
