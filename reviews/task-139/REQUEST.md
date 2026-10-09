# Task 139 - Karen's boar complaints

Task: 139
Round: 2
Base: main (`0c7f736`)
Code commit: `36bbcb6776abd62e09eca6435a8c89721df29e16`

```
[harness] PASS: 33/33 checks @ 36bbcb6776abd62e09eca6435a8c89721df29e16 (clean tree) scope=all
```

`test2` is N/A: no path in `TWO_PLAYER_PATHS` is touched.

## THE SLIDING IS SOLVED, AND THE CAUSE WAS THE CONSTANT I COULD NOT EXPLAIN

For six 150 s runs across two builds the median gap between the ground a boar covered and the ground
its clip was rated for was **56.2 %, stable to ±0.1**. I said in round 1 that I did not trust it.
Both halves turned out to be real bugs, and the number named the second one:

1. **`Body.stepVisual` was handed `speed = wantSpeed`** — the speed the animal was *asked* for.
   A boar pressed against a trunk is still ordered to run, so it drew the RUN clip rated for 24
   studs/s while covering no ground. That is Karen's *"sometimes boar stuck tree, hits and run in
   place"* exactly. It now reads the same velocity every other measurement in the file reads.
2. **`clipFor` was never handed `clipScale`.** It has asked for `info.clipScale` since task 119 —
   `gaitBands` divides every rate by it, because a female covers 0.8553 of a male's ground per stride
   and a cub 0.4372 — and the call site never put it in the table. So `bands.scale` was 1 for every
   animal and the whole per-kind correction was dead. **1 − 0.4372 = 0.5628**, which is the constant
   to within a rounding. A cub was stepping at 0.44 of the rate it needed.

**Measured: slide median 56.2 % → 0.0 %, p90 1.8 %.**

## The table

Three 150 s Forest Test runs per build, hunter at a stand, shots through the real `FireRequest`
route, reload after two.

| | main (3 runs) | round 3 (3 runs) | final build |
|---|---|---|---|
| **slide, median gap** | 56.2 / 56.2 / 56.1 | 56.2 / 55.9 / 56.2 | **0.0** (p90 1.8) |
| moving with NO locomotion clip | 22.2 / 26.0 / 27.0 % | 2.8 / 2.0 / 3.1 % | 2.5 % |
| **ran NORTH after a shot** | 8 / 6 / 4 — **6.0** | 0 / 0 / 0 — **0.0** | 0 |
| **stood after a shot** | 1 / 0 / 1 — 0.7 | 0 / 0 / 0 — **0.0** | 1 |
| came back north over the road | 0 / 0 / 0 | 0 / 0 / 1 | 1 |
| running in place (new metric) | — | 13 / 14 / 28 | 41 |
| worst sounds, one pack | 2 / 2 / 2 | 3 / 2 / 2 | 3 |
| worst sounds, world | 2 / 2 / 2 | 3 / 3 / 3 | 3 |

The three round-3 runs were taken **before** the `clipScale` fix; the final column is one run of the
shipped build. The `clipScale` fix cannot affect any position or state number — it only changes a
playback rate — so the movement columns stand; the slide column is the one it moved.

## The nine

1. **The dead `STILL_SPEED` branch is deleted**, and request item 7 of the last round with it. The
   Reviewer was right: `WALK_FROM` is 0.5 and the gate was 0.6, so it could never run.
2. **Four rules pinned**, each load-bearing: a moving grazer walks (`boar_calm.spec`); a cub's held
   gait is rated by its own stride (`boar_model.spec`); a flight with the gun **between** animal and
   exit goes to the exit and passes him to one side (`boar_move.spec`); and `Line.stillInFile` —
   extracted pure, because `releaseLine` cannot be driven in DEV (it needs `PathfindingService` at
   the Forest Test's own coordinates, task 137) — pins that `gone` is **permanent**.
3. **`stylua src tests` is clean** and CI's format gate will pass.
4. **`FLIGHT_SWERVE` always passes him to one side.** The Reviewer's note was exactly right: when the
   shooter stands directly between animal and exit, `away` is `-toExit`, `sideways` is **zero**, and
   the animal ran straight down the barrel. It now falls back to the animal's own `_whiskerSide`, so
   two animals abreast break the same way every frame instead of flipping. Comment corrected; case
   added.
5. **One shot flushing the whole line is KEPT**, on the Director's decision and Karen's own word —
   *"after shoot all run away"* (2026-10-05). It is a consequence of a line being a real sounder:
   `_stepAlarm` now reaches line members, so the panic spreads member to member and `line.gone` takes
   them all out of the file.
6. **Step audibility: 70 studs**, one reach for all three gaits (`SOUND.STEPS.*.audibleStuds`), with
   the volumes untouched. It is 70 rather than more because `boar_shot.spec` holds the other half of
   task 123 round 4 — the grunt carries more than twice as far (160 against 70). Sounds at once:
   **worst 3 in one pack, 3 in the world**.
7. **Running in place** is fixed at the cause (the drawing reads the real speed) — see the top.
8. **`SHOT_AUDIBLE_STUDS` 350 → 120.** 350 was the whole field: the Forest Test is ~600 studs from
   the spawn line to the exit, so one shot emptied every line in the world. 120 is about twice the
   range Karen shoots at (task 138 measured her hits at 30–71 m).
9. **A calm wave walks or trots and never runs.** `paceMix` drops the `run` row (it was a fifth of
   all waves, drawn before anything had happened). A run is a reaction — a shot inside the radius, a
   beater close, or a hit. **The smoke shows it**: four waves, three at a walk and one at a trot.

## What could not be verified

- **"Running in place" is not zero: 13 / 14 / 28, and 41 on the final build.** This is NOT the case
  Karen reported — that one was a run clip at full tilt on a wedged animal, and it is gone with the
  `wantSpeed` fix. What the counter now sees is `MODEL.MIN_RATE`, the 0.4 floor that exists to stop a
  clip reading as slow motion: an animal below about 1.1 studs/s has its walk clip floored there, so
  the feet move at ~1.14 studs/s while the body does less. It is a shuffle, not a gallop, and the
  floor is a deliberate rail. Whether to trade it for a hard stop below `WALK_FROM` is a feel
  question I am not deciding here.
- **MY PER-SHOT REACTION COUNT IS BROKEN and I am not reporting a number for item 8.** The metric
  keyed its set on `(id, distance)`, so one animal appears many times as it moves and the "count"
  came out above the number of boars alive. What IS evidenced for item 8 is the config change and the
  two specs that pin the rule — inside the radius sprints on the same tick, outside grazes on — both
  of which now read the distance off `SENSE.SHOT_AUDIBLE_STUDS` instead of typing it, so they cannot
  go stale against it again.
- **One animal came back north in two of the four final runs.** Not zero, and down from the 19–26 of
  the first attempt. I have not chased the last one.
- **Four existing specs encoded the old numbers** (`shotAt(340)`, `shotAt(200)`, the live spec's 345
  and 395, and `expect(SHOT_AUDIBLE_STUDS).to.equal(350)`). Each is updated **with its reason** and
  three of them now read the config rather than a literal. The rule each case exists for is
  unchanged; only the number it is measured against moved.
- **Standing rule A, Forest Test, 85 s:** the Tool in the CHARACTER at 15 s and at the end
  (`tool=true backpack=false` both), **0 fault lines in 24**, four wave lines released — and all four
  at a walk or a trot, which is item 9 running.
- **Studio:** I opened DEV from the Forest Test window, read the sync dialog (edits only — no files
  were removed this round, so no instance removal was possible), accepted, gated, then closed the
  place with **Save** and closed the empty window. Karen has one Studio, the Forest Test, in Edit.
