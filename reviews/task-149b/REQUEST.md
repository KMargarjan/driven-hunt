# Task 149b - the shot radius, the crossing, and two things I got wrong last round

Task: 149b
Round: 1
Base: main (`c114359`, task 149 item 0 merged as PR #132)
Code commit: `8468e383e653ca63bbf83c0796da6751a832225a`

```
[harness] PASS: 33/33 checks @ 8468e383e653ca63bbf83c0796da6751a832225a (clean tree) scope=all
```

`test2` is N/A: the diff is `Boar`, `Weapon`, two boots, `Flags` and one spec — nothing in
`TWO_PLAYER_PATHS`.

Karen, 2026-10-10 ~18:10, on the three items (full text in `PLAYTEST.md`): *"yes boars still
sometimes stand after dead and stays / also when I shoot sometimes they dont run ... I shoot and few
run and next to them another group walk / and also when they cross another side they have to run
away not stay and od circles"*. **No Architect run:** one new precedence row in a table that already
has eleven, and one field on a payload.

**TWO ITEMS FIXED AND MEASURED, ONE NOT REPRODUCED, AND TWO CORRECTIONS TO MY OWN TASK-149 REPORT.**

## The claims

1. **ITEM 0 WAS NOT A DEFECT, AND MY LAST REPORT WAS WRONG.** I told the Director the rifle strands
   its last magazine — `0/3 .416 3`, no further fire. Fired through the weapon's own remote, sixteen
   times, it does nothing of the kind:

   ```
   shot  3 settled: live=3 reserve=6     shot  9 just after: live=0 reserve=3
   shot  6 settled: live=3 reserve=3     shot  9 settled:    live=3 reserve=0   <- it reloaded
   shot 12 onward:  live=0 reserve=0  -- correctly empty, nothing stranded
   ```

   It fires all twelve rounds and auto-reloads at 3, 6 and 9, **including from a reserve of exactly
   3**. I had sampled it in the 0.3 s between the ninth shot and its own magazine change, and read
   "nothing changes when I click" as a jam when the clicks had stopped reaching the viewport.
   **Nothing was changed for this item.**

2. **ITEM 2's RADIUS: 29% → 91%, MEASURED EITHER SIDE OF THE CHANGE.** Thirty-three shots through
   the real server path, counting every live animal inside the radius and how many were at a flight
   speed one second later:

   ```
   before (120 studs, from the muzzle only)   13 shots   57 of 195 ran   29%
   after  (40 m shooter + 60 m impact)        20 shots  200 of 220 ran   91%
   ```

   The before run was taken against this commit's own parent (`git checkout dc51a3d^ -- src/...`),
   so the two differ by the change and nothing else.

3. **THE CAUSE WAS ARITHMETIC, AND IT WAS WRITTEN IN THE COMMENT.** `SHOT_AUDIBLE_STUDS = 120` is
   33.6 m at `METRES_PER_STUD` 0.28, while the comment above it called that *"about twice the
   distance she shoots at (her hits in task 138 were at 30 to 71 m)"* — **comparing studs with
   metres**. Her shots are 107–254 studs, so the radius was 0.47 to 1.12 of her own shooting
   distance, measured **from the muzzle alone**. The group standing beside the animal she hit never
   heard the shot. That is *"I shoot and few run and next to them another group walk"*, exactly.

4. **SO THE UNIT IS METRES AND THERE ARE TWO CIRCLES.** `SHOT_HEARD_FROM_SHOOTER_M = 40` and
   `SHOT_HEARD_FROM_IMPACT_M = 60`, with the studs beside them and `boar_behaviour.spec` asserting
   the two spellings agree — the assertion that would have caught the original mistake. Not the
   whole wood, which Karen also ruled out (*"blast radius is a bit"*): 60 m is a quarter of the
   Forest Test's depth.

5. **THE SHOT CARRIES WHERE IT LANDED.** `shotSignal` gains `at` — the aim ray's own strike, or the
   end of the range when it hit nothing — and both boots pass it to `hearShot(muzzle, at)`. `impact`
   is optional, so every caller written before this task behaves exactly as it did. **An animal runs
   from the NEARER bang**, so one standing beside the animal that was hit breaks from the impact
   rather than from a hunter 200 studs behind it. **Verify:** `boar_behaviour.spec`, "hears a shot
   from the IMPACT as well as from the shooter" — the same bang is inaudible without `impact` and
   puts the animal in FLEE with it.

6. **ITEM 3: MAX DWELL 60.7 s → 3.3 s, CIRCLE WINDOWS 120 → 24.** Three 150 s traces of every
   animal south of the road:

   ```
   before   82 crossings   max dwell 60.7 s   circle windows 120
   after    63 crossings   max dwell  3.3 s   circle windows  24
   ```

7. **AND THE CAUSE WAS MEASURED BEFORE IT WAS FIXED.** Every dwelling animal was playing a **calm**
   clip — `idle` ×19, `grazeEnd` ×18, `digWalk` ×6, `grazeLoop` ×9, `smell` ×5 — so what they were
   doing was returning to the task-117 repertoire and grazing where they stood. The wandering IS the
   circles. **After the change not one dweller was on a calm clip**: the single animal over 3 s was
   playing `walk`.

8. **THE BRAIN DOES NOT NEED TO KNOW WHERE THE ROAD IS.** Crossing means the people are BEHIND you:
   `_senseAware` latches `_crossed` the first tick a threat sits on the far side from the exit, one
   way, and a new row above the idle row keeps a crossed animal in flight to `field.exitZ` instead
   of falling through to `_senseIdle`. The GAIT is still the pace system's — a walk or a trot with
   nothing near — so this says "keep going", not "sprint for ever". Behind
   `PACE.LEAVE_AFTER_CROSSING`, and task 127 had already written Karen's earlier words into
   `_outcome`: *"once they in another side of road they run away"*.

9. **ITEM 1 DID NOT REPRODUCE IN 7 KILLS, AND THREE OF MY METRICS WERE INVALID.** Worth writing down
   so nobody repeats them: **(a)** the trunk's `UpVector` says 6 of 6 upright — but `Body.collapse`
   leaves the box alone on purpose when a visual exists; **(b)** the drawn height against one global
   mean says 3 of 5 standing — but a cub on its feet is shorter than a male on its flank; **(c)**
   the drawn height against the animal's OWN standing height says 6 of 6 standing — but the boar is
   a single **skinned** MeshPart, so bone transforms never move its bounding box. What IS measurable:
   the death clips play on every kill (`deathLeft` at +1 s, `deathPaddleLeft` from +5 s) and the
   paddle **holds its last frame out to +25 s**, so the rig never returns to its standing bind pose.

10. **149a: `FIRST_PERSON.expires` WAS THE SAME TIME BOMB AS `RIFLE`'s.** Left at `2026-10-18` it
    fails `flags.spec`'s rot tripwire on the 19th and blocks whatever gate runs that day. It keeps a
    retirement date now, with the reason beside it.

## The frames, looked at (rule 5)

| frame | what it shows, wrong first |
|---|---|
| `t149b-carcass.png` | **I moved this carcass in front of the lens to photograph it** — the game owns the camera and overwrites a scripted CFrame every frame, so the body came to the lens rather than the other way round. It proves the POSE, not where it fell. And the pose is a dead animal: a sow **on her flank**, legs out to the side, head down on the ground, tongue out. Not standing |

## Standing rule A, Forest Test, 85 s

* the Tool is in the CHARACTER at 15 s and at 85 s (`gun in hand @15s=1 @85s=1`)
* **0 "Stack Begin" and 0 error lines** in the whole console
* **five waves released**, worst 1 boar sound at once over 10 s with 20 boars alive

## What I could not verify, and what is short of target

* **ITEM 1 IS UNRESOLVED, NOT CLOSED.** Karen said "sometimes", and seven kills is a small sample for
  a sometimes. I have no metric that can see a skinned rig's pose from the server, so the next
  attempt needs either a bone CFrame (`Bone`/`Motor6D` inside the Visual) or a frame per kill.
* **BOTH TARGETS WERE 100% / 0 AND NEITHER WAS REACHED.** The radius is 91%, not 100%: the shortfall
  is animals that are already DOWN or CRIPPLED (which deliberately do not hear) plus any still on
  the ACCEL ramp at the one-second mark — I did not separate those two, so I cannot say the
  remaining 9% is all legitimate. Circle windows are 24, not 0, and **my metric counts any 300° of
  turning inside 10 s**, which includes an animal steering round three trunks; the thing Karen
  described — standing still and milling — is gone, which the clip census shows directly.
* **The before/after crossing runs had different populations** (82 against 63 crossings) because the
  world releases waves on its own schedule; the dwell and circle numbers are per-animal maxima and
  totals, so they are comparable, but they are not the same animals.
