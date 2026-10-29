PASS (items 8, 9, 10 NOT PROVEN)

Round 1 finding 1 is fixed as claimed, verified by reading, not by the request's word:
`src/server/Range/init.luau` adds `serverNow()` (`state.serverTime` or
`Workspace:GetServerTimeNow()`), `Range.ignoredFor` now does `at = serverNow() - rewindSeconds`,
`Range.start` takes `seams.serverTime` and `Range.stop` clears it. The shipped wiring agrees with
the ring: `RangeBoot` passes no `serverTime` to `Range.start`, `Boar.defaultWorld` sets no
`world.serverTime` (the only two mentions in `src/server/Boar/init.luau` are the reads at
`Runtime:cframeAt` and `historyAt`), so both sides read the same `Workspace:GetServerTimeNow()`.
Delete-the-producer on claim 5: with `clockNow()` back, `range.spec` → "asks where his animal was at
the instant the rewind tests" goes red at `expect(asked[1]).to.be.near(serverClock.t - 0.2, 1e-6)`
— `newClock` starts at `t = 0` and `advance(fake, clock, 1)` leaves `clock.t = 1.0`, so the owner
clock answers `0.8` against `49999.8`, which is exactly the `0.800000` / `49999.800000` the request
reports; and both FAIL-FIRST runs' `32/34` is the right count, since one red server spec fails both
`[server] status PASS` and `[server] > 0 passed, 0 failed, 0 errors, 0 skipped`. Harness line
`@ 17100e4f20b6ebe1425d2f8d751f0122758bc9da (clean tree)` names the request's `Code commit:`, and
`paperwork-after-code-commit.txt` says only `REQUEST.md`/`RESULT.md` followed it. Claims 8/9/10 each
fail with their producer removed (no marker in the list; `asked[2].rewind` not a number if the hoist
goes; `isolated.instance` would be `his` if `ignore` were not passed to the candidate finder).

## Notes (non-blocking)
- Rule 5, stated so this PASS is not read as rule 5 having been met: NOTHING in this step was seen in
  Karen's place — the request says so itself ("Karen's place: nothing. B8 is her place; this step is
  DEV only"). The isolation evidence is numeric (`DHLastHits` `#2 ... id=Boar11 zone=chest
  dist=105.8` with station 2's body dead on the line 40 studs nearer, plus the rule-L control reading
  nil), and no frame anywhere shows the two staged animals apart; `306b5-shooter-eye.png` and
  `306b5-line2.png` are described, not seen by me. Items 8, 9 and 10 — the shot path — are NOT PROVEN
  in her place.
- `src/shared/Range/init.luau` `windowSpanFor` + the absent `src/client/Range/Mask.luau` (carried
  from round 1, still true) — between B5 and B6 his own target is excluded from his own shot on 40 of
  the lane's 76 studs (`WINDOW_STUDS = 36`, `APRON_STUDS = 20`) while still fully drawn to him. That
  is design §16's own B5→B6 order, not a defect, but any DEV range run before B6 lands will show
  shots passing through a visible target.
- `tests/server/range.spec.luau` → "is counted, and costs under a tenth of a millisecond a call
  (T13)" — the 200-call measurement runs with `fake.pastOf = nil`, so `fake.cframeAt` answers nil and
  the live ring walk (`Runtime:cframeAtId`'s entry scan plus `Boar.sampleAt`) is not inside the
  0.0028 ms. The budget is 100 µs and the walk is over ≤ 6 entries, so there is headroom; the number
  should be read as "the owner's own arithmetic", not as the whole live cost. The budget half of that
  case would also pass with `ignoredFor` returning `{}` — its teeth are the `ignoreCalls + 2`
  assertion and the other three cases in the same describe.
- `src/server/Weapon/init.luau` / `src/server/Weapon/Flight.luau` — the ignore list is built once at
  the trigger at `serverNow() - rewindSeconds`, while `Flight` carries each pellet's instant forward
  (`rewind + (now - shot.firedAtServer - flown)`), so the instant the cast tests is
  `firedAtServer - rewind + flown`. The two agree at zero travel and drift by the pellet's flight
  time at range (≈0.1 s ≈ 2.4 studs at a 24 studs/s trot), which only matters inside that band at a
  window edge. Dark today (`AIM_REWIND` off, live `rewindSeconds` 0.000); worth queueing beside B6's
  mask so the mask and the list are judged at one instant.
- `tests/server/weapon_rewind.spec.luau` → "takes the candidate that is NOT in the shot's ignore
  list" — the exclusion is implemented by the case's own fake candidate finder
  (`Weapon.setRewindWorld`), so it proves `castWithRewind` passes `ignore` inward and not that
  `Cast.candidates`' `FilterDescendantsInstances` honours it. The real one is only covered by the DEV
  live run.
- `tests/server/weapon_shot.spec.luau` → `Weapon.setIgnoreProvider` — the no-subject arm still
  asserts only `expect(type(Weapon.setIgnoreProvider)).to.equal("function")`; its comment now says so
  plainly, which was the round-1 note. Per verdict 281 it should report itself SKIPPED and not count
  toward the check total. The quoted harness note (`trigger asked 2 time(s), rewind 0.000 s`) shows
  the live arm ran at the tested commit, so nothing is unproven by this.
- `tests/server/range.spec.luau` → `newFakeBoars` (carried) — `fake.roots` is never parented and
  never destroyed; six Parts and their `Zone` children outlive every case. Harmless (outside
  Workspace) and queued.
- `src/server/Range/init.luau` (carried) — `playerSpot` is `Range.positionOf` minus its second
  return, two readers of one fact in one file after the merge. Queue it.
- `src/server/Range/init.luau` — `ignoreCalls` keeps incrementing after `Range.stop()` (`state.stats`
  is only zeroed in `Range.start`), so T13's instrument read on a stopped range is non-zero. Cosmetic.
- `reviews/task-306e/RESULT.md` — the Reviewer's round-1 verdict was rewritten by the Builder from a
  session transcript after a `git reset --hard`, which is disclosed plainly in the request. I cannot
  check it is verbatim; the content is consistent with the code it reviewed (it quotes
  `at = clockNow() - rewindSeconds`, which the diff confirms was there). For the Director, not this
  change.

---
REVIEWER verdict on commit `d1900ccb9d0abc470476093a06293b6c669ff517` (round 2) · 2026-10-29 08:39 UTC · session cost $4.51, 46 turns · written by tools/agents.py
