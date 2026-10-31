PASS (item 2 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: NO frame of the dead
range animal was seen, at main or at the fix. The request says so itself ("A frame of the dead
animal (rule 5): NOT OBTAINABLE") and the reason checks out in the code -- `Range.CONFIG`
in `src/server/Range/init.luau` has `CARCASS_SECONDS = 3` and `Range.step`'s
`now - trial.carcassAt >= Range.CONFIG.CARCASS_SECONDS` calls `clearTarget(trial, "range carcass")`,
so the body is gone about three seconds after the kill. What WAS seen in Karen's place is the
defect, by Karen, in her own words; what has NOT been seen in her place is the FIXED carcass
(claim 2). The instrument behind claim 2 is a numeric Y trace of the TRUNK PART
(`trunk=... size=`), not of the drawn mesh -- `Body.collapse`/`Body.liftDrawn` offset the drawn
parts by `handle.liftedBy` independently of the box -- so "box bottom -0.023 of the floor" is a
claim about the physics box and not about what Karen looks at. Item 1 is not listed: she reported
the defect from play.

The change itself verifies. `Range.TARGETS_FOLDER = "RangeTargets"`
(`src/shared/Range/init.luau`), `src/server/RangeBoot.server.luau` sets
`world.folderName = RangeData.TARGETS_FOLDER` and never overrides `world.parent`, so
`Body.ensureFolder(world.parent, world.folderName)` makes `Workspace.RangeTargets` a DIRECT child
-- which is what `ForestTest.groundAt`'s `Workspace:FindFirstChild(name)` loop needs to find it.
The range's geometry is in a different folder (`Range.FOLDER_NAME = "Range"`, `Range.LAYOUT.folderName`,
`Build` writes `folder.Name = layout.folderName`), so the lane's own floor is still ground. The
arithmetic closes: box 2 x 3.00 x 5.50, standing root 151.477, bottom 149.977, ray from
`part.Position.Y + half + CARCASS_GROUND_FROM_STUDS` (2) hits its own box top at 152.977,
`Body.groundDrop` gap 3.000 -- past `CARCASS_GROUND_TOLERANCE_STUDS` 0.5 and inside
`CARCASS_GROUND_MAX_STUDS` 20, so it returns 3.000 and `stepCarcass` writes it. That is the measured
+3.000 exactly. With the folder ignored the gap is +0.023, inside the tolerance, no write -- which is
claim 2's resting -0.023. `TestArena` and `HighSeats` are correctly still absent from the list
(both are things a body stands ON); `Boars` and `RangeTargets` are the only animal folders any
`world.folderName` produces.

Delete the producer: remove `"RangeTargets"` from `ForestTest.GROUND_IGNORE` and the new case
dies twice -- `expect(table.find(Forest.GROUND_IGNORE, RangeData.TARGETS_FOLDER) ~= nil).to.equal(true)`
goes false, and `expect(read).to.be.near(150, 1e-3)` reads 153 (the carcass box's own top). No line
of it survives the deletion, and the two sides are not one identity: `read` comes from a real
`Workspace:Raycast` against a built floor, `150` from the floor's own geometry (149 + 2/2).
Harness: `[harness] PASS: 34/34 @ 71e6660f73c2fd7e4b49ce839726add561e027bb (clean tree)` names the
request's `Code commit:`, and `paperwork-after-code-commit.txt` says only `reviews/task-318/REQUEST.md`
followed it. `needs_two_player` N/A is correct: neither changed path is in `TWO_PLAYER_PATHS`
(checked against the tuple in `tools/agents.py`, not against the request's word for it).

## Notes (non-blocking)
- `src/shared/ForestTest/init.luau`, `GROUND_IGNORE` comment — "`places.spec` asserts that
  `Places.FOLDER` is in this list and **`range.spec`** that `Range.TARGETS_FOLDER` is" is false.
  `tests/server/range.spec.luau` exists and contains no `GROUND_IGNORE` assertion; the only one is
  the new case in `tests/server/boar_model.spec.luau`. The sentence is the drift guard's own
  signpost, so it points a future reader at a file that will NOT stop the entry being deleted. Name
  `boar_model.spec` instead.
- `docs/design/drive-places.md` §10.1 — the quoted block is still
  `table.freeze({ "OurForest", "Foliage", "Boars", "DrivePlaces" })`, four names, now stale. The
  design's rule ("the ignore list cannot drift from the folder it is about") IS honoured by the new
  spec, so this is text only. Queue it with whatever next touches that doc.
- `tests/server/boar_model.spec.luau`, "never lets a RANGE carcass be its own ground (task 318)" —
  `holder:Destroy()` / `targets:Destroy()` are unprotected: if `Forest.groundAt` ever throws, a
  folder named `RangeTargets` is left parented to `Workspace` for the rest of the run, and
  `hit_card.spec`, `range_solo.spec` and `RangeBoot.server`'s `Workspace:GetChildren()` scan all key
  off that exact name. Related: `groundAt` uses `FindFirstChild`, so a stale same-named folder would
  be the one ignored and this case would go red for an unrelated reason. A `pcall` around the read,
  or TestEZ cleanup, closes both.
- `src/shared/ForestTest/init.luau` comment vs `REQUEST.md` claim 1 — the comment says
  "root Y 151.477 -> 154.477", the request says "154.476 in one frame". One thousandth apart; both
  call it +3.000. Pick one.
- `REQUEST.md` claim 1 — "At the kill it goes to 154.476 in one frame" and "`Anchored` turns true in
  the same frame" cannot both be literally the server's story: `shouldAnchorCarcass` needs
  `stillFor >= CARCASS_STILL_SECONDS` (0.25) before `stepCarcass` reaches the grounding write, so
  the single frame is the CLIENT seeing one replicated CFrame+Anchored pair, not one server step.
  The conclusion is unaffected -- the +3.000 equals the box height and nothing else does -- but the
  trace's own granularity is worth one sentence where the claim is made.

---
REVIEWER verdict on commit `3a309d5b45c9a6af50b129f539fe7e603d6bd569` (round 1) · 2026-10-31 17:29 UTC · session cost $1.89, 41 turns · written by tools/agents.py
