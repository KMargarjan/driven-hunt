# Task 284 -- the boar's hitbox fits the drawn boar

Task: 284
Round: 0 (PLAN only -- the plan is committed before any `src/` edit, CORE QUALITY step 0)
Base: 3aaa1556
Code commit: (none yet)

## PLAN

**(a) REAL LIFE.** A shot that passes beside, under or over an animal does not wound it, and a shot
that crosses its chest does. `docs/research/2026-09-25-hit-zones.md` is the note; the boar's own
anatomy is the drawn mesh of `Assets.KEYS.boarMale`, whose silhouette is a deep barrel 1.401 studs
wide against a collision trunk 2.00 wide, with a mane crest at y +1.757 against a trunk top of
+1.500. Karen, 2026-10-24: *"aim in empty space to get hit in head neck or heart like in real
life"*; 2026-10-26: *"wrong I hit the chest shows outside"*.

**(b) MEASURED NOW** (`reviews/task-282/MEASURED.md` 3, probe `reviews/task-282/probes/282-fit2.luau`,
0.1-stud grid, four directions, two passes with the mesh's `CanQuery` toggled):
**49.5 %-59.2 % of every ray that meets a hittable boar meets NO ANIMAL**, every kind, every
direction (FLANK floor 53.7 %). And the drawn back is a HOLE on two kinds: male FLANK 2.2 % /
FRONT 3.9 %, legendary 1.8 % / 3.6 % of the visible animal answers nothing, because the crest
reaches +1.757 against `ZoneHead`'s top of +1.650. Re-measured with my own copy of that probe at
the start of this task, so before and after are the same instrument.

**(c) TARGET.** **AIR 0.0 % and MISS 0.0 % on the dorsal band, on all four kinds, from the flank,
from above, from the front and from behind.** AIR 0 because a kill in empty space is the defect;
the dorsal band at 0 because the top of the back is where a boar is shot from a stand. Residual
under-coverage elsewhere (hoof flare, brisket edge, tail) is REPORTED as a located defect per
L-122, never as a score: a box is widened only to where the animal provably is.

**(d) LEVER.** The boxes are data in `Boar.CONFIG.ZONES` and (per kind) `Boar.CONFIG.KINDS.<kind>.zones`.
The code that WRITES them onto the animal:

```
src/server/Boar/Body.luau:261:			zonePart.Size = box.size
src/server/Boar/Body.luau:271:			zonePart.CFrame = trunk.CFrame * CFrame.new(box.offset)
src/server/Boar/Body.luau:272:			zonePart:SetAttribute("HitZone", zone)
src/server/Boar/Body.luau:137:		for index, box in ipairs(source.boxes or { source }) do
src/server/Boar/Body.luau:173:		trunkHittable = config.ZONES.TRUNK_HITTABLE ~= false,
src/server/Boar/Body.luau:349:	if geometry.trunkHittable then
src/server/Boar/Body.luau:350:		part:SetAttribute("HitZone", "body")
src/server/Boar/Body.luau:352:		part:SetAttribute("ZonesOnly", true)
```

So the writers all exist and nothing new is built: `Body.buildZones` already makes one part per box
(task 280) and `Body.create` already answers `ZonesOnly` when `TRUNK_HITTABLE` is false. This task is
the deer's shape applied to the boar -- a fifth `body` zone part, per-kind fitted boxes, the trunk out
of every ray -- plus `Report.CONFIG.SILHOUETTE` re-derived and the five old-contract specs rewritten.

**(e) HOW IT WILL BE MEASURED AFTER.** `reviews/task-284/probes/284-fit.luau` -- the same probe as (b),
same grid, same four directions, run on all four kinds before and after.

## THE DIRECTOR'S DECISION THIS BUILDS

A fifth `body` zone part (boxes along the barrel plus a dorsal band), every box fitted to its own
kind's drawn mesh, `TRUNK_HITTABLE = false`. `legendary` = the male's fit x 1.35 (`row.scale`, which
`Body.kindGeometry` already applies to a kind with no `zones` row); `female` and `cub` get their own
absolute rows. The deer's numbers do not move. The hit card's rectangles come from the PICTURES
(task 283) and do not move.
