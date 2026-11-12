# Task 352b — task 352's forest put into Karen's Forest Test, and the stand pick diagnosed

Karen, 2026-11-12 ~10:45 UTC, on the painted map with her red marks: *"marked where need more trees
like edges has to be with trees also feeling forest and those gaps also full of trees"*. Task 352
put A1 into `Grid.PLANTED_CELLS`; this task plants it in **her** place and measures it there.

Place **Driven Hunt Forest Test** (130094961655666), **Edit**, served on `:34873` from
`driven-hunt-karen` at merged `main` `794c232d`; the tool run from `driven-hunt` on branch
`task-352b-ft-proof` at the same `794c232d`, clean tree. **No `src/`, `tests/` or `tools/` file
changed.** Never Saved, Published or Drafts-Committed: the plant lives in her session. Frames,
probes and logs: `<runs-dir>/352b-*`.

## The run

| | |
|---|---|
| backup, before any write | `<runs-dir>/FT-before-352b.rbxl` **12,779,792 bytes**, header `<roblox!`, 18:37 UTC — File > Download a Copy, driven by this session (`352b-filemenu-crop.png`, `352b-savedlg2-crop.png`) |
| the plant | `python tools/terrainbake.py plant --cells A1 --backup <that file> --keep-flags <18 names>` → `[bake] plant OK: 1 cell(s) @ 794c232d PlantEpoch=58575af518ae6156 3627 models / 11537 parts in Workspace.GridForest (clean tree)`, **144.6 s** |
| planted / refused, by reason | **3,627 of 4,225 planted**; refused **598 = 14.2 %** — **324 cliff**, **274 skipped**, **0 missing**. Under the dispatch's 25 % stop, so the run continued. Cap 6,434, row hash `be3b7030` |
| the ground it was planted on | `TerrainEpoch=58575af518ae6156`, and the folder was stamped with that same epoch. A1's raw, never-baked ground is why 324 sites were rayed onto a cliff and refused |
| flags | 18 of Karen's overrides declared with `--keep-flags` and left as found; `GRID_PREVIEW` and `RANGE_SOLO` are the tool's own exception. Never `flags.py clear` (lesson K) |

**L-164 answered before anything was measured.** `python tools/flags.py --place forest`
(`<runs-dir>/352b-flags-before.txt`), read live off place 130094961655666:
`DRIVE_VARIETY  off on on` and `DRIVE_AIMS_AT_PICKED_STAND  off on on` — both overridden ON and
both resolving ON, as the dispatch assumed. `STAND_PICK off on on`. **`PLACEMENT_IN_PLACE` is
`off off off`**, which is worth the Director's eye: the flag's own text says the aimed drive and the
beds *"were measured together"* with it ON, and in her place it is OFF.

## Before and after, each on one line (L-127)

| Measurement | BEFORE | AFTER | vs the +10 % budget |
|---|---|---|---|
| `Workspace.GridForest`, Edit | **151,080** desc / **67,926** parts, **7** cells | **176,494** / **79,463**, **8** cells | — |
| `GridForest/A1`, Edit | **absent** | **25,413** desc / **11,537** parts / **3,627** models | — |
| `Workspace`, Edit | 179,289 / 79,756 | 204,703 / 91,293 | — |
| `ServerStorage.GridWood`, Play | 125,491 / 56,281 (A2,B1,B2,C2,D1,D2) | 150,905 / 67,818 (**A1**,A2,B1,B2,C2,D1,D2) | — |
| `Workspace.GridForest`, Play | **C1 only** | **C1 only** | A1 is never rendered: it waits in `ServerStorage` until a drive is dealt in it, and A1 is not in `ROTATION_CELLS` |
| boot — the lobby takes the player | **+6 s** | **+6 s** | — |
| frame p95, lobby spawn, eye height | **26.21 ms** (488 frames, mean 20.51) | **19.71 ms** (582 frames, mean 17.23) | **−24.8 % — MET** |
| frame p95, C1 stand 11, eye height | **26.35 ms** (437 frames, mean 22.93) | **25.32 ms** (438 frames, mean 22.84) | **−3.9 % — MET** |
| client memory, lobby spawn | **3,895.8 MB** | **4,808.4 MB** | **+23.4 % — NOT MET** |
| client memory, C1 stand 11 | **3,909.1 MB** | **4,816.9 MB** | **+23.2 % — NOT MET** |
| console error lines in the Play run | **0** | **0** | — |

**The frame figures needed a control, and it is declared rather than hidden.** The first after run
read p95 **30.72 / 28.27 ms** and looked like a +17 % regression. It was not the forest: that run's
census read **1,446 descendants in `Workspace.Boars`** where the before run's read **0** — the drive
had released animals into the difference. The AFTER row above is `352b-play3.sh`, which clears
`Workspace.Boars` immediately before each park so both sides are measured in the same empty world
(**boarsDesc 0** printed on the line itself), with the same instrument, the same two cameras and the
same 10 s sample as the before. A middle run with the parks taken first is kept for comparison
(`352b-frame-*-after2.txt`, boarsDesc 2,376 and 4,488).

**The memory is NOT MET and the boars do not explain it** — it is +900 MB on both stations with
`boarsDesc 0` on both sides. A1's 25,413 instances sit in `ServerStorage.GridWood` in the same
Studio process whether or not anything draws them, and nothing in this task makes them cheaper.

**No after backup was taken.** The dispatch asked for the backup *before* any write and that is what
`FT-before-352b.rbxl` is; task 340's "File > Download a Copy, after" row has no counterpart here.

## The census, read by this session on both sides (L-182)

`<runs-dir>/352b-census-edit-before.txt` / `-after.txt`, the same probe (`340-census.luau`), run by
this session — not the plant's own printout. **Every cell but A1 is identical, model for model:**

| Cell | before | after |
|---|---|---|
| A1 | **absent** | **25,413 / 11,537** |
| A2 | 21,182 / 9,064 | 21,182 / 9,064 |
| B1 | 21,746 / 10,372 | 21,746 / 10,372 |
| B2 | 18,594 / 8,069 | 18,594 / 8,069 |
| C1 | 25,588 / 11,645 | 25,588 / 11,645 |
| C2 | 23,339 / 10,836 | 23,339 / 10,836 |
| D1 | 21,359 / 9,169 | 21,359 / 9,169 |
| D2 | 19,265 / 8,771 | 19,265 / 8,771 |
| `OurForest`, `LobbyAssets`, both `Session` folders | 24,191/9,901 · 451/389 · 264/118 · 3,293/1,420 | all four identical |

L-182 warned that task 352's planning data moved B1 3,906→3,964 and B2 4,123→4,118 when A1 was
touched. **Nothing of the kind happened to the planted wood**: the whole-container census is
unchanged outside A1, and no cell lost a model.

**Attribute diff: EMPTY** (L-101). `352b-attrs-BEFORE.txt` (taken before any write) against
`-AFTER.txt`, and again against `-FINAL.txt` after the crash recovery below: all 20 `DHFlag_*`,
`DHForestLayout`, `DHForestStartRole`, `DHShopTestGrant` and `DHTestOwns` byte-identical.
`349-setup.luau` writes `DHForestLayout=C1` and `DHForestStartRole=hunter`, which were already
their values.

## The frames — Edit, identical camera numbers on both sides, every one opened and read

Taken in **Edit**, where the camera is ours (`352b-frames.sh`); each PNG's sha printed against the
known `screen_capture` caching fault, and all twelve differ.

| Frame | camera → look | what is IN it |
|---|---|---|
| `352b-F1-before/after.png` | C1 **stand 11**, −4504.3,**134.08**,−4087.3 → outward (south, out of the grid) | C1's own spruce and birch filling the view, grass, a treeline, sky. **No visible change** |
| `352b-F1b-before/after.png` | C1 **stand 11**, the same point → **west**, towards A1 | a wall of spruce across the whole upper half, and a flat pale water surface filling the lower half — present and identical on BOTH sides. **No visible change**: A1 is 1,100 studs away behind C1's own wood |
| `352b-F2-before/after.png` | **B1 stand 8** (−5609.7,89.69,−4735.6), the A1/B1 road — a stand a drive really deals → **west into A1** | BEFORE: the gravel road across the bottom, B1's edge spruce on green grass, and beyond them **an open grassy hillside with no tree on it all the way to the horizon** — Karen's gap. AFTER: that hillside is **full of spruce in two depths**, closing the view; only slivers of sky and a narrow strip of grass are left |
| `352b-F3-before/after.png` | **A1 stand 11** (−6728.3,130.86,−4087.3), the **westernmost stand point in the world** → **east into A1** | BEFORE: bare grass, a hillside on the left, and **five or six spruce on the far horizon**. AFTER: **a full spruce treeline across the whole width of the frame**, reflected in the water below |
| `352b-F3b-before/after.png` | the same outer-edge point → **outward (west, out of the world)** | BEFORE: bare grass and sky. AFTER: **spruce along the entire width above the waterline**, with their reflections under them — from the outer edge, looking out, there are still trees |
| `352b-F4-before/after.png` | −6123,700,−2900 → down over A1 | BEFORE: the left two-thirds of the land is **bare green-tan grass** (A1); B1's wood starts abruptly at the right. AFTER: **A1 is wood to the water's edge**, continuous with B1's, with a few thinner patches in the south-centre |

**Measured, not eyeballed** (`352b-pixdiff.py`), pixels differing by more than 8/255:
F1 **2.30 %**, F1b **0.50 %**, F2 **27.76 %**, F3 **28.21 %**, F3b **21.96 %**, F4 **15.50 %**.
Task 340's control — two captures of the *same* camera two seconds apart — read **3.69 %**, so F1
and F1b are **below that noise floor** (nothing changed from C1 stand 11, which is what the geometry
says should happen) and the four A1-facing frames are far above it.

**The M map ends in wood** (`352b-map-crop.png`, cropped out of a live Play frame): A1, the top-left
cell, is painted **solid CONIFER dark green edge to edge**, with no OPEN patch in it. That is honest
only with a caveat: the map's ground layer is drawn by `MapUi.groundFromGrid` from the **recipe
data**, so the map already painted A1 as wood at `794c232d`. What this plant changed is that **the
world now matches the map**.

**One thing about A1's ground, for the Director.** At A1 stand 11 a camera at eye height (ground +5)
sits **at the waterline** — the lower half of F3 and F3b is water, and the new spruce there stand in
it. A1 is not in `ROTATION_CELLS`, so no drive deals a stand there and nobody is put in that water
today; but A1's west flank is wet, and a bake of A1 would have to answer it.

## Task 349's action, from stand 4 and from stand 11

Two drives, C1, `DRIVE_VARIETY` and `DRIVE_AIMS_AT_PICKED_STAND` both ON, ~6 s samples across the
whole 300 s drive (`352b-ft.py` / `352b-ft2.py`, task 351's instrument).

| | target | **stand 4** | **stand 11** |
|---|---|---|---|
| how the stand was reached | — | the pick did not take — he was dealt it (see below) | **a REAL click: `clicked row 11 -> 11 WEST YOURS`** |
| samples on that stand | — | 46 of 46 clocked | **47 of 47 clocked, within 20 studs** |
| first sighting after the drive opened | ≤ 30 s | **7 s — MET** | **36 s — NOT MET** |
| median gap between samples with an animal in sight | ≤ 20 s | **6.0 s — MET** | **6.0 s — MET** |
| worst gap | — | 19 s | 32 s |
| samples with an animal in sight | — | 40 of 46 (median 6 visible, worst 23) | 32 of 47 (median 4 visible, worst 14) |

Tracks: `<runs-dir>/352b-s11-track.txt` (stand 4) and `352b-s11c-track.txt` (stand 11). The stand-11
run's sighting frame is taken from `eye=-4504.4,133.8,-4087.3`, which is stand 11's own point.

**The aimed drive does reach the west flank** — stand 11 sees an animal in two samples out of three
and never waits longer than 32 s — but **it takes 36 s to show her the first one**, against the
dispatch's 30 s. Stand 4, on the main line, is quicker on both counts. That gap is the Director's to
decide on; it is not a defect this task was asked to fix.

## The stand pick: reproduced, then found to be MY instrument and not the game

Task 351 logged `clicked row 11 -> 11 WEST FREE` and the hunter was dealt stand 4. **Reproduced
first**, same place, same flags: `352b-s11-pick.txt` holds all fifteen rows before and after the
click and **not one of them changed**, and `352b-s11-track.txt` reads `stand=4` for every sample of
that drive. Then it was taken apart, and **the game is not at fault**.

**THE CAUSE: `click.ps1` activates the Studio window before it moves the cursor, and the client
re-centres the pointer when the window is activated.** After a `click.ps1` call the client reports
`GetMouseLocation = 804,392` — **exactly half of its own 1609x784 viewport** — and
`GetGuiObjectsAtPosition` there returns `Canvas > CellC2 > GroundC2_42_5 > FullMap`, the map canvas,
not a row (`352b-clicktest.txt`). **The click lands in the middle of the map and no ask is ever
sent**: the footer stays at `"click a stand"`. That is task 351's line exactly — a click that
reported a row and reached nothing. `click.ps1` is `<runs-dir>`, not the repo; the same tap is in
`351-ft.py`'s `pick_stand` and its `start` block.

**THE PROOF THAT THE GAME IS FINE.** Hold the focus first, park the cursor, then click with no
re-activation (`352b-focuspark.ps1` then `352b-rawclick.ps1`) and the pick works:

| aimed | what the game answered |
|---|---|
| Row4 with offset 175 | **`"stand 3 is yours"`, `Row3 3 MAIN YOURS`** — a claim, one row above the one aimed at |
| Row11 with offset **219** | **`"stand 11 is yours"`, `Row11 11 WEST YOURS`** (`352b-aim2-11.txt`) |
| a whole drive, Row11 with offset 219 | `clicked row 11 -> 11 WEST YOURS`, and the hunter stood on stand 11 for all 47 clocked samples |

So `StandPick`, `Match.onStandRequest`, the remote and the map rows all do what task 323 says they
do. **Nothing in `src/` needs fixing for the pick.**

**Two traps, written down so the next run does not fall into them.**

1. **`GetMouseLocation()` and `GetGuiObjectsAtPosition()` read one row LOW** for this
   `IgnoreGuiInset` ScreenGui. Parking the cursor at the point computed with offset 175 made the
   client report `Row11(TextButton)` topmost under the mouse — and the click claimed **stand 10**.
   Aiming Row11 with offset 219 made it report `Row12`, and the click claimed **stand 11**. The
   probe is 44 px — one row — out of step with the `TextButton`'s own `AbsolutePosition`. **The
   claim outcome is the instrument; the hit-test probe is not.**
2. That is what cost this session its first diagnosis. Aiming with 175 put the click on rows **8**
   and **10**, which are C1's towers (`Workspace.HighSeats = Seat8 | Seat10 | Seat13`,
   `HighSeats.standsFor("C1") = {8,10,13}`), and the server **correctly** refused them with
   `StandPick.REASON.SEAT` — `"you need tree-stand access"` — because `ServerStorage.DHTestOwns`
   carries no high-seat item. A right refusal on a row I did not mean to click read as a wrong
   refusal on the row I did.

**What the Director may want anyway:** `351-ft.py`'s own constants are `OX, OY = 5, 232`, which is
geometrically fine — 232 lands 13 px below a row's centre and a row is 42 px tall — so the ONLY
thing that has to change in the harness is the window activation. `352b-ft2.py` is that change
(focus-park, then a bare click) and it is the file that produced `11 WEST YOURS`. Both live in
`<runs-dir>`; no repo file is involved.

## What Karen will see

A1 is a forest in her place: from **B1 stand 8**, the stand on A1's own road, the empty hillside is
gone and there is wood in front of her (F2); from the **outer-edge** stand on A1's west flank there
are trees looking in and trees looking out (F3, F3b); from the air A1 is wood to the water (F4).
From **C1 stand 11** nothing changed, and nothing should have — C1's own wood closes that view at
1,100 studs (F1, F1b, both below the noise floor). The M map's A1 corner is solid conifer.

**And the stand she clicks is the stand she gets.** Proven on screen: `11 WEST YOURS`, and a whole
drive stood on stand 11.

## Gate

- `bash <runs-dir>/smoke.sh` → **SMOKE PASS**: gun in hand at +17 s **and** at 80 s, **stacks=0
  errorLines=0**, waves=10, player on the ground y=110.5, respawn ok, worst 1 boar sound at once
  (`smoke-console-1112-203055.txt`).
- No harness run: no `src/`, `tests/` or `tools/` change (dispatch GATE). No review round: the
  Director checks this file, as for task 340.
- **Studio dropped the place with `RCC-277` during the first smoke attempt**, and Studio's own
  session recovery brought it back **with the plant intact** — the census read back 176,494 / 79,463
  in 8 cells and A1 25,413 / 11,537 / 3,627, line for line the AFTER column above. Written up in
  `ESCALATE.md` at the hard stop (lesson V280). The place ends **in Edit, on `:34873` from
  `driven-hunt-karen` at `794c232d`**; because it re-opened, the **Rojo plugin needs a Connect**
  before the next sync — the plant and the place's own scripts are unaffected, and smoke passed
  without it.
