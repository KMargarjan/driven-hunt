PASS (item 9 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing in this task is a core
item (no animal behaviour and no shooting code is touched; `ForestTest.LAYOUTS` is untouched and
`GRID_PREVIEW` is born `false`, so with the flag off this change paints nothing and parents nothing
in Karen's place). What the design's §17 says Karen gets from 327a -- *"she walks the eight cells'
roads and stands at a corner"* -- has NOT been seen by her. It has been seen only by the Builder,
with the flag forced on by attribute and removed after: three frames are DESCRIBED
(`327-road.png`, `327-air2.png`, `327-air3.png`) and I cannot see them, which is not blocking. The
boot line, the 32 stakes, the 270 calls and the `Ground`-on-road / `Grass`-off-road probe are
consistent with the code and I could re-derive every number in them by hand; the design's own D-1
(the `screen_capture` fault, `ESCALATE.md` 2026-11-01) means item 9 rests on Karen's eye and item 9's
`< 4.0 s` road-paint target is MISSED at 6.09 s, by the Builder's own report.

Delete the producer, by reading, for all eight cases offered as proof -- no case survives:
- case 1: delete `Grid.CELLS`/`seedFor` -> the relief and seed loops error. The seed loop has teeth:
  replace `mix32` with the identity and `seedFor` becomes a plain xor chain, which is commutative, so
  A2 (row 2, col 1) and B1 (row 1, col 2) collide and `expect(seen[seed]).to.equal(nil)` reddens.
- case 3: delete `footprint`/`boundsOf`/`roads`/`roadsOf` -> errors; the literals 4490 / 2986 and
  `of.main.at < cell.minZ` are independent of the functions' own arithmetic.
- case 5: the loop calls `Grid.standPosition` and `sideOf` directly; `expect(apart >= range)` is a
  real inequality, not a transcription. Shrink `flankFirstStuds` and 576 pairs redden.
- case 6: the transcription line (`== math.ceil(required) + flankMargin`) WOULD survive a formula
  change, but it is flanked by `to.equal(340)`, `dx == 106`, `required ~= 312.51` and
  `sqrt(dx^2 + flankFirst^2) >= range`, which do not.
- case 9: delete `CONFIG.cellDepthStuds` / `beaterWalkStudsPerSecond` -> arithmetic on nil.
- case 11: delete `standWalk` -> error; the literal `{4,3,5,2,6,1,7,8,12,9,13,10,14,11,15}` is the
  design's own order and I re-derived the generator by hand.
- case 19: delete `paintRoads`/`roadChunks`/`roadBand` -> error. `enabled = false` -> 0 calls, and
  the nil-reader case -> 0 calls, are both real refusals.
- case 22: delete the grid block in `Places.build` -> `report.gridStakes` is 0, not 32.
No comparison in the file is a value against itself through two names.

## Notes (non-blocking)

- `tests/server/grid.spec.luau`, case 19 -- nothing asserts the chunks TILE their road. `calls ==
  bands * sources` computes `bands` from `Ground.roadChunks` itself, the inside-the-road loop is
  per-ROAD (not per chunk), and `ROAD_CHUNK_STUDS >= roadStuds * sources / budget` compares two
  constants -- so a `roadChunks` that covered half a road would still pass every line, and a
  half-painted road is exactly what Karen would see. (The shipped function is correct: `each =
  length / pieces` tiles exactly.) Three lines would close it: `chunks[1].from == road.from`,
  `chunks[#chunks].to == road.to`, and each `from` equal to the previous `to`.
- `tests/server/grid.spec.luau`, case 19 -- `local slack = Grid.CONFIG.roadClearStuds / 2` is 21
  where the geometry permits at most 14, and design §13.1 case 19 asks for "a road's own PAINTED
  half-width". Every road centre is 1 mod 4 (`originX`/`originZ` are multiples of 4, the pitches
  1112 and 1472 are too, plus the 21), so `bandBounds(at, 9)` is exactly `[at-13, at+7]` for all
  eight roads. The comment's "9 + 4 is still well inside 21" is right; the bound is loose by 7, and
  a paint twice as wide would pass this loop (`surface.halfWidthStuds * 2 == roadPaintStuds` is what
  catches that instead). Tighten `slack` to 14.
- `Ground.bandBounds` applied to a grid road -- the painted strip is **20** studs, not
  `Grid.CONFIG.roadPaintStuds` 18 (`columns = ceil(18/4) = 5`), and it is not centred on the road:
  `[at-13, at+7]` puts a hunter standing on the centre line 3 studs off the paint's middle. Harmless
  on a 20-stud road and `bandBounds`' header already states the width rule, but `roadPaintStuds = 18`
  is not the width the world gets; say so at that CONFIG row.
- `Grid.standPosition` / `Grid.sideOf` -- no range check. `sideOf(id, 99)` answers `"east"` and
  `standPosition(id, 99)` answers a point `340 + 87*220` studs north of the main road, outside the
  cell and outside the world. Not reachable today (nothing in `src/` calls it, and the claim path
  validates `claimed <= ForestTest.layout().standCount`), but 327b wires a client-supplied index
  into this seam. Assert against `Grid.standCount` here, where the index is turned into a position.
- road paint time -- 6.09 s against the design's `< 4.0 s` (§8.3, §13.4), reported rather than
  smoothed, and the design's own derivation of that target assumed 2 source materials where
  `Ground.band` makes 9. `ROAD_CALLS_PER_STEP` 2 over 270 calls is 135 `task.wait()`s = ~2.3 s of
  the 6.09 s on its own. Queue a re-baseline of the §8.3 row or a higher `ROAD_CALLS_PER_STEP`; the
  gating number (270 <= 300 calls) is met.
- the two harness runs of `dd4e1650` disagree -- `FAIL: 32/34` with `2666 passed, 1 failed, 1 errors`
  then `PASS: 34/34`, same tree, and the failing spec's name is lost. I am not holding the change on
  it: the quoted line names the `Code commit:`, is `(clean tree)`, `paperwork-after-code-commit.txt`
  says OK, and nothing here can plausibly cause it -- `grid.spec` is pure and clock-free, `Flags.isOn`
  resolves once and never yields, and `places.spec`'s two `Planter.build` calls take the
  flag-off path (`previewOn = false` -> `paintRoads` returns 0 and no folder is parented). But the
  PASS that gates this merge rests on a retry; the next run should capture the head of the output.
- `ForestTestBoot` -- the grid line prints `tostring(Places.gridPreviewEnabled())`, a SECOND read of
  the flag, rather than what `build` actually used. Cached resolution makes them agree in practice,
  but one fact with two readers is what the report exists to prevent: add `gridPreview = previewOn`
  to the report and print that.
- `src/server/Places/init.luau`, `Places.build` -- the `no-ground-reader` early return gained the
  four `grid*` keys but still omits `parts`, `paints` and `unblocked`, which the boot's `%d` would
  error on. Pre-existing and unreachable from the boot (the reader is always passed); this change did
  not make it worse.
- `src/shared/ForestTest/init.luau`, `GROUND_IGNORE` -- design §17 assigns `"GridPlaces"` to 327c,
  not 327a. One line, and it belongs here now that 32 stakes stand inside the footprint (§8.4 asks
  for it too). Noted as scope only; nothing to queue.
- `src/shared/Grid/init.luau` header -- `Grid` requires `Shotgun`, where design §4.6 states "`Grid`
  requires **nothing**". Stated in the file with its reason (the slug range §7 derives the set-back
  from) but not in the request's deviation list. The right call -- the alternative is a second copy
  of 330 -- and no cycle: `Shotgun` requires nothing.
- `tests/server/grid.spec.luau`, case 1 -- the `< 0.11` tolerance on `spreadStuds` is unexplained and
  only one row needs it: C2 reads `237.2 - 94.6 = 142.6` against `spreadStuds = 142.7`, 0.1 off
  because both ends are rounded to 1 dp. Deterministic over frozen literals so it cannot flip, but
  the comment should say the 0.11 is two 1-dp readings' rounding and not float noise.
- `docs/research/2026-11-01-the-grid-map.md` §5 names the probes `327-survey3.luau` ..
  `327-survey6.luau`; the request says `.. 327-survey7.luau`.

---
REVIEWER verdict on commit `1a79b1e1df5cfb35f826aa41d19c352ba56601a9` (round 1) · 2026-11-01 21:00 UTC · session cost $6.35, 58 turns · written by tools/agents.py
