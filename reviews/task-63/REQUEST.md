# Task 63 — M2.8b: the wood

Task: 63
Round: 1
Base: `4a0a7d5` (`main`, with Task 61 merged)
Code commit: `be43f61a406668a648f410a901f98fb9e67ea7c0` — the `[harness]` line below names it, and it
is the last commit that changed `src/`, `tests/` or `tools/`.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ be43f61a406668a648f410a901f98fb9e67ea7c0 (clean tree)

Harness, clean tree, two players — run by the DIRECTOR, not by me:

    [harness2] PASS: n/n checks @ be43f61a406668a648f410a901f98fb9e67ea7c0 (clean tree)

377 server specs (374 before) and 84 client specs. **The map is CLEARED from the place**:
`removed: 9031`, `cellsAfter: 0`, `paletteRestored: true`.

## Scope

Design §7 (the wood) and the M2.8b row of §18: species, density, brush, the hedge network already cut
to three lines in M2.8a, and `rejectTree` rewritten. No new props beyond trees and brush; no asset
ids; the palette and the road are M2.8a's and are untouched.

## The measurements (design §16.6)

**N3 — the build.** 273 steps, **2,402 ms of step time**: terrain 1,975 ms over 256 tiles, **the wood
298 ms over 4 quadrant steps**, brush 30 ms over 4, everything else 99 ms. The command itself takes
minutes because every step is one JSON-RPC round trip — the *generator* is not the slow part.
**6,264 parts** (design's estimate ≈6,650, `Map.BUDGET.parts = 20000`): **2,746 trees** (estimate
~2,925, ceiling 3,000), **500 brush**, 234 hedge, 24 tie-tree parts, 14 markers. 3,381,368 terrain
cells.

**N2 — pathfinding with the real trunk count. It passes, and this is the measurement the Director's
decision F was about.** With 2,746 trunks standing, `MapGen.reachability` is **25/25
`PathStatus.Success`** across five froms × five targets, 337–424 waypoints; the whole `reach`
command is **12.5 s wall clock**, of which 6 s is the navmesh settle — so about **0.26 s per
`ComputeAsync`**. No density fallback is needed, and there is no TASKS row proposing one.

**The walkability property, measured over five seeds** (design §7.3): the closest two trunks anywhere
are **11.30 studs** apart against the sampler's guaranteed 11.0, so the worst clear gap past the
widest trunk (oak, 5) is **6.3 studs** against the boar's `AgentRadius = 2`, which needs 4.

## Claims

1. **The drive is the wood now.** `Props.rejectTree`'s corridor rejection is gone — it was what made
   the one place the player looks the one place with no trees. `map_contract.spec` asserts **2,095 of
   2,737** placed trees stand inside the corridor. Verify: *"fills the drive with wood and still
   leaves the ground the game uses clear"*.

2. **What stays clear is the ground the game stands things on**, and there is exactly one source for
   it: `Layout.treeDensity` returns 0 on a bench and its verge, a track, the bog, a field, a hedge's
   clearance and a spawn pad, and `Props.rejectTree` **is** that function, so the placing step and
   the spec cannot disagree.

3. **Three density tiers, and they are visible in the numbers, not just in the config.** Measured:
   **17.71 trees per 10,000 studs² in the dense band** against **0.88 in the backdrop** — twenty
   times thicker where the shooter's eye is. Verify: *"is denser where the shooter looks than in the
   backdrop"*.

4. **Walkability is arithmetic, not luck.** `SCATTER_JITTER` 0.9 → **0.5**, which is what guarantees
   `22 × 0.5 = 11` studs between neighbouring candidates; the spec measures the real minimum over
   five seeds (11.30) and asserts the clear gap beats the boar's agent. This is the one change that
   makes deleting the corridor sweep safe, and it is a number changed by an argument.

5. **Karen's four species, in her proportions.** Measured by the spec over the whole wood: spruce
   **39.6 %**, birch **28.2 %**, oak **20.5 %**, alder **11.7 %** against 40/25/20/15. In the built
   map alder runs higher (21.6 %) because **wet ground forces alder** — the bog and the hollows — and
   that is the design's rule working, not drift.

6. **A defect the first build found, and it was mine:** the species came from a `math.noise` value
   indexed into a cumulative share table, and a noise field is bell-shaped about its middle, so the
   middle band won — **230 birch to 195 spruce to 3 oak** in one quadrant. The clump's species is a
   flat **hash** of the clump's block now, with the noise only wobbling the block's edges; 65 % of a
   clump is its leader and the rest is drawn from the same shares, so the marginal share of every
   species is the number in the table.

7. **A second defect the first build found:** every prop step rebuilt its folder, which is right for
   a one-step prop and wrong for one built in four — the log said 1,869 trees and the world held 964.
   The first quadrant clears and the other three append.

8. **The canopy does not block the ground game.** Trunk `CanCollide`/`CanQuery` true; crown
   `CanCollide` **false**, `CanQuery` true — so the navmesh and the boar see trunks only, while a
   shot into the canopy still stops in the canopy. Brush is **neither**: cover for the eye, because a
   bush that eats a slug is an invisible wall.

9. **The proxies teach the truth about the mesh that replaces them.** 57–71 studs tall, per
   `asset-pipeline.md` §12.1, not the 22-stud lollipop; autumn crowns; and **no colour channel
   maximum below 120**, which is the Task 22 albedo measurement applied rather than re-learned.

10. **The budget is a ceiling that fails the build.** The tree step refuses over `Map.BUDGET.trees`
    and the brush step over `Map.BUDGET.brush`, naming the quadrant — because a build that quietly
    overruns the part budget is how a place gets slow with no diff to blame. Also: the two stale v2
    tracks are gone (one ran across the drive, one inside the widened corridor — row 58a(d)); one
    flank track at x = 880 remains.

## What the shots show (rule 5 — I looked at them)

- **`map-crossing`** — the shot this task exists for: the road runs as an open ride between two walls
  of wood, autumn crowns overhanging from both sides, sky above it. It is Karen's reference frame.
- **`map-post`** — a shooter's view into the drive: white birch trunks and dark spruce, a closed
  canopy overhead, sight lines of roughly 60–100 studs. A boar could hide in that; a boar crossing
  the road would be seen.
- **`map-wide`** — from above the wood reads in **clumps of colour**: orange-brown oak, yellow birch,
  teal-green spruce, thinning to the edges, with the olive field strips on the flanks.
- **`map-autumn`** — honestly: under a closed canopy the floor and the non-birch trunks go
  **near-black**, and the spruce crowns read minty-teal rather than dark forest green. The albedo
  floor stopped the flat colours being black; shadow under a full canopy is a different thing and it
  is not fixed here. Queued as 63a.

## What I could not verify

- **Whether it is dense enough to hide a boar and open enough to shoot along** is Karen's judgement
  at a playtest; the shots are the evidence I can produce, and the sight lines are ~60–100 studs.
- **Nothing was played.** No boar has walked this wood: `reach` pathfinds with the boar's own agent,
  which is a different claim from "a boar pushed by a driver gets through".
- **The species share is measured off the pure scatter**, where the ground comes from `Height.at`;
  the built map uses `atFlattened`, which is why its alder count is higher. Both are recorded.
- **`map-post`'s sight line is my reading of one frame**, not a measured distance.
- **The 2,746 trees are proxies.** Every claim about how the wood will look with meshes is a claim
  about a box of the same size and colour.
