# Task 122 - the forest drive test: a small playable drive in its own place

Task: 122
Round: 2
Base: main
Code commit: `cced90502fddfbeda8efd3ba74e27779834fe879`

DIRECTOR NOTE (re-review at cced905): the stack's round-3 fix changed this task's owned code (`src/server/ForestTest/init.luau` and/or `src/client/Hud/init.luau`); round 1 PASSed before it, so this re-reviews the same claims at the final code commit cced905.

```
[harness] PASS: 33/33 checks @ cced90502fddfbeda8efd3ba74e27779834fe879 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ cced90502fddfbeda8efd3ba74e27779834fe879 (clean tree)
```

**THIS TASK IS ONE OF NINE IN ONE PR** (122-130, `task-130-spawn-view` -> `main`). Director decision,
recorded in `ESCALATE.md`: no branch below 128 can pass the gate on its own, so the evidence for
every task in the stack is the gate at the head, and every task still gets its own review.

## What round 1 found, and what round 2 did

**The blocking finding was real and it reached Karen's place.** `ForestTest.releaseLine` asked
`Boar.CONFIG` for its kinds; that table's `KINDS.ENABLED` follows the `BOAR_MODEL` flag, which is
`default = false`, so **every animal in every line spawned "male"**, `Line.order`'s rank table saw one
rank for all of them, and the sow-led file the line mode exists for could not happen. The `rolls`
argument was `{}` as well, so `(rolls[index] or 1) < YOUNG_MALE_CHANCE` was never true either.

## Claims

1. **The world is chosen by PLACE, not by a flag.** `Map.WORLD_BY_PLACE` maps each place id to a
   world string and `Map.EXPECTED_WORLD` reads it; the DEV place resolves to exactly what it
   resolved to before. Verify: `src/shared/Map/init.luau`, and `map_contract.spec` still passes.
2. **`ForestTestBoot` is the composition root -- but it is NOT the only file that knows this world
   exists**, and round 1 was right to call that out. Three others name it, each for its own reason:
   `src/server/MatchBoot.server.luau` stands aside in it, `src/shared/Map/init.luau` publishes
   `Map.PLAYTEST_WORLD`, and `src/server/BoarAssetsBoot.server.luau` reads that value to decide
   whether to load the boar's mesh. What is true of `ForestTestBoot` is narrower: it is the only
   place that BUILDS this world -- the runtime, the config, the drive, the stand.
3. **The beaters are phantoms, and the Brain DOES tell the difference** -- it must, and round 1 was
   right again. `ForestTest.boarThreats` marks its invented beater `phantom = true`, and
   `src/server/Boar/Brain.luau` branches on it: a REAL driver inside `PACE.DRIVER_RUN_STUDS` makes an
   animal run, a phantom pushes it at a walk or a trot. The claim is that the beater reaches the boar
   through the SAME seam a player does (`Match.quickTestPhantom`'s shape), not that it is
   indistinguishable.
4. **The wave path is dormant in the shipped configuration.** `ForestTest.LINE.enabled = true`, and
   `ForestTest.step` returns inside that branch -- so `release`, `retire`, `urgeAcrossRoad` and
   `checkAtTheEdge` do not run, `state.active` stays empty and no phantom beater is ever placed. The
   push, the lateral pass and the turn-back are reachable by one word (`enabled = false`) and are
   what Karen accepted before task 127 replaced the wave with a line. Verify:
   `src/shared/ForestTest/init.luau` and `ForestTest.step`.
5. **The line asks the WORLD what is in it** (round 2's fix). `Runtime:config()` returns the merged
   config `Boar.newRuntime` built from `ForestTestBoot`'s world table, and `boarConfig()` in
   `src/server/ForestTest/init.luau` is the one place that asks it -- every other `Boar.CONFIG` read
   in that file where the world's answer was meant now goes through it (`SOUNDER.COMPOSITIONS`,
   `SENSE.NOTICE_MOVING`, `PACE.SPOOK_MEMORY_SECONDS`, the pace speeds). Real rolls are drawn from
   the drive's own `Random`. **Proven live in the Forest Test**, each line read front to back:
   `[female>cub>cub>cub>cub>cub>male>male]`, wave after wave.
6. **Only lines that have a route are released** (round 2's fix). With two lines and one route every
   animal used to be spawned and the group with no route was led by nobody, retired by nothing, and
   counted against `maxBoars`. Each surviving route keeps its own lateral offset, and the log line
   reads `made of spawned` so the two can be compared at a glance. Forced one-route case, live:
   `line 4: 7 of 7 animal(s) in 1 of 2 line(s)`.
7. **The unreachable "turn" phase is gone**, with the three measurements that killed it, in
   `backups/2026-10-06-forest-test-turn-phase.md` (rule 7). `Phase` lost the word, `beaterPosition`
   lost the `rear` parameter that branch was its only reader of, and `TASKS.md` row 122 no longer
   claims three phases. Verify: `ForestTest.wavePhase`, `ForestTest.beaterPosition`.
8. **Two small things that read as guards and were not**: `state.waveIndex += 1` now happens after
   the runtime check (a nil runtime used to burn a wave slot), and `state.startedAt or now` lost a
   fallback that could never fire, because 0 is truthy in Luau.
9. **A stand is a spot, and the arithmetic is tested now.**
   `tests/server/forest_stand.spec.luau` is new: the nine stands sit on the road curve to within
   1e-4 studs and 150 apart, the leash passes inside and fails outside and ignores height,
   `nearestStand` answers every stand and flips at the midpoint, every `wavePhase` branch is driven
   (including a sweep asserting the removed phase can never come back), and `beaterPosition` is
   checked on the flank and behind. Until this round the verification of record was an inlined
   Edit-place run written into `TASKS.md`, which nobody could repeat on a later commit.

## What could not be verified

- **The kill.** Task 122's round 4 fired 55 shots in this world and produced no hit report, no death
  and no carcass, and the cause was not found inside that time box. **It is proven now, but by a
  later task:** task 124's `HitLog` records hits and deaths in this same world, and its drive report
  lists them -- so the path works; what was never explained is why those 55 shots did not.
- **The two-player drive in THIS place.** `test2` runs in DEV; the Forest Test world is
  single-player by construction (phantom beaters) and has no second roster.
- **Karen's own judgement** of how often waves cross, how far the stands are apart, and whether a
  drive of this length is the one she wants. She has not played this world since task 127.
