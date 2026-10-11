# The real drive in the forest: one game mode, two worlds

2026-10-11, for Task 157. Written before any code (rule 1).

**KAREN, 2026-10-11, approving the next two pieces of the drive:**

> *"start of a drive ... good / end of a drive ... yes"*

and the Director's reading of it, which is this task:

> The real game — DEV's `Match`: teams Shooters/Drivers, the drive phases, the stands, the tie, the
> score, the report — runs in DEV's world. The Forest Test place is where Karen actually plays. A
> 10-second stand timer at the start of a drive and a results scene at the end belong to the REAL
> drive, so she must be able to play the real drive **in the forest**.

---

## 1. What the system must do

| Must | Why |
|---|---|
| The drive in the Forest Test place is the **real `Match`**: phases, teams, the drive clock, the tie and the penalty, the score, the report | Karen's next two tasks are drive-start and drive-end. Building them twice — once in `Match`, once in `ForestTest` — is the "two correct pieces of code disagreeing" failure `docs/PROJECT_CONTEXT.md` names |
| It uses the **FOREST's geometry**: the nine stands on the curved road, the beater start behind the animals, the road as the drive line, the forest's trunks for the tie | The map's numbers (`Map.FIELD`, `Map.ROAD`, the tagged posts at z = −700) describe a world that does not exist in that place |
| The **animals stay the forest's**: the resting wood, the one-way flush, the lines, the horn (tasks 150, 153, 154) | Karen has accepted that behaviour by playing it. `Match`'s own release schedule is a second writer of "when an animal exists" |
| **One player alone can play it**: a solo player is a hunter, armed; `DHForestStartRole` still flips her to a beater; the phantom beaters still push | She tests solo. `MIN_PLAYERS = 1` and `ODD_PLAYER_TEAM = "Shooters"` already say a solo player is a shooter |
| **DEV's world and the gate do not change behaviour** | The harness runs in DEV. A change that moves the DEV drive invalidates every spec that passes today |
| The horn, the outfit, the map (tasks 151, 152, 155) keep working in the forest | Each is wired in `ForestTestBoot` today |

### 1.1 Must not

- **Two owners of the animals.** Either `Match` releases them or `ForestTest` does — not both.
- **Two owners of teams.** `Match.Body` is the only writer of `Player.Team`, in both worlds, today.
- **A flag-switched world.** Task 79 measured what that costs: the same commit went from 32/32 checks
  to 22/27 with eleven specs failing, because the world lives in the PLACE and a flag is one value
  for every place. The place id stays the switch (`Map.WORLD_BY_PLACE`).
- **A predicate that sniffs Workspace** to decide which world this is. `Map`'s own comment: *"a
  predicate like that lies the moment a run half-finishes."*
- **A silent wrong answer.** No placement at the origin, no empty roster that reads as a drive, no
  marker set that is `complete` because nothing checked it.

---

## 2. What exists today — read out of the code, by symbol

Every claim here is a file and a symbol, not a line number.

1. **The place decides the world, already.** `Map.WORLD_BY_PLACE` maps the DEV id to `"map:v1"` and
   the Forest Test id to `"forest-test"`; `Map.EXPECTED_WORLD` resolves it once.
   `MatchBoot.server.luau` returns early when the world is `"forest-test"`, and
   `ForestTestBoot.server.luau` returns early when it is not. Two composition roots, one per world,
   neither requiring the other.
2. **`Match` already takes an injected world.** `Match.start(injected)` reads `world.boars`,
   `world.weapon`, `world.now`, `world.serverTime`, `world.players`, `world.remotes`,
   `world.heartbeat`, `world.collection` **and `world.markers`** — and `readMarkers()` is literally
   `markerSet = if world.markers then world.markers else Markers.read(world.collection)`. The seam
   for "this world's geometry" exists and is used by the specs.
3. **But the geometry it consumes is `BasePart`s, not positions.** `Body.placementFor` reads
   `post.Position` and `post.Size.Y` for a shooter and `start.Size.X` / `start.Position` for a
   driver; `Body.anchorFor` scans `markers.trees` and falls back to `markers.posts`;
   `Body.tiePointFor` reads the trunk's `Size`. So a world that wants to supply geometry must either
   build parts or supply the placement itself.
4. **`Match.CONFIG` is one frozen module table.** `Drive.deepFreeze(Match.CONFIG)` runs at require
   time, and the owner reads `Match.CONFIG` directly in `applyPlace`, `onSafetyViolation`,
   `samplePush`, `Match:step` and the rest. Every PURE module (`Phase`, `Roster`, `Score`,
   `Penalty`) already takes `config` as a parameter — so the pure half is per-world ready and the
   owner is not.
5. **The release schedule can be switched off with data, with no new branch.**
   `Phase.maybeRelease`'s first predicate is `state.boarsReleased >= config.BOARS_PER_DRIVE`, which
   at `BOARS_PER_DRIVE = 0` is true on every step: no effect, no hold-back, no warning.
6. **`clearBoars` is already conditional on the runtime offering `clear`.** `applyClearBoars` calls
   `world.boars:clear("driveOver")` only `if world and world.boars and world.boars.clear`, and
   `applySpawnSounder` returns early with no `world.boars` at all.
7. **The forest's geometry is data, and it is the one definition.** `ForestTest.roadZ(x)` (*"the one
   definition; every other reader calls this"*), `standX`/`standPosition`/`STAND_COUNT` (9, 150
   studs apart), `beaterStart`/`beaterStartPosition` (which measures ground and trunk clearance),
   `driverStart(index, count)`, `EXIT_Z`, `groundAt` (a raycast, because *"the ground is y 140 at the
   road, 149 at 200 studs north and 196 at 400"*).
8. **The forest world owns its animals.** `ForestTest.start(runtime, now)`, `release`,
   `releaseLine`, `stepLines`, `stockWood`, `stepRest`, `spookNearBeaters` all spawn and push; the
   boot's Heartbeat drives them. `ForestTestBoot` turns `MODEL`, `CALM`, `PACE`, `MOVE`, `LINE` and
   `KINDS` on per world through `Boar.newRuntime(world)`'s `config` merge, and replaces
   `world.threats` with `ForestTest.boarThreats` at the composition root.
9. **The forest has no `DrivenHunt.*` tags.** `ForestTestBoot`'s own header: *"There is no drive
   there, no roster and no tagged markers — `Match.Markers.read` would find none."* This is the
   OPPOSITE of the Task 79 hazard, where both worlds tagged with the same strings.
10. **The safety arc only publishes; it never refuses a shot.** `Weapon`'s fire path calls
    `SafetyArc.isForbidden(aim, line, …)` and, when true, fires `SafetyViolated`; `Penalty.judge`
    then needs a REAL driver within `SAFETY_MISS_STUDS` of the shot's own path. So giving the forest
    a drive line cannot cost Karen a shot while she is alone — it only decides which shots are
    judged at all. `ForestTestBoot` registers `noDriveLine` today, and the comment explaining it
    (*"there are no drivers in this world"*) stops being true the moment the real drive runs there.
11. **The client needs nothing new.** `MatchBoot.client.luau` starts `PlayerScripts.Match` in every
    world and `Hud` reads the replica; today the forest simply never receives a snapshot. The Hud's
    only per-world branch is the compass/map geometry (`Map.EXPECTED_WORLD == "forest-test"`).
12. **`Match.quickTestPhantom` is the precedent for a phantom pusher inside `Match`** — a
    `{ id, position, kind = "driver", phantom = true }` stimulus with a non-numeric id, which
    `Match.playerDrivers` filters out of the safety rule and push credit. `ForestTest.boarThreats`
    does the same thing for its waves. Two implementations of one idea already, in two worlds.

---

## 3. External sources

### 3.1 Unreal Engine — `AGameModeBase::FindPlayerStart` and the `PlayerStart` actor

- [AGameModeBase::FindPlayerStart (UE 5.1 API)](https://docs.unrealengine.com/5.1/en-US/API/Runtime/Engine/GameFramework/AGameModeBase/FindPlayerStart/),
  [Player Start Actor in Unreal Engine](https://dev.epicgames.com/documentation/unreal-engine/player-start-actor-in-unreal-engine?lang=en-US)
- Licence: Epic's documentation, free to read, not open-licensed. **Maintained** (current 5.x docs).
- **What it does well.** The game mode asks the LEVEL where to put a player:
  `FindPlayerStart(controller, incomingName)` finds a `PlayerStart` *by tag*, and
  `ChoosePlayerStart` is the hook a project overrides to choose differently. One mode, many levels,
  and the mode's own code carries no per-level branch — which is exactly "one `Match`, two worlds".
  The *tag* on a start actor is the same idea as our `markers.posts` index: a stable name for "the
  same spot every time".
- **What it does badly, for us.** It is an engine class hierarchy, not a seam we can borrow
  wholesale, and a level with no `PlayerStart` spawns the player at the world origin — a silent
  wrong answer of precisely the kind `Body.anchorFor` already refuses to produce (it returns `nil`
  rather than a `CFrame` at 0,0,0). Also: the override lives in a *subclass* of the mode, so two
  worlds mean two classes; we want one owner and injected data.

### 3.2 Valve Developer Community — Counter-Strike map entities as the mode's contract

- [info_player_(counter)terrorist](https://developer.valvesoftware.com/wiki/De/Info_player_counterterrorist),
  [info_map_parameters](https://developer.valvesoftware.com/wiki/Info_map_parameters/Counter-Strike_series)
- Licence: **CC BY-NC-SA 3.0**. Community wiki, **actively edited**.
- **What it does well.** The map's *entities* are the mode's geometry, and the contract is explicit
  and countable: the number of `info_player_terrorist` entities **caps the team size** (five spawn
  entities means at most five players on that team; official maps carry 16–32), and the wiki states
  placement constraints as numbers — a spawn origin at least 16 units above ground, more than 32
  units from another spawn, more than 16 units from a wall, never inside a solid. That is the same
  shape as our nine stands at 150 studs: the WORLD states capacity and spacing, and the mode obeys
  them.
- **What it does badly.** Entity classnames are strings with no schema, so a typo is a map that
  loads and a mode that does nothing — which is why `Markers.read` returns `complete`/`missing` and
  the match refuses to leave `Waiting`. And those placement numbers are advice to a mapper, checked
  by nothing at load time; ours have to be checked by a spec.

### 3.3 Unity — level layout as an injected data object (`ScriptableObject`)

- [Separate game data and logic with ScriptableObjects](https://unity.com/how-to/separate-game-data-logic-scriptable-objects),
  [6 ways ScriptableObjects can benefit your team and your code](https://unity.com/blog/engine-platform/6-ways-scriptableobjects-can-benefit-your-team-and-your-code),
  and the e-book *Create modular game architecture in Unity with ScriptableObjects*
- Licence: Unity's documentation, free to read, not open-licensed. **Maintained** (current Unity 6
  learning material).
- **What it does well.** It is the data-as-asset answer to the same question, and its own worked
  example is ours: a `LevelLayoutSO` is *"a data container for the starting positions of game
  elements"*, swapped per level, with the systems reading it rather than holding the numbers. That
  is `src/shared/ForestTest/init.luau` (one world's geometry, as data, in `ReplicatedStorage`) and
  `src/shared/Map/init.luau` (the other's, frozen, with no runtime writer) — already built, already
  the pattern.
- **What it does badly.** A `ScriptableObject` is mutable at run time and edits leak back into the
  asset in the editor; our equivalent risk is a second writer of a world table, which
  `Drive.deepFreeze`/`Shotgun.deepFreeze` already removes. And Unity's version says nothing about
  *who* chooses which layout: that choice is the part this task has to get right.

### 3.4 Named and rejected — Knit (a Roblox DI/service framework)

- [Sleitnick/Knit](https://github.com/Sleitnick/Knit), [ARCHIVAL.md](https://github.com/Sleitnick/Knit/blob/main/ARCHIVAL.md)
- Licence: MIT. **Archived by its author on 2024-07-31** — and the stated reason is not
  maintainability but Luau: Knit's design *"cannot fully benefit from types and thus does not have
  good intellisense"*.
- In another engine the answer to "resolve a different geometry provider per place" would be a DI
  container. It is rejected on two counts: the package is archived and type-hostile, and this repo
  already has the thing a container would give us — an explicit composition root per world, one
  `require` and one call, which `ForestTestBoot` and `MatchBoot` both are.

### 3.5 Borrowed from ourselves (rule 2)

`Boar.newRuntime(world)` takes a world with `groundAt`, `threats` and a `config` that is **merged
over the module's defaults**, and `ForestTestBoot` already uses it to turn six behaviour blocks on
in one place without touching the boar's own file. `Weapon.setArmingPolicy` /
`setDriveLineProvider` / `setCast` are the same idea as function injection. A per-world
`Match.start({ config = …, markers = …, placement = … })` is the **third instance** of a pattern
this repo has twice, not a new foundation — which is what rule 2 asks for.

---

## 4. The pattern adopted

**The world provides; the owner decides.** `Match` keeps every decision it has today — the phase
machine, who is on which team, where the points go, who is tied — and everything it READS about a
world arrives at the composition root:

1. **the marker set** (`world.markers`), already a seam;
2. **per-world config overrides** (`world.config`), merged over `Match.CONFIG` the way
   `Boar.newRuntime` merges its own — so the forest can say `BOARS_PER_DRIVE = 0` (its animals are
   its own) and set its own drive length, while DEV with no overrides is bit-for-bit the drive the
   suite passes on today;
3. **the placement** of a player of a team (defaulting to `Body.placementFor`), because the forest's
   ground is a hill and its road is a sine curve, and `Body` must stay the one *writer* even when
   the *choice* of spot is the world's.

**The animals stay with one owner per world** — `ForestTest` in the forest, `Match` in DEV — and the
drive's **phase** is the signal the forest's own schedule listens to, rather than a second thing
that decides when a drive starts.

Which of those three the design actually adopts, and where each lives, is the Architect's call
(`reviews/task-157/BRIEF.md` §2). What this note settles is that the first two have precedent in
this repo and in all three external sources, and that the alternative — a second drive implementation
inside `ForestTest` — is the failure mode `PROJECT_CONTEXT.md` was written about.

---

## 5. Numeric targets

| Target | Value | Checkable by |
|---|---|---|
| Hunter stands in the forest | **9**, 150 studs apart, on the road curve (`ForestTest.STAND_COUNT`, `STAND_SPACING`) | server spec: the marker set has 9 posts, each within 1 stud of `standPosition(i)` in x and z |
| A post's ground | within **1 stud** of `ForestTest.groundAt(x, z)` at that x, z | server spec (live, in the forest world only) / console line |
| Beater start | `LINE.spawnNorthStuds + BEATER.behindLineStuds` = **240 studs** north of the road, trunk-clear by `BEATER.clearStuds` (6) | reuses `ForestTest.beaterStartPosition`, already measured |
| Solo player | **hunter**, armed, from the first drive (`MIN_PLAYERS` 1, `ODD_PLAYER_TEAM` Shooters) | server spec + the smoke run |
| Forest drive length | **300 s** start value (the forest's own `DRIVE.seconds`), intermission 20 s, scoring 25 s | config assertion; Karen's to change |
| Animals released by `Match` in the forest | **0** (`BOARS_PER_DRIVE = 0`) | server spec: a forest-configured `Phase` emits no `spawnSounder` over a whole simulated drive |
| DEV drive, unchanged | every `Match.CONFIG` value identical with no overrides; the DEV gate still **33/33** | `tests/server/match_*.spec.luau` as they stand, plus one new assertion that the default config is untouched |
| Tie anchor | a trunk within **60 studs** of the stand, else the post (existing `Body.anchorFor` fallback) | server spec, pure, with hand-written parts |
| Gate | one-player `test` PASS **twice**; `test2` **required** (this touches `src/server/Match/`, `src/server/MatchBoot.server.luau` — `TWO_PLAYER_PATHS`) | `tools/agents.py` |

---

## 6. What this note does not settle

- **Where the start-of-drive stand timer and the end-of-drive results scene live.** They are Karen's
  next two tasks; this one only has to make them possible in the place she plays.
- **Whether the forest's wave schedule should be reset by a drive boundary** (today
  `ForestTest.DRIVE` moves nothing but the report's window). The design decides; the safe default is
  that it keeps moving nothing, because Karen has accepted the current rhythm.
- **Team rotation in the forest** (hunter one drive, beater the next). `SWAP_TEAMS_EACH_DRIVE` is
  already true in `Match.CONFIG`, so a second drive in the forest would swap a solo player's role —
  which is either exactly what Karen asked for on 2026-10-11 (*"you start as a hunter then next
  round you are beater"*) or a surprise mid-session. Named here as a decision, not taken.
