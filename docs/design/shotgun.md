# Design: shotgun (v2, regenerated)

Architect, 2026-09-25, for Task 23. Commit `6ffe5f5114ba97c1f7707ea4cc329e1c184a5ca3`
(`.agent-evidence/head.txt`), branch `task-23-shotgun-design-v2`. Read-only session: Read, Grep, Glob,
no Studio, no network. Evidence precomputed in `.agent-evidence/` (`INDEX.md`).

**This file supersedes the 2026-09-24 design of the same name.** That version is in git history; it is
superseded, not deleted (rule 7). It was never built from — the Director ruled it not buildable until
regenerated with the boar on `main` (`TASKS.md` row 19). Its four scope questions are answered in
`reviews/task-23/BRIEF.md` and are not re-opened here. §2 lists the defects in it that this file
corrects.

Inputs, in precedence order: `reviews/task-23/BRIEF.md` (the Director's and Karen's decisions), the
code now on `main` (`src/server/Boar/`, `src/server/TestArena.luau`), `docs/design/boar-ai.md`,
`docs/research/2026-09-24-shotgun.md` (rule 1; the ballistics and sources 1–9 come from there and are
not re-derived), `CLAUDE.md`, `docs/PROJECT_CONTEXT.md`.

**Test of this document:** a Builder can build the weapon from it without asking a question. Every
number is here, every owner is named, and every interface is written out.

---

## 1. What the system must do, and must not do

### 1.1 Must do

1. A break-action, two-barrel shotgun: fire one barrel at a time, reload as one 2.0 s action, select
   slug or buckshot (`docs/PROJECT_CONTEXT.md`, "The game"; `ROADMAP.md` step 1.4).
2. Decide **on the server** what each shot hit, and publish it as a **hit report**: which instance,
   which hit zone, how many pellets, how far.
3. Hand that report to the thing that was hit through **one seam**, `Runtime:takeHit` on the target's
   own owner (§6). The weapon never writes the target's state.
4. Give a shotgun to a player and take it away on the server's say-so, through **one policy function**
   (`CONFIG.shouldArm`), so Milestone 1.7 can make it shooters-only by changing that function's body.
5. Draw a crosshair and a barrel/ammo readout, from **one** UI owner (§3.4). Karen wants a crosshair
   (brief item 3).
6. Check whether a shot was fired toward the drive line and publish that as a **safety violation** —
   define the hook, never the punishment (`ROADMAP.md` 1.7).
7. Be server-authoritative enough that a client cannot invent a kill, a shell or a rate of fire.
8. Ship on the **default Roblox camera: no ADS, no viewmodel** (brief decision 1), and leave exactly
   one named seam for the camera task that follows it (brief decision 2, §9).

### 1.2 Must not

Every row is a named cause of death of the previous project, written as a prohibition. Quotes are from
`docs/PROJECT_CONTEXT.md`, section "Why the rules exist - the previous project" (cited by section and
quote, not by line: `CLAUDE.md`, the loop, step 4).

| Prohibition | Why | Whose job it is instead |
|---|---|---|
| Never assign `workspace.CurrentCamera.CFrame`, `.CameraType`, `.FieldOfView`, `.CameraSubject` | "Two systems wrote the creature's position" | the camera owner, **unassigned** (`GAME_DESIGN.md`, Camera row). Reading the camera is allowed (§7) |
| Never assign `UserInputService.MouseIconEnabled`, `UserInputService.MouseBehavior` or `Mouse.Icon` | "Three scripts set the mouse cursor" | the camera/ADS task, which is the first system that needs a locked centre |
| Never write anything under `Workspace.Boars`, never set a boar's `Health`, velocity, `CFrame` or attributes | `Boar.Body` is "the only writer of a boar's Instances" (`src/server/Boar/Body.luau` header; `docs/design/boar-ai.md` §3) | `ServerScriptService.Boar` |
| Never hold a damage number or a zone→reaction table | one decision in one place; the zone→reaction mapping is Milestone 1.5 (`ROADMAP.md` 1.5) | the hit-zone system, when it exists |
| Never freeze, tie, teleport, score or team a player | the penalty is not the weapon's | match state, `ROADMAP.md` 1.7 |
| Never create a `ScreenGui`, `Frame` or `TextLabel` outside `PlayerScripts.Hud` | "One predicate answered two unrelated questions, so mounting hid both the crosshair and the weapon" | `PlayerScripts.Hud` (§3.4) |
| Never write a typed property value (`Vector3`, `CFrame`, `Color3`) into a `.model.json` or `.meta.json` | the harness fails it as "cannot compare" (`tools/studio_mcp.py`, `compare_synced`, the `is_plain` branch); audit-002 must-fix 1 is open (`TASKS.md` row 16) | §8: everything positioned is built in code |
| Never add a Wally package in this task | `wally.lock` and `devpackages.sha256` are pinned against the commit (`tools/studio_mcp.py` docstring, check 4); the one package worth having is the ADS spring, deferred with ADS (§10 source G) | — |
| Never let a client name what it hit, and never cast on the client | §5.6 | — |

**A predicate answers one question.** `StateMachine.apply` says whether a barrel may fire. It does not
say whether the crosshair is visible, whether the Tool is equipped, or whether the camera is in aim.
That is the previous project's "one predicate answered two unrelated questions" written as a rule.

---

## 2. Defects in the Task 19 documents, corrected here

The brief (item 4) requires these named and fixed. The Builder never edits Architect files
(`CLAUDE.md`, Roles), so they survived until this regeneration.

1. **The cone-unit contradiction.** The old §9 gave the slug cone as a **half-angle** in a row beside
   the buckshot **full angle**, and old §11.1 asserted against a half-angle. A config built from that
   table was out by 2× either way. **Fixed by a naming rule, not by a note:** every angle in
   `Shotgun.CONFIG` carries its unit *and* its convention in the field name — `SPREAD_FULL_DEG`,
   `SAFETY_ARC_HALF_DEG` — and each is converted exactly once, at one named call site (§4).
2. **The old `ARCH_RESULT` item 1 pointed at §11.1 where it meant §11.3.** Recorded; that file is
   superseded by `reviews/task-23/ARCH_RESULT.md`.
3. **Three of the old design's four `docs/PROJECT_CONTEXT.md` citations were two lines off.** The
   Builder's table in `docs/research/2026-09-24-shotgun.md` (addendum, review round 1) is correct: at
   this commit the cursor quote is at :32, the predicate quote at :32-33, the creature-position quote
   at :34 and the visibility-audit quote at :30-31. I read the file this session and confirm it. The
   fix is structural: **this design cites no line numbers at all** — file plus symbol, or file plus
   section heading (`CLAUDE.md`, the loop, step 4).
4. **A fourth defect, found while regenerating, and it is a game bug, not a citation.** The old design
   cast the shot ray from the client's `origin` (the camera position) and validated that origin as
   "within 8 studs of `HumanoidRootPart`". Under the default third-person camera — which brief
   decision 1 now makes the shipping camera — the camera sits roughly 12–16 studs behind and above the
   character, so **every honest shot would have been rejected**, and any that passed would have
   started its ray behind the player's back. §5.4 replaces it with the two-stage cast that third
   person needs (camera ray for the aim point, muzzle ray for the pellets) and a tolerance sized for a
   camera rather than a muzzle.

---

## 3. Ownership

Rule 3 (`CLAUDE.md`, Rules): exactly one writer per system, named here, mirrored into
`GAME_DESIGN.md` (§13). The structure deliberately mirrors the boar system, which is on `main`, works,
and has run green (`TASKS.md` row 18: `PASS: 24/24`): a folder module `init.luau` that owns state, a
pure decision module, and one module that is the only writer of Instances. Borrowing the repo's own
proven shape is rule 2 applied inside the project.

### 3.1 The one server owner

**`ServerScriptService.Weapon`** — disk `src/server/Weapon/init.luau`.

Sole writer of: every player's authoritative `WeaponState`; every granted `Tool` and its parts; the
four RemoteEvents; the `HitReported` and `SafetyViolated` signals; the per-player rate-limit counters.
Nothing else in the repo may fire those remotes or mutate that state.

It is a **ModuleScript** (a folder with `init.luau`, exactly as `src/server/Boar/init.luau`), started
by the three-line `src/server/WeaponBoot.server.luau`. A `Script` cannot be `require`d, so a `Script`
owner could not expose `HitReported` to `BoarBoot` (§6) and no spec could reach its pure helpers.
**Nothing happens on `require`** — only `WeaponBoot` starts production, which is the rule
`src/server/Boar/init.luau` states in its header and which makes every spec in §12 possible.

Its private modules, each the sole writer or owner of one thing:

| Module | Is | Never |
|---|---|---|
| `StateMachine.luau` | pure reducer: `(state, action, now) -> (state, reason?)` | touches Instances, services, clocks or `Player` |
| `Validator.luau` | pure: is this request physically possible | as above |
| `Pattern.luau` | pure: aim direction + rng → pellet directions | as above |
| `Hits.luau` | pure over an **injected cast function**: impacts → grouped hit reports; and `targetOf`, which reads attributes off real Instances | calls `Workspace:Raycast` itself |
| `SafetyArc.luau` | pure: is this direction inside the forbidden arc | as above |
| `Hardware.luau` | **the only writer of `Tool` Instances**: builds, grips and destroys them | holds state, touches remotes |

### 3.2 The one client owner

**`Players.LocalPlayer.PlayerScripts.Weapon`** — disk `src/client/Weapon/init.luau`, booted by
`src/client/WeaponBoot.client.luau`.

| Module | Sole writer of | Never touches |
|---|---|---|
| `init.luau` | the client's copy of `WeaponState` (the replica) | remotes outbound, Instances, camera, UI |
| `Input.luau` | the `DrivenHunt.Weapon.*` action bindings, the `FireRequest`/`ActionRequest` remotes, the local aim flag | camera, cursor, UI, any Instance |
| `Effects.luau` | cosmetic Instances under a runtime folder `Workspace.WeaponEffects` | state, remotes, camera, UI |

**The replica has no setter.** `init.luau` subscribes to `StateChanged.OnClientEvent` itself and
stores a `table.freeze`d table; `Weapon.get()` returns it. Nothing else *can* write it — rule 3
enforced by the engine rather than by policy. Specs and other systems reach these modules through
`Players.LocalPlayer:WaitForChild("PlayerScripts").Weapon`, **not** through `StarterPlayerScripts`,
which is a template (`default.project.json`, `StarterPlayer.StarterPlayerScripts`).

### 3.3 The one shared, frozen table

**`ReplicatedStorage.Shotgun`** — disk `src/shared/Shotgun/init.luau`, plus
`src/shared/Shotgun/Remotes.model.json` → `ReplicatedStorage.Shotgun.Remotes`.

`Shotgun.CONFIG` is `table.freeze`d and has **no writer**. Every number in §11 lives here and nowhere
else. The three owner modules are named `Weapon` in three different services; the shared table is
named `Shotgun` so that `require` sites read unambiguously.

### 3.4 The UI owner — new, and named here

`GAME_DESIGN.md` has "UI / anything drawn — _unassigned_". Karen wants a crosshair (brief item 3), so
this design **assigns that slot** rather than deferring it. Rule 3 gives the Architect that call.

**`Players.LocalPlayer.PlayerScripts.Hud`** — disk `src/client/Hud/init.luau`.

Sole writer of `PlayerGui.HunterHud` (one `ScreenGui`, created at runtime) and everything in it. In
this task that is the crosshair and one barrel/ammo readout, and nothing else.

**The dependency direction is one-way and it is the point.** The Hud **reads**
`PlayerScripts.Weapon.get()`, `…Weapon.Changed` and `…Weapon.Input.AimChanged`. The weapon has no
reference to the Hud, calls nothing on it, and does not know it exists. So the failure quoted in §1.2 —
one predicate hiding both the crosshair and the weapon — cannot recur: the crosshair has exactly one
writer, and that writer's only input is published state.

**What it costs to name the UI owner now, stated plainly.** It makes this task two systems rather than
one, against `ROADMAP.md` speed rule 5. The alternative costs more: a crosshair drawn from
`Weapon/Effects.luau` makes the weapon the UI owner by accident, and the next task that draws anything
inherits a second writer on day one. The scope is bounded by naming the Hud's *whole* content for this
task (crosshair, readout) in §5.5 and §11.

**Why the readout and not the crosshair alone.** Karen's feel defaults 2 and 4 (2.0 s reload, automatic
barrel select) cannot be judged by a player who cannot see which barrels are live — there is no sound
and no animation in this task. One `TextLabel` in the owner that already exists is the cheapest way to
make those two defaults playtestable. It is one line in §11 to delete if the Director disagrees
(§14, non-blocking).

### 3.5 Files on disk

```
src/shared/Shotgun/
  init.luau                    -> ReplicatedStorage.Shotgun            (CONFIG + types, frozen)
  Remotes.model.json           -> ReplicatedStorage.Shotgun.Remotes    (Folder + 4 RemoteEvents)
src/server/
  WeaponBoot.server.luau       -> ServerScriptService.WeaponBoot       (Script, ~3 lines)
  Weapon/
    init.luau                  -> ServerScriptService.Weapon           (THE SERVER OWNER)
    StateMachine.luau          -> ...Weapon.StateMachine               (pure)
    Validator.luau             -> ...Weapon.Validator                  (pure)
    Pattern.luau               -> ...Weapon.Pattern                    (pure)
    Hits.luau                  -> ...Weapon.Hits                       (pure over an injected cast)
    SafetyArc.luau             -> ...Weapon.SafetyArc                  (pure)
    Hardware.luau              -> ...Weapon.Hardware                   (the only writer of Tool Instances)
src/client/
  WeaponBoot.client.luau       -> PlayerScripts.WeaponBoot             (LocalScript, ~3 lines)
  Weapon/
    init.luau                  -> PlayerScripts.Weapon                 (THE CLIENT OWNER: the replica)
    Input.luau                 -> PlayerScripts.Weapon.Input
    Effects.luau               -> PlayerScripts.Weapon.Effects
  Hud/
    init.luau                  -> PlayerScripts.Hud                    (THE UI OWNER)
tests/server/weapon_state.spec.luau
tests/server/weapon_shot.spec.luau
tests/server/weapon_hits.spec.luau
tests/server/boar_hit.spec.luau
tests/client/weapon_client.spec.luau
```

Mappings are `default.project.json` (`ServerScriptService` → `src/server`, `ReplicatedStorage` →
`src/shared`, `StarterPlayer.StarterPlayerScripts` → `src/client`). A folder with `init.luau` becomes
that ModuleScript with its files as children — proven in this repo by `src/server/Boar/`, whose
`Brain.luau` and `Body.luau` compare green in the harness (`TASKS.md` row 18). `src/starterpack/` and
`src/serverstorage/` stay empty: see §8.

**Two changed files outside this system**, both named deliverables, both in the target's own owner:
`src/server/Boar/Body.luau` (`Body.create` sets two attributes) and `src/server/BoarBoot.server.luau`
(the wiring). §6 gives the exact change and why it is not a second writer.

---

## 4. Angles: one unit, one conversion, named in the field

The rule that makes the Task 19 defect impossible to repeat:

> **Every angle stored in `Shotgun.CONFIG` is in DEGREES, and its field name states whether it is a
> FULL cone or a HALF angle. No other angle is stored anywhere. Each is converted to radians exactly
> once, at the one call site named below.**

| Config field | Unit stored | Value | Converted where, once |
|---|---|---|---|
| `SPREAD_FULL_DEG.Slug` | degrees, **full cone** | `0.16` | `Pattern.directions`: `halfRad = math.rad(full) * 0.5` |
| `SPREAD_FULL_DEG.Buck` | degrees, **full cone** | `1.6` | same line, same function |
| `SAFETY_ARC_HALF_DEG` | degrees, **half angle** | `45` | `SafetyArc.isForbidden`: `math.rad(halfDeg)` |

Both spread numbers are the research note's (`docs/research/2026-09-24-shotgun.md`, "Numeric targets":
slug **0.16° full cone**, buckshot **1.6° full cone**), which is the consistent document. The safety
arc is a different quantity from a spread cone — a forbidden *firing* arc about the drive-line normal —
which is exactly why its name carries `HALF`.

`Pattern.directions` takes the config, not a loose angle, so no caller can pass the wrong convention.
The spec (§12) asserts against the **full** angle: every returned direction is within
`SPREAD_FULL_DEG/2` degrees of the aim, and at least one beyond `SPREAD_FULL_DEG/4`, so a 2× error in
either direction fails.

---

## 5. Public interface

Types live in `src/shared/Shotgun/init.luau` and are exported from there. `luau-lsp` is pinned but not
in CI (`TASKS.md` row 3), so annotations are documentation plus editor checking, not a gate — the same
status `docs/design/boar-ai.md` §4 records.

### 5.1 Shared types

```luau
export type AmmoKind = "Slug" | "Buck"
export type BarrelState = "Empty" | "Live" | "Spent"

export type WeaponState = {
	equipped: boolean,             -- the Tool is held (server truth, not a client guess)
	open: boolean,                 -- the action is broken open
	barrels: { BarrelState },      -- exactly 2, indices 1 and 2
	loaded: { AmmoKind? },         -- what is IN each barrel; nil where the barrel is not Live
	selected: number,              -- 1 or 2: the barrel the next Fire uses
	ammo: AmmoKind,                -- what the NEXT Load inserts
	reserve: number,               -- shells in the pocket (not counting loaded ones)
	busyFor: number,               -- seconds of action left when this snapshot was sent
}

export type ActionKind = "Fire" | "Break" | "Load" | "Close" | "SelectAmmo"
export type Action = { kind: ActionKind, ammo: AmmoKind? }

export type ShotRequest = { origin: Vector3, direction: Vector3 }  -- CAMERA ray, see 5.4

export type ZoneTally = { [string]: number }   -- HitZone attribute -> pellets

export type HitReport = {
	shooter: Player,
	target: Instance,      -- the instance carrying attribute Damageable == true
	zone: string,          -- the DOMINANT zone: most pellets, ties broken by the nearest impact
	zones: ZoneTally,      -- the full tally, for Milestone 1.5
	pellets: number,       -- total landing on this target
	nearest: number,       -- studs, muzzle to the closest impact on this target
	position: Vector3,     -- that closest impact point
	normal: Vector3,
	ammo: AmmoKind,
	at: number,            -- os.clock() on the server
}

export type ShotPayload = {         -- broadcast, cosmetic only
	shooterUserId: number,
	muzzle: Vector3,
	impacts: { Vector3 },
	ammo: AmmoKind,
}

export type DriveLine = { position: Vector3, normal: Vector3 }  -- normal points toward the drivers
export type DriveLineProvider = () -> DriveLine?
export type Impact = { instance: Instance, position: Vector3, normal: Vector3, distance: number }
export type CastFn = (origin: Vector3, direction: Vector3) -> Impact?
```

`busyFor` is a **duration**, never a server timestamp: `os.clock()` on the server is meaningless on a
client, and shipping one invites someone to compare it with a local clock.

### 5.2 Server — `ServerScriptService.Weapon`

```luau
Weapon.start(): ()                                   -- once, from WeaponBoot; asserts it is not started twice
Weapon.grant(player: Player): Tool                   -- builds and gives a Tool; resets that player's state
Weapon.revoke(player: Player): ()
Weapon.getState(player: Player): WeaponState?        -- a frozen copy, for tests and for Milestone 1.7
Weapon.setDriveLineProvider(p: DriveLineProvider?): ()
Weapon.setCast(cast: CastFn?): ()                    -- production casts Workspace; a spec injects its own
Weapon.HitReported: RBXScriptSignal                  -- (report: HitReport)
Weapon.SafetyViolated: RBXScriptSignal               -- (player: Player, direction: Vector3)
Weapon.StateMachine, Weapon.Pattern, Weapon.Validator, Weapon.Hits, Weapon.SafetyArc
	-- exported for specs only, exactly as src/server/Boar/init.luau exports Boar.Brain
```

There is **one** module-level owner, not a `newRuntime(world)` factory like the boar's. Reason, stated
so it is not mistaken for inconsistency: the four RemoteEvents are singletons in `ReplicatedStorage`,
so two runtimes would fight over them. The injectable parts the boar gets from its world —
the cast function and the drive-line provider — are injected individually instead, and everything
worth testing is in the pure modules.

Signals are `BindableEvent.Event` on a BindableEvent the module creates at runtime. Nothing
hand-written (rule 2), and it is the choice `docs/design/boar-ai.md` §8 already made for `Despawned`,
with the same two consequences: payload tables are copied (no metatables, no mixed-key tables), and
under `SignalBehavior = Deferred` a listener does not run inside `Fire`, so a live spec polls.

### 5.3 The pure core

```luau
StateMachine.initial(config): WeaponState
StateMachine.apply(state: WeaponState, action: Action, now: number): (WeaponState, string?)
	-- returns a NEW frozen state; on rejection returns the SAME state plus a reason code:
	-- "busy" | "is-open" | "is-closed" | "barrel-empty" | "no-reserve" | "barrel-full" | "bad-action"

Validator.check(req: ShotRequest, rootPosition: Vector3?, config): (boolean, string?)
	-- "not-alive" | "bad-type" | "nan" | "not-unit" | "origin-far"

Pattern.directions(ammo: AmmoKind, aim: Vector3, rng: Random, config): { Vector3 }
	-- Slug -> 1 direction, Buck -> config.BUCK_PELLETS. Same code path, same cone maths (§4)

Hits.targetOf(instance: Instance): (Instance?, string)
	-- walks `instance` and its ancestors for attribute Damageable == true -> the target root.
	-- zone = instance's HitZone attribute, else the root's, else "unknown". No root -> (nil, "")

Hits.resolve(muzzle: Vector3, directions: { Vector3 }, range: number, cast: CastFn): { Impact }
Hits.group(shooter: Player, impacts: { Impact }, ammo: AmmoKind, now: number): { HitReport }
	-- ONE report per (shot, target). 9 pellets on one boar = one report, pellets = 9

SafetyArc.isForbidden(direction: Vector3, line: DriveLine, halfAngleDeg: number): boolean
```

Every one is a pure function of its arguments: no `game:GetService`, no clock, no `Player` lookup,
no `Workspace`. `now`, `rng` and `cast` are parameters rather than lookups, which is what makes the
whole authoritative core testable **today**, with no input harness, no camera and no boar (§12).
`apply` returns an immutable state; the owner holding the result is the only mutation in the system.

### 5.4 The shot, step by step — and the two-stage cast third person needs

This is the whole server flow for one `FireRequest`. It is written out because §2 defect 4 shows what
happens when it is left implied.

1. **Rate limit.** More than `FIRE_RATE_LIMIT` accepted requests in the last second from this player:
   drop, count, no reply.
2. **Validate** with `Validator.check(req, rootPosition, CONFIG)`. `origin` is the **camera** position
   and `direction` is the camera's unit `LookVector`; the tolerance is `CAMERA_ORIGIN_TOLERANCE`
   studs from `HumanoidRootPart` (§11), because under the stock third-person camera the origin is
   *meant* to be behind the character. Rejection → one `StateChanged` (so the client resyncs) and
   nothing else.
3. **State.** `StateMachine.apply(state, {kind="Fire"}, now)`. Rejected → `StateChanged`, stop. The
   fired barrel's `loaded` kind is the ammo for this shot.
4. **Aim point.** Cast the camera ray: `cast(origin, direction * range)`. Hit → `aimPoint` is the
   impact position; no hit → `aimPoint = origin + direction * range`.
5. **Muzzle.** `muzzle = Handle.CFrame * CONFIG.MUZZLE_OFFSET`, read from the server's own Tool. The
   client never supplies it.
6. **Aim from the muzzle.** `aim = (aimPoint - muzzle).Unit`. If `(aimPoint - muzzle).Magnitude <
   MIN_AIM_DISTANCE` (a target almost touching the barrel), use `direction` instead — guarding the
   degenerate case explicitly rather than letting `.Unit` produce NaN.
7. **Pattern.** `Pattern.directions(ammoKind, aim, rng, CONFIG)`.
8. **Cast the pellets** from `muzzle`, `RaycastParams.FilterType = Exclude`, filter = the shooter's
   character and `Workspace.WeaponEffects`. `Hits.resolve` returns the impacts.
9. **Report.** `Hits.group(...)` → zero or more `HitReport`s; fire `HitReported` once per target.
10. **Safety.** If a drive line is provided, `SafetyArc.isForbidden(direction, line,
    CONFIG.SAFETY_ARC_HALF_DEG)` → fire `SafetyViolated(player, direction)`. Publish only; never
    punish.
11. **Publish.** `StateChanged:FireClient(player, newState)`; `ShotFired:FireAllClients(payload)` with
    muzzle and impact points for cosmetics.

Pellets originate at the muzzle and converge on the point the crosshair is over. That is the standard
third-person shooter geometry and the reason tracers will look right in the screenshot.

### 5.5 Client

```luau
-- PlayerScripts.Weapon (init.luau)
Weapon.start(): ()
Weapon.get(): WeaponState?              -- frozen; nil until the first StateChanged arrives
Weapon.Changed: RBXScriptSignal         -- (state: WeaponState)
Weapon.Input, Weapon.Effects            -- exported for specs

-- PlayerScripts.Weapon.Input
Input.start(): () ; Input.stop(): ()
Input.isAiming(): boolean
Input.AimChanged: RBXScriptSignal       -- (aiming: boolean). THE CAMERA SYSTEM'S ONLY HOOK (§9)

-- PlayerScripts.Weapon.Effects
Effects.play(payload: ShotPayload): ()  -- cosmetic only
Effects.folder(): Folder                -- Workspace.WeaponEffects, created on first use

-- PlayerScripts.Hud
Hud.start(): ()
Hud.gui(): ScreenGui?                   -- PlayerGui.HunterHud, for specs
Hud.isCrosshairVisible(): boolean       -- read-only; there is no setter, by design (§3.4)
```

Input actions, bound through `ContextActionService` with exactly these names. The prefix
`DrivenHunt.Weapon.` is **reserved to this system**: a grep for it finds every binding it owns, and no
other system may use it.

| Action name | Binding | Effect |
|---|---|---|
| `DrivenHunt.Weapon.Fire` | MouseButton1 / ButtonR2 | `FireRequest:FireServer({origin, direction})` from `workspace.CurrentCamera.CFrame` |
| `DrivenHunt.Weapon.Reload` | R / ButtonX | `ActionRequest:FireServer("Reload")` |
| `DrivenHunt.Weapon.SelectAmmo` | X / DPadLeft | `ActionRequest:FireServer("SelectAmmo", "Slug"\|"Buck")` — toggles |
| `DrivenHunt.Weapon.Aim` | MouseButton2 / ButtonL2 | sets the local flag and fires `AimChanged`. **No camera write, nothing visible in this task** (§9) |

All bound on `Tool.Equipped`, all unbound on `Tool.Unequipped`. `Tool.Activated` is not the fire path:
it carries no payload, so the server would learn that a shot happened but not where it pointed
(§10 source C).

**The Hud's whole content in this task**, drawn in code into `PlayerGui.HunterHud`:
- a centred crosshair: four `Frame` arms (`CROSSHAIR_ARM_PX` long, `CROSSHAIR_THICK_PX` thick,
  `CROSSHAIR_GAP_PX` from centre) in a 1×1 container anchored at `(0.5, 0.5)`, with a `UIStroke` so it
  stays visible against sky and grass. Visible **iff** `Weapon.get() ~= nil and state.equipped`.
- one `TextLabel`, bottom-right, `Font = Enum.Font.Code`, ASCII only: the two barrels as `*` (live),
  `x` (spent), `-` (empty), the selected barrel wrapped in `[ ]`, then the next-load ammo and the
  reserve. Example: `[*]x SLUG 22`.
- nothing else. No hit marker, no damage numbers, no menu.

### 5.6 The client never names a target, and never casts

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

This answers brief decision 4. It is the question Task 19 could not answer because the boar was not
visible from that branch.

### 6.1 What the boar actually is, as merged

Not what the old design assumed. `Boar.Body.create` (`src/server/Boar/Body.luau`) builds **one
`Part`** named `Boar1`, `Boar2`… under `Workspace.Boars` — no `Model`, no `Humanoid`, no `Health`, no
attributes. The runtime keeps a private entry list in `src/server/Boar/init.luau` (`Runtime:spawn`),
and the only handle it hands out is `{ id, part, state, position }`. `Workspace.Boars` and everything
in it belongs to `Boar` (`GAME_DESIGN.md`, Boar row; `docs/design/boar-ai.md` §2, §3).

So a design that reports hits against "a `Model` with `Damageable == true`" would report nothing at
all against the boar that exists.

### 6.2 The decision

**The damage entry point is `ServerScriptService.Boar`, and it gains one function:**

```luau
-- ServerScriptService.Boar, on Runtime
export type HitZone = string          -- v1 grey box: "body". Milestone 1.5 adds head/chest/leg
export type Hit = { zone: HitZone, ammo: string, pellets: number, at: number }

Runtime:takeHit(part: BasePart, hit: Hit): boolean
	-- true  = the part is one of MY live boars and the hit was recorded
	-- false = not mine, or already despawned (a late report races a despawn; that is normal)

Runtime.Hit: RBXScriptSignal          -- (record: { id, zone, ammo, pellets, at })
```

**Not a damage router.** A router would be a third system, invented now, with exactly one animal to
route to and no owner of its own — the "invented foundations" failure at small scale
(`docs/PROJECT_CONTEXT.md`). It is the right answer when there are three animals and two weapons;
it is not the right answer today, and this file says so explicitly so the decision is revisited on
purpose rather than by accident (§14).

**Why the boar's own owner and not the weapon.** A hit changes boar state. Rule 3 says boar state has
exactly one writer, and that writer is `Boar`. `takeHit` is the *only* way in, it is on the owner, and
its v1 body is small (§6.4). The weapon never requires `Boar`, and `Boar` never requires the weapon.

### 6.3 How the two are wired, without either depending on the other

The wiring lives in **`src/server/BoarBoot.server.luau`**, which owns nothing and is boot lines only.
That is already this repo's idiom, not a new one: `BoarBoot` is where the boar system's cross-system
knowledge lives today — it requires `TestArena` to assert the arena still matches `Boar.CONFIG.field`,
while `Boar` itself never requires `TestArena` (`docs/design/boar-ai.md` §9, "Boar itself never
requires TestArena"). The composition root knows both systems; neither owner knows the other.

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
its own and a shot into a wall costs one table lookup.

### 6.4 How the weapon finds a target at all: two attributes, written by the target's owner

`Hits.targetOf` walks the hit instance and its ancestors for the attribute **`Damageable == true`**;
that instance is the target root. The zone is the hit instance's **`HitZone`** string attribute, else
the root's, else `"unknown"`. No root → the pellet is a miss and produces no report.

Attributes, not `CollectionService` tags, because attributes on a `.model.json` part are compared by
the harness today (`tools/studio_mcp.py`, `compare_synced`) and tags are not — so a hit zone authored
on disk is verifiable from disk the day models arrive. Today the boar is code-built, so:

**`src/server/Boar/Body.luau`, in `Body.create`, gains two lines:**

```luau
part:SetAttribute("Damageable", true)
part:SetAttribute("HitZone", "body")   -- the grey box is one zone; Milestone 1.5 splits the body
```

This is not a second writer. `Body` is *the* writer of boar Instances (its own header says so), and
these two attributes are boar-owned data that the boar publishes about itself. The weapon only reads
them. When Milestone 1.5 replaces the box with a multi-part body, each part carries its own `HitZone`
and **nothing in the weapon changes** — that is the test of whether this seam is in the right place.

### 6.5 What `takeHit` does in this task, and what it must not do yet

Hit zones and wounded running are Milestone 1.5 (`ROADMAP.md`). So v1 of `takeHit`:

- finds the entry whose `body.part == part`; returns `false` if there is none;
- increments `entry.hits` and `entry.pelletsTaken`, stores `entry.lastHit = hit`;
- adds `hits` and `pelletsTaken` to the `Runtime:stats()` table, so a spec and the Director can see
  shots landing without a screenshot;
- fires `Runtime.Hit` once, with the record;
- returns `true`.

It does **not** change health (there is none), speed, state or lifetime, and it does not despawn. The
boar keeps fleeing. Milestone 1.5 fills this function's body and adds the zone→reaction table; nothing
else in either system moves. The player-visible feedback for a hit in this task is the weapon's own
impact effect on the boar (§5.5), which is the client's cosmetic layer and touches no boar state.

**Should being shot scare the boar?** Not in this task — it is a behaviour change to a merged system
and belongs with the reaction in 1.5. It is listed for Karen in §14.

---

## 7. What it reads, what it writes, and who owns the other end

### 7.1 Reads

| Read | Owner of that thing | Status |
|---|---|---|
| `workspace.CurrentCamera.CFrame` (client, aim ray) | camera | **unassigned** (`GAME_DESIGN.md`); the stock Roblox PlayerModule writes it until the camera task. A read creates no writer, so the later camera owner changes nothing here |
| `Character.HumanoidRootPart.Position` (server, origin sanity) | Roblox character replication | engine |
| `Humanoid.Health > 0` (server, alive check) | Roblox | engine |
| attribute `Damageable: boolean`, attribute `HitZone: string` | the target's own owner — for the boar, `Boar.Body` (§6.4) | delivered by this task |
| `DriveLine` through the injected provider | match state, `ROADMAP.md` 1.7 | not built; the provider is `nil`, so `SafetyArc` never fires |
| `PlayerScripts.Weapon.get()` / `.Changed` / `.Input.AimChanged` (the Hud reads these) | `PlayerScripts.Weapon` | this task |

The injected provider is what lets the safety hook exist before the drive line does, with no
placeholder to delete later and no second owner of the drive-line geometry. It is the same mechanism
`Boar.defaultWorld` uses for threats and paths.

### 7.2 Writes

| Write | Sole writer |
|---|---|
| authoritative `WeaponState` per player | `ServerScriptService.Weapon` |
| every granted `Tool` and its parts | `ServerScriptService.Weapon.Hardware` |
| `StateChanged` (to one client), `ShotFired` (to all) | `ServerScriptService.Weapon` |
| `FireRequest`, `ActionRequest` | `PlayerScripts.Weapon.Input` |
| the client replica | `PlayerScripts.Weapon` (no setter exists) |
| `Workspace.WeaponEffects` and everything in it | `PlayerScripts.Weapon.Effects` |
| `PlayerGui.HunterHud` and everything in it | `PlayerScripts.Hud` |
| `HitReported`, `SafetyViolated` | `ServerScriptService.Weapon` |
| boar hit counters, `Runtime.Hit` | `ServerScriptService.Boar` (§6) |

`Workspace.WeaponEffects` is created at runtime, on the client, during Play only. Workspace is not
Rojo-owned (`CLAUDE.md`, Layout) and the harness compares the Edit-mode DataModel, so runtime
cosmetics are invisible to it and cannot dirty a run. Every effect instance goes to `Debris:AddItem`
with its lifetime from §11; nothing accumulates.

---

## 8. Data on disk

**Everything positioned or coloured is built in code.** No `.rbxm` (banned, `CLAUDE.md`), no typed
property values in JSON (audit-002 must-fix 1 is open, `TASKS.md` row 16: `Vector3`, `CFrame` and
`Color3` fail the harness as "cannot compare"). This is the choice `docs/design/boar-ai.md` §9 made
for the boar body and `src/server/TestArena.luau` made for the arena, and it is the third instance of
the same argument: a number in a frozen Luau config is linted, formatted, type-checked and diffable;
the same number in JSON is none of those and currently fails the run.

So, changed from the Task 19 design: **there is no `src/serverstorage/ShotgunTemplate/`, and no
`init.meta.json`.** `Hardware.build()` creates the `Tool`, its `Handle` and the grip with
`Instance.new`, from `Shotgun.CONFIG`. That also removes this task's dependency on audit-002 F2 (the
harness never compares a meta file's `className`, and no `init.meta.json` exists in the repo to prove
the sourcemap reports it) — an untested harness behaviour is not worth carrying inside the first
weapon.

`StarterPack` stays empty deliberately: it hands a Tool to **every** player automatically, and only
shooters carry a gun (`docs/PROJECT_CONTEXT.md`, "The game"). `Weapon.grant` plus `CONFIG.shouldArm`
puts that decision in one function that Milestone 1.7 rewrites in place.

**The one file on disk that is data:** `src/shared/Shotgun/Remotes.model.json`, a `Folder` with four
`RemoteEvent` children (`FireRequest`, `ActionRequest`, `StateChanged`, `ShotFired`) and no properties
at all. Only `className`, `name` and `children` are used, which the harness compares structurally
(`tools/studio_mcp.py`, `expectations_for`, the `.model.json` branch) and which was verified live in
Task 5 (`TASKS.md` review log, M2: "Verified: valid model.json and meta.json pass"). Remotes on disk
beat remotes created at runtime: the client can `WaitForChild` them deterministically, and the harness
proves all four exist with the right ClassName before anything runs.

Fallback if Rojo or the harness objects to a `.model.json` inside a folder module: move it to
`src/shared/ShotgunRemotes.model.json` → `ReplicatedStorage.ShotgunRemotes`. One path constant
changes; no owner and no interface changes. Report which one was used (rule 6/8).

---

## 9. The seam the camera/ADS task attaches to

Brief decision 2: ADS and third-to-first-person aim are the **next** task, with their own design
(`tools/architect.sh design camera`). This design's job is to leave exactly one attachment point and
to make sure the weapon does not become the camera's owner by accident.

**The seam is `PlayerScripts.Weapon.Input.AimChanged`**, an `RBXScriptSignal` carrying one boolean.
That is all. Fixed here so it cannot be re-litigated:

1. **The weapon owns the `DrivenHunt.Weapon.Aim` action** and publishes the flag. The camera system
   **binds no input of its own for aim** — two systems binding MouseButton2 is the cursor failure with
   a different property name. If the camera task wants a different key, it changes the binding table
   in `Input.luau`; the action name and the signal do not move.
2. **The camera system is the only writer of `workspace.CurrentCamera`** and of
   `UserInputService.MouseBehavior`/`MouseIconEnabled`. The weapon reads `CurrentCamera.CFrame` for
   the aim ray and writes nothing, before or after that task (§1.2).
3. **The Hud keeps the crosshair.** If ADS should hide or change the crosshair, the Hud subscribes to
   the camera system's state and decides — the crosshair still has one writer. The camera system must
   not draw one.
4. **Nothing in the weapon changes when the camera task lands.** The two-stage cast (§5.4) already
   works from an arbitrary camera position, which is exactly what makes a first-person ADS camera a
   no-op for hit detection.
5. The ADS/recoil spring is pre-researched and named for that task (§10 source G) so it is not
   re-researched.

**What Karen sees in this task when she holds MouseButton2: nothing.** Say so in the playtest note;
do not let it be reported as a bug.

---

## 10. External sources

Sources 1–9 of `docs/research/2026-09-24-shotgun.md` are inherited whole and not restated: raycasting,
`Blockcast`/`Spherecast`, FastCast2 (rejected — MIT/ART, maintained fork of a dead original), the
viewmodel write-up, camera non-replication, Roblox units, the two ballistics articles, and ACS
(rejected — licence unconfirmable). The sources below are what the *structure* rests on. Rule 2: this
is where I borrow.

### A. Roblox raycasting — `WorldRoot:Raycast`, `RaycastParams`
<https://create.roblox.com/docs/workspace/raycasting> · first-party creator docs (creator-docs is
CC BY 4.0); the API ships with the engine · actively maintained.
**Good:** the whole hit primitive. `RaycastParams.FilterType`/`FilterDescendantsInstances` excludes
the shooter's own character and the effects folder; `RaycastResult.Instance` is exactly the handle
`Hits.targetOf` needs; ray length is the direction's magnitude, so slug and buckshot ranges are vector
lengths from the config with no extra distance check.
**Bad:** the 15,000-stud cap is a silent hard edge (far beyond our 330); the page says nothing about
*who* should cast, which is the security question source B answers; and a ray is infinitely thin, so a
server cast at server-time positions misses a target the client saw — the lag row in §11.
**Adopted:** hitscan, server-side, one ray per projectile; slug 1, buckshot `BUCK_PELLETS`. Wrapped
behind `CastFn` so the pipeline is pure and testable (`Weapon.setCast`).

### B. Roblox RemoteEvents and client/server trust
<https://create.roblox.com/docs/scripting/events/remote-events-and-callbacks> · first-party (CC BY
4.0) · actively maintained.
**Good:** the authority for the shape used here — `FireClient(player, …)` for one client's state,
`FireAllClients` for cosmetics, and the flat statement that client input is untrusted. It documents
that any client can fire any RemoteEvent with any arguments, which is why `Validator.check`
type-checks every field instead of assuming a `Vector3` arrives.
**Bad:** it supplies no rate limiter, no schema validation and no replay protection — all three are
ours. It does not distinguish "cosmetic broadcast" from "state update", a distinction this design
leans on (`ShotFired` vs `StateChanged`).
**Adopted:** two client→server remotes, both rate-limited in one place in the owner; two
server→client remotes, one targeted, one broadcast; every inbound field type-checked before use.

### C. `ContextActionService` and `Tool`
<https://create.roblox.com/docs/reference/engine/classes/ContextActionService> ·
<https://create.roblox.com/docs/reference/engine/classes/Tool> · first-party · actively maintained.
**Good:** `BindAction` keys every binding to a **name**, with a priority stack and an explicit
`Sink`/`Pass` result — a per-action owner instead of a global input router, which is the structural
answer to "three scripts set the cursor". `Tool` gives `Equipped`/`Unequipped`, Backpack handling and a
replicated model in the character's hand — the last of which is why §1.1 can ship without a viewmodel.
**Bad:** `Tool.Activated` carries no payload, so it cannot be the fire path; CAS bindings are
per-client, so nothing about them is authoritative; mobile needs `CreateTouchButton` handling this
design does not cover (v1 is PC — §14).
**Adopted:** a `Tool` for equip/unequip and the in-hand model; CAS for every key under the reserved
`DrivenHunt.Weapon.*` names; a RemoteEvent, not `Tool.Activated`, as the fire path.

### D. "Thin script, fat module" bootstrap — as popularised by Knit
<https://github.com/Sleitnick/Knit> · MIT (`LICENSE.md` in the repo). Maintenance: widely used, single
maintainer, and the author has publicly stepped back from active development. **Only the pattern is
taken, never the package, so nothing here depends on that status.**
**Good:** one `Script` per side whose only job is to `require` and start modules; all logic in
ModuleScripts, so tests and other systems can reach it, and start order is explicit rather than
emergent from Roblox's undefined script ordering.
**Bad:** Knit itself brings a service/controller registry, networking and a lifecycle this project
does not need and which would own things this design owns — the ACS mistake at smaller scale.
**Adopted:** the bootstrap shape only (`WeaponBoot.server.luau`, `WeaponBoot.client.luau`, ~3 lines
each). No dependency added. This repo already uses it: `src/server/BoarBoot.server.luau` and
`src/server/ArenaBoot.server.luau`.

### E. Roblox attributes
<https://create.roblox.com/docs/studio/properties#instance-attributes> · first-party · actively
maintained.
**Good:** typed per-instance data, settable from a Rojo `.model.json` `attributes` block, readable at
runtime with `GetAttribute`, and — decisively — **compared by the existing harness** when the value is
a plain string/number/bool. So `HitZone = "Head"` is verifiable from disk the day art models arrive; a
`CollectionService` tag is not.
**Bad:** attribute names are strings with no schema, so a typo silently yields `nil` — mitigated by
`Hits.targetOf` returning the explicit `"unknown"` rather than guessing; and attribute values share the
harness's typed-value limit, so a `Vector3` attribute would fail.
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
ancestor is hidden or the `ScreenGui` is disabled — which is precisely the previous project's
"visibility audit ignored parent visibility and certified a blank screen twice"
(`docs/PROJECT_CONTEXT.md`). The client spec therefore walks the whole ancestor chain (§12.2).
**Adopted:** one `ScreenGui` (`HunterHud`, `IgnoreGuiInset = true`, `ResetOnSpawn = false`) built in
code by the single UI owner, with a crosshair of four frames and one text label.

### G. EgoMoose `rbx-fractality-spring` — **named, deliberately not adopted here**
<https://github.com/EgoMoose/rbx-fractality-spring> · MIT · not archived; a typed rewrite of
Fraktality's `spr`; Wally `egomoose/fractality-spring`.
**Good:** small, typed, MIT, and the right answer for the ADS and recoil springs.
**Bad:** single maintainer, small surface; and adding it now touches `wally.lock` and
`devpackages.sha256` for code this task does not ship.
**Decision:** recorded as the camera/ADS task's dependency so that task does not re-research it.

### H. Borrowed from inside this repo (rule 2 applies to internal patterns too)
`docs/design/boar-ai.md` §3–§4 and `src/server/Boar/init.luau`: the folder module that owns state, a
pure decision module tested with 10,000 steps and no physics, Instances behind one writer, the world
injected, and **one named function for a policy that a later milestone replaces** (`CONFIG.isThreat`).
`Shotgun.CONFIG.shouldArm` is the same idea with the same migration path, and `Weapon.setCast` is
`Boar.defaultWorld` at smaller scale. This is deliberate: the second system in a repo either
establishes the conventions or fights them.

**Pattern adopted overall:** server-authoritative hitscan (A) behind untrusted, rate-limited,
type-checked remotes (B); `Tool` + named CAS actions for input (C); thin boot scripts over fat
modules (D); attributes as the cross-system data contract (E); one code-built `ScreenGui` under one
UI owner (F); the repo's own owner/pure-core/instance-writer split (H). Nothing is invented except
the safety arc, which has no external pattern because it is this game's own mechanic — its whole
content is a dot product against the drive-line normal, one function and one number, and the research
note says the Architect places it: it is placed in `SafetyArc.isForbidden`, called from step 10 of
§5.4, publishing only.

---

## 11. Numeric targets — the one config table

Ballistics and feel numbers are the research note's ("Numeric targets"), at 1 stud = 0.28 m. Budgets,
limits and tolerances are this design's. **All of them live in `Shotgun.CONFIG`, frozen, and nowhere
else. No magic number outside it.**

| Field | Value | Where from |
|---|---|---|
| `SLUG_RANGE` | 330 studs | note: 100 yd MPR |
| `BUCK_RANGE` | 100 studs | note: 30 yd MPR |
| `BUCK_PELLETS` | 9 | note: 00 buck, standard load count |
| `SPREAD_FULL_DEG.Buck` | **1.6** (degrees, full cone) | note; ~2.8-stud circle at 100 studs |
| `SPREAD_FULL_DEG.Slug` | **0.16** (degrees, full cone) | note; effectively an exact ray |
| `SLUG_CAST_RADIUS` | 0 (pure raycast) | this design. `Spherecast` forgiveness is the named dial if Karen reports misses (note source 2); not built now |
| `BARREL_DELAY` | 0.25 s | note, feel number |
| `RELOAD_BREAK` / `RELOAD_SHELL` / `RELOAD_CLOSE` | 0.5 / 0.45 / 0.6 s | this design; 0.5 + 2×0.45 + 0.6 = **2.0 s**, the note's feel number, as one action (§12 asserts the sum) |
| `START_RESERVE` | 24 shells, plus 2 loaded | this design; ~12 reloads in a 10-minute drive |
| `INITIAL_AMMO` | `"Slug"` | this design; the gun starts loaded |
| `CAMERA_ORIGIN_TOLERANCE` | 30 studs from `HumanoidRootPart` | this design, replacing the old 8 (§2 defect 4). The stock camera's zoom is the player's; this rejects absurd origins, nothing more |
| `MIN_AIM_DISTANCE` | 4 studs | this design; below it the muzzle-to-aim-point vector is degenerate (§5.4 step 6) |
| `DIR_UNIT_TOLERANCE` | \|dir\|−1 ≤ 1e-3 | this design |
| `SAFETY_ARC_HALF_DEG` | 45 (degrees, half angle) | this design; provider is nil in v1, so it never fires |
| `FIRE_RATE_LIMIT` | 6 /s per player, excess dropped and counted | this design; 0.25 s barrel delay + 2.0 s reload gives a true max near 4 /s |
| `ACTION_RATE_LIMIT` | 10 /s per player | this design |
| `STATE_RATE_LIMIT` | ≤ 20 `StateChanged` /s per player | this design |
| `HANDLE_SIZE` | `Vector3.new(0.4, 0.5, 4.4)` | 4.4 studs ≈ 1.23 m, a shotgun's length at 0.28 m/stud |
| `HANDLE_COLOR` | `Color3.fromRGB(70, 55, 45)` | this design. Grey-box wood-brown; **check it on screen against grass and the grey plate**, the way `Boar.CONFIG.BODY_COLOR` had to be (Task 22) |
| `GRIP` | `CFrame.new(0, 0, 1.4)` | the hand holds the gun 1.4 studs behind centre; the Handle's **−Z is the muzzle**, so the barrel points away from the player. **Verify in the screenshot** — "a knife held backwards for three rounds" (`docs/PROJECT_CONTEXT.md`) |
| `MUZZLE_OFFSET` | `Vector3.new(0, 0, -2.2)` | half of `HANDLE_SIZE.Z`, the barrel tip |
| `TRACER_LIFETIME` / `IMPACT_LIFETIME` / `FLASH_LIFETIME` | 0.06 / 1.0 / 0.05 s | this design; all through `Debris:AddItem` |
| `EFFECT_MAX_PER_SHOT` | 24 | 9 tracers + 9 impacts + flash, with headroom; a hard cap so a bug cannot flood Workspace |
| `CROSSHAIR_ARM_PX` / `_GAP_PX` / `_THICK_PX` | 8 / 5 / 2 | this design; a 26-px cross, readable at 1080p without covering the boar |
| `CROSSHAIR_COLOR` / stroke | white, 1-px black `UIStroke` | this design; readable against sky and grass |
| `HUD_TEXT_SIZE` | 18, `Enum.Font.Code`, ASCII only | this design |
| `shouldArm(player)` | `return true` | this design, mirroring `Boar.CONFIG.isThreat`. Milestone 1.7 makes it `player.Team == Teams.Shooters` and touches nothing else |

### Performance and correctness targets, each one checkable

| Target | How it is checked |
|---|---|
| Server raycasts per shot ≤ `BUCK_PELLETS` + 1 (the camera ray) | `weapon_hits.spec`: the injected cast counts its calls |
| Server time per shot ≤ 0.5 ms | `weapon_shot.spec`: 1,000 `Pattern.directions` + `Hits.group` runs under 500 ms |
| `StateMachine.apply` ≤ 10 µs | `weapon_state.spec`: 10,000 applies under 100 ms (the boar's `Brain:step` target and method) |
| Client frame budget ≤ 0.2 ms/frame at 60 fps | effects only; no per-frame viewmodel exists in this task |
| Typed-value harness problems from this task | **0** (§8) |
| Effect instances alive 2 s after a shot | 0 (`Debris`) |
| Zero errors, zero skipped tests | `tests/TestKit.luau` fails the run otherwise |

**Lag, stated as a number because it will be felt.** There is no lag compensation in v1 — state rewind
is a system of its own. At 100 ms RTT a boar at `Boar.CONFIG.SPRINT_SPEED` (38 studs/s) is ~3.8 studs
from where the shooter saw it, and the boar is 5.5 studs long (`Boar.CONFIG.BODY_SIZE`). That is most
of a body length: shots that looked good will miss. This is the single most likely thing Karen reports
as "the gun feels wrong". Mitigation order: (1) the slug `Spherecast` dial above, (2) lag compensation
as its own designed system — **never** a fudge inside the weapon.

---

## 12. Karen's five feel defaults, as config

Brief item 3. She has not played it; these are defaults to be tuned, not decisions.

| # | Karen's default | Config field(s) | Alternative, if she says so |
|---|---|---|---|
| 1 | Spread: realistic — pellets genuinely miss past 100 studs | `SPREAD_FULL_DEG.Buck = 1.6`, `BUCK_RANGE = 100` | one number: a generous cone |
| 2 | Reload: 2.0 s, one uninterruptible action | `RELOAD_BREAK`/`RELOAD_SHELL`/`RELOAD_CLOSE`; the server runs Break→Load→Load→Close itself and `busyFor` covers the whole 2.0 s, so nothing can interrupt it | per-shell loading that can be cut short: the reducer already has the primitive `Load`, so it is a server-loop change, not a redesign |
| 3 | A crosshair | `CROSSHAIR_*` in `Shotgun.CONFIG`; owner `PlayerScripts.Hud` (§3.4) | size, colour, or none: `CROSSHAIR_ARM_PX = 0` is not the way — the Hud reads one boolean, `CONFIG.CROSSHAIR_ENABLED` |
| 4 | Barrel select: automatic, next live barrel | `StateMachine.apply` advances `selected` on `Fire` to the other barrel when it is `Live` | a manual selector key: one more CAS action and one more `ActionKind` |
| 5 | Loading only while the action is broken open | the reducer rejects `Load` unless `open == true` (reason `"is-closed"`), and rejects `Fire` while `open` (reason `"is-open"`) | — |

Note on 2 and 5 together, because they look like they conflict: the state machine keeps `open` as a
real state and enforces "no `Load` unless open"; the player triggers **one** action, `Reload`, and the
server drives the primitives through the 2.0 s window. Both defaults hold at once, and the invariant is
one spec assertion, not a comment. `SelectAmmo` changes only the *next* load's kind (`state.ammo`); it
never rewrites shells already in the barrels (`state.loaded`).

---

## 13. How it is tested

### 13.1 Server specs — everything authoritative, testable today

`tests/server/` → `ServerStorage.Tests` (`CLAUDE.md`, Layout). They write their own numbers rather
than importing `CONFIG` for the assertion, following `tests/server/test_arena.spec.luau`, so a spec
disagreeing with the config is a finding and not a tautology.

**`weapon_state.spec.luau`** — `StateMachine`, pure:
1. initial state: closed, both barrels `Live`, `loaded` both `INITIAL_AMMO`, `selected == 1`,
   `reserve == 24`, `busyFor == 0`, and the table is frozen (a write errors);
2. `Fire` → barrel 1 `Spent`, `loaded[1] == nil`, `selected == 2`, `busyFor == 0.25`;
3. `Fire` inside the barrel delay → rejected `"busy"`, state identical (same values, input unmodified);
4. `Fire` on a `Spent` barrel → `"barrel-empty"`; with both spent → `"barrel-empty"`, and `selected`
   does not move;
5. `Fire` while `open` → `"is-open"`;
6. `Break` → `open == true`, both barrels `Empty`, spent shells gone; `Load`×2 → both `Live`,
   `reserve == 22`, `loaded` both the current `ammo`; `Close` → `open == false`, `selected == 1`;
7. `Load` while closed → `"is-closed"`; `Load` into a `Live` barrel → `"barrel-full"`; `Load` with
   `reserve == 0` → `"no-reserve"` (and the reload sequence still completes with one shell);
8. `SelectAmmo` flips `ammo` and **does not** change `loaded`;
9. `RELOAD_BREAK + 2*RELOAD_SHELL + RELOAD_CLOSE == 2.0` exactly — the feel number is an assertion,
   not a comment;
10. every returned state is frozen and is a different table from the input;
11. 10,000 applies under 100 ms.

**`weapon_shot.spec.luau`** — `Validator`, `Pattern`, `SafetyArc`, all pure:
1. `Validator`: a non-`Vector3` origin → `"bad-type"`; `0/0` components → `"nan"`; magnitude 2
   direction → `"not-unit"`; origin 60 studs from the root → `"origin-far"`; origin 20 studs away →
   **accepted** (the third-person camera case, §2 defect 4); `rootPosition == nil` → `"not-alive"`;
2. `Pattern`: 9 directions for `"Buck"`, 1 for `"Slug"`; every direction unit to 1e-6; **every
   direction within `SPREAD_FULL_DEG/2` degrees of the aim, and at least one beyond
   `SPREAD_FULL_DEG/4`** — so a full/half mix-up in either direction fails (§4);
3. `Pattern`: `Random.new(42)` twice gives identical lists; `Random.new(43)` gives a different one;
4. `Pattern`: an aim of `Vector3.zero` errors or returns the fallback — pick one, assert it;
5. `SafetyArc`: true straight along the drive-line normal; false at 90°; the exact boundary behaves as
   documented (pick one and assert it); a `nil` line is never passed in (the owner checks first);
6. 1,000 `Pattern` + `Hits.group` cycles under 500 ms.

**`weapon_hits.spec.luau`** — `Hits`, with real Instances in the spec's own folder and an **injected**
cast, so no Workspace geometry and no physics:
1. `targetOf` on a part with `Damageable == true` → that part, zone from its `HitZone`;
2. `targetOf` on a child part of a model with `Damageable == true` → the model; zone from the child,
   falling back to the model, falling back to `"unknown"`;
3. `targetOf` on plain scenery → `nil` (a miss, no report);
4. `resolve` calls the cast once per direction and no more (count it);
5. `group`: 9 pellets on one target → **one** report with `pellets == 9`, a `zones` tally summing to 9,
   `nearest` equal to the smallest distance, `zone` the majority zone;
6. `group`: pellets split across two targets → two reports, tallies summing correctly;
7. `group`: a tie between two zones resolves to the **nearest** impact's zone.

**`boar_hit.spec.luau`** — the seam (§6), one boar runtime with the spec's own injected world (the
pattern `tests/server/boar_body.spec.luau` already uses: its own folder, its own field, teardown in
`afterAll`):
1. after `Runtime:spawn()`, the Part carries `Damageable == true` and `HitZone == "body"`;
2. `takeHit(part, hit)` → `true`; `stats().hits == 1` and `pelletsTaken == 9`;
3. `Runtime.Hit` fires exactly once with `id`, `zone`, `ammo`, `pellets` (polled, deferred signals);
4. `takeHit` on a foreign Part → `false`, and no counter moves;
5. `takeHit` after despawn → `false`;
6. the boar's state, position and lifetime are **unchanged** by a hit in this milestone — the
   assertion that keeps 1.5's reaction out of 1.4.

### 13.2 Client spec — `tests/client/weapon_client.spec.luau`

State only, which is what client specs can assert today (`tools/studio_mcp.py` docstring,
"Client-side testing"), reaching modules through `Players.LocalPlayer.PlayerScripts.Weapon`:
1. `ReplicatedStorage.Shotgun.Remotes` holds the four RemoteEvents with the right ClassNames;
2. `Shotgun.CONFIG` is frozen (a write errors), and `SPREAD_FULL_DEG.Buck == 1.6`;
3. `Weapon.get()` is `nil` or a frozen table with exactly the `WeaponState` fields; a write to it
   errors;
4. `Weapon.Input.AimChanged` is an `RBXScriptSignal`; `Weapon.Input.isAiming()` is a boolean;
5. **the visibility assertion, and it is the point of this spec.** With the Tool equipped:
   `Hud.gui()` exists, is a `ScreenGui`, `Enabled == true`, its `Parent` is the `PlayerGui`, and
   **every ancestor up to the DataModel is present**; the crosshair container and all four arms are
   `Visible`, with no ancestor `Visible == false` and no ancestor `Transparency == 1`; the crosshair
   container's `AbsolutePosition + AbsoluteSize/2` is within 2 px of the viewport centre. This is the
   spec that makes "a visibility audit ignored parent visibility and certified a blank screen twice"
   (`docs/PROJECT_CONTEXT.md`) impossible to repeat. It does not replace the screenshot.
6. with no Tool equipped, the crosshair is not visible (`Hud.isCrosshairVisible() == false`).

### 13.3 Task 6 — exactly what the smallest version must prove for this weapon

Brief decision 3: Task 6 lands **before** the shotgun build, no waiver. So this section is Task 6's
target, written by the system that consumes it. Everything in §13.1 is independent of it and can be
built and specced whether Task 6 lands first or not — but the weapon is not *done* until these pass.

**What Task 6 must prove (the channel), smallest useful version:**
1. a **keyboard** key down and up, driven from the harness during Play, reaches a
   `ContextActionService` action bound in the player's client, and a client spec sees it;
2. a **mouse button** down and up does the same (MouseButton1 is the fire path; a keyboard-only
   version does not unblock this weapon);
3. two inputs in sequence with a specified gap arrive **in order**, with the gap observable — a reload
   is a 2.0 s window and every assertion below is a before/after around a timed action.

That is three inputs, one scenario file and one harness step, reusing the existing report channel,
gate and token unchanged. **Prove the channel before anything is built on it.**

**The weapon assertions it then unlocks** (client spec, all through `Weapon.get()` — never internals):
- press R with a fired gun → within 2.0 s + 0.3 s, `barrels` are both `Live` and `reserve` dropped
  by 2; during the window `busyFor > 0`;
- MouseButton1 with a live barrel → within 0.3 s, `barrels[1] == "Spent"` and `selected == 2`;
- MouseButton1 twice inside `BARREL_DELAY` → only **one** barrel is spent (the rate/delay path is the
  one a cheat client attacks);
- MouseButton1 with both barrels spent → no state change at all (no phantom shot);
- press X → `ammo` flips and `loaded` does not change;
- press R **during** a reload → the reload still completes once, `reserve` drops by 2 and not 4
  (the uninterruptible property of Karen's feel default 2);
- MouseButton2 down/up → `Input.isAiming()` flips and `AimChanged` fires exactly once each way, and
  `workspace.CurrentCamera.CFrame` is **unchanged** — the mechanical proof that the weapon is not the
  camera's writer (§9).

### 13.4 Screenshot (rule 5) — available, and required

Play-time `screen_capture` through Studio MCP **works** and was used for Tasks 17, 18 and 22 (brief;
`ESCALATE.md`, 2026-09-25, closed). What is missing is only that `tools/studio_mcp.py`'s `Studio._call`
joins text blocks and drops image blocks, so the harness cannot save a capture itself — captures are
taken by calling the tool directly, as Task 22 did. So rule-5 evidence for this task is the Builder's
own inspected screenshots, not Karen's:
1. the shotgun **in the character's hand in third person**, from the side — the muzzle points away
   from the player (the `GRIP` check, §11);
2. the crosshair at the screen centre, over grass and over the grey plate, legible in both;
3. the barrel/ammo readout before and after a shot, and mid-reload;
4. a shot at the boar: tracer from the muzzle, impact mark on the boar.

Describe what is actually on screen, not what should be. A number is not a verification
(`docs/PROJECT_CONTEXT.md`).

### 13.5 The one-writer guard, and its status

Specs cannot prove a negative ("this module never writes the camera"). A grep can: a CI step that
fails if `CurrentCamera`, `CameraType`, `FieldOfView`, `MouseIcon`, `MouseBehavior` or
`MouseIconEnabled` is **assigned** under `src/client/Weapon/`, or `Health` is assigned under
`src/server/Weapon/`, or anything under `src/server/Weapon/` mentions `Workspace.Boars`. Reading
`workspace.CurrentCamera.CFrame` must still pass, so the pattern matches assignment, not mention.

**Status: not built in this task.** `ROADMAP.md` speed rule 1 freezes tooling after Task 11 and this
does not block the weapon. It is §14 item D for the Director, with "the Reviewer checks §1.2 by eye"
as the standing fallback.

### 13.6 Facts the Builder must report rather than assume (rules 6 and 8)

- whether a `.model.json` inside a folder module syncs and compares as
  `ReplicatedStorage.Shotgun.Remotes` (§8 gives the fallback);
- whether `Tool.Equipped` fires on the **server** for a Tool moved into the character, which is what
  `state.equipped` and therefore the crosshair depend on. If it does not, the fallback is the
  server watching `Tool.Parent`; report which was needed;
- the harness's unmanaged-instance scan covers `LuaSourceContainer` only (audit-002 must-fix 2,
  `TASKS.md` row 15), so a Part created by hand in Studio inside a Rojo-owned container passes a green
  run and is deleted at the next Connect. **Nothing in this system is built by hand in Studio.** There
  is no check behind that sentence yet; it is policy until Task 15.

---

## 14. Rows for `GAME_DESIGN.md` — ready to paste

Rule 3 requires the owners table to mirror this file. Add these five rows, and **fill the
`UI / anything drawn` row** rather than adding a sixth. Nothing else in that table changes except the
Boar row amendment below.

| System | Owner (the only writer) | Location | Research note |
|---|---|---|---|
| Weapon: authoritative state, firing, hit resolution, the safety-arc check, and every granted `Tool` | `ServerScriptService.Weapon`, booted once by `ServerScriptService.WeaponBoot`. `StateMachine`, `Validator`, `Pattern`, `Hits` and `SafetyArc` are pure and private to it; `Hardware` is the only writer of `Tool` Instances. It writes no boar state and no camera | `src/server/Weapon/`, `src/server/WeaponBoot.server.luau` | [shotgun](docs/research/2026-09-24-shotgun.md), [design](docs/design/shotgun.md) |
| Weapon client: the state replica, the `DrivenHunt.Weapon.*` input actions and the aim flag | `PlayerScripts.Weapon`, booted once by `PlayerScripts.WeaponBoot`. `Weapon.Input` is the only binder of those actions and the only firer of `FireRequest`/`ActionRequest`; the replica has no setter | `src/client/Weapon/`, `src/client/WeaponBoot.client.luau` | same |
| Shot cosmetics (`Workspace.WeaponEffects`, created at runtime on the client) | `PlayerScripts.Weapon.Effects`. Cosmetic only; it writes no state and decides no hit | `src/client/Weapon/Effects.luau` | same |
| **UI / anything drawn** (`PlayerGui.HunterHud` and everything in it: the crosshair and the barrel/ammo readout) | `PlayerScripts.Hud`. It **reads** `PlayerScripts.Weapon` and is never called by it, so nothing but the Hud can hide or move anything drawn | `src/client/Hud/` | [design](docs/design/shotgun.md) §3.4 |
| Shotgun numbers (every ballistic, timing, layout and rate number; frozen, no writer) | `ReplicatedStorage.Shotgun` (`Shotgun.CONFIG`), with `ReplicatedStorage.Shotgun.Remotes` holding the four RemoteEvents | `src/shared/Shotgun/` | same |

**Amend the existing Boar row** (do not add a new one) by appending to its owner cell:

> … It receives hits through the single seam `Runtime:takeHit(part, hit)` and publishes `Runtime.Hit`;
> `Boar.Body` publishes the attributes `Damageable` and `HitZone` that the weapon reads. The wiring
> from `Weapon.HitReported` lives in `BoarBoot`, so neither owner requires the other
> ([shotgun design](docs/design/shotgun.md) §6).

**Input** stays `_unassigned_` as a *system*, and that is deliberate: there is no global input router.
Each system owns its named `ContextActionService` actions under a reserved prefix, and this design
registers `DrivenHunt.Weapon.*`. Record that convention in the Input row rather than naming an owner
who would then own everyone's keys.

---

## 15. Open decisions — none of them blocks building

Every one has a default written into the config or into this document. They are things Karen or the
Director should overrule on purpose rather than by accident.

**Karen (feel) — the "check this" list for the first shooting playtest (`ROADMAP.md` speed rule 8):**
1. Does the gun fire when you expect? Is `BARREL_DELAY` 0.25 s too slow between the two barrels?
2. Is 2.0 s of reload right with a boar running, given you cannot interrupt it?
3. Do buckshot misses past 100 studs read as "the gun" or as "lag"? (§11's lag paragraph is the
   honest answer; the fix order matters and is written there.)
4. Is the crosshair the right size and colour over grass, sky and the grey plate?
5. Is the gun visible and held the right way round in third person, and is the wood-brown handle
   distinguishable from the boar and the plate?
6. **Should being shot scare the boar?** Default: **no** in this task — it is a behaviour change to a
   merged system and belongs with the Milestone 1.5 reaction. One line in `takeHit` if she wants it
   sooner.

**Director (scope):**
A. **The Hud's ammo readout** (§3.4). Default: **in**, because Karen's feel defaults 2 and 4 cannot be
   judged without it and there is no sound or animation in this task. Cutting it is deleting one
   `TextLabel` and one config row.
B. **A damage router** instead of `Boar:takeHit` (§6.2). Default: **not now**, revisit when a second
   animal or a second damage source exists. The seam is shaped so that a router later means changing
   `BoarBoot`'s connection, not either owner.
C. **Players are not damageable in v1.** A pellet that hits a player is a miss; the drive-line rule,
   not damage, is the answer to shooting at people (`ROADMAP.md` 1.7). If the Director wants
   friendly-fire feedback sooner, it is `Damageable` on a character part plus a listener — and it
   needs its own owner decision, not a weapon change.
D. **The one-writer CI grep** (§13.5). Default: **not in this task** (tooling freeze); it is the only
   mechanical enforcement of rule 3 the repo could have, so it is worth queueing before release.
E. **Mobile and gamepad.** Gamepad bindings are in the action table; **mobile touch buttons are not
   built** (§10 source C). Default: PC for v1's playtests.
F. **Where the Tool comes back from on respawn.** Default: `grant` runs on every `CharacterAdded` for
   a player `shouldArm` accepts, and the state resets to `initial` (a full gun, a full reserve). The
   match loop may want carry-over in 1.7; it changes one call site.

---

## 16. What I could not verify (rule 8)

- **Anything requiring Roblox Studio.** No Studio in this session (`.agent-evidence/INDEX.md`). Every
  claim about what the harness *would* do is read from `tools/studio_mcp.py`, not observed. Every
  claim about engine behaviour is from documentation and from the code already in this repo.
- **That `Tool.Equipped` fires on the server** for a Tool the server parents into the character. The
  crosshair's visibility rule depends on it; §13.6 makes confirming it a deliverable with a fallback.
- **That Rojo places `Remotes.model.json` under a folder module as a child of the ModuleScript.** The
  mechanism is the one that already gives `Boar.Brain` and `Boar.Body`, but no `.model.json` exists
  anywhere in this repo (`.agent-evidence/ls-files.txt`), so this would be the first. §8 gives the
  one-line fallback.
- **The external sources' current licence and maintenance status.** No network access this session.
  A–C, E and F are first-party Roblox documentation (creator-docs is CC BY 4.0) and the APIs ship with
  the engine; D (Knit, MIT) and G (fractality-spring, MIT) are from my own knowledge, and neither is a
  dependency of anything built here — only D's *pattern* is used, and G is not used at all. The
  Builder confirms them in the research-note addendum before relying on any of them.
- **The lag figures in §11** are arithmetic from `Boar.CONFIG.SPRINT_SPEED` and `BODY_SIZE`, not
  measurement. The research note says the tolerances "must be measured with two real players, not
  reasoned about", and that has not happened.
- **Whether `CAMERA_ORIGIN_TOLERANCE = 30` is generous or tight** for the stock camera at its default
  zoom. It is a guard against absurdity, not a proof of honesty (§5.6); if a legitimate shot is ever
  rejected with `"origin-far"`, that is a harness-visible bug and the number is the dial.
- **Anything about the DEV place's `SignalBehavior`.** Not a repo file. §13.1 assertion 3 polls, which
  is correct under both `Immediate` and `Deferred` — the same conclusion `docs/design/boar-ai.md`
  reached.
