# Task 282 -- the readings, verbatim

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

`[hitlog]` (`ServerStorage.DHLastHits`), the server's own record:

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

## 3. The complement, BEFORE (`282-fit.luau`, 0.1-stud grid, four directions)

`HIT` = the ray met the drawn mesh AND a hittable box. `MISS` = mesh, no box. `AIR` = box, no mesh.
"Hittable" is what the weapon can hit: the four zone parts plus the trunk (no `ZonesOnly` today).

```
male: trunk 2.00,3.00,5.50  drawn mesh 1.401,3.257,5.500  hittable parts=5 (ZonesOnly=nil)
  FLANK   on the animal=814: HIT 814 (100.0%) MISS 0 (0.0%) | AIR hits=984   -> 54.7% of box hits are air
  ABOVE   on the animal=506: HIT 506 (100.0%) MISS 0 (0.0%) | AIR hits=691   -> 57.7%
  FRONT   on the animal=336: HIT 336 (100.0%) MISS 0 (0.0%) | AIR hits=341   -> 50.4%
  BEHIND  on the animal=336: HIT 336 (100.0%) MISS 0 (0.0%) | AIR hits=341   -> 50.4%
female: trunk 1.70,2.55,4.68  drawn mesh 1.202,2.647,4.675
  FLANK   on the animal=560: HIT 560 (100.0%) MISS 0 (0.0%) | AIR hits=696   -> 55.4%
  ABOVE   on the animal=370: HIT 370 (100.0%) MISS 0 (0.0%) | AIR hits=512   -> 58.1%
  FRONT   on the animal=232: HIT 232 (100.0%) MISS 0 (0.0%) | AIR hits=238   -> 50.6%
  BEHIND  on the animal=230: HIT 230 (100.0%) MISS 0 (0.0%) | AIR hits=238   -> 50.8%
cub: trunk 0.90,1.35,2.47  drawn mesh 0.618,1.439,2.475
  FLANK   on the animal=160: HIT 160 (100.0%) MISS 0 (0.0%) | AIR hits=212   -> 57.0%
  ABOVE   on the animal=106: HIT 106 (100.0%) MISS 0 (0.0%) | AIR hits=154   -> 59.2%
  FRONT   on the animal= 64: HIT  64 (100.0%) MISS 0 (0.0%) | AIR hits= 82   -> 56.2%
  BEHIND  on the animal= 64: HIT  64 (100.0%) MISS 0 (0.0%) | AIR hits= 82   -> 56.2%
legendary: NOT MEASURED -- the drawn mesh did not load on the run that measured the other three
  (the probe keyed the template on the KIND and `legendary` asks for the `male` MODEL). Fixed in
  `282-pose.luau`/`282-fit.luau` afterwards and the frame shows the mesh; the sweep was not re-run.
```

**AFTER is 0 % air and 0 % miss on every kind. Today every kind measured is over half air from the
flank, which is where a drive is shot from.** (L-122: that remainder is not progress, it is the
located defect, and it is the whole of it -- there are no holes in the boar, only air.)

## 4. The frames, looked at

- `<runs-dir>/282/eye2-male.png` -- player's eye, 12.4 studs, broadside male, zone volumes at 0.78
  over the drawn animal. The boxes' top edge runs clear of the boar's back with sky behind it; the
  tan `ZoneLegs` slab stands about a head's length past the rump and well outside the hooves; there
  is a visible margin of empty box down the near flank.
- `<runs-dir>/282/eye2-cub.png` -- the same, cub.
- `<runs-dir>/282/eye-female.png`, `eye-legendary.png` -- the other two at 0.35 (the volumes read as
  solid there, which is why the two above were re-rendered).
