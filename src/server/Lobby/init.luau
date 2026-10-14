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
Lobby.Field = require(script.Field)
Lobby.Build = require(script.Build)

local Join = Lobby.Join
local Pads = Lobby.Pads
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
	enrolments = 0,
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
	dismissals = 0,
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
		local calls, grassCalls = Field.fill(world.terrain, seat, shelf :: number, cfg)
		stats.fillCalls = calls
		stats.grassCalls = grassCalls
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
			-- THE SAME READER THIS FUNCTION JUST USED FOR THE SHELF, handed down so each truck pad is
			-- laid on the ground that is really there (task 182). Measured in the live place: without
			-- it the four pads sat 0.17 studs UNDER the terrain and only their billboards showed,
			-- because Roblox terrain is voxelised and `Field.fill`'s surface is not exactly `shelfY`.
			groundAt = world.groundAt,
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
local function stepPlayer(player: any, now: number, padIndex: number?, serverNow: number)
	local userId = player.UserId
	local inDrive = world.inDrive(userId) == true
	if inDrive then
		-- HE IS IN THE HUNT. Nothing of the lobby's applies to him: no deadline on his screen, and no
		-- respawn point at the lodge -- `Match.Body` owns where he stands now.
		clearLeaveAt(player)
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
-- against `SIZE.X` 9 leaves 8 studs between them, so he cannot be inside two and the first match is
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
			if Build.setPad(index, pad.state, pad.firstUserId, #pad.members, pad.size) then
				stats.padWrites += 1
			end
		end
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
export type Departure = {
	padIndex: number,
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
-- `pcall`, because an injected seam that throws must not take the scan down with it: the party stays
-- standing on the pad and `Pads.step`'s own `leaving` fallback asks them again.
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
	if Build.setPad(found, after.state, after.firstUserId, #after.members, after.size) then
		stats.padWrites += 1
	end
	return { ok = true, size = size }
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
		local cleared = world.dismissAll()
		if cleared > 0 then
			stats.dismissals += 1
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

	-- ONE READING OF THE SERVER CLOCK FOR THE WHOLE SCAN, so every member of one party is handed
	-- the same deadline to count down.
	local serverNow = Workspace:GetServerTimeNow()
	for _, player in ipairs(occupants) do
		stepPlayer(player, now, padOf[player.UserId], serverNow)
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
	-- EXACTLY WHAT IT WROTE AND NOTHING ELSE: the players this module actually touched, not every
	-- player on the server.
	for _, player in pairs(touched) do
		if player.Parent ~= nil or player:GetAttribute(Data.LEAVE_AT_ATTRIBUTE) ~= nil then
			player:SetAttribute(Data.LEAVE_AT_ATTRIBUTE, nil)
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
	returnedAt[userId] = nil
	spawnIndex[userId] = nil
	touched[userId] = nil
end

return Lobby
