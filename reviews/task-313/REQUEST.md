# Task 313: solo on the whole range

Task: 313
Round: 2
Base: c818d374ce4a4be40a2997889b8c305ce1a6d30c (main)
Code commit: cbb2f3d63d3918b0180a56ec2f4b65ee80ee1d54

```
[harness] PASS: 34/34 checks @ cbb2f3d63d3918b0180a56ec2f4b65ee80ee1d54 (clean tree) scope=all
[harness2] PASS: 36/36 checks @ cbb2f3d63d3918b0180a56ec2f4b65ee80ee1d54 (clean tree)
```

**Director, 2026-10-30 ~21:00 UTC:** both lines run by the Director at `cbb2f3d6`, which differs from
the Builder's tested `a5f46bbd` only in paperwork (`TASKS.md`, this file); the Forest Test Studio was
closed for the run (Karen asleep, FT in Edit). The Builder's own line was
`[harness] PASS: 34/34 checks @ a5f46bbd77e30a5d51a2413be4b7b76aa67f3a29 (clean tree) scope=all`.
No spec failed in either Director run.

**ROUND 2 IS SPEC-ONLY.** The one changed file is `tests/server/range.spec.luau`; nothing under
`src/`, `tools/` or `docs/` moved (`git diff --name-only c7c18ea3..a5f46bbd`). Round 1's verdict was
FINDINGS (`reviews/task-313/RESULT.md`); its two blocking items are claims 1-4 below. Its
non-blocking notes are NOT addressed in this round and are queued in `TASKS.md` row 313a, item by
item, including the RUN board reading (313a item (o)).

## Claims

**1. The flag-off case no longer compares a value with itself** (finding 1, the span half).
`it("is bit-for-bit the shipped window with the flag off")` asserts the OFF span against
`RangeData.matPosition(AT, spot, LAYOUT).X +- LAYOUT.WINDOW_STUDS / 2`, written out from the dials,
and no longer against `RangeData.windowSpanFor` -- the function `sightSpanFor`'s off branch
delegates to. Verify: read the case in `tests/server/range.spec.luau`; `windowSpanFor` does not
appear in it. FAIL FIRST, run: with `sightSpanFor`'s `if wide ~= true then` forced to `if false
then`, the harness reds at that case's `expect(hi).to.equal(matX + half)`
(`range.spec:5513`, *Expected value "18", got "53.06666666666666"*).

**2. ...and the OFF LEG is asserted against the shipped arithmetic** (finding 1, the leg half).
The same case computes `want = laneCentre(AT, LAYOUT, dir, spot, LAYOUT.DISTANCE_STUDS).X +-
RangeData.laneLength(LAYOUT) / 2` and asserts BOTH `Range.laneEnds` (the shipped name) and
`Range.laneEndsFor(..., false)` against it, over 6 stations x 4 legs x 2 directions. The old pair
(`laneEnds` against `laneEndsFor(..., false)`) was one value through two names. Verify: the case
holds no comparison whose two sides are the same engine call. FAIL FIRST, run: with the apron
dropped from `laneEndsFor` (`local x = if east then hi else lo`), it reds at
`expect(shipped.X).to.equal(want)` (`range.spec:5526`, *Expected "38", got "18"*).

**3. The server side carries `solo` through the shipped door onto the wire** (finding 2, design 14.1
item 11). New case `it("carries solo through Range.start onto the record: alone, and the wide
window")` in the new describe `the span: the server's own door (task 313)`. `startRange` gained a
`solo` seam passed straight into `Range.start`; nil is the shipped behaviour, so every pre-313 case
is unchanged. The case runs BOTH states by parameter and reads `Range.recordOf(man)` -- the wire,
not `maskFor` -- asserting: `alone == true` on a mat with `solo = true`, `alone == false` with
`solo = false`, and `alone == false` plus `window == nil` and `mine == nil` after his
`HumanoidRootPart` moves 600 studs off the mat WITH solo still on. With solo on the window equals
`sightSpanFor(..., true)` and is wider than `1.9 * WINDOW_STUDS`; with it off it equals
`matPosition(...).X +- WINDOW_STUDS / 2`, written out (claim 1's rule applied again). FAIL FIRST,
two runs: hard-coding `local alone = false` in `maskFor` reds at
`expect(record.alone).to.equal(solo)` (`range.spec:5684`, *Expected "true", got "false"*); passing
`false` instead of `state.solo` to `sightSpanFor` in `maskFor` reds at
`expect(record.window.minX).to.equal(lo)` (`range.spec:5692`, *Expected "1209.3333333333333", got
"1254"*).

**4. The station edge pushes, and is counted** (finding 2, design 14.1 item 9 / design 7.3's own
sentence). New case `it("pushes station 4's trunk when he walks from 2 to 4, with no request")`:
one fake player, `solo = false` so the window is deterministic whatever the flag's default is, one
pick at station 2 to make his record, then his root part is moved onto station 4's mat and
`advance` runs -- no request of any kind. Asserted: `Range.stats().spanPushes` is exactly one
higher, a payload arrived on the fake `RangeBoard` remote after the move, its `record.mine` IS
`fake.at(4).root` and is NOT station 2's trunk, and its `record.window` is station 4's. FAIL FIRST,
run: deleting the station-edge block in `occupancy` reds at
`expect(Range.stats().spanPushes).to.equal(pushes + 1)` (`range.spec:5744`, *Expected "1", got
"0"*).

**5. Nothing else changed, and the suite did not shrink.** `git diff --stat c7c18ea3..a5f46bbd` is
`tests/server/range.spec.luau | 132 +, 10 -`. Server specs 2583 -> 2586 passed, 0 failed, 77 spec
files; client 664 passed, 31 files. `selene --config tests/selene.toml tests`, `stylua --check src
tests`, `python tools/studio_mcp.py selftest` and `python tools/agents.py selftest` all pass
(rule G); `range.spec` was already in `SCOPE_SPECS["range"]`, so no scope row was needed.

## What could not be verified

- **The `[harness2]` line, and the full `test` at the branch head: the Director's** (above). Karen's
  Studio was left alone.
- **RULE 5 IS STILL NOT MET and this round does not change that.** Nothing was seen in Karen's
  place; nobody has looked at an invisible player. Round 1's live numbers are DEV ONLY and belong to
  round 1's commit, not this one (L-162). Core items 1, 5, 7, 11 and 12 remain **NOT PROVEN** -- the
  live proofs on the wide range are the Director's after merge.
- **The RUN board gap is reported, not fixed** (313a item (o)): the board prints
  `trial.lastCrossingSeconds`, the seconds between the first 10 Hz scan tick that saw the animal's X
  inside the span and the first that saw it outside on the same leg (`timeWindow`), so it measures
  the ANIMAL; 4.18 s is `100.34 / PACE.RUN_SPEED 24`, the ordered setpoint with no ramp, and
  `Brain` reaches a setpoint through `config.ACCEL * dt`. The 9.13 s the board printed against that
  4.18 s therefore says the boar does **not** hold RUN pace across the wide span. Not changed in
  this round, and no code was touched to chase it.
