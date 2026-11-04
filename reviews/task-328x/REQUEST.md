# Task 328x -- bake the five edge cells

Task: 328x
Round: 2
Base: main `3d39646` (328h #329 merged: row 1 B1, C1, D1 baked)
Code commit: `a2d647fef0611fd43261039975e6e6176a3a6f8a`

```
[harness] PASS: 34/34 checks @ a2d647fef0611fd43261039975e6e6176a3a6f8a (clean tree) scope=all
```
`test2` N/A: no `TWO_PLAYER_PATHS` path is touched (`src/shared/Grid/`, `src/serverstorage/TerrainBake/`,
`tests/server/grid_relief.spec.luau`, `tools/terrainbake.py`).

**What changed.** An ABSENT column -- one the base cannot answer, beyond the edge of the world -- is
DROPPED from the slope limiter's window instead of pinned at `snapshot.minY`, and is written as AIR
instead of a stub at the band floor. The hole refusal narrows to a hole with real ground on both
sides inside the rectangle. Two things the bake could not run without came with it: the bench band
is clipped where it leaves the base file (checked by `voidMargin`, not asserted), and `base_slice`'s
per-column `set(holes)` rebuild is bound once. `--hold-landform` holds B2's and D2's landform back.

**THE BAKE RAN AT `820484a6`, AND `git diff 820484a6..HEAD --name-only` IS
`tests/server/grid_relief.spec.luau` ALONE**, so the ground in Karen's place is byte-for-byte what
this code commit produces. Three bakes were run in all and the last two are at round 2's code: the
row-1 snapshot came back with the same sha256 `8541621a62c9` all three times.

**ROUND 2 ANSWERS BOTH ROUND-1 FINDINGS, AND I AGREE WITH BOTH.** Finding 1 was a real silent drop:
the refusal's window is the tile but `Relief.blurredGrid` answers nil for any point whose 72-stud
support holds a void, so a real column near one keeps the RAW base and the landform's whole
`(1 - baseKeep) * (blur - base) + roadFade * delta` term is lost. Finding 2 was right about
`BAKE_VERSION`. Claims 11 and 12 below are the two answers; claims 1-10 are unchanged.

## Claims

1. **An absent column is no constraint, and pinning it drags the ground.** `grid_relief` **328x-1**
   drives both arms over one column by parameter: dropped leaves samples 1-5 at exactly 200, pinned
   pulls sample 2 to 5.82. Delete the `gone(i) or gone(j)` guard in `Relief.limitPass` and arm 1
   becomes arm 2 and the case fails. **328x-2** does the same on a 2-D grid through
   `TerrainBake.limitGrid`, so the mask is proved to ride BOTH axes (the 328d lesson).

2. **The narrowed refusal, both arms.** **328x-3** over a synthetic slice: a pond at the centre
   counts 1; three whole westernmost column LINES count 0; a notch beside that void strip counts 1
   -- caught on the z axis, which is why both axes are tested. **328k-6 (c)/(d)** drive it through
   `bakeTileAt`: an enclosed hole at the tile's CENTRE still refuses, a hole in the pad no longer
   does and the tile goes on to the profiles check.

3. **103 -> 0, and the instrument is the same one 328h used.** Over 328h's virgin base, with this
   file's own `region_for`/`tile_count`/`base_slice`, the OLD rule reproduces 328h's committed table
   exactly -- A1 34, A2 46, B2 14, C2 15, D2 23, 103 of 1,120, 30 with a hole inside the tile -- and
   the narrowed rule refuses **none**. Verify: `ESCALATE.md` 2026-11-04 ~14:40 carries both columns.

4. **Nothing in the footprint is void.** 0 holes in all 838,881 columns of `Grid.footprint` and 0 in
   every one of the eight cell interiors, so no road, pad or stand is ever over the void. Ground
   runs x[-7000,-1576] z[-7000,-2980]; the live probe says `x -7010 = VOID`, `x -6990 = ground`.

5. **The bake.** `[bake] OK: 1120/1120 tiles @ 1cdc894d cells=B1,C1,D1,A2,B2,C2,D2 hold=B2,D2
   epoch=5e09ea024be987ee worstTileMs=477 (clean tree)`, 15 m 08 s, backup
   `<backups-dir>/FT-before-328x.rbxl` 29,224,982 bytes `<roblox!` sha `f4a2fd77c31615ac` taken
   before any write, Karen's 15 overrides declared with `--keep-flags` and never cleared (rule K).

6. **Row 1 did not move at all.** B1/C1/D1 snapshotted before and after
   (`328x-row1-before.bin` sha `0317b4a77148`, `-after2.bin` sha `8541621a62c9`): **0 of each
   cell's 95,944 interior columns changed**. The survey reproduces 328h to the hundredth: B1
   66.05/189.54/123.50/81.29, C1 89.14/150.26/61.12/106.03, D1 101.83/166.26/64.43/135.85.

7. **The world's edge is not a cliff, and it is a number before it is a picture.** Baked against the
   virgin base at the edge columns (x -6990..-6900, three z): **+1.24 to +2.37 st**, the limiter's
   own easing. Under the old pin those columns would have been dragged toward `minY` **39.56**.
   `328x-F2-edit` (A2#8, eye 84.4, looking west) shows the ground ending at a level lip, sky behind.

8. **Pads, junctions, ditch, stands.** 120 of 120 stands have ground under them, 0 missed; pad
   spread **0.00** for all 105 stands of the seven run cells -- the only non-zero spread in the
   world is A1's, up to 1.49 st, and A1 is the cell that could not be baked. 15 junctions, pin
   0.0000 every one, worst voxel step 2.4728 against its own explained 2.4419 (**0.031 st over**, at
   EW1 x NS2; EW3 x NS1 is over by 0.031 too). Ditch 1.52-2.37 st at d +-24..26 over 20 stations,
   every centreline `Ground`.

9. **The hold is a measurement, not a preference.** **328x-6** shows that leaving B2 out of
   `cellIds` does NOT leave its ground alone: `cellAt` answers a neighbour and `blendAt(unionOf)` is
   **1** at B2's centre, so a foreign landform would be written across it at full strength. Held, it
   is its own cell, keeps the base, asks for no bench band, and its report says HELD BACK. The
   attribute readback proves the other half: Terrain carries `TerrainEpoch` + `TerrainShape_` for
   **A2, B1, C1, C2, D1 only** -- B2 and D2 are not stamped.

10. **The bench is why, and it is measured.** The seven-cell run stops dead at tile 51 -- the first
    tile whose window reaches B2 -- with `Target is not reachable`, twice, at the same tile. ~1.5e8
    base reads a tile (328h's figure), ~360 of 1,120 tiles carry bench weight. `ESCALATE.md`
    ~16:20 carries the arithmetic and the fix I would take, including why a naive per-x cache does
    not work under the bend.

11. **THE SILENT DROP IS A READING NOW, AND ON KAREN'S GROUND IT IS ZERO** (finding 1).
    `shapeTile` returns the count of columns where `Relief.heightAt` answered nil;
    `TileReport.droppedLandform` carries it; `tools/terrainbake.py` prints
    `droppedLandform=N/M tiles` on the `[bake]` line **whatever N is**, so 0 is measured and never
    assumed. The whole run reads **`droppedLandform=0/0 tiles` over all 1,120 tiles** -- which the
    geometry predicts and now does not have to: `blendAt` is 0 beyond 200 studs of the union's box,
    whose west edge is ~-6903, and the nearest void column is at -7000, a 97-stud gap against the
    blur's 72. **`grid_relief` 328x-7 proves the defect is real anyway**, so the 0 is a fact about
    this world and not about the code: a void strip in a real C1 tile's PAD (`holesInTile` 0, so
    the tile is NOT refused) loses the landform on **1,728 shaping columns** -- 18 a row, exactly
    the blur's reach -- and the tile's own westernmost column comes out **106.4708 against the
    clean run's 106.7123**. Two ways that case was wrong before it bit, both in the log: its strip
    first stopped at exactly 72 studs, where `heightAt`'s grid-space fallback still finds ground
    across the bend's shear; and its synthetic base was a PLANE, whose blur is itself, so losing
    the blur changed nothing.

12. **`BAKE_VERSION` STAYS 1 AND THE REASON IS AT THE CONSTANT** (finding 2). Both new arms --
    `limitPass`' `absent` and the Y band over the columns that have ground -- are reached ONLY by a
    column the base cannot answer, and no stamped ground can hold one: `bakeTileAt` refused every
    such tile outright before this task. The evidence is direct: B1, C1 and D1 were re-baked by
    THIS code over ground the OLD code wrote and all **3 x 95,944 interior columns came back
    byte-identical**. A bump would re-stamp every cell to say the ground changed when it is the same
    ground to the bit. Verify at `Relief.BAKE_VERSION`, which now carries that paragraph.

## What I could NOT verify, said plainly

* **A1 IS NOT BAKED.** Eight cells take `regionFor`'s ALL branch, whose lattice starts at x -7296, so
  a tile's own slice needs x >= -7500 against a base file that starts at -7336. 164 studs short, and
  A1 cannot be baked alone afterwards without writing a foreign landform into A2 and B1.
* **B2's THREE RAMPS AND THE B2 BOT CLIMB ARE NOT MET.** `328x-F3-edit` is the proof that the ramp is
  not there: smooth held ground, no scarp. No bench cell has written a voxel yet; the RULE is proved
  by cases, the GROUND is not.
* **KAREN'S SENTENCE IS HALF ANSWERED.** C2 has GROUND now (`328x-F1` before/after is a real
  difference, same camera) but no trees -- the forest is 328i.
* **A2, C2 and D2 read 121/121 `Ground` where C1 reads 121/121 `LeafyGrass`.** That is
  `Relief.materialAt`'s documented placeholder for the four cells SWARM 2.2 gives no floor (task
  328f), seen on the ground for the first time. D2's half of it is mine: a HELD cell keeps its
  heights but the material pass runs regardless of `reshape`. Both queued in `TASKS.md` (m), (n).
* **F2 AND F3 ARE EDIT CAMERAS**, at the stand's own eye height, because the drive pins an enrolled
  shooter to its stand (`NOT HELD, best 2949.76 st`). F1 is in Play at the player's own eye height.
* **The closest cross-cell stand pair at distinct points is 210.28 st, under the 330-st slug range.**
  They are neighbours ON the same line facing the same way, not across it, and both are row-1 stands
  on byte-identical ground -- so it is not a change this task made, and I have not measured the
  across-the-line statistic the dispatch's ">= 330" probably means.
* **THE GATE WAS NOT GREEN FIRST TIME AND THE RUNS ARE NAMED.** At this code commit: run 1
  30/34 with `deer_hitbox.spec:659`, `weapon_shot.spec:1490` and `semiauto_client.spec:93` -- all
  three on the dispatch's known-flake list; run 2 32/34 with `deer_hitbox.spec:682`, also named;
  run 3 32/34 with **`boar_behaviour.spec:1553`, which is NOT on the list**, so a control run was
  made at the merge-base and passed -- `[harness] PASS: 34/34 checks @
  cbeb3f788febd1f9dd267527a5b9f81086963efa (clean tree) scope=all` -- and this diff touches no boar
  file; run 4 is the PASS line at the top. Four runs, one control.
* **ROUND 1's NOTES ARE NOT ALL CLOSED.** The clipped-band acceptance branch still has no case of
  its own (328h note (g)'s class), `relief_golden.luau` still has no holey-base sample, and the
  `[bake]` line's format has drifted from design section 5 by `hold=` and now `droppedLandform=`.
  Queued, not fixed in this round.
