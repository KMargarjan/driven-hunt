# Task 360b -- measurements

Task 360's denser stand-side forest put into **Karen's** Forest Test, **all eight cells**, and proved
there. **No `src/`, `tests/` or `tools/` file changed** -- this is a plant and its readings.

Place **Driven Hunt Forest Test** (130094961655666), **Edit**, served on `:34873` from
`driven-hunt-karen` at merged `main` **`3533e137`**; the tool run from `driven-hunt` on branch
`task-360b-ft-plant` at the same `3533e137`, clean tree. Never Saved, Published or Drafts-Committed:
the plant lives in her session (see `ESCALATE.md`, 2026-11-13 ~20:10 UTC). Probes, frames and logs:
`<runs-dir>/360b-*`.

Karen, 2026-11-13: *"first drive default position more trees neede back"*.

## 1. The run

| | |
|---|---|
| backup, before any write | `<backups-dir>/FT-before-360b.rbxl` **14,115,825 bytes**, header `<roblox!`, **19:35:11 UTC** -- File > Download a Copy, driven by this session (`360b-crop-filemenu.png`, `360b-crop-typed.png`, `360b-crop-after-save.png`) |
| the plant | `python tools/terrainbake.py plant --cells A1,B1,C1,D1,A2,B2,C2,D2 --backup <that file> --keep-flags <20 names>` -> `[bake] plant OK: 8 cell(s) @ 3533e137 PlantEpoch=58575af518ae6156 32966 models / 108396 parts in Workspace.GridForest (clean tree)`, **484.3 s of cell time** (`360b-plant.txt`) |
| the ground it was planted on | `TerrainEpoch=58575af518ae6156`, and the folder was stamped with that same epoch |
| flags | **20** of Karen's overrides declared with `--keep-flags` and left as found; `GRID_PREVIEW` is the tool's own exception. Never `flags.py clear` (lesson K). `DHFlag_PLACEMENT_IN_PLACE=true` and `DHFlag_MAP_PAINTED=true` left as found |
| why she saw none of 360 before this | `GridForest.PlantEpoch` already equalled `Terrain.TerrainEpoch`, so `ForestTest.prebuildVerdict` answers **STANDS** and the boot dresses nothing -- a planting change on the same ground is invisible until somebody re-plants (`replant-forest.sh` case 2). Measured here: the Edit census before the plant read C1 at **3,141** models, the committed planter makes **4,431** |

## 2. Planted / refused, by reason, per cell (dispatch step 3)

The stop was *"any cell refuses > 25 %"*. **The worst is D2 at 23.0 %, so the run continued.**

| cell | wanted | planted | refused | refused % | cliff | skipped | missing | parts | plan capacity | s |
|---|---|---|---|---|---|---|---|---|---|---|
| A1 | 4,690 | 4,087 | 603 | **12.9 %** | 329 | 274 | 0 | 12,927 | 7,196 | 55.9 |
| B1 | 4,404 | 4,052 | 352 | **8.0 %** | 352 | 0 | 0 | 14,040 | 6,919 | 49.2 |
| C1 | 4,483 | 4,431 | 52 | **1.2 %** | 52 | 0 | 0 | 16,344 | 8,041 | 51.8 |
| D1 | 4,618 | 4,476 | 142 | **3.1 %** | 142 | 0 | 0 | 13,560 | 9,005 | 66.1 |
| A2 | 4,674 | 4,245 | 429 | **9.2 %** | 170 | 259 | 0 | 12,534 | 7,226 | 64.3 |
| B2 | 4,673 | 3,891 | 782 | **16.7 %** | 735 | 47 | 0 | 12,141 | 7,277 | 62.5 |
| C2 | 4,545 | 4,172 | 373 | **8.2 %** | 329 | 44 | 0 | 15,022 | 7,427 | 70.3 |
| D2 | 4,691 | 3,612 | 1,079 | **23.0 %** | 1,029 | 50 | 0 | 11,828 | 7,360 | 64.2 |

Every refusal is **cliff** or **skipped**; `missing` is 0 everywhere. D2's and B2's are cliff: raw,
never-baked ground, the same reason 352b's A1 refused 324 sites.

### 2a. The absolute used-vs-cap figures (L-165, not the refusal percentage)

A cap breach can hide under a small refusal percentage, so the caps are read out rather than
inferred. `Places.PART_BUDGET_CELL = 18,200` parts bounds what is DRAWN in one cell and
`Places.CELL_PART_CAP = 4,840` is the same bound in models (the tool echoes it as `cap=4840`).

| | worst cell | used | cap | headroom |
|---|---|---|---|---|
| parts drawn in one cell | **C1** | **16,344** | 18,200 | **1,856 parts (89.8 % used)** |
| models drawn in one cell | **D1** | **4,476** | 4,840 | **364 models (92.5 % used)** |
| models the PLAN asked for | **D2** | **4,691** | 4,840 | **149 models (96.9 % used)** -- A1 is 4,690 (96.9 %), the figure task 360 section 3 disclosed |

**No cell hit a cap.** The plan sits within ~3 % of `CELL_PART_CAP` on A1 and D2, so the next
planting change that adds models to those two cells can breach it; nothing in this task does.

## 3. BEFORE | AFTER, one line each (L-127)

Every figure below was read **by this session**, both sides, with the same instrument, at
`3533e137` (L-162). Play figures come from `360b-play.sh BEFORE` and `360b-play.sh AFTER` -- one Play
session per side, `Workspace.Boars` cleared immediately before each park so both sides are measured
in the same empty world (`boarsDesc 0` printed on each line).

| Measurement | instrument / file | BEFORE | AFTER | verdict |
|---|---|---|---|---|
| `Workspace.GridForest`, Edit | `360b-census.luau` | **24,226** models / **79,463** parts, 8 cells | **32,966** / **108,396**, 8 cells | +36.1 % models |
| `Workspace`, Edit | same | 29,903 / 91,293 | 38,643 / 120,226 | -- |
| C1 eye rays, **Play**, 7 main stands | `360-ft-eye-w.luau`, `360b-eye2-*.txt` | wood<=150 **35/252 = 13.9 %**, escaped **199 = 79.0 %** | wood<=150 **77/252 = 30.6 %**, escaped **125 = 49.6 %** | **MET** |
| all 8 cells, eye rays, **Edit**, 56 stands | `360b-eye-all.luau`, `360b-eyeall-*.txt` | wood<=150 **324/2016 = 16.1 %**, escaped **62.5 %** | wood<=150 **473/2016 = 23.5 %**, escaped **51.4 %** | **MET** |
| sky/haze pixels at eye level, behind (Karen's S/SW) | `360b-GA-*.png`, measured | **15.6 %** | **0.9 %** | **MET** |
| sky/haze pixels at eye level, behind (due S) | `360b-GB-*.png`, measured | **13.9 %** | **0.7 %** | **MET** |
| sky/haze pixels at eye level, **in front** (due N) | `360b-GC-*.png`, measured | **0.4 %** | **0.3 %** | unchanged, as asked |
| frame p95, lobby spawn, eye height | `360b-park.luau`, `360b-frame2-lobby-*.txt` | **21.68 ms** (529 frames, mean 18.93) | **28.18 ms** (465 frames, mean 21.53) | **+30.0 % -- NOT MET** |
| frame p95, C1 stand 4, eye height | `360b-frame2-c1s4-*.txt` | **25.82 ms** (435 frames, mean 23.04) | **32.03 ms** (417 frames, mean 24.00) | **+24.1 % -- NOT MET** |
| client memory, lobby spawn | same | **5,248.4 MB** | **5,856.5 MB** | **+11.6 % -- NOT MET** |
| client memory, C1 stand 4 | same | **5,250.8 MB** | **5,867.3 MB** | **+11.7 % -- NOT MET** |
| console error lines in the Play run | `360b-console2-*.txt` | **0** | **0** | -- |

**The four NOT MET lines are stated and NOT tuned**, as the dispatch directs. The budget was +10 %;
the memory is +11.6 / +11.7 % and the frame p95 is +24 / +30 %. Task 360 already measured +11.3 % on
C1 alone; this plants eight cells, and all eight sit in the same Studio process whether or not
anything draws them. Nothing in this task makes them cheaper, and no number here was tuned to fit.

## 4. Every cell, its own stands, both sides (L-182 answered)

**L-182 is correct**: `360-ft-eye.luau` is hardcoded to C1's seven stand positions and C1's centre,
so it cannot speak for the other seven cells. Rather than report them NOT TAKEN, this session built
`360b-eye-all.luau`: the same ray rule (36 rays, 5 deg, the half-plane facing away from the cell
centre, 900-stud reach, eye = ground + 5), over **all eight cells' own stands**, run in **Edit**
where every cell's wood is in `Workspace.GridForest` (in Play only the dealt cell is). The stand and
centre literals are this session's own reading of `Grid.standGridOf` / `Grid.boundsOf` through a Play
server probe (`360b-stands.luau`) -- and **C1's seven reproduce `360-ft-eye.luau`'s hardcoded list to
within 1 stud**, which is what makes the generalisation checkable rather than asserted.

| cell | wood<=150 BEFORE | AFTER | escaped BEFORE | AFTER |
|---|---|---|---|---|
| A1 | 9.1 % | **9.5 %** | 55.2 % | **46.4 %** |
| B1 | 32.5 % | **38.5 %** | 20.6 % | **17.9 %** |
| C1 | 27.8 % | **37.7 %** | 40.5 % | **29.4 %** |
| D1 | 18.3 % | **27.0 %** | 63.9 % | **57.1 %** |
| A2 | 3.6 % | **13.1 %** | 95.6 % | **77.4 %** |
| B2 | 26.6 % | **37.7 %** | 57.9 % | **43.3 %** |
| C2 | 5.6 % | **16.7 %** | 77.8 % | **61.1 %** |
| D2 | 5.2 % | **7.5 %** | 88.5 % | **78.6 %** |
| **all** | **16.1 %** | **23.5 %** | **62.5 %** | **51.4 %** |

Every cell improves on both counts. **Two are weak and are not dressed up:** A1 gains 0.4 points of
close wood (9.1 -> 9.5 %) and D2 gains 2.3 (5.2 -> 7.5 %) -- the two cells whose plans sit at 96.9 %
of `CELL_PART_CAP` and, for D2, the cell that refused 1,029 sites to cliff. Their escaped-ray share
does fall (55.2 -> 46.4 % and 88.5 -> 78.6 %), so wood went in; it went in further out than 150
studs. **A2, C2 and D2 remain open country behind the stands** by this instrument, and nobody has
looked at those three on screen -- see section 6.

Note on the instrument: the centre this session read for C1 is (-3959, -4327); `360-ft-eye.luau`'s
literal is (-3899, -4371). The centre only sets the half-plane the rays are cast into, and a 75-stud
shift on a ~730-stud vector turns it by ~6 deg. **Both sides of every row above use the same centre**,
so the comparison holds; the absolute C1 percentages in section 3's Edit row are therefore not
directly comparable with task 360's Play figures, and are not claimed to be.

## 5. The frames (rule 5: opened and described)

All six are the Forest Test's own client, parked at **C1 stand 4** (-3905, 112.4, -5063), eye height,
by `360-holdA/B/C.luau`; the camera numbers are printed in `360b-hold2*-*.txt`.

* **`360b-GA-BEFORE.png` / `360b-GA-AFTER.png` -- Karen's own S/SW angle.** BEFORE: wide open grass,
  a pale horizon band and a distant blue ridge visible straight through the middle of the screen
  between widely spaced bare trunks. AFTER: the ridge and the horizon band are gone; a continuous
  dark spruce-and-birch wall fills the middle at ~15-40 studs, with one thin pale strip left far
  right between two trunks. Measured: 15.6 % -> 0.9 % sky/haze pixels in the eye-level band.
* **`360b-GB-BEFORE.png` / `360b-GB-AFTER.png` -- due south, straight behind the stand.** BEFORE:
  an open green clearing with distant **hills and open sky** across the whole width. AFTER: close
  trunks across the full frame, canopy closing the sky over the left two thirds, two small slivers of
  sky high on the right. 13.9 % -> 0.7 %.
* **`360b-GC-BEFORE.png` / `360b-GC-AFTER.png` -- due north, the wood IN FRONT.** The two read the
  same: the same birch and oak line, the same clearing, the same shadows, the same shotgun in hand.
  0.4 % -> 0.3 %. **The wood in front is exactly as before**, which is what the dispatch asked.
* **`360b-DRIVE-back.png`** -- the same camera **inside a live drive** (HUD: `DRIVE 1`, `1:47 TIME`,
  `HUNTER`, the player inside the yellow stand circle): the same close wall of trunks, no hills, no
  open horizon.

## 6. What is NOT proven

1. **Nobody has looked at the other seven cells' stands on screen.** Section 4 measures all eight
   with rays; the frames in section 5 are C1 stand 4 only. A1, A2, C2 and D2 are **NOT PROVEN by eye**.
2. **A1 and D2 are barely denser close in** (section 4). The ray count says so; whether Karen would
   call either one "trees close behind her" is **NOT PROVEN** -- nobody has seen them.
3. **The plant is not durable.** It stands in her open session and survived both a Play run and a
   place reload, but it is not in the saved place, and no agent may save it. `ESCALATE.md`.
4. **The drive was not started by a click on the pad itself, because there is no such click.**
   Measured (`360b-buttons.luau`): no `TruckSpot`/`TruckPad2-4` carries a `ClickDetector` or a
   `ProximityPrompt` -- the lobby's only world prompt is the shop counter. A **real OS keystroke** to
   walk onto the pad was tried twice and refused by the engine: `UserInputService` recorded
   `Enum.KeyCode.None` for a scan-code `W` (`360b-input.luau`; the defect `263key.ps1`'s own comment
   describes), with `WalkSpeed 16`, not anchored, and 0.00 studs moved. So the character was put on
   the pad by `lobby-go.luau` (standing rule I's documented route) and the **real click** was made on
   the pad's own `HunterHud.PadNext.RoleBlock.RoleSwitch.Hunter` control at screen (417, 668) --
   calibrated this session with two marker frames, `screen = abs + (4, 233)`, both landing on the
   predicted pixel. No phase was forced.

## 7. The drive (dispatch step 5), 96 s from the default stand

`360b-drive.luau`, sampled every 6 s, after the real click of section 6.4 (`360b-drive.txt`):

* the player stood at **-3905, -5062 -- C1 stand 4, the default first-drive stand** -- for all 16 samples;
* `team=Shooters`; the **`Shotgun` was in the CHARACTER**, not the Backpack, at every sample (standing rule A);
* **animals came**: 12 at +6 s, **peak 20**, 7 still out at +96 s;
* **console error lines in the whole session: 0** (`360b-console-DRIVE.txt`, searched for `Stack Begin`, `attempt to`, `invalid argument`).

## 8. The place was left as it was found

* `python ftplay.py mode` -> **Edit**, on `:34873` from `driven-hunt-karen`;
* **attribute diff EMPTY** (L-101): `360b-attrs-BEFORE.txt` vs `360b-attrs-AFTER.txt` are identical --
  the 21 `DHFlag_*` attributes and `DHForestLayout`, `DHForestStartRole`, `DHShopTestGrant`,
  `DHTestOwns` all unchanged. `flags.py --place forest clear` was never run;
* final census: `Workspace.GridForest` **32,966** models / **108,396** parts, 8 cells,
  `PlantEpoch=58575af518ae6156`;
* **never Saved, Published or Drafts-Committed**; no code was checked out in `driven-hunt-karen` (L-014).

## 9. One thing happened that is worth the Director's eye

Mid-session the Forest Test place closed itself and Studio showed
**"Multiple Sessions Detected ... This session has been closed ... Error Code: RCC-276"**
(`360b-padpanel-view.png`). The cause was a **second Studio process** that `ft-open.sh` had started
earlier -- `ft-open.sh` launches the `roblox-studio:` URI when no window titled *Forest Test* is
found, and a window that is loading does not yet carry that title. The stray process was closed and
the original session, with the plant in it, was unaffected (section 8's census). Worth a line in
`ft-open.sh`: it can spawn a duplicate that kills the session it was meant to rescue.
