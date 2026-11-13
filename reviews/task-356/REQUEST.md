# Task 356 -- the half-second stall when a wave releases

Task: 356
Round: 3
Base: fc2f99ba10de470ced7282dea1b44cc50f1a8ec8 (`main`)
Code commit: 14435f2ad7c15c6b5d4e91ae071132c81a551015

```
[harness] PASS: 34/34 checks @ 14435f2ad7c15c6b5d4e91ae071132c81a551015 (clean tree) scope=all
```

`test2` is **N/A**: nothing in `TWO_PLAYER_PATHS` is touched (`src/server/ForestTest/`,
`src/server/ForestTestBoot.server.luau`, `tests/server/forest_placement.spec.luau`, `reviews/`,
`docs/`, `backups/` -- no `Match/`, no `Drive/`, no client role spec).

## WHAT THIS TASK IS

**The dispatch's premise is refuted and the Director has ACCEPTED that** (`ESCALATE.md`, 2026-11-13
03:35 UTC, round 3 authorised, the Reviewer's option (b)). No stall fix is written. What ships is an
instrument -- the release bill and the per-frame charge -- plus the measurements that refute
*"569.3 ms in ONE frame"*, and the spec cases that fail if a later task breaks that instrument.
Round 3 does exactly what round 2's finding asked for and nothing else.

## CLAIMS

1. **The dead second read is gone.** `ForestTestBoot.server.luau`: the charge is `if releasingBefore
   then`, and the depth is read **once**, at the top of the Heartbeat connection. Verify:
   `grep -n "releasing()" src/server/ForestTestBoot.server.luau` -- one hit, the `releasingBefore`
   assignment above `ForestTest.step`. The comment that claimed "READ BEFORE AND AFTER ... AND OR-ED"
   is deleted and replaced by what the charge really means.
2. **`MEASUREMENTS.md` 2(b) and 3a now say what the in-release column holds**: the purely-yielding
   frames; a release's **start** frame (depth was 0 when the charge was read) and the frame whose
   backward-looking `dt` covers its **resumed** `order`/`spawn`/`files` Lua are in `hb-elsewhere`;
   round 2's or-ed read is named as the no-op it was. 3a also says both columns are the same
   instrument, so the comparison is like for like. Verify: read 2(b)'s bold paragraph and 3a's first
   paragraph. **No claim here says the charge was made stricter.**
3. **The refutation's two legs are untouched by this round.** (a) `releaseCount.ticks = stepTicks -
   releaseEntryTick` counts the Heartbeats a `releaseLine` spanned: `FRAMES=24/27/43/44` against a
   claimed single frame. (b) In-release mean 24.2 ms over 254 frames against elsewhere 24.8 ms over
   13,666, worst in-release frame 49.3 ms against 1,399.7 ms elsewhere (the lobby's join).
   Verify: `MEASUREMENTS.md` 2(a), 2(b), 3a; `git diff fc2f99ba..HEAD -- src/server/ForestTest/init.luau`
   shows no change to either counter.
4. **The depth cannot be poisoned by a raise.** `ForestTest.step` and `ForestTest.stagedLine` call
   `releaseLine` through `pcall`, decrement, then `error(..., 0)` -- the raise still reaches the
   caller, so nothing else moves. New case `it("brings the depth back down when the release RAISES")`
   asserts the raise propagates AND `Forest.releasing() == false` after it.
   **FAIL FIRST, measured** (`<runs-dir>/356r3-failfirst.txt`, that case's own `expect`):
   ```
   [tests:server] FAIL: 2976 passed, 1 failed, 0 skipped, 1 errors, 83 spec files
   TestService: ... Expected value "false" (boolean), got "true" (boolean) instead
   ServerStorage.Tests.forest_placement.spec:1931
   ```
   with the `pcall` in `step` replaced by the plain call and nothing else changed. Exactly one case
   failed.
5. **One case was reading the bill's format floor, and now reads real work.** `it("times the sections
   it really ran, and charges the call to `releasing()` only while it runs")` sums `%.1f` pairs; with
   the pathfinder stubbed every section is under 0.05 ms, so the sum can print 0 -- it read 0.400 ms
   and passed, then 0 and failed, at the same tree (`MEASUREMENTS.md` 7). The spec's own
   `computeRouteVia` patch now burns 1 ms, so `releaseProf.routes` is a measured millisecond: the
   harness note reads `the sections billed 1.000 ms ... (13001 spin(s) in `routes`)`. The timer is
   still the one under test, so the case still dies with the nine `releaseProf.<section> =` lines
   deleted. Verify: the note in `<runs-dir>/356r3-harness2.txt`, and the patch in `oneRelease`.
6. **The shape case establishes its own state.** `it("names every section, the pathfinder's counts
   and the frames the call spanned")` calls `oneRelease(0)` and reads that bill, so it no longer
   depends on the case before it having driven a release.
7. **Nothing is left in module state for the next spec file.** `it("keeps the WORST call and not the
   last one")` ends with `Forest.releaseReset()`, so `releaseWorstMs = 987654` does not outlive it.
8. **The misplaced comment is moved, not duplicated.** "WORST FRAME, THEN EVERY SECTION'S OWN
   max/total..." now sits above `ForestTest.releaseBill`, which is what it describes;
   `ForestTest.releasing` keeps only its own two lines. Verify: read both in
   `src/server/ForestTest/init.luau`.
9. **The `spawns` comment names the count the case produces** (1, from the stub's own handles, as
   that case's harness note says), not 6.
10. **No behaviour outside the instrument changes.** `git diff fc2f99ba..HEAD -- src/server/` is: the
    charge's single read, the two `pcall`+re-raise pairs, the moved comment, and round 1-2's
    instrument. One deliberate instrument difference from round 2: a frame on which a *different*,
    later release is in flight while an earlier handler finishes is now charged `hb-elsewhere` -- it
    was the only case the or could ever make true, and charging one frame's `dt` by another frame's
    state is what the finding called the opposite of the intent.

## WHAT I COULD NOT VERIFY

- **Rule 5: nothing in this task was seen in Karen's place.** Items 4 and 5 of the dispatch (*"no
  hitch when a wave releases"*) are **NOT PROVEN on screen**: their stand-ins are claims 3's numbers,
  read off `ServerStorage.DHReleaseBill` in headless Play. The dispatch for round 3 says no Forest
  Test proof is needed (no behaviour change) and her Forest Test was not opened.
- **The 1,399.7 ms lobby join frame and `Runtime:spawn`'s 23.2 ms are measured and escalated, not
  fixed** (`MEASUREMENTS.md` 5, `ESCALATE.md`). They are other owners'.
- **`MEASUREMENTS.md` 4a's bound is checked by arithmetic, not enforced by a guard** -- said there
  rather than implied.
