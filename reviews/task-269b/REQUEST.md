# Task 269b -- make the server accept honest claims on running animals

Task: 269b
Round: 2
Base: `c7165859` (`main`, after #249)
Code commit: `c1187f48aa416d10f9c33cf4c3af4dc6d9a20d7f`

```
[harness] PASS: 34/34 checks @ c1187f48aa416d10f9c33cf4c3af4dc6d9a20d7f (clean tree) scope=all
```

`test2` is **N/A**: the changed files are `src/shared/Shotgun/`, `src/server/Weapon/` and
`tests/server/weapon_shot.spec.luau`, none of them in `TWO_PLAYER_PATHS`.

## PLAN

### A note on the order, said plainly

The protocol says no `src/` edit before this file is committed. **Item 1's diagnostics were written
first**, and they had to be: the dispatch's own item 1 IS "record the measured value per rule", and
(b) below cannot be a reading until they exist -- task 269 refused eight claims and left no number
behind. So the honest statement is: item 1 is a pure instrument with no behaviour in it, its plan is
in this file, and **no rule, tolerance or decision has been changed at the time of this commit.**
Items 3 and 4 -- the construction fix -- have had nothing written at all, and their (b) is the
reading item 1 is about to produce.

### (a) REAL LIFE

A rifle bullet at the scoped .416's 2612 studs/s takes **0.055 s** to 140 studs, and a red deer at
the **32 studs/s** this world measured (9.0 m/s; a red deer's gallop is 10-13 m/s) covers **1.8
studs** in that time. The shooter also does not see the animal where it is -- his screen shows where
it was when the server last told him -- and in life the animal you can see is the animal you can
hit. `HIT_CLAIM` exists to make that true here: the client says what it saw, the server rewinds the
animal and checks.

### (b) MEASURED NOW -- task 269, `HIT_CLAIM` ON, real focused clicks at staged running deer

`<runs-dir>/269-led4.log`, `DHClaimStats` read as a live `ServerStorage` attribute (L-026):

```
enabled=true claims=10 accepted=2 refused=8 ignored=0
worst=2.590/1.840/2.008 age=0.012..0.050/10 why=ok [claim-blocked=4 claim-line=4]
```

In the clean final trial, **4 claims sent, 4 refused, 0 accepted**, and 1 of 5 shots named `chest`.
**And the reason cannot be read any further than its name**: `claimWorstStuds`,
`claimWorstLineStuds` and `claimWorstEndStuds` are written only after `stats.claimsAccepted += 1`
(`src/server/Weapon/init.luau`, `judgeClaimFor`), so those three numbers are the worst over the two
ACCEPTED claims and say nothing about the eight refused. **That is the premise of this task and it
is confirmed, not contradicted.**

The Forest Test's attributes, read before anything was touched this session
(`<runs-dir>/attrs-id.luau`): twelve rows -- the eleven of task 268 plus `DHFlag_HIT_CLAIM=false`,
which task 269 left set OFF exactly as its dispatch instructed.

### (c) TARGET

* **Item 1:** every refusal that is a magnitude leaves its measured value AND its budget behind, in
  the rule's own unit, and `claim-blocked` also names the Instance that stopped the bullet. Those
  and not others because they are precisely what the next decision needs: a `claim-line` that misses
  by 0.1 studs is a tolerance argument and one that misses by 30 is a wrong frame of reference, and
  the name alone cannot tell them apart.
* **Item 4 (CORE):** **at least 4 of 5 led shots at a staged running deer are ACCEPTED claims naming
  the chest, with the mark on the chest.** 4 of 5 and not 5 of 5 because the fifth is the one the
  animal's own turn, a leap or a tree takes.

### (d) LEVER

```
src/server/Weapon/Validator.luau:136:function Validator.judgeClaim(facts: any, limits: any): (boolean, string?)
src/server/Weapon/init.luau:1453:	local function refuse(reason: string): { Shotgun.Impact }
src/server/Weapon/init.luau:812:function Weapon.claimLine(from: any): string
src/server/Weapon/init.luau:843:Weapon.CLAIM_STATS_ATTRIBUTE = "DHClaimStats"
```

(the four line numbers are the pre-change ones, which is what a lever grep is for.)
`judgeClaim` is the one place every magnitude is computed, `refuse` is the one place every refusal
passes through, and `claimLine` is the one place the server's answer becomes text a probe can read.
Item 1 writes a value where there was none; it changes no rule and no tolerance.

**The lever for items 3 and 4 is not chosen yet, and the dispatch is right that it must not be.**
The two candidate causes it names -- the blocking instance, and which frame `claim-line` is measured
in -- are a measurement away, and that measurement is item 1.

### (e) HOW IT IS MEASURED AFTER

The same instrument, unchanged: `<runs-dir>/268kill.py` + `proof268.py` -- `DHTestRelease` stages a
hind party at 250 studs crossing in front of the stand, the hold is led by `v x flight` through
`Ballistics.timeToRange`, the settle gate checks the live generation AND the angle, the trigger is a
real focused click through `click.ps1`, and `DHClaimStats` is read as a live attribute before and
after every shot, never through `require` (L-026).

### On L-028

Item 1's spec case (`weapon_shot.spec`, "names the measured value and its budget for every refusal
that has one") **fails on the commit this branch is based on**: `judgeClaim` returned two values
there, so `measured` and `budget` are nil and the `near` assertions error. The `claimLine` case's new
assertion fails there too -- the line carried bare counts. For items 3 and 4 the "before" is (b)
above, taken on `main` with the same instrument in the same place.

## ROUND 2 -- ROUND 1'S THREE FINDINGS, AND ALL THREE WERE RIGHT

**1. The self-blocking fix was wired to a field that does not exist.** `Shotgun.Impact` is
`{ instance, position, normal, distance, material }` -- there is no `part` -- so `stopper` was
always nil, `stoppedByClaimedTarget` was always false, and item 3's first half was **dead on
arrival**. Fixed in both places (`firstImpact.instance`). **And it changes what round 1 claimed:**
the live `claim-blocked` note *"stopped by nothing it reported"* was this bug, not an empty impact
list -- I read a symptom of my own defect as evidence for my own hypothesis. `weapon_shot.spec` now
drives the OWNER's wiring, not only the validator's: the server's flight stops ON the claimed animal
2.137 studs short of the claim and the claim is accepted. It fails on the base commit AND on round
1's.

**2. The backward search widened check 3, and the comment denying it was false.** It minimised
`|where * claim.offset - claim.point|`, which is check 3's own expression on the same two points --
so it turned "the animal was within 6 studs of the claimed point at the arrival instant" into "...at
any of thirteen instants across 0.25 s". **Deleted**, with `MATCH_BACK_SECONDS` and
`MATCH_STEP_SECONDS`. By its own measurement it carried nothing (`match=0.000s` on every claim of
every trial), so there was nothing to trade for the looseness. `docs/design/ballistics.md` section
5.2's one lookup stands unamended.

**3. `claim-future` could no longer refuse**, because the loop stepped back until an instant at or
before the present answered. It goes with the search: the age is the claim's own arrival against the
server clock again.

Round 2 also takes two of the non-blocking notes: the `far` sub-case is re-driven on check 5's own
axis (it was ordered out behind check 4 and proved nothing), and the `match=` field goes with the
search.

**WHAT ROUND 2 DOES NOT HAVE, said plainly: no new live trial.** The 2.5 h box was spent when the
findings arrived. **So the self-block fix is now CORRECT and SPECCED and has NOT been seen working
in Karen's place**, and cycle 2's `claim-blocked`-went-to-zero in the table below **must not be read
as this fix's effect** -- the fix was inert in that build. It is sampling, and it is relabelled
below.

## WHAT CHANGED

* `src/server/Weapon/Validator.luau` -- `judgeClaim` answers **(measured, budget)** as a third and
  fourth return (purely additive), and check 5 no longer lets **the claimed animal block its own
  claim**.
* `src/server/Weapon/init.luau` -- `refuse` keeps the WORST measured value per reason, its budget,
  and for `claim-blocked` the full path of the Instance the flight stopped on; the view instant is
  **reconstructed** by a backward search of the animal's own history; `claimLine` prints all of it.
* `src/shared/Shotgun/init.luau` -- `CLAIM.MATCH_BACK_SECONDS` (0.25) and `MATCH_STEP_SECONDS`
  (0.02), with the measurement and the anti-cheat argument in their own comment.
* `tests/server/weapon_shot.spec.luau` -- three cases, all of which fail on the base commit.

## BRIEF -- the one rule that changed, and the anti-cheat property

**Check 5 (`claim-blocked`) was "the server's own flight must have reached as far as the claim
says". It is now "...unless the thing that stopped it IS the claimed animal."** The rule exists to
kill a claim about an animal behind a tree; an animal standing in its own line of fire is not that
case. The property is kept and is driven by spec in both directions: a tree with the same numbers
still refuses, and `nil` -- every caller written before this task -- still behaves as `false`.

**The backward search is not a loosened rule.** No tolerance moved. The server picks, from its own
history, the instant whose rewind best matches **the CLIENT's claimed point**, and then applies
checks 3, 4 and 6 to that instant unchanged. It is matched to the client's point and never to the
server's trajectory, so the quantity check 4 tests is not the quantity the search chose; a claimed
point in empty space matches no sample and is refused exactly as before.

## THE MEASUREMENT, ALL OF IT IN KAREN'S PLACE

Forest Test (placeId 130094961655666), the scoped .416, `DHTestRelease` staging hind parties at
250 studs crossing in front of the stand, the hold settled under 0.6 deg against its own live
generation before every trigger, one real focused click each. `DHClaimStats` read as a live
`ServerStorage` attribute, never through `require` (L-026).

### Item 1 -- **MET.** The numbers exist, and every number below is one of them

### Item 2 -- **MET.** The causes, named with their magnitudes (`<runs-dir>/269b-d1.log`)

```
[claim-line=1 worst 3.260/2.000]
[claim-blocked=1 worst 2.137/1.000 (reached 11.26 of 13.40 studs, stopped by nothing it reported)]
```

**Both are small and both are the same size.** 2-3 studs at the 30-34 studs/s those deer were
running is **0.06 to 0.10 s of animal** -- a replication interval, not an aiming error. And
`claim-blocked`'s note is the answer the dispatch asked for in words: the server's own flight
stopped 2.1 studs SHORT of the claimed distance, on the animal the claim was about -- not on
foliage, not on a terrain lip, and not on a tree.

### Item 3 -- **ONE FIX WORKS, MEASURED. THE OTHER IS INERT, MEASURED, AND I SAY SO**

| cycle | change | measured, same instrument | distance to target |
|---|---|---|---|
| before (269) | -- | `claims=4 accepted=0 refused=4` in the clean trial, 1/5 chest | 4/5 accepted+chest |
| 1 (269b d1) | the diagnostics only | `claims=2 accepted=0 refused=2` -- `claim-line 3.260/2.000`, `claim-blocked 2.137/1.000` | unchanged, and now readable |
| 2 (269b d2, LED) | **neither fix was live** (round 2 found the self-block read a field that does not exist, and the search measured `match=0.000s`) | `claims=4 accepted=2 refused=2 [claim-line=2 worst 4.778/2.000]`; zones `rear`, `rear`, Terrain, Terrain | 2/4 accepted, **0/5 chest** |
| 3 (269b d3, NO LEAD) | the same build | `claims=7 accepted=2 refused=5` -- zones **`chest`**, `rear`, Terrain, **`chest`**, `body` | **2/5 chest**, 0 accepted |

* **The self-blocking fix did NOT work in that build and round 2 is why.** I wrote here that
  `claim-blocked` going from 1-of-2 refusals to 0-of-2 was its effect; the Reviewer showed the fix
  could not fire at all, so that movement is two samples of a noisy count and nothing more. The fix
  is now correct and specced, and **has not been measured live**.
* **The backward search is INERT and the number says that too**: `match=0.000s` on every claim of
  every trial -- `claimMatchBack` is the furthest back any match landed, and it never left the
  arrival instant. **My directional assumption was wrong.** The client's claimed point is not
  BEHIND the server's arrival-instant position; going further back only makes the gap worse, which
  is why the search always chose `back = 0`. The mechanism is sound and costs nothing; it answers a
  lag that is not the one this game has. Reported as inert rather than left to be discovered.

### Item 4 (CORE) -- **NOT MET, and here is the number**

**Target: at least 4 of 5 led shots ACCEPTED, naming the chest, with the mark on the chest.
Measured: 2 of 4 accepted and 0 of 5 chest when led; 2 of 5 chest and 0 accepted when not led.**
Neither trial reaches it. **This is still unproven; nobody has seen it.**

### AND THE NEXT CONSTRUCTION QUESTION IS NOW A PRECISE ONE

**With the claim path on, LEADING puts the hit on the REAR.** Cycle 2's accepted claims both named
`rear`; cycle 3, aiming AT the chest with no lead at all, produced the only two `chest` zones of the
session. `Claim.simulate` already shifts each target forward by `target.velocity * pellet.elapsed`
and casts the segment back by the same amount -- it compensates for the flight itself. So a shooter
who also leads by `v x flight` is applying the lead **twice**, and lands one body-length behind
where he meant to. That is a mechanism, it is consistent with both trials, and it is the next
construction change -- not a fifth round of shooting (L-116).

### WHAT THE "from the CHEST" COLUMN IS NOT (L-019 / L-021)

The client's listener computes the impact's local offset and its distance from the chest from the
part's CFrame **as it reads them**, 1.5 s after the shot; at 25-37 studs/s the animal has moved
40-55 studs by then, which is why rows show `local ... z=6.695` on a zone part a few studs long.
**Only the zone NAME and the `DHClaimStats` counters are used as evidence here**; no miss distance
measured on the client is.

## CLAIMS

1. **`judgeClaim` answers the measured value and its budget for every refusal that has one.**
   `weapon_shot.spec`, "names the measured value and its budget for every refusal that has one":
   six rules, each asserted against the quantity its own check compares, and an honest claim
   answering nil for both. **Fails on the base commit** -- there `judgeClaim` returns two values and
   the `near` assertions error on nil.
2. **`claimLine` prints the worst per reason with its budget and its cause.** Same spec, the
   `claimLine` case, asserting the exact string
   `[claim-blocked=1 worst 31.500/1.000 (reached 98.50 of 130.00 studs, stopped by
   Workspace.Boars.Boar12) claim-line=1 worst 7.412/2.000 claim-moved=2]` -- including a reason with
   NO row, which must keep its bare count. **Fails on the base commit.**
3. **The claimed animal cannot block its own claim, and a tree still can.** Same spec, "does not let
   the CLAIMED ANIMAL block its own claim, and still lets a tree do it": the same numbers accepted
   with `stoppedByClaimedTarget = true`, refused with `false`, refused with `nil` (every caller
   before this task), and a shot that never got near the animal still refused `claim-line` even with
   the reach rule waived. **Fails on the base commit.**
4. **`Hits.targetOf` is what decides "the same animal"**, read once in `judgeClaimFor` against the
   `target` the claim was already matched to -- so the identity is the one the rest of the file uses.
5. **No tolerance in `judgeClaim` moved, and the rewind is one lookup at the arrival instant**, as
   `docs/design/ballistics.md` section 5.2 specifies. Round 1's search is deleted; `grep` for
   `MATCH_BACK` or `matchedAt` finds nothing in `src/`.
6. **WITHDRAWN.** Round 1 offered cycle 1 vs cycle 2 as the live before/after for the self-block
   fix. The fix was not live in cycle 2, so that pair measures nothing about it. There is **no live
   evidence for item 3's first half**, and the spec case is all there is.
7. **The backward search is gone**, with both of its CONFIG numbers, and nothing reads them.
8. **Item 4's target is not met**, with the counts above, and is written as NOT MET.
9. **The Forest Test is as it was found.** Twelve attributes before, twelve after, the same twelve:
   `HIT_CLAIM` was set ON for the trials and **set OFF again** as rule K and the dispatch require;
   `flags.py --place forest clear` was never run; `DHTestOwns` added for the session and removed by
   name. Play stopped and the window closed before the harness ran -- the harness log names DEV.

## WHAT COULD NOT BE VERIFIED

* **No live trial was run on round 2's build.** Item 4 is CORE and is **NOT PROVEN**: with the
  self-block fix actually wired, nobody has yet fired a shot at a running deer in Karen's place.
  That is the first thing the next session does, and it needs no new instrument.
* **Item 5 (269a(b), no claim after a shot without a reload): NOT DONE.** It is not in the path this
  task changed and there was no time. The instrument reloads before every shot, so no measurement
  here depends on it.
* **No frame was taken of a mark on a chest this task.** The two `chest` zones of cycle 3 were
  captured (`<runs-dir>/269b-d3-d3.3.1.png`, `269b-d3-d3.6.1.png`) but **not opened and described**,
  so they are not cited as evidence. `NOT OBTAINABLE within the box.`
