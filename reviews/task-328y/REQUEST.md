# Task 328y -- paint the floor of the new cells (A2, C2, D2)

Task: 328y
Round: 1
Base: main 4757a7a6 (#330, task 328x merged)
Code commit: 9fa3f0efe2258bb71bd422d4733658e91fcb9988

`[harness] PASS: 34/34 checks @ 9fa3f0efe2258bb71bd422d4733658e91fcb9988 (clean tree) scope=all`
`test2`: N/A -- no `TWO_PLAYER_PATHS` path is touched (a `Relief` data table and its spec).

## What changed

Three data lines in `Relief.LANDFORMS`: A2, C2 and D2's `floor.default` go `Ground` -> `LeafyGrass`,
which is C1's rule borrowed whole (328e). One new case in `tests/server/grid_relief.spec.luau`. No
other file. The ground was then repainted by the existing bake, from 328k's virgin base.

## Claims

1. **A2, C2 and D2 take C1's floor and nothing else.** `Relief.LANDFORMS.{A2,C2,D2}.floor` is
   `{ default = "LeafyGrass" }` -- no `mudDepthStuds`, no `screeDegFrom`. *Verify:* read the three
   rows in `src/shared/Grid/Relief.luau`; the only SWARM 2.2 floors left are A1, B1, B2, D1.
2. **No borrowed arm can fire on their geometry (the brief's "invent nothing" risk).** C1's rule has
   no Mud or Rock arm at all, so there is no condition whose trigger could differ on A2/C2/D2's
   slope or depth. *Verify:* the new case `328y gives A2, C2 and D2 C1's litter floor...` asserts
   `materialAt` answers `LeafyGrass` at slope 0/35/89 deg and depth 0/40/400 st for all three.
3. **The change is MATERIAL only by construction.** `TerrainBake.shapeInputFor` hashes `baseKeep`
   and `ops` and NOT `floor`, so every `TerrainShape_<id>` is unmoved and no cell is re-shaped;
   `Relief.epochInput` hashes the whole landform, so `TerrainEpoch` does move. *Verify:* the two
   functions, plus the new case's `never.to.equal` pair.
4. **MEASURED in Karen's place, 1,645 lattice samples a cell** (`<runs-dir>/328y-census-before.txt`
   -> `-after.txt`, same probe `328y-census.luau`): A2 `Ground` 1,537 -> 15 and `LeafyGrass`
   0 -> 1,522; C2 1,539 -> 15 / 0 -> 1,524; D2 1,545 -> 1 / 0 -> 1,544. C1 1,533 `LeafyGrass`
   before AND after, B1 / D1 / B2 identical too.
5. **NOT ONE HEIGHT MOVED.** `terrainbake.py snapshot` of the seven run cells before and after is
   the same file: sha `6ee9e1b4792642d4d72e19d13f23c541e0e32db1b6b67d84823a1019674379b2` both
   times, `cmp` identical, **0 of 95,319 interior columns changed in each of the eight cells**.
   *Verify:* `328y-before.bin{,.sha256}` / `328y-after.bin{,.sha256}` in `<runs-dir>`.
6. **Attribute diff is exactly one line:** `TerrainEpoch` `5e09ea024be987ee` -> `58575af518ae6156`.
   The five `TerrainShape_*` stamps and Karen's 15 flag overrides are byte-identical.
   *Verify:* `328y-attrs-before.txt` vs `328y-attrs-after.txt`.
7. **The bake path is the smallest that exists, and it is 328x's own run.** There is no
   material-only pass (`shapeTile` writes height and material in one `WriteVoxels`), and naming
   fewer cells is not smaller but WRONG: `cellAt` would write C2's landform across C1's southern
   179 studs. Line: `[bake] OK: 1120/1120 tiles @ 9fa3f0ef... cells=B1,C1,D1,A2,B2,C2,D2 hold=B2,D2
   epoch=58575af518ae6156 worstTileMs=483 droppedLandform=0/0 tiles (clean tree)`, 14 m
   (`328y-bake.txt`). Backup `<backups-dir>/FT-before-328y.rbxl`, 28,982,292 B, `<roblox!`,
   sha `5a176732967ba145`, taken 18:18 UTC before any terrain write.
8. **F1, the dispatch's before/after pair, opened and MEASURED.** 328x's own F1 camera (a C1 stand,
   Play, enrolled hunter, camPos -3904.8/109.8/-5061, look -Z into C2). The far plain behind the
   line: mean RGB **100,104,101 -> 87,114,74**; the C1 ground at the camera's feet, the control,
   **170,168,158 -> 169,166,157**. *Verify:* `328y-F1-{before,after}.png` and the zoom pair
   `328y-F1-zoom-{before,after}.png` -- bare grey-brown plain and ridge before, green after, same
   trees, same animals, same horizon.
9. **F2, on C2's road, in Play.** Camera on EW2 at x -4100, eye 106, looking south-west into C2:
   bare dirt to the horizon before, green litter with scattered leaves after, same frame otherwise
   (`328y-F2-{before,after}.png`). The route needed an UNENROLLED player and that is measured: the
   drive re-pins an enrolled shooter to his stand **185 times in 40 s** (328x's `NOT HELD`), against
   **17** unenrolled, with the body at the target. Both frames are Play, not Edit.
10. **Four gate runs, all of them reported.** Run 1 FAIL 32/34 `boar_behaviour.spec:1553` (the
    dispatch's known list; a 10,000-step timing assertion). Run 2 FAIL 32/34 `map_ui.spec:632` and
    `:1210` -- NOT on that list, one cause: a replayed key toggled three times instead of twice,
    which also left the minimap off. Control at `main` `4757a7a6`:
    `[harness] PASS: 34/34 checks @ 4757a7a6d87bde6c0485aa5ea797ec39598e86fe (clean tree) scope=all`.
    Run 3 at the code commit: the PASS line at the top. Logs: `328y-gate1.txt`, `328y-gate2.txt`,
    `328y-control-main.txt`, `328y-gate3.txt`.

## What I could NOT verify

- **That it reads like C1 is a LOOK claim, not a census claim** (L-170): the percentages only say
  which classes the raycasts hit. The frames above are the evidence, and Karen's eye is the test.
- **A1** is painted by whichever neighbour `cellAt` picks, not by `A1.floor`, because A1 still
  cannot be baked (328x NOT MET item 2). Its census moved 575 -> 15 `Ground` for that reason.
- **No tree is planted by this task.** Karen's *"more trees behind the line"* is 328i's.

## Learning flags

ANSWERED: L-136 the one named flake that fired is named with its run. ANSWERED: L-127 MET / NOT
PROVEN per item in the report. ANSWERED: L-162 every live proof is at `9fa3f0ef`. ANSWERED: L-014
nothing was ever checked out in `driven-hunt-karen`; the FT is on :34873. ANSWERED: L-076 all four
frames are Play at a hunter's eye height. ANSWERED: L-101 the attribute diff is claim 6.
ANSWERED: L-093 deleting the producer (the three `LeafyGrass` lines) returns the census to `Ground`
-- the before file IS that state, measured at the parent commit. ANSWERED: L-098 claim 2.
ANSWERED: L-021 the first capture of the session was a throwaway (`328y-warmup-raw.png`).
