# ONE PLACEMENT RULE: a target is the GROUND MEASURED UNDER IT, and a floor that catches a fall

Task 192. Karen, 2026-10-14 ~17:00, verbatim: *"when drive ends I am underground ... terrain is
broken / when next round is started respawn in under terrain and I dead all a time"*; again
2026-10-15 ~17:30: *"next one is fix terrain / when I respawn I die or when new round I die so fix
that"*.

## 1. What the system must do

1. Every point a CHARACTER is put down at -- a drive placement, the lobby's return, the results
   scene's ring, a tie -- stands on the ground that is really there at that point's own `x, z`,
   plus a clearance, with the root never inside a solid.
2. No hard-coded `Y`, and no `Y` carried sideways from a point that was measured somewhere else.
3. A ray that misses (the place has not finished loading, a region has not streamed) is RETRIED and
   then COUNTED, never silently turned into a number.
4. If a character ends up under the ground anyway -- a second writer, a client-side eject, a fall
   through a seam -- it is put back on the ground and the rescue is a number in the report.
5. Numeric target: a player at rest stands with his root **2-4 studs** above the measured ground,
   and **0 deaths** across three full cycles (lobby -> drive -> drive end -> next round) plus a
   manual respawn in each phase.

## 2. What was actually wrong, measured in the place Karen plays

A full cycle was played in "Driven Hunt Forest Test" with Karen's own switches
(`DHFlag_COINS/DRIVE_BOTS/SHOP`, `DHForestStartRole=hunter`) and the layout forced to `edge`
(`DHForestLayout`), with a 0.5 s server sampler logging the root, the terrain under it, the
humanoid state and every death. Raw log: `<runs-dir>/t192-before.log`,
console `<runs-dir>/t192-before-console.txt`.

**Defect 1 -- the results scene has ONE Y for a ring 14 studs across, measured somewhere else.**
`Match.gatherSpotFor` takes the MIDDLE post's ground (`middle.Position.Y - middle.Size.Y/2`) and
then moves the spot `SCENE.GATHER_BEHIND_STUDS` (24) studs horizontally **without measuring the
ground again**; `Scene.ringLayout` puts every slot of the ring at that one `Y + STAND_HEIGHT_STUDS`.
On the `edge` layout the six stands' own terrain is 147.9, 148.0, 171.5, 191.6, 223.4, 228.2 -- an
80-stud hillside -- so the middle post (Stand3, 171.5) is not the ground anywhere else on that line.
Measured in Edit over the three shipped layouts: the worst ring slot's own ground is **+7.8 studs**
above the flat `Y` the ring uses (`edge`), 0.0 on the road, -0.3 on the ride.

**Defect 2 -- TWO WRITERS of where a character stands during the results scene, and the second one
keeps the Y.** `ForestTest.boundary` (the hunter's soft wall, task 166) writes `root.CFrame` every
Heartbeat for every drive participant and clamps X and Z onto his own stand's circle **while keeping
`position.Y`**. So at the gathering the drive put the player at a ring slot near Stand3 and the wall
then dragged him back to 12.0 studs from Stand4 -- `PICK.standRadiusStuds` exactly -- carrying the
ring's `Y` with him: logged at `(3543, 174.5, -3001)` with the terrain under him at **189.0**, so
his feet were **17.5 studs under the ground**, `Anchored = true`, `Freefall`, for the whole 25-second
scoring phase. This is Karen's *"when drive ends I am underground"*, and it is the failure
`docs/PROJECT_CONTEXT.md` names in one line: *"Two systems wrote the creature's position"*.
The guard this needs already exists one line up: task 177 added `Match.isParticipant` to this very
loop for this very class of bug (*"his y bouncing 143 / 145 / 149 as two writers fought over him
every frame"*), and `Match.isHeld` is the same question's other half.

**Defect 2b -- the SAME second writer is the other half of Karen's sentence: *"when I respawn I
die"*.** A hunter who presses Reset in the middle of a drive is respawned by the engine at
`Workspace.ForestRoadSpawn` -- (3000, 138.5, -2109), 900 studs from the `edge` line -- and the soft
wall clamps his X and Z onto his own stand's circle on the very next Heartbeat while keeping that
spawn's `Y`. Measured, in both proof runs, to the stud: he arrives at **(3549, 143.7, -2990)** --
11.7 studs from stand 4, which is `PICK.standRadiusStuds`, and **47.8 studs under the terrain**,
which is the hill the wall put him inside. It is not a different bug from defect 2; it is the same
line of code reached by a different door, and it is why the wall is given
`Body.liftOntoGround` as well as the `isHeld` guard.

**Defect 3 -- the lobby's return spawn has no clearance, and THAT is the death.**
`Lobby.CONFIG.SPAWN.OFFSET` is `(0, 0, 16)`: `Y` 0. `Lobby.spawnCFrame` therefore puts the ROOT at
the measured shelf height, which is the ground, so a returned character is about 4 studs inside the
terrain. Logged, at the start of the next round: placed at `(2850, 149.2, -2934)` with the ground at
150.0 (terrain) / 150.2 (the lodge's own spawn slab), then **119.8 -> 39.0 -> -93.3 -> -285.7** in
two seconds and destroyed below `Workspace.FallenPartsDestroyHeight` (-500) -- `Humanoid.Died`,
3 seconds after the drive ended. The engine ejects a body that starts inside a solid, and down is
the way out of a hill. This is Karen's *"when new round I die"*, every round, and it has nothing to
do with the drive.

None of the four is a streaming fault (`Workspace.StreamingEnabled` is true in this place, and the
server's own rays answered at every point). All four are the same mistake: **a `Y` that was not
measured at the point it is used for.**

## 2b. Round 2 and round 3: the reader's starting height, and the voxel it reads

**Round 2 (Reviewer round 1, finding 1).** "Where is the ground under this body" was answered by a
ray from 300-600 studs UP, so the first solid thing OVERHEAD became the ground. Measured live with
this world's own reader: under the log cabin at (2840, -2910) it answers **160.8** against a floor
of **150.0**; under a canopy at (3450, -2900) it answers **221.3**
(`Workspace.Session.Mesh Tree.OuterLeaves`) against terrain at **180.1** -- a 41-stud lie, over the
ground a beater walks for 580 studs. A downward ray can only hit what is BELOW its origin, so the
reader now takes a `fromY` and `Body.groundUnder` asks from the point + 6 first. The far cast
remains, and has to: **a downward ray that starts inside a solid MISSES** -- at (3555, -3000) with
the surface at 191.6, from 197.6 HIT 191.6, from 188.6 MISS, from 171.6 MISS -- so a buried point
cannot find its own surface by looking down.

**Round 3 (Reviewer round 2, finding 1), AND IT CORRECTS A MEASUREMENT IN SECTION 5 BELOW.**
`Body.insideTerrain` read `Region3.new(at - 2, at + 2):ExpandToGrid(4)` and took index `[1][1][1]`.
That region is four studs wide only when the coordinate is exactly 2 (mod 4); at every other offset
it expands to EIGHT -- two voxels per axis -- and index 1 is the region's MINIMUM corner, which
`MapGen.Ground.paintTrack` already writes down as `rmin = region.CFrame.Position - region.Size / 2`.
Measured at (3555, -3000): the span came back `8, 8, 8` with its minimum at `(3552, 192, -3004)`, so
for a root at z -3000 **the cell actually read was four studs away in z**.

**So round 2's occupancy table was itself taken from the wrong cells, and this is the corrected
one.** Reading the CONTAINING cell (`min = floor(at / 4) * 4`, `max = min + 4`) down four columns of
the live place, by offset from the measured surface:

| offset | (3555, -3000) | (3405, -3000) | (2850, -2934) | (3030, -2097) |
|---|---|---|---|---|
| -12 | 1.00 | 1.00 | 1.00 | 1.00 |
| -8 | 0.98 | 1.00 | 1.00 | 0.89 |
| -4 | 0.93 | 1.00 | 0.56 | 0.50 |
| 0 | 0.39 | 0.46 | 0.00 | 0.00 |
| +4 | 0.00 | 0.00 | 0.00 | 0.00 |

A half would put the cell the surface crosses on the fence (0.46 and 0.50 are two of those
readings), so `TERRAIN_SOLID_OCCUPANCY` is **0.75**, in the gap between "within one cell of the
surface" (<= 0.56) and "two or more cells down" (>= 0.89).

**"Buried" is two cells, not one**: the cell the root is in AND the cell four studs above it. One
cell alone is a body settling half a stud low; two is a body with ground over its head.

**A standing character cannot read "buried", by arithmetic as well as by measurement.** A root sits
about 3 studs above its own feet, so for its cell to be half solid the surface would have to be at
least 2 studs above that cell's floor -- which puts the root at least 5 studs above the floor of a
cell that is 4 studs tall. It cannot happen. Measured at all four columns: a settled root reads
`Air` 0.00.

**THE ONE PLACE THIS DEVIATES FROM THE DISPATCH, stated rather than buried.** Task 192 round 3's
dispatch asked for a spec case "root embedded 3+ studs deep -> buried". With the measured profile a
root 3 studs under the surface sits in the cell the surface crosses (0.39-0.56) with AIR above it,
so the two-cell rule answers FALSE there, and raising the threshold to catch it would hand the
surface cell back to a standing character. The shallow case is also not the failure this net exists
for: the three real ones were 4, 17.5 and 47.8 studs, the 4-stud one is a placement the snap now
prevents, and a body with air over its head is ejected upward by the engine rather than trapped. The
spec therefore asserts burial at 10, 17.5 and 24 studs and the shallow case is left to the placement
rule. That is a judgement about a number, and it belongs to the Director.

## 3. Sources

| # | Source | Licence / status | What it does well | What it does badly |
|---|---|---|---|---|
| A | **Valve Source SDK 2013** -- `UTIL_DropToFloor` / `CBaseEntity::DropToFloor`, `game/server/util.cpp`; `SF_NORESPAWN` spawn flags. [Source SDK 2013](https://github.com/ValveSoftware/source-sdk-2013) | Valve SDK licence (source available, non-commercial); repo archived/maintained sporadically | THE pattern, 20 years old: an entity's spawn `Y` is never authored -- it is a trace straight down from the authored point, and the entity is placed on what the trace hit. One function, called by everything that spawns | It is a HULL trace against a BSP world; a voxel terrain plus skinned characters is not that, so only the shape of the idea transfers |
| B | **ioquake3** -- `SelectSpawnPoint`/`SpotWouldTelefrag` in `code/game/g_client.c`, `TeleportPlayer` in `code/game/g_misc.c` | GPL-2.0, actively maintained | Two separate ideas worth having: a spawn point is VALIDATED before it is used (`SpotWouldTelefrag`), and a teleport explicitly zeroes the player's velocity and re-sets his view -- a teleport is not a move | Spawn points are hand-placed by a level designer at a known good height, so it never has to ASK where the floor is |
| C | **Unreal Engine** -- `AWorldSettings::KillZ` + `AActor::FellOutOfWorld`, and `UWorld::FindTeleportSpot` | Epic EULA (source available), actively maintained | `KillZ` is `FallenPartsDestroyHeight`'s exact twin, and `FellOutOfWorld` is a HOOK: the engine tells the game a body left the world instead of only deleting it. `FindTeleportSpot` resolves a target that is inside geometry rather than trusting it | The hook's default is still to destroy. Nothing in it puts the actor BACK, which is the half this task needs |
| D | **Roblox** -- [Raycasting](https://create.roblox.com/docs/workspace/raycasting), [`FallenPartsDestroyHeight`](https://create.roblox.com/docs/reference/engine/classes/Workspace#FallenPartsDestroyHeight), [Instance streaming](https://create.roblox.com/docs/workspace/streaming) (`Player:RequestStreamAroundAsync`) | Vendor docs, current | Says plainly that a part below `FallenPartsDestroyHeight` is DESTROYED (so a character 650 studs down is a death, not a fall), and that a teleport into a region a client has not streamed can drop a character -- which is why a missed ray must be a retry and not a default | No guidance at all on what a spawn `Y` should be, and `RequestStreamAroundAsync` yields, so it cannot be used inside a placement that must not yield |
| E | **Luanti (Minetest)** -- `minetest.get_spawn_level`, `builtin/game/misc.lua` | LGPL-2.1, actively maintained | The "measure, then refuse" discipline: it answers `nil` when there is no legal spawn level at that `x, z` instead of inventing one. That is what this repo's `Markers.groundFor` already does | Voxel-grid specific; its answer is an integer node level |

## 4. The pattern adopted, and why

**DROP TO FLOOR (A, C) at the ONE owner, plus a KILL-Z HOOK INVERTED INTO A RESCUE (C).**

* The snap lives in **`Match.Body`** and nowhere else, because that module is already *"the only
  writer of ... where their character stands"* (CLAUDE.md rule 3; `docs/design/drive.md` 5.1). Every
  path Karen walks goes through `Body.place` (the drive's placement AND the lobby's return, which is
  injected as `place = function(player, cframe) Body.place(...) end`) or `Body.stand` (the results
  scene) or `Body.tie`. Fixing the owner fixes all four at once; fixing `Lobby.CONFIG.SPAWN.OFFSET.Y`
  would fix one of them and leave the rule unwritten.
* **A caller's `Y` becomes advisory, and that is stated rather than discovered.** `Body.placementFor`
  still returns post-top + `STAND_HEIGHT_STUDS`, `Scene.ringLayout` still returns the ring, and
  `Lobby.spawnCFrame` still returns the porch slot -- the snap then replaces the `Y` with the ground
  measured at that slot's own `x, z`. Where the caller was already right (the road, the DEV arena)
  the snap is a no-op to within the voxel surface, which is what `Body.snapped()` counts.
* **ONE definition of "where is the ground" per world.** `Body.setGroundReader` takes the world's own
  reader -- in the Forest Test `ForestTest.groundAt`, the same function `Markers.setReaders`,
  `Bots.start` and `Lobby.start` are already given -- and falls back to its own ray (excluding
  characters) when no world injected one, which is the DEV place. A third copy of that ray would be
  two definitions of one fact, the thing this project's rules exist to stop.
* **The rescue is a floor, not a kill (C inverted).** Roblox gives no `FellOutOfWorld` hook, so
  `Body.floorStep` is the hook: at the drive's existing 4 Hz step it asks, per player, "is this root
  more than `MAX_BELOW_GROUND_STUDS` under the ground measured beneath it, or below the world's
  destroy height?" and if so puts the character back -- on the ground at its own `x, z`, or at the
  last place it was standing. It is a NET under a rule, not a substitute for one: with defects 1-3
  fixed it should fire zero times in a clean session, and `Body.rescuedFromUnderGround()` is how that
  claim is checked instead of believed.
* **Rejected: `Player:RequestStreamAroundAsync` before each placement** (D). It yields, and
  `Body.place` runs inside a `CharacterAdded` handler that must pivot in the same resumption cycle
  (`Body.settle`'s whole measured reason). The server always has the geometry, so the TARGET is never
  wrong for want of streaming; a client that has not streamed the ground is exactly what the floor
  net above catches. Written down so the next person does not have to re-derive it.
* **The soft wall is made HORIZONTAL rather than routed through `Body`.** `ForestTest.boundary`
  writes `root.CFrame` itself (task 166) and that stays, because turning the wall into a placement
  would change what a wall IS -- a clamp that runs every Heartbeat, not a teleport. What it is given
  is `Body.liftOntoGround`, which is ONE-SIDED: it moves a point more than `Body.maxBelowGround()`
  studs INSIDE the ground and never touches one on it or above it. So the wall cannot bury anybody
  and cannot pin a jumping hunter to the floor either, and the vertical answer still comes from the
  one owner. `ForestTest.boundaryLifts()` counts it.
* **The TIE is the one placement that is NOT snapped, and that is a measurement too.**
  `Body.tiePointFor` reads the TREE's own bottom face, which is already an answer to "where is the
  ground" -- a tree stands on it. A ray would be worse: a tree on a rock or a platform would tie the
  offender to the ground far below it, and `match_safety.spec`'s own fixture (a trunk 700 studs up)
  fails on exactly that, which is how this was found rather than argued. So the tie takes the
  one-sided half only, like the wall: lifted out of the hill, never pulled down to it.
* **Rejected: snapping inside `Scene` or `Lobby`.** Both would be a second writer of the one fact.
  `Scene` is handed the reader as a parameter so the ANIMALS and the TORCHES sit on their own ground
  too (a buried torch is the same bug seen from outside), but it asks `Body`'s reader -- it does not
  own a second ray.

## 5. The numbers, and where each came from

| Number | Value | Why |
|---|---|---|
| `GROUND_CLEARANCE_STUDS` | 3.5 | `Match.CONFIG.STAND_HEIGHT_STUDS`, the number this repo already uses for "how far above the ground a character is put down". Measured on a stand in the live place: root 4.0 above the terrain, feet +0.2 -- inside the dispatch's 2-4 stud target |
| `GROUND_PROBE_UP_STUDS` / `DOWN` | 300 / 1200 | `ForestTest.terrainYAt` and `ForestTest.groundAt` both ray from y 600 down 1200 in this place; 300 above the target is the same reach without assuming a world's absolute height |
| `GROUND_RETRIES` / gap | 3 / 0.05 s | A miss means "not loaded yet" (D). Three tries inside a sixth of a second is well under `Match.CONFIG.PLACE_TIMEOUT` (5 s) and under `Body.PARENT_WAIT_SECONDS` (2) |
| `MAX_BELOW_GROUND_STUDS` | 5 | A standing R15 root is ~3 studs above its feet and the voxel surface is good to ~0.5; 5 studs below the ground cannot be a standing character, and the real failures measured here were 4, 17.5 and 650 |
| floor | `Workspace.FallenPartsDestroyHeight + 100` | 100 studs of warning before the engine deletes the body (D). In this place that is -400 against a terrain floor of ~99 |
| net rate | 4 Hz | `Match.CONFIG.MATCH_STEP_HZ`, the drive's existing step. A 2-second fall from the ground to -500 is 8 samples |

## 6. What this note does NOT claim

* It does not claim the terrain of this place is geometrically broken. Measured in Edit over a
  13x13 grid at 20-stud spacing centred on the lobby (2850, -2950): **no holes** (0 missed rays) and
  a smooth 139.0..170.4 hillside; and at the three layouts' middle stands the two independent ground
  readings agree to 0.00 studs (`[ForestTestBoot] markers: layout=edge 6/6 stands (0 refused), max
  ground delta 0.00`). What Karen SAW as broken terrain was being inside it. If a hole is found
  later it is a different task with a different measurement.
* It does not touch the map generator or any Studio-saved terrain.
