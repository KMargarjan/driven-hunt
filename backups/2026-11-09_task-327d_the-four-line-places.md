# 2026-11-09, task 327d — the four line places leave the rotation, and `GRID_PREVIEW` retires

Rule 7: nothing here is deleted. This note says what left the live path, where it still lives, and
how to put it back.

Karen, 2026-11-08: *"so rest part of map we can remove we can only focus on those what we have from
A1 ect"* and *"we only load one per game thats it"*; earlier, *"once I am driver ended with line I
wait untile hunt ends? its shit boring"*.
Design: `docs/design/grid-map.md` D-4 and the 327d row; `docs/design/cell-loading.md` 13 D1, 17 D-4.

## 1. The four line places — `road`, `edge`, `ride`, `track`

**Nothing was removed.** `ForestTest.LAYOUTS` still holds all four rows, value for value, and
`forest_stand.spec`'s *"leaves the ROAD layout exactly as it was before task 179"* still asserts
eleven of the road's numbers. `Places.PLANS` and `Places.SURFACES` still hold their planting recipes
and `places.spec` still asserts every one of them — it loops the new `ForestTest.LINE_PLACES`
instead of `LAYOUT_ORDER`, which is the only thing that changed about those cases.

What changed is the **rotation**: `ForestTest.LAYOUT_ORDER` was
`table.freeze({ "road", "edge", "ride", "track" })` and is now `Grid.PLANTED_CELLS`
(`C1, C2, A2, B1, D1, B2, D2`).

**THE ROLLBACK IS AN ATTRIBUTE AND NO LONGER A COMMIT.** `DHForestLayout=road` on `ServerStorage`
in Edit promotes the road for every drive of the session (`ForestTest.forcedLayout` accepts a line
place name and a cell id alike). It costs no commit and no harness run.

**The two things that rollback no longer carries, measured and said rather than discovered:**

1. **No planted wood.** `Places.build` runs at boot, before any override is read, and its loop over
   `LAYOUT_ORDER` is guarded by `Forest.layoutNamed(name)`, which is nil for every cell — so the
   9,105 parts of `Workspace.DrivePlaces` are not built at all. A forced `road` drive gets the
   road's stands, markers and high seats on Karen's own `OurForest` / `Session` trees, with no
   `DrivePlaces` wood between them.
2. **The drive script outlasts the walk.** The four places share 580 studs of beater depth; at the
   new 5.2 studs/s that walk is ~115 s, and the drive script's last slot is due at 192 s. So a
   forced rollback drive ends (on the beaters' crossing) before its own script finishes.
   `forest_stand.spec` asserts that inequality rather than leaving it to be found.

To restore the old rotation in one line: `ForestTest.LAYOUT_ORDER = table.freeze({ "road", "edge",
"ride", "track" })`. `grid.spec`'s *"deals ONLY the planted cells, never a line place and never A1"*
is written to redden on exactly that edit (lesson L-093), so the revert is loud.

## 2. `GRID_PREVIEW` — retired

The flag row is removed from `src/shared/Flags/init.luau` and `Flags.MAX_FLAGS` goes 24 → 23.
It shipped at task 327a to build the grid's cells beside the live line-place world. There is no
second world any more: every drive is dealt in a cell, so a flag that chose between them has nothing
left to choose. `cell-loading.md` 17 D-4 leaves the timing to the Director, and this is it.

The losing branch — **the preview OFF path** — is what is archived, and it is three things:

- `Places.GRID_FLAG = "GRID_PREVIEW"` and `Places.gridPreviewEnabled()`, the one reader. With them
  goes `src/server/Places/init.luau`'s `Flags` require, so that module now reads no flag at all —
  and `tools/terrainbake.py`'s `FLAGS_STUB` (an injected `Flags` that errored on every access, to
  prove the prebuild asked it nothing) goes with it, replaced by a selftest that reads the absent
  require out of the file.
- `Places.build`'s `gridPreview` parameter and the `if previewOn` guards around the `GridPlaces`
  folder and the boot dress. The folder is now always made and the first planted cell always
  dressed.
- `ForestTestBoot`'s boot-time `if gridPreviewOn then … end` block, which built one cell's
  `ForestMarkers` and `HighSeats` so Karen could walk a cell with no drive running. That made the
  boot a SECOND builder of both folders beside the drive's own `markers` closure; the closure runs
  once a second while `Match` is `Waiting`, so the set exists from the first second anyway. One
  builder is rule 3.
- the `markers` closure's preview branch, which forced `Grid.DEFAULT_CELL` and ignored a line place
  (two answers to which place is live, while both worlds could be dealt). The override now goes
  straight through.

`Grid.PREVIEW_CELL` is **renamed**, not removed: `Grid.DEFAULT_CELL`, still `"C1"`, still
`PLANTED_CELLS[1]`. Its two readers are `Cells.wantedCell`'s fallback and `Places.build`'s boot
dress.

Karen's Forest Test carries a `DHFlag_GRID_PREVIEW=true` attribute she set on purpose. With the row
gone, `Flags.resolve` rejects it as an unknown flag and `Flags` prints one
`warn("[flags] override(s) REJECTED and NOT applied: unknown flag GRID_PREVIEW")`. It is a WARNING,
not an error and not a failure, and nothing reads the flag. The attribute is **left as it is** (the
dispatch's instruction); removing it is the Director's call.
`tools/terrainbake.py`'s `KARENS_FLAGS` still names it, which is correct: that list is of attributes
the tool must not clear in her place, and the attribute is still there.
