# Task 210 -- two flaky specs become deterministic

Task: 210
Round: 1
Base: 3de5e95 (main)
Code commit: d6d42bce673ea7d7d80004d475fe6b3b4f745267

```
[harness] PASS: 33/33 checks @ d6d42bce673ea7d7d80004d475fe6b3b4f745267 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ d6d42bce673ea7d7d80004d475fe6b3b4f745267 (clean tree)
[harness2] PASS: 35/35 checks @ d6d42bce673ea7d7d80004d475fe6b3b4f745267 (clean tree)
[harness2] PASS: 35/35 checks @ d6d42bce673ea7d7d80004d475fe6b3b4f745267 (clean tree)
```

**Five one-player runs at that commit, every one 33/33 PASS, and THREE CONSECUTIVE TWO-PLAYER RUNS
at the same commit, every one 35/35 PASS** (the three `[harness2]` lines above are the Director's,
2026-10-19; `tests/client/zz_tie_to_a_tree.spec.luau` is in `TWO_PLAYER_PATHS`, and three runs rather
than one is the right bar for a race fix). Only paperwork has landed since that commit:
`git diff --name-only d6d42bce..HEAD` is `ESCALATE.md`, `TASKS.md` and this file.

## What changed

Two specs that cost a retry on most two-player runs of the week of 2026-10-18. **Both were SPEC
races; neither was a code race.** No file under `src/` is touched.

* `tests/server/boar_body.spec.luau` -- the "boar sounder, live" block.
* `tests/client/zz_tie_to_a_tree.spec.luau` -- the probe in "refuses a shot aimed straight at a
  beater, and spends nothing doing it".
* `tests/client/input_scenarios.txt` -- the "tie-the-driver" scenario, reordered.

## Claims

1. **The boar failure was the SCATTER expelling members, not the case's own stray.** The case before
   the break case shoots the leader, which latches `SOUNDER.SCATTER_SECONDS` = 6; for those seconds
   `Brain._herdSteer` triples separation and drops cohesion, and the break rule in
   `Runtime._stepSounders` expels any member past `SOUNDER.BREAK_STUDS` = 60 from the animal ahead of
   it for `BREAK_SECONDS` = 4. The sounder fell to one member, `#members <= 1` dissolved it, and
   `herd:sounders()[1]` was nil. *Verify:* read the comment block in the break case against
   `Runtime._stepSounders` (`aheadOf`, `entry.awayFor`, the `#members <= 1` branch) and
   `Brain._herdSteer`.
2. **It was measured, not guessed.** `<runs-dir>/test2-t158b.log` and `test2-t201c.log` both carry
   the two failures AND the scatter width of the preceding case: 40.7 and 44.0 studs, against
   32.1-32.9 in the five passing runs at this commit, with 60 the limit. *Verify:*
   `grep -E "scatter width|memberIds"` over those two logs.
3. **It was reproduced deterministically before it was fixed.** Forcing the width to 160 studs at the
   head of the break case on the pre-fix spec gave `0 sounder(s)`, `membersLeft 4` and the SAME two
   errors (`boar_body.spec:785` / `:795` -- the instrumented file's numbers for the Director's `:731`
   / `:740`). *Verify:* the quoted output at the end of this file, and the commit message of
   `557fa15`.
4. **The fix removes the dependency rather than widening a margin.** The break case now holds the
   non-stray members at their own CFrames every frame, for the same frames in which it already drags
   the stray to the far corner. The scatter can no longer move them, so the only member outside
   `BREAK_STUDS` is the one the case put there. *Verify:* the `held` / `heldAt` loop in the break
   case; the three original assertions are byte-identical to `3de5e95`
   (`git diff 3de5e95..HEAD -- tests/server/boar_body.spec.luau`).
5. **No sleep was added and no assertion loosened.** The clock is still the rule's own
   `SETTINGS.BREAK_SECONDS + 1.5`; `#herd:sounders()[1].memberIds == members - 1`,
   `herd:sounderOf(strayId) == nil` and `membersLeft > before` are as they were. *Verify:* the diff
   of that case.
6. **Waiting the scatter out was tried first and REJECTED on measurement.** At `557fa15` the case
   waited for `scatterFor == 0` plus a re-formed width; that run's own note reads
   `waited 5.57 s ... 3 member(s) ... membersLeft 2` -- the sounder lost a member inside the wait, so
   the race had moved rather than gone. *Verify:* `git show 557fa15` and the commit message of
   `155e0b7`.
7. **Both cases now state their preconditions.** `expect(#herd:sounders()).to.equal(1)`,
   `expect(members >= 3)` and `expect(spread(held) < SETTINGS.BREAK_STUDS)` in the break case, and
   `expect(#herd:sounders()).to.equal(1)` at the head of the mortal case. A damaged herd now fails on
   a line that names the problem instead of on a nil index. *Verify:* read both cases.
8. **The tie failure was the replay's own RELOAD, identified from the state transition.** The
   Director's pair was `b=Live/Live ammo=Buck res=10 busy=0.00` -> `b=Empty/Empty ammo=Buck res=12
   busy=0.50`. `Weapon.StateMachine`'s `Break` branch is the only thing in the repo that empties both
   barrels, puts the two unfired shells back into that ammo's pocket (+2) and sets `busyUntil` to
   `Shotgun.CONFIG.RELOAD_BREAK` = 0.5. The scenario's `R` landed 1.2 s after the cue -- inside the
   probe's fire-to-answer window -- and the probe only ever checked the gun BEFORE firing
   (`staging()`'s `gun.busyFor > 0`). *Verify:* the `Break` branch of
   `src/server/Weapon/StateMachine.luau` against `RELOAD_BREAK` in `src/shared/Shotgun/init.luau`,
   and `gunPrint` in the tie spec.
9. **Three changes there, no assertion touched.** (a) `probeBefore` is read fresh for EVERY attempt
   (it was read once and kept, so an `off-stand` retry bracketed seconds of replayed input);
   (b) an attempt whose window was not quiet is DISCARDED and retried, measured by a `QUIET_ACTION`
   watcher on the weapon's own keys -- lifted from `weapon_client.spec`, which already solves this
   problem this way (rule 2, borrow before building); (c) `staging()` also refuses a gun touched
   within `PROBE_QUIET` = 0.5 s, because `busyFor` is the server's published answer and a key already
   on the wire reads as an idle gun. `expect(probeAfter).to.equal(probeBefore)` is unchanged.
   *Verify:* `git diff 3de5e95..HEAD -- tests/client/zz_tie_to_a_tree.spec.luau`, and compare
   `QUIET_ACTION` here with the one in `weapon_client.spec`.
10. **The scenario gives the probe a runway.** "tie-the-driver" now does `R`, waits 2600 ms
    (`RELOAD_TOTAL` is 2.0 s), then cues with `T` and waits 4000 ms before the first click -- the same
    inputs in the same order relative to each other, so the gun's end state is identical; only the cue
    moved, and the quiet window after it went from 1.2 s to 4.0 s. *Verify:*
    `git diff 3de5e95..HEAD -- tests/client/input_scenarios.txt`; the spec's `PROBE_WINDOW` and retry
    comments were updated to match and no longer describe the old timing.

## What could not be verified

* **The tie fix is not exercised by the ONE-player suite, and I did not run the two-player one.**
  With one player the probe never fires -- `zz_tie: one player, so no beater to refuse a shot at;
  probe not fired` in all five of my runs -- because there is no driver to aim at. Its verification is
  `test2`, which the Director ran three times at this commit (the three `[harness2] PASS: 35/35`
  lines above). So the claims about the tie spec are backed by three green two-player runs, but the
  REASONING about them -- which attempt was discarded, and why the reload used to land inside the
  window -- is read off the code and off the Director's earlier failing output, not off a run of
  mine. **What a reviewer can still ask of those runs** is the note
  `zz_tie: probe attempts (N discarded for replayed input inside the window, task 210)`: `N` is how
  many attempts would previously have been asserted through, and the Director's logs carry it.
* **The boar fix's five clean runs are one-player runs.** They do carry the evidence that matters:
  `scatterFor 3.96-3.97` at the break case's entry in every one, so the case ran its whole
  four-second clock inside a LIVE scatter and still lost exactly one member (`4 member(s)` ->
  `3 member(s)`, `membersLeft 1` -> `2`). Under two-client load the entry width was 40.7 / 44.0 rather
  than ~32.5; both are under `BREAK_STUDS`, and the hold freezes whichever it is, so the arithmetic
  cannot change. The two-player confirmation is the Director's `test2` x3, above.
* **No screenshot (rule 5):** nothing drawn changed. Test-only commit, nothing under `src/`.

### The reproduction output, pre-fix (claim 3)

```
note  boar sounder: the break case inherits -- 1 sounder(s), 4 member(s), 4 live, width 32.4 of 60, membersLeft 1, 291.2 studs from the line
note  t210 DIAGNOSTIC: forced the scatter wide -- 1 sounder(s), 4 member(s), 4 live, width 160.0 of 60, membersLeft 1, 221.5 studs from the line
note  boar sounder: the break case leaves -- 0 sounder(s), -1 member(s), 4 live, width 335.0 of 60, membersLeft 4, 261.0 studs from the line
failed [server] boar_body.spec:785 ServerStorage.Tests.boar_body.spec:785: attempt to index nil with 'memberIds'
failed [server] boar_body.spec:795 ServerStorage.Tests.boar_body.spec:795: attempt to index nil with 'memberIds'
[harness] FAIL: 31/33 checks @ 1e5d7105adfd13f07a2fc1716b11fa6d5dc8f51a (DIRTY TREE (1 paths) - NOT valid evidence) scope=all
```

### The five runs at the code commit

| run | result | the break case inherits | the break case leaves |
|---|---|---|---|
| 1 | PASS 33/33 | 4 members, width 32.8, scatterFor 3.96 | 3 members, membersLeft 2 |
| 2 | PASS 33/33 | 4 members, width 32.5, scatterFor 3.97 | 3 members, membersLeft 2 |
| 3 | PASS 33/33 | 4 members, width 32.9, scatterFor 3.97 | 3 members, membersLeft 2 |
| 4 | PASS 33/33 | 4 members, width 32.3, scatterFor 3.97 | 3 members, membersLeft 2 |
| 5 | PASS 33/33 | 4 members, width 32.1, scatterFor 3.97 | 3 members, membersLeft 2 |
