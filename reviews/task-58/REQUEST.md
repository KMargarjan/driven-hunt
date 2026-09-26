# Task 58 — M2.8a: the forest road, the corridor and the autumn palette

Task: 58
Round: 2
Base: `c46c699` (`main`, with Task 54's revised design merged)
Code commit: `9046338e588ff85884f527ae64d3f116b55111f8` — **both** harness lines below name it. It
is a PAPERWORK commit: the last commit that changed `src/`, `tests/` or `tools/` is `42c14dd`, and
`git diff --name-only 42c14dd..9046338` is `TASKS.md` and this file.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ 9046338e588ff85884f527ae64d3f116b55111f8 (clean tree)

Harness, clean tree, two players — run by the DIRECTOR, not by me:

    [harness2] PASS: 32/32 checks @ 9046338e588ff85884f527ae64d3f116b55111f8 (clean tree)

335 server specs (330 in round 1: **5 new**), 84 shooter and 78 driver client specs. **The map is CLEARED from the place**:
`removed: 1492`, `cellsAfter: 0`, `paletteRestored: true`.

## Scope

Design §18's **M2.8a row only** — the road, the corridor, the palette. No new props: the wood's
species and density inside the drive are M2.8b, which is why the drive is still bare in the shots.

## What round 1 found, and what each fix is at its class

1. **A collidable hedge wall stood across the forest road** at x = ±760, both ends. The class is that
   *"is it in the corridor"* was never the right question for a bench: the road runs to x = ±900 and
   the corridor stops at ±620. `Layout.onBench(x, z, config, pad?)` is the one predicate now, and
   everything that **places** something asks it — `hedgeSegments` skips a segment (with half a
   segment's clearance, so the part and not just its centre stays off), and `Props.rejectTree` rejects
   a point, which closes the Reviewer's tree note in the same move. Measured: each z-line dropped from
   **86 parts to 79** — 7 segments, the road and the assembly bench.
2. **`Map.ROAD` / `Map.ASSEMBLY` were read by nothing** while `Config` re-declared the same five
   numbers. `Config.WORLD.benches` derives every one from the contract now — the rule
   `Config.SPAWN_PAD = Map.SPAWN_PAD` two lines above already states — and a spec asserts the
   derivation field by field, so a third copy cannot come back quietly.
3. **The palette was entirely untested.** Every digest spec passed three arguments, so the fourth
   never ran.
4. **Nothing asserted a post stands on the road at ground**, and a comment claimed the contract
   checked it.
5. **The whole-map relief assertion was false of the map** and true only of its lattice.

## Claims

1. **Nothing collidable stands on the road, along its whole length.** `MapGen.verifyContract` walks
   every `BasePart` under the map and fails on any `CanCollide` part within `halfWidth + verge` of the
   centreline between `from` and `to`; `python tools/mapgen.py verify` runs that check beside
   reachability. Reachability alone never saw the wall — the navmesh simply went round it, 25/25
   Success — which is why this check looks at the road itself. Verify: `verifyContract`'s blocker
   walk; `command_verify` in `tools/mapgen.py`.

2. **One bench predicate, used by every placer.** `Layout.onBench` takes the gravel, the verge, the
   taper and an optional clearance. Verify: `hedgeSegments`, `Props.rejectTree`; live build above.

3. **The benches come from the contract.** Verify: `Config.WORLD.benches`; spec *"derives every bench
   from the contract, never from a second copy"* (asserts `at/halfWidth/verge/from/to` against
   `Map.ROAD` and `Map.ASSEMBLY`).

4. **The palette moves the digest.** New spec: autumn ≠ default; the same palette twice is equal;
   **one 8-bit channel of one role** moves it; **no palette is a third, distinct answer**; and the
   canonical text is pinned exactly (`bog=…|litter=…|road=…|rough=…`). Verify: *"changes the digest
   when a palette colour changes"*.

5. **The live palette is asserted off the engine**, not off the table that wrote it:
   `Ground.readPalette` against `Map.PALETTE_DEFAULT` in the arena branch, per-channel, with an error
   that names the fix. This is what catches an autumn palette left behind after a teardown — the
   voxels are gone and the place is still orange. Verify: *"leaves the terrain palette at the
   contract's colours for the world it names"*.

6. **One generator version.** `expect(MapGen.VERSION).to.equal(Map.GENERATOR)` — design §16.1 check
   10, which claim 7 of round 1 said was closed and nothing held closed.

7. **Every post's bottom face and z, and the DriverStart's four corners.** `verifyContract` checks
   each post's `Position.Y - Size.Y/2` against `groundY` and `|z − Map.ROAD.z| <= halfWidth`, and the
   driver strip's four **corners** rather than its centre — it is 1,120 studs wide. Measured live: 8
   posts at y = 0.5, size 6×1×6, all at z = −700. Design §16.1 checks 4b/4c. The comment that claimed
   the contract already did this is gone.

8. **The relief bound is a bound on the map.** The spec samples to **±1024** — the real edge — and
   asserts three things instead of one: inland (outside `EDGE_BAND`) the noise alone stays inside
   `RELIEF`, the whole map stays inside `max(RELIEF, EDGE_MAX_Y)`, and `worst > RELIEF`, so the rim
   really is raised and the bound is not vacuous. A new spec walks `edgeFloor` over the whole map and
   asserts it never exceeds `EDGE_MAX_Y` **or** `BAND_Y.max` — the voxel band the tile size was
   measured against — and that it does rise. Verify: both `it` blocks.

9. **Two duplicates from the notes, fixed rather than queued.** `Ground.paletteMaterials(config)`
   derives the role → material map from `Config.MATERIAL` (it was a second copy with a different key
   for one material — the same class as the inversion the round-1 screenshots caught), and the palette
   section no longer sits between `Ground.cells`'s doc block and `Ground.cells`.

10. **The build is real.** 267 steps, **1,072 parts** (1,086 in round 1: the 14 hedge segments),
    4,096 terrain samples, 3,381,196 cells, digest `33b86a79…467deae5` at seed 1, `contract OK`,
    `reachability OK` (25/25), then cleared and verified empty. Built at `283704f`; the two commits
    after it changed **only** `tests/server/map_contract.spec.luau`
    (`git diff --stat 283704f..HEAD -- src tools` is empty), so the shots and the build are evidence
    for this code commit's generator.

## What the shots actually show (rule 5 — I looked at them myself)

- **`map-edge`** — the road runs out to the rim **clear**: no wall, no ramp, the rim closing the
  horizon behind it. This is finding 1 and measurement N4, visible.
- **`map-road`** and **`map-crossing`** — a pale gravel strip dead straight to the horizon, unbroken
  end to end.
- **`map-autumn`** — the floor is orange-brown leaf litter, not grass. The crowns are still green
  cubes: **it does not read as an autumn wood**, and cannot until M2.8b.
- **`map-wide`** — wood-floor interior, olive flanks, both benches as pale lines.
- **`map-post`** — a shooter sees **open ground to the horizon**, no cover at all. M2.8a places no
  props; this is what M2.8b is for, and I am not claiming otherwise.

## What I could not verify

- **The harness itself found two defects in my own new specs** (a fixture with `path`/`class` and one
  with `y`, where `Digest` reads `name`/`className` and `occupancy`): they threw inside
  `string.format` instead of asserting. Both are fixed, and the fixture shape is now one helper at
  file scope so a third copy cannot drift. Worth knowing that round 2's specs failed twice before they
  bit.
- **The posts are invisible in every shot** (`Transparency = 1` by design §4.3), so `map-road` cannot
  answer its own question; claim 7 is measured through the contract check instead. Row 58a.
- **Two players says nothing about the map**: it is not the world yet (`EXPECTED_WORLD = "arena"`).
- **Measurement B** (tags and terrain surviving a save and reopen) still needs clicks no tool makes.
- The remaining round-1 notes — the `SHOTS` table's deviation from §16.3, `Reach.to`, the stale
  `tracks` entry, the seed-dependent `atRim` sample, the assembly bench's rim notch, `map_client.spec`
  not existing, and the hedge 5→3 line being M2.8b's row — are **queued in `TASKS.md` as 58a**, not
  fixed here.
