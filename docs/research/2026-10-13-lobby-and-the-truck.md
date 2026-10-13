# The lobby: a hunting lodge in the fields, and a truck that takes you to the hunt

Task 177. Written before any code (rule 1). The decisions it reaches go into
`reviews/task-177/BRIEF.md` and then into the Architect's `docs/design/lobby.md`.

**Karen, 2026-10-13 ~19:20, verbatim:** *"I think after this fixes we need to focus on lobby /
Hunting house where inside can shop things / outside is fields and forrest so house is in fields next
to forrest"*.

Her answers, asked one by one:

* the house is a **"Wooden log lodge"** -- logs, a porch, antlers over the door, warm inside;
* a hunt starts by **"Walk to a car"** -- a hunting truck parked by the lodge. First version: step
  into a marked spot beside it. **The car RIDE comes later.**

Her design doc (*Driven Hunt v1*) says the same thing in the order it happens: *"Everyone starts in
lobby / There are houses where can buy weapons, License, Gear, Goods / There is place to join game /
... After you select a game you sit in car and drive to position - Loading"*.

**The shop inside the lodge is task 178.** This note covers the lobby WORLD and the FLOW only; the
interior gets an empty counter and a placeholder sign.

---

## 1. What the system must do

1. **A player who joins the server stands in the lobby**, not on a hunting stand: open fields beside
   the forest, with a log lodge and a truck. He has **no team, no gun, no outfit** -- he is not in a
   drive and the drive does not know about him.
2. **Walking into a marked spot by the truck joins the next hunt.** A short countdown
   (*"leaving for the hunt in 5..."*), then the drive's `Assigning` phase exactly as it is today.
   Stepping back out before the countdown ends cancels it.
3. **The drive fills to 4 + 4.** Every slot no real player takes is a bot (`DRIVE_BOTS`, task 161) --
   that machinery already exists and must not change.
4. **At the end of a drive the player is back in the lobby**, free to walk to the truck again. (The
   alternative -- straight into the next drive -- is what the code does today. Section 7 says why
   back-to-the-lobby is the simpler of the two *given* the lobby, and it is the Director's call to
   make without asking: Karen judges it in the morning.)
5. **The screen says what to do.** Task 165's objective line reads *"walk to the truck to start a
   hunt"* in the lobby, with the chevron on the truck spot; the map and the minimap either work
   there or hide cleanly, never half-draw a drive that does not exist.
6. **It must work in the place Karen actually plays**, "Driven Hunt Forest Test"
   (`130094961655666`), and it must not change what the harness sees in the DEV place.

### What it must NOT do

* It must not become a second writer of a character's position, its team, its clothes or its gun.
  Those have owners (`Match.Body`, `Match`, `Weapon`) and this project's named failure mode is two
  correct pieces of code disagreeing (`docs/PROJECT_CONTEXT.md`).
* It must not be reachable only through a flag at one of its two states: a flagged path has to be
  drivable by parameter too (CLAUDE.md, feature flags), or a spec cannot see both sides of it.
* It must not put a `Script`, `LocalScript` or `ModuleScript` anywhere Rojo does not own, and it must
  not leave anything in the Edit-mode DataModel the harness compares (CLAUDE.md, Layout).

---

## 2. The first question: one place, or two?

This is the decision the whole task hangs off, so it is first.

### 2a. Two places: a lobby place that teleports into a reserved game server

**Source: Roblox Creator Docs, "Teleporting between places"** --
<https://create.roblox.com/docs/projects/teleporting>, and the API pages it rests on:
`TeleportService:TeleportAsync` <https://create.roblox.com/docs/reference/engine/classes/TeleportService#TeleportAsync>,
`TeleportService:ReserveServer` <https://create.roblox.com/docs/reference/engine/classes/TeleportService#ReserveServer>,
`TeleportOptions` <https://create.roblox.com/docs/reference/engine/classes/TeleportOptions>.
*Licence:* the Roblox creator documentation is published under CC BY 4.0 (the
`Roblox/creator-docs` repository states it). *Maintenance:* first-party and current -- this is the
engine's own supported path, and `TeleportAsync` is the API that replaced the deprecated
`Teleport` / `TeleportToPrivateServer` pair.

**What it does well.** It is how every large Roblox round game with real matchmaking works, and the
reason is capacity: a lobby place can hold hundreds of players browsing shops while each match runs
in its own `ReserveServer` instance with exactly 8 people in it. Match state cannot leak between
rounds because the round's server is new. `TeleportOptions:SetTeleportData` carries the party across.

**What it does badly, here, today.**

* **It cannot be tested by this project's harness.** `tools/studio_mcp.py` drives ONE Studio on ONE
  place (`[harness] FAIL Studio has the DEV place open` is a real check), and `default.project.json`
  serves two place ids to two Studios -- a THIRD place means a third Studio, a third Connect click
  only Karen can make, and a test that spans two DataModels. The harness cannot follow a teleport.
* **Teleports fail, and the failure is the player's.** The docs' own guidance is to handle
  `TeleportService.TeleportInitFailed` and retry, because `ReserveServer` is a web call and
  `TeleportAsync` is rate-limited per player. A failed teleport in this design is a player stuck in
  the lobby with the hunt running without him -- a whole class of bug that does not exist in the
  one-place design.
* **Nothing in the game needs it yet.** Karen plays solo with bots. The capacity argument starts to
  pay at hundreds of concurrent players, and v1 is *"a couple of months"* away
  (`docs/PROJECT_CONTEXT.md`).
* **It is not a decision that has to be taken now.** A lobby AREA can later become a lobby PLACE
  without the game code changing shape, because the thing the drive needs is "a list of players who
  asked to hunt" either way. Taking it now spends the night's time box on teleport plumbing instead
  of on the lodge Karen wants to look at in the morning.

**Unreal says the same thing about the risk.** Unreal Engine's equivalent is `ServerTravel` between
levels, and the engine ships a whole second mechanism -- *seamless travel* -- specifically because
the travel itself drops players
(<https://dev.epicgames.com/documentation/en-us/unreal-engine/travelling-in-multiplayer-in-unreal-engine>;
*licence:* Epic's proprietary documentation licence, *maintenance:* current). The lesson borrowed is
not "never travel", it is **the transition is the dangerous part, so do not build one before you
need it**.

### 2b. One place: the lobby is an AREA of the world the drive already runs in

**Source: Roblox Creator Docs, `SpawnLocation`** --
<https://create.roblox.com/docs/reference/engine/classes/SpawnLocation> -- and
**`Player.RespawnLocation`** --
<https://create.roblox.com/docs/reference/engine/classes/Player#RespawnLocation>.
*Licence:* CC BY 4.0 as above. *Maintenance:* first-party, current.

This is the engine's own lobby mechanism and it is older than teleporting: a `SpawnLocation` with
`Neutral = true` is the lobby spawn, team-coloured ones are the arena, and `Player.RespawnLocation`
overrides the choice **per player** so one server can hold both at once. `AllowTeamChangeOnTouch` is
the engine's own "touch this pad to join that side" -- which is, exactly, Karen's marked spot.

**What it does well.** One DataModel: the harness can see the lobby, the truck spot, the drive and
the results in one run, and a spec can drive the whole flow with no teleport and no second Studio.
No web call in the path a player walks. The lodge is visible from the forest and the forest from the
lodge, which is the picture Karen asked for -- *"house is in fields next to forrest"* -- and which a
separate place cannot show at all.

**What it does badly.** One server holds the lobby crowd and the match, so it does not scale to a
browsing lobby of hundreds; a 4+4 drive and a dozen idlers share one physics step. Lobby and match
state live in the same process, so an owner boundary is the only thing keeping them apart -- there
is no server restart to wipe a leak. Both are acceptable now and neither is hidden: section 9 says
what would make us move.

### 2c. The pattern adopted

**ONE PLACE. The lobby is an area of the world, with its own neutral spawn, and the drive is
entered by opting in rather than by travelling.** Chosen for the harness above all: this project's
rule is that a claim is proved by a test the player's path actually runs through (rule 6), and the
two-place design puts the most important transition in the game somewhere no test can reach.

**Borrowed, not invented** (rule 2): the mechanism is `SpawnLocation` + `Player.RespawnLocation`
exactly as the engine documents them, and the opt-in volume is the pattern below.

---

## 3. The marked spot: how "walk to a car" is read

Karen chose *"Walk to a car"*, and *"step into a marked spot by the truck"* for the first version.
Three ways to read a player standing somewhere:

**3a. A touch event on a part.** `BasePart.Touched`
(<https://create.roblox.com/docs/reference/engine/classes/BasePart#Touched>, CC BY 4.0, current).
Good: one line. Bad: `Touched` is a physics event -- it fires on contact, not on presence, so a
player who stands perfectly still inside the ring after one touch generates nothing, and
`TouchEnded` is famously unreliable for "has he left". A countdown that must cancel when he walks
out cannot be built on it.

**3b. A `ProximityPrompt`.** <https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt>
(CC BY 4.0, current). The engine's own "hold E to use this object", with its own UI, its own
`HoldDuration` and a server-side `Triggered` event. Good: it is first-party, it draws itself, and
the hold IS the countdown. Bad: it is a BUTTON, and Karen did not ask for a button -- she asked to
walk to the car. It also adds an input binding and a piece of UI this project does not own
(`docs/design/hud-clarity.md` owns the screen).

**3c. A volume tested every tick -- the adopted pattern.**
**Source: Valve Developer Community, `trigger_multiple`** --
<https://developer.valvesoftware.com/wiki/Trigger_multiple>. *Licence:* CC BY-SA (the VDC wiki's own
licence). *Maintenance:* community wiki, actively edited; the entity itself ships in every Source
game. The pattern is a brush volume that fires `OnStartTouch` / `OnEndTouch` and, crucially, knows
who is INSIDE it -- presence, not collision. Half-Life's whole level flow is built on it.

This repo has already borrowed from exactly this family and says so in code:
`src/server/ForestTest/Markers.luau` cites Valve's `info_player_terrorist` and Unreal's
`AGameModeBase::FindPlayerStart` for "the world places the entities the game mode queries". A
trigger volume is the same idea one step on: **the world states a place, and standing in it is the
request**.

In Roblox the presence test is arithmetic, not an event: the distance from the character's root to
the spot's centre, compared against a radius, once per tick on the server. That is the shape
`ForestTest.withinStand` already has (*"IS THIS POSITION INSIDE THE STAND'S CIRCLE? Pure, so the
boundary is one rule"*) and it is **pure**, so the whole join rule is drivable in a spec with
hand-written positions and no character at all. Its worst property -- a per-tick loop over players --
costs one subtraction per player per tick, against a drive that already raycasts the ground for
every boar.

**Adopted: a circle on the ground beside the truck, tested per tick, with a countdown that cancels
when he steps out.** Reasons: it is what Karen asked for in her own words, it is presence rather
than collision, it is pure and therefore testable, and it adds no input binding and no new UI owner.

---

## 4. Building the lodge: parts, the Creator Store, or Meshy

The dispatch asks all three to be considered, so all three are.

**4a. A parts build.** Roblox primitives with `Material` and `Color`, assembled by one server module
at boot. Sources: `Terrain:FillBlock`
(<https://create.roblox.com/docs/reference/engine/classes/Terrain#FillBlock>, CC BY 4.0, current)
for the field itself, and the materials list
(<https://create.roblox.com/docs/reference/engine/enums/Material>) -- `WoodPlanks`, `Wood`, `Grass`,
`Ground`, `Slate` are all stock.
*Good:* every line is in the PR and reviewable as a diff; nothing to upload, nothing to moderate, no
asset key, no `.rbxm` (which CI and the harness both refuse); it builds identically in both places;
a cylinder is a log and eighteen cylinders are a log wall. *Bad:* it will never look like a bought
asset. A log lodge in parts is a good grey-box lodge.

**4b. A free Creator Store model, loaded by id.** `InsertService:LoadAsset`
(<https://create.roblox.com/docs/reference/engine/classes/InsertService#LoadAsset>, CC BY 4.0,
current).
*Good:* it can look genuinely good for free. *Bad, and it is decisive tonight:* `LoadAsset` only
loads an asset the place's owner owns or that is free, it is a web call in the boot path (so the
lodge can simply fail to exist), the model has to be checked by hand for `Script`s -- CLAUDE.md
forbids script-like instances outside Rojo-owned paths, and a Creator Store model is a common place
to hide one -- and the id has to be recorded in `assets/uploads.json` **with the text of Karen's
OK**. Karen is asleep. That is the asset lane (`docs/design/asset-pipeline.md`), and it is a
daylight decision.

**4c. Meshy, through the Asset agent.** `docs/design/meshy-tool.md`.
*Good:* a real lodge mesh. *Bad:* it needs a brief, a generation run, Karen's OK on the preview and
an upload -- all four of which are hers or the Asset agent's, not the Builder's, and none of which
can happen before 09:00.

**Adopted: 4a, a parts build, and the reason is written down so it is not re-litigated.** It is the
only one of the three that can be finished, reviewed and merged tonight, and it is the one that puts
a picture in front of Karen in the morning -- which is what the task is for. The geometry lives
behind one module with a config table, so swapping the lodge for a mesh later changes that module
and nothing else. **4b and 4c are the upgrade path, and Karen's OK is the gate on both.**

---

## 5. Where the lobby goes, measured

Karen: *"outside is fields and forrest so house is in fields next to forrest"*. So the lobby needs
OPEN ground with the forest edge in view. Both were measured in the Forest Test place
(`130094961655666`) in Edit mode on 2026-10-13, not guessed:

* `Workspace.OurForest` holds **9,901 parts spanning x 2229..3833, z -2896..-1297**. South of
  z = -2896 there is no forest.
* A raycast grid over fifteen 160 x 160 footprints south of that edge found **terrain everywhere and
  not one non-terrain obstacle** (`obs=0` for all fifteen), with ground height spreads from 16 to 44
  studs. The flattest was centred on **(2850, -2950)**, spread **16 studs**; (3150, -2950) was 18.

So: open ground, no trees to clear, ~54 studs south of the forest edge, and the forest fills the
northern view. The 16-stud spread over 160 studs is a 10% slope, which a lodge cannot sit on --
hence section 6.

## 6. Flattening the field

Two ways to get a flat field on a 10% slope:

**6a. A slab of parts.** A big grass-material block whose top is the field. *Bad:* with a 16-stud
spread the downhill edge floats 16 studs in the air, which is exactly the class of thing this
project exists to stop ("Things measured correct and looked wrong", `docs/PROJECT_CONTEXT.md`).

**6b. Terrain, cut and filled at runtime.** `Terrain:FillBlock` with `Enum.Material.Grass` for the
shelf and `Enum.Material.Air` for the hill above it -- two calls, one shelf, real grass that meets
the existing terrain at its edges.
*Good:* it looks like a field because it is one. *Bad:* it makes this module a writer of Terrain, and
Terrain in the DEV place is written by `tools/mapgen.py` in EDIT mode. Two writers of one thing is
the rule-3 hazard -- so the boundary has to be explicit: **this writes terrain only at RUNTIME, only
inside its own rectangle, only in a world that asked for a lobby.** A runtime terrain write does not
persist (it is a Play-session write, gone when the session ends), so it cannot dirty the Edit-mode
DataModel the harness compares -- the same property `Workspace.ForestMarkers`, `Workspace.Boars` and
`Workspace.WeaponEffects` already rely on (`ForestTest.Markers`' own header says so).

**Adopted: 6b**, with the rectangle, the materials and the two calls all in the lobby's own config,
and the rule that it writes nothing outside that rectangle.

---

## 7. The flow, and who owns which half

The drive's owner is `Match` and nothing changes about that. What changes is **how a player gets
into it**, and today that is `Match`'s `watchPlayer`: `PlayerAdded` -> `dispatch{kind="join"}` ->
`participants` -> with `MIN_PLAYERS = 1` the drive starts. A lobby is exactly the statement *that is
not automatic any more*.

**The two halves:**

| Half | Owner | What it owns |
|---|---|---|
| the lobby | **`Lobby`** (new) | the field, the lodge, the truck, the marked spot, the neutral spawn, and WHO HAS ASKED TO HUNT |
| the drive | **`Match`** (unchanged) | the roster, the teams, the placement, the phases, the score |

**The seam is two doors on `Match` and one world switch**, which is the shape `Match` already has
for every other world difference (`world.markers`, `world.placement`, `world.boars`, `world.bots`,
`world.economy` -- *"the world provides; the owner decides"*):

* `world.enrol = false` -- a player who joins the server is REGISTERED (name, score row, character
  watch) but is **not** dispatched as a `join`. He has no team, so `Objective.text` already returns
  `""` for him and `Weapon`'s arming policy (`Match.mayCarryWeapon`) already refuses him a gun. The
  "no team, no gun, no outfit" requirement is therefore not new code at all: it is what *not being in
  the drive* already means. That is the strongest argument for this seam over any other.
* `Match.enrol(player)` -- dispatches the `join` the lobby decided on. Everything after it is
  today's code: `Waiting` -> `Assigning` once `MIN_PLAYERS` is met and the markers are complete.
* `Match.dismissAll()` -- clears the roster with no feed lines, so the drive falls back to `Waiting`
  through `Phase`'s own existing door (`enoughPlayers` false at the `Scoring` exit ->
  `enterWaiting`, which already takes the scene down and frees everybody).

**End of drive -> back to the lobby, and this is the Director's pick of the simpler** (the dispatch:
*"say which and ask nothing: pick the simpler, Karen judges"*). It is simpler because it needs no new
phase and no new rule: the lobby listens to `Match.PhaseChanged`, calls `dismissAll` when the results
scene goes up, and places everybody at the lodge when the drive reaches `Waiting`. The alternative --
straight into the next drive -- would mean deciding what a player who wants to go shopping does with
a countdown already running, which is a question Karen has not been asked. It also matches her own
doc: *"Everyone starts in lobby ... After you select a game you sit in car and drive to position"*,
one trip at a time.

**4 + 4 is unchanged.** `MIN_PLAYERS` real players start the drive and `Bots` fills the rest
(task 161). Nothing in the bot path knows about the lobby.

---

## 8. The screen

Task 165 owns the objective line and the chevron (`src/client/Hud/Objective.luau`, *"THE ONE WRITER
of the objective LINE and of the WAYPOINT chevron"*). `Objective.text` is pure over
`(phase, team, drive)` and returns `""` for a player with no team -- which today means the lobby
draws nothing at all.

**The lobby is one more row in that table, not a second writer**: no team, phase `Waiting` ->
*"walk to the truck to start a hunt"*, and during the countdown *"leaving for the hunt in %d"*. The
chevron's target is the truck spot, with the word `TRUCK` beside `STAND`, `LINE` and `ROAD`.

The target has to come from somewhere, and it must not be a second definition of where the truck is.
`Objective.targetFor` already takes the world's geometry as an argument and invents nothing
(*"the screen never claims to know more than the world said"*). So the lobby's own shared module
answers it: one reader that finds the named part the lobby built and returns its position, or `nil`.
The server builds it; the client reads it; there is one definition.

The map and minimap (`MapUi`) draw the drive's geometry. In the lobby there is no drive, so the
requirement is that they **hide**, not half-draw -- which is a claim to verify rather than to assume,
and it is in the review request as one.

---

## 9. Numeric targets

| What | Target | Why |
|---|---|---|
| field shelf | 220 x 220 studs, grass, flat | the lodge (40 x 28), the truck, the track and room to walk; 220 covers the measured 160 footprint with a margin |
| lobby centre | (2850, -2950) in the Forest Test | measured flattest open ground, 54 studs south of the forest edge (section 5) |
| truck spot radius | 8 studs | `ForestTest.PICK.standRadiusStuds` is 12 for a stand a hunter must stay inside; a spot he steps into to opt in should be smaller than that and bigger than a stride (a Humanoid walks 16 studs/s) |
| countdown | 5 s | the dispatch's own *"Leaving for the hunt in 5..."*; long enough to step out of by accident and back in |
| lodge | 40 x 28 studs, 18-stud ridge | a porch, a door, one warm room with a fireplace, a table and the shop counter for task 178 |
| lobby part budget | <= 400 parts | `OurForest` is 9,901 parts in this place and the drive runs at 60 Hz with 60 boars; 400 is under 5% of that |
| build time | <= 1 s at boot | it is in the server's boot path, before the first player can reach it |
| harness, DEV | 0 changed checks | the lobby is off in DEV, so the harness must read exactly what it read at `102fbe9` |

---

## 10. What I could not verify, and what is invented

* **The documentation links above were not opened in this session** (no web access was used): the
  APIs cited are ones this repo already calls or ones I rely on from the engine reference, and every
  one of them is proved by the harness run rather than by the link. The CC BY 4.0 licence for the
  Roblox creator documentation is stated from the `Roblox/creator-docs` repository and is the one
  item here with no second source.
* **Nothing is invented** in the sense of rule 2: the spawn mechanism is the engine's
  (`SpawnLocation` + `RespawnLocation`), the opt-in volume is Valve's `trigger_multiple` read as
  arithmetic, the world/owner seam is the one `Match` already has five times over, and the terrain
  shelf is `Terrain:FillBlock` doing what it is for. The only thing with no external source is the
  LODGE'S SHAPE, which is a picture and therefore Karen's (rule: she judges the look).
* **The truck is a parts truck and will look like one.** That is stated rather than hidden.
* **The DEV place has no lobby in this task.** The flag is off there, the harness sees no change, and
  whether the generated map ever gets a lodge is a later decision.

## 11. The pattern, in one line

**One place; the lobby is an area with a neutral spawn; standing in a circle by the truck is the
request to hunt; `Match` keeps the drive and is handed the roster instead of taking it.**
