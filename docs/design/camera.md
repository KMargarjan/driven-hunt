# Design: camera (third person + first-person aim, viewmodel, cursor)

Architect, 2026-09-25, for Task 25 (ROADMAP 1.4b). Commit `792f985d36f6cfa92e058f8ffb8172a16638eb25`
(`.agent-evidence/INDEX.md`). Read-only session: Read, Grep, Glob. No Studio, no network. Evidence is
precomputed in `.agent-evidence/`.

**This is the first camera design in this repo.** `GAME_DESIGN.md`'s *System owners* table has
`Camera | _unassigned_`, and `.agent-evidence/ls-files.txt` shows `src/client/` holds nothing but
`.gitkeep`. So nothing is superseded and nothing is inherited except the seams the shotgun design
already fixed.

Inputs, in precedence order: `reviews/task-25/BRIEF.md` (Director and Karen), `docs/design/shotgun.md`
v2 (§9 fixes the seam; §1.2 forbids the weapon from writing the camera), `docs/research/2026-09-24-shotgun.md`
(sources 4 and 5 are the viewmodel and camera-replication research; not re-derived here),
`docs/PROJECT_CONTEXT.md`, `CLAUDE.md`, `tools/studio_mcp.py` (the docstring is the harness's truth),
`tests/client/input_driving.spec.luau` and `tests/client/input_scenarios.txt` (what Task 6 actually
delivered).

**Test of this document:** a Builder can build the camera from it without asking a question. Every
number is here, every owner is named, every interface is written out, and every dependency on another
system is a named symbol in a named file.

**Scope note from the brief.** Design only. Nothing is built from this until Task 24 (the shotgun)
is merged and the Director dispatches the build. This design assumes the shotgun's client half exists
as `docs/design/shotgun.md` §3.2 and §5.5 describe it, and it degrades to a working third-person
camera if it does not (§4.4).

---

## 1. What the system must do, and must not do

### 1.1 Must do

1. Third person by default, whenever the player is walking or driving (brief, Karen's v1 spec).
2. First-person aim while the aim input is held: the camera moves to the eye, the FOV narrows, the
   real character's own body stops filling the screen, and the shotgun is held in view as a
   **viewmodel**. Releasing returns to third person. Karen wants this in v1.
3. Be **the only writer of `workspace.CurrentCamera`** in the whole game (rule 3, brief item 2), and
   make a second writer *detectable at runtime*, not merely forbidden in prose (§10.1).
4. Be the only writer of the **mouse cursor and mouse lock**, with a named request API so that a later
   UI can ask for a free cursor without ever writing one (§3.3).
5. Own the **viewmodel** — created, pivoted and destroyed by one module, never replicated, never able
   to decide a hit (`docs/research/2026-09-24-shotgun.md` source 5: `workspace.CurrentCamera` is Not
   Replicated, and the viewmodel lives under it).
6. Keep the shotgun's fire path working **unchanged in both modes**, including the server's
   `CAMERA_ORIGIN_TOLERANCE` of 30 studs (`docs/design/shotgun.md` §11). This design bounds the camera's
   distance from `HumanoidRootPart` at 14.5 studs and asserts it (§8, §9.2).
7. Publish the camera's mode and blend so the **Hud** can decide the crosshair for itself
   (`docs/design/shotgun.md` §9 item 3). The camera draws nothing.
8. Behave deterministically at spawn, death, respawn, tool unequip and a missing character — each as a
   named state, not as an error (§4).

### 1.2 Must not

Every row is a named cause of death of the previous project, written as a prohibition. Quotes are from
`docs/PROJECT_CONTEXT.md`, section "Why the rules exist - the previous project", cited by section and
quote and never by line number (`CLAUDE.md`, the loop, step 4; `TASKS.md` row 19 defect (c)).

| Prohibition | Why | Whose job instead |
|---|---|---|
| No module outside `PlayerScripts.Camera.Rig` may assign `CurrentCamera.CFrame`, `.FieldOfView`, `.CameraType` or `.CameraSubject` | "Two systems wrote the creature's position" | `Camera.Rig` (§3.1). Reading the camera is allowed and the weapon does it (`docs/design/shotgun.md` §7.1) |
| **The stock Roblox camera scripts must be switched off, once, explicitly** | they are a second writer that ships with the engine. A design that only says "we own the camera" while `PlayerModule`'s CameraModule is still running is the previous project's worst failure with Roblox as the co-author | `Camera.Rig.acquire` (§3.1, §7 source B) |
| No module outside `PlayerScripts.Camera.Cursor` may assign `UserInputService.MouseBehavior`, `.MouseIconEnabled`, `.MouseDeltaSensitivity` or `Mouse.Icon` | "Three scripts set the mouse cursor" | `Camera.Cursor` (§3.3), through `requestFree`/`release` |
| The camera never creates a `ScreenGui`, `Frame` or `TextLabel`, and never sets `Visible` on anything drawn | "One predicate answered two unrelated questions, so mounting hid both the crosshair and the weapon" | `PlayerScripts.Hud` (`docs/design/shotgun.md` §3.4), which **reads** `Camera.getMode()` |
| The camera never writes the aim flag, never binds MouseButton2, and never fires `AimChanged` | two systems binding the aim button is the cursor failure with a different property name (`docs/design/shotgun.md` §9 item 1) | `PlayerScripts.Weapon.Input` |
| The camera never writes the character: no `CFrame`, `AutoRotate`, `WalkSpeed`, `Humanoid` state | the character/movement owner does not exist yet, and inventing one here is "invented foundations" | unassigned; §6.4 names the decision |
| The camera never writes `Transparency` on a character part — only `LocalTransparencyModifier`, and only on the **local** player's own character | `Transparency` replicates in intent and is the other players' business; `LocalTransparencyModifier` is the documented client-local override (§7 source A) | `Camera.Rig.setLocalBodyHidden` |
| The camera fires no `RemoteEvent` and has no server half | the camera is not replicated (research source 5), so a server half would be inventing a second truth | if 1.7 needs the server to know someone is aiming, the **weapon** publishes it: it already owns the flag |
| No typed property value (`Vector3`, `CFrame`, `Color3`) in a `.model.json` or `.meta.json` | the harness fails it as "cannot compare" (`tools/studio_mcp.py` docstring, check 4); audit-002 must-fix 1 is still open (`TASKS.md` row 16) | §3.6: this system puts **no file of data on disk**. Everything is code |
| No Wally package in this task | `wally.lock` and `devpackages.sha256` are pinned against the commit, and a runtime package needs a new `$path` in `default.project.json`, which `rojo serve` does not reload — that costs Karen a Connect click (`CLAUDE.md`, Toolchain) | §7 source E: the spring is named, deferred and not needed for a 0.2 s blend |

**Three predicates, three owners, never one function.** The previous project hid the crosshair and the
weapon with one predicate. Here the three questions are answered in three different modules from the
same published state, and no module calls another's:

| Question | Answered by | From |
|---|---|---|
| Is the crosshair visible? | `PlayerScripts.Hud` | `Weapon.get().equipped` **and** `Camera.getMode()` |
| Is the viewmodel visible? | `Camera.Viewmodel` | `blend > VIEWMODEL_SHOW_BLEND` |
| Is the local character's body hidden? | `Camera.Rig` | `blend > BODY_HIDE_BLEND` |

---

## 2. Why not just use the stock camera

Stated once, because it is the decision everything else rests on.

The stock `PlayerModule` camera is a real, maintained, first-party third-person camera, and rule 2
says borrow before building. Two facts kill it for this game:

1. **The aim button is taken.** Roblox's classic camera rotates on **right mouse button held**, and
   `docs/design/shotgun.md` §5.5 binds `DrivenHunt.Weapon.Aim` to MouseButton2. One button cannot both
   orbit the camera and aim the gun. Since the aim binding is fixed by the shotgun design and Karen's
   spec, the camera must be permanently mouse-locked, which the stock camera only offers as shift-lock
   or `CameraMode = LockFirstPerson`.
2. **`CameraMode = LockFirstPerson` is not ADS.** It is a mode switch with no blend, no FOV change,
   no per-mode sensitivity and no viewmodel, and it is written by the stock module, so the moment we
   also want an FOV lerp we have two writers on one Camera object. That is the exact shape of
   "two correct pieces of code disagreeing" (`docs/PROJECT_CONTEXT.md`).

So: **the stock camera module is disabled, the stock control (movement) module is kept.** The
movement module reads `workspace.CurrentCamera` to compute camera-relative WASD, which is a read and
stays correct under a `Scriptable` camera. We borrow the part that works and replace only the part
whose input we need. The borrowed *pattern* for what replaces it is the documented Scriptable-camera
loop (§7 source A + C) and the viewmodel write-up (§7 source D), not a home-grown invention.

---

## 3. Ownership

Rule 3: exactly one writer per system, named here and mirrored into `GAME_DESIGN.md` (§11). The shape
deliberately mirrors what is already on `main` and green: a folder module `init.luau` that owns state,
a pure decision module exported for specs (`src/server/Boar/init.luau` exports `Boar.Brain`), and
separate modules that are the only writers of Instances (`src/server/Boar/Body.luau`).

### 3.1 The one camera owner

**`Players.LocalPlayer.PlayerScripts.Camera`** — disk `src/client/Camera/init.luau`, booted once by
`src/client/CameraBoot.client.luau`.

Sole writer of: the camera **mode state** (`mode`, `blend`, `yawDeg`, `pitchDeg`), the `Changed`
signal, the one `BindToRenderStep` binding, and the one `UserInputService` connection that reads mouse
delta. It is a **ModuleScript**, and **nothing happens on `require`** — only `Camera.start()` begins
production, which is the rule `src/server/Boar/init.luau` states in its header and the only thing that
makes the specs in §9 possible.

Its private modules, each the sole writer or owner of exactly one thing:

| Module | Is | Never |
|---|---|---|
| `Config.luau` | the frozen numbers. No writer | holds logic |
| `Mode.luau` | **pure**: the reducer and every piece of camera maths. `(state, input, dt, config) -> state`, plus `cameraCFrame`, `ease`, `sensitivityScale` | touches Instances, services, clocks, `Players` |
| `Rig.luau` | **the only writer of `workspace.CurrentCamera`** and of `LocalTransparencyModifier` on the local character. Disables the stock camera. Does the occlusion cast | holds mode state, reads input, touches the cursor or the Hud |
| `Cursor.luau` | **the only writer of `UserInputService.MouseBehavior` / `.MouseIconEnabled` / `.MouseDeltaSensitivity` and `Mouse.Icon`** | touches the camera, the viewmodel or anything drawn |
| `Viewmodel.luau` | **the only writer of the viewmodel Instances** under `workspace.CurrentCamera` | writes the camera itself, writes the real Tool, decides a hit |

### 3.2 The viewmodel owner

`Camera.Viewmodel`. It **clones** the local player's Tool `Handle` and never modifies the original —
`ServerScriptService.Weapon.Hardware` stays the only writer of `Tool` Instances
(`docs/design/shotgun.md` §3.1). The clone is parented to `workspace.CurrentCamera` while aiming and
to `nil` otherwise.

**`CanQuery = false` on every viewmodel part, and it is not optional.** `workspace.CurrentCamera` is a
child of Workspace, so a client-side raycast — including this system's own occlusion cast — can hit a
part parented to the camera. That is a mystery bug waiting to happen; the config carries it and §9.2
asserts it.

### 3.3 The cursor / mouse-lock owner

`Camera.Cursor`, with a **tagged request API** instead of a setter:

```luau
Cursor.requestFree(tag: string): ()   -- "I need a visible, free cursor" (a menu, a spec)
Cursor.release(tag: string): ()
Cursor.isFree(): boolean              -- true while any tag is outstanding
```

Nothing else writes the mouse. A caller states a *need*; the Cursor resolves all needs and performs
the single write. Three systems can want a free cursor and there is still exactly one writer — that is
"three scripts set the mouse cursor" designed out rather than banned.

The Cursor writes only when the engine's current value differs from the wanted one, and counts every
time it found a difference it did not cause (`Cursor.stats().reasserts`). A non-zero count during a
run means something else wrote the mouse. §9.2 asserts it is zero.

### 3.4 The aim state: who writes, who reads

| | |
|---|---|
| **Writer** | `PlayerScripts.Weapon.Input`, through `DrivenHunt.Weapon.Aim` and `Input.AimChanged` (`docs/design/shotgun.md` §5.5, §9 item 1). Fixed there; not re-opened here |
| **Readers** | `PlayerScripts.Camera` (through an injected source, §4.4) and nothing else |
| **Truth vs request** | `Input.isAiming()` is the **request**. `Camera.getMode()`/`getBlend()` is the **state**: it accounts for the transition, death, a missing character and an unequipped tool. Anything that wants to know "is the view in aim" reads the camera, never the weapon |

That rule is what stops the Hud from having two sources for one question.

### 3.5 Files on disk

```
src/client/
  CameraBoot.client.luau   -> PlayerScripts.CameraBoot     (LocalScript, ~12 lines: the composition root)
  Camera/
    init.luau              -> PlayerScripts.Camera         (THE OWNER)
    Config.luau            -> PlayerScripts.Camera.Config  (frozen numbers, no writer)
    Mode.luau              -> PlayerScripts.Camera.Mode    (pure)
    Rig.luau               -> PlayerScripts.Camera.Rig     (the only writer of CurrentCamera)
    Cursor.luau            -> PlayerScripts.Camera.Cursor  (the only writer of the mouse)
    Viewmodel.luau         -> PlayerScripts.Camera.Viewmodel
tests/server/camera_mode.spec.luau      (the pure module, 10,000 steps, no Studio client)
tests/client/camera_client.spec.luau    (the real camera in the real client)
tests/client/input_scenarios.txt        (one scenario ADDED, §9.3)
```

`src/client` is mapped to `StarterPlayer.StarterPlayerScripts` (`default.project.json`), and a folder
with `init.luau` becomes that ModuleScript with its files as children — proven in this repo by
`src/server/Boar/`, whose `Brain.luau` and `Body.luau` compare green (`TASKS.md` row 18).

**One file outside this system changes:** `src/client/Hud/init.luau` gains a subscription to
`Camera.Changed` for the crosshair (§6.2). That file's owner is the Hud and the change is inside it;
no second writer is created. If Task 24 has not landed, that change does not exist and neither does
the Hud.

### 3.6 No data on disk

No `.model.json`, no `.meta.json`, no `.rbxm` (banned, `CLAUDE.md`). Every number in §8 is a Luau
value in `Camera.Config`, because half of them are `Vector3`/`CFrame` and the harness fails a typed
JSON value as "cannot compare" (`tools/studio_mcp.py` docstring, check 4; audit-002 must-fix 1 open,
`TASKS.md` row 16). This is the third system to make that choice, after `TestArena.LAYOUT` and
`Boar.CONFIG`.

`Config` is flat: scalars, `Vector3`s and `CFrame`s, **no nested tables**. `table.freeze` is shallow
(Task 23a note (b), which caught exactly this in the shotgun design), so a flat table is the only one
whose freeze means what the word says. §9.1 asserts a write errors.

### 3.7 A naming rule, because two things are called "camera"

`workspace.CurrentCamera` is touched by exactly one file, `Rig.luau`, where it is the local `cam`.
Every other file's `Camera` is this system's module. No file contains both meanings.

---

## 4. The state machine

### 4.1 States

| Mode | When | What the rig does |
|---|---|---|
| `Loading` | no character, or no `HumanoidRootPart` yet | holds the last CFrame, FOV `FOV_THIRD_DEG`, no viewmodel, no error, no spam |
| `Third` | alive, not aiming | over-the-shoulder orbit at `THIRD_DISTANCE_STUDS`, blend decaying to 0 |
| `Aiming` | alive and the aim source says yes | blend rising to 1: camera to the eye, FOV to `FOV_AIM_DEG`, viewmodel shown, local body hidden |
| `Dead` | `Humanoid.Died` fired for the current character | blend forced to 0 at the normal rate, viewmodel cleared **immediately**, camera holds its position and looks at the last known head point. No orbit, no input |

`blend` is a single number in `[0, 1]` and is the only thing that transitions. `mode` says which way
it is moving. Nothing in the system has a second notion of "aimed".

### 4.2 Transitions

| From | Event | To |
|---|---|---|
| `Loading` | `CharacterAdded` and `HumanoidRootPart` present and `Humanoid.Health > 0` | `Third`, `blend = 0`, `pitch = SPAWN_PITCH_DEG`, **yaw kept** across a respawn |
| `Third` | aim source true | `Aiming` |
| `Aiming` | aim source false | `Third` |
| `Third` / `Aiming` | `Humanoid.Died` | `Dead` |
| any | `CharacterRemoving` or the root part gone | `Loading` |
| `Dead` | new `CharacterAdded` | `Third` |

**Tool unequipped, and why it is not a state here.** `Weapon.Input` binds `DrivenHunt.Weapon.Aim` on
`Tool.Equipped` and unbinds it on `Tool.Unequipped` (`docs/design/shotgun.md` §5.5), so an unequipped
player cannot request aim. The one hole — the tool being taken away *during* a held aim — is closed in
the adapter, not in the camera (§4.4): `isAiming()` is defined as "holding the aim button **and** the
replicated state says equipped". The camera therefore leaves `Aiming` on the next frame with no
special case, which is why this state machine has four states and not seven.

### 4.3 The frame

One binding, `RunService:BindToRenderStep("DrivenHunt.Camera", Enum.RenderPriority.Camera.Value, update)`
(§7 source C). The reserved name prefix `DrivenHunt.Camera.*` belongs to this system — for render
steps and for any future `ContextActionService` action. v1 binds no CAS action at all.

```
update(dt):
  1. read: character/humanoid/root (may be nil), aim = source and source.isAiming() or false
  2. state = Mode.step(state, { aiming, alive, hasCharacter, lookDelta }, dt, CONFIG)   -- pure
  3. lookDelta := Vector2.zero                                     -- consumed exactly once
  4. if mode ~= lastMode then fire Changed(mode, blend) end        -- on CHANGE, never per frame
  5. pivot, desired, fov = Mode.cameraCFrame(rootCFrame, state, CONFIG)   -- pure
  6. desired = Rig.occlude(pivot, desired)                         -- one raycast
  7. Rig.apply(desired, fov)                                       -- the only camera write in the game
  8. Rig.setLocalBodyHidden(state.blend > CONFIG.BODY_HIDE_BLEND)
  9. Viewmodel.update(camCFrame, state.blend)                      -- parents/unparents and pivots
 10. Cursor.apply()                                                -- writes only on a difference
```

Mouse delta arrives on a `UserInputService.InputChanged` connection (`MouseMovement` only) and is
accumulated into `lookDelta` between frames. `UserInputService` is the only way to see mouse movement;
`ContextActionService` cannot bind it (`tests/client/input_driving.spec.luau` header, which learned
this in Task 6).

### 4.4 The aim source is injected, and the adapter lives in the boot script

```luau
export type AimSource = { isAiming: () -> boolean }
Camera.setAimSource(source: AimSource?): ()   -- nil = the camera can never aim
```

`src/client/CameraBoot.client.luau` is the composition root and the only place that knows both
systems — exactly the idiom `src/server/BoarBoot.server.luau` already uses to wire two owners together
without either requiring the other (`docs/design/boar-ai.md` §9; `docs/design/shotgun.md` §6.3):

```luau
local Camera = require(PlayerScripts:WaitForChild("Camera"))
local weapon = PlayerScripts:FindFirstChild("Weapon")
if weapon then
    local Weapon = require(weapon)
    Camera.setAimSource({
        isAiming = function()
            local state = Weapon.get()
            return Weapon.Input.isAiming() and state ~= nil and state.equipped
        end,
    })
end
Camera.start()
```

Three things follow, and they are the reason for the seam:

1. `PlayerScripts.Camera` never requires `PlayerScripts.Weapon`. Neither owner knows the other.
2. The camera builds, boots and tests **with no weapon in the place at all** — it is a working
   third-person camera that simply never aims. That is what makes §9.1 and most of §9.2 runnable
   before or independently of Task 24.
3. A spec installs a fake source and drives the whole aim path with no input and no gun (§9.2).

---

## 5. Public interface

Types are exported from `PlayerScripts.Camera`. `luau-lsp` is pinned but not in CI (`TASKS.md` row 3),
so annotations are documentation plus editor checking, not a gate — the status
`docs/design/boar-ai.md` §4 and `docs/design/shotgun.md` §5 already record.

### 5.1 The owner

```luau
export type ModeName = "Loading" | "Third" | "Aiming" | "Dead"

export type State = {          -- frozen; returned by Mode.step, held by init.luau
    mode: ModeName,
    blend: number,             -- 0 = third person, 1 = fully aimed
    yawDeg: number,            -- world yaw, wrapped to (-180, 180]
    pitchDeg: number,          -- clamped to [PITCH_MIN_DEG, PITCH_MAX_DEG]
    sinceModeChange: number,   -- seconds
}

export type Stats = {
    frames: number,
    foreignCameraWrites: number,   -- frames where CurrentCamera differed from what Rig last wrote
    cursorReasserts: number,       -- times the mouse was not what Cursor last set
    maxDistanceFromRoot: number,   -- studs, the whole session (the shotgun-validator guard)
    maxUpdateMs: number,
    viewmodelParented: boolean,
    aimEnters: number,
    aimExits: number,
}

Camera.start(): ()                     -- once; errors if called twice
Camera.stop(): ()                      -- unbind, restore the stock camera, free the cursor, clear the viewmodel
Camera.getMode(): ModeName
Camera.getBlend(): number
Camera.getState(): State               -- frozen copy
Camera.Changed: RBXScriptSignal        -- (mode: ModeName, blend: number). Fires on MODE CHANGE ONLY
Camera.setAimSource(source: AimSource?): ()
Camera.stats(): Stats                  -- frozen copy
Camera.Mode, Camera.Config, Camera.Rig, Camera.Cursor, Camera.Viewmodel   -- exported for specs only,
    -- exactly as src/server/Boar/init.luau exports Boar.Brain
```

`Changed` is a `BindableEvent.Event` created at runtime — nothing hand-written (rule 2), the same
choice `docs/design/boar-ai.md` §8 made for `Despawned`, with the same two consequences: payloads are
copied, and under `SignalBehavior = Deferred` a listener does not run inside `Fire`, so a live spec
polls rather than assuming synchronous delivery.

**There are no remotes.** The camera is not replicated (`docs/research/2026-09-24-shotgun.md` source 5),
so a server half would be a second truth about something the server cannot see.

### 5.2 The pure core — `Camera.Mode`

```luau
export type StepInput = {
    aiming: boolean,
    alive: boolean,
    hasCharacter: boolean,
    lookDelta: Vector2,      -- pixels since the last frame
}

Mode.initial(config): State
Mode.step(state: State, input: StepInput, dt: number, config): State     -- returns a NEW frozen state
Mode.ease(t: number): number                 -- 1 - (1-t)^2 : Quad/Out, written out so the module needs no service
Mode.sensitivityScale(fovDeg: number, config): number    -- THE ONE conversion site (§8.1)
Mode.cameraCFrame(rootCFrame: CFrame, state: State, config): (Vector3, CFrame, number)
    -- returns (pivot, desired camera CFrame, fovDeg). Pure geometry, no raycast
Mode.viewmodelOffset(easedBlend: number, config): CFrame
```

Every one is a pure function of its arguments: no `game:GetService`, no clock, no `Players`, no
`Instance`. `dt` and `lookDelta` are parameters, not lookups. That is what makes the camera's maths
testable in a **server** spec with 10,000 steps and no client at all (§9.1) — the method
`tests/server/boar_brain.spec.luau` already proves works in this repo.

### 5.3 The rig

```luau
Rig.acquire(): (boolean, string?)   -- disables the stock cameras, sets CameraType = Scriptable.
                                    -- Returns false plus a reason if PlayerModule could not be disabled
Rig.release(): ()                   -- CameraType = Custom, stock cameras re-enabled (Camera.stop only)
Rig.apply(cf: CFrame, fovDeg: number): ()          -- the ONLY assignment to CurrentCamera in the repo
Rig.setLocalBodyHidden(hidden: boolean): ()        -- LocalTransparencyModifier on the local character only
Rig.occlude(pivot: Vector3, desired: Vector3): Vector3
Rig.setCast(cast: ((Vector3, Vector3) -> Vector3?)?): ()   -- production casts Workspace; a spec injects
Rig.stats(): { foreignCameraWrites: number, lastApplied: CFrame }
```

`Rig.acquire` is the only place in the repo that touches `PlayerScripts.PlayerModule`. It re-runs on
every `CharacterAdded`, because the engine restores `CameraType` on respawn; re-asserting is cheap and
the alternative is a camera that silently reverts to the stock one after the first death.

### 5.4 The cursor

```luau
Cursor.start(): () ; Cursor.stop(): ()
Cursor.requestFree(tag: string): ()   -- idempotent per tag
Cursor.release(tag: string): ()
Cursor.isFree(): boolean
Cursor.apply(): ()                    -- called once per frame by the owner; writes only on a difference
Cursor.stats(): { reasserts: number, tags: { string } }
```

Default state, whenever no tag is outstanding: `MouseBehavior = LockCenter`, `MouseIconEnabled = false`,
`MouseDeltaSensitivity` left at the engine default (the aim sensitivity change is done in our own maths
— §8.1 — so the engine property is owned but never written in v1, and a non-default value is a
`reassert`).

### 5.5 The viewmodel

```luau
Viewmodel.setSource(source: (() -> BasePart?)?): ()  -- returns the Handle to clone; nil = no viewmodel
Viewmodel.update(camCFrame: CFrame, blend: number): ()
Viewmodel.clear(): ()
Viewmodel.current(): Model?
```

`CameraBoot` sets the source to "the `Handle` of the Tool currently in the local character", which is a
**read** of the Tool the weapon owns. The clone is rebuilt when the source part changes identity, never
per frame. Every cloned part: `Anchored = true`, `CanCollide = false`, `CanQuery = false`,
`CanTouch = false`, `Massless = true`, no scripts, no `Attachment` behaviour.

---

## 6. Seams with other systems

### 6.1 The weapon — the aim flag and the fire origin

| Direction | Mechanism | Owner of the other end |
|---|---|---|
| Weapon → camera | `Input.isAiming()`, via the adapter in `CameraBoot` (§4.4) | `PlayerScripts.Weapon.Input` (`docs/design/shotgun.md` §5.5) |
| Camera → weapon | **nothing.** The weapon reads `workspace.CurrentCamera.CFrame` itself when it fires | the weapon's own code, unchanged |

**Fire origin, in both modes, and why the seam needs no branch.** The weapon sends
`{ origin = CurrentCamera.CFrame.Position, direction = CurrentCamera.CFrame.LookVector }`; the server
validates `origin` within `CAMERA_ORIGIN_TOLERANCE = 30` studs of `HumanoidRootPart`, casts the camera
ray for an aim point, then casts the pellets from the **muzzle** toward it
(`docs/design/shotgun.md` §5.4 steps 2–8). Nothing in that path knows which mode the camera is in:

- **Aiming:** the camera is at the eye, ~1.7 studs from the root. Trivially inside the tolerance.
- **Third:** `MAX_DISTANCE_STUDS = 14.5` is a hard clamp in `Mode.cameraCFrame`, so the origin is at
  most 14.5 studs from the root — **inside 30, with 15 studs of headroom** for a future longer camera.
  `Camera.stats().maxDistanceFromRoot` records the real maximum for a whole session and §9.2 asserts it.

**One requirement this design places on the weapon, and it is already a known defect.** In third
person the camera ray starts behind the shooter, so it can hit the shooter's own character. Task 23a
note (a) records exactly this ("step 4's camera ray … resolves the aim point onto the shooter's own
body"). This design does not fix another system's code; it states the requirement and reduces the
exposure:

1. The weapon's camera-ray cast **must** exclude the shooter's character (Task 23a (a) — the Builder
   fixes it at build time with the Director's say-so, per `TASKS.md` row 23a).
2. `SHOULDER_STUDS.X = 2.2` keeps the third-person ray beside the body rather than through it in the
   common case; that is a mitigation, not the fix.

### 6.2 The Hud — the crosshair while aiming

The Hud owns everything drawn (`docs/design/shotgun.md` §3.4). This design specifies the **read**,
not the drawing:

```luau
-- PlayerScripts.Hud, in this task's one change outside the camera system
Camera.Changed:Connect(function(mode) ... end)   -- plus one Camera.getMode() at start
-- crosshair visible iff  Weapon.get() ~= nil and state.equipped and Camera.getMode() ~= "Aiming"
```

**Default: the crosshair is hidden while aiming** (mode `Aiming`, i.e. from the moment aim is
requested, not at a blend threshold — a crosshair that fades is worse than one that switches). Reason:
in ADS the gun's own line is the aiming reference, and leaving a hipfire cross on top of it is the
classic double-reticle mistake. It is Karen's to overrule (§12) and it is one boolean.

The Hud reads `Camera`. The camera has no reference to the Hud, calls nothing on it, and does not know
it exists. One-way, as `docs/design/shotgun.md` §3.4 already requires.

### 6.3 The stock `PlayerModule`

| | |
|---|---|
| **Cameras** | disabled once by `Rig.acquire` via `require(PlayerScripts.PlayerModule):GetCameras():Disable()` |
| **Controls** | **kept**, untouched. Movement, jumping and mobile/gamepad locomotion stay Roblox's |
| **Risk** | `GetCameras()` is thinly documented and Roblox-controlled. If it ever stops working, the stock camera becomes a second writer **silently** |
| **Mitigation** | `Rig.acquire` returns `(false, reason)` on failure, `Camera.start` `warn`s it loudly and the client spec fails; and the foreign-write detector (§10.1) catches the silent case even if `Disable` succeeds today and breaks in a Studio update tomorrow |

### 6.4 The character — not this system's, and the consequence is visible

The camera never rotates the character. In v1 a player aiming sideways is, to **other** players, a
character facing wherever the movement code left them while a shotgun fires elsewhere. The shot still
lands where the crosshair is (the muzzle→aim-point cast, §6.1), so this is cosmetic, but it is real and
it will be seen in the first two-player playtest.

Fixing it means writing `Humanoid.AutoRotate` and the root CFrame, which needs a **character/movement
owner** — a system that does not exist and that this task will not invent (`GAME_DESIGN.md` has no such
row). Director item, §12.

---

## 7. External sources

Rule 1 and rule 2: this is where I borrow. Sources 4 and 5 of `docs/research/2026-09-24-shotgun.md`
(the viewmodel write-up, camera non-replication) are inherited and are repeated below only where this
design adds a judgement about them.

### A. Roblox camera manipulation — `Camera`, `CameraType.Scriptable`, `LocalTransparencyModifier`
<https://create.roblox.com/docs/workspace/camera> ·
<https://create.roblox.com/docs/reference/engine/classes/Camera> ·
<https://create.roblox.com/docs/reference/engine/classes/BasePart#LocalTransparencyModifier>
First-party creator docs (creator-docs is CC BY 4.0); the API ships with the engine. Actively maintained.
**Good:** the whole primitive. `CameraType = Scriptable` is the documented way to take the camera from
the default scripts; `CFrame` and `FieldOfView` are the only two properties a camera controller needs;
`Camera` is documented as **not replicated**, which is why this system is client-only and why the
viewmodel under it can never decide a hit; `LocalTransparencyModifier` is the documented client-local
way to hide the player's own body without touching replicated `Transparency`.
**Bad:** it gives no third-person controller, says nothing about the stock `PlayerModule` still running
alongside (source B), and `FieldOfView` is clamped to 1–120 degrees, which is an unstated hard edge for
anyone who later tries a scope at FOV 0.5.
**Adopted:** `Scriptable` plus per-frame `CFrame`/`FieldOfView` writes from one module; the local body
hidden with `LocalTransparencyModifier`, never `Transparency`.

### B. Roblox `PlayerScripts` / `PlayerModule` — the stock camera and control scripts
<https://create.roblox.com/docs/reference/engine/classes/PlayerScripts> ·
<https://create.roblox.com/docs/reference/engine/classes/PlayerModule>
First-party; ships with every place. Actively maintained (and updated without our say-so).
**Good:** it is the only documented way to turn off the stock camera **without** also turning off
movement: `PlayerModule:GetCameras():Disable()` keeps `GetControls()` alive, so WASD, jump and the
mobile/gamepad locomotion we are not building stay Roblox's problem. That one call is the difference
between "one camera writer" as prose and as fact.
**Bad:** the module's source is Roblox-controlled and injected at runtime; `GetCameras()` returns an
internal object rather than a documented class, so this is the single engine behaviour in this design
most likely to change under us. It is also silent on failure — a `Disable` that stops working produces
a camera fight, not an error.
**Adopted:** disable the cameras, keep the controls, re-assert on respawn, and **detect the failure at
runtime** (§10.1) rather than trusting the call.

### C. `RunService:BindToRenderStep` and `Enum.RenderPriority`
<https://create.roblox.com/docs/reference/engine/classes/RunService> ·
<https://create.roblox.com/docs/reference/engine/enums/RenderPriority>
First-party, actively maintained.
**Good:** a **named** binding at a documented priority (`Enum.RenderPriority.Camera.Value`, 200) — the
place the engine expects camera code, after input is gathered and before rendering. `UnbindFromRenderStep`
by the same name makes teardown exact and provable, which is how `tests/client/input_driving.spec.luau`
proves it leaves nothing bound.
**Bad:** a yielding or erroring callback stalls the frame; there is no re-entrancy guard and no
built-in error isolation, so one bad frame is every bad frame.
**Adopted:** one binding named `DrivenHunt.Camera`; the callback never yields; `Camera.stop()` unbinds
it by name and a spec asserts it is gone.

### D. Viewmodel pattern — the DevForum write-up (research source 4)
<https://devforum.roblox.com/t/fps-using-viewmodels-the-improved-version-parts-2-out-of-3/1129877>
(rokoblox5, 2021). Licence: a forum post — **technique only, no code copied.** Maintenance: static
since 2021, and it uses the deprecated `SetPrimaryPartCFrame`; the current call is `PivotTo`.
**Good:** this is the established pattern `docs/PROJECT_CONTEXT.md` says the previous project was
"fixed for good only by adopting": a model parented to `workspace.CurrentCamera` and pivoted each frame
to `Camera.CFrame * offset`, with a separate aim offset so the gun lines up with the view. It is local
and unreplicated by construction, so it cannot leak into hit detection.
**Bad:** it assumes an animated arms rig and a `.rbxm` weapon model, neither of which exists in a grey
box (and `.rbxm` is banned here); the 2021 API is stale; and it drives everything with springs, which
pulls in a dependency this task refuses (source E).
**Adopted:** the technique, with `PivotTo`, with the "model" being a clone of the code-built Tool
`Handle` and **no arms in v1** (§12, Director item B).

### E. EgoMoose `rbx-fractality-spring` — named, deliberately not adopted
<https://github.com/EgoMoose/rbx-fractality-spring> · **MIT** · not archived; a typed rewrite of
Fraktality's `spr`; Wally `egomoose/fractality-spring`. Single maintainer, small surface.
`docs/design/shotgun.md` §10 G already booked it as "the camera/ADS task's dependency so that task does
not re-research it".
**Good:** small, typed, MIT, and the right answer for **recoil** and weapon sway.
**Bad, and decisive for *this* task:** a runtime Wally package needs a new `$path` in
`default.project.json`, which `rojo serve` does not reload — it costs a Rojo restart and **Karen's
Connect click** (`CLAUDE.md`, Toolchain), and it moves `wally.lock`/`devpackages.sha256`, which the
harness pins. And a spring is the wrong tool for a 0.2 s ADS blend: a spring asymptotes, so "is it
aimed yet" becomes a threshold question, when the whole design here turns on `blend` reaching exactly
1 at exactly `AIM_BLEND_SECONDS`.
**Decision:** not adopted. Re-opened when recoil lands, where an asymptote is the *correct* shape. The
reason is written here so it is not re-litigated or re-researched.

### F. Frame-rate-independent interpolation — Rory Driscoll, "Frame rate independent damping using lerp"
<http://www.rorydriscoll.com/2016/03/07/frame-rate-independent-damping-using-lerp/>
Licence: a personal blog — **technique and reasoning only, no code.** Maintenance: static since 2016.
**Good:** it names the bug this design would otherwise ship: `value = lerp(value, target, 0.1)` per
frame gives a *different* transition at 30 fps and at 144 fps, so Karen's "0.2 s" would be a lie on her
machine and a different lie on a player's. The article's fix is `1 - exp(-k·dt)`.
**Bad:** the exponential form never actually reaches the target, so "aimed" stays a threshold, and the
constant `k` has no natural relation to a designer's "0.2 seconds".
**Adopted, with the amendment the article's "bad" forces:** a **time-accumulated linear parameter**
(`blend += dt / AIM_BLEND_SECONDS`, clamped to `[0,1]`) shaped by `Mode.ease`. Frame-rate independent
like the article demands, and it arrives exactly on time so that `blend == 1` is a fact rather than an
epsilon. The easing curve is Quad/Out, defined by
<https://create.roblox.com/docs/reference/engine/classes/TweenService> (first-party, maintained) and
written out as `1 - (1-t)^2` so the pure module needs no service and runs in a server spec.

### G. Roblox raycasting — the occlusion cast
<https://create.roblox.com/docs/workspace/raycasting> · first-party, maintained. Already source A of
`docs/design/shotgun.md` §10; the judgement below is this system's.
**Good:** `RaycastParams.FilterType = Exclude` plus the character is all a camera pull-in needs, and
`RaycastResult.Position` is the answer directly.
**Bad:** a single ray is infinitely thin, so the camera still clips a corner the ray misses — Roblox's
own stock camera uses a multi-cast "Popper" for this. One ray plus a pad is worse and cheaper.
**Adopted:** one ray per frame from the pivot to the desired position, pulled in by `OCCLUSION_PAD_STUDS`,
floored at `OCCLUSION_MIN_DISTANCE_STUDS`. Accepted as good enough for a grey box with eight cover
blocks; revisit with the Milestone 2 map. Injected through `Rig.setCast` so specs need no geometry.

### H. Borrowed from inside this repo (rule 2 applies to internal patterns too)
`src/server/Boar/init.luau` (`Boar.newRuntime`, `Boar.defaultWorld`, `Boar.CONFIG`, the exported
`Boar.Brain`) and `src/server/BoarBoot.server.luau`: an owner module that does nothing on `require`, a
pure decision module exported for specs, the world injected rather than looked up, and a boot script as
the composition root that knows two systems so that neither knows the other. `Camera.setAimSource` is
`Boar.defaultWorld` at smaller scale; `CameraBoot`'s adapter is `BoarBoot`'s wiring. The third system in
a repo either confirms the conventions or fights them.

**Pattern adopted overall:** a Scriptable camera written once per frame at the documented render
priority (A + C), with the stock camera module disabled and the stock controls kept (B), a
camera-parented viewmodel clone (D), a linear time-accumulated blend with a written-out ease instead of
a spring (F, E), one raycast occlusion pull-in (G), inside this repo's owner / pure-core /
instance-writer split (H). **Nothing is invented** except the tagged cursor-request API, which is one
refcount over one property and exists because this project's history demands a mechanism rather than a
rule (`docs/PROJECT_CONTEXT.md`, "Three scripts set the mouse cursor").

---

## 8. Numeric targets — the one config table

**Every number lives in `Camera.Config`, frozen, and nowhere else. No magic number outside it.**
Every angle is in **degrees** and says so in its name, converted to radians exactly once at the site
named in the right-hand column — the rule `docs/design/shotgun.md` §4 introduced after the Task 19
cone-unit defect cost a 2× error.

| Field | Value | Where from / converted where |
|---|---|---|
| `FOV_THIRD_DEG` | 70 | the engine's default `FieldOfView`; keeps the stock look. Assigned directly (the property is in degrees) |
| `FOV_AIM_DEG` | 50 | **feel (Karen).** 70→50 is 1.4× magnification: a bead sight, not a scope |
| `AIM_BLEND_SECONDS` | 0.20 | brief's feel default; `docs/research/2026-09-24-shotgun.md` states plainly that 0.2 s "appears in no source and is not derived" |
| `BLEND_EASE` | Quad/Out, as `1-(1-t)^2` | `Mode.ease`, the one site |
| `THIRD_DISTANCE_STUDS` | 12.0 | this design; ≈3.4 m behind, the usual third-person shooter framing |
| `SHOULDER_STUDS` | `Vector3.new(2.2, 0.35, 0)` | this design, camera space (+x right, +y up). **Right shoulder.** 2.2 keeps the fire ray beside the body (§6.1) |
| `PIVOT_HEIGHT_STUDS` | 1.6 | above `HumanoidRootPart`, ≈ eye height for the default rig |
| `AIM_PIVOT_FORWARD_STUDS` | 0.4 | the eye sits slightly ahead of the pivot so the aim camera is not inside the head |
| `PITCH_MIN_DEG` / `PITCH_MAX_DEG` | −72 / 78 | this design; short of ±90 so the camera never gimbals. Converted once, in `Mode.cameraCFrame` |
| `SENSITIVITY_DEG_PER_PIXEL` | 0.25 | **feel (Karen).** Converted once, in `Mode.step` |
| `AIM_SENSITIVITY_OVERRIDE` | `nil` | when nil, the scale is **derived**: `Mode.sensitivityScale` returns `tan(fovNow/2)/tan(fovThird/2)`, which keeps degrees-per-pixel constant *on screen* across the zoom. At FOV 50 that is 0.666. One conversion site, named, so the shotgun's unit defect cannot repeat |
| `MAX_DISTANCE_STUDS` | 14.5 | **hard clamp** in `Mode.cameraCFrame`. Must stay below the shotgun's `CAMERA_ORIGIN_TOLERANCE = 30` with margin (§6.1); asserted in both specs |
| `OCCLUSION_MIN_DISTANCE_STUDS` | 1.2 | this design; below it the camera is inside the character |
| `OCCLUSION_PAD_STUDS` | 0.5 | pulls in short of the surface the single ray found (§7 source G) |
| `SPAWN_PITCH_DEG` | −8 | looking slightly down on spawn; yaw is **kept** across a respawn |
| `VIEWMODEL_HIP_OFFSET` | `CFrame.new(0.9, -0.9, -1.2)` | the pose at blend 0, low and to the right — the start of the ADS sweep, mostly off the bottom of the screen |
| `VIEWMODEL_AIM_OFFSET` | `CFrame.new(0, -0.22, -0.9)` | the pose at blend 1: barrel centred under the view line. **Visual value: the screenshot and Karen decide it** |
| `VIEWMODEL_SHOW_BLEND` | 0.02 | below it the viewmodel is unparented, not merely invisible |
| `BODY_HIDE_BLEND` | 0.60 | above it the local character's parts get `LocalTransparencyModifier = 1` |
| `RENDER_STEP_NAME` | `"DrivenHunt.Camera"` | the reserved prefix; a grep for it finds every binding this system owns |
| `CURSOR_LOCKED_DEFAULT` | `true` | `MouseBehavior = LockCenter`, `MouseIconEnabled = false` whenever no `requestFree` tag is outstanding (§2 gives the reason: MouseButton2 is the aim button) |
| `FREE_CURSOR_ON_DEATH` | `false` | v1 has no death UI; the hook exists (§12, Director item C) |

### 8.1 The one derived number, written out

```
sensitivityScale(fovDeg) = tan(rad(fovDeg)/2) / tan(rad(FOV_THIRD_DEG)/2)
```
Called once per frame in `Mode.step`, with the **current blended FOV**, so the sensitivity eases
exactly in step with the zoom instead of snapping at a threshold. `AIM_SENSITIVITY_OVERRIDE`, if Karen
prefers a flat number, replaces the result and nothing else changes.

### 8.2 Performance and correctness targets, each one checkable

| Target | How it is checked |
|---|---|
| Camera update ≤ **0.3 ms/frame** at 60 fps | `Camera.stats().maxUpdateMs`, asserted in the client spec over ≥ 120 frames |
| **Exactly one** raycast per frame | the injected cast counts its calls in the client spec |
| **Zero** Instances created per frame (viewmodel built once per source change) | the client spec counts `workspace.CurrentCamera:GetDescendants()` across 120 frames |
| Viewmodel parts ≤ 4 | client spec |
| `Mode.step` ≤ 10 µs | server spec: 10,000 steps under 100 ms (the boar's `Brain:step` target and method) |
| `foreignCameraWrites == 0`, `cursorReasserts == 0` | client spec — **the mechanical one-writer proof** (§10.1) |
| `maxDistanceFromRoot` < 15 studs, and < 30 | client spec — the shotgun-validator guard (§6.1) |
| `blend` reaches exactly 1.0 after `AIM_BLEND_SECONDS` of accumulated dt, at any frame rate | server spec, stepped at 1/30 and at 1/240 |
| Typed-value harness problems from this task | **0** (§3.6) |

---

## 9. How it is tested

### 9.1 Server spec — `tests/server/camera_mode.spec.luau` (the pure module, no client needed)

`Camera.Mode` is pure and requires nothing but its `Config` sibling, so a **server** spec can require
`StarterPlayer.StarterPlayerScripts.Camera.Mode` and drive it with no player, no camera and no Studio
client — the same trick that lets `tests/server/boar_brain.spec.luau` run the boar's brain with no
world. Assertions:

1. `Mode.initial` is `Loading`, `blend == 0`, and the state is frozen (a write errors).
2. `hasCharacter` and `alive` → `Third` on the next step; `blend` stays 0.
3. `aiming = true` → `Aiming` immediately; `blend` rises; after exactly `AIM_BLEND_SECONDS` of
   accumulated dt it is `1.0`, **not 0.999** — stepped at `dt = 1/30` and again at `dt = 1/240`, both
   reaching 1.0 within 1e-6 and neither overshooting.
4. `aiming = false` → `Third`, and `blend` returns to exactly 0 in the same time.
5. A **mid-transition reversal** (release at blend 0.4) returns to 0 from 0.4, not from 1.
6. `alive = false` → `Dead`; `blend` decays; a `Dead` state ignores `aiming = true` entirely.
7. `hasCharacter = false` → `Loading` from every other state.
8. Pitch clamps at `PITCH_MIN_DEG`/`PITCH_MAX_DEG` under a 10,000-pixel delta; yaw wraps and stays in
   `(-180, 180]` after 100 full turns (no unbounded drift).
9. `Mode.sensitivityScale(FOV_THIRD_DEG) == 1` exactly; `sensitivityScale(FOV_AIM_DEG)` is in
   `(0.66, 0.67)` — a tan/degree mix-up fails this by more than an order of magnitude.
10. `Mode.cameraCFrame` at `blend = 0`: the camera is `THIRD_DISTANCE_STUDS` behind the pivot along the
    look direction, plus the shoulder offset, and **`(cam.Position - root.Position).Magnitude <=
    MAX_DISTANCE_STUDS`**; and that number is **< 30**, the shotgun's `CAMERA_ORIGIN_TOLERANCE`, written
    out as its own assertion with a comment naming `docs/design/shotgun.md` §11 (§6.1).
11. `Mode.cameraCFrame` at `blend = 1`: within 0.5 studs of the pivot, and the FOV is `FOV_AIM_DEG`.
12. Every returned state is frozen and is a different table from the input.
13. 10,000 steps under 100 ms.

**Fallback (rule 6/8).** If requiring a `StarterPlayerScripts` ModuleScript from the server turns out
not to work in this place, every assertion above moves verbatim into the client spec and the server
spec is deleted. The Builder reports which happened; nothing about the design changes.

### 9.2 Client spec — `tests/client/camera_client.spec.luau` (the real camera, in the real client)

Reached through `Players.LocalPlayer:WaitForChild("PlayerScripts").Camera`, never through
`StarterPlayerScripts`, which is a template (`docs/design/shotgun.md` §3.2).

1. **One writer, mechanically.** After ≥ 120 frames: `Camera.stats().foreignCameraWrites == 0` and
   `Cursor.stats().reasserts == 0`. Nothing but `Rig.apply` set the camera and nothing but `Cursor`
   set the mouse — a *detection*, not a promise (§10.1).
2. `workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable`, and `Rig.acquire` reported
   success (the stock `PlayerModule` cameras are off).
3. `Camera.getMode() == "Third"` and `FieldOfView` within 0.01 of `FOV_THIRD_DEG`.
4. **The aim path, with an injected fake source** (`Camera.setAimSource`, restoring the production
   source in `afterAll`): set aiming → within `AIM_BLEND_SECONDS + 0.3 s`, `getMode() == "Aiming"`,
   `getBlend() == 1`, `FieldOfView` within 0.01 of `FOV_AIM_DEG`, and
   `(CurrentCamera.CFrame.Position - HumanoidRootPart.Position).Magnitude < 2.5`.
   Clear it → back to `Third`, FOV back, `blend == 0`.
5. **The viewmodel, with the whole ancestor chain walked.** While aiming: `Viewmodel.current()` is a
   `Model`, **its `Parent` is `workspace.CurrentCamera`**, that camera **is** `workspace.CurrentCamera`
   (not a stale one), every part has `Transparency < 1` **and** `LocalTransparencyModifier < 1`, every
   part has `CanQuery == false`, and no ancestor up to the DataModel is missing. This is
   "a visibility audit ignored parent visibility and certified a blank screen twice"
   (`docs/PROJECT_CONTEXT.md`) written as assertions. **It does not replace the screenshot.**
6. Not aiming → `Viewmodel.current() == nil` (unparented, not merely transparent), and
   `stats().viewmodelParented == false`.
7. **The shotgun-validator guard, live:** over the whole run,
   `Camera.stats().maxDistanceFromRoot < 15` and `< 30`, with a comment naming
   `docs/design/shotgun.md` §11 `CAMERA_ORIGIN_TOLERANCE`.
8. **Occlusion, with an injected cast** (`Rig.setCast`): a cast returning a point 4 studs from the
   pivot puts the camera at `4 - OCCLUSION_PAD_STUDS` from it, floored at
   `OCCLUSION_MIN_DISTANCE_STUDS`; a cast returning `nil` leaves the desired position untouched; the
   cast is called exactly once per frame (counted).
9. **Budget:** `stats().maxUpdateMs < 0.3` over ≥ 120 frames, and
   `#workspace.CurrentCamera:GetDescendants()` does not grow across those frames.
10. **The cursor contract:** `MouseBehavior == LockCenter` and `MouseIconEnabled == false` by default;
    `Cursor.requestFree("spec")` → `Default` and the icon back within one frame; `Cursor.release("spec")`
    → locked again; two outstanding tags need two releases.
11. **Teardown:** `Camera.stop()` leaves no `DrivenHunt.Camera` render binding
    (`RunService:UnbindFromRenderStep` by name), no viewmodel, a free cursor and
    `CameraType == Custom`. Done in `afterAll`, not asserted after doing it inside the `it` — Task 6a
    note (a) is the record of that mistake, and this spec does not repeat it.

### 9.3 Harness-driven input — the real player's path (rule 6)

Task 6 landed and Task 7 is closed (`TASKS.md` rows 6 and 7), so this is available today. **One
scenario is added** to `tests/client/input_scenarios.txt`:

```json
{ "name": "aim-hold", "spec": "ClientTests.camera_client.spec", "steps": [
  { "device": "mouse", "action": "moveTo", "x": 400, "y": 300 },
  { "device": "wait", "ms": 200 },
  { "device": "mouse", "action": "mouseButtonDown", "button": "right" },
  { "device": "wait", "ms": 600 },
  { "device": "mouse", "action": "mouseButtonUp",   "button": "right" },
  { "device": "wait", "ms": 400 } ] }
```

This also closes **Task 6a note (g)** — `"button": "right"` is "documented, validated and mapped but
never sent" today, and this is the first scenario that sends it.

What it proves, asserted from the owner's own counters (`Camera.stats().aimEnters/aimExits` and a mode
history the owner records from boot, so the assertion does not depend on when TestEZ happened to start):
right mouse **down** put the real camera into `Aiming` through the real
`ContextActionService` binding the weapon owns, and **up** took it out. That is the brief's "which input
scenario proves right-mouse aim in and out".

**It requires the shotgun's Tool to be equipped**, since `DrivenHunt.Weapon.Aim` is bound on
`Tool.Equipped`. The scenario therefore starts with a `keyPress` of `One` to equip from the hotbar.
**Unverified** (§13): whether a replayed number-key press reaches the CoreGui backpack. If it does not,
the Builder reports it (rule 6 — a harness fault is a bug) and the end-to-end assertion falls back to
§9.2 item 4's injected source, with the gap stated plainly in the review request rather than papered
over.

**What the harness cannot do here**, from the `tools/studio_mcp.py` docstring and `TASKS.md` row 6:
touch and gamepad input; a hold measured in frames; input aimed at an instance; anything after the
client report is written; and — this one matters most for a camera —
**an absolute `moveTo` under `MouseBehavior = LockCenter` may deliver no usable `InputObject.Delta`**,
so *rotation* by replayed input may be untestable. The rotation maths is covered by the pure server
spec regardless; if the replay does produce deltas, the client spec adds a yaw-changed assertion, and
if not, it says so. The fallback uses the public API, not a test-only hook: the spec calls
`Cursor.requestFree("spec")`, replays a move under `Default` behaviour, asserts yaw moved, and
releases.

**A risk this task creates for an existing spec, named now so it is not a surprise.** From the moment
this system ships, every Play session — including every harness run — starts mouse-locked. Task 6's
`tests/client/input_driving.spec.luau` asserts `uisMove >= 1` from a replayed `moveTo`. If locking the
cursor breaks that, it is a real finding about the game's own environment, **not** something to be
worked around by unlocking the mouse during tests: a harness that tests an unlocked cursor while
players get a locked one is exactly the "harness was wrong as often as the game" failure. The correct
fix, if it is needed, is for `input_driving.spec` to take a `Cursor.requestFree` tag for its duration.

### 9.4 Screenshots — rule 5, required, four of them

`python tools/studio_mcp.py capture <name> [camera x,y,z] [look-at x,y,z]` saves to `.screenshots/`
and works during Play (`TASKS.md` row 7, closed; used in Tasks 17, 18, 22). A camera and a viewmodel
are the most visual things in the game so far, and a number is not a verification
(`docs/PROJECT_CONTEXT.md`):

1. **Third person, walking:** the character seen over the right shoulder, the whole body visible, the
   shotgun in hand pointing forward — the `GRIP` check again ("a knife held backwards for three
   rounds"), now from the camera that will ship.
2. **Fully aimed:** the viewmodel shotgun in view, the barrel where the config says, the local
   character's body **not** drawn over the screen, the crosshair gone.
3. **Aimed at the boar at ~60 studs:** the boar framed by the sight line; the FOV change is visible by
   comparing it with shot 1 from the same spot.
4. **Camera against a cover block:** the character still visible, the camera pulled in, no clipping
   through the block and no view from inside the character.

Describe what is actually on screen, not what should be.

---

## 10. Failure modes, and how each one is loud

### 10.1 A second camera writer — the detector

`Rig.apply` stores what it wrote. On the next frame, before writing again, it compares
`cam.CFrame` and `cam.FieldOfView` with that record. A difference means something else wrote the camera
between frames: increment `foreignCameraWrites`, and `warn` **once** with the count and the offending
values. `Cursor.apply` does the same for the mouse.

This is the single most valuable thing in this design. `docs/design/shotgun.md` §13.5 proposed a CI grep
for camera assignments and deferred it under the tooling freeze; a grep catches only our own source
anyway. This catches the stock `PlayerModule` coming back after a Studio update, a plugin, a future
teammate's LocalScript, and any file the grep would have missed — **at runtime, in the failing case,
with a number a spec can assert on.** It is rule 3 enforced by mechanism instead of by policy.

| Failure | How it is loud |
|---|---|
| The stock camera is not disabled | `Rig.acquire` returns `(false, reason)`; `Camera.start` warns; the client spec fails at §9.2 item 2; and even a silent failure shows as `foreignCameraWrites > 0` |
| Something else writes the mouse | `cursorReasserts > 0`, asserted zero |
| The viewmodel leaks (still there while not aiming) | `stats().viewmodelParented`, asserted false in `Third`; and the parts are unparented, not hidden, so a leak is visible on screen |
| A viewmodel part blocks the occlusion ray | `CanQuery = false` on every part, asserted; symptom otherwise is a camera glued 1.2 studs behind the head |
| The camera update errors or yields | one `pcall`-free callback by design; an error in `BindToRenderStep` is printed by the engine every frame, which is loud. The owner does **not** swallow it |
| The character is missing | mode `Loading`, last CFrame held, no error and no spam — the tested path, not an accident |
| A respawn resets `CameraType` | `Rig.acquire` re-runs on `CharacterAdded`; §9.2 item 2 runs after the spec's own spawn |
| The camera drifts beyond the shotgun's validator tolerance | `MAX_DISTANCE_STUDS` clamps it, two specs assert it, and the symptom otherwise would be the server rejecting honest shots with `"origin-far"` — exactly the Task 19 defect 4 that this repo has already paid for once |

---

## 11. Rows for `GAME_DESIGN.md` — ready to paste

Rule 3 requires the owners table to mirror this file. **Fill the existing `Camera` row** (it reads
`_unassigned_`) and add three rows; do not add a fifth Camera row.

| System | Owner (the only writer) | Location | Research note |
|---|---|---|---|
| **Camera** (`workspace.CurrentCamera`: `CFrame`, `FieldOfView`, `CameraType`, `CameraSubject`) and the camera mode state | `PlayerScripts.Camera`, booted once by `PlayerScripts.CameraBoot`. `Camera.Rig` is the only module that assigns the camera and the only one that disables the stock `PlayerModule` cameras; `Camera.Mode` is pure and exported for specs. It writes nothing drawn, no character property, no weapon state and no remote | `src/client/Camera/`, `src/client/CameraBoot.client.luau` | [shotgun](docs/research/2026-09-24-shotgun.md) sources 4–5, [design](docs/design/camera.md) |
| Viewmodel (the first-person weapon model under `workspace.CurrentCamera`) | `PlayerScripts.Camera.Viewmodel`. It clones the Tool's `Handle` and never writes the original; the clone is local, unreplicated and `CanQuery = false`, so it can never affect a hit | `src/client/Camera/Viewmodel.luau` | same |
| Cursor and mouse lock (`UserInputService.MouseBehavior`, `.MouseIconEnabled`, `.MouseDeltaSensitivity`, `Mouse.Icon`) | `PlayerScripts.Camera.Cursor`. Other systems **request** a free cursor by tag (`requestFree`/`release`) and never write the mouse | `src/client/Camera/Cursor.luau` | same |
| Aim state (is the player asking to aim) | **writer:** `PlayerScripts.Weapon.Input` (`Input.AimChanged`). **Readers:** the camera, through the adapter in `CameraBoot`. The camera's own `getMode()`/`getBlend()` is the *state*; the weapon's flag is the *request*, and anything asking "is the view in aim" reads the camera | `src/client/Weapon/Input.luau`, `src/client/CameraBoot.client.luau` | [shotgun design](docs/design/shotgun.md) §9 |

**Amend the `UI / anything drawn` row** (which the shotgun design fills) by appending:

> … It decides the crosshair from `Weapon.get().equipped` **and** `Camera.getMode()`; the camera never
> touches anything drawn ([camera design](docs/design/camera.md) §6.2).

**Input** stays `_unassigned_` as a system, deliberately: there is no global input router. Each system
owns its named bindings under a reserved prefix — `DrivenHunt.Weapon.*` for the weapon, and
`DrivenHunt.Camera.*` reserved here (v1 binds no action; the camera reads mouse movement through its
one `UserInputService.InputChanged` connection, because `ContextActionService` cannot bind movement).

---

## 12. Open decisions — none of them blocks building

Every one has a default written into §8 or into this document. They are things to overrule on purpose
rather than by accident.

### Karen (feel) — the "check this" list for the first camera playtest (`ROADMAP.md` speed rule 8)

1. **Is the mouse locked all the time the right call?** It is forced by MouseButton2 being the aim
   button (§2). The cost is that you cannot click anything without a UI that asks for the cursor.
2. **`FOV_AIM_DEG = 50`** — is aiming zoomed enough to shoot a boar at 100 studs, and not so zoomed it
   feels like a scope?
3. **`THIRD_DISTANCE_STUDS = 12` and the right shoulder** — too far, too close, wrong shoulder? Driving
   on foot with dogs is most of the game; the camera has to be comfortable for ten minutes.
4. **`SENSITIVITY_DEG_PER_PIXEL = 0.25`**, and whether the derived aim sensitivity (0.666× at FOV 50)
   feels right or should be a flat number (`AIM_SENSITIVITY_OVERRIDE`).
5. **Does the crosshair disappearing while aiming feel right**, or should it stay (§6.2)? One boolean.
6. **`AIM_BLEND_SECONDS = 0.20`** — is ADS snappy enough with a boar running?
7. **The viewmodel's position** (`VIEWMODEL_AIM_OFFSET`) — the screenshot decides where the barrel sits,
   you decide whether it looks like a gun you are holding.

### Director (scope)

- **A. Character rotation while aiming (§6.4).** Default: **not in 1.4b.** Other players see a shooter
  whose body may face elsewhere. Fixing it needs a character/movement owner, which does not exist; it
  is a new `GAME_DESIGN.md` row and its own small design, best taken with 1.7 (teams and the drive
  line), where character facing starts to matter for the safety rule.
- **B. Viewmodel arms.** Default: **no arms in v1** — the viewmodel is the Tool's `Handle` clone alone
  (a grey box on a grey box). Arms need a rig and art (Milestone 2/3), and §7 source D's
  stripped-character-clone technique is the named path when they arrive; nothing in this interface
  changes.
- **C. The cursor on death.** Default: stays locked (`FREE_CURSOR_ON_DEATH = false`), because v1 has no
  death or score UI to click. When 1.7 adds one, that UI calls `Cursor.requestFree("deathUi")` — the
  hook exists and needs no camera change.
- **D. Gamepad and touch.** Default: **PC only for v1's playtests**, which the brief accepts. The stock
  `PlayerModule` **controls** stay enabled, so a gamepad or a phone can still *move*; they cannot
  *look*, because the stock camera that normally handles right-stick and drag is the thing we disabled.
  That is a real, named gap, not an oversight: right-stick look is ~10 lines against
  `UserInputService.InputChanged` (`Thumbstick2`) into the same `lookDelta`, and touch drag needs a
  design decision about where the aim button goes on a phone.
- **E. Zoom control in third person.** Default: **fixed distance, no mouse-wheel zoom.** Roblox players
  expect a zoom; a variable distance also makes the shotgun's origin tolerance a moving target (§6.1).
  If it is wanted, it is one clamped number and the `MAX_DISTANCE_STUDS` assertion stays the guard.
- **F. Recoil and sway.** Default: **not this task.** Recoil is the weapon's feel, it belongs with the
  shot, and it is the one place a spring is the right tool — `egomoose/fractality-spring` (MIT) with
  the Wally/Connect cost named in §7 source E.

---

## 13. What I could not verify (rule 8)

- **Anything requiring Roblox Studio.** No Studio in this session (`.agent-evidence/INDEX.md`). Every
  claim about what the harness *would* do is read from `tools/studio_mcp.py`'s docstring and from
  `tests/client/input_driving.spec.luau`, not observed.
- **`PlayerModule:GetCameras():Disable()`.** This is the load-bearing engine call of the whole design
  (§6.3) and it comes from my own knowledge of the stock `PlayerModule`, not from a page I read this
  session. `Rig.acquire` returns a failure reason and §10.1 detects the silent case, so a wrong
  assumption here is loud rather than fatal — but the Builder **confirms it first**, in the
  research-note addendum, before writing the rest.
- **Whether a server spec can require a `StarterPlayerScripts` ModuleScript** (§9.1). The fallback is
  written; the Builder reports which path was taken.
- **Whether a replayed absolute `moveTo` yields a mouse delta under `LockCenter`** (§9.3), and whether
  a replayed `keyPress` of `One` equips a Backpack tool. Both are harness questions with stated
  fallbacks, and both are reportable facts, not assumptions to bury.
- **Whether locking the cursor breaks `tests/client/input_driving.spec.luau`** (§9.3). It is a
  cross-task risk created by this system; the correct response if it happens is a finding and a
  `Cursor.requestFree` tag in that spec, never a camera that behaves differently under test.
- **The external sources' current licence and maintenance status.** No network this session. A, B, C
  and the TweenService/raycasting pages are first-party Roblox documentation (creator-docs is CC BY
  4.0) and the APIs ship with the engine; D and F are cited for technique only with **no code taken**;
  E (MIT) is deliberately not used. The Builder confirms them in the research-note addendum before
  relying on any of them.
- **Every number in §8 is a starting point, not a measurement.** FOV, distance, shoulder offset,
  sensitivity and the viewmodel offsets have never been on a screen. The 0.2 s blend is the brief's
  feel default and `docs/research/2026-09-24-shotgun.md` says outright that it "appears in no source
  and is not derived". Karen decides all of them, and the screenshot decides the viewmodel.
- **The shotgun's client half does not exist yet** (Task 24 unmerged; `.agent-evidence/ls-files.txt`
  shows no `src/client/Weapon/`). Every symbol this design names in it — `Weapon.get`,
  `Weapon.Input.isAiming`, `Input.AimChanged`, `Hud` — is read from `docs/design/shotgun.md` §3.2,
  §3.4 and §5.5, not from code. If the build deviates from that design, the adapter in `CameraBoot`
  (§4.4) is the one place that changes.
