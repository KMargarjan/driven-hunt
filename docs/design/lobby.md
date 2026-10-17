# The lobby: a hunting lodge in the fields, and a truck that takes you to the hunt

Task 177. Design for `reviews/task-177/BRIEF.md`, which is this document's input and overrides
anything older. Research note: `docs/research/2026-10-13-lobby-and-the-truck.md`.

**Scope.** The lobby WORLD and the FLOW. The shop is task 178: the interior gets an empty counter
and a placeholder sign and nothing else.

---

## 1. What the system must do

1. **A player who joins the server stands at the lodge**, in open fields with the forest filling the
   northern view. He has no team, no gun, no horn and no outfit, and the drive does not know about
   him.
2. **Standing in the marked circle beside the truck for `COUNTDOWN_SECONDS` enrols him in the next
   hunt.** Stepping out cancels it.
3. **The drive fills to 4 + 4** through the existing `DRIVE_BOTS` path, unchanged and unaware of the
   lobby.
4. **At the end of a drive he is back at the lodge**, free to walk to the truck again.
5. **The screen tells him what to do**: one more row in task 165's `Hud.Objective` table, with the
   chevron on the truck spot.
6. **It works in the Forest Test place (`130094961655666`)** and changes nothing the harness sees in
   the DEV place.

### What it must not do

* It must not become a second writer of a character's **position**, its **team**, its **clothes** or
  its **gun**. Those have owners (`Match.Body`, `Match`, `Weapon`, `Weapon.Horn`) and two correct
  pieces of code disagreeing is this project's named failure mode (`docs/PROJECT_CONTEXT.md`).
* It must not be reachable only through a flag at one of its two states (CLAUDE.md, feature flags).
* It must not write a `Script`/`LocalScript`/`ModuleScript` anywhere, and it must not leave anything
  in the **Edit-mode** DataModel the harness compares.
* It must not write Terrain outside its own rectangle, in any mode but a running session, or in any
  world but the one that asked for it.
* **It must not be able to lock the game out.** A lobby that fails to build must not leave a server
  in which nobody can ever start a drive (§7.4).

---

## 2. Where the lobby lives

**ONE PLACE** (BRIEF 1a). No `TeleportService`, no `ReserveServer`. The lobby is an AREA of the
world the drive already runs in.

**The area, per world.** A world has a lobby when, and only when, the anchor table has a row for it:

| World | Anchor (x, z) | Why |
|---|---|---|
| `forest-test` | **(2850, -2950)** | measured flattest open ground, spread 16 studs over the 160-stud footprint, ~54 studs south of `OurForest`'s southern edge (z = -2896), ~570 studs south of the road and of `ForestTest.EXIT_Z` — it cannot interact with the drive (BRIEF §2) |
| `map:v1` (DEV) | **no row** | the harness's world has no lobby in this task (BRIEF 1l) |

**The Y IS MEASURED, NEVER TYPED.** Nobody has measured the absolute ground height at
(2850, -2950) — the measurements in BRIEF §2 are *spreads*, not altitudes — so the anchor table
carries `x` and `z` only and the shelf's top comes from the world's own single ground reader
(`ForestTest.groundAt`, injected: §12.2). A typed Y would be a guess that puts the lodge in the air
or inside the hill, which is this project's named failure mode with a number attached.

`Lobby.anchorFor(world: string)` takes the world as a **string argument** and requires nothing, so
`ReplicatedStorage.Lobby` depends on no other module. The boot passes `Map.EXPECTED_WORLD`.

---

## 3. The owner, and its location on disk

| Disk | Studio | Role |
|---|---|---|
| `src/shared/Lobby/init.luau` | `ReplicatedStorage.Lobby` | **frozen DATA with no run-time writer**: the anchor table, `CONFIG` (every number and name), the pure readers (`spotPosition`, `secondsLeft`). Shared because the client must read the truck spot for the chevron. The `ReplicatedStorage.ForestTest` shape exactly |
| `src/server/Lobby/init.luau` | `ServerScriptService.Lobby` | **the owner**: the one writer of `Workspace.Lobby`, of the lobby's terrain rectangle, of `Player.RespawnLocation` for a player who is not in the drive, of the `DHLobbyLeaveAt` attribute, and of who has asked to hunt |
| `src/server/Lobby/Build.luau` | `…Lobby.Build` | the one **builder** of the parts: every part in `Workspace.Lobby`, its `SpawnLocation`, the ring and the sign. Takes its container as an argument, so a spec builds into its own folder |
| `src/server/Lobby/Field.luau` | `…Lobby.Field` | the one **writer of the lobby's terrain**: two `FillBlock` calls inside one rectangle. `Terrain` is an **argument**, so a spec drives the arithmetic against a fake and the harness never writes DEV's terrain (§16.1) |
| `src/server/Lobby/Join.luau` | `…Lobby.Join` | **pure**: inside/outside the circle, the countdown decision, and whether a player needs returning. No Instance, no clock, no service |

No new boot script. The lobby is wired at the world's existing composition root,
`src/server/ForestTestBoot.server.luau`, beside `Boar`, `Bots`, `Weapon`, `HitLog`, `Economy` and
`Match` — so no owner requires another owner.

### 3.1 Rows for `GAME_DESIGN.md`'s *System owners* table

**New row:**

> | **The lobby** (the field and its terrain shelf, the log lodge, the truck, the marked circle, the lodge spawn — `Workspace.Lobby` — and WHO HAS ASKED TO HUNT) | `ServerScriptService.Lobby`, wired once by `ServerScriptService.ForestTestBoot`, which returns immediately in every other place. A world has a lobby only when `Lobby.anchorFor(world)` has a row for it, so the DEV place has none. Inside it the ownership splits again, one writer each: `Build` of every part in `Workspace.Lobby`, `Field` of the terrain inside `Lobby.CONFIG.FIELD` **at run time only**, `Join` of nothing (pure). It is also the one writer of `Player.RespawnLocation` (only for a player who is NOT in the drive) and of the `Player` attribute `DHLobbyLeaveAt` (the leave deadline the screen counts down). **It writes no team, no character position, no clothes and no tool**: the one character move it asks for goes out through the injected `place` seam, which the boot binds to `Match.Body.place` — the one writer of where a character stands. `ReplicatedStorage.Lobby` is the frozen DATA with no run-time writer; the client reads the truck spot off the named part the server built, so there is one definition of where the truck is | `src/server/Lobby/`, `src/shared/Lobby/`, `src/server/ForestTestBoot.server.luau` | [lobby](docs/research/2026-10-13-lobby-and-the-truck.md), [design](docs/design/lobby.md) |

**Amendment to the generated-map row** (`GAME_DESIGN.md`, "World geometry: the generated map … and
`Workspace.Terrain`"), because it currently reads *"`Ground` is the only writer of `Terrain` in the
repo"* and that sentence stops being true:

> `Ground` is the only writer of **the DEV place's** `Terrain`, at **EDIT time**, driven by
> `tools/mapgen.py`. Since task 177 `ServerScriptService.Lobby.Field` writes terrain too, and the
> two cannot meet: a different world (`forest-test`, never `map:v1`), a different mode (a running
> session, never Edit), and a bounded rectangle it may not write outside of
> (`Lobby.CONFIG.FIELD`). `tools/mapgen.py` stays the only thing that writes DEV's terrain.

The same amendment is needed in `src/serverstorage/MapGen/Ground.luau`'s header and in
`docs/design/map-generator.md` section 2.2, in the same commit as the code. **The Builder does not
write designs** (CLAUDE.md roles), so the map-generator design edit is the Architect's; the Builder
amends the module header and `GAME_DESIGN.md` and queues the design edit in `TASKS.md`.

---

## 4. The seam: who owns the lobby ↔ drive transition

`Match` keeps the drive and is **handed** the roster instead of taking it (BRIEF 1c). The seam is
the one `Match` already has five times over — *the world provides; the owner decides*
(`world.markers`, `world.placement`, `world.boars`, `world.bots`, `world.economy`).

Evidence for what is being changed: today `Match.start` connects `service.PlayerAdded` to
`watchPlayer`, and `watchPlayer` registers the player **and** dispatches `{ kind = "join" }`
(`src/server/Match/init.luau`, `watchPlayer`). With `MIN_PLAYERS = 1` that one dispatch starts a
drive (`Phase.step`'s `Waiting` branch → `enterAssigning`). A lobby is exactly the statement *that
is not automatic any more*.

### 4.1 One world switch

```luau
-- src/server/Match/init.luau, inside Match.start
-- WHETHER JOINING THE SERVER IS JOINING THE DRIVE. `~= false` is the idiom this function already
-- uses for `world.remotes` and `world.heartbeat`: a world that injects nothing is unchanged.
local autoEnrol = true          -- module local, set by Match.start, put back by Match.stop
...
autoEnrol = world.enrol ~= false
```

```luau
local function watchPlayer(player: Player)
	names[player.UserId] = player.Name
	board = Score.join(board, player.UserId, player.Name, state.assignment[player.UserId])
	watchCharacter(player)
	if autoEnrol then
		dispatch({ kind = "join", userId = player.UserId, name = player.Name })
	else
		-- REGISTERED, NOT A PARTICIPANT. The board has his row and the character watch is on him;
		-- the drive has not been told he exists. One broadcast, because nothing else will send one.
		broadcast(false)
	end
end
```

A registered-but-not-enrolled player is therefore: in `names`, in `board` with no team, watched by
`watchCharacter`, counted by `Match.trackedPlayers()` — and **not** in `state.participants`, so
`Phase.participantCount` does not see him and `enoughPlayers` is false.

**The feed moves, and that is an improvement, not a loss.** With the switch on, the `join` feed line
is emitted when he steps into the circle rather than when he loads into the server — which is when
he actually joined the hunt.

### 4.2 Two doors `Lobby` calls, and two readers it reads

| Call | Direction | Signature | What it does |
|---|---|---|---|
| `Match.enrol` | **Lobby → Match** | `(player: Player) -> boolean` | dispatches today's `{ kind = "join" }`. Everything after it is today's code. Returns whether he is now a participant |
| `Match.dismissAll` | **Lobby → Match** | `() -> number` | dispatches `{ kind = "dismiss" }`: the roster is cleared with **no feed lines**. Returns how many were cleared |
| `Match.isParticipant` | **Lobby reads** | `(userId: number) -> boolean` | is he in the drive's roster? The read half of the seam |
| `Match.isHeld` | **Lobby reads** | `(userId: number) -> boolean` | **already exists** — the one public reader of `heldStill`. The lobby must not respawn a man the drive is holding at the results scene (§8.1) |

```luau
-- IDEMPOTENT, AND THE GUARD IS NOT DEFENSIVE. `Phase.step`'s `join` branch re-assigns a player to
-- the SMALLER TEAM and re-places him when the phase is `Assigning` or `Running`, so a second enrol
-- of a man who is already in the drive would move him mid-drive. The lobby scans at 10 Hz.
function Match.enrol(player: Player): boolean
	local userId = player.UserId
	if state.participants[userId] ~= nil then
		return true
	end
	if names[userId] == nil then
		return false        -- not registered: this owner has never seen him
	end
	stats.enrolments += 1
	dispatch({ kind = "join", userId = userId, name = player.Name })
	return state.participants[userId] ~= nil
end

-- THE ROSTER, EMPTIED, WITH NOTHING ANNOUNCED. Refused in a world that enrols automatically,
-- because there the roster would never refill and the drive would sit in `Waiting` for ever.
function Match.dismissAll(): number
	if autoEnrol then
		warn("[match] dismissAll in a world that enrols automatically: refused")
		return 0
	end
	local n = Phase.participantCount(state)
	if n == 0 then
		return 0
	end
	stats.dismissals += 1
	dispatch({ kind = "dismiss" })
	return n
end
```

### 4.3 One new pure event: `dismiss`

In `Phase.step`, beside `join` / `team` / `leave`:

```luau
elseif kind == "dismiss" then
	-- THE ROSTER, CLEARED, WITH NO FEED LINE -- which is the whole difference from `leave`. A
	-- player who is standing in the results scene has not LEFT; he is simply not in the next drive.
	-- It changes no phase by itself: `enoughPlayers` is read at the `Waiting` and `Scoring` exits
	-- below, so the drive falls back to `Waiting` through `enterWaiting`, the door task 159 already
	-- built, and the clock is untouched.
	table.clear(next_.participants)
	table.clear(next_.assignment)
	table.insert(effects, { kind = "broadcast" })
```

**What `dismiss` does NOT touch, and every one of these matters:**

* **`board`** (`Score`) — so Karen's results table is still on screen with the drive's points while
  the roster behind it is empty. `Match.snapshot`'s `rows` come from `board`, not from
  `participants`.
* **`names`** — so `enterAssigning` can rebuild the board for whoever enrols next.
* **`heldStill`** (Match's own table) — so everybody stays frozen in the ring for the rest of the
  scene, and `enterWaiting`'s existing `{ kind = "free" }` (userIds nil = everybody) releases them.
  `applyFree(nil)` iterates `heldStill`, not `participants`, so the hold survives the dismissal.
* **`Player.Team`** — so the badges and the team colours in the results scene do not blink off.
  The team is cleared one phase later, by §4.4.

### 4.4 One new effect: `unassign` — and it closes a hole the lobby would otherwise inherit

**The hole, with evidence.** `Match.Body.setTeam` is the only writer of `Player.Team`
(`src/server/Match/Body.luau`, `Body.setTeam`), and its only caller is `applyAssignTeams`, which is
only reached from an `assignTeams` effect. `Phase.enterWaiting` emits `clearScene`, `free`, a feed
line and a `broadcast` — **no `assignTeams`** — so **nothing in the repo ever sets a team back to
nil.** Today that is invisible, because `MIN_PLAYERS = 1` and every tracked player is a participant,
so `enterWaiting` is unreachable in a session with anybody in it. With the lobby it is the normal
end of every drive, and without a fix a player standing by the lodge would still be
`Player.Team = Drivers`: he would keep the horn (`Weapon.Horn.setCarryPolicy` reads
`Body.teamOf(player)` in `ForestTestBoot`), keep the orange vest, show a SHOOTER/DRIVER badge, and
read *"waiting for the drive to start"* instead of the lobby's own line — so BRIEF 1d's *"no team,
no gun, no outfit is not new code"* would be **false**.

The fix is one effect on the drive, so `Body` stays the one writer:

```luau
-- Phase.enterWaiting, before `state.assignment = {}`
local dropped = {}
for userId in pairs(state.assignment) do table.insert(dropped, userId) end
table.sort(dropped)
if #dropped > 0 then table.insert(effects, { kind = "unassign", userIds = dropped }) end
```

```luau
-- Phase.enterAssigning, after `state.assignment = Roster.assign(...)`:
-- ANYBODY WHO WAS IN THE LAST DRIVE AND IS NOT IN THIS ONE. The other door out of `Scoring` is
-- straight into `Assigning` (a lobby player can enrol during the results scene), and that path
-- never reaches `enterWaiting` -- so without this a dismissed player keeps the last drive's team.
local dropped = {}
for userId in pairs(state.previousAssignment or {}) do
	if state.assignment[userId] == nil then table.insert(dropped, userId) end
end
```

```luau
-- Match, beside applyAssignTeams. Through Body, which is the one writer of a team and of what a
-- character wears: `Body.setTeam(player, nil, config)` sets `Neutral = true` and re-dresses, and
-- `Body.dress` with a nil team destroys `HuntOutfit` and this module's own tagged accessories --
-- so the vest and the cap come off through the same door that put them on.
local function applyUnassign(userIds: { number }?)
	for _, userId in ipairs(userIds or {}) do
		local player = playersService():GetPlayerByUserId(userId)
		if player then
			Body.setTeam(player, nil, config)
			stats.unassigned += 1
		end
		board = Score.setTeam(board, userId, nil)
	end
end
```

The horn and the gun then go on their own: `Weapon.Horn`'s `CARRY_SWEEP_SECONDS = 2` level sweep
calls `Horn.refreshCarry`, which revokes a tool `Horn.carriesFor(on, nil)` says false for
(`src/shared/Horn/init.luau`, `Horn.carriesFor` is `on and team == Horn.TEAM`), and the gun's own
arming sweep does the same through `Match.mayCarryWeapon`, which returns false for a player with no
`state.assignment` entry. **No new code, in either system.**

### 4.5 What stops the two owners reaching into each other

| Boundary | What enforces it |
|---|---|
| **`Lobby` is not a second writer of a team** | it has no `setTeam` and no `dress`; it never requires `Match` or `Match.Body`; its world table has no `body`, no `weapon` and no `horn` field |
| **…of a character's position** | the only move it asks for is `world.place(player, cframe)`, which the boot binds to `Match.Body.place`. `Lobby` chooses the CFrame — exactly what `world.placement` already does for the drive — and writes nothing |
| **…of clothes or a gun** | it never calls `Body.dress`, `Weapon.*` or `Horn.*`. A player with no team wears his own avatar and carries nothing, by §4.4 |
| **`Match` never reads the lobby's geometry** | nothing under `src/server/Match/` requires `Lobby` or `ReplicatedStorage.Lobby`; the world table gains one boolean (`enrol`) and no lobby field; `Match.WORLD_OVERRIDABLE` is untouched. **A grep for `Lobby` under `src/server/Match/` must answer nothing** — that is the review claim |
| **The wiring is one-directional** | `ForestTestBoot` hands `Match`'s doors to `Lobby`, never the reverse |

---

## 5. What a player IS in the lobby — derived, not added

Nothing in this list is new code. Every row is what *not being in the drive* already means:

| Fact | Why it is already true | Evidence |
|---|---|---|
| no team | the roster never assigned him; §4.4 clears a stale one through the one writer | `Phase.enterAssigning` assigns from `participants` only |
| no objective line (before this task) | `Objective.text` returns `""` for a team that is not `Shooters`/`Drivers` | `src/client/Hud/Objective.luau`, `Objective.text` first clause |
| no gun | `Match.mayCarryWeapon` returns false in `Waiting`, and false for a userId with no `state.assignment` entry | `Match.mayCarryWeapon` |
| no horn | `Horn.carriesFor(on, nil)` is false, re-evaluated by the 2 s carry sweep | `src/shared/Horn/init.luau`, `src/server/Weapon/Horn.luau` |
| no outfit | `Body.outfitFor(nil, config)` is nil, and `Body.dress` destroys the folder and the tagged accessories first | `Match.Body.dressFor` / `outfitFor` / `dress` |
| no stand circle, no safety rule, no push credit | `Match.standAreaOf` returns nil for a team that is not `Shooters`; `Match.playerDrivers` and `Penalty` are keyed off `state.assignment` | `Match.standAreaOf`, `Match.playerDrivers` |
| no bots in the wood | `syncBots` clears every rig in `Waiting` and returns in every phase but `Assigning`/`Running` | `Match`'s `syncBots` |
| **the lobby look is his ordinary avatar** | **no outfit write at all** happens in the lobby | — |

---

## 6. The join rule, as pure arithmetic

Pattern: **Valve's `trigger_multiple` read as arithmetic** — presence, not collision (§14.2). The
shape `ForestTest.withinStand` already has (*"IS THIS POSITION INSIDE THE STAND'S CIRCLE? Pure, so
the boundary is one rule"*), so the whole rule is drivable in a spec with hand-written positions and
no character at all.

```luau
-- src/server/Lobby/Join.luau -- PURE. No Instance, no service, no clock.

-- FLAT: the Y is ignored, exactly as `ForestTest.withinStand` ignores it, because a player standing
-- on the kerb beside the truck is a stud above the ground and has not left the circle.
-- `<=` -- ON the circle is IN it, the same comparison `withinStand` makes, so the screen's chevron
-- and the rule cannot disagree about the edge (`Objective.CONFIG.ARRIVED_IN_STUDS`'s own reason).
function Join.within(position: Vector3, spot: Vector3, radiusStuds: number): boolean

export type Entry = { since: number, leaveAt: number }

-- ONE STEP OF ONE PLAYER'S COUNTDOWN. Returns the new entry (or nil) and exactly one verdict:
--   "idle"      outside, and was outside: nothing to do
--   "counting"  inside, counting down. `entry.leaveAt` is when he goes
--   "cancelled" he stepped out before it ran down (Karen's rule: stepping back out cancels it)
--   "enrol"     the countdown is done: the caller calls `world.enrol` and the entry is dropped
-- PURE over (entry, inside, now, cfg), so the whole rule -- entry, cancel, re-entry, the exact
-- boundary second -- is a table of cases in a spec with no world.
function Join.decide(entry: Entry?, inside: boolean, now: number, cfg): (Entry?, string)

-- DOES THIS PLAYER BELONG BACK AT THE LODGE? Three booleans in, one out (§8.1).
function Join.needsReturn(inDrive: boolean, held: boolean, inField: boolean?): boolean
```

**`needsReturn`'s third argument is `boolean?` and nil means "no answer, do nothing".** A player
with no character (joining, or mid-respawn) has no position, and *absent is not outside* — the rule
`MapUi.pointsFor` already states (*"a stale dot is a lie about where somebody is"*).

**Two players stepping in at once.** Each has his own entry and his own deadline, started when HE
stepped in. Both enrol independently. With `MIN_PLAYERS = 1` the first enrolment starts the drive on
the same step (`Phase.step`'s `Waiting` branch runs after the event), and the second lands in
`Assigning` — where `Phase.step`'s `join` branch assigns him to the smaller team, holds him if he is
a beater and the line is still held, and places him. **That is existing, tested behaviour**
(`match_phase.spec`, the `join`-mid-drive cases), not new code. A shared countdown was refused: it
would need a rule for what a late arrival does to a deadline somebody else started, and the
Director's instruction was *"pick the simpler"*.

---

## 7. The flow, phase by phase

### 7.1 Enrolling

```
Lobby.step: inside the circle for COUNTDOWN_SECONDS
  -> Lobby clears Player.RespawnLocation (nil) and the DHLobbyLeaveAt attribute
  -> world.enrol(player)   == Match.enrol
      -> dispatch{ kind = "join" }         feed: "<name> joined"
      -> Phase: participants[id] = name
      -> Waiting branch: enoughPlayers and markersComplete -> enterAssigning
          -> clearScene, free, assignTeams, clearBoars, hold(beaters), placePlayers,
             refreshArming, feed "Drive 1", broadcast(force)
          -> Match.Body.place puts him on his stand / at his beater lane
```

**`RespawnLocation` is cleared BEFORE `enrol`**, because `enrol` reaches `LoadCharacter` inside the
same call: with it still set, the engine would put the new character at the lodge and the drive's
pivot would have to beat it. `Body.place` + `Body.settle` already handle exactly that race in this
place (`Body.settle`'s header: the Forest Test's own `ForestRoadSpawn` overwrote the pivot, measured
in task 157) — this just does not create another instance of it.

### 7.2 The end of a drive → back to the lobby. One drive per trip.

No new phase and no new rule (BRIEF 1e):

| Edge | Who | What |
|---|---|---|
| `Running` → `Scoring` | `Phase.enterScoring` (today) | `release`, `clearBoars`, `hold`(everybody), `scene`, the end horn, `broadcast(force)`. **Karen's results scene, untouched** |
| the next `Lobby.step` after it | `Lobby` | `Match.dismissAll()` — the roster is cleared, nothing is announced, the scene and the score panel are unchanged (§4.3) |
| `Scoring` exit, `SCORE_SECONDS` later | `Phase.step`'s `Scoring` branch (today) | `enoughPlayers` is now false → **`enterWaiting`** → `clearScene` (the scene comes down), **`unassign`** (§4.4), `free` (**this is the effect that frees the hold**), feed, `broadcast(force)` |
| the same dispatch | `Match`'s `syncBots` (today) | phase is `Waiting` → `bots.clear()`: the wood is empty |
| the next `Lobby.step` | `Lobby` | every tracked player is now out of the drive, unheld and outside the field → returned to the lodge (§8.1) |

**Which effect frees the hold:** `enterWaiting`'s `{ kind = "free" }` with `userIds = nil`, applied
by `applyFree(nil)`, which iterates `heldStill` and restores each character through `Body.untie`.
**Which takes the scene down:** `enterWaiting`'s `{ kind = "clearScene" }` → `applyClearScene` →
`Match.Scene`.

### 7.3 The one path that skips `Waiting`, and why it is safe

A player who joined the server mid-drive is registered, unenrolled and standing at the lodge — he
can walk into the circle **during the results scene** (the drive's hold is on the ring, not on him).
Then `enoughPlayers` is true at the `Scoring` exit and `Phase` goes straight to `enterAssigning`,
never reaching `enterWaiting`. Two things follow and both are covered:

* the dismissed players' teams are cleared by **`enterAssigning`'s own `unassign`** (§4.4), not by
  `enterWaiting`;
* they are returned to the lodge by the **level-triggered** return rule (§8.1), not by a `Waiting`
  edge. This is why the return is level-triggered and not hung off `PhaseChanged`.

### 7.4 Degraded states: the lobby can never lock the game out

| State | What happens |
|---|---|
| the ground cannot be read yet (the place is still loading) | `Lobby.step` retries the build once a second. The `Match` precedent: *"Re-reading while `Waiting` costs five `GetTagged` calls a second and closes the race for good"* (`Match:step`) |
| the build has still failed after `BUILD_TIMEOUT_SECONDS` | **once**, `Lobby` enrols every tracked player through the same `world.enrol` door and prints one line saying why. The game is then today's game exactly: everybody is in the drive and it starts. No second code path |
| `world.enrol` / `dismissAll` not injected | `Lobby.start` returns false, builds nothing and warns. `Match` was started with `enrol = false` by the same boot, so this combination cannot ship silently: `lobby_live.spec` asserts the refusal |
| the lobby is disabled | `Lobby.start` returns false before it builds anything, and `ForestTestBoot` does not pass `enrol = false` to `Match` — **the boot asks the lobby whether it exists and only then takes the drive's enrolment away.** One line, and the fallback is today's game |

---

## 8. The spawn, and getting back to the lodge

**Open decision 4 is answered: `Match.Body` performs every respawn; `Lobby` only chooses the spot.**
`Body.place(player, cframe, config, onPlaced)` already respawns, pivots, re-pivots on drift
(`Body.settle`) and dresses — so a lobby respawn goes down the identical path a drive placement
does, and `Body.settled()` / `Body.parentWaits()` keep counting it.

### 8.1 One level-triggered rule instead of four edges

```luau
Join.needsReturn(inDrive, held, inField)  ==  (not inDrive) and (not held) and (inField == false)
```

| Case it covers | Why the edge-triggered version would have missed it |
|---|---|
| a player joining the server | `CharacterAutoLoads` may have put him at `ForestRoadSpawn` before any handler ran |
| a dismissed player after the results scene | the `Scoring → Assigning` path never reaches `Waiting` (§7.3) |
| a player who pressed Reset in the lobby | belt to `RespawnLocation`'s brace |
| a player who fell off the shelf's downhill edge | there is no edge to trigger on at all |

`held` is `Match.isHeld(userId)` and it is load-bearing: during the results scene a dismissed player
is not a participant and is 570 studs from the lodge, so **without it the lobby would respawn him
out of Karen's results scene.**

**Throttled.** `Lobby` records `returnedAt[userId]` and will not place the same player again inside
`RETURN_COOLDOWN_SECONDS`, because `Body.place` yields on `LoadCharacter` and the scan runs at 10 Hz.
The nil-position rule above already covers most of it (a respawning player has no root), so the
cooldown is the belt.

### 8.2 `Player.RespawnLocation`, and why it is a new owned thing

**Nothing in the repo writes `Player.RespawnLocation`** (grepped across `*.luau`: no hit). So
`Lobby` can own it outright, and it is the engine's own documented lobby mechanism (§14.1):

* set to `Workspace.Lobby.LodgeSpawn` for a tracked player who is **not** in the drive;
* `nil` for a player who is, cleared before the enrolment that respawns him (§7.1);
* written only when it differs from the current value, so it is one write per change.

The lobby's `SpawnLocation` carries `Neutral = true`, `Enabled = true`, `AllowTeamChangeOnTouch =
false` (the engine must never write a team: that is `Body.setTeam`'s job) and **`Duration = 0`** — a
`SpawnLocation` grants a 10-second ForceField by default, and a bubble round every player at the
lodge is a thing Karen did not ask for.

**`ForestRoadSpawn` is not touched.** It is Karen's Studio content; disabling it from code would
make this owner a writer of another world's instance, and the rollback (*"the flag off = the place
as it is"*) must stay true. The engine's choice between two enabled neutral spawns is therefore
undefined for the first character — which is exactly why the return rule is level-triggered and why
`RespawnLocation` is set as well.

### 8.3 Where he stands

```luau
-- Spread across the porch, so two players never spawn inside each other -- the
-- `Body.placementFor` driver-spread idiom, with this porch's own width.
function Lobby.spawnCFrame(anchor: Vector3, index: number, cfg): CFrame
```
Facing **+Z (north)**: he walks out of the porch looking at the truck, the track and the forest
behind it. That is Karen's *"house is in fields next to forrest"* read as a camera angle.

---

## 9. The geometry, as a config table

All of it is `Lobby.CONFIG` in `src/shared/Lobby/init.luau`, deep-frozen (`Drive.deepFreeze`, the
`Match.CONFIG` idiom). Every offset is **relative to the anchor**, so moving the lobby is one row.
`Build` reads this table and invents no number.

```luau
Lobby.CONFIG = {
	-- ---------------- the field (BRIEF 1i, 3)
	FIELD = {
		SPAN_STUDS = 220,              -- 220 x 220, square, centred on the anchor
		-- THE GRASS BLOCK IS SOLID AND DEEP, so the downhill edge is a BANK and not a floating
		-- shelf. The measured ground spread over this footprint is 16 studs and the worst of the
		-- fifteen sampled footprints was 44, so 48 reaches below the lowest ground either way.
		DEPTH_STUDS = 48,
		-- ...AND THE AIR BLOCK ABOVE IT CUTS THE HILL OFF. 96 > the worst measured spread and well
		-- above the lodge's 18-stud ridge.
		CLEAR_STUDS = 96,
		MATERIAL = Enum.Material.Grass,
	},
	-- ---------------- the lodge: "Wooden log lodge", logs, porch, antlers, warm inside
	LODGE = {
		SIZE = Vector3.new(40, 10, 28),  -- 40 x 28 footprint, 10-stud walls
		RIDGE_STUDS = 18,                -- the ridge above the shelf
		LOG_DIAMETER = 2,                -- 5 courses of cylinders per wall
		DOOR = Vector2.new(6, 9),        -- walk-through: no door part, a gap in the front wall
		PORCH_DEPTH = 8, PORCH_POSTS = 4,
		WINDOWS = 4,
		MATERIAL = Enum.Material.Wood, ROOF_MATERIAL = Enum.Material.WoodPlanks,
		-- the warm inside: a fireplace with ONE PointLight (nothing is animated, nothing is written
		-- per frame), a table with benches, and task 178's empty counter and placeholder sign
		FIRE_LIGHT = { brightness = 2, rangeStuds = 34, color = Color3.fromRGB(255, 180, 110) },
		ANTLERS = { tines = 2 },         -- a skull plate and two beams over the door
		COUNTER = Vector3.new(12, 3.5, 2),
		SIGN_TEXT = "SHOP - coming soon", -- task 178 replaces the sign, not the counter
	},
	-- ---------------- the truck, the track, the spot
	TRUCK = { OFFSET = Vector3.new(26, 0, 18), SIZE = Vector3.new(7, 7, 16), WHEELS = 4 },
	TRACK = { WIDTH_STUDS = 14, TO_Z = 110, MATERIAL = Enum.Material.Ground },
	SPOT = {
		OFFSET = Vector3.new(16, 0, 18),  -- beside the driver's door
		RADIUS_STUDS = 8,                 -- BRIEF 3
		-- THE RING IS `ForestTest.Markers.RING`'S, BORROWED WHOLE (§14.5), so the lobby's circle and
		-- the hunter's stand circle are the same piece of UI language: 20 neon chords, 0.5 thick,
		-- lifted 0.08 clear of the ground, transparency 0.45, hunting orange RGB(235, 150, 60).
		RING = { SEGMENTS = 20, THICKNESS_STUDS = 0.5, HEIGHT_STUDS = 0.12, LIFT_STUDS = 0.08,
		         TRANSPARENCY = 0.45, COLOR = Color3.fromRGB(235, 150, 60) },
		SIGN_TEXT = "STAND HERE TO HUNT",
	},
	SPAWN = { OFFSET = Vector3.new(0, 0, 16), SIZE = Vector3.new(12, 1, 6) },
	-- ---------------- the rule
	COUNTDOWN_SECONDS = 5,              -- BRIEF 3
	SCAN_HZ = 10,
	RETURN_COOLDOWN_SECONDS = 3,
	BUILD_TIMEOUT_SECONDS = 10,
	MAX_PARTS = 400,                    -- BRIEF 3; `Build` counts and the spec asserts it
}
```

### 9.1 The two terrain calls, and the one rule about them

```luau
-- src/server/Lobby/Field.luau
-- PURE. The region of each call, so a spec asserts the arithmetic with no Terrain at all.
function Field.grassBlock(anchor: Vector3, shelfY: number, cfg): (CFrame, Vector3)
function Field.airBlock(anchor: Vector3, shelfY: number, cfg): (CFrame, Vector3)

-- THE ONLY TERRAIN WRITE IN THIS SYSTEM, and `terrain` IS AN ARGUMENT -- which is what keeps the
-- harness out of it: a spec hands in a fake with a recording `FillBlock`, so no spec in the DEV
-- place can write DEV's terrain, ever. Returns the two volumes it filled.
--   Terrain:FillBlock https://create.roblox.com/docs/reference/engine/classes/Terrain#FillBlock
function Field.fill(terrain: any, anchor: Vector3, shelfY: number, cfg): (number, number)
```

* `shelfY` is `world.groundAt(anchor.X, anchor.Z)` — the world's own single ground reader
  (`ForestTest.groundAt`), the same function `ForestTest.Markers.setReaders`, the boar world and
  `Bots.start` are given. **A third copy of "where is the ground" would be two definitions of one
  fact.** nil → no build, retried (§7.4).
* **Grass first, then air.** The grass block's top IS the shelf; the air block starts at the shelf
  and removes the hill above it.
* **It writes nothing outside `FIELD`.** Both regions are computed from one anchor and one span, and
  `lobby.spec` asserts that every corner of both blocks is inside the rectangle.
* **Run time only.** The harness compares the Edit-mode DataModel and does not read Terrain at all
  (grepped: `tools/studio_mcp.py` contains no `terrain`), and a Play-session terrain write does not
  persist — the property `Workspace.ForestMarkers`, `Workspace.Boars`, `Workspace.DriveMarkers` and
  `Workspace.WeaponEffects` already rely on.

**The seam that will show, stated rather than discovered.** A flat shelf cut into a 10 % slope meets
the hillside in a step of up to about ±8 studs at the rectangle's edges (16 studs of spread over the
measured 160-stud footprint, ~22 over 220, split either side of the centre height). The lodge, the
truck, the spot and the track all sit ≥ 80 studs inside the rectangle, so nothing stands on the
seam, and the retune is one number (`SPAN_STUDS`, which pushes the cut further away). Karen judges
it. A slab of parts was refused for the opposite and worse failure: its downhill edge would float
(research note §6a).

### 9.2 Part budget — the target is ≤ 400 (BRIEF 3)

| Block | Parts |
|---|---|
| lodge walls (5 courses × 4 walls, front wall split round the door) | ≤ 40 |
| gables, roof slabs, ridge beam | ≤ 14 |
| porch (floor, 4 posts, rail, roof) | ≤ 12 |
| door frame + antlers over the door | ≤ 10 |
| windows | 4 |
| interior: floor, fireplace + light, table, 2 benches, counter, sign | ≤ 18 |
| truck | ≤ 20 |
| dirt track | ≤ 20 |
| the ring + its sign post | ≤ 24 |
| `LodgeSpawn` | 1 |
| field dressing (a fence line, a woodpile, a trough) | ≤ 40 |
| **total** | **≈ 205, cap 400** |

`Build.build` **returns the count** and `lobby.spec` asserts `<= CONFIG.MAX_PARTS`, so the budget is
a checked claim and not a promise. Every part: `Anchored = true`; everything cosmetic
`CanQuery = false`, `CanTouch = false`, `CastShadow = false` — `CanQuery = false` is load-bearing
for the same reason it is on every marker in `ForestTest.Markers` and on the outfit's plates: *a
slab that stops a pellet changes what the shot hit*. The walls, the floor and the porch **do**
collide (you walk in through the door gap and stand on the porch), and they are the only things that
do. **The folder is parented LAST** — one replication step for the whole lobby, `TestArena.build`'s
own rule.

---

## 10. The screen

**Task 165 keeps the screen** (BRIEF 1k). `Hud.Objective` is *"THE ONE WRITER of the objective LINE
and of the WAYPOINT chevron"*; the lobby is **rows in its pure table** and one more optional
argument, never a second writer.

### 10.1 The rows

```luau
-- Objective.CONFIG.TEXT, beside Waiting/DriverGo/...
-- THE LOBBY'S TWO LINES. Karen's own flow: walk to the car, then a short countdown. They are rows
-- here for the reason every other row is: they are WORDS, and words are hers to rewrite.
Lobby = "walk to the truck to start a hunt",   -- 32 characters: `TextFits` asserts it
LobbyLeaving = "leaving for the hunt in %d",
-- ...AND THE FOURTH WORD, beside STAND, LINE and ROAD.
WORD_TRUCK = "TRUCK",
```

### 10.2 The three signatures that change, all by one optional argument

```luau
export type LobbyNow = {
	spot: Vector3?,       -- where the truck spot is, or nil for "this world has no lobby"
	secondsLeft: number?, -- the countdown, or nil
}

function Objective.text(phase, team, drive: DriveNow?, lobby: LobbyNow?): string
function Objective.targetFor(team, phase, geometry, me, lobby: LobbyNow?): Target?
function Objective.lineVisible(phase, team, reportOpen, mapOpen, scoped, startCardUp, lobby: LobbyNow?): boolean
```

* **`text`**: before the existing clause, *if the team is nil and `phase == "Waiting"` and
  `lobby ~= nil` and `lobby.spot ~= nil`*, return `LobbyLeaving` formatted when `secondsLeft` is a
  number and `Lobby` otherwise. **`lobby.spot ~= nil` is the gate, and it is the repo's own rule:**
  *the screen never claims to know more than the world said*. In DEV there is no spot, so a
  teamless player in `Waiting` reads exactly what he reads today — `""`.
* **`targetFor`**: before the `phase ~= "Assigning" and phase ~= "Running"` guard, the same
  condition returns `{ point = lobby.spot, word = WORD_TRUCK, kind = "truck" }`.
* **`lineVisible`** must forward it, because it calls `Objective.text` itself.

Everything else is already correct for free: `Objective.arrived`'s hysteresis drops the chevron when
he is inside (`ARRIVED_IN_STUDS` 12 vs the spot's radius 8 — he is inside the circle before the
chevron goes, which is the right order); `Hud.markerFor` points the **compass** marker at the truck
with the word `TRUCK`; `MapUi.setTarget` gets the same point. **One target, three drawers**, exactly
as task 165 built it.

### 10.3 Where the truck's position comes from — one definition

The **server builds** the part; the **client reads it**; nobody computes it twice.

```luau
-- src/shared/Lobby/init.luau
Lobby.FOLDER_NAME = "Lobby"
Lobby.SPOT_NAME = "TruckSpot"      -- an invisible, CanQuery=false anchored part at the circle's centre
Lobby.SPAWN_NAME = "LodgeSpawn"

-- MEMOISED, and the cache is dropped when the part leaves the DataModel, so a streamed-out or
-- rebuilt lobby answers nil rather than a stale position (`MapUi.pointsFor`'s rule).
function Lobby.spotPart(): BasePart?
function Lobby.spotPosition(): Vector3?
```

`Hud` reaches the module through the door it already uses for a world-specific module —
`Hud.whenReady(ReplicatedStorage, "Lobby", ...)`, the same call that waits for `ForestTest` — and
builds one `LobbyNow` per frame. **The presence of the PART, not of the module, is what says a world
has a lobby**, so the Hud learns nothing about worlds and reads no flag.

### 10.4 The countdown reaches the client without a new wire

`Lobby` writes one attribute on the `Player` it belongs to:

```luau
Lobby.LEAVE_AT_ATTRIBUTE = "DHLobbyLeaveAt"   -- Workspace:GetServerTimeNow() + COUNTDOWN, or nil
function Lobby.secondsLeft(leaveAt: number?, serverNow: number): number?   -- PURE
```

* **No new RemoteEvent and no inbound door.** Attributes as a one-way, read-only mirror is this
  repo's own pattern (`ReplicatedStorage.Flags.State`, `ServerStorage.DHFlag_*`,
  `ServerStorage.DHForestStartRole`, `LocalPlayer.TestReport`).
* **The deadline is the SERVER's**, converted through `Workspace:GetServerTimeNow()` and counted
  down locally — the one conversion `Match.snapshot`'s `phaseEndsAt` / `holdUntil` already
  establish. A client-side countdown invented from a client-side position would be a second answer
  to "when do I leave", and it would read 0 while the server had not enrolled him.
* It is not a secret and it is not a rule: it is one deadline, for one player, that the server has
  already decided.

### 10.5 `MapUi` in the lobby: the minimap hides, the full map stays

Today the lobby is **513 studs outside** `MapUi.geometryFromForestTest`'s stated bounds
(`minZ = EXIT_Z - 60 = -2437`; the lobby is at z = -2950). So:

* the **minimap** is centred on the player with a 300-stud range: it would draw a dark disc, a scale
  bar and your own wedge, and nothing else. That is the half-draw BRIEF 1k refuses. **It hides.**
* the **full map** is a frame that holds the whole stated world and **pins** an out-of-range marker
  to its border — its own documented rule (*"pinned … will stick on the border instead of
  disappearing"*). A player at the lodge sees the road, the nine stands and himself pinned to the
  south edge. That is true, it is the map's own language, and **M and the rail button keep working**,
  so there is no dead button (`Hud.Rail`'s own rule).

One pure predicate and one existing one gains one argument:

```luau
function MapUi.withinBounds(bounds: Bounds, me: Vector3): boolean          -- PURE, new
function MapUi.minimapVisible(open, suppressed, reportOpen, hasGeometry, outsideBounds: boolean?): boolean
```

`outsideBounds` defaults to false (nil = false), so **every existing caller and every existing spec
case is bit-identical**. `MapUi.render` already builds the roster and finds `me`; the only change is
to compute `me` **before** the `MapUi.applyVisibility()` call and store
`outside = me ~= nil and not MapUi.withinBounds(geometry.bounds, me)` — `applyVisibility` stays the
one writer of both `Visible` fields and **the Hud gains no plumbing at all**.

**`me == nil` must not hide the map.** Absent is not outside.

**And the rule knows nothing about the lobby.** "You are outside the map's own frame" is a fact
about the world's stated geometry; it stays true if the lobby moves, and it needs no lobby concept
in the Hud.

### 10.6 What is deliberately left alone

`Phase.waitingFor` still answers `"players"` in the lobby, so the drive bar reads `WAITING players`.
That is true — the drive IS short of participants — and the INSTRUCTION is the objective line, which
is the element task 165 added precisely because *"everything on screen was a fact and nothing was an
instruction"*. The wording is Karen's if she wants it changed (§19).

---

## 11. The flag

```luau
-- src/shared/Flags/init.luau
LOBBY = {
	default = false,
	owner = "ServerScriptService.Lobby",
	born = "2026-10-13 task 177",
	expires = "2026-11-03",  -- 21 days, the ceiling in docs/design/feature-flags.md section 12
	why = "The player starts at a hunting lodge in the fields and starts a hunt by standing in the "
		.. "marked circle beside the truck. OFF is the game before task 177: joining the server "
		.. "joins the drive.",
} :: FlagRow,
```

**There is room: 11 rows are declared and `Flags.MAX_FLAGS` is 12**, and `Flags.problems` fails only
above it (`#names > Flags.MAX_FLAGS`). This row takes the last slot; a thirteenth is the Director's
call (`feature-flags.md` §14 item 3).

**One read, at the owner's boundary, passed inward — the only permitted shape:**

```luau
-- src/server/Lobby/init.luau
Lobby.ENABLED = Flags.isOn("LOBBY")              -- the one read, at this boundary
function Lobby.start(world): boolean             -- world.enabled defaults to Lobby.ENABLED
```

**Both branches are reachable by parameter.** A spec calls `Lobby.start({ enabled = true, ... })`
with fake seams while the row sits at `false`, and `Lobby.start({ enabled = false })` proves the OFF
branch builds nothing — the discipline `Match.CONFIG.BOTS.ENABLED` and `Boar`'s world config
already follow.

**`ForestTestBoot` turns it on through the world's own config** (BRIEF 1j), the way it already turns
`BOAR_MODEL`, `CALM`, `PACE`, `MOVE` and `LINE` on — not through a live `DHFlag_` attribute, which
is not in git and is lost when the place is reopened. **The cost of that is stated rather than
discovered, and it is the same cost those five already carry: in the Forest Test the lobby cannot be
switched off with `tools/flags.py`. The rollback for that world is a ONE-LINE commit in
`ForestTestBoot` (`enabled = false`)**, and the flag row is what keeps the DEV place — where the
harness runs — at the declared default.

---

## 12. The public interface, in full

### 12.1 `ReplicatedStorage.Lobby` (shared data, no run-time writer)

```luau
Lobby.CONFIG                                        -- §9, deep-frozen
Lobby.FOLDER_NAME / SPOT_NAME / SPAWN_NAME: string
Lobby.LEAVE_AT_ATTRIBUTE: string
Lobby.ANCHORS: { [string]: { x: number, z: number } }
function Lobby.anchorFor(world: string): { x: number, z: number }?    -- PURE
function Lobby.spotPart(): BasePart?                                  -- memoised reader
function Lobby.spotPosition(): Vector3?
function Lobby.secondsLeft(leaveAt: number?, serverNow: number): number?   -- PURE
```

### 12.2 `ServerScriptService.Lobby` (the owner)

```luau
-- NOTHING HAPPENS ON REQUIRE. Only Lobby.start(world) begins production -- the rule
-- `Match`, `Boar`, `Weapon`, `Bots` and `Economy` all follow, and what lets every spec drive the
-- whole system with no players, no terrain and no clock.
function Lobby.start(world): boolean      -- false = it built nothing, and says why
function Lobby.stop()                     -- clears the folder, the entries and every attribute it wrote
function Lobby.step(now: number, players: { any })     -- the one entry point, from the world's clock
function Lobby.onPhase(phase: string)                  -- records the drive's phase; acts on the next step
function Lobby.stats()
-- exported pure, for the specs (the `Match.Phase` / `Boar.Brain` idiom)
Lobby.Join, Lobby.Field, Lobby.Build, Lobby.Data
```

`world`, every field optional except the three doors:

| Field | Type | Bound by `ForestTestBoot` to | Why it is injected |
|---|---|---|---|
| `enabled` | `boolean?` | `true` | §11 |
| `world` | `string?` | `Map.EXPECTED_WORLD` | which anchor row |
| `enrol` | `(Player) -> boolean` | `Match.enrol` | neither owner requires the other |
| `dismissAll` | `() -> number` | `Match.dismissAll` | ” |
| `inDrive` | `(number) -> boolean` | `Match.isParticipant` | ” |
| `isHeld` | `(number) -> boolean` | `Match.isHeld` | ” |
| `place` | `(Player, CFrame) -> ()` | `function(p, cf) Match.Body.place(p, cf, Match.CONFIG) end` | **`Body` stays the one writer of where a character stands** |
| `groundAt` | `(number, number) -> number?` | `ForestTest.groundAt` | the world's one ground reader |
| `terrain` | `any?` | `Workspace.Terrain` | so a spec writes no terrain |
| `root` | `Instance?` | `Workspace` | so a spec builds into its own folder |
| `now` | `() -> number` | `os.clock` | the `Match` / `Bots` test seam |

**No events, no remotes, no bindables.** The lobby publishes nothing: one attribute per player, read
by that player's own client. There is no inbound door at all, so nothing a client sends can enrol
anybody.

### 12.3 `ServerScriptService.Match` — the whole delta

| Symbol | Change |
|---|---|
| `Match.start` | reads `world.enrol ~= false` into `autoEnrol`; `Match.stop` puts it back to `true` |
| `watchPlayer` | dispatches `join` only when `autoEnrol` (§4.1) |
| `Match.enrol(player)` | **new** door |
| `Match.dismissAll()` | **new** door |
| `Match.isParticipant(userId)` | **new** reader, beside `isTied` / `isHeld` / `assignmentOf` / `trackedPlayers` |
| `applyUnassign(userIds)` | **new** effect application, through `Body.setTeam(player, nil, config)` |
| `Match.stats()` | `+ enrolments`, `+ dismissals`, `+ unassigned` |
| `Phase.step` | **new** event `dismiss` |
| `Phase.enterWaiting` / `enterAssigning` | emit **new** effect `unassign` |

Nothing else in the drive moves: no phase, no number, no deadline, no remote, no wire field. The
snapshot is byte-identical for a world that injects nothing.

### 12.4 `ForestTestBoot` — the wiring, in order

```luau
-- 1. THE LOBBY FIRST, because the drive's enrolment switch depends on whether it exists.
local lobbyOn = Lobby.start({
	enabled = true, world = Map.EXPECTED_WORLD,
	enrol = Match.enrol, dismissAll = Match.dismissAll,
	inDrive = Match.isParticipant, isHeld = Match.isHeld,
	place = function(player, cframe) Match.Body.place(player, cframe, Match.CONFIG) end,
	groundAt = Data.groundAt, terrain = Workspace.Terrain,
	now = function() return os.clock() end,
})

-- 2. ...and only then is the drive's enrolment taken away. No lobby = today's game.
Match.start({ ..., enrol = not lobbyOn and nil or false })

-- 3. One more listener on the signal this file already listens to twice.
Match.PhaseChanged:Connect(function(_before, phase) Lobby.onPhase(phase) end)

-- 4. One more line in the Heartbeat this file already runs, which already walks every player.
Lobby.step(now, Players:GetPlayers())
```

**Open decision 2 is answered: the lobby has NO clock of its own.** `ForestTestBoot` already runs
one `RunService.Heartbeat` that walks every player's root every frame for `ForestTest.boundary`;
`Lobby.step` is one more call in it, throttled inside the module to `SCAN_HZ = 10`. A second clock
would be a second answer to "what time is it" in a file whose header already says *"ONE HEARTBEAT
FOR BOTH JOBS"*.

**`onPhase` records and does not act.** `Match` fires `PhaseChanged` at the end of `dispatch`, and
`Match:step`'s own comment says why nothing may dispatch from inside a dispatch (*"a dispatch inside
a dispatch would apply effects out of order"*). So `onPhase` writes one field and the next
`Lobby.step` acts on it — the `markersStale` idiom, and it makes the end-of-drive flow drivable in a
spec by calling `Lobby.onPhase("Scoring")` with no drive at all.

---

## 13. What it reads from and writes to other systems

| Thing | Owner | The lobby's relationship |
|---|---|---|
| `Workspace.Lobby` and every part in it | **`Lobby.Build`** | writes (the only writer) |
| Terrain inside `CONFIG.FIELD`, at run time | **`Lobby.Field`** | writes (the only writer; `MapGen.Ground` owns DEV's terrain in Edit — §3.1) |
| `Player.RespawnLocation` of a player not in the drive | **`Lobby`** | writes (nothing else in the repo writes it) |
| `Player` attribute `DHLobbyLeaveAt` | **`Lobby`** | writes |
| the roster | `Match` | **calls** `enrol` / `dismissAll`; **reads** `isParticipant` |
| who is frozen | `Match` (`heldStill`) | **reads** `isHeld` |
| the phase | `Match` | **reads**, through `onPhase` off `Match.PhaseChanged` |
| where a character stands | `Match.Body` | **asks**, through the injected `place` |
| a team, clothes, a tool | `Match.Body`, `Weapon`, `Weapon.Horn` | **never touches** |
| where the ground is in this world | `ForestTest` (`Data.groundAt`) | **reads**, injected |
| the objective line and the chevron | `Hud.Objective` | **provides data** (the spot, through `ReplicatedStorage.Lobby`); writes nothing drawn |
| the map | `Hud.MapUi` | **nothing at all**: the minimap's rule is "outside the stated bounds", which names no lobby |
| `ForestRoadSpawn`, `OurForest`, the road, the stands | Karen's Studio content / `ForestTest` | **never touches** |

---

## 14. External sources

Named, linked, with licence and maintenance status. **These links were not opened in this session**
(the Architect has Read/Grep/Glob only); every API below is one this repo already calls or one the
engine reference documents, and each is proved by the harness run rather than by the link — the same
disclosure the research note makes in its §10.

### 14.1 Roblox Creator Docs — `SpawnLocation` and `Player.RespawnLocation` — **ADOPTED**
<https://create.roblox.com/docs/reference/engine/classes/SpawnLocation> ·
<https://create.roblox.com/docs/reference/engine/classes/Player#RespawnLocation>
*Licence:* CC BY 4.0 (the `Roblox/creator-docs` repository states it). *Maintenance:* first-party,
current.
**Well:** this is the engine's own lobby mechanism and it is older than teleporting — a `Neutral`
spawn is the lobby, `RespawnLocation` overrides the choice **per player**, so one server holds both
the lobby and the arena and the harness can see the whole flow in one DataModel.
**Badly:** with two enabled neutral spawns in a place the engine's choice for the FIRST character is
undefined, and `AllowTeamChangeOnTouch` would make the engine a second writer of `Player.Team`.
**Adopted:** the spawn and `RespawnLocation`, with `AllowTeamChangeOnTouch = false` and
`Duration = 0`, and the undefined first choice answered by the level-triggered return rule (§8).

### 14.2 Valve Developer Community — `trigger_multiple` — **ADOPTED (as arithmetic)**
<https://developer.valvesoftware.com/wiki/Trigger_multiple>
*Licence:* CC BY-SA (the VDC wiki's own licence). *Maintenance:* community wiki, actively edited; the
entity ships in every Source game.
**Well:** a volume that knows who is INSIDE it — presence, not collision. Half-Life's whole level
flow is built on it, and "standing somewhere IS the request" is exactly Karen's *"walk to a car"*.
**Badly:** it is a brush entity in a compiled map; there is no such thing in Roblox, and the naive
Roblox translation (`BasePart.Touched`,
<https://create.roblox.com/docs/reference/engine/classes/BasePart#Touched>, CC BY 4.0, current) is a
physics event that fires on CONTACT, so a player standing still generates nothing and `TouchEnded`
cannot answer "has he left".
**Adopted:** the IDEA, implemented as one flat distance comparison per player per tick
(`Join.within`) — which is pure, so the whole rule is a table of cases in a spec. This repo has
already borrowed from this family and says so in code: `src/server/ForestTest/Markers.luau` cites
`info_player_terrorist` and `AGameModeBase::FindPlayerStart` for *"the world places the entities the
game mode queries"*.

### 14.3 Roblox Creator Docs — `ProximityPrompt` — **REJECTED**
<https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt>
*Licence:* CC BY 4.0. *Maintenance:* first-party, current.
**Well:** first-party, draws its own UI, `HoldDuration` IS the countdown, and `Triggered` is
server-side.
**Badly:** it is a BUTTON. Karen asked to walk to the car, not to hold E at it, and it adds an input
binding plus a piece of UI owned by neither `Hud` (which owns the screen) nor this system.
**Rejected**, and the reason is recorded so it is not re-litigated.

### 14.4 Roblox Creator Docs — `Terrain:FillBlock` and `Enum.Material` — **ADOPTED**
<https://create.roblox.com/docs/reference/engine/classes/Terrain#FillBlock> ·
<https://create.roblox.com/docs/reference/engine/enums/Material>
*Licence:* CC BY 4.0. *Maintenance:* first-party, current.
**Well:** one call fills one box with one material; grass for the shelf and `Air` for the hill above
it is two calls and a real grass field that meets the existing terrain at its edges. It looks like a
field because it is one.
**Badly:** it is axis-aligned and cannot ramp, so the shelf meets the slope in a visible step
(§9.1); and it makes this system a writer of Terrain, which `MapGen.Ground` claims in its own header
— hence the explicit boundary in §3.1 and §9.1. Its per-call voxel ceiling is **not verified** here
(§18).
**Adopted** over a slab of parts, whose downhill edge would float 16 studs — this project's named
failure mode (measured right, looks wrong).

### 14.5 This repository — `ForestTest.Markers.RING` and `TestArena.build` — **BORROWED WHOLE**
`src/server/ForestTest/Markers.luau` (`Markers.RING`, `Markers.ring`) ·
`src/server/TestArena.luau` (`TestArena.build`)
*Licence:* this project's own. *Maintenance:* live, task 166/175 and task 17.
**Well:** `Markers.RING` is a ring of 20 neon chords with every number already justified (0.15 studs
of polygon error at r = 12, a 0.08-stud lift against z-fighting, hunting orange RGB(235, 150, 60)
*"the colour this game already uses for 'this is yours'"*) and **Karen has already accepted that
picture on screen**. `TestArena.build` is the parts-into-a-folder, parent-last pattern.
**Badly:** `Markers.ring` places each chord on its own ground reading via two injected raycasters,
which the lobby does not need (its shelf is flat **by construction**), so the lobby's ring is the
same table and the same shape with a constant Y.
**Adopted:** the lobby's circle is visibly the same object as a hunter's stand circle, which is the
UI language task 165 and 166 established, at the cost of nothing.

### 14.6 Rejected, with its reason recorded
`TeleportService` / `ReserveServer` (research note §2a) — **a two-place lobby puts the most
important transition in the game where no test can reach it**: the harness drives ONE Studio on ONE
place (`Studio has the DEV place open` is a real check in `tools/studio_mcp.py`). Unreal's
`ServerTravel`/seamless travel (<https://dev.epicgames.com/documentation/en-us/unreal-engine/travelling-in-multiplayer-in-unreal-engine>,
Epic's proprietary documentation licence, current) ships a whole second mechanism because travel
itself drops players: the lesson borrowed is *the transition is the dangerous part, so do not build
one before you need it*. `InsertService:LoadAsset` and Meshy for the lodge — both need Karen's OK,
an `assets/uploads.json` row and a hand check for scripts (research note §4b/4c); they are the
upgrade path and `docs/design/asset-pipeline.md` owns it.

---

## 15. Numeric targets

| What | Target | How it is checked |
|---|---|---|
| lobby centre, Forest Test | (2850, -2950) | `lobby.spec`: `Lobby.anchorFor("forest-test")` |
| field shelf | 220 × 220 studs, grass, flat | `lobby.spec`: both `Field` regions inside the rectangle |
| grass block depth / air clearance | 48 / 96 studs | `lobby.spec` against the measured spread (16 here, 44 worst of fifteen) |
| truck spot radius | **8 studs** | `lobby.spec`: `Join.within` at 7.9 / 8.0 / 8.1 |
| countdown to leave | **5 s** | `lobby.spec`: `Join.decide` at 4.9 / 5.0 |
| lodge | about 40 × 28 studs, 18-stud ridge | `lobby.spec` reads `CONFIG.LODGE` |
| lobby part budget | **≤ 400 parts** | `Build.build` returns the count; `lobby.spec` asserts it |
| build time at boot | **≤ 1 s** | `Lobby.stats().buildMs`, printed by the boot; `lobby_live.spec` asserts ≤ 1000 |
| presence scan | 10 Hz, ≤ 1 flat subtraction per player per scan, **no new clock** | `lobby_live.spec` counts `stats.scans` over a known span |
| enrol → `Assigning` | **same dispatch** (0 extra ticks) | `lobby_live.spec` / `match_live.spec`: `Match.phase()` is `Assigning` on return from `enrol` |
| lodge → stand respawns per drive | **1** (the drive's own `placePlayers`) | `Body.place` call count in `lobby_live.spec`'s fake |
| returns to the lodge per drive end | **1 per player** | `stats.returns`, and `RETURN_COOLDOWN_SECONDS = 3` |
| DEV harness | **the same `m` checks, every one with the same answer, as at `102fbe9`** | §16.4 |
| flag rows | **12**, `MAX_FLAGS` 12 | `flags.spec` (`Flags.problems` is empty) |

---

## 16. How it is tested

### 16.1 Server specs

**`tests/server/lobby.spec.luau` — pure, no world, no terrain, no character** (scope `lobby`):

1. `Lobby.anchorFor`: the Forest Test row; **nil for `"map:v1"`** and for an unknown world.
2. `Join.within`: inside, outside, exactly ON the circle (`<=`, the `withinStand` comparison), and
   **50 studs above the spot is still inside** (flat).
3. `Join.decide`, as a table of cases: idle → counting → `enrol` at exactly
   `COUNTDOWN_SECONDS`; counting → `cancelled` on stepping out; `cancelled` → counting restarts the
   clock (re-entry does not inherit the old deadline); an entry that has already enrolled is dropped.
4. `Join.needsReturn`: all eight combinations, **including `inField = nil` → false** (absent is not
   outside).
5. `Field.grassBlock` / `Field.airBlock`: both regions' eight corners inside `CONFIG.FIELD`; the
   grass block's top IS the shelf; the air block's bottom IS the shelf; the air block clears the
   lodge's ridge.
6. `Field.fill` against a **fake terrain** that records its calls: two calls, grass then air, the
   right materials, and **the DEV place's real `Terrain` is never touched** — which is what makes
   this spec safe to run in the harness's own place.
7. `Build.build` into a **spec-owned Folder**: part count ≤ `CONFIG.MAX_PARTS`; every part
   `Anchored`; every cosmetic part `CanQuery = false`; the parts that may collide are exactly the
   walls, floor, porch and roof; `TruckSpot` exists, is named `Lobby.SPOT_NAME` and sits at
   `anchor + SPOT.OFFSET`; `LodgeSpawn` is a `SpawnLocation` with `Neutral = true`,
   `AllowTeamChangeOnTouch = false`, `Duration = 0`; the door is a GAP (no part inside the doorway's
   volume); **no `Script`, `LocalScript` or `ModuleScript` anywhere in the tree**; the spec destroys
   its folder.
8. `Lobby.spawnCFrame`: two indices are more than a body apart; the look is +Z.
9. `Lobby.secondsLeft`: nil in, nil out; a past deadline floors at 0.

**`tests/server/lobby_live.spec.luau` — the owner against fakes** (scope `lobby`):

10. `Lobby.start({ enabled = false })` → false, nothing built, no terrain call.
11. `start` with a missing door → false and a warning, nothing built.
12. the whole flow with fake occupants (`{ UserId, Character }` with a real root part in a
    spec-owned model): step outside → nothing; step inside → `DHLobbyLeaveAt` is set; step out →
    cleared, `enrol` not called; stay in → `enrol` called **exactly once**, `RespawnLocation`
    cleared first, the attribute cleared.
13. `onPhase("Scoring")` then one step → `dismissAll` called **once**, and not again on the next
    step.
14. `onPhase("Waiting")` then one step → `place` called once per player with the lobby CFrame, and
    **not** for a player the fake `isHeld` says is held, and **not** for a player the fake `inDrive`
    says is in the drive.
15. the build-timeout fallback: with `groundAt` answering nil, after `BUILD_TIMEOUT_SECONDS`
    every tracked player is enrolled **once** and one line is printed.
16. `Lobby.stop()`: the folder is gone, every attribute it wrote is nil, `stats.returns` and the
    entry table are empty — the teardown assertion every owner's spec makes.

**`tests/server/match_phase.spec.luau`** (pure, `+` cases): `dismiss` empties `participants` and
`assignment`, **emits no `feed` effect** and one `broadcast`; after it, the `Scoring` exit takes
`enterWaiting` and not `enterAssigning`; `enterWaiting` emits `unassign` with the sorted ids that
had a team, plus `clearScene` and `free`; `enterAssigning` emits `unassign` for exactly the
`previousAssignment` members who are not in the new assignment.

**`tests/server/match_live.spec.luau`** (`+` cases): a world with `enrol = false` registers a player
(`Match.trackedPlayers()` is 1, his board row exists) and **does not** make him a participant
(`Match.isParticipant` false, the phase stays `Waiting`); `Match.enrol` makes him one and the phase
is `Assigning` on return; a second `enrol` is a no-op; `Match.dismissAll` empties the roster and
**the board still has his row and his points**; `Match.dismissAll` in a world with `enrol` unset
returns 0; and the identity claim — **a world that injects no `enrol` behaves exactly as before**
(`Match.config() == Match.CONFIG`, a player joining becomes a participant).

### 16.2 Client specs (one player)

**`tests/client/hud_clarity.spec.luau`** (`+` cases, scope `hud`): `Objective.text(nil-team,
"Waiting", nil, nil)` is `""` — **the DEV answer, unchanged**; with `{ spot = … }` it is the lobby
line; with `secondsLeft = 3.2` it is `"leaving for the hunt in 4"` (`ceil`, as the beater's
countdown already does); `targetFor` returns the TRUCK target only for a teamless player in
`Waiting` with a spot, and nil in `Assigning`, `Running`, `Scoring` and for a player WITH a team;
`lineVisible` forwards the lobby argument; the lobby line **fits at 400 × 800** by the engine's own
`TextFits`, exactly as the other eight rows are measured.

**`tests/client/map_ui.spec.luau`** (`+` cases, scope `hud`): `withinBounds` inside, outside and on
the boundary; `minimapVisible(..., outsideBounds = true)` is false and every existing combination is
unchanged when the argument is nil; `fullMapVisible` is untouched.

**No change to `tests/client/Role.luau`, `match_client.spec` or `outfit_client.spec`.**

### 16.3 Harness input and screenshots

* **No input scenario.** The join rule is positional, and `tests/client/input_scenarios.txt` cannot
  express "walk 8 studs" (keys, buttons, mouse moves and gaps only — `tools/studio_mcp.py`'s
  docstring). The rule is proved by the pure spec with hand-written positions and by the live spec
  with fake occupants, which is the player's path through the same arithmetic.
* **Rule 5 — and the Builder must be honest about which half it can do tonight.** The lobby is built
  at RUN TIME in the **Forest Test** place, so a photograph needs that place open in Studio and in
  Play. `python tools/studio_mcp.py capture <name> [camera] [look-at]` has **no place-id check**
  (unlike `test`, which refuses anything but the DEV place), so it will capture whichever Studio is
  connected — if the Forest Test session is the one that is open. If it is not, **the lodge cannot be
  screenshotted by the Builder**, and the request must say so under "what could not be verified"
  with a `## Needs Karen` asking her to look. That is the brief's own plan: *Karen judges the look in
  the morning.* **Do not report a screenshot that was not taken and inspected.**

### 16.4 The gate, and the DEV place

* **DEV sees no lobby.** `ForestTestBoot` returns early when `Map.EXPECTED_WORLD ~= "forest-test"`,
  `Lobby.anchorFor("map:v1")` is nil, and the flag is `false`. `MatchBoot` passes no `enrol`, so
  `autoEnrol` is true and `watchPlayer` takes the line it takes today. **No existing harness check
  changes its answer and the count `m` is unchanged**: the new specs ride inside the one Play check,
  the flag mirror's attribute count is asserted as `#flags + 2` rather than as a literal
  (`flags.spec`), and `Workspace` is not Rojo-owned so no run-time part or terrain voxel can reach
  the Edit-mode comparison. **That is the claim to verify by running the gate, not to assert here.**
* **`tools/studio_mcp.py` must gain the scope rows in the same commit**, or `selftest` fails in CI
  (*"`selftest` fails if a spec file belongs to no scope"*, and an unmapped `src/` path resolves to
  `all`):

  ```python
  # BLAST_RADIUS +=
  ("src/server/Lobby/", "lobby"),
  ("src/shared/Lobby/", "lobby"),
  # SCOPE_SPECS +=
  "lobby": ("tests/server/lobby.spec.luau", "tests/server/lobby_live.spec.luau",
            # DUAL MEMBERSHIP, the idiom `zz_horn`/`boar_hit`/`shoot_boar` already use: the lobby
            # calls the drive's two doors, so a lobby change plays the drive's own phase specs.
            "tests/server/match_phase.spec.luau", "tests/server/match_live.spec.luau"),
  # ...and both new specs are added to the "match" tuple too, so a src/server/Match/ edit plays them.
  ```
* **THE TWO-PLAYER RUN IS IN THIS TASK'S MERGE GATE, and the design cannot avoid it.** The seam
  BRIEF 1c fixes is on `Match`, so `src/server/Match/init.luau`, `src/server/Match/Phase.luau`,
  `tests/server/match_phase.spec.luau` and `tests/server/match_live.spec.luau` all change — and all
  four are in `TWO_PLAYER_PATHS` (`tools/agents.py`: `"src/server/Match/"`,
  `"tests/server/match_phase.spec.luau"`, `"tests/server/match_live.spec.luau"`). So:
  * a **review round** may run on a scoped line (`scope=auto:lobby,match,hud,flags`), and then
    `tools/agents.py` asks for no `[harness2]` line at all (CLAUDE.md, "Run / test");
  * the **PR to `main`** needs the full `test` **and** `[harness2]` for the same commit, and that
    costs one human click. It rides with Karen's morning look at the lodge, which this task needs
    anyway. §19 item D3 offers the Director the alternative.
  No design that keeps BRIEF 1c's boundary avoids this: the alternative — faking `world.players` so
  the drive never hears about a lobby player — can only clear the roster by faking a `PlayerRemoving`
  per player, which emits the `leave` feed lines the brief forbids ("clear the roster **with no feed
  lines**") and would print *"X left"* about a man standing in front of Karen.

---

## 17. Build order for the Builder

One task, but the order matters because each step is provable before the next:

1. `src/shared/Lobby/init.luau` — the data, the anchors, the readers. `Flags` row.
2. `src/server/Lobby/Join.luau` + `Field.luau` (pure) and `tests/server/lobby.spec.luau` cases 1-6.
3. `src/server/Lobby/Build.luau` and case 7. **Look at it** (§16.3) before going further.
4. The `Match` seam (§12.3) and the `match_phase` / `match_live` cases — provable with no lobby at
   all.
5. `src/server/Lobby/init.luau` and `tests/server/lobby_live.spec.luau`.
6. `ForestTestBoot` wiring (§12.4).
7. The screen: `Objective` rows and the three signatures, `MapUi.withinBounds`, the Hud's one
   `LobbyNow` per frame, and the client cases.
8. `tools/studio_mcp.py` scope rows, `GAME_DESIGN.md` owner rows, the `MapGen.Ground` header
   amendment, `docs/research/INDEX.md`.

---

## 18. What I could not verify

1. **`Terrain:FillBlock`'s per-call voxel ceiling.** The lobby's two calls are 36,300 and 72,600
   voxels at the 4-stud resolution. `MapGen.Ground`'s header records a MEASURED
   `WriteVoxels` ceiling of 24,576 voxels per region in this Studio version — a different API, but
   near enough to matter. **Named fallback:** if a call is refused, chunk the fill along x exactly as
   `MapGen.Ground.paintTrack` already chunks its own regions (`chunk = 512`), which changes no
   number in `CONFIG` and nothing in the arithmetic. The Builder must report which path it took.
2. **The absolute ground height at (2850, -2950)** is not in the brief and is not guessed here
   (§2). The build measures it; `Lobby.stats().shelfY` must be printed so it is a number in the
   console and not a belief.
3. **How the shelf's edge reads from standing height** (§9.1) is a picture, so it is Karen's.
4. **Whether `Workspace.StreamingEnabled` is on in the Forest Test place.** If it is, a client whose
   camera is at the lodge may not have the road, and one at the road may not have `TruckSpot` — in
   which case `Lobby.spotPosition()` answers nil and the chevron is simply absent, which is the
   correct answer either way (*"never a guess and never a blank frame"*). No design decision rests
   on it.
5. **That `Player` attributes replicate to the owning client** is relied on by §10.4. This repo
   already relies on attribute replication for `ReplicatedStorage.Flags.State` and the harness
   measured in task 41 that a **`LocalPlayer`** attribute written on a client does NOT reach the
   server — the opposite direction, which is the one this design uses. If the server → client
   direction turns out not to replicate, the countdown line is absent (the rest of the lobby is
   unaffected) and the fallback is the `Flags.State` shape: one attribute on the already-replicated
   `Workspace.Lobby.TruckSpot` instead of on the `Player`. `lobby_live.spec` asserts the write; only
   a live session can prove the read.
6. **No harness run, no lint and no build was performed for this document** — the Architect is
   read-only. The evidence in `.agent-evidence/` is for `726464a`.

---

## 19. Open decisions

### For Karen (feel and design) — none of them blocks building

1. **The look of the lodge, the truck and the field.** Every number in §9 is a Director's first
   value; she judges the picture in the morning. The most likely retunes, each one line:
   `LODGE.SIZE`, `RIDGE_STUDS`, `FIRE_LIGHT.brightness`, `FIELD.SPAN_STUDS` (how far away the cut
   edge is).
2. **The two sentences**: *"walk to the truck to start a hunt"* and *"leaving for the hunt in %d"*,
   and the sign's *"STAND HERE TO HUNT"*.
3. **5 seconds and 8 studs.** Long enough to step out of by accident and back in; a circle smaller
   than a stand's 12 and bigger than a stride (16 studs/s).
4. **Does she want the drive bar's `WAITING players` reworded in the lobby** (§10.6)? It is true as
   it stands; a lobby-specific word is one row in the server's `Phase.waitingFor` list.
5. **`NEEDS KAREN`, probably:** the Forest Test Studio in Play so the lodge can be photographed
   (§16.3), and the one `test2` click for the merge (§16.4).

### For the Director (scope) — none of them blocks building

1. **`MIN_PLAYERS` stays 1**, so one real player who steps into the circle gets a full 4 + 4 drive.
   If it is ever raised, the enrolled-and-waiting state becomes reachable and needs one more
   `Objective` row (*"waiting for the hunt to fill"*). **Not built, because today it is
   unreachable** — queue it rather than ship unreachable words.
2. **The lobby cannot be switched off in the Forest Test without a commit** (§11), exactly as
   `BOAR_MODEL`, `PACE`, `MOVE`, `CALM` and `LINE` cannot. The rollback is one line in
   `ForestTestBoot`. Confirm that is the trade you want for a world Karen is judging in the morning.
3. **The two-player click** (§16.4). If the Director would rather merge the lobby tonight on the
   one-player gate, the only split that achieves it is: **task 177a** = the `Match` seam (the switch,
   the two doors, the reader, `dismiss`, `unassign`) alone, with its own two-player run; **task 177**
   = everything else, which touches no `TWO_PLAYER_PATHS` file. That costs an extra round and an
   extra PR and it is a scope call, not an engineering one. **The design is buildable as one task
   either way.**
4. **This row takes the last of the twelve flag slots** (§11). A thirteenth flag is the Director's
   call; `DRIVE_BOTS`, `BOAR_MODEL`, `BOAR_BEHAVIOUR`, `RIFLE`, `FIRST_PERSON` and `COINS` are all
   candidates for retirement.
5. **The `docs/design/map-generator.md` §2.2 amendment** (§3.1) is the Architect's edit, not the
   Builder's. Queue it, or ask for it in this run's next Architect call.

---

<!-- Added by task 193 from `docs/design/drive-places.md` section 16: the Architect's
own words for what shipped and was never written down. The Learning Agent, 2026-10-17: no
Architect run for three days and `docs/design/` is behind the code. -->

### 9.3 The gathering yard (task 191), and the trees that stand on real ground (tasks 196, 199)

**Karen, 2026-10-15 ~17:20:** *"next is when hunt over everyone is in clean ground no grass
firstable / second it could be next to cabin"*. After playing it, 2026-10-16: *"yes it works / I
shoot and cna see them there"* (`PLAYTEST.md`).

The end-of-drive gathering happens in the lodge's own clean yard **west of the lodge**, not out in
the forest grass. The yard is **one row** in `Lobby.CONFIG.FIELD.PADS` named `Gather` (56 × 56,
`Enum.Material.Ground`), found **by name** by `Lobby.gatherPad(cfg)`, and **four** things read that
one row: `Field.fill` lays the blade-free block from it (it already loops the list, so this is a row
and not a code path), `Lobby.gatherSpotFor` reads its centre, `Build.treeLine` keeps a tree off it,
and `lobby.spec` bounds the drive's whole scene inside it. **Nothing recomputes the rectangle.**

**The world gets first say and the drive's old rule is the fallback, not a replacement.**
`Lobby.gatherSpot()` (server) is handed to the drive as `world.gatherSpot`;
`Match.gatherSpotOf(reader, markers, cfg)` is pure in the reader and answers
`(spot, facing, fromWorld)`; `Match.gatherSpotFor` — `SCENE.GATHER_BEHIND_STUDS` behind the middle
stand — is **unchanged** and still answers when the world names nowhere. The pattern is ioquake3's
`FindIntermissionPoint` (GPL-2.0, nothing copied): the authored point first, `if ( !ent )` the
derived one. **The DEV place has no lobby at all** (`Lobby.ANCHORS` has no `map:v1` row), so the
harness's own world takes the fallback and `Match.stats().sceneWorldSpots` is 0 there — which is why
no feature flag was added.

**The spot's height is measured, never predicted.** `Lobby.gatherSpotFor` asks the injected
`groundAt` **once**, at the yard's own centre, and falls back to the anchor's Y only when the reader
is absent, answers a non-number, or throws. `Field.fill`'s surface is voxelised and is **not** the
nominal shelf: that is how four trucks got their tyres 0.752 studs underground (task 186). Live, the
server printed `(2800, 150, −2940)` against a shelf of 149.2. The yard was also moved **two studs
east onto the 4-stud voxel grid** after the first build came back 623 `Ground` and 2 `Grass`; it
re-measured 625/625 `Ground`, spread 0.00.

**The whole scene fits**: `Scene.cornerReachFor(SCENE.MAX_ANIMALS, Match.CONFIG)` is 23.5 studs, so
the worst-case square is 47 studs inside a 56-stud yard, and the spec asks `Match.Scene` for that
number rather than copying it.

**Where a tree meets the ground is no longer the lobby's own arithmetic.** Task 196 found that a
birch's root flare is a set of arched claws, so seating the claw **tips** leaves daylight under every
arch; task 199 found the same defect in `Workspace.OurForest` (Karen: *"look at the trees wtf"*).
The rule — the trunk/root **junction** at or below the **lowest** ground anywhere under the trunk's
own footprint — now lives in **`src/shared/TreeGround`**, which `Lobby.Build` requires from
`treePlan` and `settleOnGround`, and which **`tools/forest_ground.py` reads from this file** and
injects into the Luau it sends to Karen's Forest Test (a different place, which Rojo does not serve).
There is one copy of the arithmetic and the tool carries it rather than restating it.
`TreeGround.flareFootprint` is deliberately **not** called by `Lobby.Build`, and that is a
measurement and not a preference: `lobby.spec`'s *"buries each tree's root claws"* case failed with
it, because the lobby's footprint is already the union of the parts that reach the ground and on its
two templates those **are** the flare.
`Lobby.Build` is still **the one writer of every part in `Workspace.Lobby`**, and
`src/server/Places` (task 193) borrows its shape and not its code for that reason.

**§12.2, `ServerScriptService.Lobby` — add:**
`Lobby.gatherSpot(): (Vector3?, Vector3?)` — the yard's measured centre and `CONFIG.GATHER.FACING`,
handed to the drive as `world.gatherSpot`.
**§12.1, `ReplicatedStorage.Lobby` — add:** `Lobby.gatherPad(cfg)`,
`Lobby.gatherSpotFor(anchor, cfg, groundAt?)`, `Lobby.CONFIG.GATHER`, and the `Gather` row in
`CONFIG.FIELD.PADS`.
**§13 — add the row:** *where the drive gathers → `src/shared/Lobby` states it, `ServerScriptService.Lobby`
measures it, `ServerScriptService.Match` decides between it and its own fallback.*
