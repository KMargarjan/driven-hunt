PASS (item 5 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: what has been seen in Karen's
place is the BUILT PICTURE and the WALK -- five described frames (`f1b-line-view`, `f2b-lane1-view`,
`f3b-deck4-view`, `f6b-berm-view`, `f5-menu-view`), a real `E` opening the menu with its six option
rows and the board, and two walks on a real held `W` (lodge door to mat 6, 169.65 studs in 13.57 s,
ending at (2720.1, 154.1, -3030.0) = mat 6's own X/Z; mat 6 to mat 1, 115.24 studs in 10.43 s).
**NO SHOT WAS FIRED BY ANYONE AT ANYTHING.** Claim 5 (T6, "no shot leaves the range") is 180 COMPUTED
rays, and design 11.5 item 3's frame (the rail board under the gun with the berm beyond) was not
obtained. No animal-behaviour claim is made. Item 5 is therefore named in the parenthesis.

Round 1's blocking finding is closed, checked by arithmetic and not by the diff's word for it. With
the shipped row, `Join.homeAreas` gives field x 2740..2960 z -3060..-2840, `Range.footprintFor`
x 2532..2788 z -3238..-2998, and `Join.walkwayTo` x 2636..2874 z -3142..-2926. Rect 1 and 2 each have
2 uncovered outward points (`tested` = 4 >= 3); rect 3 has 0, so the new arm fires, and its grid point
(2636, -2926) is inside rect 3 alone -- x < 2740 so not the field, z > -2998 so not the footprint --
so `expect(own > 0)` is TRUE for a geometric reason and FALSE the moment the corridor is swallowed by
the other two. It is not a restatement of the loop's exit condition: `others` is a different list, and
the loop's points are interior, not the outward ones. Deletion test on the rest: drop
`Range.cutRects`' footprint clamp and "FITS the rectangle the B8 census measured" reddens (rect 2's
`maxZ` becomes -2996 against `MEASURED.maxZ` -2998); ignore `row.shelfFrom` in `Build.shelfAt` and
"takes its level from the LOBBY" reddens (168 against 156, and the `> 1` arm names the gap); drop the
`fillsTerrain(row)` guard and "writes NOTHING without a terrain" reddens on the shipped `map:v1` row.
The two terraces meet flush and cannot fight: rect 1 (2544..2776, -3228..-3060) touches the field only
along z = -3060, rect 2 (2544..2740, -3060..-3000) only along x = 2740, every face a multiple of 4,
and the walk from the door to mat 6 crosses x = 2740 at z = -3012.5, inside that 60-stud seam.

## Notes (non-blocking)
- REQUEST, "FAIL FIRST, run" — the cited run does not exercise the arm that shipped. The probe
  rectangle (x 9000..9100, z 9000..9100) has FOUR uncovered outward points, so under the shipped case
  `here` = 4 and the `if here == 0 then` grid never runs for it; and `0ac23f15` predates `477e6765`,
  so what reddened was the THIRD version's inverted assertion ("the others cover its whole area"),
  which a rectangle with ground of its own is *supposed* to fail. The arm is load-bearing by the
  reading above, so nothing is hidden -- but the paragraph is evidence for the opposite claim. The
  probe that would redden `expect(own > 0)` is a rectangle wholly inside the field (e.g.
  x 2800..2820, z -2900..-2880): no edge of its own, no ground of its own.
- `tests/server/lobby.spec.luau`, the grid loop — `expect(Join.insideHome(at, areas)).to.equal(true)`
  cannot fail: `at` runs from `rect.minX/minZ` to `rect.maxX/maxZ` inclusive, `rect` is `areas[index]`,
  and the case itself asserts that ON the edge is IN. Harmless beside `own > 0`, but it reads as a
  second assertion where there is one. Drop it or ask it of a point one stud outside the union.
- REQUEST claim 5 — "180 stopped at or before the berm" does not isolate the berm. Every ray is aimed
  down at a target on the lane, so a ray that stops on the flat terrace short of the berm counts the
  same as one the berm stopped, and that outcome survives the berm's deletion. Count what each ray
  HIT (the berm's own voxels) and add one level ray from the deck eye (shelf + 17.5 = 167.5 against a
  crest at 160.02) -- which is the ray that would leave the range if anything does. B9's work.
- `tests/server/range.spec.luau` "takes its level from the LOBBY and lands on the same number a
  second time" — the fixed-point arm cannot tell FLOOR from ROUND: `second` is fed `first` (168),
  already on the grid, and rounding is a fixed point there too. This task's own measurement says the
  feedback is the DRAWN surface, shelf + 2; feed `first + 2` (and `+1`, `+3.9`) as task 311's
  `Field.shelfFor` case does, and the arm bites for the reason its comment gives. The case as a whole
  still reddens on floor -> round, via `expect(first).to.equal(FOREST_SHELF)`.
- `tests/server/range.spec.luau` "stands clear of all seven lobby rectangles" — on the shipped forest
  row `bermIsTerrain` is true, so `buildWith` builds neither `Berm` nor `Bank*` and `footprintOf` now
  measures a box with the range's two WIDEST things missing (the berm spans x 2544..2776, the parts
  2592..2728). The property still holds -- all seven rectangles are inside the field, the terrace
  never overlaps the field, and the berm is 228 studs south of it -- but the case no longer proves it
  for the ground the range writes. Add `cutRects`/`bermBoxes` to the gap loop.
- `Build.writeTerrain` — the `AROUND -> LANE` repaint over the terrace rectangles has nothing to
  repaint: the air box clears everything from the shelf up and the grass box writes `LANE` over the
  whole rectangle 48 studs down, so no `Grass` voxel survives inside it. Harmless, but
  `expect(#terrain.replaces).to.equal(3)` counts two calls that cannot change a voxel; the comment
  "the cover the fill could not reach" names a case that `cutBoxes` already covers.
- Citations the move made stale outside the changed code: `ForestTestBoot.server.luau`'s `homeAreas`
  comment (*"The range is 268 studs from the lodge anchor"* -- it is now 186.7 walked, claim 6's own
  number); `src/shared/Lobby/init.luau`'s `FLAGPOLE` comment (*"291 studs from the range's nearest
  edge (`Range.ANCHORS["forest-test"]` is (2650, -3216), and its built box measures x 2570..2730,
  z -3356..-3212)"* -- that box no longer exists; the real nearest edge is x 2788 / z -2998, about 144
  studs, still clear); and the same sentence in TASKS.md's task 311 row. `rangeHomeAreas` itself
  derives the rectangle from the row, so claim 4's "nothing was edited there" is true.
- Counts: the footprint is 256 x 240 (x 2532..2788, z -3238..-2998), not the "256 x 239" in
  `Range.ANCHORS` and in `range.spec`'s section 9 header; and 8-stud spacing over it is 33 x 31 =
  1023 samples, which is the PLAY census's number -- so the Edit census's 990 is one row of samples
  short of "design 2.2's footprint" (claim 1). Name the row that was not sampled.
- The diff against `c2cb8437` also carries tasks 310 and 311 from `main` (`src/server/Lobby/*`,
  `src/shared/Lobby/init.luau`'s `FLAGPOLE`/`AVENUE`, `tools/aim_bench.py`, the lobby.spec hunks at
  the field blocks, `docs/research/2026-10-29-*`). Those have their own `reviews/task-31*/RESULT.md`
  and are not re-reviewed here. One interaction checked: task 311's `tryBuild` cuts at 148 and then
  re-reads the surface it produced (150), and `Build.shelfAt`'s floor gives 148 from either 149.25 or
  150 -- so the two terraces agree whichever owner builds first.
- Still queued and still real, as the request says: `Range.cutRects`' snapping is backwards at
  `downrange = +1` and unreachable by parameter in any case; `Build.cutBoxes`' own floor and its
  `(shelf - bottom)` term are dead on every reachable path; `SURFACE.LINE_BACK_STUDS` 14 reaches the
  deck's CENTRE, so the uprange half of every deck stands off the gravel and the coverage case's
  `^Mat%d`/`^Post%d`/`^Bench%d` filter cannot see it; and `docs/design/shooting-range-lobby.md` §8
  contradicts the code in four places. `Flags.ROWS.RANGE.default` is false (expires 2026-11-17) and
  `Range.ENABLED` gates `Range.start` before `Build.build`, so no terrain is written in any place
  until the flag flips -- the request now says so.

---
REVIEWER verdict on commit `90563c7b05f02b9f67feb5401a8b9cccdf5530ec` (round 2) · 2026-10-29 17:21 UTC · session cost $4.30, 38 turns · written by tools/agents.py
