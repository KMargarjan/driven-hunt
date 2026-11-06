# Task 330 -- the bench anchor cache, and the proof that says it changes an answer

Task: 330
Round: 1
Base: db7cd633
Code commit: 2b0bc348

**READ THIS FIRST.** The dispatch's step 1 was the Director's bench-anchor cache plus an equality
proof, with a pre-decided answer if the proof failed: *"If they differ by one column, STOP and write
`ESCALATE.md`. Do not tune it."* **They differ.** So steps 2-5 (the backup, the bake of B2 and D2,
the planting, the re-plant, the frames) were never started, and this branch deliberately ships the
cache **switched off**: a bake today is bit-for-bit the bake of yesterday. `ESCALATE.md`
2026-11-06 ~00:20 carries the arithmetic and the three candidates.

**THE HARNESS IS RED AT MAIN, NOT HERE, and no Builder choice unblocks it** (`ESCALATE.md` item 2,
`NEEDS KAREN`). Both lines, same scope, two commits:

```
[harness] FAIL: 18/22 checks @ 2b0bc34865a1cdeff5ea3b78de150586bb954986 (clean tree) scope=all   this branch
[harness] FAIL: 18/22 checks @ db7cd633a1050986a452b66b29b27f109ffc569f (clean tree) scope=all   MAIN, identical failure
```

`tools/review.sh` therefore refuses this request until the DEV Studio is restarted and a PASS line
exists. It is written now so the review can run the moment it does.

## What changed

`src/shared/Grid/Relief.luau`, `src/serverstorage/TerrainBake/init.luau`,
`tests/server/grid_relief.spec.luau`, `tools/terrainbake.py`, and the `TASKS.md` row.

## Claims, and how to verify each

1. **The cache is keyed EXACTLY as the Director decided**: the tuple of the six anchor rows'
   base-column indices. `Relief.AnchorCache` and `anchorKey` in `src/shared/Grid/Relief.luau`; the
   loop is `for s = 0, Relief.BENCH_ANCHOR_STUDS, Relief.VOXEL`, the same six rows the walk reads.
2. **The base reader gained the one index function it needs, and it agrees with the reader about
   WHICH slice answered.** `TerrainBake.columnAt` beside `TerrainBake.readerFor`; `columnOf` names
   `readOne`'s index arithmetic once (`readOne` now calls it). Spec `330-1` enters every arm --
   inside, a hole, inside an extra, outside both -- against `readerFor` at the same points, and
   asserts no two distinct columns share an identity.
3. **It is reachable by parameter in both states and is OFF unless asked.** `shapeTile`,
   `bakeTile` and `bakeTileAt` take a trailing `cacheAnchors`; only `true` builds a cache. Spec
   `330-4b` drives omitted, nil and false and asserts all three return no cache; `330-4` drives
   true and false on a real tile and asserts the heights AND the materials hash the same.
4. **On a straight grid the cache changes nothing, to the bit.** Spec `330-2`, 49 sub-stud steps
   over a hillside: worst `0.000000000` studs, with 4 walks and 45 hits, so the cache was reached.
   The note is in the harness output.
5. **Under the bend it is NOT exact, measured in the shipped arithmetic.** Spec `330-6`: worst
   `0.153004` studs = `9.79` codes of 1/64, 19 walks and 30 hits. It asserts a BOUND, not
   exactness, and its comment says why.
6. **FAIL FIRST.** Spec `330-3`: a key of one bucket per 64 studs diverges by `3.7329` studs, so
   the equality comparison can see a wrong key. Without it "identical" could not be told from a
   check that never compares.
7. **The equality proof ran on the EIGHT heaviest bench tiles in Karen's place: all eight
   stored-height codes DIFFER, and all eight material codes are identical.**
   `<runs-dir>/330-proof-8.txt`, table in `ESCALATE.md` -- seven D2 tiles (392-398) and one B2 tile
   (135), 7,545-8,246 bench columns each, 780,487-911,207 ms uncached -> 3,663-27,978 ms cached.
   Tile 393 was read twice an hour apart and gave `64dafbe0` / `c2d95b90` both times, so it is not
   float noise. The sixteen halves' own JSON rows are in `<runs-dir>/330-attrs-8tile.txt`.
8. **"The ten heaviest" is a measurement, not a list.** `TerrainBake.benchWeightPlan` counts the
   columns that pay an anchor walk and the tool ranks on it: 134 of 1,120 tiles carry bench weight.
   It SAMPLES 1 in 16 and says so, because a full count did not return inside the MCP window; each
   proof row's `walks + hits` is that tile's exact count. **PARTLY MET: 8 of the dispatch's 10.**
   The uncached half is 13-15 min and StudioMCP's request timeout is ~5 min, so each half publishes
   its answer on a `ServerStorage` attribute and the tool polls for it; the eight uncached halves
   cost 1 h 55 m of blocked Studio. I stopped at eight -- they are unanimous, they cover both cells
   in scope, and the dispatch's stop fired on the first.
9. **Nothing was written in Karen's place.** No bake, no plant, no flag change. The sixteen
   `DH330Proof_*` attributes this task set were removed (`clear-proof`: `cleared 16 attribute(s); 0
   left`, then re-read: 0 left), and her 15 `DHFlag_*` overrides are identical before and after,
   name for name (`<runs-dir>/330-karens-flags.txt` diffed against `330-attrs-final.txt`).
   `TerrainEpoch` reads `58575af518ae6156` and this task did not write it.
10. **A1's strip is VOID, not virgin ground**, read live:
    `TerrainBake.snapshot({minX=-7500, maxX=-7336, minZ=-5086, maxZ=-3656}, 0, 500, true)` answers
    14,678 columns, 14,678 holes, **0 ground**. `x -7336..-7016` is 0 of 28,640 live and 0 of 28,640
    in the base file. Her terrain's west edge is `x ~ -7016`. A1 is not in this task's scope.

## What I could not verify

- **The gate.** No `[harness] PASS` exists at any commit tonight, main included (item 2 above).
  CI IS green on the branch: `Build and lint completed success` at `d61928d0`.
- **Two of the ten proof tiles** (claim 8), for the measured reason.
- **The magnitude from the real tile arrays.** `TerrainBake.anchorDeltaAt` and `terrainbake.py
  delta` are committed and lint clean, but every call came back `Target is not reachable` at the
  transport, three times, on two different tiles, while the same-sized `anchorHalfAt` call was
  accepted. The 0.153-stud figure in claim 5 comes from the spec instead, which is the shipped
  arithmetic; the per-column counts are unread.
- **Anything about B2 and D2 on the ground**: no bake, so no frames, no bot climb, no pad or tower
  check, no density or frame-time comparison. All of it is step 1's stop.
