# Task 85 — a bare test world

Task: 85
Round: 2
Base: `main` (`155c021`)
Code commit: `fccc2194bf290c8778dc1e8889bef6d5749e9618`

```
[harness2] PASS: 32/32 checks @ fccc2194bf290c8778dc1e8889bef6d5749e9618 (clean tree)
[harness]  PASS: 32/32 checks @ fccc2194bf290c8778dc1e8889bef6d5749e9618 (clean tree)
```

## Claims

1. **THE FIX IS A GUARD, NOT A SWEEP.** `measuring(c, ...)` in `map_contract.spec` names the layers a
   case measures and **errors** when one of them is off in that config. So the vacuous pass the switch
   made possible cannot come back by hand-editing one case, and a typo'd layer name errors too.
   A case asserts the guard itself, both ways: `measuring(config(), "trees")` fails with "trees" in the
   message, `measuring(withScenery(), "trees", "relief", "hedges")` returns the very same table, and
   `"treees"` fails.
2. **FINDING 1 — both cases measure again.** "puts no hedge segment inside a gate" takes
   `measuring(withScenery(), "hedges")`, and the section 7.3 spacing case
   `measuring(withScenery(), "trees")`. The run's own notes are the evidence: `wood: closest two trunks
   over 5 seeds are 11.30 studs apart (guaranteed 11.0)` and `species: spruce 1097, birch 744, oak 554,
   alder 339 of 2734`, against `inf` and `0 of 0` in round 1.
3. **FINDING 2 — the three heightfield cases measure the bench, the pad and the easing again**: the
   road/track flatness, the verge-away comparison and the spawn-pad flattening all take
   `measuring(withScenery(), "relief")`, so a `benchHeight` that flattened the whole map fails them, as
   `wood density: 17.66 trees/10k in the band, 0.88 in the backdrop` shows the relief-fed scatter is
   live again too.
4. **THE BARE WORLD IS STILL ASSERTED, IN ONE PLACE.** "builds the bare world" asks the live config:
   flat at `GROUND_Y`, `bogDepth` 0, no tree blocks, hedge lines or high seats, `onTrack` false, 16
   stakes and no other furniture kind — each against the layer-on answer, so none of it bounds a
   generator that does nothing.
5. **AND THE FURNITURE CASE'S TASK 66 RULE COVERS THE WHOLE LAYER AGAIN** (round 1 note): "builds every
   piece of furniture" takes `measuring(withScenery(), "barriers", "logPiles", "fence", "reeds",
   "highSeats")`, so `CanQuery = false` is asked of the logs, booms, fence and reeds and not just the
   stakes. Also fixed: the furniture step's label lists the layers this config builds, the scatter
   block's config is hoisted out of `reject`, and the owner row's duplicated cells are gone.

**Not verified:** nobody has played the bare world. The Architect's `docs/design/map-generator.md`
sections 5.2/6.2/6.3/7.2/8.1 still describe the full world, and nothing compares the place's map with
`Map.DIGEST` — both are the round 1 notes, not touched here.
