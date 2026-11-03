PASS

Rule 5, stated so this PASS is not read as rule 5 having been met: both halves of what Karen will
judge HAVE been seen in her place at the code commit and described in prose. The stake removal --
claim 2, `328m-BEFORE2-J1.png` vs `-AFTER2-J1.png`, same camera: *"BEFORE, four glowing yellow
pillars stand across the road at ~400 studs ... AFTER, they are gone; the same spruce wall, the same
rutted road, the same far stand frame on the skyline, and no other tall coloured object anywhere in
the frame."* And the new density -- claim 10, `S1` and `W1`, which round 1 found undescribed and this
round describes: *"the flanks close into a wall of conifer with small spire-shaped larches among
them, the hillside is now screened except straight up the ride, and the 54-stud ride itself is still
open from the post to the skyline"*; *"more trunks plus three or four conical young larches standing
BETWEEN them at mid-ground -- a second storey where there was none"*. What remains is her taste
("more realistic"), which is `## Needs Karen` and not rule 5. No core item (animal behaviour,
shooting) is touched.

Delete-the-producer, by reading, on the two cases offered as proof:
- case 22 (claim 1): restore `Places.stakeGrid` and `ownParts == 0`, `report.gridStakes == nil` and
  `report.gridMissing == nil` all redden; delete the grid block entirely and `expect(folder ~= nil)`
  reddens. Teeth both ways.
- case 12a (claims 4, 5, 6, 9): delete the `under` loop in `Places.plantCell` and `saplings > 381`
  cannot pass -- I re-derived the bound from `Grid.CONFIG` (1070 x 1430, inset 3) and the two `scrub`
  zones hold 7x18 + 15x17 = **381 grid sites exactly**, one tree per site maximum, and they are C1's
  only other source of `band == "shrub"` with `side == 1` (the skirt is `side = -1`, the ferns are
  `herb`). Delete the `if item.under ~= nil` arm in `cellCapacity` and the
  `cellCapacity("C1") == zones + under + ferns + skirt` equality reddens. Delete the `under` rows
  from the recipe and `#withUnder > 0` reddens.
  **Two lines of case 12a DO survive the deletion**, named per the duty: `expect(worst >=
  plan.minGapStuds)` (the canopy alone satisfies 12 studs) and the `CELL_STREAM` distinct-id loop
  (data, not behaviour). The case as a whole still fails, so this is not a blocking finding.

## Notes (non-blocking)
- `src/shared/Places/init.luau`, `mixedRolling`'s new header — the "MEASURED, three allocations"
  paragraph is stale after the round-1 fix. It reads *"three allocations of that same budget
  (`driven-hunt-runs/328m-yield-v{1,2,3}.txt`): 1,885 / 1,876 / 1,886 planned models at capacity
  3,548 / 3,588 / 3,526 ... and this one is the split with the most understorey (232 saplings against
  148 and 150)"* — but the shipped split is none of those three: it is v4, at the **3,416** the same
  header states two sentences earlier, and the request's claims 3 and 5 cite `328m-yield-v4.txt` for
  it. 3,548 was round 1's number, with `oakPark`'s 132. Re-point the paragraph at v4 or say the three
  were the rejected allocations.
- `PLAYTEST.md` — the round-1 finding's own wording survives here, in the one file the Builder did not
  rewrite: *"a second storey of young growth under the four wood zones"* (it is three — `oakPark`
  takes neither) and *"`oakPark`, the clearing and the two scrub zones are untouched"*, which the same
  sentence's own preceding clause (*"`jitter` 1.0 on every zone"*) contradicts. The recipe header and
  the `TASKS.md` row both say it correctly per zone.
- `tests/server/grid.spec.luau`, case 12a — the capacity half re-implements `cells()` verbatim from
  `Places.cellCapacity`, so the equality catches the *missing* `under` term but would not catch a
  wrong cell formula (verdict 278). `expect(under > 0)` is the independent part that carries it.
  The no-displacement half is still argued in the comment rather than asserted against a golden
  (already queued as 328m-notes (f)); for what it is worth I checked it holds by construction -- the
  `under` loop runs after the whole zone loop on its own `Random`, and the only shared state is the
  `trees` bucket grid, whose only later reader is the skirt, which `Places.skirtBands` puts entirely
  inside the NEIGHBOUR's inset ground across a 42-stud road, far beyond `minGapStuds` 12.
- `foliageInGround` **62 -> 65** (claim 7) is the one design 12.1 counter that moved the wrong way,
  and the cause the request names is consistent with the new layer: `scatter` sends every
  `band ~= "herb"` site inside C1's `frontage.studs` 60 through `frontageGroupFor`, whose groups
  include `fieldOak`, so a `Field_OakTree_Var04/05/07` at 0.35-0.45 is a legal understorey stem and
  is 328l's documented residue. The rate fell (4.33 % -> 3.85 %) and the target was already breached
  at 62 with a `QUARANTINE` row offered to Karen -- for whoever takes that up, not for this round.
- `Places.UNDER_JITTER`'s override is still unreachable (no recipe sets `under.jitter`, no case drives
  it) and the synthetic recipe drops `rows`; the header now says both, which is what round 1 asked
  for. Queued as 328m-notes (e).
- Queued and still open, outside the files this change touched: `Flags.GRID_PREVIEW.why` (*"their
  corners staked"*), `ForestTest.GROUND_IGNORE`'s header, `tools/studio_mcp.py`'s two scope comments,
  and the two design appends (`grid-terrain.md` §8.1's optional-field list has no `under` row;
  `grid-map.md`'s preview sentence). I confirmed no tool PARSES the boot's `grid:` line, so the
  format change breaks nothing.
- What I re-derived rather than took on trust, all of it exact: capacity 1,573 + 1,025 = **2,598**
  before and 1,875 + 516 + 1,025 = **3,416** after, 184 under 3,600 (claim 5); `oakPark` cap
  **120** at spacing 44 and its row byte-identical to the base, so claim 3's "untouched" now holds;
  the two `scrub` zones' **381** sites (claim 4); `refusedPct` 122/1809 = 6.74 % and 118/1551 =
  7.61 %, `parts` 5104/1687 = 3.03 (claim 7). The removal is complete -- `Places.STAKE`, `gridStakes`,
  `stakeGrid` and `Stake_` survive only in the rule-7 archive, one pointer comment and case 22's two
  `nil` assertions -- and `report.gridSeconds`, the only field the rewritten boot print still reads,
  is set in both report shapes. Harness `[harness] PASS: 34/34 checks @ 7ff5c4d3 (clean tree)
  scope=all` names the request's `Code commit:`; `paperwork-after-code-commit.txt` reads OK (only
  `TASKS.md` and `REQUEST.md` followed it); selene 0/0, stylua clean, `rojo build` exit 0. No gate
  threshold, no `SCOPE_SPECS` and no flag row was touched (L-041). The `328m-*.txt` probe outputs are
  outside the worktree and were checked for internal consistency only.

---
REVIEWER verdict on commit `5d0e1e20f7bca693ef9ad8972bba0b6f1959be68` (round 2) · 2026-11-03 10:42 UTC · session cost $3.26, 41 turns · written by tools/agents.py
