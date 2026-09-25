# Design: drive (teams, the 10-minute drive, points, the score screen, the safety penalty)

System: `drive` — the match. One drive = one round: teams, a 10-minute timer, boars released into the
drive, individual points per boar, a score screen, and the comic penalty for shooting toward the
drivers. `ROADMAP.md` steps **1.6** (multiplayer test path) and **1.7**. Task 29.

Architect, 2026-09-25, read-only session: Read, Grep, Glob only. No Studio, no network. Evidence
precomputed in `.agent-evidence/` (`INDEX.md`), commit `d7720b177a16c5821d8bdc2a809071699737026a`.

Inputs, in precedence order: `reviews/task-29/BRIEF.md` (the Director's and Karen's decisions), the
code on this commit (`src/server/Weapon/`, `src/server/Boar/`, `src/server/TestArena.luau`,
`src/client/Hud/init.luau`, `tools/studio_mcp.py`), `docs/design/hit-zones.md`,
`docs/design/shotgun.md`, `docs/design/camera.md`, `docs/design/boar-ai.md`, `ROADMAP.md`,
`GAME_DESIGN.md`, `CLAUDE.md`, `docs/PROJECT_CONTEXT.md`.

**Test of this document:** a Builder can build the drive from it without asking a question. Every
number is here, every owner is named, every interface is written out, and every cross-system change is
listed in one table (§3.6).

---

## 0. Two build preconditions, stated first because they decide the branch

1. **Task 28 (hit zones) is not on `main` at this commit.** `src/server/Boar/init.luau` has
   `Runtime:takeHit` and `Runtime.Hit` (Task 24, merged) but **no `Runtime.Downed`, no `KillRecord`
   and no `WoundState`** — grep `src/server/Boar/init.luau` for `Downed`: nothing. This design's score
   input is `Runtime.Downed(record: KillRecord)` as `docs/design/hit-zones.md` §8.1 and §8.3 specify
   it. I could not read that branch (the Architect session is one worktree at one commit with Read,
   Grep and Glob — `CLAUDE.md`, "The agent scripts").
   **Therefore: branch from the hit-zones branch (a stacked PR) if Task 28 is unmerged when this is
   built, and say so in the review request's `Base:`.** §7.4 makes the Score module degrade loudly
   rather than silently if `Downed` is absent.
2. **Task 26 (camera) is in progress** (`reviews/task-29/BRIEF.md`). Nothing in this design touches
   `workspace.CurrentCamera`, the cursor or the viewmodel, and §1.2 forbids it. The only overlap is
   `src/client/Hud/init.luau`, which the camera task also changes
   (`docs/design/camera.md` §3.5, "One file outside this system changes"). Expect a merge there, in
   the Hud, which has exactly one owner either way.

**Scope warning for the Director, with a ready split.** This is the largest task in Milestone 1: it
fills the `Game state` owner slot, touches five merged files (§3.6) and adds fourteen. It is buildable
as one task, and it is also cleanly cuttable in two, at a line that leaves no half-owned system:

- **1.7a — the drive runs:** §4 (the phase machine), §5 (roster and teams), §6 (spawns, posts,
  boars), §7 (score, server side), the `MatchState` remote, and the Hud's timer/team/score lines.
- **1.7b — the safety rule and the score screen:** §8 (the penalty), §9.3 (the score-screen panel).

`Match.CONFIG.SAFETY_ENABLED = false` and `SCOREBOARD_ENABLED = false` make 1.7a a complete,
playable drive with 1.7b dark. My recommendation: **split**, because the penalty is the one part of
this system Karen has to *feel* before it is right, and it should not hold up the first 10-minute
drive she plays. Director item A in §14.

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

From Karen's v1 spec as `reviews/task-29/BRIEF.md` states it, and `ROADMAP.md` rows 1.6 and 1.7:

1. **One drive = one round.** 10 minutes, then a score screen, then the next drive, for as long as
   there are players.
2. **Two teams of equal size.** DRIVERS walk the woods and push boar toward SHOOTERS on posts along a
   line. v1: drivers on foot, no dogs. **Drivers may shoot is a config switch, default OFF.**
3. **Individual points per boar,** by the zone of the killing shot. Wounds and escapes count for less
   or nothing. The numbers are Karen's feel values and are marked as such.
4. **The safety rule:** a shooter who fires toward the drivers is punished, comically — frozen "tied
   to a tree" until the drive ends, visible to everyone. Players are **not** damageable
   (`docs/design/shotgun.md` §15 item C), so this rule, not damage, is the answer to shooting at
   people.
5. **Posts and the drive line are found by `CollectionService` tags,** so the Milestone 2 map
   generator places them without this system changing. The grey-box arena carries the first set.
6. **Several boars per drive,** released over the drive's length. Spawning is the drive's decision.
7. **10–16 players, and it must work with 2** (Karen and her daughter) for the Milestone 1 playtest.
8. **Every number in one config table,** Karen's feel values marked.
9. **Say plainly what the harness can and cannot do with 2+ players** (§12.6), and make every rule
   testable without a second client.

### 1.2 Must not

Each row is a named failure of the previous project (`docs/PROJECT_CONTEXT.md`, "Why the rules exist")
or a boundary an existing design already drew, written as a prohibition.

| Prohibition | Why | Whose job instead |
|---|---|---|
| Never write `workspace.CurrentCamera`, `UserInputService.MouseBehavior`/`.MouseIconEnabled`, or `Mouse.Icon` | "Three scripts set the mouse cursor"; and `docs/design/camera.md` §3.1/§3.3 names `Camera.Rig` and `Camera.Cursor` as the sole writers | `PlayerScripts.Camera` |
| Never create a `ScreenGui`, `Frame` or `TextLabel` outside `PlayerScripts.Hud`, and never a `BillboardGui` or `SurfaceGui` anywhere | "One predicate answered two unrelated questions, so mounting hid both the crosshair and the weapon". The UI owner is filled (`GAME_DESIGN.md`, UI row) | `PlayerScripts.Hud` (§9.3) |
| Never write a boar's state, position, attributes or Instances | `Boar.Body` is "the only writer of a boar's Instances" (`src/server/Boar/Body.luau` header) | `ServerScriptService.Boar`. The Match **calls** `runtime:spawn` and **reads** `handle.position()` (§6.3) |
| Never hold a damage number, a zone→reaction rule, or a health value | `docs/design/hit-zones.md` §1.2 and §3.1: the wound model has one home | `Boar.Wound` |
| Never decide, at fire time, where a shot went | the weapon has the muzzle direction; nothing else does (`docs/design/shotgun.md` §5.5 step 10) | `Weapon.SafetyArc`, publishing only (§8.2) |
| Never write a player's `WeaponState`, fire a weapon remote, or create/destroy a `Tool` | `ServerScriptService.Weapon` is the sole writer (`docs/design/shotgun.md` §3.1) | the Match **injects a policy** and asks for a re-evaluation (§8.5) |
| Never write `Workspace.TestArena` or anything in it | `ServerScriptService.TestArena` is its only writer (`GAME_DESIGN.md`, arena row; `src/server/TestArena.luau` header) | `TestArena`, which gains the tagged markers (§6.1) |
| Never write a `.rbxm`, and never a typed property value (`Vector3`, `CFrame`, `Color3`) into `.model.json`/`.meta.json` | `.rbxm` is banned (`CLAUDE.md`); typed values fail the harness as "cannot compare" (`tools/studio_mcp.py` docstring, check 4; audit-002 must-fix 1 open, `TASKS.md` row 16) | §10: everything positioned or coloured is built in code |
| Never accept a client→server remote in this system | the drive takes no player input, so it has **zero** inbound exploit surface, and that is worth keeping (§9.1) | — |
| Never damage, kill or ragdoll a player | Karen's penalty is comic, not lethal; players are not damageable | §8.4 freezes and moves, nothing else |
| Never move a player between teams **during** a drive | a team swap mid-drive is the worst kind of surprise, and it silently rewrites who may shoot | §5.3: assignment happens in `Assigning`, and a joiner takes the smaller team once |
| Never hold a `Player` instance in a table that outlives the player | the leak `reviews/task-23/RESULT.md` note (c) raised, queued as `TASKS.md` row 23a(c) | §7.2: per-player state is keyed by `UserId`, and `Match.forget(player)` empties it |
| Never add a Wally package or change `default.project.json` | `wally.lock` and `devpackages.sha256` are pinned against the commit; a project-file change costs Karen a Connect click (`CLAUDE.md`, Toolchain) | nothing here needs either (§10) |

**One predicate answers one question.** `Match.phase()` says which phase the drive is in. It does not
say whether a player may shoot, whether the scoreboard is visible, whether a boar may spawn, or
whether a violation is punishable. Those are four different questions with four different answers, in
§4.1, §8.5, §6.3, §9.3 and §8.3.

---

## 2. The shape of a drive, in one picture

```
      z = -190  exitZ ............. a boar past the line runs 40 more studs and is GONE ("escaped")
      z = -150  ####################  THE SHOOTER LINE: 8 posts, tagged DrivenHunt.ShooterPost
                                      one DrivenHunt.DriveLine part, its -Z pointing toward +Z
                      ^  ^  ^         shooters stand here and face +Z
      z =  -40        PillarMid
      z = +120  * * *                 DrivenHunt.BoarSpawn x4, boars enter here
      z = +170  ======                DrivenHunt.DriverStart (the existing ArenaSpawn pad area)
                                      drivers start here and push toward -Z
```

Every coordinate is inside the merged 400 × 400 arena (`src/server/TestArena.luau`, `LAYOUT.ground.span
= 400`) and consistent with `Boar.CONFIG.field` (`bounds` ±200, `exitZ = -190`, `groundY = 0`;
`src/server/Boar/init.luau`). The boar's own config already calls `exitZ` "the far edge, the future
shooter line" — this design puts the line **40 studs in front of it**, at z = -150, so a boar that
beats the line runs on and disappears behind the shooters instead of vanishing in their faces.

---

## 3. Ownership

Rule 3: exactly one writer per system, named here, mirrored into `GAME_DESIGN.md` (§13).

### 3.1 The decision: one new owner, and it fills the slot that has been empty since Task 1

`GAME_DESIGN.md` has `| Game state | _unassigned_ | | |`. This design fills it, and it is the last
unassigned slot in Milestone 1 after `Camera` (Task 26) and `UI` (Task 24).

**`ServerScriptService.Match`** — disk `src/server/Match/init.luau`, booted once by
`src/server/MatchBoot.server.luau`.

Sole writer of: the phase and its deadline, team membership, every player's per-drive score and
penalty state, which boars exist during a drive, the two outbound RemoteEvents, and the
`Workspace.DriveMarkers` folder. Nothing else in the repo writes any of those.

It is a **ModuleScript** (a folder with `init.luau`, exactly as `src/server/Boar/init.luau` and
`src/server/Weapon/init.luau`). **Nothing happens on `require`** — only `Match.start(world)` begins
production. That is the rule `src/server/Boar/init.luau` states in its header, and it is the only
thing that makes every spec in §12 possible.

**Not a "round service", not a "game manager", not a framework.** It is the boar/weapon shape at a
third instance: a folder module that owns state, pure decision modules driven by an injected world, and
one module that is the only writer of Instances. The third system either keeps the repo's conventions
or starts eroding them (`docs/design/hit-zones.md` §10 G made the same call).

### 3.2 The server modules

| Module | Is | Never |
|---|---|---|
| `src/server/Match/init.luau` → `ServerScriptService.Match` | **the owner**: `CONFIG`, the phase, `phaseEndsAt`, the per-`UserId` record table, the Heartbeat accumulator, `Match:step(dt)`, the two remotes, the `PhaseChanged`/`Scored`/`Punished` signals, `stats()` | decides a rule itself; touches Instances directly |
| `Phase.luau` | **pure**: `(state, event, now, config) -> (state, { Effect })`. The whole match state machine (§4) | touches Instances, services, clocks, `Player` |
| `Roster.luau` | **pure**: team assignment, balance, the between-drive swap, the mid-drive joiner (§5) | as above; it never knows what a `Player` is — it keys by `userId` |
| `Score.luau` | **pure**: a kill/escape/violation record → points; the leaderboard and its tie-break (§7) | as above |
| `Penalty.luau` | **pure**: `judge(shot, drivers, config) -> reason?` — was this shot a violation (§8.3) | as above |
| `Markers.luau` | **read-only**: reads `CollectionService` tags and returns one frozen table of posts, line, starts, spawns and trees. It validates and reports what is missing (§6.2) | writes anything, anywhere |
| `Body.luau` | **the only writer of player characters, of the `Teams` service, and of `Workspace.DriveMarkers`**: respawns, pivots, freezes, unfreezes, ropes (§8.4, §6.4). Named after `Boar/Body.luau`, which has exactly this role for the boar | decides anything; reads the phase |
| `src/server/MatchBoot.server.luau` | nothing. **The one composition root of the drive** (§3.5) | owns state |

`Phase`, `Roster`, `Score`, `Penalty` and `Markers` are exported as `Match.Phase`, `Match.Roster`… for
specs, exactly as `src/server/Boar/init.luau` exports `Boar.Brain` (line `Boar.Brain = Brain`), and for
the same reason: the pure core must be drivable with no world, no players and no clock.

### 3.3 The client modules

| Module | Sole writer of | Never touches |
|---|---|---|
| `src/client/Match/init.luau` → `PlayerScripts.Match` | the client's **replica** of the match snapshot. Deep-frozen, and there is **no setter**: it subscribes to `MatchState.OnClientEvent` itself | anything drawn, the camera, the weapon, any Instance, any outbound remote |
| `src/client/Hud/init.luau` → `PlayerScripts.Hud` | **unchanged owner**, new content: the drive timer, the team badge, the event feed and the score screen (§9.3) | match state, weapon state, the camera |

**The UI decision the brief asks for: `PlayerScripts.Hud`, not a new owner.** Rule 3 says anything
drawn has exactly one writer, and that writer is already named, already exists and already reads a
published replica without being called by it (`src/client/Hud/init.luau` header;
`docs/design/shotgun.md` §3.4). A second UI owner for the score screen is the previous project's
"mounting hid both the crosshair and the weapon" with a new name. The score screen is one more module
**inside** the Hud (`src/client/Hud/Scoreboard.luau`), private to it, and the Hud remains the only
thing that writes `PlayerGui.HunterHud`.

The dependency direction is one-way and unchanged: **Hud reads `Match.get()` and `Match.Changed`; the
Match holds no reference to the Hud and does not know it exists.**

### 3.4 The one shared, frozen table

**`ReplicatedStorage.Drive`** — disk `src/shared/Drive/init.luau`, plus
`src/shared/Drive/Remotes.model.json` → `ReplicatedStorage.Drive.Remotes`.

It holds the **wire types** and the handful of numbers the client needs to render (nothing else), and
is deep-frozen with `Drive.deepFreeze`, the same function `src/shared/Shotgun/init.luau` already
provides — **required from `Shotgun`, not copied**, because `table.freeze` being shallow is a defect
this repo has already paid for once (Task 23a note (b)).

Naming follows the weapon exactly: three owner modules called `Match` in three services, one shared
table with a different name (`Drive`), so every `require` site reads unambiguously.

**The rule numbers stay on the server.** `Match.CONFIG` (the drive length, the points table, the
penalty, the boar schedule) lives in `src/server/Match/init.luau` and is **not** replicated. A client
that knows the points table can compute nothing it is not already told, but a client that knows the
safety numbers can dodge the rule by eye; and the brief asks for *one* config, which is the server's.
`Drive.CONFIG` holds only layout and colours for the Hud. Stated so it is not mistaken for two configs
for one thing: they hold disjoint facts.

### 3.5 One composition root for the drive, and `BoarBoot` is archived into it

Today `src/server/BoarBoot.server.luau` does three things: it asserts the arena still matches
`Boar.CONFIG.field`, it builds and runs the production boar runtime (`Boar.newRuntime`,
`runtime:spawn()`, `runtime:run()`), and it wires `Weapon.HitReported` to `runtime:takeHit`.

From this task, **when a boar exists is a drive decision** (brief item 6). Two Scripts in
`ServerScriptService` have no defined order and cannot share a Luau value, so leaving the runtime
inside `BoarBoot` would force a singleton accessor on `Boar` — a global by another name.

**Decision: `src/server/BoarBoot.server.luau` is archived (rule 7: `git mv` to `backups/` with a
note), and all three of its jobs move verbatim into `src/server/MatchBoot.server.luau`.** One place
where a production boar comes into existence, one place that knows both the weapon and the boar, and
no owner requiring another owner — which is the property `docs/design/shotgun.md` §6.3 established and
this keeps.

`MatchBoot.server.luau`, in full, because the wiring **is** the design:

```luau
local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local TestArena = require(ServerScriptService:WaitForChild("TestArena"))
local Match = require(ServerScriptService:WaitForChild("Match"))

-- unchanged from BoarBoot: the arena rectangle is carried as data, so a map change fails loudly here
assert(TestArena.LAYOUT.ground.span == (field.bounds.maxX - field.bounds.minX)
	and TestArena.LAYOUT.ground.top == field.groundY, "...")

local world = Boar.defaultWorld()
-- THE CLOSURE TRAP, and it is why this line exists (§6.5): Boar.defaultWorld's `threats` closes over
-- the MODULE-level Boar.CONFIG, not over the runtime's merged clone, so overriding `isThreat` through
-- world.config would change nothing. Replace the function itself, at the composition root.
world.threats = Match.driverThreats
local runtime = Boar.newRuntime(world)
runtime:run()                       -- the Heartbeat is boot; WHEN a boar exists is the Match's call

Weapon.HitReported:Connect(function(report)     -- unchanged from BoarBoot
	if report.target:IsA("BasePart") then
		runtime:takeHit(report.target, { ... })  -- exactly the payload Task 28 lands
	end
end)

Weapon.setDriveLineProvider(Match.driveLine)    -- §8.2
Weapon.setArmingPolicy(Match.mayCarryWeapon)    -- §8.5
Weapon.start()  -- stays in WeaponBoot; listed here only to fix the order question: it does not matter

Match.start({
	boars = runtime,                             -- the Match calls spawn/boars, never writes one
	markers = Markers.read(),                    -- §6.2
	weapon = Weapon,                             -- for refreshArming only
	now = function() return os.clock() end,
})
```

Everything the Match needs from the world is a field of that one table, so a spec passes its own —
the pattern `Boar.defaultWorld` established and `tests/server/boar_body.spec.luau` already exercises.

### 3.6 Every file that changes, in one table

Rule 8: the whole blast radius, so nothing is discovered at merge time.

| File | Change | Owner of it |
|---|---|---|
| `src/shared/Drive/init.luau` | **NEW** wire types, `Drive.CONFIG`, `Drive.remotes()` | this system |
| `src/shared/Drive/Remotes.model.json` | **NEW** Folder + `MatchState`, `MatchEvent` | this system |
| `src/server/Match/{init,Phase,Roster,Score,Penalty,Markers,Body}.luau` | **NEW** | this system |
| `src/server/MatchBoot.server.luau` | **NEW** (§3.5) | this system |
| `src/client/Match/init.luau`, `src/client/MatchBoot.client.luau` | **NEW** | this system |
| `src/client/Hud/init.luau`, `src/client/Hud/Scoreboard.luau` | **CHANGED / NEW**, inside the UI owner | `PlayerScripts.Hud` |
| `src/server/TestArena.luau` | **CHANGED**: `LAYOUT` gains posts, drive line, driver start, boar spawns and trees; `build` tags them (§6.1) | `TestArena` — the change is inside its own owner |
| `src/server/Weapon/init.luau` | **CHANGED**: `Weapon.setArmingPolicy`, `Weapon.refreshArming`, and `SafetyViolated` gains a fourth argument `stopAt` (§8.2, §8.5) | `ServerScriptService.Weapon` — changes inside its own owner |
| `src/server/Boar/init.luau` | **CHANGED**: one number, `maxBoars = 4` → `8` (§6.3) | `ServerScriptService.Boar` |
| `src/server/BoarBoot.server.luau` | **ARCHIVED** to `backups/2026-xx-xx_boarboot.luau.txt` with a note (rule 7); its content is in `MatchBoot` | — |

**Nothing else.** In particular: no change to `src/server/Boar/Brain.luau`, `Body.luau`, `Wound.luau`,
to any pure weapon module, to `src/client/Weapon/`, to `tools/`, or to `default.project.json`. A
folder with `init.luau` takes its siblings as children, which `src/server/Boar/` and
`src/server/Weapon/` both prove green (`TASKS.md` rows 18 and 24).

---

## 4. The match state machine

### 4.1 Phases

`Phase` is pure: `Phase.step(state, event, now, config) -> (state, { Effect })`. It returns a **new
frozen state** and a list of effects the owner performs. It touches nothing.

| Phase | Entered when | Lasts | What is true in it |
|---|---|---|---|
| `Waiting` | boot; or a drive ends with `< MIN_PLAYERS` present; or the markers are incomplete | until `#participants >= MIN_PLAYERS` **and** the markers are complete | no teams, no boars, no timer. Everyone is neutral and unarmed. The Hud says what is missing |
| `Assigning` | `Waiting` satisfied, or `Scoring` elapsed with enough players | `INTERMISSION_SECONDS` = 20 s | teams are assigned **once, on entry**; everyone is respawned at their post or the driver start; guns are granted by policy; scores are zeroed; carcasses and live boars from the last drive are cleared |
| `Running` | `Assigning` elapsed | `DRIVE_SECONDS` = 600 s | the drive. Boars are released on a schedule; kills and escapes score; the safety rule is live; the timer counts down on every Hud |
| `Scoring` | `Running` elapsed, or **every** boar of the drive is dead or escaped and `END_ON_LAST_BOAR` is true (default **false**) | `SCORE_SECONDS` = 25 s | the score screen. Tied players are freed. No boars, no scoring, no penalty. Shooting is possible and pointless |

`Waiting → Assigning → Running → Scoring → Assigning → …`, and `Scoring → Waiting` when the player
count has dropped below `MIN_PLAYERS`. `Running` is the only phase in which anything scores, and that
is one predicate in one place (`Phase.isLive(state)`), read by §6.3, §7.1 and §8.3.

**Every transition is time-driven from `phaseEndsAt`, and `phaseEndsAt` is the only clock.** There is
no `task.delay`, no `task.wait` and no second timer anywhere in this system. A hitch cannot skip a
phase, and a spec can run a whole 10-minute drive in a few milliseconds of simulated `dt` — the
property `docs/design/hit-zones.md` §6.4 required of the carcass timer, for the same reason.

### 4.2 Events the machine consumes

```luau
export type Event =
	{ kind: "tick" }
	| { kind: "join", userId: number, name: string }
	| { kind: "leave", userId: number }
	| { kind: "kill", record: KillRecord }         -- from Boar Runtime.Downed
	| { kind: "gone", record: DespawnRecord }      -- from Boar Runtime.Despawned
	| { kind: "violation", userId: number, at: number }
	| { kind: "markers", complete: boolean }
```

Nothing else. In particular there is **no client-originated event**: §9.1.

### 4.3 Effects the machine emits

The pure machine cannot respawn anybody, so it says what must happen and the owner does it. This is
the split that makes the whole match testable with no players:

```luau
export type Effect =
	{ kind: "assignTeams", assignment: { [number]: TeamName } }
	| { kind: "placePlayers" }                       -- respawn + pivot to post / driver start
	| { kind: "refreshArming", userIds: { number } }
	| { kind: "spawnBoar", position: Vector3 }
	| { kind: "clearBoars" }
	| { kind: "freeze", userId: number, anchor: Vector3 }   -- tie to a tree
	| { kind: "release", userIds: { number } }              -- untie everyone
	| { kind: "broadcast" }                          -- push a snapshot now
	| { kind: "feed", entry: FeedEntry }             -- one line for the event feed
```

A spec asserts on the **effect list**, which is a plain table — no Instances, no waiting, no physics.
That is how `boar_brain.spec.luau` already asserts on an `Intent` (`src/server/Boar/Brain.luau` via
`Runtime:step`), and it is why that spec can drive 10 000 ticks.

### 4.4 Join and leave, phase by phase — the brief's question, answered in full

| | `Waiting` | `Assigning` | `Running` | `Scoring` |
|---|---|---|---|---|
| **A player joins** | counted; no team; when the count reaches `MIN_PLAYERS` the machine enters `Assigning` | assigned with everybody else | **assigned immediately to the smaller team** (tie → `ODD_PLAYER_TEAM`), spawned at a free post or the driver start, armed by policy, **score starts at 0**. No existing player moves | no team; watches the score screen; assigned at the next `Assigning` |
| **A player leaves** | counted out | removed from the assignment before it is used | their team shrinks. **Nobody is moved to rebalance** — a swap mid-drive is forbidden (§1.2). Their score is **kept for this drive's score screen**, marked `left`, and dropped at the next `Assigning`. If they were tied, the tie record is dropped with them | dropped from the next drive's roster; the screen keeps showing their result |

**A drive never aborts because a team emptied.** With 2 players, one leaving leaves a one-person
drive that runs to the end and scores. That is deliberate: Karen and her daughter will do exactly this
by accident, and a match that resets under them is worse than a lopsided one. `stats().emptyTeamDrives`
counts it so it is visible rather than folkloric.

**`Match.forget(userId)` is called from `Players.PlayerRemoving`** and removes **every** table keyed by
that user — the shape `Weapon.forget` + `Registry:forget` already has
(`src/server/Weapon/init.luau`, `Weapon.forget`), and it is why §7.2 keys by `UserId` and never by
`Player`. The one exception is the current drive's score row, which is copied into the drive result
and holds no `Player`.

---

## 5. Teams

### 5.1 Representation: `Player.Team`, and nothing else

Team membership is **Roblox's own `Player.Team`**, written only by `Match.Body`. One representation of
one fact. Reasons, in order of weight:

1. It replicates to every client for free, so the client replica needs no team field per player and
   cannot disagree with the server.
2. A client **cannot** write it — team is server-authoritative by construction, so an exploiter cannot
   join the shooters and get a gun.
3. It colours the Roblox player list, which is a free score-screen-adjacent affordance in a grey box.
4. `Boar.CONFIG.isThreat` and `Shotgun.CONFIG.shouldArm` were both written against `player.Team`
   (`src/server/Boar/init.luau` comment: "Milestone 1.7 replaces the body with
   `player.Team == Teams.Drivers`"; `docs/design/shotgun.md` §11, `shouldArm` row).

`Match.Body` creates exactly two `Team` instances in the `Teams` service at `start()`:
`Drivers` (`BrickColor.new("Bright blue")`) and `Shooters` (`BrickColor.new("Bright orange")`),
`AutoAssignable = false` so Roblox never assigns anyone. `Teams` is not a Rojo-owned container and
holds no scripts, so nothing about this trips the harness's unmanaged-script scan, which covers
`LuaSourceContainer` only (`tools/studio_mcp.py`, `QUERY_ALL_SCRIPTS`).

### 5.2 `Roster` — pure, and it never knows what a `Player` is

```luau
Roster.assign(userIds: { number }, previous: { [number]: TeamName }?, config)
	-> { [number]: TeamName }
Roster.smallerTeam(counts: { [TeamName]: number }, config): TeamName
Roster.counts(assignment: { [number]: TeamName }): { [TeamName]: number }
```

The rules, each one an assertion in §12.2:

1. **Equal, to within one.** `|#Drivers − #Shooters| ≤ 1` for any 2 ≤ n ≤ 16.
2. **The odd player goes to `ODD_PLAYER_TEAM`, default `Drivers`.** With 2 players that gives 1 driver
   and 1 shooter, which is exactly Karen and her daughter, and it is the split that makes a drive a
   drive.
3. **Deterministic.** The input is sorted by `userId` before splitting, so the same roster gives the
   same assignment on every server and in every spec run. No `Random` anywhere in this module.
4. **Roles swap between drives** when `SWAP_TEAMS_EACH_DRIVE` is true (**default: true**). A player
   who drove in drive 1 shoots in drive 2. Everybody wants to shoot; over a session it is equal, and
   the alternative (fixed roles) makes half the players tourists.
5. `assign` takes `previous` only to honour rule 4; with `previous = nil` it is the plain split.

### 5.3 What `Assigning` does, in order

1. `Roster.assign` over the current participants.
2. `Match.Body.setTeams(assignment)` — `player.Team = …` for everybody, and `nil` for anybody not in
   the assignment.
3. `Match.Body.place(player)` — `player:LoadCharacter()`, then, once `player.Character` and its
   `PrimaryPart` exist, `character:PivotTo(cf)` to that player's post (shooters, one each by index) or
   a driver start point (drivers, spread across `DRIVER_START_WIDTH`). Facing: shooters face **+Z**
   (up the drive), drivers face **−Z** (toward the line).
4. `Weapon.refreshArming(player)` for everybody (§8.5). Note that `LoadCharacter` fires
   `CharacterAdded`, which the weapon already watches (`src/server/Weapon/init.luau`, `watchPlayer`),
   so in the normal path the policy is consulted by the weapon itself and `refreshArming` is a no-op
   — it exists for the join-mid-drive race, where the team is set *after* the character spawned.
5. Scores zeroed, carcasses and boars cleared, the drive counter incremented, one `broadcast`.

**`PivotTo` after `LoadCharacter` is a two-step, not one call**, and it is the kind of thing that
silently half-works: the character does not exist synchronously. `Match.Body.place` connects
`player.CharacterAdded` **before** calling `LoadCharacter`, pivots in that handler, and counts
`stats().placementsMissed` if the character never arrives within `PLACE_TIMEOUT = 5 s`. A number in
the harness report, not a feeling in a playtest (`docs/design/hit-zones.md` §10 G).

---

## 6. Posts, the drive line, and boars

### 6.1 The markers are tags, and the arena places the first set

Five tags, all under the reserved prefix `DrivenHunt.`, which no other system may use:

| Tag | On | Read for |
|---|---|---|
| `DrivenHunt.ShooterPost` | one `Part` per post, 8 of them at z = −150, x = −140 … +140 in steps of 40 | where each shooter stands; also the fallback tie-up point |
| `DrivenHunt.DriveLine` | **exactly one** `Part` at (0, 1, −150), size (320, 1, 1) | `DriveLine = { position = part.Position, normal = part.CFrame.LookVector }`. Its **−Z faces +Z of the world**, so the normal points **toward the drivers**, which is the meaning `docs/design/shotgun.md` §5.1 gives the field and which `src/server/Weapon/SafetyArc.luau` implements |
| `DrivenHunt.DriverStart` | one `Part` at (0, 1, +170) spanning x ±60 | where drivers spawn, spread across its X extent |
| `DrivenHunt.BoarSpawn` | 4 `Part`s at z = +120, x = −120, −40, +40, +120 | where boars enter the drive |
| `DrivenHunt.Tree` | 4 `Part`s (the arena's four corner pillars are re-used, tagged, not moved) | where a punished shooter is tied |

`src/server/TestArena.luau` gains these to `LAYOUT` and tags them in `TestArena.build` with
`CollectionService:AddTag`. That file is the only writer of `Workspace.TestArena` and is replaced
wholesale by the Milestone 2 map generator (its own header says so), so the markers travel with the
map exactly as `ROADMAP.md` Milestone 2 plans ("posts and drive-line markers by tag").

**Tags, not attributes, and here is the one place this design disagrees with a previous one.**
`docs/design/shotgun.md` §10 source E chose attributes over tags because "attributes on a `.model.json`
part are compared by the harness today and tags are not". That reasoning is right for a per-instance
*value* authored on disk. It does not apply here: the markers are **built in code** (§10), so there is
no disk authoring to compare, and the question is "give me every post", which is
`CollectionService:GetTagged` in one call and an O(n) Workspace walk otherwise. The brief names tags.
A server spec asserts the tags directly (§12.5), which is stronger than the harness's file comparison,
not weaker.

### 6.2 `Markers` — read-only, and loud when something is missing

```luau
Markers.read(collection: CollectionService?): MarkerSet    -- frozen
export type MarkerSet = {
	posts: { BasePart },          -- sorted by X, so post 1 is always the same post
	line: DriveLine?,             -- nil when no DrivenHunt.DriveLine part is tagged
	driverStart: BasePart?,
	boarSpawns: { Vector3 },
	trees: { BasePart },
	complete: boolean,            -- line and driverStart present, #posts >= 1, #boarSpawns >= 1
	missing: { string },          -- the tag names that produced nothing
}
```

If `complete` is false the machine **stays in `Waiting`**, warns **once** with the exact missing tag
names, and the Hud shows them. It does not start a drive against half a map, and it does not crash.
Two tagged `DrivenHunt.DriveLine` parts is also `complete = false` with `missing = {"DrivenHunt.DriveLine (2 found, want 1)"}`
— an ambiguous drive line is worse than none, because the safety rule would silently use whichever the
engine returned first.

`Markers.read` is re-run on `Assigning` entry, so a map rebuilt in Edit mode between drives is picked
up without a server restart.

### 6.3 Boars: how many, when, and who says so

**The Match decides; `ServerScriptService.Boar` still owns every boar.** The Match calls
`runtime:spawn(position)` and reads `runtime:boars()` handles (`handle.state()`,
`handle.position()` — `src/server/Boar/init.luau`, `Runtime:spawn` returns exactly that handle). It
writes nothing about a boar, ever.

The schedule, all in `Match.CONFIG`:

| Number | Value | K? | Why |
|---|---|---|---|
| `BOARS_PER_DRIVE` | 6 | K | a 10-minute drive with six chances; enough that a miss is not the whole round |
| `FIRST_RELEASE_SECONDS` | 20 | K | the drivers need to be walking before the first boar moves |
| `RELEASE_INTERVAL_SECONDS` | 90 | K | 20 + 5 × 90 = 470 s, so the last boar has ~130 s of drive left |
| `MAX_ALIVE_BOARS` | 4 | | never exceed `Boar.CONFIG.maxBoars` |
| `RELEASE_JITTER_SECONDS` | 15 | K | so the drive is not a metronome. The only `Random` in this system, seeded per drive and recorded in `stats()` so a report is reproducible |

**Two real hazards in the merged boar code, and what this design does about each:**

1. **`Runtime:spawn` asserts.** `src/server/Boar/init.luau`, `Runtime:spawn`, begins
   `assert(#self._boars < self._config.maxBoars, "Boar runtime is at maxBoars")`. An assert raised
   inside the Match's Heartbeat step would kill the step, not the spawn. The Match therefore
   **checks before it calls** (`#runtime:boars() < MAX_ALIVE_BOARS` and
   `< Boar.CONFIG.maxBoars`), and counts `stats().releasesDeferred` when it holds one back. A deferred
   release is retried on the next step, not dropped.
2. **Carcasses occupy slots.** After Task 28, a killed boar stays in `_boars` for
   `CONFIG.WOUND.CARCASS_SECONDS = 120` (`docs/design/hit-zones.md` §11.2), and `maxBoars` counts it.
   With `maxBoars = 4`, four kills in two minutes stops the drive dead. Two changes, both small:
   **`Boar.CONFIG.maxBoars` goes from 4 to 8** (one number, in the boar's own config, which
   `docs/design/boar-ai.md` calls "a guard, not a feature"), and the Match's own `MAX_ALIVE_BOARS`
   counts only boars whose `handle.state()` is neither `"DOWN"` nor `"GONE"`. This is
   `docs/design/hit-zones.md` §14 Director item B, answered: carcasses stay 120 s, and the drive's own
   `clearBoars` at the end of `Running` removes whatever is left.

`Boar.CONFIG.spawnPoint` is **unused in production** from this task: the Match passes an explicit
position from `DrivenHunt.BoarSpawn`, round-robin with jitter. The config value stays for the specs
that use it.

### 6.4 `Workspace.DriveMarkers` — the one new runtime container

`Match.Body` creates `Workspace.DriveMarkers` on first use and is its only writer. It holds one thing:
a rope `Part` per tied player (a thin brown cylinder from the player's `HumanoidRootPart` to the tree
they are tied to), destroyed when they are released. Nothing else, ever.

Workspace is not Rojo-owned (`CLAUDE.md`, Layout) and the harness compares the Edit-mode DataModel, so
a runtime folder is invisible to it and cannot dirty a run — the same reasoning
`docs/design/shotgun.md` §7.2 records for `Workspace.WeaponEffects`.

### 6.5 The closure trap in `Boar.defaultWorld`, and why `MatchBoot` has that one line

`src/server/Boar/init.luau`, `Boar.defaultWorld`, opens with `local config = Boar.CONFIG` and its
`threats` function calls `config.isThreat(player)`. `Boar.newRuntime` merges `world.config` into a
**clone** of `Boar.CONFIG` for the runtime, but `defaultWorld`'s closure captured the module table, not
the clone. **So passing `config = { isThreat = … }` into the world changes the Brain's copy and not the
one that actually filters threats.** A Builder would discover this as "shooters still scare the boar"
after an hour.

The fix is one line at the composition root and no change to the boar: `world.threats =
Match.driverThreats`, where

```luau
function Match.driverThreats()   -- pure read; the same shape defaultWorld().threats returns
	-- { { id = tostring(userId), position = Vector3 } } for every LIVE driver with a character
end
```

Only drivers scare boars, which is the mechanic: a shooter standing on a post must not push the boar
back into the wood before it reaches the line.

---

## 7. Points

### 7.1 The table

`Match.CONFIG.POINTS`. **K** marks Karen's feel values (brief: "propose numbers, they are Karen's feel
values"). Every one of them is a number in one table and nothing computes points anywhere else.

| Field | Value | K? | Reads as |
|---|---|---|---|
| `KILL.head` | 100 | K | a clean head shot, the best shot in the game |
| `KILL.chest` | 80 | K | the shot a hunter actually takes; nearly as good, and far easier |
| `KILL.body` | 50 | K | it died, but it ran and it suffered |
| `KILL.legs` | 30 | K | you brought it down eventually |
| `KILL.unknown` | 50 | | scored as `body`, never free, and counted in `stats().unknownZoneKills` |
| `ASSIST` | 10 | K | to every contributor who is not the killer and put in ≥ `ASSIST_MIN_DAMAGE` |
| `ASSIST_MIN_DAMAGE` | 25 | K | a quarter of `Boar.CONFIG.WOUND.LETHAL`; one pellet does not earn an assist |
| `PUSH` | 25 | K | to every **driver** who was within `PUSH_RADIUS` of that boar inside `PUSH_WINDOW` before it died |
| `PUSH_RADIUS` | 60 | K | 1.5 × `Boar.CONFIG.DETECT_RADIUS`, so it means "you were the reason it ran" |
| `PUSH_WINDOW` | 20 s | K | long enough to cover a boar's flight, short enough that a driver on the far side earns nothing |
| `ESCAPE_WOUNDED` | 0 | K | the brief's "wounds/escapes count for less or nothing". Zero, so the lesson is "take the shot you can make" |
| `SAFETY_PENALTY` | −50 | K | half a good kill, on top of losing the rest of the drive |

**Why drivers score at all, stated because it is the one thing in §7 worth arguing about.** The brief
says "individual points per boar" and does not say who gets them. If only the killer scores, then for a
whole drive half the players have an empty score line and a score screen that says nothing to them —
and with `SWAP_TEAMS_EACH_DRIVE` they wait ten minutes for their turn. `PUSH` makes driving a scoring
activity with the same currency, and it is cheap: the Match samples driver↔boar distances at
`PUSH_SAMPLE_HZ = 2`, which at the worst case in v1 (8 drivers × 4 live boars) is 64 distance
comparisons a second and **zero raycasts**. Each boar carries a set of `userId → lastNearTime`, and
`Score.pointsFor` reads it when the boar dies.

**`PUSH = 0` switches the whole idea off** and costs nothing else. That is Karen item 2 in §14.

### 7.2 `Score` — pure, and keyed by `UserId`

```luau
export type Row = {
	userId: number, name: string, team: TeamName?,
	points: number, kills: number, assists: number, pushes: number,
	wounded: number, escaped: number, violations: number,
	left: boolean, firstKillAt: number?,
}

Score.new(): Board                                        -- frozen, empty
Score.kill(board, record: KillRecord, pushCredit: { [number]: number }, config)
	-> (Board, { Award })     -- Award = { userId, points, reason }
Score.escape(board, record: DespawnRecord, config): (Board, { Award })
Score.violation(board, userId: number, config): (Board, { Award })
Score.join(board, userId, name, team): Board
Score.leave(board, userId): Board                          -- marks `left`, keeps the row
Score.leaderboard(board): { Row }                          -- sorted, §7.3
```

No `game:GetService`, no clock, no `Player`, no `Instance`, no `Random`. `config` is a parameter, not
a lookup — the discipline `Boar.Wound` and `Weapon.StateMachine` are already held to.

**`Player` is never stored**, only `userId` and `name`. A wounded boar can outlive a disconnect by 25 s
(`Boar.CONFIG.WOUND.BLEED_OUT_MAX_SECONDS`) and a score row outlives it by a whole drive; holding a
`Player` pins the instance — `TASKS.md` row 23a(c).

### 7.3 The leaderboard and its tie-break

Sorted by `points` descending; ties broken by **`kills` descending, then `firstKillAt` ascending, then
`userId` ascending**. The last key makes it total, so the score screen never reorders between two
broadcasts for no reason — a wandering scoreboard is this project's "a marker wandering the screen"
(`docs/PROJECT_CONTEXT.md`) in a new place.

### 7.4 Where the kill comes from, and what happens if it is not there yet

`Runtime.Downed(record: KillRecord)` and the extended `Runtime.Despawned(record)`, both from
`docs/design/hit-zones.md` §8.3. `Match.start` connects both, and:

- `Downed` → `Score.kill`, using `record.killedByUserId`, `record.killingZone` and
  `record.contributors`.
- `Despawned` with `reason == "escaped"` and `mortallyWounded == true` → `Score.escape`
  (`ESCAPE_WOUNDED` points, and the feed says the boar got away wounded).
- `Despawned` with `reason == "killed"` → **nothing**: that is the carcass leaving, and the kill was
  already scored. Scoring both is a double count that looks like a cheat
  (`docs/design/hit-zones.md` §1.2).

**If `Runtime.Downed` does not exist** (Task 28 not merged, §0), `Match.start` does not error: it
warns once, counts `stats().killSignalMissing`, and the drive runs with no kill scoring. A missing
dependency shows as a number in the harness report rather than as a match that silently scores zero.

---

## 8. The safety rule

### 8.1 The decision, and the alternative it beats

Karen's rule is "shooting toward the drive line is punished", and the brief says "a shooter who fires
toward the drive line / toward drivers". Those are two different geometries, so this design picks one
and says why.

**v1 rule: _you fired at a driver_.** A shot is a violation when a live driver's character was inside
`SAFETY_MISS_STUDS` of the shot's own path, in front of the muzzle, and nearer than where the pellets
stopped.

Rejected, and recorded so it is not re-invented: **"any shot within 45° of the drivers"** on its own. A
shooter stands at a post facing +Z and shoots at boars coming from +Z — *every legitimate shot* is
within that cone. Taken literally, it ties everybody in the first minute. The cone is still useful, but
as a filter, not as the verdict (§8.2).

Also rejected: **"any shot along the line"** (at your neighbours). It is the other real-life rule and it
is detectable with no drivers at all, but `src/server/Weapon/SafetyArc.luau`'s `isForbidden` compares
against **one** normal, so it would catch only one of the two directions down the line, and Karen's
words name the drivers. Named here as the obvious v1.1 addition; it is one extra pure test in
`Penalty.judge` and no new plumbing.

### 8.2 Who decides what, at fire time

| Step | Who | Evidence |
|---|---|---|
| The shot's true direction and where the pellets stopped | **the weapon**, and only the weapon: `aim` is computed from the muzzle to the aim point at `src/server/Weapon/init.luau` (the block that fires `safetySignal`), which is defect (e) of the Task 23 review already fixed | `docs/design/shotgun.md` §5.5 step 10 |
| Where the drive line is | **the Match**, through the provider the weapon already accepts: `Weapon.setDriveLineProvider(Match.driveLine)` (`src/server/Weapon/init.luau`, `Weapon.setDriveLineProvider`; the field is `nil` today so nothing fires) | `docs/design/shotgun.md` §7.1 |
| "This shot went into the drive" — the **filter** | **the weapon**: `SafetyArc.isForbidden(aim, line, CONFIG.SAFETY_ARC_HALF_DEG)`, 45°, unchanged | `src/server/Weapon/SafetyArc.luau` |
| "…and it endangered somebody" — the **verdict** | **the Match**: `Penalty.judge` (§8.3) | this design |
| The punishment | **the Match**, never the weapon (`docs/design/shotgun.md` §1.2: "Never freeze, tie, teleport, score or team a player") | §8.4 |

**One change to the weapon, and it earns its place.** `SafetyViolated` gains a fourth argument:

```luau
Weapon.SafetyViolated: RBXScriptSignal   -- (player: Player, aim: Vector3, muzzle: Vector3, stopAt: number)
```

`stopAt` is the distance from the muzzle to the nearest impact of that shot, or `RANGE_STUDS[ammo]`
when nothing was hit. Without it, a shooter who cleanly kills a boar 30 studs away is tied because a
driver stood 80 studs behind it, in line — the pellets never got near him. Karen would report that as
the game being broken, and she would be right. The weapon already has both numbers at the fire site
(`reports` carry `nearest`), so this is one extra argument at one existing `safetySignal:Fire` call and
nothing else. No listener exists today, so nothing breaks.

**Known gap, stated rather than hidden.** The 45° filter is measured from the line's normal, so a
shooter who has wandered far off the post line can endanger a driver at an angle outside the cone and
the violation is never published. `SAFETY_ARC_HALF_DEG` is the dial (raise it toward 90 to make the
filter near-unconditional); the v1 default stays 45 because shooters who stay on their posts — which
the drive tells them to do — are fully covered.

### 8.3 `Penalty.judge` — pure

```luau
export type Shot = { userId: number, muzzle: Vector3, aim: Vector3, stopAt: number, at: number }
export type DriverPos = { userId: number, position: Vector3 }

Penalty.judge(shot: Shot, drivers: { DriverPos }, config): (boolean, string?)
	-- true only when SOME driver d satisfies all four:
	--   t = (d.position - shot.muzzle):Dot(shot.aim)     -- aim is unit
	--   t > 0                                            -- in front of the muzzle
	--   t <= math.min(shot.stopAt, config.SAFETY_RANGE_STUDS)
	--   ((d.position - shot.muzzle) - shot.aim * t).Magnitude <= config.SAFETY_MISS_STUDS
	-- reason: "driver-in-line"
```

The owner calls it only when the phase is `Running`, the shooter is not already tied, and
`now - driveStartedAt >= SAFETY_GRACE_SECONDS`. Those are three separate questions, answered in the
owner, and `judge` answers exactly one.

A driver is **never** punished for shooting at a shooter in v1: with `DRIVERS_MAY_SHOOT = false` they
carry no gun, and when Karen turns it on the same rule applies to them unchanged (they are checked
against the same driver list, which excludes themselves). No exception, stated so nobody adds one.

### 8.4 "Tied to a tree" — what it actually does

`Match.Body.tie(player, tree)`, the sole writer of every property below:

1. `humanoid.WalkSpeed = 0`, `humanoid.JumpHeight = 0` (and `JumpPower = 0` for
   `UseJumpPower = true` places). The stock `PlayerModule` writes `Humanoid:Move`, never `WalkSpeed`,
   so there is no second writer — `docs/design/camera.md` §6.3 records the same boundary for the
   camera.
2. `character:PivotTo(treeCFrame * TIE_OFFSET)` — put next to the tree, facing it.
3. `root.Anchored = true` — the belt to `WalkSpeed`'s braces, so a physics shove from a team-mate
   cannot drag a tied player around. Unset on release.
4. One rope `Part` in `Workspace.DriveMarkers` (§6.4).
5. `Weapon.refreshArming(player)` → the policy now says no, so the Tool is revoked. A tied player
   holding a gun they cannot aim is a worse joke than a tied player with no gun.
6. One `MatchEvent` broadcast: everybody sees who was tied and why. The comedy is the point, and it is
   also the teaching mechanism.

Released at the end of the drive (`Running → Scoring`, effect `release`), and on leaving, and on
`Match.forget`. `TIE_UNTIL_DRIVE_END = true` is Karen's rule as written; `TIE_SECONDS` exists in the
config and is used only when that flag is false.

The tree is the nearest `DrivenHunt.Tree` to the offender, falling back to the nearest
`DrivenHunt.ShooterPost` when no tree is tagged, falling back to **not tying at all** and counting
`stats().tiesWithoutAnchor` when neither exists. It never teleports a player to the origin, which is
what a nil anchor would silently do.

### 8.5 Arming: the Match answers, the weapon still decides and still writes

Two functions are added to `src/server/Weapon/init.luau`:

```luau
Weapon.setArmingPolicy(policy: ((Player) -> boolean)?): ()   -- nil restores Shotgun.CONFIG.shouldArm
Weapon.refreshArming(player: Player): ()                     -- re-evaluate now: grant or revoke
```

`watchPlayer`'s `onCharacter` (`src/server/Weapon/init.luau`) calls the injected policy instead of
`CONFIG.shouldArm` when one is set. That is the third injected provider on this owner, beside
`Weapon.setCast` and `Weapon.setDriveLineProvider` — the established idiom, not a new mechanism.

The Match supplies:

```luau
function Match.mayCarryWeapon(player: Player): boolean
	-- true iff: the player's team is Shooters, or (Drivers and CONFIG.DRIVERS_MAY_SHOOT)
	--           AND the player is not tied
	--           AND the phase is Assigning, Running or Scoring (never Waiting)
end
```

**Why not edit `Shotgun.CONFIG.shouldArm` to read `player.Team`,** which is what
`docs/design/shotgun.md` §11 anticipated: `Shotgun.CONFIG` is **deep-frozen and shared with every
client**, and `DRIVERS_MAY_SHOOT` is a drive number the brief requires to live in the drive's one
config. Putting a match rule in the client-visible weapon config would either duplicate that number or
move it out of the Match. `shouldArm` stays as the default for a server with no Match — which is
exactly what `tests/server/weapon_*.spec.luau` are, so **Task 24's specs are untouched**.

---

## 9. Public interface

Types are Luau annotations. `luau-lsp analyze` is not in CI (`TASKS.md` row 3), so they are
documentation plus editor checking, not a gate — the status `docs/design/boar-ai.md` §4 records.

### 9.1 The wire — `ReplicatedStorage.Drive`

```luau
export type TeamName = "Drivers" | "Shooters"
export type PhaseName = "Waiting" | "Assigning" | "Running" | "Scoring"

export type ScoreRow = {            -- dense arrays only, no holes, no mixed keys
	userId: number, name: string, team: TeamName?, points: number,
	kills: number, assists: number, pushes: number, violations: number, left: boolean,
}

export type MatchSnapshot = {
	phase: PhaseName,
	phaseEndsAt: number,            -- SERVER TIME (Workspace:GetServerTimeNow), not a duration
	driveNumber: number,
	boarsReleased: number, boarsLeft: number,
	waitingFor: { string },         -- why it is Waiting: "players", or the missing tag names
	rows: { ScoreRow },             -- sorted; every participant, including `left` ones
	tied: { number },               -- userIds currently tied
}

export type FeedEntry = {
	kind: "kill" | "escape" | "violation" | "phase" | "join" | "leave",
	userId: number?, name: string?, zone: string?, points: number?, at: number,
}

Drive.CONFIG            -- layout and colours for the Hud ONLY (§3.4); deep-frozen
Drive.deepFreeze        -- re-exported from ReplicatedStorage.Shotgun; NOT a second copy
Drive.remotes(): { MatchState: RemoteEvent, MatchEvent: RemoteEvent }
```

**Two remotes, both server→client, and nothing inbound.**

| Remote | Direction | Payload | Rate |
|---|---|---|---|
| `MatchState` | `FireAllClients` | `MatchSnapshot` | on change, at most 1 per `STATE_MIN_INTERVAL = 0.25 s`, plus a heartbeat every `STATE_HEARTBEAT = 5 s` |
| `MatchEvent` | `FireAllClients` | `FeedEntry` | one per discrete event |

**There is no client→server remote in this system**, so its inbound exploit surface is zero. Written
down so a later "vote to skip" or "ready up" button does not quietly add one without a design.

**The timer is a server timestamp, not a countdown.** `phaseEndsAt` is
`Workspace:GetServerTimeNow()`-based, and the Hud renders `phaseEndsAt - workspace:GetServerTimeNow()`
every frame locally. A 600-second countdown pushed as a duration drifts, and pushing it every second is
600 broadcasts nobody needs. **This is not `os.clock()`, `os.time()` or `tick()`** — `os.clock` is
meaningless across the wire, which is the same trap `docs/design/shotgun.md` §5.1 hit with `busyFor`.
The **server's own logic** keeps using `os.clock()` through the injected `world.now`, and the
snapshot is the only place server time appears. One conversion, one place.

`Remotes.model.json`, in full, so nothing is guessed (it mirrors
`src/shared/Shotgun/Remotes.model.json`, which compares green — `TASKS.md` row 24):

```json
{
	"className": "Folder",
	"children": [
		{ "name": "MatchState", "className": "RemoteEvent" },
		{ "name": "MatchEvent", "className": "RemoteEvent" }
	]
}
```

No `properties` and no `attributes`, so there is no typed value to fail the harness.

### 9.2 `ServerScriptService.Match` — the owner

```luau
Match.start(world: World): ()          -- once; asserts it is not started twice
Match.stop(): ()                       -- for specs: disconnects everything, destroys the signals
Match:step(dt: number): ()             -- the whole tick; Heartbeat calls it, a spec drives it
Match.phase(): PhaseName
Match.snapshot(): MatchSnapshot        -- deep-frozen
Match.driveLine(): DriveLine?          -- the provider handed to the weapon
Match.mayCarryWeapon(player: Player): boolean
Match.driverThreats(): { { id: string, position: Vector3 } }   -- handed to Boar.defaultWorld's world
Match.forget(player: Player): ()       -- nothing in this system is keyed by that player afterwards
Match.trackedPlayers(): number         -- the leak assertion reads this
Match.stats()                          -- drives, kills, escapes, ties, releasesDeferred,
                                       --   placementsMissed, emptyTeamDrives, unknownZoneKills,
                                       --   killSignalMissing, tiesWithoutAnchor, broadcasts
Match.PhaseChanged: RBXScriptSignal    -- (from: PhaseName, to: PhaseName, driveNumber: number)
Match.Scored: RBXScriptSignal          -- (award: Award)
Match.Punished: RBXScriptSignal        -- (userId: number, reason: string)
Match.Phase, Match.Roster, Match.Score, Match.Penalty, Match.Markers   -- exported for specs
Match.CONFIG
```

`World` is the injected table `MatchBoot` builds (§3.5): `boars`, `markers`, `weapon`, `now`, plus
optional `players` (defaults to the `Players` service) and `rng`. A spec passes its own for all of
them — which is the whole of §12.4 and §12.6.

Signals are `BindableEvent.Event`, as `Runtime.Despawned` and `Weapon.HitReported` already are, with
the two consequences `docs/design/boar-ai.md` §4 records: payload tables are copied, so no metatables
and no mixed-key tables (`rows` is an array, `tied` an array of numbers, and they are separate fields
for exactly that reason); and under `SignalBehavior = Deferred` a listener does not run inside `Fire`,
so live specs poll.

### 9.3 Client — the replica and the Hud

```luau
-- PlayerScripts.Match
Match.start(): ()
Match.get(): MatchSnapshot?            -- deep-frozen; nil until the first MatchState arrives
Match.Changed: RBXScriptSignal         -- (snapshot)
Match.Feed: RBXScriptSignal            -- (entry: FeedEntry)
Match.secondsLeft(): number            -- max(0, phaseEndsAt - workspace:GetServerTimeNow())
Match.myTeam(): TeamName?              -- read from Players.LocalPlayer.Team, NOT from the snapshot
```

`myTeam` reads `Player.Team` because that is the one representation (§5.1). The snapshot carries team
per row for the scoreboard only.

**The Hud's whole new content**, added to `PlayerGui.HunterHud`, which it already owns:

1. **A drive bar**, top centre: `MM:SS` counting down, the phase name while not `Running`, the team
   badge (`DRIVER` / `SHOOTER`, coloured to the team), and `boarsLeft`.
2. **An event feed**, bottom left: the last `FEED_LINES = 5` entries, each fading after
   `FEED_SECONDS = 8`. `"Karen  BOAR  head  +100"`, `"Mila tied to a tree"`.
3. **A score screen**, a centred panel, `Visible` **iff** `Match.get() ~= nil and phase == "Scoring"
   and Drive.CONFIG.SCOREBOARD_ENABLED`: the drive number, one row per player (`rank, name, team,
   kills, points`), the local player's row highlighted, and a `Next drive in N` line.
4. **A tied banner**, for the local player only while their `userId` is in `snapshot.tied`:
   `"TIED TO A TREE — you fired toward the drive"`.
5. Nothing else. No minimap, no menu, no vote.

All built in code, ASCII only, `Enum.Font.Code`, in the existing `HunterHud` `ScreenGui`
(`IgnoreGuiInset = true`, `ResetOnSpawn = false`) — the same constraints §10 gives and the same reason
`docs/design/shotgun.md` §10 source F gives.

---

## 10. Data on disk

**Everything positioned or coloured is built in code.** No `.rbxm` (banned, `CLAUDE.md`), no typed
property value in JSON (audit-002 must-fix 1 is open, `TASKS.md` row 16: `Vector3`, `CFrame` and
`Color3` fail the harness as "cannot compare"). This is the fourth system to make that choice, after
`TestArena.LAYOUT`, `Boar.CONFIG` and `Camera.Config`.

The **one** file on disk that is data is `src/shared/Drive/Remotes.model.json` (§9.1), which has no
properties and no attributes, exactly like the shotgun's — the precedent that already compares green.

`src/starterpack/` and `src/startergui/` stay empty: StarterPack hands a Tool to *every* player
(`docs/design/shotgun.md` §8), which is the opposite of what teams need, and a `ScreenGui` on disk
would need typed values.

---

## 11. Numeric targets — the one config table

Everything lives in `Match.CONFIG`, deep-frozen, in `src/server/Match/init.luau`. **K** marks Karen's
feel values. **No magic number anywhere else in this system.**

### 11.1 The drive

| Field | Value | K? | Basis |
|---|---|---|---|
| `DRIVE_SECONDS` | 600 | K | Karen: "10-minute drives" (`docs/PROJECT_CONTEXT.md`) |
| `INTERMISSION_SECONDS` | 20 | K | long enough to read the teams and walk to your post |
| `SCORE_SECONDS` | 25 | K | long enough to read a 16-row board |
| `MIN_PLAYERS` | 2 | | Karen and her daughter |
| `MAX_PLAYERS` | 16 | | `docs/PROJECT_CONTEXT.md`, "10-16 players" |
| `ODD_PLAYER_TEAM` | `"Drivers"` | K | with 2 players: 1 driver, 1 shooter |
| `SWAP_TEAMS_EACH_DRIVE` | `true` | K | everybody wants to shoot |
| `DRIVERS_MAY_SHOOT` | **`false`** | K | the brief: "design it as a config switch, default OFF" |
| `END_ON_LAST_BOAR` | `false` | K | a drive is 10 minutes, not "until the boars run out" |
| `PLACE_TIMEOUT` | 5 s | | how long `Body.place` waits for a character before counting a miss |

### 11.2 Boars — §6.3

`BOARS_PER_DRIVE = 6` (K) · `FIRST_RELEASE_SECONDS = 20` (K) · `RELEASE_INTERVAL_SECONDS = 90` (K) ·
`RELEASE_JITTER_SECONDS = 15` (K) · `MAX_ALIVE_BOARS = 4`.

### 11.3 Points — §7.1

The table in §7.1 is the config, field for field.

### 11.4 The safety rule — §8

| Field | Value | K? | Basis |
|---|---|---|---|
| `SAFETY_ENABLED` | `true` | | `false` makes 1.7a a complete drive with 1.7b dark (§0) |
| `SAFETY_MISS_STUDS` | 12 | K | ≈ 3.4 m at 1 stud = 0.28 m. A shot that passes within 3 m of a person is a shot at them |
| `SAFETY_RANGE_STUDS` | 330 | | `Shotgun.CONFIG.RANGE_STUDS.Slug`; past it nothing arrives |
| `SAFETY_GRACE_SECONDS` | 0 | K | no grace: the rule is the rule from the first second |
| `TIE_UNTIL_DRIVE_END` | `true` | K | Karen's rule as written |
| `TIE_SECONDS` | 60 | K | used only when the flag above is false |
| `TIE_OFFSET` | `CFrame.new(0, 0, 2.5)` | | 2.5 studs from the tree, facing it |
| `ROPE_COLOR` / `ROPE_THICKNESS` | `RGB(120, 90, 60)` / 0.2 studs | K | **check on screen**: `Boar.CONFIG.BODY_COLOR` and `Shotgun.CONFIG.HANDLE_COLOR` both read near-black at first try (`TASKS.md` rows 22 and 24) |

### 11.5 The wire — §9.1

`STATE_MIN_INTERVAL = 0.25 s` · `STATE_HEARTBEAT = 5 s` · `FEED_LINES = 5` · `FEED_SECONDS = 8` ·
`MATCH_STEP_HZ = 4` (the owner's Heartbeat accumulator; the phase machine needs no more, and the push
sampler runs at `PUSH_SAMPLE_HZ = 2` inside it).

### 11.6 Performance and correctness targets, each one checkable

| Target | How it is checked |
|---|---|
| `Phase.step` ≤ 20 µs at 16 participants | `match_phase.spec`: 10 000 steps under 200 ms (the method `boar_brain.spec` already uses) |
| `Score.kill` ≤ 10 µs | `match_score.spec`: 10 000 kills under 100 ms |
| A whole 600 s drive simulated in ≤ 50 ms | `match_phase.spec`, simulated `dt` |
| Server raycasts per drive from this system | **0** — nothing here casts (the push sampler is distance only) |
| `MatchState` broadcasts | ≤ 1/s average over a drive; asserted from `stats().broadcasts` in the live spec |
| Per-player tables held after a player leaves | **0** (`Match.trackedPlayers()`, §12.4) |
| Instances created per drive by this system | ≤ `#tied` ropes; `Workspace.DriveMarkers` is empty between drives |
| `|#Drivers − #Shooters|` | ≤ 1 for every n in 2..16 (`match_roster.spec`) |
| Typed-value harness problems from this task | **0** (§10) |
| Zero errors, zero skipped tests | `tests/TestKit.luau` fails the run otherwise |

---

## 12. How it is tested

`tests/server/` → `ServerStorage.Tests`, `tests/client/` → `ReplicatedStorage.ClientTests`
(`CLAUDE.md`, Layout). Specs **write their own numbers rather than importing `CONFIG`** for the
assertion, following `tests/server/test_arena.spec.luau`, so a spec disagreeing with the config is a
finding and not a tautology. Rule 6: these test the player's path, not the harness.

### 12.1 `tests/server/match_phase.spec.luau` — NEW, pure

1. `Waiting` with 1 participant stays `Waiting` for 10 simulated minutes; a second `join` enters
   `Assigning` on the next tick;
2. `Waiting` with enough players but `markers.complete == false` **stays `Waiting`**, and `waitingFor`
   names the missing tags;
3. `Assigning` emits exactly one `assignTeams`, one `placePlayers`, one `clearBoars` and one
   `broadcast`, in that order, **once**;
4. `Assigning` → `Running` after exactly `INTERMISSION_SECONDS` of simulated `dt`, never earlier,
   never twice;
5. the release schedule: over a simulated drive, exactly `BOARS_PER_DRIVE` `spawnBoar` effects, the
   first at `FIRST_RELEASE_SECONDS ± RELEASE_JITTER_SECONDS`, and never more than `MAX_ALIVE_BOARS`
   outstanding;
6. `Running` → `Scoring` after exactly `DRIVE_SECONDS`, emitting `release` and `clearBoars`;
7. `Scoring` → `Assigning` with enough players, `Scoring` → `Waiting` without;
8. **join/leave in every phase** (§4.4), one `it` per cell of that table: the joiner's team, that no
   existing assignment changes, and that a leaver's row survives to the score screen;
9. a `kill` event outside `Running` scores **nothing** and emits no `feed`;
10. `dt = 5` (a server hitch) advances one phase at most, never two — a hitch cannot skip the drive;
11. determinism: two machines with the same seed and the same event sequence produce identical effect
    sequences;
12. 10 000 steps under 200 ms.

### 12.2 `tests/server/match_roster.spec.luau` — NEW, pure

1. every n from 2 to 16: `|#Drivers − #Shooters| ≤ 1`, and every userId appears exactly once;
2. n = 2 gives exactly 1 driver and 1 shooter;
3. odd n puts the extra on `ODD_PLAYER_TEAM`, and flipping that config flips the result;
4. `SWAP_TEAMS_EACH_DRIVE` with `previous`: everybody's team differs from `previous` where the sizes
   allow, and the sizes still balance;
5. the same input in a different order gives the same assignment (sorted by userId);
6. `smallerTeam` with equal counts returns `ODD_PLAYER_TEAM`;
7. no `Random`, no service, no Instance is reachable from this module (read the requires).

### 12.3 `tests/server/match_score.spec.luau` and `match_safety.spec.luau` — NEW, pure

**Score:** every zone's points exactly; `unknown` scored as `body` and counted; an assist at exactly
`ASSIST_MIN_DAMAGE` and none at one point below; the killer never also gets an assist; push credit for
a driver inside `PUSH_RADIUS` inside `PUSH_WINDOW` and none for one outside either; an escape worth
`ESCAPE_WOUNDED`; a violation worth `SAFETY_PENALTY` and points may go negative; `leave` keeps the row
and sets `left`; the leaderboard's full tie-break chain (equal points → kills → firstKillAt → userId);
`kill` never mutates its input board and the result is frozen; 10 000 kills under 100 ms.

**Safety:** a driver exactly on the ray at 50 studs with `stopAt = 100` → violation; the same driver
with `stopAt = 40` → **none** (the pellets stopped in the boar); a driver at 12.0 studs off → violation,
at 12.1 → none; a driver **behind** the muzzle (`t < 0`) → none; no drivers → none; a zero-length `aim`
→ none and no error; two drivers, one qualifying → one violation, not two.

### 12.4 `tests/server/match_live.spec.luau` — NEW, live, with a stub world

One `Match` started with a spec-built world: a fake boar runtime recording `spawn` calls, a fake
marker set, a fake weapon recording `refreshArming`, a fake clock, and stand-in participant records —
the pattern `tests/server/boar_body.spec.luau` already uses (its own folder, its own field, teardown in
`afterAll`). A shortened config (`DRIVE_SECONDS = 3`, `INTERMISSION_SECONDS = 1`,
`SCORE_SECONDS = 1`) so the whole drive takes seconds.

1. a full `Waiting → Assigning → Running → Scoring → Assigning` cycle, with `PhaseChanged` firing
   exactly once per transition (polled — signals may be deferred);
2. the boar runtime was asked to spawn, and **never more than `MAX_ALIVE_BOARS`** were outstanding;
3. `releasesDeferred` increments when the stub runtime reports itself full, and the release is
   retried, not lost;
4. `Match.driveLine()` returns the marker set's line, and `nil` when no line is tagged;
5. `Match.mayCarryWeapon` is true for a shooter, false for a driver, true for a driver with
   `DRIVERS_MAY_SHOOT`, and **false for a tied shooter**;
6. a violation while `Running` ties the player once — a second violation 100 ms later changes nothing
   and fires `Punished` once;
7. `Workspace.DriveMarkers` holds exactly one rope while one player is tied, and **zero** after the
   drive ends;
8. after `Match.forget(player)`, `trackedPlayers()` has dropped by one and nothing in the system holds
   that key;
9. `Match.stop()` leaves no `BindableEvent` and no Heartbeat connection behind (the Task 24 round-1
   blocking finding was a teardown test that could not fail — this one counts instances that **are**
   parented, and destroys them in `afterAll`);
10. `stats().broadcasts` over a simulated drive is under the §11.6 budget.

### 12.5 `tests/server/test_arena.spec.luau` — CHANGED, live, the markers

Added to the existing file, which already checks the plate and the blocks:

1. exactly one `DrivenHunt.DriveLine`, exactly 8 `DrivenHunt.ShooterPost`, ≥ 1 `DrivenHunt.DriverStart`,
   4 `DrivenHunt.BoarSpawn`, ≥ 1 `DrivenHunt.Tree`;
2. **the drive line's normal points toward the drivers**: `line.CFrame.LookVector.Z > 0.99`. This one
   assertion is the difference between the safety rule firing on the right shots and on exactly the
   wrong ones, and it is the cheapest possible check for it;
3. every post's footprint is inside the ground plate, and every post's z is strictly between
   `Boar.CONFIG.field.exitZ` and the driver start's z — so a boar that beats the line still has room
   to leave;
4. the posts are 40 studs apart and sorted stably by X (post 1 is always the same post);
5. `TestArena.build` called twice adds no second set of tags (it is idempotent — its header says so).

### 12.6 The multiplayer test path — `ROADMAP.md` 1.6, answered plainly (rule 6)

**What the harness can do today**, read from `tools/studio_mcp.py`:

- `Studio.set_play` calls StudioMCP's `start_stop_play` with `{"is_start": bool}` and **nothing else** —
  there is no player-count argument anywhere in the file.
- `Studio.query(datamodel, code)` and `Studio.send_input(...)` pass a `datamodel_type` that is only ever
  `"Edit"`, `"Server"` or `"Client"` (`run_test`: `studio.query(side.capitalize(), QUERY_REPORT[side])`;
  `send_input`: `{"datamodel_type": "Client"}`). **There is no index**, so a second client is not
  addressable for a query, for a report, or for input.
- `QUERY_REPORT["client"]` reads `Players.LocalPlayer`'s `TestReport` attribute — singular by
  construction.

**Conclusion, stated plainly rather than designed around: the harness cannot run a 2-player test
today, and this design does not pretend it can.** Studio's "Clients and Servers" local test starts
additional Studio *processes*; whether StudioMCP's `list_roblox_studios` even sees them, and whether a
`datamodel_type` could ever select one, cannot be determined without Studio (§15).

**What this design does instead, and it is the substantive answer to 1.6:**

1. **Every rule is testable with no second client.** `Match.start(world)` takes its participants,
   boars, markers, weapon and clock from the injected world, and `Phase`, `Roster`, `Score` and
   `Penalty` are pure and key by `userId`. §12.1–§12.4 drive 2, 3, 7 and 16 participants with stand-in
   tables, in milliseconds, with no client at all. This is the same trick that makes
   `Weapon.Registry` testable ("it never knows what a `Player` is" — `docs/design/shotgun.md` §5.3)
   and `Boar.Brain` testable with 10 000 ticks.
2. **One real 2-player check is Karen's, and it is a `NEEDS KAREN` item with exact clicks** (§12.8).
3. **One cheap harness probe, reported as an observation and never as a passing assertion.** While a
   2-client local test is running, `python tools/studio_mcp.py state` goes through
   `Studio.__init__`, which calls `list_roblox_studios`. The Builder reports what it printed. If it
   lists two Studios, a future harness change is feasible and worth a task; if it lists one, 1.6's
   automation is closed and `ROADMAP.md` should say so. **This is one command and no code change.**
4. **Queued, not built here** (§14, Director item C): the smallest harness change that *would* make a
   2-player run possible is a player-count argument on `start_stop_play` plus an indexed
   `datamodel_type`. Both are StudioMCP capabilities this session cannot verify, and
   `ROADMAP.md` speed rule 1 freezes tooling. It is the same shape as
   `docs/design/hit-zones.md` §14 item D ("the harness cannot place a character or aim a camera"),
   and the two belong in one harness task.

### 12.7 Client spec — `tests/client/match_client.spec.luau`, NEW

Reaching modules through `Players.LocalPlayer:WaitForChild("PlayerScripts").Match`:

1. `ReplicatedStorage.Drive.Remotes` holds `MatchState` and `MatchEvent` with the right ClassNames;
2. `Match.get()` is a deep-frozen table with exactly the `MatchSnapshot` fields and no others; a write
   to it errors **and so does a write to `get().rows[1]`** (`table.freeze` is shallow — Task 23a note
   (b));
3. `Match.secondsLeft()` is within 0.5 s of `phaseEndsAt - workspace:GetServerTimeNow()`, and is never
   negative;
4. **the visibility assertion, and it is the point of this spec.** When the snapshot's phase is
   `Scoring`: the score panel exists, is `Visible`, **every ancestor up to the DataModel is present and
   `Visible`**, no ancestor has `Transparency == 1`, and the `ScreenGui` is `Enabled`; when the phase
   is `Running` the panel is not `Visible` and the drive bar is. This is what makes "a visibility audit
   ignored parent visibility and certified a blank screen twice" (`docs/PROJECT_CONTEXT.md`)
   impossible to repeat, and it is copied deliberately from
   `docs/design/shotgun.md` §13.2 item 5. **It does not replace the screenshot;**
5. the drive bar's timer text matches `^%d?%d:%d%d$` and the team badge is `DRIVER`, `SHOOTER` or
   empty — never `nil` rendered as text;
6. there is **no** client→server remote in `ReplicatedStorage.Drive.Remotes`, and nothing under
   `src/client/Match/` calls `FireServer` (read the code; §13.2 of the shotgun design records why a
   grep is the only way to prove a negative, and why it is not built here).

**No new input scenario.** The drive consumes no player input, so there is nothing for
`tests/client/input_scenarios.txt` to drive, and adding a scenario that presses keys nothing is bound
to would be evidence of nothing. Said plainly rather than padded (rule 6).

### 12.8 Screenshots (rule 5) — five, inspected by the Builder

`python tools/studio_mcp.py capture <name> [camera x,y,z] [look-at x,y,z]` works during Play
(`TASKS.md` row 7, closed; used in Tasks 17, 18, 22, 24):

1. **The shooter line from behind**, showing all 8 posts and the drive-line marker across the arena —
   does it read as a line you stand on?
2. **The Hud during `Running`**: the timer, the team badge, `boarsLeft`, over grass and over the grey
   plate, legible in both.
3. **The score screen** at the end of a drive, with at least two rows.
4. **A tied player**: standing at a pillar with the rope visible, gun gone. The `ROPE_COLOR` check —
   two colours in this repo have already read near-black on first try.
5. **The event feed** with a kill line and a violation line on screen at once.

Describe what is actually on screen, not what should be. A number is not a verification
(`docs/PROJECT_CONTEXT.md`).

**`NEEDS KAREN`, with the exact clicks** (`CLAUDE.md`, stop rules). The one thing no tool here can do
is play a drive with two people:

> 1. In Studio, **Test** tab → **Clients and Servers** → set **Players: 2** → **Start**.
> 2. In each client window, walk: one as a driver from the start pad, one as a shooter to a post.
> 3. Check, and say which is wrong: teams are announced and equal; the timer counts down from 10:00;
>    boars come from the far end and run past the line; the driver can push one within ~40 studs; the
>    shooter's gun works and the driver's does not; a shot fired at the driver ties the shooter to a
>    tree, visibly, and takes their gun; the score screen appears at 0:00 with both names and sensible
>    points; the next drive swaps the roles.
> 4. Stop, and say whether ten minutes is too long or too short.

### 12.9 Process hazards, named so the task does not stall on them

- **Rojo.** This task adds twelve files to watched folders and needs a branch switch to get them.
  `rojo serve` 7.7.0 panics when watched files vanish, and a large branch switch alone crashed it once
  (`CLAUDE.md`, "Known Rojo 7.7.0 crash"). Stop `rojo serve` before switching; expect a
  **NEEDS KAREN** Connect click.
- **`git mv` of `BoarBoot.server.luau`** (§3.5) is a file disappearing from a watched folder — exactly
  the crash above. Do it with Rojo stopped.
- **Stacked branch.** §0: branch from the hit-zones branch while it is unmerged, and say so in
  `Base:`.

---

## 13. Rows for `GAME_DESIGN.md` — ready to paste

Rule 3 requires the owners table to mirror this file. **Four new rows, one filled row, three amended
rows.**

**One filled row** — replace `| Game state | _unassigned_ | | |` with:

| System | Owner (the only writer) | Location | Research note |
|---|---|---|---|
| **Game state / the drive** (the phase and its deadline, team membership, per-drive scores, the safety penalty, which boars exist during a drive) | `ServerScriptService.Match`, booted once by `ServerScriptService.MatchBoot`, which is **the one composition root of the drive** and the only place a production boar runtime is built. `Phase`, `Roster`, `Score` and `Penalty` are pure and private to it; `Markers` only reads `CollectionService` tags; `Body` is the only writer of player characters, of the `Teams` service and of `Workspace.DriveMarkers`. It writes no boar state, no weapon state, nothing drawn and no camera | `src/server/Match/`, `src/server/MatchBoot.server.luau` | [drive](docs/design/drive.md) |

**Four new rows:**

| System | Owner (the only writer) | Location | Research note |
|---|---|---|---|
| Player character movement and team (`Humanoid.WalkSpeed`/`JumpHeight`, `HumanoidRootPart.Anchored`, the spawn/tie `CFrame`, `Player.Team`, the two `Team` instances) | `ServerScriptService.Match.Body`. Nothing else writes a character's movement or a player's team; the stock `PlayerModule` writes `Humanoid:Move`, never `WalkSpeed` | `src/server/Match/Body.luau` | [drive](docs/design/drive.md) §5.1, §8.4 |
| Tie-up markers (`Workspace.DriveMarkers`, created at run time on the server) | `ServerScriptService.Match.Body`. One rope per tied player and nothing else | `src/server/Match/Body.luau` | [drive](docs/design/drive.md) §6.4 |
| Match client: the snapshot replica and the feed | `PlayerScripts.Match`, booted once by `PlayerScripts.MatchBoot`. The replica has no setter; this system fires no remote outbound and binds no input | `src/client/Match/`, `src/client/MatchBoot.client.luau` | [drive](docs/design/drive.md) §9.3 |
| Drive wire contract (`ReplicatedStorage.Drive`: the snapshot and feed types, the Hud's layout numbers, and `Drive.Remotes` holding the two server→client RemoteEvents) | `ReplicatedStorage.Drive`, deep-frozen, no writer. The **rule** numbers stay in `Match.CONFIG` on the server and are never replicated | `src/shared/Drive/` | [drive](docs/design/drive.md) §3.4 |

**Three amended rows** (append to the existing owner cell; do not add a new row):

- **World geometry / test arena:** "… Since Milestone 1.7 it also places and tags the drive's gameplay
  markers — `DrivenHunt.ShooterPost` (8), `DrivenHunt.DriveLine` (exactly one, its `LookVector`
  pointing toward the drivers), `DrivenHunt.DriverStart`, `DrivenHunt.BoarSpawn` and
  `DrivenHunt.Tree` — which `ServerScriptService.Match.Markers` reads and never writes
  ([drive design](docs/design/drive.md) §6.1)."
- **Boar AI:** "… **When** a boar exists is the drive's decision from Milestone 1.7:
  `ServerScriptService.Match` calls `runtime:spawn(position)` and reads the handles, and writes no
  boar state. The production runtime and the `Weapon.HitReported` wiring moved from the archived
  `BoarBoot` into `MatchBoot` ([drive design](docs/design/drive.md) §3.5)."
- **Weapon:** "… Since Milestone 1.7 the drive injects two things and writes nothing:
  `Weapon.setDriveLineProvider(Match.driveLine)` and `Weapon.setArmingPolicy(Match.mayCarryWeapon)`.
  `Weapon.SafetyViolated` carries `(player, aim, muzzle, stopAt)`; the weapon publishes the violation
  and never punishes ([drive design](docs/design/drive.md) §8)."

**Amend the `UI / anything drawn` row** by appending: "… It also draws the drive bar, the event feed,
the tied banner and the score screen, reading `PlayerScripts.Match` and never being called by it
([drive design](docs/design/drive.md) §9.3)."

`Input` stays `_unassigned_` as a system: this design binds **no** input at all, and reserves no
prefix.

---

## 14. Open decisions — none of them blocks building

Every one has a default written into `Match.CONFIG` or into this document, so the Builder can build,
test and report without an answer. They are things to overrule on purpose rather than by accident.

### Karen (feel) — the "check this" list for the first two-player drive (`ROADMAP.md` speed rule 8)

1. **Is ten minutes right?** `DRIVE_SECONDS = 600`, and with 2 players and 6 boars it may be long.
   One number.
2. **Should drivers score?** Default **yes**, `PUSH = 25` for being within 60 studs of a boar that
   dies within 20 s. `PUSH = 0` switches it off entirely and makes driving a purely supporting role.
3. **Are the points right?** head 100 / chest 80 / body 50 / legs 30. Is a head shot worth more than
   three leg kills?
4. **Is "tied until the drive ends" too harsh, or not harsh enough?** `TIE_UNTIL_DRIVE_END = true` is
   your rule as written; `TIE_SECONDS = 60` is the softer version, one flag away. The comedy is in the
   rope and the announcement, not in the length.
5. **Is the safety rule fair?** It fires only when a driver was genuinely in the shot's path within 12
   studs and nearer than whatever the pellets hit. If you get tied for a shot that felt safe, say what
   you were looking at — `SAFETY_MISS_STUDS` is the dial.
6. **Do the teams swap between drives?** Default **yes**. If you would rather keep the same role for a
   session, one flag.
7. **Should a drive end early when all six boars are dead or gone?** Default **no**
   (`END_ON_LAST_BOAR = false`).
8. **Is 8 posts at 40-stud spacing the right line** for 2 players, and does standing on a post feel
   like a place to be?

### Director (scope)

- **A. Split 1.7 into 1.7a (the drive runs) and 1.7b (safety + score screen)** — §0. Default:
  **split**, with `SAFETY_ENABLED` and `SCOREBOARD_ENABLED` as the switches. My recommendation, because
  the penalty is the part Karen has to feel.
- **B. Archiving `BoarBoot.server.luau` into `MatchBoot`** (§3.5). Default: **do it** — one place where
  a production boar exists. The alternative is a singleton accessor on `Boar`, which is a global. If
  the Director prefers to keep one boot script per system, say so before the build, not during it.
- **C. The harness cannot run 2+ players** (§12.6). Default: **not built here** (tooling freeze,
  `ROADMAP.md` speed rule 1); the probe in §12.6 item 3 costs one command and decides whether a task is
  even possible. It belongs with `docs/design/hit-zones.md` §14 item D in one harness task.
- **D. `DRIVERS_MAY_SHOOT = false`** (Karen, brief). Turning it on is one boolean and no code: the
  arming policy already reads it, and the safety rule already applies to drivers unchanged.
- **E. Points for the team, as well as the individual.** Not in v1 — the brief says individual points.
  The board has `team` on every row, so a team total is a sum at the render site whenever it is wanted.
- **F. What happens with 1 player.** Default: `MIN_PLAYERS = 2`, so a single player sits in `Waiting`
  and the Hud says so. A solo practice mode is a decision, not an oversight.
- **G. Carcasses at the score screen.** Default: cleared at the end of `Running`. This answers
  `docs/design/hit-zones.md` §14 item B, which left it to 1.7.
- **H. A round-end sound or a horn.** Default: **none** — there is no audio owner, and inventing one
  inside the Hud would make the UI owner an audio owner by accident. It is its own small design.

---

## 15. What I could not verify (rule 8)

- **The hit-zones branch.** `Runtime.Downed`, `KillRecord`, `WoundState`, `contributors`,
  `killingZone` and the extended `Despawned` do not exist at this commit
  (`src/server/Boar/init.luau` has `takeHit` and `Hit` only). Everything §7.4 says about them is read
  from `docs/design/hit-zones.md` §8, not from code. §0 makes checking it the Builder's first act, and
  §7.4 makes a mismatch a counted, warned degradation rather than a crash.
- **The camera branch (Task 26).** I could not read it. `src/client/Hud/init.luau` as merged has a
  crosshair and one readout; `docs/design/camera.md` §3.5 says that file gains a `Camera.Changed`
  subscription. Expect to merge inside the Hud.
- **Anything requiring Roblox Studio.** No Studio in this session (`.agent-evidence/INDEX.md`). Every
  claim about `Player:LoadCharacter` timing, `PivotTo` on a freshly loaded character, anchoring a
  `HumanoidRootPart` while a `Humanoid` is in `Running` state, `Team` assignment ordering,
  `Workspace:GetServerTimeNow()`'s synchronisation error, and `CollectionService` tag lookup cost is
  from documentation and from the code already in this repo, not observed. §12.4 and §12.5 are the
  checks.
- **Whether StudioMCP can address a second client** (§12.6). `tools/studio_mcp.py` only ever passes
  `"Edit"`, `"Server"` or `"Client"`, and `start_stop_play` only ever gets `is_start` — those two facts
  are read from the file and are certain. What StudioMCP *would* accept is not, because its tool schema
  is not in this repo. §12.6 item 3 is the one-command probe that settles it.
- **Every number in §11 is a first guess.** None has been played. They are arithmetic against
  `Boar.CONFIG.SPRINT_SPEED`, the arena span and the drive length, not measurement, and §14's Karen
  list is where they get their real values.
- **The external sources' URLs, licences and maintenance status.** No network this session. A, B and C
  are first-party Roblox creator documentation (creator-docs is CC BY 4.0) and the APIs ship with the
  engine; D is a category of source (hunting-association driven-hunt safety guidance) rather than one
  fixed page, and only facts are taken; E's archived status is from my own knowledge. **The Builder
  confirms all of them in the research note before relying on any** (rule 1; `docs/research/` is the
  Builder's file, not mine), and if D cannot be confirmed the rule does not change — §8.1's geometry is
  derived here, and D is cited only for the vocabulary.
- **`Workspace:GetServerTimeNow()` vs. a Studio Play session.** In a local Play session client and
  server share a process, so a drift bug would not show there and would first appear on a live server.
  §12.7 item 3 asserts the arithmetic, not the synchronisation; the synchronisation is only checkable
  with two real clients, which is §12.8's `NEEDS KAREN`.
- **CI and harness status at this commit.** Lint and build are clean in the evidence
  (`.agent-evidence/lint-selene.txt`, `lint-stylua.txt`, `rojo-build.txt`). No harness or CI output is
  in `.agent-evidence/`.

---

## 16. External sources

Rule 1 and rule 2 — this is where the design borrows, and where it says so. §15 records that I could
not fetch any of them this session; the Builder confirms each URL, licence and maintenance status in
the research note before relying on it.

### A. Roblox `Teams`, `Team` and `Player.Team`
<https://create.roblox.com/docs/reference/engine/classes/Teams> ·
<https://create.roblox.com/docs/reference/engine/classes/Team> ·
<https://create.roblox.com/docs/players/teams> · first-party creator docs (creator-docs is CC BY 4.0);
the API ships with the engine · actively maintained.
**Good:** gives exactly the property this design needs and nothing more — a server-authoritative,
automatically replicated team field on `Player` that a client cannot write, with free player-list
colouring and `SpawnLocation.TeamColor` if it is ever wanted. One representation of team membership,
enforced by the engine rather than by policy, which is the strongest form of rule 3 available.
**Bad:** `Team.AutoAssignable` defaults to `true`, so Roblox will assign players itself unless it is
turned off — a silent second writer of the exact field this system owns, and the single most likely way
to build §5.1 wrong; `Teams` is not a Rojo-owned container, so the two `Team` instances must be created
at run time and are invisible to the harness's file comparison; and `Player.Team` is a reference, so
comparing by name (`player.Team.Name`) is the only form that survives a `Team` being recreated.
**Adopted:** two `Team`s created by `Match.Body` at `start()` with `AutoAssignable = false`, and
`Player.Team` as the one representation of team, compared by name everywhere.

### B. Roblox remote-event state replication and `Workspace:GetServerTimeNow`
<https://create.roblox.com/docs/scripting/events/remote-events-and-callbacks> ·
<https://create.roblox.com/docs/reference/engine/classes/Workspace#GetServerTimeNow> · first-party
(CC BY 4.0) · actively maintained.
**Good:** `GetServerTimeNow` is a clock both sides agree on, which turns a 600-second countdown into
**one** number pushed once per phase instead of 600 broadcasts, and removes the whole class of
"the client's timer disagrees with the server's" bug. `FireAllClients` is the right shape for state
every player sees identically, and the page states flatly that client input is untrusted — which is why
this system has no inbound remote at all.
**Bad:** it supplies no rate limiting and no schema validation; its table-serialisation rules are the
trap behind `docs/design/shotgun.md` §2.3 item 1 (a table that is neither a dense array nor a pure
dictionary does not survive the wire), which is why `rows` and `tied` are separate dense arrays; and
`GetServerTimeNow` is easy to confuse with `os.time`, `tick` and `os.clock`, three of which mean
nothing across the wire.
**Adopted:** two server→client remotes, none inbound; the snapshot pushed on change with a floor and a
heartbeat; `phaseEndsAt` as a `GetServerTimeNow` timestamp with the countdown computed on the client;
every table on the wire dense.

### C. Roblox `CollectionService` tags
<https://create.roblox.com/docs/reference/engine/classes/CollectionService> ·
<https://create.roblox.com/docs/studio/properties#instance-tags> · first-party (CC BY 4.0) · actively
maintained.
**Good:** `GetTagged` answers "give me every post" in one call with no Workspace walk and no naming
convention, and `GetInstanceAddedSignal` means a map generator can place markers after the server
started without this system polling. It decouples the drive from where the map put things, which is
exactly what `ROADMAP.md` Milestone 2 plans for.
**Bad:** a tag is a string with no schema, so a typo yields an empty list and a silently dead rule —
mitigated by `Markers.missing` and by refusing to leave `Waiting` (§6.2); tags are **not** compared by
this repo's harness, unlike attributes (`docs/design/shotgun.md` §10 source E), so the only proof they
exist is a spec, which §12.5 supplies; and whether tags survive a place save and reopen is an open
question this repo has already written down
(`docs/research/2026-09-24-map-generator.md`, per `TASKS.md` row 20) — moot here, because the arena is
built in code on every server start.
**Adopted:** five `DrivenHunt.*` tags placed by `TestArena.build`, read by `Markers.read` into one
frozen table, validated with a named missing-list and a loud refusal to start a drive against an
incomplete map.

### D. Driven-hunt safety practice (Deutscher Jagdverband and equivalent association guidance on *Drückjagd* discipline)
<https://www.jagdverband.de/> · copyrighted web content; **facts and technique taken, no text and no
code** · maintained as public guidance.
**Good:** it is the source of the rule Karen is reproducing, and it says what the offence actually is:
you stand on your assigned post, you do not leave it, and you do not shoot into the drive — where the
drivers are. It also supplies the reason the punishment is social rather than mechanical: on a real
drive the sanction is being sent off the line in front of everyone, which is exactly the comedy Karen
asked for.
**Bad:** qualitative and regionally variable; it gives angles and distances in metres of real
terrain, not studs of a 400-stud arena; and it assumes a hunt leader who can see everything, which a
server cannot.
**Adopted:** the *offence* ("a shot that endangers a driver"), the *post discipline* (a numbered post
per shooter), and the *shape of the sanction* (immediate, public, for the rest of the drive). The
numbers in §11.4 are this design's, compressed to the arena, and are Karen's to retune.

### E. Rodux — named, deliberately **not** adopted
<https://github.com/Roblox/rodux> · Apache-2.0 · Roblox's own Redux port; **archived / no longer
actively developed**, and its documentation site is retired.
**Good:** it is the canonical Roblox answer to "one store, one reducer, one place state changes", which
is precisely this design's shape, and it would give actions, middleware and a change signal for free.
**Bad:** archived, so adopting it now would add a Wally package, a `default.project.json` mapping and a
Connect click (`CLAUDE.md`, Toolchain) for a dependency with no maintainer; its middleware and
`Store:dispatch` lifecycle would own the phase transitions that §4 needs to be *pure and returned*, so
a spec could no longer assert on an effect list; and it brings a second state model into a repo whose
other two systems already use a plain pure reducer.
**Decision:** **the pattern is taken, the package is not** — `Phase.step(state, event, now, config)`
returning a new frozen state plus a list of effects is Redux's reducer with the side effects made
explicit, which is the part Rodux leaves to middleware. Recorded here so it is not re-researched.

### F. Borrowed from inside this repo (rule 2 applies to internal patterns too)
`src/server/Boar/init.luau` and `docs/design/boar-ai.md` §3–§4: the folder module that owns state and
does nothing on `require`, a pure decision module driven by an injected world and exported for specs,
one module that is the only writer of Instances, every number in one `CONFIG`, `Runtime:stats()` as the
cheap way to assert on a live system without a screenshot, and `Runtime:step(dt)` split from
`Runtime:run()` so a spec can drive simulated time.
`src/server/Weapon/init.luau` and `docs/design/shotgun.md` §5.3–§5.4: injected providers
(`setCast`, `setDriveLineProvider`) as the way one owner asks another a question, a pure registry that
"never knows what a `Player` is", `forget(player)` as the named lifecycle, and deep-frozen published
state.
`src/client/Hud/init.luau` and `docs/design/shotgun.md` §3.4: one UI owner, reading published state,
never called by what it reads.
**Adopted whole.** The fourth system in a repo either keeps the conventions or starts eroding them.

**Pattern adopted overall:** a pure reducer returning state plus an explicit effect list (E's shape
without E's package), inside a folder-module owner with an injected world (F); Roblox's own `Team` as
the single representation of team membership, enforced by the engine (A); tag-based world markers so
the map generator can move everything without this system changing (C); two outbound remotes with a
server timestamp instead of a pushed countdown, and nothing inbound (B); and a safety rule whose
*geometry* is the weapon's (already built and tested) and whose *verdict and punishment* are the
drive's (D). Nothing is invented except `Penalty.judge`'s point-to-ray test, which has no external
pattern because it is this game's own mechanic — and whose entire content is a dot product, a clamp and
a magnitude, in one pure function with seven assertions against it in §12.3.
