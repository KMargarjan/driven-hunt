# ESCALATE -- task 269b, after round 2. For the Director.

**Builder, 2026-10-26.** Branch `task-269b-claim-accept`. Two review rounds done, both FINDINGS,
every finding right and every one of them addressed in code. **I am stopping before round 3 rather
than spending it on a request I already know is incomplete**, and the thing it is incomplete about
needs a decision, not another round.

## WHERE IT STANDS

| round | verdict | what it found | state |
|---|---|---|---|
| 1 | FINDINGS x3 | `.part` on `Shotgun.Impact` (no such field) killed the self-block fix; the backward search widened check 3; `claim-future` became unreachable | **all three fixed** |
| 2 | FINDINGS x2 | the waiver was unbounded and the design was not amended; the owner-level case can escape | **the bound and the design are done; the case is NOT** |

`[harness] PASS: 34/34 checks @ d7772bdfb20db9a39fa5d16d4c99a16d58f117a2 (clean tree) scope=all`.

## WHAT IS ACTUALLY OPEN -- one thing

**Round 2's finding 1: the only case that covers the OWNER's wiring (`stoppedBySame`) escapes.**
I rewrote the case twice and measured both outcomes rather than guessing:

* one gate run it **executed and REFUSED** -- `weapon_shot self-block claim: rifle/Slug, 1 report(s),
  accepted 1 -> 1, refusedClaimBy [claim-blocked=1]` -- because the staged reach was measured from
  the camera `origin` while the server launches from `shot.muzzle`. Fixed.
* the two runs since, it **escaped**: `nobody is holding a gun that can fire, so the live ACCEPT
  path did not run`. The case sits immediately after the existing accept case, which fires the same
  rifle first and leaves it empty/busy; the fixture needs its own loaded subject, not a sibling of
  one.

So: **the self-block fix is correct by reading, is driven from both sides in `Validator.judgeClaim`,
and has never been seen to accept anything** -- not in a spec through the owner, and not in Karen's
place. I am not willing to write a round-3 request that calls it proven.

## AND THE CORE ITEM IS NOT PROVEN EITHER

Item 4 -- *at least 4 of 5 led shots accepted, naming the chest, with the mark on the chest* -- was
measured at **2 of 4 accepted and 0 of 5 chest when led; 2 of 5 chest and 0 accepted when not led**,
and that was on a build where **the self-block fix could not fire at all** (round 1's finding). No
live trial has been run on the corrected build. **This is still unproven; nobody has seen it.**

## THE NEXT CONSTRUCTION QUESTION, which I believe is the real one

**With the claim path on, LEADING puts the hit on the REAR.** `Claim.simulate` already shifts each
target forward by `target.velocity * pellet.elapsed` and casts the segment back by the same amount
-- it compensates for the flight itself. A shooter who ALSO leads by `v x flight` applies the lead
**twice** and lands a body length behind. The measurement agrees: the led trial's two accepted
claims both named `rear`, and the only two `chest` zones of the whole session came from the trial
that aimed AT the chest with no lead at all. That is a mechanism and it is testable in one session.

## WHAT I AM ASKING FOR

1. **A decision on round 3.** Either (a) authorise one more round for the fixture alone -- give the
   self-block case its own loaded subject and prove the accept path through `onFireRequest` -- or
   (b) merge what is here as an instrument-and-correctness task with item 4 written NOT PROVEN, and
   dispatch the lead question separately.
2. **If (a), the extra round is a `DIRECTOR_MAX_ROUNDS` matter**: rounds 1 and 2 are spent and the
   open item is documentation-and-fixture shaped, not a defect in the shipped rule.
3. **Either way, the next dispatch should be the double-lead question above**, not a fifth
   iterate-and-reshoot (L-116).

## THE PLACE IS AS IT WAS FOUND

Twelve attributes before and twelve after, the same twelve: `HIT_CLAIM` set ON for the trials and
**OFF again** as rule K and the dispatch require; `flags.py --place forest clear` never run;
`DHTestOwns` added for the session and removed by name. Play stopped, the Forest Test window closed
before every harness run.

---

# ESCALATE -- task 270. THE DESIGN DELTA IS THE ARCHITECT'S, and here it is, measured.

**Builder, 2026-10-26.** Branch `task-270-lead-sign`. Round 1's blocking finding is right and I am
not the one who may close it: `docs/design/ballistics.md` is the ARCHITECT's file (CLAUDE.md's role
table -- *"BUILDER ... Never writes designs or verdicts"*). The **code** header in
`src/client/Weapon/Claim.luau` is mine and is fixed. These three design edits are owed:

1. **§4.7, `Claim.simulate` step 2.** It still reads *"the segment is TRANSLATED by
   `-velocity * elapsed` ... the impact point is translated back by `+velocity * elapsed`"*. It is
   now `-velocity * (elapsed + along / speed)` -- the instant the bullet ARRIVES -- found in two
   passes, because `along` is the cast's own answer. **Why**: `elapsed` is the sub-step's FIRST
   edge and one sub-step at the rifle's 2612 studs/s is ~87 studs, so the lead was quantised to
   whole sub-steps. Measured, a target crossing at 30 studs/s: at 40 studs the lead that exists is
   0.463 studs and the lead applied was **0.000**; at 150 it is 1.779 and 1.000 was applied. After:
   worst |error| **0.009 studs** over twelve rows.
2. **§4.7 / §5.5, a NEW rule that is not written anywhere.** A refined cast that finds nothing means
   the bullet did not meet that animal at the instant it arrives, so **no claim is made for that
   target** -- a shot the coarse pass would have claimed now returns none. That is a change in what
   a player gets back and it belongs in §5.5's list of known errors beside the turn error.
3. **§1.4** (pre-existing, found by the Reviewer, not caused here). *"Aiming AT a running animal
   still misses ... so no claim is produced at all"* is absolute, and the deterministic case shows
   an aimed-AT shot DOES claim the animal's trailing body whenever the lead fits inside it. It wants
   "no claim on the vitals", or a bound.

**And one measurement for whoever takes the next lead task**, because it points away from
`Claim.simulate`: with the fix shipped, five live led shots in Karen's place read
`claims=4 accepted=0 refused=4 [claim-line=4 worst 4.858/2.000]` -- against 269b's `4.778`. The
quantisation removed was 0.5-1.8 studs; the live gap is 4.9 and it moved the WRONG WAY, in the
direction a more-advanced claim gives against a server holding the animal further back. **The next
thing to build is 269a(a): record the refused `trajectoryPoint`/`serverPoint` PAIR, not only its
magnitude**, so the direction of that gap can be read -- along the line, across it, or in time --
before anything else in this path is changed.

**Still owed from 269b and not started here:** its `weapon_shot.spec` owner-wiring fixture still
escapes ("nobody is holding a gun that can fire"), and 269a(b) (a second shot without cycling sends
no claim) is untouched. Both want re-dispatching rather than dropping.

---

# ESCALATE -- task 271, after round 2. Past the mark, stopping.

**Builder, 2026-10-26.** Branch `task-271-claim-line`. Two rounds, both FINDINGS, every finding
right. `[harness] PASS: 34/34 @ ec724e019b1cd5b94144d3552a809a6cf8025ef4 (clean tree) scope=all`.
**I am at 3 h 35 against a 2.5 h box and I am stopping rather than opening round 3 on a fixture
that has escaped twice before (269b).**

## WHAT THIS TASK ACTUALLY SETTLED, and it is the thing six tasks could not say

**The cause of `claim-line` is a TIME error, not a line error, and it is now a number.** One live
refusal, Karen's place, `HIT_CLAIM` on:

```
claim-line=1 worst 5.457/2.000
  gap 5.120 = along -2.079, across 4.679, ALONG THE ANIMAL +5.106 (v 28.7 studs/s, so 0.178 s)
```

**99.7 % along the animal's own velocity.** The residual perpendicular to its path is 0.38 studs --
a fifth of the 2.0 budget. `LINE_TOLERANCE_STUDS` was never the wrong number; it was being measured
at the wrong instant.

The Architect was run on that measurement (`tools/architect.ps1 design ballistics --task 271`,
`PASS`) and wrote **v4 section 5.2.1**: the server sweeps its own history over a window it owns and
judges at the instant its own trajectory came closest, among the instants that pass check 3. Both
of my candidates were refused with arithmetic. That design is committed and the implementation is
green.

## WHAT IS OPEN -- one thing, twice found and still true

**No case enters the OWNER's sweep.** My round-2 answer reproduced the live numbers purely
(`weapon_hits.spec`: one candidate refuses `claim-line` at 5.489 where the live refusal read 5.457;
the sweep accepts at 0.38) -- but it calls `Validator.pickViewInstant` directly, so deleting the
candidate loop in `judgeClaimFor` leaves the suite green. The Reviewer is right.

**What it needs, exactly:** `weapon_shot.spec`'s live accept case with a history provider that
answers `at` (`zone.CFrame * CFrame.new(travel * (at - now))`), a claim whose `point` is where that
part was ~0.18 s before `arrivalAt`, asserted **refused** with `Weapon.setViewWindow(0)` and
**accepted** with the configured window. The seam for it ships (`Weapon.setViewWindow`) and is
currently dead API, which the Reviewer also names.

Round 2's findings 2-4 (the along-track instrument collapsing into the line instrument, and round
1's findings 5-7, which I did not touch) are in `reviews/task-271/RESULT.md` and are not addressed.

## AND THE CORE ITEM IS STILL NOT PROVEN

Five led shots on the v4 build: `claims=4 accepted=1 refused=3 lag=0.033s`, zones `rear`, a tree,
`rear`, `body`, `body` -- **0 of 5 chest**. Against the same instrument 269b read 2 of 4 accepted
and 270 read 0 of 4, so 1 of 4 is inside their noise. **Nobody has seen it.**

**But the new instrument says where to look next, and it is one probe:** `lag=0.033s` is two grid
steps, while the refused shot in the same trial needed 0.163 s. The sweep is reaching one or two
candidates, not the eighteen its 0.30 s window asks for. The two things that can do that are
`askWhereWas` answering nil for the older instants (the loop breaks on the first nil after a hit)
and `pickViewInstant` filtering them out on check 3. **Print `#candidates` and `anyPassed` beside
the lag and it is decided in one trial.** (Note that number was measured on the round-1 build, so
it is the worst over every claim that reached the sweep, not the accepted one -- round 2 fixed the
field, not the reading.)

## WHAT I AM ASKING FOR

1. **A decision on round 3**: authorise one round for the owner-path fixture alone (it is the same
   `weapon_shot.spec` fixture 269b could not make stick, so it wants a dedicated loaded subject,
   not a sibling of the accept case), or take the branch as a measurement-and-design task with item
   3 written NOT PROVEN.
2. **The next dispatch is the one-probe question above**, not another five-shot trial.
3. **Still owed and untouched:** 269b's escaping owner fixture, 269a(b), 270a(a) (the coarse gate at
   `SPRINT_SPEED` 38), and round 1's findings 5-7 here.

## THE PLACE IS AS IT WAS FOUND

Twelve attributes before and twelve after; `HIT_CLAIM` ON for the two trials and **OFF again**
(rule K); `flags.py --place forest clear` never run; `DHTestOwns` added and removed by name; Play
stopped and the Forest Test window closed before every harness run.
