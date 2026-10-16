# Putting a bought forest's trees back on the ground (task 199)

**2026-10-17. Karen, 2026-10-16 ~21:35, with a frame of three birches standing on their root claws
in mid-air beside a forest road: _"look at the trees wtf"_.**

## 1. What the system must do

`Workspace.OurForest` in Karen's Forest Test place (130094961655666) holds **4,819 scattered
models** — 2,216 trees of fifty-one kinds and 2,603 ferns — bought as a Creator Store pack and
scattered by hand. It is **Studio map content**: nothing under `src/` creates, moves or parents
anything into it, no Rojo path owns it, and it is saved with the place. So the thing that has to
change cannot be changed by a commit.

What it must do:

1. Measure, for every model, how far its geometry is from the terrain under it — by a measurement a
   person can check, not by the thing that sets it.
2. Move the floating ones **straight down**, and nothing else: no sideways move, no rotation, no
   scale, no deletion.
3. Be **re-runnable** by the Director on either place, with a **dry run** first, a **backup**, and a
   **restore** that was proved to work before anything moved.
4. Use the **same rule** the lobby already uses, not a second one.

Numeric targets: **0 trees whose trunk/root junction is more than 0.2 studs above the terrain under
its own footprint**, exceptions listed with positions; nothing raised; nothing moved sideways.

## 2. The thing that is actually wrong, and why the obvious fix is the wrong one

Task 196 part 3d sank each lobby tree until its **lowest point** reached the ground. That is exactly
right for a truck and exactly wrong for a birch: the root flare of `SilverBirch_Var11_LOD_0` is a
set of **arched claws**, so putting the claw TIPS on the ground leaves daylight under every arch —
and to the eye that is a floating tree. Karen photographed that twice.

Part 3e's answer, which this note adopts unchanged: **the contact is the trunk/root junction**, the
height at which the base stops being claws and becomes trunk, and the claws go **under** the ground.

## 3. Sources

| | |
|---|---|
| **The lobby's own code and note** — `src/server/Lobby/Build.luau` (`treePlan`, `seatOnGround`, `settleOnGround`), `src/shared/Lobby/init.luau` (`TREELINE.SPECIES`, `SINK_STUDS`), and `docs/research/2026-10-15-one-placement-rule.md`. Ours; maintained; the current, reviewed answer to this exact defect (task 196, PASS round 3) | **Does well:** the junction rule, the claw fraction as a property of the MESH kept as data, the base footprint rather than the crown, the grid-plus-corners sampling, and the discipline that the lift is *measured off the parts afterwards*, never computed. **Does badly:** it is welded to Instances and raycasts, so none of it could be asserted without building a forest; and it knows exactly two templates by hand |
| **Roblox `WorldRoot:Raycast` / `RaycastParams`** — <https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Raycast>, <https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams>. First-party, current | **Does well:** `FilterType.Include` with `{workspace.Terrain}` gives a terrain-only reader that cannot stop on a canopy, a road part or a fern, and `IgnoreWater` is a flag rather than a special case. **Does badly:** a ray that **starts inside** a part never reports that part, so "fire outward from the trunk axis" silently measures nothing — which is why the claw measurement fires **upward from below** instead |
| **Roblox `Model:GetBoundingBox` / `Model:GetPivot` / `Model:PivotTo`** — <https://create.roblox.com/docs/reference/engine/classes/Model>. First-party, current | **Does well:** `PivotTo` of the current pivot plus a Y delta is a rigid translation of the whole model, which is exactly "straight down and nothing else", and it needs no `PrimaryPart`. **Does badly:** `GetBoundingBox` returns an **oriented** box, so treating its position and size as axis-aligned is wrong for anything turned — and every tree here is turned. And a free model's **pivot is not its trunk**: it is the box centre, which on a leaning tree is studs away from the foot. That one cost a round of this task (§6) |
| **`tools/mapgen.py`** — ours, maintained; the repo's existing "a tool that rewrites Workspace in an Edit session" | **Does well:** the refusal shape adopted here wholesale — Edit mode, the right `PlaceId`, a clean tree for anything that mutates, and **no usable backup means no run**; exit codes 0/1/2; a pasteable report line. **Does badly:** it is bound to the DEV place and to `ServerStorage.MapGen`, so it could not be extended to a second place's hand-made content without becoming two tools in one file |
| **Negative result — Roblox has no "drop to floor" for this.** Studio's own *Model → Drop to Floor* / `Ctrl+Shift+Down` is a **plugin-level editing action** with no scriptable API (`PluginSecurity`), and `AlignPosition`/`Anchored = false` physics settling cannot be used: these models are anchored scenery, and letting 2,216 of them fall would also let them topple and drift sideways | This is why the rule is computed rather than simulated |

## 4. Borrowing before building (rule 2)

Nothing new is invented here. The rule is the lobby's; the tool's refusals are `mapgen.py`'s; the
MCP client, the `luau_json` embedding and the `json_answer` parser are `studio_mcp.py`'s, imported
and not copied.

**The one thing written fresh is the split**, and it is a split rather than an invention:
`src/shared/TreeGround/init.luau` takes the arithmetic out of `Lobby.Build` and leaves the
raycasting behind. The Director asked for one rule, ideally one function both use (lesson L-031);
the forest's half has to run in a place Rojo does not serve, so `tools/forest_ground.py` **reads
that module's own source and injects it** into the Luau it sends. `Lobby.Build` requires the same
file in game. There is one copy of the arithmetic in the repository.

## 5. The claw fraction: measured, and only used when it is stable

The junction is a property of the mesh, kept as a fraction of the model's height so it survives a
per-tree random scale. The lobby hand-measured two. Fifty-one is too many to hand-measure, so
`forest_ground.py species` measures them: upward rays on a 7 × 7 grid over the ground-reaching
parts, and the junction is the **highest "first thing you hit"** below a quarter of the model's
height. Under an arch of claws that is the apex; under a flat-cut base it is the base itself.

**A number is only used when the model's own instances agree.** Accepted if the spread across every
instance of that model is within 0.01 of height **and** the fraction is under 0.10; otherwise it is
recorded with its reason and treated as **zero**, which seats the model's lowest geometry on the
ground and is still strictly better than today.

| | |
|---|---|
| models measured | 61 |
| **accepted, carrying a claw fraction** | **5** |
| rejected `unstable` | 26 |
| rejected `over-bound` | 1 |
| `low-plant` (under 10 studs; no claws to find) | 29 |

The rejections are honest, not a shrug. The spruces and larches have **skirt branches that sweep to
the ground**, so their "first thing you hit" is a branch underside fourteen studs up: sinking them
by that would bury the tree, and a measurement that cannot be trusted is not used.

**The cross-check that matters:** all 26 instances of `SilverBirch_Var11_LOD_0` measure
**0.0424–0.0462**, and that is the very model the lobby hand-measured at **0.075** by a completely
different method (horizontal rays, "the height at which the radius falls back to the trunk's own").
Two independent methods on one mesh, agreeing in kind — and this one is the more conservative, since
the split point is below the height at which the flare has thinned back to trunk width.

## 6. What was measured and turned out to be wrong

Three of this task's own mistakes, kept because each is now a guard or an assertion:

1. **The footprint read the canopy.** The first measurement took the footprint from every part
   whose bottom was within 0.15 of the model's height — which on an aspen includes the **leaves**,
   26 studs across. The ground 13 studs from the trunk is a different hill. Fixed by taking the
   **trunk's** box (the part whose name contains "Trunk", lowest one if several).
2. **…and then the trunk mesh was the whole lower tree.** `LarchTree_Var02`'s "Trunk" part is
   **15.6 studs across** on a 30.6-stud tree, so sampling to its corners still read the ground seven
   studs away and down a bank. It made the ground under nineteen larches look like a **cliff edge**
   and the tool declined to move every one of them — while they floated **30 studs in the air**.
   Fixed by `TreeGround.flareFootprint`, which clamps the footprint to a root flare's own width
   (`max(0.08 × height, 2.0)` each side of its centre). The clamp is **inert for the lobby's two
   templates** — a 3.7-stud birch trunk on a 74-stud tree is nowhere near the 5.9-stud clamp — which
   is asserted rather than claimed, so task 196's thirty-eight trees are untouched. Cliff
   exclusions fell from **426 to 65**.
3. **The camera was aimed at the model's pivot, and photographed the wrong tree.** The first
   close-up taken as evidence showed a perfectly seated birch that was not the tree the row was
   about. The tool now reports the **trunk footprint's own x and z**, and that is what the frame
   list in the review request carries.

## 7. The pattern adopted

* **One pure rule module**, `src/shared/TreeGround/init.luau`: bounds, ground band, ground-reaching
  parts, flare footprint, sample grid, junction height, sink, lift, spread, and one `decide`. No
  Instance, no service, no raycast — so `tests/server/tree_ground.spec.luau` asserts which trees
  move and by how much with no world at all.
* **`Lobby.Build` requires it**; `tools/forest_ground.py` injects its source. One copy.
* **The tool measures, the module decides, and only `apply` moves anything.** `plan` is a dry run
  printing the counts and the worst ten; `backup` writes every model's CFrame outside the repo;
  `restore` puts them back and checks each model's name and X/Z before it does.
* **It only ever sinks.** A tree already deep in the ground is reported `seated` and left alone:
  raising it is a different question and nobody has asked it.

## 8. The numeric targets

| | |
|---|---|
| junction more than **0.2** studs above the terrain under its own footprint | **0**, exceptions listed with positions |
| sink below the surface | **0.6** studs (the lobby's `SINK_STUDS`), capped at a tenth of the height so a 2.8-stud fern is not buried by a fifth of itself |
| root flare clamp | `max(0.08 × height, 2.0)` studs each side of the footprint centre |
| ground under one footprint that counts as a cliff edge | **4.0** studs of spread — measured: the live forest's spread is 0.23 at the median and 2.10 at the ninetieth percentile |
| claw fraction accepted when instances agree within | **0.01** of height, and the fraction is under **0.10** |
| moved sideways, rotated, scaled or deleted | **0**, by construction: the only write is `PivotTo(pivot + Vector3.new(0, lift, 0))` |
