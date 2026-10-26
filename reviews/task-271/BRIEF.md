# BRIEF for the Architect -- task 271, `docs/design/ballistics.md`, the claim's time frame

Written by the Builder, carrying the Director's dispatch of 2026-10-26 ("fix it by construction...
keep the anti-cheat property"). **This brief overrides anything older in `docs/`, `TASKS.md` or an
earlier design** (CLAUDE.md, the BRIEF row).

## THE MEASUREMENT THAT FORCES A DECISION -- live, Karen's Forest Test, `HIT_CLAIM` on

Five tasks (266b, 268, 269, 269b, 270) have failed to land an accepted, chest-named claim on a
running deer. The refusals were `claim-line`, stable at **4.8-5.5 studs of a 2.0 budget**. Until
today nothing recorded WHICH WAY that gap lay. It does now (`<runs-dir>/271-diag.log`,
`DHClaimStats`, read as a live `ServerStorage` attribute):

```
claim-line=1 worst 5.457/2.000
  client 3088.34,147.24,-2102.95  vs  server 3090.82,148.36,-2098.61
  gap 5.120 = along -2.079, across 4.679, ALONG THE ANIMAL +5.106
              (v 28.7 studs/s, so 0.178 s of it)
  firedAtView ...437 + flight 0.0223 = arrival ...459, age +0.075
  muzzle 3030.40,144.78,-2097.04  dir 0.994,0.042,-0.101
```

**5.106 of 5.120 studs -- 99.7 % -- lies along the ANIMAL'S OWN VELOCITY.** It is 0.178 s of that
animal. The shot's own line is not the defect: both sides build the bore from the same two numbers
(the client's camera origin and direction, which ride `FireRequest`) and `BORE_ON_SIGHT_LINE` ships
`true`, so `convergeAim` answers the camera's own direction on both sides whatever either ray hit.

## THE DECISION ASKED FOR

Section 5.2's check 4 is specified as *"the server's own trajectory ... against the SERVER's own
rewind of the claimed point -- **never against the client's point**, which is what keeps a modified
client from moving the line as well as the target"*.

The measurement says that is what refuses honest shots: `serverPoint` is the animal at
`firedAtView + flightSeconds`, and `firedAtView` is the client's `Workspace:GetServerTimeNow()` --
its estimate of the server's clock NOW -- while the animal it DREW is replicated state 0.178 s
older. The server therefore rewinds to an instant the shooter never saw, and check 4 charges the
shooter for the gap. **Check 3 (`claim-moved`, `POSITION_TOLERANCE_STUDS` 6.0) already bounds
exactly that disagreement** -- *"the same animal in the same place"* -- so check 4 is charging a
second time for a distance check 3 has already allowed.

**Candidate A (the Builder's reading, offered for the Architect to accept, bound or refuse):** check
4 measures the trajectory's closest approach to **the CLIENT's claimed point**, not to the server's
rewind. Nothing else moves. The anti-cheat chain then reads: check 2 the offset is on the box;
check 3 the claimed point is within 6.0 studs of where the animal ACTUALLY was in the server's own
history; check 4 the shot was aimed there; check 5 the line of sight was clear; check 6 the clock
and the gun. A forged point in empty space still dies at check 3, and a forged LINE still dies at
check 4 because the trajectory is the server's own, re-stepped from the shot record.

**Candidate B:** the claim carries the age of the picture it was taken from (a new payload field),
clamped to a new `CLAIM.VIEW_LAG_MAX_SECONDS`, and the rewind uses `firedAtView - viewLag +
flightSeconds`. Honest, but it adds a number a client chooses, and task 269b already had a
server-side search for that instant refused for being a disguised widening of check 3.

**What the design must say either way:** which point check 4 is measured against, why, and what a
modified client can still do with the payload (section 5.4's enumerated bound).

## WHAT IS NOT BEING ASKED

No tolerance change. `LINE_TOLERANCE_STUDS` stays 2.0 under either candidate.

## ALSO OWED IN THIS FILE (task 270's escalation, unchanged and still open)

Section 4.7 step 2 (`Claim.simulate` now translates by `-velocity * (elapsed + along / speed)`, the
arrival instant, in two passes); section 4.7/5.5 (a refined cast that finds nothing is a MISS and no
claim is made for that target); section 1.4 (*"aiming AT a running animal still misses"* is absolute
and the deterministic case shows it claims the trailing body whenever the lead fits inside it).
