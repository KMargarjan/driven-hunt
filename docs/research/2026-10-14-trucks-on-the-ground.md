# Trucks: wheels on the ground, and a military camouflage (task 186)

2026-10-14. Builder. Karen, verbatim:

* ~17:00 — *"car tyers are inside earth / trucks has to be comoflash"*
* ~21:15 — *"make cars comoflash like military like hunting cars"*

## 1. What the system must do

1. **No tyre may be inside the ground.** The four lobby pickups (task 180's free model, parked by
   task 182's pads) must stand ON the surface the engine actually produced, in the place Karen
   plays, whatever that surface turns out to be.
2. **They must read as military/hunting trucks**, not as white road cars, with the windows kept.
3. Neither may cost an upload, a human click, or the pads' alignment.

## 2. What was measured first

Live, in the Forest Test place (`130094961655666`), before a line was written — a ray straight down
on `Workspace.Terrain` under each of the sixteen wheels, against each wheel's own lowest point:

| truck | wheel deltas (studs, negative = under the ground) |
|---|---|
| 1 | −0.752 ×4 |
| 2 | −0.752 ×4 |
| 3 | −0.752 ×4 |
| 4 | −0.752, −1.017, −1.258, **−2.017** |

So it is not "a bit low": every tyre of every truck was buried, and the east bay's ground is not even
level with itself — a **1.266-stud spread across one truck's own four wheels**.

**Why.** `Build.trucks` stood each truck's bounding box on `anchor.Y`, the nominal shelf.
`Lobby.Field.fill` asks `Terrain:FillBlock` for a block whose top is that number, and **Roblox
terrain is voxelised**: the surface the engine produces is rounded to its own grid (150.000 against a
shelf at 149.248), and at the shelf's eastern edge the cut hill leaves part of a voxel standing.

This is **task 182's pad defect, against the same surface**: the four pads came out 0.17 studs
underground and `pad` was changed to lay them on `world.groundAt` rather than on the arithmetic. The
trucks were left on the arithmetic, and are the second half of the same bug.

## 3. Sources

| # | Source | Licence / status | Good | Bad |
|---|---|---|---|---|
| 1 | [`WorldRoot:Raycast`](https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Raycast) and [`RaycastParams`](https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams) — Roblox engine reference | Roblox docs, first-party, maintained | The engine's own answer to "where is the surface", with an include filter that can ask the terrain *alone* | Answers one column; four columns are four calls, and nothing in it fits a plane |
| 2 | [`CFrame.fromAxisAngle`](https://create.roblox.com/docs/reference/engine/datatypes/CFrame) and [`Model:PivotTo`](https://create.roblox.com/docs/reference/engine/classes/PivotTo) | Roblox docs, first-party, maintained | `fromAxisAngle` is exactly "turn this up-vector onto that normal", in one call, with no quaternion of ours | `PivotTo` is a `Model` method and task 177's truck is a `Folder`, so the transform is applied per part instead |
| 3 | Unity's standard *align-to-ground-normal* recipe — raycast under each wheel, build the orientation from the contacts rather than from one centre ray ([`Quaternion.FromToRotation`](https://docs.unity3d.com/ScriptReference/Quaternion.FromToRotation.html), Unity Technologies, maintained) | Unity docs, reference only — **no code taken**, a different engine | States the pattern plainly: a vehicle on uneven ground is placed from its *contact patches*, never from its centre; one centre ray is what buries a wheel on a slope | Unity's wheel colliders do it per frame with suspension; a parked prop needs it **once**, at build |
| 4 | Least squares plane through n points — the ordinary normal equations, `y = a·x + b·z + c` solved from the centred sums (standard linear algebra; the same shape `numpy.linalg.lstsq` documents) | public-domain mathematics | Four wheels are four samples and three of them would throw the fourth away; least squares uses all four and degrades to "level" when the determinant vanishes | Minimises the *squared* residual, not the worst one, so on genuinely non-planar ground one wheel is left high (§6) |
| 5 | This repo: `docs/research/2026-10-14-truck-pads.md` §"measured ground", and `Build.pad`'s own comment | ours | The pattern is already here, already reviewed, already bounded below by the slab this system lays itself | It measures one point per pad, because a pad is flat and 1 × 1; a truck is rigid and has four feet |

## 4. What was adopted, and why

**Borrowed, not invented** (rule 2):

* the ground reader and the lower bound are **task 182's pad rule**, unchanged — `world.groundAt`,
  clamped from below to the yard slab's top with `math.max`, so a truck can be neither under the
  terrain nor inside a slab of our own;
* the *contacts, not centre* placement is **source 3's**, which is how every engine that parks a
  vehicle on a hill does it;
* the fit is **source 4**, textbook, ~20 lines, exported pure (`Build.groundFit`) so it is a spec
  and not a belief;
* the rotation is **source 2's one call**, clamped at both ends.

Nothing here is new except the clamps, and the clamps are the measurement: `MIN_TILT_DEGREES` 0.25
(below it the ground is level and a tilt would be noise) and `MAX_TILT_DEGREES` 6 (the measured worst
case is ~3.7°; a truck lying at 26° is a bad ray, never a slope).

## 5. The camouflage: option A, a repaint, and no texture

The model's body is **eight MeshParts named `Color`**, `SmoothPlastic`, RGB 163,162,165, **with no
`TextureID` and no `SurfaceAppearance`** (measured in the live place, 76 parts in all, 45 of which do
carry a `TextureID` — none of them a body panel). So a `Color3` on them is the paint itself and not
a tint over somebody's photograph, and option A needs no second model and no upload.

**There is no camo texture, and that is a decision.** A library image would have to be *proved* to
load before anything could rest on it, and the only way to ask a running Studio is an asset call —
which `tools/studio_mcp.py` forbids in capitals: one `LoadAsset` through `execute_luau` poisoned the
thread and cost a whole night's gate on 2026-10-02. An unverified id that silently fails leaves four
untextured trucks and nobody told. Blotches wait for an uploaded texture and Karen's OK.

**The tones were photographed, not reasoned** (rule 5). The first palette was a correct olive drab
(RGB 74,80,54 and neighbours) on `Enum.Material.Fabric` — the material the rest of this model is
built from. The shot came back with four BLACK trucks. A side-by-side — the same three tones on two
trucks, one material each, in one picture — showed `Fabric`'s own weave is dark enough to swallow an
olive at this scale under the yard's tree shade. A second side-by-side put four brightness levels on
the four bays at once; the committed palettes are the two from the middle of it plus a lighter and a
browner neighbour, on `SmoothPlastic` (no reflectance, so no sheen).

## 6. Numeric targets, and what was actually reached

| | target | reached (live, after) |
|---|---|---|
| wheel under the ground | never | never: worst **+0.000** |
| wheel above the ground | ≤ 0.2 studs | trucks 1–3: **0.000** on all twelve wheels. Truck 4: 0.000 / 0.290 / 0.385 / **0.456** |
| tilt | ≤ 6° | ~3.7° on truck 4, 0° on the rest |
| body panels repainted | > 0 | 68 parts over four trucks (17 each: 9 panels, 4 tyres, 4 rims) |

**Truck 4's 0.456 studs is not a bug and will not go away by tuning.** Its four ground answers are
150.000 / 150.217 / 150.477 / 151.266 — that is not a plane, and **no rigid body has four wheels on a
surface that is not one**. The lift takes the worst contact, so the guarantee that is kept is the one
Karen asked for (nothing inside the earth) and the cost is up to 0.46 studs of air under one wheel,
down from 2.017 studs of earth over it. The two ways to reach 0.2 there are to move the east bay onto
flatter ground, or to cut `Field.fill`'s air block a little below the shelf so the boundary voxel
stops standing proud — both move something this task was not asked to move, and both are the
Director's call.
