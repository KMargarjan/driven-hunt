# Design: camera — first person all the time, the viewmodel, and the bead

Architect, 2026-09-27, for **Task 88**. Commit `0af80b83198a925f18d89dedba441f45752278dd`
(`.agent-evidence/INDEX.md`). Read-only session: Read, Grep, Glob. No Studio, no network.

**This is v3 and it REPLACES v2 in this file** (`tools/agents.py`, `cmd_architect`, writes the whole
document to `docs/design/camera.md`). Nothing is dropped: every owner, number, mechanism and test of
v2 is still here, and the third-person shoulder camera v2 designed is now the **OFF branch of one
flag**. Git holds v2 (rule 7); the section numbers 1–13 are unchanged, because eight source files and
three spec files cite them by number (`Config.luau` → §8, `Mode.luau` → §4/§5.2/§8.1, `init.luau` →
§3/§4/§5.1, `Rig.luau` → §3.1/§5.3/§10.1, `Viewmodel.luau` → §3.2/§5.5, `Hud/init.luau` → §6.2,
`camera_client.spec` → §9.2/§9.3, `Weapon/Hardware.luau` and `Weapon/Shape.luau` → §3.2).
**§14 is new**: the five-step plan.

Inputs, in precedence order: **`reviews/task-88/BRIEF.md`** (the Director carrying Karen),
`docs/research/2026-09-27-first-person-viewmodel.md` (this task's note), the code on disk, v2 of this
file, `docs/design/shotgun.md`, `docs/design/feature-flags.md`, `docs/design/asset-pipeline.md`,
`docs/PROJECT_CONTEXT.md`, `CLAUDE.md`, `tools/studio_mcp.py`'s docstring.

**Karen's decision, 2026-09-27, through the Director: FIRST PERSON ALL THE TIME.** It replaces the
2026-09-25 decision (over-the-shoulder third person, "option A") that v2's §1 and §12 recorded. The
gun is carried **low in the lower-LEFT**, aiming (hold right mouse) brings it to the eye and the
player looks **down the rib at the front bead**, there is **no crosshair at any time**, hands and arms
are on the gun, the HUD stays minimal. It **merges dark** behind `FIRST_PERSON`, so the Director can
switch it on for one playtest and Karen can compare both cameras in the same session.

**Test of this document:** a Builder can build each of §14's five steps from it without asking a
question. Every number is in §8, every owner is named in §3, every seam is a named symbol in a named
file. **Task 88 writes no code** (brief §1.9); each step below is a later task.

---

## 1. What the system must do, and must not do

### 1.1 Must do

1. **First person whenever the flag is on**: the world from the eyes, always — no orbit, no zoom-out,
   no third-person framing at any blend. With the flag off, v2's mouse-locked over-the-shoulder third
   person, unchanged.
2. **The gun is always drawn** in the ON branch: low and left while walking, raised to the eye while
   aiming. Today it is drawn only while aiming and then unparented
   (`Camera.Config.VIEWMODEL_SHOW_BLEND`, `Camera.Viewmodel.update`).
3. **Aiming is geometric.** The gun carries a **`Sight` attachment** whose origin is the bead and
   whose `LookVector` runs along the rib; ADS blends the viewmodel until that attachment sits on the
   camera's axis, `EYE_RELIEF_STUDS` in front of the eye. The bead lands on the view axis *because of
   where the bead is*, not because somebody typed an offset that looked right once.
4. **No crosshair, in either pose, ever** (Karen, brief §1.2). Today the Hud draws one and hides it
   only while aiming (§6.2).
5. Be **the only writer of `workspace.CurrentCamera`** in the whole game (rule 3), and make a second
   writer *detectable at runtime*, not merely forbidden in prose (§10.1).
6. Be the only writer of the **mouse cursor and mouse lock**, through a named request API (§3.3).
   Unchanged by this task.
7. Own the **viewmodel** and everything drawn in front of the camera — the gun, the hands, the sway,
   the bob, the recoil on the gun, the break-open tilt — created, posed and destroyed by one module,
   never replicated, never able to decide a hit.
8. Keep the shotgun's fire path **working and unchanged**: the shot ray stays
   `workspace.CurrentCamera.CFrame` (`docs/design/shotgun.md` §5.5). Sway, bob and the gun's own
   recoil are cosmetic and may never touch the camera (§6.7).
9. Publish the camera's mode and blend, and **whether the view is first person**, so the **Hud** can
   decide the crosshair for itself. The camera draws nothing and sets `Visible` on nothing.
10. Behave deterministically at spawn, death, respawn, tool unequip and a missing character — each a
    named state (§4).
11. **Merge dark.** Born OFF behind `FIRST_PERSON`, with **both branches reachable by parameter**
    (`docs/design/feature-flags.md` §13.3), so both are tested in every harness run at one flag value.

### 1.2 Must not

Every row is a named cause of death of the previous project, written as a prohibition. Quotes are
from `docs/PROJECT_CONTEXT.md`, "Why the rules exist - the previous project", cited by section and
quote, never by line number.

| Prohibition | Why | Whose job instead |
|---|---|---|
| No module outside `PlayerScripts.Camera.Rig` may assign `CurrentCamera.CFrame`, `.FieldOfView`, `.CameraType` or `.CameraSubject` | "Two systems wrote the creature's position" | `Camera.Rig` (§3.1). Reading is allowed and the weapon does it (`Weapon.Input.onFire`) |
| **The stock Roblox camera scripts must be switched off, once, explicitly** | they are a second writer that ships with the engine | `Camera.Rig.acquire` (§5.3, §6.3) |
| **No new motion may be written to the camera outside `Rig.apply`.** The camera's recoil is a term inside `Mode.cameraCFrame`, never a post-write | a second write between frames is what the foreign-write detector counts; adding a kick after `Rig.apply` would make the detector call our own code a foreign writer, and the fix would be to weaken the detector | `Camera.Mode` decides, `Rig.apply` writes once (§10.1) |
| No module outside `PlayerScripts.Camera.Cursor` may assign `UserInputService.MouseBehavior`, `.MouseIconEnabled`, `.MouseDeltaSensitivity` or `Mouse.Icon` | "Three scripts set the mouse cursor" | `Camera.Cursor` (§3.3), through `requestFree`/`release` |
| The camera never creates a `ScreenGui`, `Frame` or `TextLabel`, and never sets `Visible` on anything drawn. **In particular it never hides the crosshair** | "One predicate answered two unrelated questions, so mounting hid both the crosshair and the weapon" | `PlayerScripts.Hud`, which **reads** `Camera.getMode()` and `Camera.isFirstPerson()` (§6.2) |
| The camera never writes the aim flag, never binds MouseButton2, and never fires `AimChanged` | two systems binding the aim button is the cursor failure with another property name | `PlayerScripts.Weapon.Input` |
| The camera never writes the character: no `CFrame`, `AutoRotate`, `WalkSpeed`, `Humanoid` state. It **reads** `HumanoidRootPart.AssemblyLinearVelocity` for the bob and that is a read | the character/movement owner does not exist yet, and inventing one here is "invented foundations" | unassigned; §12 Director item A |
| The camera never writes `Transparency` on a character part — only `LocalTransparencyModifier`, and only on the **local** character | `Transparency` replicates in intent; `LocalTransparencyModifier` is the documented client-local override | `Camera.Rig.setLocalBodyHidden` |
| **The viewmodel never writes the real Tool**, and `Camera.Viewmodel`'s arm clones live under `workspace.CurrentCamera`, never under the character | `Weapon.Hardware` is the only writer of `Tool` Instances; and `Rig`'s `DescendantAdded` watcher must never see a viewmodel part, or the two would fight over `LocalTransparencyModifier` | `Weapon.Hardware` (`src/server/Weapon/Hardware.luau`) owns the Tool; `Camera.Viewmodel` owns the clones. Disjoint by **parent**, which is a mechanism and not a rule |
| **The camera never creates the `Sight` attachment**, and never invents a bead position for a gun that has none | one geometry, one creator: the same reason "the muzzle is an Attachment, not a number re-derived at each call site" (`Hardware.build`) | `ServerScriptService.Weapon.Hardware` creates it beside `Muzzle`; `Weapon.Shape.sight` and the `Assets` row supply the value (§6.5) |
| The camera fires no `RemoteEvent` and has no server half | the camera is not replicated, so a server half would be a second truth about something the server cannot see | if the server ever needs to know someone is aiming, the **weapon** publishes it: it already owns the flag |
| **The camera reads `FIRST_PERSON` exactly once, in `Camera.Config`.** No second `Flags.isOn("FIRST_PERSON")` anywhere — not in the Hud, not in a spec, not in the boot script | two readers of one switch is two sources of truth for the same fact, and the failure is a crosshair drawn over a first-person gun | `Camera.Config` reads it; everyone else reads `Camera.isFirstPerson()` (§6.6) |
| No typed property value (`Vector3`, `CFrame`, `Color3`) in a `.model.json` or `.meta.json` | the harness fails it as "cannot compare" (`tools/studio_mcp.py` docstring, check 4; audit-002 must-fix 1 still open, `TASKS.md` row 16) | §3.6: this system puts **no file of data on disk**. Everything is code |
| No Wally package | a runtime package needs a new `$path` in `default.project.json`, which `rojo serve` does not reload — it costs Karen a Connect click — and it moves `wally.lock`/`devpackages.sha256`, which the harness pins | §7 source D: the spring's **maths** is written out in `Camera.Mode`, the precedent §7 E set |

**Three predicates, three owners, never one function.** The previous project hid the crosshair and
the weapon with one predicate. Here the questions are answered in different modules from the same
published state, and no module calls another's:

| Question | Answered by | From |
|---|---|---|
| Is the crosshair visible? | `PlayerScripts.Hud` (`Hud.crosshairVisible`) | `Weapon.get().equipped`, `Camera.getMode()`, `Camera.isFirstPerson()` |
| Is the viewmodel on screen? | `Camera.Viewmodel` | `config.FIRST_PERSON or blend > VIEWMODEL_SHOW_BLEND` |
| Is the local body hidden? | `Camera.Rig`, told by the owner | ON: there is a character. OFF: `blend > BODY_HIDE_BLEND` |
| Where is the bead? | `Weapon.Shape` / the `Assets` row, through the `Sight` attachment | the gun's own geometry |

---

## 2. Why not just use the stock camera, and why `LockFirstPerson` is not the answer either

Stated once, because everything else rests on it.

1. **The aim button is taken.** Roblox's classic camera rotates on right mouse held;
   `docs/design/shotgun.md` §5.5 binds `DrivenHunt.Weapon.Aim` to MouseButton2 and
   `src/client/Weapon/Input.luau` does it (`AIM`, `onAim`). One button cannot both orbit and aim.
2. **`Players.CameraMode = LockFirstPerson` is not our mechanism.** The creator docs say it "Locks the
   camera to first-person mode. When in this mode, all parts/elements of the player's character are
   invisible to them, **except equipped Tools**" (§7 source A). Three problems, each fatal here: it is
   written by the stock `PlayerModule`, so the moment we also want an FOV lerp there are two writers
   on one Camera; its free body-hiding is the stock camera's, not ours, and this place runs a
   `Scriptable` camera; and its one exception — **the equipped Tool stays visible** — is exactly the
   thing that must be hidden, because in first person the viewmodel *is* the gun and two shotguns on
   screen is a defect this repo has already paid for once (audit-003 F1 / audit-004 must-fix 2,
   `tests/client/camera_client.spec.luau`, "the hidden local body").
3. So: **the stock camera module is disabled, the stock control (movement) module is kept.** The
   movement module *reads* the camera to compute camera-relative WASD, which stays correct under a
   `Scriptable` camera. We borrow the part that works and replace only the part whose input we need.

What replaces it is borrowed too (§7): the documented Scriptable-camera loop (A + C), the
DevForum viewmodel and **AimPart** pattern (D, I), the sway shape (J), the spring maths (K), and this
repo's own owner / pure-core / instance-writer split (H). **Nothing is invented** except the tagged
cursor-request API (v2's one invention, unchanged) and the exact composition order of §5.2's
`viewmodelOffset`, which is arithmetic, not a system.

---

## 3. Ownership

Rule 3: exactly one writer per system, named here and mirrored into `GAME_DESIGN.md` (§11).
**This task adds no owner and no module.** Brief §2.1 asks for each new motion to be assigned; every
one of them is `Camera.Mode` deciding and `Camera.Rig`/`Camera.Viewmodel` writing:

| Thing | Decided by (pure) | Written by | Not a new module because |
|---|---|---|---|
| The first-person eye pose | `Camera.Mode.cameraCFrame` | `Camera.Rig.apply` | first person is `distance = 0` at eye height in the maths that already returns a distance |
| The carry ↔ ADS blend | `Camera.Mode.step` (`state.blend`) | — | there is already exactly one blend; a second would be two notions of "aimed" |
| The geometric ADS pose | `Camera.Mode.aimOffset(sightLocal, config)` | `Camera.Viewmodel.update` | it is one CFrame identity (§5.2) |
| Sway | `Camera.Mode.step` (`state.swayDeg`) | `Camera.Viewmodel` | its input is `lookDelta`, which `Mode.step` already consumes |
| Walk bob | `Camera.Mode.step` (`state.bobPhase`, `state.bobStuds`) | `Camera.Viewmodel` | one phase accumulator in the state the reducer already returns |
| Recoil on the **drawn gun** | `Camera.Mode.step` (`recoilGun*`) | `Camera.Viewmodel` | cosmetic, and cosmetics in front of the camera are the Viewmodel's |
| Recoil on the **camera** | `Camera.Mode.step` (`recoilCamPitchDeg`), added in `cameraCFrame` | `Camera.Rig.apply` | it must go through the one aim truth (§6.7), so it cannot live anywhere else |
| The arms and hands | — (static, posed from two gun attachments) | `Camera.Viewmodel` | they are drawn in front of the camera, which is one owner's job |
| The break-open reload motion | `Camera.Mode.step` (`state.openTilt`) | `Camera.Viewmodel` | the reload **state** is the weapon's (`open`, `busyFor`); only the *motion* is ours |
| The `Sight` attachment | `Weapon.Shape.sight` / the `Assets` row | `Weapon.Hardware` | the gun's geometry belongs to the gun's owner (§6.5) |

### 3.1 The one camera owner

**`Players.LocalPlayer.PlayerScripts.Camera`** — disk `src/client/Camera/init.luau`, booted once by
`src/client/CameraBoot.client.luau`.

Sole writer of: the camera **mode state** (`Mode.State`), the `Changed` signal, the one
`BindToRenderStep` binding (`Config.RENDER_STEP_NAME = "DrivenHunt.Camera"`), the one
`UserInputService.InputChanged` connection that reads mouse delta, the pending kick counter, and the
`LookAtRequest` `BindableFunction`. It is a **ModuleScript** and **nothing happens on `require`** —
only `Camera.start()` begins production.

Its private modules, each the sole writer or owner of exactly one thing:

| Module | Is | Never |
|---|---|---|
| `Config.luau` | the frozen numbers, **and the one `Flags.isOn("FIRST_PERSON")` read** (§6.6). No writer | holds logic |
| `Mode.luau` | **pure**: the reducer and every piece of camera and viewmodel maths. `(state, input, dt, config) -> state`, plus `cameraCFrame`, `viewmodelOffset`, `aimOffset`, `ease`, `sensitivityScale`, `anglesToward`, `spring` | touches Instances, services, clocks, `Players` |
| `Rig.luau` | **the only writer of `workspace.CurrentCamera`** and of `LocalTransparencyModifier` on the local character. Disables the stock cameras. Does the occlusion cast (OFF branch only) | holds mode state, reads input, touches the cursor or the Hud |
| `Cursor.luau` | **the only writer of the mouse**. **Unchanged by this task** | touches the camera, the viewmodel or anything drawn |
| `Viewmodel.luau` | **the only writer of every Instance under `workspace.CurrentCamera`**: the gun clone, and from §14 S3 the arm clones | writes the camera, writes the real Tool, decides a hit, or invents a sight |

### 3.2 The viewmodel owner

`Camera.Viewmodel`. It **clones** the local player's Tool `Handle` and never modifies the original;
`ServerScriptService.Weapon.Hardware` stays the only writer of `Tool` Instances. In the ON branch the
clone is parented to `workspace.CurrentCamera` **all the time a handle exists**, not only while
aiming; in the OFF branch v2's rule stands (unparented below `VIEWMODEL_SHOW_BLEND`).

Everything that already makes the clone correct stays, and each line of it was paid for once:
`CanQuery = false` on every part (`workspace.CurrentCamera` is a child of Workspace, so a client
raycast — including this system's own occlusion cast — can hit it); `Anchored = true` (nothing under
the camera may be simulated); the welded **pieces come with it** (Task 71: the `Handle` is an
invisible envelope and the side-by-side is its children); and a `SurfaceAppearance`, `Texture`,
`Decal` or `Attachment` **survives the strip** (Task 74: the uploaded gun's PBR maps, and — new in
this design — the `Sight` attachment the ADS pose is computed from). The clone is rebuilt when the
source part changes identity **or its children change** (Task 76: `Hardware.upgrade` swaps the parts
fallback for the mesh on a live Handle).

**Three additions, all inside this module:**

1. `Viewmodel.sight(): CFrame?` — the clone's `Sight` attachment CFrame, in the clone's own frame,
   cached with the clone and re-read on every rebuild. `nil` when the gun carries none.
2. `Viewmodel.stats().sightMissing` — how many frames posed a gun with no `Sight`. Asserted `0` for a
   real gun in §9.2. **The loud path for "the bead is not the sight"**: with no `Sight` the ADS pose
   falls back to `VIEWMODEL_AIM_OFFSET` and the bead is wherever it happens to be, so this counter is
   the difference between an honest sight picture and a plausible one.
3. The arm clones (S3), children of the gun clone, so **one `PivotTo` still poses everything**.

### 3.3 The cursor / mouse-lock owner — unchanged

`Camera.Cursor`, with the tagged request API v2 designed and `src/client/Camera/Cursor.luau`
implements:

```luau
Cursor.requestFree(tag: string): ()   -- "I need a visible, free cursor" (a menu, a spec)
Cursor.release(tag: string): ()
Cursor.isFree(): boolean
Cursor.apply(): ()                    -- once per frame, from the owner; writes only on a difference
Cursor.stats(): { reasserts: number, tags: { string } }
```

First person changes nothing here: MouseButton2 is still the aim button, so the mouse is still locked
whenever no tag is outstanding. A caller states a *need*; the Cursor performs the single write and
counts every difference it did not cause (`reasserts`, asserted zero in §9.2).

### 3.4 The aim state: who writes, who reads

| | |
|---|---|
| **Writer** | `PlayerScripts.Weapon.Input`, through `DrivenHunt.Weapon.Aim` and `Input.AimChanged` |
| **Readers** | `PlayerScripts.Camera`, through the injected source (§4.4), and nothing else |
| **Truth vs request** | `Input.isAiming()` is the **request**. `Camera.getMode()`/`getBlend()` is the **state**. Anything asking "is the view in aim" reads the camera |

### 3.5 Files on disk

```
src/client/
  CameraBoot.client.luau   -> PlayerScripts.CameraBoot     (LocalScript, the composition root)
  Camera/
    init.luau              -> PlayerScripts.Camera         (THE OWNER)
    Config.luau            -> PlayerScripts.Camera.Config  (frozen numbers + the one flag read)
    Mode.luau              -> PlayerScripts.Camera.Mode    (pure)
    Rig.luau               -> PlayerScripts.Camera.Rig     (the only writer of CurrentCamera)
    Cursor.luau            -> PlayerScripts.Camera.Cursor  (the only writer of the mouse)
    Viewmodel.luau         -> PlayerScripts.Camera.Viewmodel
tests/server/camera_mode.spec.luau      (the pure module, both branches by parameter)
tests/client/camera_client.spec.luau    (the real camera in the real client, both branches)
tests/client/input_scenarios.txt        (unchanged: `aim-hold` already exists)
```

**Files outside this system that change, each inside its own owner, creating no second writer:**

| File | Owner | The change | Step |
|---|---|---|---|
| `src/shared/Flags/init.luau` | nobody at run time | one `FIRST_PERSON` row | S1 |
| `src/client/Hud/init.luau` | the Hud | `Hud.crosshairVisible(state, aiming, firstPerson)` made a pure public predicate, `render` calls it, and it answers `false` in first person | S1 |
| `src/server/Weapon/Shape.luau` | the weapon | `Shape.beadOffset(config)` extracted, used by the `Bead` piece **and** by the new `Shape.sight(config)` | S2 |
| `src/server/Weapon/Hardware.luau` | the weapon | creates the `Sight` attachment beside `Muzzle`, in `build` and in `upgrade` | S2 |
| `src/serverstorage/Assets/init.luau` | the manifest (no run-time writer) | `AssetRow.sightOffsetStuds: Vector3?` | S2 |
| `src/client/Weapon/init.luau` | the weapon | `Weapon.Fired`, one signal derived from its own replica (§6.7) | S4 |

No Rojo container changes, no `default.project.json` change, so no Connect click is owed.

### 3.6 No data on disk

No `.model.json`, no `.meta.json`, no `.rbxm` (banned). Every number in §8 is a Luau value in
`Camera.Config`, because many are `Vector3`/`CFrame` and the harness fails a typed JSON value as
"cannot compare". `Config` stays **flat** — scalars, `Vector3`s, `CFrame`s, **no nested tables** —
because `table.freeze` is shallow (Task 23a note (b)). §9.1 asserts a write errors.

A spec drives the other branch with `table.clone(Config)` plus one field: `table.clone` of a frozen
table returns an **unfrozen** copy, which `Flags.resolve`'s own comment already relies on.

### 3.7 A naming rule, because two things are called "camera"

`workspace.CurrentCamera` is touched by exactly one file, `Rig.luau`, where it is the local `cam`.
Every other file's `Camera` is this system's module. No file contains both meanings.

---

## 4. The state machine

### 4.1 States — four, unchanged

| Mode | When | ON branch | OFF branch |
|---|---|---|---|
| `Loading` | no character, or no `HumanoidRootPart` yet | holds the last CFrame, FOV `FOV_THIRD_DEG`, no error, no spam | same |
| `Third` | alive, not aiming | **the low carry**: eye at the pivot, gun low-left, blend decaying to 0 | over-the-shoulder orbit at `THIRD_DISTANCE_STUDS` |
| `Aiming` | alive and the aim source says yes | blend rising to 1: FOV to `FOV_AIM_DEG`, the gun to the bead | camera to the eye, viewmodel shown, body hidden |
| `Dead` | `Humanoid.Died` fired for the current character | blend forced to 0 at the normal rate, the viewmodel cleared **immediately**, the camera holds its last CFrame, the body **stays hidden** (§4.6). No orbit, no input | body shown, camera holds |

**The name `Third` reads wrong in first person and it is kept anyway.** It means "not aiming". The
alternative — a fifth name `Carry` — would rewrite `Mode.ModeName`, every `modeHistory` assertion,
`camera_client.spec`'s `expect(Camera.getMode()).to.equal("Third")` and the harness's staging, for no
behavioural gain, because `blend` already distinguishes carry from aim. Said once, here, so nobody
re-opens it.

`blend` is a single number in `[0, 1]` and is the only thing that transitions between the two poses.

### 4.2 Transitions — unchanged

| From | Event | To |
|---|---|---|
| `Loading` | `CharacterAdded` and `HumanoidRootPart` present and `Health > 0` | `Third`, `blend = 0`, `pitch = SPAWN_PITCH_DEG`, **yaw kept** |
| `Third` | aim source true | `Aiming` |
| `Aiming` | aim source false | `Third` |
| `Third` / `Aiming` | `Humanoid.Died` | `Dead` |
| any | `CharacterRemoving` or the root part gone | `Loading` |
| `Dead` | new `CharacterAdded` | `Third` |

A tool taken away *during* a held aim is closed in the adapter, not in the camera (§4.4):
`isAiming()` is "holding the aim button **and** the replicated state says equipped".

### 4.3 The frame

One binding,
`RunService:BindToRenderStep("DrivenHunt.Camera", Enum.RenderPriority.Camera.Value, update)`.
The prefix `DrivenHunt.Camera.*` is reserved to this system.

```
update(dt):
  1. read: character/humanoid/root (may be nil); aiming, open from the injected source;
           speed = horizontal |root.AssemblyLinearVelocity|; kicks = pending; nothing else
  2. state = Mode.step(state, { aiming, alive, hasCharacter, lookDelta, speed, open, kicks },
                       dt, CONFIG)                                   -- pure
  3. lookDelta := Vector2.zero ; pending := 0                        -- each consumed exactly once
  4. if mode ~= lastMode then push history, count aimEnters/aimExits, fire Changed(mode, blend) end
  5. if mode == "Dead" then Viewmodel.clear()
     else
       pivot, desired, fov = Mode.cameraCFrame(rootCFrame, state, CONFIG)   -- pure; includes recoil
       position = if CONFIG.FIRST_PERSON then desired.Position
                  else Rig.occlude(pivot, desired.Position, CONFIG)         -- OFF: one raycast
       applied = CFrame.lookAt(position, position + desired.LookVector)
       Rig.apply(applied, fov)                          -- the only camera write in the game
       settle the pendingLookAt against `applied` (Task 50)
       Viewmodel.update(applied, state, CONFIG)         -- parents, poses, never rebuilds per frame
     end
  6. Rig.setLocalBodyHidden(CONFIG.FIRST_PERSON and state.mode ~= "Loading"
                            or state.blend > CONFIG.BODY_HIDE_BLEND)   -- see 4.6
  7. Cursor.apply()                                    -- writes only on a difference
```

**`Viewmodel.update` takes the whole `state`** from S1 on, not `(camCFrame, blend, config)`: sway,
bob, recoil and the open tilt all live in the state and all land in one offset. The change is
mechanical and the two existing spec cases that call `Viewmodel.update(CFrame.new(0,10,0), 1, Config)`
directly (Tasks 74 and 76) move to a state literal built from `Mode.initial(Config)`.

Mouse delta still arrives on `UserInputService.InputChanged` (`MouseMovement` only), accumulated
between frames; `ContextActionService` cannot bind movement (`tests/client/input_driving.spec.luau`
learned this in Task 6).

**In the ON branch there is no raycast at all**, which is a saving and also a removal of a trap:
`Rig.occlude` would be a no-op anyway (the desired position is `AIM_PIVOT_FORWARD_STUDS = 0.4` studs
from the pivot, and `pulled = max(1.2, …) >= 0.4` returns `desired` untouched), so a cast per frame
would be a cost with no effect and a spec asserting "one cast per frame" would be asserting nothing.

### 4.4 The weapon source is injected, and the adapter lives in the boot script

```luau
export type AimSource = {
    isAiming: () -> boolean,
    isOpen: (() -> boolean)?,    -- the break action is open: the snapshot's `open`   (S4)
}
Camera.setAimSource(source: AimSource?): ()   -- nil = the camera can never aim
Camera.getAimSource(): AimSource?             -- so a spec can put the production one back
```

**The name and the shape of `setAimSource`/`getAimSource` do not change** (brief §2.9): the new field
is optional, so `src/client/CameraBoot.client.luau`'s existing adapter and
`camera_client.spec`'s fake both keep compiling, and a spec can install a partial fake.

`CameraBoot` stays the only place that knows both systems — the idiom `BoarBoot` established:

```luau
local Camera = require(scripts:WaitForChild("Camera"))
local weaponModule = scripts:FindFirstChild("Weapon")
if weaponModule then
    local Weapon = require(weaponModule)
    Camera.setAimSource({
        isAiming = function()
            local state = Weapon.get()
            return Weapon.Input.isAiming() and state ~= nil and state.equipped
        end,
        isOpen = function()
            local state = Weapon.get()
            return state ~= nil and state.open
        end,
    })
    Camera.Viewmodel.setSource(function(): BasePart? ... end)   -- unchanged
    Weapon.Fired:Connect(Camera.kick)                            -- S4 only (§6.7)
end
Camera.start()
```

Three things follow: neither owner requires the other; the camera builds, boots and tests **with no
weapon in the place at all**; and a spec installs a fake and drives the whole aim path with no input
and no gun.

### 4.5 The cosmetic fields, and why they are in the one frozen state

`Mode.State` gains ten fields (§5.2). They are in the **same reducer** as `blend` and `yawDeg` for one
reason: a second module holding "how much sway is there" is a second writer of the picture, and the
previous project's worst bugs were "two correct pieces of code disagreeing". Being in the state also
makes every one of them provable in a **server** spec at 10,000 steps, with no client
(`tests/server/camera_mode.spec.luau`, the method `boar_brain.spec` established).

**Every cosmetic term has an exact rest, and that is a requirement, not a nicety.** Sway returns
linearly to **exactly 0** over `SWAY_RETURN_SECONDS`; bob is **exactly** zero below `BOB_MIN_SPEED`;
the recoil springs are snapped to exactly 0 once `|offset| < RECOIL_REST_DEG` and
`|rate| < RECOIL_REST_RATE`; `openTilt` reaches exactly 0 and exactly 1. Without exact rests, "the
bead is on the axis in ADS steady state" (§9.2, the one testable number) would be a threshold
question about catching a spring at a good moment. v2 rejected an asymptote for the blend for the same
reason (§7 source F); this applies the same rule to every new term.

### 4.6 Death in first person, decided

In the ON branch the local body **stays hidden** while `Dead` and the camera holds its last
first-person CFrame: the player sees the world from where they died, with no body drawn. v2 showed the
body on death, which was right for a camera 12 studs behind the character and is wrong for one inside
the head — it would draw the inside of a neck across the whole screen. A real death camera (a pull-back,
a killcam) is **not in this work**: §12 Director item B, default as written here.

---

## 5. Public interface

Types are exported from `PlayerScripts.Camera`. `luau-lsp` is pinned but not in CI (`TASKS.md` row 3),
so annotations are documentation plus editor checking, not a gate.

### 5.1 The owner

```luau
export type ModeName = "Loading" | "Third" | "Aiming" | "Dead"

Camera.start(): ()                     -- once; errors if called twice
Camera.stop(): ()                      -- unbind, restore the stock camera, free the cursor, clear the viewmodel
Camera.getMode(): ModeName
Camera.getBlend(): number
Camera.getState(): Mode.State          -- frozen
Camera.modeHistory(): { string }
Camera.isFirstPerson(): boolean        -- NEW. `Config.FIRST_PERSON`, republished so nothing else reads the flag
Camera.kick(strength: number?): ()     -- NEW (S4). A REQUEST: +1 pending kick, consumed by the next frame
Camera.lookAt(point: Vector3): boolean -- unchanged (the harness's staging, and shoot_boar.spec)
Camera.Changed: RBXScriptSignal        -- (mode, blend). MODE CHANGE ONLY
Camera.setAimSource(source: AimSource?) ; Camera.getAimSource(): AimSource?
Camera.acquired(): (boolean, string?)
Camera.stats(): Stats                  -- frozen copy
Camera.Mode, Camera.Config, Camera.Rig, Camera.Cursor, Camera.Viewmodel   -- exported for specs only
```

`Stats` keeps every v2 field (`frames`, `foreignCameraWrites`, `cursorReasserts`,
`maxDistanceFromRoot`, `maxUpdateMs`, `avgUpdateMs`, `totalUpdateMs`, `viewmodelParented`,
`aimEnters`, `aimExits`, `lookAtRequests`, `lookAtLanded`) and adds `kicks: number` (how many kicks
the reducer has consumed) and `sightMissing: number` (from `Viewmodel`).

**`Camera.kick` is a request, not a write**, exactly as `Cursor.requestFree` is: the owner still does
all the deciding, in the reducer, on the next frame. Two barrels `BARREL_DELAY = 0.25` s apart are two
kicks, and `kicks` is a **count** consumed once per frame, so two shots in one frame cannot be lost.

**There are no remotes.** The camera is not replicated, so a server half would be a second truth about
something the server cannot see.

### 5.2 The pure core — `Camera.Mode`

```luau
export type State = {             -- frozen; returned by Mode.step, held by init.luau
    mode: ModeName,
    blend: number,                -- 0 = carry / third person, 1 = fully aimed
    yawDeg: number,               -- world yaw, wrapped to (-180, 180]
    pitchDeg: number,             -- clamped to [PITCH_MIN_DEG, PITCH_MAX_DEG]
    sinceModeChange: number,
    -- NEW, all cosmetic, all with exact rests (§4.5)
    swayDeg: Vector2,             -- the gun's lag on screen, degrees, |x|,|y| <= SWAY_MAX_DEG
    bobPhase: number,             -- radians, wrapped to [0, 2*pi)
    bobStuds: Vector3,            -- camera-space bob displacement
    recoilGunPitchDeg: number, recoilGunPitchRate: number,
    recoilGunBackStuds: number, recoilGunBackRate: number,
    recoilCamPitchDeg: number, recoilCamPitchRate: number,   -- rest is EXACTLY 0: no permanent kick
    openTilt: number,             -- 0..1, the break-open blend
}

export type StepInput = {
    aiming: boolean, alive: boolean, hasCharacter: boolean,
    lookDelta: Vector2,           -- pixels since the last frame
    speed: number,                -- NEW: horizontal studs/s
    open: boolean,                -- NEW: the break action is open
    kicks: number,                -- NEW: shots since the last step
}

Mode.initial(config): State
Mode.step(state, input, dt, config): State            -- a NEW frozen state
Mode.ease(t): number                                  -- 1 - (1-t)^2, Quad/Out, no TweenService
Mode.sensitivityScale(fovDeg, config): number         -- THE ONE conversion site (§8.1)
Mode.fovFor(blend, config): number
Mode.cameraCFrame(rootCFrame, state, config): (Vector3, CFrame, number)   -- pivot, desired, fovDeg
Mode.anglesToward(state, rootCFrame, point, config): State                -- unchanged
Mode.carryOffset(config): CFrame                      -- NEW: position + three named degrees, ONE conversion
Mode.aimOffset(sightLocal: CFrame?, config): CFrame   -- NEW: the geometric ADS pose
Mode.viewmodelOffset(state, sightLocal: CFrame?, config): CFrame          -- NEW signature
Mode.spring(offset, rate, dt, speed, damper, restOffset, restRate): (number, number)   -- NEW
```

Every one is a pure function of its arguments: no `game:GetService`, no clock, no `Players`, no
`Instance`. `dt`, `lookDelta`, `speed`, `sightLocal` and `config` are parameters. That is what lets
all of it run in a **server** spec with no client at all, and it is also what satisfies
`docs/design/feature-flags.md` §13.3 **for free**: both branches are reachable by passing a config
table, with no flag flip and no live override.

**`Mode.aimOffset` is the whole of geometric ADS, and it is one line of algebra.** In ADS the clone's
`Sight` must sit on the camera's axis, `EYE_RELIEF_STUDS` in front of the eye, pointing where the
camera points. The Model's pivot is the cloned `Handle`
(`Viewmodel.build` sets `PrimaryPart = clone`), so with `sightLocal` the attachment's CFrame in the
Handle's frame:

```
handleWanted = camCFrame * CFrame.new(0, 0, -EYE_RELIEF_STUDS) * sightLocal:Inverse()
=> aimOffset(sightLocal) = CFrame.new(0, 0, -EYE_RELIEF_STUDS) * sightLocal:Inverse()
   aimOffset(nil)        = VIEWMODEL_AIM_OFFSET        -- the legacy fallback, counted as sightMissing
```

**The composition order, written out once because order is the bug:**

```
viewmodelOffset(state, sightLocal, config) =
      CFrame.new(bobStuds) * CFrame.Angles(rad(swayDeg.Y), rad(swayDeg.X), 0)   -- camera space: moves the gun ON SCREEN
    * carryOffset(config):Lerp(aimOffset(sightLocal, config), ease(blend))      -- the pose
    * CFrame.new(0, 0, recoilGunBackStuds)                                      -- gun space: straight back (+Z is away from the muzzle)
    * CFrame.Angles(rad(recoilGunPitchDeg + openTilt * OPEN_TILT_DEG), 0, 0)    -- gun space: the muzzle rises, the action breaks
```

Sway and bob **pre**-multiply, so they move the gun across the frame; recoil and the tilt
**post**-multiply, so the gun rotates about its own grip. Sway is scaled toward `SWAY_AIM_SCALE` and
bob toward `BOB_AIM_SCALE` by the eased blend, so nothing snaps at a threshold.

**The invariant §9 rests on:** with no look input for `SWAY_RETURN_SECONDS`, `speed < BOB_MIN_SPEED`,
recoil at rest and `open == false`, all four extra terms are **exactly identity**, so
`viewmodelOffset(restState, sight, config) == aimOffset(sight, config)` exactly at `blend == 1`.

**The spring, from source K's maths, written out (no dependency):**

```
-- x'' = -(speed^2)(x - 0) - 2*damper*speed*x'   , semi-implicit Euler
rate  += (-(speed*speed) * offset - 2*damper*speed*rate) * h
offset += rate * h
```
with `h` sub-stepped at `SPRING_MAX_STEP_SECONDS = 0.05` (`math.ceil(dt/h)` passes) so a frame hitch
cannot make an explicit integrator diverge — at `speed = 15` the explicit bound is `h < 2/15 = 0.133`,
so 0.05 has a 2.7× margin — and snapped to exact rest per §4.5.

### 5.3 The rig

```luau
Rig.acquire(): (boolean, string?)   -- CameraType = Scriptable; disables the stock cameras if present. NEVER YIELDS
Rig.stockCamerasDisabled(): boolean
Rig.release(): ()
Rig.apply(cf: CFrame, fovDeg: number): ()          -- the ONLY assignment to CurrentCamera in the repo
Rig.setLocalBodyHidden(hidden: boolean): ()        -- LocalTransparencyModifier, local character only
Rig.hiddenPartCount(): number
Rig.occlude(pivot, desired, config): Vector3       -- OFF branch only from S1 on
Rig.setCast(cast: ((Vector3, Vector3) -> Vector3?)?): ()
Rig.stats(): { foreignCameraWrites: number, lastApplied: CFrame? }
```

Nothing in `Rig` changes in this task except **who calls `occlude`**. Everything it already carries
stays and each line was paid for: `acquire` takes the camera **first** and never yields (round 2
finding 1: a `WaitForChild("PlayerModule", 10)` before setting `CameraType` cost ten seconds on every
boot and respawn in a place that has no `PlayerModule`); it re-runs on `CharacterAdded` because the
engine restores `CameraType`; and the hidden-body cache **follows the character** through
`DescendantAdded`/`DescendantRemoving`, because the Tool's `Handle` is granted on `CharacterAdded`
server-side and arrives *after* the first render step (audit-003 F1 / audit-004 must-fix 2 — the
two-shotguns defect), and a part that **leaves** while hidden is restored first (Task 47 review round
1 — unequipping mid-aim otherwise left the player's own gun invisible for the rest of the life).

**In the ON branch `setLocalBodyHidden(true)` is on almost permanently**, which makes both of those
paths hotter, not colder: every accessory, every layered-clothing part and every Tool that arrives
during a life must be hidden as it arrives. The existing tests for them (§9.2) become load-bearing
for the whole game rather than for ADS alone.

### 5.4 The cursor — unchanged

Default, whenever no tag is outstanding: `MouseBehavior = LockCenter`, `MouseIconEnabled = false`,
`MouseDeltaSensitivity` left at the engine default (the aim sensitivity change is done in our own
maths, §8.1, so the engine property is owned but never written; a non-default value is a `reassert`).

### 5.5 The viewmodel

```luau
Viewmodel.setSource(source: (() -> BasePart?)?): ()   -- returns the Handle to clone; nil = none
Viewmodel.getSource(): (() -> BasePart?)?             -- so a spec can put the LIVE one back
Viewmodel.update(camCFrame: CFrame, state: Mode.State, config): ()    -- NEW signature
Viewmodel.clear(): ()
Viewmodel.current(): Model?                           -- nil unless it is really in the camera
Viewmodel.isParented(): boolean
Viewmodel.sight(): CFrame?                            -- NEW
Viewmodel.stats(): { sightMissing: number, rebuilds: number, parts: number }   -- NEW
```

The source is asked four times a second, not per frame (the pose is what must be per frame, and it is
one `PivotTo`). Every cloned part: `Anchored`, `CanCollide = false`, `CanQuery = false`,
`CanTouch = false`, `Massless`, `CastShadow = false`, and nothing that is not a shape, a
`SurfaceAppearance`, a `Texture`, a `Decal` or an **`Attachment`** survives.

**The pivot assumption is pinned, not trusted.** `aimOffset` assumes `model:GetPivot() == clone.CFrame`
(true because `PrimaryPart` is set and `WorldPivot` is never written). §9.2 asserts
`(model:GetPivot().Position - clone.Position).Magnitude < 1e-3` after a `PivotTo`, so an engine default
this design leans on is a test and not a hope.

**The arms (S3).** Route (a) of the note §5.3: clone the local character's own arm parts, so the
player's skin tone and clothing come for free. Concretely, and deliberately small: the **hands and
lower arms only** — R15 `LeftHand`/`LeftLowerArm` and `RightHand`/`RightLowerArm`, R6 `Left Arm`/
`Right Arm`, chosen from `Humanoid.RigType` — each posed as a **rigid** piece at a gun attachment, the
left at `ForeHold` (the forend) and the right at `GripHold` (the grip), both children of the gun clone
so one `PivotTo` still poses everything. **No IK, no rig, no animation system** (brief §3): at
`EYE_RELIEF_STUDS` the elbows are out of frame, so there is nothing for a second bone to do. The
upgrade — a rigged arms model with real animations — is a later asset task and is named as such.

Two risks, both named rather than discovered: a cloned part whose texture has not loaded is grey
("purple untextured legs"), and a player wearing **layered clothing** has that clothing on a
`WrapLayer` over the body parts, so a bare `LeftLowerArm` clone may come out unclothed. Both are
screenshot findings, which is why S3 is its own step with its own screenshot on **Karen's own avatar**,
and the fallback (two plain parts coloured from the character's `BodyColors`) is named in §12.

---

## 6. Seams with other systems

### 6.1 The weapon — the aim flag and the fire origin

| Direction | Mechanism | Owner of the other end |
|---|---|---|
| Weapon → camera | `Input.isAiming()` and the snapshot's `open`, via the adapter in `CameraBoot` | `PlayerScripts.Weapon.Input`, `PlayerScripts.Weapon` |
| Weapon → camera (S4) | `Weapon.Fired` → `Camera.kick()` | `PlayerScripts.Weapon` (§6.7) |
| Camera → weapon | **nothing.** The weapon reads `workspace.CurrentCamera.CFrame` itself when it fires | `Weapon.Input.onFire`, unchanged |

**First person makes the fire path more honest, not less, and it retires two mitigations without
deleting them.** The server validates `origin` within `CAMERA_ORIGIN_TOLERANCE = 30` studs of
`HumanoidRootPart`, casts the camera ray for an aim point, then casts the pellets from the **muzzle**
toward it (`docs/design/shotgun.md` §5.5 steps 2–8), with the shooter's character in the ignore list
so the camera ray cannot resolve onto the shooter's own back (that ignore list is defect (a) of Task
23a, fixed).

- **ON branch:** the camera is `AIM_PIVOT_FORWARD_STUDS = 0.4` studs from the pivot, ≈1.65 from the
  root, and the muzzle is within about a stud of the origin. The 30-stud tolerance and the ignore
  list stop mattering — **they are kept, because they still matter to the OFF branch, and because a
  guard that costs nothing and catches the Task 19 defect 4 class of bug stays.**
- **OFF branch:** unchanged. `MAX_DISTANCE_STUDS = 14.5` is a hard clamp in `Mode.cameraCFrame`, so
  the origin is at most 14.5 studs from the root — inside 30 with 15 studs of headroom.
  `Camera.stats().maxDistanceFromRoot` records the session maximum and **both** specs assert it in
  **both** branches.

### 6.2 The Hud — no crosshair in first person

The Hud owns everything drawn. This design specifies the **read**, never the drawing:

```luau
-- PlayerScripts.Hud, this task's one change outside the camera system
function Hud.crosshairVisible(state, aiming: boolean, firstPerson: boolean): boolean
    return Shotgun.CONFIG.CROSSHAIR_ENABLED and state ~= nil and state.equipped
        and not aiming and not firstPerson
end
-- render() calls it with Camera.getMode() == "Aiming" and Camera.isFirstPerson()
```

Three points:

1. **`firstPerson` comes from `Camera.isFirstPerson()`, not from a second `Flags.isOn` call.** The
   camera owns the switch and republishes it as a fact about the view; the Hud decides the drawing.
   One writer of the crosshair, one source for the fact.
2. **It is a pure public predicate** so a client spec can assert all eight combinations without
   flipping a flag — the same reason `Hud.renderScore` and `Hud.onHitMarker` are public.
3. The **hit marker** is a sibling of the crosshair and is unaffected: it must still show in first
   person, which is why it was never a child of the crosshair frame (`Hud.build`, and
   `docs/design/drive.md`).

The Hud reads `Camera`; the camera has no reference to the Hud and does not know it exists.

### 6.3 The stock `PlayerModule`

| | |
|---|---|
| **Cameras** | disabled by `Rig.acquire` via `require(PlayerScripts.PlayerModule):GetCameras():Disable()` **if one is present**. **Measured 2026-09-25: this place has none** — `PlayerScripts` during Play holds only our modules plus `RbxCharacterSounds` — so `acquire` returns `true` with a reason saying so, and watches for one arriving later |
| **Controls** | **kept**, untouched. Movement, jumping and mobile/gamepad locomotion stay Roblox's |
| **Risk** | `GetCameras()` is thinly documented and Roblox-controlled, and it is silent on failure |
| **Mitigation** | `acquire` reports which case it hit, verbatim; and the foreign-write detector (§10.1) catches the silent case |

### 6.4 The character — not this system's, and the consequence changes shape in first person

The camera never rotates the character. In the OFF branch a player aiming sideways is, to **other**
players, a character facing wherever the movement code left them. In the **ON** branch that is worse,
not better: the whole game is now played down the gun, so a shooter who never turns their body is
visible to everybody else for ten minutes, and the drive line's safety rule (`Weapon.SafetyArc`) is
about where the **shot** goes, which is still correct. Fixing it means writing `Humanoid.AutoRotate`
and the root CFrame, which needs a **character/movement owner** that does not exist. §12 Director
item A, and first person raises its priority.

### 6.5 The `Sight` attachment — the one new cross-system seam

**`Weapon.Hardware` creates it, beside the `Muzzle` attachment it already creates for exactly this
reason.** The value is per variant, and the variants differ in kind:

| Variant | Where the value comes from | Why there |
|---|---|---|
| The parts gun (`Weapon.Shape.pieces`) | **`Weapon.Shape.sight(config)`**, returning `CFrame.new(Shape.beadOffset(config))` — the *same* pure expression that places the `Bead` piece | the bead and the sight cannot disagree, because there is one expression. `Shape.beadOffset` is extracted in S2 and both call it |
| Karen's upload (**exactly one MeshPart**, `Assets`) | **the `Assets` row**: a new optional field `sightOffsetStuds: Vector3?`, in the `Handle`'s frame, so it is directly comparable with `MUZZLE_OFFSET` | the manifest is already the one home for per-upload measured geometry (`sizeStuds`, `naturalSizeStuds`, `offsetStuds`, `rotationDeg`), rows are **appended and versioned, never edited**, and a new mesh is a new row with a new measurement. Putting it in `Shotgun.CONFIG` would make one number describe two different meshes |
| Neither / an old Handle | **`Shape.sight(config)`**, and `Hardware` warns **once** | the fallback is a guess about somebody else's mesh, so it is loud. `Viewmodel.stats().sightMissing` is the client-side twin |

`Hardware` already receives the row on the mesh path (`addMesh` reads `report.row` for `sizeStuds`,
`rotationDeg`, `offsetStuds`), so no new plumbing is needed; and `upgrade` must write the `Sight` too,
because a gun handed out before the mesh loaded is upgraded in place.

Today's parts-gun numbers, so the first value is not invented at build time:
`BARREL_Y = 0.12`, barrel radius `0.085`, `RIB_THICK = 0.03` ⇒ `ribY = 0.22`; the `Bead` piece sits at
`(0, ribY + RIB_THICK/2 + 0.02, muzzleZ + 0.05)` = **`(0, 0.255, -2.15)`** in the `Handle`'s frame,
with the rib level, so the sight's rotation is **identity** — an identity CFrame's `LookVector` is
`(0, 0, -1)`, which is already the muzzle direction (`GRIP`'s convention). The bead therefore sits
`0.255 - 0.12 = 0.135` studs above the bore, so aligning the bead with the view axis puts the barrels
`atan(0.135 / 5.6) = 1.4°` below centre — which is what a real bead sight picture looks like, and it
is a consequence of the geometry rather than a number anybody chose.

**Who measures the mesh's value, and when:** the S2 task, by screenshot iteration in ADS, recorded in
the row with the date and the method, exactly as `rotationDeg = (0, 90, 0)` was found ("only a
screenshot checks this", and the gun pointed backwards on the first look). Until it is measured the
field is `nil`, the fallback applies and the warning fires. §12 Director item C.

### 6.6 The flag

One row in `src/shared/Flags/init.luau`:

```luau
FIRST_PERSON = {
    default = false,
    owner = "StarterPlayerScripts.Camera",
    born = "2026-09-27 task 88 (the design); first code in the S1 task",
    expires = "2026-10-18",     -- 21 days (docs/design/feature-flags.md section 12)
    why = "The whole game is first person: the gun is carried low-left and aimed down the rib at the "
        .. "bead, with no crosshair. OFF is the accepted over-the-shoulder third person with ADS.",
} :: FlagRow,
```

**The one boundary read, and the only permitted shape** (`CLAUDE.md`, "Feature flags"):

```luau
-- src/client/Camera/Config.luau
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
...
FIRST_PERSON = Flags.isOn("FIRST_PERSON"),
```

Read once, at the boundary, passed inward as `config` — and because `Mode.step`,
`Mode.cameraCFrame`, `Mode.viewmodelOffset` and `Viewmodel.update` **already take `config`**,
§13.3's "reachable by parameter as well as by flag" costs nothing: a spec passes
`table.clone(Config)` with `FIRST_PERSON = true`.

Four consequences, named:

1. **`Camera.Config` is the first client production module in the repo to read `Flags`** (grep: no
   `Flags` in `src/client/` today). `Flags`' client resolution reads the replicated
   `ReplicatedStorage.Flags.State` attributes synchronously when `Digest` is present, and `FlagsBoot`
   publishes at server start before any player exists, so the normal case does not yield. The
   pathological case waits up to `Flags.WAIT_SECONDS = 10` and then falls back to the defaults with
   its own warning — i.e. to the shoulder camera, with a `[flags] published-timeout` line the
   Director's `flags live` check already looks at. That is the honest failure: a wrong camera, loudly,
   not a silent half-state.
2. `tests/server/camera_mode.spec.luau` requires `StarterPlayerScripts.Camera.Mode` from the
   **server**, so `Config` → `Flags` resolves on the server path (`ServerStorage` attributes). That is
   the path `tests/server/flags.spec.luau` already exercises.
3. **`tools/studio_mcp.py` stays the only writer of `DHFlag_*`**, and `test`/`test2` refuse to start
   while any override is set, so no harness run can be made against the wrong branch.
4. `python tools/flags.py set FIRST_PERSON on` works in the same session the row lands, because Task
   78 fixed the Edit-mode `require` cache (`docs/research/2026-09-27-require-cache.md`).

### 6.7 The shot must not move — where the boundary is, exactly

The shot is `{ origin = CurrentCamera.CFrame.Position, direction = CurrentCamera.CFrame.LookVector }`,
read at the MouseButton1 edge in `Weapon.Input.onFire`. So:

| Term | Touches the camera? | Therefore |
|---|---|---|
| Sway | **no** — it is in `viewmodelOffset` only | cosmetic. Cannot move the ray |
| Bob | **no** — `viewmodelOffset` only | cosmetic. Cannot move the ray |
| Recoil on the drawn gun (`recoilGunPitchDeg`, `recoilGunBackStuds`) | **no** | cosmetic. Cannot move the ray |
| The break-open tilt | **no** | cosmetic. Cannot move the ray |
| Recoil on the **camera** (`recoilCamPitchDeg`) | **yes, by definition** | see below |

**Camera recoil is not cosmetic, and pretending it is would be the bug.** A kick that moves the view
moves the next shot, because the view *is* the aim — that is what recoil means in a shooter, and the
only way to make it "cosmetic" would be to keep a second, hidden, true aim direction, which is
precisely the two-truths failure this project is designed against. So it is built as **a separate
term in the one aim state**, never folded into `pitchDeg`:

- `recoilCamPitchDeg` is added to `pitchDeg` inside `Mode.cameraCFrame`, and it is the **only** place;
- its spring target is 0 and it snaps to exactly 0 (§4.5), so there is **no permanent kick** — the
  2 % permanent offset source I uses is a spray-control mechanic for a competitive shooter and has no
  place in a hunting game;
- the player's own aim (`pitchDeg`) is never written by it, so a kick during a mouse movement does not
  fight the player;
- it reaches the screen through `Rig.apply` like everything else, so the foreign-write detector sees
  our own write and not a stranger's (§1.2, the third prohibition).

One knock-on, stated so it is not discovered in a two-player run: `Camera.lookAt`'s "landed" test
compares `applied.LookVector` with the direction to the target against
`LOOK_AT_LANDED_DOT = 0.99` (≈8.1°). A 1.5° kick is well inside that, and rest is exact, so a staged
shot lands as before. §9.2 keeps the existing `landed <= requests` assertion, which is the windowed
claim that survives another caller (Task 82).

---

## 7. External sources

Rule 1 and rule 2: this is where I borrow. **A–H are v2's, still load-bearing, judgements unchanged
except where marked. I–L are new for first person** and are the sources of
`docs/research/2026-09-27-first-person-viewmodel.md` §3, re-judged here for the design.

### A. Roblox camera manipulation — `Camera`, `CameraType.Scriptable`, `LocalTransparencyModifier`, `CameraMode`
<https://create.roblox.com/docs/workspace/camera> ·
<https://create.roblox.com/docs/reference/engine/classes/Camera> ·
<https://create.roblox.com/docs/reference/engine/classes/BasePart#LocalTransparencyModifier>
**Licence: CC BY 4.0** (`github.com/Roblox/creator-docs`). **Maintained:** first-party, last push
2026-09-26 per the note.
**Good:** the whole primitive, with numbers rather than folklore. `FieldOfView` is "measured between
1–120 degrees", "Default is 70"; `CameraType = Scriptable` "gives you full control of the camera";
`Camera` is **not replicated**, which is why this system is client-only and why a viewmodel under it
can never decide a hit; `LocalTransparencyModifier` is the documented client-local way to hide the
player's own body.
**Bad:** it gives no third-person controller and no viewmodel; and `CameraMode.LockFirstPerson`, the
one thing that sounds like this task, describes the **stock** camera and keeps "equipped Tools"
visible (§2), so its free body-hiding is not ours.
**Adopted:** `Scriptable` plus per-frame `CFrame`/`FieldOfView` writes from one module; the FOV bounds;
the local body hidden with `LocalTransparencyModifier`, never `Transparency`.

### B. Roblox `PlayerScripts` / `PlayerModule`
<https://create.roblox.com/docs/reference/engine/classes/PlayerScripts> ·
<https://create.roblox.com/docs/reference/engine/classes/PlayerModule>
First-party; ships with every place; updated without our say-so.
**Good:** the only documented way to turn off the stock camera **without** also turning off movement:
`PlayerModule:GetCameras():Disable()` leaves `GetControls()` alive.
**Bad:** Roblox-controlled, injected at run time, returns an undocumented internal object, and is
silent on failure. **Measured here: this place has no `PlayerModule` at all**, so the call is
belt-and-braces and the detector is the real proof.
**Adopted:** disable the cameras, keep the controls, re-assert on respawn, **detect the failure at run
time**.

### C. `RunService:BindToRenderStep` and `Enum.RenderPriority`
<https://create.roblox.com/docs/reference/engine/classes/RunService> · first-party, maintained.
**Good:** a **named** binding at a documented priority (`Enum.RenderPriority.Camera.Value`, 200),
where the engine expects camera code; `UnbindFromRenderStep` by name makes teardown provable.
**Bad:** a yielding or erroring callback stalls the frame; no re-entrancy guard, no error isolation.
**Adopted:** one binding named `DrivenHunt.Camera`, a callback that never yields, teardown asserted.

### D. Roblox raycasting — the occlusion cast
<https://create.roblox.com/docs/workspace/raycasting> · first-party, maintained.
**Good:** `FilterType = Exclude` plus the character is all a camera pull-in needs.
**Bad:** one ray is infinitely thin, so the camera still clips a corner the ray misses; Roblox's own
stock camera uses a multi-cast "Popper".
**Adopted, and now narrowed:** one ray per frame **in the OFF branch only**, pulled in by
`OCCLUSION_PAD_STUDS`, floored at `OCCLUSION_MIN_DISTANCE_STUDS`, injected through `Rig.setCast` so
specs need no geometry. The ON branch casts nothing (§4.3).

### E. EgoMoose `rbx-fractality-spring` — named, still deliberately not adopted
<https://github.com/EgoMoose/rbx-fractality-spring> · **MIT** · not archived; single maintainer.
**Bad, and decisive:** a runtime Wally package needs a new `$path` in `default.project.json`, which
`rojo serve` does not reload — it costs **Karen's Connect click** — and it moves `wally.lock` and
`devpackages.sha256`, which the harness pins.
**Decision: not adopted.** v2 deferred it "until recoil lands"; recoil now lands, and the answer is
source K's maths written out in `Mode.spring` instead — six lines, no dependency, no click.

### F. Frame-rate-independent interpolation — Rory Driscoll, "Frame rate independent damping using lerp"
<https://www.rorydriscoll.com/2016/03/07/frame-rate-independent-damping-using-lerp/>
A personal blog — **technique and reasoning only, no code.** Static since 2016.
**Good:** it names the bug this design would otherwise ship: `lerp(value, target, 0.1)` per frame is a
different transition at 30 fps and at 144.
**Bad:** the exponential form never reaches the target, so "arrived" stays a threshold.
**Adopted, with the amendment the "bad" forces:** a **time-accumulated linear parameter** for the
blend (`blend += dt / AIM_BLEND_SECONDS`), and — new in v3 — the same rule for **sway** and for the
**open tilt**, so both reach exactly 0 or exactly 1 (§4.5). Recoil keeps a spring because overshoot is
the point there, and gets an explicit rest snap instead.

### G. Borrowed from inside this repo (rule 2 applies to internal patterns too)
`src/server/Boar/init.luau` and `src/server/BoarBoot.server.luau`: an owner that does nothing on
`require`, a pure decision module exported for specs, the world injected rather than looked up, and a
boot script as the composition root. `Weapon.StateMachine`'s reducer over a frozen state.
`MapGen.Layout.furniture` + `MapGen.Props.furniture`, and `Weapon.Shape.pieces` + `Weapon.Hardware`:
**a pure list plus one builder** — which is exactly the shape `Shape.sight` + `Hardware` gives the new
attachment.

### H. `TweenService` easing reference
<https://create.roblox.com/docs/reference/engine/classes/TweenService> · first-party, maintained.
Quad/Out written out as `1-(1-t)^2` so the pure module needs no service and runs in a server spec.

### I. rokoblox5, "FPS using ViewModels (The improved version) // Parts: 2 out of 3" — DevForum, 2021-04-05
<https://devforum.roblox.com/t/fps-using-viewmodels-the-improved-version-parts-2-out-of-3/1129877>
**Licence: none** — a forum post under Roblox's terms: readable, not redistributable. Treated as a
**pattern; no line copied.** **Maintained: no** (2021; its `SetPrimaryPartCFrame` is deprecated, and
this repo already uses `PivotTo`).
**Good:** the canonical Roblox statement of the three mechanisms this task needs. A model parented to
`workspace.CurrentCamera` and re-posed every render step at `Camera.CFrame:ToWorldSpace(offset)`; and
**ADS as an `AimPart`** — an invisible part on the gun marking where the camera should end up, with
the frame's transform `hip:Lerp(aim, t)` — so the sight picture is a *geometric consequence*, not a
hand-tuned offset. Recoil as two springs with the numbers written out (gun impulse, camera
`Speed = 15, Damper = 0.8`).
**Bad:** no FOV change at all; **2 % of the camera kick kept permanently**, which is spray control for
a competitive shooter and wrong for a hunting game; and it clones the whole character every spawn,
heavier than cloning the Tool the way `Camera.Viewmodel` does.
**Adopted:** the **AimPart idea, as our `Sight` attachment** — it is the reason a bead sight can be
made honest (§6.5, §9.2) — and the spring *shape* for recoil, `speed 15 / damper 0.8`, **without the
permanent kick** (§6.7).

### J. Spa_rkk, "How to make an FPS viewmodel part 3! Sway and reloading!" — DevForum, 2022-06-21
<https://devforum.roblox.com/t/how-to-make-an-fps-viewmodel-part-3-sway-and-reloading/1840530>
**Licence: none** (as I). **Maintained: no.**
**Good:** the standard sway recipe, compactly: take the camera's rotation delta, pull the X and Y
angles out, offset the viewmodel by `CFrame.Angles(sin(x)*k, sin(y)*k, 0)`, smoothed.
**Bad:** the smoothing is `lerp(..., 0.1)` **per frame**, frame-rate dependent — at 144 fps it is twice
as fast as at 60, the exact bug source F names; and its reload is driven by a *server* script
decrementing ammo, which we do not need because `Weapon.StateMachine` already owns the break action
and the snapshot already carries `open` and `busyFor`.
**Adopted:** the sway **shape** and the choice of a *view-rotation* input rather than a raw mouse
input (it survives a controller or touch that ever feeds `lookDelta`) — expressed here as degrees of
sway per degree the view actually turned, so it is FOV-independent. **Not** its timing maths: sway
returns linearly to exactly zero (§4.5).

### K. Quenty, `NevermoreEngine` — the spring
<https://github.com/Quenty/NevermoreEngine> · **Licence: MIT.** **Maintained: yes** — last push
2026-09-24, 614 stars per the note.
**Good:** a correct, readable, openly licensed critically-dampable spring (`Target`, `Position`,
`Velocity`, `Speed`, `Damper`), the de-facto reference for spring motion on Roblox and the maths
source I's tutorial is an informal copy of.
**Bad:** it is a whole engine with its own loader and package layout; pulling it in for one spring
would add a Wally dependency and a second module system to a repo that has neither (source E's cost,
again).
**Adopted:** the **maths**, written out in six lines inside `Mode.spring` with this citation in the
comment (rule 9) — the precedent source E set when it named a spring and deliberately did not adopt
it.

### L. The open-source Roblox FPS kits — surveyed, and none is adoptable
| Repo | Licence | Last push | Verdict |
|---|---|---|---|
| [minh-p/FPS_Viewmodel](https://github.com/minh-p/FPS_Viewmodel) | **none** | 2020-12-26 | No licence is not "free to copy", and a `.rbxl` is banned here anyway |
| [MonzterDev/First-Person-Camera-Roblox](https://github.com/MonzterDev/First-Person-Camera-Roblox) | **none** | 2022-04-25 | Same |
| [sshar1/FPS-Framework](https://github.com/sshar1/FPS-Framework) | **none** | 2022-05-08 | Same |
| [Kishero/CommunityFPS](https://github.com/Kishero/CommunityFPS) | **MIT** | **2016-05-30** | Licence fine, ten years stale: predates R15, Luau and `BindToRenderStep` |

**This is a finding, not a footnote:** there is no maintained, openly licensed Roblox first-person
viewmodel framework to borrow wholesale. Rule 2 is satisfied the other way — by borrowing the
**documented pattern** (I, J, K) rather than inventing one, and by keeping the mechanism inside the
owner this repo already has.

### M. Karen's reference clips — measured, not copied
Third-party game footage, four files outside the repo, **never committed and never copied**. What is
taken is **two measurements and a description** (note §2): first person in every frame; the gun low
and to the **left**, often entirely off the bottom; the sight picture straight down the rib at a small
bead; **no crosshair** in either pose; a mount time of **≈0.29 s** (7 frames at 24 fps, bounded
0.17–0.38 s); an ADS zoom of **≈1.3×**, i.e. ≈57° from a 70° hip FOV, honest band **55–58°**, inflated
by the camera also moving onto the stock. Hands were **not visible in any frame inspected**, so
"hands on the gun" is Karen's requirement and ours to design, not ours to copy.

**Pattern adopted overall:** a Scriptable camera written once per frame at the documented render
priority (A + C), the stock camera disabled and the stock controls kept (B), a camera-parented
viewmodel clone posed from the gun's own **sight attachment** (I), sway from the view-rotation delta
with this repo's timing rule (J + F), recoil as a written-out spring with an exact rest (K + F), no
occlusion cast in first person (D), inside this repo's owner / pure-core / instance-writer split (G).

---

## 8. Numeric targets — the one config table

**Every number lives in `Camera.Config`, frozen, and nowhere else.** Every angle is in **degrees** and
says so in its name, converted to radians at ONE named site — the rule introduced after the Task 19
cone-unit defect cost a 2× error.

**Branch** says which camera uses the row: `both`, `OFF` (kept for the shoulder camera, per brief
§2.6) or `ON`. **New numbers are the Director's first pick and Karen's to change** (brief §2.7); rows
marked *Karen* are already hers.

| Field | Value | Branch | Where from / converted where |
|---|---|---|---|
| `FIRST_PERSON` | `Flags.isOn("FIRST_PERSON")` | — | **NEW.** The one boundary read (§6.6) |
| `FOV_THIRD_DEG` | 70 | both | the engine default. In ON it is the **carry** FOV |
| `FOV_AIM_DEG` | 50 | both | *Karen*, 2026-09-25. The reference measures 55–58° (source M) — recorded beside it, not substituted |
| `AIM_BLEND_SECONDS` | 0.20 | both | *Karen*, 2026-09-25. The reference measures ≈0.29 s — recorded beside it |
| `BLEND_EASE` | Quad/Out, `1-(1-t)^2` | both | `Mode.ease`, the one site |
| `PIVOT_HEIGHT_STUDS` | 1.6 | both | above `HumanoidRootPart`, ≈ eye height. In ON this is the **walking** eye height all match long: Karen's dial |
| `AIM_PIVOT_FORWARD_STUDS` | 0.4 | both | the eye sits ahead of the pivot so it is not inside the head. In ON, applied always |
| `PITCH_MIN_DEG` / `PITCH_MAX_DEG` | −72 / 78 | both | short of ±90 so the camera never gimbals. Converted once, in `Mode.cameraCFrame` |
| `SENSITIVITY_DEG_PER_PIXEL` | 0.25 | both | *Karen*. Converted once, in `Mode.step` |
| `AIM_SENSITIVITY_OVERRIDE` | `nil` | both | nil = derive it (§8.1). 0.666 at FOV 50 |
| `MAX_DISTANCE_STUDS` | 14.5 | both | hard clamp; must stay below `CAMERA_ORIGIN_TOLERANCE = 30`. **Never binds in ON** (≈1.65 studs) and is asserted in both branches anyway |
| `SPAWN_PITCH_DEG` | −8 | both | yaw is kept across a respawn; only pitch resets |
| `LOOK_AT_LANDED_DOT` | 0.99 | both | ≈8.1°: "the request reached the screen", deliberately looser than what the spec waiting on it asserts (Task 50) |
| `RENDER_STEP_NAME` | `"DrivenHunt.Camera"` | both | the reserved prefix; a grep finds every binding we own |
| `CURSOR_LOCKED_DEFAULT` | `true` | both | MouseButton2 is the aim button |
| `FREE_CURSOR_ON_DEATH` | `false` | both | no death UI yet; the hook exists |
| `THIRD_DISTANCE_STUDS` | 12.0 | **OFF** | kept: the shoulder camera's boom |
| `SHOULDER_STUDS` | `Vector3.new(2.2, 0.35, 0)` | **OFF** | kept: right shoulder, keeps the third-person ray beside the body |
| `OCCLUSION_MIN_DISTANCE_STUDS` | 1.2 | **OFF** | kept. Not cast in ON |
| `OCCLUSION_PAD_STUDS` | 0.5 | **OFF** | kept. Not cast in ON |
| `BODY_HIDE_BLEND` | 0.60 | **OFF** | kept. In ON the body is hidden whenever there is a character, so this number means nothing there — **said once, not deleted** |
| `VIEWMODEL_SHOW_BLEND` | 0.02 | **OFF** | kept. In ON the gun is carried, not summoned: `Viewmodel.update` unparents only when `blend < it and not config.FIRST_PERSON` |
| `VIEWMODEL_HIP_OFFSET` | `CFrame.new(1.2, -1.2, -2.8)` | **OFF** | kept. Measured on screen in Task 26/47; low and **right** |
| `VIEWMODEL_AIM_OFFSET` | `CFrame.new(0, -0.6, -3.4)` | **OFF** + ON fallback | kept, and it is also `aimOffset(nil)` — used only when the gun has no `Sight`, and counted (`sightMissing`) |
| **`EYE_RELIEF_STUDS`** | **5.6** | ON | **NEW, derived, not guessed:** today's accepted `VIEWMODEL_AIM_OFFSET.Z = -3.4` puts the Handle's centre 3.4 studs out and the bead 2.15 further (`-2.15` in the Handle's frame) = **5.55**, rounded to 5.6 (0.05 studs, sub-pixel). So geometric ADS starts from the framing a screenshot already accepted. It is ≈1.7× the anatomical eye-to-bead distance, deliberately: it keeps the butt in front of the near plane |
| **`VIEWMODEL_CARRY_POS_STUDS`** | **`Vector3.new(-0.95, -1.45, -2.6)`** | ON | **NEW.** Low and **LEFT** (brief §1.3), ≈half the gun off the bottom-left. The `Z` is bounded, not chosen: the gun is `HANDLE_SIZE.Z = 4.4` long about its centre, so `Z > -2.3` would put the butt behind the camera plane; −2.6 leaves ≈0.5 studs of clearance once the carry angles are applied |
| **`CARRY_PITCH_DEG`** / **`CARRY_YAW_DEG`** / **`CARRY_ROLL_DEG`** | **−12 / −14 / 8** | ON | **NEW.** Three named degrees rather than a `CFrame` literal, so Karen has three legible dials; converted to radians once, in `Mode.carryOffset`. Negative yaw turns the muzzle toward the screen centre from a left-hand offset, which is the reference's "enters from the lower-left at roughly 30°" |
| **`NEAR_PLANE_MARGIN_STUDS`** | **0.25** | ON | **NEW, asserted not applied:** every corner of the gun's box must be at least this far in front of the camera in both poses (§9.1). The near plane is 0.1 studs and a 4.4-stud gun at the eye clips if the pose is wrong (note §8) |
| **`SWAY_PER_TURN`** | **0.35** | ON | **NEW.** Degrees of sway per degree the view turned — dimensionless, so it is FOV-independent |
| **`SWAY_MAX_DEG`** | **2.0** | ON | note §6 |
| **`SWAY_RETURN_SECONDS`** | **0.15** | ON | note §6. Linear return to **exactly** 0 |
| **`SWAY_AIM_SCALE`** | **0.15** | ON | note §6: suppressed in ADS so the sight picture holds still |
| **`BOB_STUDS`** | **0.03** | ON | note §6. Deliberately tiny: it must never be what moves the bead |
| **`BOB_HZ`** | **1.8** | ON | note §6 |
| **`BOB_MIN_SPEED`** | **2.0** studs/s | ON | **NEW.** Below it the player is standing and bob is **exactly** 0 |
| **`BOB_AIM_SCALE`** | **0** | ON | note §6: off while aiming |
| **`RECOIL_GUN_BACK_STUDS`** | **0.12** | ON | **NEW.** The gun's straight-back impulse |
| **`RECOIL_GUN_PITCH_DEG`** | **3.5** | ON | **NEW.** The muzzle rises on the drawn gun |
| **`RECOIL_CAM_PITCH_DEG`** | **1.5** | ON | note §6, per slug. Through the one aim state (§6.7) |
| **`RECOIL_SPRING_SPEED`** / **`RECOIL_SPRING_DAMPER`** | **15 / 0.8** | ON | source I's constants, source K's maths |
| **`RECOIL_REST_DEG`** / **`RECOIL_REST_RATE`** | **0.01 / 0.05** | ON | **NEW.** Below both, snapped to exactly 0, so "at rest" is a fact (§4.5) |
| **`SPRING_MAX_STEP_SECONDS`** | **0.05** | ON | **NEW.** Sub-step bound; explicit Euler at speed 15 needs `h < 0.133` |
| **`OPEN_TILT_DEG`** | **22** | ON | **NEW.** The **whole-gun** break tilt. A single MeshPart has no barrel to hinge (note §5.4), so the whole gun tilts about its grip: honest, cheap, and it reads at a glance |
| **`OPEN_TILT_SECONDS`** | **0.35** | ON | **NEW, and bounded by the weapon's own timing, not invented:** a server spec asserts `OPEN_TILT_SECONDS <= Shotgun.CONFIG.RELOAD_BREAK (0.5)` **and** `<= RELOAD_CLOSE (0.6)`, so the motion always finishes inside the window it depicts |
| **`BEAD_CENTRE_TOLERANCE_DEG`** | **0.37** | both | **NEW, the one testable number.** = 8 px at 1920×1080 and FOV 50 (Roblox's FOV is vertical: 50/1080 = 0.0463°/px). ≈0.9 studs at 143 studs (40 m), against a boar 5.5 studs long and 3 tall |

### 8.1 The one derived number, written out

```
sensitivityScale(fovDeg) = tan(rad(fovDeg)/2) / tan(rad(FOV_THIRD_DEG)/2)
```
Called once per frame in `Mode.step` with the **current blended FOV**, so the sensitivity eases in
step with the zoom instead of snapping. `AIM_SENSITIVITY_OVERRIDE`, if Karen prefers a flat number,
replaces the result and nothing else changes.

### 8.2 Performance and correctness targets, each one checkable

| Target | Branch | How it is checked |
|---|---|---|
| Camera update ≤ **0.3 ms average** per frame | both | `Camera.stats().avgUpdateMs` over ≥ 120 frames. The worst frame is printed, not asserted tightly (Task 26 measured 0.22–0.34 ms maxima for identical code), with a loose `maxUpdateMs < 5` to catch a hitch that could only be a bug |
| Raycasts per frame | ON: **0** · OFF: exactly **1** | the injected cast counts its calls (`Rig.setCast`) |
| **Zero** Instances created per frame | both | the clone is rebuilt only on a source-identity or child change; `Viewmodel.stats().rebuilds` does not grow over 120 frames, and neither does `#workspace.CurrentCamera:GetDescendants()` |
| Viewmodel parts | ≤ 16 gun parts (+ ≤ 4 arm parts from S3) | client spec. "A gun, not somebody's character" |
| `Mode.step` ≤ **10 µs** | both | server spec: 10,000 steps under 100 ms, with the new fields in |
| `foreignCameraWrites == 0`, `cursorReasserts == 0` | both | client spec — **the mechanical one-writer proof** (§10.1) |
| `maxDistanceFromRoot` < 15, and < 30 | both | client spec — the shotgun-validator guard |
| `blend` reaches exactly 1.0 after `AIM_BLEND_SECONDS` at any frame rate | both | server spec at dt = 1/30 and 1/240 |
| **Bead within `BEAD_CENTRE_TOLERANCE_DEG` of screen centre in ADS steady state** | both, by parameter | §9.2 item 12 — the one number this task adds |
| `sightMissing == 0` for a real gun | ON | client spec + the `Hardware` warning |
| Sway, bob, recoil and tilt all at **exact** rest in ADS steady state | both | server spec: bitwise-equal offsets (§4.5) |
| Typed-value harness problems from this task | — | **0** (§3.6) |

---

## 9. How it is tested

**The branch rule, first, because it is the false-PASS path this task creates.** The flag is OFF, so
every harness run exercises the OFF branch live. Three mechanisms keep the ON branch from being
untested prose:

1. **Everything pure is driven by parameter** (`table.clone(Config)` with `FIRST_PERSON = true`), so
   the server spec tests **both** branches in every run at one flag value.
2. **`Viewmodel.update` is public and takes `config`**, so the client spec drives the ON-branch pose
   and the bead measurement on the real camera, in the real viewport, with the flag off — the
   mechanism the Task 74 and 76 cases already use.
3. **Live-branch blocks are guarded and counted, never silently skipped.** Each of
   `describe("third person — the live OFF branch")` and
   `describe("first person — the live ON branch")` increments a file-local counter, and the **last
   `it` in the file asserts the counter is exactly 1**. A guard that merely `return`s early is a test
   that passes when the flag flips and nothing runs; this one fails.

### 9.1 Server spec — `tests/server/camera_mode.spec.luau` (pure, no client)

`Camera.Mode` requires only its `Config` sibling, so a **server** spec requires
`StarterPlayer.StarterPlayerScripts.Camera.Mode` and drives it with no player and no camera. **Every
v2 case stays** (23 `it`s today, including `anglesToward`'s five). New cases:

1. **Both branches, one config each.** `firstPerson = table.clone(Config); firstPerson.FIRST_PERSON = true`
   at the top; every geometry case below runs against both tables and asserts different answers.
2. **ON: the camera is at the eye, at every blend.** `Mode.cameraCFrame(root, state, firstPerson)` for
   `blend` in `{0, 0.25, 0.5, 1}` puts the position within `AIM_PIVOT_FORWARD_STUDS + 1e-4` of the
   pivot, and `(cam.Position - root.Position).Magnitude < 2.0` — **and `< MAX_DISTANCE_STUDS`, and
   `< 30`**, with a comment naming `CAMERA_ORIGIN_TOLERANCE`.
3. **OFF is unchanged:** at `blend = 0` the camera is `THIRD_DISTANCE_STUDS` behind the pivot plus the
   shoulder offset (v2's case, still green).
4. **The FOV still eases in both branches**, and `fovFor(0) == FOV_THIRD_DEG`,
   `fovFor(1) == FOV_AIM_DEG` exactly.
5. **`aimOffset` is the geometry, exactly.** For a sight at `CFrame.new(0, 0.255, -2.15)`:
   `(aimOffset(sight, cfg) * sight).Position` equals `Vector3.new(0, 0, -EYE_RELIEF_STUDS)` within
   1e-4, and its `LookVector` equals `(0, 0, -1)` within 1e-6. **Zero tolerance, because this is
   algebra**; the 0.37° tolerance belongs to the screen, not to the maths.
6. **`aimOffset(nil)` is `VIEWMODEL_AIM_OFFSET`**, so the fallback is a decision and not an accident.
7. **The carry pose is low and LEFT:** `carryOffset(cfg).Position.X < 0` and `.Y < 0`, and the three
   degree fields are converted at exactly one site (a 2× or radian/degree slip changes the position by
   more than a stud, which this case catches).
8. **The near plane, as an assertion instead of a hope.** For each of the eight corners of the gun's
   box (`HANDLE_SIZE`, centred, since the Handle is the envelope), in **both** the carry pose and the
   ADS pose: the corner's camera-space `Z <= -NEAR_PLANE_MARGIN_STUDS`. This is note §8's clipping
   risk made mechanical.
9. **Sway:** a 400-pixel `lookDelta` produces sway; it never exceeds `SWAY_MAX_DEG`; with no input it
   reaches **exactly** `Vector2.zero` within `SWAY_RETURN_SECONDS` of accumulated dt at dt = 1/30
   **and** 1/240; and at `blend = 1` it is scaled by `SWAY_AIM_SCALE`.
10. **Bob:** `speed = 0` gives `bobStuds == Vector3.zero` exactly; `speed = 12` gives
    `|bobStuds.Y| <= BOB_STUDS`; the phase advances at `BOB_HZ` (2π after `1/BOB_HZ` seconds of
    accumulated dt, within 1e-6) and wraps; `BOB_AIM_SCALE = 0` makes it exactly zero at `blend = 1`.
11. **Recoil:** `kicks = 1` moves the gun back and up and pitches the camera; the peak camera pitch is
    within 10 % of `RECOIL_CAM_PITCH_DEG`; it returns to **exactly** 0 within
    `RECOIL_RETURN_SECONDS = 0.25` at dt = 1/30, 1/144 and 1/240; `kicks = 2` in one step is twice the
    impulse; **and there is no permanent offset** — after 50 kicks and 5 s of settling,
    `recoilCamPitchDeg == 0` and `pitchDeg` is byte-identical to what the player's own input left.
    A `dt = 0.5` step (a hitch) does not diverge: the sub-stepping bound is exercised and the result
    is finite and within `2 * RECOIL_CAM_PITCH_DEG`.
12. **The open tilt:** `open = true` reaches exactly 1 in `OPEN_TILT_SECONDS`; `false` returns to
    exactly 0; and `OPEN_TILT_SECONDS <= Shotgun.CONFIG.RELOAD_BREAK` and `<= RELOAD_CLOSE`, which is
    the relation that keeps the motion inside the weapon's own window without duplicating its number.
13. **The rest invariant the screen test depends on:** with a rest state,
    `viewmodelOffset(state, sight, cfg)` at `blend = 1` is **bitwise equal** to
    `aimOffset(sight, cfg)`.
14. **`anglesToward` still works in first person:** with the ON config the camera is at the eye, so
    the iteration converges in one pass; aiming at a point 20 studs away leaves the camera within
    0.01° (v2's case, re-run against the ON table). This is the harness's `stage` step and
    `shoot_boar.spec`'s path, so it must hold in both branches.
15. **10,000 steps under 100 ms**, with all ten new fields in the state.
16. Every returned state is **frozen** and a different table; `Config` is frozen (a write raises).

**Fallback (rules 6, 8):** if requiring a `StarterPlayerScripts` module from the server ever stops
working, every assertion moves verbatim into the client spec and the Builder reports which happened.
It works today (`tests/server/camera_mode.spec.luau` is green).

### 9.2 Client spec — `tests/client/camera_client.spec.luau` (the real camera, the real client)

Reached through `Players.LocalPlayer:WaitForChild("PlayerScripts").Camera`, never through
`StarterPlayerScripts`, which is a template. **Every v2 case stays**, with three of them moved into
the guarded OFF-branch block (the third-person FOV/framing case, the occlusion case, and the
`distance < 2.5` half of the aim-path case). New and changed:

1. **One writer, mechanically.** After ≥ 120 frames, `stats().foreignCameraWrites == 0` and
   `Cursor.stats().reasserts == 0`. Unchanged, and now it also covers recoil: a kick that reached the
   camera any way but through `Rig.apply` would show up here.
2. **The detector is still falsifiable:** a rotation-only foreign write is counted; the camera's own
   writes are not (v2's two cases, audit-003 must-fix 2 — the property a test that cannot fail once
   guarded).
3. `CameraType == Scriptable`, `Camera.acquired()` true, and the reason printed verbatim.
4. **`Camera.isFirstPerson() == Camera.Config.FIRST_PERSON`**, and the value is printed. One line, and
   it is what ties every branch guard below to the build actually running.
5. **The branch counter** (above): exactly one live branch ran.
6. **OFF branch, live:** `getMode() == "Third"`, `FieldOfView` within 0.01 of `FOV_THIRD_DEG`, the
   aimed camera within 2.5 studs of the root, the viewmodel unparented at blend 0, the occlusion cast
   called once per frame and pulling in to `4 - OCCLUSION_PAD_STUDS`.
7. **ON branch, live:** the camera is within `AIM_PIVOT_FORWARD_STUDS + 0.2` studs of the pivot at
   **blend 0**, the viewmodel is parented at blend 0 (`Viewmodel.isParented()`), `sightMissing == 0`
   for a shooter holding a gun, and no raycast is made (`setCast` counts zero over 10 frames).
8. **The crosshair, by parameter, all eight combinations:**
   `Hud.crosshairVisible(state, aiming, firstPerson)` is false whenever `firstPerson` is true —
   including not aiming, which is the case brief §1.2 adds — and the live `Hud.isCrosshairVisible()`
   agrees with `crosshairVisible(Weapon.get(), getMode() == "Aiming", isFirstPerson())`. That second
   assertion is what stops the predicate being right while the drawing is wrong.
9. **The viewmodel is really on screen** (v2's case, unchanged and still unconditional): a `Model`
   whose `Parent` **is** `workspace.CurrentCamera`; the envelope is the only invisible part and
   everything else shows; every part `CanQuery == false`, `Anchored == true`,
   `LocalTransparencyModifier < 1`; every ancestor present up to the DataModel — "a visibility audit
   ignored parent visibility and certified a blank screen twice", written as assertions. **It does not
   replace the screenshot.**
10. **The appearance survives the clone** (Task 74) and **the clone is rebuilt when the source's
    children change** (Task 76): both cases stay, with `Viewmodel.update`'s new signature.
11. **The pivot assumption:** after a `PivotTo`,
    `(model:GetPivot().Position - clone.Position).Magnitude < 1e-3` (§5.5).
12. **THE BEAD IS ON THE AXIS — the one testable number (brief §2.4).** In one resumption, with **no
    yield** between the pose and the measurement, because a yield lets the production render step
    re-pose the gun and move the camera:
    ```
    source = a MeshPart "Handle" of HANDLE_SIZE, Transparency 1, with
             a "Sight" Attachment at CFrame.new(0, 0.255, -2.15) and
             a "Bead" Part of 0.05 studs at the same point
    Viewmodel.setSource(-> source) ; Viewmodel.clear() ; task.wait(0.3)   -- the source is asked 4x/s
    cam = Workspace.CurrentCamera
    Viewmodel.update(cam.CFrame, restStateAtBlend1, firstPersonConfig)    -- by PARAMETER, no flag
    model = Viewmodel.current()   -- must be ok(), unconditionally: no `if model then`
    sight = the clone's Sight ; bead = the clone's Bead
    for each of {sight.WorldPosition, bead.Position}:
        p, onScreen = cam:WorldToViewportPoint(point)
        expect(onScreen) ; offsetPx = (Vector2.new(p.X, p.Y) - cam.ViewportSize/2).Magnitude
        tolerancePx = BEAD_CENTRE_TOLERANCE_DEG * cam.ViewportSize.Y / cam.FieldOfView
        print the px, the tolerance and the degrees ; expect(offsetPx <= tolerancePx)
    restore: Viewmodel.clear() ; Viewmodel.setSource(live) ; source:Destroy()
    ```
    **The tolerance is angular and the pixels are derived, not fixed.** A Studio Play window is much
    smaller than 1080 px, so a hard 8 px there would be a *looser* angular claim — a false-PASS path.
    The invariant is 0.37°; the printed pixel count is the report.
    **What it proves and what it cannot:** it proves the ADS maths reaches the screen and that the
    `Sight` the gun carries is what the pose is built on. It **cannot** prove that a *mesh's* painted
    bead is where its `Sight` says, because a single MeshPart has no `Bead` Instance to project — for
    the mesh that is the S2 screenshot's job, and this design says so rather than letting a green
    number imply it (`docs/PROJECT_CONTEXT.md`: "Things measured correct and looked wrong").
    **When the viewmodel is not parented** (a driver, no gun, a source that returned nil) the case
    **fails with a message naming the reason** — never skips. The round-1 note on the Task 74 case
    (`if model then` made the whole block pass when no viewmodel was built) is the precedent.
13. **The steady-state claim is a steady state:** before measuring, `waitUntil` no look input for
    `SWAY_RETURN_SECONDS`, `getState().swayDeg == Vector2.zero`, `recoilCamPitchDeg == 0` and
    `bobStuds == Vector3.zero` — asserted, so item 12 cannot pass by catching a spring at a good
    moment.
14. **The hidden local body** (four cases, unchanged and now load-bearing for the whole match rather
    than for ADS alone): a part that arrives after the body was hidden is hidden; every part the
    character has, the Tool's `Handle` among them, reaches
    `LocalTransparencyModifier = 1`; a part that **leaves** while hidden is put back; the flag
    clearing restores everything.
15. **The harness-driven aim** (unchanged, and it runs **first**, while the production source
    installed by `CameraBoot` is still the only one): a shooter's real right mouse button entered and
    left `Aiming` twice, asserted as a **delta** from a baseline taken in the test; a driver has no
    `DrivenHunt.Weapon.*` action bound at all and the same replay changes nothing.
16. **The look-at landed signal** (unchanged, Task 50): a request is not counted until a frame has
    been rendered; `landed <= requests`; a refused request counts nothing, measured with no frame in
    between because another spec calls `Camera.lookAt` every frame (Task 82).
17. **Budget:** `avgUpdateMs < 0.3`, `maxUpdateMs < 5`, and `#workspace.CurrentCamera:GetDescendants()`
    does not grow across 120 frames.
18. **The cursor contract** (unchanged): locked and hidden by default; two tags need two releases;
    `reasserts == 0`.
19. **Teardown** in `afterAll`, not asserted after doing it inside the `it` (Task 6a note (a) is the
    record of that mistake): no `DrivenHunt.Camera` binding, no viewmodel, a free cursor,
    `CameraType == Custom`.

### 9.3 Server spec additions for the `Sight` — `tests/server/weapon_shot.spec.luau` and `assets_seam.spec.luau`

Not the camera's file, because the attachment is the weapon's and the row is the manifest's — but this
design specifies them, because they are what make the bead honest:

1. `Hardware.build()` with **no** template provider: the `Handle` has a `Sight` attachment and its
   `CFrame` equals `Shape.sight(config)` exactly.
2. `Shape.sight(config)` and the `Bead` piece in `Shape.pieces(config)` agree **to 1e-6** — the
   mechanical proof that they come from one expression (`Shape.beadOffset`).
3. With an injected mesh template and a row carrying `sightOffsetStuds`, the `Sight` is at that value;
   with the field `nil`, it falls back to `Shape.sight` and `Hardware` warns **once, not per grant**.
4. `Hardware.upgrade` leaves exactly one `Sight` (idempotent, like the `Model` it already is).
5. **A bound on the manifest, which is cheap and catches a typo without pretending to catch a wrong
   bead:** for every row with a `sightOffsetStuds`, the point is inside the mesh's own scaled bounding
   box, its `Y` is in `[0.15, 0.45]` (above the bore, below the top of a 0.69-stud-tall gun), and its
   `Z` is within 0.25 studs of `Shape.muzzleZ(config) = -2.2`.

### 9.4 Harness-driven input — the real player's path (rule 6)

**No new scenario.** `tests/client/input_scenarios.txt` already carries `aim-hold` (right mouse down,
600 ms, up), and the weapon scenario replays another hold, so two holds arrive per run and §9.2 item
15 waits for both. First person changes what the camera does with the button, not the button.

**What the harness still cannot do**, from `tools/studio_mcp.py`'s docstring and `TASKS.md` rows 6 and
6a: touch and gamepad input; a hold measured in frames; input aimed at an instance; anything after the
client report is written; and — the one that matters most here — **an absolute `moveTo` under
`MouseBehavior = LockCenter` may deliver no usable `InputObject.Delta`**, so *rotation* by replayed
input may be untestable. The rotation maths is covered by the pure server spec; `Camera.lookAt` exists
precisely because of this gap and is how the harness stages a shot.

**The flag is the honest limit, stated plainly (rule 8):** while `FIRST_PERSON` is OFF, the harness
proves the ON branch's *maths and drawing by parameter* and its *live wiring* not at all. That is
`docs/design/feature-flags.md` §13.3's rule and its cost, and it is why every step in §14 carries a
screenshot taken with the override on.

### 9.5 Screenshots — rule 5, required

`python tools/studio_mcp.py capture <name> [camera x,y,z] [look-at x,y,z]` saves to `.screenshots/`
and works during Play. §14 lists exactly what each step's screenshot must show. Two standing rules:

- **Describe what is actually on screen, not what should be.** A camera and a viewmodel are the most
  visual things in the game, and a number is not a verification.
- **Every ON-branch screenshot is taken with the override on** (`python tools/flags.py set
  FIRST_PERSON on`, `flags live` to confirm what it resolved), and `python tools/flags.py clear`
  before the next harness run — `test` and `test2` refuse to start otherwise.

---

## 10. Failure modes, and how each one is loud

### 10.1 A second camera writer — the detector

`Rig.apply` stores what it wrote. On the next frame, before writing again, it compares the camera's
**position, two basis vectors and field of view** with that record. A difference means something else
wrote the camera between frames: `foreignCameraWrites += 1` and one `warn` with both values.
`CameraType` and `CameraSubject` are deliberately **not** compared, because the engine restores both
on respawn and either would count the engine as a foreign writer every life (audit-003).

This is the single most valuable thing in this design, and audit-003 must-fix 2 is why it compares
orientation: it used to compare position and FOV only, so a second writer that **turned** the view
without moving the camera read as zero, and both specs resting on the counter went green on evidence
that could not see the case they exist for.

| Failure | How it is loud |
|---|---|
| The stock camera is not disabled | `Rig.acquire` reports which case it hit, verbatim; `Camera.start` warns; and a silent failure still shows as `foreignCameraWrites > 0` |
| Something else writes the mouse | `Cursor.stats().reasserts > 0`, asserted zero |
| **The gun has no `Sight`, so the bead is not the sight** | `Hardware` warns once server-side; `Viewmodel.stats().sightMissing > 0` client-side, asserted zero for a real gun; and the ADS pose falls back to a **named** legacy offset rather than to whatever happens to be there |
| **The mesh's measured sight is wrong** | Only the S2 screenshot catches it. Said out loud in §9.2 item 12 and §12 item C, because a green 0.37° assertion on the `Sight` would otherwise imply a claim it cannot make |
| The viewmodel leaks (present while it should not be) | `stats().viewmodelParented`, asserted false in the OFF branch at blend 0; and the parts are **unparented**, not hidden, so a leak is visible on screen |
| A viewmodel part blocks a raycast | `CanQuery = false` on every part, asserted; the symptom otherwise is a camera glued 1.2 studs behind the head in the OFF branch |
| **The real gun is drawn beside the viewmodel** | `Rig`'s `DescendantAdded` watcher, and §9.2 item 14's four cases. This is audit-003 F1, the defect Karen would see, and in first person it is permanent rather than momentary |
| A part that left the character stays invisible | §9.2 item 14's third case (Task 47 review round 1) |
| **The gun clips through the near plane** | §9.1 item 8 asserts every corner is `NEAR_PLANE_MARGIN_STUDS` in front, in both poses; and S1's screenshot is taken before anything is layered on it |
| **Recoil diverges on a frame hitch** | sub-stepped at `SPRING_MAX_STEP_SECONDS`, and §9.1 item 11 drives a `dt = 0.5` step |
| **A permanent kick creeps in** | §9.1 item 11: after 50 kicks, `recoilCamPitchDeg == 0` exactly and `pitchDeg` is unchanged |
| The camera update errors or yields | one `pcall`-free callback by design; an error in `BindToRenderStep` is printed by the engine every frame, which is loud. The owner does **not** swallow it |
| The character is missing | mode `Loading`, last CFrame held, no error and no spam — the tested path, not an accident |
| A respawn resets `CameraType` | `Rig.acquire` re-runs on `CharacterAdded` |
| The camera drifts beyond the shotgun's validator tolerance | `MAX_DISTANCE_STUDS` clamps it and both specs assert it in both branches; the symptom otherwise is the server rejecting honest shots `"origin-far"` — Task 19 defect 4, already paid for once |
| **The flag never arrives on a client** | `Flags` itself warns `published-timeout`, the camera silently *is* the OFF branch, and the Director's `flags live` line before the playtest is what catches it |
| **A second reader of the flag disagrees with the first** | impossible by construction: one read, in `Camera.Config`; everyone else reads `Camera.isFirstPerson()` |

---

## 11. Rows for `GAME_DESIGN.md` — ready to paste

Rule 3 requires the owners table to mirror this file. **Amend, do not add rows** (the Camera,
Viewmodel, Cursor and Aim-state rows already exist).

**Camera row** — append:

> Since Task 88 the camera has two branches behind the `FIRST_PERSON` flag, and `Camera.Config` is the
> **one** place that reads it (`Flags.isOn("FIRST_PERSON")`): ON is first person all the time (the eye
> at the pivot, no orbit, no occlusion cast, the local body always hidden), OFF is the accepted
> over-the-shoulder third person. `Camera.isFirstPerson()` republishes the fact so nothing else reads
> the flag. `Camera.Mode` also owns every cosmetic term — sway, bob, the recoil springs, the
> break-open tilt — as fields of the one frozen state; the **camera's** pitch kick is a separate term
> added in `Mode.cameraCFrame`, never folded into the player's own `pitchDeg`
> ([camera design](docs/design/camera.md) §3, §6.7).

**Viewmodel row** — append:

> It is parented all the time in the first-person branch, poses from the gun's own **`Sight`
> attachment** rather than from a hand-tuned offset (`Mode.aimOffset`), counts a gun that carries no
> `Sight` (`stats().sightMissing`), and from S3 also owns the cloned hands and lower arms — which live
> under `workspace.CurrentCamera`, never under the character, so `Camera.Rig` and this module can
> never fight over one part ([camera design](docs/design/camera.md) §3.2, §5.5).

**The gun's visible model row** — append:

> `Weapon.Hardware` is also the only writer of the **`Sight`** attachment, beside `Muzzle`. Its value
> is `Weapon.Shape.sight(config)` for the parts gun — the same expression that places the `Bead`
> piece — and the `Assets` row's `sightOffsetStuds` for the uploaded MeshPart, which has no `Bead`
> part to read ([camera design](docs/design/camera.md) §6.5).

**`UI / anything drawn` row** — replace the crosshair clause:

> … The crosshair is `Hud.crosshairVisible(state, aiming, firstPerson)`, a pure public predicate: it
> is false while aiming and **false at all times in first person** (Karen, 2026-09-27). The Hud reads
> `Camera.getMode()` and `Camera.isFirstPerson()`; the camera never touches anything drawn
> ([camera design](docs/design/camera.md) §6.2).

**Input** stays `_unassigned_` as a system, deliberately: there is no global input router. Each system
owns its named bindings under a reserved prefix — `DrivenHunt.Weapon.*` for the weapon,
`DrivenHunt.Camera.*` reserved here (this task binds no action; the camera reads mouse movement
through its one `UserInputService.InputChanged` connection, because `ContextActionService` cannot bind
movement).

---

## 12. Open decisions — none of them blocks building

Every one has a default written into §8 or §14. They are things to overrule on purpose rather than by
accident.

### Karen (feel) — the "check this" list for the first-person playtest

1. **`FOV_AIM_DEG = 50`, or the reference's 55–58°?** Yours is kept; the measurement is recorded
   beside it (§8). One number.
2. **`AIM_BLEND_SECONDS = 0.20`, or the reference's ≈0.29 s?** Same. Is the mount snappy enough with a
   boar running, or does it feel twitchy?
3. **The carry pose** — `VIEWMODEL_CARRY_POS_STUDS` and the three carry angles. How much of the gun do
   you want off the bottom-left? In the reference it is often all of it.
4. **`PIVOT_HEIGHT_STUDS = 1.6` as a walking eye height.** It was chosen as an ADS position, and now
   you look through it for ten minutes at a time.
5. **Sway 2° / bob 0.03 studs at 1.8 Hz.** Deliberately small: bob must never be what moves the bead.
   Too dead? Too seasick?
6. **Recoil: 1.5° on the camera, 3.5° and 0.12 studs on the gun, settled in ≈0.25 s.** A slug from a
   side-by-side should be felt.
7. **`OPEN_TILT_DEG = 22`** — does the whole gun tilting read as "breaking it open" (note §5.4: a
   single MeshPart has no barrel to hinge)?
8. **The arms** (S3): cloned from your own avatar, hands and forearms only, rigid. Do they look like
   your hands on the gun, or like two sausages?
9. **Does the camera creep forward onto the stock in ADS?** The reference's 1.3× zoom is partly that.
   Default: **no creep**, the eye stays put; it is one term in `Mode.cameraCFrame` if you want it.
10. **Do you want the shoulder camera kept at all** after you have played both? If not, the OFF branch
    is archived under `backups/` with a note (rule 7) and the flag row retired.

### Director (scope)

- **A. Character rotation while aiming (§6.4).** Default: **not in this work.** First person raises
  its priority, because now *every* player is always looking down a gun their body may not face. It
  needs a character/movement owner, which is a new `GAME_DESIGN.md` row and its own small design.
- **B. A death camera in first person (§4.6).** Default: **hold the eye where it was, body hidden, no
  new state.** A pull-back or a killcam is a separate task.
- **C. Who measures the mesh's `sightOffsetStuds`, and when (§6.5).** Default: **the S2 task**, by
  screenshot iteration in ADS, recorded in the `Assets` row with the date and the method — exactly as
  `rotationDeg = (0, 90, 0)` was found. Until then the field is `nil`, the fallback applies and
  `Hardware` warns. The alternative is a measurement task before S2, which costs a round and buys the
  same answer.
- **D. Recoil moves the next shot (§6.7).** Default: **yes**, because the view *is* the aim and a
  second hidden aim direction is the two-truths failure. If you want the camera kick purely visual, it
  is one line — but then say plainly in `GAME_DESIGN.md` that the picture and the ray differ during
  the kick, because that is what it would mean.
- **E. Splitting the asset into barrels + action** so the reload can really hinge (note §5.4).
  Default: **after Karen accepts S4's whole-gun tilt**, as an asset task (`tools/asset_prep.py` plus
  a re-upload and a new `Assets` row), not a camera task.
- **F. The flag's life.** Born OFF with `expires = 2026-10-18` (21 days). Karen's OK flips the default
  in a ≤ 3-line commit; retirement archives the losing branch under `backups/` and removes the row.
  If the comparison slips past 2026-10-18, the date moves with a reason in `why` — one line, so the
  rot tripwire can never block a task, only force someone to say the flag still has a reason.
- **G. Gamepad and touch.** Default: **PC only**, unchanged. The stock **controls** stay enabled so a
  gamepad or a phone can still *move*; they cannot *look*, because the stock camera that handles
  right-stick and drag is the thing we disabled. Right-stick look is ~10 lines against
  `UserInputService.InputChanged` (`Thumbstick2`) into the same `lookDelta`; touch needs a decision
  about where the aim button goes on a phone. First person makes this gap more visible, not less.
- **H. Sound (S5).** Named as step five and deliberately not designed here: it is judged in a
  playtest, not in a screenshot, and it wants its own note and owner.

---

## 13. What I could not verify (rule 8)

- **Anything requiring Roblox Studio.** No Studio in this session (`.agent-evidence/INDEX.md`). Every
  claim about what the harness *would* do is read from `tools/studio_mcp.py`'s docstring and the
  existing specs, not observed. Nothing in §14 has been on a screen.
- **The external sources' current licence and maintenance status.** No network this session. A–D and H
  are first-party Roblox documentation (creator-docs is CC BY 4.0) and the APIs ship with the engine;
  E and K are cited by licence (MIT) and deliberately not depended on; I and J are forum posts with
  **no licence**, used for technique only with **no code taken**; L's table and M's measurements are
  reproduced from `docs/research/2026-09-27-first-person-viewmodel.md` §3 and §2, which the Builder
  gathered on 2026-09-27. The Builder re-confirms I, J and K in a note addendum before relying on any
  of them.
- **`EYE_RELIEF_STUDS = 5.6` is derived from a number that was accepted on screen, not measured on
  screen itself.** `VIEWMODEL_AIM_OFFSET.Z = -3.4` was measured and accepted in Tasks 26/47; 5.55
  follows arithmetically. Whether *that* framing is right for a bead picture rather than for a barrel
  under a crosshair is S2's screenshot, and Karen's.
- **Every new number in §8 is a starting point.** The carry position and angles, sway, bob, recoil and
  the open tilt have never been rendered. Karen decides all of them.
- **Whether a mesh's painted bead is where its `Sight` says.** Unmeasurable by any spec in this repo
  (§9.2 item 12); the S2 screenshot is the only check, and the design says so rather than letting a
  green assertion imply otherwise.
- **Whether cloning `LeftLowerArm`/`LeftHand` off a character wearing layered clothing looks right**
  (§5.5). It is a `WrapLayer` question, and the answer is S3's screenshot on Karen's own avatar. The
  fallback is named.
- **Whether `require`ing `ReplicatedStorage.Flags` from `Camera.Config` ever yields at boot** (§6.6).
  Read from `Flags`' own code — `resolveOnClient` only waits when `Digest` is absent, and `FlagsBoot`
  publishes before any player exists — not observed. The failure is the OFF branch plus a warning, not
  a hang, and the Builder reports the measured `[flags]` line from the first run.
- **Whether `Rig.setLocalBodyHidden(true)` being on permanently changes the cost of the
  `DescendantAdded` path** in a 16-player match. The walk is off the frame path by design and
  `avgUpdateMs` is asserted, but a match-sized measurement does not exist yet.
- **Whether the `aim-hold` scenario still proves the aim path once the camera no longer changes
  position on aim.** It asserts on `aimEnters`/`aimExits` and `modeHistory`, which are mode facts and
  not geometry, so it should be unaffected — read from the spec, not run.

---

## 14. The step plan — five steps, each small, each behind the flag, each photographed

Karen's instruction is *step by step until she says it looks and feels right*, so no step bundles two
things she could reject separately. Every step: born behind `FIRST_PERSON` (OFF), reviewed, harness +
`test2`, merged dark; then the Director switches the override on, takes the screenshots, and clears
it.

### S1 — first-person camera, no crosshair, the gun carried low-left

**Code.** The flag row; `Config` gains `FIRST_PERSON` and the carry numbers; `Mode.cameraCFrame` and
`Mode.carryOffset` branch on it; `Mode.viewmodelOffset` takes the new shape (with the cosmetic terms
present but zero); `Viewmodel.update` takes `state` and stays parented in the ON branch;
`Rig.setLocalBodyHidden` is driven per §4.3 step 6; the owner skips `Rig.occlude`;
`Camera.isFirstPerson()`; `Hud.crosshairVisible`.

**A spec asserts:** §9.1 items 1–4, 7, 8, 16; §9.2 items 4–9, 17 (the whole branch-guard machinery
lands here, because everything after it depends on it).

**The screenshot must show** (two captures, override on):
1. **Standing, gun carried.** The world from eye height; **no reticle anywhere on screen**; the
   shotgun's barrels crossing the **lower-left** corner with roughly half the gun out of frame; **no
   part of the player's own body and no second shotgun** visible; nothing cut off at the bottom-left
   edge by the near plane.
2. **The same spot, looking down at the feet.** No floating body parts, no gun sliced by the near
   plane, no hole where the character should be.

**Only Karen can judge:** whether the carry reads as "a gun in my hands", and whether eye height 1.6
feels right walking.

### S2 — ADS raise to the bead, the FOV change, and the pixel measurement

**Code.** `Shape.beadOffset` extracted and `Shape.sight` added; `Hardware` creates the `Sight` in
`build` **and** `upgrade`; `AssetRow.sightOffsetStuds`; `Mode.aimOffset`; `Viewmodel.sight()` and
`stats().sightMissing`; `EYE_RELIEF_STUDS`.

**A spec asserts:** §9.1 items 5, 6, 8, 13; §9.2 items 11, 12, 13; §9.3 items 1–5. **This is the step
that carries the one testable number**, and the request pastes the printed pixel/degree line.

**The screenshot must show** (three captures from one marked spot at a named object at a measured
distance, override on):
1. **Hip carry**, for comparison.
2. **Mid-blend**, one frame during the raise: the gun on its way up, nothing teleporting.
3. **Full ADS**: the rib running away from the eye to the bead, **the bead on the named object**, the
   barrel pair just below centre (≈1.4°, which is the geometry and not a choice), **no crosshair**,
   the whole gun in frame, the receiver visible and not clipped. The FOV change is visible by
   comparing (3) with (1) from the same spot.

**Only Karen can judge:** 50° vs 55–58°, 0.20 s vs 0.29 s, and whether the sight picture looks like a
shotgun rather than a scope. **And for the uploaded mesh, only the screenshot can judge whether the
painted bead sits where the `Sight` says** — that is why (3) is taken with the mesh loaded, and why
the request must say which variant was on screen.

### S3 — hands and arms on the gun

**Code.** `Hardware` creates `GripHold` and `ForeHold` beside `Sight` (values from `Shape` for the
parts gun, from the row for the mesh); `Viewmodel` clones the hands and lower arms per §5.5 and
parents them **under the gun clone** so one `PivotTo` still poses everything; a `RigType` branch; the
fallback path.

**A spec asserts:** the arm clones exist, are `Anchored`, `CanQuery = false`, have no scripts, are
descendants of the gun clone, are **not** descendants of the character, and do not grow the part count
past the §8.2 budget; `Rig.hiddenPartCount()` is unaffected by them (the two owners are disjoint by
parent, and this is the assertion that proves it).

**The screenshot must show** (two captures, override on, **on Karen's own avatar with whatever it
wears**): both poses, two arms holding the forend and the grip, **no gap at the wrist**, no arm
through the receiver, no bare or grey forearm where clothing should be, and no arm entering from an
impossible direction.

**Only Karen can judge:** whether they look like hands and not sausages.

### S4 — recoil kick and return, and the break-open reload motion

**Code.** `Mode.spring`; the six recoil fields and `openTilt`; `Camera.kick`; `StepInput.kicks` and
`.open`; `Weapon.Fired` in `src/client/Weapon/init.luau`, derived from its **own replica** — a barrel
going `Live` → `Spent` in an arriving snapshot; `CameraBoot` connects the two.

**Why the authoritative edge and not the click:** a kick on a click the server refuses (an empty
barrel, the rate limit) is a picture that lies, and every rule in this project exists because pictures
lied. The cost is one round trip of latency, named here so it is not discovered: if it feels laggy,
the optimistic variant (kick when the client's own replica says the selected barrel is `Live` and
`busyFor == 0`) is Karen's dial, and it is one branch in `CameraBoot`'s adapter.

**A spec asserts:** §9.1 items 11, 12 (including the hitch, the no-permanent-kick case and the
`OPEN_TILT_SECONDS <= RELOAD_BREAK` relation); §9.2 item 13's rest assertions; and that a kick reaches
the camera **through `Rig.apply`** — `foreignCameraWrites` stays 0 across 20 kicks, which is the
mechanical version of §1.2's third prohibition.

**The screenshot must show** (two captures, override on):
1. **The top of the kick** — the muzzle up, the gun back, the view lifted; and a second frame ≈0.3 s
   later showing it returned, so "it comes back" is visible and not asserted alone.
2. **Mid-reload, the action open** — the **whole gun** tilted `OPEN_TILT_DEG` about the grip. Note
   plainly in the request that the barrels do **not** hinge, because the uploaded gun is exactly one
   MeshPart; the barrel/action split is Director item E.

**Only Karen can judge:** whether the kick has weight without losing the target, and whether the tilt
reads as breaking a gun open.

### S5 — sound

Last, and **not a screenshot** (a sound is not an image). Judged in a playtest. It needs its own
research note and its own owner decision before any code (rule 1), and this design does not make it:
it is named here so the plan is complete and so nobody attaches audio to the camera owner by default.
