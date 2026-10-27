# Task 282 -- the boar's hitbox, and the buckshot card

Task: 282
Round: 1
Base: cb00b9cd (main)
Code commit: efb1dbcb (docs-only -- no `src/`, `tests/` or `tools/` file is touched in this round)

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

1. **The buckshot card's own arithmetic is CORRECT and is not the fault.** Measured per pellet:
   eight dots, true `(u,v)` from the server, drawn where `BoarArt` put them. Verify:
   `282-shotcard.luau`'s output in `MEASURED.md`, dot by dot, against `HitLog.Shape.dot`.
2. **The pattern's own spread is CORRECT and is not the fault.** The eight pellets span
   u 0.260..0.590 and v 0.035..0.406 = 1.8 x 1.1 studs at 88.7 studs. Verify: `Shotgun.CONFIG`
   `SPREAD_FULL_DEG.Buck = 1.6` -> radius 89 x tan(0.8 deg) = 1.24 studs.
3. **THE FAULT IS THE TRUNK'S AIR.** The lead pellet struck at local y **+1.41** -- 0.09 under the
   trunk's top face -- on a box whose top is 1.50 where the drawn boar's back over the chest is
   lower. `uv=(0.462,0.030)`: v 0.030 is the top edge of the unit square, which the card maps to the
   top of the measured ink box, i.e. the mane. That is Karen's "bunched on the head/neck" and "half
   outside the silhouette". Verify: the `[hitlog]` line in `MEASURED.md`.
4. **THE COMPLEMENT, BEFORE, per kind** (`282-fit.luau`, 0.1-stud grids, four directions). Of every
   ray that meets a hittable box from the FLANK: male 984 of 1798 air (**54.7 %**), female 696 of
   1256 (**55.4 %**), cub 212 of 372 (**57.0 %**). From ABOVE: male 57.7 %. FRONT and BEHIND: 50.4 %.
   **Legendary is NOT measured** -- its drawn mesh did not load in the probe's first two runs; it was
   fixed (`setModelSource` keys on the model, not the kind) but re-measured only for the frame.
   **MISS on the animal is 0 of 814 flank rays on every kind measured**: the boar's defect is air,
   not holes, which is the opposite of the deer's.
5. **Item 4's grep, every boar zone name in `src/`, `tests/`, `reviews/`.** Live code and specs only
   (paperwork excluded): `src/server/Boar/init.luau` (9: the four config rows), `Boar/Body.luau` (2),
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
- **Legendary's complement** (claim 4).
- The 2.35-stud "worst zone gap" the staging probe prints is `ZoneHead`'s own design offset
  (|(0, 1.00, -2.13)| = 2.353) and not drift: the four measured offsets equal the config's exactly.
