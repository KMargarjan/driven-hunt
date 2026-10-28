# The range moves to the lodge: six stations, two firing positions, one animal each

Task 306, phase A. Design to `reviews/task-306/BRIEF.md`, which overrides anything older in `docs/`,
`TASKS.md` or an earlier design. Note: `docs/research/2026-10-28-the-range-in-the-lobby.md`.

**This is a DELTA to `docs/design/shooting-range.md` (task 298), which stays the base document.**
Every section below says which numbered section of that document it replaces, extends or leaves
alone. Nothing here is measured in a running game: phase A cannot run one. Every spatial and
compositional fact is marked **UNVERIFIED UNTIL BUILT** in §14 (L-151), and every engine API is
either cited to a shipped caller in this repository or to the Roblox documentation (L-108).

---

## 0. The delta map

| Base design (`shooting-range.md`) | This document |
|---|---|
| §1 what it must do / must not do | **extended** (§1): six stations, two firing positions, per-player picture; six new "must nots" |
| §2 owners | **extended** (§3): three new rows, one new client owner, one new weapon provider. Nothing is re-owned |
| §3 which worlds, who starts it | **extended** (§8): two new DATA fields on the row (`berm`, `terrain`); `RangeBoot` stays THE one root |
| §4 `TestArena`/`Lobby` pattern reuse | **unchanged** |
| §4.1 `Range.LAYOUT` | **replaced in nine rows** (§5): `SPOT_COUNT`, `WINDOW_STUDS`, `BERM`, `SCREEN`→`BANK`, `PLATE`, plus four new tables (`STAND`, `BENCH`, `FILL`, `SURFACE`) |
| §4.2 "the forest anchor is MEASURED in step B1" | **replaced** (§2): the anchor is chosen here, as arithmetic, and B1 measures the ground under it rather than searching for it |
| §5 the range's own `Boar` runtime | **extended** (§4, §7.4): six targets, `SOUND` off, release only for an occupied station |
| §6 the route seam (`leadTo`) | **extended** (§6): the lane centre becomes per station; two new paces are TIMES |
| §7.1–7.2 cursor, trigger, prompt | **unchanged** in mechanism; **extended** (§7.3) by a second prompt per station |
| §7.3 option lists | **extended** (§6, §9): three distances, six paces plus `mixed` |
| §7.4 the three relaxations and the loan | **unchanged**, and §7.5 shows why it already covers the treestand |
| §8 interfaces | **extended** (§9) |
| §9 the board | **extended** (§9.4): `position`, `window`, `mine` |
| §10 the shooting numbers data file | **unchanged** |
| §11 how it is tested | **extended** (§11) |
| §12 what it reads and writes | **extended** (§10) |
| §13 numeric targets | **extended** (§12) |
| §14 sources | **extended** (§13) |
| §15 open decisions | **replaced** (§15) |

---

## 1. What the system must do, and what it must not do (extends §1)

Six additions to §1's list:

7. **Six stations on one firing line**, all usable at the same time, each with its own `E` prompt
   at chest height on its own post (task 303's measured rule, shipped as `Range.LAYOUT.POST`).
8. **Each man sees ONE animal — his own — and his own menu and board.** A man at station *n* never
   sees, hears, or can hit station *m*'s animal.
9. **Two firing positions per station:** a ground bench and a treestand, and **which one he is on is
   measured off his own character, never claimed by a payload.**
10. **Three distances** (107 / 125 / 179 studs = 30 / 35 / 50 m) picked in the menu, per station.
11. **Six paces:** Karen's four (`stand`, `walk`, `trot`, `run`) plus ISSF's two (`slow` 5.0 s and
    `fast` 2.5 s across the window), the two new ones expressed as **times**, with the stud speed
    derived from `WINDOW_STUDS`.
12. **The old forest range retires** in the same step that its replacement is proved.

### What it must NOT do — six additions

- **No second shooting path, and no second resolution of a hit.** Task 305's rule is binding: the
  shot hits what the shooter saw, through `Weapon.Rewind`, `Cast.candidates` / `Cast.only`, the
  carried `shot.rewindSeconds`, `Weapon.setRewindWorld` and `RangeBoot`'s already-registered
  per-runtime history provider (`Weapon.addHistoryProvider`). This design adds **no new cast, no new
  ray, no new damage call and no second answer to "where did the bullet go"**.
- **No second renderer of an animal.** `Boar.Body` stays *"the only writer of a boar's Instances"*
  and `Boar.Brain`/`Boar.Body` stay the only writers of its CFrame. The range still issues a ROUTE
  and nothing else.
- **No client-authored hit.** Nothing a client sends decides a hit, a zone, or an animal's position.
- **No scoring, money, licence, drive count or `HitLog` row** — task 304's rule, enforced where it
  already is: `HitLog.rowWorthy` refuses a part under `Range.TARGETS_FOLDER`. The hit **card** still
  goes out (`HitLog.sendCard`, held by `Range.setCardSender`).
- **No animal for an empty station.** Six drawn animals for one shooter is six animators and six
  sound sets for nothing (§7.4).
- **No relaxation of a security bound.** `CLAIM.LINE_TOLERANCE_STUDS`,
  `CLAIM.POSITION_TOLERANCE_STUDS`, `Rules.unsafeLine` and the safety-arc penalty are untouched and
  unreachable from the range.

---

## 2. The site, as arithmetic (replaces §4.2 and the `forest-test` row of §3)

This is the item that cost tasks 298 and 302 a session each. **The anchor is chosen here, with the
numbers worked through, and B1 measures the ground under it rather than searching for a site.**

### 2.1 The chosen anchor

```lua
["forest-test"] = { x = 2600, z = -3030, plate = false, downrange = -1, drawn = true,
                    berm = "terrain", fill = true },
```

`downrange = -1` is **south**, away from the lodge, the road, the yard, the trucks, the spawn, the
gathering yard, the tree line and the drive. The firing line is the footprint's **north** edge and
nothing the lobby owns is south of it.

Mats, from `Range.matPosition(anchor, spot, LAYOUT)` with `SPOT_SPACING_STUDS = 24`:

| spot | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| x | 2600 | 2624 | 2648 | 2672 | 2696 | 2720 |

all at z = −3030. Posts at `mat + (3, 4, −7)` (shipped `POST.sideStuds` 3, `aheadStuds` 7), so
x 2603..2723, z −3037. Treestand decks at `mat + (0, deckTop, +14)` (§7), z −3016 ± 3.

### 2.2 The footprint `Range.footprintFor` computes, worked through

`footprintFor`'s X arithmetic is **replaced** (§5.2): today it centres the berm on the anchor and
then adds the spots eastward, which is right for one station and wrong for six.

```
laneHalf   = WINDOW/2 + APRON                       = 18 + 20      = 38
bankOut    = laneHalf + BANK.beyondStuds + BANK.X   = 38 + 6 + 12   = 56   (the bank's OUTER face)
spots      = (SPOT_COUNT - 1) * SPOT_SPACING        = 5 * 24        = 120
bermHalf   = bermWidthFor()/2                       = 232/2         = 116   (centred at anchorX + 60)
margin     = PROMPT.MaxActivationDistance                           = 12

minX = anchorX + min(-bankOut, 60 - bermHalf) - margin = 2600 - 56 - 12 = 2532
maxX = anchorX + max(spots + bankOut, 60 + bermHalf) + margin = 2600 + 176 + 12 = 2788
uprange edge = anchorZ - dir*(STAND.backStuds + HighSeats.footprintRadiusStuds() + margin)
             = -3030 + 14 + 5.1 + 12                                          = -2998.9
downrange edge = anchorZ + dir*(DISTANCE_MAX + BERM.behindStuds + BERM.depth/2 + margin)
             = -3030 - (179 + 13 + 4 + 12)                                    = -3238
```

**Footprint: x 2532..2788, z −3238..−2998.9 — 256 × 239.1 studs.** Centre **(2660, −3118.5)**.

**ONE PLACEMENT CONVENTION, because this document carried two (306a(c), L-151).** `BANK.beyondStuds`
is the clearance from the lane's end to the bank's **NEAR** face — that is what task 298 measured (a
bank *on* the end stopped the target 7.8 studs short of it) and what the shipped `screenPosition`
does — so the bank's **outer** face is `beyondStuds + BANK.X` past the end, and the berm must reach
*that*. The earlier `bankOut = … + BANK.X/2` was the bank's CENTRE, which left half a bank outside
each end of the derived berm. The §5.x coordinates below are corrected to this one convention;
`range.spec` asserts the identity (berm faces == bank outer faces) rather than any of these numbers.

### 2.3 It does not fit the lodge's home field, and that is a number

Lodge home field (`Lobby.ANCHORS["forest-test"]` = (2850, −2950), `Lobby.CONFIG.FIELD.SPAN_STUDS`
220, half-span 110, through `Join.insideField`): **x 2740..2960, z −3060..−2840**.

The footprint is 256 wide against a 220-wide field and its centre is 190 studs west and 168 south of
the anchor. **It cannot fit, on either axis** — exactly as the note's §4 measures. So the task-302
mechanism is used as designed, with no new one:

- `ForestTestBoot`'s `rangeHomeAreas` already hands the lobby **one extra area, computed**:
  `RangeData.footprintFor(Vector3.new(row.x, 0, row.z), RangeData.LAYOUT, RangeData.downrangeOf(row))`.
  It follows the row. **Changing the anchor changes the home area and nothing else has to be
  edited** (§10 on the retirement).
- `Join.homeAreas(anchor, cfg, extras)` then adds that rectangle **and** `Join.walkwayTo(anchor,
  areaCentre, cfg)` with `FIELD.WALKWAY_HALF_STUDS` 24:
  **walkway = x 2636..2874, z −3142..−2926.**
- `Join.insideHome` is the union of the three. Every rectangle has a reason: the lodge's field, the
  range's own footprint, and the corridor a man actually walks.

**T7, checked as arithmetic:**

| Point | field | footprint | walkway | home |
|---|---|---|---|---|
| mats 1–6 (2600..2720, −3030) | no (x<2740) | **yes** | yes for x≥2636 | **yes** |
| the six decks (2600..2720, −3016) | no | **yes** | — | **yes** |
| the ladder feet (…, −3011) | no | **yes** (maxZ −2998.9) | — | **yes** |
| the berm crest (2660, −3221) | no | **yes** (minZ −3237) | no | **yes** |
| lodge door (2850, −2916) | **yes** | no | no | **yes** |
| (2760, −2990) | **yes** | no | yes | **yes** |
| (2730, −3010) | no (x<2740) | **yes** | yes | **yes** |
| (2700, −2950) | no | no (z>−2998.9) | **yes** | **yes** |
| behind the berm (2660, −3250) | no | no | no | **no — respawned, and that is correct** |

### 2.4 The drive's field, with the margin

`ForestTest.boundsOf(ROAD_LAYOUT)`: **x 2230..3830, z −2477..−1197**, `exitZ` **−2377**
(asserted by `tests/server/forest_stand.spec.luau`). The footprint's uprange edge is **−2998.9**:

**521 studs south of the drive field's `minZ`, 622 south of `exitZ`.** The whole range — every mat,
post, deck, bank, the berm and the home-area union's northernmost edge (the walkway's −2926) — is
outside the drive, and the walkway's own northern edge is still 449 studs south of `minZ`.

The range's own runtime field is `Range.fieldFor(anchor, LAYOUT, -1)`: `exitZ = min(nearZ, farZ) −
400` = **−3609**, 372 studs behind the berm, so `Brain:_outcome` can never report `escaped` or
`outOfBounds` for a target doing what it was told. Unchanged mechanism (§5 of the base design).

### 2.5 Clearance from every obstacle in the note's inventory, crown width included

Nearest **built part** of the range to each thing, from `evidence/p306-lobby.txt` (the note's §4,
measured in her place 2026-10-28) and from `Lobby.CONFIG.TREELINE` (`COUNT` 30, `RADIUS_STUDS` 100
about the lodge anchor, arc `FROM_RADIANS` 0.6 → `TO_RADIANS` 5.68, `JITTER_STUDS` 9):

| Thing | Its extent | Nearest range part | Clearance |
|---|---|---|---|
| Lodge plinth | x 2831..2870, z −2919..−2889 | mat 6 (2724, −3026) | **145 studs** |
| Lodge door (z −2916, x 2846..2854) | — | mat 6 | **172.9 studs** (T1, §2.6) |
| LodgeSpawn | 2844..2856, −2937..−2931 | mat 6 | **146 studs** |
| Road lane + verges | 2857..2884, −3054..−2894 | east cover bank, outer face x 2776 | **81 studs** |
| `Yard` | 2883..2929, −2994..−2910 | east cover bank | **111 studs** |
| Trucks 1–4 | 2906..2925, −2982..−2921 | east cover bank | **134 studs** |
| **Truck PADS** (`Lobby.CONFIG.PADS`) | x 2916, z −2926..−2977 | east cover bank | **144 studs**; the home-area union's own maxX is 2874, **42 studs west of the nearest pad edge** |
| Fences (14 parts) | 2852..2888, −3048..−3012 | mat 6 post (2723, −3037) | **129 studs** in x, no z overlap |
| Logs | 2816..2823, −2917..−2912 | mat 6 | **127 studs** |
| Gathering yard (`PADS.Gather`, x 2748..2828, z −2980..−2900) | — | stand 6's ladder foot (2721, −3011) | **31 studs**, and the footprint's uprange edge stops **18.9 studs** short of the pad |
| `TreeLine`, 27 built of 30 | trunks x 2765..2956, z −3045..−2875; crowns 18–33 wide | stand 6's ladder foot | **trunk 55.7 studs; crown edge ~35 studs** |
| `LodgeTrees`, 12 | 2806..2896, −2906..−2863; crowns 18–26 | stand 6 | crown edge **≥ 90 studs** |
| Lobby terrain shelf's west bank (x 2740) | — | mat 6 east face (2724) | **16 studs west of the bank**, so no part stands on the fill edge |

**Which trees must be removed: none.** Two independent readings agree. (i) The note's measured
bounding box puts every lobby trunk at z ≥ −3045 and the crowns at z ≥ −3061.5, while every range
part is at z ≤ −3011 and x ≤ 2724. (ii) `TREELINE`'s own arithmetic puts no trunk west of
x 2750 at all (radius 100 about x 2850 plus 9 studs of jitter), and the range's easternmost part is
at x 2724. So nothing is deleted and **rule 7's archive is not needed for a tree** — which is also
why `Build.treeLine` needs no fourth exclusion beside the road, the yard and the gather pad.

### 2.6 T1, from her own measurement and not from the nominal speed

Lodge door at (2850, −2916); nearest mat is spot 6 at (2720, −3030):

```
sqrt(130^2 + 104^2) = sqrt(16900 + 10816) = sqrt(27716) = 166.5 studs   -- straight line
walked round the gathering yard's east corner (2828, -2980): 
  (2850,-2916)->(2828,-2980) = 67.7 ; (2828,-2980)->(2720,-3030) = 119.0 ; total = 186.7 studs
186.7 / 10.4 studs/s (her measured effective walk, evidence/p298/walk-after.txt) = 17.9 s
```

**T1 holds with 21 studs and 2.1 s of margin on the worst path** (the straight line is 166.5 studs /
16.0 s). The dials, in order of preference: the anchor's x eastward (10 studs ≈ −1.0 s), the anchor's
z northward (10 studs ≈ −1.0 s, against the gathering yard's 31-stud clearance). `Body.defaultWalkSpeed`
16 is **not** used: the budget is her measurement.

### 2.7 The stand rule — the range's treestand cannot be a hunt stand

Four independent reasons, each a named symbol:

1. `Match.standAreaFor` is the only source of a hunt stand area, and at a station `Range.standOver`
   hands back **nil** — "NO AREA MEANS NO RULE" for both `Rules.outsideStand` and
   `Rules.belowPlatform` (their own headers). Shipped since task 298 step B3 round 3.
2. The hunt's seats are built by `ServerScriptService.ForestTest.Seats` into `Workspace.HighSeats`,
   which its header calls *"the one writer"* of that folder. The range's stand is built by
   `ServerScriptService.Range.Build` into `Workspace.Range`. Two folders, two writers, no overlap.
3. `HighSeats.hasSeat(layoutName, standIndex)` and `Seats.deckTopY(standIndex)` are keyed on a
   **drive stand index**. The range has no stand index and is never passed one.
4. `ForestTest.withinStand` is about circles inside the drive's field, 521 studs north.

**What IS shared is the arithmetic and nothing else:** `HighSeats.plan` (§7).

---

## 3. Owners — one writer each, named (extends §2)

| System | THE one writer | On disk | Changed? |
|---|---|---|---|
| The per-station run DATA (which trial each station runs, its leg, its window clock, its target id) | `ServerScriptService.Range` (`state.trials`) | `src/server/Range/init.luau` | **unchanged owner**, six rows instead of one |
| The range's geometry, every Instance under `Workspace.Range` | `ServerScriptService.Range.Build` | `src/server/Range/Build.luau` | unchanged owner |
| The range's **terrain** (the firing-line fill, the lane fill, the berm, the banks, the two materials) | `ServerScriptService.Range.Build`, through the **injected** `terrain` seam | `src/server/Range/Build.luau` | **new writer of a new fact.** `nil` terrain = no write, which is every spec and DEV |
| What a seat IS (its 14 pieces, its dimensions, its ground rule) | `ReplicatedStorage.HighSeats` (`HighSeats.plan`, `HighSeats.DIMS`), **pure** | `src/shared/HighSeats/init.luau` | **one new parameter** (`facing`), default = today |
| The animal's Instances and its CFrame | `ServerScriptService.Boar.Body` | `src/server/Boar/Body.luau` | **unchanged** |
| The animal's decisions | `ServerScriptService.Boar.Brain` | `src/server/Boar/Brain.luau` | **unchanged** |
| The animal's ROUTE | `ServerScriptService.Range` (`order` → `boars.leadTo`) | `src/server/Range/init.luau` | lane centre becomes per station |
| **Which range animals this ONE PLAYER can SEE** (`LocalTransparencyModifier` on parts under `Workspace.RangeTargets`) | `StarterPlayerScripts.Range.Mask` | `src/client/Range/Mask.luau` | **NEW owner.** `Camera.Rig` stays the only writer of that property **on the local character**; the two sets are disjoint by construction and a client spec asserts it |
| **Which instances one shot may not see** | `ServerScriptService.Weapon` (it builds the list in `ignoreFor`); `Range.ignoredFor` **answers** | `src/server/Weapon/init.luau` | **one new provider** (§4.3) |
| A shot, its flight, its claim, its report | `ServerScriptService.Weapon` | `src/server/Weapon/` | unchanged |
| Who hit what, where, and did it die | `ServerScriptService.HitLog` | `src/server/HitLog/` | unchanged |
| The composition root | `src/server/RangeBoot.server.luau` | — | **stays THE one root.** A new client root `src/client/RangeBoot.client.luau` starts the mask and nothing else |

Mirror these rows into `GAME_DESIGN.md` "System owners" in the same commit as the first code of the
step that introduces each.

---

## 4. The hardest decision: how the server judges a shot at one man's own animal

### 4.1 The obstacle, read off the code

`Weapon.castWithRewind` asks `Cast.candidates` *"what animal root is near this segment"*; that
function uses `WorldRoot:GetPartBoundsInRadius`
(<https://create.roblox.com/docs/reference/engine/classes/WorldRoot#GetPartBoundsInRadius>, cited in
`Cast.luau`'s own header) and then reads `(root).CFrame` and casts `Cast.only(root, …)` with an
**Include** filter. **Every step of the rewind wants a Part.** A client-created mesh has none the
server can see: an Instance sent client→server through a remote arrives as `nil`
(<https://create.roblox.com/docs/scripting/events/remote>, the note's §3).

### 4.2 The decision, and the deviation it carries

**The animal is the server's own `Boar` runtime target, drawn by the server exactly as the drive's
is. What is per-player is its VISIBILITY, not its mesh.** The brief's §2.3 permits exactly this —
*"the server keeps an invisible, non-collidable proxy per station (and 'isolated' then describes
rendering, not instances)"* — taken to its limit: the proxy **is** the animal, and it is invisible to
the five men it does not belong to instead of to all six.

So pattern 3's three load-bearing parts are kept verbatim — **server-owned per-station run DATA, the
shot reported as NUMBERS, the server the judge** — and its fourth, "a client-drawn animal", is
replaced by "a client-MASKED animal". **This is a deviation from decision 3's wording and it is
stated rather than slipped in.** Three pieces of evidence make the literal reading unbuildable
today:

1. **The client cannot obtain the animal.** The templates live in `ServerStorage.Assets` and are
   loaded by `ServerStorage.Assets.Loader`, handed to `Boar.Body` by `Boar.setModelSource` from
   `src/server/BoarAssetsBoot.server.luau`. CLAUDE.md's Layout table calls `src/serverstorage/`
   *"Server-only templates (for example animal models with AI scripts), **never replicated to
   clients**"*. `InsertService:LoadAsset` is server-only. A client-drawn animal therefore needs the
   animal templates moved into `ReplicatedStorage` — a change to the asset pipeline, to what every
   player can read, and to the replication budget — before one line of the range is written.
2. **It would be a second renderer.** `Boar.Body` is *"the only writer of a boar's Instances"*. A
   client copy would duplicate `Body.attachVisual` (template clone, the single-mesh rule, the weld,
   the `AnimationController`+`Animator` assertion, `HIDE_BOX`), `Body.warmAssets`, `attachSounds`,
   the gait/clip player and the per-kind box offsets — and it would decide **where the animal is
   drawn**. That is two of `docs/PROJECT_CONTEXT.md`'s named killers at once: *"invented
   foundations"* and *"two systems wrote the creature's position"*.
3. **`Boar.Body` already ships the invisible body.** `MODEL.HIDE_BOX` sets `trunk.Transparency = 1`
   and every zone part's, with its own comment: *"Transparency changes nothing a ray or a collision
   can see — `CanQuery` and `CanCollide` are untouched"*. The "proxy" the brief imagines is the
   shipped animal with its skin on.

**What this buys, exactly:** the shooting path is bit-for-bit the drive's. `Cast.candidates` keeps
its Part. `Boar.Body`'s welded zone parts are untouched, so every `tests/server/weapon_*.spec.luau`,
`Weapon.Hits.group`, `report.zone`, the hit card's `zone=`, `Runtime:takeHit`, `Boar.Wound` and
`HitLog.rowWorthy` are untouched. The view lag is the **same replication lag** task 305 measured
(0.180 s, residual 0.011 studs), produced by the same cause, so `FLIGHT_REWIND_BASE_SECONDS` 0.18
and `Weapon.rewindFor` are correct for the range **by construction and not by a second calibration**.
A client-drawn animal would have had **no** replication lag and the shipped rewind would then have
been 4.3 studs **wrong in the opposite direction** at run pace — a second lag model, which is a
second answer.

**How rule L's geometric proof survives.** The drawn mesh is the server's, welded to the trunk the
zone parts are welded inside; mesh, trunk and zones are one rigid body. The server tests the segment
against that body **where the shooter's screen drew it** (`Weapon.Rewind.impact`'s translation, and
`Rewind.nearer` so cover still wins). So the three numbers task 305's instrument reports — the
shooter's aim, the server's hit part and local offset, the client's mark — mean the same thing on the
range as in the wood, and the known-bad control (a click at the air beside the body) produces no hit
for the same reason it does in the wood: the ray misses the body. **Nothing about the proof is new;
only the number of bodies is.**

### 4.3 The one new seam: a shot's ignore list

Six animals share one lane corridor (§5.3) and overlap in space. Without an exclusion:

- `Cast.candidates` returns up to `CLAIM.MAX_TARGETS` (8) roots nearest the muzzle, and
  `Rewind.impact` takes the **nearest rewound impact** — which, for six bodies in one window, is
  whichever happens to be nearest, **not necessarily the shooter's own**;
- the static pass excludes only the candidates it rewound, so a body the shooter cannot see can
  stop his bullet. That is a rule-L defect, and it is the ONE thing six overlapping animals make
  possible.

So the weapon gains **the eighth injected provider, in the shape the seven have**:

```lua
-- WHAT THIS SHOOTER'S SHOT MUST NOT SEE (task 306). The EIGHTH injected provider on this owner.
-- Unwired means nil, and nil IS TODAY'S GAME: `ignoreFor` appends nothing and every
-- tests/server/weapon_*.spec.luau is bit-for-bit unchanged.
-- `rewindSeconds` is the SAME number the shot carries (`Weapon.rewindFor`), passed so the answer is
-- measured at the instant the rewind tests and not at an instant nobody shot at.
function Weapon.setIgnoreProvider(provider: ((Player, number?) -> { Instance }?)?)
```

`ignoreFor(player, rewindSeconds)` appends the provider's answer to the shooter's character and the
`WeaponEffects` folder. Both existing call sites are unchanged in meaning: `lookAhead` (the aim ray
and the target popup) asks with no rewind, the fire path asks with `Weapon.rewindFor(player, nil,
CONFIG)` — the value it already computes one line later for `shot.rewindSeconds`. Excluding a trunk
excludes its descendants (`FilterDescendantsInstances`), and `Range.isTarget`'s own comment records
that the zone parts are welded **under** the trunk, so one instance per animal is the whole exclusion.

The range answers it:

```lua
-- EVERY RANGE TARGET THIS SHOT MUST NOT SEE: the five that are not his, and his own while it is
-- outside its station's own window (§5.3). ONE predicate, `RangeData.inWindow`, read here and by the
-- client's mask -- the server's door and the client's picture asking one question, `Lobby.roleAllowed`'s rule.
function Range.ignoredFor(player: any, rewindSeconds: number?): { Instance }
```

It walks its own six trials, asks the narrow `boars` view for each target's root (`rootOf`) and, for
his own, where that root was at `now - rewindSeconds` (`cframeAt` — the same ring `RangeBoot`'s
history provider reads, so there is no second reader of the animal's past). It reaches no Workspace
and holds no state.

**With the provider installed, exactly one animal is in his shot's world**, the candidate cap can
never cut a body it did not exclude, and the resolution is the single-animal case task 305 proved.

### 4.4 The picture: `src/client/Range/Mask.luau`

```lua
Mask.start(seams: { root: Instance?, player: any?, now: (() -> number)? }): boolean
Mask.setMine(target: Instance?)                  -- TOLD by the server, on the board payload
Mask.setWindow(minX: number?, maxX: number?)     -- TOLD by the server
Mask.step(dt: number)                            -- one more call in the client root's Heartbeat
Mask.stats(): { targets: number, writes: number, hidden: number, shown: number }
Mask.stop()
```

- **It writes `BasePart.LocalTransparencyModifier` and nothing else.**
  <https://create.roblox.com/docs/reference/engine/classes/BasePart> — the property is client-local
  and **not replicated**, which is why `src/client/Camera/Rig.luau` can use it on the local body
  without a server round trip. **UNVERIFIED (§14):** that it hides a *skinned* MeshPart. The stated
  fallback is a client-local write of `Transparency` on the same parts (also non-replicated, and
  `Boar.Body` writes that property once, at `attachVisual`), and the measurement is one screenshot
  per client.
- **`Mask` writes nothing the server owns and creates no Instance.** It never touches `CanQuery`,
  `CanCollide`, `Transparency`, a CFrame, or any part outside `Workspace.<Range.TARGETS_FOLDER>`.
- **Level-triggered on the DESIRED state, edge-triggered on the WRITE.** Per frame it reads at most
  six trunk X values and writes only where the wanted value differs from the last one it wrote —
  `Mask.stats().writes` must not climb while nothing changes, which is the instrument
  `Range.stats().boardPushes` already uses against `.scans`.
- **A late part is handled by the sweep, not by a signal**, so streaming cannot defeat it: with
  instance streaming on, a part that is not there is not visible, and when it arrives the next frame
  hides it. `Map.STREAMING`'s own note records that four Workspace streaming properties are
  unreadable from Luau, so **nothing here depends on a streaming radius** (the note's §3 weighed and
  refused that approach).
- **Why not the Hud:** `src/client/Hud/` draws pixels. A writer of world instances does not belong
  there. `src/client/RangeBoot.client.luau` is its root, mirroring the server's one root.

### 4.5 What the other five stations' data does

Nothing crosses to him. `publish` is already `remotes.RangeBoard:FireClient(player, …)` with **his
own record only**; `state.trials` is server-side and `Range.trialOf` is a server read. The payload
gains only his own `mine` (an Instance — server→client Instance passing is shipped: `ShotLanded`
carries `parts`) and his own `window`. The only observable another station leaves on his client is
the replicated animal itself, invisible to him. **The leak is named:** an exploiter can read that
part's position. It is worth nothing — the range scores nothing, pays nothing and writes no row
(decision 11) — and his *own* shot still cannot touch it (§4.3).

---

## 5. Six stations: the geometry (replaces nine rows of §4.1)

### 5.1 `Range.LAYOUT`, changed and new rows

| Field | Was | Now | Where it comes from |
|---|---|---|---|
| `SPOT_COUNT` | 1 | **6** | decision 1 |
| `SPOT_SPACING_STUDS` | 24 | **24, kept** | `2 × PROMPT.MaxActivationDistance`: the smallest spacing at which a man on mat *n* is out of reach of mat *n±1*'s prompt (note §5.1) |
| `WINDOW_STUDS` | 40 | **36** | 10.00 m at `Report.CONFIG.METRES_PER_STUD` 0.28 (sources A, B) |
| `APRON_STUDS` | 20 | **20, kept** | task 298 step B2's measurement, and ≥ 12 studs = 0.5 s at run, source E's *"at full speed before it appears"* |
| `DISTANCE_STUDS` | 125 | **125, kept** as the default | 35 m |
| `DISTANCES_STUDS` | `{125}` | **`{107, 125, 179}`** | 30 m (source D), 35 m (shipped), 50 m (sources A, B; inside source C's 48–62 m hunting band) |
| `SCREEN` | 10×8×1 part | **`BANK` = 12 × 8 × 14**, `beyondStuds` 6 | decision 5's "low cover bank"; `beyondStuds` is task 298 step B2's **measurement**, not a preference (a screen ON the lane end stopped the target 7.8 studs short and no leg ever finished) |
| `BERM` | 160 × 10 × 6 at `behindStuds` 12 | **`size.X` DERIVED (232), `height` 10, `depth` 8**, `behindStuds` **13** **from the longest lane** | §5.2. 10 studs = 2.8 m, "not high" (Karen), inside the refused 6 m upper bound |
| `PLATE` | span `max(lane,120)+80` | **span `max(spots + lane, 120) + 80`** | DEV must hold six stations |
| `MAT`, `POST`, `PROMPT` | — | **unchanged** | task 303's measured post |
| `STAND` | — | **new:** `{ backStuds = 14, facing = -1, promptRise = 2.4 }` | §7 |
| `BENCH` | — | **new:** `{ size = Vector3.new(6, 2.7, 1.2), aheadStuds = 3.5 }` | 0.7–0.8 m bench top (source A) = 2.5–2.9 studs |
| `FILL` | — | **new:** `{ DEPTH_STUDS = 48, CLEAR_STUDS = 96, GRID_STUDS = 4 }` | borrowed from `Lobby.CONFIG.FIELD` with its two measured lessons (§8) |
| `SURFACE` | — | **new:** `{ LANE = Enum.Material.Grass, LINE = Enum.Material.Limestone, EARTH = Enum.Material.Ground }` | §8.3 |
| `IDLE_CLEAR_SECONDS` (in `CONFIG`) | — | **new: 30** | §7.4 |
| `MAX_PARTS` (in `CONFIG`) | 150 | **160** | §12 |
| `MAX_TARGETS` (in `CONFIG`) | `SPOT_COUNT` | **`SPOT_COUNT` = 6, unchanged formula** | one target per station |

### 5.2 The berm's width is derived, not typed

```
BERM.size.X = spots + WINDOW + 2*APRON + 2*(BANK.beyondStuds + BANK.size.X)
            = 120  + 36     + 40       + 2*(6 + 12)             = 232  (already on the 4-stud grid)
            centred at anchorX + spots/2 = anchorX + 60 = 2660   (2660 = 4 x 665)
            west face 2544, east face 2776   (both multiples of 4)

The two banks' OUTER faces are 2544 and 2776 as well: the berm's width is derived so those four
numbers are two numbers (306a(c)).

**And the berm's Z faces are on the grid too, which is what fixes `behindStuds` at 13 and not 12:**
its centre stands `DISTANCE_MAX + behindStuds` = 192 from the anchor and `depth` 8 puts its faces at
**188 and 196**, both multiples of 4. At 12 they were 187 and 195. All four edges of the berm are
therefore grid offsets from the anchor, which is the whole of §11.2 group 4's second half.
```

A typed 160 would leave stations 5 and 6 shooting past the berm's east end. `range.spec` asserts the
identity — *the berm spans every station's lane plus both banks* — rather than the number.

### 5.3 Six windows in one corridor, and why they overlap

**Each station's window is centred on its OWN mat**, so for every one of the six the crossing is
perpendicular to the range and the ballistic lead and the measured crossing stay about different
axes (`Range.LAYOUT`'s own stated reason). That makes `Range.laneCentre` and `Range.laneEnds`
per-station (§9.1).

Six 36-stud windows at 24-stud spacing therefore **overlap**, and physically separating them is
arithmetic that does not close:

```
one station's own lane  = WINDOW + 2*APRON               = 76 studs
six separated lanes     = 6 * 76 + 5 * 2*(bank half)     = 516 studs of firing line
the walk budget allows  (T1, 208 studs from the door)    = about 130 studs of firing line
```

So the six lanes share one corridor, which is exactly what the note's §5.3 says pattern 3 is for
(*"with each man's animal local to him, six bays can face ONE lane"*). Three consequences, each
answered:

1. **Six bodies in one place do not collide.** `Boar.Body.useCollisionGroup` puts every animal in its
   own collision group — *"so animals do not touch each other"* (`Runtime:_watchContacts`' own
   comment). No physics change, no `CanCollide` write.
2. **Six bodies in one place cannot steal each other's bullets.** §4.3.
3. **Six turn-arounds cannot each have their own pair of banks.** The two cover banks stand at the
   extreme ends of the LONG lane (x 2544..2556 and 2764..2776, at z −3209), and what actually hides
   every station's turn-around at every distance is the **per-player window mask** (§4.4) — the same
   one predicate `RangeData.inWindow` that the shot's ignore list reads, so the animal is drawn
   exactly where it can be hit and hittable exactly where it is drawn. **This is a stated deviation
   from decision 5's literal reading** ("the window between two low cover banks"): the banks are
   built, at the long line, and they are the look; the mask is the mechanism. It is also what a
   running-boar range looks like from the firing point — the target is in the opening or it is not
   there — and source D's 30 m test uses *half the opening* with no cover of its own, which is
   exactly what the 107 and 125 lanes are, in front of the banks.

### 5.4 The lane furniture, in one list

| Piece | Count | Where | Parts or terrain |
|---|---|---|---|
| Mat | 6 | `matPosition(anchor, n)` | part |
| Post + `RangePromptAt` + prompt | 6 | `promptPosition(anchor, n, …, "bench")` | part |
| Bench | 6 | mat + (0, ·, −3.5·dir), 6 × 2.7 × 1.2 | part |
| Treestand (14 pieces, `HighSeats.plan`) + rail prompt | 6 | mat + (0, ·, +14) | parts |
| Cover bank | 2 | x 2544..2556 and 2764..2776 (outer faces 2544 / 2776), z −3216..−3202 | **terrain** in her place, **parts** in DEV |
| Berm | 1 | x 2544..2776, z −3226..−3218, crest +10 | **terrain** / part |
| Side bank | 2 | x 2544..2556 and 2764..2776, z −3218..−3178 | **terrain** / part |
| Firing-line fill + gravel | 1 rectangle | x 2592..2728, z −3044..−2996 | **terrain** only (DEV uses the plate) |
| Lane fill + mown grass | 1 rectangle | x 2532..2788, z −3216..−3132 | **terrain** only |
| Ground plate | 1 | DEV only (`plate = true`) | part |

**Which edges the 4-stud grid binds, exactly** (round 1, finding 2). `Terrain:FillBlock` writes
4-stud voxels on a grid anchored at the WORLD origin, and task 191 left two grass voxels standing at
a misaligned edge (`Lobby.CONFIG.FIELD.PADS`' measured lesson). So:

- **The berm and the two fill rectangles are grid-aligned BY CONSTRUCTION**, as offsets from the
  anchor: the berm's width is snapped by `bermWidthFor` and its Z faces fall at 188/196 because
  `behindStuds` is 13. `range.spec` asserts all four, anchor-relative.
- **The two cover banks' Z faces cannot be**, and that is arithmetic, not an oversight: they are
  centred on the longest lane, `DISTANCE_MAX` is **179** (ISSF's 50 m, source A) and `BANK.size.Z`
  is 14, so the two faces differ by 14 and no pair of multiples of 4 differs by 14. Their X faces
  are on the grid (2544/2556 and 2764/2776).
- **The anchor itself must be on the grid for the offsets to land on it in WORLD space**, and
  §2.1's Z of −3030 is not (−3030 = 4 × 757.5). **B8 picks the final anchor off B1's census and
  must put both coordinates on a multiple of 4**, or snap each terrain rectangle as it fills it.
  The numbers in this table are written from the −3030 of §2.1 and move with that choice.

**Full-length side berms are refused, with the arithmetic:** a shot from mat 1 at the far edge of its
own window is 18 studs off axis over 179 studs (5.7°) and ends inside the berm's 232-stud span, so a
200-stud wall down each side of the corridor buys nothing, costs the largest terrain write in the
game, and walls the shooter in. The short side banks close the berm's ends so the back of the range
reads as one earth bay.

---

## 6. The paces: two new rows, expressed as TIMES (extends §6 and §7.3)

ISSF specifies the **time across the window**, not a speed (sources A, B). So the two new rows are
times and the stud speed falls out of `WINDOW_STUDS`, which means a later change to the window keeps
the real timing instead of silently changing it.

```lua
Range.WORD = { STAND = "stand", WALK = "walk", TROT = "trot", RUN = "run",
               SLOW = "slow", FAST = "fast", MIXED = "mixed" }
Range.PACE_ORDER = { STAND, WALK, TROT, RUN, SLOW, FAST, MIXED }   -- Karen's four first, unmoved
Range.CROSSING_SECONDS = { slow = 5.0, fast = 2.5 }                -- ISSF, the only numbers typed
```

| Row | Studs/s | Where from | Crossing of 36 studs |
|---|---|---|---|
| `stand` | 0 (walked to the middle, held by the Brain's own `LINE.ARRIVE_STUDS`) | `Boar.paceSpeed` | — |
| `walk` | 4.5 | `Boar.CONFIG.PACE.WALK_SPEED` | 8.00 s |
| `slow` | **7.20** = 36 / 5.0 | derived | **5.00 s** |
| `trot` | 11 | `TROT_SPEED` | 3.27 s |
| `fast` | **14.40** = 36 / 2.5 | derived | **2.50 s** |
| `run` | 24 | `RUN_SPEED` | 1.50 s |
| `mixed` | `slow` or `fast`, drawn per leg and **not announced** | source B | 5.00 / 2.50 s |

The note's 7.14 / 14.29 come from the unrounded 35.714-stud window; at `WINDOW_STUDS = 36` the
speeds are 7.20 / 14.40 and **the crossing time is exact by construction**. The 0.8 % difference is
inside T5's 5 %.

`Range.paceSpeedFor(word, layout, boarPaceSpeed)` is the one function: four words delegate to the
injected `Boar.paceSpeed` (so the range still invents no animal speed), two divide the window by a
time, and `mixed` resolves to one of those two per leg.

**No new gait, no new clip, no new config row — AND BOTH NEW PACES ARE ONE TROT CLIP AT TWO RATES**
(306a must-fix (a), measured against `Body.gait`'s own rule: run ≥ `MODEL.RUN_FROM`, trot ≥
`MODEL.TROT_FROM`, else walk). For the boar `TROT_FROM` = `CLIPS.walk.groundStudsPerSecond` ×
`WALK_MAX_RATE` = 2.852 × 1.8 = **5.13** and `RUN_FROM` = (`TROT_SPEED` 18 + `SPRINT_SPEED` 38)/2 =
**28**, so **7.20 and 14.40 both land inside the single TROT band** — one clip, played at ~0.70 and
~1.41 of its natural rate. The earlier sentence here (*"`model.RUN_FROM = (TROT_SPEED + RUN_SPEED)/2`
already bands 7.20 as a walk/trot and 14.40 as a trot/run"*) was wrong on the repo's own numbers and
also mixed `Boar.CONFIG.TROT_SPEED` 18 with `PACE.TROT_SPEED` 11. `range.spec` group 5 asserts the
band containment off `Boar.CONFIG.MODEL` rather than the figures typed here. Whether two rates of one
trot clip READ as two paces is Karen's look (§14 item 11).

**The menu's PACE row then carries SEVEN values**, and seven buttons at the shipped 94 px pitch run
238 px off a 416 px strip, so `RangePanel.buttonLayout(count)` derives the pitch: the shipped 94
while it fits, the strip divided by the count once it does not. Every row of four values or fewer is
bit-for-bit today's.

**`Range.setDistance(spot, studs)` is the one writer of a live trial's lane** (306b's queued note
(ii), owned by this step because this step measures the crossing): a lane changed while the target
is INSIDE the window clears and disarms the window timer exactly as `setPace` does, because the
diagonal transit to the new lane is not a crossing.

`Range.setPace` keeps its shipped behaviour exactly, including the task-303 fix (`windowArmed =
false`, so a pick taken mid-window cannot start a crossing). `mixed` draws its leg speed inside
`order`, where the leg flips, and the board prints the word it actually issued — `issuedStudsPerSecond`
already exists for exactly that honesty.

---

## 7. The two firing positions, and the treestand as DATA

### 7.1 The structure is the hunt's own seat, with one sign changed

`HighSeats.plan(stand: Vector3, grounds: { number? }, facing: number?) -> ({ Piece }?, string?)`
— pure, deterministic, 14 pieces, and already the one answer to "what is a seat". `facing` is a
**sign along Z**, defaulting to `+1`, which is the shipped `downrange` idiom exactly: it moves
`LADDER_OFFSET_STUDS`, the ladder gap in the rail and the ladder's ground sample to the other face.
`ForestTest.Seats` passes nothing and gets today's output bit for bit.

**BUILT IN B3, AND THE SIGN IS TURNED WITH THE ROW.** "The range passes −1" is right for a lane that
runs SOUTH (`downrange` −1, the frame §5.4's numbers are written in) and WRONG in DEV, where
`downrange` is +1: a constant −1 puts the ladder and the gap DOWNRANGE, in front of the shooter.
`LAYOUT.STAND.facing` stays −1 as data and `Range.standFacing(layout, downrange)` resolves it, so
the ladder, the rail's gap and the ladder's ground sample are on the **uprange** face in BOTH
worlds and the solid rail board faces downrange as the shooting rest `high-seats.md` §5.3 designed
it. `range.spec` asserts it off the BUILT parts, for both signs (L-019).

`HighSeats.footprint()` must take the same sign (its ladder sample is at `(0, −4)`), and
`HighSeats.footprintRadiusStuds()` is unchanged at 5.1 (symmetric).

### 7.2 The dimensions are the hunt's, and the note's two numbers are a stated deviation

| Thing | Note §5.2 asks | This design builds | Why |
|---|---|---|---|
| Platform height | 3.0 m = 10.7 studs | **`HighSeats.DIMS.DECK_RISE_STUDS` = 12.5 (3.5 m)** | *"the range should teach the position the hunt uses"* (note §2). The hunt's seat is 3.5 m; a range at 3.0 teaches the wrong hold-over, and a second height is a second structure. Inside the real 2.50–3.50 m band (source: topagrar, landwirt.com) |
| Rail above the platform | 1.2 m = 4.3 studs | **`RAIL_RISE_STUDS` = 2.4 (0.67 m)** | `high-seats.md` §5.3 is the arithmetic: the rail is a **shooting rest**, and at 1.0–1.2 m it blocks the shot. The German guard-rail height is already recorded there as a deliberate deviation. `HighSeats.blockedBand(aimRise, drop)` puts the blocked annulus at 11.3–13.9 studs from the seat's base — the nearest range target is **107 studs**, so at this range the rail blocks nothing |
| Getting up and down | — | **the engine's own climb.** The ladder is a `TrussPart` (<https://create.roblox.com/docs/reference/engine/classes/TrussPart>), climbed by a Humanoid with no script, no key and no new input owner — so it works on a thumbstick and a phone. `HighSeats`' own adopted pattern | |

Nothing about the seat is re-derived here: the range reads `HighSeats.DIMS` and calls
`HighSeats.plan`. **Zero new dimensions, one new sign.**

### 7.3 What the menu's `spot` option becomes: nothing

**The firing position is not a menu pick. It is where he is standing, measured by the server** —
which is the same discipline `Range.mayShoot` already follows (*"every fact measured off the
character the SERVER can see"*) and it cannot disagree with reality. Decision 7's "chosen at the
station" is made with his feet: he stands at the bench or he climbs the ladder.

```lua
-- WHICH STATION, AND WHICH OF ITS TWO FIRING POSITIONS. PURE. The second return may be nil: he is
-- at the station but on neither position (walking from the bench to the ladder, or under the deck).
Range.POSITION = { BENCH = "bench", TREESTAND = "treestand" }
Range.spotAt(anchor: Vector3?, position: Vector3?, layout, deckTops: { [number]: number }?)
    : (number?, string?)
```

- **the station** is the union box of the two positions: `|x − mat.X| ≤ MAT.X/2` (4) and
  `mat.Z − 4 ≤ z ≤ mat.Z + STAND.backStuds + HighSeats.footprintRadiusStuds()` (+19.1). At 24-stud
  spacing two station boxes are 16 studs apart, so a position belongs to at most one station. This
  is what `Range.mayShoot` asks, so a man never loses his gun walking the five studs from the bench
  to the ladder.
- **`bench`** is the shipped 8 × 8 mat rect, flat (no Y), exactly as today.
- **`treestand`** is the 6 × 6 deck rect **and** `position.Y >= HighSeats.minYFor(deckTops[spot])` —
  *"the deck's own top face, with no margin"*, the same comparison `Rules.belowPlatform` makes, so
  there is no sliver of height that is both or neither. A man on the ground under the deck is at the
  station with no position, which is the honest answer.
- `deckTops[spot]` is `nil` for a station whose stand was refused (`HighSeats.plan` returns a REASON
  for ground it cannot build on — `MAX_FOOT_SPREAD_STUDS` 4.0). That station has a bench only, as
  DATA, with no branch anywhere.

**THREE THINGS B3 BUILT DIFFERENTLY FROM THE SIGNATURES ABOVE, each stated rather than silent:**

1. **`spotAt` takes `downrange` as well** (`spotAt(anchor, position, layout, downrange, deckTops)`).
   The station box is ASYMMETRIC along Z — the deck uprange, the mat's own edge downrange — so no
   sign means no box. Every other geometry function in `Range` already takes it.
2. **The deck stands UPRANGE of the mat**, at `mat.Z − downrange × STAND.backStuds`. §5.4's table
   writes that as "mat + (0, ·, +14)" in the south-facing frame; the arithmetic is the row's sign,
   which is also what makes §9.4's `distanceFor` ADD the 14 instead of subtracting it.
3. **The stand's prompt hangs on an Attachment on the DECK, not on the rail board.** The deck is the
   one piece whose NAME does not move when `facing` mirrors the rail, and `Range.promptPointOf`
   reads the Attachment's `WorldPosition` — so the prompt's world point is this section's number
   either way, which `range.spec` asserts against `promptPosition(…, "treestand")`.

And `footprintFor`'s edges are now **whole studs, rounded OUTWARD**: the seat's footprint radius is
5.1, and a fractional edge does not survive a `Vector3`'s float32 — `lobby.spec`'s own round-trip
case read the rectangle's corner a ten-thousandth outside itself. Outward is the safe direction.

Two prompts per station, both at chest height on a part, both found by name
(`Lobby.Data.shopPrompt`'s shape):

```lua
Range.promptName(spot: number, position: string): string   -- "RangePrompt3" | "RangeStandPrompt3"
Range.promptFor(spot: number, position: string?, root: Instance?): any
Range.promptPosition(anchor, spot, layout, downrange, position): Vector3
```

The bench prompt is the shipped post top. The stand prompt sits on an Attachment on the **uprange**
rail board at `deckTop + STAND.promptRise` (2.4, the rail's own top). They cannot be confused for one
reach: deck centre to post top is `sqrt(3² + 21² + 8.5²)` = **22.9 studs** (306a(m): the Y term was
dropped, and the conclusion holds with more margin than stated), well outside
`PROMPT.MaxActivationDistance` 12 — which is also why the stand needs its own prompt at all.
`Range.atSpot(promptPoint, playerPoint, layout)` is unchanged and is asked about whichever prompt the
client found, so the engine's reach and the menu's closer stay one measurement (task 303's rule).

### 7.4 One animal per OCCUPIED station (extends §5)

`scan` today releases a target for every trial unconditionally. With six stations that is six drawn,
animated, audible animals in an empty lobby. So:

- a station releases a target when a player is measured at it (`spotAt ~= nil`) and
- clears it `CONFIG.IDLE_CLEAR_SECONDS` (30) after the last player left,

through the shipped `boars.spawn` / `boars.clear` verbs and the shipped `releaseAt` slot. No new
state machine. `Range.stats().targets` is then the number of men shooting, which is also the
instrument for the frame-time target (§12).

**And the range runtime's sounds are off.** `world.config.SOUND` is a full clone of
`Boar.CONFIG.SOUND` with `ENABLED = false` (a full clone because `Boar.newRuntime` merges only
`MODEL`, `SENSE` and `KINDS` key by key and assigns everything else wholesale —
`ForestTestBoot`'s stated rule). Six animals in one lane would otherwise play six footstep loops and
six snorts at one man's ear, and there is no per-player sound. **Karen's to overrule** (§15): the
alternative is her hearing every station.

---

## 8. What is terrain and what is Parts, in both worlds (extends §3)

### 8.1 Two new DATA fields on the row, never a branch on the world's name

```lua
["forest-test"] = { x = 2600, z = -3030, plate = false, downrange = -1, drawn = true,
                    berm = "terrain", fill = true }
["map:v1"]      = { x = 1200, z = 0, y = 0, plate = true, berm = "parts", fill = false }
```

`Build` asks the row, as it already does for `plate` and `drawn`. Both arms are reachable in
`range.spec` by parameter, because `Build.build` takes its parent, its row and its layout as
arguments.

### 8.2 Who writes the terrain

**`Range.Build`, through an injected `terrain` argument, and nobody else.** The seam is already in
the base design's §8.1 `Seams` (`terrain: Terrain?`, *"an argument, so no spec writes a place's
terrain"*) and is simply not used yet; `Range.start` passes it to `Build.build`. `nil` terrain means
**no write**, which is every spec and every DEV run.

Karen's OK of 2026-10-28 is what makes this legal: her Forest Test place's terrain may be edited and
saved. The writes are deterministic and in git, so the range can be rebuilt from a commit and a
defect can be bisected — which a hand-built berm could not.

Four calls, all cited to shipped callers or to the docs (L-108):

| Call | Used for | Evidence |
|---|---|---|
| `Terrain:FillBlock(cframe, size, material)` | the two fills (grass up to the shelf, air above it), the berm core, the banks | **shipped**: `Lobby.Field.fill`, which cites <https://create.roblox.com/docs/reference/engine/classes/Terrain#FillBlock> |
| `Terrain:ReplaceMaterial(region, resolution, from, to)` | the gravel firing line, the mown lane | **shipped**: `Lobby.Field` and `Places.Ground`, both of which record that it changes the material of a voxel **and nothing else**, and that `resolution` must be 4 |
| `Terrain:FillWedge(cframe, size, material)` | the berm's sloped face | **NOT used anywhere in this repository.** <https://create.roblox.com/docs/reference/engine/classes/Terrain#FillWedge> — **UNVERIFIED (§14)** which way the hypotenuse faces. **Fallback, decided now:** a stepped stack of four `FillBlock`s, 2 studs per step, which is the shipped API and the shipped idiom. B8 tries the wedge, looks at it, and takes the stack if the wedge's orientation costs a round |
| `Workspace.Terrain` as an argument | — | never `game:GetService` inside the builder |

### 8.3 The two surfaces, and why "mown" is a material and not a guess

The note records the surfaces as a GUESS with no source. It has one in this repository:
`Places.Ground` paints **`Grass`** and **`LeafyGrass`** as two different ground covers, and
`MapGen.Config` dresses the wood in `LeafyGrass`. So:

- **the lane is `Enum.Material.Grass`, cut and filled FLAT**, against the surrounding hill's
  `LeafyGrass` — short grass beside long, level beside sloping. That is what makes a mown strip read
  as mown, and it is the same device `Lobby.CONFIG.FIELD`'s own comment credits for making the field
  read as a field;
- **the firing line is `Enum.Material.Limestone`** — pale crushed stone, in `Places.Ground`'s own
  accepted list, so the enum value is verified by shipped code rather than recalled. `Ground` is the
  stated alternative if Karen reads limestone as too white (§15).

### 8.4 The firing line is flat by construction

The old site's measured ground spread was **11.6 studs over 160 × 185**. Across a 128-stud firing
line that is a staircase, and `Build`'s `onGround` would faithfully build one (it grows each part
down to its own ground — review round 1's rule). So the firing line gets its **own cut and fill**:
one grass `FillBlock` to the shelf plus one air `FillBlock` above it over x 2592..2728, z
−3044..−2996, at `FILL.DEPTH_STUDS` 48 and `FILL.CLEAR_STUDS` 96 — `Lobby.Field.fill`'s exact shape,
borrowed with its two measured lessons (a shelf must be a solid bank, not a floating slab; every edge
on the 4-stud grid). The shelf's height is `Build.shelfAt(row.x, row.z, row, groundAt)`, unchanged.

**In DEV nothing above happens.** `plate = true` lays the anchored plate, `fill = false` writes no
terrain, `berm = "parts"` builds the berm and the three banks as parts, and the harness needs no
terrain, no measured clearing and no Karen. Both worlds run the same code with different rows, and
`range.spec` drives both arms with a fake terrain that records its calls — `Lobby.Field`'s own
discipline: *"no spec in the DEV place can write DEV's terrain"*.

---

## 9. Interfaces, with types (extends §8)

### 9.1 `ReplicatedStorage.Range` — new and changed pure functions

```lua
-- CHANGED: the lane is per STATION, so both take the spot. The one-station answer is unchanged
-- when `spot` is 1, which is what keeps `range.spec`'s shipped arithmetic cases meaningful.
Range.laneCentre(anchor: Vector3, layout, downrange: number?, spot: number?, distanceStuds: number?): Vector3
Range.laneEnds(anchor: Vector3, layout, leg: number, downrange: number?, spot: number?, distanceStuds: number?): Vector3
Range.bankPosition(anchor: Vector3, layout, leg: number, downrange: number?): Vector3   -- renamed from screenPosition
Range.spotAt(anchor: Vector3?, position: Vector3?, layout, deckTops: { [number]: number }?): (number?, string?)
Range.promptName(spot: number, position: string): string
Range.promptFor(spot: number, position: string?, root: Instance?): any
Range.promptPosition(anchor: Vector3, spot: number, layout, downrange: number?, position: string): Vector3
Range.footprintFor(anchor: Vector3, layout, downrange: number?)      -- §2.2's arithmetic
Range.bermWidthFor(layout): number                                    -- §5.2
Range.fieldFor(anchor: Vector3, layout, downrange: number?)           -- widened to the six lanes

-- NEW: the ONE predicate both sides read (§4.3, §5.3)
Range.windowSpanFor(anchor: Vector3, spot: number, layout): (number, number)   -- minX, maxX
Range.inWindow(minX: number, maxX: number, x: number?): boolean
Range.paceSpeedFor(word: string, layout, boarPaceSpeed: ((string) -> number)?): number
Range.crossingTargetSeconds(word: string): number?                    -- 5.0 / 2.5 for the two new rows
Range.mixedWord(roll: number?): string                                -- which of the two a `mixed` leg draws
Range.distanceFor(trial: any, position: string?, layout): number       -- + STAND.backStuds on the deck
Range.POSITION = { BENCH = "bench", TREESTAND = "treestand" }
Range.CROSSING_SECONDS = { slow = 5.0, fast = 2.5 }
```

`Range.DISTANCES_STUDS` becomes `{107, 125, 179}` and `optionAllowed("distanceStuds", v)` is
unchanged — it already walks that list. `optionAllowed("spot", v)` is unchanged: it already bounds on
`LAYOUT.SPOT_COUNT`.

### 9.2 `ServerScriptService.Range` — new and changed

```lua
Range.ignoredFor(player: any, rewindSeconds: number?): { Instance }    -- §4.3
Range.positionOf(player: any): (number?, string?)                      -- the server's own measurement
Range.deckTops(): { [number]: number }                                 -- what Build measured
```

`Range.mayShoot` is unchanged in meaning (`spotAt ~= nil`) and now true on the deck as well as the
mat. `Range.installOver` and the four composed providers are **unchanged** (§7.5 of the base design
still holds: `Range.standOver` hands back nil, so `Rules.outsideStand` AND `Rules.belowPlatform`
both stand down — *"NO AREA MEANS NO RULE"*).

The narrow `boars` view (`RangeBoot`) gains exactly two readers:

```lua
rootOf   = function(id: string): Instance?        -- the trunk, for the ignore list
cframeAt = function(instance: Instance, at: number): CFrame?   -- the SAME ring the history provider reads
```

### 9.3 `ServerScriptService.Weapon` — one new provider

`Weapon.setIgnoreProvider` (§4.3). Nothing else on `Weapon` changes. `Weapon.ShotResolved`,
`Weapon.HitReported`, `Weapon.rewindFor`, `Weapon.castWithRewind`, `Weapon.addHistoryProvider` and
`Weapon.setRewindWorld` are all reused as they ship.

### 9.4 The remotes (extends §8.2)

`RangeRequest` (client → server) gains nothing. **It still carries no firing position and no
instance.** `RangeBoard` (server → client, `FireClient`) gains three fields on the per-player payload:

```lua
record.position   : string?     -- "bench" | "treestand" | nil, the SERVER's measurement
record.mine       : Instance?   -- this player's own target trunk, for the mask
record.window     : { minX: number, maxX: number }
```

and `record.distanceStuds` becomes `Range.distanceFor(trial, position, LAYOUT)`, so the two lead
numbers are computed at the distance he is actually shooting from (the deck is `STAND.backStuds` = 14
studs further back: 7.8 % at 179 studs, 0.21 studs of ballistic lead at run — small, exact, and free).

### 9.5 `StarterPlayerScripts.Range.Mask`

§4.4. Started by `src/client/RangeBoot.client.luau`, which also hands it the board payload's three
fields — the client root is the only thing that knows both the remote and the mask, so neither owner
requires the other.

---

## 10. What it reads and writes, and who owns each (extends §12)

| Fact | Direction | Owner | How |
|---|---|---|---|
| which instances a shot may not see | the range **answers**; the WEAPON decides and filters | `ServerScriptService.Weapon` | `Weapon.setIgnoreProvider` ← `Range.ignoredFor` |
| where an animal was at a past instant | read | `ServerScriptService.Boar` (`Runtime:cframeAt`, *"THE ONE READER of the ring"*) | `boars.cframeAt`, and `Weapon.addHistoryProvider` (shipped) |
| an animal's trunk for a target id | read | `ServerScriptService.Boar` | `boars.rootOf` |
| what a high seat IS | read | `ReplicatedStorage.HighSeats` (pure, no writer) | `HighSeats.plan`, `HighSeats.DIMS`, `HighSeats.minYFor` |
| the terrain under and behind the range | **write** (five rectangles) | `Workspace.Terrain`, handed in as an argument | `seams.terrain`; nil = no write |
| which of my own station's animals I can see | **write**, client-local only | `StarterPlayerScripts.Range.Mask` | `LocalTransparencyModifier` under `Workspace.RangeTargets` |
| `LocalTransparencyModifier` on the local character | **never touched by the range** | `StarterPlayerScripts.Camera.Rig` | — |
| the lobby's home areas | the range **supplies a rectangle**; the LOBBY decides | `ServerScriptService.Lobby` (`Join.homeAreas`) | `ForestTestBoot` composes `RangeData.footprintFor` (shipped, task 302) |
| money, points, penalties, licences, the roster, a drive row | **not read, not written** | `Economy`, `Match`, `HitLog`'s drive rows | — |

Everything else in §12 of the base design is unchanged.

---

## 11. How it is tested (extends §11)

### 11.1 THE PROOF OF THE FEATURE (the tests rule, verdict 298)

**T4 is the feature, and a spec cannot replace it.** A registered hit per pace from both firing
positions, on the animal as the shooter saw it:

`{stand, walk, trot, run, slow, fast} × {bench, treestand}` = **12 cases**, each reported with task
305's three-number instrument plus the frame:

1. the shooter's **aim** (the camera ray and the bore, from `Weapon.stats` / the shot record);
2. the server's **hit part and local offset** (`report.zone`, and the impact in the trunk's own frame);
3. the **client's mark** (the hit card's dot, `Shape.cardDots` off the trunk's CFrame at the instant
   of the hit);
4. the **shooter's-eye frame** (`python tools/studio_mcp.py capture`), looked at.

Beside each, **rule L's known-bad control**: a click at the air beside the animal, at the same pace,
must produce **no hit and no `HitLog` line**. A design that proves only the 12 hits has proved half.

The 12 cases are run at one distance (179, the hardest lead) and the three distances are proved
separately by T5's crossing times and by one hit each.

### 11.2 Server specs — `tests/server/range.spec.luau` (extends §11.1's ten groups)

New or rewritten groups:

1. **the site, as arithmetic, not as a name-check:** `footprintFor` for the new row equals §2.2's
   four numbers; it is **disjoint from** the truck pads and the drive's field, with the margins
   asserted against `Lobby.CONFIG.PADS`, `Lobby.ANCHORS` and `ForestTest.boundsOf(ROAD_LAYOUT)` —
   the spec reads those owners, so neither owner requires the other (`lobby.spec`'s own device);
   every one of the 6 mats, the 6 decks and the berm is inside `Join.insideHome(footprint ∪ field ∪
   walkwayTo)`; and the walk from the lodge door to mat 6 is inside it **sampled every 8 studs**.
2. **`spotAt` with two positions:** on each mat; on each deck above `minYFor`; on each deck **below**
   `minYFor` (station, no position); between the two (station, no position); one stud outside the
   station box (nil); on a station whose `deckTops` entry is nil (bench only); 500 studs away; nil.
3. **six prompts and six stand prompts**, each found by `promptName`, each ≥ 24 studs from its
   neighbour, and the deck-to-bench-prompt distance > `MaxActivationDistance`.
4. **the derived berm** spans every station's lane plus both banks (the identity, not the number);
   every terrain rectangle's four edges are multiples of `FILL.GRID_STUDS`.
5. **the paces:** `paceSpeedFor` against `Boar.CONFIG.PACE` for the four and against
   `WINDOW_STUDS / CROSSING_SECONDS` for the two; `crossingSeconds(WINDOW, paceSpeedFor(w))` equals
   5.00 and 2.50 exactly; `mixed` only ever resolves to one of the two.
6. **`inWindow` / `windowSpanFor`:** per station, at all three distances, inside, on both edges
   (`<=`, the repo's rule), outside, nil.
7. **`Range.ignoredFor`:** six trials, a player at station 3 → exactly five roots, and his own when
   his animal is outside its window; **nobody at a station → the list is empty**; a nil `boars` view
   → empty and no error; the list contains a TRUNK and never a zone part.
8. **`Weapon.setIgnoreProvider`:** unwired, `ignoreFor` is bit-for-bit today's (asserted against the
   shipped two-entry list); wired, the provider's instances are appended for the fire path AND for
   `lookAhead`; a provider that throws does not refuse the shot.
9. **`weapon_rewind.spec`** gains one case: two candidates at the same place, one of them in the
   ignore list, and the impact is the other one — driven through `Weapon.setRewindWorld` with hand-made
   CFrames and no world, which is what that spec already does.
10. **`Build.build` with `SPOT_COUNT` 6**, both `plate` arms, both `berm` arms, `fill` true with a
    **fake terrain that records its calls** and false with none; the mat is still the folder's first
    direct-child BasePart (the harness stage depends on it); `HighSeats.plan` refused for one station
    leaves five stands and six benches; part count ≤ `MAX_PARTS`; `pcall(Build.build, …)` twice makes
    no duplicate folder.
11. **`high_seats.spec`** gains the `facing` identity: `plan(stand, grounds)` and
    `plan(stand, grounds, 1)` are the same 14 pieces, and `facing = -1` mirrors exactly the ladder,
    the rail gap and the ladder's ground sample and **nothing else**.
12. **one animal per occupied station:** nobody at the range → `stats.spawns` stays 0; one man →
    exactly 1 target; he leaves → cleared after `IDLE_CLEAR_SECONDS` and not before.

### 11.3 Client specs

- `tests/client/range_mask.spec.luau` (new): six fake trunks under a fake folder, `setMine` +
  `setWindow`; asserted — exactly one is shown; the five others have `LocalTransparencyModifier` 1;
  his own is hidden outside the window and shown inside; **`Mask.stats().writes` does not climb
  across 60 idle steps**; a part added after `start` is masked on the next step; `Mask.stop` restores
  every value it wrote; and **nothing under the local character is touched** (the owner boundary with
  `Camera.Rig`, asserted rather than described).
- `tests/client/range_panel.spec.luau` (extended): the three distances and the seven pace rows come
  from the shipped tables; the board prints `position` and the distance it was told.

### 11.4 The harness, on the player's path (extends §11.3)

The shipped stage block needs **no harness change**: it finds
`Workspace.Range:FindFirstChildWhichIsA("BasePart")` on the server and places the character on it,
which is why `Build` still parents mat 1 first. One scenario is extended and one added to
`tests/client/input_scenarios.txt`: `the-range` (station 1, bench) and `the-range-stand` (station 1,
after a `moveTo`+walk into the truss, which the engine climbs with no key).

**Four limits, stated, with the fallback for each** (rule 6 — a harness fault is a bug and is
reported, not worked around):

| Limit | Evidence | What is done |
|---|---|---|
| The replay **cannot aim input at an instance** and no shipped scenario has ever clicked a GUI row | TASKS.md task 6: *"Cannot express: touch, gamepad, `textInput`, frame-counted holds, input aimed at an instance"* | unchanged from §11.3: the panel is anchored at the screen centre, the scenario clicks that point, and the spec asserts the button's real `AbsolutePosition`/`AbsoluteSize` contains it **before** asserting the click arrived |
| Whether a replayed `E` reaches the engine's own `ProximityPrompt` handling is **NOT ESTABLISHED** | `ShopPanel.setPrompt`: *"a spec cannot fire a real `ProximityPrompt`"* | the spec opens through the shipped `setPrompt` seam with a synchronous fake; **the real `E` at each of the twelve prompts is a Director ops step** with `263key.ps1` plus a screenshot (T2) |
| **The harness cannot run two clients' cameras.** `test2` starts a second player but the scenario file and the stage are the first client's | `tools/studio_mcp.py`'s docstring; `TWO_PLAYER_PATHS` | **T3 is a Director ops step: two clients, two men at two stations, one screenshot from each.** A client spec can prove the mask's rule (11.3) but not that two real screens disagree |
| Whether climbing a `TrussPart` can be replayed at all is **NOT ESTABLISHED** | no shipped scenario climbs | the stand cases of T4 are reached by the stage block placing the character on the deck (`offsetStuds`), and the **climb itself is a Director ops step with a screenshot**. If a replayed walk-into-truss works, the scenario keeps it |

### 11.5 Screenshots (rule 5) — required, and looked at before any claim

1. the firing line from behind, all six stations, from the lodge's side (does it read as a range);
2. down lane 1 from the bench with the target mid-window, at 107 and at 179;
3. down lane 4 from the **deck**, the rail board below the gun and the berm beyond it;
4. **the isolation frame: the same instant from two clients at two stations** (T3);
5. the open menu with six paces and three distances; the board after a run of shots;
6. the berm and the two cover banks from the firing line (is it "not high", is it "like in real life").

### 11.6 Blast radius and the gate

Changed paths: `src/shared/Range/`, `src/server/Range/`, `src/client/Range/`,
`src/client/RangeBoot.client.luau`, `src/client/Hud/RangePanel.luau`, `RangeBoard.luau`,
`src/shared/HighSeats/init.luau`, `src/server/ForestTest/Seats.luau` (one default argument),
`src/server/Weapon/init.luau` (one provider), `src/server/RangeBoot.server.luau`,
`src/server/ForestTestBoot.server.luau` (nothing — the home area follows the row).

**`test2` is N/A for every one of them** and that is CLAUDE.md's explicit list, not an opinion: none
is in `TWO_PLAYER_PATHS`, and the range is *"the weapon, the boar and the hud"*. The one-player line
is required, always. New `BLAST_RADIUS` rows: `src/client/Range` → `range`; `src/shared/HighSeats`
→ the scope `high_seats.spec` already belongs to. `SCOPE_SPECS` gains `range_mask.spec` in the same
commit, because `selftest` fails if a spec file belongs to no scope.

**The exception, for the Director (§15):** the isolation step (B6) is the one part of this range whose
claim a second client answers — *"who the OTHER player is"*. Either `src/client/Range/` joins
`TWO_PLAYER_PATHS`, or T3 is the ops step of 11.4. **Default: the ops step**, because a second client
renders a second copy of everything else and answers nothing the first did not.

---

## 12. Numeric targets (extends §13; T1–T8 are the note's)

| # | Target | Instrument |
|---|---|---|
| **T1** | Lodge door → nearest mat **≤ 208 studs**, walked in **≤ 20 s**. Designed: **186.7 studs / 17.9 s** on the worst path round the gathering yard | the task-298 walk probe, re-run |
| **T2** | **12 prompts** (6 bench, 6 stand), every one firable with a real key, each ≥ 24 studs from its neighbour | a real `E` at each, Director ops step + screenshot |
| **T3** | A man at station *n* has **exactly 1** animal drawn for him, whatever the other five are doing | two clients, one screenshot each, plus `Mask.stats()` |
| **T4** | **THE PROOF (§11.1):** a registered hit per pace from both firing positions, 12 cases, on the animal as drawn, each with the four pieces of evidence, plus rule L's known-bad control | task 305's three-number instrument + `capture` |
| **T5** | Measured crossing within **5 %** of 8.00 / 5.00 / 3.27 / 2.50 / 1.50 s | `Range.step`'s own window timer, published to the board |
| **T6** | **No shot from inside the window's own solid angle leaves the range.** Every shot whose aim point is on the animal's silhouette, from both positions, at all three distances, ends in the berm or a side bank. Computed: a level shot from the bench eye (shelf + ~5) at the chest (5) meets the berm at 5 of its 10 studs; from the deck (shelf + 17.5) it meets it at 3.9. **The residual is named:** a shot aimed above the crest clears it, flies **south**, and dies at the ammo's own range cap in empty ground — 521 studs from the drive, 145 from the lodge, with nothing and nobody in that cone, which is why the anchor was chosen to shoot away from every one of them | a ray sweep from each station across the full window, both positions, all three distances |
| **T7** | `Join.needsReturn` is **false** at all 6 mats, on all 6 decks, at the ladder feet, at the berm, and along the walk sampled every 8 studs | the task-302 instrument, plus §2.3's arithmetic asserted in `range.spec` |
| **T8** | 0 console errors; the old forest site, its home-area rectangle and its spec assertions are gone and nothing references them | `ft-open.sh` plus grep |
| **T9** | **Build cost:** ≤ **160** parts and ≤ **300 ms**, printed at the build edge (`[range] built in %d ms (%d parts)`). Designed: 12 + 6 benches + 6×14 stands = **102** in her place, **109** in DEV | `Range.stats().parts`, `.buildMs` |
| **T10** | **Step cost:** `STEP_HZ` 10, one `leadTo` per live target per step, ≤ **2 ms** per step with six targets | `Range.stats()` |
| **T11** | **Six drawn animals cost ≤ 3 ms of one server frame**, and an empty range costs **0 spawns** | `Range.stats().targets`, the Studio microprofiler, Director ops step |
| **T12** | **The mask is free when nothing changes:** `Mask.stats().writes` does not climb across 60 idle frames, and `Cursor.stats().reasserts` stays 0 | `range_mask.spec`, the live client spec |
| **T13** | **`Range.ignoredFor` ≤ 0.1 ms** and called at most twice per shot | `Range.stats().ignoreCalls` against `.shots` |
| **T14** | **Zero second writers:** no `.CFrame =` and no `AssemblyLinearVelocity` under `src/server/Range/` outside `Build`'s own parts; no `Transparency`, `CanQuery` or `CanCollide` write under `src/client/Range/`; no write under `src/client/Range/` to any part outside `Workspace.RangeTargets` | the specs plus the Reviewer's read |

---

## 13. External sources (rule 1 and rule 2; extends §14)

Full table with licences and status in the note's §2, §3 and §5.4. The five that this **design**
turns into a decision:

1. **BSRC Time Limit Range / 50 m Running Boar normal runs**
   <https://bsrc.co.uk/time-limit-range/> ·
   <https://bsrc.co.uk/wp-content/uploads/2023/01/50m-Running-Boar-Normal-Runs.pdf>
   Club web page, text © BSRC — **reference only, nothing copied**; live and maintained (2023 PDF).
   *Well:* 50 m, a 10.00 m window, 5.0 s and 2.5 s, target centre 1.4 m, bench 0.7–0.8 m, and the
   **mechanism** — a parapet hiding the rail, a firing hut of bays, a light per bay. *Badly:*
   second-hand for the ISSF rulebook, which could not be retrieved; a sport range, so no berm height.
   **Taken:** the window (36 studs), the two times (§6), the bench top (2.7 studs), and **bays side by
   side on one firing line** (§5).
2. **Wikipedia, 50 metre running target** <https://en.wikipedia.org/wiki/50_meter_running_target> ·
   <https://en.wikipedia.org/wiki/50_meter_running_target_mixed> — **CC BY-SA 4.0**, current.
   *Well:* confirms the distance, window and both times independently, and gives **"mixed"** — slow
   or fast, randomised and *not announced*. *Badly:* no construction detail.
   **Taken:** `Range.WORD.MIXED` (§6) — the cheapest realism in this design, one boolean.
3. **Svenska Jägareförbundet, Vildsvinspasset**
   <https://gava.jagareforbundet.se/globalassets/documents/jaktskytte/vildsvinspassetny5juli_2016.pdf>
   Official, Swedish hunters' association; 2016, still the published test. *Well:* a second,
   **hunting** distance — running boar at **30 m**, using *half* the moose range's opening, from a
   hunting rest. *Badly:* no geometry of the installation. **Taken:** the 107-stud station, and the
   justification for running the two short lanes **in front of** the banks rather than building a
   second pair (§5.3).
4. **topagrar's Drückjagdbock build guide** and the **landwirt.com Ansitzleiter listing**
   <https://www.topagrar.com/jagd-und-wald/news/bauanleitung-drueckjagdbock-guenstig-bauen-70191.html> ·
   <https://www.landwirt.com/bg/detail/sonstige-ansitzleiter-drueckjagdleiter-7062639>
   Trade press and a commercial listing, both live, both © their publishers. *Well:* the real band —
   platform 1.80–3.00 m, rail 1.20 m above it, footprint 1.70 × 2.50 m. *Badly:* no range anywhere in
   the sweep has an elevated firing point, so **the treestand station is Karen's invention and this
   project's**, and rule 2 is satisfied by saying so here as well as in the note. **Taken:** nothing
   new — the range builds `HighSeats`, whose own numbers already answer to these sources, and §7.2
   states the two deviations (3.5 m not 3.0; a 0.67 m shooting rest not a 1.2 m rail) with the
   arithmetic for each.
5. **Roblox Creator Documentation** — `BasePart.LocalTransparencyModifier`, `Terrain:FillBlock`,
   `Terrain:FillWedge`, `Terrain:ReplaceMaterial`, `WorldRoot:GetPartBoundsInRadius`, `TrussPart`,
   `ProximityPrompt`, instance streaming, remote events, the client-server boundary.
   <https://create.roblox.com/docs/reference/engine/classes/BasePart> ·
   <https://create.roblox.com/docs/reference/engine/classes/Terrain> ·
   <https://create.roblox.com/docs/workspace/streaming> ·
   <https://create.roblox.com/docs/scripting/events/remote> ·
   <https://create.roblox.com/docs/scripting/security/client-server-boundary> ·
   <https://github.com/Roblox/creator-docs> — the docs repository is **CC BY 4.0** and continuously
   maintained. *Well:* the engine's own description of the instances used here, and the sentence this
   whole design turns on: a client-created instance arrives on the server as **nil**. *Badly:* silent
   or wrong on the three things this repo has had to measure (`GetNetworkPing`, four unreadable
   streaming properties, a replayed keystroke's scan code). **So where shipped code answers a
   question, this design cites the shipped caller** (L-108): `Lobby.Field` for `FillBlock` and
   `ReplaceMaterial`, `Cast.luau` for `GetPartBoundsInRadius`, `HighSeats` for `TrussPart`,
   `Camera.Rig` for `LocalTransparencyModifier`, `Lobby.Build.shopPrompt` for the prompt.
   **`Terrain:FillWedge` has no shipped caller and is marked UNVERIFIED (§8.2, §14).**
6. **Valve, Latency Compensating Methods** — already adopted and shipped as `Weapon.Rewind`
   (task 305). <https://developer.valvesoftware.com/wiki/Latency_Compensating_Methods_in_Client/Server_In-game_Protocol_Design_and_Optimization>
   Named here because **this design's whole claim is that it adds nothing to it** (§4.2).
7. **This repository, which outranks all of the above for the mechanism.** `docs/design/high-seats.md`
   and `src/shared/HighSeats/init.luau` (what a seat is, as pure arithmetic — borrowed whole);
   `src/server/Lobby/Field.luau` and `Lobby.CONFIG.FIELD` (terrain cut and fill, 4-stud voxels, a
   solid bank not a floating slab); `src/server/Lobby/Join.luau` (a union of rectangles handed in as
   data, task 302); `src/client/Camera/Rig.luau` (`LocalTransparencyModifier`, level-triggered, one
   writer); `src/server/Weapon/Rewind.luau` and `Weapon.castWithRewind` (the shot the shooter saw).

---

## 14. UNVERIFIED UNTIL BUILT (L-151)

An Architect PASS proves this document is coherent. **It does not prove it fits the engine** — task
298 step B2 found two placement errors (the screens stopping the target 7.8 studs short; the prompt
invisible down the lane) only at the first build. Every item below is a **document fact**:

1. **The site's ground.** The firing line, the stands and the northern third of the footprint stand
   on natural ground that has never been measured. The old site's 504-sample grid (8-stud spacing,
   0 non-terrain hits, 11.6 studs of spread) covers x 2570..2730, z −3123..−3308 — **the lane and
   the berm, not the firing line**. B1 measures x 2532..2788, z −2999..−3238.
2. **Every clearance in §2.5**, which is computed from the note's measured bounding boxes and from
   `TREELINE`'s arithmetic, not from a part census over the new footprint.
3. **"No tree need be removed"** (§2.5). Two readings agree; neither is a census.
4. **The 6-station spacing at 24 studs** reads as a firing line and not as a row of boxes.
5. **The berm at 10 studs** is "not high" and "like in real life" to Karen; the wedge's or the
   stepped stack's slope looks like earth.
6. **The treestand at 12.5 studs** (not the note's 10.7) feels like the hunt's stand, and the rail at
   2.4 is a rest and not an obstacle **at 107 studs** (the arithmetic says the blocked band is
   11.3–13.9 studs; it has never been shot at this range).
7. **`Terrain:FillWedge`'s orientation.** No shipped caller. Fallback decided (§8.2).
8. **`LocalTransparencyModifier` hides a skinned MeshPart.** Fallback decided (§4.4).
9. **That the five masked animals are invisible AND inaudible.** `SOUND.ENABLED = false` makes the
   range silent for everyone; whether that is acceptable is Karen's (§15).
10. **T6**, in all 36 combinations.
11. **The gait at 7.20 and 14.40 studs/s.** The band arithmetic says walk/trot and trot/run; nobody
    has looked.
12. **Six drawn animals' frame cost** (T11), and that six animators plus six skinned meshes do not
    stall the first spawn despite `Body.warmAssets`.
13. **That a replayed walk into a `TrussPart` climbs it**, and that a replayed `E` reaches a real
    `ProximityPrompt` at all (still NOT ESTABLISHED since task 298).

---

## 15. Open decisions

### For the Director (scope) — the first one is the only one worth a sentence back before B5

1. **Ratify §4.2's deviation: the animal is server-drawn and client-MASKED, not client-drawn.**
   Decision 3's three load-bearing parts are kept; its fourth is replaced, with the three pieces of
   evidence in §4.2. **The alternative costs:** the animal templates move from `ServerStorage` to
   `ReplicatedStorage` (a layout and asset-pipeline change, replicated to every client), a
   client-side copy of `Body.attachVisual` + `warmAssets` + `attachSounds` + the gait player, a
   second writer of where an animal is drawn, and a **second lag model** — the client's own animal
   has no replication lag, so the shipped `FLIGHT_REWIND_BASE_SECONDS` 0.18 would be 4.3 studs wrong
   in the other direction at run pace. The build order puts B1–B4 before any of this, so **nothing is
   blocked while this is ratified**; B5 is the first step that depends on it.
2. **Does `src/client/Range/` join `TWO_PLAYER_PATHS`?** Isolation is the one claim here that a
   second client answers. **Default: no** — T3 is a Director ops step with two clients and two
   screenshots (§11.6). Adding it costs a human click on every round of B6.
3. **Phase B is nine tasks (§16), and rule 4 is one task per round.**
4. **The red deer at a station** needs nothing new: `SPECIES_ALLOWED` and the per-kind zone columns
   already ship. It rides B2 for free or waits.

### For Karen (feel and design) — none blocks building; each has a stated default

5. **Is south-west of the lodge "in front of the shop house"?** The firing line is 173 studs from her
   door, bearing ~230°, past the gathering yard's west corner. **Default: yes.** The dial is the
   anchor's x and z, and every number in §2 moves with it.
6. **Is the range silent?** Default: **yes** — `SOUND.ENABLED = false`, because six animals in one
   lane would play six footstep loops at one man's ear and Roblox has no per-player sound. The
   alternative is hearing every station's animal.
7. **Does the animal vanish at the window's edge?** Default: **yes** — the per-player window mask is
   what hides every station's turn-around, and it is what a real running-boar range looks like from
   the firing point. The alternative she might prefer is seeing it run the whole lane, which means
   watching five turn-arounds she cannot shoot at.
8. **The berm at 10 studs (2.8 m) and the two 8-stud cover banks** — "not high" has a range, and the
   refused upper bound is 21.4 studs (6 m).
9. **Gravel: `Limestone` or `Ground`?** Default `Limestone` (pale crushed stone). `Ground` is browner.
10. **Does a station lend all four guns?** Unchanged default from §15 item 1 of the base design:
    **yes**, at a station only, never into a drive.
11. **`mixed` on the menu** — slow or fast, not announced. Default: **offered, not the default pace**.
    **And the honest question beside it (306a must-fix (a), closed in B4): both new paces are one
    trot clip at two rates (§6), not two gaits — does that read as two paces?**
12. **Which distance the menu opens on.** Default: **125**, the one she has been shooting.

---

## 16. The build steps

Each is one task, small, provable, and in the order it can be proved. **The Director dispatches B1
only after this design PASSes.**

| # | What | What closes it |
|---|---|---|
| **B1** | **The site, measured. No code.** A part census and a ground-spread grid (8-stud spacing, the task-177/298 instrument) over x 2532..2788, z −2999..−3238, in **Edit and in Play**; the walk probe from the lodge door to (2720, −3030) | §2.5's clearances confirmed against a real census; the spread reported; **T1** measured. If the spread across the firing line exceeds `MAX_FOOT_SPREAD_STUDS` where a stand goes, §8.4's fill is why that is survivable — report it, do not move the site without the Director |
| **B2** | **Six stations, in DEV.** `SPOT_COUNT` 6, per-station lane arithmetic, the derived berm, the three distances, `BANK` for `SCREEN`, the `PLATE` span, `footprintFor`'s new X | `range.spec` groups 1, 3, 4, 10; harness; **T9**; screenshots down lane 1 and lane 6 from the plate |
| **B3** | **The treestand as data.** `HighSeats.plan`'s `facing`, `LAYOUT.STAND`/`BENCH`, `spotAt`'s two positions, the second prompt, `distanceFor`, `deckTops` | `range.spec` group 2, `high_seats.spec`'s `facing` identity; **T2** in DEV; a DEV screenshot from a deck |
| **B4** | **The paces.** `slow`, `fast`, `mixed` as times; `paceSpeedFor`; the menu rows | `range.spec` group 5; **T5** measured for all six at 36 studs |
| **B5** | **Isolation, the shot.** `Weapon.setIgnoreProvider`, `Range.ignoredFor`, `boars.rootOf`/`cframeAt`, `windowSpanFor`/`inWindow` | `range.spec` groups 6–8, `weapon_rewind.spec`'s new case; **in DEV, two targets in one window and station 1's shot passing through station 2's animal**; **T13** |
| **B6** | **Isolation, the picture.** `src/client/Range/Mask.luau`, `src/client/RangeBoot.client.luau`, the board payload's three fields | `range_mask.spec`; **T3** (two clients, two screenshots); **T12** |
| **B7** | **One animal per occupied station.** Release on arrival, clear on idle, `SOUND` off | `range.spec` group 12; **T10**, **T11** |
| **B8** | **Her place.** The new row, the terrain (the two fills, the two materials, the berm, the three banks) through the injected seam, the old row and its spec assertions archived under `backups/` with a note (rule 7) | **T1** walked, **T6** swept, **T7** sampled every 8 studs, **T8**; the six screenshots of §11.5 items 1, 2, 3, 6 |
| **B9** | **THE PROOF.** T4's twelve cases with rule L's control beside each, and Karen's playtest | **T4**, in full, with the four pieces of evidence per case; `PLAYTEST.md`; §11.5 items 4 and 5 |

**B3 MEASURED A THIRD OVERFLOW OF THE OLD FOREST CLEARING** (design 2.3's family): the sampled
rectangle was taken for a firing line with NOTHING behind it, and the treestand stands `standReach`
(19.1 studs) UPRANGE of the mat -- so even ONE station no longer fits it, by 11.1 studs BEHIND the
shooter. B8's census must cover the ground behind the firing line, not only the lane.

B2 needs B1's census only for the row. B3, B4, B5 and B7 all need B2 and are otherwise independent of
each other. B6 needs B5. B8 needs B2–B7. B9 needs B8.
