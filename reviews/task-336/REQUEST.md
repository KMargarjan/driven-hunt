# Task 336 — every cell its own forest, wall to wall, stored; only the active cell stands

Task: 336
Round: 1
Base: 6d4ed31b (main)
Code commit: 257df0b7eae94797d22467d723a44e4b168d5cf2

```
[harness] PASS: 34/34 checks @ 257df0b7eae94797d22467d723a44e4b168d5cf2 (clean tree) scope=all
```
Two players: N/A — no `TWO_PLAYER_PATHS` path is touched (`src/shared/Places/`, `src/shared/Grid/`,
two server specs).

Karen, 2026-11-08: *"can you make now all grounds with different trees"*, then *"so we will need to
optimize, we only load one per game thats it"*. The Director assigned the species; Karen delegated it.

**What changed.** `Places.CELL_MIXES` gains two rows per cell (`*All` = the wood, in `FERN_MIXES`;
`*Under` = thicket, scrub and second storey, not in it; `larchAll` is deliberately out of
`FERN_MIXES` — that table's own rule is "not in a larch plantation"). Six recipes are rewritten to
draw nothing else and renamed after what they now grow: `spruceRidge` (B1), `oakRolling` (D1,
unchanged name), `aspenRolling` (A2), `larchSlope` (B2), `spruceBirchRolling` (C2),
`oakAspenRolling` (D2). Each cell's `frontage.groups` is now its OWN species. Every clearing in a
planted cell is planted. B2 and D2 join `Grid.PLANTED_CELLS` and borrow C1's skirt (24/52) and gap
(B2 takes 9 — a larch plantation is planted at 2.0–2.5 m, and 9 studs is ~2.5 m).
**C1 is byte-identical**: `git diff 6d4ed31b 257df0b7 -- src/shared/Places/init.luau` touches no line
of `mixedRolling`, and its live wood still measures 2,476 models / 9,318 parts / 2,387 birch.

Instruments, both sides the same: `<runs-dir>/336-survey.luau` (the plan AND the live wood, with
335's exact 20-stud / 25-stud lattice and 335's exact exempt set) through `<runs-dir>/336probe.py`.

## Claims

1. **Each planted cell is its own species, and C1 is still birch alone.** Own wood (`side > 0`),
   live in her FT: C1 birch 2,387 · B1 conifer 2,424 · D1 oak 2,276 · A2 aspen 2,417 ·
   B2 young 1,953 · C2 conifer 1,246 + birch 1,188 · D2 fieldOak 838 + aspen 1,186. The other
   names in B1's and A2's live tally (57 and 124) are their SKIRT into bare A1, which draws A1's
   front mix by design. *Verify:* `grid.spec` "gives each planted cell its own species, and C1
   nothing but birch" — revert any recipe and it fails (B1 came back with 735 birch and 721 larch).
2. **Wall to wall.** Open share = lattice points with no trunk within 25 studs. Live, after:
   over points where ANY of that cell's own species may stand: C1 0.59 % · B1 0.79 % · D1 0.26 % ·
   A2 0.84 % · C2 0.21 % — all inside the 3 % bound; **B2 8.04 % and D2 3.27 % are NOT MET**
   (claim 4). On 335's geometry-only exempt set the same runs read 2.45 / 1.31 / 25.29 / 1.07 /
   0.93 / 13.68 / 3.86 %, and the excess over the first number is named per cell: D1's 854 points
   are its MEADOW (`field`, a design feature this task did not touch), B2's 221 are the stands'
   managed band (mask rule 11: no young growth in front of a hunter — the whole cell is young).
   *Before:* only C1 had any wood at all; the other six cells were empty ground (`336-world.luau`,
   `<runs-dir>/336-before.txt`). *Verify:* `336-survey.luau` on any cell.
3. **Only the active cell stands.** In a Play server of her FT: the boot stood C1 and stored SIX
   (`[Places.Cells] want=C1 stood=C1 (2476 models) stored=6 cell(s)/14342 models moved=6 in 950 ms`;
   `[ForestTestBoot] prebuilt forest: STANDS ... 16818 model(s) in 7 cell folder(s)`). Forced to B1:
   **390 ms**, Workspace holds exactly B1 (2,569 models / 8,997 parts), six in GridWood (46,257
   parts). Forced again to D2: **382 ms**, Workspace holds exactly D2 (2,180 / 7,066), six stored
   (48,188 parts). Workspace parts 31,806 → 31,614 → 29,695. *Verify:* `<runs-dir>/336-swap.luau`,
   which REQUIRES `ServerScriptService.Places.Cells` — the module the boot calls — and is not a copy.
4. **B2 and D2 are planted, and their ground is why they miss the bound.** `terrainbake.py plant`
   rays every site: B1 43 cliff, D1 22, A2 9, C2 66 — but **B2 529 of 2,482 (21 %)** and
   **D2 444 of 2,624 (17 %)**, which is the held landform (328x `--hold-landform`) the dispatch
   asked about. 1,953 and 2,180 trees stood. Not reshaped: the dispatch forbids it.
5. **The budget holds.** Every planted cell is under `CELL_PART_CAP` 2,640 planned models
   (2,482–2,637) and `CELL_PLAN_CAP` 7,260 capacity (4,246–5,891). Live parts per cell 5,859–9,318.
   *Verify:* `grid.spec` "the budget", unchanged.
6. **The density is C1's own, not a thinner borrowed one.** Own planned trees 2,276–2,482 against
   C1's 2,418 — 94–103 %. *Verify:* `grid.spec` "plants every cell at C1's accepted density" —
   the standard goes back to 2,418 (328i's 1,861 was C1's count before 335 raised it).
7. **Frame time does not pay for it.** Same Play session, 10 s each: C1 stand 8 mean 22.20 ms /
   p95 27.73 (335 read 21.10 / 27.78 at that station), B1 stand 8 mean **21.46 / 26.47** — a new
   cell is no dearer than the accepted one, because conifer is 2–3 parts a model against birch's 3.8.
8. **Her place is as she left it.** Flag attribute diff before/after the plant is EMPTY
   (`336-attrs-BEFORE.txt` / `336-attrs-AFTER.txt`, 15 overrides declared with `--keep-flags`, never
   cleared). Nothing was saved, published or committed in her FT; the Play session's GridWood is gone
   (`ServerStorage store: []` in Edit afterwards). Backup `<runs-dir>/FT-before-336.rbxl`,
   29,706,183 bytes, 22:36 UTC. `smoke.sh`: **SMOKE PASS** — gun in hand, stacks=0, errorLines=0,
   waves=10.
9. **Frames, opened and described.** `336-FB1` spruce wall to wall inside its four roads, A1 beside
   it bare but for B1's skirt · `336-FD1` a dark oak wood with the meadow and its pond still open ·
   `336-FB2` visibly thinner than A2 and C2, with a bare steep spine in the middle (the 529 cliffs) ·
   `336-FC2` dense, two-tone, road to road · `336-FD2` even, with thin patches on the broken ground ·
   `336-FA2` planted edge to edge, the plantation rows readable from above · `336-FC1` unchanged,
   its V ride, X cut and two L rides the only bare ground inside · `336-G` all eight cells, seven
   wooded in visibly different textures and A1 empty.
10. **Five existing cases moved and say why.** The clearing pair, the understorey's species, the
    skirt's bare neighbour and `grid_ground`'s clearing case are re-aimed at **A1** — the one cell
    that is not planted; `grid_ground`'s frontage case now asks the frontage of the cell a tree
    STANDS IN, because a `side < 0` skirt draws the neighbour's mix (36 of B1's and 18 of A2's).

## Not verified
- **Karen has not seen it.** Nobody has played a drive in a new cell.
- **B2 8.04 % and D2 3.27 % open are NOT MET** and the cause is the ground, not the planting (claim 4).
- D1's meadow (854 points, 22 % of its lattice) is left open deliberately; whether Karen wants trees
  on it is hers, and it is in the report for the Director.
