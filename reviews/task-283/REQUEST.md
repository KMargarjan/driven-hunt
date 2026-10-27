# Task 283 -- the hit card draws the dot on the animal

Task: 283
Round: 2
Base: task-282-boar-hitbox
Code commit: a6be605ada9f9aeb881bbd994908212f431f83d7

```
[harness] PASS: 34/34 checks @ a6be605ada9f9aeb881bbd994908212f431f83d7 (clean tree) scope=all
```

`test2` is N/A: no path in `TWO_PLAYER_PATHS` is touched (shared report, a client spec, a client
test module and a tool).

## What changed (findings 1-3 of round 1)

The card's rectangle is **measured on the picture, per picture** (the Director's decision). One rule,
in `tools/silhouette_ink.py` `trunk_box`: the **back line** is the topmost row whose ink is at least
HALF the solidest row's (above it the drawing is mane, raised head or antlers); the **body's ends**
and the **hooves' line** are those trunk rows' own ink extent. It reads the uploaded PNGs' alpha at
full resolution for `Report.CONFIG.TRUNK_IN_INK`, and `Ink.trunkBox` re-derives the same rule from
the 240 x 120 grid, so a spec can check the number against the pixels.

## Claims

1. **The number, per picture, measured on that picture.** `TRUNK_IN_INK` has four rows -- one per
   PNG -- and `python tools/silhouette_ink.py measure` prints them: male u 0.0000..0.9989
   v 0.1347..0.9979 · female 0.0013..0.9987 / 0.0816..0.9977 · stag 0.0013..0.9160 / 0.4129..1.0000 ·
   hind 0.1404..0.9180 / 0.2795..1.0000. Verify the table against that output, or against the grid
   figures in the comment above it.
2. **Finding 1 is fixed and the hind is the proof.** Her back line is 0.2795 of her picture, not the
   mesh's 0.1951; her dorsal dot now draws at image v **0.323** and lands on ink, where round 1 drew
   it at **0.239** -- the reviewer's own figure -- 0.09 above her back. Verify the `above the box`
   notes in the client report.
3. **Two instruments agree, three times.** The rule reproduces task 278's hand-measured deer rumps
   (0.9160 / 0.9180 against 0.916 / 0.918) and the hand-measured hind back line (0.2795 against
   0.276), and full resolution agrees with the grid to half a cell (worst 0.0039 against a cell of
   0.0083). Verify `measure`'s own grid column, or the comment above `TRUNK_IN_INK`.
4. **A shared picture shares the row** (the decision). `Report.boarImage` keys `trunk(...)` by the
   PICTURE: a cub is drawn in the sow's rectangle, a calf and a hind in hers, a legendary in the
   male's. Verify the seven `box = trunk(...)` lines, and the per-kind `box` notes in the client
   report (cub == female, calf == hind, legendary == male).
5. **Nothing else keys it by kind.** `grep -rn "TRUNK_IN_INK|boarImage" src tests tools` -- the only
   reader is `Report.boarImage`; the spec's own `DRAWN` table maps kind to picture itself. Round 1's
   dead `legendary` branch is gone (it returned exactly the fallthrough).
6. **Finding 2 is fixed: the dorsal band asserts the animal, not the defect.** `hit_card.spec`
   "clamps a hit ABOVE the box onto the picture's back line, and draws it ON the animal" requires all
   four points to land on ink AND each one's drawn image v to be within one cell of the picture's own
   back line plus half a dot. No case asserts that a dot misses.
7. **Finding 3 is fixed: every case asserts the NUMBER.** The new case "draws the dots in the
   PICTURE'S OWN trunk box, to a cell, for all seven kinds" reads the box the renderer wrote onto the
   frame, undoes scale and `ScaleType.Fit` with the spec's own arithmetic, and compares all four
   edges with `Ink.trunkBox` to 1/120. The lead pellet and the fanned group now assert their drawn
   image v against the same ink-derived prediction: 0.224 measured / 0.170 round 1 / 0.308 before the
   task / 0.093 with no rectangle, six cells apart at the closest.
8. **FAIL FIRST, measured (L-028).** With ONLY `TRUNK_IN_INK` put back to round 1's mesh rows:
   `[harness] FAIL: 32/34 checks @ a6be605ada9f9aeb881bbd994908212f431f83d7 (DIRTY TREE (1 paths) -
   NOT valid evidence) scope=all`, `[client] 607 passed, 4 failed, 4 errors` -- the box case
   (0.079 against 0.1333), the dorsal case (all four, hind at img 0.239), the lead pellet (0.151
   against 0.2037) and the fan (0.179 against 0.2303). Four cases, each on its number.
9. **`silhouette_ink.py check` works now.** It compared file TEXT, so stylua's formatting made a
   current file read "STALE" (round 1's note); it compares the parsed grid (`w`, `h`, row strings).
   Verify `python tools/silhouette_ink.py check` -- for anyone holding the uploaded PNGs; the files
   are outside the repo, so CI cannot run it.
10. **The grid is 240 x 120 and the reason is measured.** At 120 x 60 a cell is 12.6 px of the stag
    and the stag's chest point read as air 2 px INSIDE his belly line (alpha 255 at full resolution,
    column x 356 inked to v 0.690). Twice the resolution, same rule. The only other test change is
    `tests/server/hit_card.spec.luau`'s span floor, 0.78 -> 0.75: the hind's measured body spans
    0.778 of her picture because her head and neck are drawn forward of her chest.

## What I could NOT verify

- **No card frame was drawn or looked at (rule 5), and nothing here has been seen in Karen's place.**
  The dispatch says the Director shoots it with `onray.py` after the review. The picture claim is
  **NOT PROVEN** on screen; what is proven is the pixels.
- **Why a chest aim struck the withers is not in this round** (the dispatch excludes it).
- The 23 flank points come from round 1's `283-flank.luau` rays; they were not re-measured.
