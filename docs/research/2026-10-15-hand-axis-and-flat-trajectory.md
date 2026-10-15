# The hand that was drawn end-for-end, and a rifle that shoots flat to 200 m

Task 189. Karen, 2026-10-15 ~14:15, verbatim, after playing task 188:

> *"hadn is oposit now reload with ending of arm not fingers / also are you sure we have right rifle
> aiming? / seems a bit odd when stands it has to be acurat 100% 100m 150m / when run I need a bit
> aim in front to be able hit in head or body does this implemented ?"*

Two systems, one sentence each: **which way round the right glove is drawn**, and **how flat the
rifle shoots**. The third clause is a question, not a defect, and section 6 answers it with numbers.

## 1. What each must do

1. **THE HAND.** The fist works the bolt knob and holds the wrist of the stock; the cuff and the
   forearm trail back toward the shooter. Not the other way round.
2. **THE SHOT.** A standing shot at a still target lands on the reticle's centre -- within **2 cm**
   -- at 50, 100, 150 and 200 m, while the TIME of flight (and so the lead on a running animal,
   task 185) does not move.

## 2. The hand: three sources, and what each is good and bad for

1. **Khronos, glTF 2.0 specification, "Coordinate System and Units"** (Khronos Group, read
   2026-10-15; the living specification, CC BY 4.0).
   <https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#coordinate-system-and-units>
   glTF is **right-handed, +Y up, +Z toward the viewer**, in metres, and a node transform may carry
   a negative scale.
   *Good for:* it is the format `tools/gltf_split.py` and `tools/asset_prep.py` read, so it is the
   frame every mesh measurement in this repo is taken in.
   *Bad for:* it says nothing about what the asset pipeline does afterwards, which is the whole of
   this defect.
2. **Autodesk, FBX SDK -- "Axis and unit conversion"** (Autodesk, read 2026-10-15; vendor
   documentation for the live SDK).
   <https://help.autodesk.com/view/FBX/2020/ENU/?guid=FBX_Developer_Help_nodes_and_scene_graph_fbx_scenes_axis_and_unit_conversion_html>
   An FBX scene declares its own axis system and importers **convert** to theirs -- a conversion
   that can include a reflection as well as a rotation.
   *Good for:* it names the step between the glTF the tools measure and the `.fbx` that is
   uploaded, which is where a flip can come from at all.
   *Bad for:* it is a reference for the SDK, not a statement about what Roblox's importer did to
   this file. Which is why section 3 measures the result instead of reading about it.
3. **Roblox, "Meshes" (Creator Documentation)** (Roblox, read 2026-10-15; current).
   <https://create.roblox.com/docs/parts/meshes>
   A `MeshPart`'s geometry is baked at import and is **not readable from Luau**: a script sees
   `Size` and `CFrame` and nothing else.
   *Good for:* it says plainly why this cannot be settled by a probe that reads vertices -- there is
   no such probe -- and therefore why a marker part plus a screenshot IS the measurement.
   *Bad for:* no statement about axis conversion either way.

**The pattern adopted:** *an axis convention claimed by a file is a claim about THAT FILE; the one
that matters is the one the engine draws, and it is established by putting a marker on the drawn
instance and looking at it.* Nothing is invented (rule 2); what changed is where the measurement is
taken.

## 3. What was wrong with the hand, measured

`HandAssets.AXES.RIGHT.fingers` was measured in task 188 off the published glove's **glTF** -- cuff
centroid to hand centroid -- as `(-0.9632, 0.2645, 0.0484)`, the mesh's own -X. That is correct for
that file. **The MeshPart Roblox draws is flipped in X against it**, so `Camera.Viewmodel.align`
built a frame whose +X points at the **cuff**.

**MEASURED IN THE RUNNING GAME** (rule 5), twice, in a solo Play session with the rifle in hand:
neon marker balls parked at the drawn part's own `+0.36 X` and `-0.36 X` and photographed in first
person -- `.screenshots/t189-axes2.png`, `t189-axes3.png`. **The +X ball sits on the brown fist; the
-X ball sits on the olive cuff.** A third frame (`t189-nohandright.png`) hides `HandRight` and shows
the brown fist and the olive sleeve disappear together, so the two colours are one part and not the
character's own arm.

Task 188 then SOLVED four poses in that reversed frame, and they came out end-for-end. Measured **as
drawn** -- the pose composed with the alignment the game really applies:

| bolt pull | grip point to the knob | fingertip to the knob | cuff to the knob | cuff behind the fingertip (Z) |
|---|---|---|---|---|
| task 188, as drawn | **0.327** | 0.495 | **0.212** | **-0.538** |
| task 189 | **0.000** | **0.180** | 0.490 | **+0.608** |

| hip hold | off the wrist axis | along it | fingertip to the wrist | cuff to the wrist | cuff behind (Z) |
|---|---|---|---|---|---|
| task 188, as drawn | **0.2036** | **+0.2591** | 0.499 | **0.236** | **-0.337** |
| task 189 | **0.0600** | **+0.0005** | **0.207** | 0.494 | **+0.470** |

Task 188's own bounds are 0.0719 off the wrist axis and 0.111 along it: **as drawn, its pose was
outside both**, and its spec passed anyway, because every number in that spec was computed in the
same wrong frame. That is the lesson, and section 7 is the spec that would have caught it.

**THE HONEST COST (rule 8).** The glove now actually touches the gun, so it clips more: sampled
glove vertices inside the gun's shell go from 3.7 % to 10.7 % at the bolt and from 6.9 % to 29.1 %
at the hip. A hand floating a third of a stud off the wood could not clip, because it was not
holding anything. Task 188 section 6 already recorded why a fist that really closes on this stock
needs a new glove -- its gap is 0.054 x 0.060 and the wrist of the stock is 0.144 x 0.203 -- and
that is still true, still an asset decision, and still 188a(j).

**THE LEFT GLOVE IS PROBABLY WRONG IN THE SAME WAY, AND IS NOT TOUCHED.** The same marker test on
`HandLeft` (`.screenshots/t189-left-ends.png`) puts its olive cuff flat against the fore-end with
its fingers pointing off into the air -- which is the "flat olive disc" task 188 reported and could
not explain. Its pose was tuned **by eye**, so it absorbs whatever `align` does, and flipping its
axis would move a hand Karen has already accepted. It is the next task's, with this evidence.

## 4. The shot: three sources for a flatter trajectory

1. **"Point-blank range" / maximum point-blank range** (Wikipedia, read 2026-10-15; CC BY-SA,
   actively maintained).
   <https://en.wikipedia.org/wiki/Point-blank_range>
   The real technique: choose the zero so the arc stays inside a **vital-zone band** across a span
   of ranges.
   *Good for:* it is the correct real-world answer to "one zero, many ranges", and it is what a
   hunter actually does.
   *Bad for:* the band is the size of a deer's chest, not 2 cm. On this rifle the best zero inside
   0-200 m still leaves about **+-6 cm** -- three times Karen's bar. It cannot deliver what she
   asked for, which is why it is rejected.
2. **Epic Games, `UProjectileMovementComponent::ProjectileGravityScale`** (Unreal Engine 5 API
   reference, read 2026-10-15; the engine's own current API).
   <https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/Engine/GameFramework/UProjectileMovementComponent>
   *"Custom gravity scale for this projectile. Set to 0 for no gravity."* A **per-projectile scale
   on gravity** is the shipped, named way an engine lets a game flatten a bullet without touching
   the world's gravity.
   *Good for:* it is exactly the shape adopted here -- one number per projectile, multiplying g,
   touching nothing else -- so the pattern is borrowed and not invented (rule 2).
   *Bad for:* it is an engine knob with no opinion about the value; the value comes from section 5.
3. **Hornady, .416 Rigby 400 gr DGS ballistics** (Hornady, read 2026-10-15; the maker's current
   published data).
   <https://www.hornady.com/ammunition/rifle/416-rigby-400-gr-dgs>
   The real cartridge's velocity and drop -- the numbers `Rifle.CONFIG`'s muzzle velocity and drag
   coefficient were fitted to in task 185.
   *Good for:* it says what REAL is, so the size of the concession is stated rather than hidden.
   *Bad for:* it is the thing Karen is overruling. That is hers to overrule.

**The pattern adopted:** *Unreal's per-projectile gravity scale -- one number on the weapon row,
read through `Ballistics.shotFor` beside the other three, multiplying whatever `g` is handed in.*

## 5. The number, and why 0.12

The deviation from the sight line is `elevationTangent*s - dropAt(s)`, and **both terms are exactly
proportional to g**: `Ballistics.dropAt` is the only function in the module that reads gravity, and
it is linear in it. So scaling g scales the whole band by that factor and moves nothing else.

Measured on the shipped numbers, the band peaks at **12.57 cm at 105 m**. A 2 cm bar therefore needs
0.159, and **0.12 reaches 1.51 cm** -- Karen's bar with a quarter of it to spare, which is the
margin the stepped flight (`Flight:advance` at `dt` = 1/240) needs to land inside it as well.

| still target | 50 m | 100 m | 150 m | 200 m | worst, 0-200 m |
|---|---|---|---|---|---|
| before (real gravity) | +8.9 cm | **+12.5 cm** | +9.9 cm | -0.1 cm | 12.57 cm |
| after (`GRAVITY_SCALE` 0.12) | +1.1 cm | **+1.5 cm** | +1.2 cm | -0.0 cm | **1.51 cm** |

Both rows are printed by the harness itself, twice over: once as pure arithmetic
(`ballistics.spec`), and once as a **plate standing on the reticle, shot through the server's own
`Weapon.Flight`** (`weapon_hits.spec`), which is task 183's method on the player's path.

**THE DROP IS NOT KEPT BEYOND 200 m, and that is deliberate.** A scale that switched back to 1 past
the zero would be a trajectory with a kink in it -- two answers at the seam, in the closed form AND
in the stepper, which would then have to agree about where the seam was. What it would buy is the
band from 200 m to `RANGE_STUDS` (800 studs = 224 m): **24 metres**, on a shot nobody in this game
takes. At 224 m the drop is 0.92 cm instead of 7.70.

**THE SHOTGUN KEEPS REAL GRAVITY (1.0).** Karen asked this of the rifle. A shotgun is a short-range
gun whose drop is part of what it is -- the slug is 11.4 cm low at the end of its own 330-stud range
-- and changing it would be changing a feel nobody complained about. Its numbers are reported in
section 6 so the Director can ask her.

## 6. The lead, which is the clause that was a question

*"when run I need a bit aim in front to be able hit in head or body does this implemented ?"* --
**yes, since task 185, and it is still live after this change**, because the lead is made of TIME
and `Ballistics.timeToRange` never reads gravity at all. Asserted rather than claimed:
`ballistics.spec` pins the flight time and the lead against the same shot at real gravity to **zero
tolerance**, and `weapon_hits.spec` flies the **real** `Weapon.Flight` at a scripted runner crossing
at a boar's sprint (38 studs/s) -- for the shotgun as well as the rifle since this task:

| | 28 m | 50 m | 92 m | 100 m | 200 m |
|---|---|---|---|---|---|
| rifle: the lead that hits | | 2.7 studs | | 5.6 studs | 12.2 studs |
| shotgun slug: the lead that hits | 2.3 studs | 4.3 studs | 8.6 studs | | |

In every row, aiming **AT** the animal misses and leading it by `v*t` **hits**, on the body or the
head as aimed.

## 7. What a spec could not have caught before, and now does

The only landmark on the glove was the grip point, and a grip point is **exactly as far from the
knob whichever way round the hand is**. `HandAssets.FINGERTIP_STUDS` and `CUFF_STUDS` are the two
ends of the glove, measured, and `viewmodel_poses.spec` now asks two questions of every right-hand
pose: is the **fingertip** nearer the thing being held than the **cuff**, and does the cuff trail
behind the fingertip along the gun by more than half the glove's own length? Task 188's shipped pose
fails both (0.212 against 0.495, and -0.538 studs of trail).

## 8. What I could not verify (rule 8)

1. **Whether Karen likes it.** The numbers and the frames say the fist is on the knob with the arm
   behind it; whether it reads as her own hand is hers to say.
2. **The exact transform between the source glTF and the drawn MeshPart.** What is measured is that
   the drawn part's +X is the fist while the file's +X is the cuff -- a flip along X. Whether the
   pipeline applies a reflection or a rotation that happens to agree along this axis is not
   established, and nothing here depends on it: the landmarks at both ends of the hand are measured
   in the frame this fix defines.
3. **The left glove** (section 3): reported, not fixed.
4. **The overlap figures** are a share of SAMPLED VERTICES inside the gun's shell, not surface area.
   They are comparable between poses and are not an area fraction.
5. **The bolt-cycle frames in between.** The first-person evidence is the hip and the bolt at full
   travel; the mid-cycle phases are covered by the spec rather than by eye, because the hand is
   carried rigidly by the bolt's own transform and the lift is a turn about the gun's Z, which
   cannot change which end is nearest the knob.
