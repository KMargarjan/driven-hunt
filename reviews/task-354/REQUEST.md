# Task 354 -- the painted map in the game, behind `MAP_PAINTED` (born OFF)

Task: 354
Round: 2
Base: 8cc53d35 (origin/main)
Code commit: de6330d8a7cff0112d98e220035e02efa2c35c69

```
[harness] PASS: 34/34 checks @ de6330d8a7cff0112d98e220035e02efa2c35c69 (clean tree) scope=all
```

`test2` is **N/A**: nothing here touches `TWO_PLAYER_PATHS`, and the dispatch says `test2` N/A.

## Round 1's two findings, and what they cost

**Both were right, and both changed the code rather than the wording.**

**Finding 1 -- the alignment case was an algebraic identity.** It was. `world_of_box` is the exact
inverse of the mapping `landmarks` measures its pixel with, so `pxX / outW == (worldX - minX) /
(maxX - minX)` holds for any point at any resolution, and the case printed `0.000000 px` over nine
blank PNGs. Three things changed:

* the painter and the landmark table now share **one** `canvas_px` -- round 1 found two hand-written
  copies of the same two lines, so changing the painter's projection reddened nothing;
* the identity case is **kept and correctly described** as a check of the projection CONVENTIONS
  (which corner is the origin, which way z runs, one scale for both axes), with its own comment
  saying it passes over blank images;
* **`python tools/map_paint.py verify` now reads the pictures.** It cuts a transect across each road
  in the saved tiles, takes the luma-weighted centroid of the bright ridge, and compares it with the
  pixel the manifest maps the centreline to.

**Finding 2 -- the number was measured on a rectangle the drawer does not draw.** Also right: the
drawer rounded the SIZE and added `BLEED_PX = 1` with `ScaleType.Stretch`, which drags the painting
about a pixel at a tile's far edge. It now sizes from its two **rounded corners**
(`math.round(left + width) - math.round(left)`), which is the fix the finding proposed: neighbours
still meet exactly, because their shared edge is one world coordinate, so no bleed is needed and
`BLEED_PX` is gone. A new case measures the alignment **between the two drawn instances**.

## Claims

1. **The painted road really is at the pixel the manifest maps it to, and the check bites.**
   *Verify:* `python tools/map_paint.py verify` -->
   `worst offset 8.68 studs at roadEW2_7 (<= 12.0)` and
   `worst contrast 35.6 luma at roadNS4_8 (>= 18.0)` over 16 road samples, 0 skipped.
   The known-bad half runs in CI: `python tools/map_paint.py selftest` has
   `...and BLANK tiles of the wood's own colour FAIL it` and
   `...and tiles pushed by the bend's own 45 studs FAIL it` (34 checks, 0 failed).

2. **The 12-stud bound was measured, not chosen, and its residual has a named cause.** Every
   east-west sample reads *south*; that is the painter's own crown drop-shadow (`drop` = 4 px at
   0.70 px/stud = 5.7 studs) darkening a road's north edge, against an observed +6.5-stud mean. The
   bound still catches the failure it exists for -- a dropped or mis-signed bend moves a road by
   `ewStuds` 45 to `nsStuds` 60 studs. *Verify:* the `MAX_ROAD_OFFSET_STUDS` comment, and the
   45-stud known-bad case above, which fails at 27-29 studs.

3. **The drawn icons sit on the drawn picture: worst 0.608 px over the 15 C1 stands.** Measured
   between the `Painted<id>` `ImageLabel` and the `Stand<i>` `Frame` read back out of the live map
   -- no `MapView` is rebuilt, so the panel's own scaling cannot make the two sides agree.
   *Verify:* note `map_ui 354 drawn alignment: 15 stand icons against the painted tiles, worst
   0.608 px at standC14 (<= 1.0)`.

4. **The projection conventions agree exactly.** *Verify:* note `map_ui 354 placement arithmetic:
   63 landmarks (15 stands, 32 corners, 16 road), worst 0.000000 px` -- and the case's own comment
   says what it does not prove.

5. **The picture is of THIS forest, roads included.** Round 1's note was right that 36 road points
   were never compared with Luau; now every landmark is, the road samples against
   `Grid.roadPolyline`. *Verify:* note `map_ui 354 geometry mirror: 63 points against Grid, worst
   0.000e+00 studs`.

6. **Flag OFF is today's `MAP_LOOK` map; ON replaces the tint and keeps the icons.**
   *Verify:* note `map_ui 354 draw: 9 images and 0 bands with the tiles, 0 and 384 without`.

7. **A part-uploaded set leaves no hole** -- the state a partly-rejected moderation batch produces,
   which round 1's note found unasserted. *Verify:* note `map_ui 354 part-uploaded: C1 rejected ->
   8 image(s), 56 band(s) for C1, 0 for the painted cells`.

8. **Inside task 347's budget.** *Verify:* note `map_ui 354 budget (DEV): open p50 0.15 ms, max
   0.89 ms (<= 50), 322 instances in the map frame (<= 1500)`. **DEV ONLY.**

9. **One owner, one read of the flag, born OFF, both states reachable by parameter.**
   *Verify:* `grep -rn "MAP_PAINTED" src/` -- the flag row, `MapUi.PAINTED.ENABLED`, and `Hud`'s one
   use. `Flags.DEFAULTS.MAP_PAINTED.default == false`, and every case drives the layer through
   `geometryFor`'s `paintedMap` argument.

10. **`report_panel.spec:540` was failing before this task and is repaired.** A control run with
    `origin/main`'s `src/` and `tests/` in the tree failed the same line
    (`[harness] FAIL: 32/34 checks @ ababb3cf8712 (DIRTY TREE (4 paths) - NOT valid evidence)`).
    Round 1's note is right that it was **flaky, not deterministically red** -- it reddens only when
    a feed line is already older than `FEED_SECONDS` -- and that is said here instead. The repair is
    time-independent: with `Hud.killLineText`'s line deleted, `expect(drawn).to.equal(1)` fails.
    *Verify:* `git show origin/main:tests/client/report_panel.spec.luau` against this branch's.

## Flakes seen, named, and the count

The run at this same commit **before** the passing one failed three specs, none of them within reach
of a map: `weapon_shot.spec:1890`, `weapon_shot.spec:2055` and `semiauto_client.spec:93`. The first
and third are in the dispatch's named list; `weapon_shot.spec:2055` is not, but it is in the same
named-flaky file as `:1890` and `:2077`, whose line numbers have moved since the list was written.
Captured before re-running. The re-run at the same commit is the `34/34` line above. **Two runs at
`de6330d8`: one 29/34, one 34/34.**

## What could NOT be verified, and why

* **THE UPLOAD, AND THEREFORE THE FLAG-ON FRAME.** `NOT OBTAINABLE`. All nine Decal uploads answer
  `401 Invalid API Key`, and a bare read with the same key answers the same, so the credential is
  refused rather than the asset type -- `ESCALATE.md`, **NEEDS KAREN**, written at the hard stop
  before any workaround. Every `assetId` is 0, which `PaintedMap` and `MapUi` already treat as "not
  uploaded, draw nothing", so a flag-ON frame would show today's map and would be a frame named for
  a state it does not show. None is offered. `assets/uploads.json` is **unchanged**.
* **ANY LIVE PROOF IN KAREN'S FOREST TEST, including the click proof.** Her FT syncs from
  `driven-hunt-karen`, which carries merged `main` and not this branch, and the dispatch forbids
  checking code out there -- so no frame in her place can exercise this change before the Director
  merges, and the painted map cannot be on screen there to be clicked. Nothing was started, no
  attribute was touched, and `MAP_PAINTED` is **left OFF**. Task 352b's finding stands untouched: the
  stand pick works by a real click when the window is not re-activated, and nothing here touches the
  pick path.
* **The budget numbers are DEV ONLY**, as task 347's are.
* **Whether Karen likes it.** Nobody has seen the painted map in the game, and nobody can until the
  key is replaced.

## The pictures, opened and described

* `assets/ready/map/c1.png` (774 x 1024) -- C1's cell: a yellow-green wood (mean RGB 88,96,32) with
  amber autumn crowns through it, a pale open scrub patch at the top-left and another top-right, the
  sandy east flank road curving down the right-hand edge, and the main road along the bottom with
  darker wood beyond it.
* `assets/ready/map/wood.png` (1024 x 739) -- the whole world: two rows of four wood blocks separated
  by the pale, visibly bent road grid, and the outer wood skirt running past the blocks on every side
  before it fades into olive open ground. This is the "outer wood drawn" the dispatch asks for.
* Checked numerically, not by eye: each of the eight cell tiles correlates **0.993-0.998** with the
  same rectangle cropped out of `wood.png`, mean colour equal to +-1 per channel.
