PASS (items 1, 2, 3, 4, 6, 10 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: NOTHING in this change has been
seen in Karen's place, and the request says so -- `Range.ANCHORS` has one row, `["map:v1"]`, and
`range.spec` asserts `RangeData.anchorFor("forest-test") == nil`, so her place builds no range until
B6. What WAS seen: a DEV frame, described (`.screenshots/298b2-lane-eye.png`, flag `RANGE` on, camera
at the mat (1200, 4, 0) looking down the lane -- plate, berm, both screens clear of the lane ends, the
target mid-crossing against a server probe `Boar1 at 1177.0,1.5,120.7 dx=-23.0`), and five DEV dx
probes (-25.0, +17.0, +17.9, -23.9, -12.0) that show a real body crossing AND reversing. What was
NOT: items 1, 2, 3, 4, 6 and 10 in her place, and items 2, 3, 4 and 10 anywhere but against
`range.spec`'s fake rail. Items 5, 7, 8 and 9 are structural, verified against the repo, and not core.

Verified against the repo, no action: no `.CFrame =` / `Velocity` write anywhere in `src/server/Range/`
(claim 5, TARGET 5); `ForestTest.paceSpeed` is one delegating line and `Boar` is already required at
`src/server/ForestTest/init.luau`:43, no forest `paceMix` row carries `"stand"`, `forest_stand.spec`
untouched (claim 7); `Flags.DEFAULTS` holds 19 rows against `MAX_FLAGS = 19`, `RANGE` `default = false`,
`expires = "2026-11-17"` = 21 days from born (claim 9); `test2` N/A is true -- none of the 13 changed
paths matches a `TWO_PLAYER_PATHS` prefix, and `tools/studio_mcp.py` is excluded by that list's own
comment; the harness line names the request's `Code commit:` 6ece3b7d with "(clean tree)",
`paperwork-after-code-commit.txt` says only `REQUEST.md` followed it, and `c0c58932`'s fixes are an
ancestor of it; selene/stylua/rojo clean. Producer deletion reds the cases that carry the claims:
remove `order`'s flip branch and `flips`/`directions.west` stay 0; remove `timeWindow` and
`expect(measured).to.be.ok()` dies; remove the STAND branch and `directions.middle` is nil while
`held == 180` fails; remove the carcass branch and `fake.clears == 1` fails; replace `screenPosition`
with `laneEnds` and the corridor case reds (screen at x 1240, |dx| 40 against `half + 5 + body` = 46.6).

## Notes (non-blocking)

- `src/server/Range/init.luau`, `Range.step` -- the lane scans at **8.57 Hz, not the configured
  `STEP_HZ` 10**, and the request's own counter proves it: `advance(fake, clock, 40)` runs
  `math.floor(40 / (1/60))` = 2400 frames, and claim 1's note reads `east 179, west 162 orders` = 341.
  At six frames per scan that would be 399 (400 scans, one of them the release scan); 341 is
  2400 / **7** = 342 scans minus one. The cause is `state.acc = 0` where it should be
  `state.acc -= period`: the double for `1/60` is below 1/60, so six of them fall short of the double
  for `0.1` and the seventh frame pays for it, discarding the remainder each time. Consequences, all
  cosmetic: claim 2's *"measured off the target's own position samples at `STEP_HZ` 10"* and the spec's
  *"quantised to one scan (1 / STEP_HZ = 0.1 s), which is 6 % of the fastest crossing"* are both wrong
  (0.1167 s, 7.0 %, still inside `CROSSING_TOLERANCE` 0.10), and design TARGET 7's *"`STEP_HZ` 10"*
  reads 8.57. It is a note and not a finding for two reasons: `LINE.ORDER_SECONDS` is 0.6, so nothing
  stutters, and `Lobby.step`'s cited precedent (`if now - lastScan < 1 / cfg.SCAN_HZ then return end`)
  drifts identically. Round 1's note that it is *"exact at dt = 1/60 (6 frames = 0.1 s exactly)"* is
  the premise that was wrong.
- `tests/server/range.spec.luau`, "crosses the lane and FLIPS direction at the end, both ways" -- the
  TARGET 4 line `expect(math.abs(animal.position.Z - centre.Z) <= 2).to.equal(true)`, under the comment
  *"The target stayed ON the lane: inside the apron in x, and within 2 studs of the lane in z"*, cannot
  fail. `fake.advance` builds `local to = Vector3.new(animal.order.X - animal.position.X, 0,
  animal.order.Z - animal.position.Z)`, every point `order` issues has `Z == laneCentre(anchor).Z`, and
  `release` spawns at `laneEnds`, whose Z is the same -- so the rail's z IS `centre.Z` to the bit and
  the rail holds +-0. The request discloses the live reading that fails it (z 120.0 .. 129.0), which is
  why this is a note; it reads as evidence for a target the live world misses, so delete both that line
  and the x line (also unviolable: the rail stops inside `ARRIVE_STUDS` of a point on the lane) or move
  them to B4's live spec. Two smaller things in the same disclosure: z 120.0 .. 129.0 about a lane at
  z 125 is -5.0 / +4.0, not the stated "+-4.0 studs".
- `reviews/task-298/REQUEST.md`, the rule 5 paragraph -- **LEFT or RIGHT**. From the mat at
  (1200, 4, 0) *"looking down the lane"* the look is +Z, so the camera's `RightVector` is -X
  (`X = Y x Z`, `Z = -look`), and the silhouette at x = 1177 (`dx=-23.0`) is on the frame's RIGHT. The
  rest of the description checks out against the probe (z 120.7 is the disclosed z wander; y 1.5 is a
  3-stud body's half-height on a shelf at 0; the plate, berm and both screens are what `Build` parents).
  Say which side it is, so the frame can be matched to the numbers by someone who has it.
- `reviews/task-298/REQUEST.md`, FAIL FIRST -- *"the three cases added since (freeze, per-run counters,
  the re-release rise) red against `c74d6f92`'s own code"* overstates by one. The freeze case reds there
  (`table.isfrozen(RangeData.LAYOUT)` was false) and "counts one run" reds there (the counters were
  cumulative, so the second start could not read 0), but the re-release **rise** does not: at
  `c74d6f92` the release path worked and the counters only climbed, so
  `expect(Range.stats().flips > flipsAfterRelease)` passes against that code. It is a strengthening of
  a line that could not fail, not a case for a defect -- what it reds against is deleting `order`'s
  flip branch, which is the deletion that matters and which it does catch.
- `tests/server/range.spec.luau`, "spawns a hind with the deer's own zones" -- the case builds the
  range's world INLINE (`world.folderName = "RangeTargets"`, empty `threats`, the `LINE` clone with
  `ENABLED = true`, `SENSE = { ENABLED = false }`, `KINDS = { ENABLED = true }`,
  `maxBoars = Range.CONFIG.MAX_TARGETS`), which is `src/server/RangeBoot.server.luau`'s block copied
  key for key. So claim 10's *"the range's own runtime"* is the spec's copy of it, and the case passes
  with `RangeBoot.server.luau` deleted: the two can drift and nothing reds. One
  `Range.worldFor(anchor, layout)` in the shared module, read by the boot and by the case, would make
  this assert the world the game ships.
- `src/server/Range/init.luau`, `Range.setPace` / `order` -- STAND publishes a speed it is not using.
  `setPace(spot, "stand")` writes `trial.speedStudsPerSecond = paceSpeed(pace)` = 0 (correct, and
  `crossingSeconds` answers `math.huge` for it), while `order`'s STAND branch issues
  `paceSpeed(RangeData.WORD.WALK)` = 4.5. `Range.trialOf` hands both out, so B4's board reads
  0 studs/s for a target walking to the middle at 4.5. Publish the issued speed, or name the field
  for what it is.
- `tests/server/range.spec.luau`, "builds nothing inside the lane the target walks" -- one line of it
  is a transcription of the function under test and proves nothing on its own:
  `expect(math.abs(screen.X - RangeData.laneEnds(anchor, LAYOUT, leg).X)).to.equal(LAYOUT.SCREEN.size.X
  / 2 + LAYOUT.SCREEN.beyondStuds)` restates `screenPosition`'s own `local beyond = layout.SCREEN.size.X
  / 2 + layout.SCREEN.beyondStuds`. The case is carried by `#blocking == 0` and by
  `math.abs(screen.X - centre.X) > half`, which do bite; the transcription can go.
- `tests/server/range.spec.luau`, header -- *"Nothing here touches `Workspace`, and two cases assert
  exactly that"* is contradicted by the last case, which writes `parent.Name = "RangeDeerSpec";
  parent.Parent = Workspace` with its own stated reason (`Body.create` calls the Network Ownership API).
  Name the exception in the header.
- `docs/design/shooting-range.md` section 4.1 still carries `SCREEN | 2 parts, 10 x 8 x 1, at
  `+-(WINDOW/2 + APRON)``, the row the measured fix in claim 6 replaced. `docs/design/` is the
  Architect's, the deviation is written into `Range.LAYOUT` and stated in the request, and
  `RangeBoot`'s header already queues the section 3 deviation for B6's ratification -- named here only
  so both deviations are ratified together.

---
REVIEWER verdict on commit `74824f0a44b74137f5abbe5659b62ddc08fef894` (round 2) · 2026-10-27 20:49 UTC · session cost $4.47, 46 turns · written by tools/agents.py
