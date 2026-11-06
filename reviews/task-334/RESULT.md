PASS (item 7, 8 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the bound's ARC at speed has NOT
been seen in Karen's place. What has been seen is `shots334/334r3-F2-hind-01-1.png` — a hind HEAD-ON
at frame centre, nose up, forelegs tucked, with the state read in the same loop (`AIRBORNE hind
Boar58 vy=-25.4 flat=60.1 rise=2.07`) showing it descending 2.07 studs above take-off with the burst
on — and `334r3-F2-any-00-1.png`, a broadside hind whose hooves are already at the grass (after
touchdown). Neither shows the height or the length of a bound, so Karen's *"twice high and 3 times
longer"* has been MEASURED (claim 7: apex x1.84 / x1.92 / x2.22 over 14 / 5 / 3 bounds) and NEVER
JUDGED BY EYE. Claim 8's "one burst per crossing" is likewise a counter reading, not a frame. The
one-bound-per-crossing MECHANISM is proven deterministically, in the repo, by `deer.spec`'s sweep.

What I verified by reading, and why there is no blocking finding:
- `Brain:step` — `local wasLeaping = self._leapFor > 0` is read BEFORE `self._leapFor = math.max(0,
  self._leapFor - dt)`, so the `elseif wasLeaping then self._leapArmed = false` branch covers the
  window-edge tick that round 2's literal `self._leapFor > 0` did not. After it, a new bound needs
  `wasLeaping == false`, which means the previous published `intent.leaping` was false, which is
  exactly the condition under which `Body.stepVisual`'s `if info.leaping ~= true then
  handle.leapSpent = false` has cleared the latch — so `_burstFor` can no longer be set for a bound
  `Body` refuses to launch. Round 2's `_leapFor <= 0` conjunct was correctly dropped from the step
  trigger: `wasLeaping == false` implies `_leapFor == 0` there (the only in-step writer of `_leapFor`
  is this block; `_reactToHit` / `_hearSound`, hence `spook`, run earlier in the same step).
- the minimum gap between two bounds is now two published `leaping == false` ticks plus a band exit,
  so nothing rests on `Body` catching a one-tick drop.
- `Brain:spook` — `if self._leapFor <= 0 then ... end` then `self._leapArmed = false`; `boundStarts`
  guarantees `boundLeap` is a table with `SECONDS > 0`, so no nil index.
- flag-off world unchanged: `DEER_ROAD_LEAP` default false, `leapStarts`/`boundStarts` both return
  false on `leap.ENABLED ~= true`, `_leapFor` stays 0 and `wasLeaping` is always false.
- producer deletion on the new case ("cannot re-arm the burst inside a bound it is already flying"):
  with NO guard the re-entry refreshes `_burstFor` contiguously, so `deer.spec:2040`
  (`each[1].to - each[1].from + 1 == held`) fails; with ROUND 2's guard the refresh fires at the
  window edge and lands 18 ticks after the first burst ended, so `deer.spec:2039` (`#each == 1`)
  fails. Both line numbers match the request's FAIL FIRST citations exactly. `field.road` is read in
  exactly ONE place (`Brain:step`'s `Brain.onRoad`), so the only difference between the two runs is
  the arming, which is what makes the exact-equality assertion sound and not noise.
- the other three cases also die on their producer: `move.LEAP_AIR_SECONDS` goes nil if
  `Boar.leapByKind` is dropped from `Boar.kindConfig`; `burstOn / burstOff` collapses to 1 if the
  `leapSpeedScale` call at `targetVelocity` is deleted; the 2x/3x case dies on a revert of
  `APEX_STUDS` or `SPEED_SCALE`.
- arithmetic: hind apex 5.132 -> up 44.875, air 0.4573 s (27.4 ticks, the request's 0.4574); calf
  3.336 -> 0.3688 s; stag 6.0 -> 0.4945 s and a `leapPlan` window of 0.692 s, under `SECONDS` 0.75.
  Calf 3.336 = exactly 2 x its 1.668 floor, so the floor now binds on nothing, as the comment says.
  `math.floor(0.75 * 60)` = 45.
- claim 6: `0.516` survives only in the research note's explicit *"0.516 is its `Body.leapPlan`
  WINDOW"* and in paperwork; all four code comments read 0.369 / 0.381.
- gate: `[harness] PASS: 34/34 @ ea2c0370 (clean tree)` names the request's `Code commit:`,
  `paperwork-after-code-commit.txt` is OK (only `REQUEST.md` after it), selene/stylua/rojo all
  exit 0, and the round-3 commit touched only `Brain.luau`, `init.luau` (one comment),
  `deer.spec.luau` and the research note — `docs/design/` and `Body.driveForce` untouched, as the
  Director's decision required.

## Notes (non-blocking)
- `docs/research/2026-10-23-deer-road-leap.md` section 9.5 — the note now mis-states the shipped
  mechanism and stops a cycle short. Cycle 4's row reads *"a bound cannot be re-armed while it is
  still flying (`self._leapFor <= 0` on both triggers)"*, but the step trigger no longer carries that
  conjunct at all (it is `elseif wasLeaping`), and only `Brain:spook` still reads `_leapFor <= 0`.
  The apex table (2.00 / 1.99 / 1.97 at `470a75ff`) and the regression figure (108.4) are both
  superseded by the shipped commit's own numbers in claim 7 (1.84 / 1.92 / 2.22; max 110.6 studs/s,
  i.e. the regression went UP, so finding 1 was not its producer). Add the cycle-5 row with the
  `wasLeaping` guard, the re-measured ratios and 110.6; the heading also still says "Three cycles"
  over four rows.
- REQUEST claim 8 — the burst-per-crossing count is NOT sensitive to the producer: with no guard at
  all the refresh is contiguous with the first burst, so the crossing still reads `bursts=1`, and
  with round 2's guard it reads 2 only when the instrument's band happens to agree with
  `Brain.onRoad`'s geometry. The request says as much itself (*"a burst count alone could never be a
  proof"*) and names `deer.spec`'s sweep as what settles it, which is why this is a note and not a
  finding — but do not re-offer "29 of 32 have exactly one" as evidence that the guard works.
- `src/server/Boar/Brain.luau` `Brain:spook` — the new block is unreachable in every world today
  (`MOVE.BOUND_ON_SPOOK` is false everywhere, `deer.spec` asserts it) and has no case: the only
  coverage is the pure `Brain.boundStarts`, which never sees `_leapArmed` or the refresh. Also
  `Brain.boundStarts`' own header still reads *"it does not touch `_leapArmed` ... the arming latch
  is about CROSSINGS -- one bound per road -- which a fright in the middle of the wood must not
  spend"*, while its one caller now spends it on every qualifying spook; harmless only because the
  next off-road tick in `Brain:step` re-arms. Queue a case with the leap ON by parameter before
  `STAG_BOUND_ON_SPOOK` is ever switched on.
- `tests/server/deer.spec.luau`, the sweep's `for offset = 2, window - 2` — offsets `window - 1` and
  `window` are deliberately outside it and WOULD read `#each == 2`: there the animal is off the band
  on the window-edge tick, `leaping` drops false for a tick, `Body`'s latch clears and the second
  bound is a real arc, not a ground burst. That is correct, but the case's comment does not say it,
  so the case reads as "a re-entry can never buy a bound". One sentence would fix it.
- REQUEST claim 5 — two overstatements, neither load-bearing. (a) *"0.75 minus 45 x 1/60 is exactly
  0.0 in double precision"*: `1/60` rounds DOWN as a double, so 45 iterated subtractions leave zero
  or a residue of order 1e-16; the sweep passes either way (the window-edge tick has `wasLeaping`
  true with a margin of ~1/60, not of float noise), so state the margin rather than exactness.
  (b) *"That offset is what fails under round 2's guard"*: under round 2's guard the arm set by the
  off-band ticks survives the whole flight, so EVERY offset in the sweep fails and offset 2 fails
  first; offset 43 is the one that fails under a guard keyed on `_leapFor > 0` literally.
- `src/server/Boar/init.luau` — `Boar.leapByKind`'s header is missing a word: *"`LEAP.SECONDS`, which
  is one size for all three kinds outlasts a calf's 0.369 s flight"*. And both that file's
  `SPEED_SCALE` comment (*"applied at the Brain's one `targetVelocity` write"*) and the spec case
  name (*"the burst is on the published velocity and nowhere else"*) overstate: `Brain:step` has
  three `targetVelocity` writes, and the DOWN / CRIPPLED early returns bypass the burst — so a deer
  crippled mid-bound still publishes `leaping = true` with no forward burst. Harmless (a crawling
  animal should not be launched), wording only.
- `tests/server/deer.spec.luau` "is 2x the measured height and 3x the measured length for a hind" —
  round 1's and round 2's note stands and was not taken up: `apexSeen / BEFORE_APEX` cancels to
  `Body.leapApex("hind", leap) / 2.566`, so the measured 2.471 plays no part in the height half. It
  still dies on a revert of `APEX_STUDS`, so it is not vacuous; the comment claims a comparison the
  arithmetic does not make.
- `TASKS.md` — the 334 row still reads **ESCALATED: Reviewer FINDINGS on round 2** and carries the
  superseded 108.4 and the round-2 apex ratios. Paperwork for the Director's merge, not a deliverable.
- For the Director, carried forward: the in-band maximum is now 110.6 studs/s over 185 animals
  against the `SPRINT x 2.12132` = 95.1 ceiling, and the stag's length is still x2.49. Both are
  explicitly queued by the 2026-11-06 ~20:40 decision (items 4 and 5), neither is touched here, and
  the arc Karen asked for is the thing still unseen.

---
REVIEWER verdict on commit `608c6f4640b6ae141304b4265516559ca6c9c5d7` (round 3) · 2026-11-06 22:04 UTC · session cost $3.51, 35 turns · written by tools/agents.py
