# Task 321 -- one pass, one animal

Task: 321
Round: 3
Base: d7ae1929 (main)
Code commit: 814cb8ca98fc2f8e0f28fd132d279b31b276983b

`[harness] PASS: 34/34 checks @ 814cb8ca98fc2f8e0f28fd132d279b31b276983b (clean tree) scope=all`

`[harness2] PASS: 36/36 checks @ 814cb8ca98fc2f8e0f28fd132d279b31b276983b (clean tree)`

Both runs taken by the Builder with DEV the ONLY Studio (Karen's Forest Test closed by the Director
for this round). `test2` by the F7 route in `driven-hunt-runs/run-test2.sh`, no human click. Zero
failures and zero errors in either: server 2604 passed / 0 failed / 0 errors, shooter 666, driver 660.
Not one of the intermittent specs the dispatch named fired in either run.

**Round 3 fixes ALL THREE numbered blocking findings of the round-2 verdict, not two.** The dispatch
said "the TWO blocking findings" and carried only (1) and (2). Finding (3) is numbered and blocking in
`RESULT.md`, this is the last authorised round, and its fix is two lines plus one assertion -- so it is
done here rather than left to fail the round. Flagged to the Director in the report.

## What changed

Findings (1) and (2) are ONE defect, and are fixed once at the root rather than twice at the sites.
`clearId` nils `carcassAt` whenever it takes the carcass, so any caller that wrote the clock first lost
it. `src/server/Range/init.luau` now has one writer pair for the `carcassId`/`carcassAt` slot --
`setCarcass` and `dropCarcass` -- and every call site goes through it.

## Claims

1. **A SECOND KILL AT ONE STATION INSIDE `CARCASS_SECONDS` CLEARS CORPSE A AND KEEPS CORPSE B'S OWN
   CLOCK (finding 1).** `scan`'s kill branch no longer writes `trial.carcassAt = now` before the clear;
   it calls `setCarcass(trial, trial.targetId, now)`, which drops the previous corpse FIRST and then
   installs the pair. Verify: `setCarcass` in `src/server/Range/init.luau`, and the kill branch in
   `scan`. Case: `tests/server/range.spec.luau`
   `it("clears the previous corpse on a second kill and keeps the NEW one's own clock")`.
2. **THAT CASE IS RED AT THE ROUND-2 CODE COMMIT.** It asserts `trial.carcassAt` is set after the
   second kill and that corpse B is gone `CARCASS_SECONDS` after its OWN kill with
   `trial.carcassId == nil`. At `64edb761` `carcassAt` is nil there and the corpse is never retired.
   Verify: `git stash` the fix to `src/server/Range/init.luau` only and the case fails; the ordering is
   the whole bite.
3. **LEAVE WITH A FRESH KILL ON THE LANE TAKES THE CORPSE (finding 2).** `Range.onRequest`'s `leave`
   arm calls `dropCarcass(trial, "range leave")` instead of `trial.carcassAt = nil`. Verify: the
   `leave` arm in `Range.onRequest`. Case: `it("takes his carcass with him when he leaves on a kill")`
   -- kill, then `leave` on the next tick, asserting `carcassId`, `carcassAt`, the body in the fake's
   table and `#Range.mineIdsFor(man)` all gone IN THE ARM, not a tick later. That is 319's leave: no
   animal and no carcass left. Red at `64edb761`, where only the clock was nilled.
4. **NO CORPSE OUTLIVES ITS CLOCK, AT ANY CALL SITE PRESENT OR FUTURE.** `scan`'s retire block now
   reads a MISSING `carcassAt` as expired (`carcassAt == nil or now - carcassAt >= CARCASS_SECONDS`),
   so a slot that loses its clock costs one tick instead of the session. This is the third call site
   the one guard covers, and it is why findings (1) and (2) cannot drift apart.
   Verify: the carcass block in `scan`.
5. **THE INVARIANT OVER A SEQUENCE, NOT ONE PATH.**
   `it("holds no carcass older than CARCASS_SECONDS + a tick, after any sequence of kills and leaves")`
   kills at all six stations three times over, kills again inside the hold, leaves on a kill and
   re-enters, and sweeps every trial's carcass age at every stage -- a `carcassId` with no `carcassAt`
   counted as `math.huge`, not skipped. Measured: **18 kills, 1 leave, oldest carcass 1.83 s against
   the 3.10 s bound** (`TestKit.note`, `range 321 r3`, in the harness output above).
6. **THE TRUNK'S NAME IS THE ID, AS THE GAME WRITES IT (finding 3).** `newFakeBoars().spawn` now sets
   `trunk.Name = id`, which is `Boar.Body.create`'s own `part.Name = id` and what the client's
   `Mask.isMine` resolves (`state.mineIds[trunk.Name]`). The `FakeTrunk_<id>` assertion the verdict
   called false is gone. Verify: `grep FakeTrunk tests/ src/` returns only a comment naming the defect.
7. **AND THE SHIPPED INVARIANT IS PINNED WHERE IT LIVES.**
   `it("names his animal's id on the wire, and after a kill both ids")` now also builds a REAL body
   through `Boar.Body.create` and asserts its part's `Name` equals the id it was given. Verify: delete
   `part.Name = id` in `src/server/Boar/Body.luau` and that assertion goes red -- which nothing in
   `tests/` did before (the verdict's own `grep`).
8. **THE SHOT-ISOLATION CASE STILL PROVES "THE TRUNK AND NEVER A ZONE PART".** With the rename it
   asserts `fake.animals[entry.Name] ~= nil` -- the entry IS one of the animals, which a `Zone` child
   can never satisfy -- instead of a string prefix. Verify: the trunk loop in `Range.ignoredFor`'s
   case in `tests/server/range.spec.luau`.
9. **NOTHING ELSE IN `src/` CHANGED.** `git diff d7ae1929..HEAD -- src/` beyond round 1 is the carcass
   slot and the leave arm only. Round 1's pass loop, the mask fix and the hit path are untouched.
10. **LINT, FORMAT AND BOTH SELFTESTS CLEAN.** `selene src`, `selene --config tests/selene.toml tests`,
    `stylua --check src tests`, `python tools/studio_mcp.py selftest`, `python tools/agents.py selftest`.

## What could not be verified

- **RULE 5 / STEP 3: NOTHING IN THIS ROUND WAS SEEN IN KAREN'S PLACE.** The Director's dispatch did
  not require a Forest Test proof this round ("server bookkeeping; the specs are the proof") and closed
  her Studio for it, so no frame and no live reading exists at this code commit. The round-2 verdict's
  standing rule-5 note therefore still stands in full: findings (1), (2) and (3) are **NOT PROVEN** in
  her place. The pass loop's own live measurement remains round 1's, at `160c25ae`.
- The first run of `test` at `c6a4bed3` failed 3 / errored 3. All six were my own three new cases
  cascading from ONE fault in the invariant case: the `leave`/`go` pair was 0.133 s apart against the
  0.15 s `REQUEST_MIN_INTERVAL`, so the re-enter was rate-limited and the aborted case left the range
  started, which refused the next two cases' `startRange`. Fixed in `814cb8ca` (spec only, no `src/`
  change). Disclosed rather than re-run quietly.
- Round-2's non-blocking notes are NOT fixed here, per the dispatch: they stay queued as 321a, the
  stale `MAX_TARGETS` row in `docs/design/shooting-range.md` among them.

ANSWERED: L-136 the dispatch's intermittent specs are named and none fired; the one FAIL run is
disclosed above with its commit and its cause, which was mine and not an intermittent.
ANSWERED: L-127 every claim above is MET or carries its own NOT PROVEN; rule 5 is NOT PROVEN per item.
ANSWERED: L-162 every live proof in this round is at the code commit `814cb8ca`, and there is none
other than the two harness lines.
ANSWERED: L-131 all three numbered blocking findings are fixed, not the dispatch's two; stated above.
ANSWERED: L-031 findings (1) and (2) are fixed at the shared root cause with one guard both call sites
and the retire block use, not as two per-site patches.
ANSWERED: L-095 `<desktop>/driven-hunt-294` does exist on disk; the optional Forest Test route was not
taken because the dispatch did not require it this round.
