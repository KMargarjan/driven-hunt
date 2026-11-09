# Task 337c measurements — the skirt on all four roads, and the cell budget

Every pair below is ONE instrument read twice: before at main `efe88ab2`, after at the code commit
`183a38fe`, in Karen's Forest Test (place 130094961655666). Raw output:
`<runs-dir>/337c-measure-before-final.txt`, `<runs-dir>/337c-measure-after.txt`,
`<runs-dir>/337c-census-BEFORE.txt` and `-AFTER.txt`, `<runs-dir>/337c-control-base.txt`,
`<runs-dir>/337c-harness-7.txt`.

## 1. THE BUDGET, as its own ledger (lesson L-165)

| row | before (`efe88ab2`) | after (`183a38fe`) | cap | verdict |
|---|---|---|---|---|
| `PARTS_PER_MODEL` | 3.03 (C1's 328m mix) | **3.76** (C1 live 9,318 parts / 2,476 models) | — | re-derived |
| worst cell PLAN, models | D2 2,624 | **D2 3,256** | `CELL_PART_CAP` 2,640 -> **3,404** | slack 16 -> **148** |
| worst `cellCapacity`, sites | D1 5,891 | **D1 7,025** | `CELL_PLAN_CAP` 7,260 -> **7,180** | slack 1,369 -> **155** |
| worst cell DRAWN in her place, parts | **C1 9,318 — OVER the 8,000 budget** | **C1 11,645** | `PART_BUDGET_CELL` 8,000 -> **12,800** | breached -> **1,155 parts of slack** |
| whole prebuild, `Workspace.GridForest` | 16,818 models / 55,254 parts | **20,599 / 67,926** | — | +22.5 % / +22.9 % |

`PART_BUDGET_CELL` 12,800 is still **4,200 parts under** the only MEASURED ceiling there is: 328g's
client frame, <= 16.7 ms with <= 17,000 parts inside 1,024 studs (`grid-terrain.md` 12.2).
`PART_BUDGET_DRIVE` 27,000 bounds the PLAN, and nothing renders a plan.

Live parts per model measured both ways, both reported: **C1 alone 11,645/3,141 = 3.71**;
**all seven cells 67,926/20,599 = 3.30**. 3.76 is the worst cell, which is the conservative choice
for a per-cell cap.

## 2. SKIRT TREES PER CELL SIDE

Harness note at both commits (the `per cell` and `skirt` lines):

| cell | skirt before | skirt after | sides dressed before | sides dressed after |
|---|---|---|---|---|
| A1 | 0 | 588 | 0 of 2 | **4 of 4** (2 outer) |
| B1 | 182 | 645 | 1 of 3 (A1 only) | **4 of 4** (1 outer) |
| C1 | **0** | **666** | 0 of 3 | **4 of 4** (1 outer; 152 rows outside the footprint, 514 into planted neighbours) |
| D1 | 0 | 644 | 0 of 2 | **4 of 4** (2 outer) |
| A2 | 131 | 692 | 1 of 2 (A1 only) | **4 of 4** (2 outer) |
| B2 | 0 | 699 | 0 of 3 | **4 of 4** (1 outer) |
| C2 | 0 | 607 | 0 of 3 | **4 of 4** (1 outer) |
| D2 | 0 | 632 | 0 of 2 | **4 of 4** (2 outer) |

Reach, measured from the shared road's own centre line: 250-253 studs, against `skirtStuds` 230
plus `CELL_EDGE_STUDS` — the band's far edge, exactly as `grid.spec` case 16 bounds it.

## 3. NO TRUNK ON A ROAD, A PAD OR A BEATER LINE (dispatch item 2)

One pair, one line, from `grid.spec` case 16 over all eight cells: **nearest road centre, skirt
35.90 studs / own wood 34.32 studs**, with the verge ending at 34.0. The skirt's roadside edge is
no closer to the carriageway than the cell's own. Every skirt row also answers `nil` to
`Places.maskGrid(groundCell, x, z, model, scale)` — road, ditch, verge, ride, stand pad, tower,
front cone and beater corridor of the cell whose GROUND it stands on, asked with the template and
the scale the draw settled.

## 4. OPEN GROUND BEHIND EACH ROAD — Karen's sentence as a number

A 20-stud lattice over the 230-stud band on the far side of each of the standing cell's four roads;
a point is OPEN when no standing trunk is within 25 studs (`<runs-dir>/337c-open.luau`, which
computes the band from `Grid` and never from `Places.skirtBands`, so both runs are one instrument).

| cell standing | before | after | west | east | north | south (after) |
|---|---|---|---|---|---|---|
| C1 | **100.0 %** (3,024 of 3,024) | **37.6 %** | 36.3 % | 46.5 % | 31.8 % | 33.3 % |
| D2 | **100.0 %** | **49.0 %** | 36.0 % | 51.7 % | 58.0 % | 53.9 % |
| B2 | **100.0 %** | **38.0 %** | 35.0 % | 40.5 % | 35.5 % | 41.2 % |

Standing trunks round the active cell: C1 2,387 -> **3,049**, D2 2,024 -> **2,530**,
B2 1,953 -> **2,626**. The band's far half is planted at `deepSpacingStuds` (52 on C1), so a
25-stud reach leaves open lattice points there by construction; the frame in section 7 is what
says whether that reads as wood.

## 5. FRAME TIME AND CLIENT MEMORY, same station, same ordinal in the session

| station | before mean / p95 | after mean / p95 | before memory | after memory |
|---|---|---|---|---|
| C1 stand 8, eye height, looking out | 16.92 / **19.22** ms | 17.06 / **20.03** ms | 4,384.1 MB | **5,353.3 MB** |
| B2 stand 8, eye height, looking out | 17.08 / 22.64 ms | 17.59 / 23.23 ms | 4,433.9 MB | 5,429.1 MB |
| D2 stand 8, eye height, looking out | 17.09 / 21.47 ms | 16.96 / 21.54 ms | 4,419.0 MB | 5,389.9 MB |
| C1 top-down, 2,600 studs | 18.26 / 31.04 ms | 18.08 / 33.12 ms | 4,401.0 MB | 5,373.1 MB |

**THE DISPATCH'S GUARD: p95 at a C1 stand no more than 10 % above task 340's 28.53 ms, i.e.
<= 31.38 ms. Measured 20.03 ms. MET**, with 11.3 ms to spare. Memory is reported, not bounded:
**+969 MB at the C1 stand** (4,384.1 -> 5,353.3), the cost of 12,672 more parts in the place.

## 6. SWAP — AND IT IS THE ONE TARGET THAT IS NOT MET

`Cells.reconcile(want)`'s own `ms`, same probe both sides (`<runs-dir>/337c-swap.luau`):

| swap | before | after | design T7 |
|---|---|---|---|
| -> D2 | 347 ms | **468 ms** | <= 500 ms |
| -> B2 | 271 ms | **573 ms** | **over** |
| -> C1 | 254 ms | **661 ms** | **over** |
| boot (stand one, store six) | 950 ms (task 336) | **1,214 ms** | not bounded |

**NOT MET.** `cell-loading.md` T7 names its own fallback — a per-model move in `Slice` bites, with
`Slice.ORDER` gaining `store = 1, stand = 2`. That is a separate task; nothing in 337c's scope
moves it, and a 661 ms swap happens between drives, not during one.

## 7. FRAMES

- **`337c-F1-before.png` / `337c-F1-after.png`** — C1 stand 8, eye height, camera
  (-4496.8, 115.0, -4746.3) looking (-4726.8, 55.0, -2759.6), out of the cell across its flank
  road. **BEFORE: C1's own birch edge on the left, the dirt road running away, and across it an
  empty green field to the horizon — no wood at all behind the road.** **AFTER: the same road,
  the same light, and a dense spruce wood standing on BOTH sides of it all the way into the haze;
  the carriageway itself is still clear.** That is Karen's sentence, before and after.
- **`337c-G-before.png` / `337c-G-after.png`** — top-down 2,600 studs over C1. BEFORE: one
  speckled rectangle (C1's own wood) with bare ground round it. AFTER: that rectangle plus a wide
  speckled band on all four sides, which is the skirt. Both are hazy at that height; identical
  camera numbers on both sides.
- **`337c-F2` (a D2 stand): NOT OBTAINABLE, with the measured reason.** A Play client streams
  terrain and wood around its own CHARACTER. With the player standing in C1, a camera parked at a
  stand 1,500 studs away in D2 gets no ground — `workspace:Raycast` answers nil, so the first run's
  camera sat 86 studs under the terrain (`337c-F2-before.png`, `337c-FB2-before.png`) — and no
  trees: `337c-F2b-after.png` shows D2 standing on the server and bare hills on the client, after
  `RequestStreamAroundAsync` and 15 s of retries. Walking the player to D2 is a drive this session
  did not have time for. **The D2 and B2 evidence that IS a before/after pair from one instrument
  is section 4's lattice: 100.0 % open -> 49.0 % and 38.0 %.**

## 8. THE PLACE

- Backup **before any write**: `<runs-dir>/FT-before-337c.rbxl`, 11,545,437 bytes, header
  `<roblox!`, taken by this session through File > Download a Copy
  (`337c-filemenu-crop.png`, `337c-savedlg4-crop.png`).
- Plant, at the code commit, out of the `driven-hunt-rev` worktree:
  `[bake] plant OK: 7 cell(s) @ d84337a63e854cb548072af75eae263cf100cc6f PlantEpoch=58575af518ae6156
  20599 models / 67926 parts in Workspace.GridForest (clean tree)`. Sites the plant's own rays
  refused, per cell: C1 47 cliff, C2 223, A2 105, B1 128, D1 30, B2 555, D2 562 — 0 skipped and
  0 missing everywhere.
- Boot: `[ForestTestBoot] prebuilt forest: STANDS, folder=true, 20599 model(s) in 7 cell folder(s),
  live=58575af518ae6156 planted=58575af518ae6156, dress=false`.
- `smoke.sh` **PASS**: gun in hand at +16 s and at 80 s, stacks=0, errorLines=0, waves=10, the
  player on the ground at every sample.
- **Attribute diff EMPTY** (`337c-attrs-BEFORE.txt` against `-AFTER.txt`: 15 flags and 3 settings,
  all Karen's, left as found through `--keep-flags`).
- Nothing was Saved, Published or Drafts-Committed. Nothing was checked out in `driven-hunt-karen`.

## 9. THE FLAKE, with a control (Vnight-1027)

`map_ui.spec:1071` ("ticks at TICK_HZ") failed 5 of 8 runs. **Control at the merge base
`efe88ab2`, same scope, clean tree: it fails there too, and worse — 9.72 Hz against this branch's
10.91-11.57** (`337c-control-base.txt` against `337c-harness-5.txt` / `-6.txt`). Pre-existing, and
named in the dispatch's list. **The cause was then measured, and it is not the code**: the case
reads the Studio client's own tick rate, and the second Studio window — the Forest Test, now
holding 12,672 more parts after the plant — was taking the frames. Minimised, the same commit
reads 16.6 Hz and the run is `PASS 34/34`. `weapon_shot.spec:1490`, `:1890`, `:2077` and
`weapon_client.spec:1773` (the dispatch list says `:1769`; same case, lines drifted) each fired
once or twice, all named in that list.
