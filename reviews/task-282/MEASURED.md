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

**Reading it.** u 0.260..0.590 is z_local -1.32..+0.50 and v 0.035..0.406 is y_local +1.40..+0.28:
a pattern 1.8 studs long and 1.1 tall, which is what `SPREAD_FULL_DEG.Buck = 1.6` gives at 89 studs.
So the SPREAD is right. The dots are drawn where the server put them, through the measured ink box
(v 0.250..0.713), so the CARD'S ARITHMETIC is right. What is wrong is that the pellets were allowed
to land at y_local +1.40 -- inside a 3.00-tall box whose top is above the drawn back -- and v 0.035
is 2.8 px below the top of the ink in an 80 px frame, under half a dot. That is Karen's diamond
"HALF OUTSIDE the silhouette in the grey", and at the top of the ink the drawn boar is its mane and
ears, which is her "bunched on the HEAD/NECK".

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
be a mesh hit): **53.7 % to 59.2 % of every ray that meets a hittable boar meets NO ANIMAL**, on all
four kinds, from every direction. **And there ARE holes, 1.8 % to 3.9 % of the visible animal**: the
back line and the mane stand 0.257 studs (male) and 0.347 (legendary) above the tallest box, so a
shot at the top of the back is a MISS today. `ABOVE` is 0 % by construction -- the mesh's x and z
both sit inside the trunk's -- and that is the only sweep where 0 is forced.

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
