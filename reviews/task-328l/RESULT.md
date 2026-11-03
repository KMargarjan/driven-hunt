PASS

Rule 5, stated so this PASS is not read as rule 5 having been met: this task has no **core**
item -- it is forest planting, not animal behaviour or shooting -- so nothing in the parenthesis.
What Karen will judge here is a LOOK, and what I can check of it is this: claim 10 names three
before/after pairs at 5.6 studs (`328l-{BEFORE,AFTER}-{W1,W2,W3}.png`) and describes W3's change
in words ("the tree line stands 10-20 studs closer to the road"), so rule 5's description duty is
met in form; I cannot see the images, which the rules say is not blocking. The request itself
concedes W1's pair is not the same tree, and `328a-queued` (b) D-1 -- `screen_capture` returning
one cached image for six cameras -- is still open, so "same cameras both runs" is the one part of
claim 10 that no evidence in this repo can corroborate. The numbers, by contrast, are checkable
and are internally consistent in a way that is hard to fake: 1,551 offered - 118 cliff = 1,433
trees and 118/1551 = 7.61 %, and 1,452 - 88 = 1,364 at 6.1 %; `foliageInGround` 62 = 22+23+17.

Verified by reading, not taken from the request:
- the harness line names `Code commit: f26bcf05`, is "(clean tree)", and
  `paperwork-after-code-commit.txt` says OK (only `TASKS.md` and `REQUEST.md` followed it).
- the seat's arithmetic closes the census's own test. After seating, junction = lowGround - sink,
  so the census's `foliageLow < lowGround - 0.5` becomes `sink + drop > 0.5`, and `sinkFor` holds
  `sink <= 0.45 - drop`. The direction is right and the margin is `FOLIAGE_MARGIN_STUDS`.
- the `sunk` and `floating` counters still read 0 under the shallower seat: `low - junction` = sink
  <= `sinkFor(height)`, and `gap` = -sink <= `TOLERANCE_STUDS` even at sink 0.
- DELETE THE PRODUCER, all four new cases bite. 2c-1/2c-2/`foliageDrop` call
  `Plan.nearestScale` / `Planter.pickTemplate` / `Planter.foliageDrop` by name -- deletion is an
  error, not a pass. 2c-3's `expect(Planter.auditTemplate(off, name)).to.equal("template-rescaled")`
  fails with the arm gone (`auditReason` answers `part-count` there). `decide carries the drop`
  asserts -2.6 / -2.0 / -2.35 from one call site; drop the sixth argument and the last two read
  -2.6. `nearestScale`'s tie-break is on the scale VALUE, so the two sides are not one identity
  and `{0.50,0.10,0.30}` genuinely refuses index 1.
- `CROWN_SCALE_SLACK` has no code caller left anywhere (only prose and the archive), and
  `rawget(Plan, "CROWN_SCALE_SLACK") == nil` pins the retirement.
- the archive exists with the constant, its header and its arithmetic (rule 7).
- `TreeGround.sinkFor`'s new parameter is optional and its one other caller,
  `GridCensus.survey`, passes one argument -- old behaviour, and the right direction for `sunk`.
- `template()` in `Places.build` memoises in `lookup`, so `pickTemplate` runs 35 times, not 2,400.
- selene 0/0, stylua clean, rojo builds, no secret, no local path, noreply author.

## Notes (non-blocking)
- `src/server/Places/init.luau` / `plantOne` — the clamp pays for `sink + foliageDrop`, but the
  seat puts the JUNCTION at `lowGround - sink` and `foliageDrop` is measured against `trunk.minY`,
  so for a template with a non-zero `clawFor` the crown finishes a further `clawFraction * height`
  down and the clamp does not pay for it. It does not bite today: of `CLAW_FRACTION`'s five
  non-zero names only `SilverBirch_Var11_LOD_0` (0.0425) and `_Var13_LOD_0` (0.0239) are in
  `SPECIES`, and both have crowns far above the trunk's foot, which is why `room` is never the
  binding term for them. Pass `TreeGround.junctionY(trunk.minY, whole.maxY, clawFor)` to
  `foliageDrop` instead of `trunk.minY`, or say in the header that the arm assumes claw 0.
- `tools/forest_ground.py` / the `DIMS` probe's `measure` — `foliageDropStuds = if crown then
  math.max(0, trunk.minY - crown.minY) else 0` records the drop UNSIGNED, while the runtime
  `Places.foliageDrop` is signed and claim 6 turns on the sign. So `LarchTree_Var01`'s row reads
  `foliageDropStuds = 0.00` where `TreeGround.sinkFor`'s own header says that template is **-0.10**
  and that the sign is what the task measured. The row is read by nothing in `src/`, so this is
  documentation drift and not behaviour; drop the `math.max(0, ...)` or say in the row comment that
  0.00 means "at or above the foot".
- `src/shared/Places/init.luau` / `TEMPLATE_DIMS.foliageDropStuds` — a new field on all 35 rows that
  nothing in `src/` reads and no case asserts: `grid_ground.spec`'s "every row is a measurement"
  checks `scale`, `heightStuds`, `trunkHalfWidthStuds`, `crownHalfWidthStuds` and `parts`, and not
  this one. Add it there, or mark the field reference-only in the header.
- `src/serverstorage/GridCensus/init.luau` / `FOLIAGE_SINK_STUDS` — the "one number, shared" claim
  rests on a single assignment with no case behind it. The identity case next door asserts
  `rawget(Census, "SINK_STUDS")` and `rawget(Census, "sinkFor")` are nil; it does not assert
  `Census.FOLIAGE_SINK_STUDS == TreeGround.FOLIAGE_SINK_STUDS`, so typing `0.5` back into the
  census would fail nothing. One line in that case closes it.
- `tools/forest_ground.py` / `cmd_dims` — `spread = max((r["highScale"] / ... ) for r in rows if
  r.get("instances"))` raises `ValueError: max() arg is an empty sequence` in a place that holds
  none of the 35 names (the DEV place), instead of the tool's own `fail(...)`. Separately,
  `measure`'s `trunkTallerThanWide` is computed and returned by the probe and used by neither
  `cmd_dims` nor `dims_block`.
- `tools/forest_ground.py` / `cmd_dims` is registered `(cmd_dims, False)`, so `--write` rewrites
  `src/shared/Places/init.luau` without `require_clean`, and the `[dims] ... @ <sha> place=<id>`
  line it prints carries no clean/dirty marker although it is shaped like the harness line that
  does. Print `git_state()[1]` beside the sha.
- `tools/forest_ground.py` / `cmd_apply`'s re-seat, line ~313 — still
  `TreeGround.decide(whole.minY, whole.maxY, claw, grounds)` with no `foliageDrop`, so a hand-run
  `forest_ground.py apply` over the STANDING wood seats it at the full 0.6 and puts the field oaks'
  canopies back under the grass. Outside the dispatch (rule 4) — queue it.
- `tests/server/grid_ground.spec.luau` / "and the mask refuses a wide crown where it passes a
  narrow one" — the search now narrows to `frontageAllowsGroup(plan, group)` but lost the
  `expect(widest ~= nil)` its twin above keeps, so a day when the frontage allows nothing fails on
  `assert(foundX ~= nil, "no point between the road floor and the crown set-back...")` rather than
  on what actually broke.
- `tests/server/tree_ground.spec.luau` / "makes room for a crown that hangs below the trunk" —
  three of the expectations are `line - 0.10` / `line` / `line + 0.10` where `line` is
  `FOLIAGE_SINK_STUDS - FOLIAGE_MARGIN_STUDS`, which is a transcription of `sinkFor`'s own body
  (verdict 278). The hard numbers beside them (0, 0.6, 0.28) and the
  `sinkFor(32.3, 0.10) + 0.10 < FOLIAGE_SINK_STUDS` line carry the case, so this is form and not a
  hole — but those three would survive a sign error in the constant pair.
- `reviews/task-328l/REQUEST.md`, ANSWERED L-093 — says 2c-3's audit "answers `extents` without
  it". With the arm deleted it answers **`part-code`**'s neighbour `part-count` first: the
  synthetic `off` has 2 visible parts against the row's 3, and `auditReason` tests `parts` before
  `extents`. The spec's own comment says "`extents` or `part-count`" and is right; only the
  request's line is narrower than the code.
- `reviews/task-328l/REQUEST.md`, "What I could not verify" — "the audit then quarantines that
  name rather than planting the wrong size" overstates the fail-safe. With 16-125 instances per
  name spanning x1.84, the instance next to a removed median is ~0.5 % away, far inside
  `AUDIT_SCALE_FRACTION` 0.02, so the likely outcome is a silent near-identical substitution, not
  a quarantine. The direction is still safe; the sentence is not what the code does.
- claim 7 / `TASKS.md` — `refused` 6.1 % -> 7.6 % leaves 0.4 points of headroom under the 8 % gate,
  and the stated cause (more offered sites in the roadside band, where the cross-section steps)
  grows with every further set-back reduction. Disclosed honestly; worth a row for whoever plants
  the next cell.
- `GAME_DESIGN.md` — the 328b row still lists the census's shared thresholds as "(`TOLERANCE_STUDS`,
  `sinkFor`, `junctionY`)"; since this change `FOLIAGE_SINK_STUDS` is a fourth. The 328f row below
  it was updated correctly and no longer carries "cannot disagree by construction" (328f-note (b)).

---
REVIEWER verdict on commit `c49c72efb10ce1cd3ef54b9cf390c0a5e3efe9f9` (round 1) · 2026-11-03 03:33 UTC · session cost $3.78, 40 turns · written by tools/agents.py
