# Task 176: the horn in the first-person view, held in the hands

**Date:** 2026-10-13. **Builder.**

KAREN, 2026-10-13 ~19:05, after playing 175: *"horn still hangign somewhere it has to be in hand now
I can turn around and horn stand in place somehwere behind"*, and earlier (2026-10-12 ~21:45):
*"we need when I am playing beater to make animation when raising horn to face and blow"*.

DIRECTOR DECISION on 175's `ESCALATE.md` item 1 (*"the body does not face the look"*), 2026-10-13:
**option B now** -- the horn gets a first-person view like the gun's. Option A (the character's body
faces the camera: `AutoRotate` off plus a root yaw written from the view, which needs a new
character/movement owner and an Architect design) is queued as its own later task and is explicitly
NOT this one.

---

## 1. What the system must do

1. A beater in first person sees the horn **in his own hands**, drawn in CAMERA space, so it keeps
   the same place on screen while the view sweeps 360 degrees. Today it is drawn in the WORLD, welded
   to a hand of a body that does not turn with the look -- so turning leaves it "somewhere behind".
2. On an **accepted** blast the view brings the **mouthpiece to the mouth** (the bottom-centre of the
   frame), holds it for the blast, and lowers it -- on task 168's timing and on no second clock.
3. **Third person is unchanged**: every other player still sees the horn welded in the body's hand and
   raised by task 168's clip on the character's own `Animator`.
4. Only the horn gets this. Task 152's refusal -- *a non-weapon Tool draws no viewmodel* -- must stay
   true for any OTHER non-weapon Tool, and the two camera modules must read **one** fact, because they
   are exact complements: the thing in the hand is on screen once, either as the viewmodel or as the
   real Tool, never twice and never not at all.
5. The pose numbers are DATA, in the content lane, so the look is tunable with `tools/pose.py` and
   without a review round.

## 2. Sources

| # | Source | What it is | Licence / maintenance | Good | Bad |
|---|---|---|---|---|---|
| 1 | [Luanti (Minetest) `WieldMeshSceneNode`](https://doxy.minetest.net/classWieldMeshSceneNode.html) (`src/client/wieldmesh.cpp`) | The scene node that *"displays wielded tools in front of the first-person camera"* | LGPL-2.1+; maintained (`luanti-org/luanti`, commits through 2026) | **The whole pattern.** Its entry point is `setItem(ItemStack, Client)`: the first-person node draws **whatever item is wielded**, not a weapon class -- the item's own mesh, in front of the camera, decided by one call. Exactly what a horn needs | Its geometry comes from an item definition registry we do not have; the node is a child of the camera's scene node, which Roblox spells `workspace.CurrentCamera` |
| 2 | [ioquake3 `CG_AddViewWeapon` / `CG_CalculateWeaponPosition`](https://github.com/ioquake/ioq3) (`code/cgame/cg_weapons.c`) | Quake 3's first-person weapon draw | GPL-2.0; maintained | Two facts we take: the view item is placed from the camera's own origin and angles every frame (never parented to the player's body), and the **hands model carries a `tag_weapon`** that the item hangs off -- hands and item are one rigid assembly, posed once | It is the REVERSE of this repo's rig: there the item hangs off the hands, here `Camera.Viewmodel.poseHands` places the hands from the ITEM's pose. See 4.3 |
| 3 | [rokoblox5, *FPS using viewmodels, the improved version*](https://devforum.roblox.com/t/fps-using-viewmodels-the-improved-version-parts-2-out-of-3/1129877) (2021) | The Roblox-specific viewmodel technique this repo already borrowed in task 71 | DevForum post, no reuse licence; technique only, no code copied | The engine-level mechanics: a local, unreplicated model parented to `workspace.CurrentCamera`, `CanQuery = false` on every part, pivoted per frame from the camera CFrame | Uses the deprecated `SetPrimaryPartCFrame`; says nothing about non-weapon items |
| 4 | [`Instance:SetAttribute`](https://create.roblox.com/docs/reference/engine/classes/Instance#SetAttribute) | Engine reference | Current | An attribute written on the server replicates to every client, so "a blast was accepted" can reach the blower's own camera with no new RemoteEvent and no second code path for bots | Attributes are not events: the reader has to notice a CHANGE. See 4.4 |
| 5 | This repo: `docs/research/2026-10-01-poses-as-data.md`, `2026-10-11-beater-kit.md`, `2026-10-12-fanfare-boundary-pose.md` | The horn's own three notes and the pose-data lane | -- | The horn's geometry, its grip, its blast window and its arm clip are already measured and already one source each. Nothing here re-decides any of them | -- |

**Nothing is invented** (rule 2): the drawn-in-camera-space held item is source 1's pattern, the
per-frame placement from the camera CFrame is sources 2 and 3 (and is what this repo's gun already
does), the pose data is this repo's own content lane, and the blast window is task 168's numbers.

## 3. What each candidate route was, and which won

### 3.1 Draw the horn, or turn the body? (settled by the Director, recorded here)

Option A -- make the character's body face the camera -- would fix the horn *and* every other thing
welded to the body, but it is a new owner of the character's rotation (`Humanoid.AutoRotate` off plus
a root yaw written from the view) fighting the stock PlayerModule, which `Camera.Rig`'s header already
records as a second writer that cannot be removed. That is an Architect design, not a task. Option B
is inside an owner this repo already has: `Camera.Viewmodel` is *the* writer of the model under
`workspace.CurrentCamera`.

### 3.2 Where the drawn horn's geometry comes from: CLONE the Tool's Handle

Three routes:

* **(a) Build it from `Horn.pieces`** -- the parts horn. Rejected: the beater wears the uploaded MESH
  (task 169/175), so first person would show a DIFFERENT object from the one everybody else sees, and
  the viewmodel would carry a second idea of what a horn is.
* **(b) Clone the published mesh template** out of the folder the server parks the gun's meshes in.
  Rejected: there is no such folder for the horn (`Weapon.Horn.addMesh` welds the template straight
  onto the Handle through `Hardware.addPieceMesh`), so this route is a new publishing seam for no gain.
* **(c) CLONE THE TOOL'S OWN HANDLE, with its children.** Adopted. The Handle the server already
  dressed IS the horn -- the mesh, its `SurfaceAppearance`, its fallback colour, the parts build when
  the upload has not landed -- so the first-person horn is the world horn by construction, with no
  second geometry, no second asset key and no load order of its own. It is also the path this repo
  shipped for the GUN from task 71 to task 114 (`buildNewGun`'s header records why the gun stopped
  using it: the gun needed PIECES it could hinge, which a horn does not have). Borrowed, not invented.

The clone is stripped to what may live under a camera: every `BasePart` dressed
(`Anchored`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `Massless`,
`CastShadow = false`) and everything that is not geometry destroyed -- the `Blast` `Sound`
(the blast is the real Tool's, 3D, from the beater's own position), the welds, any
`LuaSourceContainer`. `CanQuery = false` is not cosmetic: `workspace.CurrentCamera` is a child of
`Workspace`, so this system's own occlusion cast can hit a part an inch from the eye.

`LocalTransparencyModifier` is written to 0 on every cloned part, because the SOURCE parts are the
ones `Camera.Rig` is holding at 1 for the local player and a clone inherits the property.

### 3.3 One fact, read by two modules

`src/shared/HeldTool/init.luau` answers **one** question -- *what does the first-person view draw for
this Tool?* -- as `HeldTool.kindOf(tool)`: `"weapon"`, `"horn"`, or nil. `Camera.Viewmodel` draws what
it names and refuses nil exactly as task 152 made it refuse; `Camera.Rig` hides the Tool's parts when
it names something and leaves them alone when it does not. The two cannot drift apart, which is the
property task 152 established with `Weapons.isWeaponTool` and which this task would have broken by
adding "or it is a horn" to two files.

It is a new third module rather than a row in `Weapons`, because `Weapons` is the table of GUNS
("what a row may not carry" is a rule in its own header) and a horn is not a weapon; and rather than a
function in `Horn`, because the horn does not know what a weapon is. `HeldTool` is the only file that
requires both.

### 3.4 The hands: the item carries the hand, not the other way round

Source 2 hangs the item off the hands' own tag. This repo does the reverse -- `poseHands` places each
glove from the drawn item's transform, out of `poses.json` -- and that stays, for two reasons: the
pose numbers for both gloves are already measured in the ITEM's frame (task 108), and there is exactly
one writer of each glove's CFrame. The horn therefore gets a RIGHT hand only, posed in the horn's own
frame. A free-floating left glove holding nothing is what the alternative would draw: a signal horn is
blown one-handed.

### 3.5 The blast window: a counter plus the viewmodel's own clock

What the client must know is *"a blast was accepted, this long ago"*. Four routes:

* **`Tool.Activated` on the client.** Rejected: the SERVER decides whether a blast happens at all
  (the cooldown, and `Match.mayBlowHorn` for a beater who is through the line), so a client-side
  raise would play for a refused blast -- the horn goes to the mouth and no sound comes out.
* **Compare `Tool.Grip` with `GRIP_BLOW`.** Rejected: it works by accident. `Grip` is replicated, but
  a CFrame equality test across replication is a float comparison nobody can promise, and it couples
  the camera to the exact tilt the server happens to use.
* **An attribute holding a SERVER TIME** (`Workspace:GetServerTimeNow`). Rejected: the engine
  reference for that method carries no description at all (fetched 2026-10-13), so "the two machines
  agree about this number" would be an assumption in the one place a wrong assumption shows as a
  gesture at the wrong moment.
* **An attribute holding a COUNTER, plus the viewmodel's own clock.** Adopted. The server stamps
  `Horn.BLOW_ATTRIBUTE` with an increasing number on every ACCEPTED blast, inside `Horn.blowTool` --
  the one door every blast comes through, a player's and a bot's. The client notices the value is not
  the one it last saw, starts its own clock (`Viewmodel.setClock`'s injected clock, which every spec
  already drives), and asks `Horn.blowWeight(since, config, pose)` how far through the gesture it is.
  No shared clock, no new remote, no second code path, and the whole window is one pure function a
  server spec can drive with no Studio at all.

**One source for the window**, and it is task 168's: `BLOW_POSE.RAISE_SECONDS` (0.2),
`CONFIG.BLOW_SECONDS` (0.9) and `BLOW_POSE.LOWER_SECONDS` (0.35) -- the same three numbers the server
uses for the arm clip's fade-in, the `GRIP_BLOW` hold and its fade-out. `poses.json` carries the two
POSES and no timings, so the first-person gesture and the third-person one cannot fall out of step.

## 4. Numeric targets

| What | Target | How it is checked |
|---|---|---|
| Camera-space stability | the drawn horn's offset from the camera is the SAME CFrame while the view sweeps 360 deg: position delta <= 0.001 studs | measured in Play on a real player beater (section 5) |
| Mouthpiece at the blast | reaches the bottom-centre of the view: `|x| <= 0.15` studs of the view axis and below the eye | measured in Play, and `Horn.mouthpieceOffset` is the one source for where the mouthpiece is |
| Raise / hold / lower | 0.2 s / to 0.9 s / 0.35 s, from task 168's numbers and nowhere else | `zz_horn.spec` drives `Horn.blowWeight` at the seven interesting instants |
| Draw cost | one `PivotTo` plus one hand CFrame per frame; the build only when the Handle changes identity or its drawable children change | the camera's own `maxUpdateMs` budget (0.3 ms, design 8.2) is unchanged |
| Only the horn | a non-weapon Tool that is not the horn still draws nothing and stays visible | `camera_client.spec`, both halves against the same shared fact |

## 5. What was measured

See `reviews/task-176/REQUEST.md` for the run and the numbers. The screenshots (rule 5) are
`.screenshots/` on the Builder's machine (git-ignored) and are described in the request: one
first-person carry and one first-person raise, which is what Karen judges.
