# The rifle with a scope: a second weapon, a telescopic sight, and a bolt between shots

2026-10-09 · Task 140 · Builder

Karen, 2026-10-09, having accepted task 139 (*"all good / next"*):

> *"afther this fixes we need to add rifle with scope and with aimpoint / should be faster since we
> know ho it works"*
>
> *"https://sketchfab.com/3d-models/dae-rigby-hunting-rifle-game-ready-asset-e77855f0c3ea4340a4d67a4ece4b87ac
> / I think we inaf this one it's already with scope"*
>
> *"it's in download you upload your self"*

The Director cut the separate **Aimpoint red dot** out of this task: what is built here is the Rigby
**with the scope that is already mounted on it**.

---

## 1. What the system must do

1. A **second weapon** the hunter carries beside the shotgun, switched with `1` and `2`.
2. **One round per shot**, with a **bolt cycle** between shots, and the bolt handle seen to move.
3. **Ballistics**: a single bullet, longer reach and flatter than the slug. Data, not code.
4. **A scope**: aiming (right mouse) **zooms the view** 4-6x and puts a **reticle** on the screen;
   releasing returns to the hip view, which has **no crosshair** (Karen's standing rule).
5. The **same hit path as the shotgun** -- `Weapon.Hits` -> `HitLog` -> the drive report -- with the
   report saying **which weapon** made the hit.
6. **Hands on the rifle** in first person, carry and aim poses as **data** (`poses.json`), so the
   Director can tune them live with `tools/pose.py` (the content lane, task 98).

What it must NOT do: change a single shotgun number. Karen approved that gun on 2026-10-09
(*"gun is ok"*) and task 139's dispatch said so in as many words.

---

## 2. The engine fact that decides the scope, and it is first-party

A telescopic sight in an FPS is one of two things:

* **Picture-in-picture**: the scene is rendered a second time, from a camera inside the scope, into
  a texture drawn on the lens. The scope ring stays in the world and the player keeps peripheral
  vision.
* **A full-screen zoom with an overlay**: the one camera narrows its field of view and a flat image
  of the scope (ring plus reticle) is drawn over the whole screen.

**Roblox cannot do the first one.** Its only render-to-texture surface is `ViewportFrame`, and the
Creator Hub's own page for it -- fetched 2026-10-09 -- shows every rendered object being *parented
into the ViewportFrame itself* (`part.Parent = viewportFrame`), with a `Camera` parented into it as
well. It renders the instances you put inside it, not the live `Workspace`; there is no
`SceneCapture2D`. Unreal's forum thread on exactly this shape ("Scenecapture 2d in multiplayer:
sniper scope") is the other side of that coin: there, the technique exists and the cost is that
**the game is rendered again** while scoped.

So the pattern is settled by the engine, not by taste: **narrow the field of view and draw the
reticle over the screen.** The honest note is that this costs the player peripheral vision while
scoped -- which is what a real 6x scope costs as well.

### What this project already has for it

This is rule 2 doing its job -- the camera owner already blends FOV for the shotgun's bead:

* `Camera.Config.FOV_THIRD_DEG = 70` (the engine default) and `FOV_AIM_DEG = 50`, described in the
  file as *"feel (Karen): 1.4x magnification, a bead sight and not a scope"*.
* `Camera.Mode.fovFor(...)` eases between them and `Camera.Mode.sensitivityScale` derives the mouse
  sensitivity from the **current blended FOV** as `tan(fov/2) / tan(fov_third/2)`, so the view slows
  down exactly as it magnifies.
* `Camera.Rig` is the one writer of `cam.FieldOfView` and watches for foreign writes.

A scope is therefore **one number per weapon** through machinery that is already written, tested and
owned: the aim FOV. Nothing in the camera has to learn what a rifle is.

---

## 3. Sources

| # | Source | What it is | Licence / maintenance | What it gives, and what it does not |
|---|---|---|---|---|
| 1 | [Creator Hub: `ViewportFrame`](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame) | Roblox's own API reference | First-party, maintained | **The deciding fact** (§2): a ViewportFrame renders instances parented into it, with its own Camera; it is not a window onto the world. It states **no** limits for lighting, shadows or cost, so nothing about performance is claimed here |
| 2 | [Creator Hub: `Camera`](https://create.roblox.com/docs/reference/engine/classes/Camera) | Roblox's own API reference | First-party, maintained | `FieldOfView` is a writable number and `CameraType` takes an enum. **It does not state the default or the allowed range** (fetched 2026-10-09 and checked): the 1-120 degree clamp is community lore, repeated on the DevForum, and is treated here as something to **measure in the place** rather than as documentation |
| 3 | [DevForum: "What camera type should i use for a sniper scope"](https://devforum.roblox.com/t/what-camera-type-should-i-use-for-a-sniper-scope/1725098) | Community thread | No licence; a 2022 thread, not maintained | **A negative result, recorded rather than dressed up.** It was fetched expecting a comparison of techniques and contains none: the accepted answer parks the camera on the scope part with `LockFirstPerson`. It does not discuss FOV zoom, overlays, ViewportFrames or cost. It is cited for what it is -- evidence that the community answer is "move the camera", which this project cannot do, because `Camera.Rig` owns the CFrame |
| 4 | [FastCast2](https://github.com/weenachuangkud/FastCast2) (continuation of EtiTheSpirit's FastCast) | Luau projectile library: travel time, drop, penetration | **MIT** (code; artwork CC-BY-NC-ND), actively maintained; the original FastCast is **no longer maintained by its author** | **Considered again and rejected again**, for the reason `docs/research/2026-09-24-shotgun.md` gave: at this game's ranges a hitscan ray is the truth, and the server already validates one. It is cited because it documents what we are **not** modelling -- bullet drop and travel time -- so "flatter than the slug" stays a **range and damage** statement and never becomes a drop curve nobody simulates |
| 5 | [Arma 3 OPREP: Weapon Sway & Fatigue](https://dev.arma3.com/post/oprep-weapon-sway-fatigue) | Bohemia Interactive developer report | Developer blog, 2014, not maintained; authoritative for its own game | The sway model worth borrowing: **two forces, breathing (vertical) and grip**, deliberately **"predictable - and thus manageable"** rather than random, with stance changing the amplitude. Holding breath suppresses it and costs a penalty spike afterwards. **It states no numbers at all** -- no amplitude, no period, no hold duration -- so every number in §5 is ours and is labelled as ours |
| 6 | [TV Tropes: Sniper Scope Sway](https://tvtropes.org/pmwiki/pmwiki.php/Main/SniperScopeSway) | Genre catalogue | No licence for reuse; community-edited | A weak source and marked as one. It is worth one line: the convention is a slow **figure-eight** tied to breathing, with hold-breath as the counter. Used only to confirm that a sine-pair sway is what players expect, not to settle any number |
| 7 | [Unreal forum: SceneCapture2D sniper scope](https://forums.unrealengine.com/t/scenecapture-2d-in-multiplayer-sniper-scope/374281) | Engine community thread | No licence; 2023 | The picture-in-picture technique in an engine that has it, and its cost (a second scene render). Cited to show the rejected branch is rejected on an **engine capability**, not on effort |

**Also read and not usable as sources:** the Sketchfab model page itself (the asset's licence,
CC-BY-4.0 by Martijn Vaes, which is a legal fact recorded in `assets/uploads.json` and §7, not a
design source).

---

## 4. The pattern adopted

**A second weapon is a second CONFIG behind the same owner.** `Weapon` (server) currently requires
`Shotgun` at the top of the file and reads `Shotgun.CONFIG` into a file-local `CONFIG`; `Hardware`
builds exactly one Tool per player and finds it by name. The rifle does **not** get a second owner:
one owner per system is rule 3, and two weapon owners would mean two writers of Tool instances, two
fire paths and two validators. What it gets is a **weapon table** -- the shotgun's config is one row,
the rifle's is another -- plus a per-player **equipped weapon**. That is the shape the Architect is
asked to pin (`reviews/task-140/BRIEF.md`), because it touches an owner boundary.

**The scope is one number per weapon**, applied by machinery that exists (§2): `aimFovDeg`. The
reticle is a **ScreenGui overlay** drawn by the Hud owner, shown while the equipped weapon has a
scope and the player is aiming.

**The bolt is a state in the state machine that already exists.** `Weapon.StateMachine` holds the
shotgun's break/load/close reload; a bolt cycle is a shorter sequence of the same kind, and the
handle is a **drawn piece** that moves with it -- the viewmodel already animates pieces from pose
data (`Camera.Poses`, `poses.json`).

**The ballistics are rows in the weapon's config**, reusing the shotgun's own names so that nothing
downstream learns a new word: `RANGE_STUDS`, `PELLETS` (1), `SPREAD_FULL_DEG`, `DAMAGE`.

---

## 5. The numeric targets

Every number here is **ours** unless the row says otherwise, and each one is a dial in data.

| Quantity | Target | Where it comes from |
|---|---|---|
| Scope magnification | **4x** at the first cut, dialable to 6x | Karen asked for "rifle with scope"; the Director's brief says 4-6x |
| Aim FOV | **19.9 deg** for 4x (13.3 deg for 6x) | Arithmetic, not taste: magnification `m = tan(70/2) / tan(fov/2)`, which is the formula `Camera.Mode.sensitivityScale` already uses. `tan(35) = 0.7002`; `fov = 2*atan(0.7002/4) = 19.87`, `2*atan(0.7002/6) = 13.31` |
| Mouse sensitivity while scoped | **falls with the FOV, automatically** | `Camera.Mode.sensitivityScale` already derives it from the blended FOV. At 4x the view turns at a quarter the rate -- which is the whole point of a scope and needs no new code |
| Zoom-in time | **0.20 s**, the shotgun's | `Camera.Config`'s existing ADS blend, accepted by Karen in task 92. A scope that snaps reads as a teleport |
| Effective range | **450 studs** against the slug's 330 | "longer and flatter". 450 studs is 126 m at 0.28 m/stud -- a realistic driven-hunt rifle shot, and past the 150-stud kill the Director asks for proof of |
| Rounds | **1 chambered**, reserve as data | A bolt rifle is one shot and then work |
| Bolt cycle | **0.9 s**, dialable | Between the shotgun's single-shell 0.45 s and its whole 2.0 s reload: a bolt is one motion, not four |
| Sway while scoped | amplitude **0.25 deg**, period **4 s**, a figure-eight (vertical at 1x, horizontal at 0.5x) | Ours. Source 5 gives the shape and explicitly gives **no numbers**; 0.25 deg at 150 studs is 0.65 studs of wander, which is inside a boar's chest zone -- a scope that cannot hold on an animal is a bug, not a feature |
| Reticle | a duplex: black ring, thin cross, thick outer posts | The genre convention (source 6), drawn from UI primitives exactly as the drive report's silhouette is -- **no upload** |

---

## 6. What is NOT built here, and why

* **The Aimpoint red dot**: the Director's cut. A second sight on a second weapon is its own task.
* **Picture-in-picture**: impossible on this engine (§2), not merely expensive.
* **Bullet drop and travel time**: rejected with source 4. "Flatter" is a range number here.
* **Hold-breath**: source 5's companion mechanic. The sway at 0.25 deg does not need a counter yet;
  if Karen asks for sway she can feel, hold-breath is the answer and it is one key.
* **A third-person rifle model for other players**: the shotgun's world gun is untouched and the
  rifle follows whatever that does. One player is the gate for this task (`TWO_PLAYER_PATHS`).

---

## 7. The asset, and the thing that must be painted out

"DAE - Rigby Hunting Rifle - Game Ready Asset" by **Martijn Vaes**, **CC-BY-4.0**: commercial use
allowed, **author must be credited**. The credit goes in `assets/uploads.json` with the id and in
this note. Twelve mesh nodes (`Wood`, `Barrel`, `Midden1`, `Midden2`, `Circle`, `Vijsjes`, `Trigger`,
`Safety`, `TriggerHandle`, `Scope`, `ScopeKnop`, `Lens`), one 4096² atlas plus a lens map.

**The scope carries a real maker's name and logo on the baseColor atlas.** It is painted out before
anything is uploaded -- a game may not ship another company's trademark on its gun -- and the
before/after crop is in the task's request. That is a licence-and-trademark matter, not a look one:
CC-BY covers the geometry and the texture; it does not license the brand printed on it.
