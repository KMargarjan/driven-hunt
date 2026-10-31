PASS (item 10 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the VISIBLE change this task
makes is the ABSENCE of the `crossing %.2f s` clause on the board right after a pace or lane pick
(`RangeBoard.luau`'s `PACE` row: `if record.crossingSeconds ~= nil then ... else ""`), and no frame
of that blank state was seen in Karen's place. All three frames claim 10 describes
(`316-after-boards.png` `crossing 4.22 s`, `316-click-4s.png` `crossing 4.21 s`, `316-click-1s.png`
`PACE SLOW ... crossing 18.61 s`) are boards WITH a crossing printed, and every one of them would
look identical with both new `src` lines reverted -- they are consistent (slow 18.61 vs 133.47/7.2 =
18.54; run 4.22 vs 100.33/24 = 4.18) but they do not depict the fix. Claim 9's two `crossing NONE`
lines are remote-reply reads, not frames. WHAT WAS seen/measured in her place: the animal holding
its pace over the wide span (claim 1's ten cells), and the crossing coming back correctly after one
crossing under the new pace. ALSO NOT PROVEN, and the request says so itself: no real HIT at RUN was
landed (25 shots, all MISS, `DHTestLook` steers the camera and the shot did not follow it) -- the
same instrument limit already queued as 315a(k).

Verified against the repo, not the request:
- `Range.setPace` / `Range.setDistance` each now clear `trial.lastCrossingSeconds`; `blankRecord`'s
  `crossingSeconds = trial.lastCrossingSeconds` and `onShotResolved`'s
  `record.crossingSeconds = trial.lastCrossingSeconds` are the only two readers in `src`, and
  `RangeBoard` is nil-safe, so claims 4, 5 and 6 hold.
- DELETE THE PRODUCER, by reading, on the new case: delete the `setPace` line and
  `expect(picked.crossingSeconds).to.equal(nil)` goes red (the trot's seconds survive the RUN pick --
  and that is exactly the quoted fail-first `range.spec:1646  Expected "nil", got
  "3.2666666666666555"`, whose line number matches line 1646 of the spec at `694e8188`, where only
  `tests/` had been committed); delete the `setDistance` line and `expect(lane.crossingSeconds).to
  .equal(nil)` goes red (`run` survives the lane pick -- `respawn` is false for `distanceStuds`, so
  the 1936 clear cannot mask it); delete the FEEDER, `timeWindow`'s `trial.lastCrossingSeconds =
  seconds`, and `expect(trot).to.be.ok()` goes red. The control arm is real: `DEFAULT_WEAPON` is
  `shotgun`, so `{weapon = "rifle"}` does change `recordFor`'s `fresh` test and does mint a
  `blankRecord`, which is what makes `expect(kept.crossingSeconds).to.equal(trot)` a live check and
  not a check on a field nobody fills. No two sides of the case are the same engine identity.
- The case drives the player's path (`Range.onRequest` + `Range.recordOf`), not the setters; the
  0.183 s `advance` between picks clears `REQUEST_MIN_INTERVAL` 0.15, and the 0.2 s gaps are far too
  short for a second crossing to overwrite `run` before `expect(back.crossingSeconds).to.equal(run)`.
- Claim 1's table is arithmetically self-consistent and its dials are the repo's: `span/issued`
  reproduces in every row (100.33/4.5 = 22.30, /11 = 9.12, /24 = 4.18, /14.4 = 6.97; 133.47/7.2 =
  18.54; 109.47/24 = 4.56; 71.07/24 = 2.96), `PACE.WALK_SPEED` 4.5 / `TROT_SPEED` 11 / `RUN_SPEED`
  24, and `paceSpeedFor` gives slow 36/5.0 = 7.2 and fast 36/2.5 = 14.4. The spans match the repo's
  own case at `range.spec` "keeps the ISSF paces on the ISSF window while the span is wide"
  (`width(1,107)` -> 2.96 s at run). `DEFAULT_PACE` is `WORD.TROT`, so claim (b2) is supportable.
  `<runs-dir>/316-sample2.luau` is outside the repo and I could not read it.
- Harness line names the request's `Code commit: 089cafed...`, is "(clean tree)", scope=all;
  `paperwork-after-code-commit.txt` says OK (only `TASKS.md` and `REQUEST.md` after it). `test2` N/A
  is true against the ACTUAL diff, not a stale list: `TWO_PLAYER_PATHS` holds `src/client/Range/`,
  `range_mask.spec` and `range_solo.spec` and neither `src/server/Range/init.luau` nor
  `tests/server/range.spec.luau`. selene, stylua, rojo build all clean.
- No owner boundary moved: two assignments to a private field of the server's own trial, no client
  change, no second writer, nothing reaching into another system's instances.

## Notes (non-blocking)
- claim 8 / `TASKS.md` row 316 -- *"Flag-off (`RANGE_SOLO` off) is bit-for-bit"* overstates and is
  contradicted by the request's own evidence. With the flag dark the behaviour DOES change: the
  fail-first run is a dark-flag run whose board value goes from `3.2666666666666555` to nil, and the
  new spec passes `solo = nil` so it runs at the dark default. What is true is the verification
  offered beside it -- neither changed function reads `state.solo` or any span, so the fix behaves
  the SAME in both flag states. Restate it that way; nothing is hidden, the word is wrong.
- `src/server/Range/init.luau` / `trial.crossingSecondsByPace` -- the task's own stated rule
  (*"seconds measured over 100.33 studs are not the 133.47-stud lane's crossing"*) is applied to
  `lastCrossingSeconds` only. `crossingSecondsByPace[pace]` keeps the old lane's seconds for ever
  after a `setDistance`. Harmless today because nothing in `src` reads it (write at `timeWindow`,
  clone in `Range.trialOf`, and `trialOf` has no caller outside `range.spec.luau`), so it cannot
  reach the board -- but queue either the clear in `setDistance` or a written reason the per-pace map
  is exempt, before anything starts publishing it.
- `Range.setPace` vs `Range.setDistance` -- `setDistance` guards its clears with
  `if distanceStuds ~= trial.distanceStuds`, `setPace` clears unconditionally, so re-picking the pace
  he already has now blanks a crossing that WAS measured under that pace and that lane. Conservative,
  and consistent with `setPace`'s pre-existing unconditional disarms, but the asymmetry is
  undocumented; one `if pace ~= trial.pace` or one comment line closes it.
- `tests/server/range.spec.luau`, the new case -- `predicted = RangeData.crossingSeconds(LAYOUT
  .WINDOW_STUDS, speedOf("run"))` is right only while `RANGE_SOLO` is dark. `startRange(fake, now)`
  passes `solo = nil` and `Range.start` then reads `Range.SOLO_VIEW`, so lighting the flag makes
  `timeWindow` time the WIDE span: `run` becomes ~4.18 s against a predicted 1.50 s and
  `expect(err <= Range.CONFIG.CROSSING_TOLERANCE)` reddens. Same shape as the already-queued
  313a(l); add this case to that list so the flip stays one edit. The two assertions the task is
  about (`picked.crossingSeconds` / `lane.crossingSeconds` nil) are span-independent and survive.
- request, the fail-first paragraph -- *"3.2667 s is `WINDOW_STUDS 36 / 11.03`"* names a speed the
  config does not hold: `PACE.TROT_SPEED` is 11 and 36/11 = 3.2727. The observed value is exactly
  196 * (1/60), i.e. the `advance` helper's 1/60 discretisation of that crossing. The number is
  right, the explanation is not.
- request, the fail-first harness quote -- `1 failed, 0 skipped, 1 errors` while the clean run is
  `0 failed, 0 errors`, and commit `694e8188`'s own message is *"the case stops the range before it
  asserts, so one failure stays one failure"*. Only one failure line is pasted. Paste the error line
  too, or say that the counter double-counts a thrown expectation; the gate run at the code commit is
  34/34 with 0 errors either way.
- `docs/design/shooting-range.md` section 9's board row (*"PACE | the word and the measured crossing
  seconds"*) does not record the rule this task establishes -- the clause is blank until a crossing
  has been measured under the pace and the lane it is labelled with. One line, queueable.

---
REVIEWER verdict on commit `25574f76d6280e3b711ad51e93a39f9ff0ee423d` (round 1) · 2026-10-31 01:54 UTC · session cost $2.55, 34 turns · written by tools/agents.py
