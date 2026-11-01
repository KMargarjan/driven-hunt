# The deer's leap over the road, and what a shot and a horn already do to it (task 245)

**KAREN, 2026-10-22, verbatim:** *"deer hit animations is in place ? when dead ect? also it has to
run fast when sound heared they usually jump when is cross road so can we do that ?"*

Three questions in one sentence, and they are three different kinds of work. The first two turned
out to be **verification** — the clips are published, the code that picks them is already
species-blind, and the whole answer was measuring it. The third needs a twelfth animation, a
publish, and a new branch in the one function that chooses what an animal is drawing.

## 1. What the system must do

1. **A deer that takes a non-lethal hit flinches**, and a deer that is killed falls and stays
   fallen on the ground — both with the clips the Director published in task 232, on Karen's own
   path (the Forest Test drive), not on a bench.
2. **A deer that hears a shot or a horn inside its hearing radius bolts away from the sound**, at
   its running speed, as the boar's `BOAR_BEHAVIOUR` sense model already makes a boar do.
3. **A running deer crossing the road leaps**, once per crossing, with the clip's own duration and
   ground speed — and a frame of one in the air over the road, at a player's eye height.

Numbers 1 and 2 needed no code. Number 3 does, and the rest of this note is about it.

## 2. Measured first: what deer do today

Everything in this section is a live read in the **Forest Test**, in Play, off instances — the
collider parts in `Workspace.Boars` and the `Animator` on each animal's `Visual` — because
`execute_luau` gets a fresh module cache and can never reach `ForestTestBoot`'s runtime. Every
animal below reached the world through `ForestTest.releaseLine` → `Runtime:spawn`, which is the only
spawn call a hunter's drive makes.

| Question | Measurement |
|---|---|
| Do the published clips play on a drive deer at all? | Yes. A hind and a calf 42 studs from the stand were both playing `trot` (id 133923553824296) at rates 0.91 and 1.33 |
| Does a killed deer play a death clip? | **Yes.** A stag took nine buckshot pellets in the chest at 53.3 studs; `carcass=true` at t = 0.19 s with `deathLeft` (id 90698126097935) at weight 1.00, the only track by t = 0.30, and held at **speed 0** on the last frame (t = 1.15 of a 1.21 s clip) for as long as the carcass stood. Its body rose from y 145.85 to 146.44 — the collapse — and stayed there |
| Does a hit deer play a flinch? | **Yes.** `hitFront` (id 114345439062479, length 0.83 s) reaches weight 1.00 **40 ms** after the hit, holds alone to t = 0.27 s, and is then cross-faded into the gait as the animal accelerates away — which is `Body.flinchWindow` doing exactly what task 116 built it to do. `hitBack` (id 89636256373552) was seen on a second run from the other side |
| Does a shot make a deer bolt? | **Yes, and it was never not working.** Two drive stags: **4.7 → 28.4** studs/s and **11.0 → 28.6** studs/s, each inside half a second of the bang, and each cross-fading `trot` → `run` (id 113134617381510) as it went. 28.3 is `PACE.RUN_SPEED` 24 × the deer's `runScale` 1.18, to a tenth |
| Does a horn? | **Yes, harder.** A stag standing `IDLE` at a measured peak of **0.00** studs/s, 40 studs from a blast of `Horn.spookStuds` = 357 studs: `hearHorn` pushed both deer, the stag went to state `FLEE` at a peak of **44.92** studs/s and moved from 40 to **89** studs from the blast in three seconds. 44.84 is `SPRINT_SPEED` 38 × 1.18 |

**So item 2 of the dispatch is already true of the shipped game**, and that is the finding: the
boar's sense model is not a boar's. `Boar.speciesConfig` replaces `BODY_SIZE`, `ZONES` and the
`MODEL` overlay and **nothing else**, so `SENSE` — `ENABLED`, `SHOT_AUDIBLE_STUDS`,
`SHOT_AUDIBLE_FROM_IMPACT_STUDS`, `SHOT_FLIGHT_UNTIL_EXIT` — is the world's table for every species,
and `Runtime:hearShot` and `Runtime:hearHorn` walk `self._boars`, which is every animal. A deer is
in that list. The only thing that is a deer's own is how fast it runs when it bolts, and `wary`
already scales that by 1.18.

**Two things a hunter must have before any of this can be seen, and both cost this task rounds:**
`Weapon.Rules` refuses a shot at a red deer with `no-licence` / **NO LICENCE** until the red stag
card is bought (750 coins, `licence.reddeer`), and it refuses any shot taken away from the player's
own stand with `off-stand` / **NOT IN YOUR STAND**. Both are correct and both are invisible: the
symptom is `impacts=NONE` and an animal that does not react.

## 3. The leap: what the package actually ships

`Jump_Run_IP` is in all three deer files. `Run_Jump_F_IP` — the dispatch's alternative name — is in
the **Calf's only**: the stag and the Doe ship 77 clips each and the Calf 80, and the Calf's three
extras are exactly `Run_Jump_F_IP`, `Run_Jump_L_IP` and `Run_Jump_R_IP` (measured by reading the
`AnimStack` names out of the three `*_anim_IP.fbx` on 2026-10-22). So `Jump_Run_IP` is the name.

Measured by `tools/boar_prep.py prep --clips Jump_Run_IP,Run_F_IP` on all three kinds:

```
stag  Jump_Run_IP   49 keys  2.000 s   root rise 0.0000 m  hoof rise 1.1107 m  lowest hoof -0.3324 m
stag  Run_F_IP      15 keys  0.583 s   root rise 0.0000 m  hoof rise 0.4811 m  lowest hoof +0.1327 m
hind  Jump_Run_IP   49 keys  2.000 s                       hoof rise 1.1107 m  lowest hoof -0.3458 m
calf  Jump_Run_IP   49 keys  2.000 s                       hoof rise 0.7331 m  lowest hoof -0.2267 m
```

**THE CLIP DOES NOT LIFT THE ANIMAL. It lifts its BODY and reaches its LEGS DOWN.** `root_bone` does
not move a millimetre — it is an `_IP` clip like every other one in this project — while the chest
(`Spine_01`) rises 0.267 m, the rump (`Spine_base`) 0.865 m, and a hind hoof gets **0.465 m, 1.66
studs, below the plane it rests on**. Played as it arrives, a leaping stag puts its back legs through
the road.

**The bound is 0.33 s inside a 2.0 s clip.** Frame by frame, the lift that would be needed to keep
the lowest hoof out of the ground is zero for frames 1–10, then (studs) **0.76, 1.52, 1.66, 1.52,
1.24, 0.88, 0.50, 0.11** over frames 11–19, then zero again, with a 0.46-stud secondary hop at
frames 29–34. At 24 fps the bound is frames 11 to 19 — 0.42 s to 0.79 s into the clip.

## 4. Sources

| # | Source | Licence / status | What it is good for | What it is not |
|---|---|---|---|---|
| 1 | [Roblox Creator Docs — `AnimationTrack`](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack) and [`Animator`](https://create.roblox.com/docs/reference/engine/classes/Animator) | First-party, maintained, docs under Roblox's own terms | The playback model this project already uses: `Play(fadeTime)`, `AdjustSpeed`, `AdjustWeight`, `TimePosition`, `Length`, `Looped`. `TimePosition` is the seam a phase-driven lift reads | Says nothing about root motion, because Roblox has none. `Length` is **0 until the asset is fetched**, which is why every number in section 3 that came off a track was read in Play and not in Edit (task 232 learned this) |
| 2 | [Roblox Creator Docs — Using animations / the animation system](https://create.roblox.com/docs/animation/using) | First-party, maintained | Confirms the house model: a clip poses a rig, and **translation is the game's**, not the clip's. An in-place clip plus an engine-driven body is not a workaround here, it is the only shape | No vertical-arc facility at all: if an animal is to leave the ground, something other than the Animator must raise it |
| 3 | [Unity Manual — Root Motion: how it works](https://docs.unity3d.com/Manual/RootMotion.html) | Proprietary docs, maintained, the canonical write-up | The vocabulary and the trap. It is explicit that a clip's **body transform** and its **root transform** are different things, and that "baking into pose" the Y of the root is what turns a travelling jump into an in-place one — which is precisely what has been done to `Jump_Run_IP`, and precisely why `root_bone` reads 0.0000 and the legs read -0.33 | Unity's importer can *undo* the bake (`Root Transform Position (Y)` → based on original). Roblox's cannot: what arrives is what plays, so the arc has to be reconstructed on our side |
| 4 | [Unreal Engine — Root Motion](https://dev.epicgames.com/documentation/en-us/unreal-engine/root-motion-in-unreal-engine) | Proprietary docs, maintained | The second independent statement of the same split, and of "Force Root Lock" — an engine deliberately pinning the root and letting the body move around it, which is the state this clip was exported in | Same as Unity: the engine-side half of the solution is not available to us |
| 5 | [Mixamo — the "In Place" export option](https://helpx.adobe.com/creative-cloud/help/mixamo-faq.html) | Vendor documentation, maintained; Mixamo assets are not used here | Why the `_IP` suffix means what it means across this whole package, and that an in-place export is the *industry default* for engine-driven characters | It is a naming convention, not a specification: it does not promise that the body's Y is preserved, and in this package it is |
| 6 | This repo: `deathLiftStuds` (task 232, `Boar.CONFIG.KINDS`) and `Body.visualOffset` | Ours | **The precedent, and it is exact.** The death clips had the same problem in a frozen form — the stag's own clip played on geometry baked smaller drops the hooves below the floor, 0.011 / 0.185 / 1.325 studs for stag / hind / calf — and the answer was one measured number per kind, applied as a vertical offset to the drawn mesh by the layer that already owns that offset | It is a CONSTANT, read once at the frame the death is frozen at. A leap is a curve, and the number changes nine times in a third of a second |

## 5. The pattern adopted, and why

**Borrowed (rule 2), from this repo's own task 232:** the correction is a **vertical lift of the
drawn mesh, applied by `Body`, measured off the published asset, stored as data per kind.** Nothing
new is invented and no new owner appears — `Body` is already the one writer of the visual's offset,
and `MODEL.CLIPS` is already the one table of per-clip measurements.

**What is new, and it is one word:** the lift is a **curve** rather than a constant, sampled by the
clip's own phase. The shape of that curve is the animator's, not ours: it is
`hoofFloorMetresPerFrame` — the lowest of the four hooves at each frame — inverted against the
clip's own resting floor. `tools/boar_prep_blender.py` now measures it, beside the `groundStudsPerSecond`
it has always measured. The project does not choose how high a deer jumps; it stops the deer sinking.

**Rejected: a ballistic arc computed in code.** It is the obvious alternative — give the body an
upward velocity at the verge and let gravity bring it down — and it is wrong for two reasons that
this repo has already paid for. It would make a **second writer of the animal's position** beside
the mover (`docs/PROJECT_CONTEXT.md`: *"Two systems wrote the creature's position"*), and the arc
would not match the clip, so the hooves would plant in mid-air. The clip has an arc; use it.

**Rejected: playing the whole 2.0 s clip.** Its last 1.25 s is a landing and a recovery at a ground
speed of 4.35 studs/s while the animal is travelling at 28; the feet would slide for more than a
second, which is the exact complaint (*"deer running is a bit odd"*) task 240 fixed. The leap plays
its **leading 0.79 s** — frames 1 to 19, approach, bound and landing — and hands the gait back.

**Where the trigger lives: the Brain, published to `Body.clipFor` as a fact about the animal.**
`clipFor` is pure and takes an `info`; "I am crossing the road" is one more field on it, decided by
the owner that already knows where the animal is and where it is going. Not by `Body`, which has no
idea where a road is, and not by `ForestTest`, which would be a second animal-behaviour writer.

## 6. The numeric targets

| Thing | Target | Where it comes from |
|---|---|---|
| The clip | `Jump_Run_IP`, one published id shared by all three kinds | All three share `Arm_Deer` (42 bones), as the other eleven do |
| Clip length played | **0.792 s** (frames 1–19 of 49 at 24 fps) | The bound ends at frame 19; everything after it is recovery |
| Peak lift | **1.66 studs** (stag and hind), **1.08** (calf) at Blender's measurement | `hoofFloorMetresPerFrame`, section 3 — **to be re-measured live per kind off the published asset**, because the game plays the STAG's clip on smaller geometry and absolute bone translations then overshoot (the `deathLiftStuds` lesson, 0.011 / 0.185 / **1.325**) |
| Road width to clear | **40 studs** (`ForestTest.SHAPE.halfWidthStuds` = 20) | The cut lane |
| Time to cross it | **~1.3 s** at a bolting deer's 28.3 studs/s | 40 / 28.3 |
| When the bound happens | 0.42–0.79 s after the leap starts, so **12–22 studs** into the lane | The clip's own frames 11–19 at 28.3 studs/s |
| Once per crossing | one leap per animal per road transit | Karen: *"they usually jump when is cross road"* — not a hop every stride |

## 6b. Addendum, 2026-10-23: the numbers re-measured on the published asset, and they moved

Section 3's figures are Blender's, taken on each kind's OWN export. The game plays the **stag's**
published clip on all three rigs, and a clip's bone translations are absolute studs -- which is the
whole `deathLiftStuds` lesson -- so every number the code uses was taken again in a **Play** session
on the real id (126500539626404), loaded onto each kind's own published model, 49 samples across the
clip, reading every `Bone.WorldPosition` in the mesh's object space against the rig's bottom plane
(`-meshSize.Y / 2`, the plane `Body.visualOffset` stands the mesh on), with the rest pose's own gap
subtracted. The Reviewer's round-1 note on task 245 asked for exactly this: the Blender pair that
produced section 3 is not reachable by `boar_prep.py selftest`, so its arithmetic was unpinned.

| | Blender, each kind's own export | **Live, the published id** |
|---|---|---|
| clip length | 2.000 s (49 keys at 24 fps) | **2.0000 s**, two ways: `KeyframeSequenceProvider` (49 keyframes, last at 2.0000) and `AnimationTrack.Length` on all three rigs |
| worst sink, stag | 1.660 studs | **1.1863** |
| worst sink, hind | 1.661 | **1.2563** |
| worst sink, calf | 1.084 | **1.3358** |
| when | frames 11-19 of 49 | t = 0.458 to 0.708, peak at **0.5417** |

**The stag's figure moved by a quarter of a stud and the calf's by a third, in opposite
directions**, and the live order is the one that makes sense: the sink GROWS as the animal gets
smaller, which is `deathLiftStuds` (0.011 / 0.185 / 1.325) again. Section 3's numbers are left as
they were -- they are a true measurement of a different thing -- and `Boar.CONFIG.MODEL.LEAP` carries
the live ones.

**Two of section 6's targets are corrected with them.** The time to cross a 40-stud lane at 28.3
studs/s is **1.41 s**, not the "~1.3" that table printed (the Reviewer's note). And the window
played is **0.75 s** -- the instant the hooves are back at the rig's own floor -- and not 0.792:
section 3 took the bound's start as (11-1)/24 and its end as 19/24, which is two conventions in one
sentence. The same slip is why that section lists eight lift samples over a nine-frame range.

**And the lift is not applied in the first cut.** Cancelling the sink means moving the drawn mesh
every frame of the bound, and `docs/design/boar-ai.md` section 6 forbids per-frame CFrame writing on
the boar -- `Body.liftDrawn`, the one writer of that offset, toggles welds and is called ONCE, at the
moment of death. A single lift held across the bound would pop the animal 0.9 studs at t = 0.458
instead of hiding anything. So the clip is drawn as it is, the measured cost is **up to 1.19 studs
of hind hoof below the road for 0.25 s** and nothing outside that window, and the per-kind numbers
sit in `MODEL.LEAP.LIFT_STUDS` so the follow-up is a drawing change rather than another measurement
session. Queued as TASKS.md 245c.

## 7. What is still open

~~**The animation asset id.**~~ **CLOSED 2026-10-23**: the Director published it as
`deer.anim.leap = 126500539626404`, one id for all three kinds exactly as the measurement said, and
task 245b wired it. What is open now is the SINK (section 6b) and Karen's own look, which is what
the `DEER_ROAD_LEAP` flag exists for.

## 8. Addendum, 2026-11-01 (task 325): nothing was ever lifting the animal

**KAREN, 2026-11-01, verbatim:** *"you need to fix red stag male when jumping it has to jump not like
now broken and famale and kid doesnt jump / work on it"*.

### 8.1 What was measured, in her place, at `main`

Her Forest Test at `4840e1df`, `DEER_ROAD_LEAP` on, crossings staged with `DHTestRelease`, every
deer near the road sampled every frame off INSTANCES (`325-log2.luau`, `<runs-dir>/325-before2.txt`).

**The dispatch's premise is half right and the correction matters.** All three kinds DO reach the
leap: `LEAP=true` on the stag, the hind and the calf, the published clip at weight 1.00, at rate 1,
for the whole 0.75 s window, cross-fading back to the run. The hind and the calf are not gated out
of anything -- `Brain.leapStarts`, `Body.clipFor` and `MODEL.LEAP` have no per-kind branch, and the
Forest Test's own schedule line says *"she stops at the verge, then they leap"*.

**What is broken is the same thing on all three: the body never leaves the ground.**

| | root y across the whole bound | peak upward speed |
|---|---|---|
| stag (Boar66) | 133.55 -> 134.52 -> 134.43, and it never comes back down (terrain) | 4.3 - 7.0 studs/s |
| hind (Boar67) | 134.04 -> 134.21, a range of **0.17 studs** | 6.4 - 10.9 |
| calf (Boar68) | 133.12 -> 133.25, a range of **0.13 studs** | 6.1 - 15.7 |

Those peak figures are the wobble of a box running over uneven ground, not an arc: a real launch
reads one large positive value decaying linearly at `g`. Section 3 said why -- the clip lifts the
BODY and reaches the LEGS DOWN -- and section 6b chose to draw it as it arrives. With the root
pinned, a leaping deer is a deer ploughing through the road in the pose of a jumping deer, and the
smaller the rig the deeper the legs go (1.19 / 1.26 / 1.34 studs). The frame
`<runs-dir>/325-before-stag-zoom.png` is a stag held at the bound's peak in her place: the pose is a
true bound -- neck up, chest lifted, forelegs tucked -- and both forelegs and both hind hooves are
**inside the road surface**, with no daylight under the animal anywhere. That is Karen's
*"broken"*, and on the hind and the calf the same sink swallows the whole motion, which is her
*"doesnt jump"*.

### 8.2 Real life: how high and how far

| # | Source | Licence / status | Good for | Not |
|---|---|---|---|---|
| 7 | [County Fencing -- deer fence height guide](https://www.countyfencing.co.uk/blog/deer-fence-height-guide/) | Trade guidance, maintained | Red deer clear **1.8 m** routinely and a confined one will take **2.1 m**; the exclusion standard is **2.4 m**. The ceiling a road bound sits far below | Fence clearance, not a cruising bound: a jump AT an obstacle, not a stride |
| 8 | [NC Wildlife -- fencing to exclude deer](https://www.ncwildlife.gov/connect/have-wildlife-problem/tips-coexisting-wildlife/fencing-exclude-deer) | State agency, maintained | The same number from an independent authority: a deer fence is 8 ft / 2.4 m | White-tailed deer, not red |
| 9 | Lingle, S. (1993), [*Escape gaits of white-tailed deer, mule deer, and their hybrids*](https://cdnsciencepub.com/doi/pdf/10.1139/z93-095), Can. J. Zool. 71 | Peer-reviewed, archival | The **bound** as a named gait: all four feet leave the ground together, with measured take-off and landing angles and limb flexion, used to gain height and clear an obstacle -- which is the shape of the clip we have | Mule and white-tailed deer, and it gives angles rather than a metre of apex |

**The number taken: 0.84 m of body rise (3.00 studs at `METRES_PER_STUD` 0.28) for the stag.** A
road is not a fence; an animal that clears 1.8 m when it must does not spend that on a cut lane, and
a cruising bound is a fraction of the maximum. 0.84 m is visibly a jump and sits well inside every
figure above. Per kind it is `3.00 x KINDS.<kind>.scale` -- 3.000 / 2.566 / 1.485 -- **floored at
the clip's own sink plus 0.15 studs of clearance**, which binds on the calf alone
(1.3358 + 0.15 = 1.4858 > 1.485). An arc lower than the sink would put the hooves back through the
road, which is the defect itself.

At Roblox's gravity (196.2 studs/s^2, read live in her place as 196.1999969482422, about 5.6x
Earth's) an apex and an airtime cannot be chosen separately: `h = g T^2 / 8`. 3.00 studs is
**0.350 s** in the air and **10 studs = 2.8 m** of ground at a bolting 28.3 studs/s. A real red
deer's bound is longer than that, and this is the honest cost of the engine's gravity: the height is
right, the length is short. Lengthening it means slowing the clip further, and at rate 0.715 the
legs are already as slow as they can be and still read as a bound rather than as slow motion.

### 8.3 The pattern adopted, and why section 6b's "nothing reads it yet" is now wrong

**One write of `AssemblyLinearVelocity.Y` at the frame the clip leaves the ground, and gravity owns
the rest.** `v = sqrt(2 g h)`, the textbook projectile.

Section 5 rejected "a ballistic arc computed in code" as *"a SECOND WRITER of the animal's
position"*. **That reading was wrong, and this is the correction.** The mover is a `LinearVelocity`
with `VelocityConstraintMode = Plane` on the X and Z axes (`docs/design/boar-ai.md` section 6, and
`Body.create`), written as `PlaneVelocity` and nothing else. The design's own words for that choice
are *"Plane mode leaves the plane normal (Y) free, so gravity -- not the constraint -- owns falling
and resting on the ground"*. **Y has never had a writer.** Giving it one value, once, adds no second
owner of the planar path: the heading, the speed and the route stay the mover's for the whole
flight. `Body.collapseVelocity` already writes this exact property, once, at the moment of death.

The second half of section 5 holds exactly as written: *"the arc would not match the clip, so the
hooves would plant in mid-air"*. So the arc is not chosen freely -- **the clip's own airborne window
is the arc's airborne window**. The hooves are below the rig's floor from t = 0.458 to t = 0.708 and
nowhere else (section 6b), which is the signature of an in-place export's airborne phase: those two
instants ARE take-off and touchdown. The clip is started at 0.458 -- its first 0.458 s is a running
approach the run clip was already drawing -- and played at the rate that makes that 0.250 s span
last exactly `2 v / g`, plus 0.10 s of its landing. So `MODEL.LEAP.LIFT_STUDS` is read at last, as
the floor under the apex rather than as a per-frame lift, and **TASKS.md 245c is closed by this
task**: `docs/design/boar-ai.md`'s ban on per-frame CFrame writing is not approached, because
nothing moves the drawn mesh at all. `Body.liftDrawn` is still called once a life, at the death.

### 8.4 Three cycles, measured in her place

| cycle | change | measured |
|---|---|---|
| 1 | the arc, at the clip's take-off frame | stag Boar10 rose 147.02 -> 149.15 and came down; **and bounded a SECOND time off the same crossing** (clip back to 0.491, vy +25.3, 0.55 s after the first). The Brain holds one `leaping` window for every kind (0.55 s) and the stag's own is 0.49, so a gate that asked only "is the leap clip playing" re-opened the instant it stopped |
| 2 | `handle.leapSpent`: Body's half of *"once per crossing"* | one take-off per animal, all three kinds. Landing rebound (largest upward speed in the 3 frames after touchdown): stag **10.50**, hind **8.39**, calf **18.35** studs/s -- a second little hop on top of the bound. Forward speed dipped to 10.7 / 7.6 / 22.6 at touchdown |
| 3 | zero a still-rising `AssemblyLinearVelocity.Y` at the end of the bound | **9 bounds in one drive, 1 take-off each, 3 of each kind.** Rebound: stag -0.50 / 4.55 / -5.33, hind 2.64 / 6.76 / -0.70, calf 4.13 / 3.94 / 5.37 (the residual positives are animals climbing the bank the road crosses). Forward speed at touchdown 12.9-23.9 / 13.0-17.3 / 24.0 |

Peak upward speed of the body during the bound, the same instrument on both runs:

| | before (`main`) | after (cycle 3) |
|---|---|---|
| stag | 4.3, 5.8, 6.8, 7.0 | **27.8, 28.6, 30.2** |
| hind | 9.2, 8.7, 6.4, 10.9 | **26.8, 26.0, 25.2** |
| calf | 8.2, 6.1, 10.6, 15.7 | **18.4, 20.1, 15.2** |

The first sampled frame is already past the launch, so the figures sit under `v0` = 34.3 / 31.7 /
24.2 as they must. A walking hind crossing still does not bound (`speed 1.9..4.5, LEAP=false`),
which is `MODEL.RUN_FROM` and Karen's *"when is cross road"* at a run.
