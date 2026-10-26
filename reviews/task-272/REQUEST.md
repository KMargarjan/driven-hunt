# Task 272 -- the sweep reaches its whole window, and a case enters it

Task: 272
Round: 1
Base: `813b76b0` (this Builder's 271 head; its code comes with it)
Code commit: (filled in with the harness line)

## PLAN

### (a) REAL LIFE

The shooter hits what he can see. His picture of a deer crossing at 28.7 studs/s was measured
**0.178 s old**, which is 5.1 studs -- most of a 6.03-stud body. A server that judges him against
the animal's position at a different instant is judging a shot nobody took.

### (b) MEASURED NOW

Task 271, live, Karen's place, `HIT_CLAIM` on, on the v4 build (`<runs-dir>/271-v4.log`,
`DHClaimStats` read as a live `ServerStorage` attribute, L-026):

```
enabled=true claims=4 accepted=1 refused=3 lag=0.033s
[claim-line=2 worst 3.891/2.000 (... ALONG THE ANIMAL +3.865 (v 23.8 studs/s, so 0.163 s of it))]
```

`lag` is `claimWorstLagSeconds` -- the view instant the sweep CHOSE -- and 0.033 s is **two grid
steps** of the eighteen a 0.30 s window asks for, while a refusal in the same trial needed 0.163 s.

**And the dispatch's reading of that number and mine differ, which is why item 1 is a measurement
and not a fix.** The dispatch says *"the sweep reached 1-2 candidates, not the ~18"*. Reading
`Boar.sampleAt`, a 96-sample ring spans 1.60 s and answers any instant inside it, so the sweep
SHOULD get its eighteen. If it does, then nothing is short and the defect is in the CHOICE --
`pickViewInstant` filtering on check 3 or minimising to a near instant -- which is a different fix
in a different file. **One trial decides it and nothing is changed before it.**

### (c) TARGET

* **Item 1:** one live trial prints, per refused claim: `#candidates`, the window in seconds, the
  oldest and newest instant the sweep actually asked for, and whether any candidate passed check 3.
  Those four because they separate "the sweep is short" from "the choice is wrong", and no other
  pair of numbers does.
* **Item 3:** a case that enters `judgeClaimFor`'s own sweep, RED with the candidate loop deleted.
* **Item 4 (CORE):** **at least 4 of 5 led shots accepted, chest-named, with the mark on the chest
  and a frame.**

### (d) LEVER

```
src/server/Weapon/init.luau:1596:	for k = 0, CONFIG.CLAIM.VIEW_LAG_MAX_SAMPLES - 1 do
src/server/Weapon/init.luau:1600:		local where = askWhereWas(claim.part, at)
src/server/Weapon/init.luau:1620:	local index, trajectoryPoint, _lineStuds, _movedStuds =
src/server/Weapon/Validator.luau:275:function Validator.pickViewInstant(
src/server/Weapon/init.luau:836:function Weapon.claimLine(from: any): string
```

The sweep writes the candidates and `pickViewInstant` chooses among them; `claimLine` is the one
place the answer becomes text a probe can read. Item 1 adds numbers to that text and changes no
rule.

### (e) HOW IT WILL BE MEASURED AFTER

The same instrument: `<runs-dir>/268kill.py` + `proof268.py`, five led shots at a staged running
deer, `DHClaimStats` read live. Item 4's count is reported BESIDE item 1's `#candidates` and
`anyPassed`, so a repeat low number is explained by its cause rather than filed as "still broken"
(L-112).

### On L-028

Item 3's case must invoke `judgeClaimFor`, not a pure helper -- 271 round 2's case called
`pickViewInstant` directly and deleting the candidate loop left the suite green, which the Reviewer
found twice. The RED run against this branch's base is pasted before the fix is called done.

### On L-088

This task started at **2026-10-26T06:59:18Z** (`<runs-dir>/272-start.txt`). The 2.5 h mark is
**09:29:18Z** and I will quote the literal clock at it, not an estimate.

## WHAT CHANGED

(filled in)

## CLAIMS

(filled in)
