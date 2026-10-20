# Design: high-seats — a wooden Hochsitz at some stands of each drive place

Task 218. Written to `reviews/task-218/BRIEF.md`, which overrides anything older in `docs/`,
`TASKS.md` or an earlier design. Karen's reference is **ref-7** (`<runs-dir>/193-refs/karen-ref-7.png`,
outside the repo): an open raised wooden stand at the side of a forest road, plain weathered-timber
rail of rough boards, open deck, no roof — a Central-European **Drückjagdbock**.

This document rules on every decision the brief left open, including **D7's snap**, and it **amends**
the brief's proposal in two places (§6.1, §7.3). Both amendments are named as amendments.

---

## 1. What it must do, and what it must not do

### 1.1 Must do

1. Stand a wooden high seat — four legs, cross-bracing, an open deck 12.5 studs up, a plank rail, a
   ladder, **no roof** — at **some** stands of each of the four drive places, built from Parts in
   code in the lodge's timber idiom.
2. Put the hunter **on the deck** when the drive places him at a high-seat stand, through the seam
   that already exists (`Body.placementFor` reads `post.Position`), with **no new arithmetic in
   `Match`**.
3. Let him **climb** by walking into the ladder — the Humanoid's own climb state, **no new input
   owner and no new key**.
4. Refuse his shot while he is **below the platform**, with its own reason and its own notice line,
   and change **nothing** about a ground stand.
5. Sit **on the ground it is really on**: every leg cut to the ground measured at its **own** foot,
   read from an origin just above the terrain at that foot.
6. Be a pure function of the commit: which stands carry a seat is a **frozen table**, measured once
   and committed, so the world is reproducible.
7. Stop a body and stop a pellet: the deck, the legs, the rail and the ladder **collide** and are
   **queryable**.

### 1.2 Must not

1. **Must not add a field to the `Layout` record** (`drive-places.md` §1.2.1). `src/shared/ForestTest`
   stays the world-geometry seam; which stands carry a seat lives in a **second module that READS a
   layout**, one direction only.
2. **Must not write a second answer to "where is the ground."** `ForestTest.terrainYAt` and
   `ForestTest.groundAt` stay the only two readings and the seat is **given** both (§6.2).
3. **Must not touch, move, re-colour or destroy anything in `Workspace.OurForest`, `Session`,
   `LobbyAssets`, `DrivePlaces` or `ForestMarkers`.** The one folder this system may destroy is its
   own, `Workspace.HighSeats`.
4. **Must not carve or raise terrain.** No `FillBlock`, no `WriteVoxels`, no `ReplaceMaterial`.
5. **Must not change `Rules.outsideStand`'s flat rule**, and must not change the behaviour of any
   ground stand, the DEV arena, or any existing spec's answer.
6. **Must not invent a y** (`TreeGround`'s rule). A corner that cannot be read is a **refused seat**,
   counted and printed, never a guessed height.
7. **Must not require an upload, a free model or an `.rbxm`.**
8. **Must not put a seat in the DEV place.** `ForestTestBoot` returns early anywhere but
   `Map.EXPECTED_WORLD == "forest-test"`, and nothing in this design is reachable from `ArenaBoot` or
   `MatchBoot`.
9. **Must not make a seat blocking.** A seat that cannot be built must never produce a `missing`
   string, must never hold the drive in `Waiting`, and must leave its stand a working ground stand.
10. **Must not add a field to the stand wire.** `Match`'s snapshot copies `{ centre, radius }`
    (`src/server/Match/init.luau`, the `stands` loop); `minY` is **not** published and no client
    changes.

---

## 2. The pattern adopted, and why

**THE WORLD PLACES THE ENTITY, THE ENGINE OWNS THE CLIMB, AND THE GROUND IS TRACED PER CORNER.**
Three borrowed pieces, none of them new here:

1. **Climbing is a property of the thing climbed, not a new control.** The ladder is a
   `TrussPart`; the Roblox Humanoid's own `Climbing` state does the rest, so it works with WASD, a
   thumbstick and a mobile touch control, and `docs/design/camera.md` — the input owner — is not
   touched (brief D4). Luanti says the same thing in one word: a node is `climbable`.
2. **Drop to floor, per footprint corner.** Valve's `UTIL_DropToFloor`: a spawn Y is never authored,
   it is traced down from the authored point. `Match.Body.onGround` already borrows it (task 192);
   `Places.groundsUnder` already borrows the **per-corner** half (lesson L-024). This design is
   those two applied to a five-sample footprint, with the origin **just above the terrain at that
   sample** rather than from the sky (lesson L-025, and the `fromY` rule task 192 round 2 paid for).
3. **The world holds the entity the mode queries.** `ForestTest.Markers`' own pattern, extended by
   one step: a stand's marker part may now sit on a **deck** instead of on the terrain, and
   `Body.placementFor` cannot tell the difference because it reads `post.Position` and
   `post.Size.Y` and nothing else.

**What is NOT borrowed, said plainly:** the 3.50 m deck height is the brief's decision (D1), not a
number taken from a source; the rail height is derived from this game's own aim geometry (§5.3) and
is a **named deviation** from the German workplace guard-rail height of 1.00 m (§8, source E).

---

## 3. Ownership — one writer each, named

| System | Owner (the only writer) | Location on disk | Studio |
|---|---|---|---|
| **`Workspace.HighSeats`** — every seat Instance, its creation, its CFrames, its destruction | **NEW: `ForestTest.Seats`** | `src/server/ForestTest/Seats.luau` | `ServerScriptService.ForestTest.Seats` |
| **Which stands carry a seat, and every dimension and part of one** | **NEW: `HighSeats`** — frozen data and pure arithmetic. No Instance, no service, no raycast, no clock | `src/shared/HighSeats/init.luau` | `ReplicatedStorage.HighSeats` |
| `Workspace.ForestMarkers`, and the Y of `Stand<i>` | `ForestTest.Markers` — **unchanged owner.** It gains one branch: where a seat stands, the post's Y is the seat's deck | `src/server/ForestTest/Markers.luau` | unchanged |
| Where a character stands | `Match.Body` — **unchanged, and NOT TOUCHED BY THIS TASK.** `placementFor` + `onGround` already answer correctly once the marker is at the deck (§7) | — | — |
| May this shot be taken | `Weapon.Rules` — unchanged owner. One new predicate, one new reason, one new notice, one optional field | `src/server/Weapon/Rules.luau` | unchanged |
| This hunter's circle | `ForestTest.standArea` — unchanged owner. It carries `minY` when his stand has a seat | `src/server/ForestTest/init.luau` | unchanged |
| The call order across the three | `ForestTestBoot`'s `world.markers` closure — the **one** call site of `Seats.ensure` | `src/server/ForestTestBoot.server.luau` | unchanged |

**`ReplicatedStorage.HighSeats` and `Workspace.HighSeats` share a name in two different services.**
That is deliberate and it is the `ForestTest.LIVE_NAME` rule: `Seats.folder()` finds the folder
through `Workspace:FindFirstChild` and never by searching, and the module is reached through
`ReplicatedStorage:WaitForChild("HighSeats")`. One file, one instance, each found through its own
handle. (`Places` avoided the collision by naming its folder `DrivePlaces`; the brief names
`Workspace.HighSeats` and that is kept.)

**The files this task touches, in full** — and **not one of them is in `TWO_PLAYER_PATHS`**
(`tools/agents.py`): `src/shared/HighSeats/init.luau`, `src/server/ForestTest/Seats.luau`,
`src/server/ForestTest/Markers.luau`, `src/server/ForestTest/init.luau`,
`src/server/ForestTestBoot.server.luau`, `src/server/Weapon/Rules.luau`,
`tests/server/high_seats.spec.luau`, `tests/server/forest_markers.spec.luau`,
`tests/server/weapon_rules.spec.luau`, `tools/studio_mcp.py` (two table rows). See §11.4 for what
that means for the gate.

---

## 4. The seat, as geometry (brief §4 item 1)

### 4.1 The dimensions

`HighSeats.DIMS`, frozen. Metres at `Report.CONFIG.METRES_PER_STUD` = 0.28.

| Name | Studs | Metres | Why |
|---|---|---|---|
| `DECK_RISE_STUDS` | **12.5** | 3.50 | Brief D1. The deck's **top face** above the seat's **worst** footprint ground (§5.1) |
| `DECK_SIZE` | **6 × 0.5 × 6** | 1.68 m square, 0.14 thick | 6 × 6 **is `Markers.POST_SIZE`'s footprint**, so the post-top arithmetic lands in the middle of the deck with 2 studs clear all round a 2-stud-wide character |
| `LEG_SECTION_STUDS` | **0.5** | 0.14 | A real `Kantholz` of 10–14 cm |
| `LEG_INSET_STUDS` | **2.5** | 0.70 | Leg centres at (±2.5, ±2.5) from the stand point; outer faces at 2.75, inside the deck's 3.0 |
| `FOOT_EMBED_STUDS` | **0.3** | 0.08 | Each foot sunk into the voxel surface so no daylight shows under it (`TreeGround`'s claw idiom) |
| `GIRT_RISE_STUDS` | **6.0** | 1.68 | Horizontal girt, one per side, about half way up |
| `GIRT_SECTION_STUDS` | **0.4** | 0.11 | — |
| `BRACE_SECTION_STUDS` | **0.35** | 0.10 | — |
| `RAIL_RISE_STUDS` | **2.4** | 0.67 | Rail board **top** above the deck top. It is a **shooting rest**, not a guard rail; §5.3 is the arithmetic and §8 source E is the deviation |
| `RAIL_BOARD_TALL_STUDS` | **0.6** | 0.17 | A rough board |
| `RAIL_BOARD_THICK_STUDS` | **0.3** | 0.08 | — |
| `RAIL_PLANE_STUDS` | **2.90** | 0.81 | The board's own centre plane, on the **outside** of the legs (leg outer face 2.75 + half the board 0.15) |
| `LADDER_SIZE_STUDS` | **2** square | 0.56 | `TrussPart`'s own constrained cross-section (§8 source A) — and a real ladder is 0.40–0.50 m |
| `LADDER_CENTRE` | (0, −4.0) | — | South face, centred, its outer face flush with the deck edge at z = −3.0 |
| `LADDER_OVER_DECK_STUDS` | **1.0** | 0.28 | The truss runs a stud past the deck top so a climber can step off |
| `LADDER_GAP_STUDS` | **2.6** | 0.73 | The opening in the south rail a 2-stud character climbs through |
| `FOOTPRINT_RADIUS_STUDS` | **5.1** | 1.43 | The furthest footprint point from the stand point: the ladder's own outer corner at (±1, −5), √26 |

### 4.2 The parts, one row each — **17 per seat**

North is **+Z** (`ForestTest.DRIVE_BEARING_DEG` = 0); the drive comes from the north and the ladder
is on the south face, behind the hunter.

| Name | Class | Size (studs) | Where | Material | Colour |
|---|---|---|---|---|---|
| `Leg1`..`Leg4` | `Part` | 0.5 × *own length* × 0.5 | (±2.5, ±2.5). Bottom = its own foot ground − 0.3; **top = `deckTopY + 2.4` for all four**, so the four legs are the rail posts as well | `Wood` | `TIMBER` |
| `GirtN`, `GirtS` | `Part` | 5.5 × 0.4 × 0.4 | z = ∓2.5, y = `footY + 6.0` | `Wood` | `TIMBER` |
| `GirtE`, `GirtW` | `Part` | 0.4 × 0.4 × 5.0 | x = ±2.5, y = `footY + 6.0`, butting inside the N/S girts | `Wood` | `TIMBER` |
| `BraceE`, `BraceW` | `Part` | 11.18 × 0.35 × 0.35 | x = ±2.5, from (z −2.5, `footY + 1`) to (z +2.5, `footY + 11`). Placed with `CFrame.fromMatrix(mid, along, up)` — **`Markers.ring`'s own idiom** | `Wood` | `TIMBER` |
| `Deck` | `Part` | 6 × 0.5 × 6 | centre (0, `deckTopY − 0.25`, 0) | **`WoodPlanks`** | `BOARDS` |
| `RailN` | `Part` | 6.0 × 0.6 × 0.3 | z = +2.90, top at `deckTopY + 2.4` | `Wood` | `BOARDS` |
| `RailE`, `RailW` | `Part` | 0.3 × 0.6 × 5.4 | x = ±2.90, same top | `Wood` | `BOARDS` |
| `RailSE`, `RailSW` | `Part` | 1.7 × 0.6 × 0.3 | z = −2.90, x = ±2.15, same top — a 2.6-stud opening between them | `Wood` | `BOARDS` |
| `Ladder` | **`TrussPart`** | 2 × *L* × 2 | (0, —, −4.0). Top at `deckTopY + 1.0`, bottom at its own foot ground − 0.3, so *L* = `deckTopY + 1.3 − ladderFootY` | — | `TIMBER` |

**Every one of the seventeen:** `Anchored = true`, `CanCollide = true`, **`CanQuery = true`**,
`CanTouch = false`, `CastShadow = true`, `Transparency = 0`, `TopSurface`/`BottomSurface` =
`Smooth`.

**Why `CanQuery = true`, which is the deliberate opposite of every other part this world builds
(brief D5).** `Markers.marker` and `Markers.ring` both set `CanQuery = false`, and their own
comments say why: *"a slab that stops a pellet changes what the shot hit, and what the shot hit is
what `Penalty.judge` reads."* A marker and a ring are **references, not things** — they are
invisible, they are decided by nobody's eye, and a pellet that stopped on one would be a pellet that
stopped on an idea. **A deck is a thing.** A hunter stands on it, Karen looks at it, and a shot that
passed through a 0.14 m timber deck would be the inverse of that same fault: the world would be
telling the weapon that something she can see is not there. So the two rules are not in tension —
they are the same rule (*what the shot hit must be what is really there*) applied to two different
kinds of object. The same split already exists in this repo: `Lobby.Build`'s `part(..., solid =
false)` turns `CanQuery` off for cosmetics while the lodge's own shell keeps it on, and
`Lobby.Build.clip` is the third case (stops a body, stops nothing else) which this seat deliberately
is **not**.

**`CanTouch = false`** on the truss as well: `Touched` fires nothing here, and the Humanoid's climb
state is driven by collision and the part's class, not by a Touched event.

**Judged against ref-7, in words a frame can be checked against.** A frame from the ground looking
at a seat must show: four straight posts standing **on** the ground with no daylight under any foot
and none sunk out of sight; one horizontal girt and one diagonal visible on the side face; a flat
plank deck with a single board round it at about a seated man's chest; **no roof, no walls, no
bench**; and a ladder reaching the deck on the far side from the drive. A frame from the deck at eye
height must show the rail board **below** the gun and the road beyond it.

**Not built, and said so:** no bench (ref-7's hunter is seated; Roblox has no sit here and a bench
would take a third of a 6-stud deck), no roof, no backrest, no gun hook, no `Tool`-rest attachment,
and the seat does not weather or vary per layout.

### 4.3 Parts, totalled

| | Seats | Parts |
|---|---|---|
| `road` | 3 | 51 |
| `edge` | 2 | 34 |
| `ride` | 2 | 34 |
| `track` | 2 | 34 |
| **Worst case live at once** | **3** | **51** |

Against `Markers.ring`'s own worst case of **432** invisible segments on the road line, this is
small. Shadow casters: 51 worst case, against the 831 Studio `Session` trees already casting.

---

## 5. The arithmetic, stated (brief §4 items 2 and 4)

### 5.1 The ground fit (brief D6, lessons L-024 / L-025)

**Five footprint samples**, and the ground is read at **each of them**, never once at the pivot and
never off a bounding box:

```
s1 = (X − 2.5, Z − 2.5)      s2 = (X − 2.5, Z + 2.5)
s3 = (X + 2.5, Z − 2.5)      s4 = (X + 2.5, Z + 2.5)      s5 = (X,       Z − 4.0)   -- the ladder
```

**Each read is two readings with a `fromY`, in this order, and the order is the whole of D7:**

```
t  := terrainYAt(x, z)                  -- Include{Workspace.Terrain}: it CANNOT hit a deck,
                                        --   a canopy, a trunk or a body, by construction
if t == nil            -> REFUSE this seat
g  := groundAt(x, z, t + 2)             -- fromY is TWO STUDS ABOVE THE TERRAIN, never 600
if g == nil            -> REFUSE this seat
if |g − t| > 1         -> REFUSE this seat        -- Markers.GROUND_TOLERANCE_STUDS, same number
footY_i := g
```

**`fromY = t + 2` is why a seat can never measure itself.** A downward ray can only hit what is
below its origin (`ForestTest.groundAt`'s own header, task 192 round 2). A deck 12.5 studs above the
terrain is **above** an origin 2 studs above it, so it is unreachable — and that is true of the
seat's own deck, of a neighbour's, and of anything else overhead. This is the lesson L-025 fix
written as a rule rather than as care.

Then:

```
footY     := max(footY_1 .. footY_5)                 -- THE WORST corner, not the mean, not the pivot
spread    := footY − min(footY_1 .. footY_5)
if spread > MAX_FOOT_SPREAD_STUDS (4.0)  -> REFUSE this seat
deckTopY  := footY + 12.5
legTopY   := deckTopY + 2.4                          -- common to all four legs
leg i:  bottom = footY_i − 0.3,  top = legTopY,  length = legTopY − footY_i + 0.3
ladder: bottom = footY_5 − 0.3,  top = deckTopY + 1.0
```

**`max` and not `min`, and it is load-bearing, not taste.** `TreeGround` plants a trunk at the
**lowest** ground under its footprint and lets the claws bury themselves, because a tree with
daylight under it is the defect. A seat is the opposite case: the deck's Y is also the **platform
rule's own line** (§5.2), and a man standing on ground higher than that line could read as being on
the deck. Referencing the **worst** corner makes "nobody under this seat is above it" arithmetic
rather than hope.

**Each leg is cut to its own ground**, so the deck is level (all four tops are one number, exact) and
no leg hangs or sinks. **The Rule E claim is the worst case over all five samples of all seats, plus
frames:** no leg or ladder bottom face is **above** its own measured ground, and none is more than
`FOOT_EMBED_STUDS + voxel tolerance` = **0.8 studs** below it.

**What is refused, and what a refusal costs.** A seat is refused when a sample's terrain cannot be
read, when the two readings disagree by more than 1 stud at any sample, or when the footprint spread
exceeds 4 studs. A refused seat is **counted and printed** (`Seats.stats().refused`, the `[seats]`
line) and **its stand stays a working ground stand**: `Seats.deckTopY(i)` answers nil,
`Markers.build` falls through to today's path exactly, and `ForestTest.standArea` carries no `minY`.
**A seat is never a `missing` string** and can never put the drive in `WAITING`. That is
`Markers.build`'s own refused-stand discipline — *"one branch hanging over the lane must not stop a
playtest"* — applied one level out.

### 5.2 The stand rule: `minY` **is the deck's own top face**, with no margin

`StandArea` gains **`minY: number?`**. Where it is a number, a shot is refused while the shooter's
root is below it. `nil` is **"no height rule"** — every ground stand, the DEV arena
(`Match.standAreaOf`'s fallback), a beater, a player between drives and every existing spec.

**The ruling: `minY = deckTopY`.** Not `deckTopY − MARGIN`.

**The brief's D3 proposes a margin of about 2 studs and claims "no jump from the ground can reach
it". That claim is false, and this is the correction.** D3 reasons from "a jump reaches about 4–5
studs". A Roblox character's jump is `StarterPlayer.CharacterJumpHeight`, whose default is **7.2
studs** (and whose legacy `JumpPower = 50` form is 50² / (2 × 196.2) = **6.37 studs**). Either value
breaks the margin:

```
terrain under the man = footY (he is standing in the seat's own footprint)
his root, placed            = footY + STAND_HEIGHT_STUDS 3.5        = footY +  3.5
his root at a jump apex     = footY + 3.5 + 7.2                     = footY + 10.7
D3's line (margin 2)        = footY + 12.5 − 2.0                    = footY + 10.5   <-- REACHED
this ruling                 = footY + 12.5                          = footY + 12.5
his root standing on deck   = deckTopY + 3.5 = footY + 16.0
```

So with `minY = deckTopY` the two margins are:

* **1.8 studs** of air between the highest a jumper from the ground reaches (10.7) and the line
  (12.5);
* **3.5 studs** between the line and where a man standing on the deck actually is (16.0).

**It is one number with one meaning** — *your root is above the deck you are supposed to be standing
on* — read off the seat the world built, with nothing to tune and nothing to guess.

**The ruling's validity bound, stated and asserted.** It holds for any jump height under
`DECK_RISE_STUDS − STAND_HEIGHT_STUDS` = **9.0 studs**. `tests/server/high_seats.spec.luau` asserts
`12.5 − 3.5 >= HighSeats.MAX_JUMP_STUDS` with `MAX_JUMP_STUDS = 7.2` named in the module, so
**lowering the deck trips a spec instead of silently opening the rule**. `StarterPlayer` is not a
Rojo-owned container in this repo (`CLAUDE.md`, Layout: only `StarterPlayerScripts` and
`StarterCharacterScripts` are mapped), so the live value is Studio-owned and **not verifiable from
disk** — the Builder reads it in the place and reports it (§12 item 1). If it is ≥ 9.0, raise
`DECK_RISE_STUDS` and stop.

**The one case this does not close, named rather than hidden.** A man standing on ground **more than
1.8 studs above the seat's own worst foot** — possible inside the 12-stud circle on a steep stand —
can, at the top of a jump, read as on the platform. §6.3 condition (d) of the stand selection
removes it by measurement; where a layout has no stand that satisfies (d), the cost is **one console
line naming the number**, not a silent hole. The lever is `DECK_RISE_STUDS`, one line. This is
accepted in writing: the rule's purpose is *a high-seat hunter shoots from his platform*, not
anti-cheat, and the defeat costs a jumping shot from inside his own stand circle.

#### The new predicate, and where it sits in `Rules.ORDER`

```luau
-- RULE 5. IS HE BELOW HIS PLATFORM? ONE QUESTION, ITS OWN FUNCTION -- `Rules.luau`'s own rule, and
-- `Match.Penalty`'s warning about a predicate that answers two unrelated questions. `outsideStand`
-- stays FLAT and is untouched: that is the flat question, and the ground stands must not change.
-- NO minY MEANS NO RULE, the same call every other fact on this gate makes.
function Rules.belowPlatform(position: Vector3?, area: StandArea?): boolean
    if area == nil or position == nil then
        return false
    end
    if type(area.minY) ~= "number" then
        return false
    end
    return position.Y < (area.minY :: number)
end
```

```luau
Rules.REASON.OFF_PLATFORM = "off-platform"
Rules.NOTICE[Rules.REASON.OFF_PLATFORM] = "CLIMB TO YOUR STAND"

Rules.ORDER = table.freeze({
    Rules.REASON.DRIVE_OVER,
    Rules.REASON.OFF_STAND,
    Rules.REASON.OFF_PLATFORM,   -- NEW, task 218
    Rules.REASON.BEATER,
    Rules.REASON.LICENCE,
})
```

**Why immediately after `OFF_STAND`, and it is a decision.** `Rules.ORDER`'s own stated rule is
*outermost fact about the shooter first — the thing he must fix before any other answer is even
useful*. `OFF_PLATFORM` is exactly that shape, one step inside `OFF_STAND`: "NOT IN YOUR STAND" to a
man who is both outside the circle and on the ground sends him to the right place, and "CLIMB TO
YOUR STAND" then tells him the one thing left. Reversed, a man 500 studs from his stand would be
told to climb. It comes **before** `BEATER` for the same reason `OFF_STAND` already does — a refused
shot hits nobody, so no safety answer is lost, and the instruction he can act on wins. The notice is
19 characters, one less than the Hud's existing widest row (`"NOT AT A BEATER"` / `"THE DRIVE IS
OVER"`), so `src/client/Hud/` is unchanged.

### 5.3 The rail, the muzzle, and the one band of shots it blocks (brief D5)

A hunter on the deck must be able to shoot **out over** the rail — the thing ref-7 shows. The rail
is a **board with open space under it**, which is what makes this work: a steep shot goes **under**
the board, a flat shot goes **over** it, and only a narrow band of angles meets it.

With the aim origin at `deckTopY + 5.0` (root at +3.5 plus 1.5 to the eye), the rail plane at 2.90
studs from the stand point, the board's top at +2.4 and its bottom at +1.8, and a boar on the ground
12.5 studs below the deck:

```
clears OVER the board   when  tanθ <= (5.0 − 2.4) / 2.90 = 0.8966  ->  range >= 12.5 / 0.8966 = 13.9 studs
passes UNDER the board  when  tanθ >= (5.0 − 1.8) / 2.90 = 1.1034  ->  range <= 12.5 / 1.1034 = 11.3 studs
```

**So the rail blocks a boar between 11.3 and 13.9 studs of the seat's base** — a 2.6-stud annulus,
3.2 m to 3.9 m, directly beneath him. Everything closer passes under the board; everything further
passes over it. A real Hochsitz has the same blind ring and for the same reason.

**The band is sensitive to the aim origin, and that number is measured, not assumed.** At an origin
of `deckTopY + 3.5` (this repo's own `REST.sightEyeStuds`, "a standing man's eyes above the ground
he is on") the band widens to **21.3 – 33.0 studs**, which would matter. So the Builder **measures**
the aim origin's rise above the deck from a live shot — the server already holds `req.origin` in
`Weapon.onFireRequest` — prints `origin.Y − deckTopY`, and reports the band. **The lever is one
line, `RAIL_RISE_STUDS`:** if the measured band exceeds 10 studs, drop the rail to **1.8** studs
(0.50 m, a `Zwischenholm` height), which is still at a Roblox character's hip and still stops a walk
off the deck. The predicate is pure and spec-driven (§10 case 7), so the claim is a test and not a
sentence.

**The rail at 2.4 studs still stops a body**: it is a colliding box at 0.67 m, above the character's
hip. A player **can** jump over it (7.2 > 2.4) and drop off the deck, which is correct and wanted —
getting down must not need the ladder. A bot hunter has `JumpHeight = 0` and is anchored
(`Bots.Rig.prepare`), so it cannot.

### 5.4 The two arithmetic facts that make the rest of the drive keep working

**1. The floor net never fires under a seat.** `Body.underGroundBy` asks
`Body.groundUnder(x, z, at.Y)`, whose near probe starts at `at.Y + NEAR_PROBE_STUDS (6)`.

```
man UNDER his own seat:   origin = (footY + 3.5) + 6 = footY +  9.5
the deck's BOTTOM face:                               = footY + 12.0
margin                                                =          2.5 studs
```

The deck is **above** the probe's origin, so a downward ray cannot reach it and the man below reads
`ground = footY`, `below = −3.5`. **This links `DECK_RISE_STUDS` to `NEAR_PROBE_STUDS`:** the deck's
bottom must stay above `STAND_HEIGHT_STUDS + NEAR_PROBE_STUDS` = 9.5 studs. At 12.0 there are 2.5
studs of margin, and `high_seats.spec` asserts the relation (§10 case 6). A man **on** the deck
probes from `deckTopY + 9.5` and lands on the deck top: `below = −3.5`. Neither reads as buried.
`Body.insideTerrain` reads a **terrain voxel** and a deck is not terrain, so the net's first question
is untouched.

**2. The soft wall can never act on a man on his platform.** The deck's half-width is 3.0 studs and
the ladder foot is 5.1 from the stand point; `PICK.standRadiusStuds` is **12**. The whole seat lies
wholly inside the circle, so `ForestTest.boundaryPoint` returns nil for every point a man on the
deck can occupy and `ForestTest.boundary` never rewrites his CFrame. The brief's D3 claim that
nothing about the ring, the wall or `Places.LANE_STUDS` moves is therefore **arithmetic**:
`Places.LANE_STUDS` is 12 and `FOOTPRINT_RADIUS_STUDS` is 5.1, so the lane rule clears the seat's
footprint with **6.9 studs to spare** and nothing is planted through a seat (§10 case 10 asserts the
identity rather than describing it).

---

## 6. Which stands, and the frozen table (brief §4 item 3, D2)

### 6.1 The table

```luau
-- src/shared/HighSeats/init.luau
-- WHICH STANDS CARRY A SEAT, PER LAYOUT. FROZEN, so the world is a pure function of the commit --
-- the rule `Places` and `ForestTest.LAYOUTS` already follow. Ascending, never adjacent, capped.
-- MEASURED in Karen's Forest Test on 2026-10-20 (the gain, in studs, is in the comment per row).
HighSeats.STANDS = table.freeze({
    road  = table.freeze({ ?, ?, ? }),   -- <= 3
    edge  = table.freeze({ ?, ? }),      -- <= 2
    ride  = table.freeze({ ?, ? }),      -- <= 2
    track = table.freeze({ ?, ? }),      -- <= 2
})
```

The indices are **the Builder's measurement** and are not in this document, because no Studio is
reachable from an Architect run (rule 8). What **is** in this document is the rule that produces
them, exactly, so two Builders measuring the same world write the same table — and the spec asserts
the **shape**, never the values, which are Karen's to move.

### 6.2 The measurement, and the selection rule

**The measurement is a probe, not shipped code.** It lives in the Builder's run directory
(`<runs-dir>`), reads nothing and writes nothing in `src/`, and casts one horizontal ray north (+Z)
from each eye point, excluding `Workspace.Boars` and every character and capped at 400 studs:

```
eyeGround_i = (standX_i, terrainY_i + 5.0, standZ_i)
eyeDeck_i   = (standX_i, terrainY_i + 12.5 + 5.0, standZ_i)
gain_i      = reach(eyeDeck_i) − reach(eyeGround_i)          -- studs, >= 0
spread_i    = max − min of the five footprint grounds        -- §5.1
relief_i    = max − min of the terrain at the stand point and eight compass points at radius 12
```

All **25 stands of the four layouts** are measured and every row is printed, including the rejected
ones. Then, deterministically:

1. Rank the stands of a layout by `gain` **descending**, ties to the lower index.
2. Walk the ranked list and TAKE stand *i* when all of:
   (a) the count so far is below `ceil(standCount / 3)` — road 3, edge 2, ride 2, track 2, **9 in
   all**;
   (b) no already-taken stand *j* has `|i − j| == 1` — **never two adjacent**, so a hunter always has
   a ground neighbour and the line never reads as a row of towers;
   (c) `gain_i >= MIN_GAIN_STUDS` (**60**) and `spread_i <= MAX_FOOT_SPREAD_STUDS` (**4.0**);
   (d) `relief_i <= 1.8` studs — the §5.2 jump margin, measured rather than assumed.
3. Sort the taken indices ascending and write them into `HighSeats.STANDS`.
4. **Every place gets at least one seat.** If a layout takes none, condition (d) is relaxed for that
   layout and its single best-`gain` stand is taken, and the probe prints
   `seat <layout>/<i>: circle relief <r> studs > 1.8 -- the platform rule is defeatable at a jump
   apex`. This is the explicit tie-break between the brief's words (*"SOME stands of each of the four
   drive places"*) and a measurement that may not oblige.

`MIN_GAIN_STUDS = 60` is the Director's decidable default and it is reasoned: 60 studs is 17 m at
`METRES_PER_STUD` 0.28, which at `Boar.CONFIG.PACE.TROT_SPEED` (18 studs/s) is **3.3 s** more time
to see a crossing coming. A gain under that is not worth a tower.

### 6.3 What the spec may assert

Shape only: a row for every name in `Forest.LAYOUT_ORDER` and no row for anything else; `1 <= #row
<= ceil(standCount/3)`; every index inside `1..standCount`; strictly ascending; `row[k+1] − row[k]
>= 2`; both tables frozen. **Never the measured values.**

---

## 7. Placement and the snap — the ruling on D7, in full (brief §4 item 5)

### 7.1 The two facts that collide

The brief states them correctly:

1. If a seat is **visible** to `ForestTest.groundAt`, the hunter snaps onto the deck and the floor
   net, the soft wall and `underGroundBy` all stay right — **but** `Markers.groundFor` reads the
   stand column from the sky (`fromY` nil → 600) and would see the deck 12.5 studs over the terrain
   against `GROUND_TOLERANCE_STUDS` of 1, so **every seat stand would be refused** and the drive
   would sit in `WAITING forest:stands`.
2. If a seat is in **`ForestTest.GROUND_IGNORE`**, the markers are right and the hunter is snapped
   down off his own seat, which kills the feature.

### 7.2 The ruling

**The seats are VISIBLE to the world's one reader. `Workspace.HighSeats` is NOT added to
`ForestTest.GROUND_IGNORE`, and a spec asserts that it is not** (§10 case 9) — the inverse of
`places.spec`'s assertion that `Places.FOLDER` **is** in that list. A deck is a thing a body stands
on; the world's single answer to *where is the ground* must say so, or there are two answers.

**The stand column stays honest by ORDER, and by ASKING THE SEAT ITSELF — not by a second reader and
not by a remembered table.** This is the brief's proposal **amended in one place**, and the
amendment is the improvement:

> **Amendment 1 (brief D7, third bullet).** The brief has *"a seat REMEMBERS the terrain it was built
> on"* and `Markers.build` reading that memory. **This design has `Markers.build` ask the seat where
> its DECK is, read off the Instance the seat owner built, and not ask the two readers for that stand
> at all.** The folder **is** the state. A remembered table is a second copy of a fact the world
> already holds and can go stale against it (a destroyed seat, a half-saved place, a layout promoted
> twice); an Instance property cannot. This is the same discipline `Weapon.heldId` already follows —
> *"derived, never stored by anybody else ... so the two cannot disagree"* — and it removes the only
> idempotency question in the brief's version.

So:

```luau
-- src/server/ForestTest/Markers.luau, inside the per-stand loop of Markers.build
local deck = if seatSource ~= nil then seatSource(index) else nil
if deck ~= nil then
    -- A STAND WITH A SEAT IS MEASURED ONCE, ON CLEAN GROUND, BY THE SEAT'S OWNER (design 5.1), and
    -- the two readers are NOT ASKED HERE: `Data.groundAt` from the sky would see the deck 12.5
    -- studs up, disagree with the terrain by more than GROUND_TOLERANCE_STUDS, and refuse the
    -- stand -- `WAITING forest:stands` for ever. The post goes ON THE DECK, which is what
    -- `Body.placementFor` needs, and nothing here contributes to `lastMaxDelta` or `refused`.
    y = deck
else
    y, delta = Markers.groundFor(stand.X, stand.Z, groundReader, canopyReader)   -- unchanged
end
```

**`Markers.groundFor` itself is NOT changed.** It would have been tempting to give its canopy call a
`fromY` and make the deck invisible to it — but that reader's refusal is the rule all four layouts
were selected by (`drive-layouts.md` §10, *"today's road is 9 of 9 on both counts, which is the
bar"*), `forest_markers.spec` asserts it, and changing it would move the answer at every stand of
every layout for a reason that belongs to one stand in three. The branch above changes the answer
only where a seat stands.

### 7.3 Placement needs no new arithmetic anywhere

`Body.placementFor` reads `post.Position + post.Size.Y/2 + config.STAND_HEIGHT_STUDS`. The marker's
**centre** goes at `deckTopY`, which is the same convention the ground case uses (centre at the
surface). So:

```
post centre                         = deckTopY
placementFor                        = deckTopY + 0.5 + 3.5 = deckTopY + 4.0
Body.onGround near probe from       = deckTopY + 4.0 + 6   = deckTopY + 10.0  -> hits the deck top
final root                          = deckTopY + 3.5                            (feet ~ +0.2 clear)
```

— which is **exactly** the sequence a ground stand already produces (`Body.onGround`'s own comment:
*"3.5 was measured on a live stand as root 4.0 above the terrain with the feet 0.2 clear"*).
`Body.placementFor`, `Body.onGround`, `Match.standAreaOf`'s fallback, `ForestTestBoot`'s `placement`
closure and `ForestTest.postIndexFor` are **all unchanged**. The 6 × 1 × 6 post straddles the 0.5
deck slab; it is invisible, non-colliding and non-queryable, so it interferes with nothing.

> **Amendment 2 (brief §3, "where a character stands").** The brief allows that *"if the Architect
> needs a change here, it is `TWO_PLAYER_PATHS`."* **It is not needed.** `src/server/Match/` is not
> touched by this design, and §11.4 draws the consequence for the gate.

### 7.4 The residual risk — **closed by arithmetic, not accepted**

The brief names it: with the seats visible to `groundAt`, the three other callers that ask it from
the sky with no `fromY` could in principle put a boar or a bot **on a deck**. The brief's position is
to accept it. **Measured against the code, it does not arise.** Caller by caller:

| Caller | Where it asks | Verdict |
|---|---|---|
| `Places.build` | **never asks `groundAt` at all.** `ForestTestBoot` hands it `ForestTest.terrainYAt` (terrain-only), and it runs once at boot before any seat exists | **closed twice over** |
| `Runtime:spawn` (`Boar/init.luau`) | `releaseLine`'s start at `LINE.spawnNorthStuds` = **180 studs north** of the line; `Data.wavePoint` further north; `restSpot` in the wood at `REST.nearRoadStuds` ≥ 40 north | **closed.** The nearest spawn column is 40 − 5.1 = **34.9 studs** from any seat footprint |
| `Runtime:placeAt` (a follower snapped back onto the trail) | the leader's own breadcrumbs — points the leader **walked** | **closed by construction.** A boar cannot climb a ladder, so no crumb is ever on a deck |
| route waypoints | `PathfindingService` in `ForestTest.computeRoute`; **no `groundAt` read at all** (grep: the only two `groundAt` calls in `Boar/init.luau` are the two rows above) | **closed.** And a seat collides, so the navmesh routes a path **round** it, which is correct |
| `Bots.groundedFrom` (bot **hunter**) | the post `Body.placementFor` chose — at a seat stand, the **deck** | **correct, not a bug.** An anchored bot hunter stands on the platform, which is what a hunter at that stand does |
| `Bots.groundedFrom` (bot **beater**) | `Data.beaterStart`, 580 studs north | **closed** |
| `Lobby.start` / `Build` | the lodge field at (2850, −2950), built once at boot | **closed** |
| `ForestTest.nearestSolid` / `restSpotOk` | a rest spot ≥ 40 studs north; `REST.nearTrunkStuds` = 22 | **closed.** 34.9 > 22, so a seat leg can never be mistaken for the trunk a resting group is placed beside |

So the brief's named residual risk is **closed in writing** rather than accepted, and the one thing
the live drive still has to confirm is the one thing arithmetic cannot: that no animal is seen
standing on a deck in a full drive (§10.4, the live proof).

**One consequence is an improvement and is worth naming.** `ForestTest.roomToStand` and
`ForestTest.laneAhead` both see the seat (`RespectCanCollide`, excluding only the Terrain, `Boars`
and characters), so a bot beater whose lane runs into a leg is **deflected or detoured** by task
208's own machinery instead of pinning against it. Before this task a leg would have been a thing
`roomToStand` could not see.

---

## 8. External sources (rule 1)

### A. Roblox Creator Docs — `TrussPart`, and `Enum.HumanoidStateType.Climbing`

<https://create.roblox.com/docs/reference/engine/classes/TrussPart> ·
<https://create.roblox.com/docs/reference/engine/enums/HumanoidStateType> ·
<https://create.roblox.com/docs/reference/engine/classes/Humanoid#SetStateEnabled>
Licence: the Creator Docs content repo is **CC BY 4.0**. Maintenance: **continuously maintained**
(first-party).
**Does well:** the climb is the engine's own state machine, so one part class buys WASD, a
thumbstick and mobile touch at once — which is the whole of brief D4, and the reason this task adds
no input owner and no key and does not touch `docs/design/camera.md`.
**Does badly:** the page is a property index with almost no prose. Two facts it does not state are
load-bearing here — a `TrussPart`'s `Size` is **clamped** so two axes are exactly 2 (so the Builder
must read `Size` back after writing it, §12 item 2), and `Climbing` can be disabled per-Humanoid, so
a later task that calls `SetStateEnabled(Climbing, false)` would silently break the ladder with no
spec to catch it.
**Adopted:** the ladder is a `TrussPart` of `Size = (2, L, 2)`, anchored, vertical, with its top a
stud over the deck.

### B. Luanti (Minetest) — `climbable` node property

<https://api.luanti.org/node-definition/> (`core.register_node{ climbable = true }`)
Licence: engine **LGPL-2.1+**, game content CC BY-SA. Maintenance: **actively released**.
**Does well:** the canonical statement of the pattern in one word — *climbing is a property of the
thing climbed, not a new control*. This is a source this repo already reads: `Weapon.Rules`' own
header borrows `core.is_protected` from the same API.
**Does badly:** Luanti's ladders are whole-node grids with no partial heights and its climb speed is
a global; neither maps to a 12.5-stud timber ladder cut to its own ground.
**Adopted:** the principle, which is what makes D4 free.

### C. Valve Source SDK 2013 — `UTIL_DropToFloor`, and `func_ladder` / `CGameMovement::LadderMove`

<https://github.com/ValveSoftware/source-sdk-2013> (`game/server/util.cpp`,
`game/shared/gamemovement.cpp`)
Licence: **Source SDK 2013 licence** — source-available, non-commercial, **not open source**.
Maintenance: **archived**, no meaningful commits in years.
**Does well:** both halves of this task in one engine. A spawn Y is never authored but traced
down — already the pattern `Match.Body.onGround` borrows (task 192) — and a ladder is a volume with
a top and a bottom that the mover's own movement code enters, which is exactly the shape Roblox's
`TrussPart` + `Climbing` has.
**Does badly:** `func_ladder` only works because the engine's movement code cooperates, which is
code we do not have and cannot write; and the licence forbids copying anything but the idea.
**Adopted:** drop-to-floor, applied **per footprint corner** with a near origin (§5.1). Nothing is
copied.

### D. Wikipedia — *Hochsitz*

<https://de.wikipedia.org/wiki/Hochsitz>
Licence: **CC BY-SA 4.0**. Maintenance: **actively edited**.
**Does well:** it is the one source with a quotable licence that settles D1's typology — the
**Drückjagdbock** is the open, low, often mobile stand, as against the closed box *Kanzel* and the
*Leiter* strapped to a tree. That is the sentence that says ref-7 is a Bock and that this design
builds no roof and no walls.
**Does badly:** no engineering dimensions, no citations for the heights it does give, and a
general-encyclopedia article is not a build standard.
**Adopted:** the typology, and nothing numeric.

### E. German guard-rail height — ASR A2.1 / DGUV, via the practice literature

<https://www.baua.de/DE/Angebote/Regelwerk/ASR/ASR-A2-1> (ASR A2.1, *Schutz vor Absturz*)
Licence: German federal technical rule, freely published, **all rights reserved** as text.
Maintenance: **current**.
**Does well:** it is the number this design deliberately does **not** use, and having it written down
is what makes the deviation a decision. A working platform's `Geländer` is **1.00 m** (3.6 studs)
with a `Zwischenholm` at about 0.50 m.
**Does badly:** it is a **workplace** rule and a hunting stand is not a workplace; and at 3.6 studs
the rail is above this game's aim origin minus the clearance it needs, which §5.3's arithmetic shows
blocks a normal side shot between 25 and 42 studs.
**Adopted as a named deviation:** the rail is a **shooting rest** at **2.4 studs (0.67 m)** on all
four faces, which is what a real Drückjagdbock's front rail is and what a seated hunter rests on. The
`Zwischenholm` height of 0.50 m is kept as the **documented fallback** if the measured aim origin
widens the blocked band past 10 studs.

### F. WILD UND HUND — *Drückjagdstände — Sicher ist sicher?*

<https://wildundhund.de/drueckjagdstaende-sicher-ist-sicher/>
Licence: editorial, **all rights reserved**, read-only reference. Maintenance: **live site**.
**Does well:** the practice source for **where** a stand belongs — not on a path or a narrow
clearing between thickets, but where the passages converge and the bullet catch is safe — which is
the reasoning behind D2's *height buys sight the ground does not have*. Already cited in this repo
(`src/shared/ForestTest/init.luau`, the `edge` layout), so this is a borrowing declared twice.
**Does badly:** prose about real stands with no dimensions at all.
**Adopted:** the siting judgement, as the stated reason for the gain measurement in §6.2.

### G. Borrowed from inside this repo (rule 2)

| Taken | From |
|---|---|
| `part` / `log` / `clip`, and `solid` as the whole collision decision | `src/server/Lobby/Build.luau` |
| `CFrame.fromMatrix(middle, along, up)` for a part laid along a vector | `Markers.ring` / `Markers.ringUp` |
| the injected-reader seam, set once at the parent's last lines | `Markers.setReaders`, `Boar.setModelSource`, `Body.setAccessorySource` |
| destroy-and-rebuild so a folder's contents are structural | `Markers.build`, `Body.OUTFIT_NAME` |
| refuse-count-and-print instead of a silent guess | `Markers.build`'s refused stand |
| `GROUND_TOLERANCE_STUDS` = 1, unchanged and not re-derived | `Markers` |
| the `fromY` rule (*a downward ray can only hit what is below its origin*) | `ForestTest.groundAt`, `Body.groundUnder` |
| ground sampled at each footprint corner | `Places.groundsUnder` / `TreeGround.samples` |
| one pure predicate per question, over an injected provider | `Weapon.Rules` |
| `Seats.takeLine()` — the module never prints, the boot prints what it returns | `ForestTest.takeFlushLine` |
| 6 × 6 as the deck footprint | `Markers.POST_SIZE` |
| the timber tones | `Lobby.CONFIG.LODGE.LOG_COLOR` / `LOG_COLOR_ALT` |

---

## 9. The interface, and the call order (brief §4 item 6)

### 9.1 `ReplicatedStorage.HighSeats` — pure. No Instance, no service, no raycast.

```luau
export type Piece = {
    name: string,
    class: string,                 -- "Part" | "TrussPart"
    size: Vector3,
    cframe: CFrame,                -- WORLD, built from the stand point and the measured grounds
    material: Enum.Material,
    color: Color3,
    canCollide: boolean,           -- true for all seventeen
    canQuery: boolean,             -- true for all seventeen (design 4.2)
    castShadow: boolean,
}

HighSeats.DIMS: {...}                                   -- frozen, design 4.1
HighSeats.STANDS: { [string]: { number } }              -- frozen, design 6.1
HighSeats.PARTS_PER_SEAT = 17
HighSeats.MAX_JUMP_STUDS = 7.2                          -- StarterPlayer.CharacterJumpHeight's default
HighSeats.MAX_FOOT_SPREAD_STUDS = 4.0
HighSeats.MIN_GAIN_STUDS = 60
HighSeats.EYE_STUDS = 5.0                               -- the measurement probe's eye, design 6.2
HighSeats.AIM_RISE_STUDS = 5.0                          -- root 3.5 + 1.5, MEASURED by the Builder

-- WHICH STANDS, for a layout name. A fresh copy, so a caller cannot edit the table.
function HighSeats.standsFor(layoutName: string): { number }
function HighSeats.hasSeat(layoutName: string, standIndex: number): boolean
function HighSeats.capFor(standCount: number): number           -- math.ceil(standCount / 3)

-- WHERE THE FIVE FOOTPRINT SAMPLES ARE, as flat offsets from the stand point. PURE, so the reader
-- loop has nothing to get wrong and the spec names the same five points the build does.
function HighSeats.footprint(): { { dx: number, dz: number } }  -- 5 entries
function HighSeats.footprintRadiusStuds(): number               -- 5.1

-- THE ARITHMETIC, each its own function so each is its own spec case.
function HighSeats.deckTopFor(grounds: { number }): number?      -- max(grounds) + DECK_RISE; nil on a nil
function HighSeats.spreadOf(grounds: { number }): number?
function HighSeats.minYFor(deckTopY: number): number             -- == deckTopY (design 5.2)
function HighSeats.clearsRail(aimRise: number, dropStuds: number, rangeStuds: number): boolean
function HighSeats.blockedBand(aimRise: number, dropStuds: number): (number, number)  -- 11.3, 13.9

-- THE WHOLE SEAT, as seventeen pieces. `grounds` is the five readings in `footprint()` order.
-- Returns nil, reason for a seat that must not be built: a nil reading, or a spread over the cap.
-- DETERMINISTIC: the same arguments twice give the same seventeen pieces.
function HighSeats.plan(stand: Vector3, grounds: { number? }): ({ Piece }?, string?)
```

### 9.2 `ServerScriptService.ForestTest.Seats` — the one writer of `Workspace.HighSeats`

```luau
Seats.FOLDER_NAME = "HighSeats"
Seats.LAYOUT_ATTRIBUTE = "Layout"      -- stamped on the folder, so `ensure` is level-triggered

-- THE TWO READINGS, INJECTED BY THE PARENT AT LOAD TIME (`ForestTest`'s last lines). A child
-- module cannot require its parent -- `Markers.setReaders`' own stated reason -- and a third copy
-- of the two rays would be the second answer to "where is the ground" this repo is named after.
function Seats.setReaders(terrain: ((number, number) -> number?)?, ground: ((number, number, number?) -> number?)?)

-- LEVEL-TRIGGERED ON THE LAYOUT NAME, and this is the whole of the call order (design 9.3).
-- Returns how many seats stand. A folder already stamped with this layout AND holding the right
-- number of seats is left alone -- so the once-a-second `Waiting` read churns nothing and never
-- re-measures through a deck. Any other state is destroyed and rebuilt.
function Seats.ensure(layout: any, terrain: any?, ground: any?): number

function Seats.clear()                                    -- the ONE destroyer of the folder
function Seats.folder(): Folder?
function Seats.seatName(standIndex: number): string        -- "Seat<i>"

-- WHERE THIS STAND'S DECK IS, read off the Deck part this module built; nil for a stand with no
-- seat. THE FOLDER IS THE STATE: there is no remembered table to go stale (design 7.2).
function Seats.deckTopY(standIndex: number): number?

function Seats.stats(): { built: number, refused: number, reads: number,
                          worstFootGapStuds: number, worstSpreadStuds: number }
function Seats.takeLine(): string?                         -- the boot prints it; this never prints
```

### 9.3 The call order, as a numbered sequence

Inside `ForestTestBoot`'s **one** `world.markers` closure — called by `Match` once a second while
`Waiting` and once on entering `Assigning`, which is the only place that sees a layout change before
anybody is placed (`drive-layouts.md` §6.2):

```
1. ForestTest.layoutForDrive(Match.driveNumber(), ServerStorage:GetAttribute(DHForestLayout))
      -- unchanged. Idempotent per drive number, so the Waiting reads promote nothing after the first.
2. ForestTest.Seats.ensure(ForestTest.layout())
      -- NEW. Level-triggered on the layout's name:
      --   a. the folder exists, its `Layout` attribute == this layout, and it holds
      --      #HighSeats.standsFor(name) seats  ->  return, nothing is written, no ray is cast
      --   b. otherwise: Seats.clear(), then for each index in HighSeats.standsFor(name):
      --        read the five footprint samples (terrainYAt, then groundAt(x, z, t + 2)), §5.1
      --        HighSeats.plan(standPosition(i), grounds)
      --        nil  -> refused: count it, add it to the line, build nothing for that stand
      --        else -> create Workspace.HighSeats.Seat<i> with the seventeen pieces
      --      stamp the folder's `Layout` attribute LAST, so a half-built folder is rebuilt
3. ForestTest.Markers.build(ForestTest.hunterStandX(), ForestTest.layout())
      -- for each stand: Seats.deckTopY(i) first; non-nil -> the post's Y is the deck and the two
      -- readers are not asked; nil -> today's path, byte for byte (§7.2).
4. the boot prints Seats.takeLine() beside its existing `markers:` line
```

**Why `ensure` and not an `Assigning` edge handler** — this is the second amendment to the brief's
D7. The brief has the seats *"cleared with the picks and the rings at the `Assigning` edge when the
layout changes"*. An edge handler would be a **second place that decides when seats exist**, and
`Markers.build` runs at that edge anyway and once a second besides. One call site, level-triggered on
the layout name, cannot be missed, cannot fire twice and cannot be ordered wrongly — the
`Weapon.refreshArming` / `Horn.refreshCarry` discipline this repo already states (*"every
edge-triggered grant in this repo has been measured missing one"*). A rotation therefore can never
leave the road's seats standing in the ride, and the proof is structural rather than a handler.

**`ForestTestBoot` touches nothing else.** No new signal connection, no new Heartbeat, no new
attribute, no new remote.

### 9.4 `ForestTest.standArea` — the one changed line

```luau
function ForestTest.standArea(userId: number)
    local pick = ForestTest.pickOf(userId)
    if pick == nil or (pick :: any).lockedAt == nil then
        return nil
    end
    return {
        centre = Data.standPosition(pick.index, chosen.layout),
        radius = Data.PICK.standRadiusStuds,
        -- WHERE HIS PLATFORM'S FLOOR IS, or nil for "no height rule" -- which is every ground stand
        -- and every other world (design 5.2). Read off the seat the world built, so "where may he
        -- shoot" and "where is he standing" are one fact.
        minY = Seats.deckTopY(pick.index),
    }
end
```

### 9.5 `Markers` — the one new seam

```luau
-- WHERE A STAND'S DECK IS, INJECTED (the `setReaders` shape, same reason: this module is a child of
-- `ForestTest` and cannot require it). nil is "no seats in this world", which is every world but one.
function Markers.setSeatSource(fn: ((number) -> number?)?)

function Markers.build(standX, layout, ground?, canopy?, seats?): Set   -- `seats` is NEW and optional
```

`src/server/ForestTest/init.luau`'s last lines become:

```luau
Markers.setReaders(ForestTest.terrainYAt, Data.groundAt)
Markers.setSeatSource(Seats.deckTopY)
Seats.setReaders(ForestTest.terrainYAt, Data.groundAt)
```

### 9.6 What this system reads and writes, and who owns each

| Reads | Owner |
|---|---|
| `Data.standPosition`, `PICK.standRadiusStuds`, `LAYOUT_ORDER`, `standCount` | `src/shared/ForestTest` (frozen data, no run-time writer) |
| `ForestTest.terrainYAt`, `ForestTest.groundAt` | `src/server/ForestTest/init.luau` / `src/shared/ForestTest` — **injected**, never required |
| `ForestTest.layout()` | `src/server/ForestTest/init.luau` (the one chooser) |
| `Match.CONFIG.STAND_HEIGHT_STUDS`, `Body`'s `NEAR_PROBE_STUDS` | `src/server/Match/` — **read as numbers in a comment and a spec assertion only**; nothing here requires `Match` |
| `Places.LANE_STUDS` | `src/shared/Places` — read by the spec only, to assert the identity |
| **Writes** | |
| `Workspace.HighSeats` and every Instance in it | **`ForestTest.Seats`, and nothing else** |
| the Y of `Workspace.ForestMarkers.Stand<i>` at a seat stand | `ForestTest.Markers` (unchanged owner, one new branch) |
| `StandArea.minY` | `ForestTest.standArea` (unchanged owner) |
| the refusal reason `"off-platform"` on the wire | `Weapon` (unchanged owner), through `Rules.refuse` |

---

## 10. How it is tested (brief §4 item 7)

Every assertion below runs with **hand-written numbers and no Studio**, except §10.4.

### 10.1 `tests/server/high_seats.spec.luau` — NEW

1. **The table's shape.** A row for every name in `Forest.LAYOUT_ORDER` and none for anything else;
   `1 <= #row <= HighSeats.capFor(standCount)`; every index in `1..standCount`; strictly ascending;
   `row[k+1] − row[k] >= 2`; `HighSeats.STANDS` and `HighSeats.DIMS` both `table.isfrozen`.
   **Never the measured values.**
2. **`capFor`.** 9 → 3, 5 → 2, 6 → 2, 1 → 1.
3. **The plan is pure and complete.** `HighSeats.plan(Vector3.new(3030, 0, −2097), {140,142,139,141,143})`
   returns exactly `HighSeats.PARTS_PER_SEAT` (17) pieces, every one with a name, a class, a
   non-zero size, `canCollide == true`, **`canQuery == true`**; the same call twice is
   piece-for-piece identical; no piece's class is `Script`, `LocalScript` or `ModuleScript`.
4. **The deck is referenced to the WORST corner.** `deckTopFor({140,142,139,141,143})` == `143 + 12.5`
   == **155.5**. Shuffling the list changes nothing.
5. **Each leg is cut to its own ground, and the deck is level.** For that hillside, the four `Leg*`
   pieces' bottom faces equal their own corner ground − `FOOT_EMBED_STUDS`, and all four tops are
   equal to 1e-6. The `Ladder`'s bottom is sample 5's ground − `FOOT_EMBED_STUDS` and its top is
   `155.5 + 1.0`.
6. **The two arithmetic relations the whole design rests on, as assertions** — so changing a
   dimension trips a spec instead of silently opening a rule:
   * `DECK_RISE_STUDS − Match.CONFIG.STAND_HEIGHT_STUDS >= HighSeats.MAX_JUMP_STUDS`
     (12.5 − 3.5 = 9.0 ≥ 7.2) — the §5.2 jump bound;
   * `DECK_RISE_STUDS − DECK_SIZE.Y >= Match.CONFIG.STAND_HEIGHT_STUDS + 6`
     (12.0 ≥ 9.5) — the §5.4 floor-net bound, with 6 named as `Body`'s near probe.
7. **The rail band.** `clearsRail(5.0, 12.5, 10)` true (under the board), `clearsRail(5.0, 12.5, 12.5)`
   **false**, `clearsRail(5.0, 12.5, 30)` true; `blockedBand(5.0, 12.5)` == (11.3, 13.9) to 0.1.
8. **Refusal, and never a partial seat.** `plan` with a `nil` in `grounds` returns `nil` plus a
   reason; `plan` with a spread of 5 studs returns `nil` plus a reason; in both cases no piece list
   at all.
9. **The seats are visible to the one ground reader.** `"HighSeats"` is **NOT** in
   `Forest.GROUND_IGNORE` — the inverse of `places.spec`'s assertion that `Places.FOLDER` **is**.
   If a later task adds it, the hunter is snapped off his own deck and this case says so.
10. **The lane rule clears the footprint.** `Places.LANE_STUDS >= HighSeats.footprintRadiusStuds()`
    (12 ≥ 5.1) — the identity §5.4 leans on, asserted rather than described.
11. **`minY` is the deck's own top face.** `minYFor(155.5)` == 155.5.

### 10.2 `tests/server/weapon_rules.spec.luau` — added cases

12. `Rules.belowPlatform`: nil area → false; `{centre, radius}` with **no** `minY` → false; nil
    position → false; `minY = 155.5` with a root at 159 → **false** (he may shoot); the same with a
    root at 143.5 → **true**; `minY` of a non-number (a mis-wired provider) → false.
13. `Rules.ORDER` contains `OFF_PLATFORM` **immediately after** `OFF_STAND` and before `BEATER`.
14. **The order, tripped at once.** A context that trips `OFF_STAND` **and** `OFF_PLATFORM` answers
    `"off-stand"`. One that trips `OFF_PLATFORM` **and** `BEATER` **and** `LICENCE` answers
    `"off-platform"`. One that also trips `DRIVE_OVER` answers `"drive-over"`.
15. **Every ground stand is unchanged.** The four existing `Rules.refuse` cases, re-driven with
    `minY = nil` in the area, answer exactly what they answered before.
16. `Rules.noticeFor("off-platform")` == `"CLIMB TO YOUR STAND"`, and every `Rules.REASON` value has
    a `NOTICE` row (the existing closed-set case now covers five).

### 10.3 `tests/server/forest_markers.spec.luau` — added cases

17. **A seat stand's post goes on the deck, and the readers are not asked for it.** `Markers.build`
    with a `seats` fake answering 155.5 for stand 3 and nil elsewhere puts `Stand3` at y 155.5;
    counting calls in the two reader fakes shows **zero** reads at stand 3's column and today's two
    at every other stand.
18. **A world with no seats is byte-identical.** `Markers.build` with `seats` nil (and with a fake
    answering nil everywhere) produces the same posts, the same `line`, the same `driverStart`, the
    same `complete`, the same `missing` and the same `stats` as today.
19. **A seat stand is never refused.** With readers rigged to disagree by 12 studs at stand 3 and a
    `seats` fake answering 155.5 there, `stats.refused` is 0, `stats.lastMaxDelta` carries nothing
    from that column, and `complete` is true.
20. **A seat never blocks the drive.** With every stand seated and every seat refused (the `seats`
    fake answering nil), the set is exactly today's — so a refused seat is invisible to `Match`.

### 10.4 Live, and the frames (rule 5 — the point of the task)

The specs cannot see a frame, and this task is a **new visible model** (lesson L-008). So:

* **Rule E frames:** one eye-height frame **from the platform** in each place that has a seat, and
  one **from the ground looking at a seat**, beside ref-7. Inspected by the Builder before the
  review round, and shown to Karen at the stop (§11.4).
* **The `[seats]` line:** `n built, m refused, worst foot gap <g> studs, worst spread <s> studs` —
  the Rule E claim as a number, worst case over all five samples of all seats.
* **The live drive:** a full drive from a high seat with a shot boar (the hit card). The route is
  `python ftplay.py server lobby-go.luau` from `<runs-dir>` after Play starts (lesson L-095); the
  shot goes through the Forest Test's own shoot probe / `FireRequest:FireServer` with a reload
  between shots, **not** by aiming at a screen point (lesson L-023, task 149's 0/62).
* **Four numbers measured and reported in the same run:** `StarterPlayer.CharacterJumpHeight`; the
  aim origin's rise above the deck (`req.origin.Y − deckTopY`) and the blocked band that follows
  from it; the `[place]` line for a hunter placed at a seat stand (`ground=` must be the deck, `dY`
  under half a stud); and whether any animal or bot was seen standing on a deck (§7.4's one open
  question).
* **Two shots, by hand, at one seat stand:** one from the deck (fires), one from the ground directly
  below (refused, `NOTICE` reads `CLIMB TO YOUR STAND`, `stats.refusedBy["off-platform"]` increments,
  no shell spent).

### 10.5 No client spec, and the reason

Nothing is drawn client-side and the stand wire is unchanged: `Match`'s snapshot loop copies
`{ centre, radius }`, so `minY` never leaves the server. `tests/client/map_ui.spec.luau`,
`match_client.spec.luau` and `zz_tie_to_a_tree.spec.luau` are **not touched and need no new case**.
That is an honest N/A, not a gap.

### 10.6 Harness input

**None.** Brief D4: the climb is the Humanoid's own state, so there is no key to replay and
`tests/client/input_scenarios.txt` is unchanged.

---

## 11. Numeric targets, the scope, and the gate

### 11.1 Numeric targets

| What | Target |
|---|---|
| Deck top above the seat's **worst** footprint ground | **12.5 studs = 3.50 m** |
| Deck | 6 × 0.5 × 6 studs (1.68 m square) |
| Rail board top above the deck, all four faces | 2.4 studs = 0.67 m |
| Ladder | `TrussPart` 2 × *L* × 2, south face, top at deck + 1.0 |
| Parts per seat | **17** |
| Seats per layout | ≤ `ceil(standCount/3)`: road 3, edge 2, ride 2, track 2 — **9 in all** |
| Parts live at once, worst layout | **51** (against `Markers.ring`'s 432) |
| Never two adjacent stands | `row[k+1] − row[k] >= 2`, asserted |
| Minimum sight gain for a seat | 60 studs = 17 m = 3.3 s at `TROT_SPEED` |
| Footprint spread a seat accepts | ≤ 4.0 studs |
| Circle relief a seat prefers | ≤ 1.8 studs (§6.2 (d)); over it, one console line |
| **Rule E:** leg/ladder bottom above its own ground | **0.0 studs**, worst case over 5 samples × all seats |
| **Rule E:** leg/ladder bottom below its own ground | ≤ **0.8** studs (embed 0.3 + voxel 0.5) |
| Deck level: spread of the four leg tops | ≤ **1e-6** studs (arithmetic, not measured) |
| `minY` | = the deck's top face, exactly |
| Jump margin under `minY` | 12.5 − 3.5 − 7.2 = **1.8 studs** |
| Floor-net margin for a man under a seat | 12.0 − (3.5 + 6) = **2.5 studs** |
| Rail-blocked annulus (at a measured aim rise of 5.0) | **11.3 – 13.9 studs** (3.2 – 3.9 m), 2.6 wide |
| Seat circle inside the stand circle | footprint radius **5.1** < `standRadiusStuds` **12** |
| Lane clearance over the footprint | `LANE_STUDS` 12 − 5.1 = **6.9 studs** |
| Rays per `Seats.ensure` that builds | 5 terrain + 5 ground per seat, ≤ 3 seats = **≤ 30**, **once per layout change** |
| Rays per `Seats.ensure` that does not build | **0** — including every once-a-second `Waiting` read |
| Rays per `Markers.build` | unchanged at a ground stand; **two fewer** at a seat stand |
| Nearest boar spawn column to any seat footprint | ≥ **34.9 studs** (§7.4) |
| DEV place | **0 seats, 0 parts, 0 rays** — `ForestTestBoot` returns early |

### 11.2 Performance

`Seats.ensure` writes 51 parts at most, at a layout change, inside the same closure that already
destroys and rebuilds 10–11 markers. The once-a-second `Waiting` read is a `FindFirstChild`, an
attribute read and a child count: **no raycast and no write**. Nothing is added to any Heartbeat.

### 11.3 The scope (`tools/studio_mcp.py`, standing rule G)

`BLAST_RADIUS` — **one new row** (first match wins, and this prefix conflicts with nothing):

```python
    # KAREN'S HIGH SEATS (task 218): which stands carry a wooden Hochsitz, its dimensions and the
    # pure arithmetic of standing one on rolling ground. It resolves to `match` and not to a scope of
    # its own: the one writer of `Workspace.HighSeats` is `src/server/ForestTest/Seats.luau`, which
    # the `src/server/ForestTest/` row below already maps to `match`, and the stand rule it feeds is
    # read by the drive's own fire gate.
    ("src/shared/HighSeats/", "match"),
```

`src/server/ForestTest/Seats.luau` needs **no row**: `("src/server/ForestTest/", "match")` already
covers it.

`SCOPE_SPECS` — the new spec joins **two** tuples (the dual membership this table already uses):

```python
    # in "match":
              # Task 218: the high seats. `ForestTest.Markers` raises a stand's post onto a deck and
              # `ForestTest.standArea` carries its `minY`, both read by the drive and its fire gate.
              "tests/server/high_seats.spec.luau",

    # in "places":
                # Task 218: the lane rule is what keeps a seat's footprint clear, and this spec
                # asserts `Places.LANE_STUDS >= HighSeats.footprintRadiusStuds()` rather than
                # describing it -- so moving either number plays this spec.
                "tests/server/high_seats.spec.luau",
```

`tools/studio_mcp.py selftest` then passes: every spec belongs to a scope, and every scope names a
file that exists.

### 11.4 The gate — what it actually requires, said plainly

**Not one file this design touches is in `TWO_PLAYER_PATHS`** (`tools/agents.py`:
`src/server/Match/`, `src/server/MatchBoot.server.luau`, `src/client/Match/`,
`src/client/MatchBoot.client.luau`, `src/shared/Drive/`, `tests/client/Role.luau`,
`tests/server/match_*.spec.luau`, `zz_drive_boundary.spec.luau`,
`tests/client/match_client.spec.luau`, `outfit_client.spec.luau`, `zz_tie_to_a_tree.spec.luau`).
`src/server/Weapon/Rules.luau` is the weapon; `src/server/ForestTest/` and
`src/server/ForestTestBoot.server.luau` are the forest; `tools/studio_mcp.py` is the tools. **So the
gate requires the one-player `test` only**, for the review round and for the PR to `main`, and
`tools/agents.py` will not ask for a `[harness2]` line.

**That does not retire the brief's stop, and the Builder should still make it.** Brief §6 asks for
`NEEDS TEST2 218 <sha>` *"because the Architect's ruling on D7 may reach `src/server/Match/`"* — the
ruling does not reach it (§7.3, amendment 2) — **and** because Karen's look at the silhouette is
folded into that same stop (lesson L-008). The second reason stands on its own and is the better one:
this task ships a new visible model, and the frame has to be judged by eye before a review round is
spent. The Director decides whether the `test2` half of the stop is still wanted; nothing in this
design needs it.

---

## 12. What I could not verify (rule 8)

1. **`StarterPlayer.CharacterJumpHeight` in the live place.** `StarterPlayer` itself is not a
   Rojo-owned container here (only its two script folders are), so the value is Studio-owned and
   invisible from disk. The §5.2 ruling is valid for anything under **9.0 studs**; Roblox's default is
   7.2 and the legacy `JumpPower = 50` form is 6.37. **The Builder reads it in the place and reports
   it.** If it is ≥ 9.0, raise `DECK_RISE_STUDS` and stop.
2. **`TrussPart`'s exact `Size` clamp.** The docs page is a property index with no prose on it
   (source A). The Builder must set `Size = Vector3.new(2, L, 2)`, **read it back**, and report any
   difference. If the engine clamps the long axis too, the ladder is built as a stack of trusses of
   the clamped length and the part count rises — stated here so it is a known branch and not a
   surprise.
3. **The aim origin's rise above the deck.** §5.3's 5.0 studs is derived (root 3.5 + 1.5 to the eye),
   not measured. The blocked band is sensitive to it (2.6 studs wide at 5.0, 11.7 at 3.5), so it is
   measured live and the band is reported.
4. **Whether `PathfindingService` routes round a seat rather than through it.** The legs collide, so
   the navmesh should treat them as obstacles; nothing in this repo has measured a `TrussPart` or a
   0.5-stud post against `ComputeAsync`. §7.4 does not rest on it — the route points carry no ground
   read at all — but a file walking **through** the legs would look wrong, and the live drive is where
   that shows.
5. **Every number in `HighSeats.STANDS`.** They are the Builder's measurement. No Studio is reachable
   from this run.
6. **The two measured frames.** I cannot look at a screen. The frame list in §10.4 is what the
   Builder must inspect, and *inspected* means looked at.
7. **The `Workspace.HighSeats` / `ReplicatedStorage.HighSeats` name pair.** No tool was run against
   a live DataModel to confirm that `Workspace:FindFirstChild("HighSeats")` and
   `ReplicatedStorage:WaitForChild("HighSeats")` cannot be confused. The code shape makes it so
   (§3), but it is a claim about the shape, not a measurement.

---

## 13. Open decisions

### For Karen (feel and look) — **none of these blocks building**

1. **The rail's height.** Default **2.4 studs (0.67 m)**, a shooting rest on all four faces, which
   blocks a boar in a 2.6-stud ring under the seat (§5.3). The alternative, if she wants a rail that
   reads more like ref-7's, is 3.6 studs (the ASR A2.1 guard rail) at the cost of a wider blind band.
   One line.
2. **The timber tones.** `TIMBER` = `#58432D` (`Lobby.CONFIG.LODGE.LOG_COLOR_ALT`) for legs, girts,
   braces and the ladder; `BOARDS` = `#6B6253` (a weathered grey-brown) for the deck and the rail,
   because ref-7's boards are weathered and the lodge's logs are not. Two lines.
3. **Is nine seats across four places the right "some"?** The cap is `ceil(standCount/3)`. She will
   see road 3-of-9 and the three two-seat places and can say.
4. **A bench on the deck.** Not built (§4.2). Ref-7's hunter is seated; Roblox has no sit here and a
   bench takes a third of a 6-stud deck. One part if she wants it.
5. **Whether climbing feels right at 12.5 studs.** A `TrussPart` climb is slow. If the climb is
   tedious, the lever is `DECK_RISE_STUDS` — but it is bounded below by 9.0 (§5.2), so anything under
   that needs the platform rule re-derived.

### For the Director (scope) — **each has a decided default**

6. **`MIN_GAIN_STUDS = 60`** (§6.2). The bar a stand must clear to be worth a tower.
7. **`MAX_FOOT_SPREAD_STUDS = 4.0`** (§5.1). Over it a seat is refused and the stand stays a ground
   stand. Tighter means fewer seats; looser means one leg visibly twice its neighbour.
8. **The jump-apex case (§5.2) is accepted in writing**, with condition (d) of the selection rule
   removing it where the terrain allows and a console line naming it where it does not. Closing it
   properly would need a second geometry (a tighter flat radius for seat stands), which would be a
   second circle and is refused.
9. **The `test2` half of the brief's stop** (§11.4). The gate does not require it. The Karen-look half
   should happen regardless.
10. **A research note.** The Builder's position in brief §9.5 is that rule 1 wants one, and **it is
    right**: the truss climb, the per-corner drop-to-floor and the Hochsitz typology are all borrowed,
    and rule 2 wants the borrowing written down. `docs/research/2026-10-20-high-seats.md`, with §8 of
    this document as its sources section and §12 as its honest limits.

---

## 14. The deltas, as exact paste text (brief §9)

The Architect script writes only its own file. The five edits below are the Builder's to paste, in the
same commit as this design.

### 14.1 `docs/design/forest-drive.md` — append to §4.1, after §4.1.6

```markdown
#### 4.1.7 A stand's post may sit on a DECK, not on the terrain (task 218)

**Since task 218 the stand is no longer always on the ground.** `docs/design/high-seats.md` puts a
wooden high seat at some stands of each layout, and the hunter is placed **on its platform** through
the seam this section already describes: `Body.placementFor` reads `post.Position` and `post.Size.Y`,
so moving the marker part up 12.5 studs is the whole of it and **nothing in `Match` changes**.

`Markers.build` gains one branch and one injected seam, `Markers.setSeatSource(fn)` — the
`setReaders` shape, set at `src/server/ForestTest/init.luau`'s last lines to
`ForestTest.Seats.deckTopY`:

* **a stand with a seat:** the post's Y is the seat's own deck top, read off the `Deck` part the
  seat owner built, and **the two ground readers are not asked for that stand at all**. They cannot
  be: `Data.groundAt` casts from 600 studs up, would see the deck 12.5 studs over the terrain, and
  `GROUND_TOLERANCE_STUDS` is 1 — so every seat stand would be refused and the drive would sit in
  `WAITING forest:stands`. The column was already measured **once, on clean ground**, by the seat's
  own owner, from an origin two studs above the terrain at each of five footprint samples
  (`high-seats.md` §5.1).
* **a stand with none:** §4.1.5 exactly, byte for byte. `tests/server/forest_markers.spec.luau`
  asserts that identity.

A seat stand contributes nothing to `stats.lastMaxDelta` and is never counted in `stats.refused`.
**A seat is never a `missing` string**: a seat that could not be built leaves its stand a working
ground stand, so nothing about §4.1.5's refusal path changes and no seat can hold the drive in
`Waiting`.

**The call order** (`high-seats.md` §9.3) is inside this section's own `world.markers` closure:
promote the layout, then `ForestTest.Seats.ensure(layout)` — level-triggered on the layout's name, so
it writes nothing and casts no ray on the once-a-second `Waiting` read — then `Markers.build`.
```

### 14.2 `docs/design/drive-layouts.md` — append to §3.2, and one row in §14

```markdown
#### 3.2.1 A layout's stands may carry a HIGH SEAT, and that is not a field either (task 218)

Since task 218 some stands of every layout carry a wooden high seat (`docs/design/high-seats.md`).
**The `Layout` record is unchanged** — `drive-places.md` §1.2.1's rule holds, and for the same
reason: which stands carry a seat is a **second module that READS a layout**,
`ReplicatedStorage.HighSeats`, whose `STANDS` table is keyed by layout **name**. The seam is one
direction only: `HighSeats` requires nothing of `ForestTest` but its data, and nothing in
`src/shared/ForestTest/` mentions `HighSeats`.

It is **derived, not stored**, exactly as §3.2's other derived facts are: the seat's five footprint
samples come from `standPosition(i, layout)` and `HighSeats.footprint()`, and its deck Y comes from
the terrain measured under those five points. Adding a layout therefore adds **one row to
`HighSeats.STANDS`** and nothing to the record.

The caps are a rule rather than a taste: at most `ceil(standCount / 3)` seats per layout (road 3,
edge 2, ride 2, track 2 — nine in all) and **never two adjacent stands**, so a hunter always has a
ground neighbour and the line never reads as a row of towers.
```

```markdown
| `docs/design/high-seats.md` | **added by task 218.** A layout's stands may carry a high seat; the table that says which lives in `ReplicatedStorage.HighSeats`, keyed by layout name, and the `Layout` record is unchanged (§3.2.1) |
```

### 14.3 `docs/design/drive-places.md` — amend §1.2 items 1 and 2

```markdown
1. **Must not add a field to the `Layout` record.** `src/shared/ForestTest/init.luau` stays what task
   157 made it — the one world-**geometry** seam. The dressing is a **second system that READS a
   layout** (`src/shared/Places`), and the seam between them is one direction only: `Places` requires
   `ForestTest`; `ForestTest` never requires `Places`. (Already true: `src/shared/Places/init.luau`
   requires `ReplicatedStorage.ForestTest` and nothing in `src/shared/ForestTest/init.luau` mentions
   `Places`.) **Task 218 is the second system to follow this rule rather than bend it**:
   `ReplicatedStorage.HighSeats` keys its table by layout NAME for exactly this reason
   (`docs/design/high-seats.md` §3, `drive-layouts.md` §3.2.1).
2. **Must not move, re-parent, scale, re-colour or destroy anything in `Workspace.OurForest`,
   `Workspace.Session` or `Workspace.LobbyAssets`.** Clone only (BRIEF D7, rule 7). The one thing this
   system may destroy is **its own** folder, `Workspace.DrivePlaces`.
   **THIS WORLD NOW OWNS A SECOND BUILT FOLDER (task 218): `Workspace.HighSeats`**, whose one writer
   is `src/server/ForestTest/Seats.luau`. `Places` must not create, move, re-colour or destroy
   anything in it, and `Seats` must not touch `Workspace.DrivePlaces`. **The lane rule already clears
   it and no new rule is needed:** nothing is planted within `halfStripStuds + LANE_STUDS` of any
   place's line, `LANE_STUDS` is 12, and a seat's footprint radius is **5.1 studs** about a stand
   point that is on the line — so the clear ground is 6.9 studs wider than the widest seat and no tree
   can be planted through one. `tests/server/high_seats.spec.luau` asserts
   `Places.LANE_STUDS >= HighSeats.footprintRadiusStuds()` rather than describing it.
   **`Workspace.HighSeats` is deliberately NOT in `ForestTest.GROUND_IGNORE`** (which `Places.FOLDER`
   **is**, §10.1): a deck is a thing a body stands on, and the world's one ground reader must say so
   or there are two answers. `high_seats.spec` asserts that absence.
```

### 14.4 `GAME_DESIGN.md` — one new row in the *System owners* table

```markdown
| **The high seats** (`Workspace.HighSeats`: the wooden Hochsitz at some stands of each drive place — its legs, girts, braces, deck, rail boards and truss ladder) -- **BUILT (Task 218)** | `ServerScriptService.ForestTest.Seats`, the only writer of that folder and of every Instance in it, called from exactly one place: `ForestTestBoot`'s `world.markers` closure, through `Seats.ensure(layout)`, which is **level-triggered on the layout's name** — so a rotation can never leave the road's seats standing in the ride, and the once-a-second `Waiting` read writes nothing and casts no ray. It runs **only** in the Forest Test place (`ForestTestBoot` returns early anywhere else), so the DEV place where the harness runs never sees the folder. **It writes no character position, no team, no terrain and no marker**: the hunter reaches the deck through `Match.Body.placementFor` + `Body.onGround` with **no new arithmetic in `Match`**, because `ForestTest.Markers` raises that stand's `Stand<i>` marker to the deck top and `placementFor` reads `post.Position` and nothing else. The ground under a seat is measured **once, on clean ground, at five footprint samples** (four leg feet and the ladder's foot), each read with `ForestTest.terrainYAt` first and then `ForestTest.groundAt(x, z, terrain + 2)` — the `fromY` rule, so a seat can never measure itself through its own deck — and each leg is cut to **its own** ground while all four tops are one number, so the deck is level and no leg hangs or sinks. A sample that cannot be read, a 1-stud disagreement between the two readers, or a footprint spread over 4 studs **refuses that seat**: counted, printed, and the stand stays a working ground stand. A seat is **never** a `missing` string and can never hold the drive in `Waiting`. Its parts are the deliberate opposite of every other part this world builds — **`CanCollide` AND `CanQuery` both true** — because a deck is a thing and not a reference, and a pellet that passed through 0.14 m of timber would be the inverse of the fault `Markers`' `CanQuery = false` prevents. **`ReplicatedStorage.HighSeats` is the frozen DATA with no run-time writer**: which stands carry a seat (keyed by layout NAME, so the `Layout` record is untouched — `drive-places.md` §1.2.1), every dimension, and the pure arithmetic — the deck's Y from the worst footprint corner, each leg's cut, `minY`, and whether a shot clears the rail. **The stand rule moves up onto the platform through one optional field and one new predicate, and no owner changes:** `ForestTest.standArea` carries `minY = Seats.deckTopY(i)` (nil everywhere else, which is "no height rule"), `Weapon.Rules.belowPlatform` is the one question asked about it, and `Rules.outsideStand` stays flat and untouched. `minY` **is** the deck's top face with no margin, because the margin the brief proposed is reachable by a jump (12.5 − 3.5 − 7.2 = 1.8 studs of air, and `high_seats.spec` asserts that bound so lowering the deck trips a spec). `minY` is **not** published: `Match`'s snapshot copies `{ centre, radius }` and no client changes | `src/server/ForestTest/Seats.luau`, `src/shared/HighSeats/init.luau`, wired in `src/server/ForestTest/init.luau` and read in `src/server/ForestTest/Markers.luau` | [high seats](docs/research/2026-10-20-high-seats.md), [design](docs/design/high-seats.md) |
```

### 14.5 `docs/research/INDEX.md` — one new row, at the top of the table

```markdown
| 2026-10-20 | [high-seats](2026-10-20-high-seats.md) | A wooden Hochsitz at some stands of each drive place, and the stand rule moved up onto its platform (Task 218) | Karen, 2026-10-10: *"we just will improve standing places, maybe will add towers where they can stand"*, with **ref-7** -- an open raised wooden stand at a forest road, a plain weathered-timber rail, no roof: a **Drückjagdbock**, not a closed *Kanzel* (Wikipedia's *Hochsitz* typology, CC BY-SA 4.0, is what settles that). **Three borrowings, none of them new here.** The ladder is a **`TrussPart`** and the climb is the engine's own `Climbing` state, so WASD, a thumbstick and mobile all work and **no input owner and no key are added** -- Luanti says it in one word (`climbable`, LGPL-2.1+, the same API `Weapon.Rules` already borrows `core.is_protected` from). The ground fit is **Valve's `UTIL_DropToFloor`** (Source SDK 2013, archived, source-available non-commercial) applied **per footprint corner** -- lesson L-024's rule and `Places.groundsUnder`'s own shape -- at five samples, each read with `terrainYAt` FIRST and then `groundAt(x, z, terrain + 2)`, which is the `fromY` rule task 192 paid for and is what makes it **impossible** for a seat to measure itself through its own deck (lesson L-025). The German guard-rail height of 1.00 m (ASR A2.1) is written down **as the number this design does not use**: the rail is a shooting rest at 0.67 m on all four faces, because at 3.6 studs the arithmetic blocks a normal side shot between 25 and 42 studs, and at 2.4 the blind ring is 2.6 studs wide directly under the seat -- a band a real Hochsitz has too. **D7's snap is ruled the hard way and the brief is amended twice.** The seats are **visible** to the world's one ground reader (`Workspace.HighSeats` is deliberately NOT in `GROUND_IGNORE`, and a spec asserts the absence), because a deck is a thing a body stands on; the stand column stays honest because `Markers.build` **asks the seat where its DECK is, read off the Instance the seat owner built, and does not ask the two readers for that stand at all** -- the folder IS the state, so there is no remembered table to go stale (amendment 1, against the brief's "a seat REMEMBERS"); and `Seats.ensure` is **level-triggered on the layout's name from one call site** rather than an `Assigning` edge handler, so a rotation cannot leave the road's seats standing in the ride (amendment 2). **The brief's named residual risk is CLOSED by arithmetic, not accepted:** `Places` is handed `terrainYAt` and never asks `groundAt` at all; every boar spawn column is at least 34.9 studs from any footprint; `Runtime:placeAt` only ever reads a crumb the leader **walked**, and a boar cannot climb a ladder; route waypoints carry no ground read; and a bot hunter on the deck is correct. **And the brief's own margin arithmetic is wrong and is corrected:** `minY = deckTopY − 2` is reachable at a jump apex, because a Roblox jump is 7.2 studs and not "4-5" -- so `minY` IS the deck's top face, with 1.8 studs of air under it and 3.5 above it, and `high_seats.spec` asserts `12.5 − 3.5 >= 7.2` so lowering the deck trips a spec instead of silently opening the rule. The floor net under a seat is safe by the same kind of arithmetic (deck bottom 12.0 above the near probe's origin at 9.5), and the soft wall can never act on a man on his platform (deck half-width 3.0 inside a 12-stud circle) | 
```

---

## 15. Deviations from the brief, listed in one place

| Brief | This design | Why |
|---|---|---|
| D3: `minY = deckTopY − MARGIN`, margin ~2 studs, *"no jump from the ground can reach it"* | **`minY = deckTopY`**, no margin | The claim is false: a Roblox jump is 7.2 studs (default `CharacterJumpHeight`), not 4–5, so the margin is reachable by 0.2 studs. §5.2 |
| D7: *"a seat REMEMBERS the terrain it was built on"* and `Markers.build` reads that memory | `Markers.build` asks the seat **where its DECK is**, off the Instance | The folder is the state; a remembered table is a second copy that can go stale. §7.2, amendment 1 |
| D7: the seats are cleared *"at the `Assigning` edge when the layout changes"* | `Seats.ensure`, **level-triggered on the layout name from the one call site** | An edge handler would be a second decider of when seats exist, and `Markers.build` already runs at that edge. §9.3, amendment 2 |
| D7: the residual risk is *"rare, visible and self-correcting"*, to be accepted | **Closed by arithmetic**, caller by caller | §7.4. Six of seven callers cannot reach a deck; the seventh (a bot hunter) is correct |
| §3: a change to `Match.Body` *"is `TWO_PLAYER_PATHS`"* | **No `Match` change at all**, so nothing in `TWO_PLAYER_PATHS` is touched | §7.3, §11.4 |
| D1 / D5: *"a plank rail round the deck"* | Four boards with a **2.6-stud opening in the south face** | The ladder is on the south face; a continuous rail would mean climbing through a solid board. §4.2 |
| D5: implies one rail height | One height, **2.4 studs**, named as a deviation from ASR A2.1's 1.00 m | §5.3, §8 source E |
