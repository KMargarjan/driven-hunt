# Review request — Task 266: TRUE HITS

Task: 266
Round: 2
Base: main (fb4e201c, task 265's comment fix cherry-picked by the Director)
Code commit: *(filled in below with the harness line it names)*

## PLAN (core quality protocol step 0) — committed before any `src/` edit of this round

**(a) REAL LIFE.** A bullet goes where the sights were pointing when the trigger broke, after its own
flight time. A .416 at 131 studs flies **0.052 s** (`Ballistics.timeToRange`, measured task 265
round 2), so a hind at 28 studs/s needs **1.5 studs** of lead. **That is the only lead real shooting
asks for.** Any further offset a player has to hold is not ballistics — it is the game disagreeing
with his screen.

**(b) MEASURED NOW** — two readings, both from this task's own instruments, both on Karen's path:

1. `<runs-dir>/266shot.py` (`reviews/task-266/probes/`), the trigger-frame pair: with the held view
   tracking a running animal's chest, the angle from the **trigger-frame camera** to the **animal's
   own trunk position on that frame** was **0.17°–1.58°** over five shots, i.e. **0.52–1.10 studs**
   perpendicular at 39.7–275 studs. Only the one shot inside buckshot's 100-stud range landed.
   *(`probes/MEASURED-R2.md` §"FINDING 1".)*
2. `<runs-dir>/265-lagrec.luau` + `265lag.py`, task 265 round 3: the client's copy of a moving animal
   sits **~0.17 s along its own travel** from the server's, 0 of 1049 samples the other way —
   **2.5–4.3 studs at 15–25 studs/s**. **NOT ESTABLISHED** (its only control was a motionless part,
   which reads 0.000 under any clock skew), and this design is deliberately independent of it.

**(c) TARGET.** Not a number to tune. **The shot hits what the shooter saw, whatever that offset
is** — the Director's decision, and the reason it is the right one. The numbers the design puts
against it, and which the acceptance reads:

| number | value | what it bounds |
|---|---|---|
| `CLAIM.POSITION_TOLERANCE_STUDS` | 6.0 studs | client point vs the server's own rewind (check 3) |
| `CLAIM.LINE_TOLERANCE_STUDS` | 2.0 studs | the server's trajectory vs the claimed point (check 4) — **this is what makes the zone geometric rather than chosen** |
| `CLAIM.AGE_MAX_SECONDS` | 0.5 s | how old a claimed arrival may be (check 6) |
| `CLAIM.FLIGHT_TOLERANCE_SECONDS` | 0.03 s | the claimed flight time vs `timeToRange` (check 6) |
| `HISTORY.SAMPLES` | 64 | 1.07 s at 60 Hz — must cover `AGE_MAX_SECONDS`, asserted in `zz_claim_window.spec` |

**6.0 studs and not 0.5**: the shared clock is **unestablished**, so a tight bound here would refuse
every honest claim; one `Boar.CONFIG.BODY_SIZE` (5.5) rounded up means *the same animal in the same
place*, and check 4's 2.0 studs is what actually pins the zone. `stats.claimWorstStuds` reports the
worst **accepted** disagreement so the number can next be argued from evidence — the instrument idiom
`stats.originFarthest` already uses.

**(d) LEVER** — the writer exists, and it is one expression:

```
$ grep -n "aimPoint = \|local origin = \|local aim = \|safetySignal:Fire" src/server/Weapon/init.luau
1392:	local aimPoint = if aimImpact then aimImpact.position else req.origin + req.direction * range
1405:	local origin = Ballistics.boreOrigin(req.origin, req.direction, muzzle, CONFIG.BORE_ON_SIGHT_LINE)
1406:	local aim = Ballistics.convergeAim(origin, aimPoint, req.direction, CONFIG.MIN_AIM_DISTANCE)
1592:			safetySignal:Fire(player, aim, origin, stopAt)
$ grep -n "FireRequest:FireServer" src/client/Weapon/Input.luau
139:	remotes().FireRequest:FireServer({ origin = cframe.Position, direction = cframe.LookVector.Unit })
$ grep -n "finished\[#finished + 1\]" src/server/Weapon/Flight.luau
316:			finished[#finished + 1] = { shot = shot, impacts = live.impacts }
```

Read them by symbol, not by number (CLAUDE.md; the numbers are here only because step 0(d) asks for
pasted grep). **`Weapon.onShotLanded`'s `res.impacts` is the writer of what a shot hit** — that list
is what `Hits.group` is given, and the accepted claim **truncates it to one impact**. `Input.fire` is
the one firer of `FireRequest` and gains one optional field. `Flight.advance`'s `finished[...]` row
is where `reachedStuds` joins the `Resolution`.

**(e) HOW IT WILL BE MEASURED AFTER.** The same instrument as (b)1: `266shot.py`, printing for one
real click the aim point, the server's impact **in the animal's own frame**, and the client's mark,
with `ShotFired` counted separately from `ShotLanded`. Plus, new this round, `Weapon.stats()`'s
`claims / claimsAccepted / claimsRefused / refusedClaimBy / claimWorstStuds / claimWorstLineStuds`,
read off the live server.

**(f) WHAT I AM NOT DOING, SAID HERE SO IT IS NOT SILENTLY DROPPED (L-090).** The nine clicks at the
stand that produced `ShotFired=0` in round 1 are **still undiagnosed** and this round does not
diagnose them. The dispatch does not put them in scope; what it does require is `aimshot --selftest`
at **5/5 before the proof**, which is a live check that the trigger reaches the game, so the
condition is detected even though its cause is not. If the selftest fails, that is the instrument and
I stop on it.
