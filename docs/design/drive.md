# Design: drive (teams, the drive, points, the score screen, the safety penalty, sounders, **the match**)

System: `drive` — one drive is one round (teams, a 10-minute timer, boars released into the drive,
individual points, a score screen, the comic penalty for shooting toward the drivers), and **since this
revision `DRIVES_PER_MATCH` drives are one MATCH**, with points accumulating across it, a match result
screen, and a new match afterwards. `ROADMAP.md` steps **1.6**, **1.7** and Milestone 3's "a match loop
with several drives".

**Revision v4, Task 84.** It replaces the v3 document (Task 57) **in full**. Nothing is removed: every v3
section number is preserved, because `src/server/Match/init.luau`, `Match/Phase.luau`, `Match/Markers.luau`,
`Match/Body.luau`, `Match/Roster.luau`, `Match/Score.luau`, `Match/Penalty.luau`,
`src/server/MatchBoot.server.luau`, `src/server/TestArena.luau`, `src/server/Boar/init.luau`,
`src/server/Boar/Brain.luau`, `src/server/Weapon/init.luau`, `src/shared/Drive/init.luau`,
`src/client/Match/init.luau`, `src/client/Hud/init.luau`, `src/client/MatchBoot.client.luau` and nine spec
files all cite "drive.md section N" (evidence: the `-- Design: docs/design/drive.md` header line in each).
New material is appended inside the section it belongs to. The v3 text is in git history at commit
`4274580`; if the Director wants a file copy, the Builder archives it under `backups/` with a note (rule 7).

Three reasons for the revision, in precedence order:

1. **`reviews/task-84/BRIEF.md`** (the Director, 2026-09-27): a match is several drives. That is the new
   **§4.5**, **§7.5**, **§9.5**, **§11.8**, **§12.12**, and the amendments to §1, §3.2, §3.6, §4.1, §4.3,
   §4.4, §9.1, §9.2, §9.3, §11.1, §11.6, §12.1, §12.3, §12.4, §12.9, §12.10, §13, §14.
2. **v3's §0 is stale against the tree.** The world is no longer the arena: `src/shared/Map/init.luau`,
   `Map.EXPECTED_WORLD = "map:v1"` (Task 79), `Map.SPAWN_PAD` is `{ radius = 30, blend = 40,
   tolerance = 0.75 }` (not 14), `ArenaBoot` returns early, the sounder is **built** (`Runtime:spawnSounder`,
   `Boar.CONFIG.SOUNDER`, `Match.CONFIG.SOUNDER`) and still **OFF**, and the outfits are built and OFF
   (`Match.CONFIG.OUTFITS_ENABLED`). §0 states what is there now.
3. **Two numbers the brief forces into the open**: `MIN_PLAYERS` must be 1 in Studio and 2 live (brief
   item 8, §11.1), and a 43-minute match cannot be photographed or playtested by hand (§12.10).

Architect, 2026-09-27, read-only session: Read, Grep, Glob only. No Studio, no network. Evidence
precomputed in `.agent-evidence/` (`INDEX.md`), commit `4274580e8f8e6816d5237c3b8b1b10afda683a1d`. Lint and
build are clean in that evidence (`lint-selene.txt`, `lint-stylua.txt`, `rojo-build.txt`); no harness or CI
output is in it.

Inputs, in precedence order: `reviews/task-84/BRIEF.md`, the code at this commit, `reviews/task-57/BRIEF.md`,
`docs/design/map-generator.md`, `docs/design/feature-flags.md`, `docs/design/boar-ai.md`,
`docs/design/hit-zones.md`, `docs/design/shotgun.md`, `docs/design/camera.md`, `GAME_DESIGN.md`,
`CLAUDE.md`, `docs/PROJECT_CONTEXT.md`.

**Test of this document:** a Builder can build the match from it without asking a question, and can read
the drive as it stands today without opening v3. Every number is here, every owner is named, every
interface is written out, and every file that changes is in one table (§3.6).

---

## 0. Where the tree actually is, stated first because it decides the work

1. **1.7a, 1.7b, the sounder and the outfits are built and merged.** `src/server/Match/` has `init.luau`,
   `Phase`, `Roster`, `Score`, `Penalty`, `Markers`, `Body`. `Runtime:spawnSounder`, `Runtime:sounders`,
   `Runtime:sounderOf`, `Runtime:capacity`, `Runtime:count` exist (`src/server/Boar/init.luau`).
   `Match.Body.dressFor`/`dress` exist. No precondition of this revision is unmet.
2. **A drive loops forever and nothing accumulates.** `Phase.step`'s `Scoring` branch goes to
   `enterAssigning` or `enterWaiting`, `enterAssigning` increments `driveNumber` and resets the release
   counters, and the owner rebuilds the board from scratch on every entry to `Assigning`
   (`src/server/Match/init.luau`, `dispatch`: `board = Score.new()` under
   `if state.phase ~= before and state.phase == "Assigning"`). So a session never ends and nobody ever
   wins anything. **That is the hole this revision fills, and it is the whole of it.**
3. **The world is the generated map.** `Map.EXPECTED_WORLD = "map:v1"`, `Map.FIELD` is the 1,240 × 1,680
   corridor with `exitZ = -820`, `Map.EXPECTED_COUNTS.tree = 12`, `Map.SPAWN_PAD.radius = 30`. The arena is
   the rollback and `ArenaBoot` returns early. §2 and §6.1 give both worlds; nothing in this revision
   depends on which is live.
4. **Two flags are OFF and stay OFF here**: `BOAR_SOUNDERS` and `ORANGE_OUTFITS`
   (`src/shared/Flags/init.luau`, `Flags.DEFAULTS`). This revision reads neither and changes neither row.
   It adds one row of its own, `SHORT_MATCH`, and that flag is an instrument, not a game path (§12.10,
   §14 Director item **N**).
5. **`Flags.MAX_FLAGS = 12`** and three rows exist, so a fourth is legal.
6. **Recommended task split** (Director item **O**), at the line that leaves no half-owned system:
   - **84a — the match exists (server only)**: `Phase` (the counter, `MatchOver`, abandonment), `Score`
     (`accumulate`, `drop`, `winners`), the owner (the fold, the reset, the snapshot fields, `CONFIG`,
     `stats`), and four server specs. No client file changes; the new snapshot fields simply ride the wire
     unread.
   - **84b — the player sees it (client only)**: `src/shared/Drive/init.luau` layout numbers, the Hud's
     result panel and the `MATCH` column, the client spec, the screenshots and Karen's playtest.
   **My recommendation: split.** It is ~12 changed files as one task, and a counter bug and a panel bug
   look identical from the outside (a blank screen at the end of drive 4). **The honest cost of splitting,
   named:** with 84a merged alone, the 30 seconds of `MatchOver` show the drive bar reading
   `DRIVE 4/4   MATCHOVER   0:29` and no panel. That is an ugly intermediate state, not a broken one, and
   84b is the next task. One task is also buildable exactly as written.

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

1. **One drive = one round.** 10 minutes, then a score screen, then the next drive.
2. **NEW — `DRIVES_PER_MATCH` drives = one match** (default 4). Points accumulate per player across the
   match, keyed by `UserId`. After the last drive's `Scoring` there is a **match result screen** for
   `MATCH_RESULT_SECONDS`, ranking by match points, naming the top player the winner and sharing a tie.
   Then a new match starts with every total at 0.
3. **NEW — the match survives a gap.** Too few players falls back to `Waiting` as today and **keeps** the
   match counter, so the match resumes when people return, unless `Waiting` lasts longer than
   `MATCH_ABANDON_SECONDS`, and then the match resets.
4. **Two teams of equal size.** DRIVERS push boar toward SHOOTERS on posts along a line. v1: drivers on
   foot, no dogs. `DRIVERS_MAY_SHOOT` is a config switch, default OFF.
5. **Individual points per boar,** by the zone of the killing shot. Wounds and escapes count for less or
   nothing.
6. **The safety rule:** a shooter who fires at a driver is tied to a tree until the drive ends, visibly.
   Players are not damageable (`docs/design/shotgun.md` §15 item C), so this rule, not damage, is the
   answer to shooting at people.
7. **Posts, the line, spawns and tie trees are found by `CollectionService` tags,** so the map places them
   without this system changing.
8. **Several boars per drive, released over the drive's length, as a mix of singles and sounders of 2–5.**
   The drive decides *when* and *how many*; the boar's owner decides everything else.
9. **10–16 players, and it must work with 1** (the harness's single Play client) **and with 2** (Karen and
   her daughter). **NEW —** and a live server must require 2 without a flag the harness has to flip
   (§11.1).
10. **Every number in one config table,** Karen's feel values marked **K**.

### 1.2 Must not

Each row is a named failure of the previous project (`docs/PROJECT_CONTEXT.md`) or a boundary another
design drew. The last five rows are new in this revision.

| Prohibition | Why | Whose job instead |
|---|---|---|
| Never write `workspace.CurrentCamera`, `UserInputService.MouseBehavior`/`.MouseIconEnabled`, or `Mouse.Icon` | "Three scripts set the mouse cursor"; `docs/design/camera.md` §3.1/§3.3 names `Camera.Rig` and `Camera.Cursor` as sole writers | `PlayerScripts.Camera` |
| Never create a `ScreenGui`, `Frame` or `TextLabel` outside `PlayerScripts.Hud`, and never a `BillboardGui`/`SurfaceGui` anywhere | "One predicate answered two unrelated questions" | `PlayerScripts.Hud` (§9.3, §9.5) |
| Never write a boar's state, position, attributes or Instances | `Boar.Body` is "the only writer of a boar's Instances" | `ServerScriptService.Boar`. The Match **calls** `runtime:spawn`/`spawnSounder`/`clear` and **reads** handles |
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
| The drive never writes, reads or names sounder membership. It says one number, `size` | two writers of one fact is this project's named killer. Who leads, who follows, who left is **boar** state, changing 60 times a second | `ServerScriptService.Boar` (§6.7, §9.4) |
| `Boar.Brain` never holds a reference to another boar's entry, Brain, handle or Instance | the Brain is pure and testable only because everything it knows arrives as data | the Runtime assembles `obs.sounder` once per step (§6.7) |
| No collision group and no `PhysicsService` call | collision groups are global place state with no owner row in `GAME_DESIGN.md` | separation steering (§6.7) plus the existing stuck sidestep |
| Neither the drive nor the boar queries hedges, gates, trunks or brush | `Markers.MarkerSet` has five kinds and `Map.TAGS` five strings, none of them a gate | the boar's existing `world.probe` raycast and the leader's navmesh route (§6.7) |
| **NEW — there is exactly ONE match board and one writer of it.** `ServerScriptService.Match` holds it; the arithmetic is pure in `Score` | two writers of one score is the same failure as two writers of a position, with money on it | §7.5 |
| **NEW — `Phase` never sees a score, a point or a board.** It says *when* to fold and *when* to clear, as effects | the machine is pure and asserted on its effect list; a board inside it would need a clock and a `Player` next | §4.5, §7.5 |
| **NEW — the Hud never computes a winner, a rank or a total.** It renders `matchRows` and `winners` in the order the server sent them | "a marker wandering the screen": a client that sorts is a second answer to "who won" | `Score.leaderboard`/`Score.winners` on the server (§7.5) |
| **NEW — no ghost row.** A player who leaves loses their match row entirely; nothing on the result screen belongs to somebody who is not there | the Director's decision 5, and a row keyed by a `UserId` nobody can name reads as a bug | `Match.forget` → `Score.drop` (§7.5) |
| **NEW — `MATCH_RESULT_SECONDS` is a phase, not a `task.delay`** | "`phaseEndsAt` is the only clock" is the property that makes a hitch unable to skip anything | §4.1, §4.5 |

**One predicate answers one question.** `Match.phase()` says which phase it is. It does not say whether a
player may shoot, whether the scoreboard is visible, whether a boar may be released, whether a violation
is punishable, or whether the match is over — answered in §4.1, §8.5, §6.3, §8.3 and §4.5 respectively.

---

## 2. The shape of a drive, in one picture — in both worlds

**Live today (`Map.EXPECTED_WORLD = "map:v1"`, 2048 × 2048, the line on a forest road,
`docs/design/map-generator.md` §15.1):**

```
  z = -820  exitZ ............ 120 studs past the road: the boar crosses and is gone
  z = -745  12 DrivenHunt.Tree in the far wood, span 1120
  z = -700  ==== THE FOREST ROAD, half-width 8, verge 24 ==== 8 posts, spacing 160 (45 m)
                              DriveLine 1240 x 1 x 1 at z = -700, LookVector -> +Z
  z = +300  ---- hedge bank across the corridor, 2 gates, 96 studs each ----
  z = +600  *      *      *      *   BoarSpawn x4, x = -450, -150, +150, +450, pad radius 30
  z = +700  ================= DriverStart 1120 x 1 x 20, on the assembly track
```

**The rollback (`"arena"`, 400 × 400, `src/server/TestArena.luau`, `LAYOUT`):**

```
  z = -190  exitZ ............ a boar past the line runs 40 more studs and is GONE ("escaped")
  z = -150  ################  8 posts, x = -140..+140 step 40; one DriveLine 320 x 1 x 1
  z =  -40  PillarMid                       (the 4 corner pillars are the DrivenHunt.Tree)
  z = +120  *   *   *   *      BoarSpawn x4, x = -120, -40, +40, +120
  z = +170  ==============     DriverStart 120 x 1 x 12
```

Two facts the sounder leans on, from `map-generator.md` §15.1: **a gate is 96 studs wide** and a five-boar
wedge is ~18 (§11.7), so formation does not have to change to pass one; and **the road is the flattest,
most open ground in the corridor**, so the sounder is at its widest exactly where Karen's reference
photograph looks. Nothing special-cases the road; it is ground.

**The match adds nothing to this picture.** It is a counter, two boards and a screen; no geometry, no tag,
no marker.

---

## 3. Ownership

Rule 3: exactly one writer per system, named here, mirrored into `GAME_DESIGN.md` (§13).

### 3.1 The owner

**`ServerScriptService.Match`** — disk `src/server/Match/init.luau`, booted once by
`src/server/MatchBoot.server.luau`.

Sole writer of: the phase and its deadline, **the match counter and the match totals**, team membership,
every player's per-drive score and penalty state, when and how big a release is, the two outbound
RemoteEvents, and (through `Body`) `Workspace.DriveMarkers`.

It is a **ModuleScript** (folder with `init.luau`). **Nothing happens on `require`** — only
`Match.start(world)` begins production. That is what makes every spec in §12 possible.

### 3.2 The server modules (as built, plus this revision)

| Module | Is | Never |
|---|---|---|
| `src/server/Match/init.luau` → `ServerScriptService.Match` | **the owner**: `CONFIG`, the phase state, `board` (the drive) and **`matchBoard` (the match)**, the per-`UserId` tables (`names`, `tied`, `pushCredit`, `characterWatch`), the Heartbeat accumulator, `Match:step(dt)`, the two remotes, `PhaseChanged`/`Scored`/`Punished`, `stats()`, the gated test clock `advanceForTests` | decides a rule itself; touches a boar, a weapon or a drawn thing |
| `Phase.luau` | **pure**: `(state, event, now, config) -> (state, { Effect })`. The whole match machine: the phases, **the match counter, `MatchOver` and abandonment** (§4.5), and the release schedule including sounder sizes (§6.6) | touches Instances, services, clocks, `Player`, `Random`, or **any score** |
| `Roster.luau` | **pure**: `assign`, `smallerTeam`, `counts`. Keys by `userId`; never knows what a `Player` is | as above |
| `Score.luau` | **pure**: `new`, `join`, `setTeam`, `kill`, `escape`, `violation`, `leave`, `leaderboard`, and **NEW `accumulate`, `drop`, `winners`** (§7.5) | as above |
| `Penalty.luau` | **pure**: `judge(shot, drivers, config)`, `expired(tiedAt, now, config)`, `REASON` | as above |
| `Markers.luau` | **read-only**: reads the five `DrivenHunt.*` tags and `Map.SPAWN_PAD`, returns one frozen `MarkerSet` with `complete`/`missing` | writes anything, anywhere |
| `Body.luau` | **the only writer of player characters, of the `Teams` service and of `Workspace.DriveMarkers`**: `ensureTeams`, `setTeam`, `teamOf`, `driverPositions`, `placementFor`, `place`, `tie`, `untie`, `forget`, `anchorFor`, `dressFor`/`dress` | decides anything; reads the phase |
| `src/server/MatchBoot.server.luau` | nothing. **The one composition root of the drive** (§3.5) | owns state |

`Phase`, `Roster`, `Score`, `Penalty`, `Markers` and `Body` are exported as `Match.Phase`, `Match.Roster`…
for specs, exactly as `Boar.Brain` is. **This revision adds no module and no owner.**

### 3.3 The client modules

| Module | Sole writer of | Never touches |
|---|---|---|
| `src/client/Match/init.luau` → `PlayerScripts.Match` | the client's **replica** of the snapshot. Deep-frozen, **no setter**: it subscribes to `MatchState.OnClientEvent` itself | anything drawn, the camera, the weapon, any outbound remote |
| `src/client/Hud/init.luau` → `PlayerScripts.Hud` | the drive bar, the event feed, the tied banner, the score screen, **and the match result screen** (§9.5) | match state, weapon state, the camera |

**`src/client/Match/init.luau` does not change in this revision**, and that is a decision, not an
oversight: the replica freezes and republishes whatever payload arrives, so five new snapshot fields need
no client code (`src/client/Match/init.luau`, the `MatchState.OnClientEvent` handler). Said plainly so
nobody adds a getter per field.

### 3.4 The one shared, frozen table

**`ReplicatedStorage.Drive`** — `src/shared/Drive/init.luau` plus `Remotes.model.json`. Wire types, the
Hud's layout numbers, `Drive.deepFreeze` (**required from `Shotgun`, not copied**: `table.freeze` is
shallow and this repo has paid for that once), `Drive.remotes()`.

**The rule numbers stay on the server.** `Match.CONFIG` is not replicated: a client that knows the safety
numbers can dodge the rule by eye, and one that knows the sounder weights can predict the drive.
`Drive.CONFIG` holds layout and colours only. Two tables, disjoint facts.

**The one number this revision does put on the wire is `drivesPerMatch`** (§9.1), because "drive 2 of 4" is
unreadable without it and knowing it lets a client do nothing. `DRIVES_PER_MATCH` itself stays in
`Match.CONFIG`; the snapshot carries its value, like `phaseEndsAt` carries a deadline.

### 3.5 One composition root, and it is where the boar meets the drive

`src/server/MatchBoot.server.luau`, as built: the world assertion, `Boar.defaultWorld()`, the closure-trap
line `world.threats = Match.driverThreats` (§6.5), `Boar.newRuntime(world)`, `runtime:run()`, the
`Weapon.HitReported` → `runtime:takeHit` wiring, `runtime.Downed` → `Weapon.markHit`,
`Weapon.setArmingPolicy(Match.mayCarryWeapon)`, `Weapon.setDriveLineProvider(Match.driveLine)`, then
`Match.start({ boars = runtime, weapon = Weapon, now = os.clock })`.

`BoarBoot.server.luau` is archived at `backups/2026-09-25_boarboot.server.luau.txt` (rule 7).

**This revision adds nothing to `MatchBoot`.** The match is internal to the owner: no new injected field,
no new dependency, no second place that knows two systems.

### 3.6 Every file that changes in this revision, in one table

Rule 8: the whole blast radius, so nothing is discovered at merge time. **84a** and **84b** are the split
of §0 item 6; as one task, ignore the column.

| File | Change | Task | Owner of it |
|---|---|---|---|
| `src/server/Match/Phase.luau` | `State` gains `matchNumber`, `driveInMatch`, `waitingSince`; `Phase.initial`; `enterAssigning` (the counter and `clearMatchTotals`), `enterScoring` (`foldDrive`), `enterWaiting` (`waitingSince`), **new** `enterMatchOver`; the `MatchOver` branch and the abandonment branch in `Phase.step` | 84a | `ServerScriptService.Match` |
| `src/server/Match/Score.luau` | **new pure** `Score.accumulate`, `Score.drop`, `Score.winners` (§7.5) | 84a | `ServerScriptService.Match` |
| `src/server/Match/init.luau` | `CONFIG`: `DRIVES_PER_MATCH`, `MATCH_RESULT_SECONDS`, `MATCH_ABANDON_SECONDS`, `WINNER_MIN_POINTS`, `MIN_PLAYERS_STUDIO`/`MIN_PLAYERS_LIVE`/derived `MIN_PLAYERS`, the four `SHORT_MATCH` durations; `matchBoard`; `applyFoldDrive`, `applyClearMatchTotals`; five snapshot fields; `Match.forget` drops the match row; four `stats()` counters; `PhaseChanged` gains a fourth argument | 84a | `ServerScriptService.Match` |
| `src/shared/Flags/init.luau` | **one row**, `SHORT_MATCH`, `default = false` (§12.10, §14 item N) | 84a | the Builder, in git |
| `tests/server/match_phase.spec.luau` | **CHANGED**: §12.1 items 11–20 | 84a | — |
| `tests/server/match_score.spec.luau` | **CHANGED**: §12.3's `accumulate`/`drop`/`winners` block | 84a | — |
| `tests/server/match_live.spec.luau` | **CHANGED**: §12.4 items 14–17 | 84a | — |
| `tests/server/zz_drive_boundary.spec.luau` | **CHANGED**: one appended `describe`, the live match boundary (§12.12) | 84a | — |
| `tests/server/flags.spec.luau` | **CHANGED**: one wiring assertion for `SHORT_MATCH`, mirroring §12.4 item 17 | 84a | — |
| `src/shared/Drive/init.luau` | `PhaseName` gains `"MatchOver"`; `MatchSnapshot` gains five fields; `CONFIG` gains the result-panel layout numbers and widens `SCORE_PANEL_WIDTH` | 84b | no run-time writer (frozen data) |
| `src/client/Hud/init.luau` | the `MatchPanel`, `Hud.renderMatch` and its four readers; `renderScore` gains the `MATCH` column, the `k/N` title and the two footers; `renderDrive` calls `renderMatch` and maps `MatchOver` → `RESULT` (§9.5) | 84b | `PlayerScripts.Hud` |
| `tests/client/match_client.spec.luau` | **CHANGED**: §12.9 | 84b | — |
| `GAME_DESIGN.md` | three amended owner rows (§13) | 84b (or 84a if unsplit) | the Builder |
| `docs/research/2026-09-25-drive.md` | **Addendum 3**: the match-loop sources J–L confirmed, **before the code** (rule 1) | 84a | the Builder |

**Nothing else.** In particular **no change** to: `src/server/Boar/**`, `src/server/Weapon/**`,
`src/server/Match/Roster.luau`, `Penalty.luau`, `Markers.luau`, `Body.luau`, `src/serverstorage/MapGen/**`,
`src/shared/Map/init.luau`, `src/client/Match/**`, `src/client/Camera/**`, `src/client/Weapon/**`,
`tools/**`, `tests/client/input_scenarios.txt`, or `default.project.json`. The harness needs no change:
`tools/studio_mcp.py` reads no phase name (it asks clients their team before the suites run, at
`probe_role`, which is why extra drive boundaries after the clients have finished cannot disturb it).

---

## 4. The match state machine

### 4.1 Phases

`Phase.step(state, event, now, config) -> (state, { Effect })`, pure, returning a **new frozen state**.
**`MatchOver` is new; the other four are unchanged.**

| Phase | Entered when | Lasts | What is true |
|---|---|---|---|
| `Waiting` | boot; `Scoring` or `MatchOver` elapsed with `< MIN_PLAYERS`; markers incomplete | until `participants >= MIN_PLAYERS` **and** `markersComplete` | no teams, no boars, no timer; the Hud shows `waitingFor`. **A match in progress is kept** until `MATCH_ABANDON_SECONDS` (§4.5) |
| `Assigning` | `Waiting` satisfied; `Scoring` elapsed with enough players and **the match is not finished**; `MatchOver` elapsed with enough players | `INTERMISSION_SECONDS` = 20 s | teams assigned **once, on entry**; everyone placed; guns re-evaluated; the **drive** board zeroed; last drive's boars cleared. **The match counter advances here, and here only** (§4.5) |
| `Running` | `Assigning` elapsed | `DRIVE_SECONDS` = 600 s | the drive. Releases happen on the schedule; kills and escapes score; the safety rule is live. `Phase.isLive(state)` is true **only here** |
| `Scoring` | `Running` elapsed (or every boar accounted and `END_ON_LAST_BOAR`, default **false**) | `SCORE_SECONDS` = 25 s | the score screen; everybody tied is freed; boars cleared. **The drive's board is folded into the match total on entry** (`foldDrive`, §7.5) |
| **`MatchOver`** (NEW) | `Scoring` elapsed **and** `driveInMatch >= DRIVES_PER_MATCH`, whatever the player count | `MATCH_RESULT_SECONDS` = 30 s | the match result screen: `matchRows` and `winners`. No boars, no releases, no scoring, no violations (`isLive` is false). Guns are not revoked (arming treats it exactly like `Scoring`, §8.5) |

**Every transition is time-driven from `phaseEndsAt`, and `phaseEndsAt` is the only clock.** No
`task.delay`, no `task.wait`, no second timer, and the new phase adds none.

**The test seam** (`Match.advanceForTests(seconds)`, Task 41) moves **this owner's own clock** forward,
gated on Studio plus a live `TestKit.activeToken()`. It is how a spec watches a real boundary — and now a
real **match** boundary (§12.12). It is not a phase skip and it cannot happen in a playtest or on a live
server.

### 4.2 Events the machine consumes — unchanged

```luau
export type Event = {
    kind: "tick" | "join" | "leave" | "kill" | "gone" | "violation" | "markers",
    userId: number?, name: string?, record: any?, at: number?,
    aliveBoars: number?,      -- live boars (not DOWN, not GONE)
    boarEntries: number?,     -- every entry the runtime holds, CARCASSES INCLUDED
    boarCapacity: number?,    -- the runtime's own maxBoars
    complete: boolean?, missing: { string }?, boarSpawns: { Vector3 }?,
}
```

**The owner fills `aliveBoars`, `boarEntries` and `boarCapacity` on EVERY event, not only the tick**
(`src/server/Match/init.luau`, `dispatch`). That rule is load-bearing: round 1 of Task 38 found a join
landing on a release moment reading `aliveBoars = 0`, passing the gate and then being refused by the owner
— a six-boar drive quietly ran five.

**The match needs no new event.** A match ends because time passed, which is a `tick`. There is no
client-originated event (§9.1).

### 4.3 Effects the machine emits

```luau
export type Effect =
      { kind: "assignTeams", assignment: { [number]: TeamName } }
    | { kind: "placePlayers", userIds: { number }? }
    | { kind: "refreshArming", userIds: { number }? }
    | { kind: "spawnSounder", position: Vector3?, size: number }
    | { kind: "clearBoars" }
    | { kind: "freeze", userId: number }
    | { kind: "release" }
    | { kind: "broadcast", force: boolean? }
    | { kind: "feed", entry: FeedEntry }
    | { kind: "foldDrive" }                                          -- NEW
    | { kind: "clearMatchTotals", reason: "newMatch" | "abandoned" }  -- NEW
```

A spec asserts on the **effect list**, a plain table: no Instances, no waiting, no physics.

**The two new effects exist so the pure machine can own *when* without owning a score** (§1.2). Their
position in the list is load-bearing and asserted (§12.1 items 12–13):

- **`enterScoring`** emits, in this order: `release`, `clearBoars`, **`foldDrive`**, `feed`,
  `broadcast{force = true}`. `foldDrive` is **before** the broadcast, or the push that shows the score
  screen carries a match total that is one drive out of date — the same defect as `TASKS.md` 32a(c), where
  the drive-start push carried the previous drive's rows.
- **`enterAssigning`** emits **`clearMatchTotals{reason = "newMatch"}` first, and only when this Assigning
  starts a match** (`driveInMatch == 0` on entry), then `assignTeams`, `clearBoars`, `placePlayers`,
  `refreshArming`, `feed`, `broadcast{force = true}`.
- **Abandonment** (in the `Waiting` branch) emits `clearMatchTotals{reason = "abandoned"}`, `feed`,
  `broadcast{force = true}`.
- **`enterMatchOver`** emits only `feed` ("Match over") and `broadcast{force = true}`. Nothing needs
  clearing: `Scoring` already freed every tie and cleared every boar.

### 4.4 Join and leave, phase by phase

| | `Waiting` | `Assigning` | `Running` | `Scoring` | **`MatchOver`** |
|---|---|---|---|---|---|
| **joins** | counted; enters `Assigning` at `MIN_PLAYERS` | assigned with everybody | **assigned to the smaller team** (tie → `ODD_PLAYER_TEAM`), placed, armed, drive score 0. No existing player moves | no team; assigned at the next `Assigning` | as `Scoring`: no team, **0 match points**, ranked like everyone else from their first drive (Director decision 4) |
| **leaves** | counted out | dropped before the assignment is used | their team shrinks; **nobody is moved**. Their drive row is kept for this drive's screen, marked `left`. A tie is dropped with them | dropped from the next roster; this drive's screen keeps their result | as `Scoring` |

**And in every phase, a leaver's MATCH row is dropped outright** (`Match.forget` → `Score.drop`), so the
result screen never shows somebody who is not there (Director decision 5). Their drive row still finishes
the drive it was in, marked `left`, and **a row marked `left` is not folded into the match** (§7.5) — which
is what stops the fold from resurrecting the row `drop` just removed.

A drive never aborts because a team emptied; `stats().emptyTeamDrives` counts it.
`Match.forget(player)` is called from `Players.PlayerRemoving` and empties **every** table keyed by that
user, `matchBoard` included.

### 4.5 NEW — the match: the counter, every transition, and abandonment

Three fields, in the pure state, written nowhere else:

```luau
export type State = {
    -- ...as built...
    matchNumber: number,    -- 0 before the first match; 1, 2, 3... after
    driveInMatch: number,   -- 0 = no match in progress; otherwise 1..DRIVES_PER_MATCH
    waitingSince: number,   -- when Waiting was entered; math.huge whenever the phase is not Waiting
}
```

`Phase.initial` sets `matchNumber = 0`, `driveInMatch = 0`, `waitingSince = math.huge`.
**`driveNumber` is unchanged**: it stays the session-monotonic count the drive bar, the score panel title
and four existing specs already use. Two counters, two questions ("which drive of this server" and "which
drive of this match"), and neither is derived from the other, because a `Waiting` gap breaks any arithmetic
between them.

**The one place the counter moves** is `enterAssigning`:

```
enterAssigning(state, effects, now, config):
    if state.driveInMatch == 0 then            -- a new match starts here, and ONLY here
        state.matchNumber += 1
        state.driveInMatch = 1
        insert(effects, { kind = "clearMatchTotals", reason = "newMatch" })
    else
        state.driveInMatch += 1                -- 2..DRIVES_PER_MATCH; the match resumes
    end
    ...everything enterAssigning does today: driveNumber += 1, the release counters and boarsAccounted
       zeroed, Roster.assign, assignTeams, clearBoars, placePlayers, refreshArming, feed, forced broadcast
```

**The one place it is spent** is the `Scoring` branch:

```
Scoring, now >= phaseEndsAt:
    if state.driveInMatch >= config.DRIVES_PER_MATCH then
        enterMatchOver(state, effects, now, config)      -- whatever the player count
    elseif enoughPlayers(state, config) and state.markersComplete then
        enterAssigning(...)                              -- the next drive of this match
    else
        enterWaiting(...)                                -- the match is KEPT (driveInMatch unchanged)
    end
```

**The one place it is reset to 0** is the `MatchOver` branch, and abandonment:

```
MatchOver, now >= phaseEndsAt:
    state.driveInMatch = 0                               -- the match is finished
    if enoughPlayers and markersComplete then enterAssigning(...) else enterWaiting(...) end

Waiting, every step:
    if enoughPlayers and markersComplete then
        enterAssigning(...)                              -- a resume wins on the same step
    elseif state.driveInMatch > 0
           and now - state.waitingSince >= config.MATCH_ABANDON_SECONDS then
        state.driveInMatch = 0
        insert(effects, { kind = "clearMatchTotals", reason = "abandoned" })
        feed(effects, { kind = "phase", text = "Match abandoned", at = now })
        insert(effects, { kind = "broadcast", force = true })
    end
```

`enterWaiting` sets `waitingSince = now`; every other `enter*` sets it back to `math.huge`, so the
abandonment compare can only fire in `Waiting` and can only fire **once** per gap (after it,
`driveInMatch == 0` fails the guard). That is asserted (§12.1 item 17), because "once" is the difference
between one feed line and one per tick for as long as the server is empty.

**Why the counter lives in the pure state and not in the owner:** every transition that touches it is a
transition this machine already takes, and `match_phase.spec` can then simulate a whole match — four
drives, a gap, an abandonment — in milliseconds with no players and no clock. The owner holding the counter
would make the same test need a live server.

**Worked, with the committed numbers** (`DRIVES_PER_MATCH = 4`, `SWAP_TEAMS_EACH_DRIVE = true`):

```
 t=0      Waiting           matchNumber 0  driveInMatch 0
 join     Assigning         matchNumber 1  driveInMatch 1   clearMatchTotals(newMatch)
 +20      Running
 +620     Scoring                                           foldDrive  (drive 1 -> match total)
 +645     Assigning                        driveInMatch 2   teams swap
 ... drives 2, 3, 4 ...
 +2580    Scoring                                           foldDrive  (drive 4)
 +2605    MatchOver         (30 s of result screen; winners named)
 +2635    Assigning         matchNumber 2  driveInMatch 1   clearMatchTotals(newMatch)
```

A whole match is `DRIVES_PER_MATCH x (DRIVE_SECONDS + INTERMISSION_SECONDS + SCORE_SECONDS) +
MATCH_RESULT_SECONDS` = **2,610 s ≈ 43.5 minutes** with the real numbers. That number is why §12.10 exists.

---

## 5. Teams

### 5.1 Representation: `Player.Team`, and nothing else

Team membership is Roblox's own `Player.Team`, written only by `Match.Body.setTeam`. It replicates free, a
client cannot write it, and it colours the player list. `Match.Body.ensureTeams` creates exactly two
`Team`s at `start()`: `Drivers` (`Bright blue`) and `Shooters` (`Bright orange`), **`AutoAssignable = false`**
so Roblox never assigns anybody — the single most likely way to build this wrong (§16 source A).

### 5.2 `Roster` — pure, and it never knows what a `Player` is

```luau
Roster.assign(userIds: { number }, previous: { [number]: TeamName }?, config): { [number]: TeamName }
Roster.smallerTeam(counts, config): TeamName
Roster.counts(assignment): { [TeamName]: number }
```

1. **Equal to within one** for any 1 ≤ n ≤ 16.
2. The odd player goes to `ODD_PLAYER_TEAM` — **`"Shooters"`, as built**: with one player that player is a
   shooter and is armed, which keeps the harness's single Play client holding a gun.
3. **Deterministic**: the input is sorted by `userId`; no `Random` in the module.
4. Roles swap between drives when `SWAP_TEAMS_EACH_DRIVE` (default **true**).

**Across a match:** `previousAssignment` persists through `MatchOver`, so match 2 drive 1 swaps from match 1
drive 4. With `DRIVES_PER_MATCH` **even** and a stable roster, every player shoots half the match and
drives half of it — which is the Director's reason for 4, and why `DRIVES_PER_MATCH % 2 == 0` is asserted
(§12.4 item 14) rather than assumed. With an odd count or a churning roster it is approximate, and nothing
tries to correct it: a corrective assignment would be a second writer of team membership with a motive.

### 5.3 What `Assigning` does, in order

`Roster.assign` → `Body.setTeam` for everybody → `Body.place` (connect `CharacterAdded`, then
`LoadCharacter`, then `PivotTo(Body.placementFor(...))`, counting `placementsMissed` after
`PLACE_TIMEOUT = 5 s`) → `Weapon.refreshArming` for everybody → the drive board zeroed, boars cleared, the
drive and match counters advanced (§4.5), one **forced** broadcast.

`Body.placementFor(markerSet, team, indexWithinTeam, config)` puts a shooter on post *n*
(`post.Position + (0, post.Size.Y/2 + STAND_HEIGHT_STUDS, 0)`, `STAND_HEIGHT_STUDS = 3.5`) facing **+Z**,
and a driver along the `DriverStart` part's X extent facing **−Z**.

### 5.4 Outfits — as built (M2.8d), unchanged by this revision

Karen, 2026-09-26: **shooters wear an orange hat, drivers an orange vest.** The owner is
`ServerScriptService.Match.Body`, the module that already writes characters.

```luau
Body.OUTFIT_NAME = "HuntOutfit"     -- one folder per character; destroyed and rebuilt
Body.dressFor(team: TeamName?, config): { { name: string, limb: string, size: Vector3,
                                            offset: Vector3, color: Color3 } }   -- PURE
Body.dress(character: Model?, team: TeamName?, config): boolean
```

| Role | Part | Size (studs) | Attached to | Colour |
|---|---|---|---|---|
| Shooter | `Hat` (flat cylinder) | 2.2 × 0.6 × 2.2, +0.8 above the Head's centre | `Head` | RGB(255, 112, 0) |
| Driver | `Vest` (thin box) | 2.2 × 1.6 × 1.3, torso front | `UpperTorso` (fallback `Torso`) | RGB(255, 112, 0) |

Four properties that are not tidiness: **`CanQuery = false`** (an outfit that stops a pellet changes what
the shot hit, which feeds `Penalty.judge`); **`Massless = true`, not anchored** (`Body.tie` anchors the
*root*; an anchored hat would pin a head to the world); **cosmetic only, never a source of truth**
(`Penalty.judge` keeps deciding from teams); **the team colours stay** (`Body.TEAM_COLORS`).

It is merged OFF behind `ORANGE_OUTFITS`, read once at the boundary into `Match.CONFIG.OUTFITS_ENABLED` and
passed into `Body.dressFor` as a parameter.

---

## 6. Posts, the drive line, and boars

### 6.1 The markers are tags, and the world of the day places them

Five tags under the reserved prefix `DrivenHunt.`, which no other system may use. **The strings live once**,
in `src/shared/Map/init.luau`, `Map.TAGS`; `TestArena`, `Markers` and `MapGen.Markers` all read them there.

| Tag | Read for | Live world (`map:v1`) | Rollback (arena) |
|---|---|---|---|
| `DrivenHunt.ShooterPost` | where each shooter stands; the tie-up fallback | 8 parts, z = −700 **on the road**, spacing 160 (45 m), span 1120, each 6 × 1 × 6 | 8 parts, z = −150, x = −140…+140 step 40 |
| `DrivenHunt.DriveLine` | `{ position, normal = part.CFrame.LookVector }` — **exactly one**; its `LookVector` points at **+Z, the drivers** | 1240 × 1 × 1 at z = −700 (**the road is the line**) | 320 × 1 × 1 at z = −150 |
| `DrivenHunt.DriverStart` | where drivers spawn, spread across its X extent | 1120 × 1 × 20 at z = +700 | 120 × 1 × 12 at z = +170 |
| `DrivenHunt.BoarSpawn` | where a release enters the drive | 4 parts, z = +600, x = −450, −150, +150, +450, each on a flat pad of radius `Map.SPAWN_PAD.radius` = 30 | 4 parts, z = +120, x = −120, −40, +40, +120 |
| `DrivenHunt.Tree` | where a punished shooter is tied | 12 placed trunks at z = −745 (**and only those** — `Body.anchorFor` scans every tagged tree, so the wood's ~2,900 other trunks are deliberately untagged) | the 4 corner pillars, re-used |

**Tags, not attributes**: the markers are built in code, so there is nothing on disk for the harness to
compare, and the question is "give me every post", which is one `GetTagged` call. A server spec asserts the
tags directly (§12.5).

### 6.2 `Markers` — read-only, loud when something is missing

```luau
export type MarkerSet = {
    posts: { BasePart },        -- sorted by X, so post 1 is always the same post
    line: DriveLine?,           -- nil unless exactly one part is tagged
    lineParts: number,
    driverStart: BasePart?,
    boarSpawns: { Vector3 },    -- sorted by X
    trees: { BasePart },
    spawnRadius: number,        -- Map.SPAWN_PAD.radius: the flat disc the map guarantees
    complete: boolean,
    missing: { string },
}
Markers.read(service: any?): MarkerSet   -- frozen
```

`complete == false` → the machine **stays in `Waiting`**, `waitingFor` names the exact missing tags, and the
Hud shows them. Two tagged drive lines is also incomplete: an ambiguous line would make the safety rule
fire on whichever the engine returned first. `Markers.read` is re-run every second while `Waiting` and once
on entering `Assigning` (`markersStale`), which also closes the measured `ArenaBoot`/`MatchBoot` race.

### 6.3 Boars: how many, when, and who says so

**The Match decides *when* and *how many*; `ServerScriptService.Boar` owns every boar.** The Match calls
`runtime:spawn(position)` / `runtime:spawnSounder(...)` / `runtime:clear(reason)` and reads handles
(`handle.state()`, `handle.position()`, `handle.id`). It writes nothing about a boar, ever.

| Number | Value | K? | Why |
|---|---|---|---|
| `BOARS_PER_DRIVE` | 6 | K | **the ANIMAL budget for a drive**, in both flag states. Not a release count. **Per drive, not per match**: a 4-drive match is 24 animals |
| `FIRST_RELEASE_SECONDS` | 20 | K | the drivers are walking before the first boar moves. The first release is **exact**, never jittered (measured twice in Task 32) |
| `RELEASE_INTERVAL_SECONDS` | 90 | K | the singles rhythm: 20 + 5 × 90 = 470 s, so the last boar has ~130 s of drive left |
| `RELEASE_JITTER_SECONDS` | 15 | K | so the drive is not a metronome. Deterministic (`Phase.jitter`), never `Random` |
| `MAX_ALIVE_BOARS` | 6 | | `>= SOUNDER.MAX_SIZE` is an invariant (§12.4 item 11), not a coincidence |
| `SEED` | 1 | | the drive's one seed; every drawn number is a pure hash of `(SEED + driveNumber, index)`. **`driveNumber` keeps incrementing across a match**, so drive 1 of match 2 is not drive 1 of match 1 again (§12.1 item 19) |

**Two hazards in the boar code, and what this design does about each:**

1. **`Runtime:spawn` asserts** `#self._boars < maxBoars`, and an assert inside the Heartbeat step kills the
   step, not the spawn. So the **pure machine** holds a release back before it is attempted (`maybeRelease`,
   using `aliveBoars`/`boarEntries`/`boarCapacity`), the owner wraps the call in `pcall`, and a refusal
   **hands the release back** (`Phase.releaseFailed`) so it is retried and never dropped. **There is no
   second guard in the owner** — two guards disagreeing is what dropped releases in Task 38 round 1.
2. **Carcasses occupy slots** for `Boar.CONFIG.WOUND.CARCASS_SECONDS = 120`, and `maxBoars` counts them.
   `MAX_ALIVE_BOARS` counts only boars that are neither `DOWN` nor `GONE`; `boarEntries` counts everything,
   and that is the number checked against `maxBoars` (8, `src/server/Boar/init.luau`, `CONFIG.maxBoars`).

`clearBoars` empties the list at every drive boundary, `MatchOver` included by construction (it is entered
from `Scoring`, which already cleared). `Boar.CONFIG.spawnPoint` stays unused in production: the Match
passes an explicit marker position, round-robin by `soundersReleased`.

### 6.4 `Workspace.DriveMarkers`

`Match.Body` creates it on first use and is its only writer. It holds one thing: a rope `Part` per tied
player, destroyed on release. Workspace is not Rojo-owned and the harness compares the Edit-mode
DataModel, so a run-time folder cannot dirty a run.

### 6.5 The closure trap in `Boar.defaultWorld`

`Boar.defaultWorld`'s `threats` closes over the **module-level** `Boar.CONFIG`, not over the runtime's
merged clone, so passing `config = { isThreat = … }` into the world would change the Brain's copy and not
the one that filters threats. The fix is one line at the composition root:
`world.threats = Match.driverThreats`. **Only drivers scare boars** — a shooter on a post must not push the
boar back into the wood before it reaches the line.

### 6.6 The sounder release: sizes, mix, spacing, timing (as built)

**A release is a sounder of `size` boars at one `DrivenHunt.BoarSpawn` marker.** A single is a sounder of
one. `size` is decided by the **pure machine** from a hash — never `Random` — so the same seed gives the
same drive.

```luau
Phase.unitHash(seed: number, index: number): number    -- [0, 1); ONE hash in this module
Phase.sounderSize(state: State, config): number
    -- remaining = config.BOARS_PER_DRIVE - state.boarsReleased
    -- remaining <= 0              -> 0
    -- not config.SOUNDER.ENABLED  -> 1                    (EXACTLY today's behaviour)
    -- otherwise                   -> a weighted pick from SOUNDER.SIZE_WEIGHTS with
    --                                unitHash(seed + driveNumber, soundersReleased + 1),
    --                                clamped to min(SOUNDER.MAX_SIZE, remaining)
Phase.releaseGap(state: State, size: number, now: number, config): number
    -- not ENABLED -> config.RELEASE_INTERVAL_SECONDS       (EXACTLY today)
    -- ENABLED     -> clamp(((phaseEndsAt - SOUNDER.TAIL_SECONDS) - now) / releasesLeft,
    --                      SOUNDER.GAP_MIN_SECONDS, SOUNDER.GAP_MAX_SECONDS)
    --                releasesLeft = max(1, round(remainingAfterThisRelease / SOUNDER.EXPECTED_SIZE))
Phase.releaseFailed(state: State, now: number, size: number?): State
    -- gives back ONE sounder and `size` boars and makes the next release due NOW, so the SAME
    -- sounder (same hash index -> same size) is retried rather than lost.
```

`maybeRelease`: return unless the budget is unspent and `now >= nextReleaseAt`; draw `size`; **the whole
sounder fits or none of it is released** (`alive + size > MAX_ALIVE_BOARS` or
`entries + size > capacity` → `holdbacks += 1` and retry next tick); position =
`spawns[(soundersReleased % #spawns) + 1]`; increment both counters; emit
`spawnSounder{position, size}`; `nextReleaseAt = now + releaseGap + jitter`.

**The mix.** `SIZE_WEIGHTS = { 40, 20, 18, 12, 10 }` for sizes 1..5 (K): 40 % singles, a five once in ten
releases. `EXPECTED_SIZE = 2.32` is the weighted mean and **not an independent number**: `match_phase.spec`
asserts it equals the mean of the weights to 0.01.

**Spacing at the spawn — the pad is the contract.** `applySpawnSounder` passes the marker position and
`markerSet.spawnRadius`; the **boar** decides the ring geometry, clamped inside
`spawnRadius - PAD_MARGIN_STUDS`, because `Runtime:spawn` overwrites the caller's Y and a member placed on
a slope would be spawned inside a hill (`map-generator.md` §11 item 2). At `radius = 30` the ring is the
full `SPAWN_RING_STUDS = 10`.

### 6.7 The sounder's behaviour, and who writes it (as built)

**Ownership first, because it is the whole answer:**

| Fact | The one writer | Where |
|---|---|---|
| a sounder exists, who is in it, who leads, how long it is scattering | **`ServerScriptService.Boar`** (the Runtime) — `self._sounders`, `entry.sounderId` | `src/server/Boar/init.luau` |
| every boar's Instances, velocity, facing, flash, collapse | `Boar.Body` | `src/server/Boar/Body.luau` |
| every boar's **decision** state, including where in the formation it is steering | `Boar.Brain` — and it holds **no reference** to another boar | `src/server/Boar/Brain.luau` |
| how big a release is and when | `ServerScriptService.Match` / `Match.Phase` | §6.6 |
| **nothing** | — | the drive never reads `Runtime:sounders()` in production |

**The pattern: a navmesh route for the leader + Reynolds leader-following with boids
separation/cohesion/alignment for the followers**, blended into the setpoint that already exists (§16
sources G, H, I). The blended direction goes through the **same** `slew(TURN_RATE·dt)` and `ACCEL` ramp, so
the existing turn-rate and acceleration assertions still hold and there is no second motion rule.

The Runtime assembles one observation per boar per step:

```luau
export type SounderObs = {
    isLeader: boolean, slot: number, scattering: boolean,
    leaderState: string?,                                   -- "IDLE" | "FLEE" | "WOUNDED" | nil
    leader: { position: Vector3, velocity: Vector3, facing: Vector3, speed: number }?,
    centroid: Vector3,                                      -- live members, self included
    neighbours: { { position: Vector3, velocity: Vector3 } },-- within NEIGHBOUR_STUDS, never self
}
```

`obs.sounder` is **nil for a lone boar**, and then every existing path runs unchanged.

- **Who leads:** the member nearest the exit line (`min |position.Z - field.exitZ|`), tie-broken by id,
  chosen at `spawnSounder` and on every promotion.
- **The leader** behaves exactly as a lone boar and is the **only** member that asks for a path.
- **The followers** blend four terms (a Reynolds truncated weighted sum in which separation can dominate):
  cohesion toward the slot (or the centroid while IDLE beyond `IDLE_SPREAD_STUDS`; zero inside
  `SLOT_TOLERANCE_STUDS`, so it does not oscillate) at 1.0; separation, scaled
  `(SEPARATION_STUDS / max(d, 1)) - 1`, at **1.6**; alignment to the leader's velocity at 0.4; flee, the
  existing `_fleeDirection()`, at 0.8.
- **Follower speed** is the leader's speed × `CATCHUP` = 1.15 while beyond tolerance, clamped to
  `[TROT_SPEED/2, SPRINT_SPEED]`, then × the wound's `speedScale`.
- **Herd panic and herd calm:** an `IDLE` follower whose `leaderState` is `FLEE`/`WOUNDED` enters `FLEE` on
  its next sense tick even with no threat of its own; it returns to `IDLE` only when its own calm timer has
  run **and** `leaderState == "IDLE"`.
- **Formation through a gate and across the road:** the leader's route funnels the sounder (five
  `ComputeAsync` calls could each pick a different gate), and `obs.blockedAhead` latches
  `COLUMN_LATCH_SECONDS = 1.5` of **column** offsets. A 96-stud gate never triggers it; a trunk gap does.
- **A hit on any member** latches `scatterFor = SCATTER_SECONDS` (`SCATTER_ON_HIT = true`): `leader = nil`
  in every observation, cohesion and alignment zero, separation × `SCATTER_SEPARATION = 3.0`, every member
  on its own route.
- **The leader dying** promotes the live member nearest the exit **and** scatters, on the same tick. When
  the scatter expires, whoever is within `BREAK_STUDS` is back in formation and whoever is not is a lone
  boar. **There is no re-forming rule and no reunion radius.**
- **A wounded member** leaves the sounder as soon as its severity is `mortal` or `lethal`
  (`LEAVE_ON_MORTAL = true`) and continues on the existing `WOUNDED` path.
- **A member leaves in exactly four ways**, all written by the Runtime: it despawned; it became mortally
  wounded; it was beyond `BREAK_STUDS` for `BREAK_SECONDS`; the sounder fell to one member and was
  **dissolved** (`stats().soundersDissolved`).

### 6.8 Performance: one route per sounder

`LEADER_PATHS_ONLY = true`. A follower's `intent.pathRequest` is always `nil`, with one exception: a
follower `_updateStuck` has reported stuck twice may request one. Steady state: **≤ 1 `ComputeAsync` in
flight per sounder** and ≤ 2/s while fleeing (`REPATH_INTERVAL = 0.5`), whatever the size; §12.8 item 8
asserts `stats().pathRequests <= 12` over a 3-second live flee with five. Observation assembly is O(n) plus
O(n²) neighbour pairs, n ≤ 5 → ≤ 30 pair distances a frame at `MAX_ALIVE_BOARS = 6`, and **zero raycasts
added**.

### 6.9 The sounder flag

```lua
BOAR_SOUNDERS = { default = false, owner = "ServerScriptService.Match",
                  born = "2026-09-26 task 60 (the sounder itself; the release is task 61)",
                  expires = "2026-10-17",
                  why = "Boars come as a mix of singles and sounders of 2-5. OFF releases one boar per release, as today." }
```

One read, at the boundary, in the only permitted shape: `SOUNDER = { ENABLED = Flags.isOn("BOAR_SOUNDERS"), … }`
in `Match.CONFIG`. **With it OFF every size is 1**, no sounder record is created, `obs.sounder` is always
`nil`, and the Brain's formation code is unreachable. Both states are testable while the flag sits at one
of them, because every new decision takes `config` or a parameter.

**This revision does not touch that row**, and its `expires = "2026-10-17"` is not this task's business —
but it is nine days away, and an expired row fails `tests/server/flags.spec.luau`, which fails the harness.
Named for the Director as item **Q** in §14 so it is not discovered by a red harness during Task 85.

---

## 7. Points

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

Sounders change no scoring: `pushCredit` is keyed by **boar id**, so a driver who pushed a sounder of five
and watched three die is paid three times — once per animal, which is what "individual points per boar"
means. **The match changes no scoring either**: a match total is the sum of drive totals and nothing else.
No per-match bonus, no streak, no multiplier (§14 Director item **P**).

### 7.2 `Score` — pure, keyed by `UserId`

`Score.new/join/setTeam/kill/escape/violation/leave/leaderboard`, and this revision's `accumulate/drop/winners`.
No service, no clock, no `Player`, no Instance, no `Random`; every board frozen, no input mutated.
**A `Player` is never stored**, only `userId` and `name`: a wounded boar can outlive a disconnect by
`BLEED_OUT_MAX_SECONDS = 25`, a drive row outlives it by a drive, and a **match** row would have outlived it
by 43 minutes — which is exactly why `drop` exists (§7.5).

### 7.3 The leaderboard

`points` desc, then `kills` desc, then `firstKillAt` asc, then `userId` asc. The last key makes the order
total, so the board never reorders between broadcasts for no reason. **The match board uses the same
function** — one sort in this repo, not two (§7.5).

### 7.4 Where a kill comes from

`Runtime.Downed(record)` → `Score.kill(board, record, creditFor(record.id), CONFIG)`;
`Runtime.Despawned(record)` with `reason == "escaped"` → `Score.escape`; with `reason == "killed"` →
**nothing** (that is the carcass leaving, and the kill was already scored). A missing `Downed` signal warns
once and counts `stats().killSignalMissing`.

**All of this writes the DRIVE board only.** Nothing outside `applyFoldDrive` ever writes the match board.

### 7.5 NEW — the match totals: who folds, when, and what a leaver takes with them

**Two boards, one writer, one arithmetic.**

| Board | Holds | Written by | Reset by |
|---|---|---|---|
| `board` | this drive | the owner, on `Downed`/`Despawned`/`violation`/join/leave, exactly as today | the owner, on entry to `Assigning` (`board = Score.new()` then one `Score.join` per name) |
| `matchBoard` | this match | **the owner, in `applyFoldDrive` and nowhere else** | the owner, in `applyClearMatchTotals` |

```luau
-- src/server/Match/Score.luau, all pure, all new
Score.accumulate(total: Board, drive: Board): Board
    -- For every row of `drive` with left == false:
    --   points, kills, assists, pushes, wounded, escaped, violations  += the drive row's
    --   name  := the drive row's name          (the newest spelling is the truest)
    --   team  := nil                           (a match row has no team: you played both sides)
    --   left  := false
    --   firstKillAt := the earlier of the two, nil-safe
    -- Rows of `total` that `drive` does not mention are carried through unchanged (shared, not copied,
    -- exactly as withRows already does).
    -- A row marked `left` is SKIPPED (Director decision 5, and see below).
    -- It is ARITHMETIC, NOT IDEMPOTENT: folding the same drive twice doubles it. The owner folds
    -- exactly once per drive, on the Scoring entry, and match_phase.spec asserts the "exactly once".
Score.drop(board: Board, userId: number): Board
    -- Removes the row outright. Returns the SAME board when there is no such row.
    -- Not Score.leave: `leave` keeps the row marked `left` so THIS DRIVE's screen still shows what they
    -- did. A match row has no such screen to appear on except the result one, where a row belonging to
    -- somebody who has gone is a ghost.
Score.winners(board: Board, minPoints: number): { number }
    -- Every userId sharing the top `points`, ascending. {} when the board is empty, and {} when the top
    -- is below `minPoints` -- so sixteen players on 0 are not sixteen winners.
```

**The owner's two instructions, and they are the whole wiring:**

```
applyFoldDrive():                     matchBoard = Score.accumulate(matchBoard, board)
                                      stats.matchDrivesFolded += 1; snapshotCache = nil
applyClearMatchTotals(reason):        matchBoard = Score.new()
                                      stats.matchTotalsCleared += 1
                                      if reason == "abandoned" then stats.matchesAbandoned += 1 end
                                      snapshotCache = nil
```

**`Match.forget(player)` gains one line**: `matchBoard = Score.drop(matchBoard, userId)`, beside the
existing `board = Score.leave(board, userId)`. Those two calls are the Director's decisions 4 and 5 in
code: a joiner has no row until they score (and therefore starts at 0), and a leaver's points leave with
them. The `left` skip in `accumulate` is what stops the next fold from re-creating the row `drop` just
removed, and it is asserted (§12.3).

**Why the fold is at `Scoring` entry and not at the next `Assigning`:** the score screen must show the
running match total *including the drive just played* (Director decision 2). Folding at `Assigning` would
show a total one drive stale for 25 seconds, every drive. And `Scoring` is entered from `Running` only, so
"once per drive" is total — there is no path that reaches the score screen twice.

**Bounds.** `matchBoard` holds at most one row per `UserId` that ever scored in this match and is emptied at
every match start and at abandonment; every leaver's row is dropped. So an empty server's match board is
empty by construction, and a full one is ≤ `MAX_PLAYERS` rows plus any synthetic `userId` a spec's
contributor table created (the same property the drive board already has,
`tests/server/zz_drive_boundary.spec.luau` records it).

---

## 8. The safety rule — unchanged by this revision

### 8.1 The rule

**v1: _you fired at a driver_.** A shot is a violation when a live driver's character was inside
`SAFETY_MISS_STUDS` of the shot's path, in front of the muzzle, and nearer than where the pellets stopped.

Rejected and recorded so it is not re-invented: "any shot within 45° of the drivers" as the *verdict* — a
shooter on a post faces the drive, so everybody would be tied in the first minute. The cone stays as the
weapon's **filter**. Also rejected for v1: "any shot along the line" (`TASKS.md` row 35a).

### 8.2 Who decides what, at fire time

| Step | Who |
|---|---|
| the shot's true direction and where the pellets stopped | **the weapon**, only |
| where the drive line is | **the Match**, through `Weapon.setDriveLineProvider(Match.driveLine)` |
| "this shot went into the drive" — the **filter** | **the weapon**: `SafetyArc.isForbidden(aim, line, SAFETY_ARC_HALF_DEG = 45)` |
| "…and it endangered somebody" — the **verdict** | **the Match**: `Penalty.judge` |
| the punishment | **the Match**, never the weapon |

`Weapon.SafetyViolated` carries `(player, aim, muzzle, stopAt)`. Without `stopAt`, a shooter who cleanly
kills a boar 30 studs away is tied because a driver stood 80 studs behind it in line.

**Known gap, stated rather than hidden:** the 45° filter is measured from the line's normal, so a shooter
far off the post line can endanger a driver at an angle outside the cone and the violation is never
published. `SAFETY_ARC_HALF_DEG` is the dial.

### 8.3 `Penalty.judge` — pure

```luau
export type Shot = { userId: number, muzzle: Vector3, aim: Vector3, stopAt: number, at: number }
Penalty.judge(shot, drivers: { DriverPos }, config): (boolean, string?)
    -- true only when SOME driver d satisfies all of:
    --   t = (d.position - shot.muzzle):Dot(shot.aim)                  -- aim is unit
    --   t > 0
    --   t <= math.min(shot.stopAt + config.SAFETY_BODY_STUDS, config.SAFETY_RANGE_STUDS)
    --   ((d.position - shot.muzzle) - shot.aim * t).Magnitude <= config.SAFETY_MISS_STUDS
Penalty.expired(tiedAt, now, config): boolean   -- false while config.TIE_UNTIL_DRIVE_END
Penalty.REASON = "driver-in-line"
```

`SAFETY_BODY_STUDS = 4` is the depth of a person, added to where the shot stopped: without it a shot that
**hits** a driver stops on his surface, a stud in front of his root, and would be judged harmless.

The owner asks three other questions before calling `judge`: is the phase `Running`, is this shooter
already tied, is `SAFETY_GRACE_SECONDS` over.

### 8.4 "Tied to a tree"

`Match.Body.tie(player, tree, config)`, the sole writer of every property: `WalkSpeed = 0`,
`JumpHeight`/`JumpPower = 0`, `PivotTo` beside the trunk at `TIE_GAP_STUDS = 2.5` **from its surface, on the
side the offender came from**, `HumanoidRootPart.Anchored = true`, one rope part in
`Workspace.DriveMarkers`, `Weapon.refreshArming` (the policy now says no, so the Tool goes), one
`MatchEvent` so everybody sees who was tied and why.

The anchor is `Body.anchorFor(markerSet, position)`: the nearest `DrivenHunt.Tree`, falling back to the
nearest post, falling back to **not tying at all** with `stats().tiesWithoutAnchor` — never a nil CFrame.
**Without an anchor the violation still happened**: the −50 points, the feed line and `Punished` all fire.

A tied player who presses Reset is **re-tied to the same tree** on `CharacterAdded` (`watchCharacter`).
Freed at the end of the drive (the `release` effect), on leaving, on `Match.forget`, and on `Match.stop`.
`TIE_UNTIL_DRIVE_END` is a **flag read**; `TIE_SECONDS = 60` is used only when it is false.

**A tie never crosses a drive boundary, so it never crosses a match boundary either.** Nothing about the
penalty is per match, and no tie can survive into `MatchOver`: `enterScoring` emits `release` before
`foldDrive`.

### 8.5 Arming

```luau
Weapon.setArmingPolicy(policy: ((Player) -> boolean)?)   -- nil restores Shotgun.CONFIG.shouldArm
Weapon.refreshArming(player: Player)                     -- re-evaluate now: grant or revoke
Match.mayCarryWeapon(player): boolean
    -- true iff the team is Shooters, or Drivers with DRIVERS_MAY_SHOOT,
    --         AND the player is not tied,
    --         AND the phase is NOT Waiting
```

**The one change the new phase forces, and it is a non-change:** the predicate is written as "not
`Waiting`", not as a list of three phase names, so `MatchOver` needs no edit and a gun does not vanish for
the 30 seconds of the result screen. If the Builder finds the list form in the code
(`state.phase == "Assigning" or "Running" or "Scoring"`), it becomes `state.phase ~= "Waiting"` in this
task, and §12.4 item 16 asserts a shooter may still carry in `MatchOver`.

`Shotgun.CONFIG.shouldArm` stays the default for a server with no Match — which is what
`tests/server/weapon_*.spec.luau` are, so those specs are untouched.

---

## 9. Public interface

Types are Luau annotations. `luau-lsp analyze` is not in CI, so they are documentation plus editor
checking, not a gate.

### 9.1 The wire — `ReplicatedStorage.Drive`

```luau
export type TeamName = "Drivers" | "Shooters"
export type PhaseName = "Waiting" | "Assigning" | "Running" | "Scoring" | "MatchOver"   -- NEW member

export type ScoreRow = { userId: number, name: string, team: TeamName?, points: number,
    kills: number, assists: number, pushes: number, violations: number, left: boolean }

export type MatchSnapshot = {
    phase: PhaseName,
    phaseEndsAt: number,        -- SERVER TIME (Workspace:GetServerTimeNow), not a duration
    driveNumber: number,        -- this SERVER's drive count, unchanged
    boarsReleased: number,      -- ANIMALS released this drive
    boarsLeft: number,          -- BOARS_PER_DRIVE - boarsAccounted
    waitingFor: { string },
    rows: { ScoreRow },         -- THIS DRIVE, dense, sorted by Score.leaderboard
    tied: { number },           -- dense array of userIds
    -- NEW, five fields:
    matchNumber: number,        -- 1, 2, 3...; 0 before the first match of the server
    driveInMatch: number,       -- k of drivesPerMatch; 0 when no match is in progress
    drivesPerMatch: number,     -- Match.CONFIG.DRIVES_PER_MATCH, so "2/4" is drawable
    matchRows: { ScoreRow },    -- THE MATCH, dense, sorted by the same Score.leaderboard.
                                -- team is always nil and left always false on these rows (section 7.5).
                                -- Empty before the first fold of a match.
    winners: { number },        -- userIds sharing the top of matchRows, ascending; {} when nobody is
                                -- above WINNER_MIN_POINTS. The Hud DRAWS it only in MatchOver.
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

**No new remote, and there is still no client→server remote in this system**, so its inbound exploit
surface stays zero. Written down so a later "ready up" or "skip the result screen" button does not quietly
add one without a design.

**`matchRows` is always populated, not only in `Scoring` and `MatchOver`**, and that is a considered trade:
one shape with one meaning against ~16 extra rows per push. The cost is bounded — the push is floored at
4 Hz and averages ≤ 1/s over a drive (`stats().broadcasts`, §11.6) — and a field that is empty except in two
phases is a second question ("is it empty because nobody scored, or because of the phase?") that a client
spec would have to encode.

**The timer is a server timestamp, not a countdown.** `phaseEndsAt` is `GetServerTimeNow`-based and the Hud
renders the difference locally every frame; `MatchOver`'s 30 seconds use exactly that and add no clock. The
server's own logic runs on `world.now()` (`os.clock`), and `serverTimeFor` is the one conversion.

Every table on the wire is a dense array or a pure dictionary: a mixed table does not survive serialisation
(`docs/design/shotgun.md` §2.3). `matchRows` and `winners` are built with `table.insert` in sorted order,
like `rows` and `tied`.

### 9.2 `ServerScriptService.Match` — the owner

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
                                       -- soundersReleased, boarsReleased, sounderHoldbacks,
                                       -- firstReleaseAfterSeconds,
                                       -- NEW: matches, matchesAbandoned, matchDrivesFolded,
                                       --      matchTotalsCleared
Match.PhaseChanged / Match.Scored / Match.Punished    -- BindableEvent .Event
Match.Phase / Roster / Score / Penalty / Markers / Body   -- exported for specs
Match.CONFIG
```

**No new public function, and no new signal.** Two deliberate decisions:

- **`PhaseChanged` gains a fourth argument**: `(before, after, driveNumber, matchNumber)`. Existing
  listeners take three and Luau drops the extra, so nothing else changes. A separate `MatchEnded` signal
  would be a second way to learn the same thing with no consumer; a spec watches `PhaseChanged` for
  `after == "MatchOver"`.
- **The match totals are read through `Match.snapshot()`**, not through a getter. The snapshot is already
  the one published view, already deep-frozen and already cached; a `Match.matchBoard()` would be a second
  reader shape of the one board, and the first thing a caller would do with it is sort it again.

`stats().matches` increments when the owner sees the phase become `MatchOver` (the same shape as the
existing `Assigning` detection in `dispatch`); the other three increment in the two effect appliers (§7.5).

`World`: `{ boars, weapon, markers?, players?, now?, serverTime?, remotes?, heartbeat?, collection?, rng? }`.
A spec passes its own for all of them.

### 9.3 Client

```luau
-- PlayerScripts.Match (UNCHANGED)
Match.start() / Match.get(): MatchSnapshot? / Match.Changed / Match.Feed
Match.phase(): string?
Match.secondsLeft(): number            -- max(0, phaseEndsAt - workspace:GetServerTimeNow())
Match.myTeam(): TeamName?              -- from Players.LocalPlayer.Team, NOT from the snapshot
Match.isTied(): boolean
```

The Hud draws: a drive bar, an event feed (`FEED_LINES = 5`, `FEED_SECONDS = 8`), the score screen, the
tied banner, **and the match result screen** (§9.5). Nothing else. All built in code, ASCII only.

**Dependency direction, one way:** the Hud reads `Match.get()` and `Match.Changed`; the Match holds no
reference to the Hud and does not know it exists.

**The drive bar, amended** (`renderDrive`, three small changes and nothing else):

| Phase | Bar reads |
|---|---|
| `Waiting` | `DRIVE 0/4   WAITING players,DrivenHunt.DriveLine` |
| `Assigning` | `DRIVE 1/4   ASSIGNING   0:18   SHOOTER` |
| `Running` | `DRIVE 1/4   9:12   BOARS 4   SHOOTER` |
| `Scoring` | `DRIVE 1/4   SCORING   0:21   SHOOTER` |
| `MatchOver` | `DRIVE 4/4   RESULT   0:27   SHOOTER` |

So: the first piece becomes `DRIVE %d/%d` from `driveInMatch` and `drivesPerMatch` (it was `DRIVE %d` from
`driveNumber`), and the phase word for `MatchOver` is **`RESULT`**, not `string.upper(phase)`'s
`MATCHOVER`. The first piece keeps the literal `DRIVE ` and a digit **in every phase, deliberately**:
`tests/client/match_client.spec.luau` asserts `string.find(text, "DRIVE %d")` unconditionally, and a bar
that dropped the word in one phase would make that a test which passes only because the harness never
reaches the phase. The match number is **not** on the bar; it is the result panel's title (§9.5).

### 9.4 The boar runtime's sounder interface (as built)

```luau
Boar.CONFIG.SOUNDER = { ... }                       -- section 11.7
export type SounderView = { id: string, leaderId: string?, memberIds: { string },
                            scatterFor: number, bornAt: number }   -- a COPY; there is no setter
Runtime:spawnSounder(center: Vector3, size: number, maxSpread: number?): { Handle }
    -- ALL OR NOTHING: returns {} and creates nothing when size < 1 or
    -- #self._boars + size > self._config.maxBoars.
    -- size == 1 -> exactly Runtime:spawn(center); NO sounder record.
    -- Otherwise `size` boars on a ring of radius
    --   max(BODY_SIZE.Z, min(SOUNDER.SPAWN_RING_STUDS,
    --                        (maxSpread or SPAWN_RING_STUDS) - SOUNDER.PAD_MARGIN_STUDS)),
    -- the phase from self._rng, leader = nearest to field.exitZ, tie-broken by id.
Runtime:sounders(): { SounderView }
Runtime:sounderOf(boarId: string): SounderView?
Runtime:capacity(): number            -- self._config.maxBoars
Runtime:count(): number               -- #self._boars, carcasses included
Runtime:stats()                       -- + soundersSpawned, soundersDissolved, leaderPromotions,
                                      --   membersLeft, scatters
```

`Runtime:spawn`, `takeHit`, `clear`, `boars`, `woundOf`, `step`, `run`, `destroy`, `Despawned`, `Hit`,
`Downed` keep their signatures. **This section stays normative for sounders until
`docs/design/boar-ai.md` is regenerated** (§14 item M1); the code headers cite it by heading text, not by
number.

### 9.5 NEW — the Hud's result panel

**`PlayerScripts.Hud` owns it, as it owns everything drawn.** It is a **second panel**, not a second mode of
the score panel, so each panel keeps exactly one writer and one visibility predicate — which is what
`Hud.renderScore`'s header already claims for itself and what "one predicate answers one question" means
here.

```luau
-- src/client/Hud/init.luau
Hud.renderMatch(snapshot, secondsLeft: number?)   -- THE ONE WRITER of MatchPanel. Public for the same
                                                  -- reason renderScore is: a match is 43 minutes, so no
                                                  -- harness run reaches MatchOver, and a spec that cannot
                                                  -- hand this the snapshot the wire would send cannot
                                                  -- check the panel is really on screen.
Hud.matchPanel(): Frame?
Hud.isMatchPanelVisible(): boolean
Hud.matchTitleText(): string
Hud.matchRowText(): { string }                    -- visible, non-empty rows only
Hud.matchFooterText(): string
```

**Visibility, one line each, and they are mutually exclusive:**

```
MatchPanel.Visible = snapshot ~= nil and snapshot.phase == "MatchOver" and Drive.CONFIG.SCOREBOARD_ENABLED
ScorePanel.Visible = snapshot ~= nil and snapshot.phase == "Scoring"   and Drive.CONFIG.SCOREBOARD_ENABLED
```

One switch (`SCOREBOARD_ENABLED`) gates both, because "is a board in the way" is one Karen question.
`renderDrive` calls `renderScore` and `renderMatch` in the **same pass from the same snapshot**, exactly as
it already calls `renderScore` and `renderTied`, so the two panels and the bar can never disagree about the
phase. Both clear their rows when hidden, so nothing stale flashes at the next entry.

**What the result panel says** (built once in `build()`, ASCII, `Enum.Font.Code`, `ZIndex = 6` so it is over
the score panel it replaces):

```
MATCH 1   RESULT
#  NAME             KILLS  POINTS
1  Karen                5     430   WINNER
2  Mila                 2     205
3  ...
NEW MATCH IN 27
```

- Rows come from `snapshot.matchRows` **in the order they arrived**. The Hud does not sort, rank by itself,
  or recompute a total: rank is the array index.
- `WINNER` is appended to a row whose `userId` is in `snapshot.winners` — every one of them, so a tie is
  shared on screen. With `winners == {}` no row carries it.
- Colour precedence, stated so it is one rule: **my own row is `SCORE_HIGHLIGHT_COLOR`**, else a winner's
  row is `MATCH_WINNER_COLOR`, else `TEXT_COLOR`.
- The footer is `string.format("NEW MATCH IN %d", math.max(0, math.floor(secondsLeft or 0)))`.
- No team column: over four drives you played both sides, so a team on a match row would be a lie about
  half of it (`accumulate` sets `team = nil` for the same reason).

**The score panel, amended** (`renderScore`):

- Title: `DRIVE %d/%d   SCORE` from `driveInMatch` and `drivesPerMatch` (it was `DRIVE %d   SCORE` from
  `driveNumber`; a spec asserting `"DRIVE 3"` still matches).
- Header: `#  NAME             TEAM     KILLS  POINTS  MATCH`, and each row gains the player's **match**
  total, looked up in a local `userId -> points` index built from `snapshot.matchRows or {}` once per
  render — ≤ 16 entries, and the only arithmetic the Hud does is the lookup. A row with no match entry (a
  leaver, marked `*`) shows `-`.
- Footer: `MATCH RESULT IN %d` when `driveInMatch >= drivesPerMatch`, else `NEXT DRIVE IN %d`. What comes
  next is the one thing the footer has ever said, and at the end of a match what comes next is the result.
- `SCORE_PANEL_WIDTH` 480 → **560** for the new column.

**`snapshot.matchRows or {}`, and `winners or {}`.** A render loop that errors on a payload kills the Hud
for the session, so the renderer tolerates a missing field; the assertion that the field is really on the
wire is made against the **live replica** in the client spec (§12.9 item 6), not against a fixture. Both
halves are needed: the tolerant renderer keeps the screen alive, the live assertion stops the tolerance
becoming a test that passes with nothing behind it.

---

## 10. Data on disk

**Everything positioned or coloured is built in code.** No `.rbxm` (banned), no typed property value in
JSON (`Vector3`, `CFrame`, `Color3` fail the harness as "cannot compare"; `TASKS.md` row 16, open).

The **one** data file in this system is `src/shared/Drive/Remotes.model.json` — a `Folder` with two
`RemoteEvent` children, no properties and no attributes. **This revision adds no file on disk at all**: the
result panel is built in code like everything else drawn, and `MATCH_PANEL_COLOR` is a `Color3` in a Luau
table, not in JSON.

`src/starterpack/` and `src/startergui/` stay empty: StarterPack hands a Tool to *every* player, which is
the opposite of what teams need.

---

## 11. Numeric targets — the one config table

Everything lives in `Match.CONFIG`, deep-frozen with `Drive.deepFreeze`, in `src/server/Match/init.luau`.
**K** marks Karen's feel values. **No magic number anywhere else in this system.** §11.7 is the sounder
block; §11.8 is the match block; the boar's own sounder numbers live in `Boar.CONFIG.SOUNDER`.

### 11.1 The drive

| Field | Value | K? | Basis |
|---|---|---|---|
| `DRIVE_SECONDS` | 600 | K | Karen: "10-minute drives" |
| `INTERMISSION_SECONDS` | 20 | K | long enough to read the teams and walk to your post |
| `SCORE_SECONDS` | 25 | K | long enough to read a 16-row board |
| `MIN_PLAYERS_STUDIO` | **1** | | **NEW field.** Director decision F: one player is a drive, so the harness's single Play client is armed |
| `MIN_PLAYERS_LIVE` | **2** | | **NEW field.** A drive needs a driver and a shooter; `ROADMAP.md` Milestone 3 "before release" |
| `MIN_PLAYERS` | **derived** | | **NEW shape:** `if RunService:IsStudio() then MIN_PLAYERS_STUDIO else MIN_PLAYERS_LIVE`. See below |
| `MAX_PLAYERS` | 16 | | `docs/PROJECT_CONTEXT.md` |
| `ODD_PLAYER_TEAM` | `"Shooters"` | K | with one player that player is a shooter and is armed |
| `SWAP_TEAMS_EACH_DRIVE` | `true` | K | everybody wants to shoot |
| `DRIVERS_MAY_SHOOT` | `false` | K | a switch, default OFF |
| `END_ON_LAST_BOAR` | `false` | K | a drive is ten minutes, not "until the boars run out" |
| `PLACE_TIMEOUT` | 5 s | | how long `Body.place` waits for a character before counting a miss |
| `STAND_HEIGHT_STUDS` | 3.5 | | above a post's top face |

**`MIN_PLAYERS` both ways, with no flag the harness must flip** (brief item 8). One read of
`RunService:IsStudio()` at the CONFIG boundary, in the module that **already reads it**
(`src/server/Match/init.luau`, `testGateOpen`), producing a plain number that the pure machine consumes as
`config.MIN_PLAYERS` and never derives itself:

```lua
MIN_PLAYERS_STUDIO = 1,
MIN_PLAYERS_LIVE = 2,
MIN_PLAYERS = if RunService:IsStudio() then 1 else 2,   -- ONE read; the two rows above are the literals
```

- The harness (`test` and `test2`) is always Studio, so it gets 1 and every existing spec and every armed
  single client is unchanged.
- **Karen's playtests are also Studio** (Play, or Test → Clients and Servers), so they get 1 too, and a
  solo playtest still plays.
- A **published live server** gets 2, which is the ROADMAP's requirement, and it lands now rather than
  becoming the kind of thing that ships by accident.
- **The live branch is therefore exercised by no harness run**, and that is the cost. It is covered the
  only honest way available: `match_phase.spec` drives the machine with `{ MIN_PLAYERS = 2 }` as a
  parameter and asserts one player stays in `Waiting` and two start a drive (§12.1 item 20), and
  `match_live.spec` asserts the derivation's two literals and that Studio resolved to the Studio one
  (§12.4 item 15). Named in §15 as unverified in a real server.
- **A flag was considered and rejected**: `Flags` holds booleans, a flag would have to be flipped by the
  Director for every playtest to get the value the playtest wants, and `test`/`test2` refuse to run while
  any override is set. `IsStudio` answers the actual question ("is this a real server") without a
  ceremony.

### 11.2 Boars — §6.3

`BOARS_PER_DRIVE = 6` (K) · `FIRST_RELEASE_SECONDS = 20` (K) · `RELEASE_INTERVAL_SECONDS = 90` (K) ·
`RELEASE_JITTER_SECONDS = 15` (K) · `MAX_ALIVE_BOARS = 6` · `SEED = 1`.

### 11.3 Points — §7.1 is the config, field for field.

### 11.4 The safety rule

| Field | Value | K? | Basis |
|---|---|---|---|
| `SAFETY_ENABLED` | `true` | | 1.7b is merged |
| `SAFETY_MISS_STUDS` | 12 | K | ≈ 3.4 m at 1 stud = 0.28 m |
| `SAFETY_RANGE_STUDS` | 330 | | `Shotgun.CONFIG.RANGE_STUDS.Slug` |
| `SAFETY_BODY_STUDS` | 4 | | the depth of a person (§8.3) |
| `SAFETY_GRACE_SECONDS` | 0 | K | the rule is the rule from the first second |
| `TIE_UNTIL_DRIVE_END` | `Flags.isOn("TIE_UNTIL_DRIVE_END")` → `true` | K | the flags system's worked example |
| `TIE_SECONDS` | 60 | K | used only when the flag is false |
| `TIE_GAP_STUDS` | 2.5 | K | from the trunk's surface |
| `ROPE_COLOR` / `ROPE_THICKNESS` | RGB(170, 130, 85) / 0.3 | K | checked on screen |
| `OUTFITS_ENABLED` | `Flags.isOn("ORANGE_OUTFITS")` → `false` | | M2.8d, §5.4 |

### 11.5 The wire

`STATE_MIN_INTERVAL = 0.25 s` · `STATE_HEARTBEAT = 5 s` · `MATCH_STEP_HZ = 4` · `PUSH_SAMPLE_HZ = 2`.
**Unchanged: the match adds no push and no remote.**

### 11.6 Performance and correctness targets, each one checkable

| Target | How it is checked |
|---|---|
| `Phase.step` ≤ 20 µs at 16 participants | `match_phase.spec`: 10 000 steps under 200 ms |
| `Score.kill` ≤ 10 µs | `match_score.spec`: 10 000 kills under 100 ms |
| A whole 600 s drive simulated in ≤ 50 ms | `match_phase.spec`, simulated `dt` |
| **A whole 4-drive match simulated in ≤ 200 ms** | `match_phase.spec`, real durations, `dt = 0.25` (§12.1 item 11) |
| **`Score.accumulate` over a 16-row board ≤ 50 µs** | `match_score.spec`: 10 000 accumulates under 500 ms |
| **Rows on the wire** | ≤ `MAX_PLAYERS` in `rows` and ≤ `MAX_PLAYERS` in `matchRows`, plus any synthetic contributor id; **no new broadcast** (`stats().broadcasts` per drive is unchanged) |
| **`MatchState` broadcasts** | ≤ 1/s average over a drive, from `stats().broadcasts` |
| **Match rows held for a player who left** | **0** (`Score.drop`; §12.3, §12.12) |
| **Folds per drive** | exactly **1** (`stats().matchDrivesFolded` rises by one per drive, §12.12) |
| **`clearMatchTotals` per match** | exactly **1**, and exactly 1 per abandonment (§12.1 items 13, 17) |
| **The live match boundary, added wall time** | ≤ 60 s for three drive boundaries plus the result phase, inside `REPORT_WINDOW` (300 s) and `REPORT_WINDOW_2P` (420 s) (§12.12) |
| Server raycasts per drive from this system | **0** |
| Per-player tables held after a player leaves | **0** (`Match.trackedPlayers()`) |
| `\|#Drivers − #Shooters\|` | ≤ 1 for every n in 1..16 |
| Typed-value harness problems from this task | **0** |
| `Brain:step` (follower, with a sounder) | ≤ 15 µs: 10 000 steps under 150 ms |
| `ComputeAsync` requests per sounder | ≤ 1 in flight, ≤ 2/s while fleeing; `stats().pathRequests ≤ 12` over a 3 s live flee with five |
| Boars in `_boars` at any moment | ≤ `BOARS_PER_DRIVE` within a drive, and `BOARS_PER_DRIVE ≤ Boar.CONFIG.maxBoars` asserted |
| Zero errors, zero skipped tests | `tests/TestKit.luau` fails the run otherwise |

### 11.7 The sounder numbers (as built)

**`Match.CONFIG.SOUNDER`** (the release): `ENABLED = Flags.isOn("BOAR_SOUNDERS")` → `false` ·
`MAX_SIZE = 5` (K) · `SIZE_WEIGHTS = { 40, 20, 18, 12, 10 }` (K) · `EXPECTED_SIZE = 2.32` (asserted equal to
the weighted mean) · `TAIL_SECONDS = 90` (K) · `GAP_MIN_SECONDS = 45` (K) · `GAP_MAX_SECONDS = 180` (K) ·
`HOLDBACK_WARN = 20`.

**`Boar.CONFIG.SOUNDER`** (the behaviour; 1 stud = 0.28 m, against `BODY_SIZE = (2, 3, 5.5)`,
`SPRINT_SPEED = 38`, `DETECT_RADIUS = 40`):

| Field | Value | K? | Basis |
|---|---|---|---|
| `SPAWN_RING_STUDS` | 10 | | 5 on a ring of 10 stand 11.8 studs apart with a 5.5-long body |
| `PAD_MARGIN_STUDS` | 4 | | clamped inside `spawnRadius − 4`: 10 at a pad radius of 14 **and** of 30 |
| `SLOT_BACK_STUDS` / `SLOT_SIDE_STUDS` | 9 / 7 | K | ~1.6 body lengths back, two abreast |
| `FORMATION` (leader frame, +Z = behind) | slot 2 `(−7, 0, 9)`, 3 `(+7, 0, 9)`, 4 `(−3.5, 0, 18)`, 5 `(+3.5, 0, 18)` | K | a wedge ~18 studs wide, inside a 96-stud gate |
| `COLUMN_SPACING_STUDS` / `COLUMN_LATCH_SECONDS` | 9 / 1.5 | | single file while `blockedAhead` |
| `SLOT_TOLERANCE_STUDS` | 5 | | inside it, cohesion is 0 |
| `NEIGHBOUR_STUDS` / `SEPARATION_STUDS` | 25 / 7 | | the boids neighbourhood; 1.3 body lengths |
| `COHESION`/`SEPARATION`/`ALIGNMENT`/`FLEE_WEIGHT` | 1.0 / **1.6** / 0.4 / 0.8 | | separation dominates (§16 source H) |
| `IDLE_COHESION` / `IDLE_SPREAD_STUDS` | 0.5 / 18 | K | a grazing sounder is a loose group |
| `CATCHUP` | 1.15 | | capped at `SPRINT_SPEED` |
| `BREAK_STUDS` / `BREAK_SECONDS` | 60 / 4 | K | 1.5 × `DETECT_RADIUS`; then it is a lone boar |
| `SCATTER_SECONDS` / `SCATTER_SEPARATION` / `SCATTER_ON_HIT` | 6 / 3.0 / `true` | K | the sounder breaks up at the shot |
| `LEAVE_ON_MORTAL` / `LEADER_PATHS_ONLY` | `true` / `true` | K / — | a dying animal drops out; one route per sounder |

### 11.8 NEW — the match numbers

**`Match.CONFIG`:**

| Field | Value | K? | Basis |
|---|---|---|---|
| `DRIVES_PER_MATCH` | **4** | K | Director decision 1. **Even**, asserted (§12.4 item 14), because the reason for 4 is that with `SWAP_TEAMS_EACH_DRIVE` every player shoots twice and drives twice |
| `MATCH_RESULT_SECONDS` | **30** | K | Director decision 3. Longer than `SCORE_SECONDS` = 25: it is a 16-row board **plus** the winner, and it is the one screen a player will want to read twice |
| `MATCH_ABANDON_SECONDS` | **120** | K | Director decision 6. Two minutes of an empty server: long enough for one player to rejoin after a crash, short enough that nobody inherits a stranger's match |
| `WINNER_MIN_POINTS` | **1** | K | below it `winners` is empty, so sixteen players on 0 are not sixteen winners (§7.5) |
| `SHORT_MATCH` durations | `DRIVE 90` / `INTERMISSION 10` / `SCORE 10` / `RESULT 20` | K | §12.10: a whole 4-drive match in **7.7 minutes** instead of 43.5, for a playtest and the screenshots. **Reachable only through the `SHORT_MATCH` flag, which the harness refuses to run with set** |

Arithmetic, both ways: a match is `4 × (600 + 20 + 25) + 30 = 2,610 s` (43.5 min) at the real numbers and
`4 × (90 + 10 + 10) + 20 = 460 s` (7.7 min) short. A drive's boar budget is unchanged, so a match is 24
animals.

**`Drive.CONFIG` (layout only, `src/shared/Drive/init.luau`):**

| Field | Value | Basis |
|---|---|---|
| `SCORE_PANEL_WIDTH` | 480 → **560** | the new `MATCH` column |
| `MATCH_PANEL_WIDTH` | 520 | narrower than the score panel: four columns, not six |
| `MATCH_ROWS_MAX` | 16 | `Match.CONFIG.MAX_PLAYERS` |
| `MATCH_TITLE_SIZE` / `MATCH_TEXT_SIZE` | 22 / 16 | as the score panel, so the two read as one family |
| `MATCH_PANEL_COLOR` | RGB(16, 18, 20) | as the score panel |
| `MATCH_PANEL_TRANSPARENCY` | **0.15** | more solid than the score panel's 0.25: the end of a match is not the end of a drive, and the difference must be visible at a glance |
| `MATCH_WINNER_COLOR` | RGB(255, 215, 90) | a winner's row, when it is not your own |
| `WINNER_TEXT` | `"WINNER"` | ASCII, appended to every winning row |
| `SCORE_HIGHLIGHT_COLOR` | RGB(255, 232, 150) | unchanged; **your own row wins over the winner colour** (§9.5) |

Two colours at RGB(255, 215, 90) and RGB(255, 232, 150) are close, and that is the point of the precedence
rule rather than a second colour: **checked on screen in 84b's shot 2**, because two colours in this repo
have read wrong on the first try (`TASKS.md` rows 22, 24).

---

## 12. How it is tested

`tests/server/` → `ServerStorage.Tests`; `tests/client/` → `ReplicatedStorage.ClientTests`. Specs **write
their own numbers rather than importing `CONFIG`** for the assertion, following
`tests/server/test_arena.spec.luau`, so a spec disagreeing with the config is a finding and not a
tautology. Rule 6: these test the player's path, not the harness.

**The gate for this task**: it touches `src/`, so `test` **and** `test2` (Director decision 2026-09-26),
both on a clean tree, both naming the code commit. And **`python tools/flags.py clear` before either run** —
both refuse to start while any override is set, which is exactly the trap the screenshot procedure in
§12.10 walks into if it is done in the wrong order.

### 12.1 `tests/server/match_phase.spec.luau` — CHANGED, pure

Everything it asserts today stays (including items 1–10 on the release schedule, the flag-off identity
proof and the hold-back). Its local `CONFIG` gains `DRIVES_PER_MATCH = 2`, `MATCH_RESULT_SECONDS = 3`,
`MATCH_ABANDON_SECONDS = 20`, so a whole match is a few hundred simulated seconds. Added:

11. **A WHOLE MATCH, as a phase path.** From `ready(cfg)` plus one join, stepping simulated time, the
    phases arrive in exactly this order: `Assigning, Running, Scoring, Assigning, Running, Scoring,
    MatchOver, Assigning`; `driveInMatch` reads `1,1,1,2,2,2,2,1`; `matchNumber` reads `1` throughout and
    `2` on the last. With the real durations and `dt = 0.25`, the four-drive version of the same walk runs
    **under 200 ms** (§11.6).
12. **`foldDrive` is emitted exactly once per drive, on the `Scoring` entry, and BEFORE the forced
    `broadcast` in the same effect list.** Asserted by index in `kinds(effects)`, not by presence — the
    order is the fix for `TASKS.md` 32a(c) and an assertion on presence alone would not see it move.
13. **`clearMatchTotals{reason = "newMatch"}` is emitted exactly once per match**, on the `Assigning` that
    starts it, and **never** on drives 2..N. Over two simulated matches: exactly two.
14. **`MatchOver` lasts exactly `MATCH_RESULT_SECONDS`**, takes no other transition inside it, emits no
    `spawnSounder`, no `assignTeams` and no `clearBoars`, and `Phase.isLive(state)` is false in it.
15. **`MatchOver` → `Waiting`** when the roster fell below `MIN_PLAYERS`, with `driveInMatch == 0`; and then
    → `Assigning` when it recovers, with `matchNumber` incremented and `driveInMatch == 1`.
16. **A mid-match gap KEEPS the counter:** `Scoring` elapsed with no participants → `Waiting` with
    `driveInMatch == 1` unchanged and **no** `clearMatchTotals`; a join `MATCH_ABANDON_SECONDS − 1` later
    resumes **the same match** at `driveInMatch == 2`.
17. **Abandonment, once.** The same state with no join: at exactly `MATCH_ABANDON_SECONDS`, one
    `clearMatchTotals{reason = "abandoned"}`, `driveInMatch == 0`, one feed line, one forced broadcast — and
    stepping another 60 simulated seconds emits **no** second one.
18. **`DRIVES_PER_MATCH = 1` is a legal match**: one drive, then `MatchOver`. The degenerate case, because
    Karen may try it while tuning.
19. **The release schedule is untouched by the counter.** For a fixed `driveNumber` and seed, the sizes and
    times are identical to the same drive before this revision (the recorded literal schedule of item 1),
    and drive 1 of match 2 (`driveNumber == 5`) draws a **different** sequence from drive 1 of match 1 —
    because the hash is over `seed + driveNumber`, which keeps rising.
20. **`MIN_PLAYERS = 2`, through the parameter** (the live-server value, §11.1): one participant stays in
    `Waiting` for ten simulated minutes; a second one starts the drive on the step that arrives.
21. 10 000 steps under 200 ms (unchanged), now with the counter fields present.

### 12.2 `tests/server/match_roster.spec.luau` — unchanged

Every n from 1 to 16 balances to within one; n = 1 gives one shooter; the odd player follows
`ODD_PLAYER_TEAM`; `SWAP_TEAMS_EACH_DRIVE` swaps where sizes allow; order-independence; no `Random`, no
service, no Instance reachable from the module.

### 12.3 `tests/server/match_score.spec.luau` and `match_safety.spec.luau` — CHANGED (score), unchanged (safety)

Score keeps every assertion it has (every zone; `unknown` scored as `body` and counted; an assist at
exactly `ASSIST_MIN_DAMAGE` and none one below; the killer never also assists; push credit inside both
`PUSH_RADIUS` and `PUSH_WINDOW` and none outside either; `ESCAPE_WOUNDED`; a violation worth
`SAFETY_PENALTY` with points allowed negative; `leave` keeps the row; the full tie-break chain; inputs never
mutated and results frozen; 10 000 kills under 100 ms). Added, as one `describe("the match total")`:

1. **Totals across drives:** three drive boards (a kill, a push plus an assist, a violation) folded in turn
   give the arithmetic sum per `userId` for `points`, `kills`, `assists`, `pushes`, `violations`; the
   negative drive **reduces** the total.
2. **`team` is nil and `left` is false on every match row**, whatever the drive rows said.
3. **`firstKillAt` is the earliest of the folds**, nil-safe when one side has none.
4. **A row marked `left` is not folded** (the leaver rule): folding a board whose only row is `left` leaves
   the total unchanged and creates no row.
5. **A row the drive does not mention survives the fold unchanged** (identity by reference is allowed and
   asserted as equality of fields, since rows are frozen and shared).
6. **Inputs are not mutated and the result is frozen all the way to a row** (`expect(function() … end).to.throw()`).
7. **Not idempotent, by design:** folding the same board twice doubles it. Asserted so that nobody "fixes"
   the fold into an idempotent merge and hides a double-fold bug the owner's "once per drive" is what
   prevents (§12.1 item 12).
8. **`drop`** removes exactly that row and nothing else; dropping an absent row returns a board equal to the
   input.
9. **A joiner starts at 0:** a board with no row for a `userId`, folded with a drive in which they scored,
   gives exactly the drive's numbers — there is no hidden starting value.
10. **`winners`**: a single top; a two-way tie returns both, ascending by `userId`; a three-way tie returns
    three; an empty board returns `{}`; a top of 0 with `minPoints = 1` returns `{}`; a negative top returns
    `{}`; and `winners` never returns a `userId` that is not on the board.
11. **`leaderboard` on a match board** uses the same total order (points, kills, `firstKillAt`, `userId`) —
    the assertion that there is one sort in this system and not two.
12. 10 000 `accumulate` of a 16-row board under 500 ms.

Safety, unchanged: a driver on the ray at 50 with `stopAt = 100` → violation; the same at `stopAt = 40` →
none; `stopAt` exactly on the driver's surface → violation (`SAFETY_BODY_STUDS`); 12.0 studs off →
violation, 12.1 → none; behind the muzzle → none; no drivers → none; a zero-length `aim` → none and no
error; two qualifying drivers → one violation; `Penalty.expired` in **both** flag states.

### 12.4 `tests/server/match_live.spec.luau` — CHANGED, live

Everything it asserts today stays (the drive left `Waiting`; two `Team`s with `AutoAssignable = false`;
shooters armed and **holding** a gun; the markers and the line's direction; a frozen-all-the-way-down
snapshot; one entry per player; `Downed` and `SafetyViolated` connected; the config frozen; items 11–13,
the sounder invariants). Added:

14. **The match's cross-owner invariants, in one `it`:** `DRIVES_PER_MATCH` is an integer `>= 2` and
    **even** (§5.2 — the Director's reason for 4 is the swap, and an odd count silently breaks it);
    `MATCH_RESULT_SECONDS > 0`; `MATCH_ABANDON_SECONDS > 0`; `WINNER_MIN_POINTS >= 1`.
15. **`MIN_PLAYERS` both ways:** `MIN_PLAYERS_STUDIO == 1`, `MIN_PLAYERS_LIVE == 2`,
    `MIN_PLAYERS_LIVE >= MIN_PLAYERS_STUDIO`, and — because this is Studio — `MIN_PLAYERS == MIN_PLAYERS_STUDIO`.
    Printed with `TestKit.note`, so the live value is in every report rather than in somebody's memory.
16. **The snapshot carries the match, and it is frozen:** `matchNumber`, `driveInMatch`,
    `drivesPerMatch == Match.CONFIG.DRIVES_PER_MATCH`, `matchRows` and `winners` are present, both dense
    arrays, and writing into `matchRows` throws. And **a shooter may still carry a gun in `MatchOver`**:
    `Match.mayCarryWeapon` is asserted to depend on `phase ~= "Waiting"` and not on a list of three names
    (§8.5), by checking the predicate for the live player while the phase is `Running` and asserting the
    implementation reads the negative form — the observable half of it is §12.12, where a gun is still in
    hand during the result screen.
17. **The flag is wired and OFF on a clean run:** `Flags.isOn("SHORT_MATCH")` is `false`, and therefore
    `Match.CONFIG.DRIVE_SECONDS == 600`, `INTERMISSION_SECONDS == 20`, `SCORE_SECONDS == 25`,
    `MATCH_RESULT_SECONDS == 30` — so a harness PASS can never have been produced against the short
    numbers. `tests/server/flags.spec.luau` mirrors the first half of that assertion, as it does for
    `BOAR_SOUNDERS`.
18. **The new counters exist and are consistent early in the session:** `stats().matches == 0`,
    `matchesAbandoned == 0`, `matchDrivesFolded == 0` before the first `Scoring`, and `matchTotalsCleared == 1`
    (the first `Assigning` cleared the totals of the match it started).

### 12.5 `tests/server/test_arena.spec.luau` — unchanged

Exactly one `DrivenHunt.DriveLine`, 8 posts, ≥ 1 driver start, 4 boar spawns, ≥ 1 tree; **the line's
`LookVector.Z > 0.99`**; posts inside the plate and between `exitZ` and the driver start; posts 40 apart and
stably sorted; `build` twice adds no second set of tags. It spells the tag strings literally **on purpose**.

### 12.6 `tests/server/boar_brain.spec.luau` — unchanged

With `obs.sounder == nil` the intent sequence over 600 steps from a fixed seed is identical to the recorded
baseline, and a **leader**'s intents are identical to a lone boar's for the same threats.

### 12.7 `tests/server/boar_sounder.spec.luau` — unchanged, pure

A follower never returns a `pathRequest` and a leader does; a follower closes 30 studs to its slot and then
holds it without oscillating; separation dominates and the turn-rate limit is not bypassed; the follower's
speed never exceeds `SPRINT_SPEED` or `leader.speed × CATCHUP`; `blockedAhead` latches the column;
scattering removes cohesion and alignment and still produces motion; herd panic and herd calm; a mortally
wounded follower still runs at `speedScale`; determinism; `dt = 5` clamped; 10 000 follower steps under
150 ms.

### 12.8 `tests/server/boar_body.spec.luau` — unchanged, live

One real sounder of five on its own plate at y = 500: five parts inside the spread and apart from each
other; all-or-nothing at capacity; `size == 1` makes no sounder record; after 3 s of threat every member is
within `BREAK_STUDS`, above 0.4 × `SPRINT_SPEED` and **upright** (`CFrame.UpVector.Y > 0.9`); killing the
leader promotes one and scatters; a dragged member leaves; a mortal wound removes a member; the path budget
(`pathRequests <= 12`, `pathFailures == 0`); the last member dissolves the sounder;
`Runtime:clear("driveOver")` removes all five.

### 12.9 `tests/client/match_client.spec.luau` — CHANGED

The six existing assertions stay, including the parent-visibility chain for the score panel (the assertion
that makes "a visibility audit ignored parent visibility and certified a blank screen twice" impossible to
repeat) and the "no rule number on the wire" list. The `LIVE` and `scoring()` fixtures gain the five new
snapshot fields (`matchNumber = 1`, `driveInMatch = 3`, `drivesPerMatch = 4`, a two-row `matchRows`, a
one-element `winners`). Added, as one `describe("the match result screen")` with an `afterAll` that restores
both panels from the live snapshot:

1. **It is really on screen in `MatchOver`:** `Hud.renderMatch(matchOver(), 27)` → `isMatchPanelVisible()`
   is true, **every ancestor exists and is visible** and the `ScreenGui` is `Enabled` (the ancestor walk,
   not just `Visible`), and `BackgroundTransparency < 1`.
2. **It is hidden in every other phase** — `Running`, `Assigning`, `Scoring`, `Waiting` — and its rows are
   **cleared**, not merely hidden, so nothing stale flashes at the next match end.
3. **The two panels are mutually exclusive:** in `MatchOver` `isScorePanelVisible()` is false; in `Scoring`
   `isMatchPanelVisible()` is false.
4. **The rows say what the server sent:** two rows, rank 1 then 2, each carrying its name, kills and
   points; **`WINNER` appears on the winning row and only there**; my own row is
   `SCORE_HIGHLIGHT_COLOR` and the other is not; no `"nil"` anywhere; ASCII only
   (`string.match(text, "^[%w%s%p]+$")`).
5. **The titles and footers:** `matchTitleText()` contains `"MATCH 1"`; `matchFooterText()` equals
   `"NEW MATCH IN 27"`; with `winners = {}` **no** row carries `WINNER` and both still render.
6. **The wire really carries the fields** (not the fixture): from the **live replica**,
   `Match.get().drivesPerMatch == 4`, `matchNumber >= 1`, `type(matchRows) == "table"` and
   `type(winners) == "table"`. This is the one assertion that would fail if 84a's snapshot fields were
   missing, which is why it reads the replica and not a table the spec wrote.
7. **The score screen shows the match column:** `Hud.renderScore(scoring(), 12)` → row 1's text contains
   the player's **match** total as well as the drive points; a row marked `left` shows `-` in that column;
   the title contains `"DRIVE 3/4"`; the footer reads `"NEXT DRIVE IN 12"`, and with
   `driveInMatch == drivesPerMatch` it reads `"MATCH RESULT IN 12"`.

**No new input scenario**: the drive consumes no player input, and a scenario pressing keys nothing is
bound to would be evidence of nothing.

### 12.10 Screenshots (rule 5), and the 43-minute problem

**The harness can run two players.** `test2` is in the merge gate
(`[harness2] PASS: n/m checks @ <commit> (clean tree)`).

**The problem, stated as a number:** the result screen is 2,610 seconds into a session at the real config
(§11.8). Nothing in this repo can photograph it — `Match.advanceForTests` is gated to a harness run whose
Play session the Builder does not control, and a 43-minute manual playtest per iteration is not a
procedure anybody will repeat.

**The instrument: one flag, four durations, no second code path.**

```lua
SHORT_MATCH = {
    default = false,
    owner = "ServerScriptService.Match",
    born = "2026-09-27 task 84",
    expires = "2026-10-18",       -- 21 days: the ceiling in feature-flags.md section 12
    why = "A whole match in ~8 minutes instead of 43, so the match loop can be played and photographed. OFF is the real 10-minute drive.",
}
```

**One read, at the boundary, in the only permitted shape** (`docs/design/feature-flags.md` §10) — a local
above `Match.CONFIG`, used by four rows inside it:

```lua
local SHORT = Flags.isOn("SHORT_MATCH")   -- the ONE read
...
DRIVE_SECONDS = if SHORT then 90 else 600,            -- K
INTERMISSION_SECONDS = if SHORT then 10 else 20,
SCORE_SECONDS = if SHORT then 10 else 25,
MATCH_RESULT_SECONDS = if SHORT then 20 else 30,      -- K
```

It switches **four durations and nothing else**: no rule, no phase, no counter, no board, no code path. The
pure machine cannot tell the difference, which is why every §12.1 assertion is made with the spec's own
numbers anyway, and why both states are testable while the flag sits at one of them. `test` and `test2`
refuse to run while any override is set, so no harness evidence can come from the short numbers, and
§12.4 item 17 asserts the long ones on a clean run.

**The procedure, and the order matters:**

1. `python tools/studio_mcp.py test` and `test2` on the clean tree, **with no override set** — the merge
   evidence.
2. `python tools/flags.py set SHORT_MATCH on` (Edit mode), then `python tools/flags.py` to see it.
3. Start Play, `python tools/flags.py live` to confirm what it resolved, play ~8 minutes, and capture with
   `python tools/studio_mcp.py capture <name> [camera] [look-at]`.
4. `python tools/flags.py clear` **before any further harness run.** Forget it and `test` refuses, with the
   clear command printed.

**Three shots, each inspected by the Builder and described as what is on screen, not as what should be:**

1. **The score screen at the end of drive 1**, with the new `MATCH` column: does the column read as a
   total, and is the header still aligned at 560 wide?
2. **The result screen**, with at least two rows and a winner: is `WINNER` on the right row, is my own row
   distinguishable from the winner's (the two near-identical yellows, §11.8), and is the panel visibly
   different from the score panel?
3. **The drive bar in `MatchOver`**: does it read `DRIVE 4/4   RESULT   0:nn`, and is the score panel gone
   rather than layered under the result panel?

**`NEEDS KAREN` — the playtest, with the exact clicks.** The one thing no tool here can judge:

> 1. Director, Edit mode: `python tools/flags.py set SHORT_MATCH on`, then `python tools/flags.py`.
> 2. Studio → **Test** → **Clients and Servers** → **Players: 2** → **Start**.
> 3. Play a whole match (~8 minutes): four short drives, swapping sides each drive, then the result screen.
> 4. Say which of these is wrong: four drives is the right length for a match; the teams swap the way you
>    expect; the running match total on the drive screen is the number you want to see there; the result
>    screen says who won clearly enough, and 30 seconds (20 short) is the right length for it; a new match
>    starting from zero feels like a fresh start rather than a reset you did not ask for.
> 5. Director: `python tools/flags.py clear`.

### 12.11 Process hazards

- **Rojo 7.7.0 panics when a watched file vanishes**, and a large branch switch alone crashed it once. Stop
  `rojo serve` before switching; expect a **NEEDS KAREN** Connect click. This task adds **no new file**
  (every change is to a file that exists), so the risk is the branch switch, not the change.
- **`tools/flags.py clear` before every harness run** (§12.10). A forgotten override does not silently
  reset: the harness refuses, which is the design working.
- **If 84a and 84b are separate tasks**, 84b branches from 84a's branch and targets it (a stacked PR), and
  says so in `Base:`.
- **The added live spec eats wall clock** (§12.12). If the two-player run comes close to
  `REPORT_WINDOW_2P` (420 s), the phase table in the harness output is the evidence for which part grew,
  and the fix is the spec's own `PHASE_TIMEOUT`, not a shorter `CLIENTS_DONE_TIMEOUT`: waiting for the
  clients is what stops this spec from breaking the client suite.

### 12.12 NEW — the live match boundary

**It goes into `tests/server/zz_drive_boundary.spec.luau` as a second `describe`, appended after the
existing one**, and not into a new file. Two reasons, both about evidence rather than tidiness: TestEZ runs
`describe`s within a file in declaration order, so "after the drive boundary" is **guaranteed** here and
only *conventional* between two `zz_` files (the repo's ordering rests on the prefix, which is not asserted
anywhere); and the existing block has already done the expensive, delicate part — waiting for every client
to finish (`CLIENTS_DONE_TIMEOUT = 240`, and a client attribute does **not** replicate to the server, which
is why the harness sets `ServerStorage.ClientsFinished`). Doing that twice would double the risk and the
wall clock. The file's header gains a sentence saying it now covers both boundaries.

It enters with the session at match 1, drive 2 (the first block crossed one boundary). It asserts, on the
**real production owner**, with the **real config**:

1. **Where it starts:** `Match.snapshot().matchNumber == 1`, `driveInMatch == 2`,
   `drivesPerMatch == Match.CONFIG.DRIVES_PER_MATCH`, and `stats().matchDrivesFolded == 1` — one drive has
   ended, so one fold has happened.
2. **Every remaining boundary, one at a time**, with `Match.advanceForTests(DRIVE_SECONDS + 1)` then
   `advanceForTests(SCORE_SECONDS + 1)` and `waitUntil(PHASE_TIMEOUT, …)` for each phase: at each `Scoring`
   it records `Match.snapshot().rows` (the drive's points per `userId`) and asserts
   `matchDrivesFolded` rose by **exactly one**, and `driveInMatch` rose by exactly one until the last drive.
3. **The totals are the sum of the drives** — the assertion the brief asks for, on the owner and not on the
   pure module: for every `userId` in `matchRows`, `points` equals the sum of that user's `points` in the
   per-drive `rows` the spec recorded, and `kills` likewise. With one player and an empty board both sides
   are 0 and the assertion is about shape; **in the two-player run a real shot has really tied somebody and
   a real −50 is in the sum**, which is stated rather than hidden (the same split this file already makes).
4. **The result phase:** after the last drive's `Scoring` elapses, `Match.phase() == "MatchOver"` within
   `PHASE_TIMEOUT`; `stats().matches == 1`; `snapshot().phaseEndsAt - Workspace:GetServerTimeNow()` is
   within 1 s of `MATCH_RESULT_SECONDS`; `matchRows` is non-empty and sorted non-increasing by `points`;
   every `userId` in `winners` is on `matchRows` with the top `points`, and `#winners == 0` only when the
   top is below `WINNER_MIN_POINTS`; **every player still holds their gun** (the §8.5 claim, observed).
5. **The new match:** `advanceForTests(MATCH_RESULT_SECONDS + 1)` → `Assigning`, and — reading
   **`Match.lastSent()`, the payload, not the snapshot** (`TASKS.md` 32a(c)) — `matchNumber` is one higher,
   `driveInMatch == 1`, `#matchRows == 0`, and every row of `rows` is at 0 points, 0 kills, 0 violations
   and `left == false`. `stats().matchTotalsCleared` rose by exactly one and `matchesAbandoned == 0`.
6. **`TestKit.note`, every run and not only on failure** (Task 79's lesson): the phase path taken, the
   seconds of test clock used, `matchDrivesFolded`, `matches`, the number of match rows and the winner
   count. A run where the drive was left alone because a client never reported must say so in the report
   rather than passing quietly.
7. **Wall clock:** three boundaries at `PHASE_TIMEOUT = 20` worst case each, so ≤ 60 s added inside
   `REPORT_WINDOW` (300 s) / `REPORT_WINDOW_2P` (420 s) — §11.6, and the note in item 6 carries the real
   number so a regression is visible in the same output as the verdict.

**Abandonment is not in this spec, and that is deliberate**: reaching `Waiting` needs the participant count
to fall below `MIN_PLAYERS`, which in Studio is 1, so it would mean removing the only player from a running
harness session. It is proved purely (§12.1 items 16–17) and named in §15.

---

## 13. Rows for `GAME_DESIGN.md` — ready to paste

Rule 3 requires the owners table to mirror this file. **Three amended rows; no new row**, because the match
creates no new owner — which is the point of §7.5.

- **Game state / the drive** (append to the existing owner cell): "… Since Task 84 it also owns **the
  match**: `DRIVES_PER_MATCH` drives (4) make one match, and `Match.Phase` holds the counter
  (`matchNumber`, `driveInMatch`, `waitingSince`) and the fifth phase `MatchOver`, which shows the match
  result for `MATCH_RESULT_SECONDS`. Points accumulate across the match in **one** match board held by
  `ServerScriptService.Match` and written in exactly two places — `applyFoldDrive` (once per drive, on the
  `Scoring` entry, through the pure `Score.accumulate`) and `applyClearMatchTotals` (a new match, or a
  `Waiting` gap longer than `MATCH_ABANDON_SECONDS`). `Match.forget` **drops** a leaver's match row
  (`Score.drop`), so the result screen has no ghost rows, and `Score.winners` names the winner, ties
  shared. The pure machine never sees a score: it emits `foldDrive` and
  `clearMatchTotals` as effects. `MIN_PLAYERS` is derived once at the config boundary —
  1 in Studio (the harness's single Play client), 2 on a live server — with no flag to flip
  ([drive design](docs/design/drive.md) sections 4.5, 7.5, 11.1). The playtest instrument `SHORT_MATCH`
  shortens four durations and nothing else ([feature flags](docs/design/feature-flags.md))."
- **UI / anything drawn** (append): "… Since Task 84 it also draws the **match result screen**:
  `Hud.renderMatch` is the one writer of `MatchPanel`, visible **iff** `snapshot.phase == "MatchOver"` and
  `Drive.CONFIG.SCOREBOARD_ENABLED`, mutually exclusive with the score panel, and public for the same
  reason `Hud.renderScore` is — a match is 43 minutes, so no harness run reaches the phase. It renders
  `matchRows` and `winners` **in the order the server sent them**: the Hud never sorts, ranks or totals
  ([drive design](docs/design/drive.md) section 9.5)."
- **Drive wire contract** (append): "… Since Task 84 the snapshot also carries the match:
  `matchNumber`, `driveInMatch`, `drivesPerMatch`, `matchRows` (the match totals, sorted by the same
  `Score.leaderboard`, `team` always nil) and `winners`. Still two server→client RemoteEvents and nothing
  inbound, and still no rule number: `DRIVES_PER_MATCH`'s **value** rides the snapshot so a client can draw
  '2/4', while the numbers that could be exploited stay in `Match.CONFIG`."

`Input` stays `_unassigned_` as a system: this design binds no input and reserves no prefix.

---

## 14. Open decisions — none of them blocks building

Every one has a default in `Match.CONFIG`, `Drive.CONFIG` or this document, so the Builder can build, test
and report without an answer.

### Karen (feel) — the "check this" list

1. **Is four drives a match?** `DRIVES_PER_MATCH = 4`. Eight would be 87 minutes at the real numbers, two
   would be 22. The even-number rule (§5.2) is the only constraint.
2. **Is 30 seconds the right result screen?** `MATCH_RESULT_SECONDS`. Longer and the wait between matches
   drags; shorter and a 16-row board cannot be read.
3. **Should the drive score screen carry the running match total as a column, or as one line for you
   only?** Default: a column for everybody (§9.5). The column is the widest change to a screen she has
   already approved.
4. **Should nobody be the winner when nobody scored?** Default yes: `WINNER_MIN_POINTS = 1`, so `winners` is
   empty and no row says `WINNER`. The alternative is sixteen winners on 0.
5. **Is two minutes right for abandoning a match?** `MATCH_ABANDON_SECONDS = 120`.
6. **Does a new match starting from zero feel right**, or should something carry over (a match count, a
   session leaderboard)? Default: nothing carries over. Carry-over is a new system with a new owner.
7. **Do sounders read as animals or as a queue?** (carried) `SLOT_*`, `SEPARATION_STUDS`, the wedge.
8. **Is a scatter of 6 s right, should a hit scatter them or only a kill, and should a wounded pig leave the
   group?** (carried) Defaults: 6 s, any hit, yes.
9. **Are 40 % singles right?** (carried) `SIZE_WEIGHTS`.
10. **Does the drive feel empty between sounders?** (carried) `BOARS_PER_DRIVE = 6` is the dial, and §12.4
    item 11 forces `MAX_ALIVE_BOARS` and `maxBoars` to move with it.
11. **Are the points right, and is ten minutes right?** (carried) head 100 / chest 80 / body 50 / legs 30;
    `DRIVE_SECONDS = 600`.

### Director (scope)

- **N. The match is NOT behind a feature flag, and `SHORT_MATCH` is.** Default: **as written.** The
  brief asks for the match itself and calls its numbers "changeable `CONFIG` values", and a flag whose OFF
  state is "the session never ends" would leave the ROADMAP milestone unbuilt while adding a second phase
  path to reason about. What *is* flagged is the playtest instrument (§12.10), because that one really is
  dark: four durations, no rule, no path.
- **O. Split into 84a (the match exists, server) and 84b (the player sees it, client)** (§0 item 6).
  Default: **split**, and my recommendation. The named cost is 30 seconds of `MATCH OVER` with no panel
  between the two merges.
- **P. No per-match scoring of any kind** — no bonus, no streak, no multiplier, no "sounder" category
  (§7.1, §7.5). The brief asked for accumulation, and accumulation is addition.
- **Q. `BOAR_SOUNDERS` expires 2026-10-17, nine days out** (§6.9), and an expired row fails
  `tests/server/flags.spec.luau`, which fails the harness, which blocks the next merge gate. Not this
  task's change; named so it is a decision (flip it after a playtest, or move the date with a reason)
  rather than a red harness during Task 85.
- **R. `MIN_PLAYERS` goes to 2 for a live server in this task** (§11.1). Default: **do it.** The place is
  DEV and unpublished, Studio and every playtest keep 1, and the alternative is the ROADMAP item shipping
  by accident. The honest cost: the live branch is exercised by no harness run, only by a pure spec.
- **M1. `docs/design/boar-ai.md` is still out of date on sounders**, and §9.4 here is normative until it is
  regenerated. That regeneration is an Architect run, not a Builder edit. Default: **run it with the next
  boar task.**
- **H/I/J/K/L (carried from v3, all settled and built):** `MAX_ALIVE_BOARS` 4 → 6 outside the flag; the pad
  radius read from the contract (now 30); the 57a/57b split; no collision group for boar jostling; no group
  bonus and no sounder field on the wire.

---

## 15. What I could not verify (rule 8)

- **Anything requiring Roblox Studio.** No Studio in this session (`.agent-evidence/INDEX.md`). Every claim
  about wall clock in §12.12 is arithmetic over `PHASE_TIMEOUT`, `REPORT_WINDOW` and the existing spec's
  behaviour, **not measured**. The two things I would look at first in the harness output are the phase
  table and the `TestKit.note` from §12.12 item 6.
- **That `TestEZ` runs `describe` blocks within a file in declaration order.** I rely on it in §12.12 and I
  did not read TestEZ's planner; `tests/TestKit.luau` loads specs by `GetDescendants` and hands the folder
  to `TestEZ.TestBootstrap:run`, so **file** order is the `zz_` convention rather than a guarantee — which
  is exactly why the new block goes inside an existing file. If declaration order also turns out not to
  hold, the block must assert its own starting state (§12.12 item 1) and skip with a note rather than
  assume — item 1 is written to be that check.
- **The live-server `MIN_PLAYERS = 2` branch.** No published server exists to run it in. Covered by a pure
  spec through the parameter (§12.1 item 20) and by the literal assertions in §12.4 item 15.
- **Abandonment on a real server** (§12.12): reaching `Waiting` in Studio means removing the only player
  from a running session. Pure specs only.
- **The two near-identical yellows** (`SCORE_HIGHLIGHT_COLOR` RGB(255, 232, 150) and `MATCH_WINNER_COLOR`
  RGB(255, 215, 90)) and the 560-wide six-column score row. Both are screen questions, and §12.10 shots 1
  and 2 are where they are answered. This repo has twice shipped a colour that measured right and read
  wrong.
- **Whether 4 drives and 30 seconds feel right.** Nobody but Karen can judge it (§14).
- **The external sources' URLs, licences and maintenance status.** No network this session. A–I are carried
  from v3 and from `docs/design/boar-ai.md` §8; **J, K and L are added here from my own knowledge, and the
  Builder confirms each one in `docs/research/2026-09-25-drive.md` Addendum 3 before relying on it**
  (rule 1; `docs/research/` is the Builder's file, not mine). If a source cannot be confirmed, nothing in
  the design changes: no code is taken from any of them, and the pattern J and K supply is already the
  shape this repo builds in.
- **CI and harness status at this commit.** Lint and build are clean in the evidence; no harness or CI
  output is in `.agent-evidence/`.
- **Every number in §11.8 is a first guess.** None has been played.

---

## 16. External sources

Rule 1 and rule 2: this is where the design borrows, and where it says so. A–I are carried forward (they
are where the drive's and the sounder's decisions came from); **J, K and L are new and are the match's
sources.**

### A. Roblox `Teams`, `Team` and `Player.Team`
<https://create.roblox.com/docs/reference/engine/classes/Teams> ·
<https://create.roblox.com/docs/players/teams> · first-party creator docs (creator-docs is CC BY 4.0) ·
actively maintained.
**Good:** a server-authoritative, automatically replicated team field a client cannot write, with free
player-list colouring.
**Bad:** `Team.AutoAssignable` defaults to `true`, so Roblox becomes a silent second writer of the exact
field this system owns; `Teams` is not Rojo-owned, so the instances are created at run time and are
invisible to the harness's file comparison.
**Adopted:** two `Team`s created by `Match.Body.ensureTeams` with `AutoAssignable = false`; `Player.Team`
as the one representation.

### B. Roblox remote events and `Workspace:GetServerTimeNow`
<https://create.roblox.com/docs/scripting/events/remote-events-and-callbacks> ·
<https://create.roblox.com/docs/reference/engine/classes/Workspace#GetServerTimeNow> · first-party
(CC BY 4.0) · actively maintained.
**Good:** a clock both sides agree on turns a countdown into **one** number pushed once per phase — which
is why `MATCH_RESULT_SECONDS` needs no new machinery at all; `FireAllClients` is the right shape for state
every player sees identically; the page states flatly that client input is untrusted, which is why this
system has no inbound remote.
**Bad:** no rate limiting and no schema validation; a table that is neither a dense array nor a pure
dictionary does not survive the wire; `GetServerTimeNow` is easy to confuse with `os.time`, `tick` and
`os.clock`.
**Adopted:** two outbound remotes, none inbound; a snapshot with a floor, a forced push per phase entry and
a heartbeat; `phaseEndsAt` as a server timestamp; every table dense — `matchRows` and `winners` included.

### C. Roblox `CollectionService` tags
<https://create.roblox.com/docs/reference/engine/classes/CollectionService> · first-party (CC BY 4.0) ·
actively maintained.
**Good:** `GetTagged` answers "give me every post" in one call, which decoupled this system from the map
switch.
**Bad:** a tag is a string with no schema, so a typo yields an empty list and a silently dead rule; tags are
**not** compared by this repo's harness.
**Adopted:** five `DrivenHunt.*` tags whose strings live once in `Map.TAGS`, read into one frozen
`MarkerSet` with a named `missing` list.

### D. Driven-hunt safety practice (Deutscher Jagdverband and equivalent *Drückjagd* guidance)
<https://www.jagdverband.de/> · copyrighted web content; **facts and technique taken, no text and no code** ·
maintained as public guidance.
**Good:** it is the source of the rule Karen is reproducing, and it says what the offence is — you stand on
your assigned post and you do not shoot into the drive. It is also where the vocabulary comes from: a
*Rotte* is a sounder, led by an old sow. **And it is where the shape of a match comes from in the real
sport:** a day's hunt is several drives at several stands, with the bag counted at the end of the day and
not at the end of each drive.
**Bad:** qualitative and regionally variable; metres, not studs; it assumes a hunt leader who can see
everything, which a server cannot; it has no notion of a 10-minute drive or of points.
**Adopted:** the offence, the post discipline, the shape of the sanction — and **the day of several drives
with one total at the end**, which is precisely what §4.5 and §7.5 build. **Not adopted:** the real rule
that the lead sow is not to be shot.

### E. Rodux — named, deliberately **not** adopted
<https://github.com/Roblox/rodux> · Apache-2.0 · Roblox's own Redux port; maintained but quiet.
**Good:** the canonical Roblox answer to "one store, one place state changes".
**Bad:** a Wally package, a `default.project.json` mapping and a Connect click; its `dispatch` lifecycle
would own the transitions that §4 needs to be *pure and returned*.
**Decision:** the pattern is taken, the package is not — `Phase.step` returning a new frozen state plus a
list of effects is a reducer with the side effects made values. **This revision is the pattern's dividend:
the match is three more fields and two more effects, and no new machinery** (`docs/research/2026-09-25-drive.md`
corrects v2's claim that Rodux is archived).

### F. Borrowed from inside this repo (rule 2 applies to internal patterns too)
`src/server/Boar/init.luau` and `docs/design/boar-ai.md` §3–§4: the folder module that owns state and does
nothing on `require`; a pure decision module driven by an injected world and exported for specs; one module
that is the only writer of Instances; every number in one `CONFIG`; `stats()` as the cheap way to assert on
a live system; `step(dt)` split from `run()`.
`src/server/Weapon/init.luau` and `docs/design/shotgun.md` §5.3–§5.4: injected providers; `forget(player)`
as the named lifecycle; deep-frozen published state.
`src/shared/Flags/init.luau` and `docs/design/feature-flags.md` §10: one boundary read, passed inward.
`src/client/Hud/init.luau`, `Hud.renderScore`: **a public renderer as the only way to test a screen the
harness cannot reach** — §9.5's `Hud.renderMatch` is that pattern's second instance, for the same reason
at ten times the timescale.
**Adopted whole.**

### G. Craig Reynolds, *Steering Behaviors For Autonomous Characters* (GDC 1999)
<https://www.red3d.com/cwr/steer/gdc99/> · published paper, freely readable; technique taken, no code ·
frozen (1997/99), still the standard reference.
**Good:** it defines **leader following**, **separation**, **cohesion** and **alignment** and insists
steering is a *weighted, truncated* combination, so one term can dominate; it keeps steering separate from
locomotion, which is the split this Brain already has.
**Bad:** no map knowledge, so pure steering walks a follower into a dead end; nothing about the leader
dying; its arbitration advice is qualitative.
**Adopted:** leader following on top of the leader's navmesh route; the weighted truncated sum; the strict
steering/locomotion split.

### H. Craig Reynolds, *Flocks, Herds, and Schools* (SIGGRAPH '87) — the boids paper
<https://www.red3d.com/cwr/papers/1987/boids.html> · ACM-published paper; technique taken, no code · frozen
(1987), the origin of the three rules.
**Good:** the three rules, and the point this design leans on hardest — **they must be prioritised, with
collision avoidance winning**, or the flock interpenetrates; plus the *neighbourhood* idea, which is why
`NEIGHBOUR_STUDS` exists and the cost stays O(n²) over n ≤ 5.
**Bad:** a leaderless flock with no goal, no obstacles and no ground.
**Adopted:** the three rules as terms, separation weighted to dominate, the neighbourhood radius. **Not
adopted:** leaderless flocking.

### I. OpenSteer — named, **not adopted**
<https://opensteer.sourceforge.net/> · MIT licence · **unmaintained** (last release mid-2000s).
**Good:** the canonical implementation of exactly this decomposition, which settles how the terms compose in
practice.
**Bad:** C++ with an OpenGL demo harness, no Luau port, unmaintained for over a decade.
**Decision:** **pattern confirmed, code not taken** — the same call `docs/design/boar-ai.md` §8 made about
SimplePath.

### J. Roblox creator docs — round-based games, `Players.PlayerAdded`/`PlayerRemoving`, `Players.RespawnTime`
<https://create.roblox.com/docs/reference/engine/classes/Players> ·
<https://create.roblox.com/docs/tutorials> (the round-based / game-loop tutorial track) · first-party
creator docs (creator-docs is CC BY 4.0) · actively maintained. **The Builder confirms the tutorial's exact
URL and title in Addendum 3 before citing it** (§15).
**Good:** it is the platform's own answer to "how does a Roblox game run rounds", and it is explicit about
the two things that actually bite: a player who **joins mid-round** has no team and no score row yet, and a
player who **leaves** must be cleaned out of every table keyed by them (`PlayerRemoving`, and
`Players.RespawnTime` as the reason a respawn is not instantaneous — which is what `PLACE_TIMEOUT = 5` is
sized against).
**Bad:** the canonical tutorial shape is `while true do … task.wait(roundLength) end` with module-level
state and no effect list. A hitch or a yield inside that loop skips a phase, nothing can assert on it
without a real server and a real clock, and there is no answer at all to "what happens to the score when
the round loop is interrupted" — which is exactly the abandonment case in §4.5. It also says nothing about
accumulating across rounds or about a result screen.
**Adopted:** the mid-join and leave rules (§4.4, and `Score.drop` for the leave), and the platform
vocabulary. **Rejected, with the reason recorded:** the `while true do task.wait()` round loop. Every
transition here is time-driven from `phaseEndsAt` and returned as an effect, which is what lets
`match_phase.spec` run a whole 43-minute match in under 200 ms.

### K. Valve Developer Community — Counter-Strike match structure (`mp_maxrounds`, `mp_halftime`, `mp_match_end_restart`)
<https://developer.valvesoftware.com/wiki/Counter-Strike:_Global_Offensive> (and the console-variable pages
it links) · community wiki, content under the licence stated on the site (CC BY-SA family; **the Builder
confirms the exact licence in Addendum 3**) · actively maintained by the community.
**Good:** it is the most documented, most played instance of exactly the structure this brief asks for, and
it settles four questions without inventing anything: **a fixed number of rounds makes a match**
(`mp_maxrounds`), **sides swap partway so nobody plays one role all match** (`mp_halftime` — which is why
`DRIVES_PER_MATCH` being even is an invariant here rather than a preference), **a match ends with a result
period before anything restarts** (`mp_match_end_restart`), and **the score resets at the restart, wholly
and visibly**. It also names the failure mode this design must avoid: a server that cannot end a match sits
in a state no player can score in and no operator can read.
**Bad:** it is a competitive 5v5 model with fixed teams, no mid-match joiners at parity, and a warmup,
overtime, timeout and surrender machinery that is an order of magnitude beyond v1; its round lengths are
~2 minutes against this game's 10; and its documentation is a variable reference, not a design rationale —
it says *what* the knobs do, never *why* that shape is right.
**Adopted:** the structure — N rounds, a side swap, a result period, a full reset — as
`DRIVES_PER_MATCH` + `SWAP_TEAMS_EACH_DRIVE` + `MatchOver` + `clearMatchTotals`. **Not adopted:** fixed
teams, warmup, overtime, and any notion of a round win; a drive is scored by animals, not by winning it.

### L. Pete Hodgson, *Feature Toggles (aka Feature Flags)* — martinfowler.com
<https://martinfowler.com/articles/feature-toggles.html> · published article, freely readable; **technique
taken, no code** · maintained (the site's canonical reference on the subject, and already this repo's
source: `src/shared/Flags/init.luau` header, `docs/research/2026-09-26-feature-flags.md`).
**Good:** it separates a **release toggle** from the other kinds and is blunt that a toggle's cost is the
branch it leaves behind, so the smallest possible toggle with the shortest possible life is the right one.
That is the argument for `SHORT_MATCH` being **four durations and nothing else** with a 21-day `expires`,
and the argument against flagging the match itself (§14 item N): a toggle whose off-state is "the game has
no ending" is not a release toggle, it is two games.
**Bad:** it is about deployment pipelines, not about Roblox: nothing in it addresses a flag that must be
readable by a client, a Studio-only override, or a place file that carries attributes into production —
which is why `docs/design/feature-flags.md` exists at all and why `tools/flags.py clear` is in the
publish-strip list (`TASKS.md` row 2).
**Adopted:** the release-toggle lifecycle (one read at the boundary, a dated expiry that fails the build, a
retirement that deletes the losing branch) for `SHORT_MATCH`, and its cost argument as the reason the match
itself is not flagged.

### The pattern adopted overall

A pure reducer returning state plus an explicit effect list (E's shape without E's package) inside a
folder-module owner with an injected world (F); Roblox's own `Team` as the single representation of team
membership (A); tag-based world markers (C); two outbound remotes with a server timestamp and nothing
inbound (B); a safety rule whose *geometry* is the weapon's and whose *verdict and punishment* are the
drive's (D); a sounder as one navmesh route for a leader plus Reynolds leader-following with boids
separation, cohesion and alignment (G, H, I); and, new in this revision, **a match as a fixed number of
drives with a side swap, one accumulating board folded once per drive, a result phase, and a full reset —
the Counter-Strike structure (K) expressed as three fields and two effects in the reducer that already
exists (E), with the platform's own mid-join and leave rules (J) and one small, dated toggle to make it
playable by hand (L).**

Nothing here is invented except `Penalty.judge`'s point-to-ray test, the wedge offsets in §11.7, and
**`Score.accumulate`/`winners`, which are addition and a maximum** — with twelve assertions against them
(§12.3), because the one thing worse than no scoreboard is a scoreboard that is quietly wrong.
