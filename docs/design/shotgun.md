# Design: shotgun (v3)

Architect, 2026-09-25, for Task 24. Commit `2134b99c093f81151116d5d7adf870b64cfe7670`
(`.agent-evidence/head.txt`). Read-only session: Read, Grep, Glob. No Studio, no network. Evidence
precomputed in `.agent-evidence/` (`INDEX.md`).

**This file supersedes the v2 design of 2026-09-25 (Task 23), which supersedes the v1 of 2026-09-24.**
Both are in git history: superseded, not deleted (rule 7).

Inputs, in precedence order: `reviews/task-24/BRIEF.md` (the Director's instruction, carried by the
Builder), `reviews/task-23/RESULT.md` (the twelve notes, six of them real design defects, queued as
`TASKS.md` row 23a), the code now on `main` (`src/server/Boar/`, `src/server/TestArena.luau`,
`tests/client/input_driving.spec.luau`, `tests/client/input_scenarios.txt`, `tools/studio_mcp.py`),
`docs/design/boar-ai.md`, `docs/research/2026-09-24-shotgun.md` (rule 1: the ballistics and sources
1–9 come from there and are not re-derived), `CLAUDE.md`, `docs/PROJECT_CONTEXT.md`.

**What changed from v2, and nothing else.** The brief says the v2 regeneration is being built from in
this same task and must not be restructured. §2 lists every change: the six defects, three
documentation notes, and seven build-critical facts I found in the landed Task 6 harness and in
Roblox's remote serialisation that v2 could not have known. The ownership model, the module split, the
numbers and the damage seam are v2's and are unchanged.

**Test of this document:** a Builder can build the weapon from it without asking a question. Every
number is here, every owner is named, every interface is written out, and every scenario step is
written out as JSON.

---

## 1. What the system must do, and must not do

### 1.1 Must do

1. A break-action, two-barrel shotgun: fire one barrel at a time, reload as **one uninterruptible
   2.0 s action**, select slug or buckshot and only while the action is open
   (`docs/PROJECT_CONTEXT.md`, "The game"; `ROADMAP.md` 1.4).
2. Decide **on the server** what each shot hit, and publish it as a **hit report**: which instance,
   which hit zone, how many pellets, how far.
3. Hand that report to the thing that was hit through **one seam**, `Runtime:takeHit` on the target's
   own owner (§6). The weapon never writes the target's state.
4. Give a `Tool` to a player on spawn and take it away, through **one policy function**
   (`CONFIG.shouldArm`), so `ROADMAP.md` 1.7 can make it shooters-only by changing that function's
   body.
5. Draw a crosshair and a barrel/ammo readout from **one** UI owner (§3.4). Karen wants a crosshair.
6. Check whether a shot was fired toward the drive line and publish that as a **safety violation** —
   define the hook, never the punishment (`ROADMAP.md` 1.7).
7. Be server-authoritative enough that a client cannot invent a kill, a shell, a rate of fire, or an
   action the protocol does not offer it.
8. Ship on the **default Roblox camera: no ADS, no viewmodel** (brief), and leave exactly one named
   seam for `ROADMAP.md` 1.4b, the camera task that follows (§9).

### 1.2 Must not

Every row is a named cause of death of the previous project, written as a prohibition. Quotes are
from `docs/PROJECT_CONTEXT.md`, section "Why the rules exist - the previous project", cited by
section and quote, never by line (`CLAUDE.md`, the loop, step 4).

| Prohibition | Why | Whose job it is instead |
|---|---|---|
| Never assign `workspace.CurrentCamera.CFrame`, `.CameraType`, `.FieldOfView`, `.CameraSubject` | "Two systems wrote the creature's position" | the camera owner, **unassigned** until `ROADMAP.md` 1.4b (`GAME_DESIGN.md`, Camera row). Reading the camera is allowed (§7) |
| Never assign `UserInputService.MouseIconEnabled`, `UserInputService.MouseBehavior` or `Mouse.Icon` | "Three scripts set the mouse cursor" | the camera/ADS task. The **stock PlayerModule already writes `MouseBehavior`** while MouseButton2 is held, which is one more reason the weapon must not (§9) |
| Never write anything under `Workspace.Boars`, never set a boar's velocity, `CFrame` or attributes | `Boar.Body` is "the only writer of a boar's Instances" (`src/server/Boar/Body.luau` header; `docs/design/boar-ai.md` §3) | `ServerScriptService.Boar` |
| Never hold a damage number or a zone→reaction table | one decision in one place; the mapping is `ROADMAP.md` 1.5 | the hit-zone system, when it exists |
| Never freeze, tie, teleport, score or team a player | the penalty is not the weapon's | match state, `ROADMAP.md` 1.7 |
| Never create a `ScreenGui`, `Frame` or `TextLabel` outside `PlayerScripts.Hud` | "One predicate answered two unrelated questions, so mounting hid both the crosshair and the weapon" | `PlayerScripts.Hud` (§3.4) |
| Never write a typed property value (`Vector3`, `CFrame`, `Color3`) into a `.model.json` or `.meta.json` | the harness fails it as "cannot compare" (`tools/studio_mcp.py`, `compare_synced` / `plain_value`); audit-002 must-fix 1 is still open (`TASKS.md` row 16) | §8: everything positioned or coloured is built in code |
| Never add a Wally package in this task | `wally.lock` and `devpackages.sha256` are pinned against the commit (`tools/studio_mcp.py` docstring, check 4); the one package worth having is the ADS spring, deferred with ADS (§10 source G) | — |
| Never let a client name what it hit, and never cast on the client | §5.7 | — |
| Never return `Enum.ContextActionResult.Sink` from a weapon action | sinking MouseButton2 breaks the stock camera's own rotation, and sinking MouseButton1/R breaks the Task 6 input probe that shares those inputs (§5.6, §13.3) | — |

**A predicate answers one question.** `StateMachine.apply` says whether an action is legal. It does
not say whether the crosshair is visible, whether the Tool is equipped, or whether the camera is in
aim. That is the previous project's "one predicate answered two unrelated questions" written as a
rule.

---

## 2. What v3 changes, and why

### 2.1 The six defects the Task 23 review found (`reviews/task-23/RESULT.md`; `TASKS.md` row 23a a–f)

| # | Defect | Fix, and where |
|---|---|---|
| a | `CastFn = (origin, direction) -> Impact?` has no shooter, so step 8's "filter out the shooter's character" is unimplementable, and step 4's camera ray — which starts *behind* the character under the stock third-person camera — resolves the aim point onto the shooter's own back, where `MIN_AIM_DISTANCE` silently swallows it | the seam gains an **ignore list**: `CastFn = (origin, direction, ignore) -> Impact?`. Production is the new `Weapon.Cast` module, the only caller of `Workspace:Raycast`. **Both** the camera ray (§5.5 step 4) and the pellet rays (step 8) pass the same list, built once per shot from the shooter. §5.4, §5.5, §13.1 |
| b | `table.freeze` is shallow, so `CONFIG.SPREAD_FULL_DEG` and the replica's `barrels`/`loaded` stay writable | `Shotgun.deepFreeze` (§5.2), applied to `CONFIG`, to every state the reducer returns, to every snapshot, and to the replica on arrival. The specs assert a **nested** write errors (§13.1, §13.2) |
| c | no `Players.PlayerRemoving` lifecycle: per-player state and rate-limit counters leak and pin the `Player` | one named cleanup, `Weapon.forget(player)`, called from `PlayerRemoving`, beside `grant`/`revoke`; the registry it clears is the pure `Registry` module, so the lifecycle is **tested**, not asserted in prose (§5.3, §5.4, §13.1) |
| d | `ActionRequest:FireServer("Reload")` is not an `ActionKind`, and `Break`/`Load`/`Close` look client-reachable | two separate types: `RequestKind = "Reload" \| "SelectAmmo"` on the wire, `ActionKind = "Fire" \| "Break" \| "Load" \| "Close" \| "SelectAmmo"` inside the reducer. The whitelist is the pure `Validator.checkRequest`, and the **client spec fires the primitives at the server and asserts nothing moves** (§5.1, §5.6, §13.2) |
| e | the safety arc is evaluated on the client's camera direction, not the direction the pellets take | step 10 uses `aim`, the muzzle→aim-point unit vector from step 6, and `SafetyViolated` carries it with the muzzle (§5.5) |
| f | `weapon_shot.spec` item 2 imports `CONFIG` against its own preamble, and "at least one direction beyond `SPREAD_FULL_DEG/4`" is ~25 % flaky for `Slug` | the spec writes the literal degrees; the spread assertion is **`Buck` only**, over a fixed seed and 1,000 shots, as max/mean bounds rather than a single draw (§13.1) |

### 2.2 The three documentation notes (row 23a g–i)

- g: every cross-reference to the specs now points at §13 (v2 pointed three of them at §12, which is
  Karen's feel defaults).
- h: §14 no longer says "five rows". It says exactly what changes in `GAME_DESIGN.md`: **four new
  rows, one filled row, one amended row, one annotated row.**
- i: §2 of v2 claimed Task 19's `ARCH_RESULT.md` was "superseded" by Task 23's. It was not; a
  mis-pointed reference in a historical verdict file is **recorded, not corrected**, and is not
  mentioned again.

Row 23a j (document `BRIEF.md` in `CLAUDE.md`) is done: `CLAUDE.md` carries the `BRIEF.md` row. Row
23a k (keep verdict instructions out of briefs) and l (split `ROADMAP.md` 1.4) are done: `ROADMAP.md`
now has 1.4 and 1.4b. None of the three is this design's to fix.

### 2.3 Seven facts v2 could not know, each of which would have been a bug

These come from reading the Task 6 harness and spec that landed on `main`, and from Roblox's remote
serialisation. Each is a place where building v2 as written would have produced a failing or flaky
run.

1. **`loaded` cannot be a sparse array on the wire.** v2's `loaded: { AmmoKind? }` is `{nil, "Slug"}`
   after firing barrel 1. A Roblox `RemoteEvent` does not carry a table that is both sparse and
   array-like faithfully. Fixed: `loaded: { AmmoLoad }`, a **dense** array of two strings, where
   `"None"` is an explicit value (§5.1).
2. **The scenario file's mouse position is per scenario, not per session.** `scenario_batches`
   (`tools/studio_mcp.py`) resets `last_xy` for each scenario, and StudioMCP refuses a button action
   whose call establishes no position — the refusal Task 6 hit by running it. **Every scenario that
   uses a mouse button must begin with a `moveTo`** (§13.3).
3. **The ready handshake is one attribute for the whole file.** `replay_input` waits for a single
   `readyAttribute` carrying the run's token and then replays **every** scenario. Today
   `input_driving.spec` sets that attribute itself, so a second client spec's bindings can be raced.
   Fixed by one rendezvous module with one writer of that attribute (§13.3).
4. **Scenario 1 would drive the weapon.** `key-mouse-order` sends MouseButton1 and `R` — the fire and
   reload inputs. If the Tool were equipped at handshake time, Task 6's scenario would spend a barrel
   and start a reload before the weapon's own scenario began. Fixed: the Tool is equipped by a **cue
   key inside the weapon scenario**, so it is in the Backpack (nothing bound) while scenario 1 runs
   (§13.3).
5. **A weapon action must return `Pass`.** `input_driving.spec` binds MouseButton1, MouseButton2, `F`
   and `R` through `ContextActionService` and unbinds them only in its last `it`. The weapon's
   bindings are newer, so they are on top of the CAS stack; `Sink` would swallow Task 6's own
   evidence, and sinking MouseButton2 would also break the stock camera (§1.2, §5.6).
6. **`busyFor` cannot be the stored field.** A duration is what the client needs; a deadline is what a
   pure reducer can compare with `now`. Fixed: the server state holds `busyUntil`, the wire carries
   `busyFor`, and `Shotgun.snapshot(state, now)` is the one pure converter (§5.1).
7. **The server's ignore list is not "the character and `Workspace.WeaponEffects`".** Instances a
   client creates do not replicate to the server, so the effects folder normally does not exist in
   the server's `Workspace` at all. The list is the shooter's character (which contains the equipped
   Tool), plus the effects folder **only if** one exists server-side (§5.5 step 8).

---

## 3. Ownership

Rule 3 (`CLAUDE.md`, Rules): exactly one writer per system, named here, mirrored into
`GAME_DESIGN.md` (§14). The structure mirrors the boar system, which is on `main`, works and has run
green (`TASKS.md` row 18, harness `PASS: 24/24`): a folder module `init.luau` that owns state, pure
decision modules, and one module that is the only writer of Instances. Borrowing the repo's own
proven shape is rule 2 applied inside the project.

### 3.1 The one server owner

**`ServerScriptService.Weapon`** — disk `src/server/Weapon/init.luau`.

Sole writer of: every player's authoritative `WeaponState`; every granted `Tool` and its parts; the
four RemoteEvents; the `HitReported` and `SafetyViolated` signals; the per-player rate-limit buckets.
Nothing else in the repo may fire those remotes or mutate that state.

It is a **ModuleScript** (a folder with `init.luau`, exactly as `src/server/Boar/init.luau`), started
by the three-line `src/server/WeaponBoot.server.luau`. A `Script` cannot be `require`d, so a `Script`
owner could not expose `HitReported` to `BoarBoot` (§6) and no spec could reach its pure modules.
**Nothing happens on `require`** — only `WeaponBoot` starts production, which is the rule
`src/server/Boar/init.luau` states in its header and which makes every spec in §13.1 possible.

Its private modules, each the sole writer or owner of one thing:

| Module | Is | Never |
|---|---|---|
| `StateMachine.luau` | pure reducer: `(state, action, now) -> (state, reason?)` | touches Instances, services, clocks or `Player` |
| `Validator.luau` | pure: is this request well-formed and physically possible | as above |
| `Limits.luau` | pure: does this request fit the rate budget | as above |
| `Registry.luau` | pure per-key store: state, buckets, epoch, and the one `forget` | as above; it never knows what a `Player` is |
| `Pattern.luau` | pure: aim direction + rng → pellet directions | as above |
| `Hits.luau` | pure over an **injected cast**: impacts → grouped hit reports; and `targetOf`, which reads attributes off real Instances | calls `Workspace:Raycast` itself |
| `SafetyArc.luau` | pure: is this direction inside the forbidden arc | as above |
| `Cast.luau` | **the only caller of `Workspace:Raycast` in this system** | holds state, decides anything |
| `Hardware.luau` | **the only writer of `Tool` Instances**: builds, grips, equips and destroys them | holds state, touches remotes |

### 3.2 The one client owner

**`Players.LocalPlayer.PlayerScripts.Weapon`** — disk `src/client/Weapon/init.luau`, booted by
`src/client/WeaponBoot.client.luau`.

| Module | Sole writer of | Never touches |
|---|---|---|
| `init.luau` | the client's copy of the state (the replica) | remotes outbound, Instances, camera, UI |
| `Input.luau` | the `DrivenHunt.Weapon.*` action bindings, the `FireRequest`/`ActionRequest` remotes, the local aim flag | camera, cursor, UI, any Instance |
| `Effects.luau` | cosmetic Instances under a runtime folder `Workspace.WeaponEffects` | state, remotes, camera, UI |

**The replica has no setter.** `init.luau` subscribes to `StateChanged.OnClientEvent` itself and
stores a deep-frozen table; `Weapon.get()` returns it. Nothing else *can* write it — rule 3 enforced
by the engine rather than by policy. Specs and other systems reach these modules through
`Players.LocalPlayer:WaitForChild("PlayerScripts").Weapon`, **not** through `StarterPlayerScripts`,
which is a template (`default.project.json`, `StarterPlayer.StarterPlayerScripts`).

### 3.3 The one shared, frozen table

**`ReplicatedStorage.Shotgun`** — disk `src/shared/Shotgun/init.luau`, plus
`src/shared/Shotgun/Remotes.model.json` → `ReplicatedStorage.Shotgun.Remotes`.

`Shotgun.CONFIG` is **deep**-frozen and has no writer. Every number in §11 lives here and nowhere
else. The three owner modules are named `Weapon` in three different services; the shared table is
named `Shotgun` so that `require` sites read unambiguously.

### 3.4 The UI owner — assigned here

`GAME_DESIGN.md` has "UI / anything drawn — _unassigned_". Karen wants a crosshair, so this design
**assigns that slot** rather than deferring it. Rule 3 gives the Architect that call.

**`Players.LocalPlayer.PlayerScripts.Hud`** — disk `src/client/Hud/init.luau`.

Sole writer of `PlayerGui.HunterHud` (one `ScreenGui`, created at runtime) and everything in it. In
this task that is the crosshair and one barrel/ammo readout, and nothing else.

**The dependency direction is one-way and it is the point.** The Hud **reads** `Weapon.get()`,
`Weapon.Changed` and `Weapon.Input.AimChanged`. The weapon holds no reference to the Hud, calls
nothing on it, and does not know it exists. So the failure quoted in §1.2 — one predicate hiding both
the crosshair and the weapon — cannot recur: the crosshair has exactly one writer, and that writer's
only input is published state.

**What it costs, stated plainly.** It makes this task two systems rather than one, against
`ROADMAP.md` speed rule 5. The alternative costs more: a crosshair drawn from `Weapon/Effects.luau`
makes the weapon the UI owner by accident, and the next task that draws anything inherits a second
writer on day one. The scope is bounded by naming the Hud's *whole* content for this task (§5.6,
§11).

**Why the readout and not the crosshair alone.** Karen's feel defaults 2 and 4 (2.0 s reload,
automatic barrel select) cannot be judged by a player who cannot see which barrels are live — there
is no sound and no animation in this task. One `TextLabel` in the owner that already exists is the
cheapest way to make those two defaults playtestable. It is one line in §11 to delete if the Director
disagrees (§15 A).

### 3.5 Files on disk

```
src/shared/Shotgun/
  init.luau                    -> ReplicatedStorage.Shotgun            (CONFIG + types, deep-frozen)
  Remotes.model.json           -> ReplicatedStorage.Shotgun.Remotes    (Folder + 4 RemoteEvents)
src/server/
  WeaponBoot.server.luau       -> ServerScriptService.WeaponBoot       (Script, ~4 lines)
  Weapon/
    init.luau                  -> ServerScriptService.Weapon           (THE SERVER OWNER)
    StateMachine.luau          -> ...Weapon.StateMachine               (pure)
    Validator.luau             -> ...Weapon.Validator                  (pure)
    Limits.luau                -> ...Weapon.Limits                     (pure)
    Registry.luau              -> ...Weapon.Registry                   (pure)
    Pattern.luau               -> ...Weapon.Pattern                    (pure)
    Hits.luau                  -> ...Weapon.Hits                       (pure over an injected cast)
    SafetyArc.luau             -> ...Weapon.SafetyArc                  (pure)
    Cast.luau                  -> ...Weapon.Cast                       (the only Workspace:Raycast)
    Hardware.luau              -> ...Weapon.Hardware                   (the only writer of Tool Instances)
src/client/
  WeaponBoot.client.luau       -> PlayerScripts.WeaponBoot             (LocalScript, ~4 lines)
  Weapon/
    init.luau                  -> PlayerScripts.Weapon                 (THE CLIENT OWNER: the replica)
    Input.luau                 -> PlayerScripts.Weapon.Input
    Effects.luau               -> PlayerScripts.Weapon.Effects
  Hud/
    init.luau                  -> PlayerScripts.Hud                    (THE UI OWNER)
tests/server/weapon_state.spec.luau     (StateMachine, Registry, Limits, snapshot)
tests/server/weapon_shot.spec.luau      (Validator, Pattern, SafetyArc)
tests/server/weapon_hits.spec.luau      (Hits, Cast)
tests/server/boar_hit.spec.luau         (the damage seam)
tests/client/weapon_client.spec.luau    (the replica, the Hud, the driven input, the exploit path)
tests/client/InputReady.luau            (the ready rendezvous; NOT a spec)
```

Mappings are `default.project.json` (`ServerScriptService` → `src/server`, `ReplicatedStorage` →
`src/shared`, `StarterPlayer.StarterPlayerScripts` → `src/client`, `ReplicatedStorage.ClientTests` →
`tests/client`, `ServerStorage.Tests` → `tests/server`). A folder with `init.luau` becomes that
ModuleScript with its files as children — proven in this repo by `src/server/Boar/`, whose
`Brain.luau` and `Body.luau` compare green in the harness. `src/starterpack/` and
`src/serverstorage/` stay empty: see §8.

`tests/client/InputReady.luau` is not a `*.spec.*` file, so `TestKit.run` (which requires only
modules matching `%.spec$`) never runs it as a spec, and the harness's "every `*.spec.*` file is
synced" check does not apply to it. Its `Source` is still compared byte-for-byte like every other
synced file.

**Three changed files outside this system**, all named deliverables:
`src/server/Boar/Body.luau` (§6.4, two attributes, in the boar's own Instance writer),
`src/server/BoarBoot.server.luau` (§6.3, the wiring) and `tests/client/input_driving.spec.luau`
(§13.3, two lines: it hands the ready handshake to `InputReady`). `tests/client/input_scenarios.txt`
gains one scenario.

---

## 4. Angles: one unit, one conversion, named in the field

The rule that makes the v1 cone defect impossible to repeat:

> **Every angle stored in `Shotgun.CONFIG` is in DEGREES, and its field name states whether it is a
> FULL cone or a HALF angle. No other angle is stored anywhere. Each is converted to radians exactly
> once, at the one call site named below.**

| Config field | Unit stored | Value | Converted where, once |
|---|---|---|---|
| `SPREAD_FULL_DEG.Slug` | degrees, **full cone** | `0.16` | `Pattern.directions`: `halfRad = math.rad(full) * 0.5` |
| `SPREAD_FULL_DEG.Buck` | degrees, **full cone** | `1.6` | same line, same function |
| `SAFETY_ARC_HALF_DEG` | degrees, **half angle** | `45` | `SafetyArc.isForbidden`: `math.rad(halfDeg)` |

Both spread numbers are the research note's (`docs/research/2026-09-24-shotgun.md`, "Numeric
targets": slug **0.16° full cone**, buckshot **1.6° full cone**). The safety arc is a different
quantity from a spread cone — a forbidden *firing* arc about the drive-line normal — which is exactly
why its name carries `HALF`.

`Pattern.directions` takes the whole config, not a loose angle, so no caller can pass the wrong
convention. §13.1 asserts against the **full** angle in literal degrees, so a 2× error in either
direction fails.

---

## 5. Public interface

Types live in `src/shared/Shotgun/init.luau` and are exported from there. `luau-lsp` is pinned but
not in CI (`TASKS.md` row 3), so annotations are documentation plus editor checking, not a gate — the
same status `docs/design/boar-ai.md` §4 records.

### 5.1 Shared types

```luau
export type AmmoKind = "Slug" | "Buck"
export type AmmoLoad = "Slug" | "Buck" | "None"   -- "None" is a VALUE, not a hole: see 2.3 item 1
export type BarrelState = "Empty" | "Live" | "Spent"

-- The server's authoritative state. `busyUntil` is in the same clock as the `now` passed to apply().
export type WeaponState = {
	equipped: boolean,          -- the Tool is in the character (server truth, never a client claim)
	open: boolean,              -- the action is broken open
	barrels: { BarrelState },   -- exactly CONFIG.BARRELS entries, dense
	loaded: { AmmoLoad },       -- exactly CONFIG.BARRELS entries, dense, "None" where not Live
	selected: number,           -- 1 or 2: the barrel the next Fire uses
	ammo: AmmoKind,             -- what the NEXT Load inserts
	reserve: number,            -- shells in the pocket, not counting loaded ones
	busyUntil: number,          -- server clock; an action is in flight while now < busyUntil
	epoch: number,              -- bumped by grant/revoke/forget; a stale async step checks it
}

-- What crosses StateChanged. Identical except that the deadline becomes a duration.
export type WeaponSnapshot = {
	equipped: boolean, open: boolean,
	barrels: { BarrelState }, loaded: { AmmoLoad },
	selected: number, ammo: AmmoKind, reserve: number,
	busyFor: number,            -- seconds of action left when this snapshot was made
}

export type ActionKind = "Fire" | "Break" | "Load" | "Close" | "SelectAmmo"  -- reducer primitives
export type Action = { kind: ActionKind, ammo: AmmoKind? }

export type RequestKind = "Reload" | "SelectAmmo"   -- THE ONLY strings ActionRequest accepts
export type ShotRequest = { origin: Vector3, direction: Vector3 }  -- CAMERA ray, see 5.5

export type ZoneTally = { [string]: number }        -- HitZone attribute -> pellets

export type HitReport = {
	shooter: Player,
	target: Instance,      -- the instance carrying attribute Damageable == true
	zone: string,          -- the DOMINANT zone: most pellets, ties broken by the nearest impact
	zones: ZoneTally,      -- the full tally, for ROADMAP 1.5
	pellets: number,       -- total landing on this target
	nearest: number,       -- studs, muzzle to the closest impact on this target
	position: Vector3,     -- that closest impact point
	normal: Vector3,
	ammo: AmmoKind,
	at: number,            -- os.clock() on the server
}

export type ShotPayload = {   -- broadcast, cosmetic only
	shooterUserId: number,
	muzzle: Vector3,
	impacts: { Vector3 },  -- dense; may be empty
	ammo: AmmoKind,
}

export type DriveLine = { position: Vector3, normal: Vector3 }  -- normal points toward the drivers
export type DriveLineProvider = () -> DriveLine?
export type Impact = { instance: Instance, position: Vector3, normal: Vector3, distance: number }
export type CastFn = (origin: Vector3, direction: Vector3, ignore: { Instance }) -> Impact?
```

`busyFor` is a **duration**, never a server timestamp: `os.clock()` on the server is meaningless on a
client, and shipping one invites someone to compare it with a local clock. `epoch` never crosses the
wire.

### 5.2 Shared functions — `ReplicatedStorage.Shotgun`

```luau
Shotgun.CONFIG                                  -- deep-frozen; every number in section 11
Shotgun.deepFreeze<T>(t: T): T                  -- table.freeze, recursively over table values only
Shotgun.snapshot(state: WeaponState, now: number): WeaponSnapshot   -- pure; returns a deep-frozen copy
Shotgun.remotes(): { FireRequest: RemoteEvent, ActionRequest: RemoteEvent,
                     StateChanged: RemoteEvent, ShotFired: RemoteEvent }
```

`deepFreeze` recurses into table values and leaves everything else (numbers, strings, functions,
`Vector3`, `CFrame`, `Color3`) alone. It is applied to `CONFIG` at the bottom of the shared module, to
every state `StateMachine` returns, to every snapshot, and to the replica when it arrives. That is
defect (b): a shallow freeze left `CONFIG.SPREAD_FULL_DEG` and `state.barrels` writable, so "frozen,
no writer" was true of one table and false of the ones that mattered.

`Shotgun.remotes()` does the `WaitForChild` in one place, so no caller hard-codes the path twice and
the §8 fallback changes one function.

### 5.3 The pure core

```luau
StateMachine.initial(config): WeaponState        -- deep-frozen; equipped = false, epoch = 0
StateMachine.apply(state: WeaponState, action: Action, now: number): (WeaponState, string?)
	-- returns a NEW deep-frozen state; on rejection returns the SAME state plus a reason code:
	-- "busy" | "is-open" | "is-closed" | "not-equipped" | "barrel-empty" | "no-reserve"
	-- | "barrel-full" | "bad-action"
StateMachine.setEquipped(state: WeaponState, equipped: boolean): WeaponState  -- the one writer of that field

Validator.checkShot(req: ShotRequest, rootPosition: Vector3?, config): (boolean, string?)
	-- "not-alive" | "bad-type" | "nan" | "not-unit" | "origin-far"
Validator.checkRequest(kind: unknown, ammo: unknown): (boolean, string?)
	-- accepts ONLY kind == "Reload" (ammo must be nil) and kind == "SelectAmmo" with
	-- ammo == "Slug" | "Buck". Everything else -> false, "bad-request". This is defect (d): the
	-- reducer primitives Break/Load/Close are not in this function's accepted set and therefore
	-- have no path from a client at all.

Limits.allow(bucket: Bucket?, now: number, perSecond: number): (boolean, Bucket)
	-- a one-second fixed window per key: { windowStart: number, count: number }. Pure.

Registry.new(): Registry
Registry:set(key: any, state: WeaponState): ()
Registry:get(key: any): WeaponState?
Registry:bucket(key: any, name: string): Bucket?
Registry:setBucket(key: any, name: string, bucket: Bucket): ()
Registry:forget(key: any): ()          -- removes EVERY table this registry keys by `key`
Registry:count(): number               -- how many keys are held; the leak test asserts on this

Pattern.directions(ammo: AmmoKind, aim: Vector3, rng: Random, config): { Vector3 }
	-- config.PELLETS[ammo] unit directions in a cone of config.SPREAD_FULL_DEG[ammo] about `aim`.
	-- Slug -> 1, Buck -> 9. Same code path, same cone maths (section 4).

Hits.targetOf(instance: Instance): (Instance?, string)
	-- walks `instance` and its ancestors for attribute Damageable == true -> the target root.
	-- zone = instance's HitZone attribute, else the root's, else "unknown". No root -> (nil, "")
Hits.resolve(muzzle: Vector3, directions: { Vector3 }, range: number, cast: CastFn,
             ignore: { Instance }): { Impact }
Hits.group(shooter: Player, impacts: { Impact }, ammo: AmmoKind, now: number): { HitReport }
	-- ONE report per (shot, target). 9 pellets on one boar = one report with pellets = 9

SafetyArc.isForbidden(direction: Vector3, line: DriveLine, halfAngleDeg: number): boolean

Cast.world(origin: Vector3, direction: Vector3, ignore: { Instance }): Impact?
	-- the ONLY Workspace:Raycast in this system. One RaycastParams, FilterType = Exclude,
	-- FilterDescendantsInstances = ignore, set per call. Nothing else in src/server/Weapon/ may
	-- name Workspace:Raycast (section 13.5).
```

Every function above except `Cast.world` and `Hits.targetOf` is a pure function of its arguments: no
`game:GetService`, no clock, no `Player` lookup, no `Workspace`. `now`, `rng`, `cast` and `ignore` are
parameters rather than lookups, which is what makes the whole authoritative core testable with no
input harness, no camera and no boar. `Hits.targetOf` reads attributes off Instances the caller hands
it and writes nothing. `apply` returns an immutable state; the owner holding the result is the only
mutation in the system.

**`Registry` never knows what a `Player` is.** It keys by any value. That is what makes defect (c)
testable: `weapon_state.spec` exercises `set`/`get`/`forget`/`count` with stand-in keys, so the leak
is closed by a tested function, and the owner's `PlayerRemoving` connection is a one-line call the
Reviewer can check by eye.

### 5.4 Server — `ServerScriptService.Weapon`

```luau
Weapon.start(): ()                               -- once, from WeaponBoot; asserts it is not started twice
Weapon.grant(player: Player): Tool               -- builds and gives a Tool; resets that player's state
Weapon.revoke(player: Player): ()                -- destroys the Tool, resets state, bumps epoch
Weapon.forget(player: Player): ()                -- revoke + Registry:forget: NOTHING is keyed by this
                                                 --   player afterwards. Called from PlayerRemoving.
Weapon.getSnapshot(player: Player): WeaponSnapshot?     -- deep-frozen, for tests and ROADMAP 1.7
Weapon.trackedPlayers(): number                  -- Registry:count(); the leak assertion reads this
Weapon.stats(): { shots: number, reports: number, rateDropped: number, badRequests: number,
                  granted: number, revoked: number }    -- a copy, mirroring Boar's Runtime:stats()
Weapon.setDriveLineProvider(p: DriveLineProvider?): ()
Weapon.setCast(cast: CastFn?): ()                -- nil restores Cast.world; a spec injects its own
Weapon.HitReported: RBXScriptSignal              -- (report: HitReport)
Weapon.SafetyViolated: RBXScriptSignal           -- (player: Player, aim: Vector3, muzzle: Vector3)
Weapon.StateMachine, Weapon.Validator, Weapon.Limits, Weapon.Registry, Weapon.Pattern,
Weapon.Hits, Weapon.SafetyArc, Weapon.Cast
	-- exported for specs only, exactly as src/server/Boar/init.luau exports Boar.Brain
```

There is **one** module-level owner, not a `newRuntime(world)` factory like the boar's. Reason, stated
so it is not mistaken for inconsistency: the four RemoteEvents are singletons in `ReplicatedStorage`,
so two runtimes would fight over them. The injectable parts the boar gets from its world — the cast
function and the drive-line provider — are injected individually instead, and everything worth testing
is in the pure modules.

Signals are `BindableEvent.Event` on BindableEvents the module creates at runtime. Nothing
hand-written (rule 2), and it is the choice `docs/design/boar-ai.md` §8 already made for `Despawned`,
with the same two consequences: payload tables are copied (no metatables, no sparse or mixed-key
tables), and under `SignalBehavior = Deferred` a listener does not run inside `Fire`, so a live spec
polls.

**What `start()` does, in order.** It is written out because the order matters in a Studio Play
session, where the server script can run after the first `PlayerAdded`:

1. `Shotgun.remotes()`, then connect `FireRequest.OnServerEvent` and `ActionRequest.OnServerEvent`.
2. For every `Players:GetPlayers()` already present, and then on `Players.PlayerAdded`: connect
   `CharacterAdded`, and if the player already has a character, run the same handler for it.
3. `CharacterAdded` → if `CONFIG.shouldArm(player)` then `grant(player)`.
4. `Players.PlayerRemoving` → `forget(player)`.

**Lifecycle, one line each.** `grant`: `Registry:set(player, initial)`, bump `epoch`,
`Hardware.build`, park it in the Backpack, and if `CONFIG.AUTO_EQUIP` then `Hardware.equip`. `revoke`:
destroy the Tool, reset the state, bump `epoch`. `forget`: `revoke`, then `Registry:forget(player)`,
then disconnect every per-player connection. After `forget`, `trackedPlayers()` has dropped by one and
no table in this system holds that `Player` — that is defect (c), and §13.1 asserts it.

**`equipped` is derived from the Tool's parent, not from a `Tool.Equipped` event on the server.** The
server watches `tool:GetPropertyChangedSignal("Parent")` and sets
`equipped = (tool.Parent == player.Character)` through `StateMachine.setEquipped`. Reason: whether
`Tool.Equipped` fires on the server for a Tool the server parents is exactly the thing v2 listed as
unverified, and the crosshair's visibility depends on it. `Parent` is unambiguous and needs no
verification. The **client** still uses `Tool.Equipped`/`Unequipped`, which certainly fire for the
LocalPlayer's own Tool, to bind and unbind its actions (§5.6).

### 5.5 The shot, step by step — the two-stage cast third person needs

This is the whole server flow for one `FireRequest`, written out because it is where v1 and v2 both
had defects.

1. **Rate limit.** `Limits.allow(bucket, now, CONFIG.FIRE_RATE_LIMIT)` over **received** requests, not
   accepted ones — a spammer must be cut off before the expensive path, not after. Over budget:
   drop, `stats.rateDropped += 1`, no reply.
2. **Validate.** `Validator.checkShot(req, rootPosition, CONFIG)`. `origin` is the **camera**
   position, `direction` the camera's unit `LookVector`, and the tolerance is
   `CONFIG.CAMERA_ORIGIN_TOLERANCE` studs from `HumanoidRootPart`, because under the stock
   third-person camera the origin is *meant* to be behind the character. Rejection → one
   `StateChanged` (so the client resyncs), `stats.badRequests += 1`, stop.
3. **State.** `StateMachine.apply(state, {kind = "Fire"}, now)`. Rejected → `StateChanged`, stop. The
   fired barrel's `loaded` entry is the ammo for this shot; `range = CONFIG.RANGE_STUDS[ammo]`.
4. **The ignore list, built once for this shot:** `{ character }`, plus `Workspace.WeaponEffects` if
   it exists (it normally does not on the server — §2.3 item 7). The character contains the equipped
   Tool, so the gun's own Handle is excluded with it. **This is defect (a):** without it the camera
   ray, which starts 12–16 studs behind the character, resolves onto the shooter's own back.
5. **Aim point.** `cast(origin, direction * range, ignore)`. Hit → `aimPoint` is the impact position;
   no hit → `aimPoint = origin + direction * range`.
6. **Muzzle.** `muzzle = muzzleAttachment.WorldPosition`, read from the server's own Tool (§8). The
   client never supplies it.
7. **Aim from the muzzle.** `aim = (aimPoint - muzzle).Unit`. If
   `(aimPoint - muzzle).Magnitude < CONFIG.MIN_AIM_DISTANCE` use `direction` instead — the degenerate
   case is guarded explicitly rather than letting `.Unit` produce NaN.
8. **Pattern, then cast the pellets** from `muzzle` with the **same `ignore` list**:
   `Hits.resolve(muzzle, Pattern.directions(ammo, aim, rng, CONFIG), range, cast, ignore)`.
9. **Report.** `Hits.group(...)` → zero or more `HitReport`s; fire `HitReported` once per target.
   `stats.shots += 1`, `stats.reports += #reports`.
10. **Safety.** If a drive line is provided, `SafetyArc.isForbidden(aim, line,
    CONFIG.SAFETY_ARC_HALF_DEG)` → `SafetyViolated(player, aim, muzzle)`. **`aim`, not `direction`**:
    that is defect (e), so a published violation matches where the pellets actually went. Publish
    only; never punish.
11. **Publish.** `StateChanged:FireClient(player, Shotgun.snapshot(state, now))`, subject to
    `CONFIG.STATE_RATE_LIMIT`; `ShotFired:FireAllClients(payload)` with the muzzle and the impact
    points, for cosmetics.

Pellets originate at the muzzle and converge on the point the crosshair is over. That is the standard
third-person shooter geometry, and the reason tracers will look right in the screenshot.

**`ActionRequest` handler.** `Limits.allow(..., CONFIG.ACTION_RATE_LIMIT)`, then
`Validator.checkRequest(kind, ammo)`. `"SelectAmmo"` → one `apply`. `"Reload"` → the sequence below.
Anything else → `stats.badRequests += 1`, one `StateChanged`, no state change.

**The reload sequence, and why it is uninterruptible with no extra flag.** On an accepted `"Reload"`
the owner spawns one thread for that player and applies, in order:
`Break` (busy for `RELOAD_BREAK`), `Load`, `Load` (each busy for `RELOAD_SHELL`), `Close` (busy for
`RELOAD_CLOSE`), waiting out each window before the next and publishing a snapshot after each. The
sum is `CONFIG.RELOAD_TOTAL` = 2.0 s.

Uninterruptibility is a **property of the reducer**, not a second flag: `Break` requires
`open == false` and `Fire` requires `open == false`, so from the instant the first `Break` lands until
`Close` completes, a second `Reload` is rejected `"is-open"` and every `Fire` is rejected `"is-open"`.
One decision in one place. The thread checks `state.epoch` before each step and abandons the sequence
if it changed (the player respawned, was revoked, or left), which is the only reason `epoch` exists.

### 5.6 Client

```luau
-- PlayerScripts.Weapon (init.luau)
Weapon.start(): ()
Weapon.get(): WeaponSnapshot?           -- deep-frozen; nil until the first StateChanged arrives
Weapon.Changed: RBXScriptSignal         -- (snapshot: WeaponSnapshot)
Weapon.Input, Weapon.Effects            -- exported for specs

-- PlayerScripts.Weapon.Input
Input.start(): () ; Input.stop(): ()
Input.isAiming(): boolean
Input.AimChanged: RBXScriptSignal       -- (aiming: boolean). THE CAMERA SYSTEM'S ONLY HOOK (section 9)

-- PlayerScripts.Weapon.Effects
Effects.play(payload: ShotPayload): ()  -- cosmetic only
Effects.folder(): Folder                -- Workspace.WeaponEffects, created on first use

-- PlayerScripts.Hud
Hud.start(): ()
Hud.gui(): ScreenGui?                   -- PlayerGui.HunterHud, for specs
Hud.isCrosshairVisible(): boolean       -- read-only; there is no setter, by design (section 3.4)
Hud.readoutText(): string               -- what the label currently says, for specs
```

Input actions, bound through `ContextActionService` with exactly these names. The prefix
`DrivenHunt.Weapon.` is **reserved to this system**: a grep for it finds every binding it owns, and no
other system may use it.

| Action name | Binding | Effect | Result |
|---|---|---|---|
| `DrivenHunt.Weapon.Fire` | MouseButton1 / ButtonR2 | `FireRequest:FireServer({origin, direction})` from `workspace.CurrentCamera.CFrame` | `Pass` |
| `DrivenHunt.Weapon.Reload` | R / ButtonX | `ActionRequest:FireServer("Reload")` | `Pass` |
| `DrivenHunt.Weapon.SelectAmmo` | X / DPadLeft | `ActionRequest:FireServer("SelectAmmo", other)` where `other` is the kind the state does not currently have | `Pass` |
| `DrivenHunt.Weapon.Aim` | MouseButton2 / ButtonL2 | sets the local flag, fires `AimChanged`. **No camera write, nothing visible in this task** (§9) | `Pass` |

All four are bound on `Tool.Equipped` and unbound on `Tool.Unequipped`. **Every handler returns
`Enum.ContextActionResult.Pass`** — §2.3 item 5: `Sink` on MouseButton2 would break the stock
camera's own rotation, and `Sink` on MouseButton1 or R would swallow the Task 6 input probe that
shares those inputs. `Tool.Activated` is not the fire path: it carries no payload, so the server
would learn that a shot happened but not where it pointed (§10 source C).

**The Hud's whole content in this task**, built in code into `PlayerGui.HunterHud` (`IgnoreGuiInset =
true`, `ResetOnSpawn = false`, `DisplayOrder = 1`):

- a centred crosshair: a container `Frame`, `BackgroundTransparency = 1`,
  `Size = UDim2.fromOffset(2 * (GAP + ARM), 2 * (GAP + ARM))`, `AnchorPoint = Vector2.new(0.5, 0.5)`,
  `Position = UDim2.fromScale(0.5, 0.5)`, holding four arm `Frame`s:
  - top: `Size = UDim2.fromOffset(THICK, ARM)`, `AnchorPoint = (0.5, 1)`, `Position = UDim2.new(0.5, 0, 0.5, -GAP)`
  - bottom: same size, `AnchorPoint = (0.5, 0)`, `Position = UDim2.new(0.5, 0, 0.5, GAP)`
  - left: `Size = UDim2.fromOffset(ARM, THICK)`, `AnchorPoint = (1, 0.5)`, `Position = UDim2.new(0.5, -GAP, 0.5, 0)`
  - right: same size, `AnchorPoint = (0, 0.5)`, `Position = UDim2.new(0.5, GAP, 0.5, 0)`

  each `BackgroundColor3 = CONFIG.CROSSHAIR_COLOR`, `BorderSizePixel = 0`, with a `UIStroke` child
  (`Thickness = 1`, black) so it stays visible against sky and grass. The container is `Visible`
  **iff** `CONFIG.CROSSHAIR_ENABLED and Weapon.get() ~= nil and Weapon.get().equipped`.
- one `TextLabel`, bottom-right, `Font = Enum.Font.Code`, `TextSize = CONFIG.HUD_TEXT_SIZE`, ASCII
  only. Barrel glyphs are `*` (Live), `x` (Spent), `-` (Empty); the selected barrel is wrapped in
  `[ ]`; then the next-load ammo in upper case and the reserve; then `" R"` while `busyFor > 0`.
  Exactly: `string.format("%s %s %d%s", glyphs, string.upper(state.ammo), state.reserve, busyMark)`.
  A full gun reads `[*]* SLUG 24`; after one shot, `*[*] SLUG 24`; mid-reload, `[-]- SLUG 22 R`.
- nothing else. No hit marker, no damage numbers, no menu.

### 5.7 The client never names a target, and never casts

The research note's source 5 proposes that the server check "its own raycast … hits what the client
says it hit, within tolerance" with a 4-stud tolerance. **This design tightens that: the client sends
`{origin, direction}` and nothing else.** There is then nothing to reconcile — the server's cast *is*
the answer — and the whole "the two casts disagreed" class of bug disappears with the tolerance.

Cost, stated honestly: impact sparks appear ~1 RTT after the bang, under 100 ms at the target ping.
Only the muzzle flash is local and instant. The alternative — a shared RNG seed so both sides draw the
same pattern immediately — hands the client the pattern in advance. Rejected for v1, recorded so it is
not re-invented.

What stays unfixable and is accepted for v1 (from the note): the aim direction is unknowable to the
server, so an aimbot passes every check. Nobody should later believe this validation is stronger than
that.

---

## 6. The damage entry point — the seam, its owner, and why

### 6.1 What the boar actually is, as merged

`Boar.Body.create` (`src/server/Boar/Body.luau`) builds **one `Part`** named `Boar1`, `Boar2`… under
`Workspace.Boars` — no `Model`, no `Humanoid`, no `Health`, no attributes. The runtime keeps a private
entry list in `src/server/Boar/init.luau` (`Runtime:spawn`), and the only handle it hands out is
`{ id, part, state, position }`. `Workspace.Boars` and everything in it belongs to `Boar`
(`GAME_DESIGN.md`, Boar row; `docs/design/boar-ai.md` §2, §3).

So a design that reported hits against "a `Model` with `Damageable == true`" would report nothing at
all against the boar that exists.

### 6.2 The decision

**The damage entry point is `ServerScriptService.Boar`, and it gains one function:**

```luau
-- ServerScriptService.Boar, on Runtime
export type HitZone = string          -- v1 grey box: "body". ROADMAP 1.5 adds head/chest/leg
export type Hit = { zone: HitZone, ammo: string, pellets: number, at: number }

Runtime:takeHit(part: BasePart, hit: Hit): boolean
	-- true  = the part is one of MY live boars and the hit was recorded
	-- false = not mine, or already despawned (a late report racing a despawn is normal)

Runtime.Hit: RBXScriptSignal          -- (record: { id, zone, ammo, pellets, at })
```

**Not a damage router.** A router would be a third system, invented now, with exactly one animal to
route to and no owner of its own — the "invented foundations" failure at small scale
(`docs/PROJECT_CONTEXT.md`). It is the right answer when there are three animals and two weapons; it
is not the right answer today, and this file says so explicitly so the decision is revisited on
purpose rather than by accident (§15 B).

**Why the boar's own owner and not the weapon.** A hit changes boar state. Rule 3 says boar state has
exactly one writer, and that writer is `Boar`. `takeHit` is the *only* way in, it is on the owner, and
its v1 body is small (§6.5). The weapon never requires `Boar`, and `Boar` never requires the weapon.

`Runtime.Hit` is a **second** `BindableEvent` on the runtime. `Runtime:destroy` today destroys only
`self._signal`; it must destroy this one too, or a destroyed runtime leaves an Instance behind — the
kind of omission a spec's `afterAll` turns into a slow leak across a test run.

### 6.3 How the two are wired, without either depending on the other

The wiring lives in **`src/server/BoarBoot.server.luau`**, which owns nothing and is boot lines only.
That is already this repo's idiom: `BoarBoot` requires `TestArena` to assert the arena still matches
`Boar.CONFIG.field`, while `Boar` itself never requires `TestArena` (`docs/design/boar-ai.md` §9). The
composition root knows both systems; neither owner knows the other.

```luau
-- BoarBoot.server.luau, added after `runtime:run()`
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
Weapon.HitReported:Connect(function(report)
	if report.target:IsA("BasePart") then
		runtime:takeHit(report.target, {
			zone = report.zone, ammo = report.ammo, pellets = report.pellets, at = report.at,
		})
	end
end)
```

`takeHit` returns `false` for a part that is not one of its boars, so `BoarBoot` needs no filtering of
its own and a shot into a wall costs one linear scan over at most `Boar.CONFIG.maxBoars` entries.

**`WeaponBoot` starts the weapon; `BoarBoot` only connects to it.** Two `Script`s in
`ServerScriptService` have no defined order, so both must `WaitForChild("Weapon")` and neither may
assume the other ran first. `Weapon.HitReported` exists as soon as the module is required, before
`Weapon.start()`, which is why connecting is safe in either order.

### 6.4 How the weapon finds a target: two attributes, written by the target's owner

`Hits.targetOf` walks the hit instance and its ancestors for the attribute **`Damageable == true`**;
that instance is the target root. The zone is the hit instance's **`HitZone`** string attribute, else
the root's, else `"unknown"`. No root → the pellet is a miss and produces no report.

Attributes, not `CollectionService` tags, because attributes on a `.model.json` part are compared by
the harness today (`tools/studio_mcp.py`, `expectations_for`) and tags are not — so a hit zone
authored on disk is verifiable from disk the day models arrive. Today the boar is code-built, so:

**`src/server/Boar/Body.luau`, in `Body.create`, gains two lines:**

```luau
part:SetAttribute("Damageable", true)
part:SetAttribute("HitZone", "body")   -- the grey box is one zone; ROADMAP 1.5 splits the body
```

This is not a second writer. `Body` is *the* writer of boar Instances (its own header says so), and
these two attributes are boar-owned data the boar publishes about itself. The weapon only reads them.
When 1.5 replaces the box with a multi-part body, each part carries its own `HitZone` and **nothing in
the weapon changes** — that is the test of whether this seam is in the right place.

### 6.5 What `takeHit` does in this task, and what it must not do yet

Hit zones and wounded running are `ROADMAP.md` 1.5. So v1 of `takeHit`:

- finds the entry whose `body.part == part`; returns `false` if there is none or `entry.dead`;
- increments `entry.hits` and `entry.pelletsTaken`, stores `entry.lastHit = hit`;
- adds `hits` and `pelletsTaken` to the `Runtime:stats()` table (initialised to 0 in
  `Boar.newRuntime`, beside `pathRequests` and the rest), so a spec and the Director can see shots
  landing without a screenshot;
- fires `Runtime.Hit` once with the record;
- returns `true`.

It does **not** change speed, state or lifetime, and it does not despawn. The boar keeps fleeing. 1.5
fills this function's body and adds the zone→reaction table; nothing else in either system moves. The
player-visible feedback for a hit in this task is the weapon's own impact effect on the boar (§5.6),
which is the client's cosmetic layer and touches no boar state.

**Should being shot scare the boar?** Not in this task — it is a behaviour change to a merged system
and belongs with the reaction in 1.5. It is listed for Karen in §15.

---

## 7. What it reads, what it writes, and who owns the other end

### 7.1 Reads

| Read | Owner of that thing | Status |
|---|---|---|
| `workspace.CurrentCamera.CFrame` (client, aim ray) | camera | **unassigned** until `ROADMAP.md` 1.4b; the stock PlayerModule writes it. A read creates no writer, so the later camera owner changes nothing here |
| `Character.HumanoidRootPart.Position` (server, origin sanity) | Roblox character replication | engine |
| `Humanoid.Health > 0` (server, alive check) | Roblox | engine |
| `Tool.Parent` (server, `equipped`) | `Weapon.Hardware` and the player's own Backpack interaction | §5.4 |
| attribute `Damageable: boolean`, attribute `HitZone: string` | the target's own owner — for the boar, `Boar.Body` (§6.4) | delivered by this task |
| `DriveLine` through the injected provider | match state, `ROADMAP.md` 1.7 | not built; the provider is `nil`, so `SafetyArc` never fires |
| `Weapon.get()` / `.Changed` / `.Input.AimChanged` (the Hud reads these) | `PlayerScripts.Weapon` | this task |

The injected provider is what lets the safety hook exist before the drive line does, with no
placeholder to delete later and no second owner of the drive-line geometry. It is the same mechanism
`Boar.defaultWorld` uses for threats and paths.

### 7.2 Writes

| Write | Sole writer |
|---|---|
| authoritative `WeaponState` per player | `ServerScriptService.Weapon` |
| every granted `Tool`, its `Handle` and its `Muzzle` attachment | `ServerScriptService.Weapon.Hardware` |
| `StateChanged` (to one client), `ShotFired` (to all) | `ServerScriptService.Weapon` |
| `FireRequest`, `ActionRequest` | `PlayerScripts.Weapon.Input` |
| the client replica | `PlayerScripts.Weapon` (no setter exists) |
| `Workspace.WeaponEffects` and everything in it | `PlayerScripts.Weapon.Effects` |
| `PlayerGui.HunterHud` and everything in it | `PlayerScripts.Hud` |
| `HitReported`, `SafetyViolated` | `ServerScriptService.Weapon` |
| boar hit counters, `Runtime.Hit` | `ServerScriptService.Boar` (§6) |
| `LocalPlayer` attribute `InputProbeReady` | `ClientTests.InputReady` (§13.3) — test-only, one writer |

`Workspace.WeaponEffects` is created at runtime, on the client, during Play only. Workspace is not
Rojo-owned (`CLAUDE.md`, Layout) and the harness compares the Edit-mode DataModel, so runtime
cosmetics are invisible to it and cannot dirty a run. Every effect instance goes to `Debris:AddItem`
with its lifetime from §11; nothing accumulates.

---

## 8. Data on disk

**Everything positioned or coloured is built in code.** No `.rbxm` (banned, `CLAUDE.md`), no typed
property values in JSON (audit-002 must-fix 1 is open, `TASKS.md` row 16: `Vector3`, `CFrame` and
`Color3` fail the harness as "cannot compare"). This is the choice `docs/design/boar-ai.md` §9 made
for the boar body and `src/server/TestArena.luau` made for the arena: a number in a frozen Luau
config is linted, formatted, type-checked and diffable; the same number in JSON is none of those and
currently fails the run.

So **there is no `src/serverstorage/ShotgunTemplate/` and no `init.meta.json`.** `Hardware.build()`
creates, with `Instance.new`, from `Shotgun.CONFIG`:

- a `Tool` named `"Shotgun"`, `RequiresHandle = true`, `CanBeDropped = false`,
  `Grip = CONFIG.GRIP`;
- a `Part` named `"Handle"`, `Size = CONFIG.HANDLE_SIZE`, `Color = CONFIG.HANDLE_COLOR`,
  `Material = Enum.Material.Wood`, `CanCollide = false`, `Massless = true`, `Anchored = false`;
- an `Attachment` named `"Muzzle"` in the Handle at `CFrame.new(CONFIG.MUZZLE_OFFSET)`.

The muzzle is an **Attachment, not a number re-derived at each call site**: the server reads
`WorldPosition` for the shot (§5.5 step 6) and the client's `Effects` reads the same Attachment for
the flash, so the offset is defined once and cannot drift between the two.

`StarterPack` stays empty deliberately: it hands a Tool to **every** player automatically, and only
shooters carry a gun (`docs/PROJECT_CONTEXT.md`, "The game"). `Weapon.grant` plus `CONFIG.shouldArm`
puts that decision in one function that `ROADMAP.md` 1.7 rewrites in place.

**The one file on disk that is data:** `src/shared/Shotgun/Remotes.model.json`, in full, so nothing
is guessed:

```json
{
	"className": "Folder",
	"children": [
		{ "name": "FireRequest",   "className": "RemoteEvent" },
		{ "name": "ActionRequest", "className": "RemoteEvent" },
		{ "name": "StateChanged",  "className": "RemoteEvent" },
		{ "name": "ShotFired",     "className": "RemoteEvent" }
	]
}
```

No `properties` and no `attributes`, so there is no typed value to fail. The harness compares
`className`, properties, attributes and children recursively (`tools/studio_mcp.py`,
`expectations_for`, the `.model.json` branch, which walks from the sourcemap node's own path), and
`walk_model` reads each child's `name`, so every child must carry one. Remotes on disk beat remotes
created at runtime: the client can `WaitForChild` them deterministically, and the harness proves all
four exist with the right ClassName before anything runs.

**Fallback** if Rojo or the harness objects to a `.model.json` inside a folder module: move it to
`src/shared/ShotgunRemotes.model.json` → `ReplicatedStorage.ShotgunRemotes`. Only
`Shotgun.remotes()` changes; no owner and no interface changes. Report which one was used (rules 6
and 8) — this is the first `.model.json` in the repo (`.agent-evidence/ls-files.txt`).

---

## 9. The seam the camera/ADS task attaches to

`ROADMAP.md` 1.4b is the camera task, with its own design (`tools/architect.sh design camera`). This
design's job is to leave exactly one attachment point and to make sure the weapon does not become the
camera's owner by accident.

**The seam is `PlayerScripts.Weapon.Input.AimChanged`**, an `RBXScriptSignal` carrying one boolean.
That is all. Fixed here so it cannot be re-litigated:

1. **The weapon owns the `DrivenHunt.Weapon.Aim` action** and publishes the flag. The camera system
   **binds no input of its own for aim** — two systems binding MouseButton2 is the cursor failure with
   a different property name. If the camera task wants a different key, it changes the binding table
   in `Input.luau`; the action name and the signal do not move.
2. **The camera system is the only writer of `workspace.CurrentCamera`** and of
   `UserInputService.MouseBehavior`/`MouseIconEnabled`. The weapon reads `CurrentCamera.CFrame` for
   the aim ray and writes nothing, before or after that task (§1.2).
3. **The Hud keeps the crosshair.** If ADS should hide or change it, the Hud subscribes to the camera
   system's state and decides — the crosshair still has one writer. The camera system must not draw
   one.
4. **Nothing in the weapon changes when the camera task lands.** The two-stage cast already works
   from an arbitrary camera position, which is exactly what makes a first-person ADS camera a no-op
   for hit detection.
5. The ADS/recoil spring is pre-researched and named for that task (§10 source G) so it is not
   re-researched.

**What Karen sees in this task when she holds MouseButton2: nothing** except the stock camera's own
behaviour (it rotates with the mouse and locks the cursor while the button is held — the PlayerModule
doing that is not this system). Say so in the playtest note; do not let it be reported as a bug.

---

## 10. External sources

Sources 1–9 of `docs/research/2026-09-24-shotgun.md` are inherited whole and not restated:
raycasting, `Blockcast`/`Spherecast`, FastCast2 (rejected — MIT/ART, maintained fork of a dead
original), the viewmodel write-up, camera non-replication, Roblox units, the two ballistics articles,
and ACS (rejected — licence unconfirmable). The sources below are what the *structure* rests on. Rule
2: this is where I borrow.

### A. Roblox raycasting — `WorldRoot:Raycast`, `RaycastParams`
<https://create.roblox.com/docs/workspace/raycasting> · first-party creator docs (creator-docs is
CC BY 4.0); the API ships with the engine · actively maintained.
**Good:** the whole hit primitive. `RaycastParams.FilterType`/`FilterDescendantsInstances` excludes
the shooter's own character; `RaycastResult.Instance` is exactly the handle `Hits.targetOf` needs; ray
length is the direction's magnitude, so slug and buckshot ranges are vector lengths from the config
with no extra distance check.
**Bad:** the 15,000-stud cap is a silent hard edge (far beyond our 330); the page says nothing about
*who* should cast, which is the security question source B answers; and a ray is infinitely thin, so a
server cast at server-time positions misses a target the client saw — the lag row in §11.
**Adopted:** hitscan, server-side, one ray per projectile, slug 1 and buckshot 9, wrapped behind
`CastFn` **with an ignore list** so the pipeline stays pure and testable (`Weapon.setCast`,
`Weapon.Cast`). The ignore list is the fix for defect (a).

### B. Roblox RemoteEvents and client/server trust
<https://create.roblox.com/docs/scripting/events/remote-events-and-callbacks> · first-party (CC BY
4.0) · actively maintained.
**Good:** the authority for the shape used here — `FireClient(player, …)` for one client's state,
`FireAllClients` for cosmetics, and the flat statement that client input is untrusted. It documents
that any client can fire any RemoteEvent with any arguments, which is why `Validator` type-checks
every field instead of assuming a `Vector3` arrives, and why `checkRequest` is a whitelist.
**Bad:** it supplies no rate limiter, no schema validation and no replay protection — all three are
ours. It does not distinguish "cosmetic broadcast" from "state update", a distinction this design
leans on (`ShotFired` vs `StateChanged`). Its table-serialisation rules are also the trap behind
§2.3 item 1: a table that is neither a dense array nor a pure dictionary does not survive.
**Adopted:** two client→server remotes, both rate-limited in one place in the owner; two
server→client remotes, one targeted, one broadcast; every inbound field type-checked before use;
every table on the wire dense.

### C. `ContextActionService` and `Tool`
<https://create.roblox.com/docs/reference/engine/classes/ContextActionService> ·
<https://create.roblox.com/docs/reference/engine/classes/Tool> · first-party · actively maintained.
**Good:** `BindAction` keys every binding to a **name**, with a priority stack and an explicit
`Sink`/`Pass` result — a per-action owner instead of a global input router, which is the structural
answer to "three scripts set the cursor". `Tool` gives `Equipped`/`Unequipped`, Backpack handling and
a replicated model in the character's hand — the last of which is why §1.1 can ship without a
viewmodel.
**Bad:** `Tool.Activated` carries no payload, so it cannot be the fire path; CAS bindings are
per-client, so nothing about them is authoritative; the stack means a careless `Sink` silently steals
another system's input (§2.3 item 5); mobile needs `CreateTouchButton` handling this design does not
cover (v1 is PC — §15 E).
**Adopted:** a `Tool` for equip/unequip and the in-hand model; CAS for every key under the reserved
`DrivenHunt.Weapon.*` names, every handler returning `Pass`; a RemoteEvent, not `Tool.Activated`, as
the fire path.

### D. "Thin script, fat module" bootstrap — as popularised by Knit
<https://github.com/Sleitnick/Knit> · MIT (`LICENSE.md` in the repo). Maintenance: widely used, single
maintainer, and the author has publicly stepped back from active development. **Only the pattern is
taken, never the package, so nothing here depends on that status.**
**Good:** one `Script` per side whose only job is to `require` and start modules; all logic in
ModuleScripts, so tests and other systems can reach it, and start order explicit rather than
emergent from Roblox's undefined script ordering.
**Bad:** Knit itself brings a service/controller registry, networking and a lifecycle this project
does not need and which would own things this design owns — the ACS mistake at smaller scale.
**Adopted:** the bootstrap shape only (`WeaponBoot.server.luau`, `WeaponBoot.client.luau`). No
dependency added. This repo already uses it: `src/server/BoarBoot.server.luau`,
`src/server/ArenaBoot.server.luau`.

### E. Roblox attributes
<https://create.roblox.com/docs/studio/properties#instance-attributes> · first-party · actively
maintained.
**Good:** typed per-instance data, settable from a Rojo `.model.json` `attributes` block, readable at
runtime with `GetAttribute`, and — decisively — **compared by the existing harness** when the value is
a plain string/number/bool. So `HitZone = "Head"` is verifiable from disk the day art models arrive; a
`CollectionService` tag is not.
**Bad:** attribute names are strings with no schema, so a typo silently yields `nil` — mitigated by
`Hits.targetOf` returning the explicit `"unknown"` rather than guessing; and attribute values share
the harness's typed-value limit, so a `Vector3` attribute would fail.
**Adopted:** `Damageable: boolean` on the target root, `HitZone: string` on the hit part, as the
weapon↔animal contract (§6.4).

### F. Roblox `ScreenGui` and `GuiObject` layout
<https://create.roblox.com/docs/reference/engine/classes/ScreenGui> ·
<https://create.roblox.com/docs/ui/positioning-and-sizing> · first-party · actively maintained.
**Good:** `ScreenGui.IgnoreGuiInset` is what puts a crosshair at the true screen centre rather than
below the Roblox topbar; `AnchorPoint` + `UDim2.fromScale(0.5, 0.5)` centres without arithmetic;
`ResetOnSpawn = false` keeps the Hud across respawns; `DisplayOrder` gives a deterministic stack. A
crosshair is four `Frame`s — no image asset, so nothing to upload and nothing to review as a binary.
**Bad:** every useful property (`UDim2`, `Color3`) is a typed value, so the Hud cannot be authored in
`.model.json` today (§8) and must be built in code; and `Visible` on a child means nothing if an
ancestor is hidden or the `ScreenGui` is disabled — precisely the previous project's "visibility audit
ignored parent visibility and certified a blank screen twice" (`docs/PROJECT_CONTEXT.md`). The client
spec therefore walks the whole ancestor chain (§13.2).
**Adopted:** one `ScreenGui` (`HunterHud`) built in code by the single UI owner, with a crosshair of
four frames and one text label.

### G. EgoMoose `rbx-fractality-spring` — **named, deliberately not adopted here**
<https://github.com/EgoMoose/rbx-fractality-spring> · MIT · not archived; a typed rewrite of
Fraktality's `spr`; Wally `egomoose/fractality-spring`.
**Good:** small, typed, MIT, and the right answer for the ADS and recoil springs.
**Bad:** single maintainer, small surface; and adding it now touches `wally.lock` and
`devpackages.sha256` for code this task does not ship.
**Decision:** recorded as `ROADMAP.md` 1.4b's dependency so that task does not re-research it.

### H. Luau `table.freeze` / `table.clone`
<https://luau.org/library> (Luau, MIT; `table.freeze` and `table.clone` are Luau additions documented
there) · actively maintained by Roblox's Luau team.
**Good:** `table.freeze` makes a write **error**, which is rule 3 enforced by the engine rather than
by policy — the strongest form of "one writer" available in this language. `table.clone` is the cheap
copy a pure reducer needs.
**Bad:** **both are shallow**, and that is exactly defect (b): freezing `CONFIG` left
`CONFIG.SPREAD_FULL_DEG` writable, and cloning a state then mutating `clone.barrels` would mutate the
input's array too. Nothing in the language warns you.
**Adopted:** `Shotgun.deepFreeze` over every published table, and in `StateMachine.apply` a clone of
**each nested array** before it is written, never just the outer table. §13.1 asserts a nested write
errors and that `apply` never mutates its input.

### I. Borrowed from inside this repo (rule 2 applies to internal patterns too)
`docs/design/boar-ai.md` §3–§4 and `src/server/Boar/init.luau`: the folder module that owns state, a
pure decision module tested with 10,000 steps and no physics, Instances behind one writer, the world
injected, one named function for a policy a later milestone replaces (`CONFIG.isThreat`), and
`Runtime:stats()` as the cheap way to assert on a live system without a screenshot.
`Shotgun.CONFIG.shouldArm` is `isThreat` with the same migration path, `Weapon.setCast` is
`Boar.defaultWorld` at smaller scale, and `Weapon.stats()` is `Runtime:stats()`. The second system in
a repo either establishes the conventions or fights them.

**Pattern adopted overall:** server-authoritative hitscan with an ignore list (A) behind untrusted,
rate-limited, whitelisted, type-checked remotes (B); `Tool` plus named, passing CAS actions for input
(C); thin boot scripts over fat modules (D); attributes as the cross-system data contract (E); one
code-built `ScreenGui` under one UI owner (F); deep-frozen published state (H); the repo's own
owner/pure-core/instance-writer split (I). Nothing is invented except the safety arc, which has no
external pattern because it is this game's own mechanic — its whole content is a dot product against
the drive-line normal, one function and one number, placed in `SafetyArc.isForbidden` and called from
step 10 of §5.5, publishing only.

---

## 11. Numeric targets — the one config table

Ballistics and feel numbers are the research note's ("Numeric targets"), at 1 stud = 0.28 m. Budgets,
limits and tolerances are this design's. **All of them live in `Shotgun.CONFIG`, deep-frozen, and
nowhere else. No magic number outside it.**

| Field | Value | Where from |
|---|---|---|
| `BARRELS` | 2 | break action, two barrels |
| `RANGE_STUDS` | `{ Slug = 330, Buck = 100 }` | note: 100 yd and 30 yd MPR. **Keyed by `AmmoKind`** (v2 had `SLUG_RANGE`/`BUCK_RANGE`) so `Pattern` and `Hits` never branch on ammo |
| `PELLETS` | `{ Slug = 1, Buck = 9 }` | note: 00 buck, standard load count. Replaces v2's `BUCK_PELLETS`, same reason |
| `SPREAD_FULL_DEG` | `{ Slug = 0.16, Buck = 1.6 }` (degrees, **full cone**) | note; ~2.8-stud circle at 100 studs for buck, effectively an exact ray for slug |
| `SLUG_CAST_RADIUS` | 0 (pure raycast) | this design. `Spherecast` forgiveness is the named dial if Karen reports misses (note source 2); not built now |
| `BARREL_DELAY` | 0.25 s | note, feel number |
| `RELOAD_BREAK` / `RELOAD_SHELL` / `RELOAD_CLOSE` | 0.5 / 0.45 / 0.6 s | this design; 0.5 + 2×0.45 + 0.6 = **2.0 s** |
| `RELOAD_TOTAL` | 2.0 s | Karen's feel number. §13.1 asserts `BREAK + 2*SHELL + CLOSE == RELOAD_TOTAL` |
| `START_RESERVE` | 24 shells, plus 2 loaded | this design; ~12 reloads in a 10-minute drive |
| `INITIAL_AMMO` | `"Slug"` | this design; the gun starts loaded |
| `AUTO_EQUIP` | `true` | this design. The Tool is put in the hand on spawn, not left in the Backpack: a grey-box playtest should not start with Karen hunting for the hotbar, and the crosshair's visibility rule keys off `equipped`. One boolean to flip (§15 G) |
| `CAMERA_ORIGIN_TOLERANCE` | 30 studs from `HumanoidRootPart` | this design. The stock camera's zoom is the player's; this rejects absurd origins, nothing more |
| `MIN_AIM_DISTANCE` | 4 studs | below it the muzzle→aim-point vector is degenerate (§5.5 step 7) |
| `DIR_UNIT_TOLERANCE` | \|dir\|−1 ≤ 1e-3 | this design |
| `SAFETY_ARC_HALF_DEG` | 45 (degrees, **half angle**) | this design; the provider is `nil` in v1, so it never fires |
| `FIRE_RATE_LIMIT` | 6 received requests/s per player, excess dropped and counted | this design; 0.25 s barrel delay + 2.0 s reload gives a true max near 4/s |
| `ACTION_RATE_LIMIT` | 10 /s per player | this design |
| `STATE_RATE_LIMIT` | ≤ 20 `StateChanged`/s per player | this design; a spammer can force at most 16 |
| `HANDLE_SIZE` | `Vector3.new(0.4, 0.5, 4.4)` | 4.4 studs ≈ 1.23 m, a shotgun's length at 0.28 m/stud |
| `HANDLE_COLOR` | `Color3.fromRGB(70, 55, 45)` | grey-box wood-brown. **Check it on screen** against grass and the grey plate, the way `Boar.CONFIG.BODY_COLOR` had to be (Task 22, where albedo × ambient made RGB(90,80,70) render near-black) |
| `GRIP` | `CFrame.new(0, 0, 1.4)` | the hand holds the gun 1.4 studs behind centre; the Handle's **−Z is the muzzle** (`src/server/Boar/Body.luau` notes the same convention: "a Part's LookVector is its -Z"), so the barrel points away from the player. **Verify in the screenshot** — "a knife held backwards for three rounds" (`docs/PROJECT_CONTEXT.md`). If it is backwards, the fix is `CFrame.new(0, 0, -1.4) * CFrame.Angles(0, math.pi, 0)`, and report which was needed |
| `MUZZLE_OFFSET` | `Vector3.new(0, 0, -2.2)` | half of `HANDLE_SIZE.Z`: the barrel tip. Becomes the `Muzzle` Attachment (§8) |
| `TRACER_LIFETIME` / `IMPACT_LIFETIME` / `FLASH_LIFETIME` | 0.06 / 1.0 / 0.05 s | all through `Debris:AddItem` |
| `EFFECT_MAX_PER_SHOT` | 24 | 9 tracers + 9 impacts + flash, with headroom; a hard cap so a bug cannot flood Workspace |
| `CROSSHAIR_ENABLED` | `true` | the one boolean the Hud reads to draw it at all |
| `CROSSHAIR_ARM_PX` / `_GAP_PX` / `_THICK_PX` | 8 / 5 / 2 | a 26-px cross, readable at 1080p without covering the boar |
| `CROSSHAIR_COLOR` | white, with a 1-px black `UIStroke` | readable against sky and grass |
| `HUD_TEXT_SIZE` | 18, `Enum.Font.Code`, ASCII only | this design |
| `CAMERA_DRIFT_TOLERANCE` | 0.5 studs | §13.3: how far the camera may move relative to its subject across the aim hold while the weapon writes nothing |
| `shouldArm(player)` | `return true` | mirroring `Boar.CONFIG.isThreat`. `ROADMAP.md` 1.7 makes it `player.Team == Teams.Shooters` and touches nothing else |

### Performance and correctness targets, each one checkable

| Target | How it is checked |
|---|---|
| Server raycasts per shot ≤ `PELLETS[ammo]` + 1 (the camera ray) | `weapon_hits.spec`: the injected cast counts its calls |
| Every cast in a shot receives the shooter's character in `ignore` | `weapon_hits.spec`: the injected cast records the list |
| Server time per shot ≤ 0.5 ms | `weapon_shot.spec`: 1,000 `Pattern.directions` + `Hits.group` cycles under 500 ms |
| `StateMachine.apply` ≤ 10 µs | `weapon_state.spec`: 10,000 applies under 100 ms (the boar's `Brain:step` target and method) |
| Client frame budget ≤ 0.2 ms/frame at 60 fps | effects only; no per-frame viewmodel exists in this task |
| Typed-value harness problems from this task | **0** (§8) |
| Effect instances alive 2 s after a shot | 0 (`Debris`) |
| Per-player tables held after a player leaves | **0** (`Weapon.trackedPlayers()`, §13.1) |
| Zero errors, zero skipped tests | `tests/TestKit.luau` fails the run otherwise |

**Lag, stated as a number because it will be felt.** There is no lag compensation in v1 — state rewind
is a system of its own. At 100 ms RTT a boar at `Boar.CONFIG.SPRINT_SPEED` (38 studs/s) is ~3.8 studs
from where the shooter saw it, and the boar is 5.5 studs long (`Boar.CONFIG.BODY_SIZE`). That is most
of a body length: shots that looked good will miss. This is the single most likely thing Karen reports
as "the gun feels wrong". Mitigation order: (1) the slug `Spherecast` dial above, (2) lag compensation
as its own designed system — **never** a fudge inside the weapon.

---

## 12. Karen's five feel defaults, as config

She has not played it; these are defaults to be tuned, not decisions.

| # | Karen's default | Config field(s) | Alternative, if she says so |
|---|---|---|---|
| 1 | Spread: realistic — pellets genuinely miss past 100 studs | `SPREAD_FULL_DEG.Buck = 1.6`, `RANGE_STUDS.Buck = 100` | one number: a generous cone |
| 2 | Reload: 2.0 s, one uninterruptible action | `RELOAD_BREAK`/`RELOAD_SHELL`/`RELOAD_CLOSE`/`RELOAD_TOTAL`; the server runs Break→Load→Load→Close itself, and because `Break` and `Fire` both require `open == false`, nothing can interrupt it (§5.5) | per-shell loading that can be cut short: the reducer already has the `Load` primitive, so it is a server-loop change, not a redesign |
| 3 | A crosshair | `CROSSHAIR_*`; owner `PlayerScripts.Hud` (§3.4) | size, colour, or none — the Hud reads one boolean, `CROSSHAIR_ENABLED`. `CROSSHAIR_ARM_PX = 0` is not the way |
| 4 | Barrel select: automatic, next live barrel | `StateMachine.apply` advances `selected` on `Fire` to the other barrel when that barrel is `Live`, and leaves it alone otherwise | a manual selector key: one more CAS action and one more `ActionKind` |
| 5 | Loading only while the action is broken open | the reducer rejects `Load` unless `open == true` (reason `"is-closed"`) and rejects `Fire` while `open` (reason `"is-open"`) | — |

Defaults 2 and 5 look like they conflict and do not: the state machine keeps `open` as a real state
and enforces "no `Load` unless open"; the player triggers **one** action, `Reload`, and the server
drives the primitives through the 2.0 s window. Both hold at once, and the invariant is a spec
assertion, not a comment. `SelectAmmo` changes only the *next* load's kind (`state.ammo`); it never
rewrites shells already in the barrels (`state.loaded`).

---

## 13. How it is tested

### 13.1 Server specs — everything authoritative, testable with no Studio interaction

`tests/server/` → `ServerStorage.Tests` (`CLAUDE.md`, Layout). They **write their own numbers rather
than importing `CONFIG`** for the assertion, following `tests/server/test_arena.spec.luau`, so a spec
disagreeing with the config is a finding and not a tautology. Where a spec needs a config table to
drive a pure function, it builds its own literal table.

**`weapon_state.spec.luau`** — `StateMachine`, `Registry`, `Limits`, `Shotgun.snapshot`:

1. `initial`: closed, both barrels `Live`, `loaded` both `"Slug"`, `selected == 1`, `reserve == 24`,
   `busyUntil == 0`, `equipped == false`; the state is frozen **and so is `state.barrels`** — a write
   to `state.barrels[1]` errors (defect (b));
2. `Shotgun.CONFIG.SPREAD_FULL_DEG` is frozen: `CONFIG.SPREAD_FULL_DEG.Buck = 9` errors (defect (b));
3. `Fire` with `equipped == false` → `"not-equipped"`, state unchanged;
4. `setEquipped(state, true)` then `Fire` → barrel 1 `Spent`, `loaded[1] == "None"` (never a hole —
   §2.3 item 1), `selected == 2`, `busyUntil == now + 0.25`;
5. `Fire` inside the barrel delay → `"busy"`, and the returned state is the **same table**;
6. `Fire` on a `Spent` barrel → `"barrel-empty"`; with both spent → `"barrel-empty"` and `selected`
   does not move;
7. `Fire` while `open` → `"is-open"`;
8. `Break` → `open == true`, both barrels `Empty`, `loaded` both `"None"`; `Load`×2 → both `Live`,
   `reserve == 22`, `loaded` both the current `ammo`; `Close` → `open == false`, `selected == 1`;
9. `Break` while already `open` → `"is-open"` — the assertion that makes the reload uninterruptible
   (§5.5), so a second `Reload` mid-sequence cannot start one;
10. `Load` while closed → `"is-closed"`; `Load` into a `Live` barrel → `"barrel-full"`; `Load` with
    `reserve == 0` → `"no-reserve"`, and the sequence still completes with one shell;
11. `SelectAmmo` flips `ammo` and **does not** change `loaded`;
12. an unknown `kind` → `"bad-action"`;
13. `0.5 + 2 * 0.45 + 0.6 == 2.0` and equals `CONFIG.RELOAD_TOTAL` — the feel number is an assertion,
    not a comment;
14. every returned state is deep-frozen and a different table from the input, and the input's
    `barrels`/`loaded` are byte-identical afterwards (`table.clone` is shallow — source H);
15. `Shotgun.snapshot(state, now)`: `busyFor == math.max(0, busyUntil - now)`, never negative, no
    `busyUntil` and no `epoch` field on the snapshot, and the snapshot is deep-frozen;
16. `Registry`: `set`/`get`/`bucket`/`setBucket` round-trip with a stand-in key; `count() == 1`; after
    `forget(key)`, `get`, `bucket` and `count()` all report nothing held — **defect (c), tested**;
17. `Limits.allow`: `perSecond` calls in one window pass, the next fails; a call after the window
    rolls passes again; the returned bucket is a new table and the caller's old one is unchanged;
18. 10,000 applies under 100 ms.

**`weapon_shot.spec.luau`** — `Validator`, `Pattern`, `SafetyArc`, all pure:

1. `checkShot`: a non-`Vector3` origin → `"bad-type"`; `0/0` components → `"nan"`; a magnitude-2
   direction → `"not-unit"`; an origin 60 studs from the root → `"origin-far"`; an origin **20 studs**
   away → **accepted** (the third-person camera case); `rootPosition == nil` → `"not-alive"`;
2. `checkRequest`: `("Reload", nil)` and `("SelectAmmo", "Slug")` accepted; **`"Break"`, `"Load"`,
   `"Close"`, `"Fire"`, `""`, `nil`, `42`, a table, and `("SelectAmmo", "Grenade")` all rejected
   `"bad-request"` — defect (d), and the list is written out so a later `ActionKind` cannot leak in;
3. `Pattern`: 1 direction for `"Slug"`, 9 for `"Buck"`; every direction unit to 1e-6;
4. `Pattern`, **`Buck` only, seeded `Random.new(1337)`, 1,000 shots**: the angle between every
   direction and the aim is ≤ **0.8°** (half of the 1.6° full cone), the maximum over all 9,000 is
   > **0.4°**, and the mean is between 0.2° and 0.7°. A 2× error in either direction fails. The
   numbers are literals, the seed is fixed, and nothing depends on a single draw — that is defect (f).
   If seed 1337 does not satisfy it, pick the seed that does and say in a comment that it is a
   fixture;
5. `Pattern`, `Slug`, same seed: the single direction is within **0.08°** of the aim. The "at least
   one beyond a quarter cone" half of the assertion is **not** applied to `Slug` (defect (f));
6. `Pattern`: `Random.new(42)` twice gives identical lists; `Random.new(43)` gives a different one;
7. `Pattern`: an aim of `Vector3.zero` errors — assert the error, do not accept a silent fallback;
8. `SafetyArc`: true straight along the drive-line normal; false at 90°; at exactly 45° the documented
   side of the boundary; and it is never called with a `nil` line (the owner checks first);
9. 1,000 `Pattern` + `Hits.group` cycles under 500 ms.

**`weapon_hits.spec.luau`** — `Hits` with an **injected** cast, plus `Cast.world` against two real
parts in the spec's own folder (`afterAll` destroys them; instance destruction is not the Rojo file
crash of `CLAUDE.md`, which is about files disappearing):

1. `targetOf` on a part with `Damageable == true` → that part, zone from its `HitZone`;
2. `targetOf` on a child part of a model with `Damageable == true` → the model; zone from the child,
   falling back to the model, falling back to `"unknown"`;
3. `targetOf` on plain scenery → `nil` (a miss, no report);
4. `resolve` calls the cast **once per direction and no more** (count it), and passes the ignore list
   it was given to **every** call, unmodified — defect (a);
5. `group`: 9 pellets on one target → **one** report, `pellets == 9`, a `zones` tally summing to 9,
   `nearest` the smallest distance, `zone` the majority zone;
6. `group`: pellets split across two targets → two reports, tallies summing correctly;
7. `group`: a tie between two zones resolves to the **nearest** impact's zone;
8. `Cast.world` returns an `Impact` whose `instance` is a part placed in the ray's path, with
   `distance` within 0.05 studs of the arithmetic; and returns `nil` for the same ray when that part
   is in `ignore` — the mechanical proof that the ignore list is wired to
   `FilterDescendantsInstances`.

**`boar_hit.spec.luau`** — the seam (§6), one boar runtime with the spec's own injected world (the
pattern `tests/server/boar_body.spec.luau` already uses: its own folder, its own field, teardown in
`afterAll`):

1. after `Runtime:spawn()`, the Part carries `Damageable == true` and `HitZone == "body"`;
2. `takeHit(part, hit)` → `true`; `stats().hits == 1` and `stats().pelletsTaken == 9`;
3. `Runtime.Hit` fires exactly once with `id`, `zone`, `ammo`, `pellets` (polled — signals may be
   deferred);
4. `takeHit` on a foreign Part → `false`, and no counter moves;
5. `takeHit` after despawn → `false`;
6. the boar's state, position and lifetime are **unchanged** by a hit in this milestone — the
   assertion that keeps 1.5's reaction out of 1.4;
7. `Runtime:destroy()` leaves no `BindableEvent` behind (§6.2).

### 13.2 Client spec — `tests/client/weapon_client.spec.luau`, the parts that need no input

Reaching modules through `Players.LocalPlayer:WaitForChild("PlayerScripts").Weapon`:

1. `ReplicatedStorage.Shotgun.Remotes` holds the four RemoteEvents with the right ClassNames;
2. `Shotgun.CONFIG` is frozen **and so is `CONFIG.SPREAD_FULL_DEG`** (a nested write errors), and
   `SPREAD_FULL_DEG.Buck == 1.6`;
3. `Weapon.get()` is a deep-frozen table with exactly the `WeaponSnapshot` fields and no others; a
   write to it errors **and so does a write to `get().barrels[1]`**;
4. `Weapon.Input.AimChanged` is an `RBXScriptSignal`; `Input.isAiming()` is a boolean;
5. **the visibility assertion, and it is the point of this spec.** With the Tool equipped:
   `Hud.gui()` exists, is a `ScreenGui`, `Enabled == true`, its `Parent` is the `PlayerGui`, and
   **every ancestor up to the DataModel is present**; the crosshair container and all four arms are
   `Visible`, with no ancestor `Visible == false` and no ancestor `Transparency == 1`; and the
   container's `AbsolutePosition + AbsoluteSize / 2` is within 2 px of
   `workspace.CurrentCamera.ViewportSize / 2`. This is what makes "a visibility audit ignored parent
   visibility and certified a blank screen twice" (`docs/PROJECT_CONTEXT.md`) impossible to repeat. It
   does not replace the screenshot;
6. `Hud.readoutText()` matches `^[%[%*%-x%]]+ [A-Z]+ %d+ ?R?$` and, for a full gun, is exactly
   `[*]* SLUG 24`;
7. **the exploit path, defect (d) end to end.** `ActionRequest:FireServer("Break")`, then `"Load"`,
   `"Close"`, `"Fire"`, `""`, `42` and `{}`; and `FireRequest:FireServer("not a table")` and
   `FireRequest:FireServer({origin = "x", direction = Vector3.zero})`. After 1 s the snapshot's
   `barrels`, `loaded`, `reserve`, `open` and `ammo` are all what they were, and the server logged no
   error. A client can reach only `"Reload"` and `"SelectAmmo"`, and neither of those was sent.

### 13.3 Client spec — the harness-driven input, and exactly what the scenario file must contain

Task 6 has landed (`TASKS.md` row 6, harness `PASS: 26/26`), so the three things v2 asked it to prove
are proved: a keyboard down/up, a mouse button down/up and an observable ordered gap all reach
`ContextActionService`/`UserInputService` in the Play client, and a client spec asserts on them.

**Four facts about the landed harness that shape what follows** (`tools/studio_mcp.py`:
`load_scenarios`, `scenario_batches`, `replay_input`; `tests/client/input_driving.spec.luau`):

- **One ready attribute for the whole file.** `replay_input` waits ≤ 20 s for `readyAttribute` on
  `LocalPlayer` to carry this run's token, then replays **every** scenario in order. Whoever sets it
  first starts the replay.
- **The mouse position is per scenario.** `scenario_batches` resets `last_xy` for each scenario, and
  StudioMCP refuses a button action whose call establishes no position. **Every scenario that uses a
  mouse button must begin with a `moveTo`.**
- **Consecutive same-device steps travel in one call**, so their spacing is sub-frame; a `wait` splits
  the batch and is slept in Python, so it can only ever be *longer* than asked. Every assertion below
  that depends on two inputs landing close together uses the batched form, and every assertion that
  depends on them landing far apart uses a `wait` with margin.
- **Steps are validated before Play** (unknown device or action, missing `key`/`button`, non-numeric
  `moveTo`, `wait` outside 0–10000 ms), so a malformed scenario fails the run early rather than
  silently.

**One rendezvous, one writer of the ready attribute: `tests/client/InputReady.luau`.**

```luau
InputReady.ATTRIBUTE = "InputProbeReady"          -- must equal the file's `readyAttribute`
InputReady.EXPECTED = { "input_driving", "weapon_client" }   -- every spec the replay must not race
InputReady.ready(name: string): ()
	-- asserts `name` is in EXPECTED (a typo must fail loudly, not silently never signal);
	-- marks it done; when EVERY expected name is done and TestKit.openToken() returns a token,
	-- sets Players.LocalPlayer:SetAttribute(ATTRIBUTE, token). That is the ONLY writer of it.
```

If a listed spec never becomes ready, the attribute is never set, `replay_input`'s
"[input] the client bound its listeners and published this run's token" check **fails** after 20 s and
the run is red. There is no path where the replay proceeds against an unprepared client, and no path
where a missing spec passes quietly — the false-PASS shape this project exists to avoid.

`tests/client/input_driving.spec.luau` changes by two lines: it calls `InputReady.ready("input_driving")`
where it now sets the attribute itself. Nothing else in Task 6's spec changes, and its own assertions
are untouched.

**Why the Tool is equipped by a cue key and not before the replay.** Task 6's scenario sends
MouseButton1 and `R` — the fire and reload inputs. If the Tool were in the character at handshake
time, `key-mouse-order` would spend a barrel and start a reload, and the weapon scenario's start state
would be a guess. So the weapon spec signals ready with the Tool **in the Backpack** (nothing bound),
and equips it only when it sees a cue key that the weapon does not use. `Q` is the cue; the weapon
spec binds `DrivenHunt.Test.WeaponCue` on it at require time and unbinds it in `afterAll`. On the cue
the spec calls `Humanoid:EquipTool(tool)` — the engine's own API, which is what the Backpack does, so
`Tool.Equipped` fires on the client and the server sees `Tool.Parent` become the character (§5.4) —
and waits for `Weapon.get().equipped == true`. Equipping is the spec's *arrangement*; everything
asserted afterwards arrives through the real input path.

**What the scenario file must contain.** `tests/client/input_scenarios.txt` keeps
`"version": 1`, `"readyAttribute": "InputProbeReady"` and the existing `key-mouse-order` scenario
**first and unchanged**, and gains this one **after** it (so Task 6's own gap assertion, which
measures the largest gap between consecutive matched events, cannot be affected by anything here):

```json
{
	"name": "weapon-fire-reload-ammo",
	"spec": "ClientTests.weapon_client.spec",
	"steps": [
		{ "device": "keyboard", "action": "keyPress", "key": "Q" },
		{ "device": "wait", "ms": 1500 },
		{ "device": "mouse", "action": "moveTo", "x": 250, "y": 250 },
		{ "device": "mouse", "action": "mouseButtonClick", "button": "left" },
		{ "device": "mouse", "action": "mouseButtonClick", "button": "left" },
		{ "device": "wait", "ms": 900 },
		{ "device": "mouse", "action": "mouseButtonClick", "button": "left" },
		{ "device": "wait", "ms": 900 },
		{ "device": "mouse", "action": "mouseButtonClick", "button": "left" },
		{ "device": "wait", "ms": 600 },
		{ "device": "keyboard", "action": "keyPress", "key": "R" },
		{ "device": "keyboard", "action": "keyPress", "key": "R" },
		{ "device": "wait", "ms": 400 },
		{ "device": "mouse", "action": "mouseButtonClick", "button": "left" },
		{ "device": "wait", "ms": 2600 },
		{ "device": "keyboard", "action": "keyPress", "key": "X" },
		{ "device": "wait", "ms": 600 },
		{ "device": "mouse", "action": "mouseButtonDown", "button": "right" },
		{ "device": "wait", "ms": 500 },
		{ "device": "mouse", "action": "mouseButtonUp", "button": "right" },
		{ "device": "wait", "ms": 800 }
	]
}
```

Step by step, and why each is written that way:

| Steps | What it drives | Why this form |
|---|---|---|
| `Q`, `wait 1500` | the cue: the spec equips the Tool and waits for `equipped` | keeps the Tool out of the character during scenario 1 |
| `moveTo 250,250` | establishes the mouse position for this scenario | **mandatory**: without it StudioMCP refuses the first button (§2.3 item 2). 250,250 is the coordinate Task 6 proved reaches the viewport |
| two clicks, **no wait between them** | fire barrel 1; the second must be rejected `"busy"` | batched into one call, so the second is certainly inside `BARREL_DELAY` whatever the RPC latency. **One** barrel spent |
| `wait 900`, click | fire barrel 2 | 900 ms » 250 ms delay, so it is past the delay even with slow RPCs |
| `wait 900`, click | both barrels spent: **no phantom shot** | nothing may change |
| `wait 600`, `R`, `R` (batched) | reload starts; the second `R` must be rejected | batched, so the second arrives while `open == true`. `reserve` drops by **2, not 4** |
| `wait 400`, click | a fire attempt **mid-reload**, rejected `"is-open"` | 0.4 s into a 2.0 s window leaves ~1.6 s of margin for latency. The uninterruptible property of feel default 2 |
| `wait 2600` | the reload completes | 2.0 s + RTT + margin, inside StudioMCP's 10,000 ms cap |
| `X` | `SelectAmmo` | `ammo` flips to `"Buck"`, `loaded` unchanged |
| `wait 600`, RMB down, `wait 500`, RMB up, `wait 800` | aim on and off | separate calls, which is why the earlier `moveTo` matters; the trailing wait lets the last snapshot land before the assertions |

**The assertions this unlocks**, all in `weapon_client.spec.luau`, all through `Weapon.get()` and
never through internals. The spec records every `Weapon.Changed` snapshot with its `os.clock()` at
require time and asserts over that log, waiting up to 40 s for it to complete (the replay of both
scenarios takes ~20 s; the harness then allows 60 s for the client report):

1. after the cue, some snapshot has `equipped == true`, `barrels == {"Live","Live"}`,
   `loaded == {"Slug","Slug"}`, `reserve == 24`, `selected == 1`;
2. **exactly two** snapshots in the whole log increase the number of `Spent` barrels — the two
   legitimate shots. The three rejected clicks produced no shot;
3. after the first shot, some snapshot has `barrels[1] == "Spent"`, `loaded[1] == "None"` and
   `selected == 2` (feel default 4, automatic barrel select);
4. `reserve` ends at **22**: exactly one reload of two shells, though `R` was pressed twice;
5. at least one snapshot after the `R` press has `busyFor > 0`;
6. the final snapshot: `equipped == true`, `open == false`, `barrels == {"Live","Live"}`,
   `loaded == {"Slug","Slug"}` (`SelectAmmo` did not rewrite loaded shells), `selected == 1`,
   `ammo == "Buck"`, `reserve == 22`, `busyFor == 0`;
7. `Input.AimChanged` fired exactly twice, `true` then `false`, and `Input.isAiming()` is `false` at
   the end;
8. **the camera assertion (the brief's requirement, in the strongest form that is true).** The spec
   samples `workspace.CurrentCamera` immediately before the RMB-down edge and immediately after the
   RMB-up edge and asserts: `CameraType`, `FieldOfView` and `CameraSubject` are **identical**, and the
   camera's position relative to its subject changed by no more than
   `CONFIG.CAMERA_DRIFT_TOLERANCE` studs.
   **Why not "`CFrame` byte-identical":** the stock PlayerModule is the camera's live writer and moves
   it every frame to follow the character, so a byte-identical assertion would be asserting a property
   of Roblox's camera script, not of this weapon, and would be flaky. `CameraType` and `FieldOfView`
   are the two the stock camera leaves alone and an ADS implementation would not, so they are the
   mechanical part of the proof; §13.5's grep is the rest of it. If the Builder finds the `CFrame`
   provably stable in this scene, tighten the tolerance and **report the measured drift** — do not
   claim an exactness that was not observed.

Nothing in §13.2 or §13.1 depends on the replay, so the weapon can be built and specced in that order
and the input scenario added last.

### 13.4 Screenshot (rule 5) — available, and required

`python tools/studio_mcp.py capture <name> [camera x,y,z] [look-at x,y,z]` saves the image to
`.screenshots/` in Edit or during Play (`tools/studio_mcp.py` docstring, "Screenshots as evidence";
used for Tasks 17, 18 and 22). So rule-5 evidence for this task is the Builder's own inspected
screenshots, not Karen's:

1. the shotgun **in the character's hand in third person**, from the side — the muzzle points away
   from the player (the `GRIP` check, §11);
2. the crosshair at the screen centre, over grass and over the grey plate, legible in both;
3. the barrel/ammo readout in three states: full, after one shot, mid-reload;
4. a shot at the boar: tracer from the muzzle, impact mark on the boar.

For 4, note the geometry of the arena as merged: the player spawns at `ArenaSpawn`, (0, 170)
(`src/server/TestArena.luau`, `LAYOUT.spawn`), and the boar spawns at (-40, 20)
(`Boar.CONFIG.spawnPoint`) — about 152 studs apart, beyond `RANGE_STUDS.Buck` and well beyond
`Boar.CONFIG.DETECT_RADIUS` of 40. So the shot must be walked into range, and the boar will be
fleeing by the time it is. Use slug for the screenshot, or capture with an explicit camera position.

Describe what is actually on screen, not what should be. A number is not a verification
(`docs/PROJECT_CONTEXT.md`).

### 13.5 The one-writer guard, and its status

Specs cannot prove a negative ("this module never writes the camera"). A grep can: a CI step that
fails if `CurrentCamera`, `CameraType`, `FieldOfView`, `CameraSubject`, `MouseIcon`, `MouseBehavior` or
`MouseIconEnabled` is **assigned** under `src/client/Weapon/` or `src/client/Hud/`; if
`Workspace:Raycast` is named anywhere under `src/server/Weapon/` except `Cast.luau`; or if anything
under `src/server/Weapon/` mentions `Workspace.Boars`. Reading `workspace.CurrentCamera.CFrame` must
still pass, so the pattern matches assignment, not mention.

**Status: not built in this task.** `ROADMAP.md` speed rule 1 freezes tooling and this does not block
the weapon. It is §15 D for the Director, with "the Reviewer checks §1.2 by eye" as the standing
fallback.

### 13.6 Facts the Builder must report rather than assume (rules 6 and 8)

- whether a `.model.json` inside a folder module syncs and compares as
  `ReplicatedStorage.Shotgun.Remotes` (§8 gives the one-function fallback). This is the repo's first
  `.model.json`;
- whether `Humanoid:EquipTool` in a client spec results in `Tool.Parent == character` on the **server**
  within the wait, since that is what `equipped` and therefore the crosshair depend on (§5.4). If it
  does not, say so: the fallback is for the spec to assert the Backpack state instead and for
  `AUTO_EQUIP` to carry the playtest;
- the measured RPC latency of the replay, if any assertion in §13.3 comes close to its margin
  (Task 6a note (e) already flags that the gap assertions assume latency well under 700 ms);
- the harness's unmanaged-instance scan covers `LuaSourceContainer` only (audit-002 must-fix 2,
  `TASKS.md` row 15), so a Part created by hand in Studio inside a Rojo-owned container passes a green
  run and is deleted at the next Connect. **Nothing in this system is built by hand in Studio.** There
  is no check behind that sentence yet; it is policy until Task 15.

---

## 14. `GAME_DESIGN.md` — exactly what changes

Rule 3 requires the owners table to mirror this file. **Four new rows, one filled row, one amended
row, one annotated row.** That is note (h) from the Task 23 review: v2 said "five rows" and then
described something else.

**Four new rows:**

| System | Owner (the only writer) | Location | Research note |
|---|---|---|---|
| Weapon: authoritative state, firing, hit resolution, the safety-arc check, and every granted `Tool` | `ServerScriptService.Weapon`, booted once by `ServerScriptService.WeaponBoot`. `StateMachine`, `Validator`, `Limits`, `Registry`, `Pattern`, `Hits` and `SafetyArc` are pure and private to it; `Cast` is its only caller of `Workspace:Raycast`; `Hardware` is the only writer of `Tool` Instances. It writes no boar state and no camera | `src/server/Weapon/`, `src/server/WeaponBoot.server.luau` | [shotgun](docs/research/2026-09-24-shotgun.md), [design](docs/design/shotgun.md) |
| Weapon client: the state replica, the `DrivenHunt.Weapon.*` input actions and the aim flag | `PlayerScripts.Weapon`, booted once by `PlayerScripts.WeaponBoot`. `Weapon.Input` is the only binder of those actions and the only firer of `FireRequest`/`ActionRequest`; the replica has no setter | `src/client/Weapon/`, `src/client/WeaponBoot.client.luau` | same |
| Shot cosmetics (`Workspace.WeaponEffects`, created at runtime on the client) | `PlayerScripts.Weapon.Effects`. Cosmetic only; it writes no state and decides no hit | `src/client/Weapon/Effects.luau` | same |
| Shotgun numbers (every ballistic, timing, layout and rate number; deep-frozen, no writer) | `ReplicatedStorage.Shotgun` (`Shotgun.CONFIG`), with `ReplicatedStorage.Shotgun.Remotes` holding the four RemoteEvents | `src/shared/Shotgun/` | same |

**One filled row** — replace `| UI / anything drawn | _unassigned_ | | |` with:

| System | Owner (the only writer) | Location | Research note |
|---|---|---|---|
| **UI / anything drawn** (`PlayerGui.HunterHud` and everything in it: the crosshair and the barrel/ammo readout) | `PlayerScripts.Hud`. It **reads** `PlayerScripts.Weapon` and is never called by it, so nothing but the Hud can hide or move anything drawn | `src/client/Hud/` | [design](docs/design/shotgun.md) §3.4 |

**One amended row** — append to the existing Boar row's owner cell (do not add a new row):

> … It receives hits through the single seam `Runtime:takeHit(part, hit)` and publishes `Runtime.Hit`;
> `Boar.Body` publishes the attributes `Damageable` and `HitZone` that the weapon reads. The wiring
> from `Weapon.HitReported` lives in `BoarBoot`, so neither owner requires the other
> ([shotgun design](docs/design/shotgun.md) §6).

**One annotated row** — `Input` stays `_unassigned_` as a *system*, and that is deliberate: there is
no global input router. Each system owns its named `ContextActionService` actions under a reserved
prefix, every handler returning `Pass`, and this design registers `DrivenHunt.Weapon.*`. Record that
convention in the Input row rather than naming an owner who would then own everyone's keys.

`Camera` stays `_unassigned_` and is `ROADMAP.md` 1.4b's row to fill. This task must not fill it.

---

## 15. Open decisions — none of them blocks building

Every one has a default written into the config or into this document. They are things Karen or the
Director should overrule on purpose rather than by accident.

**Karen (feel) — the "check this" list for the first shooting playtest (`ROADMAP.md` speed rule 8):**

1. Does the gun fire when you expect? Is `BARREL_DELAY` 0.25 s too slow between the two barrels?
2. Is 2.0 s of reload right with a boar running, given you cannot interrupt it?
3. Do buckshot misses past 100 studs read as "the gun" or as "lag"? (§11's lag paragraph is the honest
   answer; the fix order matters and is written there.)
4. Is the crosshair the right size and colour over grass, sky and the grey plate?
5. Is the gun visible and held the right way round in third person, and is the wood-brown handle
   distinguishable from the boar and the plate?
6. **Should being shot scare the boar?** Default: **no** in this task — it is a behaviour change to a
   merged system and belongs with the `ROADMAP.md` 1.5 reaction. One line in `takeHit` if she wants it
   sooner.
7. Holding MouseButton2 does nothing visible in this task. The camera rotating and the cursor locking
   while it is held is the stock camera, not the weapon (§9).

**Director (scope):**

- **A. The Hud's ammo readout** (§3.4). Default: **in**, because Karen's feel defaults 2 and 4 cannot
  be judged without it and there is no sound or animation in this task. Cutting it is deleting one
  `TextLabel`, one config row and spec item §13.2.6.
- **B. A damage router** instead of `Boar:takeHit` (§6.2). Default: **not now**; revisit when a second
  animal or a second damage source exists. The seam is shaped so a router later means changing
  `BoarBoot`'s connection, not either owner.
- **C. Players are not damageable in v1.** A pellet that hits a player is a miss; the drive-line rule,
  not damage, is the answer to shooting at people (`ROADMAP.md` 1.7). Friendly-fire feedback sooner is
  `Damageable` on a character part plus a listener — and it needs its own owner decision, not a weapon
  change.
- **D. The one-writer CI grep** (§13.5). Default: **not in this task** (tooling freeze); it is the only
  mechanical enforcement of rule 3 the repo could have, so it is worth queueing before release.
- **E. Mobile and gamepad.** Gamepad bindings are in the action table; **mobile touch buttons are not
  built** (§10 source C). Default: PC for v1's playtests.
- **F. Where the Tool comes back from on respawn.** Default: `grant` runs on every `CharacterAdded`
  for a player `shouldArm` accepts, and the state resets to `initial` — a full gun, a full reserve.
  The match loop may want carry-over in 1.7; it changes one call site.
- **G. `AUTO_EQUIP = true`** (§11). Default: the gun is in the hand on spawn rather than in the
  Backpack. If the Director wants the player to equip it deliberately, flip the boolean; the client
  spec's cue path does not depend on it.

---

## 16. What I could not verify (rule 8)

- **Anything requiring Roblox Studio.** No Studio in this session (`.agent-evidence/INDEX.md`). Every
  claim about what the harness *would* do is read from `tools/studio_mcp.py` and
  `tests/client/input_driving.spec.luau`, not observed. Every claim about engine behaviour is from
  documentation and from the code already in this repo.
- **That `Humanoid:EquipTool` from a client spec makes `Tool.Parent == character` visible on the
  server** inside the scenario's 1500 ms cue wait. §13.6 makes confirming it a deliverable and names
  the fallback. `Tool.Parent` was chosen over `Tool.Equipped` on the server precisely because it is
  the unambiguous half of this.
- **That Rojo places `Remotes.model.json` under a folder module as a child of the ModuleScript.** The
  mechanism is the one that already gives `Boar.Brain` and `Boar.Body`, but no `.model.json` exists
  anywhere in this repo (`.agent-evidence/ls-files.txt`), so this is the first. §8 gives the fallback.
- **That `Q` and `X` are free.** I have not run a Play session to confirm no Roblox CoreScript binds
  them. `X` is the design's ammo key and `Q` the test cue; if either collides, change it in the
  binding table and the scenario and report it.
- **The replay's real latency.** The margins in §13.3 (0.4 s into a 2.0 s window; 900 ms against a
  250 ms delay) are reasoned, not measured. Task 6a note (e) says the existing gap assertion already
  assumes latency well under 700 ms; if that is wrong, these are the assertions that will go flaky
  first, and the fix is a longer `wait`, never a looser assertion.
- **The seed in §13.1 item 4.** `Random.new(1337)` is a fixture, not a verified pass; the probability
  that 9,000 buckshot directions all fall inside a quarter cone is negligible under any sane sampler,
  but I could not run it.
- **The external sources' current licence and maintenance status.** No network access this session.
  A–C, E and F are first-party Roblox documentation (creator-docs is CC BY 4.0) and the APIs ship with
  the engine; H is Luau's own documented library; D (Knit, MIT) and G (fractality-spring, MIT) are
  from my own knowledge, and neither is a dependency of anything built here — only D's *pattern* is
  used and G is not used at all. The Builder confirms them in the research-note addendum before
  relying on any of them.
- **The lag figures in §11** are arithmetic from `Boar.CONFIG.SPRINT_SPEED` and `BODY_SIZE`, not
  measurement. The research note says the tolerances "must be measured with two real players, not
  reasoned about", and that has not happened.
- **Whether `CAMERA_ORIGIN_TOLERANCE = 30` is generous or tight** for the stock camera at its default
  zoom. It is a guard against absurdity, not a proof of honesty (§5.7); if a legitimate shot is ever
  rejected `"origin-far"`, that is a harness-visible bug and the number is the dial.
- **Anything about the DEV place's `SignalBehavior`.** Not a repo file. §13.1 polls for signals, which
  is correct under both `Immediate` and `Deferred` — the same conclusion `docs/design/boar-ai.md`
  reached.
