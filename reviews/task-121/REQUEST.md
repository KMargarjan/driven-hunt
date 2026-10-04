# Task 121 — the forest, block 1 (map-generator v4)

Task: 121
Round: 1
Base: `main` @ `ae5f4fc`
Code commit: `2ad7135`

## THE HARNESS GATE IS NOT GREEN, AND I COULD NOT MAKE IT SO. READ THIS FIRST.

I have no `[harness] PASS` line to paste, so by CLAUDE.md's own rule this task **cannot be reviewed
yet**. What I have instead, honestly:

```
[harness] FAIL: 31/33 checks @ 73a5826 (clean tree) scope=all      <- the last run that COMPLETED
         server 709 passed, 2 failed, 2 errors · client 113 passed, 0 failed
         both failures: tests/server/boar_body.spec.luau:627 and :663, NOT the map
```

**The map's own spec is green.** Across two completed runs the only server failures were those two
`boar_body` cases, and the client suite passed 113/113 both times. The eleven map cases, the band,
the slope, the blocks, the markers, the patches, the walkability, the species mix, the triangle bound
and the digest all pass.

**Those two `boar_body` cases are this task's doing, and they are diagnosed.** That block flies a
sounder 1,500 studs up, but `Boar.defaultWorld` pathfinds with the real `PathfindingService` against
the real `Workspace`, so the route is answered against the navmesh built from the ground BELOW it.
Its centre was `(0, _, 160)` — open ground on the old bare plate, and the CENTRE FOREST RIDE with
wood either side since this task. Measured identically in two consecutive runs: *"the leader asked 13
times in 3 s (0 failed, 4 blocked), over the budget of 12"*, and the scatter case's spread stopped
growing. The fixture is translated by (+700, +340) so it stands over block 2, which is layout only
and carries no trees; the budget stays 12 and every assertion stays.

**That fix is UNVERIFIED, because the harness stopped completing runs.** Every attempt since sits at
`[harness] Play` for twenty minutes and never gets the client's ready token. `studio_mcp.py studios`
lists only ONE datamodel while Studio reports `Play`, so the Play session's datamodels are not
registering with the MCP server. `stop` recovers Studio to Edit and the next run hangs the same way.
That is a harness/Studio fault, not a code one (rule 6), and clearing it needs a Studio restart plus
a Connect click, which is not mine to make.

**So: `NEEDS DIRECTOR` — one `python tools/studio_mcp.py test` at `2ad7135` after a Studio restart.**
If it is green, this is reviewable as it stands. If those two `boar_body` cases still fail, they are
the one open defect and I have said exactly where they come from.

`test2`: **ALSO REQUIRED.** `src/server/Match/init.luau` is in `TWO_PLAYER_PATHS`, so
`tools/agents.py` will refuse this review without a `[harness2]` line. **The change to that file is
ONE COMMENT LINE** — it cited `Map.ROAD`, a contract field this task renames to `Map.ROADS` — and no
code. Nothing else here is on the list. I am not going to revert a comment to a field that no longer
exists in order to dodge a gate; the Director either runs `test2` or records that a comment-only
change does not need one.

Verified independently of the harness, on the same commit:

```
[mapgen] OK: 627/627 steps @ c14b411 seed=1 digest=363ae652...a4d387cb (clean tree)
[mapgen] contract OK          (8 posts, 1 line, 1 start, 4 spawns, 12 tie trees, 8,181 parts)
[mapgen] reachability OK      (25/25 routes Success, with the boar's own agent)
[mapgen] 11 named capture(s)  (all eleven inspected; see claim 9)
```

(`c14b411` is the build; `73a5826` and `2ad7135` change only `CORRIDOR_MAX_SLOPE_DEG`, a spec
threshold, and a test fixture — neither touches the heightfield, so the built world is unchanged.)

## What changed

One forest of **3,072 studs**, four drive blocks divided by four forest roads, **block 1's content
built** and blocks 2–4 layout only. `MapGen.Assets` is archived, so there is one id table in the repo.
`Map.FIELD` and `Boar.CONFIG.field` move to block 1 together. Built to `docs/design/map-generator.md`
v4; the research note is `docs/research/2026-10-04-forest-block1.md`.

## Claims, and how to verify each

1. **One block is tagged, and it is the one `Map.ACTIVE_BLOCK` names.** `Markers.read` requires
   exactly one drive line, so four blocks' markers would be one broken drive. Verify:
   `map_contract.spec`, "tags the active block and no other" — and note what it does NOT assert and
   why (the stands sit 20 studs behind the road and the tie trees sit in the crossing band, which is
   the next block's ground BY DESIGN; the assertion is "no marker across the ride").

2. **A shooter stands on a floor, not at a height.** `Map.STAND.floorStuds` is one number that is
   true in both worlds. Two cases: the post's bottom face is at `ground + floorStuds`, AND a
   **collidable part exists directly under it** — the check the 9.5-stud drop (row 43a(l)) never had.
   `Match.Body` and `Match.CONFIG` are untouched; only the marker's Y moved. Verify:
   `map_contract.spec`, the two "shooter post" cases, and `Layout.markers`' `y` field.

3. **A tree is a mesh plus an invisible trunk collider**, so a tie holds a 2-stud bole and not a
   34-stud crown, the navmesh sees boles, and a shot passes through leaves (deliberate; Karen's to
   overturn). Verify: `Props.placeTree`, and `map_contract.spec`'s "gives every tree a trunk collider
   the tie can hold" (widest trunk anywhere < 4 studs).

4. **`keepClear` is not `verge`.** Nothing collidable stands inside `halfWidth + keepClear` of ANY
   road, over its whole length — ONE predicate (`Layout.onRoadKeepClear`) that `treeDensity`,
   `Props`, `verifyContract` and the spec all call, so none can disagree. Verify: the spec's
   "leaves nothing collidable inside any road's cleared corridor", and `[mapgen] contract OK`.

5. **The wood is walkable, and that was MEASURED rather than argued.** The spec reported a worst
   trunk-surface gap of **−0.28 studs** — two trees inside each other — against a design guarantee of
   12.2. Three causes, all fixed: the rim's grid overlapped the blocks, each sub-block's lattice was
   anchored to its own corner (512 studs is 17.07 cells of 30), and a patch's edge had no margin. Now
   **+8.02 studs** against the boar's 4, and `reach` is 25/25. Verify: `map_contract.spec`'s two
   walkability cases (3 seeds over the wood, 20 seeds per patch) and `Scatter.weighted`'s `cellRange`.

6. **The rim is scenery and keeps out of the drive.** The slope spec measured **47.30°** at
   (−1440, 1214) against a 15° ceiling: `EDGE_BAND` is 400 studs and block 1 reaches to x = −1440, so
   102 studs of backdrop ridge was rising through the corner of the drive. `Height.blockRimSuppression`
   is the fix, the same smoothstep a road's lateral band already had. The analytic tile test stays an
   UPPER bound because a suppression can only lower the rim. Verify: the slope case, and the band case.

7. **`BAND_Y.min` is −48, not the design's −24, and that is a measurement.** The normalised fbm lands
   in [−0.546, +0.571], not [−1, +1], so `RELIEF = 64` achieves ±37 studs — the design's number is the
   amplitude parameter. At −24 every hollow would have been written as a **void**. Verify: the band
   case asserts, over three seeds, that no column leaves the band its tile was written in, and that a
   tile with no upper pass never reaches `BAND_Y.mid`.

8. **`tools/mapgen.py` sends a bundle, because the MCP thread cannot `require` anything.** Measured
   again here; `tools/studio_mcp.py` has carried it since 2026-10-02 and names this tool as the one
   still affected — it could not run at all. The bundle also makes `InsertService:LoadAsset` harmless,
   and it has to be, because route A calls it. Verify: `bundle_source` refuses a require shape it does
   not know rather than letting it reach Studio, and the `[mapgen]` lines above are what it produced.

9. **Eleven screenshots, all inspected, and three of them say the wood is wrong.** `block1-stand`,
   `block1-road` and `block1-hills` have no ground and no distance in them. The arithmetic is in the
   research note: a mature oak's foliage starts at 13.4 studs (above a shooter's 11.1-stud eye) but
   34-stud crowns on a 30-stud grid close the canopy, and `block1-gap` and `block1-deadwood` prove the
   point by showing distance where there is no crown overhead. **This is reported, not fixed:** the
   levers are Karen's taste values (design §19 Karen 2). Verify: `.screenshots/`, and `TASKS.md` 121a.

10. **One id table.** `MapGen.Assets` is archived with a note; `MapGen.Props` goes through
    `Assets.Loader` with a borrowed state and a cache under the map root, so nothing is parked in a
    Rojo-owned container. Closes row 74a(a). Verify: `assets_seam.spec`'s amended case, and
    `map_contract.spec`'s "leaves no asset cache behind".

## What I could not verify

- **M3 (CC0 terrain variants) is untaken.** No `ground.*` row exists, so `Ground.applyVariants` has
  nothing to apply and the step reports "no asset row" per role; the forest ships on the measured
  palette, which is what the design says it should do. Whether a terrain-bound `MaterialVariant` can
  be created from `execute_luau` at all is still unmeasured. `TASKS.md` 121a(c).
- **The wet-ground feature barely fires at seed 1.** The wettest point found on a 40-stud lattice in
  block 1 was wetness **0.22**, under the 0.5 threshold, and only 7 trees in the whole wood sit in wet
  ground. The rule is correct and asserted (every one of those 7 is alder); it is close to invisible.
- **Two-player behaviour.** Not run; see the N/A above. The Director decides if the contract data the
  match reads changes that judgement.
- **Karen's judgement of any of it.** She delegated to the Director for this block.
