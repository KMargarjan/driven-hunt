# Task 349b: the three proofs for 349, and one review of the whole branch

Task: 349b
Round: 1
Base: 6fa59255 (origin/main, #365)
Code commit: 7950974ddf0168c163ecec61cfb40eb16e626071

This review covers the WHOLE branch diff against `main` -- task 349's code included -- so the
merge gate's `PASS` is for everything that would merge.

## PLAN (core protocol step 0, committed before any `src/` edit)

**(a) REAL LIFE.** Not applicable as a field figure: all three items are about whether a test binds
the code it claims to bind. The behaviour they pin was measured live in 349 round 3 and is not
reopened here.

**(b) MEASURED NOW** (349 round 3, `reviews/task-349/RESULT.md`, three findings; her Forest Test
attributes read at 01:27 UTC tonight, `<runs-dir>/349b-attrs-start.txt`:
`DHFlag_DRIVE_AIMS_AT_PICKED_STAND=false`, `DHFlag_PLACEMENT_IN_PLACE=false`):
1. `restSpot` creates and publishes the refusal counters and **never increments one** -- the line a
   refused bed prints always reads `swept=0 band=0 lane=0 zone=0 unseen=0`, measured in `X11d`'s
   console with 85 refusals behind it.
2. The latch case asserts `settleAim(false)`'s boolean on the SECOND consecutive call, where
   `settleAim`'s own first line returns `false` for any already-settled drive -- so it cannot fail.
3. The bed case calls only the pure `Data.restPoint` and re-writes the gate's arithmetic by hand;
   no spec calls `ForestTest.restSpot`/`bedSpot` with a shift.

**(c) TARGET.** Each of the three gets a case that FAILS when its producer is deleted, and the
failing line is shown (L-093). That is the only target: a proof that does not bite is not a proof.

**(d) LEVER.**
```
src/server/ForestTest/init.luau  restSpot: local refusals = { swept = 0, band = 0, ... }  (never written)
src/server/ForestTest/init.luau  settleAim: if state.aimSettled then return state.aim, false end
tests/server/forest_stand.spec.luau  "generates a bed in the same frame it judges it in" (pure only)
```

**(e) HOW IT WILL BE MEASURED after.** The harness itself: three delete-the-producer runs, one per
finding, each naming the spec line that failed, then reverted.

## Not in scope, by the Director's decision (2026-11-12)
- **The corner stand's worst gap, 46 s against the 40 s target, is NOT a blocker.** The flag stays
  OFF. Three stand-11 flag-ON drives are measured below and their max gaps reported, nothing more.
- **Cell C1 bedding 0 with `PLACEMENT_IN_PLACE` ON is not this task** -- it goes to 345e/f. The
  control is on the record: `X11d` (both flags ON) lays 0 beds and `P11` (placement ON, aim OFF)
  also lays 0, so this cell beds nothing with or without the aim.
- **One number from round 3 is carried by neither this dispatch nor the not-in-scope list:** the
  corner stand's `peak live` is -21% against the main line (26 against 33) with `stepAvg` -19%
  (2.888 against 3.577) -- i.e. less load, not more. I flag it here rather than let it drop; it
  needs the Director to say deferred-and-where, or accepted.

## What changed

```
[harness] PASS: 34/34 checks @ 7950974ddf0168c163ecec61cfb40eb16e626071 (clean tree) scope=all
```
`test2`: N/A -- no changed file is in `TWO_PLAYER_PATHS`.

1. **Each arm counts its own refusal.** `restSpot`'s chain increments `swept`, `band`, `ground`,
   `lane`, `zone` or `unseen` where it refuses. **`band` was split from the rest on purpose**: it is
   the band test alone, so it names the FRAME -- a candidate generated on the main road while the
   gate measures the aimed one lands exactly there -- while the ground, canopy and trunk refusals
   get `ground`. `ForestTest.bedRefusals()` publishes the tally so a spec and a probe can read it,
   not only the console line `bedSpot` prints.
2. **The latch case asserts the FIRST `settleAim(false)` after `newDrive`**, and the first after the
   re-pick. The second consecutive call returns `false` for any already-settled drive, which is why
   round 3's version could not fail.
3. **A case drives `ForestTest.restSpot` itself**, with a band that cannot hold the row (refused on
   the band arm, counter > 0) and with a band moved by the same shift.
4. **Commit `a1548070`'s subject overstates what that commit did.** It reads *"a refused bed names
   the test that refused it"*; what landed there was the initialiser and the printed tally, not the
   five increments -- a Python edit asserted out before writing and I did not re-read the file
   (V298). Commits are not rewritten; the correction is here and in `ESCALATE.md`'s round-3 entry.

## Claims

1. **The counters count.** `forest_stand.spec` note from the gate run:
   `no spot (DEV has no C1 ground): swept=0 band=56 ground=76 lane=0 zone=0 unseen=0`.
2. **The shift reaches the generator, read off the counters, not transcribed.** `restSpot` offsets
   each ring by `sin(angle) * radius` (+-64 studs over 4 rings of 16). With the shift the depth is
   150 +- 64 and the inner rings clear a 120..180 band (`ground` = 76). Without it the depth is
   150 - 975 +- 64 and **no** ring can clear that band, so `ground` would be 0. The case asserts
   `ground > 0`.
3. **All three producers were deleted and run (L-093), one per finding, each reverted.**
   - stop counting the band arm -> `failed [server] forest_stand.spec:365`
     (`expect((why :: any).band > 0).to.equal(true)`)
   - restore round 2's `if aim.why == "nobody locked"` guard -> `failed [server] forest_stand.spec:289`
     (`expect(latchedFirst).to.equal(false)`)
   - drop `dz or 0` from `restSpot`'s `Data.restPoint` call -> `failed [server] forest_stand.spec:383`
     (`expect((after :: any).ground > 0).to.equal(true)`)
4. **Three stand-11 flag-ON drives at the code commit** (`<runs-dir>/349-count.py`), one line each:

| run | first | median | max | inView | released | escaped | outOfBounds |
|---|---|---|---|---|---|---|---|
| `N1` | 14 s | 4 s | **25 s** | 209/288 | 112 | 99 | 6 |
| `N2` | 15 s | 3 s | **46 s** | 191/289 | 112 | 96 | 9 |
| `N3` | 15 s | 3 s | **33 s** | 207/289 | 121 | 93 | 11 |

Two of the three are inside the 40 s target and one is not, which is the Director's own point that
a single drive cannot settle a max-gap target. The flag stays OFF either way.

## What I could not verify

- **No new frames.** The dispatch says none are required; round 2's and round 3's stand-11 frames
  stand (`<runs-dir>/A11f-sighting.png`, `A11f-left.png` -- a hind at the treeline, 101 studs, from
  stand 11's own eye, opened and described in 349's round-3 request).
- The second half of case (3) runs in DEV, which has no C1 ground, so no bed is actually laid there
  -- the counters are the reading, and they are what the frame decides. Labelled in the case itself.
- Karen has not played any of it. The flag is OFF in her Forest Test and the attribute diff against
  this session's own 01:27 read is empty.
