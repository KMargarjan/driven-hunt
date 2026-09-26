# Design: map-generator (v3 — the drive runs through a wood, and the line stands on a forest road)

System: `map-generator` — the Luau that writes the v1 map (terrain, the forest road, the wood, fields,
hedge banks, the bog and every gameplay marker) into the DEV place at **edit time**, plus the tool that
invokes it. `ROADMAP.md` Milestone 2.

**Task 54: a revision of the Task 42 design (v2) against `reviews/task-54/BRIEF.md`** — Karen's
reference images and her decisions of 2026-09-26. The brief overrides anything older in `docs/`,
`TASKS.md` and the earlier design. The Task 42 file is superseded **in full** by this one; it stays in
git history (rule 7).

Architect, 2026-09-26, read-only session: Read, Grep, Glob only. **No Studio, no network, no engine.**
Evidence precomputed in `.agent-evidence/` (`INDEX.md`), commit
`c95a3cf9dca71067d2291d11fcbe1cad83290992`. Every claim about existing code below names a **file and a
symbol**, never a line number.

Inputs, in precedence order: `reviews/task-54/BRIEF.md`; the code as built and merged
(`src/serverstorage/MapGen/`, `src/shared/Map/init.luau`, `tools/mapgen.py`,
`tests/server/map_contract.spec.luau`); `docs/design/drive.md`; `docs/design/asset-pipeline.md`;
`docs/design/meshy-tool.md`; `docs/design/feature-flags.md`; `docs/research/2026-09-24-map-generator.md`;
`docs/research/2026-09-26-asset-pipeline.md`; `TASKS.md` rows 43a–48a (the queue this design has to
answer); `CLAUDE.md`; `ROADMAP.md`; `GAME_DESIGN.md`; `docs/PROJECT_CONTEXT.md`.

**Test of this document:** a Builder can build task M2.8a from it without asking a question. Every
owner is named, every interface is written out, every number is here with its basis, every human action
is in §18 and §20.

---

## 0. What changed against v2, in one page

Karen's decisions, from the brief, and what each costs:

| Karen's decision | The change |
|---|---|
| The shooter line runs **along a forest road** through the woods, not along a field edge | The drive line marker **is** the road's centreline; the road is a flat, gravel **bench** cut into the heightfield by `Height`, 16 studs wide, running the map's width (§6.3, §9) |
| Shooters stand **on the road**, **40–80 m apart** | `postSpacing` 80 → **160 studs** (45 m, inside her range). 8 posts now span 1,120 studs, so the drive corridor widens from x ± 340 to **x ± 620** (§15.1) |
| Boars **cross the road** from the driven side to the far side; some come out between two shooters | `exitZ` −760 → **−820**, 120 studs past the road, and `corridor.minZ` −800 → **−880**, so the flee target is in the **far wood** and the crossing is what a shooter sees (§9.2) |
| The drivers push **through the woods** | `Props.rejectTree` (`src/serverstorage/MapGen/Props.luau`) currently rejects **every** point inside the corridor. That rule is **deleted**: trees now grow in the drive, at a density that is provably walkable for the boar's own agent (§7.2, §7.3) |
| Autumn: orange/brown/yellow deciduous, green spruce | A terrain **palette** step (`Ground.applyPalette`), four species with autumn crown colours, and leaf-litter ground (§8) |
| Only oak, birch, black alder, spruce | Four tree keys and one species field; alder biased to wet ground (§7.1) |
| Boars come as singles **and groups of 2–5** | Map side only: the boar-spawn pad grows from radius 14 to **30** so a sounder spawns on flat ground. The group logic is **`docs/design/drive.md`**'s, and §11 states exactly what the map guarantees it |
| Shooters wear an **orange hat**, drivers an **orange vest** | New, and it is **not** this system's: the owner is `Match.Body` (§10), merged OFF |

Three defects and eight queued notes in the built code are answered here rather than left to drift
(§19.2): the post pads that merged into one flattened strip (`TASKS.md` row 45a(d)) are gone, because
the posts now stand on the road bench; the 9.5-stud drop onto a `CanCollide = false` post
(row 43a(l), audit-004 F9) is fixed by a 1-stud post marker; and reachability now paths to five points
along the line instead of its centre (row 44a(e)).

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

1. **Build one v1 map: a mixed wood with a forest road through it**, with fields on the flanks — the
   drive corridor in the wood, the shooter line on the road, the boars' escape in the far wood
   (`reviews/task-54/BRIEF.md`).
2. **Run at edit time only**, through StudioMCP, from code on disk. Never at run time, never in a live
   server, never during Play.
3. **Be reproducible from a seed**: the same commit and seed give the same map, digest-proved
   (`MapGen.digest`, `tools/mapgen.py verify`).
4. **Place every gameplay marker as a tagged, script-free, inert instance** that
   `src/server/Match/Markers.luau`, `Markers.read`, already reads — on ground that is **exactly
   `GROUND_Y`** (§6.4).
5. **Leave the drive walkable for the boar's own agent** (`Boar.CONFIG.AGENT` in
   `src/server/Boar/init.luau`: `AgentRadius = 2`, `AgentCanJump = false`), now that the drive is
   wooded — proved geometrically (§7.3) and empirically by `MapGen.reachability`.
6. **Look like autumn**, by palette and species, not by one recoloured material (§8).
7. **Reference every art asset by key**, never by file, never by a bare id outside the manifest, never
   by a binary in the repo (§12).
8. **Be undoable**: the machine-checked backup condition in `tools/mapgen.py` before any destructive
   run, and `MapGen.clear()` as the in-place reset — which now also **restores the terrain palette**
   (§8.4).
9. **Be checkable by machine**: server specs (§16.1), a client spec (§16.2), eight named Edit-mode
   screenshots (§16.3).
10. **Cost the harness nothing**: no `default.project.json` change (so no extra Karen **Connect**
    click), no new Wally package, no `.rbxm`, no typed value in a `.model.json`.

### 1.2 Must not

Each row is a named failure from `docs/PROJECT_CONTEXT.md`, a boundary an existing owner drew, or a
documented engine fact.

| Prohibition | Why | Whose job instead |
|---|---|---|
| Never run at run time. No `.server.luau` / `.client.luau` / `init.server.luau` anywhere under the generator | a map that rebuilds itself on server start is a second writer of the world that nobody can see | `tools/mapgen.py`, at edit time, by hand |
| Never be `require`d by a runtime script | the runtime must not depend on a build tool. `MapGen.verifyContract` asserts every descendant of `ServerStorage.MapGen` is a `ModuleScript`, so nothing can autorun | game code requires `ReplicatedStorage.Map` |
| Never write a script, or bake an asset containing one | `CLAUDE.md`: nothing script-like is ever created in Studio, and one surviving `Script` under Workspace fails the harness's unmanaged-script scan **every run from then on** | `Props.scriptIn` refuses the template, the key falls back to a proxy, and the step fails with the id and the script's name (`src/serverstorage/MapGen/Props.luau`, `Props.template`) |
| Never write `Workspace.TestArena`, `Workspace.Boars`, `Workspace.WeaponEffects`, `Workspace.DriveMarkers` or any player | four named owners: `ServerScriptService.TestArena`, `ServerScriptService.Boar`, `PlayerScripts.Weapon.Effects`, `Match.Body` (`src/server/Match/Body.luau`, `Body.driveMarkers`) | those owners |
| Never write `Boar.CONFIG`, `Shotgun.CONFIG`, `Match.CONFIG` or any runtime state | one writer per system | their owners. The map **publishes** its rectangle; `Boar.CONFIG.field` is changed by the boar's owner at the M2.5 switch |
| Never turn streaming on as a side effect of a build | audit-004 F4 / row 43a(f): the step is inert today only because the contract happens to match the place | `MapGen.Settings`, `Settings.MAY_WRITE = false` until M2.6, which **refuses and reports** (`src/serverstorage/MapGen/Settings.luau`, `Settings.apply`) |
| Never create a `Water` terrain material in v1 | the boar's mover is a horizontal-plane `LinearVelocity` (`src/server/Boar/Body.luau`, `Body.create`) that was never designed to swim. The bog is `Mud` and a dip | a v1.1 task with its own boar work |
| Never put a **collidable** obstacle across the drive without a proved gap | the hedgerow wall that survived two review rounds in Task 43 (row 43a(k)) | §7.3's geometry plus `MapGen.reachability` (§16.4) |
| Never make a marker shootable, walkable or collidable | `src/server/Weapon/Cast.luau` builds `RaycastParams` with an Exclude filter and **no `RespectCanCollide`**, so a `CanCollide = false` part still stops a pellet: `CanQuery = false` is the load-bearing one (`Markers.place` already does this) | `MapGen.Markers` |
| Never decide a player's clothing, team or position | `Match.Body` is the only writer of a player's character (`src/server/Match/Body.luau` header) | §10 |
| Never write `Lighting`, `SoundService`, `Teams` | art, sound and the match are other tasks; and because the generator never writes `Lighting`, a rebuild cannot destroy it, which is what makes `tools/mapgen.py`'s census sound | Milestone 2's art task |
| Never add a subcommand, a write path or an MCP tool to `tools/studio_mcp.py` | *"Its Luau is read-only"* (`tools/studio_mcp.py` docstring, "Safety"). The file that decides whether a PR may be reviewed must not also be the file that can rewrite the world | `tools/mapgen.py` |
| Never claim a save happened | `tools/mapgen.py` cannot observe a Studio menu action, and an unverifiable claim in a tool's output is the false-PASS shape this project has already paid for | the tool prints the action; the proof is a reopen plus `mapgen.py contract` |
| Never commit a Creator Store, Meshy or place binary (`.rbxm`, `.rbxmx`, `.rbxl`) | `CLAUDE.md` bans the first two outright; the Creator Store grant is a licence to use the asset *"in Roblox Studio and in Experiences on the Services"*, and a public git repo is neither | ids in the manifest; backups outside the repo |

**One predicate answers one question.** `Map.EXPECTED_WORLD` says which world the committed code
expects. It does not say whether the arena should be built, whether streaming is on, whether an asset
is loadable, or whether the map is any good.

---

## 2. Ownership

Rule 3: exactly one writer per system, named here, mirrored in `GAME_DESIGN.md`.

### 2.1 The owner table

`GAME_DESIGN.md` already carries the first three rows (its map-contract, generated-map and
player-placement rows). This revision **amends** them rather than adding new systems: the amendments
are listed in §19.1.

| System | Owner (the only writer) | Location on disk → Studio |
|---|---|---|
| **The map contract**: tag names, the drive rectangle, the expected world, the road, the pad, the palette, streaming and budget numbers. Frozen data, **no runtime writer at all** | `ReplicatedStorage.Map` — nothing writes it; the Builder edits the file and git records it | `src/shared/Map/init.luau` |
| **The map generator**: `Terrain` (voxels **and material colours**), `Workspace.DrivenHuntMap` and everything in it, and `Workspace.StreamingEnabled` | `ServerStorage.MapGen`, and within it exactly four modules touch the world: `Ground` (Terrain and the palette), `Props` (`…Map.Props`), `Markers` (`…Map.Markers` and every `CollectionService:AddTag` in the map), `Settings` (the streaming property) | `src/serverstorage/MapGen/` |
| **The generator invoker**: the one write path into Studio | `tools/mapgen.py` — the only thing in the repo that sends a mutating `execute_luau` | `tools/mapgen.py` |
| **The markers the game reads** (`DrivenHunt.*` tags) | **at edit time:** `MapGen.Markers` in the generated map, `ServerScriptService.TestArena` in the grey box — never both (§17). **At run time: nobody writes them**; `Match.Markers` reads them | as above |
| **A player's hunting outfit** (the orange hat and vest, §10) | **`ServerScriptService.Match` → `Match.Body`**, which is already the only writer of a player's team, character placement and tie. **Not the map, not the Hud, not the client** | `src/server/Match/Body.luau` |
| **The asset manifest and the one id→Instance seam** | `ServerStorage.Assets` once M2.7a lands (`docs/design/asset-pipeline.md` §2.1). **Until then `MapGen.Assets` holds it**, with the key grammar already identical, and `MapGen` must not grow a second copy (§12.2) | `src/serverstorage/MapGen/Assets.luau` → `src/serverstorage/Assets/` |
| World geometry: test arena | **unchanged:** `ServerScriptService.TestArena`, booted by `ArenaBoot`, which gains one early return at M2.5 | `src/server/TestArena.luau` |

### 2.2 The modules inside `ServerStorage.MapGen`

As built, plus this revision's changes. **Nothing happens on require**, with one recorded clause:
`Contract.luau` clones the contract script in Edit so a run cannot read a stale one (its own header
records the measurement). `Contract` was an addition to the v2 module list, reported as row 43a(e);
**it is folded in here** (43a(e) closed).

| Module | Is | Changes in this revision | Never |
|---|---|---|---|
| `init.luau` | the entry point: `VERSION`, `CONFIG`, `steps`, `runStep`, `clear`, `digest`, `markerDigest`, `builtSeed`, `census` inputs, `reachability`, `expectedCounts`, `verifyContract` | `VERSION` reads `Map.GENERATOR` (closes row 44a(f)); a `palette` step; tree and brush **block** steps; `reachability` paths to five points | decides a layout rule itself; writes a voxel |
| `Contract.luau` | how the generator reaches `ReplicatedStorage.Map`, fresh in Edit | — | anything else |
| `Config.luau` | pure data: every number in §15, deep-frozen with `Shotgun.deepFreeze` (**required, not copied**: `table.freeze` is shallow and this repo has paid for that once, `TASKS.md` row 23a(b)) | the whole §15 table | anything else |
| `Height.luau` | pure: `Height.at`, `Height.atFlattened`, `Height.corridorFalloff`, `Height.offset` | **new**: `Height.benchHeight`, `Height.benchBand`, `Height.edgeFloor`; `atFlattened` applies benches after pads | touches Terrain, Instances, services or `Random` |
| `Layout.luau` | pure: tiles, pads, markers, tie trees, hedge lines, gates' spans, tracks, bog, corridor tests | **new**: `Layout.benches`, `Layout.onRoad`, `Layout.inField`, `Layout.treeBlocks`, `Layout.treeDensity`; `Layout.pads` returns the four boar spawns only | as above |
| `Scatter.luau` | pure: the seeded half of every placement | **new**: `Scatter.speciesAt`, `Scatter.weighted` (accept a candidate against a density weight and its own drawn key), `Scatter.brush` | as above |
| `Digest.luau` | pure: the canonical digest of a plan plus terrain samples | takes the **palette** as a third input, so a hand-changed material colour shows in the digest | as above |
| `Ground.luau` | **the only writer of `Terrain` in the repo**: `writeTile`, `paintTrack`, `sampleRow`, `cells`, `clear` | **new**: `Ground.applyPalette`, `Ground.readPalette`, `Ground.resetPalette`; `surfaceMaterial` gains the road and field cases | reads or writes any Instance |
| `Props.luau` | **the only writer of `…Map.Props`**: `template`, `hedge`, `placeTree`, `trees`, `tieTrees`, `trunks`, `rejectTree`, `clearAssets` | per-species proxies; `trees` takes a **block**; **new** `Props.brush`; `rejectTree` no longer rejects the corridor and does reject the benches | writes Terrain or a marker; calls an insert API other than through `Props.template` |
| `Markers.luau` | **the only writer of `…Map.Markers`** and the only caller of `CollectionService:AddTag` in the map | post marker size; the drive line's span | writes Terrain or a prop |
| `Settings.luau` | **the only writer of `Workspace.StreamingEnabled`**, refusing while `MAY_WRITE == false` | — | writes anything else |
| `Assets.luau` | the manifest, empty on purpose, until M2.7a moves it | four tree keys plus `prop.brush.a` (§12.1) | grow a second copy of an id |

`Height`, `Layout`, `Scatter`, `Digest` and `Assets` stay exported on `MapGen` (`MapGen.Height`, …), for
the reason `src/server/Boar/init.luau` exports `Boar.Brain`: **the pure core must be drivable in the
ordinary harness run, with no Studio, no Terrain and no asset, while the generator itself never runs
there.**

### 2.3 What may require what

```
ServerStorage.MapGen  ──requires──►  MapGen.Contract ──►  ReplicatedStorage.Map
ServerStorage.MapGen  ──requires──►  MapGen.Assets   (→ ServerStorage.Assets at M2.7a)
runtime scripts       ──require───►  ReplicatedStorage.Map
runtime scripts       ──NEVER─────►  ServerStorage.MapGen
MapGen.reachability   ──requires──►  ServerScriptService.Boar, at EDIT TIME ONLY, inside a pcall
```

The last line is as built (`MapGen.reachability` requires `Boar` for `Boar.CONFIG.AGENT`) and is
deliberate: the check must use the **real** agent, and it runs only from `tools/mapgen.py`.

`src/serverstorage/` and `src/shared/` are already `$path`-mapped, so **no `default.project.json`
change and no extra Karen Connect click.**

---

## 3. The world, in plan and in section

```
 PLAN (x across, z up the page; 2048 x 2048 studs, origin at the centre)

            x=-1024      -620            0            +620       +1024
   z=+1024   ┌───────────────────────────────────────────────────────┐
             │ field   │        wood (backdrop, sparse)      │ field │
   z=+800    │ ........│═══════ assembly track (bench) ══════│.......│   corridor.maxZ
   z=+700    │         │   ▪ DriverStart, 8 drivers over 1120 studs  │
             │         │                                    │       │
   z=+600    │  hedge  │   ● ● ● ●  BoarSpawn x4 (pads r=30) │       │
             │  bank   │                                    │       │
   z=+300    │═════════╪════ hedge bank, 2 gates in the drive ═══════│
             │  x=-760 │        THE WOOD the drivers push   │ x=+760│
             │         │        through (1,400 studs)       │       │
   z=-440    │         │        density rises toward the road│       │
   z=-700  ══╪═════════╪══ THE FOREST ROAD ══════════════════╪═══════╪══ gravel bench, 16 studs
             │     ▲ 8 posts on the road, 160 studs apart, span 1,120 (x=±80,±240,±400,±560)
   z=-745    │         │   † 12 tie trees, behind the line   │       │
   z=-820    │         │   exitZ: the boar has crossed and is gone   │
   z=-880    │  bog    │        far wood (thinner)          │       │   corridor.minZ
   z=-1024   └───────────────────────────────────────────────────────┘

 SECTION across the road (z), at one x

        wood floor          verge   ROAD   verge          wood floor
   ~~~~~~~~~~~~~~~~~~~~~~~\        ┌──────┐        /~~~~~~~~~~~~~~~~~~~~
    relief +/-16 in corridor \_____│ flat │_____ /   relief eased to +/-6
    (eased to +/-6 within 120)     │ y=0  │          within BENCH_BAND
                              24   └──────┘   24
                             verge   16 wide   verge
```

The whole point of the section: **everything the game stands a player or a boar on is at exactly
`GROUND_Y = 0`** — the road bench, the assembly bench and the four spawn pads — so
`Boar.CONFIG.field.groundY` needs no change at the M2.5 switch, and `Match.Body.placementFor`'s
`STAND_HEIGHT_STUDS` arithmetic lands on ground rather than in a hole.

---

## 4. The map contract — `ReplicatedStorage.Map`

`src/shared/Map/init.luau`, deep-frozen with `Shotgun.deepFreeze`. Data only, no behaviour, no runtime
writer. Shared rather than server-only for the reason `src/shared/Shotgun/` is: one file, one require
path. It carries no asset id and no secret.

### 4.1 The fields (additions and changes marked)

```luau
export type FieldRect = {
    bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
    exitZ: number,
    groundY: number,
}

Map.VERSION        = "v1"
Map.GENERATOR      = "m2.8-road-autumn"   -- NEW. MapGen.VERSION reads this; one home, one diff.
                                          -- Closes TASKS.md row 44a(f) by deleting the second copy.
Map.EXPECTED_WORLD = "arena"              -- THE SWITCH (§17). One committed fact.
Map.SEED           = 0                    -- the seed the committed map was built from; 0 while "arena"
Map.DIGEST         = ""                   -- the digest that seed produced; "" while "arena"

Map.FIELD: FieldRect                      -- the world EXPECTED_WORLD names. Must equal
                                          -- Boar.CONFIG.field (asserted). Arena numbers until M2.5,
                                          -- then §15.1's corridor.
Map.SIZE_STUDS     = 2048
Map.TAGS           = { shooterPost = "DrivenHunt.ShooterPost", driveLine = "DrivenHunt.DriveLine",
                       driverStart = "DrivenHunt.DriverStart", boarSpawn = "DrivenHunt.BoarSpawn",
                       tree = "DrivenHunt.Tree" }                      -- unchanged: five strings, one home
Map.EXPECTED_COUNTS= { shooterPost = 8, driveLine = 1, driverStart = 1, boarSpawn = 4, tree = 4 }
                                          -- the ARENA's counts while EXPECTED_WORLD is "arena";
                                          -- tree becomes 12 at the switch
Map.STREAMING      = { enabled = true, minRadius = 64, targetRadius = 1024,
                       integrityMode = "PauseOutsideLoadedArea", modelBehavior = "Improved",
                       scriptable = { "StreamingEnabled" } }           -- unchanged, and measured
Map.BUDGET         = { parts = 20000, visibleParts = 8000, trees = 3000,
                       brush = 600, hedgeParts = 400 }                 -- CHANGED: two new ceilings
Map.SPAWN_PAD      = { radius = 30, blend = 40, tolerance = 0.75 }     -- CHANGED: radius 14 -> 30 (a sounder)
Map.ROAD           = { z = -700, halfWidth = 8, verge = 24,            -- NEW (§6.3)
                       from = -900, to = 900 }
Map.ASSEMBLY       = { z = 700, halfWidth = 5, verge = 20,             -- NEW: the drivers' track
                       from = -700, to = 700 }
Map.PALETTE        = { litter = Color3.fromRGB(150, 108, 62),          -- NEW (§8)
                       rough  = Color3.fromRGB(126, 122, 78),
                       road   = Color3.fromRGB(152, 146, 132),
                       bog    = Color3.fromRGB(96, 82, 62) }
Map.PALETTE_DEFAULT= { … }   -- NEW, and MEASURED before it is written (§8.4, measurement N1):
                             -- Terrain:GetMaterialColor for the four materials on a place nobody has
                             -- recoloured. This is what MapGen.clear restores. Do not guess it.
```

`Map.SPAWN_PAD.blend = 40` is **adopted here as the design's number** — it is the value the build
measured and committed in Task 45 against the v2 design's 24, because a 16-stud drop eased over 24
studs produced a 22.5° ring around every pad against a 15° ceiling. `TASKS.md` row 45a(a) asked the
Architect to move the number or explain the conflict: **the number moves.** The relief stays Karen's
taste value; the blend is not one.

### 4.2 The tag vocabulary has one home, and that is unchanged

`Map.TAGS` is the one home for the five strings; `MapGen.Markers` writes from there
(`Markers.place`), `src/server/Match/Markers.luau` reads from there, `src/server/TestArena.luau` tags
from there. Row 43a(h) notes `tests/server/test_arena.spec.luau` still spells them literally: leave it,
and **comment it as deliberate** — a spec that re-derives the contract from the contract checks
nothing.

### 4.3 What the markers are, physically

Every marker is an **`Anchored`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`,
`Transparency = 1` `Part`** under `Workspace.DrivenHuntMap.Markers`, named for its kind and index, and
tagged. This is as built (`Markers.place`) and it is load-bearing, for the reason that module's header
records: `Weapon.Cast` sets no `RespectCanCollide`, so a 1,240-stud invisible drive line with
`CanQuery = true` would eat shots.

Three shapes are not the generator's choice:

- **The drive line is exactly one part**, now `size = (1240, 1, 1)` — the corridor's full width — at
  `z = Map.ROAD.z`, built with `CFrame.lookAt(position, position + Vector3.zAxis)` so its
  `LookVector` points at **+Z, the drivers**. `src/server/Match/Markers.luau`, `Markers.read`,
  publishes `normal = line.CFrame.LookVector`; `src/server/Weapon/SafetyArc.luau` consumes it; two
  tagged lines make `complete = false` and the drive sits in `Waiting` for ever.
- **A shooter post is a part a character is put down on top of.** `src/server/Match/Body.luau`,
  `Body.placementFor`, returns `post.Position + (0, post.Size.Y / 2 + STAND_HEIGHT_STUDS, 0)` with
  `STAND_HEIGHT_STUDS = 3.5`. With the v2 post size of `(4, 6, 4)` that is **ground + 9.5 studs** over
  a part that does not collide — the drop named in row 43a(l) and audit-004 F9. **The post marker
  becomes `(6, 1, 6)`**, centred at `GROUND_Y + 0.5`, so the stand point is ground + 4.5 and a
  character's root lands about a stud above where it stands. Karen confirms it by standing on one
  (§18, §20).
- **`DrivenHunt.Tree` goes on the 12 placed tie trees only**, behind the line at `z = -745`
  (`Layout.tieTreePoints`, `Props.tieTrees`, `Markers.tagTieTrees`). The wood's other ~2,900 trunks are
  **not tagged**: `Body.anchorFor` scans every tagged tree on every violation, and a 3,000-part scan
  per violation is a different bug.

---

## 5. The generator's public interface

Declared **as built**, with this revision's changes marked. This section replaces the v2 declarations
that had drifted — rows 45a(g), 47a(f) and 48a(d) all report the same class of defect (a design
declaring an old signature), and they are closed here.

```luau
export type StepSpec  = { index: number, kind: string, label: string, estimatedMs: number }

export type StepReport = {
    index: number, kind: string, label: string,
    ok: boolean, message: string?,
    voxelsWritten: number?, partsCreated: number?,
    proxyUsed: { string }?,
    elapsedMs: number,
}

export type Reach = { from: string, to: string, status: string, waypoints: number }  -- `to` is NEW

MapGen.VERSION = Map.GENERATOR                 -- CHANGED: read, not typed (row 44a(f))
MapGen.CONFIG: Config                          -- frozen
MapGen.steps(seed: number): { StepSpec }        -- pure; the whole plan, no side effect
MapGen.runStep(index: number, seed: number): StepReport
MapGen.clear(): { removed: number, terrainCleared: boolean, cellsAfter: number, cellsBefore: number,
                  paletteRestored: boolean }    -- `paletteRestored` is NEW (§8.4)
MapGen.builtSeed(): number?
MapGen.digest(): { digest: string, parts: number, samples: number, seed: number?, version: string }
MapGen.markerDigest(): string                   -- its reader is the M2.5 committed-digest check
MapGen.reachability(): { ok: boolean, findings: { string }, results: { Reach } }
MapGen.expectedCounts(): { [string]: number }
MapGen.verifyContract(): {
    ok: boolean, findings: { string }, counts: { [string]: number },
    streaming: { [string]: string }, markerDigest: string, seed: number?,
    palette: { [string]: string },               -- NEW: what the place's terrain colours actually are
}
```

**One correction the Builder must make while here** (rows 45a(c), 47a(d), 48a(c), three reviews
running): `verifyContract`'s `root == nil` early return omits `streaming`, `markerDigest`, `seed` and
now `palette` against its own declared type. Either the early return fills every field, or the type
declares them optional. **Fill them** — a caller that reads `result.markerDigest` on a missing map
should get `""`, not a `--!strict` lie.

### 5.1 The step order, which is also the layer order

Each layer is a pure function of the seed and the layers before it, so one can be re-run alone.

| # | Kind | Count | What |
|---|---|---|---|
| 1 | `clear` | 1 | `Terrain:Clear()`, destroy `Workspace.DrivenHuntMap`, **restore the palette**, and fail loudly if cells remain (as built, audit-004 must-fix 1) |
| 2 | `palette` | 1 | **NEW.** `Ground.applyPalette(Map.PALETTE)`. Second, so every later screenshot shows the intended colours |
| 3 | `terrain` | 256 | `Ground.writeTile` — one 128 × 128 tile: height → occupancy → material. The road bench, the assembly bench, the pads, the bog dip and the field/wood material split all resolve here, per column |
| 4 | `hedgerow` | 3 | `Props.hedge` — one line per step, gates cut where it crosses the corridor |
| 5 | `track` | 1 | `Ground.paintTrack` — the flank field track, **material only** |
| 6 | `trees` | 16 | **NEW shape.** `Props.trees(root, seed, config, block)` — one 512 × 512 block per step, its own folder, idempotent |
| 7 | `brush` | 4 | **NEW.** `Props.brush` — low cover, one quadrant per step |
| 8 | `stand` | 1 | `Props.tieTrees` — the 12 placed tie trees |
| 9 | `markers` | 1 | `Markers.place` + `Markers.tagTieTrees`. Last of the world layers, so no marker is orphaned and the posts stand on a bench the terrain step already flattened |
| 10 | `settings` | 1 | `Settings.apply(Map.STREAMING)` — refuses while `MAY_WRITE == false` and says so |

**285 steps.** There is no bog step, and there never was one: the bog is a dip and a material, both
decided per column by `Layout.bogDepth` (as built, and the reason is in `MapGen.steps`).

### 5.2 Statelessness, restated as a rule the Builder can check

> A step may read: its arguments, `MapGen.CONFIG`, the contract through `MapGen.Contract`, the pure
> modules, and the world as it stands. A step may **not** read a module upvalue written by an earlier
> step, a cached plan, a memo table, or `Workspace` for anything but its own idempotence.

Every world-writing step is **idempotent**: re-running the trees step for block 7 destroys and rebuilds
`…Map.Props.Trees.Block07`; it does not add a second wood. That is what makes `mapgen.py step` a usable
retry.

---

## 6. The ground

### 6.1 The heightfield (unchanged in technique)

`Height.at(x, z, seed, config, bogDepth?)` — domain-warped fractal noise on `math.noise`, with the
seed entering as a **coordinate offset** because `math.noise` takes no seed. Pattern borrowed from
RTerrainGenerator (§14 source 4); the code is ours (`Height.offset`, `fbm`, `Height.at`).

### 6.2 The three masks, in the order they apply

```
h  = fbm(warped x, warped z) * RELIEF
h  = h * corridorFalloff(x, z)      -- 1 outside; CORRIDOR_RELIEF/RELIEF inside; 90-stud ease  [as built]
h  = h * benchBand(x, z)            -- NEW: BENCH_RELIEF/RELIEF within BENCH_BAND of a bench
h  = max(h, edgeFloor(x, z))        -- NEW: a floor, not an addition, so the voxel band is unchanged
h  = benchOrPad(h, x, z)            -- NEW order: pads, then benches; a bench WINS over a pad
```

- **`benchBand`** eases the relief down to `BENCH_RELIEF = 6` studs within `BENCH_BAND = 120` studs of
  a bench centreline, smoothstepped. Its only job is to keep the verge shallow: 6 studs over the
  24-stud verge is `atan(6/24) = 14.0°`, inside `CORRIDOR_MAX_SLOPE_DEG = 15`. Without it, the
  corridor's ±16 studs against a flat road gives 33.7°, which the slope spec would (correctly) fail.
- **`edgeFloor`** raises the outer ring of the map so a player on the road does not look at a void:
  it is a **floor** (`max`), rising smoothly to `EDGE_MAX_Y = 44` studs in the outer 100 studs, and it
  is **suppressed within `BENCH_BAND` of a bench**, so the road runs off the map flat and the edge is
  hidden by trees instead of by a ridge. A floor rather than a sum keeps the maximum height at 44,
  inside the measured voxel band `BAND_Y = {-48, +48}`, so the tile size that measurement A proved
  (128 × 128 × 96 studs at resolution 4) **does not change**.

### 6.3 Benches: the road, and the drivers' assembly track

A **bench** is a flat strip at exactly `GROUND_Y`, eased into the terrain over `verge` studs on each
side, and tapered over 60 studs at each end. `Layout.benches(config)` returns both:

| Bench | Axis | At | Half-width | Verge | From → to | Material | Why |
|---|---|---|---|---|---|---|---|
| the forest road | along x | `z = -700` | 8 (16 studs = 4.5 m) | 24 | −900 → +900 | `road` (gravel) | Karen: the line stands on a ride through the woods |
| the assembly track | along x | `z = +700` | 5 (10 studs) | 20 | −700 → +700 | `road` | the drivers form up on a track at the wood edge and walk in; it also flattens the `DriverStart` strip, which spans 1,120 studs and could not be a disc pad |

`Height.benchHeight` returns `GROUND_Y` inside a bench and the eased value in the verge.
**The road is level, not contour-following** — a simplification, marked K: a real forest road
undulates, and the cost of a longitudinal profile is that every post, and the contract's
`tolerance = 0.75` check, stops being a comparison against one number. If Karen wants the undulation,
it is `ROAD_RELIEF` in `Config` plus a contract check against `Height.benchHeight(x)` instead of
against `GROUND_Y`, and it is **not** in v1.

### 6.4 Pads: four, not thirteen

`Layout.pads(config)` returns **only the four boar spawns**, radius `Map.SPAWN_PAD.radius = 30`. The
eight post pads and the driver-start rectangle are gone, because the posts and the driver start now
stand on benches. Two consequences worth naming:

- **Row 45a(d) is closed by construction.** At blend 40 the v2 post pads (radius 10 + blend 40 = 54,
  spacing 80) merged into one flattened strip along the line. There is now a road there, deliberately,
   and the strip *is* the feature instead of an artefact nobody chose.
- **The spawn pads grew for the sounders.** Radius 30 covers a group of five spawned inside it
  (§11), and the nearest two pads are 300 studs apart, so pads never overlap and
  `Height.atFlattened`'s nearest-pad rule (as built) never has to arbitrate.

### 6.5 What is asserted about the ground, and where

- `tests/server/map_contract.spec.luau`: every `DrivenHunt.BoarSpawn`'s `Position.Y` within
  `Map.SPAWN_PAD.tolerance` of `Map.FIELD.groundY`; every `ShooterPost`'s **bottom face**
  (`Position.Y - Size.Y/2`) and the `DriverStart` part's four corners likewise (§16.1).
- A pure spec on `Height`: `atFlattened` equals `GROUND_Y` **exactly** at each pad centre and at 200
  sampled points on each bench centreline; at `verge + 1` studs outside a bench it equals the
  unflattened height — so a bug in the easing cannot silently flatten the map.
- The slope spec over **three seeds** (closing row 45a(e)), with a **lower bound** as well as the
  ceiling (closing row 45a(b): the v2 relief-band assertions were arithmetic identities of `Height.at`
  and would have passed on a dead-flat map).

---

## 7. The wood

### 7.1 Four species, one field, autumn crowns

Karen's four, and nothing else: **oak, birch, black alder, spruce**.

`Scatter.speciesAt(x, z, seed, config)` is pure and deterministic: a low-frequency `math.noise` field
(`SPECIES_FREQUENCY = 1/260`, so clumps read at about 70 m) chooses a band, and the candidate's own
drawn key picks inside it. Two forced cases, because they are what makes a European wood legible:

- **alder where it is wet**: `Layout.bogDepth(x, z) > 0` or `Height.at(x, z) < -6` (a hollow) → alder,
  whatever the field says. Black alder is a wet-ground tree; a spruce in a bog reads as a mistake.
- **spruce in clumps**: the field's spruce band is contiguous by construction, so the drive crosses
  dark blocks of spruce and light stands of birch, which is the cover the boar needs.

| Species | Share (K) | Proxy trunk (w,h,d) | Proxy crown (w,h,d) | Total | Trunk colour | Crown colour (autumn) |
|---|---|---|---|---|---|---|
| spruce | 0.40 | 3, 30, 3 | 14, 44, 14 | 71 studs (20 m) | RGB(78, 62, 46) | **RGB(95, 132, 96)** — green, and above the albedo floor |
| birch | 0.25 | 2.5, 34, 2.5 | 18, 32, 18 | 64 studs (18 m) | RGB(225, 222, 210) | RGB(215, 180, 70) — yellow |
| oak | 0.20 | 5, 28, 5 | 32, 38, 32 | 64 studs (18 m) | RGB(96, 78, 58) | RGB(170, 105, 45) — orange-brown |
| alder | 0.15 | 3, 26, 3 | 13, 30, 13 | 57 studs (16 m) | RGB(84, 72, 60) | RGB(140, 130, 60) — dull yellow-green |

**The albedo trap is why these numbers are this bright.** At the place's default ambient an unlit face
renders at roughly 0.275 × albedo — the measurement recorded in `src/server/Boar/init.luau`'s
`BODY_COLOR` comment and in `TASKS.md` row 22, which turned RGB(90, 80, 70) into near-black. **No proxy
colour is below 120 on its channel maximum**, spruce included. A wood that reads as a black hole is the
screen this project has already paid for.

The proxy heights are also a **correction**: the v2 proxy was `trunk (3, 22, 3)` + `crown (11, 12, 11)`
— a 22-stud, 6-metre tree — while `docs/design/asset-pipeline.md` §12.1 plans meshes at 14 × **71** ×
14 studs. A grey box whose replacement is three times its height teaches the wrong thing about the map,
and `map-stand.png` reading "two green lollipops" (row 43a(a)) is partly that.

**Crowns do not block the ground game.** Trunk: `CanCollide = true`, `CanQuery = true`. Crown:
`CanCollide = false`, `CanQuery = true`. So the navmesh and the boar see trunks only, a shot into the
canopy stops in the canopy, and the sightline at a shooter's eye height (about 5 studs) is **trunks and
brush**, which is what makes a wooded drive shootable at all.

### 7.2 Density in three tiers, because a real stem count does not fit the budget

Honest arithmetic first. At 1 stud = 0.28 m, one hectare is 127,551 studs². A managed European wood
carries 400–800 stems/ha, which over this map's ~4 M studs² of wood would be **12,000–25,000 stems**.
`Map.BUDGET.trees = 3000` (and a proxy tree is two parts). **v1 does not model a real stem count**, and
saying so here is cheaper than discovering it in a screenshot.

So the density is tiered by where the player actually is. `Layout.treeDensity(x, z, config)` returns a
weight in 0…1, and `Scatter.weighted` accepts a candidate when its own drawn key is below the weight —
deterministic, and independent of which cells were rejected before it (the property
`Scatter.jitteredGrid` already protects by drawing all three numbers for every cell).

| Tier | Where | Weight | Estimated trees |
|---|---|---|---|
| dense | within 260 studs of the road, `|x| <= 700` | **1.00** | ~1,320 |
| drive | the rest of the corridor | **0.42** | ~1,215 |
| backdrop | everything else that is not field, bench, track, bog or pad | **0.14** | ~390 |
| none | fields, benches + verges, tracks, the bog, pads + margin, within `SCATTER_CLEARANCE` of a hedge line | 0 | 0 |

Base candidate grid: `TREE_SPACING = 22` studs, `SCATTER_JITTER = 0.5`. Estimated total **~2,925**,
against the 3,000 budget. **The estimate is mine, from areas; the Builder measures the real number and
the step fails loudly if it exceeds `Map.BUDGET.trees`** — a build that quietly overruns the part budget
is how a place gets slow without a diff to blame.

### 7.3 Why the wooded drive is still walkable, argued before it is measured

This is the one place where this revision could break the game, because `Props.rejectTree`'s corridor
rejection was the guarantee that nothing stood in the drive, and it is being deleted.

1. **Minimum separation is a property of the sampler, not of luck.** A jittered grid displaces each
   candidate by at most `±jitter·spacing/2` **inside its own cell**, so two candidates in neighbouring
   cells are at least `spacing·(1 − jitter)` apart along that axis: `22 × 0.5 = 11 studs`. Diagonal
   neighbours are further (≥ 15.6). Dropping candidates by weight only increases gaps.
2. **The widest trunk is oak at 5 studs.** Worst case clear gap between two trunks:
   `11 − 2.5 − 2.5 = 6 studs`.
3. **The boar needs 4.** `Boar.CONFIG.AGENT` is `AgentRadius = 2` (`src/server/Boar/init.luau`), so
   6 > 4 everywhere, with `AgentCanJump = false` and `AgentCanClimb = false` respected.
4. **A spec asserts 1–3 rather than trusting them**: over 20 seeds, the minimum pairwise distance among
   every placed tree point in the corridor is ≥ `TREE_SPACING × (1 − SCATTER_JITTER)`, and the count
   per 10,000 studs² never exceeds the dense tier's rate. Pure, no world, runs in the ordinary harness.
5. **`MapGen.reachability` is the empirical gate**, and it is now stronger: five targets along the line
   instead of its centre (§16.4), which closes row 44a(e).

`jitter` is **0.5, not the built 0.9**, for exactly this reason: at 0.9 the guaranteed gap is 2.2 studs
and step 3 fails. That is a number changed by an argument, not by taste.

### 7.4 Brush: cover that hides a boar and blocks nothing

`Props.brush` places low cover — `prop.brush.a`, proxy `(10, 5, 10)`, colour RGB(122, 104, 64) — at
`BRUSH_COUNT = 500` (K), on its own grid, in the wood only, in four quadrant steps.

**`CanCollide = false` and `CanQuery = false`.** A bush that stops a slug is an invisible wall to a
shooter who cannot see why the shot vanished, and a bush that stops a driver is worse. Brush is
**visual cover only** in v1: it breaks the sightline down the drive so a boar is not visible for 700
studs, and it is Karen's call whether cover should ever eat a shot (§20).

### 7.5 Hedges shrink to three lines, and the gate machinery keeps a reader

The hedge network becomes **three lines, 6,144 studs, ~250 parts**:

| Line | Crosses the corridor? | Why it exists |
|---|---|---|
| `hedgeX = -760` and `hedgeX = +760` (along z) | **no** (corridor is x ± 620) | the wood/field boundary on each flank: what makes the fields read as fields |
| `hedgeZ = +300` (along x) | **yes** → 2 seeded gates inside the corridor | an old field boundary inside the wood — they exist in European woods, and it gives the drive one interior feature the boar must funnel through |

This closes `TASKS.md` row 44a(a) by the second of the two options that row offered: the v2 design asked
for ≤ 6,000 studs of hedge and the M2.2 network needed 10,240. **The network shrinks**; the row's budget
stands, with 6,144 studs and a ≤ 400-part ceiling in `Map.BUDGET.hedgeParts`.

It also keeps `Layout.corridorSpan`, `Scatter.hedgeGates` and `Layout.widestGap` alive with a **real
reader** — dropping the last crossing line would leave three tested pure functions with no caller,
which is the row-43a(m) smell, and would retire the one mechanism that already caught a wall across the
drive.

### 7.6 Fields, the bog, and the flank track

- **Fields stay, on the flanks**: `x ∈ [760, 1024]` and `x ∈ [-1024, -760]`, `z ∈ [-400, 800]`
  (`Layout.inField`). Material `rough` (autumn grass/stubble). They are the reason this is European
  farmland-and-woods rather than a forest tile, they are visible from the assembly track, and they cost
  nothing but a material test.
- **The bog moves out of the way**: `x = -820, z = -300, radius 120, depth 6`, `Mud`, still outside the
  corridor (`minX = -620`), with alder around it by §7.1's rule. Row 44a(c) — "it reads as a grey mud
  flat, not wet ground" — stays open and is Karen's, because `Water` is forbidden in v1 (§1.2).
- **One flank track**, along z at `x = 880`, half-width 5, **material only** (`Ground.paintTrack`), so
  the field has a farm track in it. The v2 tracks at `x = -250` and `z = 430` are gone: one crossed the
  drive, and the drive is now a wood with a road in it.

---

## 8. Autumn: the palette

### 8.1 What can actually be coloured

Roblox terrain has no leaf-litter material. The lever is **per-material colour**, one global table for
the whole place, and the materials in play are the four `Config.MATERIAL` already uses:

| Role | Material | Autumn colour (`Map.PALETTE`) | Where |
|---|---|---|---|
| `litter` | `LeafyGrass` | RGB(150, 108, 62) | the forest floor — the wood's default |
| `rough` | `Grass` | RGB(126, 122, 78) | steep ground, clearings, the flank fields |
| `road` | `Ground` | RGB(152, 146, 132) | the road bench, the assembly bench, the flank track |
| `bog` | `Mud` | RGB(96, 82, 62) | the bog |

`Ground.surfaceMaterial` gains two cases in front of its existing slope test: **bench → `road`**, and
**`Layout.inField` → `rough`**. Everything else in the wood is `litter`, and a steep column is `rough`
(as built, `ROUGH_SLOPE = 0.3`).

### 8.2 The owner, and why it is this one

Terrain material colour is global state with no container, exactly like the voxels. `MapGen.Ground` is
already **the only writer of `Terrain` in the repo** (`Ground.writeTile`, `Ground.clear`), so it takes
the palette too: `Ground.applyPalette(palette)`, `Ground.readPalette()`, `Ground.resetPalette(default)`.
No second writer, anywhere, ever.

### 8.3 The measurement this rests on, and the fallback if it fails

**Not verified in this session** (read-only, no engine): that `Terrain:SetMaterialColor` /
`GetMaterialColor` are callable from `execute_luau` in Edit, that the colours are saved with the place,
and that they replicate to a client. **Measurement N1** (§16.5) settles all three, and the research note
records it (rule 1).

**Named fallback, so the task cannot stall:** if the API is unreachable or the colours do not persist,
the palette degrades to a **material-choice** table — pick the material whose *default* colour is
nearest each role (`Ground` for litter, `Grass` for rough, `Slate` for the road, `Mud` for the bog) —
and `Map.PALETTE` becomes that table. The design's shape does not change; one function becomes a
mapping instead of four writes.

### 8.4 `clear` must restore the palette, and the spec must catch it if it does not

A palette outlives `Terrain:Clear()` if nothing restores it. That matters because while
`Map.EXPECTED_WORLD == "arena"` the harness asserts the place holds **no** generated world
(`Ground.cells() == 0`, audit-004 must-fix 1) — and an autumn palette left behind after a `clear` is
exactly the "world nobody chose" that audit found. So:

- `MapGen.clear` calls `Ground.resetPalette(Map.PALETTE_DEFAULT)` and returns
  `paletteRestored: boolean`, measured by reading the colours back — never asserted as a literal.
- `tests/server/map_contract.spec.luau` asserts, **in the arena branch**, that every material's colour
  equals `Map.PALETTE_DEFAULT`; and **in the map branch**, that it equals `Map.PALETTE`.
- `MapGen.digest` includes the palette in its canonical text (`Digest.of(entries, samples, round,
  palette)`), so a hand-edited colour changes the digest instead of silently becoming the map.

---

## 9. Markers on the road

### 9.1 The eight posts

`Layout.markers` keeps its shape; the numbers change. Post `i` sits at
`x = (i − (postCount + 1) / 2) × postSpacing`, `z = Map.ROAD.z`:

```
x = -560  -400  -240  -80  +80  +240  +400  +560      (8 posts, 160 studs apart, span 1,120)
```

160 studs is **45 m**, inside Karen's 40–80 m, and it is her value to move
(`Config.WORLD.postSpacing`, marked K). 8 posts serve 16 players at an equal split. Marker size
`(6, 1, 6)` at `GROUND_Y + 0.5` (§4.3), on the road bench, so every post's bottom face is at
`GROUND_Y` and the contract check has one number to compare.

### 9.2 The line, the crossing, and the exit

- **`DriveLine`**: one part, `(1240, 1, 1)`, at `z = -700`, `LookVector` → +Z. The road **is** the drive
  line; there is no second concept.
- **`exitZ = -820`**: the boar's flee target is 120 studs **past** the road, in the far wood. So a boar
  that beats the line crosses the gravel in front of a shooter and disappears into trees — which is
  what Karen's references show, and what makes a missed crossing feel like a miss rather than a
  despawn. `corridor.minZ = -880` keeps the exit inside the rectangle
  (`src/server/Boar/Brain.luau`, `Brain:_outcome`, despawns on the exit edge).
- **Between two shooters**: nothing in the map arranges this. It is what falls out of a boar fleeing to
  the exit from wherever the drivers pushed it, across a line whose posts are 160 studs apart. The
  crossing is `map-crossing` in §16.3, and Karen judges it.

### 9.3 The driver start

`z = +700`, on the assembly bench, part `(1120, 1, 20)`, so `Body.placementFor`'s driver branch spreads
eight drivers over 1,116 studs — about 140 studs (39 m) apart, a real driving line rather than a
huddle. `Map.ASSEMBLY` flattens it.

### 9.4 The tie trees

12, at `z = -745`, evenly over the 1,120-stud span (`Layout.tieTreePoints`, as built). They are now
**behind the shooters in the far wood**, which is where a punished shooter should be put: within sight
of the post they left, out of everyone's line of fire, and never between a shooter and the drive.
`Body.anchorFor` picks the nearest, so nobody is tied more than ~100 studs from where they stood.

---

## 10. Outfits: an orange hat and an orange vest

The brief's item 3. This is **not** the map generator's, and it gets an owner here so it never gets two.

### 10.1 Owner

**`ServerScriptService.Match` → `Match.Body`** (`src/server/Match/Body.luau`). It is already the only
writer of a player's team (`Body.setTeam`), of where their character stands (`Body.place`,
`Body.placementFor`) and of what is attached to it (`Body.tie` writes `WalkSpeed`, anchors the root and
builds the rope). An outfit is one more thing written onto the character at the same moment, by the
same module, on the same signal. **Not the Hud** (it draws the screen, not the world), **not the
client** (a client-drawn outfit is per-client and cannot be trusted or screenshotted on the server),
**not the map**.

### 10.2 The grey-box version, exactly

On the `CharacterAdded` handler `Body.place` already connects (before `LoadCharacter`, which is the
whole point of that function), and again on a re-tie:

```luau
-- src/server/Match/Body.luau
Body.OUTFIT_NAME = "HuntOutfit"                  -- one folder per character; destroyed and rebuilt

function Body.dressFor(team: TeamName?, config): { { name: string, limb: string,
                                                     size: Vector3, offset: Vector3,
                                                     color: Color3 } }
    -- PURE. "Shooters" -> one hat on the Head; "Drivers" -> one vest on the UpperTorso.
    -- A spec calls this with a table and asserts both branches; nothing here touches an Instance.

function Body.dress(character: Model?, team: TeamName?, config): boolean
    -- Destroys any existing HuntOutfit folder, then for each row in dressFor:
    --   Part: Anchored = false, Massless = true, CanCollide = false, CanQuery = false,
    --         CastShadow = false, Color = row.color, welded to the limb with a WeldConstraint.
    -- Returns false when the character or a limb is missing, so the owner counts a miss
    -- rather than believing a change it did not make (the Body.tie discipline).
```

| Role | Part | Size (studs) | Attached to | Colour |
|---|---|---|---|---|
| Shooter | `Hat` (a flat cylinder) | 2.2 × 0.6 × 2.2, +0.8 above the Head's centre | `Head` | **RGB(255, 112, 0)** hunter orange |
| Driver | `Vest` (a thin box) | 2.2 × 1.6 × 1.3, on the torso front | `UpperTorso` (fallback `Torso`) | **RGB(255, 112, 0)** |

Four properties that are not tidiness:

1. **`CanQuery = false`.** A hat or vest that stops a pellet changes what the shot hit, which feeds
   `Match.Penalty` through the weapon's report (`src/server/Match/Penalty.luau`, `Penalty.judge`, uses
   the shot's own reach and line). The outfit must be invisible to every ray in the game.
2. **`Massless = true`, not anchored.** `Body.tie` anchors the *root*; an anchored hat would pin the
   character's head to the world.
3. **Cosmetic only, and never a source of truth.** Karen's brief says the safety rule "can use them to
   read who is where": that is the **player's** reading. `Penalty.judge` keeps deciding from teams
   (`Body.teamOf`), because two representations of one fact is this project's named failure mode.
4. **The team colours already exist and stay**: `Body.TEAM_COLORS` is `Bright orange` for Shooters and
   `Bright blue` for Drivers. The outfit is additional, and orange-on-both is deliberate — in the field
   both sides wear safety orange; the Hud's badge and the team colour are what say which side you are.

### 10.3 It merges OFF

Per the brief, and per `docs/design/feature-flags.md`:

- **If `ReplicatedStorage.Flags` exists** when this task is built (`src/shared/Flags/init.luau` is
  **not** in the tree at this commit — `.agent-evidence/ls-files.txt`): one row,
  `ORANGE_OUTFITS`, `default = false`, `owner = "ServerScriptService.Match"`, and `Match.CONFIG` reads
  it once at require time, which is the only permitted shape (`feature-flags.md` §10).
- **If it does not**: `Match.CONFIG.OUTFITS_ENABLED = false`, the existing pseudo-flag pattern that
  `feature-flags.md` §14 item 4 explicitly leaves in place beside `Match.CONFIG.DRIVERS_MAY_SHOOT`.

Either way `Body.dressFor` takes the boolean as an argument, so **both states are testable with nothing
to restore** (`feature-flags.md` §13.3).

`docs/design/drive.md` must mirror this section at its next regeneration — it owns `Match.CONFIG` and
`Match.Body`'s contract. Named as a delta in §19.1 rather than left to be discovered.

---

## 11. What the drive needs from the map for sounders — and what it does not get here

The brief's item 2 (groups of 2–5, leader-follower or boids, the config numbers, the feature flag) is
**`docs/design/drive.md`**'s and `docs/design/boar-ai.md`'s, not this file's. What the map guarantees,
so that design can be written against something:

1. **Four `DrivenHunt.BoarSpawn` markers**, at `z = +600`, `x = ±150, ±450`, each on a **flat disc of
   radius `Map.SPAWN_PAD.radius = 30`** at exactly `GROUND_Y`. A group spawned anywhere inside that
   disc stands on level ground.
2. **The pad is the contract for a group's spread.** `docs/design/drive.md` must keep every member's
   spawn position within `Map.SPAWN_PAD.radius` of the marker — at 30 studs that is five boars at
   ~12-stud spacing with room. Outside it, `src/server/Boar/init.luau`, `Runtime:spawn`, overwrites the
   caller's Y with `field.groundY + BODY_SIZE.Y/2 + SPAWN_CLEARANCE`, and a member placed on a slope is
   spawned **inside a hill** — the fact §6 exists for.
3. **Clearance from trunks.** `Layout.treeDensity` returns 0 inside a pad plus a 6-stud margin, so no
   group member is spawned inside a tree.
4. **`MAX_ALIVE_BOARS` is the drive's number, and `Boar.CONFIG.maxBoars = 8` is the boar's guard**
   (`docs/design/drive.md` §6.3). A group of five plus a 120-second carcass is a real pressure on both;
   the map does not decide it, and the map does not need more than four spawn markers to support it —
   a sounder is one release at one marker, not four.
5. **Nothing about a group is in the map's digest, contract or specs.** If a later drive design wants
   eight spawn markers instead of four, that is `Config.WORLD.boarSpawnX`, `Map.EXPECTED_COUNTS` and one
   line in the contract spec.

---

## 12. Assets and proxies

### 12.1 The keys

`MapGen.Assets.KEY` grows from two to six. The grammar and the first three names are
`docs/design/asset-pipeline.md` §12.1's exactly, so no key is renamed when the manifest moves:

```luau
Assets.KEY = table.freeze({
    treeSpruce = "tree.spruce.a",
    treeBirch  = "tree.birch.a",
    treeOak    = "tree.oak.a",
    treeAlder  = "tree.alder.a",   -- NEW: not yet in asset-pipeline §12.1 (§19.1 delta A2)
    hedge      = "hedge.mixed.a",
    brush      = "prop.brush.a",   -- NEW (§19.1 delta A2)
})
```

`Assets.ROWS` stays **empty**, and that is a state and not a hole: `Props.template` returns `nil`, and
every placing step draws a proxy of the right footprint (`Props.placeTree`, `placed`). **The whole map
is buildable and walkable today with no asset id and no decision from anyone**, and each id later
replaces one proxy with no code change.

### 12.2 The manifest's owner, and the one thing not to do

`docs/design/asset-pipeline.md` §2.1 puts the manifest, the licence bases and the single id→Instance
seam in `ServerStorage.Assets`, and its §2.3 explains why it may not live in `MapGen`: a runtime script
(`Boar.Body`) needs an id, and a manifest inside a build tool forces either a runtime require of that
tool or a second copy of the ids.

**The built code kept `MapGen.Assets`** (`src/serverstorage/MapGen/Assets.luau`), because M2.7a has not
landed. That is accepted as a temporary state with one rule: **`MapGen.Assets` is the only copy.** When
M2.7a lands, `MapGen.Props` moves onto `Assets.Loader` (`asset-pipeline.md` §6.8, M2.7d) and
`MapGen.Assets` is archived under `backups/` with a note (rule 7). No task may add a second id table
anywhere in the meantime.

### 12.3 The licence gate stays, and it fires on baking

Baking **is** shipping: a prop baked into the place is published with it. So before a real template is
used, the key's licence basis must permit shipping (`asset-pipeline.md` §4.5). While the manifest is
`MapGen.Assets`, the row carries `licenceNote` and `source` and the gate is: **no row without a
resolved licence, and a blocked row proxies and says which key and which basis.** Karen's Meshy-plan
answer still decides whether free-plan Meshy output may ship (`asset-pipeline.md` §16 Karen 1) — it
gates M2.3, not this revision.

---

## 13. What this system reads and writes across other systems

| Direction | What | The other side's owner | Evidence |
|---|---|---|---|
| **writes** | `Terrain` voxels **and material colours** | `MapGen.Ground` — the repo's only Terrain writer | `src/serverstorage/MapGen/Ground.luau`, `Ground.writeTile`, `Ground.clear`; §8.2 |
| **writes** | `Workspace.DrivenHuntMap` and every descendant | `MapGen.Props`, `MapGen.Markers` | `Props.trees`, `Markers.place` |
| **writes** | `Workspace.StreamingEnabled` | `MapGen.Settings`, refusing while `MAY_WRITE == false` | `Settings.apply` |
| **writes** | `CollectionService` tags on map instances, at edit time | `MapGen.Markers` | `Markers.place`, `Markers.tagTieTrees` |
| **reads** | `Map.TAGS`, `Map.FIELD`, `Map.SPAWN_PAD`, `Map.ROAD`, `Map.ASSEMBLY`, `Map.PALETTE`, `Map.STREAMING`, `Map.BUDGET`, `Map.GENERATOR` | nobody writes them at run time | `src/shared/Map/init.luau`; reached through `MapGen.Contract` |
| **reads** | `Boar.CONFIG.AGENT`, at **edit time only**, inside a pcall | `ServerScriptService.Boar` | `MapGen.reachability` |
| **is read by** | the five `DrivenHunt.*` tags, at run time | `Match.Markers` (`Markers.read`), which validates, reports what is missing and keeps the match in `Waiting` | `src/server/Match/Markers.luau` |
| **is read by** | the ground, by the boar's pathfinding | `ServerScriptService.Boar` — `Boar.defaultWorld`'s `requestPath` | `src/server/Boar/init.luau` |
| **is read by** | the ground, the trunks and the crowns, by the shotgun's rays | `ServerScriptService.Weapon` — `Weapon.Cast` is that system's only `Workspace:Raycast` caller | `src/server/Weapon/Cast.luau` |
| **is read by** | post parts and the driver start, when a character is placed | `Match.Body` | `Body.placementFor`, `Body.place` |
| **is read by** | tagged trees, when a shooter is tied | `Match.Body` | `Body.anchorFor`, `Body.tiePointFor` |
| **constrains** | `Boar.CONFIG.field` must equal `Map.FIELD` | `ServerScriptService.Boar` owns the change, at M2.5 | `tests/server/map_contract.spec.luau` asserts the equality |
| **hands over** | the orange outfits | **`Match.Body`** (§10), not this system | `src/server/Match/Body.luau` |
| **hands over** | sounders: sizes, spacing, leader-follower, scatter-on-shot, the flag | **`docs/design/drive.md`** and `docs/design/boar-ai.md` (§11) | `reviews/task-54/BRIEF.md` item 2 |

**Nothing else.** No change to `src/server/Boar/Brain.luau`, `Body.luau` or `Wound.luau`; no change to
any weapon, camera or Hud module; no change to `tools/studio_mcp.py`; no change to
`default.project.json`.

---

## 14. External sources

**How each was read, because this repo has three recorded cases of a design citing a page that said
something else** (`TASKS.md` row 26a; `docs/research/INDEX.md`):

- **This session had no network.** Nothing below was fetched by me.
- Sources 1–3 and 5–6 are quoted from repo research notes whose sessions did have network, and those
  notes are their citation of record. Where a note and this file differ, **the note is right**.
- **Source 4 and the two API members in source 1 marked "unfetched" are the Builder's to confirm before
  code** (rule 1, and they are measurements N1 and N2 in §16.5).

### 1. Roblox `Terrain` — voxels, and material colour
<https://create.roblox.com/docs/reference/engine/classes/Terrain>
Licence: first-party documentation (creator-docs source is CC BY 4.0); the API ships with the engine.
Maintenance: actively maintained.
**Good:** `WriteVoxels(region, resolution, materials, occupancy)` takes occupancy as well as material,
which is what makes smooth ground from a heightfield rather than steps; `ReadVoxels` gives the digest a
cheap canonical sample; `CountCells` is the only number that can tell a 6.3 M-voxel heightfield from an
empty world (audit-004 must-fix 1); `Clear()` is the reset.
**Bad:** the page showed `resolution = 4` throughout without saying it was the only legal value — the
build measured it (`"Resolution has to be 4"`, recorded in `Config.luau`) — and gives **no** region
size cap, which is why the tile is a conservative 128 × 128 × 96. **And `SetMaterialColor` /
`GetMaterialColor` were not fetched in this session**: their availability, persistence and replication
are measurement N1, with §8.3's fallback if the answer is no.
**Adopted:** `WriteVoxels` per tile at resolution 4 with `Region3:ExpandToGrid(4)`; the palette through
one owner; `CountCells` as the proof a build ran.

### 2. Roblox `math.noise`
<https://create.roblox.com/docs/reference/engine/libraries/math>
Licence: first-party (CC BY 4.0 docs). Maintenance: actively maintained.
**Good:** Perlin noise in the standard library, so the generator needs no dependency at all.
**Bad:** no output range, no determinism promise across sessions or engine versions, and **no seed
parameter** — the largest unproven assumption in the system.
**Adopted:** `math.noise` with a seed-derived coordinate offset (`Height.offset`), plus
`mapgen.py verify` as the standing check that it is stable, plus the named fallback of a small seeded
value-noise function in `Height.luau`. The species field (§7.1) uses the same function at a low
frequency, which costs nothing new.

### 3. Roblox `PathfindingService`
<https://create.roblox.com/docs/characters/pathfinding>
Licence: first-party. Maintenance: actively maintained. Already the boar's source of record
(`src/server/Boar/init.luau` header).
**Good:** `CreatePath(agentParams)` + `ComputeAsync` gives a **machine verdict on whether the wooded
drive is playable for the boar**, using the boar's own `AgentRadius = 2`, `AgentCanJump = false`. That
verdict is what makes §7's deletion of the corridor rejection safe to ship.
**Bad:** no documented maximum walkable slope and no slope field in the agent params, so
`CORRIDOR_MAX_SLOPE_DEG = 15` is a **conservative target, not a derived limit**; and the build measured
that Studio rebuilds its navmesh in the background (`Success` after 1 s, `NoPath` after 5), which is why
`REACH_SETTLE_SECONDS = 6` exists. Whether ~3,000 collidable trunks slow `ComputeAsync` materially is
**measurement N2**.
**Adopted:** the reachability check as the empirical gate, now to five points along the line; the
geometric argument in §7.3 as the thing that has to be true anyway.

### 4. Red Blob Games — "Making maps with noise functions" (Amit Patel)
<https://www.redblobgames.com/maps/terrain-from-noise/>
Licence: an article, © Amit Patel, free to read, code snippets published for reuse (not a package
licence). Maintenance: long-lived and revised; the canonical reference on the technique.
**Not fetched this session** — cited from knowledge, and the Builder records it in the research note
with a fetched quote (rule 1) before writing `Height.benchBand` or `Scatter.speciesAt`.
**Good:** it is the standard treatment of **shaping noise with a separate mask** (`elevation × mask`),
which is exactly the shape of the three masks in §6.2, and of using **a second, low-frequency noise
field to choose biomes** rather than deriving them from elevation — which is precisely the species field.
**Bad:** 2D tile-map oriented; nothing about voxels, nothing about Roblox, and nothing about guaranteeing
a *traversable* result, which is the property this map actually has to have.
**Adopted:** mask-multiplication for the corridor and bench bands; a `max()` floor for the map edge; a
separate low-frequency field for species. **Invented here:** the **bench** (a flat strip at a fixed
height with an eased verge and a tapered end) — no source I can cite does a road in Roblox voxel
terrain, and the reason to invent rather than borrow is written in §6.3: everything the game stands on
must be at exactly one height, which no general terrain technique gives you.

### 5. Instance streaming
<https://create.roblox.com/docs/workspace/streaming>
Licence: first-party. Maintenance: actively maintained.
**Good:** gives the defaults the contract adopts verbatim, with Roblox's own reasoning.
**Bad:** the build measured that **four of the five properties are not reachable from Luau at all**
(`Settings.apply` reports them as unreachable) and that `StreamingEnabled` was **already true** in the
DEV place — so M2.6 is a Karen click plus a playtest, not a line of code, and the design's old
"streaming is off until M2.6" assumption was wrong. `src/shared/Map/init.luau`'s `Map.STREAMING` comment
is the record.
**Adopted:** the documented numbers as the values M2.6 sets by hand; `Settings.MAY_WRITE = false` until
then.

### 6. The driven hunt itself — Deutscher Jagdverband, plus Karen's references
DJV driven-hunt guidance, fetched and quoted in `docs/research/2026-09-25-drive.md` §2/§2b (that note is
the citation of record).
Licence: the association's own publication. Maintenance: a live page, updated.
**Good:** it is primary on the two things the geometry has to respect — the rule is *"in the direction
of fellow hunters"* rather than a cone (which is why `Penalty.judge` is a line test, not an arc), and
the neighbour rule comes with a number: *"Der Schusswinkel zum Nachbarn muss grösser als 30 Grad
sein"*. At 160-stud spacing on a straight road, a boar crossing 40 studs in front of a shooter sits at
about 14° to the neighbour's stand — **so this geometry makes the v1.1 neighbour rule
(`TASKS.md` row 35a) matter, and Karen should know that before she likes the spacing.**
**Bad:** it is safety guidance, not map geometry: it gives no road width, no stand spacing in metres and
no stem density. **Those come from Karen's reference images**, described in `reviews/task-54/BRIEF.md`
and not otherwise verifiable by me: *mixed deciduous/coniferous forest, autumn leaf litter, a
gravel/earth forest road, shooters ~40–80 m apart.* This design treats the brief as the authority for
them and says so.
**Adopted:** the road, the 45 m spacing, the autumn palette, the four species, and the orange outfits —
all from Karen, all marked K where she may move them.

**Also considered and rejected, so they are not re-proposed:** Studio's Terrain Editor Import and
Generate (UI-only, unreachable from code or MCP, and their state is not a file); heightmap PNGs as the
source of truth (unreviewable as a diff, which is what the code-generated map exists to avoid); real
stem density (§7.2: 12,000–25,000 parts against a 20,000-part whole-place budget); `Water` for the bog
(§1.2); a `SurfaceGui` numbering each post (a second drawer of UI — the Hud is the UI owner); brush that
blocks shot (§7.4, Karen's call, not a default).

---

## 15. Numeric targets

**K** = Karen's taste value: a number she changes after walking it, not a measurement.
Derived at **1 stud = 0.28 m** (`docs/research/2026-09-24-map-generator.md` §1).

### 15.1 The world

| Quantity | Value | K? | Basis |
|---|---|---|---|
| Map size | **2048 × 2048 studs** (573 m), centred on the origin | | unchanged; ~2 × `StreamingTargetRadius` |
| `GROUND_Y` | **0** | | matches `Boar.CONFIG.field.groundY`, so the switch needs no boar change |
| Relief, whole map | **± 40 studs** | K | gentle; inside `Boar.CONFIG.FALL_LIMIT = 50` |
| Relief in the corridor (`CORRIDOR_RELIEF`) | **± 16 studs** | K | as built |
| Relief within `BENCH_BAND` of a bench (`BENCH_RELIEF`) | **± 6 studs** | | **NEW**: 6 studs over a 24-stud verge is 14.0°, inside the 15° ceiling |
| `BENCH_BAND` | **120 studs** | | **NEW**; smoothstepped |
| `EDGE_MAX_Y` / edge band | **44 studs / outer 100 studs**, as a floor, suppressed near a bench | | **NEW**; 44 < `BAND_Y.max = 48`, so the measured tile size is unchanged |
| `CORRIDOR_MAX_SLOPE_DEG` | **15°** | | conservative (§14 source 3); measured over **3 seeds** by the slope spec |
| Drive corridor | x ∈ **[−620, +620]**, z ∈ **[−880, +800]** | | **CHANGED**: 1,240 studs wide (347 m), to hold a 1,120-stud shooter line |
| `exitZ` | **−820** | | **CHANGED**: 120 studs past the road — the boar crosses and is gone |
| Drive length (start → line) | **1,400 studs** (392 m) | K | unchanged; ~88 s at a default `WalkSpeed` of 16 |
| The forest road | z = **−700**, half-width **8** (16 studs = 4.5 m), verge **24**, x ∈ [−900, 900] | K | Karen's reference: a gravel/earth ride |
| The assembly track | z = **+700**, half-width **5**, verge **20**, x ∈ [−700, 700] | | flattens the 1,120-stud `DriverStart` |
| Shooter posts | **8**, spacing **160 studs** (45 m), span **1,120** | K | Karen: 40–80 m. `Config.WORLD.postSpacing` |
| Post marker | **6 × 1 × 6**, centre at `GROUND_Y + 0.5` | | **CHANGED** from 4 × 6 × 4: closes the 9.5-stud drop (row 43a(l), audit-004 F9) |
| Drive line part | **1240 × 1 × 1** at z = −700, `LookVector` → **+Z** | | the corridor's full width |
| Driver start | part **1120 × 1 × 20** at z = +700 | | ~140 studs per driver at 8 |
| Boar spawns | **4**, z = **+600**, x = **−450, −150, +150, +450** | K | widened with the corridor |
| Spawn pad | radius **30**, blend **40**, tolerance **0.75** | | **CHANGED** radius (a sounder, §11); blend 40 is the measured value now adopted (row 45a(a)) |
| Tie trees | **12**, z = **−745**, span **1,120** | | behind the line, in the far wood |
| Fields | x ∈ ±[760, 1024], z ∈ [−400, +800] | K | the flanks stay farmland |
| Hedge lines | **3**: along z at x = ±760; along x at z = +300 (**2 gates**, 96 studs each) | K | 6,144 studs, ~250 parts (closes row 44a(a)) |
| Flank track | along z at x = **880**, half-width **5**, material only | | |
| Bog | x = **−820**, z = **−300**, radius **120**, depth **6**, `Mud`, **no Water** | K | outside the corridor |

### 15.2 The wood

| Quantity | Value | K? | Basis |
|---|---|---|---|
| Tree candidate spacing / jitter | **22 studs / 0.5** | | jitter 0.5 is forced by §7.3: it gives an 11-stud minimum separation and a 6-stud clear gap against `AgentRadius = 2` |
| Density weights (dense / drive / backdrop) | **1.00 / 0.42 / 0.14** | K | §7.2; the single biggest lever on "does this read as a wood" |
| Dense band | within **260 studs** of the road, \|x\| ≤ 700 | K | where the shooter's eye actually is |
| Trees placed | **~2,925 estimated**, hard ceiling `Map.BUDGET.trees = 3000` | | the estimate is from areas; **the Builder measures it and the step fails over budget** |
| Species mix | spruce **0.40**, birch **0.25**, oak **0.20**, alder **0.15** | K | Karen's four species |
| Species clump frequency | **1/260 studs⁻¹** | K | clumps read at ~70 m |
| Alder rule | forced where `bogDepth > 0` or ground < −6 | | black alder is a wet-ground tree |
| Tree heights | spruce **71**, birch **64**, oak **64**, alder **57** studs | | matches `asset-pipeline.md` §12.1's `sizeStuds`, so the proxy teaches the truth |
| Trunk / crown physics | trunk `CanCollide` **true**, `CanQuery` **true**; crown `CanCollide` **false**, `CanQuery` **true** | | §7.1: the navmesh sees trunks, the canopy still stops a shot |
| Brush | **500**, proxy 10 × 5 × 10, `CanCollide`/`CanQuery` **false** | K | cover for the eye only (§7.4) |
| Hedge segment | **24 studs**, part 24 × 7 × 3 | | as built; 24 keeps the part count inside 400 |
| Proxy albedo floor | **no channel maximum below 120** | | the Task 22 albedo measurement |
| Total parts | **≈ 6,650** of `Map.BUDGET.parts = 20000` | | 2,925 × 2 + 500 + 250 + 24 + 14 |
| Visible parts at once | target **≤ 8,000** | | streaming target radius 1,024 |

### 15.3 The generator and the run

| Quantity | Target | Basis |
|---|---|---|
| Voxel resolution | **4** | **measured**: 8 and 2 are both refused, `"Resolution has to be 4"` |
| Tile per `WriteVoxels` | **128 × 128 × 96 studs** = 24,576 voxels | measured as accepted; unchanged, which is why `EDGE_MAX_Y` is a floor and not a sum |
| Steps per build | **285** (1 clear, 1 palette, 256 terrain, 3 hedgerow, 1 track, 16 trees, 4 brush, 1 stand, 1 markers, 1 settings) | §5.1 |
| Per-step wall clock | **≤ 60 s**, hard timeout `MAPGEN_CALL_TIMEOUT = 180 s` | `Studio._rpc` defaults to 120 s (`tools/studio_mcp.py`) |
| Full build | **≤ 25 min** | 256 tiles at ~4 s dominate; edit time, so slow is fine and unrepeatable is not |
| Tree block | **512 × 512 studs**, ~180 trees, ~360 parts, ≤ 10 s | one step per block, idempotent, retryable |
| Determinism | **identical digest** from two builds at one seed | hard requirement; `mapgen.py verify` fails otherwise |
| `DIGEST_TERRAIN_SAMPLES` | 4,096 (64 × 64), round 100, **plus the palette** | §8.4 |
| `REACH_SETTLE_SECONDS` | **6** | measured: the navmesh lags the map by ~5 s |
| Reachability computes | **5 froms × 5 targets = 25** | §16.4; closes row 44a(e) |
| `BACKUP_MAX_AGE_HOURS` | 6 | as built |

---

## 16. How it is tested

### 16.1 Server specs

`tests/server/map_contract.spec.luau` runs in the ordinary harness Play session and asserts **the world
the committed contract names**, so neither branch is empty (as built). Checks 1–13 stay; these change or
are added:

1. *(unchanged)* exactly one of `Workspace.TestArena` / `Workspace.DrivenHuntMap` exists — the one
   `Map.EXPECTED_WORLD` names — and `Ground.cells()` is 0 in the arena branch, > 0 in the map branch
   (audit-004 must-fix 1). Row 47a(c): read it through **`Ground.cells()`**, the one function that
   answers that question, not `Workspace.Terrain:CountCells()` again.
2. *(unchanged)* every tag resolves to exactly `Map.EXPECTED_COUNTS`, inside the named world's root.
3. *(unchanged)* exactly one `DrivenHunt.DriveLine`, `LookVector:Dot(Vector3.zAxis) > 0.99`.
4. **CHANGED.** Every `BoarSpawn`'s `Position.Y` within `Map.SPAWN_PAD.tolerance` of
   `Map.FIELD.groundY`; **4b** every `ShooterPost`'s bottom face and the `DriverStart` part's four
   corners likewise; **4c NEW** every post's `|z − Map.ROAD.z| <= Map.ROAD.halfWidth` — a post off the
   road is a shooter standing in the wood.
5. **NEW.** `Terrain:GetMaterialColor` for the four palette materials equals `Map.PALETTE_DEFAULT` in
   the arena branch and `Map.PALETTE` in the map branch (§8.4).
6. *(unchanged)* no `LuaSourceContainer` under the named world root.
7. *(unchanged)* `Boar.CONFIG.field` deep-equals `Map.FIELD`.
8. *(map branch)* part count ≤ `Map.BUDGET.parts`; **NEW** trees ≤ `Map.BUDGET.trees`, brush ≤
   `Map.BUDGET.brush`, hedge parts ≤ `Map.BUDGET.hedgeParts`, **and each ≥ half its budget** so an
   empty wood fails instead of passing.
9. *(unchanged)* every descendant of `ServerStorage.MapGen` is a `ModuleScript`.
10. **NEW.** `MapGen.VERSION == Map.GENERATOR` (row 44a(f)).
11. *(map branch, M2.5)* the live `markerDigest` equals the committed half.

**The pure specs, which need no world and run in both branches** — this is where most of the new
geometry is actually proved:

| Spec | Asserts |
|---|---|
| `Height` | pads exactly `GROUND_Y` at centre; **benches exactly `GROUND_Y` at 200 points on each centreline**; at `verge + 1` outside a bench the unflattened height returns; `edgeFloor` never exceeds `EDGE_MAX_Y`; determinism for a fixed seed |
| slope | over **three seeds**, on a 20-stud lattice across the corridor, the worst slope **< 15°** *and* **> 0.02°** (the lower bound closes row 45a(b): the v2 assertions were identities that a flat map would pass) |
| `Layout` | marker counts and spacing; the road's span covers every post; `inField` and the benches do not overlap; `treeBlocks` tile the map exactly once |
| `Scatter` (walkability) | over **20 seeds**: minimum pairwise distance among corridor trees ≥ `TREE_SPACING × (1 − SCATTER_JITTER)`; no tree inside a bench, verge, pad + margin, track, bog or hedge clearance; density per 10,000 studs² never above the dense tier's rate (§7.3) |
| `Scatter.speciesAt` | the mix is within ±25 % of the configured shares for the committed seed; **every** tree in the bog's radius is alder; the four species are the only outputs |
| hedges | each corridor-crossing line leaves a gap ≥ `gateStuds − segmentStuds` (`Layout.widestGap`), measured from the segments actually placed |
| `Digest` | stable for a fixed input; **changes when a palette colour changes** (§8.4) |

### 16.2 Client spec — `tests/client/map_client.spec.luau`

1. `Workspace.StreamingEnabled == Map.STREAMING.enabled`.
2. The local character is standing on something: a downward ray from the root hits within 12 studs.
   (A character in the void measures fine — this project shipped "measured correct, looked wrong".)
3. `RequestStreamAroundAsync(driveLinePoint)` returns within 10 s and the `DrivenHunt.DriveLine` part is
   non-nil on the client afterwards.
4. **NEW, and honestly bounded:** the palette the client sees equals the palette the server does — *if*
   measurement N1 says material colours replicate. If they do not, this assertion is **removed and the
   fact recorded**, not weakened into something that passes either way.

### 16.3 Screenshots (rule 5) — `python tools/mapgen.py shots`

Eight named Edit-mode captures through `Studio.capture`. The v2 names were written for a field-edge map
and three of them no longer answer anything (row 43a(c) already flagged the drift); these replace them.
**The Builder inspects each and says what it shows.**

| Name | Camera → look-at | Answers |
|---|---|---|
| `map-wide` | (0, 1100, 1500) → (0, 0, −200) | is there a map, does it read as wood-with-fields, is the road visible as a line through it |
| `map-road` | (−500, 6, −700) → (500, 6, −700) | **the shot this revision exists for**: standing on the road, do the posts read at 160-stud spacing, is the gravel gravel |
| `map-post` | (−80, 6, −700) → (−80, 4, −300) | a shooter's view into the drive: how far can he see, how much of the frame is trunk |
| `map-crossing` | (0, 4, −540) → (0, 3, −780) | a boar's-eye crossing between the two middle posts: is the road a real gap in the wood |
| `map-drive` | (0, 6, 600) → (0, 4, 100) | a driver's view into the wood from the assembly track |
| `map-autumn` | (0, 3, −640) → (30, 0, −680) | the colours at eye level: leaf litter, four species, brush |
| `map-bog` | (−820, 40, −140) → (−820, 0, −300) | the bog, and whether it is a feature or an annoyance |
| `map-edge` | (600, 8, −700) → (1024, 6, −700) | does the map's edge read as a void where the road leaves it (§6.2) |

**A proxy map is still a rule-5 subject.** Row 43a(a) and row 44a(b) — "two green lollipops", "green
boxes on stalks" — were honest readings of a 22-stud grey-box tree. With §7.1's heights and colours the
same screenshots should read as a wood; if they do not, **that is the finding**, and it is Karen's to
judge, not a number's.

### 16.4 `tools/mapgen.py` — unchanged in shape, two changes in substance

Commands, refusals (dirty tree, not Edit, wrong `PlaceId`, Studio's copy ≠ disk, no accepted backup,
orphan terrain), `--backup census`, the run log and the `[mapgen] OK:` line are **as built** and
unchanged. Two changes:

1. **`reachability` paths to five points along the drive line** — both ends (x = ±560), both quarter
   points (x = ±280) and the centre — from each of the four boar spawns and the driver start. Row
   44a(e): a boar that can reach the centre but not one end used to pass. `Reach` gains a `to` field.
2. **`shots`** takes §16.3's eight names.

The `[mapgen]` line is **not** a harness line and never substitutes for one (`CLAUDE.md`, git workflow
step 4). Row 43a(p): the docstring must name both `build`'s and `verify`'s final lines.

### 16.5 What the harness cannot do here, stated rather than discovered

- **It cannot judge whether the wood reads as an autumn European wood, or whether 45 m between posts
  feels like a hunting line.** Only Karen can.
- **It cannot run the generator**, by design: `tools/studio_mcp.py` is read-only by construction, and
  `tools/mapgen.py` is invoked by hand.
- **It cannot save the place**, and neither can `mapgen.py`. There is **no tool route to
  `File → Save to File`** at all, which is why the backup rule has two accepted forms.
- **It still cannot prove tags survive a save and a reopen** (measurement B, open since Task 43: it
  needs a Save to File and a reopen, which are clicks no tool here can make).
- **`test2` is not evidence for the map itself** — the map changes nothing about two players — **but it
  is required for the outfit task** (§10), which touches `src/` and is visible on a second player's
  screen.
- **No input scenario is added.** The map takes no input; a scenario here would test the harness.

### 16.6 The measurements this revision needs written down (rules 1, 6, 8)

| # | Measurement | If the answer is no |
|---|---|---|
| **N1** | `Terrain:SetMaterialColor` / `GetMaterialColor` from `execute_luau` in Edit; do the colours persist in the place; do they replicate to a client | §8.3's material-choice fallback; and drop §16.2 check 4 rather than weaken it |
| **N2** | `ComputeAsync` cost and result with ~3,000 collidable trunks in the world (against the empty-corridor baseline the build already has) | lower the dense tier's weight, or make trunks non-collidable below crown height and rely on `Body`'s own avoidance — **a `TASKS.md` row, not a silent tweak** |
| **N3** | The real tree, brush and part counts at the committed seed, and the build's wall clock | §15.2's estimate is corrected in `Config` and in the numbers table |
| **N4** | The worst corridor slope over three seeds at `BENCH_RELIEF = 6`, verge 24 | raise the verge or lower `BENCH_RELIEF`; both are one number |
| **N5** | Standing on a post: the actual drop, and whether a shooter sees the drive over the brush | `STAND_HEIGHT_STUDS` is `Match.CONFIG`'s, so this is a report to the drive's owner, not a map change |
| **B** | *(still open from Task 43)* do `CollectionService` tags and terrain survive a save and a reopen | fallback B: markers found by folder and name; the only module that changes is `Match.Markers`. **Never ship tags and names both** |

---

## 17. The M2.5 switch — unchanged in shape, new numbers

`Map.EXPECTED_WORLD` is `"arena"` or `"map:v1"`: one committed string, read by
`tests/server/map_contract.spec.luau` today and by `ArenaBoot` from M2.5.

```luau
-- src/server/ArenaBoot.server.luau, in full after the change
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage:WaitForChild("Map"))
if Map.EXPECTED_WORLD ~= "arena" then
    return                     -- the generated map is the world; the grey box is not built
end
require(ServerScriptService:WaitForChild("TestArena")).build()
```

It cannot be half-on; it does not sniff `Workspace` (a predicate like that lies the moment a run
half-finishes); `TestArena` keeps its owner and its file while it is still the rollback. **`"arena"` is
only a rollback once the terrain is cleared too** — audit-004's point, and `mapgen.py clear` plus
`MapGen.clear`'s measured `cellsAfter` are what make it one. **And now the palette as well** (§8.4).

The order, with every human action in it:

1. Backup: `--backup census` if its conditions hold (no human), else Karen's `File → Save to File`
   outside the repo (`NEEDS KAREN`).
2. `python tools/mapgen.py build --seed <N> --backup <accepted>`.
3. `contract`, `reach`, `shots`; the Builder inspects all eight images.
4. Save: Karen `File → Save to Roblox`, or the Director posts Alt+Shift+S. **Nothing here can verify
   it.**
5. Reopen; `contract` again — this is measurement B.
6. The code commit sets `Map.EXPECTED_WORLD = "map:v1"`, `Map.SEED`, `Map.DIGEST`,
   `Map.EXPECTED_COUNTS.tree = 12`, `Map.FIELD` = §15.1's corridor (x ± 620, z −880…+800,
   `exitZ = -820`, `groundY = 0`), **and `Boar.CONFIG.field` to the same numbers** — a data change
   inside `ServerScriptService.Boar`'s own file, by its owner.
7. Harness run (`test` **and** `test2`: the change touches `src/`).
8. **Karen walks it.** The feel gate; nothing here can judge it.
9. Only after Karen accepts: a separate task archives `src/server/TestArena.luau`,
   `src/server/ArenaBoot.server.luau` and `tests/server/test_arena.spec.luau` to `backups/` with a note
   (rule 7), and removes the early return with them.

---

## 18. Build order, and what Karen checks

One task per round (rule 4), smallest first, each one reviewable and green on its own. `EXPECTED_WORLD`
stays `"arena"` until M2.8e, so **none of these changes what a player stands in** — they merge on the
strength of the harness and the screenshots.

| # | Task | Scope | Evidence |
|---|---|---|---|
| **M2.8a** | **The road and the corridor** | `Map` (`GENERATOR`, `ROAD`, `ASSEMBLY`, `PALETTE`, `PALETTE_DEFAULT`, `SPAWN_PAD`, `BUDGET`), `Config` (§15.1), `Height` (`benchHeight`, `benchBand`, `edgeFloor`), `Layout` (`benches`, `onRoad`, `inField`, pads → 4), `Ground` (palette + road/field material cases), `Markers` (post size, line span), `Digest` (palette), `init` (palette step, `VERSION`, `clear`'s `paletteRestored`, `verifyContract`'s early return), `mapgen.py` (shots, reachability targets), the specs above. **No new props.** | build + `verify` (same digest twice), `reach`, `contract`, `map-wide` / `map-road` / `map-post` / `map-edge` inspected; measurements N1, N4 |
| **M2.8b** | **The wood** | species table and per-species proxies, `Scatter.speciesAt` / `weighted`, `Layout.treeDensity` / `treeBlocks`, `Props.trees(block)`, `Props.brush`, `rejectTree` rewritten, the hedge network shrunk to 3 lines, the walkability and species specs | the tree/brush/part counts (N3), the wall clock, `reach` green at five targets (N2), `map-drive` / `map-crossing` / `map-autumn` / `map-stand` inspected |
| **M2.8c** | **Line furniture and the fields** (v2's M2.4 content) | stakes beside each post; a **high seat as scenery** near 4 posts (`prop.highseat`, a proxy — the shooter still stands on the road in v1); a barrier at each end of the road; two log piles on the verge; a fence and a gate on the field boundaries; reeds at the bog | the same shots plus one new close view; all proxies |
| **M2.8d** | **The outfits** (§10) | `Match.Body.dressFor` / `dress`, the flag or `Match.CONFIG.OUTFITS_ENABLED = false`, `GAME_DESIGN.md`'s placement row amended, server specs for both branches, a client spec that the outfit is `CanQuery = false` | **`test` + `test2`** (it touches `src/`), and a two-player screenshot with one of each role in frame |
| **M2.8e** | **The switch** (§17) | `EXPECTED_WORLD`, `SEED`, `DIGEST`, `FIELD`, `EXPECTED_COUNTS`, `Boar.CONFIG.field`, `ArenaBoot`'s early return, the spec's map branch | Karen walks it |
| M2.3 / M2.7d | **Real trees** — the four species from Karen's Meshy ids, through `Assets.Loader`; `MapGen.Props` moves onto it | `asset-pipeline.md` §14 M2.7d | measurement D (cost of 50 trees); Karen's Meshy-plan answer gates it, not the generator |
| M2.6 | **Streaming on**, alone, with a playtest | `Settings.MAY_WRITE = true`, the four Studio-panel values set by hand (Karen), the client spec's assertions | a full harness re-run plus a playtest |

### 18.1 What Karen checks in her next playtest (3–5 things, per `ROADMAP.md` speed rule 8)

1. **Stand on a post and look down the road.** Do the eight posts at 45 m read as a hunting line, or as
   a firing range? Too close, or too far? (`Config.WORLD.postSpacing`.)
2. **Stand on a post and look into the drive.** Can you see far enough to shoot, or is it a wall of
   trunks? How often does a shot hit a tree instead of the boar — and is that right? (density weights,
   §15.2.)
3. **Walk the drive from the assembly track to the road.** Is the wood dark enough to hide a boar and
   open enough to walk? Does the hedge bank at z = +300 help or annoy?
4. **Look at the colours at eye level.** Leaf litter, orange oak, yellow birch, green spruce — autumn,
   or mud?
5. **The drop when you spawn on a post**, and the bog: feature or annoyance?

---

## 19. Deltas and dispositions

### 19.1 Corrections this design imposes on other documents

**A — Architect-owned (mine; done here or named for the next regeneration):**

- **A1.** This file replaces `docs/design/map-generator.md` (Task 42) **in full**.
- **A2. `docs/design/asset-pipeline.md` needs three additions at its next regeneration**, from this
  design: a `tree.alder.a` row in §12.1 (sizeStuds 14 × 57 × 14, ≤ 900 tris, 512², Automatic, ≤ 700
  instances) and a `prop.brush.a` row (10 × 5 × 10, ≤ 300 tris, 512², ≤ 600 instances); the tree
  instance ceilings re-split for four species inside `Map.BUDGET.trees = 3000`
  (spruce ≤ 1,200, birch ≤ 750, oak ≤ 600, alder ≤ 450); and its §6.8 "once per run" is once **per
  step**, in a staging folder destroyed inside the same call.
- **A3. `docs/design/drive.md` needs two sections at its next regeneration:** the sounder release
  (the brief's item 2 — sizes, mix, spacing, leader-follower, scatter-on-shot, the flag, and the
  spawn-pad contract in §11), and the outfit rows this design assigns to `Match.Body` (§10). Its §6.1
  marker table also still carries the **arena's** coordinates, which are now three worlds out of date.
- **A4. `docs/design/boar-ai.md`:** a sounder is the first thing that makes one boar's behaviour depend
  on another's; whichever pattern drive.md adopts, the Brain's threat/flee sections have to name where a
  neighbour enters. Not this file's.

**B — the Builder's, in files the Architect never edits:**

- **B1. The citation rule, so this drift stops.** Six code comments cite `docs/design/map-generator.md`
  "section 7.3" for the spawn pads, and that section has not existed in two regenerations
  (rows 45a(g), 47a(f), 48a(d) report the same class three reviews running). **From here on, a code
  comment cites the design by heading text, not by number** — `-- Design: docs/design/map-generator.md
  ("Benches: the road, and the drivers' assembly track")`. The old → new map for the citations in the
  tree today: pads → **§6.4**; assets → **§12**; the switch → **§17**; the numbers table → **§15**; the
  spec checks → **§16.1**; the measurements → **§16.6**; the build order → **§18**; the module list →
  **§2.2**; the step order → **§5.1**; the digest → **§5**/§8.4.
- **B2. `docs/research/2026-09-24-map-generator.md`** still carries the four corrections Task 39 named
  (21,000 → 20,000 triangles and first-party; 1024 px is ours, not a platform limit; "a changed mesh is
  a new id" is half wrong; the licence text is now read) **plus** the new note this revision needs:
  measurements N1–N5 and B (rule 1 — the note comes before the code).
- **B3. `GAME_DESIGN.md`**: the generated-map row gains "and the terrain material palette"; the
  map-contract row gains the road, palette and generator-version fields; the player-placement row gains
  "and the hunting outfit" when M2.8d lands.
- **B4. `.gitignore`** already covers `/.mapgen/`, `/.agent-evidence/` and `/.assets/`; nothing new.
- **B5. `TASKS.md` row 16** (typed property values) stays under "before release": this design puts no
  positioned geometry on disk, and that was the Director's decision already.

### 19.2 The queued map notes, and what this design does with each

| Row | Disposition |
|---|---|
| 43a(a), 43a(b), 44a(b) — proxies read as lollipops; no fields | **answered**: §7.1's real heights and autumn colours, §7.6's flank fields, §8's palette. Karen still judges the result |
| 43a(c) — the six shot names are stale | **closed**: §16.3's eight names |
| 43a(e) — `MapGen.Contract` is not in the design | **closed**: §2.2 |
| 43a(f), audit-004 F4 — the settings step could make M2.6's change | **adopted**: `Settings.MAY_WRITE = false`, §1.2 and §5.1 |
| 43a(l), audit-004 F9 — 9.5-stud drop onto a non-colliding post | **closed**: §4.3's 6 × 1 × 6 post on the road bench; Karen confirms (N5) |
| 43a(m), 43a(g) — functions with no caller | `Settings.current` and `verifyContract`'s `palette` have readers; `markerDigest`'s reader is M2.5 check 11, named in §16.1 |
| 43a(h) — the arena spec spells the tags literally | **keep, and comment as deliberate** (§4.2) |
| 43a(o) — a tree can stand inside a hedge | **closed**: `rejectTree` keeps the hedge clearance, and §16.1's scatter spec asserts it over 20 seeds |
| 44a(a) — 10,240 studs of hedge against a 6,000 row | **closed**: the network shrinks to 6,144 studs (§7.5) |
| 44a(e) — reachability paths to the line's centre only | **closed**: five targets (§16.4) |
| 44a(f) — `MapGen.VERSION` is a hand-typed string | **closed**: `VERSION = Map.GENERATOR`, asserted (§16.1 check 10) |
| 44a(g) — `CORRIDOR_MAX_SLOPE_DEG` had no reader | already fixed in Task 45; **strengthened** to three seeds with a lower bound (§16.1) |
| 45a(a) — `SPAWN_PAD.blend` 40 against the design's 24 | **adopted**: 40 is the design's number now (§4.1) |
| 45a(b) — relief-band assertions are identities | **closed**: the lower bound (§16.1) |
| 45a(c), 47a(d), 48a(c) — `verifyContract`'s early return omits declared fields | **closed**: §5 says fill every field |
| 45a(d) — post pads merged into one strip | **closed by construction**: there is a road there now (§6.4) |
| 45a(e) — the slope spec runs two seeds | **closed**: three (§15.1, §16.1) |
| 45a(g), 47a(f), 48a(d) — the design's stale signatures and section numbers | **closed**: §5 declares what is built; §19.1 B1 changes how comments cite |
| 47a(c) — the terrain check bypasses `Ground.cells()` | **closed**: §16.1 check 1 |
| audit-004 F3 — `digest` reported seed 0 | already fixed (`MapGen.builtSeed`); §5 declares `seed: number?` as built |
| audit-004 F10 — the pad spec omitted `bogDepth` | already fixed; §16.1 keeps it |
| 44a(c), 44a(d) — the bog reads dry; one material per field | **Karen's** (§20); crop variety is in no milestone and stays that way for v1 |

---

## 20. Open decisions

**None of these blocks building M2.8a.** Each has a working default, in `Config` or in this document,
changeable by one value.

### Already decided, recorded so they are not reopened

`reviews/task-54/BRIEF.md`, Karen and the Director, 2026-09-26: the line is on a **forest road**; boars
**cross** it; **autumn**; **four species**; boars come as **singles and groups of 2–5**; shooters wear an
**orange hat**, drivers an **orange vest**. Earlier and still standing (`reviews/task-33/BRIEF.md`):
`tools/mapgen.py` is allowed past the tooling freeze; `TASKS.md` row 16 stays "before release";
**M2.6 (streaming) is its own task with a full harness run and a playtest**; **spawn pads are flattened
in terrain and the boar stays untouched**.

### For Karen (feel and taste — nobody else can answer)

1. **Post spacing: 160 studs (45 m), 8 posts, a 1,120-stud line.** Her reference said 40–80 m; this is
   the low end, because the map is 2,048 studs wide and 80 m spacing would need a 2,000-stud line.
   Walk it. **And note §14 source 6: at this spacing the DJV's 30° neighbour rule bites** — a boar
   crossing 40 studs in front of a shooter is about 14° off his neighbour's stand, which makes
   `TASKS.md` row 35a (the v1.1 neighbour rule) a real rule rather than a nicety.
2. **How dark and how thick the wood is** — density 1.00 / 0.42 / 0.14, and 500 brush. The single
   biggest lever on whether the drive is fun: too thin and the boar has nowhere to hide, too thick and
   the shooter's shot hits a trunk every time.
3. **Should cover ever stop a shot?** Brush is decoration in v1 (`CanQuery = false`, §7.4). Trunks and
   crowns do stop shot. If a pellet stopped by a bush feels right, that is one property.
4. **The road**: 16 studs wide and dead level. Wider, narrower, or should it roll with the ground
   (§6.3, a v1.1 cost)?
5. **The autumn palette**: four colours in `Map.PALETTE`, and four crown colours in §7.1. Numbers she
   changes after looking.
6. **Do the flank fields stay?** Default yes, two of them (§7.6). They are what keeps "European
   farmland and woods" true and they are 10 minutes to delete.
7. **The bog** — still a grey mud flat, because `Water` is forbidden in v1 (row 44a(c)).
   `Config.WORLD.bog` turns it off in one word.
8. **The outfits**: an orange hat and an orange vest, as flat grey-box parts (§10.2). Shape, size and
   whether both teams should be orange at all.
9. **The Meshy plan** — unchanged, and it gates M2.3, not this revision: while free-plan Meshy output
   may not ship, every tree bakes as a proxy. **Not legal advice.**

### For the Director (scope)

A. **The corridor widens from 680 to 1,240 studs to hold a 45 m shooter line, and the map stays 2,048
   studs.** That leaves ~400 studs of wood on each flank and 1,400 studs of drive. **Recommendation:
   accept.** Growing the map to 2,560 would cost 400 terrain tiles instead of 256 (~+60 % build time)
   and buys backdrop, not gameplay. If Karen wants 80 m spacing, the map must grow, and that is a
   separate decision with a measured cost.

B. **Five tasks before the switch (M2.8a–e), not one.** The wood, the road, the furniture and the
   outfits are four different kinds of change with four different kinds of evidence, and rule 4 is one
   task per round. **Recommendation: dispatch M2.8a alone**, and read N1 and N4 before dispatching
   M2.8b.

C. **The outfit task is the first thing in a while that needs `test2`** (it touches `src/` and is only
   visible with two players). **Recommendation:** dispatch M2.8d when a two-player slot exists, not
   before.

D. **`MapGen.Assets` stays the manifest until M2.7a**, with the key grammar already matching
   `asset-pipeline.md` (§12.2). **Recommendation: confirm**, and forbid a second id table anywhere in
   the meantime.

E. **The species and brush keys need rows in `asset-pipeline.md` §12.1** (§19.1 A2). That file is
   Architect-owned; **recommendation:** fold them in at its next regeneration rather than spending a
   design run on it now — nothing is blocked, because `Assets.ROWS` is empty and every key proxies.

F. **Measurement N2 (pathfinding cost with ~3,000 trunks) could send M2.8b back.** If it does, the
   answer is a density number or non-collidable trunks below crown height, and **either is a `TASKS.md`
   row with a measurement attached, not a quiet tweak.**
