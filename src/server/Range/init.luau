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

local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Ballistics = require(ReplicatedStorage:WaitForChild("Ballistics"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
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
	-- HE LEFT: his animal goes this long after he did, and not before (design 7.4). 30 s is the
	-- design's number and it is long enough that stepping off the mat is not losing your target.
	IDLE_CLEAR_SECONDS = 30,
	-- STAND (Karen, 2026-10-27): within this of the lane's middle counts as standing. The BRAIN
	-- stops the animal itself inside `LINE.ARRIVE_STUDS` (1.0) -- *"ARRIVED: hold the heading and
	-- stop, rather than jittering on top of the point"* -- so STAND is the same `leadTo` seam with
	-- the lane's MIDDLE as its point and no second writer anywhere. 2 studs is that 1.0 plus one
	-- 10 Hz step of walk (0.45).
	STAND_HOLD_STUDS = 2,
	-- One target per spot, never a sounder.
	MAX_TARGETS = RangeData.LAYOUT.SPOT_COUNT,
	-- SIX STATIONS: 1 plate + 6 mats + 6 posts + 2 banks + 1 berm = 16 in DEV today, and the bound
	-- carries the six treestands step B3 adds (design 12, T9).
	MAX_PARTS = 160,
	DEFAULT_SPECIES = "boar",
	DEFAULT_KIND = "male",
	DEFAULT_PACE = RangeData.WORD.TROT,
	-- THE GUN THE LANE STARTS WITH, AND ITS FIRST LOAD READ OFF THE GUN'S OWN ROW -- never a
	-- cartridge name typed here (step B4; `Ballistics.shotFor` returns nil for a load a row does
	-- not carry, which is what made the board's lead arithmetic fail on the first gate run).
	DEFAULT_WEAPON = "shotgun",
	DEFAULT_AMMO = Weapons.row("shotgun").AMMO_KINDS[1],
	-- TARGET 3: the measured crossing of the window, against `window / Boar.paceSpeed`.
	CROSSING_TOLERANCE = 0.10,
	-- KAREN, 2026-10-27: *"range is free and amunition is endless"*. STEP B3 READS EXACTLY THESE TWO
	-- when it relaxes `mayShoot`'s two providers (arming and drive-open) and the pocket; nothing in
	-- step B2 reads them, and they are named here so B3 has one place to look.
	FREE = true,
	ENDLESS_AMMO = true,
	-- WHICH ANIMALS THE RANGE OFFERS. Karen, 2026-10-27: boar AND red deer, and step B2 measured a
	-- hind spawning on the lane with the deer's own zones. A species NOT in this set is refused by
	-- the door even if the runtime could spawn it (design 7.3).
	SPECIES_ALLOWED = { boar = true, reddeer = true },
	-- The door's own bucket, per player (`Shop.onRequest`'s shape). A menu click is not a hot path.
	REQUEST_MIN_INTERVAL = 0.15,
	-- A hit belongs to the shot it followed: `onShotLanded` publishes the resolution and the reports
	-- in one frame, so anything later than this is some other shot, somewhere else.
	HIT_WINDOW_SECONDS = 1.0,
}

-- Frozen for `Range.LAYOUT`'s reason, by the same function: no run-time writer, enforced.
RangeData.deepFreeze(Range.CONFIG)

-- THE OPTIONS THE DOOR ACCEPTS, in one list so the door and the spec walk the same set.
Range.OPTIONS = { "species", "kind", "pace", "weapon", "ammo", "distanceStuds" }

type Trial = {
	spot: number,
	species: string,
	kind: string,
	pace: string,
	speedStudsPerSecond: number,
	issuedStudsPerSecond: number,
	weapon: string,
	ammo: string,
	distanceStuds: number,
	targetId: string?,
	leg: number,
	legDrawn: number?,
	drewWord: string?,
	crossings: number,
	lastCrossingSeconds: number?,
	crossingSecondsByPace: { [string]: number },
	directions: { [string]: number },
	standSeconds: number,
	windowEnteredAt: number?,
	windowLeg: number?,
	windowArmed: boolean,
	carcassAt: number?,
	releaseAt: number?,
	-- SINCE WHEN NOBODY HAS BEEN AT THIS STATION, on the owner's own clock. nil means somebody is
	-- there now; `IDLE_CLEAR_SECONDS` is counted from it (design 7.4).
	idleSince: number?,
}

local state = {
	started = false,
	roll = nil :: (() -> number)?,
	built = nil :: any,
	anchor = nil :: Vector3?,
	row = nil :: any,
	-- WHICH WAY THE LANE RUNS, read ONCE off the row at `start` and passed inward -- the flag-at-a-
	-- boundary shape, so every arithmetic below asks a value and never the world's name.
	downrange = 1,
	root = nil :: Instance?,
	-- WHAT `Build` MEASURED under each station's seat: its deck's own top face, and no entry for a
	-- station whose seat was refused. `spotAt` reads it to answer "on the stand", so the measurement
	-- and the rule are one number (design 7.3).
	deckTops = {} :: { [number]: number },
	boars = nil :: any,
	now = nil :: (() -> number)?,
	serverTime = nil :: (() -> number)?,
	trials = {} :: { [number]: Trial },
	acc = 0,
	remotes = nil :: any,
	-- THE HIT CARD'S SENDER (task 304), TOLD to this module like the remotes are: `HitLog.sendCard`,
	-- wired by `RangeBoot`. nil is legal -- a spec and a world without `HitLog` simply send no card.
	card = nil :: ((any) -> boolean)?,
	-- THE RECORD IS THE SERVER'S AND THE BOARD IS A RENDERER (design 9.3). One row per player, by
	-- UserId, thrown away when his trial changes; no drive row is written and `HitLog` is not called.
	records = {} :: { [number]: any },
	seen = {} :: { [number]: number },
	-- One shot is one `ShotResolved` plus zero or more `HitReported`, and the two arrive in that
	-- order for a hit (`onShotLanded` publishes after the hits). The pending slot joins them.
	pending = {} :: { [number]: any },
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
		-- HOW MANY ANIMALS WENT BECAUSE THEIR MAN LEFT, and how many STATIONS have somebody on them
		-- right now -- not how many men, since `occupancy` is a set keyed by spot and two men on one
		-- mat are one occupied station, which is the number the design wants (11.2 group 12, T11).
		idleClears = 0,
		occupied = 0,
		-- A CLEAR THAT TOOK THE WHOLE RANGE WITH IT: a root that wired only `boars.clear` and no
		-- `clearOne`. Counted rather than silent, because it is the defect B2 wrote down.
		wideClears = 0,
		parts = 0,
		buildMs = 0,
		-- HOW MANY SEATS STAND, and how many `HighSeats.plan` refused for its own ground reason: a
		-- refused station is a bench only, and the console says how many there are.
		stands = 0,
		refusedStands = 0,
		shots = 0,
		hits = 0,
		boardPushes = 0,
		picks = 0,
		resets = 0,
		badRequests = 0,
		rateLimited = 0,
		offMat = 0,
		-- HOW MANY HIT CARDS WENT OUT, and how many sends the seam refused (task 304).
		cards = 0,
		cardlessHits = 0,
		-- HOW MANY TIMES A SHOT ASKED WHAT IT MAY NOT SEE (design 12, T13): at most twice per shot,
		-- once for the aim ray and once for the trigger.
		ignoreCalls = 0,
		refusedBy = nil :: string?,
	},
	-- EVERY MAN THE BOARD HAS EVER BEEN PUSHED TO, by UserId (step B6). The owner does not read
	-- `Players`; it remembers the men its own seams handed it, which is the same set that has a
	-- record. `maskDirty` says a trunk changed and every one of them must be told again.
	watchers = {},
	maskDirty = false,
	-- WHO IS IN THE SERVER, handed in by the composition root: this module reads no `Players`
	-- service (it reaches no DataModel), and the RULE -- which station a man is at -- stays here.
	-- nil means the range cannot measure occupancy, and then it releases NOTHING (design 7.4).
	players = nil :: (() -> { any })?,
}

local function clockNow(): number
	local now = state.now
	return if now then now() else os.clock()
end

-- THE CLOCK THE ANIMAL'S HISTORY RING IS STAMPED WITH (review round 1, finding 1), which is the
-- ONLY clock a `cframeAt` instant may be measured on: `Boar.sampleAt` refuses anything older than
-- its oldest stamp, and `os.clock()` is a different epoch entirely.
local function serverNow(): number
	local now = state.serverTime
	return if now then now() else Workspace:GetServerTimeNow()
end

local function paceSpeed(pace: string): number
	local boars = state.boars
	-- WHICH PACE IS HOW MANY STUDS PER SECOND HAS ONE ANSWER IN THE REPOSITORY -- `Boar.paceSpeed`
	-- (moved there from `ForestTest` by this task) -- and it arrives INJECTED, because this module
	-- requires no owner (design section 3). The root wires it as
	-- `function(word) return Boar.paceSpeed(word, runtime:config()) end`, so the range invents no
	-- speed and there is no second copy of the arithmetic.
	-- ...and since B4 the ROUTE is `RangeData.paceSpeedFor`, which delegates Karen's four to that
	-- injected function and derives ISSF's two from `WINDOW_STUDS / CROSSING_SECONDS` (design 6).
	local injected = if boars ~= nil then boars.paceSpeed else nil
	if pace == RangeData.WORD.MIXED then
		-- `mixed` RESOLVES HERE, through the injected roll, so the WORD it drew is known to the
		-- caller that issues the speed and the two legs are drivable by parameter.
		local roll = state.roll
		local word = RangeData.mixedWord(if roll ~= nil then roll() else nil)
		return RangeData.paceSpeedFor(word, RangeData.LAYOUT, injected), word
	end
	return RangeData.paceSpeedFor(pace, RangeData.LAYOUT, injected)
end

local function newTrial(spot: number, pace: string): Trial
	return {
		spot = spot,
		species = Range.CONFIG.DEFAULT_SPECIES,
		kind = Range.CONFIG.DEFAULT_KIND,
		pace = pace,
		speedStudsPerSecond = paceSpeed(pace),
		-- THE SPEED THE RUNTIME WAS ACTUALLY ASKED FOR, which is NOT the pace's speed at STAND:
		-- `order` walks the target to the middle at WALK and `paceSpeed("stand")` is 0 (B2 note).
		-- The board prints this one and labels it, so no column shows a speed nobody issued.
		issuedStudsPerSecond = 0,
		weapon = Range.CONFIG.DEFAULT_WEAPON,
		ammo = Range.CONFIG.DEFAULT_AMMO,
		distanceStuds = RangeData.LAYOUT.DISTANCE_STUDS,
		targetId = nil,
		leg = 1,
		-- WHICH LEG `mixed` LAST DREW FOR: nil until `order` draws on this leg (design 6).
		legDrawn = nil,
		drewWord = nil,
		crossings = 0,
		lastCrossingSeconds = nil,
		crossingSecondsByPace = {},
		directions = {},
		standSeconds = 0,
		windowEnteredAt = nil,
		windowLeg = nil,
		-- Released at a lane end, which is outside the window: the first entry is a real one.
		windowArmed = true,
		carcassAt = nil,
		releaseAt = nil,
		-- NOBODY HAS BEEN HERE YET, so an untouched station never releases: the clock starts at the
		-- first scan and the station stays empty until a man is measured at it.
		idleSince = nil,
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

-- WHICH STATION AND WHICH FIRING POSITION, against the anchor this range was actually built on and
-- the DECK TOPS `Build` measured. The second return is nil for a man at the station but on neither
-- position (under the deck, or walking to the ladder) -- `mayShoot` asks only the first.
function Range.spotAt(position: Vector3?): (number?, string?)
	if state.anchor == nil then
		return nil, nil
	end
	return RangeData.spotAt(state.anchor, position, RangeData.LAYOUT, state.downrange, state.deckTops)
end

-- WHICH STATION ONE MAN IS AT, measured off HIS OWN CHARACTER and nothing he sent (design 7.4,
-- and design 1 item 9's rule). Moved above `scan` in step B7, which asks it per station per tick.
local function playerSpot(player: any): number?
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
		return nil
	end
	return Range.spotAt(position)
end

-- WHAT `Build` MEASURED: the top face of each station's deck, and no entry at all for a station
-- whose seat `HighSeats.plan` refused. The ONE source for "is he on the stand", so a refused
-- station is bench-only as data and nothing branches on it.
function Range.deckTops(): { [number]: number }
	return table.clone(state.deckTops or {})
end

-- THE SERVER'S OWN MEASUREMENT OF WHERE HE IS STANDING, which is the only answer there is: nothing
-- a client sends carries a firing position (design 7.3).
function Range.positionOf(player: any): (number?, string?)
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
		return nil, nil
	end
	return Range.spotAt(position)
end

-- ------------------------------------------------------------------ THE ONE PREDICATE (7.4)

-- MAY THIS MAN SHOOT HERE? Server-measured: his own character's root, on a mat, in a world where the
-- range is actually built. It answers; the WEAPON still decides and still refuses (design 7.4).
function Range.mayShoot(player: any): boolean
	if not state.started or state.anchor == nil or player == nil then
		return false
	end
	-- THE STATION, not the mat: `spotAt`'s box is the union of the bench and the deck, so a man
	-- does not lose his gun on the ladder (design 7.3).
	return (Range.positionOf(player)) ~= nil
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

-- THE STAND, AND IT IS A THIRD RELAXATION THE DESIGN DID NOT ASK FOR. Design 7.4 lists `off-stand`
-- as "no change" on the reasoning *"No stand -> NO AREA MEANS NO RULE"* -- which is FALSE in any
-- world where a drive is also running, and that is Karen's: the lobby range sits beside it.
-- MEASURED in DEV, 2026-10-27, with every other gate open: a real `FireRequest` from the mat came
-- back `refused=off-stand notice=NOT IN YOUR STAND`, because the drive had dealt the lone player a
-- stand 1200 studs away. On the mat this hands back NO AREA, so `Rules.outsideStand` answers false
-- by its own first line; off the mat the base provider's answer is untouched.
function Range.standOver(base: ((any) -> any)?): (any) -> any
	return function(player: any): any
		if Range.mayShoot(player) then
			return nil
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

-- THE FOUR INSTALLS, AS ONE FUNCTION THE BOOT AND THE SPEC BOTH CALL (task 301). The body used to
-- live inside `RangeBoot.compose`, where a spec could only COPY it -- and a copy could not see that
-- `Weapon.setStandProvider` handed nothing back (reviews/task-298/RESULT.md findings 1 and 2).
-- `armFallback` is the boot's own "arm him anyway" answer, passed in so this module gains no
-- dependency on a weapon's config. It returns the UNINSTALL, which puts each base back.
function Range.installOver(armFallback: ((any) -> boolean)?): () -> ()
	local baseArming: any = nil
	local baseDriveOpen: any = nil
	local baseOwned: any = nil
	local baseStand: any = nil
	baseArming = Weapon.setArmingPolicy(Range.armingOver(function(player)
		if baseArming ~= nil then
			return baseArming(player) == true
		end
		return if armFallback ~= nil then armFallback(player) == true else false
	end))
	baseDriveOpen = Weapon.setDriveOpenProvider(Range.driveOpenOver(function(player)
		return if baseDriveOpen ~= nil then baseDriveOpen(player) else nil
	end))
	baseOwned = Weapon.setEntitlementProvider(Range.entitlementOver(function(player)
		return if baseOwned ~= nil then baseOwned(player) else nil
	end))
	-- THE THIRD RELAXATION (round 3): without it the drive's stand refuses every shot on the mat.
	baseStand = Weapon.setStandProvider(Range.standOver(function(player)
		return if baseStand ~= nil then baseStand(player) else nil
	end))
	return function()
		Weapon.setArmingPolicy(baseArming)
		Weapon.setDriveOpenProvider(baseDriveOpen)
		Weapon.setEntitlementProvider(baseOwned)
		Weapon.setStandProvider(baseStand)
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
	trial.issuedStudsPerSecond = 0
	trial.windowEnteredAt = nil
	trial.windowLeg = nil
	-- A PACE PICKED WHILE THE TARGET IS INSIDE THE WINDOW MUST NOT START A CROSSING (task 303,
	-- item 4). Clearing the entry alone made the next scan re-start the clock MID-window, so the
	-- first crossing after any pick was timed over the studs that were left: the Director picked
	-- WALK at a trot and the board read 4.75 s against 8.89 planned -- 21.4 studs of a 40-stud
	-- window, at exactly the 4.5 studs/s it printed beside it. The timer is re-armed by LEAVING.
	trial.windowArmed = false
	trial.standSeconds = 0
	-- `mixed` redraws on the leg it is running, not on the next flip.
	trial.legDrawn = nil
	trial.drewWord = nil
	return true
end

-- THE LANE, FOR ONE SPOT, AND IT IS THE ONE WRITER OF `distanceStuds` ON A LIVE TRIAL (306b's
-- queued note (ii), owned by B4 because B4 is where the crossing is measured). A lane changed
-- while the target is INSIDE the window is not a crossing: the target is led DIAGONALLY across to
-- the new lane, and that transit used to be timed as one. Cleared and DISARMED exactly as
-- `setPace` does -- the timer is re-armed by LEAVING.
function Range.setDistance(spot: number, distanceStuds: number): boolean
	local trial = state.trials[spot]
	if trial == nil or not RangeData.optionAllowed("distanceStuds", distanceStuds) then
		return false
	end
	if distanceStuds ~= trial.distanceStuds then
		trial.windowEnteredAt = nil
		trial.windowLeg = nil
		trial.windowArmed = false
	end
	trial.distanceStuds = distanceStuds
	return true
end

-- WHERE THE SHELF IS, FOR A COMPOSITION ROOT THAT NEEDS IT BEFORE THE BUILD (step B6). The boar
-- runtime's field carries a `groundY`, and the root has to build that field before `Range.start`
-- runs -- so it asks the owner, which asks `Build`, rather than keeping a second copy of the rule.
function Range.shelfFor(row: any, groundAt: ((number, number) -> number?)?): number?
	if row == nil then
		return nil
	end
	return Build.shelfAt(row.x, row.z, row, groundAt)
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
	state.downrange = RangeData.downrangeOf(row)
	state.root = root
	state.boars = seams.boars
	-- WHO IS HERE, from the root (design 7.4). nil means no occupancy measurement is possible, and
	-- then nothing is ever released: a station with nobody measured at it has no animal.
	state.players = seams.players
	state.now = seams.now
	-- THE RING'S OWN CLOCK, which is NOT `state.now` (review round 1, finding 1). `Runtime:cframeAt`
	-- stamps its history with `GetServerTimeNow()`, so an instant taken off `os.clock()` -- process
	-- time -- falls outside the ring's span and is refused every time. Injectable so a spec can run
	-- the two clocks apart; nil is the shipped one.
	state.serverTime = seams.serverTime
	-- THE `mixed` DRAW, INJECTED like the clock, so a spec can run the two legs by parameter
	-- instead of waiting on `math.random` (round 1, finding 1). Nil means the shipped draw.
	state.roll = seams.roll
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
	state.deckTops = built.deckTops or {}
	state.stats.parts = built.parts
	state.stats.buildMs = built.buildMs
	state.stats.stands = built.stands or 0
	state.stats.refusedStands = built.refusedStands or 0
	state.stats.refusedBy = nil
	for spot = 1, RangeData.LAYOUT.SPOT_COUNT do
		state.trials[spot] = newTrial(spot, Range.CONFIG.DEFAULT_PACE)
	end
	print(
		string.format(
			"[range] built in %d ms (%d parts, %d stands, %d refused)",
			built.buildMs,
			built.parts,
			built.stands or 0,
			built.refusedStands or 0
		)
	)
	for _, refusal in ipairs(built.standRefusals or {}) do
		print(string.format("[range] no stand at station %s", refusal))
	end
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
	state.watchers = {}
	state.maskDirty = false
	state.row = nil
	state.root = nil
	state.deckTops = {}
	state.boars = nil
	state.players = nil
	state.now = nil
	state.serverTime = nil
	state.roll = nil
	state.trials = {}
	state.acc = 0
	-- THE RECORDS GO WITH THE RANGE: they describe trials that no longer exist (round 1, finding 2).
	state.records = {}
	state.pending = {}
	state.seen = {}
end

-- FORWARD-DECLARED: `scan` flushes it and it is defined down with `publish`, the one sender it
-- uses. Declared here so the owner keeps one sender and not two.
local flushMasks: () -> ()

-- ONE STATION'S ANIMAL, AND ONLY HIS (task 306 B7, must-fix 1). `Boar.Runtime:clearOne` despawns
-- by id through the same path the range-wide `clear` uses; a root that wires only `clear` takes the
-- other five stations' animals with this one, which is COUNTED (`wideClears`) and not silent.
local function clearTarget(trial: Trial, reason: string): boolean
	local boars = state.boars
	local id = trial.targetId
	if boars == nil or id == nil then
		return false
	end
	if boars.clearOne ~= nil then
		-- THE SEAM ANSWERS A BOOLEAN, and "did not raise" is not "despawned" (round 1, note): a
		-- `false` for an id that is already gone must not bump the counters group 12 reads.
		local ok, done = pcall(boars.clearOne, id :: string, reason)
		if not ok or done == false then
			return false
		end
	elseif boars.clear ~= nil then
		boars.clear(reason)
		state.stats.wideClears += 1
	else
		return false
	end
	state.stats.clears += 1
	trial.targetId = nil
	state.maskDirty = true
	trial.carcassAt = nil
	return true
end

-- WHO IS AT WHICH STATION, THIS TICK (design 7.4). The root hands in the player list, this module
-- applies its own rule (`playerSpot` -> `Range.spotAt`), and a station nobody is measured at gets
-- no animal. No payload is believed and no `Players` service is read here.
local function occupancy(): { [number]: boolean }
	local out = {}
	local players = state.players
	if players == nil then
		return out
	end
	local ok, list = pcall(players)
	if not ok or type(list) ~= "table" then
		return out
	end
	for _, player in ipairs(list :: { any }) do
		local spot = playerSpot(player)
		if spot ~= nil then
			out[spot :: number] = true
		end
	end
	return out
end

local function release(trial: Trial)
	local boars = state.boars
	if boars == nil or boars.spawn == nil or state.anchor == nil then
		return
	end
	-- Released at the end the next leg STARTS from, so the first thing it does is cross.
	-- HIS OWN STATION'S LANE, at the distance HE picked: the window is centred on his mat (design 5.3).
	local from = RangeData.laneEnds(
		state.anchor :: Vector3,
		RangeData.LAYOUT,
		trial.leg + 1,
		state.downrange,
		trial.spot,
		trial.distanceStuds
	)
	local handle = boars.spawn(from, trial.kind)
	if handle == nil or handle.id == nil then
		return
	end
	trial.targetId = handle.id
	state.maskDirty = true
	trial.carcassAt = nil
	trial.releaseAt = nil
	trial.windowEnteredAt = nil
	trial.windowLeg = nil
	trial.windowArmed = true
	state.stats.spawns += 1
end

-- THE WINDOW TIMER (TARGET 3). It times the target's passage through `WINDOW_STUDS` of OPEN lane,
-- not the whole leg: the aprons exist for the turn-around and a crossing is what the shooter sees.
local function timeWindow(trial: Trial, position: Vector3, now: number)
	local centre = RangeData.laneCentre(
		state.anchor :: Vector3,
		RangeData.LAYOUT,
		state.downrange,
		trial.spot,
		trial.distanceStuds
	)
	local inside = math.abs(position.X - centre.X) <= RangeData.LAYOUT.WINDOW_STUDS / 2
	if inside then
		-- ONLY A REAL ENTRY STARTS THE CLOCK: armed by being outside, spent on the way in.
		if trial.windowEnteredAt == nil and trial.windowArmed then
			trial.windowEnteredAt = now
			trial.windowLeg = trial.leg
			trial.windowArmed = false
		end
		return
	end
	trial.windowArmed = true
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
		point = RangeData.laneCentre(anchor, layout, state.downrange, trial.spot, trial.distanceStuds)
		speed = Range.issuedSpeedFor(trial)
		direction = "middle"
		if
			(Vector3.new(position.X, 0, position.Z) - Vector3.new(point.X, 0, point.Z)).Magnitude
			<= Range.CONFIG.STAND_HOLD_STUDS
		then
			trial.standSeconds += dt
		end
	else
		point = RangeData.laneEnds(anchor, layout, trial.leg, state.downrange, trial.spot, trial.distanceStuds)
		-- THE FLIP, and it is the range's reason to exist in one line: ISSF's mandatory direction
		-- change, so neither shoulder is favoured and no single lead is ever trained.
		if
			(Vector3.new(position.X, 0, position.Z) - Vector3.new(point.X, 0, point.Z)).Magnitude
			<= Range.CONFIG.WAYPOINT_STUDS
		then
			trial.leg += 1
			state.stats.flips += 1
			point = RangeData.laneEnds(anchor, layout, trial.leg, state.downrange, trial.spot, trial.distanceStuds)
		end
		-- `mixed` DRAWS PER LEG (design 6), here, where the leg flips and nowhere else. The shooter
		-- is never told which it drew -- ISSF does not announce it -- so the board prints the
		-- ISSUED SPEED and never a second word.
		if trial.pace == RangeData.WORD.MIXED and trial.legDrawn ~= trial.leg then
			local drew, word = paceSpeed(RangeData.WORD.MIXED)
			trial.speedStudsPerSecond = drew
			trial.drewWord = word
			trial.legDrawn = trial.leg
		end
		speed = trial.speedStudsPerSecond
		direction = if (trial.leg % 2) == 1 then "east" else "west"
	end

	trial.directions[direction] = (trial.directions[direction] or 0) + 1
	trial.issuedStudsPerSecond = speed
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
	-- ONE ANIMAL PER *OCCUPIED* STATION (design 7.4): measured once per tick, for all six.
	local here = occupancy()
	local occupiedCount = 0
	for _, occupied in pairs(here) do
		if occupied then
			occupiedCount += 1
		end
	end
	state.stats.occupied = occupiedCount
	for spot, trial in pairs(state.trials) do
		local occupied = here[spot] == true
		if occupied then
			trial.idleSince = nil
		elseif trial.idleSince == nil then
			trial.idleSince = now
		end
		if trial.targetId == nil then
			-- NO ANIMAL FOR AN EMPTY STATION: six drawn, animated animals for one shooter is six
			-- animators and six sound sets for nothing (design 7.4). This is also T11's "an empty
			-- range costs 0 spawns" -- and the ONLY arrival edge there is.
			if occupied and (trial.releaseAt == nil or now >= trial.releaseAt) then
				release(trial)
			end
			continue
		end
		-- HE LEFT: his own animal goes `IDLE_CLEAR_SECONDS` after he did, and nobody else's.
		local idleSince = trial.idleSince
		if idleSince ~= nil and now - (idleSince :: number) >= Range.CONFIG.IDLE_CLEAR_SECONDS then
			if clearTarget(trial, "range idle") then
				state.stats.idleClears += 1
				trial.releaseAt = nil
			end
			continue -- FAIL-FIRST PROBE (reverted in the next commit): the dead-id arm, restored.
		end
		local status = boars.statusOf(trial.targetId)
		if status == nil then
			-- Gone, and not by this module's hand: release another rather than steer a ghost.
			state.stats.lostTargets += 1
			trial.targetId = nil
			state.maskDirty = true
			trial.releaseAt = now + Range.CONFIG.RELEASE_SECONDS
			continue
		end
		if status.alive ~= true then
			if trial.carcassAt == nil then
				trial.carcassAt = now
				state.stats.carcasses += 1
			elseif now - (trial.carcassAt :: number) >= Range.CONFIG.CARCASS_SECONDS then
				-- HIS CARCASS, AND ONLY HIS (must-fix 1): before step B7 this was the range-WIDE
				-- `boars.clear`, so one man's kill took the other five stations' animals and all
				-- six re-released (`range.spec` asserted the 12 spawns and 5 lost targets).
				if clearTarget(trial, "range carcass") then
					trial.releaseAt = now + Range.CONFIG.RELEASE_SECONDS
					state.stats.releases += 1
				end
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
	flushMasks()
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

-- ================================================================== THE BOARD (design 9)
--
-- THE SERVER SEES THE ACCEPTED SHOT AND ITS RESOLUTION IN ORDER, IN ONE PLACE, so `Range` is the one
-- writer of the record and `RangeBoard.luau` draws what it is sent (design 9.3). It adds no source
-- of truth: every zone on it is `report.zone`, the server's own geometric answer.

-- THE ZONE COLUMNS ARE THE ANIMAL'S OWN (design 9.1): a boar has five and a red deer six, so a
-- hard-coded list would print an always-zero `neck` for a boar. Read through the injected seam.
local function zoneOrder(kind: string): { string }
	local boars = state.boars
	if boars == nil then
		return {}
	end
	-- BY THE KIND, because the KIND is what `release` hands `boars.spawn`, and `Boar.kindConfig`
	-- resolves the species from it (round 1, finding 1): a board keyed on the species field could
	-- print a deer's six columns over a boar.
	if boars.zonesForKind ~= nil then
		local ok, zones = pcall(boars.zonesForKind, kind)
		if ok and type(zones) == "table" then
			return table.clone(zones)
		end
	end
	if boars.configOf == nil then
		return {}
	end
	local ok, config = pcall(boars.configOf)
	if not ok or type(config) ~= "table" then
		return {}
	end
	local zones = (config :: any).ZONES
	if type(zones) ~= "table" or type(zones.ORDER) ~= "table" then
		return {}
	end
	return table.clone(zones.ORDER)
end

-- THE TWO LEAD NUMBERS, each naming who measured it (design 9.2). The ballistic one is the shipped
-- function's, never a number typed twice; the view one is the CONFIGURED WINDOW and is therefore a
-- BOUND, printed with a "<=" and never as a measurement.
--
-- `Weapon.HitReported` / `ShotResolved` carry no per-shot measured lag at this commit, so the bound
-- is the only honest view number B4 can print (queued: the field pair of design 9.2).
local function leadsFor(trial: Trial, player: any, distanceStuds: number?): (number, number, boolean)
	local speed = trial.speedStudsPerSecond
	local ballistic = 0
	local far = distanceStuds or trial.distanceStuds
	local row = Weapons.row(trial.weapon :: any)
	if row ~= nil then
		local shot = Ballistics.shotFor(row, trial.ammo)
		if shot ~= nil then
			ballistic = Ballistics.leadStuds(shot, far, speed)
		end
	end
	local window = 0
	local ok, seconds = pcall(Weapon.viewWindowFor, player)
	if ok and type(seconds) == "number" then
		window = seconds
	end
	return ballistic, speed * window, false
end

local function blankRecord(player: any, trial: Trial, position: string?): any
	-- THE DISTANCE HE IS ACTUALLY SHOOTING FROM, and the two lead numbers computed at it: the deck
	-- stands `STAND.backStuds` further back than the bench (design 9.4).
	local far = RangeData.distanceFor(trial, position, RangeData.LAYOUT)
	local ballistic, view, measured = leadsFor(trial, player, far)
	local columns = zoneOrder(trial.kind)
	local zones = {}
	for _, zone in ipairs(columns) do
		zones[zone] = 0
	end
	return {
		userId = (player :: any).UserId,
		spot = trial.spot,
		species = trial.species,
		kind = trial.kind,
		pace = trial.pace,
		weapon = trial.weapon,
		ammo = trial.ammo,
		distanceStuds = far,
		-- THE SERVER'S OWN MEASUREMENT of which firing position he is on; nil means he is at the
		-- station and on neither. The board prints it, and no client ever sends it.
		position = position,
		-- The pace's own speed, and the one the runtime was ASKED for -- not the same number at
		-- STAND, and the board labels both (B2's queued note).
		paceStudsPerSecond = trial.speedStudsPerSecond,
		issuedStudsPerSecond = Range.issuedSpeedFor(trial),
		shots = 0,
		hits = 0,
		zoneOrder = columns,
		zones = zones,
		miss = 0,
		lastDistanceStuds = nil,
		crossingSeconds = trial.lastCrossingSeconds,
		-- SHOWN FROM THE MOMENT OF THE PICK and not only after a shot: the lead this gun needs at
		-- this pace is what the board exists to teach (design 9.2).
		leadBallisticStuds = ballistic,
		leadViewStuds = view,
		leadViewMeasured = measured,
		lastGapStuds = nil,
		lastGapText = nil,
	}
end

-- THE SPEED THE OWNER ISSUES FOR THIS TRIAL, AND IT IS `order`'s OWN LINE, so the board can never
-- print a speed nobody asked for (B2's queued note: `paceSpeed("stand")` is 0 while the target
-- walks to the middle). ONE function, read by the one that issues it and by the one that prints it.
function Range.issuedSpeedFor(trial: Trial): number
	if trial.pace == RangeData.WORD.STAND then
		return paceSpeed(RangeData.WORD.WALK)
	end
	return trial.speedStudsPerSecond
end

-- THE RECORD FOR THIS PLAYER AT THIS TRIAL. A trial change starts a fresh one: the tally is per
-- player, per trial, and is thrown away when the trial ends (design 9.3).
local function recordFor(player: any, trial: Trial, position: string?): any
	local id = (player :: any).UserId
	-- REMEMBERED HERE, where the record is made: the board's audience and the mask's audience are
	-- the same men, so there is one list and no second definition of "who is at the range".
	state.watchers[id] = player
	local existing = state.records[id]
	-- A CHANGE OF FIRING POSITION STARTS A FRESH TALLY, for the same reason a change of lane does:
	-- the distance, and therefore both lead numbers, are different numbers (design 9.4).
	local fresh = existing == nil
		or existing.spot ~= trial.spot
		or existing.species ~= trial.species
		or existing.kind ~= trial.kind
		or existing.pace ~= trial.pace
		or existing.weapon ~= trial.weapon
		or existing.ammo ~= trial.ammo
		or existing.position ~= position
		or existing.distanceStuds ~= RangeData.distanceFor(trial, position, RangeData.LAYOUT)
	if fresh then
		existing = blankRecord(player, trial, position)
		state.records[id] = existing
	end
	return existing
end

function Range.recordOf(player: any): any
	local id = if player ~= nil then (player :: any).UserId else nil
	local record = if type(id) == "number" then state.records[id] else nil
	if record == nil then
		return nil
	end
	local copy = table.clone(record)
	copy.zones = table.clone(record.zones)
	copy.zoneOrder = table.clone(record.zoneOrder)
	-- THE MASK'S TWO FIELDS RIDE ON THE RECORD AND ARE NOT PART OF THE TALLY: they are measured on
	-- every read, because the trunk changes with every release while the tally survives it. Here and
	-- not in `publish`, so the reader and the wire see one record (the Reviewer, round 1).
	copy.mine, copy.window = Range.maskFor(player)
	return copy
end

-- WHAT THE CLIENT'S MASK IS TOLD (design 4.4, 9.4): THIS man's own trunk, and HIS station's own
-- window. Two fields, both the SERVER's measurement -- the client never guesses which animal is
-- his, which is what keeps one judge of the isolation.
--
-- IT IS THE SAME TWO FACTS `Range.ignoredFor` ANSWERS FOR THE SHOT, read from the same places:
-- `boars.rootOf` for the trunk and `RangeData.windowSpanFor` for the window. The shot's door and
-- the picture cannot disagree because neither derives its own copy.
function Range.maskFor(player: any): (Instance?, { minX: number, maxX: number }?)
	local anchor = state.anchor
	local boars = state.boars
	if not state.started or anchor == nil or player == nil then
		return nil, nil
	end
	local spot = (Range.positionOf(player))
	if spot == nil then
		return nil, nil
	end
	local minX, maxX = RangeData.windowSpanFor(anchor :: Vector3, spot :: number, RangeData.LAYOUT)
	local window = { minX = minX, maxX = maxX }
	local trial = state.trials[spot]
	if trial == nil or trial.targetId == nil or boars == nil or boars.rootOf == nil then
		-- THE WINDOW IS STILL HIS, with no animal released yet: the mask then hides the other five
		-- and has nothing of his own to show.
		return nil, window
	end
	local ok, root = pcall(boars.rootOf, trial.targetId :: string)
	if not ok or typeof(root) ~= "Instance" then
		return nil, window
	end
	return root :: Instance, window
end

local function publish(player: any)
	local record = Range.recordOf(player)
	if record == nil then
		return
	end
	local remotes = state.remotes
	if remotes == nil or remotes.RangeBoard == nil then
		return
	end
	pcall(function()
		remotes.RangeBoard:FireClient(player, { record = record, lists = Range.optionLists() })
	end)
	state.stats.boardPushes += 1
end

-- A TRUNK CHANGED, SO EVERY MAN AT THE RANGE IS TOLD AGAIN (the Reviewer, round 1, finding 1).
-- `record.mine` is an INSTANCE, and `release` makes a new one while `boars.clear` destroys all six
-- at once -- so without this a man kept a reference to a destroyed trunk and his own new animal
-- stayed hidden until his next shot. Flushed ONCE per scan tick (`STEP_HZ`, 10 Hz), not once per
-- release, so a six-trial carcass clear costs one push per man and not six.
function flushMasks()
	if not state.maskDirty then
		return
	end
	state.maskDirty = false
	for id, player in pairs(state.watchers) do
		if state.records[id] == nil then
			state.watchers[id] = nil
		else
			publish(player)
		end
	end
end

-- THE SIGNED ALONG-TRACK GAP, in studs, projected onto the target's own travel (design 9.2).
-- Negative is BEHIND the target and positive is AHEAD; `RangeData.gapText` turns it into Karen's
-- words through the repository's one metre conversion.
--
-- The lane runs along X and the heading is the leg's direction, which this module already holds --
-- so there is no second reader of the animal's CFrame. STAND has no gap: nothing is moving.
--
-- IT IS THE SHOT'S CLOSEST APPROACH AND NOT WHERE THE BULLET CAME TO REST (task 308 bug 4).
-- `endPoint` alone is the flight's END -- the berm, the ground, or the ammo's range -- so a slug
-- that passed a hand in front of the nose reported the berm's X and the board printed the same
-- 19.3 m at two paces in two directions. The quantity Karen is owed is where the bullet crossed
-- the animal's own lane: the point on the SEGMENT muzzle->endPoint nearest the animal, which for a
-- shot that stopped in the animal is the animal.
function Range.gapStuds(trial: Trial, muzzle: Vector3?, endPoint: Vector3?, targetPosition: Vector3?): number?
	if typeof(muzzle) ~= "Vector3" or typeof(endPoint) ~= "Vector3" or typeof(targetPosition) ~= "Vector3" then
		return nil
	end
	if trial.pace == RangeData.WORD.STAND then
		return nil
	end
	local line = (endPoint :: Vector3) - (muzzle :: Vector3)
	local far = line.Magnitude
	local nearest = endPoint :: Vector3
	if far > 1e-3 then
		local along = math.clamp(((targetPosition :: Vector3) - (muzzle :: Vector3)):Dot(line / far), 0, far)
		nearest = (muzzle :: Vector3) + (line / far) * along
	end
	local heading = if (trial.leg % 2) == 1 then 1 else -1
	return (nearest.X - (targetPosition :: Vector3).X) * heading
end

-- WHICH KINDS THIS SPECIES HAS, through the injected seam. The door asks it of the species of the
-- REQUEST, not of the trial's previous one (round 1, finding 1).
function Range.kindsFor(species: string?): { string }
	local boars = state.boars
	if boars == nil or boars.kindsFor == nil or type(species) ~= "string" then
		return {}
	end
	local ok, kinds = pcall(boars.kindsFor, species)
	return if ok and type(kinds) == "table" then table.clone(kinds) else {}
end

-- WHERE THE TARGET WAS WHEN THE SHOOTER DREW IT (task 308 bug 4), through the runtime's OWN
-- history ring -- the same ring `Weapon.castWithRewind` judged the shot against, so the gap and the
-- hit answer to one picture. `at` nil, no seam, or a ring that cannot answer falls back to the
-- present position, which is what this read was before the fix.
local function targetPositionOf(trial: Trial, at: number?): Vector3?
	local boars = state.boars
	if boars == nil or trial.targetId == nil then
		return nil
	end
	if type(at) == "number" and at == at and boars.cframeAt ~= nil then
		local okThen, then_ = pcall(boars.cframeAt, trial.targetId :: string, at)
		if okThen and typeof(then_) == "CFrame" then
			return (then_ :: CFrame).Position
		end
	end
	if boars.statusOf == nil then
		return nil
	end
	local ok, status = pcall(boars.statusOf, trial.targetId :: string)
	if not ok or type(status) ~= "table" then
		return nil
	end
	return (status :: any).position
end

-- EVERY RANGE TARGET THIS SHOT MUST NOT SEE (design 4.3): the five that are not his, and his own
-- while it is outside its station's own window. ONE predicate, `RangeData.inWindow`, read here and
-- by the client's mask -- the server's door and the client's picture asking one question.
-- NOBODY AT A STATION MEANS AN EMPTY LIST, so a shot in the wood is untouched; and his own target's
-- position is read through `targetPositionOf`, the SAME history ring the rewound cast is judged
-- against, so the animal is hittable exactly where it is drawn.
-- Note: docs/design/shooting-range-lobby.md sections 4.3, 5.3
function Range.ignoredFor(player: any, rewindSeconds: number?): { Instance }
	-- COUNTED BEFORE THE GUARDS, so T13's budget covers every ask including the ones that answer
	-- nothing; it is a cost counter, not a count of filtered shots (the Reviewer's note).
	state.stats.ignoreCalls += 1
	local out: { Instance } = {}
	local anchor = state.anchor
	local boars = state.boars
	if not state.started or anchor == nil or player == nil or boars == nil or boars.rootOf == nil then
		return out
	end
	local mine = (Range.positionOf(player))
	if mine == nil then
		return out
	end
	local at: number? = nil
	if type(rewindSeconds) == "number" and rewindSeconds == rewindSeconds and rewindSeconds > 0 then
		at = serverNow() - rewindSeconds
	end
	for spot, trial in pairs(state.trials) do
		if trial.targetId ~= nil then
			local ok, root = pcall(boars.rootOf, trial.targetId :: string)
			if ok and typeof(root) == "Instance" then
				local hide = spot ~= mine
				if not hide then
					local minX, maxX = RangeData.windowSpanFor(anchor, spot, RangeData.LAYOUT)
					local position = targetPositionOf(trial, at)
					hide = not RangeData.inWindow(minX, maxX, if position ~= nil then position.X else nil)
				end
				if hide then
					table.insert(out, root :: Instance)
				end
			end
		end
	end
	return out
end

-- THE LISTS AND THE BOARD, WITHOUT A PICK (task 308 bug 1). MEASURED in Karen's place on
-- 46cbd787: on the mat, before any request, `boardPushes=0` and all six option strips had zero
-- children -- the first real E drew the six labels and NO chips, because the ONLY things that
-- published were a request, a shot and a hit. A player who has not picked anything yet cannot pick
-- anything. Idempotent, and it refuses a man off the mat exactly as `onRequest` does.
function Range.look(player: any): boolean
	if not state.started or not Range.mayShoot(player) then
		return false
	end
	local spot = playerSpot(player)
	local trial = if spot ~= nil then state.trials[spot] else nil
	if trial == nil then
		return false
	end
	recordFor(player, trial)
	publish(player)
	return true
end

-- ONE ACCEPTED SHOT. `Weapon.ShotResolved`'s listener (wired at the composition root) calls this:
-- the signal fires once per RESOLVED shot, hit or miss, which is why a miss is counted at all
-- (design 8.3 -- a miss produces no `HitReported`).
function Range.onShotResolved(shot: any)
	if not state.started or type(shot) ~= "table" then
		return
	end
	local player = shot.shooter
	if player == nil or not Range.mayShoot(player) then
		return
	end
	-- WHICH STATION AND WHICH FIRING POSITION, measured at the moment of the shot.
	local spot, position = Range.positionOf(player)
	local trial = if spot ~= nil then state.trials[spot] else nil
	if trial == nil then
		return
	end
	local record = recordFor(player, trial, position)
	record.shots += 1
	record.crossingSeconds = trial.lastCrossingSeconds
	record.issuedStudsPerSecond = trial.issuedStudsPerSecond
	local ballistic, view, measured = leadsFor(trial, player, record.distanceStuds)
	record.leadBallisticStuds = ballistic
	record.leadViewStuds = view
	record.leadViewMeasured = measured
	-- THE MISS GAP, off `endPoint` (clamped) and the target's own position. A hit that follows this
	-- shot clears it, because a hit is neither behind nor ahead of anything.
	-- THE INSTANT THE SHOT WAS JUDGED AT, and it is `Weapon.rewindFor`'s AMOUNT and never
	-- `viewWindowFor`'s window (round 1, finding 1): the window is a BOUND a sweep searches, 0.30 s,
	-- while this is how far back the cast actually went, 0.18 s -- and 0 while `AIM_REWIND` is dark,
	-- which is the one value that keeps the board and the hit in the same tense in both states.
	local drawnAt: number? = nil
	if type(shot.resolvedAtServerTime) == "number" then
		local okBack, back = pcall(Weapon.rewindFor, player, nil, nil)
		drawnAt = shot.resolvedAtServerTime - (if okBack and type(back) == "number" then back else 0)
	end
	record.lastGapStuds = Range.gapStuds(trial, shot.muzzle, shot.endPoint, targetPositionOf(trial, drawnAt))
	record.lastGapText = RangeData.gapText(record.lastGapStuds)
	-- THE SLOT CARRIES THE INSTANT IT WAS OPENED. `onShotLanded` fires `ShotResolved` and then the
	-- hit reports in the SAME frame, so a second is generous -- and it is what stops a slot left
	-- open by a miss from catching a hit landed minutes later (round 3's own case).
	state.pending[(player :: any).UserId] = { shots = record.shots, at = clockNow() }
	record.miss = record.shots - record.hits
	state.stats.shots += 1
	publish(player)
end

-- ONE HIT ON A RANGE TARGET. `Weapon.HitReported` is *"one report per (shot, target)"*, so the first
-- report of a shot turns it from a miss into a hit; a second group on the same shot does not count
-- twice. A hit with no record (a shot in the wood) is ignored: this is the range's tally only.
function Range.onHitReported(report: any)
	if not state.started or type(report) ~= "table" then
		return
	end
	local player = report.shooter
	if player == nil then
		return
	end
	local id = (player :: any).UserId
	local record = state.records[id]
	if record == nil then
		return
	end
	-- TWO GATES, BECAUSE ONE WAS NOT ENOUGH (round 2, finding 2). `Weapon.HitReported` fires for
	-- EVERY hit in the place: he must still be ON THE MAT, and the hit must belong to a shot this
	-- module counted -- a slot `onShotResolved` opens and THIS CONSUMES, so one slot can never
	-- answer for a second hit landed anywhere later.
	if not Range.mayShoot(player) then
		return
	end
	local pending = state.pending[id]
	if pending == nil or pending.shots ~= record.shots then
		return
	end
	state.pending[id] = nil
	if clockNow() - (pending.at or 0) > Range.CONFIG.HIT_WINDOW_SECONDS then
		return
	end
	record.hits += 1
	state.stats.hits += 1
	local zone = report.zone
	if type(zone) == "string" and record.zones[zone] ~= nil then
		record.zones[zone] += 1
	end
	if type(report.nearest) == "number" then
		record.lastDistanceStuds = report.nearest
	end
	record.lastGapStuds = nil
	record.lastGapText = nil
	record.miss = math.max(0, record.shots - record.hits)
	publish(player)
	-- ...AND THE HUNT'S OWN HIT CARD, TO THE SHOOTER AND NOBODY ELSE (task 304). Karen, 2026-10-28:
	-- *"hit card will be usefull"*. THE SENDER IS `HitLog.sendCard` and the range re-derives nothing:
	-- same payload, same remote, same projection as a hit in the wood. It writes no row and no money
	-- (design section 1) -- that is `sendCard`'s own guarantee, asserted in `tests/server/range.spec`.
	local send = state.card
	if send ~= nil then
		local ok, sent = pcall(send, report)
		if ok and sent == true then
			state.stats.cards += 1
		else
			state.stats.cardlessHits += 1
		end
	end
end

-- ================================================================== THE MENU'S LISTS (7.3)
--
-- NO LIST IS TYPED IN THE PANEL: every row is read from the thing it is about. The SERVER sends
-- them, because the species and the kinds are the animal owner's facts and its config is server-only.
function Range.optionLists(): any
	local boars = state.boars
	local config: any = nil
	if boars ~= nil and boars.configOf ~= nil then
		local ok, got = pcall(boars.configOf)
		config = if ok then got else nil
	end
	-- THE BOAR IS THE BASE CONFIG AND IS NOT A ROW IN `SPECIES` -- measured live, 2026-10-27: with
	-- the keys alone the menu offered RED DEER and nothing else. `Boar.speciesConfig` says the same
	-- thing in reverse (an unknown species gets `config` itself), so the default species is seeded
	-- first and the rows are the animals that OVERRIDE it.
	local species = {}
	local seen = {}
	if Range.CONFIG.SPECIES_ALLOWED[Range.CONFIG.DEFAULT_SPECIES] == true then
		table.insert(species, Range.CONFIG.DEFAULT_SPECIES)
		seen[Range.CONFIG.DEFAULT_SPECIES] = true
	end
	local rows = if type(config) == "table" then (config :: any).SPECIES else nil
	if type(rows) == "table" then
		for name in pairs(rows) do
			if Range.CONFIG.SPECIES_ALLOWED[name] == true and not seen[name] then
				table.insert(species, name)
				seen[name] = true
			end
		end
	end
	if #species == 0 then
		table.insert(species, Range.CONFIG.DEFAULT_SPECIES)
	end
	-- THE KINDS ARE THE CHOSEN SPECIES' OWN (`Boar.CONFIG.KINDS.ORDER` through the injected view),
	-- so a red deer offers stag / hind / calf and a boar male / female / cub.
	local current = state.trials[1]
	local kinds = {}
	if boars ~= nil and boars.kindsFor ~= nil then
		local wanted = if current ~= nil then current.species else Range.CONFIG.DEFAULT_SPECIES
		local ok, got = pcall(boars.kindsFor, wanted)
		if ok and type(got) == "table" then
			kinds = table.clone(got)
		end
	end
	return {
		species = species,
		kinds = kinds,
		pace = table.clone(RangeData.PACE_ORDER),
		weapons = RangeData.weaponRows(),
		distances = table.clone(RangeData.DISTANCES_STUDS),
	}
end

-- ================================================================== THE ONE INBOUND DOOR (8.2)
--
-- PUBLIC SO A SPEC DRIVES IT BY PARAMETER (`Shop.onRequest`'s shape), rate-limited per player, and
-- EVERY FACT MEASURED OFF THE CHARACTER THE SERVER CAN SEE. A forged payload is counted apart from a
-- legal request the game said no to: `badRequests` against `refusedBy`.
--
-- NOTHING A CLIENT SENDS CAN SPAWN AN ANIMAL INTO THE DRIVE, WRITE A SCORE OR MOVE A TARGET: the
-- most a pick does is choose which trial THIS spot runs, and only while his character is on that mat.
function Range.onRequest(player: any, request: any): boolean
	if not state.started or player == nil then
		return false
	end
	if type(request) ~= "table" then
		state.stats.badRequests += 1
		return false
	end
	local id = (player :: any).UserId
	if type(id) ~= "number" then
		state.stats.badRequests += 1
		return false
	end
	local now = clockNow()
	local last = state.seen[id]
	if last ~= nil and now - last < Range.CONFIG.REQUEST_MIN_INTERVAL then
		state.stats.rateLimited += 1
		return false
	end
	state.seen[id] = now
	-- THE MAT IS THE PERMISSION, measured here and never claimed by the payload: the same predicate
	-- the weapon's two relaxations read (7.4).
	if not Range.mayShoot(player) then
		-- COUNTED APART FROM A FORGERY (design 8.2): a legal pick from a man who has walked off.
		state.stats.offMat += 1
		return false
	end
	-- A MALFORMED PAYLOAD IS STILL MALFORMED: a `spot` field that is not a legal station is a bad
	-- message whoever sent it, and is counted as one. What it is NOT any more is the thing that
	-- chooses the trial.
	if request.spot ~= nil and not RangeData.optionAllowed("spot", request.spot) then
		state.stats.badRequests += 1
		return false
	end
	-- THE STATION IS MEASURED, NEVER CLAIMED (the must-fix of 306b note (i)). It used to be
	-- `state.trials[request.spot]`, and the menu hard-coded `spot = 1`, so a man at station 3
	-- picked station 1's trial -- the fault that made 11 of the 12 prompts open nothing useful.
	-- A client walking between stations is stale, not hostile, so a legal spot that is not the one
	-- he is standing on is IGNORED rather than refused. `mayShoot` above already proved he is on a
	-- station, so this cannot be nil here.
	local spot = (Range.positionOf(player))
	if spot == nil then
		state.stats.badRequests += 1
		return false
	end
	local trial = state.trials[spot]
	if trial == nil then
		state.stats.badRequests += 1
		return false
	end
	-- A RESET CLEARS THIS PLAYER'S OWN RECORD AND NOTHING ELSE (Karen, 2026-10-27): through the same
	-- door and whitelisted exactly like a pick, because a reset is not a second remote.
	if request.reset == true then
		state.records[id] = nil
		state.pending[id] = nil
		state.stats.resets += 1
		recordFor(player, trial, (select(2, Range.positionOf(player))))
		publish(player)
		return true
	end
	-- TWO PASSES: NOTHING IS WRITTEN UNTIL EVERY WORD HAS PASSED (round 2, finding 1). Writing as
	-- the loop walked left a refused request HALF APPLIED -- species written, kind refused -- which
	-- is the disagreement round 1 required to be impossible.
	local lists = Range.optionLists()
	local candidate = {
		species = request.species or trial.species,
		kind = request.kind,
		weapon = request.weapon or trial.weapon,
	}
	local picked = false
	for _, option in ipairs(Range.OPTIONS) do
		local value = request[option]
		if value ~= nil then
			-- Each option is asked against the REQUEST's own other words: a load against this
			-- message's gun, a kind against this message's species.
			local against = lists
			if option == "ammo" then
				against = { weapon = candidate.weapon }
			elseif option == "kind" then
				against = { kinds = Range.kindsFor(candidate.species) }
			end
			if not RangeData.optionAllowed(option, value, against) then
				state.stats.badRequests += 1
				return false
			end
			picked = true
		end
	end
	if not picked and request.go ~= true then
		state.stats.badRequests += 1
		return false
	end

	-- ...AND ONLY NOW IS THE TRIAL TOUCHED.
	local respawn = false
	for _, option in ipairs(Range.OPTIONS) do
		local value = request[option]
		if value ~= nil then
			if option == "pace" then
				Range.setPace(trial.spot, value)
			elseif option == "distanceStuds" then
				Range.setDistance(trial.spot, value :: number)
			else
				(trial :: any)[option] = value
				respawn = respawn or option == "species" or option == "kind"
			end
			-- A new animal's kinds are not the old animal's, and a new gun's loads are not the old
			-- gun's: each follows unless this same request named one.
			if option == "species" and request.kind == nil then
				local kinds = Range.kindsFor(value :: any)
				local legal = false
				for _, name in ipairs(kinds) do
					if name == trial.kind then
						legal = true
					end
				end
				if not legal and kinds[1] ~= nil then
					trial.kind = kinds[1]
					respawn = true
				end
			end
			if option == "weapon" and request.ammo == nil then
				local row = Weapons.row(value :: any)
				local loads = if row ~= nil then row.AMMO_KINDS else nil
				if type(loads) == "table" and not RangeData.optionAllowed("ammo", trial.ammo, { weapon = value }) then
					trial.ammo = loads[1]
				end
			end
		end
	end
	if picked then
		state.stats.picks += 1
		if respawn then
			-- A new animal is a new animal: the old one is cleared and the next scan releases the
			-- picked species at the end of the lane. `Range` never writes a CFrame.
			-- HIS OWN ANIMAL (must-fix 1, 306b note (viii)): the respawn path was range-WIDE too,
			-- so a man picking a species at station 1 cleared station 6's animal as well.
			clearTarget(trial, "range pick")
			trial.targetId = nil
			trial.releaseAt = nil
			trial.crossings = 0
			trial.lastCrossingSeconds = nil
		end
	end
	-- A PICK STARTS A FRESH RECORD, because the trial it was tallying is over (design 9.3).
	recordFor(player, trial, (select(2, Range.positionOf(player))))
	publish(player)
	return true
end

-- HE TOOK HIS RECORD WITH HIM. Nothing else deletes one, and `Weapon.HitReported` carries a Player,
-- so a recycled UserId must never find a stale tally (round 1, finding 2).
function Range.forget(player: any)
	local id = if player ~= nil then (player :: any).UserId else nil
	if type(id) ~= "number" then
		return
	end
	state.records[id] = nil
	state.pending[id] = nil
	state.seen[id] = nil
end

-- THE HIT CARD'S SENDER, told the same way (task 304): `HitLog.sendCard`, from `RangeBoot`. nil is
-- legal and then no card goes out, which is what a spec that does not ask for one runs with.
function Range.setCardSender(send: ((any) -> boolean)?)
	state.card = send
end

-- The two remotes, told to this module by the root so no spec needs a DataModel. nil is legal and
-- then the board is simply not pushed -- every server spec runs that way.
function Range.setRemotes(remotes: any)
	state.remotes = remotes
end

return Range
