# Task 340 — the world trim, run in Karen's Forest Test

Karen, 2026-11-09 ~12:40 UTC, asked *"remove the land outside the cells? (yes/no)"*: **"yes please"**.

Place **Driven Hunt Forest Test** (130094961655666), **Edit only**, served on `:34873` from
`driven-hunt-karen` at merged `main` `efc60d1e`; the tool run from `driven-hunt` at the same
`efc60d1e`, clean tree. No `src/`, `tests/` or `tools/` file changed. Never Save, Publish or Drafts
Commit. Frames and logs: `<runs-dir>/340-*`.

## The run

| | |
|---|---|
| backup, before any write | `<runs-dir>/FT-before-340.rbxl` **34,099,689 bytes**, header `<roblox!`, 15:19 local — File > Download a Copy, driven by this session (`340-filemenu-crop.png`, `340-savedlg2-crop.png`) |
| one block first (design 10.4 step 3) | `block 1/233 x[-7500,-7192] z[-7500,-6476]` **762 ms**, 8 s wall including ~7 s of one-time setup. **Extrapolated: 233 x 762 ms = 178 s of block time, so 3-9 min for the run** |
| the run | `[bake] trim OK: 233 of 233 block(s) filled with Air`, exit **0**, **310 s wall**, mean 0.9 s a block (`.terrainbake/20261109T142514Z-trim.json`). Not interrupted; no resume and no restore from the backup were needed |
| flags | 13 of Karen's overrides declared with `--keep-flags` and left as found; `GRID_PREVIEW` and `RANGE_SOLO` are the tool's own exception. Never `flags.py clear` (lesson K) |
| parts moved | **0** — design 10.3: every part outside the keep boxes is rebuilt each boot or is a template source that must stay findable |

## Before and after, each on one line (L-127)

| Measurement | BEFORE | AFTER |
|---|---|---|
| terrain lattice, step 500 over ±10000 (`trim plan`) | **841 / 1681** nodes occupied, **738 outside** the keep boxes | **103 / 1681** occupied, **0 outside** — design 10.4 step 5's target T4 |
| terrain occupied extent | x[-7000..7000] z[-7000..7000] y[9..548] | x[-7000..3500] z[-7000..-1500] y[46..400] |
| `Workspace` in a Play server | **50,763** instances / **22,118** parts | **50,769** / **22,120** |
| boot — the lobby takes the player | **+4 s** | **+4 s** |
| client memory at the lobby spawn | **4,826.2 MB** | **4,284.4 MB** (−541.8) |
| client memory at the C1 stand | **4,842.6 MB** | **4,303.8 MB** (−538.8) |
| frame time at the lobby spawn, eye height | mean **26.19 ms**, p95 **37.94 ms** (383 frames) | mean **22.63 ms**, p95 **29.02 ms** (443 frames) |
| frame time at the C1 stand, eye height | mean **24.37 ms**, p95 **31.56 ms** (411 frames) | mean **23.58 ms**, p95 **28.53 ms** (424 frames) |
| File > Download a Copy | **34,099,689 bytes** | **11,545,437 bytes** — **−22,554,252, −66.1 %** |
| trim wall time | — | **310 s** for 233 blocks |

The `Workspace` +6 instances / +2 parts are **all in `Lobby`**, which the boot builds fresh: three
runs read 1,627, 1,633 and 1,639 descendants **before** the trim and 1,639 after, so that column is
run-to-run drift of the boot, not the trim. Every other folder is identical below.

## The census, read by this session on both sides, not taken from the run's own printout (L-182)

Edit (`340-census.luau`, `340-census-edit-before.txt` / `-after.txt`) — **identical line for line**:

| Folder | before | after |
|---|---|---|
| `OurForest` | 24,191 desc / 9,901 parts | 24,191 / 9,901 |
| `Session` (two folders) | 264 / 118 and 3,293 / 1,420 | 264 / 118 and 3,293 / 1,420 |
| `LobbyAssets` | 451 / 389 | 451 / 389 |
| `GridForest` (7 cells; C1 20,516 / 9,318) | 122,847 / 55,254 | 122,847 / 55,254 |
| `Workspace` | 151,056 / 67,084 | 151,056 / 67,084 |

Play (`340-worldcensus.luau`) — `GridWood` 102,330 / 45,936 (A2,B1,B2,C2,D1,D2) both sides;
`GridForest`=C1 20,517 / 9,318 both sides; `ForestMarkers` 16 / 16, `HighSeats` 45 / 42,
`Range` 49 / 13, `LobbyAssets` 451 / 389, `OurForest` 24,191 / 9,901, both `Session` folders —
**all identical**. `Lobby` 885 → 887 parts, the boot drift above.

**Attribute diff: EMPTY.** `340-attrs-BEFORE.txt` (captured before `trim`, this session's first
write — `trim plan` is read-only) vs `340-attrs-AFTER.txt`: all 15 `DHFlag_*`, `DHForestStartRole`,
`DHShopTestGrant` and `DHTestOwns` byte-identical (L-101).

## The 423 the run reported, settled by an independent instrument

`[bake] trim OK` says *"the run's own probe read 16317 hit(s) before and 423 after"*; 107 blocks
ended with 1-4 hits of their 100 samples. **This session's own sweep — a downward ray every 100
studs over the whole world box, every point outside K1 ∪ K2 (`340-residue.luau`) — read 0 terrain
hits of 20,281 points.** The 423 are a block's max-edge samples read before the neighbouring block
that owns that edge had run; the final state is clean. (One-sided: that sweep was written after the
run, so it has no before reading. The two-sided instrument is the step-500 census above.)

## The frames

Taken in **Edit**, where the camera is ours: in Play the game's camera owner reclaims a scriptable
camera, and the first attempt's "frames" were the player's own view. Identical camera numbers on
both sides; each PNG's sha printed (`340-frames.sh`) against the known `screen_capture` caching
fault.

| Frame | camera | what is IN it |
|---|---|---|
| `340-F1-before/after.png` | 3000, **144** (ground +5, eye height), −2109.5 → east | green grass, a big oak centre, birch right, spruce left, a treeline on the horizon, blue sky. **No visible change** |
| `340-F1b-before/after.png` | 3000, **219** (+80), −2109.5 → east | the lobby wood's canopy, oaks and spruce over grass, treeline, sky. **No visible change** |
| `340-F2-before/after.png` | −4496.8, **115** (ground +5), −4746.3 → out of the grid | the C1 forest road running north between spruce and birch, grass ruts, horizon. **No visible change** |
| `340-F2b-before/after.png` | −4496.8, **190** (+80), −4746.3 → out of the grid | the same road from above; at its far end a faint pale patch where the land now ends |
| `340-G-before/after.png` | −1600, **1500**, 2600 → down over the world | BEFORE: hazy land to the horizon, scattered trees and ponds. AFTER: **the ground outside the keep boxes is gone** — one flat island of land in the distance (the grid and its wood), and scattered trees left hanging in the air |

**Measured, not eyeballed** (`340-pixdiff.py`): pixels differing by more than 8/255 —
F1 **0.00 %**, F1b **0.03 %**, F2 **3.51 %**, F2b **0.31 %**, **G 47.96 %**. A control of two
captures of the *same* camera two seconds apart reads **3.69 %**, above F2's 3.51 %: F2's difference
is the animated terrain grass, not the trim. Only G is above the noise floor.

## What Karen will see, and the one thing for the Director

From **both** of her viewpoints — the lobby spawn and a C1 stand, at eye height — **nothing changed**:
K2's own wood closes the outlook east, and the grid's wood closes it north. The removal is visible
only from the air.

**The trees over the void are real and they are the design's own decision.** `340-floaters.luau`:
**1,862 parts stand outside the keep boxes and 1,614 of them now have no ground under them** —
`Session` 1,488 and `LobbyAssets` 126, the template sources `docs/design/cell-loading.md` 10.3 keeps
on purpose (`Places.pickTemplate` chooses by scale among every instance of a name, so thinning them
quarantines the name and nothing plants). Worst: `Workspace.Session.Tree8.Part` at 2584, 412, −6332.
They are what the scattered floating trees in `340-G-after.png` are. Karen cannot see them from the
ground; she can from a tower or the air. **Not this task's to fix** — 337c, the skirt, is next.

## Gate

- `bash smoke.sh` → **SMOKE PASS**: gun in hand at +16 s and at 80 s, **stacks=0 errorLines=0**,
  waves=11, player on the ground y=110.5, respawn ok (`smoke-console-1109-153219.txt`).
- **One cell drive started** in the after Play: `[ForestTestBoot] prebuilt forest: STANDS,
  16818 model(s) in 7 cell folder(s)`, `markers: layout=C1 15/15 stands (0 refused)`,
  `[seats] C1: 3 built, 0 refused`, and lines 1-5 released. **0 console error lines** in both the
  before and the after Play (`340-console-before.txt`, `340-console-after.txt`).
- No harness run: no code change (dispatch GATE). No review round: the Director checks this file.
