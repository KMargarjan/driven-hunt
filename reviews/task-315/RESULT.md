PASS (items 315a-j and 315a-k NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: `src/` is byte-identical between
round 2's reviewed commit `c9086a27` and the harness's `e8895a55` (`.agent-evidence/log.txt`:
`e8895a55` touches `tests/server/lobby.spec.luau` and `tests/server/lobby_live.spec.luau` only, and
the four commits between them touch `ESCALATE.md` / `TASKS.md` / `RESULT.md` / `REQUEST.md`), and
`paperwork-after-code-commit.txt` says `OK` with only `reviews/task-315/REQUEST.md` after it -- so
round 2's live record stands for the shipped code. SEEN in her place at that code: the walk
(174.3 studs at 3.95 deg, dead level at 150.00), the twelve-tree corridor line, the census, a real
`E` and real clicks on a real shot, board `SHOTS 2 / HITS 1 / CHEST 1 at 119 studs`, and ten
described frames. NOT SEEN BY ANYONE, both core and both declared in the request rather than
claimed: the new east cut face, which the design itself calls *"the single biggest LOOK risk of the
move"* (`docs/design/shooting-range-lobby.md` section 16 item 3, `TASKS.md` 315a(j)), and a hit on a
RUNNING target (`TASKS.md` 315a(k)). Those are the two item numbers on line 1.

Round 2's one blocking finding is closed, and both halves of it bite. `tests/server/lobby_live.spec`
*"carries the corridor's two counters through Lobby.stats, and reads 0 with no range"* goes in
through `Lobby.start` (`fresh(bin, function(world) world.templates = fakeTrees(bin); world.keepClear
= keep; world.sightline = lane end)`), and `Lobby.step` is what calls `tryBuild`. Deleting `keepClear
= world.keepClear` / `sightline = world.sightline` from `tryBuild`'s seam table makes
`Build.keptClear` answer false for everything, so `expect(built.sightlineDropped > 0)` -- the request's
quoted `lobby_live.spec:1174` -- is the line that reddens; deleting `stats.sightlineDropped =
built.sightlineDropped` leaves `Lobby`'s own table at the 0 that `Lobby.start`'s
`for key, value in pairs(stats)` zeroing put there, so `expect(owner.sightlineDropped).to.equal(
built.sightlineDropped)` -- the quoted `:1178`, "Expected 12, got 0" -- is the line that reddens.
Neither side is the same engine identity: `Lobby.stats()` is `table.clone` of this module's own
table, not `Build.stats()`. In `tests/server/lobby.spec`, deleting `treeLine`'s `stats.sightlineDropped
+= 1` leaves `built.sightlineDropped` 7 against `avenueDrops` 7, so `expect(ringDrops).to.equal(5)` --
the quoted `lobby.spec:4854` -- reddens; deleting the avenue's `+= 1` makes `ringDrops` -2 and
`expect(built.sightlineDropped).to.equal(12)` red as well. Claim 8 is right about why 5 is exact:
`treeLine` draws `rng:NextNumber(-JITTER, JITTER)` into `radius` BEFORE every `continue`, so the new
fifth exclusion cannot move a later trunk's position, only its species and yaw.

## Notes (non-blocking)
- `reviews/task-315/REQUEST.md` claim 7 -- *"All three `+= 1` sites are now separable: `treeLine`'s
  reddens the ring row, the avenue's reddens the avenue row"* is wrong twice. `lodgeTrees`' site has
  no bite at all: its branch is never taken (the sibling case asserts `keptClear` false for all
  twelve `LODGE_TREES` rows), so deleting its `+= 1` reddens nothing. And deleting the avenue's
  `+= 1` reddens the RING row and the total, not the avenue row -- `avenueDrops` is replayed through
  `Build.avenuePlan` and never reads the counter. Nothing is unproven, because `expect(
  built.sightlineDropped).to.equal(12)` is exact; the sentence overstates. Strike it or say which
  two sites are separable.
- `reviews/task-315/REQUEST.md` claim 4 -- *"Deleting `keepClear` alone would not bite, because
  `keptClear` also answers true inside the sightline rectangle"* is false, in the safe direction. The
  pine fixture is at `(2844, -3188)` and `Build.sightlineRect` spans z -3057..-2917, so the pine is
  in `keepClear`'s footprint ONLY: deleting `keepClear` alone reddens
  `expect(owner.sightlineCleared).to.equal(1)` and `expect(pine.Parent).to.equal(nil)`. The case
  covers more than the request credits it with.
- `tests/server/lobby.spec.luau` live-build case -- `ringDrops = built.sightlineDropped -
  avenueDrops` is only "the ring's share" while `lodgeTrees` drops none, and that fact is asserted in
  the PREVIOUS `it`, not in this one; the request's *"the twelve-row `LODGE_TREES` loop above it"*
  reads as if it were in the same body. Self-protecting today because the total is pinned at exactly
  12, so a grove row moved south reddens the case either way. Worth one line of cross-reference.
- `docs/design/shooting-range-lobby.md` -- section 5.3's avenue row (*"6 -- all of them"*, with its
  own derivation showing all SEVEN plantable slots inside [2783.5, 2916.5] x [-3057, -2917]) and W5's
  *"12 removed -- 5..7 ring, 6 avenue, 0 grove, 1 world pine"* are one short: measured is 12 dropped
  (5 + 7) plus 1 cleared = 13 removed. Section 16 item 5 already names the census as the decider, so
  this is the design catching up with its own process, not a contradiction -- but the two rows should
  be edited rather than left reading as done. `TASKS.md` 315a has no row for it; claim 9 says it is
  one and it is not.
- `TASKS.md` row 315's status column still reads *"ROUND 2 FINDINGS -> ESCALATED, waiting on the
  Director"*, which round 3 has overtaken.
- `TASKS.md` 315a(a) (`treeLine` asks the corridor guard before `clearOfLodge` walks the planted
  model up to 42 studs) is now COVERED for the live row and can be closed on this evidence, not just
  queued: the new live-build case reads `GetPivot().Position` off everything in `TreeLine`,
  `LodgeTrees` and `Avenue` AFTER the build and asserts `#inside == 0`, and `clearOfLodge` moves by
  `model:PivotTo` and destroys only when six steps fail -- so a trunk walked into the corridor would
  now be caught. The guard's placement is still worth a comment.
- Carried over unchanged from round 2 and correctly queued, not re-litigated here: 315a(c) the
  `clearWorkingGround` comment (`stats.worldFoliageCleared += removed` counts the sightline
  removals), 315a(d) the 11-trunk `inside` list against the backup's 12 (`Avenue01` at
  2845.5, -3047.3), 315a(e) `expect(best < 4.0)` at 3.9697 deg, 315a(g) `range.spec`'s stale section-9
  prose, and 315a(b) design 15.1 items 5 and 14 (W8) still written in no spec.

---
REVIEWER verdict on commit `af360917da2f4ec7e2ee25a0569abc610863b9cd` (round 3) · 2026-10-31 00:26 UTC · session cost $3.90, 42 turns · written by tools/agents.py
