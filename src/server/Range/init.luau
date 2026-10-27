-- Range: the lobby shooting range's STATE and its ROUTE. The owner (CLAUDE.md rule 3) of which
-- trial each spot is running, and the ONE caller of `Build`.
--
-- WHAT IT IS NOT. It is not a writer of an animal's position: *"the range issues a ROUTE and nothing
-- else"* (design section 6). `Boar.Brain` decides and `Boar.Body` writes, through the shipped
-- `Runtime:leadTo(id, point, speed)` door -- *"WALK TO THIS POINT AT THIS SPEED ... re-issued every
-- step; it expires by itself"* -- which is the door the forest drive already steers a line with
-- (`ForestTest`'s `leadIfFree`). There is no `.CFrame =` in this folder outside `Build`'s own parts.
--
-- Design: docs/design/shooting-range.md sections 2, 5, 6, 8.1 and 11.1. Task 298, step B2:
-- the lane, the owner and the spec. No menu, no gun, no board, no remote -- those are B3 and B4.
--
-- NOTHING HAPPENS ON REQUIRE, the rule `Match`, `Boar`, `Weapon` and `Lobby` all follow. Every fact
-- is INJECTED, so this module requires no other owner: the world's name, the ground reader, the
-- clock, and a narrow VIEW of one `Boar` runtime (`ForestTest.readOnlyBoars`' shape).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
-- THE SHOP'S PURE DATA ONLY, for one question: which item ids are a gun or a cartridge. The range
-- calls no `Economy` and spends nothing (design section 1, "must NOT"); `Weapon` reads this table
-- for the same reason (its own task-178 note).
local Shop = require(ReplicatedStorage:WaitForChild("Shop"))

local Build = require(ServerScriptService:WaitForChild("Range"):WaitForChild("Build"))

local Range = {}

Range.Build = Build
Range.LAYOUT = RangeData.LAYOUT

-- THE ONE BOUNDARY THAT READS THE FLAG (CLAUDE.md "Feature flags"), passed inward as
-- `seams.enabled` so both states are reachable by parameter while the flag sits at one of them.
Range.ENABLED = Flags.isOn("RANGE")

Range.CONFIG = {
	-- One scan in ten, not one per frame: `Lobby`'s rule, and the range has nothing to say at 60 Hz.
	STEP_HZ = 10,
	-- The drive's own arrival number (`ForestTest.CONFIG.LINE.WAYPOINT_STUDS`'s 6): inside this of
	-- the end of the lane, the leg is done and the direction flips.
	WAYPOINT_STUDS = 6,
	-- Hold the carcass so the player sees what he did, then clear it and release a fresh target.
	-- Death is the hunt's, not the range's (design section 6).
	CARCASS_SECONDS = 3,
	RELEASE_SECONDS = 2,
	-- STAND (Karen, 2026-10-27): within this of the lane's middle counts as standing. The BRAIN
	-- stops the animal itself inside `LINE.ARRIVE_STUDS` (1.0) -- *"ARRIVED: hold the heading and
	-- stop, rather than jittering on top of the point"* -- so STAND is the same `leadTo` seam with
	-- the lane's MIDDLE as its point and no second writer anywhere. 2 studs is that 1.0 plus one
	-- 10 Hz step of walk (0.45).
	STAND_HOLD_STUDS = 2,
	-- One target per spot, never a sounder.
	MAX_TARGETS = RangeData.LAYOUT.SPOT_COUNT,
	MAX_PARTS = 150,
	DEFAULT_SPECIES = "boar",
	DEFAULT_KIND = "male",
	DEFAULT_PACE = RangeData.WORD.TROT,
	-- TARGET 3: the measured crossing of the window, against `window / Boar.paceSpeed`.
	CROSSING_TOLERANCE = 0.10,
	-- KAREN, 2026-10-27: *"range is free and amunition is endless"*. STEP B3 READS EXACTLY THESE TWO
	-- when it relaxes `mayShoot`'s two providers (arming and drive-open) and the pocket; nothing in
	-- step B2 reads them, and they are named here so B3 has one place to look.
	FREE = true,
	ENDLESS_AMMO = true,
}

-- Frozen for `Range.LAYOUT`'s reason, by the same function: no run-time writer, enforced.
RangeData.deepFreeze(Range.CONFIG)

type Trial = {
	spot: number,
	species: string,
	kind: string,
	pace: string,
	speedStudsPerSecond: number,
	distanceStuds: number,
	targetId: string?,
	leg: number,
	crossings: number,
	lastCrossingSeconds: number?,
	crossingSecondsByPace: { [string]: number },
	directions: { [string]: number },
	standSeconds: number,
	windowEnteredAt: number?,
	windowLeg: number?,
	carcassAt: number?,
	releaseAt: number?,
}

local state = {
	started = false,
	built = nil :: any,
	anchor = nil :: Vector3?,
	row = nil :: any,
	root = nil :: Instance?,
	boars = nil :: any,
	now = nil :: (() -> number)?,
	trials = {} :: { [number]: Trial },
	acc = 0,
	stats = {
		scans = 0,
		leadTos = 0,
		spawns = 0,
		clears = 0,
		crossings = 0,
		flips = 0,
		skippedFlying = 0,
		carcasses = 0,
		releases = 0,
		lostTargets = 0,
		parts = 0,
		buildMs = 0,
		refusedBy = nil :: string?,
	},
}

local function clockNow(): number
	local now = state.now
	return if now then now() else os.clock()
end

local function paceSpeed(pace: string): number
	local boars = state.boars
	-- WHICH PACE IS HOW MANY STUDS PER SECOND HAS ONE ANSWER IN THE REPOSITORY -- `Boar.paceSpeed`
	-- (moved there from `ForestTest` by this task) -- and it arrives INJECTED, because this module
	-- requires no owner (design section 3). The root wires it as
	-- `function(word) return Boar.paceSpeed(word, runtime:config()) end`, so the range invents no
	-- speed and there is no second copy of the arithmetic.
	if boars == nil or boars.paceSpeed == nil then
		return 0
	end
	return boars.paceSpeed(pace) or 0
end

local function newTrial(spot: number, pace: string): Trial
	return {
		spot = spot,
		species = Range.CONFIG.DEFAULT_SPECIES,
		kind = Range.CONFIG.DEFAULT_KIND,
		pace = pace,
		speedStudsPerSecond = paceSpeed(pace),
		distanceStuds = RangeData.LAYOUT.DISTANCE_STUDS,
		targetId = nil,
		leg = 1,
		crossings = 0,
		lastCrossingSeconds = nil,
		crossingSecondsByPace = {},
		directions = {},
		standSeconds = 0,
		windowEnteredAt = nil,
		windowLeg = nil,
		carcassAt = nil,
		releaseAt = nil,
	}
end

function Range.isBuilt(): boolean
	return state.built ~= nil
end

function Range.stats()
	local out = table.clone(state.stats)
	out.started = state.started
	out.built = Range.isBuilt()
	out.targets = 0
	for _, trial in pairs(state.trials) do
		if trial.targetId ~= nil then
			out.targets += 1
		end
	end
	return out
end

function Range.trialOf(spot: number): Trial?
	local trial = state.trials[spot]
	if trial == nil then
		return nil
	end
	local copy = table.clone(trial) :: any
	copy.crossingSecondsByPace = table.clone(trial.crossingSecondsByPace)
	copy.directions = table.clone(trial.directions)
	return copy
end

-- WHICH MAT, against the anchor this range was actually built on. Step B3's `mayShoot` is this plus
-- one position read.
function Range.spotAt(position: Vector3?): number?
	if state.anchor == nil then
		return nil
	end
	return RangeData.spotAt(state.anchor, position, RangeData.LAYOUT)
end

-- ------------------------------------------------------------------ THE ONE PREDICATE (7.4)

-- MAY THIS MAN SHOOT HERE? Server-measured: his own character's root, on a mat, in a world where the
-- range is actually built. It answers; the WEAPON still decides and still refuses (design 7.4).
function Range.mayShoot(player: any): boolean
	if not state.started or state.anchor == nil or player == nil then
		return false
	end
	local ok, position = pcall(function(): Vector3?
		local character = (player :: any).Character
		if typeof(character) ~= "Instance" then
			return nil
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			return nil
		end
		return root.Position
	end)
	if not ok or position == nil then
		return false
	end
	return Range.spotAt(position) ~= nil
end

-- WHAT IS ON LOAN AT A SPOT. KAREN, 2026-10-27: *"range is free and amunition is endless"*, all four
-- guns owned or not -- so every row that grants a GUN or a CARTRIDGE, plus the shipped unlimited-ammo
-- entitlement. No licence, no outfit, no drive gun: a loan is not a purchase.
--
-- A ROW IS LENT ONLY IF IT GRANTS *NOTHING BUT* A GUN AND/OR A CARTRIDGE, walked over
-- `Shop.GRANT_FIELDS` (review round 1, finding 1). A BUNDLE's grants are MERGED at module load, so
-- `bundle.season.grants.weapon` is set AND so are `driveGun`, `alwaysHunter` and `highSeat`: the
-- weaker rule lent a 3750-coin package at a free range.
local function loanSet(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, id in ipairs(Shop.ALL_ORDER) do
		local row = Shop.anyRow(id)
		local grants = if row ~= nil then row.grants else nil
		if grants ~= nil and (grants.weapon ~= nil or grants.ammo ~= nil) then
			local onlyAGun = true
			for _, field in ipairs(Shop.GRANT_FIELDS) do
				if field ~= "weapon" and field ~= "ammo" and grants[field] ~= nil then
					onlyAGun = false
					break
				end
			end
			if onlyAGun then
				out[id] = true
			end
		end
	end
	if Range.CONFIG.ENDLESS_AMMO then
		out[Shop.ITEM.UNLIMITED_AMMO] = true
	end
	return out
end

Range.LOAN = loanSet()
RangeData.deepFreeze(Range.LOAN)

-- THE THREE COMPOSED PROVIDERS, BUILT HERE AND INSTALLED BY THE COMPOSITION ROOT. They are pure
-- functions of a base provider, so a spec drives the real thing by parameter rather than a copy of
-- it (design 11.1 item 8); `RangeBoot` is their only other caller.
--
-- ARMING: not a participant means no Tool at all, so a man on the mat must be armed anyway.
function Range.armingOver(base: ((any) -> boolean)?): (any) -> boolean
	return function(player: any): boolean
		if Range.mayShoot(player) then
			return true
		end
		return if base ~= nil then base(player) == true else false
	end
end

-- DRIVE OPEN: `Rules.driveClosed` refuses the trigger between drives, which is every minute a man
-- stands in the lobby. nil stays "nobody said", the default every provider on `Weapon` takes.
function Range.driveOpenOver(base: ((any) -> boolean?)?): (any) -> boolean?
	return function(player: any): boolean?
		if Range.mayShoot(player) then
			return true
		end
		return if base ~= nil then base(player) else nil
	end
end

-- ENTITLEMENT: the loan, through the SHIPPED path and never a second ammo counter -- `Weapon.grant`
-- asks `Shop.startFor(row, owned)`, and `ammo.unlimited` is what fills the `unlimited` pockets the
-- reducer already reads. Off the mat the base answer is handed back untouched.
function Range.entitlementOver(base: ((any) -> { [string]: boolean }?)?): (any) -> { [string]: boolean }?
	return function(player: any): { [string]: boolean }?
		local owned = if base ~= nil then base(player) else nil
		if not Range.mayShoot(player) then
			return owned
		end
		local out: { [string]: boolean } = if type(owned) == "table" then table.clone(owned :: any) else {}
		for id in pairs(Range.LOAN) do
			out[id] = true
		end
		return out
	end
end

-- THE PACE, FOR ONE SPOT. In step B2 the Director and the spec are the only callers; step B4's
-- `Range.onRequest` validates a player's pick with `RangeData.optionAllowed` and then calls this.
function Range.setPace(spot: number, pace: string): boolean
	local trial = state.trials[spot]
	if trial == nil or not RangeData.paceAllowed(pace) then
		return false
	end
	trial.pace = pace
	trial.speedStudsPerSecond = paceSpeed(pace)
	trial.windowEnteredAt = nil
	trial.windowLeg = nil
	trial.standSeconds = 0
	return true
end

function Range.start(seams): boolean
	if state.started then
		return false
	end
	seams = seams or {}
	local enabled = if seams.enabled == nil then Range.ENABLED else seams.enabled == true
	if not enabled then
		state.stats.refusedBy = "flag"
		return false
	end
	local row = seams.anchor or RangeData.anchorFor(seams.world)
	if row == nil then
		state.stats.refusedBy = "no row"
		return false
	end
	local root = seams.root or Workspace
	local built, why = Build.build({
		parent = root,
		row = row,
		layout = RangeData.LAYOUT,
		groundAt = seams.groundAt,
	})
	if built == nil then
		state.stats.refusedBy = why or "build refused"
		return false
	end

	state.started = true
	state.built = built
	state.anchor = built.anchor
	state.row = row
	state.root = root
	state.boars = seams.boars
	state.now = seams.now
	state.acc = 0
	state.trials = {}
	-- THE COUNTERS DESCRIBE ONE RUN, AND THAT IS NOT A TIDINESS POINT (review round 1, finding 2):
	-- carried over from the last `start` they can only ever rise, so an assertion like
	-- `flips >= 1` passes with the code that flips deleted. `scans` and the rest start here.
	for key, value in pairs(state.stats) do
		if type(value) == "number" then
			state.stats[key] = 0
		end
	end
	state.stats.parts = built.parts
	state.stats.buildMs = built.buildMs
	state.stats.refusedBy = nil
	for spot = 1, RangeData.LAYOUT.SPOT_COUNT do
		state.trials[spot] = newTrial(spot, Range.CONFIG.DEFAULT_PACE)
	end
	print(string.format("[range] built in %d ms (%d parts)", built.buildMs, built.parts))
	return true
end

-- HANDS BACK EXACTLY WHAT IT WROTE: its own folder, and the targets it asked for. It never clears
-- an animal it did not release, because the view it was handed is its own runtime's.
function Range.stop()
	if state.boars ~= nil and state.boars.clear ~= nil then
		local any = false
		for _, trial in pairs(state.trials) do
			if trial.targetId ~= nil then
				any = true
			end
		end
		if any then
			state.boars.clear("range stop")
			state.stats.clears += 1
		end
	end
	if state.built ~= nil and state.built.folder ~= nil then
		state.built.folder:Destroy()
	end
	state.started = false
	state.built = nil
	state.anchor = nil
	state.row = nil
	state.root = nil
	state.boars = nil
	state.now = nil
	state.trials = {}
	state.acc = 0
end

local function release(trial: Trial)
	local boars = state.boars
	if boars == nil or boars.spawn == nil or state.anchor == nil then
		return
	end
	-- Released at the end the next leg STARTS from, so the first thing it does is cross.
	local from = RangeData.laneEnds(state.anchor :: Vector3, RangeData.LAYOUT, trial.leg + 1)
	local handle = boars.spawn(from, trial.kind)
	if handle == nil or handle.id == nil then
		return
	end
	trial.targetId = handle.id
	trial.carcassAt = nil
	trial.releaseAt = nil
	trial.windowEnteredAt = nil
	trial.windowLeg = nil
	state.stats.spawns += 1
end

-- THE WINDOW TIMER (TARGET 3). It times the target's passage through `WINDOW_STUDS` of OPEN lane,
-- not the whole leg: the aprons exist for the turn-around and a crossing is what the shooter sees.
local function timeWindow(trial: Trial, position: Vector3, now: number)
	local centre = RangeData.laneCentre(state.anchor :: Vector3, RangeData.LAYOUT)
	local inside = math.abs(position.X - centre.X) <= RangeData.LAYOUT.WINDOW_STUDS / 2
	if inside then
		if trial.windowEnteredAt == nil then
			trial.windowEnteredAt = now
			trial.windowLeg = trial.leg
		end
		return
	end
	if trial.windowEnteredAt ~= nil then
		if trial.windowLeg == trial.leg then
			local seconds = now - (trial.windowEnteredAt :: number)
			trial.lastCrossingSeconds = seconds
			trial.crossingSecondsByPace[trial.pace] = seconds
			trial.crossings += 1
			state.stats.crossings += 1
		end
		trial.windowEnteredAt = nil
		trial.windowLeg = nil
	end
end

local function order(trial: Trial, position: Vector3, dt: number)
	local boars = state.boars
	local anchor = state.anchor :: Vector3
	local layout = RangeData.LAYOUT
	local point, speed, direction

	if trial.pace == RangeData.WORD.STAND then
		-- STAND: the lane's MIDDLE, through the same seam. The animal walks there and the Brain
		-- stops it inside `LINE.ARRIVE_STUDS` -- the Brain's own idle, not a speed this module
		-- invents and not a CFrame it writes.
		point = RangeData.laneCentre(anchor, layout)
		speed = paceSpeed(RangeData.WORD.WALK)
		direction = "middle"
		if
			(Vector3.new(position.X, 0, position.Z) - Vector3.new(point.X, 0, point.Z)).Magnitude
			<= Range.CONFIG.STAND_HOLD_STUDS
		then
			trial.standSeconds += dt
		end
	else
		point = RangeData.laneEnds(anchor, layout, trial.leg)
		-- THE FLIP, and it is the range's reason to exist in one line: ISSF's mandatory direction
		-- change, so neither shoulder is favoured and no single lead is ever trained.
		if
			(Vector3.new(position.X, 0, position.Z) - Vector3.new(point.X, 0, point.Z)).Magnitude
			<= Range.CONFIG.WAYPOINT_STUDS
		then
			trial.leg += 1
			state.stats.flips += 1
			point = RangeData.laneEnds(anchor, layout, trial.leg)
		end
		speed = trial.speedStudsPerSecond
		direction = if (trial.leg % 2) == 1 then "east" else "west"
	end

	trial.directions[direction] = (trial.directions[direction] or 0) + 1
	if boars.leadTo(trial.targetId :: string, point, speed) then
		state.stats.leadTos += 1
	end
end

local function scan(dt: number)
	local boars = state.boars
	local now = clockNow()
	state.stats.scans += 1
	if boars == nil or state.anchor == nil then
		return
	end
	for _, trial in pairs(state.trials) do
		if trial.targetId == nil then
			if trial.releaseAt == nil or now >= trial.releaseAt then
				release(trial)
			end
			continue
		end
		local status = boars.statusOf(trial.targetId)
		if status == nil then
			-- Gone, and not by this module's hand: release another rather than steer a ghost.
			state.stats.lostTargets += 1
			trial.targetId = nil
			trial.releaseAt = now + Range.CONFIG.RELEASE_SECONDS
			continue
		end
		if status.alive ~= true then
			if trial.carcassAt == nil then
				trial.carcassAt = now
				state.stats.carcasses += 1
			elseif now - (trial.carcassAt :: number) >= Range.CONFIG.CARCASS_SECONDS then
				boars.clear("range carcass")
				state.stats.clears += 1
				trial.targetId = nil
				trial.carcassAt = nil
				trial.releaseAt = now + Range.CONFIG.RELEASE_SECONDS
				state.stats.releases += 1
			end
			continue
		end
		timeWindow(trial, status.position, now)
		-- THE GUARD `leadIfFree` EXISTS FOR, kept here for its stated reason: *"the drive must not
		-- order an animal the Brain is flying"*.
		if boars.flying ~= nil and boars.flying(trial.targetId) then
			state.stats.skippedFlying += 1
			continue
		end
		order(trial, status.position, dt)
	end
end

-- ONE MORE CALL IN THE HEARTBEAT THE ROOT ALREADY RUNS, throttled in here: a second clock would be
-- a second answer to "what time is it" (`Lobby`'s rule).
function Range.step(dt: number)
	if not state.started then
		return
	end
	state.acc += math.max(0, dt or 0)
	local period = 1 / Range.CONFIG.STEP_HZ
	if state.acc < period then
		return
	end
	local used = state.acc
	state.acc = 0
	scan(used)
end

return Range
