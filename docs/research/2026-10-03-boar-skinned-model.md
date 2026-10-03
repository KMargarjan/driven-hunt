# The boar stops being a grey box: a bought, rigged, animated animal in this game

Task 115, 2026-10-03. Karen: *"we start with one bord and when this works we do with rest"*, then
*"1. go 2. upload"*.

## 1. What the system must do

1. One boar in the drive looks like a wild boar and **moves like one**: it stands, grazes, trots when
   drivers push it, gallops when it is shot at, flinches when a pellet lands, and falls over dead.
2. **Nothing about a hit changes.** The physics box, its three protruding hit zones, the wound model,
   the sounder formations and every attribute the weapon reads must be the same code over the same
   Instances as before. A player who could land a chest shot yesterday lands the same chest shot.
3. **Its feet must not slide.** A clip played at the wrong rate is the one thing that makes an
   animated animal read as a sticker, and it is the fault nobody notices in a screenshot.
4. It must **merge dark** (`BOAR_MODEL`, born OFF) so the whole thing is reviewed and green before
   Karen ever looks at it, and the rollback is one line.
5. The pipeline must be **repeatable in one command** for the female and the cub, which this task
   does not build.

## 2. The sources

| Source | What it is | Licence / status | Good | Bad |
|---|---|---|---|---|
| **RedDeer, "Boar Family"** ([fab.com](https://www.fab.com)) | The asset Karen bought: Male/Female/Cub, each a 14k-triangle skinned mesh on a 46-bone rig with **74 clips**, 4096 albedo (3 variants) / normal / roughness / AO / metallic / mask | Fab **Standard License**, bought 2026-10-03. Current product | A real artist's animal and a real animator's gaits. Every clip we need already exists, in place (`_IP`) **and** root-motion (`_RM`) variants | No licence file in the download; `fab.com/eula` answers **403** to this machine's fetch tool, so the grant was read through a web search and that is recorded in `CREDITS.md` and in the row. Textures are a 418 MB zip |
| **Roblox skinned meshes and the 3D Importer** ([rigging](https://create.roblox.com/docs/art/modeling/rigging), [3D importer](https://create.roblox.com/docs/art/modeling/3d-importer), [AnimationController](https://create.roblox.com/docs/reference/engine/classes/AnimationController)) | The engine's own route for a non-humanoid rig: one MeshPart whose descendants are `Bone`s, driven by an `Animator` under an `AnimationController` | First party, current | Exactly the shape the package exports to. Server-side `Animator:LoadAnimation` replicates, so every client sees the same animal | **The pages do not say what happens to an FBX's animations on import** (asked twice; the importer page lists "animation data" among supported content and stops). The 3D Importer itself needs a human click and cannot be driven from MCP |
| **Open Cloud Assets API** ([usage guide](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud/guides/usage-assets.md)) | `POST /assets/v1/assets`, already wrapped by `tools/roblox_upload.py` since Task 73 | First party, current | A `Model` from an `.fbx` with no clicks, which is how the mesh and its textures got in | **An `Animation` is accepted only as `.rbxm`/`.rbxmx`**, and the table's own restriction column says *"`.rbxm` or `.rbxmx` files edited outside of Roblox Studio might not upload or function"*. Nothing outside Studio can write one |
| **Blender 5.2 FBX importer/exporter** ([manual](https://docs.blender.org/manual/en/latest/addons/import_export/scene_fbx.html)) | The converter: 74 clips in, 10 out, scaled, retextured | GPL; bundled with Blender, current LTS | Reads the package's rig and its actions, and writes both an all-clips file and a one-clip-per-file set | **Slotted Actions** (4.4+) silently broke the obvious way to evaluate an action: assigning `animation_data.action` without an `action_slot` leaves every pose at rest. Measured here: all ten clips reported a foot speed of **0.000 m/s** before the slot was assigned |
| **nilo.io, "How To Export Animations to Roblox Studio From Any Tool"** ([article](https://nilo.io/articles/export-animations-to-roblox-studio)) and Roblox's own [emote import](https://create.roblox.com/docs/avatar/emotes/import) | The community and first-party route for an animation made elsewhere | Editorial / first party, current | Both name the same three steps, and the first-party page is explicit: Animation Editor → **Import → From FBX Animation**, convert to a CurveAnimation, then **⋯ → Publish to Roblox**, which hands back the asset id | It is **clicks**, per clip. There is no API behind it |

### Rejected, and why (rule 2: borrow before building)

- **Meshy** (this repo's own generator, `tools/meshy.py`): its auto-rig is **biped only**. It cannot
  rig a quadruped at all, so there is nothing to animate.
- **Tripo**: rigs a quadruped but ships one **Walk** clip, and its AI animation library is
  humanoid-only. One gait is not idle/trot/run/turn/hit/death.
- **Mixamo**: biped. Not applicable.
- **Hand-animating the rig in Blender**: 46 bones, ten gaits, by somebody who is not an animator,
  when a bought package already has 74 clips an animator made. This is exactly what rule 2 forbids.
- **`AssetService:CreateAssetAsync(keyframeSequence, Enum.AssetType.Animation, …)`**, the one route
  that would have made the ten animation ids without a human: **MEASURED and refused.** Through the
  harness's plugin-context `execute_luau`, in Edit mode, on 2026-10-03, for both `Animation` and
  `Model`: *"CreateAssetAsync and CreateAssetVersionAsync are not available yet"*. The beta
  announcement lists four supported types and `Animation` is not among them.

## 3. The pattern adopted

**A bought skinned mesh, scaled at export, welded to the existing physics box as a passenger, with
one `Animator` per boar and the clip chosen by a pure function of what the animal is doing.**

```
Workspace.Boars.Boar1              Part, 2 x 3 x 5.5, unanchored, server-owned   <- UNCHANGED
  ├── ZoneHead / ZoneChest / ZoneLegs   massless, CanCollide false, CanQuery TRUE <- UNCHANGED
  └── Visual                       Model                                          <- NEW, flag ON
       ├── BoarMale_NoAlpha        MeshPart + SurfaceAppearance + 40 Bones
       │    └── VisualWeld         WeldConstraint to the trunk
       └── BoarAnimation           AnimationController > Animator
```

Why this shape and not another:

- **A passenger, not a replacement.** `Massless`, `CanCollide = false`, **`CanQuery = false`**,
  `CanTouch = false`, and it carries neither `Damageable` nor `HitZone`. So the assembly's mass,
  centre of mass and inertia are untouched (the mover's `MaxForce` and `MaxTorque` stay correct), the
  collision body is still the plain box, and **a ray cannot see the animal at all**. The grey box is
  made invisible rather than deleted, and only once the model is really there.
- **The scale is baked into the upload**, because it has nowhere else to go: `MeshPart.Size` and
  `Model:ScaleTo` move the mesh and not the bones, so a skinned model resized after import tears
  apart the moment a clip plays (measured by the Director, 2026-10-03).
- **One writer, unchanged.** `Boar.Body` creates the visual, and nothing else may; `Boar.Brain` is
  not touched, not told anything new and not asked anything new. The yaw rate the turn clips need is
  measured in `Body` from the trunk's own facing.
- **The clip decision is pure** (`Body.clipFor`), so every gait, flinch, death and rate is a test
  case with no boar in the world.
- **Server-side `Animator`**, so all clients are shown the same animal and no client decides
  anything.

### The animation ids are the one thing a human must do

Open Cloud cannot mint an Animation from anything this repository can produce, and
`CreateAssetAsync` is not available. So `tools/boar_prep.py` writes **one FBX per clip** beside the
model, which turns the only available route into two mechanical clicks each: Animation Editor →
**Import → From FBX Animation** → **Publish to Roblox**. The ten ids then become ten rows in
`src/serverstorage/Assets` and nothing else changes — the code already reads them. Until then the
boar is drawn, welded and textured and **does not move its legs**, `BoarAssetsBoot` warns "0 of 10",
and a spec asserts exactly that state rather than leaving it a surprise.

## 4. The numbers

**Measured off the package itself** by `tools/boar_prep.py` on 2026-10-03, at this model's own scale.
`groundStudsPerSecond` is how fast the ground slides under a clip at playback rate 1: every clip is
in place (root-bone drift **0.0000** on all ten), so the animal's speed is carried entirely by its
feet, and the speed of a *planted* hoof is the clip's own ground speed. All four hooves agreed to
three decimals on every gait, which is what a correct contact threshold looks like.

| Clip | Frames @ 24 fps | Seconds | Ground m/s | Ground studs/s | Loops |
|---|---|---|---|---|---|
| `Idle_1` | 101 | 4.208 | 0 | 0 | yes |
| `Walk_F_IP` | 25 | 1.042 | 0.995 | **2.852** | yes |
| `Trot_F_IP` | 17 | 0.708 | 3.573 | **10.244** | yes |
| `Run_F_IP` | 13 | 0.542 | 6.003 | **17.210** | yes |
| `Turn_L/R_IP` | 17 | 0.708 | 0.647 | 1.855 | yes |
| `Death_L/R` | 30 | 1.250 | 0 | 0 | **no** |
| `Hit_F/B` | 21 | 0.875 | 0 | 0 | **no** |

**The playback rates that stop the feet sliding**, against Karen's three speed dials:

| Gait | Game speed | Rate |
|---|---|---|
| walk at `WANDER_SPEED` | 4 | 1.402 |
| trot at `TROT_SPEED` | 18 | 1.757 |
| run at `SPRINT_SPEED` | 38 | 2.208 |

The gait thresholds are the **midpoints of those three speeds** — 0.5 / 11 / 28 — and not the clips'
own natural speeds. Splitting at the clips instead (2.85 / 10.24 / 17.21) puts `TROT_SPEED` on the
*run* clip and leaves the trot reachable only for the 0.13 s `ACCEL` takes to cross its band.

**Geometry**, measured in Studio off the loaded asset:

- 13,976 triangles (Roblox's ceiling is 20,000 per mesh), 7,028 vertices, 40 bones after import
  (46 in Blender; the six unweighted helper bones are dropped), one MeshPart, one
  `SurfaceAppearance`, 1024 albedo / normal / roughness.
- `Size` **(1.4011, 3.2573, 5.5000)** studs. The **length** is what the model is fitted by:
  `Boar.CONFIG.BODY_SIZE.Z` exactly. Fitting all three axes would squash a real animal onto the grey
  box's proportions, and a squashed boar measures perfectly. The shoulder therefore stands 0.26 studs
  above the 3-stud physics envelope, which is right for an animal and invisible to a ray.
- The rig's origin is the **ground the animal stands on** (lowest vertex at y −0.002, a hind hoof at
  y +0.289), and it faces **−Z**, which is a `Part`'s own `LookVector` (nose at z −2.78, last tail
  bone at z +2.01). So there is no rotation correction and no pivot correction.

**The scale rule, which cost two uploads and is now a guard.** Roblox's importer reads **one raw FBX
geometry unit as one stud** and does not read the FBX unit header at all:

| Asset | Export | Arrived |
|---|---|---|
| 73934667856496 | `global_scale 0.028668`, `apply_scale_options='FBX_SCALE_ALL'` (the scale in the header) | 1.9185 studs long — the model's length in **metres** |
| 95872773434675 | `global_scale 2.866849`, `FBX_SCALE_NONE` | **550** studs long — Blender's own metre-to-centimetre hundred went into the geometry too |
| 120607820179994 | `global_scale 0.028668`, `FBX_SCALE_NONE` | **5.5000** studs. Correct |

`tools/boar_prep.py` now re-opens its own export, measures it in raw units and **fails the run** if
the length is more than 0.1 % out, so that cannot cost a third upload. The guard was mutation-checked
(`--scale-correction 100` → exit 1, "550.0000 raw units long but 5.5000 studs were asked for").

## 5. The ids landed, and loading them back corrected two things

The Director published all ten by hand on 2026-10-03 (`ESCALATE.md`, resolved). **No Curve-Editor
conversion was needed** — that step came from Roblox's *emote* page, and the publish dialog takes a
`KeyframeSequence` directly.

Every id was then loaded back with `AnimationClipProvider:GetAnimationClipAsync` before it was
written into the manifest, and the read-back found two faults that the ids alone would have hidden:

1. **Every clip length in the config was one frame too long.** A clip of N frames at 24 fps spans
   N−1 intervals, so `Idle_1` is **4.167 s**, not the 4.208 its 101 frames suggested; all ten were
   out by exactly 1/24 s. The published asset's last keyframe is now the source for both copies —
   `Assets`' `clipSeconds` and `Boar.CONFIG.MODEL.CLIPS[*].seconds` — `BoarAssetsBoot` warns if they
   drift, and `boar_model.spec` fails the build at more than half a frame. **The ground speeds in
   section 4 were never affected:** `tools/boar_prep.py` divides by the intervals it counted.
2. **All ten were published `Loop = true`**, deaths and flinches included, because the publish dialog
   does not ask. `AnimationTrack.Looped` is taken from the asset *when the asset arrives*, which is
   after `LoadAnimation` returns — so `Boar.Body` writes it from its own config immediately before
   every `Play`, not only where the track is built. A looping death stands the carcass back up every
   1.2 s.

## 6. Two faults the ids made visible, both found by looking

With the ids in, the animal still did not move, and finding out why took measurement rather than
reasoning. Both faults are the same shape: **everything reported success and nothing happened.**

**(a) The asset brings its own `AnimationController`, so every boar had two.**
`InsertService:LoadAsset` returns `Model > Model "<asset name>" > { MeshPart, InitialPoses,
AnimationController }` — Roblox's importer writes that controller, and it has no `Animator`.
`Boar.Body` added a second one beside it. The result was silent: every track loaded with the right
`Length`, `WeightTarget` went to 1, and `WeightCurrent`, `TimePosition` and every `Bone.Transform`
stayed at **zero for ever**, on the server and on the client, with no error anywhere.

A/B'd in a live session against three copies of the same clone, parented three different ways:

| Copy | Animation |
|---|---|
| keeps the asset's `AnimationController` | `t=0.000 w=0.00`, bone `Transform` identity, for ever |
| a **fresh** `AnimationController` + `Animator` | `t=0.767 w=1.00`, bones moving |
| a `Humanoid` + `Animator` | `t=0.767 w=1.00`, identical |

So it is not `AnimationController` versus `Humanoid` — it is **two things claiming one rig**, the same
class as the devforum's "a Humanoid disables an AnimationController". `attachVisual` strips every
controller and animator that arrives with the template, then adds exactly one of each and **asserts**
it, because the failure mode is an animal standing still rather than an error.

**(b) A wounded boar walked with clamped feet.** The walk/trot boundary was the midpoint of Karen's
dials, (4 + 18) / 2 = 11, which asks the walk clip — hooves 2.852 studs/s — for up to 3.86. `MAX_RATE`
clamped it to 2.50 and the feet slid by nearly 40 %. A healthy boar crosses that band in the 0.1 s
`ACCEL` takes and nobody sees it; a **wounded** one does not, because `Wound.speedScale` leaves it at
whatever fraction of 18 its injury gives — **measured at 8.99 and 9.84 studs/s, held for seconds**.
The band now ends where the walk clip reaches `WALK_MAX_RATE` (1.8), at 5.13 studs/s, and the trot
clip takes over near rate 1.0 — which is what a boar at 9 studs/s should look like anyway. `MAX_RATE`
is 2.8, above the worst real ask (the trot clip at the top of its band, 2.73), so it never shapes how
an animal moves. `boar_model.spec` sweeps every speed from `WALK_FROM` to `SPRINT_SPEED` and fails if
any of them clamps.

**What was seen afterwards, in a live session, with the flag on:** walk at rate 1.40 at speed 4, trot
at 1.76 at 18, run at 1.65 at 29, idle when stopped, a turn clip blended in at a standstill,
`hitFront` and `hitBack` once each from the side the shot came from, and `deathLeft` playing once and
**freezing at t=1.18 of 1.21 with rate 0** on a carcass lying on its flank (`UpVector.Y` = −0.01). The
feet sat within 0.01 studs of the ground throughout.

## 7. What Karen saw, and the two faults it found

Karen played it with the flag on (`PLAYTEST.md`, 2026-10-03): *"walking, running is good / yes synced
in when died / colour is good / head shaking sometimes vierd"*. The gaits and the colour are
**accepted**. Two defects, and both were found by measuring rather than by looking harder.

### (a) The carcass was buried, because the body was rotated twice

`Body.collapse` rolls the box 45 degrees past its tipping angle so gravity lays it on its side --
Task 28's answer to "a dead boar standing to attention". The **death clip does the same job**, in the
rig's own frame, from standing to flat. With both, the animal ends up roughly upside down. Measured
on a real kill, against a ground at y = 2.000:

| | y | relative to the ground |
|---|---|---|
| box centre | 2.994 | +0.99, and its own `UpVector.Y` was −0.001, so the box itself was lying correctly |
| `root_bone` | 2.992 | +0.99 |
| `head` | 0.803 | **−1.20** |
| `ear_2.R` (lowest) | 0.070 | **−1.93** |
| `hoof_b.L` | 2.863 | +0.86 |

Only the legs were above the surface, which is exactly what the screenshot shows. The same carcass's
box was then put back upright in the same session, and the clip landed where it was authored to:
lowest bone **−0.02**, head +0.44, hoof +0.11, nothing below the surface.

So **the roll happens only when nothing is drawn on the box**. With the flag off it is Task 28's
topple, unchanged; with a model attached the clip does the falling. Two orderings follow from it and
both are in the code: the coat is attached **before** the collapse can run in the same tick, and a
boar that is **already a carcass is never dressed** -- its box has been rolled, and dressing it then
would bury it after all.

### (b) The head shook because the decision outran its own crossfade

Measured over three 7-second windows on standing boars:

- up to **24 clip changes in 7 seconds** on one animal, several lasting **0.03 s** against a
  `FADE_SECONDS` of 0.15;
- **three tracks playing at once**, all writing the same bones;
- the raw per-frame yaw swinging **−120 to +173 deg/s** on a boar whose body speed was **0.0** -- a
  physics body under an `AlignOrientation` never sits perfectly still;
- the head -- the end of the longest bone chain, so the biggest amplifier of a disagreement between
  tracks -- moving at up to **8.0 studs/s** while the body was still.

Three causes, all fixed at the cause rather than damped:

1. **The signal was wrong.** One frame's facing delta divided by `dt` is not a turn rate. It is
   smoothed over `YAW_SMOOTH_SECONDS` = 0.2, with the exponential constant derived from `dt` so a
   frame-rate change does not change how much smoothing there is.
2. **The decision was bistable.** The turn clip had one threshold, so a yaw sitting on it flipped
   three times a second. It now enters at `TURN_FROM_DEG` 60 and leaves below `TURN_EXIT_DEG` 35.
3. **The decision outran the transition it started.** `MIN_CLIP_SECONDS` 0.18 is a hair over
   `FADE_SECONDS`, so a gait cannot be replaced before its own crossfade has finished and **two** is
   the most that can ever overlap. A death and a flinch ignore the dwell -- those are what a player
   is waiting to see. The **rate** still follows the speed every frame, so a clip held through the
   dwell is at the wrong gait for a fifth of a second and never at the wrong tempo.

Replaying the measured yaw sequence through the fixed decision produces **2 clip changes** where
every crossing used to be one; the spec asserts that, and `boar_model.spec` carries the whole set.

### (c) A dead boar could be shoved around, in both flag states

Karen's second look accepted the first two fixes -- *"now looks good"* -- and found a third fault:
*"when they died and lie on ground I can move them by walking it has to stay in same place without
move"*.

A carcass is an unanchored physics body with `CanCollide` on, so a character walking into it pushes
it. **This is not the model's fault.** Measured with `BOAR_MODEL` **off**: one impulse the size of a
walking character -- the assembly's own mass 23.1 times 16 studs/s -- moved the grey carcass **1.826
studs**. The grey box has been shoveable since Task 28; nobody had walked into one.

So the box is **anchored once it has come to rest**, in both flag states. Anchoring is the one thing a
walking character cannot move, and it touches no property a shot reads: `CanQuery`, `CanCollide`, the
`HitZone` attributes and the welded zone parts are all exactly as they were, and `Damageable` is false
because the animal is dead, which is Task 28's behaviour and not this fix's.

**It anchors when it has STOPPED, not after a fixed wait,** because the two states stop at different
times: with the flag off the box has to roll past its tipping angle and fall over, and with it on it
only drops the half-stud it was standing above. A timer would freeze one of them mid-topple. The
thresholds are measured and are 30x apart, which is what makes "still" unambiguous: a resting carcass
reads 0.000--0.003 linear and angular, and one still toppling peaked at **28.6** linear and **5.6**
angular in the same session. The body must be still for `CARCASS_STILL_SECONDS` (0.25) before it is
anchored, with a backstop at 4 s so nobody can keep a carcass pushable by leaning on it -- and the
backstop refuses to fire while the body is still FALLING, because a boar frozen in mid-air is a worse
bug than one that can be nudged.

Measured after the fix, in the spec, with the same shove: **0.0000 studs** in both flag states.
Anchoring took 0.63 s with the flag off (it toppled first) and 0.52 s with it on, and the box's bottom
finished at 619.993 against a ground of 620. Removing the one `Anchored = true` line fails three
cases.

### (d) A frozen death was costing 120 property writes a second, invisibly

Found by the **Reviewer**, round 1, not by looking at the game -- and it could not have been found by
looking. `Body.clipFor` keeps answering "the death clip, rate 1" for a dead boar while the frozen
track sits at speed 0 on purpose, so `play`'s re-rate branch wrote `AdjustSpeed(1)` and the freeze
wrote `AdjustSpeed(0)` straight back, **every frame**, for `CARCASS_SECONDS` (120) and up to
`maxBoars` (8) carcasses, on a server `Animator` whose every write replicates. Both writes landed
inside one Heartbeat, so every sample of `AnimationTrack.Speed` read 0 and the pose looked perfectly
held.

**Measured, by running round 1's own code again with the fix removed:** the carcass's Animator had
**no playing track at all** -- 0 samples above weight 0.01 over 4 seconds, on the server *and* on the
client. The non-looped death track had been driven past its end and had STOPPED, which is the rest
pose: the very thing the freeze exists to prevent. With the fix: `deathLeft` at full weight and
**Speed 0.000** across 241 samples in 4 seconds, on both sides.

The fix is at the cause. `play` now asks `Body.shouldAdjustRate`, which refuses to re-rate the clip
the boar is **holding** -- a held clip's speed is deliberately not the clip's rate, so "they disagree"
is not a reason to write anything. `handle.heldClip` is set once, by the freeze, and cleared when a
new clip starts, so the death's speed is written exactly once per kill. `Body.shouldFreeze`'s own
"a speed already 0" guard stays as the second line of defence it was always written to be, and
`Runtime:animationOf` hands a spec the write count the way `Runtime:woundOf` hands it a wound.

The same round found that `HOLD_EPSILON` alone is a window under two frames wide while `stepVisual`
gets the raw Heartbeat `dt`, so one long frame could step a death clean past its end. The window is
now whichever is larger, the epsilon or the distance the clip covers in that frame.

## 8. What could not be verified here (rule 8)

- The Fab Standard License grant was read through a web search, not from `fab.com/eula` (403).
- `Animator:LoadAnimation` on an id that does not exist returns a usable track (`IsPlaying` true,
  `Speed` the rate it was played at, `Length` 0) — measured, and it is what lets the spec prove the
  per-gait rate without an asset. The **held last frame of a death** cannot be proved that way, which
  is why `Body.shouldFreeze` is a pure function with its own cases.
