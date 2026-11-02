# Task 328b — trees sit right: the contact rule, the template audit, the census, Atomic

Task: 328b
Round: 2
Base: feafe9bd (main, with 328a #313 merged)
Code commit: 16da4c67a23f0019a7815e9d9b519347b176a5f8

```
[harness] PASS: 34/34 checks @ 16da4c67a23f0019a7815e9d9b519347b176a5f8 (clean tree) scope=all
```

`test2` is **N/A**: nothing changed is in `TWO_PLAYER_PATHS` (design B11, Director 2026-10-03). The
files touched are `src/shared/Places/`, `src/server/Places/`, `src/shared/ForestTest/`,
`src/serverstorage/GridCensus/`, `tests/server/grid_ground.spec.luau` and `tools/studio_mcp.py`.

**What this task found, and it is the headline.** The census this task adds measured C1 as **main**
plants it and read `tilted=571 broken=571` out of 2,019 trees — 28 % of the cell planted **lying
down**. The design assumed the template audit would catch such a thing *"at the source"*; it cannot,
because **all 35 templates pass the audit**. The cause is `plantOne`'s own `PivotTo`.

## Round 1's finding, and what it changed

Finding 1 was right twice over. The quarantine is **empty** — all 35 templates pass — so the door
could only be proved by **driving** it, and driving it found a second hole: `Places.layer`, the four
**LINE** places, drew names from `Places.SPECIES` **directly**, so round 1's claim that `namesOf` is
the one door was false for half the planting. `layer` now goes through `namesOf` like `scatter`
(claim 5). The round's own instrument also refuted the first fixture: a 2-part birch was refused
`"part-count"` before the quarantine arm could be reached, so the fixture is a **fern** — one part,
2.2 studs, scale 1 — which genuinely passes its own `TEMPLATE_DIMS` row. Eight non-blocking notes
were fixed rather than queued; they are listed at the end.

## Claims

1. **The Architect's text is pasted verbatim, in its own first commit** (`25230dce`, marked "the
   Architect's text, grid-terrain.md section 16"). *Verify:* the four blockquotes appended to
   `docs/design/grid-map.md` (new §18), `drive-places.md` (§19), `map-generator.md` (a section of its
   own — that file carries no grid section, said so in the commit message) and the
   `tools/forest_ground.py` header are character-identical to §16's, `>` markers aside.
2. **`Places.TEMPLATE_DIMS` is 35 rows, each at the template's own `GetScale()`.** MEASURED in the
   Forest Test on 2026-11-02 by `driven-hunt-runs/328b-dims.luau` (read-only, Edit). All 35 names
   `Places.SPECIES` plants were found in `Workspace.OurForest`; 30 stand at a scale that is not 1.
   `crownHalfWidthStuds` is the union of the parts `Places.isFoliageName` answers true for; the five
   ferns have no foliage-named part and read 0. The header says what invalidates the table and what
   guards it. *Verify:* `grid_ground.spec` "is 35 of 35, with no extras", and `Plan.dimsFor`.
3. **The claw fraction was measured a second time, by the lobby's horizontal rule**, and
   `Places.CLAW_CROSSCHECK` lists all 35 with both numbers and a verdict. Exactly **two agree in
   kind and both are birch** — `SilverBirch_Var11_LOD_0` (0.0425 / 0.0625) and `_Var13_LOD_0`
   (0.0222 / 0.0625) — which is the pair `CLAW_FRACTION` already carried, found again by a method
   that shares nothing with the first. **`CLAW_FRACTION` is unchanged.** `a` is a re-measurement of
   the ONE template instance against `CLAW_FRACTION`'s median over every instance, which the header
   now says — that is why `Var13` reads 0.0222 against the shipped 0.0239. **Three** spruces also
   agree and are deliberately not adopted (`Old_Spruce_Var04` at 0.0417 × 121 studs would sink 5.0
   studs deeper, and a spruce's base is a skirt, not an arch of claws). *Verify:* the table.
4. **The §9.3 audit is ONE function called twice.** `Plan.auditReason` is called by
   `Places.auditTemplate` on the TEMPLATE at build time and by `GridCensus.brokenReason` on the
   DRAWN clone; neither restates the rule. *Verify:* "the template audit catches each failure
   separately" drives a lying trunk, a leaning one, a detached crown, a crown slid sideways, a part
   count and extents — one synthetic template each — and "the extents arm divides by
   `TEMPLATE_DIMS.scale` and NOT by 1".
5. **`namesOf` is the ONE door, and both doors are driven.** `Places.QUARANTINE` is empty because
   all 35 templates pass, so the case **stubs `isQuarantined` for one name** (`Plan.forgetPlantable`
   exists for that and nothing else) and asserts: `auditTemplate` answers `"quarantined"`; `namesOf`
   drops that name **and only** that name; no `plantCell` list in C1 or A1 names it; and
   `Places.build` plants **none** of it with `report.quarantined` 0, because the LIST door shut
   before the template was ever asked for. The stub is restored through a `pcall` and the door is
   shown to open again. A **second** case drives `build`'s own audit closure with a template that
   has **drifted** (one part became two): `report.quarantined` 1, `quarantinedBy["part-count"]` 1,
   drawn 0 — against the sound fixture of the same shape, which plants > 0 with `quarantined` 0.
   *Verify:* those two cases, and that `Places.layer` and `scatter` both call `Places.namesOf`.
6. **`ServerStorage.GridCensus` shares the thresholds and shares no measurement.** It reads
   `TreeGround.TOLERANCE_STUDS`, `sinkFor`, `junctionY` and `Plan.stepAllowanceStuds`, defines no
   tolerance or sink of its own, never calls `Places.trunkBox`/`groundsUnder`, and takes its ground
   reader as a parameter. Its two own numbers — `INVISIBLE_AT` and `STAND_CLEAR_STUDS` — are named
   as the census's own and not borrowed. The seven rows no task has measured read
   `UNMEASURED: <task>` and never 0 (design 12.2). `publish` writes every count as an attribute so a
   probe can read it back (V293b). *Verify:* the "by identity" case and the "publishes every count".
7. **The census reads non-zero when it should** (lesson L-086): one folder per defect — lifted 1.0
   reads `floating=1` and `worstHigh=0.4`, sunk 1.2 reads `sunk=1` and `worstSink=1.8`, 80° over
   reads `tilted=1` and `broken=1`, and 3.5° over reads `tilted=1 broken=0`. *Verify:* that case.
8. **`plantOne` streams `Atomic`, and the foliage flags `quieten` set survive it** (lesson L-060:
   the trunk still queries, the leaf still does not). **`ForestTest.GROUND_IGNORE` carries
   `GridForest`** once and the three folder names differ (defect F-1). *Verify:* the last two cases.
9. **THE DEFECT AND THE FIX.** A Model with no `PrimaryPart` carries its bounding box's rotation in
   its pivot — `Forest_OakTree_Var03_LOD_0`'s pivot up vector is (-0.97, 0.00, -0.22) — so
   `PivotTo(CFrame.new(…) * CFrame.Angles(0, yaw, 0))` forced that pivot upright and rotated the
   whole tree by the inverse: its trunk part stood at **90.0° off vertical**, trunk box 8.2 × 1.4 ×
   **53.0** studs, model 18.8 studs tall against the template's 53.9. 10 of the 35 templates have no
   `PrimaryPart`; the other 25 do and planted upright, which is why it hid. The fix is one `* spin`:
   keep the template's own rotation, add our yaw. *Verify:* `grid_ground.spec` "a template whose
   PIVOT is rotated is planted UPRIGHT", which carries a **FAIL FIRST** control — the pre-328b line
   applied to the same fixture, measured at 80° over — so the case cannot pass with the fix deleted.
10. **The gate plumbing.** `grid_ground.spec` is in **three** scopes (`lobby`, `places`, `map`) and
    `src/serverstorage/GridCensus/` has a `BLAST_RADIUS` row (`places`). `python tools/studio_mcp.py
    selftest`, `python tools/agents.py selftest` and `python tools/privacy_scan.py scan` all pass
    (rule G). *Verify:* `SCOPE_SPECS`, `BLAST_RADIUS`, and the three selftests.

## The live measurement — Karen's Forest Test, C1, `GRID_PREVIEW` on (left exactly as found)

Both sides were re-run at the ROUND-2 instrument so the two lines are the same code (L-162). Same
instrument both sides: `ServerStorage.GridCensus` driven by `driven-hunt-runs/328b-census.luau`, its
own Terrain-only downward ray. BEFORE is `src/server/Places/init.luau` at **main** inside the
branch's tree (the planter untouched, the instrument added); AFTER is the code commit, `git status`
clean. **Both lines are whole — nothing trimmed.**

```
BEFORE [census] C1 epoch=feafe9bd-planter trees=2019 parts=5781 floating=0 sunk=0 foliageInGround=836 tilted=571 broken=571 noGround=0 inRoad=16 inStand=0 inLane(other-world)=139 onCliff=0 crownOverRoad=100 crownUnmeasured=0 refused=146+0/2165=6.7% worstHigh=-0.18 worstSink=0.60 UNMEASURED=inBeaterPath,inDitch,inRide,inTower,inVerge,mudPct,rockPct
       brokenBy: {"trunk-axis-not-Y":571}

AFTER  [census] C1 epoch=16da4c67 trees=2140 parts=6199 floating=0 sunk=0 foliageInGround=265 tilted=0 broken=0 noGround=0 inRoad=1 inStand=0 inLane(other-world)=149 onCliff=0 crownOverRoad=95 crownUnmeasured=0 refused=25+0/2165=1.2% worstHigh=-0.18 worstSink=0.60 UNMEASURED=inBeaterPath,inDitch,inRide,inTower,inVerge,mudPct,rockPct
       brokenBy: []
```

The boot lines beside them: `grid wood C1: 2019 of 2165 planted (6494 parts), 146 on a step` →
`2140 of 2165 planted (6912 parts), 25 on a step`. Zero error lines in either console.

**Three hunter's-eye frames, before and after, at the same camera points** (`driven-hunt-runs/`,
camera printed beside each; the route is 327a–c's own client binding, Director decision 2 / D-1).
The AFTER set was re-taken at the code commit: `328b-after2-f1..f3.png`.

| frame | camera → look | BEFORE | AFTER (at `16da4c67`) |
|---|---|---|---|
| f1 | (-3899, 113.5, -5107) → (-3899, 110, -4600), stand 4 | two long bare trunks lying across the grass, one bottom-left, one centre; a brown lying crown mid-frame | every tree standing; a tall oak centre, spruces and birches around it, clear floor |
| f2 | (-3898, 112.6, -5095) → (-3898, 108.6, -5130), at the 74-stud lying oak | a wall of oak foliage AT GROUND LEVEL filling the view — the crown lying on the earth | that oak standing, a clean bare trunk with its crown above, birches behind |
| f3 | (-3899, 112.6, -5107) → (-3869, 108.3, -5107), west along the stand line | a low mass of foliage on the ground, no trunks in the near band | standing birches and conifers both sides, the road corridor running away with the corner stakes visible |

Every frame was opened and looked at. No two share a sha256 (printed by the shoot script).

## What I could not verify, and what is somebody else's

- **`inRoad=1` is `crownOverRoad`'s neighbour and is 328f's**, not an oversight: the census takes the
  realised TRUNK-BOX centre, which on a wide-trunk template (`Field_OakTree_Var05_LOD_0`'s "Trunk"
  mesh is 36 studs across) sits studs from the planted `item.x` the planter tested — and design 13.2
  case 5's 34-stud frontage floor replaces the 21-stud clearance the census measures against anyway.
  16 → 1 is the fix working; the last one waits for 328f.
- **`inLane(other-world)` is not a cell defect.** It asks the four LINE places' rule, whose
  `Forest.roadZ(x, layout)` is defined for every x and so cuts a stripe across the whole world
  (design 11.3). The row is named in the line itself; 327d retires those places.
- **`foliageInGround=265` and `crownOverRoad=95` are 328f's**, the frontage rule's to answer.
- **`refused` is reported and not gated** (B5): 1.2 %, against 328f's ≤ 8 %.
- **Cases 4–9 of design 13.2 are not in the spec**: `Places.mask`, `Places.REASON`, the 34/27-stud
  frontage floors and `standTypeFor` do not exist until 328f. Queued in `TASKS.md`.
- **The fern carve-out is mine, not the design's.** §9.3's "the trunk box's longest extent must be Y"
  would quarantine all five fern templates — MEASURED 2.2–3.1 studs tall against 8.2–9.6 wide — and
  that would delete the forest floor. `Places.HERB_GROUPS` exempts the `fern` group from the axis and
  lying arms only; every other arm still applies to a fern.
- **The four LINE places' wood was not photographed** (round 1's note). `plantOne` is also `build`'s
  planter for them, so their trees changed too; the frames are all of C1, and nobody has looked at
  `Workspace.DrivePlaces` since the fix. The census covers the grid cell only.
- `deer_hitbox.spec:659` and `:682` (both named in the dispatch as known intermittents) each fired
  once across the six runs of this task and never on a re-run; the code commit's run is clean, 34/34.
  No other check ever failed.

## ANSWERED

- **ANSWERED: L-136** — the intermittents that fired are named above with their commits and counts.
- **ANSWERED: L-127** — the handover block in the report marks each dispatch item MET / NOT MET /
  NOT PROVEN in my own words.
- **ANSWERED: L-162** — both censuses and all three AFTER frames were re-taken with
  `driven-hunt-294` at `16da4c67` (`git status` clean) after round 2 changed the instrument's line.
- **ANSWERED: L-014** — nothing was ever checked out in `driven-hunt-karen`. The Forest Test was
  pointed at `:34874` (`driven-hunt-294`) for each proof and back at `:34873` afterwards; her
  `DHFlag_GRID_PREVIEW=true` was read and never written.
- **ANSWERED: L-139** — the switch back to `:34873` is verified **two ways**, both times: the Rojo
  panel reads `localhost:34873` / Disconnect (`328b-rojo-6.png`, `328b-rojo-8.png`), and a content
  probe reads `ServerStorage.GridCensus=false` in the place — Rojo removed it on reconnecting to a
  tree that does not have 328b.
