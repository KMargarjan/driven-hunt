# Task 328g — the Edit-time forest prebuild and the boot arbiter (PART 1)

Task: 328g
Round: 1
Base: `main` @ `0e416e85`
Code commit: `8c43aeac05d923930e97c894012fdc464d2ecb73`

`[harness] PASS: 34/34 checks @ 8c43aeac05d923930e97c894012fdc464d2ecb73 (clean tree) scope=all`

`test2` **N/A**: no `TWO_PLAYER_PATHS` path is touched. The four files under `src/` are
`src/server/ForestTest/init.luau`, `src/server/ForestTestBoot.server.luau`,
`src/server/Places/init.luau` and `tools/terrainbake.py` — none of them is `src/server/Match/`,
`MatchBoot`, `src/client/Match/`, `MatchBoot.client`, `src/shared/Drive/` or `tests/client/Role.luau`.

**No flake fired.** Both gate runs were green first time (`1c445a67` 34/34, `8c43aeac` 34/34); none of
the specs named in the dispatch's known-flake list appears as a FAIL in either.

## What changed

`Workspace.GridForest` is planted at **EDIT** time by `tools/terrainbake.py plant`, through
`Places.dressCell` — the one writer — and saved with the place, so Karen's trees are there at the
first frame instead of filling in behind her. `ForestTestBoot` reads two attributes once and asks
`ForestTest.prebuildVerdict`, which has three branches and owns no instance.

## Claims, and how to verify each

1. **A second DRIVER of the one writer, not a second writer, into a THIRD folder.**
   `tools/terrainbake.py`'s `PLANT_SEAM` calls `Planter.dressCells`, which calls `Places.dressCell`;
   no planting function was added — `src/server/Places/init.luau` gains only
   `Places.FOREST_FOLDER = "GridForest"` and one optional parameter on `Places.stats`. The third
   folder is defect F-1: `Places.build` destroys `GRID_FOLDER` at every boot and never this one.
   Verify: `terrainbake.py selftest` case *"no line under src/ both names the prebuild's folder and
   destroys something"* walks every `.luau` under `src/` (comments stripped) and fails if one does.

2. **All three arbiter branches are reached by parameter**, and a fourth state — an UNSTAMPED
   `GridForest` — is REFUSED rather than read as absent. Verify: `tests/server/grid.spec.luau`,
   describe *"the prebuilt forest's boot arbiter (task 328g, design 10.3)"*, three cases. Harness
   note: `arbiter: match=stands absent=absent stale=refused`.

3. **The boot acts on `dress` alone, by handing `Places.build` an EMPTY cell list** — the no-wood
   branch that function already had. `build`'s contract is untouched and the deferred dress is inert
   for free. Verify: the third case in that describe; note `stand-down: woods 0, pending 0; prebuilt
   1 model(s) survived 2 dress(es)`.

4. **The prebuild plants EXACTLY what the boot plants.** MEASURED in Karen's place, one instrument
   (`FOREST_ROWS_SEAM`, hashing name + pivot to 1/100 st + scale + yaw + band, sorted), read in Edit
   for the prebuild and in a Play server for the boot dress:

   | cell | prebuild (Edit) | boot dress #1 (Play) |
   |---|---|---|
   | C1 | 1941 / 6563 / `f8d6b718` | 1941 / 6563 / `f8d6b718` |
   | C2 | 2241 / 7490 / `ededd638` | 2241 / 7490 / `ededd638` |
   | A2 | 2311 / 7562 / `0f1c5e60` | 2311 / 7562 / `0f1c5e60` |
   | B1 | 2167 / 7274 / `67a0e513` | 2167 / 7274 / `67a0e513` |
   | D1 | 2169 / 7108 / `a2e69fc0` | 2169 / 7108 / `a2e69fc0` |

   **The boot dress is NOT reproducible run to run, and the prebuild is.** A SECOND boot dress of the
   same place, same commit, differs from the first in all five cells —
   C1 1942/`09b41eb8`, C2 2241/`588a28e0`, A2 2314/`522221c0`, B1 2168/`c78cba48`, D1 2174/`c3ff43f0`
   — because `plantOne` settles each tree against live terrain raycasts. So "equal to the boot dress"
   is exact against one dress and within the boot's own ±1..5-model drift in general. Files:
   `<runs-dir>/328g-rows-BOOT.txt`, `328g-rows-BOOT2.txt`.

5. **All three branches fired LIVE in Karen's place, at this code commit**, one `ForestTestBoot` line
   each (`<runs-dir>/328g-console-{ABSENT,STANDS,REFUSED}.txt`):
   - `prebuilt forest: ABSENT, folder=false, 0 model(s) ... planted=nil, dress=true`
   - `prebuilt forest: STANDS, folder=true, 10829 model(s) in 5 cell folder(s), live=58575af518ae6156 planted=58575af518ae6156, dress=false`
   - `prebuilt forest: REFUSED, folder=true, 10829 model(s) ... planted=deadbeefdeadbeef, dress=false` (forged stamp, then restored)

   In STANDS and REFUSED, `GridPlaces` held **no cell folder at all** — nothing was dressed.

6. **The trees are there at the first frame.** Fill poll, same probe both ways
   (`328g-fill-{BEFORE,AFTER}.txt`):
   - **with the prebuild**: at `up=3.2 s`, the earliest sample, C1 1941 / C2 2241 / A2 2311 / B1 2167 /
     D1 2169 — all five complete;
   - **today**: C1 is still being dressed on the boot's critical path (18.15 s) and the four deferred
     cells take 17.22 + 15.00 + 14.68 + 16.83 = **63.73 s** more. C2 — the cell Karen's *"more trees
     behind the line"* names — is complete ~35 s in.
   - `ForestTestBoot`'s own `places:` line, which is the composition root, drops **20.55 s → 2.01 s**:
     the lobby, shop, match and gun arrive 18.5 s earlier.

7. **Frames, hunter eye height, one C1 stand (−3905, 109, −5062), camera y 110.6, looking −Z into C2**
   — opened and described:
   - `328g-F1.png` (**with the prebuild**, `up=148.6`, complete since `up=3.2`): a closed wall of
     spruce/fir and silver birch across the whole frame, a grass clearing strip, a stony path in the
     foreground, two brown deer at right of centre by the treeline. Sky **9.29 %**.
   - `328g-F1-before-late.png` (today, between `up=4.4` and `up=29.7`, C2 still filling): the same
     ground, but a thin line of widely spaced conifers on the horizon, open sky between them and an
     empty green field in front. Sky **28.75 %**.
   - `328g-F1-before-done.png` (today, `up≈76–91`, boot finished): the wall is back, deer in the
     clearing. Sky **6.93 %**.
   So the CONTENT is the same and only the TIME differs — which is Karen's complaint exactly.

8. **`grid-terrain.md` 12.2's four rows, MEASURED for the first time** (and two are not met):
   - **place file: MET.** Download-a-Copy before **28,944,488 B (27.60 MiB)**, with the prebuild
     **32,853,698 B (31.33 MiB)** → **+3.73 MiB**, against a ≤ 150 MB ceiling. The design's
     **+25–40 MB** estimate is ~7–10× high. Both files in `<backups-dir>`.
   - **models/parts within 1024 st: MET.** At C1-8 with the prebuild, **2,661 models / 8,852 parts**
     against ≈ 5,000 / ≤ 17,000.
   - **client frame ≤ 16.7 ms: NOT MET, and not by the prebuild.** At C1-8, boot dress **43.12 ms**
     mean (2,664 models / 8,855 parts) vs prebuild **44.30 ms** (2,661 / 8,852) — a 1.2 ms difference
     inside the instrument's own spread. At D2-12 (unplanted, unbaked): 38.99–43.84 ms, **0 models**.
     Every reading names its own camera on its own line. This is Studio Play, server and client in
     one process with the Studio UI drawing.
   - **server heartbeat ≤ baseline + 1.0 ms: NOT PROVEN.** Three readings, same probe:
     ABSENT `up=357.5` **30.73 ms**, ABSENT `up=216.4` **35.43 ms**, STANDS `up=441.4` **39.41 ms**.
     The two ABSENT sessions differ by **4.7 ms**, so the instrument cannot resolve a 1.0 ms budget.
   - **live `StreamingMinRadius`: NOT OBTAINABLE.** Measured behind a pcall in BOTH the Play server
     and the Edit plugin context: `StreamingEnabled=true`, and `StreamingMinRadius`,
     `StreamingTargetRadius`, `ModelStreamingBehavior`, `StreamOutBehavior`, `StreamingIntegrityMode`
     all answer **NOT A MEMBER** in Studio 0.740.x. I also tried to read it off the Properties panel
     and did not land Workspace selected (`328g-props2-crop.png` shows a SpawnLocation); I am not
     quoting a number I did not read.

9. **Census, every counter class named (L-170), and a control.** `GridCensus.survey` over
    `GridForest` vs over a boot-dressed `GridPlaces`, same probe, same place
    (`328g-census-GRIDFOREST.txt`, `328g-census-GRIDPLACES.txt`). Identical on every counter:
    **floating 0, tilted 0, broken 0, noGround 0, inRoad 0, inStand 0, onCliff 0, crownOverRoad 0,
    crownUnmeasured 0** in both; `sunk` 101/154/123/194/200 in both; `foliageInGround` 45/33/41/40/176
    in both; `worstSink` 4.35–4.41 in both; `inLane(other-world)` 144/0/0/195/239 in both.
    `sunk` and `foliageInGround` are **not 0** — both readings hand in `clawOf = 0`, not 328b's real
    per-template claw, so they are NOT comparable with 328i's reported 0 and I do not claim they are.
    `inBeaterPath, inDitch, inRide, inTower, inVerge, mudPct, rockPct` print `UNMEASURED` by the
    census's own design. The row hash in claim 5, not this census, is what proves the two woods are
    one wood.

## What I could not verify, and two measured deviations from the design

- **Design 10.2's `breathe = nil` is refuted.** With no yield, 1,941 clones go in on Studio's main
  thread in one block: the WORK finishes (C1 stood complete, 1,941 models) but StudioMCP cannot
  answer while the thread is blocked, and the call returns *"Target is not reachable
  (ExecuteLuau.runCode, DMN_ID_EDIT)"* after six seconds, so the driver can never read its report or
  stamp the folder. The seam now passes `task.wait`. **The yield moves no tree, measured:** the
  no-yield C1 hashed `f8d6b718`, which is the yielded C1's hash and the boot dress's hash.
- **The row hash is computed in Luau, not in Python.** Returning a cell's 2,400 rows truncates the
  MCP reply. Both readers run the one seam string.
- **`CENSUS_SEAM` in `tools/terrainbake.py` passes the ROOT folder to `GridCensus.survey`, which
  walks `folder:GetChildren()` for Models** — so `terrainbake.py census` reports `trees=0` for every
  cell. I measured that (my first census run read 0 everywhere) and worked around it in my probe by
  passing the cell folder. **I did not fix `CENSUS_SEAM`**: it is outside this task's build list.
  Queued for the Director.
- **`src/server/ForestTest/init.luau` is 242 KB and pulls `Boar`, `HighSeats`, `Data`, `Line`,
  `Markers` and `Seats`, so it cannot ride on the injection.** `ForestTest.terrainYAt` is therefore
  **cut out of that file by signature**, exactly once, and the selftest asserts the cut text still
  contains the Include filter, `Workspace.Terrain`, `IgnoreWater`, and the 600 / −1200 band, and that
  `terrain_reader` refuses when the signature moves. It is not retyped — but it is a cut, and a
  reviewer should satisfy themselves that is not design 10.1's second definition of the ground.
- **Karen has seen none of this.** The frames are mine.
- **PART 2 is not done**: `GridForest` is NOT in her place now. It was planted, measured, and taken
  out again in the same session (claim 10 below).

## Her place, left exactly as found (PART 1's rule)

10. Planted → measured → archived out → the archived shell removed from `ServerStorage`.
    `Workspace.GridForest=false | Workspace.GridPlaces=false` at the end. **Attribute diff EMPTY**
    against the capture taken before any write (`328g-attrs-BEFORE.txt` vs `328g-attrs-FINAL.txt`,
    `diff` exit 0); her 15 flag overrides byte-identical and never cleared (rule K). The Rojo panel is
    back on **localhost:34873** and Connected (`328g-panel-final-crop.png`) — it was on 34874 only for
    the proof. `smoke.sh` **PASS** afterwards on her restored build: gun in hand at +18 s and at 80 s,
    **0 stacks, 0 error lines, 9 waves**. The wood is not lost (rule 7): it is in
    `<backups-dir>/FT-with-328g-prebuild.rbxl` and is reproducible by `terrainbake.py plant`.

    **PART 2's question, answered by measurement:** an Edit-time write in her Team Create place
    **PERSISTS WITHOUT A SAVE CLICK.** Studio was closed with `WM_CLOSE` (no save prompt appeared —
    `328g-closing-small.png` shows an empty start window) and reopened from the place URL; the probe
    then read `GridForest PlantEpoch=58575af518ae6156 C1=1941 C2=2241 A2=2311 B1=2167 D1=2169`. So
    PART 2 needs no NEEDS KAREN save click for the prebuild to survive into her next Studio session.
    **Bounded:** this is the Team Create edit state that Play-in-Studio reads, which is how Karen
    plays. It is not a claim about a PUBLISHED build.
