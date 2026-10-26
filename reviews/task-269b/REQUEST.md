# Task 269b -- make the server accept honest claims on running animals

Task: 269b
Round: 1
Base: `c7165859` (`main`, after #249)
Code commit: (filled in with the harness line)

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

## WHAT CHANGED

(filled in)

## CLAIMS

(filled in)
