# Task 305d -- the walk, the semi-auto, and the bone that carries each hit box

Task: 305d
Round: 1
Base: 5c444dbe (main)
Code commit: 472b8c6818dc963029021a3cfb8e9dd8b3e1640d

```
[harness] PASS: 34/34 checks @ 472b8c6818dc963029021a3cfb8e9dd8b3e1640d (clean tree) scope=all
```

`test2` is **N/A**: the change touches `src/server/Boar/Body.luau` and
`tests/server/boar_zones.spec.luau`, and neither is in `TWO_PLAYER_PATHS` (Director, 2026-10-03 --
boar work takes the one-player line only).

## PLAN

**(a) REAL LIFE.** A hit box stands for a piece of the animal, and a piece of an animal moves with
the bone under it. The slab over a boar's shoulders moves with its spine; an ear does not carry a
shoulder. Source: skeletal skinning as the mesh itself is built --
<https://create.roblox.com/docs/reference/engine/classes/Bone>, and the fit this rig was measured
to, `docs/research/` / task 284's own silhouette fit.

**(b) MEASURED NOW** (`<runs-dir>/305d/rig2.luau`, Karen's range, live): `ZoneBody1` rest
(0.00, 1.56, -0.95) -> **`ear_1.L`, d = 0.534**; `ZoneBody2` rest (0.00, 1.44, -0.11) ->
**`hip_1_f.R`, d = 0.576`**. Both boxes sit on the centre line; both were given a paired bone.

**(c) TARGET.** Every centre-line box carried by a centre-line bone, and `ZoneBody1`'s pose travel
per replication lag at RUN **below its old 0.420 studs** -- that box is 0.12 studs tall, so 0.420 is
3.5x its own height and the slab was being flung off the back. Not "zero": the boxes SHOULD move,
that is 305c. The number to beat is the one a paired bone was adding.

**(d) LEVER.** `Body.gaitRig`, `src/server/Boar/Body.luau` -- the one writer of `row.bone`:
```
$ grep -n "row.bone = best" src/server/Boar/Body.luau
972:		row.bone = best
```
and `Body.followGait` (`row.weld.C0 = ...`, same file) is the one writer of the live `C0`.

**(e) HOW IT WILL BE MEASURED AFTER.** `rig.luau` for the pose travel (the same probe, both
builds) and `carrier.luau` / `carrier2.luau` for which bone the shipped code actually chose.

**Two of the dispatch's three items contradict (b) and I say so here rather than at the end:** the
WALK is 189/189 geometrically and 4/5 on real `FireRequest`s, and the semi-auto shares the shotgun's
ammunition table by reference and reads the same as it. Both are refuted premises, which the
protocol calls finished items. `reviews/task-305d/MEASURED.md` carries every number.

## What changed

One rule in `Body.gaitRig`: a box on the animal's centre line may only be carried by a bone on the
centre line; a box off it takes its own side's bone or a centre one; if nothing passes, the plain
nearest is kept, so no animal can go unwired. Plus one spec case.

## Claims

1. **`Body.gaitRig` refuses a paired bone for a centre-line box.** `src/server/Boar/Body.luau`,
   `Body.gaitRig`: `sideOf` with `centreX = mesh.Size.X * 0.1`, and the `(boneSide == boxSide or
   boneSide == 0)` guard on the comparison that used to be `distance < bestDistance` alone.
2. **No animal can lose its rig to the new filter.** Same function: `anyBest` tracks the plain
   nearest independently, and `if best == nil then best, bestRest = anyBest, anyRest end`.
3. **The case that bites it is in the suite and could fail.**
   `tests/server/boar_zones.spec.luau`, *"never lets a paired bone carry a box on the animal's
   centre line"*: hand-made `ear_1.L` / `Neck` / `shin_f.L` bones at the male's own measured rest
   places, the real `ZONES.body.boxes[1]` and `ZONES.legs.boxes[1]` offsets. It asserts
   `toEar < toNeck` FIRST, so the ear really is the nearer bone and the test cannot pass by
   accident; delete the side filter and `backBox.bone` is the ear and the case fails. It also
   asserts the LEG box still takes `shin_f.L`, so the filter is shown to allow its own side as well
   as to refuse the other.
4. **The fix is live in Karen's place and the carrier changed.** `<runs-dir>/305d/carrier.luau`,
   Forest Test on :34874 at this commit: `ZoneBody1 carrier=Neck err=0.0284 (next hip_1_f.R
   0.1550)`, `ZoneBody2 carrier=Spine_01 err=0.0242`. Before, the old rule on the same live animal
   gave `ear_1.L` and `hip_1_f.R`.
5. **The box stopped being flung off the back.** `rig.luau`, RUN, worst pose travel over the
   measured 0.056 s replication lag: `ZoneBody1` **0.420 -> 0.268** studs, `ZoneBody2`
   **0.184 -> 0.141**, while the untouched `ZoneHead1` (0.264 -> 0.267) and `ZoneChest1`
   (0.293 -> 0.289) do not move.
6. **Air ahead of the animal still misses.** `U7-rifle-run-ahead.luau`, three real `FireRequest`s
   one full body length in front of the drawn snout at RUN: **0/3**.
7. **The WALK did not regress.** `ray.luau` at 4.50 studs/s: the rewind-translated ray through the
   DRAWN chest centre hits a zone part on **189/189** frames. `U1`: **4/5** on `5c444dbe` and
   **4/5** here -- 305b's own number.
8. **The semi-auto is not different from the shotgun.** Same ammunition table by reference
   (`muzzle=1752, t(125)=0.0763 s, lead=1.83`); back to back at RUN on `5c444dbe`, semiauto 1/5 vs
   shotgun 4/5, at a STANDING boar 2/5 vs 3/5, and on this commit **3/5 vs 3/5**. The nose TIP is a
   ~50% aim for both.
9. **The pose the client draws is 0.056 s old, not 0.18 s.** `propS/propC.luau`, 234 samples:
   min 0.0372, max 0.0797, mean 0.0556 s. The rewind's trunk look-back is 0.18 s, so the pairing
   error is the pose travel over 0.056 s -- 0.23-0.31 studs at RUN against boxes 0.32-1.76 studs
   across. Real, and an order smaller than the 0.3-1.8 studs `ESCALATE.md` feared.

## What I could NOT verify

- **Every click threshold the dispatch names.** This rig reads lower than the Playtester's real
  clicks on the SAME build (rifle RUN nose 4/10 here vs the board's 9/10 on `5c444dbe`), so no count
  here is the game's hit rate and I claim none of them. The thresholds need the Playtester.
- **The red deer.** 0/5 at the stag's nose with no before from this instrument. `carrier2.luau`
  says the stag's TRUNK boxes are all on spine/neck bones, but its head cluster is inside that
  detector's blind spot. Details in `MEASURED.md` section 3.
- **Karen has not played it**, and no shooter's-eye frame of a back-slab hit was taken.
