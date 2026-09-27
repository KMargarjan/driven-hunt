# Research: the first-person viewmodel (Task 88)

Written 2026-09-27, by the Builder, **before any code** (rule 1). This is step 0 of the polish phase
Karen opened on 2026-09-27: *the shotgun, step by step, "until I say it looks and feels right"*.

**The decision this note serves, in Karen's words through the Director (2026-09-27):**
**first person all the time**, like her reference game — walking with the gun held **low in the
lower-left of the screen**, aiming (right mouse) **down the rib at the front bead**, **no crosshair at
any time**, **hands and arms on the gun**, minimal HUD. It **replaces** the 2026-09-25 decision
(over-the-shoulder third person, option A) recorded in `docs/design/camera.md` §1 and §12.

Design to be written: `docs/design/camera.md` (delta) · Brief: `reviews/task-88/BRIEF.md`

---

## 1. What the system must do

1. The player sees the world **from the eyes**, always — no third-person orbit, no zoom-out.
2. The gun is **always drawn**: low and left while walking, raised to the eye while aiming. Today it
   is drawn **only while aiming** and then unparented (`Camera.Config.VIEWMODEL_SHOW_BLEND`).
3. **No crosshair, ever.** Today the Hud draws one and hides it only in ADS
   (`docs/design/camera.md` §6.2).
4. Aiming lines the **eye, the rib and the bead** up, so the bead *is* the sight picture — which only
   works if the bead really sits where the pellets go (§6, the one testable number).
5. **Hands and arms** hold the gun (Karen's item; see §5.3 — the reference does not show them).
6. Recoil kicks and returns; the break-open reload is visible (§7, step S4).
7. None of it may move the **shot**: the shot ray is the camera's (`docs/design/shotgun.md` §5.5), so
   sway, bob and recoil on the *drawn* gun must stay cosmetic, or the picture lies.
8. It must **merge dark**: born OFF behind `FIRST_PERSON` so the Director can switch it on for one
   playtest and Karen can compare it against the shoulder camera in the same session
   (`docs/design/feature-flags.md`).

### 1.1 What already exists, so the delta stays small

`src/client/Camera/` is already the one camera owner, with `Camera.Viewmodel` as the one writer of the
drawn gun (`docs/design/camera.md` §3.1, §3.2), a pure core (`Camera.Mode`), a frame-rate-independent
blend, body hiding through `LocalTransparencyModifier`, and a frozen config with these numbers today:

| `Camera.Config` | value | note |
|---|---|---|
| `FOV_THIRD_DEG` | 70 | the engine default (§3 source A) |
| `FOV_AIM_DEG` | 50 | Karen's, accepted 2026-09-25 |
| `AIM_BLEND_SECONDS` | 0.20 | Karen's, accepted 2026-09-25 |
| `THIRD_DISTANCE_STUDS` | 12.0 | goes to 0 in first person |
| `PIVOT_HEIGHT_STUDS` | 1.6 | above `HumanoidRootPart`, about eye height |
| `VIEWMODEL_HIP_OFFSET` | `CFrame.new(1.2, -1.2, -2.8)` | low and **right**, mostly off-screen |
| `VIEWMODEL_AIM_OFFSET` | `CFrame.new(0, -0.6, -3.4)` | barrel under the view line |
| `BODY_HIDE_BLEND` | 0.60 | above it the local body is hidden |

So this is **not a new system**. It is a delta on an owned one, which is why this note is short on
"how do I build a viewmodel" and long on **what the reference actually does** and **which numbers**.

---

## 2. The reference, measured rather than described

Karen's reference is a third-party Roblox hunting game. Her four files live in
`<assets-dir>/references/inspiration-2026-09-27/` (two stills, two screen recordings) and are
**never committed and never copied** — they were looked at, and nothing from them is redistributed.

**Method, said plainly.** I cannot watch a video. Frames were extracted with the Blender that
`tools/asset_prep.py` already drives (`blender --background`, the video loaded as a sequencer strip,
single frames rendered to PNG in the scratchpad, outside the repo) and **looked at one by one**
(rule 5). The clips are WhatsApp re-encodes: **cropped to 16:9 and rescaled**, so *vertical* screen
positions are not trustworthy, and timings are trustworthy only to the sampled frame (24 fps).

### 2.1 What the frames show

| Question | What I saw |
|---|---|
| Camera | First person in every frame of both clips and both stills. |
| Walking pose | The gun is **low and to the left**, entering from the lower-left corner at roughly 30° — and in many frames (e.g. the walking still, and `f1936`, `f1946` of the long clip) it is **entirely off the bottom of the screen**. |
| Aiming pose | Looking **straight down the rib**: the barrels fill the lower-centre, the receiver is dark, and a **small red bead** sits at the muzzle on the rib line. |
| Crosshair | **None**, in either pose, in any frame — for the shotgun. |
| Reticle elsewhere | The **rifle's scope** (`f0700` of the short clip) and the **binoculars** (`f1408`) *do* draw a black vignette with a cross reticle. So "no crosshair" is the **shotgun's** rule in that game, not the game's rule. Ours is Karen's: none, ever. |
| Hands / arms | **Not visible in any frame I looked at** (≈14 frames across both clips plus both stills). The gun appears to float. They may be below the crop; I cannot say they are absent from the game, only that the reference I inspected does not show them. **Karen's "hands on the gun" is therefore ours to design, not ours to copy** (§5.3). |
| HUD | Compass strip, a world marker ("Footprints 842 yd"), weapon name + shells ("12ga Runner S2", `0|0`), a 4-slot hotbar, a clock. Karen asked for **minimal**; ours already draws less. |

### 2.2 The two numbers worth taking

**Mount time ≈ 0.29 s.** In the long clip the gun is invisible at frame 1946, in the low-left carry at
1955, mid-rotation at 1957, and fully aligned down the rib at 1961 — so the raise from carry to sight
picture spans about **7 frames at 24 fps ≈ 0.29 s** (bounded by the sampling: it is between 0.17 s and
0.38 s, and 1954→1961 is the best reading).

**ADS zoom ≈ 1.3×.** Two tree trunks 330 px apart in the carry frame (`f1955`) are 430 px apart in the
aligned frame (`f1961`) — about **1.3×**. From a 70° hip FOV that is
`2·atan(tan(35°)/1.3) ≈ 57°`. The camera also moves forward onto the stock, which inflates the
measurement, so **55–58°** is the honest band, not a single number.

Both are *reference* numbers, not orders: this repo already has Karen's own accepted 50° and 0.20 s
(§1.1), and a feel number she has accepted is not overridden by a measurement of somebody else's game
(`docs/design/camera.md` §12). §6 keeps hers and records these beside them.

---

## 3. Sources

### A. Roblox Creator Documentation — camera, FOV, first person
<https://create.roblox.com/docs/workspace/camera> ·
<https://create.roblox.com/docs/reference/engine/classes/Camera>
**Licence: CC BY 4.0** (`github.com/Roblox/creator-docs`, confirmed through the GitHub API).
**Maintained:** last push 2026-09-26, 841 stars. First-party.
**Good:** the numbers are stated rather than folklore — `FieldOfView` is "measured between 1–120
degrees" with "Default is 70"; `CameraType.Scriptable` "gives you full control of the camera"; and
`CameraMode.LockFirstPerson` "Locks the camera to first-person mode. When in this mode, all
parts/elements of the player's character are invisible to them, **except equipped Tools**."
**Bad:** that last sentence describes the *stock* camera, which this place does not use — we own a
`Scriptable` camera, so `LockFirstPerson` is not our mechanism and its free body-hiding is not ours
either. The docs say nothing about viewmodels, sway or recoil.
**Taken:** the FOV bounds and the default; the confirmation that first person with a scriptable camera
is ours to place and ours to hide the body for (`Camera.Rig` already does, §1.1).

### B. rokoblox5, "FPS using ViewModels (The improved version) // Parts: 2 out of 3" (DevForum, 2021-04-05)
<https://devforum.roblox.com/t/fps-using-viewmodels-the-improved-version-parts-2-out-of-3/1129877>
**Licence: none.** A forum post under Roblox's terms — readable, not re-distributable. Treated as a
**pattern**, and no line of it is copied.
**Maintained:** no; 2021, and `SetPrimaryPartCFrame` in it is deprecated (this repo already uses
`PivotTo` instead — `docs/research/2026-09-24-shotgun.md`, camera addendum).
**Good:** it is the canonical Roblox statement of the three mechanisms we need. The viewmodel is a
cloned character with legs, face and accessories stripped, re-placed **every `RenderStepped`** at
`Camera.CFrame:ToWorldSpace(offset)`. **ADS is an `AimPart`**: an invisible part on the gun marking
where the camera should end up, with the frame's transform `hip:Lerp(aim, spring.Position)` — so the
sight picture is a *geometric* consequence, not a hand-tuned offset. Recoil is two springs (the gun's
displacement and the camera's rotation), with the numbers written out: gun impulse `(0, 0, 12)`,
camera spring `Speed = 15, Damper = 0.8`, ADS spring `Speed = 16, Damper = 1`, and 2 % of the camera
kick kept permanently.
**Bad:** no FOV change at all (so ADS there is pure geometry); the 2 % permanent kick is a
spray-control mechanic for a competitive shooter and has no place in a hunting game; and it clones the
whole character every spawn, which is heavier than cloning the Tool the way `Camera.Viewmodel` does.
**Taken:** the **AimPart/sight-attachment idea** — it is the reason a bead sight can be made honest
(§6) — and the spring shape for recoil, without the permanent kick.

### C. Spa_rkk, "How to make an FPS viewmodel part 3! Sway and reloading!" (DevForum, 2022-06-21)
<https://devforum.roblox.com/t/how-to-make-an-fps-viewmodel-part-3-sway-and-reloading/1840530>
**Licence: none** (same as B). **Maintained:** no.
**Good:** the standard sway recipe, stated compactly: take the camera's rotation delta in object
space (`CurrentCamera.CFrame:ToObjectSpace(lastCameraCF)`), pull the X and Y angles out of it, and
offset the viewmodel by `CFrame.Angles(sin(x)*mult, sin(y)*mult, 0)`, smoothed by a lerp. Reloading is
an animation played on the viewmodel, its length read from the sound.
**Bad:** the smoothing is `lerp(..., 0.1)` **per frame**, which is frame-rate dependent — at 144 fps it
is twice as fast as at 60. This repo already fixes exactly that with Rory Driscoll's damping
(`docs/design/camera.md` source F), and the fix must be applied here too. Its reload is also driven by
a *server* script decrementing ammo, which we do not need: `Weapon.StateMachine` already owns the
break action.
**Taken:** the sway input (camera delta, not mouse delta — it survives controller and touch) and the
sine shape; **not** its timing maths.

### D. Quenty, `NevermoreEngine` — the spring
<https://github.com/Quenty/NevermoreEngine>
**Licence: MIT.** **Maintained: yes** — last push 2026-09-24, 614 stars.
**Good:** a correct, readable, openly licensed critically-dampable spring (`Target`, `Position`,
`Velocity`, `Speed`, `Damper`) that is the de-facto reference for spring motion on Roblox, and the
maths B's tutorial is an informal copy of.
**Bad:** it is a whole engine with its own loader and package layout; pulling it in for one spring
would add a Wally dependency and a second module system to a repo that has neither.
**Taken:** the **maths**, written out in a few lines inside the owner — which is precisely the
precedent `docs/design/camera.md` source E already set when it named EgoMoose's spring and
deliberately did not adopt it.

### E. The open-source Roblox FPS kits — surveyed, and none is adoptable
| Repo | Licence | Last push | Verdict |
|---|---|---|---|
| [minh-p/FPS_Viewmodel](https://github.com/minh-p/FPS_Viewmodel) | **none** (all rights reserved) | 2020-12-26 | Unusable: no licence is not "free to copy", and a `.rbxl` place file is banned here anyway. |
| [MonzterDev/First-Person-Camera-Roblox](https://github.com/MonzterDev/First-Person-Camera-Roblox) | **none** | 2022-04-25 | Same; itself a fork of yellowfats' "EasyFirstPerson" DevForum resource. |
| [sshar1/FPS-Framework](https://github.com/sshar1/FPS-Framework) | **none** | 2022-05-08 | Same. |
| [Kishero/CommunityFPS](https://github.com/Kishero/CommunityFPS) | **MIT** | **2016-05-30** | Licence fine, but ten years stale — it predates R15, Luau and `BindToRenderStep`. |

**This is the finding, not a footnote:** there is no maintained, openly licensed Roblox first-person
viewmodel framework to borrow wholesale. Rule 2 is satisfied the other way — by borrowing the
**documented pattern** (B, C, D) rather than inventing one, and by keeping the mechanism inside the
owner this repo already has.

### F. Karen's reference clips — measured, §2
Third-party game footage, `<assets-dir>/references/inspiration-2026-09-27/`. No licence to copy
anything from, and nothing is: what is taken is **two measurements and a description**.

---

## 4. The pattern adopted

**One camera owner, one viewmodel owner, and the gun's own geometry decides the sight picture.**

1. **First person is a state of the existing camera, not a new camera.** `Camera.Mode` already returns
   a pivot, a yaw/pitch and a distance; first person is `distance = 0` at eye height, with the orbit
   and the occlusion cast switched off. That keeps one writer of `workspace.CurrentCamera` and one
   foreign-write detector (`docs/design/camera.md` §3.1) and costs no new module.
2. **The viewmodel is always parented and blends between two poses.** `Camera.Viewmodel` keeps owning
   the clone; `VIEWMODEL_SHOW_BLEND` (unparent below 2 % blend) goes away, because the gun is now
   carried, not summoned.
3. **ADS is geometric (source B), not a magic offset.** The gun carries a **`Sight` attachment** whose
   look direction runs along the rib through the bead. Aiming blends the viewmodel until that
   attachment coincides with the camera (less eye relief), so the bead lands on the view axis
   *because of where the bead is*, not because somebody typed an offset that looked right once.
   **`Weapon.Hardware` creates it**, beside the `Muzzle` attachment it already creates for exactly this
   reason ("the muzzle is an Attachment, not a number re-derived at each call site") — so both gun
   variants (the parts gun and Karen's single-MeshPart upload) carry their own answer.
4. **Sway and bob are cosmetic and bounded** (source C's input, this repo's damping), and are
   suppressed to near zero in ADS so the sight picture holds still.
5. **Recoil is a spring** (sources B, D) on the *drawn* gun plus a small camera pitch impulse that
   returns to zero. **No permanent kick.**
6. **The shot is unchanged.** It stays `workspace.CurrentCamera.CFrame` → `FireRequest`
   (`docs/design/shotgun.md` §5.5), and first person makes that *more* honest, not less: the old
   third-person origin sat 12 studs behind the character and needed `CAMERA_ORIGIN_TOLERANCE = 30`
   studs of slack plus an ignore list to stop the camera ray resolving onto the shooter's own back
   (`docs/design/shotgun.md` delta (a)). At the eye, origin and muzzle are within a stud of each other.

---

## 5. The three things the reference cannot answer

### 5.1 Where exactly the bead should sit on screen
The clips are cropped, so I can say the bead is **centred horizontally** and cannot say what its true
vertical position is. §6 makes this a *requirement* instead of a measurement: the bead must project to
the screen centre within a tolerance, and a client spec checks it.

### 5.2 Whether the reference changes FOV
≈1.3× of zoom was measured (§2.2), but part of it is the camera moving onto the stock. So "change the
FOV to 50 on aim, as Karen already accepted" is kept, and the measurement is recorded beside it.

### 5.3 Hands
Not visible in any frame I looked at. Two routes exist, and the design must pick one owner for it:
**(a)** clone the local character's `LeftHand`/`LeftLowerArm`/`LeftUpperArm` and the right equivalents
onto the viewmodel (source B's approach; gets the player's skin tone and sleeves for free, costs an
R15-vs-R6 branch and a re-clone whenever the character changes), or **(b)** build two simple arm parts
in the viewmodel's own shape list (cheap, always the same, and wrong for a player wearing anything).
**Recommendation: (a)**, drawn by `Camera.Viewmodel` — the owner of everything in front of the camera —
with (b) named as the fallback if the clone proves expensive. Karen judges it on a screenshot, and it
is S3, on its own, precisely so the earlier steps are not held up by it.

### 5.4 And one constraint the reference cannot see: our gun is one MeshPart
`Assets` says it plainly — the uploaded shotgun template "is EXACTLY ONE MeshPart". The parts gun
(`Weapon.Shape`) has `BarrelLeft`, `BarrelRight`, `Rib`, **`Bead`**, `Action`, `TopLever`, `Forend`,
`Stock`, `TriggerGuard`, `Trigger`; Karen's mesh has none of them. Consequences the design must carry:
* the `Sight` attachment (§4.3) is **measured per variant**, not read off a `Bead` part;
* **a break-open reload motion (S4) cannot hinge the barrels of a single MeshPart.** Either S4 tilts
  the whole gun (honest, cheap, and reads at a glance), or the asset is split into barrels + action by
  `tools/asset_prep.py` and re-uploaded, which is an **asset task, not a camera task**. The design
  should specify the whole-gun tilt and name the split as the later upgrade.

---

## 6. Numeric targets

Karen's accepted numbers are kept; the reference's measurements sit beside them, and every row is a
dial she can turn in a playtest. "New" means this task proposes it.

| Number | Target | Where it comes from |
|---|---|---|
| Hip FOV | **70°** | engine default (A); unchanged |
| ADS FOV | **50°** | Karen, 2026-09-25. Reference measures 55–58° (§2.2) |
| Mount / ADS blend | **0.20 s** | Karen, 2026-09-25. Reference measures ≈0.29 s (§2.2) |
| Eye height | **1.6 studs** above `HumanoidRootPart` | today's `PIVOT_HEIGHT_STUDS`; first person reuses it |
| Camera distance, first person | **0** | new |
| Carry pose | gun in the **lower-left**, barrel rising to the right, **roughly half of it off-screen** | reference §2.1; today's hip offset is lower-**right** and must move (new) |
| **Bead alignment, ADS steady state** | **≤ 8 px from screen centre at 1920×1080** (Roblox's FOV is vertical, so 50°/1080 px = 0.046°/px → 0.37°; ≈0.9 studs at 143 studs, which is 40 m, against a boar 5.5 studs long and 3 tall) | **new, and the one testable one** — §4.3 makes it geometric, `Camera:WorldToViewportPoint` measures it |
| Sway | peak **≤ 2°**, decaying with the repo's frame-rate-independent damping over **≈0.15 s**; **× 0.15 while aiming** | C's shape, this repo's damping (new numbers) |
| Walk bob | **≤ 0.03 studs** vertical at **≈1.8 Hz**, **off while aiming** | new; deliberately small — it must never be what moves the bead |
| Recoil, gun | back/up impulse, spring **speed 15, damper 0.8**, fully returned in **≈0.25 s** | B's constants (new here) |
| Recoil, camera | **1.5° pitch** per slug, **0° permanent**, returned by the same spring | B's shape, with the 2 % permanent kick deliberately dropped (§3 B) |
| Reload motion | the break-open tilt lasts exactly `Shotgun.CONFIG`'s existing reload window | no new timing invented |

---

## 7. The step plan (why it is five steps and not one task)

Karen's own instruction is step by step until she says it looks and feels right, so each step is small,
switchable and **photographable**. The flag `FIRST_PERSON` is born OFF and every step lands behind it,
so `main` keeps the accepted shoulder camera until she says otherwise.

| Step | What it is | The screenshot that proves it |
|---|---|---|
| **S1** | First-person camera, no crosshair, gun carried low-left | Standing still: the world from the eyes, no reticle anywhere on screen, the gun's barrel across the lower-left corner, no part of the player's own body visible |
| **S2** | ADS raise to the bead + FOV | Two shots from one spot — hip and full ADS — with the bead on a named distant object, plus the measured pixel distance from screen centre |
| **S3** | Hands and arms on the gun | Both poses again: two arms holding fore-end and grip, in both, with no gap at the wrist and no arm through the receiver |
| **S4** | Recoil kick and the break-open reload | The frame at the top of the kick, and one mid-reload with the action open |
| **S5** | Sound (later) | N/A — a sound is not a screenshot; Karen judges it in a playtest |

---

## 8. What this costs, and what could go wrong

* **The shoulder camera does not disappear**, it sits behind the flag as the OFF branch, so both
  branches must keep working and the specs must drive both by parameter
  (`docs/design/feature-flags.md` §13.3). That is the cost of being able to hand Karen a comparison.
* **The crosshair is the Hud's**, not the camera's (`docs/design/camera.md` §6.2). S1 changes what the
  Hud *reads*, never who draws it.
* **`camera_client.spec` asserts the third-person framing today** — distance, shoulder offset,
  occlusion. Those cases must keep asserting the OFF branch and gain their first-person counterparts;
  they must not be deleted.
* **A first-person camera at the eye sits inside the head.** The body is already hidden above
  `BODY_HIDE_BLEND`; in first person it is hidden always, which makes `BODY_HIDE_BLEND` meaningless in
  that branch — say so rather than leaving a number that no longer does anything.
* **The near plane.** At 0.1 studs a gun 4.4 studs long held at the eye will clip if the pose is
  wrong; that is a screenshot problem, and it is why S1 ships before anything else is layered on it.
