# Task 269 -- a led shot at a running deer's chest hits the chest, with the true-hit claim ON

Task: 269
Round: 1
Base: `2ce7e61d` (`main`, after #248)
Code commit: `38176f06` (the commit the harness line names; round 1's Reviewer note). **NOTHING UNDER `src/`, `tests/` OR `tools/`
CHANGED IN THIS TASK** -- the whole of it is a measurement and this branch is
paperwork only (`git diff --name-only 2ce7e61d..HEAD` is `reviews/task-269/REQUEST.md`).
The harness line below is the one-player run on the clean tree anyway, because the PR
to `main` asks for one. It names the request's own commit, which is allowed and is
stricter (git workflow step 4): everything the harness ran over is covered.

```
[harness] PASS: 34/34 checks @ 38176f068385904b23ecb69a34dee5a142f11b12 (clean tree) scope=all
```

`test2` is **N/A**: nothing under `src/` changed at all, so no path can be in `TWO_PLAYER_PATHS`.

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

**No `src/`, no `tests/`, no `tools/`.** The hypothesis in the PLAN was that nothing in the game was
wrong and that task 268's measurement had been taken with the feature switched off. **That
hypothesis is REFUTED, and refuting it is this task's result**: with `HIT_CLAIM` ON the claims are
built and sent, and the server **refuses almost all of them**.

Changed outside the repo (Director ops, `<runs-dir>`): three measured instrument faults, below.

## THE MEASUREMENT

Karen's Forest Test (placeId 130094961655666), the scoped .416 in hand, `DHTestRelease` staging hind
parties at 250 studs (70 m) crossing in front of the stand, the hold led by `v x flight` through
`Ballistics.timeToRange`, settled under 0.6 deg on its own live generation before every trigger,
one real focused click each through `click.ps1`. Log: `<runs-dir>/269-led4.log`.
`DHClaimStats` read as a live `ServerStorage` attribute, never through `require` (L-026).

### Item 2 -- 5 led shots. **TARGET 4 of 5 CHEST. MEASURED 1 of 5. NOT MET.**

| shot | target, v at the shot | range | the server named | the claim |
|---|---|---|---|---|
| led4.1.1 | Boar408 hind, 20.60 | 61.8 | `Boar408(body)` | **refused** (`claim-line`) |
| led4.2.1 | Boar425 hind, 28.78 | 171.2 | `ZoneRear(rear)` | **refused** (`claim-blocked`) |
| led4.5.1 | Boar458 hind, 26.91 | 146.2 | **`ZoneChest(chest)`** | **refused** (`claim-blocked`) |
| led4.6.1 | Boar466 hind, 29.30 | 133.1 | `Boar466(body)` | **refused** (`claim-line`) |
| led4.7.1 | Boar479 calf, 37.25 | 117.6 | `Boar479(body)` | none sent |

### AND HERE IS THE CAUSE, MEASURED: **THE CLAIMS ARE REFUSED**

`DHClaimStats`, read before and after every shot, over this task's ten claims:

```
enabled=true claims=10 accepted=2 refused=8 ignored=0
worst=2.590/1.840/2.008 age=0.012..0.050/10 why=ok [claim-blocked=4 claim-line=4]
```

**Eight of ten claims refused**, four by `claim-blocked` and four by `claim-line`. `accepted` moved
exactly twice, and neither accepted claim is one of the five shots in the table. So on every shot
in that table the zone the server named is **its own late resolution**, which is the thing
`HIT_CLAIM` exists to replace -- the feature is ON, is reached, builds a claim, sends it, and is
then refused at `Validator.judgeClaim`.

**That is a sharper statement than "the lead is wrong", and the numbers say which:** the ballistic
lead applied was 0.47 to 1.79 studs and the claims were refused for being off the server's own
trajectory (`claim-line`) or blocked by its rewind (`claim-blocked`) -- neither of which the
shooter's lead can change.

### One shot DID put the mark on the chest, and the frame was opened

`<runs-dir>/269-led4-led4.5.1.png`, described: the shooter's eye, the scoped .416 across the lower
half of the frame over the stand's yellow circle, open grass and birches to the treeline with a
small brown deer standing in the middle distance, HUD `DRIVE 6 / 4:22 TIME / 0 ANIMALS / HUNTER /
$13238` and `9 .416` in the ammo box; bottom-left the hit card **`HIT - .416`** with a deer
silhouette carrying a **red diamond mark on the CHEST**, just behind the foreleg, and under it
**`Alhamdulilah824 HIND  chest  41 m  RIFLE`**. So one of the five is the picture the dispatch asked
for -- a running hind (v 26.91), the chest named, the mark on the chest -- and **the claim for that
very shot was refused**, so even this one is the server's own answer and not the shooter's.

### Item 3 -- the 3 no-lead shots: **NOT RUN.** Honest reason

The 2 h went on the enabler's three instrument faults below and on the four 5-shot trials they cost.
It is not attempted and is not reported as anything else. **And the instrument is not yet fit for
it**: see the warning under "what the miss distance is NOT", which is exactly L-019/L-021's case.

### WHAT THE "from the CHEST" COLUMN IS NOT -- and why it is not used as the yardstick

The listener computes the impact's local offset and its distance from the chest using the part's
CFrame **as it reads them**, which is 1.5 s after the shot. At 27-37 studs/s the animal has moved
40-55 studs by then, which is why rows show `local ... z=7.578` on a zone part two studs long. The
**zone name** is sound (it is the part the server itself named in the report); the **distance** is
not, and it is not used to judge anything here. Fixing it needs the aim point and the part CFrame
LATCHED at the trigger. This is L-019/L-021's warning met in the data rather than argued about.

## THREE INSTRUMENT FAULTS MEASURED AND FIXED THIS SESSION

Each was found by a reading, and each had been silently corrupting the trial before it:

1. **Every `track` call spawned another per-frame loop under the SAME generation string**, and each
   loop runs `while RS:GetAttribute("DHTrackGen") == GEN` -- so none of the old ones ever stopped.
   Two to five loops then fought over `DHTestLook` frame by frame, each holding its own animal.
   The readings: `settle` oscillating to 48 and 91 degrees, and **a shot at a deer 23 studs away
   landing on a different animal 113 studs out**. Fixed with a unique generation per call.
2. **The fix for (1) then broke the handshake the other way**: an exiting loop wrote
   `DHTrackGen = "off"` unconditionally and killed the generation that had just replaced it. Five
   shots read `offTarget=0.000` with the hold frozen on a point the animal had long left, and
   **all five hit Terrain**. A zero angle to a stale point is not "on target", so the settle gate
   now checks the generation as well as the angle.
3. **No reload between two shots means no claim at all.** Task 269's first trial sent ONE claim in
   five shots. `Claim.forCamera` refuses to build one unless the snapshot's `loaded[selected]` is a
   string, and the probe measured that gate live: with the rifle in hand it reads
   `char=true tool=Rifle muzzle=true id=rifle ammo=Slug pellets=1` -- every gate open. Reloading
   before every shot took it to one claim per shot (`claims` 7, 8, 9, 10). Whether a second shot
   from a loaded magazine should also claim is a question for the owner; it is reported, not fixed.

## CLAIMS

1. **The flag was ON for the trial, live, on the real server.** `<runs-dir>/269-flaglive.luau` read
   `SS.DHFlag_HIT_CLAIM=true` from the running server, and `DHClaimStats` itself carries
   `enabled=true`, which is `Weapon.stats().claimsEnabled` -- the resolved answer, not the file's
   default.
2. **The claims were sent, one per shot.** `claims` went 7 -> 8 -> 9 -> 10 across the trial, read as
   a `ServerStorage` attribute before and after each shot.
3. **Eight of ten were refused, by `claim-blocked` (4) and `claim-line` (4)** -- the same attribute.
4. **The target is not met: 1 of 5 shots named `chest`.** The table above, each row with the zone
   the server's own report named.
5. **The hold was on the chest at every trigger of the final trial**: `settle` under 0.6 deg against
   the LIVE generation, 0.13 to 0.53 deg, and the read after the shot 0.000 to 0.431 deg.
6. **The one chest shot's frame was opened and is described above**, and it is a RUNNING hind
   (v 26.91) with the mark drawn on the chest -- and its claim was refused, so it is not evidence
   that the claim works.
7. **The before is task 268's, same instrument, same place, same gun, flag at its default** (the
   PLAN's (b) table): 0 of 3 vitals. The after is 1 of 5. **Neither meets the target, and the
   difference between them is not significant at these counts** -- which is said here rather than
   presented as progress.
8. **The PLAN's hypothesis is refuted and that is the item's result.** It predicted that the claim
   would make the zone the client's; the claim is refused before it can.
9. **Nothing in `src/`, `tests/` or `tools/` changed.** `git diff --name-only 2ce7e61d..HEAD`.
10. **The Forest Test is as the dispatch asked.** Eleven attributes read before
    (`<runs-dir>/attrs-id.luau`); `HIT_CLAIM` set on for the trial and **set OFF again** afterwards
    as the dispatch instructed, so the set now differs from the baseline by exactly one row,
    `DHFlag_HIT_CLAIM=false`, which resolves to the same OFF as its absence.
    `flags.py --place forest clear` was never run (rule K). `DHTestOwns` was added and removed by
    name. Play stopped, the window closed before the harness ran.

## WHAT COULD NOT BE VERIFIED

* **WHY each claim was refused, beyond the two rule names.** `claim-blocked` and `claim-line` are
  `Validator.judgeClaim`'s own words; which of the six checks' numbers were out, and by how much, is
  not in `DHClaimStats` and no probe here read it. That is the first thing the next session needs
  and it is a one-field addition to the published line.
* **Item 3 (the 3 no-lead shots): NOT RUN.**
* **Whether a magazine's second shot should claim**: measured as "it does not", not judged.
