# Design: rifle — a second weapon behind the same owner, a scope that is a field of view, and a bolt

Architect, 2026-10-09, for Task 140. Commit `bbed45189ec4455df3739811e0f00d4434f90e81`
(`.agent-evidence/INDEX.md`). Read-only session: Read, Grep, Glob. No Studio, no network.

**This is a new design. It extends `docs/design/shotgun.md` (v3) and `docs/design/camera.md` and
replaces neither.** Where a section here contradicts one of those two, this file wins for the rifle
and changes nothing about the shotgun.

Inputs, in precedence order: `reviews/task-140/BRIEF.md` (the Director's and Karen's input, which
overrides anything older), `docs/research/2026-10-09-rifle-scope.md` (rule 1: the ballistics, the
engine fact about `ViewportFrame` and sources 1–7 come from there and are not re-derived),
`docs/design/shotgun.md`, `docs/design/camera.md`, `docs/design/drive-report.md`, the code now on
`main`, `CLAUDE.md`, `docs/PROJECT_CONTEXT.md`.

**Test of this document:** a Builder can build the rifle from it without asking a question. Every
owner is named with its file and symbol, every interface change is written out as a before/after,
every number is here, and every spec case is named.

---

## 1. What the system must do, and must not do

### 1.1 Must do

1. A **second weapon** the hunter carries beside the shotgun, selected with **`1` = shotgun,
   `2` = rifle** (the Director's dispatch, brief §2.8).
2. **One round per shot**, with a **bolt cycle** between shots, and the bolt handle **seen to move**.
3. **Ballistics as data**: a single projectile, longer reach and flatter than the slug.
4. **A scope**: right mouse **narrows the field of view** to the weapon's own `aimFovDeg` and the Hud
   draws a **reticle**; releasing returns to the hip view, which has **no crosshair of any kind**
   (Karen's standing rule, 2026-09-27; `Hud.crosshairVisible` already returns false in first person).
5. The **same hit path as the shotgun** — `Weapon.Hits.group` → `Weapon.HitReported` → `HitLog` → the
   drive report — with the report **naming the weapon**.
6. **Hands on the rifle** in first person, with carry and aim poses as **data** in
   `src/shared/Viewmodel/poses.json` (the content lane), tunable live with `tools/pose.py`.

### 1.2 Must not

Each row is a prohibition with the evidence for why it exists.

| Prohibition | Why, with evidence |
|---|---|
| Never add a second writer of `workspace.CurrentCamera`. The scope is a **number handed to the camera**, nothing more | `Camera.Rig.apply` is the one writer and counts foreign writes by comparing the whole CFrame **and** `FieldOfView` to 1e-3 (`src/client/Camera/Rig.luau`, `Rig.apply`, `Rig.stats().foreignCameraWrites`). A second writer is detected, not tolerated |
| Never render the scene twice. No `ViewportFrame` scope, no `SceneCapture`-style lens | The engine cannot do it: a `ViewportFrame` renders only the instances parented **into** it (research note §2, source 1). This is an engine fact, not a cost judgement |
| Never change a shotgun number | Karen approved that gun on 2026-10-09 (*"gun is ok"*); brief §2.5. `Shotgun.CONFIG` is deep-frozen and has no writer (`src/shared/Shotgun/init.luau`, `Shotgun.deepFreeze(Shotgun.CONFIG)`) |
| Never let a weapon row carry the **safety arc**, the camera-origin tolerance, or a rate limit | Those are rules of the drive and of the protocol, not properties of a gun. A per-weapon `SAFETY_ARC_HALF_DEG` would let a new weapon widen its own licence to shoot down the line. §4.3 keeps them system-level |
| Never create a second weapon owner, a second fire path, or a second validator | rule 3; the research note's §4. `src/server/Weapon/init.luau` stays the only writer of Tool Instances (through `Hardware`) and the only validator of a shot |
| Never draw the reticle from the camera or the weapon | `PlayerScripts.Hud` is the one writer of anything drawn (`src/client/Hud/init.luau` header; `GAME_DESIGN.md` "UI / anything drawn"). The previous project's "one predicate answered two unrelated questions, so mounting hid both the crosshair and the weapon" is what that rule is made of |
| Never let the client say which weapon it is holding | `equipped` is already derived from the Tool's `Parent` and never from a client claim (`Weapon.watchEquipped`, shotgun design §5.4). The held **weapon** is derived the same way (§5.2) |
| Never rebuild a `Tool` on a player's keypress | `Hardware.equip` spawns a verification thread per call (`src/server/Weapon/Hardware.luau`, `Hardware.equip`, `equipStats`). An unthrottled rebuild path is a free DoS and it is also the exact code path that failed in tasks 34, 123, 129 and 133. §5.1 removes the need for one entirely |
| Never give the rifle a damage model of its own | `Boar.Wound.damageFor(zone, ammo, pellets, config)` is the one damage decision in the repo (`src/server/Boar/Wound.luau`). The rifle fires a single projectile charged as a slug; see §4.4 and the Director item in §17 |
| Never return `Sink` from a weapon action | shotgun design §1.2 and §2.3 item 5, unchanged. The rifle adds **no new `ContextActionService` binding at all** (§5.1) |

---

## 2. Decisions carried in from the brief — not re-opened here

Listed so a reviewer can see they were taken elsewhere: brief §2, items 1–9. The scope is an FOV zoom
plus a flat overlay; the aim FOV is one number per weapon through the existing camera machinery; one
weapon owner; hitscan; the shotgun's numbers do not move; poses are data; no crosshair in the hip
view; `1`/`2`; the Director uploads the asset with the maker's name painted out of the atlas.

---

## 3. Files on disk

```
src/shared/Weapons/
  init.luau                  -> ReplicatedStorage.Weapons   (THE WEAPON TABLE: rows, ids, loadout)
src/shared/Rifle/
  init.luau                  -> ReplicatedStorage.Rifle     (every rifle number, deep-frozen)
  Geometry.luau              -> ReplicatedStorage.Rifle.Geometry  (the DRAWN rifle, pure data)
src/server/Weapon/
  ShapeRifle.luau            -> ...Weapon.ShapeRifle        (the WORLD rifle's parts fallback, pure)
  Shapes.luau                -> ...Weapon.Shapes            (id -> world shape module; server-side map)
src/shared/Viewmodel/
  poses.json                 -> version 4: per-weapon pose sets (§6.1)
tests/server/rifle.spec.luau         (the table, the row, the reducer with a row, the cycle)
tests/client/rifle_client.spec.luau  (two Tools, the switch, the scope FOV, the reticle, the bolt)
```

Changed, each one a named deliverable in §11: `src/shared/Shotgun/init.luau` (types and one new
`RequestKind`), `src/server/Weapon/init.luau`, `Hardware.luau`, `StateMachine.luau`,
`Validator.luau`, `Hits.luau`, `src/client/Weapon/Input.luau`, `src/client/Camera/Mode.luau`,
`Config.luau`, `Poses.luau`, `Viewmodel.luau`, `init.luau`, `src/client/CameraBoot.client.luau`,
`src/client/Hud/init.luau`, `src/server/HitLog/init.luau`, `src/shared/Report/init.luau`,
`src/shared/Viewmodel/init.luau`, `src/shared/Flags/init.luau`, `src/serverstorage/Assets/init.luau`,
`tools/studio_mcp.py` (two `BLAST_RADIUS` rows and two `SCOPE_SPECS` entries — see §13.5).

**Nothing moves out of `src/shared/Shotgun/` and nothing moves out of `src/shared/Gun/`.** Moving
Karen's accepted numbers is a diff across thirty files whose only product is a risk that one of them
changes. `src/shared/Gun` stays what its header says it is — the drawn **shotgun's** geometry — and
the rifle gets a sibling with the same function set (§6.2).

`ReplicatedStorage.Shotgun.Remotes` keeps its path and its five RemoteEvents. The name is now
historical: that folder is the **weapon system's** wire, not the shotgun's. A rename is churn across
`Shotgun.remotes()`'s twenty call sites and buys nothing; say it in the file header instead.

---

## 4. The weapon table

### 4.1 Where the set of weapons lives — one shared module, rows collected

**`ReplicatedStorage.Weapons`** — disk `src/shared/Weapons/init.luau`. Deep-frozen, **no writer**,
the same shape `src/shared/Shotgun/init.luau` and `src/shared/Drive/init.luau` already have.

```luau
export type WeaponId = string                     -- "shotgun" | "rifle"; the table is the authority

Weapons.ROWS: { [WeaponId]: Row }                 -- deep-frozen
Weapons.ORDER: { WeaponId }                       -- { "shotgun", "rifle" }: hotbar slot 1, slot 2
Weapons.PRIMARY: WeaponId                         -- "shotgun": what AUTO_EQUIP puts in the hand
Weapons.row(id: WeaponId?): Row?                  -- nil for an unknown id; never errors on a client string
Weapons.ids(): { WeaponId }                       -- a copy of ORDER
Weapons.loadoutFor(rifleOn: boolean): { WeaponId } -- PURE. { "shotgun" } or ORDER
Weapons.loadout(): { WeaponId }                   -- loadoutFor(Flags.isOn("RIFLE")); the ONE flag read
Weapons.geometry(id): Geometry?                   -- the DRAWN gun's data module (§6.2)
```

**Each weapon's numbers belong to its own module**, and `Weapons` collects them:

| Weapon | Numbers | Drawn (first person) | World fallback parts |
|---|---|---|---|
| `shotgun` | `ReplicatedStorage.Shotgun` (`Shotgun.CONFIG`), untouched | `ReplicatedStorage.Gun`, untouched | `ServerScriptService.Weapon.Shape`, untouched |
| `rifle` | `ReplicatedStorage.Rifle` (`Rifle.CONFIG`) | `ReplicatedStorage.Rifle.Geometry` | `ServerScriptService.Weapon.ShapeRifle` |

`Weapons` requires `Shotgun`, `Rifle`, `Gun`, `Rifle.Geometry` and `Flags`. There is no cycle:
`Shotgun` requires nothing, `Rifle` requires `Shotgun` (for `deepFreeze` and the shared types),
`Gun` already requires `Shotgun`, and `Flags` already requires `Shotgun`.

**Why one module and not "a row per module with a registry that collects them".** A registry that
collects rows needs a registration order, and a weapon that forgot to register is a weapon that
silently does not exist — the same class of defect as the `FindFirstChild`-instead-of-`WaitForChild`
races of tasks 123, 133 and 134. A literal table is readable as a sentence, is frozen at require
time, and `Weapons.ids()` cannot answer differently on two machines.

**Why not a row inside `Shotgun.CONFIG`.** `Shotgun.CONFIG` is frozen and approved; adding a sibling
weapon to it makes the file that holds Karen's accepted numbers the file everybody edits.

**Borrowed from inside this repo (rule 2).** This is exactly the shape `Boar.CONFIG.KINDS` already
has and ships: one owner, a row per animal, `Boar.kindRow(kind)` and `Boar.kindGeometry(kind)` pure
beside it, and the composition root mapping a kind to an asset key (`src/server/Boar/init.luau`;
`GAME_DESIGN.md`, Boar row, Task 119). Three animals needed no second boar owner; two weapons need
no second weapon owner.

### 4.2 The row type, written out

```luau
export type Row = {
    id: WeaponId,
    label: string,                 -- "SHOTGUN" / "RIFLE": what the Hud prints
    toolName: string,              -- "Shotgun" / "Rifle": Tool.Name, and how a stray is found
    slot: number,                  -- 1 or 2; the hotbar order, for the record (the engine orders it)

    -- ballistics. The SHOTGUN's own field names, so nothing downstream learns a new word
    -- (research note section 4).
    RANGE_STUDS: { [string]: number },      -- keyed by AmmoKind
    PELLETS: { [string]: number },
    SPREAD_FULL_DEG: { [string]: number },  -- DEGREES, FULL cone. Halved once, in Pattern.directions
    AMMO_KINDS: { string },                 -- the kinds this weapon can carry; the SelectAmmo whitelist
    AMMO_LABEL: { [string]: string },       -- the word the Hud prints for a kind (section 4.4)
    INITIAL_AMMO: string,
    START_RESERVE: { [string]: number },

    -- the action
    BARRELS: number,                        -- chambers. 2 / 1
    BARREL_DELAY: number,                   -- seconds the action is busy after a shot
    AUTO_CYCLE: boolean,                    -- true: the owner runs CYCLE itself after an accepted Fire
    CYCLE: { { kind: ActionKind, wait: number } },  -- the reload/cycle sequence, in order
    CYCLE_TOTAL: number,                    -- the sum; a spec asserts it (section 8.1)

    -- the hardware (world Tool)
    HANDLE_SIZE: Vector3,
    HANDLE_TRANSPARENCY: number,
    GRIP: CFrame,
    MUZZLE_OFFSET: Vector3,
    LOOK: { [string]: Color3 },
    ASSET_KEYS: { string },                 -- manifest keys this weapon wears, in wear order

    -- the optics. nil means "no scope": the shotgun's bead.
    scope: Scope?,
}

export type Scope = {
    aimFovDeg: number,             -- the ONE number the camera is told
    magnification: number,         -- recorded, derived: tan(FOV_THIRD/2)/tan(aimFovDeg/2)
    eyeReliefStuds: number?,       -- nil: use the pose data's aim.eyeReliefStuds
    sway: { ampDeg: number, periodSeconds: number },
    reticle: Reticle,
}

export type Reticle = {            -- EVERYTHING IN DEGREES (section 7.2)
    kind: string,                  -- "duplex"; the one kind the Hud implements
    ringOuterDeg: number, ringThickDeg: number,
    crossGapDeg: number, crossArmDeg: number, crossThickDeg: number,
    postArmDeg: number, postThickDeg: number,
    color: Color3, strokeColor: Color3,
}
```

The shotgun's row is **built from `Shotgun.CONFIG`**, not copied out of it: `Weapons.ROWS.shotgun`
reads `Shotgun.CONFIG.RANGE_STUDS`, `.PELLETS`, `.SPREAD_FULL_DEG`, `.BARRELS`, `.BARREL_DELAY`,
`.HANDLE_SIZE`, `.GRIP`, `.MUZZLE_OFFSET`, `.LOOK`, `.START_RESERVE`, `.INITIAL_AMMO`, and its
`CYCLE` is `{Break: RELOAD_BREAK}, {Load: RELOAD_SHELL}, {Load: RELOAD_SHELL}, {Close: RELOAD_CLOSE}`
— the list `Weapon.runReload` builds today, moved into data with the same four numbers. There is one
source for every shotgun number and it is still `Shotgun.CONFIG`; `tests/server/rifle.spec.luau`
asserts row-by-row that `ROWS.shotgun` equals those fields, so a number that moves fails the harness
rather than drifting. `scope = nil` for the shotgun.

### 4.3 What stays system-level, and why

These keep living in `Shotgun.CONFIG` and are read by the owner, **never from a row**:
`SAFETY_ARC_HALF_DEG`, `CAMERA_ORIGIN_TOLERANCE`, `MIN_AIM_DISTANCE`, `DIR_UNIT_TOLERANCE`,
`FIRE_RATE_LIMIT`, `ACTION_RATE_LIMIT`, `STATE_RATE_LIMIT`, `AUTO_EQUIP`, `shouldArm`, and every
`CROSSHAIR_*` / `HIT_MARK_*` / `HUD_*` number.

A rule of the drive or of the protocol must not be a property of the thing it constrains. Written in
the header of `src/shared/Weapons/init.luau` so the next weapon does not put its own arc in its row.

### 4.4 The rifle's one ammo kind, and the word on screen

The rifle carries **one ammo kind, and that kind is `"Slug"`** on the wire.

Evidence for why: `Boar.Wound.damageFor(zone, ammo, pellets, config)` branches
`if ammo == "Slug" then zoneRow.Slug else zoneRow.Pellet` (`src/server/Boar/Wound.luau`). Any new
string is charged as **buckshot pellet** damage, so a new word would make the rifle weaker than the
slug until `Boar.CONFIG.WOUND.DAMAGE` grows a column — a change inside the boar Karen accepted on
2026-10-09, and outside this task.

The cost is that the readout would print `SLUG` for a rifle. That is fixed in the Hud and nowhere
else: `row.AMMO_LABEL` maps the kind to the word (`{ Slug = "SLUG" }` for the shotgun,
`{ Slug = ".416" }` for the rifle), and `Hud.readoutFor(state, row)` prints the label. One mapping,
in the one module that draws.

`SelectAmmo` is refused for a weapon with one kind: `Validator.checkRequest(kind, ammo, row)` accepts
`SelectAmmo` only for an `ammo` in `row.AMMO_KINDS`, so `X` on the rifle is `"bad-request"` and
`stats.badRequests` counts it — no new branch in the owner.

---

## 5. Two Tools, not one that changes

### 5.1 The decision, and why

**A player carries TWO Tools: `Shotgun` and `Rifle`. The engine's own hotbar does the switching.**

| | two Tools (**chosen**) | one Tool that changes |
|---|---|---|
| How `1`/`2` work | the stock `Backpack` CoreGui, which is **already on screen in Karen's sessions** — the Hud disables only `CoreGuiType.PlayerList` (`src/client/Hud/init.luau`, the one `SetCoreGuiEnabled` call). Slot 1 and slot 2 are the keys Roblox binds | a new remote, a new `ContextActionService` binding, a new rate limit |
| What a switch costs on the server | **nothing.** `Tool.Parent` changes; `Weapon.watchEquipped`'s `sync()` already runs on exactly that signal | `Hardware.destroy` + `build` + `give` + `equip` per keypress |
| New DoS surface | **none.** `Hardware.equip` is called only from `Weapon.grant` and `Weapon.upgradeLook` (grep: those are its two callers), so hotbar mashing spawns no thread and builds no Instance | an inbound remote into the most expensive path in the system |
| Risk it re-enters | — | the grant/equip path that produced "the gun is in the Backpack" in tasks 34, 123 round 9, 129 and 133, four separate times |
| What it breaks | `Hardware`'s "one Tool per player, found by one name" and `Input`'s `tool.Name ~= "Shotgun"` filter (§11) | nothing structural |
| Which fact is the truth | the Instance in the character — "the visible model IS the state", the rule `Hardware.MODEL_NAME`'s comment already states | a server variable that can disagree with what is on screen |

The deciding argument is the last two rows together: with two Tools, "which weapon is this player
holding" is **derived from the same Instance the system already watches for `equipped`**, so it
cannot be a second variable that disagrees with the picture. With one Tool it is a stored fact plus a
rebuild of the one Instance whose rebuild has gone wrong four times.

**The cost, stated plainly.** `Weapon.Hardware` becomes keyed by weapon id: `TOOL_NAME` becomes
`row.toolName`, `toolsOf(player)` returns every Tool whose name is in the set, the stray sweep in
`Weapon.grant` destroys strays **of that weapon only**, and `tools[player]` becomes
`tools[player][id]`. Those are §11's named edits and `tests/server/weapon_equip.spec.luau` and
`weapon_rearm.spec.luau` already exercise exactly that path.

**`AUTO_EQUIP` puts the PRIMARY in the hand.** A spawn is bit-for-bit what it is today: the shotgun
equipped, the rifle sitting in slot 2. `Weapon.grant(player, "rifle")` never calls `Hardware.equip`.

### 5.2 "Which weapon is this player holding" — the one owner, and the four readers

**Owner: `ServerScriptService.Weapon`.** The fact is **derived, not stored by anybody else**, in
`watchEquipped`'s `sync()`, which already runs per Tool on `GetPropertyChangedSignal("Parent")`:

```luau
-- src/server/Weapon/init.luau
Weapon.heldId(player: Player): WeaponId?   -- the id of the Tool whose Parent == player.Character
```

It is stored in the one per-player entry the `Registry` already holds (§6.3 `held`) so the fire path
does not walk the character, and it is rewritten by the same `sync()` that writes `equipped` — one
function, one frame, two fields that cannot disagree.

| Reader | What it needs it for | The route |
|---|---|---|
| the fire path | which numbers to validate and cast against | `onFireRequest` → `Weapons.row(Weapon.heldId(player))`. The file-scope `local CONFIG = Shotgun.CONFIG` goes (§11) |
| `Hardware` | which Tool to build | it is **told**: `Hardware.build(row)`, from `Weapon.grant(player, id)`. `Hardware` never asks |
| the client's viewmodel | which pose set and which geometry to draw | the **Tool's own attribute**: `Hardware.build` writes `tool:SetAttribute("DrivenHunt.Weapon", row.id)`, and `Camera.Viewmodel` reads it off the Tool its source already hands it |
| `HitLog` | which weapon to record | the **report**: `Hits.group(..., weaponId)` → `HitReport.weapon` (§9) |

**Two routes for one fact, and the boundary between them is stated so they cannot fight.** The
client has two ways to know: the Tool's attribute and the snapshot's new `weapon` field.

> **The drawn gun follows the Instance; the readout follows the state.**

`Camera.Viewmodel` draws from the **attribute**, because the viewmodel already rebuilds on the
Tool's *identity* (`builtFrom ~= handle` in `Viewmodel.update`) and a snapshot that arrives a frame
later would draw the shotgun in the rifle's hands for that frame. `Hud.readoutFor` formats from the
**snapshot**, because ammo and barrels are state and the snapshot is where state lives.
`tests/client/rifle_client.spec.luau` asserts the two agree once both have settled (§13.2 case 4).

### 5.3 What the client does for a switch: nothing new

`src/client/Weapon/Input.luau` binds **no new action**. Its one change is the filter:

```luau
-- before:  if not tool:IsA("Tool") or tool.Name ~= "Shotgun" then return end
-- after:   if not tool:IsA("Tool") or not Weapons.isToolName(tool.Name) then return end
```

`watchTool`, `pruneWatched`, `forgetTool`, `boundTo` and `isLive` are otherwise untouched, and they
already do the right thing for two Tools: `bind(tool)` records which Tool the four actions belong to,
`Tool.Unequipped` unbinds, and `forgetTool` unbinds only when `boundTo == tool`. That machinery was
written for a dead Tool coexisting with a live one (the comment in `forgetTool` says so) and two
Tools is the same shape. `Input.watchedTools()` becomes **2** in a session with the rifle on — the
invariant the Director fixed in Task 48 was `<= 1`; it becomes `<= #Weapons.loadout()`, and the
client spec asserts that bound, not a literal.

### 5.4 Rate limits

**Switching has no remote and therefore no bucket** — that is the point of §5.1. What it does have
is a publish: `watchEquipped`'s `sync()` calls `publish(player, next, true)` with `force = true`,
which bypasses `STATE_RATE_LIMIT`. A player mashing `1`/`2` floods `StateChanged` at input rate.

So the one change: **the Parent-change publish stops being forced and takes its own bucket**,
`"equip"`, at `EQUIP_RATE_LIMIT = 8` per second (`Shotgun.CONFIG`, system-level). Eight a second is
instant to a human and bounds the flood; `Limits.allow` is unchanged. The `grant`/`revoke` publishes
stay forced — they are one per spawn and the Hud must not miss a gun appearing or being taken away
(TASKS.md 35b(a)).

`"Switch"` is **not** added to `RequestKind` and `ActionRequest` gains no new string. If a later task
needs a programmatic switch (a loadout screen), it gets its own bucket at `SWITCH_RATE_LIMIT = 2/s`;
recorded here so that decision is made on purpose, and not built now.

---

## 6. Per-weapon state, the poses, and the geometry

### 6.1 Pose data: `poses.json` version 4

Today `poses.json` is **one** pose set at the top level (`carry`, `aim`, `reload`, `raise`, `fire`,
`look`), and `Viewmodel.view(data)` flattens it into the names `Camera.Config` publishes
(`src/shared/Viewmodel/init.luau`, `Viewmodel.view`; `src/client/Camera/Config.luau`, the merge loop
at the bottom). Version 3's own history is the precedent: version 2 held two sets and task 114
collapsed them.

**Version 4 re-opens exactly that door, keyed by weapon id and nothing else:**

```json
{ "version": 4,
  "look":    { "fill": { ... } },                  // the fill light: one light, both guns
  "weapons": {
    "shotgun": { "carry": …, "aim": …, "reload": …, "raise": …, "fire": … },   // byte-identical to v3
    "rifle":   { "carry": …, "aim": …, "cycle":  …, "raise": …, "fire": … }
  } }
```

* `look` stays at the top level: it is a light, not a pose, and it is the same light for both guns
  (`Viewmodel.view`'s own comment says so).
* **Every shotgun number moves one level down and not one digit sideways.**
  `tests/server/viewmodel_poses.spec.luau` gains a case that asserts
  `data.weapons.shotgun` equals the v3 file archived under `backups/` field by field, so "the gun
  Karen accepted is unchanged" is a harness check and not a promise.
* The rifle's third pose is named **`cycle`**, not `reload`: a bolt does not break open.
  `Viewmodel.validate` requires `reload` for a weapon whose row has `BARRELS > 1` and `cycle` for one
  with `BARRELS == 1`, and refuses both at once.
* `tools/pose.py`'s paths gain the `weapons.<id>.` prefix. `Viewmodel.paths(data)` already walks
  every numeric leaf and is the authority for "which paths exist", so the tool needs no table —
  which is the property `Viewmodel.paths`' own comment claims and this design relies on.

**The interfaces:**

```luau
Viewmodel.view(data: any, weaponId: string): { [string]: any }   -- was view(data)
Viewmodel.DEFAULT_WEAPON = "shotgun"
Camera.Poses.config(base: any, weaponId: string?): any           -- was config(base)
```

`Camera.Config` keeps publishing **the shotgun's** view at boot, so every existing reader, every
existing spec and `Mode.rightHandOffset`/`leftHandOffset` are unchanged and the default build is the
one that ships. `Camera.Poses.config(Config, id)` recomputes the view for the held weapon.

**One correction to `Poses.config` that this design requires.** Today it returns `base` untouched
whenever `not RunService:IsStudio()` — so outside Studio the rifle's poses would **never apply**. It
becomes: return `base` when `weaponId` is nil or `DEFAULT_WEAPON` **and** there is no override;
otherwise compute and cache per `(raw, weaponId)`. The production cost is one table lookup per frame
against a cache keyed exactly as the existing raw-string cache is. Named in §11 and asserted by
`tests/server/viewmodel_poses.spec.luau` driving `Poses.resolve` with both ids.

### 6.2 The drawn rifle: `ReplicatedStorage.Rifle.Geometry`

`Camera.Viewmodel.buildNewGun` requires `Gun` directly and calls `Gun.pieces(Shotgun.CONFIG)`,
`Gun.layout`, `Gun.sight`, `Gun.muzzle`, `Gun.FOLDER_NAME`. One change makes it weapon-agnostic:

```luau
export type Geometry = {
    pieces: (config) -> { Piece },      -- each piece: name, group, size, offset, colour, meshKey, meshOffset
    layout: (config) -> { barrelLength: number, barrelZ: number, … },
    sight:  (config) -> CFrame,
    muzzle: (config) -> CFrame,
    hinge:  (config) -> CFrame,
    FOLDER_NAME: string,                -- where the server parks this weapon's published meshes
    MESH_SIZE_STUDS: Vector3,
    CYCLE_KIND: string,                 -- "hinge" (shotgun) | "slide" (rifle). Section 8.2
}
Weapons.geometry(id): Geometry?
```

`buildNewGun(config, row)` takes the row, resolves `Weapons.geometry(row.id)`, and is otherwise the
same function: the invisible `Handle` of `row.HANDLE_SIZE` as `PrimaryPart`, one envelope part per
cycle group, a clone per published mesh with that group's **measured box** where the mesh is missing
or not yet downloaded (`Viewmodel.meshReady`), then `Sight` and `Muzzle` attachments. Every one of
those properties is already weapon-independent.

`Rifle.Geometry`'s piece list has **three groups**: `body` (stock, action, trigger — fixed),
`bolt` (the handle and the bolt body — what moves), and `scope` (tube, rings, lens — fixed, drawn as
a separate piece so the lens can carry its own material). The scope tube is in `body`, not `bolt`:
on a Rigby the scope is mounted to the action.

**The map lives in `Weapons` because `Gun` and `Rifle.Geometry` are shared modules.** The *world*
shape map cannot: `Weapon.Shape` is `src/server/Weapon/Shape.luau` and a shared module may not
require a server module. So there are two maps, each on the side that can see its modules:

* `Weapons.geometry(id)` (shared) → `Gun` / `Rifle.Geometry`
* `Weapon.Shapes[id]` (`src/server/Weapon/Shapes.luau`) → `Shape` / `ShapeRifle`

Both are `table.freeze`d **shallowly** over module references, deliberately: `Shotgun.deepFreeze`
recurses into table values and would freeze another module's own table, which is not this module's
to freeze. Said in both headers.

**The world rifle's fallback is three boxes, not the shotgun's ten.** `Hardware.addParts` /
`removeParts` walk `Shape.pieces(config)` — one list, forwards and backwards, which is the invariant
that file's comment states. They become `Hardware.addParts(handle, row, shape)` walking
`shape.pieces(row)`. `ShapeRifle.pieces` is a stock, a barrel and a scope tube: enough that a rifle
whose upload did not load reads as a scoped rifle at thirty studs, and **not** the shotgun's parts
list, which would draw a shotgun in the rifle's place — a wrong gun that measures perfectly, which is
the failure `docs/PROJECT_CONTEXT.md` opens with.

### 6.3 Per-weapon state, and what a switch preserves

`Registry` keys by `player` and has one `forget` (`src/server/Weapon/Registry.luau`;
`Registry:count()` is what the Task 23 defect (c) leak test reads). **Keep that.** What changes is
the stored **value**:

```luau
-- Registry:get(player) was a WeaponState. It becomes:
export type PlayerWeapons = {
    held: WeaponId?,                        -- derived in watchEquipped's sync(); section 5.2
    states: { [WeaponId]: WeaponState },    -- one per weapon in the loadout
}
```

`Registry:forget(player)` therefore still removes everything in one call, `Registry:count()` still
counts players, and the leak assertion in `tests/server/weapon_state.spec.luau` is unchanged. Buckets
stay keyed by `(player, name)`.

**The rule, stated: a switch preserves the other weapon's state.** The rifle you left with a spent
case and an open bolt is open when you come back to it. Reasons: with two Tools nothing is destroyed
on a switch, so "dropped" would need code written to drop it; and a gun that silently reloads itself
while you look away is a lie the player will notice.

Two consequences, both named because they are the whole of what "preserved" costs:

1. **`busyUntil` keeps running while the weapon is holstered.** It is a server-clock deadline, and
   the only alternative is a second clock per weapon. So a bolt cycle in flight **completes in the
   backpack** — which is also the honest answer: the hunter's hands did the work. The sequence
   already survives it: `runReload`'s steps after `Break` check `open` and the reserve and **not**
   `equipped` (`StateMachine.apply`: `Load` requires `open`, `Close` requires `open`).
2. **A switch inside `FIRE_TO_CYCLE` aborts the cycle**, because `Break` *does* require `equipped`.
   The rifle is then left with a spent case and a shut action, and the player presses `R` when they
   come back — `CYCLE` is the same four-step list `R` runs. That is the one rough edge, and the abort
   path that closes a gun it left open already exists (`runReload`'s `"is-open"` recovery, added for
   TASKS.md 24a(a)).

`epoch` stays **per weapon state**, so the cycle thread's `state.epoch ~= epoch` check is unchanged.

---

## 7. The scope view

### 7.1 Where the magnification lives, and the path the number takes

A weapon row carries `scope.aimFovDeg`. **The camera is told a number and never learns what a rifle
is.** The path, each hop named:

```
Weapons.row(id).scope                               (shared data, no writer)
  -> CameraBoot's optics adapter                    src/client/CameraBoot.client.luau
  -> Camera.setOpticsSource({ optics = () -> Optics? })
  -> Camera.update(), once per frame, at the same boundary that already resolves
     Poses.config() and breakSource.state()
  -> Mode.StepInput.aimFovDeg / .sway
  -> Mode.State.aimFovDeg / .scopeSwayDeg
  -> Mode.fovFor(blend, config, state.aimFovDeg)    and Mode.sensitivityScale(thatFov, config)
  -> Rig.apply(cframe, fov)                         THE ONE WRITER of cam.FieldOfView
```

`setOpticsSource` is the **third** injected source on this owner beside `setAimSource` and
`setBreakSource` — the established idiom, not a new mechanism, and the camera still requires no
weapon (`src/client/Camera/init.luau` header). The adapter in `CameraBoot` is where both owners are
known, exactly as the aim source, the muzzle provider and the break source are.

```luau
-- src/client/Camera/init.luau
export type Optics = {
    aimFovDeg: number,
    reticle: Reticle?,                     -- nil: no reticle, ever (the shotgun)
    sway: { ampDeg: number, periodSeconds: number }?,
}
export type OpticsSource = { optics: () -> Optics? }
Camera.setOpticsSource(source: OpticsSource?)
Camera.getOpticsSource(): OpticsSource?
Camera.scope(): Optics?                    -- THE RESOLVED OPTICS FOR THE LAST FRAME, republished as
                                           -- a fact about the VIEW. The Hud reads this and never the
                                           -- weapon table, exactly as it reads isFirstPerson()
```

```luau
-- src/client/Camera/Mode.luau
Mode.fovFor(blend: number, config, aimFovDeg: number?): number
    -- nil -> config.FOV_AIM_DEG, which is the shotgun's 50 and every existing caller's answer
```

Nothing else in the camera changes shape: the sensitivity already derives from the **current blended
FOV** (`Mode.step`'s first lines, `Mode.sensitivityScale`), so at 4x the view turns at 25.0 % of its
hip rate with no new code. The zoom-in time is the existing `AIM_RAISE_SECONDS`.

### 7.2 Who owns the reticle, and what it is

**Owner: `PlayerScripts.Hud`** — rule 3, it is drawn. **The one signal between them is
`Camera.scope()`**, a read, plus the `Camera.Changed` the Hud is already connected to.

```luau
-- src/client/Hud/init.luau
Hud.reticleVisible(mode: string?, optics): boolean      -- PURE, public, like Hud.crosshairVisible
    return optics ~= nil and optics.reticle ~= nil and mode == "Aiming"
Hud.reticle(): Frame?                                   -- for specs
Hud.reticleDegToPx(deg: number, fovDeg: number, viewportY: number): number   -- THE ONE CONVERSION
```

* `Hud.build` creates **one hidden `Reticle` frame**, a sibling of `Crosshair` and `HitMark` (not a
  child: the hit marker is a sibling for exactly this reason — camera design §6.2 item 3), with the
  duplex's parts as children: a ring (`UIStroke` on a square frame with a `UICorner`), four thin
  cross arms, four thick outer posts. UI primitives, **no upload**, which is what the drive report's
  silhouette already is (`docs/design/drive-report.md` §8.2).
* **Sized in degrees, converted once.** Roblox's field of view is **vertical**
  (`Camera.Config.BEAD_CENTRE_TOLERANCE_DEG`'s own comment measures 50/1080 = 0.0463 deg per pixel at
  1920×1080), so `px = deg / fovDeg * viewportY` is exact and scale-free. One site,
  `reticleDegToPx`, which is the rule the Task 19 cone-unit defect bought. This is why the duplex
  stays true at any screen size **and** at any magnification: change `aimFovDeg` from 19.87 to 13.31
  and every element grows by exactly the magnification.
* The geometry is **data**, in `Rifle.CONFIG.scope.reticle` (§12).
* `render(Weapon, CameraSystem)` sets `reticle.Visible = Hud.reticleVisible(CameraSystem.getMode(),
  CameraSystem.scope())` and rebuilds the pixel sizes **only when the FOV or the viewport changed** —
  two numbers compared, so there is no new per-frame work and no second per-frame writer. It is
  driven by the `Camera.Changed` connection the Hud already has, which fires on every mode
  transition, and `Third → Aiming` is the only transition the reticle cares about.
* **The crosshair is untouched and stays false in first person.** `Hud.crosshairVisible` is not
  consulted for the reticle and the reticle is not consulted for the crosshair: two predicates, two
  questions, which is §1.2's rule.

### 7.3 Sway — the camera, not a second writer, and zero in the hip view

**It is a camera-space term, applied inside `Mode.cameraCFrame` exactly as `recoilCamPitchDeg`
already is.** Not the viewmodel's.

Why: the reticle is a flat overlay at screen centre and the shot ray is the camera's own
`LookVector` (`Weapon.Input.onFire` reads `camera.CFrame`). If sway moved only the gun, the reticle
and the point of impact would both stay dead centre and the sway would be decoration the player can
ignore. Moving the **view** makes the reticle still mark the point of impact while the whole sight
picture wanders — which is what a scope does, and it makes the shot genuinely harder.

```luau
-- Mode.State gains, in atRest():
scopeSwayDeg: Vector2,     -- the VIEW's offset this frame, degrees
scopePhase: number,        -- 0..1, the figure-eight's phase
-- Mode.StepInput gains:
sway: { ampDeg: number, periodSeconds: number }?,     -- nil: zero, and the phase does not advance
```

* `Mode.step` advances `scopePhase` by `dt / periodSeconds` (wrapped) and sets
  `scopeSwayDeg = Vector2.new(amp * 0.5 * sin(2*phase*2π), amp * sin(phase*2π)) * Mode.ease(blend)`
  — vertical at 1×, horizontal at 0.5×, the figure-eight sources 5 and 6 describe.
* **Scaled by `Mode.ease(state.blend)`, so it is exactly zero in the hip view.** That is both true to
  life (you cannot see wobble at 1×) and the reason sway can never interfere with a hip-fire harness
  scenario or with the shotgun at all.
* `Mode.cameraCFrame` adds it to the view angles beside the recoil term, inside the same
  `math.clamp(..., PITCH_MIN_DEG, PITCH_MAX_DEG)`, so a sway at the top of the look range cannot
  gimbal the camera. `state.pitchDeg`/`yawDeg` — the player's aim — are untouched.
* **Switched off for a spec by parameter**: `input.sway = nil`, or a row with `ampDeg = 0`. The flag
  is not the switch. `Camera.Poses.holdState` additionally zeroes `scopeSwayDeg` and `scopePhase`, so
  `tools/pose.py compare` photographs a still gun (it already freezes `blend` and `openTilt` for the
  same reason).
* `Mode.viewmodelOffset`'s existing `swayDeg`/`bobStuds` terms are **left at their exact rest and
  untouched**. Two sway fields, and the distinction is the point: `swayDeg` is "the gun wanders in
  the frame" (cosmetic, still unmoved, S4's) and `scopeSwayDeg` is "the view wanders" (ballistic).
  Written in `Mode`'s header.

### 7.4 Recoil and the scope

**The scope inherits the recoil that exists, and the reticle does not move with it.**

`Mode.kick` adds to three springs; `recoilCamPitchDeg` lifts the **view** and decays to exactly zero
(`RECOIL_REST_EPSILON`), and `recoilGunPitchDeg`/`recoilGunBackStuds` turn the gun about its own
grip. Since the reticle is a screen overlay at centre and the view is what moves, the sight picture
jumps off the animal and settles back onto the point it left — which is what a scope does. The
reticle itself stays at screen centre, because it marks where the shot goes and the shot goes where
the camera points.

The rifle's row carries its own `fire` block in `poses.json` (`weapons.rifle.fire`), so a rifle can
kick harder than the shotgun without touching the shotgun's spring. The ceilings
(`maxGunPitchDeg`, `maxCamPitchDeg`) matter less for a one-shot weapon than for a doublet, but they
stay: a cycle can land a second kick inside the first one's settle.

---

## 8. The bolt

### 8.1 Which state machine: the same one, with the sequence as data

**No new states.** A bolt cycle is "open, eject, feed, close" with one chamber, which is exactly the
five primitives `StateMachine.apply` already has. What is per weapon is **the sequence and the
timings**, and they move into the row as `CYCLE` (§4.2) — the list `Weapon.runReload` builds today
from `CONFIG.RELOAD_*`, read from data instead of built in code.

**The one interface change the reducer needs:**

```luau
-- before: StateMachine.apply(state, action, now)        and `local config = Shotgun.CONFIG` INSIDE it
-- after:  StateMachine.apply(state, action, now, row)
```

`src/server/Weapon/StateMachine.luau` reads `Shotgun.CONFIG` at the top of `apply` for
`BARREL_DELAY` and `RELOAD_*`. With two weapons that is a rifle timed like a shotgun, silently. The
row is passed in — no default, so every caller is forced to say which weapon it means, and the
callers are `Weapon.onFireRequest`, `Weapon.runCycle`, `Weapon.onActionRequest` and the specs.
`StateMachine.initial(config)` already takes a config and becomes `initial(row)`.

The rifle's legal transitions, with `BARRELS = 1`:

| from | action | to | why |
|---|---|---|---|
| ready (`barrels = {Live}`, `open = false`) | `Fire` | spent (`{Spent}`), busy for `BARREL_DELAY` | `nextLive` finds no live barrel and leaves `selected` at 1 — the existing "an empty gun does not shuffle its selection" rule |
| spent | `Break` | cycling (`open = true`, `{Empty}`), busy `CYCLE[1].wait` | the owner runs it, `AUTO_CYCLE` |
| cycling | `Load` | fed (`{Live}`), busy `CYCLE[2].wait` | refused `"no-reserve"` on an empty pocket, which `runCycle` walks past — the one rejection it is allowed to |
| fed | `Close` | ready, busy `CYCLE[3].wait` | |
| anything | `Fire` while `open` | **refused `"is-open"`** | §8.3 |
| anything | `SelectAmmo` | **refused `"bad-request"`** at the wire | one ammo kind (§4.4) |

**The cycle is automatic.** `row.AUTO_CYCLE = true`: on an accepted `Fire` the owner spawns
`runCycle(player, id, epoch)` after `BARREL_DELAY`. Reason: with one chamber, a manual cycle means
the player presses `R` after **every** shot, which is a reload and not a bolt. It is a dial, not a
belief: `AUTO_CYCLE = false` makes `R` the cycle, both branches are reachable by parameter, and the
spec drives both. Karen's to change (§17).

**Can the player aim while cycling? Yes, and the scope stays up.** Aiming is the aim button plus
`equipped` (`CameraBoot`'s aim source) and is not gated on weapon state — a hunter does not come off
the gun to work the bolt. §8.2 is what makes that safe to draw.

`runReload` becomes `runCycle(player, id, epoch)` and is the **one** sequence runner for both
weapons: it walks `row.CYCLE`, keeps the `"no-reserve"` exception, keeps the `"is-open"` recovery
that closes a gun it left open, and keeps the trailing publish that clears the Hud's `R`. One
function, two weapons, three fewer ways to be wrong than two functions.

### 8.2 The drawn handle: one pose plus a parameter

**Data shape: one pose plus a parameter** — not a named pose per bolt phase. `Mode.State.openTilt`
is already a 0..1 blend driven by the replica's `open` through the injected break source, and
`Mode.breakAngleDeg(state, config)` is already the one site that turns it into a drawn amount. The
rifle reuses both.

```json
"weapons": { "rifle": { "cycle": {
    "openSeconds": 0.18, "closeSeconds": 0.14,
    "liftDeg": 60, "drawStuds": 0.42, "liftFraction": 0.35,
    "gun":  { "pos": {…}, "rot": {…} },     // EQUAL TO carry.gun: see below
    "right": {…}, "left": {…},              // the hand that works the bolt
    "shells": { "ejectSeconds": …, "ejectRiseStuds": … }
} } }
```

* `Mode.cycleProgress(state, config): number` replaces the shotgun-only `breakAngleDeg` as the one
  site, and `Viewmodel.hinge(gunCFrame, state, config, geometry)` branches on
  `geometry.CYCLE_KIND`:
  * `"hinge"` (shotgun): rotate the `Barrels` group about `BREAK_HINGE_STUDS` by
    `progress * BREAK_OPEN_DEG` — today's code, unchanged.
  * `"slide"` (rifle): a **two-segment** map of the same `progress` — `0 → liftFraction` rotates the
    `Bolt` group by `liftDeg` about the bolt axis, `liftFraction → 1` translates it back by
    `drawStuds`. `Mode.segmentAt` already does two-segment maps for the raise's keyframes and is
    exported; reuse it rather than writing a second one.
* **The whole-gun pose does not move for the rifle**, and the data is what makes that true:
  `Mode.viewmodelOffset` lerps the pose toward `Mode.breakOffset(config)` by `openTilt`, and the
  rifle's `cycle.gun` is seeded **equal to its `carry.gun`** — a lerp between equal numbers is those
  numbers, the trick task 98 used to ship a no-pixel-change task. So the gun stays shouldered and
  only the bolt moves, with no new branch in the composition. `tests/server/rifle.spec.luau` asserts
  the two are equal as seeded, and nothing stops the Director from making them differ later.
* **Owner that plays it: `PlayerScripts.Camera.Viewmodel`**, the one writer of the first-person
  model. The server owns the clock (`CYCLE`'s waits) and the replica carries `open`; the camera draws
  what it is told. No new owner, no new remote.
* **If the Rigby's glTF has no separable bolt node**, the `bolt` group is drawn as its own measured
  box in `Rifle.Geometry`'s fallback — a short dark cylinder and a knob — which is the same
  "a group whose mesh did not load is drawn as its own box" rule `Gun.pieces` already lives by. The
  bolt still moves. Named in §16 as unverified, and it is not a blocker because the fallback is the
  mechanism that already exists.
* The ejected case reuses `Viewmodel.shells` with the rifle's own `cycle.shells` numbers; its
  `FreshShell` feed is not drawn (a bolt feeds from a hidden magazine), so `feedSeconds` is absent
  from the rifle's block and `Viewmodel.validate` does not require it for `BARRELS == 1`.

### 8.3 A second trigger pull during the cycle: refused, and the rule lives in one place

**Refused, not queued and not ignored-in-silence.** The rule is a **property of the reducer** and not
a flag, which is the shotgun's own uninterruptible-reload argument applied again:
`StateMachine.apply`'s `Fire` branch requires `open == false` and every action except `SelectAmmo`
is refused while `now < state.busyUntil`. So from the instant `Break` lands until `Close` completes,
every `Fire` is refused `"is-open"`; inside `BARREL_DELAY`, `"busy"`.

One decision in one place: `StateMachine.apply`. `onFireRequest` publishes the state and returns the
reason, which is the contract it already has (Task 80), and `Weapon.stats()` counts nothing new. The
client needs no prediction and no queue — the Hud's `R` marker is already driven by
`snapshot.busyFor`.

---

## 9. The report: where the weapon name enters

**It enters at `Weapon.Hits.group`, which is the one place a `HitReport` is constructed.**

```luau
-- src/server/Weapon/Hits.luau
-- before: Hits.group(shooter, impacts, ammo: string, now: number): { HitReport }
-- after:  Hits.group(shooter, impacts, ammo: string, now: number, weapon: string): { HitReport }
--         each report gains  weapon = weapon
-- src/shared/Shotgun/init.luau: HitReport gains  weapon: string
```

Why there and nowhere else: the weapon is a property of **the shot**, exactly as `ammo` is, and
`group` is the only constructor of the type. `HitLog` then **copies** it, as it copies `zone`, and
derives nothing:

```luau
-- src/server/HitLog/init.luau, in recordHit's dot:   weapon = report.weapon
-- src/shared/Report/init.luau:   WireDot gains  weapon: string?
--                                Event   gains  weapon: string?
-- HitLog.recordDown's broadcast: weapon = animal.dots[fatalIndex].weapon
```

`nil` is a legal value on the wire and means "a record from before this task", which keeps the
existing `hitlog.spec` fixtures valid.

**What the panel does with it**, keeping `docs/design/drive-report.md`'s owner boundaries (the panel
draws what arrived and computes nothing; `HitLog.Shape` does every count and placement on the
server):

| View | Change |
|---|---|
| the kill line in the feed (`Hud.killLineText`) | one column: `KAREN   MALE BOAR   chest   42 m   .416`. `nil` prints nothing, not `NIL` — the rule that function already follows for `animalKind` |
| detail view, the animal's row (§8.2 of that design) | the best/fatal dot's weapon word, after the distance. One `string.format` column |
| detail view, the dots | unchanged. A dot is a position, and a second glyph per gun is a picture nobody can read |
| list view (per hunter) | **unchanged.** It is per hunter, not per shot. A per-weapon breakdown is a column Karen has not asked for (§17, Director) |

The word printed is `row.label`, resolved in the panel from `Weapons.row(dot.weapon)` — so the wire
carries the id and the screen carries the word, which is the same split as `AMMO_LABEL` (§4.4).

---

## 10. What must not change — the reviewer's checklist

Each one is a grep or a spec, not a promise.

| Must not change | How a reviewer checks it |
|---|---|
| The shotgun's ballistics | `tests/server/rifle.spec.luau` asserts `Weapons.ROWS.shotgun` field-by-field against `Shotgun.CONFIG`; `git diff` on `src/shared/Shotgun/init.luau` touches only the type block and `EQUIP_RATE_LIMIT` |
| The shotgun's poses | `tests/server/viewmodel_poses.spec.luau` asserts `data.weapons.shotgun` equals the archived v3 top level field by field |
| The safety arc | `SAFETY_ARC_HALF_DEG` is read from `Shotgun.CONFIG` in `onFireRequest` and appears in **no** row (§4.3). `tests/server/rifle.spec.luau` asserts no row carries that key |
| The penalty | `src/server/Match/` is not in this task's diff at all. `Weapon.SafetyViolated`'s four arguments are unchanged |
| The boar | `src/server/Boar/` is not in this task's diff. `Runtime:takeHit`'s `Hit` gains nothing; `Wound.damageFor` is untouched (§4.4) |
| The drive | `src/shared/Drive/`, `src/client/Match/`, `src/server/Match/` and `MatchBoot` are not in the diff, so `TWO_PLAYER_PATHS` is not reached and `test2` is N/A |
| `Camera.Rig` as the one writer of the camera | `Rig.apply` is the only assignment to `cam.CFrame`/`cam.FieldOfView` in `src/`; `Camera.stats().foreignCameraWrites == 0` after the scoped client case (§13.2) |
| The world gun every other player sees | `Hardware` is still the only writer of Tool Instances; the viewmodel still never writes the Tool |

---

## 11. Every interface that changes, as before → after

| File / symbol | Before | After |
|---|---|---|
| `src/shared/Shotgun/init.luau` `HitReport` | no weapon | `weapon: string` |
| `…` `WeaponSnapshot` | — | `weapon: string?` (the readout's state route, §5.2) |
| `…` `CONFIG` | — | `+ EQUIP_RATE_LIMIT = 8` |
| `src/server/Weapon/StateMachine.luau` `apply` | `(state, action, now)`, `Shotgun.CONFIG` read inside | `(state, action, now, row)` |
| `…` `initial` | `initial(config)` | `initial(row)` |
| `src/server/Weapon/Validator.luau` `checkRequest` | `(kind, ammo)` | `(kind, ammo, row)`; `SelectAmmo` checked against `row.AMMO_KINDS` |
| `src/server/Weapon/Hits.luau` `group` | `(shooter, impacts, ammo, now)` | `+ weapon` |
| `src/server/Weapon/Hardware.luau` `TOOL_NAME`, `ASSET_KEY`, `MODEL_NAME` | literals | `row.toolName`, `row.ASSET_KEYS`; `MODEL_NAME`/`BARRELS_NAME` stay (they are names *inside* a Handle) |
| `…` `build`, `addMesh`, `addParts`, `removeParts`, `addBarrels`, `setSight`, `upgrade`, `wearsMesh` | `(…, config)` | `(…, row, shape)`; `Hardware.Shapes[id]` resolves the parts list |
| `…` `toolsOf(player)` | name `== "Shotgun"` | name in `Weapons.toolNames()` |
| `…` `equipStats` | one table | unchanged (totals); `Weapon.stats` adds `grantedByWeapon` |
| `src/server/Weapon/init.luau` `grant`, `revoke` | `(player)` | `grant(player, id)`; `revoke(player, id?)` — **nil still means every weapon**, so `Match`'s existing `revoke(player)` on a tie is unchanged |
| `…` `refreshArming`, `armingAction` | one Tool | loops `Weapons.loadout()`; `armingAction(allowed, holding)` stays pure and per weapon |
| `…` `runReload` | shotgun's four steps from CONFIG | `runCycle(player, id, epoch)` over `row.CYCLE` |
| `…` `CONFIG` at file scope | `local CONFIG = Shotgun.CONFIG` | **removed.** Row per call from `Weapon.heldId`; system numbers read from `Shotgun.CONFIG` at their use site |
| `…` | — | `+ Weapon.heldId(player)`, `+ Weapon.Weapons` (exported for specs) |
| `src/client/Weapon/Input.luau` `watchTool` | `tool.Name ~= "Shotgun"` | `not Weapons.isToolName(tool.Name)` |
| `src/client/Camera/Mode.luau` `fovFor` | `(blend, config)` | `(blend, config, aimFovDeg?)` |
| `…` `State`, `StepInput` | — | `+ aimFovDeg`, `+ scopeSwayDeg`, `+ scopePhase`; input `+ aimFovDeg`, `+ sway` |
| `…` `breakAngleDeg` | shotgun degrees | `cycleProgress(state, config)`; `breakAngleDeg` kept as `progress * BREAK_OPEN_DEG` for the hinge path |
| `src/client/Camera/Poses.luau` `config` | `(base)`, `base` outside Studio | `(base, weaponId?)`, cached per `(raw, weaponId)` and resolved in production too |
| `src/shared/Viewmodel/init.luau` `view`, `validate`, `paths` | one pose set | `view(data, weaponId)`; `validate` per weapon, requiring `reload` or `cycle` by `BARRELS` |
| `src/client/Camera/Viewmodel.luau` `buildNewGun`, `hinge`, `update` | `Gun` required directly | `(config, row)`; geometry from `Weapons.geometry(row.id)`; `setSource` returns the **Tool** |
| `src/client/Camera/init.luau` | — | `+ setOpticsSource`, `+ getOpticsSource`, `+ scope()` |
| `src/client/Hud/init.luau` | — | `+ reticleVisible`, `+ reticle()`, `+ reticleDegToPx`; `readoutFor(state, row)` |
| `src/server/HitLog/init.luau` `recordHit` | dot has no weapon | `weapon = report.weapon` |
| `src/shared/Report/init.luau` | — | `WireDot.weapon`, `Event.weapon` |
| `src/shared/Flags/init.luau` | 7 rows | `+ RIFLE` (§14); `MAX_FLAGS` is 12, so there is room |
| `src/serverstorage/Assets/init.luau` | — | new rows for the rifle's keys, appended and versioned, never edited |
| `tools/studio_mcp.py` | — | `BLAST_RADIUS += ("src/shared/Rifle/", "gun"), ("src/shared/Weapons/", "weapon")`; `SCOPE_SPECS["weapon"] += rifle specs` (§13.5) |

---

## 12. Numeric targets

Every number from the research note's §5 carries its label; everything else is **mine** and is a dial
in data.

| Quantity | Value | Where it lives | Source |
|---|---|---|---|
| Magnification | **4x**, dialable to 6x | `Rifle.CONFIG.scope.magnification` | note §5 |
| Aim FOV | **19.87 deg** (6x = 13.31) | `scope.aimFovDeg` | note §5, arithmetic |
| Mouse sensitivity scoped | **25.0 %** of hip | derived, `Mode.sensitivityScale` | note §5 |
| Zoom time | **0.20 s** up, the shotgun's `AIM_RAISE_SECONDS` | `poses.json weapons.rifle.raise` | note §5 |
| Effective range | **450 studs** (126 m) | `row.RANGE_STUDS.Slug` | note §5 |
| Projectiles | **1** | `row.PELLETS.Slug` | note §5 |
| Spread | **0.05 deg full cone** | `row.SPREAD_FULL_DEG.Slug` | **mine.** 1 MOA = 0.0167 deg; a hunting rifle is 1–2 MOA, so 0.05 deg full is ~1.5 MOA, which is 0.39 studs across at 450 studs — inside a chest zone (0.236–0.545 of a 5.5-stud animal, drive-report §8.2) |
| Chambers | **1** | `row.BARRELS` | note §5 |
| Reserve | **10 rounds** | `row.START_RESERVE.Slug` | **mine.** A ten-minute drive with one shot per animal; 24 (the shotgun's) is a box nobody empties |
| `BARREL_DELAY` | **0.12 s** | `row.BARREL_DELAY` | **mine.** The trigger's own dwell before the cycle starts; shorter than the shotgun's 0.25 because there is no second barrel to pick |
| Bolt cycle total | **0.90 s** = Break 0.30 + Load 0.35 + Close 0.25 | `row.CYCLE`, `CYCLE_TOTAL` | note §5 (0.9 s); the split is **mine** |
| Drawn bolt lift / draw | **60 deg** / **0.42 studs**, lift over the first **0.35** of the progress | `poses.json weapons.rifle.cycle` | **mine**, and all three are what a screenshot will move |
| Drawn open / close | **0.18 s / 0.14 s** | `cycle.openSeconds`/`closeSeconds` | **mine.** Both shorter than the server's own 0.30 s and 0.25 s steps, so the drawn motion always finishes before the state that started it ends — the rule `viewmodel_poses.spec` already asserts for the shotgun, extended to the rifle |
| Sway amplitude / period | **0.25 deg**, **4.0 s**, figure-eight, vertical 1× and horizontal 0.5× | `scope.sway` | note §5. 0.25 deg at 150 studs is 0.65 studs of wander |
| Reticle: ring outer / thick | **4.0 deg** / **0.10 deg** | `scope.reticle` | **mine.** 4.0 deg at FOV 19.87 is 20 % of the screen height — a ring you look through, not at |
| Reticle: cross gap / arm / thick | **0.35 / 1.30 / 0.055 deg** | `scope.reticle` | **mine.** 0.055 deg is 1.2 px at 1080p and FOV 19.87: a hair, which is what a thin crosshair is |
| Reticle: post arm / thick | **1.50 / 0.22 deg** | `scope.reticle` | **mine.** The duplex's thick outer posts, four to five times the thin line |
| `EQUIP_RATE_LIMIT` | **8** publishes/s | `Shotgun.CONFIG` | **mine**, §5.4 |
| Rifle recoil | gun pitch **6.0 deg**, back **0.20 studs**, camera pitch **1.6 deg**, 3.6 Hz, damping 1.0 | `poses.json weapons.rifle.fire` | **mine.** Each ~1.5× the shotgun's (4.0 / 0.14 / 1.1): a centrefire rifle at the cheek, and "a bit" is still Karen's whole brief |
| `HANDLE_SIZE` | **(0.4, 0.5, 4.1)** studs | `row.HANDLE_SIZE` | **mine.** 4.1 studs = 1.15 m, a 24-inch sporter; the shotgun's is 4.4 |
| Scoped-FOV read-back tolerance | **1e-3 deg** | the client spec | the tolerance `Rig.apply`'s own foreign-write detector uses. §13.2 case 2 |

---

## 13. How it is tested

### 13.1 Server specs — pure, no client

**`tests/server/rifle.spec.luau`** (new):

1. **The table.** `Weapons.ids()` is `{"shotgun","rifle"}`; `Weapons.row("nope")` is nil;
   `Weapons.loadoutFor(false)` is `{"shotgun"}` and `loadoutFor(true)` is both;
   `Weapons.ROWS` is frozen and a nested write errors (the Task 23 defect (b) assertion).
2. **The shotgun's row is its own numbers.** Field by field against `Shotgun.CONFIG`, including
   `CYCLE` against the four `RELOAD_*` and `CYCLE_TOTAL == RELOAD_TOTAL == 2.0`.
3. **No row carries a system rule.** `SAFETY_ARC_HALF_DEG`, `CAMERA_ORIGIN_TOLERANCE`,
   `FIRE_RATE_LIMIT`, `shouldArm` are absent from every row (§4.3).
4. **The reducer with a row.** `apply` with the rifle's row: `Fire` from ready → `{Spent}`,
   `busyUntil == now + 0.12`; a second `Fire` inside it → `"busy"`; `Break` → `open`, `{Empty}`;
   `Fire` while open → `"is-open"` (§8.3); `Load` with an empty pocket → `"no-reserve"`;
   `Close` → ready. `CYCLE_TOTAL` equals the sum of its waits.
5. **The reducer with the shotgun's row is bit-for-bit what it was.** Every existing
   `weapon_state.spec` expectation re-asserted through the new signature.
6. **`SelectAmmo` on one ammo kind.** `Validator.checkRequest("SelectAmmo", "Buck", rifleRow)` is
   `(false, "bad-request")`; the same call with the shotgun's row is true.
7. **Geometry and shape maps resolve.** `Weapons.geometry(id)` and `Weapon.Shapes[id]` are non-nil
   for every id, and each answers a non-empty `pieces(row)`; `ShapeRifle.pieces` is **not**
   `Shape.pieces` (the wrong-gun fallback, §6.2).
8. **The drawn bolt as data.** `weapons.rifle.cycle.gun` equals `weapons.rifle.carry.gun`
   (the identity-lerp claim, §8.2); `cycle.openSeconds < row.CYCLE[1].wait` and
   `cycle.closeSeconds < row.CYCLE[#CYCLE].wait`.
9. **The report carries the weapon.** `Hits.group(shooter, impacts, "Slug", now, "rifle")` puts
   `weapon = "rifle"` on every report, one report per target.
10. **The scope's arithmetic.** `tan(rad(70)/2) / tan(rad(aimFovDeg)/2)` equals
    `scope.magnification` to 1e-3, so a hand-typed FOV that does not match the stated magnification
    fails the harness.

**Additions to existing specs:**

* `tests/server/camera_mode.spec.luau`: `fovFor(1, config, 19.87) == 19.87` and
  `fovFor(1, config, nil) == 50`; `sensitivityScale(19.87, config)` is 0.250 ± 1e-3; sway is exactly
  `Vector2.zero` at `blend == 0` and non-zero at `blend == 1`; sway's amplitude never exceeds
  `ampDeg` over 10,000 steps; `input.sway == nil` leaves `scopePhase` at 0; the view pitch stays
  inside `PITCH_MIN_DEG`/`PITCH_MAX_DEG` with sway and recoil both at full; `state.pitchDeg` is
  untouched by sway; `cycleProgress` reaches exactly 0 and exactly 1 at 240, 60 and 20 fps.
* `tests/server/viewmodel_poses.spec.luau`: `version == 4`; `data.weapons.shotgun` equals the
  archived v3 top level; `validate` refuses a rifle block with `reload` and one with both
  `reload` and `cycle`; `Poses.resolve` with each weapon id; `view(data, "rifle")` publishes the same
  flat name set as `view(data, "shotgun")` (so no reader can get a nil).
* `tests/server/weapon_state.spec.luau`: `Registry:forget(player)` still drops **both** weapons'
  states and `Registry:count()` returns to its prior value (defect (c), unchanged); a switch leaves
  the other weapon's `WeaponState` identical by value.
* `tests/server/hitlog.spec.luau`: a report with `weapon = "rifle"` produces a dot with
  `weapon = "rifle"`; `recordDown`'s broadcast carries the fatal dot's weapon; a report with no
  weapon produces `nil` and nothing errors.

### 13.2 Client spec — `tests/client/rifle_client.spec.luau` (new), the real camera, the real client

1. **Two Tools, both watched.** With the flag off and the rifle granted by parameter, the player's
   Backpack plus character hold exactly one `Shotgun` and one `Rifle`;
   `Weapon.Input.watchedTools() <= #Weapons.loadout()` across a respawn; the shotgun is the one in
   the character (`AUTO_EQUIP` puts the primary in the hand).
2. **The scoped FOV is really on the screen.** With the rifle equipped (through the Humanoid — see
   §13.4) and the aim source held, wait for `Camera.getBlend() == 1`, then read
   `workspace.CurrentCamera.FieldOfView` and assert it is within **1e-3** of `scope.aimFovDeg`, and
   `Camera.stats().foreignCameraWrites == 0`. This is the case that measures what the research
   note said to measure: *the engine does not clamp 19.87* (and the same case at 13.31 proves 6x is
   reachable before anybody ships it).
3. **The reticle exists, is visible only while scoped, and is the right size.**
   `Hud.reticle()` is non-nil; `Visible` is false in the hip view and true while `Aiming`; the ring's
   `AbsoluteSize.Y` equals `reticleDegToPx(ringOuterDeg, liveFov, viewport.Y)` ± 1 px, measured from
   the **live viewport** (a Studio Play window is far from 1080 px, and a fixed pixel count there
   would be a looser claim — the method `BEAD_CENTRE_TOLERANCE_DEG`'s client case already uses).
   Visible-up-the-ancestors, not just `.Visible` on the frame: a visibility audit that ignored parent
   visibility certified a blank screen twice (`docs/PROJECT_CONTEXT.md`).
4. **The drawn gun follows the Instance and the readout follows the state (§5.2).** After the switch
   settles: the Tool in the character has `DrivenHunt.Weapon == "rifle"`,
   `Camera.Viewmodel.stats().rebuilds` has increased, and `Weapon.get().weapon == "rifle"` — the two
   routes agree.
5. **No crosshair, ever.** `Hud.isCrosshairVisible()` is false with the rifle in hand, scoped and
   unscoped (Karen's rule).
6. **The bolt moves.** Drive a shot through the real path (§13.3), then sample
   `Camera.stats().cycleProgress` over the cycle window: it leaves 0, reaches 1 and returns to
   exactly 0 (`Camera.stats()` gains that number beside `breakAngleDeg`).
7. **A second trigger pull during the cycle changes nothing.** `Weapon.onFireRequest` — reachable by
   parameter since Task 80, which is the only sound way to assert a refusal — returns `"is-open"` and
   the state's `barrels` is unchanged.
8. **Sway is zero in the hip view.** `Camera.getState().scopeSwayDeg == Vector2.zero` while
   `blend == 0`, with the rifle in hand.

Additions to `tests/client/weapon_client.spec.luau`: its `"Shotgun"` literals (lines around
`watchTool`'s filter case and the cue) read `Weapons.toolNames()`; the existing two-Tool pruning case
is re-asserted with a **live** second Tool present.

### 13.3 Harness input — the player's path (rule 6)

`tests/client/input_scenarios.txt` gains one scenario. The format's rules apply: **it must begin with
a `moveTo`**, because `scenario_batches` resets `last_xy` per scenario and StudioMCP refuses a button
action with no established position (shotgun design §2.3 item 2).

```
rifle-scope: moveTo 400 300 | key 2 | wait 0.6 | mouseDown 2 | wait 0.4 | mouseDown 1 | wait 1.2 | mouseUp 1 | mouseUp 2
```

and the client spec asserts over what `ContextActionService`/`UserInputService` delivered plus the
camera's own history: an `Aiming` entry, an FOV at `aimFovDeg`, a `recoilKicks` increase and a
`cycleProgress` excursion.

**Known gap, stated rather than assumed.** `1`/`2` are the **stock Backpack's CoreGui** bindings, and
whether a StudioMCP-replayed `key 2` reaches CoreGui at all **cannot be verified from this session**
(§16). If it does not, the scenario proves the aim and the shot and **not** the switch, and the switch
is equipped from the spec through `Humanoid:EquipTool` — which is a test-only path and therefore
**not** evidence about the player's path. In that case the switch is a **Karen playtest item** and
the request must say so, not paper over it. That is rule 6 and rule 8: a harness fault is a bug and
gets reported, and what could not be verified is said.

### 13.4 Screenshots — rule 5, required, inspected

`python tools/studio_mcp.py capture <name>`, each one looked at before any claim about it:

| name | what must be in it |
|---|---|
| `t140-rifle-carry` | the rifle in the hip view: the gun low and right, the scope visible, **no crosshair, no reticle** |
| `t140-rifle-scoped` | the scoped view: the duplex centred, the ring not clipping the screen edge, the boar inside the ring at 150 studs |
| `t140-bolt-mid` | the bolt lifted and drawn, with the gun still shouldered (§8.2's identity-lerp claim, as a picture) |
| `t140-hotbar` | the stock hotbar with two slots, so Karen can say whether she wants it on screen (§17) |
| `t140-report-weapon` | the detail view with the weapon column filled |

### 13.5 Two harness tables that **will fail CI** if they are not updated

`tools/studio_mcp.py selftest` **fails if a spec file belongs to no scope** and runs in CI. So the
two new spec files must be added to `SCOPE_SPECS["weapon"]`, and `BLAST_RADIUS` gains
`("src/shared/Rifle/", "gun")` and `("src/shared/Weapons/", "weapon")`. Without the `SCOPE_SPECS`
entries the build is red; without the `BLAST_RADIUS` rows it is merely slower (an unmapped `src/`
path resolves to `all`, which is the safe direction by design).

### 13.6 The gate

**One player only.** Nothing in this task's diff touches `TWO_PLAYER_PATHS`
(`src/server/Match/`, `MatchBoot`, `src/client/Match/`, `src/shared/Drive/`, `tests/client/Role.luau`
and their specs), so `test2` is **N/A with that as the reason** — the Director's 2026-10-03 decision
and Karen's *"we dont need 2 player test now we just working on weapon and animal next"*. The
one-player `[harness] PASS … scope=all` line is required for the PR as always.

---

## 14. The flag

```luau
RIFLE = {
    default = false,                       -- born OFF
    owner = "ReplicatedStorage.Weapons",   -- the module that READS it, at Weapons.loadout()
    born = "2026-10-09 task 140",
    expires = "2026-10-30",                -- 21 days, the ceiling in feature-flags.md section 12
    why = "A bolt rifle with a 4x scope in hotbar slot 2. OFF carries the shotgun alone, as before.",
}
```

**One boundary read, and both states reachable by parameter.** `Weapons.loadout()` is the only
`Flags.isOn("RIFLE")` call in the task; `Weapons.loadoutFor(rifleOn: boolean)` is pure and is what
every spec calls, and `Weapon.refreshArming` takes the loadout. That is the only permitted shape
(`CLAUDE.md`, "Feature flags"), and it is why the rifle is tested from round one with the flag at OFF.

**Why a flag and not "it is not in the hotbar yet".** Everything in §11 is code the **shotgun** also
runs through — the reducer's new argument, the row, the per-weapon state, poses at v4, the report's
weapon field. The flag is what lets all of that land dark while Karen keeps playing the gun she
approved on 2026-10-09, and the shotgun's existing specs are what prove the refactor did not move it.
What the flag gates is exactly one thing: **whether the rifle is granted.**

`MAX_FLAGS` is 12 and seven rows exist, so there is room.

---

## 15. Rows for `GAME_DESIGN.md`

Three new rows and three amendments; the Builder pastes them in the same commit (rule: the owners
table mirrors the designs).

1. **New** — *The weapon table (which weapons exist, their numbers, the loadout)*: owner
   **nobody at run time**; frozen data, `src/shared/Weapons/init.luau`, plus
   `src/shared/Rifle/`. The one reader of the `RIFLE` flag. Design: this file.
2. **New** — *The rifle's first-person geometry*: `src/shared/Rifle/Geometry.luau`, pure data;
   `PlayerScripts.Camera.Viewmodel` is the only thing that builds it. Beside the existing
   `src/shared/Gun/` row, which stays the **shotgun's**.
3. **New** — *The scope's optics as the view sees them*: writer **`PlayerScripts.Camera`**
   (`Camera.scope()`), source `Weapons.row(id).scope` through `CameraBoot`'s adapter;
   `Camera.Rig` remains the one writer of `FieldOfView`. The **Hud** draws the reticle and reads
   `Camera.scope()`, never the weapon table — the same shape as `Camera.isFirstPerson()`.
4. **Amend** the Weapon server row: "every granted `Tool`" becomes "**every granted `Tool`, one per
   weapon in the loadout**"; `Weapon.heldId(player)` is the one answer to which weapon is in the
   hand, derived from the Tool's `Parent`.
5. **Amend** the pose-data row: **version 4**, one pose set per weapon under `weapons.<id>`, and
   `Viewmodel.view(data, weaponId)`.
6. **Amend** the UI row: the Hud also draws the **scope reticle**, `Hud.reticleVisible` is a pure
   public predicate, and the reticle is a sibling of the crosshair and the hit marker, not a child.

---

## 16. What I could not verify (rule 8)

1. **Whether a StudioMCP-replayed `key 2` reaches the stock Backpack's CoreGui binding.** No Studio
   in this session. §13.3 says what happens in each case and refuses to call the fallback evidence
   about the player's path.
2. **Whether the Rigby glTF has a separable bolt-handle node.** The research note lists twelve mesh
   nodes (`Wood`, `Barrel`, `Midden1`, `Midden2`, `Circle`, `Vijsjes`, `Trigger`, `Safety`,
   `TriggerHandle`, `Scope`, `ScopeKnop`, `Lens`) and **none of them is obviously a bolt handle**.
   `TriggerHandle` and the two `Midden*` are candidates and only `tools/gltf_split.py probe` can say.
   §8.2's fallback — the bolt group drawn as its own measured box — is why this is not a blocker, and
   it is the same mechanism `Gun.pieces` already uses for a mesh that did not load.
3. **The engine's minimum `FieldOfView`.** Roblox's own `Camera` page states no range (note,
   source 2). 19.87 and 13.31 are far from any plausible clamp, and §13.2 case 2 measures it rather
   than assuming — which matters because `Rig.apply`'s foreign-write detector compares the FOV it
   read back to 1e-3 and a clamp would count the engine as a second writer every frame.
4. **Whether the rifle is playable at all without a world mesh.** `ShapeRifle`'s three boxes are a
   design choice I cannot look at. The screenshot in §13.4 is the check.
5. **Whether 0.25 deg of sway is felt at 4x.** Only Karen can say; §17.
6. **Whether two Tools on the hotbar is what Karen wants on screen.** The stock Backpack bar is
   already visible in her sessions (nothing disables `CoreGuiType.Backpack`), so this is a second
   slot on a bar she has played with — but she has not been asked. §17.

---

## 17. Open decisions

### Karen (feel) — none of these blocks building; each is a dial in data

A. **4x or 6x.** Ships at 4x (`aimFovDeg = 19.87`); 6x is `13.31` and one number.
B. **Sway: 0.25 deg at 4 s, or none.** `ampDeg = 0` turns it off entirely and the spec drives both.
C. **The bolt cycles automatically after each shot.** `AUTO_CYCLE = false` makes `R` the cycle.
D. **The stock two-slot hotbar on screen**, or should the Hud draw its own weapon indicator and the
   bar be turned off (`SetCoreGuiEnabled(Backpack, false)`, which the Hud already owns the one call
   for)? If the bar goes, `1`/`2` stop working and the switch needs its own binding and its own
   remote — so this one changes the design and is worth asking before the rifle ships, not after.
E. **Hip-firing the rifle is blind.** Karen's standing rule is no crosshair at any time, and the
   reticle exists only while scoped — so an unscoped rifle shot at 450 studs has no aiming mark at
   all. That is realistic and it may be what she wants; it may also be a weapon nobody can use
   without right mouse. Confirm, or ask for a bare dot in the hip view.
F. **The rifle's recoil at 1.5× the shotgun's.** "A bit" was the whole brief for the shotgun's.

### Director (scope)

G. **The rifle is granted to every hunter from the start**, behind the `RIFLE` flag — the brief's
   "cheap answer" and this design's. If the economy (`karen-game-vision-2026-10-04`) is to gate it
   instead, that is `Weapons.loadout()`'s one function and a later task; nothing of the economy
   exists yet.
H. **Damage does not fall off with distance anywhere in this game.**
   `Boar.Wound.damageFor(zone, ammo, pellets, config)` has no distance term. So the rifle is
   *identical* to the slug inside 330 studs and strictly better beyond it: its advantage is **reach**
   and nothing else. If the rifle is meant to kill where a slug wounds, that is a `Bullet` column in
   `Boar.CONFIG.WOUND.DAMAGE` and a boar task — outside this one, and recorded here so the decision
   is taken on purpose.
I. **The Aimpoint red dot** — already cut by the Director; it is a second `scope` row with a
   different `aimFovDeg` and a `kind = "dot"` reticle on whichever weapon carries it, which is why
   §4.2's `Scope` is a separate type from the row.
J. **A per-weapon column in the report's list view** (how many with each gun). Not built: Karen asked
   for "how much I killed compairing others", not per gun.
K. **The world rifle for other players** needs its own uploaded mesh and `assets/uploads.json` rows,
   with the scope's maker name and logo painted out of the atlas first (brief §2.9). The Director
   uploads with Karen's OK; until then the three-box fallback is what other players see.

---

## 18. Build order — four steps, each one small and each behind the flag

The Director may take these as one task or four; the design is written so each step is green on its
own and nothing a player sees changes until step 4.

| Step | What lands | What a player sees | Gate |
|---|---|---|---|
| **R1** | `src/shared/Weapons/`, `src/shared/Rifle/`, the `RIFLE` flag at OFF, `apply`/`checkRequest`/`group`/`Hardware` taking a row, two Tools in `Hardware` and `Input`, `poses.json` v4, the report's weapon field. `tests/server/rifle.spec.luau` | **nothing.** The shotgun, from the row built out of its own numbers | one player; `rifle.spec` + every existing weapon and viewmodel spec |
| **R2** | `Rifle.Geometry`, `ShapeRifle`, `buildNewGun(config, row)`, the rifle's carry/aim poses, the bolt's `cycle` block and `Viewmodel.hinge`'s `"slide"` path | the rifle, with the flag on, in the hand and in the world | `t140-rifle-carry`, `t140-bolt-mid` |
| **R3** | `Camera.setOpticsSource`, `Mode.fovFor`'s third argument, `scopeSwayDeg`, `Hud.reticle*`. `tests/client/rifle_client.spec.luau` | the scope | `t140-rifle-scoped`; the FOV read-back case |
| **R4** | Karen's playtest with `python tools/flags.py set RIFLE on`, then her OK flips the default in a three-line commit | the rifle in every session | the full gate, one player |
