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
