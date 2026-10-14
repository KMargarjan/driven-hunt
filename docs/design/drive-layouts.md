# Design: drive-layouts — more than one place to stand in the Forest Test

Task 179. Architect. Input: `reviews/task-179/BRIEF.md` (which overrides anything older) and
`docs/research/2026-10-14-drive-layouts.md` (quoted below as "the note").

KAREN, 2026-10-13 ~13:55, verbatim:

> *"we will improve terrain that not all a time same place hunters standing and not the same terrain
> for beaters / we will make view for hunter from different places and diffretent tree lines road ect
> like in real life"*

This designs **one system**: a table of named drive layouts in the Forest Test's world module, one
chosen per drive by one writer, read by everything that already asks that module where the road is.
It designs no new drive, no new phase, no new axis and no new animal behaviour.

Deltas it forces on `docs/design/forest-drive.md` and `docs/design/map-ui.md` are in §14.

---

## 1. What it must do, and what it must not do

### 1.1 Must do

| Must | Why |
|---|---|
| Hold **three** named layouts as frozen data in `src/shared/ForestTest/init.luau`, each a different place in this world: its own line position, shape, stand count and spacing | Brief decisions 1 and 2. Task 157 made that module the one world-geometry seam; a second home is a second answer |
| Deal **one per drive**, never the same twice running, from a shuffled bag | Brief decision 5, note §4 |
| Let the Director **force one** with a Studio attribute, the `DHForestStartRole` idiom | Brief decision 6 |
| Answer **every** geometry question from the one live layout: the markers, the stand rings, the pick, the bots' lanes and goals, the resting wood, the waves, the boar's exit, the hunter's map | Rule 3. The note's §3: *"the hunter's map on a different road from the one his feet are on"* is the failure being designed out |
| Keep the beaters' walk at **580 studs in every layout**, so a drive stays the ~120 s task 162 measured | Brief decision 4 |
| Keep `road` **unchanged in every number**: centre (3030, 138, −2097), amplitude 30, divisor 70, half-width 20, 9 stands 150 apart, exit −2377 | Brief decision 2 |
| Rebuild everything a layout change invalidates, **before anybody is placed on it** | Brief §2.4. §6 is the whole answer, and it is the one change this task makes outside the forest |

### 1.2 Must not

1. **Must not parameterise the drive's axis.** Every layout pushes south along −Z. North is a *sign*
   in `Brain:_outcome` (`position.Z <= exitZ`), `Boar.CONFIG.field.exitZ`, `ForestTest.lineFrontAt`,
   `wavePoint`, `restPoint`, `encounterStage`, `markers.line.normal = Vector3.zAxis`,
   `SafetyArc.isForbidden` and `ForestTest.DRIVE_BEARING_DEG`. §13 says where the seam for it goes.
2. **Must not carve, paint or delete anything.** All three layouts sit on the ground as Studio built
   it (brief decision 8, rule 7).
3. **Must not ship a fourth layout.** Of 1,054 points sampled inside the wood, **nine** have nothing
   colliding within 45 studs and no two are adjacent (note §5). There is no clearing, so the
   clearing-with-a-high-seat the dispatch asked about cannot be placed in this world; making one
   means deleting Studio-built trees, which is rule 7 and Karen's call. Not shipped, and the reason
   is a measurement, not a preference.
4. **Must not let the client choose or derive a layout.** It reads a published name and nothing else
   (§5).
5. **Must not hold a knob no shipped layout turns.** A field that is the same in all three is a
   shared constant, not three copies of it (brief §2.1). §3.3 lists what therefore stays shared.
6. **Must not produce a silent wrong answer.** No layout-less drive, no "road by default" on the
   server, no map drawn from a guessed layout, no pick on a stand the live layout does not have.
7. **Must not change the DEV place.** Nothing here is reachable there: `ForestTestBoot` returns
   early unless `Map.EXPECTED_WORLD == "forest-test"`. The one `Match` change is proved
   value-identical in DEV in §6.4.
8. **Must not touch** the boar's behaviour, the horn, the weapon, the shop, the lobby's build, the
   drive's length, the stand radius, the spook reaches or the wave rhythm (brief §3).

---

## 2. The pattern adopted, and why

**THE WORLD HOLDS SEVERAL SETS OF ENTITIES AND NAMES WHICH SET IS LIVE.** `ForestTest.Markers`'
header already carries the borrowed half — *the world places the entities the game mode queries*
(`info_player_terrorist`, `AGameModeBase::FindPlayerStart`) — and this extends it by exactly one
level, which is the shape a dedicated server has used for twenty years: the server holds a
**mapcycle**, picks the next entry, and **tells the clients**; the clients never pick.

**The geometry functions take the layout**, which is the shape `src/shared/ForestTest/init.luau`
already uses for `spook`, `beater` and `rest` (`ForestTest.sweepAheadStuds(spook, beater)`,
`ForestTest.encounterStage(..., spook, beater)`): a pure function reads a table handed in. So
`ForestTest.roadZ(x)` becomes `ForestTest.roadZ(x, layout)` and a spec can ask any layout anything
with no world running.

**The choice is a bag, not a re-roll** (note §2 sources D and E): deal each name once, reshuffle when
empty, and swap the first of a fresh bag with the second when it equals the one just played. A
memoryless `math.random(n)` deals the same layout twice and players read that as broken; a re-roll
loop is unbounded; a bag also guarantees Karen is *dealt* every layout, which matters because she is
judging the look of each one and a layout she never sees is a layout she cannot judge.

**One writer, one reader-of-record** (rule 3): `ServerScriptService.ForestTest` chooses and
publishes; everything else reads. Sources, licences and what each gets wrong: §12. What is borrowed
from inside this repo: §12.7.

---

## 3. The layout record

### 3.1 The type, and what each field replaces

```luau
-- src/shared/ForestTest/init.luau
export type Layout = {
    name: string,            -- the key, and the string published to clients
    label: string,           -- what a HUD may print. Nothing draws it in this task
    centre: Vector3,         -- the line's middle. Y is a FALLBACK ground only (§3.4)
    amplitudeStuds: number,  -- the sine's amplitude. 0 IS a straight line: one shape, not two
    standCount: number,
    standSpacing: number,
    halfSpanStuds: number,   -- how far the line runs either side of centre.X
}
```

| Field | Replaces today | road | edge | ride |
|---|---|---|---|---|
| `name` | — | `"road"` | `"edge"` | `"ride"` |
| `label` | — | `"Road"` | `"Forest edge"` | `"Ride"` |
| `centre` | `ForestTest.CENTRE` | `(3030, 138, −2097)` | `(3480, 185, −3000)` | `(3350, 152, −2600)` |
| `amplitudeStuds` | `ForestTest.ROAD.amplitudeStuds` | `30` | `0` | `0` |
| `standCount` | `ForestTest.STAND_COUNT` | `9` | `6` | `5` |
| `standSpacing` | `ForestTest.STAND_SPACING` | `150` | `150` | `130` |
| `halfSpanStuds` | `ForestTest.HALF_SPAN` | `800` | `435` | `320` |

Stand x, from `standX(index, layout)` = `centre.X + (index − (count+1)/2) · spacing`:
road **2430…3630**, edge **3105…3855**, ride **3090…3610** — the three the note measured, to the stud.

### 3.2 What is DERIVED and therefore is not a field

```luau
ForestTest.SHAPE = { wavelengthDivisor = 70, halfWidthStuds = 20 }   -- shared: no layout varies these
ForestTest.EXIT_SOUTH_STUDS = 250
ForestTest.GROUND_Y = 138

ForestTest.exitZOf(layout?)       -- centre.Z − amplitudeStuds − EXIT_SOUTH_STUDS
ForestTest.beaterNorthStuds()     -- LINE.spawnNorthStuds 180 + BEATER.behindLineStuds 400 = 580
ForestTest.standSpan(layout?)     -- { minX, maxX } of the stands themselves
ForestTest.corridorOf(layout?)    -- the ground a drive uses: standSpan x [exitZ, centre.Z + 580]
ForestTest.boundsOf(layout?)      -- the boar field's bounds, today's formula per layout
ForestTest.fieldFor(layout?)      -- { bounds = boundsOf, exitZ = exitZOf, groundY = GROUND_Y }
```

`exitZOf`: road **−2377** (today's constant, to the stud), edge **−3250**, ride **−2850**.
Brief §2.2 is right that `EXIT_Z` cannot stay a constant: −2377 is **223 studs NORTH of the ride's
line**, so a boar on the ride would be despawned before it reached the hunters.

`boundsOf` is `ForestTestBoot`'s existing formula with the layout's numbers in it:

| | minX | maxX | minZ | maxZ |
|---|---|---|---|---|
| road | 2230 | 3830 | −2477 | −1197 |
| edge | 3045 | 3915 | −3350 | −2100 |
| ride | 3030 | 3670 | −2950 | −1700 |

The road row is **bit-identical to the live `field` table** in `ForestTestBoot`, which is how "the
road layout is unchanged" is checked rather than claimed (§10.1).

`halfSpanStuds` is the only number I chose rather than derived, and the arithmetic is written beside
each: half the stand span plus run-out — road `600 + 200` (today's, frozen by brief decision 2), edge
`375 + 60`, ride `260 + 60`. **60 studs is about half a stand spacing**, so a boar fleeing past the
end stand has half a stand's width of ground before `Brain.insideField` clamps it. The run-out is not
200 for the two new ones **because of the lodge**: at 200 the edge's west bound would be x 2905 and
the lobby's own built field is x 2740…2960 (`Lobby.CONFIG.FIELD.SPAN_STUDS` 220, centred on
`Lobby.anchorFor("forest-test")` = (2850, −2950)) — an overlap, i.e. a boar on the lodge lawn. At 60
the clearances are **85 studs (edge)** and **70 studs (ride)**, 75 and 60 after
`Boar.CONFIG.BOUNDS_SLACK` 10. §9.4 asserts it.

### 3.3 What stays shared, because no shipped layout varies it

`SHAPE.wavelengthDivisor` (70) and `SHAPE.halfWidthStuds` (20); `PICK`; `DRIVERS`; `BEATER` minus
`laneSpacingStuds`; `SPOOK` and its `SWEEP`; `LINE`; `REST`; `SCHEDULE`; `DRIVE`;
`DRIVE_BEARING_DEG`, `PUSH_BEARING_DEG`, `PUSH_LABEL`, `PUSH_TEAM`; `MAX_BOARS`;
`MAX_BODIES_IN_A_COLUMN`.

This is a **named deviation from the brief**. Brief §2.1 lists the wavelength divisor and the
half-width inside the record, and also says *"a field no shipped layout varies must not exist"*. The
two sentences disagree, and the second is the stricter and the one with the reason behind it: three
copies of 70 and three copies of 20 are a constant written three times. Only `amplitudeStuds` varies
(30 / 0 / 0), so only `amplitudeStuds` is in the record — and because 0 is a legal amplitude there is
still **one shape and not two**, which is what the brief's sentence was protecting.

`BEATER.laneSpacingStuds` is **removed**: it is `standSpacing` by definition (task 167's whole
reason), so it becomes `ForestTest.laneSpacing(layout)` returning `layout.standSpacing`. §9.3 keeps
task 167's property as an assertion over every layout instead of over one constant.

### 3.4 `centre.Y` is a fallback, and `GROUND_Y` is not per layout

Every production reader of a layout point re-measures the ground: `Markers.build` through
`Markers.groundFor`, `ForestTest.beaterStartPosition` through `terrainYAt`, `ForestTest.restSpot`
and `releaseLine` through `Data.groundAt`, each with `or <centre.Y>` as the answer when the raycast
fails. So `centre.Y` is only ever reached when there is no terrain in that column, and it is set to
the mean of the layout's own measured stand terrain: road **138** (the Director's build centre,
unchanged), edge **185** (the mean of §5's 148, 148, 172, 192, 223, 228), ride **152** (the midpoint
of §5's measured 141…163 — the note gives the range, not the six values).

**`field.groundY` stays 138 for every layout**, and that is deliberate rather than lazy.
`Brain:_outcome` despawns at `position.Y < field.groundY − config.FALL_LIMIT` (50), so a per-layout
`groundY` of 185 would make 135 the floor on an edge drive — and §5 measured terrain as low as
**99** inside this wood, with no sample at all inside the edge's own x range at the z rows where the
ground dips. A number I cannot bound must not be allowed to despawn animals, and 138 − 50 = **88**
is below every value §5 measured anywhere. The y of a target point is the only other reader, and
`Boar`'s own comment already says this single number is *"FALSE here"* for a world that climbs 90
studs; 138 keeps it exactly as false as it is today and no falser.

### 3.5 The table and the order

```luau
ForestTest.LAYOUTS = { road = {...}, edge = {...}, ride = {...} }   -- deep-frozen
ForestTest.LAYOUT_ORDER = { "road", "edge", "ride" }                -- the bag's contents, in one place
ForestTest.ROAD_LAYOUT = ForestTest.LAYOUTS.road                    -- the default parameter, named for what it is
ForestTest.DEFAULT_LAYOUT = "road"
ForestTest.layoutNamed(name: string?): Layout?                      -- PURE. nil for a name the table does not know
ForestTest.layoutNames(): { string }                                -- a fresh copy of LAYOUT_ORDER
```

Frozen with `Drive.deepFreeze`, the idiom `Match.CONFIG` and `Shotgun.CONFIG` already use, so there
is no run-time writer of a layout.

---

## 4. The signatures, function by function

**The rule, stated once.** In the **shared** module the layout is a **trailing optional** parameter
whose default is `ForestTest.ROAD_LAYOUT`. In the **server** modules it is **required**, or read from
`state.layout`. The reason is the one brief §2.2 asks for: a default that means "the live layout"
cannot exist in a replicated module, because on a client that module has no live anything — it would
answer `road` for ever and draw the wrong road, which is the exact defect the note's §3 names. A
default named `ROAD_LAYOUT` means *the road layout* by its own name, so a reader who omits the
argument has said what they got. On the server there is exactly one live answer, so a default there
could only ever hide a stale read, and it is refused.

### 4.1 `src/shared/ForestTest/init.luau`

| Today | After |
|---|---|
| `roadZ(x)` | `roadZ(x, layout?)` |
| `standX(index)` | `standX(index, layout?)` |
| `standPosition(index)` | `standPosition(index, layout?)` |
| `roadPointAt(x)` | `roadPointAt(x, layout?)` |
| `beaterStart(standX, sideOffset?)` | `beaterStart(standX, sideOffset?, layout?)` |
| `beaterLaneOffset(index?)` | `beaterLaneOffset(index?, layout?)` |
| `wavePoint(standX, spec)` | `wavePoint(standX, spec, layout?)` |
| `restPoint(standX, spec, side?, out?)` | `restPoint(standX, spec, side?, out?, layout?)` |
| `laneLookPoint(standX, spec, spot, rest)` | `laneLookPoint(standX, spec, spot, rest, layout?)` |
| `offLaneStuds(standX, spec, spot)` | `offLaneStuds(standX, spec, spot, layout?)` |
| `sweepAheadStuds(spook, beater)` | `sweepAheadStuds(spook, beater, layout?)` |
| `noticeAheadStuds(spook, beater)` | `noticeAheadStuds(spook, beater, layout?)` |
| `encounterStage(ahead, gap, alertedFor, spook, beater)` | `… , beater, layout?)` |
| `driverStart(index, count)` | `driverStart(index, count, layout?)` — **no production caller** |
| `lineFrontAt(beaters, x)`, `sweepCatches`, `stockStep`, `noticeStuds`, `alertSeconds`, `beaterSpookStuds`, `characterOf`, `groundAt` | **unchanged**: none of them reads a layout |

`driverStart`'s only caller in the repo is `tests/client/map_ui.spec.luau`. It gets the parameter for
consistency and is named here as a candidate for archiving with a note (rule 7), the same treatment
`forest-drive.md` §7.2 gave `ForestTest.drive` and `driveIndexAt` — *a function nothing reads is the
next reader's trap*. Not archived in this task: that is a separate, trivial commit and the brief's
time box is four hours.

`bandDepth` (the file-local behind `sweepAheadStuds` / `noticeAheadStuds`) changes from reading
`beater.laneSpacingStuds` to taking the spacing: `bandDepth(reach, laneSpacing, spook)`. With the
shipped numbers the bands come out notice **100** / flush **30** (spacing 150) and notice **107** /
flush **30** (spacing 130) — notice is wider than flush in both, which is the order
`forest_stand.spec` already asserts and the whole point of task 172.

> **Corrected during the build (round 2's review).** This said flush **61** at spacing 130, which is
> `sqrt(89² − 65²)` — the reach *before* task 172 split it in two. With the shipped
> `SPOOK.BEATER_STUDS` of **71** the formula is `sqrt(71² − 65²)` = 28.6, i.e. imaginary against half
> a 150-lane and below the floor against half a 130 one, so the answer is `MIN_AHEAD_STUDS` = **30**
> at both spacings. `bandDepth`'s own header in `src/shared/ForestTest/init.luau` carried the same
> stale 89/47.9 and was corrected with it. Nothing computed from it: `forest_stand.spec` asserts the
> ORDER of the two bands, not their values.

### 4.2 REMOVED, and archived with a note (rule 7)

`ForestTest.CENTRE`, `ForestTest.ROAD`, `ForestTest.STAND_COUNT`, `ForestTest.STAND_SPACING`,
`ForestTest.HALF_SPAN`, `ForestTest.EXIT_Z`, `ForestTest.BEATER.laneSpacingStuds`.

**Removed and not kept**, which is brief §2.2's explicit question. Keeping `ForestTest.CENTRE`
alongside a live layout is two answers to "where is the line", and the next reader cannot tell which
one he has — that is the defect `PROJECT_CONTEXT.md` describes three times. Their call sites are a
mechanical sweep and every one is named in §7.

### 4.3 `src/server/ForestTest/Markers.luau`

```luau
Markers.build(standX: number, layout: Layout, ground?, canopy?): Set
Markers.ring(standIndex: number, radiusStuds: number, layout: Layout, ground?, canopy?): number
```

`layout` is the **second, required** parameter in both, on purpose: an un-updated caller then errors
on `layout.centre` instead of silently measuring the road. The set gains one field:

```luau
Set.layout = layout.name     -- which layout this set was measured on
```

so a console line, the `[ForestTestBoot] markers:` report and any later reader can say which world
the drive is standing on rather than assuming. `missing` strings keep their shape and gain the count
they already print: `"forest:stands (0 of 6)"`.

### 4.4 `src/server/ForestTest/init.luau` — the chooser

```luau
-- state, beside state.picks and state.requests
state.layout      = Data.ROAD_LAYOUT          -- the LIVE one. Never nil, so nothing is layout-less
state.layoutName  = Data.DEFAULT_LAYOUT
state.layoutDrive = nil :: number?            -- the drive number this choice belongs to
state.bag         = {} :: { string }          -- empty means "refill and shuffle on the next deal"
state.layoutSource = "default"                -- "default" | "bag" | "override"

ForestTest.layout(): Layout                   -- the live one
ForestTest.layoutName(): string
ForestTest.layoutForDrive(driveNumber: number, override: any): string   -- THE ONE PROMOTER (§5.2)
ForestTest.forcedLayout(value: any): string?  -- PURE; `startRole`'s shape exactly
ForestTest.publishLayout(name: string)        -- the one writer of the published attribute
```

Every other function in this module keeps its signature and reads `state.layout` where it reads
`Data.CENTRE` / `Data.STAND_COUNT` / `Data.EXIT_Z` today: `withinStand`, `boundaryPoint`,
`nearestStand`, `standArea`, `hunterStandX`, `standIndexFor`, `postIndexFor`, `beaterStartPosition`,
`beaterPosition`, `restSpot`, `restSpotOk`, `restSeenFromLane`, `stockWood`, `spookNearBeaters`,
`releaseLine`, `stepLines`, `urgeAcrossRoad`, `checkAtTheEdge`, `boarThreats`, `waveReport`,
`restReport`, `step`. That is the cheap half of the task and it is a sweep, not a redesign.

**One new guard, and it is the answer to brief §2.4's hardest case:**

```luau
function ForestTest.pickOf(userId)
    local pick = state.picks[userId]
    -- A PICK IS A STAND INDEX AND A LAYOUT MAY NOT HAVE IT. The ride has 5 stands and the road has
    -- 9, so stand 7 exists in one and not the other; `standX(7)` on the ride answers a point 520
    -- studs off centre that is NOT a stand, and `standArea`, `boundary` and `hunterStandX` would all
    -- believe it.
    if pick == nil or pick.index > state.layout.standCount then
        return nil
    end
    return pick
end
```

`standIndexOf` goes through `pickOf`, so every reader of a pick — the fire gate (`standArea` →
`Weapon.setStandProvider(Match.standAreaFor)`), the soft wall (`boundary`), the wave aim
(`hunterStandX`) and the ring (`showRing`) — answers **"no pick"** for an index the live layout does
not have. "No pick" is already the designed, tested state during the pick window (*"no rule during
the pick window"*), so the failure mode is a hunter with no boundary and no gate for a few seconds,
not a hunter held to a point in a wood. It is belt over the brace in §8, which drops every pick at
the drive boundary anyway.

---

## 5. One writer, and how the client learns the answer

### 5.1 Ownership — one writer each, named

| System | Owner (the only writer) | Location |
|---|---|---|
| **The layout table** (what layouts exist and their numbers) | **nobody at run time**: frozen data | `src/shared/ForestTest/init.luau` |
| **Which layout is live** (the choice, the bag, the override) | **`ServerScriptService.ForestTest`** — `state.layout`, `state.bag` | `src/server/ForestTest/init.luau` |
| **The published name clients read** | **`ServerScriptService.ForestTest`** — `publishLayout` | attribute `Layout` on `ReplicatedStorage.ForestTest.Live` |
| **The forest's marker parts** | **`ServerScriptService.ForestTest.Markers`** — unchanged | `src/server/ForestTest/Markers.luau` |
| **The boar runtime's field** (`bounds`, `exitZ`, `groundY`) | **the runtime itself**, through `Runtime:setField` (§6.5); the forest is its only caller | `src/server/Boar/init.luau` |
| **The map's geometry** | **`Hud.MapUi`** — unchanged, through `MapUi.setGeometry` | `src/client/Hud/MapUi.luau` |
| **When the promoter is called** | **`src/server/ForestTestBoot.server.luau`** — boot line only; owns nothing, decides nothing | — |

**The client never chooses and never derives.** It reads one string. There is no client-side bag, no
client-side default, and no inference from the player's position — a client that guessed would put
the hunter's map on a different road from the one his feet are on, which is this project's named
killer and would be invisible in a screenshot.

### 5.2 The moment it chooses: the drive number, inside the markers provider

```luau
-- src/server/ForestTestBoot.server.luau, the `markers` field of Match.start
markers = function()
    -- THE DRIVE BOUNDARY IS WHERE A LAYOUT CHANGES, and this closure is the one place that sees it
    -- BEFORE anybody is placed: `Match` measures the set on the `Assigning` edge, ahead of its own
    -- `placePlayers` effect (§6). `layoutForDrive` is idempotent per drive number, so the
    -- once-a-second reads while `Waiting` promote nothing after the first.
    ForestTest.layoutForDrive(Match.driveNumber(), ServerStorage:GetAttribute(Data.LAYOUT_OVERRIDE_ATTRIBUTE))
    return ForestTest.Markers.build(ForestTest.hunterStandX(), ForestTest.layout())
end,
```

The attribute read stays in the boot, because the boot is the only file in this world that touches
`ServerStorage` (`Data.START_ROLE_ATTRIBUTE` is read exactly there today). The decision stays in
`ForestTest`. `ForestTest` still **does not require `Match`** — the closure that needs both lives in
the composition root, which already requires both.

```
layoutForDrive(driveNumber, override):
    key := max(1, driveNumber)                 -- drive 0 (Waiting) and drive 1 are one key, so the
                                               -- first layout dealt is the first one PLAYED
    if state.layoutDrive == key then return state.layoutName        -- idempotent
    forced := ForestTest.forcedLayout(override)
    if forced ~= nil then
        name, source := forced, "override"                           -- THE BAG IS NOT TOUCHED
    else
        name, state.bag := Data.nextLayout(state.layoutName, state.bag, roll)
        source := "bag"
    state.layoutDrive = key
    if name ~= state.layoutName then promote(name, source) else state.layoutSource = source
    return name

promote(name, source):
    state.layoutName, state.layout, state.layoutSource = name, Data.layoutNamed(name), source
    ForestTest.publishLayout(name)                     -- the clients
    ForestTest.retire(now); runtime:clear()            -- §6.5: the previous layout's animals
    runtime:setField(Data.fieldFor(state.layout))      -- §6.5: the exit and the bounds
    state.restStocked = false                          -- the wood is a new wood (newDrive's rule)
    print("[ForestTest] layout=" .. name .. " (" .. source .. "): " ..
          count .. " stands " .. spacing .. " apart, exit " .. exitZ)
```

**The source is printed and is in `ForestTest.stats()`**, the `Flags` discipline (`source =
"override"` / `"defaults"`). It is the only thing that stops the Director reporting a forced drive as
a random one: `DHForestLayout` is **not** a `DHFlag_*` name, so `tools/studio_mcp.py`'s override
guard neither sees it nor refuses a run while it is set (§11, open decision D3).

An unknown name is **ignored with one console line** and the bag deals normally, so a typo can never
produce a layout-less drive.

### 5.3 The transport: an attribute on a Rojo-owned `Configuration`

```
src/shared/ForestTest/Live.model.json   ->   ReplicatedStorage.ForestTest.Live   (Configuration)
    attribute "Layout" : string   -- written by ServerScriptService.ForestTest, read by the client
```

```luau
ForestTest.LIVE_NAME = "Live"                        -- the host instance's name
ForestTest.LAYOUT_ATTRIBUTE = "Layout"               -- the published attribute
ForestTest.LAYOUT_OVERRIDE_ATTRIBUTE = "DHForestLayout"   -- the Director's, on ServerStorage, Edit mode
```

**Why a Rojo-owned child of the module and not an attribute on `ReplicatedStorage` itself**, which is
what the note proposed: `Flags` already solved this and wrote down why — its host is
`src/shared/Flags/State.model.json`, *"a CHILD OF THIS MODULE … so it is found through `script` and
never by searching ReplicatedStorage: one file, one instance, and Rojo owns both"*, and *"a Rojo-owned
empty Configuration rather than a run-time-created instance because every Rojo-owned container
defaults to `$ignoreUnknownInstances: false`, so an instance with no file on disk is DELETED at the
next Connect"*. `ReplicatedStorage` is the service every system shares; an attribute on it is a global
name with no owner. The empty `.model.json` also makes the host exist in **Edit**, which is where the
harness compares the tree — and the attribute is written only during **Play**, so a run-time write
cannot dirty a harness run, exactly as `Flags.publish` does not.

The client already has the door: `src/client/Hud/init.luau` does
`Hud.whenReady(ReplicatedStorage, "ForestTest", function(module) … end)`. Inside that closure:

```luau
local live = module:FindFirstChild(data.LIVE_NAME)
local function draw()
    MapUi.setGeometry(MapUi.geometryFor(Map.EXPECTED_WORLD, data, Map,
        live and live:GetAttribute(data.LAYOUT_ATTRIBUTE)))
end
draw()
if live then live:GetAttributeChangedSignal(data.LAYOUT_ATTRIBUTE):Connect(draw) end
```

`MapUi.setGeometry` stays the one writer of the map's geometry (task 165's rule), so this is a second
*caller* of a public door and not a second drawer.

**Before the first publish, and when the attribute is missing: NO GEOMETRY AT ALL, and one console
line.** Not a `road` fallback. That is `MapUi.geometryFor`'s own stated rule — *"A WORLD THAT HAS
STATED NOTHING GETS NO MAP AT ALL and says so out loud -- never a blank panel"* — and the signal
connection above draws the map the instant the name arrives. In practice it is never seen: the server
publishes inside `Match.start`'s own first `readMarkers()` (`src/server/ForestTestBoot.server.luau`
line order: `Match.start` well before `RunService.Heartbeat:Connect` and `ForestTest.start`), which
is before any player's Hud runs. A `Flags`-style wait-with-deadline is **rejected** as a second
mechanism for a case the signal already covers.

### 5.4 The bag, written out

```luau
-- src/shared/ForestTest/init.luau. PURE: a spec drives it with a fixed roll and no world.
-- `roll(n)` must answer an integer in 1..n; the live caller passes state.rng:NextInteger.
function ForestTest.nextLayout(previous: string?, bag: { string }, roll: (number) -> number):
        (string, { string })
    local next_ = table.clone(bag)                 -- never mutates the caller's list
    if #next_ == 0 then
        next_ = ForestTest.layoutNames()
        for i = #next_, 2, -1 do                   -- Fisher-Yates, the one shuffle
            local j = math.clamp(roll(i), 1, i)    -- a stub that answers 0 cannot index nil
            next_[i], next_[j] = next_[j], next_[i]
        end
        -- THE BOUNDARY CASE (source §12.2). A fresh bag whose first name is the one just played
        -- deals `... C | C ...`, which is the one thing "never twice running" has to mean. Swap it
        -- with the second. With ONE layout in the table there is no second and the answer is the same
        -- name again -- honest, and not a loop that cannot terminate.
        if #next_ >= 2 and next_[1] == previous then
            next_[1], next_[2] = next_[2], next_[1]
        end
    end
    local name = table.remove(next_, 1)
    return name, next_
end
```

**Where the state lives.** `state.bag`, `state.layoutName` and `state.layoutDrive` are in
`ServerScriptService.ForestTest`'s `state` table, beside `state.picks`. So the bag survives every
drive boundary in one server and **dies with the server** — which is what the brief asks for, and the
consequence is stated rather than hidden: *the first drive after a server restart can repeat the
layout that was playing before it*, because `previous` is nil again. That is the right trade. A bag
persisted in a DataStore or an attribute would make "never twice running" depend on state nobody can
see, and a Studio restart is a new playtest anyway.

**`DHForestLayout` does not touch the bag.** Forced drives are dealt from nothing, so clearing the
override returns the rotation to exactly where it left off.

---

## 6. What rebuilds when the layout changes, in order — and the one change outside the forest

This is brief §2.4, and it is where the real bug was.

### 6.1 The finding: `placePlayers` runs on markers measured during the PREVIOUS drive

`src/server/Match/init.luau`, in `dispatch`, on the `Assigning` edge:

1. the `state.phase ~= before and state.phase == "Assigning"` block sets **`markersStale = true`**,
   with the comment *"Read on the NEXT step, never from inside dispatch: `readMarkers` dispatches an
   event of its own, and a dispatch inside a dispatch would apply effects out of order"*;
2. **`applyEffects(effects)`** runs — `assignTeams`, `clearBoars`, **`placePlayers`**,
   `refreshArming`, `broadcast`;
3. **`syncBots()`**;
4. **`phaseSignal:Fire(...)`** — so `Match.PhaseChanged` is the **last** thing, after everybody has
   been placed.

`applyPlace` reads the module-level **`markerSet`**, and `Match:step`'s gate
`if (state.phase == "Waiting" or markersStale) and sinceMarkers >= 1` only refreshes it on the
following step. So today every drive's hunters are placed on the marker set measured during the
previous drive. Today that is invisible, because the geometry is identical between drives. **With
layouts it is a 900-stud error**: the hunters of an `edge` drive would stand on the `road`'s posts,
and `ForestTestBoot`'s pick window — opened on `PhaseChanged → Running`, from
`ForestTest.nearestStand(where he landed)` — would then lock a stand 900 studs from his feet, gate
his gun off (`standArea` → `Weapon.setStandProvider`) and drag him at the soft wall.

It also means `forest-drive.md` §4.1.6's own stated contract — *"the set is re-measured … once on
entering `Assigning`"* — is **not true of the code today**.

### 6.2 The change, and it is the only one outside the forest

Split the measurement from the dispatch, and measure on the edge:

```luau
-- src/server/Match/init.luau
local function measureMarkers()                 -- NEW: measures, writes `markerSet`, dispatches NOTHING
    if type(world.markers) == "function" then markerSet = world.markers()
    elseif world.markers then markerSet = world.markers
    else markerSet = Markers.read(world.collection) end
end

local function readMarkers()                    -- unchanged in behaviour: measure, then the event
    measureMarkers()
    dispatch({ kind = "markers", … })
end

-- …in dispatch, the Assigning-edge block, beside `markersStale = true`:
    markersStale = true
    -- MEASURED NOW, NOT NEXT STEP. `applyEffects` below emits `placePlayers`, which reads
    -- `markerSet`; without this a drive places its players on the set measured during the PREVIOUS
    -- drive, which in the Forest Test is now a different LAYOUT (docs/design/drive-layouts.md 6.1).
    -- Only the measurement moves: the `markers` EVENT still goes out on the next step, so no
    -- dispatch happens inside a dispatch and `Phase` sees exactly the sequence it sees today.
    measureMarkers()
```

and one accessor beside `Match.phase()`:

```luau
function Match.driveNumber(): number
    return state.driveNumber
end
```

**The contract the provider must honour, stated so the Builder does not have to discover it:**
`world.markers` is now called from inside `dispatch`, so it **must not yield and must not call back
into `Match`**. The forest's provider raycasts and creates parts, neither of which yields; the
`Match.driveNumber()` it calls is a plain table read with no dispatch.

### 6.3 Rejected alternative, and why

*Let the forest's `placement` closure answer from `ForestTest.Markers`' own current set and leave
`Match` untouched.* Rejected: it puts **two marker sets in play** for up to a second at every
boundary, and the one `Match` holds would contain **destroyed parts** of a different layout
(`Markers.build` destroys and rebuilds the folder). `Match.gatherSpotFor`, `Body.anchorFor` (the
rope), `standsFree(#posts, …)` and `Match.beaterGoalFor` all read that set. Two answers to "where is
stand 5", one of them pointing at destroyed instances, is *"two correct pieces of code disagreeing"*
— the failure `PROJECT_CONTEXT.md` names. The four-line change above costs a `test2` click and
removes the class of bug.

### 6.4 Why DEV does not change, provably

In DEV `world.markers` is nil, so `measureMarkers` is `Markers.read(world.collection)` — five
`GetTagged` calls, no writes, idempotent. The only behavioural difference anywhere is *when* the set
is measured, and in a world whose markers are Studio-built and unchanging between drives the value is
identical. `tests/server/match_live.spec.luau` already asserts `Match.config() == Match.CONFIG` by
identity; §9 adds the marker-freshness case and the `driveNumber` case.

**The cost, named:** `src/server/Match/init.luau` is in `TWO_PLAYER_PATHS`, so this task needs the
`[harness2]` line for the merge (§9.5). There is no version of this fix that does not touch `Match`.

### 6.5 The order, once the measurement moves

| # | What | Already per drive? | Who |
|---|---|---|---|
| 1 | **The layout is promoted** — bag or override, published, printed | NEW | `ForestTest.layoutForDrive`, from the markers provider, on the `Assigning` edge |
| 2 | **The previous layout's animals go**, and the boar field is replaced (`exitZ`, `bounds`) | NEW | `ForestTest` → `runtime:clear()` + `runtime:setField(Data.fieldFor(layout))` |
| 3 | **`Workspace.ForestMarkers` is rebuilt** on the new layout | already (`Markers.build` destroys and rebuilds every call) | `ForestTest.Markers` — the one writer |
| 4 | **Players are placed**: hunters on the new posts through `Body.placementFor`, beaters at `beaterStartPosition(index)` | already | `Match.Body.place` — the one writer of where a character stands |
| 5 | **Bot lanes and goals** | already: `Match.botsNeedRebuild` clears once per drive, `botSlotsFor` re-asks `place`, and `Bots.fill` *"re-places a slot whose start or goal moved"* | `Match` + `Bots` |
| 6 | **Every pick is dropped and every ring taken down**, then a fresh unlocked pick and ring go up `PLACEMENT_SETTLE_SECONDS` later from `nearestStand(where he landed)` | already — `ForestTestBoot`'s `Match.PhaseChanged → "Assigning"` handler calls `ForestTest.clearPick` for every player and `ForestTest.Markers.clearRings()` | `ForestTestBoot` + `ForestTest` |
| 7 | **The resting wood** is re-stocked once, on the new layout's lanes | already — `ForestTest.newDrive()` clears `restStocked`; `restPoint` is relative to the locked stand's x, so it follows the layout for free | `ForestTest` |
| 8 | **The hunter's map** redraws | NEW | the attribute signal → `MapUi.setGeometry` |
| 9 | **The compass** | **nothing to do, and the reason is evidence**: `Hud.driveBearing(data, team)` reads `DRIVE_BEARING_DEG`, `PUSH_BEARING_DEG` and `PUSH_LABEL`, and every layout pushes south along −Z (§1.2.1), so all three are shared and unchanged | — |

**A player standing on a stand the next layout does not have** (the brief's named worry) is answered
three times over: step 6 drops his pick before the drive starts, step 4 places him on a post the new
layout actually has, and §4.4's `pickOf` guard refuses an index past `standCount` even if both
somehow failed. The failure mode of the guard is "no pick", which is a state the game already has and
tests.

---

## 7. What this system reads and writes, and who owns each

| Reads / writes | Owner | Through |
|---|---|---|
| **writes** `state.layout`, `state.bag` | `ServerScriptService.ForestTest` | itself |
| **writes** `ReplicatedStorage.ForestTest.Live.Layout` | `ServerScriptService.ForestTest` | `publishLayout` |
| **writes** `Workspace.ForestMarkers` | `ForestTest.Markers` | `Markers.build` / `clear` / `ring` |
| **writes** the boar runtime's field | the `Boar` runtime | `Runtime:setField` (new; the forest is its only caller) |
| **reads** `ServerStorage` attribute `DHForestLayout` | nobody writes it in code; the Director sets it in Edit | `ForestTestBoot` → `ForestTest.forcedLayout` |
| **reads** `Match.driveNumber()`, `Match.PhaseChanged` | `ServerScriptService.Match` | the boot |
| **reads** the layout, server side | `ServerScriptService.ForestTest` | `ForestTest.layout()` |
| **reads** the layout, client side | the published attribute | `Hud` → `MapUi.geometryFor` |
| **reads** `Lobby.anchorFor`, `Lobby.CONFIG.FIELD.SPAN_STUDS` | `src/shared/Lobby` | **only `tests/server/lobby.spec.luau`** (§9.4). Neither module requires the other, and this design does not make them |

Call sites of the removed constants, all mechanical, all named so none is missed:
`src/server/ForestTestBoot.server.luau` (the boot print, the `field` table, `placement`'s
`roadPointAt`, the `[rest]`/`[wave]` lines), `src/server/ForestTest/init.luau` (~30 reads),
`src/server/ForestTest/Markers.luau` (`build`, `ring`), `src/client/Hud/MapUi.luau`
(`geometryFromForestTest`), and the specs `forest_stand`, `forest_markers`, `forest_line`,
`bots_lane`, `lobby`, `map_ui`, `hud_clarity`.

---

## 8. The map, per layout

`MapUi` keeps **one shape and one drawing** (its §5.1 rule). Two signatures change:

```luau
MapUi.geometryFromForestTest(data: any, layout: any): MapGeometry
MapUi.geometryFor(world: string, forestTest: any?, map: any?, layoutName: string?): MapGeometry?
```

`geometryFor` resolves the name through `data.layoutNamed(layoutName)` and returns **nil** when the
name is nil or unknown — never the road. `geometryFromForestTest` reads the layout for the centre,
the half-span, the amplitude, the stand count and `data.exitZOf(layout)`; `ROAD_SAMPLES` and
`GEOMETRY_MARGIN_STUDS` are unchanged, and a straight layout samples to a straight polyline with no
second code path (the DEV world's two-point road already proved that).

Two consequences, stated:

* **The drawn road is the layout's own length.** On an `edge` drive the full map spans x ≈ 2985…3975,
  so the lodge (x 2740…2960) is off its west edge and a player at the lodge is **pinned to the
  border**, which is the map's own documented rule for an out-of-range marker.
* **The minimap hides outside the stated bounds** (`MapUi.minimapVisible`'s `outsideBounds`), and the
  bounds now move per drive. A player at the lodge between drives therefore sees the minimap appear
  and disappear as the layout changes. That is the existing rule doing what it says; it is in §11 as
  a feel question for Karen, not a defect.

---

## 9. How it is tested

### 9.1 Server spec — the layout table, asserted for EVERY layout

`tests/server/forest_stand.spec.luau`, looping `ForestTest.LAYOUT_ORDER`, so a bad layout added later
fails rather than ships (brief §2.5):

1. **the stands are inside the layout's own span and come out sorted ascending** —
   `standX(1) < … < standX(count)`, every x inside `standSpan(layout)`, consecutive gaps equal to
   `standSpacing` within 1e-6, and the middle index exactly at `centre.X`;
2. **the stands are on the line** — `|standPosition(i).Z − roadZ(standX(i))| < 1e-6`, and for a
   straight layout `roadZ(x) == centre.Z` for every x;
3. **the beaters start north of the animals and north of the stands** —
   `beaterStart(standX, 0, layout).Z − roadZ(standX, layout) == 580` exactly, and `580 >
   LINE.spawnNorthStuds` (180) so a beater is behind the line the drive releases;
4. **the exit is south of every point of the line, by a stated margin** — for a sweep of x across
   `standSpan`, `roadZ(x) − exitZOf(layout) >= EXIT_SOUTH_STUDS` (250), and `exitZOf(layout) <
   min(roadZ(x))`;
5. **the walk is the same ~120 s in every layout** —
   `(beaterNorthStuds() + Match.CONFIG.BOTS.GOAL_PAST_LINE_STUDS) / Bots.CONFIG.WALK_SPEED` is
   120.0 ± 0.1 for all three, which holds **by construction** because no layout carries that number;
6. **the lane spacing equals the layout's stand spacing** (task 167's reason, which must survive) —
   `laneSpacing(layout) == layout.standSpacing`, and `beaterLaneOffset` deals
   `0, +s, −s, +2s, −2s` for that s;
7. **the two sweep bands keep their order in every layout** —
   `noticeAheadStuds(nil, nil, layout) > sweepAheadStuds(nil, nil, layout)`;
8. **`road` is today's layout, number for number** — `centre`, amplitude, divisor, half-width, count,
   spacing, half-span, `exitZOf(road) == −2377`, and `fieldFor(road)` deep-equal to the table
   `ForestTestBoot` builds (§10.1);
9. **the bag** — with `roll` stubbed to a constant: three deals empty the bag, a fourth refills it,
   every name appears exactly once per bag, the boundary swap stops `C | C` across a refill, a
   one-name table answers the same name rather than looping, and `roll` answering 0 or `n+1` cannot
   index nil;
10. **the override parser** — `forcedLayout("edge")`, `" EDGE "`, `"/edge"` → `"edge"`;
    `forcedLayout("clearing")`, `nil`, `42`, `true` → nil;
11. **the pick guard** — a locked index of 7 answers `pickOf == nil` while the live layout has 5
    stands, and `standArea` / `boundary` / `hunterStandX` all answer the no-pick case.

### 9.2 Server spec — the markers, per layout

`tests/server/forest_markers.spec.luau`: `Markers.build(standX, layout, ground, canopy)` with
hand-written readers (the existing injected-reader idiom) builds `standCount` posts for each layout,
sorted by X, named `Stand1…StandN`, with `set.layout == layout.name`, `lineParts == 1` and
`missing` carrying the layout's own count (`"forest:stands (0 of 6)"`); a build with a reader that
refuses everything is `complete == false`; and a second build leaves exactly `#posts + 1` parts in
the folder (the destroy-and-rebuild discipline) rather than two layouts' worth.

### 9.3 Server spec — the bots

`tests/server/bots_lane.spec.luau`: the existing `Forest.BEATER.laneSpacingStuds ==
Forest.STAND_SPACING` case becomes the per-layout assertion in §9.1 item 6, and the existing
hand-written-posts case is run once per layout so `Match.beaterGoalFor` is shown to land on the
layout's own line with 5, 6 and 9 posts.

### 9.4 Server spec — the lodge, and the honest replacement assertion

`tests/server/lobby.spec.luau` asserts today `forest.z < ForestTest.EXIT_Z` and
`ForestTest.CENTRE.Z − forest.z > 500`. **Both become false**: `EXIT_Z` is gone, and the `edge`
layout's exit is −3250, which is *south* of the lodge at z −2950. A z comparison was only ever a
proxy for "the lodge is not in the way", and with three layouts it is the wrong question.

The replacement is a **distance between two rectangles**, with each owner stating its own:

```luau
-- for every name in ForestTest.LAYOUT_ORDER
local corridor = ForestTest.corridorOf(ForestTest.layoutNamed(name))   -- ForestTest states this
local field = rectangle(Lobby.anchorFor("forest-test"), Lobby.CONFIG.FIELD.SPAN_STUDS)  -- Lobby states this
expect(gapStuds(corridor, field) >= 100).to.equal(true)
expect(gapStuds(ForestTest.boundsOf(ForestTest.layoutNamed(name)), field)
       >= Boar.CONFIG.BOUNDS_SLACK + 40).to.equal(true)
```

Measured gaps with the shipped numbers — **corridor to the lobby's field**: road 463 studs (north of
it), edge **145**, ride **130**. **Boar bounds to the lobby's field**: road 363, edge **85**, ride
**70** (75 and 60 after `BOUNDS_SLACK` 10). The owner of the corridor is `ForestTest`; the owner of
the lodge's footprint is `Lobby`; the **spec is the only place the two meet**, which is right —
making either module require the other would be new coupling for one assertion.

### 9.5 The gate, and the client spec

* **Client spec** `tests/client/map_ui.spec.luau`: `geometryFor("forest-test", data, Map, name)` for
  each of the three — stand counts 9 / 6 / 5, the road polyline straight for `edge` and `ride` and
  curved for `road`, bounds equal to §3.2's table plus the margin; and
  `geometryFor("forest-test", data, Map, nil)` and `… , "clearing")` both **nil**, so the "no map
  rather than a wrong map" rule is a case and not a comment.
* **Harness input:** nothing new. `tests/client/input_scenarios.txt` replays keys, mouse buttons and
  moves; it **cannot set a Studio attribute** (TASKS.md tasks 6–7), so the override is tested through
  the pure parser and the one `GetAttribute` line in the boot is named in §10.2 as not covered by any
  spec.
* **Screenshots (rule 5), three, and they are the point of the task.** Karen asked for *"view for
  hunter from different places"*, so a number cannot answer it: one frame from a hunter's stand in
  each layout, each with the full map panel open in the same frame, taken with
  `DHForestLayout` forced to that name and **inspected**. A fourth frame of the `edge` layout looking
  north at the tree line 100 studs out, because that is the layout whose whole claim is a view.
* **The gate:** the one-player `python tools/studio_mcp.py test` **and** `test2`, because
  `src/server/Match/init.luau` and `tests/server/match_*.spec.luau` are in `TWO_PLAYER_PATHS`
  (§6.2). `python tools/pose.py clear` and `python tools/flags.py clear` as usual, **and
  `DHForestLayout` cleared by hand** — the harness does not refuse that attribute (§11, D3).

---

## 10. Numeric targets

| What | Target | Measured / assumed |
|---|---|---|
| Layouts shipped | 3 | — |
| Stands per layout | 9 / 6 / 5 | **measured** (note §5) |
| Stand spacing | 150 / 150 / 130 studs | **measured**: 150 = 42 m at `SPOOK.METRES_PER_STUD` |
| Stands on ground both readers agree about | **100 %** of every shipped layout | **measured**: road 9/9, edge 6/6 (delta 0.0), ride 5/5 |
| Stands trunk-free within 8 studs | **100 %** | **measured**: road 9/9, edge 6/6, ride 5/5. The bar is today's road, which is 9/9, and 6/9 candidates were rejected rather than nudged |
| Rise across the stand line | road ~0, edge **80 studs** west→east, ride ~22 | **measured** (note §5) |
| Beaters' walk | **580 studs**, every layout → 120.0 s at `Bots.CONFIG.WALK_SPEED` 5 | **measured** (task 162) |
| Push corridor inside the wood | ≥ 75 % of the walk's depth | ride **88 %** (22 of 25 samples, measured); edge **83 %** by depth (480 of 580 studs north of the measured tree line at z −2900) — **derived, not sampled**: §10.2 |
| Lodge clear of every corridor | ≥ 100 studs | **measured/derived**: 463 / 145 / 130 |
| Lodge clear of every boar bound | ≥ 50 studs | 363 / 85 / 70 |
| Same layout twice running | **never**, inside one server | by construction (§5.4) |
| Marker reads per drive | ≤ 2 (the edge, plus the next step's event read) | ≤ 20 raycasts each, unchanged |
| Extra work per boundary | 1 attribute write, 1 field swap, 1 `runtime:clear()` | — |

### 10.1 How "the road layout is unchanged" is checked rather than claimed

One spec case, not an eyeball: `fieldFor(ROAD_LAYOUT)` deep-equals `{ bounds = { minX = 2230,
maxX = 3830, minZ = −2477, maxZ = −1197 }, exitZ = −2377, groundY = 138 }`, which is literally the
table `ForestTestBoot` builds today, and `exitZOf(ROAD_LAYOUT) == −2377` reproduces the old constant
`CENTRE.Z − ROAD.amplitudeStuds − 250`. Everything else about a `road` drive is then the same code on
the same numbers.

### 10.2 What is measured and what is not (brief §2.7, rule 8)

**Measured** (note §5, read in the Forest Test place in Edit on 2026-10-14 through StudioMCP,
read-only): every centre, every stand count and spacing, both stand lines' ground agreement and
trunk clearance, the 80-stud edge rise, the ride's terrain range, the tree line at z −2900, the nine
isolated points that prove there is no clearing, the beater start z for both new layouts, the
beater-lane trunk clearance (6/9 edge, 4/5 ride), the ride's 22-of-25 corridor samples, and the
lobby anchor.

**Derived from measured numbers:** `exitZOf` (the formula is today's), `boundsOf` (today's formula),
`centre.Y` for edge and ride (the mean / midpoint of §5's stand terrain), the edge corridor's 83 %
in-wood depth, every lodge clearance.

**Chosen, and said so:** `halfSpanStuds` 435 and 320 (the 60-stud run-out, §3.2); the three `label`
strings; `edge`'s and `ride`'s names.

**NOT measured, and the Builder must measure it in the same Edit session before claiming it:** the
**edge** push corridor as a SAMPLE count, the way the ride's 22-of-25 was taken. The 83 % figure
above is a depth ratio off the tree line, not a sample of trunks along the lanes, and the two are not
the same claim. It does not block: brief decision 2 fixes the edge layout's numbers either way, and a
poor result is a finding about the layout's feel for Karen, not a build blocker.

---

## 11. Open decisions

### For Karen (feel) — none of these blocks building

* **K1. Is a different layout every drive right, or too much?** The alternative is one layout per
  session, or a layout she picks. The bag is the dispatch's decision and is one line to change.
* **K2. Does the `edge` layout read as a hunt?** It is the one with no cut lane: the hunters stand in
  the open with the tree line ~100 studs in front and an 80-stud slope across the line. Source
  §12.1's *Kugelfang* argument says that is the most classical of the three; only her eye decides.
* **K3. Do 5 and 6 stands feel like a line?** Today's nine over 1,200 studs is the only one she has
  played. The ride's five over 520 studs is a different kind of drive on purpose.
* **K4. The labels** — `"Road"`, `"Forest edge"`, `"Ride"`. Nothing draws them in this task.
* **K5. The minimap appearing and disappearing** at the lodge between drives as the bounds move
  (§8). The existing rule, doing what it says.

### For the Director (scope) — each has a decided default

* **D1. The `Match` change and the `test2` click.** Default: **make it** (§6.2). It is four lines, it
  fixes a staleness that already contradicts `forest-drive.md` §4.1.6, and there is no version of
  this task without it. The cost is one human click per gate run.
* **D2. A bot beater's lane can reach two stand spacings past the end stand, and on `edge` that is
  inside the lobby's field.** `beaterLaneOffset` deals lanes about `hunterStandX()`, so with the
  westernmost of the six edge stands locked (x 3105) lane −300 starts at **x 2805** and walks south
  through x 2805, z −3060…−2840 — the lobby's 220-stud field, 25 studs west of the lodge wall.
  Default: **ship it and log it.** The cheap fix is to clamp a beater's x into the layout's stand
  span inside `ForestTest.beaterStart`, but that changes the **road** layout's behaviour too (today
  lane −300 off stand 1 legitimately starts at x 2130, outside the stand span), and brief decision 2
  freezes the road. So it is a scope call, not a design one.
* **D3. `DHForestLayout` is not a `DHFlag_*` name, so `test` and `test2` do not refuse to start while
  it is set.** A forced layout could therefore be reported as a random one. Default: **the printed
  `source=` line and `ForestTest.stats()` are the mitigation** (§5.2). Teaching
  `tools/studio_mcp.py`'s override guard about this attribute is a harness change and its own task.
* **D4. The fourth layout — a clearing with a high seat — is not shipped**, and the reason is
  measured (§1.2.3). Making one needs Studio trees deleted (rule 7, Karen's call) or
  `tools/mapgen.py`-style carving, which works on the generated map and not on this bought terrain.
* **D5. The axis is the next task.** An east–west push, or a push out of the wood's north edge, would
  roughly double what this one block of wood can hold. The seam is named in §13.
* **D6. `ForestTest.driverStart` has no production caller** and would be archived with a note. One
  commit, not this one.

### The minimum, if the four hours run out (brief §4)

The layout table (§3), the promoter and the publish (§5), the `Match` measurement move (§6.2), the
boar field swap (§6.5 step 2) and the map (§8). That is **two new places for Karen to stand**, dealt
per drive. Droppable to a later task: the `label` field's use, the `driverStart` archive, D2's clamp,
and the edge corridor sample count (§10.2).

---

## 12. External sources

### 12.1 WILD UND HUND — *Drückjagdstände — Sicher ist sicher?*

<https://wildundhund.de/drueckjagdstaende-sicher-ist-sicher/>
Licence: all rights reserved; read for facts, nothing copied. **Maintained** — a live trade title
(Paul Parey), dated articles.

* **Well:** it says where a driven-hunt stand belongs and, more usefully, where it does **not**: not
  on a path or a narrow clearing between thickets, because panicked game runs down those light
  bridges. It belongs where game passages converge *and* the bullet catch (*Kugelfang*) is safe, and
  the two places it names are **hillsides and natural terrain edges** — on level ground a shooter has
  about ten metres before a ricochet.
* **Badly:** it is about real safety, not a game, and nothing in it is a number this project can use.
* **Adopted:** the two new layouts are a **forest edge on a hillside** and a **straight ride inside
  the wood**, in that order, and the edge layout is deliberately the one with 80 studs of rise across
  it. It also says today's road is the least classical of the three, which is Karen's complaint.

### 12.2 TetrisWiki — *Random Generator* (the bag)

<https://tetris.wiki/Random_Generator>
Licence: community wiki, facts only. **Maintained** — actively edited; the rule it documents is in
the published Tetris Guideline.

* **Well:** it names the exact failure and the exact cure. A memoryless `math.random(n)` really does
  deal the same item several times running and players read that as broken; the cure is to deal each
  item once and reshuffle when empty.
* **Badly:** a 7-bag with three items is a 3-bag, and a 3-bag can still deal `… C | C …` across a bag
  boundary.
* **Adopted:** the bag, plus the boundary swap its own description implies (§5.4), which is the line
  that makes "never twice running" true rather than nearly true.

### 12.3 Roblox DevForum — preventing a repeated map pick

<https://devforum.roblox.com/t/how-to-prevent-mathrandom-from-picking-the-same-map/1596809>
<https://devforum.roblox.com/t/an-efficient-way-to-randomize-a-list-of-maps-or-items/223583>
Licence: DevForum terms, read for approach. **Live forum, old threads** (2021 / 2018) — quoted as
what this platform's community does, not as a maintained library.

* **Well:** the two shapes actually used here — "remember the previous and re-roll", and "copy the
  list, remove as you deal, refill when empty" (the bag, independently reinvented). Both are a
  handful of lines and neither needs a dependency.
* **Badly:** the re-roll shape can loop; neither thread handles the bag boundary.
* **Adopted:** the bag, from the second thread, because re-rolling is unbounded **and** a bag
  guarantees every layout is *seen* — which matters here, where Karen is judging the look of each one.

### 12.4 Valve Developer Community — map entities as the mode's contract, and the server's mapcycle

<https://developer.valvesoftware.com/wiki/Info_map_parameters/Counter-Strike_series>
Licence: **CC BY-NC-SA 3.0**. Community wiki, **actively edited**.

* **Well:** the map's entities **are** the mode's geometry, the contract is countable (the number of
  spawn entities caps the team size), and the placement constraints are stated as numbers. And the
  server-side half of the same idea is older than this project: the server holds an ordered list of
  maps, advances it at the end of a round, and **tells every client** which one is live. Clients
  never pick.
* **Badly:** classnames are strings with no schema, so a typo is a map that loads and a mode that does
  nothing; and the placement numbers are advice to a mapper, checked by nothing at load time.
* **Adopted:** the contract and both corrections — the set is built in code from one frozen data
  module (no string to mistype) and every constraint is checked by a spec (§9.1); and the
  server-picks/clients-are-told division, which is §5 exactly.

### 12.5 Unreal Engine — `AGameModeBase::ChoosePlayerStart`

<https://dev.epicgames.com/documentation/unreal-engine/player-start-actor-in-unreal-engine?lang=en-US>
Licence: Epic documentation, free to read, not open-licensed. **Maintained** (5.x).

* **Well:** the mode asks the **level** where to put a player and `ChoosePlayerStart` is the hook a
  project overrides. One mode, many levels, no per-level branch inside the mode — which is
  `world.placement` plus `markers.posts`, already built in task 157.
* **Badly:** the override lives in a *subclass* of the mode, so two worlds mean two mode classes; and
  a level with no `PlayerStart` spawns at the world origin — a silent wrong answer.
* **Adopted:** the hook as an injected function (unchanged from task 157), and the refusal of the
  origin: a layout with no readable ground gives `complete = false` and a named `missing` string, and
  a nil placement is one printed line, never a spawn at 0,0,0.

### 12.6 ioquake3 — the mode selects among the map's spawn points

<https://github.com/ioquake/ioq3> (`code/game/g_client.c`: `SelectSpawnPoint`,
`SelectInitialSpawnPoint`)
Licence: **GPL-2.0-or-later**; nothing copied. **Maintained** (the live fork of the id release).

* **Well:** the map places a flat list of spawn entities and the *mode* picks among them by a rule of
  its own. That is the division this task keeps: the layout places its stands, and
  `ForestTest.standIndexFor` is the rule that says which one the first hunter gets. It wraps on the
  live layout's `standCount` rather than on 9 — **and the build changed it twice more than this
  section first said**: round 3 CLAMPED the answer into `1..standCount`, because the centre-out walk
  only closed on an odd count (with the 6-stand `edge` layout live, hunter 6 was dealt stand 0 and
  hunter 8 stand −1), and round 4 moved the middle from `ceil(count/2)` to `floor(count/2) + 1`, which
  makes the walk a real permutation on an even count too — 6 stands deal 4, 3, 5, 2, 6, 1 instead of
  3, 2, 4, 1, 5, *0*. Odd counts are untouched: `floor(9/2) + 1` is 5, which is both `ceil(9/2)` and
  `PICK.defaultIndex`.
* **Badly:** the selection is scattered across near-duplicate functions with per-gametype special
  cases, and it breaks ties randomly, so a report cannot be reproduced.
* **Adopted:** one pure selector, and the randomness confined to **one** place with an injected
  `roll` so every spec is deterministic (§5.4).

### 12.7 Borrowed from inside this repo (rule 2)

`Flags.publish` + `src/shared/Flags/State.model.json` as the attribute-on-a-Rojo-owned-`Configuration`
transport and the `source = "override"` reporting idiom (§5.3, §5.2); `ForestTest.START_ROLE_ATTRIBUTE`
as the Studio-attribute switch and `ForestTest.startRole` as the pure parser beside it (§5.2);
`ForestTest.sweepAheadStuds(spook, beater)` / `encounterStage(..., spook, beater)` as the
table-handed-in parameter shape (§4); `Markers.build`'s destroy-and-rebuild (the `Body.OUTFIT_NAME`
discipline) as the thing that makes a layout change a rebuild it can already do; `Boar.newRuntime`'s
injected `world` as the precedent for `Runtime:setField`; `Drive.deepFreeze` for the frozen table;
`Match.botsNeedRebuild` / `Bots.fill`'s *"a slot whose start or goal moved is re-placed"* as the
reason the bots need no new code; `MapUi.geometryFor`'s *"a world that has stated nothing gets no map
at all"* as the client's missing-attribute rule.

---

## 13. Where the axis would attach, when it is its own task (D5)

Not built, and named so the next task does not have to find them: `Brain:_outcome`'s
`position.Z <= exitZ` and `Brain.exitSign`; `Boar.CONFIG.field.exitZ` and `Brain.insideField`'s
`bounds`; `ForestTest.lineFrontAt` (which sorts by X and interpolates Z); `wavePoint`, `restPoint`,
`laneLookPoint`, `offLaneStuds`, `beaterStart` and `beaterLaneOffset` (all "north = +Z, along = x");
`markers.line.normal = Vector3.zAxis` in `Markers.build` and `SafetyArc.isForbidden`'s dot product
against it; `ForestTest.DRIVE_BEARING_DEG` / `PUSH_BEARING_DEG` and the compass. The seam is a
**bearing on the layout record** plus a rotation of the (along, across) basis in one pure helper that
all of the above call — i.e. the layout grows `bearingDeg` and these functions stop spelling x and z.
Twelve places, and it is why this task does not touch one of them.

**And the real map:** when `MapGen` wants this, it feeds the same `Layout` record — `MapGen.Layout`
already computes a post line and a road, so it would publish a `Layout` per generated world instead
of `Map.ROAD` plus `Map.FIELD`, and `MapUi.geometryFor`'s second provider would collapse into the
first. Out of scope here (brief §3) and stated in one sentence, as asked.

---

## 14. Deltas to the designs already written

* **`docs/design/forest-drive.md` §4.1.2** — `Markers.build`'s signature gains the required `layout`
  parameter and the set gains `layout`. §4.1.3's `posts` row becomes "`standCount` anchored invisible
  parts at `standPosition(i, layout)`"; the `line` row's position becomes
  `(layout.centre.X, postY, layout.centre.Z)`, which is still exactly on the line because the sine is
  0 at `centre.X` and a straight layout has no sine at all. §6.1's measured conclusion — *the arc
  reads the normal only, so the one-plane approximation is free* — **survives unchanged for all three
  layouts**, and for the two straight ones the approximation is exact.
* **`docs/design/forest-drive.md` §4.1.6** — amended by §6.2 of this document: the set is now really
  measured on the `Assigning` edge, which is what that section already said.
* **`docs/design/forest-drive.md` §9.1** — `Match` gains `Match.driveNumber()`.
* **`docs/design/map-ui.md` §5.2 and §13** — `geometryFromForestTest(data, layout)` and
  `geometryFor(world, forestTest, map, layoutName)`; the bounds table in §5.2 becomes per layout
  (§3.2 here); §5.5's late-arrival door gains the attribute signal.
* **`GAME_DESIGN.md`** — the *System owners* table gains the row "which drive layout is live →
  `ServerScriptService.ForestTest`".
* **`docs/design/bots.md` §8** — unchanged; the lane spacing it cites is now the layout's, by the
  same definition.
* **No change** to `docs/design/drive.md`, `boar-ai.md`, `boar-behaviour.md`, `lobby.md`,
  `feature-flags.md` or `shop.md`.

---

## 15. No feature flag — agreeing with the brief, correcting its reason

Brief decision 7 is right and this design does not re-open it, but its stated reason does not hold
and the honest one is better. The brief says *"the layout table with one entry IS today's behaviour,
so the change is dark by construction"*. We ship **three** entries, so the change is **live the
moment it merges** — not dark.

A flag is still the wrong tool, for the measured reason CLAUDE.md already writes down about the map
switch: *"a flag lives in code and the WORLD LIVES IN THE PLACE"*. A `DRIVE_LAYOUTS` flag would be a
second switch over the same fact — the layout name — and the thing Task 79 measured is that a
geometry switch which can be flipped without the world following it produces a build where the specs
and the ground disagree. There are already two switches here and they are enough: `LAYOUT_ORDER` (a
one-line commit back to `{ "road" }`, which is today's game exactly, by the §10.1 identity) and
`DHForestLayout` (a Studio attribute, for a playtest, with nothing in the git tree). A third would be
the only one that could disagree with the other two.

---

## 16. What I could not verify (rule 8)

* **No Studio, no place, no network in an Architect run.** Every geometric number here is read out of
  `docs/research/2026-10-14-drive-layouts.md` §5 or derived from it arithmetically in this document.
  I measured nothing myself and re-measured nothing.
* **The links in §12 are not fetched.** §12.1–12.3 are carried verbatim from the note; §12.4–12.6 are
  carried from `docs/design/forest-drive.md` §11, where earlier tasks cited them. Nothing new was
  invented, but the Builder should confirm each URL resolves before putting it in a code comment
  (rule 9).
* **The edge layout's push corridor has no sample count** (§10.2). It must be measured, not inherited
  from the ride's.
* **Whether `measureMarkers()` on the `Assigning` edge changes any DEV spec's result** is argued from
  the code (`Markers.read` is an idempotent `GetTagged` read) and not run. The harness answers it.
* **The lodge and boar-bound clearances in §9.4** are computed here from `Lobby.CONFIG.FIELD`'s
  220-stud span and the note's anchor. I did not confirm that `Lobby.Build` writes exactly that
  rectangle in the live place; the spec in §9.4 reads both owners' own numbers, so it will.
* **Nobody has seen any of this.** Karen's eye decides K1–K5, and the three screenshots in §9.5 are
  the first time the two new layouts will have been looked at.
