# Task 311 — a clean lobby: a level truck bay, a flagpole, a birch-lined road

Task: 311
Round: 1
Base: fb890d68
Code commit: c18e8264b309781607ffb029edcc8f47ca904c61

```
[harness] PASS: 34/34 checks @ c18e8264b309781607ffb029edcc8f47ca904c61 (clean tree) scope=all
```

Two players: **N/A**. `python tools/agents.py` → `needs_two_player` returns `[]` for this diff
(`src/server/Lobby/`, `src/shared/Lobby/`, `tests/server/lobby.spec.luau`, `docs/`): none of it is in
`TWO_PLAYER_PATHS`.

Karen, 2026-10-28: *"cars now some is on small mountain some of them fix those, lobby has to be clean
and nice / also you can add in middle somewhere flag long stick and flag like in hunting lobbies /
... forest road comming to lobby around ... bjorke tree from both sides with spaces"*.

Note: `docs/research/2026-10-29-lobby-flagpole-and-birch-avenue.md`. Evidence:
`<runs-dir>/evidence/p311-{before,after,after2,after3,pole,pole2,geom}.txt`, frames in
`<runs-dir>/f311/`.

## PLAN (core-quality step 0), for the mound

- **(a) REAL LIFE / the engine.** `Terrain:FillBlock` writes **4-stud voxels**
  ([docs](https://create.roblox.com/docs/reference/engine/classes/Terrain#FillBlock)); a box face
  inside a voxel writes it only partly. `Terrain:ReplaceMaterial` changes *"the material of a voxel
  and NOTHING ELSE"*.
- **(b) MEASURED NOW** (`p311-before.txt`, her place, Play, 49 terrain samples per footprint, cast
  from 14 studs above each truck's own lowest corner): Truck1 relief 0.00, **Truck2 1.27, Truck3
  1.27**, Truck4 bottom **151.27** against Truck1's **150.00**.
- **(c) TARGET.** Relief ≤ 0.25 studs per footprint and ≤ 0.25 between any two trucks' lowest
  corners — a quarter stud is 7 cm, under a tyre's own sag.
- **(d) LEVER.** `src/server/Lobby/Field.luau`, `Field.airBlock` (the only writer of the air box's
  bottom) and `Field.fill` (the only `FillBlock` caller in this system); then
  `src/server/Lobby/init.luau` `tryBuild`, the only writer of the lobby's anchor.
- **(e) MEASURED AFTER** by the same probe (`p311-after3.txt`, `p311-pole2.txt`).

## ITERATION (step 2) — four cycles, same probe each time

| cycle | the cut | relief | trucks' spread | surface | road slab |
|---|---|---|---|---|---|
| before | measured 149.248 | **1.27** | 1.36 | 150.00 | on it |
| 1 | voxel boundary below it (148) | 0.00 | 0.00 | 151.27 | **1.5 buried** |
| 2 | shelf snapped to 148 | 0.00 | 0.00 | 150.00 | **1.75 buried** |
| 3 | snapped **+ the seat re-read after the fill** | **0.00** | **0.00** | 150.00 | on it |
| 4 | avenue rows rebalanced | 0.00 | 0.00 | 150.00 | on it |

Cycle 1 flattened the yard and kept it flat in every cycle after. The next two cycles are about a
second fact the first measurement exposed: **the surface the engine draws is two studs above the top
of the fill**, so a part laid on the height we asked for is buried — task 180's invisible road.

## Claims

1. **The mound is gone and all four trucks stand at one height.** `p311-after3.txt`: relief **0.00**
   on all four 49-sample footprints, every truck's lowest corner **150.00**. Before: 1.27 / 1.27 /
   0.16 / 0.00 and a 1.27 spread (`p311-before.txt`). *Verify:* the two files, same probe
   (`<runs-dir>/p311-before.luau`, unchanged between runs).
2. **The cut is on the voxel grid and nothing is laid on a predicted height.** `Field.shelfFor`
   snaps it; `Field.cutBottomY` puts the air box's bottom on a boundary; `Lobby.tryBuild` then calls
   `world.groundAt` **again** after `Field.fill` and makes that answer the anchor. *Verify:*
   `tryBuild` in `src/server/Lobby/init.luau` (the `cut` / `produced` block) and the three new `it`s
   in `lobby.spec`'s *"the field, cut and filled"*.
3. **The fill order changed and that is half the fix.** `Field.fill` is now air → grass → pad: the
   air box reaches *below* the shelf, so running it last would cut a hole in the grass. *Verify:*
   `Field.fill`, and `lobby.spec` *"cuts AIR first and then fills"* — which asserts the order on a
   recording fake, and *"fills air BEFORE grass"*, which fails if any air call follows a fill.
4. **Nothing in the lobby floats and nothing new is buried.** `p311-pole2.txt`, the ground-standing
   census against the *highest* terrain under each footprint: trucks **+0.00** ×4, pads **−0.62**
   ×4 (identical — before, Pad4 sat on the mound at 150.4..151.2 while 1–3 were at 149.4..150.2),
   lane / yard / log pile / fence posts / spawn **−0.75**, flagpole kerb and mast **+0.00**. Worst
   float over every ground-standing item: **+0.00**. *Verify:* `p311-pole2.txt` against
   `p311-before.txt`'s census.
5. **The flagpole is the size the sources give.** Mast 35.70 studs (10 m at 0.28), finial on top at
   185.70–186.50, flag **8.57 × 5.36** (240 × 150 cm) hoisted with its top 1 stud under the finial,
   hoist edge touching the mast. *Verify:* `p311-pole2.txt`'s POLE lines; `lobby.spec` *"is a
   ten-metre pole carrying the flag the sources pair with it"* and *"builds the pole on the ground
   it is given"*; note section 3.2 for the two Swedish guides and the US bracket.
6. **The flagpole is clear of everything it must be.** Built at (2906, −2915) on the yard gravel.
   *Verify:* `lobby.spec` *"stands on the yard's gravel, clear of the pads, the bays, the lodge and
   the spawn"* — `yardRect`, `onWorkingGround`, `offRoad`, all four `Pads.centreFor`,
   `lodgeKeepOut`, the spawn pad — and *"keeps the pole and every avenue trunk away from the
   range"*, which reads `Range.ANCHORS["forest-test"]` = **(2650, −3216)**, not the (2600, −3030) an
   older draft quoted (L-151).
7. **The avenue lines both sides with spaces, and stops before the yard.** Six birches stand:
   west (2845,−3047) (2846,−3024) (2847,−2997) (2847,−2948), east (2895,−3015) (2894,−2997); every
   trunk 23.1–24.9 studs off the lane's centre. *Verify:* `p311-pole2.txt`'s AVENUE lines;
   `lobby.spec` *"is an avenue: two rows, at least five trees, a gap, and 7 m in the row"* and
   *"stands every avenue trunk off the road and stops before the yard"*.
8. **A slot the forest ring fouls moves or is dropped, and it is counted.** `TREELINE` is a jittered
   ring that crosses this road, so the table cannot be hand-tuned against it. `Avenue06` was dropped
   (a ring trunk 3.6 studs away; three 8-stud steps north still fouled) and `Avenue07` was shifted
   from z −3023 to −3015. *Verify:* `avenue()` in `Build.luau`, `stats.avenueShifted` /
   `avenueDropped`, and `lobby.spec` *"plants the avenue when there are templates, and nothing when
   there are none"*, which asserts `avenueTrees + avenueDropped == #SLOTS - avenueGaps`.
9. **Frames, looked at, from the player's eye** (camera y 155–156, ground 150). `f311/311-road.png`:
   standing on the road 100 studs south of the lodge — white birch trunks down **both** sides with
   gaps between them, the fence either side, the road running to the lodge, the flag with its cross
   visible above the trees (`f311/311-flag-zoom.png`, 5× — the cross reads; backlit through foliage
   the green field reads near-black). `f311/311-pole.png`: the mast standing on the gravel beside
   Truck 1, all four of its wheels down, the green pad flush. `f311/311-yard.png`: the yard flat,
   two pads lying flush, the mast, a truck, the lodge. `f311/311-flag.png`: the gravel flat up to
   the lodge's stone plinth.
10. **No owner moved.** `Lobby.Field` is still the only thing that touches `Terrain` here and still
    takes it as an argument; `Lobby.Build` still draws every part. `Field.insideField` still bounds
    every block, and the air box grew **downwards** — `lobby.spec` asserts its top is still
    `shelf + CLEAR_STUDS`.

## What I could not verify

- **`Lobby.stats()` could not be read live.** `execute_luau` gets its own module cache, so a probe's
  `require` returns a fresh `Lobby` whose counters are 0/nil (`p311-pole2.txt`, line 1). Every number
  above is therefore an **instance** fact measured in the world, and the counters are asserted in
  `lobby.spec` instead.
- **The avenue's drop count is this boot's dice.** The ring is random per build, so "six trees"
  is what this world gave; the spec asserts the invariant (planted + dropped = slots − gaps), not the six.
- **No terrain was saved into Karen's place, and none needs to be.** The fill is a runtime write by
  the owner that already exists; a hand-saved shelf would be a second writer of the same ground
  (note section 3.1). There is no `NEEDS-DIRECTOR`.
- The **road slabs sit 0.75 studs into the terrain** and the pads 0.62. That is unchanged from before
  this task (`p311-before.txt`: pads −0.62) and is how they are bedded; I did not touch it.
