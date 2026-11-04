# Task 328y -- paint the floor of the new cells (A2, C2, D2)

Task: 328y
Round: 2
Base: main 4757a7a6 (#330, task 328x merged)
Code commit: b876e5b3268dc6c3ea5ae66811d5538a283dfb21

`[harness] PASS: 34/34 checks @ b876e5b3268dc6c3ea5ae66811d5538a283dfb21 (clean tree) scope=all`
`test2`: N/A -- no `TWO_PLAYER_PATHS` path is touched (a `Relief` data table and its spec).

## What changed

Three data lines in `Relief.LANDFORMS`: A2, C2 and D2's `floor.default` go `Ground` -> `LeafyGrass`,
C1's rule (328e) borrowed whole. One new case in `tests/server/grid_relief.spec.luau`. No other
file. The ground was then repainted by the existing bake, from 328k's virgin base.

## Round 1's finding, and what it changed

Finding 1 was right: the stamp half of the case compared `epochInput` with and without the floor
key, which passes whether or not `shapeInputFor` hashes the floor -- the one failure its title
names. It now asks the function the stamp is written from: for each of A2/C2/D2,
`string.find(TerrainBake.shapeInputFor(id), "floor", 1, true)` is nil, the same landform with
`floor = { default = "Rock" }` encodes differently, the attribute `stampShape` wrote equals
`shapeInputFor(id)`, and `reshapeWanted(id, mark)` answers `false` / `"stamped"`. Round 1's note on
"no cell is re-shaped" is also corrected, in the comment and in the TASKS row: every non-held cell
IS re-shaped on every re-bake (328r); the heights hold because the base is the virgin `.bin` and the
write is absolute.

## Claims

1. **A2, C2 and D2 take C1's floor and nothing else.** `floor = { default = "LeafyGrass" }` -- no
   `mudDepthStuds`, no `screeDegFrom`. *Verify:* the three rows in `src/shared/Grid/Relief.luau`.
2. **No borrowed arm can fire on their geometry** (the brief's "invent nothing" risk): C1's rule has
   no Mud or Rock arm at all. *Verify:* the new case asserts `materialAt` answers `LeafyGrass` at
   slope 0/35/89 deg and depth 0/40/400 st for all three.
3. **A repaint cannot be read as a shape change.** *Verify:* the four assertions listed above, which
   go through `TerrainBake.shapeInputFor` / `stampShape` / `reshapeWanted`. Their BITE is argued by
   reading, not by a run: a `shapeInputFor` that hashed the floor fails the `string.find` line, as
   328e-6's identical line for C1 already pins. The `floor.default` and `materialAt` lines die with
   the producer directly -- the before census below IS the parent commit's state.
4. **MEASURED in Karen's place, 1,645 lattice samples a cell** (same probe `328y-census.luau`,
   before -> after): A2 `Ground` 1,537 -> 15 and `LeafyGrass` 0 -> 1,522; C2 1,539 -> 15 /
   0 -> 1,524; D2 1,545 -> 1 / 0 -> 1,544. C1 1,533 `LeafyGrass` before AND after; B1, D1, B2
   identical too. *Verify:* `<runs-dir>/328y-census-before.txt`, `-after.txt`.
5. **NOT ONE HEIGHT MOVED.** `terrainbake.py snapshot` of the seven run cells before and after is
   the same file -- sha `6ee9e1b4792642d4d72e19d13f23c541e0e32db1b6b67d84823a1019674379b2` both
   times, `cmp` identical, **0 columns changed in each of the eight cells**. The per-cell figure is
   **95,319**, not 328h/328x's 95,944, and the reason is the lattice phase, not the region: the
   snapshot's lattice starts at x -7192 / z -7092, 2 studs off a cell corner, so a 1070 x 1430
   interior holds 267 x 357 of its 4-stud columns against the bake grid's 268 x 358. Same interior.
   *Verify:* `328y-before.bin{,.sha256}` / `328y-after.bin{,.sha256}`.
6. **Attribute diff is exactly one line:** `TerrainEpoch` `5e09ea024be987ee` -> `58575af518ae6156`;
   the five `TerrainShape_*` stamps and Karen's 15 flag overrides byte-identical.
   *Verify:* `328y-attrs-before.txt` vs `328y-attrs-after.txt`.
7. **The bake path is the smallest that exists, said plainly.** There is no material-only pass
   (`shapeTile` writes height and material in one `WriteVoxels`), and naming fewer cells is not
   smaller but wrong: `cellAt` would write C2's landform across C1's southern 179 studs (the
   `--hold-landform` help says so). So the run is 328x's own:
   `[bake] OK: 1120/1120 tiles @ 9fa3f0ef... cells=B1,C1,D1,A2,B2,C2,D2 hold=B2,D2
   epoch=58575af518ae6156 worstTileMs=483 droppedLandform=0/0 tiles (clean tree)`, 14 m, from
   `terrain-base-010b6400abdd.bin` (`328y-bake.txt`). It ran at `9fa3f0ef`, whose `Relief` is
   byte-identical to this code commit's -- round 2 changed only the spec and the row. Backup
   `<backups-dir>/FT-before-328y.rbxl`, 28,982,292 B, `<roblox!`, sha `5a176732967ba145`, 18:18 UTC,
   before any terrain write.
8. **F1, the dispatch's before/after pair, opened and MEASURED.** 328x's own F1 camera (a C1 stand,
   Play, enrolled hunter, camPos -3904.8/109.8/-5061, look -Z into C2). Far plain behind the line:
   mean RGB **100,104,101 -> 87,114,74**. The C1 ground at the camera's feet, the control:
   **170,168,158 -> 169,166,157**. *Verify:* `328y-F1-{before,after}.png`, zooms
   `328y-F1-zoom-{before,after}.png` -- grey-brown plain and ridge before, green after, same trees,
   same animals, same horizon.
9. **F2, on C2's road, in Play.** EW2 at x -4100, eye 106, looking south-west into C2: bare dirt to
   the horizon before, green litter with scattered leaves after (`328y-F2-{before,after}.png`). The
   route needed an UNENROLLED player, measured: the drive re-pins an enrolled shooter **185 times in
   40 s** (328x's `NOT HELD`) against **17** unenrolled, body at the target. Both frames are Play.
10. **Five gate runs, all reported.** Run 1 FAIL 32/34 `boar_behaviour.spec:1553` (the dispatch's
    known list; a 10,000-step timing assertion). Run 2 FAIL 32/34 `map_ui.spec:632` and `:1210` --
    NOT on that list, one cause: a replayed key toggled three times instead of twice, which also
    left the minimap off. Control at `main`:
    `[harness] PASS: 34/34 checks @ 4757a7a6d87bde6c0485aa5ea797ec39598e86fe (clean tree) scope=all`.
    Run 3 at `9fa3f0ef` PASS 34/34; run 4 at this code commit, the line at the top, with the new
    case's note `A2/C2/D2 floor LeafyGrass/LeafyGrass/LeafyGrass`. Logs `328y-gate1..4.txt`,
    `328y-control-main.txt`.

## What I could NOT verify

- **"Reads like C1" is a LOOK claim, not a census claim** (L-170): the percentages only say which
  classes the raycasts hit. The frames are the evidence and Karen's eye is the test.
- **A1** is painted by whichever neighbour `cellAt` picks, not by `A1.floor`, because A1 still
  cannot be baked (328x NOT MET item 2). Its census moved 575 -> 15 `Ground` for that reason.
- **No tree is planted here.** Karen's *"more trees behind the line"* is 328i's.
- **D2 is held**, so it now carries finished litter over unshaped ground; when D2 is shaped, ground
  moves under paint Karen has seen. Queued in the row beside 328x notes (n)/(y).

## Learning flags

ANSWERED: L-136 the one named flake that fired is named with its run. ANSWERED: L-127 MET / NOT
PROVEN per item in the report. ANSWERED: L-162 every live proof is at `9fa3f0ef`, whose `Relief` is
this commit's. ANSWERED: L-014 nothing was checked out in `driven-hunt-karen`; the FT is on :34873.
ANSWERED: L-076 all four frames are Play at a hunter's eye height. ANSWERED: L-101 the attribute
diff is claim 6. ANSWERED: L-093 deleting the producer returns the census to `Ground` -- the before
file IS that state at the parent commit. ANSWERED: L-098 claim 2. ANSWERED: L-021 the session's
first capture was a throwaway (`328y-warmup-raw.png`).
