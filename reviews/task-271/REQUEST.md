# Task 271 -- why `claim-line` refuses honest shots, by construction

Task: 271
Round: 1
Base: `0b74c239` (`main`, after #250)
Code commit: (filled in with the harness line)

## PLAN

### (a) REAL LIFE

A shooter hits what he can see. The animal on his screen is the animal he may shoot, and the time
his picture is behind the world is the server's problem, not his. At the 30-34 studs/s this world's
deer run, **one 60 Hz replication interval is 0.5 studs and 0.1 s of view lag is 3.0-3.4 studs** --
half a body length of a 6.03-stud deer.

### (b) MEASURED NOW

Task 270, five led shots in Karen's Forest Test with `HIT_CLAIM` on, the quantised lead already
fixed (`<runs-dir>/270-led.log`, `DHClaimStats` read as a live `ServerStorage` attribute, L-026):

```
enabled=true claims=4 accepted=0 refused=4 [claim-line=4 worst 4.858/2.000]
```

and 269b's clean trial, same instrument: `claim-line worst 4.778/2.000`, 2 of 4 accepted. **The
number is stable at 4.8 studs across two builds and it is 2.4x its budget.** At 30 studs/s that is
**0.16 s of animal**.

**And what it is 4.8 studs OF is not recorded anywhere.** `claim-line` publishes a magnitude:
`|trajectoryPoint - serverPoint|`. Whether that gap lies ALONG the shot, ACROSS it, or along the
ANIMAL'S OWN TRAVEL -- which is what distinguishes an aiming error from a time error -- is not in
`DHClaimStats` and no probe has read it. That is this task's item 1 and nothing is changed before it.

### (c) TARGET

* **Item 1:** for three refused live shots, the two points are printed as a PAIR and decomposed on
  three named axes -- along the shot, across the shot, and along the animal's own velocity -- with
  the instants and the origins beside them. Three axes because they are the three different
  defects: a line error, an aim error and a time error, and a scalar cannot tell them apart.
* **Item 3 (CORE):** **at least 4 of 5 led shots at a staged running deer are ACCEPTED claims
  naming the chest, with the mark on the chest and a frame.**

### (d) LEVER

```
src/server/Weapon/init.luau:1532:	local rewound = askWhereWas(claim.part, arrivalAt)
src/server/Weapon/init.luau:1535:	local serverPoint = rewound * claim.offset
src/server/Weapon/init.luau:1890:	local origin = Ballistics.boreOrigin(req.origin, req.direction, muzzle, CONFIG.BORE_ON_SIGHT_LINE)
src/server/Weapon/init.luau:1891:	local aim = Ballistics.convergeAim(origin, aimPoint, req.direction, CONFIG.MIN_AIM_DISTANCE)
src/server/Weapon/Validator.luau:170:	local line = (facts.trajectoryPoint - facts.serverPoint).Magnitude
src/server/Weapon/init.luau:1453:	local function refuse(reason: string, measured: number?, budget: number?, note: string?)
```

`refuse` is the one place every refusal passes through and it already carries a `note` (task 269b),
so item 1 is a note with a decomposition in it and changes no rule. **The lever for item 2 is not
chosen**, deliberately: the dispatch names two candidates (the server's reconstructed line, and the
coarse gate), and which one the number indicts is item 1's answer, not a guess.

**What the reading of the code already says, so the measurement can confirm or refute it rather
than discover it:** both sides compute the bore from the SAME two numbers -- the client's camera
origin and direction, which ride the `FireRequest` -- and `CONFIG.BORE_ON_SIGHT_LINE` ships `true`,
so `convergeAim` answers the camera's own direction whatever either side's ray hit. The LINE should
therefore already agree. What cannot agree is the INSTANT: `claim.firedAtView` is the client's
`Workspace:GetServerTimeNow()`, which is its estimate of the server's clock NOW, while the animal
it drew is replicated state that is already some frames old. If the 4.8 studs lies along the
animal's own velocity, that is the defect; if it lies across the shot, the reading of the code is
wrong and the line is.

### (e) HOW IT WILL BE MEASURED AFTER

The same instrument: `<runs-dir>/268kill.py` + `proof268.py`, five led shots at a staged running
deer, `DHClaimStats` read live. The decomposition from item 1 is in the same attribute, so the
before and the after are one reading.

### On L-028 and L-093

Task 270's own case validated only 10/20/30 studs/s, all under the `SPRINT_SPEED` 38 at which the
COARSE gate's offset (`v * FLIGHT_STEP_MAX_SECONDS` = 1.27 studs) exceeds a 1.0-stud half-extent --
so "every LED row green" was a check that could not fail there. **Any fix to the coarse gate must
be driven at 38 and above**, and one case must enter each branch: a shot the coarse pass already
found, and one it would have gated out.

## WHAT CHANGED

(filled in)

## CLAIMS

(filled in)
