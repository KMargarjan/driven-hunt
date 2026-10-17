# Review request — Task 193: the ground each reference frame shows, and the muster off the track

Task: 193
Round: 1 (the previous review PASSED at `24b4fec`; this is new code, so the count restarts)
Base: `c02f65e` (main, PR #181 merged)
Code commit: `168df4812635e13d8043eddd25be32ae3034a472`

Harness, clean tree, at the code commit:

```
[harness] PASS: 33/33 checks @ 168df4812635e13d8043eddd25be32ae3034a472 (clean tree) scope=all
```

That is `test --scope auto`, and the token it printed is **`scope=all`, not `auto:…`** — `tools/studio_mcp.py`
is in this branch's diff (it gained the `places` blast-radius rows) and that file resolves to `all` by
its own rule, so the scoped run played the whole suite. It is therefore full evidence for the merge
gate as well (read off the log, not assumed — lesson L-079). `test2` is **N/A**: nothing in
`TWO_PLAYER_PATHS` is touched.

## What changed, and why

The Director put the first build's frames next to Karen's references and named three things. **All
three were measurable and all three were true.**

| he said | measured |
|---|---|
| place 3 *"the hunter stands on GREY ASPHALT-LOOKING ground"* | the cut line's strip is **13 of 42** samples `Asphalt` |
| place 4 *"grey ground again"* | the forest road's is **23 of 42** — more than half |
| place 1 *"shows grass and an oak and NO ROAD"* | its own line is `Ground` 31 / **`Grass` 29** over 65 samples, and the grass is at stands **1, 2, 7, 8, 9** — the road Karen built covers its middle third only, so a hunter on five of nine stands is standing in a field |

**And the first paint could not have fixed any of it.** `Ground.SOURCE_MATERIALS` was Grass and
LeafyGrass only, on the argument that the world's rock *"is the world's own rock and made ground"* —
which skipped exactly the patches he objected to.

---

## The ground under each place now — the table Karen asked for

Committed **with this code**, in `docs/research/2026-10-17-four-driven-hunt-places.md` §4.4, not after
it (lesson L-037). `places.spec` asserts this table.

| place | reference | strip | ruts | left alone |
|---|---|---|---|---|
| 1 `road` | ref-7, pale gravel road | **`Ground`**, 22 studs | none — a graded road, not a pair of ruts | its wood and its geometry (BRIEF D3) |
| 2 `edge` | ref-6, field edge | **nothing** | — | the whole field: `Ground` there would be a *ploughed* field, a different place from her frame |
| 3 `ride` | ref-5, grassy ride | **`Grass`**, 64 studs | two **`Mud`** strips, 4 studs wide at ±12 | the verges, which keep the world's own grass |
| 4 `track` | ref-1, brown dirt track | **`Ground`**, 18 studs | two **`Mud`** strips, 4 studs wide at ±6 | the belts' floor |

**Karen's *"brown floor, not green lawn"* is answered on the TRACKS and NOT yet on the forest FLOOR**
between the trunks, which is still this world's grass with a fern every 22–26 studs. `Ground` is the
brownest thing the engine gives per region; `Terrain.MaterialColors` would be browner and is
**global** — it would recolour the lodge's lawn and the whole existing wood with it, which is not ours
to decide. Closing the floor gap means painting ~692,000 voxels per place against a strip's ~58,000.
Stated, not faked.

---

## Claims

**1. Every strip is the material its reference shows, measured across and along it after the paint.**
Across the middle stand every 4 studs, and along each strip at 41 samples:
* `ride` across: `Grass` from −32 to +28 with `Mud` ruts, `Asphalt` only **outside** the strip (±32+).
  **Along: `Grass` 41/41.**
* `track` across: `Ground`/`Mud` inside the strip, `Grass` outside. Along: `Mud`/`Ground` 41/41.
* `road` across: `Ground` ±32 with `Mud` ruts. **Along: `Ground` 41/41** — a continuous road where 29
  of 65 samples were grass.
**Verify:** `places.spec`, *"paints the ground each reference frame shows, per place"* — it drives the
real `Ground.paint` with a recording fake terrain, asserts each place's material against the table
above, asserts `Asphalt` **is** among the sources used (the whole of the fix), that no band replaces a
material with itself, and that every region is on the 4-stud grid.

**2. Two wheel ruts, and the frames are why they are narrow.** The first paint's ruts filled the near
view (ride ±9, 6 studs wide) and the forest road's **merged** — at ±4 the voxel grid snapped them
together and the whole 18-stud track came back `Mud` with no litter between. Now ride ±12 / 4 studs
(20 studs of grass between them) and track ±6 (the middle 8 studs stay `Ground`). **Verify:**
`places.spec`, *"lays two wheel ruts over the strip, and only where a frame shows them"* — a rut must
fit inside its strip, its material differs from the strip's, the road has none, and the ruts are
painted **after** the strip (the other order paints them straight back over, now that the strip's own
material is in `SOURCE_MATERIALS`).

**3. `SURFACES` is its own table, apart from `PLANS`, and `road` is why.** Painting and planting are
different questions: `road` keeps task 179's wood exactly (BRIEF D3) and so has **no planting plan at
all**, but it is the place named for a road. **Verify:** `Places.SURFACES` / `Places.surfaceFor`, and
`Places.build`'s loop, which asks the two separately. `places.spec`'s *"dresses every layout that is
not the road"* still asserts `planFor("road") == nil`, and the paint case asserts `surfaceFor("road")`
is not nil.

**4. The cut line's beaters no longer muster on the forest road's track (TASKS.md 193a(a)).** They
mustered at z −3920, inside that place's lane (−3921…−3879). The line moved **40 studs south, z −4500
→ −4540**, so the muster is **−3960, 39 studs clear**. It is the **only** candidate that keeps the
sight line: measured, −4540 holds **400 studs at every stand** while −4560, −4580 and −4600 collapse
to **52, 62 and 18**. **Verify:** `places.spec`, *"musters the beaters in cover, not on another
place's track"* — for every dressed place, the muster z is outside every **other** place's lane across
the stands' own x span. Live: `layout=ride … centre (4900, -4540), exit -4790`.

**5. Nothing else regressed.** `[harness] PASS: 33/33 … scope=all` at the code commit, so every case
from the three passing rounds still holds: the rotation, the cross-place lane rule, the stand circles,
`plantOne` on a fake hillside, the belt reaching the muster, the resting wood. Live boot:
`3 dressed, 3028 planted (6932 parts), 0 skipped, 863 on a step, 0 missing, 342 paint call(s), 2.65s`.
**342 paint calls against the design's *≤ 12*, and the reason is this change**: ten source materials ×
three bands × the chunks of three places. Reported as measured, not hidden — the whole paint is still
inside 2.65 s of a one-off boot.

**6. Smoke PASS on the player's path.** 90 s, Forest Test, the lobby loop:
`gun in hand @15s=1 @90s=1 | stacks=0 errorLines=0 | waves=10`,
`position @15s=ok @end=ok respawn+10s=ok`, **SMOKE PASS**. Both selftests PASS.

---

## The frames, each looked at next to its reference

All four are **first person, on a stand, in a real drive**, camera at the character's own eye height
(~2.5 studs above his feet). The capture cannot be aimed during Play — the client owns the look
direction — so each is the hunter looking **north at his drive**, which is his working view.

* **`193-p1b-north.png` (place 1, vs karen-ref-7) — the Director's point 3 is answered.** He stands
  **on** a pale tan road; it runs away north-west between bare pale trunks with green grass verges
  either side, open high forest beyond. That is ref-7's structure: pale road, green verge, open
  trunks, the sight line along the road and into the wood. `WHERE` confirms stand 5, x 3030, z −2097,
  `off=0.0`, `under=Terrain`.
* **`193-p4c-north.png` (place 4, vs karen-ref-1) — the grey is gone.** A brown dirt track runs away
  north between close conifers and young firs. The immediate foreground is darker (the `Mud` rut plus
  shade); the track itself reads as dirt, not asphalt.
* **`193-p3c-north.png` (place 3, vs karen-ref-5) — the material is fixed and the frame still reads
  DARK, and I am not claiming otherwise.** The strip measures `Grass` 41/41 and the mid-distance shows
  a lit green grass band with blades; the near field at the stand is dark grey-green. **That is shade,
  not asphalt** — the ride sits between two 230-stud belts of tall conifers, so its floor is in deep
  shadow, which is a consequence of my own density work rather than of the paint. Karen's ref-5 is an
  open, overcast, well-lit ride. **This is the one of the three I would not call matched**, and the
  fix is a look decision (thinner or shorter belts on the sunward side, or leave it — a `Schneise`
  between tall stands genuinely is shaded).
* **The muster** is reported as a **measurement and not a frame**: z −3960 against the forest road's
  lane edge −3921, asserted by the spec above. A frame of seven bots standing in trees 580 studs up a
  ride would be a frame of trees; the number is the evidence, and `193-p3c-north.png` is the view up
  that ride.

## What I could not verify, and what I got wrong

* **The ride's stand still reads dark in its frame** (above). Measured Grass, looks shaded.
* **342 `ReplaceMaterial` calls against the design's ≤ 12.** The design sized that for one place, one
  band and two source materials. It is now three places, three bands and ten sources. It costs
  nothing measurable inside a 2.65 s boot, but the design's §11 row is stale and is queued.
* **The capture cannot be aimed in Play**, so none of the four is the along-the-ride framing two of
  Karen's references use (lesson L-021's "same camera position/state" is met for the *stand* and the
  *facing the drive* state, and is **not** met for her along-the-track framing).
* **Karen has seen none of it.** Every look decision is hers.
* **The forest floor between the trunks is still green** — the largest remaining gap from her
  ref-2/3/4, with the two ways to close it and their costs written in the note's §4.4.
* **Round 3's notes other than 193a(a) are still queued, not fixed** (TASKS.md 193a), including the
  design-delta backlog, `Places.plotOf`'s self-referential case, and `clearOfEveryLane` treating a
  lane as infinite in x.
