# Task 269 -- a led shot at a running deer's chest hits the chest, with the true-hit claim ON

Task: 269
Round: 1
Base: `2ce7e61d` (`main`, after #248)
Code commit: (filled in with the harness line)

## PLAN

Written before any `src/` edit, as the core quality protocol's step 0 requires. ONE core item.

### (a) REAL LIFE

A bullet takes time to arrive and a crossing animal must be led. At the scoped .416's own numbers
the flight to 140 studs is **0.057 s**, and a red deer at the **32.05 studs/s** this world measured
(= 9.0 m/s at `Report.CONFIG.METRES_PER_STUD` 0.28; a red deer's gallop is 10-13 m/s) travels
**1.84 studs** in that time -- a third of a body length (a deer trunk measured 6.03 studs in task
268), which is the difference between the chest and the flank.

**AND THERE IS A SECOND LEAD, which is the one this item is actually about.** The shooter does not
see the animal where it is: he sees where it was when the server last told him. That view error is
not the shooter's to correct -- in life the animal you can see is the animal you can hit -- and it
is exactly what task 266's `HIT_CLAIM` exists to remove.

### (b) MEASURED NOW -- task 268, the same instrument, `HIT_CLAIM` **OFF**

`<runs-dir>/268-t3b.log`, three real focused clicks with the rifle at tracked running deer, the
hold led by `v x flight` and settled under 0.6 deg before every trigger:

| shot | target | v at the shot | lead applied | flight | the server named | from the CHEST |
|---|---|---|---|---|---|---|
| t3.9.1 | Boar356 hind | 27.46 | 0.356 | 0.0130 | `Boar356(body)` | 5.397 studs |
| t3.9.2 | Boar356 hind | 0.00 (stopped) | 0.000 | 0.0163 | `ZoneRear(rear)` | 3.794 studs |
| t3.11.1 | Boar383 hind | 32.05 | 1.837 | 0.0573 | `Boar383(body)` | 4.143 studs |

**0 of 3 named a vital. `DHClaimStats` was never written, because the flag was off.** The miss from
the chest -- 3.8 to 5.4 studs -- is two to three times the ballistic lead, which says the ballistic
lead is not the thing that is wrong.

The Forest Test's live attributes, read this session with `<runs-dir>/attrs-id.luau` before
anything was touched: `placeId=130094961655666 DHFlag_BOAR_BEHAVIOUR=true DHFlag_BOAR_MODEL=true
DHFlag_COINS=true DHFlag_DEER_ROAD_LEAP=true DHFlag_DRIVE_BOTS=true DHFlag_HORN=true
DHFlag_LICENCE_POPUP=true DHFlag_LOBBY=true DHFlag_SHOP=true DHForestStartRole=hunter
DHShopTestGrant=true` -- eleven, and **`HIT_CLAIM` is not among them**, so (b) above is its
`default = false`.

### (c) TARGET

**At least 4 of 5 led shots at a running deer's chest are named `chest` by the server, each with
`DHClaimStats`' accepted counter +1.** Four of five and not five of five because the fifth is the
one the animal's own turn, a leap or a tree can take; the counter is per shot because an accepted
claim is what makes the zone the CLIENT's answer rather than the server's, and a chest named
without the counter moving would be a chest hit the claim had nothing to do with.

Then 3 shots with **no** lead: they land **behind** the chest by about `v x t`, which is the real
lead existing, as in life.

### (d) LEVER -- it already exists, and the hypothesis names it

```
src/server/Weapon/init.luau:1589:	return { Validator.claimImpact(claim, part.CFrame, bore, part.Material) }
src/server/Weapon/Validator.luau:220:function Validator.claimImpact(claim: any, partCFrame: CFrame, bore: Vector3, material: any?): any
src/server/Weapon/init.luau:843:Weapon.CLAIM_STATS_ATTRIBUTE = "DHClaimStats"
src/shared/Flags/init.luau:124:	HIT_CLAIM = {
src/server/Boar/Body.luau:231:		zonePart:SetAttribute("HitZone", zone)
```

**An accepted claim REPLACES the server's impact with one built on the CLAIMED PART**
(`Validator.claimImpact`), and the zone a report names is that part's own `HitZone`
(`Hits.targetOf`). So with the claim ON the zone is the one the CLIENT's bullet struck on the
animal the CLIENT could see -- which is the chest the shooter put the sight on. With the claim OFF
the server resolves on its own, later, positions, and the animal has moved on: 268's 3.8-5.4 studs
of miss at 27-32 studs/s is 0.12-0.17 s of animal, which is the order of a replication round trip.

**THE HYPOTHESIS IS THEREFORE: nothing in `src/` is wrong, and the measurement in (b) was taken
with the feature switched off.** If 5 led shots with it ON do not reach 4/5, that is refuted and
step 2's cycles begin on the claim frame, the lead arithmetic and the client's simulation -- in
that order, because that is the order of the sizes above.

### (e) HOW IT IS MEASURED AFTER

The same instrument, unchanged: `<runs-dir>/268kill.py` + `proof268.py` -- the staged release
(`DHTestRelease`), the per-frame tracking hold led by `Ballistics.timeToRange`, the settle gate,
one real focused click through `click.ps1`, and the client's `ShotLanded` listener reading the
part, its `HitZone` and the local offset. **`DHClaimStats` is read as a LIVE `ServerStorage`
ATTRIBUTE and never through `require`** (L-026: task 268 lost two runs to
`require(ServerScriptService.ForestTest)` returning a sandboxed copy with empty state).

### On L-028

The "before" is task 268's three shots in the table above -- same place, same gun, same instrument,
same tracked led hold, on the commit this branch is based on, with the flag at its shipped default.
That is a before that **did** fail, measured, and not a case constructed to fail.

## WHAT CHANGED

(filled in after the proof)

## CLAIMS

(filled in after the proof)
