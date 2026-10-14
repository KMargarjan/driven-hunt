--!strict
-- Lobby (server): THE OWNER OF THE LOBBY. The one writer of `Workspace.Lobby`, of the lobby's
-- terrain rectangle, of `Player.RespawnLocation` for a player who is not in the drive, of the
-- `DHLobbyLeaveAt` attribute -- and of WHO HAS ASKED TO HUNT.
--
-- KAREN, 2026-10-13 ~19:20: *"I think after this fixes we need to focus on lobby / Hunting house
-- where inside can shop things / outside is fields and forrest so house is in fields next to
-- forrest"*. Her two choices: a *"Wooden log lodge"*, and starting a hunt by *"Walk to a car"*.
--
-- WHAT THIS OWNS AND WHAT IT DOES NOT, because that boundary is the whole task (design section 4.5):
--   * it owns the lobby's WORLD (`Build`), the lobby's TERRAIN (`Field`), the RULE (`Join`, pure) and
--     the list of who has asked;
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
-- NO EVENTS, NO REMOTES, NO BINDABLES. It publishes one attribute per player, read by that player's
-- own client. **There is no inbound door at all**, so nothing a client sends can enrol anybody.
--
-- Design: docs/design/lobby.md (sections 3, 4, 7, 8, 11, 12.2)
-- Note:   docs/research/2026-10-13-lobby-and-the-truck.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Data = require(ReplicatedStorage:WaitForChild("Lobby"))
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))

local Lobby = {}

Lobby.Data = Data
Lobby.Join = require(script.Join)
Lobby.Field = require(script.Field)
Lobby.Build = require(script.Build)

local Join = Lobby.Join
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
local spotAt: Vector3? = nil
local lastScan = -math.huge
local firstStepAt: number? = nil
local degraded = false
local phase: string? = nil
local dismissPending = false
local entries: { [number]: any } = {}
local returnedAt: { [number]: number } = {}
local spawnIndex: { [number]: number } = {}
local nextSpawnIndex = 0
-- EVERY PLAYER THIS MODULE HAS WRITTEN TO, so `stop` hands back exactly what it wrote and nothing
-- else. Without it the teardown would have to walk `Players:GetPlayers()` and clear a
-- `RespawnLocation` it never set -- a write to somebody else's player, from a spec, in a place that
-- has no lobby.
local touched: { [number]: any } = {}

local stats = {
	scans = 0,
	buildAttempts = 0,
	buildMs = 0,
	shelfY = 0,
	parts = 0,
	fillCalls = 0,
	grassCalls = 0,
	enrolments = 0,
	cancels = 0,
	dismissals = 0,
	returns = 0,
	degradedEnrolments = 0,
	-- WHICH LODGE AND WHICH TRUCKS GOT BUILT (task 180): how many free-model templates were cloned
	-- and how many were asked for and not found. The boot prints them, so "the models are in" is a
	-- line in the console and not an inspection.
	models = 0,
	fallbacks = 0,
}

function Lobby.stats()
	return table.clone(stats)
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
local function tryBuild(): boolean
	local centre = anchor
	if centre == nil then
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
	local made, _marker, spawn, parts = Build.build(world.root or Workspace, seat, cfg, templates)
	stats.models = Build.stats().models
	stats.fallbacks = Build.stats().fallbacks
	folder = made
	spawnPart = spawn
	spotAt = seat + cfg.SPOT.OFFSET
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

local function stepPlayer(player: any, now: number)
	local userId = player.UserId
	local inDrive = world.inDrive(userId) == true
	if inDrive then
		-- HE IS IN THE HUNT. Nothing of the lobby's applies to him: no countdown, no deadline on his
		-- screen, and no respawn point at the lodge -- `Match.Body` owns where he stands now.
		entries[userId] = nil
		clearLeaveAt(player)
		setRespawn(player, nil)
		return
	end

	setRespawn(player, spawnPart)

	local here = rootOf(player)
	local inside = here ~= nil
		and spotAt ~= nil
		and Join.within(here :: Vector3, spotAt :: Vector3, cfg.SPOT.RADIUS_STUDS)
	local entry, verdict = Join.decide(entries[userId], inside, now, cfg)
	entries[userId] = entry
	if verdict == Join.COUNTING then
		-- THE DEADLINE IS THE SERVER'S, and it reaches his own client as one attribute. He counts it
		-- down locally, which is the one conversion `Match.snapshot`'s `phaseEndsAt` already
		-- establishes: a client-side countdown invented from a client-side position would read 0
		-- while the server had not enrolled him.
		--
		-- WRITTEN ONCE, ON THE `nil -> COUNTING` EDGE (review round 1, note 3), which is the same
		-- discipline `setRespawn` above already follows. It used to be written on every scan: ~50
		-- replicated attribute writes per walk-in, each one recomputing the SAME deadline from
		-- `GetServerTimeNow`. The client counts a fixed deadline down itself and has no use for a
		-- second copy of it.
		if player:GetAttribute(Data.LEAVE_AT_ATTRIBUTE) == nil then
			local leaveAt = Workspace:GetServerTimeNow() + math.max(0, (entry :: any).leaveAt - now)
			player:SetAttribute(Data.LEAVE_AT_ATTRIBUTE, leaveAt)
			touched[player.UserId] = player
		end
	elseif verdict == Join.CANCELLED then
		stats.cancels += 1
		clearLeaveAt(player)
	elseif verdict == Join.ENROL then
		-- CLEARED BEFORE THE ENROLMENT, because `enrol` reaches `LoadCharacter` inside the same call:
		-- with the lodge still set as his respawn, the engine would put the new character at the
		-- lodge and the drive's own pivot would have to beat it. `Body.place` + `Body.settle` already
		-- handle exactly that race in this place (measured in task 157); this simply does not create
		-- another instance of it.
		clearLeaveAt(player)
		setRespawn(player, nil)
		if world.enrol(player) then
			stats.enrolments += 1
		end
		return
	end

	-- BACK TO THE LODGE, BY A LEVEL RULE AND NOT BY AN EDGE (design section 8.1). `held` is
	-- load-bearing: during the results scene a dismissed player is not a participant and is 570 studs
	-- from the lodge, so without it this would respawn him out of Karen's results scene.
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

	for _, player in ipairs(occupants) do
		stepPlayer(player, now)
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
	table.clear(entries)
	table.clear(returnedAt)
	table.clear(spawnIndex)
	table.clear(touched)
	for key in pairs(stats) do
		stats[key] = 0
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
	if folder then
		folder:Destroy()
	end
	folder = nil
	spawnPart = nil
	spotAt = nil
	-- EXACTLY WHAT IT WROTE AND NOTHING ELSE: the players this module actually touched, not every
	-- player on the server.
	for _, player in pairs(touched) do
		if player.Parent ~= nil or player:GetAttribute(Data.LEAVE_AT_ATTRIBUTE) ~= nil then
			player:SetAttribute(Data.LEAVE_AT_ATTRIBUTE, nil)
			player.RespawnLocation = nil
		end
	end
	table.clear(touched)
	table.clear(entries)
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
	entries[userId] = nil
	returnedAt[userId] = nil
	spawnIndex[userId] = nil
	touched[userId] = nil
end

return Lobby
