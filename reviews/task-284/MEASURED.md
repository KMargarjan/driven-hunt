# Task 284 -- the readings

**Every block below is a probe's own output.** All DEV ONLY (Driven Hunt DEV, Play, 2026-10-27).
Probes in `reviews/task-284/probes/`.

## 1. THE COMPLEMENT, BEFORE (`284-fit.luau`, 0.1-stud grid, four directions, two casts per direction)

It is `reviews/task-282/probes/282-fit2.luau` with the kind loop rolled inside, and it reproduces task
282's numbers cell for cell -- which is what makes it the same instrument for the after. AIR is a ray
that hits a hittable box and never crosses the drawn mesh; MISS is a ray that crosses the mesh and
hits no box.

```
male: trunk 2.00,3.00,5.50  drawn mesh 1.401,3.257,5.500  hittable=5 (ZonesOnly=nil)
  FLANK   rays=2944  animal=814: HIT 796 (97.8%) MISS 18 (2.2%) | box hits=1780: AIR 984 (55.3%)
  ABOVE   rays=1728  animal=506: HIT 506 (100.0%) MISS 0 (0.0%) | box hits=1197: AIR 691 (57.7%)
  FRONT   rays=1242  animal=336: HIT 323 (96.1%) MISS 13 (3.9%) | box hits=664: AIR 341 (51.4%)
  BEHIND  rays=1242  animal=336: HIT 323 (96.1%) MISS 13 (3.9%) | box hits=664: AIR 341 (51.4%)
female: trunk 1.70,2.55,4.68  drawn mesh 1.202,2.647,4.675  hittable=5 (ZonesOnly=nil)
  FLANK   rays=2255  animal=560: HIT 559 (99.8%) MISS 1 (0.2%) | box hits=1255: AIR 696 (55.5%)
  ABOVE   rays=1320  animal=370: HIT 370 (100.0%) MISS 0 (0.0%) | box hits=882: AIR 512 (58.0%)
  FRONT   rays=984  animal=232: HIT 230 (99.1%) MISS 2 (0.9%) | box hits=468: AIR 238 (50.9%)
  BEHIND  rays=984  animal=230: HIT 230 (100.0%) MISS 0 (0.0%) | box hits=468: AIR 238 (50.9%)
cub: trunk 0.90,1.35,2.47  drawn mesh 0.618,1.439,2.475  hittable=5 (ZonesOnly=nil)
  FLANK   rays=957  animal=160: HIT 157 (98.1%) MISS 3 (1.9%) | box hits=369: AIR 212 (57.5%)
  ABOVE   rays=495  animal=106: HIT 106 (100.0%) MISS 0 (0.0%) | box hits=260: AIR 154 (59.2%)
  FRONT   rays=435  animal=64: HIT 64 (100.0%) MISS 0 (0.0%) | box hits=146: AIR 82 (56.2%)
  BEHIND  rays=435  animal=64: HIT 64 (100.0%) MISS 0 (0.0%) | box hits=146: AIR 82 (56.2%)
legendary: trunk 2.70,4.05,7.43  drawn mesh 1.891,4.397,7.425  hittable=5 (ZonesOnly=nil)
  FLANK   rays=4648  animal=1481: HIT 1455 (98.2%) MISS 26 (1.8%) | box hits=3145: AIR 1690 (53.7%)
  ABOVE   rays=2822  animal=930: HIT 930 (100.0%) MISS 0 (0.0%) | box hits=2156: AIR 1226 (56.9%)
  FRONT   rays=1904  animal=610: HIT 588 (96.4%) MISS 22 (3.6%) | box hits=1164: AIR 576 (49.5%)
  BEHIND  rays=1904  animal=609: HIT 588 (96.6%) MISS 21 (3.4%) | box hits=1164: AIR 576 (49.5%)
```

**THE LEGENDARY'S FACTOR, RE-MEASURED AS THE DISPATCH ASKS (L-020):** its drawn mesh is
1.891 x 4.397 x 7.425 against the male's 1.401 x 3.257 x 5.500 -- **1.3498, 1.3500, 1.3500**. It is
the male's mesh at `meshScale` 1.35 on a trunk at `scale` 1.35, so `Body.kindGeometry` multiplying
the male's fitted boxes by `scale` IS its fit, and it carries no `zones` row.

## 2. THE DRAWN BOAR'S OWN PROFILE (`284-profile.luau`), which is what the cages were drawn around

```
#### male trunk 2.000,3.000,5.500  drawn 1.401,3.257,5.500
mesh centre in trunk frame 0.000,0.129,0.000 -> y -1.500..1.757  z -2.750..2.750  x -0.701..0.701
z-2.95 top=none bot=none belly=none halfw=0.00  z-2.75 top=none bot=none belly=0.63 halfw=0.00  z-2.55 top=0.78 bot=0.42 belly=0.40 halfw=0.16  z-2.35 top=0.94 bot=0.26 belly=0.25 halfw=0.24  z-2.15 top=1.10 bot=0.26 belly=0.24 halfw=0.28  z-1.95 top=1.30 bot=0.22 belly=0.22 halfw=0.36  z-1.75 top=1.54 bot=0.18 belly=0.16 halfw=0.44  z-1.55 top=1.66 bot=0.06 belly=0.09 halfw=0.52  z-1.35 top=1.70 bot=-0.10 belly=-0.01 halfw=0.52  z-1.15 top=1.74 bot=-0.26 belly=-0.11 halfw=0.68  z-0.95 top=1.70 bot=-1.50 belly=-0.20 halfw=0.60  z-0.75 top=1.66 bot=-1.46 belly=-0.33 halfw=0.64  z-0.55 top=1.62 bot=-0.86 belly=-0.41 halfw=0.68  z-0.35 top=1.62 bot=-0.38 belly=-0.42 halfw=0.68  z-0.15 top=1.58 bot=-0.38 belly=-0.42 halfw=0.68  z+0.05 top=1.54 bot=-0.38 belly=-0.41 halfw=0.68  z+0.25 top=1.50 bot=-0.38 belly=-0.40 halfw=0.64  z+0.45 top=1.42 bot=-0.34 belly=-0.35 halfw=0.60  z+0.65 top=1.38 bot=-0.26 belly=-0.29 halfw=0.56  z+0.85 top=1.38 bot=-0.30 belly=-0.22 halfw=0.56  z+1.05 top=1.34 bot=-0.38 belly=-0.15 halfw=0.60  z+1.25 top=1.26 bot=-0.42 belly=-0.08 halfw=0.60  z+1.45 top=1.18 bot=-1.46 belly=0.00 halfw=0.56  z+1.65 top=1.06 bot=-1.46 belly=0.18 halfw=0.48  z+1.85 top=0.90 bot=-0.62 belly=0.40 halfw=0.36  z+2.05 top=0.70 bot=0.62 belly=0.61 halfw=0.04  z+2.25 top=0.54 bot=0.42 belly=0.39 halfw=0.04  z+2.45 top=0.34 bot=0.18 belly=0.17 halfw=0.04  z+2.65 top=0.14 bot=0.02 belly=0.00 halfw=0.04  z+2.85 top=none bot=none belly=none halfw=0.00
FEET (mesh below the barrel): z-1.05 x -0.32..0.32 low -1.47 | z-0.95 x -0.40..0.40 low -1.45 | z-0.85 x -0.40..0.40 low -1.45 | z-0.75 x -0.40..0.40 low -1.30 | z+1.35 x -0.36..0.36 low -1.44 | z+1.45 x -0.44..0.44 low -1.46 | z+1.55 x -0.44..0.44 low -1.33
#### female trunk 1.700,2.550,4.675  drawn 1.202,2.647,4.675
mesh centre in trunk frame 0.000,0.049,0.000 -> y -1.275..1.372  z -2.338..2.338  x -0.601..0.601
z-2.54 top=none bot=none belly=none halfw=0.00  z-2.34 top=none bot=none belly=0.44 halfw=0.00  z-2.14 top=0.56 bot=0.24 belly=0.23 halfw=0.12  z-1.94 top=0.76 bot=0.12 belly=0.12 halfw=0.20  z-1.74 top=0.96 bot=0.16 belly=0.15 halfw=0.28  z-1.54 top=1.12 bot=0.12 belly=0.11 halfw=0.32  z-1.34 top=1.28 bot=0.08 belly=0.07 halfw=0.40  z-1.14 top=1.32 bot=0.04 belly=0.01 halfw=0.48  z-0.94 top=1.32 bot=-0.12 belly=-0.11 halfw=0.56  z-0.74 top=1.28 bot=-1.24 belly=-0.23 halfw=0.48  z-0.54 top=1.24 bot=-1.12 belly=-0.32 halfw=0.56  z-0.34 top=1.28 bot=-0.52 belly=-0.34 halfw=0.56  z-0.14 top=1.24 bot=-0.40 belly=-0.34 halfw=0.56  z+0.06 top=1.24 bot=-0.32 belly=-0.35 halfw=0.56  z+0.26 top=1.20 bot=-0.32 belly=-0.34 halfw=0.56  z+0.46 top=1.16 bot=-0.28 belly=-0.30 halfw=0.52  z+0.66 top=1.16 bot=-0.28 belly=-0.24 halfw=0.52  z+0.86 top=1.12 bot=-0.32 belly=-0.17 halfw=0.52  z+1.06 top=1.08 bot=-0.36 belly=-0.08 halfw=0.52  z+1.26 top=0.96 bot=-1.24 belly=0.04 halfw=0.48  z+1.46 top=0.84 bot=-1.16 belly=0.50 halfw=0.36  z+1.66 top=0.68 bot=0.52 belly=0.52 halfw=0.12  z+1.86 top=0.48 bot=0.40 belly=0.40 halfw=0.04  z+2.06 top=0.32 bot=0.20 belly=0.17 halfw=0.04  z+2.26 top=0.12 bot=0.00 belly=0.01 halfw=0.04  z+2.46 top=none bot=none belly=none halfw=0.00
FEET (mesh below the barrel): z-0.84 x -0.33..0.31 low -1.23 | z-0.74 x -0.33..0.35 low -1.19 | z-0.64 x 0.15..0.15 low -1.07 | z+1.16 x -0.33..0.35 low -1.24 | z+1.26 x -0.37..0.35 low -1.15 | z+1.36 x -0.17..-0.17 low -1.10
#### cub trunk 0.900,1.350,2.475  drawn 0.618,1.439,2.475
mesh centre in trunk frame 0.000,0.044,0.000 -> y -0.675..0.764  z -1.237..1.237  x -0.309..0.309
z-1.44 top=none bot=none belly=none halfw=0.00  z-1.24 top=none bot=none belly=0.31 halfw=0.00  z-1.04 top=0.45 bot=0.13 belly=0.11 halfw=0.08  z-0.84 top=0.69 bot=0.13 belly=0.12 halfw=0.16  z-0.64 top=0.73 bot=0.13 belly=0.10 halfw=0.20  z-0.44 top=0.73 bot=-0.67 belly=-0.06 halfw=0.28  z-0.24 top=0.61 bot=-0.31 belly=-0.13 halfw=0.24  z-0.04 top=0.61 bot=-0.07 belly=-0.11 halfw=0.24  z+0.16 top=0.65 bot=-0.07 belly=-0.11 halfw=0.24  z+0.36 top=0.65 bot=-0.07 belly=-0.08 halfw=0.24  z+0.56 top=0.65 bot=-0.15 belly=-0.03 halfw=0.28  z+0.76 top=0.53 bot=-0.63 belly=0.11 halfw=0.20  z+0.96 top=0.37 bot=0.33 belly=0.32 halfw=0.04  z+1.16 top=0.21 bot=0.21 belly=0.18 halfw=0.00  z+1.36 top=none bot=none belly=none halfw=0.00
FEET (mesh below the barrel): z-0.44 x -0.17..0.19 low -0.65 | z-0.34 x 0.07..0.07 low -0.53 | z+0.66 x -0.17..0.19 low -0.64 | z+0.76 x -0.21..-0.09 low -0.59```

## 3. THE FIT, THREE CYCLES, SAME INSTRUMENT (`284-autofit.luau`)

Each box grows one 0.04-stud step at a time from a seed, a step accepted only while all three of its
projections -- (y,z) from the flank, (x,z) from above, (x,y) from the front -- still lie INSIDE the
drawn mesh's matching silhouette. A box like that cannot be met by an axis ray that misses the mesh.

| cycle | change | measured | distance to target (AIR 0) |
|---|---|---|---|
| 1 | twelve cages at fixed fractions of the drawn box, with separate dorsal bands | 2 bands had **NO SEED** (their `fy` floor of 0.890 is above the back line at the rear, because the back SLOPES) and the third rear cage grew a 0.08 x 0.16 x 0.16 box on the TAIL | not measurable: three cages produced nothing |
| 2 | the band's floor is MEASURED per span (the minimum back line over that span, `backMin`), the slab is capped there, and every cage's z edge is SNAPPED to the grid so neighbouring slabs share a face | 15 boxes per kind, no NO-SEED, tiles abut | fit complete, not yet verified |
| 3 | nothing changed -- the same four-direction sweep as the before, over the built animal | **AIR 0.0 % on all four kinds from all four directions** | **0: met** |

### Cycle 3, the after, verbatim (`284-fit.luau`, the same probe as 1)

```
male: trunk 2.00,3.00,5.50  drawn mesh 1.401,3.257,5.500  hittable=15 (ZonesOnly=true)
  FLANK   rays=2944  animal=814: HIT 618 (75.9%) MISS 196 (24.1%) | box hits=618: AIR 0 (0.0%)
  ABOVE   rays=1728  animal=506: HIT 414 (81.8%) MISS 92 (18.2%) | box hits=414: AIR 0 (0.0%)
  FRONT   rays=1242  animal=336: HIT 254 (75.6%) MISS 82 (24.4%) | box hits=254: AIR 0 (0.0%)
  BEHIND  rays=1242  animal=336: HIT 254 (75.6%) MISS 82 (24.4%) | box hits=254: AIR 0 (0.0%)
female: trunk 1.70,2.55,4.68  drawn mesh 1.202,2.647,4.675  hittable=15 (ZonesOnly=true)
  FLANK   rays=2255  animal=560: HIT 407 (72.7%) MISS 153 (27.3%) | box hits=407: AIR 0 (0.0%)
  ABOVE   rays=1320  animal=370: HIT 311 (84.1%) MISS 59 (15.9%) | box hits=311: AIR 0 (0.0%)
  FRONT   rays=984  animal=232: HIT 176 (75.9%) MISS 56 (24.1%) | box hits=176: AIR 0 (0.0%)
  BEHIND  rays=984  animal=230: HIT 176 (76.5%) MISS 54 (23.5%) | box hits=176: AIR 0 (0.0%)
cub: trunk 0.90,1.35,2.47  drawn mesh 0.618,1.439,2.475  hittable=15 (ZonesOnly=true)
  FLANK   rays=957  animal=160: HIT 86 (53.8%) MISS 74 (46.2%) | box hits=86: AIR 0 (0.0%)
  ABOVE   rays=495  animal=106: HIT 82 (77.4%) MISS 24 (22.6%) | box hits=82: AIR 0 (0.0%)
  FRONT   rays=435  animal=64: HIT 36 (56.2%) MISS 28 (43.8%) | box hits=36: AIR 0 (0.0%)
  BEHIND  rays=435  animal=64: HIT 36 (56.2%) MISS 28 (43.8%) | box hits=36: AIR 0 (0.0%)
legendary: trunk 2.70,4.05,7.43  drawn mesh 1.891,4.397,7.425  hittable=15 (ZonesOnly=true)
  FLANK   rays=4648  animal=1481: HIT 1102 (74.4%) MISS 379 (25.6%) | box hits=1102: AIR 0 (0.0%)
  ABOVE   rays=2822  animal=930: HIT 784 (84.3%) MISS 146 (15.7%) | box hits=784: AIR 0 (0.0%)
  FRONT   rays=1904  animal=610: HIT 466 (76.4%) MISS 144 (23.6%) | box hits=466: AIR 0 (0.0%)
  BEHIND  rays=1904  animal=609: HIT 466 (76.5%) MISS 143 (23.5%) | box hits=466: AIR 0 (0.0%)```

## 4. WHERE THE REMAINING MISSES ARE (`284-holes.luau`, 0.05-stud grid)

AIR is 0; its honest complement is under-coverage, and L-122 says a non-zero remainder is a LOCATED
defect and not a score. Uncovered flank cells, sorted by region:

```
male: worst DORSAL gap 0.60 studs at z -1.50 (65 of 123 columns short by more than one cell) | uncovered flank cells: back 138, belly 144, legs 99, nose/jaw 75, tail 103, other 280
female: worst DORSAL gap 1.60 studs at z +1.51 (49 of 106 columns short by more than one cell) | uncovered flank cells: back 110, belly 133, legs 57, nose/jaw 54, tail 86, other 256
cub: worst DORSAL gap 0.70 studs at z +0.81 (29 of 62 columns short by more than one cell) | uncovered flank cells: back 102, belly 64, legs 18, nose/jaw 26, tail 25, other 71
legendary: worst DORSAL gap 2.75 studs at z +2.39 (120 of 161 columns short by more than one cell) | uncovered flank cells: back 264, belly 238, legs 193, nose/jaw 123, tail 233, other 530```

The named places, read off the fit itself: the **hoof below y -1.06** (the shaft narrows past any box
the three silhouettes allow), the **0.12-stud strip at the very top of the mane crest** (the band is
limited by the minimum back line over its span, and the crest rises 0.12 above it), the **snout's
tip**, the **tail past z +1.91** (half-width 0.04 -- it is a tail), a **0.12-stud slot at
z -1.41..-1.29** where the shoulder slab could not grow forward to the head box's line, and the
**0.04-0.12 stud joins between the rear slabs** where the rump's cross-section refused the next step.

For scale: the male's 75.9 % covered flank is BETTER than the stag's shipped 65.7 % and the cub's
53.8 % is in family with the calf's 50.8 %, so this is within the standard tasks 280 and 281 set.

## 5. WHAT IS NOT MEASURED, AND NOBODY HAS SEEN

No shot has been fired at a boar on Karen's path with this hitbox, and **no ZONE_TINT frame has been
drawn or looked at** -- rule 5 is OPEN. The suite has not been run green either; `ESCALATE.md`
(2026-10-27, task 284) says which five spec files encode the old contract and what the one full run
attempted cost. **This is unproven on screen.**
