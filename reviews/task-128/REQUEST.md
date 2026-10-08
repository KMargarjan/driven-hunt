# Task 128 - unblock DEV's gate: the generator arrives as source

Task: 128
Round: 2
Base: main
Code commit: `b414f4d5c88f0a2bb01cb67c8465c06f3e3f9dd1`

```
[harness] PASS: 33/33 checks @ b414f4d5c88f0a2bb01cb67c8465c06f3e3f9dd1 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ b414f4d5c88f0a2bb01cb67c8465c06f3e3f9dd1 (clean tree)
```

The `[harness2]` line is the Director's: it needs one Studio open, and this round's live proof
needed the Forest Test open beside DEV.

**THIS TASK IS ONE OF NINE IN ONE PR** (122-130, `task-130-spawn-view` -> `main`). Director
decision, recorded in `ESCALATE.md`: no branch below 128 can pass the gate on its own -- DEV's
map could only be rebuilt once 128's bundler existed, and 129 fixed the specs 123-127 broke --
so the evidence for every task in the stack is the gate AT THE HEAD, and every task still gets
its own review.


## What changed

One Python file. `mapgen build/verify/clear` had been dead since the MCP thread started refusing
every `require`, which is why DEV still held hand-made experiments and its gate had failed 18 runs of
23 since task 122.

## What round 1 found, and what round 2 did

**ROUND 2.** #1 `command_verify`'s reachability call gets `with_boar=True`, like `command_reach` -- without it `__dh.Boar` was nil, `MapGen.reachability` took its early return and `verify` printed FAILED at every seed, which is the design's standing determinism gate. #2 `MapAssetTemplates` is out of `WORKSPACE_ALLOWED`; what that means for DEV is written where the list is, and said plainly in this request.

## Claims

1. **The generator is sent as SOURCE.** Each module of this branch's `src/serverstorage/MapGen` is
   wrapped in a closure handed its own real `script` instance and every `require` is rewritten to the
   bundle's table. Verify: `BUNDLE_MODULES`, `REQUIRE_REWRITES`, `bundle_source`, `bundle` in
   `tools/mapgen.py`.
2. **An unknown require shape cannot reach Studio**: `bundle_source` raises unless every `require`
   outside a comment has been rewritten.
3. **Only the bundler was ported** from `task-121-forest-block1`. That branch's `MapGen`, `Config`,
   `Layout`, `Props`, `Scatter`, `Map` v4, its specs, `planSummary` and `shotCameras` are not here;
   the module list is this branch's graph, including `MapGen/Assets.luau`, which 121 does not have.
4. **The `studio_id` scoping task 122 added to `call` is KEPT** -- 121's own copy dropped it, and
   both places were open and connected while this ran.
5. **It works**: `mapgen contract` returns counts and a marker digest in DEV where it used to die at
   step 1.
6. **DEV is rebuilt from the seed the contract expects.** `Map.SEED` is 1; `build --seed 1 --backup
   census` ran 262/262 steps and printed digest
   `15183f41211b3ba32453bf012277a323182fa95e07824a0479c68a8e884d8534`, which is `Map.DIGEST` in
   `src/shared/Map/init.luau` character for character. `mapgen contract` is now OK: 8 shooter posts,
   4 boar spawns, 1 drive line, 1 driver start, 12 trees.
7. **The measured payload**: 196 KB, 639 KB with the boar's modules for `reach`, against the 768 KB
   `execute_luau` was measured to accept.

## What could not be verified

- **What the rebuild destroyed, by name.** The Director's dispatch says DEV held Scene / Scene2 /
  VerdantTest experiments inside `Workspace.DrivenHuntMap`. What I measured myself is that the folder
  held 7,460 descendants with 0 tagged markers before and the generated bare world after. I did not
  list its children before destroying them, and `--backup census` only inspects Workspace's top level.
- **The generated map's LOOK.** `map-road` shows the road with its stakes at even spacing; `map-wide`
  from 1,100 studs is flat fog colour and shows nothing, which I am not counting as evidence. This
  branch's digest is task 85's BARE world, so there is no wood to photograph.
