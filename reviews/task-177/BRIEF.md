# Task 177 BRIEF: the lobby -- a hunting lodge in the fields, and a truck that takes you to the hunt

Input to `tools/architect.sh design lobby --task 177`. Read this first; it overrides anything older
in `docs/`, `TASKS.md` or an earlier design (`docs/ARCHITECT_PROMPT.md`).

Research note: `docs/research/2026-10-13-lobby-and-the-truck.md`. It is the reasoning; this is the
decision list.

---

## 0. What the task is, and what it is not

**THIS TASK = the lobby WORLD and the FLOW.** The SHOP inside the lodge is **task 178**: the
interior gets an empty counter and a placeholder sign and nothing else.

**Karen, 2026-10-13 ~19:20, verbatim:** *"I think after this fixes we need to focus on lobby /
Hunting house where inside can shop things / outside is fields and forrest so house is in fields next
to forrest"*.

Her two choices, asked one by one:

* the house: **"Wooden log lodge"** -- logs, porch, antlers over the door, warm inside;
* starting a hunt: **"Walk to a car"** -- a hunting truck parked by the lodge. **First version: step
  into a marked spot beside it. The car RIDE comes later.**

Her design doc (*Driven Hunt v1*): *"Everyone starts in lobby / There are houses where can buy
weapons, License, Gear, Goods / There is place to join game / ... After you select a game you sit in
car and drive to position - Loading"*.

**Karen is asleep until ~09:00 and judges the look in the morning.** No question is asked of her in
this task: where a choice was open, the Director's instruction was *"pick the simpler, Karen
judges"*.

---

## 1. Decisions already taken. The design does not re-open these.

**(a) ONE PLACE. The lobby is an AREA of the world, not a second place.** No `TeleportService`, no
`ReserveServer`. Reason, in full, in note section 2: the harness drives ONE Studio on ONE place
(`FAIL Studio has the DEV place open` is a real check), so a two-place design puts the most
important transition in the game where no test can reach it. The capacity argument for two places
starts to pay at hundreds of concurrent players; Karen plays solo with bots. A lobby AREA can become
a lobby PLACE later without the game code changing shape.

**(b) THE LOBBY IS A NEW OWNER, `Lobby`.** It owns: the field, the lodge, the truck, the marked
spot, the lobby spawn, and **who has asked to hunt**. It is the ONE writer of its own folder in
`Workspace` and of the terrain rectangle it flattens, and it writes nothing else.

**(c) `Match` KEEPS THE DRIVE AND IS HANDED THE ROSTER INSTEAD OF TAKING IT.** The seam is the one
`Match` already has five times over ("the world provides; the owner decides" --
`world.markers`, `world.placement`, `world.boars`, `world.bots`, `world.economy`):

* a **world switch** that stops `watchPlayer` dispatching `join` by itself. A player who joins the
  server is still REGISTERED (name, score row, character watch); he is simply not a participant.
* a door the lobby calls to **enrol** one player (dispatches today's `join`, and everything after it
  is today's code: `Waiting` -> `Assigning` once `MIN_PLAYERS` is met and the markers are complete).
* a door the lobby calls to **clear the roster** with no feed lines, so the drive falls back to
  `Waiting` through `Phase`'s existing door (`enoughPlayers` false at the `Scoring` exit ->
  `enterWaiting`, which already takes the scene down and frees everybody).

The exact names and shapes are the Architect's. The boundary is not: **`Lobby` never writes a team,
a character's position, its clothes or its gun, and `Match` never reads the lobby's geometry.**

**(d) "NO TEAM, NO GUN, NO OUTFIT IN THE LOBBY" IS NOT NEW CODE.** It is what *not being in the
drive* already means: `Objective.text` returns `""` for a player with no team,
`Match.mayCarryWeapon` (the arming policy `Weapon.setArmingPolicy` is handed) refuses a player with
no assignment, and `Body.dress` is only called by the drive's own placement. The design must SAY
this rather than add a second mechanism for it. The lobby look is the player's ordinary avatar: no
outfit write at all.

**(e) END OF A DRIVE -> BACK TO THE LOBBY. One drive per trip.** This is the Director's pick of the
simpler (the dispatch: *"say which and ask nothing: pick the simpler, Karen judges"*). It needs no
new phase and no new rule: the lobby watches `Match.PhaseChanged`, clears the roster when the
results scene goes up, and puts everybody back at the lodge when the drive reaches `Waiting`. It
also matches Karen's own doc. The alternative -- straight into the next drive -- would require
deciding what a player who wants to go shopping does with a countdown already running, and she has
not been asked that.

**(f) 4 + 4 IS UNCHANGED.** `MIN_PLAYERS` real players start the drive; `Bots` fills every other
slot (task 161, `DRIVE_BOTS`). **Nothing in the bot path may learn about the lobby.** One real
player who steps into the spot therefore gets a full 4 + 4 drive, which is what Karen plays.

**(g) THE MARKED SPOT IS A CIRCLE TESTED PER TICK, NOT `Touched` AND NOT A `ProximityPrompt`.**
Pattern: Valve's `trigger_multiple` (presence, not collision) read as arithmetic -- the shape
`ForestTest.withinStand` already has, and **pure**, so the whole join rule is drivable in a spec
with hand-written positions and no character. `Touched` cannot answer "has he left" reliably and a
prompt is a button Karen did not ask for. Note section 3.

**(h) THE LODGE IS A PARTS BUILD.** Not the Creator Store (`InsertService:LoadAsset` needs a hand
check for scripts, an `assets/uploads.json` row and **the text of Karen's OK**) and not Meshy (brief,
run, preview OK, upload -- all of it hers or the Asset agent's). Note section 4. The geometry lives
behind one module with a config table so a mesh can replace it later without touching the flow.

**(i) THE FIELD IS FLATTENED WITH TERRAIN AT RUNTIME, INSIDE ONE RECTANGLE.**
`Terrain:FillBlock` -- grass for the shelf, air for the hill above it. A slab of parts was refused:
on the measured 16-stud spread its downhill edge floats 16 studs, which is this project's named
failure mode (measured right, looks wrong). The write is **runtime only** (so it cannot dirty the
Edit-mode DataModel the harness compares -- the property `Workspace.ForestMarkers`,
`Workspace.Boars` and `Workspace.WeaponEffects` already rely on) and **never outside the rectangle**.
`tools/mapgen.py` writes DEV's terrain in EDIT mode and must stay the only thing that does.

**(j) IT IS BORN BEHIND A FLAG, OFF, AND THE FOREST TEST TURNS IT ON AT ITS COMPOSITION ROOT.**
`src/shared/Flags/init.luau` row, `default = false`, `expires` within 21 days, read ONCE at its
owner's boundary and passed inward -- the only permitted shape. `ForestTestBoot` turns it on the way
it turns `BOAR_MODEL`, `PACE`, `MOVE` and `LINE` on: through the world's own config, not through a
live `DHFlag_` attribute. **The DEV place keeps the declared default, so the harness must read
exactly what it read at `102fbe9`.** Both branches must be reachable **by parameter** as well as by
flag (CLAUDE.md), or no spec can see the lobby at all while the row sits at `false`.

**(k) THE SCREEN IS TASK 165'S AND STAYS ITS.** `Hud.Objective` is *"THE ONE WRITER of the objective
LINE and of the WAYPOINT chevron"*. The lobby is **one more row in its pure table**: no team, phase
`Waiting` -> *"walk to the truck to start a hunt"*; during the countdown -> *"leaving for the hunt in
%d"*; the chevron's target is the truck spot with a fourth word beside `STAND`, `LINE` and `ROAD`.
The target must not be a second definition of where the truck is: the lobby's own shared module
answers it from the named part the server built, and `Objective.targetFor` keeps taking the world's
geometry as an argument and inventing nothing.

**(l) THE PLACE THAT MATTERS IS THE FOREST TEST** (`130094961655666`) -- where Karen plays. DEV gets
the lobby only if it is cheap and safe, and the default answer is **no** (the flag is off there).

---

## 2. Measured facts the design may rely on

Taken in the Forest Test place in **Edit** mode, 2026-10-13, through StudioMCP -- not guessed:

* `Workspace` children: `Ambience`(Sound), `Session`(Folder, 3293 descendants), `Foliage`(Folder,
  empty), `Session`(Folder, 264), **`OurForest`(Folder, 24191)**, `Terrain`,
  **`ForestRoadSpawn`(SpawnLocation)**, `Camera`.
* `OurForest`: **9,901 BaseParts, x 2229..3833, z -2896..-1297.** There is no forest south of
  z = -2896.
* A raycast grid over fifteen 160 x 160 footprints south of that edge: **terrain under every sample,
  zero non-terrain obstacles**, ground-height spread 16..44 studs. Flattest centre **(2850, -2950),
  spread 16**; (3150, -2950) spread 18.
* The drive's own geometry in this place: road at `ForestTest.CENTRE` (3030, 138, -2097) with a sine
  of amplitude 30 over a 440-stud wavelength, nine stands 150 apart, beaters 700 studs NORTH, boars
  exiting at `EXIT_Z` = -2377. **The lobby at (2850, -2950) is ~570 studs south of the road and
  ~570 south of the boars' exit: it cannot interact with the drive.**

So: the lobby goes in open measured-flat ground about 54 studs south of the forest edge, with the
forest filling the northern view -- which is Karen's *"house is in fields next to forrest"*.

## 3. Numeric targets (note section 9)

| What | Target |
|---|---|
| lobby centre, Forest Test | (2850, -2950) |
| field shelf | 220 x 220 studs, grass, flat |
| truck spot radius | 8 studs |
| countdown to leave | 5 s |
| lodge | about 40 x 28 studs, 18-stud ridge |
| lobby part budget | <= 400 parts |
| build time at boot | <= 1 s |
| DEV harness | 0 changed checks against `102fbe9` |

## 4. What the design must contain

1. **Where the lobby lives** -- the one place, the area, its anchor, and how the anchor is stated
   per world (the Forest Test's centre above; DEV: none).
2. **The owner table row for `Lobby`**, and the amendment to the *System owners* table in
   `GAME_DESIGN.md`.
3. **Who owns the lobby <-> drive transition**, as an interface: the world switch and the two doors
   on `Match`, named, with the direction of every call written down. In particular: **what stops
   `Lobby` from being a second writer of a team, a position, clothes or a gun**, and **what stops
   `Match` from reading the lobby's geometry.**
4. **What a player IS in the lobby**, derived from (d) rather than added.
5. **The join rule as pure arithmetic**: inside/outside the circle, the countdown, what cancels it,
   and what happens if two players step in at once.
6. **The end-of-drive flow** per (e), as a sequence of existing phases and effects, naming which
   effect frees the hold and which takes the scene down.
7. **The geometry**, as a config table: the field rectangle and its two terrain calls, the lodge
   (porch, door you can walk through, antlers over the door, a warm interior with fireplace light, a
   table, the empty shop counter and placeholder sign for 178), the truck, the dirt track, and the
   glowing ring + sign at the spot (consistent with 165's UI language).
8. **The spawn**: how a player arrives at the lodge rather than at `ForestRoadSpawn`, and how he gets
   back there after a drive -- without `Lobby` becoming a second writer of where a character stands.
9. **The flag row** per (j), and how both branches are reachable by parameter.
10. **The screen** per (k): the rows added to `Objective.CONFIG.TEXT`, the fourth word, and where the
    truck's position comes from. Plus: **what `MapUi` does in the lobby** -- it must hide cleanly,
    not half-draw a drive that does not exist.
11. **What is testable without a character**, spec by spec, so the gate is one-player (the dispatch
    expects `TWO_PLAYER_PATHS` to be touched -- if the design can keep the drive's own two-player
    paths untouched, say so, and if it cannot, say exactly which file and why).

## 5. Open decisions the design MUST close (it may not leave them to the Builder)

1. The exact names and signatures of the `Match` seam (the world switch and the two doors).
2. Whether the lobby's per-tick presence scan is its own `Heartbeat` or is driven by something that
   already ticks -- and if it is its own, why a second clock is right here.
3. Where the lobby's data lives (`src/shared/Lobby/` for the numbers and the client-side reader vs
   server-only), given that the client must read the truck spot for the chevron.
4. Whether `Lobby` or `Match.Body` performs the respawn back at the lodge, and how that does not
   become a second writer of a character's position.
