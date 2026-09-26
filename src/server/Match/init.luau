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
-- MILESTONE 1.7b turned both switches on: SAFETY_ENABLED ties a shooter who fires at a driver to a
-- tree for the rest of the drive, and Drive.CONFIG.SCOREBOARD_ENABLED shows the score screen. The
-- penalty adds one pure module (Penalty) and two effects (`freeze`, `release`); nothing else about
-- the machine changed.
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
local Penalty = require(script.Penalty)
local Phase = require(script.Phase)
local Roster = require(script.Roster)
local Score = require(script.Score)

local Match = {}

-- Exported for specs only, exactly as Boar.Brain and Weapon.StateMachine are.
Match.Phase = Phase
Match.Roster = Roster
Match.Score = Score
Match.Markers = Markers
Match.Penalty = Penalty
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

	-- the safety rule (design section 11.4). Karen's rule as written: tied to a tree until the drive
	-- ends, visible to everyone, announced in the feed.
	SAFETY_ENABLED = true,
	SAFETY_MISS_STUDS = 12, -- K, ~3.4 m: a shot that passes within three metres of a person is a shot at them
	SAFETY_RANGE_STUDS = 330, -- Shotgun.CONFIG.RANGE_STUDS.Slug; past it nothing arrives
	-- The depth of a person, added to where the shot stopped. See Penalty.judge: without it a shot
	-- that HITS a driver stops on his surface, a stud in front of his root, and would be judged
	-- harmless. reviews/task-35/DESIGN_DELTA.md.
	SAFETY_BODY_STUDS = 4,
	SAFETY_GRACE_SECONDS = 0, -- K, no grace: the rule is the rule from the first second
	TIE_UNTIL_DRIVE_END = true, -- K, Karen's rule as written
	TIE_SECONDS = 60, -- K, used only when the flag above is false (Penalty.expired)
	TIE_GAP_STUDS = 2.5, -- K, studs from the trunk's SURFACE, on the side the offender came from
	ROPE_COLOR = Color3.fromRGB(170, 130, 85), -- K, checked on screen: see the note in Body
	ROPE_THICKNESS = 0.3,

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
-- Who is tied, and to what. THE ONE TRUTH about it: mayCarryWeapon reads it, the snapshot reports it
-- and the release effect empties it. The pure machine does not track it -- two writers of one fact is
-- the failure docs/PROJECT_CONTEXT.md names three times.
local tied: { [number]: { tree: BasePart, at: number } } = {}
local characterWatch: { [number]: RBXScriptConnection } = {}
local pushCredit: { [string]: { [number]: number } } = {} -- boarId -> userId -> last time near
local accumulator = 0
local sinceSample = 0
local sinceMarkers = 0
local markersStale = false
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
	tiesWithoutAnchor = 0,
	violations = 0,
	safetySignalMissing = 0,
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

-- Is this player tied to a tree right now? The one public reader of `tied`, so a spec and the
-- weapon's arming policy ask the same question of the same table.
function Match.isTied(userId: number): boolean
	return tied[userId] ~= nil
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

-- Where a player is standing, or nil. Read-only.
local function characterPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character.PrimaryPart
	return if root then root.Position else nil
end

local function refreshArmingFor(player: Player)
	if world and world.weapon and world.weapon.refreshArming then
		world.weapon.refreshArming(player)
	end
end

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
	for _, userId in ipairs(userIds or {}) do
		local player = playersService():GetPlayerByUserId(userId)
		if player then
			refreshArmingFor(player)
		end
	end
end

local function applySpawnBoar(position: Vector3?)
	if not (world and world.boars) then
		return
	end
	-- NO SECOND GUARD. Phase.maybeRelease already decided, on the same live count this owner gives
	-- it; a second check here is what dropped releases in round 1. Runtime:spawn still ASSERTS at
	-- maxBoars and an assert inside the Heartbeat step would kill the step rather than the spawn, so
	-- the call is wrapped -- and a refusal HANDS THE RELEASE BACK, so it is retried on the next step
	-- instead of vanishing (design section 6.3: deferred, not dropped).
	local ok = pcall(function()
		world.boars:spawn(position)
	end)
	if ok then
		stats.releases += 1
	else
		stats.releasesDeferred += 1
		state = Phase.releaseFailed(state, now())
		snapshotCache = nil
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

-- One tie. The owner has already decided (the phase is Running, this shooter was not tied, the grace
-- is over and Penalty.judge said yes); this performs it, through Body, which is the only writer of a
-- character's position and of Workspace.DriveMarkers.
local function applyFreeze(userId: number)
	local player = playersService():GetPlayerByUserId(userId)
	if not player then
		return
	end
	-- The POINTS penalty lands either way: the shot was a violation whether or not the map gave us
	-- anything to tie him to. Only the tie itself needs an anchor.
	--
	-- AND THE AWARD IS PUBLISHED, like every other (TASKS.md 35b(b)): Score.violation returns
	-- (board, awards) and only the board was being taken, so Match.Scored carried kills and escapes
	-- but never the -50 -- a listener rebuilding the drive from that signal alone would have missed
	-- every penalty.
	local awards
	board, awards = Score.violation(board, userId, Match.CONFIG)
	for _, award in ipairs(awards) do
		scoredSignal:Fire(award)
	end
	stats.violations += 1

	-- WITHOUT AN ANCHOR THE VIOLATION STILL HAPPENED, and everything that does not need a tree still
	-- happens (TASKS.md 35b(c)): the points above, the feed line the machine emits, and Punished.
	-- Only the rope, the freeze and the revoked gun need somewhere to tie him. The half-state the
	-- review found was Punished going missing with them, so a listener saw a feed line and no event.
	local tree = if markerSet then Body.anchorFor(markerSet, characterPosition(player)) else nil
	if not tree or not Body.tie(player, tree, Match.CONFIG) then
		-- Never a nil CFrame, which would silently teleport him to the origin (design section 8.4).
		stats.tiesWithoutAnchor += 1
		snapshotCache = nil
		punishedSignal:Fire(userId, Penalty.REASON)
		return
	end
	tied[userId] = { tree = tree, at = now() }
	stats.ties += 1
	snapshotCache = nil -- the tie is part of the snapshot the broadcast effect is about to send
	-- The weapon still decides and still writes: mayCarryWeapon now says no, so the Tool goes.
	refreshArmingFor(player)
	punishedSignal:Fire(userId, Penalty.REASON)
end

local function untie(userId: number)
	tied[userId] = nil
	snapshotCache = nil
	local player = playersService():GetPlayerByUserId(userId)
	if player then
		Body.untie(player)
		refreshArmingFor(player)
	else
		Body.forget(userId)
	end
end

-- The end of a drive frees everybody, which is what TIE_UNTIL_DRIVE_END means.
local function applyRelease()
	for userId in pairs(tied) do
		untie(userId)
	end
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
		elseif kind == "freeze" then
			applyFreeze(effect.userId)
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
	-- EVERY event carries the live boar count, not just the tick. The release guard lives in the
	-- pure machine and reads this; a join or a leave that arrives at a release moment must see the
	-- same world a tick would (round 1, finding 1).
	local filled = table.clone(event)
	if filled.aliveBoars == nil then
		filled.aliveBoars = boarsAlive()
	end
	state, effects = Phase.step(state, filled, now(), Match.CONFIG)
	snapshotCache = nil
	applyEffects(effects)
	if state.phase ~= before then
		if state.phase == "Assigning" then
			-- A map rebuilt in Edit between drives is picked up without a server restart (design
			-- section 6.2). Read on the NEXT step, never from inside dispatch: readMarkers dispatches
			-- an event of its own, and a dispatch inside a dispatch would apply effects out of order.
			markersStale = true
			stats.drives += 1
			board = Score.new() -- scores are per drive
			for userId, name in pairs(names) do
				board = Score.join(board, userId, name, state.assignment[userId])
			end
			local counts = Roster.counts(state.assignment)
			if counts.Drivers == 0 or counts.Shooters == 0 then
				stats.emptyTeamDrives += 1
			end
			-- THE BOARD WAS REBUILT AFTER THE CACHE WAS CLEARED (TASKS.md 32a(c)). applyEffects runs
			-- above, and the `broadcast` effect inside it built and cached a snapshot from the
			-- PREVIOUS drive's rows; without this the drive-start push carried them for up to
			-- STATE_MIN_INTERVAL. Clearing it here costs one table build and cannot be stale.
			snapshotCache = nil
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
	end, playersService())
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

-- ------------------------------------------------------------------------------ the safety rule

-- Every live DRIVER, as Penalty.judge wants them. driverThreats keys by a string because that is the
-- shape the boar's world wants; this is the same read, keyed by number.
local function driverPositions(): { Penalty.DriverPos }
	local out = {}
	for _, driver in ipairs(Match.driverThreats()) do
		local userId = tonumber(driver.id)
		if userId then
			table.insert(out, { userId = userId, position = driver.position })
		end
	end
	return out
end

-- THE WEAPON PUBLISHED A SHOT INTO THE DRIVE; this decides whether it endangered anybody. Four
-- questions, and only the last one is Penalty's: is the drive live, is this shooter already tied, is
-- the grace over, and did the shot pass close to a driver (design section 8.3).
--
-- The weapon's 45-degree arc has already filtered the shot -- that is why this is called at all -- and
-- taking that cone as the verdict would tie everybody in the first minute, because a shooter on a post
-- faces the drive.
local function onSafetyViolation(player: Player, aim: Vector3, muzzle: Vector3, stopAt: number?)
	if not Match.CONFIG.SAFETY_ENABLED then
		return
	end
	if not Phase.isLive(state) then
		return -- no penalty outside the drive; shooting in Scoring is possible and pointless
	end
	if tied[player.UserId] then
		return -- already tied: a second violation changes nothing and fires Punished once
	end
	local at = now()
	-- The drive's own start, derived rather than stored: phaseEndsAt is the only clock in this system.
	local driveStartedAt = state.phaseEndsAt - Match.CONFIG.DRIVE_SECONDS
	if at - driveStartedAt < Match.CONFIG.SAFETY_GRACE_SECONDS then
		return
	end
	local shot: Penalty.Shot = {
		userId = player.UserId,
		muzzle = muzzle,
		aim = aim,
		stopAt = stopAt or Match.CONFIG.SAFETY_RANGE_STUDS,
		at = at,
	}
	local guilty = Penalty.judge(shot, driverPositions(), Match.CONFIG)
	if not guilty then
		return
	end
	dispatch({ kind = "violation", userId = player.UserId, name = player.Name, at = at })
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

	-- MEASURED, and it is the reason this is here at all: ArenaBoot and MatchBoot are two Scripts in
	-- ServerScriptService with no defined order, so Match.start can run BEFORE the arena exists. It
	-- did, on one harness run in three: the markers came back empty, the drive sat in Waiting for the
	-- whole session, nobody was armed and five specs went red for a reason none of them owned.
	-- Re-reading while Waiting costs five GetTagged calls a second and closes the race for good.
	sinceMarkers += dt
	if (state.phase == "Waiting" or markersStale) and sinceMarkers >= 1 then
		sinceMarkers = 0
		markersStale = false
		readMarkers()
	end
	-- TIE_SECONDS, and only when TIE_UNTIL_DRIVE_END is false. With Karen's value (true) Penalty.expired
	-- is always false and this loop never frees anybody -- the drive's `release` effect does.
	if not Match.CONFIG.TIE_UNTIL_DRIVE_END and next(tied) ~= nil then
		local at = now()
		local freed = false
		for userId, record in pairs(tied) do
			if Penalty.expired(record.at, at, Match.CONFIG) then
				untie(userId)
				freed = true
			end
		end
		if freed then
			broadcast(false)
		end
	end

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

-- A TIED PLAYER WHO RESPAWNS MUST NOT WALK AWAY FREE. Nothing damages players (shotgun design
-- section 15 item C), but the Reset button exists, and "press Escape, Reset, and the penalty is over"
-- is not a penalty. The tie is re-applied to the new character, at the same tree.
local function watchCharacter(player: Player)
	characterWatch[player.UserId] = player.CharacterAdded:Connect(function(character)
		local record = tied[player.UserId]
		if not record then
			return
		end
		task.spawn(function()
			if not character.PrimaryPart then
				character:GetPropertyChangedSignal("PrimaryPart"):Wait()
			end
			if tied[player.UserId] == record and record.tree.Parent then
				Body.tie(player, record.tree, Match.CONFIG)
				refreshArmingFor(player)
			end
		end)
	end)
end

local function watchPlayer(player: Player)
	names[player.UserId] = player.Name
	board = Score.join(board, player.UserId, player.Name, state.assignment[player.UserId])
	watchCharacter(player)
	dispatch({ kind = "join", userId = player.UserId, name = player.Name })
end

-- After this, NO table in this system is keyed by that player.
function Match.forget(player: Player)
	local userId = player.UserId
	names[userId] = nil
	if tied[userId] then
		-- The rope outlives nobody: the Instance goes with the player (design section 4.4).
		untie(userId)
	end
	Body.forget(userId)
	local watch = characterWatch[userId]
	if watch then
		watch:Disconnect()
		characterWatch[userId] = nil
	end
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
	table.clear(characterWatch)
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

	-- The weapon publishes a shot that went into the drive; this owner decides what it costs. The
	-- weapon writes nothing about the penalty and knows nothing about it (design section 8.2).
	if world.weapon and world.weapon.SafetyViolated then
		table.insert(connections, world.weapon.SafetyViolated:Connect(onSafetyViolation))
	elseif Match.CONFIG.SAFETY_ENABLED then
		-- A number in the harness report, not a safety rule that silently never fires.
		stats.safetySignalMissing += 1
		warn("[match] the weapon has no SafetyViolated signal: the safety rule cannot fire")
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
	applyRelease() -- nobody stays frozen because a spec stopped the match
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	for userId, watch in pairs(characterWatch) do
		watch:Disconnect()
		characterWatch[userId] = nil
	end
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
