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

## 3a. The five right hands this task did NOT re-solve, and why they did not move

**The alignment is one rotation for every right hand in the game.** `Viewmodel.poseHands` draws the
right glove as `base * align` whatever weapon is in hand, and the horn branch does the same -- so
flipping the axis turns the SHOTGUN's three right-hand poses and the HORN's two end-for-end as well.
That was the Reviewer's round-1 finding and it was right: round 1 re-solved only the rifle's four.

The rifle's four were re-solved because Karen said they were wrong. The other five are hands she has
already accepted, and the honest thing to do with an accepted hand is **leave it exactly where it
is**. They are re-expressed rather than re-solved:

```
drawn = pose * align          so, to keep `drawn` while `align` changes,
pose_new = pose_old * (align_old * align_new^-1)
```

`align` is a pure rotation about the hand's own centre, so the POSITIONS do not move at all and only
the three angles change. The transport rotation is **149.88 degrees** -- which is the size of the
defect for anything that is not re-expressed -- and the drawn CFrame is reproduced to **2.2e-16**,
machine precision, for all five.

| pose | before (as written) | after (same hand, new frame) |
|---|---|---|
| `weapons.shotgun.carry.right` | yaw -103.1991, pitch -24.4176, twist -35.5376 | yaw 105.0526, pitch 45.8289, twist 18.7726 |
| `weapons.shotgun.aim.right` and `reload.right` | yaw 115, pitch -12, twist 60 | yaw -43.1721, pitch -10.4259, twist -60.3094 |
| `horn.carry.right` and `horn.blow.right` | pitch -24.4176, yaw -103.1991, twist -35.5376 | pitch -143.5824, yaw 68.4900, twist 160.6969 |

`viewmodel_poses.spec` pins all five against where they put the glove's two ends in the gun's own
frame -- numbers taken from the build Karen played, so they are an outside constant and not a copy
of the file being read.

**AND ONE OF THEM IS ALREADY END-FOR-END, REPORTED AND NOT FIXED.** Read in the corrected frame, the
shotgun's **hip** hand is right (the cuff trails the fingertip by **+0.447** studs, so the forearm
runs back along the gun) and its **aimed** hand is the same hand backwards (**-0.447**). That is a
pose Karen has accepted and this task was not asked to touch, so it is measured, printed by the
harness and queued (TASKS.md 189a), exactly as the left glove is.

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

| | 28 m | 50 m | 84 m | 100 m | 200 m |
|---|---|---|---|---|---|
| rifle: the lead that hits | | 2.7 studs | | 5.6 studs | 12.2 studs |
| shotgun slug: the lead that hits | 2.3 studs | 4.3 studs | 7.7 studs | | |

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

## 9. TASK 190: the palm was the half of the frame this note GUESSED

Karen, 2026-10-15 ~16:30, after playing the merge of this task:

> *"now right hand reload with outside of fingersit has to palm inside now is outside fix that"*

**She is describing section 8.2 and TASKS.md 189a(k), which this note wrote down as an open question
and shipped anyway.** Marker balls on +X and -X settle ONE AXIS. A frame needs two, and the second
was filled in by ASSUMING the import mirrors the mesh in X -- which flips `fingers` and leaves
`palm` pointing the wrong way along Z. Section 8.2 said the transform was "not established" and that
"nothing here depends on it". The second clause was wrong: `align` squares the palm against the
fingers, so the palm's sign IS the roll of every right hand in the game.

**MEASURED THE SAME WAY, ON THE OTHER AXIS.** The published `HandRight` template was cloned into the
sky at identity rotation with neon balls on its own +-Y and +-Z and photographed down all four
faces. **The -Z face is the PALM** (`.screenshots/t190-glove-minusZ.png`): it is the prep's own
`render_across.png` frame for frame -- the thumb and the index closing a ring you can see through,
the finger pads below it -- while +Z is `render_across-back.png`, the stitched back panel and the
knuckles.

**AND THAT CLOSES 8.2: IT IS A ROTATION, NOT A MIRROR.** In the drawn part the thumb lies at +Y with
the fingers at +X and the palm at -Z, so `thumb = fingers x palm` -- the RIGHT-hand relation. A
mirror turns a right glove into a left one and would break it. So the import is the proper rotation
carrying the file's (-X fingers, +Z palm) to the part's (+X, -Z), a half turn about Y, and both
measured signs are what that rotation predicts.

**THE LANDMARKS GO BACK TO TASK 188's Z.** A proper rotation moves no coordinate in the aligned
frame -- `(Rp).(Re) = p.e` on all three axes, cross product included -- so section 3's claim that
"only their Z changes" was a consequence of the mirror and goes with it. Recomputed off the same
prepped mesh in the same way: fingertip `(0.3324, -0.0599, +0.0178)`, cuff `(-0.3238, -0.0105,
-0.0315)`, agreeing with task 188 in X and Y to 2e-4.

### 9.1 What it was worth, measured on the player's path

One probe in a Play session, reading the DRAWN parts, printing the same frame two ways: the real
palm as the pre-190 build drew it and as this build draws it.

| | before | after |
|---|---|---|
| hip, palm against the wrist of the stock | 115.5-154.0 deg | **37.3-70.0 deg** |
| bolt stroke (79 samples, fist within 0.10 of the knob), palm against the bolt's own axis | 111.0-117.9 deg | **73.3-80.3 deg** |

Section 7's two checks still hold: the fingertip is **0.103-0.178** studs from the knob against the
cuff's **0.490-0.573**, and the cuff trails by **0.40-0.56**.

**HONEST ABOUT THE BOLT NUMBER (rule 8):** 73-80 degrees is on the right side of 90 but grazing, and
that is inherent rather than a leftover. A closed fist's palm normal IS the axis of the hole the
fist makes, and the knob sits IN that hole -- `GRIP_STUDS` is at aligned Y = 0, the middle of the
hand -- so the component pointing at the receiver is small whichever way round the hand is. **The
SIGN is the measurement.** Karen looked at `.screenshots/t190-bolt-after.png` and
`t190-hip-after.png` and said *"now is ok"*.

### 9.2 The thing the gate caught that no amount of care had

The five accepted hands were re-expressed by section 3a's transport, and the first run of the gate
failed three cases. **`Viewmodel.hornPose` does not read its three angles in `Mode.handOffset`'s
order.** The horn builds its right hand as `CFrame.Angles(pitch, yaw, twist)` -- `Rx*Ry*Rz` -- and a
gun's is `Ry(yaw)*Rz(pitch)*Rx(twist)`. A transport computed in the wrong one of those moved the
drawn horn hand **58.3 degrees**. Recomputed in the horn's own order it reproduces today's hand to
**5.8e-16**. Two conventions for three angles with the same three names is the real hazard here, and
TASKS.md 190a(a) is the row for making it one.

The other two were the yardstick moving, not the hands. `viewmodel_poses.spec`'s five pins are
`offset:PointToWorldSpace(landmark)`, so they move when the LANDMARK's Z goes back to task 188's
sign; the drawn hands do not. And `camera_mode`'s *"the two hands are posed differently"* compared
the two POSE frames -- each read in its own glove's aligned convention -- so its answer moved every
time either axis was re-measured (**139** degrees on task 188's numbers, **177** on task 189's,
**41.9** on task 190's) while the hands stood still. It measures the DRAWN rotations now and reads
**152.1** degrees on both sides of this task.

### 9.3 What task 190 could not verify (rule 8)

1. **Whether the roll wants finishing.** The sign flipped and Karen said *"now is ok"*; whether 73-80
   degrees reads as a closed fist to her over a longer play is hers.
2. **The LEFT glove is still untouched** -- 189a(a), with the same kind of guess still in it. The
   marker test that settled this one would settle it too.
3. **The Forest Test Studio could not be confirmed Rojo-synced** from here: every Rojo script's
   `Source` reads empty through StudioMCP in that place while DEV's reads correctly. Reported as a
   NEEDS KAREN (press Connect) rather than worked around.
4. **The rifle draws with a red-marble-and-gold texture in the DEV place**
   (`.screenshots/t190-bolt-after.png`). Seen, reported, not touched.
