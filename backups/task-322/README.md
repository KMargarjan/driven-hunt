# Task 322 archive: the hut and the bench rest

Karen, 2026-10-31, after playing 320: *"also remove this roof in shooting range we dont need that
eather keep just this e and one line or row where it can go or recatange not need thos 4 columns
and roof and platform"*.

Removed from the range build. Baseline commit: `2615879a` (main with 313-321 merged).

| File | What it holds |
|---|---|
| `server-Range-Build-hut-and-bench.luau.txt` | `src/server/Range/Build.luau` lines 423-485 verbatim: the bench rest, the four hut columns, the roof, the number board and its two `makeBoardFace` calls |
| `shared-Range-bench-and-hut.luau.txt` | `src/shared/Range/init.luau`: the `BENCH` table, the `HUT` table's board and colour keys, `Range.benchPosition`, `Range.benchName`, and the hut's seven build readers (`hutRoofPosition`, `hutPostPositions`, `boardRiseFor`, `boardPosition`, `boardName`, `hutRoofName`, `hutPostName`) |

## What was NOT removed, and why

`LAYOUT.HUT` still carries `roofSize`, `roofAheadStuds` and `postSection`. They are **unbuilt data**,
marked as such in `src/shared/Range/init.luau`, because two live readers measure the safety geometry
off them and task 322 must not move it:

* `Range.bayHalfSlope` — his bay's opening, which `sightSpanFor` reads, and through it the mask, the
  shot's door and the crossing window;
* `Range.sightlineFrom` — the X span a tree may not stand in (task 315).

Same precedent as `LAYOUT.STAND`, kept by task 320 for the same reason.

## Restore recipe

This is a **plain re-insertion**, not a patch: every symbol below was deleted whole, and nothing that
remains was renamed into it except `Range.boardText` -> `Range.stationNumberText`.

1. `src/shared/Range/init.luau`
   - paste the `BENCH` table back into `Range.LAYOUT`, after `STAND`;
   - paste the archived board and colour keys back into the `HUT` table (it is still there, with its
     three surviving keys) and replace its task-322 header comment;
   - paste `Range.benchName` back beside `Range.standName`;
   - paste `Range.benchPosition` back after `Range.standPosition`;
   - paste the seven hut build readers back before `Range.stationNumberText`;
   - rename `Range.stationNumberText` to `Range.boardText` (3 call sites: this definition and two in
     `Build.luau`), or keep both names.
2. `src/server/Range/Build.luau`
   - rename `makeNumberFace` back to `makeBoardFace`, point its `TextColor3` at
     `layout.HUT.boardTextColor`, drop the two `TextStroke*` lines and set `gui.Name = "BoardFace"`
     and `label.Name = "Number"` as literals;
   - replace the two `makeNumberFace(postPart, ...)` calls plus `table.insert(mats, mat)` with the
     archived block (which ends with that same `table.insert`);
   - put the mat back through `onGround` (one line) instead of the flush `groundUnder` + `makePart`
     block, and drop `MAT.liftStuds` / `MAT.material` from the layout.

No `require` line changes either way: `Build.luau` already requires `RangeData`, and nothing new was
imported. `tests/server/range.spec.luau` and `src/server/Range/init.luau`'s part census must be
reverted with it; `git show 2615879a:<path>` is the shortest route for both.
