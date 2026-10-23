--!strict
-- Lobby (server): THE OWNER OF THE LOBBY. The one writer of `Workspace.Lobby`, of the lobby's
-- terrain rectangle, of `Player.RespawnLocation` for a player who is not in the drive, of the
-- `DHLobbyLeaveAt` attribute, of WHAT EVERY TRUCK PAD IS DOING -- and of WHO HAS ASKED TO HUNT.
--
-- KAREN, 2026-10-13 ~19:20: *"I think after this fixes we need to focus on lobby / Hunting house
-- where inside can shop things / outside is fields and forrest so house is in fields next to
-- forrest"*. Her two choices: a *"Wooden log lodge"*, and starting a hunt by *"Walk to a car"*.
--
-- ...AND 2026-10-14 ~09:30, which is task 182: *"when start hunt we need to go next to truck has to
-- be mark where and has to be coloroude circle like in all games or rectangle where people stand and
-- can be 1/1 or 4/4 you can select on dialiog how many like in roblox games and can be several truck
-- like 4 of them nicly aligned next ot each other and you come to truck back rectangle and can click
-- and select how many players"*.
--
-- SO THE COUNTDOWN MOVED FROM THE PLAYER TO THE PAD. Task 177 gave every man who stepped into the
-- circle a five-second clock of his own (`Join.decide`, now archived); a party of four needs ONE
-- clock for the four of them. `Lobby.Pads` is that state machine, pure, and this owner holds four of
-- them -- one per truck -- and asks each one what to do ten times a second.
--
-- WHAT THIS OWNS AND WHAT IT DOES NOT, because that boundary is the whole task (design section 4.5):
--   * it owns the lobby's WORLD (`Build`), the lobby's TERRAIN (`Field`), the RULES (`Join` and
--     `Pads`, both pure) and the state of the four pads;
--   * it NEVER writes a team, a character's position, clothes or a tool. The one character move it
--     asks for goes out through the injected `place` seam, which the boot binds to
--     `Match.Body.place` -- the one writer of where a character stands. It has no `setTeam`, no
--     `dress`, no `Weapon` and no `Horn`, and it requires neither `Match` nor `Match.Body`.
--   * `Match` keeps the drive and is HANDED the roster instead of taking it: `world.enrol` and
--     `world.dismissAll` are its two doors, `world.inDrive` and `world.isHeld` its two readers. The
--     wiring is one-directional -- `ForestTestBoot` hands `Match`'s doors to this module and never
--     the reverse -- so neither owner requires the other, exactly as `Boar`, `Bots`, `Weapon`,
--     `HitLog` and `Economy` already are.
--
-- NOTHING HAPPENS ON REQUIRE. Only `Lobby.start(world)` begins production -- the rule `Match`,
-- `Boar`, `Weapon`, `Bots` and `Economy` all follow, and what lets every spec drive the whole system
-- with no players, no terrain and no clock.
--
-- IT HAS NO CLOCK OF ITS OWN (design, open decision 2). `ForestTestBoot` already runs one
-- `RunService.Heartbeat` that walks every player's root every frame; `Lobby.step` is one more call in
-- it, throttled in here to `SCAN_HZ`. A second clock would be a second answer to "what time is it"
-- in a file whose own header says *"ONE HEARTBEAT FOR BOTH JOBS"*.
--
-- ONE INBOUND DOOR SINCE TASK 182, AND EXACTLY ONE: `Lobby.onPadRequest`, on
-- `ReplicatedStorage.Lobby.Remotes.PadRequest`. Task 177 had none at all and said so in capitals,
-- because standing somewhere is not a message -- but Karen asked for a DIALOG, and a dialog is a
-- message from a client. It is built in `Shop.onRequest`'s shape: public so a spec drives it by
-- parameter, rate-limited per player, every fact measured off the character the SERVER can see, and
-- a forged payload counted apart from a legal request the game said no to. **Nothing a client sends
-- can enrol anybody**: the most a pick can do is choose how many men a pad waits for.
--
-- OUTBOUND IS STILL ATTRIBUTES AND NOTHING ELSE. `DHLobbyLeaveAt` on each member of a departing
-- party (task 177's wire, now written from the PAD's deadline), and `DHPadState` / `DHPadFirst` on
-- each pad's own part -- written by `Build.setPad`, because that module is the one writer of every
-- part in `Workspace.Lobby` and an attribute lives on a part. There is no outbound remote.
--
-- Design: docs/design/truck-pads.md; docs/design/lobby.md (sections 3, 4, 7, 8, 11, 12.2)
-- Note:   docs/research/2026-10-14-truck-pads.md;
--         docs/research/2026-10-13-lobby-and-the-truck.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Data = require(ReplicatedStorage:WaitForChild("Lobby"))
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))

local Lobby = {}

Lobby.Data = Data
Lobby.Join = require(script.Join)
-- THE PAD STATE MACHINE (task 182), PURE, re-exported for the specs exactly as `Join` and `Field`
-- are. It is a separate module from this owner for `Join`'s own stated reason: a rule with no world
-- in it is a table of cases in a spec, and a rule inside the owner is a thing somebody watches in a
-- playtest.
Lobby.Pads = require(script.Pads)
-- ...AND THE PARTY THAT GOES AGAIN (task 246), PURE, re-exported for the specs exactly as `Join`,
-- `Pads` and `Field` are, and a separate module for the identical reason: *"a rule with no world in
-- it is a table of cases in a spec, and a rule inside the owner is a thing somebody watches in a
-- playtest"*.
Lobby.Next = require(script.Next)
Lobby.Field = require(script.Field)
Lobby.Build = require(script.Build)

local Join = Lobby.Join
local Pads = Lobby.Pads
local NextDrive = Lobby.Next
local Field = Lobby.Field
local Build = Lobby.Build

-- THE ONE FLAG READ, AT THIS OWNER'S BOUNDARY, passed inward through `start`'s `world.enabled` --
-- the only permitted shape (CLAUDE.md, feature flags). Both branches stay reachable by PARAMETER
-- while the row sits at `false`: a spec calls `start({ enabled = true, ... })` with fake seams.
Lobby.ENABLED = Flags.isOn("LOBBY")

local started = false
local world: any = nil
local cfg = Data.CONFIG
local anchor: Vector3? = nil
local folder: Instance? = nil
local spawnPart: BasePart? = nil
local lastScan = -math.huge
local firstStepAt: number? = nil
local degraded = false
local phase: string? = nil
local dismissPending = false
-- THE PARTY THAT GOES AGAIN (task 246). ONE of them, held here because this owner is the one that
-- owns WHO IS IN THE DRIVE (`world.enrol` / `world.dismissAll`) and the one that walks everybody
-- back to the lodge -- so it is the only thing that can know when the party is home, which is when
-- the countdown may start. FROZEN by `Next`'s own functions; this is the only variable that holds it.
local nextDrive: any = NextDrive.initial()
-- WHAT THE LAST `NextDrive.step` SAID. It is kept for exactly one reason -- the per-player attribute
-- writes in `stepPlayer` need to know whether a deadline exists at all, and asking the state twice
-- in one scan is two answers to one question -- and it is reported in `stats` so a playtest can see
-- the machine is turning without a probe.
local nextVerdict: string = NextDrive.IDLE
-- ONE NUMBER PER PLAYER, the SIT OUT door's forgery guard. Its OWN bucket, beside the pad's and the
-- role's, for `lastRoleRequestAt`'s stated reason: a shared bucket would make "press SIT OUT, then
-- press BEATER" lose one of them. `forget` and `stop` empty it.
local lastNextRequestAt: { [number]: number } = {}
-- WHO THIS DRIVE LET GO OF, AND WHETHER HE WAS IN IT LAST SCAN (task 249). KAREN, 2026-10-23:
-- *"still game wasant over when I respawn after while it was showing what was shooted but I was
-- free to walk, is it ok ?"*.
--
-- RECONCILED ON THE TICK AND NOT FIRED OFF AN EVENT (L-029, and `Next`'s own header says the same
-- thing): `wasInDrive` is what `world.inDrive` said about this man on the PREVIOUS scan, and the
-- edge from true to false **while a drive is still live** is the whole definition of *"the drive
-- let go of him"*. A respawn mid-countdown, a second respawn, a man who presses Reset twice and a
-- withdrawal that arrives between two scans all land in the same place, because what is tested is
-- the STATE and not the event that produced it.
--
-- THE END OF A DRIVE IS NOT A WITHDRAWAL. `dismissAll` empties the roster one scan into `Scoring`
-- and that is everybody at once; the latch is therefore armed only while `Phase.insideDrive` is
-- true (`Assigning` or `Running`), which is the same window `Match.Phase`'s own `withdraw` branch
-- refuses outside of. One rule, two owners, measured against the same two phase names.
--
-- IT CLEARS WHEN A DRIVE HAS HIM AGAIN, so the line comes down exactly as the next drive takes
-- him, and `forget` / `stop` empty both.
local leftDrive: { [number]: boolean } = {}
local wasInDrive: { [number]: boolean } = {}
-- THE FOUR PADS (task 182), indexed by pad. `Pads.empty(index)` each, rebuilt by `start`.
local pads: { [number]: any } = {}
-- WHERE EACH PAD IS, computed ONCE at build time off `Pads.centreFor` -- the one place that
-- arithmetic lives -- so the scan is four `math.abs` pairs per player and not four additions as
-- well.
local padAt: { [number]: Vector3 } = {}
-- WHEN THIS MAN ARRIVED ON THE PAD HE IS ON. It exists for exactly one rule: who is re-elected to
-- pick when the first man walks off (`Pads.step`, the earliest remaining). Dropped the moment he is
-- on a different pad or none, so it can never claim he has been standing there since a previous
-- hunt.
local arrived: { [number]: { pad: number, since: number } } = {}
-- ONE NUMBER PER PLAYER, the door's forgery guard. `forget` and `stop` empty it (`Shop`'s
-- round-1 note: a bucket with no pruner grows for the life of the server).
local lastPadRequestAt: { [number]: number } = {}
-- WHICH ROLE EACH MAN HAS ASKED FOR, FOR ONE DRIVE (task 229). Karen, 2026-10-21: *"we also need to
-- have posibility to choose once you have a card always hunter maybe sometimes I want to be a beater
-- we need to find a way to do that"*.
--
-- ONE ROW PER PLAYER WHO HAS ASKED FOR SOMETHING OTHER THAN THE DEFAULT, and `Lobby.wishFor`'s
-- answer of `HUNTER` drops the row -- so the table holds only the men who have actually asked to
-- beat, it is empty in every build where nobody owns `ALWAYS HUNTER`, and the reconciliation can
-- only ever CLEAR. `forget` and `stop` empty it, beside the bucket above.
local roleWish: { [number]: string } = {}
-- THE FROZEN MEMO THE DRIVE READS, rebuilt by the one writer and never mutated -- so a reader still
-- holding the previous table holds a correct snapshot of the moment it asked. `Economy.owedTeams`'
-- and `Economy.alwaysHunters`' own device, and its own stated reason: `Match.dispatch` fills this on
-- EVERY event, which while TASKS.md 214a(a) is open can be ~15x `MATCH_STEP_HZ`.
local wishFrozen: { [number]: boolean }? = nil
-- THE ROLE DOOR'S OWN FORGERY GUARD, and it is its OWN bucket rather than the pad's. Sharing one
-- would make "press BEATER, then press 1 / 1" lose the size pick, because `Lobby.padRateLimited`
-- writes its row on every accepted call. One number (`PADS.REQUEST_MIN_INTERVAL`), two buckets, both
-- pruned by `forget` and `stop`.
local lastRoleRequestAt: { [number]: number } = {}
-- WHO OWNS `ALWAYS HUNTER`, injected AFTER `Shop.start` and never required. nil = nobody owns
-- anything = today's game, in every branch.
--
-- IT IS THE CARD AND NOT A WIDER RULE, and that is KAREN'S OWN WORD of 2026-10-22, verbatim: *"when
-- you have a card always hunter technically you can choose to be what you ant eather beater or
-- hunter"*. The first cut of task 242 widened this to anyone holding the BEATER LICENCE as well;
-- she ruled otherwise, and that cut is archived in
-- `backups/2026-10-22_task-242_beater-licence-buys-the-choice.md` (rule 7).
local alwaysHunters: (() -> { [number]: boolean })? = nil
local returnedAt: { [number]: number } = {}
local spawnIndex: { [number]: number } = {}
local nextSpawnIndex = 0
-- EVERY PLAYER THIS MODULE HAS WRITTEN TO, so `stop` hands back exactly what it wrote and nothing
-- else. Without it the teardown would have to walk `Players:GetPlayers()` and clear a
-- `RespawnLocation` it never set -- a write to somebody else's player, from a spec, in a place that
-- has no lobby.
local touched: { [number]: any } = {}
-- THE DOOR'S OWN CONNECTION (task 182). `Shop.start`'s shape: a list, so `stop` disconnects exactly
-- what it connected and a spec can start and stop this owner as many times as it likes.
local connections: { RBXScriptConnection } = {}

local stats = {
	scans = 0,
	buildAttempts = 0,
	buildMs = 0,
	shelfY = 0,
	parts = 0,
	fillCalls = 0,
	grassCalls = 0,
	scrubCalls = 0,
	enrolments = 0,
	-- THE ROLE DOOR (task 229), counted apart from the pad's: `roleAsks` is every well-formed ask
	-- that got past the rate bucket, `roleWrites` is the ones that actually CHANGED the value, and
	-- `roleRateLimited` is the guard firing. A `roleWrites` that climbs with `scans` would mean the
	-- reconciliation had stopped being edge-triggered, which is what the spec asserts it does not.
	roleAsks = 0,
	roleWrites = 0,
	roleRateLimited = 0,
	-- A PAD THAT EMPTIED, which since task 182 is what a cancel IS: the countdown belongs to the pad
	-- and not to a player, so "he stepped out" is "the pad lost its last man".
	cancels = 0,
	-- THE PADS (task 182). `parties` is how many pads were SIZED (picked or defaulted) and
	-- `departures` how many actually left, so a party that forms and never goes is visible as a gap
	-- between two numbers rather than as nothing at all.
	parties = 0,
	departures = 0,
	pickTimeouts = 0,
	-- THE DOOR, and its counters are `Shop.stats`' split: a FORGED payload (`badRequests`) is a
	-- different fact from a legal request the game said no to (`refusedBy`), because *"counting it as
	-- a bad request would hide a mis-wired provider inside the forgery counter"*.
	padRequests = 0,
	picks = 0,
	badRequests = 0,
	rateLimited = 0,
	refusedBy = {} :: { [string]: number },
	-- HOW MANY TIMES A PAD'S BILLBOARD OR ATTRIBUTES CHANGED. `Build.setPad` is edge-triggered, so a
	-- number that climbs with `scans` is the bug this counter exists to show.
	padWrites = 0,
	-- ...AND HOW MANY TIMES A TRUCK WAS STARTED OR STOPPED (task 197). `Build.setTruck` is
	-- edge-triggered for the same reason and reports the same way, so the two counters read together:
	-- one party leaving is one `truckWrites` on and one off.
	truckWrites = 0,
	dismissals = 0,
	-- THE CONTINUOUS LOOP (task 246). Five numbers, and each one is a different fact about the same
	-- party, on `parties`/`departures`' own principle -- *"a party that forms and never goes is
	-- visible as a gap between two numbers rather than as nothing at all"*:
	--   nextParties   how many parties were COLLECTED when a drive ended;
	--   nextArmed     how many of those got a deadline (so a party that never arms is a gap here);
	--   nextDepartures how many actually went again;
	--   nextCleared   how many ended without going -- everybody left, or everybody sat out;
	--   nextTimeouts  how many were armed by `ARM_TIMEOUT_SECONDS` instead of by being home, which
	--                 is hazard 1 firing and must never be invisible.
	-- HOW MANY TIMES A LIVE DRIVE LET GO OF SOMEBODY (task 249). Karen's respawn, and every other
	-- way out of a drive that is not the end of it. It is the number that says the line she now
	-- reads is reaching anybody at all: 0 in a drive nobody leaves, 1 per Reset.
	withdrawalsSeen = 0,
	nextParties = 0,
	nextArmed = 0,
	nextDepartures = 0,
	nextCleared = 0,
	nextTimeouts = 0,
	-- ...AND THE SIT OUT DOOR, counted exactly as the role door above is: `nextAsks` is every
	-- well-formed ask that got past the bucket, `nextWrites` the ones that CHANGED the membership.
	nextAsks = 0,
	nextWrites = 0,
	nextRateLimited = 0,
	returns = 0,
	degradedEnrolments = 0,
	-- WHICH LODGE AND WHICH TRUCKS GOT BUILT (task 180): how many free-model templates were cloned
	-- and how many were asked for and not found. The boot prints them, so "the models are in" is a
	-- line in the console and not an inspection.
	models = 0,
	fallbacks = 0,
	-- ...and how many script instances a template carried in, which the owner must be able to report
	-- too: `Build.stats()` is not reachable from the boot's log line (review round 1, note).
	strippedScripts = 0,
	-- IS THERE A MAN AT THE COUNTER, AND IS HE DRESSED (task 181)? Reported for `models`' own stated
	-- reason, and it matters more than the trucks do: since this task took task 178's auto-open
	-- away, a lodge with no keeper is a shop nobody on the server can open.
	keepers = 0,
	keeperDressed = 0,
	-- THE TRUCKS' OWN TWO NUMBERS (task 186), reported for `models`' stated reason and because the
	-- defect they close was invisible to every count there was: four trucks built, four trucks
	-- parked, every tyre 0.75 studs inside the terrain. `truckGroundStuds` is the worst wheel of the
	-- worst truck in studs ABOVE its ground, and `truckPainted` how many parts the camouflage
	-- actually repainted -- a repaint that matched nothing would otherwise be a silent zero.
	trucksSettled = 0,
	truckGroundStuds = 0,
	truckPainted = 0,
	-- How many times his head was actually turned. One write per change and never one per scan, so
	-- a number that climbs with the scan count is the bug this counter exists to show.
	keeperTurns = 0,
}

function Lobby.stats()
	local out = table.clone(stats)
	out.refusedBy = table.clone(stats.refusedBy)
	return out
end

-- WHAT PAD n IS DOING, for the specs and for a console probe. A COPY, so nothing outside this owner
-- can write a pad's state.
function Lobby.padOf(index: number): any
	local pad = pads[index]
	return if pad == nil then nil else table.clone(pad)
end

local function count(reason: string)
	stats.refusedBy[reason] = (stats.refusedBy[reason] or 0) + 1
end

function Lobby.isBuilt(): boolean
	return folder ~= nil and folder:IsDescendantOf(game)
end

-- WHERE THE DRIVE GATHERS AT ITS END (task 191), and the drive is handed this function as
-- `world.gatherSpot`. KAREN, 2026-10-15: *"next is when hunt over everyone is in clean ground no
-- grass firstable / second it could be next to cabin"*.
--
-- THE WHOLE OF IT IS A WIRE. The rectangle is `Data.gatherPad`'s row, the facing is
-- `CONFIG.GATHER.FACING`, the arithmetic is `Data.gatherSpotFor`, and the ground is `world.groundAt`
-- -- this world's single reader, which this owner was already handed for the shelf. It decides
-- nothing, holds nothing and creates nothing, which is the `Match.displayAnimal` shape.
--
-- `nil, nil` UNTIL THE LOBBY IS REALLY BUILT, AND THAT IS THE FALLBACK DOING ITS JOB rather than a
-- failure: `Match.gatherSpot` then uses the drive's own "behind the middle stand" rule, which is the
-- game before this task. The three states it covers are a drive that ends before the shelf could be
-- read, a world whose config has no `Gather` row, and this owner never started at all.
--
-- IT IS READ AT THE DRIVE'S END AND NOT CACHED, because `world.groundAt` answers the surface
-- `Field.fill` actually produced and that surface does not exist until the lobby has built itself.
function Lobby.gatherSpot(): (Vector3?, Vector3?)
	if not started or anchor == nil or not Lobby.isBuilt() then
		return nil, nil
	end
	return Data.gatherSpotFor(anchor :: Vector3, cfg, if world then world.groundAt else nil)
end

-- WHERE HE STANDS WHEN HE ARRIVES. Spread across the porch front, so two players never spawn inside
-- each other -- `Body.placementFor`'s driver-spread idiom with this yard's own width -- and facing
-- +Z (north): he looks at the lodge with the forest behind its roof, and the truck and the circle are
-- to his right. That is Karen's *"house is in fields next to forrest"* read as a camera angle.
--
-- PURE, so the spread and the facing are a spec and not a screenshot.
function Lobby.spawnCFrame(at: Vector3, index: number, config): CFrame
	local spread = config.SPAWN.SPREAD_STUDS
	-- WRAPPED INTO THE PORCH'S OWN SLOTS, AND THE BOUND IS WHAT MAKES THIS SAFE (review round 1,
	-- finding 3): the caller's index is a counter that only ever goes up, and an unwrapped slot 37
	-- lands 114 studs off the middle -- outside the field itself, where `Join.needsReturn` answers
	-- true for a man standing exactly where this put him and the lobby re-places him for ever.
	-- `SPAWN.SLOTS` is where the number and its arithmetic are written down.
	local slot = index % math.max(1, config.SPAWN.SLOTS)
	-- Centre-out: 0, +1, -1, +2, -2 ... so a solo player gets the middle of the porch.
	local step = math.floor((slot + 1) / 2) * (if slot % 2 == 0 then -1 else 1)
	local here = at + config.SPAWN.OFFSET + Vector3.new(step * spread, 0, 0)
	return CFrame.lookAt(here, here + Vector3.new(0, 0, 10), Vector3.yAxis)
end

-- ---------------------------------------------------------------- the build

-- ONE ATTEMPT. It needs the world's own ground reader to answer, and until it does there is nothing
-- to build on: `Data.groundAt` raycasts, and a place that has not finished loading answers nil.
-- Retried once a second by `step` -- the `Match:step` precedent (*"Re-reading while `Waiting` costs
-- five `GetTagged` calls a second and closes the race for good"*).
-- IS A BUILD IN FLIGHT? Since task 181 this path can YIELD -- `Build.defaultRigSource` is
-- `Players:CreateHumanoidModelFromDescription`, which is documented to load assets -- and `step`
-- runs off the boot's `Heartbeat` at `SCAN_HZ`. Without this, a rig call longer than one scan lets
-- the next scan see `isBuilt() == false` and build the whole lobby AGAIN: two folders, two lodges,
-- two keepers with two prompts, and `Build.build`'s own "parented last" means the second build
-- cannot even see the first to destroy it. Review round 1, finding 3.
--
-- It is the discipline this module already states one function below (*"THROTTLED, because
-- `Body.place` yields on `LoadCharacter` and this scan runs at 10 Hz"*), as a latch rather than a
-- clock: a second attempt during the first is not delayed, it is not made.
local building = false

local function tryBuild(): boolean
	local centre = anchor
	if centre == nil or building then
		return false
	end
	stats.buildAttempts += 1
	local shelf = world.groundAt((centre :: Vector3).X, (centre :: Vector3).Z)
	if type(shelf) ~= "number" then
		return false
	end
	local began = os.clock()
	local seat = Vector3.new((centre :: Vector3).X, shelf :: number, (centre :: Vector3).Z)
	anchor = seat
	stats.shelfY = shelf :: number

	-- THE TERRAIN FIRST, THEN THE PARTS: the shelf is what everything stands on, and a lodge placed
	-- before the hill above it was cut would be built inside that hill for as long as the fill took.
	if world.terrain ~= nil then
		local calls, grassCalls, scrubbed = Field.fill(world.terrain, seat, shelf :: number, cfg)
		stats.fillCalls = calls
		stats.grassCalls = grassCalls
		-- HOW MANY PAD RECTANGLES WERE SCRUBBED BACK TO THEIR OWN MATERIAL (task 244): one per row
		-- in `FIELD.PADS`, so "which path it took" stays a number in `Lobby.stats()` and not a
		-- belief -- the rule `grassCalls` was added for (design section 18 item 1).
		stats.scrubCalls = scrubbed
	end

	-- THE FREE MODELS, FOUND ONCE, AT THE OWNER'S BOUNDARY (task 180). `Workspace.LobbyAssets` is
	-- Studio content: it exists in the Forest Test place and not in the DEV one, so this answers an
	-- Instance there and nil here, and `Build` takes the branch it is given. `world.templates` lets a
	-- spec hand in a folder of its own without a Workspace at all -- the `world.root` seam exactly.
	local templates = world.templates
	if templates == nil then
		templates = (world.root or Workspace):FindFirstChild(Data.TEMPLATES_NAME)
	end
	-- THE KEEPER'S TWO SEAMS, AND THE DEFAULT IS THIS OWNER'S TO SUPPLY (task 181). `Build` builds
	-- no body at all when it is handed no rig source, which is what keeps a spec free of the avatar
	-- service; the live server always has one, so "somebody forgot to inject it" cannot be a lodge
	-- with nobody in it. `dress` is `Match.Body.dress`, injected at the composition root exactly as
	-- `Bots.start({ dress = Body.dress })` injects it -- one dressing path in this repository.
	-- THE LATCH IS HELD ACROSS THE ONE CALL THAT CAN YIELD, and `pcall` is what clears it on a
	-- build that throws: a latch left standing would be a lobby that never builds again, which is
	-- worse than the fault it guards.
	building = true
	local ok, made, _marker, spawn, parts = pcall(
		Build.build,
		world.root or Workspace,
		seat,
		cfg,
		templates,
		{
			rig = world.rig or Build.defaultRigSource,
			dress = world.dress,
			dressConfig = world.dressConfig,
			shopOn = world.shopOn,
			-- WHAT A THING LOOKS LIKE, by name (task 196): the boar for the trophy over the fire and
			-- the two guns for the rack behind the counter. The composition root translates a name
			-- into a template, exactly as `dress` hands over the one dressing path -- this owner
			-- never learns what an asset key is, and a world that injects nothing gets a bare plaque
			-- and an empty rack.
			assets = world.assets,
			-- THE SAME READER THIS FUNCTION JUST USED FOR THE SHELF, handed down so each truck pad is
			-- laid on the ground that is really there (task 182). Measured in the live place: without
			-- it the four pads sat 0.17 studs UNDER the terrain and only their billboards showed,
			-- because Roblox terrain is voxelised and `Field.fill`'s surface is not exactly `shelfY`.
			groundAt = world.groundAt,
			-- AND THE TERRAIN'S OWN READER (task 196 part 3d), which `Build` uses for ONE thing: it
			-- seats every tree against the LOWEST ground anywhere under its root flare, instead of
			-- against the ground at the point it was planted. Karen: *"look at the trees wtf"*.
			terrainAt = world.terrainAt,
		} :: any
	)
	building = false
	if not ok or made == nil then
		warn(string.format("[lobby] build failed and will be retried: %s", tostring(made)))
		return false
	end
	local built = Build.stats()
	stats.models = built.models
	stats.fallbacks = built.fallbacks
	stats.strippedScripts = built.strippedScripts
	stats.keepers = built.keepers
	stats.keeperDressed = built.keeperDressed
	stats.trucksSettled = built.trucksSettled
	stats.truckGroundStuds = built.truckGroundStuds
	stats.truckPainted = built.truckPainted
	folder = made
	spawnPart = spawn
	-- WHERE THE FOUR PADS ARE, COMPUTED ONCE, through the ONE function that knows (task 182).
	-- `Build.pads` placed the parts with the same call, so the rule and the slabs cannot disagree
	-- about where pad 3 is -- which is exactly what task 177 got wrong for the circle, computing
	-- `anchor + cfg.SPOT.OFFSET` in two files.
	table.clear(padAt)
	table.clear(pads)
	for index = 1, cfg.TRUCK.COUNT do
		padAt[index] = Pads.centreFor(seat, index, cfg)
		pads[index] = Pads.empty(index)
	end
	stats.parts = parts
	stats.buildMs = math.floor((os.clock() - began) * 1000 + 0.5)
	return true
end

-- ---------------------------------------------------------------- per player

local function clearLeaveAt(player: any)
	if player:GetAttribute(Data.LEAVE_AT_ATTRIBUTE) ~= nil then
		player:SetAttribute(Data.LEAVE_AT_ATTRIBUTE, nil)
		touched[player.UserId] = player
	end
end

-- WHICH PAD THIS MAN IS LOADING ONTO, as its own state word, or nil (task 197). `clearLeaveAt`'s
-- shape exactly: WRITTEN ONLY WHEN IT DIFFERS, so it is one replicated write per change and not ten
-- a second, and asked every scan so it is a LEVEL rule -- which is what makes the banner on his
-- screen go down by itself when the party cancels, when the drive takes him, or when he walks away.
local function setPadMine(player: any, state: string?)
	if player:GetAttribute(Data.PAD_MINE_ATTRIBUTE) ~= state then
		player:SetAttribute(Data.PAD_MINE_ATTRIBUTE, state)
		touched[player.UserId] = player
	end
end

-- ---------------------------------------------------------------- the next drive (task 246)

-- WHEN THE NEXT DRIVE STARTS, on this man's own `Player`, or nil. Asked every scan, so it is a
-- LEVEL rule -- that is what makes the card come down by itself when the party goes, when he sits
-- out, when he walks onto a pad instead, and when he leaves.
--
-- **IT IS `DHLobbyLeaveAt`'S OWN EDGE SHAPE AND NOT `setPadMine`'S COMPARISON, and that is a
-- correction the harness made rather than a preference.** The value written is a SERVER time
-- (`serverNow + (deadline - now)`) and the two clocks are read separately, so a comparison against
-- what is already there is a comparison between two conversions -- which differ by whatever drifted
-- between the readings. The first harness run measured it as **four writes on four scans** of one
-- unchanged deadline (`lobby_live.spec`, *"writes each attribute once per change"*). The pad's own
-- countdown solved this before this task existed, in the line beside it: write only when the
-- attribute is ABSENT, and clear it when there is no deadline. One write per change by
-- construction, with no clock in the comparison at all.
local function setNextAt(player: any, at: number?)
	if at == nil then
		if player:GetAttribute(Data.NEXT_AT_ATTRIBUTE) ~= nil then
			player:SetAttribute(Data.NEXT_AT_ATTRIBUTE, nil)
			touched[player.UserId] = player
		end
	elseif player:GetAttribute(Data.NEXT_AT_ATTRIBUTE) == nil then
		player:SetAttribute(Data.NEXT_AT_ATTRIBUTE, at)
		touched[player.UserId] = player
	end
end

-- ...AND WHETHER HE HAS ASKED TO MISS IT. `true` or nil, never `false`: an attribute that exists
-- and says `false` is a third state the card would have to understand, and absent already means
-- *"he is in"* (`roleWish`'s own storage rule -- the default is the ABSENCE of a row).
local function setNextOut(player: any, out: boolean)
	local wanted = if out then true else nil
	if player:GetAttribute(Data.NEXT_OUT_ATTRIBUTE) ~= wanted then
		player:SetAttribute(Data.NEXT_OUT_ATTRIBUTE, wanted)
		touched[player.UserId] = player
	end
end

-- ...AND WHETHER THIS DRIVE LET GO OF HIM (task 249). `true` or nil, never `false`, for
-- `setNextOut`'s stated reason: absent already means *"he has not left a drive"*.
local function setLeftDrive(player: any, left: boolean)
	local wanted = if left then true else nil
	if player:GetAttribute(Data.LEFT_DRIVE_ATTRIBUTE) ~= wanted then
		player:SetAttribute(Data.LEFT_DRIVE_ATTRIBUTE, wanted)
		touched[player.UserId] = player
	end
end

-- WHAT THE PARTY IS DOING, for the specs, the boot's log line and a console probe. A COPY of the
-- lists and never the state itself, which is `Lobby.padOf`'s rule: nothing outside this owner may
-- write a membership.
function Lobby.nextDrive(): any
	return {
		verdict = nextVerdict,
		at = nextDrive.at,
		members = NextDrive.ids(nextDrive),
		goers = NextDrive.goers(nextDrive),
	}
end

-- ---------------------------------------------------------------- the role wish (task 229)

-- THE ONE WRITER of the wish AND of the `DHRoleWish` attribute that mirrors it. Private: the door
-- and the scan are its only callers, so there is no way for anything else in this repository to
-- write a man's wish (CLAUDE.md rule 3).
--
-- `clearLeaveAt`'s and `setPadMine`'s discipline exactly: WRITTEN ONLY WHEN IT DIFFERS, so it is one
-- replicated write per change and not ten a second.
--
-- THE TABLE HOLDS ONLY THE MEN WHO ASKED TO BEAT. `HUNTER` is the default, so it is stored as the
-- ABSENCE of a row -- which is what makes `beaterWishes()` empty in every build where nobody has
-- asked, and what makes the reconciliation below able only to clear.
--
-- THE MEMO IS DROPPED ON EVERY CHANGE and rebuilt by the next reader, never mutated.
local function setRoleWish(player: any, wish: string?)
	local userId = player.UserId
	local stored: string? = roleWish[userId]
	local asked = if wish == Data.ROLE_WISH.BEATER then wish else nil
	if stored ~= asked then
		roleWish[userId] = asked
		wishFrozen = nil
		stats.roleWrites += 1
	end
	if player:GetAttribute(Data.ROLE_WISH_ATTRIBUTE) ~= wish then
		player:SetAttribute(Data.ROLE_WISH_ATTRIBUTE, wish)
		touched[userId] = player
	end
end

-- PURE and exported. WHAT THIS MAN'S ATTRIBUTE MUST SAY RIGHT NOW -- the level rule, asked every
-- scan (design section 6). It is `Join.needsReturn`'s shape and its stated reason: *"there are four
-- ways to end up standing in the wrong place and only one of them is a phase change"*, and a wish
-- is spent by five different things (a departure, a dismissal between drives, a
-- `Scoring -> Assigning`, a leave, a Reset). One level rule covers all of them; five handlers cover
-- four of them and the fifth is the bug (Learning Agent L-029).
--
--   * he does not own `ALWAYS HUNTER`  -> nil      -- no control is built anywhere
--   * the drive has given him a side   -> HUNTER   -- the wish has been SPENT
--   * otherwise                        -> what he asked for, or HUNTER
--
-- `assigned` IS THE DRIVE'S OWN TEAM AND NOT "IS HE IN A DRIVE", and that is the whole correctness
-- of the reset. `Lobby.depart` -> `Match.enrol` makes him a participant IMMEDIATELY, while the
-- assignment that reads the wish happens on a LATER `Match` step; the lobby's next scan is 0.1 s
-- away, so a wish cleared on `inDrive` would be gone before the assignment it was supposed to
-- change. `Lobby.onRoleRequest` uses the OTHER fact on purpose -- *may he still change his mind*,
-- which ends when the truck has him -- and since `inDrive` becomes true first, the two can never
-- contradict.
function Lobby.wishFor(stored: string?, owns: boolean, assigned: string?): string?
	if not owns then
		return nil
	end
	if assigned ~= nil then
		return Data.ROLE_WISH.HUNTER
	end
	return if stored == Data.ROLE_WISH.BEATER then Data.ROLE_WISH.BEATER else Data.ROLE_WISH.HUNTER
end

-- WHO HAS ASKED TO BEAT, as a FROZEN MEMO: userId -> true. This is what the drive reads, through the
-- bare function the composition root hands to `Match.start`.
--
-- FROZEN AND MEMOISED for `Economy.alwaysHunters`' own stated reason, quoted in that file: the drive
-- fills it on EVERY event, and while TASKS.md 214a(a) is open that dispatch is stepped at ~15x
-- `MATCH_STEP_HZ` -- so a clone here would be ~60 table builds a second for a table that changes at
-- most twice a drive. One table read, no clone and no freeze per call.
--
-- EMPTY when nobody owns the item, when the shop is off and in every spec that starts no money,
-- which is what makes `Roster.assign` answer BY IDENTITY and the game before this task bit for bit.
function Lobby.beaterWishes(): { [number]: boolean }
	local cached = wishFrozen
	if cached == nil then
		local built: { [number]: boolean } = {}
		for userId, wish in pairs(roleWish) do
			if wish == Data.ROLE_WISH.BEATER then
				built[userId] = true
			end
		end
		cached = table.freeze(built)
		wishFrozen = cached
	end
	return (cached :: any) :: { [number]: boolean }
end

-- WHO OWNS THE HUNTER'S PLACE, injected at the composition root. A SETTER and not a `start` field,
-- for `ForestTest.setSeatProvider`'s stated reason: `Lobby.start` runs BEFORE `Shop.start`, so an
-- ownership read cannot be in the table `start` is handed.
--
-- nil = NOBODY OWNS ANYTHING = today's game: `wishFor` answers nil for everybody, the attribute is
-- never written and neither control is ever built.
function Lobby.setAlwaysHunters(reader: (() -> { [number]: boolean })?)
	alwaysHunters = if type(reader) == "function" then reader else nil
end

-- WRITTEN ONLY WHEN IT DIFFERS, so it is one write per change and not one per scan.
local function setRespawn(player: any, to: BasePart?)
	if player.RespawnLocation ~= to then
		player.RespawnLocation = to
		touched[player.UserId] = player
	end
end

local function rootOf(player: any): Vector3?
	local character = player.Character
	local root = character and character.PrimaryPart
	return if root then root.Position else nil
end

-- WHOSE TURN IT IS ON THE PORCH. Remembered per player, so a man returned twice does not shuffle
-- along the porch each time.
local function indexFor(userId: number): number
	local known = spawnIndex[userId]
	if known ~= nil then
		return known
	end
	spawnIndex[userId] = nextSpawnIndex
	nextSpawnIndex += 1
	return spawnIndex[userId]
end

-- ONE PLAYER, ONCE A SCAN: where he respawns, whether his screen is counting down, and whether he
-- belongs back at the lodge. `padIndex` is which pad he is standing on, measured once for everybody
-- by `occupancy` below and handed in -- a second measurement here would be a second answer to "where
-- is he".
local function stepPlayer(
	player: any,
	now: number,
	padIndex: number?,
	serverNow: number,
	owners: { [number]: boolean }?
)
	local userId = player.UserId
	local inDrive = world.inDrive(userId) == true
	-- DID THIS DRIVE LET GO OF HIM? (task 249) RECONCILED HERE, before every early return below, so
	-- it is answered for a man the drive still has as well as for one standing in the lobby -- the
	-- same placement and the same reason as the card and the role wish beneath it.
	--
	-- THE EDGE IS true -> false WHILE A DRIVE IS LIVE. `Phase.insideDrive` is `Assigning` or
	-- `Running`; the end of a drive empties the roster in `Scoring` and must not mark everybody as
	-- having left, which is why the phase is part of the test rather than the edge alone.
	if inDrive then
		leftDrive[userId] = nil
	elseif wasInDrive[userId] == true and (phase == "Assigning" or phase == "Running") then
		leftDrive[userId] = true
		stats.withdrawalsSeen += 1
	end
	wasInDrive[userId] = inDrive
	setLeftDrive(player, leftDrive[userId] == true)
	-- THE NEXT DRIVE'S CARD, RECONCILED ON EVERY SCAN (task 246), **before** the `inDrive` return
	-- below and for the role wish's own stated reason: a man the drive has just taken is exactly the
	-- man whose card has to come DOWN, and a rule that ran only for men standing in the lobby would
	-- leave a countdown on his screen for the whole drive.
	--
	-- THE DEADLINE IS THE PARTY'S, NOT HIS, which is `Lobby`'s existing arrangement one system
	-- along: *"Task 177 gave every man a clock of his own; a party of four shares one"*. Everybody
	-- in the party is handed the SAME `nextDrive.at`, so no two members can be watching two numbers.
	--
	-- THE DEADLINE IS THE ONE FACT, AND IT IS WHAT MAKES THE CARD VISIBLE. While the party is
	-- collected and not yet home (`Next.WAITING`) `nextDrive.at` is nil and nothing is written, so
	-- the card is DOWN for exactly as long as Karen's results scene is up -- which is the order she
	-- asked for (*"back to lobby after hunt"*, and only then the next drive) and the reason there is
	-- no "waiting" word on the card at all.
	--
	-- AND IT IS CONVERTED INTO THE SERVER'S OWN CLOCK HERE, exactly as the pad's deadline is and
	-- with the same measured reason beside it: `Next` counts in the scan's `now`, the client counts
	-- in `Workspace:GetServerTimeNow()`, and `serverNow` is read ONCE PER SCAN by the caller -- not
	-- once per member -- because *"two men on one pad got deadlines four microseconds apart, because
	-- each conversion called `GetServerTimeNow()` again"*. The two clocks advance together, so this
	-- value does not drift and `setNextAt`'s comparison leaves it alone after the first write.
	local mine = NextDrive.has(nextDrive, userId)
	local deadline = nextDrive.at
	setNextAt(player, if mine and deadline ~= nil then serverNow + math.max(0, deadline - now) else nil)
	-- ...AND HIS OWN HALF OF IT, which is a SECOND attribute because the countdown runs whether he
	-- is in or out -- that is the whole point of letting him change his mind. It is cleared for a
	-- man with no party, so a SIT OUT cannot survive into the next gap.
	setNextOut(player, mine and NextDrive.isOut(nextDrive, userId))
	-- THE ROLE WISH, RECONCILED FIRST AND ON EVERY SCAN (task 229), **before** the `inDrive` return
	-- below: a man the drive already has is exactly the man whose wish has to be spent, and a rule
	-- that ran only for men standing in the lobby would never clear one.
	--
	-- IT IS LEVEL-TRIGGERED AND ONLY EVER CLEARS: `Lobby.wishFor` returns `HUNTER` once the drive has
	-- given him a side, and `setRoleWish` drops the row for `HUNTER` -- so a spent wish cannot come
	-- back, and nothing here can invent one.
	--
	-- `world.assignedTeam` IS OPTIONAL. A world with no drive answers nil, nothing is ever spent, and
	-- the lobby still works -- which is why it is not in `start`'s six-name required list.
	setRoleWish(
		player,
		Lobby.wishFor(
			roleWish[userId],
			owners ~= nil and owners[userId] == true,
			if world.assignedTeam ~= nil then world.assignedTeam(userId) else nil
		)
	)
	if inDrive then
		-- HE IS IN THE HUNT. Nothing of the lobby's applies to him: no deadline on his screen, and no
		-- respawn point at the lodge -- `Match.Body` owns where he stands now.
		clearLeaveAt(player)
		-- ...AND THE LOADING BANNER COMES DOWN HERE, which is the Director's *"until the drive takes
		-- the player"* said as a line of code. It is the SAME edge the roster is written on -- the
		-- drive has him -- so the banner cannot outlive the thing it was counting down to.
		setPadMine(player, nil)
		setRespawn(player, nil)
		return
	end

	setRespawn(player, spawnPart)

	-- THE COUNTDOWN ON HIS SCREEN, AND IT IS HIS PAD'S AND NOT HIS OWN (task 182). Task 177 gave
	-- every man a clock of his own; a party of four shares one, so the deadline is read off the pad
	-- he is standing on and every member of that party sees the same number.
	--
	-- LEVEL-TRIGGERED WITH EDGE WRITES, which is this module's existing discipline (`setRespawn`):
	-- the rule is asked every scan, and `clearLeaveAt` plus the `== nil` guard below mean one
	-- replicated write per CHANGE rather than ten a second. It is written on the
	-- `filling -> countdown` edge and cleared the moment he steps off -- which is the per-member half
	-- of what `Pads.step`'s own cancel does for the whole pad.
	local pad = if padIndex ~= nil then pads[padIndex] else nil
	-- ...AND WHETHER HIS PAD IS LOADING, through the ONE predicate the truck's lights read too
	-- (`Data.padLoading`): so the banner on his screen and the engine on that truck are the same
	-- fact, and there is no second answer to *"is this party leaving"*.
	setPadMine(player, if pad ~= nil and Data.padLoading(pad.state) then pad.state else nil)
	local leaveAt = if pad ~= nil and pad.state == Pads.COUNTDOWN then pad.deadline else nil
	if leaveAt == nil then
		clearLeaveAt(player)
	elseif player:GetAttribute(Data.LEAVE_AT_ATTRIBUTE) == nil then
		-- THE DEADLINE IS THE SERVER'S, and it reaches his own client as one attribute. He counts it
		-- down locally, which is the one conversion `Match.snapshot`'s `phaseEndsAt` already
		-- establishes: a client-side countdown invented from a client-side position would read 0
		-- while the server had not sent anybody anywhere.
		-- `serverNow` IS READ ONCE PER SCAN BY THE CALLER, not once per member, and the spec is what
		-- found that: two men on one pad got deadlines four microseconds apart, because each
		-- conversion called `GetServerTimeNow()` again. A party of four watching four different
		-- numbers would be four answers to "how long until I go", which is the exact duplication the
		-- pad's single clock exists to remove.
		player:SetAttribute(Data.LEAVE_AT_ATTRIBUTE, serverNow + math.max(0, leaveAt - now))
		touched[userId] = player
	end

	-- BACK TO THE LODGE, BY A LEVEL RULE AND NOT BY AN EDGE (design section 8.1). `held` is
	-- load-bearing: during the results scene a dismissed player is not a participant and is 570 studs
	-- from the lodge, so without it this would respawn him out of Karen's results scene.
	local here = rootOf(player)
	local held = world.isHeld ~= nil and world.isHeld(userId) == true
	local inField: boolean? = if here == nil then nil else Join.insideField(here :: Vector3, anchor :: Vector3, cfg)
	if Join.needsReturn(inDrive, held, inField) then
		local last = returnedAt[userId]
		-- THROTTLED, because `Body.place` yields on `LoadCharacter` and this scan runs at 10 Hz. The
		-- nil-position rule above already covers most of it (a respawning player has no root); this
		-- is the belt.
		if last == nil or now - last >= cfg.RETURN_COOLDOWN_SECONDS then
			returnedAt[userId] = now
			stats.returns += 1
			world.place(player, Lobby.spawnCFrame(anchor :: Vector3, indexFor(userId), cfg))
		end
	end
end

-- ---------------------------------------------------------------- the pads (task 182)

-- WHO IS STANDING ON WHICH PAD, RIGHT NOW. The party is DERIVED and never stored (design section
-- 6.5): one pass over the occupants per scan, and a man the drive already has is LEFT OUT -- which is
-- what makes `Pads.LEAVING` end by itself, because the moment the party is enrolled every list is
-- empty.
--
-- ONE PASS AND NOT ONE PER PAD: each man is tested until a pad matches, and `BAY_GAP_STUDS` 17
-- against `SIZE.Z` 9 leaves 8 studs between them -- it was `SIZE.X` until task 243 swapped the
-- pad's two axes, and the 8 is unchanged -- so he cannot be inside two and the first match is
-- the only match.
--
-- `arrived` IS MAINTAINED HERE because this is the one place that knows he has just stepped on. It
-- answers ONE question -- who is re-elected to pick when the first man walks off -- and it is dropped
-- the moment he is somewhere else, so it can never claim he has been standing there since a previous
-- hunt.
local function occupancy(occupants: { any }, now: number): ({ { any } }, { [number]: number })
	local lists: { { any } } = {}
	local padOf: { [number]: number } = {}
	for index = 1, cfg.TRUCK.COUNT do
		lists[index] = {}
	end
	for _, player in ipairs(occupants) do
		local userId = player.UserId
		local index: number? = nil
		if world.inDrive(userId) ~= true then
			index = Pads.indexAt(rootOf(player), anchor :: Vector3, cfg)
		end
		if index == nil then
			arrived[userId] = nil
		else
			local found = index :: number
			local known = arrived[userId]
			if known == nil or known.pad ~= found then
				arrived[userId] = { pad = found, since = now }
			end
			padOf[userId] = found
			table.insert(lists[found], { userId = userId, since = (arrived[userId] :: any).since })
		end
	end
	return lists, padOf
end

-- ONE SCAN OF EVERY PAD, and it is the only thing in this module that reaches the drive.
local function stepPads(lists: { { any } }, occupants: { any }, now: number)
	for index = 1, cfg.TRUCK.COUNT do
		local before = pads[index]
		if before ~= nil then
			local after, verdict = Pads.step(before, lists[index], now, cfg)
			pads[index] = after

			if verdict == Pads.CANCELLED then
				stats.cancels += 1
			elseif verdict == Pads.SET then
				stats.parties += 1
				if before.state == Pads.SIZING then
					-- NOBODY ANSWERED. Counted apart from a pick, because the two are different facts
					-- about the same party -- and the unattended path the Director's own smoke check
					-- takes is this one (design section 15.4).
					stats.pickTimeouts += 1
				end
			elseif verdict == Pads.DEPART then
				-- THE PARTY GOES, exactly once, through the ONE seam a published build would swap for
				-- a reserved-server teleport (design section 9).
				local went = Lobby.depart({
					padIndex = index,
					size = after.size,
					members = Lobby.playersOf(after.members, occupants),
				})
				if went > 0 then
					stats.departures += 1
				end
			end

			-- ...AND THE BOARD SAYS WHAT THE PAD IS DOING. Pure words in (`Pads.labelFor`'s own
			-- format, through `Build.setPad`), one edge-triggered write out, asked every scan --
			-- because the COUNT changes on a join and a leave, and neither of those is a verdict.
			local pad = pads[index]
			local truckLine, countLine = Pads.labelFor(pad, cfg)
			if Build.setPad(index, pad.state, pad.firstUserId, truckLine, countLine) then
				stats.padWrites += 1
			end
			-- ...AND THE TRUCK IN FRONT OF IT STARTS OR STAYS DARK (task 197). KAREN, 2026-10-15:
			-- *"could be car started sound light on something like that indicating loading"*.
			--
			-- ASKED EVERY SCAN WITH A LEVEL ANSWER, exactly like the billboard above it and for a
			-- stronger reason: an engine turned on by the PICK and off by the DEPARTURE would be left
			-- running by every other way a party can end -- the last man stepping off in `countdown`,
			-- a failed hand-over re-entering `sizing`, a phase change emptying the pads. `setTruck`
			-- is edge-triggered inside, so this costs one comparison a scan per truck.
			if Build.setTruck(index, Data.padLoading(pad.state)) then
				stats.truckWrites += 1
			end
		end
	end
end

-- ---------------------------------------------------------------- the next drive (task 246)

-- ONE SCAN OF THE PARTY THAT GOES AGAIN, and -- like `stepPads` -- it is the only other thing in
-- this module that reaches the drive.
--
-- KAREN, 2026-10-23: *"we need continues game so after drive new drive imidiatly after same amount
-- seconds"*.
--
-- THE THREE FACTS ARE MEASURED HERE AND THE RULE IS DECIDED IN `Lobby.Next`, which is `stepPads`'
-- own division: this function knows what a `Player` is and the state machine does not. One pass over
-- the occupants, which is the same pass `occupancy` already makes -- and it is a SEPARATE pass on
-- purpose, because `occupancy` is about rectangles and this is about the drive.
local function stepNextDrive(occupants: { any }, now: number)
	local present: { [number]: boolean } = {}
	local inDrive: { [number]: boolean } = {}
	local held: { [number]: boolean } = {}
	for _, player in ipairs(occupants) do
		local userId = player.UserId
		present[userId] = true
		if world.inDrive(userId) == true then
			inDrive[userId] = true
		end
		-- `isHeld` IS THE RESULTS SCENE, and it is what makes the countdown start AFTER the return
		-- rather than at the instant the drive ended: `enterScoring` holds the whole roster for
		-- `SCORE_SECONDS` and `enterWaiting`'s `free` lets them go, which is the same edge
		-- `Join.needsReturn` begins walking them home on. It is OPTIONAL in `Lobby.start`, so a
		-- world with no drive answers nothing and the party is home the moment it is collected.
		if world.isHeld ~= nil and world.isHeld(userId) == true then
			held[userId] = true
		end
	end

	local before = nextDrive.at
	local was = nextVerdict
	local state, verdict, going =
		NextDrive.step(nextDrive, { present = present, inDrive = inDrive, held = held }, now, cfg.PADS.NEXT)
	nextDrive = state
	nextVerdict = verdict

	-- ONE CONSOLE LINE PER VERDICT CHANGE, and it is here for `[lobby] trucks:`' own stated reason:
	-- this machine is INVISIBLE between drives -- no part, no billboard, and a probe cannot read it
	-- (a fresh `require` in the command bar gets an unstarted module), so without this the only way
	-- to tell *"the party is waiting for a man who is still held"* from *"there is no party"* is to
	-- read the code. It is EDGE-TRIGGERED, so a drive's whole gap is four lines and not eighty.
	--
	-- IT PAID FOR ITSELF IMMEDIATELY: the first live run of this task sat at the lodge for three
	-- minutes with `Phase=WAITING` and nothing on screen, and nothing in the console said which of
	-- the five verdicts it was in.
	if verdict ~= was then
		local heldCount = 0
		for _ in pairs(held) do
			heldCount += 1
		end
		print(
			string.format(
				"[lobby] the next drive: %s -> %s, %d member(s), %d going, %d held, in %.1fs",
				was,
				verdict,
				#NextDrive.ids(state),
				#going,
				heldCount,
				if state.at ~= nil then math.max(0, (state.at :: number) - now) else -1
			)
		)
	end

	-- THE DEADLINE WAS JUST SET. Counted on the EDGE (`before == nil`), because `COUNTING` is the
	-- verdict of every scan for the next eight seconds and a counter that climbed with the scans
	-- would say nothing.
	if verdict == NextDrive.COUNTING and before == nil then
		stats.nextArmed += 1
		-- ...AND WHETHER IT WAS ARMED BY THE TIMEOUT INSTEAD OF BY THE PARTY BEING HOME (hazard 1).
		--
		-- ASKED OF THE PARTY AND NOT OF THE SERVER (review round 1, note 4): `held` is built over
		-- EVERY occupant, so a man held for some other reason -- tied to a tree in somebody else's
		-- drive, standing in a results scene he is not in the party for -- would have reported
		-- hazard 1 firing when the arming was in fact `home`. It is the same question `Next.step`
		-- itself asks, of the same list.
		local heldMembers = 0
		for _, userId in ipairs(NextDrive.ids(state)) do
			if held[userId] == true then
				heldMembers += 1
			end
		end
		if heldMembers > 0 then
			stats.nextTimeouts += 1
			warn(
				string.format(
					"[lobby] the next drive's countdown was armed by its %ds timeout with %d of %d member(s)"
						.. " still held: the results scene did not let everybody go",
					cfg.PADS.NEXT.ARM_TIMEOUT_SECONDS,
					heldMembers,
					#NextDrive.ids(state)
				)
			)
		end
	elseif verdict == NextDrive.GO then
		-- THE PARTY GOES AGAIN, through the SAME seam a pad's party leaves through (design section
		-- 9), so a published build that swaps `world.depart` for a reserved-server teleport keeps
		-- working and there is exactly one place a party leaves this lobby.
		--
		-- `padIndex` IS NIL, AND THAT IS THE HONEST VALUE: no pad sent them. `Departure.padIndex` is
		-- optional for this one caller and the field says so.
		local went = Lobby.depart({ padIndex = nil, size = #going, members = Lobby.playersOf(going, occupants) })
		if went > 0 then
			stats.nextDepartures += 1
		end
	elseif verdict == NextDrive.CLEARED then
		stats.nextCleared += 1
	end
end

-- THE `Player` OBJECTS BEHIND A LIST OF userIds, out of the occupants this scan already walked -- so
-- this module never asks `Players` for anybody and a spec's fake occupants work unchanged.
--
-- A userId WITH NO PLAYER IS DROPPED: he left between the scan and the departure, which is a thing
-- that happens and not an error.
function Lobby.playersOf(userIds: { number }, occupants: { any }): { any }
	local out = {}
	for _, userId in ipairs(userIds) do
		for _, player in ipairs(occupants) do
			if player.UserId == userId then
				table.insert(out, player)
				break
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- the one place a party leaves

-- WHAT LEFT, AND FROM WHERE.
-- `padIndex` IS OPTIONAL SINCE TASK 246, and nil means *"no pad sent them"* -- the party that goes
-- again after a drive (`stepNextDrive`). It is nil rather than 0 because a 0 would be an index, and
-- an index that names no pad is the kind of value `LEAVING.EYEBROW`'s own comment was written about:
-- *"the screen never claims to know more than the world said"*. Nothing in this repository reads it;
-- it is here for the not-built reserved-server implementation and for a log line.
export type Departure = {
	padIndex: number?,
	size: number?,
	members: { any },
}

-- THE PARTY GOES TO THIS SERVER'S OWN DRIVE, through task 177's existing door, one call per member.
-- `Lobby` writes no team, no character and no roster entry (design section 4.5); it asks.
--
-- CLEARED BEFORE THE ENROLMENT, exactly as task 177 cleared them: `enrol` reaches `LoadCharacter`
-- inside the same call, and with the lodge still set as a man's respawn the engine would put his new
-- character at the lodge and the drive's own pivot would have to beat it. `Body.place` + `Body.settle`
-- already handle that race (measured in task 157); this simply does not create another instance of
-- it.
function Lobby.enrolHere(departure: Departure): number
	local went = 0
	for _, player in ipairs(departure.members) do
		clearLeaveAt(player)
		setRespawn(player, nil)
		if world.enrol(player) then
			went += 1
			stats.enrolments += 1
		end
	end
	return went
end

-- THE ONE PLACE A PARTY LEAVES THE LOBBY, and it is a SEAM with two implementations (design section
-- 9).
--
--   1. TODAY, AND THE ONLY ONE BUILT: `Lobby.enrolHere` above -- this server's one drive.
--   2. NOT BUILT: a published game would instead reserve a server and send the party to it, so four
--      pads would be four simultaneous hunts:
--        local code = TeleportService:ReserveServerAsync(game.PlaceId)
--        TeleportService:TeleportToPrivateServer(game.PlaceId, code, departure.members)
--      `TeleportPartyAsync` and the older `ReserveServer` are both marked DEPRECATED, which is why
--      those are the two names.
--
-- IT IS NOT BUILT HERE BECAUSE IT CANNOT BE TESTED HERE. `TeleportService` has no documented Studio
-- behaviour and in practice none -- there is no live server to reserve and no session to move a
-- player into -- and this repository's whole evidence chain runs in Studio. By rule 6 and rule 8 it
-- must not be built in the task that cannot show it working.
--
-- THE SWITCH IS `world.depart`, INJECTED, which is the stronger form of CLAUDE.md's flag requirement:
-- both branches are reachable BY PARAMETER, so `lobby_live.spec` drives each of them. A flag row was
-- considered and refused -- `Flags` is at `MAX_FLAGS = 13` with thirteen rows declared, and a flag
-- over a function that does not exist has no second state to reach, which is the one thing the
-- feature-flag section demands of a flag.
--
-- `pcall`, because an injected seam that throws must not take the scan down with it. The party is
-- then still standing on the pad, so `Pads.step`'s `leaving` case takes it back to `sizing` on the
-- next scan and asks them again -- which is the one thing that stops a refused enrolment leaving a
-- man on a dead rectangle (`Pads.step` case 6).
function Lobby.depart(departure: Departure): number
	if world ~= nil and type(world.depart) == "function" then
		local ok, went = pcall(world.depart, departure)
		return if ok and type(went) == "number" then went :: number else 0
	end
	return Lobby.enrolHere(departure)
end

-- ---------------------------------------------------------------- the door (task 182)

-- IS HE ASKING TOO OFTEN? One number per player, and it is a FORGERY GUARD rather than a game rule:
-- a person cannot press a button four times a second. `Shop.rateLimited`'s shape, including being
-- public so a spec can drive it.
function Lobby.padRateLimited(userId: number, now: number): boolean
	local last = lastPadRequestAt[userId]
	if last ~= nil and now - last < cfg.PADS.REQUEST_MIN_INTERVAL then
		return true
	end
	lastPadRequestAt[userId] = now
	return false
end

-- THE ONE INBOUND HANDLER, AND IT IS THE FIRST THIS SYSTEM HAS EVER HAD: task 177's lobby had no
-- inbound door at all, because standing somewhere is not a message. A dialog is.
--
-- PUBLIC, for `Shop.onRequest`'s and `Weapon.onFireRequest`'s stated reason: it is the seam a forged
-- request arrives through, and `OnServerEvent` can only be raised by a client (task 80), so a spec
-- must be able to drive it by parameter.
--
-- EVERY FACT IS MEASURED HERE AND NOTHING IS TAKEN FROM THE PAYLOAD BUT ITS TWO NUMBERS. Which pad he
-- is on comes from the character the SERVER can see; whether he may pick comes from the pad's own
-- `firstUserId`, which this module wrote off a man it saw standing there; whether the size is legal
-- comes from `Pads.sizeAllowed`. A client that could decide any of the three would be a client that
-- could put eight strangers in a truck.
--
-- IT RETURNS ITS OWN DECISION -- `{ ok = true, size = k }`, `{ ok = false, refused = "<reason>" }`, or
-- nil for a request that was not answered at all -- so a spec gets a per-call answer instead of
-- inferring one from a counter (task 80 round 2's correction).
--
-- THERE IS NO REPLY REMOTE. Every refusal below is a state the client could already see, and the
-- pad's two attributes are the answer to an accepted pick: one wire in, none out.
function Lobby.onPadRequest(player: any, request: any, now: number?): any
	if not started then
		return nil
	end
	stats.padRequests += 1
	local at = now or os.clock()
	local index = if type(request) == "table" then (request :: any).pad else nil
	local size = if type(request) == "table" then (request :: any).size else nil
	if
		type(index) ~= "number"
		or index % 1 ~= 0
		or index < 1
		or index > cfg.TRUCK.COUNT
		or not Pads.sizeAllowed(size, cfg)
	then
		-- NOTHING IS SENT BACK and nothing is changed: the client that forged it is not told what
		-- shape would have worked (`Shop.onRequest`'s rule).
		stats.badRequests += 1
		return { ok = false, refused = "bad-request" }
	end
	if Lobby.padRateLimited(player.UserId, at) then
		stats.rateLimited += 1
		return nil
	end
	local found = index :: number
	local pad = pads[found]
	if pad == nil then
		-- A LEGAL INDEX WITH NO PAD BEHIND IT: the lobby has not built yet. Not a forgery.
		count("no-pad")
		return { ok = false, refused = "no-pad" }
	end
	-- WHERE HE ACTUALLY IS, off the character the server can see. It is the belt to `firstUserId`'s
	-- brace: a pick from across the yard is impossible even on a scan where the pad has not yet
	-- noticed he stepped off.
	if Pads.indexAt(rootOf(player), anchor :: Vector3, cfg) ~= found then
		count("not-on-pad")
		return { ok = false, refused = "not-on-pad" }
	end
	if pad.firstUserId ~= player.UserId then
		count("not-first")
		return { ok = false, refused = "not-first" }
	end
	local after, ok = Pads.withSize(pad, size :: number, at, cfg)
	if not ok then
		-- THE PAD HAS MOVED ON: a stale client, which is a different fact from a forged one.
		count("too-late")
		return { ok = false, refused = "too-late" }
	end
	pads[found] = after
	stats.picks += 1
	stats.parties += 1
	local truckLine, countLine = Pads.labelFor(after, cfg)
	if Build.setPad(found, after.state, after.firstUserId, truckLine, countLine) then
		stats.padWrites += 1
	end
	-- THE TRUCK STARTS ON THE PRESS AND NOT ON THE NEXT SCAN (task 197). The Director's brief begins
	-- at *"the moment a size is picked"*, and this function already applies the pick here rather than
	-- waiting -- the billboard two lines up is written for the same reason. The scan's own call is
	-- what keeps it honest afterwards; this one only removes a tenth of a second of silence from the
	-- one edge a player can hear.
	if Build.setTruck(found, Data.padLoading(after.state)) then
		stats.truckWrites += 1
	end
	return { ok = true, size = size }
end

-- ---------------------------------------------------------------- the role door (task 229)

-- IS HE ASKING TOO OFTEN? `Lobby.padRateLimited`'s shape and its number
-- (`PADS.REQUEST_MIN_INTERVAL`, four a second), in a bucket OF ITS OWN -- see `lastRoleRequestAt`'s
-- own comment for why sharing the pad's would cost him his size pick.
function Lobby.roleRateLimited(userId: number, now: number): boolean
	local last = lastRoleRequestAt[userId]
	if last ~= nil and now - last < cfg.PADS.REQUEST_MIN_INTERVAL then
		return true
	end
	lastRoleRequestAt[userId] = now
	return false
end

-- THE SECOND INBOUND HANDLER (task 229). KAREN, 2026-10-21: *"we also need to have posibility to
-- choose once you have a card always hunter maybe sometimes I want to be a beater we need to find a
-- way to do that"*.
--
-- PUBLIC, for `onPadRequest`'s own stated reason: `OnServerEvent` can only be raised by a client
-- (task 80), so a spec must be able to drive it by parameter.
--
-- EVERY FACT IS MEASURED HERE AND NOTHING IS TAKEN FROM THE PAYLOAD BUT ITS ONE WORD. Whether the
-- word is legal is `Data.roleAllowed`, the one whitelist both sides read; whether he owns
-- `ALWAYS HUNTER` is the server's own frozen memo; whether the truck already has him is the drive's
-- own answer. A client that could decide any of the three would be a client that could put itself on
-- either side of a drive.
--
-- IT RETURNS ITS OWN DECISION -- `{ ok = true, role = r }`, `{ ok = false, refused = "<reason>" }`,
-- or nil for a request that was not answered at all -- so a spec gets a per-call answer instead of
-- inferring one from a counter (task 80 round 2's correction).
--
-- THERE IS NO REPLY REMOTE, which is this system's own rule: the `DHRoleWish` attribute IS the
-- answer, and every refusal below is a state the client could already see.
function Lobby.onRoleRequest(player: any, request: any, now: number?): any
	if not started then
		return nil
	end
	local at = now or os.clock()
	local wish = if type(request) == "table" then (request :: any).role else nil
	-- ONE FIELD, AND NOTHING ELSE ON THE WIRE (review round 1, note 1). `{ role = "beater" }` is the
	-- whole payload; a packet carrying anything more is not a client of this build, and accepting it
	-- while silently ignoring the extra is how a second field gets read by accident later.
	-- `Shop.checkRequest`'s own rule: *"an argument nobody reads is an argument nobody checked"*.
	local onlyRole = type(request) == "table"
	if onlyRole then
		for key in pairs(request :: any) do
			if key ~= "role" then
				onlyRole = false
				break
			end
		end
	end
	if not onlyRole or not Data.roleAllowed(wish) then
		-- NOTHING IS SENT BACK and nothing is changed: the client that forged it is not told what
		-- shape would have worked (`onPadRequest`'s rule).
		stats.badRequests += 1
		return { ok = false, refused = "bad-request" }
	end
	if Lobby.roleRateLimited(player.UserId, at) then
		stats.roleRateLimited += 1
		return nil
	end
	-- HE DOES NOT OWN THE THING HE IS ASKING ABOUT, AND THAT IS **NOT** A FORGERY. It is this
	-- module's own split, written in `stats`: a forged payload is a different fact from a legal
	-- request the game said no to, *"because counting it as a bad request would hide a mis-wired
	-- provider inside the forgery counter"* -- and a build where `setAlwaysHunters` was never called
	-- would otherwise read as an attack.
	local owners = if alwaysHunters ~= nil then alwaysHunters() else nil
	if owners == nil or owners[player.UserId] ~= true then
		count("not-an-owner")
		return { ok = false, refused = "not-an-owner" }
	end
	-- THE TRUCK ALREADY HAS HIM, SO HE MAY NOT CHANGE HIS MIND. This is the door's fact and it is
	-- deliberately NOT the reset's: `inDrive` becomes true at enrolment, one scan before the
	-- assignment that spends the wish, so the reset asks `world.assignedTeam` instead (see
	-- `Lobby.wishFor`). Asking the earlier fact here is what closes the window the later one leaves
	-- open.
	if world.inDrive ~= nil and world.inDrive(player.UserId) == true then
		count("in-a-drive")
		return { ok = false, refused = "in-a-drive" }
	end
	-- THE SERVER WRITES IT, INSIDE THIS CALL and not on the next scan, so what a player waits for is
	-- one network hop and not a tenth of a second of scan. The scan's own call is what keeps it
	-- honest afterwards -- `onPadRequest`'s own arrangement with `Build.setTruck`.
	-- COUNTED HERE AND NOT AT THE TOP (review round 1, note 2): `roleAsks` is an ask the game
	-- ANSWERED, so a refusal belongs in `refusedBy` and in nothing else -- which is what the design's
	-- own verdict table says and what `stats`' forged/refused split exists for.
	stats.roleAsks += 1
	setRoleWish(player, wish)
	return { ok = true, role = wish }
end

-- ---------------------------------------------------------------- the SIT OUT door (task 246)

-- IS HE PRESSING TOO OFTEN? Its OWN bucket, for `Lobby.roleRateLimited`'s stated reason: a shared
-- one would make "press SIT OUT, then press BEATER" lose one of the two. Public so a spec drives it.
function Lobby.nextRateLimited(userId: number, now: number): boolean
	local last = lastNextRequestAt[userId]
	if last ~= nil and now - last < cfg.PADS.NEXT.REQUEST_MIN_INTERVAL then
		return true
	end
	lastNextRequestAt[userId] = now
	return false
end

-- THE THIRD INBOUND DOOR. *"A player who wants to stop: give a SIT OUT control on the countdown
-- card. By default they are in."* (the Director's brief, carrying Karen's *"continues game"*.)
--
-- PUBLIC, AND IT RETURNS ITS OWN DECISION, for `Lobby.onPadRequest`'s and `Lobby.onRoleRequest`'s
-- stated reason: `OnServerEvent` can only be raised by a client, so a spec must be able to drive the
-- seam a forged request arrives through, and a per-call answer beats inferring one from a counter.
--
-- EVERY FACT IS MEASURED HERE AND NOTHING IS TAKEN FROM THE PAYLOAD BUT ITS ONE WORD. Whether he is
-- in a party at all is `Lobby.Next`'s membership, which this module wrote off a roster the SERVER
-- read; whether the word is legal is `Data.nextAllowed`. **Nothing a client sends can put a man INTO
-- a party** -- the most it can do is take him out of one he is already in, or put him back.
--
-- THERE IS NO REPLY REMOTE: the two attributes are the answer, exactly as the role door's one is.
function Lobby.onNextRequest(player: any, request: any, now: number?): any
	if not started then
		return nil
	end
	local at = now or os.clock()
	local word = if type(request) == "table" then (request :: any).next else nil
	-- EXACTLY ONE KEY, AND NOTHING ELSE IS TOLERATED -- `Lobby.onRoleRequest`'s own check and its
	-- reason: *"an argument nobody reads is an argument nobody checked"*.
	local onlyWord = type(request) == "table"
	if onlyWord then
		for key in pairs(request :: any) do
			if key ~= "next" then
				onlyWord = false
				break
			end
		end
	end
	if not onlyWord or not Data.nextAllowed(word) then
		-- NOTHING IS SENT BACK and nothing is changed: the client that forged it is not told what
		-- shape would have worked.
		stats.badRequests += 1
		return { ok = false, refused = "bad-request" }
	end
	if Lobby.nextRateLimited(player.UserId, at) then
		stats.nextRateLimited += 1
		return nil
	end
	-- HE IS NOT IN A PARTY. **NOT A FORGERY** -- this module's own split, and the same one the role
	-- door makes for `not-an-owner`: a legal request the game said no to is a different fact from a
	-- forged payload, *"because counting it as a bad request would hide a mis-wired provider inside
	-- the forgery counter"*. It is the normal answer for a man who pressed the key with no card up.
	if not NextDrive.has(nextDrive, player.UserId) then
		count("no-party")
		return { ok = false, refused = "no-party" }
	end
	stats.nextAsks += 1
	local wanted = word == Data.NEXT_WORD.OUT
	local before = nextDrive
	nextDrive = NextDrive.sit(nextDrive, player.UserId, wanted)
	if nextDrive ~= before then
		stats.nextWrites += 1
		-- THE SERVER WRITES THE ATTRIBUTE INSIDE THIS CALL and not on the next scan, so what the
		-- player waits for is one network hop and not a tenth of a second of scan -- the role door's
		-- own arrangement, and the reason task 209's banner had to be raised on the click. The scan's
		-- own level rule is what keeps it honest afterwards.
		setNextOut(player, wanted)
	end
	return { ok = true, next = word }
end

-- ---------------------------------------------------------------- the entry points

-- IT RECORDS AND DOES NOT ACT. `Match` fires `PhaseChanged` at the end of `dispatch`, and `Match:step`'s
-- own comment says why nothing may dispatch from inside a dispatch (*"a dispatch inside a dispatch
-- would apply effects out of order"*). So this writes one field and the next `step` acts on it -- the
-- `markersStale` idiom -- which also makes the end-of-drive flow drivable in a spec by calling
-- `Lobby.onPhase("Scoring")` with no drive at all.
function Lobby.onPhase(next_: string?)
	if not started then
		return
	end
	if next_ == "Scoring" and phase ~= "Scoring" then
		dismissPending = true
	end
	phase = next_
end

-- THE ONE ENTRY POINT, from the world's own clock. `players` is handed in -- the `Match` / `Bots`
-- test seam -- so a spec drives the whole flow with fake occupants and no `Players` service.
function Lobby.step(now: number, players: { any }?)
	if not started then
		return
	end
	if now - lastScan < 1 / cfg.SCAN_HZ then
		return
	end
	lastScan = now
	stats.scans += 1
	if firstStepAt == nil then
		firstStepAt = now
	end
	local occupants = players or Players:GetPlayers()

	if not Lobby.isBuilt() then
		if not tryBuild() then
			-- THE LOBBY CAN NEVER LOCK THE GAME OUT (design section 7.4). If the ground still cannot
			-- be read after the timeout, everybody is enrolled through the same door the circle uses
			-- and the game is today's game exactly: no second code path, and one line saying why.
			if not degraded and now - (firstStepAt :: number) >= cfg.BUILD_TIMEOUT_SECONDS then
				degraded = true
				local enrolled = 0
				for _, player in ipairs(occupants) do
					if world.enrol(player) then
						enrolled += 1
					end
				end
				stats.degradedEnrolments = enrolled
				warn(
					string.format(
						"[lobby] no ground at the anchor after %ds and %d attempts: %d player(s) enrolled directly,"
							.. " the drive runs as it did before task 177",
						cfg.BUILD_TIMEOUT_SECONDS,
						stats.buildAttempts,
						enrolled
					)
				)
			end
			return
		end
	end

	if dismissPending then
		dismissPending = false
		-- WHO WAS IN THE DRIVE THAT JUST ENDED, MEASURED BEFORE IT IS EMPTIED (task 246). It has to
		-- be this side of `dismissAll`, because after it there is no roster left to read -- and it
		-- is measured off `world.inDrive` over the occupants rather than asked for as a list,
		-- because that reader already exists and a new `world.roster` door would be a second answer
		-- to *"who is in this drive"*.
		--
		-- BOTH SIDES, AND THAT IS THE POINT OF KAREN'S FIRST SENTENCE (*"back to lobby after hunt to
		-- have the same not saperate for beaters"*): this reads no team at all, so the hunters and
		-- the beaters are one list, collected in one pass, at one instant.
		local roster = {}
		for _, player in ipairs(occupants) do
			-- ...AND THE MEN THIS DRIVE LET GO OF (task 249). The dispatch: *"keep her on the next
			-- drive's countdown party by default"*. A man who respawned mid-drive is NOT
			-- `world.inDrive` any more -- that is exactly what task 248 did to him -- so without
			-- this row he would watch the party he was in leave for the next drive and have to walk
			-- to a pad again. He is standing at the lodge with them; he goes with them.
			--
			-- `leftDrive` IS CLEARED THE MOMENT A DRIVE HAS HIM, so this cannot carry a man into a
			-- second party: `Next.collect` replaces the membership outright and the latch is down
			-- again on the first scan of the drive that takes him.
			if world.inDrive(player.UserId) == true or leftDrive[player.UserId] == true then
				table.insert(roster, player.UserId)
			end
		end
		local cleared = world.dismissAll()
		if cleared > 0 then
			stats.dismissals += 1
		end
		-- ...AND THEY ARE THE PARTY THAT GOES AGAIN. `Next.collect` clears every opt-out with it, so
		-- *"by default they are in"* is true at the start of every gap.
		nextDrive = NextDrive.collect(nextDrive, roster, now)
		if #roster > 0 then
			stats.nextParties += 1
		end
	end

	-- WHERE EVERYBODY IS STANDING, MEASURED ONCE (task 182). Both of the next two steps need it and
	-- a second pass would be a second answer to "which pad is he on".
	local lists, padOf = occupancy(occupants, now)

	-- THE PADS FIRST, because a pad that departs ENROLS its party inside this call -- and then
	-- `stepPlayer` sees `inDrive` true for those men on the same scan and hands their respawn and
	-- their countdown back, rather than giving a man the drive already has a lodge spawn for a tenth
	-- of a second.
	stepPads(lists, occupants, now)

	-- ...AND THEN THE PARTY THAT GOES AGAIN (task 246), in that order and for the pads' own stated
	-- reason: a pad that departed inside the call above has just ENROLLED its men, so this step sees
	-- `inDrive` true for them and drops them from the party on the same scan -- which is hazard 2 of
	-- the note (*"two enrolments for one man"*) closed by an ordering rather than by a second check.
	stepNextDrive(occupants, now)

	-- ONE READING OF THE SERVER CLOCK FOR THE WHOLE SCAN, so every member of one party is handed
	-- the same deadline to count down.
	local serverNow = Workspace:GetServerTimeNow()
	-- ...AND ONE READING OF WHO OWNS THE HUNTER'S PLACE (task 229), for the identical reason the
	-- clock above is read once: sixteen members would otherwise ask sixteen times. It is
	-- `Economy.alwaysHunters` -- the frozen MEMO, one table read -- and deliberately not
	-- `Economy.ownedOf`, which does `table.freeze(table.clone(set))` PER CALL and would be ~160
	-- clones a second at sixteen players.
	local owners: { [number]: boolean }? = if alwaysHunters ~= nil then alwaysHunters() else nil
	for _, player in ipairs(occupants) do
		stepPlayer(player, now, padOf[player.UserId], serverNow, owners)
	end

	-- WHO THE SHOPKEEPER LOOKS AT (task 181): the nearest man to him, decided HERE and written by
	-- `Build`, which keeps *"the one writer of every part in `Workspace.Lobby`"* true. It rides the
	-- scan this function already runs at `SCAN_HZ` -- there is no new clock, and no write at all
	-- unless the yaw moved more than `KEEPER.FACE_EPSILON_DEGREES`, which is why `keeperTurns`
	-- climbing with `scans` would be a bug and not a feature.
	local keeperAt = Build.keeperPosition()
	if keeperAt ~= nil then
		local nearest: Vector3? = nil
		local best = math.huge
		for _, player in ipairs(occupants) do
			local here = rootOf(player)
			if here ~= nil then
				local far = ((here :: Vector3) - (keeperAt :: Vector3)).Magnitude
				if far < best then
					nearest = here
					best = far
				end
			end
		end
		if Build.faceKeeper(nearest, cfg) then
			stats.keeperTurns += 1
		end
	end
end

-- Returns false when it built nothing, and says why. The boot reads the answer and only THEN takes
-- the drive's own enrolment away -- so "no lobby" is today's game and never a server nobody can join
-- a drive from (design section 7.4, last row).
function Lobby.start(injected: any?): boolean
	assert(not started, "Lobby.start() called twice")
	world = injected or {}
	cfg = world.config or Data.CONFIG
	local enabled = if world.enabled ~= nil then world.enabled == true else Lobby.ENABLED
	if not enabled then
		return false
	end
	-- `isHeld` IS REQUIRED AND NOT OPTIONAL (review round 1, note 6). It is the one thing stopping
	-- this module respawning a man out of Karen's results scene, and a boot that forgot it would get
	-- `held = false` in silence -- which is a lobby that works until the first drive ends.
	-- `depart` AND `remotes` ARE DELIBERATELY NOT IN THIS LIST (task 182). `depart` defaults to
	-- `Lobby.enrolHere`, which is the only implementation that exists, and a world that injects
	-- nothing gets the built path; `remotes` nil means there is no door, which is what every spec
	-- that drives `Lobby.onPadRequest` by parameter wants. Neither can be forgotten in a way that
	-- leaves the lobby half-working, which is the test the six below have to pass.
	for _, name in ipairs({ "enrol", "dismissAll", "inDrive", "isHeld", "place", "groundAt" }) do
		if type(world[name]) ~= "function" then
			warn(string.format("[lobby] start: no %s was injected, so nothing is built", name))
			return false
		end
	end
	local row = Data.anchorFor(world.world)
	if row == nil then
		-- NOT A FAILURE: a world with no row has no lobby, which is how the DEV place keeps today's
		-- behaviour without a second switch.
		return false
	end
	anchor = Vector3.new(row.x, 0, row.z)
	started = true
	degraded = false
	phase = nil
	dismissPending = false
	lastScan = -math.huge
	firstStepAt = nil
	nextSpawnIndex = 0
	table.clear(pads)
	table.clear(padAt)
	table.clear(arrived)
	table.clear(lastPadRequestAt)
	-- TASK 229: the wish table, its bucket and the memo over it, beside the four above.
	table.clear(roleWish)
	table.clear(lastRoleRequestAt)
	wishFrozen = nil
	-- TASK 246: the party that goes again, its verdict and its own bucket. A fresh `Next.initial()`
	-- rather than a `table.clear`, because the state is FROZEN -- which is the whole reason nothing
	-- outside `Lobby.Next` can write a membership.
	nextDrive = NextDrive.initial()
	nextVerdict = NextDrive.IDLE
	table.clear(lastNextRequestAt)
	table.clear(returnedAt)
	table.clear(spawnIndex)
	table.clear(touched)
	for key, value in pairs(stats) do
		if type(value) == "number" then
			stats[key] = 0
		end
	end
	stats.refusedBy = {}

	-- THE DOOR (task 182), and it is the LAST thing `start` does, so a `Connect` that throws cannot
	-- leave the lobby half-started.
	--
	-- GUARDED, because a seam that answers nothing must not take the boot down with it: a
	-- `RemoteEvent` double whose `Connect` returns nil is a legal stand-in -- a spec drives
	-- `Lobby.onPadRequest` by parameter, which is the whole point of that function being public --
	-- and `table.insert(t, nil)` throws. MEASURED in round 1 of task 178, where nine cases of
	-- `shop_door.spec` died inside `start` rather than failing an assertion.
	if world.remotes ~= nil and world.remotes.PadRequest ~= nil then
		local connection = world.remotes.PadRequest.OnServerEvent:Connect(function(player: Player, payload: any)
			Lobby.onPadRequest(player, payload)
		end)
		if connection ~= nil then
			table.insert(connections, connection)
		end
	end
	-- ...AND THE ROLE DOOR (task 229), guarded the same way and for the same measured reason: a
	-- `RemoteEvent` double whose `Connect` returns nil is a legal stand-in, because every spec drives
	-- `Lobby.onRoleRequest` by parameter.
	if world.remotes ~= nil and world.remotes.RoleRequest ~= nil then
		local connection = world.remotes.RoleRequest.OnServerEvent:Connect(function(player: Player, payload: any)
			Lobby.onRoleRequest(player, payload)
		end)
		if connection ~= nil then
			table.insert(connections, connection)
		end
	end
	-- ...AND THE SIT OUT DOOR (task 246), guarded the same way and for the same measured reason.
	if world.remotes ~= nil and world.remotes.NextRequest ~= nil then
		local connection = world.remotes.NextRequest.OnServerEvent:Connect(function(player: Player, payload: any)
			Lobby.onNextRequest(player, payload)
		end)
		if connection ~= nil then
			table.insert(connections, connection)
		end
	end
	return true
end

-- THE TEARDOWN ASSERTION EVERY OWNER'S SPEC MAKES: the folder is gone, every attribute it wrote is
-- nil, every `RespawnLocation` it set is handed back, and no table in this module is keyed by anybody.
function Lobby.stop()
	if not started then
		return
	end
	started = false
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	-- EVERY `DHPad*` ATTRIBUTE GOES WITH THE PADS (task 182), and it is `Destroy` that does it: the
	-- attributes live ON the pad parts, inside the folder, so there is nothing left to carry a stale
	-- state word. The tables are cleared below for the reason `touched` exists -- `stop` hands back
	-- exactly what this module wrote and nothing else.
	if folder then
		folder:Destroy()
	end
	folder = nil
	spawnPart = nil
	table.clear(pads)
	table.clear(padAt)
	table.clear(arrived)
	table.clear(lastPadRequestAt)
	table.clear(roleWish)
	table.clear(lastRoleRequestAt)
	wishFrozen = nil
	nextDrive = NextDrive.initial()
	nextVerdict = NextDrive.IDLE
	table.clear(lastNextRequestAt)
	-- TASK 249: the withdrawal latch, both rows. A stopped owner knows nothing about who left what.
	table.clear(leftDrive)
	table.clear(wasInDrive)
	-- EXACTLY WHAT IT WROTE AND NOTHING ELSE: the players this module actually touched, not every
	-- player on the server.
	for _, player in pairs(touched) do
		if
			player.Parent ~= nil
			or player:GetAttribute(Data.LEAVE_AT_ATTRIBUTE) ~= nil
			or player:GetAttribute(Data.PAD_MINE_ATTRIBUTE) ~= nil
			or player:GetAttribute(Data.ROLE_WISH_ATTRIBUTE) ~= nil
			or player:GetAttribute(Data.NEXT_AT_ATTRIBUTE) ~= nil
			or player:GetAttribute(Data.NEXT_OUT_ATTRIBUTE) ~= nil
			or player:GetAttribute(Data.LEFT_DRIVE_ATTRIBUTE) ~= nil
		then
			player:SetAttribute(Data.LEAVE_AT_ATTRIBUTE, nil)
			-- ...AND THE LOADING BANNER (task 197). It is the same teardown claim as the deadline
			-- beside it: an owner that stopped must leave nothing on anybody's screen, and this
			-- attribute is the banner's whole visibility rule.
			player:SetAttribute(Data.PAD_MINE_ATTRIBUTE, nil)
			-- ...AND THE ROLE SWITCH (task 229). Same claim again: with this owner stopped nobody
			-- owns anything as far as this module can tell, and the attribute's absence is what makes
			-- both controls disappear rather than go stale.
			player:SetAttribute(Data.ROLE_WISH_ATTRIBUTE, nil)
			-- ...AND THE NEXT DRIVE'S CARD (task 246). The same teardown claim a third time: an
			-- owner that stopped must leave no countdown on anybody's screen, and these two
			-- attributes are that card's whole visibility rule.
			player:SetAttribute(Data.NEXT_AT_ATTRIBUTE, nil)
			player:SetAttribute(Data.NEXT_OUT_ATTRIBUTE, nil)
			-- ...AND THE LINE THAT SAYS HE LEFT A DRIVE (task 249), for the same teardown claim: an
			-- owner that stopped must leave no sentence on anybody's screen.
			player:SetAttribute(Data.LEFT_DRIVE_ATTRIBUTE, nil)
			player.RespawnLocation = nil
		end
	end
	table.clear(touched)
	table.clear(returnedAt)
	table.clear(spawnIndex)
	world = nil
	anchor = nil
	phase = nil
	dismissPending = false
	degraded = false
end

-- After this, no table in this system is keyed by that player -- `Match.forget`'s own rule.
function Lobby.forget(userId: number)
	-- THE PADS HOLD NO TABLE KEYED BY HIM: a pad's members are DERIVED from where people are standing
	-- and are re-measured every scan, so there is nothing to forget there. These three are the ones
	-- that are.
	arrived[userId] = nil
	lastPadRequestAt[userId] = nil
	-- TASK 229: his wish and its bucket. A logout is what clears a wish without any rule at all --
	-- which is the whole of "nothing is persisted".
	if roleWish[userId] ~= nil then
		roleWish[userId] = nil
		wishFrozen = nil
	end
	lastRoleRequestAt[userId] = nil
	-- TASK 246: his bucket. HIS MEMBERSHIP IS NOT TOUCHED HERE, and that is deliberate rather than
	-- an omission: `Next.step` drops a man who is no longer `present` on the very next scan -- the
	-- level recount, which is the whole pattern (Quake III's `CheckIntermissionExit`) -- so clearing
	-- it here as well would be the same fact removed in two places, and the one that ran first would
	-- decide. `Lobby.stats().nextCleared` is what shows the last member leaving.
	lastNextRequestAt[userId] = nil
	-- TASK 249: the two rows of the withdrawal latch. A man who logs out has not *"left the
	-- drive"* -- he has left -- so neither row may survive him, or a new player landing on the same
	-- userId would read somebody else's sentence.
	leftDrive[userId] = nil
	wasInDrive[userId] = nil
	returnedAt[userId] = nil
	spawnIndex[userId] = nil
	touched[userId] = nil
end

return Lobby
