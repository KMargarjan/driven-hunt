# Task 270 -- settle the lead, by construction first, then live

Task: 270
Round: 1
Base: `1bc7a907` (this Builder's 269b head; its code comes with it)
Code commit: `4f74b487fb012a08ed61b2e56ddd41764324399e`

```
[harness] PASS: 34/34 checks @ 4f74b487fb012a08ed61b2e56ddd41764324399e (clean tree) scope=all
```

`test2` is **N/A**: the changed files are `src/client/Weapon/Claim.luau` and
`tests/client/weapon_client.spec.luau`, neither in `TWO_PLAYER_PATHS`.

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

* `src/client/Weapon/Claim.luau` -- the target pass advances each animal to **the instant the
  bullet actually arrives**, not to the start of the sub-step, and the refinement is the answer
  rather than a suggestion.
* `tests/client/weapon_client.spec.luau` -- the deterministic lead-sign case: 3 speeds x 4 ranges,
  asserting the offset ALONG the travel axis for an aimed-at shot and a led one.

## ITEM 1 -- **MET, and the premise is REFUTED in a useful direction**

**The lead's SIGN was never wrong. The lead was QUANTISED.** `Claim.simulate` advanced each target
by `target.velocity * pellet.elapsed`, and `pellet.elapsed` is the clock at the sub-step's FIRST
edge. One sub-step at the rifle's 2612 studs/s is `FLIGHT_STEP_MAX_SECONDS` -- about **87 studs** --
so everything inside the current sub-step was thrown away, and inside 87 studs the animal was not
advanced **at all**.

**THE CASE WAS RED FIRST** (L-028), and this is the table it printed on the base commit, a target
crossing at 30 studs/s:

| range | the lead that exists | the lead the pass applied | error |
|---|---|---|---|
| 40 | 0.463 studs | **0.000** (sub-step 1) | 0.463 -- the WHOLE lead |
| 100 | 1.174 | 1.000 (sub-step 2) | 0.174 |
| 150 | 1.779 | 1.000 (sub-step 2) | 0.779 |
| 200 | 2.399 | 2.000 (sub-step 3) | 0.398 |

**And that is why the two readings in (b) disagreed**: the existing cases are all at 200 studs,
where the quantised value is 83 % of the real one and the case passes; Karen shoots at 30-150, where
it is 0-85 % and the shooter's own lead is left uncancelled.

**After** -- the same case, same arithmetic, twelve rows: **worst |error| 0.009 studs**. Every led
shot lands on the chest (`LED -> -0.001 .. 0.009`) and every aimed-at shot lands behind it by `v x t`
(`AT -> -0.153` at 40 studs for v=10, `-0.459` for v=30, and so on) -- except the two rows where the
lead is wider than the box's own half-extent, where the honest answer is a miss and the case says so.

The fix is two passes: the first finds `along`, the second re-asks with the animal moved to
`elapsed + along / speed` -- the expression `flightSeconds` is already built from, two lines below.
**A second pass that finds nothing is a MISS**, and the case proves that too (v=20, d=150: the lead
1.186 is wider than the box's 1.0 half-extent and the shot passes behind).

## ITEM 3 (CORE) -- **NOT MET. This is still unproven; nobody has seen it.**

Five led shots at staged running deer in Karen's Forest Test, `HIT_CLAIM` on, the fix shipped, the
same instrument as 269 and 269b (`<runs-dir>/270-led.log`):

```
enabled=true claims=4 accepted=0 refused=4 [claim-line=4 worst 4.858/2.000]
```

Zones: `Boar23(body)`, `Boar58(body)`, Terrain, Terrain. **0 of 5 chest, 0 accepted.**

**And the number has MOVED THE WRONG WAY**, which I will not round off: 269b's clean trial read
`claim-line worst 4.778/2.000`; this one reads **4.858**. The quantisation this task removed was
0.5-1.8 studs; the live `claim-line` gap is 4.9. **So the quantised lead was real, was worth fixing,
and is NOT what is refusing these claims.** Whatever is, it is bigger than the thing just removed
and it is not in `Claim.simulate`'s own arithmetic -- that arithmetic is now exact to 0.009 studs
against a scripted world.

## ITEM 2 -- **NOT DONE.** 269b's fixture still escapes

The owner-wiring case still sits after the accept case, which leaves the same rifle empty. The box
went on item 1 and item 3; it is not started, and it is not reported as anything else.

## ITEM 4 (269a(b)) -- **NOT DONE.** Same reason.

## CLAIMS

1. **The lead's sign is settled by construction**: `tests/client/weapon_client.spec.luau`, "lands
   BEHIND by v x t when aimed AT, and ON when led -- at 40, 100 and 150 studs too". Twelve rows,
   three speeds and four ranges, asserting the offset along the travel axis against
   `Ballistics.leadStuds`' own number -- never a number typed in the case.
2. **It fails on the base commit.** The table above is what it printed there; the case lists every
   wrong row before it asserts, so a red run is a diagnosis. Twelve of twelve rows were out at
   40/100/150/200 on the base commit; the worst was 0.779 studs.
3. **The producer cannot be deleted silently**: remove the refinement and the case goes red on
   every row inside one sub-step, because the whole lead comes back.
4. **The refinement is bounded and cannot invent a hit**: it is one extra cast per target per
   sub-step, and a second pass that finds nothing drops that target for that sub-step rather than
   keeping the coarse answer. The case drives that branch (v=20, d=150).
5. **Item 3's live result is a worsening by 0.08 studs on `claim-line`, not an improvement**, and is
   reported as NOT MET. `DHClaimStats` read as a live `ServerStorage` attribute, never through
   `require` (L-026).
6. **The Forest Test is as it was found.** Twelve attributes before, twelve after; `HIT_CLAIM` set
   ON for the trial and OFF again (rule K); `flags.py --place forest clear` never run; `DHTestOwns`
   added and removed by name; Play stopped and the window closed before the harness ran.

## WHAT COULD NOT BE VERIFIED

* **No frame of a chest hit was taken, because there was no chest hit to photograph.** The five
  shots named `body` twice and Terrain twice, and one produced no report. `NOT OBTAINABLE: the state
  the frame would show did not occur.`
* **What the remaining 4.9 studs of `claim-line` is.** It is lag-scale (0.16 s of animal at 30
  studs/s) and it is bigger than everything this task removed. The next measurement is the one 269b
  queued: record the worst REFUSED `trajectoryPoint`/`serverPoint` pair itself, not only its
  magnitude, so the direction of the gap can be read -- along the line, across it, or in time.
