# Review request — Task 193: the ground each reference frame shows, and the muster off the track

Task: 193
Round: 2
Base: `c02f65e` (main, PR #181 merged)
Code commit: `e7d583dc4f2480d196ac94f8027d916045161850`

Harness, clean tree, at the code commit:

```
[harness] PASS: 33/33 checks @ e7d583dc4f2480d196ac94f8027d916045161850 (clean tree) scope=all
```

The token printed is **`scope=all`, not `auto:…`** — `tools/studio_mcp.py` is in this branch's diff
(the `places` blast-radius rows) and resolves to `all` by its own rule, so the run played the whole
suite and is full merge evidence. Read off the log, not assumed (L-079). `test2` **N/A**: nothing in
`TWO_PLAYER_PATHS`.

`e7d583d` is the paperwork commit carrying round 1's `RESULT.md`; the last commit to touch `src/` or
`tests/` is its parent `fcffa1f`, so the line covers all the code and is the stricter bound.

## Round 1's two blocking findings

**F1. The painted strip did not follow place 1's road, so the Director's point 3 was not fixed.**
`paint` takes one z per chunk and **my own header's justification for a 200-stud chunk was
arithmetically false** — it claimed *"a 5-stud error … inside the band's own half-width"* on the
grounds that *"no shipped plan paints a curve"*, when place 1 **is** the curve and had just been given
a surface row. 200 studs is 2.86 rad of a 440-stud wavelength, so the error reaches the full
amplitude: the Reviewer computed the chunk [2630, 2830] painted at z −2080.7…−2058.7 against the
road's own −2105.4 at x 2830, **21 studs outside**, leaving stands 2 and 8 — two of the five measured
as grass — still grass.

**And my own "Ground 41/41 along" could not have seen it:** I sampled x 2630…3430, the middle third,
which is the part of Karen's road that was *already* `Ground`. The grass was at stands 1, 2, 7, 8, 9,
outside that span. That is L-086 again — measure at the spot the complaint is about.

FIXED: `Ground.chunkFor` derives the chunk from the curve — `2 × (half − RESOLUTION) × w / a`, which is
**32 studs** for place 1 and the full 200 for a straight line. **Verify, live, over the FULL span this
time:** `ROAD along its full span (81 samples): Ground 80, Grass 1`, and **`Ground` at all nine
stands** (s1…s9). **With no world:** `places.spec`, *"paints a band the line never leaves, on the one
place that curves"* — it samples `roadZ(x)` every 5 studs across the whole plot and asserts each
sample, **and every stand**, lies inside some painted region. The material case could not see this; it
checked material, resolution and grid alignment, all of which were right.

**F2. The ride's ruts were painted 8 studs wide, not the 4 the code and the request claimed** — wider
than the 6 the Director had just rejected. `ExpandToGrid` rounds **outward**, and the ride's line z is
a multiple of 4, so a nominal [−4530, −4526] became [−4532, −4524]; the forest road escaped it only
because its z sits 2 off the grid. **The shipped width depended on the accident of each line's
parity.** FIXED: `Ground.bandBounds` snaps the z bounds before the region is built, so the nominal
width is `ceil(2 × half / 4) × 4` for every line. **Verify:** `places.spec`, *"paints a band exactly as
wide as it was asked for, whatever the line's parity"* — eight line parities, 4-stud and 64-stud bands.

**The harness then caught a third thing, in my fix for F1** (`places.spec:827`): a grid-snapped band is
**not symmetrical** about the line — it reaches `half` below the chunk's centre but only
`half − RESOLUTION` above it in the worst phase, so chunk 51 let the line wander 10.9 studs into an
upward reach of 8. The chunk now pays for the snap. It is in `fcffa1f` with its own commit message.

---

## The ground under each place — the table Karen asked for

In `docs/research/2026-10-17-four-driven-hunt-places.md` §4.4, committed with the code (L-037).

| place | reference | strip | ruts | left alone |
|---|---|---|---|---|
| 1 `road` | ref-7, pale gravel road | **`Ground`**, 24 studs | none — a graded road, not a pair of ruts | its wood and its geometry (BRIEF D3) |
| 2 `edge` | ref-6, field edge | **nothing** | — | the whole field: `Ground` there would be a *ploughed* field |
| 3 `ride` | ref-5, grassy ride | **`Grass`**, 64 studs | two **`Mud`** strips at ±12 | the verges |
| 4 `track` | ref-1, brown dirt track | **`Ground`**, 20 studs | two **`Mud`** strips at ±6 | the belts' floor |

**Karen's *"brown floor, not green lawn"* is answered on the TRACKS and NOT on the forest FLOOR**
between the trunks, which is still this world's grass with a fern every 22–26 studs. `Ground` is the
brownest thing the engine gives per region; `Terrain.MaterialColors` is **global** and would recolour
the lodge's lawn and the whole existing wood. Closing the floor means ~692,000 voxels per place against
a strip's ~58,000. Stated, not faked.

## Claims

**1. Place 1 is a road at every stand** (F1 above): `Ground` 80/81 along its full span, `Ground` at
s1–s9, where it was `Grass` at five of nine.

**2. Places 3 and 4 are not grey** (round 1's measurements, re-checked): the ride's strip is `Grass`
with `Mud` ruts and `Asphalt` only outside it; the track's is `Ground`/`Mud` inside, `Grass` outside.
**Verify:** `places.spec`, *"paints the ground each reference frame shows, per place"* — asserts each
place's material against the table, that `Asphalt` **is** among the sources used (the whole of the
fix), that no band replaces a material with itself, and that every region is grid-aligned.

**3. The cut line's beaters no longer muster on the forest road's track** (193a(a)). The line moved 40
studs south (z −4500 → **−4540**), muster **−3960, 39 studs clear** of that lane. The **only**
candidate that keeps the sight line: −4540 holds 400 studs at every stand, −4560/−4580/−4600 collapse
to 52/62/18. **Verify:** `places.spec`, *"musters the beaters in cover, not on another place's
track"*.

**4. Nothing else regressed.** 33/33 at the code commit, so every case from the three earlier passing
rounds still holds. Live boot: `3 dressed, 3028 planted (6932 parts), 0 skipped, 863 on a step, 0
missing, 720 paint call(s), 2.76s`.

**5. Smoke PASS** (90 s, Forest Test, lobby loop): `gun in hand @15s=1 @90s=1 | stacks=0 errorLines=0 |
waves=10`, `position @15s=ok @end=ok respawn+10s=ok`. Both selftests PASS. CI green.

## The frames, each looked at next to its reference

First person, on a stand, in a real drive, camera at the character's own eye height. The capture
cannot be aimed during Play — the client owns the look direction — so each is the hunter looking
**north at his drive**.

* **`193-p1c-north.png` (place 1, vs ref-7) — the Director's point 3 is answered.** He stands **on** a
  tan road that fills the bottom of the frame, green grass verge above it, open birch forest beyond.
  `WHERE`: stand 5, x 3030, z −2097, `off=0.0`, `under=Terrain`.
* **`193-p4c-north.png` (place 4, vs ref-1).** A brown dirt track running away north between close
  conifers and young firs. Not asphalt.
* **`193-p3d-north.png` (place 3, vs ref-5) — the material is fixed and the frame STILL READS DARK,
  and I am not claiming otherwise.** Measured `Grass` with `Mud` ruts; the mid-distance shows lit
  green grass with blades; the near field at the stand is dark grey-green. **That is shade, not
  asphalt** — the ride sits between two 230-stud belts of tall conifers, which is a consequence of my
  own density work, not of the paint. Ref-5 is an open, overcast, well-lit ride. **This is the one of
  the three I would not call matched**, and the fix is a look decision (thinner or shorter belts on
  the sunward side, or leave it — a `Schneise` between tall stands genuinely is shaded).
* **The muster is a measurement, not a frame**: z −3960 against the lane edge −3921, asserted by the
  spec. A frame of seven bots 580 studs up a ride is a frame of trees.

## What I could not verify, and what I got wrong

* **The ride's frame still reads dark** (above). Measured grass, looks shaded.
* **The rut's PAINTED width is still not 4 studs in the world.** Sampling across the ride every 2
  studs reads `Mud` over about 6–8 studs per rut against a 4-stud band. `bandBounds` makes the band
  deterministic and the spec proves that, but the terrain's own voxel quantisation is reporting wider
  than the band asked for and **I have not run that to ground.** Queued, not claimed as fixed.
* **720 `ReplaceMaterial` calls against the design's ≤ 12.** The design sized that for one place, one
  band, two sources; it is now three places, three bands, ten sources and a 32-stud chunk on the
  curve. It costs nothing measurable inside a 2.76 s one-off boot, but the design row is stale and is
  queued.
* **My first "Ground 41/41" measurement sampled the span that could not fail** (F1). The Reviewer
  found it by arithmetic, not me.
* **The capture cannot be aimed in Play**, so none of the frames is the along-the-track framing two of
  Karen's references use.
* **Karen has seen none of it.** Every look decision is hers.
* **Round 3's other notes are still queued, not fixed** (TASKS.md 193a): the design-delta backlog,
  `Places.plotOf`'s self-referential case, and `clearOfEveryLane` treating a lane as infinite in x.
