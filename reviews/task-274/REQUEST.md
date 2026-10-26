# Task 274 -- an accepted claim must decide the hit

Task: 274
Round: 1
Base: `a8877335` (`main`, after #252)
Code commit: (filled in with the harness line)

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

(filled in)

## CLAIMS

(filled in)
