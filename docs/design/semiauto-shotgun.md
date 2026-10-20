# The semi-automatic shotgun (`semiauto`)

Architect design for **Task 225**, written to `reviews/task-225/BRIEF.md` (the Builder carrying the
Director, 2026-10-20). The BRIEF overrides anything older in `docs/`, `TASKS.md` and
`docs/design/shotgun.md`; where this document departs from it, it says so in the open, with the file
and symbol that forced it (sections 7.1, 7.3, 7.4, 9.2, 11.2).

Karen, verbatim: *"so you have things to do / deer / weapons / make it work like we have now"*, and
*"Upload, sell in shop (Recommended)"*. Her standing bar: shooting, weapon and reload **perfect**, a
separate-part model, every frame checked against the target.

The model is PStudio's MP-153-pattern 12-gauge (Fab Standard, Personal tier), bought, **outside the
repo**, never committed. It is a **fourth row in the weapon system, joined exactly as the lever
rifle was** (D-1): no new system, `ServerScriptService.Weapon` stays the owner of the action,
`Weapons.ROWS` stays the one table of guns, `Camera.Viewmodel` stays the one writer of the drawn gun.

**Three things in this task are genuinely new, and all three are named with their owner:** a SECOND
moving group (the shell lifter, section 7.2), a gun that **cycles itself without the shooter's hands
moving** (section 7.4 — the pose share, and it is the finding that matters most), and the first
magazine-readout gun with **two ammunition kinds** (section 6.4).

---

## 1. What it must do

1. Exist as one frozen row in `Weapons.ROWS` keyed `semiauto`, built field by field from its own
   config module, with its own `Tool`, its own hotbar slot (4) and its own viewmodel drawn with the
   same gloves.
2. Fire **one trigger pull, one shell**, and then **cycle itself** (`AUTO_CYCLE`), throwing the fired
   hull and leaving the live rounds in the tube (`CYCLE_EJECTS = "spent"`).
3. Hold **four in the tube and one in the chamber** (`BARRELS = 5`, `MAGAZINE = 5`,
   `READOUT = "magazine"`), measured off the model's own tube (section 6.3).
4. Fire **the side-by-side's shells, with the side-by-side's ballistics** — the same cartridge, one
   answer (section 9).
5. Top the tube up through the loading port under the receiver on `R`, one shell per `Load` step,
   and end early when the tube fills (the shipped `Weapon.cycleRefusal`, section 6.2).
6. Draw **two independently moving groups**: the bolt, back and forward on `CYCLE`; the shell lifter,
   up and down on each `Load` of `RELOAD` (section 7.2).
7. Aim down a **red dot** (`SIGHT = "reddot"`, `scope = nil`): the shotgun's aim path, the gun and
   both gloves left in the view, no mask, no reticle overlay (section 7.3).
8. Be **bought in the shop** (`OWNED_ONLY = true`, one `Shop.ROWS` entry whose `grants.weapon` names
   this id), with a display model in the shop window (section 11).
9. Be drawn from **six uploaded MeshParts** in Karen's account, with the measured fallback boxes
   until they land.

## 2. What it must not do

1. **Not become a second owner of anything.** It writes no state: `Weapon.StateMachine` is still the
   only producer of a `WeaponState`, `Weapon.Hardware` the only writer of Tool Instances,
   `Camera.Viewmodel` the only writer of the drawn gun, `tools/pose.py` the only writer of the live
   pose override, `CameraBoot`'s break-source closure the only reader of the state replica.
2. **Not add a primitive to the reducer and not change `runCycle`.** `Break` / `Load` / `Close`
   already are "the bolt opens", "one shell through the port" and "the bolt closes", and
   `Weapon.cycleRefusal` already answers `"finish"` for a `Load` on a full tube (shipped in task
   224). **Nothing in `src/server/Weapon/` changes in this task** — which is the confirmation D-7
   asks for, checked against `runCycle`'s `filled` branch and `StateMachine.apply`'s `Load`.
3. **Not carry a rule of the drive or of the protocol.** `Weapons`' header is the rule and
   `rifle.spec`'s forbidden-field loop is the assertion: no `SAFETY_ARC_HALF_DEG`, no `AUTO_EQUIP`,
   no rate limit, no `FLIGHT_*`, no gravity constant.
4. **Not invent a second answer to "how far does a slug go".** It reads `Shotgun.CONFIG`'s
   ballistic rows and nothing else out of another gun's file (section 9).
5. **Not add a feature flag.** See section 12.
6. **Not reorder the hotbar.** It appends at slot 4; `Weapons.PRIMARY` and a flag-off spawn are
   bit-for-bit what they are (section 12).
7. **Not draw loose shells in the hands** (`HAND_FED_SHELLS = false`): the shotgun's two-chamber
   hand feed is the shotgun's, at the shotgun's 4.4-stud layout, and task 224 already declared that
   fact per gun. The drawn port feed is 225a (section 16).
8. **Not touch** `Match.CONFIG.SAFETY_RANGE_STUDS` (still 330, still 183a(a), still a
   `TWO_PLAYER_PATH`), a Robux product id, a new audio upload, a new hit card, a new decal, a new
   hit-zone table, or the drawn gate feed queued as 224a.

---

## 3. Owners, and where each lives on disk

Every row is "exactly one writer, named" (CLAUDE.md rule 3). *new* marks a new file; everything else
is an existing file with the edit named.

| Thing | Owner (the one writer) | On disk |
|---|---|---|
| This gun's numbers (every ballistic reference, timing, layout, voice) | `ReplicatedStorage.SemiAuto` → `SemiAuto.CONFIG`, frozen by `Shotgun.deepFreeze`, no run-time writer | *new* `src/shared/SemiAuto/init.luau` |
| The DRAWN gun (every group, both pivots, the sight, the reticle plane, the hand anchors) | `ReplicatedStorage.SemiAuto.Geometry`, pure data, the sibling of `Gun`, `Rifle.Geometry` and `Lever.Geometry` with the same function set **plus the lift pair** | *new* `src/shared/SemiAuto/Geometry.luau` |
| The WORLD gun's fallback piece list | `ServerScriptService.Weapon.ShapeSemiAuto`, the sibling of `ShapeLever`, reading its boxes out of `SemiAuto.Geometry` and re-typing none | *new* `src/server/Weapon/ShapeSemiAuto.luau` |
| Which weapons exist, and which a hunter carries | `Weapons.ROWS` / `ORDER` / `GEOMETRY` — **one new row, one ORDER entry, one geometry entry** | `src/shared/Weapons/init.luau` |
| weapon id → world shape | `Weapon.Shapes.BY_ID` — **one new entry** | `src/server/Weapon/Shapes.luau` |
| What a 12-gauge shell IS (its kinds, its word on screen, its glyph) | `Shotgun.CONFIG` — **`AMMO_KINDS`, `AMMO_LABEL`, `AMMO_GLYPH` move here from the shotgun's row literal, value for value**, and both shotgun rows read them (section 9.2) | `src/shared/Shotgun/init.luau`, `src/shared/Weapons/init.luau` |
| The action (every state transition, every sequence) | `ServerScriptService.Weapon` (`runCycle`, `onActionRequest`, `cycleRefusal`) and the pure `Weapon.StateMachine` — **UNCHANGED** | `src/server/Weapon/init.luau` |
| Which piece of a drawn gun moves with which group | `Gun.Group` — **one type line: `"body" \| "barrels" \| "lift"`** (its one reader is `buildNewGun`) | `src/shared/Gun/init.luau` |
| The drawn bolt's travel, and its SIGN | `SemiAuto.Geometry.boltTravel` — **not** `Camera.Viewmodel` (task 188's rule) | `src/shared/SemiAuto/Geometry.luau` |
| The drawn lifter's swing, its pivot and its SIGN | `SemiAuto.Geometry.lifterSwing` / `lifterHinge` | `src/shared/SemiAuto/Geometry.luau` |
| The drawn gun on screen, including **both** moving groups | `PlayerScripts.Camera.Viewmodel` — **one new `CYCLE_KIND` branch (`"straight"`), a second envelope in `buildNewGun`, the `"lift"` parent branch, and the new `setLift` / `liftProgress` / `lifterWeight` / `lift` quartet called once from `update`** (section 7) | `src/client/Camera/Viewmodel.luau` |
| "A shell just went in" as a pure edge | `Camera.fedShell(previous, snapshot)` — pure and public, beside `Camera.breakFrom` and `Camera.breakSound`, which exist for exactly that reason | `src/client/Camera/init.luau` |
| Feeding that edge to the drawn gun and to the voice | `CameraBoot`'s break-source closure — **the existing one reader of the replica**, which gains one remembered snapshot | `src/client/CameraBoot.client.luau` |
| How much of the cycle pose the gun and hands take up | `Camera.Mode` (`viewmodelOffset`, `handFrame`) reading one new pose number `CYCLE_POSE_SHARE` — the pure pose composer, already the one owner of the blend (section 7.4) | `src/client/Camera/Mode.luau` |
| This gun's pose set | `src/shared/Viewmodel/poses.json`, `weapons.semiauto` — **content lane**, `tools/pose.py` the one live writer | `src/shared/Viewmodel/poses.json` |
| Which weapon ids must have a pose set; the flat names | `Viewmodel.validate` (**one literal grows to four ids**) and `Viewmodel.view` (**three new flat names**: `LIFTER_DEG`, `LIFTER_SECONDS`, `CYCLE_POSE_SHARE`) | `src/shared/Viewmodel/init.luau` |
| This weapon's voices | `SemiAuto.CONFIG.SOUND`, played by `Weapon.Sound` (client) off `CameraBoot`'s edges — **no new voice key, no new `Sound.*` function** | `src/shared/SemiAuto/init.luau` |
| Published viewmodel meshes | `src/server/ViewmodelAssetsBoot.server.luau` — **one new folder, one preload, one publish loop** | same |
| Asset ids and every measured fact about an upload | `ServerStorage.Assets.ROWS` — **six new rows**, written by the Builder from what `tools/roblox_upload.py` printed into `assets/uploads.json` | `src/serverstorage/Assets/init.luau` |
| The split plan | `tools/gltf_split.py` `SEMIAUTO_PLAN` + `PLANS` — **one new named plan**, beside `MODEL_B_PLAN`, `RIGBY_PLAN` and `LEVER_PLAN` | `tools/gltf_split.py` |
| The shop catalogue | `ReplicatedStorage.Shop` — **one `ITEM`, one `ROWS` row, one `ORDER` entry, one `ALL_ORDER` entry, one `BASE_AMMO` entry** | `src/shared/Shop/init.luau` |
| The shop window's picture | `PlayerScripts.Hud.ShopDisplay` `DRAW` — **one entry through the shipped generic `buildGun`** (section 11.3) | `src/client/Hud/ShopDisplay.luau` |
| Which scope a spec belongs to | `tools/studio_mcp.py` `BLAST_RADIUS` + `SCOPE_SPECS` — **one prefix, four tuple entries** | `tools/studio_mcp.py` |
| The owners table | `GAME_DESIGN.md` *System owners* — **three new rows**, mirroring this section | `GAME_DESIGN.md` |

**Nothing else in `src/` is touched.** Checked, not assumed: `Hardware.addMesh` reads
`row.ASSET_KEYS` / `MESH_NAMES` as parallel lists and is count-agnostic; `Hardware.build` reads
`config.GRIP`, `HANDLE_SIZE`, `HANDLE_COLOR` and writes `DrivenHunt.Weapon`; `Weapon.refreshArming`
walks `Weapons.loadout()` and `Weapon.equipDelayFor` already answers for `#wanted > 1`;
`Hud.readoutFor` / `ammoChipFor` branch on `row.READOUT` and `Hud.PIP_MAX` is 8, so five pips draw;
`Hud.killLineText` and `Report.detailCellsFor` read `row.label`; `Ballistics.shotFor` reads the four
required numbers off the row; `Weapon.heldFrom` is already asserted over three replicas and is
id-driven. **`src/server/Weapon/` does not change at all.**

---

## 4. The module shape

**`src/shared/SemiAuto/` with its own `Geometry` sibling** — the lever's and the Rigby's shape. The
BRIEF's item 2 asks for confirm-or-overrule: **confirmed**, with the boundary written down.

- `SemiAuto.CONFIG` is one frozen table, deep-frozen at require time with `Shotgun.deepFreeze`.
- **What it may read out of `Shotgun.CONFIG`, and nothing else:** `deepFreeze`, the `ActionKind` /
  `AmmoKind` type names, and the **ammunition rows by reference** —
  `RANGE_STUDS`, `PELLETS`, `SPREAD_FULL_DEG`, `MUZZLE_STUDS_PER_S`, `DRAG_PER_STUD`, `ZERO_STUDS`,
  `GRAVITY_SCALE`, plus the three identity tables of section 9.2 (`AMMO_KINDS`, `AMMO_LABEL`,
  `AMMO_GLYPH`). **By reference, not by copy**, exactly as `Weapons.ROWS.shotgun` already does
  (`local C = Shotgun.CONFIG` … `RANGE_STUDS = C.RANGE_STUDS`): a copy would be a second answer.
- Everything else is this gun's own: the action, the timings, the hardware, the look, the voice.
  It does **not** read `Rifle.CONFIG` or `Lever.CONFIG`, and nothing reads `SemiAuto.CONFIG` but its
  own row and its own geometry.
- `SemiAuto.Geometry` is pure data with the **same function set** as `Gun` / `Rifle.Geometry` /
  `Lever.Geometry` — because `buildNewGun`, `ShopDisplay.buildGun` and `Viewmodel.hinge` draw
  whichever one `Weapons.geometry(id)` hands them and must not learn which gun they have — **plus
  the lift pair** (`LIFT_GROUP_NAME`, `lifterHinge`, `lifterSwing`), which is additive: a geometry
  without them is read exactly as it is today (section 7.2).
- Require direction, so there is no cycle: `Weapons` → { `Shotgun`, `Rifle`, `Lever`, `SemiAuto`,
  `Gun`, the three `Geometry` modules, `Shop` }; `SemiAuto` → `Shotgun`; `SemiAuto.Geometry` →
  { `Gun`, `SemiAuto` }; `Shop` requires none of them.

Rejected, with the reason:

- *A second row inside `Shotgun.CONFIG`.* Refused for `Rifle`'s stated reason — the file that holds
  Karen's accepted shotgun numbers must not become the file everybody edits. What is shared is the
  CARTRIDGE, which is section 9's one exception and is read by reference.
- *A shared `Repeater` base this gun and the lever both read.* It would make one number answer for
  two guns, which is `docs/PROJECT_CONTEXT.md`'s named failure. They share the machinery (the
  reducer, the sequence runner, the geometry function set) and that is already the whole saving.

---

## 5. The public interface

### 5.1 `SemiAuto.CONFIG` (`ReplicatedStorage.SemiAuto`)

Types are the `Weapons.Row` type's. Every field is read by the row and by nothing else.

```luau
export type CycleStep = { kind: Shotgun.ActionKind, wait: number }

local C = Shotgun.CONFIG   -- THE CARTRIDGE, BY REFERENCE (section 9)

SemiAuto.CONFIG = {
  -- the cartridge: the side-by-side's, one answer
  RANGE_STUDS, PELLETS, SPREAD_FULL_DEG,
  MUZZLE_STUDS_PER_S, DRAG_PER_STUD, ZERO_STUDS, GRAVITY_SCALE,   -- = C.<same>
  AMMO_KINDS, AMMO_LABEL, AMMO_GLYPH,                             -- = C.<same> (9.2)
  INITIAL_AMMO        : string               = "Buck",
  START_RESERVE       : { [string]: number } = { Slug = 10, Buck = 10 },

  -- the action (section 6)
  BARRELS             : number  = 5,
  MAGAZINE            : number  = 5,
  BARREL_DELAY        : number  = 0.12,
  AUTO_CYCLE          : boolean = true,
  CYCLE               : { CycleStep },   -- Break 0.12, Close 0.18
  CYCLE_TOTAL         : number  = 0.30,
  CYCLE_EJECTS        : string  = "spent",
  RELOAD              : { CycleStep },   -- Break 0.35, Load 0.38 x 5, Close 0.35
  RELOAD_TOTAL        : number  = 2.60,
  AUTO_RELOAD_WHEN_EMPTY : boolean = true,
  READOUT             : string  = "magazine",

  -- the hardware (section 10)
  HANDLE_SIZE         : Vector3 = Vector3.new(0.4, 0.5, 4.9),
  HANDLE_TRANSPARENCY : number  = 1,
  GRIP                : CFrame  = CFrame.new(0, 0, 1.56),
  MUZZLE_OFFSET       : Vector3 = Vector3.new(0, 0, -2.45),
  LOOK                : { [string]: Color3 },  -- barrel, action, bolt, lifter, stock, sight, dot
  SOUND               : { [string]: any },     -- shot, bolt, load (section 8)
}
```

`scope` is **absent**; `SIGHT = "reddot"` lives on the row. The manifest keys are **not** here (the
Reviewer's round-1 note on the rifle, kept): they live once in `SemiAuto.Geometry.ASSET_KEYS` for
the drawn gun and once in the row's `ASSET_KEYS` for the world Tool, and their ORDER decides which
key is worn as `Model`.

### 5.2 The row (`Weapons.ROWS.semiauto`)

Built field by field from `SemiAuto.CONFIG`, never copied out of it.

```
id = "semiauto", label = "AUTO", toolName = "SemiAuto", slot = 4,
<every CONFIG field above>, HANDLE_COLOR = SemiAuto.CONFIG.LOOK.stock,
ASSET_KEYS = { "semiauto.action", "semiauto.barrel", "semiauto.stock",
               "semiauto.bolt", "semiauto.lifter", "semiauto.sight" },
MESH_NAMES = { "Model", "Barrel", "Stock", "Bolt", "Lifter", "Sight" },
SIGHT = "reddot", scope = nil, OWNED_ONLY = true,
```

`label` is **four characters and must stay at seven or fewer**: `ReportPanel.DETAIL_COLUMNS`' `gun`
cell is 88 px and task 219 measured `SHOTGUN` at 46 px in that cell's own face. `"SEMI-AUTO SHOTGUN"`
is the SHOP row's label (17 ≤ `Shop.CONFIG.LABEL_MAX` 18), not the gun's. `Model` is the first
`MESH_NAMES` entry and the **action** is therefore the first `ASSET_KEYS` entry — `Hardware.wearsMesh`
and the upgrade sweep read "does this Handle have a `Model` child". **No new field on the
`Weapons.Row` type.**

### 5.3 `SemiAuto.Geometry` (`ReplicatedStorage.SemiAuto.Geometry`)

The function set is `Lever.Geometry`'s, so a generic caller cannot tell the guns apart, **plus three
names for the second moving group**. Every box and point is a MEASUREMENT the Builder takes with
`tools/gltf_split.py probe` on the converted glTF before this file is written (section 10.2); this
design names what must be measured and invents no number.

```luau
Geometry.MESH_SIZE_STUDS      : Vector3   -- the split report's `wholeBoxFileAxes.size`, at 4.9
Geometry.MESH_ROTATION_DEG              = Gun.MESH_ROTATION_DEG
Geometry.FOLDER_NAME                    = "ViewmodelSemiAuto"
Geometry.BODY_NAME                      = "SemiAutoBody"
Geometry.CYCLE_GROUP_NAME               = "Bolt"
Geometry.CYCLE_KIND                     = "straight"   -- the fourth value (7.1)
Geometry.LIFT_GROUP_NAME                = "Lifter"     -- NEW: the second moving group (7.2)
Geometry.HAND_FED_SHELLS                = false
Geometry.ASSET_KEYS           : { string }              -- six, in wear order
Geometry.MESH_KEYS            : { [string]: string }    -- Action/Barrel/Stock/Bolt/Lifter/Sight

Geometry.layout(config)       -- every measurement, scaled by HANDLE_SIZE.Z / 4.9, frozen.
                              -- Publishes: total, half, muzzleZ, meshCentreY, action, barrel,
                              -- stock, bolt, lifter, sight (each { size, at }), dotAt, dotDiameter,
                              -- portAt, boltBackStuds, the generic pair cycleLength / cycleZ,
                              -- AND the new pair liftLength / liftZ.
Geometry.sightKind(config)    -- `config.SIGHT or "reddot"`: one configuration, no piece filtered
Geometry.beadOffset(config)   -- THE RETICLE PLANE, on the gun's centre line (x = 0)
Geometry.sight(config)        -- CFrame.new(beadOffset): where the eye is laid
Geometry.muzzle(config)
Geometry.hinge(config)        -- read by `Viewmodel.hinge` before it branches; = the bolt's rest
Geometry.boltTravel(config, drawStuds, progress) : CFrame   -- the bolt, with the SIGN here (7.1)
Geometry.lifterHinge(config)  -- the tray's pin
Geometry.lifterSwing(config, deg, progress) : CFrame        -- the tray, with the SIGN here (7.2)
Geometry.lifterTipOffset(config)                           -- the tray's free end, for the spec
Geometry.gripOffset / gripAxis / gripRadius / gripHalfLength
Geometry.alongGripAxis(config, point) / offGripAxis(config, point)
                              -- SAME NAMES as the other guns', so one spec helper checks all three
Geometry.pieces(config)       -- { Piece }, in build order: Stock, Action, Barrel, Sight, Dot (body);
                              -- Bolt ("barrels"); Lifter ("lift")
Geometry.partCount(config)    -- #pieces + 2 = 9
```

**No `skipFor` / `onlyFor` filter here**, and that is deliberate against the BRIEF's D-9 wording:
task 143's filter exists so ONE geometry can draw a gun with or without glass, and this gun has
exactly one sight configuration — a filter would be a branch with one reachable arm. The filter
stays where it is, on the Rigby, for the Rigby's next sight (`Lever.Geometry`'s own precedent).

### 5.4 `Weapon.ShapeSemiAuto` (server)

`pieces(row)`, `sight(row)`, `muzzleZ(row)` — the `ShapeLever` contract, read forwards by
`Hardware.addParts` and backwards by `Hardware.removeParts`. Five boxes, read out of
`SemiAuto.Geometry.layout` and re-typing nothing: `SemiAutoStock`, `SemiAutoBarrel` (a cylinder on
the bore line), `SemiAutoTube` (a second, thinner cylinder BELOW it — at thirty studs the two
parallel pipes are the whole silhouette of a tube gun and the one cue that says *not a double*),
`SemiAutoAction`, `SemiAutoSight` (a small block on the receiver's top). No loop, no scope tube.
The world gun does not move: `Hardware` builds it and only the first-person viewmodel cycles.

### 5.5 Remotes, events, flags

**None are added.** `Shotgun.remotes()`' six RemoteEvents carry this gun exactly as they carry the
other three; `weapon = "semiauto"` is a string in fields that already carry one. **No wire field is
added** — which is the second half of D-7's question: the second moving group is driven from
`snapshot.barrels` and `snapshot.action`, both of which have been on the wire since task 142
(`Shotgun.WeaponSnapshot` carries `barrels`, `loaded`, `action` and `busyFor`).

---

## 6. The action

### 6.1 The cycle — the gun works itself

```
CYCLE = { { kind = "Break", wait = 0.12 }, { kind = "Close", wait = 0.18 } }
CYCLE_TOTAL = 0.30      AUTO_CYCLE = true      CYCLE_EJECTS = "spent"
```

Two steps because one stroke is out and back: `Break` throws the fired hull (`"spent"` — the
shotgun's `"all"` would dump four live rounds down the hill after every shot) and `Close` chambers
the next from the tube. No `Load`: nothing is fed by hand during a cycle.

**0.30 s, bracketed by numbers this repo has measured on screen** — far under the lever's 1.10 and
the bolt's 1.62, because a gas gun cycles while the shooter does nothing (source 13.1), and not zero,
because the bolt must be **visibly back for at least one frame** or the "mid-cycle, bolt back" frame
does not exist. At 0.12 s the `Break` step is ~7 frames at 60 Hz, and the drawn window is 0.10 s
(section 7.5), so the bolt is at or near full travel for about 4 frames. **It is Karen's dial.**

The practical rate is `BARREL_DELAY + CYCLE_TOTAL` = **0.42 s between shots, 2.38 shots/s**, five
rounds in 1.68 s after the first. That rate is the gun's whole character and is hers.

### 6.2 The reload — single shells through the port, and it adds nothing

```
RELOAD = { Break 0.35, Load 0.38, Load 0.38, Load 0.38, Load 0.38, Load 0.38, Close 0.35 }
RELOAD_TOTAL = 2.60      AUTO_RELOAD_WHEN_EMPTY = true
```

`StateMachine.apply`'s `Load` fills **exactly one** empty chamber from the pocket per step, which is
precisely one shell through one port. **`Break` and `Close` open and close nothing on this gun** —
they are the hand leaving the grip for the port and coming back, and the bolt stays where it is
(section 7.5). Said out loud so the words are not read as a break action.

0.38 s per shell is quicker than the lever's 0.42 (a shotgun's port is a bigger hole than a rifle's
gate) and 2.60 s is still the slowest full reload in the game, which is the price of five rounds.
**A PARTIAL top-up ends early, through shipped code**: `Weapon.cycleRefusal("Load", "barrel-full")`
answers `"finish"`, `runCycle` sets `filled` and skips the remaining `Load`s, so two rounds cost
0.35 + 2 × 0.38 + 0.35 = **1.46 s** and the `Close` is a real published, timed, voiced step. **No
code change** — this is exactly the branch task 224 bought and this gun is its second user.

### 6.3 Four and one, measured off the model

The tube runs from the receiver face (file y −0.3305) to the magazine cap's rear (−0.6851):
**0.3546 file units × 0.894 m = 317 mm**. That is 4.5 rounds of 70 mm or 4.2 of 76 mm — **four
either way**, so the answer does not depend on which hull length is assumed — plus one chambered.
It is also what a real MP-153 holds (source 13.2). `BARRELS = 5` and `MAGAZINE = 5` are the same
number and the config says why; `barrels` in the reducer is already an array of Live/Spent/Empty, so
a tube of five IS that array with five entries.

### 6.4 `X` on a tube gun: the first magazine readout with two loads

**This is new and the BRIEF's item 8 is right to ask for it.** This is the first weapon with
`READOUT = "magazine"` **and** two `AMMO_KINDS` **and** `CYCLE_EJECTS = "spent"`. Traced against the
shipped code, with no change:

- `Validator.checkRequest` accepts `X` (the row has two kinds), `StateMachine.apply`'s `SelectAmmo`
  sets `state.ammo`, and `onActionRequest` then spawns `runCycle(..., row.RELOAD)`.
- `Break` with `"spent"` ejects **nothing** from a full tube, so the five `Load`s answer
  `"barrel-full"`, `cycleRefusal` answers `"finish"`, and the sequence runs `Close`.
  **Measured consequence: `X` on a FULL gun costs 0.70 s and changes nothing in the tube.**
- On a part-empty gun it **tops the tube up with the new kind**, so the tube can hold a MIX. That is
  correct and honest, because `state.loaded` is per chamber and `onFireRequest` reads
  `state.loaded[state.selected]` — each shell flies as what it is, and the per-load recoil and
  volume come from the same word (`Viewmodel.loadFor`).
- The readout says `5/5 BUCK 10` — `Hud`'s own comment already defines that word as *"the ammo the
  NEXT load uses"*, which is what it is. **No Hud change.**

**It ships as the shipped machinery**, with the behaviour written into the config's header so nobody
reads it as a bug. The alternative — refusing `X` while the tube is full, with a notice — is a branch
in `onActionRequest`, i.e. a change to the owner of the action for a cosmetic saving of 0.70 s;
**that is the Director's call (D-b) and it ships off.**

---

## 7. What the drawn gun does, and the forced changes to shipped drawing code

### 7.1 `CYCLE_KIND = "straight"`, a fourth value

The BRIEF leaves this open; the shipped code decides it. `Viewmodel.hinge` has three branches today:
`"slide"` (the Rigby: the handle turns up over `BOLT_LIFT_FRACTION`, then the bolt draws back),
`"lever"` (an arc), and the break action. **A gas bolt does neither: it reciprocates straight back
and forward, and nothing rotates.**

Reusing `"slide"` with `liftDeg = 0` would spend the first `liftFraction` of the travel doing
nothing (a bolt that holds still for a third of its stroke) and would require a `boltLift` on this
geometry that exists only to return identity — a pose dial (`liftDeg`) that moves nothing on screen,
which is the silent-number defect task 188 was raised for. So:

```luau
elseif geometry.CYCLE_KIND == "straight" then
  -- A GAS BOLT. One translation, no rotation; the AXIS and the SIGN are the geometry's (task 188).
  swing = geometry.boltTravel(row or Shotgun.CONFIG, config.BOLT_DRAW_STUDS or 0, progress)
```

`SemiAuto.Geometry.boltTravel` owns the direction: in the Handle's frame −Z is the muzzle, so BACK is
**+Z**, and the function is the one place that says so. `poseHands` is **not edited**: its
`(CYCLE_KIND or "hinge") == "hinge"` test answers `false`, which is the right answer — the left hand
holds the fore-end, which is bolted to the barrel and does not move.

### 7.2 The second moving group, in full (D-3: **confirmed, with the owner and the driver named**)

Every gun so far has exactly one moving group. This one has two, on two different sequences. The
second is **declared beside the first**, not overloaded onto `CYCLE_GROUP_NAME`:

| Question | Answer |
|---|---|
| The field | `Geometry.LIFT_GROUP_NAME = "Lifter"`, additive — a geometry without it has no second group and is read exactly as today |
| The piece | `Gun.Group` gains `"lift"` (one type line; its **one** reader is `buildNewGun`'s `part.Parent = if piece.group == "barrels" then barrels else handle`) |
| The envelope | `buildNewGun` builds a second invisible envelope when `geometry.LIFT_GROUP_NAME ~= nil`, sized from `at.liftLength` and placed from `at.liftZ`, parented to the **Handle** (not to the bolt: the two groups are independent) |
| The geometry | `Geometry.lifterSwing(config, deg, progress)` — `pivot * CFrame.Angles(rad(deg * clamp(progress, 0, 1)), 0, 0) * pivot:Inverse()`, the hinge maths `Lever.Geometry.leverThrow` already models |
| The pivot | `Geometry.lifterHinge`: **MEASURED** as the centroid of `shotgun.018`'s REAR-most 8 % in the long axis lying in its upper half — the material around the pin and nothing else, the recipe `Lever.Geometry`'s `LEVER_PIVOT` already uses. On an MP-153 the tray pins at the rear of the port and its free end rises |
| The SIGN | **in the geometry, for task 188's reason**, and it is falsifiable: at progress 1 `lifterTipOffset` must have a **greater Y** than at progress 0, and the rise must be at least one hull diameter (20.5 mm = 0.079 studs) or the tray could not lift a shell to the chamber mouth |
| Which sequence drives it | `RELOAD`'s `Load` steps, and only those |
| How its progress is read | a per-shell clock in `Camera.Viewmodel`, the **exact shape `setMagazine` / `magazineProgress` already has**: `Viewmodel.setLift(seconds)` starts one if none is running, `Viewmodel.liftProgress()` returns 0..1 and clears itself at 1, and `Viewmodel.lifterWeight(progress)` is a pure up-and-down ramp (0 → 1 → 0 at progress 0.5), because a tray rises AND falls on each shell |
| Who starts that clock | `CameraBoot`'s break-source closure — the existing **one** reader of the replica — on the pure edge `Camera.fedShell(previous, snapshot)` |
| Who writes the Instance | `Camera.Viewmodel.lift(gunCFrame, config)`, called once from `update` directly after `hinge`, placing the envelope and each rider from `swungLift * ridersLocal[part]`, exactly as `hinge` does |

**`Camera.fedShell(previous, snapshot): boolean` — pure, public, beside `Camera.breakFrom`:** true
when `snapshot.action == "Load"` **and** the count of `"Live"` chambers in `snapshot.barrels` is
greater than in `previous.barrels`. That is one shell going in, once per shell, **with no protocol
change**.

Why not the rising edge of `action == "Load"`, which the `load` VOICE uses today: `runCycle`
publishes the step name on every step, so the step before each `Load` after the first is that same
`Load` and the edge fires **once per run, not once per shell** — measured and written down in
`CameraBoot`'s own comment and queued as 224a(e). A tray that flicked once during a five-shell
reload is the "measures correct, looks wrong" class of defect. The live-chamber count is the signal
that was already on the wire. It cannot misfire on a re-grant (a full gun publishes with
`action = nil`) or on a magazine change (`action == "Magazine"`), which are the two cases that
defeated the earlier round-counting attempts.

**And the `load` voice moves onto the same edge** (one edge, two readers), which closes 224a(e) for
this gun and for the lever at the same time: the gate then clicks once per cartridge instead of once
per run. That is a change to a SHIPPED gun's behaviour, it is an improvement, it is measured, and it
is the Director's to refuse (D-c). If refused, the lifter keeps `fedShell` and the voice keeps its
own edge — and then this gun shows five lifts and makes one click, which should be said out loud.

### 7.3 The red dot: drawn, unconditional, and **always lit**

`SIGHT = "reddot"`, `scope = nil` — so aiming takes the shotgun's path with the gun and both gloves
left in the view, and **not** the Rigby's full-screen mask (`Viewmodel.hiddenByScope` requires an
`optics.eyepiece`, and this row carries no `scope` block at all). That is what a red dot is for and
it is Karen's own polish target: *"bead aiming with hands and no crosshair"*.

The dot is a **drawn piece and not the mesh's emissive map**, and that is a fact about Roblox:
`SurfaceAppearance` has four channels — ColorMap, NormalMap, MetalnessMap, RoughnessMap — and **no
emission** (source 13.3), so the artist's `M_Sight01_Emissive.png` renders as nothing at all. So:
one small `Neon` ball, `Geometry.layout`'s `dotDiameter` (≈3 mm = 0.012 studs), at
`Geometry.beadOffset` — **the same expression `Geometry.sight` aims with, not a copy of it** (the
rule `Gun.beadOffset` and `Rifle.Geometry.beadOffset` already keep: the point the eye is laid on and
the thing the eye sees must come from one expression). The reticle plane is MEASURED as the centre of
`sight.001`'s rear glass window on the tube's own optical axis, and **drawn at x = 0** because the
shot leaves at x = 0 and a sight that disagrees with the bore lies.

**It is lit all the time, and the BRIEF's proposal to gate it on the aim blend is overruled on
evidence.** `Enum.Material.Neon` makes a part render bright; it is **not a light source** — Roblox
emits light only from `PointLight` / `SpotLight` / `SurfaceLight` instances (source 13.4) — so "a
light source the player cannot switch off" is not what an always-on dot is. A real red dot is always
on, the piece is 3 mm, and gating it would mean a per-frame property write in `Viewmodel.update` for
a cosmetic that costs nothing. **If Karen looks and dislikes it on the hip, it is a per-frame
transparency write at one owner (K-5, queued as 225a) and not a redesign.**

### 7.4 The gun must NOT move when it cycles itself — and that is a code change

**The most important finding in this design, and the BRIEF does not anticipate it.** Traced through
shipped code:

- `Mode.step` drives `openTilt` 0 → 1 → 0 from the replica's `open`.
- `Mode.viewmodelOffset` ends with `pose = pose:Lerp(Mode.breakOffset(config), clamp(openTilt))`.
- `Mode.handFrame` ends with `lerpHand(value, handFrameOf(poses.reload[side]), clamp(openTilt))`.

So while the action is open the gun and both hands travel **to the cycle pose and back, whatever the
aim is**. On a self-cycling gun at 0.42 s per shot that is a lurch out of the sight picture **2.4
times a second**, and no choice of pose data can fix it: if `cycle.gun` equals `carry.gun` the hip is
steady and the AIMED hold still slides to the carry; if it equals the aimed hold, the reverse.

**The fix is one pose number read by the one owner of the blend.** `Camera.Mode` is the pure pose
composer and is already that owner:

- `poses.json` → `weapons.<id>.cycle.poseShare`, absent on the three shipped guns;
- `Viewmodel.view` publishes `CYCLE_POSE_SHARE = action.poseShare or 1`;
- both sites read `math.clamp(config.CYCLE_POSE_SHARE or 1, 0, 1)` and multiply it into the lerp
  weight. **At 1 every shipped gun is bit-for-bit what it is today**, provably: the key is absent, so
  the value is 1, so the expression is the expression.
- This gun ships at **`poseShare = 0`**: the shooter does nothing, so the gun does not move — only
  the bolt does. Both arms are reachable by parameter, so a spec drives both with no session.

**The stated cost, because it is real:** this gun has ONE action pose block (`cycle`) read by both
sequences (`Viewmodel.view` takes `data.reload or data.cycle`), so `poseShare = 0` also means the
gun does not change its hold during the 2.6 s RELOAD — the tray rises five times, the readout
climbs, and the gun stays mounted. A per-sequence hold is a second drawn state, not a number, and it
is **225a** with Karen's eye on it (K-4). She can dial `poseShare` anywhere in 0..1 live.

### 7.5 What the pose set carries, and what moves

`poses.json` → `weapons.semiauto`, version 4, with **`cycle`** as the action block (a weapon
carrying both `reload` and `cycle`, or neither, fails `Viewmodel.validate` and therefore the
harness).

| Block | Present | What it draws on this gun |
|---|---|---|
| `carry`, `aim`, `raise`, `fire` | yes | as the other three. `aim` is `eyeReliefStuds` + `cheekDeg` solved from `Geometry.sight` — the **dot's own plane** |
| `fire.loads` | **yes** | the shotgun's own two rows (`Slug` 1.45 / 0.82 / 1.25, `Buck` 1.0), because it is the same shell. Without it `Viewmodel.loadFor` answers `NEUTRAL_LOAD` and a slug would kick like buckshot |
| `cycle.gun`, `cycle.left`, `cycle.right` | yes | read only through `poseShare`, which is 0 — so they are inert today and are the dial Karen turns to make the gun move (7.4) |
| `cycle.poseShare` | **yes, new, = 0** | 7.4 |
| `cycle.openSeconds` 0.10, `closeSeconds` 0.15 | yes | the drawn windows, both **strictly less** than the server's 0.12 / 0.18 steps — the shipped rule `lever.spec` and `viewmodel_poses.spec` assert |
| `cycle.drawStuds` | **yes, and it is the bolt's one live dial** | MEASURED: the ejection port's clear travel, ≈0.35–0.40 studs. Bound: ≥ **0.29 studs** (76 mm at 259 mm/stud), or a hull could not clear the port |
| `cycle.lifterDeg`, `cycle.lifterSeconds` | **yes, new** | the tray's throw (seeded from the measured pivot so the free end rises ≥ 0.079 studs) and its window, **0.30 < the `Load` step's 0.38** |
| `cycle.openDeg`, `cycle.hingeStuds` | yes, inert | read by no branch on this gun; they ship because `Viewmodel.view` publishes `BREAK_OPEN_DEG` and `BREAK_HINGE_STUDS` and the flat-name parity case requires every name the SHOTGUN's view has. The lever's `hingeStuds` ships for exactly this reason |
| `cycle.liftDeg`, `liftFraction` | yes, inert | read only on the `"slide"` path |
| `cycle.load`, `cycle.shells` | yes, inert | the flat-name set again (`SHELL_LOAD`, `SHELL_*`). The drawn feed is OFF (`HAND_FED_SHELLS = false`) |
| `cycle.hand` | **no** | the shooter's hands do **nothing** during a cycle. Absent ⇒ `BOLT_HAND` nil ⇒ `poseHands` leaves the right hand on the grip, which is the whole truth about a gas gun |
| `cycle.magazine` | **no** | no box. Its absence keeps `poseHands`' magazine branch and `magazineAtProgress` off |

**So what actually moves:** on a shot, the bolt alone, back 0.10 s and home 0.15 s, with the hull
leaving the port; on `R`, the tray alone, five times, 0.30 s each. The gun and both gloves hold
still. That is the gun.

---

## 8. The voice

No audio is uploaded (D-10). Every id is Roblox-provided licensed library audio this repo has
already measured to load. **Nobody here has heard any of it: Karen's ears decide, and every number
is one line.** `Sound.voiceFor` answers nil for a key a row does not carry, so a missing key is
silence and never a wrong sound.

```
shot = the SHOTGUN's own id, pitch and cut, unchanged
  -- the same gun firing the same shell. A different report for the same cartridge would be the
  -- Hud's "SLUG" on a .416 all over again.
bolt = the lever's clack, SHORTER and HIGHER (cut 0.22, pitch 1.15)
  -- a gas bolt slamming home is a lighter, faster piece of steel than a lever throw. Played on
  -- BOTH edges by `CameraBoot` (`Camera.breakSound` -> open / close), which is already how a
  -- weapon with a `bolt` voice is handled -- so one shot makes two clicks 0.12 s apart, which is
  -- what a semi-auto sounds like.
load = the lever's gate click (already a shell-handling sample), pitch 0.95
  -- one per shell, on `Camera.fedShell` (7.2). No `magazine` key: this gun has no box.
```

**No new voice key and no new `Sound.*` function** — `Sound.load` shipped in task 224.

---

## 9. Ballistics: the cartridge is shared, and this is the one place sharing is correct

### 9.1 The rows

`RANGE_STUDS`, `PELLETS`, `SPREAD_FULL_DEG`, `MUZZLE_STUDS_PER_S`, `DRAG_PER_STUD`, `ZERO_STUDS` and
`GRAVITY_SCALE` are **`Shotgun.CONFIG`'s, by reference** (`{ Slug = 330, Buck = 100 }`,
`{ 1, 9 }`, `{ 0.16, 1.6 }`, `{ 1752, 1442 }`, `{ 1.059e-3, 2.631e-3 }`, `{ 180, 70 }`,
`{ 1.0, 1.0 }`). **D-8 confirmed.**

**And it is the exact opposite of task 224's rule, so the design says why both are right.** The two
RIFLES share no number because they are different cartridges and `Rifle`'s header warns that the file
holding Karen's accepted numbers must not become the file everybody edits. The two SHOTGUNS fire the
**identical shell**: a 12-gauge slug does not care that the gun behind it has a gas piston, so a
second copy of `RANGE_STUDS` would be a second answer to *"how far does a slug go"* — the defect, not
the protection. A 710 mm barrel against the double's is a real difference of a few per cent in
muzzle velocity and **this repo has no measurement of it**; inventing one would be a number that
looks measured and is not.

### 9.2 One answer for the shell's identity too (a second shared-code change, named)

`AMMO_KINDS`, `AMMO_LABEL` and `AMMO_GLYPH` are today **literals inside `Weapons.ROWS.shotgun`**,
not in `Shotgun.CONFIG`. They are facts about the 12-gauge cartridge — which kinds exist, what each
is called on screen, which `Style.glyph` draws it — and two guns now fire it. So they **move into
`Shotgun.CONFIG`, value for value**, and both rows read them. No value changes; `rifle.spec`'s
field-by-field walk of the shotgun's row against that config then covers them, and
`Weapons.ROWS.shotgun` keeps the comment that says why the glyph exists.

If the Director prefers nothing in `Shotgun.CONFIG` to move, the alternative is a second literal in
`SemiAuto.CONFIG` plus a spec case asserting the two are equal (**D-a**, ships as the move).

### 9.3 What is issued with the gun

`Shop.BASE_AMMO.semiauto = { Buck = true }` — the shotgun's rule, not the rifle's: **buckshot is
free with the gun and the slug is still the ladder's first rung** (`ammo.slug`, 120). `INITIAL_AMMO`
is `"Buck"`, and `Shop.startFor` already hands a kind he may not be issued a pocket of **zero**
rather than an absent one, so the readout stays honest. `START_RESERVE = { Slug = 10, Buck = 10 }`
— two tubes of each, the lever's precedent, and Karen's dial.

---

## 10. The hardware

### 10.1 Scale: 4.9 studs, and it is a fact about the gun (D-16 confirmed)

The shotgun and the Rigby are 4.4 because both are about 45 inches. This gun measures **1270 mm = 50
inches**, cross-checked twice on the model (barrel 719 mm against a sold 710; receiver 38 mm against
a real 38, both inside 1.5 %, neither fitted), and at this repo's 3.87 studs/m that is **4.91 → 4.9**.
It is the longest gun in the game and the real one is: a 28-inch barrel on a semi-auto receiver is
longer than a 45-inch double. **One stud is 259.2 mm on this gun**, which is the conversion every
bound in section 14 uses.

**It is not too long in the hand, and that is checkable rather than arguable**: everything downstream
is per-row data (`HANDLE_SIZE.Z`, `MUZZLE_OFFSET.Z = -2.45`, `MESH_SIZE_STUDS`) and the poses are
authored fresh for this gun, so the length costs nothing and buys its silhouette. The one thing it
*can* cost is the muzzle clipping the near plane in the aimed pose — which is a pose number
(`aim.eyeReliefStuds`) and a screenshot, not a scale decision. `GRIP.Z = 1.56` is the rifle's 1.4
scaled by 4.9/4.4; it places the **world** Tool in the character's hand and is **not** the
first-person anchor (that is `Geometry.gripOffset`, measured). The lever ships the same two numbers
0.18 apart for the same reason.

### 10.2 Six groups, three materials, and the measurement list

**The split is forced by the materials** (D-2 confirmed): `gltf_split.group_mesh` refuses a group
spanning two materials — *"one MeshPart is one material"* — and this file has three
(`M_Shotgun_barrel`, `M_Shotgun_stock`, `M_Sight`) where the lever had one. Two of the six groups are
material boundaries and two are parts that have to move.

| Group | Objects | Material | Tris | Worn as | Why it is its own group |
|---|---|---|---|---|---|
| `action` | 013, 016, 017, 020, 021 | stock | 2400 | `Model` | the body: the piece that must be there for the gun to count as dressed (`Hardware.wearsMesh`) |
| `barrel` | 012, 022, 004 | barrel | 2802 | `Barrel` | a different material; static |
| `stock` | 019 | stock | 1062 | `Stock` | the silhouette's other half |
| `bolt` | 014 | stock | 634 | `Bolt` | **IT MOVES** — the cycle |
| `lifter` | 018 | stock | 248 | `Lifter` | **IT MOVES** — the reload |
| `sight` | sight.001 | sight | 1578 | `Sight` | a different material, and the dot sits on it |

**8,724 triangles in total, worst group 2,802**, against the Rigby's 18,672 prepped and its worst
group's 8,258: **nothing is decimated.** Roblox's ceiling is 20,000 per mesh.

**Six uploads is two more than any gun so far, and that is said here rather than arriving as a
surprise at the upload step** (D-2). It also means six manifest rows and six `ASSET_KEYS` — and
`tests/server/assets_seam.spec.luau` derives its expected set from `Weapons.ROWS[id].ASSET_KEYS` and
requires each key to be in the manifest **exactly once**, so the row cannot land before the six rows
with real ids. That is an ordering constraint, not a nicety (section 18 step 3).

The pipeline is the lever's, step for step (rule 2), and it runs **outside the repo**:

```
FBX --(headless Blender, a one-off script in the runs directory)--> glTF
    --> tools/gltf_split.py probe      (THE MEASUREMENTS)
    --> tools/gltf_split.py split  SEMIAUTO_PLAN
    --> tools/asset_prep.py prep --preset gun   (per group; NO new recipe)
    --> tools/roblox_upload.py     (STOP POINT: "READY TO UPLOAD 225 <folders>")
```

`gltf_split` stays **stdlib-only and Blender-free**, which its docstring states as a design property,
so the FBX→glTF conversion is a script in the runs directory and never an import of `bpy`.

**`SEMIAUTO_PLAN`**, beside the other three: `lengthStuds = 4.9`; `boreUpStuds = 0.12` (the same bore
line all three shipped guns use — what is MEASURED off this model is everything relative to it);
`axisFromNode = "shotgun.012"` (the barrel's principal axis **is** the bore line);
`upTowardNode = "shotgun.020"` (the rail, certainly above the bore);
`backTowardNode = "shotgun.019"` (the butt stock, certainly behind the muzzle);
`anchorSize = 1.0e-4`; the six groups above; `dropNodes = []` — every node belongs on the gun, and
refusal 4 guarantees a node in no group stops the split rather than vanishing.

**The frame is the gun's own and it is already axis-aligned**: forward (the muzzle) is **−Y**, up is
**+Z**, so right is **−X**, and that handedness is proved by the gun rather than asserted — the
charging handle (`shotgun.014`, to x −0.0375) and the bolt-release button (`shotgun.021`, entirely at
x −0.0247..−0.0203) are the only two objects off the centre line, they are on the same side, and on
an MP-153 both are on the right. There is no Sketchfab tilt to measure out. Every group carries the
WHOLE gun's bounding box through the anchor triangles, so all six import at one size and one origin
and assemble at **ONE CFrame with no per-piece offset** (task 96's trick, which all three shipped
guns use).

**What `probe` must produce before `SemiAuto.Geometry` is written** — the task's measurement list,
and not one of these numbers is invented in this document:

1. each group's box in the Handle's frame (the six fallback boxes);
2. the bore line's height and the muzzle face (`Geometry.muzzle`);
3. the **reticle plane**: `sight.001`'s rear glass window centre and the tube's optical axis
   (`beadOffset`, `dotAt`, `dotDiameter`);
4. the **bolt's travel**: the ejection port's clear length (`boltBackStuds`, the seed for
   `cycle.drawStuds`), against the 76 mm hull bound;
5. the **lifter's pivot** (`lifterHinge`, the recipe in 7.2), its free end (`lifterTipOffset`), and
   the angle at which that end has risen one hull diameter (the seed for `cycle.lifterDeg`);
6. the **loading port's** centre on the receiver's underside (`portAt`) — recorded now, read by 225a;
7. the **stock's wrist**: the narrowest cross-section between the receiver's rear and the comb, its
   principal axis, its half-width and its holdable half-length (`gripOffset` / `gripAxis` /
   `gripRadius` / `gripHalfLength`) — task 188's four tolerances, which exist because a pose 0.158
   along the axis put the hand on the comb and the spec passed;
8. the **fore-end's** holdable band (centre, axis, radius) for the LEFT glove — section 15.1 case 14;
9. `HandAssets.GRIP_STUDS` / `GRIP_RADIUS_STUDS` checked against both of those, as the Rigby's knob
   and the lever's loop were.

### 10.3 Textures, manifest

The 4K and 2K maps go down to **1024**. Four maps per material set — base colour, normal, metalness,
roughness — and three sets, one per group's material. **The packed `Mixed_AO` is not an ORM and is
dropped**: `SurfaceAppearance` has no occlusion channel (source 13.3), so an AO map renders as
nothing. The artist ships metalness and roughness as separate files, but the FBX→glTF export **packs
them into one image** (the glTF spec, and `asset_prep`'s own docstring), so `asset_prep`'s existing
split is what unpacks them — **no new recipe and no new preset**: `--preset gun` classifies regions by
pixel and writes metalness 0.10 / roughness ≈0.50 on the metal, which are this repo's measured
anti-sky-mirror numbers. **No base colour is recoloured.** The Builder reports what each group was
classified as, having looked at the preview (rule 5).

`LOOK` (the fallback colours, drawn only before the uploads load and never on top of them) is
**sampled off the prepped previews**, above the albedo floor task 22 measured, and is this model's
own: an MP-153 is blued steel with a dark stock, not the Rigby's walnut and not the 1895's stainless.

Six new `Assets.ROWS` rows, appended and versioned, never edited in place: `semiauto.action`,
`.barrel`, `.stock`, `.bolt`, `.lifter`, `.sight`, each `kind = "meshpart"`,
`source = "creator-store"`, Karen's creator id, **no `scope`** (they are `runtime` keys — the world
Tool wears the same meshes the viewmodel clones), `sizeStuds = SemiAutoGeometry.MESH_SIZE_STUDS`,
`naturalSizeStuds` = the split report's box at 100×, `offsetStuds = Vector3.zero`,
`rotationDeg = Vector3.new(0, SemiAutoGeometry.MESH_ROTATION_DEG, 0)`, `texturePx = 1024`,
`trisDeclared` **measured** by `asset_prep`, and a `licence` block quoting the Fab Standard /
Personal terms as the boar's and the lever's do. `assets/uploads.json` gets one row per upload with
Karen's words verbatim (*"Upload, sell in shop (Recommended)"*). `Assets.KEYS` is **not** extended —
the lever's precedent: the keys live once in the geometry's `ASSET_KEYS` and once in the row's.

If moderation rejects a group, `Assets.byKey` answers nil, `ViewmodelAssetsBoot` publishes the folder
without it, and that group is drawn from `Geometry.pieces`' measured box — a plain dark gun, playable
and honest. Say so in the report rather than shipping a hole.

---

## 11. The shop

### 11.1 One row at 500, and the ladder is the argument (D-12 confirmed)

```
ITEM.SEMIAUTO = "shotgun.semiauto"      -- so the two shotguns sort together, as rifle.* do
label = "SEMI-AUTO SHOTGUN"             -- 17 <= LABEL_MAX 18
category = "weapon", sale = true, grants = { weapon = "semiauto" }
price = 500, hunts = 8
blurb (109 chars, in 20..135):
  "Five rounds in the tube and it cycles itself: the same slug and buckshot the double fires,
   out to about 90 m."
```

Every number in the blurb is one this repo measured (`Shop.Row.blurb`'s own rule): five rounds is
`MAGAZINE`, 90 m is `Shotgun.CONFIG.RANGE_STUDS.Slug` (330 studs = 92 m, rounded **down**, as the
slug row's own blurb does).

**Why it is UNDER the lever's 650:** the scarce thing in a driven hunt is REACH, and this gun adds
none — it fires the free gun's shell at the free gun's range. What it buys is VOLUME. The ladder
reads free double → **500 semi-auto (volume)** → 650 lever (reach) → 1500 scoped rifle (precision at
range), and each rung buys a different thing. `hunts = 8` sits between the high seat's 5 and the
unlimited pocket's 10.

**Its position in `Shop.ORDER` is arithmetic, not a preference:** the list is cheapest-first and
`shop.spec` asserts the whole list ascends, so 500 goes at **index 3**, between the beater's licence
(250) and THE HIDE (575), and every later index shifts by one.

### 11.2 A measured consequence: the shop is then FULL

`#Shop.ORDER` goes 11 → **12**, and `Shop.CONFIG.MAX_ITEMS` is 12 — whose own comment says *"twelve
so the next one needs no second decision"*. So this row takes the last slot: it passes `rowsOk`
exactly, and **the next catalogue row needs `MAX_ITEMS` moved**. Stated here so that arrives as a
one-line decision and not as a red harness.

### 11.3 The shop window's picture is mandatory

`tests/client/shop_panel.spec.luau`'s *"has a picture for every row it sells"* walks **every**
`Shop.ORDER` id and requires `ShopDisplay.knows(id)`, a model, ≥ 3 parts and a `PrimaryPart`. **A
shop row without a `DRAW` entry turns the harness red.** The BRIEF does not mention it; it is one
entry through the shipped generic builder:

```luau
[ShopData.ITEM.SEMIAUTO] = {
  view = RIFLE_VIEW,
  build = function(model, _id) buildGun(model, SemiAutoGeometry, SemiAuto.CONFIG) end,
},
```

`buildGun` is already *"one drawing for any gun this repo has geometry for"* (task 224), which is why
this is three lines and not a second answer to what a gun looks like.

---

## 12. The hotbar, the loadout, and no new flag

```
Weapons.ORDER   = { "shotgun", "rifle", "lever", "semiauto" }
Weapons.PRIMARY = "shotgun"     -- unchanged
Weapons.FLAG    = "RIFLE"       -- unchanged
```

`Weapons.ORDER` **is** the hotbar: the engine's Backpack GUI numbers a slot the first time it sees a
Tool, so `Weapon.refreshArming` granting in this order is the whole mechanism. It **appends** at
slot 4 — it is not slid in beside the shotgun, because reordering would move the rifle's and lever's
slot numbers, which Karen has been playing with since tasks 141 and 224.

**A flag-off spawn and the unrestricted loadout stay bit-for-bit what they are, provably:**
`Weapons.loadoutFor(false, …)` returns `{ PRIMARY }`, and `carriable(nil)` returns exactly the ids
whose row has no `OWNED_ONLY` — which is `{ shotgun, rifle }` before this task and
`{ shotgun, rifle }` after it. Nothing in this task touches either branch.

**No new feature flag** (item 7 confirmed). The gun is gated by **ownership** (`OWNED_ONLY` +
`Shop.ownsWeapon`), a shipped mechanism strictly stronger than a flag — nobody who has not bought it
can hold one — and the `RIFLE` flag already decides whether any bought weapon is handed out at all. A
flag whose two states are "a shop row exists" and "a shop row does not" is the map-switch mistake
CLAUDE.md names: *a switch that cannot be switched off is not a feature flag*. The one flag read in
the whole weapon system stays `Weapons.loadout()`, at that boundary, passed inward as a list.

---

## 13. External sources

Five external sources plus the repo's own prior art. **No code and no asset is taken from any of
them**; what is borrowed is a fact, a mechanism's shape, or one pattern, and that is recorded here
(rule 2). The Builder writes `docs/research/2026-10-20-semiauto-shotgun.md` with these and an
`INDEX.md` row **before any code** (rule 1), and **pastes the URL it actually resolved** for 13.1 and
13.2, whose deep links carry ids.

**13.1 Hunter-Ed (Kalkomey) hunter-education course, "Semi-Automatic Action"** —
https://www.hunter-ed.com/national/studyGuide/ (firearm actions section).
*Licence:* course material, all rights reserved (Kalkomey). *Maintenance:* actively maintained
state hunter-education courseware.
*Good at:* the cycle as ONE stroke the shooter does not drive — fire, unlock, extract, eject, cock,
feed, lock — which is exactly `AUTO_CYCLE = true` with `Break`/`Close` and nothing in the shooter's
hands (sections 6.1, 7.4).
*Bad at:* a teaching page; no timings at all, so it cannot settle 0.30 s.
*Adopted:* the two-step reading of one stroke, `CYCLE_EJECTS = "spent"` as its consequence, and the
fact that the hands do not move — which is what `poseShare = 0` draws.

**13.2 Baikal / Izhmekh MP-153 specification and owner's manual** — https://baikalinc.ru/
(manufacturer's catalogue), cross-read against a retail spec sheet so that one typo cannot become
this gun's capacity.
*Licence:* manufacturer and retail material, all rights reserved; figures cited as facts.
*Maintenance:* live catalogue pages, revised with the model range.
*Good at:* the 4+1 tube, the gas system, the barrel lengths and the overall length — the four
numbers section 6.3 and 10.1 check the MODEL against.
*Bad at:* marketing copy on recoil with no measured figure; no drawing of the lifter.
*Adopted:* the capacity and the lengths, and nothing else. Every number in sections 6.3 and 10.1 is
measured off the file and merely **agrees** with this.

**13.3 Roblox Creator Documentation, `SurfaceAppearance`** —
https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance
*Licence:* Roblox creator documentation (content CC-BY-4.0 in `github.com/Roblox/creator-docs`).
*Maintenance:* actively maintained, public repository.
*Good at:* the exhaustive channel list — ColorMap, NormalMap, MetalnessMap, RoughnessMap — which is
the whole evidence that the artist's emissive map renders as nothing and that `Mixed_AO` has nowhere
to go (sections 7.3, 10.3).
*Bad at:* it documents the class, not the renderer, so "what Neon looks like beside it" comes from
13.4.
*Adopted:* the dot is a drawn piece, not a texture channel; the AO map is dropped.

**13.4 Roblox Creator Documentation, `Enum.Material`** —
https://create.roblox.com/docs/reference/engine/enums/Material
*Licence / maintenance:* as 13.3.
*Good at:* `Neon` is a MATERIAL that renders bright — Roblox emits light only from light
*instances* — which is why an always-on dot is not a light nobody can switch off (7.3).
*Bad at:* no photometry; how bright the dot reads on screen is a screenshot, not a document.
*Adopted:* the dot ships lit, and the decision is Karen's after she looks.

**13.5 ioquake3, `code/cgame/cg_weapons.c` (`CG_AddPlayerWeapon`, `CG_MachinegunSpinAngle`)** —
https://github.com/ioquake/ioq3
*Licence:* GPL-2.0. *Maintenance:* actively maintained fork of the id Software release.
*Good at:* the established pattern for a weapon's **second, independently driven sub-part**: the
barrel is its own model placed every frame from a value derived from game state and a local clock,
beside the weapon's own animation, rather than being baked into one animation. That is section 7.2
with our names in it — `lifterSwing` from `liftProgress`, beside `boltTravel` from `cycleProgress`.
*Bad at:* a C renderer with its own entity system; **no code is copied** and the clock seam here is
this repo's own (`Viewmodel.setClock`).
*Adopted:* two sub-parts, two drivers, one per-frame placement site; the state says WHICH step and
HOW LONG, the client owns HOW FAR THROUGH — which is `setMagazine`'s own rule, already shipped here.

**13.6 Chuck Hawks, "Shotgun Recoil Table"** — https://www.chuckhawks.com/shotgun_recoil_table.htm
*Licence:* editorial, all rights reserved. *Maintenance:* **dormant** (a static reference page).
*Good at:* free-recoil energy for 12-gauge loads, which is the only published number behind "a slug
kicks harder than buckshot" — and that ratio is already in `fire.loads` (Slug 1.45).
*Bad at:* it is **fixed-breech** free recoil and says nothing about a gas gun. So D-11's *direction*
(a gas gun spends part of the impulse cycling the action, spread over the carrier's travel) is
physics and the manufacturer's claim; **the magnitude is not measured anywhere and is therefore
Karen's dial, not a derivation.** Said plainly because the alternative is a number that looks
measured and is not.
*Adopted:* the direction only, and the per-load ratio, which is the shotgun's own.

**13.7 In-repo prior art, which rule 2 makes the first place to look.** Every pattern this design
reuses is already shipped and reviewed here: `docs/design/lever-rifle.md` (the fourth row's whole
shape, `cycleRefusal`, `HAND_FED_SHELLS`, the measurement list);
`docs/design/rifle.md` (a second weapon as a row, the sight filter, `boltLift`'s sign);
`docs/design/shotgun.md` (the reducer and the remotes); `docs/design/shop.md` section 7.1 (the nil
ownership set and its accepted cost); `docs/research/2026-10-20-lever-action.md`;
`2026-10-09-rifle-scope.md`; `2026-10-10-rifle-bolt-magazine-sound.md`;
`2026-10-14-ballistics-lead.md`; `2026-10-15-rifle-right-hand.md` (hand anchors as a line and a
radius); `2026-10-01-poses-as-data.md`; `backups/2026-10-10-rifle-open-sights.md` (the sight
machinery this design deliberately does NOT reuse, and why).

---

## 14. Numeric targets

| Target | Value | Where it is checked |
|---|---|---|
| Overall length | 4.9 studs (50 in at 45 in = 4.4); 1 stud = 259.2 mm | `semiauto.spec`: `HANDLE_SIZE.Z == 4.9`, `MUZZLE_OFFSET.Z == -HANDLE_SIZE.Z/2` |
| Capacity | 5 chambers, 5 magazine, 10+10 in the pocket | `semiauto.spec`; `Hud.PIP_MAX` 8, so five pips draw |
| Cycle | 0.12 + 0.18 = 0.30 s; drawn 0.10 / 0.15, both **strictly less** | `semiauto.spec` (the sum) and the shipped "draws the break and the close faster than the server performs them" rule |
| Rate | 0.42 s between shots (2.38 shots/s); five rounds in 1.68 s after the first | `semiauto.spec`: `BARREL_DELAY + CYCLE_TOTAL` |
| Reload | 0.35 + 5 × 0.38 + 0.35 = 2.60 s full; **1.46 s** for a two-shell top-up | `semiauto.spec` (the sum, and the top-up driven through the reducer) |
| Bolt travel | `cycle.drawStuds` ≥ 0.29 studs (76 mm, one hull) | `semiauto.spec` via `Geometry.boltTravel` |
| Lifter rise | the free end rises ≥ 0.079 studs (20.5 mm, one hull diameter) at progress 1, and **upward** | `semiauto.spec` via `lifterSwing` + `lifterTipOffset` |
| Lifter window | `lifterSeconds` 0.30 < the `Load` step's 0.38 | `semiauto.spec` |
| The gun does not move while it cycles | `CYCLE_POSE_SHARE == 0`: the gun frame and both hand frames at `openTilt` 1 equal those at 0, to 1e-6 | `semiauto.spec` via `Mode.viewmodelOffset` / `Mode.handOffsetAt` |
| Ballistics | identical to the shotgun's for both kinds, by reference | `semiauto.spec`: table identity against `Shotgun.CONFIG` |
| Triangles | 8,724 total; worst group 2,802; nothing decimated (repo's shipped worst 8,258; Roblox 20,000/mesh) | `asset_prep` report, `Assets.ROWS.trisDeclared` |
| Textures | 1024 px, four maps, three material sets, no AO | the manifest rows |
| Drawn parts | Handle + 2 envelopes + 7 pieces + 2 gloves = **12**; `Geometry.partCount` = **9** | `Geometry.partCount`, `Camera.stats().parts` |
| Camera cost | unchanged: ≤ 0.3 ms average `Camera.update` (one extra envelope and its riders per frame) | `camera_client.spec`'s existing budget case |
| Hud label | `"AUTO"`, 4 ≤ 7 (the `gun` cell is 88 px; `SHOTGUN` measures 46) | `rifle_client.spec`'s column-alignment case, extended |
| Shop | price 500, hunts 8, label 17 ≤ 18, blurb 109 in 20..135, `#Shop.ORDER` **12** = `MAX_ITEMS` | `shop.spec` and `Shop.rowsOk` |
| Manifest | six keys, each in `keysFor("runtime")` exactly once | `assets_seam.spec` |

---

## 15. How it is tested

### 15.1 Server spec — `tests/server/semiauto.spec.luau` *(new)*

Pure, no session, driven as `lever.spec` is. **Every case must ENTER this weapon's own branch**
rather than pass alongside it ([L-093], and task 224 round 2's mirrored-frame miss) — written out per
case. The BRIEF's item 8 list is covered by cases 5, 6, 7, 8, 9, 11, 12, 15, 16, 17.

1. **The table holds four weapons, in hotbar order, frozen all the way down.** `Weapons.ids()` is
   `{ shotgun, rifle, lever, semiauto }`, `PRIMARY` is `shotgun`, every row deep-frozen.
   *Only this gun:* the fourth id and `slot == 4`.
2. **The row is `SemiAuto.CONFIG`, field by field** — a `pairs` walk with a skip set, so a number
   that moves fails the harness instead of drifting.
3. **The cartridge is the shotgun's, by reference and not by copy:** the seven ballistic tables and
   the three identity tables are **the same table objects** as `Shotgun.CONFIG`'s, and the row's
   `AMMO_GLYPH` is identical to the shotgun row's with no value changed (section 9.2).
   *Only this gun:* the lever's and the rifle's rows must differ from `Shotgun.CONFIG`'s.
4. **Buckshot patterns and the slug does not:** `Pattern.directions("Buck", aim, rng, row)` returns
   nine directions inside the cone and `"Slug"` returns exactly one equal to `aim` — driven with
   THIS row.
5. **The cycle is two steps, the total is the sum**, `CYCLE_TOTAL == 0.30`, `CYCLE_EJECTS == "spent"`,
   `AUTO_CYCLE == true`, and the rate is `BARREL_DELAY + CYCLE_TOTAL == 0.42`.
   *Only this gun:* 0.30 against the lever's 1.10 and the bolt's 1.62.
6. **The reload is `Break` + five `Load` + `Close`, the total is the sum, and it carries NO
   `Magazine` step.** *Only this gun:* five `Load`s; the rifle's `RELOAD` begins with `Magazine`.
7. **The reducer, driven with this row:** fire → busy for `BARREL_DELAY`; `Break` ejects the spent
   hull and **leaves the other four live** (counted); `Close` chambers; five shots empty it;
   a full `RELOAD` walk refills five, one chamber and one pocket round per step.
8. **A PARTIAL top-up ends early, through the shipped `cycleRefusal`:** three live, `R`, two `Load`s
   succeed, the third answers `barrel-full`, `cycleRefusal` answers `"finish"`, the sequence finishes
   at `Close`, and the charged window is **1.46 s and not 2.60**. Driven step by step through
   `StateMachine.apply` + `cycleRefusal` (`runCycle` is not exported — 224a(d)).
9. **`X` on a full tube changes the NEXT load and not the tube** (section 6.4): `SelectAmmo` to
   `Slug`, then the `RELOAD` walk leaves all five chambers `loaded == "Buck"`, the readout prints
   `5/5 SLUG <pocket>`, and a shot fired from that state flies as **Buck** (`state.loaded[selected]`).
   *This is the arm nothing else in the game can enter.*
10. **`waitFor` charges each sequence its own window** (`Break` is 0.12 in `CYCLE` and 0.35 in
    `RELOAD`), driven with `steps` named — the defect task 184 measured.
11. **No row carries a forbidden field** — the existing loop, now over four ids.
12. **Geometry and shape resolve for every weapon and are four different modules**;
    `Weapons.geometry("semiauto")` is `SemiAuto.Geometry` and `Shapes.for_("semiauto")` is
    `ShapeSemiAuto`; the world shape carries **two parallel pipes** and no loop and no scope tube.
13. **THE BOLT GOES STRAIGHT BACK:** `CYCLE_KIND == "straight"`, `CYCLE_GROUP_NAME == "Bolt"`;
    `boltTravel` at progress 0 is identity; at progress 1 the bolt's own box centre has moved
    **+Z only** (x and y unchanged to 1e-6) by `drawStuds`, and `drawStuds ≥ 0.29`.
    *The sign case for group one.*
14. **THE LIFTER GOES UP:** `LIFT_GROUP_NAME == "Lifter"`; `lifterSwing` at 0 is identity; at 1
    `lifterTipOffset` has a **greater Y** and the rise is ≥ 0.079 studs; `lifterWeight` is 0 at 0,
    **1 at 0.5** and 0 at 1. *The sign case for group two, and the one case that proves the tray is
    at full rise mid-`Load`.*
15. **The pose set:** `validate` finds nothing wrong with the shipped file; `weapons.semiauto`
    carries a `cycle` and no `reload`, no `magazine`, **no `hand`**; `openSeconds` and `closeSeconds`
    are each strictly less than their server step; `lifterSeconds < 0.38`; `poseShare == 0`.
16. **THE GUN HOLDS STILL WHILE IT CYCLES:** with this weapon's config,
    `Mode.viewmodelOffset(stateAt(blend, openTilt = 1))` equals the same at `openTilt = 0` to 1e-6,
    and so do `Mode.handOffsetAt("right", …)` and `("left", …)` — at blend 0 **and** at blend 1.
    **Then the same assertions with `CYCLE_POSE_SHARE = 1` must DIFFER**, or the case proved nothing,
    and with the shotgun's config they must differ as well (the shipped behaviour is untouched).
17. **The hand anchors are ON the gun, written so they can fail** (section 15.4).
18. **The flat-name set:** every key `Viewmodel.view(DATA, "shotgun")` publishes is non-nil in
    `view(DATA, "semiauto")`, and this gun's own three (`LIFTER_DEG`, `LIFTER_SECONDS`,
    `CYCLE_POSE_SHARE`) are present, with `LIFTER_DEG` nil for the shotgun.
19. **Hud:** `readoutFor` prints `5/5 BUCK 10` for a full gun; `ammoChipFor` returns five pips, no
    selection, the pocket, and the **buckshot glyph** — which is the two-ammo magazine readout.
20. **`Viewmodel.handFeedsShells`** is false for `SemiAuto.Geometry` and true for `Gun`.

### 15.2 Shop — `tests/server/shop.spec.luau` *(edited)*

- `#Shop.ORDER` 11 → **12**, still ≤ `MAX_ITEMS`, still cheapest-first; **every positional assertion
  from index 3 on shifts by one** (`ORDER[3]` is now the semi-auto at 500).
- `Shop.ROWS[ITEM.SEMIAUTO]`: `price == 500`, `hunts == 8`, `grants.weapon == "semiauto"`,
  `sale == true`, `category == WEAPON`, the label and blurb inside their bounds.
- **The weapons shelf has three rows, cheapest first:** `semiauto`, `lever`, `rifle`.
- `Shop.ownsWeapon({ [ITEM.SEMIAUTO] = true }, "semiauto")` is true and false for a man who owns only
  the lever; `Shop.loadoutFrom(Weapons.ORDER, "shotgun", owned)` returns `{ shotgun, semiauto }`.
- `Shop.startFor(Weapons.ROWS.semiauto, owned)` issues **Buck** from `BASE_AMMO.semiauto` with a
  **zero** Slug pocket, and the Slug pocket becomes `START_RESERVE.Slug` once he also owns
  `ammo.slug` — the ladder, asserted.
- **`OWNED_ONLY` keeps it out of an unrestricted loadout:** `Weapons.loadoutFor(true, nil)` is
  `{ shotgun, rifle }`, bit-for-bit what it is before this task.
- **`rowsOk` is clean** with `Weapons.ROWS` passed in, and `mergedGrants` still has no conflict — it
  is in **no bundle**, because `Grants.weapon` is single-valued and THE FULL SEASON already covers
  the scoped rifle.

### 15.3 Client spec — `tests/client/semiauto_client.spec.luau` *(new)*

What only a running client can show, driven through `PlayerScripts` (never `StarterPlayerScripts`),
with the first-person branch reached **by parameter**, and asserting on **Instances** — the lesson of
task 224 rounds 1 and 2: a case that reads two numbers out of `poses.json` proves nothing. The gun is
put in the hand the way round 3 did: a `Tool` carrying `DrivenHunt.Weapon = "semiauto"` with a
`Handle`, handed through `Camera.Viewmodel.setSource`, and put back afterwards.

1. **The gun is built from its own geometry:** `Viewmodel.weaponId()` is `semiauto`, the clone has a
   part named `Bolt` **and** one named `Lifter`, both children of the Handle and neither a child of
   the other, and `Camera.stats().weapon` agrees. `Viewmodel.stats().parts == 12`.
2. **The aim is NOT a scope:** at blend 1 the FOV is the shotgun's, `Camera.scope()` is nil, no
   eyepiece and no reticle is visible anywhere up the parent chain (**visibility walked to the
   `ScreenGui`** — an audit that ignored parent visibility certified a blank screen twice), and the
   gun and **both gloves are parented**.
3. **The dot is on the sight's own plane and it is Neon:** a part named `Dot` exists, its material is
   `Neon`, and its world position is within 1e-3 of the `Sight` attachment's — the one expression
   both come from.
4. **The bolt travels and the fore-end glove does not follow it:** step `Mode.step` through a cycle;
   at `cycleProgress` 1 the `Bolt` part's world position has moved by `drawStuds` **along the gun's
   +Z** while `HandLeft`'s has moved by less than a hundredth of a stud. *The `poseHands` finding.*
5. **The gun itself does not move through that cycle:** the Handle's world CFrame at
   `cycleProgress` 1 equals its CFrame at 0 to 1e-4, and so do both gloves'. **Shown failing first**
   with `CYCLE_POSE_SHARE = 1` forced, and the measured displacement reported (the task-224 rule:
   a case is believed once it has been seen to fail).
6. **The lifter rises once per shell, on the wire's own evidence:** feed the break source two
   fabricated snapshots — `action = "Load"` with 3 Live, then with 4 Live — and assert
   `Camera.fedShell` true; step the injected clock to `lifterSeconds / 2` and assert the `Lifter`
   part's free end is at its measured full rise; step past `lifterSeconds` and assert it is home.
   Then a snapshot with `action = "Load"` and **no change** in the count, and assert `fedShell` is
   false and the tray does not restart. *This is the arm the whole second group exists for.*
7. **No loose shell is ever drawn:** after a simulated open with `spent = 1`,
   `Viewmodel.stats().shellsDrawn` does not move and no `SpentShell*` / `FreshShell*` child exists.
   *Only this gun: the shotgun's own case asserts the opposite in `gun_client.spec`.*
8. **The readout and the report column:** `Hud.readoutFor` on a live five-chamber state, and the GUN
   cell drawn for `AUTO` sits inside its 88 px column.

### 15.4 The hand anchors, written so they CAN fail (the BRIEF's item 9)

Task 224's lesson: round 1's case asserted `off < 0.5` on a gun whose own `gripRadius` is 0.0468 —
ten times the bound — and the real miss was 0.0602. So the bounds are published by the GEOMETRY, as a
**line and a radius** rather than a point, and the spec computes the hand's grip point through
`Mode.handOffsetAt` (the one conversion site the viewmodel really draws with) plus
`HandAssets.GRIP_STUDS` — not by reading `pos` out of the file.

| Hand | Bound it must satisfy, in all three states (hip, aimed, cycling) |
|---|---|
| RIGHT, on the stock's wrist | `offGripAxis(point) < gripRadius(ROW)` **and** `\|alongGripAxis(point)\| < gripHalfLength(ROW)` |
| LEFT, on the fore-end | `offForeAxis(point) < foreRadius(ROW)` **and** `\|alongForeAxis(point)\| < foreHalfLength(ROW)` — the same four names on the fore-end's measured band, published beside the wrist's because on THIS gun the left hand is the one that holds a moving-looking part and must be shown not to |
| Either | one grip only: the right hand's position at the hip equals its position aimed to 1e-6 (a gun re-gripped every time Karen aims) |

Every bound is `TestKit.note`d with the measured value beside it, so the number is in the harness
report and not only in a boolean.

### 15.5 Harness: input, screenshots, scopes

- **`BLAST_RADIUS`** gains `("src/shared/SemiAuto/", "gun")` — its numbers and its drawn geometry are
  a gun's, exactly as `src/shared/Lever/` is. `src/server/Weapon/` is already `weapon`,
  `src/client/Camera/Viewmodel.luau` and `src/shared/Viewmodel/` are already `viewmodel`,
  `src/client/Camera/` (which now includes `Mode.luau` and `init.luau`) is already `camera`,
  `src/shared/Shop/` is `shop`, `src/client/Hud/` is `hud`.
- **`SCOPE_SPECS`**: `semiauto.spec` into **`gun`** (its numbers), **`weapon`** (the reducer and the
  sequence runner), **`shop`** (the row and its grant) and **`camera`** (the pose share lives in
  `Camera.Mode`); `semiauto_client.spec` into **`weapon`**, **`viewmodel`** and **`camera`**.
  Standing rule G: a new spec in no scope turns CI red, and `tools/studio_mcp.py selftest` fails both
  ways — so the table edit and the spec files land in the same commit.
- **Input the harness cannot drive, said plainly (rule 6, TASKS 6–7).** The hotbar keys **cannot be
  replayed at all** — `VirtualInput` refuses them as *"permanently bound to a CoreGUI core action"*
  (measured in task 141) — and this gun is `OWNED_ONLY`, so in a spec world (`owned == nil`) the
  Tool is **never granted**. **There is therefore no input scenario for this weapon and none is
  added**; `tests/client/input_scenarios.txt` is unchanged. What the specs do instead is drive the
  path as functions: `Weapon.refreshArming(player, { "shotgun", "rifle", "lever", "semiauto" })`
  puts four Tools in the bag in order, `Hardware.equip` puts this one in the hand,
  `Weapon.heldFrom` is asserted over four replicas, and the drawn gun is reached through
  `Viewmodel.setSource`. "Press 4 and the semi-auto comes up" is **Karen's click or the
  Director's**, and the report must say so rather than imply a replay.
- **Screenshots (rule 5), inspected by the Builder, not counted:** (1) the gun in the hand at the
  carry; (2) aimed, with the **red dot on the glass** and both gloves in the view; (3) **three frames
  of one cycle** — rest, bolt fully back with the port open, home — which is the one thing the
  numbers cannot certify; (4) the reload, with the **tray at full rise in the port**; (5) a five-shot
  string's readout from `5/5` to `0/5`; (6) a kill at 90 m with the report row naming `AUTO`;
  (7) the shop page with its display model, price and blurb.
  `python tools/studio_mcp.py capture <name>`.
- **Gate:** the one-player `test` only. This weapon is in none of `TWO_PLAYER_PATHS` — not
  `src/server/Match/`, not `src/client/Match/`, not `src/shared/Drive/`, not their specs — so
  `test2` is **N/A with that reason** (Director decision 2026-10-03).
- **Content lane:** once the pose set exists, every number in `weapons.semiauto` is tuned live with
  `tools/pose.py set/show/compare`, Karen looks, `tools/pose.py save` commits with the one-player
  gate and no review round. `tools/pose.py clear` and `tools/flags.py clear` before any harness run —
  both `test` and `test2` refuse to start otherwise.

---

## 16. Explicitly out of scope (the BRIEF's item 11)

1. **A Robux product id** — every row's `robuxProductId` is nil in this build and `rowsOk`'s I12
   asserts it; task 222 needs Karen's Creator Dashboard.
2. **New audio uploads** — section 8 reuses measured library ids.
3. **A new hit card, decal, report path or hit-zone table** — the pellets and the slug are the same
   objects they already are (D-14).
4. **`Match.CONFIG.SAFETY_RANGE_STUDS`** — still 330, still 183a(a), still a `TWO_PLAYER_PATH`.
5. **The drawn gate / port feed** — 224a, with its four prerequisites (`loadingAt`'s two-chamber
   loop, `chamberOffset`'s hard-wired `Shotgun.CONFIG`, `Camera.breakFrom`'s two-chamber `loaded`,
   and `Geometry.portAt`, which this task MEASURES and records so 224a starts from a number).
6. **A separate hold for the RELOAD** (the gun lowered and turned for the port, rather than the one
   `poseShare`) — **225a**, named in 7.4, Karen's eye first.
7. **Gating the dot on the aim blend** — **225a**, one per-frame write at one owner, 7.3, Karen's.
8. **One gate click per shell on the LEVER** — it comes free with section 7.2's shared edge; if the
   Director refuses that, it stays 224a(e).
9. **Folding `cycleLength`/`cycleZ` into `Gun` and `Rifle.Geometry`** — still "before release"; this
   task adds the second pair (`liftLength`/`liftZ`) in the same shape rather than widening the old
   ones.
10. **Raising `Shop.CONFIG.MAX_ITEMS`** — not needed for this row (12 of 12) and needed for the next
    one (11.2).
11. **The lodge gun rack** — `ForestTestBoot`'s `WEAPON_OF` stays as it is.
12. **A bundle containing this gun** — blocked by `mergedGrants`' single-valued `weapon` field.

---

## 17. Open decisions

**None of these blocks building.** Each ships at the stated value and is one line to change.

**Karen (feel):**

- **K-1. The rate: 0.30 s cycle, 0.42 s between shots.** The gun's whole character. Hers.
- **K-2. The reload: 0.35 / 0.38 / 0.35 = 2.60 s**, and 1.46 s for two shells.
- **K-3. The recoil, as data (D-11).** Ships **below** the side-by-side's (`camPitchDeg` 1.5 against
  2.1, `gunBackStuds` 0.20 against 0.28, `gunPitchDeg` 5.5 against 8.0, the three maxima in the same
  ratio), with the shotgun's own per-load scales (`Slug` 1.45) unchanged. The direction is physics
  and the manufacturer's claim; **the magnitude is not measured anywhere** (13.6). Content lane.
- **K-4. Does the gun need to MOVE during the reload?** It ships at `poseShare = 0`, so it holds
  still through both sequences (7.4). One number, live, 0 to 1 — and a separate reload hold is 225a.
- **K-5. The dot, lit on the hip.** It ships always on, which is what a red dot is (7.3).
- **K-6. The three voices and their pitches** (section 8). Nobody here has heard them.
- **K-7. The Hud label: `"AUTO"` or `"SEMI"`.** Ships `"AUTO"`; both fit the 7-character ceiling.
- **K-8. The shop price: 500 / 8 hunts**, under the lever's 650 because it buys volume and not reach
  (11.1).

**Director (scope):**

- **D-a. The ammo-identity move into `Shotgun.CONFIG`** (9.2) versus a second literal in
  `SemiAuto.CONFIG`. Ships as the move; no value changes either way.
- **D-b. `X` on a full tube** (6.4): ships as the shipped machinery (0.70 s, nothing changes). The
  alternative is a refusal branch in `onActionRequest`, i.e. an edit to the owner of the action.
- **D-c. The `load` voice on `Camera.fedShell`** (7.2): ships shared, which closes 224a(e) and
  changes the LEVER's audible behaviour (five clicks where it makes one today). Refusing it leaves
  this gun showing five lifts and clicking once.
- **D-d. Who runs the six uploads** (section 18 step 3). Tasks 140's and 224's were the Director's.
- **D-e. `MAX_ITEMS`** after this row (11.2) — not this task's, and named so it is nobody's surprise.

---

## 18. Build order, with the stop points

1. **Research note** `docs/research/2026-10-20-semiauto-shotgun.md` + `INDEX.md` row (rule 1,
   sources 13.1–13.6, with the resolved URLs pasted). **No code before it.**
2. **Outside the repo:** FBX → glTF; `gltf_split probe`; **record every measurement in section
   10.2**; write `SEMIAUTO_PLAN`; `gltf_split split`; `asset_prep prep --preset gun` × 6. Report the
   triangle counts and the preview of each group, **having looked at it** (rule 5).
3. **STOP: `READY TO UPLOAD 225 <folder list>`.** Then `roblox_upload.py`, then the six `Assets.ROWS`
   rows and the `assets/uploads.json` rows with Karen's words verbatim. **The weapon row cannot land
   before this** (10.3, `assets_seam.spec`).
4. `src/shared/SemiAuto/` (config + geometry), `src/server/Weapon/ShapeSemiAuto.luau`, the three map
   entries (`Weapons.ROWS`/`ORDER`/`GEOMETRY`, `Shapes.BY_ID`), the ammo-identity move (9.2),
   `Viewmodel.validate`'s literal, `ViewmodelAssetsBoot`'s folder + preload + publish.
5. `Gun.Group`'s `"lift"`; `buildNewGun`'s second envelope and parent branch; `Viewmodel.hinge`'s
   `"straight"` branch; `setLift` / `liftProgress` / `lifterWeight` / `lift` + the `update` call +
   `clear()`; `Camera.fedShell`; `CameraBoot`'s remembered snapshot and edge;
   `Viewmodel.view`'s three new flat names; `Camera.Mode`'s two `CYCLE_POSE_SHARE` reads.
6. `weapons.semiauto` in `poses.json`, authored against the section-10.2 measurements.
7. The shop row (`ITEM`, `ROWS`, `ORDER`, `ALL_ORDER`, `BASE_AMMO`) **and** the `ShopDisplay` entry
   (11.3 — without it the harness goes red).
8. `tests/server/semiauto.spec.luau`, `tests/client/semiauto_client.spec.luau`, the `shop.spec` and
   `rifle.spec` edits, `BLAST_RADIUS` + `SCOPE_SPECS`.
9. `GAME_DESIGN.md`'s three owner rows; `CREDITS.md`'s attribution.
10. Lint, `rojo build`, `python tools/studio_mcp.py test`, the seven screenshots, then the request.
