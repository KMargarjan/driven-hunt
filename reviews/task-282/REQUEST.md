# Task 282 -- the boar's hitbox, and the buckshot card

Task: 282
Round: 2
Base: cb00b9cd (main)
Code commit: d4c730ae (docs-only -- no `src/`, `tests/` or `tools/` file is touched in this round)

```
[harness] PASS: 34/34 checks @ d4c730aecce39a3e2d2edcc16bce4fc322ec8d4c (clean tree) scope=all
```

Not required (docs-only; `.agent-evidence/changed-files.txt` carries the premise) and run anyway,
because 281a(k) records the suite failing twice on a head with byte-identical `src`. `[harness2]`
is **N/A**: nothing in `TWO_PLAYER_PATHS` is touched -- nothing at all under `src/` is.
`tools/studio_mcp.py selftest` and `tools/agents.py selftest` both pass.

**THIS IS A MEASUREMENT ROUND, NOT A FIX ROUND.** Dispatch item 2's cause was unknown; it is now
measured and named, and it turns out to BE item 1. Item 1 is a task-280-sized rebuild and did not fit
the box -- `ESCALATE.md`, 2026-10-27, says so with the arithmetic. Nothing in the game changed.

## PLAN (core quality protocol, step 0)

- **(a) REAL LIFE.** 00 buckshot from a cylinder bore throws a pattern about 1 inch per yard: at
  89 studs (~25 m) that is a circle roughly 2.5 studs across. A wild boar is ~0.40 m across the
  chest and ~1.0 m at the withers, so at that range the pattern is WIDER AND TALLER THAN THE ANIMAL.
- **(b) MEASURED NOW** (`reviews/task-282/probes/282-stage.luau` + `282-shotcard.luau`, DEV Play,
  one `FireRequest` at a frozen broadside male at 88.7 studs, camera ray verified on `ZoneChest`):
  `SPREAD_FULL_DEG.Buck = 1.6` gives a measured pattern of 1.8 studs long x 1.1 studs tall -- as
  designed. The trunk is 2.00 x 3.00 x 5.50 and the DRAWN male measures 1.401 x 3.257 x 5.500.
- **(c) TARGET.** Every pellet the server calls a hit crossed the drawn animal; a pellet beside,
  under or above it is NOT a hit. Today 54.7 % of the male's hittable flank cross-section is air.
- **(d) LEVER.** `Boar.CONFIG.ZONES` (`src/server/Boar/init.luau`, the four rows) and
  `config.ZONES.TRUNK_HITTABLE`, read at `src/server/Boar/Body.luau` `kindGeometry`
  (`trunkHittable = config.ZONES.TRUNK_HITTABLE ~= false`) and acted on in `Body.create`
  (`part:SetAttribute("ZonesOnly", true)`). Both writers exist -- that is why the target is not
  refuted -- and this is exactly the pair task 280 moved for the deer.
- **(e) HOW IT WILL BE MEASURED AFTER.** `282-fit.luau`, the same probe as (b), same four sweeps.

## Claims

1. **The buckshot card's own arithmetic is CORRECT and is not the fault.** The half that falsifies
   is `true` vs `drawn`, not `uv` vs the dot attribute (those are one `Shape.dot` result under two
   names). Verify: recompute each `drawn` from `BoarArt.drawDots` with `DOT_PIXELS = 7` on a 148x80
   frame and the written box. **Two of the eight are moved by `BoarArt.spread`** -- (0.332,0.326)
   and (0.310,0.254) are 6.6 px apart and are fanned onto a ring of radius 5.94 px about their own
   centre, which is why both draw at v 0.393. That is by design (Karen, 2026-10-17) and it is small
   here; **a group of EIGHT gets radius 11.9 px in an 80 px frame against a 37 px ink box**, which
   is a second, smaller card defect this round does not fix and 282a should carry.
2. **The pattern's own spread is CORRECT and is not the fault.** The eight pellets span
   u 0.260..0.590 and v 0.035..0.406 = 1.8 x 1.1 studs. Verify: `Shotgun.CONFIG`
   `SPREAD_FULL_DEG.Buck = 1.6` -> a cone 2.3-2.5 studs across at this range. (88.7 is the STAGED
   TRUNK's distance; the server's own record for the two shots is `dist=82.0` and `dist=85.7`. The
   span sits inside the cone on any of the three.)
3. **THE FAULT IS THE TRUNK'S AIR.** The lead pellet struck at local y **+1.41** -- 0.09 under the
   trunk's top face -- on a box whose top is 1.50 where the drawn boar's back over the chest is
   lower. `uv=(0.462,0.030)`: v 0.030 is the top edge of the unit square, which the card maps to the
   top of the measured ink box, i.e. the mane. That is Karen's "bunched on the head/neck" and "half
   outside the silhouette". Verify: the `[hitlog]` line in `MEASURED.md`.
4. **THE COMPLEMENT, BEFORE, all four kinds** (`282-fit2.luau`, 0.1-stud grids, four directions,
   `rays=` printed). Of every ray that meets a hittable boar: **AIR is 53.7 %-59.2 %** on every kind
   from every direction (FLANK: male 984 of 1780 = 55.3 %, female 55.5 %, cub 57.5 %, legendary
   53.7 %). **AND THERE ARE HOLES**: MISS on the visible animal is 18 of 814 (2.2 %) on the male's
   flank, 13 of 336 (3.9 %) front and behind, and 26 of 1481 (1.8 %) / 22 of 610 (3.6 %) on the
   legendary -- the back line and the mane stand 0.257 studs (male) above `ZoneHead`'s top of
   +1.650, so the top of the back is a miss today. `ABOVE`'s 0 % is forced by the geometry and is
   the only 0 that is. Verify: `MEASURED.md` section 3, verbatim output.
   **ROUND 1 REPORTED MISS 0 EVERYWHERE AND THAT WAS A BUG IN MY PROBE, which the Reviewer caught**:
   `FilterDescendantsInstances` takes the instance AND ITS DESCENDANTS, the drawn mesh is a
   descendant of the trunk, so every mesh hit counted as a box hit. `282-fit2.luau` casts in two
   passes with the mesh's `CanQuery` toggled between them. The diagnostic that isolates it is in
   `MEASURED.md` section 3.
5. **Item 4's grep, every boar zone name in `src/`, `tests/`, `reviews/`.** Live code and specs only
   (paperwork excluded): `src/server/Boar/init.luau` (8: the four config rows -- round 1 said 9, the Reviewer's count is right), `Boar/Body.luau` (2),
   `src/server/Weapon/init.luau` (2, both comments), `src/server/Weapon/Validator.luau` (2, both
   comments), `tests/server/boar_zones.spec.luau` (5, one of which asserts the exact child list
   `"ZoneChest,ZoneHead,ZoneLegs,ZoneRear"`), `boar_hit.spec.luau` (1), `boar_behaviour_live.spec.luau`
   (1), `weapon_shot.spec.luau` (2, both a hind's). **Nothing numbering breaks today**, because no
   zone was renumbered -- that is the work item 1 would have done.
6. **Frames, looked at.** `<runs-dir>/282/eye2-male.png` and `eye2-cub.png`, player's eye height,
   12.4 studs, broadside, the shot volumes drawn over the drawn animal. The male frame shows the
   boxes' top edge running clear of the back line with sky behind it, the tan `ZoneLegs` slab
   standing a head's length past the rump, and a margin of empty box down the near flank.
7. **Not done, and named as not done:** items 1, 2's FIX, and 5 (the spec). `ESCALATE.md` has the
   reason and the size.

## What could not be verified

- **Karen's own place.** The Forest Test reproduction was abandoned after the drive swapped the
  player to BEATER mid-measurement (`tool=Horn`); DEV holds the role steady, runs the same code, and
  the fault is geometry. **Every number above is `DEV ONLY`.**
- Nothing else: legendary's complement is measured in this round.
- The 2.35-stud "worst zone gap" the staging probe prints is `ZoneHead`'s own design offset
  (|(0, 1.00, -2.13)| = 2.353) and not drift: the four measured offsets equal the config's exactly.
