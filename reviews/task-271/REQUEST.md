# Task 271 -- why `claim-line` refuses honest shots, by construction

Task: 271
Round: 1
Base: `0b74c239` (`main`, after #250)
Code commit: `4bb6405960cdf0f2737360e6bbddb6a1363fe23d`

```
[harness] PASS: 34/34 checks @ 4bb6405960cdf0f2737360e6bbddb6a1363fe23d (clean tree) scope=all
```

`test2` is **N/A**: the changed files are `src/shared/Shotgun/`, `src/server/Weapon/`,
`src/server/Boar/init.luau` and three server specs -- none in `TWO_PLAYER_PATHS`.

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

* `src/server/Weapon/init.luau` -- a `claim-line` refusal prints the **pair**, decomposed on three
  named axes (item 1); the geometric checks are evaluated at the **view instant** swept from the
  server's own history (item 2); `Weapon.viewWindowFor`; `claimWorstLagSeconds`.
* `src/server/Weapon/Validator.luau` -- `closestOnSegments` (the owner's own loop MOVED) and
  `pickViewInstant` (new), both pure. **`judgeClaim` is unchanged, bit for bit.**
* `src/shared/Shotgun/init.luau` -- four `CLAIM` rows: `VIEW_LAG_BASE_SECONDS` 0.30,
  `VIEW_LAG_MAX_SECONDS` 0.45, `VIEW_LAG_STEP_SECONDS` 1/60, `VIEW_LAG_MAX_SAMPLES` 28.
* `src/server/Boar/init.luau` -- `HISTORY.SAMPLES` 64 -> 96, because the ring must span the new
  window with the 1.5x margin `zz_claim_window.spec` already demanded.
* `docs/design/ballistics.md` -- **v4, written by the Architect**, to `reviews/task-271/BRIEF.md`.
  `reviews/task-271/ARCH_RESULT.md` is `PASS`.
* three server specs.

## ITEM 1 -- **MET, and it is the first time in six tasks that the cause has a direction**

One `claim-line` refusal, live, Karen's place, `HIT_CLAIM` on (`<runs-dir>/271-diag.log`):

```
claim-line=1 worst 5.457/2.000
  client 3088.34,147.24,-2102.95  vs  server 3090.82,148.36,-2098.61
  gap 5.120 = along -2.079, across 4.679, ALONG THE ANIMAL +5.106
              (v 28.7 studs/s, so 0.178 s of it)
  firedAtView ...437 + flight 0.0223 = arrival ...459, age +0.075
  muzzle 3030.40,144.78,-2097.04  dir 0.994,0.042,-0.101
```

**5.106 of 5.120 studs -- 99.7 % -- lies along the ANIMAL'S OWN VELOCITY.** The two sides did not
disagree about where; they disagreed about **when**. The residual perpendicular to the animal's
path is `sqrt(5.120^2 - 5.106^2)` = **0.38 studs**, which is a fifth of the 2.0 budget. **The line
was never the defect and the tolerance never needed to move.**

## ITEM 2 -- built to the Architect's v4, not to my own reading

I wrote the BRIEF with the measurement and two candidates; the Architect **refused both** and
specified a third (section 5.2.1): the server sweeps its **own** history backwards over a window it
owns and judges at the one instant **its own trajectory** came closest -- among the instants that
pass check 3. Check 4's target is still the server's own rewind, never the client's point, and no
tolerance moved. `arrivalAt` is always candidate 1, so v4 is a strict superset of v3.

**Why this is not task 269b's refused search, in one line:** that one minimised check 3's own
expression; this minimises check 4's, whose left-hand side is the server's own re-step of the shot,
and `claim.point` appears in neither term of it.

## ITEM 3 (CORE) -- **NOT MET. This is still unproven; nobody has seen it.**

Five led shots on the v4 build (`<runs-dir>/271-v4.log`):

```
enabled=true claims=4 accepted=1 refused=3 lag=0.033s
[claim-blocked=1 worst 3.385/1.000 (... stopped by Workspace.Boars.Boar34.ZoneRear)
 claim-line=2 worst 3.891/2.000 (... ALONG THE ANIMAL +3.865 (v 23.8 studs/s, so 0.163 s of it))]
```

Zones: `rear`, a tree, `rear`, `body`, `body`. **0 of 5 chest.** Against the same instrument,
269b read 2 of 4 accepted and 270 read 0 of 4, so 1 of 4 is inside the noise of those two.

**AND THE NEW INSTRUMENT SAYS WHY, WHICH IS THE VALUE OF THIS ROUND:** `lag=0.033s`. That is
`claimWorstLagSeconds`, the worst **accepted** view instant, and it is **two grid steps**. The
refused shot in the same trial needed **0.163 s**. So the sweep is reaching one or two steps back
and not the twenty it is configured for -- the window is 0.30 s and `VIEW_LAG_STEP_SECONDS` is
1/60, so eighteen candidates were asked for and the evidence says they were not found. The two
places that can do that are `askWhereWas` answering nil for the older instants (the loop then
breaks on its first nil after a hit) and `pickViewInstant` filtering them out on check 3. **I did
not get to separate those two before the box ran out**, and I am not going to guess between them
in a request.

## ITEM 4 -- **MET.** The Architect was run by me

`tools/architect.ps1 design ballistics --task 271`, in the foreground, with
`reviews/task-271/BRIEF.md` written first. Verdict `PASS`; v4 is 1215 insertions over 980
deletions and carries task 270's three owed edits as well.

## CLAIMS

1. **The decomposition is in the one place every refusal passes through** (`refuse`'s `note`), and
   it changed no rule: `judgeClaim` is unchanged bit for bit this task.
2. **`closestOnSegments` and `pickViewInstant` are pure and are driven from both sides**:
   `weapon_hits.spec`, five cases -- the closest approach of a walked line including the
   behind-the-start case and the empty list; the sweep picking the instant the trajectory came
   closest; the sweep REFUSING an instant that fails check 3 however close the line is; the
   no-candidate-passes case answering the best `movedStuds` so the refusal names `claim-moved`;
   and the empty sweep answering nothing rather than a zero. **All five fail on the base commit --
   neither function existed there.**
3. **v4 is a strict superset of v3**, asserted: given only the arrival instant, `pickViewInstant`
   answers the arrival instant.
4. **The ring spans the new window with margin**: `zz_claim_window.spec` now sizes
   `HISTORY.SAMPLES / 60` against `AGE_MAX + VIEW_LAG_MAX + 1/60` and holds the 1.5x it always
   held; 96/60 = 1.60 s against 0.967 s is 1.66x. At 64 it was 1.10x and the spec refused it --
   which is the spec doing its job on a config change, not a number chosen to fit.
5. **The live accept path still runs and still accepts**: `weapon_shot accepted claim: rifle/Slug,
   1 report(s), accepted 0 -> 1, worst 0.000/0.027, refusedClaimBy []`, from the harness run of the
   code commit.
6. **Item 3 is NOT MET**, with the counts above, and `lag=0.033s` is reported as the open question
   rather than dressed up.
7. **The Forest Test is as it was found.** Twelve attributes before, twelve after; `HIT_CLAIM` ON
   for the two trials and OFF again (rule K); `flags.py --place forest clear` never run;
   `DHTestOwns` added and removed by name; Play stopped and the window closed before every harness
   run.

## WHAT COULD NOT BE VERIFIED

* **Why the sweep only reaches 0.033 s.** Named above as the next measurement, with the two
  candidate causes. It is one probe: print `#candidates` and the `anyPassed` flag beside the lag.
* **L-028's and L-093's requirement for a case at `SPRINT_SPEED` 38 that enters the coarse-gated-out
  arm: NOT DONE.** This task did not touch `Claim.simulate`'s coarse gate -- that is task 270a(a),
  still queued -- so no case here enters it, and I am not claiming one does.
* **No frame of a chest hit**, because there was no chest hit. `NOT OBTAINABLE: the state it would
  show did not occur.`
