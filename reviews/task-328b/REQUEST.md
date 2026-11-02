# Task 328b — trees sit right: the contact rule, the template audit, the census, Atomic

Task: 328b
Round: 1
Base: feafe9bd (main, with 328a #313 merged)
Code commit: 7bd49f451926e680eee285897ff794b803707eda

```
[harness] PASS: 34/34 checks @ 7bd49f451926e680eee285897ff794b803707eda (clean tree) scope=all
```

`test2` is **N/A**: nothing changed is in `TWO_PLAYER_PATHS` (design B11, Director 2026-10-03). The
files touched are `src/shared/Places/`, `src/server/Places/`, `src/shared/ForestTest/`,
`src/serverstorage/GridCensus/`, `tests/server/grid_ground.spec.luau` and `tools/studio_mcp.py`.

**What this task found, and it is the headline.** The census this task adds measured C1 as **main**
plants it and read `tilted=571 broken=571` out of 2,019 trees — 28 % of the cell planted **lying
down**. The design assumed the template audit would catch such a thing *"at the source"*; it cannot,
because **all 35 templates pass the audit**. The cause is `plantOne`'s own `PivotTo`. That
contradiction is reported here rather than left for a review round (V293).

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
   ferns have no foliage-named part and read 0. *Verify:* `grid_ground.spec` "is 35 of 35, with no
   extras", and `Plan.dimsFor`.
3. **The claw fraction was measured a second time, by the lobby's horizontal rule**, and
   `Places.CLAW_CROSSCHECK` lists all 35 with both numbers and a verdict. Exactly **two agree in
   kind and both are birch** — `SilverBirch_Var11_LOD_0` (0.0425 / 0.0625) and `_Var13_LOD_0`
   (0.0222 / 0.0625) — which is the pair `CLAW_FRACTION` already carried, found again by a method
   that shares nothing with the first. **`CLAW_FRACTION` is unchanged**: four spruces also agree and
   are deliberately NOT adopted (the arithmetic is in the comment: `Old_Spruce_Var04` at 0.0417 ×
   121 studs would sink 5.0 studs deeper, and a spruce's base is a skirt, not an arch of claws).
   *Verify:* the table, and that no non-zero fraction was added.
4. **The §9.3 audit is ONE function called twice.** `Plan.auditReason` is called by
   `Places.auditTemplate` on the TEMPLATE at build time and by `GridCensus.brokenReason` on the
   DRAWN clone; neither restates the rule. *Verify:* `grid_ground.spec` "the template audit catches
   each failure separately" drives a lying trunk, a leaning one, a detached crown, a crown slid
   sideways, a part count and extents — one synthetic template each — and "the extents arm divides
   by `TEMPLATE_DIMS.scale` and NOT by 1".
5. **`Places.QUARANTINE` is empty, and that is a measurement**: all 35 templates pass. `namesOf` is
   the one door a quarantined name cannot pass, and with nothing quarantined it is the identity —
   asserted, because that is what keeps the planting list bit-identical to 327c's. *Verify:* the
   "every QUARANTINE name is in SPECIES" case, and the boot's `2165 wanted` before and after.
6. **`ServerStorage.GridCensus` shares the thresholds and shares no measurement.** It reads
   `TreeGround.TOLERANCE_STUDS`, `sinkFor`, `junctionY` and `Plan.stepAllowanceStuds`, defines no
   tolerance or sink of its own, never calls `Places.trunkBox`/`groundsUnder`, and takes its ground
   reader as a parameter. The seven rows no task has measured read `UNMEASURED: <task>` and never 0
   (design 12.2). `publish` writes every count as an attribute so a probe can read it back (V293b).
   *Verify:* the "contact rule is TreeGround's, by identity" case and the "publishes every count" case.
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

Same instrument both sides: `ServerStorage.GridCensus` driven by `driven-hunt-runs/328b-census.luau`,
its own Terrain-only downward ray. BEFORE is `src/server/Places/init.luau` at **main** inside the
branch's tree (the planter untouched, the instrument added); AFTER is the code commit.

```
BEFORE [census] C1 epoch=feafe9bd-planter trees=2019 parts=5781 floating=0 sunk=0 foliageInGround=836
        tilted=571 broken=571 noGround=0 inRoad=16 inStand=0 inLane=139 onCliff=0 crownOverRoad=100
        crownUnmeasured=0 refused=146+0/2165=6.7% worstHigh=-0.18 worstSink=0.60
AFTER  [census] C1 epoch=afb417be trees=2140 parts=6199 floating=0 sunk=0 foliageInGround=265
        tilted=0 broken=0 noGround=0 inRoad=1 inStand=0 inLane=149 onCliff=0 crownOverRoad=95
        crownUnmeasured=0 refused=25+0/2165=1.2% worstHigh=-0.18 worstSink=0.60
```

**Three hunter's-eye frames, before and after, at the same camera points** (`driven-hunt-runs/`,
camera printed beside each; the route is 327a–c's own client binding, Director decision 2 / D-1):

| frame | camera → look | BEFORE | AFTER |
|---|---|---|---|
| f1 | (-3899, 113.5, -5107) → (-3899, 110, -4600), stand 4 | two long bare trunks lying across the grass, one bottom-left, one centre; a brown lying crown mid-frame | every tree standing; a tall oak centre, spruces and birches around it, clear floor |
| f2 | (-3898, 112.6, -5095) → (-3898, 108.6, -5130), at the 74-stud lying oak | a wall of oak foliage AT GROUND LEVEL filling the view — the crown lying on the earth | that oak standing, a clean bare trunk with its crown above, birches behind |
| f3 | (-3899, 112.6, -5107) → (-3869, 108.3, -5107), west along the stand line | a low mass of foliage on the ground, no trunks in the near band | standing birches and conifers both sides, the road corridor running away with the corner stakes visible |

Every frame was opened and looked at. No two frames share a sha256 (printed by the shoot script).

## What I could not verify

- **The `inLane` row is not a cell defect** and is reported, not fixed: it counts trees inside one of
  the four **LINE places'** lanes, which are a different world (design 11.3) and which 327d retires.
- **`foliageInGround=265` and `crownOverRoad=95` are 328f's**, the frontage rule's to answer; they are
  reported here per B5 and gated nowhere.
- **`refused` is reported and not gated** (B5): 1.2 %, against 328f's ≤ 8 %.
- **Cases 4–9 of design 13.2 are not in the spec**: `Places.mask`, `Places.REASON`, the 34/27-stud
  frontage floors and `standTypeFor` do not exist until 328f. Queued in `TASKS.md`.
- **The fern carve-out is mine, not the design's.** §9.3's "the trunk box's longest extent must be Y"
  would quarantine all five fern templates — MEASURED 2.2–3.1 studs tall against 8.2–9.6 wide — and
  that would delete the forest floor. `Places.HERB_GROUPS` exempts the `fern` group from the axis and
  lying arms only; every other arm still applies to a fern.
- `deer_hitbox.spec:659` (a known intermittent, named in the dispatch) fired once during the run at
  `afb417be` and did not fire on the re-run at the same commit; the code commit's run is clean,
  34/34. No other check ever failed.

## ANSWERED

- **ANSWERED: L-136** — the one intermittent that fired is named above with its commit and its count
  (once at `afb417be`, clean on the re-run and clean at the code commit).
- **ANSWERED: L-127** — the handover block in the report marks each dispatch item MET / NOT MET /
  NOT PROVEN in my own words.
- **ANSWERED: L-162** — the AFTER census and all three AFTER frames were taken with
  `driven-hunt-294` checked out at `afb417be` (`git status` clean), which is the code commit's
  `src/`; the only commit after it, `7bd49f45`, changes `GAME_DESIGN.md` and `TASKS.md` alone.
- **ANSWERED: L-014** — nothing was ever checked out in `driven-hunt-karen`. The Forest Test was
  pointed at `:34874` (`driven-hunt-294`) for the proof and back at `:34873` afterwards; her
  `DHFlag_GRID_PREVIEW=true` was read and never written.
- **ANSWERED: L-139** — the switch back to `:34873` is verified **two ways**: the Rojo panel reads
  `localhost:34873` / Disconnect (`driven-hunt-runs/328b-rojo-6.png`), and a content probe reads
  `ServerStorage.GridCensus=false` in the place — Rojo removed it when it reconnected to a tree that
  does not have 328b.
