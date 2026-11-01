# Design: stand-pick — the hunter takes his stand on the map before the drive

Task 323 · Architect · 2026-10-31 · written to `reviews/task-323/BRIEF.md`, which **overrides anything
older** in `docs/`, `TASKS.md` or an earlier design (`docs/ARCHITECT_PROMPT.md`). D1–D10 are not
re-opened. What this document rules on is everything the brief left to the Architect: where the window
sits, the phase arithmetic, the one owner, the wire, the seam into placement, the map deltas, the edge
cases, the tests and the task split.

Karen, 2026-10-31 ~21:00: *"…choose shooting place on map before hunt"*.

---

## 0. The three facts this design is built on, and they are all already in the repo

Read these first, because two of them change the obvious answer.

**F1. There is already a stand pick, and it is a WALK.** `src/server/ForestTest/init.luau` holds
`state.picks` (`{ [userId] = { index, lockedAt } }`) with `ForestTest.openPick`, `.lockPick`,
`.clearPick`, `.pickOf`, `.standIndexOf` and `.standArea`. Its own comment states the rule:
*"THE NEAREST STAND to a position, which is how a hunter picks one: he walks to it… standing on it IS
the selection"* (`ForestTest.nearestStand`). `ForestTestBoot`'s `openPickFor` opens it at
`Running` and `task.delay(Data.PICK.seconds, …)` locks whatever he is nearest to. **This design does
not add a second pick. It replaces the walk's DECISION with the map's, and leaves every reader of
`state.picks` — the ring, the soft wall, `standArea`, `hunterStandX` — untouched.**

**F2. There is already a whole-line stand deal.** `HighSeats.dealLine(walk, seated, entitled, count)`
(`src/shared/HighSeats/init.luau`) answers *every* hunter's stand in one pass, by serial dictatorship,
and its header says why it must: *"`Match` places players ONE AT A TIME … and a per-player rule cannot
be collision-free: two hunters independently skipping the same seat land on the same ground stand."*
`Match`'s `placementLine(team)` builds `{ count, entitled }`; `ForestTestBoot`'s `placement` closure
calls `dealLine` and hands the answer to `Body.placementFor`. **This is the one seam the pick enters.
It needs one more parameter and no new call site.**

**F3. `Assigning` is five seconds long, and placement happens at its FIRST instant.**
`Match.CONFIG.INTERMISSION_SECONDS = 5`; `Phase.enterAssigning` emits `assignTeams`, `clearBoars`,
`hold`, **`placePlayers`**, `refreshArming` in one list. So a 15-second window "inside `Assigning`,
before hunters are placed" (brief D2) does not exist today in either dimension. §3 rules on both.

---

## 1. What it must do, and what it must not do

### 1.1 Must do

1. Give every **hunter** (D1) a window at the start of each drive in which he takes one of that drive
   place's numbered stands by tapping or clicking it on the **existing** map (D3).
2. Let the **server** decide: first request wins, a taken stand cannot be taken, he may change his
   pick to another free stand until the window closes, and a stand freed by a change or a leave is
   free again at once (D4).
3. Show every hunter, on one snapshot, which stands are **free**, **taken and by whom**, **his own**,
   and which carry a **high seat** (D3, `high-seats.md`).
4. Place him on the stand he took, through the seam that already exists (F2), so **`Body` stays the
   one writer of where a character stands**.
5. Place a hunter who picked nothing by today's rule — the lowest free stand of
   `ForestTest.standWalk()` — so a drive never waits on a player (D5).
6. Fill the rest with bots **only once no human can still pick** (D6).
7. Be a pure function of the commit with the flag off: today's placement **bit for bit** (D8).

### 1.2 Must not

Each line is a boundary, not a style note.

1. **Must not add a second table of "which stand is whose."** `src/server/Match/StandPick.luau` holds
   the claim. `ForestTest.state.picks` keeps its owner and is **fed** the claim (§6.3), one direction
   only. `Drive.MatchSnapshot.stands` keeps its owner (`Match.standAreaOf`) and stays **derived**
   (§4.3). Three readers, one decision.
2. **Must not move WHERE a stand is, or touch the safety rule** (D7). `ForestTest.standPosition`,
   `Data.PICK.standRadiusStuds`, `ForestTest.boundary`, `src/server/Weapon/SafetyArc.luau` and
   `Match.Penalty` are read-only to this system and no number in them moves.
3. **Must not write a character's CFrame anywhere but inside `Match.Body`.** The move at the window's
   close is `Body.carry` (§5.2), a new function **in `Body`**, composed of `Body.holdCharacter`,
   `Body.onGround`, `PivotTo` and `Body.untieCharacter`'s restore — four pieces that already exist in
   that file.
4. **Must not add a second clock.** `Phase.luau`'s own cardinal rule: *"EVERY TRANSITION IS TIME-DRIVEN
   FROM `phaseEndsAt`, AND `phaseEndsAt` IS THE ONLY CLOCK."* The window **is** a phase (§3), so "how
   long is left" is `Match.secondsLeft()` and there is nothing to keep in step.
5. **Must not add a phase.** Tasks 158 and 159 both recorded *"ADDED NO PHASE"* in `Phase.luau`'s
   header. `"Picking"` would be a fifth `PhaseName` on the wire that every client, every
   `Objective.CONFIG.TEXT` row and `Phase.driveOpen`/`insideDrive`/`lineHeld` would have to learn.
6. **Must not make the pick blocking.** No refusal, no rate limit, no missing world seam and no empty
   map may put the drive in `Waiting`, hold `Assigning` open, or leave a hunter unplaced. Every path
   ends in a stand (`high-seats.md`'s refused-seat discipline, one level out).
7. **Must not free the mouse or hold the trigger outside the window.** `map-ui.md` §8.4 refused both
   for a map opened mid-drive — *"freeing the mouse would … cost the camera its lock while the player
   is standing in a drive"* — and that refusal stands. §7.4 is the amendment, and it is bounded to the
   window.
8. **Must not add an entry to `TWO_PLAYER_PATHS`.** §10.2 proves zero new entries, which is the answer
   to D9's 20-entry ceiling.
9. **No new art, no upload, no asset id** (D10). Every mark is a `Frame`/`TextButton` built in code,
   in `Style` tokens the panel already wears.

---

## 2. The owner, and one writer for each fact (rule 3)

### 2.1 The decision

**A new module under `Match`, because the claim is a fact about the DRIVE'S ROSTER, not about the
wood.** `Match` already owns the roster (`state.assignment`), the phase, the line index
(`indexWithinTeam`), the placement call (`applyPlace`), the line record (`placementLine`) and the
`MatchState` wire. Putting the claim anywhere else would mean a second module reading
`state.assignment` to find out who is a hunter.

| Disk | Studio | Role |
|---|---|---|
| **`src/server/Match/StandPick.luau`** (new) | `ServerScriptService.Match.StandPick` | **the one writer of the claim**, and the pure rule that decides it |
| `src/server/Match/init.luau` | `ServerScriptService.Match` | opens and closes the window, measures the world for `StandPick.judge`, owns the remote, publishes the table, calls `Body.carry` |
| `src/shared/Drive/Remotes.model.json` | `ReplicatedStorage.Drive.Remotes` | gains **one** `RemoteEvent`, `StandRequest` |
| `src/client/Match/init.luau` | `StarterPlayerScripts.Match` | **the one owner of the drive wire on the client**: fires `StandRequest`, reads `snapshot.picks`, answers `Match.standPick…()` |
| `src/client/Hud/MapUi.luau` | `StarterPlayerScripts.Hud.MapUi` | **the one writer of everything inside the map's frames**, unchanged owner. It draws the states it is HANDED and calls one collaborator on a tap |
| `src/client/Hud/init.luau` | `StarterPlayerScripts.Hud` | resolves the pick view **once** and hands it to `MapUi` — the `setPush` / `setTarget` discipline this file already states |

`StandPick.luau` is a sibling of `Phase.luau` and `Roster.luau` and has their shape: **the rule is
pure, the state is one table, and the owner measures the world.** `Weapon.Rules` and `Lobby.Pads`
are the two precedents inside the repo (§9.6).

### 2.2 The table, fact by fact

| Fact | The one writer | Where |
|---|---|---|
| **which hunter holds which stand, this drive** | **`Match.StandPick`** (`claim`, `release`, `reset`) | `src/server/Match/StandPick.luau` |
| whether a request is accepted | `Match.StandPick.judge` — **pure**, no service, no `Player`, no clock | as above |
| whether the window is open, and until when | `Match.Phase` — it **is** `state.phase` + `state.phaseEndsAt` (§3). Nothing else holds a window | `src/server/Match/Phase.luau` |
| the claim on the wire (`snapshot.picks`) | `Match.snapshot` | `src/server/Match/init.luau` |
| the verdict on the wire | `Match`'s `StandRequest` handler | as above |
| **where a character stands** | `Match.Body` — **unchanged owner**, one new composed function (`Body.carry`) | `src/server/Match/Body.luau` |
| which stand the drive PLACES him on | `HighSeats.dealLine` — unchanged owner, one new parameter | `src/shared/HighSeats/init.luau` |
| which stand BINDS him once the drive runs (the ring, the soft wall, `standArea`) | `ForestTest` (`state.picks`) — **unchanged owner**, fed the claim by its own composition root | `src/server/ForestTest/init.luau` |
| the claim as the client knows it | `PlayerScripts.Match` (from the snapshot; it derives nothing) | `src/client/Match/init.luau` |
| every pixel of the markers, the hit pads and the stand list | `Hud.MapUi` | `src/client/Hud/MapUi.luau` |
| which pick view `MapUi` is given | `Hud` (`Hud.renderObjective`'s own evaluation) | `src/client/Hud/init.luau` |
| the mouse (`MouseBehavior`, `Mouse.Icon`…) | `PlayerScripts.Camera.Cursor` — **asked, never written**, tag `"map-pick"` | `src/client/Camera/Cursor.luau` |
| the trigger | `PlayerScripts.Weapon.Input` — **asked, never written**, tag `"map-pick"` | `src/client/Weapon/Input.luau` |

**The one thing that must not be mistaken for a second writer**, so it is written down: `snapshot.picks`
and `snapshot.stands` are two published VIEWS of one claim. `picks` is *who holds which stand*, live
during the window; `stands` is *the circle the fire gate measures*, which `Match.standAreaOf` reads off
`ForestTest.standArea` — which reads `pickOf(userId).lockedAt`, which is the claim after §6.3's lock.
During the window `stands` is absent for everybody, which already means **no rule**
(`Weapon.Rules.outsideStand`'s own nil case). After GO the two agree **by derivation, not by
agreement**.

---

## 3. The timing — the window IS `Assigning`, and that is the whole of the arithmetic

### 3.1 The ruling

**The pick window is the `Assigning` phase, and `Assigning` is lengthened to the window while the flag
is on.** Nothing else.

```lua
-- src/server/Match/Phase.luau  (the EXISTING one question, one new branch)
function Phase.intermissionSeconds(config): number
    if config.QUICK_TEST then
        return config.QUICK_TEST_INTERMISSION_SECONDS      -- unchanged, and it WINS: §3.4
    end
    -- STAND_PICK_SECONDS is 0 with the flag off, so this line is `INTERMISSION_SECONDS` by identity.
    return math.max(config.INTERMISSION_SECONDS, config.STAND_PICK_SECONDS or 0)
end
```

```lua
-- src/server/Match/init.luau, Match.CONFIG -- THE ONE BOUNDARY READ OF THE FLAG (CLAUDE.md,
-- "The owner reads it once, at its boundary, and passes the value inward").
STAND_PICK_SECONDS = if Flags.isOn("STAND_PICK") then 15 else 0,
```

So:

| | window open | window closed |
|---|---|---|
| server | `Phase.pickWindow(state, config)` = `state.phase == "Assigning" and config.STAND_PICK_SECONDS > 0 and standCount > 0` | anything else |
| seconds left | `state.phaseEndsAt - now` | — |
| client | `Match.phase() == "Assigning"` and `snapshot.pickWindow == true` | — |
| seconds left | `Match.secondsLeft()` — **already exists**, already drawn | — |

**Why this and not the alternatives**, each rejected for a named reason:

| Alternative | Rejected because |
|---|---|
| a new `"Picking"` phase | §1.2 boundary 5: a fifth `PhaseName` on the wire, and `Phase`'s header has refused one twice |
| a `task.delay` window inside `Assigning` | a second clock. `Phase.luau`: *"a hitch cannot skip a phase"*; a delay can, and task 168's `goFreeAt` is the pattern that replaced exactly this |
| the window in the previous drive's `Scoring` (9 s) | teams are assigned in `enterAssigning`. A man picking a stand before he knows he is a hunter is picking for a role he may not get |
| move `placePlayers` to the end of `Assigning` | `Phase.enterAssigning`'s hold-before-place ORDER is a measurement, not a preference (`[harness2] FAIL 33/35 @ 7ea945f`). Splitting placement by team doubles the placement moments and re-opens that measurement |

**`INTERMISSION_SECONDS = 5 → 15` is a FEEL change and it is Karen's.** Drive to drive goes 20 s → 30 s
(`Match.CONFIG`: *"9 + 6 + 5 = 20 s"*). It ships **dark** behind `STAND_PICK` (D8), which is exactly what
the flag discipline is for: no playtest in the merge gate, Karen's OK flips the default. §15 open
decision O-1.

### 3.2 Where each thing happens, on one line

```
enterAssigning  ─ assignTeams ─ clearBoars ─ hold(beaters) ─ placePlayers ─ refreshArming ─ broadcast
                  │                                          │
                  │                                          └─ the PROVISIONAL stand: dealLine with
                  │                                             NO picks = today's deal, bit for bit
                  └─ Match: StandPick.reset(driveNumber)  →  window OPEN for STAND_PICK_SECONDS
   …15 s of taps, each one judged, claimed and force-broadcast…
enterRunning    ─ settleStands ─ feed ─ signal("start") ─ broadcast(force)
                  │
                  ├─ Match: StandPick.close(); bots filled (D6, §8)
                  ├─ Match: applyPlace is NOT called. Body.carry moves only the movers (§5.2)
                  └─ ForestTestBoot: openPickFor locks IMMEDIATELY on the claim (§6.3)
```

`settleStands` is a **new effect with no payload**, emitted **first** in `enterRunning`. That is the
same shape `scene` and `clearScene` already have — `Phase.luau`: *"`scene` and `clearScene` carry
nothing: the scene is built from the drive's own kills and the world's own geometry, which are the
owner's to read"* — and first for the reason task 159 paid for twice: it must land before any client
is told the drive is on. **It cannot yield**: `Body.carry` passes `attempts = 1` to `Body.onGround`
(the parameter already exists), so `groundWithRetries` cannot wait. The ground under a stand was
measured 15 seconds earlier by the very placement this is correcting.

### 3.3 The hunter who joins mid-window

`Phase`'s `join` branch can assign a team mid-`Assigning`, and `Match` broadcasts on `PlayerAdded` and
at 4 Hz. So a late joiner's **first snapshot carries the live claim table and the live
`phaseEndsAt`** — there is nothing to catch up and no replay. Two rules, both stated so the behaviour
is a decision:

* **The map auto-opens only if at least `STAND_PICK_MIN_SECONDS` (3) remain.** A map that appears and
  vanishes is worse than no map, and `map-ui.md` §5.4's rule — *"visibly no map, never a blank
  panel"* — is the same sentence in a different costume. He can still open it with **M** and claim
  with 0.2 s left if he is quick; only the AUTO-open is gated.
* **He takes the fallback if he claims nothing**, like anybody else (D5). The window is not extended
  for him: extending it is a second clock.

### 3.4 `QUICK_TEST` wins, and that is deliberate

With both on, `Phase.intermissionSeconds` returns `QUICK_TEST_INTERMISSION_SECONDS` (3) and the window
is three seconds. The quick test exists to get Karen to a crossing fast
(`Match.CONFIG`: *"enough to read 'Drive 1' and turn round"*); a Studio switch that made the
intermission five times longer would be the opposite of the thing. Three seconds is still a usable
window for one player with the map already open, and `STAND_PICK_MIN_SECONDS` keeps the auto-open
honest. Asserted (`match_stand_pick.spec`, case 4).

---

## 4. The wire

### 4.1 One new remote, and why it carries both directions

`src/shared/Drive/Remotes.model.json`:

```json
{ "className": "Folder", "children": [
    { "name": "MatchState",   "className": "RemoteEvent" },
    { "name": "MatchEvent",   "className": "RemoteEvent" },
    { "name": "StandRequest", "className": "RemoteEvent" }
] }
```

**This is a deliberate departure from the repo's `XRequest` + `XState` pair** (`Shop`, `Report`,
`Range`, `Lobby`), and the reason is that the STATE already has a channel:

* **the claim table** is a property of the drive and rides **`MatchState`**, beside `stands`, `tied`,
  `through` and `roleOverruled` — four lists of the same shape, from the same owner, in the same
  snapshot. A second state channel for per-drive hunter state would be a second answer to *what does
  this drive look like*.
* **the verdict** is addressed to exactly one player and is the reply to exactly one ask. It cannot
  ride `MatchEvent`, which is `FireAllClients`. A third `RemoteEvent` would be a channel with one
  message on it — `Phase.luau`'s own words about the horn: *"a second RemoteEvent for one word would
  be a second wire answering a question this one already answers."*

So `StandRequest` is **client → server: one number**, and **server → that client: one verdict**.

### 4.2 The payloads, typed

```lua
-- CLIENT -> SERVER. ONE NUMBER. Anything else is dropped and counted (`stats.malformed`), never
-- coerced: `tonumber("4")` on a client's string is the server believing a client's type.
StandRequest:FireServer(standIndex: number)

-- SERVER -> THAT CLIENT, exactly once per ask it did not drop.
export type StandVerdict = {
    ok: boolean,
    stand: number,     -- the stand he asked for, echoed, so a late reply cannot be read as a reply
                       -- to a later ask
    reason: string?,   -- nil when ok; one of StandPick.REASON below
}
StandRequest:FireClient(player, verdict: StandVerdict)
```

### 4.3 The snapshot delta

```lua
-- src/shared/Drive/init.luau, MatchSnapshot
-- WHO HOLDS WHICH STAND IN THIS DRIVE (task 323), keyed by `tostring(standIndex)` -- the `stands`
-- and `Horn.keyFor` keying, because a table on the wire has string keys. THE WHOLE TABLE, as one
-- snapshot (brief 3.2): a per-stand delta would be a second representation of a fact that fits in
-- nine rows, and a client that missed one delta would draw a stand as free that is not.
--
-- ABSENT means "no pick in this build" -- the flag off, or a world that states no stands -- which is
-- the `stands` / `coinsOn` / `roleOverruled` idiom, and the client then draws exactly what it drew
-- before this task.
picks: { [string]: number }?,
-- IS THE WINDOW OPEN RIGHT NOW. It is NOT derivable from `phase == "Assigning"` alone: the flag may
-- be off and the world may state no stands, and a map that opened itself and refused every tap is
-- the worst of the three states.
pickWindow: boolean?,
```

`phaseEndsAt` already carries the deadline, in server time. **No new timestamp.**

### 4.4 The broadcast rule

An **accepted** claim calls `broadcast(true)` — forced, past `STATE_MIN_INTERVAL` (0.25 s), for the
reason `Phase.enterAssigning` gives about phase changes: a client that learns 1.2 s late that stand 4
went is a client that taps a stand that is gone. A **refused** one broadcasts nothing (the state did
not move) and sends only the verdict.

Cost ceiling: 8 hunters × `STAND_PICK_MAX_REQUESTS` (20) = 160 forced broadcasts worst case in 15 s,
against the rate limiter's floor of one accepted change per 0.25 s per player = **at most 8 × 60 = 480
in the window, and in practice 8 to 24.** The limiter is what makes the ceiling a number rather than a
hope (§12).

---

## 5. The server: the rule, and the one move

### 5.1 `StandPick.judge` — pure, one function, one reason each

The shape is `Weapon.Rules`': the caller measures the world, this decides, and every refusal is a spec
case with no remote, no `Player` and no clock.

```lua
-- src/server/Match/StandPick.luau
export type Ask = {
    userId: number,
    stand: number,
    now: number,
    open: boolean,        -- Phase.pickWindow, measured by the owner
    standCount: number,   -- what the WORLD says (world.standCount), not #markers.posts: see 7.2
    isHunter: boolean,    -- state.assignment[userId] == "Shooters", measured by the owner
    seated: boolean,      -- does THIS stand carry a high seat (ForestTest.seatedStands)
    entitled: boolean?,   -- may he use one. nil is "nobody answered", which is YES --
                          -- `Shop.grantsHighSeat`'s own nil rule, so a build with no economy
                          -- answers exactly what it answers today
    heldBy: number?,      -- who holds that stand now
    mine: number?,        -- which stand HE holds now
    lastAt: number?,      -- when his last ACCEPTED change was
    asks: number,         -- how many asks he has made this drive
    config: any,
}

StandPick.REASON = table.freeze({
    CLOSED = "closed", ROLE = "role",  RANGE = "range", RATE = "rate",
    FLOOD  = "flood",  SAME = "same",  SEAT  = "seat",  TAKEN = "taken",
})

-- THE ORDER IS `Rules.ORDER`'S OWN RULE: the outermost fact about the asker first -- the thing he
-- must fix before any other answer is even useful. "TAKEN" to a beater, or to a man asking after the
-- horn, sends him to fix the wrong thing.
StandPick.ORDER = table.freeze({ CLOSED, ROLE, RANGE, RATE, FLOOD, SAME, SEAT, TAKEN })

function StandPick.judge(ask: Ask): (boolean, string?)
```

| Reason | Refused when | The word his screen shows |
|---|---|---|
| `closed` | `not ask.open` | `too late` |
| `role` | `not ask.isHunter` | `beaters have no stand` |
| `range` | not an integer, or outside `1..standCount` | `no such stand` |
| `rate` | `now - lastAt < STAND_PICK_MIN_INTERVAL` | *(silent)* |
| `flood` | `asks > STAND_PICK_MAX_REQUESTS` | *(silent)* |
| `same` | `ask.stand == ask.mine` | *(silent, and it is not an error)* |
| `seat` | `ask.seated and ask.entitled == false` | `you need tree-stand access` |
| `taken` | `heldBy ~= nil and heldBy ~= userId` | `taken` |

Every word is ≤ 25 ASCII characters, inside `Objective.CONFIG.TEXT`'s measured bound of 33
(`hud_clarity.spec`'s `TextFits` at 400 px). **`rate`, `flood` and `same` draw nothing**: a silent
refusal is right for a thing the player did not do wrong, and drawing "too fast" teaches him the limit.

### 5.2 The claim, and the one move

```lua
StandPick.reset(driveNumber: number)            -- every claim dropped; the drive number remembered
StandPick.claim(userId: number, stand: number, now: number): (boolean, string?)
StandPick.release(userId: number): number?      -- returns the stand it freed, or nil
StandPick.close()
StandPick.standOf(userId: number): number?
StandPick.holderOf(stand: number): number?
StandPick.wireTable(): { [string]: number }     -- frozen; the snapshot field
StandPick.picksFor(ids: { number }): { number? } -- by LINE INDEX, nil where unclaimed. `dealLine`'s
                                                 -- 5th argument and nothing else builds it
StandPick.stats(): { asks, accepted, refused: { [string]: number }, malformed, moved, movedStuds }
```

**`claim` yields nowhere.** No `pcall` into a provider, no `LoadCharacter`, no `task.wait`. That is
what makes "first request wins" a property of the code and not a hope: `OnServerEvent` handlers are
queued and run one at a time, so **two requests in the same frame are resolved by the queue, and the
table is written before anything in the handler can yield** (edge case E1, §7.1).

**The move.** A hunter was placed on his provisional stand at `enterAssigning`; at `settleStands` the
movers are moved. One new function, in the one writer:

```lua
-- src/server/Match/Body.luau
-- MOVE A CHARACTER THE PLAYER IS ALREADY IN, WITH NO RESPAWN (task 323). It is `Body.stand` that
-- hands back what it held: hold (which ANCHORS, which is why the pivot sticks -- this module's
-- header), ground-snap at the target's own x,z (task 192's one placement rule), pivot, restore.
--
-- NOT `Body.place`: that calls `LoadCharacter`, which is a new character, a dropped Tool and a reset
-- camera at the instant the start fanfare sounds. `Body.stand`'s own comment refused it for the
-- results scene for the same reason, and this is that refusal reused.
--
-- `attempts = 1` SO IT CANNOT YIELD (design 3.2): the ground at this stand was measured by the
-- placement 15 seconds ago, and a yield here would hold the drive's forced broadcast open.
--
-- IT REFUSES A CHARACTER SOMEBODY ELSE IS HOLDING. A tie or a hold saved his WalkSpeed first
-- (`held[userId]`), and the restore below would hand it back and free a man who is meant to be
-- frozen. In `Assigning` a hunter is neither (`Phase.heldUserIds` is `START_HOLD_TEAM` = Drivers;
-- ties only exist in `Running`), so this is a belt -- and a counted one.
function Body.carry(player: Player, cframe: CFrame, config): boolean
```

`Match`'s handler for the new effect:

```lua
local function applyStandSettle()
    StandPick.close()
    if markerSet == nil then return end
    local ids = sortedHunterIds()
    local line = placementLine("Shooters")          -- now carries `picks` (section 6.1)
    local place = if world and world.placement then world.placement else Body.placementFor
    for index, userId in ipairs(ids) do
        local claimed = StandPick.standOf(userId)
        if claimed ~= nil then
            local player = playersService():GetPlayerByUserId(userId)
            local cframe = place(markerSet, "Shooters", index, config, line)
            if player and cframe and Body.carry(player, cframe, config) then
                stats.standsSettled += 1
            end
        end
    end
end
```

**Only claimants are moved**, so a drive in which nobody picked makes **zero** `Body` calls and is
today's drive by identity. A claimant whose claim equals his provisional stand still gets one
`PivotTo` to the same CFrame, which `Body.carry` reports as a move of `< SNAP_TOLERANCE_STUDS` and
`Body.snapped()` does not count. Acceptable; `stats.movedStuds` is the number that says so.

---

## 6. The seam into placement — one parameter, no new call site

### 6.1 `HighSeats.dealLine` gains a fifth argument

```lua
-- src/shared/HighSeats/init.luau
-- `picks`  what each hunter TOOK, by line index (task 323). nil anywhere is "he took nothing",
--          which takes the three passes below exactly as they are. nil ENTIRELY -- the DEV place, a
--          spec, any caller written before this argument -- is today's deal, value for value.
function HighSeats.dealLine(
    walk: { number },
    seated: { [number]: boolean },
    entitled: { boolean? }?,
    count: number,
    picks: { number? }?
): { number }
```

**Two sweeps, and the order is the whole of D4 and D5.**

```
SWEEP A -- EVERY VALID PICK, IN LINE-INDEX ORDER, BEFORE ANYBODY TAKES ANYTHING BY FALLBACK.
  for index = 1..count:
      s = picks and picks[index]
      take s when: s is in `walk`, not `taken`, and (allowSeat or not seated[s])
SWEEP B -- TODAY'S THREE PASSES, over the indices sweep A did not fill. Unchanged, line for line.
```

**Why two sweeps and not one pass with a pick check.** With one pass, hunter 1 (no pick) takes
`walk[1]` on his turn and hunter 3's claim of `walk[1]` is then refused by the fallback — the claim
would lose to a man who claimed nothing, which is the inverse of D4. Two sweeps make the pick
**strictly stronger** than the fallback, which is what "first request wins and the rest fill what is
left" means.

**The entitlement is checked twice on purpose**, at the request (`judge`'s `seat`) and here. The
request check is the one the player sees; this one is the one a forged `FireServer` meets. The second
is the belt `high-seats.md` §5.2 already wears for the same reason.

**Pass 3 (every stand taken) is reached unchanged**, so a tenth hunter still wraps onto a shared stand
exactly as `ForestTest.standIndexFor` does today, and the comment that says so stays true.

### 6.2 `Match.placementLine` gains one line

```lua
local function placementLine(team: TeamName): any
    local ids = sortedIdsOnTeam(team)
    …entitled, unchanged…
    -- WHAT EACH OF THEM TOOK (task 323), by the same line index `indexWithinTeam` answers and the
    -- same sorted-userId order `entitled` is built in -- so the two lists cannot be out of step.
    -- Empty with the flag off, which is `dealLine`'s nil case.
    local picks = StandPick.picksFor(ids)
    return { count = #ids, entitled = entitled, picks = picks }
end
```

`ForestTestBoot`'s `placement` closure gains one argument at an existing call:

```lua
local deal = HighSeats.dealLine(
    ForestTest.standWalk(),
    ForestTest.seatedStands(),
    if line then line.entitled else nil,
    math.max(index, if line then line.count else index),
    if line then line.picks else nil                      -- NEW, task 323
)
```

`Match.botSlotsFor`'s `botLine` already copies `hunterLine.entitled`; it copies `hunterLine.picks` the
same way. Bots occupy line indices `n+1 …`, where `picks` is nil, so **a bot can never hold a claim**
— D6 by construction and not by a check.

**`Match.standAreaOf`'s DEV fallback** calls `place(markerSet, "Shooters", index, config, line)` with
`placementLine("Shooters")` — so it picks the new field up with no edit, and the circle it answers is
the circle the placement used. That is the task-221 reason its own comment already gives.

### 6.3 The forest's walk-pick: the claim decides, the walk does not

Two edits at the composition root, both one line, both reading the flag once.

**(a) `ForestTest.lockPick` takes the stand as an optional argument** — the same shape
`ForestTest.openPick(userId, now, standIndex?)` already has (task 175), in the same file, for the same
reason:

```lua
-- `standIndex` IS THE STAND THE DRIVE SAYS IS HIS (task 323), and it is optional so every caller
-- written before it keeps `nearestStand` -- which is the walk pick, and is this function unchanged.
-- WITH IT, WALKING NO LONGER RE-CHOOSES: he chose on the map, and the circle closes round what he
-- chose. Without it, standing on it IS the selection, exactly as before.
function ForestTest.lockPick(userId: number, position: Vector3, now: number, standIndex: number?): number
```

**(b) `ForestTestBoot.openPickFor` locks IMMEDIATELY when the window has already closed:**

```lua
-- ONE TERNARY AT THE COMPOSITION ROOT. With the pick on, the window closed at the end of `Assigning`
-- and the claim is final, so waiting `Data.PICK.seconds` into the drive would leave ten seconds of
-- `Running` with no circle and no rule -- which is the gap task 175 closed from the other end.
local lockIn = if Match.CONFIG.STAND_PICK_SECONDS > 0 then 0 else Data.PICK.seconds
task.delay(lockIn, function() … ForestTest.lockPick(userId, pos, os.clock(), Match.standOf(userId)) … end)
```

`Match.standOf(userId)` is `StandPick.standOf` re-exported on `Match`, because `ForestTestBoot`
already talks to `Match` and must not require `Match.StandPick` (the owner's internals are not a
public surface; `Match.standAreaOf`, `Match.isHeld` and `Match.driveLine` are the precedents).

**What this leaves alone, named rather than assumed:** `ForestTest.pickOf`'s layout guard, `standArea`,
`standIndexOf`, `boundary`, `boundaryPoint`, `hunterStandX`, `Markers.ring`, `showRing` and
`standIsClaimed` are **not touched**. `hunterStandX` gets a locked pick at GO instead of GO + 10 s,
which is strictly better: the waves are aimed at the stand he is really on from the first release.

**One imperfection, stated rather than hidden.** The world RING drawn during `Assigning`
(`ForestTestBoot`'s `PLACEMENT_SETTLE_SECONDS` loop) is round his **provisional** stand for the length
of the window, because `showRing` is edge-triggered on `standIndexOf` and the forest has no listener
for an accepted pick. `showRing` corrects it at the lock, which is GO — *"if he walked to another
stand in the window, `showRing` takes the old circle down"*, its own comment. During the window the
picture is the MAP, which is what Karen asked for. A ring that follows the claim needs a world-side
signal and is **queued as 323d**, not built here.

---

## 7. Edge cases (brief §5)

### 7.1 Two requests in the same frame — E1

Decided by the `OnServerEvent` queue, not by a lock. `RemoteEvent` server handlers are invoked one at
a time and `StandPick.claim` **yields nowhere** (§5.2), so the second handler reads a table the first
has already written. Asserted directly by calling `StandPick.claim` twice with the same `now` and the
same stand (`match_stand_pick.spec`, case 7) — and the property is in the code, so the spec is
checking a guarantee rather than a timing.

### 7.2 A hunter leaves mid-window — E2

`Match.forget(userId)` is already the one door a leaver goes through. It gains
`StandPick.release(userId)` and one forced broadcast, so **the stand is free again at once** (D4) and
every other client's map says so inside 0.25 s. If he was also the `firstUserId` of nothing and held
nothing, `release` returns nil and no broadcast is forced.

### 7.3 A role switch mid-window — E3

The forest's `/beater`, `Match.requestTeam` and `Phase`'s `team` branch all end at **one line**:
`applyAssign`, which is *"the ONE place a team is written"* (`Match`'s own comment). `StandPick.release`
goes there, beside `Body.setTeam`, guarded on `team ~= "Shooters"`. So a hunter who becomes a beater
loses his stand **where the team is decided**, not at remembered moments — which is the shape that
comment says task 214's root cause was missing. The reverse (`/hunter` mid-window) gives him a hunter's
line index and an empty claim, so he may pick what is left.

### 7.4 Fewer stands than hunters — E4

`judge`'s `taken` refuses every held stand; a hunter who can claim nothing claims nothing, and
`dealLine`'s sweep B passes 2 and 3 place him exactly as they do today — including the wrap onto a
shared stand, which is `standIndexFor`'s documented behaviour at ten hunters on nine stands. The map
shows every marker taken, which is the truth. **No refusal and no shortage can hold the drive**
(§1.2 boundary 6).

### 7.5 The drive place rotates, so the stands differ per drive — E5

**Closed by order, and the order already exists.** `ForestTest.layoutForDrive(driveNumber)` is keyed on
the drive number, which `Phase.enterAssigning` increments, and `Match`'s `dispatch` *"measures the
markers on the `Assigning` edge (task 179)"* — in the same effect application, **before** the window
opens. So the stand set for drive N is fixed before any client can ask about it. Three consequences,
each one line:

* `StandPick.reset(driveNumber)` drops every claim at `enterAssigning`, so a claim of stand 7 from a
  nine-stand `road` cannot survive into a five-stand `ride`.
* `standCount` comes from **`world.standCount()`**, not from `#markerSet.posts`. The map draws
  `standPosition(1..standCount)`; a post whose ground was refused is **absent from `markers.posts`**
  (measured: `8/9 stands (1 refused)`), so validating against the post list would refuse a stand the
  player can see. `ForestTest.postIndexFor`'s name lookup and `placementFor`'s modulo then handle the
  refused post exactly as they do today.
* `ForestTest.pickOf`'s existing layout guard (`pick.index > chosen.layout.standCount → nil`) is the
  belt under all of it and is **not** changed.

**Not closed, and logged rather than papered over:** a stand whose post was refused is still
*claimable*, because which post was refused is not published. A hunter who claims it is placed by
`postIndexFor`'s modulo fallback — today's answer for that stand — and the forest prints the refusal
count as it already does. Publishing the refused set is **queued as 323e**.

### 7.6 Two more that the brief did not list

* **A forged `FireServer` with a float, a string, a table or `math.huge`.** `judge`'s `range` is
  `type(stand) == "number" and stand == math.floor(stand) and stand >= 1 and stand <= standCount`.
  Anything that is not a number at all is dropped before `judge` and counted as `stats.malformed`.
* **A drive that is dismissed into `Waiting` mid-window.** `Phase.enterWaiting` is a phase change, so
  `Phase.pickWindow` goes false by itself and every further ask is `closed`. `StandPick.reset` runs at
  the next `enterAssigning`. **Nothing has to remember to clear anything** — the shape
  `Phase.barredFromRejoin`'s own comment prescribes.

---

## 8. Bots (D6)

**Bots never take a stand a human could still pick, and that is arithmetic, not a check.**

`Match.syncBots` is called at the end of every `dispatch` and rebuilds **once per drive**, on the edge
`Match.botsNeedRebuild(phase, drive, lastRebuilt)` = `phase == "Assigning" and lastRebuilt ~= drive`.
Today the rebuild happens on the **first** `Assigning` tick. One change:

```lua
-- WITH THE PICK ON, THE REBUILD WAITS FOR THE WINDOW (task 323, D6). The bots' stands come out of the
-- same `dealLine`, so a line dealt while a human could still claim would hand a rig the stand he was
-- about to take -- and `botsNeedRebuild` is TRUE EXACTLY ONCE PER DRIVE, so moving the edge costs no
-- rebuild and adds no state. `STAND_PICK_SECONDS == 0` is the edge this function has always had.
function Match.botsNeedRebuild(phase: string, driveNumber: number, lastRebuilt: number?, pickOpen: boolean?): boolean
    if pickOpen == true then
        return false
    end
    return (phase == "Assigning" or phase == "Running") and lastRebuilt ~= driveNumber
end
```

`"Running"` joins the edge **only** so the rebuild that the window deferred actually happens; with the
flag off `pickOpen` is false in `Assigning`, the first `Assigning` tick rebuilds, `lastRebuilt` moves,
and the `Running` arm is unreachable — **today's behaviour by identity**, and `bots_live.spec` asserts
the rebuild count is still one per drive.

`Fill.standsFree(postCount, realHunters)` and `Fill.counts` are **unchanged**: the subtraction was
always "posts minus real hunters", and after the window every real hunter holds exactly one stand.

---

## 9. The map (brief §3.4) — the deltas to `map-ui.md`

`docs/design/map-ui.md` is the owner of the map and is **not** re-opened. Three of its boundaries are
amended, each named as an amendment, each bounded to the window.

### 9.1 Amendment A-323-1 — the map may now ask one collaborator

`map-ui.md` §2 boundary 3: *"It writes no other system's state… It fires **no remote** and owns none."*

**Amended:** `MapUi` still fires no remote and still writes no other system's state. On a tap it calls
**one collaborator**, `PickSystem.request(standIndex)`, which is `PlayerScripts.Match` — the one owner
of the drive wire on the client. That is `ReportPanel`'s own shape: its `ask({ page })` goes to
`ReportSystem` and the panel owns no remote. The sentence that changes is *"everything it draws is data
the client already has"*: a tap is not drawing.

### 9.2 Amendment A-323-2 — the mouse and the trigger, inside the window only

`map-ui.md` §8.4 refused both, and wrote down the condition on which it would change its mind: *"If a
later task makes the map clickable, it asks `PlayerScripts.Camera.Cursor` — the one writer of
`MouseBehavior`… with the tag `"map"`, exactly as `ReportPanel` does with `"report"`. It never writes
the mouse."* This is that task.

```lua
-- Tagged NEEDS, never writes -- the `Cursor.requestFree` / `Input.requestHold` pattern, and the tag
-- is `"map-pick"` and not `"map"` so a map opened for any other reason keeps §8.4's refusal.
if pickable then Cursor.requestFree("map-pick"); WeaponInput.requestHold("map-pick")
else            Cursor.release("map-pick");     WeaponInput.releaseHold("map-pick") end
```

`pickable = MapUi.fullMapVisible(open, suppressed, reportOpen) and window and isHunter`. Released on
**every** exit: the window closing, the map closing, the scope coming in, the report opening, the team
changing, `teardown()`. `Cursor` and `Input` are both reference-counted by tag, so a missed release
costs a free mouse in a drive — which is why the release is driven off the same pure predicate as the
grab, and `map_ui.spec` asserts `Cursor.isFree() == false` after each of the six exits.

**And the trigger hold is not optional.** `Weapon.Input` binds `MouseButton1`; without
`requestHold("map-pick")`, tapping a stand fires a shell. `ReportPanel`'s comment names the identical
case: *"clicking a row in the report would also fire the gun"*.

### 9.3 Amendment A-323-3 — the stand nodes become buttons

`drawGeometry`'s `Stand%d` `Frame` gains a child `TextButton` named `Hit`, transparent, `Text = ""`.

**`GuiButton.Activated` is the whole of D3's "mouse and touch".** It fires for a mouse click, a touch
tap and a gamepad A on one handler, which is why `Hud.Rail` and `Hud.Touch` already use it. **No new
input owner, no new key, no `UserInputService` reader, and `docs/design/camera.md` is not touched** —
the same argument `high-seats.md` §2 makes for the `TrussPart` climb.

### 9.4 The five marker states, and what is drawn (brief §3.4)

Colours are the repo's own. **No new colour is introduced** (`map-ui.md` §12's rule).

| State | Mark | Source of the colour |
|---|---|---|
| **free, ground** | 6 px square + index label — **today, unchanged** | `MapUi.COLORS.stand` |
| **free, high seat** | the same square with a 2 px `UIStroke` | `MapUi.CONFIG.RIM_COLOR` (`Style.LOOK.BRASS`), the map's own rim |
| **taken by somebody else** | square in the shooter colour at 0.45 transparency, his **name** under the index | `Drive.CONFIG.SHOOTER_COLOR`, `MapUi.CONFIG.PINNED_TRANSPARENCY` |
| **mine** | the **existing** `Target` mark: a 45° rotated 10 px square | `MapUi.COLORS.arrow` — *"the ONE place on this map that is yours"*, already built, already accepted |
| **not claimable** (a seat he has not bought) | square at 0.7 transparency, no stroke, and the tap is refused with `seat` | `MapUi.COLORS.stand` |

"Mine" reuses the `Target` node rather than adding a sixth mark, so the full map still carries **exactly
one** orange mark and it is still where you are going — `buildDrawer`'s own stated rule. `Hud` stops
calling `MapUi.setTarget` for the hunter's stand while the window is open and calls
`MapUi.setStandStates` instead; one evaluation, one mark, no two writers of that node (it is
`MapUi`'s either way).

### 9.5 The hit area, and the one place the repo's own 44 px minimum does not fit

The full map is drawn into a **fixed 1100 px canvas** with a `UIScale` (`map-ui.md` §7.2). The forest's
nine stands at `standSpacing` 150 over a 1,720-stud span give **96 canvas px** between adjacent stands.

```
STAND_HIT_PX = 72                       -- canvas px, square, centred on the stand. 72 < 96, so two
                                        -- adjacent pads never overlap: the arithmetic, not an eye
desktop 1920x1080:  scale = 1100/1100 = 1.00  ->  72 px on screen   comfortable for a mouse
phone    400x800:   scale =  352/1100 = 0.32  ->  23 px on screen   BELOW the 44 px thumb minimum
```

**23 px fails `mobile-controls.md`'s own minimum, and a bigger pad cannot fix it: at 0.32 scale the
stands themselves are 30.7 px apart.** So the touch answer is not a bigger pad:

**A `StandList` inside the panel on a touch device.** One row per stand, **44 px tall**, 9 rows = 396
px, inside the phone panel's 644 px height (`map-ui.md` §7.4). Each row carries the index, the state
word (`FREE` / a name / `SEAT`) and nothing else, and its `Activated` calls **the same**
`MapUi.tapStand(index)` the markers call — one entry point, so there is one tap rule and not two.
Shown by `Touch.shown(UserInputService.TouchEnabled)` (**read**, never written — `Hud.Touch` is its
owner), and only while `pickable`. On a desktop it is not built.

This is **task 323c** (§14), so 323a and 323b ship without it and the flag stays off until all three
land.

### 9.6 Auto-open, and what hides what

`map-ui.md` §8's table gains one row and contradicts none of it:

| Question | Answer |
|---|---|
| the full map, when the window opens for a hunter | **opened by `MapUi.setOpen(true)`**, once, edge-triggered (D3: *"the map opens by itself"*) |
| …when fewer than `STAND_PICK_MIN_SECONDS` remain | **not opened** (§3.3) |
| the full map, when the window closes | **closed**, unless the player opened it himself with M since (one boolean, `openedByMe`) |
| the window, for a beater | nothing happens at all. No auto-open, no markers, no cursor, no hold |
| the map while the sight picture is in | **hidden**, unchanged (`setSuppressed`), and the cursor is released with it |
| the map while the report is open | **hidden**, unchanged, and the cursor released |

### 9.7 The redraw budget (brief §3.4)

**Zero added per-tick cost.** `MapUi.render`'s 20 Hz tick is untouched: the stand nodes are built once
per world by `drawGeometry` and the states are written **edge-triggered** by
`MapUi.setStandStates(states, version)`, which compares a version integer and returns at once when it
has not moved.

| | per change | worst case in a 15 s window |
|---|---|---|
| property writes | 9 stands × 4 (`BackgroundColor3`, `BackgroundTransparency`, the stroke's `Enabled`, the name label) = **36** | 480 accepted changes × 36 = **17,280**, i.e. **1,150 writes a second**, against `render`'s own ~120 per tick at 20 Hz = 2,400 a second |
| `Instance.new` | **0** — 9 pads and 9 name labels are built in `drawGeometry` with the squares | 0 |
| remotes fired | 1 (by `PlayerScripts.Match`, not by `MapUi`) | 480 |

And the measured bound that matters: in practice a hunter taps **once to three times**, so the real
figure is 8 players × 3 × 36 ≈ **860 writes in fifteen seconds**.

---

## 10. The flag, the rollback, and the gate

### 10.1 The flag row

```lua
-- src/shared/Flags/init.luau
STAND_PICK = {
    default = false,
    owner = "ServerScriptService.Match (and ServerScriptService.Match.StandPick)",
    born = "2026-10-31 task 323",
    expires = "2026-11-21",          -- 21 days, the ceiling in feature-flags.md section 12
    why = "A hunter takes his own stand on the map in the countdown before the drive, instead of "
        .. "being dealt one. OFF deals every stand exactly as before task 323, and the intermission "
        .. "stays 5 s.",
}
```

**Read once, at the boundary, and passed inward as a number**:
`Match.CONFIG.STAND_PICK_SECONDS = if Flags.isOn("STAND_PICK") then 15 else 0`. That is the only
permitted shape (`CLAUDE.md`, *"feature flags"*), and **`0` makes both states reachable by parameter**
from a pure spec while the flag sits at one of them.

**Flag off is today's game, and each claim is provable rather than asserted:**

| Path | Why it is identical |
|---|---|
| `Phase.intermissionSeconds` | `max(5, 0) == 5` |
| `Phase.pickWindow` | false in every phase |
| `HighSeats.dealLine` | `picks` is an empty table; sweep A takes nothing; sweep B is the old loop |
| `enterRunning` | `settleStands` is emitted, and `applyStandSettle` returns on its first line because no claim exists. **Zero** `Body` calls |
| `ForestTestBoot` | `lockIn == Data.PICK.seconds`; `lockPick`'s 4th argument is nil; `nearestStand` decides |
| `Match.botsNeedRebuild` | `pickOpen` false → the first `Assigning` tick rebuilds, as today |
| the snapshot | `picks` and `pickWindow` absent → a client draws what it drew before |
| the map | `pickWindow` false → no auto-open, no buttons live, no cursor, no hold |

### 10.2 Zero new `TWO_PLAYER_PATHS` entries (D9)

| File | Already covered by |
|---|---|
| `src/server/Match/StandPick.luau` | `src/server/Match/` |
| `src/server/Match/init.luau`, `Phase.luau`, `Body.luau` | `src/server/Match/` |
| `src/client/Match/init.luau` | `src/client/Match/` |
| `src/shared/Drive/init.luau`, `Remotes.model.json` | `src/shared/Drive/` |
| **`tests/server/match_stand_pick.spec.luau`** | `tests/server/match_*.spec.luau` — **this is why the spec is named `match_stand_pick` and not `stand_pick`** |
| the client assertions | **`tests/client/match_client.spec.luau`**, already in the list |
| `src/shared/HighSeats/`, `src/server/ForestTest*`, `src/client/Hud/`, `tools/studio_mcp.py` | **not** in the list, and **must not be added**: `map-ui.md` §2 boundary 8 holds, and putting `src/client/Hud/` in would drag every HUD task into a human click |

So `TWO_PLAYER_PATHS` stays at its current length and `tools/agents.py selftest` needs no new row.
**`test2` is in the gate for all three tasks anyway**, because each touches `src/server/Match/`.

`tools/studio_mcp.py` needs two table rows and nothing else: `match_stand_pick.spec.luau` into
`SCOPE_SPECS["match"]`, and no `BLAST_RADIUS` change (`src/server/Match`, `src/client/Match`,
`src/shared/Drive` → `match`; `src/client/Hud` → `hud`; `src/shared/HighSeats` and
`src/server/ForestTest` are unmapped and therefore resolve to `all`, which is correct). Its `selftest`
fails if the spec belongs to no scope, so this is enforced rather than remembered.

---

## 11. External sources (rule 1)

### A. Colyseus — authoritative room state, sequential messages, patched broadcast

<https://github.com/colyseus/colyseus> · <https://docs.colyseus.io/server/room/>
**Licence: MIT.** **Maintenance: actively maintained** (0.16 line, regular releases).
**Does well:** it is the clearest published statement of the shape this design needs.
`Room.onMessage(type, handler)` handlers run **sequentially against one authoritative state**, and the
state is broadcast as a patch on the room's own tick — so *"two clients claimed the same seat in the
same frame"* is resolved by the order the messages arrived and nothing else. Its `ClientState` /
`reserveSeat` flow is literally seat reservation with the server as the arbiter.
**Does badly:** its patch protocol (`@colyseus/schema` binary deltas) is the part we deliberately do
**not** take — nine rows fit in one snapshot and a delta stream would be a second representation of
the claim that a dropped patch could desynchronise (§4.3). And its rooms are Node processes with their
own loop; Roblox hands us the loop.
**Adopted:** *one authoritative table, handlers that do not yield, whole-state broadcast.*
`StandPick.claim` yielding nowhere (§5.2) is this source's guarantee written as a property of our code.

### B. Nakama (Heroic Labs) — the authoritative match handler

<https://github.com/heroiclabs/nakama> ·
<https://heroiclabs.com/docs/nakama/concepts/multiplayer/authoritative/>
**Licence: Apache-2.0.** **Maintenance: actively maintained.**
**Does well:** `match_loop(ctx, dispatcher, tick, state, messages)` is handed **the tick's inbound
messages as an ordered list** and returns the new state — a reducer over a batch, which is exactly
`Match.Phase`'s own shape (*"a reducer returning a new frozen state plus an explicit list of
effects"*). It makes "the server decides, in order" an interface rather than a convention, and its
docs are explicit that a client message is a **request** and the state is the server's.
**Does badly:** the loop is fixed-rate and owns its own tick, and the SDK's language (Go/Lua/TS
runtimes) brings nothing we can reuse. It also has no notion of a privileged slot, which is the half
`high-seats.md` already borrowed source F for.
**Adopted:** the **request/state split and the ordered batch**, as the justification for `StandRequest`
carrying an ask and `MatchState` carrying the truth (§4.1).

### C. Valve Source SDK 2013 — `HandleCommand_JoinTeam` / `HandleCommand_JoinClass`

<https://github.com/ValveSoftware/source-sdk-2013> (`game/server/hl2mp/hl2mp_player.cpp`)
**Licence: Source SDK 2013 licence — source-available, non-commercial, not open source.**
**Maintenance: effectively dormant** (a multiplayer-branch refresh in 2024 and little since).
`high-seats.md` §8 source C records it as *"archived, no meaningful commits in years"*; this design
does not re-litigate that.
**Does well:** the canonical server-side validator for *a client asking to occupy a constrained slot
during a round's setup window*. The engine checks the window, the team, the limit and the "you are
already that" case **in that order**, refuses with a reason, and never trusts the client's own idea of
what is free. That ordering is `StandPick.ORDER` (§5.1).
**Does badly:** `func_ladder`-style cooperation with the mover's own movement code is not available to
us, and the licence permits the idea and nothing else. Its class limits are global, not per-slot, so
it has no answer to *"stand 4 specifically"*.
**Adopted:** the refusal ORDER and the reason-per-rule discipline. Nothing is copied.

### D. Roblox Creator Docs — `RemoteEvent` security, and `GuiButton.Activated`

<https://create.roblox.com/docs/scripting/events/remote> ·
<https://create.roblox.com/docs/reference/engine/classes/RemoteEvent> ·
<https://create.roblox.com/docs/reference/engine/classes/GuiButton#Activated>
**Licence: the Creator Docs content repo is CC BY 4.0.** **Maintenance: continuously maintained**
(first-party).
**Does well:** two first-party facts this design rests on. (1) *"Never trust the client"* — every
argument must be validated server-side, which is §5.1's whole existence. (2) `Activated` fires for a
mouse click, a touch tap **and** a gamepad button on one handler, which is the whole of D3's "mouse and
touch" and the reason this task adds no input owner (§9.3).
**Does badly:** the pages are reference indexes with no prose on contention, ordering or rate
limiting — they do not say that `OnServerEvent` handlers are serialised, which §5.2 therefore makes a
property of our code rather than a dependency on an undocumented one. Nor do they give a thumb-target
minimum, which §9.5 had to take from `mobile-controls.md`.
**Adopted:** the validate-everything rule, and `Activated` as the one tap entry point.

### E. Abdulkadiroğlu & Sönmez — serial dictatorship (the fallback, borrowed twice)

*"Random Serial Dictatorship and the Core from Random Endowments in House Allocation Problems"*,
Econometrica 66(3), 1998. <https://doi.org/10.2307/2998585>
**Licence: journal article, all rights reserved** (idea only). **Maintenance: n/a** — a 1998 paper,
and the canonical statement of the mechanism.
**Does well:** agents in a fixed order each take their most preferred item among those still unclaimed
and acceptable to them — **collision-free by construction**, which is the property D5's fallback must
have. It is already the cited pattern of `HighSeats.dealLine`, so **this is a borrowing declared twice**
(rule 2).
**Does badly:** the literature RANDOMISES the order for fairness across draws, and we deliberately do
not (`dealLine`'s own comment: *"ours is `indexWithinTeam`'s sorted userIds, so the same roster gets
the same stands every drive"*). It also has no notion of a prior claim, which is precisely what
sweep A adds.
**Adopted:** the mechanism, unchanged, as sweep B — with **sweep A making a claim strictly stronger
than a preference** (§6.1), which is this design's one addition to it.

### F. Deutscher Jagdverband / WILD UND HUND — `Standvergabe` at a Drückjagd

<https://www.jagdverband.de/> · <https://wildundhund.de/drueckjagdstaende-sicher-ist-sicher/>
**Licence: editorial, all rights reserved** — read-only reference. **Maintenance: live sites.**
**Does well:** the real-world source for *what the system must do*. At a German driven hunt the
*Jagdleiter* allots the stands at the *Ansprache* — commonly by drawing numbered lots — **before**
anybody walks out, precisely so that two hunters never share a stand and every neighbour's position is
known before a shot is possible. That is D4 and D7 in one practice: the allotment is made by one
authority, in advance, and it changes **who** stands where and never **where** the stands are. Already
cited in this repo (`high-seats.md` §8 source F, `src/shared/ForestTest`'s `edge` layout), so this is a
second declared borrowing.
**Does badly:** prose with no mechanism — no dimensions, no timings, and a real `Standvergabe` is a man
with a hat full of tickets, which says nothing about contention in a frame.
**Adopted:** *the allotment happens before the hunt, and one authority makes it.* It is the sentence
that justifies the window being **before** the drive rather than Karen's existing walk during it.

### G. Borrowed from inside this repo (rule 2)

| Taken | From |
|---|---|
| the whole-line deal and its three passes | `HighSeats.dealLine` |
| a pure rule per question over an injected measurement | `Weapon.Rules`, `Lobby.Pads.withSize` |
| a reducer with effects as values, and `phaseEndsAt` as the only clock | `Match.Phase` |
| `TAG`ged needs instead of a second writer (`requestFree` / `requestHold`) | `Camera.Cursor`, `Weapon.Input`, `MapUi.setSuppressed` |
| "the Hud tells, this module writes" | `MapUi.setPush`, `MapUi.setTarget` |
| the optional-last-argument seam that keeps every older caller identical | `ForestTest.openPick(…, standIndex?)`, `Body.placementFor(…, _line?)` |
| hold → pivot → restore, with no respawn | `Body.standCharacter` + `Body.untieCharacter` |
| the one placement rule (ground measured at the target's own x, z) | `Body.onGround` |
| a flag read once at the owner's boundary, passed inward as a number | `Match.CONFIG.TIE_UNTIL_DRIVE_END`, `QUICK_TEST` |
| refuse-count-and-print rather than a silent guess | `Markers.build`'s refused stand, `Seats.stats().refused` |
| `tostring(userId)` keys on the wire | `MatchSnapshot.stands`, `Horn.keyFor` |

---

## 12. Numeric targets

`Match.CONFIG`, one block, so a retune is one diff.

| Name | Value | Why |
|---|---|---|
| `STAND_PICK_SECONDS` | **15** (flag on) / **0** (off) | brief D2's first value. **It IS the `Assigning` phase** (§3.1), so there is no second number and nothing to keep in step. 15 s is two stand-to-stand reads of a nine-marker line plus a tap |
| `STAND_PICK_MIN_SECONDS` | **3** | below this the map does not auto-open for a late joiner (§3.3). Three seconds is about one read and one tap |
| `STAND_PICK_MIN_INTERVAL` | **0.25** | the floor between one player's **accepted** changes. It is `STATE_MIN_INTERVAL` exactly, so an accepted change can force at most one broadcast per throttle slot and the forced push can never outrun the throttle it is bypassing |
| `STAND_PICK_MAX_REQUESTS` | **20** | per player per drive. A human changes his mind two or three times in 15 s; 20 is seven times that and a hard ceiling on a forged client's cost |
| `MapUi.CONFIG.STAND_HIT_PX` | **72** | canvas px, square. `72 < 96` = the forest's own stand spacing in canvas px, so **two pads never overlap** (§9.5) |
| `MapUi.CONFIG.STAND_LIST_ROW_PX` | **44** | `mobile-controls.md`'s thumb minimum. 9 rows = 396 px inside the phone panel's 644 (§9.5) |
| `MapUi.CONFIG.STAND_SEAT_STROKE_PX` | **2** | `CONFIG.RIM_THICKNESS`'s own number, so the seat ring looks like the map's own rim |
| `MapUi.CONFIG.STAND_TAKEN_TRANSPARENCY` | **0.45** | `CONFIG.PINNED_TRANSPARENCY`, so "not available to you" reads the same everywhere on this map |
| `MapUi.CONFIG.STAND_BARRED_TRANSPARENCY` | **0.7** | dimmer than taken, because an unpaid seat is not somebody else's — it is nobody's |

**Three claims that are measurements, not targets, and each is a spec case:**

* **Flag off is bit-for-bit.** `dealLine(walk, seated, entitled, count, nil)` and
  `dealLine(walk, seated, entitled, count, {})` return a table **equal element by element** to
  `dealLine(walk, seated, entitled, count)` for every layout in `ForestTest.LAYOUT_ORDER` at every
  count 1..16. 4 × 16 × 2 = **128 assertions**, by value.
* **The move count.** `stats.standsSettled == <how many hunters claimed>`, and **0** with the flag off.
* **The move distance.** `stats.movedStuds` ≤ `standSpacing × (standCount − 1)` = 1,200 studs on the
  `road`; the worst real case is a solo hunter dealt stand 5 taking stand 1, which is 600.

---

## 13. How it is tested

Each case names what it proves. Harness limits: no Studio in an Architect run, and
`TASKS.md` tasks 6–7 are the standing statement of what the input harness cannot express — it replays
keys, mouse buttons, mouse moves and gaps (`tests/client/input_scenarios.txt`), so **it cannot click a
`GuiButton` at a computed screen position and it cannot produce a touch tap at all.** §13.3 says what
is done instead.

### 13.1 `tests/server/match_stand_pick.spec.luau` (new; the `match_*` glob covers it)

| # | Case | Proves |
|---|---|---|
| 1 | `judge` refuses each of the eight reasons, one case each, and in `ORDER` when two apply | §5.1; a beater asking after the horn is told `closed`, not `taken` |
| 2 | `judge` accepts a free in-range stand for a hunter in an open window | the happy path, with no remote and no player |
| 3 | `Phase.pickWindow` is true only in `Assigning`, only with `STAND_PICK_SECONDS > 0`, only with `standCount > 0` | §3.1, eight combinations |
| 4 | `Phase.intermissionSeconds`: (5, 0)→5 · (5, 15)→15 · QUICK_TEST+15→3 | §3.1 and §3.4 by value |
| 5 | `dealLine` with `nil`, `{}` and a full `picks` — the 128 equal-by-value assertions of §12 | **flag off is identical** |
| 6 | `dealLine`: hunter 3 claims `walk[1]`, hunter 1 claims nothing → 3 gets it, 1 gets the next free | sweep A beats sweep B (§6.1) — the case one pass gets wrong |
| 7 | two `claim` calls, same stand, same `now` → first true, second `(false, "taken")` | E1 (§7.1) |
| 8 | `release` frees it; the next `claim` of that stand succeeds | D4, E2 |
| 9 | `reset(n)` drops every claim; `standOf` nil for all | E5 |
| 10 | `picksFor(ids)` is indexed by line index, nil where unclaimed, and the same order `entitled` is | §6.2 — the two lists cannot drift |
| 11 | an unentitled hunter's claim of a seated stand → `(false, "seat")`, **and** `dealLine` refuses it in sweep A if it got there anyway | §6.1's double check |
| 12 | `claim` with `2.5`, `"4"`, `0`, `standCount+1`, `math.huge`, `0/0` → `range` for every one | §7.6 |
| 13 | the rate limiter: 2 accepted changes inside `MIN_INTERVAL` → the second is `rate`; ask 21 → `flood` | §12 |
| 14 | `Match.botsNeedRebuild(phase, drive, last, pickOpen)` — the four combinations, and the flag-off identity | §8 |
| 15 | `wireTable()` is frozen, string-keyed, and holds exactly the live claims | §4.3 |

### 13.2 `tests/server/match_place.spec.luau` and `match_live.spec.luau` (existing, extended)

| # | Case | Proves |
|---|---|---|
| 16 | a staged drive: 3 hunters, hunter 2 claims stand 1 → `placementLine("Shooters").picks == {nil, 1, nil}` and the deal puts hunter 2 on stand 1 | the seam end to end, server-side |
| 17 | `applyStandSettle` with no claims makes **zero** `Body` calls (`Body.stood()`, `Body.snapped()` and `stats.standsSettled` all unmoved) | flag off costs nothing |
| 18 | `Body.carry` on a held character returns false and leaves `Body.isHolding` true | §5.2's belt |
| 19 | `Body.carry` does not call `LoadCharacter` (the character instance is the same object afterwards) | §5.2 — his gun survives |
| 20 | `Match.standAreaOf` after the settle answers the claimed stand's circle | the two views agree **by derivation** (§2.2) |

### 13.3 Client — `tests/client/match_client.spec.luau` and `map_ui.spec.luau` (existing)

| # | Case | Proves |
|---|---|---|
| 21 | a hand-built snapshot with `picks`/`pickWindow` → `Match.standPickTable()`, `.standPickOpen()`, `.myStand()` answer it; absent fields → nil/false | §4.3, and the client derives nothing |
| 22 | `Match.requestStand(4)` fires `StandRequest` once with the number 4 and nothing else | the one outbound door |
| 23 | `MapUi.standStateFor(index, view)` — **pure** — returns each of the five states for a hand-written view | §9.4 with no world, no server and no drive |
| 24 | `MapUi.setStandStates` writes the colour, transparency, stroke and name of all nine and **nothing else**, and a second call with the same version writes **nothing** | §9.7's edge-trigger |
| 25 | `MapUi.pickable(open, suppressed, reportOpen, window, isHunter)` — **pure**, 32 combinations | §9.2's one predicate for the grab and the release |
| 26 | after each of the six exits, `Cursor.isFree() == false` and `Input.isHeld() == false` | §9.2 — a free mouse in a drive is the failure |
| 27 | `MapUi.tapStand(4)` with a stub `PickSystem` calls `request(4)` once; with `pickable` false it calls **nothing** | §9.1 — and a tap on a dead map is dead |
| 28 | every `Stand%d` node has exactly one `Hit` `TextButton` whose size is `STAND_HIT_PX`, and no two pads' rects overlap at `fullView` for all four layouts | §9.5's arithmetic, by the engine's own numbers |
| 29 | `MapUi.standListRect(viewport)` at 400×800: 9 rows of 44 inside the panel; at 1920×1080 the list is not built | §9.5 (task 323c) |
| 30 | the window opens → `MapUi.isOpen()` true; with 2 s left it does **not** | §3.3 and §9.6 |
| 31 | `Objective.text` for a hunter in an open window is the pick line and ≤ 33 chars by `TextFits` at 400 px | `hud_clarity.spec`'s own bound |

**What no spec can prove, and what is done instead (rule 6, rule 8):**

* **A real tap.** The harness cannot click a `GuiButton` at a position or produce a touch event. Case
  27 drives `MapUi.tapStand` directly and case 28 proves the pads are where and how big the design
  says — so the **wiring** and the **geometry** are tested and the **gesture** is not. The gesture is
  `GuiButton.Activated`, which is the engine's (§9.3, source D). A **harness fault is a bug**: if a
  later harness can synthesise a tap, case 27 is the one to replace.
* **Two hunters racing for one stand (D9).** `test2`. Scripted in the two-player run: both clients
  `Match.requestStand(5)` in the same frame; assert one `ok = true` and one
  `ok = false, reason = "taken"`, that `snapshot.picks["5"]` names exactly one of them, and that both
  are placed on different stands. This is the case the brief says matters and it is the reason `test2`
  is in the gate.
* **How it LOOKS (rule 5).** A **screenshot, inspected**, is required for task 323b:
  `python tools/studio_mcp.py capture t323-pick` with the window open — and the Builder must say in
  words what the image shows: nine numbered squares on the road line, one of them a rotated orange
  diamond (his), at least one dimmed with a name under it, the seated ones ringed in brass, and the
  countdown on the drive bar. `PROJECT_CONTEXT.md`'s *"a number is not a verification"* is the whole
  reason this line is here: every arithmetic claim above can be true of a blank panel.

---

## 14. Deltas to other designs

| Design | Delta |
|---|---|
| **`map-ui.md`** | Amendments **A-323-1** (§9.1: one collaborator on a tap), **A-323-2** (§9.2: `Cursor`/`Input` tagged `"map-pick"`, bounded to the window — this is §8.4's own stated condition, now met), **A-323-3** (§9.3: the stand nodes gain a `Hit` button). Plus §9.4's five states and §9.6's row in the *what hides what* table, §12's three `CONFIG` numbers, §9.7's budget. **§2's boundaries 1, 2, 4, 5, 6, 7 and 8 are untouched** — in particular it still renders no world, re-derives nothing, does not rotate, and touches no `TWO_PLAYER_PATHS` file. |
| **`drive.md` §4** | `Assigning` is `max(INTERMISSION_SECONDS, STAND_PICK_SECONDS)`; one new effect, `settleStands`, emitted first in `enterRunning`; `Phase.pickWindow` as a new pure predicate beside `driveOpen`, `lineHeld` and `insideDrive`. **No new phase, no new clock.** |
| **`high-seats.md`** | `HighSeats.dealLine` gains a fifth parameter and sweep A (§6.1). Nothing about a seat's geometry, `minY`, the rail, the ladder or `Rules.belowPlatform` moves. §5.2's `seatPaid` rule is **re-used** as `judge`'s `seat` reason, so "may he use that platform" has one answer with two readers. |
| **`bots.md` §§7, 13, 14** | `Match.botsNeedRebuild` gains a `pickOpen` argument and the `Running` arm (§8). `Fill.counts` and `Fill.standsFree` are **unchanged**. |
| **`drive-places.md`** | **No delta, and that is the finding.** The layout is dealt on the `Assigning` edge, before the window opens (§7.5), so rotation and the pick never race. Stated so a reader does not look for a gap. |
| **`forest-drive.md` §4.3** | `ForestTest.lockPick` gains an optional 4th argument; `ForestTestBoot` locks immediately when the window has already closed (§6.3). The walk pick is this design's flag-off behaviour and stays documented as such. |
| **`mobile-controls.md`** | One new surface, `MapUi`'s `StandList`, inside the map panel. `Touch.shown` is **read, never written**; `Hud.Touch` and `Hud.Rail` are not touched. |
| **`hud-clarity.md` §3** | One new `Objective.CONFIG.TEXT` row for the hunter's pick line, ≤ 33 chars, measured by `TextFits`. |
| **`GAME_DESIGN.md`** | One row in *System owners*: **stand pick → `ServerScriptService.Match.StandPick`**. |
| **`feature-flags.md`** | One row, `STAND_PICK` (§10.1). |

---

## 15. The task split (brief §7) — three tasks, in order

**323a — the owner and the wire. No pixel changes.**
`src/server/Match/StandPick.luau` (`judge`, `claim`, `release`, `reset`, `close`, `standOf`,
`holderOf`, `wireTable`, `picksFor`, `stats`) · `Phase.pickWindow`, `Phase.intermissionSeconds`'s
branch, `settleStands` · `Match`: the `StandRequest` handler, `applyStandSettle`, `placementLine.picks`,
`StandPick.release` in `applyAssign` and `Match.forget`, `Match.standOf`, the snapshot fields,
`botsNeedRebuild` · `Body.carry` · `HighSeats.dealLine`'s 5th parameter and sweep A ·
`ForestTest.lockPick`'s 4th argument and `ForestTestBoot`'s `lockIn` · the `STAND_PICK` flag row ·
`src/shared/Drive/` (the type and the remote) · `src/client/Match`: `requestStand`,
`standPickTable`, `standPickOpen`, `myStand` · cases 1–22. **Gate: `test` + `test2`.**
Screenshot **N/A** — nothing is drawn.
*It is testable alone:* every verdict, every fallback, the flag-off identity and the two-player race
are provable with no map at all.

**323b — the map, with a mouse.**
`MapUi`: `standStateFor` (pure), `setStandStates`, `pickable` (pure), `tapStand`, the `Hit` buttons,
the five states, the auto-open, `Cursor`/`Input` tagged `"map-pick"`, the footer reason line ·
`Hud`: the one evaluation handed to `MapUi`, and the `Objective` pick row · cases 23–28, 30, 31.
**Gate: `test` + `test2`** (it depends on 323a's branch) **and a screenshot, inspected** (§13.3).

**323c — touch.**
The `StandList`, `Touch.shown` read, the 44 px rows, the phone-width arithmetic · case 29.
**Gate: `test` + `test2`, and a screenshot at a pinned 400×800 viewport.**

The flag stays **OFF** through all three. Karen plays it with
`python tools/flags.py set STAND_PICK on`, and **her OK flips the default** in a later three-line
commit (`CLAUDE.md`, feature flags).

---

## 16. Open decisions

**Nothing here blocks building.** Every item ships dark behind `STAND_PICK` and is answered by a
playtest, which is what the flag discipline exists for. They are listed so nobody has to rediscover
that they were decided by default.

### Karen (feel)

* **O-1. The intermission grows 5 s → 15 s with the pick on**, so drive to drive goes 20 s → 30 s
  (§3.1). She cut that gap herself (`Match.CONFIG`: *"9 + 6 + 5 = 20 s"*). The lever is one number,
  `STAND_PICK_SECONDS`. If 15 s feels long, 10 s is the obvious next value and nothing else moves.
* **O-2. Walking no longer re-picks** (§6.3). Her 2026-10-12 words — *"we need boundries but not put
  back where it started"* — are satisfied either way (the soft wall and its 12-stud circle are
  untouched), but *"hunter has square where can select stand within 10s and save"* becomes a tap
  rather than a walk. If she wants both, the rule is "the map claims it, walking to a **free** stand
  re-claims it", which is one more `claim` call from the forest's Heartbeat sweep and a 323d task.
* **O-3. The teleport at GO.** A hunter who picked a distant stand is moved there at the instant the
  start fanfare sounds (§5.2) — no respawn, he keeps his gun, and it is the least visible moment in
  the drive. If it reads badly, the alternative is to place hunters at the **end** of `Assigning`
  instead of the start, which re-opens task 159's measured hold-before-place ordering and is a
  design round of its own.

### The Director (scope)

* **O-4. 323c (touch) is the third task and the flag waits for it.** If a phone playtest is not near,
  the flag could be flipped after 323b for desktop only — but then `mobile-controls.md`'s 44 px
  minimum is published and unmet, which this design will not do silently.
* **O-5. Two things are queued, not built, and both are named above:** **323d**, the world ring
  following the claim during the window (§6.3); **323e**, publishing which stands had their post
  refused, so the map can grey them (§7.5). Neither blocks a drive and both are one-line behaviours
  today.

### Not verified

* No Studio in an Architect run: every arithmetic figure above is computed from the numbers in
  `src/` (`INTERMISSION_SECONDS` 5, `standSpacing` 150, `standCount` 9, the 1100 px canvas,
  `STATE_MIN_INTERVAL` 0.25) and **none is measured in a running place**. The ones that must be
  measured by the Builder are: the on-screen hit-pad size at 400×800, `stats.movedStuds` in a real
  drive, and whether `Body.carry` with `attempts = 1` ever misses the ground at a stand
  (`Body.snapMisses()` must stay 0).
* That `OnServerEvent` handlers are serialised is **relied on only as a consequence of `claim` not
  yielding**, not as a documented engine guarantee (§5.2, source D "does badly"). If it ever were not
  true, case 7 is the spec that would still hold and case 16 is the one that would fail.
