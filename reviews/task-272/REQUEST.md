# Task 272 -- the sweep reaches its whole window, and a case enters it

Task: 272
Round: 1
Base: `813b76b0` (this Builder's 271 head; its code comes with it)
Code commit: `fd87409cd833c494ed258f08599cee717a8e1c17`

```
[harness] PASS: 34/34 checks @ fd87409cd833c494ed258f08599cee717a8e1c17 (clean tree) scope=all
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

## ITEM 2 -- **REFUTED AS WRITTEN, and a refuted premise is a finished item**

There is no shortness to fix. What the measurement now indicts is one of two things inside
`Validator.pickViewInstant`: the check-3 filter removing the right candidate, or the trajectory
distance being minimised at the arrival instant anyway -- **which would mean the server's own
re-stepped trajectory does not pass near the point the client claimed, whatever instant is chosen.**
The decomposition supports the second: the measured gap carries `across 3.405` of a 5.110 total,
and an across-track component does not shrink by rewinding time. **I did not change code on a guess
with 40 minutes left.**

## ITEM 3 -- the case now ENTERS the sweep, which two tasks could not do

`weapon_shot.spec`, "ACCEPTS a claim whose picture is 0.17 s old -- and REFUSES it with the sweep
switched off". It goes through `onFireRequest` -> a real flight -> `judgeClaimFor`, with a history
provider that **answers `at`**, and it takes its own loaded rifle (`refillForDrive` plus a real
`Reload` action -- 269b's escape was a sibling case leaving the gun empty). Its own note, from the
harness run of the code commit:

```
weapon_shot view instant: window 0 -> accepted 0->1 refused 0->0;
  window 0.30 -> accepted 1->2, sweep 19/19 spread 6.00 lag 0.033; forged -> accepted 2->2
```

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
