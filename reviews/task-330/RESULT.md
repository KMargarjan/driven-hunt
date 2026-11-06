PASS

Rule 5, stated so this PASS is not read as rule 5 having been met: NO ITEM OF TASK 330 IS A CORE
ITEM under the digest's definition -- nothing here is animal behaviour or shooting -- so the
parenthesis is empty for that reason and not because Karen has played this. What she has NOT seen:
B2 and D2 played, a bot or a beater on B2's three ramps (claim's own "no bot walked it"), and the
before/after of the B2 spot (`330-F0` NOT OBTAINABLE, stated). What WAS seen in her place and
described (rule 5): `330-F1` at B2 stand 4 and `330-F2` at D2 stand 4 from hunter eye height, plus
`330b-F2-screen.png` as the negative control looking away from the cell.

Delete-the-producer, read case by case (duty (a)):
- `330-2` would survive the cache's deletion on `worst` alone (off == on trivially) -- but it dies on
  `expect(anchors.misses > 0)` / `expect(anchors.hits > 0)`. Survives nothing.
- `330-3` dies on `expect(coarse.hits > 0)`; `330-7` on `expect(exact.auditWalks > 0)` and
  `expect(coarse.auditWalks > 0)`; `330-8` on `expect(walksOne).to.equal(hitsOne)`; `330-4` and
  `330-4b` on `expect(anchors).to.be.ok()` / `expect(built).to.be.ok()`; `330-1` on
  `expect(columnAt(2, 102)).to.equal(TerrainBake.COLUMN_SPACE + 1)`; `330-5` on
  `codeFnv(a) never.to.equal(codeFnv(b))`. None is a value compared with itself.
- selftest: `endswith(', {}, true, 64)')` and `endswith(', {"C1"}, nil, 0)')` die if the two flags
  are not plumbed; `over == 2 and len(overEntries) == 1 and under == 0` dies if the 0.25-st stop is
  removed, and carries its own FAIL FIRST (0.9 st stops, 0.2 st does not); the three retry arms are
  driven through `CALL_IMPL`, which is why they are not exercising a leftover stub.
- `330-6` is the one case offered as a measurement that CAN pass vacuously -- see note 1. It is not
  what claim 1 rests on, so it is a note, not a finding.
Claim 3's `[bake]` line matches `tile_pass`'s own format string field for field, names the request's
`Code commit: 3bce240c`, is "(clean tree)", and
`.agent-evidence/paperwork-after-code-commit.txt` says only ESCALATE.md / TASKS.md / REQUEST.md
followed it. selene, stylua and `rojo build` are all exit 0. No secret, path or address in the diff.
Behaviour with the cache OFF is unchanged: `anchorMeanAt(..., nil)` is the old inline loop
statement for statement, which is why `BAKE_VERSION` and `relief_golden` correctly did not move.

## Notes (non-blocking)

- `tests/server/grid_relief.spec.luau` / `330-6` — it asserts only `anchors.hits > 0` and
  `worst < 0.25`. `Relief.heightAt` multiplies the whole delta by `roadFadeAt`, so at any sample
  point inside a road's 51-stud fade `off == on` whatever the key does, and the bound passes for
  want of a difference. `330-2` is protected by `330-3` at the SAME x and `z = Z0 + 90`; `330-6` at
  `z = Z0 + 150` has no companion. Add a floor -- `expect(worst > 1 / 64)` or a plain off-vs-on
  comparison at the bent point -- so the bent case cannot go quiet.
- `Relief.applyOps`, the audit's appear/vanish arm — `anchors.auditWorst = math.huge` is returned on
  the report and `bakeTileAtPublished` then hands it to `HttpService:JSONEncode`. A non-finite
  number there makes `CALL_TEMPLATE`'s `pcall` return `{ error = ... }`, `call` raises, and
  `tile_call` re-raises it (the message is neither "timeout" nor "not reachable") -- so the one arm
  that means "a whole bench plane appeared or vanished" ends the bake with a JSON error instead of
  the `[bake] STOP at tile N` line guard 2 is written to print. Clamp to a large finite sentinel.
- `tools/terrainbake.py` `tile_call` / `proof_half` — both catch `RuntimeError` only, and
  `tools/studio_mcp.py` says of its own transport "the transport raises queue.Empty when StudioMCP
  stops answering". A CLIENT-side timeout (the `timeout=` on `_rpc`, i.e. `self.lines.get`) is
  therefore not the case the handler covers; only the server-side `Request timeout` /
  `Target is not reachable` bodies are. The poll loop below already catches bare `Exception`. Catch
  `queue.Empty` in the first call too, or the "MCP gave up ... polling" path is unreachable for half
  of what the docstring names.
- `tools/terrainbake.py:1951` and `:2110` vs `TerrainBake.proofAttr` / `TerrainBake.tileAttr` — the
  attribute name is typed TWICE, `"DH330Proof_T%d_%s"` and `"DH330Tile_%s_%d"` in Python against
  `string.format` off `PROOF_PREFIX` / `TILE_PREFIX` in Luau, with no check that they agree. The
  module's own comment says "`TerrainBake.proofAttr` is the one place the name is built, so the
  writer and the reader cannot disagree about it", which the Python copy makes untrue. The file's own
  precedent is the opposite (`from studio_mcp import QUERY_PLACE_AND_NAME`, "IMPORTED, not re-typed",
  and `args_side()` reading `TILE_STUDS` out of the Luau). Drift costs a 30-minute
  `TILE_POLL_SECONDS` wait mid-bake.
- `tools/terrainbake.py` `call` — `retries` now defaults to `CALL_RETRIES = 3` for EVERY caller, not
  just the bake, and the Builder's own evidence is that `Target is not reachable` can come back
  while the Luau ran to completion ("a retried tile is RE-SHAPED ... the answer was on its attribute
  after the first"). `plant` is safe only because `Places.dressCell` is "destroy whatever cell is
  standing, then plant this one" -- that is what makes a retried plant idempotent, and it is the
  load-bearing fact the retry comment does not name. Say it there, or set `retries=1` on
  `command_plant`'s `PLANT_SEAM` call.
- `TerrainBake.epochInputFor` — it is `baseSha + Relief.epochInput(...) + BAKE_VERSION`, with no
  term for `cacheAnchors`. A cache-ON bake and a cache-OFF bake from the same base therefore write
  DIFFERENT ground under the SAME `TerrainEpoch`, so `PlantEpoch == TerrainEpoch` no longer means
  "this wood was planted on this ground". Harmless at 0.194 st and everything was re-planted in one
  run (claim 6), but it is a new hole in design 5.4's arbiter and belongs in the Architect's next
  grid-terrain pass beside the six-row key.
- `tools/terrainbake.py` `tile_pass`, the stop message — `"%d tile(s) were written before this one"
  % (index - 1)` is true as worded but reads as the total written; the divergent tile ITSELF was
  already written when the report came back, so the operator's count of touched tiles is `index`.
- `tools/terrainbake.py` `tile_pass`, the `[audit]` line — it prints the worst stored height and
  `anchorAuditWorstAtX` on one line, but `auditWorstAtX` is only updated beside `auditWorst` (the
  raw anchor gap); `auditWorstHeight` takes its own `math.max` and can come from a different column.
  Either track an x for the height or drop the x from that clause.
- `TerrainBake.columnAt` vs `TerrainBake.readerFor` — `readOne` falls through to `extras` when
  `height[at]` is nil, `columnOf` does not (it answers `at` for any in-bounds non-hole column). With
  a fully populated `height` the two agree, but the header's "it walks `snapshot` then `extras` in
  exactly `readerFor`'s order, so the number names the column that actually answered" is one
  condition stronger than the code. One line in the header, or key off `readOne`'s own fall-through.
- `tools/terrainbake.py` Usage block — the new `proof` entry carries a stray copied
  `# read-only: per-tile cost, DRY (no WriteVoxels)` from `measure`, and the two other new commands,
  `delta` and `clear-proof`, have no Usage entry at all although both are in `choices`.
- `tools/terrainbake.py` selftest — `other = FakeStudio(0)` is dead: it is overwritten by
  `other = OtherError(0)` two statements later before it is used.
- `TerrainBake.diffTileAt` — the replacement comment ("`TerrainBake.codeFnv`, which task 330 named
  once ...") was left above the `TerrainBake.snapshot` call, so it now heads the wrong statement; the
  `codeFnv` use moved down into the `out` table.
- `reviews/task-330/REQUEST.md` claim 2 — "0.77% of the run's 443,523 bench evaluations" is 0.70%;
  0.77% is 3,092 of the ~395,776 HITS (3,092 x 128). Say which denominator.
- `reviews/task-330/REQUEST.md` claim 1 — `Relief.anchorMeanAt` is not a member of `Relief`; it is a
  file-local `anchorMeanAt`. Same for claim 6's `[bake] plant OK:` quote, which drops the line's
  real tail (`in Workspace.GridForest (clean tree)`).
- `ESCALATE.md` 2026-11-06 ~00:20 section 4 — the `grep -n 'kind = "bench"'` line numbers
  (A1 741, B2 828, D2 855) are stale; they are now 799, 886 and 913. The conclusion is right: those
  are the only three bench ops and `Relief.LANDFORMS.C2` has none, which is what makes claim 4's
  "the cache did not do it" readable off the code.
- QUEUE, and it is beyond this task's statement (rule 4), so it is named rather than fixed: **the B2
  ramp climb**. The request calls 29.09 / 49.62 / 56.03 deg a failure of "the design's own floor",
  but §15 item 4's 15% is a FLOOR on how shallow the face may become ("below that it is not a
  scarp"), not a ceiling, and design 13.1 item 6 exempts the scarp and the ramps from the slope
  limiter -- so a steepest-single-step angle on a ramp is the base's own roughness, not the ramp's
  grade, and 13.1 item 4's "within 1% of 15" is about the op's `gradePercent`, which is 15. The
  substance still wants a task: measure the ramps' MEAN grade over the run, not the worst step
  between neighbouring samples, before anyone concludes B2 needs a different landform. Nothing is
  broken today -- `GRID_PREVIEW` builds C1 only, so no drive crosses B2.
- QUEUE: **frame time p95**. +19.4% (B2) and +29.4% (D2) against the 15% guard, in a session with an
  un-isolated live drive. Mean and median are inside it. The confound is named and the numbers are
  given, so this is NOT PROVEN rather than a miss -- but it needs one isolated re-measure of B2 and
  D2 with no drive running before the gate reads the guard as met.

---
REVIEWER verdict on commit `9aa1f8e31b4c0173308415a197a93da831a7a5cf` (round 1) · 2026-11-06 04:42 UTC · session cost $4.70, 38 turns · written by tools/agents.py
