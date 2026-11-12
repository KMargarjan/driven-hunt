PASS (items 3, 4, 7 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: of this task's core items only
claim 10 has been SEEN in Karen's place — one hunter-view frame of an A2 lane, from the hunter's own
camera, with no animal in the lane or at the tree line, which is the absence T5 claims. Claims 3, 4
and 7 are MEASURED off the console and the `DHForestPlacement` attribute and were never seen; nobody
has watched a flag-ON drive's groups be found by the line (that is T6).

Harness/evidence consistency checked: the request's `[harness] PASS: 34/34 checks @ 713711b8...
(clean tree) scope=all` names the request's `Code commit:`, and
`.agent-evidence/paperwork-after-code-commit.txt` says only `reviews/task-345e/REQUEST.md` changed
after it. selene 0/0, stylua clean, rojo build exit 0. `test2` N/A is TRUE against the real list:
`tools/agents.py` `TWO_PLAYER_PATHS` contains no `src/server/ForestTest/`, `src/shared/ForestTest/`,
`forest_line.spec` or `forest_placement.spec` entry.

Delete-the-producer, by reading, for each case offered as proof:
- claim 1, `forest_line.spec` "is SILENT past the end of the script..." — delete
  `if inPlace == true then return nil end` in `Data.slotAt` and `expect(onRows).to.equal(0)` fails
  (`onRows` is now incremented), as do all thirty `to.equal(nil)` rows: the window at slots 16+ has
  non-deer candidates 7 and 11, both kept at `quiet`, so every density answers a row with the branch
  gone. BITES.
- claim 2, "hands the switch through ForestTest.waveAt" — the ON arm `to.equal(nil)` bites; the OFF
  arm is `waveAt`'s own callee at the same arguments and proves nothing, which the request itself
  declares rather than claims.
- claim 5, "counts a lane spawn when a slot the roster does not own reaches the spawn half" — delete
  the `if onNow and staged == nil then state.laneSpawns = ... end` block in `releaseLine` and
  `expect(got.laneSpawns > 0)`, `laneSlots == 1`, `laneWorstSlot == got.slot` and
  `got.made == got.laneSpawns` all fail. BITES. The Builder's reported trace
  (`:1695` plus `:1551 function laneSpawnOnce ... :1763`) is internally consistent: the reset case
  aborts first, leaving `state.rosterDrive == 973`, so the second `laneSpawnOnce` fails at
  `expect(Forest.planDrive(973, true) ~= nil)`. Round 1's blocking finding is fixed.
- claim 6, "zeroes all six new counters in planDrive" — `wokeHorn`/`wokeSlot` are dirtied through
  `stepPlacement` (a `where[id].flying = true` body with no latch of ours; a walker past
  `wakeAtSeconds`), asserted `> 0`, then zeroed by `planDrive`: delete those two resets and the two
  `to.equal(0)` lines fail. The nine extra steps bite the two latches: remove `if row.wokeAs == nil`
  or `row.slotDue` and `held.wokeHorn == before.wokeHorn` / `held.wokeSlot == before.wokeSlot` fail.
  BITES.
- claim 7's fix verified in code: `Placement.wakeReason` returns nil for a row that is not `bedded`,
  and the band/slot arm sits behind `row.state == "bedded"`, so `wokeBand` needs no latch while the
  slot arm (which never sets `woken`) does. `row.slotDue` and `row.wokeAs` gate counters only —
  nothing else reads them, so "COUNT only, change nothing" holds.
- claim 9 verified by grep: `driveIndexAt`, `wavesPerDrive`, `deerWaveOf`, `deerWanted`,
  `twoLineChance` and `ForestTest.drive` have no reader in `src/`, `tests/` or `tools/` — comments
  and the `backups/` copy only. The archive file exists with the code and the reason (rule 7).
- the three remaining `slotAt` callers (`stagRow`, `driveTally`, `Placement.plan`) all loop
  `1..#rows`, so the retired branch is unreachable for them and the 3-argument calls are unaffected.
- `releaseLine`'s `if placed == 0 then return` precedes the lane block, so `laneSlots` cannot count a
  slot that put nothing on the ground.

## Notes (non-blocking)
- `forest_placement.spec` / `it("zeroes all six new counters in planDrive...")` — the title says all
  six, but `expect(after.wokeWalk).to.equal(0)` cannot fail: `state.placementWokeWalk` is only ever
  written behind `state.latched`, which only `spookNearBeaters` writes, which needs a live beater.
  The comment says exactly this and claim 6 declares it, so nothing false is claimed — but delete
  `state.placementWokeWalk = 0` from `planDrive` and the case still passes. Retitle to five, or
  queue the live-beater case.
- `forest_placement.spec` / `laneSpawnOnce` — it patches `Forest.computeRouteVia` and restores it
  without `pcall`, and both call sites use drive key `973`, so the first failure leaks the patch and
  leaves `state.rosterDrive == 973`, which turns the second call's `planDrive` into a second,
  misleading failure (that is precisely the Builder's own delete-and-fail trace). Give each call its
  own drive number and restore the patch in a `pcall`.
- `ForestTest.budget()` / `it("holds the dormant roster inside 120 rows...")` — the new
  `expect(animals).to.equal(83)` is right, but the old `expect(animals <= budget.dormantRows)` is
  kept beside it and still compares an ANIMAL count with a ROW cap. Drop it; `#rows <=
  budget.dormantRows` above already asserts the row half.
- `ForestTest.budget()` — still a subset of design 5.2: "groups PLACED per drive 9 / 13 / 15",
  "animals PLACED per drive 53 / 73 / 83" and "groups skipped for `inview`, per drive 0" have no row,
  so the spec asserts 83 as a literal where a published row would have had an owner.
- `forest_placement.spec` / `laneSpawnOnce` — `expect(got.made).to.equal(got.laneSpawns)` holds only
  while the same `Forest.step` does not also materialise a bed (both go through `runtime:spawn`). It
  passes today; if `stepPlacement` ever materialises on the release tick this line turns red for a
  reason that has nothing to do with the counter. Count the handles made by the release instead.
- `ForestTest.releaseLine` — the `state.owedRow` door is still open on the ON path: a deer row
  `Placement.plan` dropped can be refused by `runtime:deerAllowed`, latched into `owedRow`, and then
  resurrected at a slot past `#rows` where `rosterSlot` finds nothing, which is a lane spawn. It
  cannot fire in her Forest Test (`ForestTestBoot` raises `MAX_GROUPS_ALIVE` to `MAX_DEER_GROUPS`
  40), which is consistent with the measured 0, and the request queues it. Still the one hole in
  "0 for EVERY slot".
- `docs/design/animal-placement.md` 17's T5 row asks for `repeatFrom`/`repeatTo`/`repeatRoomFor` and
  the clamp family to be **archived**; they are KEPT, per the dispatch's *"flag OFF stays today's
  drive byte for byte"*, with the reason written in `backups/2026-11-12_task-345e_...md` and beside
  each function. The design row and the code now disagree — the Architect's to reconcile at T6.
- `TASKS.md` row 345e — status still reads "in review (round 1)" and the third column still names
  code commit `982e52c9`, not `713711b8`.
- `REQUEST.md` preamble — *"the live measurements of claims 3, 4 and 8"*: claim 8 is the budget spec
  and carries no live reading; claim 7 is the one that does.

---
REVIEWER verdict on commit `08a498fb2b0eb8f1386603072d7941e2ea19f449` (round 2) · 2026-11-12 05:36 UTC · session cost $3.75, 39 turns · written by tools/agents.py
