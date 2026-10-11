# Design: forest-drive — the real `Match` in the Forest Test place

Task 157. Architect. Input: `reviews/task-157/BRIEF.md` (which overrides anything older) and
`docs/research/2026-10-11-forest-drive.md`. Deltas to `docs/design/drive.md`,
`docs/design/map-generator.md` §17 and `docs/design/beater-kit.md` §9 are in §15.

This document designs **one system**: the seam by which the existing drive owner
(`ServerScriptService.Match`) runs in the place "Driven Hunt Forest Test" on that world's geometry.
It designs no new drive, no new phase and no new client code.

---

## 1. What it must do, and what it must not do

### 1.1 Must do

| Must | Why |
|---|---|
| The drive in the Forest Test place is the **real `Match`**: the four phases, the two teams, the drive clock, the roster and its rotation, the tie, the penalty, the score, the report window | Brief decision 2. Karen's next two tasks (the stand timer, the results scene) are drive pieces; building them twice is the "two correct pieces of code disagreeing" failure `docs/PROJECT_CONTEXT.md` names |
| It uses the **forest's** geometry: the nine stands on the curved road, the beater start 240 studs behind the animals, the road as the drive line | Brief decision 3. `Map.FIELD`, `Map.ROAD` and the posts at z = −700 describe a world that does not exist in that place |
| The **animals stay `ForestTest`'s**. `Match` releases none and clears none | Brief decision 5. One owner of "when an animal exists", per world |
| A **solo player can play it**: hunter, armed, drive 1; beater on drive 2 | Brief decisions 7 and 1 (Karen, 2026-10-11: *"you start as a hunter then next round you are beater"*) |
| **DEV's behaviour does not change, provably** | Brief decision 8. The harness runs in DEV. §4.2 gives the identity assertion |
| The horn, the outfit, the map, the compass and the report keep working in the forest | Brief decision 10. §8 says what moves and what does not |
| Exactly **one** decider of which role a player is | Brief §2.2. §5 |

### 1.2 Must not

1. **Must not release or clear a boar in the forest.** `Match` gets a read-only view of the runtime
   (§4.1), so `applyClearBoars`'s existing `if world.boars.clear` is false and `applySpawnSounder`'s
   existing early return holds. No new branch in `Phase`.
2. **Must not have two deciders of a role.** Today `ForestTestBoot.applyRole` → `Body.setTeam` and
   `Match`'s roster → `Body.setTeam` would both write `Player.Team`, and — worse — `Player.Team`
   would then disagree with `state.assignment`, which is the table `Match.mayCarryWeapon`,
   `Match.boarThreats`, `Match.driverThreats` and `samplePush` actually read.
3. **Must not tag anything `DrivenHunt.*` in the forest.** The forest has no such tags
   (`src/server/ForestTestBoot.server.luau` header: *"no tagged markers — `Match.Markers.read` would
   find none"*). Keeping it that way means the two worlds can never both answer one `GetTagged` —
   the inverse of the Task 79 hazard.
4. **Must not use a feature flag for the world.** The place id is the switch (§14).
5. **Must not reset the forest's wave or rest schedule from a drive boundary** (§7.2).
6. **Must not change any `Match.CONFIG` value, any effect order, or any DEV-reachable default**
   (§4.2's allow-list and identity rule).
7. **Must not add a client file or a client spec** (§6.4, §13.4).
8. **Must not produce a silent wrong answer**: no placement at the origin, no marker set that is
   `complete` because nothing checked it (§4.1.3).

---

## 2. The pattern adopted

**"The world provides; the owner decides"** — the research note's §4, restated as the brief's decision
6 and not re-opened here. `Match` keeps every decision it has today. Everything it *reads* about a
world arrives at the composition root, as **three injected fields and nothing else**:

| Injected | Type | Default when absent | Who supplies it in the forest |
|---|---|---|---|
| `world.markers` | `MarkerSet` **or `() -> MarkerSet`** | `Markers.read(world.collection)` | `ForestTest.Markers.build` |
| `world.config` | `{ [string]: number \| boolean }` over an allow-list | `Match.CONFIG` itself, by identity | `ForestTestBoot`, two keys |
| `world.placement` | `(markers, team, index, config) -> CFrame?` | `Body.placementFor` | `ForestTestBoot`, a closure over `ForestTest` |

This is the **third** instance of an owner with an injected world in this repo, not a new foundation:
`Boar.newRuntime(world)` (with its `config` merge) and
`Weapon.setArmingPolicy`/`setDriveLineProvider`/`setCast` are the first two. A DI container is
rejected — Knit is archived and type-hostile (§11.4), and this repo already has what a container
would give it: one explicit composition root per world.

Borrowed, and said so (rule 2): the external shape is Unreal's `FindPlayerStart`/`ChoosePlayerStart`
and Valve's map entities as the mode's contract; the spawn *selection* rule (`standIndexFor`, §4.3)
is Quake III's `SelectSpawnPoint` family. Sources, licences and what each gets wrong: §11.

---

## 3. Ownership — one writer each, named

| System | Owner (the only writer) | Location |
|---|---|---|
| The drive: phase, teams, per-drive score, penalty state, the two remotes, `Workspace.DriveMarkers` | **`ServerScriptService.Match`** — unchanged | `src/server/Match/init.luau` |
| `Player.Team`, where a character stands, what it wears, the tie | **`Match.Body`** — unchanged, and still the only writer | `src/server/Match/Body.luau` |
| **The forest's marker parts** (`Workspace.ForestMarkers` and every part in it) | **`ServerScriptService.ForestTest.Markers`** — NEW, and the only writer of that folder | `src/server/ForestTest/Markers.luau` |
| **The forest's role REQUEST** (a one-shot, per `userId`) | **`ServerScriptService.ForestTest`** — `state.requests`, beside `state.picks` | `src/server/ForestTest/init.luau` |
| The forest's animals: when a wave exists, when the wood is stocked, the leash, the stand pick | **`ServerScriptService.ForestTest`** — unchanged | `src/server/ForestTest/init.luau` |
| Which world this is | **nobody at run time**: `Map.WORLD_BY_PLACE` → `Map.EXPECTED_WORLD`, frozen data | `src/shared/Map/init.luau` |
| The wiring of all of it in the forest | **`src/server/ForestTestBoot.server.luau`** — boot line only; owns nothing, decides nothing, holds no state | — |

**The two composition roots stay two, one per world.** `MatchBoot` gains nothing and loses nothing.
`ForestTestBoot` shrinks (§8).

**`ServerScriptService.ForestTest` still does not require `Match`** (the property
`docs/design/beater-kit.md` §9 states). The placement closure that needs both lives in
`ForestTestBoot`, which already requires both.

---

## 4. The three seams

### 4.1 The marker set

#### 4.1.1 The decision: the forest builds invisible marker PARTS, and tags nothing

`markers.posts` and `markers.driverStart` are consumed as `BasePart`s, not positions —
`Body.placementFor` reads `post.Position` and `post.Size.Y` for a shooter and `start.Size.X` /
`start.Position` for a driver; `Body.anchorFor` and `Body.tiePointFor` read a part's `Position` and
`Size`. Changing `Markers.MarkerSet` to a position-based shape would touch `Markers`, `Body` (the one
writer of placement) and DEV's own path. Nine parts cost nine instances and change no interface.

This is Valve's pattern (the map's entities are the mode's geometry) and Unreal's (`PlayerStart`
actors the mode queries), with their worst property removed: a missing entity here is a named
`missing` string, not a spawn at the world origin (§11.1).

The parts are **not tagged**. The set is handed over through `world.markers`, so `Markers.read` is
never called in this world and `GetTagged("DrivenHunt.*")` still answers zero there.

#### 4.1.2 `ForestTest.Markers` — the new module

```luau
-- src/server/ForestTest/Markers.luau, exported as ForestTest.Markers (the shape ForestTest.Line has)
Markers.FOLDER_NAME = "ForestMarkers"
Markers.POST_SIZE = Vector3.new(6, 1, 6)          -- the generated map's post, so STAND_HEIGHT_STUDS
                                                   -- means the same thing in both worlds
Markers.START_SIZE = Vector3.new(60, 1, 20)        -- the beater pad; see 4.1.5
Markers.GROUND_TOLERANCE_STUDS = 1

-- PURE except for the two readers it is GIVEN. `ground` and `solid` default to
-- ForestTest.terrainYAt and ForestTest.nearestSolid, so a spec drives the whole rule with
-- hand-written numbers (the "reachable by parameter" rule applied to a raycast).
function Markers.build(
    standX: number,                                -- ForestTest.hunterStandX()
    ground: ((number, number) -> number?)?,        -- terrain only; cannot hit a canopy
    canopy: ((number, number) -> number?)?         -- ForestTest.Data.groundAt, for the cross-check
): Markers.Set                                     -- = Match.Markers.MarkerSet, field for field

function Markers.clear()                           -- destroys the folder; the only destroyer
function Markers.stats(): { posts: number, refused: number, reads: number, lastMaxDelta: number }
```

`build` destroys and rebuilds the folder every call (the `Body.OUTFIT_NAME` discipline), so the folder
holds exactly `#posts + 1` parts at all times and never twenty.

Part properties, and the one that is not tidiness:

| Property | Value | Why |
|---|---|---|
| `Anchored` | `true` | a marker that falls is not a marker |
| `CanQuery` | **`false`** | **load-bearing.** A post that stops a pellet changes what the shot hit, and what the shot hit is what `Penalty.judge` reads through the weapon's report. The same reason `Body.dress` and `Body`'s rope set it |
| `CanCollide` | `false` | the hunter stands on the road, not on a slab |
| `CanTouch`, `CastShadow` | `false` | a reference point fires no Touched and casts no shadow |
| `Transparency` | `1` | invisible |
| `Name` | `Stand1`…`Stand9`, `BeaterStart` | so a console line and a Studio Explorer read the same |

**Why a run-time part in `Workspace` cannot dirty the harness.** The harness compares the **Edit-mode**
DataModel against disk and fails on a *script* outside a Rojo-owned path; `Workspace` is not
Rojo-owned, these are Parts, and they are created during Play. The precedents are in the repo and say
so: `Workspace.DriveMarkers` (`src/server/Match/Body.luau` header: *"Workspace is not Rojo-owned and
the harness compares the Edit-mode DataModel, so a run-time folder cannot dirty a run, exactly as
Workspace.WeaponEffects does not"*) and `Workspace.Boars`. Stronger here: this code cannot execute in
DEV at all — `ForestTestBoot` returns early unless `Map.EXPECTED_WORLD == "forest-test"` — so the DEV
place never sees the folder.

#### 4.1.3 Field by field, and what reads each

| Field | What the forest puts there | Who reads it |
|---|---|---|
| `posts` | 9 anchored invisible parts at `ForestTest.standPosition(i)`, y from `ground(x, z)`, sorted by X ascending so post *n* is stand *n* | `Body.placementFor` (shooters, through `standIndexFor`); `Body.anchorFor` (the tie, §6.3); `Match.quickSpawnFor` (`posts[1]`, Studio-only and off) |
| `line` | ONE `{ position = (CENTRE.X, postY, CENTRE.Z), normal = Vector3.zAxis }`, **built as a table, not as a part** — nothing in the forest needs a line part | `Weapon`'s `driveLineProvider` → `SafetyArc.isForbidden` (the **normal only**, §6.1); `Match.quickSpawnFor` (off) |
| `lineParts` | `1` | `Markers.read`'s "exactly one" contract, honoured by construction; the Hud's `missing` text |
| `driverStart` | ONE part at `ForestTest.beaterStart(standX, 0)`, y from `ground`, `Size = START_SIZE` | **nothing in production** — the forest's `world.placement` answers for a beater (§4.3). It exists so no path can produce a nil `CFrame`, and so `complete` can be true honestly |
| `boarSpawns` | **`{}`** — empty, deliberately (§4.1.4) | `Phase`'s `maybeRelease`, which is unreachable at `BOARS_PER_DRIVE = 0` |
| `spawnRadius` | `ForestTest.Data.REST.spreadStuds` (90) | `applySpawnSounder`, unreachable |
| `trees` | **`{}`** — the forest tags no trunks (§6.3) | `Body.anchorFor`, which falls back to `posts` |
| `complete` | `#posts >= 1 and lineParts == 1 and driverStart ~= nil` | `Phase.step`'s `markers` event; the drive stays in `Waiting` while false |
| `missing` | the blocking reasons, as short strings: `"forest:stands (0 of 9)"`, `"forest:line"`, `"forest:beater-start"` | `Phase.waitingFor` → `MatchSnapshot.waitingFor` → the Hud's drive bar (`src/client/Hud/init.luau`, `renderDrive`: `"WAITING " .. table.concat(snapshot.waitingFor, ",")`). **No client change** |

#### 4.1.4 Two deliberate deviations from `Markers.read`'s own rule, each with its reason

1. **`boarSpawns` is empty and the set is still `complete`.** `Markers.read` calls an empty
   `boarSpawn` list missing. In the forest `Match` releases nothing (brief decision 5), so requiring
   a spawn marker would make the drive refuse to start over a thing it must never use. Asserted, so
   it is a decision and not an oversight.
2. **`trees` is empty and the set is still `complete`.** Same in DEV: `Markers.read` does not require
   trees either. `Body.anchorFor`'s post fallback is the designed answer (§6.3).

#### 4.1.5 What makes `complete` FALSE in the forest, and why that is reachable

A post is **refused** when either reading of the ground is missing, or when the two disagree:

```
y := ground(x, z)                            -- terrain only (ForestTest.terrainYAt)
c := canopy(x, z)                            -- ForestTest.Data.groundAt
refuse if y == nil or c == nil or math.abs(y - c) > GROUND_TOLERANCE_STUDS   -- 1 stud
```

`Data.groundAt` excludes `OurForest`, `Foliage` and `Boars` but **not** the two `Session` folders of
831 more trees (measured in task 153, quoted in `ForestTest.terrainYAt`'s header), so it can stop on a
canopy. Over the cut road lane it must not; a disagreement over the lane is evidence that this is not
the place we think it is, not a number to average.

`complete` is therefore false when **all nine** posts are refused, or the beater start is, or the line
has no y. The refusal of *some* posts is a counter (`Markers.stats().refused`) and a console line, not
a `missing` string — one branch over the lane must not stop a playtest.

**It is reachable, and in DEV it is the normal answer.** There is no terrain under x ≈ 3030,
z ≈ −2097 in the DEV place — `tests/server/forest_stand.spec.luau`'s own header already relies on
exactly that (*"in the DEV place, where there is no terrain under this world's coordinates, what that
case proves is the FALLBACK"*). So the harness, which runs in DEV, can prove this set says **no**
(§13.1). That is the guard against the audit that *"certified a blank screen twice"*.

**What the player sees while it is false:** the drive bar reads `WAITING forest:stands (0 of 9)`, and
nobody is armed (`Match.mayCarryWeapon` returns false in `Waiting`). `Match:step` re-reads the markers
once a second while `Waiting` (`sinceMarkers`), so a transient nil resolves itself on the next second
with no restart.

#### 4.1.6 One change inside `Match`: `world.markers` may be a function

```luau
-- src/server/Match/init.luau, readMarkers()
markerSet = if type(world.markers) == "function" then world.markers()
            elseif world.markers then world.markers
            else Markers.read(world.collection)
```

Every existing spec passes a table and is bit-identical. The forest passes a function, so the set is
re-measured on the same two occasions a tagged world is re-read: once a second while `Waiting`, and
once on entering `Assigning` (`markersStale`). **Budget:** ≤ 20 raycasts per read (two per post, two
for the start), ≤ 1 read/s while `Waiting`, 1 per drive otherwise.

### 4.2 The per-world config

`Match.CONFIG` is one module table, deep-frozen at require time (`Drive.deepFreeze(Match.CONFIG)`),
exported, and read **directly** by the owner in 36 places in `src/server/Match/init.luau`
(`applyPlace`, `applyAssignTeams`, `onSafetyViolation`, `samplePush`, `Match:step`, `snapshot`,
`mayCarryWeapon`, `applyFreeze`, `quickTestPhantom`, …).

#### 4.2.1 The shape

```luau
Match.CONFIG                        -- UNCHANGED: the frozen DEFAULTS, exported, what every spec reads
Match.WORLD_OVERRIDABLE: { [string]: true }        -- frozen; the allow-list
Match.mergeConfig(defaults, overrides)             -- PURE, exported for the spec
Match.config()                                     -- the LIVE table this drive is running on
```

* A module-level `local config = Match.CONFIG`. **Every one of the 36 internal `Match.CONFIG` reads
  becomes `config`.** A missed one is a drive whose clock says 300 and whose safety grace reads 600 —
  so the spec in §13.1 asserts the two tables are not interchangeable.
* `Match.start(injected)`: `config = Match.mergeConfig(Match.CONFIG, world.config)`, **before**
  `Phase.initial(config)` (today it is `Phase.initial(Match.CONFIG)`, which would seed the state from
  the wrong table).
* `Match.stop()`: `config = Match.CONFIG`.

#### 4.2.2 The merge rule: top level, key by key, allow-list, scalars only

```
mergeConfig(defaults, overrides):
  overrides nil or empty      -> return defaults ITSELF (identity; DEV changes nothing)
  key not in WORLD_OVERRIDABLE -> error("Match.start: a world may not override <key>")
  type(value) == "table"       -> error("Match.start: <key> is a block; a world may override scalars only")
  otherwise                    -> Drive.deepFreeze(table.clone(defaults) with the keys written)
```

`table.clone` of a frozen table returns an unfrozen copy — the idiom `Flags.resolve` already uses and
documents — so `Match.CONFIG` is never mutated.

**Tables are refused, and the evidence is in this repo.** `Boar.newRuntime`'s merge is
`for key, value in pairs(world.config)`, which replaces a nested block wholesale. That cost three
repairs: `ForestTestBoot` must hand-clone `MODEL`, `CALM`, `PACE`, `MOVE` and `LINE`
(`local model = table.clone(Boar.CONFIG.MODEL); model.ENABLED = true`), and `Boar.newRuntime` grew
key-by-key merges for `SENSE` and `KINDS` plus a special clone for `MODEL.ANIMATION_IDS` — each with a
comment saying what nil-for-every-number did. One refusal here is cheaper than three repairs there.

#### 4.2.3 The allow-list, and what is never overridable

**Overridable** (`Match.WORLD_OVERRIDABLE`): `DRIVE_SECONDS`, `INTERMISSION_SECONDS`,
`SCORE_SECONDS`, `BOARS_PER_DRIVE`, `FIRST_RELEASE_SECONDS`, `RELEASE_INTERVAL_SECONDS`,
`MAX_ALIVE_BOARS`, `STAND_HEIGHT_STUDS`, `PLACE_TIMEOUT`.

**Never overridable, and why:**

| Keys | Why not |
|---|---|
| `SAFETY_ENABLED`, `SAFETY_MISS_STUDS`, `SAFETY_RANGE_STUDS`, `SAFETY_BODY_STUDS`, `SAFETY_GRACE_SECONDS`, `TIE_UNTIL_DRIVE_END`, `TIE_SECONDS`, `TIE_GAP_STUDS` | `drive.md` §3.4: the rule numbers are not replicated because a client that knows them can dodge the rule by eye. A per-world value is a second answer to one rule — in the world Karen actually plays, which is exactly where the rule must be the real one |
| `POINTS`, `SOUNDER` | blocks (refused by the table rule as well) |
| `MIN_PLAYERS`, `MAX_PLAYERS`, `ODD_PLAYER_TEAM`, `SWAP_TEAMS_EACH_DRIVE`, `DRIVERS_MAY_SHOOT` | brief decisions 1 and 7 are these five values. A world that could change them could silently make a solo player a beater, or stop the rotation Karen asked for |
| `OUTFITS_ENABLED`, `QUICK_TEST*` | flag-derived. A second value for a flag is a second boundary read (`docs/design/feature-flags.md`) |
| `SEED`, `STATE_MIN_INTERVAL`, `STATE_HEARTBEAT`, `MATCH_STEP_HZ`, `PUSH_SAMPLE_HZ`, `ROPE_*`, `END_ON_LAST_BOAR`, `RELEASE_JITTER_SECONDS` | nothing has asked, and an unused override is a key nobody tested |

#### 4.2.4 The forest's override list — two keys

```luau
config = {
    DRIVE_SECONDS   = ForestTest.Data.DRIVE.seconds,   -- 300; the forest's own number, one home
    BOARS_PER_DRIVE = 0,                               -- its animals are its own
}
```

`INTERMISSION_SECONDS` 20 and `SCORE_SECONDS` 25 unchanged (brief §3).

`BOARS_PER_DRIVE = 0` switches the schedule off **with data and no new branch**:
`Phase.maybeRelease`'s first predicate is `state.boarsReleased >= config.BOARS_PER_DRIVE`, true on
every step, so no effect, no hold-back and no warning. `Phase.sounderSize` also returns 0 at
`remaining <= 0`. Nothing in `Phase` learns about a world.

#### 4.2.5 How "DEV does not change" is proved rather than hoped

`mergeConfig(Match.CONFIG, nil)` returns `Match.CONFIG` **itself**. So in the DEV place, after
`MatchBoot` has started the drive with no `config` field:

```luau
expect(Match.config()).to.equal(Match.CONFIG)      -- identity, in tests/server/match_live.spec.luau
```

That single assertion covers every number, because there is only one table. The existing frozen-table
case in the same spec (writing `Match.CONFIG.DRIVE_SECONDS` must error) keeps the defaults immutable.

### 4.3 The placement

#### 4.3.1 The decision: an injected provider; `Body` stays the one writer

```luau
export type Placement = (markers: MarkerSet, team: TeamName, index: number, config: any) -> CFrame?
```

Same argument order as `Body.placementFor`, so the **default is `Body.placementFor` itself**:

```luau
-- src/server/Match/init.luau, applyPlace()
local place = if world and world.placement then world.placement else Body.placementFor
local cframe = place(markerSet, team, indexWithinTeam(userId, team), config)
Body.place(player, cframe, config, …)              -- unchanged: Body respawns and pivots
```

`Body.place` is still the only thing that calls `LoadCharacter` and `PivotTo`. Only the *choice* of
spot is the world's. A provider that answers nil behaves exactly as `placementFor`'s nil does today:
`Body.place`'s `pivot` dresses the character and returns `finish(true)` — *"nowhere to put them: they
spawned, and that is not a failure"*.

#### 4.3.2 The forest's provider (a closure in `ForestTestBoot`)

```luau
local function placement(markers, team, index, cfg)
    if team == "Shooters" then
        -- The forest chooses WHICH post; Body's one rule puts her on it.
        return Body.placementFor(markers, team, ForestTest.standIndexFor(index), cfg)
    end
    -- A beater: the measured start, looking down the push at the road.
    local at = ForestTest.beaterStartPosition()
    local road = ForestTest.Data.roadPointAt(at.X)
    return CFrame.lookAt(at, Vector3.new(road.X, at.Y, road.Z))
end
```

* **Shooters go through `Body.placementFor`**, so `STAND_HEIGHT_STUDS`, the post's own `Size.Y/2` and
  the facing are one rule in both worlds. The marker posts are at measured ground, so a hunter lands
  3.5 studs above the road at her stand, not at one y for the whole hillside.
* **`ForestTest.standIndexFor(index)` is new and pure**: centre-out, `5, 4, 6, 3, 7, 2, 8, 1, 9`, so a
  **solo hunter gets stand 5** — exactly where task 153 put her (`ForestTest.spawnPosition` uses
  `PICK.defaultIndex = 5`) and exactly the x that `ForestTest.hunterStandX()` already aims every wave
  at. Without it `Body.placementFor` would put her on `posts[1]`, 600 studs west of where the drive
  aims — the "whether she ever got a close crossing was luck" defect task 123 round 8 fixed.
  Wrapping (`% 9`) is kept so a 10th hunter shares stand 5; with `MAX_PLAYERS = 16` and a balanced
  split there are at most 8 shooters, so the wrap is unreachable in production and asserted anyway.
* **The beater keeps task 153's accepted geometry byte for byte.** `beaterStartPosition` measures the
  ground with `terrainYAt`, checks trunk clearance with `roomToStand`, and side-steps ±10…±40 studs.
  The look is the point on the curve at her own x, flattened to her own height.

#### 4.3.3 Which way each role faces — already right, and the number that says the provider is needed

* `Body.placementFor` faces a shooter **+Z**. North is +Z in the forest and the drive comes from the
  north (`ForestTest.DRIVE_BEARING_DEG = 0`; `ForestTestBoot.placeFor`'s own correction:
  *"North is +Z here … so he is turned to face it"*). **Correct, unchanged.**
* `Body.placementFor` faces a driver **−Z**, i.e. straight south. The road is south of the beaters, so
  the sign is right — but the road is a sine, and its tangent swings by
  `atan(30/70) = 23.2°` over a 440-stud wavelength. A straight −Z look is therefore **up to 23° off
  the push direction**. That is the whole reason the beater branch does not use `placementFor`.

#### 4.3.4 Every drive start respawns everybody — what that moves, and who re-opens it

`Body.place` calls `LoadCharacter`, and `enterAssigning` emits `placePlayers` for everybody. The
effect order in `enterAssigning` is `assignTeams` → `clearBoars` → `placePlayers` → `refreshArming`,
which is load-bearing here:

| Thing | What the respawn does | Who restores it |
|---|---|---|
| the **outfit** | the character is replaced | `Body.place`'s `pivot` calls `Body.dressWhenLoaded` — already the design's first call site, and the team was written by `assignTeams` one effect earlier |
| the **horn Tool** | destroyed with the character | `Weapon.Horn.start()`'s own carry sweep, over the team `assignTeams` just wrote (`MatchBoot`'s own comment states this) |
| the **gun** | destroyed with the character | the `refreshArming` effect, one effect later |
| the **stand pick** | — | the boot re-opens the 10 s window on `PhaseChanged → Running`, for `Shooters` only (§5.4). Not on `CharacterAdded` any more: a hunter who resets mid-drive keeps the stand she locked |
| the **leash** | — | unchanged; it reads `state.picks`, and a beater has no pick |
| the **tie** | a tied player who resets | unchanged: `Match.watchCharacter` re-ties at the same anchor |
| the **wood / the waves** | nothing | deliberately nothing (§7.2) |

**One consequence Karen will see, named:** she now spawns at the place's own SpawnLocation and is
placed by the drive, not within a frame. That is one marker read (≤ 1 s) plus
`INTERMISSION_SECONDS` (20 s) ≈ **21 seconds from Play to standing on a stand**. The one-line fix is on
the allow-list (`INTERMISSION_SECONDS`); the brief fixes the start value at 20, so it is an open
decision for Karen and the Director (§17), not a blocker.

---

## 5. Who decides which role a player is

### 5.1 The finding that settles it

`Player.Team` has one writer (`Match.Body.setTeam`) and, in the forest today, two deciders:
`Match`'s roster (`Phase.enterAssigning` → `Roster.assign` → `assignTeams`) and the forest's own
request (`ForestTest.roles` → `ForestTestBoot.applyRole`).

A direct `Body.setTeam` from the boot is not merely a second decider — **it would not even work**.
`Match` reads `state.assignment`, not `Player.Team`:

* `Match.mayCarryWeapon` → `state.assignment[player.UserId]`
* `Match.boarThreats` / `Match.driverThreats` → `Body.boarStimuli(function(player) return state.assignment[player.UserId] end, …)`
* `samplePush` and `onSafetyViolation` → `driverPositions()` → the same table

So `/beater` through `Body.setTeam` would change the outfit and the horn and leave the drive believing
she is a hunter: armed, push-credited, unprotected by the safety rule.

### 5.2 The decision

**The drive is the one decider. `Player.Team` is the one answer. The forest's role becomes a one-shot
REQUEST that re-enters through the drive.**

1. **`ForestTest.roleOf` is removed** and archived with a note (rule 7). It is replaced by a pure
   function of the team:

   ```luau
   function ForestTest.roleFor(team: string?): RoleWord   -- PURE
       return if team == ForestTest.Data.PUSH_TEAM then "beater" else "hunter"
   end
   ```

   `Data.PUSH_TEAM` already exists (`"Drivers"`) precisely so nothing hard-codes a team name.
   `ForestTest.threatKind(role)` is unchanged, so the word→stimulus mapping stays where it is.

   The five behaviour readers the brief named now read the team the engine replicates:

   | Reader | Before | After |
   |---|---|---|
   | `boarThreats` (`threatKind`) | `roleOf(userId)` | `roleFor(player.Team and player.Team.Name)` — it already walks `Players:GetPlayers()` |
   | `realBeaters` | `roleOf(userId) == "beater"` | the same team read |
   | `beaterMode` | any stored role is `"beater"` | any player is on `Data.PUSH_TEAM` |
   | `leash` | `roleOf(userId) ~= "hunter"` | `ForestTest.leash(userId, root, role)` — the role is a parameter; the boot's heartbeat already holds the Player |
   | the stand pick (`lockPick`, the window) | `roleOf(userId) ~= "hunter"` | the boot reads the team it already has |

   Reading `Player.Team` is **not** a second writer, and there is precedent: the client's
   `Match.myTeam()` reads `Players.LocalPlayer.Team` and `drive.md` §9.3 says so explicitly
   (*"NOT from the snapshot"*). `ForestTest` still does not require `Match`.

   **`beaterMode`'s timing property survives.** Today it reads the role rather than a body *"because
   the wood has to be full before she has finished falling onto the ground"*. `assignTeams` writes
   `Player.Team` **before** `placePlayers` in the same effect list, so the team exists a respawn
   earlier than the character — the same guarantee, from the effect order.

2. **The request, named as a request** (`src/server/ForestTest/init.luau`, `state.requests`, beside
   `state.picks`):

   ```luau
   function ForestTest.requestRole(userId: number, role: RoleWord): RoleWord
   function ForestTest.takeRequest(userId: number): RoleWord?   -- one-shot: returns AND clears
   function ForestTest.clearRequest(userId: number)
   ```

3. **One new owner function and one new pure event.** `Match` gains:

   ```luau
   function Match.requestTeam(player: Player, team: TeamName?): boolean
       -- dispatch({ kind = "team", userId = player.UserId, team = team }); returns whether it was honoured
   ```

   `Phase.step` gains `kind == "team"`, which is the `join` branch's shape with no participant added:

   * phase `Running` or `Assigning` and the userId is a participant →
     `next_.assignment[userId] = team`, then the effects
     `assignTeams { [userId] = team }`, `placePlayers { userId }`, `refreshArming { userId }`,
     `broadcast`;
   * phase `Waiting` or `Scoring` → **no state change and no effect**, and `requestTeam` returns
     false. A preference belongs to the next `enterAssigning`, which is the roster's own business.

   `Roster` is **unchanged**. There is no sticky preference, and that is the point: see §5.3.

4. **`/beater` and `/hunter` stay** (a dev command in a playtest world: server-only, no remote, no
   binding, no client module). `ForestTestBoot`'s `player.Chatted` handler becomes:

   ```luau
   ForestTest.requestRole(userId, role); honour(player)
   -- honour(player): local word = ForestTest.takeRequest(player.UserId)
   --                 if word then Match.requestTeam(player, Body.teamForWord(word)) end
   ```

   `Body.teamForWord` remains the one translator from "beater" to `Drivers`.

5. **`DHForestStartRole` stays** and now works as a *start* switch rather than a join-time write: on
   `PlayerAdded` the boot records the request, and `honour` is replayed from the drive's own signal —
   `Match.PhaseChanged`, on entering **`Running`**. Not `Assigning`: that phase emits `placePlayers`
   for everybody, and a request applied in the same intermission would be a second `LoadCharacter` for
   that player. On entering `Running` everybody has been placed once, and the request respawns exactly
   the one player who asked, at the beater start. **Cost: one extra respawn for the player who asked,
   at the instant the drive starts.** Stated rather than discovered.

6. **`ForestTestBoot.applyRole` is deleted**, with all three of its manual calls: `Body.setTeam`,
   `Weapon.Horn.refreshCarry` and `Weapon.refreshArming` are the drive's effects now (§4.3.4).

### 5.3 What a solo player gets, drive by drive

| | Drive 1 | Drive 2 | Drive 3 |
|---|---|---|---|
| No switch set | **hunter**, armed, stand 5 (`MIN_PLAYERS = 1`, `ODD_PLAYER_TEAM = "Shooters"`) | **beater** (`SWAP_TEAMS_EACH_DRIVE = true`, honoured through `previousAssignment`), horn, no gun (`DRIVERS_MAY_SHOOT = false`) | hunter |
| `DHForestStartRole = beater` | roster says hunter, then the request flips her at `Running`: **beater** | **hunter** (the swap) | beater |

**This task takes the rotation** rather than deferring it: `SWAP_TEAMS_EACH_DRIVE` is already `true`
in `Match.CONFIG`, and Karen asked for exactly it on 2026-10-11 (*"you start as a hunter then next
round you are beater"*). A request is consumed when honoured, so it cannot defeat the rotation; the
start switch only decides the parity.

**The nicest consequence, and it is free:** `beaterMode()` now follows the team, so drive 1 (hunter)
runs the 20-second wave schedule at her stand and drive 2 (beater) runs the stocked resting wood —
the two experiences Karen has accepted, alternating, with no new code.

### 5.4 The stand pick and the leash, after the change

* The pick window opens on `PhaseChanged → Running` for `Shooters` only, with
  `ForestTest.openPick` + the existing `task.delay(Data.PICK.seconds, …)` → `lockPick`. The
  `task.delay` guard changes from `roleOf(...) ~= "hunter"` to the live team read.
* `ForestTest.clearPick` is called when the drive changes a player's team (the boot's `honour`, and on
  `PhaseChanged → Assigning` for everybody): a locked stand for a beater would make `hunterStandX()`
  name a stand nobody is on, and the drive aims every wave at that x.
* The leash is otherwise untouched: 6 studs, hunters only, a pull and not a freeze.

---

## 6. The drive line, the safety rule and the tie

### 6.1 One plane for a sine road — and the approximation costs nothing

`Markers.DriveLine` is `{ position, normal }`: one plane. The forest supplies
`position = (3030, postY, CENTRE.Z)` — at x = CENTRE.X the curve's sine is 0, so this is exactly on
the road — and `normal = Vector3.zAxis`, which is the meaning `Markers.read` gives the field (*"the
part's LookVector points at +Z, the drivers"*).

**The approximation, in studs:** the true road is `CENTRE.Z + 30·sin((x − CENTRE.X)/70)`, so the plane
is up to **±30 studs** north or south of the road's actual z, and a hunter at stand 1 or 9 stands
**600 studs** from the plane's own position along x.

**The consequence, by symbol:**

* `src/server/Weapon/SafetyArc.luau`, `SafetyArc.isForbidden`, is
  `direction.Unit:Dot(line.normal.Unit) >= cos(halfAngle)` — it reads **the normal only**. The
  position never enters the verdict. So ±30 studs of plane offset and 600 studs of lateral distance
  change **nothing**. What would matter is north ceasing to be the drive side, and the curve's tangent
  swings only ±23.2°, so every x on the road has the beaters to its north.
* `Penalty.judge` reads no line at all: the shot's own muzzle and aim against live driver positions.
* The only reader of `line.position` is `Match.quickSpawnFor`, under `QUICK_TEST` — off, Studio-only,
  and the forest releases nothing.

So the one-plane approximation is **free in this world**, and the reason is which field each symbol
reads, not an estimate.

### 6.2 What the arc does change in the forest, and the comment that stops being true

`ForestTestBoot` registers `noDriveLine` today with a comment that says *"there are no drivers in this
world — the beaters are phantoms"*. **That sentence stops being true the moment the real drive runs
there** (the task-151-round-1 rule: do not leave the older sentence standing). `noDriveLine` and its
comment are **deleted**, replaced by `MatchBoot`'s own line:
`Weapon.setDriveLineProvider(Match.driveLine)`.

What that means, stated plainly:

* **The arc only publishes; it never refuses a shot.** `onFireRequest` fires `SafetyViolated` and
  `Match.onSafetyViolation` then requires `Penalty.judge` to find a **real** driver within
  `SAFETY_MISS_STUDS` (12) of the shot's own truncated path. `Match.playerDrivers` filters by
  `tonumber(driver.id)`, so the wave phantoms (`"beater-3"`) can never be that driver.
* **So a solo hunter can never lose a shot.** With `SAFETY_ARC_HALF_DEG = 45` she will publish a
  violation on most shots up the drive, and `judge` will answer false every time. The cost is
  bookkeeping, not a penalty.
* **With two players it bites, which is the rule working.** A beater 240 studs up the push line and a
  hunter shooting up the drive at an animal with the beater behind it → tied to her stand for the rest
  of the drive. In the world Karen actually plays. This is the single behaviour in this task that
  needs two players to observe (§13.3).

### 6.3 Where a tied player is tied

**Decision: the nearest of the nine stand markers. The forest tags no trunks in this task.**

`Body.anchorFor` takes `markers.trees` when it is non-empty and `markers.posts` otherwise; the forest
supplies no trees, so the fallback is the answer by construction. `Body.tiePointFor` then puts her
`max(6, 6)/2 + TIE_GAP_STUDS` = **5.5 studs** from the marker's centre, at
`post.Position.Y − 0.5 + 3.5` = 3 studs above the road, facing it, with a rope.

Why not tag trunks: the forest's trees live in `OurForest`, `Foliage` and two Studio-built `Session`
folders of 831 more that this repo did not write. Tagging them would mean a run-time writer into
Studio content and the first `DrivenHunt.*` tags in that place — the one property §1.2 item 3 keeps.
And a hunter roped to her own stand reads correctly ("tied at your post").

**The deviation from Karen's words is named**, not buried: her rule is *"tied to a tree"*. If she wants
a trunk, it attaches at exactly one place — `ForestTest.Markers.build` fills `trees` with the nearest
solid parts found by `ForestTest.nearestSolid` around each stand, and nothing else changes, because
`Body.anchorFor` already prefers `trees`. Queued as an open decision (§17), not built.

`TIE_UNTIL_DRIVE_END` stays **true** there: it is the flag's resolved value, it is not on the
override allow-list, and in a 300-second drive it means up to five minutes tied. Karen has accepted
the rule as written; the number she would change is `DRIVE_SECONDS`, which is on the list.

### 6.4 The client

Nothing. `MatchBoot.client.luau` starts `PlayerScripts.Match` in every world; `Hud` draws the drive
bar, the feed, the score screen, the tied banner and the `WAITING <missing>` text from the replica;
the Hud's only per-world branch is the compass/map geometry
(`Map.EXPECTED_WORLD == "forest-test"`), and `Hud.driveBearing(data, team)` already switches on
`Player.Team == Data.PUSH_TEAM`, which the drive now writes. **No client file changes in this task.**
Said so nobody adds one.

---

## 7. The record, the report and the forest's own schedule

### 7.1 One window owner: `Match.PhaseChanged`, in both worlds

`ForestTestBoot`'s Heartbeat latch on `ForestTest.drive(now).index` is **deleted**. In its place,
`MatchBoot`'s two lines, verbatim:

```luau
Match.PhaseChanged:Connect(function(_before, phase, driveNumber)
    if phase == "Assigning" then HitLog.openDrive(driveNumber or 1, os.clock())
    elseif phase == "Scoring" then HitLog.closeDrive(os.clock()) end
end)
```

Both `HitLog` calls are idempotent at the other end, so a phase that fires twice cannot open two
drives. `HitLog.start()` stays where it is.

### 7.2 What `ForestTest.DRIVE` means afterwards

It keeps **moving nothing** — which was already true (*"it moves no animal and resets no schedule"*)
— and it keeps one job: `ForestTest.Data.DRIVE.seconds` (300) is the **source** of the forest's
`DRIVE_SECONDS` override, so the number has one home.

`ForestTest.drive(now)` and `ForestTest.driveIndexAt` lose their only production caller. Named
decision: they are **retained as the pure window arithmetic their spec drives**, and the Builder says
so in the module comment. A function nothing reads is the next reader's trap, so if nothing claims
them by the next audit they are archived with a note (rule 7). Same treatment for
`ForestTest.spawnPosition`, whose only caller (`placeFor`'s hunter branch) goes: either it becomes the
marker builder's y helper or it is archived in the same commit — it may not be left silently uncalled.

**The drive's phase does NOT reset the wave or rest schedule** (brief §4, note §6). `ForestTest.start`
is still called once at boot and nothing resets `nextWaveAt`, `state.active` or `state.rest`. The
thing at risk is the rhythm Karen accepted in tasks 123, 150, 153 and 154, and nothing asked for it to
change. One consequence: at a drive boundary everybody is respawned and the wood is not re-stocked, so
a beater who emptied it starts the next drive in an empty wood until `REST.restockSeconds` (15 s) after
the last animal left — which is the rule she already accepted.

---

## 8. `ForestTestBoot`, job by job

| Job today | KEEP / MOVE / DELETE | Why |
|---|---|---|
| `Map.EXPECTED_WORLD ~= "forest-test"` early return | **KEEP** | the switch (§14) |
| the boot print (`stands`, `intervalSeconds`) | **KEEP**, add the marker line (§13.5) | the only honest channel |
| `field`, the six `table.clone` config blocks, `world.groundAt`, `world.config`, `maxBoars` | **KEEP** | the boar's world, unchanged |
| `world.threats = ForestTest.boarThreats` | **KEEP** | the closure trap, and the forest's phantoms are not `Match`'s (§15) |
| `Boar.newRuntime(world)` + `runtime:run()` | **KEEP** | |
| `Weapon.ShotFired` → `runtime:hearShot` | **KEEP** | the weapon's contract does not change with the world |
| `Weapon.Horn.Blown` → `runtime:hearHorn(…, true)` + the console line | **KEEP** | the latch is this world's decision (task 154) |
| `Weapon.HitReported` → `HitLog.recordHit` + `runtime:takeHit` | **KEEP** | |
| `runtime.Downed` → `HitLog.recordDown` + `Weapon.markHit` | **KEEP** | |
| `Weapon.setArmingPolicy(HornData.gunFor(Body.teamOf))` | **DELETE** → `Weapon.setArmingPolicy(Match.mayCarryWeapon)` | §8.1 |
| `noDriveLine` + `setDriveLineProvider(noDriveLine)` + the comment | **DELETE** → `Weapon.setDriveLineProvider(Match.driveLine)` | §6.2 |
| `Body.ensureTeams()` | **DELETE** | `Match.start` does it, idempotently |
| `applyRole` | **DELETE** | §5.2 item 6 |
| `Weapon.Horn.setCarryPolicy(carriesFor(true, Body.teamOf))` + `Horn.start()` | **KEEP** (`hornOn = true` stays this world's decision) | the horn still reads `Player.Team`, which the drive now writes |
| `placeFor` | **MOVE** into the `placement` provider (§4.3.2); `root.CFrame` writes go, `Body.place` writes | one writer of where a character stands |
| `startAt` | **MOVE**: the placement half goes to the provider; the pick window and the console line move to `PhaseChanged → Running` | §4.3.4, §5.4 |
| `PlayerAdded` → `startRole` → `setRole` | **KEEP**, as `requestRole` | §5.2 item 5 |
| `PlayerAdded` → `Chatted` → `setRole` + `applyRole` + `clearPick` + `startAt` + the console line | **MOVE**: `requestRole` + `honour` + `clearPick`; the console line stays | §5.2 item 4 |
| `PlayerAdded` → `CharacterAdded` → `applyRole` + root wait + `task.defer(startAt)` | **DELETE** | the drive owns the respawn, the placement and the dressing |
| `PlayerRemoving` → `ForestTest.clearPick` | **KEEP** | `ForestTest` owns the pick |
| `PlayerRemoving` → `ForestTest.clearRole` | **KEEP**, as `clearRequest` | |
| `PlayerRemoving` → `Body.forget` | **DELETE** | `Match.forget` runs in this world now and calls it. Two connections to one event with undefined order, doing independent work, is fine; two callers of `Body.forget` is not needed |
| Heartbeat: the drive latch + `HitLog.openDrive/closeDrive` | **DELETE** → `Match.PhaseChanged` (§7.1) | one window owner |
| Heartbeat: `ForestTest.step(now)` + its print | **KEEP** | the forest's animals |
| Heartbeat: `waveReport` / `restReport` every 2 s | **KEEP** | the evidence channel |
| Heartbeat: the per-player `ForestTest.leash` | **KEEP**, with the role passed in (§5.2) | |
| `HitLog.start()` | **KEEP** | |
| `ForestTest.start(runtime, os.clock())` | **KEEP** | |
| — | **NEW:** `ForestTest.Markers.clear()` is not called at boot; `build` destroys and rebuilds | |
| — | **NEW:** `Match.start({ boars = ForestTest.readOnlyBoars(runtime), weapon = Weapon, now = os.clock, markers = function() return ForestTest.Markers.build(ForestTest.hunterStandX()) end, placement = placement, config = { DRIVE_SECONDS = Data.DRIVE.seconds, BOARS_PER_DRIVE = 0 } })` | the whole of the change, in one call |

### 8.1 Where `Match.start` and the existing code would both act — and which wins

| Contest | Winner | Why, and what is deleted |
|---|---|---|
| **arming**: `Match.mayCarryWeapon` vs `HornData.gunFor(Body.teamOf)` | **`Match.mayCarryWeapon`** | For these two teams `gunFor` *is* `mayCarryWeapon`'s answer (`Shooters` → yes; `Drivers` → `DRIVERS_MAY_SHOOT` = false), plus two things `gunFor` cannot know: `Waiting` (nobody armed before a drive) and `tied` (a tied hunter's gun goes). `Horn.gunFor`'s own header says task 154's bug was two policies answering one question. `gunFor` keeps its file and its spec; this world stops calling it. **New behaviour to expect: no gun in `Waiting`** |
| **the respawn**: `Body.place` vs `startAt`/`placeFor` | **`Body.place`** | one writer of where a character stands. `placeFor`'s arithmetic survives as the provider's return value |
| **the outfit**: `Match.watchCharacter`/`Body.place` → `dressWhenLoaded` vs `applyRole` → `setTeam` → `dressWhenLoaded` | **the drive's** | `applyRole` goes; the team is written by `assignTeams`, one effect before the respawn |
| **the horn carry sweep** | **`Weapon.Horn`'s own sweep** | `applyRole`'s `refreshCarry` goes. The sweep reads `Player.Team`, which the drive writes |
| **`Weapon.refreshArming`** | **the `refreshArming` effect** | `applyRole`'s call goes. The weapon still decides and still writes |
| **the HitLog window** | **`Match.PhaseChanged`** | the Heartbeat latch goes |
| **`Player.Team`** | **`Match.Body.setTeam`, from the roster or from `Match.requestTeam`** | the boot never calls `setTeam` again |
| **when an animal exists** | **`ForestTest`** | `Match` gets a read-only view (§9.3) |

---

## 9. Public interface

### 9.1 `ServerScriptService.Match` — added

```luau
Match.config(): Config                             -- the LIVE table; == Match.CONFIG in DEV
Match.mergeConfig(defaults: Config, overrides: { [string]: number | boolean }?): Config   -- PURE
Match.WORLD_OVERRIDABLE: { [string]: true }        -- frozen allow-list (§4.2.3)
Match.requestTeam(player: Player, team: TeamName?): boolean    -- honoured only in Assigning/Running
```

`World` (`drive.md` §9.2) becomes:

```luau
{ boars?, weapon?, now?, serverTime?, players?, remotes?, heartbeat?, collection?, rng?,
  markers?: MarkerSet | () -> MarkerSet,          -- CHANGED: a function is allowed
  config?: { [string]: number | boolean },        -- NEW
  placement?: (MarkerSet, TeamName, number, Config) -> CFrame? }   -- NEW
```

`Match.CONFIG`, `Match.snapshot`, `Match.stats`, the three signals, the exported pure modules: all
unchanged.

### 9.2 `Match.Phase` — added

```luau
export type Event = { kind: "tick" | "join" | "leave" | "kill" | "gone" | "violation" | "markers"
                           | "team",              -- NEW
                      team: TeamName?, … }        -- NEW field, read only by the "team" branch
```

No new effect kind. No new state field. `Roster`, `Score`, `Penalty`, `Markers`, `Body`: unchanged.

### 9.3 `ServerScriptService.ForestTest` — added, changed, removed

```luau
-- NEW
ForestTest.Markers                                 -- the module above (§4.1.2)
function ForestTest.standIndexFor(index: number): number        -- PURE, centre-out, wraps
function ForestTest.roleFor(team: string?): RoleWord            -- PURE
function ForestTest.requestRole(userId: number, role: RoleWord): RoleWord
function ForestTest.takeRequest(userId: number): RoleWord?      -- one-shot
function ForestTest.clearRequest(userId: number)
function ForestTest.readOnlyBoars(runtime): BoarView            -- §9.4

-- CHANGED
function ForestTest.leash(userId: number, root: BasePart, role: RoleWord?): Vector3?

-- REMOVED (archived with a note, rule 7)
ForestTest.roleOf, ForestTest.setRole, ForestTest.clearRole, state.roles
```

### 9.4 The read-only boar view — how `Match` scores without owning the animals

```luau
export type BoarView = {
    Downed: RBXScriptSignal, Despawned: RBXScriptSignal,
    boars: (self) -> { Handle }, count: (self) -> number, capacity: (self) -> number,
    -- and NO clear, NO spawn, NO spawnSounder
}
```

It writes nothing: three forwarded reads and two forwarded signals. What that buys, each checked
against the owner's code:

| `Match` path | With the view |
|---|---|
| `applyClearBoars` | `world.boars.clear` is nil → the existing conditional is false → only `table.clear(pushCredit)`. **The forest's wood is never cleared at a drive boundary.** This is the research note's §2.6 used as designed, not a new branch |
| `applySpawnSounder` | unreachable at `BOARS_PER_DRIVE = 0`; if it were ever reached, the `pcall` turns the missing method into `stats.releasesDeferred` + `Phase.releaseFailed` — a counted retry, never a silent drop |
| `onDowned` / `onDespawned` | **connected** → kills and escapes score, the feed publishes, `HitLog` already has its own wire. The scoreboard works in the forest |
| `samplePush` | `world.boars:boars()` works → a beater who pushed an animal a hunter then shoots earns `POINTS.PUSH` (25). This is what the rotation is *for* |
| `boarsAlive`, `dispatch`'s `boarEntries`/`boarCapacity` | honest numbers, read only by the unreachable release guard |

A spec asserts the view has no `clear`, `spawn` or `spawnSounder` — so "one owner of the animals" is a
test, not a comment.

---

## 10. What this system reads and writes, and who owns each

| It reads | Owner | It writes | Owner |
|---|---|---|---|
| `Map.EXPECTED_WORLD`, `Map.WORLD_BY_PLACE` | `ReplicatedStorage.Map` (frozen, no run-time writer) | `Workspace.ForestMarkers` + its 10 parts | **`ForestTest.Markers`** (new, sole) |
| `ForestTest.Data`: `roadZ`, `standPosition`, `STAND_COUNT`, `STAND_SPACING`, `beaterStart`, `roadPointAt`, `DRIVE.seconds`, `PUSH_TEAM`, `REST.spreadStuds`, `PICK`, `START_ROLE_ATTRIBUTE` | `ReplicatedStorage.ForestTest` (frozen data) | `state.requests`, `state.picks` | `ServerScriptService.ForestTest` |
| `ForestTest.terrainYAt`, `Data.groundAt`, `roomToStand`, `nearestSolid`, `beaterStartPosition`, `hunterStandX` | `ServerScriptService.ForestTest` | `state.assignment`, the phase, the board, `tied` | `ServerScriptService.Match` |
| `Player.Team` (replicated engine field) | written **only** by `Match.Body.setTeam`; read by `ForestTest`, by `Weapon.Horn`'s policy and by the client's `Match.myTeam()` | `Player.Team`, the character's position, its outfit, the rope | `Match.Body` |
| `runtime.Downed`, `Despawned`, `boars()`, `count()`, `capacity()` | `ServerScriptService.Boar` | nothing in `Boar` | — |
| `Weapon.SafetyViolated`, `Weapon.refreshArming` | `ServerScriptService.Weapon` | the arming policy and the line provider, injected at the root | `Weapon` still decides and writes |
| `HornData.carriesFor`, `spookStuds` | `ReplicatedStorage.Horn` | the horn Tool | `Weapon.Horn` |
| `ServerStorage` attribute `DHForestStartRole` | the Director, in Edit (not a `DHFlag_*`, so the harness's override guard cannot see it) | — | — |
| `TestKit.activeToken` (through `Match.advanceForTests`) | `ReplicatedStorage.TestKit` | — | — |

---

## 11. External sources

### 11.1 Unreal Engine — `AGameModeBase::FindPlayerStart` / `ChoosePlayerStart` and the `PlayerStart` actor

* [FindPlayerStart (UE 5.1 API)](https://docs.unrealengine.com/5.1/en-US/API/Runtime/Engine/GameFramework/AGameModeBase/FindPlayerStart/),
  [Player Start Actor](https://dev.epicgames.com/documentation/unreal-engine/player-start-actor-in-unreal-engine?lang=en-US)
* Licence: Epic documentation, free to read, not open-licensed. **Maintained** (current 5.x).
* **Well:** the mode asks the LEVEL where to put a player, by tag, and `ChoosePlayerStart` is the hook
  a project overrides. One mode, many levels, no per-level branch in the mode. That is exactly
  `world.placement` plus `markers.posts`.
* **Badly:** it is an engine class hierarchy, and the override lives in a *subclass* of the mode — two
  worlds mean two mode classes, which is the thing this design refuses. And a level with no
  `PlayerStart` spawns at the world origin: a silent wrong answer. `Body.anchorFor` already returns
  `nil` rather than a `CFrame` at 0,0,0, and §4.1.5 keeps that discipline for the marker set.
* **Adopted:** the *hook*, as an injected function rather than a subclass, and the *tag → stable
  index* idea as `posts` sorted by X.

### 11.2 Valve Developer Community — Counter-Strike map entities as the mode's contract

* [info_player_counterterrorist](https://developer.valvesoftware.com/wiki/De/Info_player_counterterrorist),
  [info_map_parameters](https://developer.valvesoftware.com/wiki/Info_map_parameters/Counter-Strike_series)
* Licence: **CC BY-NC-SA 3.0**. Community wiki, **actively edited**.
* **Well:** the map's entities ARE the mode's geometry, and the contract is countable — the number of
  spawn entities caps the team size, and the wiki states placement constraints as numbers (a spawn
  origin ≥ 16 units above ground, > 32 units from another spawn, never inside a solid). That is
  §12's nine stands at 150 studs, a 1-stud ground tolerance and a trunk-clearance test.
* **Badly:** classnames are strings with no schema, so a typo is a map that loads and a mode that does
  nothing; and the placement numbers are advice to a mapper, checked by nothing at load time.
* **Adopted:** the contract, and both corrections — the set is built in code from one data module (no
  string to mistype), and every constraint is checked at build time and reported in `missing` or
  `refused`.

### 11.3 Unity — level layout as an injected data object (`ScriptableObject`)

* [Separate game data and logic with ScriptableObjects](https://unity.com/how-to/separate-game-data-logic-scriptable-objects),
  [6 ways ScriptableObjects can benefit your team](https://unity.com/blog/engine-platform/6-ways-scriptableobjects-can-benefit-your-team-and-your-code)
* Licence: Unity documentation, free to read, not open-licensed. **Maintained** (Unity 6 material).
* **Well:** its worked example is this task — a `LevelLayoutSO` is *"a data container for the starting
  positions of game elements"*, swapped per level, with the systems reading it. That is
  `src/shared/ForestTest/init.luau` and `src/shared/Map/init.luau`, already built.
* **Badly:** a `ScriptableObject` is mutable at run time and edits leak back into the asset; and it
  says nothing about *who* chooses which layout — the part this task had to get right.
* **Adopted:** data-as-module, deep-frozen (`Drive.deepFreeze`, `Shotgun.deepFreeze`) so there is no
  run-time writer; and the choice is the **place id** (§14), never a predicate over `Workspace`.

### 11.4 Named and rejected — Knit (a Roblox DI/service framework)

* [Sleitnick/Knit](https://github.com/Sleitnick/Knit),
  [ARCHIVAL.md](https://github.com/Sleitnick/Knit/blob/main/ARCHIVAL.md)
* Licence: MIT. **Archived by its author on 2024-07-31**, and the stated reason is Luau: the design
  *"cannot fully benefit from types and thus does not have good intellisense"*.
* Rejected on both counts: archived and type-hostile, and this repo already has what a container would
  give it — one explicit composition root per world, one `require` and one call.

### 11.5 Quake III Arena / ioquake3 — the mode selects among the map's spawn points

* [ioquake3](https://github.com/ioquake/ioq3) (`code/game/g_client.c`: `SelectSpawnPoint`,
  `SelectRandomFurthestSpawnPoint`, `SelectInitialSpawnPoint`)
* Licence: **GPL-2.0-or-later**. **Maintained** (ioquake3 is the live fork of the id release).
* **Well:** the map places a flat list of spawn entities and the *mode* picks among them by a rule of
  its own — the furthest-from-danger scoring, and a separate "initial" rule for a player's first
  spawn. That is precisely the division this design draws: the forest places nine stands, and
  `ForestTest.standIndexFor` is the rule that says which one the first hunter gets.
* **Badly:** the selection is scattered across several near-duplicate functions in one C file with
  per-gametype special cases inside them, which is how a selection rule becomes four rules; and it
  resolves ties randomly, so a bug report cannot be reproduced.
* **Adopted:** one pure, deterministic selector (`standIndexFor`), no `Random` — the same reason
  `Roster` has none.

### 11.6 Borrowed from inside this repo (rule 2)

`Boar.newRuntime(world)`'s `config` merge and its three measured repairs (§4.2.2);
`Weapon.setArmingPolicy` / `setDriveLineProvider` / `setCast` and `Body.setAccessorySource` as the
function-injection idiom; `Match.quickTestPhantom` as the precedent for a phantom pusher;
`Workspace.DriveMarkers` / `WeaponEffects` as the precedent for a run-time folder in `Workspace`;
`Flags.resolve`'s `table.clone`-a-frozen-table idiom. Driven-hunt safety practice is already source D
of `docs/design/drive.md` §16 and is not restated.

---

## 12. Numeric targets

| Target | Value | Checked by |
|---|---|---|
| Forest drive length | **300 s** (`ForestTest.Data.DRIVE.seconds`); DEV stays **600** | `match_config.spec` (the override), `match_live.spec` (DEV identity) |
| Intermission / scoring | **20 s / 25 s**, both worlds | `match_config.spec`: neither is in the forest's override list |
| Animals released by `Match` in the forest | **0** | `match_phase.spec`: a forest-configured machine over a whole simulated drive emits **no** `spawnSounder`, `boarsReleased == 0`, `holdbacks == 0` |
| Hunter stands | **9**, **150** studs apart, on the curve | `forest_markers.spec`: 9 posts, each within **1 stud** of `ForestTest.standPosition(i)` in x and z |
| Post ground tolerance | within **1 stud** of `ForestTest.Data.groundAt(x, z)`; a bigger disagreement refuses the post | `forest_markers.spec` with an injected ground reader |
| Post size / stand height | **6 × 1 × 6**, character at `+Size.Y/2 + STAND_HEIGHT_STUDS` = **3.5** studs above the slab, ≈ 3 studs above the road | `forest_markers.spec`, `match_outfit`-style arithmetic |
| Solo hunter's stand | **5** (`standIndexFor(1) == 5 == Data.PICK.defaultIndex`), which is the x `hunterStandX()` aims at | `forest_stand.spec` |
| Max hunters placed | **9**; a 10th wraps to stand 5. Unreachable with `MAX_PLAYERS = 16` and a balanced split (≤ 8 shooters) | `forest_stand.spec` asserts the wrap anyway |
| Beater start | **240** studs north of the road (`LINE.spawnNorthStuds` 180 + `BEATER.behindLineStuds` 60), trunk-clear by **6** | `forest_stand.spec`, unchanged from task 153 |
| Beater's look error if the generic −Z were used | up to **23.2°** (`atan(30/70)`) — the number that justifies the provider | `forest_stand.spec`: the look is the road point at her own x |
| Drive-line plane offset from the real road | up to **±30** studs in z, up to **600** studs along x — and **0** effect, because `SafetyArc.isForbidden` reads the normal only | `forest_line.spec`: `isForbidden` is invariant to `line.position` |
| Safety numbers | unchanged: `SAFETY_MISS_STUDS` **12**, `SAFETY_RANGE_STUDS` **330**, `SAFETY_BODY_STUDS` **4**, grace **0**, arc half-angle **45°** | `match_config.spec`: none of them is overridable |
| Tie anchor | the nearest of the 9 posts, **5.5** studs from its centre, **3** studs above the road | `match_safety.spec`-style pure case with hand-written parts |
| Unused `driverStart` fallback error | `START_SIZE.X` 60 × the measured slope 0.14 (56 studs in 400) = up to **±4.2** studs of y across the pad | stated; production does not use it |
| Marker read budget | ≤ **20** raycasts per read; ≤ **1** read/s while `Waiting`; **1** per drive otherwise | `Markers.stats().reads`, console line |
| Placement misses | `Match.stats().placementsMissed` == **0** over a forest session | console line (playtest only) |
| Time from Play to being placed in the forest | ≈ **21 s** (≤ 1 s marker read + 20 s intermission) | measured by Karen; §17 open decision |
| DEV suite | the existing count does not fall; the two new specs raise it | the harness's own line |

---

## 13. How it is tested

**The hard constraint, stated first (rule 8): the harness runs in the DEV place.** No spec, no input
replay and no screenshot in this task can execute the forest's *live* path — `ForestTestBoot` returns
early in DEV, so every line of the wiring is inert during a harness run. What the gate can prove is:
the pure halves, the merge, the marker builder's refusal, the view's missing methods, and that **DEV
did not change**. Everything about the live forest is Karen's playtest plus the console lines in
§13.5. Brief decision 11 asks for no frames and no long traces, and this design asks for none.

### 13.1 Server specs

| File | New/changed | Cases |
|---|---|---|
| `tests/server/match_config.spec.luau` | **NEW**, pure | (a) `mergeConfig(CONFIG, nil)` and `mergeConfig(CONFIG, {})` return `Match.CONFIG` **by identity**; (b) `{ DRIVE_SECONDS = 300, BOARS_PER_DRIVE = 0 }` gives a new **frozen** table with those two changed and **every other key** equal, iterated over `Match.CONFIG`; (c) a key off the allow-list errors and the message names the key; (d) a table value errors; (e) `Match.CONFIG` is still frozen and unchanged after all of it; (f) `WORLD_OVERRIDABLE` contains no key matching `^SAFETY_`, `^TIE_`, `^QUICK_TEST`, and none of `POINTS`, `SOUNDER`, `MIN_PLAYERS`, `MAX_PLAYERS`, `ODD_PLAYER_TEAM`, `SWAP_TEAMS_EACH_DRIVE`, `DRIVERS_MAY_SHOOT`, `OUTFITS_ENABLED`, `SEED` — by **pattern**, so a later addition cannot sneak one in |
| `tests/server/match_phase.spec.luau` | **CHANGED**, pure | the forest config over a simulated 300 s drive: **no `spawnSounder` ever**, `boarsReleased == 0`, `holdbacks == 0`, and the phases still run `Waiting → Assigning → Running → Scoring → Assigning`. The `"team"` event: in `Running` it reassigns one userId and emits exactly `assignTeams`, `placePlayers`, `refreshArming`, `broadcast`; in `Waiting` and in `Scoring` it emits nothing and changes nothing; and the **next** drive swaps her back, asserted off `previousAssignment` (the rotation) |
| `tests/server/forest_markers.spec.luau` | **NEW** | **In the DEV place** (where the harness runs): `Markers.build(...)` answers `complete == false`, `missing` names `forest:stands (0 of 9)`, and **no part is created** — the "it can say no" proof. With an **injected** ground reader: 9 posts within 1 stud of `standPosition(i)`; one `line` with `normal == Vector3.zAxis` and `position.Z == CENTRE.Z` to 1e-6; `lineParts == 1`; `#boarSpawns == 0` **and** `complete == true`; `#trees == 0` **and** `complete == true`; a post refused when the two ground readings disagree by > 1 stud; `complete == false` when all nine are refused; `build` twice leaves exactly 10 parts; `clear()` leaves the folder gone |
| `tests/server/forest_stand.spec.luau` | **CHANGED**, pure | `standIndexFor`: `1→5`, the centre-out order, every answer in 1..9, the wrap at 10; `roleFor`: `Data.PUSH_TEAM → "beater"`, `"Shooters" → "hunter"`, `nil → "hunter"`; the request queue is one-shot (`takeRequest` twice answers nil); `readOnlyBoars(fake)` has **no** `clear`, `spawn` or `spawnSounder` and forwards the five members; `leash` refuses a beater by its new parameter. Its existing cases are untouched |
| `tests/server/forest_line.spec.luau` | **CHANGED**, pure | `SafetyArc.isForbidden` is **invariant** to `line.position` (the same verdict with the plane moved ±30 studs in z and ±600 in x); north is the drive side at x = CENTRE.X ± HALF_SPAN, i.e. `roadZ(x) < beaterStart(x).Z` for every stand |
| `tests/server/match_live.spec.luau` | **CHANGED**, live | one case: `Match.config() == Match.CONFIG` in DEV. The existing frozen-table and config-value cases unchanged |
| `tests/server/map_contract.spec.luau`, `match_roster.spec`, `match_score.spec`, `match_safety.spec`, `match_outfit.spec`, `zz_drive_boundary.spec`, `zz_horn.spec` | **unchanged** | nothing they assert moves. If any of them goes red, the merge missed one of the 36 reads |

### 13.2 Client specs

**None changed and none added** (§6.4). `tests/client/match_client.spec.luau` and
`tests/client/Role.luau` are DEV-only and untouched.

### 13.3 What genuinely needs two players

1. A **real** beater on the push line making a hunter's shot a judged violation — `Penalty.judge`
   requires a driver with a numeric `userId`, and `Match.playerDrivers` filters the phantoms out by
   construction. One player cannot produce it.
2. The roster splitting 1/1 and the rotation swapping **both** players.
3. Any client assertion about the *other* role (`tests/client/Role.luau`'s branch).

Everything else is one player or no player: the merge, the marker builder, the placement, the stand
index, the request queue, `BOARS_PER_DRIVE = 0`, the arc's direction test.

### 13.4 The gate

This change touches `src/server/Match/` and `src/server/Match/Phase.luau`, which are in
`TWO_PLAYER_PATHS`. So:

* a **review round** may use `python tools/studio_mcp.py test --scope auto` — `src/server/Match` maps
  to the `match` scope — and then no `[harness2]` line is asked for;
* the **PR to `main`** needs the full `[harness] PASS: n/n … scope=all` **and**
  `[harness2] PASS: n/n @ <same sha>`.

### 13.5 Harness input and screenshots

* **Input replay:** not applicable. The scenario file drives the DEV Play client; nothing in this task
  binds input (`/beater` is chat, read on the server).
* **Screenshots:** not applicable, and brief decision 11 says so. There is no frame of the forest the
  harness can take, and Karen judges look and feel herself.
* **The console lines that stand in for them**, all server-side in the place she plays:
  * `[ForestTestBoot] markers: 9/9 stands (0 refused), line z=…, max ground delta 0.3; complete=true`
    — once at boot and once per drive;
  * `[ForestTest] <name> placed as a <role> at (x, y, z), N studs from the road, stand <n>` — task
    153's line, kept, now printed from the drive's placement path;
  * `[report] drive <n> opened` — now from `Match.PhaseChanged`;
  * the existing `[wave]`, `[rest]` and horn lines, unchanged;
  * `Match.stats()`: `placementsMissed` must be 0, `boarsReleased` must be 0, `releasesDeferred` must
    be 0.

---

## 14. No feature flag, and the rollback

**Decision: no flag.** Brief decision 12 permits one and asks the design to decide.

1. The **place id is already the switch**, and a stricter one: every line of this change is either
   inside `ForestTestBoot` (which returns early in DEV) or behind an injected field DEV never passes.
   With nothing injected the code path is bit-identical, and that is provable by **identity**
   (`Match.config() == Match.CONFIG`) rather than by a flag read.
2. A flag would be a **second switch** for a thing the place already decides — Task 79's measured
   failure in miniature: *"a flag is one value for every place a build is served into"*. CLAUDE.md
   makes the world switch the written exception to the flag rule, by Director decision.
3. There is no honest `why` line for the row that the place id does not already answer.
4. The **rollback is a commit, and a small one**: `ForestTestBoot` drops `Match.start(...)` and
   restores `applyRole`, `startAt`'s placement and `noDriveLine`. Nothing in `Match` needs reverting
   — with no injection it is the DEV drive.
5. The A/B a flag would buy, Karen gets for free: while the marker set is incomplete the drive sits in
   `Waiting` and the ambient forest runs exactly as today. That is the degraded state, not a second
   build.

`Flags.MAX_FLAGS` is 12 with 9 declared, so this is not a capacity argument.

---

## 15. Deviations from the designs already written

| Document | What changes |
|---|---|
| `drive.md` **§3.5 "One composition root"** | There are **two**, one per world, and `ForestTestBoot` is the second — true for the boar since task 122, now true for the drive. `MatchBoot` is unchanged and remains DEV's |
| `drive.md` **§6.1 "The markers are tags, and the world of the day places them"** | "The world of the day places them" survives. "They are tags" gains an exception: a world may hand the set over through `world.markers` as **parts it built plus a line table**, with **no tags at all**. The table in §6.1 gains a third column for `forest-test` |
| `drive.md` **§6.2 `Markers`** | `Markers.read` is unchanged. An injected set may deviate from its completeness rule, and the two deviations are named and asserted (§4.1.4) |
| `drive.md` **§5.3 "What `Assigning` does"** | the order is unchanged; `Body.placementFor` may be replaced by `world.placement`, and `Body` is still the one writer |
| `drive.md` **§9.2** | `World` gains `config?` and `placement?`; `markers?` may be a function; `Match` gains `config()`, `mergeConfig`, `WORLD_OVERRIDABLE`, `requestTeam`; `Phase.Event` gains `kind = "team"` |
| `drive.md` **§3.4 "the rule numbers stay on the server"** | unchanged, and the allow-list (§4.2.3) is what keeps it true |
| `map-generator.md` **§17** | Its sentence *"`Map.EXPECTED_WORLD` is `"arena"` or `"map:v1"`"* is already stale: since task 122 it is `Map.WORLD_BY_PLACE[game.PlaceId] or Map.DEFAULT_WORLD`, and `"forest-test"` is a third value chosen by the **place id**, not by a committed string. §17's build-and-switch order applies to the generated map only |
| `beater-kit.md` **§9** | Its three-owner table **survives**: `ForestTest` owns the *request*, `Match.Body` owns what the player *is* and what they wear. What changes is step 2 and step 3 of "the wiring": the request reaches `Player.Team` through **`Match.requestTeam`**, never through a direct `Body.setTeam` at the boot, and `applyRole` is gone. §9's note that `boarThreats` reports every real player as `shooter` was already superseded by task 153; it now reads `Player.Team` |
| `boar-behaviour.md` **§8** | unchanged. `Match.boarThreats` and `ForestTest.boarThreats` remain **two implementations of one idea, one per world** — and this design deliberately does **not** merge them: the forest's list carries the wave phantoms, which `Match` knows nothing about, and `Match.quickTestPhantom` is Studio-only and off. Logged for a later audit, not fixed here |

---

## 16. Where the out-of-scope things attach (decision 13) — none of them built

| Thing | Where it attaches |
|---|---|
| **The 10-second stand timer as a drive PHASE** | a fifth phase in `Phase.luau` between `Assigning` and `Running` — `"Standing"`, `phaseEndsAt = now + STAND_SECONDS`, entered by `enterAssigning`'s successor and leaving to `enterRunning`. Its effects are `openPick` and `lockStands`, which the forest's `ForestTest.openPick`/`lockPick` already implement; the Hud keys on `snapshot.phase` as it already does for `Scoring`. One new phase, two new effects, no new owner |
| **The end-of-drive results scene** | nothing new on the server: `Scoring` exists, `SCORE_SECONDS` is 25, `HitLog.closeDrive` fires on it, and `Hud.renderScore` plus `Hud.ReportPanel` already key on `phase == "Scoring"`. It is a client scene over an existing phase |
| **Money** | a pure module beside `Score`, fed from `Match.Scored`; persistence is its own owner and not `Match`'s |
| **The weapon licence** | one more condition inside `Match.mayCarryWeapon`, which is already the one predicate both worlds ask |
| **Dogs** | a `world.dogs` runtime injected at each composition root, the shape `world.boars` is, with their own owner module |
| **Tying to a real trunk** | `ForestTest.Markers.build` fills `trees` from `ForestTest.nearestSolid` near each stand; `Body.anchorFor` already prefers `trees` and nothing else changes (§6.3) |

---

## 17. Open decisions

### Karen (feel)

1. **≈21 seconds from Play to standing on a stand** in the forest (§4.3.4). The fix is one number on
   the allow-list (`INTERMISSION_SECONDS`); the brief's start value is 20 s, so this ships as 20 and
   she says whether it is too long.
2. **Tied to her own stand, not to a tree** (§6.3). Her rule says tree. The start value is the post
   fallback; §16 says where the trunk version attaches.
3. **Up to five minutes tied** in a 300-second drive (`TIE_UNTIL_DRIVE_END = true`). She has accepted
   the rule as written; the number she would change is `DRIVE_SECONDS`.
4. **The rotation**: hunter, then beater, then hunter, every 300 s + 45 s of intermission and scoring.
   She asked for it on 2026-10-11; this is her chance to say the period is wrong.
5. **`DRIVE_SECONDS = 300`** for the forest (the brief's start value, from `ForestTest.DRIVE.seconds`).

### Director (scope)

6. **The drive bar reads `BOARS 0` during a forest drive**, because `boarsLeft` is
   `BOARS_PER_DRIVE − accounted` and the drive owes none; the wood is `ForestTest`'s. Cosmetic.
   Options: leave it, hide the counter when `BOARS_PER_DRIVE == 0`, or give the wire a different
   field. Not blocking; left as-is by this design.
7. **`MAX_PLAYERS = 16` against 9 stands.** Unreachable with a balanced split (≤ 8 shooters), so no
   change is proposed; the same question exists in DEV with 8 posts. Named so nobody discovers it.
8. **`ForestTest.drive` / `driveIndexAt` / `spawnPosition` lose their callers** (§7.2). Retain with a
   comment, or archive with a note (rule 7). The design forbids only the third option: leaving them
   silently uncalled.
9. **Two `boarThreats`, one per world** (§15, last row). Log-only; a later audit's call.

---

## 18. What I could not verify (rule 8)

1. **Nothing live.** Studio was not available in this run (`.agent-evidence/INDEX.md`:
   *"Roblox Studio is not available: harness claims can be checked only for consistency"*). Every
   claim here about the forest place's terrain, its `Session` tree folders, its ground heights and its
   trunk density is **quoted from the code comments that recorded those measurements** (task 153 for
   the 831 trees and the canopy rays, `ForestTest.groundAt` for y 140/149/196), not re-measured.
2. **The ≈21-second spawn-to-stand number is arithmetic**, not a stopwatch: 1 s marker read + 20 s
   intermission + one `MATCH_STEP_HZ` tick. It needs Karen's session to be real.
3. **Whether `Data.groundAt` and `terrainYAt` agree within 1 stud over the road lane** is the
   assumption the tolerance encodes. It is checked *at run time* and reported (`refused`,
   `lastMaxDelta`), so if it is wrong the console says so on the first boot rather than silently
   dropping stands. If all nine are refused in the real place, the drive sits in `Waiting` and the
   Hud says why — loud, not silent, and the number to move is `GROUND_TOLERANCE_STUDS`.
4. **The ioquake3 function names** in §11.5 (`SelectSpawnPoint`, `SelectRandomFurthestSpawnPoint`,
   `SelectInitialSpawnPoint` in `code/game/g_client.c`) are from the published source tree and were
   not opened during this run. The pattern they illustrate does not depend on the exact names.
5. **The DEV suite's exact check count** after the two new specs is not predicted here; the design
   asserts only that nothing existing goes red, and the harness's own line is the evidence.
6. **The one extra respawn** for a player whose request is honoured at `Running` (§5.2 item 5) is
   derived from `Body.place`'s `LoadCharacter` and the effect list, not observed.
