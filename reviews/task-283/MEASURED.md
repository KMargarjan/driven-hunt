# Task 283 -- the readings

All DEV ONLY (Driven Hunt DEV, Play, 2026-10-27). Probes in `reviews/task-283/probes/`.

## 1. The drawn extent of every kind that draws a card (`283-extent.luau`)

```
male      trunk 2.000,3.000,5.500 | drawn 1.401,3.257,5.500 | local y -1.500..1.757 z -2.750..2.750 x -0.701..0.701 | TRUNK-IN-INK u 0.0000..1.0000 v 0.0790..1.0000 | meshes 1
female    trunk 1.700,2.550,4.675 | drawn 1.202,2.647,4.675 | local y -1.275..1.372 z -2.338..2.338 x -0.601..0.601 | TRUNK-IN-INK u 0.0000..1.0000 v 0.0368..1.0000 | meshes 1
cub       trunk 0.900,1.350,2.475 | drawn 0.618,1.439,2.475 | local y -0.675..0.764 z -1.237..1.237 x -0.309..0.309 | TRUNK-IN-INK u 0.0000..1.0000 v 0.0618..1.0000 | meshes 1
legendary trunk 2.700,4.050,7.425 | drawn 1.891,4.397,7.425 | local y -2.025..2.372 z -3.713..3.713 x -0.946..0.946 | TRUNK-IN-INK u 0.0000..1.0000 v 0.0790..1.0000 | meshes 1
stag      trunk 1.800,4.800,7.050 | drawn 3.467,7.920,7.050 | local y -2.400..5.520 z -3.525..3.525 x -1.733..1.733 | TRUNK-IN-INK u 0.0000..1.0000 v 0.3940..1.0000 | meshes 1
hind      trunk 1.540,4.105,6.030 | drawn 2.008,5.101,6.030 | local y -2.053..3.048 z -3.015..3.015 x -1.004..1.004 | TRUNK-IN-INK u 0.0000..1.0000 v 0.1951..1.0000 | meshes 1
calf      trunk 0.891,2.376,3.490 | drawn 1.234,3.481,3.490 | local y -1.188..2.293 z -1.745..1.745 x -0.617..0.617 | TRUNK-IN-INK u 0.0000..1.0000 v 0.3173..1.0000 | meshes 1
```

Three of the four numbers are the same for every kind and that is a fact about the assets: the drawn
LENGTH equals the trunk's exactly and is centred on it, and the drawn BOTTOM is the trunk's bottom.
Only the top overhangs.

## 2. Four points on each drawn flank, found by ray (`283-flank.luau`)

The withers station came back ABOVE the trunk box on male / legendary / hind / calf (the male's at
y 1.510 against a box top of 1.500) and `MESH=false` on the stag (it fell in the gap under his
antlers). Those are the five points the spec does NOT use as flank evidence; the clamped four are
asserted separately as the dorsal-band reading.

```
male | withers local=(0.649,1.510,-1.210) MESH=true span y -0.180..1.740 uv=(0.2800,0.0000) | chest local=(0.679,0.513,-0.550) uv=(0.4000,0.3290) | belly local=(0.471,-0.137,0.110) uv=(0.5200,0.5456) | rump local=(0.538,0.237,1.540) uv=(0.7800,0.4210) | AIR y=2.550 MESH=false
female | withers uv=(0.2800,0.0448) | chest uv=(0.4000,0.3440) | belly uv=(0.5200,0.5480) | rump uv=(0.7800,0.4340)
cub | withers uv=(0.2800,0.0024) | chest uv=(0.4000,0.3820) | belly uv=(0.5200,0.5128) | rump uv=(0.7800,0.3890)
legendary | chest uv=(0.4000,0.3290) | belly uv=(0.5200,0.5456) | rump uv=(0.7800,0.4210)
stag | withers MESH=false | chest uv=(0.4000,0.0910) | belly uv=(0.5200,0.4600) | rump uv=(0.7800,0.1940)
hind | chest uv=(0.4000,0.4250) | belly uv=(0.5200,0.3920) | rump uv=(0.7800,0.1340)
calf | chest uv=(0.4000,0.3840) | belly uv=(0.5200,0.2672) | rump uv=(0.7800,0.0280)
```

## 3. The card, before and after, against the pictures' own pixels

The harness's own notes, same four cases, same instrument.

```
BEFORE (src reverted to main)          AFTER (31186be7)
27 flank points, 0 off the ink         23 flank points, 0 off the ink
lead pellet img(0.471,0.266) row 16    lead pellet img(0.464,0.151) row 10
air in the box -> ink=TRUE             air in the box -> ink=FALSE
8 fanned pellets, 0 off the ink        8 fanned pellets, 0 off the ink
                                       above the box -- on ink male img(0.290,0.126)
                                       legendary img(0.290,0.126) calf img(0.303,0.380)
                                       | OFF ink hind img(0.296,0.239)
```

Karen's lead pellet (local 1.06, 1.41, -0.21) belongs at image v **0.107** by the drawn geometry
((1.757 - 1.41) / 3.257). It drew at **0.266** before and **0.151** after; the residual is the
half-dot inset, which is a drawing decision and is now taken in the animal's own pixels.

**The old card drew that withers hit too LOW, not too high.** See `ESCALATE.md`, 2026-10-27.

## 4. The pictures

The four uploaded PNGs are cropped to the ink: measured on the bytes whose sha256
`assets/uploads.json` records, the opaque pixels of all four reach every edge (male 947 x 475 ink
cols 0..945 rows 0..473; female 759 x 441 cols 1..757 rows 0..439; stag and hind 0..1 on both axes).
That is why the trunk rectangle's u is 0..1 of the picture.
