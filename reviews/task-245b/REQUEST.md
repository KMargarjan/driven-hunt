# Task 245b - the deer's road leap, wired behind DEER_ROAD_LEAP

Task: 245b
Round: 1
Base: 92735a05 (main)
Code commit: 76adac58f3885bc199695ac35078c22ef3a099bc

```
[harness] PASS: 34/34 checks @ 76adac58f3885bc199695ac35078c22ef3a099bc (clean tree) scope=all
```

`[harness2]`: **N/A.** Nothing this task changed is in `TWO_PLAYER_PATHS` -- the files are
`src/server/Boar/{init,Brain,Body}.luau`, `src/server/BoarAssetsBoot.server.luau`,
`src/serverstorage/Assets/init.luau`, `src/shared/Flags/init.luau`, `src/shared/ForestTest/init.luau`
and `tests/server/deer.spec.luau`. `tools/agents.py` agrees (it prints how many of the changed code
files need two players).

## What this is

The Director published the clip that task 245 stopped at (`deer.anim.leap = 126500539626404`, ONE
id for all three kinds as measured), so item 3(c) could be built: **a running deer bounds once as it
crosses the road**, behind a new flag, born off.

## Claims

1. **Every number the code uses was measured on the PUBLISHED ASSET, in Play, and two of them moved.**
   This is the Reviewer's own round-1 note on task 245: the Blender pair that produced the earlier
   figures sits behind a `bpy` import that `boar_prep.py selftest` cannot reach, so its arithmetic
   was unpinned -- and the game plays the STAG's clip on geometry baked smaller, where bone
   translations are absolute studs. Live, on each kind's own published model, 49 samples across the
   clip, reading every `Bone.WorldPosition` against the rig's bottom plane:

   | | Blender (task 245) | **live, this task** |
   |---|---|---|
   | length | 2.000 s | **2.0000 s** |
   | sink, stag | 1.660 studs | **1.1863** |
   | sink, hind | 1.661 | **1.2563** |
   | sink, calf | 1.084 | **1.3358** |

   The live order is the one that makes sense -- the sink GROWS as the animal gets smaller, which is
   `deathLiftStuds` (0.011 / 0.185 / 1.325) again. Verify: research note section 6b, and
   `MODEL.LEAP.LIFT_STUDS`.
2. **`clipSeconds = 2.0` was taken two independent ways and the method is checked against two rows
   that were already reviewed.** `KeyframeSequenceProvider:GetKeyframeSequenceAsync` reports 49
   keyframes with the last at **2.0000**, and `Animator:LoadAnimation(...).Length` reports 2.0000 on
   all three rigs. The same pair over `deer.anim.run` gives **0.5833** (the manifest says 0.583) and
   over `deer.anim.death.left` **1.1667** (1.167). Verify: `deer.spec`'s existing
   "agrees with the manifest about how long each deer clip is" now covers the leap too.
3. **The flag is read at exactly one place.** `Boar.CONFIG.MODEL.LEAP.ENABLED = Flags.isOn("DEER_ROAD_LEAP")`
   and nothing else in the game asks. `Brain.leapStarts` takes the leap table as a **parameter**, so
   both states are reachable with the row at false -- which is what
   `docs/design/feature-flags.md` section 11 requires and what every new spec case does. Verify:
   `grep -rn DEER_ROAD_LEAP src/` is the row plus that one line.
4. **The row is born off, owned, dated and expires inside 21 days** (2026-10-23 -> 2026-11-13), and
   `Flags.MAX_FLAGS` goes 15 -> 16 **with the reason written out**, exactly as task 238 did rather
   than quietly retiring somebody else's row. 82b is still the real fix and still the Director's
   call. Verify: the row's comment block and `deer.spec`'s "is BORN OFF" case.
5. **Where the road is, is the WORLD's fact and it lives on the field.** `ForestTest.fieldFor` gains
   `road = { halfWidthStuds, zAt }` beside `bounds`, `exitZ` and `groundY`, because where the lane
   runs is the same kind of geometry those are and the field is already what a `Brain` is born with.
   **`zAt` is a function because the ride is a SINE** -- it swings +-30 studs over the map's length,
   so a constant z would put the band in the trees at one end. The four numbers
   `forest_stand.spec` pins are untouched. Verify: `deer.spec`'s "gives the Forest Test's field a
   road that IS ForestTest.roadZ", which checks the curve at four x values rather than checking that
   a road merely exists.
6. **The DEV world has no road and therefore no leap**, which is what keeps the DEV harness
   measuring the game it measured yesterday: `Boar.CONFIG.field` has no `road` key, `Brain.onRoad`
   answers false for nil, and `leapStarts` can then never be true. Verify: the `onRoad` case, and
   `Boar.CONFIG.field`.
7. **Two pure functions carry the whole rule.** `Brain.onRoad(position, road)` and
   `Brain.leapStarts(onRoad, armed, speed, runFrom, leap)` -- plain values in, a boolean out. The
   four conditions are Karen's sentence: switched on, on the band, **armed** (clear of the band
   since the last bound -- her *"once per crossing"*), and running at or above `MODEL.RUN_FROM`, so
   the leap and the gait under it agree by construction instead of by a second speed that could
   drift. Verify: the two spec cases, which remove each condition on its own.
8. **`Body.clipFor` gains one branch, below the death and the flinch and above every gait.** A deer
   shot mid-bound flinches and one that dies mid-bound falls; a leaping animal is not trotting. Rate
   is the literal **1** -- a bound is not a cycle whose feet must keep up -- which is why
   `CLIPS.leap.groundStudsPerSecond` is 0. The prep DOES report 4.354 studs/s for this clip and that
   number is an artefact: the contact heuristic calls the lowest fraction of a hoof's range
   "planted", and a bound has no planted foot. Verify: "draws the leap above every gait and below
   every reaction".
9. **`Body.hasClip` is asked in exactly one place**, so a world with no published leap draws what it
   always drew -- which is every boar, whose `MODEL.CLIPS` has no `leap` entry at all. Verify:
   "draws NOTHING with no published leap, which is every boar".
10. **MEASURED LIVE, with the flag driven on by parameter:** a stag pushed south crossed a 40-stud
    band at **44.9 studs/s**; the clip became `leap` on the tick it entered the band (z - roadZ =
    **+18.9**, inside +-20) and stayed for **46 samples -- 0.75 s at 60 Hz, which is `LEAP.SECONDS`**
    -- once for the crossing, and the animal ran on to z - roadZ = -278 without a second one. The
    probe also printed `shipped MODEL.LEAP.ENABLED = false`, so the row really is off.
    **FRAME (rule 5 and rule F):** a stag frozen at the peak of its bound (t = 0.5417) over the DEV
    map's own road, photographed from the player's eye height **y = 5.15**, 24 studs away:
    `.screenshots/20261022T234849Z-245b-leap-dev2.png`. Looked at: legs tucked, antlers back, the
    whole animal clear of the ground.

## What I could not verify

* **No frame on KAREN'S path, and it is a `NEEDS DIRECTOR` rather than a miss.** The Forest Test is
  not open -- the Builder closed it at the end of task 245 because the standing block says to before
  any harness run, and this dispatch assumed it was still up. The standing block's own answer is
  what `ESCALATE.md` now carries. The flag was therefore never set in her place, and her attributes
  were not read, not written and not restored: **nothing in the Forest Test was touched by this
  task at all.**
* **The sink is measured and deliberately NOT cancelled.** A hind hoof passes up to **1.19 studs**
  (stag; 1.26 hind, 1.34 calf) below the rig's own floor for **0.25 s** at the peak of the bound,
  and nothing outside t = 0.458..0.708. Cancelling it means moving the drawn mesh every frame and
  `docs/design/boar-ai.md` section 6 forbids per-frame CFrame writing on the boar -- `Body.liftDrawn`
  toggles welds and is called ONCE, at death -- while a single lift held across the bound would pop
  the animal 0.9 studs. The per-kind numbers are in `MODEL.LEAP.LIFT_STUDS` with that reasoning on
  them, and TASKS.md 245c queues it. **This is a judgement I took; it may be the wrong one.**
* **The live fire check used a straight road and a probe's own runtime**, not
  `ForestTest.releaseLine`: a probe gets a fresh module cache and can never reach a boot script's
  runtime. What it proves is the trigger, the duration and the once-per-crossing latch. What it does
  not prove is the sine road in the live world -- that is claim 5's spec, and the Forest Test frame
  above.
* **The staged frame's animal is anchored and frozen**, and its body was placed by the probe rather
  than settled by physics, so **nothing about its height above the ground should be read off that
  picture**. It is evidence of the POSE. The sink numbers come from the rig-local measurement in
  claim 1.
* **Task 245's own one-in-three harness flake is still unidentified** (544 passed, 1 failed, 1 error
  at `e6945774`, no `.luau` in that commit). It did not recur here: this task's gate failed once
  with three REAL failures, which are named in their own commit, and passed 34/34 after they were
  fixed.
