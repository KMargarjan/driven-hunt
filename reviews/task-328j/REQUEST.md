# Task 328j -- the bake's two fixes, and C1 BAKED in Karen's Forest Test

Task: 328j
Round: 2
Base: 6b520717 (origin/main)
Code commit: a18b4ac563b7d51fabd8746c826e4997a1cd75a3

```
[harness] PASS: 34/34 checks @ a18b4ac563b7d51fabd8746c826e4997a1cd75a3 (clean tree) scope=all
```

`test2` is N/A: nothing here is in `TWO_PLAYER_PATHS` (the bake is the map and the tools).

**Two reviews have run.** The first PASSED (`3886e92a`; a copy of that verdict is at
`<runs-dir>/328j-RESULT-round1-PASS.md`, because a PASS closes the gate's count and the next run
overwrites the file). The second, numbered round 1 by that same rule, found **one** blocking thing
and claim 11 below is its fix. Their notes are queued in `TASKS.md`, not fixed here. This round covers only what changed after it: two tool bugs that each
stopped the bake dead, and **the bake itself**, which has now run. The whole branch against `main`
is 328d plus 328j; 328d's request still stands.

## Claims

1. **Refusal 7 could not pass Karen's own two flags, so the bake could not start at all.**
   `flag_overrides` answers `DHFlag_<NAME>=<value>` strings and `check_overrides` compared each WHOLE
   string with a whitelist of bare names, so `"DHFlag_GRID_PREVIEW=true" not in ("GRID_PREVIEW",
   "RANGE_SOLO")` was true and the whitelist matched nothing. Measured in her place at 18:00 UTC:
   **all 15** of her overrides refused, the two the list exists to allow among them. `override_name_of`
   is the pure half; the selftest case states the bug (`"DHFlag_GRID_PREVIEW=true" not in
   KARENS_FLAGS` is asserted as true beside `override_name_of(...) in KARENS_FLAGS`). Verify:
   `ESCALATE.md`'s 18:05 UTC entry has the probe output before the fix.
2. **`--keep-flags` declares the place owner's overrides instead of clearing them.** The dispatch
   says her flags are "left as found" and lesson K forbids `clear`. The bake printed
   `keep 13 declared override(s), left as found: AIM_REWIND,...,ZONES_FOLLOW_GAIT` and then
   `flags live overrides: ...` beside it, so the widening is in the run output. An undeclared
   override still refuses. Verify: `.terrainbake/20261102T181221Z-C1.json` and the bake log.
3. **The first wet bake wrote every tile and then died stamping the epoch.** `epochInputFor` answers
   a STRING whose landform digest carries braces, and `parse_json` looked for the first `{`.
   `parse_json` now tries `{`, `[` and `"` in the order they appear and takes the first that DECODES;
   two cases cover it, and the string one fails before the fix. No wet run had ever happened, so
   nothing had reached that line. Verify: the traceback is in the bake log after `tile 208/208`.
4. **THE BAKE RAN, in Karen's Forest Test, at the code commit, by the injection route.**
   208/208 tiles, **3,513,344 voxels**, 82-127 ms a tile (mean 98.0), **20.4 s** of tile time, one
   MCP call each, no tile message. The backup gate was re-checked immediately before the first
   `WriteVoxels`: `FT-before-328d.rbxl`, 29,360,598 bytes, 1.16 h old, outside the repo. Her session
   was **Edit only** (`get_studio_state`: "Available DataModels: Edit"), so rule C held. The epoch was
   then stamped through `TerrainBake.stamp` -- design 2's only writer -- with **no re-bake**, because
   a second bake would read the BAKED ground as its base: `TerrainEpoch` nil -> `5f6a97f4aace5dcf`.
5. **The road is cut into the ground, measured away from the crossings.** The first probe sampled
   each road's span midpoint, which for all four of C1's roads IS a crossing -- where the design says
   the other axis wins and there is no ditch -- and scanned the grade over the whole road, most of
   which was never baked. Re-measured halfway between the two crossings and only inside the baked
   region (`328j-section-AFTER.json`):

   | road | crown | ditch + | ditch - | realised grade over the baked span |
   |---|---|---|---|---|
   | EW2 | 110.58 | **1.97** | **1.97** | 5.48 % |
   | EW3 | 144.78 | **1.98** | **1.98** | 11.99 % |
   | NS3 | 109.97 | **1.92** | **1.92** | 10.23 % |
   | NS4 | 124.90 | **1.98** | **1.98** | 7.90 % |

   Design 7.1's ditch is 2.00 st; the worst error is **0.08 st**, so section 15 item 2's 4-stud
   fallback is not triggered. The full `d -40..+40` section of EW2 is in the file: level carriageway
   (-0.00 at d 1, -0.08 at d 10, -0.12 at d 15), both ditches bottoming at **-1.97** at d +23 and
   d -25 inside the realised band 19..27, verge back up at d 30-33, bank beyond.
6. **The step at each crossing, on the WRITTEN GROUND, where round 3 measured 60 studs.** Inside the
   junction square (|d| <= 16 on both axes, 81 rays a crossing, `328j-cross-AFTER.json`): worst
   adjacent-column step **0.1758 / 0.0900 / 0.1984 / 0.0547 st** for EW2xNS3, EW2xNS4, EW3xNS3,
   EW3xNS4 -- every one at or under the 0.20 crown fall. The tool's own `junctionSteps` over the
   profiles read pin 0.0000 on all four at this commit.
7. **The ±24 window reads bigger, and the reason is the ditch, not the junction.** The same metric
   with the round-1 ±24 window reads 1.474 / 0.927 / 1.416 / 0.932 st, at offsets like (+16,-24):
   the REALISED ditch band starts at d **19**, not the nominal 22 (`columnsFor`'s documented inward
   shift), so a point 24 studs out on one axis is in the other road's 2-stud ditch while still
   "on a carriageway" by the nominal rule. Named here rather than quietly dropped.
8. **Director decision 3, on the written ground.** NS3 realises **10.23 %** and NS4 **7.90 %** over
   the baked span -- both under the 12 % the decision asks for, where round 3's profiles were 15.73
   and 13.47. The caps are `cutFillStuds = { x = 12, z = 20 }` and the ladder that chose 20 is claim
   8 of round 1.
9. **The census, on the baked ground, from a fresh Play boot with her GRID_PREVIEW already on.**
   `[census] C1 epoch=5f6a97f4aace5dcf trees=2085 parts=6073 floating=0 sunk=0 foliageInGround=275
   tilted=0 broken=0 noGround=0 inRoad=0 inStand=0 inLane(other-world)=131 onCliff=0
   crownOverRoad=91 crownUnmeasured=0 refused=25+0/2165=1.2% worstHigh=-0.18 worstSink=0.60`.
   **floating 0, sunk 0, tilted 0** is the dispatch's ask. `crownOverRoad=91` is 328f's frontage
   rule, not this task's.
10. **Her place is as found.** Every place/ServerStorage/Workspace/ReplicatedStorage attribute was
    dumped BEFORE the first `WriteVoxels` (`<runs-dir>/attr-328j-20261102T173231Z.log`, 17:32 UTC,
    15 `DHFlag_*` plus `DHForestStartRole`, `DHShopTestGrant`, `DHTestOwns`) and again after
    (`attr-328j-20261102T182237Z.log`): **byte-identical**. The frame camera's `DH328dFrame`
    attribute was cleared, Play was stopped, and nothing was saved, published or committed in her
    place.

11. **The refusal-7 cases now carry the shape the transport answers, and the fix dies without them.**
    The previous round's finding: all four `check_overrides` cases fed `FakeStudio` BARE names, which
    `flag_overrides` never returns, so reverting `override_names` left them green. Each now passes
    `DHFlag_<NAME>=<value>` as `QUERY_FLAG_OVERRIDES` builds it, and a fifth covers `--keep-flags`
    accepting a declared override and only that one. Verify: revert `override_names` to
    `sorted(flag_overrides(...))` and **two** cases go red -- "LEAVES Karen's own two alone" and the
    `--keep-flags` one (run, not argued). `LOCALAPPDATA=/nonexistent` exits 0 with **83** PASS lines.
12. **Two notes of that round taken, not queued.** `parse_json` now prefers the candidate that
    CONSUMES THE WHOLE REPLY: by position alone a quote in Studio's preamble beats the JSON behind
    it, and by type alone `[{"a": 1}]` decodes to its first element -- the suite's existing array case
    caught the second, and both shapes have a case now. `log_run` keeps `keepFlags` and
    `liveOverrides`, which the docstring and `ESCALATE.md` had claimed it did when only stdout had
    them. **The bake's own run log predates that**, so `.terrainbake/20261102T181221Z-C1.json` is
    still tiles only and claim 2 rests on the bake output, not on it.

## What I could not verify

* **The stands are still not on the ground, and the bake is not what levels them.** Before:
  5 floating (worst 17.82 st) and 10 buried (worst 24.33) of 15. After: 5 floating (worst **13.57**)
  and 10 buried (worst **21.84**) -- better, but only because the landform moved under them.
  `bakeTileAt` passes `plans = {}` to `shapeTile`, so **no pad op is applied at all** (round 1's
  Reviewer note says the same of `Relief.materialAt`). The dispatch's "none floating, none buried"
  is therefore **NOT MET**, and nothing in this task could meet it: it needs the pad plans, queued
  as 328e/328f. Stand 10 went -24.33 -> -7.41; stand 11 went -16.55 -> **-21.84**, so the worst case
  moved rather than closed.
* **C1's landform cannot be checked against `Relief.heightAt` after the bake.** `heightAt` takes the
  BASE as a function, and the base is now overwritten, so re-deriving it reads the baked ground as
  its own input. Measured anyway and labelled: 12.99 st worst deviation before, 12.91 after, over 36
  points -- the two are **not the same quantity** and neither is evidence. What is comparable is the
  ridge, from the same 1,530-ray scan: **150.89 at (-4434,-3806) before, 149.36 at (-4050,-3678)
  after** -- it moved 384 st east and dropped 1.53 st.
* **The four frames are looked at and described, from eye height, in her place after the bake**
  (`.screenshots/328j-after-A|B|C|D-view.png`, cropped to her viewport). **A** stand 4 looking north:
  a ridge line with rounded humps across the horizon where round 3's before-frame had a level,
  ridgeless horizon, bare carriageway in the foreground with a grass band. **B** on EW2 looking west:
  the carriageway reads as a pale bare strip with a tall grass verge beside it -- the near ditch is
  BEHIND that grass band and is not visible from this eye point, so the frame does not show it.
  **C** stand 10 looking east: a grass slope rising to a long bare ridge, a pale track to the right,
  and **no stand post or tower**, which the bake does not place. **D** (new) NS3 at a truck driver's
  7-stud eye looking north: the carriageway runs away between two grass edges and climbs into a long
  rounded hill -- 93.60 to 149.64 over 1,100 studs. **No tree is in any of the four**: the forest is
  planted at Play, and these are Edit frames.
* **The grade CHANGE at a pinned junction breaches design 7.1's rate** -- NS3 and NS4 print
  `grade change 10.00 % over 60 st` against a 2.40 % allowance. Printed, never hidden, and queued in
  `TASKS.md`'s 328j row; which of the two rules yields is the Architect's.
* **`deer_hitbox.spec:682`** failed once in five clean-tree runs on this branch and passed in the
  other four; the dispatch names it a known intermittent. The final run at `a18b4ac5` is 34/34.
* **`bake` has still never completed end to end.** It died in `epoch_for` after `log_run`, and the
  epoch was a hand call to `TerrainBake.stamp`, so no `[bake] OK: 208/208 ... epoch=...` line exists
  for C1 and the `parse_json` fix has not met a real Studio reply. 328e's wet run is the first that
  will. Re-running `bake` on C1 to produce that line would read the BAKED ground as its base, so it
  is not a thing to do for the sake of a line.
