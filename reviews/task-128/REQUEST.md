# Task 128 — unblock DEV's gate

Task: 128
Round: 1
Base: `93ce904` (task-127-boar-line)
Code commit: `50f0503ba3a1e897055f2f79b10964fda76efe2d`

One Python file changed: `tools/mapgen.py`. No Luau, no spec, no `src/`.

**THE REVIEW CANNOT RUN YET, AND THIS SAYS SO UP FRONT.** The gate at the code commit is
`[harness] FAIL: 29/33 checks @ 50f0503ba3a1e897055f2f79b10964fda76efe2d (clean tree) scope=all`.
It fails on specs this task did not touch — see claim 6 — and `tools/agents.py` refuses a request
touching `tools/` without a harness PASS for the code commit. This file is written so the claims are
on the record for whoever picks the chain up.

## What changed

`mapgen build/verify/clear/contract/plan/digest/reach/shots` could not reach the generator at all:
the MCP thread refuses every `require` ("additional values for the Capabilities property:
LoadUnownedAsset"), which `tools/studio_mcp.py`'s header has carried since 2026-10-02. The generator
is now sent as SOURCE instead: each module is wrapped in a closure that is handed its own real
`script` instance, and every `require` is rewritten to the bundle's own table.

Ported from `origin/task-121-forest-block1`, and only the bundling.

## Claims

1. **The bundler is the only thing ported.** `BUNDLE_MODULES` names this branch's
   `src/serverstorage/MapGen` — including `MapGen/Assets.luau`, which 121's generator does not have —
   and 121's `planSummary`, `shotCameras`, its `MapGen`/`Config`/`Layout`/`Props`/`Scatter`, `Map` v4
   and its specs are absent. Verify: `git diff 93ce904..50f0503` is one file; `git diff 50f0503
   origin/task-121-forest-block1 -- tools/mapgen.py` still shows all of 121's generator-side changes.
2. **The `studio_id` scoping task 122 added is kept.** `call` still goes through `studio._scoped`;
   121's own `call` dropped it. Verify: read `call` in `tools/mapgen.py`. It matters here because two
   Studios are open and connected.
3. **An unknown require shape cannot reach Studio.** `bundle_source` raises unless every `require`
   outside a comment has been rewritten. Verify: read it; or add a `require(workspace.Nothing)` to any
   bundled module and run `python tools/mapgen.py plan --seed 1`.
4. **It works.** `python tools/mapgen.py contract` in DEV returns counts and a marker digest where it
   used to die at step 1. Verify: run it.
5. **DEV is rebuilt from the seed the contract expects.** `Map.SEED` is 1 ("the seed the committed map
   was built from"); `build --seed 1 --backup census` ran 262/262 steps and printed digest
   `15183f41211b3ba32453bf012277a323182fa95e07824a0479c68a8e884d8534`, which is `Map.DIGEST` in
   `src/shared/Map/init.luau` character for character. `mapgen contract` is now OK: 8 shooter posts,
   4 boar spawns, 1 drive line, 1 driver start, 12 trees. Verify: `python tools/mapgen.py contract`
   and `python tools/mapgen.py digest`.
6. **The gate now runs in DEV and fails on the 123–127 stack, not on this change.** Server 728 passed
   / 17 failed, client 143 / 3: `boar_shot.spec` (642, 672, 1028, 1108, 1133, 1403, 1536, 1646, 1710,
   1807), `boar_behaviour.spec` (215, 267, 297, 458, 512), `boar_calm.spec` (466),
   `camera_client.spec` (237), `compass.spec` (104, 170). This task changes one Python file and no
   Luau, and every one of those specs covers tasks 123–127, whose rows all read GATE BLOCKED. Verify:
   `git diff --stat 93ce904..50f0503`, then read the failing assertions.

## What I could not verify

- **That the gate passes.** It does not, and claim 6 is the reason. `test2` was not run: the change
  touches no path in `TWO_PLAYER_PATHS`, and a two-player run cannot pass while the one-player run
  fails.
- **The names of what the rebuild destroyed.** The Director's dispatch says DEV held
  Scene / Scene2 / VerdantTest experiments inside `Workspace.DrivenHuntMap`. What I measured myself is
  that the folder held 7,460 descendants with 0 tagged markers before, and the generated bare world
  after. I did not list its children before destroying them, and `--backup census` only inspects
  Workspace's top level.
