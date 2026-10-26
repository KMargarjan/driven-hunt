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
