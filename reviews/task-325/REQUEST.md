# Task 325 — the deer's road leap: it now really leaves the ground

Task: 325
Round: 1
Base: 4840e1df (main)
Code commit: 124eafd7c493d189c4d07056ac2668ebd198ea7c

KAREN, 2026-11-01: *"you need to fix red stag male when jumping it has to jump not like now broken
and famale and kid doesnt jump / work on it"*.

Harness, clean tree, full scope, at the code commit:

```
[harness] PASS: 34/34 checks @ 124eafd7c493d189c4d07056ac2668ebd198ea7c (clean tree) scope=all
```

`test2` is N/A: nothing here touches `TWO_PLAYER_PATHS` (the change is `src/server/Boar/`, which the
Director's 2026-10-03 list puts with the one-player gate). The last commit that changed `src/` or
`tests/` is `da10165d`; everything after it is this request and the research note, so the line above
covers the head.

**An intermittent, named and then cleared.** An earlier run of the same commit reported
`deer_hitbox.spec:682` (2653 passed, 1 failed) — the intermittent the dispatch names, and the Forest
Test was in Play at the time, which the dispatch says makes it worse. Stopping that Play session and
re-running the same commit gave the clean 34/34 above. Two runs, same commit: `FAIL: 32/34` then
`PASS: 34/34 @ 124eafd7`.

ANSWERED: L-136 — the only FAIL seen was `deer_hitbox.spec:682`, which the dispatch names as a known
intermittent; it is reported above with both runs rather than waved away, and the pasted evidence is
the clean one. `weapon_shot.spec.luau:1490` never fired.
ANSWERED: L-127 — every claim below is MET or carries its own "could not be verified" line; the
handover block in the report marks each dispatch item MET / NOT PROVEN by name.
ANSWERED: L-162 — every live reading in this request was taken in her place at a commit on this
branch: the "before" at `main` 4840e1df, cycles 1–3 at `6dbd7a6a`, `14266be1` and `da10165d`, each
served to her place on its own Rojo port and each with a Play restart.
ANSWERED: L-111 (route) — task 255's finding ("nothing in `src/server/Boar/` ever writes a vertical
velocity") is exactly right and is the root cause this task fixes; `b245b-result.json`'s hoof sink
and its "a real fix needs per-frame CFrame writes the design forbids" is answered without any such
write — the body rises, the drawn mesh never moves, and 245c is closed. Written up in §8.3.
ANSWERED: L-020 (route) — measured rather than assumed: there is NO per-kind gate anywhere, all
three kinds already entered the bound at `main`, and the premise "the hind and the calf do not jump"
is corrected in claim 1. The per-kind apex is taken off each kind's own `scale` with the floor from
each kind's own measured sink.

## PLAN (core quality protocol step 0)

**(a) REAL LIFE.** A red deer clears a 1.8 m fence routinely and 2.4 m is the exclusion standard
(County Fencing; NC Wildlife). A *bound* is the gait where all four feet leave the ground together,
used to gain height over an obstacle (Lingle 1993, Can. J. Zool. 71). A road is not a fence, so the
target is a cruising bound: **0.84 m of body rise = 3.00 studs** at `METRES_PER_STUD` 0.28.
Sources are `docs/research/2026-10-23-deer-road-leap.md` section 8.2.

**(b) MEASURED NOW** (her place, `main` 4840e1df, probe `<runs-dir>/325-log2.luau` →
`325-before2.txt`). All three kinds DO play the leap clip at weight 1.00 for its whole window —
**the dispatch's "the hind and the calf do not jump" is not a code gate**, there is no per-kind
branch anywhere. What is broken is the same on all three: **the body never rises.** Root y range
across the entire bound: stag 0.97 studs of terrain drift, **hind 0.17, calf 0.13**. Peak upward
speed 4.3–15.7 studs/s, which is a box's wobble on uneven ground, not an arc.

**(c) TARGET.** 3.00 studs apex for the stag, `× KINDS.<kind>.scale` for the others
(3.000 / 2.566 / 1.485), floored at the clip's measured sink + 0.15 clearance — the floor binds on
the calf alone (1.3358 + 0.15 = 1.4858).

**(d) LEVER.** `BasePart.AssemblyLinearVelocity`, written once at take-off. There was no writer of
the animal's Y before this task, and that is why it never left the ground:

```
$ grep -n "AssemblyLinearVelocity\|PlaneVelocity" src/server/Boar/Body.luau   # at main
606:    handle.mover.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
620:    return handle.part.AssemblyLinearVelocity
2850:    part.AssemblyLinearVelocity = Body.collapseVelocity(part.AssemblyLinearVelocity, config)
```

Line 606 is the mover, in `Plane` mode on X and Z only; line 2850 is the death, which already writes
this exact property once. Y was gravity's alone.

**(e) HOW IT IS MEASURED AFTER.** The same probe, the same statistic.

## Claims

1. **At `main`, no deer's body rises when it bounds, and all three kinds DO enter the bound.**
   `<runs-dir>/325-before2.txt`: six `CROSS … LEAP=true` rows across stag, hind and calf; the
   per-frame `FRAME` rows for Boar66/67/68 show the leap clip at weight 1.00 and y flat to 0.17 /
   0.13 studs. Verify: the file, and `docs/research/2026-10-23-deer-road-leap.md` §8.1.

2. **The body now leaves the ground, and the figure is the lever's own.** `Body.leapTakeoff` is
   `v = sqrt(2 g h)`; `Body.leapPlan` solves apex, rate and window together per kind. Measured after
   (cycle 3, `325-after3.txt`): peak upward speed stag 27.8/28.6/30.2, hind 26.8/26.0/25.2, calf
   18.4/20.1/15.2, against `v0` = 34.3 / 31.7 / 24.2 (the first sampled frame is already past the
   launch). Verify: `Body.leapPlan` in `src/server/Boar/Body.luau`, the table in §8.4.

3. **No second writer of the animal's position.** The mover is `LinearVelocity` with
   `VelocityConstraintMode = Plane` on X and Z (`Body.create`), and `docs/design/boar-ai.md` §6 says
   Plane mode leaves Y to gravity. The take-off write preserves X and Z
   (`Vector3.new(now.X, up, now.Z)`). Verify: `Body.create`'s mover block, and the one write in
   `Body.stepVisual`.

4. **The legs and the arc agree by construction.** The clip is started at its own take-off frame
   (`Body.leapStartAt`, 0.458) and played at the rate that makes its airborne span
   (`LAND_SECONDS - TAKEOFF_SECONDS`) last exactly `2 v / g`. `deer.spec` asserts that identity for
   every kind to 1e-6. Verify: `Body.leapRate`, and the spec case "bounds every kind over its own
   sink, and the arc and the legs agree (task 325)".

5. **Nothing sinks into the road any more, and TASKS.md 245c is closed by it.** The apex is floored
   at `LIFT_STUDS[kind] + CLEARANCE_STUDS`, so the clip's downward leg reach lands on air rather than
   through the surface. Measured in the freeze probe: root above the ground under it, stag 5.01 /
   hind 2.23 / calf 1.90–2.10 studs, against sinks of 1.19 / 1.26 / 1.34. Nothing moves the drawn
   mesh, so `docs/design/boar-ai.md` §6's ban on per-frame CFrame writing is not approached;
   `Body.liftDrawn` is still called once a life, at the death. Verify: the `APEX_STUDS` block in
   `Boar.CONFIG.MODEL.LEAP`, and the spec's apex-vs-sink assertion.

6. **One bound per crossing, for all three kinds.** Cycle 1 measured a stag bounding TWICE off one
   crossing (clip back to 0.491, vy +25.3): the Brain holds one `leaping` window for every kind and
   `Body` ends each kind's own earlier, so a gate asking only "is the leap clip playing" re-opened.
   `handle.leapSpent` is Body's half of Karen's rule. Cycle 3: **9 bounds in one drive, 1 take-off
   each, 3 of each kind** (`325-after3.txt`). Verify: the `leapSpent` block in `stepVisual`, and the
   take-off count in §8.4.

7. **No float after the landing.** Cycle 2's rebound (largest upward speed in the 3 frames after
   touchdown) was stag 10.50, hind 8.39, calf 18.35 studs/s. Cycle 3 zeroes a still-rising Y at the
   end of the bound and measures stag −0.50 / 4.55 / −5.33, hind 2.64 / 6.76 / −0.70, calf 4.13 /
   3.94 / 5.37 — the residual positives are animals climbing the bank the road crosses. A body on
   its way DOWN is left alone. Verify: the block in `stepVisual`, and the §8.4 table.

8. **The calf's bound is a calf's.** `APEX_STUDS` is per kind off `KINDS.<kind>.scale`, and
   `deer.spec` asserts calf < hind < stag. Measured peak upward speed orders the same way
   (claim 2). Verify: the spec case, and the frames below.

9. **A world with no leap is byte-identical.** `Body.leapPlan` returns `(0, 1, 0)` for a kind with
   no `APEX_STUDS` row and for a nil leap table, so every boar takes no impulse and draws at rate 1
   exactly as task 245b shipped. `deer.spec` asserts `Body.leapPlan("male", leap) == 0`. Verify:
   that case, plus `Body.hasClip("leap", config)` still gating the branch in `clipFor`.

10. **FOREST TEST PROOF, looked at.** Her place, `DEER_ROAD_LEAP` on, a real staged crossing, the
    animal frozen mid-bound and held on its own track, photographed from a man's eye height.
    - `325-before-stag-zoom.png` (main): the pose is a true bound — neck up, chest lifted, forelegs
      tucked — and **both forelegs disappear into the road surface and both hind legs are buried
      from the hock down**. No daylight under the animal anywhere.
    - `325-after-stag-zoom.png`: fully airborne over the road, forelegs folded at the knee under the
      chest, hind legs extended straight out behind, clear ground under every hoof.
    - `325-after-hind-zoom.png`: the hind airborne over the road, forelegs reaching forward for the
      landing, hind legs trailing; her calf standing on the verge beside her for scale.
    - `325-after-calf-zoom.png`: the calf airborne, forelegs tucked, hind legs trailing, all four
      hooves clear — visibly a smaller, lower bound than the stag's.

## What could not be verified

- **Karen's own look.** Every frame here is a bound frozen at one phase and photographed; nobody has
  watched the motion run at speed. `DEER_ROAD_LEAP` is on in her place, so this is one drive away.
- **The bound's LENGTH is short and is not fixable here.** At Roblox gravity (5.6× Earth's) apex and
  airtime are one number: 3.00 studs of apex is 0.350 s and 2.8 m of ground, where a real red deer's
  bound is longer. Making it longer means slowing the clip past the point where it reads as a bound.
  Written up in §8.2 rather than hidden.
- The forward speed still dips at touchdown (cycle 3: stag 12.9–23.9, hind 13.0–17.3, calf 24.0
  studs/s against 24–28 before it). It recovers inside four frames and was not chased further.
