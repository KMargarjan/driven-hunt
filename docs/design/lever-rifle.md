# The lever-action rifle (`lever`)

Architect design for **Task 224**, written to `reviews/task-224/BRIEF.md` (the Director's and Karen's
input, 2026-10-20 ~13:25). The BRIEF overrides anything older in `docs/`, `TASKS.md` and
`docs/design/rifle.md`; where this document departs from the BRIEF's literal wording it says so, in
the open, with the file and symbol that forced it (sections 7.1, 6.3).

Karen, verbatim: *"so you have things to do / deer / weapons / make it work like we have now"*, and
*"Upload, sell in shop (Recommended)"*. Her standing bar: shooting, weapon and reload **perfect**, a
separate-part model, every frame checked against the target.

The model is a Ruger-made Marlin 1895 SBL: **a third row in the weapon system, joined exactly as the
scoped rifle was** (D-1). No new system. `ServerScriptService.Weapon` stays the owner of the action
and `Weapons.ROWS` stays the one table of guns.

---

## 1. What it must do

1. Exist as one frozen row in `Weapons.ROWS` keyed `lever`, built from its own config module, with
   its own `Tool`, its own hotbar slot (3) and its own viewmodel drawn with the same gloves.
2. Fire one `.45-70` bullet per trigger pull, through the shipped flight: `Ballistics.shotFor` reads
   the four required numbers off the row and `Weapon.Flight` steps the projectile. Same hit zones,
   same damage table, same hit card, same drive report.
3. Work its **lever** after every shot (`AUTO_CYCLE`), drawn as one hinged group swinging down and
   forward, the right hand carried on the loop.
4. Top its tube up through the loading gate on `R`, one cartridge per `Load` step, leaving live
   rounds where they are (`CYCLE_EJECTS = "spent"`).
5. Aim down its **own iron sights** (`SIGHT = "bead"`, `scope = nil`): no scope overlay, no reticle,
   no eyepiece, no `Rifle.Scope` table, the gun and both hands in the view, FOV 50 — which is the
   shotgun's aim path, reached by carrying no `scope` block at all.
6. Be **bought in the shop**: one `Shop.ROWS` entry whose `grants.weapon` names this id, so
   `Shop.ownsWeapon` is what decides whether a hunter may carry it.
7. Be drawn from three uploaded MeshParts in Karen's account, with the measured fallback boxes until
   they land.

## 2. What it must not do

1. **Not become a second owner of anything.** It writes no state: `Weapon.StateMachine` is still the
   only producer of a `WeaponState`, `Weapon.Hardware` still the only writer of Tool Instances,
   `Camera.Viewmodel` still the only writer of the drawn gun, `tools/pose.py` still the only writer
   of the live pose override.
2. **Not read `Rifle.CONFIG`, and not add a row to it.** Confirmed against the BRIEF's item 2: the
   reason is written in `Rifle`'s own header (*"the file that holds [Karen's accepted numbers] must
   not become the file everybody edits"*). The two guns share **no number**. They share the
   machinery.
3. **Not carry a rule of the drive or of the protocol.** `Weapons`' header is the rule and
   `tests/server/rifle.spec.luau` ("carries NO rule that belongs to the drive or to the protocol")
   is the assertion: no `SAFETY_ARC_HALF_DEG`, no `AUTO_EQUIP`, no rate limit, no `FLIGHT_*`, no
   gravity constant.
4. **Not add a primitive to the reducer.** `Break` / `Load` / `Close` already are "throw the lever"
   and "push one through the gate" (D-6). No `Magazine` step: this gun has no box.
5. **Not add a feature flag.** See section 11.
6. **Not touch `Match.CONFIG.SAFETY_RANGE_STUDS`** (still 330, still queued as 183a(a), still a
   `TWO_PLAYER_PATH`), the semi-auto shotgun (task 225), a Robux product id, a new audio upload, a
   new hit card, or the lodge gun rack.
7. **Not draw a shotgun shell.** See section 7.3 — this is a shipped defect the lever would walk
   into, and closing it is part of this task.

---

## 3. Owners, and where each lives on disk

Every row is "exactly one writer, named" (CLAUDE.md rule 3). **New** files are marked *new*; the rest
are files this task edits, with the edit named.

| Thing | Owner (the one writer) | On disk |
|---|---|---|
| The lever's numbers (every ballistic, timing, layout, voice) | `ReplicatedStorage.Lever` → `Lever.CONFIG`, frozen by `Shotgun.deepFreeze`, no run-time writer | *new* `src/shared/Lever/init.luau` |
| The DRAWN lever (where every group, the pivot, the sights and the hand anchors are) | `ReplicatedStorage.Lever.Geometry`, pure data, the sibling of `Gun` and `Rifle.Geometry` with the same function set | *new* `src/shared/Lever/Geometry.luau` |
| The WORLD lever's fallback piece list | `ServerScriptService.Weapon.ShapeLever`, the sibling of `Weapon.ShapeRifle`, reading its boxes out of `Lever.Geometry` and re-typing none | *new* `src/server/Weapon/ShapeLever.luau` |
| Which weapons exist, and which a hunter carries | `Weapons.ROWS` / `ORDER` / `GEOMETRY` — **one new row, one new ORDER entry, one new geometry entry** | `src/shared/Weapons/init.luau` |
| weapon id → world shape | `Weapon.Shapes.BY_ID` — **one new entry** | `src/server/Weapon/Shapes.luau` |
| The action (every state transition, every sequence) | `ServerScriptService.Weapon` (`runCycle`, `onActionRequest`) and the pure `Weapon.StateMachine` — **one new pure function, `Weapon.cycleRefusal`, and one branch that calls it** (section 6.3) | `src/server/Weapon/init.luau` |
| The lever's pose set (carry, aim, cycle, fire, raise) | `src/shared/Viewmodel/poses.json`, `weapons.lever` — **content lane**, `tools/pose.py` the one live writer | `src/shared/Viewmodel/poses.json` |
| Which weapon ids must have a pose set | `Viewmodel.validate` — **one literal grows to `{ "shotgun", "rifle", "lever" }`** | `src/shared/Viewmodel/init.luau` |
| The drawn swing of a lever, and its SIGN | `Lever.Geometry.leverThrow` — **not** `Camera.Viewmodel`; the mirror of `Rifle.Geometry.boltLift`, which exists for exactly this reason (task 188: *"THE SIGN WAS WRONG AND NOTHING COULD SEE IT"*) | `src/shared/Lever/Geometry.luau` |
| The drawn gun on screen | `PlayerScripts.Camera.Viewmodel` — **one new `CYCLE_KIND` branch in `Viewmodel.hinge`, one new pure predicate `Viewmodel.handFeedsShells`, two call sites changed to read it, two tokens added to the moving group's envelope** (section 7) | `src/client/Camera/Viewmodel.luau` |
| This weapon's voices | `Lever.CONFIG.SOUND`, played by `Weapon.Sound` (client), triggered by `CameraBoot`'s action edges — **one new voice key `load`, one new `Sound.load`, one new edge** (section 8) | `src/shared/Lever/init.luau`, `src/client/Weapon/Sound.luau`, `src/client/CameraBoot.client.luau` |
| Published viewmodel meshes | `src/server/ViewmodelAssetsBoot.server.luau` — **one new folder, one preload, one publish loop** | same |
| Asset ids and every measured fact about an upload | `ServerStorage.Assets.ROWS` — **three new rows**, written by the Builder from what `tools/roblox_upload.py` printed into `assets/uploads.json` | `src/serverstorage/Assets/init.luau` |
| The split plan | `tools/gltf_split.py` `LEVER_PLAN` + `PLANS` — **one new named plan**, beside `MODEL_B_PLAN` and `RIGBY_PLAN`, because that file's docstring says why plans live there | `tools/gltf_split.py` |
| The shop catalogue | `ReplicatedStorage.Shop` — **one `ITEM`, one `ROWS` row, one `ORDER` entry, one `ALL_ORDER` entry, one `BASE_AMMO` entry** | `src/shared/Shop/init.luau` |
| Which scope a spec belongs to | `tools/studio_mcp.py` `BLAST_RADIUS` + `SCOPE_SPECS` — **one prefix, three tuple entries** | `tools/studio_mcp.py` |
| The owners table | `GAME_DESIGN.md` *System owners* — **two new rows**, mirroring section 3 of this file | `GAME_DESIGN.md` |

**Nothing else in `src/` is touched.** In particular `Weapon.Hardware`, `Weapon.Registry`,
`Weapon.Rules`, `Weapon.Validator`, `Weapon.Flight`, `Weapon.Cast`, `Weapon.Hits`, `Ballistics`,
`Boar.Wound`, `HitLog`, `Report`, `Hud`, `Economy`, `Shop`'s server door and `Match` are all
id-driven already and get the third weapon for free. Checked, not assumed:
`Hardware.addMesh` reads `row.ASSET_KEYS` / `MESH_NAMES`; `Hardware.build` reads `config.GRIP`,
`HANDLE_SIZE`, `HANDLE_COLOR` and writes `DrivenHunt.Weapon`; `Weapon.refreshArming` walks
`Weapons.loadout()` and `Weapon.equipDelayFor` already answers for `#wanted > 1`;
`Hud.readoutFor` / `Hud.ammoChipFor` branch on `row.READOUT` and `Hud.PIP_MAX` is 8;
`Weapon.heldFrom` already holds for three replicas (`tests/client/weapon_client.spec.luau`, the
case "answers with the gun whose newest snapshot claimed the hand", written for a fabricated third
id in task 143).

---

## 4. The module shape

**`src/shared/Lever/` with its own `Geometry` sibling — the rifle's shape, and for the rifle's
reason.** The BRIEF's item 2 asks for confirm-or-overrule: **confirmed, and the "reads nothing out of
`Rifle.CONFIG`" reading is right.**

- `Lever.CONFIG` is one frozen table of this gun's own numbers, deep-frozen at require time with
  `Shotgun.deepFreeze` (the only thing it takes from another gun's file, plus the `ActionKind` /
  `AmmoKind` type names — which is exactly what `Rifle` takes).
- `Lever.Geometry` is pure data with the **same function set** as `Gun` and `Rifle.Geometry`, because
  `Camera.Viewmodel.buildNewGun` draws whichever one `Weapons.geometry(id)` hands it and must not
  learn which gun it has.
- `Lever.Geometry` requires `Gun` for one constant (`MESH_ROTATION_DEG`, the same two turns the
  pipeline imposes on every group) and `script.Parent` for its own config default. It does **not**
  require `Rifle` or `Rifle.Geometry`.
- Require direction, so there is no cycle: `Weapons` → { `Shotgun`, `Rifle`, `Lever`, `Gun`,
  `Rifle.Geometry`, `Lever.Geometry`, `Shop` }; `Lever` → `Shotgun`; `Lever.Geometry` → { `Gun`,
  `Lever` }; `Shop` requires none of them (`Shop.rowsOk` takes the weapon table as a parameter
  precisely so).

Rejected alternatives, with the reason:

- *A second row inside `Rifle.CONFIG`.* Refused by `Rifle`'s own header. Two guns in one file is the
  file everybody edits.
- *A shared `BoltAction` base both rifles read.* It would make one number answer for two guns, which
  is the "two correct pieces of code disagreeing" failure `docs/PROJECT_CONTEXT.md` opens with. The
  guns share machinery (the reducer, the sequence runner, the geometry function set), and that is
  already the whole saving.

---

## 5. The public interface

### 5.1 `Lever.CONFIG` (`ReplicatedStorage.Lever`)

Types are the `Weapons.Row` type's; every field below is read by the row and by nothing else.

```luau
export type CycleStep = { kind: Shotgun.ActionKind, wait: number }

Lever.CONFIG = {
  -- ballistics (section 9)
  RANGE_STUDS         : { [string]: number } = { Slug = 600 },
  PELLETS             : { [string]: number } = { Slug = 1 },
  SPREAD_FULL_DEG     : { [string]: number } = { Slug = 0 },
  MUZZLE_STUDS_PER_S  : { [string]: number } = { Slug = 2232 },
  DRAG_PER_STUD       : { [string]: number } = { Slug = 5.21e-4 },
  ZERO_STUDS          : { [string]: number } = { Slug = 357 },
  GRAVITY_SCALE       : { [string]: number } = { Slug = 0.35 },   -- KAREN'S DIAL (17 K-1)
  AMMO_KINDS          : { string }           = { "Slug" },
  AMMO_LABEL          : { [string]: string }  = { Slug = ".45-70" },
  INITIAL_AMMO        : string               = "Slug",
  START_RESERVE       : { [string]: number } = { Slug = 10 },

  -- the action (section 6)
  BARRELS             : number  = 5,
  MAGAZINE            : number  = 5,
  BARREL_DELAY        : number  = 0.12,
  AUTO_CYCLE          : boolean = true,
  CYCLE               : { CycleStep },        -- Break 0.46, Close 0.64
  CYCLE_TOTAL         : number  = 1.10,
  CYCLE_EJECTS        : string  = "spent",
  RELOAD              : { CycleStep },        -- Break 0.40, Load 0.42 x 5, Close 0.40
  RELOAD_TOTAL        : number  = 2.90,
  AUTO_RELOAD_WHEN_EMPTY : boolean = true,
  READOUT             : string  = "magazine",

  -- the hardware (section 10)
  HANDLE_SIZE         : Vector3 = Vector3.new(0.4, 0.5, 4.0),
  HANDLE_TRANSPARENCY : number  = 1,
  GRIP                : CFrame  = CFrame.new(0, 0, 1.27),
  MUZZLE_OFFSET       : Vector3 = Vector3.new(0, 0, -2.0),
  LOOK                : { [string]: Color3 },  -- barrel, action, wood, lever
  SOUND               : { [string]: any },     -- shot, bolt, load (section 8)
}
```

`AMMO_GLYPH` is **absent**, like the rifle's: `Hud.ammoChipFor` draws no shell rather than a wrong
one, and the wire word is `Slug` for all three guns because `Boar.Wound.damageFor` branches on that
string. `scope` is **absent**. `SIGHT = "bead"` lives on the row (section 5.3).

### 5.2 The row (`Weapons.ROWS.lever`)

Built field by field from `Lever.CONFIG`, never copied out of it — the rule `Weapons`' header sets
for the shotgun and `tests/server/rifle.spec.luau` asserts.

```
id = "lever", label = "LEVER", toolName = "Lever", slot = 3,
<every CONFIG field above>, HANDLE_COLOR = Lever.CONFIG.LOOK.wood,
ASSET_KEYS = { "lever.action", "lever.stock", "lever.lever" },
MESH_NAMES = { "Model", "Stock", "Lever" },
SIGHT = "bead", scope = nil,
```

`label` is **five characters and must stay at seven or fewer**: `ReportPanel.DETAIL_COLUMNS`' `gun`
cell is 88 px and task 219 measured `SHOTGUN` at 46 px in that cell's own face. `Model` must be the
first `MESH_NAMES` entry — `Hardware.wearsMesh` and the upgrade sweep read "does this Handle have a
`Model` child" — and the first `ASSET_KEYS` entry is therefore the **action**, the piece that must be
there for the gun to count as dressed (D-14).

No new field on the `Weapons.Row` type. `SOUND` is already `{ [string]: any }?`, so the new `load`
voice needs no type change.

### 5.3 `Lever.Geometry` (`ReplicatedStorage.Lever.Geometry`)

The function set is `Rifle.Geometry`'s, so a generic caller cannot tell the guns apart. **Every box
and every point below is a MEASUREMENT the Builder takes with `tools/gltf_split.py probe` on the
converted glTF before this file is written** (section 10.2); this design names what must be measured
and what reads it, and invents no number.

```luau
Geometry.MESH_SIZE_STUDS      : Vector3   -- the split report's `wholeBoxFileAxes.size`, at 4.0
Geometry.MESH_ROTATION_DEG              = Gun.MESH_ROTATION_DEG
Geometry.FOLDER_NAME                    = "ViewmodelLever"
Geometry.BODY_NAME                      = "LeverBody"
Geometry.CYCLE_GROUP_NAME               = "Lever"
Geometry.CYCLE_KIND                     = "lever"        -- the third value (7.1)
Geometry.HAND_FED_SHELLS                = false          -- (7.3)
Geometry.ASSET_KEYS           : { string }                -- action, stock, lever
Geometry.MESH_KEYS            : { [string]: string }      -- Action / Stock / Lever -> keys

Geometry.layout(config)       -- every measurement, scaled by HANDLE_SIZE.Z / 4.0, frozen.
                              -- Publishes: total, half, muzzleZ, meshCentreY, action, stock,
                              -- lever { size, at }, pivot, sightFrontY, sightRearZ, gateAt,
                              -- AND the generic pair `cycleLength` / `cycleZ` (7.2).
Geometry.sightKind(config)    -- `config.SIGHT or "bead"`: one sight configuration, kept for the
                              -- function set, no piece filtered on it.
Geometry.sight(config)        -- the FRONT SIGHT, on the gun's centre line (x = 0, because the
                              -- bullet leaves at x = 0 and a sight that disagrees with the bore
                              -- lies -- `Rifle.Geometry.beadOffset`'s own rule).
Geometry.muzzle(config)       -- the bore line at the muzzle face.
Geometry.hinge(config)        -- the LEVER'S PIVOT. Read by `Viewmodel.hinge` before it branches.
Geometry.leverThrow(config, throwDeg, progress) : CFrame
                              -- the swing, in the gun's frame, with the SIGN here (7.1).
Geometry.leverGripOffset(config) / leverGripRadius(config)
                              -- where the right hand holds the loop, and how big that bar is.
Geometry.gripOffset / gripAxis / gripRadius / gripHalfLength
Geometry.alongGripAxis(config, point) / offGripAxis(config, point)
                              -- the stock's wrist, SAME NAMES as the rifle's so one spec helper
                              -- checks both guns' hip holds (task 188's tolerances).
Geometry.pieces(config)       -- { Piece }, in build order: Stock (body), Action (body),
                              -- Lever (the `barrels` group -- `Gun.Group`'s second value).
Geometry.partCount(config)
```

Three pieces and no drawn bead: **this model carries its own iron sights**, on the rail, inside the
`action` upload (D-3's measurement: `Sights` sits at z +0.447..+0.496, on the rail's top face). That
is the whole difference from the Rigby, whose twelve nodes carry no sight node and whose bead is
therefore drawn (`Rifle.Geometry`'s `BEAD_DIAMETER` block).

### 5.4 `Weapon.ShapeLever` (server)

`pieces(row)`, `sight(row)`, `muzzleZ(row)` — the `Weapon.ShapeRifle` contract, read forwards by
`Hardware.addParts` and backwards by `Hardware.removeParts`. Four boxes, read out of
`Lever.Geometry.layout` and re-typing nothing: `LeverStock` (wood block), `LeverBarrel` (a cylinder
at the bore line — at thirty studs the thing that says "rifle" is a long thin pipe), `LeverAction`
(the receiver), `LeverLoop` (a short block under the wrist, which is the one silhouette cue that says
*lever* and not *bolt*). No scope tube.

### 5.5 Remotes, events, flags

**None are added.** `Shotgun.remotes()`' six RemoteEvents carry this gun exactly as they carry the
other two (`FireRequest`, `ActionRequest`, `ShotFired`, `ShotLanded`, `HitMarker`, state). The wire
payloads are unchanged: `weapon = "lever"` is a string in fields that already carry one.

---

## 6. The cycle, the reload, and the one refusal rule

### 6.1 The cycle — a lever throw

```
CYCLE = { { kind = "Break", wait = 0.46 }, { kind = "Close", wait = 0.64 } }
CYCLE_TOTAL = 1.10
```

Two steps because the throw is one motion out and one back: `Break` ejects the fired case
(`CYCLE_EJECTS = "spent"` — the shotgun's `"all"` would dump four live rounds down the hill every
shot) and `Close` chambers the next from the tube. No `Load`: nothing is fed by hand during a cycle,
which is the same reason the rifle's `CYCLE` has none.

**1.10 s, between the two numbers this repo has measured on screen.** Faster than the bolt's 1.62 —
Karen's own number from task 184, *"I think it reloads to fast has to be 1 s slower"* / *"Bolt after
each shot"* — because a lever throw is one continuous motion of the hand that is already on the grip
(sources 13.2, 13.3). Slower than the 0.62 the bolt first shipped at, which read as too fast on
screen. **It is a dial** and it is Karen's.

`AUTO_CYCLE = true`: the gun works itself after the trigger's own `BARREL_DELAY`, through the same
`runCycle` the rifle uses. A lever gun that needed `R` after every shot would not be a lever gun.

### 6.2 The reload — cartridges through the gate

```
RELOAD = { Break 0.40, Load 0.42, Load 0.42, Load 0.42, Load 0.42, Load 0.42, Close 0.40 }
RELOAD_TOTAL = 2.90
```

Five `Load`s because the tube holds five (D-9: the tube spans 1.147 of the gun's 4.905 units = 9.5 in
of a 40.5-in rifle = 3.7 cartridges of 2.55 in, so four in the tube and one in the chamber).
`StateMachine.apply`'s `Load` fills **one** empty chamber from the pocket per step, which is exactly
one cartridge through one gate — the shape the shotgun's reload already has, with the tube's count
instead of two barrels. 2.90 s is slower than the rifle's 1.97 s magazine change, and that **is** the
trade a tube magazine makes. Also a dial.

### 6.3 `barrel-full` on a `Load`, and the one changed line

**The BRIEF's D-7 is right about the substance and I am sharpening it, with a measurement.**

Today `runCycle` (`src/server/Weapon/init.luau`) walks past exactly one refusal:

```luau
if reason and not (step.kind == "Load" and reason == "no-reserve") then  -- abort + recover
```

A partial top-up — three in the tube of five, press `R` — makes the fourth `Load` return
`"barrel-full"`. D-7 proposes adding `barrel-full` to that walk-past set. Traced against the shipped
code, that gives a **fixed-length reload**: the fourth and fifth `Load` steps still burn 0.42 s each
with nothing going in, so putting two rounds in a tube takes the same 2.90 s as putting in five.

The current behaviour is not a crash either: the refusal falls into the recovery branch, which waits
out the busy window, applies `Close`, breaks, and republishes — so the gun does end up shut. What is
wrong with it is that a **correct** event is routed down a path whose own comment says *"the world
moved under it"*, and the `Close` it runs is not published as a step (`publish(..., step.kind)` is
skipped), so `snapshot.action` never says `Close` for it.

**The design's rule — one pure function, three answers:**

```luau
-- PURE and exported, so the three cases are driven with no session.
-- "walk"   : keep going (an empty pocket: closing a gun with fewer rounds is correct)
-- "finish" : the tube is FULL -- skip every remaining `Load` and run the sequence's last step
-- "abort"  : anything else: the world moved under it. Today's recovery, unchanged.
function Weapon.cycleRefusal(kind: string, reason: string): string
```

`Load` + `no-reserve` → `"walk"` (bit-for-bit today's behaviour). `Load` + `barrel-full` →
`"finish"`. Everything else → `"abort"`. `runCycle` reads it and, on `"finish"`, continues the loop
while skipping steps of kind `Load`.

- **It changes no shipped behaviour, provably.** The shotgun's `Break` ejects `"all"`, so both its
  chambers are always `Empty` when its two `Load`s run; the rifle's reload uses `Magazine`, which
  fills every chamber at once and whose own `barrel-full` is a `Magazine` refusal, not a `Load` one.
  Neither gun can reach the new branch, and a spec case asserts that (section 15.1 case 9).
- **It gets the length right**: a two-round top-up is 0.40 + 2 × 0.42 + 0.40 = **1.64 s**, and the
  `Close` is a real published, timed, voiced step.
- If the Director prefers the BRIEF's literal boolean, it is one line in `cycleRefusal`
  (`"finish"` → `"walk"`) and the reload is always 2.90 s. Stated so the choice is visible.

---

## 7. What the drawn gun does, and the three forced changes to shipped code

The BRIEF's D-5 says the lever is the one moving group, hinged — **right** — and names
`CYCLE_KIND = "hinge"`. That string is wrong, and two named symbols say so.

### 7.1 `CYCLE_KIND = "lever"`, a third value

1. **`Camera.Viewmodel.poseHands`** decides where the LEFT hand is placed with
   `local follows = (Viewmodel.geometryNow().CYCLE_KIND or "hinge") == "hinge"`. On a break action
   the left hand holds the barrels and swings with them; on this gun it holds the **fore-end**, which
   is bolted to the barrel and does not move. With `"hinge"` the fore-end glove would ride the loop
   through its whole arc — a hand sliding off the gun once per shot.
2. **The sign of the throw.** `Viewmodel.hinge`'s break branch is
   `hinge * CFrame.Angles(-math.rad(angle), 0, 0) * hinge:Inverse()`. For a loop hanging below and
   behind its pin, that rotation carries the loop's end **up and toward the butt** for a positive
   angle; a lever opens **down and forward**. Expressing it with a negative `openDeg` in `poses.json`
   would put a sign in the content lane and the arithmetic in the viewmodel — which is precisely the
   defect `Rifle.Geometry.boltLift` was created to fix in task 188 (*"the handle simply disappears
   into the gun for the whole cycle"*).

So: `Geometry.CYCLE_KIND = "lever"`, `Geometry.CYCLE_GROUP_NAME = "Lever"`, and
`Lever.Geometry.leverThrow(config, throwDeg, progress)` owns the axis, the pivot and the direction,
beside the pivot it turns about. `Viewmodel.hinge` gains **one branch**:

```luau
if geometry.CYCLE_KIND == "slide" then        -- the bolt, unchanged
elseif geometry.CYCLE_KIND == "lever" then
  swing = geometry.leverThrow(row or Shotgun.CONFIG, config.BREAK_OPEN_DEG or 0, progress)
else                                          -- the break action, unchanged
```

`poseHands` is **not edited**: its existing expression answers `false` for `"lever"`, which is the
right answer. `BREAK_OPEN_DEG` stays the throw's magnitude in degrees, positive, in the pose data
where the Director can tune it live.

### 7.2 The moving group's envelope

`buildNewGun` sizes the moving group from `at.barrelLength or (at.bolt and at.bolt.size.Z) or 0.6`
and places it from `at.barrelZ or (at.bolt and at.bolt.at.Z) or 0`. Both names are a specific gun's.
`Lever.Geometry.layout` publishes the generic pair `cycleLength` / `cycleZ` (derived from its own
`lever` box, so there is one measurement and not two), and the two expressions gain `at.cycleLength or`
and `at.cycleZ or` at the **front**. Nothing moves for the two shipped guns. *Queued, not done here:*
publishing the same two names from `Gun` and `Rifle.Geometry` and dropping the gun-specific
alternatives (TASKS.md, "before release").

### 7.3 Loose shells: the drawn feed must become a fact about the gun

This is the hole the lever walks into, and it is in shipped code:

- `Camera.Viewmodel.shells` draws a spent hull per fired chamber at `chamberOffset(barrel, config)`,
  which is `Gun.chamber(barrel, Shotgun.CONFIG)` — **the SHOTGUN's chamber mouths, at the shotgun's
  4.4-stud layout, with the shotgun's two-barrel x offsets**, and the drawn shell is the shotgun's
  red-hulled model.
- `Camera.Viewmodel.loadingAt` runs the left hand's four-moment breech feed over `for barrel = 1, 2`
  — two of five chambers — against those same shotgun coordinates.
- `Camera.breakFrom` (`src/client/Camera/init.luau`) reports `loaded = { false, false }` and ignores
  any chamber past the second.
- Both drawn paths are suppressed today by `config.MAGAZINE_SWAP ~= nil`. **The lever has no
  magazine**, so that predicate answers "yes, draw it" — and after every shot a red 12-gauge hull
  would flip out of a .45-70 at a 4.4-stud gun's breech. That is the knife-held-backwards class of
  defect `docs/PROJECT_CONTEXT.md` opens with.

**The fix is a declared fact about the gun, not a borrowed predicate.** `MAGAZINE_SWAP` answers
"does this gun swap a box"; it must not also answer "does this gun put loose rounds in the player's
hands". So:

- each geometry module declares `HAND_FED_SHELLS`: `Gun` → `true`, `Rifle.Geometry` → `false`,
  `Lever.Geometry` → `false`;
- `Viewmodel.handFeedsShells(geometry): boolean` is one pure exported expression
  (`geometry ~= nil and geometry.HAND_FED_SHELLS ~= false`), so a client spec drives it without a
  Tool in a hand;
- `Viewmodel.loadingAt` and `Viewmodel.shells` **replace** their `MAGAZINE_SWAP` test with
  `not Viewmodel.handFeedsShells(geometryNow())`. The rifle's `MAGAZINE_SWAP` keeps its other two
  readers (`poseHands`' left-hand swap, `magazineAtProgress`) untouched.

It is **one** question and not two on purpose: `loadingAt` returns the carried shell's own frame
(`freshShellAt`), so the hand and the round it is holding are one mechanism with two halves, and
splitting it would be two answers to "is this gun hand-fed".

### 7.4 What the pose set carries, and what moves (the BRIEF's item 4)

`poses.json` → `weapons.lever`, version 4, with **`cycle`** as the action block (a weapon carrying
both `reload` and `cycle`, or neither, fails `Viewmodel.validate` and therefore the harness).

| Block | Present | What it draws on this gun |
|---|---|---|
| `carry`, `aim`, `raise`, `fire` | yes | as both other guns. `aim` is `eyeReliefStuds` + `cheekDeg` solved from `Geometry.sight` — the front sight — which is Karen's *"aiming true nozzle"* and is bit-for-bit how the shotgun's bead works. |
| `cycle.gun`, `cycle.left`, `cycle.right`, `cycle.openDeg`, `cycle.openSeconds`, `cycle.closeSeconds`, `cycle.hingeStuds` | yes | the gun's pose while the action is worked, the throw angle, and the two drawn windows. `hingeStuds` is read by nothing on this gun (the pivot is the geometry's) and ships for the reason the rifle's does — it is a tunable number and removing one is the Director's call, not this task's. |
| `cycle.hand` (`grip`, `reachShare`) | **yes** | **the RIGHT hand on the loop.** `Viewmodel.poseHands` lerps the right hand to `barrelsCFrame * grip` by `Viewmodel.boltHandWeight(cycleProgress)`, and `barrelsCFrame` is the swung cycle group — so the hand is carried by the lever's own arc and "the lever moves with the hand" is true by construction. `grip` is measured on the loop's grip bar (`Geometry.leverGripOffset`); `reachShare` is small, because the hand never leaves the gun. |
| `cycle.load` (fetch / above / seat / shellInHand + four durations) | **yes, and nothing draws from it** | It is there so the flat-name set is complete: `Viewmodel.view` publishes `SHELL_LOAD = action.load`, and `tests/server/rifle.spec.luau`'s *"publishes the same flat names for both weapons, so no reader can get a nil"* becomes a three-weapon case. The rifle carries an inert `cycle.load` for exactly this reason. The DRAWN feed is off (7.3). |
| `cycle.shells` (four numbers) | yes, inert | same reason; `Viewmodel.view` publishes `SHELL_*` off it. Already queued as 140a/142a for the rifle. |
| `cycle.magazine` | **no** | this gun has no box. Its absence is what keeps `poseHands`' magazine branch and `Viewmodel.magazineAtProgress` off. |
| `cycle.liftDeg`, `cycle.drawStuds`, `cycle.liftFraction` | **no** | read only on the `"slide"` path. |

**So what actually moves during the gate top-up:** the gun sits in `cycle.gun` with the loop thrown,
the right hand on the loop, the left on the fore-end, one voice per cartridge (section 8), and the
loop comes home on `Close`. **Nothing is hand-fed on screen.** Said plainly because it is the one
part of the reload that is a still picture, and because the honest alternative is a task of its own:
a drawn gate feed needs the gate measured on the model (`Geometry.gateAt`), `loadingAt`'s `1, 2`
loop generalised to `#state.barrels`, `chamberOffset`'s hard-wired `Shotgun.CONFIG` replaced by the
gun's own geometry, and `Camera.breakFrom`'s two-chamber `loaded` widened. That is four changes to
shipped drawing code in three owners — **queued as 224a**, named here so the Builder does not drift
into it and so the Director can price it after Karen has looked.

**A measured consequence to state once:** `openTilt` is driven from `snapshot.open`, so the lever is
drawn **thrown open for the whole top-up** (0.40 + 5 × 0.42 + 0.40). A real Marlin is topped up with
the action closed. There is one `openTilt` and one `BREAK_OPEN_DEG` per weapon, so distinguishing
"cycling" from "feeding" is a second drawn state and not a number — the same 224a. Karen's call
whether that reads wrong enough to pay for (section 17 K-4).

---

## 8. The voice

No audio is uploaded (the dispatch's rule, and D-10). Every id below is Roblox-provided licensed
library audio already measured to load in this repo (`Rifle.CONFIG.SOUND`, and
`docs/research/2026-10-10-rifle-bolt-magazine-sound.md` section 4). **Nobody here has heard any of
them: KAREN'S EARS DECIDE, and every one is one line.**

```
shot = { id = "rbxassetid://9114725315", cut = 2.0, fade = 0.8, pitch = 0.80 }
  -- "Gun Retort 1 (SFX)", ProSoundEffects, the rifle's own sample, LOWER than the .416's 0.88: a
  -- .45-70 is a bigger, slower, lower-pressure bore -- a boom where the Rigby is a crack.
bolt = { id = "rbxassetid://9117889191", cut = 0.40, fade = 0.10, pitch = 0.95 }
  -- the rifle's clack, BELOW its own 1.15 and a hair longer: a lever throw is heavier and duller
  -- than a bolt. Played on BOTH edges by `CameraBoot` (`Camera.breakSound` -> open / close), which
  -- is already how a weapon with a `bolt` voice is handled.
load = { id = "rbxassetid://9119115171", cut = 0.30, fade = 0.08, pitch = 0.85 }
  -- "Shotgun Handle 1 (SFX)", ProSoundEffects, "Grab, Handle": a short handling click, which is
  -- what pushing a cartridge through a gate is. No `magazine` voice: this gun has no magazine.
```

**The BRIEF's open key, settled: a `Load` plays a `load` voice, and the key is new.** D-10 asks which
*existing* voice a `Load` plays "if any". The honest answer is that none of the three existing keys
fits: `Camera.breakSound` only has the open/close edges, and `CameraBoot`'s only per-step hook is the
rising edge of `action == "Magazine"`. Reusing the `magazine` key would put the word *magazine* on a
gun that has none — the naming drift this repo keeps paying for. So:

- `Weapon.Sound.load(config, row)` beside `Sound.bolt` and `Sound.magazine`, three lines, reading
  `Sound.voiceFor(row, "load")` and `fire.volume.open`; `played.load` in `resetStats` (the counter
  itself is already nil-safe: `played[kind] = (played[kind] or 0) + 1`).
- `CameraBoot`'s break-source closure already latches `wasAction`; it gains one edge beside the
  `Magazine` one: rising `action == "Load"` and `Sound.voiceFor(row, "load") ~= nil` → play it.
- **Both shipped guns are untouched**: the shotgun's row has no `SOUND` block at all, and the rifle's
  has no `load` key, so `voiceFor` answers nil and nothing plays — which is exactly today.

Fallback if the Director wants nothing new in the sound path: drop the key and the gate is silent.
One line, and it is stated so the choice is visible.

---

## 9. Ballistics (D-8), checked

`Ballistics.CONFIG.GRAVITY_STUDS_PER_S2` is `9.81 / 0.28` = 35.0357 studs/s², **real gravity in this
game's units** (derived from `Report.CONFIG.METRES_PER_STUD`, not from `Workspace.Gravity`). So
`GRAVITY_SCALE = 1.0` is the real world, and every figure below is recomputed from the shipped
closed forms (`timeToRange`, `dropAt`, `sightOffsetAt`), not taken on trust.

Hornady LEVERevolution .45-70 325 gr FTX, the load a Marlin 1895 is sold for: **2050 / 1729 / 1450 /
1225 fps** at 0 / 100 / 200 / 300 yd, 24-in barrel (source 13.1).

| Row field | Value | Where it comes from |
|---|---|---|
| `MUZZLE_STUDS_PER_S` | `{ Slug = 2232 }` | 2050 fps = 624.8 m/s at 0.28 m/stud = 2231.6 |
| `DRAG_PER_STUD` | `{ Slug = 5.21e-4 }` | `v(s) = v0·exp(-k·s)` **fitted to the 100 yd point only** (326.6 studs): `ln(1729/2050)/326.6` = 5.214e-4 |
| — prediction, nothing fitted to it | 200 yd: **1459** vs 1450 (**+0.6 %**); 300 yd: **1231** vs 1225 (**+0.5 %**) | the same one-coefficient justification `Rifle.CONFIG.DRAG_PER_STUD` carries, and it fits this cartridge better than it fits the .416 |
| `RANGE_STUDS` | `{ Slug = 600 }` | 168 m, against the scoped rifle's 800 (224 m) and the slug's 330 (92 m). The dispatch's "~150 m practical" plus the margin an uphill shot needs |
| `ZERO_STUDS` | `{ Slug = 357 }` | 100 m, where an iron-sighted .45-70 is zeroed |
| `SPREAD_FULL_DEG` | `{ Slug = 0 }` | the scoped rifle's reason, in that file: *"a number nobody can predict is the wrong place to put character"*. This gun's character is its reach, its drop and its cycle |
| `GRAVITY_SCALE` | **`{ Slug = 0.35 }`** — Karen's | see below |
| `AMMO_KINDS` / `AMMO_LABEL` | `{ "Slug" }` / `{ Slug = ".45-70" }` | the wire word stays `Slug` (`Boar.Wound.damageFor` branches on it); the screen word is the Hud's alone (`Hud.readoutFor`) |

**`GRAVITY_SCALE`, the one number the design must argue.** At 1.0 (real) the trajectory off a 100 m
zero is **+4.14 cm at 50 m, 0 at 100 m, −14.84 cm at 150 m** — real, and exactly the complaint task
189 was raised for (Karen, 2026-10-15: *"it has to be acurat 100% 100m 150m"*). Both terms of
`sightOffsetAt` are exactly proportional to g (`dropAt` multiplies by it and nothing else does), so
the scale moves the whole band and nothing else — `timeToRange` never reads gravity, so **every stud
of lead is untouched**. At **0.35**:

| distance | 50 m | 100 m | 150 m | 168 m (`RANGE_STUDS`) |
|---|---|---|---|---|
| off the sight line | **+1.45 cm** | 0.00 | **−5.19 cm** | **−8.2 cm** |
| flight time | 0.084 s | 0.176 s | 0.277 s | 0.316 s |
| lead on a 38 studs/s boar | 3.2 studs | 6.7 studs | 10.5 studs | 12.0 studs |

The whole band from 0 to 150 m is inside ±1.5 / −5.2 cm — inside any zone on a boar — while the
bullet still **visibly falls** past 150 m, where the scoped rifle's 0.12 does not. It is one line and
it is hers (the same call as 185a(h) and 189). 1.0 is the real world back.

---

## 10. The hardware

### 10.1 Scale: 4.0 studs (D-15), and it is a fact about the guns

Both shipped guns are 4.4 because a Rigby stalking rifle and a Beretta 486 are both about 45 inches.
A Marlin 1895 is about 40.5: 40.5 / 45 × 4.4 = 3.96. A lever carbine is **visibly shorter**, and that
is half of what it looks like. Everything downstream is per-row data — `HANDLE_SIZE.Z = 4.0`,
`MUZZLE_OFFSET.Z = -2.0`, `GRIP.Z = 1.27` (the rifle's 1.4 × 4.0/4.4), `MESH_SIZE_STUDS` scaled by
4.0 / 4.905 — and the poses are authored fresh for this gun either way, so the shorter gun costs
nothing and buys its silhouette. The Handle stays the envelope (`HANDLE_TRANSPARENCY = 1`) and is the
only part of the gun a ray can hit.

### 10.2 The three groups, and the measurements that must be taken first

The pipeline is the Rigby's, step for step (rule 2), and it runs **outside the repo**; the bought FBX
is never committed and never redistributed.

```
FBX --(headless Blender, a one-off script in the runs directory)--> glTF
    --> tools/gltf_split.py probe      (THE MEASUREMENTS)
    --> tools/gltf_split.py split  LEVER_PLAN
    --> tools/asset_prep.py prep   per group
    --> tools/roblox_upload.py     (STOP POINT: "READY TO UPLOAD 224 <folders>")
```

`gltf_split` stays **stdlib-only and Blender-free**, which its docstring states as a design property,
so the FBX→glTF conversion is a script in the runs directory and never an import of `bpy` into that
tool.

| Group | Contents (D-14, by role; exact node names from `probe`) | Worn as |
|---|---|---|
| `action` | receiver, barrel, Picatinny rail, **both sights**, magazine tube, tube cap/plug, fore-end, both swivels, trigger, hammer, breech bolt, loading gate | `Model` |
| `stock` | stock, butt plate, rear swivel | `Stock` |
| `lever` | the finger lever (`Trigger frame`) | `Lever` |

Settled by geometry and not by the names (D-4, the lesson `RIGBY_PLAN`'s comment writes down):
`Trigger frame` **is the finger lever** (z −0.270..+0.231, a 0.81-long loop a quarter of the gun's
depth below the receiver — on a Marlin the finger lever *is* the trigger guard, and there is no
separate guard object in the file); `Bolt action` is the **breech bolt**, inside the receiver at
barrel height; `slide` is the **loading gate**, the only object entirely on one side of the centre
line; `Magazine` is the **tube** and `Magazine release` its front cap — a Marlin has no magazine
release, and neither object moves.

**The rail stays**, and that is a measurement rather than a taste (D-3): the rear sight's base is at
+0.447 and the receiver's top at +0.429, so dropping the rail leaves the rear sight floating 0.018 of
the gun's length above a bare slot. Task 147 hit this exact trap on the Rigby and the Director
cancelled it. This gun is sold with a rail and ghost-ring irons **on** it: the rail is the sight base,
and the gun aims down its own irons.

**`LEVER_PLAN`** in `tools/gltf_split.py`, beside the other two:
`lengthStuds = 4.0`; `boreUpStuds` = **measured** (the barrel's own axis height in the Handle's
frame); `axisFromNode` = the barrel node (its principal axis *is* the bore line); `upTowardNode` =
the rail (certainly above the bore); `backTowardNode` = the stock (certainly behind the muzzle);
`anchorSize = 1.0e-4`. Every group carries the **whole gun's bounding box** through the anchor
triangles, so all three import at one size and one origin and assemble at ONE CFrame with no measured
per-piece offset (task 96's trick, which both other guns use). The frame is already axis-aligned
(forward +X, up +Z), so there is no Sketchfab tilt to measure out. **One material** (`Marlin` on all
18 objects), so `group_mesh`'s one-material refusal cannot arise and there is nothing to drop — no
`dropNodes`, and refusal 4 guarantees a node in no group stops the split rather than vanishing.

**What `probe` must produce before `Lever.Geometry` is written** — this is the task's measurement
list, and not one of these numbers is invented in this document:

1. each group's box in the Handle's frame (the three fallback boxes);
2. the bore line's height (`boreUpStuds`, and `Geometry.muzzle`);
3. the **front sight's** tip, and the rear sight's notch (`Geometry.sight`, `sightFrontY`,
   `sightRearZ`);
4. the **lever's pivot** (`Geometry.hinge`) and the throw angle at which the loop clears the wrist
   (the seed for `cycle.openDeg`);
5. the **loop's grip bar** centre and radius (`leverGripOffset` / `leverGripRadius`), against
   `HandAssets.GRIP_STUDS` — the rifle's knob and the glove's own gap match to half a millimetre, and
   this must be checked the same way;
6. the **stock's wrist**: the narrowest cross-section between the receiver's rear and the comb, its
   principal axis, its half-width and its holdable half-length (`gripOffset` / `gripAxis` /
   `gripRadius` / `gripHalfLength` — task 188's four tolerances, which exist because a pose 0.158
   along the axis put the hand on the comb and the spec passed);
7. the **gate**'s centre on the right flank (`gateAt`) — recorded now, read by 224a.

### 10.3 Textures, triangles, manifest

4K maps down to **1024** (`Marlin_Base_color`, `_Normal`, `_Roughness`, `_Metallic`), the packed ORM
split into the two single-channel maps Roblox reads — `asset_prep` already does both. Metalness 0.10
/ roughness 0.50 on the metal, which are the shotgun's own measured anti-sky-mirror numbers; **no
base colour is recoloured**. **17,485 triangles over three meshes** as bought, against the Rigby's
four at 18,672 prepped. Prep near-native, and **decimate only a group that exceeds 8,258** — the
Rigby's own worst, which is the number this repo has already shipped and looked at. Roblox's ceiling
is 20,000 per mesh.

Three new `Assets.ROWS` rows, appended and versioned, never edited in place: `lever.action`,
`lever.stock`, `lever.lever`, each `kind = "meshpart"`, `source = "creator-store"`, Karen's creator
id, **no `scope`** (they are `runtime` keys, because the WORLD Tool wears the same meshes the
viewmodel clones), `sizeStuds = LeverGeometry.MESH_SIZE_STUDS`, `offsetStuds = Vector3.zero`,
`rotationDeg = Vector3.new(0, LeverGeometry.MESH_ROTATION_DEG, 0)`, `texturePx = 1024`,
`trisDeclared` **measured** by `asset_prep`, and a `licence` block quoting the package's own terms
with the attribution `CREDITS.md` carries. `assets/uploads.json` gets one row per upload with Karen's
words verbatim (*"Upload, sell in shop (Recommended)"*).

**This is an ordering constraint, not a nicety.** `tests/server/assets_seam.spec.luau` asserts that
`Assets.keysFor("runtime")` is **exactly** the union of every weapon row's `ASSET_KEYS` plus the
horn's, each key present exactly once. So the row cannot land before the three manifest rows with
real ids. The uploads are a **stop point in the build order** (section 18), exactly as task 140's
were.

If moderation rejects a group, `Assets.byKey` answers nil, `ViewmodelAssetsBoot` publishes the folder
without it, and the gun is drawn from `Geometry.pieces`' measured box for that group — a plain dark
lever gun, playable, and honest. Say so in the report rather than shipping a hole.

---

## 11. The hotbar, the loadout, and no new flag

```
Weapons.ORDER   = { "shotgun", "rifle", "lever" }
Weapons.PRIMARY = "shotgun"     -- unchanged
Weapons.FLAG    = "RIFLE"       -- unchanged
```

`Weapons.ORDER` **is** the hotbar: the engine's Backpack GUI numbers a slot the first time it sees a
Tool, so `Weapon.refreshArming` granting in this order is the whole mechanism, and
`Weapon.equipDelayFor` already defers the primary's equip when more than one Tool is handed over.
Slot 3 is the lever. Slot 3 was the open-sighted rifle until task 148 and the ordering was measured
then (`1 Shotgun, 2 Rifle, 3 RifleOpen`), so this is a rung being re-occupied, not a new mechanism.

**A flag-off spawn stays bit-for-bit what it is:** `Weapons.loadoutFor(false, …)` returns
`{ PRIMARY }` and nothing in this task touches that branch.

**No new feature flag. The BRIEF's item 6 reading is confirmed.** The gun is gated by **ownership**
(`Shop.ownsWeapon`), a shipped mechanism and strictly stronger than a flag — nobody who has not
bought it can hold one — and the `RIFLE` flag already decides whether any bought weapon is handed out
at all. A flag whose two states are "a shop row exists" and "a shop row does not" is the map-switch
mistake CLAUDE.md names: *a switch that cannot be switched off is not a feature flag*. The one flag
read in the whole weapon system stays `Weapons.loadout()`, at that boundary, passed inward as a list.

**The accepted cost, stated because it is real:** `Shop.loadoutFrom` returns **every** id when
`owned` is nil — an un-wired world, a build with the shop off, a profile that would not load, and
every `tests/server/weapon_*.spec.luau`. So those worlds now hand out three guns instead of two.
That is the same accepted cost `docs/design/shop.md` section 7.1 already names for the rifle (*"a
player who owns nothing is handed the rifle for one drive"*), and the direction is the safety of the
whole feature: nobody loses a gun because a DataStore was slow.

---

## 12. What it reads and writes, and who owns each

| It reads | Owner | Why |
|---|---|---|
| `Shotgun.deepFreeze`, `Shotgun.ActionKind` / `AmmoKind` | `ReplicatedStorage.Shotgun` | the freeze helper and two type names, which is what `Rifle` takes |
| `Gun.MESH_ROTATION_DEG`, `Gun.Piece`, `Gun.Group` | `ReplicatedStorage.Gun` | one measured constant and two type names; re-typing 270 would hide a correction from one gun |
| `Shop.ownsWeapon`, `Shop.loadoutFrom`, `Shop.startFor`, `Shop.BASE_AMMO` | `ReplicatedStorage.Shop` | whether a hunter may carry it, and what it is issued with. One-way: `Weapons` requires `Shop`, never the reverse |
| `Flags.isOn("RIFLE")` | `ReplicatedStorage.Flags` | **only** at `Weapons.loadout()` |
| `Ballistics.shotFor` + the four required numbers | `ReplicatedStorage.Ballistics` | the flight; a row missing one refuses the shot rather than firing straight |
| `HandAssets.GRIP_STUDS` / `GRIP_RADIUS_STUDS` | `ReplicatedStorage.HandAssets` | the glove's own gap, checked against the loop's grip bar |
| `Assets.byKey` / `Loader.template` | `ServerStorage.Assets` | the three uploads |
| `Viewmodel.DATA.weapons.lever` | `src/shared/Viewmodel/poses.json` | every pose number, content lane |

| It is read by | Owner | What it hands over |
|---|---|---|
| `Weapons.ROWS` / `row(id)` / `geometry(id)` | `src/shared/Weapons/init.luau` | the row and the geometry, by id |
| `Weapon.StateMachine.apply` / `initial` | `ServerScriptService.Weapon.StateMachine` | `BARRELS`, `INITIAL_AMMO`, `START_RESERVE`, `BARREL_DELAY`, `CYCLE_EJECTS`, `AMMO_KINDS`, and the two step lists through `waitFor` |
| `Weapon.runCycle` | `ServerScriptService.Weapon` | `CYCLE`, `RELOAD`, `AUTO_CYCLE`, `AUTO_RELOAD_WHEN_EMPTY` |
| `Weapon.Hardware` | `ServerScriptService.Weapon.Hardware` | `HANDLE_SIZE`, `HANDLE_COLOR`, `GRIP`, `ASSET_KEYS`, `MESH_NAMES`, and the shape through `Weapon.Shapes.for_` |
| `Camera.Viewmodel.buildNewGun` / `hinge` / `poseHands` | `PlayerScripts.Camera.Viewmodel` | `Lever.Geometry`'s function set and `CYCLE_KIND` |
| `Hud.readoutFor` / `ammoChipFor` / `killLineText`, `ReportPanel` | `PlayerScripts.Hud` | `READOUT`, `MAGAZINE`, `AMMO_LABEL`, `label` |
| `Weapon.Sound` | `PlayerScripts.Weapon.Sound` | `SOUND.shot` / `bolt` / `load` |
| `Shop.rowsOk(weaponRows, …)` | `ReplicatedStorage.Shop` | that `grants.weapon = "lever"` names a weapon this build ships |

**Writes: none.** This system writes no state, no Instance, no remote and no attribute.

---

## 13. External sources

Three gun sources plus the repo's own prior art. **No code and no asset is taken from any of the
three**: they are cited for facts and for the shape of one motion. All three are ordinary
copyrighted web pages (no open licence); what is borrowed is a number or a sentence, and that is
recorded here, which is rule 2's requirement.

**13.1 Hornady LEVERevolution .45-70 325 gr FTX factory ballistics** — the published tables as
carried by Midwest Gun Works and Gunners Den (2050 / 1729 / 1450 / 1225 fps at 0 / 100 / 200 /
300 yd, 24-in barrel).
*Licence:* retail spec sheets, all rights reserved; figures are Hornady's published data, cited as
facts. *Maintenance:* live retail pages, revised with the catalogue.
*Good at:* four velocities for the exact load a Marlin 1895 is sold for — enough to fit one drag
coefficient to the first and **predict** the other two to 0.6 %.
*Bad at:* no drop table for a 100 m zero, no BC-based trajectory, no in-game units; two independent
pages were compared so that one typo cannot become this gun's muzzle velocity.
*Adopted:* the four velocities, and nothing else. Everything in section 9 is computed from them by
the shipped closed forms.

**13.2 Gun Digest, "Cowboy 101: How To Run A Lever-Action Rifle"**
(https://gundigest.com/gear-ammo/rifles/how-to-run-a-lever-action-rifle)
*Licence:* editorial, all rights reserved. *Maintenance:* actively published magazine site.
*Good at:* the throw as a continuous motion of the hand that never leaves the grip, and the rifle
staying mounted through it — which is what `cycle.hand` draws and why `reachShare` is small.
*Bad at:* no timings at all, so it cannot settle 1.10 s.
*Adopted:* the hand stays on the gun; the right hand works the lever; the sights come back down onto
the animal rather than the gun coming off the shoulder.

**13.3 Hunter-Ed, "How Does a Lever Action Rifle Work?"**
(https://www.hunter-ed.com/national/studyGuide/How-Does-a-Lever-Action-Rifle-Work/201099_700056147/)
*Licence:* course material, all rights reserved (Kalkomey). *Maintenance:* actively maintained
state hunter-education courseware.
*Good at:* one throw = eject, feed, cock, in that order — which is exactly `Break` (eject the spent
case) then `Close` (feed and chamber), and is why the lever adds no primitive.
*Bad at:* a teaching diagram; nothing about the gate, nothing about rate.
*Adopted:* the two-step reading of one throw, and `CYCLE_EJECTS = "spent"` as its consequence.

**13.4 Ranger Point Precision, "Tips on How to Hold, Aim, and Shoot a Lever-Action Rifle"**
(https://rangerpointprecision.com)
*Licence:* vendor blog, all rights reserved. *Maintenance:* active commercial site (it sells short-
throw kits, which is a declared interest).
*Good at:* the explicit claim that a shorter throw raises the practical rate — the only source of the
four that connects the motion to a *rate*, which is what 1.10 s is measured against.
*Bad at:* commercial, and it states no measured rate.
*Adopted:* the direction only — a lever cycles faster than a bolt, which is why 1.10 < 1.62.

**13.5 In-repo prior art, which rule 2 makes the first place to look.** Every pattern this design
reuses is already shipped and reviewed here:
`docs/research/2026-10-09-rifle-scope.md` (a second weapon as a row);
`2026-10-10-rifle-bolt-magazine-sound.md` (a cycle as data on the row, per-weapon voices, every id
measured to load); `2026-10-14-ballistics-lead.md` (one drag coefficient, fitted and then predicting
— and the FastCast stepping pattern, MPL-2.0, docs repo marked obsolete, living forks MIT-0, **not
vendored** because it ships as a banned `.rbxm`); `2026-10-15-rifle-right-hand.md` (hand anchors
measured off the model, and the four tolerances); `2026-10-01-poses-as-data.md` (poses outside the
code); `backups/2026-10-10-rifle-open-sights.md` (the open-sight machinery, and the cancelled upload
that D-3's measurement avoids); `backups/2026-10-16_task-196_shop-rifle-open-row.md` (the shop rung
this row re-occupies, at price 600 / hunts 10).
The Builder writes `docs/research/2026-10-20-lever-action.md` with 13.1–13.4 and an `INDEX.md` row
before any code (rule 1).

---

## 14. Numeric targets

| Target | Value | Where it is checked |
|---|---|---|
| Overall length | 4.0 studs (40.5 in at 45 in = 4.4) | `lever.spec`: `HANDLE_SIZE.Z == 4.0`, `MUZZLE_OFFSET.Z == -HANDLE_SIZE.Z/2` |
| Triangles | ≤ 8,258 per group (the Rigby's worst); 17,485 total as bought; Roblox's ceiling 20,000/mesh | `asset_prep` report, `Assets.ROWS.trisDeclared` |
| Textures | 1024 px, four maps, ORM split | the manifest rows |
| Muzzle velocity | 2232 studs/s (2050 fps) | `lever.spec` against `Lever.CONFIG` |
| Drag prediction error | ≤ 1 % at 200 and 300 yd, nothing fitted to either (measured: +0.6 %, +0.5 %) | `lever.spec` via `Ballistics.speedAt` |
| Zero | 357 studs (100 m) | `lever.spec`: inside `RANGE_STUDS` |
| Reach | 600 studs (168 m) | `lever.spec`; the shop blurb says 165 m |
| Drop band, 0–150 m | within +1.5 cm / −5.2 cm of the sight line | `lever.spec` via `Ballistics.sightOffsetAt` |
| Lead at 150 m on a 38 studs/s boar | 10.5 studs | `lever.spec` via `Ballistics.leadStuds` |
| Dispersion | exactly 0 (one bullet along `aim`) | `lever.spec` via `Pattern.directions` |
| Cycle | 0.46 + 0.64 = 1.10 s; drawn `openSeconds` 0.40 and `closeSeconds` 0.58, both **strictly less** than the server's steps | `lever.spec` (the sum) and `viewmodel_poses.spec` (the shipped "draws the break and the close faster than the server performs them" rule) |
| Reload | 0.40 + 5 × 0.42 + 0.40 = 2.90 s full; **1.64 s** for a two-round top-up | `lever.spec` (the sum, and the `cycleRefusal` cases) |
| Capacity | 5 chambers, 5 magazine, 10 in the pocket | `lever.spec`; `Hud.PIP_MAX` is 8, so five pips draw |
| Hud label | ≤ 7 characters (`LEVER` is 5; the `gun` cell is 88 px and `SHOTGUN` measures 46) | `rifle_client.spec`'s column-alignment case, extended |
| Shop | price 650, hunts 12, label 12 chars ≤ 18, blurb 106 chars in 20..135, `#Shop.ORDER` 11 ≤ `MAX_ITEMS` 12 | `shop.spec` and `Shop.rowsOk` |
| Camera cost | unchanged: ≤ 0.3 ms average `Camera.update` | `camera_client.spec`'s existing budget case |
| Drawn parts | Handle + Lever envelope + 3 pieces (+2 gloves) = 7 | `Geometry.partCount`, `Camera.stats().parts` |

---

## 15. How it is tested

### 15.1 Server spec — `tests/server/lever.spec.luau` *(new)*

Pure, no session, driven exactly as `tests/server/rifle.spec.luau` is. **Every case must enter THIS
weapon's own branch** rather than a case that would also pass on the scoped rifle (the Learning
Agent's [L-093]) — written out per case below.

1. **The table holds three weapons, in hotbar order, frozen all the way down.** `Weapons.ids()` is
   `{ "shotgun", "rifle", "lever" }`, `PRIMARY` is `shotgun`, every row deep-frozen.
   *Lever-only:* the third id and `slot == 3`.
2. **The row is `Lever.CONFIG`, field by field** — a `pairs` walk over the config with a skip set, so
   a number that moves fails the harness instead of drifting (the shape 143a asked for).
   *Lever-only:* it asserts against `Lever.CONFIG`, which no other row may read.
3. **Ballistics:** every required field present for `Slug`; `shotFor` non-nil; the zero inside
   `RANGE_STUDS`; the 200 yd and 300 yd **predictions** within 1 %; the drop band at 50/100/150 m
   within +1.5 / 0 / −5.2 cm; the lead at 150 m 10.5 studs.
   *Lever-only:* the .45-70 numbers and the 0.35 band, which fail on the rifle's 0.12 / 714.
4. **No cone:** `Pattern.directions("Slug", aim, rng, row)` returns exactly one direction, equal to
   `aim`. *Lever-only:* run with this row, whose `PELLETS` is 1 and `SPREAD_FULL_DEG` 0 — shared with
   the rifle, so case 3 is what distinguishes it; kept because it is the shot's own invariant.
5. **`SIGHT = "bead"` draws no scope and no sight picture:** `row.scope == nil`;
   `Weapons.geometry("lever").sightKind(row) == "bead"`; **no piece returned by
   `Geometry.pieces(row)` is named `Scope`**; `ShapeLever.pieces(row)` contains no tube; and
   `Geometry.sight(row)` is on the centre line (`x == 0`) at the measured front sight, forward of the
   action. *Lever-only:* the rifle's geometry answers a scope for its own row.
6. **The cycle is two steps and the total is the sum**; `CYCLE_TOTAL == 1.10`; `CYCLE_EJECTS` is
   `"spent"`; `AUTO_CYCLE` true. *Lever-only:* 1.10 against the rifle's 1.62.
7. **The reload is `Break` + five `Load` + `Close`, the total is the sum, and it carries NO
   `Magazine` step.** *Lever-only:* the rifle's `RELOAD` begins with `Magazine`.
8. **The reducer, driven with this row:** fire → busy for `BARREL_DELAY`; `Break` ejects the spent
   case and **leaves the other four live** (count them); `Load` fills one chamber and takes one from
   the pocket; five shots empty it; a full `RELOAD` walk refills five.
   *Lever-only:* five chambers and `Load`-by-`Load` filling; the rifle fills three at once.
9. **`Weapon.cycleRefusal`, all three answers, and the two shipped guns cannot reach the new one:**
   `("Load","no-reserve") == "walk"`, `("Load","barrel-full") == "finish"`,
   `("Close","is-closed") == "abort"`; then a **partial top-up** driven through the reducer step by
   step — three live, press `R`, two `Load`s succeed, the third answers `barrel-full`, the sequence
   finishes at `Close`, and the elapsed window is 1.64 s and not 2.90.
   *Lever-only by construction:* a case that asserts the shotgun's `Break` leaves every chamber
   `Empty` and that the rifle's reload never issues a `Load`, so neither can enter the branch.
10. **`waitFor` charges each sequence its own window** (`Break` is 0.46 in `CYCLE` and 0.40 in
    `RELOAD`), driven with `steps` named — the defect task 184 measured.
    *Lever-only:* this gun's two lists disagree about `Break` by 0.06.
11. **No row carries a forbidden field** — the existing loop, extended to three ids.
12. **The geometry and the shape resolve for every weapon and are three different modules**;
    `Weapons.geometry("lever")` is `Lever.Geometry` and `Shapes.for_("lever")` is `ShapeLever`.
13. **The cycle group SWINGS:** `Geometry.CYCLE_KIND == "lever"`, `CYCLE_GROUP_NAME == "Lever"`, and
    **`leverThrow` carries the loop's grip point DOWN AND FORWARD** — at progress 1 the point
    `leverGripOffset` has a smaller `Y` **and** a more negative `Z` than at progress 0, and at
    progress 0 the transform is identity. *This is the sign case, and it is the one task 188 bought.*
14. **The hand anchors are on the gun:** `offGripAxis(gripOffset) == 0`;
    `|alongGripAxis(poses.carry.right)| <= gripHalfLength` and `offGripAxis(...) <= gripRadius` for
    the hip hold; `(cycle.hand.grip.Position - leverGripOffset).Magnitude <= leverGripRadius +
    HandAssets.GRIP_RADIUS_STUDS` for the hand on the loop.
15. **The flat-name set is identical for all three weapons** (`Viewmodel.view` per id, key by key),
    so no reader can get a nil — which is what forces the inert `cycle.load` and `cycle.shells`.
16. **`Viewmodel.validate`** finds nothing wrong with the shipped file; a `weapons.lever` removed is
    named; `weapons.lever` carrying both `reload` and `cycle` is named.
17. **Hud:** `readoutFor` prints `5/5 .45-70 10` for a full gun and `ammoChipFor` returns five pips
    with no selection. *Lever-only:* five pips and `.45-70`.
18. **`Viewmodel.handFeedsShells`** is false for `Lever.Geometry` and `Rifle.Geometry`, true for
    `Gun`. *Lever-only half:* the lever has no `MAGAZINE_SWAP`, so before this task it would have
    answered "draw them".

### 15.2 Shop — `tests/server/shop.spec.luau` *(edited)*

- `#Shop.ORDER` 10 → **11**, still ≤ `MAX_ITEMS`, still cheapest-first (650 sits between the high
  seat's 600 and the deer licence's 750).
- `Shop.ROWS[Shop.ITEM.LEVER].price == 650`, `hunts == 12`, `grants.weapon == "lever"`, `sale == true`.
- **The weapons shelf now has two rows, cheapest first:** `groups[1].rows[1].id == Shop.ITEM.LEVER`
  and `#groups[1].rows == 2`. The shipped case's own comment anticipated exactly this —
  *"the ordering it was written for comes back with the next weapon"*.
- `Shop.ownsWeapon({ [Shop.ITEM.LEVER] = true }, "lever")` is true, and false for someone who owns
  only the scoped rifle; `Shop.loadoutFrom(Weapons.ORDER, "shotgun", owned)` returns
  `{ shotgun, lever }` for that man.
- `Shop.startFor(Weapons.ROWS.lever, owned)` issues `Slug` from `BASE_AMMO.lever` **without** the
  slug-shell purchase (the rifle's own rule: selling a man a rifle and then no rounds for it would be
  the shop taking money for nothing).
- **`rowsOk` is clean**, with `Weapons.ROWS` passed in — which is the invariant that the shop cannot
  sell a weapon no build ships.
- **It is in no bundle, and that is a measured constraint:** `Grants.weapon` is single-valued and
  `Shop.mergedGrants` returns a *conflict* for two covered rows that disagree about one field, which
  `rowsOk`'s I11 turns into a failing harness line. THE FULL SEASON already covers the scoped rifle,
  so adding the lever to it would fail the gate. A case asserts `mergedGrants` still has no conflict.

### 15.3 Client spec — `tests/client/lever_client.spec.luau` *(new)*

What only a running client can show, driven through `PlayerScripts` (never `StarterPlayerScripts`,
which is a template), with the first-person branch reached **by parameter** as
`camera_client.spec` and `rifle_client.spec` do:

1. **The gun is built from the lever's own geometry:** with a Tool carrying
   `DrivenHunt.Weapon = "lever"`, `Viewmodel.weaponId()` is `lever`, the model's moving group is
   named `Lever`, and `Camera.stats().weapon` agrees.
2. **The aim is NOT a scope:** at blend 1 the field of view is 50, `Camera.scope()` is nil, no
   eyepiece and no reticle is visible anywhere up the parent chain (visibility walked to the
   `ScreenGui` — a visibility audit that ignored parent visibility certified a blank screen twice),
   and the **gun and both gloves are parented** (the rifle's `hiddenByScope` branch must not fire).
3. **The lever swings and the fore-end hand does not follow it:** step `Mode.step` through a cycle,
   and at `cycleProgress` 1 the `Lever` part has moved while `HandLeft`'s world position has moved by
   less than a hundredth of a stud from its rest pose. *This is the `poseHands` finding.*
4. **The right hand is on the loop** at full throw: within `HandAssets.GRIP_RADIUS_STUDS` of the
   lever part's own grip point.
5. **No loose shell is ever drawn:** after a simulated open with `spent = 1`,
   `Viewmodel.stats().shellsDrawn` does not move and no child named `SpentShell*` or `FreshShell*`
   exists on the clone. *Lever-only: the shotgun's own case asserts the opposite, in `gun_client.spec`.*
6. **The readout and the report column:** `Hud.readoutFor` on a live lever state, and the GUN cell
   drawn for `LEVER` sits inside its 88 px column — the alignment case task 143 added, extended with
   the third label.

### 15.4 Harness: input, screenshots, scopes

- **`BLAST_RADIUS`** gains `("src/shared/Lever/", "gun")` — its numbers and its drawn geometry are a
  gun's, exactly as `src/shared/Rifle/` is. The server shape and the sequence runner are already
  `("src/server/Weapon/", "weapon")`; the drawn gun is already `("src/client/Camera/Viewmodel.luau",
  "viewmodel")`; `src/shared/Shop/` is already `shop`.
- **`SCOPE_SPECS`**: `lever.spec` into **`gun`** (its numbers), **`weapon`** (the reducer and the
  sequence runner) and **`shop`** (the row and its grant); `lever_client.spec` into **`weapon`** and
  **`viewmodel`**. Standing rule G: a new spec in no scope turns CI red, and
  `tools/studio_mcp.py selftest` fails both ways (a spec in no scope, and a scope naming a file that
  does not exist) — so the table edit and the spec files land in the same commit.
- **Input the harness cannot drive, said plainly (rule 6, TASKS 6–7):** the hotbar keys **1/2/3
  cannot be replayed at all** — `VirtualInput` refuses them as *"permanently bound to a CoreGUI core
  action"* (measured in task 141). So "press 3 and the lever comes up" is **Karen's click or the
  Director's**, not a scenario line. What the specs do instead is drive the switch **as a function**:
  `Weapon.refreshArming(player, { "shotgun", "rifle", "lever" })` puts three Tools in the bag in
  order, `Hardware.equip` puts the lever in the hand, and `Weapon.heldFrom` is asserted over three
  replicas (the rule task 143 built after the third Tool broke the client's replica). A
  `lever-aim` scenario (right mouse down, hold, release) **is** addable to
  `tests/client/input_scenarios.txt` and should be, because the aim is an ordinary mouse button.
- **Screenshots (rule 5), inspected by the Builder, not counted:** (1) the lever in the hand at the
  carry; (2) aimed down the irons at a plate, the front sight on the target; (3) **three frames of
  one throw** — rest, full throw, home — which is the one thing the numbers cannot certify (the
  hand on the loop, the loop clear of the wrist, nothing buried in the stock); (4) the top-up, to see
  whether the thrown-open loop reads wrong (section 17 K-4); (5) a kill at 150 m with the report row
  naming the gun. `python tools/studio_mcp.py capture <name>`.
- **Gate:** the one-player `test` only. The weapon is not in `TWO_PLAYER_PATHS`
  (Director decision 2026-10-03, after Karen: *"we dont need 2 player test now we just working on
  weapon and animal next"*), and this task touches none of `src/server/Match/`, `src/client/Match/`,
  `src/shared/Drive/` or their specs. `test2` is **N/A with that reason**.
- **Content lane:** once the pose set exists, every number in `weapons.lever` is tuned live with
  `tools/pose.py set/show/compare`, Karen looks, `tools/pose.py save` commits with the one-player
  gate and no review round. `tools/pose.py clear` and `tools/flags.py clear` before any harness run —
  both `test` and `test2` refuse to start otherwise.

---

## 16. Explicitly out of scope

1. **The semi-auto shotgun** — task 225.
2. **A Robux product id** — every row's `robuxProductId` is nil in this build and `rowsOk`'s I12
   asserts it; task 222 needs Karen's Creator Dashboard.
3. **New audio uploads** — section 8 reuses measured library ids.
4. **A new hit card, decal, report path or hit-zone table** — the bullet is one `Slug` and the
   existing card draws it (D-13).
5. **`Match.CONFIG.SAFETY_RANGE_STUDS`** — still 330, still queued as 183a(a), still a
   `TWO_PLAYER_PATH`.
6. **The drawn gate feed** (a hand carrying a cartridge to the gate, and a shell at the gate) —
   **224a**, with its four prerequisites named in 7.4.
7. **The lodge gun rack** — `ForestTestBoot`'s `WEAPON_OF` names two words and stays as it is; a
   third gun on the wall is a cosmetic task.
8. **Folding `cycleLength`/`cycleZ` into `Gun` and `Rifle.Geometry`** — "before release" (7.2).
9. **An Aimpoint or any second sight on this gun** — it has one sight configuration, and task 143's
   `skipFor` / `onlyFor` filter stays where it is, for the rifle's next sight.
10. **A bundle containing the lever** — blocked by `mergedGrants`' single-valued `weapon` field
    (15.2); widening `Grants.weapon` to a set is the Director's, as shop design section 17 D-3
    already records for `Grants.ammo`.

---

## 17. Open decisions

**None of these blocks building.** Each ships at the stated value and is one line to change.

**Karen (feel):**

- **K-1. `GRAVITY_SCALE = 0.35.`** Ships at 0.35 (band +1.45 / 0 / −5.19 cm at 50 / 100 / 150 m).
  1.0 is the real world (+4.14 / 0 / −14.84). Hers, and the same call as 185a(h) and 189.
- **K-2. The cycle at 1.10 s and the reload at 2.90 s.** She set the bolt's 1.62 by eye; these are
  proposed against it and against the 0.62 that read as too fast.
- **K-3. The recoil, as data (D-11).** `weapons.lever.fire` ships **above** the scoped rifle's 5.6 /
  0.68 / 19.0 — a .45-70 in a light carbine kicks harder than a .416 in a heavy stalking rifle — with
  the ceilings in the same ratio. Content lane, her dial, no review round.
- **K-4. Does the thrown-open loop read wrong during the top-up?** (7.4.) If it does, 224a is a
  second drawn state; if it does not, the five `Load` steps stay as they are.
- **K-5. The three voices and their pitches** (section 8). Nobody here can hear them.
- **K-6. The shop price.** Proposed **650 / 12 hunts** — dearer than the archived "RIFLE, OPEN" rung
  (600 / 10) because this one actually ships a gun, and well under the scoped rifle's 1500 so the
  ladder she accepted (slugs → lever gun → scoped rifle) still climbs.

**Director (scope):**

- **D-a. `cycleRefusal`'s `"finish"`** (6.3) versus the BRIEF's literal walk-past. Ships as
  `"finish"`: a two-round top-up is 1.64 s instead of 2.90. One line either way.
- **D-b. The new `load` voice key** (section 8) versus a silent gate. Ships with the key.
- **D-c. 224a** — the drawn gate feed, and with it `loadingAt`'s two-chamber loop,
  `chamberOffset`'s hard-wired `Shotgun.CONFIG` and `Camera.breakFrom`'s two-chamber `loaded`. All
  three are shipped defects that only this gun exposes; this task **suppresses** rather than fixes
  them, by declaring the fact about the gun (7.3).
- **D-d. Who runs the three uploads** (section 18 step 3). Task 140's uploads were the Director's.

---

## 18. Build order, with the stop points

1. **Research note** `docs/research/2026-10-20-lever-action.md` + `INDEX.md` row (rule 1, sources
   13.1–13.4). No code before it.
2. **Outside the repo:** FBX → glTF; `gltf_split probe`; **record every measurement in section
   10.2**; write `LEVER_PLAN`; `gltf_split split`; `asset_prep prep` ×3. Report the triangle counts
   and the preview of each group, having **looked at it** (rule 5).
3. **STOP: `READY TO UPLOAD 224 <folder list>`.** Then `roblox_upload.py`, then the three
   `Assets.ROWS` rows and the `assets/uploads.json` rows with Karen's words verbatim. The row cannot
   land before this (section 10.3, `assets_seam.spec`).
4. `src/shared/Lever/` (config + geometry), `src/server/Weapon/ShapeLever.luau`, the three map
   entries (`Weapons.ROWS`/`ORDER`/`GEOMETRY`, `Shapes.BY_ID`), `Viewmodel.validate`'s literal,
   `ViewmodelAssetsBoot`'s folder + preload + publish.
5. `Weapon.cycleRefusal` + the `runCycle` branch; `Viewmodel.hinge`'s `"lever"` branch;
   `Viewmodel.handFeedsShells` + its two call sites; the two envelope tokens; `Sound.load` +
   `CameraBoot`'s `Load` edge.
6. `weapons.lever` in `poses.json`, authored against the section-10.2 measurements.
7. The shop row (`ITEM`, `ROWS`, `ORDER`, `ALL_ORDER`, `BASE_AMMO`).
8. `tests/server/lever.spec.luau`, `tests/client/lever_client.spec.luau`, the `shop.spec` and
   `rifle.spec` edits, `BLAST_RADIUS` + `SCOPE_SPECS`.
9. `GAME_DESIGN.md`'s two owner rows; `CREDITS.md`'s attribution.
10. Lint, `rojo build`, `python tools/studio_mcp.py test`, the five screenshots, then the request.
