# Design: shotgun

Architect, 2026-09-24. Commit `003dc0a1e0b3e24c07edea8053374e6bc2211fcb`, branch
`task-19-shotgun-design` (`.agent-evidence/head.txt:1-2`). Read-only session; evidence precomputed in
`.agent-evidence/`.

Research note (rule 1): `docs/research/2026-09-24-shotgun.md`. That note is the source of the
ballistics, the ranges and five of the sources below; this file is the **structure**: who owns what,
what the interfaces are, and what the Builder may and may not write. Where I deviate from the note I
say so and why (rule 2).

State of the tree: no game code exists. `src/` holds one file, `src/server/SyncCheck.server.luau`, a
test fixture; the other seven `src/` directories hold only `.gitkeep`
(`.agent-evidence/ls-files.txt:32-39`). Lint, format and build are clean
(`.agent-evidence/lint-selene.txt`, `lint-stylua.txt`, `rojo-build.txt`, all exit 0). **The shotgun
is the first real system in this repo**, so every convention it sets is inherited by the boar, the
hit zones, the HUD and the match loop.

---

## 1. What the system must do

1. A break-action, two-barrel shotgun: fire one barrel at a time, break open, eject, load two shells,
   close. Slug and buckshot selectable (`docs/PROJECT_CONTEXT.md:9-11`, `ROADMAP.md:30`).
2. Decide, on the server, what each shot hit, and publish that as a **hit report**: which model, which
   hit zone, how many pellets, at what distance.
3. Detect a shot fired toward the drive line and publish that as a **safety violation**.
4. Give the shotgun to a player and take it away, on the server's say-so (shooters get one, drivers do
   not — `docs/PROJECT_CONTEXT.md:8-9`).
5. Be server-authoritative enough that a client cannot invent a kill, a shell or a rate of fire.

## 2. What the system must not do

This list is the point of the document. Every line is a failure of the previous project
(`docs/PROJECT_CONTEXT.md:32-38`) written as a prohibition.

| Prohibition | Why | Whose job it is |
|---|---|---|
| Never assign `workspace.CurrentCamera.CFrame`, `.CameraType`, `.FieldOfView` or `.CameraSubject` | "Two systems wrote the creature's position" (`docs/PROJECT_CONTEXT.md:36`) | camera owner, **unassigned** (`GAME_DESIGN.md:24`) |
| Never assign `UserInputService.MouseIconEnabled`, `UserInputService.MouseBehavior` or `Mouse.Icon` | "Three scripts set the mouse cursor" (`docs/PROJECT_CONTEXT.md:33-34`) | cursor owner, **unassigned** (`GAME_DESIGN.md:27`) |
| Never write a `Humanoid.Health`, apply a `BodyMover`, or ragdoll anything | one writer per animal | animal / hit-zone system, `ROADMAP.md:56` |
| Never compute a damage number and never hold a damage table | the zone→reaction mapping is one decision in one place | animal / hit-zone system |
| Never freeze, tie, teleport or score a player | the penalty is not the weapon's | match-state system, `ROADMAP.md:58` |
| Never create a `ScreenGui`, `TextLabel` or crosshair | Task 7 blocks visual client code (`TASKS.md:13`); UI has no owner (`GAME_DESIGN.md:27`) | UI owner, unassigned |
| Never write a typed property value (`Vector3`, `CFrame`, `Color3`) into any `.model.json` or `.meta.json` | the harness fails it as "cannot compare" (`tools/studio_mcp.py:398-399`, `:505-507`); audit-002 must-fix 1 is still open (`TASKS.md:22`) | see §5.4 |
| Never add a Wally package in this task | `wally.lock` / `devpackages.sha256` are checked against the commit (`tools/studio_mcp.py:55-56`); the one package this system would want is deferred with ADS (§3.3) | — |
| Never let a client name what it hit | see §7.3 | — |

A predicate in this system answers **one** question. `WeaponStateMachine` says whether a barrel may
fire; it does not say whether the viewmodel is visible. That is the "one predicate answered two
unrelated questions" failure (`docs/PROJECT_CONTEXT.md:34-35`) stated as a rule.

## 3. Ownership

Rule 3 (`CLAUDE.md:22-23`): exactly one writer per system, named here, mirrored into the
`GAME_DESIGN.md` owners table (§12).

### 3.1 The one server owner

**`ServerScriptService.Weapon.WeaponServer`** — disk: `src/server/Weapon/WeaponServer.luau`.

It is the only writer of: every player's authoritative weapon state; every granted `Tool` instance and
its `Handle` properties; the `StateChanged` and `ShotFired` remotes; the `HitReported` and
`SafetyViolated` signals. Nothing else in the repo may fire those remotes or mutate that state.

It is a **ModuleScript**, not a `Script`. The boot script `src/server/WeaponBoot.server.luau` does
one thing: `require(...).start()`. That is the "thin script, fat module" bootstrap (source D) and it
exists for a concrete reason — a `Script` cannot be `require`d, so a `Script` owner could not expose
`HitReported` to the hit-zone system without a second channel, and a server spec could not reach its
pure helpers.

### 3.2 The one client owner

**`Players.LocalPlayer.PlayerScripts.Weapon`** — disk: `src/client/Weapon/`, a Folder of
ModuleScripts, booted by `src/client/WeaponBoot.client.luau`.

Three modules, each the single writer of one thing:

| Module | Sole writer of | Never touches |
|---|---|---|
| `WeaponInput` | the `FireRequest` / `ActionRequest` remotes; the local `aiming` flag | camera, cursor, state replica, any Instance |
| `WeaponReplica` | the client's copy of the weapon state | remotes (it only listens), effects |
| `ShotEffects` | cosmetic Instances under a single runtime `workspace.Effects` folder | state, remotes, camera |

**`WeaponReplica` has no setter.** It subscribes to `StateChanged.OnClientEvent` itself and stores a
`table.freeze`d table. Nothing else *can* write it — that is rule 3 enforced by the engine rather
than by policy. Note the runtime path: specs and other systems must reach it through
`Players.LocalPlayer:WaitForChild("PlayerScripts").Weapon.WeaponReplica`, **not** through
`StarterPlayerScripts`, which is a template (the same mechanism that runs `ClientTestRunner`,
`default.project.json:37-41`).

### 3.3 What this design deliberately does not build yet — and why that is the right cut

`ROADMAP.md:55` describes task 1.4 as "third person, first-person aim". **This design ships the
shotgun on the default Roblox camera, with no ADS and no viewmodel**, and moves both to a later
camera task. Three reasons, in order of weight:

1. **A viewmodel only exists in first person.** It is a character clone parented to
   `workspace.CurrentCamera` (`docs/research/2026-09-24-shotgun.md:96-102`). In third person the
   player sees the `Tool` in the character's hand — which is server-visible, replicated, and needs no
   camera. Building a viewmodel before the camera mode that shows it is building a thing nobody can
   look at, against rule 5 (`CLAUDE.md:25`).
2. **ADS needs a camera writer and there is none** (`GAME_DESIGN.md:24`). If the shotgun writes the
   camera "just for aiming", the camera system inherits a second writer on day one. That is exactly
   the failure this project is designed around.
3. **The aim ray does not need the camera to be ours.** `workspace.CurrentCamera.CFrame.LookVector` is
   a *read*. Reading the camera creates no writer. So the gun aims correctly under the stock camera
   today and under our camera later, with no change to the weapon.

What this task still delivers for the camera task, at no cost: `WeaponInput.AimChanged`
(§6.2) is bound and fired now. The camera module connects to it later and nothing in the weapon
changes. The interface is fixed here so it cannot be re-litigated.

This is blocking open decision 2 (§13): it contradicts a line of the Director's roadmap, so the
Director signs it off or overrides it.

## 4. Files on disk

```
src/shared/Weapon/
  ShotgunConfig.luau          -> ReplicatedStorage.Weapon.ShotgunConfig   (ModuleScript, frozen table)
  WeaponTypes.luau            -> ReplicatedStorage.Weapon.WeaponTypes     (types only)
  Remotes.model.json          -> ReplicatedStorage.Weapon.Remotes         (Folder + 4 RemoteEvents)
src/server/
  WeaponBoot.server.luau      -> ServerScriptService.WeaponBoot           (Script, 3 lines)
  Weapon/
    WeaponServer.luau         -> ServerScriptService.Weapon.WeaponServer  (THE OWNER)
    WeaponStateMachine.luau   -> pure reducer
    ShotValidator.luau        -> pure
    ShotPattern.luau          -> pure
    SafetyArc.luau            -> pure
src/serverstorage/ShotgunTemplate/
  init.meta.json              -> ServerStorage.ShotgunTemplate            (className "Tool")
  Handle.model.json           -> ... .Handle                              (Part, plain properties only)
src/client/
  WeaponBoot.client.luau      -> PlayerScripts.WeaponBoot                 (LocalScript, 3 lines)
  Weapon/
    WeaponInput.luau
    WeaponReplica.luau
    ShotEffects.luau
tests/server/weapon_state.spec.luau
tests/server/weapon_validation.spec.luau
tests/server/weapon_pattern.spec.luau
tests/server/weapon_safety.spec.luau
tests/client/weapon_client.spec.luau
```

Mappings are from `default.project.json:6-52`; the file-type rules from `CLAUDE.md:236-240`. A
directory with no `init.*` becomes a Folder; `src/shared/Weapon/` therefore becomes
`ReplicatedStorage.Weapon`, a sibling of `TestKit`, `ClientTests` and `DevPackages`
(`default.project.json:12-26`) with no name collision — the harness fails same-named siblings
(`tools/studio_mcp.py:490-491`).

### 4.1 The Tool lives in ServerStorage, not StarterPack

`CLAUDE.md:214` documents `src/starterpack/` as the home of a `Tool`. This design puts the template in
`src/serverstorage/` instead (`CLAUDE.md:216`, "server-only templates … never replicated to clients").
Reason: `StarterPack` hands the Tool to **every** player automatically, and in this game only shooters
carry a gun (`docs/PROJECT_CONTEXT.md:8-9`). A ServerStorage template plus
`WeaponServer.grant(player)` gives the match-state system one place to decide who is armed, and keeps
the grant decision out of the engine's hands. `src/starterpack/` stays empty.

## 5. Data on disk, and the typed-value problem

audit-002 must-fix 1 is open: a property whose JSON value is not `str`/`bool`/`int`/`float` fails the
harness as "cannot compare" (`tools/studio_mcp.py:398-399`, `:505-507`), and it is deliberate
behaviour (`CLAUDE.md:246-248`). Task 16 is queued but explicitly not next (`TASKS.md:22`). So:

### 5.1 The rule

**No shotgun file contains a typed property value.** Every `Vector3`, `CFrame` and `Color3` the gun
needs lives in `ShotgunConfig.luau` and is applied at runtime by `WeaponServer` to the *clone* it
grants. Target: the harness reports zero "cannot compare" problems for the shotgun's files (§10).

This is not a workaround grudgingly accepted — it is better evidence. A number in
`ShotgunConfig.luau` is linted, formatted, type-checked and diffable; the same number in a
`.model.json` is none of those.

### 5.2 What is legal on disk today, verified against the harness source

- `className` and `name` in `.model.json`, and `children` recursively (`tools/studio_mcp.py:448-458`).
- Plain string, number and boolean properties and attributes (`:474-476`, `:502-510`).
- **Enum properties written as strings pass.** Studio encodes an `EnumItem` as its `.Name`
  (`tools/studio_mcp.py:115-117`) and the comparison accepts a string match (`:420`). So
  `"Material": "Plastic"` and `"CollisionGroup": "Default"` compare correctly. `Color3` does not.
- Attributes are the hit-zone channel (§6.3) precisely because they *are* compared today.

### 5.3 The template's contents

`src/serverstorage/ShotgunTemplate/init.meta.json`: `{"className": "Tool", "properties":
{"RequiresHandle": true, "CanBeDropped": false, "ToolTip": "Break-action shotgun"}}` — all plain.
`Handle.model.json`: a `Part` with `Material`, `CanCollide: false`, `Massless: true`,
`Transparency: 0`. `Size`, `Color` and `Tool.Grip` are set at runtime from `ShotgunConfig`.

### 5.4 This is the repo's first `init.meta.json`, and audit-002 F2 is untested

audit-002 F2 (`docs/architecture/audit-002.md:183-190`): the harness never compares `className` from a
meta file, and whether Rojo's sourcemap reports the meta-declared class is **not verified — no
`init.meta.json` exists in the repo**. The worst case is a false failure, not a false pass. The
Builder must therefore treat this as a named deliverable: run the harness, and report in
`REVIEW_REQUEST.md` whether `ServerStorage.ShotgunTemplate` compares as `Tool` or as `Folder`. If it
reports `Folder`, that is a harness fault under rule 6 (`CLAUDE.md:26`) and gets reported, not worked
around.

## 6. Public interface

Types live in `src/shared/Weapon/WeaponTypes.luau` and are exported from there; every signature below
uses them.

### 6.1 Shared types

```luau
export type AmmoKind = "Slug" | "Buck"
export type BarrelState = "Empty" | "Live" | "Spent"

export type WeaponState = {
	open: boolean,                 -- action broken open
	barrels: { BarrelState },      -- exactly 2, index 1 and 2
	selected: number,              -- 1 or 2: the barrel the next Fire uses
	ammo: AmmoKind,                -- what a Load puts in
	reserve: number,               -- shells carried
	busyFor: number,               -- seconds of animation/cooldown left at the moment this was sent
}

export type ShotRequest = { origin: Vector3, direction: Vector3 }

export type ZoneTally = { [string]: number }  -- HitZone attribute -> pellets; "" = no zone attribute

export type HitReport = {
	shooter: Player,
	model: Model,          -- the damageable model
	zones: ZoneTally,
	pellets: number,       -- total landing on this model
	nearest: number,       -- studs, muzzle to the closest impact on this model
	position: Vector3,     -- the closest impact point
	normal: Vector3,
	ammo: AmmoKind,
	at: number,            -- os.clock() on the server
}

export type DriveLine = { position: Vector3, normal: Vector3 }  -- normal points from the gun line toward the drivers
export type DriveLineProvider = () -> DriveLine?
```

`busyFor` is a duration, not a server timestamp: `os.clock()` on the server is meaningless on a
client, and shipping one invites someone to compare it with a local clock.

### 6.2 Client

```luau
-- PlayerScripts.Weapon.WeaponReplica
WeaponReplica.get(): WeaponState?          -- frozen; nil until the first StateChanged arrives
WeaponReplica.Changed: RBXScriptSignal     -- (state: WeaponState)

-- PlayerScripts.Weapon.WeaponInput
WeaponInput.start(): ()
WeaponInput.stop(): ()
WeaponInput.isAiming(): boolean
WeaponInput.AimChanged: RBXScriptSignal    -- (aiming: boolean). The camera system's ONLY hook.

-- PlayerScripts.Weapon.ShotEffects
ShotEffects.play(shooter: Player, muzzle: Vector3, impacts: { Vector3 }): ()   -- cosmetic only
```

Signals are `BindableEvent.Event` on a BindableEvent the module creates at runtime — no hand-written
signal class (rule 2: nothing invented where the engine already ships it).

Input actions, bound through `ContextActionService` (source C) with exactly these names, which are
reserved to this system:

| Action name | Default binding | Effect |
|---|---|---|
| `DrivenHunt.Weapon.Fire` | MouseButton1 / ButtonR2 | `FireRequest` with origin + direction |
| `DrivenHunt.Weapon.Aim` | MouseButton2 / ButtonL2 | local flag + `AimChanged` (no camera write, §3.3) |
| `DrivenHunt.Weapon.Break` | R / ButtonX | `ActionRequest("Break")` |
| `DrivenHunt.Weapon.Reload` | R held, or automatic after Break | `ActionRequest("Load")` ×2 then `("Close")` |
| `DrivenHunt.Weapon.SelectAmmo` | X / DPadLeft | `ActionRequest("SelectAmmo", "Slug"/"Buck")` |

All bound on `Tool.Equipped`, all unbound on `Tool.Unequipped`. The action-name prefix is the
registry: a grep for `DrivenHunt.Weapon.` finds every binding this system owns, and no other system
may use that prefix.

### 6.3 Server

```luau
-- ServerScriptService.Weapon.WeaponServer
WeaponServer.start(): ()                        -- once, from WeaponBoot; asserts it is not started twice
WeaponServer.grant(player: Player): Tool
WeaponServer.revoke(player: Player): ()
WeaponServer.getState(player: Player): WeaponState?      -- a frozen copy, for tests and the match system
WeaponServer.setDriveLineProvider(p: DriveLineProvider?): ()
WeaponServer.HitReported: RBXScriptSignal       -- (report: HitReport)
WeaponServer.SafetyViolated: RBXScriptSignal    -- (player: Player, direction: Vector3)
```

**One `HitReport` per (shot, model).** Nine pellets landing on one boar produce one report with
`pellets = 9` and a `zones` tally, not nine reports. Splitting by zone or by pellet would force the
animal system to re-aggregate, and two systems aggregating the same shot is how you get two answers.

**The weapon publishes; it never damages.** `HitReported` is a signal with zero subscribers today.
The animal/hit-zone system (`ROADMAP.md:56`) connects to it and is the sole writer of animal health.
If a boar dies of a cause the weapon can see, the weapon still does not write it.

**Hit-zone lookup**, in this order, and nowhere else:
1. the raycast result's `Instance`;
2. `instance:FindFirstAncestorWhichIsA("Model")` whose attribute `Damageable == true` → the model;
   no such ancestor → the pellet counts as a miss and produces no report;
3. the hit part's string attribute `HitZone` → the tally key; absent → key `""`.

Attributes, not `CollectionService` tags, because attributes on a `.model.json` part are compared by
the harness today (`tools/studio_mcp.py:474-476`, `:502-510`) and tags are not. A hit zone that the
harness can verify from disk is worth more than one that is prettier.

### 6.4 Pure modules (the testable core)

```luau
WeaponStateMachine.initial(config): WeaponState
WeaponStateMachine.apply(state: WeaponState, action: Action, now: number): (WeaponState, string?)
	-- Action = { kind: "Fire" | "Break" | "Load" | "Close" | "SelectAmmo", ammo: AmmoKind? }
	-- returns a NEW frozen state, plus a rejection reason code when nothing changed

ShotValidator.check(req: ShotRequest, rootPosition: Vector3?, config): (boolean, string?)
	-- reason codes: "not-alive" | "bad-type" | "nan" | "not-unit" | "origin-far"

ShotPattern.directions(ammo: AmmoKind, aim: Vector3, rng: Random, config): { Vector3 }

SafetyArc.isForbidden(origin: Vector3, direction: Vector3, line: DriveLine, halfAngleDeg: number): boolean
```

Every one is a pure function of its arguments: no `game:GetService`, no clock, no `Player`. That is
why `rootPosition` and `now` and `rng` are parameters rather than lookups — it is what makes the whole
core testable today without input, without a camera and without a boar (§11).

`apply` returns an immutable new state. `WeaponServer` holding the result is then the *only*
mutation in the system.

## 7. What it reads from, and writes to, other systems

### 7.1 Reads

| Read | Owner of that thing | Status |
|---|---|---|
| `workspace.CurrentCamera.CFrame` (client, aim direction) | camera | **unassigned** (`GAME_DESIGN.md:24`); the stock Roblox PlayerModule writes it until then. Read-only here, so the later camera owner changes nothing |
| `Character.HumanoidRootPart.Position` (server, origin sanity) | Roblox character replication | engine |
| `Humanoid.Health > 0` (server, alive check) | Roblox / animal system | engine |
| part attribute `HitZone: string` | whoever authors the model (animal system, map) | not built (§13.3) |
| model attribute `Damageable: boolean` | same | not built |
| `DriveLine` via the injected provider | match-state system, `ROADMAP.md:58` | not built; provider is `nil`, so `SafetyArc` never fires |

The injected provider is the mechanism that lets this system be built **before** the drive line
exists, with no placeholder to delete later and no second owner of the drive-line geometry.

### 7.2 Writes

| Write | Sole writer |
|---|---|
| authoritative `WeaponState` per player | `WeaponServer` |
| the granted `Tool` and its `Handle` | `WeaponServer` |
| `Remotes.StateChanged` (to the owning player), `Remotes.ShotFired` (to all) | `WeaponServer` |
| `Remotes.FireRequest`, `Remotes.ActionRequest` | `WeaponInput` |
| the client state replica | `WeaponReplica` |
| cosmetic instances in `workspace.Effects` | `ShotEffects` |
| `HitReported`, `SafetyViolated` | `WeaponServer` |

`workspace.Effects` is created at runtime, during Play only. Workspace is not Rojo-owned
(`CLAUDE.md:203-205`) and the harness compares the Edit-mode DataModel, so runtime cosmetics are
invisible to it and cannot dirty a run. Every effect instance is handed to `Debris:AddItem` with
`CONFIG.EFFECT_LIFETIME`; nothing accumulates.

### 7.3 The client never names a target

The research note's source 5 (`docs/research/2026-09-24-shotgun.md:108-123`) proposes that the server
check "its own raycast … hits what the client says it hit, within tolerance", with a 4-stud tolerance
(`:183`). **I am tightening that: the client sends only `{origin, direction}` and never claims a
hit.** Then there is nothing to reconcile — the server's cast *is* the answer — and the 4-stud
tolerance disappears along with the whole class of "the two casts disagreed" bug. The client's
tracers and impact sparks are drawn from the server's `ShotFired` payload, one round trip later; only
the muzzle flash is instant and local.

Cost, stated honestly: buckshot impact sparks appear ~1 RTT after the bang. At the target ping that is
under 100 ms and below the threshold anyone notices on a shotgun. The alternative — a shared RNG seed
so both sides draw the same pattern instantly — needs the server to hand the client a seed, which
hands the client the pattern in advance. Rejected for v1; recorded here so it is not re-invented.

What remains unfixable and is accepted for v1, from the note (`:121-123`): the direction is unknowable
to the server, so an aimbot passes every check. Nobody should later believe this validation is
stronger than that.

## 8. External sources

Sources 1–9 of `docs/research/2026-09-24-shotgun.md:42-166` are inherited whole and not restated:
Roblox raycasting, `Blockcast`/`Spherecast`, FastCast2 (rejected, MIT/ART, maintained fork of a dead
original), the viewmodel write-up, camera non-replication, Roblox units, two ballistics articles, and
ACS (rejected, licence unconfirmable). The design-level sources below are additional, and are what the
*structure* rests on (rule 2: this is where I borrow).

### A. Roblox raycasting — `WorldRoot:Raycast`, `RaycastParams`
<https://create.roblox.com/docs/workspace/raycasting> · first-party creator-docs (CC BY 4.0), engine
API · actively maintained.
**Good:** the whole hit primitive. `RaycastParams.FilterType`/`FilterDescendantsInstances` is how the
shooter's own character is excluded; `RaycastResult.Instance` is exactly the handle the `HitZone`
attribute lookup needs (§6.3); ray length is the direction's magnitude, so slug and buckshot ranges
are expressed as vector lengths from `ShotgunConfig` with no extra distance check.
**Bad:** the 15,000-stud cap is a silent hard edge (far beyond our 330); it says nothing about who
should cast, which is the security question source B answers; and a ray is infinitely thin, so a
server cast at server-time positions will miss a target the client saw — see §10's lag row.
**Adopted:** hitscan, server-side, one ray per projectile. Slug = 1 ray, buckshot = 9
(`ShotPattern`).

### B. Roblox remote events and client/server trust
<https://create.roblox.com/docs/scripting/events/remote-events-and-callbacks> · first-party (CC BY
4.0) · actively maintained.
**Good:** it is the authority for the shape used here — `RemoteEvent:FireClient(player, ...)` to
target one client's state, `FireAllClients` for cosmetics, and the flat statement that client input is
untrusted. It also documents that any client can fire any RemoteEvent with any arguments, which is
why §6.4's validator type-checks every field rather than assuming a `Vector3` arrives.
**Bad:** it supplies no rate limiter, no schema validation and no replay protection; all three are
ours to write. It also does not distinguish "cosmetic broadcast" from "state update", a distinction
this design leans on (`ShotFired` vs `StateChanged`).
**Adopted:** two client→server remotes, both rate-limited at one place in `WeaponServer`; two
server→client remotes, one targeted (state), one broadcast (effects); every inbound field
type-checked before use.

### C. `ContextActionService` and `Tool`
<https://create.roblox.com/docs/reference/engine/classes/ContextActionService> ·
<https://create.roblox.com/docs/reference/engine/classes/Tool> · first-party · actively maintained.
**Good:** `BindAction` keys every binding to a **name**, with a priority stack and an explicit
`Enum.ContextActionResult.Sink`/`Pass` result. That is a per-action owner rather than a global input
router, which is the structural answer to "three scripts set the cursor". `Tool` gives
`Equipped`/`Unequipped`, automatic Backpack handling and a replicated model in the character's hand —
the last of which is why §3.3 can defer the viewmodel.
**Bad:** `Tool.Activated` carries no payload, so it cannot be the fire path (the server would learn
that a shot happened but not where it pointed) — hence a remote instead; and CAS bindings are
per-client, so nothing about them is authoritative. Mobile needs `CreateTouchButton` handling this
design does not cover.
**Adopted:** a `Tool` for equip/unequip and the in-hand model; CAS for every key, with the reserved
`DrivenHunt.Weapon.*` names; a RemoteEvent, not `Tool.Activated`, as the fire path.

### D. "Thin script, fat module" bootstrap — as popularised by Knit
<https://github.com/Sleitnick/Knit> · MIT (`LICENSE.md` in the repo).
Maintenance: widely used, single maintainer, and the author has publicly stepped back from active
development — **the Builder should confirm its current status before ever depending on the code.
Nothing here depends on the answer, because only the pattern is taken, not the package.**
**Good:** one `Script` per side whose only job is to `require` and start modules; all logic in
ModuleScripts, so it is requirable by tests and by other systems, and the start order is explicit
rather than emergent from Roblox's undefined script ordering (a hazard the repo already works around
by hand at `tests/server/sync.spec.luau:27-32`).
**Bad:** Knit itself brings a service/controller registry, networking and a lifecycle this project
does not need and which would own things this design owns; adopting the framework would repeat the
ACS mistake at smaller scale.
**Adopted:** the bootstrap shape only (`WeaponBoot.server.luau`, `WeaponBoot.client.luau`, ~3 lines
each). No dependency added.

### E. Roblox attributes
<https://create.roblox.com/docs/studio/properties#instance-attributes> · first-party · actively
maintained.
**Good:** typed per-instance data, settable from a Rojo `.model.json` `attributes` block, readable at
runtime by `GetAttribute`, and — decisively for us — **compared by the existing harness**
(`tools/studio_mcp.py:474-476`, `:502-510`) as long as the value is a plain string/number/bool. A
`HitZone = "Head"` attribute is therefore verifiable from disk today; a `CollectionService` tag is
not.
**Bad:** attribute names are strings with no schema, so a typo silently yields `nil` — mitigated by
the `zones` tally keying unknown parts to `""` rather than guessing; and attribute values share the
harness's typed-value limitation, so a `Vector3` attribute would fail (§5.1).
**Adopted:** `HitZone: string` on parts, `Damageable: boolean` on models, as the weapon↔animal
contract.

### F. EgoMoose `rbx-fractality-spring` — **deferred, not adopted in this task**
<https://github.com/EgoMoose/rbx-fractality-spring> · MIT · not archived; a typed rewrite of
Fraktality's `spr`; Wally `egomoose/fractality-spring`.
**Good:** small, typed, MIT, and the correct answer for the ADS and recoil springs
(`docs/research/2026-09-24-shotgun.md:93-102`).
**Bad:** single maintainer, small surface area; and adding it now would be the repo's second Wally
package for code that §3.3 defers, touching `wally.lock` and `devpackages.sha256` for no gameplay.
**Decision:** named here as the camera/ADS task's dependency so that task does not re-research it.
Not added now.

## 9. Numeric targets

Ballistics and timings are the research note's (`docs/research/2026-09-24-shotgun.md:167-187`), at
1 stud = 0.28 m. Budgets, limits and tolerances are this design's. All of them live in one frozen
table, `ShotgunConfig.luau`, and nowhere else.

| Quantity | Value | Where from |
|---|---|---|
| Slug range | 330 studs | note, 100 yd MPR |
| Buckshot range | 100 studs | note, 30 yd MPR |
| Pellets | 9 | note, 00 buck |
| Buckshot cone | 1.6° full angle (~2.8-stud circle at 100 studs) | note |
| Slug cone | 0.16° half-angle → implemented as an exact ray | note |
| Slug cast radius | **0** (pure raycast) | this design; the `Spherecast` forgiveness option (source 2 of the note) is named as the agreed dial if Karen reports misses, and is not built now |
| Barrel-to-barrel delay | 0.25 s | note, feel number |
| Reload (break → 2 shells → close) | 2.0 s total | note, feel number |
| Shells carried | 24 | this design; ~12 reloads in a 10-minute drive |
| Origin tolerance | 8 studs from `HumanoidRootPart` | note |
| Direction unit tolerance | \|dir\|−1 ≤ 1e-3 | this design |
| Server raycasts per shot | ≤ 9 | 9 pellets; ~40 casts/s with 8 shooters firing every 2 s |
| Server time per shot | ≤ 0.5 ms | this design |
| `FireRequest` accepted per player | ≤ 6 /s; excess dropped and counted | this design; 0.25 s barrel delay + 2 s reload gives a true max near 4 /s |
| `ActionRequest` accepted per player | ≤ 10 /s | this design |
| `StateChanged` sent | one per accepted transition; ≤ 20 /s per player | this design |
| Effect lifetime | 1.5 s, all via `Debris:AddItem` | this design |
| Typed-value harness problems | **0** | §5.1 |
| Frame budget, client | ≤ 0.2 ms/frame at 60 fps (effects only; no per-frame viewmodel in this task) | this design |

**Lag, stated as a number because it will be felt.** There is no lag compensation in v1 — state
rewind is a system of its own. At 100 ms RTT, a boar running at the note's 38 studs/s is ~3.8 studs
from where the shooter saw it. The boar is 5.5 studs long (note `:179`), so that is most of a body
length: shots that looked good will miss. This is the single most likely thing Karen reports as
"the gun feels wrong", and the mitigation order is (1) the slug spherecast dial above, (2) lag
compensation as its own designed system — never a fudge inside the weapon.

## 10. Code conventions this system sets

- Every module header carries the pattern name, the source link and
  `docs/research/2026-09-24-shotgun.md` (rule 9, `CLAUDE.md:29`), in the style already used at
  `src/server/SyncCheck.server.luau:1-3` and `tests/server/sync.spec.luau:1-4`.
- `--!strict` at the top of every new `.luau` file. luau-lsp is pinned but not in CI (`TASKS.md:9`),
  so this buys nothing automatically today and everything the day Task 3 lands.
- StyLua: tabs, 120 columns (`stylua.toml:3-5`). selene: `std = "roblox"`, and **no TestEZ global may
  appear in `src/`** (`selene.toml:4`, Task 10).
- `ShotgunConfig` is `table.freeze`d and returned; no module mutates it.
- No magic number outside `ShotgunConfig`.

## 11. How it is tested

### 11.1 What is testable today, without Task 6 or Task 7

Everything in §6.4, because every one of those functions is pure. Four server specs:

- **`tests/server/weapon_state.spec.luau`** — the reducer. Closed with two live shells: `Fire` leaves
  barrel 1 `Spent`, `selected` = 2; `Fire` on a `Spent` barrel is rejected with a reason and returns
  an unchanged state; `Fire` while `open` is rejected; `Fire` inside the 0.25 s barrel delay is
  rejected; `Break` → `Load` → `Load` → `Close` returns two `Live` barrels and decrements `reserve`
  by 2; `Load` with `reserve == 0` is rejected; `SelectAmmo` is accepted only while `open`; the
  returned state is frozen and the input state is unmodified.
- **`tests/server/weapon_validation.spec.luau`** — `ShotValidator.check` on fabricated requests: a
  non-`Vector3` origin → `"bad-type"`; `0/0` components → `"nan"`; a direction of magnitude 2 →
  `"not-unit"`; an origin 20 studs from the root → `"origin-far"`; an origin 5 studs away → accepted;
  `rootPosition == nil` → `"not-alive"`.
- **`tests/server/weapon_pattern.spec.luau`** — `ShotPattern.directions`: 9 directions for `"Buck"`,
  1 for `"Slug"`; every direction is unit to 1e-6; every direction is within the configured
  half-angle of the aim; `Random.new(42)` twice gives identical lists (determinism), and
  `Random.new(43)` gives a different one.
- **`tests/server/weapon_safety.spec.luau`** — `SafetyArc.isForbidden`: true straight down the drive
  line's normal; false at 90°; exactly at the boundary angle behaves as documented (pick one and
  assert it); a `nil` provider means it is never called.

One client spec, asserting **state only** (which is what `tools/studio_mcp.py:68-72` says client specs
can do today, and what `tests/client/client_env.spec.luau:21-29` already demonstrates):

- **`tests/client/weapon_client.spec.luau`** — `ReplicatedStorage.Weapon.Remotes` exists with the four
  RemoteEvents and the right ClassNames; `ShotgunConfig` is frozen (writing to it errors);
  `WeaponReplica.get()` is `nil` or a frozen table with exactly the `WeaponState` fields, and a write
  to it errors; `WeaponInput.AimChanged` is an `RBXScriptSignal`; `WeaponInput.isAiming()` is a
  boolean. It must reach the modules through `Players.LocalPlayer.PlayerScripts.Weapon` (§3.2).

Every one of these runs under the existing harness with no change to it.

### 11.2 The one-writer guard

Specs cannot prove a *negative* ("this module never writes the camera"). A grep can. Add one CI step
to `.github/workflows/ci.yml` that fails if `CurrentCamera`, `CameraType`, `FieldOfView`, `MouseIcon`,
`MouseBehavior` or `MouseIconEnabled` is **assigned** anywhere under `src/client/Weapon/`, and if
`Humanoid` or `Health` is assigned anywhere under `src/server/Weapon/`. Reading
`workspace.CurrentCamera.CFrame` must still pass, so the pattern matches assignment, not mention.

Six lines of `grep`, and it is the only mechanical enforcement of rule 3 this repo has. It brushes
`ROADMAP.md:10` (tooling frozen after Task 11) — §13.4 puts that to the Director, with "build it" as
the default and "the Reviewer checks it by eye" as the fallback.

### 11.3 What is blocked, and the smallest unblock for each

The research note (`:227-242`) asks the Architect to name the smallest unblock. These are they —
*smallest*, not general; the general version is the wrong thing to build under a blocking dependency.

**Task 6 — drive real input.** Not a scenario language. The smallest thing that proves the channel:
one committed file `tests/input-scenarios.json` holding a single entry (`{"name":"probe","steps":
[{"key":"R","action":"press"}]}`); one harness step that, after Play starts and before it reads the
client `TestReport`, replays that entry through StudioMCP's existing `user_keyboard_input`; and one
client spec that connects to `UserInputService.InputBegan`, records what it saw, and asserts `R`
arrived. That reuses the report channel, the gate and the token exactly as they are
(`tools/studio_mcp.py:61-64`) and adds one step. **Prove the channel with one key before anything is
built on it.** Only then does the shotgun's input layer get real specs.

**Task 7 — play-time screenshots.** `screen_capture` is Edit-mode only, so there is no tool path and I
will not pretend otherwise: for anything the player sees, the rule-5 evidence is **Karen's
screenshot**, recorded in `PLAYTEST.md` against the code commit. That is policy, and it is the
Director's to set.

What *can* be automated is the class of bug that the previous project's visibility audit missed — "a
visibility audit ignored parent visibility and certified a blank screen twice"
(`docs/PROJECT_CONTEXT.md:30-31`). The smallest version, as a client spec: after the Tool is equipped,
assert the Handle exists, that **every ancestor up to the DataModel** is present and not `Transparency
== 1` where the property exists, that no ancestor `Model`/`Folder` was destroyed, and that the Handle's
pivot is within N studs of the character's root. It does not replace the screenshot. It makes the
specific lie the old audit told impossible to repeat.

### 11.4 Harness facts the Builder must report, not assume

- Whether `init.meta.json`'s `className` is reported by the sourcemap (§5.4, audit-002 F2).
- The harness's "no script outside Rojo-managed paths" scan covers `LuaSourceContainer` only
  (`tools/studio_mcp.py:57-58`, audit-002 must-fix 2), so a Studio-created **Part** under
  `ServerStorage.ShotgunTemplate` would pass a green run and be deleted at the next Connect. Nothing
  in this system may be built by hand in Studio. There is no check standing behind that sentence yet;
  it is policy until Task 15.

## 12. Rows to add to `GAME_DESIGN.md`

Rule 3 requires the owners table to mirror this file (`CLAUDE.md:22-23`, `GAME_DESIGN.md:15-16`). The
Builder adds exactly these, and fills none of the still-`_unassigned_` rows at `GAME_DESIGN.md:24-27`:

| System | Owner (the only writer) | Location | Research note |
|---|---|---|---|
| Weapon state, firing, hit detection, safety-arc check | `ServerScriptService.Weapon.WeaponServer` | `src/server/Weapon/WeaponServer.luau` | [shotgun](docs/research/2026-09-24-shotgun.md) |
| Weapon input (actions `DrivenHunt.Weapon.*`) and the aim flag | `PlayerScripts.Weapon.WeaponInput` | `src/client/Weapon/WeaponInput.luau` | same |
| Client copy of weapon state | `PlayerScripts.Weapon.WeaponReplica` | `src/client/Weapon/WeaponReplica.luau` | same |
| Shot cosmetics (`workspace.Effects`) | `PlayerScripts.Weapon.ShotEffects` | `src/client/Weapon/ShotEffects.luau` | same |
| Shotgun numbers | `ReplicatedStorage.Weapon.ShotgunConfig` (frozen; no writer) | `src/shared/Weapon/ShotgunConfig.luau` | same |

`TASKS.md` also needs the shotgun build task itself: this branch's task (19) is not in the table,
which stops at 16 (`TASKS.md:5-22`). That is the Director's file.

## 13. Open decisions

### Blocking (these are the ARCH_RESULT list)

**13.1 Task 6 — Director, scope.** `TASKS.md:12` marks Task 6 **BLOCKING before any input-driven
client code**. Every trigger in this system is client input. §6.4 and §11.1 are deliberately
structured so the entire authoritative core is buildable and fully specced *today* — but
`WeaponInput` is not, and without it there is no playable gun. Either Task 6 lands first (§11.3), or
the Director waives it in writing for these three actions on the record that the input layer is thin
and the core is covered. An Architect cannot waive a Director's blocker.

**13.2 ADS and the viewmodel — Director, scope.** §3.3 splits them out, against the wording of
`ROADMAP.md:55`. If the Director wants them in this task, `tools/architect.sh design camera` must run
first, because the camera has no owner (`GAME_DESIGN.md:24`) and the shotgun must not become one.

**13.3 The damage entry point — Director, scope.** `docs/research/2026-09-24-shotgun.md:7` and `:179`
cite `docs/research/2026-09-24-boar-ai.md` and "Task 18 `CONFIG.BODY_SIZE`". Neither exists on this
branch (`.agent-evidence/ls-files.txt:27-29`; `TASKS.md` stops at 16), and `docs/design/` holds only
its README. So boar work exists somewhere I cannot read. §6.3 says the weapon publishes and never
damages, which composes with most designs — but if the boar branch already has the weapon writing
health, this design creates the second writer it exists to prevent, and I cannot tell. Land the boar
design where the Architect can see it, or state which system owns the damage entry point. (This is
audit-002 must-fix 4, `docs/architecture/audit-002.md:105-132`, biting a second time.)

### Non-blocking — Karen (feel), with defaults so nothing waits

Per `ROADMAP.md:20`, shooting is feel-critical and waits for Karen's OK before merging. Defaults:

1. **Spread:** realistic — 1.6° full cone, pellets genuinely miss past 100 studs. Alternative: a
   generous cone. One number in `ShotgunConfig`.
2. **Reload:** 2.0 s for break + 2 shells + close, as one uninterruptible action. Alternative: per-shell
   loading that can be cut short.
3. **Ammo swap:** allowed only while the action is broken open.
4. **Barrel select:** automatic (next live barrel). Alternative: a manual selector key.
5. **No crosshair and no ammo HUD in this task** — both are UI, which has no owner
   (`GAME_DESIGN.md:27`) and is blocked by Task 7 (`TASKS.md:13`). Karen will want an ammo readout the
   first time she plays it; it belongs to the UI task, not here.
6. **Karen: check this** — does the gun fire when you expect; does 2 s of reload feel right with a
   boar running; do buckshot misses at range read as "the gun" or as "lag" (§9); is the Tool visible
   and held correctly in third person (rule 5 screenshot, §11.3).

### Non-blocking — Director

**13.4 The one-writer CI guard (§11.2)** is six lines of `grep` in `.github/workflows/ci.yml`, which
`ROADMAP.md:10` could read as frozen tooling. Default: build it — it is the only mechanical
enforcement of rule 3 in the repo, and it guards the exact failure that killed the previous project.
Fallback if the Director rules it frozen: the Reviewer checks the prohibitions in §2 by eye, every
round.

## 14. What I could not verify (rule 8)

- **Anything requiring Roblox Studio.** No Studio in this session (`.agent-evidence/INDEX.md:14`).
  Every claim about what the harness *would* do is read from `tools/studio_mcp.py`, not observed.
- **That Rojo accepts the exact `.model.json` / `init.meta.json` shapes in §5.3.** The harness's
  parsing of them is certain from `tools/studio_mcp.py:440-459`; Rojo's own acceptance is from its
  documented format, and **no `init.meta.json` exists in this repo to compare against** (audit-002 F2,
  `docs/architecture/audit-002.md:183-190`). §5.4 makes confirming it a deliverable.
- **The boar design, the boar research note and any code on other branches.** Not in this worktree and
  I have no git tool. §13.3.
- **Source D's current maintenance status.** I take only the pattern, so nothing depends on it, but I
  have not re-checked the repository in this session and have said so rather than assert it.
- **Whether `Tool.Activated` behaves as described under a locked-centre mouse.** §6.2 does not use
  `Tool.Activated` as the fire path, so the design does not rest on it; the claim in source C's
  "Bad" that it carries no payload is from the API surface, not from a live test.
- **The lag figures in §9** are arithmetic from the note's boar speed, not measurement. The note says
  the tolerances "must be measured with two real players, not reasoned about"
  (`docs/research/2026-09-24-shotgun.md:183`), and that has not happened.
