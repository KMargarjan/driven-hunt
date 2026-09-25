# Design: boar-ai (grey box, v1)

System: `boar-ai` — one wild boar that idles, flees from a threat, routes to the exit edge and
despawns. ROADMAP step 1.2 (`ROADMAP.md:53`), TASKS Task 18, research note
`docs/research/2026-09-24-boar-ai.md` (rule 1, written before this design; indexed at
`docs/research/INDEX.md:7`).

Written against commit `3de9573` (`.agent-evidence/INDEX.md:3`). Read-only session: Read, Grep, Glob
only, no Studio, no network. See **Not verified** at the end.

This is the `animal` slot that `docs/architecture/audit-002.md:222` (L2) put second in the design
queue. The Director dispatched it as `boar-ai`; the owner row in `GAME_DESIGN.md` uses that name.

---

## 1. What it must do

From the research note (`docs/research/2026-09-24-boar-ai.md:6-21`) and ROADMAP speed rule 5
(`ROADMAP.md:16`, "one whole system per task: the boar AI: idle, flee, route, despawn"):

1. Spawn one boar body: a grey box, **unanchored**, physically simulated, **server-owned**, so no
   client can push it.
2. **IDLE** — wander/graze slowly inside a home area around the spawn point.
3. **FLEE** — react within 0.5 s when a threat comes inside the detection radius, and run away from
   it around the cover blocks.
4. **Route** — while fleeing, head for the far (north) edge of the arena, the future shooter line, not
   just directly away from the threat, and never through the threat.
5. **Despawn** — on reaching the exit edge or leaving the arena bounds, remove the body and fire one
   signal carrying enough for the future score system.
6. Exactly one writer for boar state (rule 3, `CLAUDE.md:22`), and "who scares the boar" must be
   **one function**, so drivers-only can be plugged in later without touching the state machine.

## 2. What it must not do

- **No client code at all.** No LocalScript, no RemoteEvent, no client-side movement or prediction.
  The body is a Part in Workspace and replicates as one. This is deliberate: it keeps the system
  clear of the two blocking harness gaps, driving real input (Task 6, `TASKS.md:12`) and play-time
  screenshots (Task 7, `TASKS.md:13`), for everything except rule 5's screenshot (§10).
- **Must not write anything in Workspace except its own folder.** Not `Workspace.TestArena` (owner:
  `ServerScriptService.TestArena`, `GAME_DESIGN.md:24`), not the place's default `Baseplate` or
  `SpawnLocation` (Studio content, `ESCALATE.md:71-73`), not player characters.
- **Must not use a `Humanoid`, `Humanoid:MoveTo`, or direct `CFrame`/`Position` writes per frame.**
  The body moves only through the physics mover in §6. Two systems writing a creature's position is
  named as a cause of death of the previous project (`docs/PROJECT_CONTEXT.md:35-36`).
- **Must not be anchored.** `SetNetworkOwner` errors on an anchored part
  (`docs/research/2026-09-24-boar-ai.md:88-91`).
- **Must not yield inside the step.** `Path:ComputeAsync` yields; it runs in its own thread (§6).
- **Must not own damage, hit zones, wounded running, blood, dogs, teams, score, respawn or spawn
  waves.** Hit zones are Milestone 1.5 (`ROADMAP.md:56`); the match loop is 1.7 (`ROADMAP.md:58`).
  This system emits `Despawned` and nothing else.
- **Must not come from a `.model.json`.** See §9 — the harness cannot compare typed property values,
  so a positioned Part on disk fails the run today.
- **Must not have side effects on `require`.** Only `BoarBoot` starts production, so a spec can
  require the module and test the brain with no boar in the world.

---

## 3. Owner and location

One writer per thing, named (rule 3, `CLAUDE.md:22`). `src/server/` maps to `ServerScriptService`
(`CLAUDE.md:213`); a folder with `init.luau` becomes that ModuleScript with its children as
descendants (`CLAUDE.md:241`), so no `default.project.json` change and no `.meta.json` is needed.

| Disk | Studio | Writes (nobody else may) | Called by |
|---|---|---|---|
| `src/server/Boar/init.luau` | `ServerScriptService.Boar` | **the system owner**: `CONFIG`, runtime list, the `Heartbeat` loop, the `Despawned` signal, the path threads | `BoarBoot`, server specs |
| `src/server/Boar/Brain.luau` | `…Boar.Brain` | boar *decision* state (state name, heading, timers, waypoint index). Pure: no services, no yields, no instances | only `Boar` (init.luau) and `boar_brain.spec` |
| `src/server/Boar/Body.luau` | `…Boar.Body` | **every boar instance**: the folder, the Part, `LinearVelocity`, `AlignOrientation`, `SetNetworkOwner(nil)`, and the only `Destroy` | only `Boar` (init.luau) |
| `src/server/BoarBoot.server.luau` | `ServerScriptService.BoarBoot` | nothing. Boot line only, mirroring `ArenaBoot.server.luau:1-8` | the engine, at server start |

`Workspace.Boars` (production folder) is created and destroyed only by `Body`, which is called only
by `Boar`. Workspace is not Rojo-mapped (`CLAUDE.md:205-207`), so a runtime folder there is legal and
matches what `TestArena.build` already does (`src/server/TestArena.luau:73-117`).

Row to add to the *System owners* table in `GAME_DESIGN.md` (rule 3 mirror, `GAME_DESIGN.md:15-16`):

> | Boar AI: state, movement and lifetime of every boar (`Workspace.Boars` and everything in it) | `ServerScriptService.Boar`, booted once by `ServerScriptService.BoarBoot`. `Boar.Brain` (decisions) and `Boar.Body` (instances) are private to it and called by nothing else. It writes nothing else in Workspace | `src/server/Boar/`, `src/server/BoarBoot.server.luau` | [boar-ai](docs/research/2026-09-24-boar-ai.md), [design](docs/design/boar-ai.md) |

---

## 4. Public interface

Types are Luau annotations; `luau-lsp analyze` is not in CI yet (Task 3, `TASKS.md:9`), so they are
documentation plus editor checking, not a gate.

```luau
-- ServerScriptService.Boar
export type State = "IDLE" | "FLEE" | "GONE"
export type DespawnReason = "escaped" | "outOfBounds"

export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Field  = { bounds: Bounds, exitZ: number, groundY: number }
export type Threat = { id: string, position: Vector3 }

export type World = {
    field: Field,
    parent: Instance,          -- production: Workspace
    folderName: string,        -- production: "Boars"
    threats: () -> { Threat },
    probe: (from: Vector3, direction: Vector3, length: number) -> boolean, -- true = something solid
    requestPath: (from: Vector3, to: Vector3, done: ({ Vector3 }?) -> ()) -> (),
    rng: Random,
    config: { [string]: any }?, -- shallow overrides merged over Boar.CONFIG, for specs
}

export type DespawnRecord = {
    id: string,
    reason: DespawnReason,
    position: Vector3,
    aliveFor: number,   -- seconds
}

export type Handle = {
    id: string,
    part: BasePart,          -- read-only to everyone but Body
    state: () -> State,
    position: () -> Vector3,
}

Boar.CONFIG: Config                       -- every number in §7; the one table, as the note promised
Boar.defaultWorld(field: Field?): World   -- production implementations; field defaults to CONFIG.field
Boar.newRuntime(world: World): Runtime    -- independent; nothing global
```

```luau
-- Runtime
Runtime.Despawned: RBXScriptSignal        -- fires (record: DespawnRecord), once per boar
Runtime:spawn(position: Vector3?): Handle -- default: CONFIG.spawnPoint. Errors past CONFIG.maxBoars
Runtime:step(dt: number)                  -- one tick; specs call this directly, deterministically
Runtime:run(): () -> ()                   -- connects RunService.Heartbeat; returns a disconnect fn
Runtime:boars(): { Handle }               -- snapshot copy, not the live table
Runtime:stats(): { pathRequests: number, pathFailures: number, spawned: number, despawned: number }
Runtime:destroy()                         -- disconnect, destroy the folder, drop all state
```

```luau
-- Boar.Brain (private; required by init.luau and by boar_brain.spec)
export type Observation = {
    position: Vector3,
    velocity: Vector3,
    threats: { Threat },
    waypoints: { Vector3 }?,  -- newest successful path, already trimmed by the Brain as it advances
    pathFailed: boolean,      -- the last request came back nil
    blockedAhead: boolean,    -- world.probe along the current facing, PROBE_LENGTH studs
}

export type Intent = {
    state: State,
    targetVelocity: Vector3,  -- world, Y always 0
    facing: Vector3?,         -- unit XZ; nil = keep the current facing
    pathRequest: Vector3?,    -- ask for a path to this point this tick, else nil
    despawn: boolean,
    reason: DespawnReason?,
}

Brain.new(config: Config, field: Field, start: Vector3, rng: Random): Brain
Brain:step(dt: number, obs: Observation): Intent
Brain:state(): State
Brain:debug(): { home: Vector3, heading: Vector3, target: Vector3?, sinceThreat: number }
```

**Remotes: none.** **Threat identity is injected data, not input events** — the reason no harness
input work (Task 6) is needed.

`Despawned` is a `BindableEvent` created in code and held by the Runtime, exposed as its `.Event`.
Rejected alternative in §8 (source 9). Two consequences the Builder must respect: the payload is a
plain dictionary (BindableEvent copies tables, so no metatables and no mixed-key tables), and under
`SignalBehavior = Deferred` a listener does not run inside `Fire`, so the live spec polls for up to
1 s instead of asserting on the next line (§10).

### Who is a threat — the one function (note requirement 6)

```luau
CONFIG.isThreat = function(_player: Player): boolean
    return true -- v1: every player. Milestone 1.7: `player.Team == Teams.Drivers`.
end
```
`Boar.defaultWorld().threats` is the only caller: it walks `Players:GetPlayers()`, keeps those where
`CONFIG.isThreat(player)` is true and whose character has a `PrimaryPart`, and returns
`{ id = tostring(player.UserId), position = primaryPart.Position }`. Swapping teams in later touches
this one function and nothing in `Brain`.

---

## 5. Behaviour: states, transitions, formulas

Three states. The ROADMAP's word "route" (`ROADMAP.md:53`) is **not** a state here: it is
`routeTarget()`, the destination function used by FLEE. One fewer state, and the routing rule stays
testable on its own.

| State | Speed setpoint | Path | Leaves when |
|---|---|---|---|
| `IDLE` | `WANDER_SPEED`, or 0 while grazing | none (steering + probe only) | a threat is within `DETECT_RADIUS` (flat XZ distance) → `FLEE` |
| `FLEE` | `SPRINT_SPEED` while any threat is within `DETECT_RADIUS`, else `TROT_SPEED` | repath to `routeTarget()` every `REPATH_INTERVAL` | no threat within `CALM_RADIUS` for `CALM_TIME` → `IDLE` (home centre resets to the current position); crossing the exit line or the bounds → `GONE` |
| `GONE` | 0 | none | terminal. `despawn = true` is returned exactly once |

Sensing runs on a `SENSE_INTERVAL` accumulator inside `Brain:step`, not per frame. Movement
integration runs every step. `dt` is clamped to `DT_CLAMP` so a server hitch cannot fling the boar.

**IDLE — Reynolds wander** (`docs/research/2026-09-24-boar-ai.md:71-79`): keep a persistent unit
heading; each sense tick rotate it by `rng:NextNumber(-WANDER_JITTER, WANDER_JITTER)` radians. Not a
fresh random vector per tick — that is what makes it look like an animal rather than a twitching box.
- Beyond `HOME_RADIUS` from the home centre: `heading = unit(heading + toHome * HOME_PULL)`.
- `blockedAhead`: rotate the heading by `±(PROBE_TURN + jitter)`, sign chosen by `rng`.
- Grazing: with probability `GRAZE_CHANCE` per tick, set the setpoint to 0 for
  `rng:NextNumber(GRAZE_MIN, GRAZE_MAX)` seconds.

**FLEE — route target** (the note's requirement 4, `:18-19`), evaluated on every repath:
```
c        = XZ centroid of threats inside DETECT_RADIUS (nearest threat if none inside)
lateral  = sign(position.X - c.X)              -- +1 when equal
onExitSide = (c.Z - field.exitZ) * sign(field.exitZ - position.Z) > 0   -- threat between boar and exit
bias     = ROUTE_SIDE_BIAS * (onExitSide and 2 or 1)
targetX  = clamp(position.X + lateral * bias, bounds.minX + EDGE_MARGIN, bounds.maxX - EDGE_MARGIN)
target   = Vector3.new(targetX, field.groundY, field.exitZ)
```
The doubled bias is the "never run through the driver" rule, and it is one assertion in the spec.

**FLEE — following the route.** Steer to `waypoints[1]`; drop it when the flat distance is under
`WAYPOINT_RADIUS`. If `waypoints` is nil or `pathFailed`, fall back to Reynolds flee — straight away
from the threat centroid, blended 50/50 with the direction to `target` — so the boar never freezes
because pathfinding failed. Ask for a new path when `sinceRepath ≥ REPATH_INTERVAL`, when the
waypoint list empties, or when stuck.

**Stuck.** If the position has moved less than `STUCK_DIST` in `STUCK_TIME` while the setpoint was
non-zero: repath, and on the second consecutive time add a 90° lateral offset to the heading for one
tick.

**Turning and acceleration are on the setpoint, not the physics.** The desired direction slews at
`TURN_RATE` rad/s and the desired speed ramps at `ACCEL` studs/s²; `targetVelocity` is the result.
So the box never snaps 180° and never jumps to sprint, and both are asserted in the pure spec with no
physics at all.

**Despawn.** `position.Z ≤ field.exitZ` → `escaped`. Outside `bounds` grown by `BOUNDS_SLACK`, or
`position.Y < field.groundY - FALL_LIMIT` → `outOfBounds`. `Boar` then calls `Body.destroy`, removes
the handle, and fires `Despawned` once with the record.

---

## 6. Movement and the body (`Body.luau`)

One Part, no model, no mesh, no `Humanoid`:
- `Size = Vector3.new(2, 3, 5.5)` — width X, height Y, **length Z**, because a part's `LookVector` is
  its −Z, so facing and length agree. Grey (`Color3.fromRGB(90, 80, 70)`), `SmoothPlastic`, matching
  the arena's construction idiom (`src/server/TestArena.luau:56-68`).
- `Anchored = false`, `CanCollide = true`, spawned at `groundY + Size.Y / 2 + 0.5`.
- After parenting: `part:SetNetworkOwner(nil)` on the server. Anchored parts cannot have an owner set
  at all, which is why the body must be unanchored
  (`docs/research/2026-09-24-boar-ai.md:84-91`, source 4).
- Mover: one `LinearVelocity` on one `Attachment`, `RelativeTo = World`,
  `VelocityConstraintMode = Plane`, plane axes X and Z, `PlaneVelocity = Vector2.new(v.X, v.Z)`,
  `MaxForce = MAX_FORCE`. Plane mode leaves the plane normal (Y) free, so gravity — not the
  constraint — owns falling and resting on the ground
  (`docs/research/2026-09-24-boar-ai.md:93-102`, source 5).
  **Fallback, if Plane mode does not behave as documented:** `VelocityConstraintMode = Vector`,
  `ForceLimitMode = PerAxis`, `MaxAxesForce = Vector3.new(MAX_FORCE, 0, MAX_FORCE)` — zero force on Y
  has the same effect. The Builder records which one it used in the research-note addendum (§11).
- Upright and facing: one `AlignOrientation`, `Mode = OneAttachment`, `RigidityEnabled = false`,
  `Responsiveness = ALIGN_RESPONSIVENESS`, `MaxTorque = MAX_TORQUE`, `CFrame` set to
  `CFrame.lookAt(Vector3.zero, facing)` each tick. Without it a driven box tips and rolls (source 6).
- `Body.destroy(handle)` destroys the Part (constraints go with it) and, when the last boar is gone,
  leaves the folder in place. It never destroys anything it did not create.

**Pathfinding never touches the step.** `Boar.defaultWorld().requestPath` does
`task.spawn(function() … Path:ComputeAsync … done(waypoints or nil) end)`, one `Path` object per
agent created once with `AgentRadius = 2, AgentHeight = 3, AgentCanJump = false, AgentCanClimb =
false`. `done` is called on a later frame; `Boar` stores the result and hands it to the Brain on the
next step as `obs.waypoints`. At most one request per boar is in flight; a late reply for a
despawned boar is dropped. `Path.Blocked` is connected and, if `blockedWaypointIdx` is ahead of the
current index, forces a repath — the one part of SimplePath's loop worth copying
(source 2, `docs/research/2026-09-24-boar-ai.md:56-68`).

---

## 7. Numeric targets

### The scale premise in the research note is wrong, and correcting it makes the numbers agree

`docs/research/2026-09-24-boar-ai.md:28` says "the project's own scale is 1 stud ≈ 1 m", concludes
that a real boar's 40 km/h would be ~11 studs/s and therefore that 38 studs/s is a feel number in
conflict with physics. A grep of every `.md` in the repo finds that claim in that one line and
nowhere else: no design, ROADMAP or GAME_DESIGN statement sets a scale, so it has no source.
Roblox's own convention is **1 stud ≈ 0.28 m** (source 7), which the engine's defaults agree with —
a default character is about 5 studs tall, i.e. ~1.4 m, not 5 m.

At 0.28 m/stud: 40 km/h = 11.1 m/s = **39.7 studs/s**. So 38 studs/s is not a compromise, it is the
physically correct sprint speed, and it sits in the Director's 35–40 band. The same correction moves
the body: the note's "1.5 × 1 × 0.6 stud body" (`:28`) would be a 42 cm boar, smaller than a
football next to a 5-stud player. A 1.5 m × 0.9 m × 0.5 m boar is **5.5 × 3 × 2 studs**, which is
what §6 specifies — the boar's back at 3 studs against a ~5-stud player, the right ratio for a big
European boar.

### The table

Every one of these lives in `Boar.CONFIG` in `init.luau`, as the note promised (`:36`).

| Name | Value | Basis |
|---|---|---|
| `SPRINT_SPEED` | 38 studs/s | 40 km/h at 1 stud = 0.28 m (source 7). Karen may retune (§12) |
| `TROT_SPEED` | 18 studs/s | Must exceed the default `Humanoid.WalkSpeed` of 16 (source 8) or drivers cannot push a boar that has stopped panicking, and must not clear the 400-stud arena in 10 s. 400/38 = 10.5 s; 400/18 = 22 s |
| `WANDER_SPEED` | 4 studs/s | Grazing pace, ~1/10 of sprint. Note `:29`. Feel |
| `ACCEL` | 60 studs/s² | Reaches sprint in 0.63 s. Weight without a ragdoll |
| `TURN_RATE` | 4 rad/s (~230°/s) | No 180° snaps; a body length is covered in ~0.15 s at sprint |
| `DETECT_RADIUS` | 40 studs | 1/10 of the arena span. Note `:30`. Feel |
| `CALM_RADIUS` | 70 studs | Hysteresis, so the boar does not flicker at exactly 40 |
| `CALM_TIME` | 4 s | Beyond `CALM_RADIUS` this long → IDLE |
| `SENSE_INTERVAL` | 0.2 s | Reaction ≤ 0.2 s + one frame (0.217 s at 60 Hz) against the 0.5 s requirement. Note `:31` |
| `DT_CLAMP` | 0.1 s | A hitch cannot move the setpoint more than 6 studs' worth |
| `REPATH_INTERVAL` | 0.5 s (FLEE only; IDLE never paths) | `ComputeAsync` yields and is not free. Note `:34` |
| `WAYPOINT_RADIUS` | 4 studs | Slightly under the body length |
| `HOME_RADIUS` | 120 studs | Note `:32`. Feel |
| `WANDER_JITTER` | 0.35 rad per sense tick | Reynolds wander (source 3) |
| `HOME_PULL` | 0.6 | Returns to the home area within ~10 s from the boundary |
| `GRAZE_CHANCE` / `GRAZE_MIN` / `GRAZE_MAX` | 0.15 per tick / 1 s / 3 s | Feel; makes IDLE read as an animal |
| `PROBE_LENGTH` / `PROBE_TURN` | 6 studs / 1.6 rad | Reynolds obstacle avoidance (source 3). 6 studs ≈ one body length |
| `ROUTE_SIDE_BIAS` / `EDGE_MARGIN` | 60 / 20 studs | Bias > `DETECT_RADIUS`/2 so the route leaves the threat's circle; margin keeps the target off the plate edge |
| `STUCK_DIST` / `STUCK_TIME` | 3 studs / 2 s | Under one body length in 2 s at any non-zero setpoint is stuck |
| `MAX_FORCE` / `MAX_TORQUE` | 6000 / 20000 | Mass ≈ 33 studs³ × 0.7 (plastic) ≈ 23; 6000 is ~3× what `ACCEL` needs, leaving headroom for friction |
| `ALIGN_RESPONSIVENESS` | 25 | Upright without visible wobble |
| `BOUNDS_SLACK` / `FALL_LIMIT` | 10 / 50 studs | Out-of-bounds despawn |
| `field` | `bounds = ±200`, `exitZ = -190`, `groundY = 0` | The Task 17 arena: 400×400, surface at y = 0 (`src/server/TestArena.luau:26-31`), spawn pad at z = +170 (`:49`), so the exit edge is north. Note `:33` |
| `spawnPoint` | `Vector3.new(-40, 0, -60)` | Inside the arena, ~230 studs from the player spawn pad at (0, 170), clear of `WallWest` at (−60, −100) and `PillarMid` at (40, −40) (`src/server/TestArena.luau:38-45`) |
| `maxBoars` | 4 | The interface is plural; production spawns 1. A guard, not a feature |

### Performance and correctness targets, each one an assertion

| Target | How it is checked |
|---|---|
| `Brain:step` ≤ 10 µs | `boar_brain.spec`: 10 000 steps under 100 ms wall clock |
| ≤ 1 path request in flight per boar, ≤ 2/s while fleeing | `Runtime:stats().pathRequests` after a timed live run |
| Reaction: state is `FLEE` within 0.25 s of a threat inside `DETECT_RADIUS` | pure spec, exact |
| Body reaches ≥ 0.5 × `SPRINT_SPEED` within 1.0 s of first sensing | live spec, `part.AssemblyLinearVelocity` |
| Boar stays upright: `part.CFrame.UpVector.Y > 0.9` throughout a 3 s flee | live spec |
| `Despawned` fires exactly once per boar | live spec counts; `stats().despawned == stats().spawned` |
| Zero errors and zero skipped tests | `tests/TestKit.luau:100-108` fails the run otherwise |

---

## 8. External sources

Rule 1 and rule 2. Sources 1–5 and 8 are carried over from `docs/research/2026-09-24-boar-ai.md:40-102`
(that is where they were first assessed, and this design does not re-derive them). Sources 6, 7, 9
and 10 are added by this design; they are what the note was missing.

| # | Source | Licence | Maintenance |
|---|---|---|---|
| 1 | Roblox `PathfindingService` API reference — <https://create.roblox.com/docs/reference/engine/classes/PathfindingService> | First-party docs (creator-docs is CC BY 4.0); the API ships with the engine | Actively maintained |
| 2 | SimplePath (grayzcale) — <https://github.com/grayzcale/simplepath> | MIT | ~176 commits, no canonical fork. **Not adopted** |
| 3 | Craig Reynolds, *Steering Behaviors For Autonomous Characters* (GDC 1999) — <https://www.red3d.com/cwr/steer/gdc99/> | Published paper, freely readable; technique taken, not code | Frozen (1997/99); the standard reference |
| 4 | Roblox network ownership — <https://create.roblox.com/docs/physics/network-ownership> | First-party | Actively maintained |
| 5 | Roblox `LinearVelocity` — <https://create.roblox.com/docs/reference/engine/classes/LinearVelocity> | First-party | Current constraint (`BodyVelocity` is legacy) |
| 6 | **Roblox `AlignOrientation`** — <https://create.roblox.com/docs/reference/engine/classes/AlignOrientation> | First-party | Current |
| 7 | **Roblox units / scale (1 stud ≈ 28 cm)** — <https://create.roblox.com/docs/art/modeling/roblox-units> | First-party | Actively maintained |
| 8 | Roblox character pathfinding guide — <https://create.roblox.com/docs/characters/pathfinding> | First-party | Actively maintained |
| 9 | **`Signal` in sleitnick/RbxUtil** — <https://github.com/Sleitnick/RbxUtil> | MIT | Actively maintained, on Wally. **Not adopted** |
| 10 | **Mat Buckland, *Programming Game AI by Example*** (Wordware, 2005, ISBN 1-55622-078-2), ch. 2 (state machines) and ch. 3 (steering) | Book | 2005, no updates; the pattern it documents is stable |

**What each does well and badly, for this system**

- **1 / 8 (PathfindingService).** Good: `CreatePath` → `ComputeAsync` → `GetWaypoints` gives a route
  around the arena's cover blocks with no navmesh of our own; `Path.Blocked` carries
  `blockedWaypointIdx`, so we recompute only when the obstacle is ahead. Bad: it is written around
  `Humanoid:MoveTo`, the docs say a non-humanoid agent needs "custom movement logic", it yields, and
  the route is static — nothing steers between waypoints. **Adopted for the route only.**
- **3 (Reynolds).** Good: defines flee, wander and obstacle avoidance exactly as this task names
  them, and the crucial detail that wander keeps steering state and jitters it rather than picking a
  new random force each frame. Bad: no map knowledge, so pure steering walks into dead ends behind
  the cover blocks. **Adopted for wander, the flee fallback and the probe turn, on top of the
  navmesh.**
- **4 (network ownership).** Good: states the rule directly — `SetNetworkOwner(nil)` for
  gameplay-critical objects a client must not manipulate. Bad, and the trap: the server always owns
  anchored parts and their ownership cannot be set, so the call errors on an anchored body.
  **Adopted.**
- **5 (LinearVelocity).** Good: drives an unanchored assembly at a chosen world velocity while
  physics still resolves collisions, so the boar is stopped by walls instead of passing through them.
  Bad: in `Vector` mode it fights gravity unless Y is freed — hence Plane mode, with the `PerAxis`
  force limit as the fallback. **Adopted.**
- **6 (AlignOrientation).** Good: one constraint keeps the box upright and turned along travel, with
  `Responsiveness` as the single softness dial; no manual torque maths. Bad: at high
  `Responsiveness` with `RigidityEnabled` it can fight the mover and jitter, and it needs an
  `Attachment`, so the body is never a bare Part. **Adopted.**
- **7 (Roblox units).** Good: gives the one number the whole size-and-speed table hangs on, from the
  engine's own documentation. Bad: it is an art-pipeline convention, not enforced by the engine, so
  it must be written down once and obeyed — this design is that place. **Adopted; it corrects the
  research note (§7).**
- **9 (RbxUtil Signal).** Good: the maintained, MIT, Wally-installable signal that most Roblox
  projects use; faster than `BindableEvent` and passes tables by reference. Bad: a new Wally
  dependency plus a `Packages` mapping for exactly one event in this milestone. **Not adopted** —
  `BindableEvent` is the engine idiom and costs nothing (rule 2 reason, recorded here). Revisit when
  a second system needs signals; then adopt it everywhere at once rather than hand-rolling one.
- **10 (Buckland).** Good: the standard write-up of the split this design uses — a small explicit
  state machine deciding *what* to do, steering deciding *how* to move, with the state machine kept
  free of engine calls so it can be tested. Bad: C++ and pre-navmesh, so the code is not reusable
  and its FSM class hierarchy is heavier than three states need. **Pattern adopted, code not.**
- **2 (SimplePath).** Rejected with a written reason in the note
  (`docs/research/2026-09-24-boar-ai.md:120-126`): no canonical repository among at least four
  near-identical forks, not on Wally under one name, and its value is the waypoint-walking loop we
  need to write anyway for a non-humanoid body. This design confirms that and copies one idea from
  it explicitly (repath on `Path.Blocked` only when the blocked index is ahead), which is §6.

**Pattern adopted:** navmesh route (1) + steering follow and wander (3) + explicit three-state
machine with injected world (10) + `LinearVelocity`/`AlignOrientation` mover on an unanchored,
server-owned body (4, 5, 6), with every number derived at 1 stud = 0.28 m (7). Nothing here is
invented except the `routeTarget` formula in §5, which exists because no source addresses "flee
*toward* a specific line", and whose whole content is a clamp and a sign — it is one spec assertion.

---

## 9. Cross-system reads and writes

| Direction | What | Owner of the other side |
|---|---|---|
| reads | `Players:GetPlayers()`, `player.Character.PrimaryPart.Position` | Roblox engine. Read-only; the boar never writes a character |
| reads | `PathfindingService`, `Workspace:Raycast` for the probe | Roblox engine. Read-only |
| reads | `TestArena.LAYOUT.ground.span` and `.top`, **in `BoarBoot` only**, as an assertion | `ServerScriptService.TestArena` (`GAME_DESIGN.md:24`) |
| writes | `Workspace.Boars` and its descendants | this system (`Boar.Body`) |
| writes | `Despawned` (BindableEvent) | this system. Future listener: the score system (Milestone 1.7), which reads and never writes back |
| writes | nothing else, anywhere | — |

`Boar` itself never requires `TestArena`. `CONFIG.field` carries the arena rectangle as data, and
`BoarBoot` asserts `layout.ground.span == 400 and layout.ground.top == 0`, naming this file in the
message. So when the Milestone 2 map generator replaces the arena, the boar fails loudly at boot
instead of routing to an edge that no longer exists — and swapping maps means changing one `Field`,
not the state machine. This is the anti-coupling rule from `PROJECT_CONTEXT.md:35-36`: no second
writer, and no silent dependency on another system's table shape.

### Why the body is built in code and not a `.model.json`

`tools/studio_mcp.py:398-399` accepts only `str`, `bool`, `int` and `float` as comparable property
values, and `:505-507` turns anything else into "cannot compare … (typed value; add a comparison)",
which fails the run. `Size`, `Position` and `CFrame` in a `.model.json` are arrays or
`{"Vector3": [...]}`, so **any positioned part on disk fails the harness today**. `.rbxm`/`.rbxmx`
are banned (`CLAUDE.md:247`), and `src/serverstorage/` is fully Rojo-owned, so a model built in
Studio there is deleted at the next Connect (`CLAUDE.md:258-261`). That is audit-002 must-fix 1
(`docs/architecture/audit-002.md:20-48`), still open as Task 16 (`TASKS.md:23`).

Therefore: the boar body is constructed with `Instance.new` in `Body.luau`, exactly as the arena is
(`src/server/TestArena.luau:56-68`). No new `.model.json` and no new `.meta.json` in this task, so
the task does not depend on Task 16 and adds no work to it. When Task 16 lands, a boar *template*
under `src/serverstorage/Boar/` becomes possible; that is a Milestone 2 change (art, `ROADMAP.md:64`)
and `Body.luau` stays the single writer either way — it would clone the template instead of building
the Part.

---

## 10. How it is tested

Both specs are **server** specs (`tests/server/` → `ServerStorage.Tests`, `CLAUDE.md:221`). They
follow the existing convention of writing their numbers out independently of the module under test
(`tests/server/test_arena.spec.luau:3-4`) — so the spec disagreeing with `CONFIG` is a finding, not a
tautology. Rule 6: these test the boar's path, not the harness.

**`tests/server/boar_brain.spec.luau` — pure, no physics, no waiting, no Workspace.**
Requires `ServerScriptService.Boar` (side-effect-free on require, §2) and drives
`Brain:step(1/60, obs)` with a fixed `Random.new(1)` and hand-written observations. At least:

1. starts `IDLE`; stays `IDLE` with a threat at 41 studs; enters `FLEE` within 0.25 s of a threat at
   39 studs (the ≤ 0.5 s requirement);
2. `FLEE` returns to `IDLE` only after `CALM_TIME` beyond `CALM_RADIUS`, and does not flicker at
   exactly `DETECT_RADIUS`;
3. `pathRequest` in `FLEE` is on the exit line (`Z == field.exitZ`), inside the bounds minus
   `EDGE_MARGIN`, and on the opposite side of the threat in X;
4. with the threat placed between boar and exit, `|targetX − threatX| ≥ ROUTE_SIDE_BIAS * 2` — the
   boar never routes through the driver;
5. flee velocity increases the flat distance to the threat over 30 simulated steps;
6. `waypoints = nil, pathFailed = true` still yields a non-zero `targetVelocity` (no freeze);
7. `blockedAhead = true` changes the heading by ≥ 1 rad within two sense ticks;
8. wander over 120 s of simulated steps never exceeds `HOME_RADIUS + 20` from home, and the heading
   never reverses by more than `TURN_RATE * dt` in one step;
9. the speed setpoint never rises faster than `ACCEL * dt`;
10. crossing `exitZ` gives `despawn = true, reason = "escaped"` once, then `GONE` forever, with
    `targetVelocity` zero;
11. outside the bounds gives `outOfBounds`;
12. two brains with the same seed produce identical intent sequences (determinism);
13. `dt = 5` is clamped: the setpoint change is no larger than at `dt = DT_CLAMP`;
14. 10 000 steps in under 100 ms.

**`tests/server/boar_body.spec.luau` — one real, physically simulated boar, ~6 s.**
It builds **its own** world so it does not depend on `Workspace.TestArena` (Task 17 is blocked,
`TASKS.md:22`): an anchored 120×120 plate at **y = 500**, well clear of the arena and the default
Baseplate, in a spec-owned folder, with `field = { bounds = ±55, exitZ = -40, groundY = 500 }` and a
scripted `threats()` returning one fixed point. A short exit line is what keeps the test at seconds
instead of the 10.5 s a full arena crossing takes. Then, through the public interface only:

1. `Runtime:spawn()` puts exactly one Part under the runtime's folder, `Anchored == false`;
2. `part:GetNetworkOwner() == nil` (server-owned, source 4);
3. the Part carries a `LinearVelocity` and an `AlignOrientation`;
4. with no threats, after 2 s the boar is still inside the bounds and its speed ≤ `WANDER_SPEED * 1.5`;
5. with the threat switched on, within 1.0 s `AssemblyLinearVelocity` magnitude ≥ 0.5 × `SPRINT_SPEED`,
   and the flat distance to the threat has grown by ≥ 20 studs after 2 s;
6. `CFrame.UpVector.Y > 0.9` at every sample through the flee (it did not tip over);
7. `Despawned` fires exactly once, with `reason == "escaped"` and the recorded position past `exitZ`,
   polled for up to 3 s (deferred signals, §4), and the Part is gone from the folder;
8. `stats().pathRequests > 0` and `pathFailures == 0` — so a silent permanent fallback to
   straight-line flee is a failure, not an invisible degradation;
9. `afterAll` calls `Runtime:destroy()` and removes the spec's own folder. Production's boar, spawned
   by `BoarBoot`, is a separate runtime and is untouched.

**Client spec: N/A** — this system has no client code (§2). `tests/client/` stays as it is.

**Harness input (Task 6): not needed.** Threats are injected as data through `world.threats`, never
read from real input, so the blocker at `TASKS.md:12` does not apply.

**Screenshot (rule 5, `CLAUDE.md:25`): needed, and it needs Karen.** A moving grey box is a visual
change. Play-time capture is not wired (Task 7, `TASKS.md:13`; `tools/studio_mcp.py:68-72`), and
`screen_capture` over MCP is Edit-mode only while the boar exists only during Play
(`ESCALATE.md:80-82`). So the evidence for this task is **Karen's screenshot** of the boar idling and
of it fleeing, or Task 7 landing first. The Builder must not report rule 5 as met on its own, and
must not claim a screenshot it did not inspect (`PROJECT_CONTEXT.md:25-27`).

**Rojo hazard.** This task adds a directory (`src/server/Boar/`) and a branch switch to get it. Rojo
7.7.0 crashes when watched files disappear, and a large branch switch alone was enough on 2026-09-24
(`CLAUDE.md:166-170`, `CLAUDE.md:328-332`, `ESCALATE.md:13-44`). Stop `rojo serve` before switching,
and expect a NEEDS KAREN Connect click. That is process, not design, but it is the most likely way
this task stalls.

---

## 11. What the Builder owes the research note

Rule 1 keeps decisions and dated measurements in `docs/research/`, and the note predates this
design. The Builder appends one dated addendum to `docs/research/2026-09-24-boar-ai.md` (it owns
research notes, `CLAUDE.md:41`) recording:
1. the scale correction in §7, superseding the "1 stud ≈ 1 m" premise at `:28` — and the size and
   speed numbers that follow from it;
2. the confirmed URL, licence and maintenance line for sources 6, 7, 9 and 10 (this session could
   not fetch them, §13);
3. which mover configuration actually worked, Plane mode or `PerAxis` (§6);
4. whether `PathfindingService` computed a usable path on the elevated spec plate, and on the arena.

Rule 9: `init.luau`, `Brain.luau` and `Body.luau` each carry the pattern name, the source links they
use and the note path in their header, as `src/server/TestArena.luau:1-16` and
`tests/TestKit.luau:1-5` already do.

---

## 12. Open decisions

**None of these blocks building.** Every one has a default written into `CONFIG` or into this
document, so the Builder can build, test and report without an answer. They are the things Karen or
the Director should overrule on purpose rather than by accident.

**Karen (feel), for the first playtest — the "check this" list (`ROADMAP.md:22`):**
1. `SPRINT_SPEED` 38 and `TROT_SPEED` 18. At 38 a player at the default walk speed 16 can never catch
   a panicking boar; that is intended (drivers push, shooters shoot), but the trot is what decides
   whether a drive is playable at all. Retuning either is one number.
2. `DETECT_RADIUS` 40 and `CALM_TIME` 4 s: does the boar notice you too early, and does it settle too
   fast?
3. **Does a boar behind a wall notice you?** Default: **no line-of-sight check**, flat XZ distance
   only. Adding one is a `probe` call in `threats()` and touches nothing else. Cheaper to decide by
   feel than to argue about.
4. Does the boar body-block or shove a player? Default: `CanCollide = true`, no knockback, no
   collision group.
5. Karen's screenshot is the rule-5 evidence for this task until Task 7 lands (§10).

**Director (scope):**
6. One boar or several? Default: the interface is plural and guarded at `maxBoars = 4`; `BoarBoot`
   spawns **one**. Several boars is a `spawn()` loop, but it also multiplies `ComputeAsync` calls and
   is where SimplePath's waypoint loop would start to pay off (source 2) — revisit then, not now.
7. Respawn after despawn? Default: **no**. The boar is gone and the world is empty until the server
   restarts. Respawn belongs to the match loop (Milestone 1.7, `ROADMAP.md:58`).
8. Task 17 is `blocked: NEEDS KAREN` (`TASKS.md:22`): the arena has never been seen in Studio, and
   two known problems are open there — its ground surface is coplanar with the default Baseplate's
   top, and two `SpawnLocation`s will exist during Play (`ESCALATE.md:74-79`). Neither blocks the
   boar (the live spec builds its own plate at y = 500), so boar-ai can be built in parallel; but the
   *in-arena playtest* that answers decisions 1–4 cannot happen until the arena is connected and
   seen. The Director decides whether to build now or wait for Karen's Connect.
9. Naming: `docs/architecture/audit-002.md:222` queued this slot as `animal`. This file is
   `boar-ai`, and the `GAME_DESIGN.md` row in §3 uses that. Roe deer, fox and rabbit are v1.1
   (`ROADMAP.md:27`); when they arrive, the expectation is that they reuse `Brain` with a different
   `CONFIG`, not a second state machine.

---

## 13. Not verified

- **Anything requiring Roblox Studio.** No Studio in this session
  (`.agent-evidence/INDEX.md:14`). Every claim about how `LinearVelocity`, `AlignOrientation`,
  `SetNetworkOwner`, `PathfindingService` or gravity behave here is read from documentation and from
  the research note, not observed. In particular: whether `VelocityConstraintMode.Plane` leaves Y
  free in practice, whether `ForceLimitMode`/`MaxAxesForce` exist on the pinned engine version, and
  whether `ComputeAsync` returns a usable path on an elevated 120×120 plate. §6 gives a fallback for
  the first two; §10 assertion 8 makes the third visible instead of silent.
- **The URLs, licences and maintenance status of sources 6, 7, 9 and 10.** No network access; those
  four are from my own knowledge, and `PathfindingService`-style stable doc URLs can move. Sources
  1–5 and 8 are verified only as *cited in the repo*
  (`docs/research/2026-09-24-boar-ai.md:40-102`), not as reachable. The Builder confirms all ten
  (§11.2).
- **The exact figure 1 stud = 0.28 m** (source 7) is from the Roblox unit convention as I know it;
  §7's conclusion survives anything in the 0.25–0.35 m range (35.7–44.4 studs/s for 40 km/h), which
  is why `SPRINT_SPEED` is stated as a band-centre and left as Karen's dial. What is certainly wrong
  is 1 stud = 1 m, because it makes the default character 5 m tall.
- **`SignalBehavior` of the DEV place.** Not a repo file, so I cannot read it. §10 assertion 7 polls,
  which is correct under both `Immediate` and `Deferred`.
- **Whether Rojo's sourcemap and the harness handle a `src/server/Boar/init.luau` folder module.**
  `CLAUDE.md:241` documents the mapping, and the harness compares such a script by Source
  (`tools/studio_mcp.py:39-44`), but no folder module exists in the repo today
  (`.agent-evidence/ls-files.txt:34-36`), so this is the first one. If it misbehaves, the fallback is
  three flat files (`src/server/Boar.luau`, `BoarBrain.luau`, `BoarBody.luau`); the owner table in §3
  is unchanged by that.
- **The arena itself.** Never seen in Studio; Task 17 is blocked (`TASKS.md:22`). The `CONFIG.field`
  and `spawnPoint` numbers are read from `src/server/TestArena.luau:26-49`, not from a running place.
- **CI and harness status at this commit.** Lint and build are clean in the evidence
  (`.agent-evidence/lint-selene.txt`, `.agent-evidence/rojo-build.txt`, both exit 0). No harness or
  CI output is in `.agent-evidence/`.
