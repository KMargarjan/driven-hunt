--!strict
-- Match: the owner of the drive (CLAUDE.md rule 3) -- the phase and its deadline, team membership,
-- every player's per-drive score, which boars exist while a drive runs, and the two outbound
-- RemoteEvents. It fills the `Game state` slot that has been `_unassigned_` in GAME_DESIGN.md since
-- Task 1.
--
-- It writes NO boar state (it calls runtime:spawn and reads handles), NO weapon state (it injects a
-- policy and asks the weapon to re-evaluate), nothing drawn, and no camera.
--
-- Pattern: a folder module that owns state over pure decision modules driven by an injected world --
-- the shape src/server/Boar/init.luau and src/server/Weapon/init.luau already are, at a third
-- instance. NOTHING HAPPENS ON REQUIRE: only Match.start(world) begins production, which is what
-- lets every spec in tests/server/match_*.spec.luau drive a whole drive with no players, no boars
-- and no clock.
--   Phase   pure: the state machine, returning state + an explicit effect list
--   Roster  pure: who is on which team
--   Score   pure: points
--   Markers read-only: the CollectionService tags
--   Body    the only writer of teams and of where a character stands
--
-- MILESTONE 1.7a. SAFETY_ENABLED and SCOREBOARD_ENABLED are false: the penalty and the score screen
-- are 1.7b (design section 0, Director decision A). Everything they need is here and dark.
--
-- Design: docs/design/drive.md
-- Note:   docs/research/2026-09-25-drive.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))

local Body = require(script.Body)
local Markers = require(script.Markers)
local Phase = require(script.Phase)
local Roster = require(script.Roster)
local Score = require(script.Score)

local Match = {}

-- Exported for specs only, exactly as Boar.Brain and Weapon.StateMachine are.
Match.Phase = Phase
Match.Roster = Roster
Match.Score = Score
Match.Markers = Markers
Match.Body = Body

-- Every number the drive has. K marks Karen's feel values. No magic number anywhere else in this
-- system, and none of this is replicated: a client that knows the safety numbers can dodge the rule
-- by eye (design section 3.4).
Match.CONFIG = {
	-- the drive
	DRIVE_SECONDS = 600, -- K, Karen: "10-minute drives"
	INTERMISSION_SECONDS = 20, -- K, long enough to read the teams and walk to your post
	SCORE_SECONDS = 25, -- K
	-- DIRECTOR DECISION F (audit-003 must-fix 1), Milestone 1 only: ONE player is a drive. A solo
	-- player is a SHOOTER and is armed, so the harness's single Play player keeps its gun and the
	-- weapon and camera client specs stay green. Raise to 2 before release.
	-- See reviews/task-32/DESIGN_DELTA.md.
	MIN_PLAYERS = 1,
	MAX_PLAYERS = 16,
	ODD_PLAYER_TEAM = "Shooters" :: any, -- K; see the delta: with one player this makes them a shooter
	SWAP_TEAMS_EACH_DRIVE = true, -- K, everybody wants to shoot
	DRIVERS_MAY_SHOOT = false, -- K, the brief: a switch, default OFF
	END_ON_LAST_BOAR = false, -- K, a drive is ten minutes, not "until the boars run out"
	PLACE_TIMEOUT = 5,
	STAND_HEIGHT_STUDS = 3.5, -- how far above a post's top face a character is put down

	-- boars (design section 6.3)
	BOARS_PER_DRIVE = 6, -- K
	FIRST_RELEASE_SECONDS = 20, -- K, the drivers need to be walking before the first boar moves
	RELEASE_INTERVAL_SECONDS = 90, -- K, 20 + 5*90 = 470 s, so the last boar has ~130 s of drive left
	RELEASE_JITTER_SECONDS = 15, -- K, so the drive is not a metronome
	MAX_ALIVE_BOARS = 4, -- never exceed Boar.CONFIG.maxBoars, and carcasses do not count

	-- points (design section 7.1)
	POINTS = {
		KILL = { head = 100, chest = 80, body = 50, legs = 30, unknown = 50 }, -- K
		ASSIST = 10, -- K
		ASSIST_MIN_DAMAGE = 25, -- K, a quarter of Boar.CONFIG.WOUND.LETHAL: one pellet is not an assist
		PUSH = 25, -- K, to a driver who was the reason it ran
		PUSH_RADIUS = 60, -- K, 1.5x Boar.CONFIG.DETECT_RADIUS
		PUSH_WINDOW = 20, -- K, seconds before the kill
		ESCAPE_WOUNDED = 0, -- K, "take the shot you can make"
		SAFETY_PENALTY = -50, -- K, 1.7b
	},
	PUSH_SAMPLE_HZ = 2,

	-- the safety rule: 1.7b. The switch exists so the Hud and the score are written once.
	SAFETY_ENABLED = false,

	-- the wire (design section 11.5)
	STATE_MIN_INTERVAL = 0.25,
	STATE_HEARTBEAT = 5,
	MATCH_STEP_HZ = 4,

	SEED = 1,
}

Drive.deepFreeze(Match.CONFIG)

type TeamName = Roster.TeamName

local world: any = nil
local started = false
local state = Phase.initial(Match.CONFIG)
local board = Score.new()
local markerSet: any = nil
local connections: { RBXScriptConnection } = {}
local heartbeat: RBXScriptConnection? = nil
local remotes: any = nil

local names: { [number]: string } = {} -- userId -> name, for the feed and the board
local tied: { [number]: boolean } = {} -- 1.7b; always empty in this milestone
local pushCredit: { [string]: { [number]: number } } = {} -- boarId -> userId -> last time near
local accumulator = 0
local sinceSample = 0
local lastBroadcast = -math.huge
local snapshotCache: any = nil

local stats = {
	drives = 0,
	kills = 0,
	escapes = 0,
	releases = 0,
	releasesDeferred = 0,
	placementsMissed = 0,
	emptyTeamDrives = 0,
	unknownZoneKills = 0,
	killSignalMissing = 0,
	broadcasts = 0,
	ties = 0,
}

local phaseSignal = Instance.new("BindableEvent")
local scoredSignal = Instance.new("BindableEvent")
local punishedSignal = Instance.new("BindableEvent")
Match.PhaseChanged = phaseSignal.Event
Match.Scored = scoredSignal.Event
Match.Punished = punishedSignal.Event

function Match.stats()
	return table.clone(stats)
end

function Match.phase(): string
	return state.phase
end

function Match.trackedPlayers(): number
	local n = 0
	for _ in pairs(names) do
		n += 1
	end
	return n
end

local function now(): number
	return if world and world.now then world.now() else os.clock()
end

local function playersService()
	return if world and world.players then world.players else Players
end

-- The ONE conversion from the server's own clock to the wire's. The server's logic runs on
-- world.now() (os.clock by default, which means nothing across the wire); the snapshot is the only
-- place server TIME appears, as a GetServerTimeNow timestamp the client counts down from locally.
local function serverTimeFor(deadline: number): number
	if deadline == math.huge then
		return 0
	end
	local remaining = math.max(0, deadline - now())
	local clock = if world and world.serverTime then world.serverTime() else Workspace:GetServerTimeNow()
	return clock + remaining
end

local function boarsAlive(): number
	if not (world and world.boars) then
		return 0
	end
	local alive = 0
	for _, handle in ipairs(world.boars:boars()) do
		local boarState = handle.state()
		if boarState ~= "DOWN" and boarState ~= "GONE" then
			alive += 1
		end
	end
	return alive
end

function Match.snapshot()
	if snapshotCache then
		return snapshotCache
	end
	local rows = {}
	for _, row in ipairs(Score.leaderboard(board)) do
		table.insert(rows, {
			userId = row.userId,
			name = row.name,
			team = row.team,
			points = row.points,
			kills = row.kills,
			assists = row.assists,
			pushes = row.pushes,
			violations = row.violations,
			left = row.left,
		})
	end
	local tiedList = {}
	for userId in pairs(tied) do
		table.insert(tiedList, userId)
	end
	table.sort(tiedList)

	snapshotCache = Drive.deepFreeze({
		phase = state.phase,
		phaseEndsAt = serverTimeFor(state.phaseEndsAt),
		driveNumber = state.driveNumber,
		boarsReleased = state.releasesDone,
		boarsLeft = math.max(0, Match.CONFIG.BOARS_PER_DRIVE - state.boarsAccounted),
		waitingFor = Phase.waitingFor(state, Match.CONFIG),
		rows = rows,
		tied = tiedList,
	})
	return snapshotCache
end

local function broadcast(force: boolean?)
	if not remotes then
		return
	end
	local at = now()
	if not force and at - lastBroadcast < Match.CONFIG.STATE_MIN_INTERVAL then
		return
	end
	lastBroadcast = at
	stats.broadcasts += 1
	remotes.MatchState:FireAllClients(Match.snapshot())
end

local function publishFeed(entry)
	if not remotes then
		return
	end
	local filled = table.clone(entry)
	if filled.userId and not filled.name then
		filled.name = names[filled.userId]
	end
	remotes.MatchEvent:FireAllClients(Drive.deepFreeze(filled))
end

-- ----------------------------------------------------------------------------------- the effects
-- The pure machine says what must happen; this is the only place any of it is done.

local function applyAssignTeams(assignment)
	for userId, team in pairs(assignment) do
		local player = playersService():GetPlayerByUserId(userId)
		if player then
			Body.setTeam(player, team)
		end
		board = Score.setTeam(board, userId, team)
	end
end

local function indexWithinTeam(userId: number, team: TeamName): number
	local ids = {}
	for id, assigned in pairs(state.assignment) do
		if assigned == team then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for index, id in ipairs(ids) do
		if id == userId then
			return index
		end
	end
	return 1
end

local function applyPlace(userIds: { number }?)
	local targets = userIds
	if not targets then
		targets = {}
		for userId in pairs(state.assignment) do
			table.insert(targets, userId)
		end
		table.sort(targets)
	end
	for _, userId in ipairs(targets :: { number }) do
		local player = playersService():GetPlayerByUserId(userId)
		local team = state.assignment[userId]
		if player and team and markerSet then
			local cframe = Body.placementFor(markerSet, team, indexWithinTeam(userId, team), Match.CONFIG)
			Body.place(player, cframe, Match.CONFIG, function(ok)
				if not ok then
					stats.placementsMissed += 1
				end
			end)
		end
	end
end

local function applyRefreshArming(userIds: { number }?)
	if not (world and world.weapon and world.weapon.refreshArming) then
		return
	end
	for _, userId in ipairs(userIds or {}) do
		local player = playersService():GetPlayerByUserId(userId)
		if player then
			world.weapon.refreshArming(player)
		end
	end
end

local function applySpawnBoar(position: Vector3?)
	if not (world and world.boars) then
		return
	end
	if boarsAlive() >= Match.CONFIG.MAX_ALIVE_BOARS then
		stats.releasesDeferred += 1
		return
	end
	-- Runtime:spawn ASSERTS at maxBoars, and an assert inside the Heartbeat step would kill the
	-- step rather than the spawn, so this checks before it calls (design section 6.3).
	local ok = pcall(function()
		world.boars:spawn(position)
	end)
	if ok then
		stats.releases += 1
	else
		stats.releasesDeferred += 1
	end
end

local function applyClearBoars()
	-- Through the BOAR's own owner, never by touching an Instance: Boar.Body is the only writer of
	-- a boar's Instances, so the runtime grew a `clear` of its own (Runtime:clear) rather than this
	-- system reaching into Workspace.Boars.
	if world and world.boars and world.boars.clear then
		world.boars:clear("driveOver")
	end
	table.clear(pushCredit)
end

local function applyRelease()
	-- 1.7b: nobody is ever tied while SAFETY_ENABLED is false, so this frees an empty set.
	table.clear(tied)
end

local function applyEffects(effects)
	for _, effect in ipairs(effects) do
		local kind = effect.kind
		if kind == "assignTeams" then
			applyAssignTeams(effect.assignment)
		elseif kind == "placePlayers" then
			applyPlace(effect.userIds)
		elseif kind == "refreshArming" then
			applyRefreshArming(effect.userIds)
		elseif kind == "spawnBoar" then
			applySpawnBoar(effect.position)
		elseif kind == "clearBoars" then
			applyClearBoars()
		elseif kind == "release" then
			applyRelease()
		elseif kind == "feed" then
			publishFeed(effect.entry)
		elseif kind == "broadcast" then
			-- Throttled, not forced: STATE_MIN_INTERVAL is the floor between pushes, and the
			-- heartbeat below is what guarantees a client that missed one still catches up.
			broadcast(false)
		end
	end
end

-- The one place the machine is driven. Every caller goes through here, so the phase can never
-- advance without its effects being applied and the snapshot cache can never go stale.
local function dispatch(event)
	local before = state.phase
	local driveBefore = state.driveNumber
	local effects
	state, effects = Phase.step(state, event, now(), Match.CONFIG)
	snapshotCache = nil
	applyEffects(effects)
	if state.phase ~= before then
		if state.phase == "Assigning" then
			stats.drives += 1
			board = Score.new() -- scores are per drive
			for userId, name in pairs(names) do
				board = Score.join(board, userId, name, state.assignment[userId])
			end
			local counts = Roster.counts(state.assignment)
			if counts.Drivers == 0 or counts.Shooters == 0 then
				stats.emptyTeamDrives += 1
			end
		end
		phaseSignal:Fire(before, state.phase, state.driveNumber)
	elseif state.driveNumber ~= driveBefore then
		phaseSignal:Fire(before, state.phase, state.driveNumber)
	end
end

-- ------------------------------------------------------------------------------- the boar's side

-- Drivers only. A shooter standing on a post must not push the boar back into the wood before it
-- reaches the line, which is the whole mechanic.
function Match.driverThreats()
	return Body.driverPositions(function(player)
		return state.assignment[player.UserId]
	end)
end

function Match.driveLine()
	return if markerSet then markerSet.line else nil
end

-- The weapon still decides and still writes; this only answers the question.
function Match.mayCarryWeapon(player: Player): boolean
	if state.phase == "Waiting" then
		return false
	end
	if tied[player.UserId] then
		return false
	end
	local team = state.assignment[player.UserId]
	if team == "Shooters" then
		return true
	end
	return team == "Drivers" and Match.CONFIG.DRIVERS_MAY_SHOOT
end

-- Distance sampling, twice a second: which DRIVERS were near which boar, so a kill can pay the
-- people who pushed it. Distance only -- this system casts no rays at all.
local function samplePush()
	if not (world and world.boars) or not Phase.isLive(state) then
		return
	end
	local drivers = Match.driverThreats()
	if #drivers == 0 then
		return
	end
	local at = now()
	for _, handle in ipairs(world.boars:boars()) do
		local boarPosition = handle.position()
		local credit = pushCredit[handle.id]
		if not credit then
			credit = {}
			pushCredit[handle.id] = credit
		end
		for _, driver in ipairs(drivers) do
			if (driver.position - boarPosition).Magnitude <= Match.CONFIG.POINTS.PUSH_RADIUS then
				credit[tonumber(driver.id) :: number] = at
			end
		end
	end
end

local function creditFor(boarId: string?): { [number]: number }
	local out = {}
	local credit = if boarId then pushCredit[boarId] else nil
	if not credit then
		return out
	end
	local at = now()
	for userId, seen in pairs(credit) do
		if at - seen <= Match.CONFIG.POINTS.PUSH_WINDOW then
			out[userId] = seen
		end
	end
	return out
end

local function onDowned(record)
	if not Phase.isLive(state) then
		return -- a shot at a carcass between drives scores nothing
	end
	stats.kills += 1
	if record.killingZone == nil or Match.CONFIG.POINTS.KILL[record.killingZone] == nil then
		stats.unknownZoneKills += 1
	end
	local awards
	board, awards = Score.kill(board, record, creditFor(record.id), Match.CONFIG)
	for _, award in ipairs(awards) do
		scoredSignal:Fire(award)
	end
	pushCredit[record.id] = nil
	dispatch({
		kind = "kill",
		userId = record.killedByUserId,
		name = record.killedByName,
		record = record,
	})
end

local function onDespawned(record)
	if record.reason ~= "escaped" then
		pushCredit[record.id] = nil
		return -- "killed" is the carcass leaving, and the kill was already scored
	end
	if not Phase.isLive(state) then
		return
	end
	stats.escapes += 1
	local awards
	board, awards = Score.escape(board, record, Match.CONFIG)
	for _, award in ipairs(awards) do
		scoredSignal:Fire(award)
	end
	pushCredit[record.id] = nil
	dispatch({ kind = "gone", record = record })
end

-- ------------------------------------------------------------------------------------ lifecycle

local function readMarkers()
	markerSet = if world.markers then world.markers else Markers.read(world.collection)
	dispatch({
		kind = "markers",
		complete = markerSet.complete,
		missing = markerSet.missing,
		boarSpawns = markerSet.boarSpawns,
	})
end

function Match:step(dt: number)
	if not started then
		return
	end
	accumulator += dt
	sinceSample += dt
	local interval = 1 / Match.CONFIG.MATCH_STEP_HZ
	if sinceSample >= 1 / Match.CONFIG.PUSH_SAMPLE_HZ then
		sinceSample = 0
		samplePush()
	end
	if accumulator < interval then
		return
	end
	accumulator = 0
	dispatch({ kind = "tick", aliveBoars = boarsAlive() })
	if now() - lastBroadcast >= Match.CONFIG.STATE_HEARTBEAT then
		broadcast(true)
	end
end

local function watchPlayer(player: Player)
	names[player.UserId] = player.Name
	board = Score.join(board, player.UserId, player.Name, state.assignment[player.UserId])
	dispatch({ kind = "join", userId = player.UserId, name = player.Name })
end

-- After this, NO table in this system is keyed by that player.
function Match.forget(player: Player)
	local userId = player.UserId
	names[userId] = nil
	tied[userId] = nil
	board = Score.leave(board, userId)
	for _, credit in pairs(pushCredit) do
		credit[userId] = nil
	end
	dispatch({ kind = "leave", userId = userId, name = player.Name })
end

function Match.start(injected)
	assert(not started, "Match.start() called twice")
	started = true
	world = injected or {}
	state = Phase.initial(Match.CONFIG)
	board = Score.new()
	table.clear(names)
	table.clear(tied)
	table.clear(pushCredit)
	snapshotCache = nil

	if world.remotes ~= false then
		remotes = world.remotes or Drive.remotes()
	end

	Body.ensureTeams()
	readMarkers()

	if world.boars then
		if world.boars.Downed then
			table.insert(connections, world.boars.Downed:Connect(onDowned))
		else
			-- A missing dependency shows as a number in the harness report rather than as a match
			-- that silently scores zero (design section 7.4).
			stats.killSignalMissing += 1
			warn("[match] the boar runtime has no Downed signal: kills will not score")
		end
		if world.boars.Despawned then
			table.insert(connections, world.boars.Despawned:Connect(onDespawned))
		end
	end

	local service = playersService()
	for _, player in ipairs(service:GetPlayers()) do
		watchPlayer(player)
	end
	table.insert(connections, service.PlayerAdded:Connect(watchPlayer))
	table.insert(
		connections,
		service.PlayerRemoving:Connect(function(player)
			Match.forget(player)
		end)
	)

	if world.heartbeat ~= false then
		heartbeat = RunService.Heartbeat:Connect(function(dt)
			Match:step(dt)
		end)
	end
end

function Match.stop()
	if not started then
		return
	end
	started = false
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	world = nil
	remotes = nil
	markerSet = nil
end

-- DELIBERATELY NOT DESTROYED HERE: the design has stop() destroy the three signals, but this is
-- a singleton ModuleScript that production and every spec share, and a destroyed BindableEvent stays
-- destroyed for the rest of the session -- the next spec to require Match would get a dead module.
-- stop() disconnects everything it connected, which is what the teardown assertion checks.
-- reviews/task-32/DESIGN_DELTA.md records it.

return Match
