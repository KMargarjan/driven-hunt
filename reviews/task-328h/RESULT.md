PASS (items 1, 2 NOT PROVEN)

Round 3's scope is the two round-2 fixes. Both are real, and both are entered by a case that dies
when the thing it tests dies.

FIX 1 (the window is the TILE's). `TerrainBake.bakeTileAt` now requires `bandMinX = tile.minX - pad
- band.xPad` / `bandMaxX = tile.minX + side + pad + band.xPad` with no `math.max(band.minX, ...)`,
and `bench_slices_for` cuts `min_x = tile["minX"] - pad - extra` with `band["minX"]`/`band["maxX"]`
no longer read at all, for every band of the run with no relevance skip. The arithmetic covers the
reach: `shapeTile`'s grid runs `tile.minX + (i - margin - 0.5) * v` = tile.minX -126 .. +side+126,
`gx = x - bendX(z)` and `baseAtGrid` re-adds `bendX(zAnchor)` (2 * `maxBendStuds` = 120), and
`blurredAt` adds 72 in grid x -- 318 studs against the 324 the window gives. In z, `pad` 136 covers
72 + one voxel + `bendZ`'s 45. So the behavioural defect round 2 named -- the bench anchored on the
RAW base over the cell's x skirt with `covered` still true -- is gone, not relocated.
Delete-the-producer: with `benchBands` returning nothing, 328h-1's `expect(#bands).to.equal(1)`
fails; with the refusal block deleted, (a)'s `expect(none.message).never.to.equal(nil)` fails; with
`bench_slices_for`'s clip deleted, the selftest's "each is cut over the TILE's window" fails.

FIX 2 (precedence). `overlap` is built at the compared point from `bandHeight`, and
`expect(both(x, z)).to.equal(plain(x, z))` now dies if `extras` is tried first (it would return
`height+500` where `plain` returns `height`). The old line survived that; this one does not.

## Notes (non-blocking)
- `tests/server/grid_relief.spec.luau` / 328h-1 — no sub-case distinguishes the unclamped window
  from a RESTORED `bandMinX = math.max(band.minX, ...)` / `bandMaxX = math.min(band.maxX, ...)` in
  `bakeTileAt`. At the picked tile (`tile.minX + side > bounds.maxX`, so tile.minX > -2380 for D2)
  `band.minX` -3458 never binds, so (c)'s `expect(string.find(tooNarrow.message, "covering its
  anchor", ...))` survives the clamp -- `narrow` already fails on the LOW side for want of `xPad` --
  and (e)'s `good` covers the clamped window a fortiori; (b) and (d) are unaffected. The
  distinguishing input is a band cut to `bands[1].minX`/`bands[1].maxX` themselves: it stops at
  -2116 while the required window runs to `tile.minX + 452`. One sub-case (f) handing that band and
  expecting "covering its anchor" closes it. The request's "Restoring either clamp fails those"
  therefore holds for `bench_slices_for` only (the selftest's `abs(c["minX"] - (_tile["minX"] -
  fake_pad - 120)) < 4.001` catches that one); the Luau half is unpinned, and the `ok(...)` cases
  that match `"tile.minX - pad - band.xPad" in bake_text` still pass with the clamp wrapped round it.
- `tests/server/grid_relief.spec.luau` / 328h-2 — `expect(both(x, z)).never.to.equal(bandHeight(x,
  z))` cannot detect the band winning. `snapshotOf` stores `heightOf(minX + (i - 0.5) * v, ...)`, so
  the value a band win returns is `bandHeight(x + 2, z + 2)`, which differs from `bandHeight(x, z)`
  by 0.04 anyway — the assertion passes either way. The precedence is carried entirely by the
  companion `expect(both(x, z)).to.equal(plain(x, z))`. Compare against the column value `overlap`
  actually holds, or drop the line and the request's "and that the answer is NOT the band's".
- `tools/terrainbake.py` / `bench_slices_for` — every band is now cut for every tile over
  `[tile.minX - pad - xPad, tile.minX + side + pad + xPad]` (194 x ~74 columns a band a tile), and
  `base_slice` refuses a rectangle that leaves the file. For a bench run whose region reaches the
  edge of `terrain-base-*.bin` the whole bake now stops at that tile with `[bake] FAILED at tile N`.
  Loud, not silent, and no bench cell has baked -- but 328x should expect it, and the payload is a
  second unmeasured cost beside the ~1.5e8 reads already recorded.
- `src/serverstorage/TerrainBake/init.luau` / `benchBands` — the 324-stud window's sufficiency (126
  + 72 + 2 * `maxBendStuds`) is derived in the header's prose and in `xPad`'s comment, not pinned by
  a case: the margin is 6 studs, and a bend amplitude raised past 63 would silently exceed it while
  `grid_relief` 328h-1 stayed green (it builds its own band from `xPad`). A case asserting the
  window against `LIMIT_MARGIN_STUDS + BLUR.cutoffStuds + 2 * maxBendStuds()` would hold it.
- `reviews/task-328h/REQUEST.md` — "`git diff --name-only 8e05ce48..HEAD` = `ESCALATE.md`,
  `TASKS.md`" omits `reviews/task-328h/REQUEST.md` itself, which
  `.agent-evidence/paperwork-after-code-commit.txt` lists; all three are paperwork and the file reads
  "Not paperwork: none", so the harness line does cover HEAD.
- Round 2's notes (a)-(f) are all still open in the tree and are recorded as queued in `TASKS.md`:
  the five `in bake_text` string cases, `readsWholeCell` dead but for 328d-8, 328h-1's `reach` built
  from the same three constants `benchBands` uses, and `expect(Grid.towersRelaxed(...)).to.equal
  (false)` pinning an absence for three cells that carry no such field.
- `test2` N/A is correct: none of the ten changed files is in `src/server/Match/`,
  `src/client/Match/`, `src/shared/Drive/`, `tests/client/Role.luau` or the named match/drive specs.

Rule 5, stated so this PASS is not read as rule 5 having been met: B1's and D1's baked ground HAS
been seen in Karen's place (F2/F3, before/after at hunter eye height on NS2 and NS5, described, with
the 6.25-stud rise under F2 owned), and the towers and pads were re-measured in a PLAY session. NOT
seen: (a) items 1 and 2 -- no bench cell has baked anywhere, so the band path both round-2 fixes
concern has never written a voxel; what is proved is the RULE by cases, not ground; (b) the thing
Karen asked for -- "more trees behind the line" is cell C2, which did not bake, and
`328h-F1-before.png` / `-after.png` are deliberately the same frame, so her named defect is open in
328x and nobody has seen it fixed; (c) animal behaviour on the new ground -- `328h-sampler.luau` read
`CELL B1 n=0` / `CELL D1 n=0` over 100 s because the FT's drive runs in C1 only.

---
REVIEWER verdict on commit `388311d13fcc2b3ea2693f4ce6f02be4c9fab1d2` (round 3) · 2026-11-04 13:33 UTC · session cost $2.95, 26 turns · written by tools/agents.py
