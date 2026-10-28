# The lobby shooting range

Task 298, phase A. Design to `reviews/task-298/BRIEF.md`, which overrides anything older in `docs/`,
`TASKS.md` or an earlier design. Note: `docs/research/2026-10-27-shooting-range.md`.

Every number here is either read off a cited symbol or arithmetic from one, shown. Nothing in this
document is measured in a running game: phase A cannot run one, and every place that needs a
measurement says so and names the instrument.

---

## 1. What the system must do

1. **Spots in the lobby.** Standing on one, a real `E` opens a menu.
2. **The menu picks the trial:** animal, pace (walk / trot / run), weapon (the four guns), cartridge
   (the loads that weapon really has), distance (~35 m first).
3. **The target is the real animal** — the real model, the real welded zone parts, the real gait —
   crossing a fixed lane left-to-right and back, direction alternating.
4. **One shooting path.** The same `Weapon` owner, the same `Ballistics`/`Flight`, the same claim
   checks, the same `HitLog`. A shot that lands differently on the range than in the hunt is a RANGE
   bug, by definition.
5. **A board:** shots, hits, the animal's own zones, miss, distance, and **the lead as TWO numbers**.
6. **Tuning the range IS tuning the game:** the shooting numbers live in ONE data file both read,
   turned live by a tool, and "implement in game" is one commit of that file.

### What it must NOT do

- **No second way to shoot.** It adds no remote that fires a gun, no second resolver, no second
  damage call, no second score. `Weapon` stays the only owner of a shot; `HitLog` stays
  *"THE ONE WRITER of who hit what, where, and did it die"* (`src/server/HitLog/init.luau` header).
- **No second writer of an animal's position.** The range issues a ROUTE and nothing else (§6).
- **No second writer of the mouse or the trigger.** It uses `Camera.Cursor` and `Weapon.Input`'s
  shipped tagged doors with the tag `"range"` (§7).
- **No money, no penalty, no licence gate, no drive counts.** It does not call `Economy`,
  `Match.Penalty`, `Match.Score` or `HitLog.openDrive`.
- **No Studio-made part.** Everything is built from code into one `Workspace` folder.
- **No relaxation of a security bound.** `CLAIM.LINE_TOLERANCE_STUDS` and
  `CLAIM.POSITION_TOLERANCE_STUDS` are not tunable and not reachable from the range
  (BRIEF, "WHAT IS REFUSED"). It also does not relax `Rules.unsafeLine`: a man who walks onto the
  lane makes the shot refuse, which is correct and is left alone.

---

## 2. Owners (CLAUDE.md rule 3). One writer each, named

| System | THE one writer | On disk | Reachable at |
|---|---|---|---|
| The range's geometry — every Instance under `Workspace.Range` | `ServerScriptService.Range.Build` | `src/server/Range/Build.luau` | called only by `Range`, its owner |
| The range's STATE — which trial each spot is running, the record of each trial | `ServerScriptService.Range` | `src/server/Range/init.luau` | `Range.start(world)`, `Range.onRequest` |
| The target's Instances and its CFrame | **`ServerScriptService.Boar.Body`, unchanged** (*"the only writer of a boar's Instances"*) | `src/server/Boar/Body.luau` | the range never touches a body |
| The target's decisions | **`ServerScriptService.Boar.Brain`, unchanged** | `src/server/Boar/Brain.luau` | — |
| The target's ROUTE (which point, at which speed) | `ServerScriptService.Range` | `src/server/Range/init.luau` | `Runtime:leadTo` (§6) |
| The range's data (names, words, lane arithmetic, option whitelists) | **nobody at run time.** Frozen data, edited by the Builder in git | `src/shared/Range/init.luau` | — |
| The menu's pixels, and the only sender of `RangeRequest` | `StarterPlayerScripts.Hud.RangePanel` | `src/client/Hud/RangePanel.luau` | `Hud` builds its Frame and feeds it facts |
| The board's pixels | `StarterPlayerScripts.Hud.RangeBoard` | `src/client/Hud/RangeBoard.luau` | ditto |
| The SHOOTING NUMBERS (the seven tunables) | **nobody at run time.** Frozen data: `src/shared/Shooting/numbers.json`, edited by the Builder in git or written by `tools/shot.py save` | `src/shared/Shooting/` | `Shooting.data()`, `Shooting.live()` |
| The live shooting override (`DHShooting` on `ReplicatedStorage.Shooting`) | `tools/shot.py`, **Edit or Play, never a game script** | `tools/shot.py` | — |
| A shot, its flight, its claim, its report | **`ServerScriptService.Weapon`, unchanged** | `src/server/Weapon/` | — |
| Who hit what, where, and did it die | **`ServerScriptService.HitLog`, unchanged** | `src/server/HitLog/` | — |

**The shooting path gains exactly one new PUBLISH and no new writer.** `Weapon` gains
`Weapon.ShotResolved` (§8.3), a third BindableEvent beside the shipped `Weapon.ShotFired` and
`Weapon.HitReported` (`src/server/Weapon/init.luau`, `hitSignal`/`shotSignal`). It publishes facts
`onShotLanded` already holds; it decides nothing and writes nothing.

Mirror these rows into `GAME_DESIGN.md` "System owners" in the same commit as the first code.

---

## 3. In which worlds the range is built, and what decides it

**A world has a range when, and only when, there is a row for it** — `Lobby.ANCHORS`' rule verbatim
(`src/shared/Lobby/init.luau`, `Lobby.anchorFor`), and for its stated reason: the answer is never
found by sniffing `Workspace`, *"a predicate like that lies the moment a run half-finishes"*
(`src/server/ArenaBoot.server.luau`).

```lua
Range.ANCHORS = {
    -- Karen's place. x/z are FILLED FROM A MEASUREMENT, not from this document (§4.2).
    -- MEASURED in step B6 (section 4.2's instrument, run in Edit and in Play).
    ["forest-test"] = { x = 2650, z = -3216, plate = false, downrange = -1, drawn = true },
    -- The DEV place, where the harness runs. Its own ground plate, clear of the generated map.
    ["map:v1"]      = { x = 1200, z = 0, y = 0, plate = true },
}
```

- **The exit line is NOT signed.** `Range.fieldFor`'s `exitZ` is south of the whole field for
  both rows, because `Brain:_outcome`'s despawn predicate is one-sided (section 5's field row,
  and the Director's 2026-10-28 decision on which way a wounded target runs).
- **`downrange` is the lane's direction along z, as DATA on the row** (step B6): `+1` is the DEV
  row's north, `-1` is Karen's south, through ONE arithmetic (`laneCentre`, `laneEnds`,
  `screenPosition`, `fieldFor`, each taking the sign) and never a branch on the world's name.
  Both arms are entered by parameter in `range.spec`. `drawn` is the same shape for the skin:
  Karen's place draws the animal, DEV keeps the grey box with its real welded zones.
- **`forest-test`** is where Karen plays, beside the lodge. `plate = false`: the shelf is read with
  the injected `groundAt` at build time and the range lays itself on the ground that is really
  there. The Y is deliberately absent — `Lobby.ANCHORS`' own words: *"a typed Y would be a guess
  that puts the lodge in the air or inside the hill."*
- **`map:v1` (DEV) IS A ROW, and that is what makes constraint 1 satisfiable.** The DEV place has no
  lobby at all: `Lobby.ANCHORS` has no `map:v1` row, so `Lobby.start` builds nothing there, and the
  trucks, the pads and the shop panel do not exist for the harness to drive. The range must be
  testable in DEV, so it builds its own world: `plate = true` means `Build` lays an anchored ground
  plate at `row.y` and the shelf is the plate's top — `TestArena.LAYOUT.ground`'s pattern, which
  needs no terrain, no raycast and no measured shelf. `x = 1200` is outside `Map.FIELD.bounds`
  (`maxX = 620`) and outside `Map.SIZE_STUDS / 2` = 1024, so it touches neither the drive corridor
  nor one generated prop.
- **There is no `arena` row.** `Map.EXPECTED_WORLD` is never `"arena"` in either live place.

**One code path, one row, two values.** `plate` is a DATA field, not a branch in the caller: `Build`
asks the row. Both branches are reachable in a spec by parameter, because `Build.build` takes its
parent, its anchor and its row as arguments (`Lobby.Build.build`'s own shape — `lobby.spec` builds a
whole lodge into `Instance.new("Folder")`).

### Who starts it

**ONE root, `src/server/RangeBoot.server.luau`, for every world that has a row** (steps B2 and B6;
this supersedes phase A's two roots, and the reason is in that file's header). It learns its world
the way `Lobby` does — `Map.EXPECTED_WORLD` through `Range.anchorFor` — so a new world is a ROW and
never a second wiring; it runs its own Heartbeat; and it keeps `MatchBoot` out of the diff, which is
what keeps a range task off the two-player gate (`TWO_PLAYER_PATHS`).

Neither root is a new concept and no owner requires another: `Range` requires neither `Match`,
`Lobby`, `ForestTest` nor `Boar`. Every fact it needs is injected (§8.1).

---

## 4. `TestArena` and `ArenaBoot`: the PATTERN is reused, the MODULES are not

**Verdict: reuse neither module. Reuse the pattern, and copy nothing by value.**

- `src/server/TestArena.luau` says in its own header that it *"is the only writer of
  Workspace.TestArena"*, and `src/server/ArenaBoot.server.luau` returns early unless
  `Map.EXPECTED_WORLD == "arena"` — which is true in neither live place. Calling `TestArena.build`
  would make a second writer of a folder whose one writer is named, and `TestArena` is still the
  map's **rollback** (`Map.EXPECTED_WORLD`'s comment, and map-generator design §17 step 9 archives it
  only after Karen accepts the map). Touching it risks the rollback for nothing.
- What IS reused is the pattern, and it is named in code and in the research note: *"world geometry
  built from code into ONE Workspace folder"*, *"every dimension of the arena is here"*
  (`TestArena.LAYOUT`), `makePart` with `Anchored = true` and **the parent set last** — *"one
  replication step for the whole arena"* (`TestArena.build`). `Range.Build` is written to that shape,
  with `Range.LAYOUT` as its one dimensions table, and takes its parent as an argument so a spec
  never writes `Workspace`.
- `Lobby.Build` is the second source of the pattern and of two measured lessons this range inherits:
  parts are **laid on the ground that is measured, not on the shelf the arithmetic predicts**
  (`src/server/Lobby/init.luau`, the `groundAt` seam's comment: without it four pads *"sat 0.17 studs
  UNDER the terrain"*), and `Terrain:FillBlock` writes **4-stud voxels**, so every terrain edge the
  range scrubs must land on a multiple of 4 (`Lobby.CONFIG.FIELD.PADS`, the `Gather` row).

`Range.Build` is its own file and NOT a function inside `Lobby.Build`: that module is already the one
writer of `Workspace.Lobby` and ~4,200 lines, and the range's lane, target and board are not the
lodge's. One folder, one writer, each.

### 4.1 `Range.LAYOUT` — the first values

Every dimension in one table, read by `Build`, which invents none (`Lobby.CONFIG`'s rule). Offsets
are relative to the anchor, `+x` east, `+z` north, Y from the shelf.

| Field | Value | Where it comes from |
|---|---|---|
| `folderName` | `"Range"` | the stage block's `targetFolder` (§11.3) |
| `DISTANCE_STUDS` | `125` | 35 m at `Report.CONFIG.METRES_PER_STUD` 0.28. 89 (25 m) and 179 (50 m) are rows for later |
| `WINDOW_STUDS` | `40` | 11.2 m: crossing 8.9 / 3.64 / 1.67 s at the three paces (§13) |
| `APRON_STUDS` | `20` each end | room to turn around behind a screen. **A first value, confirmed by the measured crossing time** (TARGET 3), not a measurement |
| `SCREEN` | 2 parts, 10 x 8 x 1, at `±(WINDOW/2 + APRON)` | ISSF hides the turn-around; a visible 180° turn is not a crossing animal |
| `BERM` | 160 x 10 x 6, 12 studs behind the lane | a real range's backstop, and it stops a stray slug leaving the lobby |
| `MAT` | 8 x 1 x 8 at the spot | the firing position. **Parented FIRST** (§11.3) |
| `SPOT_COUNT` | `1` first cut (decision 6); `SPOT_SPACING_STUDS` 24 for later | — |
| `PLATE` | span `max(WINDOW + 2*APRON, 120) + 80`, thickness 4 | DEV only (`plate = true`) |
| `PROMPT` | `ActionText = "RANGE"`, `ObjectText = "SHOOTING RANGE"`, `MaxActivationDistance = 12`, `HoldDuration = 0` | `Lobby.Build`'s `shopPrompt` shape |

The lane runs along **x** and the shooter looks along **+z** or **-z**: one axis for the crossing, one
for the range, so `Ballistics.leadStuds` and the measured crossing are about perpendicular directions
and neither contaminates the other.

### 4.2 The forest anchor is MEASURED in phase B, step 1, before a line of Build is written

This is `Lobby.ANCHORS`' own precedent: *"a raycast grid over fifteen 160 x 160 footprints"*, and the
chosen centre had *"the smallest ground spread (16 studs)"*. The range's footprint is
`(WINDOW + 2*APRON + 80) x (DISTANCE + 60)` = **160 x 185 studs**, and it must satisfy, measured:

1. zero non-terrain obstacles over the footprint (the lane must be clear of Karen's trees);
2. ground spread inside the fill's own depth and clearance, as `Lobby.CONFIG.FIELD` uses them;
3. every terrain edge the range scrubs on a multiple of 4 (§4);
4. the firing line clear of `Lobby.CONFIG.FIELD.PADS` (`Yard`, `Road`, `Gather`), of the four truck
   pads, of the porch and of the lodge — `tests/server/lobby.spec.luau` already holds seven lobby
   pieces to that rectangle and the range is the eighth;
5. the lane's downrange direction pointing **away from** the lodge, the pads and the gathering yard,
   so `Match.lineIsUnsafe` refuses nothing a player standing in the yard is doing. The range does not
   relax that rule and must not need to.

The instrument is the one task 177 used: a raycast grid over candidate footprints, in Karen's own
place, reported as numbers. **Which side of the lodge** is Karen's taste, not arithmetic (§15).

---

## 5. Why the range has its own `Boar` runtime, and what it must NOT be

**It has its own `Boar.newRuntime`, with its own field and its own folder. It does not borrow the
drive's.** Three measured reasons:

1. **The lobby is outside the drive's field, and an animal there is deleted on the first step.**
   `ForestTest.boundsOf(ROAD_LAYOUT)` is `x 2230..3830, z -2477..-1197` and `exitZ` is `-2377`
   (`src/shared/ForestTest/init.luau`, asserted by `tests/server/forest_stand.spec.luau`). The lobby
   anchor is `(2850, -2950)` (`Lobby.ANCHORS`). `Brain:_outcome` returns `"outOfBounds"` for
   `position.Z < bounds.minZ - slack` and `"escaped"` for an **ordered** animal at or past `exitZ` —
   the range target is ordered by construction (§6), so both tests fire.
2. **`Runtime:setField` is the wrong tool and says so.** Its header: *"AN ALREADY-SPAWNED BOAR KEEPS
   THE FIELD IT WAS BORN WITH"*, and *"THE FOREST IS THE ONLY CALLER"*. Swapping the drive's field
   per range spawn from outside would be a second writer of the drive's field.
3. One runtime per field is the shape the module already supports:
   `Boar.newRuntime(world)` clones the config per runtime (`self._config = table.clone(Boar.CONFIG)`,
   with `MODEL`, `SENSE` and `KINDS` merged key by key), `world.folderName` is per world table
   (`Boar.defaultWorld`: `folderName = "Boars"`), and `Runtime:run()` connects its own Heartbeat.

### The range runtime's world, built by the composition root

| Field | Value | Why |
|---|---|---|
| `folderName` | `"RangeTargets"` | its own folder. `Workspace.Boars` keeps one writer |
| `field` | `Range.fieldFor(anchor, LAYOUT, downrange)` — the lane's rectangle plus 60 studs of slack, `exitZ` 400 studs SOUTH OF THE WHOLE FIELD (`math.min(nearZ, farZ) - 400`), `groundY` = the shelf | an exit the target can never reach, so nothing despawns mid-crossing. **It is NOT signed with `downrange`** (step B6, round 3): `Brain:_outcome`'s test is `position.Z <= field.exitZ` and its direction is not a parameter, so a signed exit put Karen's line north of her lane and despawned every ordered target on the first order. **Director's decision, 2026-10-28:** a wounded target at a range therefore flees DOWNRANGE into the berm (`Brain:_flee` heads for `exitZ`) — which is wanted: nothing ever runs back over the firing line |
| `threats` | `function() return {} end` | **nobody is a threat at a range.** With the shipped `defaultWorld.threats`, `Brain.perceive` would see the shooter 125 studs away (`SENSE` notices a moving person at 60) and the target would flee the lane |
| `config.LINE.ENABLED` | `true` | **required in both worlds:** `Brain:leadTo` returns false when `LINE.ENABLED ~= true` |
| `config.SENSE.ENABLED` | `false` | belt to the `threats` brace: the lane is a route, not a reaction |
| `config.maxBoars` | `Range.CONFIG.MAX_TARGETS` = `SPOT_COUNT` | one target per spot, never a sounder |
| `config.MODEL`, `KINDS`, `PACE`, `MOVE` | **the clones the root already built.** `ForestTestBoot` reuses its own `model`/`calm`/`pace`/`move` locals; `MatchBoot` passes the DEV defaults | the gait band is `model.RUN_FROM = (TROT_SPEED + pace.RUN_SPEED) / 2`, already computed there. One answer per world to "what does an animal look like here" |

**The composition root does NOT wire `Weapon.ShotFired` to the range runtime's `hearShot`.** In the
drive a shot is a sound every boar runs from (`MatchBoot`, `ForestTestBoot`); at a range that would
make the target bolt off the lane on the first shot. Not wiring it is the whole mechanism — no branch,
no flag, no new state.

**What the target looks like, per world, with no range-specific branch:** in Karen's place
`BoarAssetsBoot` has already set the module-level model source (`Boar.setModelSource`), so the range
target is the same drawn, animated animal the drive uses. In DEV, `Boar.CONFIG.MODEL.ENABLED` is
false and `Map.PLAYTEST_WORLD` is false, so no mesh is loaded and the target is the grey box **with
its real welded zone parts** — which is exactly what every `tests/server/weapon_*.spec.luau` and
`tests/client/shoot_boar.spec.luau` already shoot at. The zones are the same parts in both worlds;
only the skin differs.

---

## 6. The seam by which the range commands a pace and a lane

**The range owns the ROUTE. `Brain` decides, `Body` writes. There is no second CFrame writer.**

The seam is the shipped `Runtime:leadTo(id, point, speed)` (`src/server/Boar/init.luau`), whose own
header is the contract: *"WALK TO THIS POINT AT THIS SPEED, through the same door as `urge`, `spook`
and `check`. The drive re-issues it every step; it expires by itself."* The shipped caller is
`ForestTest`'s line (`src/server/ForestTest/init.luau`, `leadIfFree` → `runtime:leadTo`), and its
header states the division this range copies word for word: *"The Brain's job is unchanged and is one
sentence: walk to the point you were given at the speed you were given (`Brain:leadTo`). Everything
below decides WHICH point."*

So `Range.step(dt)`, at `Range.CONFIG.STEP_HZ` (10), for each live trial:

1. reads the target with `Runtime:statusOf(id)` — position, real speed, the speed it was asked for,
   alive;
2. advances the lane leg when the target is within `WAYPOINT_STUDS` (6, the drive's own number) of
   the current end, and **flips the direction** — ISSF's mandatory change, and the range's reason to
   exist in one line (research note source A: *"a lane that only ever runs one way trains one lead"*);
3. re-issues `leadTo(id, laneEnd, speed)`, skipping an animal `Runtime:flying(id)` reports — the
   guard `leadIfFree` exists for, kept here for its stated reason: *"the drive must not order an
   animal the Brain is flying, whoever adds the next way into `live`"*;
4. counts crossings, and publishes the measured crossing seconds to the board (TARGET 3).

**Which pace is how many studs per second has ONE answer in the repository, and this task moves it to
where both readers can reach it.** It exists today as `ForestTest.paceSpeed(pace, config)` —
*"what that pace is in studs per second, in the BOAR's own numbers rather than new ones"* — on the
forest world's owner, which a range that also runs in DEV must not require. It moves to
**`Boar.paceSpeed(pace, config)`**, pure, beside `Boar.gaitBands` and `Boar.scaledByWary`, taking the
config as its argument exactly as it does now; `ForestTest.paceSpeed` becomes a one-line delegation,
so its callers and its spec are untouched (`ForestTest` already requires `Boar`). The range reads
`Boar.paceSpeed(pace, runtimeConfig)` and **invents no speed**: `WALK_SPEED` 4.5, `TROT_SPEED` 11,
`RUN_SPEED` 24 (`Boar.CONFIG.PACE`).

**Death is the hunt's, not the range's.** A lethal hit kills the target through
`Weapon.HitReported → Runtime:takeHit → Boar.Wound`, unchanged — that is decision 3. `Range.step`
sees `statusOf(id).alive == false`, holds the carcass for `CARCASS_SECONDS` (3) so the player sees
what he did, then calls the runtime's `clear` and releases a fresh target after
`RELEASE_SECONDS` (2). The range adds no "invulnerable" mode, because an invulnerable target is a
different shooting path (§15, open decision 5).

---

## 7. The menu

### 7.1 The two doors, by their shipped names

Both are already solved, in shipped code with a shipped caller, and the range uses them with the tag
`"range"` and adds no mechanism (BRIEF constraint 5):

- `Camera.Cursor` (`src/client/Camera/Cursor.luau`) is *"THE ONLY WRITER of
  UserInputService.MouseBehavior, .MouseIconEnabled, .MouseDeltaSensitivity and Mouse.Icon"*.
  `Cursor.requestFree("range")` on open, `Cursor.release("range")` on close. `Cursor.apply()` is the
  one per-frame writer and `Cursor.stats().reasserts` must stay 0.
- `Weapon.Input` (`src/client/Weapon/Input.luau`): `Input.requestHold("range")` /
  `Input.releaseHold("range")`. The four `ContextActionService` bindings (`FIRE` MouseButton1,
  `RELOAD` R, `SELECT_AMMO` X, `AIM` MouseButton2) stay bound and still return `Pass`, and act on
  nothing while a hold is out.
- The shipped caller that holds both at once is `Hud.ShopPanel.setOpen`
  (`src/client/Hud/ShopPanel.luau`): `Cursor.requestFree("shop")` plus
  `WeaponInput.requestHold("shop")`, released by tag on close. `RangePanel.setOpen` is that function
  with one word changed.
- **`GuiButton.Modal` is not used.** `src/client/Weapon/Input.luau`'s own header refuses it as a
  second writer of `MouseBehavior`.

### 7.2 The prompt

`Range.Build` builds one `ProximityPrompt` per spot — **since task 303 on a `Post` at the mat's
front edge, on a `RangePromptAt` attachment at its top, and no longer on the mat.** A prompt is
drawn only while its own position is on screen, so one lying on the 8x8 mat was invisible whenever
she looked down the lane and `E` did nothing (the Director's real-key proof, 2026-10-28).
`Range.promptPosition` is the one arithmetic for that point, `Range.promptPointOf` reads it back off
a built prompt, and `Range.atSpot` is asked about THAT point rather than the mat's, so the engine's
reach and the client's "is he at the spot" are one measurement. From `LAYOUT.PROMPT` — the shape
`Lobby.Build`'s `shopPrompt` already has, and for its measured reason: the prompt hangs on the
**part**, not on a body, because *"the clip that stops a player jumping the counter cannot be made
invisible to a ray (measured), so a prompt behind it is a shop nobody can open."*

The client reaches it the way the shop does: `Hud.step` finds it (`Range.Data.promptFor(index)`,
`Lobby.Data.shopPrompt`'s shape — by NAME anywhere under `Workspace.Range`) and hands it over with
`RangePanel.setPrompt(prompt)`, which is **edge-triggered on the Instance** and accepts *"anything
carrying a `Triggered` signal"*. That seam is not laxity and `ShopPanel.setPrompt` says why: *"a spec
cannot fire a real `ProximityPrompt`"* (§11.3 takes that at its word).

### 7.3 The option lists, and where each list's values come from

No list is typed in the panel. Every row is read from the thing it is about.

| Option | The values | Read from |
|---|---|---|
| Animal | `boar` first; `reddeer` when its rig allows | `Boar.CONFIG.SPECIES` keys, filtered by `Range.CONFIG.SPECIES_ALLOWED` |
| Kind | the species' own kinds (`male`, `female`, `cub`, `stag`, `hind`, `calf`) | `Boar.CONFIG.KINDS.ORDER` |
| Pace | `walk` / `trot` / `run` | `Boar.CONFIG.PACE.{WALK,TROT,RUN}_SPEED` through `Boar.paceSpeed` |
| Weapon | the four | `Weapons.ORDER` = `{ "shotgun", "rifle", "lever", "semiauto" }` |
| Cartridge | the loads **that weapon really has** | `Weapons.row(id).AMMO_KINDS`, labelled with `.AMMO_LABEL` — the same pair the Hud's ammo chip reads |
| Distance | `125` first; `89` / `179` later | `Range.CONFIG.DISTANCES_STUDS` |

The server sends the lists to the client as part of the range's state, and the whitelist that accepts
a pick is **one pure function read by both sides** — `Lobby.roleAllowed`'s rule: *"the server's door
asks it of a payload and the client's sender asks it of its own argument, so 'which words are legal'
has one answer."*

### 7.4 Who holds a gun at a range: the THREE relaxations and the loan, as shipped (step B6)

In Karen's place a man standing in the lobby is not in the drive, so today he **carries no gun and
his trigger is dead**. Measured from the shipped wiring in `src/server/ForestTestBoot.server.luau`:

| Gate | Shipped provider | At a range spot |
|---|---|---|
| arming | `Weapon.setArmingPolicy(Match.mayCarryWeapon)` | **must relax.** Not a participant → no Tool at all |
| drive open | `Weapon.setDriveOpenProvider(Match.driveOpen)` | **must relax.** `Rules.driveClosed` refuses the trigger between drives |
| off-stand | `Weapon.setStandProvider(Match.standAreaFor)` | **must relax (MEASURED, step B3 round 3).** Phase A read `Rules.outsideStand`'s *"NO AREA MEANS NO RULE"* and said no change — but in Karen's world `Match.standAreaFor` hands back the DRIVE's stand, a real area far away, so it refused every shot on the mat. `Range.standOver` is the third relaxation |
| the beater in the ray | `Weapon.setTargetProvider(Match.classifyTarget)` | no change. A boar is not a beater |
| licence | not wired for a boar | no change |
| the safety line | `Weapon.setSafetyLineProvider(Match.lineIsUnsafe)` | **no change, deliberately.** A man on the lane refuses the shot, as he should |

So the range publishes **ONE predicate**, `Range.mayShoot(player): boolean` — true only for a player
whose character the SERVER measures standing on a spot's mat, in a world where the range is built —
and **`Range.installOver(armFallback)` is the installer** (task 301): it builds the four wrappers
`Range.armingOver`, `Range.driveOpenOver`, `Range.entitlementOver` and `Range.standOver`, installs
each over whatever that world already wired, **keeps the base each setter hands back** —
`Weapon.setStandProvider` hands one back since task 301 — and returns the uninstall that puts all
four back. The body lives in the module and NOT in the composition root, so a spec drives the real
composition instead of a copy, and a copy could not see that `setStandProvider` returned nothing
(`reviews/task-298/RESULT.md` findings 1 and 2). **`RangeBoot` is the ONE caller**, once, on the
first Heartbeat. The two providers phase A named are four:

```lua
Weapon.setArmingPolicy(function(player)
    return Match.mayCarryWeapon(player) or Range.mayShoot(player)
end)
Weapon.setDriveOpenProvider(function(player)
    return Range.mayShoot(player) or Match.driveOpen()
end)
Weapon.setEntitlementProvider(...)   -- the loan: all four guns, on the mat only
Weapon.setStandProvider(...)         -- the THIRD relaxation
```

`setDriveOpenProvider`'s provider is `(() -> boolean?)` today and its own comment says *"It takes no
`Player` ... the drive is on or it is not, for everybody at once"*. **Once a range exists that
sentence is false**, so the seam becomes `((Player?) -> boolean?)` and `askDriveOpen(player)` passes
the player it already has in scope (`src/server/Weapon/init.luau`, `askDriveOpen` and its one call
site in the fire path: `driveOpen = askDriveOpen()`). The shipped `Match.driveOpen` ignores the extra
argument, so **every existing caller and every `weapon_*.spec` is bit-for-bit unchanged**, and an
unwired provider still means "no restriction".

This is one gate, not two: the WEAPON still decides and still refuses, which is
`docs/research/2026-10-13-the-rules.md`'s own pattern (*"the drive answers, the WEAPON refuses"*) with
a second thing that may answer.

**Which guns the range lends** is one line, and the default stated here is: at a spot, all four,
whatever the player owns — through `Weapon.setEntitlementProvider`'s existing composition at the
root. The reason is the task: three of the seven dials cannot be judged at all with a gun Karen has
not bought. It never follows him into a drive, because `Range.mayShoot` is false the moment he steps
off the mat and `Weapon.refreshArming` re-asks on its own 2 s sweep (`ARMING_SWEEP_SECONDS`). Karen's
to overrule (§15, open decision 1).

---

## 8. Interfaces, with types

### 8.1 `ServerScriptService.Range` (`src/server/Range/init.luau`)

Nothing happens on require — the rule `Match`, `Boar`, `Weapon`, `Lobby` and `Economy` all follow.

```lua
type Trial = {
    spot: number,
    species: string,     -- "boar"
    kind: string,        -- "male"
    pace: string,        -- "walk" | "trot" | "run"
    speedStudsPerSecond: number,  -- Boar.paceSpeed(pace, config)
    weapon: string,      -- a Weapons.WeaponId
    ammo: string,        -- a row of that weapon's AMMO_KINDS
    distanceStuds: number,
}

type Seams = {
    enabled: boolean,                      -- the RANGE flag, read ONCE at the root and passed in
    world: string?,                        -- Map.EXPECTED_WORLD
    root: Instance?,                       -- default Workspace; a spec passes a Folder
    anchor: { x: number, z: number, y: number?, plate: boolean? }?,  -- default Range.anchorFor(world)
    groundAt: ((number, number) -> number?)?,   -- the world's ONE ground reader
    terrain: Terrain?,                     -- an argument, so no spec writes a place's terrain
    -- the animals: a NARROW VIEW of one Boar runtime, injected (ForestTest.readOnlyBoars' shape)
    boars: {
        spawn: (position: Vector3, kind: string?) -> { id: string }?,
        clear: (reason: string?) -> (),
        statusOf: (id: string) -> { position: Vector3, speed: number, want: number, alive: boolean }?,
        leadTo: (id: string, point: Vector3, speed: number) -> boolean,
        flying: (id: string) -> boolean,
        configOf: () -> any,               -- that runtime's merged config, for PACE and ZONES
    }?,
    remotes: { RangeRequest: RemoteEvent, RangeBoard: RemoteEvent }?,
    now: (() -> number)?,
}

Range.ENABLED: boolean            -- Flags.isOn("RANGE"), the ONE boundary read
Range.LAYOUT, Range.CONFIG        -- frozen
Range.Build                       -- re-exported for the specs, as Lobby re-exports Join/Pads/Field
Range.start(seams: Seams): boolean    -- false when there is no row, no flag or no seam
Range.stop()                          -- hands back exactly what it wrote
Range.step(dt: number)                -- called by the root's existing Heartbeat, throttled to STEP_HZ
Range.isBuilt(): boolean
Range.mayShoot(player: any): boolean  -- §7.4. Pure in its measurement: the server's own position read
Range.spotAt(position: Vector3?): number?   -- pure, exported, the one arithmetic for "which mat"
Range.onRequest(player: any, request: any)  -- the ONE inbound door (§8.2)
Range.trialOf(spot: number): Trial?         -- a COPY
Range.recordOf(player: any): Record?        -- a COPY (§9)
Range.stats(): { [string]: any }
```

`Range.start` **has no clock of its own**: `Range.step` is one more call in the Heartbeat the root
already runs, throttled in here — `Lobby`'s stated rule (*"A second clock would be a second answer to
'what time is it'"*).

### 8.2 Remotes — `ReplicatedStorage.Range.Remotes` (`src/shared/Range/Remotes.model.json`)

Two, both narrow, each answering one question.

- **`RangeRequest` (client → server)**, the range's only inbound door, built in `Shop.onRequest`'s
  and `Lobby.onPadRequest`'s shape: public so a spec drives it by parameter, rate-limited per player
  (`Range.CONFIG.REQUEST_MIN_INTERVAL`, its own bucket), every fact measured off the character the
  SERVER can see, and a forged payload counted apart from a legal request the game said no to
  (`stats.badRequests` vs `stats.refusedBy`).
  `{ spot: number, species: string?, kind: string?, pace: string?, weapon: string?, ammo: string?, distanceStuds: number?, go: boolean? }`
  **Nothing a client sends can spawn an animal into the drive, write a score, or move a target:** the
  most a pick can do is choose which trial THIS spot runs, and only while that client's character is
  measured on that mat.
- **`RangeBoard` (server → client, `FireClient`)**, one payload per shot plus one on every trial
  change. The board is a renderer; the record is the server's (§9).

### 8.3 `Weapon.ShotResolved` — the one addition to the shooting path

```lua
-- ({ shooter: Player?, shooterUserId: number, weapon: string?, ammo: string,
--    muzzle: Vector3, reachedStuds: number, endPoint: Vector3, firedAt: number,
--    resolvedAtServerTime: number, hitParts: { Instance } })
Weapon.ShotResolved = resolvedSignal.Event
```

Published once in `onShotLanded` (`src/server/Weapon/init.luau`), from facts that function already
holds: `Flight.Resolution` is `{ shot: ShotRecord, impacts: { Impact }, reachedStuds: number }`, and
`ShotRecord` carries `shooterUserId`, `weapon`, `ammo`, `muzzle`, `rangeStuds` and `firedAt`.
`resolvedAtServerTime` is `Workspace:GetServerTimeNow()` taken in that same function, which is what
lets the range rewind its own target to the arrival instant (§9.2).

**Why this and not the range re-deriving it.** A MISS produces no `Weapon.HitReported` — that signal
is per hit — and `Weapon.ShotFired` fires at the trigger, up to 0.365 s before the bullet lands
(`stats.shotsResolved`' own comment: *"`shots` ... now LEADS `shotsResolved` by up to 0.365 s, and
that gap is the instrument for 'a shot that never landed'"*). A range that inferred a miss from the
absence of a hit inside a timeout would be a **second answer** to "did that shot hit", which is this
project's named failure mode. One publish, from the one place that knows, is the cheap and honest
version. Its one listener is `Range`, wired at the composition root; neither owner requires the other.

### 8.4 `ReplicatedStorage.Range` (`src/shared/Range/init.luau`)

Frozen data and pure arithmetic, no Instances, required by both sides so a SERVER spec drives it with
no client (the `ReplicatedStorage.Lobby` / `ReplicatedStorage.ForestTest` shape).

```lua
Range.FOLDER_NAME, Range.MAT_NAME, Range.PROMPT_NAME, Range.REMOTES_NAME
Range.WORD = { WALK = "walk", TROT = "trot", RUN = "run" }   -- they cross the wire: ONE spelling
Range.paceAllowed(word: any): boolean          -- the ONE whitelist, both sides (Lobby.roleAllowed)
Range.optionAllowed(kind: string, value: any): boolean
Range.anchorFor(world: string?): Anchor?       -- pure, takes the world as a STRING, requires nothing
Range.laneEnds(anchor: Vector3, layout, leg: number, downrange: number?): Vector3   -- the ONE lane arithmetic
Range.matPosition(anchor: Vector3, spot: number, layout): Vector3
Range.crossingSeconds(windowStuds: number, speed: number): number
Range.promptFor(spot: number): ProximityPrompt?  -- found by NAME under Workspace.Range
```

The mats' positions have **one** definition — this function — and `Build` places the parts with the
same call. That is task 182's lesson quoted in `Lobby`: the circle's position was computed
`anchor + cfg.SPOT.OFFSET` *"in two files"*.

### 8.5 The client panels

```lua
RangePanel.start(frame: Frame, seams: { remotes: any?, send: ((any) -> ())? })
RangePanel.setPrompt(prompt: any)            -- edge-triggered on the Instance
RangePanel.setNear(near: boolean)            -- only ever CLOSES, ShopPanel.setNear's rule
RangePanel.setState(state: any)              -- the server's lists and the live trial
RangePanel.setOpen(open: boolean)            -- the two doors, by tag "range"
RangePanel.isOpen(): boolean
RangePanel.select(option: string, value: any)
RangePanel.confirm(): boolean                -- sends { go = true }; nothing else sends
RangePanel.rowRect(option: string, index: number): (Vector2, Vector2)  -- for §11.3
RangePanel.rowText(): { string }             -- what a spec reads instead of a screenshot
RangeBoard.setRecord(record: any)
RangeBoard.rowText(): { string }
RangeBoard.isVisible(): boolean
```

`Hud.init` creates both Frames with the panels' own pure size functions and `Hud.step` feeds them
facts once a frame — `ShopPanel` and `PadPanel`'s exact arrangement (`src/client/Hud/init.luau`:
`shop.Size = ShopPanel.panelSize()`, `ShopPanel.setNear(...)`, `PadPanel.setAsk(...)`).

---

## 9. The board

### 9.1 Columns

**The zone columns are the ANIMAL's own, and the BRIEF's fixed list would be wrong for both animals.**
Measured: `Boar.CONFIG.ZONES.ORDER` is `{ "head", "chest", "body", "rear", "legs" }` and
`Boar.CONFIG.SPECIES.reddeer.ZONES.ORDER` is `{ "head", "neck", "chest", "body", "rear", "legs" }`
(`src/server/Boar/init.luau`). A hard-coded `head / neck / chest / body` board would print an
always-zero `neck` for a boar and would hide `rear` and `legs`, which are the two most common
non-lethal hits and the ones a range exists to show. So the board reads the order from the config the
target was spawned with (`seams.boars.configOf().ZONES.ORDER`, through `Boar.speciesConfig`) and
appends MISS.

| Column | Value | Measured by |
|---|---|---|
| SHOTS | accepted trigger pulls at this spot | `Range`, counting `Weapon.ShotResolved` for this player |
| HITS | shots with at least one zone part struck | `Weapon.HitReported`, which is *"one report per (shot, target)"* |
| per zone | one column per `ZONES.ORDER` entry | `report.zone` — the server's own geometric answer, nothing re-derived |
| MISS | SHOTS − HITS | arithmetic |
| DISTANCE | `report.nearest`, else the trial's `distanceStuds` | `Weapon.Hits.group` |
| PACE | the word and the measured crossing seconds | `Range.step` off the target's own position samples |
| LEAD BALLISTIC | §9.2 | `Ballistics.leadStuds` |
| LEAD VIEW | §9.2 | the accepted claim, or the window as a bound |

The existing feedback is untouched and not duplicated: `Hud.HitCard` and the kill toast keep drawing
what they draw, from the wire they already read.

### 9.2 The lead is TWO numbers, and each names who measured it

At 125 studs the arithmetic says the clock dominates the ballistics, so one number would blame the
ballistics for a clock (BRIEF; research note TARGET 1):

| Load | flight to 125 studs | ballistic lead at run (24 studs/s) | of a 5.5-stud body |
|---|---|---|---|
| .416 Rigby | 0.049 s | 1.18 studs = 33 cm | 0.21 |
| .45-70 lever | 0.058 s | 1.39 studs = 39 cm | 0.25 |
| 12 ga slug | 0.076 s | 1.83 studs = 51 cm | 0.33 |
| 12 ga 00 buck | 0.103 s | 2.46 studs = 69 cm | 0.45 |

`VIEW_LAG_BASE_SECONDS` 0.30 s at 24 studs/s is **7.2 studs** — three to six times the whole
ballistic lead, and 1.3 body lengths.

- **LEAD BALLISTIC** = `Ballistics.leadStuds(shot, distanceStuds, trial.speedStudsPerSecond)`, where
  `shot = Ballistics.shotFor(Weapons.row(trial.weapon), trial.ammo)`. **Measured by `Range`,
  computed by the shipped function** whose header says it exists for exactly this: *"the sentence
  Karen asked for written as arithmetic ... not from a number typed twice."* Always available, hit or
  miss.
- **LEAD VIEW** = `trial.speedStudsPerSecond * viewLagSeconds`, and `viewLagSeconds` has two sources
  which the board **labels differently**:
  - on an accepted claim, the instant the server's own sweep chose — the measured lag, which
    `Weapon` already computes and publishes as `stats.claimWorstLagSeconds` and
    `stats.claimLastDisplacement`. For a per-shot number it is carried on the shot's own report (one
    field pair on `Weapon.HitReported` / `ShotResolved`: `viewLagSeconds`, `viewOffsetStuds`), not a
    second measurement;
  - otherwise — a miss, a refused claim, a server with `HIT_CLAIM` off — the configured WINDOW
    `Weapon.viewWindowFor(player)` = `clamp(VIEW_LAG_BASE_SECONDS + ping * FLIGHT_CATCHUP_PING_FACTOR,
    0, VIEW_LAG_MAX_SECONDS)`, printed as a **bound** (`≤`) and never as a measurement.
- **And for a MISS, the signed along-track gap** — source E's idea, and the one number that teaches a
  lead in one shot: `Range` takes `endPoint` off `Weapon.ShotResolved`, rewinds its own target with
  its own runtime (`Runtime:cframeAt(trunk, resolvedAtServerTime)`, *"THE ONE READER of the ring"*),
  and projects the difference onto the target's velocity: **`-0.9 studs BEHIND`** or `+1.4 AHEAD`.
  The range owns this arithmetic because the weapon must not learn what a range is; it reads only
  facts the weapon already publishes.

### 9.3 The record is the SERVER's and the board is a renderer

The server sees the accepted shot and its resolution in order, in one place, and only the server can
measure the view lag at all. So `Range` is the one writer of the range's record and publishes it on
`RangeBoard`; `RangeBoard.luau` draws what it is sent and holds no opinion — the arrangement
`src/shared/Lobby/init.luau` states for every attribute it owns (*"the card lights the half the
server says, never the half it asked for"*) and `Shop.Remotes.ShopState`'s shape.

**It adds no source of truth.** Every zone on it is `report.zone`, which `HitLog.recordHit` is fed
from the same signal in the same frame; the range's tally is a derived view of the same reports, per
player, per trial, and is thrown away when the trial ends. `HitLog.openDrive` is never called and no
drive row is written.

### 9.4 The board is a PAGE OF THE MENU, and the hit card is what she reads while shooting (task 304)

Karen, 2026-10-28, playing the range with the board over the left third of her view: *"if you remove
this shit will be good I will see where I hit / and hit card will be usefull"*. Measured on `main`
at `aed230ef`: `Hud.RangeBoard` was 380 x 300 at absolute (16, 188) of her 969 x 792 viewport and
stayed `Visible` the whole time she stood on the mat.

**The numbers are not deleted; they move into the E panel.** Two decisions, stated:

1. **`RangeBoard.luau` STAYS THE ONE WRITER** of its own frame, its children and its `Visible`.
   `RangePanel` gains nothing. The record arrives here, the columns, the two lead numbers, the miss
   gap and RESET are already formatted here, and moving them would make two renderers of one
   record — the thing 9.3 exists to prevent. What changed is only *when* and *where* it draws:
   `RangeBoard.setMenuOpen(open)` is told by `Hud.step` (the "a panel that is TOLD" idiom `setNear`
   and `ShopPanel.setNear` already follow), and `render` writes `Visible = menuOpen`. Not
   `record ~= nil`: with the menu open and no shot fired `rowText` says *"no shots yet"*, which is
   the honest page.
2. **It is drawn inside the menu's own footprint.** `Hud` anchors the frame to the SAME screen
   centre the 560 x 640 panel is anchored to, at the panel's interior (12, 444) — screen centre
   plus (-268, +124) — 536 x 192, in the band the menu leaves free below its hint. A sibling and
   not a child, because `RangePanel.build` destroys every child of its own frame; and at
   `RangePanel.LOOK.Z_INDEX + 3`, because `ZIndexBehavior.Sibling` compares a child's ZIndex
   globally and the menu's children draw at 15 and 16.

**Every range hit shows the hunt's own hit card, and nothing is scored.** `HitLog.sendCard(report)`
is `recordHit`'s own `buildCard` plus `toShooter` and nothing else: the same `Report.CardPayload`,
the same `Shape.cardDots` projection off the trunk's CFrame at the instant of the hit, the same
`ReportEvent` to that one player. It writes no drive row, no dot, no kill line, no hit-log line and
no money. `Range` holds the sender as an injected seam (`Range.setCardSender`, `RangeBoot` wires
`HitLog.sendCard`), so this module still requires no owner. `drive` and `at` go out as 0 because
there is no drive, and the card's client reads neither.

**And a lane hit is not a row, in any world.** `HitLog.rowWorthy(part)` — `not
RangeData.isTarget(part)`, one ancestor read for `RangeData.TARGETS_FOLDER`, the folder `RangeBoot`
names its runtime's world with — refuses one at the top of `recordHit`, and counts it as
`stats.rangeHits`. It lives in `HitLog` and not in a root for `cardWorthy`'s own stated reason:
*"a guard spread over two call sites is two answers"*. `ForestTestBoot` and `MatchBoot` both feed
that module, and in Karen's place a drive is open while she stands at the lobby range — so before
this task a lane hit WAS written a drive row and a hunt card the moment a drive was running.

---

## 10. The data file: one file both read, and "implement in game" is one commit

### 10.1 The file

| | |
|---|---|
| Path | `src/shared/Shooting/numbers.json` (and `src/shared/Shooting/init.luau`) |
| In Studio | `ReplicatedStorage.Shooting.numbers`, a **Rojo JSON module** — a ModuleScript returning the decoded table |
| Compared by the harness | by **VALUE**, not Source: the "json" kind added in Task 98 for `poses.json` (`tools/studio_mcp.py` docstring) |
| Requires | **nothing.** Its own local `deepFreeze` (`src/shared/Report/init.luau`'s precedent), so `Shotgun`, `Rifle`, `Lever` and `SemiAuto` can each require it with no cycle |

**Keyed by CARTRIDGE, not by weapon, and that is measured rather than tidy.** `SemiAuto.CONFIG` reads
`Shotgun.CONFIG.MUZZLE_STUDS_PER_S`, `DRAG_PER_STUD`, `ZERO_STUDS`, `GRAVITY_SCALE` and
`SPREAD_FULL_DEG` directly (`src/shared/SemiAuto/init.luau`), because *"a SECOND gun started firing
this cartridge"* (`Weapons.ROWS.shotgun`'s own comment). A weapon-keyed file would put the 12-gauge's
numbers in two rows that can drift; a cartridge-keyed one cannot.

```json
{
  "version": 1,
  "claim": {
    "VIEW_LAG_BASE_SECONDS": 0.30,
    "FLIGHT_CATCHUP_PING_FACTOR": 1.0,
    "FLIGHT_CATCHUP_MAX_SECONDS": 0.15
  },
  "cartridges": {
    "12ga":     { "MUZZLE_STUDS_PER_S": { "Slug": 1752, "Buck": 1442 },
                  "DRAG_PER_STUD":      { "Slug": 1.059e-3, "Buck": 2.631e-3 },
                  "GRAVITY_SCALE":      { "Slug": 1.0, "Buck": 1.0 },
                  "SPREAD_FULL_DEG":    { "Slug": 0.16, "Buck": 1.6 } },
    "416rigby": { ... },
    "4570gov":  { ... }
  }
}
```

Each gun names its own cartridge key in its own file (`Shotgun.CARTRIDGE = "12ga"`,
`SemiAuto.CARTRIDGE = "12ga"`, …) and reads its four rows from it. The losing literals are archived
under `backups/` with a note (rule 7); they are **moved, not copied** — two homes for one number is
the failure this file exists to prevent.

### 10.2 The ONE boundary that reads it

Three read sites, and each is one line:

1. **`src/shared/Weapons/init.luau`** — `Weapons.ROWS` already assembles every ballistic row for every
   gun (`MUZZLE_STUDS_PER_S = C.MUZZLE_STUDS_PER_S`, …) and `Weapons.row(id)` is the one accessor.
   This is the assembly point the BRIEF names; the values now come from the file via each gun's
   CONFIG.
2. **`src/server/Weapon/init.luau`** — `Weapon.viewWindowFor` and `Weapon.catchUpFor` read
   `cfg.CLAIM.VIEW_LAG_BASE_SECONDS`, `cfg.FLIGHT_CATCHUP_PING_FACTOR` and
   `cfg.FLIGHT_CATCHUP_MAX_SECONDS`, where `cfg` is already `config or CONFIG` — **an optional third
   parameter both functions already take**, which is what makes both states testable without the
   file.
3. **`src/client/Weapon/Claim.luau`** — `limits = opts.limits or Shotgun.CONFIG.CLAIM`, likewise
   already parameterised.

Nothing else changes. `Ballistics.shotFor(row, ammo)` keeps reading the row and keeps refusing a row
that is missing a number — *"`nil` IS A DATA FAULT AND NEVER A FALLBACK"* — so a typo in the JSON
refuses the shot rather than firing it in a straight line.

### 10.3 The live override, and why `CONFIG` cannot carry it

`Shotgun.deepFreeze(Shotgun.CONFIG)` runs at module load (`src/shared/Shotgun/init.luau`), and
`Shotgun.deepFreeze(Weapons.ROWS)` likewise. **A live value cannot be written into either.** So the
override is `poses.json`'s mechanism exactly:

- **One attribute**, `DHShooting` on `ReplicatedStorage.Shooting`, holding a JSON object —
  `Viewmodel.OVERRIDE_ATTRIBUTE = "DHPose"`'s shape, and its two stated reasons: a Roblox attribute
  name cannot contain a dot, and clearing a tuning session must be a single write. Set on the SERVER
  of a running session so it replicates to every client.
- **One reader.** `Shooting.live()` returns a deep-frozen table: the file when nothing is set
  (**the same table identity**, so an un-tuned server allocates nothing and behaves bit-for-bit as
  today), and a merged clone when something is — `Viewmodel.merge`'s shape, *"a new deep-frozen
  table → (data, problems). PURE."* It caches on the attribute's own changed signal, so the cost per
  shot is a table read.
- `Weapons.row(id)` answers the frozen `ROWS[id]` while no override is live and a merged row,
  memoised on the override's serial, while one is. `Weapon.viewWindowFor`/`catchUpFor` take
  `Shooting.liveConfig(CONFIG)` as their `config` argument — one function, two call sites, both
  already parameterised.
- **The tool is `tools/shot.py`** (`show` / `set <path> <value>` / `compare` / `save` / `clear`), the
  only writer of that attribute, built on `tools/pose.py`'s shape and sharing nothing with it but the
  idea. `save` rewrites `numbers.json` through the tool's own serializer.
- **`test` and `test2` must REFUSE to start while an override is set**, exactly as they do for
  `DHFlag_*` and for the pose override (*"No pose override is set"*, checked before the token is
  written and again in `verdict()`). That guard lives in `tools/studio_mcp.py`, the one owner of the
  overrides, and `selftest` must prove the new one catches and clears (standing rule J).
- **No flag.** The file ships the shipped numbers, so the un-tuned path is an identity — and the
  guard that proves it is better than a flag: `tests/server/shooting.spec.luau` walks the file
  against the four CONFIGs row by row, which is the device `rifle.spec` already uses for
  `Weapons.ROWS.rifle`. A flag on a data read would be two code paths for one number.

### 10.4 The sentence that makes "implement in game" one commit

The hunt and the range read **the same `Weapons.row(id)`, the same `Ballistics.shotFor`, the same
`Flight`, the same `CLAIM` block** — there is no range copy of any shooting number anywhere. So when
Karen likes what the range does, the change is `tools/shot.py save`: **one commit of
`src/shared/Shooting/numbers.json`**, which is a content-lane change under CLAUDE.md's own rule
(`CONTENT_PATHS` in `tools/agents.py` — one more path beside `poses.json`), with the one-player
harness run and no review round for the tuning itself.

---

## 11. How it is tested

### 11.1 Server specs (DEV, no Play, no world) — `tests/server/range.spec.luau`

Pure first, then the owner against fakes. `lobby.spec` and `lobby_live.spec`'s arrangement, and it
works in DEV for `lobby_live.spec`'s stated reason: the owner is only started by a boot that returns
early in the DEV place, so the module sits unstarted and each case starts it with its own fakes and
stops it again.

1. `Range.anchorFor` — a row for `forest-test` and for `map:v1`, **nil for `arena`, for a world with
   no row and for nil**. The switch-off case is the one that matters most.
2. `Range.laneEnds` / `matPosition` / `crossingSeconds` — pure arithmetic, including TARGET 3's
   predicted crossing times from `Boar.CONFIG.PACE`, read from the config and not typed.
3. `Range.spotAt` — on the mat, one stud off it, 500 studs away, nil position.
4. `Range.paceAllowed` / `optionAllowed` — every legal word, and `nil`, `""`, a table, a number, an
   ammo the chosen weapon does not carry, a weapon that is not in `Weapons.ORDER`.
5. `Build.build` into `Instance.new("Folder")`, **both anchor branches**: `plate = true` builds its
   own ground and `plate = false` lays the lane on a fake `groundAt`; every part `Anchored`; the mat
   is the **first direct-child BasePart**; one prompt per spot; the part count against
   `Range.CONFIG.MAX_PARTS`; and `pcall(Build.build, ...)` twice produces no duplicate folder.
6. The owner with fake seams: a fake `boars` view that records every `leadTo`, a fake occupant with a
   real root part, a fake clock. Asserted: the direction **alternates** on each leg; the speed asked
   for is `Boar.paceSpeed`'s and never a literal; an animal reported `flying` is **not** ordered; a
   dead target is cleared and re-released; `leadTo` is re-issued (a count that rises with the scans)
   while the per-player attribute writes are **edge-triggered** (a count that does not).
7. The door: a forged payload (`spot = "1"`, an unknown pace, a weapon the player is not near),
   the rate bucket, and a pick from a player **not standing on the mat** — each counted in its own
   counter, `badRequests` apart from `refusedBy`.
8. `Range.mayShoot` false for every player when the flag is off, when the range is not built, and
   when the character is off the mat; and the two composed providers asserted **by parameter**:
   `armingPolicy(player)` and `driveOpenProvider(player)` true at a spot with a closed drive, and
   unchanged for a player the drive already arms.
9. `tests/server/shooting.spec.luau` — the file against the four CONFIGs, row by row, plus every way
   the JSON can be wrong (a missing cartridge, a load the row does not carry, a string where a number
   belongs, a negative `GRAVITY_SCALE`), in `Viewmodel.validate`'s shape; and
   `Ballistics.shotFor` refusing each of them.
10. `Weapon.ShotResolved` fires exactly once per resolved shot, for a hit and for a miss, with
    `reachedStuds` and `resolvedAtServerTime` set — driven through `Weapon.setCast` with a fake cast,
    as `weapon_shot.spec` already drives the flight.

### 11.2 Client specs — `tests/client/range_panel.spec.luau`

Fakes for the prompt (*"a plain synchronous signal"*, because a `BindableEvent` fires deferred and
*"a spec cannot fire a real `ProximityPrompt`"* — `ShopPanel.setPrompt`'s own measured note):

1. open and close through the fake prompt; `RangePanel.isOpen` on the edges;
2. **the two doors, by tag**: `Cursor.isFree()` true and `Cursor.stats().tags` containing exactly
   `"range"` while open; `Weapon.Input.isHeld()` true and `Input.holdTags()` containing `"range"`;
   both released on close and **nothing else's tag touched**; `Cursor.stats().reasserts == 0`;
3. the option lists come from the shipped tables — asserted against `Weapons.ORDER`,
   `Weapons.row(id).AMMO_KINDS` and `Boar.CONFIG.PACE`, never against a literal in the spec;
4. `confirm()` sends exactly one request with the selected trial, through an injected `send`;
5. `RangeBoard.rowText()` for a record with a hit, a miss and a kill, including the **two lead
   numbers** and the `≤` marker on an unmeasured view offset.

### 11.3 The harness, on the player's path — one new scenario in `tests/client/input_scenarios.txt`

```json
{ "name": "the-range",
  "spec": "ClientTests.range_live.spec",
  "stage": { "targetFolder": "Range", "offsetStuds": [0, 4, 0] },
  "steps": [ … E, moveTo the viewport centre, click, clicks on the rows, MouseButton1 … ] }
```

The stage is the shipped instrument and needs **no harness change**: it finds
`Workspace.<targetFolder>:FindFirstChildWhichIsA("BasePart")` on the SERVER, places the character at
`target.Position + offsetStuds` and aims at it, then sets `LocalPlayer.StagedTarget`
(`tools/studio_mcp.py`, `QUERY_STAGE_TARGET` / `QUERY_STAGE`). That is why `Build` parents the **mat
first**: the stage's target must be the firing position. The spec then keeps the aim on the running
target with the camera owner's own held look, which is what `shoot_boar.spec` does
(`Camera.TestLook`, `DHTestLook` — level-triggered, held, Studio-only, task 263).

What the spec asserts, end to end, nothing stubbed: the panel opened, the request arrived, a target
is running on the lane, a real `MouseButton1` produced an accepted shot, and the board shows a shot
with both lead numbers.

**Three limits, stated, with the fallback for each.** Rule 6: a harness fault is a bug and gets
reported, not worked around.

| Limit | Evidence | What is done |
|---|---|---|
| The replay **cannot aim input at an instance** (TASKS.md Task 6: *"Cannot express: touch, gamepad, `textInput`, frame-counted holds, input aimed at an instance"*), and no shipped scenario has ever clicked a GUI row — there is no shop scenario in the file | `tests/client/input_scenarios.txt` | The panel is anchored at the screen centre so the CONFIRM button contains the viewport centre at any size, the scenario clicks that one point, and **the spec asserts the button's real `AbsolutePosition`/`AbsoluteSize` contains the point the scenario clicked** before asserting the click arrived. A constant that is checked, not assumed; if the click does not arrive the assertion fails loudly and the harness fault is reported |
| Whether a replayed `E` reaches the engine's own `ProximityPrompt` handling is **NOT ESTABLISHED** | `ShopPanel.setPrompt`: *"a spec cannot fire a real `ProximityPrompt`"* | The spec drives the open through the shipped `setPrompt` seam with a synchronous fake. The **real `E` into the real prompt is a Director ops step** with `263key.ps1` (which adds `MapVirtualKey` and a throwaway press, because without them *"every digit arrived at `UserInputService` as `KeyCode.None`"*) plus a screenshot. If the replayed `E` does turn out to work, the scenario keeps it and the fake becomes redundant |
| The DEV target is the grey box, not the drawn animal | `BoarAssetsBoot`: `Boar.CONFIG.MODEL.ENABLED or Map.PLAYTEST_WORLD` | The zones are the same parts in both worlds, so every geometric claim holds in DEV. **The LOOK of the range is Karen's playtest**, in her place, with a screenshot |

### 11.4 Screenshots (rule 5)

`python tools/studio_mcp.py capture <name> [camera x,y,z] [look-at x,y,z]`, and looked at before any
claim about what it shows. Required for: the lane from the firing line with the target mid-window
(the only proof the thing reads as a range), the open menu, and the board after a run of shots.

### 11.5 Blast radius

`src/server/Range/`, `src/shared/Range/`, `src/client/Hud/RangePanel.luau`, `RangeBoard.luau`,
`src/shared/Shooting/`, `src/shared/Weapons/`, `src/server/Weapon/`, `src/shared/{Shotgun,Rifle,Lever,SemiAuto}/`,
`src/client/Weapon/Claim.luau`, `src/server/Boar/init.luau` (one moved pure function),
`src/server/{ForestTestBoot,MatchBoot}.server.luau`.

**`test2` is N/A for every one of them.** None is in `TWO_PLAYER_PATHS` (`tools/agents.py`): the
range is the weapon, the boar and the hud, which *"behave the same with one player as with two"*. The
one-player line is required, always. New scope rows for `tools/studio_mcp.py`'s `BLAST_RADIUS`:
`src/server/Range`, `src/shared/Range`, `src/client/Hud/RangePanel.luau` → `range`;
`src/shared/Shooting` → `gun` (it IS the gun's numbers). `selftest` fails if a spec file belongs to no
scope, so `range.spec` and `shooting.spec` must be added to `SCOPE_SPECS` in the same commit.

---

## 12. What it reads and writes, and who owns each

| Fact | Direction | Owner of the fact | How |
|---|---|---|---|
| `Map.EXPECTED_WORLD` | read | `ReplicatedStorage.Map` (frozen, no writer) | injected as `seams.world` by the root |
| the RANGE flag | read ONCE at the boundary | `ReplicatedStorage.Flags` | `Range.ENABLED = Flags.isOn("RANGE")`, passed inward as `seams.enabled` |
| where the ground is | read | the world's ONE reader (`ForestTest.Data.groundAt`; nil in DEV) | `seams.groundAt` |
| the terrain | write (one scrub under the lane) | `Workspace.Terrain`, handed in as an argument | `seams.terrain`; nil = no scrub |
| the lobby's anchor and its pads/yard/gather rectangles | read, to stay clear of them | `ServerScriptService.Lobby` | **the SPEC reads them**, not the range: `lobby.spec`'s own device, so neither owner requires the other |
| the target's existence, pace and lane | the range ASKS; `Boar` decides and writes | `ServerScriptService.Boar` (`Brain` decides, `Body` writes) | `seams.boars` — `spawn`, `clear`, `statusOf`, `leadTo`, `flying` |
| which pace is how many studs/s | read | `ServerScriptService.Boar` (`Boar.paceSpeed`, moved there by this task) | `seams.boars.configOf()` |
| the animal's zone names | read | `ServerScriptService.Boar` (`CONFIG.ZONES.ORDER`) | ditto |
| a shot was accepted | read | `ServerScriptService.Weapon` (`Weapon.ShotFired`) | wired at the root |
| a shot resolved, hit or miss | read | `ServerScriptService.Weapon` (`Weapon.ShotResolved`, new) | wired at the root |
| a hit, its zone and its distance | read | `ServerScriptService.Weapon` (`Weapon.HitReported`) | wired at the root. `HitLog.recordHit` keeps receiving it, unchanged |
| a death | read | `Boar.Runtime.Downed` | the range only clears and re-releases |
| may this player hold a gun / is his trigger live | the range ANSWERS; the WEAPON decides and refuses | `ServerScriptService.Weapon` | `Range.mayShoot`, composed into two providers at the root |
| the mouse | **never written by the range** | `StarterPlayerScripts.Camera.Cursor` | `requestFree("range")` / `release("range")` |
| the trigger | **never written by the range** | `StarterPlayerScripts.Weapon.Input` | `requestHold("range")` / `releaseHold("range")` |
| the shooting numbers | read | `ReplicatedStorage.Shooting` (frozen data, no run-time writer) | `Weapons.row`, `Weapon.viewWindowFor`, `Claim` |
| money, points, penalties, licences, the roster | **not read and not written** | `Economy`, `Match`, `HitLog`'s drive rows | — |

---

## 13. Numeric targets

| # | Target | How it is measured |
|---|---|---|
| 1 | **The board reports the lead as two numbers, never one.** Ballistic lead and view offset, each labelled with its source, the second marked `≤` when it is the window and not a measurement | `range_panel.spec` on `RangeBoard.rowText()`; the live spec on a real shot |
| 2 | **A shot the player sees as centred on the chest logs `zone = chest`.** Over 20 run-pace shots: **zero** shots where the client drew a hit mark and the server logged no hit, and zero where the logged zone's DRAWN part the aim point was not on | the live client spec plus `Weapon.stats` (`claims`, `claimsAccepted`, `refusedClaimBy`) |
| 3 | **Crossing times within ±10 %** of 8.9 s (walk 4.5), 3.64 s (trot 11), 1.67 s (run 24) over the 40-stud window | `Range.step` measures it off the target's own position samples and publishes it; the live spec asserts it. Outside tolerance, `APRON_STUDS` is the dial |
| 4 | **The lane is where it says it is:** the target's x stays inside `WINDOW/2 + APRON + 4` and its z within 2 studs of the lane | the live spec, off `statusOf` |
| 5 | **Zero second writers.** `Cursor.stats().reasserts == 0`; the range makes no `CFrame` write to any animal (grep: no `.CFrame =` and no `AssemblyLinearVelocity` in `src/server/Range/` except inside `Build`'s own parts) | the client spec; the Reviewer's read |
| 6 | **Build cost:** ≤ 150 parts and ≤ 120 ms, printed on the console at the build edge like `[lobby] built in %d ms` | `Range.stats().parts`, `.buildMs` |
| 7 | **Step cost:** `STEP_HZ` 10, one `leadTo` per live target per step, ≤ 1 ms per step with one spot | `Range.stats()` |
| 8 | **One board payload per shot and one per trial change** — not one per step. A `boardWrites` that climbs with `scans` is the bug the counter exists to show | `Range.stats().boardWrites` against `.scans` |
| 9 | **The data file is an identity at rest:** every row equals the CONFIG value it replaced | `tests/server/shooting.spec.luau`, row by row |
| 10 | 50 m later: slug flight 0.113 s, ballistic lead at run **2.70 studs = 76 cm** — the distance at which the ballistic lead first exceeds half a body length | arithmetic, recorded for the distance task |

---

## 14. External sources

Rule 1 and rule 2: named, linked, with licence and maintenance status, what each does well and badly,
and the pattern taken. **No open-source running-target range exists to borrow code from** — that is
stated rather than papered over, and it is why the borrowed CODE patterns are this repository's own
and are cited as such in §4, §6, §7 and §10.

1. **ISSF, Official Statutes, Rules and Regulations — 10 m Running Target (section 8)**
   <https://www.issf-sports.org/theissf/rules.ashx> ·
   <https://www.issf-sports.org/sports/discipline.ashx?discipline=RT>
   Copyright ISSF, freely published. **Current** — reissued every Olympic cycle and still a World
   Championship discipline. *Well:* the exact shape wanted — one target, one lane, one variable at a
   time, with the crossing TIME (not the speed) as the dial the shooter feels, a boar silhouette, and
   a **mandatory direction change** so neither shoulder is favoured. *Badly:* 10 m and an air rifle;
   not one number in its table transfers. **Taken:** the lane, one variable at a time, and the
   alternation (§4.1, §6 step 2) — a finding we would not have guessed.
2. **Deutscher Jagdverband — the *laufender Keiler***
   <https://www.jagdverband.de/> · <https://www.jagdverband.de/wild-wissen/jagdliches-schiessen>
   Copyright DJV; the national association's own competition and education material. **Current**, and
   the doctrine this game's hunt is already modelled on (`Boar.Wound`, the Kammer zones, the safety
   arc). *Well:* the hunter's discipline at the hunter's distance, scored **anatomically** — the
   Kammer counts and a paunch hit is a fault, not a lower ring. *Badly:* it publishes the discipline,
   not a measured target speed; the figures quoted for these ranges come from range operators rather
   than one authoritative table. **Taken:** the board's columns are ZONES and not rings (§9.1); the
   speed is taken from our own animal instead (§6).
3. **Svenska Jägareförbundet — the *löpande älg* test**
   <https://jagareforbundet.se/> · <https://jagareforbundet.se/skytte/>
   Copyright Svenska Jägareförbundet. **Current**, and the mandatory moose test in Sweden, Norway and
   Finland. *Well:* the clearest precedent for *"the target moves at the speed the animal really
   moves"* — calibrated against the animal, not against a stopwatch — and a pass read off the vitals
   rather than a score. *Badly:* 80 m, a centre-fire rifle, a 500 kg animal; lane and zones an order
   of magnitude off ours. **Taken:** target speed = the animal's own `PACE`, invented nowhere (§6).
4. **theHunter: Call of the Wild (Expansive Worlds, 2017) — the harvest screen**
   <https://store.steampowered.com/app/518790/> ·
   <https://thehunter.fandom.com/wiki/Harvest_Screen>
   Commercial, **closed source**, proprietary licence; **actively maintained** (still shipping content
   in 2026). *Well:* the anatomical readout — which organs the bullet passed, the distance, whether it
   was lethal — so the player learns *where* he hit. *Badly:* it is a POST-MORTEM screen, one animal,
   after it dies: it shows nothing about a miss, and a range is mostly misses, and it says nothing
   about lead. **Taken:** the zone columns beside the existing hit card (§9.1).
5. **Aim Lab (State Space Labs) and KovaaK's — per-shot moving-target telemetry**
   <https://store.steampowered.com/app/714010/Aim_Lab/> ·
   <https://store.steampowered.com/app/824270/KovaaKs/>
   Commercial, **closed source**, proprietary licences; **actively maintained**. *Well:* the only
   widely used prior art that reports a moving-target miss as a **vector** rather than a score,
   separating how far off from in which direction — the "behind the target" signature of
   under-leading. *Badly:* no anatomy, no ballistics, no distance; and the per-shot vector is read off
   their UI, not from a published format, so what is borrowed is the IDEA. **Taken:** the signed
   along-track gap (`-0.9 studs BEHIND`), §9.2.
6. **Roblox Creator Documentation** — `ProximityPrompt`, `CollectionService`, `Instance`,
   `BasePart.Anchored`, `Terrain:FillBlock`
   <https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt> ·
   <https://github.com/Roblox/creator-docs> — the documentation repository is published under
   **CC BY 4.0** and is **continuously maintained** by Roblox. *Well:* it is the engine's own
   description of the instance behaviour used here. *Badly:* it is silent or wrong on the three
   things this repo has had to measure — what `Player:GetNetworkPing()` means (the whole of open item
   H), that four `Workspace` streaming properties are unreadable from Luau (`Map.STREAMING`), and
   that a replayed keystroke needs a scan code (task 263). **So where shipped code answers a
   question, this design cites the shipped caller and not the docs** (lesson L-108): the cursor
   (`Camera.Cursor`), the trigger (`Weapon.Input`), the prompt (`Lobby.Build.shopPrompt` and
   `ShopPanel.setPrompt`) and the deletion rule for Studio-made instances (CLAUDE.md, Rojo project
   format).
7. **This repository, which outranks all of the above for the mechanism.**
   `docs/research/2026-10-24-real-shooting.md` (the ballistics, the lead, the two defects);
   `docs/research/2026-10-01-poses-as-data.md` plus CLAUDE.md "Content lane" (numbers in a data file,
   tuned live, saved in one commit — **already shipped once**, for `poses.json`);
   `docs/research/2026-10-17-the-pad-menu-and-the-truck.md` with `src/client/Hud/ShopPanel.luau`
   (a `ProximityPrompt` opening a full-screen panel that is clickable in first person);
   `src/server/TestArena.luau` and `src/server/Lobby/Build.luau` (world geometry from code into one
   folder, every dimension in one table).

---

## 15. Open decisions

### For Karen (feel and design) — none of these blocks building; each has a stated default

1. **Does the range lend a gun she has not bought?** Default: **yes**, at a spot only, never into a
   drive. Three of the seven dials cannot be judged otherwise. One line at the composition root
   either way (§7.4).
2. **Does the target die?** Default: **yes, exactly as in the hunt** — one shooting path (decision 3)
   — with the carcass held 3 s and a fresh target released 2 s later. The alternative (an unkillable
   target for pure lead practice) would be a second damage path and is refused unless she asks for it.
3. **Which side of the lodge**, and how the lane should look: a mown strip with earth screens at each
   end and a berm behind (§4.1), or something more built. The footprint is decided by measurement
   (§4.2); the side and the look are hers.
4. **Does the menu stay open while she shoots**, or close on confirm? Default: **close**, because the
   cursor and the trigger hold are released together and a man cannot shoot with the panel up.
5. **`FLIGHT_CATCHUP_PING_FACTOR` cannot be closed in Studio**, and the range does not pretend
   otherwise. A loopback Play session reads **1.7 ms** (task 256 round 2), which is 0.065 studs on a
   sprinting boar, so no measurement on this machine can tell 1.0 from 2.0. The range makes the dial
   reachable and the error visible; **closing open item H needs a published session on two machines**,
   which is Karen's call and not a build step.

### For the Director (scope)

6. **Phase B is more than one task, and rule 4 says one task per round.** The buildable order, each
   its own task, each shippable alone:
   - **B1** `src/shared/Shooting/` plus `numbers.json`, the three read sites, `shooting.spec`, the
     archived literals. Pure refactor, provable as an identity, and it unblocks everything else.
   - **B2** `src/shared/Range/` plus `src/server/Range/` (`Build` and the owner) and `range.spec`,
     built in DEV only, no menu and no gun. The lane runs and the crossing times are measured.
   - **B3** `Weapon.ShotResolved`, `Range.mayShoot` and the two composed providers, with the
     `driveOpenProvider` signature change.
   - **B4** `RangePanel` and `RangeBoard`, the two remotes, the client specs and the live scenario.
   - **B5** `tools/shot.py` plus the `DHShooting` guard in `tools/studio_mcp.py` and its selftest.
   - **B6** the forest world: the measured anchor, the `forest-test` row, the boot wiring, Karen's
     playtest and the screenshots.
   B1 and B2 can run in parallel; B4 needs B2 and B3; B5 needs B1.
7. **Is `ZERO_STUDS` in the tunable set?** It is not in the BRIEF's IN list, and it is coupled to
   `GRAVITY_SCALE` (the drop and the zero are one picture). Default: **out**, as the BRIEF says, and
   it costs one row to add later.
8. **`Boar.paceSpeed` is moved out of `ForestTest` by this task** (§6) so one answer serves two
   readers. That is a one-line delegation and no behaviour change, but it touches a forest file, so
   it is called out rather than slipped in.
9. **The red deer target** waits for its rig, per decision 1. The board already reads the species'
   own zone order, so `neck` appears the day a deer runs on the lane and nothing else changes.
