PASS

Round 1's two blocking findings are fixed, and both fixes have teeth:
- Finding 1: "emits tiles the MEASURED voxel ceiling can carry" now takes its tiles from
  `Relief.tiles(Grid.footprint(), Config.TILE_STUDS)` and its 32 / 24 / 24,576 from
  `MapGen.Config` (`TILE_STUDS` 128, `VOXEL` 4, `BAND_Y` {-48,48} -> 32*32*24 = 24576, header
  "MEASURED, 2026-09-26"). Delete `Relief.tiles` and the case errors. The SPLIT half is now
  Deviation 7, not a claim.
- Finding 2: "makes every bench a PLANE at its own weight times its own grade" asserts the
  realised gradient inside the band where `weightOf == 1` and `roadFadeAt == 1`. Checked by hand
  against the shipped recipes and `Grid.CONFIG` (1070 x 1430, roads at originX+21+k*1112 /
  originZ+21+k*1472): A1 0.8*0.02 = 0.0160 over 188 st = 3.008; B2 0.9*0.02 = 0.0180 over 172 =
  3.096; D2 0.7*0.04 = 0.0280 over 260 = 7.280 -- the three printed gate lines exactly. Delete the
  bench branch of `applyOps` and the slope is 0 against `want`, so it fails. `grid_relief: the
  bake's region is 1333 tiles` also reproduces exactly from `Relief.tiles` over the footprint +-430
  (43 x 31), which is independent evidence the pasted gate run played this spec at this code.
Deletion check on the rest: the falloff walk, the road fade, the B2 scarp/ramp heights, the
limiter's three cases, `columnsFor`'s parity case, `materialAt` and the no-voxel behavioural case
all fail with their producer removed (worked through below where it was close). Harness line names
the `Code commit:` 291f68cb, "(clean tree)", scope=all, and
`paperwork-after-code-commit.txt` says OK. `[harness2] N/A` is right against the real diff:
`TWO_PLAYER_PATHS` in `tools/agents.py` holds no `src/shared/Grid/`, no `tests/server/grid_*`, and
excludes `tools/studio_mcp.py` by name.

## Notes (non-blocking)
- Rule 5, stated so this PASS is not read as rule 5 having been met: nothing in this change reaches
  Karen's place and nothing was seen there. No core item (animal behaviour, shooting) is in the
  request -- `Relief` is required by nothing, writes no terrain, and has no caller until 328d. The
  ground's shape, the thing she will eventually judge, exists only as `heightAt`'s numbers and as
  the hillshade PNGs described at `<runs-dir>/328c-relief-<cell>.png`, which I cannot see. The
  request says this plainly under "Not verified", and no claim here depends on a frame.
- `REQUEST.md` "Round 2" bullet -- "the scan's note now says plainly that it **proved nothing** on a
  run where `Source` is unreadable" is false. The shipped note text is unchanged:
  `TestKit.note("grid_relief source scan: Script.Source is " .. (if readable then "readable" else
  "UNREADABLE"))`. The "NOT a silent pass" sentence is a code COMMENT, which the gate log never
  shows. Round 1's note stands as written; the fix is one string.
- `TASKS.md` holds no `328c-notes` row -- the string "328c" does not occur in the file at all -- so
  the four notes the request says are "queued in `TASKS.md` under 328c-notes" (the separable blur,
  `columnsFor`'s inward shift on an off-centre band, the axes `limitPass` runs on, B2's bench weight
  0.9) are queued nowhere in the tree; they exist only in `reviews/task-328c/RESULT.md`. `328a-notes`
  and `328b-notes` rows do exist, so if the Director files this one at merge, say that instead.
- `blurKernel`'s normalisation is asserted by nothing. No case calls `Relief.blurKernel`, and a
  kernel whose taps did not sum to 1 would survive every case: on a flat base `h0 - base` is a
  CONSTANT along the column, so the bench case's gradients, the "every cell's own column" limiter
  case and the outside-the-footprint case all read the same; only the golden would move, and its
  expected numbers came from the same code. The normalisation is correct as written (`sum += if i ==
  0 then w else 2 * w`, then `out[i] /= sum`, applied separably), it is just unpinned. One line
  fixes it: `blurredAt` over a constant base returns that constant.
- `tests/server/grid_relief.spec.luau` / "is the base again outside the footprint" -- all three
  sample points are at or past `BLEND_STUDS` (the first two at a diagonal 283 st), so every one of
  them hits `heightAt`'s `if outside >= Relief.BLEND_STUDS then return base` and the `k = 1 -
  smoothstep(outside / BLEND_STUDS)` branch is never exercised. The case does have teeth -- B2's
  `weightOf` for a scarp returns 1 at every x and `scarpProfile` saturates at -28 past the face, so
  with no blend at all the third point reads 72 against 100 -- but a wrong `k` at 50 or 100 studs out
  would pass. One point mid-blend would close it.
- `Relief.heightAt` -- `k` fades from the CELL's bounds, not the footprint's, so each cell's delta
  bleeds up to 200 studs into its neighbours. Worked example: B2's bench depends only on z, so ~120
  studs east of B2 (inside C2) `k` is ~0.35 and `roadFadeAt` has recovered to ~0.57, which is ~1
  stud of B2's plateau standing in C2 on top of C2's own landform. Nothing composes two cells in
  this change, so nothing is broken -- but 328d's tile pass has to decide what happens in the
  overlap, and the design (section 3.0 "outside the footprint", 5.2's footprint+430 region) reads as
  one blend at the footprint edge rather than eight at the cell edges.
- `tests/server/grid_relief.spec.luau` / "leaves a pinned band exactly where it was" --
  `expect(Relief.isExempt(Relief.LANDFORMS.C1, Grid.boundsOf("C1"), xOff, zc)).to.equal(false)`
  passes `xOff` and `zc` computed from B2's bounds, and C1 has no `scarp` op, so `isExempt` returns
  false at the first guard for any point whatever. The assertion says nothing about C1's geometry.
- `REQUEST.md` claim 3 calls the `SCARP B2 ...` / `RAMPPURE B2 ...` rows "the gate's measured
  `SCARP`/`RAMP` rows", and the Measured section labels those same rows "probe run, 2026-11-02". The
  gate case that does cover the claim is "gives B2 a 28-stud scarp over 64 studs and three ramps at
  15 per cent"; cite that. Same class: the probe that produced `faceMaxDeg`, the per-op peaks and
  `at51` is not in the tree, so those rows cannot be re-derived from the repo (each is corroborated
  by a gate case or by arithmetic off the recipe, and nothing blocking rests on them).
- `REQUEST.md` claim 7 says "**Seven deviations** are listed"; eight are. Round 1's note was
  "three/six"; the count has been wrong both rounds.
- `tests/server/grid_relief.spec.luau` -- `local depth = 1430` in the `noTrees` assertion types in
  `Grid.CONFIG.cellDepthStuds`. Read it from `Grid.CONFIG`, like the rest of the file reads
  `Grid.boundsOf`.
- `Relief.uvOf` ships with no caller and no case (blast radius: "no reference outside the changed
  files"; the spec defines its own local `xzOf` instead). Fine as 328d's API surface, worth one
  assertion when something calls it.

---
REVIEWER verdict on commit `a2c327b99600d08a32a31a6b8e55b437a76fef7f` (round 2) · 2026-11-02 13:39 UTC · session cost $4.71, 44 turns · written by tools/agents.py
