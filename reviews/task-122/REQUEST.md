# Task 122 - the forest drive test: a small playable drive in its own place

Task: 122
Round: 1
Base: main
Code commit: `831a06fbe759608129b15f1fbfdfb2f5abebfb16`

```
[harness] PASS: 33/33 checks @ 831a06fbe759608129b15f1fbfdfb2f5abebfb16 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 831a06fbe759608129b15f1fbfdfb2f5abebfb16 (clean tree)
```

**THIS TASK IS ONE OF NINE IN ONE PR** (122-130, `task-130-spawn-view` -> `main`). Director
decision, recorded in `ESCALATE.md`: no branch below 128 can pass the gate on its own -- DEV's
map could only be rebuilt once 128's bundler existed, and 129 fixed the specs 123-127 broke --
so the evidence for every task in the stack is the gate AT THE HEAD, and every task still gets
its own review.


## What changed

A second place -- "Driven Hunt Forest Test", placeId 130094961655666 -- gets a drive Karen can play
alone: hunters on the road, phantom beaters a minute north, waves crossing in front of her.

## Claims

1. **The world is chosen by PLACE, not by a flag.** `Map.WORLD_BY_PLACE` maps each place id to a
   world string and `Map.EXPECTED_WORLD` reads it; the DEV place resolves to exactly what it
   resolved to before, which is why the harness sees no change. Verify: `src/shared/Map/init.luau`,
   and `tests/server/map_contract.spec.luau` still passes in DEV.
2. **`ForestTestBoot` is the composition root and returns immediately anywhere else.** It is the only
   file that knows this world exists; its first statement after the requires is the
   `Map.EXPECTED_WORLD ~= "forest-test"` return. Verify: `src/server/ForestTestBoot.server.luau`.
3. **The beaters are phantoms, at the seam that already existed.** `ForestTest.boarThreats` returns
   the real players plus a position with nobody standing on it, marked `phantom = true` -- the same
   shape `Match.quickTestPhantom` uses, and the Brain cannot tell the difference because a threat is
   a position and a kind. Verify: `src/server/ForestTest/init.luau`.
4. **A stand is a spot, and it is pulled rather than frozen.** The first seconds of walking are the
   choice, the timer saves it, and afterwards the player is leashed to a few studs by a pull, not an
   anchor -- because Karen asked to test walking too. Verify: `ForestTest.hunterStandX` and the
   stand/leash section of the same file.
5. **`MatchBoot` stands aside in this world** rather than running a drive with no markers and nobody
   allowed a gun. Verify: `src/server/MatchBoot.server.luau`.
6. **The boar's two flags are on by WORLD CONFIG, not by a live attribute.** `ForestTestBoot` passes
   full clones of `MODEL`, `CALM`, `PACE`, `MOVE` and `LINE` into `Boar.newRuntime`, so the DEV drive
   is untouched and nothing depends on a `DHFlag_` that is lost when the place is reopened.
7. **The harness learned there are two places.** StudioMCP refuses any call naming no `studio_id`
   once a second Studio is connected; `tools/studio_mcp.py` now resolves the harness place by
   `game.PlaceId` (not by the Studio's name, which comes back blank for seconds after a Play
   session) and says which Studio unscoped calls default to.

## What could not be verified

- **The two-player drive in THIS place.** `test2` runs in DEV; the Forest Test world is single-player
  by construction (phantom beaters) and has no second roster.
- **Karen's own judgement of the drive's feel** -- how often waves cross, how far the stands are
  apart -- which is a playtest, not a gate.
