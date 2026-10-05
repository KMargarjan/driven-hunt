# The drive report: the hit record, the hit indicator, the kill log and the end-of-drive panel

Architect design for Task 124. Written to `reviews/task-124/BRIEF.md` (Builder carrying the Director,
2026-10-05), which overrides anything older in `docs/`, `TASKS.md` and any earlier design.
Research note: `docs/research/2026-10-05-drive-report.md`.

Karen, verbatim:

> "we need to show when is killed logg or something similar / we need to indicate a hit / and we need
> to show on the end what has been killed where was the hit / so after drive we can see how much I
> killed compairing others and I can click on details or similar and see boars where was the hit /
> something simple but cool"

---

## 1. What the system must do

1. **Say "that hit", to the shooter only, instantly** — and say it differently when the animal died.
2. **Say "X killed a Y" to everybody**, briefly, while the drive runs, in the feed that already exists.
3. **At the end of a drive, show every hunter side by side**, sorted, so Karen can see how she did
   against the others.
4. **Let her open one hunter** and see each animal: where every shot landed on it, how far away it
   was, and whether it died or was hit and never died.
5. **Work in a world with no `Match`.** The Forest Test has no drive, no roster and no teams.
6. **Be openable at any time on `Tab`**, in both worlds, and auto-open once when a drive closes.

## 2. What it must not do

| Must not | Why, with evidence |
|---|---|
| Keep a second score | `Match` owns points, penalties and the roster: `Score.kill`/`Score.escape` are called from `Match`'s `onDowned`/`onDespawned` (`src/server/Match/init.luau`). The report's payload carries **no points field at all**; the panel reads points out of the client's existing `Match.get().rows` |
| Let a client write a hit, a kill or a placement | The one inbound remote carries at most three optional numbers (drive, hunter, page) and every one is re-resolved server-side by `Shape.resolveRequest`. Pattern: the weapon's "the client sends {origin, direction} and NOTHING else" (`src/server/Weapon/init.luau` header) |
| Store a world position for an impact | A carcass despawns (`Runtime:_despawn`); a world point then means nothing. The impact is stored in the animal's own frame (section 6.2) |
| Draw a zone the damage model does not have | Exactly five: `head`, `chest`, `body`, `legs`, `rear` — the rows of `Boar.CONFIG.WOUND.DAMAGE` and `WOUND.CLASS` |
| Send `os.clock()` to a client | Server clock, meaningless on a client. Precedent and wording: `Shotgun.snapshot` — "a deadline becomes a duration, because os.clock() on the server means nothing on a client". Every time on the wire is **seconds since the drive opened** |
| Write a boar, a weapon state, a camera, a character, a team or a mouse | Those have owners. `HitLog` reads two published signals and writes only its own record and its own three remotes |
| Require another owner | `HitLog` requires neither `Boar` nor `Weapon` nor `Match`. Each world's composition root wires it, exactly as `MatchBoot` already wires `Weapon.HitReported → runtime:takeHit` |
| Add a second screen-space writer | `src/client/Hud/` stays the one owner of `PlayerGui.HunterHud` (section 4) |
| Keep a `Player` instance in the record | `Wound.killRecord`'s own rule: "it carries userIds and names, never Player instances: a boar can outlive a disconnect by 16 seconds and a stored Player pins the instance" |
| Reset the Forest Test's wave schedule | The drive period there is a **reporting window only** (section 10). The 20-second cycle Karen signed off in Task 123 is untouched |

## 3. Owner table

Every row is exactly one writer, named (rule 3). Rows 1–4 are new.

| System | Owner (the only writer) | Location on disk | Reached with no `Match` |
|---|---|---|---|
| **The hit record** ("who hit what, where, and did it die"), the three remotes, the request throttle | `ServerScriptService.HitLog` | `src/server/HitLog/init.luau` | Yes — `ForestTestBoot` wires and starts it, exactly as `MatchBoot` does |
| The record's arithmetic: the impact projection, the payloads, the caps, the inbound validation | `ServerScriptService.HitLog.Shape` — **pure**: no Instance, no clock, no remote, no service | `src/server/HitLog/Shape.luau` | n/a (pure) |
| **The report's wire contract and layout numbers** (types, `remotes()`, `CONFIG`, the silhouette rects) | **nobody at run time.** Deep-frozen data, no writer, exactly as `src/shared/Drive/init.luau` is | `src/shared/Report/init.luau`, `src/shared/Report/Remotes.model.json` | Yes — shared, world-independent |
| **The report client replica** (subscribes to the three remotes; the ONE firer of `ReportRequest`; no drawing) | `PlayerScripts.Report`, booted once by `PlayerScripts.ReportBoot` | `src/client/Report/init.luau`, `src/client/ReportBoot.client.luau` | Yes — no `Match` dependency |
| **The report panel** (the one writer of `HunterHud.ReportPanel` and everything in it), the `DrivenHunt.Report.*` keys | `PlayerScripts.Hud.ReportPanel`, started by `Hud.start()` | `src/client/Hud/ReportPanel.luau` | Yes |
| **The Hud's own 2-D feedback sounds** (the hit/kill tick) | `PlayerScripts.Hud.Sound` | `src/client/Hud/Sound.luau` | Yes |
| Everything else drawn, incl. the hit marker, the feed, the score panel, the `ReportPanel` **frame itself** | `PlayerScripts.Hud` — unchanged owner | `src/client/Hud/init.luau` | Yes |
| The hit/kill marker remote (server → the shooter alone) | `ServerScriptService.Weapon` (`Weapon.markHit`) — unchanged owner | `src/server/Weapon/init.luau` | Yes — `ForestTestBoot` already calls it |
| The weapon's input actions and the new input hold | `PlayerScripts.Weapon.Input` — unchanged owner | `src/client/Weapon/Input.luau` | Yes |
| The Forest Test's drive length | **nobody at run time.** Data in `ReplicatedStorage.ForestTest` (`ForestTest.DRIVE`); the live period index is `ServerScriptService.ForestTest` | `src/shared/ForestTest/init.luau`, `src/server/ForestTest/init.luau` | n/a |

**The Hud boundary, written down because the brief asks for it.** The report is **Hud-owned**, not a new
screen owner. `Hud.build()` creates one `Frame` named `ReportPanel` (ZIndex 10) under `HunterHud` and
passes it to `ReportPanel.start(frame, ReportSystem, CameraSystem)`. After that:

* `Hud` is still the only module that **parents anything into `HunterHud`**;
* `ReportPanel` is the only module that writes **inside that frame** — its children, their text, their
  visibility, and the frame's own `Visible`;
* `Hud` never writes inside `ReportPanel`, and `ReportPanel` never writes outside it.

This is the shape `src/client/Camera/` already has: `Camera/init.luau` owns the system and
`Camera/Cursor.luau` is "THE ONLY WRITER of UserInputService.MouseBehavior" inside it. A second
top-level screen owner would reopen the failure `docs/PROJECT_CONTEXT.md` names — "three scripts set
the mouse cursor", "one predicate answered two unrelated questions".

**The one place the two panels could have fought.** `Hud.renderScore` is already documented as "THE ONE
WRITER of the score panel". It stays the one writer and gains **one input**:

```lua
function Hud.scorePanelVisible(snapshot, reportOpen: boolean): boolean  -- pure, exported
    if snapshot == nil or snapshot.phase ~= "Scoring" or not Drive.CONFIG.SCOREBOARD_ENABLED then
        return false
    end
    return not reportOpen
end
```

`renderScore` calls it with `ReportPanel.isOpen()`. That is a **read of published state**, the same shape
as `Hud.crosshairVisible(state, aiming, firstPerson)` reading `Camera.isFirstPerson()`. Nothing but
`renderScore` ever writes `ScorePanel.Visible`.

## 4. The two client paths, and which remote carries each

### 4.1 The hit indicator — the shooter's only, and it already exists

`Weapon.markHit(player, kind, zone)` fires `Shotgun.Remotes.HitMarker` to **one** client
(`src/server/Weapon/init.luau`), and both composition roots already call it twice: `"hit"` from the
weapon's own shot path (`onFireRequest`) and `"kill"` from `runtime.Downed`
(`MatchBoot.server.luau`, `ForestTestBoot.server.luau`). `Hud.showHitMark` already draws white for a
hit and `HIT_MARK_KILL_COLOR` for a kill. **Nothing about the wire changes.** What this task adds:

1. **Duration, to the research note's numbers.** `Shotgun.CONFIG.HIT_MARK_SECONDS` 0.15 → **0.35**,
   `HIT_MARK_KILL_SECONDS` 0.45 → **0.80**. 0.15 s is four frames at 30 fps: readable only if you were
   already looking at the centre of the screen, which during a crossing you are not.
2. **A soft tick.** `Hud.showHitMark` — the one writer of the marker — calls
   `Hud.Sound.tick(kind)`. `src/client/Hud/Sound.luau` is a 40-line copy of the pattern in
   `src/client/Weapon/Sound.luau` ("LOCAL ONLY, AND AT THE EAR": a parentless `Sound` under
   `SoundService`, `Debris:AddItem`), with its own `stats()` so a spec can hear what was asked for
   without a speaker. Ids live beside the marker's other numbers in `Shotgun.CONFIG`:
   `HIT_MARK_SOUND_ID = ""`, `HIT_MARK_KILL_SOUND_ID = ""`, `HIT_MARK_VOLUME = 0.35`.
   **An empty id plays nothing and is not an error** — the rule `Weapon.Sound` already states for
   `SOUND_SHOT_ID` ("a gun that is silent is the gun this repo has had all along; a warn per shot
   would be worse than the silence"). Picking the two ids is Karen's (section 13).

It is **not** a new owner and **not** a new remote: "The weapon owns that remote and fires it … this
module only draws" (`src/client/Hud/init.luau` header) is unchanged.

### 4.2 The kill line — everybody, in the feed that already exists

**Decision: the kill line's one writer is `HitLog`, over its own remote, in every world; the Hud's
feed draws a kill line from that one source and from no other.**

The brief asks whether the line reuses `Match`'s feed remote. It cannot, and the reasons are evidence,
not taste:

* `Drive.remotes()` is documented as "Both are server -> client. There is NO inbound remote in this
  system, so its inbound exploit surface is zero", and `tests/client/match_client.spec.luau` asserts
  the `Drive.Remotes` folder holds **exactly two RemoteEvents and no RemoteFunction**. A third remote
  there fails that spec, and it should.
* `Match.publishFeed` is the only writer of `MatchEvent`. A second writer of one remote is the
  previous project's death ("two systems wrote the creature's position").
* In the Forest Test, `MatchBoot` returns immediately and `Match.start` is never called, so nobody
  owns `MatchEvent` at all there. A kill line over it would be a remote with a writer in one world and
  none in the other.

So `HitLog` broadcasts `Report.Remotes.ReportEvent` with `kind = "kill"` in **both** worlds, and the
client path is identical in both — no world conditional anywhere, on either side.

**The duplicate in the DEV world is removed on the client, in one line.** `Match`'s `Phase` also emits a
`kind = "kill"` feed entry (`src/server/Match/Phase.luau`, the `kill`/`gone` branch), and
`Hud.feedTextFor` renders it today. `feedTextFor` returns **nil** for `kind == "kill"`, and the Hud does
not insert a line with no text. The boundary, written so it is greppable:

> **`Match`'s feed owns the DRIVE's events** — `escape`, `violation`, `join`, `leave`, `phase`.
> **`HitLog`'s line owns the KILL.**

`HitLog`'s line strictly dominates the one it replaces: it carries the animal's **kind**, which Karen's
report needs and which `Match`'s entry does not have. `src/server/Match/` is **not** in this task's
blast radius and is not touched; retiring the now-unread `kill` entry from `Phase.luau` is queued
(section 14, item 1) because that file is in `TWO_PLAYER_PATHS`.

The line goes into the **existing feed**: `Drive.CONFIG.FEED_LINES = 5`, `FEED_SECONDS = 8`, written by
`Hud.renderFeed`. **This deliberately overrides the research note's "max 4, each ~6 s"**: a second feed
region would be a second writer of the same corner of the screen, which costs more than the two
seconds it buys. The note's number is a feel preference; the one-writer rule is not.

Text, as a pure exported formatter (`Hud.killLineText(event)`), so a spec can assert the shape without a
wire:

```
KAREN         MALE BOAR   chest   42 m
<name,-12>    <KIND> BOAR <zone>  <metres> m
```

`animalKind == nil` (kinds off) reads `BOAR` with no kind word.

### 4.3 Why the trigger cannot fire while the panel is open

With the panel open the cursor is free and the player clicks a row. `Weapon.Input`'s handlers are still
bound and every one returns `Pass` by design, so that click would **also fire the gun**. Relying on a
`TextButton` to swallow it is a guess about engine behaviour; `GuiButton.Modal` would free the mouse
itself and fight `Cursor`, which is the one writer of `MouseBehavior` and counts every write it did not
cause (`Cursor.apply`, `reasserts`).

So `Weapon.Input` gains a **tagged hold**, borrowed verbatim from this repo's own `Camera.Cursor`
tag API:

```lua
function Input.requestHold(tag: string)   -- asserts a non-empty tag, as Cursor.requestFree does
function Input.releaseHold(tag: string)
function Input.isHeld(): boolean
function Input.holdTags(): { string }     -- sorted, for a spec
```

While any tag is out, `onFire`, `onReload`, `onSelectAmmo` and `onAim` return `Pass` **without acting**,
and entering the held state clears `aiming` and fires `AimChanged(false)` — the same three lines
`unbind()` already runs. `Input` is still the only firer of `FireRequest`/`ActionRequest`; a caller
states a need and the owner resolves it. The one caller is `ReportPanel`, with the tag `"report"`.

## 5. The remotes

New folder `src/shared/Report/Remotes.model.json` → `ReplicatedStorage.Report.Remotes`
(`src/shared/` is mapped wholesale, so this needs **no** `default.project.json` change and therefore
no Rojo restart and no Connect click):

```json
{ "className": "Folder", "children": [
  { "name": "ReportEvent",   "className": "RemoteEvent" },
  { "name": "ReportRequest", "className": "RemoteEvent" },
  { "name": "ReportData",    "className": "RemoteEvent" } ] }
```

| Remote | Direction | Written by | Payload | Rate |
|---|---|---|---|---|
| `ReportEvent` | server → **all** clients | `HitLog` | `Event` (section 6.4): `kind = "kill" \| "driveOpened" \| "driveClosed"` | one per kill, two per drive |
| `ReportRequest` | client → server | **client `Report.ask`** is the only firer | `{ drive: number?, hunter: number?, page: number? }` | server throttle `REQUEST_MIN_INTERVAL = 0.5 s` per player; over-fast requests are dropped and counted |
| `ReportData` | server → **the asking client only** (`FireClient`) | `HitLog` | `ListPayload` or `DetailPayload` (section 6.4) | one per accepted request |

**The inbound surface, stated in full.** Three optional numbers. `Shape.resolveRequest` (pure) maps
them onto what the server holds: an unknown or absent `drive` becomes the server's current drive; a
`hunter` that has no row in that drive becomes the list view; a `page` outside `1..pages` is clamped.
It never errors, never yields and never trusts a number. A client cannot name an animal, cannot ask for
another drive than the two kept, and cannot ask for more rows than the cap — because the cap is the
server's.

**No `RemoteFunction`.** There is not one in the repo today (grep: the only hit is
`match_client.spec`'s assertion that there is none), and an `OnServerInvoke` that yields is a thread a
client can hold. A request/reply pair of `RemoteEvent`s is the same conversation with no thread.

## 6. The record

### 6.1 How it is fed — two signals, no new source of truth

Wired at each world's composition root, beside the lines that are already there:

```lua
-- MatchBoot.server.luau and ForestTestBoot.server.luau, in the EXISTING handlers:
Weapon.HitReported:Connect(function(report)
    if report.target:IsA("BasePart") then
        runtime:takeHit(report.target, { ... })   -- unchanged
        HitLog.recordHit(report)                  -- NEW
    end
end)

runtime.Downed:Connect(function(record)
    HitLog.recordDown(record)                     -- NEW
    local shooter = ...                           -- unchanged
    if shooter then Weapon.markHit(shooter, "kill", record.killingZone) end
end)
```

`Weapon.HitReported` is already **one report per (shot, target)** — "nine pellets on one boar are one
report with pellets = 9, never nine reports" (`Weapon.Hits.group`) — so the record needs no grouping of
its own. `runtime.Downed` fires **exactly once per boar**: "the Brain reports `downed` on the tick it
enters DOWN and never again, so the kill cannot be published twice"
(`src/server/Boar/init.luau`, the `intent.downed` branch).

**How the two signals are joined.** On the animal's id string:

* `Body.create` sets `part.Name = id` and nothing in `Body.luau` ever reassigns it (grep for `Name =`),
  so `report.target.Name` **is** the boar's id;
* `Wound.killRecord(state, id, …)` is called with `entry.id`, so `record.id` is the same string.

The record is keyed by that string and never by the Instance — an Instance key pins a part that is about
to be destroyed. `HitLog.stats().unmatchedDowns` counts a `Downed` whose id has no record, and a spec
asserts it is zero after a live kill. This is the repo's own degradation idiom (`tallylessHits`,
`unknownZoneHits`, `meshUpgradeFails`): a number in the harness report instead of a feeling in a
playtest.

The animal's kind comes from the attribute its own owner publishes about it:
`report.target:GetAttribute("Kind")` (`Body.create`, Task 123 round 3 — "without this it is a fact
nobody outside the server can see"). `nil` with kinds off, and the report then says `BOAR`.

**The one guard on what is recorded.** Every `HitReport` whose `target` is a `BasePart` is recorded.
Only animals carry `Damageable == true` today (`Body.create`; `Weapon.Hits.targetOf` finds nothing
else), so that is the whole filter. If a player or a prop ever becomes damageable, this is the line that
needs a kind check, and it says so in a comment.

### 6.2 The impact, in the animal's own frame

The decision the brief fixed, and the one that makes the silhouette possible at all. In
`HitLog.recordHit`, at the moment of the hit:

```lua
local part = report.target :: BasePart
local l = part.CFrame:PointToObjectSpace(report.position)   -- the trunk's own frame
local f = Vector3.new(l.X / part.Size.X, l.Y / part.Size.Y, l.Z / part.Size.Z)  -- component by component
```

`Shape.dot(cframe, size, impact)` is the pure function that does it and returns `(u, v, side)`:

* `u = clamp(f.Z + 0.5, 0, 1)` — **0 at the nose, 1 at the tail.** The trunk is 2 × 3 × 5.5 and "a
  Part's LookVector is its -Z" (`Boar.CONFIG.BODY_SIZE` comment), so -Z is the front.
* `v = clamp(0.5 - f.Y, 0, 1)` — **0 at the back, 1 at the belly** (screen y grows downward).
* `side = if f.X < 0 then -1 else 1` — which flank.

Three properties, all load-bearing:

1. **It divides by the part's own `Size`, so it knows nothing about `Boar`.** A cub's trunk is the male's
   times `geometry.clipScale` (`Body.kindGeometry`), and a hit high on a cub's shoulder lands at the
   same `(u, v)` as the same hit on a male. `HitLog` requires neither `Boar` nor its config.
2. **The clamp is why a nose shot reads `u = 0`.** Zone parts stand `PROTRUSION` (0.06–0.15 studs)
   proud of the trunk by design, so a surface impact can be a few hundredths outside the box.
3. **One dot per (shot, target), at the nearest pellet.** `Hits.group` sets the report's `position` to
   the nearest impact's position, so nine buckshot pellets are one dot and not nine — the same rule the
   marker and the damage record already follow.

The dot is computed **once, at the hit**, and only `(u, v, side)` is stored. Nothing later can go stale:
the carcass can collapse, be shoved and despawn, and "high on the shoulder" still means high on the
shoulder.

### 6.3 Shape of the stored record

```lua
type Dot = {
    userId: number?, name: string?,     -- who fired it; strings and ids, never a Player
    zone: string,                       -- report.zone: the dominant zone of that shot
    u: number, v: number, side: number, -- section 6.2
    distance: number,                   -- studs, report.nearest (muzzle to the nearest impact)
    ammo: string, pellets: number,
    at: number,                         -- SERVER os.clock(); never sent as-is (section 6.4)
    fatal: boolean,                     -- set by recordDown, see below
}

type AnimalRecord = {
    id: string, kind: string?,
    firstAt: number, lastAt: number,
    dots: { Dot },                      -- capped at HITS_PER_ANIMAL, newest dropped, counted
    droppedDots: number,
    hits: number,                       -- total hits, including the dropped ones
    result: "wounded" | "down",         -- "wounded" until Downed says otherwise
    downedAt: number?, killedByUserId: number?, killingZone: string?, instant: boolean?,
}

type DriveRecord = {
    number: number, openedAt: number, closedAt: number?,
    animals: { [string]: AnimalRecord }, order: { string },
    animalCount: number, droppedAnimals: number,
}
```

* **`result` starts at `"wounded"`.** An animal with hits and no `Downed` **is** Karen's wounded-lost,
  and it needs no third signal: `recordDown` is the only thing that writes `"down"`, and it also sets
  `fatal = true` on the dot whose `(zone, at)` matches `record.mortalWound` — or on the last dot by
  that shooter if no dot matches, counted as `stats.unmatchedFatal`.
* **A hit on an animal somebody else killed stays in the record**, under its own shooter's dots. The
  list's `kills` column counts `result == "down" and killedByUserId == me`; `lost` counts animals this
  hunter hit that are still `"wounded"` at the close. Two hunters can both have a row for one animal,
  and the detail view shows whose dot is whose by name.

### 6.4 When a record is forgotten

**Two drives are kept: the current one and the previous one.** `DRIVES_KEPT = 2`.

* The current drive is what Tab shows mid-drive.
* The previous one is what the panel is showing when the next drive has already started — a drive
  closes, the panel opens, and in the DEV world the next drive begins `INTERMISSION_SECONDS` later
  while Karen is still reading. Keeping one drive would blank the panel under her.
* Older drives are **dropped whole** when a third opens. Ceiling:
  2 × `ANIMALS_PER_DRIVE_KEPT` (96) × `HITS_PER_ANIMAL` (8) dots — roughly 1,500 small tables for the
  whole server, bounded by construction and not by hope. `BOARS_PER_DRIVE` is 60 today, so 96 is
  1.6× headroom; the 97th animal of one drive drops the oldest and increments `droppedAnimals`.
* Nothing persists. There is no DataStore and no session history: a server restart forgets everything,
  which is correct for a grey-box and is the Director's to change later.

Opening and closing is a **composition-root job**, because only the root knows which world it is in:

```lua
HitLog.openDrive(driveNumber: number, now: number)   -- closes an open one first, then opens
HitLog.closeDrive(now: number)                       -- idempotent; a second call is a no-op
```

* **DEV (`map:v1`)** — `MatchBoot` connects `Match.PhaseChanged`, which fires
  `(before, phase, driveNumber)` (`src/server/Match/init.luau`, `phaseSignal`): `phase == "Assigning"`
  → `openDrive(driveNumber, os.clock())`; `phase == "Scoring"` → `closeDrive(os.clock())`.
* **Forest Test** — `ForestTestBoot` latches on the period index (section 10).

Both calls broadcast `ReportEvent` with `kind = "driveOpened"` / `"driveClosed"`, so no client has to
infer a drive boundary from a phase it may not have.

### 6.5 Wire types (`src/shared/Report/init.luau`)

Dense arrays or pure dictionaries only, no holes, no mixed keys — the rule
`src/shared/Drive/init.luau` states for `ScoreRow` ("a table that is neither a dense array nor a pure
dictionary does not survive the wire faithfully").

```lua
export type WireDot = { userId: number?, name: string?, zone: string, u: number, v: number,
                        side: number, distance: number, pellets: number, at: number, fatal: boolean }

export type AnimalRow = { id: string, kind: string?, result: string, zone: string, distance: number,
                          hits: number, droppedHits: number, at: number, dots: { WireDot } }

export type HunterRow = { userId: number, name: string, kills: number, lost: number, hits: number,
                          animals: number,
                          byKind: { male: number, female: number, cub: number, unknown: number } }

export type ListPayload   = { view: string, drive: number, openedAt: number, seconds: number,
                              closed: boolean, rows: { HunterRow }, animals: number, truncated: boolean }
export type DetailPayload = { view: string, drive: number, userId: number, name: string,
                              page: number, pages: number, rows: { AnimalRow } }
export type Event         = { kind: string, drive: number, userId: number?, name: string?,
                              animalKind: string?, zone: string?, distance: number?, at: number }
```

**Every `at` and `seconds` on the wire is seconds since the drive opened**, computed by `Shape` from
`drive.openedAt`. `byKind` always carries all four keys as numbers (never `nil`), so it is a pure
dictionary with no holes.

## 7. The payload, bounded

The brief's test — 60 animals and 8 hunters must not arrive as one unbounded table — is met by splitting
the view in two and capping both. All caps are in `Report.CONFIG`, read by the **server** (`Shape`) and
by the panel, which draws at most what it can fit.

| Cap | Value | Why |
|---|---|---|
| `HUNTER_ROWS_MAX` | 16 | `Match.CONFIG.MAX_PLAYERS`, mirroring `Drive.CONFIG.SCORE_ROWS_MAX` |
| `ANIMALS_PER_PAGE` | 8 | one screen at 1920×1080 (section 8.3) |
| `HITS_PER_ANIMAL` | 8 | dots kept and sent per animal. A shotgun's nine pellets are **one** hit |
| `ANIMALS_PER_DRIVE_KEPT` | 96 | `BOARS_PER_DRIVE` 60 × 1.6 |
| `DRIVES_KEPT` | 2 | section 6.4 |
| `REQUEST_MIN_INTERVAL` | 0.5 s | per player, server-side |

Worst case on the wire: the **list** is 16 rows × 10 values ≈ 180 values. The **detail** is 8 rows ×
(8 dots × 10 values + 8 fields) ≈ 700 values. Both are one small `FireClient` and neither grows with
the number of animals in the drive: a hunter with 40 animals gets 5 pages, and `pages` is in the
payload so the footer can say so.

**The data path, end to end:**

1. Karen presses Tab (or a drive closes). `ReportPanel` asks the replica:
   `Report.ask(nil, nil, 1)` → `ReportRequest:FireServer({ page = 1 })`.
2. `HitLog`'s handler throttles, then `Shape.resolveRequest` resolves the three numbers, then
   `Shape.list(drive, config)` builds the payload and `ReportData:FireClient(player, payload)`.
3. The replica freezes it (`Drive.deepFreeze`, re-exported from `Shotgun` — not a second copy), stores
   it and fires `Report.Data`.
4. `ReportPanel.render(payload)` draws it. `render` is **public** for the same stated reason
   `Hud.renderScore` is: "a drive is 600 seconds long, so no harness run ever reaches the Scoring
   phase", and a spec that cannot hand the panel a payload cannot prove the panel is really on screen —
   which is the one check `docs/PROJECT_CONTEXT.md`'s "a visibility audit certified a blank screen
   twice" demands.
5. A click (or `Enter`) on a row → `Report.ask(drive, userId, 1)` → the same path with
   `Shape.detail`.

The client never computes a count, a sort order or a placement. It draws what arrived.

## 8. The panel

### 8.1 List view — "how much I killed compairing others"

```
DRIVE 3   REPORT                                       4:58       [TAB] CLOSE
#  NAME              MALE  FEM  CUB   KILLS  LOST   POINTS
1  Karen                2    1    0       3     1       34
2  Dana                 1    0    0       1     0       12
3  Someone              0    0    0       0     2        0
                                        [ENTER] DETAILS
```

* Sorted **kills desc, then hits desc, then userId asc** — deterministic, so two clients never disagree
  about the order. `Shape.list` sorts; the panel does not.
* The local player's row is tinted `Drive.CONFIG.SCORE_HIGHLIGHT_COLOR`, as the score panel already
  does.
* **`POINTS` comes from `Match.get().rows`, joined on `userId`, on the client.** Blank when there is no
  `Match`. The report payload has no points field (section 2).
* **A hunter who hit nothing has no row in the payload** — `HitLog` knows no roster. The panel **merges
  in the remaining roster rows as zeros** from `Match.get().rows` when a `Match` exists, so in the real
  game you can see that you are behind. With no `Match` (the Forest Test) only hunters who hit something
  appear, which there is Karen alone.

### 8.2 Detail view — "see boars where was the hit"

One row per animal, newest first:

```
KAREN   DRIVE 3   3 KILLED, 1 LOST                       [BACKSPACE] BACK
 [silhouette]   MALE     DOWN     chest    12 m   2 hits   t+41s
 [silhouette]   FEMALE   WOUNDED  legs     22 m   1 hit    t+96s
                                                   PAGE 1/2  [<] [>]
```

The silhouette is **five frames and a dot per hit** — no art, no mesh, no viewport:

* a base `body` rectangle (the whole trunk) and four zone rectangles over it, from
  `Report.CONFIG.SILHOUETTE`, each tinted with the zone's own colour;
* one 6-px `Frame` per dot at `UDim2.new(dot.u, 0, dot.v, 0)` inside the silhouette frame, anchored
  centre. The **fatal** dot is drawn in `HIT_MARK_KILL_COLOR`, the others white; a far-flank dot
  (`side == -1`) is drawn at 0.55 transparency so you can see which side of the animal it came from;
* `distance` is the fatal dot's for a kill, else the first dot's, converted to **metres** in the panel
  (`METRES_PER_STUD = 0.28`, the figure `Shotgun.CONFIG`'s own header derives everything from). A
  hunting report in studs is a report nobody reads.

**The rects are derived, not drawn by eye, and a spec stops them drifting.** Projecting
`Boar.CONFIG.ZONES` through `Shape.dot`'s own mapping (`u = (z + 2.75)/5.5`, `v = (1.5 - y)/3`,
clamped) gives:

| zone | box in trunk space | u0–u1 | v0–v1 |
|---|---|---|---|
| `head` | z -2.81…-1.45, y 0.35…1.65 | 0.000–0.236 | 0.000–0.383 |
| `chest` | z -1.45…+0.25, y -0.45…1.56 | 0.236–0.545 | 0.000–0.650 |
| `rear` | z +1.10…+2.90, y -0.30…1.56 | 0.700–1.000 | 0.000–0.600 |
| `legs` | z -2.55…+2.85, y -1.50…-0.50 | 0.036–1.000 | 0.667–1.000 |
| `body` | the trunk | 0.000–1.000 | 0.000–1.000 |

The four zone rects are **pairwise disjoint in this projection** — a property worth asserting, because
a dot can then only ever sit in one named zone. What is left over is `body`: the flank between chest
and rump (u 0.545–0.700), the brisket under the head, the band at v 0.60–0.667. That is exactly what
the trunk's own comment says `body` is — "belly, flank, rear and brisket — whatever no zone part
covers" — so the picture tells the truth about the model.

`tests/server/report_silhouette.spec.luau` requires **both** `Boar` and `Report` and asserts
rect-by-rect and tint-by-tint that `Report.CONFIG.SILHOUETTE` equals
`Shape.rectOf(zone.size, zone.offset, Boar.CONFIG.BODY_SIZE)`, plus the disjointness. A zone box that
moves fails the harness. This is the pattern `MatchBoot`'s arena assertion already uses — "the arena
changed … but `Boar.CONFIG.field` still says …" — a hand-carried constant with a check that fails when
its source moves.

### 8.3 Layout, and how it closes

| | value |
|---|---|
| `PANEL_WIDTH` / `PANEL_HEIGHT` | 760 × 640 px, centred, ZIndex **10** (over the feed at 1, the score panel at 5) |
| list row / rows | 22 px (the score panel's) × 16 = 352 px |
| detail row / rows | 68 px × 8 = 544 px; silhouette 110 × 60 px (the boar is 5.5 × 3) |
| title / header / footer | 28 / 22 / 24 px |
| panel colour | `Drive.CONFIG.SCORE_PANEL_COLOR`, transparency 0.25 — the same panel Karen already accepted |

640 px tall fits 1080p with 440 px to spare, which is the note's "one screen, no scrolling at 1920×1080
for 8 hunters". The font is `Enum.Font.Code` and the columns are `string.format`-padded, like every
other panel in this repo.

**Opening and closing, and the one state that decides it.** `ReportPanel` holds `open: boolean`,
`view`, `selected: number?`, `page: number` and `autoOpenedFor: number?`, and is the only writer of all
five.

* `DrivenHunt.Report.Toggle` (**Tab**) — opens on the list, or closes from anywhere.
* `DrivenHunt.Report.Back` (**Backspace**) — detail → list; on the list, closes.
* `DrivenHunt.Report.Up` / `.Down` (**arrow keys**) — move `selected`.
* `DrivenHunt.Report.Open` (**Enter**) — list → that hunter's detail.
* `DrivenHunt.Report.Page` (**left/right arrows**) — pages the detail.
* A click on a row's `TextButton` does what `Enter` does. **`Escape` is not bound**: it is the Roblox
  menu's and cannot be taken.

The prefix `DrivenHunt.Report.*` is **reserved to this module**, the convention `GAME_DESIGN.md`'s
*Input* row sets out ("there is no global input router. Each system owns its own named actions under a
reserved prefix"). Every handler returns `Pass`, like every other handler in the repo.

**On open** `ReportPanel` does exactly three things besides drawing: `Cursor.requestFree("report")`
through `CameraSystem.Cursor` (the tagged request API, not a write),
`Weapon.Input.requestHold("report")` (section 4.3), and `Report.ask(...)`. **On close** it releases both
tags. With **no camera** (`Hud` already resolves it with a bounded `WaitForChild("Camera", 5)` and
tolerates nil) the cursor request is skipped and the keyboard path is the only way to drive the panel —
which is why the keyboard path exists and is not a nicety.

**Tab belongs to the Roblox player list on PC**, and a `ContextActionService` binding cannot take a
CoreGui key. So `Hud.start()` calls
`StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)` once. `Hud` is the one writer of
`SetCoreGuiEnabled` — it already owns screen space — and this is its only call. A client spec asserts
`GetCoreGuiEnabled(PlayerList) == false` **and** that `DrivenHunt.Report.Toggle` is bound, so "Tab
reaches us" is a check and not a hope. **I could not verify the Tab/PlayerList binding in this place**
(no Studio in an Architect run): if the playtest shows Tab still opening the player list, the key is one
value — `Report.CONFIG.TOGGLE_KEY` — and changing it is Karen's call, not a redesign.

### 8.4 A drive ending while the panel is open; a player joining mid-drive

* **Drive closes, panel already open** → the panel does **not** re-open or jump. `ReportPanel` hears
  `Report.DriveClosed(event)` and **re-asks for the same view** on the drive that just closed, so the
  numbers settle into their final values and the title stops counting down. If the player was in a
  detail view, they stay in it.
* **Drive closes, panel closed** → it **auto-opens once**, on the list, and `autoOpenedFor` is set to
  that drive number so it never re-opens itself for the same drive. If Karen closes it, it stays closed.
* **Drive opens** → if the panel is open it is closed (the drive is starting; a panel over the first
  crossing is the modal mistake `theHunter` makes), and `selected`/`page` are reset.
* **Joining mid-drive** → the joiner missed `driveOpened`, and it does not matter: `Report.ask(nil, …)`
  means "whatever drive the server thinks is current", resolved **server-side**. Tab works on the first
  press and shows the whole drive so far, including kills from before they joined. The server keeps no
  per-player state except one throttle timestamp, dropped on `PlayerRemoving`.
* **A player who left** keeps their row: their `userId` and `name` are in the record. The score panel
  already does this ("a leaver's row stays on this drive's screen").

## 9. What it reads from and writes to other systems

| Direction | What | The other side's owner | Shape |
|---|---|---|---|
| `HitLog` ← | `Shotgun.HitReport` (shooter, target, zone, zones, pellets, nearest, position, normal, ammo, at) | `ServerScriptService.Weapon` | published signal, wired at the composition root |
| `HitLog` ← | `Wound.KillRecord` (id, kind, killedByUserId, killingZone, mortalWound, instant…) | `ServerScriptService.Boar` | published signal, wired at the composition root |
| `HitLog` ← | `part:GetAttribute("Kind")`, `part.Name`, `part.CFrame`, `part.Size` | `Boar.Body` publishes them about itself | read-only attribute/property read, as `Weapon.Hits.targetOf` reads `Damageable`/`HitZone` |
| `HitLog` → | `ReportEvent`, `ReportData` | its own remotes | it is their only writer |
| `HitLog` → | nothing else. It writes no boar, no score, no character, no camera | | |
| `ReportPanel` ← | `ListPayload`/`DetailPayload`, `Report.Killed`, `Report.DriveClosed` | `PlayerScripts.Report` | read |
| `ReportPanel` ← | `Match.get().rows` for the points column and the zero rows | `PlayerScripts.Match` (replica, no setter) | read, may be nil |
| `ReportPanel` → | `Cursor.requestFree/release("report")` | `PlayerScripts.Camera.Cursor` | **tagged request**, the camera still writes the mouse |
| `ReportPanel` → | `Input.requestHold/releaseHold("report")` | `PlayerScripts.Weapon.Input` | **tagged request**, the weapon still fires the remote |
| `Hud` ← | `ReportPanel.isOpen()` for `scorePanelVisible`; `Report.Killed` for the feed line | | read |
| `Hud.showHitMark` → | `Hud.Sound.tick(kind)` | `PlayerScripts.Hud.Sound` | one call site |
| `MatchBoot` → | `HitLog.openDrive/closeDrive` on `Match.PhaseChanged` | | boot wiring |
| `ForestTestBoot` → | `HitLog.openDrive/closeDrive` on the period latch | | boot wiring |

The dependency direction stays one-way everywhere it already was: the weapon has no reference to the
Hud, the camera has no reference to the Hud, `Match` has no reference to `HitLog`, and `HitLog` has no
reference to `Match`, `Boar` or `Weapon`.

## 10. The Forest Test's drive length, and what "the next drive starts" means there

**Where it lives:** `src/shared/ForestTest/init.luau`, beside every other number for that world:

```lua
-- THE REPORTING WINDOW, and nothing else: it moves no animal and resets no schedule.
ForestTest.DRIVE = { seconds = 300 }   -- the Director's 5 minutes: ~15 waves at the 20 s interval
```

**The period index**, pure, in `src/server/ForestTest/init.luau` beside the other pure half:

```lua
function ForestTest.driveIndexAt(startedAt: number, now: number, config): (number, number)
    -- (index starting at 1, secondsLeft) ; index = floor((now - startedAt) / seconds) + 1
function ForestTest.drive(now: number)   -- the live reader over state.startedAt
```

`ForestTestBoot` already has one Heartbeat with a `lastReportAt` latch; it gets one more latch:

```lua
local lastDriveIndex = 0
-- in the existing Heartbeat:
local drive = ForestTest.drive(now)
if drive.index ~= lastDriveIndex then
    if lastDriveIndex > 0 then HitLog.closeDrive(now) end
    lastDriveIndex = drive.index
    HitLog.openDrive(drive.index, now)
end
```

**"The next drive starts" there means exactly one thing: the report's window rolls over.** The wave
schedule, `state.waveIndex`, the active waves, the boars on the ground and the hunter's stand are all
untouched — resetting the cycle would change the push rhythm Karen accepted in Task 123, and nothing
asked for that. So at t+300 s the panel auto-opens with the first five minutes' tally, the animals keep
crossing, and the record starts again. The drive bar stays hidden in that world (no `MatchState` is
ever sent); the panel's own title carries the clock.

## 11. External sources

Named, linked, with licence and maintenance status. Nothing below is copied into the game; the first
three are design claims, the last three are the engine APIs this design rests on.

| Source | Licence / status | Does well | Does badly | Adopted? |
|---|---|---|---|---|
| [theHunter: Call of the Wild — Harvest Screen](https://thehuntercotw.fandom.com/wiki/Harvest_Screen) (Fandom wiki) | CC BY-SA 3.0. Live, community-maintained. **Read through search extracts: the page answered HTTP 402 to a fetch**, so it is quoted from the extract and not the page | The genre's standard post-kill screen: one animal, a list of shots, each with where it landed and how far away it was. Exactly the shape of the "details" half of Karen's ask | Modal and slow: it stops the hunt for one animal at a time, which is wrong for a drive where six animals cross in a minute | **The shape, not the moment.** One animal per row, a place and a distance per shot — but at the end of the drive, not in the middle of it |
| [Way of the Hunter — damage model / bullet-cam thread](https://steamcommunity.com/app/1288320/discussions/0/4691153988129135177/) (Steam Community) | Steam Subscriber Agreement; user content. Live, fetched and quoted | The richest version of the idea, and the clearest statement of the rule that matters: *"only organs where the bullet actually penetrated the organ are indicated on the energy graph"* — show only what the model knows | Needs a ballistics model this game does not have: per-organ joules, penetration split from cavitation, a rig to author. Its own players complain about organs drawn but not simulated | **Rejected as a screen, adopted as a rule.** `Boar.CONFIG.WOUND` is damage points per zone, not joules, so the silhouette is divided into exactly the five zones `WOUND.DAMAGE` has rows for, and its words come from the same table |
| [Hunting Simulator 2 — "No multiplayer?"](https://steamcommunity.com/app/1135910/discussions/0/2567564692475501394/) + [thexboxhub review](https://www.thexboxhub.com/hunting-simulator-2-review/) | Steam Subscriber Agreement / editorial copyright. Both live | **A negative result, and the most useful one**: the hunting sims show YOUR animal and have no hunter-vs-hunter table at all. So "how much I killed compairing others" is not a solved pattern in this genre and has to be designed | Tells us nothing about how to draw it | **Adopted by borrowing elsewhere:** the comparison half is the ordinary competitive **scoreboard** — name, counts, a score, sorted, one row each, a detail view behind a click. Which is what this repo's own score panel already is, so the list view is that panel with three more columns |
| [`CFrame:PointToObjectSpace`](https://create.roblox.com/docs/reference/engine/classes/CFrame#PointToObjectSpace) (Roblox Creator Docs) | Content CC BY 4.0 ([Roblox/creator-docs](https://github.com/Roblox/creator-docs)). Actively maintained | One call turns a world impact into a point in the animal's own frame, which is the only representation that survives the carcass | Nothing — it is the exact primitive needed | **Adopted.** Section 6.2 |
| [Remote events and callbacks / security](https://create.roblox.com/docs/scripting/events/remote-events-and-callbacks) (Roblox Creator Docs) | CC BY 4.0. Actively maintained | States the rule this design's inbound remote obeys — never trust the client — and documents why a `RemoteFunction` server callback is a yield a client can hold | Does not bound payload size for you; that is the designer's job (section 7) | **Adopted**, and it is the same page `src/server/Weapon/init.luau` and `src/shared/Drive/init.luau` already cite. Request/reply as two `RemoteEvent`s, validated by a pure resolver |
| [`StarterGui:SetCoreGuiEnabled`](https://create.roblox.com/docs/reference/engine/classes/StarterGui#SetCoreGuiEnabled) / [`Enum.CoreGuiType`](https://create.roblox.com/docs/reference/engine/enums/CoreGuiType) (Roblox Creator Docs) | CC BY 4.0. Actively maintained | The documented way to take a key CoreGui holds — disable the core player list and Tab is yours | Global: it turns the stock player list off for good, which this game does not need anyway | **Adopted**, with one writer (`Hud`) and a spec that asserts the state. **Not verified in this place** |

**Where this design borrows (rule 2).** The tagged-request API for the cursor and for the input hold is
borrowed **from this repo**: `src/client/Camera/Cursor.luau` ("a TAGGED REQUEST API instead of a
setter … Three systems can want a free cursor and there is still exactly one writer"). The
pure-core-under-one-owner split (`HitLog` + `Shape`) is borrowed from `Weapon` + `Hits`/`Validator` and
from `Boar` + `Wound`. The derived-constant-with-an-assertion guard is borrowed from `MatchBoot`'s arena
assertion. Nothing here is invented that an established pattern already covers, which is rule 2's whole
point.

## 12. Numeric targets

| | target | why |
|---|---|---|
| hit marker on screen | **0.35 s** hit, **0.80 s** kill | long enough to read in peripheral vision, short enough not to sit over the next animal. Today's 0.15 s is four frames at 30 fps |
| tick volume | 0.35, ids empty until Karen picks them | an empty id plays nothing and is not an error |
| kill lines on screen | the existing feed: **5 lines, 8 s** | one writer of that corner. Overrides the note's 4 / 6 s on purpose (section 4.2) |
| report opens | at drive close, and on **Tab** at any time | the Forest Test has no drive end, so it gets both |
| Forest Test drive length | **300 s** | the Director's number: ~15 waves at the 20 s interval |
| dots per animal | **8** kept and sent; a shotgun's nine pellets are **one** | `Hits.group` has already grouped them |
| silhouette zones drawn | **5** | exactly the rows `WOUND.DAMAGE` has |
| animals per detail page | **8**; pages reported in the payload | one screen |
| hunter rows | **16** | `Match.CONFIG.MAX_PLAYERS` |
| animals kept per drive / drives kept | **96** / **2** | 1.6× `BOARS_PER_DRIVE`; the panel must not blank when the next drive starts |
| detail payload ceiling | ~700 values per page | 8 rows × (8 dots × 10 + 8) — does not grow with the drive |
| request throttle | **0.5 s** per player; over-fast requests dropped and counted | one inbound remote, bounded |
| panel | 760 × 640 px, ZIndex 10 | fits 1080p with 440 px spare |
| distance shown | metres, `0.28 m` per stud | the unit a hunter reads; the payload carries studs |
| `HitLog.stats()` zeros | `unmatchedDowns == 0`, `unmatchedFatal == 0`, `dropped == 0` after a live kill | the join between the two signals is a measured number, not a belief |

## 13. How it is tested

**The DEV place is not open, so none of this can be gated in this run.** What follows is what the build
must ship and what a later gate must cover — and the honest part first: **`src/server/MatchBoot.server.luau`
is in `TWO_PLAYER_PATHS`** (`tools/agents.py`), and this design touches it, so the **merge gate needs
`[harness2]` as well as `[harness]`**. The Forest Test half does not (section 15 gives the Director a
seam if they want to avoid the human click this round).

### Server specs (`tests/server/`)

`hitlog.spec.luau` — the pure half runs in microseconds with no world, the way `boar_wound.spec` does:

1. `Shape.dot` against hand-computed numbers: a point at the trunk's nose face → `u ≈ 0`; at the tail
   → `u ≈ 1`; on the back → `v ≈ 0`; on the belly → `v ≈ 1`; a point 0.1 proud of a zone face →
   clamped into `[0, 1]`; `side` from the sign of local X. Falsifiable: swap the Y sign and it goes red.
2. **Scale invariance**: the same relative point on a trunk of half the size gives the same `(u, v)`.
   This is the cub case, and it is why `Shape.dot` divides by `part.Size`.
3. `Shape.rectOf` and the five rects of section 8.2, including **pairwise disjointness**.
4. `Shape.list`: the sort (kills desc, hits desc, userId asc), `byKind` carrying all four keys as
   numbers, `lost` counting animals this hunter hit that never died, and **no `points` field anywhere
   in the payload** (the "no second score" rule as an assertion).
5. `Shape.detail`: paging, `HITS_PER_ANIMAL`, `droppedHits`, `pages`, and every `at` being seconds
   since `openedAt` and never a raw `os.clock()` (assert it is under the drive's own length).
6. `Shape.resolveRequest` with hostile input: a string, a negative page, a drive that was dropped, a
   hunter with no row, `nil`, a table with extra keys — every one resolves to something safe and
   nothing raises.
7. `openDrive`/`closeDrive`: `DRIVES_KEPT`, the third drive dropping the first, `closeDrive` twice being
   a no-op, and an animal arriving with no drive open being counted rather than crashing.
8. The **live join**, through the real path the game uses: a real boar, a real
   `Weapon.HitReported`-shaped report and a real `Downed` record — the record's id equals the boar's id,
   the dot's zone equals the charged zone, `result` goes `"wounded"` → `"down"`, `fatal` lands on the
   mortal dot, and `stats().unmatchedDowns == 0`.

`report_silhouette.spec.luau` — the drift guard of section 8.2: `Report.CONFIG.SILHOUETTE` equals the
projection of `Boar.CONFIG.ZONES`, rect by rect and tint by tint, plus disjointness. **A zone box that
moves fails the harness.**

`report_remotes.spec.luau` (or folded into `hitlog.spec`) — `ReplicatedStorage.Report.Remotes` holds
**exactly three RemoteEvents and no RemoteFunction**; `Report.CONFIG` is deep-frozen (a write raises);
`Report.CONFIG` carries **no rule number** — no damage value, no points, no safety angle. The existing
`match_client.spec` assertion that `Drive.Remotes` still has exactly two is the other half of that
fence and must stay green.

### Client specs (`tests/client/`)

`report_client.spec.luau`:

1. **The wire.** The replica is connected to all three remotes, and `Report.ask` is the only thing in
   the client tree that fires `ReportRequest` (grep-backed claim plus a `stats().requests` count).
2. **The panel exists and is really on screen.** `HunterHud.ReportPanel` exists, is hidden by default,
   and when opened **every ancestor up to the `ScreenGui` is visible and `Enabled`** — the explicit
   answer to `docs/PROJECT_CONTEXT.md`'s "a visibility audit ignored parent visibility and certified a
   blank screen twice". The same walk `tests/client/camera_client.spec` already does for the crosshair.
3. **The drawing**, through `ReportPanel.render(payload)` with a payload the spec owns: N rows drawn
   for N rows in the payload and none for the rest; the local player's row highlighted; a dot's pixel
   position inside the rect of its own zone for all five zones (compute `dotPosition` and check it
   against `Report.CONFIG.SILHOUETTE[zone]`); the fatal dot's colour; a far-flank dot's transparency.
4. **The two panels never both show**: `Hud.scorePanelVisible(snapshot, reportOpen)` for all four
   combinations, and the live `ScorePanel.Visible` false while the report is open.
5. **The input hold**: `Weapon.Input.requestHold("report")` then a replayed left click sends **no**
   `FireRequest` (count it off `Weapon.stats()`/the client's own counter), and releasing restores it.
   `Input.isHeld()` and `holdTags()` after open and after close.
6. **Tab is reachable**: `GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList) == false` and
   `ContextActionService:GetAllBoundActionInfo()` contains `DrivenHunt.Report.Toggle`.
7. **The kill line**: `Hud.killLineText(event)` shape; `feedTextFor` returning nil for a `Match` `kill`
   entry, so one kill draws **one** line and not two; `Hud.feedText()` after one of each.
8. **The tick**: `Hud.Sound.stats()` counts a tick per `showHitMark`, and an empty id plays nothing and
   raises nothing.

### Harness input (`tests/client/input_scenarios.txt`)

A new scenario `report-after-a-kill`, staged like the existing `shoot-the-boar` one
(`"stage": { "targetFolder": "Boars", "offsetStuds": [0, 1.5, 22] }`): shoot the staged boar until it
goes down, then `keyPress Tab`, `wait`, `keyPress Down`, `keyPress Return`, `wait`. The spec asserts the
panel opened, the list carried one row with one kill, the detail carried one animal, and that animal
carried at least one dot whose zone is the zone the kill record named. **That is the player's path end
to end** — trigger, server record, remote, panel — and it is the one test that cannot pass while any
link is broken.

**What the harness cannot do here**, so I am not pretending otherwise (Task 6's list: no touch, no
gamepad, no `textInput`, no frame-counted holds, no input aimed at an instance, nothing after the client
report):

* **It cannot click a GUI row.** A `moveTo` is a pixel, not a row, and under
  `MouseBehavior = LockCenter` a `moveTo` delivers no usable delta at all
  (`docs/design/camera.md` 9.3). The **keyboard** path is therefore the harness path, and the
  **mouse** path is covered by a client spec driving the row's `Activated` plus Karen's playtest. This
  is exactly why the keyboard bindings are in the design and not an extra.
* **It cannot reach a drive end.** A drive is 600 s. The auto-open is tested by calling
  `ReportPanel.onDriveClosed(event)` — public for the reason `Hud.renderScore` is public — and by the
  Forest Test's 300-second window at a real playtest.
* **It cannot judge whether it looks right.** Rule 5: `python tools/studio_mcp.py capture
  report-list` and `capture report-detail`, **inspected by eye** before any claim about the panel. The
  previous project measured a knife as correct for three rounds while it was held backwards.

### What a later DEV gate must cover

1. `[harness] PASS … scope=all` for the code commit, and **`[harness2] PASS` for the same commit**,
   because `src/server/MatchBoot.server.luau` is in `TWO_PLAYER_PATHS`.
2. `python tools/flags.py clear` and `python tools/pose.py clear` first — both runs refuse to start
   while an override is set.
3. The two screenshots above, inspected.
4. A Forest Test session, by Karen: a kill line appears, the marker ticks, Tab opens the panel, a dot
   sits where she remembers shooting the animal, and at five minutes the panel opens itself.

## 14. What this design does not do, and why

1. **It does not retire `Match`'s `kill` feed entry.** `src/server/Match/Phase.luau` is outside this
   task's blast radius and inside `TWO_PLAYER_PATHS`. The entry still crosses the wire and the Hud
   ignores it. Queue: one branch in `Phase.luau`, one `[harness2]` run.
2. **It does not use `runtime.Despawned`.** With two signals, "hit and never died" is the honest answer
   and it is the one Karen asked for. `Despawned` would let the report distinguish *escaped over the
   exit line* from *still out there when the drive ended*, which is a better word for the same row and
   a third subscription. Queue it; it is additive.
3. **No trophy score, no meat weight, no bullet path, no 3-D model.** This game has no such model, and
   inventing one to fill a panel is the mistake Way of the Hunter's own players describe.
4. **No persistence.** One server's lifetime. A DataStore is the Director's scope call, later.
5. **No drive bar in the Forest Test.** The panel's own title carries that world's clock; nothing else
   there publishes a `MatchState`.

## 15. Build order, if the Director wants a seam

The design is buildable as one task. If they would rather not spend the two-player click this round,
there is a clean cut, and each half gates on its own:

* **Stage A — the record and the moment.** `src/shared/Report/` (types, remotes, CONFIG),
  `src/server/HitLog/`, the marker retune, `src/client/Hud/Sound.luau`, the kill line in the Hud feed,
  and the Forest Test wiring (`ForestTest.DRIVE`, `driveIndexAt`, the `ForestTestBoot` latch).
  Nothing in `TWO_PLAYER_PATHS` **except** the `MatchBoot` wiring — leave that out and stage A is a
  one-player gate.
* **Stage B — the panel.** `src/client/Report/`, `src/client/ReportBoot.client.luau`,
  `src/client/Hud/ReportPanel.luau`, the `Hud` changes, the `Input` hold, the `MatchBoot` wiring (and
  with it the `[harness2]` line).

Karen gets the hit indicator and the kill log — the two things she notices in the first minute — at the
end of stage A.

## 16. Open decisions

**Blocking: none.** Every decision needed to build is above.

**Karen (feel):**

1. The two tick sound ids (`HIT_MARK_SOUND_ID`, `HIT_MARK_KILL_SOUND_ID`). Empty until she picks them,
   and an empty id plays nothing.
2. 0.35 s / 0.80 s for the marker — one playtest answers it; it is two numbers in `Shotgun.CONFIG`.
3. **Tab**, if the core player list turns out to keep it (section 8.3). One value.
4. Metres or studs in the detail row. The design says metres.
5. Whether the report should auto-open at a drive end at all, or only on Tab. The design auto-opens
   once per drive and never re-opens after she closes it.
6. Whether the old score panel should go away entirely once she has used the report in a real drive.
   Suppressed-while-open today; retiring it is a separate task.

**The Director (scope):**

1. One task or the two stages of section 15 — and with it, whether this round pays for the two-player
   run.
2. Items 1 and 2 of section 14 (`Phase.luau`'s dead `kill` entry; `Despawned` for "escaped" vs "lost").
3. Persistence across servers, if a hunter's history is ever to mean more than one session.

## 17. Mirror in `GAME_DESIGN.md`

Rule 3 says the *System owners* table mirrors these designs. The rows to add or amend:

* **new** — "**The hit record** (who hit what, where, and did it die; the impact in the animal's own
  frame)" → `ServerScriptService.HitLog`, `src/server/HitLog/`, this design.
* **new** — "**Report wire contract and layout** (`ReplicatedStorage.Report`: types, `remotes()`,
  `CONFIG` including the silhouette rects, and `Report.Remotes`' three RemoteEvents)" → nobody at run
  time, deep-frozen, `src/shared/Report/`.
* **new** — "**Report client replica** (the three remotes; the one firer of `ReportRequest`)" →
  `PlayerScripts.Report`, booted by `PlayerScripts.ReportBoot`, `src/client/Report/`.
* **amend the UI row** — `PlayerGui.HunterHud` now also holds the **report panel**, whose one writer is
  `PlayerScripts.Hud.ReportPanel` inside the frame the Hud creates for it; `Hud` is also the one writer
  of `SetCoreGuiEnabled` (one call: the core player list off, so Tab is ours), and
  `Hud.scorePanelVisible(snapshot, reportOpen)` is the one writer of the score panel's visibility.
* **amend the Hud row** — the Hud's own 2-D feedback sounds have one writer,
  `PlayerScripts.Hud.Sound`.
* **amend the Input row** — add `DrivenHunt.Report.*`, reserved by `PlayerScripts.Hud.ReportPanel`;
  note that `PlayerScripts.Weapon.Input` now resolves **tagged holds** (`requestHold`/`releaseHold`) and
  is still the only firer of `FireRequest`/`ActionRequest`.
