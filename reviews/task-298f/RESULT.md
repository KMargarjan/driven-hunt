PASS (items 1, 2, 3, 4, 5, 6, 7, 8, 9 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: **nothing in Karen's place has been
seen.** No Forest Test session was run, no screenshot of a range beside her lodge exists, and the
forest arm of `RangeBoot` (`ForestTest.groundAt` → `Range.shelfFor` → the `drawn` clones) has never
executed in any run that produced evidence — it cannot, because the harness world is `map:v1`. The
request says so in its own words (*"Nothing in Karen's place was played... The drawn target in her
place (`drawn = true`) is reasoned from `ForestTestBoot`'s own rule for MODEL/CALM/PACE/MOVE, not seen
on screen."*). What IS proven is DEV plus arithmetic over her measured ground: the exit line, the
field, the footprint, the lobby clearance and the owner's sign.

Harness evidence is consistent: `[harness] PASS: 34/34 checks @ 73037ba1... (clean tree) scope=all`
names the request's `Code commit:`, and `paperwork-after-code-commit.txt` says only
`reviews/task-298f/REQUEST.md` changed after it. selene 0/0/0, stylua clean, rojo build exit 0.
Round 3's FAIL FIRST is real and exactly placed: `14d1bf98` is the two cases alone (+73/-11 on
`range.spec`, nothing else) and `73037ba1` is the fix (+10/-2 on `src/shared/Range/init.luau`).

Round 2's two findings are closed, and I checked both by deleting the producer:
- `Range.fieldFor` now writes `exitZ = math.min(nearZ, farZ) - Range.FIELD_EXIT_BEHIND_STUDS` —
  -400 for DEV (bit-for-bit, asserted against the constant) and -3741 for the forest row.
  `Brain:_outcome`'s test is still `position.Z <= field.exitZ` with no direction parameter
  (`src/server/Boar/Brain.luau`), so direction-blind is the only correct shape. Revert the line to
  the signed form and the forest arm of "gives the range a field whose exit is south of the whole
  field -- BOTH rows" goes red at -2816 against -3401, which is the recorded red run.
- "keeps an ORDERED target alive on Karen's field" bites three separate ways: with the signed `exitZ`
  the target at z -3341 despawns `escaped` and `statusOf` is nil (recorded); with `exitZ` removed
  `_outcome` errors; with `downrangeOf` forced to +1 the spawn at z -3341 is 55 studs past
  `bounds.minZ - BOUNDS_SLACK` (-3286) and goes `outOfBounds`. It is the real `Boar.newRuntime`, not
  the file's fake rail, and it steps 90 × 1/30 s.
- Round 1's cases still bite: delete `onGround`/`groundUnder` and the forest arm's
  `math.abs(bottom - lo) < 1e-2` fails on the berm by 11.25 studs (its own corner ground is 136.0
  against a 147.25 anchor read), and `#asked >= 5 * 4` collapses to 1. Delete `state.downrange` and
  the release lands at z -3091 against `position.Z < row.z - DISTANCE_STUDS + 1`.

Also checked and correct: all five owner call sites and both `Build` call sites take the sign
(`grep` of `src` finds no unthreaded caller); `Range.shelfFor` → `Build.shelfAt` gives DEV `row.y or 0`
unchanged, so `field.groundY` is the shelf `Build` measured and B2's queued note (g) is closed;
`world.groundAt = groundAt` is nil in DEV and `Boar.defaultWorld` sets no default, so DEV is
byte-identical; `ForestTest.groundAt` really is on the SHARED module (`src/shared/ForestTest/init.luau`),
so the forest arm would not warn-and-return; `Weapon.setStandProvider` does `return previous`, so
design 7.4's claim about `installOver` holds; `RANGE` is `default = false` with `expires` 2026-11-17
and `RangeBoot` reads it at its boundary, so none of this reaches Karen until the flag flips; and the
568 lines removed from `ESCALATE.md` are in `backups/ESCALATE-293-2026-10-27.md` at the same blob hash
(`7467511e`), which is rule 7 met exactly.

## Notes (non-blocking)
- `src/shared/Range/init.luau`, the paragraph above `FIELD_SLACK_STUDS` — now stale and contradicts
  the `exitZ` line six lines below it: *"an `exitZ` far BEHIND the firing line"*. For the forest row
  the exit is 400 studs DOWNRANGE of the lane. Rewrite it to the sentence the `exitZ` key carries.
- `docs/design/shooting-range.md` §5, the `config.MODEL`, `KINDS`, `PACE`, `MOVE` row — *"the clones
  the root already built. `ForestTestBoot` reuses its own `model`/`calm`/`pace`/`move` locals;
  `MatchBoot` passes the DEV defaults"* is false against what shipped: `RangeBoot` builds its own
  clones off `Boar.CONFIG` when `row.drawn == true`, and `MatchBoot` is no longer a root at all. This
  is the one design row the `drawn` field should have changed and did not.
- `src/server/RangeBoot.server.luau`, the `drawn` block's comment — self-contradictory: *"MODEL,
  CALM, PACE and MOVE are replaced WHOLESALE by `newRuntime` (only MODEL, SENSE and KINDS merge key
  by key)"*. Harmless, because a full clone is passed either way.
- `tests/server/range.spec.luau`, the exit case — `ipairs({ DEV_ROW, FOREST_ROW })` TRUNCATES to one
  element if `RangeData.anchorFor("forest-test")` ever returns nil, so deleting the row makes the
  forest arm vanish silently rather than go red (the suite still catches it, in the row case). One
  `expect(FOREST_ROW).to.be.ok()` at file scope, or loop over the world NAMES, closes it.
- `tests/server/range.spec.luau`, "both worlds" case — `expect(lane.Z - anchor.Z).to.equal(case.dir *
  LAYOUT.DISTANCE_STUDS)` where `lane = RangeData.laneCentre(anchor, LAYOUT, case.dir)` is still a
  transcription of `laneCentre`'s body with the same `case.dir` fed in (round 1 and 2 note, verdict
  278). The berm assertion beside it is the one that reads a built part, which is why the case is
  sound; the transcription line adds nothing.
- `src/server/Range/Build.luau` / `groundUnder` — five samples find the true low/high only for a
  PLANAR reader, and `slopedGround` is planar, so the spec's 9 x 9 scan agrees with it by
  construction. On real terrain a dip inside the berm's 160 x 6 footprint that is not at a corner
  leaves that part floating over the dip. Still open from round 2: say so in the header or queue a
  sweep count.
- `ForestTest.GROUND_IGNORE` is `table.freeze({ "OurForest", "Foliage", "Boars", "DrivePlaces" })` and
  does not name `Range.FOLDER_NAME`, so once the range is parented the world's ONE ground reader can
  answer with the mat or the berm — which would lay a carcass on top of the berm, and would refuse a
  stand outright if any marker column ever falls inside x 2570..2730 / z -3356..-3212
  (`Markers.GROUND_TOLERANCE_STUDS` is 1). Not a defect today: `Build` measures before
  `folder.Parent = parent`, and the b6-anchor measurement reports 0 non-terrain hits over that
  footprint in Play. `places.spec`'s rule for `Places.FOLDER` is the shape to copy. Queue it.
- `tests/server/range.spec.luau`, claim 7's case — the downrange half cannot fail on the SIGN: the
  Gather pad is ~139 studs off the line, so `aim = Vector3.new(0, 0, dir)` answers false for either
  value of `dir`. The Builder names this himself. The falsifiable half is "turn round and the same man
  refuses the shot", which is a real assertion about `Match.lineUnsafeFor`.
- `src/shared/Range/init.luau` footprint — the berm is 160 wide centred on x 2650, so it spans
  `MEASURED.minX`..`MEASURED.maxX` exactly and `expect(box.minX >= MEASURED.minX)` passes with zero
  margin on both edges. One stud of x drift reds it. Already queued; repeated because the sampled
  rectangle, not the parts, is what should grow.
- `reviews/task-298f/REQUEST.md` — *"Round 3 is authorised by the Director, 2026-10-28 01:50 UTC ...
  Recorded in `ESCALATE.md` under this task's entry"* overstates what the file holds: `ESCALATE.md`'s
  01:50 entry is the Builder ASKING (*"What I need from the Director: One authorised round 3"*); the
  Director's word is not in the repo. The dispatch of this run says round 3 of max 3, so the round
  stands either way.
- `TASKS.md`, the 298 row — still ends *"ROUND 2 RETURNED FINDINGS -> `ESCALATE.md` 2026-10-28 01:50,
  DO NOT MERGE"* and lists both round-2 findings as open. Stale as of `73037ba1`.
- `docs/design/shooting-range.md` §5 — *"a wounded target at a range therefore flees DOWNRANGE into
  the berm (`Brain:_flee` heads for `exitZ`)"* is the berm's COLLISION, not the exit line: `exitZ`
  -3741 is 340 studs outside `bounds.minZ` -3401, so an animal that goes round the berm (the berm
  spans x 2570..2730 inside bounds 2550..2750) is removed as `outOfBounds` rather than `escaped`.
  Same shape DEV has always had; worth one honest sentence rather than a code change.
- `src/server/Range/init.luau` / `Range.stop` — still leaves `state.downrange` at the stopped range's
  sign; harmless because `start` always assigns it first. Already queued.

---
REVIEWER verdict on commit `6e95b466b657516b78581af66ae47670ca14339c` (round 3) · 2026-10-28 02:12 UTC · session cost $4.23, 41 turns · written by tools/agents.py
