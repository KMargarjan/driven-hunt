# Design: drive (teams, the 10-minute drive, points, the score screen, the safety penalty, **sounders**)

System: `drive` — the match. One drive = one round: teams, a 10-minute timer, boars released into the
drive, individual points per boar, a score screen, and the comic penalty for shooting toward the
drivers. `ROADMAP.md` steps **1.6** and **1.7**.

**Revision v3, Task 57.** It replaces the v2 document (Task 29, written before 1.7a/1.7b were built) **in
full**, for three reasons, all of them the Director's brief or a delta another design filed against this
file:

1. **`reviews/task-57/BRIEF.md`** (Karen, 2026-09-26): boars come as a **mix of singles and sounders of
   2–5**. That is new §6.6–§6.9, §9.4, §11.7 and the changes to §4, §6.3, §12.
2. **`docs/design/map-generator.md` §19.1 A3**: this file "needs two sections at its next regeneration"
   — the sounder release **and** the outfit rows that design assigns to `Match.Body` (new §5.4) — and
   "its §6.1 marker table still carries the arena's coordinates, which are now three worlds out of
   date" (rewritten §6.1, both worlds).
3. **The v2 numbers and preconditions are stale against the built code.** `MIN_PLAYERS` is 1, not 2;
   `ODD_PLAYER_TEAM` is `"Shooters"`, not `"Drivers"`; `TIE_UNTIL_DRIVE_END` is a flag read, not a
   literal; `SAFETY_BODY_STUDS`, `STAND_HEIGHT_STUDS`, `TIE_GAP_STUDS` and `Match.advanceForTests` exist
   and the v2 document does not mention them; §12.6 said "the harness cannot run a 2-player test", and
   `test2` has been in the merge gate since 2026-09-26. **This document states what is built** and marks
   each supersession where it happens. The v2 text stays in git history at commit `cfc8a72`; if the
   Director wants a file copy, the Builder archives it as `backups/2026-09-27_drive-design-v2.md` with a
   note (rule 7) — no code or behaviour is being removed here.

**Section numbers are load-bearing and are preserved.** `src/server/Match/init.luau`,
`src/server/Match/Markers.luau`, `src/server/Match/Phase.luau`, `src/server/MatchBoot.server.luau`,
`src/server/Boar/init.luau` and `docs/design/map-generator.md` all cite "drive.md section N". Every
number that existed in v2 keeps its section. New material is appended inside the section it belongs to
(§5.4, §6.6–§6.9, §9.4, §11.7).

Architect, 2026-09-26, read-only session: Read, Grep, Glob only. No Studio, no network. Evidence
precomputed in `.agent-evidence/` (`INDEX.md`), commit `cfc8a7278`.

Inputs, in precedence order: `reviews/task-57/BRIEF.md`, the code on this commit, `reviews/task-54/BRIEF.md`
(the Director's decisions on the map), `docs/design/map-generator.md`, `docs/design/feature-flags.md`,
`docs/design/boar-ai.md`, `docs/design/hit-zones.md`, `docs/design/shotgun.md`, `docs/design/camera.md`,
`GAME_DESIGN.md`, `CLAUDE.md`, `docs/PROJECT_CONTEXT.md`.

**Test of this document:** a Builder can build the sounder release from it without asking a question,
and can read the drive as it stands today without opening the v2 file. Every number is here, every owner
is named, every interface is written out, and every cross-system change is in one table (§3.6).

---

## 0. Where the tree actually is, stated first because it decides the work

1. **1.7a and 1.7b are built and merged.** `src/server/Match/` has `init.luau`, `Phase`, `Roster`,
   `Score`, `Penalty`, `Markers`, `Body`; `Runtime.Downed`, `KillRecord` and `Runtime:clear` exist
   (`src/server/Boar/init.luau`, `Runtime:clear`, `Runtime:takeHit`). The v2 §0 preconditions about the
   unmerged hit-zones branch are **spent** and are not carried forward.
2. **The feature-flags system is built and merged** (`src/shared/Flags/init.luau`, `Flags.isOn`,
   `Flags.DEFAULTS` with one row, `TIE_UNTIL_DRIVE_END`). The sounder release therefore **must** be born
   OFF behind a row in that table (§6.9), and merges without a playtest.
3. **The world is still the arena.** `src/shared/Map/init.luau`, `Map.EXPECTED_WORLD = "arena"`. The
   forest-road map of `docs/design/map-generator.md` is designed, partly built and **not switched on**.
   Everything here works in both worlds, and §6.1 gives both marker tables.
4. **`Map.SPAWN_PAD.radius` is 14 in the tree and 30 in the map design.** `src/shared/Map/init.luau`,
   `Map.SPAWN_PAD` = `{ radius = 14, blend = 40, tolerance = 0.75 }`;
   `docs/design/map-generator.md` §4.1 and §15.1 declare `radius = 30` as a **change** for a sounder,
   which no committed task has built. The brief's "spawn pads radius 30" is therefore the *map design's
   promise*, not the code. **This design never writes 30 anywhere.** A sounder's spread is clamped
   against whatever the contract says at run time (§6.6, §9.4), so it is correct at 14 today and at 30
   after the map task lands, with no change here. Flagged for the Director as item **I** in §14.
5. **Recommended task split** (Director item **J**). The work divides at a line that leaves no
   half-owned system:
   - **57a — the sounder exists (`src/server/Boar/`)**: `Runtime:spawnSounder`, sounder state and the
     Brain's formation steering, with **no production caller**. Dark by construction, so it needs no
     flag, and its evidence is pure specs plus one live 5-boar spec.
   - **57b — the drive releases sounders (`src/server/Match/`, `src/shared/Flags/`)**: the
     `BOAR_SOUNDERS` row, the sizes and the pacing in `Phase`, `applySpawnSounder`, `MAX_ALIVE_BOARS`.
   It is buildable as one task, and it is ~11 changed files if it is. My recommendation: **split**,
   because a leader-follower bug and a release-schedule bug look identical from the outside, and 57a's
   live spec is the only thing that can tell them apart.

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

1. **One drive = one round.** 10 minutes, then a score screen, then the next drive, for as long as
   there are players.
2. **Two teams of equal size.** DRIVERS push boar toward SHOOTERS on posts along a line. v1: drivers on
   foot, no dogs. **`DRIVERS_MAY_SHOOT` is a config switch, default OFF.**
3. **Individual points per boar,** by the zone of the killing shot. Wounds and escapes count for less or
   nothing.
4. **The safety rule:** a shooter who fires at a driver is tied to a tree until the drive ends, visibly.
   Players are not damageable (`docs/design/shotgun.md` §15 item C), so this rule, not damage, is the
   answer to shooting at people.
5. **Posts, the line, spawns and tie trees are found by `CollectionService` tags,** so the map generator
   places them without this system changing.
6. **Several boars per drive, released over the drive's length, and since this revision they come as a
   MIX of singles and sounders of 2–5** (`reviews/task-57/BRIEF.md`). The drive decides *when* and *how
   many*; the boar's own owner decides everything else about them.
7. **10–16 players, and it must work with 1** (the harness's single Play client) **and with 2** (Karen
   and her daughter).
8. **Every number in one config table,** Karen's feel values marked **K**.
9. **The sounder merges OFF**, behind one flag, and both of its states are testable while the flag sits
   at one of them (`docs/design/feature-flags.md` §13.3).

### 1.2 Must not

Each row is a named failure of the previous project (`docs/PROJECT_CONTEXT.md`) or a boundary an existing
design drew, written as a prohibition. The last four rows are new in this revision.

| Prohibition | Why | Whose job instead |
|---|---|---|
| Never write `workspace.CurrentCamera`, `UserInputService.MouseBehavior`/`.MouseIconEnabled`, or `Mouse.Icon` | "Three scripts set the mouse cursor"; `docs/design/camera.md` §3.1/§3.3 names `Camera.Rig` and `Camera.Cursor` as sole writers | `PlayerScripts.Camera` |
| Never create a `ScreenGui`, `Frame` or `TextLabel` outside `PlayerScripts.Hud`, and never a `BillboardGui`/`SurfaceGui` anywhere | "One predicate answered two unrelated questions" | `PlayerScripts.Hud` (§9.3) |
| Never write a boar's state, position, attributes or Instances | `Boar.Body` is "the only writer of a boar's Instances" (`src/server/Boar/Body.luau` header) | `ServerScriptService.Boar`. The Match **calls** `runtime:spawn`/`spawnSounder`/`clear` and **reads** handles |
| Never hold a damage number, a zone→reaction rule or a health value | `docs/design/hit-zones.md` §1.2 | `Boar.Wound` |
| Never decide, at fire time, where a shot went | only the weapon has the muzzle direction | `Weapon.SafetyArc`, publishing only (§8.2) |
| Never write a player's `WeaponState`, fire a weapon remote, or create/destroy a `Tool` | `ServerScriptService.Weapon` is the sole writer (`docs/design/shotgun.md` §3.1) | the Match injects a policy and asks for re-evaluation (§8.5) |
| Never write `Workspace.TestArena`, `Workspace.DrivenHuntMap` or anything in them | `TestArena` and `ServerStorage.MapGen` are their only writers (`GAME_DESIGN.md`) | those owners; the drive only **reads tags** (§6.2) |
| Never write a `.rbxm`, and never a typed property value (`Vector3`, `CFrame`, `Color3`) into `.model.json`/`.meta.json` | `.rbxm` is banned; typed values fail the harness as "cannot compare" (`TASKS.md` row 16, open) | §10: everything positioned or coloured is built in code |
| Never accept a client→server remote in this system | the drive takes no player input, so it has **zero** inbound exploit surface (§9.1) | — |
| Never damage, kill or ragdoll a player | the penalty is comic, not lethal | §8.4 freezes and moves, nothing else |
| Never move a player between teams **during** a drive | a mid-drive swap silently rewrites who may shoot | §5.3; a joiner takes the smaller team once |
| Never hold a `Player` instance in a table that outlives the player | the leak `TASKS.md` row 23a(c) named | per-player state is keyed by `UserId`; `Match.forget` empties it |
| Never add a Wally package or change `default.project.json` | pinned against the commit; a project-file change costs Karen a Connect click | nothing here needs either |
| **NEW — the drive never writes, reads or names sounder membership.** It says one number, `size`, and nothing else | two writers of one fact is this project's named killer. Who leads, who follows and who left is **boar** state, and it changes 60 times a second | `ServerScriptService.Boar` (§6.7, §9.4) |
| **NEW — `Boar.Brain` never holds a reference to another boar's entry, Brain, handle or Instance.** It receives positions and velocities as plain values in its `Observation` | the Brain is pure and testable only because everything it knows arrives as data (`src/server/Boar/Brain.luau` header) | the Runtime assembles `obs.sounder` once per step (§6.7) |
| **NEW — no collision group, and no `PhysicsService` call, in this task** | collision groups are global place state with no owner row in `GAME_DESIGN.md`; introducing one to stop five boars jostling would be a new system invented inside a behaviour task | separation steering (§6.7) plus the existing stuck sidestep. If the live spec or the screenshot shows grinding, a collision group is its own small design (§14 item K) |
| **NEW — neither the drive nor the boar queries hedges, gates, trunks or brush** | there is nothing to query: `Markers.MarkerSet` has five kinds and `Map.TAGS` five strings, none of them a gate. A map-geometry read would couple the AI to the generator | the boar's existing `world.probe` raycast, which already excludes the boar folder (`Boar.defaultWorld`, `probe`), and the leader's navmesh route (§6.7) |

**One predicate answers one question.** `Match.phase()` says which phase the drive is in. It does not say
whether a player may shoot, whether the scoreboard is visible, whether a boar may be released, or whether
a violation is punishable — four questions, answered in §4.1, §8.5, §6.3 and §8.3.

---

## 2. The shape of a drive, in one picture — in both worlds

**Today (`Map.EXPECTED_WORLD = "arena"`, 400 × 400, `src/server/TestArena.luau`, `LAYOUT`):**

```
  z = -190  exitZ ............ a boar past the line runs 40 more studs and is GONE ("escaped")
  z = -150  ################  8 posts, DrivenHunt.ShooterPost, x = -140..+140 step 40
                              one DrivenHunt.DriveLine part (320 x 1 x 1), LookVector -> +Z
  z =  -40  PillarMid                       (corner pillars = the 4 DrivenHunt.Tree)
  z = +120  *   *   *   *      DrivenHunt.BoarSpawn x4 (6 x 1 x 6), x = -120, -40, +40, +120
  z = +170  ==============     DrivenHunt.DriverStart (120 x 1 x 12)
```

**At the M2.5 switch (`docs/design/map-generator.md` §15.1), 2048 × 2048, the line on a forest road:**

```
  z = -820  exitZ ............ 120 studs past the road: the boar crosses and is gone
  z = -745  12 DrivenHunt.Tree in the far wood, span 1120
  z = -700  ==== THE FOREST ROAD, half-width 8, verge 24 ==== 8 posts, spacing 160 (45 m)
                              DriveLine 1240 x 1 x 1 at z = -700, LookVector -> +Z
  z = +300  ---- hedge bank across the corridor, 2 gates, 96 studs each ----
  z = +600  *      *      *      *   BoarSpawn x4, x = -450, -150, +150, +450, pad radius = Map.SPAWN_PAD
  z = +700  ================= DriverStart 1120 x 1 x 20, on the assembly track
```

Two facts about the second picture that the sounder design depends on, both from
`docs/design/map-generator.md` §15.1:

- **A gate is 96 studs wide.** A five-boar wedge is ~18 studs wide (§11.7). **The formation does not have
  to change to get through a gate** — it has to change for trunks and brush, which is what the probe
  latch in §6.7 is for. This is the brief's "how do followers keep formation through gates in hedges",
  answered by measurement rather than by machinery.
- **The road is the flattest, most open ground in the corridor** (16 studs wide, 24-stud verges, dead
  level at `GROUND_Y`), and the line sits on it. The sounder is therefore at its **widest** exactly where
  Karen's reference photograph looks: crossing the road in front of the posts. Nothing special-cases the
  road; it is ground.

---

## 3. Ownership

Rule 3: exactly one writer per system, named here, mirrored into `GAME_DESIGN.md` (§13).

### 3.1 The owner

**`ServerScriptService.Match`** — disk `src/server/Match/init.luau`, booted once by
`src/server/MatchBoot.server.luau`.

Sole writer of: the phase and its deadline, team membership, every player's per-drive score and penalty
state, **when and how big a release is**, the two outbound RemoteEvents, and `Workspace.DriveMarkers`.

It is a **ModuleScript** (folder with `init.luau`). **Nothing happens on `require`** — only
`Match.start(world)` begins production. That is what makes every spec in §12 possible.

### 3.2 The server modules (as built)

| Module | Is | Never |
|---|---|---|
| `src/server/Match/init.luau` → `ServerScriptService.Match` | **the owner**: `CONFIG`, the phase, the per-`UserId` tables (`names`, `tied`, `pushCredit`, `characterWatch`), the Heartbeat accumulator, `Match:step(dt)`, the two remotes, `PhaseChanged`/`Scored`/`Punished`, `stats()`, and the gated test clock `advanceForTests` | decides a rule itself; touches a boar, a weapon or a drawn thing |
| `Phase.luau` | **pure**: `(state, event, now, config) -> (state, { Effect })`. The whole match machine **and the release schedule**, including sounder sizes (§6.6) | touches Instances, services, clocks, `Player`, `Random` |
| `Roster.luau` | **pure**: `assign`, `smallerTeam`, `counts`. Keys by `userId`; never knows what a `Player` is | as above |
| `Score.luau` | **pure**: `new`, `join`, `setTeam`, `kill`, `escape`, `violation`, `leave`, `leaderboard` | as above |
| `Penalty.luau` | **pure**: `judge(shot, drivers, config)`, `expired(tiedAt, now, config)`, `REASON` | as above |
| `Markers.luau` | **read-only**: reads the five `DrivenHunt.*` tags and `Map.SPAWN_PAD`, returns one frozen `MarkerSet` with `complete`/`missing` | writes anything, anywhere |
| `Body.luau` | **the only writer of player characters, of the `Teams` service and of `Workspace.DriveMarkers`**: `ensureTeams`, `setTeam`, `teamOf`, `placementFor`, `place`, `tie`, `untie`, `forget`, `anchorFor`, and (M2.8d) `dressFor`/`dress` (§5.4) | decides anything; reads the phase |
| `src/server/MatchBoot.server.luau` | nothing. **The one composition root of the drive** (§3.5) | owns state |

`Phase`, `Roster`, `Score`, `Penalty`, `Markers` and `Body` are exported as `Match.Phase`, `Match.Roster`…
for specs, exactly as `Boar.Brain` is.

### 3.3 The client modules — unchanged by this revision

| Module | Sole writer of | Never touches |
|---|---|---|
| `src/client/Match/init.luau` → `PlayerScripts.Match` | the client's **replica** of the snapshot. Deep-frozen, **no setter**: it subscribes to `MatchState.OnClientEvent` itself | anything drawn, the camera, the weapon, any outbound remote |
| `src/client/Hud/init.luau` → `PlayerScripts.Hud` | the drive bar, the event feed, the tied banner, the score screen | match state, weapon state, the camera |

**This revision changes no client file and adds no client spec**, because `MatchSnapshot.boarsReleased`
and `boarsLeft` already count **animals** and keep counting animals when a release is a sounder (§9.1).
Said plainly so nobody adds a "sounders left" field nothing asked for.

### 3.4 The one shared, frozen table

**`ReplicatedStorage.Drive`** — `src/shared/Drive/init.luau` plus `Remotes.model.json`. Wire types, the
Hud's layout numbers, `Drive.deepFreeze` (**required from `Shotgun`, not copied**: `table.freeze` is
shallow and this repo has paid for that once), `Drive.remotes()`.

**The rule numbers stay on the server.** `Match.CONFIG` is not replicated: a client that knows the safety
numbers can dodge the rule by eye, and a client that knows the sounder weights can predict the drive.
`Drive.CONFIG` holds layout and colours only. Two tables, disjoint facts.

### 3.5 One composition root, and it is where the boar meets the drive

`src/server/MatchBoot.server.luau`, as built: the arena assertion, `Boar.defaultWorld()`, the closure-trap
line `world.threats = Match.driverThreats` (§6.5), `Boar.newRuntime(world)`, `runtime:run()`, the
`Weapon.HitReported` → `runtime:takeHit` wiring, `runtime.Downed` → `Weapon.markHit`,
`Weapon.setArmingPolicy(Match.mayCarryWeapon)`, `Weapon.setDriveLineProvider(Match.driveLine)`, then
`Match.start({ boars = runtime, weapon = Weapon, now = os.clock })`.

`BoarBoot.server.luau` is archived at `backups/2026-09-25_boarboot.server.luau.txt` with a note (rule 7).

**This revision adds nothing to `MatchBoot`.** The drive asks the runtime for its own ceiling through the
`boars` handle it already holds (`Runtime:capacity()`, `Runtime:count()`, §9.4), so no new injected field
and no second place that knows both systems.

### 3.6 Every file that changes in this revision, in one table

Rule 8: the whole blast radius, so nothing is discovered at merge time. **57a** and **57b** are the split
of §0 item 5.

| File | Change | Task | Owner of it |
|---|---|---|---|
| `src/server/Boar/init.luau` | `CONFIG.SOUNDER` (§11.7); `_sounders`; `Runtime:spawnSounder`, `sounders`, `sounderOf`, `capacity`, `count`; per-step sounder bookkeeping and the `obs.sounder` assembly in `Runtime:step`; the scatter latch in `takeHit`; five new `stats()` counters | 57a | `ServerScriptService.Boar` |
| `src/server/Boar/Brain.luau` | formation steering: `_sounderDirection`, the column latch, the follower speed rule, the leader-panic transition, `pathRequest` suppression for followers | 57a | `ServerScriptService.Boar` |
| `tests/server/boar_sounder.spec.luau` | **NEW**, pure (§12.7) | 57a | — |
| `tests/server/boar_body.spec.luau` | **CHANGED**: one live `describe` with a real sounder of five (§12.8) | 57a | — |
| `tests/server/boar_brain.spec.luau` | **CHANGED**: one regression case — with `obs.sounder == nil` the intents are identical to today's | 57a | — |
| `src/shared/Flags/init.luau` | **one row**, `BOAR_SOUNDERS`, `default = false` (§6.9) | 57b | the Builder, in git |
| `src/server/Match/init.luau` | `CONFIG.SOUNDER` block; `MAX_ALIVE_BOARS` 4 → 6; `applySpawnBoar` → `applySpawnSounder`; `boarEntries`/`boarCapacity` filled on every dispatch; three new `stats()` counters | 57b | `ServerScriptService.Match` |
| `src/server/Match/Phase.luau` | `releasesDone` → `boarsReleased` + `soundersReleased`; `Phase.sounderSize`; `Phase.releaseGap`; `Phase.unitHash`; `maybeRelease` emits `spawnSounder { position, size }`; `Phase.releaseFailed(state, now, size)` | 57b | `ServerScriptService.Match` |
| `src/server/Match/Markers.luau` | one field: `spawnRadius = Map.SPAWN_PAD.radius` | 57b | `ServerScriptService.Match` |
| `tests/server/match_phase.spec.luau` | **CHANGED**: the flag-OFF identity proof, sizes, pacing, hold-back (§12.1) | 57b | — |
| `tests/server/match_live.spec.luau` | **CHANGED**: the cross-system invariants (§12.4 items 11–13) | 57b | — |
| `tests/server/flags.spec.luau` | **CHANGED**: one wiring assertion, mirroring case 11 | 57b | — |
| `GAME_DESIGN.md` | two amended owner rows (§13) | 57b | the Builder |
| `docs/research/2026-09-25-drive.md` | the sounder sources and the pattern adopted, **before the code** (rule 1) | 57a | the Builder |

**Nothing else.** In particular: **no change** to `Boar/Body.luau`, `Boar/Wound.luau`, `Match/Roster.luau`,
`Match/Score.luau`, `Match/Penalty.luau`, `Match/Body.luau`, any weapon module, `src/client/**`,
`src/shared/Drive/**`, `tools/**` or `default.project.json`.

---

## 4. The match state machine

### 4.1 Phases — unchanged

`Phase.step(state, event, now, config) -> (state, { Effect })`, pure, returning a **new frozen state**.

| Phase | Entered when | Lasts | What is true |
|---|---|---|---|
| `Waiting` | boot; a drive ends with `< MIN_PLAYERS`; markers incomplete | until `participants >= MIN_PLAYERS` **and** `markersComplete` | no teams, no boars, no timer; the Hud shows `waitingFor` |
| `Assigning` | `Waiting` satisfied, or `Scoring` elapsed with enough players | `INTERMISSION_SECONDS` = 20 s | teams assigned **once, on entry**; everyone placed; guns re-evaluated; scores zeroed; last drive's boars cleared |
| `Running` | `Assigning` elapsed | `DRIVE_SECONDS` = 600 s | the drive. Releases happen on the schedule; kills and escapes score; the safety rule is live |
| `Scoring` | `Running` elapsed (or every boar accounted and `END_ON_LAST_BOAR`, default **false**) | `SCORE_SECONDS` = 25 s | the score screen; everybody tied is freed; boars cleared |

**Every transition is time-driven from `phaseEndsAt`, and `phaseEndsAt` is the only clock.** No
`task.delay`, no `task.wait`, no second timer. `Phase.isLive(state)` (`phase == "Running"`) is the one
predicate read by the release gate, by scoring and by the penalty.

**The test seam** (`Match.advanceForTests(seconds)`, built in Task 41) moves **this owner's own clock**
forward, gated on Studio plus a live `TestKit.activeToken()`. It is how a spec watches a real drive
boundary. It is not a phase skip and it cannot happen in a playtest or on a live server.

### 4.2 Events the machine consumes

```luau
export type Event = {
    kind: "tick" | "join" | "leave" | "kill" | "gone" | "violation" | "markers",
    userId: number?, name: string?, record: any?, at: number?,
    aliveBoars: number?,      -- live boars (not DOWN, not GONE)
    boarEntries: number?,     -- NEW: every entry the runtime holds, CARCASSES INCLUDED
    boarCapacity: number?,    -- NEW: the runtime's own maxBoars
    complete: boolean?, missing: { string }?, boarSpawns: { Vector3 }?,
}
```

**The owner fills `aliveBoars`, `boarEntries` and `boarCapacity` on EVERY event, not only the tick.**
That rule already exists and is load-bearing: round 1 of Task 38 found a join landing on a release moment
reading `aliveBoars = 0`, passing the gate, and then being refused by the owner — a six-boar drive quietly
ran five (`src/server/Match/Phase.luau`, `maybeRelease` header). The two new fields obey the same rule for
the same reason.

There is **no client-originated event** (§9.1).

### 4.3 Effects the machine emits

```luau
export type Effect =
      { kind: "assignTeams", assignment: { [number]: TeamName } }
    | { kind: "placePlayers", userIds: { number }? }
    | { kind: "refreshArming", userIds: { number }? }
    | { kind: "spawnSounder", position: Vector3?, size: number }   -- CHANGED from spawnBoar
    | { kind: "clearBoars" }
    | { kind: "freeze", userId: number }
    | { kind: "release" }
    | { kind: "broadcast", force: boolean? }
    | { kind: "feed", entry: FeedEntry }
```

`spawnBoar` becomes `spawnSounder` with a `size`. **With the flag OFF every emitted size is 1**, so the
effect list is one field longer and otherwise identical — which is exactly what §12.1 item 1 asserts.

A spec asserts on the **effect list**, a plain table: no Instances, no waiting, no physics.

### 4.4 Join and leave, phase by phase — unchanged

| | `Waiting` | `Assigning` | `Running` | `Scoring` |
|---|---|---|---|---|
| **joins** | counted; enters `Assigning` at `MIN_PLAYERS` | assigned with everybody | **assigned to the smaller team** (tie → `ODD_PLAYER_TEAM`), placed, armed, score 0. No existing player moves | no team; assigned at the next `Assigning` |
| **leaves** | counted out | dropped before the assignment is used | their team shrinks; **nobody is moved** (§1.2). Their row is kept for this drive's screen, marked `left`. A tie is dropped with them | dropped from the next roster; the screen keeps their result |

A drive never aborts because a team emptied; `stats().emptyTeamDrives` counts it.
`Match.forget(player)` is called from `Players.PlayerRemoving` and empties **every** table keyed by that
user.

---

## 5. Teams

### 5.1 Representation: `Player.Team`, and nothing else

Team membership is Roblox's own `Player.Team`, written only by `Match.Body.setTeam`. It replicates free,
a client cannot write it, and it colours the player list. `Match.Body.ensureTeams` creates exactly two
`Team`s at `start()`: `Drivers` (`Bright blue`) and `Shooters` (`Bright orange`), **`AutoAssignable = false`**
so Roblox never assigns anybody — the single most likely way to build this wrong (§16 source A).

### 5.2 `Roster` — pure, and it never knows what a `Player` is

```luau
Roster.assign(userIds: { number }, previous: { [number]: TeamName }?, config): { [number]: TeamName }
Roster.smallerTeam(counts, config): TeamName
Roster.counts(assignment): { [TeamName]: number }
```

1. **Equal to within one** for any 1 ≤ n ≤ 16.
2. The odd player goes to `ODD_PLAYER_TEAM` — **`"Shooters"`, as built**, superseding v2's `"Drivers"`:
   with one player (`MIN_PLAYERS = 1`, Director decision F, `reviews/task-32/DESIGN_DELTA.md`) that
   player is a shooter and is armed, which is what keeps the harness's single Play client holding a gun
   and the weapon and camera client specs green.
3. **Deterministic**: the input is sorted by `userId`; no `Random` in the module.
4. Roles swap between drives when `SWAP_TEAMS_EACH_DRIVE` (default **true**).

### 5.3 What `Assigning` does, in order

`Roster.assign` → `Body.setTeam` for everybody → `Body.place` (connect `CharacterAdded`, then
`LoadCharacter`, then `PivotTo(Body.placementFor(...))`, counting `placementsMissed` after
`PLACE_TIMEOUT = 5 s`) → `Weapon.refreshArming` for everybody → scores zeroed, boars cleared, drive
counter incremented, one **forced** broadcast.

`Body.placementFor(markerSet, team, indexWithinTeam, config)` puts a shooter on post *n*
(`post.Position + (0, post.Size.Y/2 + STAND_HEIGHT_STUDS, 0)`, `STAND_HEIGHT_STUDS = 3.5`) facing **+Z**,
and a driver along the `DriverStart` part's X extent facing **−Z**.

### 5.4 Outfits — NEW here, mirroring `docs/design/map-generator.md` §10 (its delta A3)

Karen, 2026-09-26: **shooters wear an orange hat, drivers an orange vest.** The owner is
`ServerScriptService.Match.Body` — the module that already writes characters — and not a new "cosmetics"
owner.

```luau
Body.OUTFIT_NAME = "HuntOutfit"     -- one folder per character; destroyed and rebuilt
Body.dressFor(team: TeamName?, config): { { name: string, limb: string, size: Vector3,
                                            offset: Vector3, color: Color3 } }   -- PURE
Body.dress(character: Model?, team: TeamName?, config): boolean                  -- returns false on a
                                                                                -- missing limb
```

| Role | Part | Size (studs) | Attached to | Colour |
|---|---|---|---|---|
| Shooter | `Hat` (flat cylinder) | 2.2 × 0.6 × 2.2, +0.8 above the Head's centre | `Head` | RGB(255, 112, 0) |
| Driver | `Vest` (thin box) | 2.2 × 1.6 × 1.3, torso front | `UpperTorso` (fallback `Torso`) | RGB(255, 112, 0) |

Four properties that are not tidiness, all four from the map design and repeated here because this file
owns `Match.Body`'s contract:

1. **`CanQuery = false`.** An outfit that stops a pellet changes what the shot hit, which feeds
   `Penalty.judge` through the weapon's report. It must be invisible to every ray in the game.
2. **`Massless = true`, not anchored.** `Body.tie` anchors the *root*; an anchored hat would pin a head
   to the world.
3. **Cosmetic only, never a source of truth.** Karen's "the safety rule can use them to read who is
   where" is the **player's** reading. `Penalty.judge` keeps deciding from teams (`Body.teamOf`).
4. **The team colours stay** (`Body.TEAM_COLORS`). Orange on both sides is deliberate: in the field both
   wear safety orange, and the Hud badge says which side you are.

**It merges OFF**, as its own flag in its own task (**M2.8d**, not 57a/57b): one row `ORANGE_OUTFITS`,
`default = false`, `owner = "ServerScriptService.Match"`, `expires` ≤ 21 days from its `born`, and
`Match.CONFIG.OUTFITS_ENABLED = Flags.isOn("ORANGE_OUTFITS")` read once at the boundary and passed into
`Body.dressFor` as a parameter, so both states are testable (`docs/design/feature-flags.md` §13.3).
Declared here so M2.8d has no design question left.

---

## 6. Posts, the drive line, and boars

### 6.1 The markers are tags, and the world of the day places them

Five tags, all under the reserved prefix `DrivenHunt.`, which no other system may use. **The strings live
once**, in `src/shared/Map/init.luau`, `Map.TAGS`; `TestArena`, `Markers` and `MapGen.Markers` all read
them from there.

| Tag | Read for | Arena today (`TestArena.LAYOUT.drive`) | Generated map (`map-generator.md` §15.1) |
|---|---|---|---|
| `DrivenHunt.ShooterPost` | where each shooter stands; the tie-up fallback | 8 parts, z = −150, x = −140…+140 step 40 | 8 parts, z = −700 **on the road**, spacing 160 (45 m), span 1120, each 6 × 1 × 6 |
| `DrivenHunt.DriveLine` | `{ position, normal = part.CFrame.LookVector }` — **exactly one**; its `LookVector` points at **+Z, the drivers** | 320 × 1 × 1 at z = −150 | 1240 × 1 × 1 at z = −700 (**the road is the line**) |
| `DrivenHunt.DriverStart` | where drivers spawn, spread across its X extent | 120 × 1 × 12 at z = +170 | 1120 × 1 × 20 at z = +700 |
| `DrivenHunt.BoarSpawn` | where a release enters the drive | 4 parts, z = +120, x = −120, −40, +40, +120 | 4 parts, z = +600, x = −450, −150, +150, +450, each on a flat pad of radius `Map.SPAWN_PAD.radius` |
| `DrivenHunt.Tree` | where a punished shooter is tied | the 4 corner pillars, re-used | 12 placed trunks at z = −745 (**and only those** — `Body.anchorFor` scans every tagged tree, so the wood's ~2,900 other trunks are deliberately untagged) |

This replaces v2's single arena-only table, which `map-generator.md` §19.1 A3 correctly calls three worlds
out of date.

**Tags, not attributes**, for the reason v2 gave and which still holds: the markers are built in code, so
there is nothing on disk for the harness to compare, and the question is "give me every post", which is
one `GetTagged` call. A server spec asserts the tags directly (§12.5).

### 6.2 `Markers` — read-only, loud when something is missing

```luau
export type MarkerSet = {
    posts: { BasePart },        -- sorted by X, so post 1 is always the same post
    line: DriveLine?,           -- nil unless exactly one part is tagged
    lineParts: number,
    driverStart: BasePart?,
    boarSpawns: { Vector3 },    -- sorted by X
    trees: { BasePart },
    spawnRadius: number,        -- NEW: Map.SPAWN_PAD.radius, the flat disc the map guarantees
    complete: boolean,
    missing: { string },
}
Markers.read(service: any?): MarkerSet   -- frozen
```

`complete == false` → the machine **stays in `Waiting`**, `waitingFor` names the exact missing tags, and
the Hud shows them. Two tagged drive lines is also incomplete: an ambiguous line would make the safety
rule fire on whichever the engine returned first. `Markers.read` is re-run every second while `Waiting`
and once on entering `Assigning` (`markersStale`), which also closes the measured `ArenaBoot`/`MatchBoot`
ordering race.

**`spawnRadius` is the one new field, and it is a read of the contract, not a new fact.** It exists so the
sounder's spread is bounded by what the map promises (§6.6) without `Match` or `Boar` requiring `Map`
themselves. It is 14 today and 30 when the map task lands (§0 item 4).

### 6.3 Boars: how many, when, and who says so

**The Match decides *when* and *how many*; `ServerScriptService.Boar` owns every boar.** The Match calls
`runtime:spawn(position)` / `runtime:spawnSounder(...)` / `runtime:clear(reason)` and reads handles
(`handle.state()`, `handle.position()`, `handle.id`). It writes nothing about a boar, ever.

| Number | Value | K? | Why |
|---|---|---|---|
| `BOARS_PER_DRIVE` | 6 | K | **the ANIMAL budget for a drive, in both flag states.** Not a release count |
| `FIRST_RELEASE_SECONDS` | 20 | K | the drivers are walking before the first boar moves. The first release is **exact**, never jittered (measured twice in Task 32: a jittered first release made the only boar of a harness session arrive after the input replay had finished) |
| `RELEASE_INTERVAL_SECONDS` | 90 | K | the singles rhythm: 20 + 5 × 90 = 470 s, so the last boar has ~130 s of drive left |
| `RELEASE_JITTER_SECONDS` | 15 | K | so the drive is not a metronome. Deterministic (`Phase.jitter`), never `Random`, so a bug report is reproducible |
| `MAX_ALIVE_BOARS` | **6** (was 4) | | see below |
| `SEED` | 1 | | the drive's one seed; every drawn number is a pure hash of `(SEED + driveNumber, index)` |

**Two hazards in the boar code, and what this design does about each** (both still true):

1. **`Runtime:spawn` asserts** `#self._boars < maxBoars`. An assert inside the Heartbeat step kills the
   step, not the spawn. So the **pure machine** holds a release back before it is ever attempted
   (`maybeRelease`, using `aliveBoars`/`boarEntries`/`boarCapacity`), the owner wraps the call in `pcall`,
   and a refusal **hands the release back** (`Phase.releaseFailed`) so it is retried and never dropped.
   There is **no second guard in the owner** — two guards disagreeing is what dropped releases in Task 38
   round 1.
2. **Carcasses occupy slots** for `Boar.CONFIG.WOUND.CARCASS_SECONDS = 120`, and `maxBoars` counts them.
   `MAX_ALIVE_BOARS` counts only boars whose state is neither `DOWN` nor `GONE`; `boarEntries` counts
   everything, and that is the number checked against `maxBoars`.

**`MAX_ALIVE_BOARS` goes from 4 to 6, and `Boar.CONFIG.maxBoars` stays 8.** This is the brief's "how do
the 6-boar budget and `maxBoars` interact with groups", answered arithmetically:

- A sounder may be 5. A ceiling of 4 would make a 5-boar release **permanently** impossible, and the
  retry loop would stall the drive. So `MAX_ALIVE_BOARS >= SOUNDER.MAX_SIZE` is an **invariant**, asserted
  in `match_live.spec` (§12.4 item 11), not a coincidence of two numbers.
- 6 = `BOARS_PER_DRIVE`, so the budget is the real ceiling: within one drive, entries ≤ boars released
  ≤ 6 < 8, and `clearBoars` empties the list at every drive boundary. `maxBoars = 8` therefore needs no
  change, and the spec asserts `BOARS_PER_DRIVE <= Boar.CONFIG.maxBoars` so that **raising the budget can
  never silently re-arm hazard 1**.
- The ceiling still bites: two singles alive plus a sounder of 5 is 7 > 6, and that release waits.
- **This is the one behaviour change that the flag does not cover**, stated so the Reviewer sees it
  declared rather than discovering it: with the flag OFF, 4 → 6 only widens a guard that the singles
  schedule (90-second gaps against a ~10-second arena crossing at `SPRINT_SPEED = 38`) never approaches.
  Director item **H** in §14.

`Boar.CONFIG.spawnPoint` stays unused in production: the Match passes an explicit marker position,
round-robin by `soundersReleased`.

### 6.4 `Workspace.DriveMarkers`

`Match.Body` creates it on first use and is its only writer. It holds one thing: a rope `Part` per tied
player, destroyed on release. Workspace is not Rojo-owned and the harness compares the Edit-mode
DataModel, so a run-time folder cannot dirty a run.

### 6.5 The closure trap in `Boar.defaultWorld`

`Boar.defaultWorld`'s `threats` closes over the **module-level** `Boar.CONFIG`, not over the runtime's
merged clone, so passing `config = { isThreat = … }` into the world would change the Brain's copy and not
the one that filters threats. The fix is one line at the composition root:
`world.threats = Match.driverThreats`. **Only drivers scare boars** — a shooter on a post must not push
the boar back into the wood before it reaches the line.

This matters more with sounders, not less: a whole sounder turning round because a shooter walked forward
would be the same bug five times.

### 6.6 NEW — the sounder release: sizes, mix, spacing, timing

The brief: "how a drive mixes singles and groups (sizes, probabilities, spacing, timing)".

**A release is a sounder of `size` boars at one `DrivenHunt.BoarSpawn` marker.** A single is a sounder of
one. `size` is decided by the **pure machine**, from a hash — never `Random` — so two runs of the same
seed give the same drive, which is the property `Phase.jitter` and `Roster.assign` already have and the
only thing that makes a bug report reproducible.

```luau
-- src/server/Match/Phase.luau, all pure, all new
Phase.unitHash(seed: number, index: number): number    -- [0, 1); Phase.jitter is refactored onto it,
                                                       -- so there is ONE hash in this module, not two
Phase.sounderSize(state: State, config): number
    -- remaining = config.BOARS_PER_DRIVE - state.boarsReleased
    -- remaining <= 0                 -> 0
    -- not config.SOUNDER.ENABLED     -> 1                       (EXACTLY today's behaviour)
    -- otherwise                      -> a weighted pick from config.SOUNDER.SIZE_WEIGHTS with
    --                                   Phase.unitHash(state.seed + state.driveNumber,
    --                                                   state.soundersReleased + 1),
    --                                   clamped to math.min(config.SOUNDER.MAX_SIZE, remaining)
Phase.releaseGap(state: State, size: number, now: number, config): number
    -- not ENABLED -> config.RELEASE_INTERVAL_SECONDS            (EXACTLY today)
    -- ENABLED     -> math.clamp((state.phaseEndsAt - config.SOUNDER.TAIL_SECONDS - now)
    --                             / releasesLeft,
    --                           config.SOUNDER.GAP_MIN_SECONDS,
    --                           config.SOUNDER.GAP_MAX_SECONDS)
    --                releasesLeft = math.max(1, math.round(remainingAfterThisRelease
    --                                                      / config.SOUNDER.EXPECTED_SIZE))
Phase.releaseFailed(state: State, now: number, size: number): State
    -- gives back ONE sounder and `size` boars, and makes the next release due NOW, so the SAME
    -- sounder (same hash index -> same size) is retried on the next step rather than lost.
```

`maybeRelease` becomes:

```
if state.boarsReleased >= config.BOARS_PER_DRIVE or now < state.nextReleaseAt then return end
local size = Phase.sounderSize(state, config)
if size <= 0 then return end
-- THE WHOLE SOUNDER FITS OR NONE OF IT IS RELEASED
if (event.aliveBoars or 0) + size > config.MAX_ALIVE_BOARS then return end        -- retried next tick
if (event.boarEntries or 0) + size > (event.boarCapacity or math.huge) then return end
local position = spawns[(state.soundersReleased % #spawns) + 1]
state.soundersReleased += 1
state.boarsReleased += size
table.insert(effects, { kind = "spawnSounder", position = position, size = size })
state.nextReleaseAt = now + Phase.releaseGap(state, size, now, config)
    + Phase.jitter(state.seed + state.driveNumber, state.soundersReleased + 1, config.RELEASE_JITTER_SECONDS)
```

**Why the flag-OFF path is provably today's path, byte for byte.** With `ENABLED = false` every size is 1,
so `soundersReleased == boarsReleased == the old releasesDone`: the marker round-robin index is the same,
the jitter index is the same, and `releaseGap` returns the same 90. The rename is a rename.
`match_phase.spec` asserts the whole effect sequence of a 600-second drive against the literal schedule
(§12.1 item 1), which is the strongest form of "nothing that works stopped working".

**The mix.** `SIZE_WEIGHTS = { 40, 20, 18, 12, 10 }` for sizes 1..5 (K): 40 % singles, 60 % groups, a
five once in ten releases. `EXPECTED_SIZE = 2.32` is the weighted mean, and it is **not an independent
number**: `match_phase.spec` asserts it equals the mean of the weights to 0.01, so it cannot drift when
Karen retunes them.

**The timing, and the trade it forces, stated plainly.** Six animals in bites averaging 2.32 is **~3
encounters per drive**, where singles gave 6. A fixed 90-second gap would then spend the budget by ~t+300
and leave half the drive empty. So, **with the flag ON only**, the gap is paced across the drive: divide
the time left before `TAIL_SECONDS` by the releases the remaining budget is expected to buy, clamped to
[45, 180] s. Worked, `SEED = 1`, budget 6, sizes 1/2/3: releases at 20, 200, 380 — the last sounder
arrives 220 s before the end with three animals on the field, instead of 290 s before the end with
nothing following. The tail cannot be removed by pacing; it is arithmetic. **Karen's dial is
`BOARS_PER_DRIVE`**, and my recommendation is in §14 Karen item 9: play it at 6; if the wood feels empty
after the third sounder, 10 is one number and `MAX_ALIVE_BOARS`/`maxBoars` are asserted to move with it.

**Spacing at the spawn — and the pad is the contract.** The owner passes the marker position and the
radius the map guarantees:

```
applySpawnSounder(position, size):
    handles = pcall -> world.boars:spawnSounder(position, size, markerSet and markerSet.spawnRadius)
    ok and #handles > 0 -> stats.releases += 1
    otherwise           -> stats.releasesDeferred += 1; state = Phase.releaseFailed(state, now(), size)
```

`spawnSounder` is **all-or-nothing** (§9.4): it creates the whole sounder or nothing, so a half sounder
cannot exist and the drive's budget arithmetic cannot drift from the world. The **boar** decides the ring
geometry, because the offsets are about `BODY_SIZE` and `SPAWN_CLEARANCE`, which are its numbers
(§11.7). Five boars on a ring of radius 10 stand 11.8 studs apart with a 2 × 5.5 body — comfortable — and
the ring is clamped inside `spawnRadius - PAD_MARGIN_STUDS`, so it is 10 at a pad radius of 14 **and** at
30. Why staying inside the pad matters: `Runtime:spawn` **overwrites the caller's Y** with
`field.groundY + BODY_SIZE.Y/2 + SPAWN_CLEARANCE`, so a member placed on a slope is spawned inside a hill
(`docs/design/map-generator.md` §11 item 2). The arena's plate is flat everywhere, so the arena is safe by
construction; the generated map is safe only on the pad.

### 6.7 NEW — the sounder's behaviour, and who writes it

The brief: "borrow a known pattern with sources (leader-follower, boids-style cohesion/separation on top
of the existing Brain + PathfindingService route) — who leads, how followers keep formation through gates
in hedges and along the road crossing, what happens when the leader is shot, how a wounded group member
behaves".

**Ownership first, because it is the whole answer to the brief's third item.**

| Fact | The one writer | Where |
|---|---|---|
| a sounder exists, who is in it, who leads, how long it is scattering | **`ServerScriptService.Boar`** (the Runtime) — `self._sounders`, `entry.sounderId` | `src/server/Boar/init.luau` |
| every boar's Instances, velocity, facing, flash, collapse | `Boar.Body` (unchanged) | `src/server/Boar/Body.luau` |
| every boar's **decision** state, including where in the formation it is steering | `Boar.Brain` (unchanged role) — and it holds **no reference** to another boar | `src/server/Boar/Brain.luau` |
| how big a release is and when | `ServerScriptService.Match` / `Match.Phase` | §6.6 |
| **nothing** | — | the drive never reads `Runtime:sounders()` in production. It is there for specs and diagnostics |

**The pattern adopted: a navmesh route for the leader + Reynolds leader-following with boids
separation/cohesion/alignment for the followers, blended into the setpoint that already exists.** Sources,
assessment and what is rejected: §16 sources G, H, I. Nothing about the physics changes: the blended
direction goes through the **same** `slew(TURN_RATE·dt)` and the same `ACCEL` ramp the Brain already
applies, so the existing turn-rate and acceleration assertions still hold and there is no second motion
rule.

**The Runtime assembles one observation per boar per step** (it already does this for threats, waypoints,
hits and the wound):

```luau
export type SounderObs = {
    isLeader: boolean,
    slot: number,                    -- 1 = leader, 2..5 = the formation slot, stable for a member's life
    scattering: boolean,
    leaderState: string?,            -- "IDLE" | "FLEE" | "WOUNDED" | nil
    leader: { position: Vector3, velocity: Vector3, facing: Vector3, speed: number }?,
    centroid: Vector3,               -- live members, self included; what IDLE uses instead of a slot
    neighbours: { { position: Vector3, velocity: Vector3 } },  -- live members within NEIGHBOUR_STUDS,
                                                              -- never self, plain values only
}
```

`obs.sounder` is **nil for a lone boar**, and then every existing code path runs unchanged — which is why
the flag-OFF world is provably today's world (§12.6 item 1).

**Who leads.** The member **nearest the exit line** (`min |position.Z - field.exitZ|`), tie-broken by id,
chosen at `spawnSounder` and re-chosen on every promotion. The animal at the front leads; it is one line
and it is deterministic.

**The leader** behaves exactly as a lone boar does today: it senses threats, it routes to
`_routeTarget()` (flee toward the exit line, pushed sideways away from the threat, the bias doubled when
the threat is between it and the exit), and it is the **only** member that asks for a path.

**The followers** blend four steering terms into the desired direction — a Reynolds truncated weighted sum
in which separation can dominate (§16 source H's arbitration point):

| Term | Toward | Weight |
|---|---|---|
| cohesion | its slot in the leader's frame, or the sounder centroid while IDLE beyond `IDLE_SPREAD_STUDS`; **zero inside `SLOT_TOLERANCE_STUDS`** (arrival, so it does not oscillate on the spot) | `COHESION` 1.0 |
| separation | away from each neighbour, scaled `(SEPARATION_STUDS / max(d, 1)) - 1`, clamped ≥ 0 | `SEPARATION` **1.6** — it dominates, because two colliding 23-stud bodies driven by 6000 of force is the worst thing that can happen here |
| alignment | the leader's velocity, else the neighbour mean | `ALIGNMENT` 0.4 |
| flee | the existing `_fleeDirection()` — the route/threat direction | `FLEE_WEIGHT` 0.8 |

**Follower speed** is the leader's speed (so the sounder does not concertina), × `CATCHUP` = 1.15 while
farther than `SLOT_TOLERANCE_STUDS`, clamped to `[TROT_SPEED/2, SPRINT_SPEED]`, and then multiplied by the
wound's `speedScale` exactly as today. With no leader (scattering) the existing rule applies: sprint while
threatened, trot otherwise.

**Herd panic, and herd calm.** A follower in `IDLE` whose `leaderState` is `FLEE` or `WOUNDED` enters
`FLEE` on its next sense tick, even if no threat is inside its own `DETECT_RADIUS`. A sounder bolts as one
animal; without this rule the first contact tears the group in half. The reverse also holds: a follower
returns to `IDLE` only when its own calm timer has run **and** `leaderState == "IDLE"`.

**Formation through a gate, and across the road.** Two mechanisms, and neither queries the map (§1.2):

1. **The leader's route funnels the sounder.** `PathfindingService` routes the leader around the hedge
   parts and through a gate; the followers follow **the leader**, not the route. This is the second reason
   leader-only pathing is right: five independent `ComputeAsync` calls could each choose a different gate
   and split the sounder in two.
2. **Single file when it is actually tight.** `obs.blockedAhead` — the existing probe, which already
   excludes the boar folder (`Boar.defaultWorld`, `probe`, `FilterType = Exclude`,
   `FilterDescendantsInstances = { world.folder }`), so it never fires on a herd-mate — latches
   `COLUMN_LATCH_SECONDS = 1.5`, and while latched the slot offsets become a **column** behind the
   leader at `COLUMN_SPACING_STUDS`. A 96-stud gate (`map-generator.md` §15.1) never triggers it; a
   trunk gap does. The road (16 studs plus 24-stud verges, level) triggers nothing, so the sounder
   crosses the line at full width — Karen's reference frame.

**When a member is shot.** `Runtime:takeHit` already knows the boar and the hit. On **any** hit on any
member (`SCATTER_ON_HIT = true`, K), the sounder's `scatterFor` is latched to `SCATTER_SECONDS = 6` and
`stats().scatters` increments. While scattering: `leader = nil` in every member's observation, cohesion
and alignment are zero, separation is × `SCATTER_SEPARATION = 3.0`, and every member runs its own
`_routeTarget` with the existing Reynolds fallback. A real sounder breaks up at the shot; this is the
drama Karen's reference is about, and it also stops a group from queueing up in front of one barrel.

**When the leader dies.** Both things, in this order, on the same tick: the Runtime **promotes** the live
member nearest the exit line, and the sounder **scatters** for `SCATTER_SECONDS` (a kill is a hit). When
the scatter expires, whoever is still within `BREAK_STUDS` of the new leader is back in formation and
whoever ran farther has become a lone boar. There is **no re-forming rule and no reunion radius**: a
member that left never rejoins. One rule fewer, and it is what the reference scene looks like.

**A wounded member.** `LEAVE_ON_MORTAL = true` (K): as soon as a member's wound severity is `mortal` or
`lethal`, the Runtime takes it **out of the sounder** — the sounder loses a member, promoting if it was
the leader, and the wounded animal continues on the existing `WOUNDED` path (never calms, speed ramps down
over its flight, leg hits limp). Two reasons: a dying animal cannot hold formation, and if the group
matched *its* speed the whole sounder would crawl to the line. `Boar.Wound` is untouched — the Runtime
already holds the one wound state and is already the only writer of it.

**A member leaves, in exactly four ways**, all written by the Runtime and nothing else:

1. it despawned (escaped, out of bounds, or the carcass timed out);
2. it became mortally wounded (`LEAVE_ON_MORTAL`);
3. it was farther than `BREAK_STUDS` from the leader for `BREAK_SECONDS` (counted with `dt`, reset on
   coming back inside);
4. the sounder fell to **one** member — it is **dissolved**, `entry.sounderId = nil`, and the survivor is
   a lone boar with no per-step group work left (`stats().soundersDissolved`).

A sounder crossing the line dissolves itself for free: each member despawns independently as it passes
`exitZ`, and rules 1 and 4 do the rest.

### 6.8 NEW — performance: one route per sounder

The brief: "pathfinding cost with 5 boars in a group (compute the route once for the leader?)". **Yes,
and it is an invariant rather than an optimisation.**

- `LEADER_PATHS_ONLY = true`. A follower's `intent.pathRequest` is always `nil`, with **one exception**: a
  follower that `_updateStuck` has reported stuck twice may request one, because the alternative is a
  member wedged behind a trunk that the sidestep alone does not clear. The per-boar in-flight guard
  (`entry.pending`, `Runtime:_requestPath`) already caps each boar at one.
- Steady state: **≤ 1 `ComputeAsync` in flight per sounder** and ≤ 2 per second while fleeing
  (`REPATH_INTERVAL = 0.5`), whatever the size. A per-member design would be 5× that, and `ComputeAsync`
  yields.
- Measurable, and §12.8 item 8 asserts it: over a 3-second live flee with a sounder of five,
  `stats().pathRequests <= 12`. Per-member pathing lands near 30.
- Observation assembly is O(n) per sounder plus O(n²) neighbour pairs, n ≤ 5 → ≤ 20 pair distances per
  sounder per step; at `MAX_ALIVE_BOARS = 6` that is ≤ 30 pair distances a frame and **zero raycasts
  added** (the probe was already one per boar).
- Instances: ~7 per boar (trunk, three zone parts, attachment, `LinearVelocity`, `AlignOrientation`), so a
  sounder of five is ~35 and a full field is ~42 — negligible against `Map.BUDGET.parts = 20000`.

### 6.9 NEW — the flag

```lua
BOAR_SOUNDERS = {
    default = false,
    owner = "ServerScriptService.Match",
    born = "2026-09-27 task 57b",
    expires = "2026-10-17",      -- 20 days: inside the 21-day ceiling (feature-flags.md section 12)
    why = "Boars come as a mix of singles and sounders of 2-5. OFF releases one boar per release, as today.",
}
```

**One read, at the boundary, in the only permitted shape** (`docs/design/feature-flags.md` §10):

```lua
SOUNDER = {
    ENABLED = Flags.isOn("BOAR_SOUNDERS"),   -- K; flag: docs/design/feature-flags.md
    ...
},
```

**What it switches: the release shape, and nothing else.** With it OFF every size is 1, so
`Runtime:spawnSounder` is never called with a size above 1 by production, no sounder record is ever
created, `obs.sounder` is always `nil`, and the Brain's formation code is unreachable. **One flag at one
boundary, and the behaviour is dark because it has no caller** — rather than a flag threaded through the
Brain, which would put a boolean inside a 60 Hz loop (`feature-flags.md` §1.2 item 4 forbids exactly
that).

**How both states are tested while the flag sits at one of them** (`feature-flags.md` §13.3): every new
decision is a pure function taking `config` or a parameter —

- `Phase.sounderSize(state, config)` and `Phase.releaseGap(state, size, now, config)`: specs pass
  `{ SOUNDER = { ENABLED = true, … } }` and `{ ENABLED = false }` and assert both;
- `Runtime:spawnSounder(center, size, maxSpread)` is a **public function a spec calls directly**,
  regardless of the flag, so the live five-boar evidence exists with the flag off;
- `Brain:step(dt, obs)` takes `obs.sounder` as data, so the follower path is driven by a hand-written
  table.

And the honest limit, stated rather than implied: **while the flag is OFF, CI and the harness exercise the
on-disk defaults only.** The *wired, live* release of a sounder by the drive is proved by the Director's
override plus Karen's playtest (§12.10), and by the pure and live specs before that.

---

## 7. Points — unchanged by this revision

### 7.1 The table (`Match.CONFIG.POINTS`, as built)

| Field | Value | K? | Reads as |
|---|---|---|---|
| `KILL.head` | 100 | K | the best shot in the game |
| `KILL.chest` | 80 | K | the shot a hunter actually takes |
| `KILL.body` | 50 | K | it died, but it ran |
| `KILL.legs` | 30 | K | you brought it down eventually |
| `KILL.unknown` | 50 | | scored as `body`, never free, counted in `stats().unknownZoneKills` |
| `ASSIST` | 10 | K | to every contributor who is not the killer and put in ≥ `ASSIST_MIN_DAMAGE` |
| `ASSIST_MIN_DAMAGE` | 25 | K | a quarter of `Boar.CONFIG.WOUND.LETHAL` |
| `PUSH` | 25 | K | to every **driver** within `PUSH_RADIUS` of that boar inside `PUSH_WINDOW` before it died |
| `PUSH_RADIUS` | 60 | K | 1.5 × `Boar.CONFIG.DETECT_RADIUS` |
| `PUSH_WINDOW` | 20 s | K | long enough for a boar's flight |
| `ESCAPE_WOUNDED` | 0 | K | "take the shot you can make" |
| `SAFETY_PENALTY` | −50 | K | half a good kill, on top of losing the drive |
| `PUSH_SAMPLE_HZ` | 2 | | distance only; **this system casts no rays at all** |

**Sounders do not change scoring, and that is a decision, not an omission.** `pushCredit` is keyed by
**boar id**, not by sounder (`src/server/Match/init.luau`, `samplePush`, `creditFor`), so a driver who
pushed a sounder of five and watched three of them die is paid three times — once per animal, which is
what "individual points per boar" means. No group bonus in v1 (§14 Director item L).

### 7.2 `Score` — pure, keyed by `UserId`

`Score.new/join/setTeam/kill/escape/violation/leave/leaderboard`. No service, no clock, no `Player`, no
Instance, no `Random`. **A `Player` is never stored**, only `userId` and `name`: a wounded boar can outlive
a disconnect by `BLEED_OUT_MAX_SECONDS = 25` and a row outlives it by a whole drive.

### 7.3 The leaderboard

`points` desc, then `kills` desc, then `firstKillAt` asc, then `userId` asc. The last key makes the order
total, so the score screen never reorders between broadcasts for no reason.

### 7.4 Where a kill comes from

`Runtime.Downed(record)` → `Score.kill(board, record, creditFor(record.id), CONFIG)`;
`Runtime.Despawned(record)` with `reason == "escaped"` → `Score.escape`; with `reason == "killed"` →
**nothing** (that is the carcass leaving, and the kill was already scored — scoring both is a double count
that looks like a cheat). A missing `Downed` signal warns once and counts
`stats().killSignalMissing` rather than scoring zero in silence.

---

## 8. The safety rule — unchanged by this revision

### 8.1 The rule

**v1: _you fired at a driver_.** A shot is a violation when a live driver's character was inside
`SAFETY_MISS_STUDS` of the shot's path, in front of the muzzle, and nearer than where the pellets stopped.

Rejected and recorded so it is not re-invented: "any shot within 45° of the drivers" as the *verdict* — a
shooter on a post faces the drive, so every legitimate shot is inside that cone and everybody would be
tied in the first minute. The cone stays as the weapon's **filter**. Also rejected for v1: "any shot along
the line" at your neighbours — `SafetyArc.isForbidden` compares against one normal, so it would catch one
direction of two; it is one extra pure test in `Penalty.judge` when it is wanted (`TASKS.md` row 35a, and
`map-generator.md` §20 Karen item 1 notes that at 160-stud post spacing it becomes a real rule).

### 8.2 Who decides what, at fire time

| Step | Who |
|---|---|
| the shot's true direction and where the pellets stopped | **the weapon**, only |
| where the drive line is | **the Match**, through `Weapon.setDriveLineProvider(Match.driveLine)` |
| "this shot went into the drive" — the **filter** | **the weapon**: `SafetyArc.isForbidden(aim, line, SAFETY_ARC_HALF_DEG = 45)` |
| "…and it endangered somebody" — the **verdict** | **the Match**: `Penalty.judge` |
| the punishment | **the Match**, never the weapon |

`Weapon.SafetyViolated` carries `(player, aim, muzzle, stopAt)`. Without `stopAt`, a shooter who cleanly
kills a boar 30 studs away is tied because a driver stood 80 studs behind it in line — the pellets never
got near him.

**Known gap, stated rather than hidden:** the 45° filter is measured from the line's normal, so a shooter
who has wandered far off the post line can endanger a driver at an angle outside the cone and the
violation is never published. `SAFETY_ARC_HALF_DEG` is the dial; shooters who stay on their posts are
fully covered.

### 8.3 `Penalty.judge` — pure

```luau
export type Shot = { userId: number, muzzle: Vector3, aim: Vector3, stopAt: number, at: number }
Penalty.judge(shot, drivers: { DriverPos }, config): (boolean, string?)
    -- true only when SOME driver d satisfies all of:
    --   t = (d.position - shot.muzzle):Dot(shot.aim)                    -- aim is unit
    --   t > 0
    --   t <= math.min(shot.stopAt + config.SAFETY_BODY_STUDS, config.SAFETY_RANGE_STUDS)
    --   ((d.position - shot.muzzle) - shot.aim * t).Magnitude <= config.SAFETY_MISS_STUDS
Penalty.expired(tiedAt, now, config): boolean   -- false while config.TIE_UNTIL_DRIVE_END
Penalty.REASON = "driver-in-line"
```

`SAFETY_BODY_STUDS = 4` is the depth of a person, added to where the shot stopped: without it a shot that
**hits** a driver stops on his surface, a stud in front of his root, and would be judged harmless
(`reviews/task-35/DESIGN_DELTA.md`). It supersedes the v2 formula.

The owner asks three other questions before it calls `judge`: is the phase `Running`, is this shooter
already tied, is `SAFETY_GRACE_SECONDS` over. Four questions, four places, one of them `judge`'s.

### 8.4 "Tied to a tree"

`Match.Body.tie(player, tree, config)`, the sole writer of every property: `WalkSpeed = 0`,
`JumpHeight`/`JumpPower = 0`, `PivotTo` beside the trunk at `TIE_GAP_STUDS = 2.5` **from its surface, on
the side the offender came from**, `HumanoidRootPart.Anchored = true`, one rope part in
`Workspace.DriveMarkers`, `Weapon.refreshArming` (the policy now says no, so the Tool goes), one
`MatchEvent` so everybody sees who was tied and why.

The anchor is `Body.anchorFor(markerSet, position)`: the nearest `DrivenHunt.Tree`, falling back to the
nearest post, falling back to **not tying at all** with `stats().tiesWithoutAnchor` — never a nil CFrame,
which would silently teleport the offender to the origin. **Without an anchor the violation still
happened**: the −50 points, the feed line and `Punished` all fire; only the rope, the freeze and the
revoked gun need a tree.

A tied player who presses Reset is **re-tied to the same tree** on `CharacterAdded`
(`watchCharacter`): "press Escape, Reset, and the penalty is over" is not a penalty.

Freed at the end of the drive (the `release` effect), on leaving, on `Match.forget`, and on `Match.stop`.
`TIE_UNTIL_DRIVE_END` is a **flag read** (§11.4); `TIE_SECONDS = 60` is used only when it is false, through
`Penalty.expired`.

### 8.5 Arming

```luau
Weapon.setArmingPolicy(policy: ((Player) -> boolean)?)   -- nil restores Shotgun.CONFIG.shouldArm
Weapon.refreshArming(player: Player)                     -- re-evaluate now: grant or revoke
Match.mayCarryWeapon(player): boolean
    -- true iff the team is Shooters, or Drivers with DRIVERS_MAY_SHOOT,
    --         AND the player is not tied,
    --         AND the phase is Assigning, Running or Scoring (never Waiting)
```

`Shotgun.CONFIG.shouldArm` stays as the default for a server with no Match — which is exactly what
`tests/server/weapon_*.spec.luau` are, so those specs are untouched.

---

## 9. Public interface

Types are Luau annotations. `luau-lsp analyze` is not in CI, so they are documentation plus editor
checking, not a gate.

### 9.1 The wire — `ReplicatedStorage.Drive`, unchanged

```luau
export type TeamName = "Drivers" | "Shooters"
export type PhaseName = "Waiting" | "Assigning" | "Running" | "Scoring"

export type ScoreRow = { userId: number, name: string, team: TeamName?, points: number,
    kills: number, assists: number, pushes: number, violations: number, left: boolean }

export type MatchSnapshot = {
    phase: PhaseName,
    phaseEndsAt: number,        -- SERVER TIME (Workspace:GetServerTimeNow), not a duration
    driveNumber: number,
    boarsReleased: number,      -- ANIMALS released this drive. Unchanged meaning: it reads
                                -- state.boarsReleased, which is what state.releasesDone already was
    boarsLeft: number,          -- BOARS_PER_DRIVE - boarsAccounted
    waitingFor: { string },
    rows: { ScoreRow },         -- dense array, sorted
    tied: { number },           -- dense array of userIds
}

export type FeedEntry = { kind: "kill" | "escape" | "violation" | "phase" | "join" | "leave",
    userId: number?, name: string?, zone: string?, points: number?, text: string?, at: number }

Drive.CONFIG            -- layout and colours for the Hud ONLY; deep-frozen
Drive.deepFreeze        -- re-exported from ReplicatedStorage.Shotgun; NOT a second copy
Drive.remotes(): { MatchState: RemoteEvent, MatchEvent: RemoteEvent }
```

| Remote | Direction | Payload | Rate |
|---|---|---|---|
| `MatchState` | `FireAllClients` | `MatchSnapshot` | on change, floored at `STATE_MIN_INTERVAL = 0.25 s`, **forced on every phase entry**, plus a `STATE_HEARTBEAT = 5 s` beat |
| `MatchEvent` | `FireAllClients` | `FeedEntry` | one per discrete event |

**There is no client→server remote in this system**, so its inbound exploit surface is zero. Written down
so a later "ready up" button does not quietly add one without a design.

**The timer is a server timestamp, not a countdown.** `phaseEndsAt` is `GetServerTimeNow`-based; the Hud
renders the difference locally every frame. The server's own logic runs on `world.now()` (`os.clock`), and
`serverTimeFor` is the one conversion, in one place.

Every table on the wire is a dense array or a pure dictionary: a mixed table does not survive
serialisation (`docs/design/shotgun.md` §2.3).

### 9.2 `ServerScriptService.Match` — the owner (as built, plus this revision)

```luau
Match.start(world: World)              -- once; asserts it is not started twice
Match.stop()                           -- disconnects everything it connected; frees everybody tied
Match:step(dt: number)                 -- the whole tick; Heartbeat calls it, a spec drives it
Match.phase(): PhaseName
Match.snapshot(): MatchSnapshot        -- deep-frozen, cached
Match.lastSent(): MatchSnapshot?       -- what the clients were ACTUALLY told
Match.driveLine(): DriveLine?
Match.mayCarryWeapon(player: Player): boolean
Match.driverThreats(): { { id: string, position: Vector3 } }
Match.isTied(userId: number): boolean
Match.forget(player: Player)
Match.trackedPlayers(): number
Match.advanceForTests(seconds: number): boolean   -- gated on Studio + TestKit.activeToken()
Match.testSeconds(): number
Match.stats()                          -- drives, kills, escapes, releases, releasesDeferred,
                                       -- placementsMissed, emptyTeamDrives, unknownZoneKills,
                                       -- killSignalMissing, broadcasts, testSeconds, ties,
                                       -- tiesWithoutAnchor, violations, safetySignalMissing,
                                       -- NEW: soundersReleased, boarsReleased, sounderHoldbacks
Match.PhaseChanged / Match.Scored / Match.Punished    -- BindableEvent .Event
Match.Phase / Roster / Score / Penalty / Markers / Body   -- exported for specs
Match.CONFIG
```

`World`: `{ boars, weapon, markers?, players?, now?, serverTime?, remotes?, heartbeat?, collection?, rng? }`.
A spec passes its own for all of them.

### 9.3 Client — unchanged

```luau
-- PlayerScripts.Match
Match.start() / Match.get(): MatchSnapshot? / Match.Changed / Match.Feed
Match.secondsLeft(): number            -- max(0, phaseEndsAt - workspace:GetServerTimeNow())
Match.myTeam(): TeamName?              -- from Players.LocalPlayer.Team, NOT from the snapshot
```

The Hud draws: a drive bar (MM:SS, phase, team badge, `boarsLeft`), an event feed
(`FEED_LINES = 5`, `FEED_SECONDS = 8`), a score screen visible **iff** `phase == "Scoring"` and
`Drive.CONFIG.SCOREBOARD_ENABLED`, and a tied banner for the local player. Nothing else. All built in
code, ASCII only.

**Dependency direction, one way:** the Hud reads `Match.get()` and `Match.Changed`; the Match holds no
reference to the Hud and does not know it exists.

### 9.4 NEW — the boar runtime's sounder interface

This is the part of `src/server/Boar/` that 57a adds. It belongs in `docs/design/boar-ai.md`, which is
**not regenerated by this run**; that design's §3 and §4 are otherwise unchanged, and
`map-generator.md` §19.1 A4 already asks for it. **Until boar-ai.md is regenerated, this section is
normative for sounders**, and the code headers cite this file (`-- Design: docs/design/drive.md ("the
sounder's behaviour, and who writes it")` — heading text, not a number,
per `map-generator.md` §19.1 B1). Named as delta **M1** in §14 so the two files cannot quietly disagree.

```luau
-- ServerScriptService.Boar
Boar.CONFIG.SOUNDER = { ... }                       -- section 11.7

export type SounderView = {                          -- a COPY; there is no setter
    id: string,                 -- "Sounder3"
    leaderId: string?,
    memberIds: { string },      -- live members, leader first, then by slot
    scatterFor: number,         -- seconds of scatter left; 0 in formation
    bornAt: number,
}

Runtime:spawnSounder(center: Vector3, size: number, maxSpread: number?): { Handle }
    -- ALL OR NOTHING. Returns {} and creates nothing when size < 1 or
    -- #self._boars + size > self._config.maxBoars, so a half sounder cannot exist and the drive's
    -- budget can never disagree with the world.
    -- size == 1 -> exactly Runtime:spawn(center); NO sounder record is created.
    -- Otherwise: `size` boars evenly spaced on a ring around `center`, radius
    --   math.max(BODY_SIZE.Z, math.min(SOUNDER.SPAWN_RING_STUDS,
    --                                  (maxSpread or SOUNDER.SPAWN_RING_STUDS) - SOUNDER.PAD_MARGIN_STUDS))
    -- the ring's phase from self._rng (so two releases at one marker do not stand in the same
    -- footprints), each member through the existing spawn path, leader = nearest to field.exitZ,
    -- tie-broken by id.
Runtime:sounders(): { SounderView }
Runtime:sounderOf(boarId: string): SounderView?
Runtime:capacity(): number            -- self._config.maxBoars. Read-only; the drive's pre-check
Runtime:count(): number               -- #self._boars, carcasses included
Runtime:stats()                       -- + soundersSpawned, soundersDissolved, leaderPromotions,
                                      --   membersLeft, scatters
```

`Runtime:spawn`, `takeHit`, `clear`, `boars`, `woundOf`, `step`, `run`, `destroy`, `Despawned`, `Hit`,
`Downed` keep their signatures exactly. `Runtime:clear` already despawns every entry through the one
despawn path, so a sounder is cleared at a drive boundary with no new code.

`Boar.Brain` gains no public function: the formation lives inside `Brain:step` and is driven entirely by
`obs.sounder` (§6.7).

---

## 10. Data on disk

**Everything positioned or coloured is built in code.** No `.rbxm` (banned), no typed property value in
JSON (`Vector3`, `CFrame`, `Color3` fail the harness as "cannot compare"; `TASKS.md` row 16, open, and the
Director has already decided it stays "before release").

The **one** data file in this system is `src/shared/Drive/Remotes.model.json` — a `Folder` with two
`RemoteEvent` children, no properties and no attributes, mirroring the shotgun's, which compares green.
**This revision adds no file on disk at all.**

`src/starterpack/` and `src/startergui/` stay empty: StarterPack hands a Tool to *every* player, which is
the opposite of what teams need.

---

## 11. Numeric targets — the one config table

Everything lives in `Match.CONFIG`, deep-frozen with `Drive.deepFreeze`, in
`src/server/Match/init.luau`. **K** marks Karen's feel values. **No magic number anywhere else in this
system.** §11.7 is the sounder block; the boar's own sounder numbers live in `Boar.CONFIG.SOUNDER`, where
`BODY_SIZE` and `SPRINT_SPEED` already are.

### 11.1 The drive (as built; supersedes v2 where marked)

| Field | Value | K? | Basis |
|---|---|---|---|
| `DRIVE_SECONDS` | 600 | K | Karen: "10-minute drives" |
| `INTERMISSION_SECONDS` | 20 | K | long enough to read the teams and walk to your post |
| `SCORE_SECONDS` | 25 | K | long enough to read a 16-row board |
| `MIN_PLAYERS` | **1** | | **supersedes v2's 2.** Director decision F (audit-003 must-fix 1), Milestone 1 only: one player is a drive, so the harness's single Play client is armed. Raise to 2 before release |
| `MAX_PLAYERS` | 16 | | `docs/PROJECT_CONTEXT.md` |
| `ODD_PLAYER_TEAM` | **`"Shooters"`** | K | **supersedes v2's `"Drivers"`**, for the same reason |
| `SWAP_TEAMS_EACH_DRIVE` | `true` | K | everybody wants to shoot |
| `DRIVERS_MAY_SHOOT` | `false` | K | the brief: a switch, default OFF |
| `END_ON_LAST_BOAR` | `false` | K | a drive is ten minutes, not "until the boars run out" |
| `PLACE_TIMEOUT` | 5 s | | how long `Body.place` waits for a character before counting a miss |
| `STAND_HEIGHT_STUDS` | 3.5 | | **new in the design; built since 1.7a.** Above a post's top face |

### 11.2 Boars — §6.3

`BOARS_PER_DRIVE = 6` (K) · `FIRST_RELEASE_SECONDS = 20` (K) · `RELEASE_INTERVAL_SECONDS = 90` (K) ·
`RELEASE_JITTER_SECONDS = 15` (K) · **`MAX_ALIVE_BOARS = 6`** (was 4; §6.3) · `SEED = 1`.

### 11.3 Points — §7.1 is the config, field for field.

### 11.4 The safety rule (as built)

| Field | Value | K? | Basis |
|---|---|---|---|
| `SAFETY_ENABLED` | `true` | | 1.7b is merged |
| `SAFETY_MISS_STUDS` | 12 | K | ≈ 3.4 m at 1 stud = 0.28 m |
| `SAFETY_RANGE_STUDS` | 330 | | `Shotgun.CONFIG.RANGE_STUDS.Slug` |
| `SAFETY_BODY_STUDS` | 4 | | **new in the design; built.** The depth of a person (§8.3) |
| `SAFETY_GRACE_SECONDS` | 0 | K | the rule is the rule from the first second |
| `TIE_UNTIL_DRIVE_END` | `Flags.isOn("TIE_UNTIL_DRIVE_END")` → `true` | K | **supersedes v2's literal.** The flags system's worked example |
| `TIE_SECONDS` | 60 | K | used only when the flag is false |
| `TIE_GAP_STUDS` | 2.5 | K | **supersedes v2's `TIE_OFFSET` CFrame.** From the trunk's surface |
| `ROPE_COLOR` / `ROPE_THICKNESS` | RGB(170, 130, 85) / 0.3 | K | **supersedes v2's RGB(120, 90, 60) / 0.2**: checked on screen, because two colours in this repo read near-black on first try |

### 11.5 The wire

`STATE_MIN_INTERVAL = 0.25 s` · `STATE_HEARTBEAT = 5 s` · `MATCH_STEP_HZ = 4` · `PUSH_SAMPLE_HZ = 2`.

### 11.6 Performance and correctness targets, each one checkable

| Target | How it is checked |
|---|---|
| `Phase.step` ≤ 20 µs at 16 participants | `match_phase.spec`: 10 000 steps under 200 ms |
| `Score.kill` ≤ 10 µs | `match_score.spec`: 10 000 kills under 100 ms |
| A whole 600 s drive simulated in ≤ 50 ms | `match_phase.spec`, simulated `dt` |
| Server raycasts per drive from this system | **0** |
| `MatchState` broadcasts | ≤ 1/s average over a drive, from `stats().broadcasts` |
| Per-player tables held after a player leaves | **0** (`Match.trackedPlayers()`) |
| `\|#Drivers − #Shooters\|` | ≤ 1 for every n in 1..16 |
| Typed-value harness problems from this task | **0** |
| **`Brain:step` (follower, with a sounder)** | **≤ 15 µs**: 10 000 steps under 150 ms (`boar_sounder.spec`). The lone-boar target stays ≤ 10 µs |
| **`ComputeAsync` requests per sounder** | **≤ 1 in flight, ≤ 2/s while fleeing**; `stats().pathRequests ≤ 12` over a 3 s live flee with five boars (§12.8) |
| **Sounder bookkeeping per step** | ≤ 30 neighbour-pair distances a frame at `MAX_ALIVE_BOARS = 6`; **0 new raycasts** |
| **Boars in `_boars` at any moment** | ≤ `BOARS_PER_DRIVE` within a drive, and `BOARS_PER_DRIVE ≤ Boar.CONFIG.maxBoars` asserted |
| Zero errors, zero skipped tests | `tests/TestKit.luau` fails the run otherwise |

### 11.7 NEW — the sounder numbers

**`Match.CONFIG.SOUNDER`** (the release; the drive's numbers):

| Field | Value | K? | Basis |
|---|---|---|---|
| `ENABLED` | `Flags.isOn("BOAR_SOUNDERS")` → `false` | | the one boundary read (§6.9) |
| `MAX_SIZE` | 5 | K | Karen: groups of 2–5 |
| `SIZE_WEIGHTS` | `{ 40, 20, 18, 12, 10 }` for sizes 1..5 | K | 40 % singles, 60 % groups, a five once in ten releases |
| `EXPECTED_SIZE` | 2.32 | | the weighted mean of the row above; **asserted equal to it**, so it cannot drift |
| `TAIL_SECONDS` | 90 | K | the last release lands at least this long before 0:00, so the sounder has time to reach the line |
| `GAP_MIN_SECONDS` | 45 | K | two sounders never arrive on top of each other |
| `GAP_MAX_SECONDS` | 180 | K | never more than three minutes of empty wood |
| `HOLDBACK_WARN` | 20 | | after this many consecutive hand-backs of one sounder, warn once, so a stall is visible instead of folkloric |

**`Boar.CONFIG.SOUNDER`** (the behaviour; the boar's numbers, derived at 1 stud = 0.28 m against
`BODY_SIZE = (2, 3, 5.5)`, `SPRINT_SPEED = 38`, `DETECT_RADIUS = 40`):

| Field | Value | K? | Basis |
|---|---|---|---|
| `SPAWN_RING_STUDS` | 10 | | 5 on a ring of 10 stand 11.8 studs apart with a 5.5-long body |
| `PAD_MARGIN_STUDS` | 4 | | the ring is clamped inside `spawnRadius − 4`, so it is 10 at a pad radius of 14 and of 30 (§0 item 4) |
| `SLOT_BACK_STUDS` | 9 | K | ~1.6 body lengths behind the leader |
| `SLOT_SIDE_STUDS` | 7 | K | two abreast, clear of each other |
| `FORMATION` (leader frame, +Z = behind) | slot 2 `(−7, 0, 9)`, 3 `(+7, 0, 9)`, 4 `(−3.5, 0, 18)`, 5 `(+3.5, 0, 18)` | K | a wedge ~18 studs wide — well inside a 96-stud hedge gate (§2) |
| `COLUMN_SPACING_STUDS` | 9 | | single file: slot *i* → `(0, 0, (i−1) × 9)` |
| `COLUMN_LATCH_SECONDS` | 1.5 | | how long `blockedAhead` holds the column |
| `SLOT_TOLERANCE_STUDS` | 5 | | inside it, cohesion is 0 and the follower matches the leader's speed |
| `NEIGHBOUR_STUDS` | 25 | | the boids neighbourhood |
| `SEPARATION_STUDS` | 7 | | 1.3 body lengths; below it, push apart |
| `COHESION` / `SEPARATION` / `ALIGNMENT` / `FLEE_WEIGHT` | 1.0 / **1.6** / 0.4 / 0.8 | | separation dominates (§16 source H) |
| `IDLE_COHESION` / `IDLE_SPREAD_STUDS` | 0.5 / 18 | K | a grazing sounder stays a loose group instead of marching in a wedge |
| `CATCHUP` | 1.15 | | capped at `SPRINT_SPEED` |
| `BREAK_STUDS` / `BREAK_SECONDS` | 60 / 4 | K | 1.5 × `DETECT_RADIUS`; then it is a lone boar |
| `SCATTER_SECONDS` | 6 | K | the sounder breaks up at the shot |
| `SCATTER_SEPARATION` | 3.0 | | they spread while scattering |
| `SCATTER_ON_HIT` | `true` | K | any hit, not only a kill |
| `LEAVE_ON_MORTAL` | `true` | K | a mortally wounded animal drops out of the sounder |
| `LEADER_PATHS_ONLY` | `true` | | one `ComputeAsync` per sounder (§6.8) |

---

## 12. How it is tested

`tests/server/` → `ServerStorage.Tests`; `tests/client/` → `ReplicatedStorage.ClientTests`. Specs **write
their own numbers rather than importing `CONFIG`** for the assertion, following
`tests/server/test_arena.spec.luau`, so a spec disagreeing with the config is a finding and not a
tautology. Rule 6: these test the player's path, not the harness.

**The gate for this task**: it touches `src/`, so `test` **and** `test2` (Director decision 2026-09-26),
both on a clean tree, both naming the code commit. And **`python tools/flags.py clear` before either
run** — `test` and `test2` refuse to start while any override is set, which is exactly the trap the
screenshot procedure in §12.10 walks into if it is done in the wrong order.

### 12.1 `tests/server/match_phase.spec.luau` — CHANGED, pure

Everything it asserts today stays. Added:

1. **THE FLAG-OFF IDENTITY PROOF.** With `SOUNDER.ENABLED = false`, a simulated 600-second drive emits
   exactly `BOARS_PER_DRIVE` `spawnSounder` effects, **every one with `size == 1`**, the first at exactly
   `FIRST_RELEASE_SECONDS`, the rest at 90 s ± `RELEASE_JITTER_SECONDS`, round-robin over the spawn
   markers in the same order as before, and `state.boarsReleased == state.soundersReleased` throughout.
   Written against literals, not against `CONFIG`.
2. With `ENABLED = true`: over 200 simulated drives (seeds 1..200) every size is in `1..MAX_SIZE`, the
   sizes sum to **exactly** `BOARS_PER_DRIVE` in every drive, and the observed size histogram is within
   ±20 % of `SIZE_WEIGHTS`.
3. `EXPECTED_SIZE` equals the weighted mean of `SIZE_WEIGHTS` to 0.01.
4. Determinism: the same seed and drive number give the same size sequence; two different drive numbers
   give different ones (so the drive is not the same drive twice).
5. The last release of every simulated drive is at or before `DRIVE_SECONDS − TAIL_SECONDS`, and every
   gap is within `[GAP_MIN_SECONDS, GAP_MAX_SECONDS]` before jitter.
6. **Hold-back, not drop:** with `aliveBoars = MAX_ALIVE_BOARS − 2` and a drawn size of 5, no
   `spawnSounder` is emitted, `boarsReleased` is unchanged, and when the count falls the **same size** is
   released later.
7. `Phase.releaseFailed(state, now, 5)` gives back one sounder and five boars and makes the next release
   due immediately; a second call from `boarsReleased == 0` is a no-op.
8. `boarEntries + size > boarCapacity` blocks the release even when `aliveBoars` is low — the carcass
   case, which is the one hazard 1 in §6.3 is about.
9. A hitch (`dt = 5`) advances one phase at most and never releases twice in one step.
10. 10 000 steps under 200 ms.

### 12.2 `tests/server/match_roster.spec.luau` — unchanged

Every n from 1 to 16 balances to within one; n = 1 gives one shooter; the odd player follows
`ODD_PLAYER_TEAM`; `SWAP_TEAMS_EACH_DRIVE` swaps where sizes allow; order-independence; no `Random`, no
service, no Instance reachable from the module.

### 12.3 `tests/server/match_score.spec.luau` and `match_safety.spec.luau` — unchanged

Score: every zone exactly; `unknown` scored as `body` and counted; an assist at exactly
`ASSIST_MIN_DAMAGE` and none one below; the killer never also assists; push credit inside both
`PUSH_RADIUS` and `PUSH_WINDOW` and none outside either; `ESCAPE_WOUNDED`; a violation worth
`SAFETY_PENALTY` with points allowed negative; `leave` keeps the row; the full tie-break chain; inputs
never mutated and results frozen; 10 000 kills under 100 ms.

Safety: a driver on the ray at 50 with `stopAt = 100` → violation; the same driver with `stopAt = 40` →
none; **`stopAt` exactly on the driver's surface → violation, because of `SAFETY_BODY_STUDS`**; 12.0 studs
off → violation, 12.1 → none; behind the muzzle → none; no drivers → none; a zero-length `aim` → none and
no error; two qualifying drivers → one violation; `Penalty.expired` in **both** flag states, through the
parameter.

### 12.4 `tests/server/match_live.spec.luau` — CHANGED, live

Everything it asserts today stays (the drive left `Waiting`; two `Team`s with `AutoAssignable = false`;
shooters armed and **holding** a gun; the markers and the line's direction; a frozen-all-the-way-down
snapshot; one entry per player; `Downed` and `SafetyViolated` connected; the config frozen). Added:

11. **The cross-system invariants, in one `it`, because three numbers in two owners have to agree:**
    `Match.CONFIG.BOARS_PER_DRIVE <= Boar.CONFIG.maxBoars`,
    `Match.CONFIG.MAX_ALIVE_BOARS >= Match.CONFIG.SOUNDER.MAX_SIZE`,
    `Match.CONFIG.MAX_ALIVE_BOARS <= Boar.CONFIG.maxBoars`, and
    `Boar.CONFIG.SOUNDER.SPAWN_RING_STUDS + Boar.CONFIG.SOUNDER.PAD_MARGIN_STUDS <= Map.SPAWN_PAD.radius`.
    This is what makes "Karen raised the budget to 10" fail a spec instead of stalling a drive.
12. `Match.CONFIG.SOUNDER.ENABLED == Flags.isOn("BOAR_SOUNDERS")` and, on a clean run, **false** — so a
    harness PASS can never have been produced with the dark path live.
13. `world.boars:capacity()` and `:count()` exist and the owner's dispatch fills `boarEntries` and
    `boarCapacity` (read from `Match.stats()` after one tick: `sounderHoldbacks == 0` on an empty field).

### 12.5 `tests/server/test_arena.spec.luau` — unchanged

Exactly one `DrivenHunt.DriveLine`, 8 posts, ≥ 1 driver start, 4 boar spawns, ≥ 1 tree;
**the line's `LookVector.Z > 0.99`** (the cheapest possible check on the difference between the safety
rule firing on the right shots and on exactly the wrong ones); posts inside the plate and between `exitZ`
and the driver start; posts 40 apart and stably sorted; `build` twice adds no second set of tags. It
spells the tag strings literally **on purpose** — a spec that re-derives the contract from the contract
checks nothing (`map-generator.md` §4.2).

### 12.6 `tests/server/boar_brain.spec.luau` — CHANGED, pure, one case

1. **The lone-boar path is untouched:** with `obs.sounder == nil` the intent sequence over 600 steps from
   a fixed seed is identical to a recorded baseline, and a **leader**'s intents (`obs.sounder` with
   `isLeader = true`, one neighbour behind it) are identical to a lone boar's for the same threats. The
   leader is today's code; this is the assertion that says so.

### 12.7 `tests/server/boar_sounder.spec.luau` — NEW, pure, no physics, no Workspace

Requires `ServerScriptService.Boar` (side-effect-free on require) and drives `Brain:step(1/60, obs)` with
a fixed `Random.new(1)` and hand-written observations.

1. A **follower** never returns a `pathRequest`; a **leader** does, on the exit line, inside the bounds
   minus `EDGE_MARGIN`, on the far side of the threat in X.
2. A follower 30 studs off its slot closes the distance over 60 simulated steps and then stays within
   `SLOT_TOLERANCE_STUDS` without oscillating (its heading reverses less than once per second).
3. **Separation dominates:** two members 3 studs apart move apart on the next step even when the slot lies
   through each other, and the resulting direction is at most `TURN_RATE × dt` from the previous one (the
   turn-rate limit is not bypassed).
4. A follower's speed setpoint never exceeds `SPRINT_SPEED`, never exceeds `leader.speed × CATCHUP`, and
   matches the leader's within 1 stud/s inside the tolerance.
5. `blockedAhead = true` puts the follower in **column** offsets, and it stays there for
   `COLUMN_LATCH_SECONDS` after the probe clears.
6. `scattering = true` with `leader = nil`: cohesion and alignment are gone (the direction no longer
   depends on the centroid), separation is stronger, and the member still produces a non-zero velocity
   away from the threat — it never freezes.
7. **Herd panic:** an `IDLE` follower with `leaderState == "FLEE"` and no threat inside `DETECT_RADIUS`
   enters `FLEE` within one `SENSE_INTERVAL`; with `leaderState == "IDLE"` it stays `IDLE`.
8. **Herd calm:** a follower does not return to `IDLE` while `leaderState` is `FLEE`, even after
   `CALM_TIME` beyond `CALM_RADIUS`.
9. A wounded follower (`obs.wound.severity == "mortal"`) still runs and its setpoint is scaled by
   `speedScale` exactly as a lone boar's is.
10. Determinism: two brains with the same seed and the same observation sequence produce identical
    intents.
11. `dt = 5` is clamped; the setpoint change is no larger than at `DT_CLAMP`.
12. 10 000 follower steps under 150 ms.

### 12.8 `tests/server/boar_body.spec.luau` — CHANGED, live: one real sounder of five

Added as its own `describe`, in the spec's **own** world — an anchored plate at **y = 500**, well clear of
the arena, with `field = { bounds = ±55, exitZ = −40, groundY = 500 }`, a scripted `threats()` and its own
runtime, torn down in `afterAll`, exactly as the existing live boar block does. Through the public
interface only:

1. `spawnSounder(center, 5, 14)` creates **exactly 5** parts, every one inside 14 studs of the centre and
   at least `BODY_SIZE.X` from every other; `sounders()` reports one sounder with 5 members and one
   leader.
2. `spawnSounder(center, 5, nil)` when only 3 slots are left under `capacity()` creates **nothing** and
   returns `{}` — all-or-nothing.
3. `spawnSounder(center, 1, nil)` creates one boar and **no** sounder record (`sounderOf(id) == nil`).
4. With the threat switched on, after 3 s: every live member's flat distance to the leader is
   ≤ `BREAK_STUDS`, every member's speed ≥ 0.4 × `SPRINT_SPEED`, and **every member's
   `CFrame.UpVector.Y > 0.9`** — five colliding 23-stud bodies driven at 6000 of force is the one thing
   here that can physically go wrong, and this is the assertion that sees it.
5. Killing the leader (through `takeHit` with a lethal slug to the head) promotes a new leader within one
   step (`leaderPromotions == 1`), latches `scatterFor > 0`, and the survivors' pairwise spread **grows**
   over the next 2 s.
6. A member teleport-free drag past `BREAK_STUDS` for `BREAK_SECONDS` (by moving the plate's threat so it
   runs the other way) leaves the sounder: `memberIds` shrinks, `membersLeft == 1`.
7. A mortal wound on a follower takes it out of the sounder on the next step (`LEAVE_ON_MORTAL`).
8. **The path budget:** `stats().pathRequests <= 12` over the 3 s flee with five boars, and
   `pathFailures == 0` — so a silent permanent fallback to straight-line flee is a failure, not an
   invisible degradation.
9. The last member alive dissolves the sounder (`soundersDissolved == 1`, `sounderOf` → `nil`).
10. `Runtime:clear("driveOver")` removes all five through the existing despawn path, fires `Despawned`
    five times, and leaves no sounder behind.

### 12.9 Client specs — no change, and why

`tests/client/match_client.spec.luau` keeps its six assertions, including the parent-visibility chain for
the score panel (the assertion that makes "a visibility audit ignored parent visibility and certified a
blank screen twice" impossible to repeat). **Nothing on the wire changes** (§9.1), so there is nothing new
for a client spec to assert, and **no new input scenario**: the drive consumes no player input, and a
scenario that pressed keys nothing is bound to would be evidence of nothing.

### 12.10 Screenshots (rule 5) and what only a human can do

**The harness can run two players.** `test2` exists and is in the merge gate
(`CLAUDE.md`, git workflow step 4; `[harness2] PASS: n/m checks @ <commit> (clean tree)`), and all three
reports are checked since Task 36. This **supersedes v2 §12.6**, which concluded the harness could not,
and the v2 "one cheap probe" and "queued harness change" items are spent.

**The screenshot for this task, and the order matters.** The sounder path is dark on a clean tree, so the
harness run proves nothing visual. The sequence, which the Builder can do without Karen:

1. `python tools/studio_mcp.py test` and `test2` on the clean tree, **with no override set** — the merge
   evidence.
2. `python tools/flags.py set BOAR_SOUNDERS on` (Edit mode), then `python tools/flags.py` to see it.
3. Start Play, `python tools/flags.py live` to confirm what it resolved, wait for the first release
   (`FIRST_RELEASE_SECONDS = 20`), and
   `python tools/studio_mcp.py capture sounder-crossing <camera> <look-at>` — **from behind a post,
   looking up the drive**, which is Karen's reference framing.
4. `python tools/flags.py clear` **before any further harness run**. Forget it and `test` refuses, with
   the clear command printed.

Three shots, each inspected by the Builder and described as what is on screen, not as what should be:

1. **A sounder of five at the spawn pad**, grazing: do they read as a group, or as five unrelated boxes?
2. **The same sounder crossing the line** in front of a post: is it a wedge, a column or a pile-up?
3. **A sounder one second after a shot**: is the scatter visible?

**The first size is reproducible, and if it is a 1 the Builder changes the seed.** `SEED` is a config
number and the size is a pure hash of `(SEED + driveNumber, index)`, so `boar_sounder.spec`/`match_phase.spec`
prints the first three sizes for the committed seed through `TestKit.note`. If the committed seed opens
with a single, the Builder picks a seed whose first release is ≥ 3 and records that in the request. That
is a one-line, reviewable choice — not a debug switch, which is what a `FORCE_SIZE` dial would be.

**`NEEDS KAREN` — the playtest, with the exact clicks.** The one thing no tool here can judge:

> 1. Director, Edit mode: `python tools/flags.py set BOAR_SOUNDERS on`, then `python tools/flags.py`.
> 2. Studio → **Test** → **Clients and Servers** → **Players: 2** → **Start**.
> 3. One as a driver from the assembly/start pad, one as a shooter on a post.
> 4. Say which of these is wrong: a sounder arrives as a group and stays one until it is shot at; it
>    breaks up at the shot and does not re-form; a mortally wounded pig drops out and runs on alone; the
>    group is not a traffic jam and does not push each other over; the drive does not feel empty between
>    sounders; and the gaps between arrivals are right.
> 5. Director: `python tools/flags.py clear`.

### 12.11 Process hazards

- **Rojo 7.7.0 panics when a watched file vanishes**, and a large branch switch alone crashed it once.
  Stop `rojo serve` before switching; expect a **NEEDS KAREN** Connect click. This task adds one or two
  files (`tests/server/boar_sounder.spec.luau`, and nothing else new), so the risk is the branch switch,
  not the change.
- **`tools/flags.py clear` before every harness run** (§12.10). A forgotten override does not silently
  reset: the harness refuses, which is the design working.
- **If 57a and 57b are separate tasks**, 57b branches from 57a's branch and targets it (a stacked PR),
  and says so in `Base:`.

---

## 13. Rows for `GAME_DESIGN.md` — ready to paste

Rule 3 requires the owners table to mirror this file. **Two amended rows; no new row**, because sounders
create no new owner — which is the point of §6.7.

- **Boar AI** (append to the existing owner cell): "… Since Task 57 it also owns **sounders**: the
  runtime is the only writer of a sounder's existence, membership, leader and scatter timer
  (`Runtime:spawnSounder`, `Runtime:sounders`, `Runtime:sounderOf`), it promotes a new leader and
  dissolves a sounder of one, and it assembles each member's `obs.sounder` once per step so that
  `Boar.Brain` never holds a reference to another boar. The drive says only **how many** boars a release
  is and **where** ([drive design](docs/design/drive.md), "the sounder's behaviour, and who writes it").
  Exactly one `PathfindingService` route is computed per sounder, for its leader."
- **Game state / the drive** (append): "… Since Task 57 a release is a **sounder** of 1–5 animals:
  `Match.Phase` draws the size from `Match.CONFIG.SOUNDER.SIZE_WEIGHTS` with a deterministic hash (never
  `Random`), paces the releases across the drive, and hands a refused release back rather than dropping
  it; `Match.Markers` publishes `spawnRadius` from `Map.SPAWN_PAD` so a sounder is spread only where the
  map guarantees flat ground. It writes no sounder state and never asks who leads one. Behind the flag
  `BOAR_SOUNDERS`, default OFF ([feature flags](docs/design/feature-flags.md))."

`Input` stays `_unassigned_` as a system: this design binds no input and reserves no prefix.

---

## 14. Open decisions — none of them blocks building

Every one has a default in `Match.CONFIG`, `Boar.CONFIG` or this document, so the Builder can build, test
and report without an answer.

### Karen (feel) — the "check this" list

1. **Do sounders read as animals or as a queue?** `SLOT_*`, `SEPARATION_STUDS` and the wedge in §11.7 are
   the dials. Shot 3 in §12.10 and step 4 of the playtest.
2. **Is a scatter of 6 s right?** Shorter and the group barely breaks; longer and a sounder never re-forms
   inside one drive.
3. **Should a hit scatter them, or only a kill?** Default: any hit (`SCATTER_ON_HIT = true`).
4. **Should a wounded pig leave the group?** Default yes. The alternative is the whole sounder crawling to
   the line at a dying animal's speed.
5. **Are 40 % singles right?** `SIZE_WEIGHTS`. Her reference is a sounder, but a lone boar is the commoner
   animal in a real drive.
6. **Is ten minutes right?** `DRIVE_SECONDS = 600`.
7. **Are the points right?** head 100 / chest 80 / body 50 / legs 30. Is a head shot worth more than three
   leg kills? And **should a sounder pay a group bonus?** Default no (§7.1).
8. **Is "tied until the drive ends" too harsh?** The flag is already there and already
   switchable without a commit.
9. **Does the drive feel empty between sounders?** This is the one number I would expect her to change:
   six animals in bites of ~2.3 is ~3 encounters. **My recommendation: play it at 6 first.** If the wood
   feels empty after the third sounder, `BOARS_PER_DRIVE = 10` is one number and §12.4 item 11 forces
   `MAX_ALIVE_BOARS` and `Boar.CONFIG.maxBoars` to move with it rather than failing at run time.
10. **Is 8 posts the right line**, and does standing on a post feel like a place to be?

### Director (scope)

- **H. `MAX_ALIVE_BOARS` 4 → 6 is outside the flag** (§6.3). Default: **do it**, because a 5-boar release
  is impossible otherwise and the singles schedule never approaches 4. The alternative is a flag-dependent
  number, which is two states of an integer and worse to reason about.
- **I. `Map.SPAWN_PAD.radius` is 14 in the tree and 30 in the map design** (§0 item 4). Default: **build
  against the contract, clamped**, so this task needs no map change and no coordination. Whoever builds
  the pad widening changes one number and nothing here moves.
- **J. Split into 57a (the sounder exists) and 57b (the drive releases it)** (§0 item 5). Default:
  **split**, and my recommendation.
- **K. No collision group for boar-on-boar jostling** (§1.2). Default: separation steering only. If §12.8
  item 4 or shot 3 shows them shoving each other over, a collision group is its own small design with its
  own owner row, because it is global place state.
- **L. No group bonus and no "sounder" field on the wire** (§3.3, §7.1). The brief asked for a mix of
  singles and groups, not a new scoring category.
- **M1. `docs/design/boar-ai.md` is out of date the moment 57a lands**, and this document is normative for
  sounders until it is regenerated (§9.4). That regeneration is an Architect run, not a Builder edit; it
  is the same delta `map-generator.md` §19.1 A4 already filed. **Default: run it with the next boar task,
  not before 57a**, so it is written against built code.
- **M2. `MIN_PLAYERS = 1` is a Milestone-1 concession** (§11.1) and has to go back to 2 before release.
  Unchanged by this revision; repeated because it is the kind of thing that ships by accident.

---

## 15. What I could not verify (rule 8)

- **Anything requiring Roblox Studio.** No Studio in this session (`.agent-evidence/INDEX.md`). Every
  claim about how five colliding, `LinearVelocity`-driven bodies behave — whether separation steering is
  enough to stop them shoving each other over, whether `AlignOrientation` at
  `ALIGN_RESPONSIVENESS = 25` keeps a jostled boar upright, and what `ComputeAsync` costs with two
  leaders pathing at once — is derived from the numbers in the repo and from documentation, **not
  observed**. §12.8 items 4 and 8 are the checks, and they are the two assertions I would look at first.
- **The exact `SEED = 1` size sequence.** I cannot run `Phase.unitHash`, so I do not know whether the
  committed seed opens with a single or a group. §12.10 makes the spec print it and makes the seed choice
  the Builder's, recorded.
- **`Map.SPAWN_PAD.radius = 30`.** Declared in `docs/design/map-generator.md` §4.1/§15.1, **not** in
  `src/shared/Map/init.luau`, which says 14. I have not read a task that builds it. The design is written
  so that this cannot matter.
- **The generated map's geometry.** The road, the gates and the pads are read from
  `docs/design/map-generator.md` §15.1, not from a built world: `Map.EXPECTED_WORLD` is still `"arena"`.
  The 96-stud gate that §2 leans on is that design's number, and if it shrinks, the column latch in §6.7
  is what catches it — which is why the latch is not conditional on the gate.
- **Whether a follower that never paths gets wedged in the generated wood** (~2,900 trunks,
  `map-generator.md` §15.2) rather than in the grey arena. The stuck-escape in §6.8 (a twice-stuck
  follower may path) is my mitigation and it is unmeasured. It is the most likely thing in this design to
  need a second round, and the cheapest way to see it is Karen's playtest, not a spec.
- **The external sources' URLs, licences and maintenance status.** No network this session. Sources A–F
  are carried from the v2 document and from `docs/design/boar-ai.md` §8, where they were first assessed;
  G–I are added here from my own knowledge. **The Builder confirms each one in
  `docs/research/2026-09-25-drive.md` before relying on it** (rule 1; `docs/research/` is the Builder's
  file, not mine). If OpenSteer (source I) cannot be confirmed, nothing changes: it is cited as the
  reference implementation of a pattern that sources G and H already document, and no code is taken.
- **CI and harness status at this commit.** Lint and build are clean in the evidence
  (`.agent-evidence/lint-selene.txt`, `lint-stylua.txt`, `rojo-build.txt`). No harness or CI output is in
  `.agent-evidence/`.
- **Every number in §11.7 is a first guess.** None has been played. They are arithmetic against
  `BODY_SIZE`, `SPRINT_SPEED`, `DETECT_RADIUS` and the gate width, not measurement, and §14 is where they
  get their real values.

---

## 16. External sources

Rule 1 and rule 2: this is where the design borrows, and where it says so. A–F are carried forward from
the v2 document (they are where the drive's own decisions came from); **G, H and I are new and are the
sounder's sources**.

### A. Roblox `Teams`, `Team` and `Player.Team`
<https://create.roblox.com/docs/reference/engine/classes/Teams> ·
<https://create.roblox.com/docs/players/teams> · first-party creator docs (creator-docs is CC BY 4.0), the
API ships with the engine · actively maintained.
**Good:** a server-authoritative, automatically replicated team field a client cannot write, with free
player-list colouring. One representation enforced by the engine rather than by policy.
**Bad:** `Team.AutoAssignable` defaults to `true`, so Roblox becomes a silent second writer of the exact
field this system owns; `Teams` is not Rojo-owned, so the instances are created at run time and are
invisible to the harness's file comparison.
**Adopted:** two `Team`s created by `Match.Body.ensureTeams` with `AutoAssignable = false`; `Player.Team`
as the one representation, compared by name.

### B. Roblox remote events and `Workspace:GetServerTimeNow`
<https://create.roblox.com/docs/scripting/events/remote-events-and-callbacks> ·
<https://create.roblox.com/docs/reference/engine/classes/Workspace#GetServerTimeNow> · first-party
(CC BY 4.0) · actively maintained.
**Good:** a clock both sides agree on turns a 600-second countdown into **one** number pushed once per
phase; `FireAllClients` is the right shape for state every player sees identically; the page states flatly
that client input is untrusted, which is why this system has no inbound remote.
**Bad:** no rate limiting and no schema validation; a table that is neither a dense array nor a pure
dictionary does not survive the wire; `GetServerTimeNow` is easy to confuse with `os.time`, `tick` and
`os.clock`, three of which mean nothing across the wire.
**Adopted:** two outbound remotes, none inbound; a snapshot with a floor, a forced push per phase entry
and a heartbeat; `phaseEndsAt` as a server timestamp; every table dense.

### C. Roblox `CollectionService` tags
<https://create.roblox.com/docs/reference/engine/classes/CollectionService> · first-party (CC BY 4.0) ·
actively maintained.
**Good:** `GetTagged` answers "give me every post" in one call with no Workspace walk, which decouples the
drive from where the map put things — exactly what the M2 switch needs.
**Bad:** a tag is a string with no schema, so a typo yields an empty list and a silently dead rule; tags
are **not** compared by this repo's harness, unlike attributes.
**Adopted:** five `DrivenHunt.*` tags whose **strings live once** in `Map.TAGS`, read into one frozen
`MarkerSet` with a named `missing` list and a loud refusal to start a drive against an incomplete map.

### D. Driven-hunt safety practice (Deutscher Jagdverband and equivalent guidance on *Drückjagd* discipline)
<https://www.jagdverband.de/> · copyrighted web content; **facts and technique taken, no text and no
code** · maintained as public guidance.
**Good:** it is the source of the rule Karen is reproducing, and it says what the offence actually is —
you stand on your assigned post and you do not shoot into the drive. It also supplies the reason the
punishment is social rather than mechanical.
**Bad:** qualitative and regionally variable; metres of real terrain, not studs; it assumes a hunt leader
who can see everything, which a server cannot.
**Adopted:** the offence, the post discipline, and the shape of the sanction (immediate, public, for the
rest of the drive). It is also where the vocabulary of this revision comes from — a *Rotte* is a sounder,
and it is led by an old sow. **Not adopted, and named so it is not invented by accident:** the real rule
that the lead sow is not to be shot. That is a scoring rule Karen has not asked for (§14 Karen item 7).

### E. Rodux — named, deliberately **not** adopted
<https://github.com/Roblox/rodux> · Apache-2.0 · Roblox's own Redux port; maintained but quiet.
**Good:** the canonical Roblox answer to "one store, one place state changes".
**Bad:** a Wally package, a `default.project.json` mapping and a Connect click; its `dispatch` lifecycle
would own the transitions that §4 needs to be *pure and returned*, so a spec could no longer assert on an
effect list.
**Decision:** the pattern is taken, the package is not — `Phase.step` returning a new frozen state plus a
list of effects is a reducer with the side effects made values. (`docs/research/2026-09-25-drive.md`
corrects the v2 document's claim that Rodux is archived.)

### F. Borrowed from inside this repo (rule 2 applies to internal patterns too)
`src/server/Boar/init.luau` and `docs/design/boar-ai.md` §3–§4: the folder module that owns state and does
nothing on `require`; a pure decision module driven by an injected world and exported for specs; one
module that is the only writer of Instances; every number in one `CONFIG`; `stats()` as the cheap way to
assert on a live system; `step(dt)` split from `run()` so a spec drives simulated time.
`src/server/Weapon/init.luau` and `docs/design/shotgun.md` §5.3–§5.4: injected providers as the way one
owner asks another a question; `forget(player)` as the named lifecycle; deep-frozen published state.
`src/shared/Flags/init.luau` and `docs/design/feature-flags.md` §10: one boundary read, passed inward as a
parameter.
**Adopted whole.** The fourth system in a repo either keeps the conventions or starts eroding them.

### G. Craig Reynolds, *Steering Behaviors For Autonomous Characters* (GDC 1999) — **the sounder's primary source**
<https://www.red3d.com/cwr/steer/gdc99/> · published paper, freely readable; **technique taken, no code** ·
frozen (1997/99), and still the standard reference. Already this repo's source for wander, flee and the
probe turn (`src/server/Boar/Brain.luau` header), so adopting its *leader following* costs no new
vocabulary.
**Good:** it defines exactly the three behaviours this design needs and names them the way the code will:
**leader following** (offset pursuit of a point behind the leader, plus "get out of the leader's way" for
a follower caught in front of it), **separation**, **cohesion** and **alignment**, and — the detail that
matters most — it insists steering is a *weighted, truncated* combination of behaviours, so one term can
dominate when it has to. It also keeps steering strictly separate from locomotion, which is the split this
Brain already has (`slew` + `ACCEL` on the setpoint).
**Bad:** it has no map knowledge at all, so pure steering walks a follower into a dead end behind a hedge;
it says nothing about how a follower should behave when the leader dies; and its arbitration advice is
qualitative — the weights in §11.7 are this design's, not the paper's.
**Adopted:** leader following as the formation rule, on top of the leader's navmesh route; the weighted
truncated sum; the strict steering/locomotion split.

### H. Craig Reynolds, *Flocks, Herds, and Schools: A Distributed Behavioral Model* (SIGGRAPH '87) — the boids paper
<https://www.red3d.com/cwr/papers/1987/boids.html> · ACM-published paper; technique taken, no code ·
frozen (1987), the origin of the three rules.
**Good:** it is where cohesion/separation/alignment come from, and it makes the point this design leans on
hardest: **the rules must be prioritised, with collision avoidance winning**, or the flock interpenetrates
— which for five `CanCollide = true` bodies at `MAX_FORCE = 6000` is not a graphical artefact but a
physics fight. It also gives the *neighbourhood* idea (a boid only sees flockmates within a radius), which
is why `NEIGHBOUR_STUDS` exists and why the cost stays O(n²) over n ≤ 5 rather than over the whole field.
**Bad:** a flock with no leader and no goal, in open 3D space with no obstacles and no ground; it has
nothing to say about a herd being driven toward a line, which is the entire mechanic here.
**Adopted:** the three rules as *terms*, separation weighted to dominate (`SEPARATION = 1.6` against
`COHESION = 1.0`), and the neighbourhood radius. **Not adopted:** leaderless flocking, because a sounder
in a drive has a direction and something has to own the route.

### I. OpenSteer (Craig Reynolds' reference implementation) — named, **not adopted**
<https://opensteer.sourceforge.net/> · MIT licence · **unmaintained** (last release mid-2000s; the
SourceForge project is dormant).
**Good:** it is the canonical implementation of exactly this decomposition — `steerForSeparation`,
`steerForCohesion`, `steerForAlignment`, `steerToFollowPath`, `steerForPursuit` — and it settles the
question of how the terms compose in practice, which the papers leave qualitative.
**Bad:** C++ with an OpenGL demo harness, no Luau port, and unmaintained for over a decade. Vendoring or
porting it would be the "invented foundation" failure with a licence attached.
**Decision:** **pattern confirmed, code not taken.** This is the same call `docs/design/boar-ai.md` §8
made about SimplePath, for the same reason, and it is recorded here so it is not re-researched.

### The pattern adopted overall

A pure reducer returning state plus an explicit effect list (E's shape without E's package), inside a
folder-module owner with an injected world (F); Roblox's own `Team` as the single representation of team
membership (A); tag-based world markers so the map can move everything without this system changing (C);
two outbound remotes with a server timestamp and nothing inbound (B); a safety rule whose *geometry* is
the weapon's and whose *verdict and punishment* are the drive's (D); and, new in this revision, **a
sounder as one navmesh route for a leader plus Reynolds leader-following with boids separation, cohesion
and alignment blended into the setpoint the Brain already limits** (G, H, I), with the release shape — how
many, how often, how spread — decided by the same pure, seeded, `Random`-free machine that already decides
the phase.

Nothing here is invented except `Penalty.judge`'s point-to-ray test (a dot product, a clamp and a
magnitude, with eight assertions against it) and the **wedge offsets** in §11.7, which no source specifies
because a formation's shape is a taste value — which is why it is marked **K** and why it is Karen's first
question in §14.
