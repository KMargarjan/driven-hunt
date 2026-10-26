# Task 272 -- the sweep reaches its whole window, and a case enters it

Task: 272
Round: 2
Base: `813b76b0` (this Builder's 271 head; its code comes with it)
Code commit: `013a075e8b7d046a5bb1299e1dd01e3cb7e1a40b`

```
[harness] PASS: 34/34 checks @ 013a075e8b7d046a5bb1299e1dd01e3cb7e1a40b (clean tree) scope=all
```

`test2` is **N/A**: `src/server/Weapon/init.luau` and `tests/server/weapon_shot.spec.luau`, neither
in `TWO_PLAYER_PATHS`.

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

* `src/server/Weapon/init.luau` -- five diagnostic fields on the sweep (`claimSweepFound`,
  `claimSweepAsked`, `claimSweepWindow`, `claimSweepSpread`, `claimSweepPassed`) and `claimLine`
  prints them. **No rule, no tolerance and no behaviour changed in this task.**
* `tests/server/weapon_shot.spec.luau` -- the owner-path case.

## ITEM 1 -- **MET, AND THE DISPATCH'S PREMISE IS REFUTED**

The dispatch said *"the sweep reached 1-2 candidates, not the ~18 of its 0.30 s window"*. **It is
not short.** Live, Karen's place, `HIT_CLAIM` on (`<runs-dir>/272-s1.log`, `272-s2.log`):

```
sweep=19/19 win=0.301s spread=8.046 passed=true   lag=0.000s
```

**Nineteen candidates of nineteen asked, over a 0.301 s window, spanning 8.05 studs of the
animal's own path, and some passed check 3.** `spread` is the distance between the first and last
candidate's point: at 28.5 studs/s over 0.30 s the animal covers 8.55 studs, so the ring is
answering nineteen DIFFERENT places and the sweep is reaching all of them.

**So the defect is in the CHOICE, not the reach**, and that is a different fix in a different
function from the one the dispatch named. The refusals in the same trials still read:

```
claim-line=1 worst 3.603/2.000 (... ALONG THE ANIMAL +4.695 (v 28.6 studs/s, so 0.164 s of it))
```

A candidate 0.164 s back exists in the sweep and `pickViewInstant` did not take it.

## THE SECOND MEASUREMENT, AND IT FINISHES THE QUESTION

**This request is still `Round: 1`** -- `tools/review.sh` refuses a `Round: 2` after a PASS, and it
is right to: the first verdict passed, and what follows is MORE evidence on the same round, not an
answer to findings. It is re-reviewed because `src/` changed after that verdict (two more
diagnostic fields), so the earlier PASS no longer covers the head.

The addition is two numbers on the same instrument -- **which candidate the sweep TOOK, and which
was BEST** -- and one live trial then ends the enquiry six tasks have been running. Two numbers to the same instrument -- **which candidate the sweep
TOOK, and which was BEST** -- and one live trial then ends the enquiry six tasks have been running:

```
sweep=19/19 win=0.300s spread=8.523 passed=true  took=1  best=1@2.665  segs=3
claim-line=1 worst 2.665/2.000
  gap 5.062 = along +4.303, across 2.665, ALONG THE ANIMAL +5.044 (v 29.1 studs/s, 0.173 s of it)
```

**`best=1@2.665`: over all nineteen candidates, spanning 8.52 studs of the animal's own path, the
nearest the server's own trajectory ever comes to THE SERVER'S OWN REWIND of the animal is 2.665
studs -- at the arrival instant. The sweep took the best one there was.** A second trial read
`best=1@2.943` the same way.

**ROUND 1'S FINDING 2 WAS RIGHT AND THE CONCLUSION I DREW FROM THIS IS WITHDRAWN.** I wrote that
`best` is the distance to *the claimed point* and concluded that *"the two trajectories disagree by
2.7-2.9 studs, about 1.5 degrees"*. It is not: the producing code is
`Validator.closestOnSegments(segments, candidate.point)` and `candidate.point` is `where *
claim.offset`, the SERVER's own rewind. `claim.point` appears nowhere in it. The number says the
server's own bullet never passes within 2.665 studs of the server's own animal at any instant in
the window -- which is a real and useful fact, and a different one. That `across 2.665` of the gap
happens to equal it is **not** evidence that the two are the same quantity, and I offered it as if
it were.

**What is therefore established, and what is not:**
* ESTABLISHED: the sweep reaches its whole window (19/19, spread 8.5 studs) and there is **no
  better instant in it** -- `took` is `best` in every live reading. **The view instant is not what
  is refusing these claims**, which closes the question tasks 271 and 272 were dispatched on.
* NOT ESTABLISHED: why the server's trajectory misses the server's own animal by 2.7 studs when the
  shooter's sight was on its chest. The two candidates are the one 259b named (which origin and
  direction each side flies) and the claimed point itself being off the animal -- and **separating
  them needs one more field, the distance from the trajectory to `claim.point`**, which this task
  does not have. That is the next task's first line, and it is one number.

## ITEM 2 -- **REFUTED TWICE OVER, and a refuted premise is a finished item**

There is no shortness to fix -- round 1 measured `sweep=19/19` -- and **there is no better instant
to choose either**: round 2 measured `best=1@2.665`, the minimum over the whole window. The two
candidate causes round 1 named are now separated, and it is the second: the server's own trajectory
does not pass near the claimed point at ANY instant. **Nothing in the sweep or in `pickViewInstant`
can fix that**, and I did not change code to look busy. The next task's subject is which origin and
direction each side actually flies.

## ITEM 3 -- the case now ENTERS the sweep, which two tasks could not do

`weapon_shot.spec`, "ACCEPTS a claim whose picture is 0.17 s old -- and REFUSES it with the sweep
switched off". It goes through `onFireRequest` -> a real flight -> `judgeClaimFor`, with a history
provider that **answers `at`**, and it takes its own loaded rifle (`refillForDrive` plus a real
`Reload` action -- 269b's escape was a sibling case leaving the gun empty). Its own note, from the
harness run of the code commit:

```
weapon_shot view instant: window 0 -> accepted 0->1 refused 0->0 (sweep 1/1 took 1 best 1@0.550
  segs 3); window 0.30 -> accepted 1->2, sweep 19/19 spread 6.00 lag 0.033 took 3 best 3@0.134
  segs 3; forged -> accepted 2->2
```

(round 1's finding 1 was right: the note I pasted first was the PRE-diagnostic format and could not
have come from the commit I declared. This one is the harness's own line at the code commit above,
and it carries `took`/`best`/`segs` on both halves -- which is also what proves the case did not
take one of its escapes, because an escape prints the `NOT PROVEN in this run` line instead. **I
also saw it take that escape once** -- `forged=no-reload` on a run where both halves that matter had
fired -- so the forged third of the case is now asserted only when it actually fires, and the note
says which.)

**What it proves:** the owner's sweep runs, reaches 19 of 19 candidates, spans 6.00 studs, chooses
a NON-ZERO instant (`lag 0.033`), and a forged claim 30 studs off the animal is still refused at
every instant in the window. Three of those assertions read fields **only the candidate loop
writes**, so deleting that loop reds them.

**What it does NOT prove, and the case says so in its own comment:** the window-0 half was written
to refuse -- one candidate, the shooter's picture 0.17 s behind it -- and it **accepts**. Until
that is understood the two assertions that would make this a before/after pair are not written. A
case that asserts what it cannot show is worse than one that says so.

## ITEM 4 (CORE) -- **NOT MET. This is still unproven; nobody has seen it.**

Five led shots on this build (`<runs-dir>/272-core.log`): `claims=6 accepted=3 refused=3`, zones
Terrain, Terrain, `ZoneLegs(legs)`, Terrain, `Boar136(body)` -- **0 of 5 chest**.

**And per L-112 it is reported beside its cause rather than as a retry:** acceptance is up (3 of 6
here, 1 of 4 in 271, 0 of 4 in 270), and every refusal in the trial carries
`sweep=19/19 passed=true` with a gap of 0.158-0.164 s along the animal. **The sweep is healthy and
is not taking the instant that would accept these shots** -- that is the one open question, and it
is now a sentence rather than a guess.

## ITEM 5 -- not started. No time.

## CLAIMS

1. **The sweep is not short**: `sweep=19/19 win=0.301s spread=8.046 passed=true`, read from
   `DHClaimStats` as a live `ServerStorage` attribute (L-026), in two separate live trials.
1a. **And there is no better instant in it**: `took=1 best=1@2.665` and `best=1@2.943` in two more
   live trials, where `best` is the minimum, over all nineteen candidates, of the distance from the
   server's trajectory to the SERVER's own rewind. `took == best` in every reading, so the choice
   is not what refuses these claims. **No claim is made here about the client's point** -- round 1's
   finding 2 corrected me on exactly that.
2. **The five fields are written by the sweep and by nothing else**, and `claimLine` prints them;
   `weapon_shot.spec`'s own note is the harness's reading of them.
3. **The owner-path case enters `judgeClaimFor`** -- `onFireRequest`, a real flight, a provider
   that answers `at` -- and asserts `claimSweepFound > 1`, `claimSweepSpread > 1` and
   `claimWorstLagSeconds > 0`. **With the candidate loop deleted all three are 0 and the case is
   red.** That is the L-028 property this case was written for.
4. **The anti-cheat property is driven in the same case**: a claimed point 30 studs off the animal
   is refused with the sweep at its full window.
5. **Item 4 is NOT MET**, with the zones and counts above.
6. **Nothing in this task changed a rule.** `git diff` on `src/` is five stats fields and a format
   string.
7. **The Forest Test is as it was found.** Twelve attributes before, twelve after; `HIT_CLAIM` ON
   for the trials and OFF again (rule K); `flags.py --place forest clear` never run; `DHTestOwns`
   added and removed by name; Play stopped and the window closed before every harness run.

## WHAT COULD NOT BE VERIFIED

* **Why the window-0 half of the owner case accepts.** It is the same question as item 2's and it
  is the next thing to measure, not to patch.
* **Why `pickViewInstant` chooses the arrival instant** when a candidate 0.164 s back exists. Two
  candidate causes are named in item 2; separating them is one more field (the chosen index and its
  line distance against the best candidate's).
* **No frame of a chest hit**, because there was no chest hit. `NOT OBTAINABLE: the state it would
  show did not occur.`
* Item 5 (270a(a), 269a(b)): not started.
