# Task 207 — the stand circle is ONE ring, not broken pieces

Task: 207
Round: 1
Base: main @ `3c13418`
Code commit: `df56e00cad36ac9a62fd6aeb916ddb7edb1cea3f`

Harness, clean tree, FULL run (the merge-gate line):

```
[harness] PASS: 33/33 checks @ df56e00cad36ac9a62fd6aeb916ddb7edb1cea3f (clean tree) scope=all
```

`test2`: **N/A.** Nothing this task touches is in `TWO_PLAYER_PATHS` — the change is
`src/server/ForestTest/Markers.luau` and `tests/server/forest_markers.spec.luau`, and that list is
`src/server/Match/`, `MatchBoot`, `src/client/Match/`, `src/shared/Drive/`, `tests/client/Role.luau`
and the match specs. (The *scope* table maps `src/server/ForestTest/` to the `match` SCOPE, which is
a different table and decides which specs a `--scope auto` run must play, not who runs it.)

## What changed, and why

Karen, 2026-10-18 ~14:20, on the road line's stand 6: *"and this is not circle is broken one"*
(`<runs-dir>/karen-2026-10-18/shot-8.png`).

Task 166 drew the stand's edge as twenty 3.8-stud boxes, each **level** and placed at the ground
reading under its own **middle**. A level slab cannot touch sloping ground at both ends: its uphill
half goes under the hill, its downhill half hangs over it, and two neighbours meet at a vertical
step. That is the picture she sent.

`Markers.ring` now draws a **polyline on the ground**: the ground is read at the ring's **vertices**
(shared by two segments, so a step is impossible, not merely small), each segment is **tilted** along
its own chord and **rolled** to the cross-slope measured either side of its middle, there are **48**
of them, they **overlap** by 0.12 studs, and a vertex the two readers disagree on **falls back to the
terrain reader and is counted** instead of deleting the segment. Same colour, same width, same
transparency, same lift, same `CanQuery = false`.

## Claims

1. **The defect was reproduced first, on her path, before anything changed** (rule H). Her screenshot
   is the road line. All 25 stands of all four layouts were measured in her Forest Test
   (place 130094961655666) on the pre-fix commit, by drawing the real ring through the real
   `Markers.ring` and sampling each drawn part's **bottom face** at 15 footprint points against
   `ForestTest.terrainYAt` at each sample's own x,z. Worst over all 25: **buried 1.06, floating 1.56,
   neighbour ends 2.48 studs apart — all three at road stand 6**, which is her stand.
   *Verify:* `<runs-dir>/t207-measure.luau` and the per-stand table in the report; the before frame
   `<runs-dir>/t207-before-worst.png`, camera at (3180, **157.0**, −2071.8), ground there 152.03, so
   **4.97 studs = eye height**, looking at the worst joint.
2. **The same measurement after the change, same 25 stands, same sampling**: buried **0.21**,
   floating **0.16**, least overlap at any joint **0.114** studs (positive — the ends pass each
   other), worst step at a joint **0.025**. Pre-fix the two ends sat at the same x,z with different
   y, so the whole 2.48 was step and the overlap was zero.
   *Verify:* the after frames `<runs-dir>/t207-after-worst.png` (the same camera as claim 1) and
   `<runs-dir>/t207-after-worstspot.png` (eye height at the measured worst spot).
3. **The ground is read at each vertex's own x,z, and never once per stand** (lessons L-024/L-025).
   *Verify:* `Markers.ring`'s first loop builds `points[index]` from `home.X + cos(a) * radius`,
   `home.Z + sin(a) * radius` and calls `Markers.ringGroundFor` for that point alone. The readers
   are `ForestTest.terrainYAt` and `Data.groundAt`, both of which start their own ray above the
   point they are asked about.
4. **Two neighbours cannot step, by construction**: `points` is built once and segment `index` spans
   `points[index] → points[index % count + 1]`, so the shared vertex is ONE reading used by both.
   *Verify:* `Markers.ring`; and `forest_markers.spec`'s *"meets itself on a slope"*, which asserts
   the signed overlap along the successor's own axis is positive and the perpendicular miss < 0.03.
5. **Each segment lies ON the hill.** `Markers.ringUp` takes the surface normal as the cross product
   of the two tangents — the chord itself, and `across + yAxis * slope` where `slope` is read
   `THICKNESS_STUDS / 2` either side of the middle — so the box's bottom face is parallel to the
   ground rather than square to the world.
   *Verify:* `Markers.ringUp`; and `forest_markers.spec`'s *"lies ON the slope"*, which samples every
   segment's bottom face and asserts nothing is under the ground at all.
6. **The new cases FAIL on the pre-fix code, and the failing numbers were measured, not guessed**
   (lesson L-028). Run against the pre-fix commit in a live Forest Test server, on the spec's own
   plane of slope 0.5: **neighbour ends 1.854 studs apart, worst buried 0.927, worst floating
   0.967** (`<runs-dir>/t207-slope-prefix.luau`). The new cases require overlap > 0.06, step < 0.03,
   buried ≤ 0 and floating < 0.13.
7. **A disagreement between the two ground readers no longer puts a hole in the circle.**
   `Markers.ringGroundFor` falls back to the TERRAIN reader and counts it in
   `stats.lastRingFallbacks`. `Markers.build`'s refusal for a STAND is untouched — a stand nobody can
   measure still must not be stood on.
   *Verify:* `Markers.ringGroundFor`, `Markers.build` (unchanged), and `forest_markers.spec`'s
   *"keeps the circle whole where the canopy reader argues with the terrain"*, which drives half the
   circle with a reader 10 studs up and asserts 48 segments, a fallback count above zero, and that
   not one segment sits on the branch.
8. **Part count, stated**: 48 per ring, against 20. `ForestTestBoot` draws one ring per locked pick
   and `clearRings` takes them all down at the next intermission, so the worst case is the road
   line's 9 stands = **432** parts, all `CanQuery = false`, `CanCollide = false`, `CastShadow =
   false`. 64 segments was measured too (buried 0.17, floating 0.20) and bought nothing, because
   what is left at 48 is a 24-degree crease in the terrain at road stand 6, not the chord's sag.
9. **Nothing else about the ring moved**: `COLOR`, `THICKNESS_STUDS`, `HEIGHT_STUDS`, `LIFT_STUDS`,
   `TRANSPARENCY`, `Material.Neon`, the name `StandRing<n>`, `ringName`, `clearRing`, `clearRings`
   and the replace-don't-stack rule are as they were, and every task-166 case still passes.
   *Verify:* `Markers.RING`; the harness line above (1638 server + 430 client assertions, 0 failed).
10. **It is every stand in all four places.** `Markers.ring` takes the layout and reads
    `Data.standPosition(standIndex, layout)`; the measurement above covers road (9), edge (5),
    ride (5) and track (6).

## What I could not verify

* **Karen has not seen it.** She approved merging look work unseen on gates + review + my own look +
  the ready check; the frames are in the report.
* **The residual 0.21-stud burial at road stand 6 is a terrain CREASE**, not the ring: two adjacent
  segments differ by 24 degrees there because the ground does. The line stays continuous across it
  (`t207-after-worstspot.png`) but there is a visible kink, and a kink in the ground is a kink in a
  line drawn on the ground. If Karen wants that softened it is a new task, not a defect in this one.
* **The DEV place has no terrain under the forest's coordinates**, so every spec case here is driven
  with injected readers, as the whole file already is. The real-ground numbers come from the Forest
  Test, not from the harness.
