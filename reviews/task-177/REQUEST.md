# Task 177 review request

Task: 177
Round: 2
Base: 102fbe9 (`main`, #160 merged -- task 176)
Code commit: 43786a31516109d4ee5d25dc5075e776c96fdf43

Harness, the clean tree, TWICE at the code commit, each logged
(`.agent-logs/task177-r3-test1.log`, `-r3-test2.log`):

```
[harness] PASS: 33/33 checks @ 09b693281bd0c42e7f0a78976ba80487b89ee959 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 09b693281bd0c42e7f0a78976ba80487b89ee959 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 43786a31516109d4ee5d25dc5075e776c96fdf43 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 43786a31516109d4ee5d25dc5075e776c96fdf43 (clean tree)
```

DIRECTOR NOTE: the last two lines are the Director's at the head `43786a3` (only paperwork after `09b6932`).

**The `[harness2]` line is the Director's and is not here yet.** `src/server/Match/` and two of its
specs are in `TWO_PLAYER_PATHS`, and `tools/studio_mcp.py` is in the diff, so a `--scope auto` run
resolves to `scope=all` -- full evidence, which asks for the two-player line; `run_test2` cannot
start that test itself. **It PASSED at the previous head** -- `[harness2] PASS: 35/35 checks @
a5a212e5283ff60d0ee1ca0bad992addcd68bdac (clean tree)`, the Director's own run -- and this round
changed code after it, so it is asked for again rather than carried over. `ESCALATE.md` carries
**`NEEDS TEST2 177 09b6932`** with the exact clicks.

## Round 1's three findings, each fixed at its owner

**1. `applyUnassign` resurrected a departed player as a ghost board row.** `Score.setTeam` goes
through `mutable`, which for a userId with no row returns `blankRow(userId, name or
tostring(userId))` -- so clearing the team of somebody the board has never seen CREATES him. The
effect's list outlives the player: `Phase.enterAssigning` builds it from `previousAssignment`, and
the `leave` branch clears `participants` and `assignment` and not that. **Fix:**
`Match.unassignTargets(userIds, known)` -- pure and exported, the `Match.botSlotsFor` /
`Match.quickSpawnFor` shape -- filters the list to the ids this owner still knows (`names`, which
`Match.forget` clears BEFORE the `leave` it dispatches), and `applyUnassign` iterates that.
**Verify:** `Match.unassignTargets` and `applyUnassign` in `src/server/Match/init.luau`; the new
`match_live.spec` case *"never resurrects a departed player as a ghost row on the board"*, which
asserts BOTH halves -- that `Score.setTeam(Score.new(), -4242, nil)` really does put a row named
`"-4242"` with 0 points and no `left` mark on `Score.leaderboard` (the hazard, unchanged), and that
the filter drops exactly the unknown id and keeps the order (the guard).
**What is NOT claimed:** the end-to-end path needs two players and a disconnect inside `Scoring`, and
no one-player DEV spec can reach it. The guard is asserted; the journey is the two-player run's.

**2. `map_ui.spec`'s lobby-vs-bounds case asserted nothing where it ran.** It opened
`if Map.EXPECTED_WORLD ~= "forest-test" then return end`, and that is `"map:v1"` in the DEV place --
the only place the harness runs -- so claim 10 below rested on an assertion nothing executed.
**Fix:** the gate is gone and the world is named (`MapUi.geometryFor("forest-test", data, Map)`),
which is what the sibling case two `describe`s up already does; `geometryFor` branches on its `world`
ARGUMENT and `ReplicatedStorage.ForestTest` is in every place. **Verify:** the case now runs in DEV
and can fail there -- it is inside the 1308 the server/client suites report.

**3. The porch index was unbounded and the per-player tables were never reclaimed.**
`indexFor` only ever counted up, one per player who had ever joined, and `Lobby.spawnCFrame` offset
by `floor((index + 1) / 2) * SPREAD_STUDS` with no bound: slot 37 is 114 studs off the middle,
outside `FIELD.SPAN_STUDS`'s half-span of 110 -- so `Join.insideField` answers FALSE for the man
standing exactly where `world.place` put him, `needsReturn` answers true, and the lobby re-places him
at the same off-shelf point every cooldown for ever. **Fix:** `SPAWN.SLOTS = 7` and the index WRAPS
(worst case 3 x 6 = 18 studs, inside the lodge's own 40-stud front), and `Lobby.forget` is wired to
`PlayerRemoving` in `ForestTestBoot` beside `ForestTest.clearPick` / `clearRequest`, so `entries`,
`returnedAt`, `spawnIndex` and `touched` are reclaimed and `touched` stops holding a departed
`Player` instance. **Verify:** `Lobby.spawnCFrame` and `SPAWN.SLOTS`; the new `lobby.spec` case
*"can never put a player off the lobby's own field, however high the index climbs"*, which walks
indices 0..200 asserting `Join.insideField` and the porch half-width, and asserts the wrap --
**it fails on the old code**; and the `PlayerRemoving` handler in `ForestTestBoot`.

## Round 1's notes

Fixed: **note 1** (this file's stale `[harness2]` paragraphs are gone), **note 3** (the leave
deadline is written once on the `nil -> COUNTING` edge instead of ~50 times per walk-in, asserted in
`lobby_live.spec`), **note 4** (the boot prints the lobby's own numbers -- `shelfY`, `parts`,
`fillCalls`, `grassCalls`, `buildMs` -- which `docs/design/lobby.md` section 18 item 2 asks for),
**note 5** (`MapGen.Ground`'s palette paragraph carries the qualifier its header already gained),
**note 6** (`isHeld` is a REQUIRED door, in `Lobby.start`'s list and in `lobby_live.spec`'s
missing-door loop).
Queued, not fixed: **note 2** -- the collision set is wider than `docs/design/lobby.md` 9.2 and 16.1
state (`Bed`, `Cab`, `Bonnet`, `Fireplace`, `Counter`, `TableLeg*`, `DoorPost*`, `SignPost`, `Gable*`
are solid). The Reviewer calls it defensible and says the DESIGN should be amended, which is the
Architect's lane: `TASKS.md` 177a(e).

## What changed

**The lobby.** A player who joins the server now stands at a log lodge in open fields beside the
forest, with no team, no gun and no outfit, and starts a hunt by standing for five seconds in the
marked circle beside the hunting truck. At the end of a drive he is back at the lodge. It is ONE
PLACE -- an area of the world with its own neutral spawn -- and it is born behind the flag `LOBBY`
(OFF), turned on by `ForestTestBoot`'s world config, so the DEV place where the harness runs has no
anchor row and no lobby at all.

New: `src/shared/Lobby/`, `src/server/Lobby/` (`init`, `Join`, `Field`, `Build`),
`tests/server/lobby.spec.luau`, `tests/server/lobby_live.spec.luau`, `docs/design/lobby.md`,
`docs/research/2026-10-13-lobby-and-the-truck.md`.
Changed: `Match` (`init`, `Phase`), `ForestTestBoot`, `Hud` (`init`, `Objective`, `MapUi`),
`Flags`, `MapGen.Ground` (header only), four specs, `tools/studio_mcp.py` (scope rows),
`GAME_DESIGN.md`, `TASKS.md`.

## Claims, and how to verify each

1. **`Lobby` never writes a team, a character's position, clothes or a tool.** `src/server/Lobby/`
   has no `setTeam`, no `dress`, no `Weapon` and no `Horn`, and requires neither `Match` nor
   `Match.Body`; the one character move it asks for is `world.place`, which `ForestTestBoot` binds to
   `Match.Body.place`. **Verify:** grep `src/server/Lobby/` for `Match`, `Body`, `Weapon`, `Horn`,
   `setTeam`, `dress`, `Team` -- none; read `Lobby.stepPlayer` and the `world` table in `Lobby.start`.
2. **`Match` never learns that a lobby exists.** The world table gains ONE boolean (`world.enrol`);
   `Match.WORLD_OVERRIDABLE` is untouched. **Verify:** `grep -rn "Lobby" src/server/Match/` answers
   nothing.
3. **A world that injects no `enrol` is bit-identical to before this task.** `autoEnrol =
   world.enrol ~= false` -- the idiom `world.remotes` and `world.heartbeat` already use -- and
   `Match.stop` puts it back to `true`. **Verify:** `Match.start` / `Match.stop` / `watchPlayer` in
   `src/server/Match/init.luau`; the four new cases in `tests/server/match_live.spec.luau`
   ("the drive's own doors"), which assert ON PRODUCTION in the DEV place that the one live player is
   a participant, that `enrol` is idempotent, that an unregistered player is refused and that
   `dismissAll` is refused and empties nothing.
4. **"No team, no gun, no outfit in the lobby" is not new code.** It is what not being in the drive
   already means. **Verify:** `Objective.text`'s first clause, `Match.mayCarryWeapon`,
   `Horn.carriesFor(on, nil)`, `Body.outfitFor(nil, config)`.
5. **`unassign` closes a hole that was invisible before this task.** `Body.setTeam` is the one writer
   of `Player.Team` and its only caller was the `assignTeams` effect; `Phase.enterWaiting` emits no
   such effect, so NOTHING in this repo ever set a team back to nil -- unreachable while
   `MIN_PLAYERS` is 1 and everybody is a participant, and the normal end of every drive with a lobby.
   **Verify:** `applyUnassign` in `src/server/Match/init.luau`, the two emit sites in
   `Phase.enterWaiting` / `Phase.enterAssigning`, and the five new cases in
   `tests/server/match_phase.spec.luau` ("the lobby's two additions").
   **It reads BOTH rosters, and that is a DELTA from the design's section 4.4 snippet**, which reads
   `state.assignment` alone: a `dismiss` has already emptied that table by the time this door is
   reached -- that is what makes `enoughPlayers` false and this door the one taken -- while the
   players still carry `Player.Team`. The gate found it (`unassign 0`); the union is what the
   committed code does and `match_phase.spec` asserts both shapes.
6. **`dismiss` emits no feed line and touches no team, no board and no hold.** **Verify:** the
   `dismiss` branch in `Phase.step`; the first new `match_phase` case asserts `countKind(effects,
   "feed") == 0` and one broadcast; `applyFree(nil)` iterates `heldStill`, not `participants`.
7. **The join rule is pure.** `Lobby.Join` has no Instance, no service and no clock: `within`,
   `insideField`, `decide` and `needsReturn`. **Verify:** `tests/server/lobby.spec.luau` drives the
   circle at 7.9 / 8.0 / 8.1 studs and 50 studs up, the countdown at 4.9 / 5.0, the cancel, the
   re-entry's new clock, all eight `needsReturn` combinations and `inField = nil`.
8. **`Field` writes terrain only inside `CONFIG.FIELD`, and only through an argument.** Three blocks
   -- grass, a `Ground` pad under the buildings, then air -- and `terrain` is a parameter, so no spec
   in the DEV place can write DEV's terrain. **Verify:** `Field.fill` and the corner assertions in
   `lobby.spec` ("writes nothing outside the field's own rectangle"); the fake-terrain case asserts
   the order and that the real `Terrain` is never touched. `MapGen.Ground`'s header and
   `GAME_DESIGN.md`'s generated-map row carry the amended sole-writer sentence; **the
   `docs/design/map-generator.md` edit is the Architect's and is queued as `TASKS.md` 177a(a)**.
9. **The screen is task 165's and stays its.** Two rows in `Objective.CONFIG.TEXT`, a fourth word,
   and one optional argument on three pure functions. **Verify:** `Objective.text` /
   `targetFor` / `lineVisible`; the five new `hud_clarity.spec` cases, including *"still says nothing
   with no team when the world has no lobby"* (the DEV answer, unchanged) and the `TextFits` sweep,
   which now measures the lobby's two sentences at 400 x 800 as well. **The sweep's proxy bound goes
   32 -> 33 characters** and the case says why: the design's own target table puts `TextFits` first,
   and the lobby's line is the Director's own wording at 33 characters, which passes.
10. **The minimap hides outside the world the map states, and the full map does not.**
    `MapUi.withinBounds` is pure and names no lobby; `minimapVisible`'s fifth argument defaults to
    false, so every existing caller and spec case is bit-identical. **Verify:** the three new
    `map_ui.spec` cases, one of which reads `Lobby.anchorFor` and the Forest Test geometry and
    asserts the lobby really is outside those bounds.

## Measured live, in the Forest Test (the place Karen plays)

A Play session at the code commit, through StudioMCP:

* `[lobby] on: the drive is entered from the marked circle beside the truck`.
* The lobby built: **106 parts, 50 collidable, 2 SurfaceGuis, 1 PointLight, 0 scripts**, `TruckSpot`
  at (2866, 149, -2932) = anchor + `SPOT.OFFSET`, shelf **measured** at ~149.5 and never typed.
* A player joining stands at **(2854, 153, -2933)** -- the porch -- with `Team = none` and
  `RespawnLocation = LodgeSpawn`.
* Standing in the circle for five seconds: `Team = Shooters`, `RespawnLocation` cleared,
  character at **(3030, 143, -2097)** = `ForestTest.CENTRE`, stand 5 on the road, and
  `[report] drive 1 opened (300s windows)`.
* At the end of that drive: `Team = none`, `RespawnLocation = LodgeSpawn`, character back at
  **(2849, 153, -2934)** -- the lodge.
* `smoke.sh 90` on a fresh session: `stacks=0 errorLines=0 waves=5`, worst concurrent boar sounds 1.
  It reports `FAIL: gun not in hand`, **and that is the lobby working**: a player by the lodge has no
  gun. What `smoke.sh` should check instead is in the report and in `ESCALATE.md`.

Two screenshots were taken and inspected: `.screenshots/177-lodge-outside.png` (the lodge, its roof,
the antlers over the door, the `STAND HERE TO HUNT` sign, the `TRUCK 14 m` chevron, the objective
line *"walk to the truck to start a hunt"*, the drive bar `DRIVE 0 WAITING players`, and **no
minimap**) and `.screenshots/177-lodge-inside.png` (the fireplace lit, the log walls warm, the plank
floor, the table and the shop sign).

11. **The two-player run's two spec failures were NOT about teams, roles or who holds what, and
    there is no game bug: a shooter did not hold a horn.** Both failing clients failed the SAME case,
    `camera_client.spec`'s horn case, which **injects both handles itself** through
    `Viewmodel.setSource` -- a horn's Handle from its own `hornTool()`, then a gun's `MeshPart` it
    creates on the spot -- and **never reads the player's real Tool**. The drawn model simply never
    swapped. **Verify:** read the case; `Viewmodel.update`'s own dispatch is
    `local tool = handle and handle.Parent` / `if tool ~= nil and tool:IsA("Tool") then
    HeldTool.kindOf(tool) else HeldTool.WEAPON`, so the spec's parentless gun Handle takes the WEAPON
    branch by construction. The log agrees on the game: `[harness2] client teams: 5b779e64=Drivers,
    ebc9caf4=Shooters`, the server suite `1306 passed, 0 failed`, the shooter's readout
    `[*]x SLUG 24`, and the driver is the one with the horn.
    **The cause** is `Viewmodel.update`'s source throttle: it re-asks the source every quarter second
    once it holds a handle whose `Parent` is still there (task 133), and `lastSourceCheck` is a module
    local **shared with the live camera loop**, which calls `update` every frame and resets it. So the
    case's `task.wait(0.3)` guaranteed nothing and the frame cadence decided the outcome. **It is the
    first `test2` since task 176 added a second kind of viewmodel** -- 175 and 176 were both
    `test2` N/A -- so one player had been winning that race ever since.
    **The fix is at the owner:** `Viewmodel.setSource` drops `cachedHandle`, so a source swapped at
    runtime cannot leave the previous source's handle on screen for up to 250 ms. **The assertion is
    not weakened:** `Viewmodel.clear()` is still deliberately NOT called across the swap, so
    `builtKind` remains the only thing that can turn the horn's model into the gun's. The case now
    asserts the swap is drawn on **update 1 in both directions** and notes it, so a regression says so
    instead of flaking: `camera_client: a source swap is drawn on update 1 (to the gun) and 1 (back to
    the horn)`, in both logged runs.

## What I could not verify

* **The two-player run AT THIS COMMIT.** It PASSED at the previous head (`[harness2] PASS: 35/35 @
  a5a212e`, the Director's run), and this round changed code after it, so nothing here claims it
  still passes. It needs a human click; `ESCALATE.md`, `NEEDS TEST2 177 09b6932`.
* **The ghost row end to end.** Finding 1's guard is asserted; the journey that produced it -- two
  players, one disconnecting inside `Scoring`, the other holding the server in `Assigning` -- is not
  reachable from a one-player DEV spec and is the two-player run's to see.
* **The `enrol = false` branch of `watchPlayer` has no DEV spec.** `Match` is a started singleton
  that `MatchBoot` owns and a spec cannot restart it under a running client suite
  (`match_live.spec`'s own first paragraph). It is evidenced LIVE in the Forest Test instead, by the
  measurements above: the player is in the world, not in the drive, and the drive stays in `Waiting`
  until he stands in the circle.
* **The look.** Karen judges it. The lodge reads DARK from outside in the wood's shade, the field's
  tall grass hides its lower courses, and the `STAND HERE TO HUNT` sign sits further left than it
  should. Every number is one row in `Lobby.CONFIG`.
* **Two `Stack Begin` entries appeared in a LONG unattended session**, both
  `ServerScriptService.Boar:3939: Boar runtime is at maxBoars` from `ForestTest.releaseLine`. It is
  the Forest Test's own 60-animal ceiling reached with nothing shot, on a schedule that is
  independent of the drive, and the fresh 90-second `smoke.sh` session had **zero**. Queued, not
  fixed here.
