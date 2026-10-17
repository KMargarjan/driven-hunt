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

## 6. What task 202 measured, three days later, and why section 4's targets passed anyway

**Karen, 2026-10-14 ~17:00:** *"beater hadn is bad and 2 horsn instead 1 it's broken"*.

**There is one horn, and there always was.** Measured in the Forest Test on 2026-10-17 as a real
player beater (`DHForestStartRole=beater`), in five states -- at rest, blowing, after a respawn,
after a new drive, and after `/hunter` -> `/beater`: in every one of them the scene holds exactly two
horn part-trees, the viewmodel clone under `workspace.CurrentCamera` (drawn) and the real Tool's two
parts on the character at `LocalTransparencyModifier = 1` (not drawn). Zero stray horn pieces
anywhere in `Workspace`. Section 3's complement holds; task 176's claim was true.

**The one horn was DRAWN as two.** With the carry pose this note shipped, the 3.125-stud horn ran
from 3.61 studs in front of the lens to **0.99**, and its near end projected to **x = 1455 on a
955-pixel screen** -- off the right-hand edge. Rays cast through the viewmodel at eye height hit the
horn at x = 500..700, the glove at 740..800, **nothing at 840..880**, and the horn again at 910..940:
two pale masses with clear background between them. The blow pose was worse -- the mouthpiece ended
up **0.23 studs behind the eye** and the horn filled the right half of the screen.

**Section 4's targets did not catch either, and that is the lesson.** *"Mouthpiece at the blast
reaches the bottom-centre of the view"* is a target on ONE POINT of the object. It was met exactly --
the mouthpiece reached (-0.001, -0.450, -0.050) -- and meeting it is what put the mouthpiece at the
lens. A pose target has to bound the WHOLE object against the PICTURE, not one landmark against one
axis. The same hole let the glove pass: it was pinned against its own past
(`viewmodel_poses.spec`'s task-189 case) and never against the horn, so it sat 0.21 studs off the
centre line of a tube whose radius there is 0.185 -- outside the horn it was holding.

### 6.1 The horn's own geometry, measured

`Horn.MESH` says how big the mesh's BOX is; it says nothing about where the horn lies inside it, and
the box is nearly empty. `Horn.TUBE_SAMPLES` closes that: a clone of the real Handle was anchored at
a known CFrame in a running session and raycast at 0.125-stud steps along the Handle's Z (down from
+4 and up from -4 for the tube's top and bottom, then across at the mid height for its width). The
centre line sags from `y = +0.02` at the bell to `y = -0.34` at the middle and rises to `y = +0.44`
at the mouthpiece; the section is 0.56 studs across at the bell, about 0.33 in the middle and 0.13 at
the tip. The two ends agree with `Horn.mouthpieceOffset` and `Horn.bellOffset`, and were LOOKED at:
`.screenshots/t202-horn-fixture.png` photographs the clone with a red ball on the Handle's +Z (the
dark narrow mouthpiece) and a blue one on its -Z (the open bell).

### 6.2 The targets that replace section 4's two pose rows

| What | Target | How it is checked |
|---|---|---|
| The carry is in the picture | every measured section of the tube has `(|x| + r) / depth` and `(|y| + r) / depth` below `tan(FOV/2)`, and nothing is nearer than 1.0 stud | `viewmodel_poses.spec`, *"draws the whole horn inside the picture at the carry"*. Shipped before this task: 1.6270 / 0.8580 / 1.0885 -- fails |
| The blow is in the picture | the same, over the horn up to `z = 1.0`; the mouthpiece beyond it may leave the bottom edge, because the mouth IS the camera | `viewmodel_poses.spec`, *"brings the mouthpiece to the mouth without filling the screen"*. Shipped before: 10.4059 / 1.3913 / **-0.2297** -- the mouthpiece was behind the eye |
| The glove is on the horn | the grip, the fingertip and the cuff each lie within the tube's own radius of its centre line, in BOTH poses | `viewmodel_poses.spec`, *"lays the right glove on the tube in both poses"*. Shipped before: the grip 0.2100 off a 0.1854 tube -- fails |

The viewport is assumed no narrower than it is tall. Roblox's `FieldOfView` is the VERTICAL angle, so
the vertical bound is exact for every window and the horizontal bound is the vertical one again --
the strictest any window can ask for. Karen plays at 955 x 785, which has 1.22x that horizontal room.

### 6.3 The mouthpiece was not on the horn either

`Horn.mouthpieceOffset` answered the centre of the mesh BOX's `+Z` end face. The box is 1.084 studs
tall and the tube's centre line at that end is **0.4415 studs above** that face's centre -- so the
point the raise was aimed at, and the point `camera_client`'s *"within 0.15 studs of the view's own
vertical axis"* was measured against, sat in mid-air beside the horn. The target passed on it while
the horn was elsewhere: in the pose this task ships, the box end reads **0.410** studs off the view
axis and the measured tip reads **0.025**. Since task 202 the function lifts that end onto
`TUBE_SAMPLES`' centre line, which is what makes the client case mean what it says.

### 6.4 What the Forest Test's own `/beater` cost before any of this could be measured

Neither `[ForestTest] <name> asked to join as a <role> (start switch)` nor `[ForestTest] <name> is a
<role> at (...)` printed in a Play Solo session, twice running: `Players.PlayerAdded` had not fired
for the only player in the place. Play Solo puts the local player into `Players` while the server
scripts are still running, and `ForestTestBoot` now yields for seconds before it reaches that
connection (`places: 3 dressed, 3028 planted ... 2.73s`, plus the asset loads). Both routes into a
role live inside it -- the `DHForestStartRole` switch AND the `player.Chatted` connection Karen's
`/beater` travels down -- so neither worked. The fix is the standard catch-up loop over
`Players:GetPlayers()` at boot, and with it the switch prints and the drive moves her.
