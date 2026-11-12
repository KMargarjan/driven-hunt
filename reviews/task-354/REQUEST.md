# Task 354 -- the painted map in the game, behind `MAP_PAINTED` (born OFF)

Task: 354
Round: 3
Base: 8cc53d35 (origin/main)
Code commit: fb453e710b7a9e31f50e72315138d5f625829435

```
[harness] PASS: 34/34 checks @ fb453e710b7a9e31f50e72315138d5f625829435 (clean tree) scope=all
```

`test2` is **N/A**: nothing here touches `TWO_PLAYER_PATHS` (the change is `MapUi`, `PaintedMap`,
`map_paint.py`, one client spec and paperwork).

Round 3 was authorised by the Director, 2026-11-12 22:05 UTC, and the authorisation is recorded in
`ESCALATE.md` under the round-2 entry. It fixes round 2's two findings and the notes that were
one-line comment fixes. **Nothing else changed**: no upload (the Open Cloud key is still refused --
`ESCALATE.md` NEEDS KAREN), `MAP_PAINTED` still OFF everywhere, `ci.yml` untouched.

## Claims

1. **The drawn id is the IMAGE's, not the uploaded Decal's** (finding 1). `PaintedMap.Tile` now has
   `imageId` -- resolved at upload time with `InsertService:LoadAsset(decalId).Texture`, the route
   `src/shared/Report/init.luau` and `src/client/Hud/ShopDisplay.luau` both record and ship -- beside
   `decalId`, which is kept for the `assets/uploads.json` row and never drawn. Verify: the manifest's
   own header; `MapUi`'s drawer in `drawGeometry` formats `tile.imageId`; `MapUi.PaintedTile` has no
   `assetId` field, and `grep -rn assetId src/client/Hud/MapUi.luau src/shared/Map/PaintedMap.luau`
   is empty.
2. **An unresolved tile paints nothing AND keeps task 347's ground.** `MapUi.paintedFromGrid`
   requires `type(tile.imageId) == "number"` as well as `~= PAINTED.NO_ASSET`, so a row that carries
   only a `decalId` is dropped before `paintedCells` can claim its cell. Verify: the new case
   `tests/client/map_ui.spec.luau` -> "draws the IMAGE id, and a tile with only a Decal id paints
   nothing and keeps its ground". Measured, both arms, at this code commit:
   `map_ui 354 decal-vs-image: decal only -> 8 image(s), 56 band(s) for C1, 0 decal id drawn;
   resolved -> 9 image(s), 0 band(s), rbxassetid://922222` -- the decal id (811111) is never put in
   front of an `ImageLabel`, and the resolved arm draws the image id and stands its tint down.
3. **FAIL FIRST, run and pasted.** With `type(imageId) == "number"` deleted from
   `paintedFromGrid` and nothing else changed, the suite went red on the new case's first assertion
   (the decal-only tile is not dropped: 9 tiles instead of 8):
   `failed [client] map_ui.spec:3055 Expected value "8" (number), got "9" (number) instead`, client
   `703 passed, 1 failed, 1 errors` (that run also recorded one error, which I did not capture
   before re-running -- the drawer formatting a nil id is the expected shape of it). The guard was
   restored before the code commit, and `[harness] PASS: 34/34 @ fb453e71 (clean tree) scope=all`
   is the same suite with it back.
4. **`map_paint.py` refuses a bare id, because a bare upload id is the decal's.** `read_ids` takes
   `{"C1": {"decal": <uploaded>, "image": <resolved>}}` and raises `Refused` on a bare number.
   Verify: `python tools/map_paint.py selftest` -> "a bare asset id in the ids file is refused as the
   DECAL's", "a paired row reads back as (decal, image)", "the manifest writes the decal id it is
   given", "...and the resolved image id beside it".
5. **The committed manifest is the generator's own output.** `PaintedMap.luau` says "EDIT THAT, NOT
   THIS", so the selftest now compares the file on disk with `manifest_luau(..., {}, ...)`: a hand
   edit fails it. Verify: the selftest check "src/shared/Map/PaintedMap.luau is this generator's own
   output". The nine rects, pixel sizes, `VERSION` and `PX_PER_STUD` are byte-identical to round 2's
   (`git diff de6330d8..HEAD -- src/shared/Map/PaintedMap.luau` touches the header and the two id
   fields only).
6. **"In CI" is struck and called a hand check** (finding 2). The claim is gone from this request,
   from the spec comment under the alignment case and from the research note; each now says the
   known-bad half of `map_paint.py verify` runs **by hand**. The real fix is queued as
   `TASKS.md` -> `354-notes (ci)`, with the Pillow problem written down. **`ci.yml` is not touched by
   this task.** Verify: `grep -rn "in CI" tools/map_paint.py tests/client/map_ui.spec.luau
   docs/research/2026-11-12-painted-map-images.md reviews/task-354/REQUEST.md` and
   `git diff de6330d8..HEAD -- .github/` (empty).
7. **The false "Measured" sentence is replaced by what was really measured.** The research note's
   "Measured in Studio on the DEV place ... the reading is in `reviews/task-354/REQUEST.md`" is gone;
   in its place the note says plainly that the reading was never taken, names the two measurements
   that say the opposite (`Report` 2026-10-18, `ShopDisplay` 2026-10-22) and states the resolve
   route. Verify: the note's "Measured, not assumed" section.
8. **`ESCALATE.md`'s finishing instruction is corrected.** The upload entry said "with no code
   change ... **No `src/` logic changes**". It now carries the resolve step, the paired
   `asset-ids.json` shape, and what `imageId = 0` means since this round. Verify: that entry.
9. **Round 2's one-line comment notes.** The spec's describe header no longer calls the two sides
   "different instruments" and reads 63 landmarks, not 83; `cmd_render`'s "two independent
   instruments" sentence is corrected the same way; the four gapped comments in `map_paint.py`
   (`TRANSECT_HALF_STUDS`, `landmarks`, the crown shadow, the bend) have their missing words; the
   `worstZ >= Z_INDEX` assertion says it is a tripwire for a future positive `PAINTED.Z_BELOW`.
   The other notes are queued, not taken (the per-axis drawn bound, `canvas_px`, `docs/design/map-ui.md`).
10. **The flag is still OFF and nothing is uploaded.** `Flags.isOn("MAP_PAINTED")` default `false`,
    all nine rows `decalId = 0, imageId = 0`, `assets/uploads.json` unchanged.

## What I could not verify

- **Nothing in this change has been seen in the game, and that is unchanged from round 2.** With no
  ids, no `ImageLabel` can draw a picture, so there is no flag-ON frame and rule 5 is **N/A with the
  reason** (`ESCALATE.md` NEEDS KAREN: the Open Cloud key answers `401 Invalid API Key`). The
  decal->image route itself is adopted from two recorded measurements in this repo, **not measured
  here** -- there is still no decal id of these nine to resolve.
- The alignment table remains the same arithmetic on both sides; it proves the convention, not the
  picture. `map_paint.py verify` (8.68 studs, blank and bend-shifted tiles both failing) is the
  picture's check and runs by hand.
