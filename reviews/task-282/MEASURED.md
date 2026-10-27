# Task 282 -- the readings

**The blocks below are the probes' own output. Where a line is annotated it says so on the line.**

All DEV ONLY (Driven Hunt DEV, Play, 2026-10-27). Probes in `reviews/task-282/probes/`.

## 1. The staging, and the camera ray on `ZoneChest` (`282-stage.luau`)

```
LOS: ZoneChest zone=chest d=87.66 entry local=(1.06,0.59,-0.59) raydir local=(-1.000,-0.029,-0.007)
kind=male trunk 2.00,3.00,5.50 at 88.7 studs
zones:
  ZoneHead head size=1.20,1.30,1.36 off=0.00,1.00,-2.13
  ZoneChest chest size=2.12,2.01,1.70 off=0.00,0.55,-0.60
  ZoneRear rear size=2.12,1.86,1.80 off=0.00,0.63,2.00
  ZoneLegs legs size=2.12,1.00,5.40 off=0.00,-1.00,0.15
worst zone gap 2.35 studs
DRAWN flank extent: z -2.70..2.70  y -1.50..1.75  x 0.00..0.70
```

The drawn boar is 1.40 wide against a 2.00 box, and its back line reaches y +1.75 against a box top
of +1.50 -- so the animal both FAILS TO FILL the box down each flank and STANDS OUT of it on top.
`BoarAssetsBoot` agrees: `boar.male loaded: ... 1.4011056423187256, 3.2573037147521973, 5.5`.

## 2. One real buckshot shot, nine pellets, at that ray (`282-shotcard.luau`)

`[hitlog]` (`ServerStorage.DHLastHits`), the server's own record. **Two shots, 75 s apart, sharing
one ring** -- round 1's staging probe looked for a `StringValue` child where `HitLog.writeTrace`
writes an ATTRIBUTE, so its "log cleared" did nothing (the Reviewer, round 1; fixed in the committed
probe). **Claim 3 reads `#1`; claims 1 and 2 read the card of `#2`.** Both are the same staging and
the same aim point; they are not one event.

```
#1 t=140.30s male id=Boar1 zone=chest local=(1.06,1.41,-0.21) uv=(0.462,0.030) dist=82.0 shotgun/Buck pellets=9 fatal=no
#2 t=215.77s male id=Boar1 zone=chest local=(1.06,1.40,0.16) uv=(0.530,0.035) dist=85.7 shotgun/Buck pellets=8 fatal=no
```

The card, read off the drawn `Dot` frames (shot #2, 8 of 9 pellets):

```
HitCard visible=true     text: H I T   -   B U C K   8 / 9
art Art vis=true abs=148x80 box u 0.100..0.900 v 0.250..0.713 dots=8
  dot true=(0.517,0.406) zone=chest drawn=(0.513,0.442)
  dot true=(0.530,0.035) zone=chest drawn=(0.523,0.285)
  dot true=(0.590,0.263) zone=body  drawn=(0.569,0.381)
  dot true=(0.332,0.326) zone=chest drawn=(0.394,0.393)
  dot true=(0.310,0.254) zone=chest drawn=(0.333,0.393)
  dot true=(0.535,0.193) zone=chest drawn=(0.527,0.352)
  dot true=(0.260,0.121) zone=chest drawn=(0.317,0.321)
  dot true=(0.413,0.193) zone=chest drawn=(0.434,0.351)
```

## 2b. WHAT THE BACK LINE ACTUALLY IS, AND WHAT THAT MAKES THE CAUSE (`282-why2.luau`)

**ROUND 2'S FINDING WAS RIGHT AND IT REFUTES MY FIRST ANSWER.** I claimed the pellets landed above
the drawn back without ever measuring the back AT THAT z. Measured now -- the highest y at which a
flank ray still meets the drawn mesh, every 0.2 studs:

```
  z-2.8=none z-2.6=0.74 z-2.4=0.90 z-2.2=1.06 z-2.0=1.24 z-1.8=1.46 z-1.6=1.68 z-1.4=1.70
  z-1.2=1.74 z-1.0=1.70 z-0.8=1.66 z-0.6=1.64 z-0.4=1.62 z-0.2=1.60 z+0.0=1.54 z+0.2=1.50
  z+0.4=1.46 z+0.6=1.40 z+0.8=1.38 z+1.0=1.34 z+1.2=1.30 z+1.4=1.24 z+1.6=1.12 z+1.8=0.96
  z+2.0=0.78 z+2.2=0.58 z+2.4=0.40 z+2.6=0.22
hitlog point y=1.41 z=-0.21 : MESH HIT at local x 0.347 | BOX ZoneChest
hitlog point y=1.40 z=0.16 : MESH HIT at local x 0.262 | BOX ZoneChest
```

**Both lead pellets CROSSED THE DRAWN ANIMAL.** At z -0.21 the back is 1.60 and the pellet struck
1.41 -- 0.19 studs INSIDE the boar, on its upper flank at the withers. They were honest hits.

**So the cause of Karen's frame is the CARD'S MAPPING, not the air.** `HitLog.Shape.dot` normalises
y by the **TRUNK** (half-height 1.50): y 1.41 -> v = 0.030, the top of the unit square.
`BoarArt.drawDots` then maps that unit square onto the picture's whole **INK** box
(`Report.imageBox`, v 0.250..0.713), whose top edge is the drawn boar's highest point anywhere --
the mane crest at z -1.2, y 1.74. Two different rectangles: 3.00 studs of trunk stretched over
3.257 studs of animal, and the error is all at the top. **An honest hit on the withers therefore
draws on the mane, at every u** -- Karen's "bunched on the HEAD/NECK" -- and 2.6 px below the ink's
top edge in an 80 px frame is under half a dot, which is her "HALF OUTSIDE the silhouette".
A hit on the trunk's own top (y 1.50) is v = 0, drawn ON the crest line; the back of a boar cannot
be drawn below it at all.

**Reading the rest of it.** u 0.260..0.590 is z_local -1.32..+0.50 and v 0.035..0.406 is
y_local +1.40..+0.28: a pattern 1.8 studs long and 1.1 tall, which is what
`SPREAD_FULL_DEG.Buck = 1.6` gives (a cone 2.29-2.48 studs across at 82-88.7 studs). **The spread
is right.** Every dot is drawn where `BoarArt` places it from the server's `(u, v)` -- two of the
eight are fanned by `BoarArt.spread` onto a 5.94 px ring, by design. **The arithmetic inside the
card is right; the RECTANGLE it is handed is wrong.**

## 3. The complement, BEFORE (`282-fit2.luau`, 0.1-stud grid, four directions)

**ROUND 1'S SWEEP WAS WRONG AND THE REVIEWER CAUGHT IT.** Its box cast used
`bp.FilterDescendantsInstances = { ...zones..., trunk }`, and `FilterDescendantsInstances` takes the
instance AND ITS DESCENDANTS (`src/client/Weapon/Claim.luau` says so in as many words) -- the drawn
mesh is a descendant of the trunk, so EVERY mesh hit was also a box hit and `uncovered` could not be
anything but 0. The Reviewer's prediction was exact: `ZoneHead` tops at +1.650 and the drawn male
reaches +1.757, so a flank row at y 1.70 must be mesh-and-no-box. The diagnostic
(`<runs-dir>/282-why.luau`) shows the contaminated reading in isolation:

```
mesh centre in trunk frame: 0.000,0.129,0.000 -> top 1.757 bottom -1.500
  hittable ZoneHead  top 1.650 (centre y 1.00, size y 1.30)
  hittable ZoneChest top 1.560 (centre y 0.55, size y 2.01)
  hittable ZoneRear  top 1.560 (centre y 0.63, size y 1.86)
  hittable ZoneLegs  top -0.500 (centre y -1.00, size y 1.00)
  hittable Boar1     top 1.500 (centre y 0.00, size y 3.00)
y=1.70  mesh=6 box=6 UNCOVERED=0 at z {}      <- 6 mesh hits at 1.70 with no box above 1.65
```

`282-fit2.luau` casts in TWO PASSES with the mesh's `CanQuery` toggled between them, so neither cast
can see the other's parts. Its output, four kinds, verbatim:

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

**What it says.** AIR is the headline and it is unchanged by the bug (a box hit with no mesh cannot
be a mesh hit): **49.5 % to 59.2 % of every ray that meets a hittable boar meets NO ANIMAL**, on all
four kinds, from every direction (49.5 % is legendary FRONT/BEHIND; the FLANK floor is 53.7 %).
**And there are holes on two of the four kinds**: male FLANK 2.2 %, FRONT/BEHIND 3.9 %; legendary
1.8 % / 3.6 %. Female is 0.2 % and 0.9 %, cub 1.9 % and 0.0 %. The hole is the crest: the drawn
male's mane reaches 1.757 against `ZoneHead`'s top of **1.650** -- **0.107 studs**, not the 0.257
above the TRUNK's 1.500 I wrote in round 2 (legendary 0.145, not 0.347). `ABOVE` is 0 % by
construction -- the mesh's x and z both sit inside the trunk's -- and that is the only forced 0.

**AFTER must be 0 % air AND 0 % miss on every kind.** (L-122: both remainders are located defects,
not progress. The dorsal band is the same regression task 280a names for the deer.)

## 4. The frames, looked at

- `<runs-dir>/282/eye2-male.png` -- player's eye, 12.4 studs, broadside male, zone volumes at 0.78
  over the drawn animal. The boxes' top edge runs clear of the boar's back with sky behind it; the
  tan `ZoneLegs` slab stands about a head's length past the rump and well outside the hooves; there
  is a visible margin of empty box down the near flank.
- `<runs-dir>/282/eye2-cub.png` -- the same, cub.
- `<runs-dir>/282/eye-female.png`, `eye-legendary.png` -- the other two at 0.35 (the volumes read as
  solid there, which is why the two above were re-rendered).
