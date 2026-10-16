# Task 199 -- the forest's trees stand on the ground

Task: 199
Round: 1
Base: `78f97a2` (main)
Code commit: `PENDING`

Harness (clean tree, one player):

```
PENDING
```

Two players: **N/A.** Nothing this task touches is in `TWO_PLAYER_PATHS` (`tools/agents.py`):
the changed paths are `src/shared/TreeGround/`, `src/server/Lobby/Build.luau`,
`tests/server/tree_ground.spec.luau` and three files in `tools/`. Weapon / viewmodel / camera /
boar / hud / sound / tools / lobby need the one-player line only, for the PR to `main` as well
(Director decision, 2026-10-03).

---

## What changed, and why it is two different kinds of thing

**Karen, 2026-10-16 ~21:35, with a frame of three birches standing on their root claws in mid-air
beside a forest road: _"look at the trees wtf"_.**

`Workspace.OurForest` in her Forest Test place (130094961655666) holds **4,819 scattered models**.
It is **Studio map content**: nothing under `src/` creates, moves or parents anything into it, no
Rojo path owns it, and it is saved with the place. **No commit can move those trees.** So this task
is a rule plus an instrument, and the trees themselves were moved by running the instrument.

1. **`src/shared/TreeGround/init.luau` (new).** The arithmetic of where a tree meets the ground,
   split out of task 196 part 3e's lobby planting. Pure: no Instance, no service, no raycast.
2. **`src/server/Lobby/Build.luau`** now requires it. `Build.footprintSamples`, `treePlan`'s
   junction and `settleOnGround`'s `toLowest` lift are that module's; nothing here restates them.
3. **`TreeGround.flareFootprint` (new rule)** clamps a footprint to a root flare's width. Used by
   the tool only; the lobby does not call it, and claim 3 says why that is a measurement.
4. **`tools/forest_ground.py` (new)** -- `species` / `backup` / `plan` / `apply` / `check` /
   `restore`, against a place named by id and verified by `game.PlaceId`.
5. **`tools/forest_claws.json` (new)** -- the claw fraction of each of the 61 models, measured.
6. **`tools/studio_mcp.py`** -- two lines: the new spec and `src/shared/TreeGround/` join the
   `lobby` scope.
7. **The Forest Test place itself** was re-seated by running `apply`. That is not in this diff and
   cannot be; the evidence is below.

---

## Claims

**1. The lobby and the forest are planted by ONE function, and the tool cannot drift from the
game.** `src/server/Lobby/Build.luau` requires `ReplicatedStorage.TreeGround` and calls
`TreeGround.samples`, `TreeGround.junctionY` and `TreeGround.liftTo`; no copy of those three
remains in `Build.luau`. (`TreeGround.flareFootprint` is the forest's alone -- claim 3.) `tools/forest_ground.py`'s `module_source()` **reads
`src/shared/TreeGround/init.luau` off disk** and injects it into every payload it sends, because
Karen's Forest Test place is not the place `default.project.json` serves.
*Verify:* `grep -n "TreeGround\." src/server/Lobby/Build.luau`; `module_source` and `PRELUDE` in
`tools/forest_ground.py`; the docstring's "THE RULE IS NOT WRITTEN HERE".

**2. The rule is testable with no world, and the spec asserts which trees move and by how much.**
`tests/server/tree_ground.spec.luau` builds plain tables. It includes the case lesson **L-028** asks
for: the same `decide` fires on the PRE-fix numbers of a real tree (#739, foot 2.62 above the
ground) and declines on its POST-fix numbers -- so the check is not one that reads "nothing is
floating" on both states.
*Verify:* `tests/server/tree_ground.spec.luau`, the `describe("decide")` block, last case.

**3. The lobby's 38 trees are NOT changed by this -- and that took a correction, which round 1 of
the harness forced.** `treePlan` now calls `TreeGround.junctionY` and `TreeGround.samples` instead
of its own copies; both are the same arithmetic, so the planting is byte-for-byte what task 196
signed off. **I also applied the flare clamp there and claimed it was inert** (the templates' trunk
parts are 3.7 and 2.0 studs across against a 5.9-stud clamp) -- and `lobby.spec`'s own "buries each
tree's root claws" case FAILED on commit `543422c`: that case reads the ground across the **whole
model box** on a test slope, so narrowing the sampled strip raises the lowest reading and every
lobby tree sinks less than the 0.6 studs it holds them to. The clamp is now the forest's alone.
*Verify:* commit `854bfc7`; the comment at the end of `treePlan` in `src/server/Lobby/Build.luau`;
`TreeGround.flareFootprint`'s own header; the harness above runs `lobby.spec` and `lobby_live.spec`.

**4. Nothing was moved before there was a backup, and the restore was PROVED on three trees.**
`backup` wrote all 4,819 pivots to `<runs-dir>/t199/ourforest-before.json` (1.07 MB) and refuses a
path inside the repository. Three models (an aspen, a larch and a fern) were then nudged down 7
studs and restored: **every one of the twelve CFrame components came back bit-identical** (worst
delta 0.000e+00). `apply` refuses without a backup that exists, is outside the repo, is under 24 h
old, was taken on the same place, holds the same model count, and agrees on every model's name and
index.
*Verify:* the evidence block below; `read_backup` and `cmd_apply` in `tools/forest_ground.py`.

**5. The tool only ever moves a model straight DOWN, and only one whose claws show.** The only
write is `model:PivotTo(model:GetPivot() + Vector3.new(0, verdict.lift, 0))` -- a rigid translation,
so X and Z come out bit-identical (which is what `restore` checks against). `TreeGround.decide`
returns `move = false` for a tree that is already seated or buried: raising one is a different
question and nobody asked it.
*Verify:* the `APPLY` payload in `tools/forest_ground.py` (one `PivotTo`, no other write); the
`seated` and "never raises a tree that is buried" cases in the spec.

**6. Measured on the live place: 782 floating models before, 65 after, and all 65 are the cliff
edges the tool deliberately listed rather than moved.** Trees whose junction is more than 0.2 studs
above the lowest terrain under their own trunk footprint: **758 -> 0** of 2,216 trees that were
moved, and ferns **24 -> 0**. The worst gap fell from **36.70 to 5.96**. 717 models moved; 65 were
listed as cliff edges (ground under one footprint varying more than 4.0 studs); 4,037 were already
seated.
*Verify:* the before/after tables below, both printed by the same `plan` code path.

**7. The claw fraction is measured per model and USED ONLY WHERE THAT MODEL'S INSTANCES AGREE.**
5 of 61 qualify. The spruces and larches are rejected (`unstable`) because their skirt branches
sweep to the ground, so the "first thing you hit" is a branch underside fourteen studs up; sinking
by that would bury the tree. **Cross-check:** all 26 `SilverBirch_Var11_LOD_0` measure
0.0424-0.0462, and the lobby hand-measured that same mesh at **0.075** by a different method
(horizontal rays) -- two methods agreeing in kind, with this one the more conservative.
*Verify:* `tools/forest_claws.json` (`reason` per row); `cmd_species` in `tools/forest_ground.py`;
`src/shared/Lobby/init.luau`, `TREELINE.SPECIES`.

**8. The tool cannot run against the wrong place (lesson L-055).** It asks **every** connected
Studio `game.PlaceId` and never trusts the name, refuses if none answers as the place asked for,
refuses if that Studio is not in Edit, re-checks the place id after resolving, and refuses a dirty
tree for `apply` and `restore`.
*Verify:* `resolve_studio`, `require_edit`, `require_clean` in `tools/forest_ground.py`.

**9. The DEV place has no `OurForest` and was not touched.** Asked directly in Edit:
`workspace:FindFirstChild("OurForest")` is `nil` on 136410205938347. Every write in this task named
place 130094961655666.
*Verify:* the evidence block below.

**10. Four of this task's own mistakes are written down as guards and assertions, not hidden.**
The footprint read the canopy; then the trunk mesh *was* the lower tree (`LarchTree_Var02`'s is 15.6
studs across, which made nineteen 30-stud floaters read as cliff edges and left them in the air);
then I applied the fix for that to the lobby as well and asserted it was inert, and `lobby.spec`
proved it was not; and a camera aimed at a model's pivot photographed the wrong tree.
*Verify:* `docs/research/2026-10-17-forest-trees-on-the-ground.md` section 6; the comments on
`TreeGround.flareFootprint`, at the end of `treePlan`, and on the `ROWS` payload's trunk-foot
columns; the tolerance case in `tests/server/tree_ground.spec.luau`.

---

## Evidence

### Backup and the restore proof (before anything moved)

```
[backup] 4819 models -> <runs-dir>\t199\ourforest-before.json
[restore] 3 of 4819 models from <runs-dir>\t199\ourforest-before.json
[restore] 3 restored, 0 skipped
#12    SM_AspenTree_Var03     y=130.5038  worst component delta vs backup: 0.000e+00  EXACT
#2496  LarchTree_Var02        y=96.4375   worst component delta vs backup: 0.000e+00  EXACT
#4000  SM_Lady_Fern_Var03     y=194.8557  worst component delta vs backup: 0.000e+00  EXACT
```

### The place, before and after `apply`

```
BEFORE -- 4819 models (2216 trees >= 10 studs, 2603 low plants)
                       n   >0.20   >1.00     worst
trees               2216     758     208     36.70   (junction above terrain)
                             738     202     36.70   (lowest geometry above terrain -- 196's metric)
low plants          2603      24       0      0.71
ALL                 4819     782     208     36.70

[apply] moved 717 models straight down.

AFTER -- 4819 models
trees               2216      65      48      5.96   (junction above terrain)
                              65      48      5.96   (lowest geometry above terrain -- 196's metric)
low plants          2603       0       0      0.18
ALL                 4819      65      48      5.96

[forest] 4819 models, 65 floating (>0.20), worst 5.96 @ 543422cc0d91 place=130094961655666
```

### The 65 exceptions -- listed, not moved (the Director's own instruction)

Every one is a cliff edge: the terrain under its own trunk footprint varies more than 4.0 studs, so
sinking it to the lowest reading would bury it in the bank. The worst eight, with positions:

```
  #2859  SM_AspenTree_Var04             gap   5.96  spread   6.56  at 3454, 189, -2002
  #1278  Old_Spruce_Tree_Var05_LOD_0    gap   5.48  spread  11.76  at 3300, 191, -1928
  #4615  LarchTree_Var07                gap   4.98  spread   9.43  at 3202, 218, -1735
  #4370  LarchTree_Var07                gap   4.88  spread  10.01  at 3235, 232, -1729
  #1565  LarchTree_Var07                gap   4.63  spread   8.87  at 3250, 238, -1729
  #2405  LarchTree_Var06                gap   4.45  spread   8.28  at 3298, 203, -1905
  #4747  LarchTree_Var05                gap   4.24  spread   9.01  at 2894, 179, -1625
  #3329  SM_AspenTree_Var04             gap   4.10  spread   5.33  at 2976, 164, -1776
```

### Where the DEV place stands

```
Edit, place 136410205938347: workspace:FindFirstChild("OurForest") -> nil
```

---

## For the Director's own proof frames (the dispatch's item 4)

Shot with `python tools/studio_mcp.py capture <name> <camera> <look-at>` against the Forest Test
Studio in Edit. The camera stands **on the ground at its own x,z** at 5 studs -- a character's eye
height -- 30 studs out, on the approach with no rise between it and the trunk (rule F). My own
frames of each are already in `<runs-dir>/t199/` as `dir-worst-before-*.png` and
`dir-worst-after-*.png`; they are evidence I looked, not the proof.

### The 5 worst BEFORE the fix (all now moved; the camera shows what the fix did)

| # | model | trunk base x, y, z | gap before | lift | camera | look-at |
|---|---|---|---|---|---|---|
| 2496 | LarchTree_Var02 | 2326.0, 133.1, -1670.5 | **36.70** | -37.30 | `2300.1,99.9,-1685.5` | `2326.0,100.4,-1670.5` |
| 4006 | LarchTree_Var02 | 3635.8, 244.9, -1545.8 | **35.47** | -36.07 | `3665.3,208.8,-1551.0` | `3635.8,213.4,-1545.8` |
| 1868 | LarchTree_Var02 | 2419.3, 148.0, -2427.8 | **35.22** | -35.82 | `2409.0,116.4,-2399.7` | `2419.3,116.8,-2427.8` |
| 4531 | LarchTree_Var02 | 2869.7, 210.3, -1355.2 | **34.26** | -34.86 | `2859.5,176.7,-1327.0` | `2869.7,180.1,-1355.2` |
| 4014 | LarchTree_Var02 | 3179.3, 247.2, -1731.3 | **33.96** | -34.56 | `3160.0,203.7,-1754.3` | `3179.3,217.3,-1731.3` |

### The 5 worst AFTER the fix -- every one a cliff edge the tool listed and did NOT move

| # | model | trunk base x, y, z | gap | ground spread | camera | look-at |
|---|---|---|---|---|---|---|
| 2859 | SM_AspenTree_Var04 | 3454.1, 194.5, -2002.0 | 5.96 | 6.56 | `3443.9,183.8,-2030.2` | `3454.1,192.5,-2002.0` |
| 1278 | Old_Spruce_Tree_Var05_LOD_0 | 3299.8, 196.4, -1928.3 | 5.48 | 11.76 | `3289.5,187.7,-1956.5` | `3299.8,194.9,-1928.3` |
| 4615 | LarchTree_Var07 | 3202.2, 223.2, -1734.5 | 4.98 | 9.43 | `3176.2,211.1,-1749.5` | `3202.2,222.2,-1734.5` |
| 4370 | LarchTree_Var07 | 3234.6, 237.2, -1729.2 | 4.88 | 10.01 | `3208.6,227.5,-1744.2` | `3234.6,236.3,-1729.2` |
| 1565 | LarchTree_Var07 | 3250.3, 243.1, -1729.0 | 4.63 | 8.87 | `3224.3,233.9,-1744.0` | `3250.3,242.4,-1729.0` |

### Before/after pairs at IDENTICAL cameras (what I looked at)

`<runs-dir>/t199/before-<n>-*.png` and `after-<n>-*.png`, same camera and look-at in each pair,
eye height, 14 studs out:

| # | model | gap before | what changed in the frame |
|---|---|---|---|
| 2496 | LarchTree_Var02 | 36.70 | before: empty grass and distant trees, the larch 36 studs overhead and out of shot. after: the whole larch fills the frame with its skirt on the grass |
| 739 | SilverBirch_Var06_LOD_0 | 2.62 | before: the trunk stops at a flat dark cut above the grass line. after: it carries down into the ground with a flare |
| 2871 | SilverBirch_Var06_LOD_0 | 2.67 | the same, on flatter ground: the base drops 3.27 studs and meets the grass |
| 3003 | SilverBirch_Var07_LOD_0 | 2.22 | a 26.5-stud birch sinks 2.82; its crown now sits near the ground and reads bushier. **The one frame in this set I would call a judgement rather than a win** |
| 2219 | SilverBirch_Var11_LOD_0 | 1.08 | a claw birch, lift -1.68. Before and after look near-identical because a bank hides the foot from this camera: not useful evidence either way, and kept for that reason |

---

## What I could not verify

* **That Karen will call it fixed.** This is a look, and only she judges a look. The frames are in
  `<runs-dir>/t199/` and the Director shoots the proof frames himself (the dispatch's item 4).
* **The AFTER "0 floating" is partly the setter echoed back, and I am saying so (lesson L-086).**
  For the 56 models whose claw fraction is 0, the junction IS the model's lowest geometry, so
  `clawGap` and `bottomGap` are the same number and re-measuring a tree the planter just moved can
  only give back what it set. The evidence that is NOT an echo is: the before/after frame pairs at
  **identical cameras**; the spec case that fires on #739's pre-fix numbers and declines on its
  post-fix ones; and the restore proof.
* **The 65 cliff-edge trees still float, by design.** A `SM_AspenTree_Var04` 5.96 studs up on a
  6.5-stud bank will still read as wrong from the downhill side. Seating those at the terrain under
  the footprint's **centre** rather than its lowest corner is the obvious next rule; it is a new
  rule and this task did not take it.
* **Nothing in `tests/` can reach the tool.** `forest_ground.py` needs a live Studio and a specific
  place, so what the specs cover is `TreeGround` -- the decisions -- and not the measuring or the
  MCP plumbing around them.
* **Team Create saving.** The place is Team Create and the moves were made in Edit; I did not and
  cannot force a save, and Studio was left in Edit with the change in the session.
