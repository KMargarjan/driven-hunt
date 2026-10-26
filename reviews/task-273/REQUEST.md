# Task 273 -- why led shots with the sight on the chest land low

Task: 273
Round: 1
Base: `f58ce15e` (`main`, after #251, which carries 271 and 272)
Code commit: (filled in with the harness line)

## PLAN

### (a) REAL LIFE

A rifle zeroed at 200 m puts the bullet within a couple of centimetres of the sight line anywhere
inside 50 m. A hunter who holds the crosshair on a deer's chest at 30-50 m does not hit its feet.

### (b) MEASURED NOW

Task 272, five led shots, Karen's place, `HIT_CLAIM` on (`<runs-dir>/272-core.log`):
zones **Terrain, Terrain, `ZoneLegs(legs)`, Terrain, `Boar136(body)` -- 0 of 5 chest**, with the
tracked hold settled under 0.6 deg on the chest before every trigger. And `best=1@2.665` /
`best=1@2.943`: the server's own trajectory never passes within 2.7 studs of the server's own
animal. **Terrain twice and legs once says the error is DOWN.**

**AND ONE BRANCH IS RULED OUT BY ARITHMETIC BEFORE ANY TRIAL**, which is what step 0 is for. The
scoped rifle's `ZERO_STUDS` is **714** (`src/shared/Rifle/init.luau:165`), so inside 200 studs the
bullet is still RISING toward its zero, not falling: with `v0 = 2612`, `k = 4.29e-4` and the repo's
own gravity (35.0357 studs/s^2, derived from `Report.CONFIG.METRES_PER_STUD`), the elevation
tangent is `dropAt(714)/714 = 1.792/714 = 0.002510`, and at 150 studs the sight line is 0.3765
studs above the bore while the drop is only 0.0616 -- so the bullet sits **+0.315 studs ABOVE the
sight line**, high and tiny. **Ballistic drop cannot be the low miss**, and task 265's own
measurement agrees (0.023-0.038 studs off the sight line at 90-179 studs).

So what is left is GEOMETRY: where the aim point actually is on the animal. The candidates the
dispatch lists, in the order the numbers will test them -- the instrument aiming at a point that
sits low on the drawn deer, the trunk box sitting low against the drawn mesh, or the claim naming
the animal's pivot rather than its chest.

### (c) TARGET

* **Item 1:** for three live shots, the gap decomposed into **vertical, horizontal-across and
  along-path** components in the animal's own frame, with the aim point, the claim's point, the
  trajectory's closest approach and the origin-vs-eye offset beside them. Those three axes because
  "low" is a vertical statement and the two tasks before this one decomposed on axes that could not
  see it.
* **Item 4 (CORE):** **at least 4 of 5 led shots accepted, chest-named, with the mark on the chest
  and a frame.**

### (d) LEVER

```
src/shared/Rifle/init.luau:165:	ZERO_STUDS = { Slug = 714 },
src/server/Boar/Body.luau:231:		zonePart:SetAttribute("HitZone", zone)
src/server/Boar/Body.luau:229:		zonePart.CFrame = trunk.CFrame * CFrame.new(spec.offset)
src/server/Weapon/init.luau:1606:		local where = askWhereWas(claim.part, at)
```

`Body.buildZones` is the one writer of where a zone sits on an animal -- `trunk.CFrame *
CFrame.new(spec.offset)` -- and the instrument's aim point is `ZoneChest.Position`. If those two
disagree with what the player SEES, that is the defect and it is in one of those two places.

### (e) HOW IT WILL BE MEASURED AFTER

The same instrument: `<runs-dir>/268kill.py` + `proof268.py` (the staged release, the tracked led
hold, `aimshot`'s real focused clicks through `click.ps1`, `DHClaimStats` read as a live
`ServerStorage` attribute, L-026), plus `<runs-dir>/273-geom.luau`, which reads a LIVE deer's trunk
box, its drawn mesh, its lowest bone, the ground under it and all four zone parts -- so "the aim
point sits low on the animal" becomes a number instead of a description.

### On L-116

This is the fourth dispatch on the same symptom and item 1 is again a diagnostic. **The difference
is that the previous three decomposed on axes that cannot see a vertical error** (along/across the
shot, along the animal). The arithmetic above already ruled out drop without a trial, and the geometry
probe answers the rest in one reading. **If it does not name the cause, the next step is a fix
attempt, not a fifth decomposition.**

### On L-088

Started **2026-10-26T08:31:38Z** (`<runs-dir>/273-start.txt`); the 2.5 h mark is **11:01:38Z** and
I will quote the literal clock, not an estimate.

## WHAT CHANGED

(filled in)

## CLAIMS

(filled in)
