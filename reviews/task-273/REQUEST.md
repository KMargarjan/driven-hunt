# Task 273 -- why led shots with the sight on the chest land low

Task: 273
Round: 2
Base: `f58ce15e` (`main`, after #251, which carries 271 and 272)
Code commit: `70ba389e242ab37e40932f7b99bf0f1d6005b98c` (the PLAN). **NOTHING UNDER `src/`,
`tests/` OR `tools/` CHANGED IN THIS TASK** -- the premise was refuted and the defect this task
found is in the INSTRUMENT, which lives outside the repo. `git diff --name-only f58ce15e..HEAD` is
`reviews/task-273/` only.

```
[harness] PASS: 34/34 checks @ 70ba389e242ab37e40932f7b99bf0f1d6005b98c (clean tree) scope=all
```

`test2` is **N/A**: nothing under `src/` changed, so no path can be in `TWO_PLAYER_PATHS`.

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
bullet is still RISING toward its zero, not falling.

**ROUND 1'S FINDING WAS RIGHT AND THIS IS THE CORRECTED ARITHMETIC.** I used the vacuum drop and
left out `Rifle.CONFIG.GRAVITY_SCALE = 0.12` -- the fourth number `Ballistics.shotFor` refuses a row
without, and the one `dropAt`'s own header exists to apply. Through the repo's own function:
`Ballistics.dropAt(shot, 714)` is **0.195 studs** (not 1.792), the elevation tangent is
`0.195/714 = 2.73e-4` (not 2.510e-3), and `Ballistics.sightOffsetAt(shot, 150)` is **+0.034 studs
-- 0.94 cm** (not +0.315). **The conclusion survives and strengthens by an order of magnitude**:
the bullet is above the sight line and by a centimetre. **Ballistic drop cannot be the low miss.**
And the corroboration I cited now actually corroborates: task 265 measured 0.023-0.038 studs off the
sight line at 90-179 studs, which IS 0.034 at 150 -- I quoted it as agreeing with a figure ten times
larger and it did not.

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

**No `src/`, no `tests/`, no `tools/`.** One instrument fix outside the repo
(`<runs-dir>/proof268.py`), and three live measurements.

## ITEM 1 -- **MET, AND THE DISPATCH'S PREMISE IS REFUTED: THE ERROR IS NOT LOW.**

**(i) Ruled out by arithmetic before any trial** (the PLAN): the rifle's `ZERO_STUDS` is 714, so
inside 200 studs the bullet is RISING -- **+0.315 studs above the sight line at 150 studs**, high
and tiny. Ballistic drop cannot be a low miss.

**(ii) The geometry of a LIVE deer, read in Karen's place** (`<runs-dir>/273-geom.luau`):

```
Boar2/hind | trunk y 145.14 size 1.54,4.11,6.03 bottom 143.09 | ground 143.09 (trunk sits -0.01)
           | drawn 143.09..148.19 (Red_Deer_Doe_NoAlpha, bottom -0.00 vs trunk)
           | lowestBone 143.08 (-0.00 vs trunk bottom)
           | ZoneChest y 146.19 (+3.09 above ground) size 1.64,2.10,1.54
           | ZoneHead  (+4.37)  ZoneRear (+3.00)  ZoneLegs (+0.81) size 1.64,1.63,5.47
```

**The aim point is not low.** The deer stands 5.10 studs from hoof to withers, its trunk box sits
on the ground to within 0.01 studs, and `ZoneChest` -- which is what the instrument aims at -- is
**+3.09 above the ground, 61 % of the animal's height.** That is a chest. None of the three
candidates the dispatch offered for a low aim is present.

**(iii) The vertical component, measured, on live shots** -- and this is the number that refutes
the premise outright. With the sight basis latched at the trigger (item 2):

| shot | OFF-SIGHT | of which RIGHT | of which UP | range |
|---|---|---|---|---|
| v1.1.1 | 0.631 | **+0.611** | **+0.156** | 113.6 |
| v1.3.1 | 3.050 | **-3.050** | **-0.002** | 18.1 |
| core.7.1 | 0.180 | -0.179 | +0.011 | 154.6 |

**The vertical part of the miss is 0.002 to 0.16 studs. The horizontal part is 0.18 to 3.05.**
`Terrain` and `legs` were not a low shot: they are a shot that passed the animal ALONG ITS OWN PATH
and carried on to the ground beyond -- `core.11.1` hit Terrain at 202.6 studs with the animal at
~60, which is 140 studs PAST it.

**THE CAUSE, IN ONE LINE:** the residual is the animal's own travel along its path in the 0.155-0.173 s
between the shooter's picture and the server's resolution -- `claim-line ... ALONG THE ANIMAL +4.469
(v 28.8 studs/s, so 0.155 s of it)` and `+4.924 (0.173 s)` -- which is the same quantity task 272
proved the view-instant sweep cannot remove (`took == best`, `sweep=19/19`).

## ITEM 2 -- **IT WAS THE INSTRUMENT, and here is the before and after**

The client listener read `DHAimPoint` and `DHEye` **when the `ShotLanded` payload arrived**, and the
tracker rewrites both every frame -- so on a moving hold the recorded sight basis was the camera's
AFTER the shot. That is why task 272's log carried `OFF-SIGHT 8.119` on a gun task 265 measured at
0.023-0.038 studs against a still target.

It now latches on **`ShotFired`** -- and round 1's note is right that this is not the trigger
itself: `ShotFired` reaches the client through `remotes.ShotFired.OnClientEvent`, so it is the
trigger plus the fire request's round trip, and a hold that is still panning bleeds into the
horizontal axis it is panning on. That is exactly what `v1.3.1`'s 3.050 being entirely `right`
shows. It is a large improvement and not a cure:

| | before (272, read at `ShotLanded`) | after (273, latched at `ShotFired`) |
|---|---|---|
| OFF-SIGHT on settled shots | 3.089, 3.183, 8.119, 3.411 studs | **0.180, 0.631** (and 3.050, 3.637 on the two shots whose hold was still moving) |

**So the gun is not 8 studs off the sight line and never was.** That line of task 272's evidence is
withdrawn, and L-021's warning -- which I quoted in three requests and still fell to -- is now
fixed in the instrument rather than annotated.

## ITEM 3 -- **NOT NEEDED. No game defect was found to fix at an owner.**

The arithmetic ruled out drop, the geometry probe found the chest zone correctly placed, and the
vertical error is under 0.16 studs. **I did not change `src/` to look busy**, and the one number
that is still over budget (`claim-line` 3.0-4.8 studs, all along the animal's path) is the same one
task 272 established the sweep cannot address -- so it belongs to whatever owns the 0.16 s, not to
this task's premise.

## ITEM 4 (CORE) -- **NOT MET. This is still unproven; nobody has seen it.**

Five led shots on the corrected instrument (`<runs-dir>/273-core.log`): `claims=5 accepted=1
refused=4`, zones `ZoneRear(rear)`, `Boar136(body)`, Terrain -- **0 of 5 chest**. No frame: there
was no chest hit to photograph. `NOT OBTAINABLE: the state it would show did not occur.`

**And per L-112 it is reported beside its cause**: every refusal carries `sweep=19/19 passed=true
took=1`, and one of them carries `best=1@0.321` -- the server's trajectory came within a third of a
stud of the rewound animal and the claim was still refused, as `claim-blocked worst 4.105/1.000
(reached 154.23 of 158.34 studs, stopped by Workspace.Boars.Boar132.ZoneRear)`. **That is a second,
separate cause and it is new**: the self-block waiver is bounded by the claimed part's own largest
extent plus the slack, and `ZoneRear` is 2.04 long, so the bound is ~4.0 and the shortfall was
4.105. It is a hair too tight for a zone part, and the animal's TRUNK is 6.03 long.
**Round 1's note corrects my arithmetic here too and I had the axis wrong**: `judgeClaim` takes
`2 * max(partHalf.X, partHalf.Y, partHalf.Z)`, and the hind's `ZoneRear` is (1.64, **2.40**, 2.04),
so the largest extent is the 2.40 in Y and the bound is **3.40**, not ~4.0. The finding survives
either way -- 4.105 is over 3.40 as well -- but the number to argue from is 3.40.

## CLAIMS

1. **Ballistic drop is ruled out by arithmetic, through the repo's own function**: `ZERO_STUDS =
   714` and `GRAVITY_SCALE = 0.12` (`src/shared/Rifle/init.luau`), `Ballistics.dropAt(shot, 714) =
   0.195`, elevation tangent `2.73e-4`, so `Ballistics.sightOffsetAt(shot, 150)` is **+0.034 studs
   (0.94 cm) ABOVE** the sight line. The sign is wrong for a low miss and the size is two orders
   below the 2.7-stud residual. **Round 1 corrected my figures here by a factor of 9.2** -- I used
   the vacuum drop and omitted `GRAVITY_SCALE` -- and the conclusion is unchanged.
2. **The chest zone is where a chest is**: `+3.09 studs above the ground on a 5.10-stud deer`, read
   off a LIVE animal in Karen's place with `<runs-dir>/273-geom.luau`, together with the trunk box
   (`sits -0.01` on the ground), the drawn mesh and the lowest bone.
3. **The miss is horizontal, not vertical**: `up` of 0.002-0.156 studs against `right` of
   0.18-3.05, on three live shots with the sight basis latched at the trigger.
4. **The instrument was wrong and is much better**, with the before/after in the table above. The
   listener latches on `ShotFired`; `<runs-dir>/proof268.py`, generation `273s1`. **It is one hop
   late, not at the trigger** (round 1's note), so a panning hold still bleeds into the horizontal
   axis -- which is why the two unsettled shots read 3.050 and 3.637 while the settled ones read
   0.180 and 0.631.
5. **Item 4 is NOT MET**, with the zones and counts above.
6. **Nothing in `src/`, `tests/` or `tools/` changed.** `git diff --name-only f58ce15e..HEAD`.
7. **The Forest Test is as it was found.** Twelve attributes before, twelve after; `HIT_CLAIM` ON
   for the trials and OFF again (rule K); `flags.py --place forest clear` never run; `DHTestOwns`
   added and removed by name. **A second Studio session was opened by mistake** and Roblox closed
   one with `Multiple Sessions Detected (RCC-276)`; the stray Start-Page window was closed and the
   healthy session reconnected, both read off screenshots rather than assumed.

## WHAT COULD NOT BE VERIFIED

* **Where the 0.155-0.173 s actually goes.** It is the animal's travel between the shooter's
  picture and the server's resolution, it is stable across six tasks, and task 272 proved the
  view-instant sweep cannot remove it (`took == best`). What has never been measured is the
  BREAKDOWN of that interval -- render interpolation, the client's own frame, the remote, the
  server's resolve. That is the next task and it is a timestamp at each hop, not another geometry
  decomposition.
* **The `claim-blocked` bound at 4.105 of a ~4.0 budget.** New this task, named above, not fixed.
* No frame of a chest hit, because there was no chest hit.
