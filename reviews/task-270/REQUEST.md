# Task 270 -- settle the lead, by construction first, then live

Task: 270
Round: 1
Base: `1bc7a907` (this Builder's 269b head; its code comes with it)
Code commit: (filled in with the harness line)

## PLAN

### (a) REAL LIFE

A bullet takes time. At the scoped .416's 2612 studs/s the flight to 100 studs is **0.0393 s**, and
an animal crossing at **20 studs/s** (5.6 m/s) travels **0.79 studs** in that time. At 150 studs and
30 studs/s it is **1.79 studs**. A shooter who holds on the animal hits BEHIND it by exactly that;
one who holds ahead by it hits where he looked. That is the whole of the sign this task settles.

### (b) MEASURED NOW

Two readings that disagree, which is why this task exists:

* **LIVE (269b, Karen's place, `HIT_CLAIM` on, `<runs-dir>/269b-d2.log` and `269b-d3.log`):** the
  two accepted claims of the LED trial named `rear`; the only two `chest` zones of the session came
  from the UNLED trial. 0/5 chest led, 2/5 chest unled.
* **SPEC (today's `tests/client/weapon_client.spec.luau`):** *"aiming AT a sprinting target produces
  NO claim"* and *"aiming AHEAD by the ballistic lead produces a claim on the target"* -- both pass,
  and both are at **200 studs only**.

**And there is a reading of the code that explains both**, which the deterministic case is built to
confirm or refute: `Claim.simulate` translates the segment by `-target.velocity * pellet.elapsed`,
and `pellet.elapsed` is **0 for the whole first sub-step**. One sub-step at the rifle's muzzle speed
is `FLIGHT_STEP_MAX_SECONDS` long -- **~87 studs** -- so at 40, 100 and 150 studs the animal is not
advanced at all, while at the 200 studs the existing cases use it is. If that is right, every rifle
shot inside 87 studs claims the animal where it is NOW, the shooter's own lead is then uncancelled,
and the two readings above are the same fact seen from two ranges.

### (c) TARGET

With a target crossing at `v` and the rifle at range `d`, writing `t = Ballistics.timeToRange(shot, d)`:

* **(a) aiming at the CURRENT chest lands behind it by `v x t`** -- the offset along the travel axis
  is `-v x t`, within a quarter of a stud;
* **(b) aiming at the chest + `v x t` lands ON it** -- that offset is `0`, within a quarter of a
  stud;
* and the server ACCEPTS both claims.

A quarter of a stud because `LINE_TOLERANCE_STUDS` is 2.0 and the chest box is 2 studs across: a
test that could not tell a quarter stud from zero could not tell the chest from the shoulder. Nine
combinations: `v` in {10, 20, 30} studs/s, `d` in {40, 100, 150} studs -- three of them inside one
sub-step, three straddling it, three beyond.

### (d) LEVER

```
src/client/Weapon/Claim.luau:201:			local shift = target.velocity * pellet.elapsed
src/client/Weapon/Claim.luau:202:			local hit = castOnly(target.root)(pellet.position - shift, segment, staticIgnore)
src/client/Weapon/Claim.luau:243:					point = hit.position + shift,
src/client/Weapon/Claim.luau:247:					flightSeconds = pellet.elapsed + (bestAlong / math.max(1e-6, pellet.velocity.Magnitude)),
src/shared/Ballistics/init.luau:377:function Ballistics.leadStuds(shot: Shot, studs: number, targetStudsPerSecond: number): number
```

`shift` is the one writer of the animal's own advance, and `pellet.elapsed` is the one thing it is
built from. Note that line 247 already knows the better number -- `elapsed + along/speed` is the
time at the IMPACT, and the shift two lines above uses only the first term.

### (e) HOW IT IS MEASURED AFTER

The same deterministic case, which is the instrument: it needs no Studio clock, no drive, no animal
and no instrument lag, so the before and the after are the same arithmetic. The live re-measurement
(item 3) then uses `<runs-dir>/268kill.py` + `proof268.py` unchanged, exactly as 269 and 269b did.

### On L-028 and L-112

The new case asserts the numbers in (c). **If the double lead is real it goes red on today's code
at 40, 100 and 150 studs and stays green at 200**, and that split is itself the diagnosis. And
nothing here is delivery of the core item: **item 3 is met only by the live re-measurement in
Karen's place**, not by this case passing (L-112).

## WHAT CHANGED

(filled in)

## CLAIMS

(filled in)
