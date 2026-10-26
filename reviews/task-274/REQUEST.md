# Task 274 -- an accepted claim must decide the hit

Task: 274
Round: 1
Base: `a8877335` (`main`, after #252)
Code commit: `df463cb9ab7a575682fb8250f83af9b44afbea08`

```
[harness] PASS: 34/34 checks @ df463cb9ab7a575682fb8250f83af9b44afbea08 (clean tree) scope=all
```

`test2` is **N/A**: the only changed file is `src/server/Weapon/init.luau`, not in
`TWO_PLAYER_PATHS`.

## PLAN

### (a) REAL LIFE

A hunter is credited with the shot he took. If his sight was on the chest and his own bullet struck
the chest, the animal is hit in the chest -- not in the leg it had moved on to 0.16 s later.

### (b) MEASURED NOW -- **AND IT REFUTES THE DISPATCH'S PREMISE, BY READING, BEFORE ANY SHOT**

The dispatch's reading is that *"the server VALIDATES the claim and then ... does NOT apply it; it
re-resolves the hit at its own instant"*. **That is not what the code does.** The three answers the
dispatch asks for, each one line, each with its file and function:

* **(a) which hit is applied after `judgeClaimFor` accepts?** **The CLAIM's.**
  `src/server/Weapon/init.luau`, `judgeClaimFor`'s last line is
  `return { Validator.claimImpact(claim, part.CFrame, bore, part.Material) }` -- one impact, built
  from the claim, replacing `res.impacts` entirely -- and `onShotLanded` uses exactly that:
  `local impacts = judgeClaimFor(res)`.
* **(b) which hit does the client's mark use?** **The same one.** `onShotLanded` builds the dust
  and the marker from that same `impacts` list in the block below it (`if #impacts > 0 then`), and
  `Hits.group(shot.shooter, impacts, ...)` is the single constructor of the `HitReport` the hit
  card is drawn from.
* **(c) which zone reaches `Wound.damageFor` and the kill line?** **The CLAIMED part's.**
  `Hits.group` (`src/server/Weapon/Hits.luau`) opens `local target, zone = Hits.targetOf(impact.instance)`,
  and `Validator.claimImpact` sets `instance = claim.part`. So `report.zone` is the `HitZone`
  attribute of the part the CLIENT named, and that is what the damage and the kill line read.

**So the design is already implemented and the premise is refuted.** A refuted premise is a
finished item, not a failure -- and it moves the question exactly one step: if an accepted claim
already decides the zone, then on the accepted shots of task 272 (`accepted=3 of 6`) the zone the
server named was **the zone the CLIENT claimed**. The client claimed `body`, `legs` or nothing --
not the chest its shooter's sight was on.

**What is NOT measured anywhere, and is this task's item 1:** which PART the client actually claims.
`DHClaimStats` records the counters and the refusal reasons; it has never recorded the claimed part
or its zone. Task 272's live zones (Terrain, legs, body) cannot be attributed to the client or to
the server without it.

### (c) TARGET

* **Item 1:** the three answers above, confirmed live by one field -- the claimed part's full name
  and its `HitZone`, recorded on every accepted claim. One field because it is the only thing that
  can tell "the client claimed the chest and the server overrode it" from "the client never claimed
  the chest".
* **Item 3 (CORE):** **at least 4 of 5 led shots accepted, chest-named, with the mark on the chest
  and a frame.**

### (d) LEVER

```
src/server/Weapon/init.luau:1701:	return { Validator.claimImpact(claim, part.CFrame, bore, part.Material) }
src/server/Weapon/Validator.luau:293:		instance = claim.part,
src/server/Weapon/Hits.luau:75:		local target, zone = Hits.targetOf(impact.instance)
src/server/Weapon/init.luau:1721:	local impacts = judgeClaimFor(res)
```

Those four lines ARE the chain the dispatch asks about, and they already run the claim's way.
Item 1 adds a recording beside them and changes no rule.

### (e) HOW IT WILL BE MEASURED AFTER

The same instrument: `<runs-dir>/268kill.py` + `proof268.py` (`DHTestRelease` stages the hind party,
the tracked led hold, `aimshot`'s real focused clicks through `click.ps1`), `DHClaimStats` read as a
live `ServerStorage` attribute (L-026), and the new field in the same line.

### On the Learning Agent's route warnings

The routes it says are unnamed are the ones this session has used in tasks 268-273 and they are
named here: **the staged RUNNING deer is `DHTestRelease`** (task 268's own `src/` feature, not a
`.luau` probe -- `<runs-dir>/proof268.py`'s `STAGE` writes `ServerStorage.DHTestRelease` and
`ForestTest.stagedLine` releases a hind party at a run, which is why none of the old
`*-stage-*.luau` scripts with `Anchored = true` is used); **the enrolment is
`python ft.py server lobby-go.luau`** (rule I), driven automatically by `268kill.py`'s `ready()`;
**the licence is `DHTestOwns = rifle.scoped,role.alwayshunter,licence.reddeer`**
(`<runs-dir>/268-setup.luau`), which is why `no-licence` has not appeared in any trial since 268.

### On L-088

Started **2026-10-26T09:07:13Z** (`<runs-dir>/274-start.txt`, the literal `date -u` output); the
2.5 h mark is **11:37:13Z**.

## WHAT CHANGED

`src/server/Weapon/init.luau` only: **one recorded field**, `claimLastPart` -- the part the CLIENT
claimed and that part's `HitZone` -- written for every claim that reaches the judge, and printed in
`claimLine`. **No rule, no tolerance and no behaviour changed.**

## ITEM 1 -- **MET. The premise is refuted by reading AND the live field reverses what 272 looked
like.**

The three answers are in the PLAN, with their files and functions: the claim's hit is applied, the
client's mark uses the same one, and the claimed part's zone is what reaches the damage and the kill
line. **The server does not re-resolve.**

**Then the field was added and measured live, and it took two readings to get right -- which is the
part worth reading:**

* **Recorded on ACCEPTED claims only** (the first version): `claimed=ZoneRear(rear)` and
  `claimed=Boar56(body)`. Read alone, that says *the client is claiming the rear.*
* **Recorded on EVERY claim** (the shipped version): with the sight settled on the chest, **every
  claim reads `claimed=ZoneChest(chest)`.**

**So the client claims the chest correctly, and it is the CHEST claims that were being refused** --
the ones that survived to be accepted were the rear/trunk ones. The first reading was a selection
effect of my own field, and I would have reported it as a client defect if I had stopped there.

## ITEM 2 -- **NOT NEEDED.** No server-side re-resolution exists to remove

The design is already implemented. Nothing in `src/` was changed to look busy.

## ITEM 3 (CORE) -- **NOT MET on the rate. 1 of 5, not 4 of 5. BUT THE THING ITSELF HAS NOW BEEN
SEEN, AND HERE IS ITS FRAME.**

Five led shots at staged running deer, `HIT_CLAIM` on (`<runs-dir>/274-core.log`):
`claims=6 accepted=3 refused=3`; zones `ZoneRear(rear)`, Terrain, `ZoneRear(rear)`,
**`ZoneChest(chest)`**, Terrain.

**THE CHEST SHOT, with all three numbers together, on a RUNNING animal:**

* **AIMED**: `Boar148`, the tracked hold on its chest, `offTarget 0.991 deg`, **v = 28.07 studs/s**
  (a hind at a run), lead 0.290 studs.
* **SERVER**: `ZoneChest(chest) @ 3288.32,166.70,-3222.09`, `OFF-SIGHT 0.057 studs (right +0.038,
  up +0.042)` at 43.0 studs.
* **CLIENT**: `Attachment @ 3288.32,166.70,-3222.09 (under ZoneChest)` -- the mark drawn on the
  same zone, at the same point.

**THE FRAME, `<runs-dir>/274-core-core.10.1.png`, opened and described**: the shooter's eye from
the stand, the scoped .416 across the lower half, and **a hind in mid-stride with her legs extended,
running across the open field at centre frame** about 11 m out; two more deer on the rise behind her
and a tower stand on the skyline. Bottom-left the hit card **`HIT - .416`** with the deer
silhouette carrying a **red diamond on the CHEST, just behind the foreleg**; under it
**`Alhamdulilah824 HIND  chest  11 m  RIFLE`**. HUD `DRIVE 2 / 2:32 / 0 ANIMALS / HUNTER / $13027`,
ammo `6 .416`.

**That is a led shot at a running deer whose chest was hit, with the mark on the chest -- the thing
eight tasks have been trying to see.** It is one of five, not four of five, so **the target is NOT
MET and the feature is not proven at the rate Karen would need.**

### And the one reading that shows the whole chain working at once

```
claims=1 accepted=1 refused=0  lag=0.183s  sweep=19/19 took=12 best=12@0.767
claimed=ZoneChest(chest)   ->   SERVER #1 ZoneChest(chest)
```

**`took=12`** -- the sweep chose the twelfth candidate, **`lag=0.183 s`**, which is the view lag
task 271 measured (0.178 s) to within a grid step; `best` was AT that instant and used 0.767 of its
2.0 budget; the claim was accepted; and the server named the claimed zone. **Every part of tasks
266-273 did its job on that shot.** `spread=0.001` on that one, so the animal was nearly still at
that instant -- which is why the running shot above is the one offered as the core evidence and
this one is offered as the chain's own proof.

## ITEM 3's second half -- the `claim-blocked` waiver: **NOT CHANGED, and the number says why**

273 left it at 4.105 against a 3.40 bound. This task measured `claim-blocked=1 worst 7.275/1.000
(reached 38.79 of 46.07 studs, stopped by Workspace.Boars.Boar147.ZoneChest)` -- **7.275 studs
short, stopped by the claimed animal's own chest zone.** Bounding it by the trunk's 6.03 would
still refuse this one, so the dispatch's "if it refuses honest chest shots, bound it by the trunk"
does not reach it. **Changing a bound that would not have changed this verdict is not a fix**, and
I did not.

## CLAIMS

1. **The accepted claim already decides the hit**, with the chain in the PLAN: `judgeClaimFor`'s
   `return { Validator.claimImpact(...) }`, `onShotLanded`'s `local impacts = judgeClaimFor(res)`,
   `Hits.group`'s `Hits.targetOf(impact.instance)` and `Validator.claimImpact`'s
   `instance = claim.part`.
2. **The client claims the chest**: `claimed=ZoneChest(chest)` on every claim of the led trial, read
   from `DHClaimStats` as a live `ServerStorage` attribute (L-026).
3. **A led shot at a running deer (v 28.07) was chest-named with the mark on the chest**, with the
   three numbers and the frame above.
4. **The sweep chose a non-arrival instant and it was the view lag**: `took=12 lag=0.183s
   best=12@0.767`, the first such reading in this investigation.
5. **Item 3's rate is NOT MET**: 1 of 5.
6. **Nothing but one recorded field changed.** `git diff --stat a8877335..HEAD` on `src/` is
   `src/server/Weapon/init.luau` alone.
7. **The Forest Test is as it was found.** Twelve attributes before, twelve after; `HIT_CLAIM` ON
   for the trials and OFF again (rule K); `flags.py --place forest clear` never run; `DHTestOwns`
   added and removed by name. A stray second Studio session (RCC-276) was closed from its own
   screenshot. Play stopped and the window closed before the harness ran -- only DEV was open.

## WHAT COULD NOT BE VERIFIED

* **Why 4 of the 5 shots did not produce a chest.** Two sent no claim at all (the client's
  simulation found nothing -- a miss or an obstruction), and two were `claim-line` refusals at
  4.090 of 2.000, still the 0.16 s. The rate, not the mechanism, is what is unproven.
* **No spec was added this task.** The one field is a recording and the behaviour it describes was
  already covered by task 272's owner-path case; a case asserting "an accepted claim names the
  claimed zone" would pass on the base commit too, because it already does. **Writing one would be
  the unfalsifiable-case mistake tasks 265 and 271 made**, so I did not.
