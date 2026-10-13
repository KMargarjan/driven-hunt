# Task 177 review request

Task: 177
Round: 1
Base: 102fbe9 (`main`, #160 merged -- task 176)
Code commit: f625098c9c73947c55bd939d4a9a1232b80261e3

Harness, the clean tree, TWICE at the code commit:

```
[harness] PASS: 33/33 checks @ f625098c9c73947c55bd939d4a9a1232b80261e3 (clean tree) scope=all
[harness] PASS: 33/33 checks @ f625098c9c73947c55bd939d4a9a1232b80261e3 (clean tree) scope=all
```

**The `[harness2]` line is NOT here and the review cannot start without it.** `src/server/Match/`,
`tests/server/match_phase.spec.luau` and `tests/server/match_live.spec.luau` are all in
`TWO_PLAYER_PATHS`, and `tools/studio_mcp.py` is in the diff so a `--scope auto` run resolves to
`scope=all` -- full evidence, which asks for the two-player line. `run_test2` cannot start the test
itself (*"StudioMCP CANNOT start this test itself"*). `ESCALATE.md` carries the entry, headed
**`NEEDS KAREN` / `NEEDS TEST2 177 f625098`**, with the exact clicks.

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

## What I could not verify

* **The two-player run.** It needs a human click; see the top of this file and `ESCALATE.md`.
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
